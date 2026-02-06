local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class List: AceModule
local list = addon:GetModule('List')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class ItemRowFrame: AceModule
local itemRowFrame = addon:GetModule('ItemRowFrame')

---@class CategoryPane: AceModule
local categoryPane = addon:NewModule('CategoryPane')

---@class CategoryPaneListButton: Button
---@field Category FontString
---@field Note FontString
---@field Init boolean

---@class CategoryPaneItemFrame: Frame
---@field item ItemRow

---@class CategoryPaneFrame
---@field frame Frame
---@field kind BagKind
---@field listFrame ListFrame
---@field detailFrame Frame
---@field itemListFrame ListFrame
---@field selectedCategory string|nil
---@field selectedButton CategoryPaneListButton|nil
local categoryPaneProto = {}

-- Mapping from enum value to display text
local groupByEnumToDisplayText = {
  [const.SEARCH_CATEGORY_GROUP_BY.NONE] = "None",
  [const.SEARCH_CATEGORY_GROUP_BY.TYPE] = "Type",
  [const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE] = "Subtype",
  [const.SEARCH_CATEGORY_GROUP_BY.EXPANSION] = "Expansion",
}

-- Mapping from query text to enum value (case-insensitive)
local groupByTextToEnum = {
  ["none"] = const.SEARCH_CATEGORY_GROUP_BY.NONE,
  ["type"] = const.SEARCH_CATEGORY_GROUP_BY.TYPE,
  ["subtype"] = const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE,
  ["expansion"] = const.SEARCH_CATEGORY_GROUP_BY.EXPANSION,
  ["exp"] = const.SEARCH_CATEGORY_GROUP_BY.EXPANSION,
}

-- Mapping from enum value to query text
local groupByEnumToText = {
  [const.SEARCH_CATEGORY_GROUP_BY.NONE] = "none",
  [const.SEARCH_CATEGORY_GROUP_BY.TYPE] = "type",
  [const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE] = "subtype",
  [const.SEARCH_CATEGORY_GROUP_BY.EXPANSION] = "expansion",
}

-- Pattern to match "group by <value>" at the end of a query (case-insensitive)
local groupByPattern = "%s+group%s+by%s+(%w+)%s*$"

---@param query string
---@return number|nil groupBy enum value if found, nil otherwise
local function parseGroupByFromQuery(query)
  local match = query:lower():match(groupByPattern)
  if match then
    return groupByTextToEnum[match]
  end
  return nil
end

---@param query string
---@return string query with group by clause stripped
local function stripGroupByFromQuery(query)
  local v, _ = query:gsub("%s+[Gg][Rr][Oo][Uu][Pp]%s+[Bb][Yy]%s+%w+%s*$", "")
  return v
end

---@param query string
---@param groupBy number
---@return string query with group by clause added/updated
local function setGroupByInQuery(query, groupBy)
  local cleanQuery = stripGroupByFromQuery(query)
  if groupBy == const.SEARCH_CATEGORY_GROUP_BY.NONE then
    return cleanQuery
  end
  local groupByText = groupByEnumToText[groupBy]
  if groupByText and cleanQuery ~= "" then
    return cleanQuery .. " group by " .. groupByText
  elseif groupByText then
    return "group by " .. groupByText
  end
  return cleanQuery
end

---@param button CategoryPaneListButton
---@param elementData table
function categoryPaneProto:initListItem(button, elementData)
  if not button.Init then
    button.Init = true
    button:SetHeight(30)
    -- Apply backdrop mixin if not already applied
    if not button.SetBackdrop then
      Mixin(button, BackdropTemplateMixin)
    end
    button.Category = button:CreateFontString(nil, "OVERLAY")
    button.Category:SetHeight(30)
    button.Category:SetJustifyH("LEFT")
    button.Category:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.Category:SetPoint("RIGHT", button, "RIGHT", -40, 0)
    button.Note = button:CreateFontString(nil, "OVERLAY")
    button.Note:SetHeight(30)
    button.Note:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.Note:SetTextColor(0.6, 0.6, 0.6, 1)
    button.Note:SetFontObject(fonts.UnitFrame12White)
    button:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0)
  end

  -- Header styling
  if elementData.header then
    button.Category:SetFontObject(fonts.UnitFrame12Yellow)
    button.Note:SetText("")
    button:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
  else
    button.Category:SetFontObject(fonts.UnitFrame12White)

    -- Show note based on category state
    local filter = categories:GetCategoryByName(elementData.title)
    if filter and filter.searchCategory then
      button.Note:SetText(format("P:%d", filter.priority or 0))
    else
      button.Note:SetText("")
    end

    -- Background based on selection state only
    if self.selectedCategory == elementData.title then
      button:SetBackdropColor(1, 0.82, 0, 0.3)
      self.selectedButton = button
    else
      button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
    end
  end

  button.Category:SetText(elementData.title)

  -- Click handler to select category
  if not elementData.header then
    button:SetScript("OnClick", function(_, mouseButton)
      if mouseButton == "LeftButton" then
        if IsShiftKeyDown() then
          -- Quick pin/unpin
          self.listFrame.provider:MoveElementDataToIndex(elementData, 2)
          self:UpdatePinnedItems()
          local ctx = context:New('CategoryPane_ShiftClick')
          events:SendMessage(ctx, 'bags/FullRefreshAll')
        else
          self:SelectCategory(elementData.title)
        end
      end
    end)

    button:SetScript("OnEnter", function()
      if self.selectedCategory ~= elementData.title then
        button:SetBackdropColor(0.3, 0.3, 0.3, 0.5)
      end
    end)

    button:SetScript("OnLeave", function()
      if self.selectedCategory == elementData.title then
        button:SetBackdropColor(1, 0.82, 0, 0.3)
      else
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
      end
    end)
  else
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", nil)
    button:SetScript("OnLeave", nil)
  end
