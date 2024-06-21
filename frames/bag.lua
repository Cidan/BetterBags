---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:NewModule('BagFrame')

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

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

---@class Currency: AceModule
local currency = addon:GetModule('Currency')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule('SectionConfig')

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule('ThemeConfig')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule('WindowGroup')

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class (exact) Bag
---@field kind BagKind
---@field currentView View
---@field frame Frame The fancy frame of the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field recentItems Section The recent items section.
---@field currencyFrame CurrencyFrame The currency frame.
---@field sectionConfigFrame SectionConfigFrame The section config frame.
---@field themeConfigFrame ThemeConfigFrame The theme config frame.
---@field currentItemCount number
---@field private sections table<string, Section>
---@field slots bagSlots
---@field isReagentBank boolean
---@field decorator Texture
---@field bg Texture
---@field moneyFrame Money
---@field resizeHandle Button
---@field drawOnClose boolean
---@field drawAfterCombat boolean
---@field menuList MenuList[]
---@field toRelease Item[]
---@field toReleaseSections Section[]
---@field views table<BagView, View>
---@field loaded boolean
---@field windowGrouping WindowGrouping
---@field sideAnchor Frame
---@field previousSize number
bagFrame.bagProto = {}

function bagFrame.bagProto:Show()
  if self.frame:IsShown() then
    return
  end
  --addon.ForceShowBlizzardBags()
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_OPEN or SOUNDKIT.IG_BACKPACK_OPEN)
  self.frame:Show()
end

function bagFrame.bagProto:Hide()
  if not self.frame:IsShown() then
    return
  end
  addon.ForceHideBlizzardBags()
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_CLOSE or SOUNDKIT.IG_BACKPACK_CLOSE)
  self.frame:Hide()
  if self.drawOnClose and self.kind == const.BAG_KIND.BACKPACK then
    debug:Log("draw", "Drawing bag on close")
    self.drawOnClose = false
    self:Refresh()
  end
end

function bagFrame.bagProto:Toggle()
  if self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function bagFrame.bagProto:IsShown()
  return self.frame:IsShown()
end

---@return number x
---@return number y
function bagFrame.bagProto:GetPosition()
  local scale = self.frame:GetScale()
  local x, y = self.frame:GetCenter()
  return x * scale, y * scale
end

function bagFrame.bagProto:Sort()
  if self.kind ~= const.BAG_KIND.BACKPACK then return end
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  events:SendMessage('bags/SortBackpack')
end

-- Wipe will wipe the contents of the bag and release all cells.
function bagFrame.bagProto:Wipe()
  if self.currentView then
    self.currentView:Wipe()
  end
end

---@return string
function bagFrame.bagProto:GetName()
  return self.frame:GetName()
end

-- Refresh will refresh this bag's item database, and then redraw the bag.
-- This is what would be considered a "full refresh".
function bagFrame.bagProto:Refresh()
  if self.kind == const.BAG_KIND.BACKPACK then
    events:SendMessage('bags/RefreshBackpack')
  else
    events:SendMessage('bags/RefreshBank')
  end
end

-- Search will search all items in the bag for the given text.
-- If a match is found for an item, it will be highlighted, while
-- items that don't match will dim.
---@param text? string
function bagFrame.bagProto:Search(text)
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateSearch(text)
  end
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param ctx Context
---@param slotInfo SlotInfo
function bagFrame.bagProto:Draw(ctx, slotInfo)
  local view = self.views[database:GetBagView(self.kind)]

  if view == nil then
    assert(view, "No view found for bag view: "..database:GetBagView(self.kind))
    return
  end

  if self.currentView and self.currentView:GetBagView() ~=  view:GetBagView() then
    self.currentView:Wipe()
    self.currentView:GetContent():Hide()
  end

  debug:StartProfile('Bag Render')
  view:Render(ctx, self, slotInfo)
  debug:EndProfile('Bag Render')
  view:GetContent():Show()
  self.currentView = view
  self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
  local text = search:GetText()
  self:Search(text)
  self:OnResize()
  if database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS and not self.slots:IsShown() then
    self.slots:Draw()
    self.slots:Show()
  end
  events:SendMessage('bag/Rendered', self, slotInfo)
end

function bagFrame.bagProto:KeepBagInBounds()
  local w, h = self.frame:GetSize()
  self.frame:SetClampRectInsets(0, -w+50, 0, h-50)
  -- Toggle the clamp setting to force the frame to rebind to the screen
  -- on the correct clamp insets.
  self.frame:SetClampedToScreen(false)
  self.frame:SetClampedToScreen(true)
