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
| Next themes | `sonata/themes/next/*.lua` | `Default` (complete: every other theme inherits what it does not set from it), `Ember`, `Parchment`, `Quiet`. |
| `NextStyle` | `next/style.lua` | A view of the current theme (`Use`): the old constant fields (`ICON`, `PAD`, `Color`, `Time`, `Small`, `Chain`, `Cloud`, ...) keep their names and are read from the theme, so Next's code reads them as before; `style.Theme` is the resolved theme for widget specs. Fonts, `Paint`, `RGBA`, `Ease`, `TexturePath`. |
| Widgets | `next/*.lua` | Each draws from the theme and has an `ApplyStyle(ctx)` that restyles it live. |

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
| `Fonts` | Text roles: `Size`, `Color`, `Shadow` (true, a table, or none), `Flags`, `File` (unset: the client's own font, for the locale), `Justify`; or `Object`, one of the client's font objects by name, copied (its file, size and flags in every locale, its color and shadow) and changed only by what the role also sets (`Stack` copies `NumberFontNormal`, the bags' item count font); or `Copy`, a client font copied outright (its file, flags, color and shadow) at the role's `Size` (its own, or the one it inherits from Default; `false`: the client font's own), nothing else the role inherits changing it but its height on whole pixels and its own `Justify` (the Plain theme, at Default's sizes). Default's roles: Title, Section, SectionRecent, SectionFree, Count, Tab, TabSelected, Footer, Empty, DragHint, ConfirmTitle, ConfirmWarning, ConfirmHint, Search, SearchText, Price, PriceUnaffordable, VendorName, Stack; the controls' ControlText, ControlMuted, ControlHelp, Button, ButtonPrimary, ButtonDanger, Link, LinkHover, MenuItem, MenuItemSelected, DialogTitle, DialogText, TopTab, TopTabHover, TopTabSelected; the settings window's SettingsBrand, SettingsNavGroup, SettingsNav, SettingsNavHover, SettingsNavSelected, SettingsVersion, SettingsTitle, SettingsDescription, SettingsSection, SettingsSectionNote, SettingsLabel, SettingsText, SettingsLink. |
| `Layout` | Sizes: Icon (an item button's size; the player's Icon Scale, the Size tab, multiplies it: `style.ICON`; the grid's width and the vendor's cards keep the theme's own, `style.CARD_ICON`, docs/next-appearance-size.md), VendorColumns, VendorTextGap, VendorPriceRaise (the vendor's cards, next.md §10b), Gap, PerRow, Gutter, Pad, Feather, TitleTop, TitleInset, SearchTop, SearchHeight, SearchIcon, SearchGap, SearchRight, ContentTop, EmptyTop, Footer, FooterText, FooterMoney, SectionHeader, SectionSpacing, TabHeight, TabSpacing, TabMinWidth, TabMaxWidth, TabPadding, TabHover, TabIcon, TabIconGap, TabGroupGap, HeaderButton, HeaderButtonGap, HeaderButtonTop. |
| `Motion` | `Time` (every animation's seconds), `Ease` (Open, Close, SmallOpen, SmallClose, Enter, Fly, Glide, Hover, Wash, Cascade, Lift, Land, FlyAway, Pulse, Couple, Uncouple, Morph, MorphFade, Resize), `Rise` (the cascade). `NextStyle.OVERREACH` follows the Open ease's overshoot (outBack a tenth, outBackSoft a fiftieth, others none). |
| `Panel` | `Fill` (texture spec; `Inset`: `Left`, `Right`, `Top`, `Bottom` into the body, drawn for the backpack and mirrored on the bank, the screen-edge side still reaching past the edge while docked; `Panel:FillInsets()`), `Frame` (Blizzard's frame round the body, §15, mirrored on the bank; `Above` over the content, `Bands` across its top), `Feather` (`Color`, or false), `Wash` (`Height`, `BlendMode`, or false), `Washes` (Default, Warbank, Guild: palette names), `Edge` (`Color`, `Alpha`, `Size`, `Full`: on full panels too, kept through a size switch; or false), `DropGlow` (or false), `Ornaments` (§12; Default has none). |
| `Header` | `Title.Font`, `Title.Justify` (`"CENTER"`: centered in the room the header buttons leave, as Blizzard centers a window's title; its button and glow over the text where it is drawn); `TitleGlow` (`Texture`, `Color`, `Alpha`, `X`, `Y`, `BlendMode`, or false); `Ribbon` (`Length`, `Thickness`, `Color`, `BlendMode`, `Glow`: `{ offset, alpha }` lines, as many as listed; or false); `Spark` (`Texture`, `Size`, `Growth`, `Color`, `BlendMode`; false: no shimmer); `Cloud` (puffs as many as listed, `Join`, swell and breath; or false); `Buttons` (§11: `Icons`, every header button's icon by its key; `Color` and `HoverColor` for glyphs, `ArtColor` and `ArtHoverColor` for full-color art; `DisabledAlpha`; `Scale`, an icon's size as a share of its button; an icon's `Highlight`, art drawn over it under the pointer; an icon's `Pushed` art while pressed and `Disabled` art while disabled, drawn whole (neither dimmed nor grayed), as a button's pushed and disabled textures are; `RowStart`, where the row starts from the outer side when the pinned buttons hold the corner (the title's room counts the row from there or the pins, whichever reaches further); `Rail`, the buttons down a strip along the inner side instead of across the header, inside the body or `Outside` it, its art from `Start`, §13, false in Default; `Pinned`, a button at a corner of the body apart from the row or the rail, §13; `Menu`, the row in a bag button's menu, §19). |
| `Search` | `Fill`, `FocusFill` (colors, or art: §14), `Edge` (`Color`, `Size`, `Idle`, `Hover`, `Focus`, or false), `Icon` (`Color`, `Idle`, `Active`, `FocusColor`, `ActiveColor`: while it holds a search, under the pointer or not, as Blizzard's magnifier stays white), `HelpFont`, `TextFont`; `Template = true` keeps the bag search box's own border (`BagSearchBoxTemplate`) and draws neither the fill nor the edge. |
| `Sections` | `Title` (`X`, `Y`), `CountGap`, `LineGap`, `TitleFont`, `RecentFont`, `FreeFont`, `CountFont`, `Header` (art behind the title row, across the section, `Layout.SectionHeader` tall; unset in Default), `Line` (`Color`, `From`, `To`, `Size`, or art, or false), `Highlight` (`Color`, `From`, `To`, or art, or false). |
| `Tabs` | `Fill`, `SelectedFill` (colors fading by `Fade`, or art: drawn for the backpack's tabs, sticking out to the left, mirrored on the other panels, no fade), `Font`, `SelectedFont`, `Glow` (`Color`, `BlendMode`, `Drop`, `Pulse`, or false), `Indicator` (`Color`, `Width`, or art tinted by the accent, or false), `Highlight` and `SelectedHighlight` (art over the tab's fill under the pointer and when selected: Blizzard's list rows; mirrored with the panel), `Accents` (Warbank, Guild). A tab entry's `accent` is an accent name, a palette name or a color. |
| `Footer` | `Line` (`Color`, `Inner`, `Outer`, `Size`, or art mirrored with the panel, or false), `Font`, `EmptyFont`, `MoneyFont` (the guild's gold). |
| `Sparkles` | `Texture`, `BlendMode`, `Colors`, `FadeIn`, `FadeOut`, `TwinkleSpeed`, `TwinkleDepth`, `Shrink`, `WobbleSpeed`; emitters `Cloud`, `Ribbon` (+`Spread`), `Edge` (+`Reach`), `Knot` (+`Burst`), each `Rate`, `Max`, `Life`, `Size`, `Speed`, `Rise`, `Wobble`, `Spin`, `Alpha`, or false; `Sparkles = false` turns them all off. A coupled bag keeps its shorter ribbon and edge sparkle lives (next.md §12, §14e). |
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
  - `Sizes = "Full"` or `"Small"`: shown at that size only (unset: both); a size switch shows and hides them.
  - `Motion`: `Sway` (degrees either way of rest about `Origin`, `BOTTOM` when unset: a full swing every
    `Period`), `Spin` (a turn every `Period` about its middle, 1 clockwise, -1 the other way), `Pulse`
    (`{ from, to }` alpha and back every `Period`), `Bob` (up that far and back every `Period`), `Delay` (where in
    its motion it starts, so pieces do not move in step). `Origin` names one of the piece's points, `INNER` and
    `OUTER` included. `Period` defaults to 4.
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
