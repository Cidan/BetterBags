# BetterBags Roadmap

Planned work that is deliberately deferred. Each item states why it waits and what it has to
preserve when it is picked up.

## Incremental search indexing

**Status:** done. The index is updated with `search:SyncKind`, which re-indexes only the items
whose indexed values changed and removes items with the values they were indexed with. The
constraints this entry listed (equivalence with a clean rebuild, the cross-bag index, category
changes, moves and re-roots, full wipes) and the randomized equivalence test that gates them
are described in `.claude/rules/search-indexing.md` §1 and §4.

## Performance: what the captures still show

The items below come from profiler captures taken on 2026-10-12 (retail, 491 bank items, 43
backpack items). Times are with the profiler's per-call overhead subtracted unless marked raw.
Every change must start from a capture and be checked with a second one
(`.claude/rules/data-driven.md`). The capture numbers for a bank open with the built-in upgrade
provider: the read at open costs 265 ms over two frames (about 95 ms reading the bags, about
175 ms committing and drawing), then a 59 ms recalculation when the last tooltips resolve.

### Search indexing at bank open (about 65 ms)

**Status:** not started. Every bank item is indexed on every bank open: `addStringToIndex`
26 ms over 4,419 calls, 22,083 interval-tree inserts (`IntervalTree.InsertRecursive` 15 ms,
`RecalculateMinMax` 13 ms, about 45 per item), `Search.Add` 6 ms, `indexSnapshot` 4.5 ms.
Options: build each number index in bulk instead of one insert at a time, or index only the
fields search queries and search categories use. **Preserve:** the index must equal a clean
rebuild (the randomized test in `spec/search_spec.lua`, search-indexing.md §1); both bags share
one index (§4).

### Late tooltip resolution recalculates the whole bank (59 ms)

**Status:** not started. About 0.8 s after the bank read, 24 tooltips resolve and
`TooltipScanner:OnTooltipDataResolved` recalculates both bags, all 491 bank items, to update
those 24. A recalculation scoped to the resolved items (re-scan, re-index, re-categorize only
them) would cost a fraction. **Preserve:** search categories that match tooltip text must
re-categorize those items; the index must still equal a clean rebuild; the re-scan cap
(tooltip-scanning.md §2).

### Reading tooltips at harvest (45 ms per bank open)

**Status:** not started. `TooltipScanner.ExtractRetail` costs about 92 µs per item (491
calls, 45 ms), mostly Blizzard's `C_TooltipInfo.GetBagItem`. Scanning only when something
needs tooltip text (a tooltip search, or a search category that queries it) would skip it on
most opens. **Preserve:** tooltip search and tooltip-based search categories must see the text
before they are evaluated, cold-scan healing (tooltip-scanning.md).

### Drawing a whole bank tab from scratch (55-78 ms)

**Status:** not started. Opening the bank draws its 465 buttons for the first time
(`SetItemFromData` 22 ms, `Themes.GetItemButton` 9 ms, `UpdateCooldown` 4.6 ms, grid layout
13 ms; the Sonata overhaul removed `GetItemButton`, a button's decoration is now a field read,
item-drawing.md §7a; not re-measured), and every tab switch releases the old tab's buttons and draws the new tab's from
scratch (353 first draws, 78 ms, in one switch). Showing the grids runs Blizzard's show
handlers on every newly visible button (`GridFrame.Show`, up to 40 ms at open, 22 ms in a
switch). This is a design question: keeping inactive tab views drawn and hidden would trade
memory and hidden-frame cost for instant switches. **Preserve:** one static button per slot,
claim-then-sweep ownership (layout-rendering.md §1), no frame creation after boot.

### Buttons fresh from boot are reset on their first draw (7 ms)

**Status:** not started. A button is marked blank by `ResetVisuals`, and its next draw skips
the reset (item-drawing.md §7a), but buttons created at boot are never marked, so the first
bank open after login reset all 466 of them. Mark buttons blank at creation once the code
confirms a freshly created button really is blank (decoration textures, count, quality,
cooldown).

### Pawn (about 100 ms per bank sweep)

**Status:** deliberately not cached. With Pawn as the upgrade provider, `ResolveUpgrade` cost
103 ms per bank sweep: a median 0.21 ms per item, 445 of 491 items over 0.05 ms (Pawn's full
upgrade comparison for gear; non-gear exits early). Pawn verdicts are asked every sweep by
design (caches.md §2: an earlier caching attempt hooked Pawn and made sorting hitch, and was
reverted). The lever is fewer sweeps, which the bank fixes already cut from three to two per
open. **Preserve:** do not hook Pawn's functions or over-engineer the integration.

