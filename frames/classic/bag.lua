---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:GetModule('BagFrame')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class BagSlots: AceModule
local bagSlots = addon:GetModule('BagSlots')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Resize: AceModule
local resize = addon:GetModule('Resize')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

---@class Currency: AceModule
local currency = addon:GetModule('Currency')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule('ThemeConfig')

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule('WindowGroup')

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule('SectionConfig')

function bagFrame.bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  --self.frame:SetTitle(L:G("Bank"))
  items:ClearBankCache()
  self:Wipe()
end

function bagFrame.bagProto:Sort()
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  if _G.SortBags ~= nil then
    events:SendMessage('bags/SortBackpackClassic')
  end
end

-------
--- Bag Frame
-------

--- Create creates a new bag view.
---@param kind BagKind
---@return Bag
function bagFrame:Create(kind)
  ---@class Bag
  local b = {}
  setmetatable(b, { __index = bagFrame.bagProto })
  b.currentItemCount = 0
  b.drawOnClose = false
  b.isReagentBank = false
  b.sections = {}
  b.toRelease = {}
  b.toReleaseSections = {}
  b.kind = kind
  b.windowGrouping = windowGroup:Create()
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsClassicBagPortrait
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil)
  -- Setup the main frame defaults.
  b.frame = f
  b.sideAnchor = CreateFrame("Frame", f:GetName().."LeftAnchor", b.frame)
  b.sideAnchor:SetWidth(1)
  b.sideAnchor:SetPoint("TOPRIGHT", b.frame, "TOPLEFT")
  b.sideAnchor:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMLEFT")
  b.frame.Owner = b
  themes:RegisterPortraitWindow(f, name)

  b.frame:SetParent(UIParent)
  b.frame:SetToplevel(true)
  if b.kind == const.BAG_KIND.BACKPACK then
    b.frame:SetFrameStrata("MEDIUM")
    b.frame:SetFrameLevel(500)
  else
    b.frame:SetFrameStrata("HIGH")
  end

  b.frame:Hide()
  b.frame:SetSize(200, 200)

  b.views = {
    [const.BAG_VIEW.ONE_BAG] = views:NewOneBag(f, b.kind),
    [const.BAG_VIEW.SECTION_GRID] = views:NewGrid(f, b.kind),
    [const.BAG_VIEW.LIST] = views:NewList(f, b.kind),
    [const.BAG_VIEW.SECTION_ALL_BAGS] = views:NewBagView(f, b.kind),
  }

  -- Register the bag frame so that window positions are saved.
  Window.RegisterConfig(b.frame, database:GetBagPosition(kind))

  -- Create the bottom bar for currency and money display.
  local bottomBar = CreateFrame("Frame", nil, b.frame)
  bottomBar:SetPoint("BOTTOMLEFT", b.frame, "BOTTOMLEFT", const.OFFSETS.BOTTOM_BAR_LEFT_INSET, const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET)
  bottomBar:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BOTTOM_BAR_RIGHT_INSET, const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET)
  bottomBar:SetHeight(20)
  bottomBar:Show()
  b.bottomBar = bottomBar

  -- Create the money frame only in the player backpack bag.
  if kind == const.BAG_KIND.BACKPACK then
    local moneyFrame = money:Create()
    moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
    moneyFrame.frame:SetParent(b.frame)
    b.moneyFrame = moneyFrame
  end

  -- Setup the context menu.
  b.menuList = contextMenu:CreateContextMenu(b)

  local slots = bagSlots:CreatePanel(kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  if kind == const.BAG_KIND.BACKPACK then
    b.searchFrame = search:Create(b.frame)
  end

  if kind == const.BAG_KIND.BACKPACK then
    local currencyFrame = currency:Create(b.frame)
    currencyFrame:Hide()
    b.currencyFrame = currencyFrame

    b.themeConfigFrame = themeConfig:Create(b.sideAnchor)
    b.windowGrouping:AddWindow('themeConfig', b.themeConfigFrame)
    b.windowGrouping:AddWindow('currencyConfig', b.currencyFrame)
  end

  b.sectionConfigFrame = sectionConfig:Create(kind, b.frame)
  b.windowGrouping:AddWindow('sectionConfig', b.sectionConfigFrame)

  -- Enable dragging of the bag frame.
  b.frame:SetMovable(true)
  b.frame:EnableMouse(true)
  b.frame:RegisterForDrag("LeftButton")
  b.frame:SetClampedToScreen(true)
  b.frame:SetScript("OnDragStart", function(drag)
    b:KeepBagInBounds()
    drag:StartMoving()
  end)
  b.frame:SetScript("OnDragStop", function(drag)
    drag:StopMovingOrSizing()
    Window.SavePosition(b.frame)
    b.previousSize = b.frame:GetBottom()
    b:OnResize()
  end)

  b.frame:SetScript("OnSizeChanged", function()
    b:OnResize()
  end)
  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)

  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
  end)
  b:KeepBagInBounds()

  if b.kind == const.BAG_KIND.BACKPACK then
    events:BucketEvent('BAG_UPDATE_COOLDOWN',function(_) b:OnCooldown() end)
  end

  events:RegisterEvent('ITEM_LOCKED', function(_, bagid, slotid)
    b:OnLock(bagid, slotid)
  end)

  events:RegisterEvent('ITEM_UNLOCKED', function(_, bagid, slotid)
    b:OnUnlock(bagid, slotid)
  end)

  events:RegisterMessage('search/SetInFrame', function (_, shown)
    themes:SetSearchState(b.frame, shown)
  end)

  return b
end
