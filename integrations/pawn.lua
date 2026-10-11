local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Pawn: AceModule
local pawn = addon:NewModule('Pawn')

-- Pawn functions that change what its upgrade verdict reads: scales and their values,
-- visibility and options, best items and best item levels, artifacts, and initialization.
-- Pawn calls PawnResetBags (our RefreshAll) after some of these but not all (adding,
-- deleting or duplicating a scale, plugin scales, the item-level part of losing an item),
-- so each is hooked. Every option Pawn's window changes directly is covered by hooking the
-- window's OnHide. Taken from Pawn 2.13.16; a name a Pawn version lacks is skipped.
local PAWN_STATE_FUNCTIONS = {
  "PawnInitialize", "PawnResetTooltips", "PawnClearCache", "PawnClearCacheValuesOnly",
  "PawnInvalidateBestItems", "PawnInvalidateBestItemsForScale", "PawnAddDefaultScale",
  "PawnDeleteScale", "PawnRenameScale", "PawnDuplicateScale", "PawnSetAutoSelectScales",
  "PawnSetScaleVisible", "PawnSetUpgradeTracking", "PawnSetShowUpgradesForWeapons",
  "PawnSetStatValue", "PawnImportScale", "PawnAddPluginScale", "PawnAddPluginScaleFromTemplate",
  "PawnAddPluginScaleProvider", "PawnSetAllScaleProviderScalesVisible", "PawnClearBestItemLevelData",
  "PawnOnItemLost", "PawnOnArtifactUpdated", "PawnAddItemToLevelTracker", "PawnResetScalesCore",
  "PawnAddEmptyScale", "PawnCorrectScaleErrors",
}

-- invalidate drops every kept Pawn verdict and, while Pawn draws the arrows, refreshes the
-- bags so they are asked again.
local function invalidate()
  items:InvalidateUpgrades("Pawn", items:GetActiveUpgradeProvider() == "Pawn")
end

-- Pawn's equip locations whose upgrades it checks against the equipped weapon's handedness
-- (PawnIsItemAnUpgrade).
local WEAPON_EQUIP_LOCS = {
  INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
  INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true,
  INVTYPE_RANGEDRIGHT = true,
}

---@param slot number
---@return boolean
local function pawnHasSlotData(slot)
  local item, slotHadItem = PawnGetItemDataForInventorySlot(slot, true)
  return item ~= nil or not slotHadItem
end

-- pawnHadData reports whether Pawn had the data its verdict for this item needs. Pawn
-- answers false, not "not sure", when it has no data for the item or for an equipped item it
-- compares with ("we can't evaluate upgrades yet"), and sends no signal when the data
-- arrives; such an answer must not be kept. Checked: the item itself (unless it can never
-- have stats; relics while Pawn shows relic upgrades are never kept), the equipped items in
-- its slots, and for weapons both weapon slots and the equipped weapon whose handedness
-- Pawn reads (the main hand's, or the off hand's when the main hand is empty).
---@param data ItemData
---@return boolean
local function pawnHadData(data)
  local link = data.itemInfo.itemLink
  if PawnCanItemHaveStats(link) then
    if PawnGetItemData(link) == nil then
      return false
    end
  elseif PawnCommon and PawnCommon.ShowRelicUpgrades and PawnCanItemBeArtifactUpgrade(link) then
    -- Pawn's relic check answers false while the relic's data is still loading.
    return false
  end
  for _, slot in pairs(data.inventorySlots or {}) do
    if not pawnHasSlotData(slot) then
      return false
    end
  end
  if WEAPON_EQUIP_LOCS[data.itemInfo.itemEquipLoc] then
    if not pawnHasSlotData(INVSLOT_MAINHAND) or not pawnHasSlotData(INVSLOT_OFFHAND) then
      return false
    end
    local weaponLink = GetInventoryItemLink("player", INVSLOT_MAINHAND) or GetInventoryItemLink("player", INVSLOT_OFFHAND)
    if weaponLink and PawnGetItemData(weaponLink) == nil then
      return false
    end
  end
  return true
end

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

  -- Pawn's verdicts are kept on items (.claude/rules/caches.md §2) only when Pawn can tell us
  -- when to drop them, through its third-party bag registration (Pawn's PawnBags.lua) and the
  -- hooks above, and only on Mainline, where Pawn treats its own item data as final (outside
  -- Mainline it re-checks that data on every call). The check is the one that always
  -- answers: Pawn's public check is time-budgeted and answers nil once the budget is spent,
  -- which would leave arrows missing or out of date while waiting. Since a kept verdict is
  -- only asked again when an input changed, this costs no more than every refresh did before
  -- verdicts were kept. Pawn's own nil ("ask again later": item data still loading) is
  -- passed through, and an answer Pawn gave without the data it needs is marked not to keep.
  local keepVerdicts = type(PawnRegisterThirdPartyBag) == "function"
    and VgerCore ~= nil and VgerCore.IsMainline == true
    and type(PawnGetItemData) == "function" and type(PawnCanItemHaveStats) == "function"
    and type(PawnGetItemDataForInventorySlot) == "function"
    and type(PawnCanItemBeArtifactUpgrade) == "function"
  items:RegisterUpgradeProvider("Pawn", function(data)
    if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
      return false
    end
    -- Pawn can never arrow a link that is not an item link (a caged battle pet, a keystone),
    -- and answers nil ("ask again later") for it forever, since GetItemInfo has no item.
    if not string.find(data.itemInfo.itemLink, "|Hitem:", 1, true) then
      return false
    end
    local verdict = PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(data.itemInfo.itemLink, true)
    if verdict == nil then
      return nil
    end
    return verdict, keepVerdicts and pawnHadData(data)
  end, { cacheable = keepVerdicts })
  if type(PawnRegisterThirdPartyBag) == "function" then
    PawnRegisterThirdPartyBag("BetterBags", { RefreshAll = invalidate })
    for _, name in ipairs(PAWN_STATE_FUNCTIONS) do
      if type(_G[name]) == "function" then
        hooksecurefunc(name, invalidate)
      end
    end
    if PawnUIFrame then
      PawnUIFrame:HookScript("OnHide", invalidate)
    end
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
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end
  end)
end
