local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:NewModule('Grid')

---@class Flow: AceModule
local flow = addon:GetModule('Flow')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class Cell
---@field frame Frame

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
---@field footers Section[]
---@field maxCellWidth number The maximum number of cells per row.
---@field spacing number
---@field compactStyle GridCompactStyle
---@field private scrollable boolean
---@field package scrollBox WowScrollBox
---@field private sortVertical boolean
local gridProto = {}
addon:GetModule('Perf'):RegisterPrototype(gridProto, 'GridFrame')

---@class (exact) RenderOptions
---@field cells Cell[] The cells to render in this grid.
---@field maxWidthPerRow number The maximum width of a row before it wraps (render/flow.lua).
---@field columns? number The number of columns to render. If not set, columns is 1.
---@field sizeOf? fun(cell: Cell): number?, number? The size to lay a cell out at, when it is not its frame's yet (a section measured but not arranged); nil falls back to the frame's.

---@class (exact) GridMeasure: FlowResult
---@field cells Cell[] The cells, in the order of the positions.

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
  if not cell.isGap then
    assert(cell.frame, 'the added cell must have a frame')
  end
  for _, existingCell in ipairs(self.cells) do
    if existingCell == cell then
      error("Duplicate cell detected: Cell is already in the grid under a different ID")
    end
  end
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
  if not cell.isGap then
    assert(cell.frame, 'the added cell must have a frame')
  end
  if self.idToCell[id] ~= nil then return end
  for _, existingCell in ipairs(self.cells) do
    if existingCell == cell then
      error("Duplicate cell detected: Cell is already in the grid under a different ID")
    end
  end
  table.insert(self.cells, cell)
  self.idToCell[id] = cell
  self.cellToID[cell] = id
end

-- RemoveCell will removed a cell from this grid.
---@param id string|nil
---@return Cell?
function gridProto:RemoveCell(id)
  assert(id, 'id is required')
  for i, c in ipairs(self.cells) do
    if c == self.idToCell[id] then
      local cell = self.cells[i]
      table.remove(self.cells, i)
      self.cellToID[self.idToCell[id]] = nil
      self.idToCell[id] = nil
      return cell
    end
  end
  return nil
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
  if not self.scrollable then return end
  self.bar:Hide()
  self.bar:SetAlpha(0)
  self.bar:SetAttribute("nodeignore", true)
end

-- EnableMouseWheelScroll enables or disables mouse wheel scrolling on this grid's
-- scroll box. Disable this on non-scrollable grids (e.g. section content grids)
-- so mouse wheel events fall through to the outer scrollable bag container.
---@param enabled boolean
function gridProto:EnableMouseWheelScroll(enabled)
  if not self.scrollable then return end
  self.frame:EnableMouseWheel(enabled)
end

function gridProto:SortVertical()
  self.sortVertical = true
end

function gridProto:SortHorizontal()
  self.sortVertical = false
end

function gridProto:ShowScrollBar()
  if not self.scrollable then return end
  self.bar:SetAttribute("nodeignore", false)
  self.bar:SetAlpha(1)
  self.bar:Show()
end

-- DislocateCell will dislocate a cell from this grid, making it so
-- anything to the right of this cell is no longer setpoint relative
-- to the cell's frame, and instead is setpoint relative to the cell to the left
-- of it, leaving a gap where the cell once was. If the cell is the first cell in
-- the grid, the right cell will be setpoint relative to the inner frame of the grid.
-- If the cell is the first cell in a row and the row is not the first row, the right cell
-- will be setpoint relative to the bottomright of the cell above this cell.
function gridProto:DislocateCell(id)
  local cell = self.idToCell[id]
  if not cell or cell.isGap then return end
  -- First, loop all the cells and figure out what cell is to the left, and to the right
  -- of this cell.
  ---@type Cell?
  local leftCell = nil
  ---@type Cell?
  local rightCell = nil
  for i, c in ipairs(self.cells) do
    if c == cell then
      if i > 1 then
        leftCell = self.cells[i - 1]
      end
      if i < #self.cells then
        rightCell = self.cells[i + 1]
      end
      break
    end
  end

  ---@type string, ScriptRegion, string, number, number
  local _, relativeTo, relativePoint, _, offsetY = cell.frame:GetPoint(1)
  ---@type string, ScriptRegion, string, number, number
  local rightRelativePoint
  if rightCell then
    local _, _, rp = rightCell.frame:GetPoint(1)
    rightRelativePoint = rp
  end
  -- If there is a right cell and left cell, set it to be setpoint relative to the left cell, leaving a gap for the cell that was removed.
  if rightCell and leftCell then
    -- This cell is the first cell in a new row, offset the height of the right cell using the height offset of the current cell.
    if relativePoint == "BOTTOMLEFT" then
      rightCell.frame:SetPoint("TOPLEFT", relativeTo, "BOTTOMRIGHT", (self.spacing), offsetY)
    elseif rightRelativePoint ~= "BOTTOMLEFT" then
      rightCell.frame:SetPoint("TOPLEFT", leftCell.frame, "TOPRIGHT", (self.spacing * 2) + cell.frame:GetWidth(), 0)
    end
  elseif not leftCell and rightCell then
    -- This is the first cell in the grid.
    rightCell.frame:SetPoint("TOPLEFT", self.inner, "TOPLEFT", (self.spacing * 2) + cell.frame:GetWidth(), 0)
  end
  cell.frame:Hide()
  cell.frame:ClearAllPoints()
