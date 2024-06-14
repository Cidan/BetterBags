local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class WindowGroup: AceModule
local windowGroup = addon:NewModule('WindowGroup')

---@class WindowGrouping
---@field windows any[]
local windowGrouping = {}

---@param name string
---@param frame any
function windowGrouping:AddWindow(name, frame)
  assert(frame.fadeIn and frame.fadeOut, 'Frame must have fadeIn and fadeOut animations.')
  self.windows[name] = frame
end

function windowGrouping:Show(name)
  if self.windows[name]:IsShown() then
    self.windows[name]:Hide()
    return
  end
  local started = false
  for frameName, frame in pairs(self.windows) do
    if frameName ~= name then
      if frame:IsShown() then
        if started then
          frame:Hide()
        else
          started = true
          frame:Hide(function()
            self.windows[name]:Show()
          end)
        end
      end
    end
  end
  if not started then
    self.windows[name]:Show()
  end
end

---@return WindowGrouping
function windowGroup:Create()
  local group = setmetatable({}, { __index = windowGrouping })
  group.windows = {}
  return group
end