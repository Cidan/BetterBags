---
paths:
  - "next/glass.lua"
  - "next/sheen.lua"
  - "sonata/themes/next/rainywindow.lua"
  - "spec/next/glass_spec.lua"
  - "spec/next/sheen_spec.lua"
  - "textures/next/rain/*.png"
  - "tools/textures/next_rain.py"
---
## 26. The Rainy Window theme's engine (`next/glass.lua`, `next/sheen.lua`)

What the Rainy Window theme (next-themes-shipped.md §8) needed of the engine, all of it data a theme gives. Asked, of a
throwaway tech demo of fake glass (branch `glass-demo`): "that rainy glass pane was... chefs kiss. clarity might be a
problem though (transparent bag)"; agreed: smoked glass, "let's let people adjust the tint strength", and for opening and
closing, "let's have fun with that".

There is no shader. Glass is three blend modes and a light worked out in Lua:
- **MOD** multiplies the world behind by a color: it darkens and never brightens, so nothing bright behind a bag can wash
  its items out. This is what makes a see-through bag readable; a BLEND veil alone cannot, it only lowers contrast.
- **BLEND** toward a light color: the glass scattering light, lifting the darks and flattening the world's detail.
- **ADD**: light the glass passes on or reflects. Every ADD part's alpha comes from where it is against the light.

