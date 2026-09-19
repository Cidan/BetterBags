-- equipmentsets_spec.lua -- Unit tests for data/equipmentsets.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- The module reads version flags directly from the addon object
addon.isClassic = false
addon.isAnniversary = false
addon.isRetail = true
addon.isMidnight = false

StubBetterBagsModule("Constants")
StubBetterBagsModule("Localization")

LoadBetterBagsModule("data/equipmentsets.lua")
local equipmentSets = addon:GetModule("EquipmentSets")

describe("EquipmentSets", function()

  before_each(function()
    addon.isClassic = false
    addon.isAnniversary = false
    addon.isRetail = true
    addon.isMidnight = false

    _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {} end
    _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "" end
    _G.C_EquipmentSet.GetItemLocations = function() return {} end

    _G.EquipmentManager_UnpackLocation = function()
      return 0, false, true, false, 1, 0
    end
    _G.EquipmentManager_GetLocationData = function()
      return { isBank = false, isBags = true, slot = 1, bag = 0 }
    end

    equipmentSets:Init()
  end)

  -- ─── Update (API feature detection) ───────────────────────────────────────────

  describe("Update", function()

    it("returns early on classic", function()
      addon.isClassic = true
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() error("should not be called") end
      equipmentSets:Update()
    end)

    it("returns early on anniversary", function()
      addon.isAnniversary = true
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() error("should not be called") end
      equipmentSets:Update()
    end)

    it("uses the UnpackLocation path when that API exists", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) return "Set" .. id end
      _G.C_EquipmentSet.GetItemLocations = function(id) return {"loc-" .. id} end
      _G.EquipmentManager_UnpackLocation = function()
        return 0, false, true, false, 1, 0
      end
      -- GetLocationData present too, but UnpackLocation must win where available.
      _G.EquipmentManager_GetLocationData = function()
        error("should not be called when UnpackLocation exists")
      end
      equipmentSets:Update()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("uses the GetLocationData path when UnpackLocation is absent (Midnight)", function()
      _G.EquipmentManager_UnpackLocation = nil
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) return "Set" .. id end
      _G.C_EquipmentSet.GetItemLocations = function(id) return {"loc-" .. id} end
      _G.EquipmentManager_GetLocationData = function()
        return { isBank = false, isBags = true, slot = 1, bag = 0 }
      end
      equipmentSets:Update()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))
    end)

    -- Regression: WoW: Forever (Camelot) is a mainline retail fork that ships the
    -- Midnight EquipmentManager (only GetLocationData; no UnpackLocation) but reports
    -- a sub-12.0 TOC, so addon.isMidnight is false. The old version gate routed it to
    -- the UnpackLocation path and crashed with "attempt to call a nil value".
    it("does not crash on Forever (retail, non-midnight, no UnpackLocation)", function()
      addon.isRetail = true
      addon.isMidnight = false
      _G.EquipmentManager_UnpackLocation = nil
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) return "Forever Set" .. id end
      _G.C_EquipmentSet.GetItemLocations = function(id) return {"loc-" .. id} end
      _G.EquipmentManager_GetLocationData = function()
        return { isBank = false, isBags = true, slot = 4, bag = 2 }
      end
      assert.has_no.errors(function() equipmentSets:Update() end)
      assert.are.same({"Forever Set1"}, equipmentSets:GetItemSets(2, 4))
    end)
  end)

  -- ─── UpdatePreMidnight ────────────────────────────────────────────────────────

  describe("UpdatePreMidnight", function()

    it("maps equipment set items to bagAndSlotToSet", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1, 2} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) -- luacheck: ignore 212
        if id == 1 then return "Tank Set" else return "DPS Set" end
      end
      _G.C_EquipmentSet.GetItemLocations = function(id) -- luacheck: ignore 212
        return {"loc-" .. id .. "-a", "loc-" .. id .. "-b"}
      end
      _G.EquipmentManager_UnpackLocation = function(loc) -- luacheck: ignore 212
        if loc == "loc-1-a" then return 0, false, true, false, 1, 0 end
        if loc == "loc-1-b" then return 0, false, true, false, 2, 0 end
        if loc == "loc-2-a" then return 0, false, true, false, 1, 0 end
        if loc == "loc-2-b" then return 0, false, true, false, 3, 0 end
        return 0, false, false, false, 0, 0
      end

      equipmentSets:UpdatePreMidnight()

      local sets1 = equipmentSets:GetItemSets(0, 1)
      assert.are.same({"Tank Set", "DPS Set"}, sets1)
      assert.are.same({"Tank Set"}, equipmentSets:GetItemSets(0, 2))
      assert.are.same({"DPS Set"}, equipmentSets:GetItemSets(0, 3))
    end)

    it("handles nil setLocations (bugfix for #113)", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1, 2} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) return "Set" .. id end -- luacheck: ignore 212
      _G.C_EquipmentSet.GetItemLocations = function(id) -- luacheck: ignore 212
        if id == 1 then return nil end
        return {"loc-2"}
      end
      _G.EquipmentManager_UnpackLocation = function()
        return 0, false, true, false, 1, 0
      end

      equipmentSets:UpdatePreMidnight()
      assert.are.same({"Set2"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("filters out non-bag/non-bank locations", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set1" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"loc-good", "loc-bad"} end
      _G.EquipmentManager_UnpackLocation = function(loc) -- luacheck: ignore 212
        if loc == "loc-good" then return 0, false, true, false, 1, 0 end
        if loc == "loc-bad" then return 0, false, false, false, 1, 0 end
      end

      equipmentSets:UpdatePreMidnight()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("shifts slots for non-retail (no void bank)", function()
      addon.isRetail = false
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Classic Set" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"loc-1"} end
      _G.EquipmentManager_UnpackLocation = function()
        return 0, false, true, 3, 5, 0
      end

      equipmentSets:UpdatePreMidnight()
      local result = equipmentSets:GetItemSets(5, 3)
      assert.are.same({"Classic Set"}, result)
    end)

    it("skips locations with nil slot or nil bag", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set1" end
      _G.C_EquipmentSet.GetItemLocations = function()
        return {"loc-nil-slot", "loc-nil-bag", "loc-good"}
      end
      _G.EquipmentManager_UnpackLocation = function(loc) -- luacheck: ignore 212
        if loc == "loc-nil-slot" then return 0, false, true, nil, nil, 0 end
        if loc == "loc-nil-bag" then return 0, false, true, false, 1, nil end
        if loc == "loc-good" then return 0, false, true, false, 1, 0 end
      end

      equipmentSets:UpdatePreMidnight()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("handles empty equipment set IDs", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {} end
      equipmentSets:UpdatePreMidnight()
      assert.is_nil(equipmentSets:GetItemSets(0, 1))
    end)

    it("clears previous state on each update", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set1" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"loc-1"} end
      _G.EquipmentManager_UnpackLocation = function()
        return 0, false, true, false, 1, 0
      end

      equipmentSets:UpdatePreMidnight()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))

      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {2} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set2" end
      equipmentSets:UpdatePreMidnight()

      assert.are.same({"Set2"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("includes bank locations", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Bank Set" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"loc-bank"} end
      _G.EquipmentManager_UnpackLocation = function()
        return 0, true, false, false, 5, 1
      end

      equipmentSets:UpdatePreMidnight()
      assert.are.same({"Bank Set"}, equipmentSets:GetItemSets(1, 5))
    end)
  end)

  -- ─── UpdateMidnight ───────────────────────────────────────────────────────────

  describe("UpdateMidnight", function()

    it("maps equipment set items using GetLocationData", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1, 2} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) -- luacheck: ignore 212
        if id == 1 then return "Midnight Set A" else return "Midnight Set B" end
      end
      _G.C_EquipmentSet.GetItemLocations = function(id) -- luacheck: ignore 212
        return {"mloc-" .. id .. "-1", "mloc-" .. id .. "-2"}
      end
      _G.EquipmentManager_GetLocationData = function(loc) -- luacheck: ignore 212
        if loc == "mloc-1-1" then return { isBank = false, isBags = true, slot = 1, bag = 0 } end
        if loc == "mloc-1-2" then return { isBank = false, isBags = true, slot = 2, bag = 0 } end
        if loc == "mloc-2-1" then return { isBank = false, isBags = true, slot = 1, bag = 0 } end
        if loc == "mloc-2-2" then return { isBank = true, isBags = false, slot = 3, bag = 2 } end
        return { isBank = false, isBags = false, slot = 0, bag = 0 }
      end

      equipmentSets:UpdateMidnight()

      assert.are.same({"Midnight Set A", "Midnight Set B"}, equipmentSets:GetItemSets(0, 1))
      assert.are.same({"Midnight Set A"}, equipmentSets:GetItemSets(0, 2))
      assert.are.same({"Midnight Set B"}, equipmentSets:GetItemSets(2, 3))
    end)

    it("handles nil setLocations", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1, 2} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function(id) return "Set" .. id end -- luacheck: ignore 212
      _G.C_EquipmentSet.GetItemLocations = function(id) -- luacheck: ignore 212
        if id == 1 then return nil end
        return {"mloc-2"}
      end
      _G.EquipmentManager_GetLocationData = function()
        return { isBank = false, isBags = true, slot = 1, bag = 0 }
      end

      equipmentSets:UpdateMidnight()
      assert.are.same({"Set2"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("filters out non-bag, non-bank locations", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set1" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"mloc-equip"} end
      _G.EquipmentManager_GetLocationData = function()
        return { isBank = false, isBags = false, slot = 5, bag = 0 }
      end

      equipmentSets:UpdateMidnight()
      assert.is_nil(equipmentSets:GetItemSets(0, 5))
    end)

    it("skips locations with nil slot or nil bag", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set1" end
      _G.C_EquipmentSet.GetItemLocations = function()
        return {"mloc-nil-slot", "mloc-good"}
      end
      _G.EquipmentManager_GetLocationData = function(loc) -- luacheck: ignore 212
        if loc == "mloc-nil-slot" then return { isBank = false, isBags = true, slot = nil, bag = 0 } end
        if loc == "mloc-good" then return { isBank = false, isBags = true, slot = 1, bag = 0 } end
      end

      equipmentSets:UpdateMidnight()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))
    end)

    it("clears previous state on each update", function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set1" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"mloc-1"} end
      _G.EquipmentManager_GetLocationData = function()
        return { isBank = false, isBags = true, slot = 1, bag = 0 }
      end

      equipmentSets:UpdateMidnight()
      assert.are.same({"Set1"}, equipmentSets:GetItemSets(0, 1))

      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {2} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Set2" end
      equipmentSets:UpdateMidnight()

      assert.are.same({"Set2"}, equipmentSets:GetItemSets(0, 1))
    end)
  end)

  -- ─── GetItemSets ──────────────────────────────────────────────────────────────

  describe("GetItemSets", function()

    before_each(function()
      _G.C_EquipmentSet.GetEquipmentSetIDs = function() return {1} end
      _G.C_EquipmentSet.GetEquipmentSetInfo = function() return "Test Set" end
      _G.C_EquipmentSet.GetItemLocations = function() return {"loc-1"} end
      _G.EquipmentManager_UnpackLocation = function()
        return 0, false, true, false, 1, 0
      end
      equipmentSets:UpdatePreMidnight()
    end)

    it("returns set names for a valid bag/slot", function()
      local sets = equipmentSets:GetItemSets(0, 1)
      assert.are.same({"Test Set"}, sets)
    end)

    it("returns nil for nil bagid", function()
      assert.is_nil(equipmentSets:GetItemSets(nil, 1))
    end)

    it("returns nil for nil slotid", function()
      assert.is_nil(equipmentSets:GetItemSets(0, nil))
    end)

    it("returns nil for non-existent bag/slot combination", function()
      assert.is_nil(equipmentSets:GetItemSets(99, 99))
    end)

    it("returns nil for valid bag but invalid slot", function()
      assert.is_nil(equipmentSets:GetItemSets(0, 99))
    end)
  end)
end)
