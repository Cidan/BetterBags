local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

-- Register attempts to register the Pawn upgrade provider. It returns true once
-- registration has happened (or already happened). It returns false when Pawn's
-- globals are not yet available, so OnEnable can retry after Pawn finishes
-- loading (Pawn may load after BetterBags enables its modules).
---@return boolean
function pawn:Register()
  if self._registered then
    return true
  end
  if not PawnIsContainerItemAnUpgrade and not PawnGetItemData then
    return false
  end

  items:RegisterUpgradeProvider("Pawn", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink, true)
    return isUpgrade or false
  end)

  self._registered = true
  print("BetterBags: Pawn integration enabled.")
  return true
end

function pawn:OnEnable()
  if self:Register() then
    return
  end
  -- Pawn is not loaded yet; retry as addons finish loading so the provider
  -- still appears once Pawn is present (load-order resilience). When it finally
  -- registers, request a refresh so already-drawn arrows re-resolve against it.
  events:RegisterEvent("ADDON_LOADED", function(ctx)
    if pawn._registered then return end
    if pawn:Register() then
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end
  end)
end
