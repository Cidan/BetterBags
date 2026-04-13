# BetterBags Test Suite

Unit tests for BetterBags, powered by [busted](https://olivinelabs.com/busted/) with Lua 5.1.

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
