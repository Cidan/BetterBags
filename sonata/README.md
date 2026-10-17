# Writing BetterBags Themes (Sonata)

BetterBags draws every window, dialog, panel, item button, tab, section title, search box and
button through **Sonata**, a declarative theme engine. A theme is **data**: tables that say
what each kind of window and each kind of element looks like. A theme contains no code that
builds frames; BetterBags owns every frame and applies the theme to it, and re-applies another
theme cleanly when the player switches.

The themes BetterBags ships are in this folder's `themes/` directory and are the best
examples: `base.lua` (what every theme inherits), `default.lua` (Blizzard's look),
`simpledark.lua`, `moonlight.lua` (Dark, Parchment and Slate, sharing one hidden
parent), `elvui.lua` and `gw2.lua`
(themes that depend on another addon and read its settings through variables).

> The theme API before BetterBags' Sonata (a `themes:RegisterTheme(key, { Portrait = function
> ... })` table of functions that built decoration frames) is gone. See "Porting an old
> theme" at the end.

## Registering a theme from your addon

List BetterBags as a dependency, so your addon loads after it, and register your theme when
your file loads:

```toc
## Dependencies: BetterBags
```

```lua
local sonata = LibStub('AceAddon-3.0'):GetAddon('BetterBags'):GetModule('Sonata')

