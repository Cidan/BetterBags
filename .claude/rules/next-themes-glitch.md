---
paths:
  - "next/glitch.lua"
  - "next/rain.lua"
  - "sonata/themes/next/glitch.lua"
  - "spec/next/rain_spec.lua"
  - "tools/textures/next_glitch.py"
---
## 21. The Glitch theme's engine (`next/glitch.lua`, `next/rain.lua`, and smaller pieces)

Asked: "a 'glitch' theme, where the bag sort of 'glitches' into existance when opening, glitches out when closing. think
flickers, glitched blinking textures that wobble suddenly and harshly, think green mesh. i want to push the limits of
what's possible here ... you can expand sonata if needed", kept local until it is shown. The theme is next-themes-shipped.md §8's; what it
needed of the engine is here, all of it data a theme gives, none of it the Glitch theme's alone.

- **Glitching in and out, and now and then** (`Panel.Glitch`, NextGlitch, driven by the panel: `glitchIn`, `glitchOut`,
  `burst`, `endGlitch`). With `Open`, a panel opens where it rests instead of sliding in: `PowerOn` seconds of a CRT
  warming up (the `Beam`, `{ Color, Alpha, Height, BlendMode }`, a line across the body's middle opening to its height,
  the panel unseen), then `Time` seconds of moments, one every `Step`, each at a strength falling from 1 to 0: the panel
  jumping up to `Jitter` units sideways (whole pixels) and flickering between `Flicker[1]` and `Flicker[2]` of its alpha
  (lit more often as the strength falls), bands of a frame tearing across the body (`Tears`: `Count` at full strength,
  `Texture`, `Height` range, `Alpha`, `BlendMode`, their art slipped), datamosh blocks (`Blocks`: `Count`, `Texture`,
  `Size` range, `Colors`), static over the body (`Noise`), the title's colour ghosts split up to `Ghosts` units either
  way, its letters corrupted (`Corrupt`: each swapped for one of `Glyphs` at `Chance` times the strength; a letter and a
  glyph are UTF-8 characters; never a title the panel may not read, a secret: a vendor's name in an instance), and a
  third of its sections shoved up to `Sections` units sideways (a Translation animation on the client, which moves what
  is drawn, not where the frame is laid out, so the canvas keeps its layout). With `Close`, it closes where it is:
  `Time` seconds of moments rising in strength, then `PowerOff` of the CRT turning off (squashed to a line, the line
  shrinking to a point), then hidden. With `Bursts` (`Every`, `Time`), a burst now and then while it shows (`Every` on
  average, 0.4 to 1.6 of it): moments rising and falling over `Time`; never in combat, nor while the panel moves, is
  moved or sized, or a section is held (it waits for the next); with the pointer over the panel nothing that takes a
  click moves (no jump, no shove). A chained bag waiting out its entrance delay waits unseen, then glitches in.
  - **The glitch layer**: a frame over the body, 100 levels above the panel's frame (over its content, overlay and
    sparkles), drawn at its own alpha (`SetIgnoreParentAlpha`), so a glitch shows while the panel flickers to nothing;
    it takes no mouse. Everything a moment draws is on it; `NextGlitch:Rest` hides it and puts the panel back (sections,
    ghosts, letters).
  - **Cut short or its theme gone**: whatever replaces or stops the panel's tween (a flight, Escape, a hide) ends the
    glitch at rest (the tween's new `onStop`), back at full strength and in the place it was glitching in or out from
    (`endGlitch(base)`: each glitch its own base), unless another tween has taken the panel over, which places it; every
    hide drops a burst scheduled or under way (a token per schedule). A
    theme applied without a glitch (another theme, Glitch Effects off) mid-glitch: the opening shows the panel plainly
    and finishes (it still says it has shown), a burst or a closing goes on at rest (`Roll` and `Beam` rest the panel
    and do nothing without `Panel.Glitch`), and a theme with bursts applied while it shows schedules them (its
    `ApplyStyle`). **Failure mode (fixed before it shipped, found by reading the burst's code):** every moment read
    `Panel.Glitch` anew, so a theme applied mid-glitch errored every frame of the rest of it (`attempt to index local
    'G' (a nil value)`); the spec reproduced it before the fix.
  - **Bursts yield** to whatever else places the panel: none starts, and one under way stops at rest, while the
    player moves or sizes it, it switches size or glides to one (`placedElsewhere`), or once something else has placed
    it (its offset is no longer the one the burst wrote); a burst never changes a panel's alpha (setOffset fades a small
    panel by its distance). A theme with fewer ghosts in use when a glitch ends (before the panel restyled) is no error
    (`PlaceGhosts`).
  - **No dot before the beam**: the beam draws nothing while it is no line yet (a chained bag waiting out its delay).
  - **Its art repeats**: tears, blocks and static are loaded with the `REPEAT` wrap mode both ways, their coordinates
    running past their art (loaded clamped, the client stretches the art's edge texels over the rest); and every
    texture of the layer is drawn without the client's sharpening as it is made (texture-sharpening.md).
  - **A parent hiding the panel** (Alt+Z hides UIParent) runs its OnHide, which stops everything that moves: when the
    parent shows it again (its own flag still set at the hide, `hiddenByParent`), its sparkles, ornaments, rain,
    shimmer and bursts start again (`startEffects`, shared with `Show`).
  - **Photosensitivity**: a glitch flickers the whole panel (every `Step`, 0.06 s in the theme, for well under a second;
    bursts every 14 s on average, never below 0.3 of its alpha). That is above the 3 flashes a second WCAG 2.3.1 allows
    for a large area. Appearance > Animation > Glitch Effects (next-themes-animation.md §20) turns it off, and with it every ornament's glitch (the
    HUD brackets' blinking twitch; their other motion is Moving Ornaments').
- **Title ghosts** (`Header.Title.Ghosts`): copies of the title in other font roles (cyan and magenta), under it on the
  overlay, `X` and `Y` from it at `Alpha`, hung from the body by the title's own numbers (never from the title, a
  text), given the title's text and the width and wrapping `FitTitle` gave it (`titleCut`, none when it is not cut
  short); a glitch spreads them. Corrupted letters leave a title with escape sequences (`|`) as it is.
  - **Failure mode (fixed before it shipped, found by the adversarial review):** the ghosts were given the title's width
    read back from the title. A vendor's name in an instance is a secret, its width then too, and `SetWidth` takes no
    secret from addon code (`SecretArguments = "AllowedWhenUntainted"`, SimpleScriptRegionResizingAPIDocumentation):
    with the Glitch theme the vendor never opened in a dungeon. The specs' mock took secrets in `SetWidth`, `SetHeight`,
    `SetSize` and `SetPoint`; it now refuses them as the client does, and the vendor's secret-name test runs every
    shipped theme (it named five).