A texture's alpha is its vertex color's (next-themes.md §10): every part is colored first and given its alpha after, and
a MOD texture's strength is in its color (lerped toward white), never its alpha: whether the client lets a MOD texture's
alpha (or its frame's) weaken it is not known, and nothing relies on it.

### Glass on a panel (`Panel.Glass`, NextGlass, a set per panel like NextSnow's)

- **Where:** the panel frame's own textures, under its tabs and content (child frames). The tint, veil and grain hang
  from the panel's `fill` (`SetAllPoints(panel.fill)`, BACKGROUND 1 to 3), so they reach past the screen edge with it
  while docked; the reflections, the lamp and the flash hang from the `body` (BORDER 2, 2, 5); rim pieces and drops are on
  the frame by its top left (BORDER 4 and 3, the snow's sublevel). The theme's `Panel.Fill` is a clear color: the glass is
  the fill.
- **Tint** (`Color`, `Strength` 0 to 1, `Veil` = `Color`, `Alpha`): MOD in `1 - Strength * (1 - Color)`, the veil's
  alpha `Veil.Alpha * Strength`. `NextGlass:Tint()` hands it out (clear without one).
- **Presence** (`set:SetPresence(p)`, 1 at rest): the tint lerped further toward clear and the veil's alpha times `p`.
  NextSheen's open and close set it with the panel's alpha each frame, so the smoke fades with the panel whatever the
  client does with a MOD texture's alpha; `endShatter` (every way an open or close ends or is cut short) puts it back to
  1. `Retint` keeps it.
- **Grain** (`Texture`, `Color`, `Alpha`, `BlendMode`, `Size`): tiled over the body, a tile every `Size` units.
- **Reflections** (`Texture`, `Color`, `Alpha`, `BlendMode`, `Angle`, `Period`, `Parallax`): one texture over the body,
  its art (a band profile repeating across) mapped by `SetTexCoord`'s eight numbers turned to `Angle`, a period every
  `Period` units, shifted by `Parallax` of the frame's place on the screen. The body's rect cuts the bands, and they hold
  `Parallax` of the way still on the screen while the bag moves (a room's reflection holds still as a pane slides).
  Laid again whenever the frame's left or top changes. Asked, of a first art (four bands a period of 420): "very nice,
  but... also repeating a bit too much": the art is now uneven groups of bands across 1024 texels and the period 1600
  units, once a screen or more.
- **Lamp** (`Texture`, `Color`, `Alpha`, `BlendMode`, `Size`, `Reach`): the pointer. A texture over the body whose art's
  coordinates centre a `Size`-wide light on the pointer, loaded `CLAMPTOBLACKADDITIVE` (Blizzard's own on a Texture,
  `Blizzard_Wardrobe.xml`), so nothing is drawn past the art and the body's edges cut it; full while the pointer is on the
  body, fading out to nothing `Reach` off it. `lampAt` (a Gaussian of `Reach`) lights the rim and the drops.
- **Rim** (`Color`, `Alpha` = { faintest, strongest }, `Size`, `Piece`): the body's four edges cut into pieces about
  `Piece` long on whole pixels (found by the pixel checks: pieces cut at fractions of a unit), each at
  `faintest + (strongest - faintest) * (lamp * facing + flash)`, `facing` 0.6 to 1 by how squarely the edge faces the
  pointer.
- **Rain** (`Texture`, `Color`, `Alpha`, `Density`, `Size`, `Appear`, `Highlight`, `Caustic`, `Runners`): `Density` drops
  to every 100 x 100 units of the body, counted in `Layout` (a panel styles its glass as it is built, before it has a
  size; found in the panel spec: none were made), smaller far more often than larger. Each drop is three textures: its
  body (the drop art, its own darks), its highlight on the side toward the light, and its caustic, the light it focuses,
  on the far side; the light is the lamp, else the sky above. As the panel shows (`Start`) every drop beads up in its own
  turn somewhere in `Appear` seconds, growing and fading in over 0.3 s (at once without `Appear`). `Runners` (`Count`,
  `Size`, `Speed`, `Wait`, `Slide`, `Catch`, `Every`, `Beads`, `BeadSize`, `BeadLife`) wait `Wait` in the upper half, then
  slide (`Speed`, for `Slide`) and catch (`Catch`) in turn, a bead left every `Every` units; each swells into sight over
  about 0.7 s whether waiting or already running (a short `Wait` once ran down part faded, or with none unseen). A runner
  fades out as its foot nears the body's and starts again there, and no bead is left past the foot (found in review: a
  small bag's runners slid on out below it, leaving beads over the world); in combat it waits, unseen, until combat ends.
  Beads dry over the last 40% of `BeadLife` (a pool of `Beads`, reused oldest first).
- **A body that changes size** while the glass shows (`Layout`): drops made for a bigger body bead up in their own turn
  (`Appear`), as those it showed with did, even after those have all beaded up; what a smaller one leaves outside it
  (a foot past its foot, or off its sides) goes: runners start again on it and are drawn there at once, or in combat wait
  unseen as at the body's foot; beads dry at once (found in review: drops came in at full; beads and waiting runners
  stayed drawn over the world; and in the third, drops made late never beaded up, runners started again in combat and
  were drawn where they had been until the next frame).
- **Lightning** (`Every`, `Time`, `Color`, `Alpha`): a flash over the body every `Every` seconds, a strike and a weaker
  one over `Time`, lighting the drops and the rim; none in combat (due again `Every` later).
- **Driver:** a child of the panel frame, running while the panel shows and the theme has glass (`Start`, `Stop` from
  the panel's `startEffects` and `OnHidden`). Each frame it lays the glass out again if the body is another size or
  place on the frame than it was laid out for (`resized`: a small panel sized by a grip, fitted or snapped does not lay
  its geometry out again, and a hook on the frame's `OnSizeChanged` made while the panel is built is replaced by the
  panel's own `SetScript` in `Watch`; found in review: rim lines and drops left over the world outside a resized bag);
  `Start` does the same. It reads the pointer and redraws what the light falls on only when the pointer moved near the
  body (or left it), the frame moved, or a flash changed; drops beading up, runners and beads every frame.
- **A theme without glass** on a showing panel stops nothing for good: `Style` starts the set again (no driver without
  glass), so a glass theme applied again moves at once (found in review: a theme previewed in the theme pane, then left,
  froze the glass until the bag was closed and opened).
- **Retint:** `NextGlass:Retint()` paints every panel's tint and veil again (a weak set of every glass), and nothing
  else.
- **Moving parts:** every drop's textures (the pixel checks leave them out).

### The sheen (`Panel.Sheen`, NextSheen, a run per open or close on its own layer, like NextBeam's)

First a fog wiped off as a bag opened and a wash of falling columns as it closed; asked: "kind of lame -- something
more... elegant?"; agreed: the light a sheet of glass catches as it turns toward you.

- **The layer:** a frame over the screen in the DIALOG strata, taking no mouse, with a driver that lets a run linger
  after the panel's part. Pooled textures, drawn without the client's sharpening. Started by `core/init.lua`
  (`NextSheen:Init`, after NextPaper).
- **Band** (`Texture`, `Color`, `Alpha`, `BlendMode`, `Width`, `Angle`): one texture over the body, its art (a soft glow,
  a bright core and a hairline, nothing at its ends) laid across the body by its coordinates, loaded
  `CLAMPTOBLACKADDITIVE`, so the body's edges cut it and nothing repeats. It travels from the panel's inner side out,
  `Angle` degrees downhill (mirrored on a panel on the left of the screen), from wholly before the body's nearest corner
  to wholly past its farthest over its phase's `Time`, eased in and out; closing, it travels back the other way.
- **Glow** (`Color`, `Alpha`, `BlendMode`): the pane lit faintly as the band crosses, most at the middle of its way.
- **Open** (`Time`, `Reveal`): the panel opens where it rests, fading in (and its glass's presence with it) over
  `Reveal`; `OpenLock` and `OpenTime` are `Reveal` (the threads draw in and the sections cascade from then, and it says
  it has shown); the band crosses on by itself until `Time` (`Linger`). The Rainy Window shows in 0.32 s: a bank waits at
  most 1 s for its panel.
- **Close** (`Time`, `Fade`): the panel fades out (its glass with it) over `Fade` (`CloseTime`), then hides where it
  stood; the band crosses on until `Time`.
- **Turned back part way:** opened again as it closes, or closed as it opens, a panel goes on from as far in as its sheen
  had shown it (`OpenAt(alpha)`, `CloseAt(alpha)`: the time whose fade gives that alpha, the inverse of the smoothstep),
  its tween from there to the end (found in review: the bag key pressed twice jumped it to full, or to nothing, and faded
  from there). The alpha is the panel's `sheenShown`, what its sheen last drew, set by each open's and close's update
  and cleared as either ends or is stopped; never the frame's own alpha, which other code sets (a companion held for its
  anchor waits at full out of sight, a small panel is given its slide's alpha as it is fitted; found in the second
  review: both came in at full). Any open but one turned back starts from nothing; a close with no sheen before it from
  the frame's alpha.
- **Closed unseen:** a close from an alpha of nothing (closed the moment it opened, a chained bag in its stagger) has no
  band, and keeps the panel unseen until it hides (the open it replaces puts it back at full as it stops); found in the
  second review: the band's second half played over nothing. Any other close's band and glow are as strong as the bag
  was (`Begin`'s `strength`; found in the third: two presses 33 ms apart played the band at full over a bag about to
  vanish, a cliff at the 0.01 cutoff that moved with the frame rate). Its run is begun in its tween's first update, and
  again if its theme goes and comes back as it fades (found in the third: held still at its starting alpha, bandless).
- **One band a panel:** `Begin` gives back the band a panel's last run still has crossing (found in the second review: a
  bag closed as its open's band crossed showed two, going opposite ways); other panels' go on.
- **Cut short or its theme gone:** the panel's own tween, as Beam's: a flight, a placement or Escape ends it at rest
  (`endShatter`: alpha and presence 1); its theme going mid-open or mid-close shows the panel plainly.

### The player's parts

- **Glass Tint** (`nextGlassTint`, Appearance > Theme, a section shown only while the theme in use or previewed has
  `Panel.Glass.Tint`: on any other it would do nothing): saved per profile in percent (`DB:GetNextGlassTint`, 60 until set,
  whole, 0 to 100). `SonataNext:effective` lays it over the theme's `Strength` (reading it only for a glass theme), and
  `next/GlassTintChanged` (sent on every step of a dragged slider) runs `SonataNext:ApplyGlassTint`, which writes it into
  the theme in use and calls `NextGlass:Retint()`: no theme handed over again, no other widget restyled.
- **Switches** (next-themes-animation.md §20): Rain on Glass (`glassRain`: `Panel.Glass.Rain`), Lightning (`lightning`:
  `Panel.Glass.Lightning`; flashes can be hard on some players' eyes), Glass Sheen (`sheen`: `Panel.Sheen`; the bags slide
  in and out instead). The glass itself is the look, not an animation, and stays.
- **Check** (`SonataNext:Check`): every part's keys (`KEYS`, `TINT_KEYS`, ... in each module), `Strength` and alphas from 0
  to 1, a texture where one is drawn, the `Period`, `Reach`, `Size`, `Piece`, `Every`, band `Width` and times that are
  divided by or stepped in, ranges in order, a lightning `Every` above nothing (due at once it flashes every frame), with
  beads a `BeadSize` and a `BeadLife` above nothing (found in review: none raised every frame, a life of nothing never
  dried), a sheen's band, and its panel's part (`Reveal`, `Fade`) within its `Time`.

### Reviews

The first review (a sub-agent, Prime Directive #2) found four bugs a player could hit, each fixed test-first and named
where it is described above: the glass frozen after a theme previewed without glass; a resized small bag's glass laid
out for its old size; runners sliding out below a small bag and leaving beads there; a bag turned back part way jumping
to full or to nothing. And two only a theme author could hit (beads without a size or life, beads that never dried),
fixed in Check. Left as they are, for the reasons given: drops may hang past the body's edge by up to half their size
(measured: one of sixteen, by 0.08 units); `Rain.Density` has no upper bound in Check (only an author could make
thousands of drops). Out of the change's scope, noted only: `next/snow.lua` hooks `OnSizeChanged` while the panel is built,
and the panel's `Watch` replaces that hook with its own `SetScript`; Alt+Z during any close stops its tween at full alpha.

The second review, aimed at those fixes, found that reading the frame's alpha to turn back an open broke a chained
companion (in at full, before its anchor) and a small bag (its fitting sets its alpha), that a smaller body still left
beads and waiting runners outside it, that drops made for a growing body came in at full, that a bag closed unseen
played a band over nothing, and that a close during its open's band showed two; each fixed test-first as described above.
Left as they are: while a grip, a glide or a morph changes a bag's size the glass is laid out every frame, its rim's
pieces taken and given back (the cost is not measured: a profiler capture would show it, `NextGlassSet.Layout`); drops
past a shrinking body's count are the list's last, wherever they sit; a theme applied while a bag closes beads its drops
up again under the fade.

The third review, aimed at the second's fixes (with 3,000 random actions on the backpack and 7,500 on a chained pair,
checking after each that no alpha was stale, no panel stuck below full, no texture held twice), found no bug at medium
severity or above, and four low ones, fixed test-first as described above: the close band's cliff at the 0.01 cutoff, a
close held still when its theme came back, runners started again outside a smaller body in combat or drawn where they
had been, and drops made late never beading up. It found six of the fixes untested (what each open and close forgets as
it ends, the beading flag, a narrower body, a foot past the body's but not its middle) and one assertion that could not
fail; each now has a test. A fourth review, aimed at the third's fixes, found no bug, and that a close's band could be
drawn at no strength without a test noticing; its strength is now asserted exactly. The fixes of all rounds were run
against 38 mutations; every one is caught.
Out of scope, noted only: closing the backpack during its companion's stagger puts the companion at full where it rests
(`Hold` ends it at rest, as for Beam and Paper); a turned-back open's band begins part way across, by design.

### Not seen in game yet

The sheen and the new reflections. Seen in game (the first pass): the glass, its rain and the reflections' parallax ("very
nice"). To check: whether the client's MOD weakens with a texture's or frame's alpha (the sheen's fade does not rely on
it); how the smoke reads over a snowfield and a dark cave at 60%; the band's width and angle on a full-height bag and a
small one; the open finishing inside a bank's 1 s wait; the cost of a full backpack's glass while the pointer moves over
it (a profiler capture: `NextGlassSet.Step`, `NextGlassSet.relight`, `NextSheenRun.Draw`).

### Coverage

`spec/next/glass_spec.lua` (no glass without one; the tint and veil over the fill at each strength; Retint on every
panel; presence fading the tint and kept by a retint; clear without a tint; the grain; the reflections turned, cut and
held still as the frame moves; the lamp centred on the pointer, clamped, fading off the body; the rim lit near the
pointer; drops by density behind the content, counted once the body has a size and again on a resize; drops beading up
one after another, or at once without Appear; each drop lit from the pointer and the sky; runners swelling, sliding,
catching and leaving beads that dry; starting again, none in combat; lightning lighting drops and edges, none in combat;
parts left out; stopping; moving parts; a new theme; moving on through a theme without glass; laid out again for a body
changed in height or width, as it moves or as it shows; beads dried and runners started again, drawn at once, whose foot
a shorter body or whose place a narrower one leaves outside it, waiting unseen in combat; drops for a growing body
beading up, as their fellows bead up and after; runners faded at the foot, no bead past it even in a hitch; swelling with
a short wait), `spec/next/sheen_spec.lua` (opens and closes only with each, the panel's parts and when the band has
crossed; the layer and the band's art, clamped over the body; the band's way across the body corner by corner, wholly
before and wholly past it; mirrored on the left, back again closing; how far in a panel at an alpha is; one band a panel,
others left; band and glow at a run's strength; the panel's fade in and out; lingering and released), `spec/next/theme_panel_spec.lua` ("glass (Panel.Glass) and its sheen": on the real
backpack, the glass over its fill, its drops under its content, moving only while it shows; the tint and another theme;
fading in in place with its glass, its band lingering; threads once revealed; fading out with its glass, back at full
strength; cut short at full strength; turned back part way, full and small; closed unseen with no band; opened from
nothing after Escape at rest, opening or closing; closed from full with its band after a stopped open; a close's band as
faint as the bag; fading on with its band when its theme comes back; through a theme without glass and back; sliding
without a sheen), `spec/next/chain_spec.lua` (a companion held for the backpack fading
in under its sheen once its turn comes), `spec/next/pixel_perfect_spec.lua` (every
shipped theme on whole pixels, the rim's pieces included), `spec/sonata/next_engine_spec.lua` (the switches, the tint laid
over and taken at once with only the glass redrawn, the messages followed, Check), `spec/sonata/next_themes_spec.lua`
("Rainy Window"), `spec/database_spec.lua`, `spec/core/constants_spec.lua`, `spec/config/settings_effects_spec.lua`,
`spec/next/settings/content_spec.lua` (the switches, Glass Tint only with a glass theme), `spec/core/init_spec.lua`, and
every shipped-theme spec with it.
