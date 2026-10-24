# BetterBags Next: the Plain theme

Asked (2026-10-24): "a new theme: Plain. the Plain theme looks like the default UI for the version of WoW we're
playing on. This will likely need some new things in Sonata to support different texture paths per wow version
(classic, retail, etc). look at our Original betterbags default theme to figure out what we did there."
Decisions (asked, answered): the tabs are left to me; header buttons without Blizzard art keep BetterBags' glyphs in
Blizzard's colors; the full-height docked bag gets the whole frame, its top and bottom at the screen edge.

## What the original Default did

`sonata/themes/default.lua` names no art: it creates Blizzard's own frame templates by name (`DefaultPanelTemplate`,
`DefaultPanelFlatTemplate`, `UIPanelCloseButton`), and each client draws its own version of them. Per-client overrides
(`Clients`) only fix the Show Bags panel where a client's template drew wrong. Next cannot host Blizzard's template
frames: its panels draw themselves from theme data, mirror on the left of the screen, slide, morph between sizes and
chain. So Plain draws Blizzard's art through Next's own drawing, from data.

Per-version textures need no new mechanism: Next themes already take `Clients` overrides through the shared resolver
(`sonata/resolve.lua`: Retail, Forever, Classic, Era, TBC, Anniversary, Mists, Cata). What Next lacks is drawing
pieces for how Blizzard builds its frames.

## What Blizzard draws (from `.libraries/wow-ui-source`, branches live, forever, classic, classic_era, classic_anniversary)

- **Retail bags** (`ContainerFrameCombinedBags`, `Mainline/ContainerFrame.xml`): `PortraitFrameFlatTemplate` with
  `layoutType = HeldBagLayout` (`Mainline/NineSliceLayouts.lua`: `ui-frame-portraitmetal-cornertopleftsmall` at -13,16,
  the metal corners and edges). Fill: `FlatPanelBackgroundTemplate` colored `PANEL_BACKGROUND_COLOR`, inset 2,-20 to
  -2,3. Portrait: `Interface/Icons/Inv_misc_bag_08`, 36 x 36 at -4,1 (`ContainerFrame_OnLoad`), round through
  `Interface\CharacterFrame\TempPortraitAlphaMask` (2,0 to -2,4 of the portrait). Title: `GameFontNormal`, its
  container 35 in (`SetTitleOffsets(35)`) to 24 from the right, the text at its top less 5, centered. Close:
  `UIPanelCloseButtonDefaultAnchors`, TOPRIGHT 1,0, 24 x 24, `RedButton-Exit`, `-pressed`, `-Disabled`,
  `RedButton-Highlight` (ADD). The bank and the vendor show the NPC (`SetPortraitToUnit("npc")`). HeldBagLayout exists
  on retail and Forever only.
- **The settings window, every client** (`Blizzard_Settings_Shared/<Mainline|Classic>/Blizzard_SettingsPanelTemplates.xml`):
  `FlatPanelBackgroundTemplate` 7,-18 to -3,3, `layoutType = ButtonFrameTemplateNoPortrait` (retail: the metal; Classic:
  `UI-Frame-TopLeftCornerNoPortrait`, `_UI-Frame-TitleTile` ...), title `GameFontNormal` at the top less 5, 60 in from
  each side; Classic adds `_UI-Frame-TitleTileBg` 8,-3 to 0,-3. Close: retail as above; Classic 32 x 32 at 4,4,
  `Interface\Buttons\UI-Panel-MinimizeButton-Up`, `-Down`, `-Disabled`, `-Highlight` (ADD).
- **Controls, the same art on every client**: check box `checkbox-minimal`, `checkmark-minimal`,
  `checkmark-minimal-disabled` (`SettingsCheckboxTemplate`); slider `Minimal_SliderBar_Left`, `_Minimal_SliderBar_Middle`,
  `Minimal_SliderBar_Right` at their atlas sizes, thumb `Minimal_SliderBar_Button` (`MinimalSliderTemplate`); scroll bar
  8 wide, track `minimal-scrollbar-track-top`, `!minimal-scrollbar-track-middle`, `-bottom`, thumb
  `minimal-scrollbar-small-thumb-top|middle|bottom` with `-over` and `-down` (`MinimalScrollBar`); dropdown
  `common-dropdown-classic-textholder` 9,8 to 8,9 past the button, arrow `common-dropdown-classic-a-buttonDown`
  (`WowStyle1DropdownTemplate`); input box `common-search-border-left|middle|right`, 20 tall, caps 8, the left one 5
  past the box (`InputBoxVisualTemplate`); button `Interface\Buttons\UI-Panel-Button-Up|Down|Disabled` in three pieces
  (caps 12 wide, TexCoords 0-0.09375, 0.09375-0.53125, 0.53125-0.625 by 0-0.6875), highlight
  `UI-Panel-Button-Highlight` (ADD) over it (`UIPanelButtonNoTooltipTemplate`, `UIPanelButton_OnMouseDown`); bag sort
  button `bags-button-autosort-up|down`.
