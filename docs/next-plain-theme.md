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

## What Blizzard draws (from `.libraries/wow-ui-source`, branches live, forever, classic_era, classic_anniversary, classic)

Read from the files each client loads (its TOCs, below), retail at build 12.1.5 (70575): none of the files these come
from changed since 70448, where the first reads were made.

- **Retail bags** (`ContainerFrameCombinedBags`, `Mainline/ContainerFrame.xml`): `PortraitFrameFlatTemplate` with
  `layoutType = HeldBagLayout` (`Mainline/NineSliceLayouts.lua`: `ui-frame-portraitmetal-cornertopleftsmall` at -13,16,
  the metal corners and edges). Fill: `FlatPanelBackgroundTemplate` colored `PANEL_BACKGROUND_COLOR`, inset 2,-20 to
  -2,3. Portrait: `Interface/Icons/Inv_misc_bag_08`, 36 x 36 at -4,1 (`SetPortraitTextureSizeAndOffset(36, -4, 1)`),
  round through `Interface\CharacterFrame\TempPortraitAlphaMask` (2,0 to -2,4 of the portrait), at frame level 400:
  the metal (`NineSlicePanelTemplate`, 500) is over it, the title and close (510) over both. Title: `GameFontNormal`, its
  container 35 in (`SetTitleOffsets(35)`) to 24 from the right, 1 down, the text 5 below its top, centered. Close:
  `UIPanelCloseButtonDefaultAnchors`, TOPRIGHT 1,0, 24 x 24, `RedButton-Exit`, `-pressed`, `-Disabled`,
  `RedButton-Highlight` (ADD). The bank and the vendor show the NPC (`SetPortraitToUnit("npc")`). HeldBagLayout exists
  on retail and Forever only. Sort: `bags-button-autosort-up`, `-down`, 28 x 26, `ButtonHilight-Square` (ADD) 24 x 23
  centered.
- **The settings window, every client** (`Blizzard_Settings_Shared/<Mainline|Classic>/Blizzard_SettingsPanelTemplates.xml`):
  `FlatPanelBackgroundTemplate` 7,-18 to -3,3, `layoutType = ButtonFrameTemplateNoPortrait` (retail: the metal; Classic:
  `UI-Frame-TopLeftCornerNoPortrait`, `_UI-Frame-TitleTile` ...), title `GameFontNormal` at the top less 5, 60 in from
  each side; Classic adds `_UI-Frame-TitleTileBg` 8,-3 to 0,-3 in the frame's own `BACKGROUND` -6 layer. Close: retail
  as above; Classic 32 x 32 at 4,4, `Interface\Buttons\UI-Panel-MinimizeButton-Up`, `-Down`, `-Disabled`, `-Highlight`
  (ADD). Its tabs are `MinimalTabTemplate` (below).
- **Controls, the same art on every client**: check box `checkbox-minimal`, `checkmark-minimal`,
  `checkmark-minimal-disabled` (`SettingsCheckboxTemplate`, 30 x 29; a disabled setting's whole row desaturated,
  `DisplayEnabled`), a setting's row lit white at 0.1 under the pointer (`HoverBackgroundTemplate`); slider 19 tall,
  `Minimal_SliderBar_Left`, `_Minimal_SliderBar_Middle`, `Minimal_SliderBar_Right` at their atlas sizes, the caps by
  `LEFT` and `RIGHT`, the middle hung from their tops, thumb `Minimal_SliderBar_Button` at its atlas size
  (`MinimalSliderTemplate`); scroll bar 8 wide, track `minimal-scrollbar-track-top`, `!minimal-scrollbar-track-middle`,
  `-bottom`, thumb `minimal-scrollbar-small-thumb-top|middle|bottom` with `-over` and `-down`
  (`MinimalScrollBar`, `MinimalScrollBarThumbScriptsMixin`); input box `common-search-border-left|middle|right`, 20
  tall, caps 8, the left one 5 past the box (`InputBoxVisualTemplate`), its text `GameFontHighlightSmall` and help
  `GameFontDisableSmall` (`InputBoxInstructionsTemplate`), the bag search box's magnifier gray (0.6) while empty and not
  typed in, white otherwise (`SearchBoxTemplate_OnEditFocusLost`); button `Interface\Buttons\UI-Panel-Button-Up|Down|Disabled`
  in three pieces (caps 12 wide, TexCoords 0-0.09375, 0.09375-0.53125, 0.53125-0.625 by 0-0.6875), highlight
  `UI-Panel-Button-Highlight` (ADD, 0-0.625 by 0-0.6875) over it, 22 tall, its text and 40, at least 40,
  `GameFontNormal`, `GameFontHighlight`, `GameFontDisable` (`UIPanelButtonNoTooltipTemplate`, `UIPanelButton_OnMouseDown`).
