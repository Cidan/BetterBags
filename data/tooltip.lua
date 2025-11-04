local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class TooltipScanner: AceModule
local tooltipScanner = addon:NewModule('TooltipScanner')

---@class (exact) Debug: AceModule
local debug = addon:GetModule('Debug')

function tooltipScanner:OnInitialize()
  -- Cache to store extracted tooltip text, keyed by item GUID
  -- This prevents repeated expensive tooltip extractions
  ---@type table<string, string>
  self.cache = {}

  -- For Classic/Era: Create a hidden GameTooltip for scanning
  -- Retail uses C_TooltipInfo API and doesn't need this
  if not addon.isRetail then
    self.scanTooltip = CreateFrame("GameTooltip", "BetterBagsScanTooltip", nil, "GameTooltipTemplate")
    self.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    debug:Log("TooltipScanner", "Created GameTooltip scanner for Classic/Era")
  else
    self.scanTooltip = nil
    debug:Log("TooltipScanner", "Using C_TooltipInfo API for Retail")
  end
end

--- Extract tooltip text for a bag item
--- @param bagid number The bag ID
--- @param slotid number The slot ID within the bag
--- @param itemGUID string The item's GUID for caching
--- @return string? The concatenated tooltip text, or nil if extraction failed
function tooltipScanner:GetTooltipText(bagid, slotid, itemGUID)
  -- Check cache first to avoid repeated extraction
  if self.cache[itemGUID] then
    return self.cache[itemGUID]
  end

  local text
  if addon.isRetail then
    text = self:ExtractRetail(bagid, slotid)
  else
    text = self:ExtractClassic(bagid, slotid)
  end

  -- Cache the result if extraction succeeded
  if text and text ~= "" then
    self.cache[itemGUID] = text
    debug:Log("TooltipScanner", "Cached tooltip for GUID %s: %s", itemGUID, string.sub(text, 1, 50) .. "...")
  end

  return text
end

--- Extract tooltip text using Retail's C_TooltipInfo API
--- @private
--- @param bagid number
--- @param slotid number
--- @return string?
function tooltipScanner:ExtractRetail(bagid, slotid)
  -- C_TooltipInfo.GetBagItem is only available in Retail (Patch 10.0.2+)
  -- Returns structured TooltipData with lines array
  if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
    debug:Log("TooltipScanner", "C_TooltipInfo.GetBagItem not available")
    return nil
  end

  local tooltipData = C_TooltipInfo.GetBagItem(bagid, slotid)
  if not tooltipData or not tooltipData.lines then
    debug:Log("TooltipScanner", "No tooltip data for bag %d slot %d", bagid, slotid)
    return nil
  end

  local lines = {}
  for _, line in ipairs(tooltipData.lines) do
    -- Extract both left and right text from each line
    if line.leftText and line.leftText ~= "" then
      table.insert(lines, line.leftText)
    end
    if line.rightText and line.rightText ~= "" then
      table.insert(lines, line.rightText)
    end
  end

  if #lines == 0 then
    return nil
  end

  -- Concatenate all lines with spaces for search indexing
  return table.concat(lines, " ")
end

--- Extract tooltip text using Classic/Era's GameTooltip scanning
--- @private
--- @param bagid number
--- @param slotid number
--- @return string?
function tooltipScanner:ExtractClassic(bagid, slotid)
  if not self.scanTooltip then
    debug:Log("TooltipScanner", "Scan tooltip not initialized")
    return nil
  end

  -- Clear any previous tooltip data
  self.scanTooltip:ClearLines()

  -- Populate the tooltip with the bag item
  -- This triggers WoW's internal tooltip generation
  self.scanTooltip:SetBagItem(bagid, slotid)

  local numLines = self.scanTooltip:NumLines()
  if numLines == 0 then
    debug:Log("TooltipScanner", "No tooltip lines for bag %d slot %d", bagid, slotid)
    return nil
  end

  local lines = {}
  -- Cap at 30 lines to avoid the Classic bug where lines 9+ have incorrect FontString names
  -- In practice, most item tooltips are well under 30 lines
  for i = 1, math.min(numLines, 30) do
    local leftText = _G["BetterBagsScanTooltipTextLeft"..i]
    local rightText = _G["BetterBagsScanTooltipTextRight"..i]

    -- Extract text from left-aligned FontString
    if leftText then
      local text = leftText:GetText()
      if text and text ~= "" then
        table.insert(lines, text)
      end
    end

    -- Extract text from right-aligned FontString (e.g., stat values)
    if rightText then
      local text = rightText:GetText()
      if text and text ~= "" then
        table.insert(lines, text)
      end
    end
  end

  if #lines == 0 then
    return nil
  end

  -- Concatenate all lines with spaces for search indexing
  return table.concat(lines, " ")
end

--- Clear the entire tooltip cache
--- Called when items are wiped or addon is reset
function tooltipScanner:ClearCache()
  wipe(self.cache)
  debug:Log("TooltipScanner", "Tooltip cache cleared")
end

--- Remove a specific item from the cache
--- @param itemGUID string The item GUID to remove
function tooltipScanner:RemoveFromCache(itemGUID)
  if self.cache[itemGUID] then
    self.cache[itemGUID] = nil
    debug:Log("TooltipScanner", "Removed GUID %s from tooltip cache", itemGUID)
  end
end

--- Get the current cache size (for debugging/monitoring)
--- @return number The number of cached tooltips
function tooltipScanner:GetCacheSize()
  local count = 0
  for _ in pairs(self.cache) do
    count = count + 1
  end
  return count
end
