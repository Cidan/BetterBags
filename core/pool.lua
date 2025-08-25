local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Pool: AceModule
local pool = addon:NewModule('Pool')

---@class PoolItem
---@field private createFn fun(ctx: Context): any
---@field private resetFn fun(ctx: Context, item: any)
---@field private items any[]
local poolItem = {}

---@param ctx Context
---@return any
function poolItem:Acquire(ctx)
  if #self.items == 0 then
    local item = self.createFn(ctx)
    return item
  end
  local item = table.remove(self.items)
  return item
end

---@param ctx Context
---@param item any
function poolItem:Release(ctx, item)
  self.resetFn(ctx, item)
  table.insert(self.items, item)
end

---@generic T
---@param createFn fun(ctx: Context): T
---@param resetFn fun(ctx: Context, item: T)
---@return PoolItem
function pool:Create(createFn, resetFn)
  local obj = setmetatable({
    createFn = createFn,
    resetFn = resetFn,
    items = {},
  }, {__index = poolItem})
  return obj
end
