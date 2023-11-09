local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class GridFrame: AceModule
local grid = addon:NewModule('Grid')

---@class Cell
---@field frame Frame
local cellProto = {}

---@class Grid
---@field frame Frame
---@field cells any[]
local gridProto = {}

function gridProto:Show()
  self.frame:Show()
end

function gridProto:Hide()
  self.frame:Hide()
end

-- AddCell will add a cell to this grid.
---@param cell Cell|Section
function gridProto:AddCell(cell)
  assert(cell, 'cell is required')
  assert(cell.frame, 'the added cell must have a frame')
  table.insert(self.cells, cell)
end

-- Sort will sort the cells in this grid using the given function.
---@param fn fun(a: `T`, b: `T`):boolean
function gridProto:Sort(fn)
  table.sort(self.cells, fn)
end

-- Create will create a new grid frame.
---@param parent Frame
---@return Grid
function grid:Create(parent)
  local g = setmetatable({}, { __index = gridProto })
  ---@class Frame: BackdropTemplate
  local f = CreateFrame('Frame', nil, nil, "BackdropTemplate")
  f:SetParent(parent)
  g.frame = f
  return g
end