- **The data rain** (`Panel.Rain`, NextRain, `next/rain.lua`): a list of entries, each `Where` (`"Feather"`: down the
  feather beside the body's inner side, a full panel's only, `Layout.Feather` wide; `"Body"`: across the body, behind
  the content), `Font` (the trail's role) and `HeadFont` (the head's), `Glyphs` (a string, read as UTF-8 characters),
  `Spacing` (units between columns; as many as fit, centered), `Speed` (rows a second) and `Trail` (glyphs behind the
  head) as `{ least, most }`, each column's own at random, `Alpha` (the head's; the trail fades from it), `Swap`
  (glyphs changed a second in each column). A cell is its font's height square, on whole pixels of the panel's grid.
  - Each column is a ring of font strings as long as its longest trail: the head writes a new glyph in every row it
    reaches, the glyph at the end of the trail becoming the new head, so the glyphs written stay in their cells and a
    column costs its trail, never the panel's height. A slow frame writes every row it passed. Once its trail has
    fallen past the bottom it starts again above the top (up to half the panel's height above), with a new speed and
    trail; in combat none starts again (the rain thins out and stops, as sparkles do).
  - **Only what changed**: a column's glyphs are drawn again only when it passed a row; a layout places again only
    columns whose cells moved and draws again only those whose rows changed (a resize lays it out on each of its
    frames). Found by the adversarial review: every frame redrew every glyph (about 440 calls a frame on a full backpack
    for the two glyphs that moved). Not measured in game.
  - On the panel's own frame (`BORDER` 2: over the fill, feather, wash and a small panel's edge; under every child
    frame: tabs, content). Laid out by the panel's geometry and the frame's `OnSizeChanged` (a grip, a size switch);
    falls only while the panel shows (its driver is a child of the panel's frame, started on show, stopped as it
    hides); a theme restyles it (`Style`), falling on through a theme with rain. Its glyphs are moving parts: the
    pixel checks leave them out.