- **Dropdowns and menus** (`Blizzard_Menu/<Family>/MenuTemplates.*`, `MenuVariants.lua`, `Compositor.lua`):
  - Retail: `WowStyle1DropdownTemplate` 25 tall, `common-dropdown-textholder` 8,7 to 8,9 past it, its text
    `GameFontHighlight` 8 in, the arrow `common-dropdown-a-button` at its atlas size by its right at RIGHT 1,-3, in
    `-hover`, `-pressedhover`, `-pressed`, `-open`, `-disabled` (`GetWowStyle1ArrowButtonState`), the text gray while
    disabled; `MenuStyle1Mixin` `common-dropdown-bg` 10,3 past the menu at 0.925, the list 8, 8, 8, 15 in; radios
    (`CreateRadio`) the `common-dropdown-tickradial` ring on every row, `common-dropdown-icon-radialtick-yellow` over it
    at its top left on the chosen one.
  - Classic: 24 tall, `common-dropdown-classic-textholder` 9,8 to 8,9 past it (`-small` at 100 wide or less), its text
    `GameFontHighlightSmall` 9 in, justified right, the arrow `common-dropdown-classic-a-buttonDown` by its right at
    RIGHT -1,0 in `-hover`, `-pressedhover`, `-pressed`, `-disabled`; the menu `common-dropdown-classic-bg` 3,3,3,4 past
    it over black at 0.8 6 inside it, the list 16, 10, 16, 10 in; radios (Vanilla and Cata) the
    `common-dropdown-tickradial-classic` ring, swapped for `common-dropdown-icon-radialtick-yellow-classic` when chosen.
  - Every client: a row's text `GameFontHighlight`, `Interface\QuestFrame\UI-QuestTitleHighlight` (ADD) over the row
    under the pointer.
- **Dialogs**: today's popup (`Blizzard_StaticPopup_Game/GameDialog.lua`, `GameDialogBaseMixin:OnLoad`) is
  `UI-DialogBox-Background-Dark` 7 in under `UI-DiamondDialogBox-Border` (retail) or `UI-DiamondDialogBox-ClassicBorder`
  (Classic) over the whole popup, its text `GameFontHighlight`. The first plan read `DialogBorderTemplate` (the `Dialog`
  layout over the light background), which the popup no longer uses.
- **Lists** (`Blizzard_CategoryList.lua`): rows 20 tall, a selected one `Options_List_Active` at its atlas size,
  centered, with `GameFontHighlight`; under the pointer `Options_List_Hover`, its font kept; top-level rows
  `GameFontNormal`, the text 1 above the middle; group headers 30 tall, `Options_CategoryHeader_<n>` (cycled 1 to 3) at
  their top left, `GameFontHighlightMedium` 20 in and 1 down; 2 between every element (the view's spacing).
- **Tabs**: the settings window's are `MinimalTabTemplate`: 37 tall, 5 apart, as wide as their text and 40,
  `Options_Tab_Left|Middle|Right` (`Options_Tab_Active_*` selected) at their atlas sizes by their bottoms,
  `GameFontNormalSmall`, `GameFontHighlightSmall` under the pointer and selected, the text 4 above the bottom (6
  selected). Blizzard has no sideways text tabs (its tab art turns only 180 degrees, `TabSystemButtonArtMixin`). Plain's
  side tabs are drawn as Blizzard's list rows: the panel's color, `Options_List_Hover` under the pointer,
  `Options_List_Active` when selected, gold and white text.
- **Colors**: `Color.lua` (`Blizzard_SharedXMLBase`, every client) makes each of the client's named UI colors
  (`C_UIColor.GetColors`) a Lua global (`PANEL_BACKGROUND_COLOR`, ...).
- **Nine-slice placement** (`Blizzard_SharedXML/NineSlice.lua`, every client): corners at their corner by x,y, at their
  atlas size; edges between their corners (x,y and x1,y1), tiled as the atlas says (`C_Texture.GetAtlasInfo`
  `tilesHorizontally`/`tilesVertically`); the center between the top-left and bottom-right corners; `mirrorLayout`
  flips the coordinates of the mirrored pieces. `NineSliceUtil.GetLayout(name)` returns the client's table (Forever's
  overrides included).
