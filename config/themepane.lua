local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class List: AceModule
local list = addon:GetModule('List')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- ThemePane is the settings window's theme picker: a list of themes and the picked one's details,
-- previewing a pick on the next frame and saving it only with Apply. It picks from an engine: Sonata
-- (the bags' themes, the Theme page) or SonataNext (BetterBags Next's themes, the Next Theme page,
-- next-themes.md), which answer the same calls (GetThemes, IsAvailable, IsSelectable,
-- GetCurrentThemeKey, GetSavedThemeKey, ApplyTheme, RestoreSavedTheme). Its own text is drawn with
-- the bags' theme's roles either way: the settings window is the bags' theme's.
---@class ThemePane: AceModule
local themePane = addon:NewModule('ThemePane')

---@class ThemeEngine
---@field GetThemes fun(self): table<string, table>
---@field IsAvailable fun(self, key: string): boolean
---@field IsSelectable fun(self, key: string): boolean
---@field GetCurrentThemeKey fun(self): string?
---@field GetSavedThemeKey fun(self): string
---@field ApplyTheme fun(self, ctx: Context, key: string, save?: boolean)
---@field RestoreSavedTheme fun(self, ctx: Context)

---@class ThemePaneListButton: Button
---@field ThemeName FontString
---@field CheckmarkIcon Texture
---@field Init boolean

-- A theme as the pane lists it.
---@class ThemePaneEntry
---@field key string The theme's key.
---@field name string Its display name.
---@field description string
---@field available boolean Its addon is loaded (it can be applied).
---@field active boolean It is the saved theme (the one in effect outside a preview).

---@class ThemePaneFrame
---@field engine ThemeEngine The themes it picks from.
---@field frame Frame
---@field listFrame ListFrame
---@field detailFrame Frame
---@field selectedTheme string|nil
---@field selectedButton ThemePaneListButton|nil
local themePaneProto = {}
addon:GetModule('Perf'):RegisterPrototype(themePaneProto, 'ThemePaneFrame')

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

  ---@cast elementData ThemePaneEntry
  sonata:SetTextRole(button.ThemeName, "Body")

  -- Checkmark for the applied theme
  if elementData.active then
    button.CheckmarkIcon:Show()
  else
    button.CheckmarkIcon:Hide()
  end

  -- Background based on selection state only
  if self.selectedTheme == elementData.key then
    button:SetBackdropColor(1, 0.82, 0, 0.3)
    self.selectedButton = button
  elseif elementData.available then
    button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
  else
    button:SetBackdropColor(0, 0, 0, 0)
  end

  button.ThemeName:SetText(elementData.name)

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
    elseif elementData.available then
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
    if prevTheme and self.engine:IsAvailable(prevTheme) then
      self.selectedButton:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    else
      self.selectedButton:SetBackdropColor(0, 0, 0, 0)
    end
  end

  self.selectedTheme = themeKey
  self:QueuePreview(themeKey)
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

-- QueuePreview previews a picked theme on the next frame: applying a theme restyles and resizes
-- the settings window, which must not happen inside the click on the theme list. A later pick
-- before then replaces it.
---@param themeKey string
function themePaneProto:QueuePreview(themeKey)
  self.pendingPreview = themeKey
  if self.previewQueued then
    return
  end
  self.previewQueued = true
  C_Timer.After(0, function()
    self.previewQueued = false
    local key = self.pendingPreview
    self.pendingPreview = nil
    if key ~= nil then
      self:Preview(key)
    end
  end)
end

-- Preview applies a picked theme without saving it; Apply saves it. Picking the saved theme or
-- one that cannot be applied shows the saved theme.
---@param themeKey string
function themePaneProto:Preview(themeKey)
  local ctx = context:New('ThemePane_Preview')
  local engine = self.engine
  if engine:IsSelectable(themeKey) then
    if engine:GetCurrentThemeKey() ~= themeKey then
      engine:ApplyTheme(ctx, themeKey, false)
    end
  else
    engine:RestoreSavedTheme(ctx)
  end
end

-- EndPreview puts the saved theme back and forgets the pick, when the pane hides (another
-- settings page, or the settings window closing).
---@param ctx Context
function themePaneProto:EndPreview(ctx)
  self.pendingPreview = nil
  self.engine:RestoreSavedTheme(ctx)
  self.selectedTheme = nil
  self.selectedButton = nil
  if self.initialized then
    self:RefreshList()
    self:UpdateDetailPanel()
  end
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

  local entry = themePane:Entry(self.selectedTheme, self.engine)
  if entry then
    self:ShowThemeDetail(entry)
  else
    self:ShowEmptyDetail()
  end
end

function themePaneProto:ShowEmptyDetail()
  if not self.emptyDetail then
    self.emptyDetail = CreateFrame("Frame", nil, self.detailFrame)
    self.emptyDetail:SetAllPoints()

    local text = sonata:CreateText(self.emptyDetail, "Empty")
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Select a theme to view its details")
  end
  self.emptyDetail:Show()
  self.detailContent = self.emptyDetail
end