- **Smaller pieces**: the `flicker` ease (`NextTween.Ease`: eight steps, each dim, below 0.3, or lit, 0.75 and up, lit
  more often as it goes, lit from 0.75 on; a hash of the step, so the same time gives the same value; the theme's
  sections flicker into place with it); a tween's `onStop` (it ends without reaching its end: stopped, or replaced by
  another of its key); a font role's `Locales` (next-themes.md §3: the fonts cover Latin alphabets only, so the other locales draw the
  client's own); `Sparkles.Upright` (never turned: square pixels); tab edges (next-themes.md §3, `Tabs.Edge`, `SelectedEdge`); the
  ornaments' `BODY` point and `Scroll` and `Glitch` motions (next-themes-ornaments.md §12).
- **Check** (`SonataNext:Check`): a glitch's parts (`NextGlitch.KEYS`), `Open`, `Close` and `Bursts` tables with their
  `Time`, a `Step` with any of them, `Bursts.Every`, `Flicker` two numbers, `Corrupt.Glyphs` some glyphs; a rain
  entry's parts (`NextRain.KEYS`), `Where`, its `Glyphs`, its `Font` and `HeadFont` roles, a `Spacing` above nothing,
  `Speed` and `Trail` two numbers, none below 0, the least first; an ornament's `Motion.Glitch` and `Motion.Scroll`
  tables, their parts and keys. The adversarial review found data Check took that the runtime cannot run (no `Step`:
  an error every moment; no `Bursts.Every`: an error as the panel finished showing, so a bank never loaded until its
  timeout; a `Spacing` of 0: columns without end).
- **Art and fonts**: `tools/textures/next_glitch.py` (standard-library Python, like `next_glow.py`) makes
  `textures/next/glitch/*.png`: a grid, the wireframe floor, scanlines, a rolling bar, a vignette, static, datamosh
  blocks, colour-split tears, a HUD bracket, a dash. `fonts/glitch`: VT323 and Share Tech Mono with their SIL Open Font
  License files (measured with fontTools: VT323 has all of basic Latin and Latin-1 and 127 of Latin Extended-A's 128;
  Share Tech Mono basic Latin and Latin-1; neither has Cyrillic, Hangul or CJK). What the rain writes and the title is corrupted with is ASCII, which every
  client's fonts have.
- **Coverage**: `spec/next/rain_spec.lua` (columns down the feather on either side and across the body, centered, a
  small panel's feather dry, the head's and the trail's fonts and fading, glyphs kept in their cells, a slow frame,
  trails shorter than the longest, starting again from above and not in combat, swaps, characters, size changes,
  started and stopped, a theme with and without, moving parts), `spec/next/theme_panel_spec.lua` ("glitching
  (Panel.Glitch)": opening, flicker and jumps, tears, static, ghosts and corruption by strength, secrets, characters,
  shoves, closing, cut short, bursts and their rules, its theme gone mid-glitch three ways and coming back; the Glitch
  theme's four brackets inside the body, as far in from each corner: a bottom corner's piece goes in with a Y up, as
  `Y` is down whatever the corner, next-themes-ornaments.md §12; reported in game, the bottom two sat outside; "data rain
  (Panel.Rain)" on the real panels), `spec/next/ornaments_spec.lua` (BODY, Scroll, Glitch), `spec/next/tween_spec.lua`
  (flicker, onStop), `spec/next/style_theme_spec.lua` (Locales), `spec/next/sparkles_spec.lua` (Upright),
  `spec/next/tabs_spec.lua` (edges), `spec/sonata/next_engine_spec.lua` (Check; the two switches; an ornament's glitch
  off with Glitch Effects), `spec/next/vendor_spec.lua` (a secret name in every shipped theme),
  `spec/sonata/next_themes_spec.lua` ("Glitch": its fonts, licenses and art on disk, its glitch, rain, ghosts and CRT
  pieces, its palette; every theme's dock card title fitting its line), and every shipped-theme spec (`shipped_themes_spec`, `pixel_perfect_spec`, `theme_panel_spec`)
  with it. Mutation-tested: 56 mutations of the rain, tab edges, checks and switches (seven first survived: four led to
  tests, three were dead code, removed), and 49 of the glitch engine, ease, onStop, Locales, Upright and ornaments
  (twelve first survived: nine led to tests, three were dead code, removed); then 46 of the fixes after the adversarial
  review (eight first survived: four led to tests, four were dead code, removed); every one now caught.
- **Not seen in game yet**: any of it. To check: the theme's look at rest and mid-glitch against the mockups (the plan
  drew them), the custom fonts at the UI scales the pixel rules cover, the rain's cost (a profiler capture of an open
  panel: `NextRainSet.Step`), the client's draw order of the BORDER-layer glyphs under the vignette and over the wash,
  and whether a section's shove animation and the glitch layer's own alpha behave as the specs' mock says.
