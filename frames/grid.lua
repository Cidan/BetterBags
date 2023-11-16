local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class GridFrame: AceModule
local grid = addon:NewModule('Grid')

---@class Cell
---@field frame Frame
local cellProto = {}

------
--- Grid Proto
------

---@class Grid
---@field frame Frame
---@field cells Cell[]|Item[]|Section[]
---@field columns Column[]
---@field cellToColumn table<Cell|Item|Section, Column>
---@field maxCellWidth number The maximum number of cells per row.
local gridProto = {}

function gridProto:Show()
  self.frame:Show()
end

function gridProto:Hide()
  self.frame:Hide()
end

-- AddCell will add a cell to this grid.
---@param id string|nil
---@param cell Cell|Section|Item
function gridProto:AddCell(id, cell)
  assert(id, 'id is required')
  assert(cell, 'cell is required')
  assert(cell.frame, 'the added cell must have a frame')
  cell.frame:SetParent(self.frame)
  table.insert(self.cells, cell)
end

-- RemoveCell will removed a cell from this grid.
---@param id string|nil
---@param cell Cell|Section|Item
function gridProto:RemoveCell(id, cell)
  assert(id, 'id is required')
  assert(cell, 'cell is required')
  for i, c in ipairs(self.cells) do
    if c == cell then
      cell.frame:SetParent(nil)
      table.remove(self.cells, i)
      return
    end
  end
  assert(false, 'cell not found')
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
  local maxWidth = 0
  local maxHeight = 0

  for i, cell in ipairs(self.cells) do
    cell.frame:ClearAllPoints()
    if i == 1 then
      cell.frame:SetPoint('TOPLEFT', self.frame, 'TOPLEFT', 0, 0)
      width = cell.frame:GetWidth()
      height = cell.frame:GetHeight()
    elseif i % self.maxCellWidth == 1 then
      cell.frame:SetPoint('TOPLEFT', self.cells[i - self.maxCellWidth].frame, 'BOTTOMLEFT', 0, 0)
      maxWidth = math.max(maxWidth, width)
      maxHeight = math.max(maxHeight, height)
      height = math.max(height + cell.frame:GetHeight(), maxHeight)
      width = cell.frame:GetWidth()
    else
      cell.frame:SetPoint('TOPLEFT', self.cells[i - 1].frame, 'TOPRIGHT', 0, 0)
      width = width + cell.frame:GetWidth()
      height = math.max(height, cell.frame:GetHeight() + maxHeight)
    end
  end
  return math.max(width, maxWidth), height
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
  g.columns = {}
  g.cellToColumn = {}
  g.maxCellWidth = 5
  return g
end

grid:Enable()