---
paths:
  - "next/panel.lua"
  - "next/chain.lua"
  - "spec/next/small_spec.lua"
  - "spec/next/vendor_spec.lua"
  - "spec/next/pixel_perfect_spec.lua"
---
### 14i. Autosize Bags (Appearance → Size)

Asked (2026-11-06): "we need to add a new feature to betterbags: autosize bags. this feature should go in appearance next to
size, and it should make it so the bag grows on the vertical (Y axis) to hold all items + free space the user currently has,
keeping the X size as is. it should be a toggle option, and it should default on i think". Then, of the plan: "follow live",
"yes always at least as tall as tab rail", "yes move the bag up just enough", "yes vendor bag too". Then, trying it: the room
"from the bottom of the last section's item buttons, to the border to the currency/money section, is too small, make this a
bit wider", and "don't lock dragging on the Y axis when resizing the window. let it drag larger, but then "bounce" it back to
the size it should be on the Y axis." The plan and its status are in `docs/next-appearance-size.md`.

A small panel (next-small-mode.md §14) is as tall as what it shows, growing and shrinking with it while it is open; its width
is the player's, as before. Every Next kind's small panel autosizes: the backpack, the bank, the guild bank and the vendor
(they are all `NextPanel`). Full panels are the screen's height and are unchanged. The classic bags have their own size to
content (window.md §3) and are unchanged.

#### The setting

- `nextAutosize` (profile, **on** by default; `DB:Get/SetNextAutosize`), **Autosize Bags** on Appearance → Size, after Bag
  Scale and before Fit Names While Open (`next/settings/content.lua`; next-settings.md). Its switch sends
  `next/AutosizeChanged`; `chain:AutosizeChanged` refits every open small panel at once (`Update`, snapping: `FitSmall`), as
  Fit Names While Open's does; a closed one takes its height as it opens.
- AceDB saves only what differs from a default, so every profile starts with it on, including a player's who gave a small bag
  a height with its grips: that height stays saved (`nextSmallSizes[kind].height`) and is the bag's again once the setting is
  off.

#### Its height (`RestingHeight`, `FittedHeight`)

- `SmallSize` gives the width as before and the height from `RestingHeight`: with the setting on, `FittedHeight`; off, the
  height the player gave it, else `Small.Height` of the screen. Either way never below `MinHeight` nor past the screen at its
  scale (`FloorIn(unit, UIParent:GetHeight() / scale)`); past that, what it shows scrolls as before.
- `FittedHeight`: its header (`CONTENT_TOP`), what it shows as last laid out (`contentHeight`), as much room as between its
  sections down to its footer's line (`SECTION_SPACING`: the line sits `FOOTER_LINE`, 4, under the scroll area, so the room
  added below what it shows is `SECTION_SPACING - FOOTER_LINE`; Default's 4 units between the last row of icons and the line
  were reported too small), and what is under its scroll area (`ContentBottom`: the footer), so nothing scrolls; never shorter
  than its tab rail, which hangs beside the body from `CONTENT_TOP` (`CONTENT_TOP` + the rail's height, while the rail shows:
  the backpack hides it with groups off). `FOOTER_LINE` is the constant `styleFooter` anchors the line with (it was a bare 4).
- Neither the room the render root hands the scroll box (`rootProto:PreRender`: the height less `CONTENT_TOP` and
  `ContentBottom`) nor the scroll box as `styleContent`'s `pixel:Point` anchors it (each offset snapped to the panel's pixels,
  which Blizzard's scroll box measures its scroll range from) may be a fraction short of what it holds, or a fraction would
  scroll: the header is taken at the larger of `CONTENT_TOP` and `CONTENT_TOP` snapped, and the sum rounded up to whole pixels
  (`pixel:CeilIn`). What it holds is whole pixels, and a length rounded up is never less than one rounded, so that covers the
  bottom anchor's rounding too: a `max` there as well changed nothing in any case (mutation-tested; it went). The footer's line
  stands on a whole pixel too (`pixel:Point`), so the room down to it is `SECTION_SPACING` within a pixel.
