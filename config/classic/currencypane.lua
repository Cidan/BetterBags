---@diagnostic disable: duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class List: AceModule
local list = addon:GetModule('List')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class CurrencyPane: AceModule
local currencyPane = addon:NewModule('CurrencyPane')

---@class CurrencyPaneListButton: Button
---@field CurrencyIcon Texture
---@field CurrencyName FontString
---@field CurrencyCount FontString
---@field Init boolean

---@class CurrencyPaneFrame
---@field frame Frame
---@field listFrame ListFrame
---@field detailFrame Frame
---@field selectedIndex number|nil
---@field selectedButton CurrencyPaneListButton|nil
local currencyPaneProto = {}

---@param ref number
---@return CurrencyInfo
local function getCurrencyInfo(ref)
  local name, isHeader, isExpanded,
  isUnused, isWatched, count, icon,
  maximum, hasWeeklyLimit,
  currentWeeklyAmount, unknown, itemID = GetCurrencyListInfo(ref)
  return {
    name = name,
    isHeader = isHeader,
    isHeaderExpanded = isExpanded,
    isTypeUnused = isUnused,
    isShowInBackpack = isWatched,
    quantity = count,
    iconFileID = icon,
    maxQuantity = maximum,
    canEarnPerWeek = hasWeeklyLimit,
    quantityEarnedThisWeek = currentWeeklyAmount,
    unknown = unknown,
    itemID = itemID
  }
end

---@param button CurrencyPaneListButton
---@param elementData table
function currencyPaneProto:initListItem(button, elementData)
  if not button.Init then
    button.Init = true
    button:SetHeight(30)
    -- Apply backdrop mixin if not already applied
    if not button.SetBackdrop then
      Mixin(button, BackdropTemplateMixin)
    end

    button.CurrencyIcon = button:CreateTexture(nil, "ARTWORK")
    button.CurrencyIcon:SetSize(20, 20)
    button.CurrencyIcon:SetPoint("LEFT", button, "LEFT", 5, 0)

    button.CurrencyName = button:CreateFontString(nil, "OVERLAY")
    button.CurrencyName:SetHeight(30)
    button.CurrencyName:SetJustifyH("LEFT")
    button.CurrencyName:SetPoint("LEFT", button.CurrencyIcon, "RIGHT", 5, 0)
    button.CurrencyName:SetPoint("RIGHT", button, "RIGHT", -50, 0)

    button.CurrencyCount = button:CreateFontString(nil, "OVERLAY")
    button.CurrencyCount:SetHeight(30)
    button.CurrencyCount:SetJustifyH("RIGHT")
    button.CurrencyCount:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.CurrencyCount:SetFontObject(fonts.UnitFrame12White)

    button:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0)
  end

  local info = elementData.info
  local isHeader = info.isHeader
  local isShownInBackpack = info.isShowInBackpack

  -- Icon
  if info.iconFileID then
    button.CurrencyIcon:SetTexture(info.iconFileID)
    button.CurrencyIcon:Show()
  else
    button.CurrencyIcon:Hide()
  end

  -- Font styling based on header state
  if isHeader then
    button.CurrencyName:SetFontObject(fonts.UnitFrame12Yellow)
    button.CurrencyCount:SetText("")
  else
    button.CurrencyName:SetFontObject(fonts.UnitFrame12White)
    button.CurrencyCount:SetText(BreakUpLargeNumbers(info.quantity or 0))
  end

  -- Background based on selection and shown-in-backpack state
  if self.selectedIndex == elementData.index then
    button:SetBackdropColor(1, 0.82, 0, 0.3)
    self.selectedButton = button
  elseif isShownInBackpack then
    -- Yellow background highlight for currencies shown in backpack (like old list)
    button:SetBackdropColor(1, 1, 0, 0.2)
  elseif not isHeader then
    button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
  else
    button:SetBackdropColor(0, 0, 0, 0)
  end

  button.CurrencyName:SetText(info.name or "")

  -- Click handler to select currency (not headers)
  if not isHeader then
    button:SetScript("OnClick", function()
      self:SelectCurrency(elementData.index)
    end)

    button:SetScript("OnEnter", function()
      -- Only show hover highlight for non-selected items that aren't shown in backpack
      if self.selectedIndex ~= elementData.index and not isShownInBackpack then
        button:SetBackdropColor(0.3, 0.3, 0.3, 0.5)
      end
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:SetCurrencyToken(elementData.index)
      GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
      if self.selectedIndex == elementData.index then
        button:SetBackdropColor(1, 0.82, 0, 0.3)
      elseif isShownInBackpack then
        button:SetBackdropColor(1, 1, 0, 0.2)
      else
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
      end
      GameTooltip:Hide()
    end)
  else
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", nil)
    button:SetScript("OnLeave", nil)
  end
