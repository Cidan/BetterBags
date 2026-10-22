-- itemprobe_spec.lua -- Unit tests for debug/itemprobe.lua (ItemProbe): what each Blizzard API
-- answered about an item, recorded raw for the Dump tab (data-driven.md).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("ItemProbe", "debug/itemprobe.lua")
LoadBetterBagsModule("debug/itemprobe.lua")
local itemProbe = addon:GetModule("ItemProbe")
-- The probe looks Constants up when it samples (it loads before core/constants.lua).
local constants, constantsCreated = StubBetterBagsModule("Constants")

describe("ItemProbe", function()
  local link = "|cffa335ee|Hitem:42::::::::80::::2:6652:10390::::|h[Gleaming Blade]|h|r"
  local saved

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved = {}
    override(C_Container, "GetContainerItemID", function(bag, slot) if bag == 0 and slot == 1 then return 42 end end)
    override(C_Container, "GetContainerItemLink", function(bag, slot) if bag == 0 and slot == 1 then return link end end)
    override(C_Container, "GetBagName", function(bag) return bag == 0 and "Backpack" or nil end)
    override(C_Item, "IsItemDataCached", function() return true end)
    override(C_Item, "IsItemDataCachedByID", function() return false end)
    override(C_Item, "GetItemInfo", function(info)
      if info == link then return "Gleaming Blade", link, 4, 600, 70 end
      return "Gleaming Blade", "base", 4, 580, 68
    end)
    override(C_Item, "GetItemInfoInstant", function() return 42, "Weapon", "Swords", "INVTYPE_WEAPON", 1, 2, 7 end)
    override(C_Item, "GetDetailedItemLevelInfo", function(info) return info == link and 619 or 580, false, 580 end)
    override(C_Item, "GetCurrentItemLevel", function() return 619 end)
    override(C_Item, "IsEquippableItem", function() return true end)
    override(C_Item, "GetItemSpell", function() end)
    override(C_Item, "IsCosmeticItem", function() return false end)
    override(C_Item, "GetItemUpgradeInfo", function() return { currentLevel = 3, maxLevel = 6, maxItemLevel = 619, trackString = "Hero" } end)
    override(C_Item, "CanScrapItem", function() return true end)
    override(C_Item, "GetItemStats", function() return { ITEM_MOD_HASTE_RATING_SHORT = 120 } end)
    override(_G, "C_TradeSkillUI", { GetItemReagentQualityByItemInfo = function() return nil end,
      GetItemCraftedQualityByItemInfo = function() return 3 end })
    override(_G, "C_PetJournal", { GetPetInfoByItemID = function() return nil end,
      GetNumCollectedInfo = function() return 1, 3 end })
    override(_G, "C_ToyBox", { GetToyInfo = function() return 42, "Gleaming Blade", 1, false, false, 4 end })
    override(_G, "PlayerHasToy", function() return false end)
    override(_G, "C_PlayerInfo", { CanUseItem = function() return true end })
    override(_G, "C_ItemUpgrade", { GetHighWatermarkForItem = function() return 626, 639 end })
    override(_G, "C_TransmogCollection", { GetItemInfo = function() return 1001, 2002 end,
      PlayerHasTransmogItemModifiedAppearance = function() return true end })
    override(C_TooltipInfo, "GetBagItem", function()
      return { dataInstanceID = 7, lines = {
        { type = 22, leftText = "Gleaming Blade" },
        { type = 0, leftText = "Toy", rightText = "" },
        { type = 44, leftText = "Use: Gleam." },
      } }
    end)
    override(_G, "canaccessvalue", nil)
  end)

  teardown(function()
    if constantsCreated then ResetModuleStub("Constants") end
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  it("records every answer an API gave, by item ID and by link", function()
    local p = itemProbe:Probe(0, 1)
    assert.are.equal(42, p.itemID)
    assert.are.equal(link, p.link)
    assert.are.same({ n = 5, "Gleaming Blade", "base", 4, 580, 68 }, p.itemInfoByID)
    assert.are.same({ n = 5, "Gleaming Blade", link, 4, 600, 70 }, p.itemInfoByLink)
    assert.are.same({ n = 3, 580, false, 580 }, p.detailedItemLevelByID)
    assert.are.same({ n = 3, 619, false, 580 }, p.detailedItemLevelByLink)
    assert.are.same({ n = 1, 619 }, p.currentItemLevel)
    assert.are.same({ n = 1, true }, p.dataCached)
    assert.are.same({ n = 1, false }, p.dataCachedByID)
    assert.are.same({ n = 1, true }, p.equippable)
    assert.are.same({ n = 0 }, p.itemSpell, "nothing returned is recorded as nothing")
    assert.are.same({ n = 1, { currentLevel = 3, maxLevel = 6, maxItemLevel = 619, trackString = "Hero" } }, p.upgradeInfo)
    assert.are.same({ n = 1, { ITEM_MOD_HASTE_RATING_SHORT = 120 } }, p.stats)
    assert.are.same({ n = 1, nil }, p.reagentQuality)
    assert.are.same({ n = 1, 3 }, p.craftedQuality)
    assert.are.same({ n = 6, 42, "Gleaming Blade", 1, false, false, 4 }, p.toyInfo)
    assert.are.same({ n = 1, false }, p.hasToy)
    assert.are.same({ n = 1, true }, p.canUse)
    assert.are.same({ n = 2, 626, 639 }, p.watermark)
    assert.are.same({ n = 2, 1001, 2002 }, p.transmog)
    assert.are.same({ n = 1, true }, p.transmogCollected)
    assert.are.same({ n = 1, "Backpack" }, p.bagName)
  end)

  it("records each tooltip line with its type", function()
    local p = itemProbe:Probe(0, 1)
    assert.are.same({
      { type = 22, left = "Gleaming Blade" },
      { type = 0, left = "Toy", right = "" },
      { type = 44, left = "Use: Gleam." },
    }, p.tooltip)
  end)

  it("asks how many of a pet species are collected only for an item that teaches one", function()
    assert.is_nil(itemProbe:Probe(0, 1).petCollected)
    _G.C_PetJournal.GetPetInfoByItemID = function()
      return "Adder", 1, 1, 1, "", "", false, true, true, false, true, 1, 635
    end
    local asked
    _G.C_PetJournal.GetNumCollectedInfo = function(species) asked = species return 1, 3 end
    local p = itemProbe:Probe(0, 1)
    assert.are.equal(635, asked)
    assert.are.same({ n = 2, 1, 3 }, p.petCollected)
  end)

  it("records an API's error instead of failing", function()
    C_Item.IsCosmeticItem = function() error("bad item") end
    local p = itemProbe:Probe(0, 1)
    assert.is_truthy(tostring(p.cosmetic.error):find("bad item", 1, true))
    assert.are.same({ n = 1, true }, p.equippable, "the other answers are still recorded")
  end)

  it("leaves out what the client does not have", function()
    _G.C_ToyBox = nil
    _G.PlayerHasToy = nil
    C_Item.GetItemUpgradeInfo = nil
    local p = itemProbe:Probe(0, 1)
    assert.is_nil(p.toyInfo)
    assert.is_nil(p.hasToy)
    assert.is_nil(p.upgradeInfo)
  end)

  -- A value the addon may not read (a secret value, under addon restrictions) is never read.
  it("records a value the addon may not access as a secret", function()
    _G.canaccessvalue = function(v) return v ~= 120 end
    local p = itemProbe:Probe(0, 1)
    assert.are.same({ n = 1, { ITEM_MOD_HASTE_RATING_SHORT = "<secret number>" } }, p.stats)
  end)

  it("records nothing for an empty slot", function()
    assert.is_nil(itemProbe:Probe(0, 2))
  end)

  -- Whether an appearance is collected, every way Vendor asks (itemproperties.lua): the item's
  -- source, any source of its appearance, the item itself, and whether the player could collect it.
  it("records whether the item's appearance is collected, every way it can be asked", function()
    _G.C_TransmogCollection.GetSourceInfo = function(source) return { sourceID = source, isCollected = true } end
    _G.C_TransmogCollection.GetAppearanceSources = function(appearance)
      return { { sourceID = 2002, isCollected = false }, { sourceID = 2003, isCollected = true } }
    end
    _G.C_TransmogCollection.PlayerHasTransmogByItemInfo = function(l) return l == link end
    _G.C_TransmogCollection.PlayerCanCollectSource = function() return true, false end
    local p = itemProbe:Probe(0, 1)
    assert.are.same({ n = 1, { sourceID = 2002, isCollected = true } }, p.transmogSource)
    assert.are.same({ n = 1, { { sourceID = 2002, isCollected = false }, { sourceID = 2003, isCollected = true } } },
      p.transmogAppearanceSources)
    assert.are.same({ n = 1, true }, p.transmogByItemInfo)
    assert.are.same({ n = 2, true, false }, p.transmogCanCollect)
  end)

  it("asks nothing about an appearance for an item without one", function()
    _G.C_TransmogCollection.GetItemInfo = function() end
    local asked = 0
    _G.C_TransmogCollection.GetSourceInfo = function() asked = asked + 1 end
    _G.C_TransmogCollection.GetAppearanceSources = function() asked = asked + 1 end
    local p = itemProbe:Probe(0, 1)
    assert.are.equal(0, asked)
    assert.is_nil(p.transmogSource)
  end)

  -- Worn gear has the upgrade tracks and watermarks a bag rarely does.
  it("records what the item in an equipment slot answered", function()
    override(_G, "GetInventoryItemID", function(unit, slot) if unit == "player" and slot == 15 then return 42 end end)
    override(_G, "GetInventoryItemLink", function(unit, slot) if unit == "player" and slot == 15 then return link end end)
    local tooltipSlot
    override(C_TooltipInfo, "GetInventoryItem", function(unit, slot)
      tooltipSlot = slot
      return { lines = { { type = 22, leftText = "Gleaming Blade" } } }
    end)
    local located
    override(C_Item, "GetCurrentItemLevel", function(location)
      located = location
      return 619
    end)
    local p = itemProbe:ProbeEquipped(15)
    assert.are.equal(15, p.equipmentSlot)
    assert.are.equal(42, p.itemID)
    assert.are.equal(link, p.link)
    assert.are.equal(15, tooltipSlot)
    assert.are.same({ { type = 22, left = "Gleaming Blade" } }, p.tooltip)
    assert.is_true(located:IsEquipmentSlot())
    assert.are.same({ n = 3, 619, false, 580 }, p.detailedItemLevelByLink)
    assert.is_nil(p.bagName)
    assert.is_nil(itemProbe:ProbeEquipped(1), "an empty slot")
  end)

  it("records every equipped item", function()
    override(_G, "GetInventoryItemID", function(_, slot) if slot == 1 or slot == 16 then return 42 end end)
    override(_G, "GetInventoryItemLink", function() return link end)
    local all = itemProbe:ProbeEquipment()
    assert.is_not_nil(all[1])
    assert.is_not_nil(all[16])
    assert.is_nil(all[2])
  end)

  -- The player values Vendor's rules read (docs/vendor-compat.md, "Player values"), raw.
  it("records the player values, raw", function()
    override(_G, "UnitLevel", function(unit) return unit == "player" and 90 or 0 end)
    override(_G, "UnitEffectiveLevel", function() return 85 end)
    override(_G, "GetAverageItemLevel", function() return 231.5, 229.25, 230 end)
    override(_G, "C_PaperDollInfo", { GetMinItemLevel = function() return 200 end })
    override(_G, "UnitClass", function() return "Warrior", "WARRIOR", 1 end)
    override(_G, "UnitFullName", function() return "Someone", "Somewhere" end)
    override(_G, "C_SpecializationInfo", { GetSpecialization = function() return 2 end,
      GetSpecializationInfo = function(index) return 72, "Fury", "", 1, "DAMAGER", 1 end })
    override(_G, "GetProfessions", function() return 3, nil, 7 end)
    override(_G, "GetProfessionInfo", function(index) return "Profession " .. index, 1, 50, 100 end)
    override(_G, "CanDualWield", function() return true end)
    local p = itemProbe:Player()
    assert.are.same({ n = 1, 90 }, p.level)
    assert.are.same({ n = 1, 85 }, p.effectiveLevel)
    assert.are.same({ n = 3, 231.5, 229.25, 230 }, p.averageItemLevel)
    assert.are.same({ n = 1, 200 }, p.minItemLevel)
    assert.are.same({ n = 3, "Warrior", "WARRIOR", 1 }, p.class)
    assert.are.same({ n = 2, "Someone", "Somewhere" }, p.fullName)
    assert.are.same({ n = 1, 2 }, p.specialization)
    assert.are.same({ n = 6, 72, "Fury", "", 1, "DAMAGER", 1 }, p.specializationInfo)
    assert.are.same({ n = 3, 3, nil, 7 }, p.professions)
    assert.are.same({ [3] = { n = 4, "Profession 3", 1, 50, 100 }, [7] = { n = 4, "Profession 7", 1, 50, 100 } },
      p.professionInfo)
    assert.are.same({ n = 1, true }, p.canDualWield)
  end)

  it("records no specialization info before a specialization is known", function()
    override(_G, "C_SpecializationInfo", { GetSpecialization = function() return 0 end,
      GetSpecializationInfo = function() error("no spec") end })
    local p = itemProbe:Player()
    assert.are.same({ n = 1, 0 }, p.specialization)
    assert.is_nil(p.specializationInfo)
  end)

  -- What every container the client knows says (the bank's tabs only while the bank is open).
  it("records every bag's name and size", function()
    override(_G.Enum, "BagIndex", { Backpack = 0, Bag_1 = 1, CharacterBankTab_1 = 6 })
    override(C_Container, "GetBagName", function(bag) if bag == 6 then return "Tab One" end end)
    override(C_Container, "GetContainerNumSlots", function(bag) return bag == 6 and 98 or 0 end)
    override(C_Container, "GetContainerNumFreeSlots", function(bag) return bag == 6 and 90 or 0, 0 end)
    local names = itemProbe:BagNames()
    assert.are.same({ name = "CharacterBankTab_1", bagName = { n = 1, "Tab One" }, slots = { n = 1, 98 },
      free = { n = 2, 90, 0 } }, names[6])
    assert.are.same({ n = 0 }, names[0].bagName, "answered nothing")
  end)

  -- What follows the character and the account, for each item in the backpack, sampled while a
  -- diagnostics capture runs: when each is known at login against the bag reads.
  it("samples what follows the character and the account for the backpack's items", function()
    override(constants, "BACKPACK_BAGS", { [0] = 0 })
    override(C_Container, "GetContainerNumSlots", function(bag) return bag == 0 and 2 or 0 end)
    override(C_Container, "GetContainerItemID", function(bag, slot) if bag == 0 then return slot == 1 and 42 or 43 end end)
    override(C_Container, "GetContainerItemLink", function(bag, slot) return "|Hitem:" .. (slot == 1 and 42 or 43) .. "|h" end)
    _G.C_PlayerInfo.CanUseItem = function(id) return id == 42 end
    _G.C_TransmogCollection.GetItemInfo = function(l) if l:find("item:42", 1, true) then return 1001, 2002 end end
    _G.C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance = function(source) return source == 2002 end
    _G.C_PetJournal.GetPetInfoByItemID = function(id)
      if id == 43 then return "Adder", 1, 1, 1, "", "", false, true, true, false, true, 1, 635 end
    end
    _G.C_PetJournal.GetNumCollectedInfo = function(species) return species == 635 and 2 or 0, 3 end
    override(_G, "UnitLevel", function() return 90 end)
    override(_G, "UnitFullName", function() return "Someone", "Somewhere" end)
    local sample = itemProbe:Sample()
    assert.are.same({ [42] = true, [43] = false }, sample.usable)
    assert.are.same({ [2002] = true }, sample.appearances)
    assert.are.same({ [635] = { 2, 3 } }, sample.pets)
    assert.are.same({ n = 1, 90 }, sample.player.level)
    assert.is_nil(sample.player.fullName, "a sample leaves out who the player is")
  end)

  it("asks once about an item held in two slots", function()
    override(constants, "BACKPACK_BAGS", { [0] = 0 })
    override(C_Container, "GetContainerNumSlots", function() return 2 end)
    override(C_Container, "GetContainerItemID", function() return 42 end)
    local asked = 0
    _G.C_PlayerInfo.CanUseItem = function() asked = asked + 1 return true end
    itemProbe:Sample()
    assert.are.equal(1, asked)
  end)

  it("describes the client the probes were taken on", function()
    local client = itemProbe:Client()
    assert.are.same({ version = "10.0.0", build = "12345", date = "Jan 1 2024", interface = 100000 },
      { version = client.version, build = client.build, date = client.date, interface = client.interface })
    assert.are.equal("enUS", client.locale)
    assert.is_number(client.time)
  end)
end)
