local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class PerfFormat: AceModule
local perfFormat = addon:GetModule('PerfFormat')

-- FlameGraph draws a profiler call tree as an icicle chart: the zoomed node spans the full
-- width on the top row and every child sits under its parent, as wide as its share of the
-- time. Bars are pooled textures on a single canvas frame; hovering and clicking are
-- resolved by hit-testing the cursor against the layout, so no frame is created per bar.
---@class FlameGraph: AceModule
local flameGraph = addon:NewModule('FlameGraph')

local ROW_HEIGHT = 18
local LABEL_MIN_WIDTH = 36
local MAX_BARS = 2000
local DIM_ALPHA = 0.25

local PALETTE = {
  { 0.86, 0.42, 0.20 },
  { 0.90, 0.58, 0.18 },
  { 0.80, 0.33, 0.26 },
  { 0.93, 0.70, 0.30 },
  { 0.75, 0.48, 0.22 },
  { 0.88, 0.50, 0.36 },
  { 0.70, 0.36, 0.18 },
  { 0.95, 0.62, 0.40 },
  { 0.82, 0.60, 0.25 },
  { 0.78, 0.40, 0.40 },
}

local KIND_COLORS = {
  all = { 0.40, 0.40, 0.45 },
  event = { 0.30, 0.52, 0.85 },
  msg = { 0.42, 0.62, 0.90 },
  bucket = { 0.30, 0.68, 0.72 },
  script = { 0.55, 0.45, 0.85 },
  other = { 0.50, 0.50, 0.55 },
}

local function hashString(s)
  local h = 0
  for i = 1, #s do
    h = (h * 31 + string.byte(s, i)) % 2147483647
  end
  return h
end

