---
paths:
  - "sonata/**/*.lua"
  - "next/{style,panel,ornaments,frameart,fill,menubutton,tween}.lua"
  - "next/{glitch,rain,shatter,snow,threads,smoke,bats,beam,paper,stopmotion}.lua"
  - "next/controls/*.lua"
  - "next/settings/categories.lua"
  - "spec/next/shipped_themes_spec.lua"
  - "spec/sonata/next_themes_spec.lua"
  - "spec/helpers/ui_source.lua"
  - "spec/fixtures/atlas_sizes.lua"
  - "tools/atlas_sizes/generate.py"
---
## Windows and Elements Made on First Use Are Themed at Registration
**Problem**: a theme is applied at startup, to the windows and elements registered so far. A window built later on first use (the profiler's Settings form, the "Create New Bank Tab" group dialog) used to stay undecorated until the next theme change: no background and no close button.
**Solution**: `Sonata:RegisterWindow` / `RegisterElement` style what registers at once when a theme has already been applied; otherwise the first `ApplyTheme` does. Every window is a `Window` (`window/window.lua`), which registers itself. Coverage: `spec/sonata/engine_spec.lua` ("styles windows and elements registered after a theme was applied at once").
**Consequence**: a window's `OnDecorated` can run inside `window:Create`, before its owner made anything it places, and so can every option the styling reads (in the window size mode it sets the resize bounds from the minimums). An `OnDecorated` that places parts must do nothing while they do not exist, and the owner places them once made; an option must read only what exists before the window (a constant, a setting), not what the owner builds after it. The classic bags made by a design switch (next-bagsystem.md §11f) crashed on this; at login it never shows, because Sonata applies the theme after the bags exist. Test code that matters only once the addon is past login (switches, first use) on the whole addon (test-harness.md §5).

## Moving a Parent Moves Its Children, and Below 0 Is the Top
**Problem**: when a frame's level changes, every descendant shifts by the same amount, and one that would go below 0 is set to 10000 (warcraft.wiki.gg "Frame Strata"). A template child pinned low in XML (`DefaultPanelFlatTemplate`'s `Bg`, `frameLevel="0"`) is therefore thrown above everything when its parent is lowered, covering the window it should sit behind.
**Solution**: record each child's level relative to its parent when the parent is created, and after moving the parent put every child back at that offset, clamped at 0 (`sonata/decoration.lua` `applyTemplate`). Mocks must model the shift and the wrap (`spec/helpers/wow_mocks.lua` `SetFrameLevel`), or the bug cannot fail a test. See `.claude/rules/sonata.md` §3.

## SetAtlas Brings Its Own Coordinates, Tiling and Slicing
**Problem**: `Texture:SetAtlas` sets the atlas's texture coordinates, tiling and nine-slice data along with the file. Resetting a reused texture *after* `SetAtlas` (`SetTexCoord(0, 1, 0, 1)`, `ClearTextureSlice`, `SetHorizTile(false)`) shows the whole atlas sheet, stretches nine-slice atlases and stops tiling ones.
**Solution**: reset first, draw the file, atlas or color second, apply only what the spec sets explicitly last (`sonata/apply.lua` `apply:Texture`). Likewise `SetNormalTexture`-style setters take no nil asset: a state that only tints changes the region the button already has.

