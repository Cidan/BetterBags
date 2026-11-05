---
paths:
  - "next/shatter.lua"
  - "next/snow.lua"
  - "next/threads.lua"
  - "sonata/themes/next/frost.lua"
  - "spec/next/shatter_spec.lua"
  - "spec/next/snow_spec.lua"
  - "spec/next/threads_spec.lua"
  - "tools/textures/next_frost.py"
---
## 22. The Frost theme's engine (`next/shatter.lua`, `next/snow.lua`, `next/threads.lua`)

What the Frost theme (next-themes-shipped.md §8) needed of the engine, all of it data a theme gives, none of it Frost's alone.

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
    theme with a glitch (next-themes-glitch.md §21) opening or closing glitches instead.
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
- **Switches** (next-themes-animation.md §20): Ice Shatter and Snowfall; Moving Ornaments holds threads still.
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
