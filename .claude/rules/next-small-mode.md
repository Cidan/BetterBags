---
paths:
  - "next/panel.lua"
  - "next/chain.lua"
  - "spec/next/small_spec.lua"
---
## 14. Small mode (`next/panel.lua`, `next/chain.lua`)

A second size for every Next panel: smaller, movable panels that keep Next's look, for players on
smaller screens. The plan, the reasoning and what was asked are in `docs/next-small-mode.md`
(asked: "the biggest pain is two panels open for people with smaller screens ... a smaller panel,
like ESO ... a panel we can move ... a button toggle to swap between small and full mode (animated
of course)"). Phase 1 is small panels, moving them and switching sizes (§14a-d); phase 2 is chaining
small panels by dragging them together (§14e); then resizing them with grips (§14g: next-small-resize.md, and fitting their names, next-small-names.md); then as tall as what
they show (§14i, Autosize Bags: next-small-autosize.md).

### 14a. The setting and the size

- `nextSize` (profile, `"small"` by default; `DB:Get/SetNextSize`, nothing else accepted) is every
  Next panel's size. Asked (2026-11-04): "by default, bags in next start in minimized mode"; it was `"full"`.
  AceDB saves only what differs from a default, so a profile on full before this, chosen or not, saved
  nothing and starts small too; one already on small is unchanged.
  - **Left as it is, for the player to decide (found by the bug review, computed with the real modules):** with no
    saved place, the small backpack sits 40 in from the right edge and every companion 40 in from the left
    (`SmallPlace`), each regardless of the other, so on a screen under 996 units wide (1280x1024 at UI scale 1: 960)
    the two overlap by default (36 units there; 106 at 1024x768 and 1.15). It was so before for players who chose
    small; small being the default makes it every unsaved profile's at the bank, a vendor or the guild bank.
  - **Coverage:** the whole-addon specs that start BetterBags Next now run small panels; Papercraft's "full size and
    small" starts full (it had started on the default).
  `nextSmallCorners[kind]` (`DB:Get/SetNextSmallCorner`) the corner each kind's small panel holds where it was left (one of
  its four corners in UIParent's units, and which, its side and its edge: next-bag-anchor.md §30a), nothing until first
  placed; the
  top left it was saved by before (`nextSmallPlaces`) is taken over as it first shows;
  `nextSmallSizes[kind]` (`DB:Get/SetNextSmallSize`, `{ width, height }`) the size the player gave it
  with its grips (next-small-resize.md §14g), nothing while it is the default size (a reset clears it); with Autosize Bags on
  (next-small-autosize.md §14i) its height is kept for when the setting is off, and a grip saves only the width.
- Each panel keeps its own `size`, read from the setting when it is made, so a panel can be part way
  through a switch (§14d). `IsSmall`, `Height`, `Width`, `BodyLeft`, `RibbonBase` and
  `SparkSpreadBase` answer for it.
- The knobs are the Next theme's `Small` (next-themes.md), read through `style.Small`: the height share
  (0.66), the beam (120) and how far out along it its sparkles are born (48), the open slide (24), the
  default margin (40), the grips (`Grip`) and the least room kept for the title (`MinTitle`, 60); the
  edge's alpha is `Panel.Edge.Alpha` (0.35). `Motion.Time.Morph` (0.4 s) is the switch,
  `Motion.Time.Resize` (0.4 s) the glide back to the default size.

### 14b. The geometry (`ApplyGeometry`)

One function shapes a panel for its size and places it at its offset, run when it is made and at the
end of a switch. `BuildPanel` only makes the parts.
- **Full** is unchanged (next.md §3): the frame on its screen edge, top to bottom; the body inside the
  feather; no clicks over the feather (hit rect insets); the fill and the wash reaching past the
  screen edge while docked (`SetDocked`).
- **Small:** the frame is the body, its size `SmallSize`: the size the player gave it (next-small-resize.md §14g), else
  `BODY_WIDTH` wide (the full body's) and a share of the screen tall (whole units), never below its
  minimum nor past the screen; with Autosize Bags on, as tall as what it shows (`RestingHeight`, next-small-autosize.md §14i). It is anchored by its top left at its place (`SmallPlace`: over the
  corner it holds at its size now, next-bag-anchor.md §30a, so it grows up and away from its held side; where it was left,
  else a margin in from its own screen edge, its bottom where a bag of the default height centered has it; kept on the
  screen while Clamp Bags to Screen is on, `clampPlace`, for its own width, and on whole pixels either way). No feather, clicks everywhere, a 1-pixel lavender edge all round (`edges`), the
  shorter beam, a grip on each bottom corner (next-small-resize.md §14g). `SetDocked` does nothing to a small panel (it is
  never at its screen edge). The render root hands the content the body's width less its padding
  (`BodyWidth`: the full body's at full size, a small panel's own) and the panel's height less its
  header and footer.
- **Sparkles follow the geometry:** every emitter computes its spawn points from `BodyLeft` at spawn
  time (they were constants of the full width), so the edge sparkles still drift out of a small
  panel's inner side and the ribbon's along its shorter beam.

### 14c. Opening, closing and moving a small panel

- **Opening:** it takes the screen as it is (`FitSmall`: its height, a place still on the screen),
  then slides `Small.Slide` in from its edge side as it fades in (`setOffset` for a small panel is
  its place plus the offset, its alpha falling with the distance; `HiddenOffset` is the slide). The
  sections cascade in as before. Opened again while it slides out, it comes back from where it is, fitted as any
  opening is (`FitSmall` keeps its offset, so the slide goes on from where it is and the edge its place holds stays): a
  draw while it slid out (a long name looted in) was left cut until it next opened, setting on or off (found by the
  second bug review; `Show` fitted only a panel that had finished closing, a skip no test held).
- **Closing:** the reverse. Every way of closing works as before. `chain:ExitOffset` never sends a
  small panel off through a partner's edge: the full mode's chain layout (`nextChain`) is kept for
  full mode, and would otherwise fly a small bag across the screen.
- **Moving:** dragging the title row (`mover`: the body's top down to the search box, under the
  header buttons, which stay clickable above it) or the title (`titleButton`) calls `StartMove`
  (`frame:StartMoving()`) and `StopMove`: the place, kept on the screen while the bags are clamped to it,
  is saved for the kind (the corner it holds there, on the half of the screen its middle is on: `SavePlace`,
  next-bag-anchor.md §30a) and the frame anchored there again (the client anchors a moved frame to the
  nearest screen corner). A held bag does not move (locked, next-bag-anchor.md §30d).
  - **Clamp Bags to Screen** (window.md §3a, one setting for every bag, off by default): a small panel's
    frame is clamped (`ApplyClamp`, from `ApplyGeometry`) and its place kept on the screen (`clampPlace`:
    a move, a resize, a snap, a reset glide, a chained spot, the screen changing, opening) only while it is
    on. Off, the place is only put on whole pixels, so a panel goes where the player puts it, off the
    screen too. A full panel is never clamped. `bags/ClampChanged` (registered by the chain with its screen
    events, in BetterBags Next's scope): `chain:ClampChanged` applies every panel's clamp; turned on, each
    open small panel is fitted again (`FitSmall`: a chained one beside where its anchor is put back, which
    `LivePlace` reads already clamped) and its place saved, so turning it off again moves nothing. A closed
    one is put back as it opens. Coverage: `spec/next/small_spec.lua` ("with Clamp Bags to Screen": moved off
    the screen on whole pixels, opening off it, a screen change, turning it on (saved; a closed one as it
    opens), turning it off (nothing moves, also a panel the screen's edge put back), a chained bag beside its
    anchor, a full panel untouched).
  - `StartMoving` flags a frame user-placed, and the client then restores a named frame's place from
    its layout cache at login (warcraft.wiki.gg Frame:StartMoving): `StartMove` clears the flag
    (`SetUserPlaced(false)`), as the wiki says to.
  - No move with something on the cursor: pressing on the bag is a drop. The mover passes drops and
    clicks with an item to the bag, like the rest of the panel (`PlaceCursorItem`).
  - An opening slide is finished first. Hiding ends a move (`OnHidden`).
  - Nothing in the panels is protected (`BankPanelPurchaseButtonScriptTemplate` is not), so moving
    works in combat (`StartMoving` is blocked only on protected frames).
- **The screen changing** (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`, `chain:Update` with snap)
  refits an open small panel and lays its content out again; a closed one refits when it opens.
- **The full chain** (next-chain.md §12) leaves small panels alone: never paired (`Pair`), never placed by the full
  layouts (`Update`), never sent through a partner's edge (`ShownAnchorOf`); a small panel's title's
  click does nothing (`Click` returns `"small"`) and its tooltip says to drag it. Small panels chain
  their own way (§14e).

### 14d. Switching sizes (`nextPanel:SetSize`, `PrepareResize`, `Morph`)

- **The button** (`sizeButton`, the backpack's header, after the button back to the classic bags):
  arrows pointing in while full and out while small (the theme's `sizeButtonFull` and
  `sizeButtonSmall` icons, `SizeIconKey`, next-themes.md §11), with a tooltip. Blizzard's red minimize
  and maximize art stood out among the flat icons. A click calls `nextPanel:SetSize(ctx, size)`,
  which returns `"switched"` or `"same"`.
- **SetSize** saves the size, lets go of a coupled pair's braid at once (`chain:LetGo`), switches
  every panel (`PrepareResize`), then starts the switch of every shown one (`Morph`): where a full
  panel rests depends on its partner's size, so every panel has its new size before any target is
  computed. Then every panel updates its size button.
- **A panel not shown** (a closing one finishes closing first) takes the size at once and lays its
  content out for its new height (its root renders while hidden: it has no `ShouldRender`).
- **A shown panel switches in two steps** (`Morph`). Its opening slide or flight is finished, its
  body's place and size are kept (`BodyRect`), and it gets the new size's parts at once
  (`ApplyGeometry`); the frame is then anchored by its top left and sized as it goes (the body plus
  the feather at full size), so the body only moves and stretches. Nothing reaches past the screen
  edge on the way (`SetDocked(false)`).
  - **The glide** (`inOutCubic`, `Time.Morph`): the body from where it was to where it rests (its
    small place, or its full rest offset, `chain:RestOffset`) and from its width to the new size's (a
    small panel the player sized is wider or narrower than the full body, next-small-resize.md §14g; when the body
    narrows, the content is laid out at once for the width it ends at, so nothing is cut off on the
    way, and again at the end), the beam shortening or growing, and
    what the old size had fading out on the way: shrinking, the feathers (a shrinking panel's feather
    beside its inner side, re-anchored there; the far feather, `outerFeather`, with it); growing, the
    small border.
  - **The fade** (`inOutSine`, `Time.MorphFade`): what the new size has, once it is there: shrinking,
    the small border fades in; growing, the feathers fade in (the far feather only when it ends away
    from its screen edge, beside its partner: at the edge a full panel has none).
  - **The feathers fade through their gradients** (`paintFeathers`, which also draws them when the
    panel is made): a feather is a gradient texture, its alpha in its vertex colors, and faded with
    `SetAlpha` it did not fade at all in game (reported); the wash has always faded this way
    (`paintWash`). See `patterns-ui-themes.md`, "Fade a Gradient Texture Through Its Colors".
  - **Why:** the edge used to cross-fade with the feather over the whole glide, so the border showed
    while the feather was still there, "making it look like the feathering is spilled out"; asked
    for "a 2 step animation". Growing first let the border go before moving, and "it doesn't feel
    good that it doesn't start moving right away": it moves at once, the border fading on the way,
    then the feathers fade in, "basically the inverse of shrinking". The edge also hung on the frame,
    which for a full panel reaches over its feather, so a growing panel's fading border outlined the
    feather too: it hangs on the body now.
  - The content is laid out once, at the end. At the end it couples again if the new size chains it
    (`chain:Arrived`; `UpdateCoupling` waits while either bag of the pair still switches).
- **Switched back mid-switch,** it turns around from where it is (`morph.at`: its place, height, beam,
  feathers and border), the first switch stopped. A step with nothing to do is skipped (switched twice
  in a row, it ends where it started at once), and a fade part way done takes only its share of
  `MorphFade`.
- **Anything that places the panel ends a switch first, both steps** (`setOffset` calls `endMorph`,
  which stops the step playing and puts the panel at the switch's end; every slide, flight and refit
  goes through it), and so does `StartMove` (it moves the frame itself). Showing an
  open panel again (a refresh) does not end it.

### 14e. Chaining small bags by dragging them together (`next/chain.lua`)

Asked: "they can still chain to each other if dragged close by. still want the sparkles between
them/coming out the side though!"
- **The small chain** is its own setting, `nextSmallChain` (`DB:Get/SetNextSmallChain`): `"apart"`,
  `"backpack"` (a companion was dropped beside the backpack: the backpack anchors) or `"companion"`
  (the backpack was dropped beside a companion, and sits beside whichever is open). Full mode's
  `nextChain` is untouched; each size keeps its own chain.
- **Where a chained bag sits** (`ChainedPlace`): a companion left of the backpack, the backpack right
  of a companion (only their facing sides chain), each as wide as the player made it (next-small-resize.md §14g), bottoms
  aligned (each holds its bottom and grows up, next-bag-anchor.md §30a; they were tops aligned), `SmallGap` between them (both tab
  rails, each its widest tab plus the hover slide, and a margin; at least `Small.MinGap`).
  `SmallPlace` of a chained bag is that spot beside its anchor where the anchor is now
  (`LivePlace`: under the mouse while dragged, else its place, saved or default, so a companion opens
  straight beside where the backpack was left, open or not). There is no waiting for the anchor.
- **Dropping beside a partner chains** (`chain:Dropped`, from `StopMove`): an open small partner, the
  dropped bag's spot beside it on the screen, and the drop within `Small.SnapReach` (80) across and
  `Small.SnapRise` (160) up or down of it. The partner becomes the anchor, the dropped bag glides into
  its spot (`GlideTo`, `Time.Glide`), its place saved there. The glide closes the distance it starts from its spot with
  the spot as it is on each frame (`SmallPlace`) while the bag it glides beside is still its anchor (`chain:SmallAnchorOf`,
  read as it starts), so an anchor whose size glides meanwhile (its names, next-small-names.md §14g) carries it
  along: the anchor's glide places it too (`spotGlide`), whichever of the two goes first in a frame, and it ends beside the
  anchor where the anchor ends. It glided to the spot as it was at the drop, and lerped from where it set out: a bank
  dropped beside a backpack gliding wider for a name overlapped it by 136 pixels (found by the second bug review). An anchor
  that lets it go on the way (a bank closing is no longer the chain's companion, `chain:Companion` being an open one) leaves
  it going to the spot it read last, as before the second review: read on, the spot became the backpack's saved place and
  it jumped back 10 units as the bank closed (found by the third bug review).
- **Dragging the anchor moves both:** its partner (`chain:Follower`) is placed beside it every frame
  of the drag (the mover's `OnUpdate`, cleared at the drop; a glide into its spot is finished first),
  the braid with them; at the drop both places are saved.
- **Dragging the other lets it go** (`chain:Detach`, from `StartMove`): the chain is `"apart"` and the
  braid comes apart at once; dropped back beside the anchor, it chains again.
- **The braid** (`UpdateCoupling` with `SmallPair`, `applyCoupling`): once both are open and still
  (`SmallPlaced`: neither sliding, gliding or switching size), their ribbons twist into the braid
  across the gap between their bodies where they are now (`SmallLeft`), the chained bag showing the
  knot, which bursts. One of the pair closing lets go; it braids again when it opens.
- **Sparkles between them, never over them:** the ribbon sparkles shorten as in full mode; a braided
  small bag's edge sparkles live shorter and drift slower (`SetCoupling`), so they die before the
  middle of a narrow gap (born up to 24 out, 24 + half the gap / 2 stays below the gap, which is at
  least 64). Apart, they drift as before.
- **When a chained bag's spot moves** (the gap changes: a tab rail grows; its anchor's size glided while it was busy,
  `spotMoved`, next-small-resize.md §14g's snap, which settling it clears, as anything else that puts it on its spot does), it glides there
  (`chain:Settle`, from `Update` and `Arrived`; `GlideTo`, above), but never while it slides in or switches size: a
  slide's end says the bag has shown (a bank open waits for it), so it settles once it arrives. A bag
  chained to a closed backpack stays where it is.
- **A companion closing leaves the backpack beside it where it stands** (`chain:Released`, from the companion's `Hide` and
  `OnHidden`): the backpack beside a companion (layout "companion") has an anchor only while a companion is open, then reads its
  own saved place. As a small companion closes (not a parent hiding it), the open backpack's place is saved where it stands,
  its bottom its spot's beside the companion (never one pushed down to keep its top on the screen, next-bag-anchor.md §30a), so
  whatever moved it beside the companion (the companion's glides
  and refits, its glide into its spot) is where it is placed from. Found with Autosize Bags (next-small-autosize.md §14i): its
  next height glide took it back to where it was dropped.

### 14f. Coverage

`spec/next/small_spec.lua` (116, the resizing tests listed in §14g, next-small-resize.md and next-small-names.md): the geometry (size, place, no feather, the edge, the beam, sparkles
on both sides, the root, a saved place kept on the screen), opening and closing (slide and fade,
reopening mid-close, the screen at opening, never chained, closing with a chain layout saved),
moving (by the title row and the title, saved per kind, the layout cache flag, kept on the screen,
the cursor, finishing the opening, hiding, header buttons above the mover, the screen changing, full
panels never move), switching sizes (the button's art on retail and Classic, its place and tooltip,
saving, closed panels with their content laid out, the glide's path both ways, the two steps both
ways (the feather and beam with the size, the border only after shrinking and before growing, the far
feather with the near one), the border round the body, nothing past the edge, one layout at the end,
a close or a move mid-switch (both steps finished), a closing panel, a pair's braid let go and
braided again only once both arrive, turning around mid-glide and mid-border, a border brought
straight back, Escape mid-switch, a refresh mid-switch, the feather's anchors after both ways), chaining (the gap, dropping
beside either partner, too far, too high, facing away, a pair that would not fit, the braid's
halves and knot, the edge sparkles in the gap and back, the anchor moving both, letting go and
chaining again, opening beside an open anchor, beside where it was left, the backpack beside a
companion, closing and reopening one of the pair, a spot that moves, one that moves while sliding in
or switching size, a closed anchor, a partner gliding when the anchor is dragged, each size's chain).
`spec/database_spec.lua` and `spec/core/constants_spec.lua` (the settings). The other Next specs run
full size. Every guard was mutation-tested (80 mutations): the redundant ones it found were removed
(nine), each one it showed untested got a test, and it found one bug before it shipped (a glide that
would have cut a bag's slide in short, dropping what waited for it to show).

Not verified in game yet: how the small panels look, the glide, and moving them.

§14g, resizing a small panel, is in next-small-resize.md, and its continuation, fitting its title and its sections'
names (Fit Names While Open), in next-small-names.md.

### 14h. Bag Scale (Appearance → Size)

Asked: a "bag scale" slider on Appearance's Size tab; "bag scale should just not apply when docked to
the side"; and, on the risk of drags and chaining in a scaled panel: "it's not risk, it's just work ...
just get it done with tests" (docs/next-appearance-size.md).

- **The setting:** `nextBagScale` (profile, a whole percentage in 50 to 150, 100 by default;
  `DB:Get/SetNextBagScale`), one value for every Next panel, so chained bags match. Its slider sends
  `next/ScalesChanged`; the chain (`chain:ScalesChanged`) has every panel draw again (`ApplyScales`), then refits
  every open small panel (`Update`, snapping: `FitSmall`, which takes the scale); a closed one refits as it opens. The
  refit refits a panel whose size glides too, its glide ended first (found by the second bug review: a glide under way
  kept the old scale and size), so a panel the draw set gliding toward its width at the new scale while still at the old
  one (Fit Names While Open on; found by the bug review, which had refitted first, an order the third found moot, next-small-names.md §14g)
  is refitted at the new scale. Only one a grip holds is left alone, as before this change: a Bag Scale given while a
  grip holds it is accepted as it is (the frame keeps its old scale until something refits it; its let-go is computed at
  the new scale), two inputs at once that nobody has seen.
- **The same layout at every scale:** items keep their rows and columns at every Bag Scale; a layout is
  decided in units, never on lengths rounded to the panel's grid (`LayoutWidth`, next-pixel-perfect.md §3).
- **Small panels only:** `panelProto:Scale()` is the Bag Scale for a small panel and 1 for a full one.
  `ApplyGeometry` and `FitSmall` give the frame that scale (`SetScale`); everything in it (art, text,
  item buttons, sparkles, the braid) scales with it.
- **Units:** a small panel's place (`placeX`, `placeY`, `nextSmallCorners`) stays on the screen, in
  UIParent's units; its size (`smallWidth`, `smallHeight`, `nextSmallSizes`, `MinWidth`, `MinHeight`) is
  in its own units, as its content is laid out. On the screen it is its size times its scale. A scaled
  frame's anchor offsets are in its own units (`setOffset`, `GlideTo`, the reset glide divide by the
  scale), and its edges are read in its own units (`LivePlace`, `SmallLeft`, `StopMove`, `StopSizing`
  multiply by `NextLift:ScaleOf`). The default size is the full body's width and the theme's share of the
  screen in its own units, so the whole default panel scales; the screen bounds its size at its scale
  (`SmallSize`, the grips' `SetResizeBounds`), and `clampPlace` and the default place use its size on
  the screen.
- **The small chain** works on the screen: `SmallGap` is each rail's widest tab plus the hover slide at
  its bag's scale, the margin and `Small.MinGap` at the larger scale; `ChainedPlace` and `Dropped` use
  each bag's width on the screen; the braid's half gap is measured on the screen and handed to each bag
  in its own units (`SetCoupling`).
- **Switching sizes** glides the scale with the body's place and size on the screen (`BodyRect` returns
  them and the scale; `Morph`'s `draw` sets the scale and anchors and sizes the frame in its own
  units); the content is laid out at once when the body ends narrower in its own units.
- **Everything read on the screen goes through NextLift** (`ScaleOf`, `Center`, `ScreenPoint`): a
  lifted frame keeps its size on screen (`Pick` starts from its scale there, `base`, shrinks from it,
  lands back at it unless its owner names another, flies away from it); the section drag's gap under the
  cursor and its landing, the flight into a tab or a panel, scrolling near the edges (`AutoScroll`), the
  dock's flights, a tab moved in its rail, and the settings lists' reordering (the settings window
  scales itself down to fit a small screen, which had the same mismatch). Before, these read a frame's
  edges as if every Next frame were at scale 1.
- Coverage: `spec/next/small_spec.lua` ("the Size tab's scales" → "Bag Scale": scale and default place,
  full panels untouched, kept on the screen and never bigger, moving, sizing, the reset glide, a live
  change, the chain both ways, the screen's edges, the braid, the glide into a spot, an anchor dragged
  with its chained bag, switching sizes both ways and while closed, the early layout),
  `spec/next/lift_spec.lua` ("a frame in a scaled panel"), `spec/next/drag_spec.lua` ("in a scaled
  panel"), `spec/next/dock_spec.lua`, `spec/next/tabs_spec.lua`, `spec/next/settings/reorder_spec.lua`.
  58 mutations: 11 first survived; 10 led to tests, one showed a refit already done by the chain, removed.
