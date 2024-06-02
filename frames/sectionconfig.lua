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

local fakeDatabase = {}

---@param button BetterBagsSectionConfigListButton
---@param elementData table
function sectionConfigFrame:initSectionItem(button, elementData)
  button.Category:SetText(elementData.title)
  button.Category:SetPoint("LEFT", button.Enabled, "RIGHT", 10, 0)
  if fakeDatabase[elementData.title] then
    button.Enabled:SetTexture("Interface\\raidframe\\readycheck-ready")
  else
        button.Enabled:SetTexture("")
    --button.Enabled:SetTexture("Interface\\raidframe\\readycheck-notready")
  end
  button:SetScript("OnMouseDown", function(_, key)
    if key == "RightButton" then
      if fakeDatabase[elementData.title] then
        fakeDatabase[elementData.title] = false
        button.Enabled:SetTexture("")
        --button.Enabled:SetTexture("Interface\\raidframe\\readycheck-notready")
      else
        fakeDatabase[elementData.title] = true
        button.Enabled:SetTexture("Interface\\raidframe\\readycheck-ready")
      end
      --button.Enabled:SetTexture("Interface\\raidframe\\readycheck-ready")
      print("right clicked on ", elementData.title)
      events:SendMessage('config/SectionSelected', elementData.title)
    end
  end)
end

---@param button BetterBagsSectionConfigListButton
---@param elementData table
function sectionConfigFrame:resetSectionItem(button, elementData)
  _ = elementData
  _ = button
end

function sectionConfigFrame:AddSection(name)
  if self.content:HasItem({ title = name }) then
    return
  end
  self.content:AddToStart({ title = name })
end

function sectionConfigFrame:Wipe()
  self.content:Wipe()
end

function sectionConfigFrame:GetLastEnabledItem()
end

---@param parent Frame
---@return SectionConfigFrame
function sectionConfig:Create(parent)
  local sc = setmetatable({}, { __index = sectionConfigFrame })
  sc.frame = CreateFrame("Frame", nil, parent, "BackdropTemplate") --[[@as Frame]]
  sc.content = list:Create(sc.frame)
  sc.content.frame:SetAllPoints()
  sc.content:SetupDataSource("BetterBagsSectionConfigListButton", function(f, data)
    ---@cast f BetterBagsSectionConfigListButton
    sc:initSectionItem(f, data)
  end,
  function(f, data)
    ---@cast f BetterBagsSectionConfigListButton
    sc:resetSectionItem(f, data)
  end)
  sc.content:SetCanReorder(true, function(ev, elementData, currentIndex, newIndex)
    print("reorder", elementData.title, currentIndex, newIndex)
    events:SendMessage('bags/FullRefreshAll')
  end)
  return sc
end
