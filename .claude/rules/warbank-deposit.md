---
paths:
  - "bags/bank.lua"
  - "next/bank.lua"
  - "frames/menubutton.lua"
  - "frames/contextmenu.lua"
  - "spec/bags/warbound_deposit_spec.lua"
  - "spec/frames/contextmenu_spec.lua"
  - "spec/frames/menubutton_spec.lua"
  - "spec/next/bank_spec.lua"
---
# The Warbank's Item Deposit (Deposit All Warbound Items)

Blizzard's bank window has a **Deposit All Warbound Items** button and an **Include tradeable reagents** checkbox
under the Warbank (`BankPanel.AutoDepositFrame`, `Blizzard_UIPanels_Game/Mainline/BankFrame.xml`). BetterBags draws
its own bank and hides that frame with the rest of Blizzard's bank (`BankBehavior:SuppressBlizzardBankPanel`,
`bags/bank.lua`), so it offers the same deposit, and the same setting, itself (issue #750). Everything here exists only
where there is a Warbank (`addon.hasWarbank`: retail, never WoW: Forever or Classic).

## 1. What Blizzard's button does

`BankPanelItemDepositButtonMixin` (`BankFrame.lua`):

- **The deposit** is `C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)` (`BankDocumentation.lua`: one
  argument, the bank type; no returns). Whether tradeable reagents go too is the client's `bankAutoDepositReagents`
  CVar: the checkbox only reads it (`GetCVarBool`) and writes it (`SetCVar`, `BankPanelIncludeReagentsCheckboxMixin`).
  That the deposit honours the CVar is inferred from that code (the API takes nothing else), not seen in game. The
  live client's CVar list (Ketho/BlizzardInterfaceResources, `Resources/CVars.lua`: default, category, account,
  character, secure) has it as `{"1", 4, false, true, false}`: on by default, kept per character, and not secure, so
  addon code may set it.
