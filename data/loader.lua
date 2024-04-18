local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Async: AceModule
local async = addon:GetModule('Async')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) ItemLoader
---@field private locations table<number, ItemMixin>
---@field private callback fun()
---@field private id number
local ItemLoader = {}

---@class (exact) Loader: AceModule
---@field private eventFrame Frame
---@field private loaders ItemLoader[]
---@field private loadCount number
local loader = addon:NewModule('Loader')

function loader:OnInitialize()
  self.loaders = {}
  self.loadCount = 1
end

---@return ItemLoader
function loader:New()
  local itemLoader = {}
  setmetatable(itemLoader, {__index = ItemLoader})
  itemLoader.locations = {}
  itemLoader.id = self.loadCount
  self.loaders[itemLoader.id] = itemLoader
  self.loadCount = self.loadCount + 1
  return itemLoader
end

---@param itemMixin ItemMixin
function ItemLoader:Add(itemMixin)
  local itemLocation = itemMixin:GetItemLocation()
  if itemLocation == nil then return end
  local itemID = itemMixin:GetItemID()
  if itemID == nil then return end
  self.locations[itemID] = itemMixin
  itemMixin:ContinueOnItemLoad(function()
    if itemMixin:IsItemDataCached() then
      local bagid, slotid = itemMixin:GetItemLocation():GetBagAndSlot()
      C_Container.GetContainerItemLink(bagid, slotid)
      debug:Log("AsyncDebug", "Item Was Cached, Removing From Loader", bagid, slotid, itemMixin:GetItemLink(), C_Container.GetContainerItemLink(bagid, slotid))
      self.locations[itemID] = nil
    end
  end)
end

function ItemLoader:Load(callback)
  repeat
    for itemID, location in pairs(self.locations) do
      local l = location:GetItemLocation()
      if l == nil then
        self.locations[itemID] = nil
      else
        C_Item.RequestLoadItemData(l)
      end
    end
  until next(self.locations) == nil
  callback()
  --[[
  async:Until(function()
    for itemID, location in pairs(self.locations) do
      local l = location:GetItemLocation()
      if l == nil then
        self.locations[itemID] = nil
      else
        C_Item.RequestLoadItemData(l)
      end
    end
    if next(self.locations) == nil then
      loader.loaders[self.id] = nil
      return true
    end
    return false
  end, callback)
  ]]--
end
