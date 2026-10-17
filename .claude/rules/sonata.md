# Sonata: the Declarative Theme Engine (`sonata/`)

Sonata replaces BetterBags' old theme API (`themes/themes.lua`, where a theme was a table of
functions that built frames). It is ported from the author's Moonlight addon
(`~/git/Moonlight/sonata/`, `~/git/Moonlight/themes/`) and extended to cover everything
BetterBags themes. **A theme is data**: tables of window styles and element styles, no code.
The old API is gone with no adapter; third-party theme authors port to Sonata.

Why: the old themes each built their own frames, search boxes, close buttons and bag buttons,
had to fit their art around fixed insets (`const.OFFSETS`), carried behavior (the GW2 theme
duplicated the Show Bags toggle), and third-party themes reached into internals
(`themes.titles`, `frame.Owner`) and hooked Blizzard tab art to learn a tab's state.

## 1. Themes and resolution (`sonata/engine.lua`)

`Sonata:RegisterTheme(theme)` takes a table with a unique `Name` (the saved key). Theme files
register as they load, before `Init`, which never clears `sonata.themes`.

| Key | Meaning |
|---|---|
| `Name` | the key the theme is saved and registered under |
| `DisplayName`, `Description` | shown in the theme pickers |
| `Parent` | the theme this one inherits from; unset means `Base` |
| `Hidden` | never listed or applied (`Base`) |
| `Available` | boolean, or a function (an addon the theme depends on is loaded) |
| `Masque` | `false`: item buttons are not handed to Masque |
| `Variables` | values or functions, used as `"$Name"` |
| `Windows` | window styles by window kind: `Bag`, `Panel`, `Flat`, `Dialog`, `Slots`, `Search` (§3, §3b) |
| `Elements` | element styles by element kind (item buttons, tabs, ...) |
| `Clients` | partial themes applied on a client (below) |

`Sonata:Resolve(key)` returns a **new, complete** table:

1. The chain is the theme, its parent, ... up to `Base`. A missing parent or a cycle is an error.
2. From `Base` down, each level merges into the result, then each of the level's `Clients`
   overrides for this client, in `GetClientKeys()` order (general first): `Retail`;
   `Retail`, `Forever` on WoW: Forever; `Classic` plus `Era`, `TBC`, `Mists`, `Cata`, or
   `TBC`, `Anniversary` on Anniversary (which also sets `isBCC`). An unknown client key is an
   error at registration.
3. Merge rules: tables merge key by key; **lists replace** (a table with `[1]`); **`false`
   replacing a table removes it** (a theme turns off something it inherited; a `false` with no
   table under it stays `false`, e.g. `Masque = false`); objects (a table with a metatable, or
   a frame) are kept by reference, never copied or merged.
4. `Variables` merge like everything else; then every value is evaluated (a function is called
   and must return something) and variables referring to other variables are filled in (a
   cycle is an error). Every whole-string `"$Name"` (spaces around the name allowed) becomes a
   copy of the variable. An unknown variable is an error; a string that only contains `$` stays.
5. `Name`, `DisplayName`, `Description`, `Hidden` describe the result; `Parent`, `Available`,
   `Clients` are not part of it. `Windows` and `Elements` always exist.

Resolution never changes the registered tables.

## 2. Applying and the registry

- `RegisterWindow(window, kind)` (ordered; registering twice is an error) and
  `RegisterElement(kind, element)` (held weakly; registering again does nothing). After a theme
  was applied, anything that registers is styled at once.
- `SetWindowDecorator(fn(window, style, theme))` and `SetElementStyler(kind, fn(element, style,
  theme))` install the code that turns styles into frames. One set after a theme was applied
  styles everything already registered. `GetDecoration(window)` is what the decorator returned.
- `ApplyTheme(ctx, key, save?)` errors on an unknown, hidden or unavailable theme, resolves it
  (a failure changes nothing), bumps `GetGeneration()`, saves it unless `save == false`,
  decorates every window and styles every element (each in its own protected call; failures go
  to `geterrorhandler()`), then sends `sonata/ThemeChanged` (key) and `bags/Redraw`. Windows and
  elements registered by a decorator or styler during the apply are styled once, as they
  register; one unregistered during the apply is skipped, and none is skipped by mistake.
- `Redecorate(window?)` decorates one window (or every window) again with the current theme,
  without saving, changing the generation, or redrawing: for state the decoration reads from
  the window (its title, its opacity).
- `OnEnable` applies the saved theme. A saved theme that is missing, hidden or unavailable this
  session falls back to `Default` **without changing the saved choice**, so a theme whose addon
  is disabled for one session comes back with it. **A theme registered after that** (another
  addon's theme registers when that addon loads, after BetterBags enabled Sonata in its own
  `ADDON_LOADED`) is applied at once, unsaved, when it is the saved choice, not already applied,
  and selectable. (The old theme module reset a missing saved theme to Default at login, so a
  third-party theme never survived a reload.)
- **Previews.** `GetSavedThemeKey()` names the theme the saved setting puts in effect (the
  saved theme, or Default while it is missing, hidden or unavailable), and
  `RestoreSavedTheme(ctx)` applies it, unsaved, when another theme is applied (nothing before
  the first apply, nothing when it is already applied). The settings window's Theme pane
  (`config/themepane.lua`) previews: picking a selectable theme applies it unsaved
  (`ApplyTheme(ctx, key, false)`; picking the saved one or an unavailable one shows the saved
  one), its status reads "Previewing", and only **Apply Theme** saves it. The preview applies
  on the **next frame** (`QueuePreview`, one `C_Timer.After(0)`; the last pick before then
  wins), never inside the click on the list: applying restyles and resizes the settings window
  around the list, and applying inside the click sometimes left the list blank until it was
  scrolled (reported in game). A pane that hides before then previews nothing. The pane's frame hides
  when the player opens another settings page or closes the settings window (`OnHide` also
  fires when an ancestor hides); `EndPreview` then restores the saved theme and forgets the pick.
  The list's check mark and "Currently Active" follow the saved theme, not the one previewed.
  Coverage: `spec/sonata/engine_spec.lua` ("names the theme the saved setting puts in effect",
  "puts the saved theme back after a preview", "restores nothing before Sonata applied a theme")
  and `spec/config/themepane_spec.lua` ("previewing").