- **Classic's portrait windows** (`PortraitFrameTemplate`, `Classic/SharedUIPanelTemplates.xml`) are separate textures,
  not a nine-slice layout (Classic's layouts have no portrait frame): `UI-Frame-Portrait` at -14,11, a 61-square round
  portrait at -6,8, `_UI-Frame-TitleTile` between it and `UI-Frame-TopCornerRight`, the side and bottom tiles and
  corners, `UI-Background-Rock` inside. They map onto Next's frame `Pieces` exactly. Plain does not use them (below).

## What Next gained (each test first)

1. **Blizzard's colors by name**: a palette entry `{ Global = "PANEL_BACKGROUND_COLOR" }` is that global's color, read
   when the theme applies.
2. **Frames** (`next/frameart.lua`, next-themes.md §15): `Frame = { Layout = "HeldBagLayout" }` draws Blizzard's
   nine-slice layout of that name, read from the client; or `Pieces`; mirrored on panels whose inner side is on the
   right; `TitleBg`, a band across the top. On panels, the settings window and dialogs.
3. **Fills** (`next/fill.lua`, §16): inset or past their frame (`Inset`, negative reaching past), at their atlas's size
   (`AtlasSize`, `Point`), or pieced (`Pieces`, caps at their atlas size or `Size`, `Thickness`, or each piece at its
   atlas's thickness with `Align`). On buttons (with a `Highlight` over the fill), sliders, scroll bars, inputs,
   dropdowns, menus (with a `Border`), dialogs (with a `Border`), the settings window, its list and page tabs.
4. **Header buttons**: an icon's `Pushed` art while pressed and `Disabled` art while disabled; `RowStart`.
5. **Blizzard's search box**: `Search.Template = true` keeps the template's own border; the magnifier's `ActiveColor`.
6. **Ornaments**: atlases, round masks (`Mask`), unit portraits (`Unit = "npc"`), `Mirror = false`, tiled spans cropped
   by `TexCoords`.
7. **Centered titles** (`Header.Title.Justify = "CENTER"`) and **fill insets** (`Panel.Fill.Inset = { Left, Right, Top,
   Bottom }`, drawn for the backpack and mirrored on the bank, replacing `Panel.Fill.Top`).
8. **Tabs and lists**: `Tabs.Highlight`, `Tabs.SelectedHighlight`; the settings list's `GroupFills`, `GroupLabel`,
   `Spacing`, `TextRaise`; page tabs' art (`Fill`, `HoverFill`, `SelectedFill`, `Padding`, `TextBottom`).
9. **Controls** (§17): atlases at their own size (`Size = "Atlas"`, `ThumbSize = "Atlas"`); the dropdown's arrow per
   state, `Justify`, `DisabledFont`, `DisabledAlpha`, `NarrowFill`; radio rings (`Check.Off`, `Check.Under`); menu
   insets per side; a button's `DisabledFont`; the settings close's `Atlas`, `Highlight`, `Offset`.
10. **Fonts copied outright** (`Copy`): the client's font as it is, nothing a Default role sets changing it.

Plain turns parts off that no theme turned off before (`Edge`, `Indicator`, `Divider`, `Line` set to false), and seven
code paths read them unguarded: Plain broke the settings window on every client. No spec saw it, because SonataNext
restyles widgets in protected calls and the mock error handler drops errors. Each is now guarded, with a test.

## The theme (`sonata/themes/next/plain.lua`)

As of round two (below):

- **The bags, every client**: the original BetterBags bag window (`DefaultPanelTemplate`'s look:
  `ButtonFrameTemplateNoPortrait` in the client's art, drawn above the content; the rock and its streaks; Classic's title
  band), the original menu button's bag icon (`Bagslots2x`) over the top inner corner on every bag, a centered gold title,
  the search box where the original put it with `SearchBoxTemplate`'s insides, the sort button's own art.
- **The settings window, every client**: Blizzard's settings window (920 x 724) in the same stone: its name in the title
  bar, `Options_InnerFrame`, the category list, the search box at the top right, page tabs on the inner frame's edge, the
  page as Blizzard's settings list, `WowStyle2` dropdowns and `MinimalSliderWithSteppers` sliders with their steppers,
  Done and What's New at the bottom right.
- **Retail and Forever** (`Clients.Retail`): the red close button, the retail menus, the popup's retail border.
- **Classic, Era, TBC, Anniversary, Mists, Cata** (`Clients.Classic`): Classic's close button, Classic's menus, the
  popup's Classic border.
- **Everywhere**: the panel button, the input border, the settings check box and scroll bar, the list rows for the bags'
  side tabs, `MinimalTab` page tabs, the client's fonts copied outright; no sparkles, feather, wash, ribbon, cloud, glow or
  braid.

## How it was checked

- **Each client's files**: `spec/helpers/ui_source.lua` resolves the files a client loads from its branch, by the TOC
  format's rules (warcraft.wiki.gg "TOC format"): each addon's TOC by suffix (`_Standard`, `_Camelot`, `_Vanilla`,
  `_TBC`, `_Mists`, then `_Mainline` or `_Classic`, then none), `AllowLoadGameType` and `ExcludeLoadGameType` on the addon
  and on each line (game types `standard`, `camelot`/`forever`, `vanilla`, `tbc`, `mists`; families `mainline`,
  `classic`), `[Family]`, `[Game]` and `[TextLocale]` expanded, glue-only and other locales' lines skipped, and the files
  XML pulls in. A branch carries every game type's folders, and a whole addon can be one game type's (the damage meter
  is `standard` only, yet its art is in an unflavored file), so "used somewhere in the branch" proves nothing. Retail
  loads 3,594 files, Forever 3,574, Classic Era 2,110, Anniversary 2,132, Mists Classic 2,323; a second resolver
  (Python, outside the repository) agreed file for file but for two locale-only lines it read loosely.
- **The art**: `spec/sonata/plain_art_spec.lua` resolves Plain as each client does and checks that every atlas, Blizzard
  file, nine-slice layout, font and named color it names is used by code that client loads: 60 atlases, 13 files, 3
  layouts, 14 fonts. Mutation-tested: a misspelled atlas fails on every client, retail's menu art on Classic fails on the
  three Classic clients only.
- **Every window**: `spec/next/shipped_themes_spec.lua` draws the settings window, every control, menus and dialogs, and
  `spec/next/pixel_perfect_spec.lua` the bags, with every shipped theme as every client resolves it, failing on anything
  sent to the error handler.
- `install-deps.sh` clones the UI source with every branch, shallow (86 MB).

## Not matched, or left for testing in game

- **The bag's header row and footer** stay Next's (its buttons in the title bar, the free slots and money below): the
  original bags put their sort and size buttons elsewhere, and Blizzard's bags differ again.
- **Header buttons are square**: the sort button is 24 square, Blizzard's 28 x 26.
- **The bag icon has no glow under the pointer**: the original's glow belongs to its menu button, and the icon here is
  art, not a button.
- **The scroll thumb's middle** is stretched; Blizzard crops it to the thumb's height (`OnSizeChanged`).
- **The check box's art** fills its 30 x 29 box; whether the client sizes a button's state textures to their atlas
  (`useAtlasSize` on `NormalTexture`) is not known from the source.
- **The settings search box** is Next's field with Blizzard's border and magnifier: its magnifier 6 in and its text after
  it, where Blizzard's are 1 and 16 in (the bags' search box has the template's numbers).
- **Classic's frame's right edge**: Blizzard's own layout gives its right tile two different x offsets (−8 at its top
  anchor, +8 at its bottom); Next sets the same anchors, so it draws as Blizzard's Classic windows do, but which the
  client honors is not known from the source, and the preview could not show it.
- Checked against Blizzard's source, the client's atlas data and the specs, and looked at drawn with the client's own
  textures; not yet seen in game after round two.

## Round two: what testing in game found (2026-10-24)

Reported with screenshots: the window background is "this transparent thing", not the stone of the original bag
windows and the What's New window; the search box is "completely off"; the bag icon should be the original bags'; the
settings window is wrong "in every way it can be" (the left menu's headers misaligned, sidebar textures spilling out
of the window, things on the wrong layers, the BetterBags text misaligned, no control spaced right, the tabs
hideous). Each cause below was confirmed from a geometry dump of the Plain windows through the specs' layout resolver
(`spec/helpers/layout.lua`), from Blizzard's templates in the files each client loads, and from the client's own atlas
sizes (`UiTextureAtlasMember`, read through wago.tools for builds 12.1.5.70575, 1.60.1.70532, 1.15.9.70003,
2.5.6.70006 and 5.5.4.70579: the sizes below are the same on all five).

### Why round one shipped like this

- **Nothing checked Plain's layout against Blizzard's.** The specs checked that Plain's names exist on each client and
  that every part lands on whole pixels, not that a part is where Blizzard puts it.
- **The specs had no atlas sizes.** Art drawn "at its atlas's size" (the list rows and headers, the tabs, the slider)
  collapsed to nothing in the mock, so no test could see how big it really is. The header art is 199 x 144; it was
  drawn across the whole sidebar.
- **No one looked at it.** The art names were Blizzard's, but where each piece goes was not.

Round two adds the client's atlas sizes to the specs (`spec/fixtures/atlas_sizes.lua`), tests every placement
against Blizzard's numbers, and checks each window as a picture made from Blizzard's own textures before it ships
(a scratch tool outside the repository: the specs' layout, drawn with the client's files read through wago.tools).

### 1. The window background: the stone of the original bags

- **Asked**: the stone background of the original bag windows and the What's New window.
- **Cause**: Plain filled its windows with `PANEL_BACKGROUND_COLOR` (`FlatPanelBackgroundTemplate`, the retail bags'
  fill), which is translucent.
- **Blizzard**: the original bags and What's New are `DefaultPanelTemplate` windows (`sonata/themes/default.lua`):
  `Bg` is `Interface\FrameGeneral\UI-Background-Rock`, tiled both ways, 6 in from the left, 21 from the top, 2 from the
  right and the bottom (`BACKGROUND` -6); `TopTileStreaks` over it, 6 in to 2 from the right, 21 down
  (`_UI-Frame-TopTileStreaks`: retail an atlas, 256 x 43, tiled across; Classic the file `Interface\FrameGeneral\_UI-Frame`,
  coordinates 0-1 x 0.671875-0.9609375, 37 tall). Classic's `DefaultPanelBaseTemplate` also draws `TitleBg`
  (`_UI-Frame-TitleTileBg`, 17 tall) 7 in and 4 down, to 24 from the right; retail's has none. The original fades
  `Bg` with the bags' opacity setting.
- **Fix**: the bags and the settings window draw the rock, the streaks and (Classic) the title band, faded by the
  opacity setting. The frame art draws a list of bands across the top (`Bands`, replacing the single `TitleBg`).

### 2. The bag window: the original's frame and its bag icon

- **Asked**: the bag icon of the original bags.
- **The original** (`frames/menubutton.lua`, `sonata/themes/default.lua`): a `DefaultPanelTemplate` window
  (`ButtonFrameTemplateNoPortrait`, on every client), its border raised above the content (`NineSlice` at +500), and the
  round menu button at the top left: 40 x 40 at `TOPLEFT -10, 7`, its art `Interface\ContainerFrame\Bagslots2x`
  (coordinates 0-0.2 x 0-1) 48 x 60 centered on it, above everything (strata HIGH), a gold glow (0.2-0.3992) fading in
  under the pointer. Plain drew retail's combined bags instead (`HeldBagLayout` with a 36-pixel bag icon portrait).
- **Fix**: Plain's bags take the original's frame and icon on every client: `ButtonFrameTemplateNoPortrait` drawn above
  the content (new: `Frame.Above`, the frame on a frame of its own above the panel's content, with the title and the
  header buttons above it), the `Bagslots2x` art where the original draws it, above the frame (new: `Above` ornaments),
  on every panel (the original showed it on the backpack and the bank alike; the NPC portraits go). The glow under the
  pointer is the menu button's, and Next has no menu button there: not drawn.

### 3. The search box

- **Cause** (geometry dump, retail): the box ran from 10 in, 28 down, under the portrait's corner (36 x 36 from -4,
  -1); its magnifier was 14 square 6 in, its text 26 in, Next's own layout, not the template's.
