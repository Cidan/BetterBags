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
