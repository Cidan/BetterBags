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

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class SectionConfig: AceModule
local sectionConfig = addon:NewModule('SectionConfig')

---@class SectionConfigItem
---@field frame Frame
---@field label FontString
local sectionConfigItem = {}

---@class SectionConfigFrame
---@field frame Frame
---@field content Grid
local sectionConfigFrame = {}

function sectionConfigFrame:AddSection(name)
  local section = setmetatable({}, { __index = sectionConfigItem })
  section.frame = CreateFrame("Frame", nil, self.frame, "BackdropTemplate") --[[@as Frame]]
  section.frame:SetSize(360, 20)
  section.frame:EnableMouse(true)
  section.frame:SetMovable(true)
  section.frame:SetScript("OnMouseDown", function()
    section.frame:ClearAllPoints()
    section.frame:SetParent(UIParent)
    section.frame:StartMoving(true)
  end)
  section.label = section.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight") --[[@as FontString]]
  section.label:SetPoint("LEFT", 10, 0)
  section.label:SetText(name)
  debug:DrawBorder(section.frame, 1, 0, 0, true)
  self.content:AddCell(name, section)
  self.content:Draw()
  self.content:ShowScrollBar()
end

---@param parent Frame
---@return SectionConfigFrame
function sectionConfig:Create(parent)
  local sc = setmetatable({}, { __index = sectionConfigFrame })
  sc.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate") --[[@as Frame]]
  sc.content = grid:Create(sc.frame)
  sc.content:GetContainer():SetPoint("TOPLEFT", 10, -10)
  sc.content:GetContainer():SetPoint("BOTTOMRIGHT", -10, 10)

  sc.content.maxCellWidth = 1
  return sc
end