- **Blizzard** (`SearchBoxTemplate`, every client): the magnifier 10 x 10 at `LEFT 1, -1`, the text and help 16 in and
  20 from the right (`TextInsets`), help in `GameFontDisableSmall` at 0.35 gray, the clear button 17 x 17 at
  `RIGHT -3, 0`, its icon 10 x 10 at 3, -3; 20 tall with its border caps 8 wide, the left one 5 past the box.
  The original BetterBags placed the box at `TOPLEFT 20, -30` to `-10, -50` (`sonata/themes/base.lua`), its content
  from 62 down (insets 42 plus the search's 20).
- **Fix**: Plain places the box where the original did, and the theme gives its insides the template's numbers (new:
  `Search.Inner`: `IconX`, `IconY`, `IconSize`, `TextLeft`, `TextRight`, `ClearRight`).

### 4. The settings window

Blizzard's settings window (`Blizzard_SettingsPanel.xml`, the same on every client): 920 x 724;
`Options_InnerFrame` (886 x 618: a soft inset shadow, a thin gray outline, a divider 199 in) at `TOPLEFT 17, -64`;
the category list at 18, 76, 199 wide, down to 46 above the bottom; the content from 16 right of the list to 22 from
the window's right; the search box 350 x 22, its bottom right 4 right of and 20 above the content's top right; tabs
(`MinimalTabTemplate`) at `TOPLEFT 32, -27`, 37 tall, 5 apart; Close 96 x 22 at `BOTTOMRIGHT -16, 16`, Apply left of it,
2 apart. `SettingsFrameTemplate` keeps its border at the window's own level (`useParentLevel`): content draws over it,
and is never placed under it.

