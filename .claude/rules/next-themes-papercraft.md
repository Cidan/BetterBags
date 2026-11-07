---
paths:
  - "next/paper.lua"
  - "next/stopmotion.lua"
  - "sonata/themes/next/papercraft.lua"
  - "spec/next/paper_spec.lua"
  - "spec/next/stopmotion_spec.lua"
  - "spec/integration/papercraft_spec.lua"
  - "tools/textures/next_papercraft.py"
---
## 25. The Papercraft theme's engine (`next/paper.lua`, `next/stopmotion.lua`, ornaments' `Frames` and `Boil`)

What the Papercraft theme (next-themes-shipped.md §8) needed of the engine, all of it data a theme gives, none of it Papercraft's alone.

- **Stop motion** (`Motion.StopMotion = { FPS, Spacing, Wobble }`, NextStopMotion; `style.StopMotion` for what steps itself).
  Asked for imperfect placement, not only a low frame rate, so each part lands off where it should be, by noise that is the
  same for the same frame (a held pose never moves):
  - **Tweens** (`NextTween.Stepping`, `tween:pose`): every tween holds each pose for a whole frame, its time up to `Spacing`
    of a frame's step off its even place (under a half, so it never goes back; never past its end), and still ends exactly
    at its end. A tween that says `smooth` runs every frame: what steps itself (below) has no second stepping over it.
  - **What a layout moves** (`motion:BeginPass(root, duration, stepping)`, render-pipeline.md §4c): the canvas, a settings
    list's rows and the currency strip and tracker pass `style.StopMotion`; each pose is held, up to `Wobble` units off its
    line, and the move ends exactly where it goes.
  - **What runs itself**: the sparkles' emitters and the chain's braid (`held`) wait a pose, then step with all the time it
    held. Ornaments boil (next-themes-ornaments.md §12) at a rate of their own, set by the theme.
  - Not stepped: what the client animates (a theme's swaying ornaments, next-themes-ornaments.md §12) and a `smooth` tween.
- **The sheet** (`Panel.Paper`, NextPaper, driven by the panel: `paperIn` from `moveIn`, `paperOut` from the slide out). The
  client cannot draw a frame's content into a texture, so a run draws the sheet itself on the paper layer (a frame over the
  screen in the `DIALOG` strata, taking no mouse, with its own driver), from `Front` and `Back` (texture specs: the body's
  art and the paper's other side), `Edge` (`Texture`, `Width`, `Inside`, `Tile`), `Shadow` (`Texture`, `Spread`, `X`, `Y`),
  at `Rate` poses a second. Every part is a pooled texture moved with `SetVertexOffset`, as the shatter's shards are (next-themes-frost.md §22): a
  1 x 1 texture at the layer's bottom left, its four corners moved where they go, the right way round whichever way the
  paper has flipped (`quad`), without the client's sharpening (texture-sharpening.md).
  `Wobble` (`Move`, `Turn`, `Vertex`, `Pose`) is how far a pose lands off under a stop motion: the whole sheet moved and
  turned, each corner its own way (a corner cells share is one place, so it never tears), its angle off its pose (never a
  flap lying flat or right over). Without a stop motion the run goes between its poses every frame, with no wobble.
- **Unfolding** (`Open`; `Unfold(t)`). A lattice of `Cells` a half each way, from the `From` corner (`TOPOUTER`,
  `BOTTOMINNER`...; mirrored with the panel). A sheet folded in four has two hinges, and its layers show as a real one's do:
  - `Quarter`: poses of the folded note, each `Scale` and `Turn`, as it drops into place; `Note` (art with `Frames`, `Width`,
    `Height`, `X`, `Y`) is drawn on its outside, turning with the flap, until the flap comes past upright.
  - `Half`: the first fold's flap swings across its hinge, angles from 180 (right over) to 0 (flat), showing the paper's back
    on both sides of the fold, the half of the flap facing the viewer changing as it passes upright.
  - `Full`: the second fold's flap swings down, its back to the viewer until upright, the front of the sheet under it.
  - `Curl` bends a flap across its length, `Depth` draws it nearer the viewer as it lifts, `Lit` shades it as it turns from
    the light; a flap casts `Shadow` on what is under it. Once flat (`OpenLock`) the panel shows and says it has shown, its
    sections cascading in and threads drawing in from then, and the sheet goes over it, a pose at a time, over `Reveal`
    (`Linger`, on the layer's driver).
  - **The budget:** a bank waits for its panel to have shown before it loads, 1 second at most (refresh-scheduler.md §11):
    Papercraft's eleven poses at twelve a second are 0.92 s. The panel stays unseen until the sheet lies flat, set again
    on each frame of it: a small panel's place shows it (`setOffset`).
- **Crumpling** (`Close`; `Grab`, `Crumple`, `Warp`, `DrawCrumple`). The panel trembles where it stands for `Grab` poses, by
  `Tremble` units and less and less; then it is gone and the sheet takes its place, carrying on alone on the layer's driver.
  - The shatter's mesh (`Cell`, `Jitter`; next-themes-frost.md §22) over the body; each corner goes (`Warp`) from where it lies to a place on a ball
    `Ball` units across, its middle staying toward the viewer and its edges gathering behind (`Wrap`). Its edges start first
    (`Lag`), `Lump` makes the ball no sphere, `Wrinkle` rises and sinks on the way (gone at both ends), `Twist` turns it as it
    draws in, `Jag` moves each corner its own way, most of all half way in. `Poses` are shares from 0 to 1, the last 1.
  - Facets are shaded by how they face the light (`Lit`, `Facet` for a fleck of their own); one turned from the viewer shows
    the paper's back, and nearer ones are drawn over farther ones (their sublevels). The shadow draws in with it and is gone
    on the ball: a ball in the air casts none on the screen.
  - **What is printed on it** (`panel:PaperDecals`): each item shown in the scroll area, in UIParent's units, its icon cropped
    (`Crop`) on `Mount`, carried by Warp. They draw over the paper, so paper cannot hide them: one is hidden once it has turned
    from the viewer or, past 0.55 of the way, gone round the ball's side; none is left on the ball. **Why:** from a render,
    printed items on a finished ball read as a beach ball's stripes.
  - `Toss`: `Up` a second, `Gravity`, `Drift` (toward the middle of the screen), `Tumble` (radians a second about two axes),
    `Life` (seconds at most). It is given back once it is off the bottom of the screen, or at its Life.
- **Stopped part way:** the panel's tween owns the run. A flight, a placement or Escape stops it, and the sheet is given back
  at rest (`onStop`); a theme gone mid-fold (another theme, Paper Folding off) shows the panel plainly and finishes, so it
  still says it has shown; gone mid-grab, it closes plainly. A ball in flight keeps its own spec, so a theme changing under it
  is no error, and a design switch under a sheet (`Deactivate` hides the panel) stops it the same way.
- **All the text by hand:** three parts of a bag's text are not a Next role, so themes reach them:
  - `Footer.CoinFont` (`NextCoins:Style`): the amounts in the bags' shared money frame, out of the classic theme's hands
    (`Sonata:ClearButtonTextRole`, so a classic theme applied later leaves it), each amount's width reset for its new font
    (a font string keeps the width it was sized to, sonata.md 3c). Default sets it to `Footer` (issue #1226: the bags' gold reads as the vendor's footer does); `false`, the frame's own role.
  - `ItemButton.ItemLevel` and `ItemButton.Countdown` (sonata.md §3a): an item level keeps the color its draw gave it, since a
    style applied for a new pixel grid draws nothing; a countdown's own font is recorded by value and put back.
  - `ItemButton.Count` and `ItemButton.ItemLevel` name Patrick Hand's file, drawn through a font object made for it, never
    set on the text: set on the text, it stayed on every button under every other theme and the classic bags (issue #1263,
    after a preview of this theme; sonata.md §3a).
- **Item buttons' empty slots:** `ItemButton.EmptySlot` draws an empty slot's art (retail's `ItemSlotBackground`; on Classic
  its icon, `SonataElements:EmptySlotArt`), Blizzard's when the style has none.
- **Check** (`SonataNext:Check`): a stop motion's parts, an `FPS` above nothing, a `Spacing` from 0 to under a half; a sheet's
  parts (`NextPaper.KEYS` and its neighbours), `Front`, `Back` and `Rate`, `From`, every number's range, angles in `Half` and
  `Full`, `Poses` ending in 1, `Drift` the least first.
- **Coverage:** `spec/next/stopmotion_spec.lua` (frames and float error, noise, tweens: holding, spacing, never past the end,
  ending exactly, delays, `smooth`, slow frames, a theme going), `spec/render/motion_spec.lua` (poses held, wobble, the end
  exact), `spec/next/paper_spec.lua` (the layer; each fold's places, faces and shading; the note, edges and shadows; mirroring;
  wobble, each corner its own and no tearing; poses drawn once; Reveal; pools and pictures; grabbing, Warp's every part, facets,
  the toss and leaving the screen; printed items), `spec/next/theme_panel_spec.lua` ("a sheet of paper (Panel.Paper)": on the
  real panels, unseen until flat, stopping every way, its theme going, the shake, what it prints at a scale),
  `spec/next/ornaments_spec.lua` (`Frames`, `Boil`, `Locales`), `spec/next/sparkles_spec.lua`, `spec/next/chain_spec.lua`,
  `spec/next/content_spec.lua`, `spec/next/currency_spec.lua`, `spec/next/settings/reorder_spec.lua` (each a pose at a time),
  `spec/next/coins_spec.lua`, `spec/sonata/elements_spec.lua`, `spec/frames/item_spec.lua`, `spec/next/guildbutton_spec.lua`
  (the text), `spec/sonata/next_engine_spec.lua` (Check, the switches), `spec/sonata/next_themes_spec.lua` ("Papercraft": its
  fonts, licenses and art on disk), and `spec/integration/papercraft_spec.lua` on the whole addon (the money through classic
  themes, the item buttons' counts and item levels after a preview, another theme and the classic bags, a real bag unfolding
  and crumpling twice, Paper Folding off, the design switching under a sheet).
- Mutation-tested: 96 mutations of the stop motion, the sheet, the panel's hooks, the switches and the text. 32 first
  survived: most showed the first tests proved the animation ran rather than what it drew (the toss's side, the paper's back
  on a turned face, each of Warp's parts, a shake fading, poses drawn once), and led to tests; two were code that could not
  matter, removed (a tween's lower clamp, a second Release's guard: its lists are empty by then). On the rerun every one of
  the 95 left was caught.
- **Failure mode (fixed, reported in game, with screenshots):** every pencilled field and button in the settings window (the
  search box, dropdowns, a slider's number box, Done) smeared past its edges and crossed over itself, an X on a narrow box. The
  theme's `outlined` gave the fill a `Size`; `NextFill` reads each cap's own, so the caps got a width of 0, and a texture with
  no width appears to draw at its file's: a 12-pixel sliver of `button.png` stretched 128 units, the two caps overlapping when
  the box was narrower than both (measured from the screenshot: the art about 217 pixels across a box about 48 wide; inferred
  for the client, which no API documents). The mock reports no width as 0 and draws nothing, so nothing failed, and the renders
  reviewed before shipping showed the bags and not the settings window. Now `Check` names a cap drawn from a file with no length
  on every theme, and `layout.ArtWithNoSize` (spec/helpers/layout.lua) fails on shown art with no size: in the settings window
  under every shipped theme (`spec/next/shipped_themes_spec.lua`) and on every page and tab and the bags under Papercraft
  (`spec/integration/papercraft_spec.lua`).
- **Seen in game once (the settings window, the report above); the rest not yet.** To check: a bag opening and closing at full size and small, chained both ways, a bank
  open (a capture: does its panel say it has shown under the 1 second?), the paper layer over other windows, `SetVertexOffset`
  on Classic, the fonts at the UI scales the pixel rules cover, cooldown numbers (whether the client keeps a countdown's font),
  the cost of a crumple (a profiler capture: `NextPaperRun.DrawCrumple`), and `/console taintLog 1`.
