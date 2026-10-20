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
  -- PawnGetItemData is a stable, long-lived Pawn global; its presence means the
  -- Pawn addon has loaded and defined its API. (We deliberately do not check
  -- PawnIsContainerItemAnUpgrade, which no longer exists in current Pawn.)
  if not PawnGetItemData then
    return false
  end

  -- Pawn's answer is passed on as it is: true, false, or nil for "we're not sure yet", which
  -- ResolveUpgrade does not keep. The answers are kept on each item (cacheable) until Pawn says bag
  -- arrows may have changed: PawnResetBags, which Pawn calls when scales, its settings or the spec
  -- change, and after inventory changes (Pawn 2.13 Pawn.lua). It starts a new upgrade generation
  -- without a refresh, as before the next refresh asked Pawn again (caches.md §2).
  items:RegisterUpgradeProvider("Pawn", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    return PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink, true)
  end, { cacheable = true })
  if not self._hooked and type(PawnResetBags) == "function" then
    hooksecurefunc("PawnResetBags", function()
      items:InvalidateUpgrades(false)
    end)
    self._hooked = true
  end

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
      events:SendMessage(ctx, 'bags/Rederive', { categoriesUnchanged = true })
    end
  end)
end
