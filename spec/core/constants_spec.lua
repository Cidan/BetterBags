local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Required globals for constants loading
_G.Enum = _G.Enum or {}
_G.Enum.BagIndex = {
  Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4,
  ReagentBag = 5, Bank = -1, Reagentbank = -3,
  BankBag_1 = 6, BankBag_2 = 7, BankBag_3 = 8, BankBag_4 = 9,
  BankBag_5 = 10, BankBag_6 = 11, BankBag_7 = 12,
  Characterbanktab = 100, CharacterBankTab_1 = 101, CharacterBankTab_2 = 102,
  CharacterBankTab_3 = 103, CharacterBankTab_4 = 104, CharacterBankTab_5 = 105,
  CharacterBankTab_6 = 106,
  AccountBankTab_1 = 200, AccountBankTab_2 = 201, AccountBankTab_3 = 202,
  AccountBankTab_4 = 203, AccountBankTab_5 = 204,
  Keyring = -2,
}
_G.Enum.ItemQuality = {
  Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
  Legendary = 5, Artifact = 6, Heirloom = 7, WoWToken = 8,
  Good = 2, Standard = 1,
}
_G.Enum.ItemClass = {
  Tradegoods = 7,
}
_G.Enum.InventoryType = {
  IndexHeadType = 1, IndexNeckType = 2, IndexShoulderType = 3,
  IndexBodyType = 4, IndexChestType = 5, IndexWaistType = 6,
  IndexLegsType = 7, IndexFeetType = 8, IndexWristType = 9,
  IndexHandType = 10, IndexFingerType = 11, IndexTrinketType = 12,
  IndexWeaponType = 13, IndexShieldType = 14, IndexRangedType = 15,
  IndexCloakType = 16, Index2HweaponType = 17, IndexTabardType = 18,
  IndexRobeType = 20, IndexWeaponmainhandType = 21,
  IndexWeaponoffhandType = 22, IndexHoldableType = 23,
  IndexThrownType = 25, IndexRangedrightType = 26,
}

_G.INVSLOT_HEAD = 1
_G.INVSLOT_NECK = 2
_G.INVSLOT_SHOULDER = 3
_G.INVSLOT_BODY = 4
_G.INVSLOT_CHEST = 5
_G.INVSLOT_WAIST = 6
_G.INVSLOT_LEGS = 7
_G.INVSLOT_FEET = 8
_G.INVSLOT_WRIST = 9
_G.INVSLOT_HAND = 10
_G.INVSLOT_FINGER1 = 11
_G.INVSLOT_FINGER2 = 12
_G.INVSLOT_TRINKET1 = 13
_G.INVSLOT_TRINKET2 = 14
_G.INVSLOT_BACK = 15
_G.INVSLOT_MAINHAND = 16
_G.INVSLOT_OFFHAND = 17
_G.INVSLOT_RANGED = 18
_G.INVSLOT_TABARD = 19

_G.C_Item = _G.C_Item or {}
_G.C_Item.GetItemSubClassInfo = function(_, subclassID)
  return "SubClass " .. tostring(subclassID)
end

_G.ITEM_QUALITY0_DESC = "Poor"
_G.ITEM_QUALITY1_DESC = "Common"
_G.ITEM_QUALITY2_DESC = "Uncommon"
_G.ITEM_QUALITY3_DESC = "Rare"
_G.ITEM_QUALITY4_DESC = "Epic"
_G.ITEM_QUALITY5_DESC = "Legendary"
_G.ITEM_QUALITY6_DESC = "Artifact"
_G.ITEM_QUALITY7_DESC = "Heirloom"
_G.ITEM_QUALITY8_DESC = "WoWToken"

_G.LE_EXPANSION_CLASSIC = 0
_G.LE_EXPANSION_BURNING_CRUSADE = 1
_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2
_G.LE_EXPANSION_CATACLYSM = 3
_G.LE_EXPANSION_MISTS_OF_PANDARIA = 4
_G.LE_EXPANSION_WARLORDS_OF_DRAENOR = 5
_G.LE_EXPANSION_LEGION = 6
_G.LE_EXPANSION_BATTLE_FOR_AZEROTH = 7
_G.LE_EXPANSION_SHADOWLANDS = 8
_G.LE_EXPANSION_DRAGONFLIGHT = 9
_G.LE_EXPANSION_WAR_WITHIN = 10
_G.LE_EXPANSION_MIDNIGHT = 11

