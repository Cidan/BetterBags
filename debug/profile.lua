local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

function debug:StartProfile(name)
  assert(name ~= nil, "name must not be nil")
  assert(type(name) == "string", "name must be a string")
  assert(self.profiles[name] == nil, "profile already exists")
  self.profiles[name] = debugprofilestop()
end

function debug:EndProfile(name)
  assert(name ~= nil, "name must not be nil")
  assert(type(name) == "string", "name must be a string")
  assert(self.profiles[name] ~= nil, "profile does not exist")
  local start = self.profiles[name]
  local stop = debugprofilestop()
  print(name, "took", stop - start, "ms")
  self.profiles[name] = nil
end
