local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:Init()

local ctx = addon:GetModule("Context")

-- Stub standard dependencies
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end

local database = StubBetterBagsModule("Database")
database.GetItemLevelOptions = function() return { color = true, enabled = true } end
database.GetStackingOptions = function() return { mergeUnstackable = false } end
database.GetShowAllFreeSpace = function() return false end
database.GetGlowIntensity = function() return 60 end

local color = StubBetterBagsModule("Color")
color.GetItemLevelColor = function() return 1, 1, 1 end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.BACKPACK_BAGS = { [0] = true, [1] = true }
const.BANK_BAGS = { [5] = true }
const.ITEM_QUALITY = { Common = 1, Uncommon = 2 }
const.ITEM_QUALITY_COLOR = {
  [0] = { 0.62, 0.62, 0.62, 1 },
  [1] = { 1, 1, 1, 1 },
  [2] = { 0.12, 1, 0, 1 },
  [3] = { 0, 0.44, 0.87, 1 },
  [4] = { 0.64, 0.21, 0.93, 1 },
}
const.GLOW_INTENSITY_HALO_THRESHOLD = 60
const.GLOW_INTENSITY_MAX = 100
const.GLOW_INTENSITY_DEFAULT = 60
const.BACKPACK_ONLY_REAGENT_BAGS = {}

local items = StubBetterBagsModule("Items")
items.GetSlotKeyFromBagAndSlot = function(_, bagid, slotid)
  -- Support both method colon and normal dot calling syntax if needed
  if type(bagid) == "table" then
    bagid, slotid = slotid, nil
  end
  return bagid .. "_" .. slotid
end
items.GetStackData = function() return nil end
items.IsNewItem = function() return false end

