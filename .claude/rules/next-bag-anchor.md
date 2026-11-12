---
paths:
  - "next/panel.lua"
  - "next/chain.lua"
  - "next/bag.lua"
  - "next/bank.lua"
  - "frames/anchor.lua"
  - "spec/next/small_spec.lua"
  - "spec/frames/anchor_spec.lua"
---
## 30. Bag anchors in BetterBags Next (#1276; docs/next-bag-anchor.md)

Issue #1276 asked for the classic bags' Bag Anchor in BetterBags Next. What was asked, after a literal port and snapping to the
screen's edges were turned down ("people don't always anchor on edges either"):

> replace the "clean up bags" button in the header since it's duplicate functionality now that you can right click the header
> to clean up bags. instead, let's replace it with an anchor control: 1) always auto-grow the bag based on it's bottom half
> quadrant [...] (or maybe just left right split on the screen, rather). this is just on and works 2) button at the top toggles
> our visible anchors for the bag *and* switches to anchor mode. they drag the visible anchor with the same mechanics as the
> classic bags. 3) press the button again to lock the anchor and bags so they can't be dragged 4) press the button again to
> release anchor (basically, tri-state button)

And the answers to the questions it raised: rule 1 is the bottom edge, left or right by screen half; the bank's title sorts it
and its sort button goes too; the vendor and the guild bank hold their bottom corner but have no button; a full-size bag hides
the button and the square; "resize is locked too"; dragging the bag's title while its anchor shows moves the square with it;
anchoring the bag that sits beside its partner unchains it, and locking a bag holds the bag chained beside it; Next keeps its
own saved state, apart from the classic anchor's.

Then, having used it in game ("the interaction is perfect"):

> let's do the 4 quadrant anchoring instead of just left and right. for the top half of the screen though... let's make it so
> we only swap the anchor if the anchor box is the drag handle [...] top anchors only work when you drag via the box, not the
> title. this is because dragging by the title to the top won't work well given how tall the window is. basically, when
> dragging by title bar == left/right anchor only. when dragging by anchor box == 4 quadrants.

### 30a. A small bag holds a corner (`HeldCorner`, `SmallPlace`)

- **Saved:** `nextSmallCorners[kind] = { x, y, side, edge }` (`DB:Get/SetNextSmallCorner`: side "LEFT" or "RIGHT", edge
  "TOP" or "BOTTOM", nothing else accepted; a corner saved without an edge, by the first build of the anchor, reads as
  "BOTTOM"): one of the bag's four corners on the screen, in UIParent's units. Where it is drawn (`SmallPlace`, its top left)
  is worked out from the corner and its size now, so it grows away from its held edge and its held side: up from a bottom
  corner, down from a top one. Autosize Bags (next-small-autosize.md §14i), Fit Names While Open, Bag Scale, the screen's height
  share all keep the corner.
