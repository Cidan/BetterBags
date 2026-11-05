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
small panels by dragging them together (§14e); then resizing them with grips (§14g).

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
  `nextSmallPlaces[kind]` (`DB:Get/SetNextSmallPlace`) where each kind's small
  panel was left (its top left in UIParent's units), nothing until first moved;
  `nextSmallSizes[kind]` (`DB:Get/SetNextSmallSize`, `{ width, height }`) the size the player gave it
  with its grips (§14g), nothing while it is the default size (a reset clears it).
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
- **Small:** the frame is the body, its size `SmallSize`: the size the player gave it (§14g), else
  `BODY_WIDTH` wide (the full body's) and a share of the screen tall (whole units), never below its
  minimum nor past the screen. It is anchored by its top left at its place (`SmallPlace`: where it was
  left, else a margin in from its own screen edge, centered; kept on the screen while Clamp Bags to
  Screen is on, `clampPlace`, for its own width, and on whole pixels either way). No feather, clicks everywhere, a 1-pixel lavender edge all round (`edges`), the
  shorter beam, a grip on each bottom corner (§14g). `SetDocked` does nothing to a small panel (it is
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
  sections cascade in as before. Opened again while it slides out, it comes back from where it is.
- **Closing:** the reverse. Every way of closing works as before. `chain:ExitOffset` never sends a
  small panel off through a partner's edge: the full mode's chain layout (`nextChain`) is kept for
  full mode, and would otherwise fly a small bag across the screen.
- **Moving:** dragging the title row (`mover`: the body's top down to the search box, under the
  header buttons, which stay clickable above it) or the title (`titleButton`) calls `StartMove`
  (`frame:StartMoving()`) and `StopMove`: the place, kept on the screen while the bags are clamped to it,
  is saved for the kind and the frame anchored there again (the client anchors a moved frame to the
  nearest screen corner).
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
    small panel the player sized is wider or narrower than the full body, §14g; when the body
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
  of a companion (only their facing sides chain), each as wide as the player made it (§14g), tops
  aligned, `SmallGap` between them (both tab
  rails, each its widest tab plus the hover slide, and a margin; at least `Small.MinGap`).
  `SmallPlace` of a chained bag is that spot beside its anchor where the anchor is now
  (`LivePlace`: under the mouse while dragged, else its place, saved or default, so a companion opens
  straight beside where the backpack was left, open or not). There is no waiting for the anchor.
- **Dropping beside a partner chains** (`chain:Dropped`, from `StopMove`): an open small partner, the
  dropped bag's spot beside it on the screen, and the drop within `Small.SnapReach` (80) across and
  `Small.SnapRise` (160) up or down of it. The partner becomes the anchor, the dropped bag glides into
  its spot (`GlideTo`, `Time.Glide`), its place saved there.
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
- **When a chained bag's spot moves** (the gap changes: a tab rail grows), it glides there
  (`chain:Settle`, from `Update` and `Arrived`), but never while it slides in or switches size: a
  slide's end says the bag has shown (a bank open waits for it), so it settles once it arrives. A bag
  chained to a closed backpack stays where it is.

### 14f. Coverage

`spec/next/small_spec.lua` (116, the resizing tests listed in §14g): the geometry (size, place, no feather, the edge, the beam, sparkles
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

### 14g. Resizing a small panel (the grips)

Asked: "a window handle when in minimized mode that lets users resize the window, dom like, just like
the original bags ... make this resize static though, i.e. no snapping"; then grips on "both sides,
but disable it on the side it's chained on, if it's chained"; the room left past the last icon "all on
the right ... let's not center in the next design"; "remember what the custom window sizing is"; a
tooltip; "shift + left click the grip to reset to default size (animated, of course)"; and, after
trying them in game, "auto-hide the handles so they only show on hover". Then (2026-10-24) snapping, always on:
"let's bring our snapping windows logic from original bags to next, but make it always on ... when we let go, it
will size down (or up) to the nearest exact width needed to fit the columns the user released it at"; "normalize to
the nearest column that keeps the same column count on screen as the user selected, never normalize such that the
column count changes away from the user"; the height snap "on hold, only X"; "default should probably be exact too".
A first version snapped to the columns a row holds at the width let go at, which left a panel dragged far wider than
its icons as wide as it was (reported with a screenshot: its widest row 14 icons, 25 columns wide): "if i drag the
window to be too big like in that screenshot, it should shrink back down to where the icon is".

- **The grips** (`BuildGrips`, `styleGrips`, the theme's `Small.Grip`): a button on each bottom corner
  of a small panel's body, `Inset` (2) in, `Size` (16) square, drawn with Blizzard's chat size grabber
  (`UI-ChatIM-SizeGrabber-Up`, `-Highlight`, `-Down`: the art of `FloatingChatFrame.xml`'s resize
  button and of the classic bags' grip, on every client), turned around on the left corner (its
  texture coordinates). Full panels have none (`UpdateGrips`). The tooltip reads "Resize", "Drag to
  resize.", "Shift-click to reset to the default size."
- **Seen only under the pointer** (`fadeGrip`): a grip is transparent until the pointer is over it,
  as the classic bags' grip is (`window.lua`, `ShowOnHover`), fading in and out over `Time.Hover` as
  Next's other hovers do; it stays seen while it is dragged, wherever the pointer goes, and fades once
  let go away from it. Transparent, it still takes the pointer, so hovering the corner finds it. A
  theme with `Small.Grip.ShowOnHover = false` shows them at all times; a theme switch sets each grip
  at once for where the pointer is, cutting a fade short.
- **No grip on the chained side** (`chain:ChainedSide`, `UpdateGrips`): a bag chained beside its
  anchor has none on its facing side (its place hangs from the anchor's, open or not), and an anchor
  none on its facing side while its chained bag is open; facing is the backpack's left and a
  companion's right. Updated with the coupling (`chain:UpdateCoupling`, which every open, close and
  chain change reaches) and as a drop chains (`chain:Dropped`); a grip being dragged stays until let
  go. So neither bag's chained side ever moves: the chained bag's spot (`ChainedPlace`) is measured
  from the anchor's facing side, and nothing pushes the partner.
- **Dragging a grip** (`StartSizing`, `Resized`, `StopSizing`): `Frame:StartSizing` from the grip's
  corner (`BOTTOMLEFT` or `BOTTOMRIGHT`) and from where it was pressed (`alwaysStartFromMouse`, as the
  classic window does), within `MinWidth`/`MinHeight` and the screen (`SetResizeBounds`); the corner
  across from it stays still. Its opening slide, a size switch or a glide back is finished first. It
  does not size while closing or moving, nor with something on the cursor: pressing a grip is then a
  drop, which the grip passes to the bag (`PlaceCursorItem`, on release and on `OnReceiveDrag`).
  - **Live reflow, like a web page:** while a grip sizes the panel, the frame's own `OnSizeChanged`
    (`Resized`) fits the title and invalidates the render root, so the content lays out again every
    frame at the new width, as many icons per row as fit; the canvas places everything at once
    meanwhile (`canvas:SetInstant`), so nothing glides behind the moving edge. A size change of its
    own (a switch) lays nothing out from there.
  - **What it shows stays where it was scrolled** (`KeepScroll`): Blizzard's scroll box keeps its scroll percentage
    as its height changes (`ScrollBoxBaseMixin:OnSizeChanged` updates it; the offset is the scroll range times the
    percentage), so a panel scrolled partway moved everything it shows a pixel every few frames as a grip sized it
    (simulated: 15 or 16 frames of 150, on every screen tried; reported: the jitter "on Y, it's ever so slight").
    While a grip sizes it or its size glides, the scroll box's own `OnSizeChanged` (hooked, so after Blizzard's
    handler, before anything is drawn) puts the scroll offset back in pixels (`keptScroll`, read as the grip is
    pressed and as Shift-click's glide starts), as a browser keeps the top of a page where it was; past the end, the
    end. Once nothing sizes it, the scroll box is left to itself. Blizzard's full update keeps the offset when the
    content's height changes (`FullUpdateInternal`), so a reflow keeps it too. The specs' mock of the scroll box now
    does both, as Blizzard's does: it kept the percentage on a full update and had no `OnSizeChanged`.
  - **Recorded** while the render recorder records (`recordSizing`, render-recorder.md §2): each step of the sizing and
    of its glide, with where the client put the panel and a few icons in screen pixels with their fractions.
  - **Let go, it shrinks to its widest row of icons** (`StopSizing`, `SnapWidth`; in columns what they need, next-columns.md §7a): its widest row as laid out
    where it was let go, in units: as many cells as a row holds there (`NextCanvas:PerRow`, the canvas's own row
    rule, icons or the vendor's cards), or as its largest section in the column holds when that is fewer
    (`NextCanvas:Widest`: a gap takes a cell; a section waiting in a dock or leaving is not in the column, one flying
    back is), their width with the gaps between them (`RowWidth`), and the room beside them (`ContentRoom`: the
    padding, the side rail, the scroll box's room for its bar on both sides, read from the scroll box's options,
    `SCROLL_OPTIONS`); the columns a row holds while it lays out no section; never below its minimum. Every row
    stays as it was: a section wider than the panel keeps wrapping where it wrapped, and no column is added, so it
    only ever narrows (a fraction of a pixel aside). The width saved stays when items come and go (a section that
    grows past it wraps). The height stays where it was let go (a height snap is on hold). Saved for its kind with its place (its top left, which the left grip moves: the side
    across from the grip stays still). A press whose snapped width and height are within half a unit of the size
    it had saves nothing (a default-sized panel dragged a little wider snaps back to the default and saves
    nothing), so the default size keeps following the screen. Hiding it (Escape) ends the sizing, snapped
    (`OnHidden`).
  - **The snap glides with the original bags' bounce** (`snapTo`): past its width by Motion's overshoot (a tenth
    of the distance, at most 10, never below its minimum; render-pipeline.md §4c) and back, over `Time.Snap`
    (Default 0.35, the original bags' time, window.md §3b), the edge the grip moved moving. Its content keeps the
    rows and the width it ends at all the way (`panel.snap`: the root hands it `snap.body`, `LayoutWidth` is
    `snap.layout`), so the bounce, inside the scroll box's room, moves no item and closes no gap. It is the size
    glide Shift-click uses (`sizeGliding`, `sizeGlideKey`; they were `resetting`, `resetKey`), so everything that
    follows a panel while its size glides follows a snap too (`LivePlace`, `SmallLeft`, `chain:Update`, a
    partner's spot and the braid), and anything that places, moves, sizes, switches or hides it ends the snap at
    its width (`endSizeGlide`). Both glides size it in whole pixels each frame, as a grip dragged does: its scroll
    box's edge between two pixels drew the icons it clips stretched (texture-sharpening.md §5).
- **Its size** (`SmallSize`): the saved size, else its default width (`DefaultWidth`: the columns the full
  body's width holds, `ColumnsWidth(BODY_WIDTH)`, whatever it shows, so it leaves no room past its last column at
  any Icon Scale and does not change as items come and go;
  exactly `BODY_WIDTH` at 100%) and `Small.Height` of the screen tall; never below its minimum nor past the
  screen, without changing what was saved. An open panel at its default size takes its new default when Icon
  Scale changes (`FitSmall`); a saved size keeps its width. While it is built (its header fits its title before
  its footer and content exist) `SmallWidth` reads the full body's width; `ApplyGeometry` gives it its size.
  - `MinWidth`: room for the shown header buttons, 12, and `Small.MinTitle` of the title (cut short
    past that); for the footer's free slots, 12 and the money (`frames/money.lua`: 128 wide); and for
    one column of icons with the scroll box's room and the padding. `MinHeight`: the header, the
    footer, a section's title and one row of icons (`CellHeight`).
  - `SmallWidth`/`SmallHeight` read the frame while a grip sizes it or its size glides, else the size it
    took last (`smallWidth`, `smallHeight`, from `ApplyGeometry` and `FitSmall`).
  - The room past the last column of icons is left on the right, as a web page's (asked: no centering
    in Next's design); a grip let go snaps it to its widest row, so only a panel held wider by its minimum (its
    header, its footer), at its default width with fewer icons than a row holds, or at a size saved before snapping
    keeps any.
  - It comes back at its saved size after a switch to full size and back. When the screen changes
    (`FitSmall`) it is refitted to it and laid out again if its width or height changed; what was
    saved is kept.
- **The title** (`FitTitle`): a small panel's title stays on one line in the room its shown header
  buttons leave, cut short rather than under them; so does the vendor's at either size (`fitsTitle`:
  a vendor's name can be any length; this replaced its own `fitTitle`). A full panel's other titles
  are as long as they are (width 0, wrapping on). Run by `LayoutHeader`, `SetTitle`, `ApplyGeometry`,
  `FitSmall` and every size change while sized or gliding back.
  - **Justified toward its anchor** (`styleHeader`): left on the backpack, right on the companions.
    Text is centered in a font string's width unless justified otherwise (`justifyH` defaults to
    `CENTER`, `Blizzard_SharedXML/UI.xsd`), and the backpack's title set none, so once small panels'
    titles had a width it sat in the middle of the room it had (reported: titles "shift right" in
    small mode and not at full size, where a title is as wide as its text). The companions already
    right-justified. The frame mock now answers `CENTER` for a font string never justified.
- **Shift-click** (`ResetSize`): the panel glides (`Time.Resize`, `Ease.Resize`) back to its default
  size, the corner across from the grip still (the right grip keeps the top left, the left grip the
  top right), its content reflowing at once on the way as while dragging; the saved size is cleared,
  so the default follows the screen again, and the place saved. It returns `"resetting"`, `"default"`
  (nothing was saved) or `"closing"`. Anything that places, moves, sizes, switches or hides the panel
  ends the glide where it was going first (`endSizeGlide`, from `setOffset`, `StartMove`, `StartSizing`,
  `PrepareResize`, `OnHidden`).
- **Everything that read one width reads each panel's own:** `ChainedPlace`, `Dropped` (a bag too wide
  to sit beside its partner on the screen does not chain), the braid's gap (`applyCoupling`),
  `clampPlace`, the default place, `BodyRect`, the sparkles' spawn points and the root's constraints.
  While a bag is sized or glides back, `LivePlace` and `SmallLeft` read its frame, so a partner's spot
  and the braid follow it, and `chain:Update` leaves it alone (it places itself once let go).
- **Combat:** nothing in the panels is protected, and `Frame:StartSizing` is restricted only on
  protected frames in combat (warcraft.wiki.gg Frame:StartSizing), so resizing works in combat.

Coverage: `spec/next/small_spec.lua` ("resizing it": the grips' corners, art, mirroring and tooltip;
unseen until hovered, fading in and out, kept while dragged, a theme that shows them, a theme switch
mid-fade; sizing from either corner from the mouse, the bounds, the footer's room, live reflow with
nothing gliding, the size kept and saved with its place, the left grip's edge, the title cut short,
a drop, a slide finished first, hiding mid-drag, a press that sizes nothing; the saved size at
opening, clamped, after a switch and back, the width gliding through a switch and the content laid
out early when narrowing, the screen changing (both ways), a wide panel's default and saved places,
the sparkles at its width; Shift-click from both grips, reflowing on the way, at the default size,
while closing, ended by a move, a sizing, a close, Escape and a switch; the chained side without a
grip both ways, after a drop, while dragged, a chained bag resized beside its anchor, a bag being
sized left alone and followed by its partner and the braid, bags of any width side by side, the
braid between them, a bag too wide to chain), `spec/database_spec.lua` ("GetNextSmallSize /
SetNextSmallSize"), `spec/core/constants_spec.lua`. Every guard was mutation-tested (93 mutations,
each caught): the 17 the first pass missed led to new tests, and to removing code they showed was not
needed: a `SetUserPlaced(false)` in `StartSizing` (the flag comes from `StartMoving` and the layout
cache, warcraft.wiki.gg Frame:SetUserPlaced, not from sizing) and the chained-bag branch in
`StopSizing`, which the grip turned off on the chained side made pointless (its chained side never
moves); the same branch in `ResetSize` went for the same reason.

Snapping (2026-10-24): `spec/next/small_spec.lua` ("snapping to its icons": shrinking to the widest row with every
row as it was, a wider section wrapping where it wrapped and no column added, exactly a column count's width kept, a
default-sized panel dragged a little wider snapping back and saving nothing, a new height alone saved, hugging fewer
icons than the default holds, the default width the same whatever it shows, its minimum (and nothing less saved),
the columns with no icons, the bounce and its height still, its rows through the bounce, the left grip's edge, ended
by a grip, a move and a hide, a chained bag's chained side still, a section in a dock left out, cards, dragged again
after a snap; with a side rail; hiding mid-drag snapped; "Icon Scale": the default at the columns it holds, refitted
when Icon Scale changes, a saved size kept), `spec/next/content_spec.lua` (`PerRow`, `RowWidth`, `Widest`),
`spec/render/motion_spec.lua` ("a size snapping"). 38 mutations, each caught; four first survived and led to tests
(the minimum saved, the rail's room, the snap record cleared) or to removing a minimum `ColumnsWidth` repeated.

Not verified in game yet: the hover fade, the glide back, the snap and its bounce, chained bags' grips, and how the
grips look on the other Next themes (Parchment's light paper). A render recording of a resize (render-recorder.md)
would show the reflow and the room left on the right.

### 14h. Bag Scale (Appearance → Size)

Asked: a "bag scale" slider on Appearance's Size tab; "bag scale should just not apply when docked to
the side"; and, on the risk of drags and chaining in a scaled panel: "it's not risk, it's just work ...
just get it done with tests" (docs/next-appearance-size.md).

- **The setting:** `nextBagScale` (profile, a whole percentage in 50 to 150, 100 by default;
  `DB:Get/SetNextBagScale`), one value for every Next panel, so chained bags match. Its slider sends
  `next/ScalesChanged`; the chain (`chain:ScalesChanged`) has every panel draw again and refits every
  open small panel (`Update`, snapping: `FitSmall`); a closed one refits as it opens.
- **The same layout at every scale:** items keep their rows and columns at every Bag Scale; a layout is
  decided in units, never on lengths rounded to the panel's grid (`LayoutWidth`, next-pixel-perfect.md §3).
- **Small panels only:** `panelProto:Scale()` is the Bag Scale for a small panel and 1 for a full one.
  `ApplyGeometry` and `FitSmall` give the frame that scale (`SetScale`); everything in it (art, text,
  item buttons, sparkles, the braid) scales with it.
- **Units:** a small panel's place (`placeX`, `placeY`, `nextSmallPlaces`) stays on the screen, in
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
