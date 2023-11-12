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
---@field cells Cell[]|Item[]|Section[]
---@field maxCellWidth number The maximum number of cells per row.
local gridProto = {}

function gridProto:Show()
  self.frame:Show()
end

function gridProto:Hide()
  self.frame:Hide()
end

-- AddCell will add a cell to this grid.
---@param cell Cell|Section|Item
function gridProto:AddCell(id, cell)
  assert(cell, 'cell is required')
  assert(cell.frame, 'the added cell must have a frame')
  cell.frame:SetParent(self.frame)
  table.insert(self.cells, cell)
end

-- Sort will sort the cells in this grid using the given function.
---@param fn fun(a: `T`, b: `T`):boolean
function gridProto:Sort(fn)
  table.sort(self.cells, fn)
end

-- Draw will draw the grid.
---@return number width
---@return number height
function gridProto:Draw()
  local width = 0
  local height = 0
  for i, cell in ipairs(self.cells) do
    cell.frame:ClearAllPoints()
    if i == 1 then
      cell.frame:SetPoint('TOPLEFT', self.frame, 'TOPLEFT', 0, 0)
      width = width + cell.frame:GetWidth()
      height = height + cell.frame:GetHeight()
    elseif i % self.maxCellWidth == 1 then
      cell.frame:SetPoint('TOPLEFT', self.cells[i - self.maxCellWidth].frame, 'BOTTOMLEFT', 0, 0)
      height = height + cell.frame:GetHeight()
    else
      cell.frame:SetPoint('TOPLEFT', self.cells[i - 1].frame, 'TOPRIGHT', 0, 0)
      if i <= self.maxCellWidth then
        width = width + cell.frame:GetWidth()
      end
    end
  end
  return width, height
end

function gridProto:Wipe()
  wipe(self.cells)
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
  g.cells = {}
  g.maxCellWidth = 5
  return g
end

grid:Enable()