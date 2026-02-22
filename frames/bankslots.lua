---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bank slots module.
---@class BankSlots: AceModule
local BankSlots = addon:NewModule('BankSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Context: AceModule
local context = addon:GetModule('Context')

local buttonCount = 0

-- BankSlotButton represents a single bank tab slot button in the panel.
---@class BankSlotButton
---@field frame Button
---@field bagIndex number The Enum.BagIndex value for this tab slot
---@field bankType BankType Whether this is a Character or Account bank tab
---@field purchased boolean Whether this tab slot has been purchased
---@field isSelected boolean Whether this tab slot is currently selected
---@field iconTexture Texture The icon texture (shown when purchased)
---@field emptyBg Texture The empty slot background texture
---@field selectedHighlight Texture The highlight shown when selected
---@field plusText Texture The green '+' atlas icon shown for unpurchased slots
local bankSlotButtonProto = {}

-- Update refreshes the button's visual state based on current tab data.
---@param charTabData table<number, BankTabData>
---@param accountTabData table<number, BankTabData>
function bankSlotButtonProto:Update(charTabData, accountTabData)
  local tabData
  if self.bankType == Enum.BankType.Character then
    tabData = charTabData[self.bagIndex]
  else
    tabData = accountTabData[self.bagIndex]
  end

  if tabData then
    -- Purchased slot: show the configured icon
    self.purchased = true
    self.iconTexture:SetTexture(tabData.icon)
    self.iconTexture:Show()
    self.plusText:Hide()
  else
    -- Unpurchased slot: show empty appearance with green '+'
    self.purchased = false
    self.iconTexture:SetTexture(nil)
    self.iconTexture:Hide()
    self.plusText:Show()
  end

  -- Update selected highlight
  if self.isSelected then
    self.selectedHighlight:Show()
  else
    self.selectedHighlight:Hide()
  end
end

---@param selected boolean
function bankSlotButtonProto:SetSelected(selected)
  self.isSelected = selected
  if selected then
    self.selectedHighlight:Show()
  else
    self.selectedHighlight:Hide()
  end
end

-- bankSlotsPanel is the slide-out panel showing all possible bank tab slots.
---@class bankSlotsPanel
---@field frame Frame
---@field content Grid
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
---@field buttons BankSlotButton[]
---@field selectedBagIndex number?
BankSlots.bankSlotsPanelProto = {}

-- Draw refreshes all button visuals from the current C_Bank tab data.
---@param ctx Context
function BankSlots.bankSlotsPanelProto:Draw(ctx)
  local _ = ctx
  debug:Log('BankSlots', "Bank Slots Draw called")

  -- Fetch purchased tab data from the Blizzard bank API
  local charTabData = {}
  local accountTabData = {}
  if C_Bank and C_Bank.FetchPurchasedBankTabData then
    local charTabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
    if charTabs then
      for _, tab in ipairs(charTabs) do
        charTabData[tab.ID] = tab
      end
    end
    local accountTabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
    if accountTabs then
      for _, tab in ipairs(accountTabs) do
        accountTabData[tab.ID] = tab
      end
    end
  end

  -- Update all slot buttons
  for _, btn in ipairs(self.buttons) do
    btn:Update(charTabData, accountTabData)
  end

  -- Layout the grid and size the panel to fit
  local w, h = self.content:Draw({
    cells = self.content.cells,
    maxWidthPerRow = 1024,
  })
  self.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET + 4)
  self.frame:SetHeight(h + 42)
end

function BankSlots.bankSlotsPanelProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

