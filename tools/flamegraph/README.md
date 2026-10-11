# BetterBags flame graph exporter

Turns profiler sessions saved by the `/bbdb` Performance tab into flame graphs you can open
outside the game.

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
```

| Option | Meaning |
|---|---|
| `--list` | List the saved sessions (id, date, character, duration, measured time) and exit. |
| `--session <id\|latest>` | Session to export. Default: the latest. |
| `--frame <n>` | Export the session's n-th worst frame instead of the whole session. |
| `--metric <time\|alloc>` | Size bars by time (default) or by allocated memory (needs a session captured with "Track memory allocations"). |
| `--out <dir>` | Output directory. Default: the current directory. |

## Outputs

Each run writes three files named `betterbags-<id>[-frame<n>][-alloc]`:

- `.html`: a single self-contained page. Click a bar to zoom in, right-click to zoom out,
  type in the search box to highlight matches and see their share of the view.
- `.speedscope.json`: drop it on https://www.speedscope.app for its Left Heavy and Sandwich
  views. It is a "sampled" profile weighted by self time in microseconds (or bytes).
- `.folded`: collapsed stacks (`a;b;c value`), the input format of `flamegraph.pl` and
  `inferno-flamegraph`. Values are microseconds of self time (or bytes).

The SavedVariables file is executed in an empty environment, so nothing in it can touch
the tool. Decoding reuses `debug/perf/format.lua`, the same code the in-game viewer uses.
The session format is documented in `.claude/rules/perf-profiler.md`.

## Tests

`spec/tools/flamegraph_spec.lua`, run with the rest of the suite
(`~/.local/lua51/bin/busted`).
