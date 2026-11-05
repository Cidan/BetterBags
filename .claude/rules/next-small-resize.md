---
paths:
  - "next/panel.lua"
  - "next/chain.lua"
  - "spec/next/small_spec.lua"
---
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

Fitting its title and its sections' names to its width (the title, names whole, Fit Names While Open) and the bug
reviews of them are §14g (continued), in next-small-names.md.

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
    `SCROLL_OPTIONS`); the columns a row holds while it lays out no section; never below its minimum; then, from
    there, the first grid step that cuts no name short (`FitWidth`, "Names whole", next-small-names.md), which can be wider than where
    it was let go. Every row stays as it was: a section wider than the panel keeps wrapping where it wrapped, and no
    column is added, so it narrows, but for its names (a fraction of a pixel aside). The width saved stays when items come and go (a section that
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
    its width (`endSizeGlide`). A snap so ended settles no chain as it ends (`glideCut`, set while `endSizeGlide`
    finishes it), since what ended it places the panel itself; only a snap that ran to its end runs `chain:Update`
    (found by the bug review, next-small-names.md: a size switch lets go of the braid first, and the glide's end coupled the pair
    again mid-switch). What sizes the frame itself ends the glide first (`ApplyGeometry`, `FitSmall`): the glide's end
    sizes the frame to what it set out for, so ended after (by `setOffset`) it left the frame there while the panel's
    size and the width it lays out for were the new ones, until it next opened (found by the second bug review: a theme
    or a refit mid-glide). Both glides size it in whole pixels each frame, as a grip dragged does: its scroll
    box's edge between two pixels drew the icons it clips stretched (texture-sharpening.md §5). A snap that grows
    (its names, next-small-names.md) has no overshoot (`motion.SnapOvershoot`: none for a size that grows), and its content, laid
    out at the width it ends at, is clipped by the scroll box until the frame reaches it. Where both its edges move (the
    screen's edge puts it back while Clamp Bags to Screen is on), its left edge goes to where it ends with its width
    (`snapTo`'s `toX`), on whole pixels each frame too: it was never put on one, and stood between two on 11 or 12 of a
    names glide's 21 frames and one or two of a grip's (found by the fourth bug review).
  - **The bag chained to it moves only where the glide moves the side it hangs from** (`carries`: its edge on its chained
    side, `chain:ChainedSide`, the backpack's left, a companion's right, or both its edges, `toX`). Then the bag beside it
    (`chain:Follower`, read each frame: one can be dropped beside it and chained while it glides) is placed beside it every
    frame, as beside an anchor dragged (`StartMove`); one gliding into its spot is placed where that glide has it now
    (`spotGlide`, next-small-mode.md §14e); one busy otherwise (`busy`: a Glitch burst's shove is not busy, and placing it ends the burst) is
    left to it, its spot marked moved (`spotMoved`); and once the snap runs to its end `chain:Update` settles it, and the
    braid follows both (`SmallLeft`). One a grip or a snap of its own holds then, which that update leaves alone, is settled
    as its own snap ends: a snap whose spot moved under it runs `chain:Update` as it ends too, and settling the bag
    (`chain:Settle`) clears the mark, as does anything else that puts it on its spot: a refit (`FitSmall`), the anchor's
    glide placing it (this carry), its anchor dragged (each frame of the drag, `StartMove`'s `OnUpdate`, and the drop,
    `StopMove`). Only settling it did before the fourth bug review, so a bag put on its spot another way kept the mark,
    and its own grip let go after ran `chain:Update`, which glided it over the fraction of a pixel its let-go place stands
    from its spot (below) and let the braid go for 15 frames. A glide that leaves its chained side still (every grip's snap: there is no grip on that
    side; a glide for its names whose place holds that side, the backpack where the player left it, a companion beside its
    anchor) places nothing beside it and settles no chain: the bag beside it and the braid are as they were before this
    change. Found by the third bug review (Fit Names While Open off): at 2560x1440, UI scale 0.71, Bag Scale 125%, letting go
    of the bank's left grip 37 units wider glided the backpack beside it a pixel and the braid untwisted for about 0.25 s and
    twisted again; at 1920x1080, UI scale 1, Bag Scale 125% and 85%, the backpack stepped a pixel and back; a chained bag's
    own left grip did the same. Placed every frame from the frame's edge, which stands a fraction of a pixel from where the
    place the let-go saves puts it, the bag's spot rounded to the other whole pixel (`clampPlace`), and the end's
    `chain:Update` glided a bag over that pixel (`Settle`: any glide is not in place, so the braid lets go). The rounding
    is older: a left grip let go rounds its place apart from its facing edge, and the bag beside it stays up to a pixel off
    its spot (0.75 units at 2560x1440 and 0.71) until something settles it, now as before.
- **Its size** (`SmallSize`): the saved size, else its default width (`DefaultWidth`: the columns the full
  body's width holds, `ColumnsWidth(BODY_WIDTH)`, whatever it shows, so it leaves no room past its last column at
  any Icon Scale and does not change as items come and go;
  exactly `BODY_WIDTH` at 100%) and `Small.Height` of the screen tall; its width fitted to its title and names
  (`FittedWidth`: `FitWidth` of the saved or default width, never past the screen at its scale), its height never
  below its minimum nor past the screen, without changing what was saved. An open panel at its default size takes
  its new default when Icon Scale changes (`FitSmall`); a saved size keeps its width. While it is built (its header
  fits its title before its footer and content exist) `SmallWidth` reads the full body's width; `ApplyGeometry`
  gives it its size.
  - `MinWidth`, on a grid step (`StepWidth`: the narrowest whole cells and `ContentRoom` at least that wide):
    room for the shown header buttons, 12, and its whole title and a pixel (`titleWhole`; the frame and the title's
    room each stand on the nearest whole pixel, which can take up to a pixel off between them), or `Small.MinTitle`
    of a title it may not measure (a secret, cut short past that as before); for the footer's free slots, 12 and the
    money (`frames/money.lua`: 128 wide); and for one column of icons with the scroll box's room and the padding.
    `MinHeight`: the header, the footer, a section's title and one row of icons (`CellHeight`).
  - `SmallWidth`/`SmallHeight` read the frame while a grip sizes it or its size glides, else the size it
    took last (`smallWidth`, `smallHeight`, from `ApplyGeometry`, `FitSmall`, `StopSizing` when it saves, `ResetSize`
    and `FollowNames`).
  - **What it lays out for at rest** (`RestingLayoutWidth`) is the width it took last, unrounded (`restingWidth`,
    taken with `smallWidth` everywhere it is), which its frame stands for; its fitted width only before it took one.
    It was worked out live on every render (`max(MinWidth, saved or default)`) while the frame changed only in
    `FitSmall`, so a panel at its minimum laid out for a minimum that followed its footer's text: a free-slot count
    gaining a digit could lay out a cell, and so a column, more than the frame held (next-columns.md, "Known, not
    fitted again. `FitSmall` lays it out again when its frame or that width changed. A panel whose size glides is
    refitted too (`chain:Update`, snapping), its glide ended first (`FitSmall`), a chained pair's anchor before the bag
    beside it (`Update` takes the anchor first: the bag is placed from where the anchor is refitted to; refitted after the
    bag, an anchor whose glide moved its facing side left the bag 91 units into it until a glide settled it, found in the
    review of these fixes); only one a grip holds is left alone, as before this change (a Bag Scale given while a grip holds
    it: next-small-names.md, accepted). It was left alone while its size glided, so a Bag Scale or screen change mid-glide kept the old
    scale and size until it next opened (found by the second bug review).
  - The room past the last column of icons is left on the right, as a web page's (asked: no centering
    in Next's design); a grip let go snaps it to its widest row, so only a panel held wider by its minimum (its
    header, its footer), at its default width with fewer icons than a row holds, or at a size saved before snapping
    keeps any.
  - It comes back at its saved size after a switch to full size and back. When the screen changes
    (`FitSmall`) it is refitted to it and laid out again if its width or height changed; what was
    saved is kept.
- **Shift-click** (`ResetSize`): the panel glides (`Time.Resize`, `Ease.Resize`) back to its default
  size (fitted to its names, `SmallSize`; what they asked for on the way follows the frame after it ends), the corner across from the grip still (the right grip keeps the top left, the left grip the
  top right), its content reflowing at once on the way as while dragging; the saved size is cleared,
  so the default follows the screen again, and the place saved. It returns `"resetting"`, `"default"`
  (nothing was saved) or `"closing"`. Anything that places, moves, sizes, switches or hides the panel
  ends the glide where it was going first (`endSizeGlide`, from `setOffset`, `StartMove`, `StartSizing`,
  `PrepareResize`, `OnHidden`).
- **Everything that read one width reads each panel's own:** `ChainedPlace`, `Dropped` (a bag too wide
  to sit beside its partner on the screen does not chain), the braid's gap (`applyCoupling`),
  `clampPlace`, the default place, `BodyRect`, the sparkles' spawn points and the root's constraints.
  While a bag is sized or glides back, `LivePlace` and `SmallLeft` read its frame, so a partner's spot
  and the braid follow it, and `chain:Update` leaves it alone (it places itself once let go), but for a refit (snapping:
  the screen or a scale changed), which refits a gliding bag, its glide ended first, and leaves alone only one a grip holds.
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
