local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Color: AceModule
local color = addon:NewModule('Color')

---@type table<number, table<number, number, number>>
local colorTable = {
  [1] = {0.62, 0.62, 0.62},
  [300] = {0, 0.55, 0.87},
  [420] = {1, 1, 1},
  [489] = {1, 0.5, 0}
}

-- Color criteria based on the item level relative to the player's average item level
local colorCriteria = {
  orange = {1, 0.5, 0},      -- Above or equal to average item level
  purple = {0.63, 0.21, 0.93}, -- 5 or less lower than average item level
  blue = {0, 0.55, 0.87},    -- 6-10 lower than average item level
  green = {0, 1, 0},         -- 10-20 lower than average item level
  gray = {0.5, 0.5, 0.5}     -- More than 20 lower than average item level
}

-- Function to determine the average item level of the player using the WoW API
local function getAverageItemLevel()
  local averageItemLevel, equippedItemLevel = GetAverageItemLevel()
  return averageItemLevel -- Returns the average item level of all equipped items
end

-- Function to determine color based on the item level relative to average item level
---@param itemLevel number
---@return table<number, number, number>
function color:GetItemLevelRelativeColor(itemLevel)
  local averageItemLevel = getAverageItemLevel()
  local difference = itemLevel - averageItemLevel
  
  if difference >= 0 then
    return colorCriteria.orange
  elseif difference >= -10 then
    return colorCriteria.purple
  elseif difference >= -15 then
    return colorCriteria.blue
  elseif difference >= -20 then
    return colorCriteria.green
  else
    return colorCriteria.gray
  end
end

-- Function to use the determined color for an item level
---@param itemLevel number
---@return number, number, number
function color:GetItemLevelDynamicColor(itemLevel)
  return unpack(color:GetItemLevelRelativeColor(itemLevel))
end

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
      lowerBound = colorTable[lowestValue]
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
  return unpack(interpolateColor(colorTable, itemLevel))
end