---
paths:
  - "next/smoke.lua"
  - "next/bats.lua"
  - "sonata/themes/next/halloween.lua"
  - "spec/next/smoke_spec.lua"
  - "spec/next/bats_spec.lua"
  - "tools/textures/next_halloween.py"
---
## 23. The Halloween theme's engine (`next/smoke.lua`, `next/bats.lua`, ornaments' `Blink` and `Flicker`)

What the Halloween theme (next-themes-shipped.md §8) needed of the engine, all of it data a theme gives.

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
- **Ornament motions** `Blink` and `Flicker` (next-themes-ornaments.md §12).
- **Check** names each part a smoke or bats does not have, and what their runtimes need: an opening's `Rise`,
  `Spacing`, `Start`, `Growth` and `Burst` more than nothing, its `Jitter` no less, `FadeIn` from 0 to 1, `Buoyancy` a
  number, `Swirl` two numbers no less than nothing (how far and how often, in no order); a close's `Pieces`, its
  `Shudder`, `Tremble`, `Break`, `Gap`, `Morph`, `Accel` and `Life` no less than nothing, its `Jitter` from 0 to below
  half a cell (corners moved further could cross), its `Dark` a palette color; `FrameRate` and `Stagger` no less,
  `Frames` and `Travel` more; `Puffs` for a smoke that opens, and their `Size`; a spark's `Count`; every range as two
  numbers in order (`Size`, `Alpha`, `Lift`, `Spread`, `Reveal`, `Life`, `Count`, `Speed`, `Delay`, `Band`; `Every`
  required for a flutter); a blink's `Every` and parts, a flicker's `Low` (0 to 1), `Speed` and parts.
- **The switches** Smoke Puff and Bats (next-themes-animation.md §20); Snowfall became Snow and Leaves.
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