- `GetThemes()` lists every theme that is not hidden, available or not (the theme pane shows
  unavailable ones as such); `GetAllThemes()` lists only those a player can pick now.
- `GetCurrentTheme()` is the resolved active theme (before any apply: the saved one, or
  Default), cached until the next apply. `GetWindowStyle(kind)` / `GetElementStyle(kind)` read
  it; a kind the theme does not style gets one shared, read-only empty table. **Styles are
  shared and read-only.** `UsesMasque()` is `theme.Masque ~= false`.
- The generation changes on every apply: anything that records what it drew with a theme (item
  button draw records, caches.md §4) compares it.

## 3. Window decoration (`sonata/decoration.lua`, `sonata/apply.lua`)

The decorator `SonataDecoration:Decorate(window, style, theme)` builds a window's chrome from a
window style, creating one decoration object per window on first use (`window.decoration`).
The window object provides `frame` (inheriting `BackdropTemplate`), `GetTitle()`,
`GetOpacity()` (0-100) and `OnCloseClicked(ctx)`, and may provide `OnDecorated(decoration)`,
which the decoration calls at the end of every apply (the Window module moves its content and
lays out again there, window.md §2).

| Style key | What it builds |
|---|---|
| `Insets` | the content box (`GetInsets()`, unset sides 0) |
| `Template` | a Blizzard frame template behind the window: `Name`, `Level` (offset from the window, default -1, never below 0), `Levels` (offsets from the window for the template's child **frames**, e.g. `NineSlice`; naming anything else is an error), `TitleFont`, `Title = false` (the template's title stays empty), `HideTitleWhenEmpty`, `Opacity` (the key of the region that fades), `Hide` (keys of template parts to hide), `BackdropColor` / `BackdropBorderColor` (for a template with `SetBackdropColor`, such as `TooltipBorderedFrameTemplate`; the template's own colors are recorded and given back when the next style releases it) |
| `Backdrop` | a backdrop on the window frame: `BgFile`, `EdgeFile`, `EdgeSize`, `Tile`, `TileEdge`, `TileSize`, `Insets`, `Color`, `BorderColor`, `Opacity` (default on; `false` keeps the fill), `BorderOpacity = true` (the border fades too), `Outlines` (extra edge-only borders, `Offset` > 0 outside, < 0 inside; `EdgeFile` defaults to `Interface\Buttons\WHITE8X8`) |
| `Background` | a texture filling the window (or `Inset`/`Points`), fading with opacity unless `Opacity = false` |
| `Border` | a texture filling the window; `Above = true` puts it over the content |
| `Textures` | named textures: anchored by `Points` (`RelativeTo` = `Window`, `Title` (only when the style has a title), or an earlier texture's `Name`; an unknown name is an error) or `Inset`; `Size` (`Width`, `Height`, or `MaxWidth` with `WidthOffset`: the window width plus the offset, capped, kept current on resize); `Above`; `Opacity = true` to fade. A texture with one point needs a `Size`. |
| `Title` | a font string: `Font`, `Color`, `Points` (default TOP, -5; may name a texture), `Height`, `Justify` (default the font's `Justify`, else CENTER) |
| `CloseButton` | `Template` (one button per template, reused), `Size` (default 24 without a template), `Points` (default TOPRIGHT -4,-4 without a template), `Normal`/`Highlight`/`Pushed`/`Disabled` (a texture, atlas or color; `false` clears the state), `HoverColor`, `Text` (drawn in `Font = { Object }`, default `GameFontNormal`; the button's own font is put back on release), `HitRectInsets` ({ left, right, top, bottom }); clicks call `window:OnCloseClicked(ctx)` |
| `Resize`, `Animations` | read by the window module |
| `Layout` | geometry for parts the window owns (search box, menu button, footer), `GetLayout()` |

**Any key set to `false`** (or any other non-table) builds nothing: a per-client override can
turn off a template, a backdrop, a title or a close button whether or not a parent theme
defined one.

Specs (`sonata/apply.lua`):
- Colors are `{ r, g, b, a? }` or `{ r =, g =, b =, a? }`.
- Fonts are `{ Object }` (a font object, or a name: BetterBags' `Fonts` module first, then the
  client's; unknown is an error), applied with the object's color and shadow so nothing an
  earlier style set stays; then `Path`, `Size`, `Flags`; then `Color`, `Shadow`, `Justify`.
- Textures are `Texture`, `Atlas` (`UseAtlasSize`) or `Color` plus `Layer` (kept when unset),
  `SubLevel`, `SliceMode` (`Stretched`/`Tiled`) and `SliceMargins`, `TexCoords`, `VertexColor`,
  `BlendMode`, `Desaturated`, `HorizTile`, `VertTile`, `Alpha`. `apply:Texture` **resets the
  texture first** (slicing cleared with `ClearTextureSlice`, present on every client;
  coordinates, tiling, tint, blend, desaturation, alpha), **then** draws the file, atlas or
  color, **then** applies what the spec sets. The order matters: `SetAtlas` brings the atlas's
  own texture coordinates, tiling and nine-slice data (`SimpleTextureBaseAPIDocumentation.lua`),
  which a reset after it would undo. `apply:ResetTexture` blanks a texture for reuse, size
  included.
- **Tiling loads the art with the `REPEAT` wrap mode.** `HorizTile`/`VertTile` pass `"REPEAT"`
  as the horizontal/vertical wrap mode to `SetTexture` (or `SetAtlas`) before setting the tile
  flags, as Blizzard's `SetTextureWithAddressModeOptions` does (`TextureUtil.lua`). With the
  default `CLAMP`, a texture tiled past its own size repeats its edge pixels: Slate's marble
  (256 x 256) drew as vertical streaks below its first 256 pixels. Coverage:
  `spec/sonata/apply_spec.lua` ("loads a tiled file with the REPEAT wrap mode", "loads a tiled
  atlas with the REPEAT wrap mode too") and the Slate tests in `spec/sonata/theme_ports_spec.lua`.
- Button states (`apply:ButtonStates`): a state given a file, atlas or color draws it, reset to
  fill the button, untinted, at full alpha; a state with only `VertexColor`, `TexCoords`,
  `BlendMode`, `Inset` or `Alpha` changes the art the button already has (the
  `Set*Texture` setters take no nil asset); `false` clears the state (`Clear*Texture`, every
  client); a state left out is kept. Blend modes are set on the region (only
  `SetHighlightTexture` takes one).

**Where things go, so content always draws above its fill** (see patterns-ui.md, "Filled
Backdrops Belong on the Panel Frame"): the backdrop is on the window frame itself; the
background, border and textures are the window frame's own regions (a frame's regions draw
below its child frames); a template sits below the window. What a style marks `Above`, the
title and the close button go on the **overlay frame**, 500 levels above the window, which
never takes the mouse; neither does a template or any of its children that is not a button
(the window frame must stay the drop target, bag-drop-zone.md).

**Template frame levels.** When a frame's level changes, every descendant shifts by the same
amount, and a descendant that would go below 0 jumps to 10000 (warcraft.wiki.gg "Frame
Strata"). `DefaultPanelFlatTemplate`'s `Bg` is pinned at `frameLevel="0"`, so lowering the
template under the window used to throw the background above the whole window. Each child's
level relative to the template is recorded when the template is created and put back, clamped
at 0, every time the template is placed.

**Switching themes leaves nothing behind.** Applying a style first releases the last one:
- the template gives back its title font, the alpha of its faded region and the shown state of
  the parts it hid or its title bar, then hides;
- the backdrop and outlines are cleared, and every texture returns to a pool, reset;
- the title is hidden, emptied, unanchored, height 0, back to `GameFontNormal` (its color and
  shadow) and centered;
- the close button gets back the points, size, text, hit rect and state art it was created
  with (a plain button: nothing), then hides.
Templates and close buttons are kept per name and reused.

**Build order**: template, backdrop, the title's font, background, border, textures, the title's
anchors, capped widths, close button, so a title can sit on a texture and a texture on the
title.

The capped widths follow the window through the overlay's `OnSizeChanged` (the overlay fills
the window), hooked with `addon.HookScript` so profiler captures see it: a script the window's
owner sets on the window frame cannot remove it. The close button's hover hooks also use
`addon.HookScript`; on leave it returns to its normal state's `Color` or `VertexColor`.

The close button takes the clicks `window:GetCloseClicks()` lists (`LeftButtonUp` for a
window without it) and passes the mouse button to `window:OnCloseClicked(ctx, button)`.

`SetTitle(text)` retitles the template (empty when `Title = false`; it shows or hides its title
bar for `HideTitleWhenEmpty`) and the decoration's own title. `SetOpacity(pct)` fades the
template's `Opacity` region, the backdrop fill (and its border with `BorderOpacity`), the
background and `Opacity = true` textures. Windows call these directly for title and opacity
changes; `Sonata:Redecorate` rebuilds the whole chrome. `Sonata:UpdateOpacity()` tells every
registered window that has `UpdateOpacity` to apply its opacity again (the Opacity sliders).

## 3a. Element styles (`sonata/elements.lua`)

`SonataElements` registers a styler per element kind. Every styler follows two rules:
- **A style sets everything it controls.** What it leaves out falls back to Blizzard's own look
  for that part (`withDefaults`: a part a style only partly describes keeps the rest of the
  default; a style that names its own file, atlas or color takes none of the default's art).
- **Template regions are recorded the first time a style changes them and put back** when a
  later style leaves them out (`captureRegion`/`restoreRegion`: file or atlas, coordinates,
  tint, blend, alpha, layer, desaturation, tiling, size, anchors; an atlas is restored after
  the coordinates are reset and keeps its own). Template art a style hides (`Strip`,
  `HideCaps`, `SearchIcon = false`) is hidden by alpha and gets its own alpha back.

| Kind | Element | Style keys (defaults are Blizzard's) |
|---|---|---|
| `ItemButton` | an item button's visual decoration | `Icon` (`Inset`, `TexCoords`), `Highlight`, `Pushed` (button states), `Backdrop` (`Color` fill, `Inset`; `BorderColor`/`EdgeSize` draw a 4-texture edge, `BorderInset` a number or per side), `QualityBorder = "Backdrop"`, `QualityColors` (per quality index), `UpgradeIcon` (`Atlas`/`Texture`, `Scale`), `Count` (`Font`, `Points`), `QuestIcon`, `QuestStarterIcon`, `QuestBorderColor` |
| `Tab` | a bottom tab | `Art = "Flat"` (template art hidden; `Background`, `Border`, `Hover` (HIGHLIGHT layer), `Selected = { Background, Bar, Border }`: `Bar` is a texture spec with `Height` and `Points` (default along the top), `Border = { Color }` recolors the tab's border while it is selected or a drop target), `Height` (default 32), `Font`, `HighlightFont`, `SelectedFont`, `TextOffset`, `SelectedTextOffset` |
| `SectionHeader` | a section title font string | `Font` (default `GameFontNormal`) |
| `SearchBox` | the in-bag `BagSearchBoxTemplate` box | `Strip`, `HideCaps`, `Middle` (texture spec + `Points`, `Height`), `SearchIcon` (`false` hides; a texture spec restyles), `ClearButton = { Icon }`, `Background`, `Border`, `Font` (default `GameFontHighlightSmall`), `Instructions` (default `GameFontDisableSmall`, 0.35 gray), `InstructionsPoints`, `TextInsets` (default 16, 20, 0, 0) |
| `BagButton` | the bag menu (portrait) button | `Size` (40; `Width`/`Height` per axis), `Portrait`, `Highlight` (texture spec + `Width`, `Height`, `X`, `Y`; OVERLAY 7; `false` hides it, the next style shows it again), `States` (`Normal`, `Highlight`, `Pushed`, `Disabled` through `apply:ButtonStates`, the button's own state art; every state a style leaves out is cleared, so a flat button never outlives its theme). Added for plugin themes whose menu button is flat art (macOS, Aero Glass in BetterBags - Themes); coverage `spec/sonata/elements_spec.lua` ("the bag menu button") |
| `Button` | `UIPanelButtonTemplate` buttons | `Strip`, `Background`, `Border`, `HoverBorderColor` (the border's color while the mouse is over the button; hooked once), `Highlight` (`false` hides the button's highlight by alpha, given back by a later style), `Font`, `HighlightFont`, `DisabledFont` (the button's own fonts are recorded and put back) |
| `EditBox` | `InputBoxTemplate` edit boxes | `Strip`, `Background`, `Border`, `Font` (the box's own font is put back) |

Details:
- `DrawItemQuality(decoration, color, quality)` draws quality on the backdrop edge and returns
  true only when the style takes quality (`QualityBorder = "Backdrop"`) and draws an edge;
  otherwise BetterBags' quality glow draws it (item-drawing.md §5).
- `DrawItemQuest(decoration, questInfo)` goes by the item's quest data (`isQuestItem`,
  `questID`, `isActive`, Blizzard's `UpdateQuestItem` arguments), never by whether the quest
  texture is shown: Classic's `IconQuestTexture` has no hidden attribute and is shown on every
  button. A quest border without a backdrop edge sets the icon border's texture
  (`WhiteIconFrame`), blend, coordinates and color itself, so no quality halo stays on it.
- `SetTabState(tab, "normal"|"selected"|"drop")` replaces toggling the template's art by hand
  (`frames/tabs.lua` `SelectTab`/`DeselectTab`, the drag highlight): `drop` (a section dragged
  over the tab) shows the active art without moving the text, and keeps the selected tab's
  idle art hidden. `GetTabState(tab)` returns the stored state (`normal` or `selected`; a drop
  is never stored), which the drag code sets back when the drag leaves or ends.
- **Tab decorations** (`frames/tabs.lua`): `Tabs:GetDecoration(ctx, tab)` makes each tab's
  decoration once (`tab.decoration`), from `BetterBagsSecureBagTabTemplate` (Blizzard's
  `PanelTabButtonTemplate` + `InsecureActionButtonTemplate` on retail, BetterBags' own art on
  Classic), on the tab at TOPLEFT, clicking the secure purchase button for purchase tabs,
  shown once out of combat, and registers it as a `Tab` element. The text is measured in the
  theme's font (the old forced `GameFontNormalSmall` is gone) and the tab is as tall as the
  decoration (the style's `Height`). `Tabs:Init()` (core/init.lua, after Sonata) keeps every
  bar `Tabs:Create` makes and reloads each on `sonata/ThemeChanged`, which Sonata sends after
  restyling every element, so the widths follow the new fonts; the bag window no longer
  reloads its tabs when it is decorated (that ran before the elements were restyled). A drag
  that ends resets both bags' bars (`Tabs:ResetDropHighlights`). Coverage:
  `spec/frames/tabs_spec.lua`, `spec/frames/section_spec.lua` ("Dragging a section"). Selecting sets `GameFontHighlightSmall` as the disabled font, as
  `PanelTemplates_SelectTab` does; text offsets come from the template (`selectedTextY`, ...)
  or `PanelTemplates_*`'s defaults (2 and -3).
- **Section titles** (`frames/section.lua`): each section registers its title's font string
  once as a `SectionHeader` element when it is created (the old code re-applied the theme's
  font on every `SetTitle`). `StyleSectionHeader` records the color it left on the font string
  (the font object's, or the style's `Color`), and `GetSectionHeaderColor(fontString)` returns
  it: `SetTitle` with no color of its own sets that color, so a pooled section that had a
  custom color goes back to the theme's, `Color` included (resetting to the font object's
  color, as before, would drop a theme `Color`). Coverage: `spec/frames/section_spec.lua`
  ("Title and Colors"), `spec/sonata/elements_spec.lua` ("section headers").
- Fonts set on button states (tabs, buttons) must be font objects: a button re-applies its
  state's font object when hovered, which would undo `SetFont`/`SetTextColor` on its label. A
  font spec with a `Path`, `Color`, `Shadow` or `Justify` becomes a font object made for it
  (`CreateFont`, one per distinct spec, copied from its `Object` first).
- Flat tab fills: background at BACKGROUND -8, selected fill at -7 (always above it), bar at
  OVERLAY 6.
- **Masque.** Restyling rewrites regions Masque skins (icon, highlight, pushed, count). A theme
  apply bumps the generation in every button's draw record (caches.md §4), so every button
  draws in full afterwards and Masque re-skins it on `item/Updated`. A theme with
  `Masque = false` (`Sonata:UsesMasque()`) keeps Masque off its buttons: on
  `sonata/ThemeChanged` the integration removes every button it skinned from its group
  (`RemoveButton` gives it its own look back), and it adds nothing while that theme is active;
  the next draw under a theme that uses Masque adds the buttons again
  (`spec/integrations/masque_spec.lua`).
- **Item decorations** are made once per button (`item:GetDecoration`, item-drawing.md §7a)
  and registered as `ItemButton` elements; a theme never builds its own.
- Edge sizes and insets are in UI units. Pixel-perfect edges at any scale are not yet
  expressible.

## 3b. BetterBags' themes (`sonata/themes/*.lua`)

**Bag padding is the same on both sides.** BetterBags centers the bag's items in its content box
(window.md §3b), so a theme's `Windows.Bag.Insets` (and the `Layout.Footer` that lines up with
them) must leave the same room inside the visible border on the left and the right. Art whose
border is uneven compensates in its insets, with the measurements written next to them.
`spec/sonata/theme_ports_spec.lua` ("pads every theme's bag the same on both sides") checks
every built-in theme on every client. Measured: Moonlight's two frame images (their opaque
edge and border line sit at the same pixels from both sides). Default's `DefaultPanelTemplate`
border (`ButtonFrameTemplateNoPortrait`): a retail recording shows its edge pieces are 75 pixels
wide, 8 outside the frame on the left and 4 outside on the right, as the layout places them; the
metal drawn inside them cannot be read from frames, so whether its visible border is uneven
(4 pixels more on the right if the left and right pieces are mirror images) is not measured yet.
ElvUI, GW2 and Simple Dark are backdrops, whose edge the recorder reads (render-recorder.md).

Each theme is a data file that calls `sonata:RegisterTheme`, listed in every TOC right after
`window\window.lua`, Base first.
Window kinds: **Bag** (the backpack and bank), **Panel** (forms: the settings and profiler
settings windows; the group dialog), **Flat** (the debug window), **Dialog** (question dialogs,
the search category editor), **Slots** (the Show Bags and bank tab panels), **Search** (the
overlay search panel).

- **Base** (hidden): what every theme inherits. Its `Windows.Bag` carries the bag's insets
  (6, 6, 42, 3), the default fade (`Animations`, 0.1 s alpha in and out) and the bag window's
  `Layout` (window.md §7): `Search` (points, `Reserve` 20), `Footer` (6, 6, bottom 6, height 20,
  `Reserve` 26), `MenuButton` (TOPLEFT -10, 7). Panel insets 4, 0, 30, 4; Flat and Dialog
  5, 5, 25, 5; Slots 8 on every side, with a fade that drops 10 pixels as it hides; Search 10, 10, 0, 0, with a fade that slides 10 pixels right as it hides. Its
  `Elements.SectionHeader` font is `GameFontNormal`.
- **Default**: Blizzard's look. Bags and panels are a `DefaultPanelTemplate` one level below
  the window (its `Bg` fades with the opacity; `NineSlice` and `TitleContainer` at window level
  + 500 and + 501, above the content), titled in `UnitFrame12Yellow`, with Blizzard's
  `UIPanelCloseButtonDefaultAnchors` close button. Flat windows and dialogs are
  `DefaultPanelFlatTemplate` (title in `UnitFrame12Yellow`, hidden when empty); flat windows add
  a `UIPanelCloseButton` at TOPRIGHT 2, 2. Slots panels are a headerless
  `DefaultPanelFlatTemplate` with insets 10, 6, 30, 12; on Classic (`Clients.Classic`) they are
  a tooltip backdrop on the window frame (`UI-Tooltip-Background`/`-Border`, edge 16, insets 4,
  black at 0.9, white border, not faded) because that template draws a title band there that
  cannot be hidden (classic-bag-slots-panel.md); on WoW: Forever (`Clients.Forever`) they are a
  `TooltipBorderedFrameTemplate` below the window colored black 0.9 with a white border, because
  that client redraws the flat template's header art too tall (camelot-forever.md §5). Both use
  even padding of 8. The Search panel is `BetterBagsSearchPanelTemplate` (`SimplePanelTemplate`
  on retail, BetterBags' own panel art on Classic) with no title and its `Inset` hidden. Section
  titles in `UnitFrame12Yellow`.

- **Simple Dark** (`SimpleDark`, the key saved profiles already use): every window a black
  `ChatFrameBackground` backdrop with a 1px gray (0.5) edge that fades with the opacity, border
  included (`BorderOpacity`); titles in `UnitFrame12White` at TOP, 30 high, on bags, panels,
  flat windows and dialogs; BetterBags' 12px `textures\close.png` close button at TOPRIGHT
  -8, -8 where windows close (not dialogs); slots panels and the search panel are the bare
  backdrop. The bag's search box sits at 20, -40 to -10, -60 and the menu button at 4, -6 with
  its art at 85% (`BagButton` portrait and highlight 40.8 x 51); section titles
  `UnitFrame12White`.
- **The Moonlight set** (`Dark` and `Parchment`, children of the hidden `Moonlight`; first
  released as `MoonlightDark` and `MoonlightParchment`, which `DB:Migrate` moves to the new keys.
  A third, Dark Round, was removed; Dark took its darker fill): Moonlight's art, shipped in
  `textures\moonlight\`, nine-sliced with 24px margins as every window's `Background` (`$Frame`,
  `$SliceMode`: Dark's tiled square frame `dark-frame.png`, Moonlight's default, or Parchment's
  stretched paper), content insets 18, 18, 40, 12 (they were 18, 24, 40, 12, ported from
  Moonlight: the images are opaque the same distance in from the left and the right, measured
  from the files, so the padding is the same on both sides, window.md §3b),
  `GameFontHighlight` titles in the text palette (`$TextColor`, `$TextShadow`: white with a black
  shadow on the dark themes) at TOPLEFT 44, -15 (20, -15 on dialogs), and a 32px close button
  lettered "X" (`CloseButton.Font`, §3). The bag's search box sits at 18, -40 to -18, -60
  (reserve 24), its footer at 18, 18, bottom 12 (the money and currencies sit on it), and a
  32px menu button (art 32 x 40) at 8, -6. **Dark** brings its menu button inside its frame's
  heavy border (which ends about 16 in): the button at 14, -12, the title at 50, -15, the
  search box at 18, -48 to -18, -68, and the bag's content box 48 from the top (8 lower).
  Parchment and Slate keep the set's positions.
  Parchment hangs its 281 x 84 ribbon over the bag (BOTTOM 40 below the window's TOP) and
  centers the bag's title on it.
  **Dark's fill** is Dark Round's: black at 0.75 (`0,0,0,192`) inside the frame's border, where
  Moonlight's frame had black at 0.30. It is baked into `dark-frame.png`: every pixel inside the
  border's solid black band (found by filling from the center up to the band) had its alpha
  remapped so the band's inner fade (pixels 10-15 from each edge) runs from 255 down to the new
  192 instead of to 77, and the fill itself became pure black at 192. The border, its band and
  the soft shadow outside it are unchanged, pixel for pixel. Dark Round's art, `dark-round.png`
  (a round #3c3b3c rim around the same fill), is no longer shipped.
  **Parchment's text** (§3c) is dark, in Blizzard's parchment text colors from the game's color
  table (`GlobalColor`): body `#2e1f0f` (`PARCHMENT_MATERIAL_TEXT_COLOR`), titles and accents
  black (`PARCHMENT_MATERIAL_TITLETEXT_COLOR`), the hovered settings entry `#350000`
  (`PARCHMENTLARGE_MATERIAL_TITLETEXT_COLOR`), good and bad `PARCHMENT_ACCESSIBILITY_GREEN` and
  `_RED`, secondary and muted text the browns of its tabs' text and the paper's burnt edge, no
  shadow, and a faint gold glow (35%) on the open settings entry. Its window titles follow the
  palette; its section titles are black `GameFontNormal` without a shadow
  (`Elements.SectionHeader`), and its close buttons are lettered in `GameFontBlack`.
- **Slate** (`Slate`, a child of `Moonlight`): Moonlight's own default theme. Every window's
  background is Blizzard's marble (`Interface\FrameGeneral\UI-Background-Marble`, present on
  every client), tiled the way Blizzard tiles it (`HorizTile`, `VertTile`,
  `CommunitiesMemberList.xml`; the inherited `SliceMargins` removed), fading with the opacity
  setting; no border art. Everything else is the Moonlight set's.

- **ElvUI** (`elvui`, offered while ElvUI is loaded): what ElvUI's skins would draw, as data,
  calling nothing of ElvUI's. Its variables read ElvUI's engine (`unpack(ElvUI)`) when the theme
  is applied: `media.blankTex`, `glossTex`, `bordercolor`, `backdropcolor`, `backdropfadecolor`,
  `rgbvaluecolor`, `Media.Textures.Close`/`BagQuestIcon`/`BagUpgradeIcon`, `PixelMode`,
  `twoPixelsPlease`, `Modern`, `Border`, `TexCoords`, `Scale` (each with a fallback, so
  resolving without ElvUI does not fail). ElvUI fills its media in its own `OnInitialize`, and
  BetterBags lists ElvUI as an optional dependency, so they exist when Sonata applies at
  login. Windows are the "Transparent" template (`SetTemplate`): a blank-texture backdrop in the
  fade color, a 1px edge (2 with two-pixel borders), black inner and outer lines outside pixel
  mode (`Outlines`), opacity left to ElvUI; `GameFontWhite` titles at TOP; ElvUI's close art
  12px inside a 24px button at TOPRIGHT -4, -4, tinted the value color on hover, hit insets 6, 6,
  7, 7. Item buttons (`HandleItemButton`, `HandleIconBorder`): the default template behind the
  icon (inset by the border width, ElvUI's icon crop), quality on the edge with common items
  black, white 30% hover and pushed fills, ElvUI's quest icon with a gold edge, its upgrade icon
  at 120%, and no Masque. Tabs (`HandleTab`): flat, the default template inset 3 (10 on older
  clients) from the sides, 1 (3 outside pixel mode) from the top and 3 from the bottom, text
  centered. The search box and edit boxes (`HandleEditBox`) and dialog buttons
  (`HandleButton`: the gloss texture, the value-color edge on hover, no highlight) are flat in
  the default template. The bag's search box sits at 10, -40 to -10, -60 and the menu button at
  4, -6 at 85%.

- **Guild Wars 2** (`GW2`, offered while GW2_UI is loaded, `GW2_ADDON`): GW2_UI's look from its
  own art files (`Interface\AddOns\GW2_UI\Textures\...png`), calling nothing of GW2_UI's
  (`CreateFrameHeaderWithBody`, `GwSkinButton`, `SkinBagSearchBox`). The bag: GW2's window
  header (`bagheader.png` from 25 below the window's top, its width the window's less 20 capped
  at 512, and `bagheader-right.png`), the 84px bag icon centered on the top left corner (-16,
  0), the world map background below the header (not faded), the 40px side panel along the left
  and the 55px footer; the title in GW2's header font (`DAMAGE_TEXT_FONT`, GW2's BigHeader size
  + 2 and outline setting, LightHeader color) at the header's bottom left (35, 10); GW2's close
  art on Blizzard's `UIPanelCloseButtonNoScripts` at TOPRIGHT -5, 14; no menu button
  (`MenuButton = false`), and in the side panel four action buttons (window.md, "Action
  buttons"): Show Bags, Sort, Settings and the menu, with GW2's micro-button icons, 32px, 5
  apart from TOPLEFT -35, -40. Other windows: GW2's tooltip backdrop (32px edge, insets 2, not
  faded) titled in `DAMAGE_TEXT_FONT` 16 at TOP 0, -5, GW2's close button at TOPRIGHT -1, -1 on
  panels and flat windows. The search box: no caps, `bagsearchbg.png` 24 high across it, the
  magnifier 10px at LEFT 6, text insets 20, `UNIT_NAME_FONT` at GW2's normal size in white.
  Section titles `UnitFrame12White`. Its variables read `GW2_ADDON.settings.fonts`, with
  GW2_UI's defaults (18, 14, 12).

**Tabs.** Default keeps Blizzard's tabs (`PanelTabButtonTemplate`) and ElvUI draws ElvUI's flat
tabs (above). Every other built-in theme draws flat tabs 26 high whose art starts 1 or 2 pixels
into the tab (the tab bar hangs 2 pixels into the window, `frames/tabs.lua`), text centered 1
below the middle, a light hover:
- Simple Dark: black, the window's 1px gray (0.5) edge, the selected tab 0.12 gray; text 0.7
  gray, white when selected or hovered (`GameFontHighlightSmall`).
- Dark: translucent black (0.55) in a 3px near-black edge, the selected tab lighter (white at
  0.1); gray and white text.
- Parchment: a strip of `parchment.png`'s plain middle (TexCoords 0.25-0.75, 0.3-0.5), dimmed
  (0.8, 0.76, 0.7) until selected, in a 2px burnt-brown edge (#74492d); dark brown
  `GameFontNormalSmall` text without a shadow, darker when selected.
- Guild Wars 2: GW2's downward tab art (`units\unittab_down.png`, what `GwSkinTab(tab, "down")`
  uses), `UNIT_NAME_FONT` at GW2's small size without a shadow, LightHeader when selected, and
  GW2's wine-red accent (`GW.Colors.Accent`) along the bottom of the selected tab.
- Slate: the tiled marble in a 1px dark edge, a cool gray bar along the bottom of the selected
  tab.
The colors of Dark and Parchment were read from the art's pixels. While a tab is
dragged, the reorder marker is as tall as the tabs (`tabs:UpdateDropPlaceholder`).

Coverage: `spec/sonata/themes_spec.lua` (Base hidden, its geometry and fades per kind; Default's
bag panel, levels, title font, opacity, close button and content box; panels, flat windows,
dialogs; slots panels on retail, Classic and Forever; section font) and
`spec/sonata/theme_ports_spec.lua` (Simple Dark; the Moonlight set, its art and Slate; every
theme's tabs, styled on a real tab; ElvUI against a
stand-in engine: availability, the template in and outside pixel mode, titles and close
button, Masque, item buttons, tabs, search box and buttons, bag layout; Guild Wars 2: availability,
the bag's header, panel, footer and background, its title and close button, the side buttons,
the other windows, the search box). Every file in
`sonata/themes/` is listed in every TOC after Base (`spec/render/toc_spec.lua`).

## 3c. Text roles (`Sonata:GetTextFont`, `CreateText`, `SetTextRole`, `SetButtonTextRole`)

BetterBags' own text (the settings window and its panes, dialogs, the search category editor,
the overlay search panel, the debug window's tabs, the bag footer's money and currency counts,
the empty-group hint) is drawn with **text roles**: named fonts in the theme's `Text` table,
each a font spec (§3). Before roles every such text hard-coded a client font and white, gold or
gray, so no theme could change it, and on Parchment's light paper it was white on parchment.

- **A font object is made once and never changed.** `Sonata:GetTextFont(role)` makes the
  current theme's font object for a role the first time it is asked for (`CreateFont`, named
  `BetterBagsText<Role><n>`, unique), styles it right away, and never touches it again.
  `Sonata:CreateText(parent, role, layer?)` makes a font string drawn with a role,
  `Sonata:SetTextRole(text, role)` switches a font string or edit box to a role, and
  `Sonata:SetButtonTextRole(button, role)` sets a button's normal font object; all three record
  the role (weak tables `texts`, `buttonTexts`). An unknown role errors.
- **A theme makes new font objects and moves the text.** `ApplyTheme` (before windows and
  elements) and every rescale of the client's fonts call `newTextFonts`: it starts an empty set
  of role font objects and points every recorded text and button at its role's new one. Text
  whose role the theme does not define keeps its font object. Old font objects stay as they
  were (font objects cannot be destroyed; a theme switch leaves at most one unused object per
  role behind). **Failure mode (fixed):** role font objects used to be restyled in place on
  every theme switch, relying on a font object passing its changes to the text set to it. The
  settings window is built before Sonata applies the saved theme, so its font objects were
  changed while its text used them, and a text that then switched font objects (hovering a
  settings entry: `Nav`, `NavHover`, back to `Nav`) came back out of step: the entry changed
  size until a theme switch restyled everything together. Restyling only at a different moment
  (re-copying on the client's rescale) did not fix it in game. The rule now: never change a font
  object after it is made; make a new one. `Sonata:Init` starts empty registries.
- **Text sized to its content refits after every font change** (`Sonata:WatchTextFont(text,
  fn)`, weak table `textWatchers`): `fn(text)` runs after `SetTextRole` and after `newTextFonts`
  moves the text (a theme, a client rescale). A button's own font string is sized when the
  button's text is set and keeps that width when its font changes; Blizzard documents it and
  resets it by setting the font string's width to 0, then the button's text again
  (`QuestLogTitleButton_Resize`, `Blizzard_UIPanels_Game/Cata/QuestLogFrame.lua`, "HACK ALERT").
  **Failure mode (fixed):** with font objects made once (above), settings entries still wrapped
  onto a clipped second line after a hover or a selection in game (Default and Dark, WoW:
  Forever): "Import/" left of "Import/Export", "General" cut too. A render recording
  (render-recorder.md, text entries) showed every Nav role in the same font and size, but the
  Nav role's shadow (offset 1) made a string about 0.8 wider than the hover and selected roles'
  glow (offset 0): "Import/Export" 110.8 against 110.0, "General" 64.2 against 63.3. Once sized
  in a glow role the entry kept the narrower width, so in Nav it wrapped (`lines=2`,
  `truncated=true`). Blizzard's reset (width 0, then the same text) refreshed the string's width
  but left the entry's at 110.0, also a frame later. The settings navigation
  (`forms/layouts/stacked.lua` `fitNavText`) therefore measures the entry when it is made and
  after every font change, and sets that width explicitly, rounded up with a pixel to spare, as
  Blizzard sizes a tab after changing its font (`CRFRaidMarkersMixin:SetTab`:
  `GetFontString():GetStringWidth()`). Text with a fixed width or two anchors needs no watcher.
- **A role font is a copy of its client font.** `styleTextFont` copies the role's client font
  with `Font:CopyFontObject`, then applies the role's color, shadow, file and justification;
  never `Font:SetFontObject`, which makes a font inherit from another (Blizzard makes its own
  runtime font objects by copying, `FontableFrameMixin.lua`). The client rescales its fonts with
  `SetFontHeight` for the Text Size setting after `VARIABLES_LOADED` and whenever the setting
  changes (`TextSizeManager.lua`), then sends `EventRegistry` `TextSizeManager.OnTextScaleUpdated`;
  `Sonata:Init` registers for it (one callback, Sonata as the owner, so a new `Init` replaces it)
  and makes new role fonts, so copies follow the client's sizes.
- **Text drawn with a role must not set its own color or shadow** (`SetTextColor`,
  `SetShadowColor`, `SetShadowOffset`): that overrides its font object. States switch roles
  instead: the settings navigation is `Nav`, `NavHover`, `NavActive` (`NavSub*` for entries), a
  theme's status `Positive`, `Description` or `Negative`, a profiler row `BodySmall` or
  `MutedSmall`.
- **Roles in Base** (`sonata/themes/base.lua`), each the client font its text used and its old
  color: `Heading`, `Label`, `Description` (settings sections, option titles and descriptions);
  `Title`, `Field`, `FieldSmall` (pane names and field labels, small headers); `Body`,
  `BodySmall`, `BodyLarge`; `Muted`, `MutedSmall`, `Empty` (notes, captions, empty-pane
  messages); `Positive`, `Negative`; the six `Nav` roles; `Search` (the overlay's typed text,
  `GameFontNormalHuge`); `Count` and `Money` (the bag footer, `Number12Font`; money is
  `NumberFontNormalRight` on Classic, a `Clients.Classic` override, as before). Near-identical
  grays were merged (0.7 and 0.9 into the 0.75 and white roles, 0.5 into 0.6), and the theme
  pane's "Unavailable" uses Blizzard's red text (`RED_FONT_COLOR`) instead of a dim red.
- **The palette.** Roles take their colors from variables, so a theme recolors all its text by
  setting them: `TextColor`, `TextSoftColor`, `TextMutedColor`, `TextAccentColor`,
  `TextAccentHoverColor`, `TextPositiveColor`, `TextNegativeColor`, `TextShadow`, `TextGlow`
  (a shadow with no offset). A theme can also restyle one role under `Text`.
- **What keeps its own font:** input fields (their own field art), the in-bag search box (the
  `SearchBox` element), item text on item buttons, item rows (quality colors), the bag-anchor
  and section-drag frames (their own backdrops), and the flame graph and timeline canvases.
- **Guard:** `spec/sonata/text_usage_spec.lua` fails when a file that draws this text sets a
  color or shadow, makes text with a client font, or uses a fixed BetterBags or number font.
  Specs whose code draws role text call `UseSonataTextRoles()` (`spec/helpers/addon_loader.lua`)
  and give their `Database` a `GetTheme`.

Coverage: `spec/sonata/text_spec.lua` (one named font per role, every role's Base look, a
theme's palette reaching roles and the text set to them, switching roles, one role restyled,
Classic money, new font objects per theme with text and buttons moved to them and the old ones
unchanged, no font object changed after it is made (through theme switches and rescales), text
on a role the new theme lacks, new role fonts at the client's sizes after a rescale, copies rather
than inheriting fonts, one text-size callback across `Init`s, unknown roles),
`spec/forms/stacked_text_spec.lua` (including a hovered settings entry after a theme application
ending on the same font object as the entries never hovered),
`spec/config/themepane_spec.lua`, `spec/frames/perfpane_spec.lua`, `spec/frames/money_spec.lua`,
`spec/frames/debug_window_spec.lua`, `spec/frames/search_overlay_spec.lua`,
`spec/frames/simulatepane_spec.lua`, and the Parchment and dark-theme tests in
`spec/sonata/theme_ports_spec.lua`.

## 4. Load order

`sonata\engine.lua`, `sonata\apply.lua`, `sonata\decoration.lua`, `sonata\elements.lua` follow
the render modules in every TOC, and `window\window.lua` follows them; `core/init.lua` calls `addon:GetModule('Sonata'):Init()` after Render's
(initialization.md). Modules start disabled; Sonata is enabled once windows exist.

## 5. Coverage

`spec/sonata/engine_spec.lua` (registration, availability, listing, inheritance, lists, false,
parents and cycles, client keys and their order, unknown client keys, variables: values,
functions, nested, cycles, nothing returned, spaces, copies; objects by reference, describing
keys, immutability; applying: styling, late registration, unregistering, order, generation,
messages and their order, failures (unknown, unavailable, hidden, unresolvable: nothing
changes), error isolation for windows and elements, registry changes during an apply,
idempotent elements, cache reuse, `Redecorate`, `GetDecoration`, late decorators and stylers,
the shared empty style; enabling: saved theme, fallbacks that keep the saved choice, Masque).
`spec/sonata/decoration_spec.lua` (decorator registration, insets, layout, one decoration per
window, templates: placement, levels, a flat template's background kept below the window,
child levels, title, font, empty titles, opacity, reuse, the mouse, hidden parts; backdrops,
fill and border opacity, outlines and their default edge and level, clearing; background, border
above, textures: anchors (title on a texture and back, no title for a style without one),
unknown anchor, capped widths through the overlay, release, pooling, fading only the current
theme's, atlases on reused textures; titles and font objects, justification, reset between
themes, template title font and title bar restored, `Title = false`; close buttons: templates,
clicks, plain ones, art replacement and its restore, hit rects, a plain button started from
nothing, hover tint and a solid normal color, the overlay; `false` keys; the overlay following
the window's level; a clean switch from a templated theme to a flat one).
`spec/sonata/elements_spec.lua` (every styler and its reset to Blizzard's look: icons,
highlight and pushed art with blend modes, backdrops with and without edges, per-side edge
insets, quality on the edge and per-quality colors, upgrade arrows styled in part, count font
and position, quest art by quest data (items, starters, Classic's always-shown texture) and the
quest border's texture; tabs: Blizzard art by state, template offsets, drop on a normal and on
the selected tab, flat art with fills, bar and hover, the selected fill above the normal one,
fonts and height reset, selected-only fonts, made font objects (shared per spec), highlight
fonts; search boxes: strip, middle art and its full restore, search icon, clear button,
instruction anchors; bag button: art, partial portraits, layers; buttons and edit boxes:
flattening, fonts and highlights put back, a highlight the button never had; through the
engine). `spec/sonata/apply_spec.lua` (both color forms, font objects by name or object, a font object's
color and shadow, font order; texture reset, atlas coordinates/tiling/slicing kept, explicit
atlas settings, solid colors, kept draw layer, reset for reuse; anchors and resolution errors,
insets; button states: art, blend modes, tint-only, `false`, reset of a state given new art,
insets).
The mocks follow the client: frame levels (a frame starts one above its parent; descendants
shift with it; below 0 becomes 10000), `SetAtlas` bringing its own coordinates, tiling and
slicing, `SetColorTexture` replacing a file or atlas, button state setters rejecting nil and
`Clear*Texture`, `BackdropTemplateMixin` (only frames that inherit or mix it in have a backdrop;
`SetBackdrop` semantics from `Backdrop.lua`), `Mixin`, `TooltipBackdropTemplate` (a `NineSlice`
and its own color setters, no `SetBackdrop`), font objects and `CreateFont` (`FontStyles.xml`),
`GetFontObject` returning the inherited font, `IsObjectType`, hit rects, `ClearAllPoints`
clearing `SetAllPoints`, Blizzard's templates (`DefaultPanelTemplate`,
`DefaultPanelFlatTemplate`, `UIPanelCloseButton*`) (`spec/helpers/wow_mocks.lua`).