end

---@param button CurrencyPaneListButton
---@param elementData table
function currencyPaneProto:resetListItem(button, elementData)
  _ = elementData
  button:SetScript("OnClick", nil)
  button:SetScript("OnEnter", nil)
  button:SetScript("OnLeave", nil)
end

---@param index number
function currencyPaneProto:SelectCurrency(index)
  -- Deselect previous
  if self.selectedButton then
    local prevIndex = self.selectedIndex
    if prevIndex then
      local prevInfo = getCurrencyInfo(prevIndex)
      if prevInfo and prevInfo.isShowInBackpack then
        self.selectedButton:SetBackdropColor(1, 1, 0, 0.2)
      else
        self.selectedButton:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
      end
    end
  end

  self.selectedIndex = index
  self:UpdateDetailPanel()

  -- Refresh the list to update selection highlight
  self.listFrame.ScrollBox:ForEachFrame(function(button)
    ---@cast button CurrencyPaneListButton
    local elementData = button:GetElementData()
    if elementData and elementData.index == index then
      button:SetBackdropColor(1, 0.82, 0, 0.3)
      self.selectedButton = button
    end
  end)
end

function currencyPaneProto:UpdateDetailPanel()
  -- Clear existing detail content
  if self.detailContent then
    self.detailContent:Hide()
  end

  if not self.selectedIndex then
    self:ShowEmptyDetail()
    return
  end

  local info = getCurrencyInfo(self.selectedIndex)

  if info and info.name and not info.isHeader then
    self:ShowCurrencyDetail(self.selectedIndex, info)
  else
    self:ShowEmptyDetail()
  end
end

function currencyPaneProto:ShowEmptyDetail()
  if not self.emptyDetail then
    self.emptyDetail = CreateFrame("Frame", nil, self.detailFrame)
    self.emptyDetail:SetAllPoints()

    local text = self.emptyDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(L:G("Select a currency to view its details"))
    text:SetTextColor(0.5, 0.5, 0.5)
  end
  self.emptyDetail:Show()
  self.detailContent = self.emptyDetail
end

---@param index number
---@param info CurrencyInfo
function currencyPaneProto:ShowCurrencyDetail(index, info)
  if self.emptyDetail then self.emptyDetail:Hide() end

  if not self.currencyDetail then
    self:CreateCurrencyDetailPanel()
  end

  self.currencyDetail:Show()
  self.detailContent = self.currencyDetail

  -- Populate fields
  self.currencyDetail.nameLabel:SetText(info.name or "")

  -- Icon
  if info.iconFileID then
    self.currencyDetail.icon:SetTexture(info.iconFileID)
    self.currencyDetail.icon:Show()
  else
    self.currencyDetail.icon:Hide()
  end

  -- Quantity
  self.currencyDetail.quantityLabel:SetText(L:G("Quantity") .. ": " .. BreakUpLargeNumbers(info.quantity or 0))

  -- Max quantity if applicable
  if info.maxQuantity and info.maxQuantity > 0 then
    self.currencyDetail.maxQuantityLabel:SetText(L:G("Maximum") .. ": " .. BreakUpLargeNumbers(info.maxQuantity))
    self.currencyDetail.maxQuantityLabel:Show()
  else
    self.currencyDetail.maxQuantityLabel:Hide()
  end

  -- Weekly limit info
  if info.canEarnPerWeek then
    self.currencyDetail.weeklyLabel:SetText(L:G("Earned this week") .. ": " .. BreakUpLargeNumbers(info.quantityEarnedThisWeek or 0))
    self.currencyDetail.weeklyLabel:Show()
  else
    self.currencyDetail.weeklyLabel:Hide()
  end

  -- Update toggle button state
  local isShown = info.isShowInBackpack
  if isShown then
    self.currencyDetail.toggleButton:SetText(L:G("Hide in Backpack"))
    self.currencyDetail.statusLabel:SetText(L:G("Shown in backpack"))
    self.currencyDetail.statusLabel:SetTextColor(0.2, 0.8, 0.2)
  else
    self.currencyDetail.toggleButton:SetText(L:G("Show in Backpack"))
    self.currencyDetail.statusLabel:SetText(L:G("Hidden from backpack"))
    self.currencyDetail.statusLabel:SetTextColor(0.7, 0.7, 0.7)
  end

  -- Store the index for the toggle button
  self.currencyDetail.currentIndex = index