---@param callback? fun()
function BankSlots.bankSlotsPanelProto:Show(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeInGroup.callback = function()
      self.fadeInGroup.callback = nil
      callback()
    end
  end
  self.fadeInGroup:Play()
end

---@param callback? fun()
function BankSlots.bankSlotsPanelProto:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOutGroup.callback = function()
      self.fadeOutGroup.callback = nil
      callback()
    end
  end
  self.fadeOutGroup:Play()
end

function BankSlots.bankSlotsPanelProto:IsShown()
  return self.frame:IsShown()
end

-- SelectTab selects the given bank tab slot and triggers a filtered bank
-- refresh so only items from that specific Blizzard tab are shown.
---@param ctx Context
---@param bagIndex number
function BankSlots.bankSlotsPanelProto:SelectTab(ctx, bagIndex)
  -- Deselect all, then select the target button
  for _, btn in ipairs(self.buttons) do
    btn:SetSelected(btn.bagIndex == bagIndex)
  end
  self.selectedBagIndex = bagIndex

  -- Delegate to the bank behavior which sets blizzardBankTab and triggers refresh
  if addon.Bags and addon.Bags.Bank and addon.Bags.Bank.behavior then
    addon.Bags.Bank.behavior:SwitchToBlizzardTab(ctx, bagIndex)
  end
end

-- SelectFirstTab auto-selects the first bank tab slot when the panel opens.
---@param ctx Context
function BankSlots.bankSlotsPanelProto:SelectFirstTab(ctx)
  if #self.buttons > 0 then
    self:SelectTab(ctx, self.buttons[1].bagIndex)
  end
end

-- OpenTabConfig opens the Blizzard tab configuration dialog for the given
-- bank tab. Uses BankPanel.TabSettingsMenu for character bank tabs and
-- AccountBankPanel.TabSettingsMenu for account/warbank tabs.
---@param bagIndex number
function BankSlots.bankSlotsPanelProto:OpenTabConfig(bagIndex)
  local bagFrame = addon.Bags and addon.Bags.Bank and addon.Bags.Bank.frame

  -- Determine bank type: account bank tabs start at AccountBankTab_1
  local isAccountTab = Enum.BagIndex.AccountBankTab_1 and bagIndex >= Enum.BagIndex.AccountBankTab_1

  -- Re-connect the icon selector callback so that clicking an icon in the grid
  -- updates the selected-icon preview.  After reparenting and Update() calls the
  -- callback set in OnLoad can become stale; explicitly re-setting it here ensures
  -- icon selection always works.
  ---@param menu table The TabSettingsMenu frame
  local function reconnectIconCallback(menu)
    if not (menu.IconSelector and menu.BorderBox and menu.BorderBox.SelectedIconArea) then return end
    local previewButton = menu.BorderBox.SelectedIconArea.SelectedIconButton
    local descText = menu.BorderBox.SelectedIconArea.SelectedIconText
      and menu.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription
    if previewButton and menu.IconSelector.SetSelectedCallback then
      menu.IconSelector:SetSelectedCallback(function(_, icon)
        previewButton:SetIconTexture(icon)
        if descText then
          if ICON_SELECTION_CLICK then
            descText:SetText(ICON_SELECTION_CLICK)
          end
          descText:SetFontObject(GameFontHighlightSmall)
        end
      end)
    end
  end

  -- Populate selectedTabData directly from C_Bank API so Update() can run even
  -- when BankPanel.purchasedBankTabData has not yet been populated (e.g. the first
  -- time the bank is opened and BankPanel was hidden during BANKFRAME_OPENED).
  ---@param menu table The TabSettingsMenu frame
  ---@param bankType BankType Enum.BankType value for the tab
  ---@param id number bagIndex to look up
  local function ensureSelectedTabData(menu, bankType, id)
    -- Reset so SetSelectedTab always performs a fresh lookup (bypasses the
    -- "alreadySelected" early-exit which could skip the data refresh).
    menu.selectedTabData = nil
    menu:SetSelectedTab(id)
    -- Fallback: if BankPanel.purchasedBankTabData was empty, fetch directly.
    if not menu.selectedTabData and C_Bank and C_Bank.FetchPurchasedBankTabData then
      local tabList = C_Bank.FetchPurchasedBankTabData(bankType)
      if tabList then
        for _, tab in ipairs(tabList) do
          if tab.ID == id then
            menu.selectedTabData = tab
            break
          end
        end
      end
    end
  end

  if isAccountTab then
    -- Account/warbank tab: use AccountBankPanel.TabSettingsMenu
    if AccountBankPanel and AccountBankPanel.TabSettingsMenu then
      local menu = AccountBankPanel.TabSettingsMenu
      if bagFrame then
        menu:SetParent(bagFrame)
        menu:ClearAllPoints()
        menu:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMRIGHT", 10, 0)
        -- Keep GetBankFrame override so the menu can look up tab data via the
        -- real AccountBankPanel hierarchy when needed.
        menu.GetBankFrame = function()
          return {
            GetTabData = function(_, id)
              if C_Bank and C_Bank.FetchPurchasedBankTabData then
                local tabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
                if tabs then
                  for _, tab in ipairs(tabs) do
                    if tab.ID == id then return tab end
                  end
                end
              end
              return nil
            end,
          }
        end
      end
      ensureSelectedTabData(menu, Enum.BankType.Account, bagIndex)
      menu:Show()
      if menu.Update then menu:Update() end
      reconnectIconCallback(menu)
    end
  else
    -- Character bank tab: use BankPanel.TabSettingsMenu (added in The War Within)
    if BankPanel and BankPanel.TabSettingsMenu then
      local menu = BankPanel.TabSettingsMenu
      if bagFrame then
        menu:SetParent(bagFrame)
        menu:ClearAllPoints()
        menu:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMRIGHT", 10, 0)
      end
      ensureSelectedTabData(menu, Enum.BankType.Character, bagIndex)
      menu:Show()
      if menu.Update then menu:Update() end
      reconnectIconCallback(menu)
    end
  end
end

-- CreatePanel creates the bank tab slots panel, attaches it above the given
-- bag frame, and returns it. Returns nil on non-retail clients.
---@param ctx Context
---@param bagFrame Frame
---@return bankSlotsPanel?
function BankSlots:CreatePanel(ctx, bagFrame)
  if not addon.isRetail then
    return nil
  end
  local _ = ctx

  ---@class bankSlotsPanel
  local b = {}
  setmetatable(b, {__index = BankSlots.bankSlotsPanelProto})

  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", "BetterBagsBankSlots", bagFrame)
  b.frame = f

  themes:RegisterFlatWindow(f, L:G("Bank Tabs"))

  b.content = grid:Create(b.frame)
  b.content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET + 4, -30)
  b.content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, 12)
  -- Allow all 11 slots on one row
  b.content.maxCellWidth = 11
  b.content:HideScrollBar()
  -- Bank tab slots grid is not scrollable; disable mouse wheel so scroll
  -- events pass through to the outer scrollable bag container.
  b.content:EnableMouseWheelScroll(false)
  b.content:Show()

  b.buttons = {}
  b.selectedBagIndex = nil

  -- All possible bank tab slots in order:
  --   6 character bank tabs (CharacterBankTab_1 through _6)
  --   5 account/warbank tabs (AccountBankTab_1 through _5)
  local allTabSlots = {
    {bagIndex = Enum.BagIndex.CharacterBankTab_1, bankType = Enum.BankType.Character},
    {bagIndex = Enum.BagIndex.CharacterBankTab_2, bankType = Enum.BankType.Character},
    {bagIndex = Enum.BagIndex.CharacterBankTab_3, bankType = Enum.BankType.Character},
    {bagIndex = Enum.BagIndex.CharacterBankTab_4, bankType = Enum.BankType.Character},
    {bagIndex = Enum.BagIndex.CharacterBankTab_5, bankType = Enum.BankType.Character},
    {bagIndex = Enum.BagIndex.CharacterBankTab_6, bankType = Enum.BankType.Character},
    {bagIndex = Enum.BagIndex.AccountBankTab_1, bankType = Enum.BankType.Account},
    {bagIndex = Enum.BagIndex.AccountBankTab_2, bankType = Enum.BankType.Account},
    {bagIndex = Enum.BagIndex.AccountBankTab_3, bankType = Enum.BankType.Account},
    {bagIndex = Enum.BagIndex.AccountBankTab_4, bankType = Enum.BankType.Account},
    {bagIndex = Enum.BagIndex.AccountBankTab_5, bankType = Enum.BankType.Account},
  }

  for i, slotInfo in ipairs(allTabSlots) do
    ---@type BankSlotButton
    local btn = {}
    setmetatable(btn, {__index = bankSlotButtonProto})
    btn.bagIndex = slotInfo.bagIndex
    btn.bankType = slotInfo.bankType
    btn.purchased = false
    btn.isSelected = false

    buttonCount = buttonCount + 1
    local frameName = format("BetterBagsBankSlotButton%d", buttonCount)
    local buttonFrame = CreateFrame("Button", frameName, b.frame)
    buttonFrame:SetSize(37, 37)
    buttonFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Empty slot background texture
    local emptyBg = buttonFrame:CreateTexture(nil, "BACKGROUND")
    emptyBg:SetAllPoints()
    emptyBg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
    emptyBg:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.emptyBg = emptyBg

    -- Icon texture displayed when the tab has been purchased
    local iconTex = buttonFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconTex:Hide()
    btn.iconTexture = iconTex

    -- Highlight shown when this tab slot is selected
    local selectedHL = buttonFrame:CreateTexture(nil, "OVERLAY")
    selectedHL:SetAllPoints()
    selectedHL:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    selectedHL:SetBlendMode("ADD")
    selectedHL:Hide()
    btn.selectedHighlight = selectedHL

    -- Atlas texture for unpurchased tab slots.  SetAtlas ignores anchor-based sizing
    -- (SetAllPoints) and falls back to the atlas's native dimensions, which are smaller
    -- than the 37×37 button.  Use explicit SetPoint + SetSize BEFORE SetAtlas so the
    -- rendered size is controlled by us, not by the atlas metadata — matching the same
    -- pattern used for icon textures in tabs.lua and item.lua.
    local plusIcon = buttonFrame:CreateTexture(nil, "ARTWORK")
    plusIcon:SetPoint("CENTER", buttonFrame, "CENTER", 0, 0)
    plusIcon:SetSize(37, 37)
    plusIcon:SetAtlas("Garr_Building-AddFollowerPlus")
    plusIcon:Hide()
    btn.plusText = plusIcon

    btn.frame = buttonFrame

    -- Capture loop variables for use in closures below
    local capturedBtn = btn
    local capturedPanel = b
    local capturedSlotInfo = slotInfo

    buttonFrame:SetScript("OnClick", function(_, mouseButton)
      if mouseButton == "RightButton" then
        -- Right-click: open Blizzard tab configuration (purchased tabs only)
        if capturedBtn.purchased then
          capturedPanel:OpenTabConfig(capturedBtn.bagIndex)
        end
      else
        -- Left-click: select this tab and filter bank to its items
        local ectx = context:New('BankSlotSelect')
        capturedPanel:SelectTab(ectx, capturedBtn.bagIndex)
      end
    end)

    buttonFrame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(buttonFrame, "ANCHOR_LEFT")
      -- Look up tab name from C_Bank if available
      local tabData
      if C_Bank and C_Bank.FetchPurchasedBankTabData then
        local tabs = C_Bank.FetchPurchasedBankTabData(capturedSlotInfo.bankType)
        if tabs then
          for _, tab in ipairs(tabs) do
            if tab.ID == capturedSlotInfo.bagIndex then
              tabData = tab
              break
            end
          end
        end
      end
      if tabData then
        GameTooltip:SetText(tabData.name, 1, 1, 1, 1, true)
        if capturedSlotInfo.bankType == Enum.BankType.Character then
          GameTooltip:AddLine(L:G("Bank"), 0.6, 0.8, 1.0, true)
        else
          GameTooltip:AddLine(L:G("Warbank"), 1.0, 0.85, 0.1, true)
        end
        GameTooltip:AddLine(L:G("Left-click to view this tab"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L:G("Right-click to configure this tab"), 0.8, 0.8, 0.8, true)
      elseif capturedSlotInfo.bankType == Enum.BankType.Character then
        GameTooltip:SetText(L:G("Unpurchased Bank Tab"), 1, 1, 1, 1, true)
      else
        GameTooltip:SetText(L:G("Unpurchased Warbank Tab"), 1, 1, 1, 1, true)
      end
      GameTooltip:Show()
    end)

    buttonFrame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    b.content:AddCell(tostring(i), btn)
    table.insert(b.buttons, btn)
  end

  b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeAndSlideTop(b.frame)

  -- When fade-in finishes, auto-select the first bank tab
  addon.HookScript(b.fadeInGroup, "OnFinished", function(ectx)
    b:SelectFirstTab(ectx)
  end)

  -- When fade-out finishes, clear the blizzardBankTab filter and restore normal view
  addon.HookScript(b.fadeOutGroup, "OnFinished", function(ectx)
    -- Deselect all buttons
    for _, btn in ipairs(b.buttons) do
      btn:SetSelected(false)
    end
    b.selectedBagIndex = nil
    -- Clear the single-tab filter and refresh the bank to show all items
    if addon.Bags and addon.Bags.Bank then
      addon.Bags.Bank.blizzardBankTab = nil
      items:ClearBankCache(ectx)
      events:SendMessage(ectx, 'bags/RefreshBank')
    end
  end)

  -- Redraw when tab settings are updated (name/icon changed)
  events:RegisterEvent('BANK_TAB_SETTINGS_UPDATED', function(ectx)
    if b:IsShown() then
      b:Draw(ectx)
    end
  end)

  -- Redraw when a bank tab is purchased
  events:RegisterEvent('PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED', function(ectx)
    if b:IsShown() then
      b:Draw(ectx)
    end
  end)

  b.frame:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", 0, 8)
  b.frame:Hide()
  return b
end
