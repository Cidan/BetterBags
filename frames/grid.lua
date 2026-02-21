local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:NewModule('Grid')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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

---@class (exact) RenderOptions
---@field cells Cell[] The cells to render in this grid.
---@field maxWidthPerRow number The maximum width of a row before it wraps.
---@field columns? number The number of columns to render. If not set, columns is 1.
---@field header? Cell A Cell to render above all other items, ignoring columns.
---@field footer? Cell A Cell to render below all other items, ignoring columns.
---@field mask? Cell[] A list of cells to hide and not render at all.
---@field dynamic? boolean If true, the grid will calculate the number of columns such that the height of the grid does not exceed the percentage of the screen height.
---@field dynamicHeight? number The percentage of the screen height to use when calculating the number of columns.

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
  self.bar:Hide()
  self.bar:SetAlpha(0)
  self.bar:SetAttribute("nodeignore", true)
end

-- EnableMouseWheelScroll enables or disables mouse wheel scrolling on this grid's
-- scroll box. Disable this on non-scrollable grids (e.g. section content grids)
-- so mouse wheel events fall through to the outer scrollable bag container.
---@param enabled boolean
function gridProto:EnableMouseWheelScroll(enabled)
  self.frame:EnableMouseWheel(enabled)
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
  if not cell then return end
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
  if not targetCell then return end
  local parentTop, parentLeft = self.inner:GetTop(), self.inner:GetLeft()
  if parentTop == nil or parentLeft == nil then return end
  ---@type {x: number, y: number, cell: Cell}[]
  local positions = {}
  for _, cell in pairs(self.cells) do
    if cell.frame:IsShown() then
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

-- Sort will sort the cells in this grid using the given function.
---@param fn fun(a: `T`, b: `T`):boolean
function gridProto:Sort(fn)
  -- Guard against invalid sort functions from external addons modifying saved variables.
  -- Use a no-op comparison function as a safe default to prevent crashes.
  if type(fn) ~= "function" then
    fn = function() return false end
  end
  table.sort(self.cells, fn)
end

---@return number, number
function gridProto:stageSimple()
  return 1,1
end

---@param options RenderOptions
---@return Cell[]
function gridProto:calculateCellMask(options)
  if not options.mask then return options.cells end

  ---@type Cell[]
  local result = {}
  for _, cell in ipairs(options.cells) do
    local found = false
    for _, maskCell in ipairs(options.mask) do
      if cell == maskCell then
        found = true
        break
      end
    end
    if not found then
      table.insert(result, cell)
    end
  end
  return result
end