end

---@param button CategoryPaneListButton
---@param elementData table
function categoryPaneProto:resetListItem(button, elementData)
  _ = elementData
  button:SetScript("OnClick", nil)
  button:SetScript("OnEnter", nil)
  button:SetScript("OnLeave", nil)
end

function categoryPaneProto:UpdatePinnedItems()
  local itemList = self.listFrame:GetAllItems()
  database:ClearCustomSectionSort(self.kind)
  local index, elementData = next(itemList)
  repeat
    if elementData.title ~= "Pinned" and not elementData.header then
      database:SetCustomSectionSort(self.kind, elementData.title, index - 1)
    end
    index, elementData = next(itemList, index)
  until elementData and elementData.title == "Automatically Sorted" and elementData.header
end

function categoryPaneProto:LoadPinnedItems()
  local pinnedList = database:GetCustomSectionSort(self.kind)
  ---@type {title: string, index: number}[]
  local sortedList = {}
  for title, index in pairs(pinnedList) do
    table.insert(sortedList, { title = title, index = index })
  end
  table.sort(sortedList, function(a, b)
    return a.index < b.index
  end)
  for _, element in ipairs(sortedList) do
    self.listFrame.provider:Insert({title = element.title})
  end
end

---@param category string
function categoryPaneProto:SelectCategory(category)
  -- Deselect previous
  if self.selectedButton then
    self.selectedButton:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
  end

  self.selectedCategory = category
  self:UpdateDetailPanel()

  -- Refresh the list to update selection highlight
  self.listFrame.ScrollBox:ForEachFrame(function(button)
    ---@cast button CategoryPaneListButton
    local elementData = button:GetElementData()
    if elementData and elementData.title == category then
      button:SetBackdropColor(1, 0.82, 0, 0.3)
      self.selectedButton = button
    end
  end)
end

