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

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

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
function bagFrame.bagProto:GenerateCharacterBankTabs(ctx)
  if not addon.isRetail then return end

  -- Only generate individual tabs if enabled
  if not database:GetCharacterBankTabsEnabled() then
    -- Hide all character bank tabs
    local bankBags = const.BANK_ONLY_BAGS_LIST
    for _, bagID in ipairs(bankBags) do
      if self.tabs:TabExistsByID(bagID) then
        self.tabs:HideTabByID(bagID)
      end
    end

    -- Show single bank tab
    if not self.tabs:TabExistsByID(1) then
      self.tabs:AddTab(ctx, "Bank", 1)
    else
      self.tabs:ShowTabByID(1)
    end
    
    -- Sort tabs to ensure Bank tab is first
    self.tabs:SortTabsByID()
    return
  end

  -- Hide the single bank tab when multiple tabs are enabled
  if self.tabs:TabExistsByID(1) then
    self.tabs:HideTabByID(1)
  end

  -- Try to get character bank tab data from the API
  local characterTabData = C_Bank and C_Bank.FetchPurchasedBankTabData and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)


  for _, data in pairs(characterTabData) do
    if not self.tabs:TabExistsByID(data.ID) then
      self.tabs:AddTab(ctx, data.name, data.ID)
    else
      -- Update the name if it changed
      if self.tabs:GetTabNameByID(data.ID) ~= data.name then
        self.tabs:RenameTabByID(ctx, data.ID, data.name)
      end
      self.tabs:ShowTabByID(data.ID)
    end
  end
  
  -- Sort tabs by ID to ensure proper order
  self.tabs:SortTabsByID()
  
  -- Adjust frame width if needed
  local w = self.tabs.width
  if self.frame:GetWidth() + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET < w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET then
    self.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET)
  end
end

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

  --[[
  if not self.tabs:TabExists("Purchase Warbank Tab") then
    self.tabs:AddTab(ctx, "Purchase Warbank Tab", nil, nil, BankPanel.PurchasePrompt.TabCostFrame.PurchaseButton)
  end

  if C_Bank.HasMaxBankTabs(Enum.BankType.Account) then
    self.tabs:HideTabByName("Purchase Warbank Tab")
  else
    self.tabs:MoveToEnd("Purchase Warbank Tab")
    self.tabs:ShowTabByName("Purchase Warbank Tab")
  end
  ]]--
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
  if database:GetCharacterBankTabsEnabled() then
    -- Hide all character bank tabs
    local bankBags = const.BANK_ONLY_BAGS_LIST
    for _, bagID in ipairs(bankBags) do
      local tabID = bagID
      if self.tabs:TabExistsByID(tabID) then
        self.tabs:HideTabByID(tabID)
      end
    end
  else
    self.tabs:HideTabByID(1) -- Hide Bank tab
  end
end

function bagFrame.bagProto:ShowBankAndReagentTabs()
  if database:GetCharacterBankTabsEnabled() then
    -- Show all character bank tabs
    local bankBags = const.BANK_ONLY_BAGS_LIST
    for _, bagID in ipairs(bankBags) do
      local tabID = bagID
      if self.tabs:TabExistsByID(tabID) then
        self.tabs:ShowTabByID(tabID)
      end
    end
  else
    self.tabs:ShowTabByID(1)
  end
end

---@param ctx Context
function bagFrame.bagProto:Show(ctx)
  if self.frame:IsShown() then
    return
  end
  --addon.ForceShowBlizzardBags()
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_OPEN or SOUNDKIT.IG_BACKPACK_OPEN)

  if self.kind == const.BAG_KIND.BANK and addon.isRetail then
    self:GenerateCharacterBankTabs(ctx)
    self:GenerateWarbankTabs(ctx)
    if addon.atWarbank then
      self:HideBankAndReagentTabs()
      self.tabs:SetTabByID(ctx, 13)
      -- Set the active bank type for warbank
      if BankPanel then
        BankPanel.bankType = Enum.BankType.Account
      end
    else
      self:ShowBankAndReagentTabs()
      -- Set first tab when using multiple character bank tabs
      if database:GetCharacterBankTabsEnabled() then
        local firstTabID = const.BANK_ONLY_BAGS_LIST[1]
        self.bankTab = firstTabID  -- Important: set bankTab before SetTabByID
        self.tabs:SetTabByID(ctx, firstTabID)
        ctx:Set('filterBagID', firstTabID)  -- Set the filter for the initial tab
      else
        self.bankTab = addon.isRetail and Enum.BagIndex.Bank or Enum.BagIndex.Characterbanktab
        self.tabs:SetTabByID(ctx, 1)
      end
      -- Set the active bank type for character bank
      if BankPanel then
        BankPanel.bankType = Enum.BankType.Character
      end
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
  elseif not addon.isRetail then
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
    if database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS and self.slots and not self.slots:IsShown() then
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
  self.bankTab = addon.isRetail and Enum.BagIndex.Bank or Enum.BagIndex.Characterbanktab
  BankFrame.selectedTab = 1
  self:SetTitle(L:G("Bank"))
  self.currentItemCount = -1
  BankFrame.activeTabIndex = 1
  BankPanel.selectedTabID = nil
  -- Set the active bank type so right-click item movement works correctly
  if addon.isRetail and BankPanel then
    BankPanel.bankType = Enum.BankType.Character
  end
  -- Clear bank cache to ensure clean state
  items:ClearBankCache(ctx)
  self:Wipe(ctx)
  ctx:Set('wipe', true)
  ctx:Set('filterBagID', nil) -- Clear filter for single bank tab
  -- Update visual tab selection
  self.tabs:SetTabByID(ctx, 1)
  -- Trigger a full refresh and redraw
  events:SendMessage(ctx, 'bags/RefreshBank')
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
end