- **Which corner:**
  - **Dragged by its title** (or dropped beside a partner, or saved where it stands as its companion closes): a bottom corner,
    the side the half of the screen the bag's middle is on (`CornerOf` with no side and no edge: `SavePlace`, `StopMove`,
    `chain:Released`), wherever it is dropped, the top half too (asked: "when dragging by title bar == left/right anchor
    only ... dragging by the title to the top won't work well given how tall the window is"). A bag holding a top corner
    dragged by its title holds a bottom one from then on.
  - **Dragged by its anchor square** (§30c): any of the four, the quadrant the square's middle is in ("when dragging by anchor
    box == 4 quadrants").
  - Sizing keeps the corner it has, side and edge (`saveSized`: a grip let go, Shift-click), and so does turning Clamp Bags
    to Screen on (`chain:ClampChanged`), so a bag sized or refitted across the middle never flips.
- **Never placed** (`HeldCorner`'s default): its own side's bottom corner (the backpack's bottom right, a companion's bottom
  left) the margin in from its edge, its bottom where a bag of the default height (the screen's share, `Small.Height`)
  centered on the screen has it: with Autosize Bags off, a bag of the default size sits exactly where it always did.
- **On the screen** (`clampPlace`): with Autosize Bags on, all of its height stays on the screen: a bag holding its bottom is
  pushed down no further than keeps its top on the screen (the mirror of "move the bag up just enough", asked when bags held
  their top); one holding its top is pushed up no further than keeps its bottom on it; a drop that leaves its bottom under the
  screen is put back up and held there. The corner is not changed by a push: the bag goes back to it as it shrinks. Clamp
  Bags to Screen on keeps all of it on the screen, as before.
- **Grips** stay on the bottom corners and size from there (the client's `StartSizing`, the top still): let go, the corner is
  kept, its held edge where it was left (`saveSized`: a bottom corner's bottom where the grip left it, a top corner's top,
  which the grip never moves); autosized, its height bounces back from the edge it holds (`StopSizing`'s top is a top corner's,
  or a bottom corner's plus its height), an edge pushed back on the screen kept, one Clamp Bags to Screen moved the other way
  saved.
- **Shift-click** (`ResetSize`) keeps its held edge (`HeldEdge`; autosized, the one it holds) and the side across from the grip
  (the right grip its left, the left grip its right); the other edge glides.
- **Saved places from before** (`nextSmallPlaces`, a top left, `DB:GetNextSmallPlace`/`ClearNextSmallPlace`): `SmallPlace`
  reads one as a top left until the bag shows; as it first shows (`FitSmall`, `ApplyGeometry` on a shown panel) `adoptPlace`
  saves the bottom corner it holds where it is then, at the height it shows (kept on the screen as it is drawn), and clears the
  old place, so it does not move.
- **Chained bags line up by the edge their anchor holds** (`chain:ChainedPlace`, `HeldEdge`; they lined up by their tops):
  their bottoms beside an anchor holding a bottom corner, their tops beside one holding a top corner, each growing away from
  that line on its own, so a companion's height glide no longer carries the bag beside it, while its width (a name, the
  screen's edge, a Bag Scale) still does. A chained bag's `HeldEdge` is its anchor's (its Shift-click keeps that edge).
  - A grip that moves an anchor's bottom (Autosize Bags off) leaves the bag beside it where it is while it is dragged and glides
    it level once let go (`StopSizing` → `SettleSpot`; beside an anchor holding its top, the spot does not move and nothing
    glides). A chained bag's own grip let go glides it back level with its partner (`StopSizing`'s top is its spot's; the snap
    glides the top whenever its place moved, `rises`).
  - `chain:Released` saves the backpack's bottom corner where it stands beside the companion closing, not a bottom Autosize
    Bags pushed down (`math.max` of where it stands and its spot's bottom).
  - An anchor holding a top corner dragged by its title carries its partner by their tops; dropped, it holds a bottom corner,
    and the partner glides to line up by their bottoms (`StopMove`: only where the drop changed the anchor's `HeldEdge`; any
    other drop moves the partner with the anchor at once, a push off the screen's edge too).

### 30b. The anchor button (`AnchorButton`, `CycleAnchor`, `SetAnchorState`)

- **State:** `nextAnchorStates[kind]` (`DB:Get/SetNextAnchorState`: "free", "shown" or "locked", free saving nothing),
  `panelProto:AnchorState()`. Separate from the classic anchor's (`anchorState`, `anchorPositions`).
- **The button** (`key = "anchorButton"`) is where the sort button was in the backpack's and the bank's header
  (`bagProto:GetHeaderButtons`, `bankProto:GetHeaderButtons` call `self:AnchorButton()`). A click cycles free → shown →
  locked → free. Its icon is its state's (`anchorButtonFree`, `anchorButtonShown`, `anchorButtonLocked` in a theme's
  `Header.Buttons.Icons`); its tooltip's title and its entry in a theme's bag button menu (`label`, a function: Plain lists it)
  say what a click does next: "Show Bag Anchor", "Lock Bag", "Unlock Bag", with a line saying how.
- **Only while small** (`UpdateAnchor`, from `ApplyGeometry`, `Show`, `Hide`, `OnHidden`, `SetAnchorState`): a full-size bag
  rests at its screen edge, so its button and square hide (its header laid out again, `LayoutHeader`), its state kept.
- **Sorting:** the backpack's title sorts it on a right click as before (`bagProto:OnTitleRightClick`); the bank's does too now
  (`bankProto:OnTitleRightClick`, `TitleRightClickHint` "Right-click to sort the bank."), where the client can sort the bank
  (`CanSort`: `C_Container.SortBankBags` or `SortBankBags`; it had a sort button only then).
- **Unchaining** (`SetAnchorState` to shown or locked, small): `chain:Unchain` lets the bag go of the small chain where the
  chain would sit it beside a partner (a companion in layout "backpack", the backpack in layout "companion", the partner open
  or not), and its place is saved where it stood (`SavePlace` of its place at rest). An anchored bag dropped beside its
  partner never chains (`chain:Dropped`), nor does another bag's drop chain it (`free` in `SmallAnchorOf`, `SmallPair`); its
  partner dropped beside it still chains to it, the anchored bag the pair's anchor. Freed where the chain sits it beside a
  partner, it glides into its spot once nothing else places it (`SettleSpot`, §30h).

### 30c. The square (`anchorSquareFrame`, `PlaceSquare`, `StartAnchorDrag`, `AnchorDragged`, `StopAnchorDrag`)

- **One look for both designs:** `Anchor:CreateSquare(name, label)` (frames/anchor.lua) makes the classic anchor's square (72
  across on UIParent, Blizzard's tooltip background in blue 48/168/255 with a black 1-unit edge, its label at its top and its
  position label at its bottom, `FULLSCREEN_DIALOG`, movable by a left-button drag, hidden). The classic `anchor:New` makes its
  square with it, then adds its own scripts, `CENTER` point and LibWindow config as before; Next's (made the first time it
  shows, the module looked up then, so specs that never show one need not load frames/anchor.lua) sizes it in whole pixels,
  clamps it to the screen and enables the mouse.
- **Shown** (`SquareShown`: small, open, not closing, state shown) with its same corner on the corner the bag holds (its top
  right on a top right corner, and so on: `PlaceSquare`, on whole pixels, its position label `"%dx %dy"` of that corner). It
  covers the bag's corner, as the classic one does; on a top corner that is the end of its header, where its buttons are (the
  backpack's close, settings and anchor buttons), and a right click on the square locks the bag (below). `SetCorner` (every
  save of a corner) places it again. A bag pushed back on the screen leaves the square where its corner is.
- **Dragged** (the classic anchor's mechanics: the client moves the square, `StartMoving`): each frame (`OnUpdate`, set for the
  drag only) the corner is the square's same corner in the quadrant of the screen the square's middle is in (its side the
  half across, its edge the half up and down), saved, and the bag (and the bag chained beside it) placed from it. Let go, the
  square is anchored on whole pixels there and the chained bag's place saved. A hide ends the drag (`OnHidden`,
  `UpdateAnchor`).
- **Dragging the bag's title** moves the square with it each frame on the bottom corner the bag would hold where it is now
  (`StartMove`'s mover `OnUpdate`: `CornerOf(LivePlace())`, a bottom corner, as the drop saves).
- **A right click** on the square hides it, as on the classic one, which keeps the anchor: here that is Locked.

### 30d. Locked (`Held`)

`Held`: a small bag whose state is locked, or that sits beside (chained) a locked bag. It neither moves (`StartMove` refuses,
the title and title row with it) nor sizes (`StartSizing` refuses, `ResetSize` returns "locked", its grips hide:
`UpdateGrips`, and `chain:UpdateGrips` as a state changes so the chained bag's grips follow). Its title's tooltip says so
(`chain:Tooltip`: "Locked in place: unlock it with its anchor button.", or "Locked beside the %s." for a held chained bag).

### 30e. Art

Header glyphs (`tools/textures/next_icons.py`): `anchor` (an anchor), `anchorshown` (the anchor inside the corners of its
square) and `lock` (a padlock), in the uitools style of the others; the sort glyph is gone with its button. Papercraft draws the
same three by hand (`next_papercraft.py`, `icon_anchor` and so on), Make It So has them as LCARS blocks (`next_makeitso.py`,
`block_anchor` lilac, `block_anchorshown` sky, `block_lock` orange). GW2 has no anchor art: it inherits the Default glyphs in its
glyph color (its sort art, `MicroCollections`, went with the button). `Textures`: `IconAnchor`, `IconAnchorShown`, `IconLock`
(Default, Papercraft), `BlockAnchor`, `BlockAnchorShown`, `BlockLock` (Make It So).

### 30f. Left as it is

- `/bbanchor` still shows the classic bags' anchors only (config/config.lua); in Next the anchor is the header button.
- The vendor and the guild bank hold their corner (a bottom one: they have no square) but have no anchor button (asked).
- Chained bags lining up by the edge their anchor holds (§30a) follows from holding a corner rather than something asked in so
  many words.
- Saved places from before #1276 (a top left) are taken over as a bottom corner, as a title drag would place them: a top corner
  is the square's alone.
- **Open, for the player to decide (found by the bug review, reproduced):** the braid between two chained small bags is drawn
  by each bag from its own title (`applyBraid`, `TitleJoin`: each half straight out at its title's height, its ribbon too), so
  with their bottoms level and their heights different (Autosize Bags, on by default) the two halves sit at two heights and do
  not meet: loose pieces in every theme with a braid (Plain, GW2 and Quiet draw none). Beside an anchor holding a top corner
  their tops are level and the braid meets. Either the braid slopes between the two titles (its strands, beads, knot and both
  ribbons; not built, its look not seen in game), or chained bags line up by their tops always (the braid as it was; the bag
  beside an anchor holding a bottom corner then moves as the anchor grows up). Asked of the player with the report.

### 30h. Bug review

The first review (2026-11-12) found four, each reproduced and the first three fixed test-first with their specs:
- **An anchored bag chained by another bag's drop:** a companion dropped beside the backpack sets layout "backpack", which
  chained every companion, an anchored bank too (drawn beside the backpack, its square left at its corner, carried by a dragged
  backpack). The chain never sits an anchored bag beside a partner now (`free`, in `SmallAnchorOf`, `SmallPair`, `Released`).
- **A companion closing mid-glide saved the backpack's corner from the glide's height:** `CornerOf` read the frame's size
  part way through the glide, and the backpack jumped at its next height change. `CornerOf` works from the size at rest
  (`smallWidth`, `smallHeight`), and `Released` takes the spot's bottom as the spot's top less the backpack's height as
  `ChainedPlace` read it.
- **Alt+Z part way through the close slide left the square hidden:** `OnHidden` updated the anchor while it was still closing;
  it does so once the close is over now.
- And, not reproduced by it but shown by its spec here: items arriving while the square is dragged cut the height glide short
  every frame (`AnchorDragged` places the bag); a square drag makes the bag busy (`busy`), as a move does, so its height waits
  and glides once let go.
- The braid (§30f), left for the player.

The second review, aimed at those fixes, found three, each fixed test-first with its spec:
- **Anchoring a chained bag part way through its height's glide** saved its corner from `SmallPlace` (the glide's height) less
  its height at rest (`CornerOf`), its bottom off its partner's. `SetAnchorState` saves its place at rest (`placeX`,
  `placeY`, which a size glide sets where it ends).
- **Locking a bag already anchored** set the chain "apart" (`Unchain`), letting go of another companion's chain beside the
  backpack. `Unchain` does nothing for a bag that is not free (it is chained to none).
- **A bag freed where the chain sits it beside a partner** (layout "backpack", set by another companion's drop) was chained at
  once but left where it was drawn, and jumped at the next move. Freed, it glides into its spot, as a bag opened in that
  layout does, and the pair braids. A decision for the player, reported: the other way was to keep it where it stands, which
  in that layout means letting go of the other companion's chain too.

The third review, aimed at those, found that gliding a freed bag into its spot fought whatever else placed it: freed during
its open slide, the glide replaced the slide, whose end says it has shown (a bank's contents waited for the 1 s timeout);
during its height glide or a size switch, the two placed it in turn and it jumped. `SettleSpot` glides it only when nothing
else places it (`busy`), else owes it the glide (`spotMoved`), which its slide's end, a size switch's end (`chain:Arrived`)
and its size glide's end (`chain:Update`) pay, as `chain:Update` already leaves a busy bag to them. `StopSizing`'s glide of
the bag beside an anchor goes through it too. A bag freed during a close slide does not glide (it opens in its spot). Left:
a Shift-click's glide ends without settling a bag owed one, so a bag shown, reset, then locked and freed within that 0.35 s
glide waits until the chain next settles it.

The four corners had two reviews (2026-11-12). The first found one bug, fixed test-first: an anchor holding a top corner
dragged by its title carried its partner by their tops, then the drop saved a bottom corner and the partner jumped to line up
by their bottoms (446 units at once). `StopMove` glides it there (`SettleSpot`). It also found five of the change's branches
no spec caught (Clamp Bags to Screen keeping the edge, `saveSized`'s `math.min`, `HeldEdge` through the chain, `StopSizing`'s
held top with Autosize Bags on, `ResetSize`'s held top with it on); each has a spec now, the last one by what the player sees
(it changes nothing on screen there: the height a reset starts from is the one it had, and its top comes back as that height
follows). The second, aimed at the glide, found it glided wherever the partner's spot moved: a drop the screen's edge moved
(Autosize Bags) slid the partner after the anchor instead of with it, and at some Bag Scales an ordinary drop glided it a
pixel. It glides only where the drop changed the edge the pair lines up by (`HeldEdge` before and after). Left: grabbing
either bag in that glide's 0.23 s ends it at once (`StartMove` finishes a partner's glide, as for every glide into a spot),
so the rest of the distance jumps; less than the whole jump it replaced, and the same as for a glide after a drop beside a
partner.

### 30g. Coverage

`spec/next/small_spec.lua`: "holding its bottom corner" (the default corner, the side a drop takes, growing up with each side
still, never placed, pushed down and back up at Bag Scale 100% and 150%, a drop below the screen put back, a grip's bounce over
the held bottom, a names glide away from the held side, a grip and Shift-click with Autosize Bags off, chained bags by their
bottoms, a saved place taken over on either side; and "holding a top corner": growing down with its side still, pushed up off
the screen's bottom and back down, a grip and Shift-click keeping its top (Autosize Bags off and on, pushed up too), a title
drag making it a bottom corner, chained bags by their tops, the partner gliding level by their bottoms once a top-held anchor
is dropped by its title and moving with it at once on any other drop (Bag Scale 100%, 90%, 115%), a chained bag's Shift-click
keeping its top level, Clamp Bags to Screen keeping a top corner) and "its anchor" (the button where sort was, small only; the
three states,
icons, tooltips and menu labels; the square's look, place, showing with the bag and at full size; dragging it, the side
following the screen's half, any of four corners by the square's quadrant (the top ones in the top half, the middle's edge), its
place on a top corner; the title drag carrying it, on a bottom corner from a top one; its right click locking; locked: no move,
no resize, no reset, grips
hidden, the tooltip; unchaining both layouts, keeping the anchor's chain, no chaining a dropped anchored bag; a chained bag held
by a locked one), plus every older small-mode test rewritten for held bottoms (resizing "chained": a grip that moves an anchor's
bottom gliding the bag beside it level once let go). `spec/next/bank_spec.lua` (the title's sort and its hint, none where the
client cannot sort, the header's buttons), `spec/next/bag_spec.lua`, `spec/next/theme_panel_spec.lua` (the Plain menu's anchor
entry), `spec/frames/anchor_spec.lua` (the shared square, the classic anchor made with it), `spec/database_spec.lua`,
`spec/core/constants_spec.lua`, `spec/sonata/next_themes_spec.lua` (every theme's anchor art).