- **4a. Spilling and layers.** The sidebar ran from the window's outer edge (x 0, the whole height), its fill and the
  list's art over the border. **Fix**: the list where Blizzard puts it; no sidebar fill or line.
- **4b. The list.** Rows were 232 wide, 20 tall from x 0, labels 30 in; headers stretched to the row (their art is
  199 x 144) and in capitals. **Blizzard** (`Blizzard_CategoryList.*`): rows 175 x 20, the label 36 in and 1 up
  (`GameFontNormal`, `GameFontHighlight` chosen), `Options_List_Active` / `Options_List_Hover` at their size (187 x 21)
  centered on the row; headers 175 x 30, `Options_CategoryHeader_1` to 3 at their size from the header's top left
  (their tails are faint lines down the column), the label 20 in and 1 down (`GameFontHighlightMedium`), as written;
  2 between every element. **Fix**: those numbers (new: `Nav.ItemWidth`, `Nav.GroupUpper`).
- **4c. The BetterBags text.** Next's brand (icon and name) sat in the sidebar's top 72 pixels. Blizzard's window has
  no brand: its name ("Options") is centered in the title bar (`GameFontNormal`, 5 down). **Fix**: the brand off
  (new: `Brand = false`) and the window's name in its title bar (new: `Settings.Title`).