### Bank tab switches: the fixed 12.6-15 ms

**Status:** instrumented, not yet captured. Every tab switch spent 12.6-15 ms inside
`Bank.SwitchToGroup` in Blizzard calls, the same with zero or 529 buttons reacting. The two
candidates now go through measured functions (`BetterBags.SetBlizzardBankType`,
`BetterBags.TriggerItemContextChanged`, perf-profiler.md §2); a capture of tab switches will
show which one.

### Show Bags (27 ms on, 16 ms off, without Masque)

**Status:** partly done (Masque no longer un-skins released buttons; unchanged buttons skip
their redraw; released buttons are reset once). Left: Blizzard's show and hide handlers on the
145 empty-slot buttons (`GridFrame.Show` 5.5 ms on, 3.9 ms off; `GridFrame.Hide` 1.8 ms),
drawing the empty slots (`SetFreeSlots` 4.7 ms), and 2.2 ms directly in `Refresh._Resume` that
no measured call explains (a capture with "Track allocations" would show whether it is garbage
collection). With Masque on, its skin pass adds about 10 ms for the buttons drawn for the first
time.

### Search categories re-run every sweep (1-5 ms)

**Status:** not started. `Items:RefreshSearchCache` evaluates every search category against the
whole index on every sweep. Re-running only the categories whose results could have changed
(the items re-indexed this sweep) would cut it. **Preserve:** category priority rules (lower
number wins, search wins ties; data-loader.md §8).

### Bank loading screen

**Status:** planned. The bank window now shows at once and fills in when its item data has
loaded (refresh-scheduler.md §11); it is empty meanwhile on a cold open. A loading screen goes
in that window while the data loads.

## Profiler and tooling

### Bank-open timings look wrong

**Status:** not investigated. Bank opens feel worse than the worst frames the captures report.
Two things point at the measurements: frame durations come from the profiler's virtual clock,
which excludes its own time (3.07 s of a 4.0 s capture with arguments recorded), so real frames
are longer than shown; and Blizzard's addon-profiler reading paired with one 20 ms frame was
2,885 ms, which no single frame can be. Check how frame durations and Blizzard's readings are
paired before trusting worst-frame numbers for long frames.

### SavedVariables size

**Status:** deferred by decision. Captures with arguments recorded reached 35 MB of
SavedVariables; a file that size failed to load and the game reset the whole file, including
BetterBags' settings (a 23 MB file still loaded). Cap the call-trace data saved, well under
23 MB, dropping the oldest captures' traces first.

### Recording arguments dominates capture cost

**Status:** known. Describing call arguments is most of the profiler's own time (2.75-3.07 s in
4-5 s bank captures). Timing captures should turn "trace arguments" off; turn it on only when a
question needs the arguments (redraw reasons, layouts).

### Spec isolation

**Status:** known debt. The suite's own order passes (and is what CI runs). Measured on
2026-10-16, after the windowing and Sonata overhaul:

- Run directly before `refresh_pipeline_spec`, `spec/frames/bankslots_spec.lua` and
  `spec/quickfind_spec.lua` fail 12 of its bank tests (3 failures, 9 errors); this predates the
  2026-10-12 work. `spec/frames/tabs_spec.lua` no longer does (rewritten in the overhaul).
- Every spec file passes run alone except `orchestrator_spec` and `targeted_sweep_spec`, whose
  `Database` and `Constants` stubs miss methods `data/items.lua` calls (they fail alone on the
  pre-overhaul commit too).
- `busted --shuffle` (seeds 1-5) fails 18 to 90 tests, all in specs the overhaul did not touch
  (`categories_spec`, `items_spec`, `equipmentsets_spec`, `loader_spec`, `async_spec`,
  `orchestrator_spec`, `targeted_sweep_spec`) plus `bags/backpack_spec`, which loads the real
  `core/database.lua` and fails when any earlier file registered a `Database` stub. The
  pre-overhaul commit fails 58 to 80 with the same seeds (different orders, as it has fewer
  files). The specs the overhaul added remove the stubs they create, restore what they replace
  in file-level teardowns (busted shuffles blocks too, so a restore in one block's teardown can
  run first), and pass alone and with their blocks shuffled.

`events:Init` no longer leaves duplicate handlers behind, which removed one source.