sonata:RegisterTheme({
  Name = "MyTheme",                 -- the key BetterBags saves; must be unique
  DisplayName = "My Theme",         -- shown in Settings > Theme
  Description = "A darker look.",
  Windows = { ... },                -- see "Windows"
  Elements = { ... },               -- see "Elements"
})
```

The player picks it in **Settings > Theme**. If the player's saved theme is yours, BetterBags
draws Default until your addon registers it, then switches to it in the same session.

## Theme keys

| Key | Meaning |
|---|---|
| `Name` | the key the theme is saved and registered under (required, unique) |
| `DisplayName`, `Description` | shown in the theme picker |
| `Parent` | the theme this one inherits from; unset means `Base` |
| `Hidden` | never listed or applied; for a parent that only shares settings |
| `Available` | `true`/`false`, or a function returning one (for example, whether an addon is loaded); unavailable themes are listed but cannot be applied |
| `Masque` | `false` keeps Masque off BetterBags' item buttons while this theme is applied |
| `Variables` | named values, or functions returning them, used anywhere as `"$Name"` |
| `Windows` | window styles by window kind |
| `Elements` | element styles by element kind |
| `Text` | text roles: the fonts of BetterBags' own text (settings, dialogs, the bag footer); see [Text](#text) |
| `Clients` | partial themes applied only on some game clients |

### Inheritance, and how themes merge

A theme is resolved from `Base` down through its `Parent` chain to the theme itself; each level
merges into what came before:

- tables merge key by key, so a theme sets only what it changes;
- lists (a table with `[1]`, such as `Points` or animation lists) **replace** the inherited list;
- `false` **removes** an inherited table: `CloseButton = false` takes away a parent's close
  button, `MenuButton = false` hides the bag's menu button.

### Variables

```lua
Variables = {
  Edge = { 0.4, 0.4, 0.4, 1 },
  Accent = function() return MyAddonDB.color end,   -- called when the theme is applied
},
Windows = { Bag = { Backdrop = { BorderColor = "$Edge" } } },
```

A string that is exactly `"$Name"` becomes a copy of the variable. Functions run each time the
theme is applied, so a theme can follow another addon's settings (the ElvUI theme reads ElvUI's
colors and textures this way). A child theme can override a parent's variables.

### Per-client overrides

`Clients` holds partial themes merged on top on some clients, general before specific:
`Retail`; `Retail` then `Forever` on WoW: Forever; `Classic` then `Era`, `TBC`, `Mists`, `Cata`,
or `TBC` then `Anniversary`.

```lua
Clients = {
  Classic = { Windows = { Slots = { Template = false, Backdrop = { ... } } } },
},
```

## Windows

Window kinds, and where BetterBags uses them:

| Kind | Windows |
|---|---|
| `Bag` | the backpack and the bank |
| `Panel` | the settings window, the profiler's settings, the group dialog |
| `Flat` | the debug window |
| `Dialog` | question dialogs, the search category editor |
| `Slots` | the Show Bags panel and the bank tab panel below a bag |
| `Search` | the search panel the search keybinding opens |

A window style:

| Key | What it does |
|---|---|
| `Insets` | `{ Left, Right, Top, Bottom }`: the content box inside the window; BetterBags lays out the window's contents there and sizes the window around it |
| `Template` | a Blizzard frame template drawn behind the window: `Name`, `Level` (offset from the window, default -1), `Levels` (offsets for the template's child frames, e.g. `{ NineSlice = 500 }` to draw a border above the content), `TitleFont`, `Title = false`, `HideTitleWhenEmpty`, `Opacity` (the key of the template region that fades with the player's opacity setting, e.g. `"Bg"`), `Hide` (keys of template parts to hide), `BackdropColor`, `BackdropBorderColor` |
| `Backdrop` | a backdrop on the window: `BgFile`, `EdgeFile`, `EdgeSize`, `Tile`, `TileEdge`, `TileSize`, `Insets`, `Color`, `BorderColor`, `Opacity` (`false`: the fill ignores the opacity setting), `BorderOpacity = true` (the border fades too), `Outlines` (extra edge-only borders: `{ Offset, EdgeSize, EdgeFile, Color }`, offset outside when positive, inside when negative) |
| `Background` | a texture filling the window (or `Inset`/`Points`); fades with the opacity setting unless `Opacity = false` |
| `Border` | a texture filling the window; `Above = true` draws it over the content |
| `Textures` | a list of named textures: `Name`, a texture spec, `Points` (relative to the window, the title, or an earlier texture by `Name`) or `Inset`, `Size` (`Width`, `Height`, or `MaxWidth` with `WidthOffset`: the window's width plus the offset, capped, following resizes), `Above`, `Opacity = true` |
| `Title` | the window title: `Font`, `Color`, `Points` (may name a texture), `Height`, `Justify` |
| `CloseButton` | `Template`, `Size`, `Points`, `Normal`/`Highlight`/`Pushed`/`Disabled` (texture specs; `false` clears a state; `Inset` places the art inside the button), `HoverColor`, `Text` and `Font = { Object }`, `HitRectInsets` (`{ left, right, top, bottom }`) |
| `Resize` | the grip shown when the player sizes a bag window: `Size`, `Points`, `Normal`, `Highlight`, `Pushed`, `ShowOnHover` |
| `Animations` | `Show` and `Hide` lists of `{ Type = "Alpha", From, To, Duration, Smoothing }`, `{ Type = "Translation", X, Y, ... }` or `{ Type = "Scale", From = { x, y }, To = { x, y }, Origin, ... }`; `false` shows and hides at once |
| `Layout` | where BetterBags places its own parts (below) |

Anything set to `false` builds nothing, even if a parent theme defined it.

BetterBags keeps content above a window's fills: the backdrop, background, border and textures
are drawn on the window frame below its contents, a template sits below the window, and
`Above` textures, the title and the close button sit on an overlay that never takes the mouse
(so dropping an item anywhere on a bag still works).

### Bag layout

A `Bag` style's `Layout` places the parts the bag owns, relative to the window:

| Key | What it places |
|---|---|
| `Search` | the in-bag search box: `Points`, and `Reserve` (the rows above the content it takes while shown) |
| `Footer` | the money and currency bar: `Left`, `Right`, `Bottom`, `Height`, `Reserve` |
| `MenuButton` | the round bag menu button: `Points`; `false` hides it |
| `Actions` | buttons running BetterBags actions (GW2's side panel): `Points` (the first button), `Size`, `Spacing`, `Buttons = { { Action, Normal, Highlight, Pushed }, ... }`, where `Action` is `ShowBags`, `Sort`, `Settings` or `Menu`; buttons stack downwards |

A `Slots` style's `Layout.Offset = { X, Y }` is where the panel's top left sits from its bag's
bottom left.

## Elements

| Kind | Element | Style keys |
|---|---|---|
| `ItemButton` | every item button | `Icon` (`Inset`, `TexCoords`), `Highlight`, `Pushed`, `Backdrop` (`Color`, `Inset`, `BorderColor`, `EdgeSize`, `BorderInset`), `QualityBorder = "Backdrop"` (draw item quality on the backdrop's edge), `QualityColors` (`{ [quality] = color }`), `UpgradeIcon` (`Atlas` or `Texture`, `Scale`), `Count` (`Font`, `Points`), `QuestIcon`, `QuestStarterIcon`, `QuestBorderColor` |
| `Tab` | the tabs below a bag | `Art = "Flat"` (hide Blizzard's tab art) with `Background`, `Border`, `Hover`, `Selected = { Background, Bar, Border }` (`Bar` with `Height` and `Points`; `Border = { Color }` while selected); `Height`, `Font`, `HighlightFont`, `SelectedFont`, `TextOffset`, `SelectedTextOffset` |
| `SectionHeader` | section titles | `Font` |
| `SearchBox` | the in-bag search box | `Strip` (hide its art), `HideCaps`, `Middle` (texture spec, `Points`, `Height`), `SearchIcon` (texture spec and `Points`, `Width`, `Height`; `false` hides it), `ClearButton = { Icon }`, `Background`, `Border`, `Font`, `Instructions`, `InstructionsPoints`, `TextInsets` |
| `BagButton` | the bag menu button | `Size`, `Portrait`, `Highlight` (texture spec and `Width`, `Height`, `X`, `Y`) |
| `Button` | buttons in dialogs and settings | `Strip`, `Background`, `Border`, `HoverBorderColor`, `Highlight` (`false` hides it), `Font`, `HighlightFont`, `DisabledFont` |
| `EditBox` | edit boxes in dialogs | `Strip`, `Background`, `Border`, `Font` |

An element style sets everything it controls; whatever it leaves out keeps Blizzard's look, so
switching themes never leaves part of the last theme behind. Fills and borders on elements
take a texture spec or a color: `Background = { Color = { 0, 0, 0, 0.8 } }`,
`Border = { Color = { 0.3, 0.3, 0.3, 1 }, EdgeSize = 1, Inset = -1 }`.

## Text

BetterBags' own text, in the settings window, dialogs, the search category editor, the search
panel, the debug window and the bag footer, is drawn with **text roles**: fonts named by what the
text is. Every theme inherits Base's roles, which take their colors from these variables, so a
light theme only needs to set the variables:

| Variable | Base | Used for |
|---|---|---|
| `TextColor` | white | headings, body text, values, the settings navigation, money and counts |
| `TextSoftColor` | light gray | option titles and descriptions, secondary information |
| `TextMutedColor` | gray | notes, hints, empty lists |
| `TextAccentColor` | gold | names and field labels, the open settings entry |
| `TextAccentHoverColor` | warm gold | the hovered settings entry |
| `TextPositiveColor`, `TextNegativeColor` | green, red | a good or bad state |
| `TextShadow` | black, offset 1, -1 | every role's shadow |
| `TextGlow` | gold glow | the hovered and open settings entries |

```lua
Variables = {
  TextColor = { 0.18, 0.12, 0.06, 1 },
  TextAccentColor = { 0, 0, 0, 1 },
  TextShadow = { Color = { 0, 0, 0, 0 }, X = 0, Y = 0 },
},
```

To change one role rather than a color, set it under `Text` (it merges with Base's):
`Text = { Field = { Color = { 0.4, 0.8, 1, 1 } } }`. The roles are `Heading`, `Label`,
`Description`, `Title`, `Field`, `FieldSmall`, `Body`, `BodySmall`, `BodyLarge`, `Muted`,
`MutedSmall`, `Empty`, `Positive`, `Negative`, `Nav`, `NavHover`, `NavActive`, `NavSub`,
`NavSubHover`, `NavSubActive`, `Search`, `Count` and `Money`. Window titles and section titles
are styled by their window and element styles (`Title.Font`, `SectionHeader.Font`).

## Specs

- **Colors**: `{ r, g, b, a }` (alpha optional) or `{ r = , g = , b = , a = }`.
- **Fonts**: `{ Object = "GameFontNormal" }` (a font object or its name; BetterBags' own fonts,
  such as `UnitFrame12White`, are found by name too), then optionally `Path`, `Size`, `Flags`,
  `Color`, `Shadow = { X, Y, Color }`, `Justify`. Use the client's locale font globals
  (`STANDARD_TEXT_FONT`, `UNIT_NAME_FONT`, `DAMAGE_TEXT_FONT`) or a font object rather than a
  font file, or other alphabets lose their glyphs.
- **Textures**: one of `Texture` (a file), `Atlas` (`UseAtlasSize`) or `Color`, plus `Layer`,
  `SubLevel`, `SliceMode` (`"Stretched"` or `"Tiled"`) with `SliceMargins = { Left, Right,
  Top, Bottom }` for nine-sliced art, `TexCoords`, `VertexColor`, `BlendMode`, `Desaturated`,
  `HorizTile`, `VertTile` (tile the art; Sonata loads it with the `REPEAT` wrap mode the tiling
  needs), `Alpha`.
- **Points**: a list of `{ Point, RelativeTo, RelativePoint, X, Y }`; `RelativeTo` defaults to
  the window (or the element) and may name a texture or `Title` where noted.

## Examples

A flat dark theme, inheriting everything else from Base:

```lua
local EDGE = { 0.25, 0.25, 0.25, 1 }
local FILL = {
  BgFile = "Interface\\Buttons\\WHITE8X8", EdgeFile = "Interface\\Buttons\\WHITE8X8", EdgeSize = 1,
  Color = { 0.05, 0.05, 0.05, 1 }, BorderColor = EDGE,
}
local TITLE = { Font = { Object = "GameFontHighlight" }, Points = { { Point = "TOP", Y = -8 } } }
local CLOSE = { Size = 20, Text = "x", Points = { { Point = "TOPRIGHT", X = -4, Y = -4 } } }

