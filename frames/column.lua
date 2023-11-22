local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class ColumnFrame: AceModule
local columnFrame = addon:NewModule('ColumnFrame')

---@class Column
---@field frame Frame
---@field cells Cell[]|Item[]|Section[]
---@field minimumWidth number
local columnProto = {}

-- AddCell adds a cell to this column at the given position, or
-- at the end of the column if no position is given.
---@param cell Cell|Item|Section
---@param position? number
function columnProto:AddCell(cell, position)
  cell.frame:ClearAllPoints()
  cell.frame:SetParent(self.frame)
  if position and position < 1 then
    position = 1
  else
    position = position or #self.cells + 1
  end
  -- cell.position = position not sure if needed yet
  table.insert(self.cells, position, cell)
  cell.frame:Show()
end

-- GetCellPosition returns the cell's position as an integer in this column.
function columnProto:GetCellPosition(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then return i end
  end
end

-- RemoveCell removes a cell from this column.
function columnProto:RemoveCell(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then
      cell.frame:ClearAllPoints()
      table.remove(self.cells, i)
      return
    end
  end
end

--TODO(lobato): Figure out if we need to do cell compaction.
-- Draw will full redraw this column and snap all cells into the correct
-- position.
function columnProto:Draw()
  local w = self.minimumWidth
  local h = 0
  local previousRow = 0
  local cellOffset = 1
  for cellPos, cell in ipairs(self.cells) do
    -- cell.position = cellPos unsure if need this
    w = math.max(w, cell.frame:GetWidth()+4)
    if cellPos == 1 then
      cell.frame:SetPoint("TOPLEFT", self.frame)
      -- previousRow = cell.frame.count unsure what this was
      h = h + cell.frame:GetHeight()
    else
      cell.frame:SetPoint("TOPLEFT", self.cells[cellPos - 1].frame, "BOTTOMLEFT", 0, -4)
      h = h + cell.frame:GetHeight() + 4
    end
  end
  self.frame:SetSize(w, h)
  self.frame:Show()
  return w, h
end

------
--- Column Frame
------
function columnFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

---@return Column
function columnFrame:_DoCreate()
  local column = setmetatable({}, {__index = columnProto})
  ---@class Frame: BackdropTemplate
  local f = CreateFrame('Frame', nil, nil, "BackdropTemplate")
  column.frame = f
  column.minimumWidth = 0
  column.cells = {}
  column.frame:Show()
  debug:DrawDebugBorder(column.frame, 1, 1, 1)
  return column
end

---@param c Column
function columnFrame:_DoReset(c)
  c.frame:Hide()
  c.frame:ClearAllPoints()
  c.frame:SetParent(nil)
  c.minimumWidth = 0
  for _, cell in ipairs(c.cells) do
    cell.frame:ClearAllPoints()
    cell.frame:SetParent(nil)
  end
  wipe(c.cells)
end

---@return Column
function columnFrame:Create()
  return self._pool:Acquire()
end

---@param c Column
function columnFrame:Release(c)
  self._pool:Release(c)
end