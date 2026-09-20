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

## 7. Camelot bank container model — the bank is the purchased CharacterBankTab_N; -1 is the KEYRING (do not add it)

Definitive container map on Camelot (verified live via a per-container `/run` dump plus the
`origin/forever` source):

- **Character bank storage = the purchased tabs `CharacterBankTab_1..9` = bag ids 6..14.** The
  first character tab is auto-granted free (`BankFrameMixin:PurchaseFirstSlot`,
  `Blizzard_UIPanels_Game/Camelot/BankFrame.lua` — `tabCost == 0` ⇒ auto `PurchaseBankTab`), the
  rest are bought. `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)` returns the
  purchased tabs' container ids (6, then 7…). BetterBags already scans these — they are in
  `const.BANK_BAGS` (§2). A live dump showed `6: slots=48, free=48` for a character with one
  48-slot tab, matching the player's hand-counted 48 free.
- **`Characterbanktab` (-2) / `Accountbanktab` (-3) hold bank-BAG objects, not items** (addressed
  `(Characterbanktab, bagSlotID)`); `GetContainerNumSlots(-2)` is 0. Harmless in `BANK_BAGS`
  (skipped by the `size > 0` guard), same as live retail.
- **Bag id -1 is the KEYRING, NOT the bank.** `origin/forever:Blizzard_FrameXMLBase/Constants.lua`
  sets `KEYRING_CONTAINER = Enum.BagIndex.Keyring` and the enum has `Keyring = -1`; Camelot is
  Wrath-era and has a working keyring (`Blizzard_MainMenuBarBagButtons/Camelot/MainMenuBarBagButtons.lua`
  `GetKeyRingSize()` → `GetContainerNumSlots(-1)`). It persistently reports ~32 slots whether or
  not you are at the bank.

