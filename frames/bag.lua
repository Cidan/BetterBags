---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()

---@class BagFrame: AceModule
local bagFrame = addon:NewModule('BagFrame')

local L = addon:GetLocalization()

local const = addon:GetConstants()
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

local events = addon:GetEvents()

local debug = addon:GetDebug()

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

---@class Currency: AceModule
local currency = addon:GetModule('Currency')

local context = addon:GetContext()

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule('SectionConfig')

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule('ThemeConfig')

local themes = addon:GetThemes()

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule('WindowGroup')

---@class Anchor: AceModule
local anchor = addon:GetModule('Anchor')

---@class Tabs: AceModule
local tabs = addon:GetModule('Tabs')

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
---@field anchor AnchorFrame The anchor frame for the bag.
---@field bottomBar Frame The bottom bar of the bag.
---@field recentItems Section The recent items section.
---@field currencyFrame CurrencyFrame The currency frame.
---@field sectionConfigFrame SectionConfigFrame The section config frame.
---@field themeConfigFrame ThemeConfigFrame The theme config frame.
---@field currentItemCount number
---@field private sections table<string, Section>
---@field slots bagSlots
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
---@field searchFrame SearchFrame
---@field tabs Tab
---@field bankTab BankTab
bagFrame.bagProto = {}

---@param ctx Context
function bagFrame.bagProto:GenerateWarbankTabs(ctx)
  local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
  for _, data in pairs(tabData) do
    if self.tabs:TabExistsByID(data.ID) and self.tabs:GetTabNameByID(data.ID) ~= data.name then
      self.tabs:RenameTabByID(ctx, data.ID, data.name)
    elseif not self.tabs:TabExistsByID(data.ID) then
      self.tabs:AddTab(ctx, data.name, data.ID)
    end
  end

  if not self.tabs:TabExists("Purchase Warbank Tab") then
    self.tabs:AddTab(ctx, "Purchase Warbank Tab", nil, nil, AccountBankPanel.PurchasePrompt.TabCostFrame.PurchaseButton)
  end

  if C_Bank.HasMaxBankTabs(Enum.BankType.Account) then
    self.tabs:HideTabByName("Purchase Warbank Tab")
  else
    self.tabs:MoveToEnd("Purchase Warbank Tab")
    self.tabs:ShowTabByName("Purchase Warbank Tab")
  end
  -- TODO(lobato): this
  --self.currentView:UpdateWidth()
  local w = self.tabs.width
  if self.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET < w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET then
    self.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
  end
end

---@param id number
---@return BankTabData
function bagFrame.bagProto:GetWarbankTabDataByID(id)
  local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
  for _, data in pairs(tabData) do
    if data.ID == id then
      return data
    end
  end
  return {}
end

function bagFrame.bagProto:HideBankAndReagentTabs()
  self.tabs:HideTabByIndex(1)
  self.tabs:HideTabByIndex(2)
end

function bagFrame.bagProto:ShowBankAndReagentTabs()
  self.tabs:ShowTabByIndex(1)
  self.tabs:ShowTabByIndex(2)
end

---@param ctx Context
function bagFrame.bagProto:Show(ctx)
  if self.frame:IsShown() then
    return
  end
  --addon.ForceShowBlizzardBags()
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_OPEN or SOUNDKIT.IG_BACKPACK_OPEN)

  if self.kind == const.BAG_KIND.BANK and addon.isRetail then
    self:GenerateWarbankTabs(ctx)
    if addon.atWarbank then
      self:HideBankAndReagentTabs()
      self.tabs:SetTabByID(ctx, 13)
    else
      self:ShowBankAndReagentTabs()
    end
   self.moneyFrame:Update()
  end

  self.frame:Show()
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
end

