local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:OnInitialize()

local ctx = addon:GetModule("Context")

-- Stub standard dependencies
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end

local database = StubBetterBagsModule("Database")
database.GetItemLevelOptions = function() return { color = true, enabled = true } end
database.GetStackingOptions = function() return { mergeUnstackable = false } end
database.GetShowAllFreeSpace = function() return false end

local color = StubBetterBagsModule("Color")
color.GetItemLevelColor = function() return 1, 1, 1 end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.BACKPACK_BAGS = { [0] = true, [1] = true }
const.BANK_BAGS = { [5] = true }

local items = StubBetterBagsModule("Items")
items.GetSlotKeyFromBagAndSlot = function(bagid, slotid) return bagid .. "_" .. slotid end
items.GetStackData = function() return nil end
items.IsNewItem = function() return false end

local themes = StubBetterBagsModule("Themes")
themes.GetItemButton = function(_, buttonCtx, item)
  if not item._decoration then
    item._decoration = {
      SetID = function(_, id) item._decoration.id = id end,
      SetMatchesSearch = function() end,
      ItemSlotBackground = { Hide = function() end, Show = function() end },
      IconBorder = { SetTexture = function() end, SetBlendMode = function() end, SetTexCoord = function() end, SetSize = function() end },
      NormalTexture = { SetSize = function() end },
      IconQuestTexture = { SetSize = function() end },
      IconTexture = { SetSize = function() end },
      IconOverlay = { SetSize = function() end },
      UpgradeIcon = { SetShown = function() end },
      BattlepayItemTexture = { Hide = function() end },
      NewItemTexture = { Hide = function() end },
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
    }
  end
  return item._decoration
end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

-- Load the item.lua file
LoadBetterBagsModule("frames/item.lua")
local itemFrame = addon:GetModule("ItemFrame")

describe("ItemFrame Static Buttons and Parent Removal Tests", function()
  before_each(function()
    _G.ClearItemButtonOverlay = _G.ClearItemButtonOverlay or function() end
    _G.SetItemButtonQuality = _G.SetItemButtonQuality or function() end
    _G.SetItemButtonCount = _G.SetItemButtonCount or function() end
    _G.SetItemButtonDesaturated = _G.SetItemButtonDesaturated or function() end
    _G.GameTooltip.GetOwner = _G.GameTooltip.GetOwner or function() return nil end
    itemFrame:OnInitialize()
  end)

  it("should create buttonsBySlotkey table on OnInitialize", function()
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

  it("should remove parent frame and use the ItemButton directly as i.frame", function()
    local btnCtx = ctx:New("test")
    local item = itemFrame:GetButton(btnCtx, "0_2")
    assert.equal(item.frame, item.button)
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

    -- This call should succeed (it will fail right now until we implement the fix)
    item:SetItem(btnCtx, "0_2")

    -- And the decoration frame level should be 0
    assert.equal(item._decoration._frameLevel, 0)
  end)
end)
