---
paths:
  - "next/chain.lua"
  - "spec/next/chain_spec.lua"
---
## 12. Chaining the backpack and its companion (`next/chain.lua`)

Asked: "having the left and right bags sit on opposite ends works well for me, but it's not going
to work well for everyone. so we need to have an option to chain bags to each other": an anchor bag
on the left or the right; clicking a bag's name flies it to the other bag and "their glowy stick
things that stick out, merge in an animation effect that shows them intertwined and coupled"; left
flies right and right flies left; a chained bag's name puts it back; the anchor's name moves both to
the other side; kept across sessions; vendors, banks and the backpack all alike. Decided with the
player: each bag keeps its orientation ("fixed"), and the backpack alone opens at its own edge,
joining its companion when it opens ("option a").

### 12a. Three layouts

The backpack faces left (its title, tabs and ribbon on its left), its companion (the bank, the
vendor or the guild bank, whichever is open) faces right. That leaves three layouts, saved as the profile's
`nextChain` (`DB:GetNextChain`/`SetNextChain`, default `"apart"`):

| Layout | Left edge | Right edge |
|---|---|---|
| `apart` | the companion | the backpack |
| `left` | the companion (the anchor), the backpack beside it facing it | |
| `right` | | the backpack (the anchor), the companion beside it facing it |

The anchor is the bag at the screen edge; the chained bag faces it, so their ribbons meet in the gap.

- **Clicking a bag's name** (`panel.titleButton`, over the title; `chain:Click`, which returns what
  it did for profiler traces): apart, the bag flies to its partner (`"chained"`: the backpack makes
  `left`, the companion `right`); the chained bag goes back to its edge (`"unchained"`); the anchor
  moves both across together (`"moved"`: `left` and `right` swap, the bags keep their order and fly
  as one, so the other bag ends at the edge and is the anchor). With no partner open nothing happens
  (`"alone"`); on a screen too narrow for the two side by side it refuses with an error message
  (`"no room"`).
- **The pointer over the title** lights a soft glow behind it and the tooltip says what a click
  does.
- **Alone, a bag sits at its own edge.** A chained bag sits beside its anchor only while the anchor
  is open (`chain:Pair`, `chain:RestOffset`): when the anchor opens it flies over; when the anchor
  closes (or Escape hides it) it flies home.
- **A chained bag opening beside its open anchor comes in from the anchor's edge** (`panel:Enter`):
  from out of sight beyond that edge (`chain:EntranceOffset`), lowered 100 levels beneath the anchor
  so it slides out from under it, and back at its own level once in place. While the anchor is still
  coming in itself it starts `style.Chain.Stagger` (0.08 s) after (`chain:EntranceDelay`). Asked,
  after the first version flew a restored chain across the screen as the bags opened: "stagger them
  appearing from the border they are chained to? the window closest to the border first, then the
  chained one a few ms after, and have them fall in place". An option to fly it in across the
  screen from its own edge (`style.Chain.Enter = "edge"`) was dropped with it.
- **At a bank or a vendor the companion opens first** and the backpack a frame later
  (`addon.OpenInteractionWindow` sends `bags/OpenClose` later). Chained left, the backpack then comes
  in after its anchor as above. Chained right, the companion is the chained bag and its anchor is not
  open yet: it waits out of sight beyond the backpack's edge (`chain:WaitsForAnchor`,
  `panel:WaitForAnchor`, `panel.waiting`) and comes in after the backpack once the backpack opens
  (`chain:Update`). If the backpack has not opened within `style.Chain.AnchorWait` (0.25 s) it opens
  alone from its own edge. The backpack opens after its companion, so it never waits. A bank waiting
  still loads only once it has come in (refresh-scheduler.md §11): wait, stagger and entrance stay
  under the bank's 1 s show timeout.
- **Out of sight beyond the far edge** (waiting, or held through its stagger: `BeyondFarEdge`), a bag
  that flies home (its anchor closed) or closes leaves through its own edge, never crossing the
  screen.