---@param ctx Context
function bagFrame.bagProto:Hide(ctx)
  if not self.frame:IsShown() then
    return
  end
  addon.ForceHideBlizzardBags()
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_CLOSE or SOUNDKIT.IG_BACKPACK_CLOSE)
  self.frame:Hide()
  if self.kind == const.BAG_KIND.BANK then
    if C_Bank then
      C_Bank.CloseBankFrame()
    else
      CloseBankFrame()
    end
  elseif self.kind == const.BAG_KIND.BACKPACK then
    self.searchFrame:Hide()
  end
  if self.drawOnClose and self.kind == const.BAG_KIND.BACKPACK then
    debug:Log("draw", "Drawing bag on close")
    self.drawOnClose = false
    self:Refresh(ctx)
  end
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
end

---@param ctx Context
function bagFrame.bagProto:Toggle(ctx)
  if self.frame:IsShown() then
    self:Hide(ctx)
  else
    self:Show(ctx)
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

---@param ctx Context
function bagFrame.bagProto:Sort(ctx)
  if self.kind ~= const.BAG_KIND.BACKPACK then return end
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  events:SendMessage(ctx, 'bags/SortBackpack')
end

-- Wipe will wipe the contents of the bag and release all cells.
---@param ctx Context
function bagFrame.bagProto:Wipe(ctx)
  if self.currentView then
    self.currentView:Wipe(ctx)
  end
end

---@return string
function bagFrame.bagProto:GetName()
  return self.frame:GetName()
end

-- Refresh will refresh this bag's item database, and then redraw the bag.
-- This is what would be considered a "full refresh".
---@param ctx Context
function bagFrame.bagProto:Refresh(ctx)
  if self.kind == const.BAG_KIND.BACKPACK then
    events:SendMessage(ctx, 'bags/RefreshBackpack')
  else
    events:SendMessage(ctx, 'bags/RefreshBank')
  end
end

---@param ctx Context
---@param results table<string, boolean>
function bagFrame.bagProto:Search(ctx, results)
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateSearch(ctx, results[item.slotkey])
  end
end

---@param ctx Context
function bagFrame.bagProto:ResetSearch(ctx)
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateSearch(ctx, true)
  end
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param ctx Context
---@param slotInfo SlotInfo
---@param callback fun()
function bagFrame.bagProto:Draw(ctx, slotInfo, callback)
  local view = self.views[database:GetBagView(self.kind)]

  if view == nil then
    assert(view, "No view found for bag view: "..database:GetBagView(self.kind))
    return
  end

  if self.currentView and self.currentView:GetBagView() ~=  view:GetBagView() then
    self.currentView:Wipe(ctx)
    self.currentView:GetContent():Hide()
  end

  debug:StartProfile('Bag Render %d', self.kind)
  view:Render(ctx, self, slotInfo, function()
    debug:EndProfile('Bag Render %d', self.kind)
    view:GetContent():Show()
    self.currentView = view
    self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
    local text = searchBox:GetText()
    if text ~= "" and text ~= nil then
      self:Search(ctx, search:Search(text))
    end
    self:OnResize()
    if database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS and not self.slots:IsShown() then
      self.slots:Draw(ctx)
      self.slots:Show()
    end
    events:SendMessage(ctx, 'bag/RedrawIcons', self)
    events:SendMessage(ctx, 'bag/Rendered', self, slotInfo)
    callback()
  end)
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
  if self.anchor:IsActive() then
    self.frame:ClearAllPoints()
    self.frame:SetPoint(self.anchor.anchorPoint, self.anchor.frame, self.anchor.anchorPoint)
    --- HACKFIX(lobato): This fixes a bug in the WoW rendering engine.
    -- The frame needs to be polled in some way for it to render correctly in the pipeline,
    -- otherwise relative frames will not always render correctly across the bottom edge.
    self.frame:GetBottom()
    return
  end
  --Window.RestorePosition(self.frame)
  if self.previousSize and database:GetBagView(self.kind) ~= const.BAG_VIEW.LIST and self.loaded then
    local left = self.frame:GetLeft()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, self.previousSize)--, left, self.previousSize * self.frame:GetScale())
  end
  self:KeepBagInBounds()
  self.previousSize = self.frame:GetBottom()
end

function bagFrame.bagProto:SetTitle(text)
  themes:SetTitle(self.frame, text)
end

