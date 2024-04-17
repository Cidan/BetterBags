local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Async: AceModule
local async = addon:GetModule('Async')

---@class (exact) ItemLoader
---@field private locations table<number, ItemLocationMixin>
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
  events:RegisterEvent('ITEM_DATA_LOAD_RESULT', function(event, ...)
    local itemID, success = select(1, ...)
    for _, itemLoader in pairs(self.loaders) do
      itemLoader:OnEvent(itemID, success)
    end
  end)
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

  self.locations[itemID] = itemLocation

end

function ItemLoader:Load(callback)
  async:Until(function()
    for _, location in pairs(self.locations) do
      C_Item.RequestLoadItemData(location)
    end
    if next(self.locations) == nil then
      loader.loaders[self.id] = nil
      return true
    end
    return false
  end, callback)
end

---@package
---@param itemID number
---@param success boolean
function ItemLoader:OnEvent(itemID, success)
  if self.locations[itemID] == nil then return end
  self.locations[itemID] = nil
end
