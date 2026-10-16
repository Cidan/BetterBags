# "Show Bags" Slots Panel: Classic Flat Panel & Centering

This documents how the bag-slots panel (the "Show Bags" slide-out created by
`BagSlots:CreatePanel`, `frames/bagslots.lua`) is themed and laid out, and why
Classic/Era diverge from Retail.

## 1. The theme draws it: a flat panel on retail, a tooltip backdrop on Classic/Era

The panel is a Slots window (window.md §8); the theme's `Slots` style draws it (sonata.md
§3b). Default draws a headerless `DefaultPanelFlatTemplate` on retail. On **Classic/Era**
(the `Clients.Classic` override) that template cannot be used: its `NineSlice` paints a 28px
`_UI-Frame-TitleTile` **title-bar band** at the top
(`Blizzard_SharedXML/Classic/NineSliceLayouts.lua`) that hiding the `TitleContainer` cannot
suppress (the band lives on the NineSlice), which showed as an empty title bar on the classic
"Show Bags" panel. So the Classic style has no template and puts a **backdrop on the window
frame itself**: `Interface/Tooltips/UI-Tooltip-Background` + `UI-Tooltip-Border`, edge 16,
insets 4, black at 0.9, white border, not faded by opacity, no title bar, no close button.
`BackdropTemplate` + `SetBackdrop` is identical across Retail, MoP, TBC, and Vanilla.

## 2. Centering: the theme's insets

The panel's window sizes itself to its bag grid plus the theme's `Insets` for the Slots
kind, so the grid's container is exactly the grid's size and the bags are never left in the
corner of a larger box.

- **Retail:** 10 left, 6 right, 30 top (the flat template's header band), 12 bottom.
- **Classic/Era** and WoW: Forever: there is no header band, so **8 on every side**, and the
  bags are centered both horizontally and vertically.

Never reserve the retail header band on Classic: a phantom 30px header pushed the bags off
center (the reported bug). Coverage: `spec/frames/bagslots_spec.lua` ("is as big as its bags
plus the theme's room around them on retail", "centers its bags with even padding on Classic
and on WoW: Forever") and `spec/sonata/themes_spec.lua` ("the slots panels").

## 3. Classic/Era bank "Show Bags" (the bank gets the same panel as the backpack)

The context menu's "Show Bags" entry (`frames/contextmenu.lua`) is only added
`if bag.slots`. The UI unification (#1044) removed `frames/classic/bag.lua` /
`frames/era/bag.lua`, which created the bag-slots panel inline for **both** bags,
and moved creation into each behavior's `OnCreate`. #1089 restored it for the
backpack only, so the Classic/Era **bank** had no `bag.slots` and its menu entry
was missing. There are three parts to the fix. Leave out any one and the bank menu
entry is missing, broken, or shows an empty/partial view.

- **Panel creation.** `bags/classic/bank.lua` and `bags/era/bank.lua` `OnCreate(ctx)`
  call `bagSlots:CreatePanel(ctx, const.BAG_KIND.BANK, self.bag.frame)` (hidden,
  parented to the bank frame), exactly like the backpack overrides. The panel shows
  `const.BANK_ONLY_BAGS_LIST` (`BankBag_1..7`); `frames/bagbutton.lua` already
  classifies these as bank bags on non-retail and handles buying bank bag slots.
  `frames/bagslots.lua` loads before `bags/*` in every Classic TOC.
- **Toggle semantics.** The retail bank's `bag.slots` is a different panel — the
  bank-**tab** filter (`frames/bankslots.lua`, retail only) — whose state persists via
  `database:SetShowBankTabs` and drives the one-tab-at-a-time data filter. That is a
  retail-only concept. The menu's `usesBankTabs` is therefore
  `addon.isRetail and bag.kind == BANK`. On Classic/Era the bank toggles **exactly
  like the backpack**: checkmark = `bag.slots:IsShown()`, and it only switches the bag
  view (`SECTION_ALL_BAGS` / previous view). It never writes `showBankTabs`. The menu entry and
  a theme's `ShowBags` action button (the GW2 theme's side panel) run the same code,
  `ContextMenu:ToggleBagSlots` (window.md, "Action buttons"), so both use this gate. Re-opening the bank restores the panel from the view:
  `bagProto:Draw` shows `bag.slots` whenever the view is `SECTION_ALL_BAGS`.
- **Data partition.** `ItemBelongsToTab` (`data/items.lua`) filters bank items to
  `item.bagid == tabID` in `SECTION_ALL_BAGS`, because on retail tab ID == Blizzard
  bank-tab bag ID. On Classic/Era the bank tab IDs are group IDs (or `-1` with a stale
  `showBankTabs`), so that filter emptied the view or kept only the main bank. The filter
  is retail-only. On Classic/Era every bank container (main bank `-1` plus
  `BankBag_1..7`) renders as its own physical section, like the backpack.

Coverage: `spec/bags/bank_spec.lua` ("Classic/Era Bank OnCreate Bag Slots Panel"),
`spec/frames/contextmenu_spec.lua` (classic bank toggles like the backpack; retail
bank still persists `showBankTabs`), and `spec/bank_tab_category_routing_spec.lua`
("Bank Show Bags (SECTION_ALL_BAGS) partition by client flavor").
