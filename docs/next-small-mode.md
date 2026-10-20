# BetterBags Next: Small Mode

A second size for BetterBags Next's panels: smaller, movable panels that keep Next's look, for
players on smaller screens. Players switch between the two sizes with a button, animated, and keep
whichever they like. This document is the plan; `.claude/rules/next.md` describes what is built.

## Why

Next's panels are full height and slide in from the screen's edges (next.md §3). At the bank, a
vendor or the guild bank, two of them are open at once, and on a 1080p screen they cover most of
it. Asked (2026-10-19):

> the biggest pain is two panels open for people with smaller screens. one solution is just a
> smaller panel, like ESO -- we keep our visual flare (maybe no feather, and the beam is shorter),
> and the slide out becomes a panel we can move. same for the others. they can still chain to each
> other if dragged close by. still want the sparkles between them/coming out the side though!
>
> let's add a button toggle to swap between small and full mode (animated of course). people can
> pick. we'll have to toy with it.

The reference is The Elder Scrolls Online's inventory: one panel on the side of the screen, much of
the game still visible around it.

## How the panels work today (what small mode changes)

From `next/panel.lua`, `next/chain.lua` and `next/style.lua`:

- **Full height.** A panel's frame is anchored to `UIParent`'s top and bottom (`setOffset`), and its
  render root hands its content the screen's height less the header and footer
  (`rootProto:PreRender`).
- **Placed by one number.** Where a panel is, is a horizontal offset from its own screen edge
  (`offset`): sliding in and out, flying to its partner, waiting beyond the far edge. The backpack
  is on the right edge, every companion (bank, vendor, guild bank) on the left.
- **Width:** `style.WIDTH` = the feathered edge (`FEATHER`, 96) + the body (`BODY_WIDTH`, 458: the
  8-column grid of 44-unit icons, the scroll gutter and the padding). The tab rail hangs out of the
  body's inner side, up to `TAB_MAX_WIDTH` (150) more.
- **The beam:** the title's ribbon, `RIBBON_LENGTH` (300) of glowing line from the title out of the
  window, its spark gliding along it, and the cloud of light round the title.
- **Sparkles:** round the ribbon, in the title's cloud, along the inner feathered edge ("coming out
  the side"), and from the knot between two chained bags. Their spawn points are fixed offsets from
  the panel's top left, computed from the full width (`BuildSparkles`).
- **Chaining** (next.md §12): three layouts saved as `nextChain` ("apart", "left", "right"). A
  chained bag sits beside its anchor at the anchor's edge; clicking a bag's title chains, unchains or
  moves the pair. Once in place, their ribbons twist into a braid across the gap between them, with
  a knot in the middle that bursts with sparkles. Every distance in it is horizontal, across the
  screen (`Gap`, `Distance`, `applyCoupling`).

## The design

### The setting and the toggle

- One setting for every Next panel: `nextSize`, `"full"` (the default: nothing changes for anyone
  who does not switch) or `"small"`, in the profile next to `nextChain`.
- **The toggle** is a header button on the backpack: Blizzard's expand and condense art (the
  `RedButton-Expand` / `RedButton-Condense` atlases on retail and WoW: Forever, the
  `UI-Panel-BiggerButton-Up` / `UI-Panel-SmallerButton-Up` textures on Classic, the maximize and
  minimize buttons of Blizzard's own frames). It switches every Next panel, open or not, and every
  open one morphs to its new size (below).

### A small panel

- **The body alone:** no feathered edge (the frame is the body), with a 1-pixel edge in Next's
  lavender at a low alpha so its edge reads against the world. Same width as the body today
  (`BODY_WIDTH`): the grid, the sections, drag and drop, the confirmation card and the tab rail are
  unchanged. Its height is a share of the screen's (`style.Small.Height`, starting at 0.66), so it
  scrolls sooner.
- **The look kept:** the wash, the title and its breathing cloud, the shimmer, the sections'
  cascade, the sparkles round the ribbon and in the cloud, and the edge sparkles drifting out of its
  inner side ("coming out the side").
- **A shorter beam:** the ribbon is `style.Small.Ribbon` long (starting at 120), the ribbon's
  sparkles born along that.
- **Opening and closing:** it appears where it was left, sliding a short way in from its outward
  side while it fades in (`style.Small.Slide`), the sections cascading in as today; closing is the
  reverse. Every way of closing (the close button, Escape, leaving the bank) works as today.

### Moving it

