---
paths:
  - "next/ornaments.lua"
  - "next/panel.lua"
  - "spec/next/ornaments_spec.lua"
---
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
  - `Point = "BODY"`: over the whole body, `Inset` into it (`Left`, `Right`, `Top`, `Bottom`; `Left` on the inner
    side, mirrored), its art repeating every `Tile` both ways (the Glitch theme's grid and scanlines), else stretched.
  - `Sizes = "Full"` or `"Small"`: shown at that size only (unset: both); a size switch shows and hides them.
  - `Motion`: `Sway` (degrees either way of rest about `Origin`, `BOTTOM` when unset: a full swing every
    `Period`), `Spin` (a turn every `Period` about its middle, 1 clockwise, -1 the other way), `Pulse`
    (`{ from, to }` alpha and back every `Period`), `Bob` (up that far and back every `Period`), `Delay` (where in
    its motion it starts, so pieces do not move in step). `Origin` names one of the piece's points, `INNER` and
    `OUTER` included. `Period` defaults to 4. Two motions run on the set's driver (Lua, a child of the panel's frame,
    only while one shown needs it), added for the Glitch theme (next-themes-glitch.md §21): `Scroll` (`X` units a second toward the outer
    side, `Y` down: a tiled piece's art moving within its tile; the rolling bar), and `Glitch` (`Every` seconds on
    average, from 0.3 to 1.7 of it, the piece glitches for `Hold` seconds, rolled anew every `GLITCH_STEP`, 0.06: a jump
    up to `Jump` units either way across and up or down on whole pixels, half the time a blink to `Blink` of its alpha,
    its art slipped up to `Slip` of a tile; then back at rest; `ornaments.Random` its randomness). A panel hiding mid-
    glitch puts the piece back at rest. Two more, added for the Halloween theme (next-themes-halloween.md §23): `Blink` (after `Every` seconds,
    `{ soonest, latest }`, the piece is shut, drawn at no alpha, for `Time`, 0.12 when unset, then open again; now and
    then, `Twice` of its blinks, it blinks again as soon as it has been open as long as it was shut, never a third time:
    a black cat's eyes) and `Flicker` (its alpha wandering like a candle's, never still, between `Low` of its own and its
    own, toward somewhere new every half to one and a half of a `Speed`'th of a second). Both set only the piece's alpha
    (`fade`), never its place. A panel hiding mid-blink opens it again. One more for the Make It So theme (next-themes-makeitso.md §24): `Flash`
    (a piece that is light, not art at rest: unseen, it waits `First` seconds after the panel shows, else `Every`, `{
    soonest, latest }`, then over `Time`, 0.3 when unset, comes up to its alpha and goes out again, half a sine, and
    waits `Every` for the next; what a step waited past is how far into its flash it is; a panel hiding mid-flash puts it
    out, and it waits its `First` again next time: the comm badge's glint). The Animation switch Moving Ornaments stills
    them all (next-themes-animation.md §20), and takes a piece that only flashes out altogether: held still it would shine for good.
- **Whole pixels** (docs/next-pixel-perfect.md): offsets snapped and sizes rounded on the frame's grid, so a
  piece at rest is on whole pixels. Moving pieces rest nowhere: `panelProto:MovingParts` names them (only those
  shown at the panel's size), so the pixel checks leave them out.
- **A sway eases only where it turns**: three rotations in a repeating group (out of rest to one side, across to
  the other, back through rest), eased `OUT`, `IN_OUT` and `IN`, so the piece passes rest at full speed. **Failure
  mode (fixed, reported in game: "very jerky"):** every step was eased `IN_OUT`, so the last stopped dead at rest
  and the loop began again from a standstill, a halt mid-swing once a cycle (concluded from the animation's
  definition; confirm in game). A pulse or a bob (one animation, `BOUNCE`) eases at its two turns, which is right.
- **The next theme's piece starts at rest.** Pieces are reused by their place in the list, so a theme's ornaments would
  otherwise take what the last theme's motions did to that piece. `Style` clears it (`scrollU`, `scrollV`, `slip`, `jx`, `jy`,
  `blink`). **Failure mode (fixed, reported on Make It So: "this weird texture in the lower left"):** Glitch's scanlines
  scroll, and they are the same piece as Make It So's bottom elbow. How far they had scrolled stayed on the piece through every
  theme after, until a reload: the elbow drew V 0.33 to 1.33, and its art's last row, opaque all the way across, clamped to
  fill what was left, a solid block. `spec/integration/theme_switch_spec.lua` compares Make It So's pieces fresh and after
  every other theme, with their motions run.
- **Motion runs on the client's animation groups** (`Rotation`, `Alpha`, `Translation`, every client): no Lua
  runs while they loop, unlike the sparkles and the cloud. They play while the panel shows (`Show`, and a piece a
  size switch shows while it does) and stop when it hides (`OnHidden`); each motion has one group per piece, made
  once, emptied and rebuilt by every theme (`RemoveAnimations`, every client), started from its phase
  (`Play(reverse, offset)`, every client). A theme applied while the panel shows keeps them moving.
- **Drawn on the panel's frame**, under the body's content (the content is the body's child frames): ornaments sit
  in the body's padding and outside it (over the feather), never over items.
- **Restyled live** with the body (`styleBody`): pieces reused across themes, the ones a theme no longer has
  hidden and stopped; laid out again with the geometry (`ApplyGeometry`).
- **A piece's old spec goes before anything stops it** (`setProto:Style`). A theme's palette names exist only in that
  theme, and stopping a Flicker, Blink, Glitch or Flash puts the piece back at rest by reading its color. **Failure mode
  (fixed, reported in game):** switching away from Make It So with its panel shown raised "the Next theme has no color
  named LcarsLilac", from its flickering top bar, with the new theme's palette already in place. Nothing caught it because
  no spec let a piece's motion run before the switch. Coverage: `spec/next/ornaments_spec.lua` ("restyles for another
  theme a piece caught in its ..."), `spec/integration/theme_switch_spec.lua` (every shipped theme with its effects running,
  on the whole addon).
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
- **`Above = true`** draws a piece on the panel's overlay (next-themes-art.md §15: over the content and a frame drawn above it), as the
  original bags' menu button sat over their border and search box (the Plain theme's bag icon); give it a `Layer` over
  the frame's pieces (`OVERLAY`). A piece keeps its texture, mask and motions on each frame it has been drawn on and
  hides the one it leaves; its mask is made on its own frame.
- **`Panels`** lists the panels a piece shows on (`Backpack`, `Bank`, `Vendor`, `GuildBank`, by the bag kind each
  shows, `const.BAG_KIND`, looked up as the panel lays out); unset, every panel. GW2_UI shows its bag's emblem on
  its bag, bank and guild bank and another on its merchant.
- **`Frames`** draws one of a strip of drawings side by side in the file (the first at rest), and **`Motion.Boil`**
  (`{ FPS, Jiggle }`) draws it again FPS times a second, added for the Papercraft theme (next-themes-papercraft.md §25): another of its drawings, never
  the same one twice running, as a hand-drawn animation's lines shimmer, and up to `Jiggle` units off its place, on whole
  pixels; a slow frame's extra time carries over, so it keeps its rate. It runs on the set's driver; a panel hiding puts the
  piece back at rest, and Moving Ornaments stills it. **`Locales`** lists the client locales a piece shows in (a note
  written in one language). `Check` names `Frames` that are no whole number, `Locales` that are no list, a Boil's parts.
- **Who uses it.** BetterBags' own Guild Wars 2 theme (next-themes-shipped.md §8). Before it BetterBags shipped no ornamented theme. BetterBags - Themes (Sauravisus' addon) gets Next versions of
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