- `contentHeight` is the scroll box's `FitHeight` (render-pipeline.md: its child's height, the canvas's `y`), kept by the
  render root's `Render` from the render's results on every render. The canvas lays out from the width alone (`LayoutWidth`),
  never the height, so taking the height never lays it out differently, and fitting it converges in one step. While a section
  is dragged the canvas never shrinks (`heldHeight`, next-drag.md); the panel waits for the drag meanwhile (`busy`).

#### Following what it shows (`FollowHeight`, `heightLater`)

- The render root's `Render` asks `FollowHeight(true)` on every render, and the tab rail's resize handler asks it when the
  rail's tabs are set (the rail is shown after `SetTabs` calls it, so a frame on). With `later` it tries a frame on
  (`heightLater`: a zero-length tween on `heightKey`, as `followLater` is for names); a render inside `FitSmall`,
  `PrepareHeight` or `StopSizing` only schedules it.
- A try: not an open small panel (`"closed"`) or the setting off (`"off"`) does nothing; not `Settled` (a grip, a glide, a
  move, a switch, a slide, a section dragged, a Glitch shove), or its chained partner open and not settled, it tries again
  next frame (`"owed"`): a chained pair glides one at a time, as for names (next-small-names.md §14g; both glided at once, the
  anchor's moving top found the bag beside it busy and left it behind). Within half a pixel of `RestingHeight` it `"fits"`.
  Else it glides (`"following"`): it takes the height (`smallHeight`), works out the place that height puts it
  (`SmallPlace`), and snaps there (`snapTo`, its width and the width it lays out for as they are). Nothing is saved.
  - Where it stands apart from its place across (a chained bag carried by an anchor that has since closed), its left edge glides
    there with its height (`toX`), so the glide's end (`setOffset(0)`, at its place) never jumps it. The chain saves such a
    bag's place where it stands as its anchor goes (below), so no spec reaches it now (mutation-tested); it stays so the glide
    always ends where it is going.
  - The render inside an open's draw asks too (there is no `opening` guard, as `FollowNames` has): it waits out the slide and
    finds the height `FitSmall` gave it. A guard there changed nothing a spec could see (mutation-tested) and went.
  - It sets `keptScroll` as it starts, as every size glide does (a grip's press, Shift-click, `FollowNames`): `KeepScroll`
    scrolls a panel whose size glides back to `keptScroll`, and one left from an earlier grip would scroll it there. What it
    shows fits before and after a height glide (only a bag at the screen's height scrolls, and that height does not change),
    so the offset kept is 0 in every case the specs can make; no spec sees the line (mutation-tested), and it stays for the
    rule that no glide starts with a stale `keptScroll`.
- **Fit Names While Open glides the width alone** (`FollowNames` takes `SmallSize`'s width and resting width and keeps
  `smallHeight`): with `snapTo` gliding a height that changed, a names glide that took a newer height would have jumped the
  frame to it on its first frame, and moved a centered bag's top with it. The height follows after, on its own.

#### The glide (`snapTo`)

- `snapTo` takes the height it starts from (`h`, else no height glide) and where its top ends (`toY`, else it stays). The
  height glides from `h` to `SmallHeight` with the width's bounce (`motion.SnapSizeAt`, `SnapOvershoot` floored at
  `MinHeight`: none growing), as the original bags' height snap does (window.md §3b); a shrinking bag's last row slides under
  its bottom edge by the overshoot for a moment, as there.
- Its top moves with the share of its height glided (`along`: by the size it has now, so a bag whose bottom is held, at the
  screen's bottom, keeps it there through the bounce; by the glide's progress where a size does not change). `toX` is worked
  out the same way, which is what it was for every caller before (each had a width that changed).
- `carries` (the bag chained to it is placed beside it each frame, and the chain settles as it ends) is true where the top
  moves too (`toY`): a chained bag's spot hangs from its anchor (its bottom, since bags hold their bottom corner,
  next-bag-anchor.md §30a: a height glide over a held bottom places it on the spot it is on). A height glide passes `"RIGHT"`, so a companion
  anchoring the backpack (its chained side its right) carries it through a height glide whose top stays: placed from where the
  anchor's frame is, the bag beside it reads back the spot it is on, and the braid stays twisted, on 42 screens and Bag Scales
  tried (2560x1440, 1920x1080, 3396x1362 and 1366x768, UI scales 0.53 to 1.07, Bag Scale 50% to 150%). Not carrying a glide whose
  width does not change changed nothing there either (mutation-tested; it went).

#### Where it sits (`clampPlace`, `SmallPlace`, `saveSized`)

Since #1276 a small bag holds a corner (next-bag-anchor.md §30a): a bottom one unless its anchor square gave it a top one. Holding
its bottom it grows up from it, and everything below is that mirror of what it was when bags held their top (each held-top rule,
and the review finding behind it, kept its spec, rewritten for the bottom); holding a top corner it grows down, as bags did
before, pushed up to keep its bottom on the screen (`clampPlace`, `saveSized`'s `math.min`).

- Its bottom stays where the player left it; the top edge moves. Never placed, it holds its own side's bottom corner where a
  bag of the default height centered has it (`HeldCorner`), so it grows up from there.
- **Its top stays on the screen** (the mirror of "move the bag up just enough"): with the setting on, `clampPlace` keeps its top
  no higher than the screen's and its bottom no lower (`max(min(y, screen), min(screen, height × scale))`) whether or not Clamp
  Bags to Screen is on (on, it already did, window.md §3a). It is pushed down no further than that, and since the corner it
  holds is the one saved (a follow saves nothing), it goes back up to where it was left as it shrinks.
  - Everything that places a small panel goes through `clampPlace`, so a drop that leaves its bottom off the screen is put back
    up as it lands, and saved there, as Clamp Bags to Screen does: the drop is where the player put it.
  - A grip let go and a Shift-click save its corner through `saveSized`: with the setting on, a bottom pushed under the one held
    (by the rule above) keeps the one held, so it still goes back up as it shrinks (the mirror of the mutation run that found
    raises saved). A bottom over the one held (Clamp Bags to Screen raising a bottom saved past the screen's) is saved where it
    is (the mirror of the bug review's). A chained bag saves where it stands, its spot (the second bug review's). Off, where it
    is.
  - A grip let go also takes the place it is put at from the bottom it holds before `clampPlace` (`StopSizing`), so a
    pushed-down bag the grip made shorter goes back up at once (the mirror of the second bug review's). A Shift-click keeps the
    bottom it holds the same way (`ResetSize`).
  - A chained bag is placed beside its anchor, bottoms level (`ChainedPlace`), and then through `clampPlace` with its own height:
    one taller than its anchor near the screen's top is pushed down alone, its bottom off its anchor's, as Clamp Bags to Screen
    already did with it on. Left as it is: nobody has seen it, and it is the clamp's existing behaviour.
- **The backpack beside a companion that closes stays where it stands** (`chain:Released`, once a close: from `Hide` as the
  companion starts to close, which marks it `released`, and from `OnHidden` for a hide with no mark, Escape's at once): the backpack
  beside a companion (layout "companion") has an anchor only while a companion is open (`chain:Companion`), and then reads its
  own saved place, the spot it was dropped at. Its anchor's glides (its centered top following its height, its edge for a name),
  refits (a Bag Scale) and its own glides into its spot carried it elsewhere without saving, so once the companion closed its next
  height glide took it back there, its left edge jumping as the glide ended (found by the bug review). As a small companion
  closes in that layout, the open backpack's place is saved: its left edge where it stands, its bottom its spot's beside the
  companion's bottom (`ChainedPlace`), or where it stands if higher, never a bottom Autosize Bags pushed it down to (the mirror of
  the third bug review's finding: it saved that raise, and never went back down). Since bottoms are level, a companion's height
  no longer moves the backpack; its width (a name) and a Bag Scale still do. The slide's end hides the companion too (the client fires `OnHide`),
  and saves nothing more: in its 0.24 s the companion's top can move (a glide the close cut short ends where it was going, below
  where the backpack stands), another companion open and the backpack glide beside it, or the backpack be dropped, and the place
  the close saved stands (found by the fourth bug review, each with its spec). The mark is cleared as the companion opens, so a
  companion opened again as it slides out saves again as it closes, Escape's too, and at the end of `OnHidden`, which every close
  reaches once: a parent's hide (Alt+Z) part way through the slide cuts the close short and leaves the companion open with no
  `Show`, and its next close, Escape's, saved nothing (found by the fifth bug review). A parent hiding the companion (Alt+Z,
  `hiddenByParent`) is no close and saves nothing (found by the third bug review: it overwrote the place a backpack closed first
  then kept). A close that ends part way through a switch to small (`PrepareResize` finishes it) is a full panel's and saves
  nothing (a backpack never small has no place yet).
  - A first version kept the bag chained beside an open anchor in `chain:Update` and saved one that no longer was: a pair
    chained by a drop or a size switch never passed through `Update` (`Arrived` does not), and a bag dragged off its anchor
    stayed the one kept, so its own glide's end saved the top it rose to (found by the second bug review). The `released` mark
    was once removed as changing nothing (its mutations alive): no spec fired `OnHide` at a slide's end where the backpack or the
    companion had moved meanwhile; the fourth review's specs do. Its clearing in `OnHidden` then went too, as one every opening
    does; the fifth review showed a close a parent's hide cut short reopens with no `Show`, and it is back with its spec.
  - A closed backpack keeps the place it had. This holds with the setting off too: an open backpack stays, and reopens, where
    it last stood beside the companion, not where it was dropped.

#### The grips (`StartSizing`, `StopSizing`)

- A grip sizes both ways, as with the setting off (`SetResizeBounds`: the minimums and the screen); what it shows reflows at
  each size as it is dragged. Let go, the height bounces back to what it shows (asked: "let it drag larger, but then "bounce"
  it back"): `snapTo` glides from the height let go at to `RestingHeight` with the bounce (past it shrinking, by the overshoot;
  straight to it growing), the width's snap with it, the top still. A first version held the height while a grip dragged
  (resize bounds pinned at its height); asked to free it.
- `StopSizing` saves only the width (a press that moved only the height saves nothing: `heightMoved` counts with the setting
  off alone), with the height that was saved, nil when none (the player's height for when the setting is off; `autosize and
  saved or h` would have saved the let-go height where none was saved, Lua's `and`/`or` falling through a nil). Where it
  saves, it lays out at the width it snaps to (`RenderNow` after `SmallSize`, its resting width the new one) and takes that
  height (found by the bug review: it took the let-go width's, and a snap wider for a name glided the height twice, up to the
  screen's height first). Then one `snapTo` glides the width and the height (`h` the let-go height, `toY` where its bottom must
  stay on the screen: it rises as it grows), also where only the height changes. Off, nothing about it changed.
- Shift-click (`ResetSize`) glides to the default width with the height from what it shows at the width it had (its glide
  already moved the height and the top); the height of what the default width shows follows once it ends (`FollowHeight`).
  The saved size is cleared, the saved height with it, as a reset always did.

#### Fitting at once

- `FitSmall` (opening, a screen or scale change, the setting turned on or off, Clamp Bags to Screen turned on): with the
  setting on and a width to lay out for that changed (`restingWidth ~= fitted`), it lays out there first (`RenderNow`), so
  the height it takes is that width's. The open's draw lays out at its resting width already, so an open that keeps its width
  renders once.
- `ApplyGeometry` takes `SmallSize` as before (`contentHeight` as last laid out; none yet as a panel is built, so its
  minimum: it fits as it opens).
- Switching to small (`nextPanel:SetSize`): once every panel is prepared (`PrepareResize`), each that morphs lays out at its
  small width and takes that height (`PrepareHeight`) before any `Morph` works out where it glides to, so the switch glides
  once, to the height that shows what it holds, and a bag chained beside another is placed from the top that one ends at
  (found by the bug review: done in each `Morph`, the backpack beside a companion morphed first, placed from the companion's
  old height, and jumped 184 pixels as the switch ended). `PrepareHeight` takes `SmallSize`'s width first, as `FitSmall` does
  (found by the second bug review: a bag small before, whose names asked for a wider width while it was full, took the old
  width's height and glided again). `Morph`'s `ApplyGeometry` then takes the same size.
  - Switching to a small size wider than the full body, what it shows is laid out at the small width as the switch starts, so
    the columns past the body's edge are clipped by the scroll box until the body reaches them, as a snap that grows for a
    name clips them (next-small-resize.md §14g). Chosen over laying out at the end and gliding the height a second time (found
    by the second bug review; the clipping is inferred from Blizzard's ScrollBox clipping its children, not seen).

#### Specs

The panels' specs stub `GetNextAutosize` (patterns-specs.md): `spec/next/small_spec.lua` off by default (`db.autosize`, so the
specs of sizes the player gives see them) and on in "autosizing its height"; `spec/next/pixel_perfect_spec.lua` on, its
default (`db.autosize`), but for the three that scroll a panel the player gave a height; `spec/next/vendor_spec.lua`,
`theme_panel_spec.lua` and `guildbank_spec.lua` off, the vendor's on in its own test. Their `fitted` reads the footer line's
anchor (`select(5, footerLine:GetPoint(1))`) rather than repeating `FOOTER_LINE`.

Coverage: `spec/next/small_spec.lua` ("resizing it" → "autosizing its height": the height at opening, its width as it was,
centered at its default place; its minimum; the room above its footer's line; growing and shrinking a frame on, gliding, its top
still, saving nothing; centered on the way; the screen's height and scrolling past it; its bottom kept on the screen and back
down to where it was left at Bag Scale 100% and 150% with Clamp Bags to Screen off; the tab rail, as tabs are added; waiting for
a move; a grip sizing it either way and its height bouncing back, a press that moved only its height bouncing back and saving
nothing, one glide for both, once where it snaps wider for a name, the width saved without a height and with the player's
height; a let-go that raises it, gliding up with its bottom on the screen and saving the top it was left at; a Shift-click that
lets it back down; a let-go saving where Clamp Bags to Screen keeps it, the setting on and off; opening at a new width at that
width's height with nothing to glide after; the setting turned off and on; Shift-click; a chained bag level with its anchor's
moving top; a chained pair one at a time, level all the way; switching a pair to small, the backpack beside a companion, level
and gliding all the way there; the backpack where a companion's height, name or Bag Scale left it once the companion closes,
its left edge still, and closed by Escape; the backpack where it stands as a companion chained by a size switch or by a drop
(its glide cut by the close) closes; a closed backpack's place kept; back down to where it was dropped after being dragged
off its companion; a raised bag a grip made shorter going back down, Clamp Bags to Screen on and off; a chained bag's let-go
saving its spot; switching back to small after its names asked for a wider width while full, in one glide; back down to its
spot beside a companion once that closes, raised as it closes or as the slide ends (OnHide fired as the client fires it),
Clamp Bags to Screen on and off; nothing saved as a parent hides a companion; nothing saved for the backpack as a companion's
close ends in a switch to small or to full; as a companion's slide ends (OnHide fired), the close's save kept over a glide the
close cut short, another companion opening and a drop, a companion opened again as it slid out saving as Escape closes it, and
one whose close a parent's hide cut short saving as Escape closes it; the bag beside a companion never moved nor the braid untwisted by a height glide, at two screens; a full
panel; switching to a narrower small size in one glide; the return values; Fit Names While Open's width glide never jumping the
height; whole screen pixels and nothing to scroll at every Bag Scale from 50% to 150% on three screens),
`spec/next/vendor_spec.lua` ("autosizes a small vendor's height to the cards it shows, and follows them"),
`spec/next/pixel_perfect_spec.lua` (every small-panel check with the setting on), `spec/next/settings/content_spec.lua`,
`spec/config/catalog_spec.lua`, `spec/config/settings_effects_spec.lua`, `spec/database_spec.lua`,
`spec/core/constants_spec.lua`.

Mutation-tested (2026-11-06, 89 mutations over eleven passes, and the fifth review's). The first pass left 11 of 29 alive: seven led to tests (opening at
a new width, a switch to a narrower small size, a let-go that raises it, the let-go's height gliding, a chained pair at once,
rounding at every Bag Scale) and to `leftPlace`; four showed code not needed, removed (an `opening` guard, a `max` on the
bottom anchor, not carrying a width-still glide, `leftPlace`'s chained check, which the second review then showed was needed
and is back with its spec). The bug review's fixes: 16 mutations, all caught but `FollowHeight`'s `toX` (above). The second
review's: 16, all caught but two, removed (`leftPlace` before a Shift-click's `clampPlace`, and `Released` waiting for every
companion to close: beside another open one the backpack reads its spot from it); one more led to a spec (a closed backpack's
place). The third review's: 16, a mark of a close already saved (four, all alive: the spot's top makes a second save the same;
it went) and `Released`'s guards (a full backpack's alive, removed: the save repeats the close's first; a full companion's led to
a spec). The fourth review's: the mark back, its six mutations caught but its clearing in `OnHidden` (removed); its clearing as it
opens led to a spec; the fifth review restored its clearing in `OnHidden`, with a spec. `keptScroll` set as a height glide starts is alive too, kept for the rule above.

Bug review (2026-11-06): four found and fixed, each with its spec (a let-go snapping wider for a name gliding the height twice;
switching a pair to small with the backpack beside a companion; the backpack's place once its companion closes; a let-go
keeping a saved top past the screen). Second bug review, of those fixes and the grips and footer changes: six found, five fixed
with specs (the backpack's place after a companion chained by a drop or a size switch closes, and after it is dragged off one;
a raised bag a grip made shorter; a bag small before switching back; a chained bag's let-go), one chosen and documented (the
clipping above). Third bug review, of those fixes: three found and fixed with specs (the slide's end saving the backpack's own
raise; Alt+Z saving its place; a backpack raised beside its companion keeping the raise). Left as reported: a companion closed,
opened again as it slides out, and closed after the backpack leaves the place the first close saved, which is neither where
the backpack was dropped nor where it last stood (nobody has seen it; the backpack opens there, beside where the companion
was). Fourth bug review, of the third's: three found (the slide's end saving over the close's save as a shrinking glide the close
cut short ends, as another companion opens, and over a drop), fixed by the mark, with specs. Fifth bug review, of the mark: one
found and fixed with its spec (a close Alt+Z cut short left the mark set). Left as reported, not built for: a backpack whose groups are turned off hides its tab
rail without a render of its own (the setting's own redraw follows in game); a section drag's end only invalidates, and whether
the client runs a frame's tweens before its `C_Timer.After(0)` render is not known, so a try in between would read the drag's
held height for a frame.

Not verified in game: the glide as items come and go, a bag growing up from the screen's bottom, a chained pair, a grip dragged
taller and bouncing back, the room above the footer on each theme, and how a short bag beside a long tab rail looks.
