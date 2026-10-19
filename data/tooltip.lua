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

-- A tooltip whose data keeps resolving (e.g. dynamic text that updates) would otherwise
-- re-scan and re-harvest forever; after this many resolution-driven re-scans an item's
-- tooltip is left as cached.
local MAX_RESOLVE_RESCANS = 3

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
  -- Resolution-driven re-scans per item GUID, capped at MAX_RESOLVE_RESCANS.
  ---@type table<string, number>
  self.resolveRescans = {}

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
    -- TOOLTIP_DATA_UPDATE fires for every tooltip in the game (units, spells, action
    -- buttons), so the filter drops anything that is not one of our scanned items
    -- before BucketEvent records or schedules anything; matching ids are batched per
    -- window. Retail only; the event does exist on Classic but C_TooltipInfo (and thus
    -- dataInstanceID) does not.
    if not self._tooltipUpdateHooked then
      self._tooltipUpdateHooked = true
      events:BucketEvent('TOOLTIP_DATA_UPDATE', function(_, resolved)
        self:OnTooltipDataResolved(resolved)
      end, function(_, dataInstanceID)
        return dataInstanceID ~= nil and self.instanceToGUID[dataInstanceID] ~= nil
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
    if addon.isRetail and dataInstanceID ~= nil and itemGUID ~= nil and itemGUID ~= ""
      and (self.resolveRescans[itemGUID] or 0) < MAX_RESOLVE_RESCANS then
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

-- joinRetailLines joins a C_TooltipInfo tooltip's left and right texts with spaces, as
-- ExtractRetail does, or nil when it has none.
---@param tooltipData? TooltipData
---@return string?
local function joinRetailLines(tooltipData)
  if not tooltipData or not tooltipData.lines then
    return nil
  end
  local lines = {}
  for _, line in ipairs(tooltipData.lines) do
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
  return table.concat(lines, " ")
end

-- joinScanLines joins the scan tooltip's left and right texts with spaces, as ExtractClassic does,
-- or nil when it has none.
---@param scanTooltip GameTooltip
---@return string?
local function joinScanLines(scanTooltip)
  local lines = {}
  for i = 1, math.min(scanTooltip:NumLines(), 30) do
    for _, side in ipairs({ "Left", "Right" }) do
      local fontString = _G["BetterBagsScanTooltipText" .. side .. i]
      local text = fontString and fontString:GetText()
      if text and text ~= "" then
        table.insert(lines, text)
      end
    end
  end
  if #lines == 0 then
    return nil
  end
  return table.concat(lines, " ")
end

-- GetMerchantItemText returns the tooltip text of the open merchant's item at index, for
-- BetterBags Next's vendor search (next/merchant.lua): C_TooltipInfo.GetMerchantItem on retail,
-- the scan tooltip's SetMerchantItem on Classic. Not cached: merchants change their items.
---@param index number
---@return string?
function tooltipScanner:GetMerchantItemText(index)
  if addon.isRetail then
    if not C_TooltipInfo or not C_TooltipInfo.GetMerchantItem then
      return nil
    end
    return joinRetailLines(C_TooltipInfo.GetMerchantItem(index))
  end
  if not self.scanTooltip then
    return nil
  end
  self.scanTooltip:ClearLines()
  self.scanTooltip:SetMerchantItem(index)
  return joinScanLines(self.scanTooltip)
end

-- GetGuildBankItemText returns the tooltip text of a guild bank item, for search
-- (items:AttachGuildBankItemInfo): C_TooltipInfo.GetGuildBankItem on retail, the scan tooltip's
-- SetGuildBankItem on Classic. A guild bank slot has no item GUID, so the text is cached by the
-- item's link (an item's text is the same wherever it lies), under "guild:" .. link, a key no GUID
-- has; a sparse retail tooltip resolves as a bag item's does (OnTooltipDataResolved).
---@param tab number
---@param slot number
---@param link string
---@return string?
function tooltipScanner:GetGuildBankItemText(tab, slot, link)
  local key = "guild:" .. link
  if self.cache[key] then
    return self.cache[key]
  end
  local text, dataInstanceID
  if addon.isRetail then
    if C_TooltipInfo and C_TooltipInfo.GetGuildBankItem then
      local data = C_TooltipInfo.GetGuildBankItem(tab, slot)
      text = joinRetailLines(data)
      dataInstanceID = data and data.dataInstanceID
    end
  elseif self.scanTooltip then
    self.scanTooltip:ClearLines()
    self.scanTooltip:SetGuildBankItem(tab, slot)
    text = joinScanLines(self.scanTooltip)
  end
  if text and text ~= "" then
    self.cache[key] = text
    if dataInstanceID ~= nil and (self.resolveRescans[key] or 0) < MAX_RESOLVE_RESCANS then
      self:RecordInstance(key, dataInstanceID)
    end
  end
  return text
end

-- GetInventoryRepairCost returns what repairing an equipped item costs: the TooltipData's
-- repairCost on retail (Blizzard's TooltipDataRules.lua reads it), the third return of the scan
-- tooltip's SetInventoryItem on Classic (PaperDollFrame.lua). 0 when nothing says.
---@param slot number
---@return number
function tooltipScanner:GetInventoryRepairCost(slot)
  if addon.isRetail then
    local data = C_TooltipInfo and C_TooltipInfo.GetInventoryItem and C_TooltipInfo.GetInventoryItem("player", slot)
    return data and data.repairCost or 0
  end
  if not self.scanTooltip then
    return 0
  end
  self.scanTooltip:ClearLines()
  local _, _, repairCost = self.scanTooltip:SetInventoryItem("player", slot)
  return repairCost or 0
end

-- GetBagRepairCost returns what repairing an item in a bag costs: the TooltipData's repairCost on
-- retail, the second return of the scan tooltip's SetBagItem on Classic (ContainerFrame_Shared.lua).
---@param bag number
---@param slot number
---@return number
function tooltipScanner:GetBagRepairCost(bag, slot)
  if addon.isRetail then
    local data = C_TooltipInfo and C_TooltipInfo.GetBagItem and C_TooltipInfo.GetBagItem(bag, slot)
    return data and data.repairCost or 0
  end
  if not self.scanTooltip then
    return 0
  end
  self.scanTooltip:ClearLines()
  local _, repairCost = self.scanTooltip:SetBagItem(bag, slot)
  return repairCost or 0
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
--- cache entry so the next sweep re-scans it warm, and request that sweep.
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
        self.resolveRescans[guid] = (self.resolveRescans[guid] or 0) + 1
        invalidated = true
      end
    end
  end
  if not invalidated then return end
  -- Recalculate the bags: the sweep re-scans the invalidated items (a cache miss, now
  -- warm) and re-indexes them, without reading the bags (refresh-scheduler.md §10). The
  -- backpack always; the bank and the guild bank only when they are open.
  local ctx = context:New('TooltipDataResolved')
  events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = addon.atBank == true,
    guild = addon.atGuildBank == true or nil })
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
