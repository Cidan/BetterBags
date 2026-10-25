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

- **Retail and Forever**: the retail bags window: `HeldBagLayout`, the panel's color inset as Blizzard insets it, the
  round portrait (the bag's icon, the NPC on the bank and vendor), a centered gold title, the red close button, the
  sort button's own art; the settings window in `ButtonFrameTemplateNoPortrait`; the retail dropdowns, menus and popup.
- **Classic, Era, TBC, Anniversary, Mists, Cata** (`Clients.Classic`): Classic's settings window frame
  (`ButtonFrameTemplateNoPortrait`, Classic's art) and title band for the bags and the settings window, no portrait,
  Classic's close button, the Classic dropdowns, menus and popup.
- **Everywhere**: the controls above, the list rows for tabs and the settings sidebar, `MinimalTab` page tabs,
  `GameFontNormal`, `GameFontHighlight` and the client's small fonts, copied outright; no sparkles, feather, wash,
  ribbon, cloud, glow or braid.

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

- **Classic's bags** use the settings window's frame, as planned. Classic's own portrait window (above) would give
  them Classic's portrait and rock background instead; a choice to make in game.
- **Next's own layouts** stay Next's: the settings window's sidebar (brand, search, version), a page's header and
  sections, the bag's header row and footer. Blizzard has no equivalent window.
- **Header buttons are square**: the sort button is 24 square, Blizzard's 28 x 26.
- **The scroll thumb's middle** is stretched; Blizzard crops it to the thumb's height (`OnSizeChanged`).
- **The check box's art** fills its 30 x 29 box; whether the client sizes a button's state textures to their atlas
  (`useAtlasSize` on `NormalTexture`) is not known from the source.
- **The settings slider** is 140 wide; Blizzard's is 212 inside a 250-wide control.
- Checked against Blizzard's source and the specs; testing in game began on 2026-10-24, and refinements are expected
  from it.