- **Drag the header** (the title row, the title included) to move a small panel. It stays on the
  screen (clamped), and its place is saved per kind of bag (backpack, bank, vendor, guild bank:
  `nextSmallPositions[kind]`), so each opens where the player left it.
- **Default places:** the backpack on the right, a companion on the left, each a margin in from its
  edge (the tab rail clear of it), vertically centered.
- **When the screen changes** (UI scale, resolution), a saved place is kept on the screen.

### Chaining by dragging them together

- **Drop a bag next to its partner and it chains.** Only the facing sides chain: the backpack faces
  left, a companion right, as their tabs, titles and ribbons do. A bag dropped with its inner side
  within `style.Small.SnapReach` of where it would sit beside its partner, and its top within
  `style.Small.SnapRise` of the partner's, glides into place beside it: tops aligned, the gap between
  them wide enough for both tab rails (`chain:SmallGap`, at least `style.Small.MinGap`). A pair that
  would not fit on the screen does not chain.
- **The anchor is the bag it was dropped beside.** Saved as `nextSmallChain`: `"apart"`,
  `"backpack"` (a companion was dropped beside the backpack) or `"companion"` (the backpack was
  dropped beside a companion; it then sits beside whichever companion is open).
- **Dragging the anchor moves both:** the other follows it, the braid with them. **Dragging the
  other lets it go** (the braid comes apart); dropped back beside the anchor, it chains again.
- **Opening:** places are saved, so a chained bag opens straight at its spot beside its anchor
  (where the anchor is, or was left), sliding in and fading as any small panel does. No waiting for
  the anchor as in full mode.
- **The sparkles between them:** once both are open and in place, their ribbons twist into the
  braid across the gap, the knot bursts, and the edge sparkles drift into the gap, as in full mode.
  The braid's geometry is the gap between the two bodies instead of across the screen.
- **When the gap changes** (a tab rail grows), the chained bag glides to its new spot.
- The full mode's layouts (`nextChain`) are kept as they are and still used in full mode; the
  title's click (chain, unchain, move across) belongs to full mode. Each size keeps its own chain.

### Switching sizes (the morph)

- **Every open panel morphs, in two steps** (asked after the first version, 2026-10-19: the border
  showed while the feather was still fading, "making it look like the feathering is spilled out"):
  - **Shrinking:** the glide first (its visible rect, the body, eases to its small place and height,
    `style.Time.Morph`, the feather fading out and the beam shortening), then the small border fades
    in (`style.Time.MorphFade`).
  - **Growing:** the inverse: the glide starts at once, the border fading out on the way and the beam
    growing, then the feathers fade in (asked, of a first version that let the border go before
    moving: "it doesn't feel good that it doesn't start moving right away").
- **The content is not laid out every frame:** the body's width does not change, so the scroll area
  only gets taller or shorter as it moves; the content is laid out once at the end, at its new size.
- **Panels not shown** take the new size at once, and use it when they next open.
- **A chained pair** (full mode's layout, or small mode's snap) uncouples as it morphs and couples
  again where it lands, if the new size chains them.

## What does not change

The data, every item and free slot button, sections and their order, the tabs, search and the new
search box, section drag and drop, the confirmation card (next.md §7), the vendor, the bank, the
guild bank, Masque, ConsolePort, the classic bags, and switching between the classic bags and Next.

## Knobs to toy with

All in `style.Small` (`next/style.lua`), one place: the height share, the ribbon's length, the open
slide, the edge, the snap and unsnap distances, the default margins. Possible later knobs, if small
panels still feel big: denser icons (the grid's 44-unit icons and 6-unit gaps, used everywhere
through `style.ICON` and `style.GAP`). Resizing a small panel with a grip is done (phase 3).

## Phases

1. **Small panels** (done; `.claude/rules/next.md` §14): the setting, the small geometry (no
   feather, a shorter beam, the height, the edge), sparkles that follow the geometry, opening and
   closing in place, moving and saved places, the toggle with the morph. Small panels are not
   chained yet.
2. **Chaining by dragging** (done; `.claude/rules/next.md` §14e): the snap, moving a chained pair
   together, letting go, the braid and its sparkles between two free panels, a companion opening
   beside its anchor.
3. **Resizing with grips** (done; `.claude/rules/next.md` §14g): a grip on each bottom corner, seen
   under the pointer, none on the chained side, live reflow, the size kept and saved per bag, and
   Shift-click to glide back to the default size.
4. **Tuning** with the player, in game.

Each phase is tested first (specs that fail before), documented in `.claude/rules/next.md`, and
verified in game with the render recorder (render-recorder.md) where it is about how things look.