end

function currencyPaneProto:CreateCurrencyDetailPanel()
  self.currencyDetail = CreateFrame("Frame", nil, self.detailFrame)
  self.currencyDetail:SetAllPoints()

  local yOffset = -10

  -- Currency Icon (large)
  local icon = self.currencyDetail:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 10, yOffset)
  self.currencyDetail.icon = icon

  -- Currency Name (large title, next to icon)
  local nameLabel = self.currencyDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nameLabel:SetPoint("LEFT", icon, "RIGHT", 10, 0)
  nameLabel:SetPoint("RIGHT", self.currencyDetail, "RIGHT", -10, 0)
  nameLabel:SetJustifyH("LEFT")
  nameLabel:SetTextColor(1, 0.82, 0)
  self.currencyDetail.nameLabel = nameLabel

  yOffset = yOffset - 50

  -- Divider
  local divider = self.currencyDetail:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", 10, yOffset)
  divider:SetPoint("RIGHT", self.currencyDetail, "RIGHT", -10, 0)
  divider:SetHeight(1)
  divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)

  yOffset = yOffset - 20

  -- Quantity Label
  local quantityLabel = self.currencyDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  quantityLabel:SetPoint("TOPLEFT", 10, yOffset)
  quantityLabel:SetJustifyH("LEFT")
  self.currencyDetail.quantityLabel = quantityLabel

  yOffset = yOffset - 20

  -- Max Quantity Label
  local maxQuantityLabel = self.currencyDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  maxQuantityLabel:SetPoint("TOPLEFT", 10, yOffset)
  maxQuantityLabel:SetJustifyH("LEFT")
  self.currencyDetail.maxQuantityLabel = maxQuantityLabel

  yOffset = yOffset - 20

  -- Weekly Label
  local weeklyLabel = self.currencyDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  weeklyLabel:SetPoint("TOPLEFT", 10, yOffset)
  weeklyLabel:SetJustifyH("LEFT")
  self.currencyDetail.weeklyLabel = weeklyLabel

  yOffset = yOffset - 30

  -- Status Label
  local statusTitle = self.currencyDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  statusTitle:SetPoint("TOPLEFT", 10, yOffset)
  statusTitle:SetText(L:G("Status") .. ":")
  statusTitle:SetTextColor(0.9, 0.9, 0.9)

  local statusLabel = self.currencyDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  statusLabel:SetPoint("LEFT", statusTitle, "RIGHT", 10, 0)
  self.currencyDetail.statusLabel = statusLabel

  yOffset = yOffset - 40

  -- Toggle Button
  local toggleButton = CreateFrame("Button", nil, self.currencyDetail, "UIPanelButtonTemplate")
  toggleButton:SetPoint("TOPLEFT", 10, yOffset)
  toggleButton:SetSize(150, 25)
  toggleButton:SetText(L:G("Show in Backpack"))
  toggleButton:SetScript("OnClick", function()
    if self.currencyDetail.currentIndex then
      local info = getCurrencyInfo(self.currencyDetail.currentIndex)
      if info and info.name then
        -- Classic uses 0/1 instead of true/false
        if info.isShowInBackpack then
          SetCurrencyBackpack(self.currencyDetail.currentIndex, 0)
        else
          SetCurrencyBackpack(self.currencyDetail.currentIndex, 1)
        end
        -- Refresh after a short delay to allow the game to update
        C_Timer.After(0.1, function()
          self:RefreshList()
          self:UpdateDetailPanel()
          -- Notify the icon grid to update
          local ctx = context:New('CurrencyPane_Toggle')
          events:SendMessage(ctx, 'currency/Updated')
        end)
      end
    end
  end)
  self.currencyDetail.toggleButton = toggleButton
