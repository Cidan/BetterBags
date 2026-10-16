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
-- bound sections out (the bag binds data to them before rendering). A bag sized to its content
-- uses its items per row and columns; a bag given a width (a window the player sized) keeps its
-- columns and fits as many items per row as that width allows.
---@class BagCanvas: AceModule
local bagCanvas = addon:NewModule('BagCanvas')

-- A section of N items per row is 41 * N + 8 wide: N 37-pixel cells 4 apart, plus the section's
-- 6-pixel padding on each side (frames/section.lua Grid, frames/grid.lua layoutSingleColumn).
local CELL_STRIDE = 41
local SECTION_EXTRA = 8

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

-- GetLayout returns the layout for a canvas width: the bag's settings without one, else the
-- bag's columns with as many items per row as fit.
---@param width? number
---@return ViewLayout
function canvasProto:GetLayout(width)
  local kind = self.bag.kind
  local sizeInfo = database:GetBagSizeInfo(kind, database:GetBagView(kind))
  local columns = sizeInfo.columnCount
  if width == nil then
    return { itemsPerRow = sizeInfo.itemsPerRow, columns = columns }
  end
  local perColumn = width / columns - SECTION_EXTRA
  return { itemsPerRow = math.max(1, math.floor(perColumn / CELL_STRIDE)), columns = columns }
end

---@return RenderPlan
function canvasProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

---@param parentResult? RenderResult
---@param options RenderChainOptions
---@return RenderResult
function canvasProto:Render(parentResult, options)
  local width = parentResult and parentResult.Width
  local layout = self:GetLayout(width)
  local bag = self.bag
  local headerW, headerH, footerW, footerH = bag:LayoutGlobalSections(layout)
  local tabW, tabH = 0, 0
  if bag.currentView ~= nil then
    tabW, tabH = bag.currentView:Layout(options.ctx, layout)
  end
  self.tabContainer:SetHeight(math.max(1, tabH))

  local totalW = width or math.max(headerW, tabW, footerW)
  local totalH = headerH + tabH + footerH
  self.frame:SetSize(math.max(1, totalW), math.max(1, totalH))
  return { Width = totalW, Height = totalH }
end
