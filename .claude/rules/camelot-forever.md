# WoW: Forever (Camelot) Support

WoW: Forever (internal codename **Camelot**, build `1.60.1.69893`, install flavor
`wow_classic_beta`, TOC Interface `16001`) is a **mainline retail fork**: the engine and
UI are retail, so at runtime `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` and
`addon.isRetail == true`, exactly like live retail. Camelot therefore runs BetterBags'
**retail** code paths. Its bank is still the numbered-container model (BetterBags renders
its own window by scanning container bags via `C_Container`; it never uses Blizzard's paged
`BankPanel`), it just exposes **9 character + 9 account bank tabs** instead of retail's
**6 + 5**, and the `Enum.BagIndex.AccountBankTab_N` values are shifted up accordingly.

## 1. Detection is load-time only — `addon.isForever`

There is **no** build, version, or project number that distinguishes Camelot from live
retail at runtime (it is a mainline fork). The only reliable signal is **which TOC loaded**:

- `core/forever.lua` sets `addon.isForever = true`. It is listed **only** in
  `BetterBags_Camelot.toc`, so it runs solely on the Camelot client. It must load **after**
  `core/boot.lua` (which creates the addon) and **before** `core/constants.lua`.
- `core/constants.lua` normalizes `addon.isForever = addon.isForever == true` next to the
  other `addon.is*` flavor flags, so every consumer sees a plain boolean (`false` on
  retail/classic, `true` on Camelot).
- **Never** try to detect Camelot with a version/`GetBuildInfo`/`WOW_PROJECT_ID` check — it
  is indistinguishable from live retail by any such API. Confirmed with the Forever devs.
- **Never** add `core/forever.lua` to `BetterBags.toc` (the base TOC) or any non-Camelot
  TOC — doing so would flag every retail/classic user as Forever.

Coverage: `spec/core/forever_spec.lua` (flag set; present in Camelot TOC, absent from base
TOC; loads before constants.lua) and `spec/core/constants_spec.lua` (boolean normalization).

## 2. Bank tab tables are sized off the enum, not hard-coded

The retail bank bag-ID tables in `core/constants.lua` — `BANK_TAB`, `BANK_BAGS`,
`BANK_ONLY_BAGS`, `BANK_ONLY_BAGS_LIST`, `ACCOUNT_BANK_BAGS` — are built by probing
`Enum.BagIndex` with the `enumerateBagIndices(prefix)` helper, which walks contiguous
members named `"<prefix>1"`, `"<prefix>2"`, … and stops at the first missing index. This
yields **6 + 5 on live retail** (byte-for-byte identical to the old static literals) and
**9 + 9 on Camelot**, with **no `addon.isForever` branch** — the enum itself is the source
of truth, so this is also forward-compatible if Blizzard adds tabs to either client.

- **Why this is the load-bearing bank fix:** nearly all of `data/items.lua` (scan,
  partition, free-slot count, cache-clear) iterates these tables with `pairs()` or tests
  membership (`const.ACCOUNT_BANK_BAGS[bagid]`) or the symbolic `>= AccountBankTab_1`
  threshold, and `GetPossibleTabIDs` / `Phase1_DetermineBags` iterate `pairs(const.BANK_BAGS)`
  / `pairs(const.ACCOUNT_BANK_BAGS)`. Once the constant tables cover all 9+9 tabs, the entire
  scan/partition/routing pipeline adapts automatically — item storage container IDs are
  unchanged (`CharacterBankTab_1..9` = bag IDs 6..14, `AccountBankTab_1..9` = 15..23), so
  "player bags in bank" (`C_Bank.ShouldUsePlayerBagsInBank`) does **not** change what we scan.
- **Do not** re-introduce static `CharacterBankTab_1..6` / `AccountBankTab_1..5` literals for
  these tables. A naive static add of tabs 7–9 would also throw `table index is nil` on live
  retail, where those enum members do not exist.

`ACCOUNT_BANK_BAGS_LIST` is the ordered account-tab counterpart of `BANK_ONLY_BAGS_LIST`,
built in the same loop, consumed by the bank tab slots panel (§3).

Coverage: `spec/core/constants_spec.lua` ("dynamic bank tab sizing": 6+5 retail shape, 9+9
Camelot expansion across every derived table incl. `ACCOUNT_BANK_BAGS_LIST`, and
`BANK_ONLY_BAGS_LIST` ordering by tab index).

## 3. Bank UI is retail code — it carries over; only tab counts needed fixing

