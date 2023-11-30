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

---@param colors table<number, table<number, number, number>>
---@param number number
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

---@return number, number, number
function color:GetItemLevelColor(itemLevel)
  return unpack(interpolateColor(colorTable, itemLevel))
end