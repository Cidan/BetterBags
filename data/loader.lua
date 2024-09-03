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

---@class Items: AceModule
---@field private loaders ItemLoader[]
---@field private loadCount number
local items = addon:GetModule('Items')

--- ItemLoader for loading bag items.
---@class (exact) ItemLoader
---@field private locations table<string, ItemMixin>
---@field private callback fun()
---@field private id number
---@field private kind BagKind
---@field private data table<string, ItemData>
---@field private equipmentData table<number, ItemData>
---@field private mixins ItemMixin[]
local ItemLoader = {}

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
  itemLoader.equipmentData = {}
  itemLoader.mixins = {}
  self.loaders[itemLoader.id] = itemLoader
  self.loadCount = self.loadCount + 1
  return itemLoader
end

---@param itemMixin ItemMixin
function ItemLoader:Add(itemMixin)
  local itemLocation = itemMixin:GetItemLocation()
  if itemLocation == nil then return end

  table.insert(self.mixins, itemMixin)
end

---@param itemMixin ItemMixin
function ItemLoader:AddInventorySlot(itemMixin)
 if itemMixin:IsItemEmpty() then return end
  local itemGUID = itemMixin:GetItemGUID()
  if itemGUID == nil then return end
  self.locations[itemGUID] = itemMixin

  itemMixin:ContinueOnItemLoad(function()
    if itemMixin:IsItemDataCached() then
      local data = items:GetEquipmentInfo(itemMixin)
      self.equipmentData[data.inventorySlots[1]] = data
      self.locations[itemGUID] = nil
    end
  end)
end

---@param itemMixin ItemMixin
function ItemLoader:ProcessMixin(itemMixin)
  local itemLocation = itemMixin:GetItemLocation()
  if itemLocation == nil then return end

  if not itemMixin:IsItemEmpty() then
    local data = {}
    ---@cast data +ItemData
    data.bagid, data.slotid = itemMixin:GetItemLocation():GetBagAndSlot()
    items:AttachItemInfo(data, self.kind)
    self.data[items:GetSlotKey(data)] = data
    return
  end

  local itemGUID = itemMixin:GetItemGUID()
  if itemGUID == nil then return end
  self.locations[itemGUID] = itemMixin

  itemMixin:ContinueOnItemLoad(function()
    if itemMixin:IsItemDataCached() then
      local data = {}
      ---@cast data +ItemData
      data.bagid, data.slotid = itemMixin:GetItemLocation():GetBagAndSlot()
      items:AttachItemInfo(data, self.kind)
      self.data[items:GetSlotKey(data)] = data
      self.locations[itemGUID] = nil
    end
  end)
end

---@param ctx Context
---@param callback fun(ctx: Context)
function ItemLoader:Load(ctx, callback)
  async:Batch(ctx, 10, self.mixins, function(_, itemMixin, _)
    self:ProcessMixin(itemMixin)
  end, function(ectx)
    async:Until(ectx, function(_)
      for itemGUID, location in pairs(self.locations) do
        local l = location:GetItemLocation()
        if l == nil or (l.IsValid and not l:IsValid()) then
          self.locations[itemGUID] = nil
        else
          C_Item.RequestLoadItemData(l)
        end
      end
      if next(self.locations) == nil then
        items.loaders[self.id] = nil
        wipe(self.mixins)
        return true
      end
      return false
    end, function(ictx)
      callback(ictx)
    end)
  end)
end

---@return table<string, ItemData>
function ItemLoader:GetDataCache()
  return self.data
end

---@return table<number, ItemData>
function ItemLoader:GetEquipmentDataCache()
  return self.equipmentData
end