Camelot runs BetterBags' **retail** bank UI unchanged (`BankPanel`,
`C_Bank.FetchPurchasedBankTabData`, `BankPanelPurchaseButtonScriptTemplate` + `overrideBankType`,
`BankPanel:SetBankType`, `.TabSettingsMenu` all exist and behave as on retail — audited from
the `origin/forever` source). `BankPanel.Header` and `BankPanel.AutoDepositFrame` do **not**
exist on Camelot, but `bags/bank.lua` already nil-guards both and uses `SetAlpha(0)` + `Show()`
(not `Hide()`), which is correct there too — no change needed. The bank window renders its own
container-scan view, so Camelot's paged "player bags in bank" model (`ShouldUsePlayerBagsInBank`)
does not affect us. Our tab-slots panel is the analogue of Camelot's physical bank-bag slots in
bag mode, and of retail's virtual tabs in non-bag mode — same panel both ways.

The only real gap was **tab count**, fixed by deriving from the §2 constant tables (not an
`addon.isForever` branch — the enum already encodes the count, so this is forward-compatible and
identical on retail):

- `frames/bankslots.lua` `CreatePanel` builds `allTabSlots` from `const.BANK_ONLY_BAGS_LIST`
  (character) + `const.ACCOUNT_BANK_BAGS_LIST` (account), and sets
  `content.maxCellWidth = #allTabSlots` (was a fixed 11-entry literal + `maxCellWidth = 11`).
  Renders 11 slots on retail, 18 on Camelot. Coverage: `spec/frames/bankslots_spec.lua`
  ("Dynamic tab count derived from Constants").
- `integrations/quickfind.lua` classifies a bank tab id via membership in `const.BANK_ONLY_BAGS`
  / `const.ACCOUNT_BANK_BAGS` instead of the old hard bounds `<= CharacterBankTab_6` /
  `<= AccountBankTab_5` (which dropped Camelot tabs 7-9 / 6-9 into the visual-only fallback).
  Coverage: `spec/quickfind_spec.lua`.

## 4. No warbank on Forever — `addon.hasWarbank`

Camelot has **no Account bank (Warbank / Warband bank)** at all, even though its
`Enum.BagIndex` still declares `AccountBankTab_1..9`. This is a genuine behavioral divergence
the enum cannot express, so it is gated on a dedicated predicate rather than the enum:

- **`addon.hasWarbank = addon.isRetail and not addon.isForever`** (`core/constants.lua`, set
  next to the other flavor flags). True on live retail, false on Camelot and on classic.
- **Central lever:** the account bag tables are built **only when `addon.hasWarbank`**. On
  Camelot they are left **present-but-empty** (`const.ACCOUNT_BANK_BAGS = {}`,
  `ACCOUNT_BANK_BAGS_LIST = {}`) — this must be explicit, because the enum probe would
  otherwise populate 9 phantom account tabs. Every **table-driven** warbank site then goes
  inert automatically with no per-site branch: the data sweep/partition/free-slot/cache-clear
  in `data/items.lua`, the bank tab slots panel (`frames/bankslots.lua` renders character tabs
  only), `integrations/quickfind.lua`, `data/loader.lua`, `data/refresh.lua` bank-change
  detection, the virtual-stack `"W"` hash discriminator, and `frames/item.lua` kind classing.
- **Explicit `addon.hasWarbank` gates** for the warbank surfaces that reference
  `Enum.BankType.Account` / warbank UI directly (not through those tables):
  - `core/database.lua` `Migrate` — does **not** seed the default **Warbank** group (this is
    what kills the whole data-driven account-tab section / `tabIsAccountBank` routing).
  - `frames/groupdialog.lua` — the group-creation dialog omits the "Warbank" bank-type option.
  - `bags/bank.lua` — `money:Create(addon.hasWarbank)` (character-only bank wallet).
  - `frames/contextmenu.lua` — omits the "Clean Up Warbank" menu entry.
  - `themes/themes.lua` — bag-menu button drops the "Deposit Warbank Items" tooltip line and
    the shift-right deposit / SortWarbank branch; on Forever right-click always sorts the
    character bank (see bag-menu-button.md).
  - `data/refresh.lua` — a backpack sort with the bank open no longer sets `sortWarbank`.
  - `core/hooks.lua` — does not register the `AccountBanker` interaction.
- **Do NOT** gate these on `addon.isRetail` alone (that is still true on Camelot) or on
  `addon.isForever` inline — use `addon.hasWarbank`, so classic (also warbank-less) stays
  correct and the intent reads clearly.

