-- cursorplacement_spec.lua -- Unit tests for util/cursorplacement.lua (issue #408: an item
-- dropped anywhere on a bag window goes into a free slot of that window's bags).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local const = StubBetterBagsModule("Constants")

ResetModuleStub("CursorPlacement", "util/cursorplacement.lua")
LoadBetterBagsModule("util/cursorplacement.lua")
local cursorPlacement = addon:GetModule("CursorPlacement")

describe("CursorPlacement", function()
  local saved = {}
  local families
  local itemClasses
  local reagents

  local function save(tbl, key)
    table.insert(saved, { tbl = tbl, key = key, value = tbl[key] })
  end

  -- Puts an item on the cursor, picked up from location (nil when the client gives none). An item
  -- picked up from a bag stays in its slot until it is put down (C_Cursor.GetCursorItem names it).
  local function holding(itemID, location)
    _G._cursorHasItem = true
    _G._cursorType = "item"
    _G._cursorItemID = itemID
    _G._cursorItemLink = "[Item " .. itemID .. "]"
    _G._cursorItemLocation = location
    if location and location:IsBagAndSlot() then
      local bag, slot = location:GetBagAndSlot()
      _G._itemsAtLocation[bag .. ":" .. slot] = { itemID = itemID }
    end
  end

  local function fromBag(bag, slot)
    return ItemLocation:CreateFromBagAndSlot(bag, slot)
  end

  local function fromEquipment()
    return ItemLocation:CreateFromEquipmentSlot(5)
  end

  local function pickups()
    return _G.C_Container._pickups
  end

  before_each(function()
    for _, key in ipairs({ "BAG_KIND", "BACKPACK_BAGS", "BACKPACK_ONLY_REAGENT_BAGS", "BANK_BAGS", "ACCOUNT_BANK_BAGS" }) do
      save(const, key)
    end
    save(_G.Enum.BagIndex, "Keyring")
    save(_G.Enum, "ItemClass")
    save(_G.C_Container, "GetContainerNumFreeSlots")
    save(_G.C_Item, "GetItemInfoInstant")
    save(_G.C_Item, "GetItemInfo")

    -- Enum.ItemClass values from ItemConstantsDocumentation.lua; other specs replace the table.
    _G.Enum.ItemClass = { Container = 1, Armor = 4, Tradegoods = 7, Quiver = 11 }
    const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
    const.BACKPACK_BAGS = { [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 }
    const.BACKPACK_ONLY_REAGENT_BAGS = { [5] = 5 }
    -- -2 is the retail Characterbanktab container: it holds bank bags, never items.
    const.BANK_BAGS = { [-2] = -2, [6] = 6, [7] = 7, [8] = 8 }
    const.ACCOUNT_BANK_BAGS = { [12] = 12, [13] = 13 }
    _G.Enum.BagIndex.Keyring = nil

    families = {}
    itemClasses = {}
    reagents = {}
    _G.C_Container.GetContainerNumFreeSlots = function(bag)
      return #(_G._containerFreeSlots[bag] or {}), families[bag] or 0
    end
    _G.C_Item.GetItemInfoInstant = function(itemID)
      return itemID, nil, nil, nil, nil, itemClasses[itemID] or 4, 0
    end
    _G.C_Item.GetItemInfo = function(itemID)
      return "Item", "[Item]", 1, 1, 0, "Type", "Subtype", 1, "", 1, 0, 0, 0, 0, 0, 0, reagents[itemID] == true
    end

    _G._containerFreeSlots = {}
    _G._itemFamilies = {}
    _G._refundableLocations = {}
    _G.C_Container._pickups = {}
    _G.UIErrorsFrame._messages = {}
    _G.ClearCursor()
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i].tbl[saved[i].key] = saved[i].value
    end
    saved = {}
    _G.ClearCursor()
    _G._itemsAtLocation = {}
  end)

  describe("in the backpack", function()
    it("puts unequipped gear in the backpack's first free slot", function()
      _G._containerFreeSlots = { [0] = { 3, 4 }, [1] = { 1 } }
      holding(1001, fromEquipment())
      assert.are.equal("placed", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({ { bag = 0, slot = 3 } }, pickups())
    end)

    it("uses the next bag when the backpack is full", function()
      _G._containerFreeSlots = { [0] = {}, [2] = { 7 } }
      holding(1001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      assert.are.same({ { bag = 2, slot = 7 } }, pickups())
    end)

    it("reads the free slots when the item is dropped", function()
      _G._containerFreeSlots = { [0] = { 3 } }
      holding(1001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      _G._containerFreeSlots = { [0] = { 4 } }
      holding(1002, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      assert.are.same({ { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }, pickups())
    end)

    it("puts an item in a bag of its family first", function()
      _G._containerFreeSlots = { [0] = { 1 }, [3] = { 2 } }
      families[3] = 32 -- herb bag
      _G._itemFamilies[2001] = 0x200020 -- herbs and alchemy
      holding(2001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      assert.are.same({ { bag = 3, slot = 2 } }, pickups())
    end)

    it("never puts an item in a specialized bag it does not fit", function()
      _G._containerFreeSlots = { [3] = { 2 } }
      families[3] = 32
      holding(1001, fromEquipment())
      assert.are.equal("full", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({}, pickups())
      assert.are.equal(ERR_INV_FULL, _G.UIErrorsFrame._messages[1].text)
      assert.is_true(CursorHasItem())
    end)

    it("puts a crafting reagent in the reagent bag", function()
      _G._containerFreeSlots = { [0] = { 1 }, [5] = { 9 } }
      reagents[3001] = true
      holding(3001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      assert.are.same({ { bag = 5, slot = 9 } }, pickups())
    end)

    it("keeps everything else out of the reagent bag", function()
      _G._containerFreeSlots = { [5] = { 9 } }
      holding(1001, fromEquipment())
      assert.are.equal("full", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({}, pickups())
    end)

    it("stores a bag in a bag that holds anything, not in one of the family it holds", function()
      _G._containerFreeSlots = { [0] = { 1 }, [3] = { 2 } }
      families[3] = 32
      itemClasses[4001] = Enum.ItemClass.Container
      _G._itemFamilies[4001] = 32 -- a herb bag reports the family it holds
      holding(4001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      assert.are.same({ { bag = 0, slot = 1 } }, pickups())
    end)

    it("files a key in the Classic keyring, and nothing else", function()
      _G.Enum.BagIndex.Keyring = -2
      const.BACKPACK_BAGS = { [-2] = -2, [0] = 0 }
      const.BACKPACK_ONLY_REAGENT_BAGS = {}
      _G._containerFreeSlots = { [-2] = { 4 }, [0] = { 1 } }
      _G._itemFamilies[5001] = 256
      holding(5001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      holding(1001, fromEquipment())
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK)
      assert.are.same({ { bag = -2, slot = 4 }, { bag = 0, slot = 1 } }, pickups())
    end)

    it("returns an item picked up from the backpack to its slot", function()
      _G._containerFreeSlots = { [0] = { 3 } }
      holding(1001, fromBag(1, 4))
      assert.are.equal("returned", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({}, pickups())
      assert.is_false(CursorHasItem())
    end)

    it("takes an item from the Warbank into a free slot", function()
      _G._containerFreeSlots = { [0] = { 3 } }
      holding(1001, fromBag(12, 1))
      assert.are.equal("placed", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({ { bag = 0, slot = 3 } }, pickups())
    end)

    it("places an item the client gives no location for", function()
      _G._containerFreeSlots = { [0] = { 3 } }
      holding(1001, nil)
      assert.are.equal("placed", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({ { bag = 0, slot = 3 } }, pickups())
    end)

    it("ignores anything on the cursor but an item", function()
      _G._containerFreeSlots = { [0] = { 3 } }
      _G._cursorHasItem = false
      _G._cursorType = "merchant"
      _G._cursorItemID = 7
      assert.are.equal("ignored", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      _G._cursorType = nil
      assert.are.equal("ignored", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BACKPACK))
      assert.are.same({}, pickups())
      assert.are.same({}, _G.UIErrorsFrame._messages)
    end)
  end)

  describe("in the bank", function()
    it("fills the character bank when it is shown", function()
      _G._containerFreeSlots = { [-2] = {}, [6] = {}, [7] = { 5 }, [12] = { 1 } }
      holding(1001, fromBag(0, 2))
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, -2)
      assert.are.same({ { bag = 7, slot = 5 } }, pickups())
    end)

    it("fills the Warbank when a Warbank tab is shown", function()
      _G._containerFreeSlots = { [6] = { 1 }, [12] = {}, [13] = { 2 } }
      holding(1001, fromBag(0, 2))
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, 12)
      assert.are.same({ { bag = 13, slot = 2 } }, pickups())
    end)

    it("fills the shown tab first", function()
      _G._containerFreeSlots = { [6] = { 1 }, [8] = { 9 } }
      holding(1001, fromBag(0, 2))
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, 8)
      assert.are.same({ { bag = 8, slot = 9 } }, pickups())
    end)

    it("leaves a refundable item for the Warbank's own confirmation", function()
      _G._containerFreeSlots = { [12] = { 1 } }
      _G._refundableLocations["0:2"] = true
      holding(1001, fromBag(0, 2))
      assert.are.equal("ignored", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, 12))
      assert.are.same({}, pickups())
      assert.is_true(CursorHasItem())
    end)

    it("puts a refundable item in the character bank", function()
      _G._containerFreeSlots = { [6] = { 1 } }
      _G._refundableLocations["0:2"] = true
      holding(1001, fromBag(0, 2))
      assert.are.equal("placed", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, -2))
      assert.are.same({ { bag = 6, slot = 1 } }, pickups())
    end)

    it("returns an item picked up from either bank type to its slot", function()
      holding(1001, fromBag(13, 4))
      assert.are.equal("returned", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, -2))
      holding(1001, fromBag(7, 4))
      assert.are.equal("returned", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, 12))
      assert.are.same({}, pickups())
    end)

    it("says the bank is full in the bank's words", function()
      holding(1001, fromBag(0, 2))
      assert.are.equal("full", cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, -2))
      assert.are.equal(ERR_BANK_FULL, _G.UIErrorsFrame._messages[1].text)
    end)

    it("fills a Classic bank's main slots before its bags", function()
      const.BANK_BAGS = { [-1] = -1, [5] = 5, [6] = 6 }
      const.ACCOUNT_BANK_BAGS = {}
      const.BACKPACK_ONLY_REAGENT_BAGS = {}
      _G._containerFreeSlots = { [-1] = { 20 }, [5] = { 1 } }
      holding(1001, fromBag(0, 2))
      cursorPlacement:PlaceCursorItem(const.BAG_KIND.BANK, -1)
      assert.are.same({ { bag = -1, slot = 20 } }, pickups())
    end)
  end)
end)
