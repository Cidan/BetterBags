---
paths:
  - "next/content.lua"
  - "spec/next/content_spec.lua"
---
## 7a. Section columns (`NextCanvas:ColumnSplit`, `columnRows`, `renderColumns`)

Asked: sections side by side, because a bag of many one-item sections is tedious to scroll: "a layout option to ... have N
columns by default", "top-to-bottom or side-to-side", "window determines the size of columns", and "most players play in
window detached/non docked mode, so optimize for that". Automatic packing (each section taking the first row with room) and
dragging a section beside another were considered first; this came instead, and drag-to-reorder in columns is the next stage.

**The hard rule: never disjoint rows.** Asked, in these words: "NO, absolutely no disjoint rows. this is a hard constraint.
never, ever. at all. this is a design decision for visual clarity." Sections stand side by side only in rows: every section
of a row starts on the row's line, so their titles share it, and the next row starts below the tallest of them, in both fill
orders. Columns stacking on their own heights are never an option, though they were measured denser (the classic bags do it).

- **Settings**, per bag, in its Layout tab's Sections, BetterBags Next only (`config/catalog.lua`; saved apart from the classic
  bags' `columnCount`, whose saved values would otherwise change Next's layouts): **Section Columns** (`sectionColumns`, 1 to 4,
  default 2, `const.NEXT_SECTION_COLUMNS_DEFAULT`), **Fill Order** (`sectionFill`, Side to Side by default, or Top to Bottom),
  **Wide Sections Span Columns** (`sectionSpan`, on) and **Wide Column Limit** (`sectionWideRows`, 2 to 10, default 2). The last
three are disabled at one column, the limit also with wide sections off. Each sends `next/SectionColumnsChanged` (the bag's
  kind), and that bag's panel lays out again: no read of the bags. The settings window shows the rows' state again on it.
- **Section Order is each design's own** (`nextSectionSort`, Size Descending by default; the classic bags' `sectionSort`, Alphabetically).
  Asked: "2 columns, side to side, wide sections on, wide column limit of 2, and sort order is descending for sections by default. do
  this for all bags", then of that default: "i did mean bbn here". `DB:GetSectionSortType` and `SetSectionSortType` read and write the
  design in use, so the setting's row and the data phase need no other change. A design switch recalculates the backpack when the two
  sort it differently (`BagSystem:Switch`): what the bags last read was sorted by the other. `DB:SplitSectionOrder` carries over, once,
  an order a player chose when both designs shared one. AceDB saves only what differs from a default, so a BetterBags Next player on
  Alphabetically before, chosen or not, takes the new default: a saved value cannot tell them apart.
- **Sizes change the order:** with Size Descending a section's place follows how much it holds, so a read that changes a count can
  move sections, in rows too. A read that changes no count moves none, and a section's own width stays held through it.
- **What decides it:** the panel names a source (`canvas:SetColumnSource`, `panel:SectionColumns`), read at each layout. Only
  bags have one: the vendor's cards stay one column. The Show Bags view (a bag's slots in order, a guild tab by itself) is one
  column. One column takes the code path it always did, unchanged.
