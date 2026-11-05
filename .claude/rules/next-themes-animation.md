---
paths:
  - "sonata/next.lua"
  - "config/catalog.lua"
  - "spec/sonata/next_engine_spec.lua"
---
## 20. The player's Animation switches (Appearance > Animation)

Asked: "we need a way to disable sparkles etc on any theme, not just switching to a theme without them", on a new tab of
Appearance, then "title it 'Animation'". Each switch turns one of BetterBags Next's effects off on whatever theme is in
use, and back on.

- **The switches** (the settings catalog, `config/catalog.lua`; the Animation tab's Effects section,
  next-settings.md §4), each on until turned off:

  | Setting | Saved as | Takes out of the theme in use |
  |---|---|---|
  | Sparkles (`nextSparkles`) | `sparkles` | `Sparkles`: every emitter (title cloud, ribbon, edge, the knot's burst) |
  | Title Shimmer (`nextShimmer`) | `shimmer` | `Header.Spark`: the spark gliding along the ribbon into the cloud |
  | Title Cloud (`nextTitleCloud`) | `titleCloud` | `Header.Cloud`: the puffs breathing behind the title, and the join |
  | Title Ribbon (`nextTitleRibbon`) | `ribbon` | `Header.Ribbon`: the gold line from the title out past the window's edge (asked: "the spike that comes off of the bag"); the shimmer, left on, flares where it began |
  | Braid (`nextBraid`) | `braid` | `Chain.Braid` (false): the ribbons twisting between chained bags |
  | Moving Ornaments (`nextOrnamentMotion`) | `ornaments` | each ornament's `Motion` (next-themes-ornaments.md §12): it stands still, its art kept |
  | Glitch Effects (`nextGlitch`) | `glitch` | `Panel.Glitch` (next-themes-glitch.md §21): no flicker, tears or bursts; the bags slide in and out as any theme's. Flicker can be hard on some players' eyes |
  | Data Rain (`nextRain`) | `rain` | `Panel.Rain` (next-themes-glitch.md §21): no glyphs falling |
  | Ice Shatter (`nextShatter`) | `shatter` | `Panel.Shatter` (next-themes-frost.md §22): no freezing together or shattering; the bags slide in and out as any theme's |
  | Snow, Leaves and Stars (`nextSnow`) | `snow` | `Panel.Snow` (next-themes-frost.md §22): no snow, falling leaves, stars at warp, gusts, wind streaks or shooting stars. Titled Snowfall until the Halloween theme's leaves fell through the same engine, then Snow and Leaves until the Make It So theme's stars did |
  | Smoke Puff (`nextSmoke`) | `smoke` | `Panel.Smoke` (next-themes-halloween.md §23): no smoke; the bags slide in as any theme's |
  | Bats (`nextBats`) | `bats` | `Panel.Bats` (next-themes-halloween.md §23): no breaking up into bats, no fluttering bats; the bags slide out as any theme's |
  | Transporter (`nextBeam`) | `beam` | `Panel.Beam` (next-themes-makeitso.md §24): no beaming in or out; the bags slide in and out as any theme's |
  | Paper Folding (`nextPaper`) | `paper` | `Panel.Paper` (next-themes-papercraft.md §25): no unfolding or crumpling; the bags slide in and out as any theme's |
  | Stop Motion (`nextStopMotion`) | `stopMotion` | `Motion.StopMotion` (next-themes-papercraft.md §25): the theme's animations run smoothly, every frame |

  Moving Ornaments also holds a theme's threads of light still (next-themes-frost.md §22: each thread's `Sway` and `Glint` taken out, its art
  and its draw-in as the panel opens kept).

  Saved per profile in `nextAnimation` (`DB:GetNextAnimation(name)`, `DB:SetNextAnimation(name, on)`; any other name is
  an error, the names being the defaults' in `const.DATABASE_DEFAULTS`). Each switch sends `next/AnimationChanged`.
- **How:** `SonataNext:effective(key)` resolves a theme (a new table) and runs, for each switch turned off, what it
  takes out (`ANIMATION_OFF`, `sonata/next.lua`): a table set to nil, as resolution removes a table a theme sets to
  `false`, and `Chain.Braid` set to false (a boolean). The theme in use is always the effective one: Next starting
  (`use`), a theme applied or previewed (`ApplyTheme`), the theme handed out (`GetCurrentTheme`). `Resolve` and `Check`
  keep a theme as it is written, for theme authors. No widget checks a switch: every part a switch removes is one a
  shipped theme already leaves out (Quiet, Parchment, Guild Wars 2, Plain), and `spec/next/shipped_themes_spec.lua`
  draws every window with them absent. The title's glow and the wash are left alone: they are no animation.
- **Every combination must draw.** Each part is one some theme leaves out, but no theme leaves out every set of them
  together. **Failure mode (fixed, reported: "turning off title shimmer causes the background behind the word Backpack
  to BLIND ME"):** with a cloud and no spark (no shipped theme has that), the header's styling settled the shimmer's
  swell by drawing the cloud (`SetCloudSwell(0)`) before its new puffs were laid out; drawing a puff with no place
  failed (silently: each widget restyles in a protected call), and the cloud's driver failed every frame after, leaving
  the puffs at full strength, added as light. It now only resets the swell; the cloud is drawn once laid out
  (`LayoutCloud`, at the end of the header's styling). A spec draws an open bag under all 64 combinations of the
  switches, errors captured, and runs the cloud's driver each time.
- **A switch changed** (`next/AnimationChanged`, followed by `SonataNext:WatchAnimation`, registered once, started by
  `core/init.lua` after `WatchClientFonts`): `SonataNext:ApplyAnimation(ctx)` lays the switches over the current theme
  again, hands it to Next's style keeping the font objects (`NextStyle:Use(theme, true)`: the switches touch no font,
  and font objects can never be freed, so a theme applied on every click would leave a set behind each time), and
  restyles every widget: an open bag stops its emitters (`SetEnabled(false)` clears every sparkle) or starts them
  again, hides its spark or glides it again, and so on, at once. Nothing is saved or announced
  (`sonata/NextThemeChanged` is not sent: no theme changed). Nothing before Next starts.
- **Not done:** the motion of the layout itself (items gliding, the sections' fade-in cascade, slides): a "reduce
  motion" setting is a different kind, for later.
- **Coverage:** `spec/sonata/next_engine_spec.lua` ("the player's Animation switches": each part out and the rest left,
  nothing out while on, over every theme applied and previewed, `Resolve` untouched, `ApplyAnimation` keeping the font
  objects and restyling, nothing before the start, the theme handed out before any is in use, the message followed and
  registered once), `spec/next/style_theme_spec.lua` (keeping font objects), `spec/next/theme_panel_spec.lua` ("the
  Animation switches": on real panels, every sparkle stopped and started, through a theme applied and a bag made later,
  the shimmer, the cloud with the ribbon kept, the ribbon with the cloud kept, the cloud at its own strength with the
  shimmer off and settled mid-swell, every combination of the switches without an error, a coupled pair's braid, a
  moving ornament stilled with its art kept),
  `spec/database_spec.lua`, `spec/config/settings_effects_spec.lua` (each switch saves and sends the message),
  `spec/next/settings/content_spec.lua` (the tab, its switches, Next only, search),
  `spec/integration/next_settings_spec.lua` (the tab built on the whole addon), `spec/core/init_spec.lua` (the order).
  20 mutations, each caught; the one that first survived (the theme handed out before any is in use) led to a test.
  Then 4 for the ribbon and the cloud's fix, each caught (drawing the cloud early, not settling its swell, the ribbon
  left in, its row left out).
