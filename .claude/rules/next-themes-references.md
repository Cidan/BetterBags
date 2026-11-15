---
paths:
  - "sonata/resolve.lua"
  - "sonata/next.lua"
  - "spec/sonata/next_engine_spec.lua"
  - "spec/sonata/engine_spec.lua"
---
# Next themes: references and Watch (`SonataResolve`, `SonataNext`)

Split out of next-themes.md (its §2, the engine), keeping their numbers.

## 2a. References: another addon's values, as data

Asked (issue #1326): an ElvUI theme for BetterBags Next that keeps the player's ElvUI colors, nothing of ElvUI's called
(next-themes-elvui.md §27). A theme is data, so it cannot call a function to read another addon's settings, as the
classic bags' themes do; it **names** where the value is, and the engine reads it.

- **The form** (a `Variables` entry, so `"$Name"` puts it anywhere: a palette color, a texture, a font's file, flags or
  shadow, a list of numbers): `{ Global, Path, Fallback, Alpha?, Map? }`. Any variable that is a table with a `Global`
  and a `Fallback` is one; a `Global` without a `Fallback` is data, as it always was (a client color named through a
  variable, which `NextStyle` reads as a palette color). A reference is one value: a client's override of it replaces
  it whole (`SonataResolve.Merge`), nothing of the base's `Alpha` or `Map` kept.
- **Reading** (`SonataResolve.ReadReference`, every time the theme resolves, so every apply reads it again):
  `_G[Global]`, then each key of `Path` (strings or numbers), **raw** (`rawget`: no metamethod of the other addon runs;
  `SonataResolve.Walk`); a value on the way that is not a table, or a missing key, reads nothing. Then `Map` (a table:
  the value read is looked up in it, and a value it does not name is read as it is). Then the value is taken when it
  is the `Fallback`'s kind: a fallback of three or four numbers takes a **color** (`r`, `g`, `b` numbers and `a`, read as
  `{ r, g, b, a }`, opaque without an `a`: ElvUI's color tables and Blizzard's ColorMixins) or a list of as many numbers;
  a longer or shorter list of numbers a list of as many; a string, a number or a boolean the same kind; **`false`** any
  string, number or boolean (a part that reads `false` treats it as unset: a font role's `File` false is the client's
  font). Otherwise the `Fallback` is drawn. `Alpha` replaces a color's alpha, the fallback's too. What is read is a
  copy, never filled in with `$` variables.
- **Registration refuses** (`SonataNext:RegisterTheme`, the theme's `Variables` and each `Clients` override's): a
  `Global` that is not a name, a `Path` that is not a list of keys, an `Alpha` that is not a number, a `Map` that is
  not a table; the error names the variable (`Variables.Border: ...`,
  `Clients.Classic.Variables.Edge: ...`). The classic engine resolves references too (the resolver is shared,
  sonata.md), but only Next validates them.
- **`Check`** names a reference whose `Global` is a table but whose value reads nothing of its kind ("its Fallback is
  drawn"): the addon keeps it elsewhere now. One whose addon is not loaded is not checked (the theme is not offered).

## 2b. Watch: drawing again when another addon changes

Asked: "i do think we should hook UpdateMedia". ElvUI fires no event or callback when a player changes a color: its
options write the setting and call `E:UpdateMedia()`, once per step while a color is dragged
(docs/next-elvui-theme.md).

- **The form**: `Watch = { { Global, Path, Method }, ... }`, the methods (of the table at `Path` under `Global`, read as
  references are) whose calls change what the theme's references read. Registration refuses anything else, a map too (the hooks
  walk it as a list). The theme's own `Watch` is hooked; one in a `Clients` override is not (no theme has one).
- **Hooking** (`SonataNext:HookWatches(theme)`, from `Init` for every registered theme and from `RegisterTheme` once
  started): each method that is a function now (raw) is hooked with `hooksecurefunc`, **once for good** per table and
  method (`sonataNext.hooked`, weak by table, kept through `Init`: a hook cannot be taken off), however many themes
  watch it. The method runs as it did, its return values kept. It returns how many it hooked.
- **A call** (`OnWatchedCall(target, method)`, inside the other addon's call): nothing but a flag and a timer. While the
  theme in use watches that method, one read waits for the next frame (`C_Timer.After(0)`), however many calls come
  before it. It returns `"scheduled"`, `"queued"`, `"not watched"` or `"not started"`.
- **The read** (`RefreshWatched(ctx)`): the theme in use resolved again (`effective`). Its `Variables` as they were:
  `"unchanged"`, nothing drawn. Otherwise, when every text role draws the same (`Fonts`, `FontShadow` and every palette
  color a role or shadow is drawn in, as they were): **restyled with the font objects kept** (`NextStyle:Use(theme,
  true)`, the generation bumped, the item buttons synced, every widget restyled, `sonata/NextThemeChanged` sent),
  `"restyled"`: a color dragged in ElvUI's options would otherwise leave a set of font objects behind on every step, and
  font objects can never be freed. Otherwise applied again, unsaved, new font objects and all: `"applied"`. Never saved
  (the theme may be a preview). `"no theme"` before Next starts.
- **A theme that watches should draw no text in a color it reads** from the other addon: a color dragged makes a read
  per frame, and a text role drawn otherwise makes new font objects on each. Found in review: the ElvUI theme drew six
  roles in its value color and made 56 font objects a frame while it was dragged (next-themes-elvui.md §27).
- What each returns is for profiler traces: a capture wraps every module's methods (perf-profiler.md), so it shows each
  watched call and what each read did (data-driven.md).

Coverage: `spec/sonata/next_engine_spec.lua` ("references to another addon's values": every kind, read again, copies,
fallbacks, alpha and map, raw reads, a `Global` without a `Fallback` kept as data, a client's override replacing a
reference whole, registration, `Check`; "watching another addon's methods": the form (a map refused), one hook,
late themes, one read per frame, unchanged, restyled with fonts kept, applied for a font's file and for a font's color,
not watched and not started), `spec/sonata/engine_spec.lua` (the classic engine reads one).
