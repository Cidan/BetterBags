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
---@field package bar EventFrame|MinimalScrollBar
---@field package box WowScrollBox
---@field package view Frame
---@field cells Cell[]|Item[]|Section[]
---@field idToCell table<string, Cell|Item|Section|BagButton>
---@field cellToID table<Cell|Item|Section|BagButton, string>
---@field headers Section[]
---@field columns Column[]
---@field cellToColumn table<Cell|Item|Section, Column>
---@field maxCellWidth number The maximum number of cells per row.
---@field spacing number
---@field compactStyle GridCompactStyle
---@field private scrollable boolean
---@field package scrollBox WowScrollBox
---@field private sortVertical boolean
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
  self.idToCell[id] = cell
  self.cellToID[cell] = id
end

-- AddCell will add a cell to this grid.
---@param id string
---@param cell Cell|Section|Item|BagButton
function gridProto:AddCell(id, cell)
  assert(id, 'id is required')
  assert(cell, 'cell is required')
  assert(cell.frame, 'the added cell must have a frame')
  if self.idToCell[id] ~= nil then return end
  table.insert(self.cells, cell)
  self.idToCell[id] = cell
  self.cellToID[cell] = id
end

-- RemoveCell will removed a cell from this grid.
---@param id string|nil
function gridProto:RemoveCell(id)
  assert(id, 'id is required')
  for i, c in ipairs(self.cells) do
    if c == self.idToCell[id] then
      table.remove(self.cells, i)
      for _, column in pairs(self.columns) do
        column:RemoveCell(id)
      end
      self.cellToID[self.idToCell[id]] = nil
      self.idToCell[id] = nil
      return
    end
  end
  --assert(false, 'cell not found')
end

function gridProto:RekeyCell(oldID, newID)
  local cell = self.idToCell[oldID]
  if cell == nil then
    return
  end
  local column = self.cellToColumn[cell] --[[@as Column]]
  column:RemoveCell(oldID)
  column:AddCell(newID, cell)
  self.idToCell[newID] = cell
  self.cellToID[cell] = newID
  self.idToCell[oldID] = nil
end

function gridProto:GetCell(id)
  return self.idToCell[id]
end

---@return table<string, Cell|Item|Section|BagButton>
function gridProto:GetAllCells()
  return self.idToCell
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

function gridProto:GetScrollView()
  return self.inner
end

function gridProto:HideScrollBar()
  self.bar:SetAlpha(0)
  self.bar:SetAttribute("nodeignore", true)
end

function gridProto:SortVertical()
  self.sortVertical = true
end

function gridProto:SortHorizontal()
  self.sortVertical = false
end

function gridProto:ShowScrollBar()
  self.bar:SetAttribute("nodeignore", false)
  self.bar:SetAlpha(1)
end

-- Sort will sort the cells in this grid using the given function.
---@param fn fun(a: `T`, b: `T`):boolean
function gridProto:Sort(fn)
  table.sort(self.cells, fn)
end

---@return number, number
function gridProto:stage()
  for _, column in pairs(self.columns) do
    column:RemoveAll()
    column:Release()
  end
  wipe(self.cellToColumn)
  wipe(self.columns)

  local width = 0 ---@type number
  local height = 0
  local currentColumn = 0
  -- Do not compact the cells at all and draw them in their ordered
  -- rows and columns.
  if self.compactStyle == const.GRID_COMPACT_STYLE.SIMPLE or
  self.compactStyle == const.GRID_COMPACT_STYLE.NONE then
    for i, cell in ipairs(self.cells) do
      cell.frame:ClearAllPoints()

      ---@type number
      local columnKey
      if self.sortVertical then
        -- Calculate a column key such that all cells in the cell list are
        -- distributed equally among however many columns are defined by self.maxCellWidth, i.e. depth first.
        if self.columns[currentColumn] and #self.columns[currentColumn].cells > #self.cells / self.maxCellWidth then
          currentColumn = currentColumn + 1
        end
        columnKey = currentColumn
      else
        -- Get the current column for a given cell order, left to right, i.e. bredth first.
        columnKey = i % self.maxCellWidth
      end
      local column = self.columns[columnKey]
      if column == nil then
        -- Create the column if it doesn't exist and position it within
        -- the grid.
        column = columnFrame:Create()
        column.spacing = self.spacing
        column.frame:SetParent(self.inner)
        self.columns[columnKey] = column
        if self.sortVertical then
          if columnKey == 0 then
            column.frame:SetPoint("TOPLEFT", self.inner, "TOPLEFT", 0, 0)
          else
            local previousColumn = self.columns[columnKey - 1]
            column.frame:SetPoint("TOPLEFT", previousColumn.frame, "TOPRIGHT", self.spacing, 0)
          end
        else
          if i == 1 then
            column.frame:SetPoint("TOPLEFT", self.inner, "TOPLEFT", 0, 0)
          else
            local previousColumn = self.columns[i - 1]
            column.frame:SetPoint("TOPLEFT", previousColumn.frame, "TOPRIGHT", self.spacing, 0)
          end
        end
      end
      -- Add the cell to the column.
      column:AddCell(self.cellToID[cell], cell)
      self.cellToColumn[cell] = column
      cell.frame:Show()
    end
  elseif self.compactStyle == const.GRID_COMPACT_STYLE.COMPACT then
  end
  return width, height
end

---@param width number
---@param height number
---@return number, number
function gridProto:render(width, height)
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

-- Draw will draw the grid.
---@return number width
---@return number height
function gridProto:Draw()
  return self:render(self:stage())
end

-- Clear will remove and release all columns from the grid,
-- but will not release cells.
function gridProto:Clear()
  for _, column in pairs(self.columns) do
    column:RemoveAll()
    column:Release()
  end
  wipe(self.cellToColumn)
  wipe(self.columns)
  wipe(self.cells)
  wipe(self.idToCell)
  wipe(self.cellToID)
end

-- Wipe completely removes all cells and columns from the grid
-- and releases all cells and columns.
function gridProto:Wipe()
  for _, column in pairs(self.columns) do
    column:Release()
  end
  wipe(self.cellToColumn)
  wipe(self.columns)
  wipe(self.cells)
  wipe(self.idToCell)
  wipe(self.cellToID)
end

local scrollFrameCounter = 0
---@private
---@param g Grid
---@param parent Frame
---@param child Frame
---@return WowScrollBox
function grid:CreateScrollFrame(g, parent, child)
  local box = CreateFrame("Frame", "BetterBagsScrollGrid"..scrollFrameCounter, parent, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetAllPoints(parent)
  box:SetInterpolateScroll(true)
  local bar = CreateFrame("EventFrame", nil, box, "MinimalScrollBar")
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", -12, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", -12, 0)
  bar:SetInterpolateScroll(true)

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(100)

  child:SetParent(box)
  child.scrollable = true
  g.bar = bar
  g.box = box
  g.view = view
  ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view)
  scrollFrameCounter = scrollFrameCounter + 1
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

  g.frame = f
  g.inner = c
  g.cells = {}
  g.idToCell = {}
  g.cellToID = {}
  g.columns = {}
  g.cellToColumn = {}
  g.headers = {}
  g.maxCellWidth = 5
  g.compactStyle = const.GRID_COMPACT_STYLE.NONE
  g.spacing = 4
  g:SortHorizontal()
  g.bar:Show()
  -- Fixes a bug where the frame is not visble when anchored to the parent.
  g.frame:SetSize(1,1)
  return g
end

grid:Enable()