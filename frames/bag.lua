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

---@class Context: AceModule
local context = addon:GetModule('Context')

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

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class (exact) Bag
---@field kind BagKind
---@field frame Frame The fancy frame of the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field content Grid The main content frame of the bag.
---@field recentItems Section The recent items section.
---@field freeSlots Section The free slots section.
---@field freeBagSlotsButton Item The free bag slots button.
---@field freeReagentBagSlotsButton Item The free reagent bag slots button.
---@field currencyFrame CurrencyFrame The currency frame.
---@field itemsByBagAndSlot table<number, table<number, Item|ItemRow>>
---@field currentItemCount number
---@field private sections table<string, Section>
---@field slots bagSlots
---@field isReagentBank boolean
---@field decorator Texture
---@field bg Texture
---@field moneyFrame Money
---@field resizeHandle Button
---@field drawOnClose boolean
---@field menuList MenuList[]
---@field toRelease Item[]
---@field toReleaseSections Section[]
bagFrame.bagProto = {}

function bagFrame.bagProto:Show()
  if self.frame:IsShown() then
    return
  end
  addon.ForceShowBlizzardBags()
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

function bagFrame.bagProto:WipeFreeSlots()
  self.content:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.content:RemoveCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
  self.freeSlots:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.freeSlots:RemoveCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
  self.freeSlots:GetContent():Hide()
end

-- Wipe will wipe the contents of the bag and release all cells.
function bagFrame.bagProto:Wipe()
  for _, oldFrame in pairs(self.toRelease) do
    oldFrame:Release()
  end
  for _, section in pairs(self.toReleaseSections) do
    section:Release()
  end
  self:WipeFreeSlots()
  self.content:RemoveCell(self.freeSlots.title:GetText(), self.freeSlots)
  self.content:Wipe()
  wipe(self.itemsByBagAndSlot)
  wipe(self.sections)
  wipe(self.toRelease)
  wipe(self.toReleaseSections)
end

-- Refresh will refresh this bag's item database, and then redraw the bag.
-- This is what would be considered a "full refresh".
function bagFrame.bagProto:Refresh()
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
function bagFrame.bagProto:Search(text)
  for _, bagData in pairs(self.itemsByBagAndSlot) do
    for _, item in pairs(bagData) do
      item:UpdateSearch(text)
    end
  end
end

-- UpdateCellWidth will update the cell width of the bag based on the current
-- bag view configuration.
function bagFrame.bagProto:UpdateCellWidth()
  local sizeInfo = database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind))
  self.content.maxCellWidth = sizeInfo.columnCount

  for _, section in pairs(self.sections) do
    section:SetMaxCellWidth(sizeInfo.itemsPerRow)
  end
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param dirtyItems ItemData[]
function bagFrame.bagProto:Draw(dirtyItems)
  if self.slots:IsShown() then
    self:Wipe()
  end
  self:UpdateCellWidth()
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
  self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
  local text = search:GetText()
  self:Search(text)
  self:KeepBagInBounds()
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
  if database:GetBagView(self.kind) == const.BAG_VIEW.LIST then
    views:UpdateListSize(self)
  end
  self:KeepBagInBounds()
end

function bagFrame.bagProto:ClearRecentItems()
  for _, i in pairs(self.recentItems:GetAllCells()) do
    local bagid, slotid = i.data.bagid, i.data.slotid
    if bagid and slotid then
      self.itemsByBagAndSlot[bagid] = self.itemsByBagAndSlot[bagid] or {}
      self.itemsByBagAndSlot[bagid][slotid] = nil
    end
  end
  self.recentItems:WipeOnlyContents()
end

-- GetOrCreateSection will get an existing section by category,
-- creating it if it doesn't exist.
---@param category string
---@return Section
function bagFrame.bagProto:GetOrCreateSection(category)
  if category == L:G("Recent Items") then return self.recentItems end
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

function bagFrame.bagProto:GetSection(category)
  if category == L:G("Recent Items") then return self.recentItems end
  return self.sections[category]
end

function bagFrame.bagProto:RemoveSection(category)
  if category == L:G("Recent Items") then return end
  self.sections[category] = nil
end

---@return table<string, Section>
function bagFrame.bagProto:GetAllSections()
  return self.sections
end

function bagFrame.bagProto:ToggleReagentBank()
  -- This should never happen, but just in case!
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = not self.isReagentBank
  if self.isReagentBank then
    BankFrame.selectedTab = 2
    self.frame:SetTitle(L:G("Reagent Bank"))
    self.currentItemCount = -1
    self:ClearRecentItems()
    self:Wipe()
    items:RefreshReagentBank()
  else
    BankFrame.selectedTab = 1
    self.frame:SetTitle(L:G("Bank"))
    self.currentItemCount = -1
    self:ClearRecentItems()
    self:Wipe()
    items:RefreshBank()
  end
end