-- ShowRenameCategoryDialog shows a dialog to rename a category.
---@param categoryName string
function categoryPaneProto:ShowRenameCategoryDialog(categoryName)
  if not categories:DoesCategoryExist(categoryName) then return end

  -- Define the static popup if not already defined
  if not StaticPopupDialogs["BETTERBAGS_RENAME_CATEGORY"] then
    StaticPopupDialogs["BETTERBAGS_RENAME_CATEGORY"] = {
      text = L:G("Enter new category name:"),
      hasEditBox = true,
      button1 = L:G("Rename"),
      button2 = L:G("Cancel"),
      OnAccept = function(f)
        local newName = f.EditBox:GetText()
        if newName and newName ~= "" then
          newName = strtrim(newName)
          local ctx = context:New("RenameCategory")
          local success = categories:RenameCategory(ctx, f.data.categoryName, newName)
          if success then
            -- Update selected category if it was the renamed one
            if f.data.pane.selectedCategory == f.data.categoryName then
              f.data.pane.selectedCategory = newName
            end
            f.data.pane:RefreshList()
            f.data.pane:UpdateDetailPanel()
          else
            -- Show error message
            print(format(L:G("Failed to rename category. A category named '%s' may already exist."), newName))
          end
        end
      end,
      OnShow = function(f)
        f.EditBox:SetText(f.data.categoryName)
        f.EditBox:HighlightText()
        f.EditBox:SetFocus()
      end,
      EditBoxOnEnterPressed = function(f)
        local parent = f:GetParent()
        local newName = parent.EditBox:GetText()
        if newName and newName ~= "" then
          newName = strtrim(newName)
          local ctx = context:New("RenameCategory")
          local success = categories:RenameCategory(ctx, parent.data.categoryName, newName)
          if success then
            -- Update selected category if it was the renamed one
            if parent.data.pane.selectedCategory == parent.data.categoryName then
              parent.data.pane.selectedCategory = newName
            end
            parent.data.pane:RefreshList()
            parent.data.pane:UpdateDetailPanel()
          else
            -- Show error message
            print(format(L:G("Failed to rename category. A category named '%s' may already exist."), newName))
          end
        end
        parent:Hide()
      end,
      EditBoxOnEscapePressed = function(f)
        f:GetParent():Hide()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end

  local dialog = StaticPopup_Show("BETTERBAGS_RENAME_CATEGORY")
  if dialog then
    dialog.data = { categoryName = categoryName, pane = self }
  end
end

function categoryPaneProto:UpdateDetailPanel()
  -- Clear existing detail content
  if self.detailContent then
    self.detailContent:Hide()
  end

  if not self.selectedCategory then
    self:ShowEmptyDetail()
    return
  end

  local filter = categories:GetCategoryByName(self.selectedCategory)

  if filter and filter.searchCategory then
    self:ShowSearchCategoryDetail(filter)
  elseif filter then
    self:ShowManualCategoryDetail(filter)
  else
    -- Dynamic or system category
    self:ShowDynamicCategoryDetail(self.selectedCategory)
  end
end

function categoryPaneProto:ShowEmptyDetail()
  if not self.emptyDetail then
    self.emptyDetail = CreateFrame("Frame", nil, self.detailFrame)
    self.emptyDetail:SetAllPoints()

    local text = self.emptyDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Select a category to view its settings")
    text:SetTextColor(0.5, 0.5, 0.5)
  end
  self.emptyDetail:Show()
  self.detailContent = self.emptyDetail
end

---@param filter CustomCategoryFilter
function categoryPaneProto:ShowSearchCategoryDetail(filter)
  if self.emptyDetail then self.emptyDetail:Hide() end

  if not self.searchDetail then
    self:CreateSearchDetailPanel()
  end

  self.searchDetail:Show()
  self.detailContent = self.searchDetail

  -- Populate fields
  self.searchDetail.nameLabel:SetText(filter.name)
  local query = filter.searchCategory.query or ""
  local storedGroupBy = filter.searchCategory.groupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE

  -- Parse group by from query string to ensure sync
  local parsedGroupBy = parseGroupByFromQuery(query)

  -- Determine the effective group by: prefer what's in the query string
  local effectiveGroupBy
  if parsedGroupBy ~= nil then
    effectiveGroupBy = parsedGroupBy
  else
    effectiveGroupBy = storedGroupBy
    -- If there's a stored groupBy but it's not in the query, add it
    if effectiveGroupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
      query = setGroupByInQuery(query, effectiveGroupBy)
    end
  end

  self.searchDetail.queryBox:SetText(query)
  self.searchDetail.priorityBox:SetText(tostring(filter.priority or 10))

  -- Update group by dropdown
  self.searchDetail.selectedGroupBy = effectiveGroupBy
  if addon.isRetail then
    self.searchDetail.groupByDropdown:GenerateMenu()
  else
    UIDropDownMenu_SetText(self.searchDetail.groupByDropdown, groupByEnumToDisplayText[effectiveGroupBy])
  end

  -- Update color
  if filter.color then
    self.searchDetail.colorTexture:SetVertexColor(filter.color[1], filter.color[2], filter.color[3], 1)
  else
    self.searchDetail.colorTexture:SetVertexColor(1, 1, 1, 1)
  end

  -- Show/hide rename and delete buttons based on category type
  local isDynamic = categories:IsDynamicCategory(filter.name)
  self.searchDetail.renameButton:SetEnabled(not isDynamic)
  self.searchDetail.deleteButton:SetEnabled(not isDynamic)
  if isDynamic then
    self.searchDetail.renameButton:SetText("Cannot Rename")
    self.searchDetail.deleteButton:SetText("Cannot Delete")
  else
    self.searchDetail.renameButton:SetText("Rename")
    self.searchDetail.deleteButton:SetText("Delete Category")
  end
end

function categoryPaneProto:CreateSearchDetailPanel()
  self.searchDetail = CreateFrame("Frame", nil, self.detailFrame)
  self.searchDetail:SetAllPoints()

  local yOffset = -10

  -- Category Name (read-only display)
  local nameLabel = self.searchDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nameLabel:SetPoint("TOPLEFT", 10, yOffset)
  nameLabel:SetTextColor(1, 0.82, 0)
  self.searchDetail.nameLabel = nameLabel

  yOffset = yOffset - 30

  -- Divider
  local divider = self.searchDetail:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", 10, yOffset)
  divider:SetPoint("RIGHT", self.searchDetail, "RIGHT", -10, 0)
  divider:SetHeight(1)
  divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)

  yOffset = yOffset - 20

  -- Query Label
  local queryLabel = self.searchDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  queryLabel:SetPoint("TOPLEFT", 10, yOffset)
  queryLabel:SetText("Search Query")

  yOffset = yOffset - 20

  -- Query multi-line text area
  local queryScrollBox = CreateFrame("Frame", nil, self.searchDetail, "WowScrollBox") --[[@as WowScrollBox]]
  queryScrollBox:SetPoint("TOPLEFT", 10, yOffset)
  queryScrollBox:SetPoint("RIGHT", self.searchDetail, "RIGHT", -30, 0)
  queryScrollBox:SetHeight(60)
  queryScrollBox:EnableMouseWheel(false)

  local queryScrollBar = CreateFrame("EventFrame", nil, self.searchDetail, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  queryScrollBar:SetPoint("TOPLEFT", queryScrollBox, "TOPRIGHT", 4, -2)
  queryScrollBar:SetPoint("BOTTOMLEFT", queryScrollBox, "BOTTOMRIGHT", 2, 0)
  queryScrollBar:SetHideIfUnscrollable(true)
  queryScrollBox:SetInterpolateScroll(true)
  queryScrollBar:SetInterpolateScroll(true)

  -- Background for the text area
  local queryBackground = CreateFrame("Frame", nil, queryScrollBox, "BackdropTemplate") --[[@as Frame]]
  queryBackground:SetBackdrop({
    bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 4,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  })
  queryBackground:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
  queryBackground:SetBackdropBorderColor(0.4, 0.4, 0.4)
  queryBackground:SetPoint("TOPLEFT", queryScrollBox, "TOPLEFT", 0, 0)
  queryBackground:SetPoint("BOTTOMRIGHT", queryScrollBox, "BOTTOMRIGHT", 0, 0)

  local queryView = CreateScrollBoxLinearView()
  queryView:SetPanExtent(10)

  local queryBox = CreateFrame("EditBox", nil, queryScrollBox) --[[@as EditBox]]
  queryBox:SetFontObject("ChatFontNormal")
  queryBox:SetMultiLine(true)
  queryBox:EnableMouse(true)
  queryBox:SetCountInvisibleLetters(false)
  queryBox:SetAutoFocus(false)
  queryBox.scrollable = true

  queryBox:SetScript("OnEscapePressed", function()
    queryBox:ClearFocus()
    queryScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
  end)

  queryBox:SetScript("OnEditFocusGained", function()
    queryScrollBox:EnableMouseWheel(true)
  end)

  queryBox:SetScript("OnEditFocusLost", function()
    queryScrollBox:EnableMouseWheel(false)
  end)

  queryBox:SetScript("OnTextChanged", function(_, isUserInput)
    queryScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    -- Sync dropdown from query string when user types
    if isUserInput and self.searchDetail.groupByDropdown then
      local parsedGroupBy = parseGroupByFromQuery(queryBox:GetText())
      if parsedGroupBy ~= nil and parsedGroupBy ~= self.searchDetail.selectedGroupBy then
        self.searchDetail.selectedGroupBy = parsedGroupBy
        if addon.isRetail then
          self.searchDetail.groupByDropdown:GenerateMenu()
        else
          UIDropDownMenu_SetText(self.searchDetail.groupByDropdown, groupByEnumToDisplayText[parsedGroupBy])
        end
      elseif parsedGroupBy == nil and self.searchDetail.selectedGroupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
        -- Query has no group by clause, reset dropdown to None
        self.searchDetail.selectedGroupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE
        if addon.isRetail then
          self.searchDetail.groupByDropdown:GenerateMenu()
        else
          UIDropDownMenu_SetText(self.searchDetail.groupByDropdown, groupByEnumToDisplayText[const.SEARCH_CATEGORY_GROUP_BY.NONE])
        end
      end
    end
  end)

  queryScrollBox:SetScript("OnMouseDown", function()
    queryBox:SetFocus()
  end)

  ScrollUtil.InitScrollBoxWithScrollBar(queryScrollBox, queryScrollBar, queryView)
  self.searchDetail.queryBox = queryBox

  yOffset = yOffset - 75

  -- Priority Label
  local priorityLabel = self.searchDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  priorityLabel:SetPoint("TOPLEFT", 10, yOffset)
  priorityLabel:SetText("Priority (0-99)")

  yOffset = yOffset - 20

  -- Priority EditBox
  local priorityBox = CreateFrame("EditBox", nil, self.searchDetail, "InputBoxTemplate")
  priorityBox:SetPoint("TOPLEFT", 15, yOffset)
  priorityBox:SetSize(60, 25)
  priorityBox:SetAutoFocus(false)
  priorityBox:SetNumeric(true)
  priorityBox:SetMaxLetters(2)
  self.searchDetail.priorityBox = priorityBox

  yOffset = yOffset - 40

  -- Group By Label
  local groupByLabel = self.searchDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  groupByLabel:SetPoint("TOPLEFT", 10, yOffset)
  groupByLabel:SetText("Group By")

  yOffset = yOffset - 25

  -- Group By Dropdown
  self.searchDetail.selectedGroupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE
  local groupByOptions = {
    {text = "None", value = const.SEARCH_CATEGORY_GROUP_BY.NONE},
    {text = "Type", value = const.SEARCH_CATEGORY_GROUP_BY.TYPE},
    {text = "Subtype", value = const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE},
    {text = "Expansion", value = const.SEARCH_CATEGORY_GROUP_BY.EXPANSION},
  }

  if addon.isRetail then
    local groupByDropdown = CreateFrame("DropdownButton", nil, self.searchDetail, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
    groupByDropdown:SetPoint("TOPLEFT", 10, yOffset)
    groupByDropdown:SetWidth(150)
    groupByDropdown:SetupMenu(function(_, root)
      for _, option in ipairs(groupByOptions) do
        root:CreateRadio(option.text, function()
          return self.searchDetail.selectedGroupBy == option.value
        end, function()
          self.searchDetail.selectedGroupBy = option.value
          -- Sync query string from dropdown
          if self.searchDetail.queryBox then
            local newQuery = setGroupByInQuery(self.searchDetail.queryBox:GetText(), option.value)
            self.searchDetail.queryBox:SetText(newQuery)
          end
        end)
      end
    end)
    self.searchDetail.groupByDropdown = groupByDropdown
  else
    local groupByDropdown = CreateFrame("Frame", nil, self.searchDetail, "UIDropDownMenuTemplate")
    groupByDropdown:SetPoint("TOPLEFT", -5, yOffset)
    UIDropDownMenu_SetWidth(groupByDropdown, 140)
    UIDropDownMenu_Initialize(groupByDropdown, function(_, level, _)
      for _, option in ipairs(groupByOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.checked = function() return self.searchDetail.selectedGroupBy == option.value end
        info.func = function()
          self.searchDetail.selectedGroupBy = option.value
          UIDropDownMenu_SetText(groupByDropdown, option.text)
          -- Sync query string from dropdown
          if self.searchDetail.queryBox then
            local newQuery = setGroupByInQuery(self.searchDetail.queryBox:GetText(), option.value)
            self.searchDetail.queryBox:SetText(newQuery)
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
    self.searchDetail.groupByDropdown = groupByDropdown
  end

  yOffset = yOffset - 45

  -- Color Label
  local colorLabel = self.searchDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", 10, yOffset)
  colorLabel:SetText("Color")

  -- Color Picker
  local colorPicker = CreateFrame("Frame", nil, self.searchDetail)
  colorPicker:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
  colorPicker:SetSize(24, 24)
  colorPicker:EnableMouse(true)

  local colorTex = colorPicker:CreateTexture(nil, "ARTWORK")
  colorTex:SetAllPoints()
  colorTex:SetTexture(5014189)
  self.searchDetail.colorTexture = colorTex

  colorPicker:SetScript("OnMouseDown", function()
    if not self.selectedCategory then return end
    local filter = categories:GetCategoryByName(self.selectedCategory)
    local r, g, b = 1, 1, 1
    if filter and filter.color then
      r, g, b = filter.color[1], filter.color[2], filter.color[3]
    end

    local function OnColorChanged()
      local newR, newG, newB = ColorPickerFrame:GetColorRGB()
      colorTex:SetVertexColor(newR, newG, newB, 1)
    end

    local options = {
      swatchFunc = OnColorChanged,
      cancelFunc = function() end,
      hasOpacity = false,
      r = r,
      g = g,
      b = b,
    }
    ColorPickerFrame:SetupColorPickerAndShow(options)
  end)

  yOffset = yOffset - 50

  -- Save Button
  local saveButton = CreateFrame("Button", nil, self.searchDetail, "UIPanelButtonTemplate")
  saveButton:SetPoint("TOPLEFT", 10, yOffset)
  saveButton:SetSize(100, 25)
  saveButton:SetText("Save")
  saveButton:SetScript("OnClick", function()
    self:SaveSearchCategory()
  end)
  self.searchDetail.saveButton = saveButton

  -- Rename Button
  local renameButton = CreateFrame("Button", nil, self.searchDetail, "UIPanelButtonTemplate")
  renameButton:SetPoint("LEFT", saveButton, "RIGHT", 10, 0)
  renameButton:SetSize(100, 25)
  renameButton:SetText("Rename")
  renameButton:SetScript("OnClick", function()
    if not self.selectedCategory then return end
    self:ShowRenameCategoryDialog(self.selectedCategory)
  end)
  self.searchDetail.renameButton = renameButton

  -- Delete Button
  local deleteButton = CreateFrame("Button", nil, self.searchDetail, "UIPanelButtonTemplate")
  deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 10, 0)
  deleteButton:SetSize(120, 25)
  deleteButton:SetText("Delete Category")
  deleteButton:SetScript("OnClick", function()
    if not self.selectedCategory then return end
    question:YesNo("Delete Category", format("Are you sure you want to delete the category %s?", self.selectedCategory), function()
      local ctx = context:New('CategoryPane_DeleteSearchCategory')
      categories:DeleteCategory(ctx, self.selectedCategory)
      self.selectedCategory = nil
      self:UpdateDetailPanel()
      self:RefreshList()
    end, function() end)
  end)
  self.searchDetail.deleteButton = deleteButton
end

function categoryPaneProto:SaveSearchCategory()
  if not self.selectedCategory then return end

  local filter = categories:GetCategoryByName(self.selectedCategory)
  if not filter or not filter.searchCategory then return end

  local ctx = context:New('CategoryPane_SaveSearchCategory')

  -- Update query (strip group by clause since it's stored separately)
  local newQuery = stripGroupByFromQuery(self.searchDetail.queryBox:GetText())
  local newPriority = tonumber(self.searchDetail.priorityBox:GetText()) or 10
  local newGroupBy = self.searchDetail.selectedGroupBy

  -- Update color
  local r, g, b = self.searchDetail.colorTexture:GetVertexColor()

  -- Recreate the category with updated values
  categories:CreateCategory(ctx, {
    name = self.selectedCategory,
    priority = newPriority,
    save = true,
    itemList = filter.itemList or {},
    color = {r, g, b},
    searchCategory = {
      query = newQuery,
      groupBy = newGroupBy,
    }
  })

  events:SendMessage(ctx, 'bags/FullRefreshAll')
  self:RefreshList()
end

---@param filter CustomCategoryFilter
function categoryPaneProto:ShowManualCategoryDetail(filter)
  if self.emptyDetail then self.emptyDetail:Hide() end
  if self.searchDetail then self.searchDetail:Hide() end

  if not self.manualDetail then
    self:CreateManualDetailPanel()
  end

  self.manualDetail:Show()
  self.detailContent = self.manualDetail

  -- Populate fields
  self.manualDetail.nameLabel:SetText(filter.name)

  -- Update color
  if filter.color then
    self.manualDetail.colorTexture:SetVertexColor(filter.color[1], filter.color[2], filter.color[3], 1)
  else
    self.manualDetail.colorTexture:SetVertexColor(1, 1, 1, 1)
  end

  -- Show/hide rename and delete buttons based on category type
  local isDynamic = categories:IsDynamicCategory(filter.name)
  self.manualDetail.renameButton:SetEnabled(not isDynamic)
  self.manualDetail.deleteButton:SetEnabled(not isDynamic)
  if isDynamic then
    self.manualDetail.renameButton:SetText("Cannot Rename")
    self.manualDetail.deleteButton:SetText("Cannot Delete")
  else
    self.manualDetail.renameButton:SetText("Rename")
    self.manualDetail.deleteButton:SetText("Delete Category")
  end

  -- Load item list
  self:LoadItemList(filter.name)
end

function categoryPaneProto:CreateManualDetailPanel()
  self.manualDetail = CreateFrame("Frame", nil, self.detailFrame)
  self.manualDetail:SetAllPoints()

  local yOffset = -10

  -- Category Name
  local nameLabel = self.manualDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nameLabel:SetPoint("TOPLEFT", 10, yOffset)
  nameLabel:SetTextColor(1, 0.82, 0)
  self.manualDetail.nameLabel = nameLabel

  yOffset = yOffset - 30

  -- Divider
  local divider = self.manualDetail:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", 10, yOffset)
  divider:SetPoint("RIGHT", self.manualDetail, "RIGHT", -10, 0)
  divider:SetHeight(1)
  divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)

  yOffset = yOffset - 20

  -- Color Label
  local colorLabel = self.manualDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", 10, yOffset)
  colorLabel:SetText("Color")

  -- Color Picker
  local colorPicker = CreateFrame("Frame", nil, self.manualDetail)
  colorPicker:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
  colorPicker:SetSize(24, 24)
  colorPicker:EnableMouse(true)

  local colorTex = colorPicker:CreateTexture(nil, "ARTWORK")
  colorTex:SetAllPoints()
  colorTex:SetTexture(5014189)
  self.manualDetail.colorTexture = colorTex

  colorPicker:SetScript("OnMouseDown", function()
    if not self.selectedCategory then return end
    local filter = categories:GetCategoryByName(self.selectedCategory)
    local r, g, b = 1, 1, 1
    if filter and filter.color then
      r, g, b = filter.color[1], filter.color[2], filter.color[3]
    end

    local function OnColorChanged()
      local newR, newG, newB = ColorPickerFrame:GetColorRGB()
      colorTex:SetVertexColor(newR, newG, newB, 1)
    end

    local options = {
      swatchFunc = OnColorChanged,
      cancelFunc = function() end,
      hasOpacity = false,
      r = r,
      g = g,
      b = b,
    }
    ColorPickerFrame:SetupColorPickerAndShow(options)
  end)

  yOffset = yOffset - 40

  -- Items Label
  local itemsLabel = self.manualDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  itemsLabel:SetPoint("TOPLEFT", 10, yOffset)
  itemsLabel:SetText("Items in Category (drag items here to add)")

  yOffset = yOffset - 20

  -- Save Button (anchored to bottom)
  local saveButton = CreateFrame("Button", nil, self.manualDetail, "UIPanelButtonTemplate")
  saveButton:SetPoint("BOTTOMLEFT", self.manualDetail, "BOTTOMLEFT", 10, 10)
  saveButton:SetSize(100, 25)
  saveButton:SetText("Save")
  saveButton:SetScript("OnClick", function()
    self:SaveManualCategory()
  end)
  self.manualDetail.saveButton = saveButton

  -- Rename Button (anchored to save button)
  local renameButton = CreateFrame("Button", nil, self.manualDetail, "UIPanelButtonTemplate")
  renameButton:SetPoint("LEFT", saveButton, "RIGHT", 10, 0)
  renameButton:SetSize(100, 25)
  renameButton:SetText("Rename")
  renameButton:SetScript("OnClick", function()
    if not self.selectedCategory then return end
    self:ShowRenameCategoryDialog(self.selectedCategory)
  end)
  self.manualDetail.renameButton = renameButton

  -- Delete Button (anchored to rename button)
  local deleteButton = CreateFrame("Button", nil, self.manualDetail, "UIPanelButtonTemplate")
  deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 10, 0)
  deleteButton:SetSize(120, 25)
  deleteButton:SetText("Delete Category")
  deleteButton:SetScript("OnClick", function()
    if not self.selectedCategory then return end
    question:YesNo("Delete Category", format("Are you sure you want to delete the category %s?", self.selectedCategory), function()
      local ctx = context:New('CategoryPane_DeleteManualCategory')
      categories:DeleteCategory(ctx, self.selectedCategory)
      self.selectedCategory = nil
      self:UpdateDetailPanel()
      self:RefreshList()
    end, function() end)
  end)
  self.manualDetail.deleteButton = deleteButton

  -- Divider 2 (anchored above buttons)
  local divider2 = self.manualDetail:CreateTexture(nil, "ARTWORK")
  divider2:SetPoint("BOTTOMLEFT", self.manualDetail, "BOTTOMLEFT", 10, 45)
  divider2:SetPoint("RIGHT", self.manualDetail, "RIGHT", -10, 0)
  divider2:SetHeight(1)
  divider2:SetColorTexture(0.5, 0.5, 0.5, 0.5)

  -- Item List Frame (expands to fill available space)
  local itemListContainer = CreateFrame("Frame", nil, self.manualDetail)
  itemListContainer:SetPoint("TOPLEFT", 10, yOffset)
  itemListContainer:SetPoint("RIGHT", self.manualDetail, "RIGHT", -10, 0)
  itemListContainer:SetPoint("BOTTOM", divider2, "TOP", 0, 20)

  self.manualDetail.itemListFrame = list:Create(itemListContainer)
  self.manualDetail.itemListFrame.frame:SetAllPoints()
  self.manualDetail.itemListFrame:SetupDataSource("BetterBagsCategoryPaneItemFrame", function(f, data)
    ---@cast f CategoryPaneItemFrame
    self:initItemRow(f, data)
  end, function(f, data)
    ---@cast f CategoryPaneItemFrame
    self:resetItemRow(f, data)
  end)

  -- Enable drag-and-drop to add items to the category
  -- Set up handlers on both the container and the list frame's scroll box
  local function onReceiveDrag()
    self:OnItemListDrop()
  end
  local function onMouseUp(_, button)
    if button == "LeftButton" and CursorHasItem() then
      self:OnItemListDrop()
    end
  end

  itemListContainer:EnableMouse(true)
  itemListContainer:SetScript("OnReceiveDrag", onReceiveDrag)
  itemListContainer:SetScript("OnMouseUp", onMouseUp)

  -- Also set on the scroll box so drops work over the list area
  self.manualDetail.itemListFrame.ScrollBox:SetScript("OnReceiveDrag", onReceiveDrag)
  self.manualDetail.itemListFrame.ScrollBox:HookScript("OnMouseUp", onMouseUp)
end

---@param categoryName string
function categoryPaneProto:LoadItemList(categoryName)
  if not self.manualDetail or not self.manualDetail.itemListFrame then return end

  self.manualDetail.itemListFrame:Wipe()

  local itemDataList = categories:GetMergedCategory(categoryName)
  if not itemDataList then return end

  for id in pairs(itemDataList.itemList) do
    self.manualDetail.itemListFrame:AddToStart({id = id, category = categoryName})
  end
end

-- Handle dropping an item onto the item list to add it to the category
function categoryPaneProto:OnItemListDrop()
  if not self.selectedCategory then return end
  if not CursorHasItem() then return end

  local cursorType, itemID = GetCursorInfo()
  if cursorType ~= "item" then return end

  -- Add the item to the category
  local ctx = context:New('CategoryPane_DropItem')
  categories:AddPermanentItemToCategory(ctx, itemID, self.selectedCategory)
  ClearCursor()

  -- Refresh the bags and the item list
  events:SendMessage(ctx, 'bags/FullRefreshAll')
  self:LoadItemList(self.selectedCategory)
end

---@param frame CategoryPaneItemFrame
---@param elementData table
function categoryPaneProto:initItemRow(frame, elementData)
  local ctx = context:New("CategoryPane_ItemRow_Init")
  if frame.item == nil then
    frame.item = itemRowFrame:Create(ctx)
    frame.item.frame:SetParent(frame)
    frame.item.frame:SetPoint("LEFT", frame, "LEFT", 4, 0)
    frame.item.frame:SetPoint("RIGHT", frame, "RIGHT", -9, 0)
  end

  addon.SetScript(frame.item.rowButton, "OnMouseDown", function(ectx, _, b)
    if b == "RightButton" then
      contextMenu:Show(ectx, {{
        text = L:G("Remove"),
        notCheckable = true,
        hasArrow = false,
        func = function()
          database:DeleteItemFromCategory(elementData.id, elementData.category)
          local refreshCtx = context:New('CategoryPane_RemoveItem')
          events:SendMessage(refreshCtx, 'bags/FullRefreshAll')
          self:LoadItemList(elementData.category)
        end
      }})
    end
  end)

  items:GetItemData(ctx, {elementData.id}, function(ectx, itemData)
    frame.item:SetStaticItemFromData(ectx, itemData[1])
  end)
end

---@param frame CategoryPaneItemFrame
---@param elementData table
function categoryPaneProto:resetItemRow(frame, elementData)
  _ = elementData
  local ctx = context:New("CategoryPane_ItemRow_Reset")
  if frame.item then
    frame.item:ClearItem(ctx)
    frame.item.rowButton:SetScript("OnMouseDown", nil)
  end
end

function categoryPaneProto:SaveManualCategory()
  if not self.selectedCategory then return end

  local filter = categories:GetCategoryByName(self.selectedCategory)
  if not filter then return end

  local ctx = context:New('CategoryPane_SaveManualCategory')

  -- Update color
  local r, g, b = self.manualDetail.colorTexture:GetVertexColor()

  -- Update the category with new color
  categories:CreateCategory(ctx, {
    name = self.selectedCategory,
    save = filter.save,
    itemList = filter.itemList or {},
    color = {r, g, b},
  })

  events:SendMessage(ctx, 'bags/FullRefreshAll')
  self:RefreshList()
end

---@param categoryName string
function categoryPaneProto:ShowDynamicCategoryDetail(categoryName)
  if self.emptyDetail then self.emptyDetail:Hide() end
  if self.searchDetail then self.searchDetail:Hide() end
  if self.manualDetail then self.manualDetail:Hide() end

  if not self.dynamicDetail then
    self.dynamicDetail = CreateFrame("Frame", nil, self.detailFrame)
    self.dynamicDetail:SetAllPoints()

    local nameLabel = self.dynamicDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameLabel:SetPoint("TOPLEFT", 10, -10)
    nameLabel:SetTextColor(1, 0.82, 0)
    self.dynamicDetail.nameLabel = nameLabel

    local infoLabel = self.dynamicDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoLabel:SetPoint("TOPLEFT", 10, -50)
    infoLabel:SetText("This is a dynamic category.\nIt cannot be edited or deleted.")
    infoLabel:SetTextColor(0.7, 0.7, 0.7)
  end

  self.dynamicDetail:Show()
  self.dynamicDetail.nameLabel:SetText(categoryName)
  self.detailContent = self.dynamicDetail
end

function categoryPaneProto:RefreshList()
  self.listFrame:Wipe()
  self.listFrame:AddToStart({ title = "Pinned", header = true })
  self:LoadPinnedItems()
  self.listFrame:AddToStart({ title = "Automatically Sorted", header = true })

  -- Add all categories
  local allCategories = categories:GetAllCategories()
  local bag = self.kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank

  ---@type table<string, boolean>
  local namesSet = {}

  -- Get categories from bag sections
  if bag and bag.currentView and bag.currentView.sections then
    for sName in pairs(bag.currentView.sections) do
      namesSet[sName] = true
    end
  end

  -- Get all defined categories
  for sName in pairs(allCategories) do
    namesSet[sName] = true
  end

  -- Convert to sorted list
  local sortedNames = {}
  for name in pairs(namesSet) do
    table.insert(sortedNames, name)
  end
  table.sort(sortedNames)

  -- Add categories that aren't already in pinned
  local pinnedList = database:GetCustomSectionSort(self.kind)
  for _, name in ipairs(sortedNames) do
    if not pinnedList[name] then
      self.listFrame:AddToStart({ title = name })
    end
  end
end

function categoryPaneProto:SetupDragBehavior()
  if addon.isRetail then
    self.listFrame.dragBehavior:SetDropPredicate(function(_, contextData)
      if contextData.elementData.header and
         contextData.elementData.title == "Pinned" and
         (contextData.area == DragIntersectionArea.Above or contextData.area == DragIntersectionArea.Inside) then
        return false
      end
      if contextData.elementData.header and
         contextData.elementData.title == "Automatically Sorted" and
         contextData.area == DragIntersectionArea.Inside then
        return false
      end
      return true
    end)

    self.listFrame.dragBehavior:SetDragPredicate(function(_, elementData)
      if elementData.header then
        return false
      end
      return true
    end)

    self.listFrame.dragBehavior:SetFinalizeDrop(function(_)
      local ctx = context:New('CategoryPane_FinalizeDrop')
      self:UpdatePinnedItems()
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end)

    self.listFrame:SetCanReorder(true)
  else
    self.listFrame:SetCanReorder(true, function(_, elementData, currentIndex, newIndex)
      local ctx = context:New('CategoryPane_Reorder')
      if elementData.header then
        self.listFrame.provider:RemoveIndex(newIndex)
        self.listFrame.provider:InsertAtIndex(elementData, currentIndex)
        return
      end
      if newIndex == 1 then
        self.listFrame.provider:RemoveIndex(newIndex)
        self.listFrame.provider:InsertAtIndex(elementData, 2)
      end
      self:UpdatePinnedItems()
      events:SendMessage(ctx, 'bags/FullRefreshAll')
    end)
  end
end

---@param parent Frame
---@param kind BagKind
---@return Frame
function categoryPane:Create(parent, kind)
  local pane = setmetatable({}, { __index = categoryPaneProto })
  pane.kind = kind

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
    ---@cast f CategoryPaneListButton
    pane:initListItem(f, data)
  end, function(f, data)
    ---@cast f CategoryPaneListButton
    pane:resetListItem(f, data)
  end)

  pane:SetupDragBehavior()

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

  -- Register for category updates
  local drawEvent = kind == const.BAG_KIND.BACKPACK and 'bags/Draw/Backpack/Done' or 'bags/Draw/Bank/Done'
  events:RegisterMessage(drawEvent, function()
    if pane.initialized then
      pane:RefreshList()
      -- Also refresh the item list if a manual category is selected
      if pane.selectedCategory and pane.detailContent == pane.manualDetail then
        pane:LoadItemList(pane.selectedCategory)
      end
    end
  end)

  return pane.frame
end
