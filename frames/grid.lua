local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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
---@field cells Cell[]|Item[]|Section[]|any[]
---@field idToCell table<string, Cell|Item|Section|BagButton|any>
---@field cellToID table<Cell|Item|Section|BagButton|any, string>
---@field headers Section[]
---@field maxCellWidth number The maximum number of cells per row.
---@field spacing number
---@field compactStyle GridCompactStyle
---@field private scrollable boolean
---@field package scrollBox WowScrollBox
---@field private sortVertical boolean
local gridProto = {}

---@class (exact) RenderOptions
---@field cells Cell[] The cells to render in this grid.
---@field maxWidthPerRow number The maximum width of a row before it wraps.
---@field columns? number The number of columns to render. If not set, columns is 1.
---@field header? Cell A Cell to render above all other items, ignoring columns.

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
---@param cell Cell|Section|Item|BagButton|any
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
function gridProto:stageSimple()
  return 1,1
end

-- calculateColumns takes a list of cells and a column count. It will then
-- return a list of list of cells, where each list of cells is a column.
-- The columns are divided evenly by the height of all the cell frames
-- in a given column.
---@param cells Cell[]
---@param options RenderOptions
---@return Cell[][]
function gridProto:calculateColumns(cells, options)
  if not options.columns or options.columns == 1 then
    return {[1] = cells}
  end
  --local rowWidth = 0
  local totalHeight = 0
  ---@type Cell[][]
  local columns = {}
  for _, cell in ipairs(cells) do
    --TODO(lobato): Calculate total height based on compressed heights.
    --if i ~= 1 then
    --  if rowWidth + cell.frame:GetWidth() > options.maxWidthPerRow then
    --    totalHeight = totalHeight + cell.frame:GetHeight()
    --    rowWidth = cell.frame:GetWidth()
    --  else
    --    rowWidth = rowWidth + cell.frame:GetWidth() + self.spacing
    --  end
    --else
    --  totalHeight = totalHeight + cell.frame:GetHeight()
    --end
    totalHeight = totalHeight + cell.frame:GetHeight()
  end

  local splitAt = math.ceil(totalHeight / options.columns)
  local currentHeight = 0
  local currentColumn = 1
  for _, cell in ipairs(cells) do
    if currentHeight + cell.frame:GetHeight() > splitAt then
      currentColumn = currentColumn + 1
      currentHeight = 0
    else
      currentHeight = currentHeight + cell.frame:GetHeight()
    end
    if not columns[currentColumn] then
      columns[currentColumn] = {}
    end
    table.insert(columns[currentColumn], cell)
  end
  return columns
end

---@param cells Cell[]
---@param options RenderOptions
---@param currentOffset number
---@return number, number
function gridProto:layoutSingleColumn(cells, options, currentOffset)
  local w = 0
  local rowWidth = 0
  local h = 0
  local rowStart = cells[1]
  for i, cell in ipairs(cells) do
    cell.frame:SetParent(self.inner)
    cell.frame:ClearAllPoints()
    local relativeToFrame = self.inner
    local relativeToPoint = "TOPLEFT"
    local spacingX = 0
    local spacingY = 0
    if i ~= 1 then
      if rowWidth + cell.frame:GetWidth() > options.maxWidthPerRow then
        -- Get the first cell in the previous row.
        relativeToFrame = rowStart.frame
        h = h + cell.frame:GetHeight()
        rowWidth = cell.frame:GetWidth()
        w = math.max(w, rowWidth)
        relativeToPoint = "BOTTOMLEFT"
        rowStart = cell
      else
        local previousCell = cells[i - 1]
        relativeToFrame = previousCell.frame
        relativeToPoint = "TOPRIGHT"
        spacingX = self.spacing
        rowWidth = rowWidth + cell.frame:GetWidth() + spacingX
        w = math.max(w, rowWidth)
      end
    else
      h = h + cell.frame:GetHeight()
      rowWidth = cell.frame:GetWidth()
      w = rowWidth
      rowStart = cell
      spacingX = currentOffset
    end
    cell.frame:SetPoint("TOPLEFT", relativeToFrame, relativeToPoint, spacingX, spacingY)
    cell.frame:Show()
  end
  return w, h
end

---@param options RenderOptions
---@return number, number
function gridProto:stage(options)
  if not options then return 0, 0 end
  local w = 0
  local h = 0
  local columns = self:calculateColumns(options.cells, options)
  local currentOffset = 0
  for _, column in ipairs(columns) do
    local columnWidth, columnHeight = self:layoutSingleColumn(column, options, currentOffset)
    w = w + columnWidth
    h = math.max(h, columnHeight)
    currentOffset = currentOffset + columnWidth
  end
  if options.header then
    ---@type RenderOptions
    local headerOptions = {
      cells = {options.header},
      maxWidthPerRow = w,
    }
    self:layoutSingleColumn({options.header}, headerOptions, 0)
  end

  w = w + self.spacing
  -- Remove the last 4 pixels of padding.
  if w > 4 then
    w = w - 4 ---@type number
  end
  self.inner:SetSize(w, h)
  return w, h
end

-- Draw will draw the grid.
---@param options RenderOptions
---@return number width
---@return number height
function gridProto:Draw(options)
  return self:stage(options)
end

-- Clear will remove and release all columns from the grid,
-- but will not release cells.
function gridProto:Clear()
  wipe(self.cells)
  wipe(self.idToCell)
  wipe(self.cellToID)
end

-- Wipe completely removes all cells and columns from the grid
-- and releases all cells and columns.
function gridProto:Wipe()
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