end

function bagFrame.bagProto:OnResize()
  if database:GetBagView(self.kind) == const.BAG_VIEW.LIST and self.currentView ~= nil then
    self.currentView:UpdateListSize(self)
  end
  --if self.previousSize and database:GetBagView(self.kind) ~= const.BAG_VIEW.LIST then
    --self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", self.frame:GetLeft(), self.previousSize)
  --end
  self:KeepBagInBounds()
  self.previousSize = self.frame:GetBottom()
end

function bagFrame.bagProto:SetTitle(text)
  themes:SetTitle(self.frame, text)
end

function bagFrame.bagProto:ToggleReagentBank()
  local ctx = context:New()
  -- This should never happen, but just in case!
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = not self.isReagentBank
  items:ClearBankCache()
  if self.isReagentBank then
    BankFrame.selectedTab = 2
    self:SetTitle(L:G("Reagent Bank"))
    self.currentItemCount = -1
    --self:ClearRecentItems()
    self:Wipe()
    ctx:Set('wipe', true)
    items:RefreshReagentBank(ctx)
  else
    BankFrame.selectedTab = 1
    self:SetTitle(L:G("Bank"))
    self.currentItemCount = -1
    --self:ClearRecentItems()
    self:Wipe()
    ctx:Set('wipe', true)
    items:RefreshBank(ctx)
  end
end

function bagFrame.bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  self:SetTitle(L:G("Bank"))
  items:ClearBankCache()
  self:Wipe()
end

function bagFrame.bagProto:OnCooldown()
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateCooldown()
  end
end

function bagFrame.bagProto:OnLock(bagid, slotid)
  if not self.currentView then return end
  if slotid == nil then return end
  local slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  local button = self.currentView.itemsByBagAndSlot[slotkey]
  if button then
    button:Lock()
  end
end

function bagFrame.bagProto:OnUnlock(bagid, slotid)
  if not self.currentView then return end
  if slotid == nil then return end
  local slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  local button = self.currentView.itemsByBagAndSlot[slotkey]
  if button then
    button:Unlock()
  end
end

function bagFrame.bagProto:UpdateContextMenu()
  self.menuList = contextMenu:CreateContextMenu(self)
end

function bagFrame.bagProto:CreateCategoryForItemInCursor()
  local _, itemID, itemLink = GetCursorInfo()
  ---@cast itemID number
  question:AskForInput("Create Category", format(L:G("What would you like to name the new category for %s?"), itemLink),
  function(input)
    if input == nil then return end
    if input == "" then return end
    categories:AddItemToPersistentCategory(itemID, input)
    events:SendMessage('bags/FullRefreshAll')
  end)
  GameTooltip:Hide()
  ClearCursor()
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
  b.drawAfterCombat = false
  b.isReagentBank = false
  b.sections = {}
  b.toRelease = {}
  b.toReleaseSections = {}
  b.kind = kind
  b.windowGrouping = windowGroup:Create()
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsBagPortraitTemplate
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil)

  -- Register this window with the theme system.
  themes:RegisterPortraitWindow(f, name)

  -- Setup the main frame defaults.
  b.frame = f
  b.sideAnchor = CreateFrame("Frame", f:GetName().."LeftAnchor", b.frame)
  b.sideAnchor:SetWidth(1)
  b.sideAnchor:SetPoint("TOPRIGHT", b.frame, "TOPLEFT")
  b.sideAnchor:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMLEFT")
  f.Owner = b
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

  --b.frame.Bg:SetAlpha(sizeInfo.opacity / 100)
  --b.frame.CloseButton:SetScript("OnClick", function()
  --  b:Hide()
  --  if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
  --end)

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
    search:Create(b.frame)
  end

  if kind == const.BAG_KIND.BACKPACK then
    local currencyFrame = currency:Create(b.sideAnchor, b.frame)
    currencyFrame:Hide()
    b.currencyFrame = currencyFrame

    b.themeConfigFrame = themeConfig:Create(b.sideAnchor)
    b.windowGrouping:AddWindow('themeConfig', b.themeConfigFrame)
    b.windowGrouping:AddWindow('currencyConfig', b.currencyFrame)
  end

  b.sectionConfigFrame = sectionConfig:Create(kind, b.sideAnchor)
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
