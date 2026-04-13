-- binding_spec.lua -- Unit tests for data/binding.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local const = StubBetterBagsModule("Constants")

-- Set up binding scope constants
const.BINDING_SCOPE = {
  UNKNOWN = 0,
  NONBINDING = 1,
  BOE = 2,
  BOU = 3,
  QUEST = 4,
  SOULBOUND = 5,
  REFUNDABLE = 6,
  ACCOUNT = 7,
  BNET = 8,
  BOUND = 9,
  WUE = 10,
}

-- Mock WoW APIs for binding detection
_G.C_Item = _G.C_Item or {}
_G.C_Bank = nil
_G.C_Container = _G.C_Container or {}
_G.Enum = _G.Enum or {}
_G.Enum.BankType = { Account = 2, Character = 1 }

LoadBetterBagsModule("data/binding.lua")
local binding = addon:GetModule("Binding")

--- Create a mock ItemLocation
local function MockItemLocation(opts)
  opts = opts or {}
  return {
    GetBagAndSlot = function() return opts.bagID or 0, opts.slotID or 1 end,
    GetEquipmentSlot = function() return opts.equipSlot or 0 end,
    IsEquipmentSlot = function() return opts.isEquipped or false end,
  }
end

describe("Binding", function()

  before_each(function()
    -- Reset C_Item mocks
    _G.C_Item.IsBound = function() return false end
    _G.C_Item.IsBoundToAccountUntilEquip = nil
    -- Reset C_Bank (nil = not retail)
    _G.C_Bank = nil
    -- Reset C_Container
    _G.C_Container.GetContainerItemPurchaseInfo = function() return nil end
  end)

  describe("GetItemBinding", function()

    -- ─── Unbound items ──────────────────────────────────────────────────────

    it("returns NONBINDING for bindType 0 (no bind)", function()
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 0)
      assert.are.equal(const.BINDING_SCOPE.NONBINDING, info.binding)
      assert.is_false(info.bound)
    end)

    it("returns BOE for bindType 2 (bind on equip)", function()
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 2)
      assert.are.equal(const.BINDING_SCOPE.BOE, info.binding)
      assert.is_false(info.bound)
    end)

    it("returns BOU for bindType 3 (bind on use)", function()
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 3)
      assert.are.equal(const.BINDING_SCOPE.BOU, info.binding)
      assert.is_false(info.bound)
    end)

    it("returns BNET for bindType 8 (battle.net bound)", function()
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 8)
      assert.are.equal(const.BINDING_SCOPE.BNET, info.binding)
      assert.is_false(info.bound)
    end)

    it("returns UNKNOWN for unrecognized unbound bindType", function()
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 99)
      assert.are.equal(const.BINDING_SCOPE.UNKNOWN, info.binding)
      assert.is_false(info.bound)
    end)

    it("returns WUE when IsBoundToAccountUntilEquip is true (retail)", function()
      _G.C_Item.IsBoundToAccountUntilEquip = function() return true end
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 2)
      assert.are.equal(const.BINDING_SCOPE.WUE, info.binding)
      assert.is_true(info.bound)
    end)

    -- ─── Bound items ────────────────────────────────────────────────────────

    it("returns BOUND for a generic bound item", function()
      _G.C_Item.IsBound = function() return true end
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 1)
      assert.are.equal(const.BINDING_SCOPE.BOUND, info.binding)
      assert.is_true(info.bound)
    end)

    it("returns SOULBOUND on retail with C_Bank available", function()
      _G.C_Item.IsBound = function() return true end
      _G.C_Bank = {
        IsItemAllowedInBankType = function() return false end,
      }
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 1)
      assert.are.equal(const.BINDING_SCOPE.SOULBOUND, info.binding)
      assert.is_true(info.bound)
    end)

    it("returns ACCOUNT when item is allowed in account bank", function()
      _G.C_Item.IsBound = function() return true end
      -- C_Bank.IsItemAllowedInBankType is a C API (dot call, no self)
      _G.C_Bank = {
        IsItemAllowedInBankType = function(bankType)
          return bankType == _G.Enum.BankType.Account
        end,
      }
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 1)
      assert.are.equal(const.BINDING_SCOPE.ACCOUNT, info.binding)
      assert.is_true(info.bound)
    end)

    it("returns REFUNDABLE when purchase info exists", function()
      _G.C_Item.IsBound = function() return true end
      _G.C_Container.GetContainerItemPurchaseInfo = function() return {money = 100} end
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 1)
      assert.are.equal(const.BINDING_SCOPE.REFUNDABLE, info.binding)
      assert.is_true(info.bound)
    end)

    it("returns QUEST for bound quest items (bindType 4)", function()
      _G.C_Item.IsBound = function() return true end
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 4)
      assert.are.equal(const.BINDING_SCOPE.QUEST, info.binding)
      assert.is_true(info.bound)
    end)

    -- ─── Priority ordering for bound items ──────────────────────────────────

    it("QUEST overrides REFUNDABLE (bindType 4 takes priority last)", function()
      _G.C_Item.IsBound = function() return true end
      _G.C_Container.GetContainerItemPurchaseInfo = function() return {money = 100} end
      local loc = MockItemLocation()
      local info = binding.GetItemBinding(loc, 4)
      -- The code checks REFUNDABLE before QUEST, but QUEST comes after and overwrites
      assert.are.equal(const.BINDING_SCOPE.QUEST, info.binding)
    end)

    it("passes correct bagID and slotID to GetContainerItemPurchaseInfo", function()
      _G.C_Item.IsBound = function() return true end
      local receivedBag, receivedSlot, receivedEquipped
      _G.C_Container.GetContainerItemPurchaseInfo = function(bag, slot, equipped)
        receivedBag = bag
        receivedSlot = slot
        receivedEquipped = equipped
        return nil
      end
      local loc = MockItemLocation({bagID = 3, slotID = 7, isEquipped = false})
      binding.GetItemBinding(loc, 1)
      assert.are.equal(3, receivedBag)
      assert.are.equal(7, receivedSlot)
      assert.is_false(receivedEquipped)
    end)
  end)
end)
