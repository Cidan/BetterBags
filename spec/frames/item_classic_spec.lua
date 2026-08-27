-- item_classic_spec.lua -- Item button drawing on Classic/Era clients and bag-kind
-- classification. Blizzard's Classic ItemButtonTemplate (Blizzard_ItemButton/Classic/
-- ItemButtonTemplate.lua on the classic_era and classic branches) implements
-- SetItemButtonQuality as:
--
--   function SetItemButtonQuality(button, quality, itemIDOrLink, suppressOverlays)
--     button.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]]);
--     button.IconOverlay:Hide();
--     --[[ quality color block is commented out in the Classic source ]]
--     button.IconBorder:Hide();
--   end
--
-- so the addon must draw the quality border itself on those clients. The Classic
-- ContainerFrameItemButtonTemplate also lacks the modern ItemButtonMixin methods
-- (UpdateCooldown, SetHasItem, ...); cooldowns must go through
-- ContainerFrame_UpdateCooldown(bagID, button).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:Init()
local context = addon:GetModule("Context")

-- Mirrors the Classic SetItemButtonQuality quoted above.
local function ClassicSetItemButtonQuality(button)
  button.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]])
  button.IconOverlay:Hide()
  button.IconBorder:Hide()
end

-- Mirrors Classic SetItemButtonTexture: icon comes from button.Icon/button.icon.
local function ClassicSetItemButtonTexture(button, texture)
  local icon = button.Icon or button.icon
  if texture then
    icon:Show()
  else
    icon:Hide()
  end
  icon:SetTexture(texture)
end

local overrides = {}
local function override(tbl, key, value)
  table.insert(overrides, { tbl = tbl, key = key, original = tbl[key] })
  tbl[key] = value
end
local function restoreOverrides()
  for i = #overrides, 1, -1 do
    local o = overrides[i]
    o.tbl[o.key] = o.original
  end
  overrides = {}
end

-- Stub modules registered by this spec are torn down again so later spec files can
-- load the real module (AceAddon refuses to NewModule a name that already exists).
local createdStubs = {}
local function stubModule(name)
  local mod, created = _G.StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end
local function resetCreatedStubs()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
  createdStubs = {}
end

local const

-- Builds a decoration shaped like Classic's ContainerFrameItemButtonTemplate: a plain
-- Button with IconBorder/IconOverlay/icon textures and NO modern mixin methods.
local function newClassicDecoration(item)
  local d = CreateFrame("Button", item.button:GetName() .. "DecorationClassic")
  d.IconBorder = d:CreateTexture()
  d.IconBorder:Hide()
  d.IconOverlay = d:CreateTexture()
  d.icon = d:CreateTexture()
  d.IconQuestTexture = d:CreateTexture()
  d.ExtendedSlot = d:CreateTexture()
  d.searchOverlay = d:CreateTexture()
  d.flashAnim = { IsPlaying = function() return false end, Play = function() end, Stop = function() end }
  d.newitemglowAnim = { IsPlaying = function() return false end, Play = function() end, Stop = function() end }
  d.SetMatchesSearch = function(me, match)
    if match then me.searchOverlay:Hide() else me.searchOverlay:Show() end
  end
  return d
end

