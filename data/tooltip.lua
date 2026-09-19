local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class TooltipScanner: AceModule
local tooltipScanner = addon:NewModule('TooltipScanner')

---@class (exact) Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

function tooltipScanner:Init()
  -- Cache to store extracted tooltip text, keyed by item GUID
  -- This prevents repeated expensive tooltip extractions
  ---@type table<string, string>
  self.cache = {}

  -- Retail sparse-tooltip resolution bookkeeping. C_TooltipInfo tooltips can be
  -- returned "sparse" (e.g. an item's "Use:" spell line still cold on login) and
  -- resolve later via TOOLTIP_DATA_UPDATE. We map the tooltip's dataInstanceID to
  -- the item GUID we cached under, so that when it resolves we can invalidate the
  -- stale cache entry and re-scan. Kept strictly 1:1 with `cache`.
  ---@type table<number, string>
  self.instanceToGUID = {}
  ---@type table<string, number>
  self.guidToInstance = {}

  -- For Classic/Era: Create a hidden GameTooltip for scanning
  -- Retail uses C_TooltipInfo API and doesn't need this
  if not addon.isRetail then
    self.scanTooltip = CreateFrame("GameTooltip", "BetterBagsScanTooltip", nil, "GameTooltipTemplate")
    self.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    debug:Log("TooltipScanner", "Created GameTooltip scanner for Classic/Era")
  else
    self.scanTooltip = nil
    debug:Log("TooltipScanner", "Using C_TooltipInfo API for Retail")
    -- Register the sparse-tooltip resolution listener exactly once (guarded so
    -- repeated Init calls -- e.g. in tests -- never leak duplicate handlers).
    -- BucketEvent debounces the burst of updates that fires as data warms up and
    -- hands us every resolved dataInstanceID at once. Retail only; the event does
    -- exist on Classic but C_TooltipInfo (and thus dataInstanceID) does not.
    if not self._tooltipUpdateHooked then
      self._tooltipUpdateHooked = true
      events:BucketEvent('TOOLTIP_DATA_UPDATE', function(_, resolved)
        self:OnTooltipDataResolved(resolved)
      end)
    end
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

  local text, dataInstanceID
  if addon.isRetail then
    text, dataInstanceID = self:ExtractRetail(bagid, slotid)
  else
    text = self:ExtractClassic(bagid, slotid)
  end

  -- Cache the result if extraction succeeded
  if text and text ~= "" then
    self.cache[itemGUID] = text
    -- Record the retail sparse-tooltip instance so a later TOOLTIP_DATA_UPDATE can
    -- invalidate this exact entry if it was scanned while still partial.
    if addon.isRetail and dataInstanceID ~= nil and itemGUID ~= nil and itemGUID ~= "" then
      self:RecordInstance(itemGUID, dataInstanceID)
    end
    debug:Log("TooltipScanner", "Cached tooltip for GUID %s: %s", itemGUID, string.sub(text, 1, 50) .. "...")
  end

  return text
end

--- Extract tooltip text using Retail's C_TooltipInfo API
--- @private
--- @param bagid number
--- @param slotid number
--- @return string? text The concatenated tooltip text, or nil.
--- @return number? dataInstanceID The tooltip's sparse-data instance id (for TOOLTIP_DATA_UPDATE), or nil.
function tooltipScanner:ExtractRetail(bagid, slotid)
  -- C_TooltipInfo.GetBagItem is only available in Retail (Patch 10.0.2+)
  -- Returns structured TooltipData with lines array
  if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
    debug:Log("TooltipScanner", "C_TooltipInfo.GetBagItem not available")
    return nil
  end

  local itemLink = C_Container.GetContainerItemLink(bagid, slotid)
  if itemLink and (string.find(itemLink, "battlepet:") or string.find(itemLink, "Hbattlepet:")) then
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

  -- Concatenate all lines with spaces for search indexing. Also surface the
  -- dataInstanceID so a later TOOLTIP_DATA_UPDATE for this instance can be
  -- correlated back to the item (see OnTooltipDataResolved).
  return table.concat(lines, " "), tooltipData.dataInstanceID
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
  if self.instanceToGUID then wipe(self.instanceToGUID) end
  if self.guidToInstance then wipe(self.guidToInstance) end
  debug:Log("TooltipScanner", "Tooltip cache cleared")
end

--- Remove a specific item from the cache (and its sparse-tooltip instance mapping).
--- @param itemGUID string The item GUID to remove
function tooltipScanner:RemoveFromCache(itemGUID)
  if self.cache[itemGUID] then
    self.cache[itemGUID] = nil
    debug:Log("TooltipScanner", "Removed GUID %s from tooltip cache", itemGUID)
  end
  -- Keep the instance maps 1:1 with the cache so they can never leak an entry
  -- for a GUID whose text is gone.
  local did = self.guidToInstance and self.guidToInstance[itemGUID]
  if did ~= nil then
    self.instanceToGUID[did] = nil
    self.guidToInstance[itemGUID] = nil
  end
end

--- Record the retail sparse-tooltip dataInstanceID that a GUID was cached under.
--- Replaces any prior instance id for the GUID so the two maps stay 1:1 with the
--- cache (no orphaned reverse entries when an item is re-scanned).
--- @param itemGUID string
--- @param dataInstanceID number
function tooltipScanner:RecordInstance(itemGUID, dataInstanceID)
  local prev = self.guidToInstance[itemGUID]
  if prev ~= nil and prev ~= dataInstanceID then
    self.instanceToGUID[prev] = nil
  end
  self.instanceToGUID[dataInstanceID] = itemGUID
  self.guidToInstance[itemGUID] = dataInstanceID
end

--- Handle a debounced batch of TOOLTIP_DATA_UPDATE fires (retail only). Each
--- resolved dataInstanceID that maps to one of our cached items means that item's
--- tooltip was scanned while still sparse and has now resolved: drop the stale
--- cache entry so the next harvest re-scans it warm, and request a re-index.
--- @param resolved EventArg[] Coalesced fires; each entry's args[1] is a dataInstanceID.
function tooltipScanner:OnTooltipDataResolved(resolved)
  if not addon.isRetail then return end
  local invalidated = false
  for _, entry in ipairs(resolved or {}) do
    local dataInstanceID = entry.args and entry.args[1]
    if dataInstanceID ~= nil then
      local guid = self.instanceToGUID[dataInstanceID]
      if guid ~= nil then
        self:RemoveFromCache(guid)
        invalidated = true
      end
    end
  end
  if not invalidated then return end
  -- Re-harvest so the invalidated item(s) re-scan (now warm) and the search index
  -- rebuilds. Backpack is always re-swept; the bank only when it's actually open,
  -- so we never clobber the last-seen bank contents while away from it.
  local ctx = context:New('TooltipDataResolved')
  events:SendMessage(ctx, 'bags/RefreshBackpack')
  if addon.atBank then
    events:SendMessage(ctx, 'bags/RefreshBank')
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
