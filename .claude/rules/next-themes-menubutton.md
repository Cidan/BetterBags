---
paths:
  - "next/menubutton.lua"
  - "spec/next/menubutton_spec.lua"
---
## 19. The bag button (`next/menubutton.lua`, `Header.Buttons.Menu`)

**Why.** Asked, of the Plain theme: "remove all top bar buttons, make sure our bag title is always correctly centered from
the right of the bag button, to the left of the close button", "bring back the drop down menu with these options, just
like the original bags ... just the options we are removing from the bar", "same for vendors and bank", and "vendors
should have their portrait for the bag button, not the bag texture" (docs/next-plain-theme.md, round three).

- **The schema**: `Header.Buttons.Menu = { Point, Anchor, X, Y, Width, Height, Layers, Highlight, Panels }`, or nothing
  (Default). `Point` is a corner of the body by its side (`TOPINNER`, `TOPOUTER`, `BOTTOMINNER`, `BOTTOMOUTER`), the
  button placed by its own `Anchor` (the same corner when unset), `X` toward the body's middle and `Y` down, as an
  ornament's corner piece (next-themes-ornaments.md §12), mirrored on a panel whose inner side is on the right. Each of its `Layers` (in order,
  each over the one before; `Layer`, `SubLevel`) is a file (`Texture`, `TexCoords`), an atlas, a unit's portrait (`Unit`:
  while the client has the unit, `SetPortraitTexture`; nothing while it has none) or only a `Color` (filled with it),
  inset into the button (`Inset`: `Left`, `Right`, `Top`, `Bottom`; negative reaches past), cut by a `Mask`, never
  flipped; `Highlight` the same over them, faded in under the pointer (`Time.Hover`) to its `Alpha`. `Panels` gives a
  panel its own keys over the rest (`Backpack`, `Bank`, `Vendor`, `GuildBank`, as ornaments name them): the vendor's
  portrait. The art and masks are drawn with the ornaments' own functions (`NextOrnaments:DrawArt`, `Cut`).
- **The row goes in its menu**: while a theme has one, every header button that is not pinned (next-themes-ornaments.md §13) goes under a hidden
  frame (`panel.menuHolder`), so the panel's own showing and hiding of it (a vendor that repairs, a game rule) still
  decides whether the menu lists it, and back on the panel's frame (over its overlay) for a theme without one, at the
  level it had: a new parent changes a frame's level (Blizzard's LFDFrame.lua: "Setting a new parent changes the frame
  level"), so `holdRow` reads each button's level before `SetParent` and sets it back after, as Blizzard's
  `FrameUtil.SetParentMaintainRenderLayering` does. **Failure mode (fixed, reported):** after Plain and back to Default,
  the header buttons did nothing until a reload: back at one above the panel, they sat under a small panel's mover (over
  the title row, taking the mouse to move it). The specs' frame mock kept a frame's level across `SetParent`, which hid
  it; it now gives a reparented frame one above its new parent, the level a new child gets. The title
  then starts at the button's far edge (`panel:TitleStart`, `NextMenuButton:Room`) and ends at the pinned buttons
  (`pinnedRoom`, now counting a pin's offset by its direction: one out past the edge takes less room), with no slack, so a
  centered title is centered between the two.
- **The menu** (a left click; its tooltip says so): the original bags' menu, `ContextMenu` (LibUIDropDownMenu's
  `EasyMenu`, frames/contextmenu.lua), the same drop-down: the title line (`BetterBags` and the version), then the header
  buttons the panel shows that are not pinned, in their order, those saying `menuLast` (Open Options Screen, last in the
  original menu too) at the end. Each entry is its button's `label` (else its `tooltip`), checked for a toggle
  (`checked`), disabled as its button is (`IsEnabled`), with its tooltip (`menuTooltip`, else its `tooltip` when that is
  not its name), read as the menu opens (the library calls back on entering an entry only on retail); a click runs its
  `onClick`. Each panel's buttons say so (`NextHeaderButton`): the backpack's Sort Bags, Show Blizzard Bags and Small Bags
  (checked), the bank's Show Bank Tabs (checked), Deposit Warbank Items and Sort Bank, the vendor's Filter, Sell Junk,
  Repair All and Repair With Guild Funds (their costs: `RepairLines`, shared with the header's tooltips), the guild bank's
  Deposit Gold and Withdraw Gold (`WithdrawLines`), Open Options Screen last on each. The vendor's filter opens from the
  bag button while the filter button is in the menu (`OpenFilter`).
- **An item dropped on it** (issue #1270, next-category-picker.md): in a theme whose `Header.ItemDrop.Target` is
  `"Menu"` (Plain), on a panel that files items (the backpack, the bank), an item dropped or left-clicked onto the button
  opens the category picker under it in place of its menu (asked: "drag an item to the bag name (or in the case of Plain,
  the bag button ...)"), as the original bags' button made a category of one; while an item is held over it, its
  highlight lights and its tooltip says what a drop does (`NextCategoryPicker:Hint`). Anything else held (a merchant's
  item) leaves it the menu button it is.
- **Drawn again on each show** (`Paint`), so a vendor's portrait is the vendor now.
- **Checked** (`SonataNext:Check`): a corner by its side, the size, art in every layer (its own and each panel's), the
  panels it names.
- **Coverage**: `spec/next/menubutton_spec.lua` (hidden without one; its corner, mirrored, above the overlay; its room;
  layers inset and never flipped; a panel's own layers: a color, a portrait while there is a unit, a mask, a ring; layers
  put away; the highlight; the menu: the title, the order, Open Options Screen last, checked, disabled, tooltips, a click,
  buttons not shown), `spec/next/theme_panel_spec.lua` ("a header row in a menu": the row out and back, the title centered
  on either side, the backpack's entries, drawn on show; Plain's bag button on Retail and Era),
  `spec/next/vendor_spec.lua` ("in a bag button's menu": what the vendor offers, repair costs and the guild's repair, the
  filter's owner), `spec/next/bank_spec.lua` and `spec/next/guildbank_spec.lua` (their entries), `spec/sonata/next_engine_spec.lua`
  ("names what is wrong with a bag button"). Mutation-tested with the rest of round three: 58 mutations, 53 caught at once;
  two survivors led to tests, three showed code that changed nothing, removed (restoring the row's frame level after its
  new parent: levels stay what they were set to since 7.0.3, warcraft.wiki.gg Frame Strata; the row's width and layout
  while it waits in the menu).