sonata:RegisterTheme({
  Name = "FlatDark",
  DisplayName = "Flat Dark",
  Windows = {
    Bag = { Backdrop = FILL, Title = TITLE, CloseButton = CLOSE },
    Panel = { Backdrop = FILL, Title = TITLE, CloseButton = CLOSE },
    Flat = { Backdrop = FILL, Title = TITLE, CloseButton = CLOSE },
    Dialog = { Backdrop = FILL, Title = TITLE },
    Slots = { Backdrop = FILL },
    Search = { Backdrop = FILL },
  },
  Elements = {
    ItemButton = { Backdrop = { Color = { 0, 0, 0, 1 }, BorderColor = EDGE }, QualityBorder = "Backdrop" },
    Tab = { Art = "Flat", Background = { Color = { 0.05, 0.05, 0.05, 1 } }, Border = { Color = EDGE } },
  },
})
```

Default with one change, by naming it as the parent:

```lua
sonata:RegisterTheme({
  Name = "DefaultWhiteTitles",
  DisplayName = "Default (white titles)",
  Parent = "Default",
  Elements = { SectionHeader = { Font = { Object = "GameFontHighlight" } } },
})
```

A theme for another addon:

```lua
sonata:RegisterTheme({
  Name = "MyUI",
  Available = function() return MyUI ~= nil end,
  Variables = { Border = function() return MyUI.db.borderColor end },
  Windows = { Bag = { Backdrop = { EdgeFile = "Interface\\Buttons\\WHITE8X8", EdgeSize = 1, BorderColor = "$Border" } } },
})
```

## Porting an old theme

| Old theme function | Sonata |
|---|---|
| `Portrait(frame)` | `Windows.Bag` |
| `Simple(frame)` | `Windows.Panel` |
| `Flat(frame)` | `Windows.Flat`, `Windows.Dialog`, `Windows.Slots` |
| `Opacity(frame, alpha)` | `Template.Opacity`, `Backdrop.Opacity`/`BorderOpacity`, `Background`, `Textures[].Opacity` |
| `SectionFont(font)` | `Elements.SectionHeader.Font` |
| `SetTitle(frame, title)` | `Title` (BetterBags sets the text) |
| `ToggleSearch(frame, shown)`, `searchBox:CreateBox` | `Layout.Search` (BetterBags owns the box) |
| `themes.SetupBagButton` | `Layout.MenuButton`, `Elements.BagButton` |
| `ItemButton(item)` | `Elements.ItemButton` (BetterBags owns the decoration; do not create one) |
| `Tab(tab)` | `Elements.Tab` |
| `PositionBagSlots` | `Windows.Slots.Layout.Offset` |
| `DisableMasque = true` | `Masque = false` |
| `Reset()` | nothing: BetterBags releases a theme's look itself |

Build nothing, hook nothing and reach into no BetterBags frame: everything a theme can change
is a key above. If you need a look the keys cannot express, open an issue.
