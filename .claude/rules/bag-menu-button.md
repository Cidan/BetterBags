# Top-Left Bag Menu Button: Click Semantics & Sort Coupling

This documents the click behavior of the round top-left menu button on the bag/bank
frames (created by `themes.SetupBagButton`, `themes/themes.lua`) and how a backpack sort
couples to the open bank.

## 1. Click map (`themes/themes.lua`, the button's `OnClick`)

The button registers `LeftButtonUp`/`RightButtonUp` and branches on the click arg:

- **Left-click** — shift = `BetterBags_ToggleSearch()`; cursor holds an item = create a
  category for it; otherwise open the context menu (`contextMenu:Show(bag.menuList)`).
- **Right-click, backpack** — `bag:Sort(ctx)` → `bags/SortBackpack`.
- **Right-click, bank (retail)** — **sort only** the active bank type: `bags/SortBank` when
  the active tab is a Character-bank tab (`bag.bankTab <= Enum.BagIndex.CharacterBankTab_6`),
  else `bags/SortWarbank`. No auto-deposit happens on a plain right-click.
- **Shift + right-click, bank (retail)** — **deposit** eligible items into the Warbank
  (`C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)`). No sort.
- **Right-click, bank (non-retail)** — falls through to `bag:Sort(ctx)` (bank `Sort` is a
  no-op via `ShouldHandleSort()==false`; classic bank sorting is handled elsewhere).

Rationale: right-click used to *both* auto-deposit and sort the bank in one action, which
made a plain "sort" also shuffle items into the Warbank unexpectedly. Deposit and sort are
now split — plain right-click sorts, shift+right-click deposits.

## 2. Sorting the backpack also sorts the open bank

The `bags/SortBackpack` message handler (`data/refresh.lua`, `refresh:OnEnable`) builds
`{ sort = true }` and, **when `addon.atBank` is true**, additionally sets `sortBank = true`
(and `sortWarbank = true` on `addon.isRetail`). So a single right-click on the backpack
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
