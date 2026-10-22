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

-- probeItem records what the client says about an item, wherever it is (location).
---@param itemID number
---@param link? string
---@param location ItemLocationMixin
---@return table
local function probeItem(itemID, link, location)
  local item, trade, pets = C_Item, _G.C_TradeSkillUI, _G.C_PetJournal
  local transmog = _G.C_TransmogCollection
  local probe = {
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
    transmog = ask(field(transmog, "GetItemInfo"), link),
  }
  local speciesID = probe.petInfo and probe.petInfo[13]
  if type(speciesID) == "number" then
    probe.petCollected = ask(field(pets, "GetNumCollectedInfo"), speciesID)
  end
  -- Whether the appearance is collected, every way Vendor asks (itemproperties.lua).
  local appearanceID = probe.transmog and probe.transmog[1]
  local modifiedAppearanceID = probe.transmog and probe.transmog[2]
  if type(modifiedAppearanceID) == "number" then
    probe.transmogCollected = ask(field(transmog, "PlayerHasTransmogItemModifiedAppearance"), modifiedAppearanceID)
    probe.transmogSource = ask(field(transmog, "GetSourceInfo"), modifiedAppearanceID)
    probe.transmogCanCollect = ask(field(transmog, "PlayerCanCollectSource"), modifiedAppearanceID)
  end
  if type(appearanceID) == "number" then
    probe.transmogAppearanceSources = ask(field(transmog, "GetAppearanceSources"), appearanceID)
    probe.transmogByItemInfo = ask(field(transmog, "PlayerHasTransmogByItemInfo"), link)
  end
  return probe
end

-- tooltipLines records a tooltip's lines with their types.
---@param tooltip? table What ask returned for a C_TooltipInfo call.
---@return table?
local function tooltipLines(tooltip)
  local data = tooltip and tooltip[1]
  if type(data) == "table" and type(data.lines) == "table" then
    local lines = {}
    for _, line in ipairs(data.lines) do
      table.insert(lines, { type = line.type, left = line.leftText, right = line.rightText })
    end
    return lines
  end
  return tooltip
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
  local probe = probeItem(itemID, link, ItemLocation:CreateFromBagAndSlot(bagid, slotid))
  probe.bagid = bagid
  probe.slotid = slotid
  probe.bagName = ask(C_Container.GetBagName, bagid)
  probe.tooltip = tooltipLines(ask(field(_G.C_TooltipInfo, "GetBagItem"), bagid, slotid))
  return probe
end

-- ProbeEquipped records what the client says about the item worn in an equipment slot; nil for an
-- empty slot. Worn gear has the upgrade tracks and watermarks a bag rarely does.
---@param slot number
---@return table?
function itemProbe:ProbeEquipped(slot)
  local itemID = GetInventoryItemID("player", slot)
  if itemID == nil then
    return nil
  end
  local link = GetInventoryItemLink("player", slot)
  local probe = probeItem(itemID, link, ItemLocation:CreateFromEquipmentSlot(slot))
  probe.equipmentSlot = slot
  probe.tooltip = tooltipLines(ask(field(_G.C_TooltipInfo, "GetInventoryItem"), "player", slot))
  return probe
end

-- ProbeEquipment probes every equipment slot, by slot.
---@return table<number, table>
function itemProbe:ProbeEquipment()
  local out = {}
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    out[slot] = self:ProbeEquipped(slot)
  end
  return out
end

-- characterValues records the player values Vendor's rules read (docs/vendor-compat.md, "Player
-- values"), raw; with who the player is when withName.
---@param withName boolean
---@return table
local function characterValues(withName)
  local spec = _G.C_SpecializationInfo
  local values = {
    level = ask(_G.UnitLevel, "player"),
    effectiveLevel = ask(_G.UnitEffectiveLevel, "player"),
    averageItemLevel = ask(_G.GetAverageItemLevel),
    minItemLevel = ask(field(_G.C_PaperDollInfo, "GetMinItemLevel")),
    class = ask(_G.UnitClass, "player"),
    specialization = ask(field(spec, "GetSpecialization")),
    professions = ask(_G.GetProfessions),
    canDualWield = ask(_G.CanDualWield),
  }
  if withName then
    values.fullName = ask(_G.UnitFullName, "player")
  end
  local specIndex = values.specialization and values.specialization[1]
  if type(specIndex) == "number" and specIndex > 0 then
    values.specializationInfo = ask(field(spec, "GetSpecializationInfo"), specIndex)
  end
  local professions = values.professions
  if professions and professions.n then
    values.professionInfo = {}
    for i = 1, professions.n do
      local index = professions[i]
      if type(index) == "number" then
        values.professionInfo[index] = ask(_G.GetProfessionInfo, index)
      end
    end
  end
  return values
end

-- Player records the player values, raw, and who the player is.
---@return table
function itemProbe:Player()
  return characterValues(true)
end

-- BagNames records, for every container the client knows (Enum.BagIndex), its name and size. The
-- bank's containers answer only while the bank is open.
---@return table<number, table>
function itemProbe:BagNames()
  local out = {}
  for name, bag in pairs(Enum.BagIndex) do
    out[bag] = {
      name = name,
      bagName = ask(C_Container.GetBagName, bag),
      slots = ask(C_Container.GetContainerNumSlots, bag),
      free = ask(C_Container.GetContainerNumFreeSlots, bag),
    }
  end
  return out
end

-- Sample records what follows the character and the account rather than the items, for the
-- items in the backpack, read straight from the client: whether the character can use each item,
-- whether each appearance is collected, each pet's counts, and the player values. A diagnostics
-- capture (debug/perf/sessions.lua) samples it while it runs, to show when each is known at login
-- against the bag reads. Values are kept only when the call answered.
---@return table
function itemProbe:Sample()
  ---@class Constants: AceModule
  local const = addon:GetModule('Constants')
  local transmog, pets, info = _G.C_TransmogCollection, _G.C_PetJournal, _G.C_PlayerInfo
  local sample = { player = characterValues(false), usable = {}, appearances = {}, pets = {} }
  for bag in pairs(const.BACKPACK_BAGS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local itemID = C_Container.GetContainerItemID(bag, slot)
      if itemID ~= nil and sample.usable[itemID] == nil then
        local usable = ask(field(info, "CanUseItem"), itemID)
        sample.usable[itemID] = usable and usable[1]
        local link = C_Container.GetContainerItemLink(bag, slot)
        local appearance = ask(field(transmog, "GetItemInfo"), link)
        local source = appearance and appearance[2]
        if type(source) == "number" then
          local has = ask(field(transmog, "PlayerHasTransmogItemModifiedAppearance"), source)
          sample.appearances[source] = has and has[1]
        end
        local pet = ask(field(pets, "GetPetInfoByItemID"), itemID)
        local species = pet and pet[13]
        if type(species) == "number" then
          local counts = ask(field(pets, "GetNumCollectedInfo"), species)
          sample.pets[species] = counts and { counts[1], counts[2] }
        end
      end
    end
  end
  return sample
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
