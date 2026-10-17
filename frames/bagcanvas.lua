local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

-- BagCanvas is the drawable inside a bag's scroll box: three stacked containers for the Recent
-- Items header, the active tab view and the Free Space footer (the bag binds data to their
-- sections before rendering). It plans a layout, arranges it, and centers it in its width, so the
-- longest row has the same padding on both sides.
--
-- A layout is a function of items per row and columns alone (render-pipeline.md, the layout
-- engine): every section measured with that many items in a row, the sections packed in rows and
-- columns. A bag sized to its content takes the bag's items per row. A bag given a width (a window
-- the player sized) takes the densest layout that fits it, trying every items per row from the one
-- past which nothing changes down to one: the same candidates for any width, so the layout chosen
-- at a width is also the one chosen at that layout's own width (FitWidth), which is what a window
-- snaps to (window.md 3b).
--
-- With Animate Item Movement on, each render while the canvas is shown is a Motion pass
-- (render/motion.lua): every section, item and container whose place changed travels there, the
-- rest stay put. Otherwise, and while hidden, it places everything at once; hiding ends its moves
-- and forgets them, so a bag never opens mid-move.
---@class BagCanvas: AceModule
local bagCanvas = addon:NewModule('BagCanvas')

-- A row of sections may be 41 * N + 16 wide at N items per row (views/views.lua), and a row lets
-- its sections sit this far apart (render/flow.lua).
local CELL_STRIDE = 41
local ROW_EXTRA = 16
local SPACING = 4

---@class (exact) CanvasPlan
---@field itemsPerRow number
---@field columns number
---@field global {header?: SectionMeasure, footer?: SectionMeasure}
---@field view? ViewMeasure
---@field width number The widest of the header, view and footer.
---@field height number The three added.

---@class (exact) BagCanvasDrawable: Drawable
---@field bag Bag
---@field frame Frame
---@field headerContainer Frame
---@field tabContainer Frame
---@field footerContainer Frame
---@field plan? CanvasPlan The plan of the last render.
---@field plannedFor? number The width the last plan had to fit; nil when sized to its content.
---@field measured? {caps: table<Section, number>, byItemsPerRow: table<Section, table<number, SectionMeasure>>} Section measures kept across renders until the bag binds new data (ForgetMeasures).
local canvasProto = drawable:Extend({}, 'BagCanvasFrame')

---@param bag Bag
---@param parent Frame
---@return BagCanvasDrawable
function bagCanvas:Create(bag, parent)
  ---@type BagCanvasDrawable
  local canvas = drawable:Create(canvasProto)
  canvas.bag = bag
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(1, 1)
  canvas.frame = frame

  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  header:SetHeight(1)

  -- The view and the footer hang from the header's top at the offsets the plan gives them (Render),
  -- not from the bottom of the container above: an empty container is kept 1 pixel tall, which
  -- would push everything below it down a pixel past the height the canvas reports.
  local tab = CreateFrame("Frame", nil, frame)
  tab:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
  tab:SetSize(1, 1)

  local footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
  footer:SetSize(1, 1)

  canvas.headerContainer = header
  canvas.tabContainer = tab
  canvas.footerContainer = footer
  addon.SetScript(frame, "OnHide", function()
    motion:Forget(canvas)
  end)
  return canvas
end

-- Measure works out the canvas's layout at itemsPerRow and columns, moving nothing: the global
-- sections and the view, each measured with that many items in a row.
---@param itemsPerRow number
---@param columns number
---@param measureSection? SectionMeasurer
---@return CanvasPlan
function canvasProto:Measure(itemsPerRow, columns, measureSection)
  local bag = self.bag
  local global = bag:MeasureGlobalSections(itemsPerRow, columns, measureSection)
  local view = bag.currentView and bag.currentView:Measure(itemsPerRow, columns, measureSection) or nil
  local header, footer = global.header, global.footer
  local headerW, headerH = header and header.width or 0, header and header.height or 0
  local footerW, footerH = footer and footer.width or 0, footer and footer.height or 0
  local viewW, viewH = view and view.width or 0, view and view.height or 0
  return {
    itemsPerRow = itemsPerRow,
    columns = columns,
    global = global,
    view = view,
    width = math.max(headerW, viewW, footerW),
    height = headerH + viewH + footerH,
  }
end

---@class (exact) CanvasBounds
---@field cap number The items per row past which no layout changes.
---@field sectionsCap number The items per row past which no section changes.
---@field widest number The view's widest section at its widest.
---@field oneRow number The view's sections side by side in one row, at their widest.

-- boundsOf works out what limits the layouts worth measuring: past sectionsCap every section's
-- cells fit one row (a section spanning the columns has columns times the items per row); past cap
-- the view's sections also fit one row of sections, so nothing changes any more.
---@param columns number
---@param measureSection SectionMeasurer
---@return CanvasBounds
function canvasProto:boundsOf(columns, measureSection)
  local bag = self.bag
  local sectionsCap, widest, total, count = 1, 0, 0, 0
  if bag.currentView ~= nil then
    for _, section in pairs(bag.currentView.sections) do
      local sectionCap = section:GetItemsPerRowCap()
      local width = measureSection(section, sectionCap).width
      sectionsCap = math.max(sectionsCap, sectionCap)
      widest = math.max(widest, width)
      total = total + width
      count = count + 1
    end
  end
  for _, global in ipairs(bag:GetGlobalLayoutSections()) do
    local perRow = global.spansColumns and columns or 1
    sectionsCap = math.max(sectionsCap, math.ceil(global.section:GetItemsPerRowCap() / perRow))
  end
  local oneRow = count > 0 and total + SPACING * (count - 1) or 0
  local cap = sectionsCap
  if count > 0 then
    cap = math.max(cap, math.ceil((oneRow - ROW_EXTRA) / CELL_STRIDE))
  end
  return { cap = cap, sectionsCap = sectionsCap, widest = widest, oneRow = oneRow }
