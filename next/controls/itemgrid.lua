local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextScrollBar: AceModule
local nextScrollBar = addon:GetModule('NextScrollBar')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextItemGrid is a scrolling grid of item icons for the settings window (next-settings.md §5), drawn
-- from the theme (Controls.ItemGrid) in an input's fill and edge. Only the cells of the rows in view
-- exist: they are placed for the rows the box shows and reused as it scrolls, so thousands of items
-- cost what a screenful does. A cell shows an item's icon, its count above one, its quality on its
-- edge, and a faded look for an item that shows in another category; its tooltip is the item's (its
-- link, else its ID) with the entry's note and the grid's hint. An item dropped anywhere on the grid,
-- or clicked onto it, goes to onDrop; a right click goes to onRightClick; a modified click (a chat link,
-- the dressing room) to Blizzard's HandleModifiedItemClick.
---@class NextItemGrid: AceModule
---@field all NextItemGridFrame[]
local itemGrid = addon:NewModule('NextItemGrid')

---@class (exact) NextItemGridEntry
---@field id any Its key.
---@field itemID number
---@field icon number|string
---@field quality? number
---@field link? string
---@field count? number Shown above one.
---@field dim? boolean It shows in another category.
---@field note? string A line added to its tooltip.

---@class (exact) NextItemGridOptions
---@field onDrop? fun(ctx: Context) An item dropped on the grid; without it the grid takes none.
---@field onRightClick? fun(ctx: Context, entry: NextItemGridEntry, cell: Button)
---@field hint? string A line at the end of every tooltip.
---@field empty? string Shown while it has no entries.

---@class NextItemGridCell
---@field frame Button
---@field icon Texture
---@field hover Texture
---@field count FontString
---@field edge NextEdge
---@field entry? NextItemGridEntry

---@class NextItemGridFrame
---@field frame Frame
---@field fill Texture
---@field edge NextEdge
---@field box WowScrollBox
---@field content Frame
---@field bar NextScrollBarFrame
---@field empty FontString
---@field cells NextItemGridCell[] Made as needed; the first ones are those shown.
---@field entries NextItemGridEntry[]
---@field columns number
---@field width number
---@field height number
---@field opts NextItemGridOptions
local gridProto = {}
addon:GetModule('Perf'):RegisterPrototype(gridProto, 'NextItemGridFrame')

itemGrid.all = {}

---@param ctx? Context
function itemGrid:ApplyStyle(ctx)
  local _ = ctx
  for _, grid in ipairs(self.all) do
    grid:Style()
  end
end

---@param parent Frame
---@param opts NextItemGridOptions
---@return NextItemGridFrame
function itemGrid:Create(parent, opts)
  local frame = CreateFrame("Frame", nil, parent)
  frame:EnableMouse(true)
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(controls:Theme("ItemGrid").Size)
  box:Init(view)
  ---@type NextItemGridFrame
  local grid = setmetatable({
    frame = frame, fill = frame:CreateTexture(nil, "BACKGROUND"), edge = controls:CreateEdge(frame),
    box = box, content = content, cells = {}, entries = {}, columns = 1, width = 0, height = 0, opts = opts,
  }, { __index = gridProto })
  grid.fill:SetAllPoints(frame)
  grid.bar = nextScrollBar:Create(box)
  grid.bar:Bind(box)
  grid.empty = style:CreateText(frame, controls:Theme("ItemGrid").EmptyFont)
  grid.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
  box:RegisterCallback(BaseScrollBoxEvents.OnScroll, function() grid:ShowRows() end, grid)
  if opts.onDrop then
    local function drop(ctx, _, button)
      if button == nil or (button == "LeftButton" and CursorHasItem()) then
        opts.onDrop(ctx)
      end
    end
    addon.SetScript(frame, "OnReceiveDrag", drop)
    addon.SetScript(frame, "OnMouseUp", drop)
    addon.SetScript(box, "OnReceiveDrag", drop)
    addon.HookScript(box, "OnMouseUp", drop)
  end
  table.insert(self.all, grid)
  sonataNext:RegisterWidget(self)
  grid:Style()
  return grid
end

-- Style draws the grid and its cells from the theme, and lays them out again.
function gridProto:Style()
  local K, I = controls:Theme("ItemGrid"), controls:Theme("Input")
  controls:Paint(self.fill, I.Fill)
  controls:PaintEdge(self.edge, I.Edge, I.Edge.Idle)
  style:SetFont(self.empty, K.EmptyFont)
  for _, cell in ipairs(self.cells) do
    style:SetFont(cell.count, K.CountFont)
    controls:Paint(cell.hover, K.Hover)
  end
  self:Layout()
end

-- Place sizes the grid and lays it out.
---@param width number
---@param height number
function gridProto:Place(width, height)
  self.width, self.height = width, height
  self.frame:SetSize(width, height)
  self.box:ClearAllPoints()
  self.box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 1, -1)
  self.box:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -1, 1)
  self.box:SetSize(math.max(1, width - 2), math.max(1, height - 2))
  self:Layout()
end

-- SetEntries shows a list of items, in its order, and with none emptyText (else its own).
---@param entries NextItemGridEntry[]
---@param emptyText? string
function gridProto:SetEntries(entries, emptyText)
  self.entries = entries
  local empty = #entries == 0
  self.empty:SetText(emptyText or self.opts.empty or "")
  self.empty:SetShown(empty)
  self:Layout()
end