---@param ctx Context
function bagFrame.bagProto:SwitchToBank(ctx)
  self.bankTab = const.BANK_TAB.BANK
  BankFrame.selectedTab = 1
  self:SetTitle(L:G("Bank"))
  self.currentItemCount = -1
  BankFrame.activeTabIndex = 1
  AccountBankPanel.selectedTabID = nil
  self:Wipe(ctx)
  ctx:Set('wipe', true)
  items:RefreshBank(ctx)
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
end

---@param ctx Context
---@return boolean
function bagFrame.bagProto:SwitchToReagentBank(ctx)
  if not IsReagentBankUnlocked() then
    StaticPopup_Show("CONFIRM_BUY_REAGENTBANK_TAB")
    return false
  end
  self.bankTab = const.BANK_TAB.REAGENT
  BankFrame.selectedTab = 2
  self:SetTitle(L:G("Reagent Bank"))
  self.currentItemCount = -1
  BankFrame.activeTabIndex = 1
  AccountBankPanel.selectedTabID = nil
  self:Wipe(ctx)
  ctx:Set('wipe', true)
  items:RefreshBank(ctx)
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
  return true
end

---@param ctx Context
---@param tabIndex number
---@return boolean
function bagFrame.bagProto:SwitchToAccountBank(ctx, tabIndex)
  self.bankTab = tabIndex
  BankFrame.selectedTab = 1
  BankFrame.activeTabIndex = 3
  local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
  for _, data in pairs(tabData) do
    if data.ID == tabIndex then
      AccountBankPanel.selectedTabID = data.ID
      break
    end
  end
  self:SetTitle(ACCOUNT_BANK_PANEL_TITLE)
  self.currentItemCount = -1
  self:Wipe(ctx)
  ctx:Set('wipe', true)
  items:RefreshBank(ctx)
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
  return true
end

---@param ctx Context
function bagFrame.bagProto:SwitchToBankAndWipe(ctx)
  if self.kind == const.BAG_KIND.BACKPACK then return end
  ctx:Set('wipe', true)
  self.tabs:SetTabByIndex(ctx, 1)
  self.bankTab = const.BANK_TAB.BANK
  BankFrame.selectedTab = 1
  BankFrame.activeTabIndex = 1
  self:SetTitle(L:G("Bank"))
  items:ClearBankCache(ctx)
  self:Wipe(ctx)
end

---@param ctx Context
function bagFrame.bagProto:OnCooldown(ctx)
  if not self.currentView then return end
  for _, item in pairs(self.currentView:GetItemsByBagAndSlot()) do
    item:UpdateCooldown(ctx)
  end
end

---@param ctx Context
---@param bagid number
---@param slotid number
function bagFrame.bagProto:OnLock(ctx, bagid, slotid)
  if not self.currentView then return end
  if slotid == nil then return end
  local slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  local button = self.currentView.itemsByBagAndSlot[slotkey]
  if button then
    button:Lock(ctx)
  end
end

---@param ctx Context
---@param bagid number
---@param slotid number
function bagFrame.bagProto:OnUnlock(ctx, bagid, slotid)
  if not self.currentView then return end
  if slotid == nil then return end
  local slotkey = items:GetSlotKeyFromBagAndSlot(bagid, slotid)
  local button = self.currentView.itemsByBagAndSlot[slotkey]
  if button then
    button:Unlock(ctx)
  end
end

function bagFrame.bagProto:UpdateContextMenu()
  self.menuList = contextMenu:CreateContextMenu(self)
end

