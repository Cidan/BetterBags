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
-- Builds the world each spec file runs in (spec/helpers/world.lua): a new one for every file, let go when the file
-- ends, so a file runs as it would alone and the suite holds one file's memory at a time
-- (.claude/rules/test-harness.md §6).

-- Lua starts a collection once memory doubles what the last one left (a pause of 200); at 120 the garbage between
-- collections stays a fifth of what is live.
collectgarbage("setpause", 120)

local buildWorld = dofile("spec/helpers/world.lua")

local pristine = {}
for key, value in pairs(_G) do
  pristine[key] = value
end

-- One world for busted -l, which runs the spec files without their file events.
buildWorld()

local busted = require("busted")

-- Every world is built on the globals Lua and busted start with: the libraries keep a copy they find (LibStub), and the
-- mocks wrap the xpcall they find.
busted.subscribe({ "file", "start" }, function()
  for key, value in pairs(_G) do
    if pristine[key] ~= value then
      rawset(_G, key, pristine[key])
    end
  end
  for key, value in pairs(pristine) do
    if rawget(_G, key) == nil then
      rawset(_G, key, value)
    end
  end
  buildWorld()
  return nil, true
end)

-- busted keeps every describe, it and hook for the whole run, and their functions hold their file's locals, and through
-- them its world. A finished file's let go of theirs; the file's own function, which --repeat runs again, holds none.
local function release(element)
  for _, child in ipairs(busted.children(element)) do
    release(child)
  end
  element.run = nil
  element.env = nil
end
busted.subscribe({ "file", "end" }, function(file)
  for _, child in ipairs(busted.children(file)) do
    release(child)
  end
  file.env = nil
  return nil, true
end)
