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