---@param ctx Context
function bagFrame.bagProto:CreateCategoryForItemInCursor(ctx)
  local kind, itemID, itemLink = GetCursorInfo()
  if not itemLink or kind ~= "item" then return end
  ---@cast itemID number
  question:AskForInput("Create Category", format(L:G("What would you like to name the new category for %s?"), itemLink),
  function(input)
    if input == nil then return end
    if input == "" then return end
    categories:CreateCategory(ctx, {
      name = input,
      permanentItemList = {[itemID] = true},
      save = true,
    })
    events:SendMessage(ctx, 'bags/FullRefreshAll')
  end)
  GameTooltip:Hide()
  ClearCursor()
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
  b.drawAfterCombat = false
  b.bankTab = const.BANK_TAB.BANK
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

  -- Create the money frame only in the player backpack bag.
  if kind == const.BAG_KIND.BACKPACK then
    local moneyFrame = money:Create()
    moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
    moneyFrame.frame:SetParent(b.frame)
    b.moneyFrame = moneyFrame
  end

    -- ...except for warbank!
  if kind == const.BAG_KIND.BANK then
    local moneyFrame = money:Create(true)
    moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
    moneyFrame.frame:SetParent(b.frame)
    b.moneyFrame = moneyFrame
  end
  -- Setup the context menu.
  b.menuList = contextMenu:CreateContextMenu(b)

  local slots = bagSlots:CreatePanel(ctx, kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  if kind == const.BAG_KIND.BACKPACK then
    b.searchFrame = searchBox:Create(ctx, b.frame)
  end

  if kind == const.BAG_KIND.BACKPACK then
    local currencyFrame = currency:Create(b.sideAnchor, b.frame)
    currencyFrame:Hide()
    b.currencyFrame = currencyFrame

    b.themeConfigFrame = themeConfig:Create(b.sideAnchor)
    b.windowGrouping:AddWindow('themeConfig', b.themeConfigFrame)
    b.windowGrouping:AddWindow('currencyConfig', b.currencyFrame)
  end

  if kind == const.BAG_KIND.BANK then
    -- Move the settings menu to the bag frame.
    AccountBankPanel.TabSettingsMenu:SetParent(b.frame)
    AccountBankPanel.TabSettingsMenu:ClearAllPoints()
    AccountBankPanel.TabSettingsMenu:SetPoint("BOTTOMLEFT", b.frame, "BOTTOMRIGHT", 10, 0)

    -- Adjust the settings function so the tab settings menu is populated correctly.
    AccountBankPanel.TabSettingsMenu.GetBankFrame = function()
      return {
        GetTabData = function(_, id)
          local bankTabData = b:GetWarbankTabDataByID(id)
          return {
            ID = id,
            icon = bankTabData.icon,
            name = b.tabs:GetTabNameByID(id),
            depositFlags = bankTabData.depositFlags,
            bankType = Enum.BankType.Account,
          }
        end
      }
    end

    b.tabs = tabs:Create(b.frame)
    b.tabs:AddTab(ctx, "Bank")
    b.tabs:AddTab(ctx, "Reagent Bank")

    b.tabs:SetTabByIndex(ctx, 1)

    b.tabs:SetClickHandler(function(ectx, tabIndex, button)
      if tabIndex == 1 then
        AccountBankPanel.TabSettingsMenu:Hide()
        b:SwitchToBank(ectx)
      elseif tabIndex == 2 then
        AccountBankPanel.TabSettingsMenu:Hide()
        return b:SwitchToReagentBank(ectx)
      else
        if button == "RightButton" or AccountBankPanel.TabSettingsMenu:IsShown() then
          AccountBankPanel.TabSettingsMenu:SetSelectedTab(tabIndex)
          AccountBankPanel.TabSettingsMenu:Show()
          AccountBankPanel.TabSettingsMenu:Update()
        end
        b:SwitchToAccountBank(ectx, tabIndex)
      end
      return true
    end)
    -- BANK_TAB_SETTINGS_UPDATED
    -- BANK_TABS_CHANGED
    events:RegisterEvent('PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED', function(ectx)
      b:GenerateWarbankTabs(ectx)
    end)
    events:RegisterEvent('BANK_TAB_SETTINGS_UPDATED', function(ectx)
      b:GenerateWarbankTabs(ectx)
    end)
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
    b:OnResize()
  end)

  b.anchor = anchor:New(kind, b.frame, name)
  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)
  b.previousSize = b.frame:GetBottom()

  b.frame:SetScript("OnSizeChanged", function()
    b:OnResize()
  end)

  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
  end)
  b.resizeHandle:Hide()
  b:KeepBagInBounds()

  if b.kind == const.BAG_KIND.BACKPACK then
    events:BucketEvent('BAG_UPDATE_COOLDOWN',function(ectx) b:OnCooldown(ectx) end)
  end

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
