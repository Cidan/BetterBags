# BetterBags Next Themes (`sonata/next.lua`, `sonata/themes/next/`, `next/style.lua`)

BetterBags Next draws its look from a **Next theme**: a declarative, data-only table, the same
mechanism as the classic bags' Sonata themes (sonata.md), with its own registry, saved choice and
settings page. Asked: "bring sonata engine system's to next, but greatly expanded. same mechanism
(apply with a declarative spec, no functions!), we'll likely need a different theme registration path
(original themes, next themes)... as expansive as possible in our theme application here on the
widgets -- from text, to outlines, to search, to buttons, to backgrounds, to animations, to
fade/feathering, all of it. the current design should be the 'default' -- ... take care with text!
... (don't re-use text objects across themes, make whole new ones)".

Before this, Next's whole look was constants in `next/style.lua` and literals across `next/*.lua`;
`NextStyle` said "Next draws itself and does not follow the theme".

## 1. The pieces

| Piece | File | Role |
|---|---|---|
| `SonataResolve` | `sonata/resolve.lua` | Theme resolution shared by both engines: inheritance (`Parent`, else the registry's base), per-client overrides (`Clients`), variables (`"$Name"`), the merge rules (tables merge, lists replace, `false` removes). Moved out of `sonata/engine.lua`; the classic engine delegates (`Resolve`, `chainOf`, `GetClientKeys`) and every Sonata spec passes unchanged. |
| `SonataNext` | `sonata/next.lua` | Next's engine: registry, data-only validation, availability (`Requires`), the saved choice (`nextTheme`), applying, previews, widgets, item buttons, `Check`. |
| Next themes | `sonata/themes/next/*.lua` | `Default` (complete: every other theme inherits what it does not set from it), `Ember`, `Glitch`, `GW2`, `Parchment`, `Plain`, `Quiet`. |
| `NextStyle` | `next/style.lua` | A view of the current theme (`Use`): the old constant fields (`ICON`, `PAD`, `Color`, `Time`, `Small`, `Chain`, `Cloud`, ...) keep their names and are read from the theme, so Next's code reads them as before; `style.Theme` is the resolved theme for widget specs. Fonts, `Paint`, `RGBA`, `Ease`, `TexturePath`. |
| Widgets | `next/*.lua` | Each draws from the theme and has an `ApplyStyle(ctx)` that restyles it live. |
| `NextGlitch` | `next/glitch.lua` | A panel's glitches (`Panel.Glitch`, §21): the CRT's beam, a glitch's moments (tears, datamosh blocks, static, the title's colours split and its letters corrupted, sections shoved), drawn on the panel's glitch layer; the panel drives them. |
| `NextRain` | `next/rain.lua` | A panel's data rain (`Panel.Rain`, §21): columns of glyphs falling down the feather or behind the content. |

Load order (every TOC, `spec/render/toc_spec.lua`): `sonata\resolve.lua` before `sonata\engine.lua`,
`sonata\next.lua` right after it, the Next theme files after the classic themes and before
`next\style.lua` (which resolves Default when it loads). `core/init.lua` calls
`SonataNext:Init()` right after Sonata's, before any bag is made (initialization.md).

## 2. The engine (`SonataNext`)

- **`RegisterTheme(theme)`** (also `Sonata:RegisterNextTheme(theme)`, the "other registration path"):
  a unique `Name`; **data only**: a function, an object (a table with a metatable, a frame) or
  userdata anywhere in it is refused, naming its path (`Bad.Fonts.Title.Size is a function`).
  `Requires` is a list of addon names (instead of Sonata's `Available` function); unknown client keys
  are refused. A theme registered after Next started that is the saved choice is applied at once,
  unsaved (another addon's theme loading late), as Sonata does.
- **`IsAvailable(key)`**: registered and every `Requires` addon loaded (`C_AddOns.IsAddOnLoaded`,
  second return, every client). `IsSelectable` adds not `Hidden`. `GetThemes` lists every theme not
  hidden; `GetAllThemes` those a player can pick.
- **`Resolve(key)`**: `SonataResolve` over Next's registry with `Default` as the base.
- **`Init()`**: forgets widgets, and uses the saved theme (`GetSavedThemeKey`: the saved one, or
  Default while it is missing, hidden or unavailable, the saved choice kept) without saving or sending
  anything.
- **`ApplyTheme(ctx, key, save?)`**: refuses unknown, hidden or unavailable themes (changing nothing);
  resolves; bumps `GetGeneration()`; saves unless `save == false` (a preview); hands the theme to
  `NextStyle:Use`; syncs the item buttons (§6); calls every registered widget's `ApplyStyle(ctx)`, each
  in its own protected call (a failure goes to `geterrorhandler()` and the rest are still styled; one
  unregistered by another during the apply is skipped); sends `sonata/NextThemeChanged`.
- **`RestoreSavedTheme(ctx)`**: applies the saved choice, unsaved, when another is in use (previews).
- **`ApplyAnimation(ctx)`**, **`WatchAnimation()`**: the player's Animation switches, laid over the theme in use (every
  theme applied is the effective one) and again when one changes, keeping the font objects (§20).
- **`RegisterWidget(widget)` / `UnregisterWidget`**: weak; registered by every panel when made
  (`nextPanel:Create`), by `NextDrag` once it builds its layer or dock, by `NextVendorButton` when it
  makes its first button.
- **`Check(key)`**: what a theme names but does not define, each as `"path: problem"`: palette colors
  (keys `Color`, `Fill`, `SelectedFill`, `FocusFill`, `HoverColor`, `FocusColor`, `BeadColor`,
  `KnotColor`, `Unusable`, `SoldOut`, `SoldOutUnusable`, `ArtColor`, `ArtHoverColor`, and the values
  of `Washes`, `Accents`,
  `Colors`), text roles (`Font`, `SelectedFont`, `TitleFont`, `RecentFont`, `FreeFont`, `CountFont`,
  `HelpFont`, `TextFont`, `EmptyFont`, `MoneyFont`, `HintFont`, `WarningFont`, `PriceFont`,
  `UnaffordableFont`, `StackFont`), textures (`Texture`, `QualityBorder`, `QuestMark`: a `Textures`
  name, or a file by path or ID) and eases (`Motion.Ease`, against `NextTween.Ease`); a side rail without
  its `Width` or `Top` (§13); an ornament's `TexCoords` with a `Tile` or not four numbers, and `Panels` not a
  list or naming no panel (§12). For theme authors; every shipped theme is checked on every client.

## 3. The schema (Default, `sonata/themes/next/default.lua`)

Colors are palette names or `{ r, g, b, a }`. A part set to `false` is turned off: resolution removes a table a
theme sets to `false` (`SonataResolve.Merge`), so code reads every part as possibly absent (`local E = I.Edge; ...
E and E.Idle`); `spec/next/shipped_themes_spec.lua` draws every Next window with every theme on every client and
fails on anything sent to the error handler, which is where a restyle's error goes (§9). A **texture spec**
is `{ Color, Texture (a Textures name or a file), Atlas, TexCoords, HorizTile, VertTile, BlendMode,
Desaturated }`, drawn by `NextStyle:Paint` (a solid color without art; art tinted by `Color`; tiling
loads with the `REPEAT` wrap mode; everything it does not set is reset). Where a control paints a **fill**, the fill
may also be inset, drawn at its atlas's size or pieced (§16); a **frame** is Blizzard's nine-slice art (§15).

| Key | What |
|---|---|
| `Palette` | Every named color, or one of the client's named colors (`{ Global = "PANEL_BACKGROUND_COLOR", Alpha? }`: Color.lua makes each `C_UIColor` color a global on every client; read when the theme applies; `Check` names a missing one). The controls and the settings window (next-settings.md) add `ControlFill`, `ControlHover`, `ControlPressed` (a field idle, under the pointer, pressed), `Track` (a switch off, a slider's empty track), `Danger` (what deletes) and `Sidebar`; a theme whose body is not indigo sets the first four in its own colors. |
| `Textures` | Named files (`Glow`, `Sparkle`; Parchment adds `Paper`), and the glyphs (`Icon...`; `minimize.png` and `maximize.png` are shipped for themes that want window marks, Guild Wars 2's size button; the controls' `IconChevron`, `IconCheck`, `IconSearch`, `IconPlus`, and `Circle`, the round switch's disc, made by `tools/textures/next_icons.py`). |
| `FontShadow` | The shadow `Shadow = true` means. |
| `Fonts` | Text roles: `Size`, `Color`, `Shadow` (true, a table, or none), `Flags`, `File` (unset: the client's own font, for the locale), `Justify`, `Locales` (the client locales `File` is drawn in; elsewhere the client's own font: a font covers some alphabets, §21); or `Object`, one of the client's font objects by name, copied (its file, size and flags in every locale, its color and shadow) and changed only by what the role also sets (`Stack` copies `NumberFontNormal`, the bags' item count font); or `Copy`, a client font copied outright (its file, flags, color and shadow) at the role's `Size` (its own, or the one it inherits from Default; `false`: the client font's own), nothing else the role inherits changing it but its height on whole pixels and its own `Justify` (the Plain theme, at Default's sizes). Default's roles: Title, Section, SectionRecent, SectionFree, Count, Tab, TabSelected, Footer, Empty, DragHint, ConfirmTitle, ConfirmWarning, ConfirmHint, Search, SearchText, Price, PriceUnaffordable, VendorName, Stack; the controls' ControlText, ControlMuted, ControlHelp, Button, ButtonPrimary, ButtonDanger, Link, LinkHover, MenuItem, MenuItemSelected, DialogTitle, DialogText, TopTab, TopTabHover, TopTabSelected; the settings window's SettingsBrand, SettingsNavGroup, SettingsNav, SettingsNavHover, SettingsNavSelected, SettingsVersion, SettingsTitle, SettingsDescription, SettingsSection, SettingsSectionNote, SettingsLabel, SettingsText, SettingsLink. |
| `Layout` | Sizes: Icon (an item button's size; the player's Icon Scale, the Size tab, multiplies it: `style.ICON`; the grid's width and the vendor's cards keep the theme's own, `style.CARD_ICON`, docs/next-appearance-size.md), VendorColumns, VendorTextGap, VendorPriceRaise (the vendor's cards, next.md §10b), Gap, PerRow, Gutter, Pad, Feather, TitleTop, TitleInset, SearchTop, SearchHeight, SearchIcon, SearchGap, SearchRight, ContentTop, EmptyTop, Footer, FooterText, FooterMoney, SectionHeader, SectionSpacing, TabHeight, TabSpacing, TabMinWidth, TabMaxWidth, TabPadding, TabHover, TabIcon, TabIconGap, TabGroupGap, HeaderButton, HeaderButtonGap, HeaderButtonTop. |
| `Motion` | `Time` (every animation's seconds), `Ease` (Open, Close, SmallOpen, SmallClose, Enter, Fly, Glide, Hover, Wash, Cascade, Lift, Land, FlyAway, Pulse, Couple, Uncouple, Morph, MorphFade, Resize; any of `NextTween.Ease`, `flicker` included, §21), `Rise` (the cascade). `NextStyle.OVERREACH` follows the Open ease's overshoot (outBack a tenth, outBackSoft a fiftieth, others none). |
| `Panel` | `Fill` (texture spec; `Inset`: `Left`, `Right`, `Top`, `Bottom` into the body, drawn for the backpack and mirrored on the bank, the screen-edge side still reaching past the edge while docked; `Panel:FillInsets()`), `Frame` (Blizzard's frame round the body, §15, mirrored on the bank; `Above` over the content, `Bands` across its top), `Feather` (`Color`, or false), `Wash` (`Height`, `BlendMode`, or false), `Washes` (Default, Warbank, Guild: palette names), `Edge` (`Color`, `Alpha`, `Size`, `Full`: on full panels too, kept through a size switch; or false), `DropGlow` (or false), `Ornaments` (§12; Default has none), `Glitch` (glitching in, out and now and then, §21; Default has none), `Rain` (data rain, §21; Default has none), `Shatter`, `Snow`, `Threads` (§22), `Smoke`, `Bats` (§23; Default has none), `Beam` (§24), `Corners` (a small body's rounded corners, by side, §24; Default has none). |
| `Header` | `Title.Font`, `Title.Ghosts` (copies of the title under it, each `{ Font, X, Y, Alpha }`: a colour split, §21), `Title.Justify` (`"CENTER"`: centered in the room the header buttons leave, as Blizzard centers a window's title; its button and glow over the text where it is drawn); `TitleGlow` (`Texture`, `Color`, `Alpha`, `X`, `Y`, `BlendMode`, or false); `Ribbon` (`Length`, `Thickness`, `Color`, `BlendMode`, `Glow`: `{ offset, alpha }` lines, as many as listed; or false); `Spark` (`Texture`, `Size`, `Growth`, `Color`, `BlendMode`; false: no shimmer); `Cloud` (puffs as many as listed, `Join`, swell and breath; or false); `Buttons` (§11: `Icons`, every header button's icon by its key; `Color` and `HoverColor` for glyphs, `ArtColor` and `ArtHoverColor` for full-color art; `DisabledAlpha`; `Scale`, an icon's size as a share of its button; an icon's `Highlight`, art drawn over it under the pointer; an icon's `Pushed` art while pressed and `Disabled` art while disabled, drawn whole (neither dimmed nor grayed), as a button's pushed and disabled textures are; `RowStart`, where the row starts from the outer side when the pinned buttons hold the corner (the title's room counts the row from there or the pins, whichever reaches further); `Rail`, the buttons down a strip along the inner side instead of across the header, inside the body or `Outside` it, its art from `Start`, §13, false in Default; `Pinned`, a button at a corner of the body apart from the row or the rail, §13; `Menu`, the row in a bag button's menu, §19). |
| `Search` | `Fill`, `FocusFill` (colors, or art: §14), `Edge` (`Color`, `Size`, `Idle`, `Hover`, `Focus`, or false), `Icon` (`Color`, `Idle`, `Active`, `FocusColor`, `ActiveColor`: while it holds a search, under the pointer or not, as Blizzard's magnifier stays white), `HelpFont`, `TextFont`; `Template = true` keeps the bag search box's own border (`BagSearchBoxTemplate`) and draws neither the fill nor the edge. |
| `Sections` | `Title` (`X`, `Y`), `CountGap`, `LineGap`, `TitleFont`, `RecentFont`, `FreeFont`, `CountFont`, `Header` (art behind the title row, across the section, `Layout.SectionHeader` tall or its own `Height` from the row's top, §24; unset in Default), `Line` (`Color`, `From`, `To`, `Size`, or art, or false), `Highlight` (`Color`, `From`, `To`, or art, or false). |
| `Tabs` | `Fill`, `SelectedFill` (colors fading by `Fade`, or art: drawn for the backpack's tabs, sticking out to the left, mirrored on the other panels, no fade), `Font`, `SelectedFont`, `Glow` (`Color`, `BlendMode`, `Drop`, `Pulse`, or false), `Indicator` (`Color`, `Width`, or art tinted by the accent, or false), `Highlight` and `SelectedHighlight` (art over the tab's fill under the pointer and when selected: Blizzard's list rows; mirrored with the panel), `Edge` and `SelectedEdge` (an edge round each tab, NextControls' edge: `Color`, `Alpha`, `Size`; the selected tab's and a drop target's in `SelectedEdge`, else `Edge`; §21), `Accents` (Warbank, Guild). A tab entry's `accent` is an accent name, a palette name or a color. |
| `Footer` | `Line` (`Color`, `Inner`, `Outer`, `Size`, or art mirrored with the panel, or false), `Font`, `EmptyFont`, `MoneyFont` (the guild's gold). |
| `Sparkles` | `Texture`, `BlendMode`, `Colors`, `FadeIn`, `FadeOut`, `TwinkleSpeed`, `TwinkleDepth`, `Shrink`, `WobbleSpeed`, `Upright` (never turned: square pixels, §21); emitters `Cloud`, `Ribbon` (+`Spread`), `Edge` (+`Reach`), `Knot` (+`Burst`), each `Rate`, `Max`, `Life`, `Size`, `Speed`, `Rise`, `Wobble`, `Spin`, `Alpha`, or false; `Sparkles = false` turns them all off. A coupled bag keeps its shorter ribbon and edge sparkle lives (next.md §12, §14e). |
| `Chain` | Chaining (next.md §12) and the braid: `Braid` (false: none), `Segments`, `Beads`, colors (`Color`, `BeadColor`, `KnotColor`), sizes and timing. |
| `Small` | Small mode (next.md §14). The border's alpha is `Panel.Edge.Alpha`. `Grip` (next.md §14g): `Size`, `Inset`, `ShowOnHover` (false: always seen), and `Normal`, `Highlight`, `Pushed` texture specs (mirrored on the left corner); `MinTitle`, the least room a narrowed panel keeps for its title. |
| `Drag` | `LiftScale`, `FlyScale`, `Shadow` (`Color`, `Alpha`, `Spread`, or false), `HintFont`, `HintGap`. |
| `Dock` | `Card` (a texture spec: a card can be art), `Pad`, `TitleHeight`, `LineHeight`, `Glow` (`Color`, `Width`, `Low`, `High`, `Period`, or false), `Halo` (`Texture`, `Color`, `Spread`, `Low`, `High`, `Period`, `BlendMode`, or false; the panel's column leaves `Spread` round each card), its line roles, `DestroyColor` (a section waiting to be destroyed glows in it; Default's palette `Crimson`), `BuyColor` (a shopping list waiting to be bought glows in it; Default's palette `Emerald`, profession-shopping-list.md). Drawn by `NextDockCard` (`next/dockcard.lua`), for each section waiting in a panel's dock (`NextDock`, next.md §7). |
| `Vendor` | `QualityBorder` (a file, or false), `QuestMark`, `SearchDim`, `Highlight` (a color), tints (`Unusable`, `SoldOutUnusable`, `SoldOut`), roles (`PriceFont`, `UnaffordableFont`, `NameFont`, `StackFont`), a card's `CoinSize`, `CardFill` and `CardHover` (colors or art, or false), `DurabilityHeight`. |
| `ItemButton` | Optional: a Sonata `ItemButton` element style (sonata.md §3a) for item buttons while Next is in use (§6); its files are paths (Sonata's specs), its backdrop and quality border may be art. |
| `Settings` | The settings window (next-settings.md §3): `Width`, `Height`, `Fill` (a fill, §16), `Frame` (§15), `Wash` (or false), `Edge`; laid out as Blizzard's with `Title`, `InnerFrame`, `Tabs`, `Brand = false` and the placement keys of §18; `Sidebar` (`Width`, `Pad`, `Fill`, `Line`, `Frame`: Blizzard's frame round it, §15, drawn under its pages and list), `Brand` (`Height`, `Icon`, `IconSize`, `IconColor`, `Gap`, `Font`, `Line`: `Color`, `From`, `To`, `Size`, or art), `Search` (`Icon`, `IconSize`, `IconColor`, `Gap`), `Back` (a page's own list: `Icon`, `IconSize`, `IconColor`, `Gap`, `Font`, `HoverFont`, `Slide` seconds), `Nav` (`ItemHeight`, `Indent`, `GroupHeight`, `GroupGap`, `Spacing` (between every heading and row), `TextRaise` (a row's text above its middle), `Indicator` (or false), `SelectedFill`, `HoverFill` (fills: at their atlas's size with `AtlasSize`), `GroupFills` (cycled through the headings, as Blizzard cycles `Options_CategoryHeader_1` to 3), `GroupLabel` (`Point`, `X`, `Y`: where a heading's label goes), its four fonts), `Version`, `Header` (`Height`, `Pad`, `TitleTop`, `Gap`, its fonts, `Close`: `Icon` or `Atlas`, `HoverIcon` (art of its own under the pointer), `Highlight` (a fill over it under the pointer), `Size`, `Inset`, or `Offset` (`X`, `Y`: anchor offsets from the top right, Blizzard's close anchors), `Color`, `HoverColor`; `Actions`: `Top`, `Gap`), `Content` (padding, `RowHeight`, `RowPad`, `MinColumn`, `Card`, `Divider` (or false: no lines), `Hover`, `TitleUpper` (false: section titles as written), its fonts), `Footer`, `Cards` (the theme pickers: sizes, fills, edges, status fonts), `Categories` (the Categories page, next-settings.md §5: its list's rows, `Dot`, `Indicator`, fills; its tabs' `Pad`, `FieldGap`, `LabelWidth`, `FilterWidth`; fonts), `BagCategories` (a bag's arrangement of them). |
| `Controls` | Every control (next-settings.md §2): `ScrollBar` (the bags' too; its track and thumb fills), `Toggle` (`Style`: `Square`, `Round` or `Check`, §14), `Button` (`Plain`, `Primary`, `Danger`, `Link`: fills, edges and fonts by state, `DisabledFill`, §14, `Highlight` (a fill over it under the pointer while enabled), `DisabledFont`), `Input` (`Edge` or false), `TextArea` (a text area's own `Fill`, `FocusFill`, `Edge` and `Frame`, §15; each the input's when unset), `Slider` (`Track` a fill; `ThumbSize = "Atlas"`, §17), `Dropdown` (§17: `Justify`, `Chevron` art per state at `Size = "Atlas"` by `Point`, `DisabledFont`, `DisabledAlpha`, `NarrowWidth`, `NarrowFill`; `Edge` or false), `Menu` (`Inset` per side; `Border`, a fill over its fill; `Check` (`Size = "Atlas"`, `Off`, `Under`: the radio ring, §17)), `Swatch`, `TopTabs` (its `Indicator` a color or art, or false; `Line` or false, reaching past the tabs by `Outset` (`Left`, `Right`) and stopping under the chosen tab with `Open`; tabs too wide for their row give up half their padding, then half their gaps, then cut their names, the longest first; `Fill`, `HoverFill`, `SelectedFill` per tab, `Padding`, `TextBottom`, `SelectedTextBottom`: Blizzard's `MinimalTabTemplate`, §17), `Dialog` (`Card` a fill, `Border` over it, `Frame`, §15), `ItemGrid` (`Size`, `Gap`, `Pad`, `CommonEdge`, `DimAlpha`, `Hover`, `CountFont`, `EmptyFont`; its box's own `Fill`, `Edge` and `Frame`, the input's fill and edge when unset). A fill is a texture spec, a palette color or false; an edge a `Color`, `Alpha`, `Size` (and strengths `Idle`, `Hover`, `Focus`/`Open` for fields). `Motion.Time` adds `Toggle` and `TabMarker`. |

**Default is the v0.7.0 design, value for value**: `spec/fixtures/next_style_v0_7_0.lua` freezes
v0.7.0's `next/style.lua`, and `spec/next/style_theme_spec.lua` checks every value and every font
(file, size, color, shadow) against it. Changed on purpose since, and checked as changes: the vendor's
items as cards with larger prices (`VENDOR_PRICE` went; `Price` 10 to 13; next.md §10b), and its stack
counts in the bags' item count font (`Stack` copies `NumberFontNormal`). Data-driven colors stay out of themes: item
quality, item level colors, the durability bar's green to red.

## 4. Text (the lesson from Sonata, sonata.md 3c)

- **A font object is made once and never changed.** `NextStyle:Use` starts a new set of font objects
  (uniquely named `BetterBagsNextFont<Role><n>`) with every theme, also the same theme applied again,
  and moves every text drawn with a role to its role's new one. Old font objects are never touched.
- `NextStyle:SetFont(text, role)` / `CreateText(parent, role)` draw text with a role and record it.
  Text must not set its own color or shadow: a state that looks different is another role (the
  vendor's price an item cannot afford is `PriceUnaffordable`, not a red `SetTextColor`; a selected
  tab is `TabSelected`).
- Text on a role the new theme does not define (another theme's own) keeps its font object until its
  widget restyles it with this theme's roles.
- **Copies of the client's fonts follow it** (`NextStyle:CopiesStale`, `SonataNext:WatchClientFonts`, started by
  `core/init.lua` after NextPixel): a role copying a client font (`Object`) records what it copied; on every
  `PLAYER_ENTERING_WORLD`, when any copy made with the current fonts no longer matches its client font (file, size,
  flags, color, shadow), the current theme is applied again, unsaved, as a new pixel grid does. UI addons rewrite
  the client's fonts once the game has loaded, after BetterBags made its own: GW2_UI at `PLAYER_LOGIN`
  (`Core/GW2_ui.lua`, `Core/fonts.lua`: `GameFontHighlight`, `SystemFont_Shadow_Large`, `NumberFontNormal` and
  others). Before, Default's `Stack` (a copy of `NumberFontNormal`) kept Blizzard's font under GW2_UI while the
  bags' item counts drew GW2_UI's (inferred from GW2_UI's source; not seen in game). Coverage:
  `spec/next/style_theme_spec.lua` ("copies of the client's fonts"), `spec/sonata/next_engine_spec.lua` ("watching
  the client's fonts"), `spec/core/init_spec.lua` (the order).
- **Template colors win over font objects.** `NextStyle:SetTemplateFont` sets the role's color and
  shadow on the text too, now and with every theme, read from the role's font object, never one read
  back from the text (`.context/patterns-ui.md`). Used for the search box's help text, which
  `InputBoxInstructionsTemplate` gives an XML `<Color>` (0.35 gray). What is typed needs no such
  color: `BagSearchBoxTemplate` sets no enabled color (the template's `enabledColor` KeyValues are
  commented out, "Optional"). Inferred from the XML, not seen in game: v0.7.0 gave the help text only
  a font object, so it likely stayed gray.

## 5. Widgets restyling live

Every widget builds its parts, then styles them from the theme with the same functions `ApplyStyle`
calls again. Sizes are read when used (no value kept at load).

- **Panel** (`next/panel.lua`): `StyleParts` (body, mover, search box, header, content, footer,
  sparkles, tab rail, canvas) then `ApplyStyle` reshapes it (`ApplyGeometry`), places a chained pair
  (`chain:Update`), restarts its emitters and shimmer while it shows, and draws its content again
  (`Draw` with its last data: at once while shown, else on show), so buttons take the theme's icon
  size. Pools let a theme change counts: cloud puffs, ribbon lines, braid segments and beads; surplus
  ones are hidden. The wash remembers its key (`washKey`), so a theme paints the same thing (the
  Warbank's wash) in its own color. Emitters a theme turns off never start (`SetEnabled`).
- **Tab rail** (`next/tabs.lua`): restyles every tab, shown or pooled, and lays them out again (their
  widths follow the new fonts).
- **Canvas** (`next/content.lua`): restyles every section, drawn, kept from the last pass or pooled.
  `SetPriceRow` (the vendor's) replaced `SetCellHeight`, so rows follow the theme's icon size.
- **Drag and dock** (`next/drag.lua`): restyled in place while a section is lifted or docked.
- **Vendor buttons** (`next/vendorbutton.lua`): every button made, in use or pooled; the vendor
  fits its name to the theme's header sizes again.
- **Size button**: its icon follows the theme by state (`SetHeaderIcon`).
- **Controls and the settings window** (next-settings.md §2, §3): every control module restyles every
  instance it made (`NextScrollBar`, `NextButton`, `NextToggle`, `NextInput`, `NextSlider`, `NextMenu`
  while open, `NextDropdown`, `NextSwatch`, `NextTopTabs`, `NextDialog` while shown); the window
  restyles every part and lays itself out again; its pages, theme pickers and category managers
  restyle theirs.

## 6. Item buttons

Item buttons are shared by both designs and styled by Sonata's `ItemButton` element (the classic
bags' theme). `Sonata:SetElementStyleOverride(kind, style)` makes a style replace the theme's for a
kind (restyling it at once; nil gives the theme's back). `SonataNext:SetActive(design == "next")` is
called by `BagSystem:Use`; while Next is in use and its theme sets `ItemButton`, that style is the
override, and `ItemFrame:RestyleButtons()` makes every button draw in full again. Default sets none,
so item buttons look as before. Masque is still decided by the bags' theme.

**Sizes and Masque.** Masque sizes a skin to the button when it skins it (Masque 12.1.0 `Core.lua`
`UpdateScale`, from `Button:GetSize()`, in `SkinButton`, which both `AddButton` and `ReSkin` run).
Bag item buttons are re-skinned on `item/Updated`, which only a full draw sends, and a redraw whose
inputs are unchanged is skipped (item-drawing.md §7b). **Failure mode (fixed, reported in game):**
Quiet's 38-pixel icons resized every button with nothing else changed, so no draw was full and the
skin stayed sized for 44: Masque's frame and the default border both showed, and switching back left
broken borders. `itemProto:SetSize` now makes the next draw full when the size changes (the record
is invalidated, as `Lock` does). Vendor buttons are skinned once and not drawn again on a theme
change, so the Masque integration re-skins them on `sonata/NextThemeChanged`. Guild bank buttons
re-skin on every draw already, and a theme redraws the guild bank.

## 7. Picking a theme

The settings window picks it on its **Appearance** page (next-settings.md §4, §7): theme cards over
SonataNext (`NextSettingsThemes:Create(parent, sonataNext)`; the cards take any engine with GetThemes,
IsAvailable, IsSelectable, GetCurrentThemeKey, GetSavedThemeKey, ApplyTheme, RestoreSavedTheme), the
**Theme** section while BetterBags Next is in use and the **Settings Window** section for the classic
bags (Next's themes draw the window either way). The classic settings window's Next Theme page, the
Theme pane over SonataNext, was removed with that window. The rules are those it had: themes by name,
those whose addons are not loaded shown as unavailable, a pick previewed on the next frame without
saving, **Apply Theme** saves, the saved one put back when the page is left. The bags' theme is left
alone. The setting is `nextTheme` (`DB:Get/SetNextTheme`, default `"Default"`).

## 8. The shipped themes

- **Default**: the design as it was.
- **Ember**: a charcoal and amber palette, sparkles drifting slowly and rising like embers.
- **Parchment**: Moonlight's parchment art (the plain middle, away from its burnt edges) for the body
  and the dock's card; dark ink text in Blizzard's parchment text colors with no shadow (numbers over
  icons keep one); ink and sealing-wax lines, bars and glows drawn normally, not added as light; no
  sparkles, cloud, spark or wash; glyph icons in ink, colored icons in their own colors. Its paper
  color (feather, tabs) is the art's measured average (0.83, 0.78, 0.70).
- **Quiet**: cool grays, smaller icons nine to a row, a shorter header with its button icons at 0.8
  of their buttons (§11), no ribbon, cloud, spark,
  sparkles or braid, quicker opening without a bounce (the body reaches only 4 past the edge), a
  fainter small border. Its first version drew the border on full panels too; asked: a full panel
  docked at its edge should have none, so it no longer sets `Panel.Edge.Full`.

- **Guild Wars 2** (`GW2`, `sonata/themes/next/gw2.lua`, offered while GW2_UI is loaded, `Requires = { "GW2_UI" }`;
  the plan and what GW2_UI's source says: `docs/next-gw2-theme.md`): GW2_UI's look from its own files, calling
  nothing of it. Asked (round two): "we need to use those icons, that bag frame style, that icon" of the original
  BetterBags GW2 theme (`sonata/themes/gw2.lua`), "X button should still be top right", "tabs, i mean everything",
  and no feather while docked; (round three) the header and emblem as GW2_UI's character window, one highlight for
  every side button, the size button beside the X, one close button. So:
  - **The header as GW2_UI's character window** (`GwCharacterWindowTemplate`, `Character/windowBase.xml`; a first try
    followed `GwFrameHeader`, which the character window does not use, and its emblem sat inside the window): the
    window's top 62 below the body's top; the band's painted rows (45) above it, from over the side panel (40 out);
    the emblem (84) straddling the side panel, its bottom right corner 18 in and 22 below the window's top (so it
    starts at the body's top: a docked panel's top is the screen's); the title 31 in, its middle 18 above the window's
    top; the world map painting from the window's top (`Panel.Fill.Inset.Top`), so the band is drawn over what is behind the
    window; no border (`Panel.Edge = false`); the search bar 13 below the window's top; the footer band (its painted
    rows, 30 tall) with the free slots and money on it; `Panel.Feather = false`.
  - **The side panel outside the window** (`Rail.Outside`, §13), 40 wide, its art from the window's top line
    (`Rail.Start`), the actions down it below the emblem in the original's micro icons (32, 5 apart): Show Bags
    (`bagmicrobutton`), Sort (`collectionsmicrobutton`), Settings (`questlogmicrobutton`); GW2_UI's own for the bank
    tabs and deposit (`bankicons.png`'s character and Warbank quarters, `Inventory/bank.xml`) and repair
    (`icons\repair.png`); BetterBags' glyphs in LightHeader where GW2_UI has none.
  - **Every side button highlighted alike** (an icon's `Highlight`, §13; asked: as Show Blizzard Bags is): GW2_UI's
    `-down` art over the bag, its hover art over the close, an icon's own art again over one without `-down` art
    (added, for the half-opaque micro icons; drawn again, for the near-opaque ones), no tint. GW2_UI's `-down` art is
    its `-up` art at 2.2 times its opacity (measured, 1.6 for the main menu's).
  - **The close and size buttons side by side at the top outer corner** (`Pinned`, §13), the close's middle 20 in and
    20 above the window's top, as the character window's: GW2_UI's close art (its hover art over it), the size button
    left of it (asked: out of the side panel) in BetterBags' own glyphs, an underscore and a box with a heavier top
    (`minimize.png`, `maximize.png`, `tools/textures/next_icons.py`; asked: GW2_UI's own, its only, 32 x 32, drew
    blurry). Top right
    on the backpack, as asked. A judgment call: Next mirrors the other panels, whose side panel, emblem and title
    start from the right, so there they are top left; at the top right they would sit on the title. The settings
    window's close is the same art (`Settings.Header.Close.HoverIcon`).
  - **Every control in GW2_UI's art** (§14): its side tabs (`tab-tex-right-left.png`, flipped, its solid columns 0 to
    48 of 64 and 64 of its 1,024 rows: its outer 40% fades to nothing and left names over the world, and squeezed
    whole it streaked; asked: "tough to read"), its bag search bar (no border), its bag section rows (`bag-sep.png`,
    `GwBagHeaderTemplate`) with `menu-hover.png` under the pointer; cream buttons (`button.png`, darker under the
    pointer and pressed, `button_disable.png` disabled, dark text, no edge), check boxes (`checkbox.png`,
    `checkboxchecked.png`, `checkbox-disabled.png`, the mark gray while disabled), sliders (`sliderbg.png`,
    `sliderhandle.png`), scroll bars (`scrollbg.png`, `scrollbarmiddle.png`), fields (`statusbar.png` at half, edged in
    black), dropdowns and menus (its backdrop, `arrowdown_down.png`, `button_hover.png`, the check mark), dialogs and
    dock cards on its backdrop; the settings window as GW2_UI's own (`settingspanelbg.png`, `236menubg.png`,
    `levelreward-sep.png`, `settingspanelsep.png`). Every art spec sets its `Alpha` (§14, inherited alphas).
  - Text in GW2_UI's own fonts (copies of the client fonts it rewrites, §4), its colors (LightHeader titles, its
    wine accent, its skin colors); its item buttons (cropped icons on its backdrop, its border in the quality's
    color, its highlight and pushed art, the count at the top right). No sparkles, shimmer, cloud, ribbon, wash or
    braid. Painted rows and columns were measured from the files. Every GW2_UI file it names is checked against
    GW2_UI's source (`install-deps.sh` clones it).
  - Laid out on a 1920 x 1080 screen at both sizes (one-off dumps through the specs' layout resolver): nothing
    overlaps, the header where `GwFrameHeader` puts it.

- **Plain** (`sonata/themes/next/plain.lua`; asked: "the Plain theme looks like the default UI for the version of WoW
  we're playing on"; the plan, what Blizzard draws and how it was checked: `docs/next-plain-theme.md`): Blizzard's own
  art, every name and number read from the files each client loads, at Default's scale and in Default's layout (asked,
  round three: "scale for Plain should be the same as our Default", and of the settings window, "keep it like we do in
  default, just, pass over with skin a bit"). The bags are the original BetterBags bag windows (asked, round two):
  `DefaultPanelTemplate`'s look on every client (`ButtonFrameTemplateNoPortrait`, the client's own art, drawn above the
  content; `UI-Background-Rock` 6, 21, 2 and 2 in and its `TopTileStreaks`; Classic's title band), the search box where
  the original put it with `SearchBoxTemplate`'s insides, the original menu button's `Bagslots2x` bag as the bag button
  holding the header's actions in the original bags' menu (§19; the vendor's portrait in Bagslots2x's empty gold ring on
  the vendor's), only the close button in the header, the title centered between them. The settings window is Default's
  in the same frame and stone, its name in the title bar, its sidebar Blizzard's inset (`InsetFrameTemplate` over its
  marble, 4 in, 24 down, 4 above the bottom), its pages in the settings list's art (`Options_CategoryHeader_*`,
  `Options_List_*`), its page tabs (`MinimalTab`) on a line across their column open under the chosen tab, its section
  titles as written, its text areas and item boxes in Blizzard's multi-line edit box's frame (`InputScrollFrameTemplate`).
  Retail and WoW: Forever (`Clients.Retail`): the red close button, the retail menus (`MenuStyle1`, and `MenuStyle2` for
  the settings dropdowns), today's popup's retail border. Every Classic client (`Clients.Classic`): Classic's 32-square
  close, Classic's menus (its own `MenuStyle2`), the popup's Classic border. Every client: the panel button in three
  pieces with its highlight, the input border, the settings check box, slider, dropdown and scroll bar art at Default's
  sizes, today's popup, the client's fonts copied at Default's sizes (the title bar's and the two larger Blizzard fonts
  at their own). Its side tabs are the list rows: Blizzard has no sideways text tabs. No sparkles, feather, wash, ribbon,
  cloud, glow or braid. Round one drew the dialog in the old `Dialog` nine-slice and the retail bags as Blizzard's
  combined bags; round two the bag windows above and the settings window as Blizzard's (§18); round three Default's
  scale and layout, the bag button (docs/next-plain-theme.md).

- **Glitch** (`sonata/themes/next/glitch.lua`; asked: "a 'glitch' theme, where the bag sort of 'glitches' into existance
  when opening, glitches out when closing. think flickers, glitched blinking textures that wobble suddenly and harshly,
  think green mesh ... push the limits of what's possible here", and to keep it off GitHub until it is shown): a
  terminal that will not hold still. Opening, a CRT warming up, then the panel flickering into view through tears,
  datamosh blocks and static, its sections shoved and its title split and corrupted; closing, the same backwards into a
  CRT turning off; a short burst now and then while it shows. At rest: phosphor green on near black, a faint grid, a
  wireframe floor breathing along the bottom, a CRT vignette, scanlines and a rolling bar over the items, HUD brackets
  at the corners that twitch now and then, the title's cyan and magenta ghosts, data raining down the feather and
  faintly behind the items, tabs as HUD boxes (the selected one lit with dark text), dashed section lines, square pixel
  sparks, item buttons as terminal cells. Text in VT323 and Share Tech Mono (`fonts/glitch`, SIL OFL, their licenses
  beside them), Latin locales only. Its palette redefines Default's names in greens, so what it leaves to Default
  follows. The engine it added: §21.

- **Frost** (`sonata/themes/next/frost.lua`; asked: "a cool blue and cold theme, icy in nature. ... the shades of blue
  and gold should be like the screenshot ... themes are ice, cool breeze, etc. ... go crazy on the show and hide
  animations, and the overall feel"): deep winter blue threaded with gold, its palette Default's names in the
  screenshot's blues and gold (Gold, Lavender as ice blue, Text, Muted), plus Ice, Frost and Silver. Its engine is §22.
  - **Opening:** the bag appears out of a frost storm (asked, after seeing the shatter in game: "i love how the bags
    close, but for the opening of the bag, instead of just doing the close in reverse, can we do a sort of... frost storm
    that grows from the bottom left to the top right and the bag appears? almost like the bag appearing out of the frost
    storm"): the storm grows out of the body's bottom inner corner (bottom left on the backpack, mirrored to bottom right
    on the panels across the screen, as all of the theme is) across it, flakes curling and turning and mist rolling and
    growing in it, shards of its own body forming behind its front; once it has crossed, the seams flash, the frost on
    the shards thaws and the bag shows under them as the storm blows away, the seams never showing (asked, of the first
    storm, which flashed them: "these lines, don't need to show"); a gust of wind blows snow in, and its gold
    threads draw themselves in once every shard has formed. About 0.9 s, under the 1 s a bank waits for its panel to show
    (refresh-scheduler.md §11). (Its first opening was the close in reverse: the shards flying in from around the body;
    still the engine's open without a `Storm`.) **Closing:** frost spreads over it, cracks run along its
    seams out from where the pointer is (the close button clicked), and it shatters, the shards tumbling away under
    gravity, turning and catching the light, on a layer that carries them on after the bag has hidden.
  - **At rest:** the body's art (`body.png`: teal-blue depths, drifting frost), and now and then a gold shooting star
    flying a short way across it toward the inner side, its snowflake head twinkling (`Panel.Snow.Flybys`, §22; at most
    two at once, every 4 to 9 seconds, 110 to 170 units at 55 to 85 a second, the body 458 across). The first version
    painted streaks of wind into the body; asked, "make those animated and not static", they became a tiled ornament
    blown across the whole body, and then, asked: "slightly too noisy ... the wrong color -- more golden, and A LOT less
    of them, more like... slower, shooting star, then don't even go the full length of the bag, more like... flyby
    twinkles", these stars. The rune circle it had behind the items was removed, asked: "get rid of that big rune". An
    aurora drifting across the top, a frosted rim, an interlace
    border down the inner side and along the top and bottom (and the outer side of a small panel), ice crystals growing
    out of the inner corners into the feather and glinting; snow behind the items and down the feather on a breeze that
    gusts now and then, streaks of wind sweeping across; three threads of gold light (round the header behind the title,
    along the footer out into the feather, down the feather), swaying, a glint running along each now and then;
    snowflakes for sparkles and for the spark that glides along the gold ribbon into the frosty mist round the title.
  - **Text:** Cinzel (fonts/frost, Regular and Bold, SIL Open Font License, upstream static files of
    github.com/NDISCOVER/Cinzel) for display text (titles, sections, tabs, dialog and settings titles), the client's
    font for the rest; Cinzel covers Latin alphabets only, so in other locales its roles draw the client's (`Locales`).
  - **Art:** `tools/textures/next_frost.py` (standard-library Python) makes `textures/next/frost/*.png`: the body, hoarfrost
    (dendrites grown in from the edges), an ice crystal cluster, an interlace band (along an edge and turned down a
    side), aurora curtains, a frost rim, a snowflake, a wind streak (a gust's, and a shooting star's tail), a thread of
    light. Checked by its numbers rather than by eye (the body averages 0.05, 0.19, 0.29; the frost covers 9% of its
    file).
  - Item buttons are frosted cells (cropped icons, a thin ice edge carrying the quality); the settings window is drawn
    on the body's art.
  - Not seen in game yet. Seen nowhere else either: no image of it was rendered.

- **Halloween** (`sonata/themes/next/halloween.lua`; asked: "think: black cats, pumpkins/jack-o-lanterns, bats, orange
  and black. the bags should appear in a puff of smoke from bottom to top (get that smoke right! make it feel really
  good). for the bag closing, make the bag 'turn into' several bats, like 10-15 bats, and fly away in random directions
  off screen. like old school cartoon vampires turning into bats and flying away ... main color should be orange with
  black accents (so orange backdrop), with whimsy and fun animations. slightly cartoony almost and flat shaded ... a
  nice good color of orange, like that of a pumpkin, not over the top bright"): pumpkin orange with black accents, its
  palette Default's names in candlelight (Gold), a witch's purple (Lavender) and dark ink (Text, Muted), plus Ink, Bone,
  Night, the smoke's purple-tinged greys and the leaves' autumn colours. Its engine is §23.
  - **Opening:** smoke rises up the bag from the bottom (NextSmoke). The first version was cartoon smoke (flat,
    cel-shaded puffs popping past their size, holding, shrinking away); asked: "can you make it more real-ish?". Now rows
    of soft, uneven puffs (`puff.png`, noise-shaped) are born from the rising front, each at its own strength (0.35 to
    0.65) and angle, swelling from 0.55 of its size to 1.8, rising faster and faster (buoyancy), curling across its drift,
    fading in quickly and thinning away over 0.75 to 1.25 s, the bottom row spreading along the floor; embers (soft gold
    and pumpkin glows) rise through it. The bag shows under it by 0.4 s (under the 1 s a bank waits for its panel to
    show) and the smoke lingers on its layer, clearing from the bottom up, about 1.6 s in all. A bat or two flutters out
    of its header as it opens. **Closing:** first a puff of smoke covered it and bats burst out of it; asked: "no puff of
    smokes: how the frost theme shatters, we want the bag break up *and morph* into bats and fly away. almost a surreal
    effect". Now it trembles where it stands (0.18 s), breaks into 11 to 15 pieces of its own body that drift apart from
    where it breaks (the pointer, else its middle), and each in turn, nearer the break first, shrinks, spreads wings and
    darkens into a bat (0.32 s) that flies away (four frames, 14 a second) faster and faster, wobbling and banking, until
    it is off the screen.
  - **At rest:** the body's art (`body.png`: one deep pumpkin orange from side to side, averaging 0.8, 0.4, 0.11, a
    touch lighter at the top and darker toward the bottom; the first version's five soft ribs were taken out, asked:
    "remove the dark streaks on the bag ... make the orange slightly deeper"), black goo dripping along its top (16 tall, clear of the title at 24 and the header buttons at
    27), a black edge; at the bottom of the feather a jack-o'-lantern, its candlelit face and a glow round it flickering
    (`Flicker`, §12), a black cat sitting on it swishing its tail (`Sway`) and blinking now and then, sometimes twice
    (`Blink`, §12); on a small bag, the cat and a little jack-o'-lantern sit on its top edge at the outer corner; a cobweb
    across the feather's top corner, a spider swinging from it; a pumpkin vine curling along the footer out to the
    jack-o'-lantern (a thread, §22); autumn leaves tumbling down the feather and a few behind the items, on a breeze that
    gusts now and then (NextSnow, drawn flat); one to three bats fluttering out of the header every 9 to 18 seconds; a
    candlelit glow round the title, a bat gliding in along a black ribbon into it; little stars for sparkles, drawn flat.
  - **Text:** Creepster (fonts/halloween, Font Diner, SIL Open Font License, Google Fonts' upstream file) for display
    text (titles, sections, the empty text, dialog and settings titles), the client's font for the rest; dark ink on the
    orange, bone and pumpkin on the black (tabs, the search box, menus, a primary button), each with a shadow of its own.
    Its character map covers Latin-1 and more (checked with a stdlib reader of the font's `cmap`: none of the
    accented letters of the eight Latin locales missing), so in other locales its roles draw the client's (`Locales`).
  - **Art:** `tools/textures/next_halloween.py` (standard-library Python; a scanline rasterizer at 4 x 4 samples a pixel
    for flat, hard-edged, anti-aliased shapes) makes `textures/next/halloween/*.png`: the body (8 x 512, every column the
    same, stored uncompressed so the theme's spec reads its pixels), a soft puff of smoke (256 x 256, grey tones, tinted:
    a round falloff broken up by fractal value noise read through a noise-warped point, for curls and thin places), a star, the bat flapping (512 x 128, four square frames) and gliding, the cat with its eyes (on the
    same canvas, so they lie over it exactly) and its tail apart, the jack-o'-lantern with its lit face apart, a cobweb, a
    spider on its thread, a maple leaf, a vine, goo drips repeating across. Checked by ASCII previews of each picture's
    shape in the terminal rather than an image viewer, which hangs.
  - Item buttons are dark cells on the orange (cropped icons, an ink edge carrying the quality); the settings window, a
    dock's card, the currency tracker and dialogs are on the body's art in ink; menus are black with bone text.
  - Not seen in game yet; no image of it was rendered.

- **Make It So** (`sonata/themes/next/makeitso.lua`; asked, to honor Patrick Stewart: "star trek TNG themed, the bags
  obviously need the star trek beam down, and beam up animation for appearing and closing. star trek comm badge is a
  part of the theme as well ... LCARS is an option, but maybe also holodeck too -- up to you, go nuts ... most important
  part is beam down/beam up", with the glam of the Halloween, Glitch and Frost themes): a starship's computer. Its
  palette redefines Default's names in LCARS' colours (Gold its orange, Lavender its lilac, Text and Muted peach) and
  adds them (`LcarsOrange`, `LcarsPeach`, `LcarsLilac`, `LcarsBlue`, `LcarsSalmon`, `LcarsRed`, `Sky`) and the
  transporter's pale blue (`Transporter`). Its engine is §24.
  - **Softer and more modern** (asked after the first look, with a screenshot: "softer colors, maybe a bit more
    translucent in the title of each section, more.. modern a bit. i'll let you decide what this means"): a pane of
    glass. LCARS' colours softened to pastels (apricot, peach, lavender, sky, soft blue, salmon; none more than 0.6
    saturated, where the original orange was 1); the body a translucent navy (the holodeck tile's base navy, its grid
    a faint amber, drawn at 0.9, `HolodeckGlass`); the side bar glass (`LilacGlass`, 0.16) with its blocks floating on it
    as rounded keys; a slimmer top bar (10) and bottom bar (8); no border (`Edge = false`: the inner corners are rounded,
    where straight lines would stop short); sections and tabs on glass with their names in peach; the chosen tab solid
    apricot, its name in black; item buttons navy cells with a soft lavender edge.
  - **Beaming down** (NextBeam): a column of pale blue light comes up over where the bag rests, its art flowing up and
    its strength shimmering; the transporter's shimmer (flecks of white, blue and a little peach, about 2.6 to every
    100 x 100 units of the body, some a little past its sides) twinkles in brief flashes and ripples up and down
    through it; the body glows as the bag materializes under them, solid by 0.72 s (under the 1 s a bank waits for its
    panel to show); the light goes out after, by 1.15 s. A moment later the comm badge chirps: a glint flashes across
    it (`Flash`, first 0.85 s after it shows, then every 7 to 13 s). **Beaming up:** where it stands, the column and the
    shimmer come up and the body glows as the bag fades out of the light, gone by 0.65 s; the light goes out after it.
  - **The LCARS frame** (ornaments, §12, and the side rail, §13): the side bar (52 wide, inside the body on its inner
    side) curves into the slim top bar (10 tall, apricot) at the top elbow (150 x 66, its outer corner rounded 30, the
    corner inside filled round); then a lavender segment, its light flickering as the computer works, the bar on to its
    rounded end short of the comm badge. At the bottom another elbow (peach, 150 x 40, its outer corner rounded 24, its
    top 6 left clear) into the bottom bar (salmon, 8 tall) and its rounded end. A small bag (as narrow as 216) keeps its
    elbows, its bottom bar and the badge: the top bar beyond its elbow would run into them. **Its corners** (asked:
    "corner at the top left and bottom left peak out around the LCARS, i think we need a way to shape the window
    itself"): a small bag's inner corners are rounded as the elbows round them (30 and 24) (`Panel.Corners`, §24); its
    outer corners and a full bag's stay square. (The restyle first rounded the outer ones too, 12: the body's fill then
    needed a fourth mask, which the client refuses, §24.) The header's buttons are the side bar's blocks: each its soft
    LCARS colour (settings peach, sort and filter lavender, Show Blizzard Bags and repair sky, the size button apricot,
    bank tabs and Sell Junk salmon, deposits blue, gold gold), a key rounded 8, 3 in from the bar's sides, its glyph cut
    in dark navy at its right end, the bar's glass round it, so the blocks stack 4 apart under the elbow
    (`Layout.HeaderButton` 36, each icon's `Scale` 52 / 36, `Rail.Top` 70, `Gap` 4, the glass from 66 where the elbow
    ends), a light over one under the pointer.
  - **The comm badge:** the close button, pinned at the top outer corner (12 in, 6 down), its own icon blank; the badge
    (the gold delta over its silver oval) an ornament drawn over the content, 44 across, centered on the button (36),
    so 4 past it on every side, inside the rounded corner (`Above`), a glint over it, and a soft light round it under
    the pointer (the button's `Highlight`). Tap your comm badge to beam up.
  - **At rest:** the holodeck's golden grid behind the items (the body's fill, a 64 x 64 tile repeating); in the
    feathered edge, stars at warp (NextSnow, §22): streaks and specks drifting out into the world at three speeds,
    never falling, never turned, and every 30 s or so a jump to warp (a gust 600 strong, streaks of light sweeping
    across). Tabs are LCARS bars of glass, rounded where they stick out (lavender at 0.42, `TabGlass`, their names in
    peach; the chosen one solid apricot, its name in black). Section headers are bars of glass (the section bar art: a
    solid rounded tip, a gap, then glass a third as strong fading along the section to a twentieth), 20 tall in a header
    28 tall (`Sections.Header.Height`, `Layout.SectionHeader`), so 8 clear the first row of icons (reported: the title
    "is overlaping with the first icon row"), their names in peach after the tip, counts in lavender; the title in
    LCARS orange with a soft glow, an orange line out of the window and a fleck of the transporter's light gliding in
    along it; no cloud; sparkles are the transporter's flecks; item buttons navy cells, a soft lavender edge carrying an
    item's quality.
  - **Text:** Antonio (fonts/makeitso, Vernon Adams, SIL Open Font License; Google Fonts' upstream,
    googlefonts/antonioFont at `0856299`, its static Bold and SemiBold, checked against the upstream's file hashes), a
    free face in the spirit of LCARS' lettering, for display text (titles, sections, tabs, counts, the empty text,
    dialog and settings titles); the client's font for the rest. Its character map covers Latin-1 (checked with a stdlib
    reader of its `cmap`), none of Cyrillic, Korean or Chinese, so in other locales its roles draw the client's
    (`Locales`).
  - **Art:** `tools/textures/next_makeitso.py` (standard-library Python; shapes at 4 x 4 samples a pixel, lights as
    smooth fields; the frame's pieces drawn for the size the theme gives them in its units, so circles stay circles)
    makes `textures/next/makeitso/*.png`: the elbows, a bar's rounded end, a white square the bars and segments are
    tinted from, a blank, the tab, the section bar, a block for each header button (its glyph read from
    `textures/next/icons` with a stdlib PNG reader and resampled) and the light over one, the comm badge and the light
    round it, the glint, the transporter's column (soft across, streaked, banded so it tiles as it flows), the body's
    glow (softening over its outer fifth, where the beam's margin and ends are), a warp streak and the holodeck tile.
    Checked by ASCII previews, colour classes for the badge and a block. The masks the engine cuts with (a corner, a
    beam's end) are `tools/textures/next_masks.py`'s.
  - Seen in game once, before the restyle (a screenshot: the corners, the section titles and the look above came from
    it); the beam's reach and ends were reported from it too. The restyle is not seen in game yet.

Each draws the settings window and its controls in its own look (next-settings.md §6): Ember and Quiet
their control colors in their own charcoal and grays (Quiet also smaller settings titles and quicker
switches and tab markers); Parchment the window, its menus and dialogs on the paper art, ink text and
edges, sealing wax for the accents, Blizzard's parchment red for what deletes.

Not seen in game yet: any theme but Default.

## 10. A texture's alpha is its vertex color's

For a texture (and a line), `SetAlpha` and `SetVertexColor`'s alpha are **one value**: each replaces
the other. Blizzard's own code relies on it: `FCF_SetWindowAlpha` sets a chat window's alpha with
`SetAlpha` on its textures, and `FCF_GetChatWindowInfo` reads it back from
`background:GetVertexColor()` (`Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua`); both setters
add the same Alpha secret aspect (`SimpleRegionAPIDocumentation.lua`). A gradient's alphas are its
own: `SetAlpha` does not fade a gradient texture (§14d of next.md; `.context/patterns-ui.md`).

**Reported in game, all from treating the two as separate:**
- The small border looked bright after any size switch and dim after a theme: the switch faded it
  with `SetAlpha` and ended at `SetAlpha(1)`, replacing the theme's 0.35, until a theme colored it
  again. Since v0.7.0's small mode.
- The title's hover glow lit up when a bag opened or a theme applied, until hovered: `Paint` colored
  it (`SetVertexColor(..., 1)`) after its `SetAlpha(0)`. The spark the same, while its shimmer waited.

**Rules (they give the same result whichever way the client counts):**
- A texture whose alpha is animated gets its color first and its alpha after: anything that colors
  it again (a theme) keeps the alpha it shows (`GetAlpha` before, `SetAlpha` after): the title's
  glow, the spark, the drop glow, a tab's glow. Textures whose alpha is set every frame (cloud
  puffs, sparkles, braid lines, the dock's glow) need nothing more.
- A texture with a theme alpha that also fades is faded through its vertex color alone, never with
  `SetAlpha`: the small border (`paintEdges(strength)`: the theme's alpha times the strength).
- Classic Sonata the same: `apply:Texture` and `apply:ButtonStates` set a tint's color, then one
  alpha, the tint's alpha times `Alpha`; the decorator fades a texture from that product
  (`apply:TextureAlpha`). No shipped classic theme gives a faded texture a tint alpha below 1.
- The spec mock models it (`spec/helpers/wow_mocks.lua`, `SetAlpha`/`SetVertexColor`/`GetVertexColor`
  on textures and lines): read a texture's alpha with `GetAlpha` and its color with the first three
  values of `GetVertexColor`.

## 11. Header icons

Asked: "these icons on the top right, i don't like how they are all different. i *love* the gear
icon; can we make icons for each button we use (including the bank, guild bank, etc) in the same
style please? remember themes: these buttons should be colorable via themes, and even replacable
with custom art"; then, shown a draft set, to use BetterBags' own for every button, the gear and the
close button included.

- **The art** (`tools/textures/next_icons.py`, standard-library Python like `next_glow.py`; run from
  the repository root): fourteen glyphs, `textures/next/icons/*.png`, 64 x 64, white, the shape in the
  alpha. Drawn in the style of Blizzard's `uitools-icon` family, measured from its atlas (file 5400310,
  `UiTextureAtlas` 2561 on wago.tools): a 20-unit grid, a 1.5-unit stroke, about 1.5 to 18.5 across,
  so they fill a 22-unit button as the gear did. Blizzard's family has no sort, bag, bank tab,
  deposit, gold, filter, junk or repair icon, so BetterBags draws all fourteen, the gear and the close
  button too, so every button matches in weight and sharpness on every client (Blizzard's are 20
  pixels and blur when scaled up). Each is a set of signed-distance shapes (strokes, fills,
  knock-outs) sampled once per pixel with a one-pixel edge: settings (a gear), close, sort (a broom
  with a sparkle, as Blizzard's sort button), classic bags (a backpack), small and full size (arrows
  in, arrows out), bank tabs (a tabbed panel), Warbank deposit (an arrow into a tray), deposit and
  withdraw gold (a coin stack with an arrow), filter (a funnel), sell junk (a price tag), repair (a
  hammer), guild repair (a hammer with a guild shield).
- **Drawn smooth:** `SetTexture(file, nil, nil, "TRILINEAR")` (`SimpleTextureBaseAPIDocumentation`:
  `filterMode`), as Blizzard draws its map tiles on every client, so a 64-pixel glyph drawn at 22 units
  (often 14 to 22 pixels) stays smooth, and stays sharp on large screens.
- **The theme gives every icon** (`Header.Buttons.Icons`, by button key): `settingsButton`,
  `closeButton`, `sortButton`, `bagsButton` (Show Blizzard Bags; it was `classicButton`, the switch to the
  classic bags it replaced), `sizeButtonFull` and `sizeButtonSmall` (the size
  button by state), `bankTabsButton`, `depositButton` (the Warbank), `depositGoldButton`,
  `withdrawGoldButton` (the guild bank's: renamed from `depositButton`/`withdrawButton`, which would
  have shared the Warbank's key), `filterButton`, `sellJunkButton`, `repairAllButton`,
  `guildRepairButton`. Default names its glyphs in `Textures` (`IconSettings`, `IconSort`, ...), so a
  theme can repoint one file for every use. The panels' button lists carry no art; a key the theme
  gives no icon is an error naming it (`SetHeaderIcon`), and every theme inherits Default's.
- **Replacing one:** `Icons.<key> = { Texture, TexCoords }` or `{ Atlas }`. Theme tables merge key by
  key, so a replacement inherits what it leaves out: an `Atlas` wins over an inherited `Texture`;
  colored art says `Glyph = false` (an icon is a glyph unless it says so).
- **Colors** (`PaintHeaderIcon`): a glyph in `Color`, brighter in `HoverColor` under the pointer; art
  (`Glyph = false`) in `ArtColor` and `ArtHoverColor` (a tint suits a white glyph and darkens colored
  art into a silhouette: Parchment's ink did, asked with a screenshot). An icon's own `Color` and
  `HoverColor` win over both. Parchment inks every glyph (`Color = "Ink"`).
- **Disabled** (`SetHeaderButtonEnabled`: the vendor's Repair All, guild repair and Sell Junk, the
  guild bank's withdraw gold): drawn at `DisabledAlpha` (Default 0.3) of the color it would have, never
  brighter under the pointer; art desaturated too. Desaturating, as before, does nothing to a white
  glyph: a disabled button looked enabled. One alpha follows every theme's own icon color.
- **Scale** (asked: "we need to scale our icons as part of the quiet theme (icon scale should be part
  of theme spec in sonata)"): an icon is `Layout.HeaderButton` times `Header.Buttons.Scale` (Default
  1) times its own `Scale` (an icon in `Icons` may carry one, for art that needs fitting) across,
  centered in its button (`SetHeaderIcon`, so a theme switch and the size button's state change size
  it again). The button, its click area and its place in the header stay the layout's: shrinking the
  buttons themselves is `Layout.HeaderButton`. Quiet draws them at 0.8: its title is 20 against
  Default's 26, and 0.8 keeps the icons' share of the title about Default's.
- **Every client draws the same**: the art branches per client are gone (Blizzard's backpack art,
  `RedButton-Condense`/`-Expand` or Classic's smaller and bigger buttons, the merchant's
  `SpellIcon-256x256-*` atlases or Classic's repair icons and a coin).

Coverage: `spec/sonata/next_themes_spec.lua` ("names a glyph BetterBags ships for every header button
in Default": every key, a file of its own, a 64 x 64 RGBA PNG on disk, nothing else),
`spec/next/theme_panel_spec.lua` ("header icons": Default's color on every button, a theme's glyph
colors and hover, a theme's own art and glyph, texture coordinates, one button's own colors, disabled
glyph and art, hovered and through a theme switch, a missing key; each icon its button's size and
centered in Default, scaled by the theme and by its own `Scale`, the button unchanged, through a size
switch, a share of the layout's button size), `spec/sonata/next_themes_spec.lua` ("Quiet": its scale
below 1, Default's 1), `spec/next/bag_spec.lua`,
`spec/next/bank_spec.lua`, `spec/next/vendor_spec.lua`, `spec/next/guildbank_spec.lua` and
`spec/next/small_spec.lua` (each panel's icons, on retail and Classic, and the trilinear filter). 37
mutations, each caught (the one that first survived, art hovered in the glyph color, led to a test
whose two hover colors differ).

Not verified in game yet: how the glyphs look in each theme, and the trilinear filter on each client.

## 12. Ornaments (`next/ornaments.lua`, `Panel.Ornaments`)

Asked, for Next themes in the spirit of Sauravisus' race themes (BetterBags - Themes): "i still want some of
those pretty borders, but, you know, smaller and less large, more tasteful, and animated feeling. so for
example, i can see a green druid type one where the left side of the bag is gnarled roots and leaves". The
classic themes' borders are nine-slice frames round the window; a Next panel has no frame to wrap (a full panel
is a column at a screen edge, feathered on its inner side), so ornaments are art pieces anchored to the body.

- **A theme draws for an inner side on the left**: the body's side away from its screen edge (a backpack, which
  belongs to the right of the screen). A panel belonging to the left (the bank, the vendor, the guild bank) shows
  every ornament mirrored: its points swap sides and its art is flipped (texture coordinates), motions too.
- **An ornament** (one entry of the list, data only): its art (`Texture`, a `Textures` name or a file;
  `Color`, `Alpha`, `BlendMode`, `Desaturated`, `Layer` and `SubLevel`, ARTWORK 0 when unset), loaded
  `TRILINEAR` (art drawn smaller than it is stays smooth), and where it goes:
  - `Point = "INNER"` or `"OUTER"`: a span down that side, `Width` wide, `Start` from the top and `End` from the
    bottom, `X` toward the body's middle; `Point = "TOP"` or `"BOTTOM"`: a span along that edge, `Height` tall,
    `Start` from the inner end and `End` from the outer, `Y` down. A span's art repeats every `Tile` along it
    (its texture coordinates, loaded with the `REPEAT` wrap mode, so the art keeps its scale: the client's own
    tiling would draw it at its file's size), and again as the body changes size (a resize, a size switch: the
    body's `OnSizeChanged`); without `Tile` it is stretched.
  - `Point = "TOPINNER"`, `"TOPOUTER"`, `"BOTTOMINNER"` or `"BOTTOMOUTER"`: a piece `Width` x `Height` at that
    corner, by its own corner `Anchor` (the same one when unset), `X` toward the body's middle, `Y` down. Corners
    only: Next never anchors by a middle point (docs/next-pixel-perfect.md), and a body is often an odd number of
    pixels across.
  - `Point = "BODY"`: over the whole body, `Inset` into it (`Left`, `Right`, `Top`, `Bottom`; `Left` on the inner
    side, mirrored), its art repeating every `Tile` both ways (the Glitch theme's grid and scanlines), else stretched.
  - `Sizes = "Full"` or `"Small"`: shown at that size only (unset: both); a size switch shows and hides them.
  - `Motion`: `Sway` (degrees either way of rest about `Origin`, `BOTTOM` when unset: a full swing every
    `Period`), `Spin` (a turn every `Period` about its middle, 1 clockwise, -1 the other way), `Pulse`
    (`{ from, to }` alpha and back every `Period`), `Bob` (up that far and back every `Period`), `Delay` (where in
    its motion it starts, so pieces do not move in step). `Origin` names one of the piece's points, `INNER` and
    `OUTER` included. `Period` defaults to 4. Two motions run on the set's driver (Lua, a child of the panel's frame,
    only while one shown needs it), added for the Glitch theme (§21): `Scroll` (`X` units a second toward the outer
    side, `Y` down: a tiled piece's art moving within its tile; the rolling bar), and `Glitch` (`Every` seconds on
    average, from 0.3 to 1.7 of it, the piece glitches for `Hold` seconds, rolled anew every `GLITCH_STEP`, 0.06: a jump
    up to `Jump` units either way across and up or down on whole pixels, half the time a blink to `Blink` of its alpha,
    its art slipped up to `Slip` of a tile; then back at rest; `ornaments.Random` its randomness). A panel hiding mid-
    glitch puts the piece back at rest. Two more, added for the Halloween theme (§23): `Blink` (after `Every` seconds,
    `{ soonest, latest }`, the piece is shut, drawn at no alpha, for `Time`, 0.12 when unset, then open again; now and
    then, `Twice` of its blinks, it blinks again as soon as it has been open as long as it was shut, never a third time:
    a black cat's eyes) and `Flicker` (its alpha wandering like a candle's, never still, between `Low` of its own and its
    own, toward somewhere new every half to one and a half of a `Speed`'th of a second). Both set only the piece's alpha
    (`fade`), never its place. A panel hiding mid-blink opens it again. One more for the Make It So theme (§24): `Flash`
    (a piece that is light, not art at rest: unseen, it waits `First` seconds after the panel shows, else `Every`, `{
    soonest, latest }`, then over `Time`, 0.3 when unset, comes up to its alpha and goes out again, half a sine, and
    waits `Every` for the next; what a step waited past is how far into its flash it is; a panel hiding mid-flash puts it
    out, and it waits its `First` again next time: the comm badge's glint). The Animation switch Moving Ornaments stills
    them all (§20), and takes a piece that only flashes out altogether: held still it would shine for good.
- **Whole pixels** (docs/next-pixel-perfect.md): offsets snapped and sizes rounded on the frame's grid, so a
  piece at rest is on whole pixels. Moving pieces rest nowhere: `panelProto:MovingParts` names them (only those
  shown at the panel's size), so the pixel checks leave them out.
- **A sway eases only where it turns**: three rotations in a repeating group (out of rest to one side, across to
  the other, back through rest), eased `OUT`, `IN_OUT` and `IN`, so the piece passes rest at full speed. **Failure
  mode (fixed, reported in game: "very jerky"):** every step was eased `IN_OUT`, so the last stopped dead at rest
  and the loop began again from a standstill, a halt mid-swing once a cycle (concluded from the animation's
  definition; confirm in game). A pulse or a bob (one animation, `BOUNCE`) eases at its two turns, which is right.
- **Motion runs on the client's animation groups** (`Rotation`, `Alpha`, `Translation`, every client): no Lua
  runs while they loop, unlike the sparkles and the cloud. They play while the panel shows (`Show`, and a piece a
  size switch shows while it does) and stop when it hides (`OnHidden`); each motion has one group per piece, made
  once, emptied and rebuilt by every theme (`RemoveAnimations`, every client), started from its phase
  (`Play(reverse, offset)`, every client). A theme applied while the panel shows keeps them moving.
- **Drawn on the panel's frame**, under the body's content (the content is the body's child frames): ornaments sit
  in the body's padding and outside it (over the feather), never over items.
- **Restyled live** with the body (`styleBody`): pieces reused across themes, the ones a theme no longer has
  hidden and stopped; laid out again with the geometry (`ApplyGeometry`).
- **Checked** (`SonataNext:Check`): a `Point` that is no place, an `Anchor` that is no corner, a span or a piece
  without its size, `Sizes` that is no size, a `Motion` key that is no motion, an `Origin` that is no point; the
  art's texture and color through the usual walk.
- **A pulsing piece takes its strength from its `Pulse` alone** (no `Alpha`): whether the client multiplies an
  Alpha animation's alpha into the texture's own or replaces it is not verified (warcraft.wiki.gg's Alpha page lists
  only the API), and a pulse with no `Alpha` beside it looks the same either way.
- **A strip's art must repeat seamlessly**: its last row continues into its first, or the join shows every `Tile`
  down the bag. Art made by drawing shapes should draw past both ends and crop (a drop shadow or a blur at an end
  must see what lies beyond it), and any noise in it must repeat exactly over the tile.
- **`TexCoords`** (left, right, top, bottom) crops a piece's art to part of its file, mirrored with the panel; on a
  tiled span it crops across it (its strip of the file) while the tiles run along it. GW2_UI's header and footer bands
  are part of their files.
- **`Atlas`** draws one of the client's atlases instead of a file (not with `Tile`: an atlas tiles as its own data
  says). **`Mirror = false`** keeps a piece's art unflipped on a mirrored panel, placed mirrored all the same (a
  portrait, an icon). **`Mask`** (`Texture`, a mask file; `Inset`: `Left`, `Right`, `Top`, `Bottom`, mirrored with the
  panel) cuts its art, as Blizzard rounds its portraits (`TempPortraitAlphaMask`); a piece whose theme drops its mask
  loses it. **`Unit`** draws that unit's portrait (`SetPortraitTexture`) while the client has the unit (`UnitExists`),
  its own art otherwise, drawn again each time the panel shows (Blizzard's bank and merchant show their NPC:
  `SetPortraitToUnit("npc")`). `Check` names an ornament with no art, an atlas with `Tile`, a mask with no file.
- **`Above = true`** draws a piece on the panel's overlay (§15: over the content and a frame drawn above it), as the
  original bags' menu button sat over their border and search box (the Plain theme's bag icon); give it a `Layer` over
  the frame's pieces (`OVERLAY`). A piece keeps its texture, mask and motions on each frame it has been drawn on and
  hides the one it leaves; its mask is made on its own frame.
- **`Panels`** lists the panels a piece shows on (`Backpack`, `Bank`, `Vendor`, `GuildBank`, by the bag kind each
  shows, `const.BAG_KIND`, looked up as the panel lays out); unset, every panel. GW2_UI shows its bag's emblem on
  its bag, bank and guild bank and another on its merchant.
- **Who uses it.** BetterBags' own Guild Wars 2 theme (§8). Before it BetterBags shipped no ornamented theme. BetterBags - Themes (Sauravisus' addon) gets Next versions of
  its race themes, with their art and its generator (`themes/next/`, `textures/next/`, `tools/next_ornaments.py` there,
  registered with `Sonata:RegisterNextTheme`): Night Elf first, refined round by round toward a pull request; Blood
  Elf, Nightborne and Pandaren parked. The work, the method and the lessons: `docs/next-race-themes.md`; checking them
  against this engine: `tools/next_theme_check/`.

Coverage: `spec/next/ornaments_spec.lua` (spans down a side and along an edge, their tiles, mirroring, corner
pieces and anchors, art and layer, sizes, tiles following the body, whole pixels on both sides; restyling,
reuse; sway, spin, pulse and bob, mirrored, phases, start and stop, a piece shown by a size switch, a motion
dropped by a theme, moving parts), `spec/next/theme_panel_spec.lua` ("ornaments": on the real backpack and bank,
mirrored, moving only while shown and through a theme, at their size through a real size switch, moving parts),
`spec/sonata/next_engine_spec.lua` ("names what is wrong with an ornament"); atlases, masks, units and crops:
`spec/next/ornaments_spec.lua` ("portraits", "tiles a span along it and crops it across"). 23 mutations, each caught (three
first survived and led to tests).

## 13. The side rail (`Header.Buttons.Rail`)

Asked, for the Guild Wars 2 theme: "you can move the top icon buttons to be side buttons, and side buttons can be
left on backpack, and right on other bags" (docs/next-gw2-theme.md). GW2_UI's windows keep their buttons on a
40-pixel side panel.

- **The schema**: `Rail = { Width, Top, Gap, Fill }`, or false (Default). `Width` is the strip's width, `Top` the
  first button's top from the body's top, `Gap` between buttons (`Layout.HeaderButtonGap` when unset), `Fill` the
  strip's art (a texture spec; false: room and buttons, no art). The buttons keep `Layout.HeaderButton`'s size.
- **Where**: inside the body along its inner side (away from its screen edge): the backpack's left, the bank's,
  vendor's and guild bank's right. The tab rail still hangs outside that edge. The strip is a texture on the panel's
  frame (BACKGROUND 7: over the body's fill and feather, under its edge, wash and ornaments), anchored to the body's
  inner corners, its art mirrored on a panel whose inner side is on the right.
- **The buttons** (`layoutRail`) go down it in the order they went across the header (the first at the top), each
  centered across the strip and placed by its corner on whole pixels (`Top` snapped, each step the button's length
  plus the snapped gap); a hidden button leaves no gap. Their tooltips open beside the strip, away from the panel
  (`ANCHOR_LEFT` on the backpack, `ANCHOR_RIGHT` on the others).
- **The room**: the body is `Width` wider (`NextStyle.RAIL`, in `BODY_WIDTH`), so the content keeps the grid's width.
  Everything inside the body keeps `Width` more room on its inner side (`InnerPad`, `SidePads`): the title (and its
  glow, its cloud's span, the ribbon's join), the search box, the scroll area and the canvas's widths, the footer's
  line and free slots; the money stays on the outer side. The header has no buttons, so the title takes its whole
  row (`FitTitle`). A small panel goes no narrower than the strip and what it held before (`MinWidth`), nor shorter
  than its buttons down the strip and `Pad` below them (`MinHeight`).
- **Theme-dependent geometry is read live.** The sparkles' ribbon start captured the title's join when the panel was
  built; with the title's inset now a theme's (its `Pad`, `TitleInset` and rail), a panel built under one theme and
  switched to another started its ribbon sparkles inside the body (found by the rail's tests: 136 against the edge
  at 96). It is read on every spawn.
- **Outside the body** (`Outside = true`, round two: GW2_UI's side panel stands beside its windows): the strip stands
  against the body's inner edge, outside it (`NextStyle.RAIL_OUT`); the body keeps its width and its content its
  room (`RAIL` is 0); the buttons are centered across the strip outside; the tab rail hangs past the strip; a chained
  pair is spaced for both strips (`chain:Gap`, `SmallGap`); a small panel keeps the strip on the screen with it
  (`clampPlace`, on its inner side).
- **Pinned buttons** (`Header.Buttons.Pinned = { key = { Point, X, Y } }`; asked: "X button should still be top
  right"): a button pinned to a corner of the body, by WoW offsets, apart from the rail or the header row. `Point` is
  a corner of the body (`TOPRIGHT`, ...) or one named by its side (`TOPINNER`, `TOPOUTER`, `BOTTOMINNER`,
  `BOTTOMOUTER`, as ornaments name theirs): drawn for the backpack, whose inner side is on the left, mirrored (its
  `X` too) on a panel on the left of the screen. A pinned button is left out of the row's width and the rail, and
  the title keeps clear of the farthest pin along the top (`pinnedRoom`, in `FitTitle` and a small panel's
  `MinWidth`; pins side by side are not added up, a pin at a bottom corner takes no room). `Check` names an unknown
  corner.
- **An icon's highlight** (an icon's `Highlight`: `Texture` or `Atlas`, with `TexCoords`, `BlendMode` (BLEND unless
  set), `Alpha`): art drawn over the icon while it is hovered and enabled, as a button's highlight texture is drawn
  over its normal art; GW2_UI highlights its buttons so (its bag's `-down` art over the `-up`, its micro menu's icon
  over itself, `Micromenu/micromenu.lua`). It replaced swapping the icon's art (`Hover`, round two): asked, the side
  buttons highlighted unevenly, only the one with `-down` art brightening.
- **The strip's art from `Start`** below the body's top (GW2_UI's side panel runs from its window's top line,
  `GwWindowLeftPanel`); the buttons still from `Top`.
- **Coverage**: `spec/next/theme_panel_spec.lua` ("a side rail (Header.Buttons.Rail)": both sides, centered, from
  its top; hidden buttons; the header's gap; the strip, its art, mirrored, none without art or a rail, back across
  the header; the room for every part; the title's glow, cloud and sparkles; tooltips; "outside the body
  (Outside)", its art's start; "pinned buttons (Pinned)": a corner of the body, by its side, out of the row; "header
  icons": the highlight), `spec/next/small_spec.lua` (a pinned button's room, the farthest pin's, a strip outside kept
  on the screen),
  ("with its header buttons down a side rail": minimum width and height, the title's room), `spec/next/vendor_spec.lua`
  and `spec/next/guildbank_spec.lua` (down their right), `spec/sonata/next_engine_spec.lua` ("names what a side rail
  lacks"), `spec/next/pixel_perfect_spec.lua` (every shipped theme, Guild Wars 2's rail included, on whole pixels).

## 14. Art where a color was

Asked, of the Guild Wars 2 theme: "when i say theme for gw2, i also mean tabs, i mean everything. be more
comprehensive and match not just colors in sonata, but art of buttons, art of toggles, all of it. go deeper here in
expanding what sonata can do" (and keep it declarative). Parts that took only a color now take art too.

- **The contract**: `NextStyle:IsArt(fill)` says a fill is art (a texture spec with a `Texture` or an `Atlas`); art is
  drawn with `NextStyle:Paint` (tinted by `Color`, at `Alpha`), a color its own way. Switching back to a color resets
  what art left: the texture's coordinates, and a plain white texture under the color.
- **Tabs** (`Tabs.Fill`, `SelectedFill`): art is drawn for the backpack's tabs, which stick out to the left, and
  mirrored on the other panels; colors keep their fade. **The selected bar** (`Tabs.Indicator`) may be art, tinted by
  the tab's accent.
- **The search box** (`Search.Fill`, `FocusFill`).
- **Sections**: `Sections.Header`, art behind the title row across the section, `Layout.SectionHeader` tall, under
  the title, count and line (BACKGROUND); `Line` and `Highlight` may be art.
- **Lines**: the footer's (mirrored with the panel), the settings window's brand line, the top tabs' marker.
- **Check boxes** (`Controls.Toggle.Style = "Check"`): the box (`Off`) and the hover fill the switch; the mark (`On`)
  over it as strong as it is on; while disabled, `Disabled` for the box and `DisabledOn` for the mark, and no dimming
  when it has `Disabled`. No knob, no edge, no round ends. `Check` names an unknown `Style`.
- **Buttons** (`DisabledFill`, per style): drawn while disabled, and the button is then not dimmed by
  `DisabledAlpha`, on a theme switch too.
- **Vendor cards** (`Vendor.CardFill`, `CardHover`).
- **Inherited alphas** (round three; reported in game: Guild Wars 2's Done and Delete buttons dark and unreadable):
  a theme's spec merges with Default's key by key (§2), so art a theme draws over one of Default's faint colored fills
  took that fill's `Alpha` (the Primary fill's 0.14, the Danger fill's 0.1; the scroll thumbs' and the settings
  divider's too). Every art spec in Guild Wars 2 now sets its `Alpha`, and `spec/sonata/next_themes_spec.lua` ("draws
  the art each theme sets at the alpha it sets") checks every shipped theme on every client.
- **Light edges in art** (round five; reported in game: a thin white line between Guild Wars 2's side panel and the
  bag): GW2_UI's side panel art's last column, the one against the window, is white at 55% (every other column
  black), and the world map painting's last 17 columns fade out (opaque 0 to 1006 of 1024), which shows the world
  through beside the bank's side panel. Both are cropped to their solid part (`TexCoords`). Measure a file's edge
  columns and rows before drawing it against something (`docs/next-gw2-theme.md`); GW2_UI's header and footer bands
  are dark to their edges. Coverage: `spec/sonata/next_themes_spec.lua` ("is the original's frame").
- **A border a theme does not draw** (round five; reported in game with Guild Wars 2: a white border round the bag
  on a size switch either way): a size switch (`Morph`) showed the border's four lines whatever the theme, to fade the
  border across the switch, and a theme without one (`Panel.Edge = false`) never colors them (`paintEdges` returns),
  so they showed as created, white, until the switch's end hid them. The switch now shows them only when the theme
  has a border. Coverage: `spec/next/small_spec.lua` ("shows no border on a switch either way under a theme without
  one").
- **Tab names cut short** (round four; reported in game: "Backpa..." on the selected tab): the client keeps the width
  a font string took when its text was set through a later font change, and cuts text past it with "..." (Blizzard
  resets it by setting the width to 0 and the text again, `QuestLogTitleButton_Resize`; sonata.md 3c measured it on
  the classic settings window). A tab's name is set in its idle font and switched to its selected font when chosen;
  Guild Wars 2's selected font has a shadow, slightly wider. `NextTabs` now resets a name's width that way and sets it
  to its text's in the font it has now, after every name and font change (`placeContent`), as the classic settings
  navigation does (`fitNavText`). The specs' mock measures text the same in every font, so the test makes a tab's
  text measure 0.8 wider in the selected font, as measured in game. The settings sidebar's labels are anchored at both
  ends, so their width is the row's and this cannot happen to them. Coverage: `spec/next/tabs_spec.lua` ("keeps a
  tab's name as wide as its text in the font it has now").
- **A wash a theme does not draw** (round three; reported in game: the bank broke opening, `next/panel.lua:2075:
  attempt to index upvalue 'from'` in `SetWash`): a panel made under a theme without a wash (Guild Wars 2, Parchment,
  Quiet) never painted one, so changing it (the bank's type, the guild bank) faded from nothing. `SetWash` now only
  records the wash's key under such a theme, and a theme with a wash paints it in that key's color. Earlier specs made
  the bank under Default before switching themes. Coverage: `spec/next/theme_panel_spec.lua` ("changes its wash under
  a theme without one").
- **The frame mock** follows the client: `SetVertexColor` replaces a gradient (warcraft.wiki.gg Region:SetVertexColor
  sets all four corners' colors, and TextureBase:SetGradient points to it; Blizzard's `MarchingAntsMixin` switches
  one texture between the two by orientation). It kept the gradient before, which hid a tab keeping its old
  gradient after switching to art.
- **Coverage**: `spec/next/tabs_spec.lua` (tab art, mirrored, colors after; bar art), `spec/next/theme_panel_spec.lua`
  (search art, footer line art), `spec/next/content_spec.lua` (the row, line and highlight art),
  `spec/next/settings/window_spec.lua` (brand line art), `spec/next/controls/panel_controls_spec.lua` (marker art),
  `spec/next/controls/button_spec.lua` ("in the check style"; disabled art, on a theme switch),
  `spec/next/vendorbutton_spec.lua` (card art), `spec/sonata/next_engine_spec.lua` (toggle styles, pinned corners).

## 15. Frames (`next/frameart.lua`, `Panel.Frame`, `Settings.Frame`, `Controls.Dialog.Frame`)

**Why.** Blizzard builds its windows from nine-slice layouts (`Blizzard_SharedXML/<Family>/NineSliceLayouts.lua`): the
retail bags' `HeldBagLayout`, the settings window's `ButtonFrameTemplateNoPortrait`. Next cannot host Blizzard's frame
templates (its panels draw themselves, mirror, slide, morph and chain), so `NextFrameArt` draws the same art from data.

- **A layout by name**: `Frame = { Layout = "HeldBagLayout" }` reads `NineSliceUtil.GetLayout(name)` at apply: the
  client's own art and offsets, Forever's load-time adjustments included (`Camelot/NineSliceLayoutOverrides.lua`).
  A layout that sets its pieces up itself (`setupPieceVisualsFunction`) or needs a texture kit (`%s` atlases) is an
  error; `Check` names a layout the client lacks.
- **Or pieces**: `Frame = { Pieces = { TopLeftCorner = { Atlas | Texture, TexCoords, Width, Height, HorizTile,
  VertTile, X, Y, X1, Y1 }, ... } }`, named as Blizzard names them (`Check` names an unknown piece).
- **Placed by Blizzard's rules** (`NineSliceUtil.ApplyLayout`, `NineSlice.lua`, every client): corners at their corner
  by their offsets at their atlas size (`C_Texture.GetAtlasInfo`); edges between their two corners, as thick as their
  atlas, tiled as it says; the center between the top left and bottom right corners; three-slice layouts against the
  region; `mirrorLayout` flips the mirrored pieces; `disableSharpening` turns pixel snapping off (each texture's own
  snapping given back for a layout without it). An atlas the client lacks draws nothing, as Blizzard's does.
- **Mirrored** on a panel whose inner side is on the right (the bank), as ornaments are: each piece in the opposite
  place, flipped, offsets negated.
- **`Bands`**: strips across the region's top (texture specs with `Height`, `Left`, `Right`, `Top`; mirrored), each over
  the one before, in the owner's `BACKGROUND` layer over its fills and under the frame's pieces, as Blizzard's are in its
  frames': `DefaultPanelTemplate`'s `TopTileStreaks`, Classic's `_UI-Frame-TitleTileBg`. (It replaced a single
  `TitleBg`.)
- **Where**: on the owner frame's `ARTWORK` 5 (`Layer`, `SubLevel`), tinted by `Color` and `Alpha`, under everything in
  the owner's child frames (Blizzard's settings window: `SettingsFrameTemplate`'s NineSlice `useParentLevel`, its
  content placed inside it); the panel frames its body, the settings window itself, a dialog its card.
- **`Above = true`**: on the frame `Create` was given to draw above the content (the panel's overlay, `next/panel.lua`:
  20 levels over its frame, over the content's sections and item buttons, never taking the mouse), as the original bags
  raised their border over their content (Sonata's Default: NineSlice at +500). The panel's title is on the overlay
  (`OVERLAY`, over the art) and its header buttons above it, as Blizzard's title and close sit over its NineSlice (510
  over 500). A set drawn on another frame keeps its pieces there and hides them; a set given no such frame refuses
  `Above`. Ornaments that say `Above` are drawn on the overlay too (§12).
- **Coverage**: `spec/next/frameart_spec.lua` (with Blizzard's layouts per client, `spec/fixtures/nineslice_layouts.lua`,
  copied from each branch, Forever's adjustments applied by a copy of Blizzard's code), `spec/next/theme_panel_spec.lua`
  ("draws a frame round its body, mirrored on the bank", "draws a frame that says Above over its content"),
  `spec/next/settings/window_spec.lua`,
  `spec/next/controls/panel_controls_spec.lua`, `spec/sonata/next_engine_spec.lua` ("names what is wrong with a frame").

## 16. Fills (`next/fill.lua`)

**Why.** Blizzard draws its buttons, sliders, scroll bars and inputs in three pieces, a begin cap, a stretched middle
and an end cap, and many of its fills reach past their frame (a dropdown's background) or sit inside it (a window's).

- `NextFill:Wrap(texture, region)` makes a widget's own texture a fill: the texture stays the fill (its middle when
  pieced), so the widget and its specs keep using it, and the fill adds its caps beside it. `NextControls:Paint` paints a
  wrapped texture through its fill.
- **One piece**: a texture spec filling the region, `Inset` into it (`Left`, `Right`, `Top`, `Bottom`; negative reaches
  past), or at its atlas's own size (`AtlasSize = true`) by its `Point` (CENTER when unset, `X`, `Y`).
- **Pieced**: `Pieces = "Horizontal"` or `"Vertical"`; `Begin`, `Middle`, `End`, each its own `Atlas` or `Texture` with
  `TexCoords` (else the fill's); the caps `Size` long (else their atlas's); `Thickness` thick and centered (else the
  region's), or `"Atlas"`: each piece its atlas's own thickness, the caps by their middles (or by their bottom corners
  with `Align = "BOTTOM"`), the middle hung from the caps' tops (MinimalSliderTemplate, MinimalTabTemplate); tinted by
  the fill's `Color` and alpha.
- **Wrapped**: buttons (and their `Highlight`), slider bars and scroll bar tracks (each in a frame of its own where the
  strip goes: `barFrame`, `trackFrame`), scroll thumbs, inputs and text areas, dropdowns, menus (and their `Border`),
  dialog cards (and their `Border`), the settings window's fill, the settings list's rows, page tabs.
- **Coverage**: `spec/next/fill_spec.lua`, and each widget's spec ("in three pieces", "past it", "at its atlas's size").

## 17. Blizzard's look in controls (for the Plain theme)

Each of these is how Blizzard draws a control, read from its template (docs/next-plain-theme.md), and generally
available to themes:

- **Atlases at their own size** (`useAtlasSize`): `NextStyle:AtlasSize(atlas)` and `SizeOf(spec, art, fallback)`
  (`Size = "Atlas"`); the slider's `ThumbSize = "Atlas"`; fills above.
- **The dropdown's arrow in its art for each state** (`GetWowStyle1ArrowButtonState`): `Chevron.Hover`, `Pressed`
  (pressed under the pointer), `Open`, `Disabled`, at `Size = "Atlas"`, by its right at `Point` from the dropdown's right
  edge; `Justify` (Classic writes the choice right, against the arrow); `DisabledFont` and `DisabledAlpha` (Blizzard
  grays the text and swaps the arrow, dimming nothing); `NarrowWidth` and `NarrowFill` (Classic's `-small` background at
  100 wide or less).
- **Radio menus** (`MenuVariants.CreateRadio`): `Check.Off`, the empty ring on every row not chosen, and `Check.Under`,
  the ring under the chosen row's tick at its top left (retail draws two textures; Classic swaps one, so no `Under`);
  `Menu.Inset` per side (`MenuStyle1Mixin:GetInset`), `Menu.Border` over its fill (Classic's art).
- **The dialog**: `Border` over its `Card` (today's popup: the diamond border over the dark background).
- **Page tabs** (`MinimalTabTemplate`): each tab's `Fill`, `HoverFill`, `SelectedFill`, `Padding` either side of its
  label, the label by its bottom `TextBottom` above the tab's (`SelectedTextBottom` chosen); `Indicator = false` and
  `Line = false` hide the marker and line for good.
- **The settings list** (`Blizzard_CategoryList.lua`): `Spacing`, `TextRaise`, `GroupFills`, `GroupLabel`, atlas-sized
  row fills; `Close.Atlas`, `Close.Highlight`, `Close.Offset`.
- **The settings slider** (`MinimalSliderWithSteppersTemplate`, `MinimalSlider.lua`): `Slider.Steppers` (`Back`,
  `Forward`: `Atlas` or `Texture`, `Width`, `Height`; `Gap` out from the bar's ends; `Room` left either side of the bar;
  `DisabledAlpha` for a stepper whose way the value can go no further, desaturated too), each stepping the value by its
  step; `Slider.Value = "Text"` writes the value `ValueGap` right of the bar in `ValueFont` (`ValueDisabledFont`
  disabled) instead of the box to type in; `Slider.DisabledAlpha` dims the bar alone while disabled (Blizzard's 0.7).
- **The settings dropdown** (`WowStyle2DropdownTemplate`, `DropdownWithSteppersTemplate`): `PressedFill` and
  `DisabledFill` (its art for each state, `GetBackgroundAtlas`); `Chevron.Anchor` (the point it hangs by, `BOTTOM` for
  WowStyle2's arrow) and `Chevron.HoverOnly` (shown only under the pointer); `Steppers` (`Back`, `Next`: an atlas and its
  `Disabled` art; `Width`, `Height`; `BackGap`, `NextGap` out from the dropdown; `Fill` and its states for the buttons,
  at their atlas size centered with `AtlasSize`), stepping to the choice before or after, off at the ends and while the
  dropdown is; `Dropdown.Menu`, what the menu a dropdown opens changes in `Controls.Menu` (`NextMenuOptions.style`,
  merged key by key: Blizzard's settings dropdowns open `MenuStyle2`).
- **The bag search box**: `Search.Inset` (`Left`, `Right`: the box in from the body's sides, mirrored on the bank, else
  the side pads), `Search.Inner` (`IconX`, `IconY`, `IconSize`, `TextLeft`, `TextRight`, `ClearRight`: its insides as
  `SearchBoxTemplate` anchors them, else Next's own layout), `Search.HelpColor` (the template's own color for its help).
- **Smaller ones**: a button's `Highlight`, `DisabledFont` and `SetStyle` (a button changing looks), the magnifier's
  `ActiveColor`, `Search.Template`, a header icon's `Pushed` and `Disabled`, a centered title, `RowStart`, tab
  `Highlight`s, ornaments' `Atlas`, `Mask`, `Unit` and `Above` (§12), palette `Global` colors, `Copy` fonts, an input's
  icon `Atlas`.

## 18. The settings window as Blizzard's (`next/settings/window.lua`, `page.lua`, `rows.lua`)

**Why.** Reported in game (round two, docs/next-plain-theme.md): Plain's settings window was Next's own layout in
Blizzard's art (a full-height sidebar from the window's edge, its fill and list art over the border, the brand, two
columns of cards, controls at the far right, tabs floating under the header). Blizzard's settings window
(`Blizzard_SettingsPanel.xml`, the same on every client) is laid out differently; these keys let a theme lay Next's
window out as Blizzard's. Each defaults to Next's own layout, so Default and the other themes do not move (the window
specs that predate them pass unchanged).
Plain laid its settings window out with them in round two; round three went back to Default's layout, skinned (asked: "keep
it like we do in default, just, pass over with skin a bit"; docs/next-plain-theme.md). They stay for a theme that wants
Blizzard's window, covered by their own specs.

- **The window**: `Settings.Title` (`Font`, `Top`, `Left`, `Right`, `Height`: the window's name in its title bar, centered
  between `Left` and `Right`, the bar `Height` tall moving the window), `Settings.InnerFrame` (a fill on the window under
  its content: `Options_InnerFrame` at its size at 17, -64), `Brand = false` (no brand: its icon, name and line hide).
- **The sidebar**: `Sidebar.Left`, `Top`, `Bottom` (the sidebar inside the window, `Left` in and `Top` down to `Bottom`
  above its bottom; its height everything a page's list and the slide measure from), `Back.Height` (the row Back sits in,
  else the brand's); `Nav.ItemWidth` (rows and headings that wide from the list's left), `Nav.GroupUpper = false`
  (headings as written).
- **The search box**: `Search.Place = "Top"` with `Width`, `Right`, `Top` (on the window at its top right), `Search.Atlas`
  (its magnifier an atlas). The pages' list then starts at the sidebar's top.
- **The version**: `Version.Window` with `Left`, `Bottom` (at the window's bottom left).
- **The header and content**: `Header.Left`, `Right`, `Top` (the content from `Left` right of the sidebar to `Right` from
  the window's right, its header `Top` down), `Header.DescriptionFont = false` (no description), `Header.Divider` (a fill
  on the header: `Options_HorizontalDivider` centered 50 down), `Header.Actions.Right` (a page's buttons from the header's
  right; else clear of a close button in its corner); `Settings.Tabs.Top`, `Left` (a page's tabs on the window, `Top`
  down from the content's left, taking no room under the header); `Content.ScrollLeft`, `ScrollRight`, `ScrollTop` (the
  scroll area beside the content's left, in from its right, below the header).
- **The footer**: `Footer.Left` (from the window's left), `Footer.Buttons` (`Width`, `Right`, `Bottom`, `Gap`: Done that
  wide at the bottom right, What's New left of it), `Footer.WhatsNew` (What's New's look: a link, or a button).
- **The page as Blizzard's list** (`Content.Layout = "List"`, `SettingsListTemplate`, `SettingControls`): one column `Pad`
  in and `PadRight` from the right, `Top` and `Bottom` padding, `RowGap` between every element; a section's title element
  `SectionHeight` tall, its title `TitleX` in and `TitleTop` down, as written unless `TitleUpper`; rows at least
  `RowHeight` tall, a setting's name `LabelX` in up to `LabelRight` from the row's middle (wrapping there), each control
  from the middle by its kind's `Content.Controls[kind]` (`X`, `Y` up: `toggle`, `slider`, `dropdown`, `color`, `input`,
  `buttons`), a row lit across it from `HoverInset.Left` past its left to `HoverInset.Right` short of its right; no cards
  or lines.
- **Coverage**: `spec/next/settings/window_spec.lua` ("laid out as Blizzard's settings window"),
  `spec/next/settings/page_spec.lua` (both "laid out as Blizzard's list" blocks), `spec/next/controls/slider_spec.lua`
  ("with steppers and its value written"), `spec/next/controls/dropdown_spec.lua` ("as Blizzard's settings dropdown"),
  `spec/next/theme_panel_spec.lua` ("sits Inset in from its body's sides…", "the Plain theme").

## 19. The bag button (`next/menubutton.lua`, `Header.Buttons.Menu`)

**Why.** Asked, of the Plain theme: "remove all top bar buttons, make sure our bag title is always correctly centered from
the right of the bag button, to the left of the close button", "bring back the drop down menu with these options, just
like the original bags ... just the options we are removing from the bar", "same for vendors and bank", and "vendors
should have their portrait for the bag button, not the bag texture" (docs/next-plain-theme.md, round three).

- **The schema**: `Header.Buttons.Menu = { Point, Anchor, X, Y, Width, Height, Layers, Highlight, Panels }`, or nothing
  (Default). `Point` is a corner of the body by its side (`TOPINNER`, `TOPOUTER`, `BOTTOMINNER`, `BOTTOMOUTER`), the
  button placed by its own `Anchor` (the same corner when unset), `X` toward the body's middle and `Y` down, as an
  ornament's corner piece (§12), mirrored on a panel whose inner side is on the right. Each of its `Layers` (in order,
  each over the one before; `Layer`, `SubLevel`) is a file (`Texture`, `TexCoords`), an atlas, a unit's portrait (`Unit`:
  while the client has the unit, `SetPortraitTexture`; nothing while it has none) or only a `Color` (filled with it),
  inset into the button (`Inset`: `Left`, `Right`, `Top`, `Bottom`; negative reaches past), cut by a `Mask`, never
  flipped; `Highlight` the same over them, faded in under the pointer (`Time.Hover`) to its `Alpha`. `Panels` gives a
  panel its own keys over the rest (`Backpack`, `Bank`, `Vendor`, `GuildBank`, as ornaments name them): the vendor's
  portrait. The art and masks are drawn with the ornaments' own functions (`NextOrnaments:DrawArt`, `Cut`).
- **The row goes in its menu**: while a theme has one, every header button that is not pinned (§13) goes under a hidden
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

## 20. The player's Animation switches (Appearance > Animation)

Asked: "we need a way to disable sparkles etc on any theme, not just switching to a theme without them", on a new tab of
Appearance, then "title it 'Animation'". Each switch turns one of BetterBags Next's effects off on whatever theme is in
use, and back on.

- **The switches** (the settings catalog, `config/catalog.lua`; the Animation tab's Effects section,
  next-settings.md §4), each on until turned off:

  | Setting | Saved as | Takes out of the theme in use |
  |---|---|---|
  | Sparkles (`nextSparkles`) | `sparkles` | `Sparkles`: every emitter (title cloud, ribbon, edge, the knot's burst) |
  | Title Shimmer (`nextShimmer`) | `shimmer` | `Header.Spark`: the spark gliding along the ribbon into the cloud |
  | Title Cloud (`nextTitleCloud`) | `titleCloud` | `Header.Cloud`: the puffs breathing behind the title, and the join |
  | Title Ribbon (`nextTitleRibbon`) | `ribbon` | `Header.Ribbon`: the gold line from the title out past the window's edge (asked: "the spike that comes off of the bag"); the shimmer, left on, flares where it began |
  | Braid (`nextBraid`) | `braid` | `Chain.Braid` (false): the ribbons twisting between chained bags |
  | Moving Ornaments (`nextOrnamentMotion`) | `ornaments` | each ornament's `Motion` (§12): it stands still, its art kept |
  | Glitch Effects (`nextGlitch`) | `glitch` | `Panel.Glitch` (§21): no flicker, tears or bursts; the bags slide in and out as any theme's. Flicker can be hard on some players' eyes |
  | Data Rain (`nextRain`) | `rain` | `Panel.Rain` (§21): no glyphs falling |
  | Ice Shatter (`nextShatter`) | `shatter` | `Panel.Shatter` (§22): no freezing together or shattering; the bags slide in and out as any theme's |
  | Snow, Leaves and Stars (`nextSnow`) | `snow` | `Panel.Snow` (§22): no snow, falling leaves, stars at warp, gusts, wind streaks or shooting stars. Titled Snowfall until the Halloween theme's leaves fell through the same engine, then Snow and Leaves until the Make It So theme's stars did |
  | Smoke Puff (`nextSmoke`) | `smoke` | `Panel.Smoke` (§23): no smoke; the bags slide in as any theme's |
  | Bats (`nextBats`) | `bats` | `Panel.Bats` (§23): no breaking up into bats, no fluttering bats; the bags slide out as any theme's |
  | Transporter (`nextBeam`) | `beam` | `Panel.Beam` (§24): no beaming in or out; the bags slide in and out as any theme's |

  Moving Ornaments also holds a theme's threads of light still (§22: each thread's `Sway` and `Glint` taken out, its art
  and its draw-in as the panel opens kept).

  Saved per profile in `nextAnimation` (`DB:GetNextAnimation(name)`, `DB:SetNextAnimation(name, on)`; any other name is
  an error, the names being the defaults' in `const.DATABASE_DEFAULTS`). Each switch sends `next/AnimationChanged`.
- **How:** `SonataNext:effective(key)` resolves a theme (a new table) and runs, for each switch turned off, what it
  takes out (`ANIMATION_OFF`, `sonata/next.lua`): a table set to nil, as resolution removes a table a theme sets to
  `false`, and `Chain.Braid` set to false (a boolean). The theme in use is always the effective one: Next starting
  (`use`), a theme applied or previewed (`ApplyTheme`), the theme handed out (`GetCurrentTheme`). `Resolve` and `Check`
  keep a theme as it is written, for theme authors. No widget checks a switch: every part a switch removes is one a
  shipped theme already leaves out (Quiet, Parchment, Guild Wars 2, Plain), and `spec/next/shipped_themes_spec.lua`
  draws every window with them absent. The title's glow and the wash are left alone: they are no animation.
- **Every combination must draw.** Each part is one some theme leaves out, but no theme leaves out every set of them
  together. **Failure mode (fixed, reported: "turning off title shimmer causes the background behind the word Backpack
  to BLIND ME"):** with a cloud and no spark (no shipped theme has that), the header's styling settled the shimmer's
  swell by drawing the cloud (`SetCloudSwell(0)`) before its new puffs were laid out; drawing a puff with no place
  failed (silently: each widget restyles in a protected call), and the cloud's driver failed every frame after, leaving
  the puffs at full strength, added as light. It now only resets the swell; the cloud is drawn once laid out
  (`LayoutCloud`, at the end of the header's styling). A spec draws an open bag under all 64 combinations of the
  switches, errors captured, and runs the cloud's driver each time.
- **A switch changed** (`next/AnimationChanged`, followed by `SonataNext:WatchAnimation`, registered once, started by
  `core/init.lua` after `WatchClientFonts`): `SonataNext:ApplyAnimation(ctx)` lays the switches over the current theme
  again, hands it to Next's style keeping the font objects (`NextStyle:Use(theme, true)`: the switches touch no font,
  and font objects can never be freed, so a theme applied on every click would leave a set behind each time), and
  restyles every widget: an open bag stops its emitters (`SetEnabled(false)` clears every sparkle) or starts them
  again, hides its spark or glides it again, and so on, at once. Nothing is saved or announced
  (`sonata/NextThemeChanged` is not sent: no theme changed). Nothing before Next starts.
- **Not done:** the motion of the layout itself (items gliding, the sections' fade-in cascade, slides): a "reduce
  motion" setting is a different kind, for later.
- **Coverage:** `spec/sonata/next_engine_spec.lua` ("the player's Animation switches": each part out and the rest left,
  nothing out while on, over every theme applied and previewed, `Resolve` untouched, `ApplyAnimation` keeping the font
  objects and restyling, nothing before the start, the theme handed out before any is in use, the message followed and
  registered once), `spec/next/style_theme_spec.lua` (keeping font objects), `spec/next/theme_panel_spec.lua` ("the
  Animation switches": on real panels, every sparkle stopped and started, through a theme applied and a bag made later,
  the shimmer, the cloud with the ribbon kept, the ribbon with the cloud kept, the cloud at its own strength with the
  shimmer off and settled mid-swell, every combination of the switches without an error, a coupled pair's braid, a
  moving ornament stilled with its art kept),
  `spec/database_spec.lua`, `spec/config/settings_effects_spec.lua` (each switch saves and sends the message),
  `spec/next/settings/content_spec.lua` (the tab, its switches, Next only, search),
  `spec/integration/next_settings_spec.lua` (the tab built on the whole addon), `spec/core/init_spec.lua` (the order).
  20 mutations, each caught; the one that first survived (the theme handed out before any is in use) led to a test.
  Then 4 for the ribbon and the cloud's fix, each caught (drawing the cloud early, not settling its swell, the ribbon
  left in, its row left out).

## 21. The Glitch theme's engine (`next/glitch.lua`, `next/rain.lua`, and smaller pieces)

Asked: "a 'glitch' theme, where the bag sort of 'glitches' into existance when opening, glitches out when closing. think
flickers, glitched blinking textures that wobble suddenly and harshly, think green mesh. i want to push the limits of
what's possible here ... you can expand sonata if needed", kept local until it is shown. The theme is §8's; what it
needed of the engine is here, all of it data a theme gives, none of it the Glitch theme's alone.

- **Glitching in and out, and now and then** (`Panel.Glitch`, NextGlitch, driven by the panel: `glitchIn`, `glitchOut`,
  `burst`, `endGlitch`). With `Open`, a panel opens where it rests instead of sliding in: `PowerOn` seconds of a CRT
  warming up (the `Beam`, `{ Color, Alpha, Height, BlendMode }`, a line across the body's middle opening to its height,
  the panel unseen), then `Time` seconds of moments, one every `Step`, each at a strength falling from 1 to 0: the panel
  jumping up to `Jitter` units sideways (whole pixels) and flickering between `Flicker[1]` and `Flicker[2]` of its alpha
  (lit more often as the strength falls), bands of a frame tearing across the body (`Tears`: `Count` at full strength,
  `Texture`, `Height` range, `Alpha`, `BlendMode`, their art slipped), datamosh blocks (`Blocks`: `Count`, `Texture`,
  `Size` range, `Colors`), static over the body (`Noise`), the title's colour ghosts split up to `Ghosts` units either
  way, its letters corrupted (`Corrupt`: each swapped for one of `Glyphs` at `Chance` times the strength; a letter and a
  glyph are UTF-8 characters; never a title the panel may not read, a secret: a vendor's name in an instance), and a
  third of its sections shoved up to `Sections` units sideways (a Translation animation on the client, which moves what
  is drawn, not where the frame is laid out, so the canvas keeps its layout). With `Close`, it closes where it is:
  `Time` seconds of moments rising in strength, then `PowerOff` of the CRT turning off (squashed to a line, the line
  shrinking to a point), then hidden. With `Bursts` (`Every`, `Time`), a burst now and then while it shows (`Every` on
  average, 0.4 to 1.6 of it): moments rising and falling over `Time`; never in combat, nor while the panel moves, is
  moved or sized, or a section is held (it waits for the next); with the pointer over the panel nothing that takes a
  click moves (no jump, no shove). A chained bag waiting out its entrance delay waits unseen, then glitches in.
  - **The glitch layer**: a frame over the body, 100 levels above the panel's frame (over its content, overlay and
    sparkles), drawn at its own alpha (`SetIgnoreParentAlpha`), so a glitch shows while the panel flickers to nothing;
    it takes no mouse. Everything a moment draws is on it; `NextGlitch:Rest` hides it and puts the panel back (sections,
    ghosts, letters).
  - **Cut short or its theme gone**: whatever replaces or stops the panel's tween (a flight, Escape, a hide) ends the
    glitch at rest (the tween's new `onStop`), back at full strength and in the place it was glitching in or out from
    (`endGlitch(base)`: each glitch its own base), unless another tween has taken the panel over, which places it; every
    hide drops a burst scheduled or under way (a token per schedule). A
    theme applied without a glitch (another theme, Glitch Effects off) mid-glitch: the opening shows the panel plainly
    and finishes (it still says it has shown), a burst or a closing goes on at rest (`Roll` and `Beam` rest the panel
    and do nothing without `Panel.Glitch`), and a theme with bursts applied while it shows schedules them (its
    `ApplyStyle`). **Failure mode (fixed before it shipped, found by reading the burst's code):** every moment read
    `Panel.Glitch` anew, so a theme applied mid-glitch errored every frame of the rest of it (`attempt to index local
    'G' (a nil value)`); the spec reproduced it before the fix.
  - **Bursts yield** to whatever else places the panel: none starts, and one under way stops at rest, while the
    player moves or sizes it, it switches size or glides to one (`placedElsewhere`), or once something else has placed
    it (its offset is no longer the one the burst wrote); a burst never changes a panel's alpha (setOffset fades a small
    panel by its distance). A theme with fewer ghosts in use when a glitch ends (before the panel restyled) is no error
    (`PlaceGhosts`).
  - **No dot before the beam**: the beam draws nothing while it is no line yet (a chained bag waiting out its delay).
  - **Its art repeats**: tears, blocks and static are loaded with the `REPEAT` wrap mode both ways, their coordinates
    running past their art (loaded clamped, the client stretches the art's edge texels over the rest); and every
    texture of the layer is drawn without the client's sharpening as it is made (texture-sharpening.md).
  - **A parent hiding the panel** (Alt+Z hides UIParent) runs its OnHide, which stops everything that moves: when the
    parent shows it again (its own flag still set at the hide, `hiddenByParent`), its sparkles, ornaments, rain,
    shimmer and bursts start again (`startEffects`, shared with `Show`).
  - **Photosensitivity**: a glitch flickers the whole panel (every `Step`, 0.06 s in the theme, for well under a second;
    bursts every 14 s on average, never below 0.3 of its alpha). That is above the 3 flashes a second WCAG 2.3.1 allows
    for a large area. Appearance > Animation > Glitch Effects (§20) turns it off, and with it every ornament's glitch (the
    HUD brackets' blinking twitch; their other motion is Moving Ornaments').
- **Title ghosts** (`Header.Title.Ghosts`): copies of the title in other font roles (cyan and magenta), under it on the
  overlay, `X` and `Y` from it at `Alpha`, hung from the body by the title's own numbers (never from the title, a
  text), given the title's text and the width and wrapping `FitTitle` gave it (`titleCut`, none when it is not cut
  short); a glitch spreads them. Corrupted letters leave a title with escape sequences (`|`) as it is.
  - **Failure mode (fixed before it shipped, found by the adversarial review):** the ghosts were given the title's width
    read back from the title. A vendor's name in an instance is a secret, its width then too, and `SetWidth` takes no
    secret from addon code (`SecretArguments = "AllowedWhenUntainted"`, SimpleScriptRegionResizingAPIDocumentation):
    with the Glitch theme the vendor never opened in a dungeon. The specs' mock took secrets in `SetWidth`, `SetHeight`,
    `SetSize` and `SetPoint`; it now refuses them as the client does, and the vendor's secret-name test runs every
    shipped theme (it named five).
- **The data rain** (`Panel.Rain`, NextRain, `next/rain.lua`): a list of entries, each `Where` (`"Feather"`: down the
  feather beside the body's inner side, a full panel's only, `Layout.Feather` wide; `"Body"`: across the body, behind
  the content), `Font` (the trail's role) and `HeadFont` (the head's), `Glyphs` (a string, read as UTF-8 characters),
  `Spacing` (units between columns; as many as fit, centered), `Speed` (rows a second) and `Trail` (glyphs behind the
  head) as `{ least, most }`, each column's own at random, `Alpha` (the head's; the trail fades from it), `Swap`
  (glyphs changed a second in each column). A cell is its font's height square, on whole pixels of the panel's grid.
  - Each column is a ring of font strings as long as its longest trail: the head writes a new glyph in every row it
    reaches, the glyph at the end of the trail becoming the new head, so the glyphs written stay in their cells and a
    column costs its trail, never the panel's height. A slow frame writes every row it passed. Once its trail has
    fallen past the bottom it starts again above the top (up to half the panel's height above), with a new speed and
    trail; in combat none starts again (the rain thins out and stops, as sparkles do).
  - **Only what changed**: a column's glyphs are drawn again only when it passed a row; a layout places again only
    columns whose cells moved and draws again only those whose rows changed (a resize lays it out on each of its
    frames). Found by the adversarial review: every frame redrew every glyph (about 440 calls a frame on a full backpack
    for the two glyphs that moved). Not measured in game.
  - On the panel's own frame (`BORDER` 2: over the fill, feather, wash and a small panel's edge; under every child
    frame: tabs, content). Laid out by the panel's geometry and the frame's `OnSizeChanged` (a grip, a size switch);
    falls only while the panel shows (its driver is a child of the panel's frame, started on show, stopped as it
    hides); a theme restyles it (`Style`), falling on through a theme with rain. Its glyphs are moving parts: the
    pixel checks leave them out.
- **Smaller pieces**: the `flicker` ease (`NextTween.Ease`: eight steps, each dim, below 0.3, or lit, 0.75 and up, lit
  more often as it goes, lit from 0.75 on; a hash of the step, so the same time gives the same value; the theme's
  sections flicker into place with it); a tween's `onStop` (it ends without reaching its end: stopped, or replaced by
  another of its key); a font role's `Locales` (§3: the fonts cover Latin alphabets only, so the other locales draw the
  client's own); `Sparkles.Upright` (never turned: square pixels); tab edges (§3, `Tabs.Edge`, `SelectedEdge`); the
  ornaments' `BODY` point and `Scroll` and `Glitch` motions (§12).
- **Check** (`SonataNext:Check`): a glitch's parts (`NextGlitch.KEYS`), `Open`, `Close` and `Bursts` tables with their
  `Time`, a `Step` with any of them, `Bursts.Every`, `Flicker` two numbers, `Corrupt.Glyphs` some glyphs; a rain
  entry's parts (`NextRain.KEYS`), `Where`, its `Glyphs`, its `Font` and `HeadFont` roles, a `Spacing` above nothing,
  `Speed` and `Trail` two numbers, none below 0, the least first; an ornament's `Motion.Glitch` and `Motion.Scroll`
  tables, their parts and keys. The adversarial review found data Check took that the runtime cannot run (no `Step`:
  an error every moment; no `Bursts.Every`: an error as the panel finished showing, so a bank never loaded until its
  timeout; a `Spacing` of 0: columns without end).
- **Art and fonts**: `tools/textures/next_glitch.py` (standard-library Python, like `next_glow.py`) makes
  `textures/next/glitch/*.png`: a grid, the wireframe floor, scanlines, a rolling bar, a vignette, static, datamosh
  blocks, colour-split tears, a HUD bracket, a dash. `fonts/glitch`: VT323 and Share Tech Mono with their SIL Open Font
  License files (measured with fontTools: VT323 has all of basic Latin and Latin-1 and 127 of Latin Extended-A's 128;
  Share Tech Mono basic Latin and Latin-1; neither has Cyrillic, Hangul or CJK). What the rain writes and the title is corrupted with is ASCII, which every
  client's fonts have.
- **Coverage**: `spec/next/rain_spec.lua` (columns down the feather on either side and across the body, centered, a
  small panel's feather dry, the head's and the trail's fonts and fading, glyphs kept in their cells, a slow frame,
  trails shorter than the longest, starting again from above and not in combat, swaps, characters, size changes,
  started and stopped, a theme with and without, moving parts), `spec/next/theme_panel_spec.lua` ("glitching
  (Panel.Glitch)": opening, flicker and jumps, tears, static, ghosts and corruption by strength, secrets, characters,
  shoves, closing, cut short, bursts and their rules, its theme gone mid-glitch three ways and coming back; the Glitch
  theme's four brackets inside the body, as far in from each corner: a bottom corner's piece goes in with a Y up, as
  `Y` is down whatever the corner, §12; reported in game, the bottom two sat outside; "data rain
  (Panel.Rain)" on the real panels), `spec/next/ornaments_spec.lua` (BODY, Scroll, Glitch), `spec/next/tween_spec.lua`
  (flicker, onStop), `spec/next/style_theme_spec.lua` (Locales), `spec/next/sparkles_spec.lua` (Upright),
  `spec/next/tabs_spec.lua` (edges), `spec/sonata/next_engine_spec.lua` (Check; the two switches; an ornament's glitch
  off with Glitch Effects), `spec/next/vendor_spec.lua` (a secret name in every shipped theme),
  `spec/sonata/next_themes_spec.lua` ("Glitch": its fonts, licenses and art on disk, its glitch, rain, ghosts and CRT
  pieces, its palette; every theme's dock card title fitting its line), and every shipped-theme spec (`shipped_themes_spec`, `pixel_perfect_spec`, `theme_panel_spec`)
  with it. Mutation-tested: 56 mutations of the rain, tab edges, checks and switches (seven first survived: four led to
  tests, three were dead code, removed), and 49 of the glitch engine, ease, onStop, Locales, Upright and ornaments
  (twelve first survived: nine led to tests, three were dead code, removed); then 46 of the fixes after the adversarial
  review (eight first survived: four led to tests, four were dead code, removed); every one now caught.
- **Not seen in game yet**: any of it. To check: the theme's look at rest and mid-glitch against the mockups (the plan
  drew them), the custom fonts at the UI scales the pixel rules cover, the rain's cost (a profiler capture of an open
  panel: `NextRainSet.Step`), the client's draw order of the BORDER-layer glyphs under the vignette and over the wash,
  and whether a section's shove animation and the glitch layer's own alpha behave as the specs' mock says.

## 22. The Frost theme's engine (`next/shatter.lua`, `next/snow.lua`, `next/threads.lua`)

What the Frost theme (§8) needed of the engine, all of it data a theme gives, none of it Frost's alone.

- **Shattering and freezing together** (`Panel.Shatter`, NextShatter, driven by the panel: `shatterIn`, `shatterOut`,
  `endShatter`, `breakPoint`, `FillRect`).
  - **The shards are real pieces of the body.** `NextShatter:Mesh` cuts the body's rect into a grid of cells about
    `Shards.Size` across (at least one), its inner vertices moved up to `Shards.Jitter` of a cell either way (those on an
    edge only along it, the corners still), each cell cut along either diagonal: triangles that tile the body exactly.
    Each triangle is a texture whose four corners are moved onto its three (`TextureBase:SetVertexOffset`, every
    client's API documentation; offsets in the texture's units from where its rect puts each corner, y up, as Blizzard's
    artifact lines use them; the fourth corner on the third), carrying the body's fill where it lies (`SetTexCoord`'s
    eight numbers, in Blizzard's code on every client), mapped over the fill's own rect (`panel:FillRect`: it reaches past
    the body on a docked panel's screen-edge side), with a second texture over it carrying `Frost` mapped over the body.
    The edges between them are the seams (Lines), ordered by how many seams they are from the focus vertex (where it
    breaks: the inner vertex nearest it is moved onto it, at most 0.45 of a cell from its place, its neighbours jittered
    at most 0.15 so no triangle folds), the cracks.
  - **The layer**: one frame over the whole screen (`NextShatter:Layer`), a child of UIParent in the DIALOG strata (above
    the panels' HIGH), taking no mouse, so the shards show over the panel's content and fly on once the panel has hidden.
    Its textures and lines are pooled and drawn without the client's sharpening (texture-sharpening.md); a pooled one
    is painted again only when the theme's spec changed (a full panel's run takes about 240 textures and 300 seams).
  - **Opening** (`Open`: `Time`, `Stagger`, `Clear`, `Spread`, `Spin`): the panel opens where it rests (no slide), unseen;
    each shard flies in from `Spread` units away from the body's middle, turned up to `Spin` degrees, half its size,
    starting up to `Stagger` later the farther from the middle (the ice forms outward), eased out, catching the light as it
    turns (its frost brighter across a turn); once all have locked (the open's lock, tolerant of float error), over
    `Clear` the seams flash and fade (only with `Open.Flash`: none otherwise), the frost thaws, the shards go and the
    panel shows under them. The threads draw
    themselves in from the lock, and the sections cascade in from it. Then it says it has shown, as the slide does.
    `NextShatter:OpenLock()` and `OpenTime()` say how long it takes to lock and in all, for the panel.
  - **Opening out of a frost storm** (`Open.Storm`: `From`, `Appear`, `Flakes`, `Mist`; Frost's open): the storm grows out
    of the body's `From` corner (`BOTTOMINNER`, `BOTTOMOUTER`, `TOPINNER`, `TOPOUTER`: inner is the side away from the
    panel's screen edge, so it mirrors), its front a quarter circle reaching the corner across at `Open.Time`: a straight
    front across the diagonal reached a tall bag's far bottom corner long before its far top one, and did not read as
    growing from the corner. `Flakes` (`Texture`, `Count` born over the crossing, `Size`, `Life`, `Speed`, `Swirl`
    radians a second their heading turns, `Spin` degrees a second, `Colors`, `Alpha` a range, `BlendMode`) and `Mist`
    (the same, one `Color` and `Alpha`, and `Growth`, how much a puff grows over its life) are born on the front, inside
    the body (a few tries, none where the front has left it), heading out from the corner; one born this frame moves from
    the next. Each shard forms where it lies over `Appear` once the front reaches its middle (from frost to its art,
    turning to rest, growing to its size); the lock is `Time + Appear`. Over `Clear` the storm fades as the panel shows
    (its seams flash only with `Open.Flash`, as the fly-in's).
    Its flakes and mist are pooled textures on the shatter layer, given back as they die and with the run.
  - **Closing** (`Close`: `Frost`, `Crack`, `Time`, `Speed`, `Spin`, `Gravity`, `Lift`): where it stands, frost spreads
    over the body over `Frost` (the shards' frost, their art unseen: the panel still shows under it), then cracks run
    along the seams out from where it breaks over `Crack` (the pointer when it is over the body, else its middle); then
    the panel hides at once (Hide's end) and the shards fly apart on the layer's driver over `Time`: away from where it
    broke at `Speed`, thrown up by `Lift`, falling under `Gravity`, turning up to `Spin` degrees a second, shrinking,
    catching the light, fading, then given back.
  - **Cut short or its theme gone**: whatever stops or replaces the panel's tween (a flight, a placement, Escape: OnHidden)
    gives the shards back and leaves the panel at rest, at full strength (`endShatter`); a theme applied without a
    shatter (another theme, Ice Shatter off) mid-open shows the panel plainly and still says it has shown; mid-close it
    closes plainly. A run keeps the spec it began with, so a theme changing under shards in flight is no error. A
    theme with a glitch (§21) opening or closing glitches instead.
  - **Started** with BetterBags Next's look (`NextShatter:Init` in `core/init.lua`, after NextPixel): its pools and the
    runs flying.
- **Snow on a breeze** (`Panel.Snow`, NextSnow): `Flakes`, a list of entries, each `Where` (`Body`: behind the content;
  `Feather`: down the feather beside the inner side, a full panel's only), `Texture`, `Count` (a steady number), `Size`,
  `Fall`, `Alpha` (`{ least, most }`, each flake its own at random), `Drift` (the breeze, units a second toward the inner
  side: out into the world), `Wobble` (`{ units, swings a second }`), `Spin` (degrees a second at most), `Colors`,
  `BlendMode`, `Layer`, `SubLevel` (BORDER 3 when unset: over the fill and the rain, under every child frame). A flake
  fallen past the bottom starts again above the top; one blown past the downwind side starts again upwind; in combat none
  starts again (they come back after it). `Gusts` (`Every`, `Time`, `Strength`, `OnOpen`, `Streaks`): every `Every` on
  average (0.4 to 1.6 of it) the breeze rises by up to `Strength` and falls over `Time`, and `Streaks` (`Count`, `Length`,
  `Thickness`, `Alpha`, `Color`, `Texture`, `BlendMode`, `Tilt`) sweep across the panel ahead of it, tilted down along the
  wind, their head first (the art's right end, mirrored to lead going left); one blows as the panel shows with `OnOpen`.
  `Flybys` (`Every`, `Max`, `Travel`, `Speed`, `Length`, `Thickness`, `Tilt`, `Texture`, `Color`, `Alpha`, `BlendMode`,
  `Layer`, `SubLevel`, `Head`): shooting stars. One sets off every `Every` (`{ soonest, latest }`) while fewer than `Max`
  fly, none in combat (it is due again `Every` later); from somewhere in the body far enough from its inner edge to fly
  its `Travel` inside it (and from its top and bottom: 8% to 85% down, less its fall), toward the inner side at `Speed`,
  falling along its `Tilt` (degrees). Its tail (`Texture`, the art's right end its head, mirrored going left, tilted down
  along its way) is as long as it has flown, up to `Length`, `Thickness` thick, behind its head; `Head` (`Texture`,
  `Size`, `Color`, `Alpha`, `BlendMode`, `Twinkle`: twinkles a second) at its front. Both fade in over its first 15% and
  out over its last 45%. Given back when it has flown its way, or the panel hides (`Stop`).
  Laid out again on the panel's geometry and frame size changes, keeping flakes still inside where they are; a feather
  flake hides while the panel is small and falls again once it is full (a size switch lays the snow out, it does not
  make it again: found in review, it errored every frame). Falls only while the panel shows; a flake that does not spin is
  never turned again and its one anchor is replaced in place, so a full backpack's 77 flakes cost about 77 calls a frame.
  Not measured in game.
- **Threads of light** (`Panel.Threads`, NextThreads): a list, each a Catmull-Rom curve through `Points` (`{ x, y }`: x a
  share of the body's width from its inner side, past 0 or 1 out beyond it; y by `Anchor`: `TOP` units down from the
  body's top, `BOTTOM` up from its bottom, `BODY` a share of its height), `Segments` Lines on the panel's frame (`Layer`,
  `SubLevel`; under every child frame), `Width` thick in `Texture` (a soft profile across it), `Color`, `Alpha`,
  `BlendMode`, at its `Sizes` only. `Sway` (`Amplitude`, `Period`): each point moves on its own phase, laid out again at
  most 20 times a second. `Glint` (`Every`, `Time`, `Length` a share of its length, `Color`, `Strength`): a light runs
  along it from start to end now and then. `Draw`: seconds it takes to draw itself in as the panel opens (`DrawIn`, after
  the open's delay, eased out, its tip bright; `Start` keeps a draw-in asked for before it); it unravels as the panel
  closes (`Unravel`, over the close's time). Mirrored on a panel whose inner side is on the right. Its lines are curves on
  no pixel grid: moving parts.
- **Check** (`SonataNext:Check`): a shatter's parts (`NextShatter.KEYS`), its `Shards`, `Frost` and `Seams`, a shard
  size above nothing, a jitter from 0 to below half a cell, `Open.Time` and `Close.Time`, `Spread` and `Speed` ranges; a
  snow's parts (`KEYS`, `FLAKE_KEYS`, `GUST_KEYS`, `STREAK_KEYS`), each flake's place and `Count`, its ranges, the gusts'
  `Every` and `Time`; each thread's parts (`KEYS`, `SWAY_KEYS`, `GLINT_KEYS`), anchor, two points or more, `Segments`,
  `Sizes`, a sway's `Period`, a glint's `Every` and `Time`; a storm's parts (`STORM_KEYS`, `FLAKE_KEYS`, `MIST_KEYS`),
  its corner (`CORNERS`), its flakes' and mist's `Count` and ranges. Each is what its runtime would fail on (a size of nothing cuts
  cells without end; jitter of half a cell folds triangles; a gust, glint or sway without its time divides by nothing).
  Named textures and palette colours inside them are checked by the walk every theme gets.
- **Switches** (§20): Ice Shatter and Snowfall; Moving Ornaments holds threads still.
- **Not seen in game yet**: any of it. To check: a bag opening and closing at full size and small, chained, at a
  vendor and the bank (its open finishing within the bank's 1 s wait); the shards' triangles drawn as the API documents
  (`SetVertexOffset` with the fourth corner on the third); the art's look; the cost of a full panel's run as it begins
  (a profiler capture: `NextShatter.Begin`, `NextShatterRun.Assemble`, `NextShatterRun.fly`), and of the snow
  (`NextSnowSet.Step`) and threads (`NextThreadSet.Step`) while a bag is open.
- **Coverage**: `spec/next/shatter_spec.lua` (the mesh tiling its rect with and without a focus, its edges, jitter both
  ways and calm by the focus, both diagonals, uv, the seams' order; the layer; a run's textures, corners, art and frost
  mapping, seams; assembling from away to locked, nearest first, thawing, glints; freezing and cracking in order;
  shattering outward, gravity, turning, fading, giving back, the driver stopping, runs side by side, pools, painting
  again only for a new spec, releasing; "a frost storm": its front from the bottom inner corner, flakes and mist born on
  it inside the body, shards formed as it reaches them, all formed once it has crossed and the panel shown as it blows
  away, curling, turning and growing, flakes given back as they die, mirrored, another corner, given back with the run,
  the lock and total times), `spec/next/snow_spec.lua` (none without, the look, places on either side, a
  small panel, falling and drifting, starting again at the top and upwind, combat, gusts and streaks both ways, OnOpen,
  stopping, a new theme, resizing, a size switch, moving parts; "flybys": Every apart, never more than Max, inside the
  body all the way on either side, flying a short way toward the inner side and falling in its color, its tail growing
  and its head twinkling, fading in and out, mirrored, none in combat or once hidden, moving parts), `spec/next/threads_spec.lua` (lines, the curve through
  its points, mirroring, anchors, sizes, sway, glint, draw-in and its tip, a part-drawn segment, unravelling, a draw-in
  before Start, a new theme, resizing, moving parts), `spec/next/theme_panel_spec.lua` ("shattering, snow and threads":
  on the real backpack: opening, opening out of a storm from its bottom left, closing from the pointer and its middle,
  Escape mid-open, the theme gone mid-open,
  sliding without it, threads drawn in and unravelled, snow and moving parts), `spec/sonata/next_engine_spec.lua`
  (Check; the switches; threads held still by Moving Ornaments), `spec/sonata/next_themes_spec.lua` ("Frost": fonts,
  license, art, its engine pieces, its palette; the alpha rule comparing a range alpha by value), `spec/core/init_spec.lua`
  (started), and every shipped-theme spec with it (`shipped_themes_spec`, `pixel_perfect_spec`, `theme_panel_spec`,
  `vendor_spec`'s secret name). The mocks gained `SetVertexOffset`/`GetVertexOffset` from the API documentation.
  Mutation-tested: 73 mutations of the three modules, the panel's wiring, Check, the switches and the start. Nine first
  survived: six led to sharper tests (jitter both ways, both diagonals, calm by the focus, glints once every shard
  shows, a resize leaving flakes in place, a thread swaying both ways and cut where it has reached), two showed code
  that changed nothing, removed (the crack phase's own time check, a per-frame hide Layout already does), and one did
  not apply. Then 25 of the storm (four first survived and led to tests: flakes born on the front inside the body,
  curling, given back as they die, the threads waiting for the lock on the panel; the first also led to a flake born
  this frame moving only from the next). Then 30 of the shooting stars and their Check rules (two first survived and led
  to tests: a star on a panel on the left of the screen starting inside the body, and fading in and out). Every one now
  caught.

## 23. The Halloween theme's engine (`next/smoke.lua`, `next/bats.lua`, ornaments' `Blink` and `Flicker`)

What the Halloween theme (§8) needed of the engine, all of it data a theme gives.

- **Coming in out of smoke** (`Panel.Smoke`, NextSmoke, driven by the panel: `smokeIn`, as `shatterIn` is,
  `endShatter` ending both; `moveIn` takes it after a glitch and a shatter). The first version was cartoon smoke (each
  puff popping past its size over `Grow`, holding over `Hold`, shrinking away over `Shrink`); asked: "can you make it
  more real-ish?". Those keys are gone.
  - **The smoke.** `NextSmoke:Begin(panel)` lays puffs over the body's rect (`panel:BodyRect`, at the panel's scale) in
    rows and columns about `Open.Spacing` apart (scaled), a column half a spacing outside each side so the smoke billows
    past the edges, each moved up to `Jitter` of a spacing either way; each a texture on the smoke layer (a frame over the
    screen in the DIALOG strata, level 10, above every panel, taking no mouse), in a colour of `Puffs.Colors`, its size
    between `Puffs.Size`, its strength between `Puffs.Alpha` (a range, or one number), at an angle of its own, turning up
    to `Spin` degrees a second either way. Rows lower in the body draw below rows above (sublevels -8 to 7).
  - **The front** rises up the body over `Open.Rise`, quick off the floor and slowing near the top: `1 - (1 - u)^2` of
    the way up `u` of the way through; a row is born as it passes it, so the top row at `Rise`.
  - **A puff**, as smoke does: lives between `Open.Life` (seconds); swells from `Start` of its size toward `Growth` of
    it (an ease out: quickly at first); rises at its `Lift` (units a second, scaled) and faster and faster by `Buoyancy`
    (units a second a second, scaled: warm smoke); drifts out from the body's middle line at `Spread` times how far from
    it it is, the bottom row `Burst` times as fast (the smoke spreading along the floor); curls across that drift
    (`Swirl`: `{ units, swings a second }`, from a phase of its own, growing in over the first two fifths of its life);
    fades in over `FadeIn` of its life and thins away from three tenths of it on. The bottom rows, born first, go first:
    the smoke clears from the bottom up.
  - **The panel** is drawn at no alpha, then shown under the smoke over `Reveal` (`{ from, to }` seconds, smoothstep).
    Once that ends it has shown (`OpenTime` and `OpenLock`: `Reveal`'s end, else `Rise`): it says so, its threads draw in
    and its sections cascade. Its smoke lingers on (`Linger`): the run lives on by itself on the smoke layer's driver
    until its last puff and ember are gone (`ClearTime`: `Rise` plus the longest `Life`), and the driver stops with the
    last run. `Init` gives back whatever lingers (`core/init.lua` starts it with the shatter's). The theme going mid-open
    shows it plainly; Escape ends it at rest, its smoke given back.
  - **Embers** (`Sparks`: `Count`, born at random through the rise somewhere in the smoke below the front, rising at
    `Rise` over `Life`, sized `sin(pi * age / life)` of its size, turning, on the layer's `OVERLAY`).
- **Breaking up into bats** (`Panel.Bats`, NextBats, driven by the panel: `batsOut`, taken in `Hide` after a glitch and
  a shatter). The first version covered the body in a puff of smoke and sent bats out of it; asked: "no puff of smokes:
  how the frost theme shatters, we want the bag break up *and morph* into bats and fly away. almost a surreal effect".
  `Close.Puff`, `Grow` and `Vanish` are gone.
  - **A bat** is a flipbook: `Texture` holds `Frames` pictures side by side (square), shown in turn `FrameRate` a second,
    each bat from its own phase (`SetTexCoord` over its frame); `Color`, `BlendMode` (BLEND when unset).
  - **Closing:** `NextBats:Begin(panel, breakPoint)` cuts the body (where its `BodyRect` puts it) into about
    `Close.Count` pieces (rounded, between its two): a grid of cells as near square as the body allows, its inner corners
    moved up to `Jitter` of a cell (those on an edge only along it), so the pieces tile the body exactly. Each is a
    texture of the bats layer painted with `Close.Pieces` (the body's own art) at the texture coordinates where it lies
    in the panel's fill (`panel:FillRect`), its four corners moved onto its own (`SetVertexOffset`), as the shatter's
    shards are. The panel trembles where it stands over `Shudder` (across, `Tremble` units either way, dying away; the
    tween's own offset), then hides (`Hide`'s end) as `Break` shows the pieces where it was. They drift apart straight
    out from where it breaks (the pointer over the body, else its middle; `Gap` units over `Break` seconds); then each,
    after its delay (`Delay`, nearer the break first, give or take a fifth), turns into its bat over `Morph`: it shrinks
    toward its bat's `Size`, its top spreading into wings that flap and its bottom drawn in, banking as its bat will,
    darkening toward `Dark` and fading as the bat (in from halfway) comes out of it. The bat flies away from the break
    give or take `Spread` degrees at its `Speed`, growing by `Accel` of itself a second (`speed * (t + accel * t^2 / 2)`,
    eased in over the morph), wobbling across its way (`Wobble`: `{ units, swings a second }`), banking by `Tilt`
    degrees toward the side it flies to, growing a little as it goes; it is hidden once off the screen. The run is
    given back when its last bat is, or after `Life`. All on the bats layer (DIALOG, above the panels), whose driver
    stops with the last run. The theme going as it trembles closes it plainly.
  - **Fluttering** (`Flutter`, NextBats' set on each panel: `Create`, `Style`, `Start`, `Stop`, `MovingParts`, the
    panel calling them with its snow's): every `Every` (`{ soonest, latest }`), none in combat, `Count` bats one after
    another `Stagger` apart (a negative starting age) fly out of the header band of the body (`Band`: down from its top;
    from its outer three quarters) toward its inner side, out into the world, at `Speed`, rising or falling at `Rise`,
    wobbling up and down, flapping, faded in over the first tenth of `Travel` and out over its last quarter, given back
    once they have flown it; on the panel's frame (`Layer`, `SubLevel`: BORDER 5 when unset), under its content. One
    flutters out as the panel shows with `OnOpen`. A theme without a flutter applied while they fly lets them go
    (`Style`).
- **Ornament motions** `Blink` and `Flicker` (§12).
- **Check** names each part a smoke or bats does not have, and what their runtimes need: an opening's `Rise`,
  `Spacing`, `Start`, `Growth` and `Burst` more than nothing, its `Jitter` no less, `FadeIn` from 0 to 1, `Buoyancy` a
  number, `Swirl` two numbers no less than nothing (how far and how often, in no order); a close's `Pieces`, its
  `Shudder`, `Tremble`, `Break`, `Gap`, `Morph`, `Accel` and `Life` no less than nothing, its `Jitter` from 0 to below
  half a cell (corners moved further could cross), its `Dark` a palette color; `FrameRate` and `Stagger` no less,
  `Frames` and `Travel` more; `Puffs` for a smoke that opens, and their `Size`; a spark's `Count`; every range as two
  numbers in order (`Size`, `Alpha`, `Lift`, `Spread`, `Reveal`, `Life`, `Count`, `Speed`, `Delay`, `Band`; `Every`
  required for a flutter); a blink's `Every` and parts, a flicker's `Low` (0 to 1), `Speed` and parts.
- **The switches** Smoke Puff and Bats (§20); Snowfall became Snow and Leaves.
- **Not measured in game:** the smoke's cost. A full panel's open draws about 230 puffs (458 x 1000 at a spacing of 52)
  for up to 1.6 s, each placed, sized, turned and faded every frame; the close 11 to 15 pieces and their bats.
- **Coverage:** `spec/next/smoke_spec.lua` (opening only with an open, its lock, time and clear time; the layer; rows
  and columns over the body and past its sides; born as the front rises; swelling from `Start` to `Growth`, fading in
  and thinning away; clearing from the bottom up; the reveal; rising faster and faster and drifting out, the bottom row
  along the floor; swirling no more than its `Swirl`, from a phase of its own, growing in over two fifths of its life;
  turning, colours and alphas; embers; the panel's scale, buoyancy included; pools; lingering on after the panel has
  shown until its last puff has lived its life, then stopping; given back when it starts again and by `Init`),
  `spec/next/bats_spec.lua` (closing only with a close; pieces tiling the body, as near square as it allows, jittered,
  each painted with the fill where it lies at every corner; trembling less and less, at the panel's scale; shown where
  the body was, drifting apart over `Break`, half way half way; turning in their own time, nearer the break first;
  shrinking, the top spread into wings and the bottom drawn in exactly as much as it shrank, flapping, darkening and
  fading into the bat; bats flapping through the frames, straight out give or take `Spread`, eased into their speed,
  faster and faster, wobbling no more than their wobble, growing as they fly, banking, at the panel's scale; given back
  off the screen and as the last leaves, hidden as each leaves, within their Life, by `Init`; fluttering: none without,
  now and then one after another, out of the header inside the body, toward the inner side, flapping, fading, gone after
  its travel, mirrored, combat, stopping, OnOpen, moving parts), `spec/next/ornaments_spec.lua` (a blink, once and
  twice, never a third; open again on a hide; a flicker between `Low` and its own, never still, back at its own),
  `spec/next/theme_panel_spec.lua` ("smoke and bats": on the real backpack: opening out of the smoke over its body,
  shown under it, its threads waiting, the smoke lingering after; Escape and the theme going mid-open; closing by
  trembling then breaking into pieces of its body, no smoke; its threads unravelled as it trembles; breaking from the
  pointer or the middle; the theme going as it trembles; sliding without them; fluttering while it shows and stopping,
  a theme without bats letting them go), `spec/sonata/next_engine_spec.lua` (Check; the switches),
  `spec/sonata/next_themes_spec.lua` ("Halloween": the font and its license, its locales, the art, the palette, ink on
  orange and light on black; the body one orange from side to side, read from its pixels, averaging the feather's color,
  deeper than the first; the smoke's timing, cover, translucency, swelling, buoyancy, curling and lives; the bats' count,
  the pieces of its own body, the tremble, break and morph, the frames; the cat and jack-o'-lantern at each size, the
  drips' clearance, leaves and vine), `spec/core/init_spec.lua` (started), the settings specs (the switches and their
  rows), and every shipped-theme spec with it (`shipped_themes_spec`, `pixel_perfect_spec`). Mutation-tested: 110
  mutations of the two modules, the motions, the panel's wiring, Check and the switches. Eleven first survived: nine led
  to sharper tests, two showed code that did nothing, removed. Then the feedback round (smoke made real-ish, the close
  made a break into bats, the body): 62 mutations of the smoke, the bats, the panel's wiring and Check; 16 first
  survived and led to the tests above (the swirl's phase and growing in, a linger lasting its puffs' lives, buoyancy at
  the panel's scale, threads unravelling over the tremble, the tremble dying away and its scale, the drift over `Break`,
  the wings' spread, the piece fading into its bat, the corners' jitter and texture coordinates, `Spread`, the grid's
  shape, the speed's ease in, the bat's growing). Every one now caught.

## 24. The Make It So theme's engine (`next/beam.lua`, ornaments' `Flash`)

What the Make It So theme (§8) needed of the engine, all of it data a theme gives.

- **Beaming in and out** (`Panel.Beam`, NextBeam, driven by the panel: `beamIn` from `moveIn` after a glitch, a shatter
  and smoke; `beamOut` from `Hide` after a glitch, a shatter and bats; `endShatter` ending both, as it ends theirs).
  - **A run** (`NextBeam:Begin(panel, phase)`, `"Open"` a beam down, `"Close"` a beam up) lays its parts on the beam
    layer (a frame over the screen in the DIALOG strata, level 15, above every panel, taking no mouse) over the body's
    rect (`panel:BodyRect`, at the panel's scale), unseen until it draws:
    - **Sparkles** (required): `Density` of them to every 100 x 100 units of the body (counted in the body's own units,
      so a scaled panel shows as many, smaller), across it and `Spread` past its sides, down it; each a texture
      (`OVERLAY`) in a colour of `Colors`, its size between `Size`, its strength between `Alpha` (a range, or one
      number), drifting up or down (half each way) at between `Drift` round the body (wrapping from top to bottom), and
      twinkling `Twinkle` times a second from a phase of its own: `((1 + sin(2 pi f t + phase)) / 2) ^ Sharpness` of its
      strength, `Sharpness` making the flashes brief; swelling from half its size to its size as it flashes, drawn out
      `Stretch` times as tall as wide. All scaled by the panel's scale.
    - **Column** (optional): a texture (`ARTWORK` 0) over the body and `Spread` past its sides, in `Color`, at `Alpha`,
      shimmering (`Shimmer`: `{ how deep, 0 to 1; how fast, swings a second }`: `1 - depth + depth * (0.5 + 0.5 sin)`
      of its strength) and its art flowing up `Scroll` of its height a second (its texture coordinates; the art loaded
      with the REPEAT wrap mode down its length, not tiled by the client).
    - **Glow** (optional): a texture (`ARTWORK` 1) over the body, in `Color`, at `Alpha`: the bag lit as it
      materializes.
  - **Envelopes:** each part grows in and out over an envelope of its phase, `{ in, full, out, gone }` seconds:
    `smoothstep(in, full, t) * (1 - smoothstep(out, gone, t))`; a part its phase gives no envelope stays dark.
  - **The panel's part:** a beam down (`Open`) shows the panel under it over `Reveal` (`{ from, to }`, smoothstep): it
    has materialized at `Reveal`'s end (`OpenTime`, `OpenLock`), says it has shown, and its threads draw in and its
    sections cascade from then. A beam up (`Close`) fades it over `Fade` (`CloseTime`, its end): then it hides (`Hide`'s
    end), and its threads unravel over that time. Either way the run lingers on its own (`Linger`, on the beam layer's
    driver) until its last part has gone out (`ClearTime(phase)`: the latest envelope's end; none without one), then
    gives its textures back; the driver stops with the last. `Init` gives back whatever lingers (`core/init.lua` starts
    it with the smoke's and the bats'). The theme going mid-beam shows the panel plainly (and a beam up closes it
    plainly at its end), its run given back; Escape mid-beam ends it at rest.
  - **What it covers** (`NextBeam:Reach`): the body and `Margin` past it evenly all round, at the panel's scale. Asked:
    "make sure it covers the window + it's decoration fully, it's a bit too small on all sides", then, of a version that
    also reached past the tabs on the inner side, "it's too far to the left (leave tabs out) and not enough on the
    right": the tabs are left out, the margin is even.
  - **Its ends** (`Ends`; asked: "the top and bottom beam are cut off extremely clean on the horizontal plane, almost
    like it's clipped at the top and bottom"): it runs `Ends` past the top and bottom of what it covers. The column and
    the glow reach that far; the column fades out to nothing over each end through two masks (`beam.END_MASKS`,
    `textures/next/beam_end_top.png` and `beam_end_bottom.png`: nothing at the end each is for, all at the other,
    smoothstep between; each over its end of the column, `Ends` tall, the column's own art left to scroll; two images,
    since a mask cannot be turned over by its coordinates, below), given back to their pool off the column when the run
    is (a texture used again for a fleck is never cut). The flecks are scattered over the ends too,
    as dense, drift round the whole length, and fade over the ends as the column does
    (`smoothstep(bottom, bottom + ends, y) * (1 - smoothstep(top - ends, top, y))`). The glow's art softens over its
    outer fifth. Without `Ends` nothing changes.
- **A body's rounded corners** (`Panel.Corners`; reported with a screenshot: "corner at the top left and bottom left
  peak out around the LCARS, i think we need a way to shape the window itself"): by side (`TOPINNER`, `TOPOUTER`,
  `BOTTOMINNER`, `BOTTOMOUTER`, as ornaments name corners, §12), each a radius. On a small panel (`shapeCorners`, from
  `ApplyGeometry`, which every styling of the body is followed by), a mask at each rounded corner of the body, the
  radius twice across, that corner's own image (`textures/next/corner_topleft.png`, `corner_topright.png`,
  `corner_bottomleft.png`, `corner_bottomright.png`: cut round at that corner, opaque elsewhere; the inner and outer
  corners swap sides on a panel whose inner side is on the right), cuts what is drawn across the body: its fill, its
  wash, its edges, the side rail's strip and the glow a drop lights. It is wrapped white outside its rect
  (`CLAMPTOWHITE`); its halves away from its corner are opaque, so a wrap that clamps to its edge would cut nothing more
  either. A full panel's corners stay square (it stands against the screen's top and bottom beside its feathered edge).
  Ornaments are not cut: a theme draws them to fit (the elbows' outer corners are rounded as much).
  - **Two rules of the client's masks**, both found the hard way (reported in game: "lower left corner not masked. top
    left is perfect though"), and both now in the spec mock (`spec/helpers/wow_mocks.lua`):
    - **A mask's texture coordinates are ignored.** The first version drew one image and flipped it for each corner
      with `SetTexCoord`: only the top left, which needs no flip, was cut. lightspark tested it when masks came in (7.2,
      WoWInterface, "MaskTexture : new widget for 7.2": "SetTexCoord had no effect on mask texture"), and Blizzard's UI
      never sets coordinates on one. Every orientation is an image of its own; the masked texture's own coordinates are
      not affected (TheDanW, Blizzard, #wowuidev 2017-01-18: masks "won't wreak havoc on texcoords you set"), so the
      beam's column still scrolls.
    - **A texture takes at most 3 masks**; a fourth is an error ("Texture:AddMaskTexture(): Texture already has the
      maximum number of mask textures (3)", quoted in EllesmereUI's pull request 2594; "a texture can be masked by up
      to 3 mask textures", TheDanW, the same day). The body's fill spans every corner, so at most `MAX_CORNERS` (3) are
      rounded, in the order `TOPINNER`, `BOTTOMINNER`, `TOPOUTER`, `BOTTOMOUTER`, the rest left square; Check names a
      theme that rounds four. The masks a theme no longer rounds come off every part before any new one goes on, and a
      mask already on its parts is not added again (`applied`), so no part is ever asked for a fourth. The restyle had
      rounded all four corners of Make It So; its fill refused the fourth.
  **Not verified in game:** `CLAMPTOWHITE` on a mask texture (the client's UI schema lists it, `UI.xsd` `WRAPMODE`;
  Blizzard's own masks use `CLAMPTOBLACKADDITIVE`, never it), which the art makes not matter; and whether the client
  counts the same mask added twice to a texture toward its three (`applied` makes sure it is never asked).
- **A section's row art shorter than its row** (`Sections.Header.Height`, from the row's top; reported: the section's
  title "is overlaping with the first icon row"): the art no longer fills the header to the first row of icons.
- **Ornament motion** `Flash` (§12), the comm badge's chirp.
- **Check** names each part a beam does not have (and each of its phase's parts: `Reveal` only in an `Open`, `Fade`
  only in a `Close`, each required there, two numbers in order), what its runtime needs (`Sparkles`, and their
  `Density`, more than nothing; `Stretch` and `Sharpness` more than nothing; `Spread` no less; `Size` required, and
  `Twinkle`, `Drift` and `Alpha` (when a range) as two numbers in order; a column's `Spread` no less, `Shimmer` its
  depth from 0 to 1 and its speed no less than nothing, `Scroll` a number), every envelope four numbers in order, none
  below 0; `Margin` and `Ends` no less than nothing; its colours through the usual walk. A corner that is no side
  (`TOPLEFT` is not one) or a radius below nothing; a section's art `Height` not more than nothing. And a flash's `Every` (required, in order), `Time` more than nothing,
  `First` no less, and its parts.
- **The switch** Transporter (§20); Snow and Leaves became Snow, Leaves and Stars (the warp stars fall through the snow
  engine).
- **Not measured in game:** the beam's cost. A full panel's beam lays about 130 flecks (510 x 1000 units at a density of
  2.6), each placed, sized and faded every frame for about 1.15 s, and two large textures over the body.
- **Coverage:** `spec/next/beam_spec.lua` (opening only with an Open and closing only with a Close, the times; the
  layer; flecks by their density across the body and past its sides, unseen until drawn, their colours, rippling both
  ways; each twinkling, swelling, drawn out, drifting round the body, in and out over its envelope, nothing before or
  after it; the column over the body and past its sides, loaded repeating, shimmering and flowing; the glow over the
  body, dark before its envelope; the panel shown over its Reveal, faded over its Fade by the Close's own envelopes;
  only sparkles without a column or glow; the panel's scale; lingering where the panel left it until the last part has
  gone out, the driver stopped; pools, and `Init` letting go of what lingers; a margin evenly all round with its tabs
  left out, on either side and at a scale; "its ends": the column and glow past them, the two masks, given back with
  the column, flecks over the ends as dense and faded there, at a scale), `spec/next/content_spec.lua` (a section's row
  art its own height), `spec/next/theme_panel_spec.lua` ("a body with rounded corners": masks on a small backpack and
  the mirrored bank, none on a full panel, taken off when a theme leaves a corner square; each corner its own image, the
  lower left the lower left's; at most three, in order; one theme's corners off before the next one's go on), `spec/next/ornaments_spec.lua` (a flash:
  unseen at rest, its first after `First`, up to its alpha and out over `Time`, the next after `Every`, out once still
  and `First` again; without `First`, a whole `Every`), `spec/next/theme_panel_spec.lua` ("a transporter's beam": on the
  real backpack, beaming down in place, materializing under the shimmer and saying it has shown, the shimmer going out
  on its own after; its threads and sections waiting; Escape and the theme going mid-beam; beaming up where it stands,
  gone at its Fade's end, the shimmer lingering; its threads unravelling over it; the theme going as it beams up;
  sliding without a beam. "the Make It So theme's LCARS frame", on a screen where a unit is a pixel: the badge over the
  close button, centered on it, 4 past it on every side, inside the body, on the backpack and the mirrored bank; the buttons down the side bar under the elbow,
  each block the bar's width, 4 apart; the title and search box clear of the side bar, the top bar and the badge; the
  footer's text above the bottom bar; no piece along the top or bottom running into another, full and as narrow as a
  small bag goes), `spec/sonata/next_engine_spec.lua` (Check of a beam and of a flash; the switch; Moving Ornaments taking
  a flashing piece out), `spec/sonata/next_themes_spec.lua` ("Make It So": the font, its license and locales, the art,
  the beam's timing and colour, the side bar's blocks, the comm badge centered on the pin and its chirp after the beam,
  the holodeck and the warp stars; the restyle: soft colours, section names in peach on glass above the icons, glass
  tabs and a solid chosen one, the body and side bar translucent, its inner corners rounded and a clean Check, the beam's margin
  and ends), `spec/core/init_spec.lua` (started), the settings specs (the
  switch, its row, its title; Snow, Leaves and Stars), `spec/core/constants_spec.lua` (every switch on by default), and
  every shipped-theme spec with it (`shipped_themes_spec`, `pixel_perfect_spec`). Mutation-tested: 65 mutations of the
  beam, the flash, the panel's wiring, Check, the switch, its default and its start. Six first survived: four led to
  sharper tests (a fleck's Spread at the panel's scale, each fleck's own twinkle phase, drifting round the body, the
  switch on by default), one to a test of an envelope of five numbers, and one showed code that changed nothing (a
  run's clear time starting from the panel's part), simplified. Every one now caught. The feedback round (the beam's
  reach and ends and their masks, the rounded corners, a section's art height, their Check): 30 mutations, 29 caught at
  once; the survivor showed code that changed nothing (shaping the corners from `styleBody`, which `ApplyGeometry`
  always follows), removed. The masks' two client rules (an image per corner and per beam end, at most three masks):
  9 mutations, 8 caught; the survivor (adding a mask already on a part again) cannot be told apart in the mock, which
  ignores a repeated add, as the client may; it is kept so the client is never asked.

## 9. Coverage

- Engine: `spec/sonata/next_engine_spec.lua` (registration and data-only refusal by path, objects,
  clients, `Requires`; availability and listing; resolution, parents, lists, `false`, clients,
  untouched tables; starting with the saved theme or Default; applying, saving, previews, refusals,
  widget failures isolated, unregistering, late themes; restoring; item buttons with `SetActive`;
  `Check`), `spec/sonata/engine_spec.lua` (the override), every Sonata spec unchanged (the resolver).
- Default and text: `spec/next/style_theme_spec.lua` (the v0.7.0 golden test, split-off roles, layout
  and OVERREACH from a theme, colors, new font objects per theme, edit boxes, role switches, unique
  names, roles a theme lacks, template colors).
- Widgets: `spec/next/theme_panel_spec.lua` (on the real backpack and bank: every part above, its
  toggles, sizes, the content drawn again at the theme's icon size shown and hidden, animations,
  tabs and sections restyled with the panel, and every shipped theme applied in turn to open, drawn
  bags at both sizes with no error), `spec/next/content_spec.lua`, `spec/next/tabs_spec.lua`,
  `spec/next/drag_spec.lua`, `spec/next/vendorbutton_spec.lua`, `spec/next/vendor_spec.lua`,
  `spec/next/guildbank_spec.lua` ("a theme" blocks).
- Themes: `spec/sonata/next_themes_spec.lua` (each resolves on every client and checks clean; each
  looks as described).
- Settings and wiring: `spec/next/settings/themes_spec.lua` (the cards),
  `spec/next/settings/content_spec.lua` (Appearance per design), `spec/bagsystem_spec.lua` (`SetActive`),
  `spec/database_spec.lua`, `spec/core/constants_spec.lua`, `spec/render/toc_spec.lua`.
- Alphas (§10): `spec/next/theme_panel_spec.lua` ("alphas": the title's glow through a theme, lit and
  dark; the border's alpha after any number of size switches and part way through one; the spark
  while its shimmer waits; a hidden drop glow; the cloud settling when the spark goes),
  `spec/next/chain_spec.lua` (the glow dark until hovered), `spec/next/tabs_spec.lua` (a drop target
  restyled), `spec/sonata/apply_spec.lua` and `spec/sonata/decoration_spec.lua` (tint alpha times
  Alpha, a tinted texture faded).
- Sizes and Masque: `spec/frames/item_spec.lua` ("draws in full again after its size changed"),
  `spec/integrations/masque_spec.lua` ("skins them again when a Next theme applies").
- Every guard was mutation-tested (about 95 mutations): each that survived led to a test or to
  removing what it showed unneeded (the edit box's template color, the border's kept strength).
- The Guild Wars 2 work (the side rail, ornaments' `TexCoords` and `Panels`, font copies, item button art, `Check`):
  57 mutations, each caught; four first survived (the title's glow, the cloud's span and both sides' sparkle
  origins) and led to tests, one of which found the stale ribbon start (§13). An ornament guard no shipped panel can
  reach (a bag kind constants lack) was removed. `spec/sonata/next_themes_spec.lua` ("Guild Wars 2": every GW2_UI
  file it names exists, the original's frame, the actions and the close, its fonts and colors, tabs, search and
  sections, every control, item buttons and the settings window).
- Round two (the strip outside, pinned buttons, hover art, art in tabs, search, sections, lines, check boxes, disabled
  buttons, cards, `Check`): 56 mutations, each caught; two first survived (a pinned button counted in the row's
  width, a theme switch on a disabled button) and led to tests, and two showed code that did nothing (a header
  icon's art forgotten when restyled, the check style hiding its knob twice), removed.
- Round three (the wash under a theme without one, the settings close's hover art, icon highlights, the farthest
  pin's room, the fill's top, the strip's start, `Check` of `HoverIcon`): 18 mutations, each caught.
- Round four: the tab name's width (removing it fails the test; the reset before it, width 0 and the text again, is
  Blizzard's documented sequence and cannot be told apart in the mock), the character window's numbers and the size
  glyphs (`spec/sonata/next_themes_spec.lua`).
- **Every theme draws every window** (`spec/next/shipped_themes_spec.lua`): the settings window (built once, under
  Plain), a page with a row of every kind, every control under the pointer, pressed, disabled and enabled, the
  dropdown's menu, a dialog, the other tab and page, with every shipped theme as every client resolves it; and
  `spec/next/pixel_perfect_spec.lua` ("in every shipped theme, on every client") the bags. Both fail on anything sent to
  the error handler: SonataNext restyles each widget in a protected call and the mock handler drops errors, which hid
  seven places that read a part Plain turns off.
- **Round three** (Default's scale and layout, the bag button): `spec/sonata/next_themes_spec.lua` ("Plain": Default's sizes
  but what the frame fixes, fonts at Default's sizes, the settings window Default's, the inset and the edit box frames, the
  bag button and the vendor's portrait), `spec/next/style_theme_spec.lua` (`Copy` at the role's size, `Size = false`),
  `spec/next/controls/itemgrid_spec.lua` and `input_spec.lua` ("its box"), `spec/next/controls/panel_controls_spec.lua`
  (the tabs' line, open and reaching past them; tabs that do not fit), `spec/next/settings/window_spec.lua` ("a sidebar
  framed as an inset"), `spec/next/settings/page_spec.lua` (titles as written in cards), and §19.
- **Plain's art exists on each client** (`spec/sonata/plain_art_spec.lua`): every atlas, Blizzard file, nine-slice
  layout, font and named color Plain resolves to on a client is used by code that client loads, read from its branch of
  Blizzard's UI source by the files its TOCs load (`spec/helpers/ui_source.lua`; `install-deps.sh` clones every branch).
- **The client's atlas sizes** (`spec/fixtures/atlas_sizes.lua`, written by `tools/atlas_sizes/generate.py` from the
  client's `UiTextureAtlasElement` and `UiTextureAtlasMember` tables through wago.tools; `UseRealAtlasSizes(family)` in
  the mocks): specs that draw a theme's art at its atlas's size use them, and `spec/sonata/plain_art_spec.lua` fails when
  Plain names an atlas the fixture lacks. Without them, art "at its atlas's size" collapsed in the specs and round one's
  settings list headers (199 x 144) shipped stretched. Files the client's loaded code never names but its game data has
  (`Bagslots2x`) are listed in the art spec with the evidence.
- Round two (52 mutations of its guards: frame art above and its bands, the overlay, ornaments above, the search box's
  inset, insides and help color, every settings window key, the list page and rows, the slider's steppers and value, the
  dropdown's art, arrow, steppers and menu style, the art spec's game-data list): each caught.
- The Plain work: 22 mutations of its new guards (list spacing and raise, atlas-sized fills and pieces, the dropdown's
  narrow fill, justify, arrow states and disabled font, the menu's ring and insets, the title band's mirroring, the
  dialog's border, the page tabs' marker and padding, the page's dividers, the magnifier, the thumb), each caught; the
  error capture and the art spec were mutation-tested too (a layout the client lacks, a retail atlas on Classic, a
  misspelled atlas).