Coverage: `spec/core/constants_spec.lua` ("warbank availability": empty tables + `hasWarbank`
false on Forever, populated + true on retail), `spec/database_migration_spec.lua` ("default
Warbank group gating"), `spec/refresh_spec.lua` ("sort the bank but NOT the warbank on a client
without one").

## 5. Flat slots panels use a headerless tooltip decoration on Camelot

The Default theme decorates flat windows (`themes:RegisterFlatWindow`) with
`DefaultPanelFlatTemplate`. On Camelot that template renders **broken**: its `Bg` starts
20px below the top (a reserved title strip), and its `ButtonFrameTemplateNoPortrait`
NineSlice overhangs the top with tall metal header art that Camelot re-drew even taller
(`Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua`) — Blizzard shipped a Camelot-only
`NineSliceUtil.UpdateCornerCropping` just to survive it on short frames. On the short
bag/bank **slots panels** this showed as an empty dark title-bar band + wrong border.

Fix: on `addon.isForever`, both slots panels decorate with a **headerless
`TooltipBorderedFrameTemplate`** child frame (dark, thin-bordered, carries its own
background; cross-version-safe, verified on all five TOCs) instead of registering the themed
flat window, and take the **symmetric-padding** layout path (no reserved header — never feed
`GetFlatHeaderHeight`, which still returns Default's 30, into this path). This mirrors the
Classic manual-backdrop fix in `classic-bag-slots-panel.md`; Camelot just uses the Blizzard
tooltip template rather than a raw `SetBackdrop`.

- `frames/bagslots.lua` — `CreatePanel` adds an `addon.isForever` branch (tooltip decoration)
  ahead of the retail/Classic branches; `Draw` centering condition is `addon.isRetail and not
  addon.isForever` so Camelot falls to the symmetric-padding branch.
- `frames/bankslots.lua` — `CreatePanel` decorates with the tooltip template on Camelot else
  registers the flat window; `Draw` uses a 12px symmetric `topInset` on Camelot.
- Only the **slots panels** are converted. Other flat windows (`frames/searchcategory.lua`
  config pane) still use the themed decoration; convert them the same way if they show the
  band on Camelot.

Coverage: `spec/frames/bagslots_spec.lua` ("centers the bags with symmetric padding on
Camelot") and `spec/frames/bankslots_spec.lua` ("Camelot headerless decoration": bypasses the
themed flat window on Camelot, still uses it on ordinary retail).

## 6. Equipment-set scan routes by API existence, not TOC version

`data/equipmentsets.lua` has two harvest implementations: `UpdatePreMidnight` (uses
`EquipmentManager_UnpackLocation`) and `UpdateMidnight` (uses `EquipmentManager_GetLocationData`,
the API 12.0/Midnight introduced when it removed `UnpackLocation`). The dispatcher in
`equipmentSets:Update()` originally chose between them with the version gate
`addon.isMidnight` (`addon.isRetail and tocVersion >= 120000`, `core/constants.lua`).

Camelot is a mainline fork that already ships the Midnight `EquipmentManager` — only
`GetLocationData`, no `UnpackLocation` — yet reports a **sub-12.0 TOC** (Interface `16001`), so
`addon.isMidnight` is `false` on Forever. The version gate therefore routed Forever to
`UpdatePreMidnight`, which called the non-existent `EquipmentManager_UnpackLocation` and crashed
with `attempt to call a nil value` (triggered by `CreateEquipmentSet` → `EQUIPMENT_SETS_CHANGED`
→ `refresh:RequestUpdate` → `equipmentSets:Update`). This is the same lesson as §1: **no version
number distinguishes Forever from other clients** — here it also fails to distinguish which
EquipmentManager API is present.

Fix: `Update()` selects the implementation by **feature detection**, preferring the old API
where it exists — `if EquipmentManager_UnpackLocation ~= nil then UpdatePreMidnight() else
UpdateMidnight() end`. This keeps every client that works today byte-for-byte unchanged (War
Within retail and the classic-retail variants BCC/Cata/Mists all still have `UnpackLocation`,
including the `not addon.isRetail` void-bank slot shift) and routes both Midnight **and** Forever
to the `GetLocationData` path. `addon.isMidnight` is no longer the discriminator for equipment
sets (it remains defined; it has no other consumer). Coverage: `spec/equipmentsets_spec.lua`
("Update" describe — UnpackLocation-present path, UnpackLocation-absent Midnight path, and the
"does not crash on Forever (retail, non-midnight, no UnpackLocation)" regression).

## 7. Base/general bank lives in container -1 (not -2, not a CharacterBankTab_N)

Camelot's always-present base/general **character** bank is stored in container **-1**, and
that is the id BetterBags must scan. Verified live on a 1.60.1 client with an empty bank and
zero purchased tabs (`/run` dump): the only bank-range container reporting slots was
`-1: slots=32, free=32`; `Characterbanktab` (-2) reported nothing, and every
`CharacterBankTab_N` (6..14) was empty because `C_Bank.FetchNumPurchasedBankTabs(Character)`
was 0 (purchased-tab data `[]`). So on a fresh/low-tab Camelot character the entire bank
lives at -1.

- `Characterbanktab` (-2) only holds **bank-bag objects** (addressed as
  `(Characterbanktab, bagSlotID)` in `origin/forever:Blizzard_UIPanels_Game/Camelot/BankFrame.lua`),
  not item storage — `GetContainerNumSlots(-2)` is 0.
- The purchasable tabs `CharacterBankTab_1..9` (bag ids 6..14) *are* item storage once bought,
  and are already in `const.BANK_BAGS` (§2) — but they are empty/absent until purchased.
- The mainline enum Camelot inherits labels **-1 as `Keyring`**, but Camelot has no keyring;
  -1 is the bank there.

**The bug this caused:** `const.BANK_BAGS` (retail build) was `{ [-2]=-2, 6..14 }` — it never
included -1 — so `Harvest`/`Phase5_UpdateFreeSlots`/`Phase6_EnrichData` never scanned the base
bank. With no purchased tabs, nothing bank-side was scanned at all and the **entire bank window
rendered blank** (no items, no free-slot markers).

**Fix (two inline `addon.isForever` gates — no split constants file, no new constant):**
1. `core/constants.lua`, retail `BANK_BAGS` build: after the `CharacterBankTab_` loop,
   `if addon.isForever then const.BANK_BAGS[-1] = -1 end`. Added to `BANK_BAGS` only, **not**
   `BANK_ONLY_BAGS` (that list is the purchasable tabs alone, consumed by the tab slots panel).
   Because `BANK_BAGS` drives the whole scan/partition/free-count pipeline plus the loader's
   managed-bag set (`data/loader.lua:ForEachManagedBag`) and the `BAG_UPDATE`→bank-refresh
   fan-out (`data/refresh.lua`), this one addition makes the base bank scanned, harvested,
   free-counted, routed to the character bank tab (`const.ACCOUNT_BANK_BAGS[-1]` is nil, so
   `IncludeBagInFreeSpace`/`ItemBelongsToTab` treat it as character bank), and re-indexed on
   change — with no other per-site edits.
2. `data/items.lua`: the keyring special-casing keys off `Enum.BagIndex.Keyring`, which is -1 on
   Camelot — i.e. the base bank. Gate both sites with `not addon.isForever` so -1 is never
   excluded/mislabeled as the keyring: `Phase5_UpdateFreeSlots` (the `isKeyring` guard that
   otherwise drops -1 from `emptySlots`) and `Phase6_EnrichData` (the `name = "Keyring"` branch).
   `GetBagName` needs no change — -1 isn't in `BACKPACK_BAGS`, so it already falls to its
   `id == -1 → "#1: Bank"` branch.

Do **not** re-introduce a `bags = { [-1] = true }`-style *targeted* handler for this (that was the
non-retail `PLAYERBANKSLOTS_CHANGED` path); the fix is purely making -1 a first-class member of
`BANK_BAGS`. An earlier attempt that instead registered `PLAYERBANKSLOTS_CHANGED` on Forever did
**not** fix it (the base bank container was never in the scan list to begin with) and was
reverted.

Coverage: `spec/core/constants_spec.lua` ("Forever base bank container (-1)": added to
`BANK_BAGS` but not `BANK_ONLY_BAGS` on Forever, absent on live retail) and `spec/items_spec.lua`
("Forever base bank at -1 (keyring guard)": `Phase5_UpdateFreeSlots` counts -1's free slots on
Forever, still excludes -1 as the keyring when not Forever).

## 8. Still pending (not yet done)

- The three new `C_Bank` functions on Camelot (`ShouldUsePlayerBagsInBank`,
  `FetchMaxNumBankTabs`, `BankBagTypeAndIDToInvSlot`) are net-new integration points; none
  are required for the container-scan model above.
- Optional net-new feature: a physical bank-bag-slot bar (analogous to `frames/bagslots.lua`)
  for viewing/buying/dragging the actual bags Camelot slots into the bank.
