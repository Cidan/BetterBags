local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class SimpleItemLevel: AceModule
local simpleItemLevel = addon:NewModule('SimpleItemLevel')

-- Register attempts to register the SimpleItemLevel upgrade provider. Returns
-- true once registered (or already registered); false when the SimpleItemLevel
-- addon is not yet loaded, so OnEnable can retry on ADDON_LOADED.
---@return boolean
function simpleItemLevel:Register()
  if self._registered then
    return true
  end
  if not SimpleItemLevel then
    return false
  end

  items:RegisterUpgradeProvider("SimpleItemLevel", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    local isUpgrade = SimpleItemLevel.API.ItemIsUpgrade(data.itemInfo.itemLink)
    return isUpgrade or false
  end)

  self._registered = true
  print("BetterBags: SimpleItemLevel integration enabled.")
  return true
end

function simpleItemLevel:OnEnable()
  if self:Register() then
    return
  end
  -- SimpleItemLevel may load after us; retry as addons finish loading. When it
  -- finally registers, request a refresh so drawn arrows re-resolve against it.
  events:RegisterEvent("ADDON_LOADED", function(ctx)
    if simpleItemLevel._registered then return end
    if simpleItemLevel:Register() then
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end
  end)
end
