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

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class BagSlots: AceModule
local bagSlots = addon:GetModule('BagSlots')

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

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule('SectionConfig')

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule('ThemeConfig')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule('WindowGroup')

---@class Anchor: AceModule
local anchor = addon:GetModule('Anchor')

---@class BackpackBehavior: AceModule
local backpackBehavior = addon:GetModule('BackpackBehavior')

---@class BankBehavior: AceModule
local bankBehavior = addon:GetModule('BankBehavior')

--- SwitchToBankAndWipe delegates to behavior for bank-specific implementation.
--- This proxy method exists because external code (hooks.lua) calls bag:SwitchToBankAndWipe().
---@param ctx Context
function bagFrame.bagProto:SwitchToBankAndWipe(ctx)
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.behavior:SwitchToBankAndWipe(ctx)
end

-------
--- Bag Frame
-------

--- Create creates a new bag view.
---@param ctx Context
---@param kind BagKind
---@return Bag
function bagFrame:Create(ctx, kind)
  ---@class Bag
  local b = {}
  setmetatable(b, { __index = bagFrame.bagProto })
  b.currentItemCount = 0
  b.drawOnClose = false
  b.bankTab = const.BANK_TAB.BANK
  b.sections = {}
  b.toRelease = {}
  b.toReleaseSections = {}
  b.kind = kind
  b.windowGrouping = windowGroup:Create()

  -- Instantiate the appropriate behavior based on bag kind
  if kind == const.BAG_KIND.BACKPACK then
    b.behavior = backpackBehavior:Create(b)
  else
    b.behavior = bankBehavior:Create(b)
  end

  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsClassicBagPortrait
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil)

  -- Register this window with the theme system.
  themes:RegisterPortraitWindow(f, name)

  -- Setup the main frame defaults.
  b.frame = f
  b.frame:SetParent(UIParent)
  b.frame:SetToplevel(true)
  b.frame:SetFrameStrata(b.behavior:GetFrameStrata())
  local frameLevel = b.behavior:GetFrameLevel()
  if frameLevel then
    b.frame:SetFrameLevel(frameLevel)
  end
  b.sideAnchor = CreateFrame("Frame", f:GetName().."LeftAnchor", b.frame)
  b.sideAnchor:SetWidth(1)
  b.sideAnchor:SetPoint("TOPRIGHT", b.frame, "TOPLEFT")
  b.sideAnchor:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMLEFT")
  f.Owner = b

  b.frame:Hide()
  b.frame:SetSize(200, 200)

  -- Attach fade animations (created once, used conditionally based on settings)
  local animations = addon:GetModule('Animations')
  b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeGroup(b.frame)

  b.views = {
    [const.BAG_VIEW.SECTION_GRID] = views:NewGrid(f, b.kind),
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

  -- Setup money frame via behavior
  b.moneyFrame = b.behavior:SetupMoneyFrame(bottomBar)

  -- Setup the context menu.
  b.menuList = contextMenu:CreateContextMenu(b)

  -- Era creates bag slots for both backpack and bank
  local slots = bagSlots:CreatePanel(ctx, kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  -- Backpack-specific: search and theme config (no currency in era)
  if kind == const.BAG_KIND.BACKPACK then
    b.searchFrame = searchBox:Create(ctx, b.frame)
    b.themeConfigFrame = themeConfig:Create(b.sideAnchor)
    b.windowGrouping:AddWindow('themeConfig', b.themeConfigFrame)
  end

  -- Bank-specific initialization via behavior
  if kind == const.BAG_KIND.BANK then
    b.behavior:OnCreate(ctx)
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

  b.anchor = anchor:New(kind, b.frame, name)
  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)

  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
  end)
  b.resizeHandle:Hide()
  b:KeepBagInBounds()

  -- Register behavior-specific events
  b.behavior:RegisterEvents()

  events:RegisterEvent('ITEM_LOCKED', function(ectx, _, bagid, slotid)
    b:OnLock(ectx, bagid, slotid)
  end)

  events:RegisterEvent('ITEM_UNLOCKED', function(ectx, _, bagid, slotid)
    b:OnUnlock(ectx, bagid, slotid)
  end)

  events:RegisterMessage('search/SetInFrame', function (ectx, shown)
    themes:SetSearchState(ectx, b.frame, shown)
  end)

  events:RegisterMessage('bag/RedrawIcons', function(ectx)
    if not b.currentView then return end
    for _, item in pairs(b.currentView:GetItemsByBagAndSlot()) do
      item:UpdateUpgrade(ectx)
    end
  end)

  return b
end
