---
paths:
  - "next/beam.lua"
  - "sonata/themes/next/makeitso.lua"
  - "spec/next/beam_spec.lua"
  - "tools/textures/next_makeitso.py"
  - "tools/textures/next_masks.py"
---
## 24. The Make It So theme's engine (`next/beam.lua`, ornaments' `Flash`)

What the Make It So theme (next-themes-shipped.md §8) needed of the engine, all of it data a theme gives.

- **Beaming in and out** (`Panel.Beam`, NextBeam, driven by the panel: `beamIn` from `moveIn` after a glitch, a shatter
  and smoke; `beamOut` from `Hide` after a glitch, a shatter and bats; `endShatter` ending both, as it ends theirs).
  - **A run** (`NextBeam:Begin(panel, phase)`, `"Open"` a beam down, `"Close"` a beam up) lays its parts on the beam
    layer (a frame over the screen in the DIALOG strata, level 15, above every panel, taking no mouse) over the body's
    rect (`panel:BodyRect`, at the panel's scale), unseen until it draws:
    - **Sparkles** (required): `Density` of them to every 100 x 100 units of the body (counted in the body's own units,
      so a scaled panel shows as many, smaller), across it and `Spread` past its sides, down it; each a texture
      (`OVERLAY`) in a colour of `Colors`, its size between `Size`, its strength between `Alpha` (a range, or one
      number), drifting up or down (half each way) at between `Drift` round the body (wrapping from top to bottom), and
      twinkling `Twinkle` times a second from a phase of its own: `((1 + sin(2 pi f t + phase)) / 2) ^ Sharpness` of its
      strength, `Sharpness` making the flashes brief; swelling from half its size to its size as it flashes, drawn out
      `Stretch` times as tall as wide. All scaled by the panel's scale.
    - **Column** (optional): a texture (`ARTWORK` 0) over the body and `Spread` past its sides, in `Color`, at `Alpha`,
      shimmering (`Shimmer`: `{ how deep, 0 to 1; how fast, swings a second }`: `1 - depth + depth * (0.5 + 0.5 sin)`
      of its strength) and its art flowing up `Scroll` of its height a second (its texture coordinates; the art loaded
      with the REPEAT wrap mode down its length, not tiled by the client).
    - **Glow** (optional): a texture (`ARTWORK` 1) over the body, in `Color`, at `Alpha`: the bag lit as it
      materializes.
  - **Envelopes:** each part grows in and out over an envelope of its phase, `{ in, full, out, gone }` seconds:
    `smoothstep(in, full, t) * (1 - smoothstep(out, gone, t))`; a part its phase gives no envelope stays dark.
  - **The panel's part:** a beam down (`Open`) shows the panel under it over `Reveal` (`{ from, to }`, smoothstep): it
    has materialized at `Reveal`'s end (`OpenTime`, `OpenLock`), says it has shown, and its threads draw in and its
    sections cascade from then. A beam up (`Close`) fades it over `Fade` (`CloseTime`, its end): then it hides (`Hide`'s
    end), and its threads unravel over that time. Either way the run lingers on its own (`Linger`, on the beam layer's
    driver) until its last part has gone out (`ClearTime(phase)`: the latest envelope's end; none without one), then
    gives its textures back; the driver stops with the last. `Init` gives back whatever lingers (`core/init.lua` starts
    it with the smoke's and the bats'). The theme going mid-beam shows the panel plainly (and a beam up closes it
    plainly at its end), its run given back; Escape mid-beam ends it at rest.
  - **What it covers** (`NextBeam:Reach`): the body and `Margin` past it evenly all round, at the panel's scale. Asked:
    "make sure it covers the window + it's decoration fully, it's a bit too small on all sides", then, of a version that
    also reached past the tabs on the inner side, "it's too far to the left (leave tabs out) and not enough on the
    right": the tabs are left out, the margin is even.
  - **Its ends** (`Ends`; asked: "the top and bottom beam are cut off extremely clean on the horizontal plane, almost
    like it's clipped at the top and bottom"): it runs `Ends` past the top and bottom of what it covers. The column and
    the glow reach that far; the column fades out to nothing over each end through two masks (`beam.END_MASKS`,
    `textures/next/beam_end_top.png` and `beam_end_bottom.png`: nothing at the end each is for, all at the other,
    smoothstep between; each over its end of the column, `Ends` tall, the column's own art left to scroll; two images,
    since a mask cannot be turned over by its coordinates, below), given back to their pool off the column when the run
    is (a texture used again for a fleck is never cut). The flecks are scattered over the ends too,
    as dense, drift round the whole length, and fade over the ends as the column does
    (`smoothstep(bottom, bottom + ends, y) * (1 - smoothstep(top - ends, top, y))`). The glow's art softens over its
    outer fifth. Without `Ends` nothing changes.
- **A body's rounded corners** (`Panel.Corners`; reported with a screenshot: "corner at the top left and bottom left
  peak out around the LCARS, i think we need a way to shape the window itself"): by side (`TOPINNER`, `TOPOUTER`,
  `BOTTOMINNER`, `BOTTOMOUTER`, as ornaments name corners, next-themes-ornaments.md §12), each a radius. On a small panel (`shapeCorners`, from
  `ApplyGeometry`, which every styling of the body is followed by), a mask at each rounded corner of the body, the
  radius twice across, that corner's own image (`textures/next/corner_topleft.png`, `corner_topright.png`,
  `corner_bottomleft.png`, `corner_bottomright.png`: cut round at that corner, opaque elsewhere; the inner and outer
  corners swap sides on a panel whose inner side is on the right), cuts what is drawn across the body: its fill, its
  wash, its edges, the side rail's strip and the glow a drop lights. It is wrapped white outside its rect
  (`CLAMPTOWHITE`); its halves away from its corner are opaque, so a wrap that clamps to its edge would cut nothing more
  either. A full panel's corners stay square (it stands against the screen's top and bottom beside its feathered edge).
  Ornaments are not cut: a theme draws them to fit (the elbows' outer corners are rounded as much).
  - **Two rules of the client's masks**, both found the hard way (reported in game: "lower left corner not masked. top
    left is perfect though"), and both now in the spec mock (`spec/helpers/wow_mocks.lua`):
    - **A mask's texture coordinates are ignored.** The first version drew one image and flipped it for each corner
      with `SetTexCoord`: only the top left, which needs no flip, was cut. lightspark tested it when masks came in (7.2,
      WoWInterface, "MaskTexture : new widget for 7.2": "SetTexCoord had no effect on mask texture"), and Blizzard's UI
      never sets coordinates on one. Every orientation is an image of its own; the masked texture's own coordinates are
      not affected (TheDanW, Blizzard, #wowuidev 2017-01-18: masks "won't wreak havoc on texcoords you set"), so the
      beam's column still scrolls.
    - **A texture takes at most 3 masks**; a fourth is an error ("Texture:AddMaskTexture(): Texture already has the
      maximum number of mask textures (3)", quoted in EllesmereUI's pull request 2594; "a texture can be masked by up
      to 3 mask textures", TheDanW, the same day). The body's fill spans every corner, so at most `MAX_CORNERS` (3) are
      rounded, in the order `TOPINNER`, `BOTTOMINNER`, `TOPOUTER`, `BOTTOMOUTER`, the rest left square; Check names a
      theme that rounds four. The masks a theme no longer rounds come off every part before any new one goes on, and a
      mask already on its parts is not added again (`applied`), so no part is ever asked for a fourth. The restyle had
      rounded all four corners of Make It So; its fill refused the fourth.
  **Not verified in game:** `CLAMPTOWHITE` on a mask texture (the client's UI schema lists it, `UI.xsd` `WRAPMODE`;
  Blizzard's own masks use `CLAMPTOBLACKADDITIVE`, never it), which the art makes not matter; and whether the client
  counts the same mask added twice to a texture toward its three (`applied` makes sure it is never asked).
- **A section's row art shorter than its row** (`Sections.Header.Height`, from the row's top; reported: the section's
  title "is overlaping with the first icon row"): the art no longer fills the header to the first row of icons.
- **Ornament motion** `Flash` (next-themes-ornaments.md §12), the comm badge's chirp.
- **Check** names each part a beam does not have (and each of its phase's parts: `Reveal` only in an `Open`, `Fade`
  only in a `Close`, each required there, two numbers in order), what its runtime needs (`Sparkles`, and their
  `Density`, more than nothing; `Stretch` and `Sharpness` more than nothing; `Spread` no less; `Size` required, and
  `Twinkle`, `Drift` and `Alpha` (when a range) as two numbers in order; a column's `Spread` no less, `Shimmer` its
  depth from 0 to 1 and its speed no less than nothing, `Scroll` a number), every envelope four numbers in order, none
  below 0; `Margin` and `Ends` no less than nothing; its colours through the usual walk. A corner that is no side
  (`TOPLEFT` is not one) or a radius below nothing; a section's art `Height` not more than nothing. And a flash's `Every` (required, in order), `Time` more than nothing,
  `First` no less, and its parts.
- **The switch** Transporter (next-themes-animation.md §20); Snow and Leaves became Snow, Leaves and Stars (the warp stars fall through the snow
  engine).
- **Not measured in game:** the beam's cost. A full panel's beam lays about 130 flecks (510 x 1000 units at a density of
  2.6), each placed, sized and faded every frame for about 1.15 s, and two large textures over the body.
- **Coverage:** `spec/next/beam_spec.lua` (opening only with an Open and closing only with a Close, the times; the
  layer; flecks by their density across the body and past its sides, unseen until drawn, their colours, rippling both
  ways; each twinkling, swelling, drawn out, drifting round the body, in and out over its envelope, nothing before or
  after it; the column over the body and past its sides, loaded repeating, shimmering and flowing; the glow over the
  body, dark before its envelope; the panel shown over its Reveal, faded over its Fade by the Close's own envelopes;
  only sparkles without a column or glow; the panel's scale; lingering where the panel left it until the last part has
  gone out, the driver stopped; pools, and `Init` letting go of what lingers; a margin evenly all round with its tabs
  left out, on either side and at a scale; "its ends": the column and glow past them, the two masks, given back with
  the column, flecks over the ends as dense and faded there, at a scale), `spec/next/content_spec.lua` (a section's row
  art its own height), `spec/next/theme_panel_spec.lua` ("a body with rounded corners": masks on a small backpack and
  the mirrored bank, none on a full panel, taken off when a theme leaves a corner square; each corner its own image, the
  lower left the lower left's; at most three, in order; one theme's corners off before the next one's go on), `spec/next/ornaments_spec.lua` (a flash:
  unseen at rest, its first after `First`, up to its alpha and out over `Time`, the next after `Every`, out once still
  and `First` again; without `First`, a whole `Every`), `spec/next/theme_panel_spec.lua` ("a transporter's beam": on the
  real backpack, beaming down in place, materializing under the shimmer and saying it has shown, the shimmer going out
  on its own after; its threads and sections waiting; Escape and the theme going mid-beam; beaming up where it stands,
  gone at its Fade's end, the shimmer lingering; its threads unravelling over it; the theme going as it beams up;
  sliding without a beam. "the Make It So theme's LCARS frame", on a screen where a unit is a pixel: the badge over the
  close button, centered on it, 4 past it on every side, inside the body, on the backpack and the mirrored bank; the buttons down the side bar under the elbow,
  each block the bar's width, 4 apart; the title and search box clear of the side bar, the top bar and the badge; the
  footer's text above the bottom bar; no piece along the top or bottom running into another, full and as narrow as a
  small bag goes), `spec/sonata/next_engine_spec.lua` (Check of a beam and of a flash; the switch; Moving Ornaments taking
  a flashing piece out), `spec/sonata/next_themes_spec.lua` ("Make It So": the font, its license and locales, the art,
  the beam's timing and colour, the side bar's blocks, the comm badge centered on the pin and its chirp after the beam,
  the holodeck and the warp stars; the restyle: soft colours, section names in peach on glass above the icons, glass
  tabs and a solid chosen one, the body and side bar translucent, its inner corners rounded and a clean Check, the beam's margin
  and ends), `spec/core/init_spec.lua` (started), the settings specs (the
  switch, its row, its title; Snow, Leaves and Stars), `spec/core/constants_spec.lua` (every switch on by default), and
  every shipped-theme spec with it (`shipped_themes_spec`, `pixel_perfect_spec`). Mutation-tested: 65 mutations of the
  beam, the flash, the panel's wiring, Check, the switch, its default and its start. Six first survived: four led to
  sharper tests (a fleck's Spread at the panel's scale, each fleck's own twinkle phase, drifting round the body, the
  switch on by default), one to a test of an envelope of five numbers, and one showed code that changed nothing (a
  run's clear time starting from the panel's part), simplified. Every one now caught. The feedback round (the beam's
  reach and ends and their masks, the rounded corners, a section's art height, their Check): 30 mutations, 29 caught at
  once; the survivor showed code that changed nothing (shaping the corners from `styleBody`, which `ApplyGeometry`
  always follows), removed. The masks' two client rules (an image per corner and per beam end, at most three masks):
  9 mutations, 8 caught; the survivor (adding a mask already on a part again) cannot be told apart in the mock, which
  ignores a repeated add, as the client may; it is kept so the client is never asked.
