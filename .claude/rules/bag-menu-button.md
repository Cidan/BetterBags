# Top-Left Bag Menu Button: Click Semantics & Sort Coupling

This documents the click behavior of the round top-left menu button on the bag/bank
frames (`BagMenuButton:Create`, `frames/menubutton.lua`; the bag creates it in
`BuildParts`, the theme only places it with its bag window's `Layout.MenuButton` and styles
it with the `BagButton` element, sonata.md §3a) and how a backpack sort couples to the open
bank.

## 1. Click map (`frames/menubutton.lua`, the button's `OnClick`)

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

The hover tooltip (the button's `OnEnter`, same file) must mirror the click map. The retail
bank tooltip lists **Right Click → Sort Bank** and, **only when `addon.hasWarbank`**, **Shift
Right Click → Deposit Warbank Items** (on Forever the deposit line is omitted). Keep these in
sync whenever the click branches change.

The right click is `BagMenuButton:Sort(ctx, bag)`, which a theme's Sort action button
(window.md, "Action buttons") and BetterBags Next's bank sort button (next.md §6, retail) call
too, so all of them always do the same thing.

Coverage: `spec/frames/menubutton_spec.lua` (every click branch, the shared Sort, the drop, the
first-time highlight, both tooltips with and without a Warbank, the cursor-item line,
placement).

## 2. Sorting the backpack also sorts the open bank

The `bags/SortBackpack` message handler (`data/refresh.lua`, `refresh:OnEnable`) builds
`{ sort = true }` and, **when `addon.atBank` is true**, additionally sets `sortBank = true`
(and `sortWarbank = true` on `addon.hasWarbank`, i.e. retail with a warbank — never on
Forever). So a single right-click on the backpack
button cleans up everything visible when the bank is open, restoring the classic "sort
inventory also sorts the bank" behavior.

- All three sort flags ride **one** serialized refresh unit (`refresh:_RunUnit`, see
  refresh-scheduler.md §6): the unit marks both kinds' sort sweeps pending, arms one
  fallback timer covering both, clears recent items for both kinds, and issues the protected
  `C_Container.SortBags()` + `SortBankBags()` + `SortAccountBankBags()` calls (gated behind
  `not InCombatLockdown()`). It does not sweep either kind itself: the moves' `BAG_UPDATE`
  refreshes (or the fallback, if nothing moved) show the result. In combat both kinds are
  swept in the unit instead, as before.
- When the bank is closed (`addon.atBank == false`), the request stays `{ sort = true }` —
  backpack only, byte-for-byte the prior behavior.

Coverage: `spec/refresh_spec.lua` ("should also sort the bank and warbank when sorting the
backpack with the bank open (retail)", "…(classic)", and the unchanged closed-bank case).

## 3. The menu a left-click opens (`frames/contextmenu.lua`, `CreateContextMenu`)

The toggles come first, then Bag Anchor, then the bank's sorts, then the common entries:

| Backpack | Bank |
|---|---|
| Drag to Resize | Drag to Resize |
| Show Bags | Show Bags |
| Show Bag Button | Bag Anchor ▸ |
| Bag Anchor ▸ | Sort Bank |
| | Clean Up Warbank (with a Warbank) |
| Switch to Next | |
| What's New | What's New |
| Open Options Screen | Open Options Screen |
| Close Menu | Close Menu |

(asked: Drag to Resize at the top of both bags' menus, Bag Anchor below the toggles, Show Bag
Button above Bag Anchor). The bank's Show Bags used to come after its sorts; it moved up so both
menus start alike and the two sorts stay together. Show Bags is only listed when the bag has a
slots panel. **Switch to Next** (asked) switches the bags to BetterBags Next without a reload
(next.md §11); only the backpack's menu has it, since the bank's is shown at the bank, where the
bags cannot switch.

- **Drag to Resize** is the Resizable Window option (`config/catalog.lua`, a bag's Layout tab in the
  settings window) as a toggle: checked
  while `database:GetBagSizeMode(kind) == "window"`; a click sets "window" or "content" for the
  view the bag shows and sends `bags/Redraw`, whose draw applies it (`bagProto:ApplySizeSettings`).
  The options screen reads the same setting when it opens.
- New strings ("Drag to Resize" and its tooltip) have no translations yet and show in English
  (`L:G` falls back to the key), like "What's New".

Coverage: `spec/frames/contextmenu_spec.lua` ("menu order and Drag to Resize": the backpack, the
retail bank, a bank without a Warbank, and the toggle on both bags). Each guard was
mutation-tested.