function bagFrame.bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  self.frame:SetTitle(L:G("Bank"))
  self:Wipe()
end

function bagFrame.bagProto:OnCooldown()
  for _, bagData in pairs(self.itemsByBagAndSlot) do
    for _, item in pairs(bagData) do
      item:UpdateCooldown()
    end
  end
end

function bagFrame.bagProto:UpdateContextMenu()
  self.menuList = context:CreateContextMenu(self)
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
  b.itemsByBagAndSlot = {}
  b.sections = {}
  b.toRelease = {}
  b.toReleaseSections = {}
  b.kind = kind
  local sizeInfo = database:GetBagSizeInfo(b.kind, database:GetBagView(b.kind))
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsBagPortraitTemplate
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil, "BetterBagsBagPortraitTemplate")

  -- Setup the main frame defaults.
  b.frame = f
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
  b.frame.Bg:SetAlpha(sizeInfo.opacity / 100)
  b.frame:SetTitle(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  b.frame.CloseButton:SetScript("OnClick", function()
    b:Hide()
    if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
  end)
  b.frame:SetPortraitToAsset([[Interface\Icons\INV_Misc_Bag_07]])
  b.frame:SetPortraitTextureSizeAndOffset(38, -5, 0)

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
  b.menuList = context:CreateContextMenu(b)

  -- Create the invisible menu button.
  local bagButton = CreateFrame("Button")
  bagButton:EnableMouse(true)
  bagButton:SetParent(b.frame.PortraitContainer)
  --bagButton:SetHighlightTexture([[Interface\AddOns\BetterBags\Textures\glow.png]])
  bagButton:SetWidth(40)
  bagButton:SetHeight(40)
  bagButton:SetPoint("TOPLEFT", b.frame.PortraitContainer, "TOPLEFT", -6, 2)
  local highlightTex = bagButton:CreateTexture("BetterBagsBagButtonTextureHighlight", "BACKGROUND")
  highlightTex:SetTexture([[Interface\AddOns\BetterBags\Textures\glow.png]])
  highlightTex:SetAllPoints()
  highlightTex:SetAlpha(0)
  local anig = highlightTex:CreateAnimationGroup("BetterBagsBagButtonTextureHighlightAnim")
  local ani = anig:CreateAnimation("Alpha")
  ani:SetFromAlpha(0)
  ani:SetToAlpha(1)
  ani:SetDuration(0.2)
  ani:SetSmoothing("IN")
  if database:GetFirstTimeMenu() then
    ani:SetDuration(0.4)
    anig:SetLooping("BOUNCE")
    anig:Play()
  end
  bagButton:SetScript("OnEnter", function()
    if not database:GetFirstTimeMenu() then
      anig:Stop()
      highlightTex:SetAlpha(1)
      anig:Play()
    end
    GameTooltip:SetOwner(bagButton, "ANCHOR_LEFT")
    if kind == const.BAG_KIND.BACKPACK then
      GameTooltip:SetText(L:G("Left Click to open the menu, right click sort your bags and clear recent items."))
    else
      GameTooltip:SetText(L:G("Left Click to open the menu, right click to swap to reagent bank and back."))
    end
    GameTooltip:Show()
  end)
  bagButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not database:GetFirstTimeMenu() then
      anig:Stop()
      highlightTex:SetAlpha(0)
      anig:Restart(true)
    end
  end)
  bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      if database:GetFirstTimeMenu() then
        database:SetFirstTimeMenu(false)
        highlightTex:SetAlpha(1)
        anig:SetLooping("NONE")
        anig:Restart()
      end
      context:Show(b.menuList)
    elseif e == "RightButton" and kind == const.BAG_KIND.BANK then
      b:ToggleReagentBank()
    elseif e == "RightButton" and kind == const.BAG_KIND.BACKPACK then
      PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
      items:RemoveNewItemFromAllItems()
      C_Container:SortBags()
    end
  end)

  -- Create the bag content frame.
  local content = grid:Create(b.frame)
  content:GetContainer():ClearAllPoints()
  content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  content:Show()
  b.content = content

  -- Create the recent items section.
  local recentItems = sectionFrame:Create()
  recentItems:SetTitle(L:G("Recent Items"))
  recentItems:SetMaxCellWidth(sizeInfo.itemsPerRow)
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
  slots.frame:Hide()
  b.slots = slots

  if kind == const.BAG_KIND.BACKPACK then
    search:Create(b.frame)
  end

  if kind == const.BAG_KIND.BACKPACK then
    local currencyFrame = currency:Create(b.frame)
    currencyFrame:Hide()
    b.currencyFrame = currencyFrame
  end
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

  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
  end)
  b:KeepBagInBounds()

  if b.kind == const.BAG_KIND.BACKPACK then
    events:BucketEvent('BAG_UPDATE_COOLDOWN',function(_) b:OnCooldown() end)
  end

  return b
end