-- Sonata: the theme generation in every draw record, and the elements it styles. When the
-- real modules are loaded already (an earlier spec file), what is replaced here is put back
-- in the teardown; stubs this file made are removed.
local sonata, createdSonata = StubBetterBagsModule("Sonata")
local elements, createdElements = StubBetterBagsModule("SonataElements")
local replaced = {}
local function replace(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
replace(sonata, "generation", 0)
replace(sonata, "registered", {})
replace(sonata, "GetGeneration", function(self) return self.generation end)
replace(sonata, "RegisterElement", function(self, kind, element) table.insert(self.registered, { kind, element }) end)
-- By default the theme draws neither quality nor quest art.
replace(elements, "DrawItemQuality", function() return false end)
replace(elements, "DrawItemQuest", function() end)

-- newDecoration builds what ContainerFrameItemButtonTemplate gives an item's decoration.
local function newDecoration(item)
  do
    item._decoration = {
      SetSize = function() end,
      SetID = function(_, id) item._decoration.id = id end,
      GetID = function() return item._decoration.id end,
      GetBagID = function() return item._decoration.bagID end,
      SetMatchesSearch = function() end,
      ItemSlotBackground = { Hide = function() end, Show = function() end },
      IconBorder = { SetTexture = function() end, SetBlendMode = function() end, SetTexCoord = function() end, SetSize = function() end, SetVertexColor = function() end, Show = function() end, Hide = function() end },
      NormalTexture = { SetSize = function() end },
      IconQuestTexture = { SetSize = function() end },
      IconTexture = { SetSize = function() end },
      IconOverlay = { SetSize = function() end },
      UpgradeIcon = { SetShown = function() end },
      BattlepayItemTexture = { Hide = function() end },
      NewItemTexture = { Hide = function() end, Show = function() end, SetAtlas = function() end },
      flashAnim = { IsPlaying = function() return false end, Play = function() end, Stop = function() end },
      newitemglowAnim = { IsPlaying = function() return false end, Play = function() end, Stop = function() end },
      SetHasItem = function() end,
      SetItemButtonTexture = function() end,
      UpdateExtended = function() end,
      UpdateQuestItem = function() end,
      UpdateNewItem = function() end,
      UpdateJunkItem = function() end,
      UpdateItemContextMatching = function() end,
      UpdateCooldown = function() end,
      SetReadable = function() end,
      CheckUpdateTooltip = function() end,
      SetFrameLevel = function(_, level)
        if not level or type(level) ~= "number" or level < 0 or level > 65535 then
          error("bad argument #1 to 'SetFrameLevel' (outside of expected range 0 to 65535 - Usage: self:SetFrameLevel(frameLevel))", 2)
        end
        item._decoration._frameLevel = level
      end,
      CreateTexture = function(_, _, layer)
        return {
          _shown = false,
          _layer = layer,
          SetTexture = function(t, path) t._texture = path end,
          SetAtlas = function(t, atlas) t._atlas = atlas end,
          SetSize = function(t, w, h) t._w, t._h = w, h end,
          SetPoint = function() end,
          SetAlpha = function(t, a) t._alpha = a end,
          SetTexCoord = function() end,
          Show = function(t) t._shown = true end,
          Hide = function(t) t._shown = false end,
          SetShown = function(t, s) t._shown = not not s end,
        }
      end,
    }
  end
  return item._decoration
end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

-- A fresh frames/item.lua: a copy an earlier spec file loaded holds that file's Sonata stubs,
-- not the ones above. Removed again in the teardown.
local itemFrame = LoadFreshBetterBagsModule("ItemFrame", "frames/item.lua")
itemFrame.CreateDecoration = function(_, item) return newDecoration(item) end

describe("ItemFrame Static Buttons and Parent Removal Tests", function()
  before_each(function()
    addon.isRetail = true
    _G.ClearItemButtonOverlay = _G.ClearItemButtonOverlay or function() end
    _G.SetItemButtonQuality = _G.SetItemButtonQuality or function() end
    _G.SetItemButtonCount = _G.SetItemButtonCount or function() end
    _G.SetItemButtonDesaturated = _G.SetItemButtonDesaturated or function() end
    _G.GameTooltip.GetOwner = _G.GameTooltip.GetOwner or function() return nil end
    itemFrame:Init()
  end)

  describe("decoration", function()
    local btnCtx, originalSend, sent

    before_each(function()
      btnCtx = ctx:New("decoration")
      sonata.registered = {}
      sent = {}
      originalSend = events.SendMessage
      events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    end)

    after_each(function()
      events.SendMessage = originalSend
      elements.DrawItemQuality = function() return false end
      elements.DrawItemQuest = function() end
    end)

    local function potion(fields)
      local data = {
        slotkey = "0_9", bagid = 0, slotid = 9, isItemEmpty = false,
        questInfo = { isQuestItem = false, isActive = false },
        containerInfo = {},
        itemInfo = { itemID = 1, itemIcon = 1, itemQuality = 3, itemLink = "item:1", currentItemCount = 1, classID = 0,
          currentItemLevel = 1 },
      }
      for k, v in pairs(fields or {}) do data[k] = v end
      return data
    end

    it("is made once, styled by Sonata as an ItemButton, and announced", function()
      local item = itemFrame:GetButton(btnCtx, "0_9")
      local decoration = item:GetDecoration(btnCtx)
      assert.are.equal(decoration, item:GetDecoration(btnCtx))
      local count = 0
      for _, entry in ipairs(sonata.registered) do
        if entry[2] == decoration then
          count = count + 1
          assert.are.equal("ItemButton", entry[1])
        end
      end
      assert.are.equal(1, count)
      local announced = 0
      for _, entry in ipairs(sent) do
        if entry[1] == "item/NewButton" and entry[3] == decoration then announced = announced + 1 end
      end
      assert.are.equal(1, announced)
    end)

    it("lets the theme draw quality on its border, and draws BetterBags' glow otherwise", function()
      local item = itemFrame:GetButton(btnCtx, "0_9")
      local seen, glows = {}, 0
      local glow = item.DrawQualityGlow
      item.DrawQualityGlow = function() glows = glows + 1 end
      elements.DrawItemQuality = function(_, decoration, qualityColor, quality)
        table.insert(seen, { decoration, qualityColor, quality })
        return true
      end
      item:SetItemFromData(btnCtx, potion())
      assert.are.equal(0, glows)
      local last = seen[#seen]
      assert.are.equal(item._decoration, last[1])
      assert.are.same(const.ITEM_QUALITY_COLOR[3], last[2])
      assert.are.equal(3, last[3])
      elements.DrawItemQuality = function() return false end
      sonata.generation = sonata.generation + 1
      item:SetItemFromData(btnCtx, potion())
      assert.are.equal(1, glows)
      item.DrawQualityGlow = glow
    end)

    it("gives the theme no quality color for common and poor items", function()
      local item = itemFrame:GetButton(btnCtx, "0_9")
      local colors = {}
      elements.DrawItemQuality = function(_, _, qualityColor) table.insert(colors, qualityColor or "none") return true end
      local data = potion()
      data.itemInfo.itemQuality = 1
      item:SetItemFromData(btnCtx, data)
      assert.are.equal("none", colors[#colors])
    end)

    it("hands the theme the item's quest data after Blizzard draws it", function()
      local item = itemFrame:GetButton(btnCtx, "0_9")
      local got
      elements.DrawItemQuest = function(_, decoration, questInfo) got = { decoration, questInfo } end
      local data = potion({ questInfo = { isQuestItem = true, questID = 7, isActive = false } })
      item:SetItemFromData(btnCtx, data)
      assert.are.equal(item._decoration, got[1])
      assert.are.equal(data.questInfo, got[2])
    end)

    it("draws again in full after a theme is applied", function()
      local item = itemFrame:GetButton(btnCtx, "0_9")
      item:SetItemFromData(btnCtx, potion())
      assert.is_nil(item:DrawInputChanged(item._decoration, potion()))
      sonata.generation = sonata.generation + 1
      assert.are.equal("decorationGeneration", item:DrawInputChanged(item._decoration, potion()))
    end)
  end)

  it("should create buttonsBySlotkey table on Init", function()
    assert.is_table(itemFrame.buttonsBySlotkey)
  end)

  it("should lazily look up and create a physical slot button on GetButton", function()
    local btnCtx = ctx:New("test")
    local item = itemFrame:GetButton(btnCtx, "0_1")
    assert.is_table(item)
    assert.equal(item, itemFrame.buttonsBySlotkey["0_1"])
    assert.equal(item.button:GetID(), 1)
    assert.equal(item.button.bagID, 0)
    assert.equal(item.slotkey, "0_1")

    -- Subsequent lookups should return the exact same instance
    local item2 = itemFrame:GetButton(btnCtx, "0_1")
    assert.equal(item, item2)
  end)

  it("should create virtual button for non-physical slotkeys", function()
    local btnCtx = ctx:New("test")
    local item = itemFrame:GetButton(btnCtx, "Container")
    assert.is_table(item)
    assert.equal(item, itemFrame.buttonsBySlotkey["Container"])
    assert.equal(item.slotkey, "Container")
  end)

  -- Every item button must exist from boot: creating one later can taint. A capture of
  -- opening the bank on retail created 265 buttons at runtime, all character bank tab slots
  -- 41-98 (tabs hold 98 slots; boot made 40 for them and 98 for Warbank tabs).
  describe("buttons created at boot", function()
    local savedBankOnly, savedAccount

    before_each(function()
      savedBankOnly, savedAccount = const.BANK_ONLY_BAGS, const.ACCOUNT_BANK_BAGS
    end)

    after_each(function()
      const.BANK_ONLY_BAGS, const.ACCOUNT_BANK_BAGS = savedBankOnly, savedAccount
      addon.isRetail = true
    end)

    it("creates every slot of a retail character bank tab, up to 98", function()
      addon.isRetail = true
      const.BANK_ONLY_BAGS = { [6] = 6 }
      const.ACCOUNT_BANK_BAGS = { [12] = 12 }
      itemFrame:Init()
      itemFrame:OnEnable()
      local created = 0
      local origDoCreate = itemFrame._DoCreate
      itemFrame._DoCreate = function(...)
        created = created + 1
        return origDoCreate(...)
      end
      local btnCtx = ctx:New("boot")
      itemFrame:GetButton(btnCtx, "6_41")
      itemFrame:GetButton(btnCtx, "6_98")
      itemFrame:GetButton(btnCtx, "12_98")
      itemFrame._DoCreate = origDoCreate
      assert.equal(0, created, "no bank tab slot is created after boot")
    end)

    it("keeps 40 slots per bank bag on Classic", function()
      addon.isRetail = false
      const.BANK_ONLY_BAGS = { [6] = 6 }
      const.ACCOUNT_BANK_BAGS = nil
      itemFrame:Init()
      itemFrame:OnEnable()
      assert.is_not_nil(itemFrame.buttonsBySlotkey["5_40"])
      assert.is_nil(itemFrame.buttonsBySlotkey["5_41"])
      assert.is_nil(itemFrame.buttonsBySlotkey["6_41"])
    end)
  end)

  describe("Virtual Item Button Pool Architecture", function()
    it("should pre-allocate virtual item buttons during OnEnable", function()
      itemFrame:Init()
      assert.equal(0, #itemFrame.virtualPool)
      itemFrame:OnEnable()
      assert.is_true(#itemFrame.virtualPool >= 20)
    end)

    it("should acquire virtual button from pool without calling Create during GetButton", function()
      itemFrame:Init()
      itemFrame:OnEnable()
      local poolCountBefore = #itemFrame.virtualPool
      local createCalled = false
      local origDoCreate = itemFrame._DoCreate
      itemFrame._DoCreate = function(...)
        createCalled = true
        return origDoCreate(...)
      end

      local btnCtx = ctx:New("test_virtual_pool")
      local item = itemFrame:GetButton(btnCtx, "Reagent Bag")

      assert.is_false(createCalled, "_DoCreate should NOT be called during GetButton for virtual slotkeys when pool has pre-allocated buttons")
      assert.equal("Reagent Bag", item.slotkey)
      assert.is_true(item.isVirtual)
      assert.equal(#itemFrame.virtualPool, poolCountBefore - 1)

      itemFrame._DoCreate = origDoCreate
    end)

    it("should release virtual button back to pool on Wipe or Release", function()
      itemFrame:Init()
      itemFrame:OnEnable()

      local btnCtx = ctx:New("test_virtual_release")
      local item = itemFrame:GetButton(btnCtx, "Container")
      assert.equal("Container", item.slotkey)
      assert.equal(item, itemFrame.buttonsBySlotkey["Container"])

      local poolCountBeforeWipe = #itemFrame.virtualPool
      item:Wipe(btnCtx)

      assert.is_nil(itemFrame.buttonsBySlotkey["Container"])
      assert.equal(#itemFrame.virtualPool, poolCountBeforeWipe + 1)
    end)

    -- A full teardown (bag:Wipe, DeleteTabView) can release a button the next draw's
    -- sweep then also finds unclaimed; a virtual button must still enter its pool once.
    it("returns a virtual button to the pool only once, however often it is released", function()
      itemFrame:Init()
      itemFrame:OnEnable()
      local btnCtx = ctx:New("test_virtual_double_release")
      local item = itemFrame:GetButton(btnCtx, "Container")
      local before = #itemFrame.virtualPool
      item:Release(btnCtx)
      item:Release(btnCtx)
      item:Wipe(btnCtx)
      assert.equal(before + 1, #itemFrame.virtualPool)
    end)

    it("releases a virtual button again after it is acquired from the pool again", function()
      itemFrame:Init()
      itemFrame:OnEnable()
      local btnCtx = ctx:New("test_virtual_reacquire")
      local item = itemFrame:GetButton(btnCtx, "Container")
      item:Release(btnCtx)
      local again = itemFrame:GetButton(btnCtx, "Reagent Bag")
      assert.equal(item, again, "the pool hands back the button just released")
      local before = #itemFrame.virtualPool
      again:Release(btnCtx)
      assert.equal(before + 1, #itemFrame.virtualPool)
      assert.is_nil(itemFrame.buttonsBySlotkey["Reagent Bag"])
    end)
  end)

  it("releases a physical button again only after it has been drawn again", function()
    local btnCtx = ctx:New("test_release_rearm")
    local item = itemFrame:GetButton(btnCtx, "0_12")
    local hides = 0
    local hide = item.frame.Hide
    item.frame.Hide = function(self)
      hides = hides + 1
      return hide(self)
    end
    item:Release(btnCtx)
    local afterFirst = hides
    item:Release(btnCtx)
    assert.equal(afterFirst, hides, "a second release of an undrawn button does nothing")

    item:SetFreeSlots(btnCtx, { bagid = 0, slotid = 12, slotkey = "0_12", itemInfo = { emptySlotName = "Bag" } }, 1)
    item:Release(btnCtx)
    assert.is_true(hides > afterFirst)
  end)

  it("should use a permanent parent frame for the bag as i.frame", function()
    local btnCtx = ctx:New("test")
    local item = itemFrame:GetButton(btnCtx, "0_2")
    assert.not_nil(item.frame)
    assert.not_equal(item.frame, item.button)
    assert.equal(item.button:GetParent(), item.frame)
    assert.equal(item.frame:GetID(), 0)
    assert.is_function(item.frame.IsCombinedBagContainer)
    assert.is_false(item.frame:IsCombinedBagContainer())
  end)

  it("should clamp frame level to 0 and not throw an error after the fix", function()
    local btnCtx = ctx:New("test")
    local item = itemFrame:GetButton(btnCtx, "0_2")

    -- Set physical button's frame level to 0
    item.button:SetFrameLevel(0)

    -- Setup mock items data return
    local itemData = {
      slotkey = "0_2",
      bagid = 0,
      slotid = 2,
      isItemEmpty = false,
      questInfo = {
        isQuestItem = false,
        questID = nil,
        isActive = false,
      },
      containerInfo = {
        isReadable = false,
        isFiltered = false,
        hasNoValue = false,
      },
      itemInfo = {
        isBound = false,
        itemID = 12345,
        itemIcon = 136235,
        itemQuality = 2,
        itemLink = "item:12345",
      }
    }

    items.GetItemDataFromSlotKey = function(_, slotkey)
      if slotkey == "0_2" then
        return itemData
      end
    end

    -- This call should succeed
    item:SetItemFromData(btnCtx, itemData)

    -- And the decoration frame level should be 0
    assert.equal(item._decoration._frameLevel, 0)
  end)

  it("should call UpdateExtended on both self.button and decoration during SetItemFromData", function()
    local btnCtx = ctx:New("test_update_extended_set_item")
    local item = itemFrame:GetButton(btnCtx, "0_3")

    -- Set up tracking
    local buttonUpdateExtendedCalled = 0
    item.button.UpdateExtended = function()
      buttonUpdateExtendedCalled = buttonUpdateExtendedCalled + 1
    end

    local decUpdateExtendedCalled = 0
    item._decoration.UpdateExtended = function()
      decUpdateExtendedCalled = decUpdateExtendedCalled + 1
    end

    -- Setup mock items data return
    local itemData = {
      slotkey = "0_3",
      bagid = 0,
      slotid = 3,
      isItemEmpty = false,
      questInfo = {
        isQuestItem = false,
        questID = nil,
        isActive = false,
      },
      containerInfo = {
        isReadable = false,
        isFiltered = false,
        hasNoValue = false,
      },
      itemInfo = {
        isBound = false,
        itemID = 12345,
        itemIcon = 136235,
        itemQuality = 2,
        itemLink = "item:12345",
      }
    }

    items.GetItemDataFromSlotKey = function(_, slotkey)
      if slotkey == "0_3" then
        return itemData
      end
    end

    item:SetItemFromData(btnCtx, itemData)

    -- Assert that UpdateExtended was called on both
    assert.equal(1, buttonUpdateExtendedCalled, "button:UpdateExtended was not called on SetItemFromData")
    assert.equal(1, decUpdateExtendedCalled, "decoration:UpdateExtended was not called on SetItemFromData")
  end)

  it("should call UpdateExtended on both self.button and decoration during SetFreeSlots", function()
    local btnCtx = ctx:New("test_update_extended_free_slots")
    local item = itemFrame:GetButton(btnCtx, "0_4")

    -- Set up tracking
    local buttonUpdateExtendedCalled = 0
    item.button.UpdateExtended = function()
      buttonUpdateExtendedCalled = buttonUpdateExtendedCalled + 1
    end

    local decUpdateExtendedCalled = 0
    item._decoration.UpdateExtended = function()
      decUpdateExtendedCalled = decUpdateExtendedCalled + 1
    end

    local itemData = {
      bagid = 0,
      slotid = 4,
      slotkey = "0_4",
      itemInfo = {
        emptySlotName = "Backpack",
        itemQuality = 1,
      }
    }
    item:SetFreeSlots(btnCtx, itemData, 1, false)

    -- Assert that UpdateExtended was called on both
    assert.equal(1, buttonUpdateExtendedCalled, "button:UpdateExtended was not called on SetFreeSlots")
    assert.equal(1, decUpdateExtendedCalled, "decoration:UpdateExtended was not called on SetFreeSlots")
  end)

  it("should preserve the slotkey when Wipe or ClearItem is called", function()
    local btnCtx = ctx:New("test_wipe_preserves_slotkey")
    local item = itemFrame:GetButton(btnCtx, "0_5")
    assert.equal("0_5", item.slotkey)
    item:Wipe(btnCtx)
    assert.equal("0_5", item.slotkey)
  end)

  describe("Phase 5: Decoupled Item Button Drawing", function()
    local btnCtx
    local item

    before_each(function()
      btnCtx = ctx:New("phase5_test")
      item = itemFrame:GetButton(btnCtx, "0_6")
      _G.NEW_ITEM_ATLAS_BY_QUALITY = _G.NEW_ITEM_ATLAS_BY_QUALITY or { [1] = "bags-glow-white", [2] = "bags-glow-green" }
      _G.Enum = _G.Enum or {}
      _G.Enum.ItemClass = _G.Enum.ItemClass or {}
      _G.Enum.ItemClass.Armor = _G.Enum.ItemClass.Armor or 4
      _G.SetItemButtonCountCalled = nil
      _G.SetItemButtonCountVal = nil
      _G.SetItemButtonCount = function(_, count)
        _G.SetItemButtonCountCalled = true
        _G.SetItemButtonCountVal = count
      end
    end)

    it("SetItemFromData should pass pre-computed isSearchResult to SetMatchesSearch", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        isItemEmpty = false,
        isSearchResult = false,
        questInfo = { isQuestItem = false },
        containerInfo = { isReadable = false, isFiltered = false, hasNoValue = false },
        itemInfo = { isBound = false, itemID = 12345, itemIcon = 136235, itemQuality = 2, itemLink = "item:12345" },
      }
      local searchMatched = nil
      item._decoration.SetMatchesSearch = function(_, matched)
        searchMatched = matched
      end
      item:SetItemFromData(btnCtx, itemData)
      assert.is_false(searchMatched)
    end)

    -- A button drawn in consecutive passes is no longer released in between, so the
    -- reset a release used to do runs only when the button changes what it shows (item,
    -- free slot, empty slot). Same-kind redraws set every visual themselves.
    -- BAG_UPDATE_COOLDOWN refreshes (bag:OnCooldown) ask the client for each button's
    -- cooldown and skip Blizzard's update (spiral, icon tint, has-item) when it matches
    -- what that button last applied. Full draws always apply.
    describe("cooldown refresh", function()
      local applied
      local function potion()
        return {
          slotkey = "0_6", bagid = 0, slotid = 6, isItemEmpty = false,
          questInfo = { isQuestItem = false },
          containerInfo = { isReadable = false, isFiltered = false, hasNoValue = false },
          itemInfo = { isBound = false, itemID = 5512, itemIcon = 135230, itemQuality = 1,
            itemLink = "item:5512", currentItemCount = 3, classID = 0, currentItemLevel = 1 },
        }
      end

      before_each(function()
        applied = 0
        _G._containerCooldowns = {}
        sonata.generation = 0
        item:SetItemFromData(btnCtx, potion())
        item._decoration.UpdateCooldown = function() applied = applied + 1 end
      end)

      after_each(function()
        _G._containerCooldowns = {}
        sonata.generation = 0
      end)

      it("skips a refresh when the cooldown is unchanged since it was applied", function()
        item:UpdateCooldown(btnCtx, potion(), true)
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(0, applied)
      end)

      it("applies when the client reports a different cooldown", function()
        _G._containerCooldowns["0_6"] = { 100, 60, 1 }
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(1, applied)
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(1, applied)
        _G._containerCooldowns["0_6"] = { 100, 60, 0 }
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(2, applied)
        _G._containerCooldowns["0_6"] = { 100, 90, 0 }
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(3, applied)
        _G._containerCooldowns["0_6"] = { 200, 90, 0 }
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(4, applied)
        _G._containerCooldowns["0_6"] = nil
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(5, applied)
      end)

      it("applies when the icon, the theme or the decoration changed", function()
        local other = potion()
        other.itemInfo.itemIcon = 1
        item:UpdateCooldown(btnCtx, other, true)
        assert.equal(1, applied)

        sonata.generation = 1
        item:UpdateCooldown(btnCtx, other, true)
        assert.equal(2, applied)

        local old = item._decoration
        item._decoration = nil
        item:GetDecoration(btnCtx)
        item._decoration.id, item._decoration.bagID = old.id, old.bagID
        item._decoration.UpdateCooldown = function() applied = applied + 1 end
        item:UpdateCooldown(btnCtx, other, true)
        assert.equal(3, applied)
        item._decoration = old
      end)

      it("always applies on a full draw or a call that does not ask to skip", function()
        item:UpdateCooldown(btnCtx, potion())
        assert.equal(1, applied)
        local changed = potion()
        changed.itemInfo.currentItemCount = 2
        item:SetItemFromData(btnCtx, changed)
        assert.equal(2, applied)
      end)

      it("applies again after the button was released", function()
        item:Release(btnCtx)
        item:SetItemFromData(btnCtx, potion())
        applied = 0
        item.cooldownState.valid = false
        item:UpdateCooldown(btnCtx, potion(), true)
        assert.equal(1, applied)

        item:Release(btnCtx)
        assert.is_false(item.cooldownState.valid)
      end)

      it("applies again after the button showed a free slot", function()
        item:SetFreeSlots(btnCtx, { bagid = 0, slotid = 6, slotkey = "0_6", itemInfo = { emptySlotName = "Bag" } }, 1)
        assert.is_false(item.cooldownState.valid)
      end)

      it("never skips an item row", function()
        item.staticData = potion()
        item:UpdateCooldown(btnCtx, potion(), true)
        item:UpdateCooldown(btnCtx, potion(), true)
        item.staticData = nil
        assert.equal(2, applied)
      end)

      it("skips the same way on Classic, which updates through ContainerFrame_UpdateCooldown", function()
        local saved = _G.ContainerFrame_UpdateCooldown
        local classicApplied = 0
        _G.ContainerFrame_UpdateCooldown = function() classicApplied = classicApplied + 1 end
        item._decoration.UpdateCooldown = nil
        item:UpdateCooldown(btnCtx, potion())
        item:UpdateCooldown(btnCtx, potion(), true)
        _G._containerCooldowns["0_6"] = { 100, 60, 1 }
        item:UpdateCooldown(btnCtx, potion(), true)
        _G.ContainerFrame_UpdateCooldown = saved
        assert.equal(2, classicApplied)
      end)
    end)

    describe("redrawing without a release", function()
      local function fullItem(count)
        return {
          slotkey = "0_6", bagid = 0, slotid = 6, isItemEmpty = false, stackedCount = count,
          questInfo = { isQuestItem = false },
          containerInfo = { isReadable = false, isFiltered = false, hasNoValue = false },
          itemInfo = { isBound = false, itemID = 12345, itemIcon = 136235, itemQuality = 2,
            itemLink = "item:12345", currentItemCount = count, classID = 0 },
        }
      end

      local function countResets()
        local resets = 0
        local original = itemFrame.itemProto.ResetVisuals
        itemFrame.itemProto.ResetVisuals = function(self, c)
          resets = resets + 1
          return original(self, c)
        end
        return function()
          itemFrame.itemProto.ResetVisuals = original
          return resets
        end
      end

      it("does not reset a button that shows an item again", function()
        item:SetItemFromData(btnCtx, fullItem(3))
        local done = countResets()
        item:SetItemFromData(btnCtx, fullItem(9))
        assert.equal(0, done())
        assert.equal(9, _G.SetItemButtonCountVal)
      end)

      -- A release already reset the button (ClearItem runs ResetVisuals). Captures of Show
      -- Bags and of bank tab switches showed every button reset twice: once on release and
      -- again on its next draw (146 and 465 resets).
      it("does not reset a released button again on its next draw", function()
        local free = { slotkey = "0_6", bagid = 0, slotid = 6, isItemEmpty = true,
          itemInfo = { emptySlotName = "Bag" } }
        item:SetItemFromData(btnCtx, fullItem(3))
        local done = countResets()
        item:Release(btnCtx)
        item:SetFreeSlots(btnCtx, free, 1)
        assert.equal(1, done(), "the release resets; the draw does not")

        item:SetFreeSlots(btnCtx, free, 1)
        done = countResets()
        item:Release(btnCtx)
        item:SetItemFromData(btnCtx, fullItem(3))
        assert.equal(1, done())
      end)

      -- Anything that changes the button's look after its release (a lock, a search, a
      -- cooldown) means it is no longer blank, so its next draw resets it.
      for _, case in ipairs({
        { "locked", function() item:Lock(btnCtx) end },
        { "searched", function() item:UpdateSearch(btnCtx, false) end },
        { "faded", function() item:SetAlpha(0.5) end },
      }) do
        it("resets a released button that was " .. case[1] .. " before its next draw", function()
          item:SetItemFromData(btnCtx, fullItem(3))
          item:Release(btnCtx)
          case[2]()
          local done = countResets()
          item:SetFreeSlots(btnCtx, { slotkey = "0_6", bagid = 0, slotid = 6, isItemEmpty = true,
            itemInfo = { emptySlotName = "Bag" } }, 1)
          assert.equal(1, done())
        end)
      end

      it("resets the button like a release when its slot is drawn empty", function()
        item:SetItemFromData(btnCtx, fullItem(7))
        local done = countResets()
        item:SetItemFromData(btnCtx, { slotkey = "0_6", bagid = 0, slotid = 6, isItemEmpty = true,
          itemInfo = {} })
        assert.equal(1, done())
        assert.equal(0, _G.SetItemButtonCountVal)
      end)

      -- A redraw whose drawn inputs are identical to the last draw skips every setter:
      -- the signature is the item's itemHash plus its link and each field SetItemFromData
      -- reads, plus the data phase's draw generation (bumped by every wipe sweep, which is
      -- how settings changes reach the buttons) and the theme's decoration generation.
      describe("skipping a redraw whose inputs are unchanged", function()
        local fullDraws

        local function data(changes)
          local d = fullItem(4)
          d.itemHash = "hash-12345"
          d.drawGeneration = 1
          d.isUpgrade = false
          d.itemContextMatchResult = 1
          d.questInfo.isActive = false
          d.itemInfo.isNewItem = false
          d.itemInfo.isBattlePayItem = false
          d.itemInfo.currentItemLevel = 100
          for _, change in ipairs(changes or {}) do change(d) end
          return d
        end

        before_each(function()
          fullDraws = 0
          sonata.generation = 0
          item:SetItemFromData(btnCtx, data())
          -- Only a full item draw calls SetReadable (ResetVisuals does not).
          item._decoration.SetReadable = function() fullDraws = fullDraws + 1 end
        end)

        after_each(function()
          sonata.generation = 0
        end)

        it("skips the setters but still points the button at the new data", function()
          local again = data()
          item:SetItemFromData(btnCtx, again)
          assert.equal(0, fullDraws)
          assert.equal(again, item.currentData)
          assert.equal(again, item._decoration._itemData)
          assert.is_false(item.released)
        end)

        local changes = {
          { "stacked count", function(d) d.stackedCount = 5 end },
          { "count without a stack", function(d) d.stackedCount = nil; d.itemInfo.currentItemCount = 9 end },
          { "new item", function(d) d.itemInfo.isNewItem = true end },
          { "battle pay", function(d) d.itemInfo.isBattlePayItem = true end },
          { "quest item", function(d) d.questInfo.isQuestItem = true end },
          { "quest id", function(d) d.questInfo.questID = 77 end },
          { "active quest", function(d) d.questInfo.isActive = true end },
          { "readable", function(d) d.containerInfo.isReadable = true end },
          { "filtered", function(d) d.containerInfo.isFiltered = true end },
          { "no value", function(d) d.containerInfo.hasNoValue = true end },
          { "bound", function(d) d.itemInfo.isBound = true end },
          { "search match", function(d) d.isSearchResult = false end },
          { "upgrade", function(d) d.isUpgrade = true end },
          { "context match", function(d) d.itemContextMatchResult = 2 end },
          { "item hash", function(d) d.itemHash = "hash-other" end },
          { "item link", function(d) d.itemInfo.itemLink = "item:12345:0:0:0:0:0:0:0:0:0:0:0:1:9999" end },
          { "icon", function(d) d.itemInfo.itemIcon = 1 end },
          { "quality", function(d) d.itemInfo.itemQuality = 4 end },
          { "item level", function(d) d.itemInfo.currentItemLevel = 200 end },
          { "item class", function(d) d.itemInfo.classID = 4 end },
          { "draw generation", function(d) d.drawGeneration = 2 end },
        }
        for _, change in ipairs(changes) do
          it("redraws when the " .. change[1] .. " changes", function()
            item:SetItemFromData(btnCtx, data({ change[2] }))
            assert.equal(1, fullDraws)
          end)
        end

        it("redraws after a theme is applied", function()
          sonata.generation = 1
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws)
        end)

        -- The profiler's call trace records this method's return value for every draw, which
        -- is how a capture shows why a button redrew (data-driven.md).
        it("names the input that changed, and nothing when the redraw can be skipped", function()
          local decoration = item._decoration
          assert.is_nil(item:DrawInputChanged(decoration, data()))
          local named = {
            { function(d) d.stackedCount = 5 end, "shownCount" },
            { function(d) d.itemInfo.isNewItem = true end, "isNewItem" },
            { function(d) d.isUpgrade = true end, "isUpgrade" },
            { function(d) d.itemContextMatchResult = 2 end, "itemContextMatchResult" },
            { function(d) d.drawGeneration = 2 end, "drawGeneration" },
            { function(d) d.isSearchResult = false end, "matches" },
            { function(d) d.itemHash = "hash-other" end, "itemHash" },
          }
          for _, case in ipairs(named) do
            assert.equal(case[2], item:DrawInputChanged(decoration, data({ case[1] })))
          end
          sonata.generation = 1
          assert.equal("decorationGeneration", item:DrawInputChanged(decoration, data()))
          sonata.generation = 0
          itemFrame:RestyleButtons()
          assert.equal("styleGeneration", item:DrawInputChanged(decoration, data()))
        end)

        -- A capture of Show Bags (which turns stacking off) showed all 32 item buttons drawn in
        -- both views redrawn on each toggle with "stackedCount": a single pile records its own
        -- count as the stack total in the normal view and none in Show Bags, the same number shown.
        it("skips a redraw when the stack total goes away but the count shown is the same", function()
          item:SetItemFromData(btnCtx, data({ function(d) d.stackedCount = nil end }))
          assert.equal(0, fullDraws)
        end)

        it("redraws when a stack starts or stops hiding an armor or weapon piece's level", function()
          local function armor(d)
            d.itemInfo.classID = Enum.ItemClass.Armor
            d.itemInfo.currentItemCount = 2
            d.stackedCount = nil
          end
          item:SetItemFromData(btnCtx, data({ armor }))
          fullDraws = 0
          assert.equal("stackHidesLevel", item:DrawInputChanged(item._decoration,
            data({ armor, function(d) d.stackedCount = 2 end })))
        end)

        it("names a missing record after the button was locked", function()
          item:Lock(btnCtx)
          assert.equal("record", item:DrawInputChanged(item._decoration, data()))
        end)

        -- Settings that only change how buttons draw (glow intensity, item level display)
        -- reach the buttons through a redraw with no new data, so they restyle the buttons.
        it("redraws once after the buttons were restyled", function()
          itemFrame:RestyleButtons()
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws)
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws, "the next redraw skips again")
        end)

        it("redraws after the live search dimmed the button, not after it applied the same match", function()
          item:UpdateSearch(btnCtx, true)
          item:SetItemFromData(btnCtx, data())
          assert.equal(0, fullDraws)
          item:UpdateSearch(btnCtx, false)
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws)
        end)

        it("redraws after the button was locked", function()
          item:Lock(btnCtx)
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws)
        end)

        it("replays the new-item animation on a skipped redraw", function()
          local isNew = function(d) d.itemInfo.isNewItem = true end
          item:SetItemFromData(btnCtx, data({ isNew }))
          fullDraws = 0
          local updates = 0
          item.UpdateNewItem = function() updates = updates + 1 end
          item:SetItemFromData(btnCtx, data({ isNew }))
          item.UpdateNewItem = nil
          assert.equal(0, fullDraws)
          assert.equal(1, updates)
        end)

        it("never skips an item row's static draw", function()
          item:SetStaticItemFromData(btnCtx, data())
          item:SetStaticItemFromData(btnCtx, data())
          item.staticData = nil
          assert.equal(2, fullDraws)
        end)


        it("redraws when the decoration is a different object", function()
          local old = item._decoration
          item._decoration = nil
          item:GetDecoration(btnCtx)
          item._decoration.SetReadable = function() fullDraws = fullDraws + 1 end
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws)
          item._decoration = old
        end)

        it("redraws a button that was released since its last draw", function()
          item:Release(btnCtx)
          fullDraws = 0
          item:SetItemFromData(btnCtx, data())
          assert.equal(1, fullDraws)
        end)

        it("still clears the classic slot texture on a skipped redraw", function()
          addon.isRetail = false
          local cleared = 0
          local normal = item.button:GetNormalTexture()
          local setTexture = normal.SetTexture
          normal.SetTexture = function(self, path)
            if path == nil then cleared = cleared + 1 end
            return setTexture(self, path)
          end
          item:SetItemFromData(btnCtx, data())
          addon.isRetail = true
          normal.SetTexture = setTexture
          assert.equal(0, fullDraws)
          assert.equal(1, cleared)
        end)
      end)

      describe("skipping a free-slot redraw whose inputs are unchanged", function()
        local fullDraws

        local function slot(changes)
          local d = { bagid = 0, slotid = 6, slotkey = "0_6",
            itemInfo = { emptySlotName = "Bag", emptySlotFamilyIcon = nil, itemQuality = nil } }
          for _, change in ipairs(changes or {}) do change(d) end
          return d
        end

        before_each(function()
          fullDraws = 0
          sonata.generation = 0
          item:SetFreeSlots(btnCtx, slot(), 3)
          item._decoration.UpdateQuestItem = function() fullDraws = fullDraws + 1 end
        end)

        after_each(function()
          sonata.generation = 0
        end)

        it("skips the setters when nothing changed, and still shows the button", function()
          item.frame:Hide()
          item:SetFreeSlots(btnCtx, slot(), 3)
          assert.equal(0, fullDraws)
          assert.is_true(item.isFreeSlot)
          assert.is_true(item.frame:IsShown())
        end)

        it("redraws once after the buttons were restyled", function()
          itemFrame:RestyleButtons()
          item:SetFreeSlots(btnCtx, slot(), 3)
          assert.equal(1, fullDraws)
          item:SetFreeSlots(btnCtx, slot(), 3)
          assert.equal(1, fullDraws, "the next redraw skips again")
        end)

        it("names the free-slot input that changed, and nothing when the redraw can be skipped", function()
          local decoration = item._decoration
          assert.is_nil(item:FreeDrawInputChanged(decoration, slot(), 3))
          assert.equal("count", item:FreeDrawInputChanged(decoration, slot(), 4))
          assert.equal("emptySlotName", item:FreeDrawInputChanged(decoration,
            slot({ function(d) d.itemInfo.emptySlotName = "Reagent Bag" end }), 3))
        end)

        it("redraws after a theme is applied, on a new decoration, or for another bag", function()
          sonata.generation = 1
          item:SetFreeSlots(btnCtx, slot(), 3)
          assert.equal(1, fullDraws)

          local old = item._decoration
          item._decoration = nil
          item:GetDecoration(btnCtx)
          item._decoration.UpdateQuestItem = function() fullDraws = fullDraws + 1 end
          item:SetFreeSlots(btnCtx, slot(), 3)
          assert.equal(2, fullDraws)

          item:SetFreeSlots(btnCtx, slot({ function(d) d.bagid = 1 end }), 3)
          assert.equal(3, fullDraws)
          item._decoration = old
        end)

        it("redraws when the count, the count display, the name, the family icon or the quality changes", function()
          item:SetFreeSlots(btnCtx, slot(), 4)
          item:SetFreeSlots(btnCtx, slot(), 4, true)
          item:SetFreeSlots(btnCtx, slot({ function(d) d.itemInfo.emptySlotName = "Reagent Bag" end }), 4, true)
          item:SetFreeSlots(btnCtx, slot({
            function(d) d.itemInfo.emptySlotName = "Reagent Bag" end,
            function(d) d.itemInfo.emptySlotFamilyIcon = "Mobile-Herbalism" end,
          }), 4, true)
          item:SetFreeSlots(btnCtx, slot({
            function(d) d.itemInfo.emptySlotName = "Reagent Bag" end,
            function(d) d.itemInfo.emptySlotFamilyIcon = "Mobile-Herbalism" end,
            function(d) d.itemInfo.itemQuality = 2 end,
          }), 4, true)
          assert.equal(5, fullDraws)
        end)
      end)

      it("keeps the size and static data an item row set before its first draw", function()
        local row = itemFrame:Create(btnCtx)
        row:SetSize(btnCtx, 20, 20)
        local data = fullItem(1)
        row:SetStaticItemFromData(btnCtx, data)
        assert.equal(data, row.staticData)
        assert.equal(20, row.frame:GetWidth())
        assert.equal(data, row:GetItemData())
      end)

      it("resets the button when a free slot shows an item, and when an item becomes a free slot", function()
        item:SetFreeSlots(btnCtx, { bagid = 0, slotid = 6, slotkey = "0_6", itemInfo = { emptySlotName = "Bag" } }, 0)
        local done = countResets()
        item:SetItemFromData(btnCtx, fullItem(2))
        assert.equal(1, done())
        assert.is_true(item.button:IsEnabled())

        done = countResets()
        item:SetFreeSlots(btnCtx, { bagid = 0, slotid = 6, slotkey = "0_6", itemInfo = { emptySlotName = "Bag" } }, 4)
        assert.equal(1, done())
        assert.is_nil(item.currentData)
      end)
    end)

    it("UpdateCount should render pre-computed stackedCount when present", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        stackedCount = 42,
        isItemEmpty = false,
        itemInfo = {
          currentItemCount = 5,
        }
      }
      item:UpdateCount(btnCtx, itemData)
      assert.is_true(_G.SetItemButtonCountCalled)
      assert.equal(42, _G.SetItemButtonCountVal)
    end)

    it("UpdateCount should fall back to currentItemCount when stackedCount is nil", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        isItemEmpty = false,
        itemInfo = {
          currentItemCount = 5,
        }
      }
      item:UpdateCount(btnCtx, itemData)
      assert.is_true(_G.SetItemButtonCountCalled)
      assert.equal(5, _G.SetItemButtonCountVal)
    end)

    it("DrawItemLevel should utilize passed ItemData directly", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        isItemEmpty = false,
        itemInfo = {
          currentItemLevel = 210,
          classID = _G.Enum.ItemClass.Armor,
        }
      }
      item.kind = const.BAG_KIND.BACKPACK
      item:DrawItemLevel(itemData)
      assert.equal("210", item.ilvlText:GetText())
      assert.is_true(item.ilvlText:IsShown())
    end)

    it("UpdateUpgrade should show UpgradeIcon if isUpgrade is true", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        isItemEmpty = false,
        isUpgrade = true,
        itemInfo = {
          itemLink = "item:12345",
        }
      }
      local shownVal = nil
      item._decoration.UpgradeIcon.SetShown = function(_, val)
        shownVal = val
      end
      item:UpdateUpgrade(btnCtx, itemData)
      assert.is_true(shownVal)
    end)

    it("UpdateNewItem should use pre-computed isNewItem and isBattlePayItem", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        isItemEmpty = false,
        itemInfo = {
          isNewItem = true,
          isBattlePayItem = false,
          itemQuality = 2,
        }
      }
      local newItemShown = false
      local battlepayShown = false
      item._decoration.NewItemTexture.Show = function() newItemShown = true end
      item._decoration.NewItemTexture.Hide = function() newItemShown = false end
      item._decoration.NewItemTexture.SetAtlas = function() end
      item._decoration.BattlepayItemTexture.Show = function() battlepayShown = true end
      item._decoration.BattlepayItemTexture.Hide = function() battlepayShown = false end

      item:UpdateNewItem(btnCtx, itemData)
      assert.is_true(newItemShown)
      assert.is_false(battlepayShown)

      itemData.itemInfo.isBattlePayItem = true
      item:UpdateNewItem(btnCtx, itemData)
      assert.is_false(newItemShown)
      assert.is_true(battlepayShown)
    end)

    it("SetFreeSlots should read emptySlotName and itemQuality from the passed data", function()
      local itemData = {
        slotkey = "0_6",
        bagid = 0,
        slotid = 6,
        isItemEmpty = true,
        itemInfo = {
          emptySlotName = "Quiver",
          itemQuality = 4,
        }
      }
      local setQualityVal = nil
      _G.SetItemButtonQuality = function(_, q)
        setQualityVal = q
      end

      item:SetFreeSlots(btnCtx, itemData, 1, false)
      assert.equal("Quiver", item.freeSlotName)
      assert.equal(4, setQualityVal)
    end)

    it("GetItemContextMatchResult should return pre-computed itemContextMatchResult from ItemData", function()
      local contextMatchCtx = ctx:New("test_context_match")
      local contextMatchItem = itemFrame:GetButton(contextMatchCtx, "0_7")
      local itemData = {
        slotkey = "0_7",
        bagid = 0,
        slotid = 7,
        isItemEmpty = false,
        itemContextMatchResult = 42,
      }
      contextMatchItem.currentData = itemData

      local result = itemFrame.GetItemContextMatchResult(contextMatchItem)
      assert.equal(42, result)
    end)

    it("UpdateUpgrade should assert that data is provided", function()
      assert.has_error(function()
        item:UpdateUpgrade(btnCtx, nil)
      end, "data must be provided")
    end)

    it("UpdateCooldown should assert that data is provided", function()
      assert.has_error(function()
        item:UpdateCooldown(btnCtx, nil)
      end, "data must be provided")
    end)
  end)
