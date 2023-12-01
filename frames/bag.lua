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

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Resize: AceModule
local resize = addon:GetModule('Resize')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

local LSM = LibStub('LibSharedMedia-3.0')

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class Bag
---@field kind BagKind
---@field frame Frame The fancy frame of the bag.
---@field leftHeader Frame The top left header of the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field content Grid The main content frame of the bag.
---@field recentItems Section The recent items section.
---@field freeSlots Section The free slots section.
---@field freeBagSlotsButton Item The free bag slots button.
---@field freeReagentBagSlotsButton Item The free reagent bag slots button.
---@field itemsByBagAndSlot table<number, table<number, Item|ItemRow>>
---@field sections table<string, Section>
---@field slots bagSlots
---@field isReagentBank boolean
---@field decorator Texture
---@field bg Texture
---@field moneyFrame Money
---@field resizeHandle Button
local bagProto = {}

function bagProto:Show()
  if self.frame:IsShown() then
    return
  end
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_OPEN or SOUNDKIT.IG_BACKPACK_OPEN)
  self.frame:Show()
end

function bagProto:Hide()
  if not self.frame:IsShown() then
    return
  end
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_CLOSE or SOUNDKIT.IG_BACKPACK_CLOSE)
  self.frame:Hide()
end

function bagProto:Toggle()
  if self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function bagProto:IsShown()
  return self.frame:IsShown()
end

---@return number x
---@return number y
function bagProto:GetPosition()
  local scale = self.frame:GetScale()
  local x, y = self.frame:GetCenter()
  return x * scale, y * scale
end

function bagProto:WipeFreeSlots()
  self.content:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.content:RemoveCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
  self.freeSlots:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.freeSlots:RemoveCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
end

-- Wipe will wipe the contents of the bag and release all cells.
function bagProto:Wipe()
  self:WipeFreeSlots()
  self.content:RemoveCell(self.freeSlots.title:GetText(), self.freeSlots)
  self.content:Wipe()
  wipe(self.itemsByBagAndSlot)
  wipe(self.sections)
end

-- Refresh will refresh this bag's item database, and then redraw the bag.
-- This is what would be considered a "full refresh".
function bagProto:Refresh()
  if self.kind == const.BAG_KIND.BACKPACK then
    items:RefreshBackpack()
  elseif self.kind == const.BAG_KIND.BANK and not self.isReagentBank then
    items:RefreshBank()
  else
    items:RefreshReagentBank()
  end
end

-- Search will search all items in the bag for the given text.
-- If a match is found for an item, it will be highlighted, while
-- items that don't match will dim.
---@param text? string
function bagProto:Search(text)
  for _, bagData in pairs(self.itemsByBagAndSlot) do
    for _, item in pairs(bagData) do
      item:UpdateSearch(text)
    end
  end
end

-- UpdateCellWidth will update the cell width of the bag based on the current
-- bag view configuration.
function bagProto:UpdateCellWidth()
  local sizeInfo = database:GetBagSizeInfo(self.kind)
  self.content.maxCellWidth = sizeInfo.columnCount

  for _, section in pairs(self.sections) do
    section:SetMaxCellWidth(sizeInfo.itemsPerRow)
  end
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param dirtyItems table<number, table<number, ItemMixin>>
function bagProto:Draw(dirtyItems)
  self:UpdateCellWidth()
  for _, i in pairs(self.recentItems:GetAllCells()) do
    local bagid, slotid = i:GetMixin():GetItemLocation():GetBagAndSlot()
    if bagid and slotid then
      self.itemsByBagAndSlot[bagid] = self.itemsByBagAndSlot[bagid] or {}
      self.itemsByBagAndSlot[bagid][slotid] = nil
    end
  end
  self.recentItems:WipeOnlyContents()
  if database:GetBagView(self.kind) == const.BAG_VIEW.ONE_BAG then
    self.resizeHandle:Hide()
    views:OneBagView(self, dirtyItems)
  elseif database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_GRID then
    self.resizeHandle:Hide()
    views:GridView(self, dirtyItems)
  elseif database:GetBagView(self.kind) == const.BAG_VIEW.LIST then
    self.resizeHandle:Show()
    views:ListView(self, dirtyItems)
  end
  local text = self.frame.SearchBox:GetText()
  self:Search(text)
  self:KeepBagInBounds()
