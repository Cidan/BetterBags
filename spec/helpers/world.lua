-- world.lua -- The world a spec file runs in: the WoW mocks, the Ace3 libraries, the BetterBags addon with the modules
-- every spec needs, and the shared mock data. Returns the function that builds it, on the globals Lua and busted start
-- with; spec/setup.lua builds a new one for every spec file (.claude/rules/test-harness.md §6).

return function()
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

  -- The profiler engine loads right after core/boot.lua in every TOC, and files across the
  -- addon register their prototypes with it at load time, so every spec needs it present.
  LoadBetterBagsModule("debug/perf/engine.lua")
  -- The pixel check (debug/pixelaudit.lua): spec/helpers/layout.lua runs it, and BetterBags Next's windows
  -- register with it as they are made.
  LoadBetterBagsModule("debug/pixelaudit.lua")
  -- Flow is the pure packing every grid lays out with (render/flow.lua); the grid looks it up when
  -- it loads, so every spec that loads a grid needs it present.
  LoadBetterBagsModule("render/flow.lua")
  -- Motion positions the cells and sections of every grid (render/motion.lua); grids and sections
  -- look it up when they load.
  LoadBetterBagsModule("render/motion.lua")
  -- Texels draws the bags' textures without the client's sharpening (render/texels.lua); item buttons and windows
  -- look it up when they load.
  LoadBetterBagsModule("render/texels.lua")
  -- BetterBags Next's pixel grid (next/pixel.lua, docs/next-pixel-perfect.md): every Next file that places
  -- anything looks it up when it loads.
  LoadBetterBagsModule("next/pixel.lua")
  LoadBetterBagsModule("next/itemfit.lua")
  LoadBetterBagsModule("next/coins.lua")
  -- Sonata resolves its themes and BetterBags Next's with SonataResolve (sonata/resolve.lua), which
  -- the engine looks up when it loads.
  LoadBetterBagsModule("sonata/resolve.lua")
  -- BetterBags Next's theme engine and its themes (sonata/next.lua, sonata/themes/next): next/style.lua
  -- reads the Default theme when it loads.
  FreshNextThemes()

  -- Step 4: Load shared mock data factories
  dofile("spec/helpers/mock_data.lua")
end
