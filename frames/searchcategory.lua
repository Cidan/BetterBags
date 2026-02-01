local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class SearchCategoryConfig: AceModule
---@field frame Frame
---@field openedName string
---@field queryBox InputScrollFrameTemplate
---@field selectedGroupBy number
---@field updatingFromDropdown boolean
---@field updatingFromQuery boolean
local searchCategoryConfig = addon:NewModule('SearchCategoryConfig')

-- Mapping from query text to enum value (case-insensitive)
local groupByTextToEnum = {
  ["none"] = const.SEARCH_CATEGORY_GROUP_BY.NONE,
  ["type"] = const.SEARCH_CATEGORY_GROUP_BY.TYPE,
  ["subtype"] = const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE,
  ["expansion"] = const.SEARCH_CATEGORY_GROUP_BY.EXPANSION,
  ["exp"] = const.SEARCH_CATEGORY_GROUP_BY.EXPANSION,
}

-- Mapping from enum value to display text for query
local groupByEnumToText = {
  [const.SEARCH_CATEGORY_GROUP_BY.NONE] = "none",
  [const.SEARCH_CATEGORY_GROUP_BY.TYPE] = "type",
  [const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE] = "subtype",
  [const.SEARCH_CATEGORY_GROUP_BY.EXPANSION] = "expansion",
}

-- Mapping from enum to dropdown display text
local groupByEnumToDisplayText = {
  [const.SEARCH_CATEGORY_GROUP_BY.NONE] = "None",
  [const.SEARCH_CATEGORY_GROUP_BY.TYPE] = "Type",
  [const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE] = "Subtype",
  [const.SEARCH_CATEGORY_GROUP_BY.EXPANSION] = "Expansion",
}

-- Pattern to match "group by <value>" at the end of a query (case-insensitive)
local groupByPattern = "%s+group%s+by%s+(%w+)%s*$"

---@param query string
---@return number|nil groupBy enum value if found, nil otherwise
function searchCategoryConfig:ParseGroupByFromQuery(query)
  local match = query:lower():match(groupByPattern)
  if match then
    return groupByTextToEnum[match]
  end
  return nil
end

---@param query string
---@return string query with group by clause stripped
function searchCategoryConfig:StripGroupByFromQuery(query)
  -- Remove the group by clause from the end, preserving original case
  return query:gsub("%s+[Gg][Rr][Oo][Uu][Pp]%s+[Bb][Yy]%s+%w+%s*$", "")
end

---@param query string
---@param groupBy number
---@return string query with group by clause added/updated
function searchCategoryConfig:SetGroupByInQuery(query, groupBy)
  -- First strip any existing group by
  local cleanQuery = self:StripGroupByFromQuery(query)

  -- If groupBy is NONE, just return the clean query
  if groupBy == const.SEARCH_CATEGORY_GROUP_BY.NONE then
    return cleanQuery
  end

  -- Add the group by clause
  local groupByText = groupByEnumToText[groupBy]
  if groupByText and cleanQuery ~= "" then
    return cleanQuery .. " group by " .. groupByText
  elseif groupByText then
    return "group by " .. groupByText
  end

  return cleanQuery
end

---@private
function searchCategoryConfig:UpdateDropdownDisplay()
  if addon.isRetail then
    self.groupByDropdown:GenerateMenu()
  else
    UIDropDownMenu_SetText(self.groupByDropdown, groupByEnumToDisplayText[self.selectedGroupBy])
  end
end

function searchCategoryConfig:CheckNameboxText()
  local input = self.nameBox:GetText()
  if input == "" then
    self.errorText:SetText("Name cannot be empty")
  elseif categories:DoesCategoryExist(input) and self.openedName ~= input then
    self.errorText:SetText("This category name overwrites a previous item list based category. Please choose a different name.")
  else
    self.errorText:SetText("")
  end
end