end

-- Plan returns the layout to arrange: the bag's items per row without a width; with one, the
-- densest layout no wider than it (one item per row when none fits), out of every items per row
-- from the cap down. Each section is measured once per items per row it needs, capped where it
-- stops changing.
--
-- A row of sections only wraps when the next one would pass the row limit, so the view's first row
-- (and so the view, whose first column holds it) is wider than the limit less the widest section,
-- unless every section fits that row. Items per row whose limit less the widest section reaches the
-- width therefore cannot fit and are not measured. Such an items per row is past every view
-- section's cap (the widest section is at least 41 * its cap + 8 wide), so every section is at its
-- widest there and "every section fits one row" means the one-row width, which is checked to pass
-- the width. The answer is the same as measuring every candidate, at a fraction of the cost: a bank
-- of 591 items in 60 sections had about 600 candidates, and planning took 17-25 ms; with the skip
-- 1.5-3.4 ms, measured offline.
---@param width? number
---@return CanvasPlan
function canvasProto:Plan(width)
  local kind = self.bag.kind
  local sizeInfo = database:GetBagSizeInfo(kind, database:GetBagView(kind))
  local columns = sizeInfo.columnCount
  if width == nil then
    return self:Measure(sizeInfo.itemsPerRow, columns)
  end
  local measured = self.measured
  if measured == nil then
    measured = { caps = {}, byItemsPerRow = {} }
    self.measured = measured
  end
  local caps, measures = measured.caps, measured.byItemsPerRow
  ---@type SectionMeasurer
  local function measureSection(section, itemsPerRow)
    local cap = caps[section]
    if cap == nil then
      cap = section:GetItemsPerRowCap()
      caps[section] = cap
    end
    local key = math.min(itemsPerRow, cap)
    local byKey = measures[section]
    if byKey == nil then
      byKey = {}
      measures[section] = byKey
    end
    local sectionMeasure = byKey[key]
    if sectionMeasure == nil then
      sectionMeasure = section:Measure(kind, key)
      byKey[key] = sectionMeasure
    end
    return sectionMeasure
  end
  local bounds = self:boundsOf(columns, measureSection)
  local start = bounds.cap
  if bounds.oneRow > width then
    -- The first items per row whose row limit less the widest section reaches the width.
    local tooWide = math.ceil((width + bounds.widest - ROW_EXTRA) / CELL_STRIDE)
    start = math.min(start, tooWide - 1)
  end
  local narrowest
  for itemsPerRow = start, 1, -1 do
    local plan = self:Measure(itemsPerRow, columns, measureSection)
    if plan.width <= width then
      return plan
    end
    narrowest = plan
  end
  return narrowest
end

-- ForgetMeasures drops the section measures kept across renders. The bag calls it whenever it
-- binds new data to its sections (bag:Draw); renders in between (a resize, a snap) reuse them.
function canvasProto:ForgetMeasures()
  self.measured = nil
end

-- hangFromHeader places a container y below the header's top, as wide as the layout: it shares
-- the header's left edge (centered with it). It travels there when the header or the view above
-- it changed height.
---@param container Frame
---@param y number
---@param width number
function canvasProto:hangFromHeader(container, y, width)
  container:SetWidth(math.max(1, width))
  motion:Place(container, self.headerContainer, 0, -y)
end

---@return RenderPlan
function canvasProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

-- Render plans the layout for parentResult.LayoutWidth when given (a window animating to its
-- snapped width keeps the layout it snaps to), else for its width, arranges it, and centers it in
-- its width: the header, view and footer share one left edge, the widest of them centered.
---@param parentResult? RenderResult
---@return RenderResult
function canvasProto:Render(parentResult)
  local width = parentResult and parentResult.Width
  local plannedFor = parentResult and parentResult.LayoutWidth or width
  local plan = self:Plan(plannedFor)
  self.plan = plan
  self.plannedFor = plannedFor
  local animated = self.frame:IsVisible() and database:GetAnimateItemMovement()
  if animated then
    motion:BeginPass(self)
  else
    motion:Forget(self)
  end
  -- The containers first, then what is in them: an item that changes container moves from where
  -- its new one stands (render/motion.lua).
  local bag = self.bag
  local view = bag.currentView ~= nil and plan.view or nil
  local headerH = plan.global.header and plan.global.header.height or 0
  local tabH = view and view.height or 0
  self.tabContainer:SetHeight(math.max(1, tabH))
  self:hangFromHeader(self.tabContainer, headerH, plan.width)
  self:hangFromHeader(self.footerContainer, headerH + tabH, plan.width)
  bag:ArrangeGlobalSections(plan.global)
  if view ~= nil then
    bag.currentView:Arrange(view)
  end
  if animated then
    motion:EndPass()
  end

  local totalW = width or plan.width
  local offset = (totalW - plan.width) / 2
  self.headerContainer:ClearAllPoints()
  self.headerContainer:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset, 0)
  self.headerContainer:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -offset, 0)
  self.frame:SetSize(math.max(1, totalW), math.max(1, plan.height))
  return { Width = totalW, Height = plan.height, FitWidth = plan.width }
end
