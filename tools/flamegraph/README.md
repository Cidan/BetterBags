# BetterBags flame graph exporter

Turns profiler sessions saved by the `/bbdb` Performance tab into flame graphs you can open
outside the game, and their call traces into Chrome trace files for Perfetto.

Sessions are written to `BetterBagsPerfDB` when a capture stops, and the game writes
SavedVariables to disk on logout or `/reload`. The file is:

```
World of Warcraft/<_retail_|_classic_|...>/WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua
```

## Usage

Requires Lua 5.1 (`~/.local/lua51/bin/lua` on the dev machine). Run it from anywhere:

```bash
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --list
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua                 # latest session
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --session 12 --out /tmp
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --session 12 --frame 1
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --metric alloc
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --trace          # call trace for Perfetto
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --trace --from 1200 --to 1500
lua tools/flamegraph/flamegraph.lua path/to/BetterBags.lua --trace --find RequestUpdate
```

| Option | Meaning |
|---|---|
| `--list` | List the saved sessions (id, date, character, duration, measured time, and the trace's call count when it has one) and exit. |
| `--session <id\|latest>` | Session to export. Default: the latest. |
| `--frame <n>` | Export the session's n-th worst frame instead of the whole session. |
| `--metric <time\|alloc>` | Size bars by time (default) or by allocated memory (needs a session captured with "Track memory allocations"). |
| `--raw` | Keep the profiler's own overhead in the times. Without it, sessions captured with calibration (the default) have the measured per-call overhead removed. |
| `--trace` | Export the session's call trace instead of flame graphs (see below). |
| `--from <ms>`, `--to <ms>` | With `--trace`: only the calls that ran in this stretch of the capture, in milliseconds from its start (the Calls view's "Started" column). |
| `--find <text>` | With `--trace`: only the calls whose function name, arguments or return values contain the text (any case). |
| `--out <dir>` | Output directory. Default: the current directory. |

## Outputs

Each run writes three files named `betterbags-<id>[-frame<n>][-alloc][-raw]`. Unless
`--raw` is given, times have the profiler's per-call overhead (measured when the capture
started) removed, the same adjustment the in-game "Subtract overhead" box applies; the HTML
summary says which one you are looking at.

- `.html`: a single self-contained page. Click a bar to zoom in, right-click to zoom out,
  type in the search box to highlight matches and see their share of the view.
- `.speedscope.json`: drop it on https://www.speedscope.app for its Left Heavy and Sandwich
  views. It is a "sampled" profile weighted by self time in microseconds (or bytes).
- `.folded`: collapsed stacks (`a;b;c value`), the input format of `flamegraph.pl` and
  `inferno-flamegraph`. Values are microseconds of self time (or bytes).

With `--trace` it writes one file, `betterbags-<id>.trace.json`, in the Chrome trace-event
format. Open it at https://ui.perfetto.dev (or `chrome://tracing`). Every call is a slice on
one track, in the order and at the time it ran, nested under its caller; clicking it shows
its call number, arguments, return values, and whether an error cut it short or it was still
running when the capture stopped. A call that paused (a refresh waiting a frame between its
harvest and its commit) is one slice per stretch it ran, the later ones marked `continued`.
A counter track shows BetterBags' measured time per frame. Times are raw: each slice is one
call. The file is written a call at a time, so even a million-call trace exports without
loading it all into memory; `--from`/`--to`/`--find` keep it small enough for Perfetto to
open instantly. Sessions captured with tracing off, or whose trace was removed in game, have
nothing to export and the tool says so.

The SavedVariables file is executed in an empty environment, so nothing in it can touch
the tool. Decoding reuses `debug/perf/format.lua`, the same code the in-game viewer uses.
The session format is documented in `.claude/rules/perf-profiler.md`.

## Tests

`spec/tools/flamegraph_spec.lua`, run with the rest of the suite
(`~/.local/lua51/bin/busted`).