end

function currencyPaneProto:RefreshList()
  self.listFrame:Wipe()

  -- Get all currencies
  local listSize = GetCurrencyListSize()

  for i = 1, listSize do
    local info = getCurrencyInfo(i)
    if info and info.name then
      -- Note: Classic doesn't support ExpandCurrencyList in the same way
      -- Headers are typically pre-expanded or don't exist in classic
      self.listFrame:AddToStart({ index = i, info = info })
    end
  end
end

---@param parent Frame
---@return Frame
function currencyPane:Create(parent)
  local pane = setmetatable({}, { __index = currencyPaneProto })

  -- Create main frame
  pane.frame = CreateFrame("Frame", nil, parent)
  pane.frame:SetAllPoints()

  -- Create list frame (left side)
  -- Width: 200 for content + 18 for scrollbar outside = 218
  local listContainer = CreateFrame("Frame", nil, pane.frame)
  listContainer:SetPoint("TOPLEFT", 0, 0)
  listContainer:SetPoint("BOTTOMLEFT", 0, 0)
  listContainer:SetWidth(218)

  pane.listFrame = list:Create(listContainer)
  pane.listFrame.frame:SetPoint("TOPLEFT", 0, 0)
  pane.listFrame.frame:SetPoint("BOTTOMRIGHT", 0, 0)

  pane.listFrame:SetupDataSource("BetterBagsPlainTextListButton", function(f, data)
    ---@cast f CurrencyPaneListButton
    pane:initListItem(f, data)
  end, function(f, data)
    ---@cast f CurrencyPaneListButton
    pane:resetListItem(f, data)
  end)

  -- Create detail frame (right side)
  pane.detailFrame = CreateFrame("Frame", nil, pane.frame)
  pane.detailFrame:SetPoint("TOPLEFT", listContainer, "TOPRIGHT", 10, 0)
  pane.detailFrame:SetPoint("BOTTOMRIGHT", 0, 0)

  -- Register for currency updates
  pane.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
  pane.frame:SetScript("OnEvent", function(_, event)
    if event == "CURRENCY_DISPLAY_UPDATE" then
      if pane.frame:IsShown() then
        pane:RefreshList()
        pane:UpdateDetailPanel()
      end
    end
  end)

  -- Initial load - delay to allow parent frame to finish layout
  pane.frame:SetScript("OnShow", function()
    -- Only run once on first show
    if not pane.initialized then
      pane.initialized = true
      -- Use C_Timer.After(0) to defer until the next frame when parent layout is complete.
      -- This ensures the list container has its proper height calculated before RefreshList.
      C_Timer.After(0, function()
        pane:RefreshList()
        pane:UpdateDetailPanel()
      end)
    else
      -- Refresh on subsequent shows to catch any currency changes
      pane:RefreshList()
      pane:UpdateDetailPanel()
    end
  end)

  -- Handle size changes to ensure the list updates when pane dimensions are set.
  -- This fixes intermittent issues where the list extends beyond the pane boundaries.
  pane.frame:SetScript("OnSizeChanged", function()
    if pane.initialized and pane.listFrame and pane.listFrame.ScrollBox then
      -- Trigger a full update on the list's ScrollBox to recalculate its extent
      if pane.listFrame.ScrollBox.FullUpdate then
        pane.listFrame.ScrollBox:FullUpdate(true)
      end
    end
  end)

  return pane.frame
end
