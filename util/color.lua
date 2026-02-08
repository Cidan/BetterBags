local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Color: AceModule
local color = addon:NewModule('Color')

---@class Database: AceModule
local database = addon:GetModule('Database')

-- Weight multipliers for dynamic breakpoints
-- Matches current distribution: 1→300(61%), 300→420(86%), 420→489(100%)
local WEIGHT_MID = 0.61      -- 61% of max for mid breakpoint
local WEIGHT_HIGH = 0.86     -- 86% of max for high breakpoint
local MIN_MAX_ILVL = 100     -- Minimum max to prevent edge cases

---@param itemLevel number
---@return number, number, number
function color:GetItemLevelColor(itemLevel)
  -- Get the max item level and user-configured colors from database
  local maxIlvl = math.max(database:GetMaxItemLevel(), MIN_MAX_ILVL)
  local userColors = database:GetItemLevelColors()

  -- Calculate dynamic breakpoints based on max item level
  local midPoint = math.floor(maxIlvl * WEIGHT_MID)
  local highPoint = math.floor(maxIlvl * WEIGHT_HIGH)

  if itemLevel >= maxIlvl then
    return userColors.max.red, userColors.max.green, userColors.max.blue
  end
  if itemLevel >= highPoint then
    return userColors.high.red, userColors.high.green, userColors.high.blue
  end
  if itemLevel >= midPoint then
    return userColors.mid.red, userColors.mid.green, userColors.mid.blue
  end

  return userColors.low.red, userColors.low.green, userColors.low.blue
end
