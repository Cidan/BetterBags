# BetterBags Next: bag anchors (#1276)

Issue #1276 asks for the classic bags' Bag Anchor in BetterBags Next. Triaged with the player (2026-11-12): a literal port
of the classic anchor (a separate blue square toggled from the bag menu) does not fit Next, whose small bags already move
by their title, and which has no bag menu. Snapping to screen edges was rejected too ("people don't always anchor on
edges either"). What was asked instead:

> replace the "clean up bags" button in the header since it's duplicate functionality now that you can right click the
> header to clean up bags. instead, let's replace it with an anchor control:
> 1) always auto-grow the bag based on it's bottom half quadrant, so lower right, grow from lower right of bag, lower left,
>    grow from lower left (or maybe just left right split on the screen, rather). this is just on and works
> 2) button at the top toggles our visible anchors for the bag *and* switches to anchor mode. they drag the visible anchor
>    with the same mechanics as the classic bags.
> 3) press the button again to lock the anchor and bags so they can't be dragged
> 4) press the button again to release anchor (basically, tri-state button)

The decisions taken with it:

| Question | Decision |
|---|---|
| Rule 1 | Every small bag holds its bottom edge, and its left or right bottom corner by which half of the screen it is on. |
| The bank's sort button | Not a duplicate (its title's right click did nothing): the bank's title sorts it on a right click too, and its sort button is replaced by the anchor button as well. |
| The vendor and the guild bank | Rule 1 applies to them (they are small bags too); no anchor button. |
| Full-size bags | Docked to the screen's edges, nothing to anchor: the anchor button and the square are hidden. |
| What Locked blocks | Moving and resizing (the grips and their Shift-click reset). |
| Dragging the title while the anchor shows | The bag and the square move together. |
| Chained bags | Anchoring the bag that sits beside its partner unchains it, as dragging it does; locking a bag holds the bag chained beside it too. |
| Saved state | Next keeps its own (where each small bag is held, and each bag's anchor state), apart from the classic anchor's. |
| Four quadrants (asked after using it in game) | The square picks any of the bag's four corners, by the quadrant its middle is in. Dragging by the title picks a bottom corner only, left or right: "dragging by the title to the top won't work well given how tall the window is". |

## Rule 1: a small bag holds a corner

Before: a small bag's place was its top left (`nextSmallPlaces`), so it grew downward as it got taller (Autosize Bags,
on by default) and away from its left edge as it got wider (its grips, Fit Names While Open).

Now its place is its **held corner** (`nextSmallCorners[kind] = { x, y, side, edge }`, `DB:Get/SetNextSmallCorner`): one of
its four corners on the screen, in UIParent's units, its `side` "LEFT" or "RIGHT" and its `edge` "TOP" or "BOTTOM". Where it
is drawn is worked out from that corner and its size as it is now (`SmallPlace`), so it grows away from its held edge (up
from a bottom corner, down from a top one) and away from its held side.

- **Dragged by its title:** a bottom corner, the side the half of the screen its middle is on, wherever it is dropped. So is
  a bag put back beside a companion that closed. A top corner comes from the square alone (below).
- **Resizing** keeps the corner it has: a bag sized across the middle of the screen does not flip.
- **Never placed:** its own side's bottom corner (the backpack's bottom right, a companion's bottom left), the margin in
  from its edge, its bottom where a bag of the default height centered on the screen has it: with Autosize Bags off a bag
  of the default size sits where it always did.
- **On the screen:** with Autosize Bags on, all of it stays on the screen as it grows: a bag holding its bottom is pushed down
  just enough to keep its top on it (the mirror of "move the bag up just enough" for a bag that held its top), one holding
  its top pushed up just enough to keep its bottom on it; either goes back to where it was left as it shrinks. With Clamp
  Bags to Screen on, all of it, as before.
- **Its grips** are on its bottom corners and size it from there, its top still: let go, the edge it holds is where the
  player left it (Autosize Bags off; on, its height bounces back to what it shows from the edge it holds). Shift-click
  glides it back to its default size keeping its held edge.
- **Chained bags** line up by the edge their anchor holds: their bottoms beside a bag holding a bottom corner, their tops
  beside one holding a top corner, each growing away from that line on its own.
- **Saved places from before** (`nextSmallPlaces`, a top left) are taken over the first time the bag is shown (its height
  is what it shows then) as a bottom corner: worked out from where it is, so it does not move, and the old place is cleared.

## The anchor button and the anchor

The backpack's and the bank's header button that sorted them is now the anchor button (their titles sort them on a right
click). It cycles through three states, saved per bag (`nextAnchorStates[kind]`: nil for free, "shown", "locked"):

1. **Free** (the anchor icon): the bag moves and sizes as any small bag does.
2. **Shown** (the anchor icon, framed): the bag's anchor shows, the classic bags' blue square (frames/anchor.lua's look,
   one component for both designs: `Anchor:CreateSquare`), its same corner on the bag's held corner, its label the bag's
   name, its position label where that corner is. Dragging the square moves the bag with it, the bag's corner pinned to
   the square's same corner, the corner following the quadrant of the screen the square is in, as the classic anchor's
   does (the top corners in the top half). Dragging the bag's title moves the square with it, on the bottom corner of its
   half. A right click on the square hides it, as on the classic one,
   which locks the bag (below).
3. **Locked** (a padlock): the square hides and the bag can neither be moved nor resized: its title and title row do
   not drag it, its grips hide, Shift-click does not reset it. A bag chained beside it is held as well.

Pressing it again releases the anchor: back to free. Only small bags show the button; a full-size bag hides it and its
square (the state is kept for when it is small again). The Plain theme lists it in its bag button's menu by what a click
does next ("Show Anchor", "Lock Bag", "Unlock Bag").

The square's right click: the classic square hides itself on a right click and keeps the anchor; Next's goes to the next
state (Locked), so the button and the square never disagree.

## What changed where

- `next/panel.lua`: `SmallPlace` from the held corner; `heldCorner`, `CornerOf`, `SidePlaced`, `SaveCorner`;
  `clampPlace` keeps the top on the screen with Autosize Bags on; `StopMove`, `StopSizing`, `ResetSize` save corners;
  `leftPlace` is gone (its job, keeping a saved bottom through a push, is the corner's); the anchor state, the square and
  the lock (`AnchorState`, `CycleAnchor`, `Held`, `UpdateAnchor`, `PlaceSquare`).
- `next/chain.lua`: `ChainedPlace` lines bags up by the edge their anchor holds; `Released`, `ClampChanged` save corners; `Dropped` never
  chains an anchored bag; `Unchain` lets a bag go of a chain it would sit beside.
- `next/bag.lua`, `next/bank.lua`: the anchor button for the sort button; the bank's title sorts it.
- `frames/anchor.lua`: the square's look as `Anchor:CreateSquare`, which the classic anchor uses too.
- `core/database.lua`, `core/constants.lua`: `nextSmallCorners`, `nextAnchorStates`.
- Themes (`sonata/themes/next/*.lua`) and their glyphs (`tools/textures/next_icons.py`, `next_papercraft.py`,
  `next_makeitso.py`): `anchorButtonFree`, `anchorButtonShown`, `anchorButtonLocked` for `sortButton`.
