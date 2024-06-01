local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class List: AceModule
local list = addon:GetModule('List')

---@class SectionConfig: AceModule
local sectionConfig = addon:NewModule('SectionConfig')

---@class SectionConfigItem
---@field frame Frame
---@field label FontString
local sectionConfigItem = {}

---@class SectionConfigFrame
---@field frame Frame
---@field content ListFrame
local sectionConfigFrame = {}

---@param button BetterBagsDebugListButton
---@param elementData table
local function initSectionItem(button, elementData)
  button.Category:SetText(elementData.title)
  button.Category:SetPoint("LEFT", button.RowNumber, "RIGHT", 10, 0)
end

function sectionConfigFrame:AddSection(name)
  self.content:AddToStart({ title = name })
end

---@param parent Frame
---@return SectionConfigFrame
function sectionConfig:Create(parent)
  local sc = setmetatable({}, { __index = sectionConfigFrame })
  sc.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate") --[[@as Frame]]
  sc.content = list:Create(sc.frame)
  sc.content.frame:SetAllPoints()
  sc.content:SetupDataSource("BetterBagsSectionConfigListButton", initSectionItem)
  sc.content:SetCanReorder(true)
  return sc
end
