local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class List: AceModule
local list = addon:GetModule('List')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class ThemePane: AceModule
local themePane = addon:NewModule('ThemePane')

---@class ThemePaneListButton: Button
---@field ThemeName FontString
---@field CheckmarkIcon Texture
---@field Init boolean

---@class ThemePaneFrame
---@field frame Frame
---@field listFrame ListFrame
---@field detailFrame Frame
---@field selectedTheme string|nil
---@field selectedButton ThemePaneListButton|nil
local themePaneProto = {}

---@param button ThemePaneListButton
---@param elementData table
function themePaneProto:initListItem(button, elementData)
  if not button.Init then
    button.Init = true
    button:SetHeight(30)
    -- Apply backdrop mixin if not already applied
    if not button.SetBackdrop then
      Mixin(button, BackdropTemplateMixin)
    end
    button.ThemeName = button:CreateFontString(nil, "OVERLAY")
    button.ThemeName:SetHeight(30)
    button.ThemeName:SetJustifyH("LEFT")
    button.ThemeName:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.ThemeName:SetPoint("RIGHT", button, "RIGHT", -25, 0)

    -- Checkmark icon for currently active theme
    button.CheckmarkIcon = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.CheckmarkIcon:SetSize(16, 16)
    button.CheckmarkIcon:SetPoint("RIGHT", button, "RIGHT", -5, 0)
    button.CheckmarkIcon:SetAtlas("common-icon-checkmark")
    button.CheckmarkIcon:SetAlpha(1)
    button.CheckmarkIcon:Hide()

    button:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0)
  end

  local currentTheme = database:GetTheme()
  local isCurrentTheme = elementData.key == currentTheme

  -- Font styling - uniform white for all themes
  button.ThemeName:SetFontObject(fonts.UnitFrame12White)

  -- Checkmark for currently active theme
  if isCurrentTheme then
    button.CheckmarkIcon:Show()
  else
    button.CheckmarkIcon:Hide()
  end

  -- Background based on selection state only
  if self.selectedTheme == elementData.key then
    button:SetBackdropColor(1, 0.82, 0, 0.3)
    self.selectedButton = button
  elseif elementData.theme.Available then
    button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
  else
    button:SetBackdropColor(0, 0, 0, 0)
  end

  button.ThemeName:SetText(elementData.theme.Name)

  -- Click handler to select theme
  button:SetScript("OnClick", function()
    self:SelectTheme(elementData.key)
  end)

  button:SetScript("OnEnter", function()
    if self.selectedTheme ~= elementData.key then
      button:SetBackdropColor(0.3, 0.3, 0.3, 0.5)
    end
  end)

  button:SetScript("OnLeave", function()
    if self.selectedTheme == elementData.key then
      button:SetBackdropColor(1, 0.82, 0, 0.3)
    elseif elementData.theme.Available then
      button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    else
      button:SetBackdropColor(0, 0, 0, 0)
    end
  end)
end

---@param button ThemePaneListButton
---@param elementData table
function themePaneProto:resetListItem(button, elementData)
  local _ = elementData
  button:SetScript("OnClick", nil)
  button:SetScript("OnEnter", nil)
  button:SetScript("OnLeave", nil)
end

---@param themeKey string
function themePaneProto:SelectTheme(themeKey)
  -- Deselect previous
  if self.selectedButton then
    local prevTheme = self.selectedTheme
    local allThemes = themes:GetAllThemes()
    if prevTheme and allThemes[prevTheme] and allThemes[prevTheme].Available then
      self.selectedButton:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    else
      self.selectedButton:SetBackdropColor(0, 0, 0, 0)
    end
  end

  self.selectedTheme = themeKey
  self:UpdateDetailPanel()

  -- Refresh the list to update selection highlight
  self.listFrame.ScrollBox:ForEachFrame(function(button)
    ---@cast button ThemePaneListButton
    local elementData = button:GetElementData()
    if elementData and elementData.key == themeKey then
      button:SetBackdropColor(1, 0.82, 0, 0.3)
      self.selectedButton = button
    end
  end)
end

function themePaneProto:UpdateDetailPanel()
  -- Clear existing detail content
  if self.detailContent then
    self.detailContent:Hide()
  end

  if not self.selectedTheme then
    self:ShowEmptyDetail()
    return
  end

  local allThemes = themes:GetAllThemes()
  local theme = allThemes[self.selectedTheme]

  if theme then
    self:ShowThemeDetail(self.selectedTheme, theme)
  else
    self:ShowEmptyDetail()
  end
end

function themePaneProto:ShowEmptyDetail()
  if not self.emptyDetail then
    self.emptyDetail = CreateFrame("Frame", nil, self.detailFrame)
    self.emptyDetail:SetAllPoints()

    local text = self.emptyDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Select a theme to view its details")
    text:SetTextColor(0.5, 0.5, 0.5)
  end
  self.emptyDetail:Show()
  self.detailContent = self.emptyDetail
end

