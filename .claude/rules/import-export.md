---
paths:
  - "util/serialization.lua"
  - "core/database.lua"
  - "next/settings/content.lua"
  - "spec/serialization_spec.lua"
  - "spec/database_spec.lua"
  - "spec/helpers/encoding_util.lua"
  - "spec/helpers/legacy_export.lua"
  - "spec/helpers_encoding_util_spec.lua"
  - "spec/fixtures/legacy_export_v3.lua"
---
# Importing and Exporting Categories

Players share their categories as text: Settings → Profiles → Import / Export (`next/settings/content.lua`, `transfer` tab)
fills a box with `DB:ExportSettings()` and reads one back with `DB:ImportSettings(text)` (`core/database.lua`). The text is
pasted from Discord, forums and other players, so **an import string is untrusted input, and it is read as data, never
run**.

## 1. Why: the import ran the pasted string (issue #1317)

Until #1317 the text after `!BB` was Base64 of a Lua table constructor, and `Serialization:Deserialize` handed it to
`loadstring("return " .. str)` and called the result, with the global environment and no sandbox. A string could carry
a function call instead of a table, and it ran with every API an addon has, while the import still reported success
(reproduced against the real `DB:ImportSettings` in a spec, and kept as one: `spec/database_spec.lua`, "never runs code
a pasted '!BB' string holds"). Category strings are shared in public, and #1250 (one category at a time) makes sharing
them the point, so the importer was fixed first.

## 2. The formats

| Prefix | After it | Written | Read by |
|--------|----------|---------|---------|
| `!BB2!` | `Serialization:Encode`: CBOR, Deflate, Base64 | `DB:ExportSettings` since #1317 | `Serialization:Decode` |
| `!BB` | Base64 of a Lua table constructor (`serializeTable`) | before #1317 | `Serialization:DecodeLegacy` |

- `ImportSettings` strips all whitespace first (a chat box breaks long text over lines), then checks `!BB2!` before
  `!BB`: `!BB` is a prefix of it, and an old string never has `!` after `!BB` (Base64 has none). Anything else is
  refused with the "Missing !BB prefix" message.
- **After the prefix, every character outside Base64 is skipped** (`base64Only`, in both `Decode` and `DecodeLegacy`).
  The old reader did that (its decoder dropped them), so an old string saved with a period after it, or pasted with a
  no-break or zero-width space, imported; the bug review found the new reader refused those, and both formats skip them
  now.
- **The payload is the same in both**: `{ version = 3, customCategoryFilters, customCategoryIndex,
  ephemeralCategoryFilters, categoryFilters, customSectionSort }`. `version` is the shape of the data (2: unified
  categories; 3: search rule version 2), not the encoding; the prefix says the encoding. An import is normalized
  (`DB:NormalizeCategories`) and its rules brought to the current version (`DB:MigrateSearchRules`), as before.
- What a failed read returns: `false, "Failed to read import data: " .. reason`, and nothing in the profile changes.

## 3. `Serialization` (`util/serialization.lua`)

- `Encode(value) -> string`: `C_EncodingUtil.SerializeCBOR`, `CompressString(_, Deflate, OptimizeForSize)`,
  `EncodeBase64` (Standard). Not protected: what it encodes is the profile's own data.
- `Decode(text) -> table | nil, reason`: the reverse, each step in `pcall`, and a result that is not a table refused.
  `C_EncodingUtil` raises an error on some bad data and returns nothing on other (the documentation's
  `MayReturnNothing` on DecodeBase64 and DecompressString; warcraft.wiki.gg: DecompressString "will raise an error if the
  data appears to be invalid"; it says nothing for DeserializeCBOR), so every step handles both. CBOR can hold only
  nil, booleans, numbers, strings and tables: nothing in it can run.
- `DecodeLegacy(text) -> table | nil, reason`: `C_EncodingUtil.DecodeBase64`, then `parseLegacy`, in `pcall`.
- `DeepCopy(value)`, unchanged.
- **`C_EncodingUtil` is on every client BetterBags ships for**: `EncodingUtilDocumentation.lua` documents the same
  functions, arguments and enums on the live, classic (Mists), classic_era (Vanilla), classic_anniversary (TBC),
  classic_titan and forever branches of `.libraries/wow-ui-source` (`SerializeCBOR`, `DeserializeCBOR`,
  `CompressString`, `DecompressString`, `EncodeBase64`, `DecodeBase64`; only live's carries the `SecretArguments`
  lines), and every TOC's interface version is at or past the patch warcraft.wiki.gg gives for it on that client.
  Blizzard's own Cooldown Viewer export uses the same chain (`CooldownViewerSettingsDataStoreSerialization.lua`).
- `loadstring` and the hand-written Base64 are gone from the module.

### 3a. The legacy parser

`parseLegacy` reads exactly what `serializeTable` wrote, and refuses the rest:

- a table: `{`, then fields `[key] = value` each followed by `,` (the last one's may be left out), then `}`; whitespace
  between anything;
- a key: a string, a number, `true` or `false` (a `nil` key raises Lua's own "table index is nil");
- a value: a table, or a literal: a string, a number, `true`, `false`, `nil` (the old writer's value for a function);
- a string as Lua 5.1's `string.format("%q")` writes it (`lstrlib.c`, `addquoted`): `\"`, `\\`, a backslash before a
  real newline, `\r`, `\ddd` (it wrote `\000`); any other byte as it is;
- a number as `tostring` writes it (`%.14g`): `-?digits[.digits][e±digits]`;
- one table, and nothing after it.

Identifiers, calls, operators, `..`, positional values, `name = value` fields, long strings, comments, hex numbers and
table keys are all refused. A table nested too deep for Lua's stack makes the parse raise, and `DecodeLegacy` returns
that as the reason.

## 4. The mock (`spec/helpers/encoding_util.lua`)

`spec/helpers/world.lua` loads it after `wow_mocks.lua`, with `Enum.CompressionMethod`, `Enum.CompressionLevel` and
`Enum.Base64Variant`. Real CBOR (RFC 8949: arrays only for tables wholly 1..n, maps otherwise, strings as byte strings,
errors for functions, tables holding themselves and nesting past 100, `ignoreSerializationErrors` writing undefined),
real Base64 (RFC 4648, both alphabets; nothing returned for text that is not), and Deflate's stored blocks: the mock
writes uncompressed blocks, which any inflater reads, and reads only those, so it reads what it wrote and raises an error
on anything else. Zlib and Gzip raise an error in the mock: nothing uses them. `spec/helpers_encoding_util_spec.lua`
checks it against RFC 8949 Appendix A, RFC 4648 §10 and RFC 1951's stored block layout.

`spec/helpers/legacy_export.lua` is the old writer, unchanged, so specs can make the strings players still hold;
`spec/fixtures/legacy_export_v3.lua` is a string the old `ExportSettings` wrote, captured from it before #1317, with the
data it was written from.

## 5. Coverage

`spec/serialization_spec.lua` (round trips of an export's shapes, every byte, Base64 only, each kind of bad text;
the fixture; every value form the old writer wrote; payloads that would run code, and texts the old writer never wrote,
each refused; a last field with no comma; nesting too deep; each `C_EncodingUtil` step raising or returning nothing,
with the reason naming it), `spec/database_spec.lua` ("import/export": the `!BB2!` format, the fixture imported into
the profile, the code payload refused with the categories left alone, a bad `!BB2!` string, stray characters in either
format, a string broken over lines, the version 1 and 2 imports built with the old writer).

22 mutations of the parser, `Decode`, `DecodeLegacy` and the prefixes: 21 caught. The survivor is equivalent: with the
unknown-escape check off, `tonumber(nil)` raises and the string is refused anyway; the check stays to name the problem.
Two guards whose mutations survived the same way were removed, as Lua raises for them itself (an escape above 255, a nil
key). The bug review also read 3000 random tables written by the old writer through both `DecodeLegacy` and the old
`loadstring` reader (identical), and fuzzed 20000 old and 15000 new texts (never raised).

## 6. Left as they are, and why

- **The shape of what an import holds is not checked.** An import copies the five tables whole, as it did before
  #1317. A string written by hand can hold a table of the wrong shape (a category that is a number), which the bags
  then fail to read until the profile is fixed or reset. That is not code running, the old format allowed the same, and
  nothing BetterBags exports has that shape.
- **A function in a category makes the export raise** (bug review of #1317). `DB:CreateOrUpdateCategory` saves a
  plugin's `save = true` category table as given, so a plugin that put a function in one would have
  `SerializeCBOR` raise in `Encode`, where the old writer wrote `nil` for it. No plugin has been seen doing that; the
  documented `{ ignoreSerializationErrors = true }` is the fix if one does.
- **`CompressString` and `EncodeBase64` returning nothing is not handled in `Encode`.** The documentation marks them
  `MayReturnNothing`, but nothing shows them doing so for a string BetterBags hands them; Blizzard's own export only
  asserts it. `ExportSettings` would raise.
- **`inf` or `nan` in an old string is refused** where `loadstring` read them as nil globals. No profile field holds one.
- **A hand-made old string the parser cannot read may name a line of `util/serialization.lua`** in its reason ("table
  index is nil", "bad argument #1 to 'char'", "stack overflow"), shown in the import's message. Only text the old
  writer never wrote gets there.
- **Decompressing is bounded only by the client** (`Constants.EncodingLimits.EncodingDecompressSizeLimit`, about
  100 MB). A small string that inflates to a lot is data, not code, and the same as pasting that much.
