local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class ColumnFrame: AceModule
local columnFrame = addon:GetModule('ColumnFrame')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:NewModule('Grid')

---@class Cell
---@field frame Frame
local cellProto = {}

------
--- Grid Proto
------

---@class Grid
---@field package frame WowScrollBox
---@field package inner Frame
---@field package bar MinimalScrollBar
---@field cells Cell[]|Item[]|Section[]
---@field columns Column[]
---@field cellToColumn table<Cell|Item|Section, Column>
---@field maxCellWidth number The maximum number of cells per row.
---@field compactStyle GridCompactStyle
---@field private scrollable boolean
---@field package scrollBox WowScrollBox
local gridProto = {}

function gridProto:Show()
  self.frame:Show()
end

function gridProto:Hide()
  self.frame:Hide()
end

---@param id string|nil
---@param cell Cell|Section|Item|BagButton
function gridProto:AddCellToLastColumn(id, cell)
  assert(id, 'id is required')
  assert(cell, 'cell is required')
  assert(cell.frame, 'the added cell must have a frame')
  local position = 0
  for i, _ in ipairs(self.cells) do
    if i % self.maxCellWidth == self.maxCellWidth - 1 then
      position = i
    end
  end
  table.insert(self.cells, position+1, cell)
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
      for _, column in pairs(self.columns) do
        column:RemoveCell(cell)
      end
      return
    end
  end
  --assert(false, 'cell not found')
end

---@private
---@return Frame|WowScrollBox
function gridProto:GetFrame()
  if self.scrollable then
    return self.scrollBox
  end
  return self.frame
end

function gridProto:GetContainer()
  return self.frame
end

function gridProto:HideScrollBar()
  self.bar:Hide()
end

function gridProto:ShowScrollBar()
  self.bar:Show()
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
  for _, column in pairs(self.columns) do
    column:RemoveAll()
    column:Release()
  end
  wipe(self.cellToColumn)
  wipe(self.columns)

  local width = 0 ---@type number
  local height = 0

  -- Do not compact the cells at all and draw them in their ordered
  -- rows and columns.
  if self.compactStyle == const.GRID_COMPACT_STYLE.SIMPLE or
  self.compactStyle == const.GRID_COMPACT_STYLE.NONE then
    for i, cell in ipairs(self.cells) do
      cell.frame:ClearAllPoints()
      -- Get the current column for a given cell order, left to right.
      local column = self.columns[i % self.maxCellWidth]
      if column == nil then
        -- Create the column if it doesn't exist and position it within
        -- the grid.
        column = columnFrame:Create()
        column.frame:SetParent(self.inner)
        self.columns[i % self.maxCellWidth] = column
        if i == 1 then
          column.frame:SetPoint("TOPLEFT", self.inner, "TOPLEFT", 0, 0)
        else
          local previousColumn = self.columns[i - 1]
          column.frame:SetPoint("TOPLEFT", previousColumn.frame, "TOPRIGHT", 4, 0)
        end
      end
      -- Add the cell to the column.
      column:AddCell(cell)
      self.cellToColumn[cell] = column
      cell.frame:Show()
    end
  elseif self.compactStyle == const.GRID_COMPACT_STYLE.COMPACT then
  end
  -- Draw all the columns and their cells.
  for _, column in pairs(self.columns) do
    local w, h = column:Draw(self.compactStyle)
    width = width + w + 4
    height = math.max(height, h)
  end

  -- Remove the last 4 pixels of padding.
  if width > 4 then
    width = width - 4 ---@type number
  end
  self.inner:SetSize(width, height)
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

---@private
---@param g Grid
---@param parent Frame
---@return WowScrollBox
function grid:CreateScrollFrame(g, parent, child)
  local box = CreateFrame("Frame", nil, parent, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetAllPoints(parent)
  box:SetInterpolateScroll(true)

  local bar = CreateFrame("EventFrame", nil, box, "MinimalScrollBar")
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", -10, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", -10, 0)
  bar:SetInterpolateScroll(true)

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(100)

  child:SetParent(box)
  child.scrollable = true
  g.bar = bar
  g.box = box
  g.view = view
  ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view)
  return box
end

-- Create will create a new grid frame.
---@param parent Frame
---@return Grid
function grid:Create(parent)
  local g = setmetatable({}, { __index = gridProto })
  ---@class Frame
  local c = CreateFrame("Frame")

  ---@class WowScrollBox
  local f = grid:CreateScrollFrame(g, parent, c)

  --f:SetParent(parent)
  g.frame = f
  g.inner = c
  g.cells = {}
  g.columns = {}
  g.cellToColumn = {}
  g.maxCellWidth = 5
  g.compactStyle = const.GRID_COMPACT_STYLE.NONE
  g.bar:Show()
  --g.scrollBox = grid:CreateScrollFrame(f)
  --g.scrollBox:Hide()
  return g
end

grid:Enable()