---@param ctx Context
---@param tabID number
function bagFrame.bagProto:SwitchToCharacterBankTab(ctx, tabID)
  self.bankTab = tabID
  BankFrame.selectedTab = 1
  BankFrame.activeTabIndex = 1
  BankPanel.selectedTabID = nil
  -- Set the active bank type so right-click item movement works correctly
  if addon.isRetail and BankPanel then
    BankPanel.bankType = Enum.BankType.Character
  end
  self:SetTitle(format(L:G("Bank Tab %d"), tabID - const.BANK_ONLY_BAGS_LIST[1] + 1))
  self.currentItemCount = -1
  -- Clear bank cache to ensure no items from other tabs remain
  items:ClearBankCache(ctx)
  self:Wipe(ctx)
  ctx:Set('wipe', true)
  ctx:Set('filterBagID', tabID)
  -- Update visual tab selection
  self.tabs:SetTabByID(ctx, tabID)
  -- Trigger a full refresh and redraw
  events:SendMessage(ctx, 'bags/RefreshBank')
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
end

---@param ctx Context
---@param tabIndex number
---@return boolean
function bagFrame.bagProto:SwitchToAccountBank(ctx, tabIndex)
  self.bankTab = tabIndex
  BankFrame.selectedTab = 1
  BankFrame.activeTabIndex = 3
  -- Set the active bank type so right-click item movement works correctly
  if addon.isRetail and BankPanel then
    BankPanel.bankType = Enum.BankType.Account
  end
  local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
  for _, data in pairs(tabData) do
    if data.ID == tabIndex then
      BankPanel.selectedTabID = data.ID
      break
    end
  end
  BankPanel:TriggerEvent(BankPanelMixin.Event.BankTabClicked, tabIndex)
  self:SetTitle(ACCOUNT_BANK_PANEL_TITLE)
  self.currentItemCount = -1
  self:Wipe(ctx)
  ctx:Set('wipe', true)
  ctx:Set('filterBagID', nil) -- Clear filter for account bank
  -- Update visual tab selection
  self.tabs:SetTabByID(ctx, tabIndex)
  items:RefreshBank(ctx)
  ItemButtonUtil.TriggerEvent( ItemButtonUtil.Event.ItemContextChanged )
  return true
end

