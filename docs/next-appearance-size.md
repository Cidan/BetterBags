# Appearance: a Theme tab and a Size tab (BetterBags Next)

## As asked (2026-10-23)

> make "Theme" here a tab, and add a tab for "Size"; here we have a slider for "icon scale" in the bag,
> and another slider for "bag scale"

Then, on the plan:

> it's not risk, it's just work, it's computer science, not brain surgery -- just get it done with tests.
>
> bag scale should just not apply when docked to the side. and yes, do not touch items per row or all
> that jazz, just item button scale (also account for the fact that themes can set icon scale!)

> it doesn't have to be 8 per row, it can adjust based on scale, if buttons are huge, less fit per row
> naturally. if buttons are small, more per row fit. don't overthink it.

## The page

- **Appearance** (`next/settings/content.lua`) gets two tabs: **Theme** (what the page shows today: the
  Next theme picker with BetterBags Next; the bags' theme and the settings window's with the classic
  bags) and **Size** (BetterBags Next only: the classic bags have Scale and Items Per Row on each bag's
  page, so with them the page keeps one tab).
- Tabs can now be limited to a design (`design`, as pages, sections and rows already are).

## Icon Scale

- A profile setting (`nextIconScale`, a percentage, 100 by default, 50 to 150 in steps of 5).
- An item button is the Next theme's icon size (`Layout.Icon`: Default 44, Quiet 38) times the scale, in
  whole pixels (`style.ICON`). A theme sets the size; the player's scale multiplies it, whatever the
  theme.
- The panels keep their width (the theme's, `GRID_WIDTH` from the theme's own icon size), and each row
  takes as many buttons as fit (`content.lua` already packs a row by its width): big buttons, fewer per
  row; small buttons, more. A small panel the player sized fits as many as its width allows, as it does
  today.
- Every bag with item buttons: the backpack, the bank and the guild bank. The vendor's cards are not
  item buttons (name and price beside the icon, two to a row) and keep the theme's size: a smaller icon
  would not fit two lines of name.
- A change applies at once: the icon size is recomputed and every panel lays out again. It does not
  re-apply the theme (a theme application makes new font objects, which can never be freed: a slider
  drag would leave one set per step).

## Bag Scale

- A profile setting (`nextBagScale`, a percentage, 100 by default, 50 to 150 in steps of 5), one value
  for every Next panel, so chained bags match.
- **Only small panels** (movable, docs/next-small-mode.md). A full panel, docked to its screen edge, is
  always at scale 1.
- A small panel's frame takes the scale (`SetScale`); everything in it (art, text, buttons, sparkles,
  the braid) scales with it.
- **Units:** a small panel's place (`placeX`, `placeY`, saved) stays in UIParent's units, as now; its
  size (`smallWidth`, `smallHeight`, the size saved with the grips, its minimums) is in its own units,
  as its content is laid out. On screen a panel is its size times its scale. Every place that mixed the
  two converts: anchoring (offsets in the frame's own units), clamping to the screen, the default place,
  the screen as a bound on the size, moving, sizing with a grip, the reset glide, the small chain (the
  gap and each bag's width on screen), the braid's half gap (handed to the panel in its own units).
- **Switching sizes** glides the scale too (from 1 to the bag scale, or back), with the body's place
  and size on screen.
- **Dragging across scales:** a frame lifted from a scaled panel keeps its size on screen (NextLift
  starts from the frame's scale on screen), lands at the scale of where it lands, and flies away from
  its own. Positions read on screen go through NextLift (`ScreenPoint`, and new helpers for a frame's
  center and scale): section drags (the gap under the cursor, the landing, the flight to a tab),
  scrolling near the edges, the dock's flights, and moving a tab in its rail.
- A change applies at once to open small panels: they take the scale, refit to the screen and lay out
  again; the chain places its pair again.

**Status:** planned.