- **4d. The tabs.** Blizzard's tab art is a hollow outlined top with no bottom (seen in the client's texture), drawn to
  sit on `Options_InnerFrame`'s top edge. Plain drew no inner frame and hung the tabs under the page header, so they
  floated. **Fix**: the inner frame (new: `Settings.InnerFrame`) and the tabs on its top edge, 27 down, from the
  content's left (new: `Settings.Tabs`), the search box at Blizzard's place (new: `Search.Place = "Top"`).
- **4e. The page.** Plain kept Next's page: two columns of cards, rows 44 tall, the control at the far right, section
  titles in capitals. **Blizzard** (`Blizzard_SettingsList.*`, `Blizzard_SettingControls.*`): a header 50 tall with
  the title (`GameFontHighlightHuge`) 7 in and 22 down and `Options_HorizontalDivider` (630 x 1) centered 50 down; the
  list from 2 below it and 15 left of the content, 25 in, 10 from the top, 9 between rows; section titles 45 tall,
  `GameFontHighlightLarge` 7 in and 16 down, as written; rows 26 tall, one column, the name 37 in (plus 15 per indent)
  up to 85 left of the row's middle; the check box from 80 left of the middle, the slider (250 wide with its steppers)
  80 left and 3 up, the dropdown (220) 48 left and 3 up, the color swatch 73 left, a button (200) 40 left; under the
  pointer the row is lit white at 0.1, 10 past its left to 5 short of its right. **Fix**: a list layout for pages (new:
  `Content.Layout = "List"` and its numbers).
