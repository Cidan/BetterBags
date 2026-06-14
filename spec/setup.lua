-- Step 0: Enforce Lua 5.1. The BetterBags suite targets WoW's Lua 5.1 runtime;
-- running on any other interpreter (5.2, 5.3, 5.4, luajit-5.2-mode, etc.) is
-- unsupported and will silently produce false confidence. This guard runs
-- before any library load or test code so the failure is immediate and loud.
if _VERSION ~= "Lua 5.1" then
  error(string.format(
    "BetterBags test suite requires Lua 5.1 (WoW's runtime). Detected %s. "
    .. "Install Lua 5.1 and `luarocks install busted` against it; "
    .. "see spec/README.md and CLAUDE.md (\"Lua Version\").",
    _VERSION
  ), 0)
end

-- setup.lua -- Busted test helper. Loaded before all spec files via .busted config.
-- Delegates to modular helpers in spec/helpers/ for maintainability.

-- Step 1: Mock WoW globals (must come before any library loading)
dofile("spec/helpers/wow_mocks.lua")

-- Step 2: Load Ace3 libraries (order matters -- dependencies first)
dofile("libs/LibStub/LibStub.lua")
dofile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("libs/AceAddon-3.0/AceAddon-3.0.lua")
dofile("libs/AceEvent-3.0/AceEvent-3.0.lua")
dofile("libs/AceDB-3.0/AceDB-3.0.lua")
dofile("libs/AceHook-3.0/AceHook-3.0.lua")
dofile("libs/AceConsole-3.0/AceConsole-3.0.lua")
dofile("libs/AceDBOptions-3.0/AceDBOptions-3.0.lua")
dofile("libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
dofile("libs/AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua")
dofile("libs/AceConfig-3.0/AceConfig-3.0.lua")

-- Step 3: Create the BetterBags addon and provide module loading helpers
dofile("spec/helpers/addon_loader.lua")

-- Step 4: Load shared mock data factories
dofile("spec/helpers/mock_data.lua")
