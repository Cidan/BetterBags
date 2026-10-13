local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class PerfFormat: AceModule
local perfFormat = addon:GetModule('PerfFormat')

---@class FlameGraph: AceModule
local flameGraph = addon:GetModule('FlameGraph')

-- TraceChart draws a stretch of a call trace on a time axis: each call is a bar from its
-- start to its end, on the row of its call depth, so the order things ran in is visible.
-- Like the flame graph, bars are pooled textures on one canvas and the cursor is
-- hit-tested against the layout. The mouse wheel zooms around the cursor (Shift+wheel
-- scrolls rows), a click zooms to a call, and a right-click zooms out.
---@class TraceChart: AceModule
local traceChart = addon:NewModule('TraceChart')

local ROW_HEIGHT = 18
local LABEL_MIN_WIDTH = 36
local MAX_BARS = 2000
local MIN_WINDOW_MS = 0.001
local HIGHLIGHT = { 1, 1, 0.3 }

---@class TraceChartRect
---@field slice PerfTraceSlice
---@field row number
---@field x number Pixels from the canvas's left edge.
---@field w number

---@class TraceChartFrame
---@field frame Frame
---@field canvas Frame
---@field header FontString
---@field empty FontString
---@field bars Texture[]
---@field rects TraceChartRect[]
---@field trace PerfTrace|nil
---@field from number|nil Window start, in milliseconds from the start of the capture.
---@field to number|nil
---@field depthOffset number
---@field maxDepth number
---@field highlight number|nil Index of the call drawn highlighted.
---@field hovered TraceChartRect|nil
---@field onWindowChanged fun(from: number, to: number)|nil
local chartProto = {}
chartProto.ROW_HEIGHT = ROW_HEIGHT

---@param parent Frame
---@return TraceChartFrame
function traceChart:Create(parent)
  local chart = setmetatable({}, { __index = chartProto }) --[[@as TraceChartFrame]]
  chart.frame = CreateFrame('Frame', nil, parent)
  chart.bars = {}
  chart.rects = {}
  chart.depthOffset = 0
  chart.maxDepth = 0

  chart.header = chart.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  chart.header:SetPoint('TOPLEFT', chart.frame, 'TOPLEFT', 2, -3)
  chart.header:SetPoint('TOPRIGHT', chart.frame, 'TOPRIGHT', -2, -3)
  chart.header:SetJustifyH('LEFT')
  chart.header:SetWordWrap(false)

  chart.canvas = CreateFrame('Frame', nil, chart.frame)
  chart.canvas:SetPoint('TOPLEFT', chart.frame, 'TOPLEFT', 0, -20)
  chart.canvas:SetPoint('BOTTOMRIGHT', chart.frame, 'BOTTOMRIGHT', 0, 0)
  chart.canvas:EnableMouse(true)
  chart.canvas:EnableMouseWheel(true)

  local background = chart.canvas:CreateTexture(nil, 'BACKGROUND')
  background:SetAllPoints(chart.canvas)
  background:SetColorTexture(0, 0, 0, 0.35)

  chart.empty = chart.canvas:CreateFontString(nil, 'OVERLAY', 'GameFontDisable')
  chart.empty:SetPoint('CENTER', chart.canvas, 'CENTER')
  chart.empty:SetText('No call trace')

  chart.canvas:SetScript('OnSizeChanged', function()
    chart:Refresh()
  end)
  chart.canvas:SetScript('OnEnter', function()
    chart.canvas:SetScript('OnUpdate', function()
      chart:UpdateHover()
    end)
  end)
  chart.canvas:SetScript('OnLeave', function()
    chart.canvas:SetScript('OnUpdate', nil)
    chart.hovered = nil
    GameTooltip:Hide()
  end)
  chart.canvas:SetScript('OnMouseUp', function(_, button)
    if button == 'RightButton' then
      chart:ZoomOut()
      return
    end
    local rect = chart:RectUnderCursor()
    if rect then
      chart:ZoomToCall(rect.slice.call)
    end
  end)
  chart.canvas:SetScript('OnMouseWheel', function(_, delta)
    if IsShiftKeyDown() then
      chart:Scroll(-delta)
      return
    end
    local fraction = chart:CursorFraction() or 0.5
    chart:ZoomAt(fraction, delta > 0 and 0.5 or 2)
  end)

  return chart
