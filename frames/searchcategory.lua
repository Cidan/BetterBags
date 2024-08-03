local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

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

end

---@param searchCategory SearchCategory
function searchCategoryConfig:Open(searchCategory)
  self.nameBox:SetText(searchCategory.name)
  self.queryBox.EditBox:SetText(searchCategory.query)
  self.frame:Show()
end