---@param ctx Context
function bagFrame.bagProto:SwitchToBankAndWipe(ctx)
  if self.kind == const.BAG_KIND.BACKPACK then return end
  ctx:Set('wipe', true)
  self.tabs:SetTabByID(ctx, 1)
  self.bankTab = addon.isRetail and Enum.BagIndex.Bank or Enum.BagIndex.Characterbanktab
  BankFrame.selectedTab = 1
  BankFrame.activeTabIndex = 1
  -- Set the active bank type so right-click item movement works correctly
  if addon.isRetail and BankPanel then
    BankPanel.bankType = Enum.BankType.Character
  end
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
      itemList = {[itemID] = true},
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
  b.bankTab = addon.isRetail and Enum.BagIndex.Bank or Enum.BagIndex.Characterbanktab
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

  if kind == const.BAG_KIND.BACKPACK then
    local slots = bagSlots:CreatePanel(ctx, kind)
    slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
    slots.frame:SetParent(b.frame)
    slots.frame:Hide()
    b.slots = slots
  end

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
    BankPanel.TabSettingsMenu:SetParent(b.frame)
    BankPanel.TabSettingsMenu:ClearAllPoints()
    BankPanel.TabSettingsMenu:SetPoint("BOTTOMLEFT", b.frame, "BOTTOMRIGHT", 10, 0)

    -- Adjust the settings function so the tab settings menu is populated correctly.
    BankPanel.TabSettingsMenu.GetBankFrame = function()
      return {
        GetTabData = function(_, id)
          -- Check if this is a character bank tab request
          if BankPanel.bankType == Enum.BankType.Character then
            -- For character bank tabs, we need to get the bag information
            local bagID = const.BANK_ONLY_BAGS_LIST[id]
            if bagID then
              local invid = C_Container.ContainerIDToInventoryID(bagID)
              local baglink = GetInventoryItemLink("player", invid)
              local icon = nil
              local tabName = format("Bank Tab %d", id)

              if baglink then
                icon = C_Item.GetItemIconByID(baglink)
                local itemName = C_Item.GetItemNameByID(baglink)
                if itemName and itemName ~= "" then
                  tabName = itemName
                end
              end

              -- Try to get character bank tab data from API if available
              local characterTabData = C_Bank and C_Bank.FetchPurchasedBankTabData and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
              local depositFlags = nil

              if characterTabData then
                for _, data in pairs(characterTabData) do
                  if data.ID == id then
                    tabName = data.name or tabName
                    icon = data.icon or icon
                    depositFlags = data.depositFlags
                    break
                  end
                end
              end
              
              return {
                ID = id,
                icon = icon or 133633, -- Default bag icon
                name = tabName,
                depositFlags = depositFlags,
                bankType = Enum.BankType.Character,
              }
            end
          else
            -- Original warbank tab data handling
            local bankTabData = b:GetWarbankTabDataByID(id)
            return {
              ID = id,
              icon = bankTabData.icon,
              name = b.tabs:GetTabNameByID(id),
              depositFlags = bankTabData.depositFlags,
              bankType = Enum.BankType.Account,
            }
          end
        end
      }
    end

    b.tabs = tabs:Create(b.frame)
    
    -- Always create Bank tab
    if not b.tabs:TabExistsByID(1) then
      b.tabs:AddTab(ctx, "Bank", 1)
    end
    
    -- Set initial tab if not using character bank tabs
    if not database:GetCharacterBankTabsEnabled() then
      b.tabs:SetTabByID(ctx, 1)
    end

    b.tabs:SetClickHandler(function(ectx, tabID, button)
      -- Check if this is a character bank tab
      if tabID and tabID >= Enum.BagIndex.CharacterBankTab_1 and tabID <= Enum.BagIndex.CharacterBankTab_6 then
        if button == "RightButton" then
          -- Show settings menu for character bank tabs
          BankPanel.bankType = Enum.BankType.Character
          local bagIndex = tabID
          -- Try to get character bank tab data if available
          local characterTabData = C_Bank and C_Bank.FetchPurchasedBankTabData and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
          if characterTabData then
            BankPanel:FetchPurchasedBankTabData()
          end
          BankPanel.TabSettingsMenu:Show()
          BankPanel.TabSettingsMenu:SetSelectedTab(bagIndex)
          BankPanel.TabSettingsMenu:Update()
        else
          BankPanel.TabSettingsMenu:Hide()
          BankPanel.bankType = Enum.BankType.Character
        end
        b:SwitchToCharacterBankTab(ectx, tabID)
        return true -- Tab switch handled, allow selection
      elseif tabID == 1 then
        -- Bank tab
        BankPanel.TabSettingsMenu:Hide()
        BankPanel.bankType = Enum.BankType.Character
        b:SwitchToBank(ectx)
        return true -- Tab switch handled, allow selection
      else
        -- Warbank tabs
        if button == "RightButton" or BankPanel.TabSettingsMenu:IsShown() then
          BankPanel.bankType = Enum.BankType.Account
          BankPanel:FetchPurchasedBankTabData()
          BankPanel.TabSettingsMenu:Show()
          BankPanel.TabSettingsMenu:SetSelectedTab(tabID)
          BankPanel.TabSettingsMenu:Update()
        end
        b:SwitchToAccountBank(ectx, tabID)
        return true -- Tab switch handled, allow selection
      end
    end)
    -- BANK_TAB_SETTINGS_UPDATED
    -- BANK_TABS_CHANGED
    events:RegisterEvent('PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED', function(ectx)
      b:GenerateWarbankTabs(ectx)
    end)
    events:RegisterEvent('BANK_TAB_SETTINGS_UPDATED', function(ectx)
      -- Update both warbank and character bank tabs when settings change
      b:GenerateWarbankTabs(ectx)
      if database:GetCharacterBankTabsEnabled() then
        b:GenerateCharacterBankTabs(ectx)
      end
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
  -- Setup the context menu.
  b.menuList = contextMenu:CreateContextMenu(b)
  return b
end