-- calculateColumns takes a list of cells and a column count. It will then
-- return a list of list of cells, where each list of cells is a column.
-- The columns are divided evenly by the height of all the cell frames
-- in a given column.
---@param options RenderOptions
---@return Cell[][]
function gridProto:calculateColumns(options)
  local maskedCells = self:calculateCellMask(options)
  if not options.columns or options.columns == 1 then
    return {[1] = maskedCells}
  end
  local rowWidth = 0
  local totalHeight = 0
  local maxCellHeight = 0
  ---@type Cell[][]
  for i, cell in ipairs(maskedCells) do
    if i ~= 1 then
      if rowWidth + cell.frame:GetWidth() > options.maxWidthPerRow then
        totalHeight = totalHeight + cell.frame:GetHeight() + self.spacing
        rowWidth = cell.frame:GetWidth()
      else
        rowWidth = rowWidth + cell.frame:GetWidth() + self.spacing
      end
    else
      totalHeight = cell.frame:GetHeight()
      rowWidth = cell.frame:GetWidth()
    end

    if cell.frame:GetHeight() > maxCellHeight then
      maxCellHeight = math.ceil(cell.frame:GetHeight())
    end
  end

  -- Consider the largest cell for calculating splitAt. Don't split before reaching that height, to avoid unnecessary columns
  local splitAt = math.ceil(math.max((totalHeight / options.columns) + 20, maxCellHeight))
  local algorithmAttempt = 0

  while true do
    local currentHeight = 0
    local currentColumn = 1
    rowWidth = 0
    local overshoot = 0
    local columns = {}
    algorithmAttempt = algorithmAttempt + 1

    for i, cell in ipairs(maskedCells) do
      if i ~= 1 then
        if rowWidth + cell.frame:GetWidth() > options.maxWidthPerRow then
          if currentHeight + cell.frame:GetHeight() > splitAt then
            currentColumn = currentColumn + 1
            currentHeight = cell.frame:GetHeight()
          else
            currentHeight = currentHeight + cell.frame:GetHeight() + self.spacing
          end
          rowWidth = cell.frame:GetWidth()
        else
          rowWidth = rowWidth + cell.frame:GetWidth() + self.spacing
        end
      else
        currentHeight = cell.frame:GetHeight()
        rowWidth = cell.frame:GetWidth()
      end

      if not columns[currentColumn] then
        columns[currentColumn] = {}
      end
      table.insert(columns[currentColumn], cell)

      if currentColumn > options.columns then
        overshoot = overshoot + cell.frame:GetHeight()
      end
    end

    if currentColumn > options.columns then
      if algorithmAttempt > 5 then
        -- The algorithm should be pretty fast and we should get to a valid distribution in a 1-3 attempts, but let's cut it off after 5 attempts to be safe
        debug:Log("calculateColumns", "Couldn't fit cells in", options.columns, "columns after 5 attempts. Using current solution.")
        return columns
      end

      -- Need to increase splitAt to reduce number of columns, try evenly increasing by the overshot height/2 and try again
      splitAt = splitAt + math.ceil(overshoot / (2 * options.columns))
    else
      return columns
    end
  end
end

---@param cells Cell[]
---@param options RenderOptions
---@param currentOffset number
---@param topOffset number
---@return number, number
function gridProto:layoutSingleColumn(cells, options, currentOffset, topOffset)
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
        h = h + cell.frame:GetHeight() + self.spacing
        rowWidth = cell.frame:GetWidth()
        w = math.max(w, rowWidth)
        relativeToPoint = "BOTTOMLEFT"
        rowStart = cell
        spacingY = -self.spacing
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
      spacingY = topOffset
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

  -- Explicitly hide masked cells so they don't remain visible at old positions
  if options.mask then
    for _, maskCell in ipairs(options.mask) do
      if maskCell.frame then
        maskCell.frame:Hide()
      end
    end
  end

  local w = 0
  local h = 0
  local columns = self:calculateColumns(options)
  local currentOffset = 0
  local topOffset = 0
  local headerWidth = 0
  local headerHeight = 0
  local footerWidth = 0
  local footerHeight = 0
  local bottomColumnPosition = 0
  if options.header then
    ---@type RenderOptions
    local headerOptions = {
      cells = {options.header},
      maxWidthPerRow = options.maxWidthPerRow * 2,
    }
    headerWidth, headerHeight = self:layoutSingleColumn({options.header}, headerOptions, 0, 0)
    topOffset = -headerHeight
  end

  for _, column in ipairs(columns) do
    local columnWidth, columnHeight = self:layoutSingleColumn(column, options, currentOffset, topOffset)
    w = w + columnWidth
    h = math.max(h, columnHeight)
    currentOffset = currentOffset + columnWidth
    bottomColumnPosition = math.max(bottomColumnPosition, columnHeight)
  end

  if options.footer then
    ---@type RenderOptions
    local footerOptions = {
      cells = {options.footer},
      maxWidthPerRow = options.maxWidthPerRow * 2,
    }
    footerWidth, footerHeight = self:layoutSingleColumn({options.footer}, footerOptions, 0, -bottomColumnPosition + topOffset)
    --topOffset = -headerHeight
  end

  h = h + headerHeight + footerHeight

  if w == 0  or w < headerWidth then
    w = headerWidth
  end

  if w == 0  or w < footerWidth then
    w = footerWidth
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
  g.footers = {}
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
