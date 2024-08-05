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

---@class SearchCategoryConfig: AceModule
---@field frame Frame
---@field openedName string
local searchCategoryConfig = addon:NewModule('SearchCategoryConfig')

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

  self.frame:SetSize(430, 380)
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

  self.queryBox = CreateFrame("ScrollFrame", addonName .. "SearchCategoryConfigQueryBox", self.frame, "InputScrollFrameTemplate")
  self.queryBox:SetSize(400, 100)
  self.queryBox.EditBox:SetSize(200, 300)
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

  self.errorText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.errorText:SetPoint("TOPLEFT", self.priorityBox, "BOTTOMLEFT", 0, -20)
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

  self.saveButton:SetScript("OnClick", function()
    local name = self.nameBox:GetText()
    local query = self.queryBox.EditBox:GetText()
    if self.errorText:GetText() ~= "" and self.errorText:GetText() ~= nil then
      return
    end
    categories:CreateCategory({
      name = name,
      priority = tonumber(self.priorityBox:GetText()) or 10,
      save = true,
      itemList = {},
      searchCategory = {
        query = query,
      }
    })
    if self.openedName ~= name and self.openedName ~= nil and self.openedName ~= "" then
      categories:DeleteCategory(self.openedName)
    end
    self.openedName = nil
    events:SendMessage('bags/FullRefreshAll')
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
  self.queryBox.EditBox:SetText(filter.searchCategory.query)
  self.priorityBox:SetText(tostring(filter.priority) or "10")
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
