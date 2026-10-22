-- itemprobe_spec.lua -- Unit tests for debug/itemprobe.lua (ItemProbe): what each Blizzard API
-- answered about an item, recorded raw for the Dump tab (data-driven.md).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("ItemProbe", "debug/itemprobe.lua")
LoadBetterBagsModule("debug/itemprobe.lua")
local itemProbe = addon:GetModule("ItemProbe")

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

  it("describes the client the probes were taken on", function()
    local client = itemProbe:Client()
    assert.are.same({ version = "10.0.0", build = "12345", date = "Jan 1 2024", interface = 100000 },
      { version = client.version, build = client.build, date = client.date, interface = client.interface })
    assert.are.equal("enUS", client.locale)
    assert.is_number(client.time)
  end)
end)
