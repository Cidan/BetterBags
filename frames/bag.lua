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

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

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
---@field currentView view
---@field frame Frame The fancy frame of the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field recentItems Section The recent items section.
---@field currencyFrame CurrencyFrame The currency frame.
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
---@field views table<BagView, view>
---@field searchBox SearchFrame
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

function bagFrame.bagProto:Sort()
  if self.kind ~= const.BAG_KIND.BACKPACK then return end

  -- Unlock all locked items so they can be sorted.
  ---@type Item[]
  local lockList = {}
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    if item.data.itemInfo.isLocked then
      table.insert(lockList, item)
      item:Unlock()
    end
  end

  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  items:RemoveNewItemFromAllItems()
  C_Container:SortBags()
  items:RefreshAll()

  for _, item in pairs(lockList) do
    item:Lock()
  end
end

-- Wipe will wipe the contents of the bag and release all cells.
function bagFrame.bagProto:Wipe()
  if self.currentView then
    self.currentView:Wipe()
  end
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

function bagFrame.bagProto:DoRefresh()
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
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateSearch(text)
  end
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param dirtyItems ItemData[]
function bagFrame.bagProto:Draw(dirtyItems)
  local view = self.views[database:GetBagView(self.kind)]

  if view == nil then
    assert(view, "No view found for bag view: "..database:GetBagView(self.kind))
    return
  end


  if self.currentView and self.currentView:GetKind() ~=  view:GetKind() then
    self.currentView:Wipe()
    self.currentView:GetContent():Hide()
  end

  debug:StartProfile('Bag Render')
  view:Render(self, dirtyItems)
  debug:EndProfile('Bag Render')
  view:GetContent():Show()
  self.currentView = view
  self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
  local text = search:GetText()
  self:Search(text)
  self:OnResize()
  events:SendMessage('bag/Rendered', self)
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
  self:KeepBagInBounds()
end

function bagFrame.bagProto:ToggleReagentBank()
  -- This should never happen, but just in case!
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = not self.isReagentBank
  if self.isReagentBank then
    BankFrame.selectedTab = 2
    if self.searchBox.frame:IsShown() then
      self.frame:SetTitle("")
      self.searchBox.helpText:SetText(L:G("Search Reagent Bank"))
    else
      self.frame:SetTitle(L:G("Reagent Bank"))
    end
    self.currentItemCount = -1
    --self:ClearRecentItems()
    self:Wipe()
    items:RefreshReagentBank()
  else
    BankFrame.selectedTab = 1
    if self.searchBox.frame:IsShown() then
      self.frame:SetTitle("")
      self.searchBox.helpText:SetText(L:G("Search Bank"))
    else
      self.frame:SetTitle(L:G("Bank"))
    end
    self.currentItemCount = -1
    --self:ClearRecentItems()
    self:Wipe()
    items:RefreshBank()
  end
end

function bagFrame.bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  if self.searchBox.frame:IsShown() then
    self.frame:SetTitle("")
    self.searchBox.helpText:SetText(L:G("Search Bank"))
  else
    self.frame:SetTitle(L:G("Bank"))
  end
  self:Wipe()
end

function bagFrame.bagProto:OnCooldown()
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateCooldown()
  end
end

function bagFrame.bagProto:UpdateContextMenu()
  self.menuList = context:CreateContextMenu(self)
end

function bagFrame.bagProto:CreateCategoryForItemInCursor()
  local _, itemID, itemLink = GetCursorInfo()
  ---@cast itemID number
  question:AskForInput("Create Category", format(L:G("What would you like to name the new category for %s?"), itemLink),
  function(input)
    categories:AddItemToCategory(itemID, input)
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

  b.views = {
    [const.BAG_VIEW.ONE_BAG] = views:NewOneBag(f),
    [const.BAG_VIEW.SECTION_GRID] = views:NewGrid(f),
    [const.BAG_VIEW.LIST] = views:NewList(f)
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
      GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Sort Bags"), 1, 0.81, 0, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Swap Between Bank/Reagent Bank"), 1, 0.81, 0, 1, 1, 1)
    end

    if CursorHasItem() then
      local cursorType, _, itemLink = GetCursorInfo()
      if cursorType == "item" then
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(format(L:G("Drop %s here to create a new category for it."), itemLink), 1, 1, 1)
      end
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
  bagButton:SetScript("OnReceiveDrag", b.CreateCategoryForItemInCursor)
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      if database:GetFirstTimeMenu() then
        database:SetFirstTimeMenu(false)
        highlightTex:SetAlpha(1)
        anig:SetLooping("NONE")
        anig:Restart()
      end
      if IsShiftKeyDown() then
        BetterBags_ToggleSearch()
      elseif CursorHasItem() and GetCursorInfo() == "item" then
        b:CreateCategoryForItemInCursor()
      else
        context:Show(b.menuList)
      end

    elseif e == "RightButton" and kind == const.BAG_KIND.BANK then
      b:ToggleReagentBank()
    elseif e == "RightButton" and kind == const.BAG_KIND.BACKPACK then
      b:Sort()
    end
  end)

  local slots = bagSlots:CreatePanel(kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  if kind == const.BAG_KIND.BACKPACK then
    search:Create(b.frame)
  end

  local searchBox = search:CreateBox(kind, b.frame)
  searchBox.frame:SetPoint("TOP", b.frame, "TOP", 0, -2)
  searchBox.frame:SetSize(150, 20)
  if database:GetInBagSearch() then
    searchBox.frame:Show()
    b.frame:SetTitle("")
  end
  b.searchBox = searchBox

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

  events:RegisterMessage('search/SetInFrame', function (_, shown)
    if shown then
      b.searchBox.frame:Show()
      b.frame:SetTitle("")
    else
      b.searchBox.frame:Hide()
      b.frame:SetTitle(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
    end
  end)

  events:RegisterMessage('bags/FullRefreshAll', function()
    if b.currentView then
      b.currentView.fullRefresh = true
    end
  end)

  return b
end