function searchCategoryConfig:OnEnable()
  self.frame = CreateFrame("Frame", addonName .. "SearchCategoryConfig", UIParent)
  themes:RegisterFlatWindow(self.frame, "Configure Search Category")

  self.frame:SetSize(430, 450)
  self.frame:SetPoint("CENTER")
  self.frame:SetMovable(true)
  self.frame:EnableMouse(true)
  self.frame:SetClampedToScreen(true)
  self.frame:RegisterForDrag("LeftButton")
  self.frame:SetScript("OnDragStart", self.frame.StartMoving)
  self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
  self.frame:SetFrameStrata("DIALOG")

  self.fadeInGroup, self.fadeOutGroup = animations:AttachFadeGroup(self.frame)

  self.nameBoxLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.nameBoxLabel:SetPoint("TOPLEFT", 20, -40)
  self.nameBoxLabel:SetText("Category Name")

  self.nameBox = CreateFrame("EditBox", addonName .. "SearchCategoryConfigNameBox", self.frame, "InputBoxTemplate")
  self.nameBox:SetSize(200, 20)
  self.nameBox:SetPoint("TOPLEFT", self.nameBoxLabel, "BOTTOMLEFT", 2, -7)
  self.nameBox:SetAutoFocus(false)
  self.nameBox:SetFontObject("GameFontHighlight")

  self.nameBox:SetScript("OnTextChanged", function()
    self:CheckNameboxText()
  end)

  self.queryBoxLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.queryBoxLabel:SetPoint("TOPLEFT", self.nameBox, "BOTTOMLEFT", -2, -20)
  self.queryBoxLabel:SetText("Search Query")

  self.queryBox = CreateFrame("ScrollFrame", addonName .. "SearchCategoryConfigQueryBox", self.frame, "InputScrollFrameTemplate") --[[@as InputScrollFrameTemplate]]
  self.queryBox:SetSize(400, 100)
  self.queryBox.EditBox:SetSize(390, 100)
  self.queryBox:SetPoint("TOPLEFT", self.queryBoxLabel, "BOTTOMLEFT", 2, -7)
  self.queryBox.EditBox:SetFontObject("GameFontHighlight")
  self.queryBox.EditBox:SetMaxLetters(1024)
  self.queryBox:Show()

  self.queryBox.EditBox:SetScript("OnTextChanged", function()
    local input = self.queryBox.EditBox:GetText()
    if input == "" then
      self.errorText:SetText("Query cannot be empty")
    else
      self.errorText:SetText("")
    end

    -- Sync group by from query to dropdown (if not already updating from dropdown)
    if not self.updatingFromDropdown then
      local parsedGroupBy = self:ParseGroupByFromQuery(input)
      if parsedGroupBy ~= nil and parsedGroupBy ~= self.selectedGroupBy then
        self.updatingFromQuery = true
        self.selectedGroupBy = parsedGroupBy
        self:UpdateDropdownDisplay()
        self.updatingFromQuery = false
      elseif parsedGroupBy == nil and self.selectedGroupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
        -- No group by in query, but dropdown is set - check if user is still typing
        -- Only reset if there's no partial "group by" match
        local lowerInput = input:lower()
        if not lowerInput:match("%s+group%s*$") and not lowerInput:match("%s+group%s+by%s*$") then
          self.updatingFromQuery = true
          self.selectedGroupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE
          self:UpdateDropdownDisplay()
          self.updatingFromQuery = false
        end
      end
    end
  end)

  self.priorityBoxLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.priorityBoxLabel:SetPoint("TOPLEFT", self.queryBox, "BOTTOMLEFT", -2, -20)
  self.priorityBoxLabel:SetText("Priority")

  self.priorityBox = CreateFrame("EditBox", addonName .. "SearchCategoryConfigPriorityBox", self.frame, "InputBoxTemplate")
  self.priorityBox:SetSize(200, 20)
  self.priorityBox:SetPoint("TOPLEFT", self.priorityBoxLabel, "BOTTOMLEFT", 2, -7)
  self.priorityBox:SetAutoFocus(false)
  self.priorityBox:SetFontObject("GameFontHighlight")
  self.priorityBox:SetNumeric(true)
  self.priorityBox:SetMaxLetters(2)

  self.priorityBox:SetScript("OnTextChanged", function()
    local input = self.priorityBox:GetText()
    if input == "" then
      self.errorText:SetText("Priority cannot be empty")
    else
      self.errorText:SetText("")
    end
  end)

  -- Group By dropdown
  self.groupByLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.groupByLabel:SetPoint("TOPLEFT", self.priorityBox, "BOTTOMLEFT", -2, -20)
  self.groupByLabel:SetText("Group By")

  self.selectedGroupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE

  local groupByOptions = {
    {text = "None", value = const.SEARCH_CATEGORY_GROUP_BY.NONE},
    {text = "Type", value = const.SEARCH_CATEGORY_GROUP_BY.TYPE},
    {text = "Subtype", value = const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE},
    {text = "Expansion", value = const.SEARCH_CATEGORY_GROUP_BY.EXPANSION},
  }

  if addon.isRetail then
    self.groupByDropdown = CreateFrame("DropdownButton", addonName .. "SearchCategoryGroupByDropdown", self.frame, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
    self.groupByDropdown:SetPoint("TOPLEFT", self.groupByLabel, "BOTTOMLEFT", 0, -5)
    self.groupByDropdown:SetWidth(200)

    self.groupByDropdown:SetupMenu(function(_, root)
      for _, option in ipairs(groupByOptions) do
        root:CreateRadio(option.text, function()
          return self.selectedGroupBy == option.value
        end, function()
          if not self.updatingFromQuery then
            self.updatingFromDropdown = true
            self.selectedGroupBy = option.value
            -- Sync to query text
            local currentQuery = self.queryBox.EditBox:GetText()
            local newQuery = self:SetGroupByInQuery(currentQuery, option.value)
            self.queryBox.EditBox:SetText(newQuery)
            self.updatingFromDropdown = false
          else
            self.selectedGroupBy = option.value
          end
        end)
      end
    end)
  else
    -- Classic/Era dropdown using UIDropDownMenuTemplate
    self.groupByDropdown = CreateFrame("Frame", addonName .. "SearchCategoryGroupByDropdown", self.frame, "UIDropDownMenuTemplate") --[[@as Frame]]
    self.groupByDropdown:SetPoint("TOPLEFT", self.groupByLabel, "BOTTOMLEFT", -15, -5)

    UIDropDownMenu_SetWidth(self.groupByDropdown, 185)
    UIDropDownMenu_SetText(self.groupByDropdown, "None")

    UIDropDownMenu_Initialize(self.groupByDropdown, function(_, level, _)
      for _, option in ipairs(groupByOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.checked = function()
          return self.selectedGroupBy == option.value
        end
        info.func = function()
          if not self.updatingFromQuery then
            self.updatingFromDropdown = true
            self.selectedGroupBy = option.value
            UIDropDownMenu_SetText(self.groupByDropdown, option.text)
            -- Sync to query text
            local currentQuery = self.queryBox.EditBox:GetText()
            local newQuery = self:SetGroupByInQuery(currentQuery, option.value)
            self.queryBox.EditBox:SetText(newQuery)
            self.updatingFromDropdown = false
          else
            self.selectedGroupBy = option.value
            UIDropDownMenu_SetText(self.groupByDropdown, option.text)
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end

  self.errorText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.errorText:SetPoint("TOPLEFT", self.groupByDropdown, "BOTTOMLEFT", addon.isRetail and 0 or 15, -20)
  self.errorText:SetWidth(self.frame:GetWidth() - 40)
  self.errorText:SetText("")
  self.errorText:SetTextColor(1, 0, 0)

  self.saveButton = CreateFrame("Button", addonName .. "SearchCategoryConfigSaveButton", self.frame, "UIPanelButtonTemplate")
  self.saveButton:SetSize(100, 30)
  self.saveButton:SetPoint("BOTTOMRIGHT", -20, 20)
  self.saveButton:SetText("Save")

  self.cancelButton = CreateFrame("Button", addonName .. "SearchCategoryConfigCancelButton", self.frame, "UIPanelButtonTemplate")
  self.cancelButton:SetSize(100, 30)
  self.cancelButton:SetPoint("RIGHT", self.saveButton, "LEFT", -10, 0)
  self.cancelButton:SetText("Cancel")

  addon.SetScript(self.saveButton, "OnClick", function(ctx)
    local name = self.nameBox:GetText()
    local query = self.queryBox.EditBox:GetText()
    if self.errorText:GetText() ~= "" and self.errorText:GetText() ~= nil then
      return
    end
    -- Strip the group by clause from the stored query (it's stored separately in groupBy field)
    local cleanQuery = self:StripGroupByFromQuery(query)
    categories:CreateCategory(ctx, {
      name = name,
      priority = tonumber(self.priorityBox:GetText()) or 10,
      save = true,
      itemList = {},
      searchCategory = {
        query = cleanQuery,
        groupBy = self.selectedGroupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE,
      }
    })
    if self.openedName ~= name and self.openedName ~= nil and self.openedName ~= "" then
      categories:DeleteCategory(ctx, self.openedName)
    end
    self.openedName = nil
    events:SendMessage(ctx, 'bags/FullRefreshAll')
    self.fadeOutGroup:Play()
  end)

  self.cancelButton:SetScript("OnClick", function()
    self.openedName = nil
    self.fadeOutGroup:Play()
  end)

  self.frame:Hide()
end

function searchCategoryConfig:IsShown()
  return self.frame:IsShown()
end

function searchCategoryConfig:Close(callback)
  self.fadeOutGroup.callback = function()
    self.fadeOutGroup.callback = nil
    callback()
  end
  self.fadeOutGroup:Play()
end

---@param filter CustomCategoryFilter
---@param f? Frame
function searchCategoryConfig:Open(filter, f)
  if filter.name == self.openedName then
    self.openedName = nil
    self.fadeOutGroup:Play()
    return
  end
  self.nameBox:SetText(filter.name)
  self.openedName = filter.name

  -- Load groupBy value
  self.selectedGroupBy = filter.searchCategory.groupBy or const.SEARCH_CATEGORY_GROUP_BY.NONE

  -- Display query with group by clause appended (if groupBy is set)
  local displayQuery = filter.searchCategory.query
  if self.selectedGroupBy ~= const.SEARCH_CATEGORY_GROUP_BY.NONE then
    displayQuery = self:SetGroupByInQuery(displayQuery, self.selectedGroupBy)
  end
  self.queryBox.EditBox:SetText(displayQuery)

  self.priorityBox:SetText(tostring(filter.priority) or "10")

  -- Update dropdown display
  self:UpdateDropdownDisplay()

  self.fadeInGroup.callback = function()
    self.nameBox:SetFocus()
    self:CheckNameboxText()
  end
  self.frame:ClearAllPoints()
  if f then
    self.frame:SetPoint("TOPRIGHT", f, "TOPLEFT", -10, 0)
  else
    self.frame:SetPoint("CENTER")
  end
  self.fadeInGroup:Play()
end
