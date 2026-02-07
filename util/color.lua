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

---@param colors table<number, table<number, number, number>>
---@param number number
---@return table<number, number, number>
local function interpolateColor(colors, number)
  local lowerBound = nil
  local upperBound = nil
  local lowestValue = nil

  -- Find the appropriate lower and upper bounds
  for key, value in pairs(colors) do
    if not lowestValue or key < lowestValue then
      lowestValue = key
    end
    if number >= key then
      if not lowerBound or key > lowerBound.key then
        lowerBound = {key = key, value = value}
      end
    else
      if not upperBound or key < upperBound.key then
        upperBound = {key = key, value = value}
      end
    end
  end

  if not lowerBound then
    lowerBound = {key = lowestValue, value = colors[lowestValue]}
  end

  -- If no upper bound is found, use the lower bound color
  if not upperBound then
    return lowerBound.value
  end

  -- Interpolate the color
  local t = (number - lowerBound.key) / (upperBound.key - lowerBound.key)
  local r1, g1, b1 = unpack(lowerBound.value) ---@type number, number, number
  local r2, g2, b2 = unpack(upperBound.value) ---@type number, number, number

  local r = r1 + t * (r2 - r1)
  local g = g1 + t * (g2 - g1)
  local b = b1 + t * (b2 - b1)

  return {r, g, b}
end

---@param itemLevel number
---@return number, number, number
function color:GetItemLevelColor(itemLevel)
  -- Get the max item level and user-configured colors from database
  local maxIlvl = math.max(database:GetMaxItemLevel(), MIN_MAX_ILVL)
  local userColors = database:GetItemLevelColors()

  -- Calculate dynamic breakpoints based on max item level
  local midPoint = math.floor(maxIlvl * WEIGHT_MID)
  local highPoint = math.floor(maxIlvl * WEIGHT_HIGH)

  -- Build dynamic color table
  local colorTable = {
    [1] = {userColors.low.red, userColors.low.green, userColors.low.blue},
    [midPoint] = {userColors.mid.red, userColors.mid.green, userColors.mid.blue},
    [highPoint] = {userColors.high.red, userColors.high.green, userColors.high.blue},
    [maxIlvl] = {userColors.max.red, userColors.max.green, userColors.max.blue}
  }

  return unpack(interpolateColor(colorTable, itemLevel))
end