- **The refund question.** Before depositing into the Warbank, `GetItemDepositConfirmationPopup` looks through the
  bags (`ItemUtil.IteratePlayerInventory`: the backpack and the bag slots, the reagent bag too, never the bank) for an
  item the Warbank takes (`C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation)`) that can still be
  refunded (`C_Item.CanBeRefunded(itemLocation)`). If there is one it shows
  `StaticPopupDialogs.ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM` ("You are about to deposit refundable items into the
  bank. All warbound items will have their refund timers removed. Would you like to continue?"), whose Accept deposits;
  else it deposits at once. A deposit without the question ends a refund silently, which BetterBags did before #750.
- **Closing it.** `BankPanelMixin:CloseAllBankPopups` hides that popup, from the panel's `OnHide` and from
  `BankPanel:SetBankType` while the panel is shown.

## 2. The shared deposit (`bags/bank.lua`, `BankBehavior`)

- `BankBehavior:WarboundDepositEndsRefunds()` is Blizzard's check above, as is.
- `BankBehavior:DepositWarbound(ask)` deposits at once, or, when the check says a refund would end, calls
  `ask(deposit)`: `ask` shows a question and calls `deposit` once the player accepts. Every Warbank deposit in
  BetterBags goes through it; none calls `C_Bank.AutoDepositItemsIntoBank` itself.
- Each bank asks in its own dialog (UI consistency: the classic bags use Blizzard's popups, BetterBags Next asks every
  question in `NextDialog`):
  - **Classic bank:** `bank.proto:DepositWarboundItems()` asks with Blizzard's own popup, by name, with
    `{ bankType = Enum.BankType.Account }` as its data; Blizzard's `OnAccept` deposits (its `deposit` is not used).
    It closes as Blizzard's own does: BetterBags keeps `BankPanel` shown while the bank is open
    (`SuppressBlizzardBankPanel`), so `BankPanel:SetBankType` closes it, both when the player switches the bank's tab
    (as at Blizzard's bank) and when the bank closes (`addon.CloseBank` runs `SwitchToBankAndWipe`, which sets the
    character bank, before it hides `BankPanel`). `BankPanel`'s own `OnHide` never runs: its `BankFrame` sits under a
    hidden frame.
  - **BetterBags Next's bank:** `bankProto:DepositWarboundItems()` (`next/bank.lua`) asks in `NextDialog` over the
    bank, in Blizzard's words: title `ACCOUNT_BANK_DEPOSIT_BUTTON_LABEL`, text
    `ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM`, Cancel and Deposit (`Danger`). It asks nothing, and deposits
    nothing, while another window's dialog shows (there is one dialog; showing it again would replace that one
    unanswered, as the vendor's quantity question does). The bank's `Hide` closes its own question, which answers
    Cancel; another window's stays.

**Left as is, and why: Escape on Next's question closes the bank too.** The question has no text field, so Escape
reaches Blizzard's `CloseAllWindows`/`CloseSpecialWindows`, which hides the dialog and the bank panel together (the
panel is in `UISpecialFrames`, outside the controls' Escape stack, next-controls.md), and BetterBags' hook on
`CloseSpecialWindows` (`core/hooks.lua`) then ends the bank interaction and closes the bags. The question answers
Cancel and nothing is deposited. The classic bank's Blizzard popup takes Escape first (`StaticPopup_EscapePressed`), so
there only the popup closes. It is the vendor's quantity question's documented behaviour with its field unfocused
(next-vendor.md §10d); keeping the bank open would mean taking the panel out of `UISpecialFrames` while its question
shows and stopping that hook from ending the bank interaction, both shared by every BetterBags Next window and
taint-sensitive. Reported to the user with #750, not built.

## 3. Where the player finds it

| | Classic bags | BetterBags Next |
|---|---|---|
| Deposit All Warbound Items | the bank's left-click menu (after Sort Bank and Clean Up Warbank); Shift + right click on the bank's menu button | the bank's header button (`depositButton`, in Plain's bag-button menu); Shift + right click on its title or bag button |
| Include tradeable reagents | the bank's left-click menu, checked while `GetCVarBool("bankAutoDepositReagents")` | (to come) |

- Both sides name it in Blizzard's words (`ACCOUNT_BANK_DEPOSIT_BUTTON_LABEL`, "Deposit All Warbound Items";
  `BANK_DEPOSIT_INCLUDE_REAGENTS_CHECKBOX_LABEL`, "Include tradeable reagents"), translated by the client: the menu
  entries, the menu button's tooltip line, Next's header button's tooltip.
- The Shift + right click is `BagMenuButton:Sort` (bag-menu-button.md §1), which calls the bag's
  `behavior:DepositWarboundItems()`: the classic bank's `bank.proto`, or the table Next's bank gives as its `behavior`.
- **Sort Bank only sorts.** The classic bank's menu entry used to deposit every reagent into the character bank
  (`C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Character)`, Blizzard's "Deposit All Reagents") before sorting,
  where nothing said so. That was removed (asked: "let's not have that be hidden functionality").
- The deposit is offered wherever the bank shows, as the Shift right click and Next's header button were before #750;
  Blizzard shows its button only while its panel shows the Warbank's items (`BankPanelMixin:SetItemDisplayEnabled`).

## 4. Coverage

`spec/bags/warbound_deposit_spec.lua` (the check, in the bags only; the deposit at once or once accepted; the classic
bank's popup), `spec/frames/contextmenu_spec.lua` ("the Warbank's deposit": the entries, their order, the CVar toggle,
Sort Bank depositing nothing), `spec/frames/menubutton_spec.lua` (the Shift right click through the bank),
`spec/next/bank_spec.lua` (the header button, the question over the bank, another window's dialog, Hide closing the
question); 14 mutations, all caught. The WoW mocks for `ItemUtil`, `C_Bank.IsItemAllowedInBankType`, `C_CVar` and
`ContainerFrame_GetContainerNumSlots` are ported from Blizzard's source (`spec/helpers/wow_mocks.lua`).
