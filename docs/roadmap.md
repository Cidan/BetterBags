# BetterBags Roadmap

Planned work that is deliberately deferred. Each item states why it waits and what it has to
preserve when it is picked up.

## Incremental search indexing

**Status:** done. The index is updated with `search:SyncKind`, which re-indexes only the items
whose indexed values changed and removes items with the values they were indexed with. The
constraints this entry listed (equivalence with a clean rebuild, the cross-bag index, category
changes, moves and re-roots, full wipes) and the randomized equivalence test that gates them
are described in `.claude/rules/search-indexing.md` §1 and §4.
