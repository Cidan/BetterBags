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
  `onClick`. Each panel's buttons say so (`NextHeaderButton`): the backpack's anchor (while small, named for what a click
  does next: Show Bag Anchor, Lock Bag, Unlock Bag; next-bag-anchor.md §30b; it replaced Sort Bags, its title sorting on a
  right click), Show Blizzard Bags and Small Bags (checked), the bank's Show Bank Tabs (checked), Deposit Warbank Items and its
  anchor (it replaced Sort Bank), the vendor's Filter, Sell Junk,
  Repair All and Repair With Guild Funds (their costs: `RepairLines`, shared with the header's tooltips), the guild bank's
  Deposit Gold and Withdraw Gold (`WithdrawLines`), Open Options Screen last on each. The vendor's filter opens from the
  bag button while the filter button is in the menu (`OpenFilter`).
- **What only the menu offers** (asked: "add the missing button interactions to the plain drop down menu ... minimize/
  maximize bags, etc, whatever is missing"): after the row, before Open Options Screen, the panel's `MenuEntries()`, each
  a header button's spec without its button (`label`, `checked`, `menuTooltip`, `onClick`; always enabled): what a right
  click on its title does, named by `TitleRightClickLabel()` (the backpack's Sort Bags, the bank's Sort Bank where the client
  can sort it; the vendor and the guild bank have none), and the switch to small bags (`SizeEntry()`, the backpack's size
  button's own spec: one switch for every bag, `nextPanel:SetSize`) on a panel with no size button of its own (the bank, the
  vendor, the guild bank). The backpack: Show Blizzard Bags, Small Bags, Sort Bags; the bank: Show Bank Tabs, Deposit
  Warbank Items, Sort Bank, Small Bags; the vendor: its row, Small Bags; the guild bank: Deposit Gold, Withdraw Gold, Small
  Bags (each with its anchor while small, and Open Options Screen last). Only a theme with a bag button lists them: no
  theme gains a header button. Measured before: every header button was in its menu; the title's sort and the companions'
  size switch were nowhere.
- **A right click** (reported: "right clicking the bag button on plain doesn't seem to sort bags like it does on the other
  themes", where the title's right click sorts) runs the panel's `OnTitleRightClick`, the title's own, its menu closed: the
  backpack and the bank sort (the bank through the original bags' button's `Sort`: the Warbank on a Warbank tab, Shift
  depositing, bag-menu-button.md §1), the vendor and the guild bank do nothing. Its tooltip adds "Right Click" and the
  action's name under "Left Click: Open Menu", as the original's right click line did (frames/menubutton.lua), only where
  there is one. The original's "Shift Right Click: Deposit Warbank Items" line is not there: Shift on the bank's sort
  deposits, through the original button's `Sort`, as it does on the title's right click and the menu's Sort Bank, and no
  tooltip of Next's says so (left out, as agreed: Deposit Warbank Items is in the bank's menu). The button takes
  `LeftButtonUp` and `RightButtonUp`; a right click with an item held sorts, as the title's does, and a left click with
  one opens the category picker.
- **Not built for** (raised by the bug review, unseen): the context menu is not closed as its panel hides, so its entries
  can be clicked after the bank closes (Sort Bank, as Deposit Warbank Items could before); nothing has shown what the
  client does with a bank sort away from the bank.
- **An item dropped on it** (issue #1270, next-category-picker.md): in a theme whose `Header.ItemDrop.Target` is
  `"Menu"` (Plain), on a panel that files items (the backpack, the bank), an item dropped or left-clicked onto the button
  opens the category picker under it in place of its menu (asked: "drag an item to the bag name (or in the case of Plain,
  the bag button ...)"), as the original bags' button made a category of one; while an item is held over it, its
  highlight lights and its tooltip says what a drop does (`NextCategoryPicker:Hint`). Anything else held (a merchant's
  item) leaves it the menu button it is.
- **Drawn again on each show** (`Paint`), so a vendor's portrait is the vendor now.
- **Its reach** (`menuButton:Reach(M, unit)`): how far the theme's button reaches past the body's top and past its bottom,
  as `Style` places it on a grid of `unit`, each offset and size in whole pixels of it as `Style` rounds them (`Y` and the
  insets by `pixel:Snap`, the height by `pixel:Size`): its anchor `Y` below its corner (one anchored by its bottom at a top
  corner reaches its `Height` further), and its art past it (each layer's and the highlight's `Inset`, negative reaching past); the most of every
  panel's own (`Panels`, merged as `Spec` merges them, `over`), so every panel docks the same; none without a button.
  Plain's reaches 17 above (15, its art 2 more). A docked panel keeps it clear of the screen's top and bottom
  (`Panel.DockMargin`, next.md §3).
- **Checked** (`SonataNext:Check`): a corner by its side, the size, art in every layer (its own and each panel's), the
  panels it names.
- **Coverage**: `spec/next/menubutton_spec.lua` (hidden without one; its corner, mirrored, above the overlay; its room;
  layers inset and never flipped; a panel's own layers: a color, a portrait while there is a unit, a mask, a ring; layers
  put away; the highlight; the menu: the title, the order, Open Options Screen last, checked, disabled, tooltips, a click,
  buttons not shown, the panel's own entries; a right click and its tooltip line, none where there is nothing; its reach:
  above the top, a panel's own, its own anchor, a bottom corner, none), `spec/next/theme_panel_spec.lua` ("a header row in
  a menu": the row out and back, the title centered on either side, the backpack's entries with Sort Bags, its right click
  and tooltip line, the bank's Small Bags switching every bag, drawn on show; Plain's bag button on Retail and Era),
  `spec/next/vendor_spec.lua` ("in a bag button's menu": what the vendor offers with Small Bags, repair costs and the
  guild's repair, the filter's owner), `spec/next/bank_spec.lua` (its entries with Sort Bank and Small Bags, a right click
  sorting as the title's does, none where the client cannot sort), `spec/next/guildbank_spec.lua` (its entries with Small
  Bags), `spec/sonata/next_engine_spec.lua`
  ("names what is wrong with a bag button"). Mutation-tested with the rest of round three: 58 mutations, 53 caught at once;
  two survivors led to tests, three showed code that changed nothing, removed (restoring the row's frame level after its
  new parent: levels stay what they were set to since 7.0.3, warcraft.wiki.gg Frame Strata; the row's width and layout
  while it waits in the menu).