**Do NOT add -1 to `const.BANK_BAGS`.** A prior fix misread an empty-bank dump (which, at 0
purchased tabs, showed only `-1: 32` because the free first tab hadn't been granted/loaded yet)
and concluded -1 was the "base bank." Adding it made the aggregate free-space counter read
`keyring(32) + bank(48) = 80` when the real bank was 48, and would have surfaced 32 keyring slots
as bank space. That change (and its `not addon.isForever` keyring-guard edits in `data/items.lua`)
was reverted. The keyring guards in `Phase5_UpdateFreeSlots`/`Phase6_EnrichData`/`GetBagName`
(`bagid == Enum.BagIndex.Keyring`) are correct as-is: -1 is not in `BACKPACK_BAGS` or `BANK_BAGS`,
so it is simply never scanned.

If a Camelot bank ever renders blank with tabs that *do* have slots, the cause is the async
first-tab grant/load not being reflected at the `BANKFRAME_OPENED` scan (there is no retail
re-scan on `BANK_TABS_CHANGED`), **not** a missing base-bank container — diagnose that path
rather than re-adding -1.

## 8. PLAYER_MONEY crash while looting away from the bank (directly UnregisterEvent BankPanel.MoneyDisplay)

Symptom: on Camelot, a gold change out in the world (looting coin) throws
`Blizzard_UIPanels_Game/Camelot/BankFrame.lua:43: bad argument #1 to 'FetchNumPurchasedBankTabs'
(bankType nil)`. It requires having visited the bank at least once in the session, and does not
happen with the addon disabled.

Root cause (a latent Blizzard bug that BetterBags's frame handling triggers), traced end to end:
- `BankPanel.MoneyDisplay` (`BankBagCostMoneyDisplayMixin`, the "cost of the next bank tab" money
  frame) registers `PLAYER_MONEY` in its `OnShow` / unregisters in `OnHide`
  (`Camelot/BankFrame.lua`). Its `OnEvent` on `PLAYER_MONEY` calls `Refresh()`, which fires
  `EventRegistry:TriggerEvent("BankPanelMixin.ShowOrHideBagCost")`. The handler
  `BankFrameMixin:OnShowOrHideBagCost` calls `C_Bank.FetchNumPurchasedBankTabs(self:GetActiveBankType())`
  with **no nil check**.
- The two `GetActiveBankType`s are asymmetric (`Mainline/BankFrameTemplates.lua`):
  `BankPanelMixin:GetActiveBankType()` returns `self.bankType` (raw), but
  `BankFrameBaseMixin:GetActiveBankType()` returns `self.BankPanel:IsShown() and
  self.BankPanel:GetActiveBankType() or nil` — **gated on `BankPanel:IsShown()`**. `MoneyDisplay:Refresh`'s
  guard reads the raw (BankPanel) one; the crashing handler reads the IsShown-gated (BankFrame) one.
- `IsShown()` is the frame's own flag; `IsVisible()` is effective (self **and** all parents shown)
  — verified from `warcraft.wiki.gg` (`ScriptRegion:IsVisible`; their example: reparent a shown
  frame under a hidden one ⇒ `IsShown()==true, IsVisible()==false`). `OnShow`/`OnHide` track
  **effective visibility**, with one exception: `OnShow` for an XML frame "fires after OnLoad
  **unless hidden at the time**" (its own hidden state, not the parent chain). And critically,
  **event registration is independent of shown state** — a registered frame keeps receiving events
  while hidden, and calling `Hide()` on a frame that is not `IsVisible` produces no
  visible→hidden transition, so its `OnHide` does **not** fire.
- So `MoneyDisplay` registers `PLAYER_MONEY` at **login** (own flag shown, no `hidden` attr),
  regardless of the parent bank being hidden. BetterBags then reparents `BankFrame` under the
  permanently-hidden `sneakyFrame` (`core/init.lua` `HideBlizzardBags`, gated on
  `database:GetEnableBankBag()`). Because `MoneyDisplay` is never *effectively visible*, its
  `OnHide` never fires, and it stays registered forever. **`Hide()` cannot fix this** — verified
  live in the broken state: `MoneyDisplay:IsEventRegistered("PLAYER_MONEY")==true` while
  `IsShown()==false`. (My earlier "close cascade unregisters it" and the two `Hide()`-based
  attempts — at bank `OnShow` and at close — were all wrong for this reason; the `OnShow` one also
  fought Blizzard re-`Show()`ing it mid-session.)
- After any bank visit, `BankPanel.bankType` is left non-nil (`bags/bank.lua` `SwitchToBankAndWipe`
  → `SetBankType(Character)`), and `addon.CloseBank` sets `BankPanel:IsShown()` false via
  `BankPanel:Hide()` (`core/hooks.lua`). Looting then: `PLAYER_MONEY` → `MoneyDisplay:OnEvent` →
  `Refresh` guard passes (raw bankType non-nil) → handler reads `BankPanel:IsShown()`(false) → nil →
  crash. (No crash *before* a bank visit — `bankType` is nil, so `Refresh`'s guard bails.)

Fix: **`UnregisterEvent("PLAYER_MONEY")` on `MoneyDisplay` directly** — not `Hide()`, which cannot
unregister it. Done in two taint-safe places:
- `bags/bank.lua` `bank:SuppressBlizzardBankPanel()` — the consolidated BankPanel-suppression
  helper (previously duplicated inline in the fade + direct `bank.proto:OnShow` paths) that also
  hides `MoneyFrame`/`AutoDepositFrame`/`Header`. So it's killed the moment BetterBags takes over
  the bank.
- `core/hooks.lua` `addon.CloseBank` — alongside the existing `BankPanel:Hide()`, in the
  `BANKFRAME_CLOSED` event-handler context (sanctioned by patterns-taint.md).

Nothing re-registers it (its `OnShow` can never fire while it is not `IsVisible` under the
`sneakyFrame`). Must **not** be done at init — touching `BankPanel`/children during
`HideBlizzardBags` taints `BankPanel` and breaks `UseContainerItem()` for all containers (see the
`core/init.lua` warning). Nil-guarded, so live retail (no `MoneyDisplay`) is unaffected. Coverage:
`spec/core/close_bank_spec.lua` and `spec/bags/bank_panel_suppress_spec.lua`.

## 9. Still pending (not yet done)

- The three new `C_Bank` functions on Camelot (`ShouldUsePlayerBagsInBank`,
  `FetchMaxNumBankTabs`, `BankBagTypeAndIDToInvSlot`) are net-new integration points; none
  are required for the container-scan model above.
- Optional net-new feature: a physical bank-bag-slot bar (analogous to `frames/bagslots.lua`)
  for viewing/buying/dragging the actual bags Camelot slots into the bank.
