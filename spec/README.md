# BetterBags Test Suite

Unit tests for BetterBags, powered by [busted](https://olivinelabs.com/busted/) with Lua 5.1.

> **The suite is Lua 5.1 only.** `spec/setup.lua` aborts before any test code runs if `_VERSION` is not `"Lua 5.1"`. If you see a "BetterBags test suite requires Lua 5.1" error, the `lua` / `busted` on your `PATH` is the wrong interpreter — install Lua 5.1 (or a 5.1-compatible LuaJIT 2.x) and `luarocks install busted` against it, then rerun. See `CLAUDE.md` § "Lua Version" for the full policy.

## Local setup (Lua 5.1 toolchain)

Install the test tools with **your system-installed LuaRocks** against a **Lua 5.1**
interpreter. This is exactly what CI does (`.github/workflows/test.yml` pins Lua 5.1 via
`leafo/gh-actions-lua@v10`, then `luarocks install busted luacov`). **Never commit a rocks
tree into the repo** — `busted`/`luacheck`/`luacov` are per-developer tools, not addon
dependencies, and `install-deps.sh` deliberately does not install them.

- **`busted` must run under Lua 5.1** — the suite's `_VERSION` guard rejects anything else.
- **`luacheck` is interpreter-agnostic** — it lints against `std = "lua51"` (set in
  `.luacheckrc`) regardless of which Lua runs it, so a 5.4 `luacheck` on your `PATH` is fine.

### If your system Lua *is* 5.1

```bash
luarocks install busted luacheck luacov   # rocks land in your normal 5.1 tree
busted
```

### If your system Lua is a different version (e.g. 5.4)

Point LuaRocks at a separate Lua 5.1 interpreter and install into a user-local 5.1 tree.
A 5.1-compatible **LuaJIT 2.1** works (`_VERSION` is `"Lua 5.1"`); real `lua5.1` works too.

```bash
# Example: LuaJIT from Homebrew/Linuxbrew. Replace the prefix with your own
# (`brew --prefix luajit`, or the prefix of any Lua 5.1 install).
LUA51_PREFIX="$(brew --prefix luajit)"

luarocks --lua-version=5.1 --lua-dir="$LUA51_PREFIX" --local install busted
luarocks --lua-version=5.1 --lua-dir="$LUA51_PREFIX" --local install luacheck
luarocks --lua-version=5.1 --lua-dir="$LUA51_PREFIX" --local install luacov
```

This installs into `~/.luarocks` (the 5.1 rocks tree coexists with your 5.4 one). The 5.1
`busted` launcher is `~/.luarocks/bin/busted`. Run it directly, or put `~/.luarocks/bin`
ahead of your other rocks bin dir on `PATH` so plain `busted` resolves to the 5.1 build:

```bash
~/.luarocks/bin/busted            # explicit
# or, after `export PATH="$HOME/.luarocks/bin:$PATH"`:
busted
```

## Running Tests

```bash
# Run all tests
busted

# List tests without running
busted -l

# Run a specific spec file
busted spec/query_spec.lua
```

## Directory Structure

```
spec/
  setup.lua              # Busted helper -- loads mocks, Ace3, and creates the BetterBags addon
  basic_spec.lua         # Ace3 library loading verification
  query_spec.lua         # QueryParser (Lexer/Parser/Query) unit tests
  serialization_spec.lua # Serialization (Serialize/Deserialize/Base64/DeepCopy) tests
  intervaltree_spec.lua  # IntervalTree (Insert/Query/Remove) tests
  sort_spec.lua          # Sort comparators (items, sections, priorities) with stub modules
  color_spec.lua         # Item level color tier calculations
  context_spec.lua       # Context object (Set/Get/Cancel/Copy/Timeout)
  pool_spec.lua          # Object pool (Acquire/Release/reuse)
  bucket_spec.lua        # Debounce/throttle with controllable timer mock
  windowgroup_spec.lua   # Window group show/hide toggling
  movementflow_spec.lua  # Game context detection (bank/mail/trade/merchant)
  stacks_spec.lua        # Stack data structure (add/remove/count/root promotion)
  events_spec.lua        # Event system (message register/send/catch)
  search_spec.lua        # Search engine (indexing, queries, ngrams, comparisons)
  binding_spec.lua       # Item binding detection (bound/unbound/BOE/soulbound/account)
  slots_spec.lua         # SlotInfo data structure (changeset tracking, empty slots)
  tooltip_spec.lua       # Tooltip cache management and retail extraction
  helpers/
    wow_mocks.lua        # WoW global API mocks (CreateFrame, C_Timer, string/table funcs, etc.)
    addon_loader.lua     # BetterBags addon creation + module loading helpers
```

## Writing New Tests

Each BetterBags module file expects `...` (vararg) to resolve to the addon name. The test helpers handle this automatically.

### Adding tests for a new module

1. Create `spec/<module>_spec.lua`
2. Load the module and get a reference:

```lua
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("path/to/module.lua")
local MyModule = addon:GetModule("ModuleName")
```

3. If the module depends on other modules via `addon:GetModule()`, stub them first:

```lua
local stubDB = StubBetterBagsModule("Database")
stubDB.SomeMethod = function() return "mock value" end
LoadBetterBagsModule("path/to/module_that_needs_database.lua")
```

4. Write tests using busted's `describe`/`it`/`assert` syntax.

### Available Test Globals

| Global | Purpose |
|--------|---------|
| `LoadBetterBagsModule(path)` | Load a BetterBags module file with correct vararg. Idempotent (safe to call multiple times). |
| `StubBetterBagsModule(name)` | Create or retrieve a stub AceModule on the BetterBags addon. |
| `LibStub` | Ace3 library registry (available after setup.lua runs). |

## Mock Architecture

`spec/setup.lua` is the busted helper (configured in `.busted`) and runs before all spec files. It delegates to:

- **`helpers/wow_mocks.lua`**: Sets WoW global functions and aliases (`_G.CreateFrame`, `_G.C_Timer`, `_G.strmatch`, `_G.wipe`, etc.)
- **`helpers/addon_loader.lua`**: Creates the BetterBags addon via AceAddon and provides `LoadBetterBagsModule()` and `StubBetterBagsModule()` helpers

To add new WoW API mocks, edit `helpers/wow_mocks.lua`. To change addon bootstrapping, edit `helpers/addon_loader.lua`.
