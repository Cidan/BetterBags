---
paths:
  - "next/panel.lua"
  - "next/chain.lua"
  - "spec/next/small_spec.lua"
---
### 14g (continued). Keeping names whole

This continues next-small-resize.md §14g (resizing a small panel, the grips): fitting its title and its sections' names
to its width, Fit Names While Open, and the bug reviews of them.

- **The title** (`FitTitle`): a small panel's title stays on one line in the room its shown header
  buttons leave, cut short rather than under them; so does the vendor's at either size (`fitsTitle`:
  a vendor's name can be any length; this replaced its own `fitTitle`). A full panel's other titles
  are as long as they are (width 0, wrapping on). Run by `LayoutHeader`, `SetTitle`, `ApplyGeometry`,
  `FitSmall` and every size change while sized or gliding back. A small panel's minimum holds its whole title, so it
  is cut short only where even the screen's width cannot hold it, or it is a secret.
  - **Its cloud follows the width it is cut to** (`FitTitle` runs `LayoutCloud` whenever `titleCut` changes). The
    client measures a title cut short at the width it is cut to, and the cloud reaches across the title as measured
    (`CloudSpan`); it was laid out only where a title is set and a theme styles the header. The bank and the vendor
    set their title as they open (`OnShowing`), before the open fits the panel (`FitSmall`): set cut short, then shown
    whole, the title kept a cloud as short as its cut (found by the bug review, setting on or off). Every place the
    title is fitted is after the header is built and its puffs made for the theme in use (a theme or Animation switch
    restyles every panel in the same call, `RestyleWidgets`, and nothing fits another panel's title in between), and
    `CloudSpan` reads a secret title's stand-in width. While a grip drags the panel the cut changes every frame: the
    cloud's twelve puffs (Default) are sized and placed again, beside `applyCloud`, which the cloud's driver runs every
    frame anyway.
  - **Measured whole** (`measureTitle`, `titleWhole`) as its text or font is set (`SetTitle`, `styleHeader`), never as
    it is fitted: `FitTitle` runs every frame of a resize, and the Glitch theme shows the title's letters corrupted for a
    moment (`ShowTitle`), which setting its text would end. A font string keeps the width it was cut to through a new
    text or font and measures that, so it is set back to none and its text set again before it is measured
    (next-themes-art.md §14), then takes back the width it had: a theme's restyle lays the cloud out before it fits the
    title again. While the title shows a secret (a vendor's name in an instance) its measure is secret, and `titleWhole`
    is nil: nothing is compared, added up or kept (next-vendor.md §10a).
  - **Justified toward its anchor** (`styleHeader`): left on the backpack, right on the companions.
    Text is centered in a font string's width unless justified otherwise (`justifyH` defaults to
    `CENTER`, `Blizzard_SharedXML/UI.xsd`), and the backpack's title set none, so once small panels'
    titles had a width it sat in the middle of the room it had (reported: titles "shift right" in
    small mode and not at full size, where a title is as wide as its text). The companions already
    right-justified. The frame mock now answers `CENTER` for a font string never justified.
- **Names whole** (`FitWidth`, `NextCanvas:NameCells`, next-columns.md §7a). Reported (2026-11-04) with a screenshot: a
  near-empty backpack four cells wide in two columns, "Consumable 1" beside "Miscellaneo... 2", its title "Backp...".
  Asked: "we need to make sure this never happens by always have the bag width sit at the minimum step ... such that no
  text is truncated in bag title or section title". A small panel's width sits at the first grid step (whole cells and
  the room beside them, `RowWidth(n) + ContentRoom()`) at or above the width the player chose (saved, else its default,
  else where a grip let go) at which neither its title (its minimum holds it) nor any section's name is cut. Whole names
  are not monotonic in cells: more cells can mean more columns, each narrower. The reported bag holds every name at three
  cells (one column), cuts Miscellaneous at four (two columns of two) and five (three and two), and holds them from six
  (three and three). So the search goes up from the chosen width's cells a step at a time, through the canvas's own
  column rules; never the fewest cells that hold them, which would take the player's columns away, and never past the
  screen at its scale (`PerRow` of its width there). Where no step up to the screen holds them, or the width chosen
  holds them already (a saved width from before snapping, on a step or not), the width chosen.
  - A whole row of content (Recent Items, Free Space, every section at one column) is drawn in whole pixels and can be
    drawn short of its cells' width: the frame stands on the nearest whole pixel, or the screen's last before it (up to
    a pixel), and the scroll box keeps a whole number of pixels for its bar on each side (half a pixel each). So
    `NameCells` gets `ROW_SHORT` (2) screen pixels to take off a whole row (a column is whole cells, drawn exactly). The
    design first named the icon row (`n * step - gap`) as a safe lower bound; measured with the real modules over five
    screens, Bag Scales 50% to 150% and 1 to 20 cells, it was a pixel more than the drawn row in 50 of 1,719 layouts.
    Measured: a whole row is drawn a pixel short of its cells' width at 3396x1362 (65%) and 85% at five to eight cells, and a
    margin of 1 already keeps every name whole on the screens the specs try; the second pixel is derived, for a frame on the
    screen's last whole pixel (up to a pixel short) at the same time as the bar's rounding.
  - Fitted as it opens (opened again as it slides out too, next-small-mode.md §14c) and is fitted again (`FitSmall`, `ApplyGeometry`:
    opening, the screen or its scale changing, a theme, a size switch's end, Fit Names While Open turned on, each ending a
    size glide first) and where a grip is let go (`SnapWidth`: the snap glides
    there, and that is what is saved, as the snap's width always was). Nothing is saved as it opens: a saved width too
    narrow for the names opens wider and stays saved as it was.
  - Each name's need is the canvas's own sum (`titleRowWidth`: the title's place, its whole name, `CountGap`, the count,
    each in whole pixels), measured once per search. The vendor's section names and counts are never secret: they are
    category names and button counts, and the canvas keys tables by section names already (`byName`, `heldCells`), which
    a secret could not be.
- **Fit Names While Open** (`nextFitNamesWhileOpen`, profile, off by default; `DB:Get/SetNextFitNamesWhileOpen`; Appearance
  → Size, after Bag Scale; its switch sends `next/FitNamesChanged`, and `chain:FitNamesChanged` fits every open small panel
  again, `Update` snapping). Asked: "with an option to enable/disable this behavior in settings, default disable. with it
  disabled, behavior is as it is now". Off, nothing changes a small panel's width while it is open: a section with a long
  name looted in while it shows may be cut until it next opens or a grip is let go. On, while a small panel is open
  (`FollowNames`), every draw (`Draw` after `Bind`, its footer's text set first, before the render; the vendor's `Draw`
  after `BindSections`) and every new title (`SetTitle`, a frame on: below) fits it again (`FittedWidth`): it glides wider
  when a name or the title would be cut, and back to the player's width (saved or default, fitted) once they fit, saving
  nothing. The glide is the snap's (`snapTo`, `Time.Snap`, the content laid out at the width it ends at all the way, so no
  name is cut on any frame of it), and keeps where the player has it scrolled as it starts (`keptScroll`, read there as a
  grip's press and Shift-click's glide read it; `KeepScroll`). The edge that moves is the one its place does not hold:
  where its new place's left is its old, the right edge ("RIGHT"); where its right is (the backpack's default place, a
  companion chained left of its anchor), the left ("LEFT"); where neither is (the screen's edge, Clamp Bags to Screen),
  both, its left edge gliding to its new place with its width. It returns what it did for profiler traces: `"closed"`,
  `"off"`, `"owed"`, `"fits"`, `"placed"` (its frame was that wide already) or `"following"`.
  - **Not settled, it waits** (`Settled`: nothing moves, sizes or places it, `busy`: a grip sizing it, its size gliding,
    moved, switching size, a slide or a glide playing on it, a section dragged on its canvas; and it is on its place, its
    offset 0, which a Glitch burst's shove is not), **and while the open bag chained to it is not settled** (`chainedPartner`:
    the anchor it sits beside, `chain:SmallAnchorOf`, or the open bag beside it, `chain:Follower`; a partner closing or
    closed never holds it: one closing slides off its place, and stays off it once closed). A chained pair glides for its
    names one at a time: each is placed from the other's edge, the anchor moves its partner only while the partner is not
    busy, and two glides at once overlapped them (found by the bug reviews, below). Each waits only on the other's motion,
    and motions end, so neither waits for good. Off its place, a glide would set out from the shoved place and jump back
    at its end; a burst stopped part-way puts the panel back where it found it (below, the Glitch theme).
  - **What it owes is tried again each frame** (`followLater`): waiting, it marks the follow owed (`namesOwed`) and tries
    `FollowNames` again a frame on (a zero-length tween, `namesKey`), and again each frame it still waits, so it follows the
    frame after whatever it waits for ends, however that ends: a glide run to its end or cut short, a grip let go, a move
    dropped, its partner dragged away (and unchained), closing or settled, a section drag landed or cancelled (a drag
    cancelled draws nothing after it, next-drag.md §7), a burst over. The tries stop once it follows (or fits), once it is
    not an open small panel (closed, closing, full size: `"closed"`; it is fitted as it opens), or once the setting is off
    (`"off"`). A try while it waits is `FollowNames`' checks alone (the setting, the chain's partner, `Settled` of both): no
    layout and no name measured, and one tween a frame. Never at once: what ends a wait may have been ended early by what is
    about to place or size the panel itself (`StartMove`, `StartSizing`, `PrepareResize` end a glide and then start), which
    by the next frame it is doing. This replaced follows called back from each end (`FollowOwed`, from a snap's or reset's
    end, `StopSizing`, `StopMove`, `chain:Arrived`, `NextDrag`'s `finish`): an end that called back for nobody (a partner
    unchained, closed, a burst) left the follow owed until the next draw (found by the second bug review); with the tries,
    each of those calls changed no test's outcome, and they went. What owes a follow is never cleared elsewhere:
    `FollowNames` checks the width again, so a follow owed by a panel since fitted finds it `"fits"`.
  - **A new title follows a frame on** (`SetTitle` runs `FollowNames(true)`: owed, tried a frame on). What sets a new
    title draws what it shows next in the same frame (a bank tab switched: `SwitchToGroup`, `SwitchToBlizzardTab`), and
    that draw fits the new title and the new sections in one glide; a title set with nothing drawn after it follows on
    the next frame. The guild bank's tab switch (`guildProto:shown`) and the bank's Show Bags toggle (`ToggleBankTabs`)
    draw through `bags/Rederive`, which the refresh scheduler runs a frame or more later (`refresh:_Arm`,
    `C_Timer.After(0)`): there the title can still glide before the draw does, twice when both the title and the
    sections change the width they need (left as it is: waiting for a recalculation that may draw nothing is not this
    setting's to do).
  - **A title that grows** is cut until the glide has made room for it: it is never wider than the room beside its header
    buttons (`FitTitle`).
  - **The Glitch theme's bursts** (`burst`) shove a panel off its place (`setOffset`) while nothing else moves it. Shoved,
    it is not settled, and follows once the burst puts it back. A burst stopped part-way (it closes, or a parent hides it:
    Alt+Z) puts the panel back where it found it (its `onStop`), unless something else has taken it over: placed it (its
    offset is no longer the burst's: a full bag beside its anchor placed at once by a new screen, `PlaceAt`), or moves or
    sizes it now (`placedElsewhere`: a move the client is making). It left the panel shoved for good before, which with the
    wait above would have held its names for good. So too a parent hiding the panel mid-slide (Alt+Z: `OnHidden` stops what
    moves it): its open slide stopped part-way left it off its place and faded once shown again, from before this change;
    shown again by its parent (`OnShow`, `hiddenByParent`), a small panel off its place with nothing playing on it is put back
    on its place. A full bag beside its anchor rests off its screen edge and is left there, and so is a panel sliding out (a
    close begun while its parent hid it).
  - **Found by the bug review** (each reproduced against the real modules first, then fixed test-first):
    1. A Bag Scale change with the setting on left an open panel at its old scale: `chain:ScalesChanged` drew every panel
       (`ApplyScales` → `Draw` → `FollowNames`, which glided toward the new scale's width) before refitting it, and the
       refit left a gliding panel alone, so `FitSmall`'s `takeScale` never ran. It refitted first, then drew; since the
       second review the refit refits a gliding panel (its glide ended first, item 6 below), which the third review's
       mutation run found makes the order moot (no test fails either way), and `chain:ScalesChanged` draws then refits again,
       as before this change (next-small-mode.md §14h).
    2. A names glide scrolled the bag back to where the last grip press left it: `keptScroll` was read only at a press and
       at Shift-click's glide, and `KeepScroll` acts while any size glides. `FollowNames` reads it as its glide starts.
    3. A chained pair drawn in the same update (items moved between them) glided at once and overlapped by up to 136
       pixels, in either draw order: the waits above.
    4. A bank tab switch glided twice, the new tab's long name cut through the first glide: `SetTitle` fitted the new title
       to the old tab's sections before the tab was drawn. A new title follows a frame on (above).
    5. The title's cloud stayed laid out for a cut title after the panel widened to show it whole (setting on or off):
       `FitTitle` lays it out again (the title, above).
    6. Switching size while a chained bag's size glided coupled the braid again mid-switch (a regression of this change):
       `nextPanel:SetSize` lets go of the braid, then `PrepareResize` ends the glide, whose end ran `chain:Update`. A snap
       ended early settles no chain (`glideCut`, the snap, next-small-resize.md).
    7. A follow owed while a section was dragged on the canvas waited for the next draw when the drag was cancelled. The
       tries each frame (above) follow it.
  - **Found by the second bug review** (each reproduced against the real modules, `/tmp` specs, then fixed test-first):
    1. A restyle or a refit while a size glided (a theme, Clamp Bags to Screen turned on; also a Shift-click's glide, before
       this change) left the frame at the glide's size while the panel's size and the width it lays out for were the new
       ones, the content laid out up to 300 units wider than the frame, until it next opened: what sizes the frame ends the
       glide first (the snap, next-small-resize.md).
    2. A follow owed was never run when what it waited for ended without calling back for it: the partner dragged away
       mid-glide (the move cut the glide short and `chain:Detach` unchained the pair, so its let-go called back for nobody),
       the partner closing, a burst. The tries each frame (above).
    3. A chained pair still overlapped (136 pixels) when the anchor glided for its names while its partner glided into its
       spot: the wait was for a partner's grip or size glide only. It waits while its open partner is not settled at all;
       and the other way about (the partner dropped beside an anchor already gliding), the glide into its spot follows the
       spot as it moves (next-small-mode.md §14e) and the anchor's glide reads the bag beside it each frame.
    4. On the Glitch theme, a names glide started during a burst set out from the shoved place and jumped 14 pixels as it
       ended: a panel off its place is not settled (the Glitch theme's bursts, above).
    5. A bag opened again as it slid out was not fitted, setting on or off (next-small-mode.md §14c).
    6. A Bag Scale, UI scale or screen change while a size glided kept the old scale and size (the refit left a gliding
       panel alone): it is refitted, its glide ended first. It was reported, not built for, after the first review. A
       conversion built with it for a panel a grip holds as the Bag Scale changes (its let-go place turned into its units at
       the new scale) went in the third review: that is two inputs at once, which nobody has seen, and it was wrong for the
       left grip (190 pixels off); the let-go is as before this change, accepted.
    7. With the tries each frame, a Shift-click glide's end no longer calls back for a follow, so its check for a glide ended
       early (`glideCut`), which no test held, went with that call. What it kept from happening (the bag beside an anchor
       dragged mid-glide following under the move, the anchor placing it every frame and so ending its glide at once: a
       jump to its width) is kept from happening by the wait above, tested.
    Reported, not built for (they need what nobody has seen): a title longer than the screen at a high Bag Scale can make
    `MinWidth` exceed the grips' `SetResizeBounds` maximum; an error raised inside a glide's end while `endSizeGlide` ends it
    would leave `glideCut` set; `FitWidth` keeps the player's width when no step up to the screen holds the names.
  - **Found by the third bug review** (each reproduced against the real modules, `/tmp` specs, then fixed test-first):
    1. A grip let go on a chained pair, the setting off, glided the bag beside it a pixel and back, or untwisted the braid
       and twisted it again (a regression of this change; the snap, next-small-resize.md). The snap carries the bag beside it, and settles
       the chain as it ends, only where it moves the side that bag hangs from.
    2. A bag gliding into its spot jumped back 10 units when the anchor it glided beside closed (a regression of this
       change, next-small-mode.md §14e): it goes on to the spot it read last.
    3. The let-go conversion for a Bag Scale given while a grip holds the panel went (second review, item 6).
    4. `chain:ScalesChanged` draws, then refits, as before this change (first review, item 1).
    5. The mutation run showed three guards no test held, each now tested: a partner shown (a bank chained beside a
       closed backpack waited for good, its name cut: a closed panel rests off its place, so it is never settled); the tween
       playing on a panel in `busy` (a glide into its spot and the Ice Shatter, Smoke, Beam and Paper opens put the panel on
       its place as they start, its offset 0); and the wait for a partner gliding into its spot ("the drop first" passed
       with the wait cut back to grips and size glides: the anchor's glide places the bag gliding beside it, so they stayed
       apart either way; it now checks they glide one at a time).
    Reported, not fixed (as so before this change): a short drag of a chained anchor is undone (`chain:Dropped` reads the
    old saved place); Alt+Z during a glide into a spot leaves the bag off its spot; Alt+Z during a close slide leaves the bag
    never closing. Left as it is: a busy bag beside an anchor whose glide moved its spot, settled as its own snap ends, is
    settled by the next chain update instead when what held it was a Shift-click's glide or a grip let go at the width it
    snaps to, or when that snap was cut short (two inputs at once and more); since the fourth review, a refit or its
    anchor dragged in between puts it on its spot and pays that too.
  - **Found by the fourth bug review** (each reproduced against the real modules, `/tmp` specs, then fixed test-first):
    1. What the anchor's glide owed a busy bag beside it (`spotMoved`) outlived what it was for: only `chain:Settle` cleared
       it, and a refit (`chain:Update` snapping, `FitSmall`) or the anchor dragged puts the bag on its spot without it. At
       2560x1440, UI scale 0.71, Bag Scale 125%, the bank's left grip let go 53 wider after either glided the bank 0.751
       units (over `PLACED`, 0.5) and untwisted the braid for 15 frames. Everything that puts it on its spot clears it (the
       snap, next-small-resize.md).
    2. Where both edges glide, the left edge stood between screen pixels (the snap, next-small-resize.md).
    3. The mutation run showed the carry's busy check untested (a carry placing a busy bag every frame passed every spec:
       placing the bank ended its own snap at once, a jump from 624 to 608 on the first frame); now tested.
    4. `ApplyScales`' comment said the chain refits every open panel before it draws them: `chain:ScalesChanged` draws
       first, then refits, as at the commit before this change, and the comment says so again.
  - **Left as it is: the player scrolling during a glide** (found by the second bug review, also so for a grip's snap before
    this change). A wheel scroll while its size glides is put back on the next frame (`KeepScroll` keeps `keptScroll`, read
    as the glide starts). Blizzard's scroll box gives no clean way to tell the player's scroll from its own: it sends
    `OnScroll` on every update (its own size change, `FullUpdate`, a scroll); its own size change keeps the scroll
    percentage, but `FullUpdateInternal` changes the percentage to keep the offset when the content's height changes, through
    `SetScrollPercentageInternal`, the very setter the wheel's interpolated steps go through (`ScrollControllerMixin:
    Interpolate`, `scrollInternal`, bound at `OnLoad` where no hook reaches it); a hook on `SetScrollPercentage` sees only the
    start of a wheel scroll, not its steps. A related finding, not verified in game: `KeepScroll` runs from a `HookScript` on
    the scroll box's `OnSizeChanged`, and `FullUpdateInternal` sets that script to nil and back around its work, which clears
    hooks (warcraft.wiki.gg ScriptRegion:HookScript: hooks stay "until replaced or cleared with SetScript"); the bags' render
    calls `FullUpdate` on every render (`render/scrollbox.lua`), so in game the hook likely runs only until the first render.
    The scroll box's own callback event (`BaseScrollBoxEvents.OnSizeChanged`, which `NextScrollBar` listens to) is sent from
    the same place and survives it; the spec mock models neither the clearing nor that event from its `OnSizeChanged`.

Names whole (2026-11-04): `spec/next/small_spec.lua` ("keeping its names whole": the reported bag let go at twelve cells
snapping to six with every name whole and that saved, and at five; one let go snapping wider than the screen's edge leaves
room for, both edges gliding; a press that moves nothing; one column; a saved width too
narrow opening wider, what was saved kept; the minimum holding its whole title on a step; never a title cut at its minimum
at Bag Scales 85 to 135 on two screens, needs on and either side of a step; never a name cut that a whole row was found to
hold, three screens, four Bag Scales; the whole title measured though the client measures a cut one, and again through a
restyle; laid out again for a width its frame does not show; cut only past the screen; off: nothing changes while open, a
footer's minimum laid out for the width taken; on: wider and back with no name cut on any frame, back to a saved width and
place, a longer title, the footer fitted in the draw that grows it, opening without a glide, both edges at the screen's edge,
waiting for a grip, a move (and never under it, the glide a move cut short owing one), a size glide, a Shift-click's glide, a
switch, a section drag (followed as a cancelled drag ends, with no draw) and its opening slide, a chained partner and the braid
beside it on every frame, a busy partner settled; the setting turned on; from the bug review: a chained pair drawn together in
either order glides one at a time, never overlapping, both whole after; the scroll kept through a names glide; a bank tab switch
in one glide with no name cut on any frame; a new title a frame on; the title's cloud laid out again once the open shows the
title whole; a chained pair left unbraided as it switches size while a names glide or a grip's snap runs; "the Size tab's
scales" → "Bag Scale": a new scale taken at once with the setting on, at 105% and 150% saved at the screen's width and at 150%
with a name no step holds), `spec/next/content_spec.lua` ("the cells every name needs", next-columns.md §7a), `spec/next/vendor_spec.lua`
(a secret name's least room, a long name's cloud through a restyle), `spec/next/theme_panel_spec.lua` (Make It So's narrowest
on a step), `spec/database_spec.lua`, `spec/core/constants_spec.lua`, `spec/config/catalog_spec.lua`,
`spec/config/settings_effects_spec.lua`, `spec/next/settings/content_spec.lua`. 46 mutations: 32 first caught; of the 14 that
survived, eight led to tests or made a test real (the whole-row margin, the cloud through a restyle measured as the client
measures a cut title, a width its frame does not show, opening without a glide, both edges moving, a busy partner settled, a
Shift-click's glide, a restyle's measure), four showed code nothing can observe, removed (clears of an owed follow, which
`FollowNames` checks again, and a glide ended before a refit), and two are margins smaller than `ROW_SHORT`'s 2: 1 and 1.5 pass
on the screens tested, 2 is derived for a frame on the screen's last whole pixel; 0 is caught (it cuts a name at 3396x1362 and
85%, six cells).

The second bug review (2026-11-05): `spec/next/small_spec.lua` ("keeping its names whole" → "with Fit Names While Open on": following
once the partner it waited for is dragged away mid-glide, and once it closes mid-glide; tried each frame while it waits and stopping
once it follows, closes or the setting is off; waiting while its chained anchor is dragged, then gliding; waiting for no anchor that
closes; a chained pair kept apart as one glides into its spot and the other for its names, either first; a bag gliding into its spot
kept beside its anchor as the anchor's glide is cut short; letting go of a glide into its spot as it ends or stops; waiting for a
Glitch burst and gliding from its place; back on its place when a burst is stopped part-way; back on its place when a parent shows
it again after stopping its slide in, and left where it is sliding out or as a full bag beside its anchor; a burst stopped by a move
leaving the panel to it; a partner kept beside it through a burst on the partner; a full panel left where a new screen puts it as
that ends a burst; and in "keeping its names whole": the size a restyle or a refit gives it while its size glides for its names, a
grip's snap or a Shift-click; fitted as it is opened again sliding out, setting off or on; a new Bag Scale while its size glides for
its names or a grip's snap (a test of one given while a grip holds it went in the third review, with what it tested); a bag kept
beside its anchor on every frame as a new Bag Scale refits the anchor mid-glide). 36 mutations, besides the anchor-first refit, whose test failed before it was written. Of the 28 on the fixes, 20 were first caught; eight
survived: seven led to tests (a closing anchor holding its partner; the anchor's glide carrying a bag gliding into its spot, set or
called, which was caught only in one order of a frame's tweens until a test cut the anchor's glide short; that glide's let-go as it
stops; the burst's restore leaving another placement alone; a parent's re-show leaving a full panel and a panel sliding out where
they are), and one showed a check nothing can observe, removed (the burst's restore skipping a panel a tween plays on). The other
eight each removed a call back for an owed follow (`FollowOwed` from a snap's end, a reset's end, and that one without its `glideCut`
check, `StopSizing`, `StopMove`, `chain:Arrived`, `NextDrag`'s `finish`, a partner's): with the tries each frame none changed a
test's outcome, and they went.

The third bug review (2026-11-05): `spec/next/small_spec.lua` ("resizing it" → "chained": never moving the bag beside it as a grip on
either bag is let go, four widths each, at 2560x1440 and 0.71 with Bag Scale 125% and 1920x1080 and 1 with 125% and 85%, either bag
anchoring, Clamp Bags to Screen off, the bag beside it on the same screen pixel, nothing gliding into a spot and the braid coupled on
every frame (four of the six failed before the fix, all six pass at the commit before this change); taking the bag beside it along
where a grip let go moves both its edges; "with Fit Names While Open on": never moving the bag beside it as it glides for its names
with that side still, the backpack's glide and the bank's, on three screens; owing a busy partner it settled nothing more as that
partner's own grip is let go after; waiting for no chained anchor that is closed; waiting while it glides into its spot; "the drop
first" checking the pair glides one at a time; "chaining small bags": gliding on to its spot as the anchor it glides beside closes).
15 mutations. Of the 14 on the fixes and the guards, 13 were caught: the snap's carry (always, never, ungated per frame, ungated
at its end, without both edges), its mark of a busy bag's moved spot (never set, never read, never cleared), the glide into a spot
(always and never reading the spot again), the three guards above; `carries`' check for no chained side survived (without one,
only both edges moving makes it true, which runs a chain update that settles nothing) and went. The 15th put
`chain:ScalesChanged` back in the order the second review left it: no test fails.

The fourth bug review (2026-11-05): `spec/next/small_spec.lua` ("keeping its names whole" → "with Fit Names While Open on": owing a
busy partner nothing once a refit puts it on its spot, once its anchor is dragged and dropped, dropped in the frame it was picked
up, dragged a little and chained to it, and once its anchor's glide places it and is cut short, each with the bank's own left grip
let go 37, 53, 101 and 157 wider after at 2560x1440 and 0.71, Bag Scale 125%: nothing glides into a spot and the braid stays
coupled on every frame (seven failed before the fix); a chained partner's own snap left gliding frame by frame through the anchor's
glide; both edges gliding on whole screen pixels where the screen's edge puts it back, three screens; and in "as it opens and as a
grip is let go", where a grip let go puts it back, three screens, two of which failed before the fix). 8 mutations, each caught by
the tests aimed at it: each of the four clears of the mark alone (a refit; the carry; the drag's frame; the drop) and the drag's
two together, the left edge unsnapped, and the carry's busy check placing a busy bag every frame or reading only a grip.

Not verified in game yet: a panel fitting its names as it opens and as a grip is let go, the follow's glide, and a chained
pair following it; a glide into a spot following an anchor that glides for its names.
