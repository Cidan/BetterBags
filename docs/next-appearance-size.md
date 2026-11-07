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
- Every bag with item buttons: the backpack, the bank and the guild bank, and the icon on a vendor's card
  (name and price beside it, two to a row; changed for issue #1221, it first kept the theme's size). The
  card stays at least the theme's icon size tall, so two lines of name still fit beside a small icon.
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

**Status:** done, with these choices:
- Both sliders run 50% to 150% in steps of 5.
- A small panel's default size scales with it (the full body's width and the theme's share of the
  screen, in its own units), so the whole panel is a smaller or larger version of itself; the screen
  still bounds it.
- The settings lists' reordering was fixed on the way: the settings window scales itself down to fit a
  small screen, and its rows had the same mismatch.
- Commits: the tabs and Icon Scale (21 mutations, one led to a test), then Bag Scale (58 mutations, 11
  first survived: 10 led to tests, one showed a refit the chain already does, removed). Rules: next.md
  §3 (Icon Scale) and next-small-mode.md §14h (Bag Scale), next-settings.md, next-themes.md, `.claude/rules/patterns-ui-next.md`.
- Not seen in game: how a scaled small panel looks (art, text, sparkles), dragging sections and tabs in
  one, and the switch's scale glide.

## Fit Names While Open (2026-11-04)

Reported with a screenshot: a small backpack four cells wide in two columns, its title "Backp..." and a section
"Miscellaneo... 2". Asked:

> we need to make sure this never happens by always have the bag width sit at the minimum step ... such that no
> text is truncated in bag title or section title

> with an option to enable/disable this behavior in settings, default disable. with it disabled, behavior is as it
> is now

- A small bag's width always sits at the first grid step (whole cells of icons and the room beside them) at or above
  the width the player chose at which neither its title nor any section's name is cut: as it opens and where a resize
  grip is let go (next-small-names.md §14g).
- **Fit Names While Open**, after Bag Scale on the Size tab (`nextFitNamesWhileOpen`, a switch, off by default): on, a
  small bag open on the screen also follows what it shows, gliding wider when a section's name or its title would be
  cut and back to its size once it fits, saving nothing. Off, nothing changes its width while it is open.
- Found by the bug review and fixed: two chained bags follow their names one at a time (at once they overlapped); a bank
  tab switch fits its new name and sections in one glide; a Bag Scale change takes the scale before the bag follows its
  names; the glide keeps where the bag is scrolled; the title's glow is laid out for the title as it shows.
- Full-height bags are unchanged.
- Not seen in game: a bag fitting its names as it opens and as a grip is let go, and the switch's glide.

## Autosize Bags (2026-11-06)

Asked:

> we need to add a new feature to betterbags: autosize bags. this feature should go in appearance next to size, and it
> should make it so the bag grows on the vertical (Y axis) to hold all items + free space the user currently has, keeping
> the X size as is.
>
> it should be a toggle option, and it should default on i think

Then, of the plan: "follow live", "yes always at least as tall as tab rail", "yes move the bag up just enough", "yes vendor
bag too".

- **Autosize Bags**, after Bag Scale on the Size tab (`nextAutosize`, a switch, **on** by default): a small bag is as tall as
  its header, everything it holds and its Free Space, and its footer, so nothing scrolls, as far as the screen allows (past
  that it scrolls); its width stays the player's. Every small bag: the backpack, the bank, the guild bank and the vendor.
- **Live:** it fits as it opens, and glides to its new height a frame after anything it shows changes (an item looted or
  sold, a tab switched, a section moved, Free Space), with the bounce a resize grip's snap has; it waits while the bag is
  moved, sized, dragged in or sliding, and a chained pair glides one at a time.
- **Never shorter than its tab rail**, which hangs beside it from under its header.
- **Where it sits:** its top stays where the player left it and its bottom moves; never moved, it stays centered. Its bottom
  stays on the screen: where growing would take it past the screen's bottom it moves up as far as that, saving nothing, and
  goes back down to where it was left as it shrinks.
- **The grips** size it both ways; let go, its height bounces back to what that width shows, with the width's snap (asked,
  trying it: "don't lock dragging on the Y axis when resizing the window. let it drag larger, but then "bounce" it back to the
  size it should be on the Y axis"; a first version held the height while a grip dragged). Only the width is saved; the height a
  player gave a bag with its grips stays saved, and is its height again once the switch is off.
- **Room above the footer:** as much room below the last section, down to the footer's line, as between sections (asked,
  trying it: the room from the last section's item buttons "to the border to the currency/money section, is too small, make
  this a bit wider"; it was 4 units on Default).
- Full-height bags and the classic bags are unchanged.

**Status:** done. Rules: `.claude/rules/next-small-autosize.md` (§14i), next-settings.md. Found on the way, by the specs: a
let-go saved its height where none was saved (`autosize and saved or h`); by a mutation run: a let-go or Shift-click that
raised the bag saved the raise, so it never went back down (it saves the top it was left at now, `leftPlace`). Found by the bug
review and fixed: a let-go snapping wider for a name glided the height twice; switching a pair to small with the backpack beside
a companion jumped at the end; the backpack, carried by its companion, went back to where it was dropped once the companion
closed (its place is now saved where it stands as its companion closes); a let-go kept a saved top past the screen. Found by the second bug review and fixed: the backpack's place when a companion chained by a drop or a size switch
closes, or after it is dragged off one; a raised bag a grip made shorter stayed up; a bag small before glided twice switching
back; a chained bag's let-go saved a mixed place. Found by the third bug review and fixed: the companion's slide end saved the backpack's own raise; Alt+Z
saved the backpack's place; a backpack raised beside its companion kept the raise once the companion closed. Found by the fourth
bug review and fixed: the companion's slide end saved over what its close saved (a glide the close cut short, another
companion opening meanwhile, a drop). Found by the fifth bug review and fixed: a close Alt+Z cut short kept the companion's next close from saving.
- Not seen in game: the glide as items come and go, a bag growing up from the screen's bottom, a chained pair, a grip dragged
  taller and bouncing back, the room above the footer on each theme, and how a short bag beside a long tab rail looks.