local function stubModules()
  local L = stubModule("Localization")
  override(L, "G", function(_, key) return key end)

  local debug = stubModule("Debug")
  override(debug, "Log", function() end)
  override(debug, "ShowItemTooltip", function() end)
  override(debug, "HideItemTooltip", function() end)

  const = stubModule("Constants")
  override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = 0, BANK = 1 })
  override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 })
  override(const, "ITEM_QUALITY_COLOR", {
    [0] = { 0.62, 0.62, 0.62, 1 },
    [1] = { 1, 1, 1, 1 },
    [2] = { 0.12, 1, 0, 1 },
    [3] = { 0, 0.44, 0.87, 1 },
    [4] = { 0.64, 0.21, 0.93, 1 },
  })
  override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
  override(const, "BANK_BAGS", { [6] = 6 })
  override(const, "ACCOUNT_BANK_BAGS", { [13] = 13 })
  override(const, "BACKPACK_ONLY_REAGENT_BAGS", {})

  local database = stubModule("Database")
  override(database, "GetItemLevelOptions", function() return { enabled = false, color = false } end)
  override(database, "GetStackingOptions", function() return { mergeUnstackable = false } end)
  override(database, "GetExtraGlowyButtons", function() return false end)
  override(database, "GetShowAllFreeSpace", function() return false end)

  local color = stubModule("Color")
  override(color, "GetItemLevelColor", function() return 1, 1, 1 end)

  local items = stubModule("Items")
  override(items, "GetSlotKeyFromBagAndSlot", function(_, bagid, slotid) return bagid .. "_" .. slotid end)
  override(items, "GetStackData", function() return nil end)
  override(items, "IsNewItem", function() return false end)

  local themes = stubModule("Themes")
  override(themes, "GetItemButton", function(_, _, item)
    if not item._decoration then
      item._decoration = newClassicDecoration(item)
    end
    return item._decoration
  end)
end

local function itemData(bagid, slotid, quality)
  return {
    slotkey = bagid .. "_" .. slotid,
    bagid = bagid,
    slotid = slotid,
    isItemEmpty = false,
    questInfo = { isQuestItem = false, questID = nil, isActive = false },
    containerInfo = { isReadable = false, isFiltered = false, hasNoValue = false },
    itemInfo = {
      isBound = false,
      itemID = 12345,
      itemIcon = 136235,
      itemQuality = quality,
      itemLink = "item:12345",
      isNewItem = false,
      currentItemCount = 1,
      currentItemLevel = 0,
      classID = 15,
    },
  }
end