end)

describe("Empty slot family icon overlay", function()
  before_each(function()
    addon.isRetail = true
    _G.ClearItemButtonOverlay = _G.ClearItemButtonOverlay or function() end
    _G.SetItemButtonQuality = _G.SetItemButtonQuality or function() end
    _G.SetItemButtonCount = _G.SetItemButtonCount or function() end
    _G.SetItemButtonDesaturated = _G.SetItemButtonDesaturated or function() end
    _G.GameTooltip.GetOwner = _G.GameTooltip.GetOwner or function() return nil end
    itemFrame:Init()
  end)

  it("draws a centered, semi-transparent family icon atlas on a specialized empty slot", function()
    local btnCtx = ctx:New("famicon")
    local item = itemFrame:GetButton(btnCtx, "0_9")
    item:SetFreeSlots(btnCtx, {
      slotkey = "0_9", bagid = 0, slotid = 9,
      itemInfo = { emptySlotName = "Herb Bag", emptySlotFamilyIcon = "Mobile-Herbalism" },
    }, -1)
    local overlay = item._decoration.BetterBagsFamilyIcon
    assert.is_not_nil(overlay)
    assert.is_true(overlay._shown)
    assert.are.equal("Mobile-Herbalism", overlay._atlas)
    assert.are.equal(0.4, overlay._alpha)
  end)

  it("hides the family icon on a generic (family 0) empty slot", function()
    local btnCtx = ctx:New("famicon2")
    local item = itemFrame:GetButton(btnCtx, "0_10")
    item:SetFreeSlots(btnCtx, { slotkey = "0_10", bagid = 0, slotid = 10, itemInfo = { emptySlotFamilyIcon = "X" } }, -1)
    assert.is_true(item._decoration.BetterBagsFamilyIcon._shown)
    item:SetFreeSlots(btnCtx, { slotkey = "0_10", bagid = 0, slotid = 10, itemInfo = { emptySlotName = "Bag" } }, -1)
    assert.is_false(item._decoration.BetterBagsFamilyIcon._shown)
  end)

  it("hides the family icon when the slot is (re)drawn as an item", function()
    local btnCtx = ctx:New("famicon3")
    local item = itemFrame:GetButton(btnCtx, "0_11")
    item:SetFreeSlots(btnCtx, { slotkey = "0_11", bagid = 0, slotid = 11, itemInfo = { emptySlotFamilyIcon = "X" } }, -1)
    assert.is_true(item._decoration.BetterBagsFamilyIcon._shown)
    item:SetItemFromData(btnCtx, { slotkey = "0_11", bagid = 0, slotid = 11, isItemEmpty = true, itemInfo = {} })
    assert.is_false(item._decoration.BetterBagsFamilyIcon._shown)
  end)

  it("passes nil (not Common) to SetItemButtonQuality when a free slot has no itemQuality", function()
    local captured, called
    local orig = _G.SetItemButtonQuality
    _G.SetItemButtonQuality = function(_, quality) called = true; captured = quality end

    local btnCtx = ctx:New("famnoq")
    local item = itemFrame:GetButton(btnCtx, "5_1")

    -- Aggregated "stack" button: itemInfo carries no itemQuality -> nil reaches the API (no border).
    item:SetFreeSlots(btnCtx, {
      slotkey = "5_1", bagid = 5, slotid = 1,
      itemInfo = { emptySlotName = "Reagent Bag", emptySlotFamilyIcon = "Mobile-Herbalism" },
    }, 2)
    assert.is_true(called)
    assert.is_nil(captured)

    -- A slot that does carry a quality still passes it through unchanged.
    item:SetFreeSlots(btnCtx, {
      slotkey = "5_1", bagid = 5, slotid = 1,
      itemInfo = { itemQuality = const.ITEM_QUALITY.Uncommon },
    }, -1)
    assert.are.equal(const.ITEM_QUALITY.Uncommon, captured)

    _G.SetItemButtonQuality = orig
  end)

  it("shows the icon through the exact individual free-slot call (nocount) after a wipe", function()
    -- Individual ("unstacked") free slots are drawn as SetFreeSlots(ctx, btn, 1, true) after the
    -- button is released/wiped by WipeGlobalSections; the aggregated ("stacked") counter uses
    -- SetFreeSlots(ctx, btn, count). Both must end up with the glyph shown.
    local btnCtx = ctx:New("famicon4")
    local item = itemFrame:GetButton(btnCtx, "5_1")
    local btn = { slotkey = "5_1", bagid = 5, slotid = 1, itemInfo = { emptySlotName = "Reagent Bag", emptySlotFamilyIcon = "REAGENT" } }

    -- Individual path (nocount = true), fresh button.
    item:ClearItem(btnCtx)
    item:SetFreeSlots(btnCtx, btn, 1, true)
    assert.is_true(item._decoration.BetterBagsFamilyIcon._shown)
    assert.are.equal("REAGENT", item._decoration.BetterBagsFamilyIcon._atlas)

    -- Simulate a redraw: WipeGlobalSections -> Release (ClearItem) then re-draw individual.
    item:ClearItem(btnCtx)
    assert.is_false(item._decoration.BetterBagsFamilyIcon._shown)
    item:SetFreeSlots(btnCtx, btn, 1, true)
    assert.is_true(item._decoration.BetterBagsFamilyIcon._shown)

    -- Aggregated path (count, no nocount) must also show it.
    item:ClearItem(btnCtx)
    item:SetFreeSlots(btnCtx, btn, 2)
    assert.is_true(item._decoration.BetterBagsFamilyIcon._shown)
  end)
end)

-- After every block of this file (a file-level teardown also runs last when blocks are
-- shuffled), put back what the file replaced.
teardown(function()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  ResetModuleStub("ItemFrame", "frames/item.lua")
  if createdSonata then ResetModuleStub("Sonata") end
  if createdElements then ResetModuleStub("SonataElements") end
end)