- **4f. The controls Blizzard draws differently in this window.** The slider is `MinimalSliderWithSteppersTemplate`:
  back and forward steppers (`Minimal_SliderBar_Button_Left`, 11 x 19, and `_Right`, 9 x 18, 4 out from the bar), the
  value in `GameFontNormal` 25 right of it, gray and the slider at 0.7 while disabled; no box to type in. The dropdown
  is `WowStyle2DropdownTemplate` (`common-dropdown-c-button` 7 past it, the choice centered in `GameFontNormal`, an
  arrow `common-dropdown-c-button-hover-arrow` 5 below its bottom) between back and next steppers
  (`common-dropdown-icon-back`, `-next`). **Fix**: both, as Plain's settings controls.
- **4g. The footer.** Done sat 24 from the right of a 56-pixel band with a line, What's New a link at its left.
  **Fix**: Done 96 x 22 at 16, 16 from the bottom right, What's New the same size left of it, 2 apart (Blizzard's Apply
  button's place), no band or line; the version at the bottom left.
- **4h. The size.** 1000 x 720 (Default's). **Fix**: 920 x 724, so `Options_InnerFrame` fits as it does in Blizzard's.

  The dropdown's art follows its state (`WowStyle2DropdownMixin:GetBackgroundAtlas`: `-hover-1`, `-pressed-1`,
  `-pressedhover-1`, `-open`, `-disabled`), the arrow shows only under the pointer, the text is gold (gray disabled).
  Its menu is `MenuStyle2`: retail `common-dropdown-c-bg` 17 past its sides, 12 above and 22 below, the list 3, 6, 3, 7
  in; Classic loads its own after the shared one (`Blizzard_Menu.toc`: `MenuTemplates.lua`, then
  `[Family]\MenuTemplates.lua`), `common-dropdown-classic-b-bg` 3 past the sides, 1 above and 4 below, over black at
  0.8 from 7, 4 to 8, 8 inside it, the list 14 in. The art is on every client (`common-dropdown-c-button` is sliced 12
  either side, `UiTextureAtlasElementSliceData`: it stretches across).

### 5. The other windows

Dialogs and the bags' menus already followed Blizzard's (today's popup, `MenuStyle1`).

### What was done, and how it was checked

Every fix above, each test first: 4,886 specs pass, luacheck is clean, and 52 mutations of the new guards were each
caught. Each window was then drawn from the specs' layout with the client's own textures (decoded from the game files
through wago.tools; text in a stand-in font) and looked at on retail and Classic Era: the bag (the stone, the frame, the
icon, the search box) and the settings window (the General page, the Appearance page's tabs). The drawing found two
things the specs had not: the divider stretched across the header (the atlas fixture was stale, now checked by a spec),
and the content's top measured on a window not built yet when a page restyled (`ContentTop`, now measured on UIParent's
grid as `Metrics` is).
