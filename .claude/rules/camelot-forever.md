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

## 4. Still pending (not yet done)

- The three new `C_Bank` functions on Camelot (`ShouldUsePlayerBagsInBank`,
  `FetchMaxNumBankTabs`, `BankBagTypeAndIDToInvSlot`) are net-new integration points; none
  are required for the container-scan model above.
- Optional net-new feature: a physical bank-bag-slot bar (analogous to `frames/bagslots.lua`)
  for viewing/buying/dragging the actual bags Camelot slots into the bank.
