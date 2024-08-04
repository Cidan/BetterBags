local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class SearchCategoryConfig: AceModule
---@field frame Frame
local searchCategoryConfig = addon:NewModule('SearchCategoryConfig')

function searchCategoryConfig:OnEnable()
  self.frame = CreateFrame("Frame", addonName .. "SearchCategoryConfig", UIParent)
  themes:RegisterFlatWindow(self.frame, "Configure Search Category")

  self.frame:SetSize(800, 600)
  self.frame:SetPoint("CENTER")
  self.frame:SetMovable(true)
  self.frame:EnableMouse(true)
  self.frame:SetClampedToScreen(true)
  self.frame:RegisterForDrag("LeftButton")
  self.frame:SetScript("OnDragStart", self.frame.StartMoving)
  self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)

  self.nameBoxLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.nameBoxLabel:SetPoint("TOPLEFT", 20, -40)
  self.nameBoxLabel:SetText("Category Name")

  self.nameBox = CreateFrame("EditBox", addonName .. "SearchCategoryConfigNameBox", self.frame, "InputBoxTemplate")
  self.nameBox:SetSize(200, 20)
  self.nameBox:SetPoint("TOPLEFT", self.nameBoxLabel, "BOTTOMLEFT", 2, -7)
  self.nameBox:SetAutoFocus(false)
  self.nameBox:SetFontObject("GameFontHighlight")

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
    if name == "" then
      return
    end
    if query == "" then
      return
    end
    categories:CreateOrUpdateSearchCategory({
      name = name,
      query = query,
      save = true,
    })
    events:SendMessage('bags/FullRefreshAll')
    self.frame:Hide()
  end)

  self.cancelButton:SetScript("OnClick", function()
    self.frame:Hide()
  end)

  self.frame:Hide()
end

---@param searchCategory SearchCategory
function searchCategoryConfig:Open(searchCategory)
  self.nameBox:SetText(searchCategory.name)
  self.queryBox.EditBox:SetText(searchCategory.query)
  self.frame:Show()
  self.nameBox:SetFocus()
end