---@param entry ThemePaneEntry
function themePaneProto:ShowThemeDetail(entry)
  if self.emptyDetail then self.emptyDetail:Hide() end

  if not self.themeDetail then
    self:CreateThemeDetailPanel()
  end

  self.themeDetail:Show()
  self.detailContent = self.themeDetail

  -- Populate fields
  self.themeDetail.nameLabel:SetText(entry.name)
  self.themeDetail.descriptionLabel:SetText(entry.description)

  if entry.active then
    self.themeDetail.statusLabel:SetText("Currently Active")
    sonata:SetTextRole(self.themeDetail.statusLabel, "Positive")
    self.themeDetail.applyButton:SetEnabled(false)
    self.themeDetail.applyButton:SetText("Active")
  elseif entry.available then
    self.themeDetail.statusLabel:SetText("Previewing")
    sonata:SetTextRole(self.themeDetail.statusLabel, "Description")
    self.themeDetail.applyButton:SetEnabled(true)
    self.themeDetail.applyButton:SetText("Apply Theme")
  else
    self.themeDetail.statusLabel:SetText("Unavailable")
    sonata:SetTextRole(self.themeDetail.statusLabel, "Negative")
    self.themeDetail.applyButton:SetEnabled(false)
    self.themeDetail.applyButton:SetText("Unavailable")
  end

  -- Store the key for the apply button
  self.themeDetail.currentThemeKey = entry.key
end

function themePaneProto:CreateThemeDetailPanel()
  self.themeDetail = CreateFrame("Frame", nil, self.detailFrame)
  self.themeDetail:SetAllPoints()

  local yOffset = -10

  -- Theme Name (large title)
  local nameLabel = sonata:CreateText(self.themeDetail, "Title")
  nameLabel:SetPoint("TOPLEFT", 10, yOffset)
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
  local descTitle = sonata:CreateText(self.themeDetail, "Body")
  descTitle:SetPoint("TOPLEFT", 10, yOffset)
  descTitle:SetText("Description")

  yOffset = yOffset - 20

  -- Description Text
  local descriptionLabel = sonata:CreateText(self.themeDetail, "Body")
  descriptionLabel:SetPoint("TOPLEFT", 10, yOffset)
  descriptionLabel:SetPoint("RIGHT", self.themeDetail, "RIGHT", -10, 0)
  descriptionLabel:SetJustifyH("LEFT")
  descriptionLabel:SetWordWrap(true)
  descriptionLabel:SetNonSpaceWrap(true)
  self.themeDetail.descriptionLabel = descriptionLabel

  yOffset = yOffset - 60

  -- Status Label
  local statusTitle = sonata:CreateText(self.themeDetail, "Body")
  statusTitle:SetPoint("TOPLEFT", 10, yOffset)
  statusTitle:SetText("Status:")

  local statusLabel = sonata:CreateText(self.themeDetail, "Body")
  statusLabel:SetPoint("LEFT", statusTitle, "RIGHT", 10, 0)
  self.themeDetail.statusLabel = statusLabel

  yOffset = yOffset - 40

  -- Apply Button
  local applyButton = CreateFrame("Button", nil, self.themeDetail, "UIPanelButtonTemplate")
  applyButton:SetPoint("TOPLEFT", 10, yOffset)
  applyButton:SetSize(120, 25)
  applyButton:SetText("Apply Theme")
  addon.SetScript(applyButton, "OnClick", function(ctx)
    if self.themeDetail.currentThemeKey then
      self.engine:ApplyTheme(ctx, self.themeDetail.currentThemeKey)
      -- Refresh the list to update current theme highlighting
      self:RefreshList()
      -- Update the detail panel to reflect the new active state
      self:UpdateDetailPanel()
    end
  end)
  self.themeDetail.applyButton = applyButton
end

-- RefreshList lists every theme its engine knows, by name.
function themePaneProto:RefreshList()
  self.listFrame:Wipe()
  for _, entry in ipairs(themePane:Entries(self.engine)) do
    self.listFrame:AddToEnd(entry)
  end
end

-- Entry describes the theme of key for the pane, or nil for a theme the engine (Sonata by default)
-- does not list.
---@param key string
---@param engine? ThemeEngine
---@return ThemePaneEntry?
function themePane:Entry(key, engine)
  engine = engine or sonata
  local theme = engine:GetThemes()[key]
  if theme == nil then
    return nil
  end
  return {
    key = key,
    name = theme.DisplayName or theme.Name,
    description = theme.Description or "No description available.",
    available = engine:IsAvailable(key),
    active = key == engine:GetSavedThemeKey(),
  }
end

-- Entries describes every theme the engine (Sonata by default) knows that is not hidden, those whose
-- addon is not loaded too, sorted by name.
---@param engine? ThemeEngine
---@return ThemePaneEntry[]
function themePane:Entries(engine)
  engine = engine or sonata
  local entries = {}
  for key in pairs(engine:GetThemes()) do
    table.insert(entries, self:Entry(key, engine))
  end
  table.sort(entries, function(a, b)
    return a.name < b.name
  end)
  return entries
end

-- Create returns the pane's frame, for the settings window: the bags' themes, or an engine's.
---@param parent Frame
---@param engine? ThemeEngine Sonata when unset.
---@return Frame
function themePane:Create(parent, engine)
  return self:New(parent, engine).frame
end

---@param parent Frame
---@param engine? ThemeEngine Sonata when unset.
---@return ThemePaneFrame
function themePane:New(parent, engine)
  local pane = setmetatable({}, { __index = themePaneProto })
  pane.engine = engine or sonata

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

  addon.SetScript(pane.frame, "OnHide", function(ctx)
    pane:EndPreview(ctx)
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

  return pane
end
