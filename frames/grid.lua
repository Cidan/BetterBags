local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class ColumnFrame: AceModule
local columnFrame = addon:GetModule('ColumnFrame')

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
---@param cell Cell|Section|Item|BagButton
function gridProto:AddCell(id, cell)
  assert(id, 'id is required')
  assert(cell, 'cell is required')
  assert(cell.frame, 'the added cell must have a frame')
  table.insert(self.cells, cell)
end

-- RemoveCell will removed a cell from this grid.
---@param id string|nil
---@param cell Cell|Section|Item|BagButton
function gridProto:RemoveCell(id, cell)
  assert(id, 'id is required')
  assert(cell, 'cell is required')
  for i, c in ipairs(self.cells) do
    if c == cell then
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
  -- Wipe and release all columns.
  for _, column in pairs(self.columns) do
    columnFrame:Release(column)
  end
  wipe(self.columns)
  wipe(self.cellToColumn)

  local width = 0
  local height = 0
  for i, cell in ipairs(self.cells) do
    cell.frame:ClearAllPoints()
    -- Get the current column for a given cell order, left to right.
    local column = self.columns[i % self.maxCellWidth]
    if column == nil then
      -- Create the column if it doesn't exist and position it within
      -- the grid.
      column = columnFrame:Create()
      column.frame:SetParent(self.frame)
      self.columns[i % self.maxCellWidth] = column
      if i == 1 then
        column.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
      else
        local previousColumn = self.columns[i - 1]
        column.frame:SetPoint("TOPLEFT", previousColumn.frame, "TOPRIGHT", 0, 0)
      end
    end
    -- Add the cell to the column.
    column:AddCell(cell)
    self.cellToColumn[cell] = column
    cell.frame:Show()
  end

  -- Draw all the columns and their cells.
  for _, column in pairs(self.columns) do
    local w, h = column:Draw()
    width = width + w
    height = math.max(height, h)
  end

  return width, height
end

function gridProto:Wipe()
  for _, column in pairs(self.columns) do
    column:Release()
  end
  for _, cell in pairs(self.cells) do
    cell:Release()
  end
  wipe(self.columns)
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