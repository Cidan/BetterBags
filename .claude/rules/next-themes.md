---
paths:
  - "sonata/next.lua"
  - "sonata/resolve.lua"
  - "sonata/themes/next/default.lua"
  - "next/style.lua"
  - "spec/next/style*_spec.lua"
  - "spec/next/theme_panel_spec.lua"
  - "spec/sonata/next_engine_spec.lua"
  - "spec/fixtures/next_style_v0_7_0.lua"
  - "tools/textures/next_icons.py"
---
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

Sections with their own rule files keep their numbers there: next-themes-shipped.md §8,
next-themes-ornaments.md §12 and §13, next-themes-art.md §14, §15 and §16, next-themes-plain.md §17 and §18,
next-themes-menubutton.md §19, next-themes-animation.md §20, and the theme engines: next-themes-glitch.md §21,
next-themes-frost.md §22, next-themes-halloween.md §23, next-themes-makeitso.md §24, next-themes-papercraft.md §25 and
next-themes-glass.md §26.

## 1. The pieces

| Piece | File | Role |
|---|---|---|
| `SonataResolve` | `sonata/resolve.lua` | Theme resolution shared by both engines: inheritance (`Parent`, else the registry's base), per-client overrides (`Clients`), variables (`"$Name"`), the merge rules (tables merge, lists replace, `false` removes). Moved out of `sonata/engine.lua`; the classic engine delegates (`Resolve`, `chainOf`, `GetClientKeys`) and every Sonata spec passes unchanged. |
| `SonataNext` | `sonata/next.lua` | Next's engine: registry, data-only validation, availability (`Requires`), the saved choice (`nextTheme`), applying, previews, widgets, item buttons, `Check`. |
| Next themes | `sonata/themes/next/*.lua` | `Default` (complete: every other theme inherits what it does not set from it), `Ember`, `Frost`, `Glitch`, `GW2`, `Halloween`, `MakeItSo`, `Papercraft`, `Parchment`, `Plain`, `Quiet`. |
| `NextStyle` | `next/style.lua` | A view of the current theme (`Use`): the old constant fields (`ICON`, `PAD`, `Color`, `Time`, `Small`, `Chain`, `Cloud`, ...) keep their names and are read from the theme, so Next's code reads them as before; `style.Theme` is the resolved theme for widget specs. Fonts, `Paint`, `RGBA`, `Ease`, `TexturePath`. |
| Widgets | `next/*.lua` | Each draws from the theme and has an `ApplyStyle(ctx)` that restyles it live. |
| `NextGlitch` | `next/glitch.lua` | A panel's glitches (`Panel.Glitch`, next-themes-glitch.md §21): the CRT's beam, a glitch's moments (tears, datamosh blocks, static, the title's colours split and its letters corrupted, sections shoved), drawn on the panel's glitch layer; the panel drives them. |
| `NextRain` | `next/rain.lua` | A panel's data rain (`Panel.Rain`, next-themes-glitch.md §21): columns of glyphs falling down the feather or behind the content. |
| `NextStopMotion` | `next/stopmotion.lua` | A theme's say that its animations run as stop motion (`Motion.StopMotion`, next-themes-papercraft.md §25): how many poses a second, how far off each lands. |
| `NextPaper` | `next/paper.lua` | A panel as a sheet of paper (`Panel.Paper`, next-themes-papercraft.md §25): unfolding as it opens, crumpling into a ball that falls off the screen as it closes, on the paper layer; the panel drives it. |

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
  theme applied is the effective one) and again when one changes, keeping the font objects (next-themes-animation.md §20).
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
  its `Width` or `Top` (next-themes-ornaments.md §13); an ornament's `TexCoords` with a `Tile` or not four numbers, and `Panels` not a
  list or naming no panel (next-themes-ornaments.md §12). For theme authors; every shipped theme is checked on every client.

## 3. The schema (Default, `sonata/themes/next/default.lua`)