local function colorFor(name)
  local kind = string.match(name, '^%[([%w ]+)%]')
  if kind then
    return KIND_COLORS[kind] or KIND_COLORS.other
  end
  local module = string.match(name, '^([^.]+)') or name
  return PALETTE[hashString(module) % #PALETTE + 1]
end

---@class FlameGraphFrame
---@field frame Frame
---@field canvas Frame
---@field breadcrumb FontString
---@field resetButton Button
---@field empty FontString
---@field bars Texture[]
---@field rects PerfRect[]
---@field tree PerfTree|nil
---@field zoom PerfNode|nil
---@field metric "time"|"alloc"
---@field search string|nil
---@field depthOffset number
---@field maxDepth number
---@field hovered PerfRect|nil
local flameGraphProto = {}
flameGraphProto.ROW_HEIGHT = ROW_HEIGHT

---@param parent Frame
---@return FlameGraphFrame
function flameGraph:Create(parent)
  local fg = setmetatable({}, { __index = flameGraphProto }) --[[@as FlameGraphFrame]]
  fg.frame = CreateFrame('Frame', nil, parent)
  fg.bars = {}
  fg.rects = {}
  fg.metric = 'time'
  fg.depthOffset = 0
  fg.maxDepth = 0

  fg.resetButton = CreateFrame('Button', nil, fg.frame, 'UIPanelButtonTemplate') --[[@as Button]]
  fg.resetButton:SetSize(80, 18)
  fg.resetButton:SetPoint('TOPRIGHT', fg.frame, 'TOPRIGHT', 0, 0)
  fg.resetButton:SetText('Reset Zoom')
  fg.resetButton:SetScript('OnClick', function()
    fg:ResetZoom()
  end)

  fg.breadcrumb = fg.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  fg.breadcrumb:SetPoint('TOPLEFT', fg.frame, 'TOPLEFT', 2, -3)
  fg.breadcrumb:SetPoint('RIGHT', fg.resetButton, 'LEFT', -6, 0)
  fg.breadcrumb:SetJustifyH('LEFT')
  fg.breadcrumb:SetWordWrap(false)

  fg.canvas = CreateFrame('Frame', nil, fg.frame)
  fg.canvas:SetPoint('TOPLEFT', fg.frame, 'TOPLEFT', 0, -22)
  fg.canvas:SetPoint('BOTTOMRIGHT', fg.frame, 'BOTTOMRIGHT', 0, 0)
  fg.canvas:EnableMouse(true)
  fg.canvas:EnableMouseWheel(true)

  local background = fg.canvas:CreateTexture(nil, 'BACKGROUND')
  background:SetAllPoints(fg.canvas)
  background:SetColorTexture(0, 0, 0, 0.35)

  fg.empty = fg.canvas:CreateFontString(nil, 'OVERLAY', 'GameFontDisable')
  fg.empty:SetPoint('CENTER', fg.canvas, 'CENTER')
  fg.empty:SetText('No profile selected')

  fg.canvas:SetScript('OnSizeChanged', function()
    fg:Refresh()
  end)
  fg.canvas:SetScript('OnEnter', function()
    fg.canvas:SetScript('OnUpdate', function()
      fg:UpdateHover()
    end)
  end)
  fg.canvas:SetScript('OnLeave', function()
    fg.canvas:SetScript('OnUpdate', nil)
    fg.hovered = nil
    GameTooltip:Hide()
  end)
  fg.canvas:SetScript('OnMouseUp', function(_, button)
    if button == 'RightButton' then
      fg:ZoomOut()
      return
    end
    local rect = fg:RectUnderCursor()
    if rect then
      fg:Zoom(rect.node)
    end
  end)
  fg.canvas:SetScript('OnMouseWheel', function(_, delta)
    fg:Scroll(-delta)
  end)

  return fg
end

---@param tree PerfTree|nil
function flameGraphProto:SetTree(tree)
  self.tree = tree
  self.zoom = tree and tree.root or nil
  self.depthOffset = 0
  self:Refresh()
end

---@param metric "time"|"alloc"
function flameGraphProto:SetMetric(metric)
  self.metric = metric
  self:Refresh()
end

---@param text string|nil
function flameGraphProto:SetSearch(text)
  if text == nil or text == '' then
    self.search = nil
  else
    self.search = string.lower(text)
  end
  self:Refresh()
end

---@param node PerfNode
function flameGraphProto:Zoom(node)
  self.zoom = node
  self.depthOffset = 0
  self:Refresh()
end

function flameGraphProto:ZoomOut()
  if self.zoom and self.zoom.parent then
    self:Zoom(self.zoom.parent)
  end
end

function flameGraphProto:ResetZoom()
  if self.tree then
    self:Zoom(self.tree.root)
  end
end

---@param rows number
function flameGraphProto:Scroll(rows)
  local maxOffset = math.max(0, self.maxDepth - self:VisibleRows() + 1)
  local offset = self.depthOffset + rows
  if offset < 0 then offset = 0 end
  if offset > maxOffset then offset = maxOffset end
  if offset ~= self.depthOffset then
    self.depthOffset = offset
    self:Refresh()
  end
end

---@return number
function flameGraphProto:VisibleRows()
  return math.max(1, math.floor(self.canvas:GetHeight() / ROW_HEIGHT))
end

---@param node PerfNode
---@return boolean
function flameGraphProto:Matches(node)
  return self.search ~= nil and string.find(string.lower(node.name), self.search, 1, true) ~= nil
end

-- searchTotal sums the matching subtrees under the zoom, without counting a match that
-- sits inside another match twice.
---@return number
function flameGraphProto:SearchTotal()
  local field = self.metric == 'alloc' and 'totalAlloc' or 'total'
  local sum = 0
  local function visit(node)
    if self:Matches(node) then
      sum = sum + node[field]
      return
    end
    for _, c in ipairs(node.children) do
      visit(c)
    end
  end
  visit(self.zoom)
  return sum
end

function flameGraphProto:UpdateBreadcrumb()
  if not self.zoom then
    self.breadcrumb:SetText('')
    return
  end
  local path = perfFormat:PathOf(self.zoom)
  local text = #path > 0 and table.concat(path, ' > ') or 'All measured time'
  local field = self.metric == 'alloc' and 'totalAlloc' or 'total'
  local format = self.metric == 'alloc' and perfFormat.KB or perfFormat.Ms
  text = text .. '  |cffaaaaaa' .. format(perfFormat, self.zoom[field]) .. '|r'
  if self.search then
    local matched = self:SearchTotal()
    local share = self.zoom[field] > 0 and matched / self.zoom[field] * 100 or 0
    text = text .. string.format('  |cffff66ffmatches: %s (%.1f%%)|r', format(perfFormat, matched), share)
  end
  self.breadcrumb:SetText(text)
end

---@return Texture
function flameGraphProto:AcquireBar(index)
  local bar = self.bars[index]
  if not bar then
    bar = self.canvas:CreateTexture(nil, 'ARTWORK')
    bar.label = self.canvas:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    bar.label:SetJustifyH('LEFT')
    bar.label:SetWordWrap(false)
    self.bars[index] = bar
  end
  return bar
end

function flameGraphProto:Refresh()
  local width = self.canvas:GetWidth()
  self.rects = {}
  self.maxDepth = 0
  local count = 0
  if self.zoom and width > 0 then
    self.rects = perfFormat:Layout(self.zoom, { metric = self.metric, minFraction = 1 / width })
    local visibleRows = self:VisibleRows()
    for _, rect in ipairs(self.rects) do
      if rect.depth > self.maxDepth then self.maxDepth = rect.depth end
      local row = rect.depth - self.depthOffset
      if row >= 0 and row < visibleRows and count < MAX_BARS then
        count = count + 1
        local bar = self:AcquireBar(count)
        local x = rect.x * width
        local w = math.max(1, rect.w * width - 1)
        bar.rect = rect
        bar:ClearAllPoints()
        bar:SetPoint('TOPLEFT', self.canvas, 'TOPLEFT', x, -row * ROW_HEIGHT)
        bar:SetSize(w, ROW_HEIGHT - 1)
        local color = colorFor(rect.node.name)
        local alpha = 1
        if self.search and not self:Matches(rect.node) then
          alpha = DIM_ALPHA
        end
        bar:SetColorTexture(color[1], color[2], color[3], alpha)
        bar:Show()
        if w >= LABEL_MIN_WIDTH then
          bar.label:ClearAllPoints()
          bar.label:SetPoint('LEFT', bar, 'LEFT', 3, 0)
          bar.label:SetWidth(w - 6)
          bar.label:SetText(rect.node.name)
          bar.label:SetAlpha(alpha)
          bar.label:Show()
        else
          bar.label:Hide()
        end
      end
    end
  end
  for i = count + 1, #self.bars do
    self.bars[i]:Hide()
    self.bars[i].label:Hide()
    self.bars[i].rect = nil
  end
  if count > 0 then
    self.empty:Hide()
  else
    self.empty:Show()
  end
  self:UpdateBreadcrumb()
end

-- HitTest finds the bar at a point given in pixels from the canvas's top-left corner.
---@param x number
---@param y number
---@return PerfRect|nil
function flameGraphProto:HitTest(x, y)
  local width = self.canvas:GetWidth()
  if width <= 0 or y < 0 then return nil end
  local depth = math.floor(y / ROW_HEIGHT) + self.depthOffset
  for _, rect in ipairs(self.rects) do
    if rect.depth == depth then
      local left = rect.x * width
      if x >= left and x < left + rect.w * width then
        return rect
      end
    end
  end
  return nil
end

---@return PerfRect|nil
function flameGraphProto:RectUnderCursor()
  local cx, cy = GetCursorPosition()
  local scale = self.canvas:GetEffectiveScale()
  local left, top = self.canvas:GetLeft(), self.canvas:GetTop()
  if not left or not top then return nil end
  return self:HitTest(cx / scale - left, top - cy / scale)
end

function flameGraphProto:UpdateHover()
  local rect = self:RectUnderCursor()
  if rect == self.hovered then return end
  self.hovered = rect
  if rect then
    self:ShowTooltip(rect)
  else
    GameTooltip:Hide()
  end
end

---@param rect PerfRect
function flameGraphProto:ShowTooltip(rect)
  local node = rect.node
  local zoomTotal = self.zoom and self.zoom.total or 0
  local share = zoomTotal > 0 and node.total / zoomTotal * 100 or 0
  GameTooltip:SetOwner(self.canvas, 'ANCHOR_CURSOR')
  GameTooltip:SetText(node.name, 1, 1, 1)
  GameTooltip:AddDoubleLine('Total', string.format('%s (%.1f%%)', perfFormat:Ms(node.total), share))
  GameTooltip:AddDoubleLine('Self', perfFormat:Ms(node.self))
  GameTooltip:AddDoubleLine('Calls', tostring(node.calls))
  if node.max > 0 then
    GameTooltip:AddDoubleLine('Slowest call', perfFormat:Ms(node.max))
  end
  if self.tree and self.tree.hasAlloc then
    GameTooltip:AddDoubleLine('Allocated', perfFormat:KB(node.totalAlloc))
    GameTooltip:AddDoubleLine('Allocated here', perfFormat:KB(node.alloc))
  end
  GameTooltip:AddLine('Left-click to zoom in, right-click to zoom out.', 0.6, 0.6, 0.6)
  GameTooltip:Show()
end