end

function bagProto:KeepBagInBounds()
  local w, h = self.frame:GetSize()
  self.frame:SetClampRectInsets(0, -w+50, 0, h-50)
  -- Toggle the clamp setting to force the frame to rebind to the screen
  -- on the correct clamp insets.
  self.frame:SetClampedToScreen(false)
  self.frame:SetClampedToScreen(true)
end

function bagProto:OnResize()
  if database:GetBagView(self.kind) == const.BAG_VIEW.LIST then
    views:UpdateListSize(self)
  end
  self:KeepBagInBounds()
end

-- GetOrCreateSection will get an existing section by category,
-- creating it if it doesn't exist.
---@param category string
---@return Section
function bagProto:GetOrCreateSection(category)
  local section = self.sections[category]
  if section == nil then
    section = sectionFrame:Create()
    section.frame:SetParent(self.content:GetScrollView())
    section:SetTitle(category)
    self.content:AddCell(category, section)
    self.sections[category] = section
  end
  return section
end

function bagProto:ToggleReagentBank()
  -- This should never happen, but just in case!
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = not self.isReagentBank
  if self.isReagentBank then
    BankFrame.selectedTab = 2
    self.frame:SetTitle(L:G("Reagent Bank"))
    self:Wipe()
    items:RefreshReagentBank()
  else
    BankFrame.selectedTab = 1
    self.frame:SetTitle(L:G("Bank"))
    self:Wipe()
    items:RefreshBank()
  end
end

function bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  self.frame:SetTitle(L:G("Bank"))
  self:Wipe()
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
  setmetatable(b, { __index = bagProto })

  b.isReagentBank = false
  b.itemsByBagAndSlot = {}
  b.sections = {}
  b.kind = kind
  local sizeInfo = database:GetBagSizeInfo(b.kind)
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsBagPortraitTemplate
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil, "BetterBagsBagPortraitTemplate")

  -- Setup the main frame defaults.
  b.frame = f
  b.frame:SetParent(UIParent)
  if b.kind == const.BAG_KIND.BACKPACK then
    b.frame:SetFrameStrata("MEDIUM")
    b.frame:SetFrameLevel(500)
  else
    b.frame:SetFrameStrata("HIGH")
  end
  b.frame:Hide()
  b.frame:SetSize(200, 200)
  b.frame.Bg:SetAlpha(0.8)
  b.frame:SetTitle(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  b.frame.CloseButton:SetScript("OnClick", function()
    b:Hide()
    if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
  end)
  b.frame:SetPortraitToAsset([[Interface\Icons\INV_Misc_Bag_07]])
  b.frame:SetPortraitTextureSizeAndOffset(38, -5, 0)

  -- Register the bag frame so that window positions are saved.
  Window.RegisterConfig(b.frame, database:GetBagPosition(kind))

  -- Create the top left header.
  -- TODO(lobato): This is obsolete, remove it eventually.
  ---@class Frame: BackdropTemplate
  local leftHeader = CreateFrame("Frame", nil, b.frame, "BackdropTemplate")
  leftHeader:SetPoint("TOPLEFT", 3, -20) -- -8 to -20
  leftHeader:SetPoint("TOPRIGHT", -3, 3)
  leftHeader:SetHeight(20)
  leftHeader:Show()
  b.leftHeader = leftHeader

  -- Create the bottom bar for currency and money display.
  local bottomBar = CreateFrame("Frame", nil, b.frame)
  bottomBar:SetPoint("BOTTOMLEFT", b.frame, "BOTTOMLEFT", 0, 6)
  bottomBar:SetPoint("TOPRIGHT", b.frame, "BOTTOMRIGHT", 0, 40)
  bottomBar:Show()
  b.bottomBar = bottomBar

  -- Create the money frame only in the player backpack bag.
  if kind == const.BAG_KIND.BACKPACK then
    local moneyFrame = money:Create()
    moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -10, 0)
    moneyFrame.frame:SetParent(b.frame)
    b.moneyFrame = moneyFrame
  end

  -- Create the invisible menu button.
  local bagButton = CreateFrame("Button")
  bagButton:EnableMouse(true)
  bagButton:SetParent(b.frame.PortraitContainer)
  bagButton:SetHighlightTexture([[Interface\AddOns\BetterBags\Textures\glow.png]])
  bagButton:SetWidth(40)
  bagButton:SetHeight(40)
  bagButton:SetPoint("TOPLEFT", b.frame.PortraitContainer, "TOPLEFT", -6, 2)
  bagButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(bagButton, "ANCHOR_LEFT")
    if kind == const.BAG_KIND.BACKPACK then
      GameTooltip:SetText(L:G("Left Click to open the menu."))
    else
      GameTooltip:SetText(L:G("Left Click to open the menu, right click to swap to reagent bank and back."))
    end
    GameTooltip:Show()
  end)
  bagButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  -- Create the bag content frame.
  local content = grid:Create(b.frame)
  content:GetContainer():SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 3, -3)
  content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -3, 3)
  content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  content:Show()
  b.content = content

  -- Create the recent items section.
  local recentItems = sectionFrame:Create()
  recentItems:SetTitle(L:G("Recent Items"))
  recentItems:SetMaxCellWidth(sizeInfo.itemsPerRow)
  --recentItems.frame:SetParent(b.frame)
  --recentItems.frame:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 3, -3)
  recentItems.frame:Hide()
  content:AddHeader(recentItems)
  b.recentItems = recentItems

  -- Create the free bag slots buttons and free bag slot section.
  local freeBagSlotsButton = itemFrame:Create()
  b.freeBagSlotsButton = freeBagSlotsButton

  local freeReagentBagSlotsButton = itemFrame:Create()
  b.freeReagentBagSlotsButton = freeReagentBagSlotsButton

  local freeSlots = sectionFrame:Create()
  freeSlots:SetTitle(L:G("Free Slots"))
  freeSlots:SetMaxCellWidth(sizeInfo.itemsPerRow)
  b.freeSlots = freeSlots

  local slots = bagSlots:CreatePanel(kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  b.slots = slots

  -- Setup the search box events.
  b.frame.SearchBox:SetAlpha(0)
  b.frame.SearchBox:SetScript("OnEnter", function()
    b.frame.SearchBox:SetAlpha(1)
  end)
  b.frame.SearchBox:SetScript("OnLeave", function()
    if b.frame.SearchBox:HasFocus() then return end
    if b.frame.SearchBox:GetText() ~= "" then return end
    b.frame.SearchBox:SetAlpha(0)
  end)
  b.frame.SearchBox:SetScript("OnEditFocusGained", function()
    b.frame.SearchBox:SetAlpha(1)
  end)
  b.frame.SearchBox:SetScript("OnEditFocusLost", function()
    if b.frame.SearchBox:GetText() ~= "" then return end
    b.frame.SearchBox:SetAlpha(0)
  end)

  b.frame.SearchBox:SetScript("OnTextChanged", function()
    local text = b.frame.SearchBox:GetText()
    if text == "" or text == nil then
      b.frame.SearchBox.Instructions:Show()
    else
      b.frame.SearchBox.Instructions:Hide()
    end
    b:Search(text)
  end)

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
  end)

  b.frame:SetScript("OnSizeChanged", function()
    b:OnResize()
  end)
  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)

  -- Setup the context menu.
  local contextMenu = context:CreateContextMenu(b)
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      context:Show(contextMenu)
    else
      b:ToggleReagentBank()
    end
  end)
  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagFrameSize(b.kind, fw, fh)
  end)
  return b
end

--- Destroy destroys the given bag view.
---@param bag Bag
function bagFrame:Destroy(bag)
end