---@param themeKey string
---@param theme Theme
function themePaneProto:ShowThemeDetail(themeKey, theme)
  if self.emptyDetail then self.emptyDetail:Hide() end

  if not self.themeDetail then
    self:CreateThemeDetailPanel()
  end

  self.themeDetail:Show()
  self.detailContent = self.themeDetail

  -- Populate fields
  self.themeDetail.nameLabel:SetText(theme.Name)
  self.themeDetail.descriptionLabel:SetText(theme.Description or "No description available.")

  -- Update status
  local currentTheme = database:GetTheme()
  local isActive = themeKey == currentTheme

  if isActive then
    self.themeDetail.statusLabel:SetText("Currently Active")
    self.themeDetail.statusLabel:SetTextColor(0.2, 0.8, 0.2)
    self.themeDetail.applyButton:SetEnabled(false)
    self.themeDetail.applyButton:SetText("Active")
  elseif theme.Available then
    self.themeDetail.statusLabel:SetText("Available")
    self.themeDetail.statusLabel:SetTextColor(0.7, 0.7, 0.7)
    self.themeDetail.applyButton:SetEnabled(true)
    self.themeDetail.applyButton:SetText("Apply Theme")
  else
    self.themeDetail.statusLabel:SetText("Unavailable")
    self.themeDetail.statusLabel:SetTextColor(0.6, 0.3, 0.3)
    self.themeDetail.applyButton:SetEnabled(false)
    self.themeDetail.applyButton:SetText("Unavailable")
  end

  -- Store the key for the apply button
  self.themeDetail.currentThemeKey = themeKey
end

function themePaneProto:CreateThemeDetailPanel()
  self.themeDetail = CreateFrame("Frame", nil, self.detailFrame)
  self.themeDetail:SetAllPoints()

  local yOffset = -10

  -- Theme Name (large title)
  local nameLabel = self.themeDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nameLabel:SetPoint("TOPLEFT", 10, yOffset)
  nameLabel:SetTextColor(1, 0.82, 0)
  self.themeDetail.nameLabel = nameLabel

  yOffset = yOffset - 30

  -- Divider
  local divider = self.themeDetail:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", 10, yOffset)
  divider:SetPoint("RIGHT", self.themeDetail, "RIGHT", -10, 0)
  divider:SetHeight(1)
  divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)

  yOffset = yOffset - 20

  -- Description Label
  local descTitle = self.themeDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  descTitle:SetPoint("TOPLEFT", 10, yOffset)
  descTitle:SetText("Description")
  descTitle:SetTextColor(0.9, 0.9, 0.9)

  yOffset = yOffset - 20

  -- Description Text
  local descriptionLabel = self.themeDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  descriptionLabel:SetPoint("TOPLEFT", 10, yOffset)
  descriptionLabel:SetPoint("RIGHT", self.themeDetail, "RIGHT", -10, 0)
  descriptionLabel:SetJustifyH("LEFT")
  descriptionLabel:SetWordWrap(true)
  descriptionLabel:SetNonSpaceWrap(true)
  self.themeDetail.descriptionLabel = descriptionLabel

  yOffset = yOffset - 60

  -- Status Label
  local statusTitle = self.themeDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  statusTitle:SetPoint("TOPLEFT", 10, yOffset)
  statusTitle:SetText("Status:")
  statusTitle:SetTextColor(0.9, 0.9, 0.9)

  local statusLabel = self.themeDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  statusLabel:SetPoint("LEFT", statusTitle, "RIGHT", 10, 0)
  self.themeDetail.statusLabel = statusLabel

  yOffset = yOffset - 40

  -- Apply Button
  local applyButton = CreateFrame("Button", nil, self.themeDetail, "UIPanelButtonTemplate")
  applyButton:SetPoint("TOPLEFT", 10, yOffset)
  applyButton:SetSize(120, 25)
  applyButton:SetText("Apply Theme")
  applyButton:SetScript("OnClick", function()
    if self.themeDetail.currentThemeKey then
      local ctx = context:New('ThemePane_ApplyTheme')
      themes:ApplyTheme(ctx, self.themeDetail.currentThemeKey)
      -- Refresh the list to update current theme highlighting
      self:RefreshList()
      -- Update the detail panel to reflect the new active state
      self:UpdateDetailPanel()
    end
  end)
  self.themeDetail.applyButton = applyButton
end

function themePaneProto:RefreshList()
  self.listFrame:Wipe()

  -- Get all themes and sort by name
  local allThemes = themes:GetAllThemes()
  local sortedThemes = {}
  for key, theme in pairs(allThemes) do
    table.insert(sortedThemes, { key = key, theme = theme })
  end
  table.sort(sortedThemes, function(a, b)
    return a.theme.Name < b.theme.Name
  end)

  -- Add themes to the list
  for _, themeData in ipairs(sortedThemes) do
    self.listFrame:AddToStart({ key = themeData.key, theme = themeData.theme })
  end
end

---@param parent Frame
---@return Frame
function themePane:Create(parent)
  local pane = setmetatable({}, { __index = themePaneProto })

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
    ---@cast f ThemePaneListButton
    pane:initListItem(f, data)
  end, function(f, data)
    ---@cast f ThemePaneListButton
    pane:resetListItem(f, data)
  end)

  -- Create detail frame (right side)
  pane.detailFrame = CreateFrame("Frame", nil, pane.frame)
  pane.detailFrame:SetPoint("TOPLEFT", listContainer, "TOPRIGHT", 10, 0)
  pane.detailFrame:SetPoint("BOTTOMRIGHT", 0, 0)

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
