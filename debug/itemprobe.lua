local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- The ItemProbe records, for one bag slot, what each Blizzard API answered about its item: every
-- value returned, by item ID and by link where the API takes both, whether the client had the
-- item's data, and the tooltip's lines with their types. The Dump tab stores it beside each dumped
-- item, so a dump from the game settles what an API does (data-driven.md) and seeds tests with
-- real answers. Nothing here is read by the bags.
---@class ItemProbe: AceModule
local itemProbe = addon:NewModule('ItemProbe')

local SECRET = "<secret %s>"

---@param value any
---@return any
local function clean(value)
  local canAccess = type(_G.canaccessvalue) == 'function' and _G.canaccessvalue or nil
  if canAccess and not canAccess(value) then
    return format(SECRET, type(value))
  end
  local kind = type(value)
  if kind == "function" or kind == "userdata" or kind == "thread" then
    return nil
  end
  if kind ~= "table" then
    return value
  end
  if value[0] ~= nil and type(value[0]) == "userdata" then
    return nil
  end
  local copy = {}
  for k, v in pairs(value) do
    local ck, cv = clean(k), clean(v)
    if ck ~= nil and cv ~= nil then
      copy[ck] = cv
    end
  end
  return copy
end

-- pack records every value a call returned, n being how many (nil included).
---@return table
local function pack(...)
  local out = { n = select('#', ...) }
  for i = 1, out.n do
    out[i] = clean((select(i, ...)))
  end
  return out
end

---@param ok boolean
---@return table
local function record(ok, ...)
  if not ok then
    return { error = tostring((...)) }
  end
  return pack(...)
end

-- ask calls an API and records what it returned, or the error it raised; nothing for an API the
-- client does not have.
---@param fn? function
---@return table?
local function ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return record(pcall(fn, ...))
end

---@param tbl? table
---@param name string
---@return function?
local function field(tbl, name)
  return tbl and tbl[name]
end

-- Probe records what the client says about the item in a bag slot; nil for an empty slot.
---@param bagid number
---@param slotid number
---@return table?
function itemProbe:Probe(bagid, slotid)
  local itemID = C_Container.GetContainerItemID(bagid, slotid)
  if itemID == nil then
    return nil
  end
  local link = C_Container.GetContainerItemLink(bagid, slotid)
  local location = ItemLocation:CreateFromBagAndSlot(bagid, slotid)
  local item, trade, pets = C_Item, _G.C_TradeSkillUI, _G.C_PetJournal
  local probe = {
    bagid = bagid,
    slotid = slotid,
    itemID = itemID,
    link = link,
    dataCached = ask(item.IsItemDataCached, location),
    dataCachedByID = ask(item.IsItemDataCachedByID, itemID),
    itemInfoByID = ask(item.GetItemInfo, itemID),
    itemInfoByLink = ask(item.GetItemInfo, link),
    itemInfoInstant = ask(item.GetItemInfoInstant, itemID),
    detailedItemLevelByID = ask(item.GetDetailedItemLevelInfo, itemID),
    detailedItemLevelByLink = ask(item.GetDetailedItemLevelInfo, link),
    currentItemLevel = ask(item.GetCurrentItemLevel, location),
    equippable = ask(item.IsEquippableItem, link),
    itemSpell = ask(item.GetItemSpell, link),
    cosmetic = ask(item.IsCosmeticItem, link),
    upgradeInfo = ask(item.GetItemUpgradeInfo, link),
    scrappable = ask(item.CanScrapItem, location),
    stats = ask(item.GetItemStats or _G.GetItemStats, link),
    reagentQuality = ask(field(trade, "GetItemReagentQualityByItemInfo"), link),
    craftedQuality = ask(field(trade, "GetItemCraftedQualityByItemInfo"), link),
    petInfo = ask(field(pets, "GetPetInfoByItemID"), itemID),
    toyInfo = ask(field(_G.C_ToyBox, "GetToyInfo"), itemID),
    hasToy = ask(_G.PlayerHasToy, itemID),
    canUse = ask(field(_G.C_PlayerInfo, "CanUseItem"), itemID),
    watermark = ask(field(_G.C_ItemUpgrade, "GetHighWatermarkForItem"), link),
    transmog = ask(field(_G.C_TransmogCollection, "GetItemInfo"), link),
    bagName = ask(C_Container.GetBagName, bagid),
  }
  local speciesID = probe.petInfo and probe.petInfo[13]
  if type(speciesID) == "number" then
    probe.petCollected = ask(field(pets, "GetNumCollectedInfo"), speciesID)
  end
  local modifiedAppearanceID = probe.transmog and probe.transmog[2]
  if type(modifiedAppearanceID) == "number" then
    probe.transmogCollected = ask(field(_G.C_TransmogCollection, "PlayerHasTransmogItemModifiedAppearance"),
      modifiedAppearanceID)
  end
  local tooltip = ask(field(_G.C_TooltipInfo, "GetBagItem"), bagid, slotid)
  local data = tooltip and tooltip[1]
  if type(data) == "table" and type(data.lines) == "table" then
    probe.tooltip = {}
    for _, line in ipairs(data.lines) do
      table.insert(probe.tooltip, { type = line.type, left = line.leftText, right = line.rightText })
    end
  elseif tooltip then
    probe.tooltip = tooltip
  end
  return probe
end

-- Client describes the client the probes are taken on.
---@return table
function itemProbe:Client()
  local version, build, date, interface = GetBuildInfo()
  return {
    version = version,
    build = build,
    date = date,
    interface = interface,
    locale = GetLocale(),
    retail = addon.isRetail,
    forever = addon.isForever,
    time = time(),
  }
end