- **Closing, a chained bag leaves through its anchor's edge** (`chain:ExitOffset`): while it is away
  from its own edge and the bag it is chained to still shows (`chain:ShownAnchorOf`: open, or sliding
  out), it slides out beyond the anchor's edge, beneath the anchor (lowered 100 levels, back at its
  own level once hidden); else through its own edge, as before. Asked: "when closing a vendor or bank,
  if the bag is chained, it should also exit in the direction of the anchor (right now it flies
  across the screen to it's original side when we leave the vendor/bank/whatever)".
- **Leaving a bank or a vendor the companion closes a frame before the backpack**
  (`addon.CloseInteractionWindow` sends `bags/OpenClose` later). Chained right, the companion is the
  chained bag and leaves through the backpack's edge, then the backpack through its own. Chained
  left, the companion is the anchor: while it slides out, the backpack beside it is held where it is
  (`chain:Holds`, `panel:Hold`), so it leaves after it through the bank's edge when it closes a frame
  later, instead of first flying home across the screen. One that stays open goes home once the
  anchor has gone: the end of a slide-out updates the chain (as `OnHidden` does; also for a hide
  whose `OnHide` does not run, as in the specs' frames). A bag still at its own edge is never held.
  The whole addon, through `BANKFRAME_CLOSED` and the banker interaction's hide: chained left the bank
  goes 0 to -620 and the backpack -800 to -2016, chained right the backpack 0 to 620 and the bank 800
  to 2016.
- **Screen changes** (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`, registered in BetterBags Next's
  event scope) place the bags at once; a screen too narrow keeps them apart without changing the
  saved layout.

### 12b. Spacing

- **The gap** between the two bodies (`chain:Gap`) is both tab rails (each `NextTabRail:Width()`,
  its widest tab, plus the hover slide) and `style.Chain.TabMargin`, never less than the two feathers
  (192). A tab renamed or added re-lists the rail, whose resize handler (`SetResizeHandler`) runs
  `chain:Update`, so the chained bag glides to the new gap.
- **The chained bag's offset** from its own edge is the screen less both bodies and the gap
  (`chain:Distance`), so its body edge sits exactly the gap from the anchor's.
- **The far edge.** Away from its screen edge (beside its anchor, or flying) a bag's far side faces
  the middle of the screen: `SetDocked(false)` stops the fill and the wash at the frame and shows
  `outerFeather`, the body's color fading out over `style.Chain.OuterFeather` (48) pixels beyond it
  (it was the full 96 of the inner feather; asked: "too heavy. tone it down a bit"); back at its edge
  the fill and wash reach `OVERREACH` past it again. The switch happens at offset 0, where both are
  off the screen, so it never shows.
- **Coupled, the inner feathers grow into the gap** (`panel:growFeather`, from `SetCoupling`): each to
  `style.Chain.CoupledFeather` (0.65) of the gap the pair rests at, never under 96, with the coupling's
  amount, so it grows as they couple and shrinks as they part. Past the middle, the two fades overlap
  and the bags look closer; under the whole gap, there is still a gap. The texture keeps its anchor on
  the frame's inner edge, pushed past it by the growth and widened as much, so it still starts at the
  body edge. Asked: "grow the feathering between two coupled bags a bit when things are coupled, so
  they appear a bit more closely together (still a gap, just not as drastic)".

### 12c. Motion

- `panel:FlyTo(to)` flies a bag (`style.Time.Fly`, 0.45 s, in-out cubic: slow off the mark and
  into place, three times its average speed in the middle); `PlaceAt` places it at once. The first
  flights, 0.7 s with an in-out sine (only about 1.6 times its average speed at its fastest), felt
  "too slow and... linear almost".
  `panel.target` is where it is headed, `RestOffset` where it rests. A flight that takes over an
  opening slide still runs the slide's `onShown` (`finishShowing`), so a bank open still loads once
  its panel has come to rest (refresh-scheduler.md §11).
- Moving both across, the two flights start together with the same duration and ease, so the gap
  between them stays exactly the same all the way.
- A chained bag's entrance takes `style.Time.Enter` (0.5 s) with `outBackSoft`: quick off the mark,
  settling about a fiftieth of the way past its place and back ("fall in place"; `outBack`'s tenth
  would be over a hundred pixels on a move across the screen). Its sections cascade in as it starts
  coming in (`moveIn`), not while it waits. An ordinary opening is the 0.45 s slide with its bounce.
  Coupling takes 0.35 s, letting go 0.25 s.

### 12d. The coupling

Once the chained bag has come to rest beside its anchor (`chain:Arrived`), the pair couples
(`chain.coupling`, `amount` 0 to 1 over `style.Time.Couple`, 0.35 s); it uncouples (back to 0 over
`style.Time.Uncouple`, then ends) as soon as they are no longer chained or one closes. Moving both
across keeps the coupling and swaps the roles. `chain:UpdateCoupling` (and `Arrived`) returns what
it did for profiler traces: `"coupled"`, `"kept"`, `"on its way"`, `"letting go"`, `"apart"`.

- **A place is the same within half a pixel** (`PLACED`), and the rails' widths are the ones they
  set (`tab.width`), never read back with `GetWidth`. **Failure mode (fixed):** reported, the tangle
  "only appears sometimes", never at the bank, and at a vendor only after clicking the vendor again.
  The pair coupled only when the chained bag's target equalled its rest place, recomputed, exactly,
  and that place came from the tabs' `GetWidth`, which the client hands back with float error at a
  UI scale (window.md §3b, layout-rendering.md §4). Off by a hair, the pair never coupled, until
  something listed the tabs again (clicking the vendor again does), which flew the bag the hair and
  coupled it. The specs' frames return exact sizes, so nothing reproduced it until a test read the
  widths back with a 0.0001-pixel error. Either fix alone covers that test; both are kept. Not
  confirmed with a capture: the client's float error is measured in other recordings, its role here
  is concluded from the symptoms and that test.
- **A pair formed while another let go** (one companion closing as another opens, the backpack in
  place) couples as soon as the old coupling ends: the end of letting go checks the pair again.

- **The braid.** Each bag draws its half (`panel.braid`, `BuildBraid`, `SetCoupling`, `applyBraid`):
  two strands of 16 additive gold `Line`s (`Frame:CreateLine`, on every client's API documentation)
  from its body edge to the middle of the gap. A strand's height above the ribbon at `d` pixels from
  the body is `±amplitude · sin(π d / 2h) · sin(k s + phase)`, with `s` the signed distance from the
  middle of the gap (`d - h` on the left bag, `h - d` on the right), so the halves meet at the middle,
  the strands swell from nothing at the bodies, the second mirrors the first and they cross; the
  strand in front by the turn is brighter. Each bag's half is drawn on its own layer
  (`braid.layer`, 40 levels above the panel): a coupled bag's grown feather reaches into the other
  bag's half, and would cover that half if the braid were one of the panel's own regions. Lines are
  only ever re-pointed with
  `SetStartPoint`/`SetEndPoint` (`Line:ClearAllPoints` is marked protected).
- **Shared turn.** One driver (`chain.driver`) turns the braid (`style.Chain.Turn`) and lays both
  halves out in the same call, so they never fall out of step; it runs only while coupled, every
  frame, so the braid follows the bags as they move: half the gap is measured from where they are,
  so the braid stretches and untwists as a chained bag flies home.
- **The ribbons** reach the middle of the gap while coupled (`panel.ribbonLength`), back to 300 as
  they let go, and the shimmer runs along that length.
- **Lights and the knot.** Three lights run along each half from its cloud to the knot in the middle
  (`style.Chain.BeadTime`); the chained bag shows the knot, a soft gold puff that flashes as they
  couple (`BurstKnot`), with a burst of sparkles (`knotSparkles`, `NextSparkleEmitter:Burst`).
- **Sparkles.** Coupled, ribbon sparkles are born and die within the first half of the gap. Edge
  sparkles keep drifting off both bags' inner feathered edges into the gap, chained or not, and die
  before the other bag (at most 36 * 4.2 + 24 pixels out; the gap is at least 192). An earlier version
  stopped the anchor's and moved the chained bag's to its far edge; asked: "the small sparkles along
  the bags stop when they are coupled, let's not do that".

### 12e. Coverage

`spec/next/chain_spec.lua` (the layouts and each role; the gap from the tabs and the feathers;
each click: flying either way, putting back, moving across together with the gap held, alone, no
room, a tab renamed, the screen's size or the UI scale changing (placed at once), a screen too
narrow; opening alone at its edge, flying to a companion that opens, coming in from behind its
anchor, staggered after an anchor coming in, falling into place, its sections cascading in only then,
a companion waiting for the backpack and coming in after it, saying it has shown only once in place,
coming in alone when the backpack does not open, closing while waiting, flying home from its own
edge when its anchor closes before it came in, not waiting for an open backpack, the bank beside the
backpack, flying home when the anchor closes or is hidden, `onShown` across a flight; closing through
the anchor's edge beneath it, held while the anchor leaves then leaving after it, going home once the
anchor has gone, and through its own edge when alone at it, sliding in while the anchor leaves, on a
screen too narrow, on its way home after the anchor was hidden (both layouts), and as the anchor of a
pair moving across; the far edge both ways, toned down; coupling with tabs read back with float
error, within half a pixel, a new pair after the old let go, the inner feathers growing and
shrinking, the braid above both feathers, edge sparkles kept running, coupling after the flight,
the braid's geometry, its turn and lights, staying coupled while moving across, untwisting and
stretching as they part, letting go on a close, the knot's burst; the title's
tooltip and glow), `spec/next/vendor_spec.lua` ("chaining": the vendor is a companion, its name goes
to the chain), `spec/next/sparkles_spec.lua` (`Burst`), `spec/next/tabs_spec.lua` (`Width` from the
widths set), `spec/next/tween_spec.lua` (`outBackSoft`), `spec/database_spec.lua` and
`spec/core/constants_spec.lua` (the setting). The frame mock gained `CreateLine` from Blizzard's API
documentation. 47 mutations; the five that first survived led to tests of the screen events, the
entrance's own target and timing, the braid running on through the knot and the burst's sparkles,
and to removing a per-move redraw the driver already does. The coupling and entrance fixes: 21
mutations; the five that first survived led to tests of the rail's width, a bag at rest within half
a pixel, the companion not waiting for an open backpack and the delayed cascade, and to removing a
check the half-pixel rule already makes. The exit, feather and sparkle changes: 24 mutations; the five
that first survived led to the edge-case closing tests above.

Seen in game (the player): the whole of §12, including closing through the anchor's edge, the
feathers and the sparkles.
