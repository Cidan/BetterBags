local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Async: AceModule
local async = addon:GetModule('Async')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) ItemLoader
---@field private locations table<number, ItemMixin>
---@field private callback fun()
---@field private id number
---@field private kind BagKind
---@field private data table<string, ItemData>
local ItemLoader = {}

---@class Items: AceModule
---@field private loaders ItemLoader[]
---@field private loadCount number
local items = addon:GetModule('Items')

---@param kind BagKind
---@return ItemLoader
function items:NewLoader(kind)
  if not self.loaders then
    self.loaders = {}
    self.loadCount = 1
  end
  local itemLoader = {}
  setmetatable(itemLoader, {__index = ItemLoader})
  itemLoader.locations = {}
  itemLoader.id = self.loadCount
  itemLoader.kind = kind
  itemLoader.data = {}
  self.loaders[itemLoader.id] = itemLoader
  self.loadCount = self.loadCount + 1
  return itemLoader
end

---@param itemMixin ItemMixin
function ItemLoader:Add(itemMixin)
  local itemLocation = itemMixin:GetItemLocation()
  if itemLocation == nil then return end

  if itemMixin:IsItemEmpty() then
    local data = {}
    ---@cast data +ItemData
    data.bagid, data.slotid = itemMixin:GetItemLocation():GetBagAndSlot()
    items:AttachItemInfo(data, self.kind)
    self.data[items:GetSlotKey(data)] = data
    return
  end

  local itemID = itemMixin:GetItemID()
  if itemID == nil then return end
  self.locations[itemID] = itemMixin

  itemMixin:ContinueOnItemLoad(function()
    if itemMixin:IsItemDataCached() then
      local data = {}
      ---@cast data +ItemData
      data.bagid, data.slotid = itemMixin:GetItemLocation():GetBagAndSlot()
      items:AttachItemInfo(data, self.kind)
      self.data[items:GetSlotKey(data)] = data
      self.locations[itemID] = nil
    end
  end)
end

function ItemLoader:Load(callback)
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
      items.loaders[self.id] = nil
      return true
    end
    return false
  end, function()
    callback()
  end)
end

---@return table<string, ItemData>
function ItemLoader:GetDataCache()
  return self.data
end