end

-- CaptureEnd is the length of the capture the trace belongs to, in milliseconds.
---@return number
function chartProto:CaptureEnd()
  local stats = self.trace and self.trace.session.stats
  return stats and stats.durationMs or 0
end

---@param trace PerfTrace|nil
function chartProto:SetTrace(trace)
  self.trace = trace
  self.from, self.to = nil, nil
  self.highlight = nil
  self.depthOffset = 0
  self:Refresh()
end

-- SetWindow shows the stretch from `from` to `to`, kept inside the capture.
---@param from number
---@param to number
function chartProto:SetWindow(from, to)
  if not self.trace then return end
  local finish = self:CaptureEnd()
  if from < 0 then from = 0 end
  if finish > 0 and to > finish then to = finish end
  if to - from < MIN_WINDOW_MS then to = from + MIN_WINDOW_MS end
  self.from, self.to = from, to
  self:Refresh()
  if self.onWindowChanged then
    self.onWindowChanged(from, to)
  end
end

-- ZoomAt scales the window by factor (below 1 zooms in), keeping the moment at `fraction`
-- of the width where it is.
---@param fraction number
---@param factor number
function chartProto:ZoomAt(fraction, factor)
  if not self.from then return end
  local width = self.to - self.from
  local pivot = self.from + fraction * width
  local newWidth = width * factor
  self:SetWindow(pivot - fraction * newWidth, pivot + (1 - fraction) * newWidth)
end

function chartProto:ZoomOut()
  self:ZoomAt(0.5, 2)
end

---@param call PerfTraceCall
function chartProto:ZoomToCall(call)
  self.highlight = call.index
  self:SetWindow(call.start, math.max(call.finish, call.start + MIN_WINDOW_MS))
end

---@param rows number
function chartProto:Scroll(rows)
  local maxOffset = math.max(0, self.maxDepth - self:VisibleRows())
  local offset = self.depthOffset + rows
  if offset < 0 then offset = 0 end
  if offset > maxOffset then offset = maxOffset end
  if offset ~= self.depthOffset then
    self.depthOffset = offset
    self:Refresh()
  end
end

---@return number
function chartProto:VisibleRows()
  return math.max(1, math.floor(self.canvas:GetHeight() / ROW_HEIGHT))
end

---@return Texture
function chartProto:AcquireBar(index)
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

function chartProto:UpdateHeader()
  if not self.trace then
    self.header:SetText('')
    return
  end
  if not self.from then
    self.header:SetText('Pick a frame above')
    return
  end
  local firstFrame, lastFrame = self.trace:FrameOf(self.from), self.trace:FrameOf(self.to)
  local frames = firstFrame == lastFrame and string.format('frame %d', firstFrame)
    or string.format('frames %d-%d', firstFrame, lastFrame)
  self.header:SetText(string.format('%s - %s  (%s, %s)  |cffaaaaaawheel: zoom, Shift+wheel: scroll, click: zoom to call, right-click: zoom out|r',
    perfFormat:Ms(self.from), perfFormat:Ms(self.to), perfFormat:Ms(self.to - self.from), frames))
end

