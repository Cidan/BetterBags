---
paths:
  - "next/frameart.lua"
  - "next/fill.lua"
  - "next/style.lua"
  - "spec/next/frameart_spec.lua"
  - "spec/next/fill_spec.lua"
  - "spec/fixtures/nineslice_layouts.lua"
---
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
  a theme's spec merges with Default's key by key (next-themes.md §2), so art a theme draws over one of Default's faint colored fills
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
  `Above`. Ornaments that say `Above` are drawn on the overlay too (next-themes-ornaments.md §12).
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
  `TexCoords` (else the fill's); each cap `Size` long, its own and not the fill's (else its atlas's; a cap drawn from a file
  with none gets no width, and a texture with no width draws at its file's: `Check` names it); `Thickness` thick and centered (else the
  region's), or `"Atlas"`: each piece its atlas's own thickness, the caps by their middles (or by their bottom corners
  with `Align = "BOTTOM"`), the middle hung from the caps' tops (MinimalSliderTemplate, MinimalTabTemplate); tinted by
  the fill's `Color` and alpha.
- **Wrapped**: buttons (and their `Highlight`), slider bars and scroll bar tracks (each in a frame of its own where the
  strip goes: `barFrame`, `trackFrame`), scroll thumbs, inputs and text areas, dropdowns, menus (and their `Border`),
  dialog cards (and their `Border`), the settings window's fill, the settings list's rows, page tabs.
- **Coverage**: `spec/next/fill_spec.lua`, and each widget's spec ("in three pieces", "past it", "at its atlas's size").