Colors are palette names or `{ r, g, b, a }`. A part set to `false` is turned off: resolution removes a table a
theme sets to `false` (`SonataResolve.Merge`), so code reads every part as possibly absent (`local E = I.Edge; ...
E and E.Idle`); `spec/next/shipped_themes_spec.lua` draws every Next window with every theme on every client and
fails on anything sent to the error handler, which is where a restyle's error goes (§9). A **texture spec**
is `{ Color, Texture (a Textures name or a file), Atlas, TexCoords, HorizTile, VertTile, BlendMode,
Desaturated }`, drawn by `NextStyle:Paint` (a solid color without art; art tinted by `Color`; tiling
loads with the `REPEAT` wrap mode; everything it does not set is reset). Where a control paints a **fill**, the fill
may also be inset, drawn at its atlas's size or pieced (next-themes-art.md §16); a **frame** is Blizzard's nine-slice art (next-themes-art.md §15).

| Key | What |
|---|---|
| `Palette` | Every named color, or one of the client's named colors (`{ Global = "PANEL_BACKGROUND_COLOR", Alpha? }`: Color.lua makes each `C_UIColor` color a global on every client; read when the theme applies; `Check` names a missing one). The controls and the settings window (next-settings.md) add `ControlFill`, `ControlHover`, `ControlPressed` (a field idle, under the pointer, pressed), `Track` (a switch off, a slider's empty track), `Danger` (what deletes) and `Sidebar`; a theme whose body is not indigo sets the first four in its own colors. |
| `Textures` | Named files (`Glow`, `Sparkle`; Parchment adds `Paper`), and the glyphs (`Icon...`; `minimize.png` and `maximize.png` are shipped for themes that want window marks, Guild Wars 2's size button; the controls' `IconChevron`, `IconCheck`, `IconSearch`, `IconPlus`, and `Circle`, the round switch's disc, made by `tools/textures/next_icons.py`). |
| `FontShadow` | The shadow `Shadow = true` means. |
| `Fonts` | Text roles: `Size`, `Color`, `Shadow` (true, a table, or none), `Flags`, `File` (unset: the client's own font, for the locale), `Justify`, `Locales` (the client locales `File` is drawn in; elsewhere the client's own font: a font covers some alphabets, next-themes-glitch.md §21); or `Object`, one of the client's font objects by name, copied (its file, size and flags in every locale, its color and shadow) and changed only by what the role also sets (`Stack` copies `NumberFontNormal`, the bags' item count font); or `Copy`, a client font copied outright (its file, flags, color and shadow) at the role's `Size` (its own, or the one it inherits from Default; `false`: the client font's own), nothing else the role inherits changing it but its height on whole pixels and its own `Justify` (the Plain theme, at Default's sizes). Default's roles: Title, Section, SectionRecent, SectionFree, Count, Tab, TabSelected, Footer, Empty, DragHint, ConfirmTitle, ConfirmWarning, ConfirmHint, Search, SearchText, Price, PriceUnaffordable, VendorName, Stack; the controls' ControlText, ControlMuted, ControlHelp, Button, ButtonPrimary, ButtonDanger, Link, LinkHover, MenuItem, MenuItemSelected, DialogTitle, DialogText, TopTab, TopTabHover, TopTabSelected; the settings window's SettingsBrand, SettingsNavGroup, SettingsNav, SettingsNavHover, SettingsNavSelected, SettingsVersion, SettingsTitle, SettingsDescription, SettingsSection, SettingsSectionNote, SettingsLabel, SettingsText, SettingsLink. |
| `Layout` | Sizes: Icon (an item button's size; the player's Icon Scale, the Size tab, multiplies it: `style.ICON`; the grid's width keeps the theme's own, and a vendor's card is never shorter than it, `style.CARD_HEIGHT`, docs/next-appearance-size.md), VendorColumns, VendorTextGap, VendorPriceRaise (the vendor's cards, next-vendor.md §10b), Gap, PerRow, Gutter, Pad, Feather, TitleTop, TitleInset, SearchTop, SearchHeight, SearchIcon, SearchGap, SearchRight, ContentTop, EmptyTop, Footer, FooterText, FooterMoney, SectionHeader, SectionSpacing, TabHeight, TabSpacing, TabMinWidth, TabMaxWidth, TabPadding, TabHover, TabIcon, TabIconGap, TabGroupGap, HeaderButton, HeaderButtonGap, HeaderButtonTop. |
| `Motion` | `StopMotion` (every animation as stop motion, next-themes-papercraft.md §25; unset in Default), `Time` (every animation's seconds), `Ease` (Open, Close, SmallOpen, SmallClose, Enter, Fly, Glide, Hover, Wash, Cascade, Lift, Land, FlyAway, Pulse, Couple, Uncouple, Morph, MorphFade, Resize; any of `NextTween.Ease`, `flicker` included, next-themes-glitch.md §21), `Rise` (the cascade). `NextStyle.OVERREACH` follows the Open ease's overshoot (outBack a tenth, outBackSoft a fiftieth, others none). |
| `Panel` | `Fill` (texture spec; `Inset`: `Left`, `Right`, `Top`, `Bottom` into the body, drawn for the backpack and mirrored on the bank, the screen-edge side still reaching past the edge while docked; `Panel:FillInsets()`), `Frame` (Blizzard's frame round the body, next-themes-art.md §15, mirrored on the bank; `Above` over the content, `Bands` across its top), `Feather` (`Color`, or false), `Wash` (`Height`, `BlendMode`, or false), `Washes` (Default, Warbank, Guild: palette names), `Edge` (`Color`, `Alpha`, `Size`, `Full`: on full panels too, kept through a size switch; or false), `DropGlow` (or false), `Ornaments` (next-themes-ornaments.md §12; Default has none), `Glitch` (glitching in, out and now and then, next-themes-glitch.md §21; Default has none), `Rain` (data rain, next-themes-glitch.md §21; Default has none), `Shatter`, `Snow`, `Threads` (next-themes-frost.md §22), `Smoke`, `Bats` (next-themes-halloween.md §23; Default has none), `Beam` (next-themes-makeitso.md §24), `Corners` (a small body's rounded corners, by side, next-themes-makeitso.md §24; Default has none), `Paper` (a sheet unfolding and crumpling, next-themes-papercraft.md §25; Default has none). |
| `Header` | `Title.Font`, `Title.Ghosts` (copies of the title under it, each `{ Font, X, Y, Alpha }`: a colour split, next-themes-glitch.md §21), `Title.Justify` (`"CENTER"`: centered in the room the header buttons leave, as Blizzard centers a window's title; its button and glow over the text where it is drawn); `TitleGlow` (`Texture`, `Color`, `Alpha`, `X`, `Y`, `BlendMode`, or false); `ItemDrop` (where an item dropped to put it in a category goes, next-category-picker.md: `Target`, `"Title"` or `"Menu"` (the bag button: a theme with `Buttons.Menu`), and for the title `Highlight` (`Texture`, `Color`, `Alpha`, `X`, `Y`, `BlendMode`) lit behind it while an item is held over it; or false, nowhere); `Ribbon` (`Length`, `Thickness`, `Color`, `BlendMode`, `Glow`: `{ offset, alpha }` lines, as many as listed; or false); `Spark` (`Texture`, `Size`, `Growth`, `Color`, `BlendMode`; false: no shimmer); `Cloud` (puffs as many as listed, `Join`, swell and breath; or false); `Buttons` (§11: `Icons`, every header button's icon by its key; `Color` and `HoverColor` for glyphs, `ArtColor` and `ArtHoverColor` for full-color art; `DisabledAlpha`; `Scale`, an icon's size as a share of its button; an icon's `Highlight`, art drawn over it under the pointer; an icon's `Pushed` art while pressed and `Disabled` art while disabled, drawn whole (neither dimmed nor grayed), as a button's pushed and disabled textures are; `RowStart`, where the row starts from the outer side when the pinned buttons hold the corner (the title's room counts the row from there or the pins, whichever reaches further); `Rail`, the buttons down a strip along the inner side instead of across the header, inside the body or `Outside` it, its art from `Start`, next-themes-ornaments.md §13, false in Default; `Pinned`, a button at a corner of the body apart from the row or the rail, next-themes-ornaments.md §13; `Menu`, the row in a bag button's menu, next-themes-menubutton.md §19). |
| `Search` | `Fill`, `FocusFill` (colors, or art: next-themes-art.md §14), `Edge` (`Color`, `Size`, `Idle`, `Hover`, `Focus`, or false), `Icon` (`Color`, `Idle`, `Active`, `FocusColor`, `ActiveColor`: while it holds a search, under the pointer or not, as Blizzard's magnifier stays white), `HelpFont`, `TextFont`; `Template = true` keeps the bag search box's own border (`BagSearchBoxTemplate`) and draws neither the fill nor the edge. |
| `Sections` | `Title` (`X`, `Y`), `CountGap`, `LineGap`, `TitleFont`, `RecentFont`, `FreeFont`, `CountFont`, `Header` (art behind the title row, across the section, `Layout.SectionHeader` tall, a fill, next-themes-art.md §16: pieced, its ends keep their shape in a narrower section, as Make It So's bar does, next-columns.md §7a or its own `Height` from the row's top, next-themes-makeitso.md §24; unset in Default), `Line` (`Color`, `From`, `To`, `Size`, or art, or false), `Highlight` (`Color`, `From`, `To`, or art, or false), `Compact` (`TextEnd`: room a compact section keeps after its text for the theme's art, an end cap or a bar's inset, next-columns.md §7b; or false for none). |
| `Tabs` | `Fill`, `SelectedFill` (colors fading by `Fade`, or art: drawn for the backpack's tabs, sticking out to the left, mirrored on the other panels, no fade), `Font`, `SelectedFont`, `Glow` (`Color`, `BlendMode`, `Drop`, `Pulse`, or false), `Indicator` (`Color`, `Width`, or art tinted by the accent, or false), `Highlight` and `SelectedHighlight` (art over the tab's fill under the pointer and when selected: Blizzard's list rows; mirrored with the panel), `Edge` and `SelectedEdge` (an edge round each tab, NextControls' edge: `Color`, `Alpha`, `Size`; the selected tab's and a drop target's in `SelectedEdge`, else `Edge`; next-themes-glitch.md §21), `Accents` (Warbank, Guild). A tab entry's `accent` is an accent name, a palette name or a color. |
| `Footer` | `Line` (`Color`, `Inner`, `Outer`, `Size`, or art mirrored with the panel, or false), `Font`, `EmptyFont`, `MoneyFont` (the guild's gold), `CoinFont` (the amounts in the bags' money frame; Default's `Footer`, issue #1226), `CoinFont` (the amounts in the bags' money frame; unset, its own font, next-themes-papercraft.md §25). |
| `Sparkles` | `Texture`, `BlendMode`, `Colors`, `FadeIn`, `FadeOut`, `TwinkleSpeed`, `TwinkleDepth`, `Shrink`, `WobbleSpeed`, `Upright` (never turned: square pixels, next-themes-glitch.md §21); emitters `Cloud`, `Ribbon` (+`Spread`), `Edge` (+`Reach`), `Knot` (+`Burst`), each `Rate`, `Max`, `Life`, `Size`, `Speed`, `Rise`, `Wobble`, `Spin`, `Alpha`, or false; `Sparkles = false` turns them all off. A coupled bag keeps its shorter ribbon and edge sparkle lives (next-chain.md §12, next-small-mode.md §14e). |
| `Chain` | Chaining (next-chain.md §12) and the braid: `Braid` (false: none), `Segments`, `Beads`, colors (`Color`, `BeadColor`, `KnotColor`), sizes and timing. |
| `Small` | Small mode (next-small-mode.md §14). The border's alpha is `Panel.Edge.Alpha`. `Grip` (next-small-resize.md §14g): `Size`, `Inset`, `ShowOnHover` (false: always seen), and `Normal`, `Highlight`, `Pushed` texture specs (mirrored on the left corner); `MinTitle`, the least room a narrowed panel keeps for its title. |
| `Drag` | `LiftScale`, `FlyScale`, `Shadow` (`Color`, `Alpha`, `Spread`, or false), `HintFont`, `HintGap`. |
| `Dock` | `Card` (a texture spec: a card can be art), `Pad`, `TitleHeight`, `LineHeight`, `Glow` (`Color`, `Width`, `Low`, `High`, `Period`, or false), `Halo` (`Texture`, `Color`, `Spread`, `Low`, `High`, `Period`, `BlendMode`, or false; the panel's column leaves `Spread` round each card), its line roles, `DestroyColor` (a section waiting to be destroyed glows in it; Default's palette `Crimson`), `BuyColor` (a shopping list waiting to be bought glows in it; Default's palette `Emerald`, profession-shopping-list.md). Drawn by `NextDockCard` (`next/dockcard.lua`), for each section waiting in a panel's dock (`NextDock`, next-drag.md §7). |
| `Vendor` | `QualityBorder` (a file, or false), `QuestMark`, `SearchDim`, `Highlight` (a color), tints (`Unusable`, `SoldOutUnusable`, `SoldOut`), roles (`PriceFont`, `UnaffordableFont`, `NameFont`, `StackFont`), a card's `CoinSize`, `CardFill` and `CardHover` (colors or art, or false), `DurabilityHeight`. |
| `ItemButton` | Optional: a Sonata `ItemButton` element style (sonata.md §3a) for item buttons while Next is in use (§6); its files are paths (Sonata's specs), its backdrop and quality border may be art. |
| `Settings` | The settings window (next-settings.md §3): `Width`, `Height`, `Fill` (a fill, next-themes-art.md §16), `Frame` (next-themes-art.md §15), `Wash` (or false), `Edge`; laid out as Blizzard's with `Title`, `InnerFrame`, `Tabs`, `Brand = false` and the placement keys of next-themes-plain.md §18; `Sidebar` (`Width`, `Pad`, `Fill`, `Line`, `Frame`: Blizzard's frame round it, next-themes-art.md §15, drawn under its pages and list), `Brand` (`Height`, `Icon`, `IconSize`, `IconColor`, `Gap`, `Font`, `Line`: `Color`, `From`, `To`, `Size`, or art), `Search` (`Icon`, `IconSize`, `IconColor`, `Gap`), `Back` (a page's own list: `Icon`, `IconSize`, `IconColor`, `Gap`, `Font`, `HoverFont`, `Slide` seconds), `Nav` (`ItemHeight`, `Indent`, `GroupHeight`, `GroupGap`, `Spacing` (between every heading and row), `TextRaise` (a row's text above its middle), `Indicator` (or false), `SelectedFill`, `HoverFill` (fills: at their atlas's size with `AtlasSize`), `GroupFills` (cycled through the headings, as Blizzard cycles `Options_CategoryHeader_1` to 3), `GroupLabel` (`Point`, `X`, `Y`: where a heading's label goes), its four fonts), `Version`, `Header` (`Height`, `Pad`, `TitleTop`, `Gap`, its fonts, `Close`: `Icon` or `Atlas`, `HoverIcon` (art of its own under the pointer), `Highlight` (a fill over it under the pointer), `Size`, `Inset`, or `Offset` (`X`, `Y`: anchor offsets from the top right, Blizzard's close anchors), `Color`, `HoverColor`; `Actions`: `Top`, `Gap`), `Content` (padding, `RowHeight`, `RowPad`, `MinColumn`, `Card`, `Divider` (or false: no lines), `Hover`, `TitleUpper` (false: section titles as written), its fonts), `Footer`, `Cards` (the theme pickers: sizes, fills, edges, status fonts), `Categories` (the Categories page, next-settings-categories.md §5: its list's rows, `Dot`, `Indicator`, fills; its tabs' `Pad`, `FieldGap`, `LabelWidth`, `FilterWidth`; fonts), `BagCategories` (a bag's arrangement of them). |
| `Controls` | Every control (next-controls.md §2): `ScrollBar` (the bags' too; its track and thumb fills), `Toggle` (`Style`: `Square`, `Round` or `Check`, next-themes-art.md §14), `Button` (`Plain`, `Primary`, `Danger`, `Link`: fills, edges and fonts by state, `DisabledFill`, next-themes-art.md §14, `Highlight` (a fill over it under the pointer while enabled), `DisabledFont`), `Input` (`Edge` or false), `TextArea` (a text area's own `Fill`, `FocusFill`, `Edge` and `Frame`, next-themes-art.md §15; each the input's when unset), `Slider` (`Track` a fill; `ThumbSize = "Atlas"`, next-themes-plain.md §17), `Dropdown` (next-themes-plain.md §17: `Justify`, `Chevron` art per state at `Size = "Atlas"` by `Point`, `DisabledFont`, `DisabledAlpha`, `NarrowWidth`, `NarrowFill`; `Edge` or false), `Menu` (`Inset` per side; `Border`, a fill over its fill; `Check` (`Size = "Atlas"`, `Off`, `Under`: the radio ring, next-themes-plain.md §17); `Picker`, a menu with a field (the category picker, next-category-picker.md): `Width`, `MaxRows`, `Gap`, `IconSize`, `Dot`, `HeadFont`, `NoteFont`, `NewIcon`, `BackIcon`), `Swatch`, `TopTabs` (its `Indicator` a color or art, or false; `Line` or false, reaching past the tabs by `Outset` (`Left`, `Right`) and stopping under the chosen tab with `Open`; tabs too wide for their row give up half their padding, then half their gaps, then cut their names, the longest first; `Fill`, `HoverFill`, `SelectedFill` per tab, `Padding`, `TextBottom`, `SelectedTextBottom`: Blizzard's `MinimalTabTemplate`, next-themes-plain.md §17), `Dialog` (`Card` a fill, `Border` over it, `Frame`, next-themes-art.md §15), `ItemGrid` (`Size`, `Gap`, `Pad`, `CommonEdge`, `DimAlpha`, `Hover`, `CountFont`, `EmptyFont`; its box's own `Fill`, `Edge` and `Frame`, the input's fill and edge when unset). A fill is a texture spec, a palette color or false; an edge a `Color`, `Alpha`, `Size` (and strengths `Idle`, `Hover`, `Focus`/`Open` for fields). `Motion.Time` adds `Toggle` and `TabMarker`. |

**Default is the v0.7.0 design, value for value**: `spec/fixtures/next_style_v0_7_0.lua` freezes
v0.7.0's `next/style.lua`, and `spec/next/style_theme_spec.lua` checks every value and every font
(file, size, color, shadow) against it. Changed on purpose since, and checked as changes: the vendor's
items as cards with larger prices (`VENDOR_PRICE` went; `Price` 10 to 13; next-vendor.md §10b), and its stack
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
  back from the text (`patterns-ui-text.md`). Used for the search box's help text, which
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
- **Controls and the settings window** (next-controls.md §2, next-settings.md §3): every control module restyles every
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

**A Next theme leaves quality on the icon's border** (`spec/sonata/next_themes_spec.lua`): none sets
`QualityBorder = "Backdrop"` (the ElvUI classic theme does, with `Masque = false`). **Failure mode (fixed, reported):**
Frost, Glitch, Halloween and Make It So drew quality on the button's own 1-pixel edge, which hid `IconBorder`, the texture
Masque skins, and Masque's Normal frame covers the edge (Caith: 42 of 36, `ARTWORK` over `BORDER`), so under Masque no
quality showed; Default showed it. A check for a skinned button could not have fixed it: a bag button joins its group on
its first `item/Updated`, after its first draw, and the draw record then skips later draws. Reported as missing without
Masque too. **Not known:** why the edge did not show there; the code sets its color and the mock shows it, and no capture
of it exists. Default's route works in both, so the themes use it, following Quality Glow Intensity as Default does.

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

## 10. A texture's alpha is its vertex color's

For a texture (and a line), `SetAlpha` and `SetVertexColor`'s alpha are **one value**: each replaces
the other. Blizzard's own code relies on it: `FCF_SetWindowAlpha` sets a chat window's alpha with
`SetAlpha` on its textures, and `FCF_GetChatWindowInfo` reads it back from
`background:GetVertexColor()` (`Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua`); both setters
add the same Alpha secret aspect (`SimpleRegionAPIDocumentation.lua`). A gradient's alphas are its
own: `SetAlpha` does not fade a gradient texture (§14d of next-small-mode.md; `patterns-ui-themes.md`).

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
  the repository root): sixteen glyphs, `textures/next/icons/*.png`, 64 x 64, white, the shape in the
  alpha. Drawn in the style of Blizzard's `uitools-icon` family, measured from its atlas (file 5400310,
  `UiTextureAtlas` 2561 on wago.tools): a 20-unit grid, a 1.5-unit stroke, about 1.5 to 18.5 across,
  so they fill a 22-unit button as the gear did. Blizzard's family has no anchor, lock, bag, bank tab,
  deposit, gold, filter, junk or repair icon, so BetterBags draws all sixteen, the gear and the close
  button too, so every button matches in weight and sharpness on every client (Blizzard's are 20
  pixels and blur when scaled up). Each is a set of signed-distance shapes (strokes, fills,
  knock-outs) sampled once per pixel with a one-pixel edge: settings (a gear), close, the anchor button's three
  (next-bag-anchor.md §30e: an anchor, the anchor in its square's corners, a padlock; the sort broom went with the sort
  button), classic bags (a backpack), small and full size (arrows
  in, arrows out), bank tabs (a tabbed panel), Warbank deposit (an arrow into a tray), deposit and
  withdraw gold (a coin stack with an arrow), filter (a funnel), sell junk (a price tag), repair (a
  hammer), guild repair (a hammer with a guild shield).
- **Drawn smooth:** `SetTexture(file, nil, nil, "TRILINEAR")` (`SimpleTextureBaseAPIDocumentation`:
  `filterMode`), as Blizzard draws its map tiles on every client, so a 64-pixel glyph drawn at 22 units
  (often 14 to 22 pixels) stays smooth, and stays sharp on large screens.
- **The theme gives every icon** (`Header.Buttons.Icons`, by button key): `settingsButton`,
  `closeButton`, `anchorButtonFree`, `anchorButtonShown` and `anchorButtonLocked` (the anchor button by state,
  next-bag-anchor.md §30b; it replaced `sortButton`), `bagsButton` (Show Blizzard Bags; it was `classicButton`, the switch to the
  classic bags it replaced), `sizeButtonFull` and `sizeButtonSmall` (the size
  button by state), `bankTabsButton`, `depositButton` (the Warbank), `depositGoldButton`,
  `withdrawGoldButton` (the guild bank's: renamed from `depositButton`/`withdrawButton`, which would
  have shared the Warbank's key), `filterButton`, `sellJunkButton`, `repairAllButton`,
  `guildRepairButton`. Default names its glyphs in `Textures` (`IconSettings`, `IconAnchor`, ...), so a
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
  origins) and led to tests, one of which found the stale ribbon start (next-themes-ornaments.md §13). An ornament guard no shipped panel can
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
  framed as an inset"), `spec/next/settings/page_spec.lua` (titles as written in cards), and next-themes-menubutton.md §19.
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