-- Layout fits as many columns as the width takes and makes the content as tall as every row.
function gridProto:Layout()
  local K = controls:Theme("ItemGrid")
  local step = K.Size + K.Gap
  self.columns = math.max(1, math.floor((self.width - 2 * K.Pad + K.Gap) / step))
  local rows = math.ceil(#self.entries / self.columns)
  local height = rows == 0 and 1 or 2 * K.Pad + rows * step - K.Gap
  self.content:SetHeight(height)
  self.box:FullUpdate(true)
  self:ShowRows()
end

-- cell returns the i-th cell, made the first time it is needed.
---@private
---@param i number
---@return NextItemGridCell
function gridProto:cell(i)
  local cell = self.cells[i]
  if cell ~= nil then
    return cell
  end
  local K = controls:Theme("ItemGrid")
  local frame = CreateFrame("Button", nil, self.content)
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  cell = {
    frame = frame,
    icon = frame:CreateTexture(nil, "ARTWORK"),
    hover = frame:CreateTexture(nil, "HIGHLIGHT"),
    count = style:CreateText(frame, K.CountFont),
    edge = controls:CreateEdge(frame, "OVERLAY"),
  }
  cell.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  cell.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  cell.hover:SetAllPoints(frame)
  controls:Paint(cell.hover, K.Hover)
  cell.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  cell.count:SetJustifyH("RIGHT")
  addon.SetScript(frame, "OnClick", function(ctx, _, button) self:Click(ctx, cell, button) end)
  addon.SetScript(frame, "OnReceiveDrag", function(ctx)
    if self.opts.onDrop then
      self.opts.onDrop(ctx)
    end
  end)
  addon.SetScript(frame, "OnEnter", function() self:ShowTooltip(cell) end)
  addon.SetScript(frame, "OnLeave", function()
    if GameTooltip:IsOwned(frame) then
      GameTooltip:Hide()
    end
  end)
  self.cells[i] = cell
  return cell
end

-- ShowRows places a cell for each entry of the rows the box shows, and hides the rest.
function gridProto:ShowRows()
  local K = controls:Theme("ItemGrid")
  local step = K.Size + K.Gap
  local n, columns = #self.entries, self.columns
  local offset = self.box:GetDerivedScrollOffset()
  local view = math.max(0, self.height - 2)
  local rows = math.ceil(n / columns)
  local first = math.max(0, math.floor((offset - K.Pad) / step))
  local last = math.min(rows - 1, math.floor((offset + view - K.Pad) / step))
  local used = 0
  for row = first, last do
    for column = 0, columns - 1 do
      local index = row * columns + column + 1
      if index > n then
        break
      end
      used = used + 1
      local cell = self:cell(used)
      cell.frame:ClearAllPoints()
      cell.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", K.Pad + column * step, -(K.Pad + row * step))
      cell.frame:SetSize(K.Size, K.Size)
      self:Draw(cell, self.entries[index])
      cell.frame:Show()
    end
  end
  for i = used + 1, #self.cells do
    self.cells[i].entry = nil
    self.cells[i].frame:Hide()
  end
end

-- Draw shows an entry in a cell: its icon, its count above one, its quality on the edge (the plain
-- edge for Common and Poor), faded when it shows in another category.
---@param cell NextItemGridCell
---@param entry NextItemGridEntry
function gridProto:Draw(cell, entry)
  local K = controls:Theme("ItemGrid")
  cell.entry = entry
  cell.icon:SetTexture(entry.icon)
  local count = entry.count or 0
  cell.count:SetText(count > 1 and tostring(count) or "")
  cell.count:SetShown(count > 1)
  local color = entry.quality ~= nil and entry.quality >= 2 and const.ITEM_QUALITY_COLOR[entry.quality] or nil
  if color then
    controls:PaintEdge(cell.edge, { Color = { color[1], color[2], color[3] }, Size = K.CommonEdge.Size }, 1)
  else
    controls:PaintEdge(cell.edge, K.CommonEdge)
  end
  cell.frame:SetAlpha(entry.dim and K.DimAlpha or 1)
end

-- ShowTooltip shows a cell's item: by its link, else by its ID, then the entry's note and the hint.
---@param cell NextItemGridCell
function gridProto:ShowTooltip(cell)
  local entry = cell.entry
  if entry == nil then
    return
  end
  GameTooltip:SetOwner(cell.frame, "ANCHOR_RIGHT")
  if entry.link then
    GameTooltip:SetHyperlink(entry.link)
  else
    GameTooltip:SetItemByID(entry.itemID)
  end
  if entry.note then
    GameTooltip:AddLine(entry.note, 1, 0.82, 0, true)
  end
  if self.opts.hint then
    GameTooltip:AddLine(self.opts.hint, 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

-- Click drops the item on the cursor, links a modified click, or passes a right click on.
---@param ctx Context
---@param cell NextItemGridCell
---@param button string
function gridProto:Click(ctx, cell, button)
  if button == "LeftButton" and CursorHasItem() then
    if self.opts.onDrop then
      self.opts.onDrop(ctx)
    end
    return
  end
  local entry = cell.entry
  if entry == nil then
    return
  end
  if button == "RightButton" then
    if self.opts.onRightClick then
      self.opts.onRightClick(ctx, entry, cell.frame)
    end
    return
  end
  if IsModifiedClick() then
    HandleModifiedItemClick(entry.link or select(2, C_Item.GetItemInfo(entry.itemID)))
  end
end
