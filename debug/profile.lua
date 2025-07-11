

---@type BetterBags
local addon = GetBetterBags()

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

function debug:StartProfile(name, ...)
  if not self.enabled then return end
  assert(name ~= nil, "name must not be nil")
  assert(type(name) == "string", "name must be a string")
  local resolvedName = format(name, ...)
  assert(self.profiles[resolvedName] == nil, "profile already exists")
  self.profiles[resolvedName] = debugprofilestop()
end

function debug:EndProfile(name, ...)
  if not self.enabled then return end
  assert(name ~= nil, "name must not be nil")
  assert(type(name) == "string", "name must be a string")
  local resolvedName = format(name, ...)
  assert(self.profiles[resolvedName] ~= nil, "profile " .. tostring(resolvedName) .. " does not exist")
  local start = self.profiles[resolvedName]
  local stop = debugprofilestop()
  self:Log("Profile", resolvedName, "took", stop - start, "ms")
  self.profiles[resolvedName] = nil
end
