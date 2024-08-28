local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemBrowser: AceModule
local itemBrowser = addon:NewModule('ItemBrowser')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class List: AceModule
local list = addon:GetModule('List')

---@class Node
---@field nodeType string
---@field kind BagKind
---@field slotInfo? SlotInfo
---@field itemData? ItemData
---@field key any
---@field data any

---@class ItemBrowserFrame
---@field list ListFrame
local itemBrowserFrame = {}

function itemBrowserFrame:Show()
  self.list:Show()
end

function itemBrowserFrame:Hide()
  self.list:Hide()
end

function itemBrowserFrame:GetFrame()
  return self.list.frame
end

function itemBrowserFrame:Update()
  self.list:Wipe()
end

---@param parent Frame
---@return ItemBrowserFrame
function itemBrowser:Create(parent)
  -- Stub: Implement creation logic
  local ib = setmetatable({}, {__index = itemBrowserFrame})
  ib.list = list:Create(parent)
  -- Create frame and setup basic structure
  return ib
end
