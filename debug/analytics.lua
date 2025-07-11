


local addon = GetBetterBags()

---@class WagoAnalytics
local WagoAnalytics = LibStub("WagoAnalytics"):Register("aNDmy96o")

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@param label string
---@param enabled boolean
function debug:Switch(label, enabled)
  WagoAnalytics:Switch(label, enabled)
end

---@param counter string
---@param amount number
function debug:IncrementCounter(counter, amount)
  WagoAnalytics:IncrementCounter(counter, amount)
end

---@param counter string
---@param amount number
function debug:DecrementCounter(counter, amount)
  WagoAnalytics:DecrementCounter(counter, amount)
end

---@param counter string
---@param amount number
function debug:SetCounter(counter, amount)
  WagoAnalytics:SetCounter(counter, amount)
end