_G.EXPANSION_NAME0 = "Classic"
_G.EXPANSION_NAME1 = "Burning Crusade"
_G.EXPANSION_NAME2 = "Wrath of the Lich King"
_G.EXPANSION_NAME3 = "Cataclysm"
_G.EXPANSION_NAME4 = "Mists of Pandaria"
_G.EXPANSION_NAME5 = "Warlords of Draenor"
_G.EXPANSION_NAME6 = "Legion"
_G.EXPANSION_NAME7 = "Battle for Azeroth"
_G.EXPANSION_NAME8 = "Shadowlands"
_G.EXPANSION_NAME9 = "Dragonflight"
_G.EXPANSION_NAME10 = "The War Within"
_G.EXPANSION_NAME11 = "Midnight"

-- Stub dependencies
local L = StubBetterBagsModule("Localization")
L.G = function(self, key) return key end

describe("Constants Module Offsets", function()
  before_each(function()
    addon.modules["Constants"] = nil
    local aceAddon = LibStub("AceAddon-3.0")
    if aceAddon.addons["BetterBags_Constants"] then
      aceAddon.addons["BetterBags_Constants"] = nil
    end
  end)

  after_each(function()
    addon.modules["Constants"] = nil
    local aceAddon = LibStub("AceAddon-3.0")
    if aceAddon.addons["BetterBags_Constants"] then
      aceAddon.addons["BetterBags_Constants"] = nil
    end
  end)

  it("should have SCROLLBAR_WIDTH defined in the default constants offsets", function()
    loadfile("core/constants.lua")("BetterBags")
    local const = addon:GetModule("Constants")
    assert.is_not_nil(const.OFFSETS)
    assert.are.equal(14, const.OFFSETS.SCROLLBAR_WIDTH)
  end)

  it("should have SCROLLBAR_WIDTH defined in the era constants offsets", function()
    loadfile("core/constants.lua")("BetterBags")
    loadfile("core/era/constants.lua")("BetterBags")
    local const = addon:GetModule("Constants")
    assert.is_not_nil(const.OFFSETS)
    assert.are.equal(14, const.OFFSETS.SCROLLBAR_WIDTH)
  end)

  it("should have SCROLLBAR_WIDTH defined in the classic constants offsets", function()
    loadfile("core/constants.lua")("BetterBags")
    loadfile("core/classic/constants.lua")("BetterBags")
    local const = addon:GetModule("Constants")
    assert.is_not_nil(const.OFFSETS)
    assert.are.equal(14, const.OFFSETS.SCROLLBAR_WIDTH)
  end)

  describe("dynamic bank tab sizing", function()
    local addedKeys

    local function countKeys(t)
      local n = 0
      for _ in pairs(t) do n = n + 1 end
      return n
    end

    before_each(function()
      addon.modules["Constants"] = nil
      local aceAddon = LibStub("AceAddon-3.0")
      if aceAddon.addons["BetterBags_Constants"] then
        aceAddon.addons["BetterBags_Constants"] = nil
      end
      addedKeys = {}
    end)

    after_each(function()
      -- Remove any bank tab enum members added by a test so the default 6+5
      -- retail shape is restored for other specs.
      for _, key in ipairs(addedKeys) do
        _G.Enum.BagIndex[key] = nil
      end
    end)

    it("yields the 6+5 retail shape from a live-retail enum", function()
      loadfile("core/constants.lua")("BetterBags")
      local const = addon:GetModule("Constants")
      assert.are.equal(6, #const.BANK_ONLY_BAGS_LIST)
      assert.are.equal(6, countKeys(const.BANK_ONLY_BAGS))
      -- BANK_BAGS also carries the main Characterbanktab container (6 tabs + 1).
      assert.are.equal(7, countKeys(const.BANK_BAGS))
      assert.are.equal(5, countKeys(const.ACCOUNT_BANK_BAGS))
      assert.are.equal(5, #const.ACCOUNT_BANK_BAGS_LIST)
      -- Tabs beyond the retail cap must not be present.
      assert.is_nil(const.BANK_ONLY_BAGS[Enum.BagIndex.CharacterBankTab_6 + 1])
    end)

    it("expands to 9+9 when the enum exposes Camelot's extra tabs", function()
      -- Simulate WoW: Forever (Camelot), which adds CharacterBankTab_7..9 and
      -- AccountBankTab_6..9 to Enum.BagIndex.
      local charBase = Enum.BagIndex.CharacterBankTab_6
      for i = 7, 9 do
        local key = "CharacterBankTab_" .. i
        _G.Enum.BagIndex[key] = charBase + (i - 6)
        table.insert(addedKeys, key)
      end
      local acctBase = Enum.BagIndex.AccountBankTab_5
      for i = 6, 9 do
        local key = "AccountBankTab_" .. i
        _G.Enum.BagIndex[key] = acctBase + (i - 5)
        table.insert(addedKeys, key)
      end

      loadfile("core/constants.lua")("BetterBags")
      local const = addon:GetModule("Constants")

      assert.are.equal(9, #const.BANK_ONLY_BAGS_LIST)
      assert.are.equal(9, countKeys(const.BANK_ONLY_BAGS))
      assert.are.equal(10, countKeys(const.BANK_BAGS))
      assert.are.equal(9, countKeys(const.ACCOUNT_BANK_BAGS))
      assert.are.equal(9, #const.ACCOUNT_BANK_BAGS_LIST)

      -- The new tabs resolve to their enum values in every derived table.
      assert.are.equal(Enum.BagIndex.CharacterBankTab_9, const.BANK_ONLY_BAGS[Enum.BagIndex.CharacterBankTab_9])
      assert.are.equal(Enum.BagIndex.CharacterBankTab_9, const.BANK_BAGS[Enum.BagIndex.CharacterBankTab_9])
      assert.are.equal(Enum.BagIndex.AccountBankTab_9, const.ACCOUNT_BANK_BAGS[Enum.BagIndex.AccountBankTab_9])
      assert.are.equal(Enum.BagIndex.AccountBankTab_9, const.ACCOUNT_BANK_BAGS_LIST[9])

      -- BANK_TAB covers every character and account tab plus the aliases.
      assert.are.equal(Enum.BagIndex.CharacterBankTab_9, const.BANK_TAB[Enum.BagIndex.CharacterBankTab_9])
      assert.are.equal(Enum.BagIndex.AccountBankTab_9, const.BANK_TAB[Enum.BagIndex.AccountBankTab_9])
      assert.are.equal(Enum.BagIndex.Characterbanktab, const.BANK_TAB.BANK)
      assert.are.equal(Enum.BagIndex.AccountBankTab_1, const.BANK_TAB.ACCOUNT_BANK_1)
    end)

    it("preserves BANK_ONLY_BAGS_LIST ordering by tab index", function()
      for i = 7, 9 do
        local key = "CharacterBankTab_" .. i
        _G.Enum.BagIndex[key] = Enum.BagIndex.CharacterBankTab_6 + (i - 6)
        table.insert(addedKeys, key)
      end
      loadfile("core/constants.lua")("BetterBags")
      local const = addon:GetModule("Constants")
      for i = 1, 9 do
        assert.are.equal(Enum.BagIndex["CharacterBankTab_" .. i], const.BANK_ONLY_BAGS_LIST[i])
      end
    end)
  end)

  describe("addon.isForever normalization", function()
    local savedIsForever
    before_each(function() savedIsForever = addon.isForever end)
    after_each(function() addon.isForever = savedIsForever end)

    it("normalizes an unset flag to false (retail/classic are never Forever)", function()
      addon.isForever = nil
      loadfile("core/constants.lua")("BetterBags")
      assert.is_false(addon.isForever)
    end)

    it("preserves the flag set by core/forever.lua (Camelot stays Forever)", function()
      addon.isForever = true
      loadfile("core/constants.lua")("BetterBags")
      assert.is_true(addon.isForever)
    end)
  end)

  describe("warbank availability (no warbank on Forever)", function()
    local savedIsForever, savedHasWarbank

    local function countKeys(t)
      local n = 0
      for _ in pairs(t) do n = n + 1 end
      return n
    end

    before_each(function()
      savedIsForever = addon.isForever
      savedHasWarbank = addon.hasWarbank
      addon.modules["Constants"] = nil
      local aceAddon = LibStub("AceAddon-3.0")
      if aceAddon.addons["BetterBags_Constants"] then
        aceAddon.addons["BetterBags_Constants"] = nil
      end
    end)

    after_each(function()
      addon.isForever = savedIsForever
      addon.hasWarbank = savedHasWarbank
    end)

    it("populates account bank tables and sets hasWarbank on live retail", function()
      addon.isForever = nil
      loadfile("core/constants.lua")("BetterBags")
      local const = addon:GetModule("Constants")
      assert.is_true(addon.hasWarbank)
      assert.are.equal(5, countKeys(const.ACCOUNT_BANK_BAGS))
      assert.are.equal(5, #const.ACCOUNT_BANK_BAGS_LIST)
    end)

    it("leaves account bank tables empty and clears hasWarbank on Forever", function()
      addon.isForever = true
      loadfile("core/constants.lua")("BetterBags")
      local const = addon:GetModule("Constants")
      assert.is_false(addon.hasWarbank)
      -- Account tables exist but are empty, so every table-driven warbank site is inert.
      assert.are.equal(0, countKeys(const.ACCOUNT_BANK_BAGS))
      assert.are.equal(0, #const.ACCOUNT_BANK_BAGS_LIST)
      -- Character bank tabs are unaffected.
      assert.are.equal(6, #const.BANK_ONLY_BAGS_LIST)
    end)
  end)
end)