- **Menus** (`Blizzard_Menu/<Family>/MenuTemplates.lua`): retail `common-dropdown-bg` 10,3 past the menu at 0.925;
  Classic `common-dropdown-classic-bg` 3,3,3,4 past it over black at 0.8 inset 6.
- **Dialogs** (`StaticPopupBaseTemplate`, `DialogBorderTemplate`): the `Dialog` nine-slice layout over
  `Interface\DialogFrame\UI-DialogBox-Background` tiled, inset 7, on every client.
- **Lists** (`Blizzard_CategoryList.lua`): a selected row `Options_List_Active` with `GameFontHighlight`, under the
  pointer `Options_List_Hover`, idle `GameFontNormal`; group headers `Options_CategoryHeader_<n>`.
- **Tabs**: Blizzard has no sideways text tabs (its tab art turns only 180 degrees, `TabSystemButtonArtMixin`). Plain's
  side tabs are drawn as Blizzard's list rows: the panel's color, `Options_List_Hover` under the pointer,
  `Options_List_Active` when selected, gold and white text.
- **Colors**: `Color.lua` (`Blizzard_SharedXMLBase`, every client) makes each of the client's named UI colors
  (`C_UIColor.GetColors`) a Lua global (`PANEL_BACKGROUND_COLOR`, ...).
- **Nine-slice placement** (`Blizzard_SharedXML/NineSlice.lua`, every client): corners at their corner by x,y, at their
  atlas size; edges between their corners (x,y and x1,y1), tiled as the atlas says (`C_Texture.GetAtlasInfo`
  `tilesHorizontally`/`tilesVertically`); the center between the top-left and bottom-right corners; `mirrorLayout`
  flips the coordinates of the mirrored pieces. `NineSliceUtil.GetLayout(name)` returns the client's table (Forever's
  overrides included).

## What Next gains (each test first)

1. **Blizzard's colors by name**: a palette entry `{ Global = "PANEL_BACKGROUND_COLOR" }` is that global's color, read
   when the theme applies. Themes stay data.
2. **Frames**: `Frame = { Layout = "HeldBagLayout" }` draws Blizzard's nine-slice layout of that name, read from the
   client, with the client's art and offsets; or `Frame = { Pieces = { TopLeftCorner = {...}, ... } }`. Drawn mirrored
   on panels whose inner side is on the right. On panels (`Panel.Frame`), the settings window (`Settings.Frame`),
   dialogs (`Controls.Dialog.Frame`) and menus (`Controls.Menu.Frame`).
3. **Pieced fills and outsets**: a fill drawn as a begin cap, a middle and an end cap (`Pieces = "Horizontal"` or
   `"Vertical"`, caps at their atlas size or `Size`, a thickness `Thickness`), and drawn past its frame (`Outset`). On
   buttons (with a `Highlight` over the fill under the pointer), sliders, scroll bars, inputs, dropdowns and menus.
4. **Header button states**: an icon's `Pushed` art while pressed and `Disabled` art while disabled.
5. **Blizzard's search box**: `Search.Template = true` keeps the template's own border.
6. **Ornaments**: atlases, round masks (`Mask`), and unit portraits (`Unit = "npc"`, with the ornament's art when there
   is no such unit).
7. **Centered titles** and **fill insets**: `Header.Title.Justify = "CENTER"` between `TitleInset` and the outer
   buttons; `Panel.Fill.Inset = { Inner, Outer, Top, Bottom }` (replacing `Panel.Fill.Top`).
8. **Tab highlights**: `Tabs.Highlight` (under the pointer) and `Tabs.SelectedHighlight`, art over the tab's fill;
   settings sidebar group headers in art.

## The theme (`sonata/themes/next/plain.lua`)

- **Retail and Forever**: the retail bags window: `HeldBagLayout`, the panel's color inset as Blizzard insets it, the
  round portrait (the bag's icon, the NPC on the bank and vendor), a centered gold title, the red close button, the
  sort button's own art; the settings window in `ButtonFrameTemplateNoPortrait`.
- **Classic, Era, TBC, Anniversary, Mists, Cata** (`Clients.Classic`): Classic's settings window frame
  (`ButtonFrameTemplateNoPortrait`, Classic's art) and title band for the bags and the settings window, no portrait,
  Classic's close button.
- **Everywhere**: the controls above, the list rows for tabs and the settings sidebar, `GameFontNormal`,
  `GameFontHighlight` and the client's small fonts; no sparkles, feather, wash, ribbon, cloud, glow or braid.
- **Verification**: a spec checks, per client, that every atlas and file Plain names appears in that client's branch of
  Blizzard's UI source (`install-deps.sh` clones it with every branch).