end

-- DislocateAllCellsWithID will dislocate all in the grid, hiding the cell
-- with the given id.
function gridProto:DislocateAllCellsWithID(id)
  local targetCell = self.idToCell[id]
  if not targetCell or targetCell.isGap then return end
  local parentTop, parentLeft = self.inner:GetTop(), self.inner:GetLeft()
  if parentTop == nil or parentLeft == nil then return end
  ---@type {x: number, y: number, cell: Cell}[]
  local positions = {}
  for _, cell in pairs(self.cells) do
    if not cell.isGap and cell.frame:IsShown() then
      -- Get the top left point of the cell.
      local x, y = cell.frame:GetLeft(), cell.frame:GetTop()
      if x and y then
        table.insert(positions, {x = parentLeft - x, y = parentTop - y, cell = cell})
      end
    end
  end
  for _, position in ipairs(positions) do
    position.cell.frame:ClearAllPoints()
    position.cell.frame:SetPoint("TOPLEFT", self.inner, "TOPLEFT", -position.x, -position.y)
  end
  targetCell.frame:Hide()
  targetCell.frame:ClearAllPoints()
end

-- cellSize returns a cell's size rounded to whole pixels, the size the grid lays it out at. A
-- frame reports its size back with float noise (scale conversions), and a size a hair over its
-- whole value at a row or column limit (two 131-wide sections against a 262-wide row) moved cells
-- to another row or column, flipping the layout from one redraw to the next. Cells are 37-pixel
-- buttons and sections built from them; a section as wide as its title's text moves by less than
-- half a pixel.
---@param cell Cell
---@return number width, number height
local function cellSize(cell)
  if cell.isGap then
    return cell.width or 37, cell.height or 37
  end
  return math.floor(cell.frame:GetWidth() + 0.5), math.floor(cell.frame:GetHeight() + 0.5)
end

-- Measure works out where every cell would go, from the cells' sizes alone, with the packing
-- every grid shares (render/flow.lua). It moves nothing: a view measures its sections for a
-- width before deciding which layout to arrange (frames/bagcanvas.lua).
---@param options RenderOptions
---@return GridMeasure
function gridProto:Measure(options)
  local sizes = {}
  local sizeOf = options.sizeOf
  for i, cell in ipairs(options.cells) do
    local w, h
    if sizeOf ~= nil then
      w, h = sizeOf(cell)
    end
    if w == nil then
      w, h = cellSize(cell)
    end
    sizes[i] = { w, h }
  end
  local measured = flow:Pack(sizes, { rowLimit = options.maxWidthPerRow, columns = options.columns, spacing = self.spacing })
  ---@cast measured GridMeasure
  measured.cells = options.cells
  return measured
end

-- Arrange puts the cells where a measure placed them and sizes the grid to it.
---@param measured GridMeasure
---@return number width, number height
function gridProto:Arrange(measured)
  for i, cell in ipairs(measured.cells) do
    if not cell.isGap then
      local position = measured.positions[i]
      self:PlaceCell(cell, position.x, position.y)
    end
  end
  self.inner:SetSize(measured.width, measured.height)
  self.contentWidth = measured.width
  self.contentHeight = measured.height
  return measured.width, measured.height
end

-- PlaceCell puts one cell at x, y from the grid's top left. Every cell of every grid is placed
-- here, through Motion: in a bag's render a cell whose place changed moves there.
---@param cell Cell
---@param x number
---@param y number
function gridProto:PlaceCell(cell, x, y)
  if cell.frame:GetParent() ~= self.inner then
    cell.frame:SetParent(self.inner)
  end
  motion:Place(cell.frame, self.inner, x, y, motion.ShownBy(cell))
  cell.frame:Show()
end

-- Draw measures the grid and arranges it.
---@param options RenderOptions
---@return number width
---@return number height
function gridProto:Draw(options)
  return self:Arrange(self:Measure(options))
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
  g.scrollBox = box
  ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view)
  scrollFrameCounter = scrollFrameCounter + 1
  return box
end

-- Create will create a new grid frame.
---@param parent Frame
---@param isScrollable? boolean
---@return Grid
function grid:Create(parent, isScrollable)
  local g = setmetatable({}, { __index = gridProto })
  ---@class Frame
  local c = CreateFrame("Frame", nil, parent)

  if isScrollable == false then
    g.frame = c
    g.inner = c
    g.scrollable = false
  else
    ---@class WowScrollBox
    local f = grid:CreateScrollFrame(g, parent, c)
    g.frame = f
    g.inner = c
    g.scrollable = true
  end

  g.cells = {}
  g.idToCell = {}
  g.cellToID = {}
  g.columns = {}
  g.cellToColumn = {}
  g.headers = {}
  g.footers = {}
  g.maxCellWidth = 5
  g.compactStyle = const.GRID_COMPACT_STYLE.NONE
  g.spacing = 4
  g:SortHorizontal()
  if g.scrollable then
    g.bar:Show()
  end
  -- Fixes a bug where the frame is not visble when anchored to the parent.
  g.frame:SetSize(1,1)
  return g
end

grid:Enable()
