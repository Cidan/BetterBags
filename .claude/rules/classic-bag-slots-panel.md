# "Show Bags" Slots Panel: Classic Flat Panel & Centering

This documents how the bag-slots panel (the "Show Bags" slide-out created by
`BagSlots:CreatePanel`, `frames/bagslots.lua`) is themed and laid out, and why
Classic/Era diverge from Retail.

## 1. Retail themes it; Classic/Era draw a self-contained flat panel

On **Retail** the panel frame is registered as a themed flat window
(`themes:RegisterFlatWindow(f, "")`) and the active theme's `Flat` decoration
draws its background/border.

On **Classic/Era** (`not addon.isRetail`) the panel is **not** registered as a
themed flat window. The Default theme's `Flat` uses Blizzard's
`DefaultPanelFlatTemplate`, and on Classic that template's `NineSlice` sibling
paints a 28px `_UI-Frame-TitleTile` **title-bar band** at the top
(`Blizzard_SharedXML/Classic/NineSliceLayouts.lua`), which `TitleContainer:Hide()`
in `themes/default.lua` cannot suppress (the band lives on the NineSlice, not the
TitleContainer). The result was an empty title bar on the classic "Show Bags"
panel. So `CreatePanel` instead gives the frame (created with `"BackdropTemplate"`)
its own flat backdrop — `Interface/Tooltips/UI-Tooltip-Background` +
`UI-Tooltip-Border`, no title bar, no close button. `BackdropTemplate` +
`SetBackdrop` is byte-for-byte identical across Retail, MoP, TBC, and Vanilla, so
this is safe cross-version.

## 2. Centering: symmetric padding on Classic, header-aware on Retail

`bagSlotProto:Draw` sizes the frame to wrap the grid and positions the grid
container. The grid is scrollable-with-hidden-scrollbar, so its content sits at the
top-left of a larger region unless the region is sized to exactly the content.

- **Retail:** reserve the themed header band at the top (`themes:GetFlatHeaderHeight`,
  30 for Default) plus 12px at the bottom — unchanged legacy behavior.
- **Classic/Era:** there is no header band, so wrap the grid with **equal padding on
  all sides** (`CLASSIC_PADDING = 8`): `frame = content + 2*PAD`, container inset by
  `PAD` on every edge. Equal insets make the container exactly the content size, so
  the bags are centered both horizontally and vertically instead of clinging to the
  top-left.

Do **not** feed `GetFlatHeaderHeight` into the Classic path — its 30px Default
return reserves a phantom header the classic panel no longer has, which pushed the
bags off-center (the reported bug). Coverage: `spec/frames/bagslots_spec.lua`
("centers the bags with symmetric padding on Classic/Era", "keeps the retail
themed-header layout unchanged").

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
  view (`SECTION_ALL_BAGS` / previous view). It never writes `showBankTabs`. The GW2
  theme's duplicate "Show Bags" panel button (`themes/gw2.lua`) uses the same retail
  gate. Re-opening the bank restores the panel from the view:
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
