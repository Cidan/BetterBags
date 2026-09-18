# Top-Left Bag Menu Button: Click Semantics & Sort Coupling

This documents the click behavior of the round top-left menu button on the bag/bank
frames (created by `themes.SetupBagButton`, `themes/themes.lua`) and how a backpack sort
couples to the open bank.

## 1. Click map (`themes/themes.lua`, the button's `OnClick`)

The button registers `LeftButtonUp`/`RightButtonUp` and branches on the click arg:

- **Left-click** — shift = `BetterBags_ToggleSearch()`; cursor holds an item = create a
  category for it; otherwise open the context menu (`contextMenu:Show(bag.menuList)`).
- **Right-click, backpack** — `bag:Sort(ctx)` → `bags/SortBackpack`.
- **Right-click, bank (retail *with* warbank — `addon.hasWarbank`)** — **sort only** the
  active bank type: `bags/SortWarbank` when the active tab is a Warbank tab
  (`const.ACCOUNT_BANK_BAGS[bag.bankTab]`), else `bags/SortBank`. No auto-deposit happens on a
  plain right-click. (The membership test replaced the old `bag.bankTab <= CharacterBankTab_6`
  bound, which misrouted character tabs 7-9 on 9-tab clients.)
- **Shift + right-click, bank (retail with warbank)** — **deposit** eligible items into the
  Warbank (`C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)`). No sort.
- **Right-click, bank (retail *without* warbank — WoW: Forever, `addon.isRetail` and not
  `addon.hasWarbank`)** — always `bags/SortBank`; there is no Warbank, so no shift-deposit and
  no `bags/SortWarbank` branch. See camelot-forever.md §4.
- **Right-click, bank (non-retail)** — falls through to `bag:Sort(ctx)` (bank `Sort` is a
  no-op via `ShouldHandleSort()==false`; classic bank sorting is handled elsewhere).

Rationale: right-click used to *both* auto-deposit and sort the bank in one action, which
made a plain "sort" also shuffle items into the Warbank unexpectedly. Deposit and sort are
now split — plain right-click sorts, shift+right-click deposits.

The hover tooltip (`bagButton` `OnEnter`, same file) must mirror the click map. The retail
bank tooltip lists **Right Click → Sort Bank** and, **only when `addon.hasWarbank`**, **Shift
Right Click → Deposit Warbank Items** (on Forever the deposit line is omitted). Keep these in
sync whenever the click branches change.

## 2. Sorting the backpack also sorts the open bank

The `bags/SortBackpack` message handler (`data/refresh.lua`, `refresh:OnEnable`) builds
`{ sort = true }` and, **when `addon.atBank` is true**, additionally sets `sortBank = true`
(and `sortWarbank = true` on `addon.hasWarbank`, i.e. retail with a warbank — never on
Forever). So a single right-click on the backpack
button cleans up everything visible when the bank is open, restoring the classic "sort
inventory also sorts the bank" behavior.

- All three sort flags ride **one** serialized refresh unit (`refresh:_RunUnit`, see
  refresh-scheduler.md): the unit clears recent items for both kinds, refreshes bank then
  backpack, then issues the protected `C_Container.SortBags()` + `SortBankBags()` +
  `SortAccountBankBags()` calls (still gated behind `not InCombatLockdown()`). No second
  request is enqueued.
- When the bank is closed (`addon.atBank == false`), the request stays `{ sort = true }` —
  backpack only, byte-for-byte the prior behavior.

Coverage: `spec/refresh_spec.lua` ("should also sort the bank and warbank when sorting the
backpack with the bank open (retail)", "…(classic)", and the unchanged closed-bank case).