- **The split** (`ColumnSplit`): the cells a row holds at the width to lay out for, split into whole cells per column, the spare
  ones in the first columns: 8 cells are 4+4, 3+3+2 or 2+2+2+2; Quiet's 9 are 5+4. Decided in units, never on lengths rounded
  to the grid (next-pixel-perfect.md §3). A window that cannot give each column `MIN_COLUMN_CELLS` (2) shows fewer. Between columns
  is the theme's icon gap, so every icon in the bag stands on one grid (`gridLengths`, with `section.gridCells` so every section
  closes its gap for the whole width): that gap is what makes 8 cells 4+4. A bigger gap makes 3+3, which is taller than not
  sharing at all (two 8-item sections: stacked 152, 4+4 118, 3+3 168, Default's sizes).
- **Fill orders** (`columnRows`): Side to Side goes across a row and then the next. Top to Bottom goes down a column and then the
  next, its rows still lined up: K sections in N columns are `ceil(K / N)` rows.
- **Wide sections**, asked: "wide rows consume multiple columns", as a toggle; then "the number of rows before something is
  considered a wide column. default this to 2, not 3. min 2". A section that would **reach** the limit in its column is wide:
  at 2, any section that does not fit one row of its column (asked of 6 items in a column of 4: "you can see tradeskill not
  expand out into columns"). It takes as many columns as keep it under the limit (`needed = ceil(n / (limit - 1))` cells),
  every column when even that is not enough. Side to Side, one that does not fit in what is left of its row starts the next
  row, leaving the rest empty: order is never given up to fill the hole. Top to Bottom, a wide section takes a row of its own
  across every column, and the sections between such rows fill down their columns: a section is wide when it reaches the limit in
  the column it lands in, and the sections either side of it land again as their own runs (a split of 5 and 4 can treat two sections
  of 5 differently). Asked of the first column alone a section landing in the narrower one reached the limit; asked of the narrowest
  alone, a split of 5 and 4 gave up all that columns gain.
- **Held while it shows** (`neededCells`), asked: "content changes and isn't always stable, so rows above or below it might get
  gapped out". The cells a section needs are decided the first time they are asked for while the canvas shows, and held until the
  layout starts afresh: its bag closing (`Settle`), a sort or anything else that sets `resetLayout` or wipes
  (`slotInfo.layoutResets`, counted in `Phase11_CommitAndDispatch`, which a read adding a bank or guild bank tab does too:
  refresh-scheduler.md §11a), another tab or view, or a new limit. That is when gaps
  collapse too (data-loader.md §13). So one item coming or going never pushes sections across the bag: a section reaching the limit
  grows taller where it stands, one shrinking stays as wide, and a hidden canvas holds nothing, so a bag opens with what it holds.
  A canvas in columns lays out again each time it shows (its `OnShow`), a parent showing it too (Alt+Z): a bag can open on what it
  drew before it closed, with no read to lay it out, and from its second open the next read, one item more, decided every section's
  width (found by the adversarial review; holding what sections needed with nothing laid out, its first fix, held a width the bag
  did not show). A section that grew while the bag was open takes its width as the bag opens.
  A sort that moved nothing has no read to count a reset, so it says so (`bags/SortSettled`) and the bag lets go (`ReleaseWidths`).
- **Full width:** Recent Items above the columns and Free Space below them, as the classic bags' global sections do. Dock cards
  lead the column as ever.
- **Titles:** one too long for its section is cut short, its count kept (`placeTitleRow`; `section.titleCut`; a font string keeps
  the width it was cut to, so it is set back with `SetWidth(0)` and its text again before measuring, next-themes-art.md §14). The full
  name is on its header's tooltip. The line after a title hides when no room is left (`LINE_MIN`), where it would draw backwards;
  that holds at one column in a narrow window too.
- **Nothing between columns.** A divider was built and removed, asked: "remove that divider for columns, looks terrible".
- **Dragging reorders, as in one column:** asked, "we're not storing column positions, just list positions here, so what we save is
  still just an ordered list". The room is a place in the list (`drag.index`, as ever): `renderColumns` stands the dragged section there
  among the others, the rows follow, and whatever moved slides there. A drop saves the list as one column does (`SaveOrder`), and tabs,
  the other bag, sellers and docks work as ever. Section Order applies after a drop as in one column: a place saved is a pin. A drop back
  in the place it had saves nothing and recalculates nothing (`IndexOf`, one column too), or it would pin the section and stop it
  following the order; a reorder recalculates its own bag, the guild bank too (it was left out, and its order stayed old until its next read).
  - **Where it goes** (`columnIndexAt`): the place whose slot's top left is nearest the held section's top left (the cursor less the
    point grabbed, `DragIndexAt`), so where along its header it was grabbed does not matter, and a pick-up finds its own place at no
    distance. A still cursor chooses nothing (`state.moved`): a read's glide can still be carrying the section it picked up, and once the
    cursor moves it goes by where it looks. `dragSlots` works out, for every place, where the section would stand with the rows laid out that way, once a drag (again
    when a read, a held width, the columns, the fill, the wide settings or the grid change them; a pass of the rows per place, 2 to 12 ms at
    60 sections, measured offline with mocks). Both fills and spanning sections take no special case, as `columnRows` lays each place out.
  - **Places sharing a spot.** Reported, Back then Consumable (spanning) then Quest: "i can't drag a span section under the last single
    item section ... quest doesn't move above consumable". A section spanning its columns starts the row after the one before it, whether
    or not another fits beside that one, so after Back and after Quest it stands in one spot, and only the others differ. Choosing the
    first made 1,865 of 10,964 places unreachable in 300 random bags, and 187 of 1,109 pick-ups moved the room with the cursor still.
    Now, past the spot's bottom the section takes the last of its places, which leaves no hole. Otherwise the place the room holds stays,
    above the spot's top too (taking the first there made the result depend on the cursor's speed, and a 5-pixel nudge reorder the bag),
    and arriving from another spot it takes the last. A spot is places side by side in the list and of one size (`slots[at + 1]`): filling
    down with unequal columns, places far apart can start at one corner, and comparing corners alone sent a section four places on and
    made it 450 pixels wider.
  - **What a wide section cannot do by itself:** take a place that leaves a hole (Back, Consumable, Quest with Consumable already moved).
    Drag the neighbor past it to get that order. Filling down, when two spots of different sizes start at one corner, the later is only
    reached the same way (24 of 4,005 random drags in a limit-3 bag of unequal columns, none filling across).
  - **Left as it is:** filling down, a section dragged far below a short column goes by the nearest corner, which can be in a longer
    column beside it (the last place is taken on its own slot; only blank space below the rows shows this). A section dropped onto a tall
    section's exact corner can need a few more pixels, as leaving makes that section rise. Dropping on a seller or a dock ends the drag at once,
    and the height with it, as it always did: the section leaves the column anyway. A read or a section leaving mid-drag can shift the room under a
    still cursor, and a drop then saves what the screen shows.
  - **Staying put.** Where a slot stands depends only on the held section's place, and among places sharing a spot the room does not
    move, so the room moving cannot send it back. But the room's place changes the bag's height, and a shorter bag shortens what its box
    scrolls: at the end of a scrolled bag the box pulled the canvas down from under a cursor held still, which then asked for another place,
    and the room flipped every few frames (11 of 1,800 runs; heights swinging 2388 to 2687). So through a drag the canvas never shrinks
    (`drag.heldHeight`; a read or a released width starts it over), auto-scroll stops at where the rows end (`AutoScroll`'s `beyond`:
    `HeldHeightExtra`; it had run on into the height held, showing nothing, 450 to 600 pixels of it with wide sections off), and when the
    section lands the height comes down with the landing (`ReleaseHeight`, started by the next render, which knows where the rows end after the
    room's last move), not all at once after it (84 pixels at once on a scrolled bag, 450 after a drop off the panel). A read during it ends it.
  - **Held, a section keeps its shape** (`drag.heldWidth`, `drag.heldLayout`): drawn for a column of other cells it hopped off the cursor (245
    pixels at Bag Scale 85), and a release there could click another section's item. It takes its place's shape once it lands. Its room is
    still measured for the place (`drag.height`, `MeasureSection`). Landing, it is not laid out at all (`drag.landingFor`): its frame changes
    scale every frame, and laid out on each new grid it restyled every button every frame (2,955 restyles for a 197-icon section's landing, 197 without);
    only once more for a read that changed what it holds (`drag.layoutOwed`). A landing cut short (the bag closing) ends as it would have, so the order it
    saved is the order shown and the bag recalculates (`state.landed`).
- **Small panels** (next-small-mode.md §14g): `Widest(layoutWidth)` is what keeps the columns as they stand at the width let go at (`columnRows`, so what
  stood side by side still does): each column as wide as the largest section beside another, at least `MIN_COLUMN_CELLS` so a snap
  never takes a column away; one spanning some of its columns sharing what it needs among them; one alone in its row only what it
  needs, since it can take the row (not filling down, where the sections above it hold its column); or what Recent Items or Free Space
  hold. Every column as wide as the largest section, spanning or not, left a bag of 14, 4 and 7 let go at 25 cells 25 wide, and a
  lone section of 6 at 12: asked of one column, "it should shrink back down". Letting go of a grip lays out once more where it
  was let go (in columns only), so what the snap moves glides from there: sizing places everything at once, and the second column
  jumped hundreds of pixels with the window still wide behind it. A frame within half a pixel of the width the panel lays out
  for stands for that width (`FrameLayoutWidth`): frames stand on whole pixels, and a frame a fraction under what its columns take
  read as a cell fewer, so a press on a grip that moved nothing took a column away, each press another. The root was older; at one
  column it cost a cell, and columns made it a column.
- **Dock cards:** a card is as wide as the panel's column whatever its section's width (`listProto:Lead`), the section at its own
  size inside it: as wide as a section in a column of four it was 118 wide under a warning of 282. A read of its bag leaves the
  buttons of a section waiting in a card to the dock (`claim`), which draws them on the card's grid: sized for the column's, they
  stood a fraction of a pixel off until the card next laid out, and made a test fail in about 4 runs of 10, as widgets restyle in
  no fixed order (`pairs(self.widgets)`). So a read of its bag lays the card out (`boundAt`, read by `Pulse`): a sort gives a docked
  section other buttons in the same number. So does a flight seating its section (`Seat`), which laid nothing out. Both are older
  than columns.
- **Top to Bottom reflows:** a section appearing or leaving changes where the sections after it land, so many can move, in spite of
  held widths: filling down has no other way to keep its columns even. Measured: a neighbour leaving moved 1,060 of 2,708 sections
  (2 columns, 300 random bags). Side to Side moves only what comes after it in its row.
- **Known, not fixed:** a small panel left at its minimum width lays out for that minimum live (`RestingLayoutWidth`, `MinWidth`
  following the footer's text), and its frame only takes it in `FitSmall`: a free-slot count gaining a digit can show one cell, and
  so a column, more than the frame holds until the panel is next fitted. It needs a panel at exactly its minimum width, and the
  formula is older than columns.
- **Not done:** saving a section in a column: order is one list, and a section stands where the list and the window put it.

Measured offline on real bags (title widths estimated from a screenshot, Default's sizes, 8 cells, 2 columns, scroll height, before
the limit was 2): your backpack 538 today, 436 Side to Side, 420 with wide sections; a long-name profile 1428, 1056, 1040; a 33-section
bank 5106, 6262, 4582: without wide sections its 197-icon section takes 50 rows beside blank space. Not measured in game.

Coverage: `spec/next/content_spec.lua` ("section columns": the split, spare cells, both fills, rows as tall as their tallest, random
bags keeping every row on one line and the order, Recent Items and Free Space, fewer columns in a narrow window, deciding on the width
to lay out for, none without a source, back to one column; titles and lines; "wide sections": columns taken, a new row, the limit,
top to bottom, what it holds while its contents change, random bags; what moves; how wide it needs to be; "a section's header art"),
`spec/next/bag_spec.lua` ("section columns": its own bag's setting, Show Bags, the message, the tooltip, holding from the second
open and after Alt+Z, a sort that moved nothing, the logout), `spec/next/drag_spec.lua` ("with section columns"),
`spec/next/dock_spec.lua` (a card's width, flying back to a column), `spec/next/content_spec.lua` ("reordering by drag": the room under
the cursor in a row and between rows, committing and cancelling, nearest slot, one answer wherever the room stands, filling down, a
section spanning columns, places sharing a spot, the height kept through a drag, Recent Items and Free Space, a read during a drag, a released
width, random bags with the room anywhere), `spec/next/drag_spec.lua` ("with section columns": the reported Consumable under Quest, a drop in
its own place, landing back; a guild reorder recalculating), `spec/next/lift_spec.lua` (the cursor on a frame that narrows), `spec/next/small_spec.lua` ("with section columns": a press that
moves nothing on real screens, a real pixel's drag, gliding as it snaps), `spec/next/pixel_perfect_spec.lua` ("in section
columns": every shipped theme, one grid across columns on four screens, a Bag Scale, a read of a docked section's bag; a pieced bar in
a dock card), `spec/integration/logout_spec.lua`, `spec/integration/guild_bank_spec.lua` (late and shifted answers), `spec/next/vendor_spec.lua`,
`spec/config/catalog_spec.lua`, `spec/config/settings_effects_spec.lua`, `spec/database_spec.lua`,
`spec/next/settings/content_spec.lua`, `spec/refresh_pipeline_spec.lua` ("counts each time a kind's layout starts afresh"),
`spec/integration/next_settings_spec.lua`.

## 7b. Compact sections (`NextCanvas:compactPlaces`, `compactFit`, `compactShapes`, `compactLayout`, `compactWidest`)

Asked: "a 'compact' mode to columns, as a single toggle", that "aggressively pulls categories together and ignores the concepts
of columns", each section pushed "as far left as it can, with a minimum of the icon grid's normal gap", "take into account header text as
well so it doesn't overlap". And the constraint: "always make sure we round to the nearest item grid position -- no disjoint item button
placement ... compact mode must never violate this constraint." Then, of a bag with wide sections off, Consumable 16 with Miscellaneous and
Quest below it beside nothing: "in this one very, very narrow case, i'm okay violating our 'no disjoint rows' constraint ... generally, try to
compute what the most compact layout is possible, but making sure section names are always visible."

- **The setting:** **Compact Sections** (`sectionCompact`, per bag, off by default, BetterBags Next only, `DB:GetNextSectionCompact`), in
  a bag's Layout tab's Sections, right after Section Columns. Off at one column (`disabled`). Sends `next/SectionColumnsChanged`, as the
  others do: no read of the bags. **Fill Order** is off while it is on: with no columns there is nothing to fill down.
- **Every icon in the columns of one grid:** a section starts `start` whole cells along (`step`, from `gridLengths`), and every icon a whole number of steps further on. Nothing is
  ever placed across by a measured pixel length. So a section's left edge and every icon line up with every other section's, wherever it stands down the bag.
- **Down the bag, the usual spacing, nothing more:** a section under another stands `SectionSpacing` below it, the same as outside compact, in whole pixels. Asked, of a first version
  that kept icons on a grid of rows too, each title taking a whole row of it (about 14 pixels more between sections): "why when we have compact sections, do we have a wider gap on the
  Y axis between sections? feels... like that defeats the purpose". So a section tucked beside a taller one does not line up with that section's rows (the "no disjoint rows" the player
  gave up for this, below). Compact is never looser than the layout it replaces.
- **Packing** (`compactPlaces`): in the bag's order, each section takes the place where it ends highest, whichever its bag's columns, beside a
  taller section or in a hole an earlier one left; for one height, its usual shape, then the leftmost place. Only here does §7a's "no disjoint
  rows" not hold (asked, above); section columns keep it.
- **Judgment call:** a later section can stand ahead of an earlier one to fill a hole: the first section of a list never moves, each after takes the
  best of what is left. So a bag's order is a priority, not a reading order. Asked for the most compact layout, and order given up only where a hole
  would otherwise stay empty.
- **A section's shapes** (`compactShapes`), widest first: what keeps its icons within a column, or with wide sections on within its Wide Column
  Limit (`ceil(n / (limit - 1))`, up to the row), in as few cells as hold the same rows (`ceil(n / rows)`). So 6 at a limit of 2 is 6 cells, 9 in a row of
  8 is 5 and 4 rather than 8 and 1, and 16 with wide sections off in columns of 4 is 4 and 4 and 4 and 4. Then each narrower one, more rows
  for fewer cells, taken only when that ends strictly higher (6 icons beside a section leaving two cells: 2 cells, 3 rows). With wide sections on, never as
  many rows as its limit: that is the player's setting.
- **A name is always whole** (`compactTextCells`): no shape is narrower than the section's title's place (`Sections.Title.X`), its whole name, the gap to the
  count (`CountGap`), the count, and what the theme keeps after them (`Sections.Compact.TextEnd`), in whole pixels on the grid it is drawn on, as `placeTitleRow`
  works its room out: `ceil((text + gap) / step)`. A name too long for the whole row is cut, its count kept, as it always was. A count gaining a digit past its cells
  packs the bag afresh rather than cut the name.
- **Held while it shows** (`compactLayout`, `heldPlaces`), as §7a's widths are held and for the same reason: each section keeps the cell it starts on and its
  cells until the layout starts afresh, and only finds its row. One more item grows it taller where it stands, and what is under it moves down, never across the bag.
  Packed afresh for: a read that starts the layout over, a sort, another tab or view, its bag closing; a window of other cells or other settings; a section coming or
  going (waiting in a dock, leaving, gone); a drag; a count outgrowing its cells; a theme.
- **Recent Items and Free Space** stay at the full width, above and below, as in §7a. Dock cards lead the column as ever.
- **A window too narrow for its columns** (`ColumnSplit`): compact keeps a grid down to two cells, where columns fall back to one: sections of one
  cell can still stand side by side.
- **Drawn on another grid** (`titleFits`, `section.givenWidth`): held in a drag or in a dock card a section is drawn shrunk, where each length rounds otherwise and its width
  comes up short, and a compact section has no room to spare: a name that exactly fit its cells was cut while held, and in the card after a drag, whose card read the short
  width (both found by the bug reviews, 3396x1362 at 65%). Whether a name fits is decided on the canvas's grid, against the width the section was given, so at rest nothing
  changes, and a dock card lays out a section from another panel at that width too, never at its frame's.
- **Dragging:** the room is a place in the list (§7a). Where the dragged section stands at a place depends only on the sections before it, so `dragSlots` finds every place in
  one pass of them, not a pass per place. A drag packs afresh, so the others make way by the same rule.
- **Small panels** (`compactWidest`): what the sections reach, in cells, and from there the fewest cells that leave every section where it stands, as a narrower
  window can narrow a column and so a section's shape: 16 icons with wide sections off, two rows of eight at 16 cells, need 15, where the first column is still eight. A
  width let go at snaps to one the snap leaves alone. A lone section of one cell needs two: a window of one has no grid. At the window it shows them in, it goes by where they
  stand now, so a press on a grip that moves nothing moves nothing (found by the bug review: a section that had lost items since came in a cell).
- **A name cut for the whole row** (`section.titleWhole`): measuring it never touches the title, which keeps the width it was cut to and measures that. Setting it back to measure it left it
  whole with no layout after it to cut it again, running over its count through a drag (found by the bug review). A section taken from the pool for a new name has its title's width set back
  first: a theme restyles the pool too, which cut the old name again, and the new name took the old one's width (found by the next review: "Back" across a whole row).
- **Themes:** `Sections.Compact.TextEnd` (next-themes.md §3): Default 0; Guild Wars 2 8 and Papercraft 4, the insets of their title bars at the other
  end; Make It So 16, its bar's end cap. Everything else comes from what a theme already sets: its icon and gap (the grid), its title's place,
  fonts and count gap (the text), its section header and spacing (how far apart sections stand).
- **Measured offline** (PUC Lua 5.1, mock widgets, wide sections off, 2 columns), compact on against off: 15 sections, a render 1.26 / 1.11 ms; 60 sections at 30 cells, a render 5.16 / 4.45 ms,
  packed afresh 10.69 / 4.39 ms, every room of a drag (`dragSlots`) 8.76 / 1.61 ms (measured with whole rows; the packing's work is the same). Not measured in game.
- **Known:** a name's room is worked out on the grid it is drawn on, as it must be not to be cut, so a name within a pixel or two of a cell's end can take a
  different number of cells at another Bag Scale, and so the packing can differ. A layout otherwise does not depend on the grid (next-pixel-perfect.md §3; tested at Bag Scales 50% to 150% on three
  screens). A section of few cells looted into while the bag shows grows tall where it stands (25 items in one cell's width), until the next sort or close: the same hold as §7a's.

Coverage: `spec/next/content_spec.lua` ("compact"; "packing": the reported bag, the usual spacing down, one grid across, names whole, a hole filled ahead of its order, a narrower shape, its usual shape, a name's width, the
limit; held: moved down never across, afresh when told, a section going or coming, a count outgrowing its cells, a window of other cells; the exact fit, the gap, wide sections, wide sections off,
icons across a name's width, a name too long, Fill Order, a narrow window, one column, off; themes: title, count gap, `TextEnd`, none, another grid, a theme applied; `Widest`; 400 random bags keeping every
icon in the grid's columns, nothing overlapping or closer than the spacing, every name whole and each section as high as it can stand; 300 random snaps leaving every section where it stands; reordering by drag; a drag working each section's width out once; drawn on another grid; a dock and back), `spec/next/pixel_perfect_spec.lua` ("compact": one grid measured on four screens, at a Bag Scale, in every shipped
theme; the same cells at every Bag Scale; a grip; "in section columns": a real drag), `spec/next/small_spec.lua`, `spec/next/bag_spec.lua`, `spec/config/catalog_spec.lua`,
`spec/config/settings_effects_spec.lua`, `spec/database_spec.lua`, `spec/core/constants_spec.lua`, `spec/next/settings/content_spec.lua`, `spec/sonata/next_themes_spec.lua`,
`spec/integration/next_settings_spec.lua`.

Mutation-tested: 110 mutations of the first version, which kept rows, and 72 of the packing, every one caught but what cannot be told apart. Of the packing's, seven first survived: five led to tests (a
drag's slots under Recent Items, their height, how far down they stand; a snap for another window, and for other sections); and two cover for each other (`compactKey`'s start and `compactWidest` counting a
section's start: either alone finds a layout that fits). Rounding a name or a count up alone cannot be told apart either, as any fraction left in the sum still goes past a whole pixel, while both together are caught.

**Not seen in game** since the packing. To check: a bag with wide sections off and a tall section (the reported Consumable 16 with Back, Item Enhancement, Miscellaneous and Quest), on a few themes; drag a section; resize a small panel; loot into a small section with the bag open.
