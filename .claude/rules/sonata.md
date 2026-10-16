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
| `Windows` | window styles by window kind: `Bag`, `Panel`, `Flat`, `Dialog` (§3) |
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
  is disabled for one session comes back with it.
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
`GetOpacity()` (0-100) and `OnCloseClicked(ctx)`.

| Style key | What it builds |
|---|---|
| `Insets` | the content box (`GetInsets()`, unset sides 0) |
| `Template` | a Blizzard frame template behind the window: `Name`, `Level` (offset from the window, default -1, never below 0), `Levels` (offsets for the template's child frames, e.g. `NineSlice`), `TitleFont`, `Title = false`, `HideTitleWhenEmpty`, `Opacity` (the key of the region that fades) |
| `Backdrop` | a backdrop on the window frame: `BgFile`, `EdgeFile`, `EdgeSize`, `Tile`, `TileEdge`, `TileSize`, `Insets`, `Color`, `BorderColor`, `Opacity` (default on; `false` keeps the fill), `Outlines` (extra edge-only borders, `Offset` > 0 outside, < 0 inside) |
| `Background` | a texture filling the window (or `Inset`/`Points`), fading with opacity unless `Opacity = false` |
| `Border` | a texture filling the window; `Above = true` puts it over the content |
| `Textures` | named textures: anchored by `Points` (`RelativeTo` = `Window`, `Title`, or an earlier texture's `Name`; an unknown name is an error) or `Inset`; `Size` (`Width`, `Height`, or `MaxWidth` with `WidthOffset`: the window width plus the offset, capped, kept current on resize); `Above`; `Opacity = true` to fade |
| `Title` | a font string: `Font`, `Color`, `Points` (default TOP, -5), `Height`, `Justify` (default CENTER) |
| `CloseButton` | `Template` (one button per template, reused), `Size`, `Points` (default TOPRIGHT -4,-4 without a template), `Normal`/`Highlight`/`Pushed`/`Disabled` textures or atlases, `HoverColor`, `Text`; clicks call `window:OnCloseClicked(ctx)` |
| `Resize`, `Animations` | read by the window module |
| `Layout` | geometry for parts the window owns (search box, menu button, footer), `GetLayout()` |

Specs (`sonata/apply.lua`): colors are `{ r, g, b, a? }`; fonts are `{ Object }` (BetterBags'
`Fonts` module first, then a global font object; unknown is an error) or `{ Path, Size, Flags }`
plus `Color`, `Shadow`, `Justify`; textures are `Texture`, `Atlas` or `Color` plus `Layer`,
`SubLevel`, `SliceMode` (`Stretched`/`Tiled`) and `SliceMargins`, `TexCoords`, `VertexColor`,
`BlendMode`, `Desaturated`, `HorizTile`, `VertTile`, `Alpha`. Applying a texture spec sets every
one of these (to the spec's value or the default; slicing is cleared with
`ClearTextureSlice`, present on every client), so a reused texture keeps nothing.

**Where things go, so content always draws above its fill** (see patterns-ui.md, "Filled
Backdrops Belong on the Panel Frame"): the backdrop is on the window frame itself; the
background, border and textures are the window frame's own regions (a frame's regions draw
below its child frames); a template sits one level below the window. Only what a style marks
`Above`, the title and the close button go on the **overlay frame**, 500 levels above the
window, which never takes the mouse (the window frame must stay the drop target, bag-drop-zone.md).

**Switching themes leaves nothing behind**: applying a style first hides the template, clears
the backdrop, hides outlines, returns every texture to a pool (reset), hides the title and the
close button. Templates and close buttons are kept per name and reused.

`SetTitle(text)` retitles the template (and shows or hides its title bar for
`HideTitleWhenEmpty`) and the decoration's own title. `SetOpacity(pct)` fades the template's
`Opacity` region, the backdrop fill (not its border), the background and `Opacity = true`
textures.

## 4. Load order

`sonata\engine.lua`, `sonata\apply.lua`, `sonata\decoration.lua` follow the render modules in
every TOC; `core/init.lua` calls `addon:GetModule('Sonata'):Init()` after Render's
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
window, templates: placement, levels, title, font, empty titles, opacity, reuse; backdrops,
fill opacity, outlines, clearing; background, border above, textures: anchors, unknown anchor,
capped widths, release, pooling; titles and font objects; close buttons: templates, clicks,
plain ones, art replacement, hover tint, one per template; a clean switch from a templated
theme to a flat one). The mocks follow Blizzard's templates (`DefaultPanelTemplate`,
`DefaultPanelFlatTemplate`, `UIPanelCloseButton*`, `BackdropTemplate`) and texture, button and
font APIs (`spec/helpers/wow_mocks.lua`).
