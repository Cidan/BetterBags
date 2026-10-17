local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Database: AceModule
local database = addon:GetModule('Database')

-- BagCanvas is the drawable inside a bag's scroll box: three stacked containers for the
-- Recent Items header, the active tab view and the Free Space footer. Its render lays the bag's
-- bound sections out (the bag binds data to them before rendering) and centers them in its
-- width, so the longest row has the same padding on both sides. A bag sized to its content uses
-- its items per row and columns; a bag given a width (a window the player sized) keeps its
-- columns, fits as many items per row as that width allows and packs rows up to each column's
-- width. It reports the narrowest width that lays out the same (FitWidth), for a window
-- snapping to its content.
---@class BagCanvas: AceModule
local bagCanvas = addon:NewModule('BagCanvas')

-- A section of N items per row is 41 * N + 8 wide: N 37-pixel cells 4 apart, plus 6 pixels of
-- padding on each side (frames/section.lua Grid).
local CELL_STRIDE = 41
local SECTION_EXTRA = 8
-- The grid lets a row of sections run this far past its limit: it does not count the gap before
-- a row's last section (frames/grid.lua layoutSingleColumn).
local ROW_OVERRUN = 4

---@class (exact) BagCanvasDrawable: Drawable
---@field bag Bag
---@field frame Frame
---@field headerContainer Frame
---@field tabContainer Frame
---@field footerContainer Frame
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

  local tab = CreateFrame("Frame", nil, frame)
  tab:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
  tab:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
  tab:SetHeight(1)

  local footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, 0)
  footer:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", 0, 0)
  footer:SetHeight(1)

  canvas.headerContainer = header
  canvas.tabContainer = tab
  canvas.footerContainer = footer
  return canvas
end

-- GetLayout returns the layout for a canvas width: the bag's settings without one (rows of
-- sections packed up to 41 * N + 16, views/views.lua), else the bag's columns, as many items per
-- row as a section can show in a column, and rows packed up to the column's width.
---@param width? number
---@return ViewLayout
function canvasProto:GetLayout(width)
  local kind = self.bag.kind
  local sizeInfo = database:GetBagSizeInfo(kind, database:GetBagView(kind))
  local columns = sizeInfo.columnCount
  if width == nil then
    local itemsPerRow = sizeInfo.itemsPerRow
    return { itemsPerRow = itemsPerRow, columns = columns, rowWidth = CELL_STRIDE * itemsPerRow + 16 }
  end
  local perColumn = width / columns
  return {
    itemsPerRow = math.max(1, math.floor((perColumn - SECTION_EXTRA) / CELL_STRIDE)),
    columns = columns,
    rowWidth = perColumn - ROW_OVERRUN,
  }
end

-- fitWidth returns the narrowest width that lays the content out exactly as layout did: every
-- column as wide as the widest (rows pack the same up to it: none of them took a section that
-- would have made it wider), and the header and footer. When that width would give fewer items
-- per row (no section filled a row), it is the narrowest width that keeps them.
---@param layout ViewLayout
---@param widestColumn number
---@param headerW number
---@param footerW number
---@return number
function canvasProto:fitWidth(layout, widestColumn, headerW, footerW)
  local fit = math.max(layout.columns * widestColumn, headerW, footerW)
  if self:GetLayout(fit).itemsPerRow < layout.itemsPerRow then
    fit = layout.columns * (CELL_STRIDE * layout.itemsPerRow + SECTION_EXTRA)
  end
  return fit
end

---@return RenderPlan
function canvasProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

-- Render lays the content out for parentResult.LayoutWidth when given (a window animating to
-- its snapped width keeps the layout it snaps to), else for its width, and centers it in its
-- width: the header, view and footer share one left edge, the widest of them centered.
---@param parentResult? RenderResult
---@param options RenderChainOptions
---@return RenderResult
function canvasProto:Render(parentResult, options)
  local width = parentResult and parentResult.Width
  local layoutWidth = parentResult and parentResult.LayoutWidth or width
  local layout = self:GetLayout(layoutWidth)
  local bag = self.bag
  local headerW, headerH, footerW, footerH = bag:LayoutGlobalSections(layout)
  local tabW, tabH, widestColumn = 0, 0, 0
  if bag.currentView ~= nil then
    tabW, tabH, widestColumn = bag.currentView:Layout(options.ctx, layout)
  end
  self.tabContainer:SetHeight(math.max(1, tabH))

  local contentW = math.max(headerW, tabW, footerW)
  local totalW = width or contentW
  local totalH = headerH + tabH + footerH
  local offset = (totalW - contentW) / 2
  self.headerContainer:ClearAllPoints()
  self.headerContainer:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset, 0)
  self.headerContainer:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -offset, 0)
  self.frame:SetSize(math.max(1, totalW), math.max(1, totalH))

  local fit = contentW
  if layoutWidth ~= nil then
    fit = self:fitWidth(layout, widestColumn or tabW, headerW, footerW)
  end
  return { Width = totalW, Height = totalH, FitWidth = fit }
end