function chartProto:Refresh()
  local width = self.canvas:GetWidth()
  self.rects = {}
  self.maxDepth = 0
  local count = 0
  if self.trace and self.from and width > 0 then
    local span = self.to - self.from
    local slices = self.trace:Slices(self.from, self.to, span / width)
    local visibleRows = self:VisibleRows()
    for _, slice in ipairs(slices) do
      if slice.depth > self.maxDepth then self.maxDepth = slice.depth end
      local left = math.max(slice.start, self.from)
      local right = math.min(slice.finish, self.to)
      local x = (left - self.from) / span * width
      local w = (right - left) / span * width
      local row = slice.depth - 1 - self.depthOffset
      local rect = { slice = slice, row = row, x = x, w = w }
      self.rects[#self.rects + 1] = rect
      if row >= 0 and row < visibleRows and count < MAX_BARS then
        count = count + 1
        local bar = self:AcquireBar(count)
        local barWidth = math.max(1, w - 1)
        bar.rect = rect
        bar:ClearAllPoints()
        bar:SetPoint('TOPLEFT', self.canvas, 'TOPLEFT', x, -row * ROW_HEIGHT)
        bar:SetSize(barWidth, ROW_HEIGHT - 1)
        local color = slice.call.index == self.highlight and HIGHLIGHT or flameGraph:ColorFor(slice.name)
        local alpha = (slice.call.aborted or slice.call.unfinished) and 0.6 or 1
        bar:SetColorTexture(color[1], color[2], color[3], alpha)
        bar:Show()
        if barWidth >= LABEL_MIN_WIDTH then
          bar.label:ClearAllPoints()
          bar.label:SetPoint('LEFT', bar, 'LEFT', 3, 0)
          bar.label:SetWidth(barWidth - 6)
          bar.label:SetText(slice.name)
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
    self.empty:SetText(self.trace and 'Nothing ran in this stretch' or 'No call trace')
    self.empty:Show()
  end
  self:UpdateHeader()
end

-- HitTest finds the call at a point given in pixels from the canvas's top-left corner.
---@param x number
---@param y number
---@return TraceChartRect|nil
function chartProto:HitTest(x, y)
  if y < 0 then return nil end
  local row = math.floor(y / ROW_HEIGHT)
  local found
  for _, rect in ipairs(self.rects) do
    if rect.row == row and x >= rect.x and x < rect.x + math.max(rect.w, 1) then
      found = rect
    end
  end
  return found
end

---@return number|nil
function chartProto:CursorFraction()
  local cx = GetCursorPosition()
  local scale = self.canvas:GetEffectiveScale()
  local left, width = self.canvas:GetLeft(), self.canvas:GetWidth()
  if not left or not width or width <= 0 then return nil end
  local fraction = (cx / scale - left) / width
  if fraction < 0 then fraction = 0 end
  if fraction > 1 then fraction = 1 end
  return fraction
end

---@return TraceChartRect|nil
function chartProto:RectUnderCursor()
  local cx, cy = GetCursorPosition()
  local scale = self.canvas:GetEffectiveScale()
  local left, top = self.canvas:GetLeft(), self.canvas:GetTop()
  if not left or not top then return nil end
  return self:HitTest(cx / scale - left, top - cy / scale)
end

function chartProto:UpdateHover()
  local rect = self:RectUnderCursor()
  if rect == self.hovered then return end
  self.hovered = rect
  if rect then
    self:ShowTooltip(rect)
  else
    GameTooltip:Hide()
  end
end

---@param rect TraceChartRect
function chartProto:ShowTooltip(rect)
  local call = rect.slice.call
  local trace = self.trace
  GameTooltip:SetOwner(self.canvas, 'ANCHOR_CURSOR')
  GameTooltip:SetText(call.name, 1, 1, 1)
  GameTooltip:AddDoubleLine('Call', '#' .. perfFormat:Count(call.index))
  GameTooltip:AddDoubleLine('Started', perfFormat:Ms(call.start))
  GameTooltip:AddDoubleLine('Frame', tostring(trace:FrameOf(call.start)))
  GameTooltip:AddDoubleLine('Duration', perfFormat:Ms(call.incl))
  if call.segments then
    GameTooltip:AddDoubleLine('Including pauses', perfFormat:Ms(call.wall))
  end
  if call.aborted then
    GameTooltip:AddLine('Cut short by an error.', 1, 0.4, 0.3)
  elseif call.unfinished then
    GameTooltip:AddLine(call.paused and 'Paused when the capture stopped.' or 'Still running when the capture stopped.', 1, 0.6, 0.2)
  end
  local args, returns = trace:Text(call.args), trace:Text(call.returns)
  if args then
    GameTooltip:AddLine('Arguments: ' .. args, 0.8, 0.8, 0.8, true)
  end
  if returns then
    GameTooltip:AddLine('Returned: ' .. (returns == '' and '(nothing)' or returns), 0.8, 0.8, 0.8, true)
  end
  GameTooltip:AddLine('Click to zoom to this call, right-click to zoom out.', 0.6, 0.6, 0.6)
  GameTooltip:Show()
end