## Fade a Gradient Texture Through Its Colors, Not SetAlpha
**Problem**: BetterBags Next's feathers are gradient textures (`SetColorTexture(1, 1, 1, 1)` then `SetGradient` from the body's color to nothing). Switching between full and small faded them with `Texture:SetAlpha`, and in game they did not fade at all, while textures colored with `SetVertexColor` (the small border) faded with the same call. The spec mock honored `SetAlpha`, so the specs passed. Measured: only the player's report; inferred from the docs: a gradient is the texture's vertex colors (warcraft.wiki.gg TextureBase:SetGradient, "see Region:SetVertexColor"), `SetAlpha` and `SetVertexColor` share the same Alpha secret aspect (SimpleRegionAPIDocumentation), and Blizzard puts a gradient's alpha in its colors (`Blizzard_NamePlates.lua`, `CreateColor(r, g, b, a)`).
**Solution**: fade a gradient by setting it again with the alpha in its colors each frame (Next's `paintFeathers`, as `paintWash` always did), and leave its `SetAlpha` alone. In specs, check the gradient's colors (`texture._gradient`), not `GetAlpha`. next-small-mode.md §14d.

## A Texture's Alpha Is Its Vertex Color's Alpha
**Problem**: for a texture, `SetAlpha` and `SetVertexColor`'s alpha are one value, each replacing the other. Blizzard relies on it: `FCF_SetWindowAlpha` sets a chat window's alpha with `SetAlpha` and `FCF_GetChatWindowInfo` reads it back from `GetVertexColor` (`FloatingChatFrame.lua`). Treating them as separate (a theme alpha in the vertex color, a fade with `SetAlpha`; or coloring with `SetVertexColor` after `SetAlpha(0)`) showed in game as a border brighter than its theme after a fade, and a hover glow lit on open until hovered. The spec mock modeled them as separate until this was found.
**Solution**: set a texture's color first and its alpha last; restyling an animated texture keeps the alpha it shows (`GetAlpha` before, `SetAlpha` after); a texture with a theme alpha that also fades is faded through its vertex color alone. next-themes.md §10.

## Read Theme-Dependent Geometry When It Is Used, Never When Built
**Problem**: A closure made when a Next panel is built captured a value a theme decides (the title's join, from
`Pad`, `TitleInset` and now a side rail). A theme applied later moved the title but not the captured value: the
ribbon's sparkles started 40 pixels inside the body (next-themes-ornaments.md §13).

**Rule**: Anything a theme can change is read where it is used (a `Spawn`, a layout pass), as `NextStyle`'s fields
are; capture only what never changes for the panel (its side).

## A Part That Took a Color Takes Art Too, Through One Check
**Problem**: BetterBags Next drew tabs, search boxes, section lines and other parts as colors or gradients only, so
a theme matching another UI's art (Guild Wars 2) could not draw them (next-themes-art.md §14).

**Rule**: A themed part accepts a fill that is either a color or a texture spec with a `Texture`/`Atlas`
(`NextStyle:IsArt`). Draw art with `NextStyle:Paint`; draw a color its own way, after resetting what art left (the
texture's coordinates, and a plain white texture under the color). Art for a panel is drawn for the backpack
(inner side on the left) and mirrored on panels on the left of the screen, as ornaments are.

## A Gradient and a Vertex Color Are the Same Four Corners
**Problem**: The frame mock kept a gradient after `SetVertexColor`, so a test could not see a texture keeping an
old gradient after switching to tinted art.

**Rule**: In the client both write the texture's four corner colors, the last call winning
(warcraft.wiki.gg Region:SetVertexColor; Blizzard's `MarchingAntsMixin` switches between them on one texture).
The mock's `SetVertexColor` clears `_gradient`. When moving a texture from a gradient to art, `Paint` (which tints)
is enough; from art to a gradient, set a white color texture first.

## A Theme Part Set to False Arrives as Nothing
**Problem**: A Next theme turns a part off with `false` (`Edge = false`, `Indicator = false`), and resolution removes a
table set to `false` (`SonataResolve.Merge`), so the widget reads `nil`. Seven places read such a part unguarded
(`I.Edge.Idle`, `N.Indicator.Width`, `C.Divider.Size`): the Plain theme, the first to turn those parts off, broke the
settings window on every client. A second form: a part hidden when styled but shown again later (`marker:SetShown(width
> 0)`, a divider's `Show()` after placing) draws anyway.

**Rule**: Read every theme part as possibly absent (`local E = I.Edge; ... E and E.Idle`), and every later `Show` of a
part checks the part is still on. `spec/next/shipped_themes_spec.lua` draws every Next window with every shipped theme
on every client; a new part, or a theme turning one off, is covered by it.

## Protected Restyles Hide Errors From Specs
**Problem**: `SonataNext:RestyleWidgets` styles each widget in a `pcall` and hands a failure to `geterrorhandler()`,
as the client would show it, and the specs' mock handler returns the error and drops it. A theme that broke a widget
passed every spec that applied it (the pixel spec applied Plain to the bags and checked their pixels, not errors).

**Rule**: A spec that applies themes captures the handler (`_G.geterrorhandler = function() return function(err)
table.insert(errors, tostring(err)) end end`) and asserts nothing was sent. It restyles only the widgets it made (its own
`sonataNext.widgets` table for the run): other spec files' widgets were made against their own stubs.

## A Branch of Blizzard's UI Source Holds Every Client's Files
**Problem**: Since the UIs were unified, each branch of `wow-ui-source` carries every game type's folders
(`Mainline\`, `Classic\`, `Vanilla\`, `Camelot\`), loaded only by their own client (`[AllowLoadGameType]`, `[Family]`,
`[Game]`), and a whole addon can be one game type's (the damage meter is `## AllowLoadGameType: standard`, its art in an
unflavored file). Grepping a branch for an atlas proved nothing: retail's menu art passed as present on Classic.

**Rule**: To know what a client has, read the files its TOCs load (`spec/helpers/ui_source.lua`), and search those.
Read a template from the loaded file, not the first match in the branch. Use `origin/<branch>`: a local branch can lag
(the local `live` was a build behind).

## Copying Blizzard's Art Names Is Not Copying Its Look
**Problem**: The Plain theme's first version named only Blizzard's atlases, files and fonts, each checked to exist on
every client, yet in game the settings window was wrong in nearly every way: the list's header art (199 x 144) stretched
across a sidebar that started at the window's outer edge, its fill and art over the border, tabs floating with nothing
under them (their art is a hollow outline meant to sit on `Options_InnerFrame`'s edge), two columns of cards where
Blizzard draws one list. The specs had no atlas sizes, so art drawn at its atlas's size collapsed to nothing in them,
and nothing compared a placement with Blizzard's.

**Rule**: To match a Blizzard window, take its layout from its template (every anchor and size), its art's sizes from
the client's own atlas table (`spec/fixtures/atlas_sizes.lua`, `tools/atlas_sizes/generate.py`), and test placements
against those numbers. Look at the art before deciding where it goes (decode it from the client's files: hollow tab
outlines, a header bar with lines down its column), and look at the result drawn with the client's textures before it
ships; a layout dump through the specs' resolver (`spec/helpers/layout.lua`) gives exact rects to draw from.

## A Theme Key Set to False Is Nil By the Time Code Reads It
**Problem**: Plain sets `Brand = false`; resolution removes a table set to `false`, so the window read `nil`, and
`SetShown(B ~= false)` showed the brand. A window built before its theme applies (the settings window) also read
`Brand.Font` and `Header.DescriptionFont` at build time and failed under Plain.

**Rule**: Test a removable part as a table (`local on = B and true or false`), never against `false`; and never read a
removable part's keys at build time: give the region a role there and set the theme's at style time.

## A Control's Art Covers What Takes Its Clicks, and Each Control Has Its Own Look
**Problem**: The Plain theme's item boxes were white and its Search Rule box drew a 20-pixel strip in a box several times
taller. Both borrowed the single-line input's fill: Plain's is three pieces of the search border at their own thickness,
which on a plain texture (the item grid's) paints the whole box white, and on the text area covers a strip of what takes
its clicks.

**Rule**: A control draws its box from its own theme keys (`Controls.ItemGrid`, `Controls.TextArea`), falling back to
another control's only when the theme gives none, and its art covers exactly the area that takes its clicks (art at a
fixed thickness belongs to a control that is that tall). Blizzard has a frame for each: the single-line field's border,
the multi-line edit box's frame (InputScrollFrameTemplate), the inset (InsetFrameTemplate).

## Matching Default's Scale Means Matching Default's Numbers
**Problem**: Plain copied Blizzard's fonts and sizes (37-pixel item buttons, 10 to 12 point text), which made it look
smaller than the theme it sits beside; asked: "scale for Plain should be the same as our Default".

**Rule**: A skin theme takes Default's sizes (layout, fonts, controls) and replaces only the look; keep a Blizzard size
only where Blizzard's art fixes it (a title bar, a check box, a close button) or where Blizzard's is larger. `Copy` font
roles take the role's `Size` for exactly this (`Size = false` keeps the client's).

## A New Parent Changes a Frame's Level
**Problem**: Plain moves the bag's header buttons under a hidden frame and Default moves them back; the code assumed a
frame keeps its level across `SetParent` (its comment cited 7.0.3's "frame levels no longer change automatically"),
and the buttons came back at one above the panel, under a small panel's mover, which took their clicks. The spec mock
kept levels across `SetParent`, so a test that checked the level passed.

**Rule**: `SetParent` changes a frame's level (Blizzard's LFDFrame.lua: "Setting a new parent changes the frame level,
so we need to move it back"). Read the level before `SetParent` and set it after, as Blizzard's
`FrameUtil.SetParentMaintainRenderLayering` does; a "never lower it" check compares with the level read before. The
mock now gives a reparented frame one above its new parent.

## A Player's Choice Over a Declarative Theme Removes Parts After Resolution
**Problem**: players wanted BetterBags Next's sparkles and other effects off on any theme, not only on themes that
leave them out. Checking a setting in every widget that draws an effect would spread one choice across the panels,
and every new widget would have to remember it.

**Rule**: lay the player's choice over the resolved theme, in the engine, by removing the parts it turns off exactly
as resolution removes a part a theme sets to `false` (`SonataNext:effective`, next-themes-animation.md §20). Widgets already
handle every part being absent (shipped themes leave them out, and a spec draws every window with every theme), so
nothing else changes. Keep `Resolve` and `Check` raw for theme authors, and when the choice changes, re-lay it and
restyle without new font objects, which can never be freed.

## An Animation That Reads Its Theme Every Frame Must Survive the Theme Going

A tween that runs for a while and reads the theme on each update (BetterBags Next's glitches read `Panel.Glitch` on every
moment) outlives the theme it started under: a theme applied meanwhile, or an Animation switch that takes the part out,
leaves it reading nothing. Make the per-frame work do nothing (and put the widget at rest) when the part is gone, let the
animation finish so whatever waits for its end (a panel saying it has shown, which loads the bank) still hears it, and
have the widget's `ApplyStyle` start what the new theme has. Test it by applying a theme without the part mid-animation
and stepping the tween: the Glitch theme's code errored every frame of the rest of a glitch before it did
(next-themes-glitch.md §21).

## Count Every Flash a Theme Can Make

Flicker across a whole window is a flash in WCAG 2.3.1's sense (more than three a second over a large area can trigger
seizures). An effect that flickers a window's alpha or flashes large textures needs an Animation switch that takes it
out on any theme (next-themes-animation.md §20), and its rate written down where it is defined.

## Mask Textures: One Image per Orientation, Three per Texture

Two client rules for `MaskTexture` that the API documentation does not state (next-themes-makeitso.md §24, both in the spec
mock):

- **`SetTexCoord` does nothing on a mask.** A mask's art cannot be flipped, rotated or cut out of an atlas by its
  coordinates: draw every orientation as its own image (BetterBags Next's `corner_topleft.png` ... `corner_bottomright.png`,
  `beam_end_top.png` and `beam_end_bottom.png`). The textures a mask cuts keep their own coordinates (a scrolling
  texture can be masked).
- **A texture takes at most three masks**; a fourth raises "Texture already has the maximum number of mask textures
  (3)". Something that spans four masked regions (a body with four rounded corners) needs fewer masks or more
  textures. Take old masks off before adding new ones, and never add one twice.

Failure mode (fixed): one corner image flipped per corner rounded only the top left (the only corner needing no flip),
and a theme rounding four corners errored on the body's fill.

## Imperfect Stop Motion Needs Noise Keyed by Frame

A stop-motion look (next-themes-papercraft.md §25) is not a low frame rate alone: each pose lands a little off where it should be. That
offset must come from noise that is a pure function of the frame and a key (`NextTween.Noise`), not from `math.random` at draw
time: a pose held across several client frames then stays exactly where it landed even if it is drawn again, a slow frame that
skips poses lands where those poses would have, and the specs can name exact places. Anything that adds its time up
(`held`, a boil's `left`) keeps what a slow frame ran over, or the animation drifts slower than its FPS. And test that a held
pose draws once with a spy on the draw: since the noise repeats, redrawing it every frame looks identical and only costs time.

## A Texture With No Size Draws at Its File's Size

`SetWidth(0)` on a texture does not make it nothing: it means no width, and a texture with art and no width appears to draw at
its file's own width (seen in game: pencil art 128 units wide over a 48-unit box). So anything computing a length that can be
nil must not fall back to 0 for art (`pixel:Width(cap, size or 0)`), and a spec key read from the wrong level silently becomes
this. The frame mock reports 0 and shows nothing wrong: `layout.ArtWithNoSize` is the check, and a render only proves what it
was pointed at, so point it at every window a theme draws, not only the one the work was about.

## A Theme's Spec Inherits the Keys It Leaves Out
**Problem**: Sonata and SonataNext resolve a theme by merging it with its parent key by key (only lists replace).
A theme that draws art where its parent draws a faint color (`{ Texture = "Button", Color = "White" }` over Default's
`{ Color = "Gold", Alpha = 0.14 }`) also gets the parent's `Alpha`: Guild Wars 2's cream buttons drew at 14%.

**Rule**: A spec that replaces the look of a parent's spec sets every key the parent sets that would change it
(`Alpha` above all), and a spec over every shipped theme compares what a theme sets with what it resolves to
(`spec/sonata/next_themes_spec.lua`, "draws the art each theme sets at the alpha it sets"). `false` removes an
inherited table entirely (it resolves to nil).

## Restyle a Control Before Laying Out by Its Size
**Problem**: `sonataNext:RestyleWidgets` restyles the registered modules in `pairs` order, so on a theme change a
page's `ApplyStyle` can run before `NextButton`'s. A layout that places a control by its own size (centering a
button by its width) then reads the old theme's size, and the control resizes afterwards: the Categories page's
Convert to Category button sat 40 units off center after a theme with wider button padding.

**Rule**: A block that centers or right-aligns a control by its size restyles that control in its own `Style` before
laying out (`blizzardTabProto:Style`, next/settings/categories.lua: `self.convert:Style()`). Anchoring by the
control's left edge does not need it: a width change does not move it. Test it by restyling the page first and the
controls after, then checking the position.
