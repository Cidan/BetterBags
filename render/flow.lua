local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Flow is the packing every BetterBags grid lays out with, as a pure function: boxes go left to
-- right in rows, a row wraps when the next box would pass the row limit, and rows split into
-- columns by height. It reads sizes and returns positions; it touches no frame. Measuring a
-- layout (how wide would these sections be at N items per row?) is therefore free of side
-- effects, and placing frames is a separate step (frames/grid.lua Arrange), the one place an
-- animation between two layouts would hook in (render-pipeline.md, the layout engine).
---@class Flow: AceModule
local flow = addon:NewModule('Flow')

-- The gap between boxes in a row and between rows.
flow.SPACING = 4

---@class (exact) FlowOptions
---@field rowLimit number How wide a row may be; checked without the gap before its last box.
---@field columns? number How many columns to split the rows into (1 when unset).
---@field spacing? number The gap between boxes and rows (flow.SPACING when unset).

---@class (exact) FlowPosition
---@field x number From the layout's left edge.
---@field y number From its top edge, 0 or below (negative), as SetPoint takes it.

---@class (exact) FlowResult
---@field positions FlowPosition[] One per box, in the boxes' order.
---@field columnOf number[] The column each box went into.
---@field width number The columns' widths added (an empty layout is one spacing wide).
---@field height number The tallest column.

-- columnsOf splits the boxes' rows into columns: the rows' heights are added up, each column
-- takes rows until it passes its share (plus 20, at least the tallest box), and when that leaves
-- more columns than asked for the share grows and it tries again, at most five times.
---@param sizes number[][]
---@param rowLimit number
---@param columns number
---@param spacing number
---@return number[][] columns The boxes' indexes in each column.
local function columnsOf(sizes, rowLimit, columns, spacing)
  local all = {}
  for i = 1, #sizes do
    all[i] = i
  end
  if columns <= 1 then
    return { all }
  end
  local rowWidth, totalHeight, tallest = 0, 0, 0
  for i, size in ipairs(sizes) do
    local w, h = size[1], size[2]
    if i ~= 1 then
      if rowWidth + w > rowLimit then
        totalHeight = totalHeight + h + spacing
        rowWidth = w
      else
        rowWidth = rowWidth + w + spacing
      end
    else
      totalHeight = h
      rowWidth = w
    end
    if h > tallest then
      tallest = math.ceil(h)
    end
  end

  local splitAt = math.ceil(math.max((totalHeight / columns) + 20, tallest))
  local attempt = 0
  while true do
    local currentHeight, current, overshoot = 0, 1, 0
    local result = {}
    rowWidth = 0
    attempt = attempt + 1
    for i, size in ipairs(sizes) do
      local w, h = size[1], size[2]
      if i ~= 1 then
        if rowWidth + w > rowLimit then
          if currentHeight + h > splitAt then
            current = current + 1
            currentHeight = h
          else
            currentHeight = currentHeight + h + spacing
          end
          rowWidth = w
        else
          rowWidth = rowWidth + w + spacing
        end
      else
        currentHeight = h
        rowWidth = w
      end
      result[current] = result[current] or {}
      table.insert(result[current], i)
      if current > columns then
        overshoot = overshoot + h
      end
    end
    if current > columns and attempt <= 5 then
      splitAt = splitAt + math.ceil(overshoot / (2 * columns))
    else
      return result
    end
  end
end

-- packColumn places one column's boxes in rows starting at x, returning the column's width (its
-- widest row) and height.
---@param indexes number[]
---@param sizes number[][]
---@param rowLimit number
---@param spacing number
---@param x number
---@param positions FlowPosition[]
---@return number width, number height
local function packColumn(indexes, sizes, rowLimit, spacing, x, positions)
  local width, height, rowWidth, rowHeight = 0, 0, 0, 0
  for n, i in ipairs(indexes) do
    local w, h = sizes[i][1], sizes[i][2]
    local px, py
    if n ~= 1 and rowWidth + w > rowLimit then
      height = height + rowHeight + spacing
      px, py = x, -height
      rowWidth, rowHeight = w, h
    elseif n ~= 1 then
      px, py = x + rowWidth + spacing, -height
      rowWidth = rowWidth + w + spacing
      rowHeight = math.max(rowHeight, h)
    else
      px, py = x, 0
      rowWidth, rowHeight = w, h
    end
    width = math.max(width, rowWidth)
    positions[i] = { x = px, y = py }
  end
  if #indexes > 0 then
    height = height + rowHeight
  end
  return width, height
end

-- Pack lays boxes of the given sizes ({ width, height } each, whole pixels) out in rows within
-- columns.
---@param sizes number[][]
---@param options FlowOptions
---@return FlowResult
function flow:Pack(sizes, options)
  local spacing = options.spacing or flow.SPACING
  local rowLimit = options.rowLimit
  local positions, columnOf = {}, {}
  local width, height, x = 0, 0, 0
  for c, indexes in ipairs(columnsOf(sizes, rowLimit, options.columns or 1, spacing)) do
    local w, h = packColumn(indexes, sizes, rowLimit, spacing, x, positions)
    for _, i in ipairs(indexes) do
      columnOf[i] = c
    end
    width = width + w
    height = math.max(height, h)
    x = x + w
  end
  -- The grid this replaced added the spacing and took 4 off; an empty layout stays 4 wide.
  width = width + spacing
  if width > 4 then
    width = width - 4
  end
  return { positions = positions, columnOf = columnOf, width = width, height = height }
end