describe("ItemFrame on Classic clients", function()
  local itemFrame
  local savedGlobals = {}
  local cooldownCalls

  before_each(function()
    stubModules()
    savedGlobals.SetItemButtonQuality = _G.SetItemButtonQuality
    savedGlobals.SetItemButtonTexture = _G.SetItemButtonTexture
    savedGlobals.SetItemButtonCount = _G.SetItemButtonCount
    savedGlobals.SetItemButtonDesaturated = _G.SetItemButtonDesaturated
    savedGlobals.ClearItemButtonOverlay = _G.ClearItemButtonOverlay
    savedGlobals.ContainerFrame_UpdateCooldown = _G.ContainerFrame_UpdateCooldown
    savedGlobals.GetOwner = _G.GameTooltip.GetOwner
    savedGlobals.NEW_ITEM_ATLAS_BY_QUALITY = _G.NEW_ITEM_ATLAS_BY_QUALITY
    savedGlobals.isRetail = addon.isRetail

    cooldownCalls = {}
    _G.SetItemButtonQuality = ClassicSetItemButtonQuality
    _G.SetItemButtonTexture = ClassicSetItemButtonTexture
    _G.SetItemButtonCount = function() end
    _G.SetItemButtonDesaturated = function() end
    _G.ClearItemButtonOverlay = nil
    _G.ContainerFrame_UpdateCooldown = function(bagID, button)
      table.insert(cooldownCalls, { bagID = bagID, button = button })
    end
    _G.GameTooltip.GetOwner = function() return nil end
    _G.NEW_ITEM_ATLAS_BY_QUALITY = { [1] = "bags-glow-white", [2] = "bags-glow-green" }
    addon.isRetail = false

    ResetModuleStub("ItemFrame", "frames/item.lua")
    LoadBetterBagsModule("frames/item.lua")
    itemFrame = addon:GetModule("ItemFrame")
    itemFrame:Init()
  end)

  after_each(function()
    ResetModuleStub("ItemFrame", "frames/item.lua")
    restoreOverrides()
    _G.SetItemButtonQuality = savedGlobals.SetItemButtonQuality
    _G.SetItemButtonTexture = savedGlobals.SetItemButtonTexture
    _G.SetItemButtonCount = savedGlobals.SetItemButtonCount
    _G.SetItemButtonDesaturated = savedGlobals.SetItemButtonDesaturated
    _G.ClearItemButtonOverlay = savedGlobals.ClearItemButtonOverlay
    _G.ContainerFrame_UpdateCooldown = savedGlobals.ContainerFrame_UpdateCooldown
    _G.GameTooltip.GetOwner = savedGlobals.GetOwner
    _G.NEW_ITEM_ATLAS_BY_QUALITY = savedGlobals.NEW_ITEM_ATLAS_BY_QUALITY
    addon.isRetail = savedGlobals.isRetail
    resetCreatedStubs()
  end)

  it("shows a colored rarity border for items even though Classic SetItemButtonQuality hides it", function()
    local ctx = context:New("classic_border")
    local item = itemFrame:GetButton(ctx, "0_1")
    local decoration = item._decoration

    item:SetItemFromData(ctx, itemData(0, 1, const.ITEM_QUALITY.Rare))

    assert.is_true(decoration.IconBorder:IsShown(), "rare item must have a visible quality border on Classic")
    assert.same({ r = 0, g = 0.44, b = 0.87, a = 1 }, decoration.IconBorder._vertexColor)
    assert.equal([[Interface\Common\WhiteIconFrame]], decoration.IconBorder._texturePath)
  end)

  it("colors the border per quality on Classic", function()
    local ctx = context:New("classic_border_epic")
    local item = itemFrame:GetButton(ctx, "0_2")
    local decoration = item._decoration

    item:SetItemFromData(ctx, itemData(0, 2, const.ITEM_QUALITY.Epic))
    assert.is_true(decoration.IconBorder:IsShown())
    assert.same({ r = 0.64, g = 0.21, b = 0.93, a = 1 }, decoration.IconBorder._vertexColor)

    item:SetItemFromData(ctx, itemData(0, 2, const.ITEM_QUALITY.Uncommon))
    assert.is_true(decoration.IconBorder:IsShown())
    assert.same({ r = 0.12, g = 1, b = 0, a = 1 }, decoration.IconBorder._vertexColor)
  end)

  it("shows a bag-quality border for free slots on Classic", function()
    local ctx = context:New("classic_free_slot")
    local item = itemFrame:GetButton(ctx, "0_3")
    local decoration = item._decoration

    item:SetFreeSlots(ctx, {
      slotkey = "0_3",
      bagid = 0,
      slotid = 3,
      itemInfo = { emptySlotName = "Bag", itemQuality = const.ITEM_QUALITY.Uncommon },
    }, 4)

    assert.is_true(item.isFreeSlot)
    assert.is_true(decoration.IconBorder:IsShown(), "free slot must show the bag quality border on Classic")
    assert.same({ r = 0.12, g = 1, b = 0, a = 1 }, decoration.IconBorder._vertexColor)
  end)

  it("hides the border again when the button is cleared", function()
    local ctx = context:New("classic_clear")
    local item = itemFrame:GetButton(ctx, "0_4")
    local decoration = item._decoration

    item:SetItemFromData(ctx, itemData(0, 4, const.ITEM_QUALITY.Rare))
    assert.is_true(decoration.IconBorder:IsShown())
    item:ClearItem(ctx)
    assert.is_false(decoration.IconBorder:IsShown())
  end)

  it("draws the cooldown via ContainerFrame_UpdateCooldown at draw time when the mixin method is missing", function()
    local ctx = context:New("classic_cooldown")
    local item = itemFrame:GetButton(ctx, "1_1")
    local decoration = item._decoration
    assert.is_nil(decoration.UpdateCooldown)

    item:SetItemFromData(ctx, itemData(1, 1, const.ITEM_QUALITY.Common))

    assert.equal(1, #cooldownCalls, "ContainerFrame_UpdateCooldown must be called once during SetItemFromData")
    assert.equal(1, cooldownCalls[1].bagID)
    assert.equal(decoration, cooldownCalls[1].button)
  end)
end)

describe("ItemFrame bag kind classification", function()
  local itemFrame
  local savedGlobals = {}

  before_each(function()
    stubModules()
    savedGlobals.SetItemButtonQuality = _G.SetItemButtonQuality
    savedGlobals.SetItemButtonTexture = _G.SetItemButtonTexture
    savedGlobals.SetItemButtonCount = _G.SetItemButtonCount
    savedGlobals.SetItemButtonDesaturated = _G.SetItemButtonDesaturated
    savedGlobals.ClearItemButtonOverlay = _G.ClearItemButtonOverlay
    savedGlobals.GetOwner = _G.GameTooltip.GetOwner
    savedGlobals.NEW_ITEM_ATLAS_BY_QUALITY = _G.NEW_ITEM_ATLAS_BY_QUALITY
    savedGlobals.isRetail = addon.isRetail

    _G.SetItemButtonQuality = function() end
    _G.SetItemButtonTexture = ClassicSetItemButtonTexture
    _G.SetItemButtonCount = function() end
    _G.SetItemButtonDesaturated = function() end
    _G.ClearItemButtonOverlay = function() end
    _G.GameTooltip.GetOwner = function() return nil end
    _G.NEW_ITEM_ATLAS_BY_QUALITY = { [1] = "bags-glow-white", [2] = "bags-glow-green" }
    addon.isRetail = true

    -- Retail's ContainerFrameItemButtonTemplate carries the ItemButtonMixin cooldown method.
    local themes = addon:GetModule("Themes")
    override(themes, "GetItemButton", function(_, _, item)
      if not item._decoration then
        item._decoration = newClassicDecoration(item)
        item._decoration.UpdateCooldown = function() end
      end
      return item._decoration
    end)

    ResetModuleStub("ItemFrame", "frames/item.lua")
    LoadBetterBagsModule("frames/item.lua")
    itemFrame = addon:GetModule("ItemFrame")
    itemFrame:Init()
  end)

  after_each(function()
    ResetModuleStub("ItemFrame", "frames/item.lua")
    restoreOverrides()
    _G.SetItemButtonQuality = savedGlobals.SetItemButtonQuality
    _G.SetItemButtonTexture = savedGlobals.SetItemButtonTexture
    _G.SetItemButtonCount = savedGlobals.SetItemButtonCount
    _G.SetItemButtonDesaturated = savedGlobals.SetItemButtonDesaturated
    _G.ClearItemButtonOverlay = savedGlobals.ClearItemButtonOverlay
    _G.GameTooltip.GetOwner = savedGlobals.GetOwner
    _G.NEW_ITEM_ATLAS_BY_QUALITY = savedGlobals.NEW_ITEM_ATLAS_BY_QUALITY
    addon.isRetail = savedGlobals.isRetail
    resetCreatedStubs()
  end)

  it("classifies account bank (warbank) item buttons as BANK kind", function()
    local ctx = context:New("warbank_kind")
    local item = itemFrame:GetButton(ctx, "13_1")
    item:SetItemFromData(ctx, itemData(13, 1, const.ITEM_QUALITY.Common))
    assert.equal(const.BAG_KIND.BANK, item.kind)
  end)

  it("classifies account bank (warbank) free slots as BANK kind", function()
    local ctx = context:New("warbank_free_kind")
    local item = itemFrame:GetButton(ctx, "13_2")
    item:SetFreeSlots(ctx, {
      slotkey = "13_2",
      bagid = 13,
      slotid = 2,
      itemInfo = { emptySlotName = "Bag", itemQuality = const.ITEM_QUALITY.Common },
    }, 5)
    assert.equal(const.BAG_KIND.BANK, item.kind)
  end)

  it("classifies character bank and backpack buttons by their bag id", function()
    local ctx = context:New("kinds")
    local bankItem = itemFrame:GetButton(ctx, "6_1")
    bankItem:SetItemFromData(ctx, itemData(6, 1, const.ITEM_QUALITY.Common))
    assert.equal(const.BAG_KIND.BANK, bankItem.kind)

    local backpackItem = itemFrame:GetButton(ctx, "0_1")
    backpackItem:SetItemFromData(ctx, itemData(0, 1, const.ITEM_QUALITY.Common))
    assert.equal(const.BAG_KIND.BACKPACK, backpackItem.kind)
  end)
end)
