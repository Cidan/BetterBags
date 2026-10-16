local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

-- Scrollbox is a drawable that scrolls one child: a WowScrollBox with a MinimalScrollBar.
-- It hands the child the width left of the bar (or nothing, for a natural width), sizes the
-- scroll child to the height the child took, and reports the viewport it occupies: the
-- child's height capped at MaxHeight when the window sizes to its content, or the fixed
-- Height of a window the player sized. The bar shows and hides itself
-- (SetHideIfUnscrollable): it is updated from the scroll box's own size, which the window
-- sets after this render. Each window owns one scroll box for its lifetime.
---@class Scrollbox: AceModule
local scrollbox = addon:NewModule('Scrollbox')

-- The width kept free for the scroll bar, whether or not it shows, so the content does not
-- move when the bar appears.
local BAR_WIDTH = 14

---@class (exact) ScrollboxDrawable: Drawable
---@field frame Frame
---@field scrollBox WowScrollBox
---@field scrollBar MinimalScrollBar
---@field scrollChild Frame
---@field scrollView table
---@field child? Drawable
---@field plan? RenderPlan
local scrollboxProto = drawable:Extend({}, 'ScrollboxFrame')

-- SetChild makes child the drawable this box scrolls. The child it replaces is hidden and
-- detached from the box.
---@param child Drawable
function scrollboxProto:SetChild(child)
  local previous = self.child
  if previous ~= nil and previous ~= child then
    previous:Hide()
    if previous.renderParent == self then
      render:Detach(previous)
    end
  end
  self.child = child
  child.renderParent = self
  child:SetParent(self.scrollChild)
  child:ClearAllPoints()
  child:SetPoint({ Point = "TOPLEFT", RelativeTo = self.scrollChild, RelativePoint = "TOPLEFT" })
  child:Hide()
  self.plan = {
    Plan = {
      { step = render.PRE },
      { step = render.DEP, target = child },
      { step = render.SELF },
    }
  }
end

---@return Drawable?
function scrollboxProto:GetChild()
  return self.child
end

---@return number
function scrollboxProto:GetBarWidth()
  return BAR_WIDTH
end

---@return RenderPlan
function scrollboxProto:GetRenderPlan()
  if self.plan == nil then
    error("a scroll box was rendered without a child -- did you call SetChild?")
  end
  return self.plan
end

---@param parentResult? RenderResult
---@return RenderResult
function scrollboxProto:PreRender(parentResult)
  local width = parentResult and parentResult.Width
  return {
    Width = width and math.max(0, width - BAR_WIDTH) or nil,
  }
end

---@param parentResult? RenderResult
---@param _ RenderChainOptions
---@param results RenderResults
---@return RenderResult
function scrollboxProto:Render(parentResult, _, results)
  local childResult = results.Results[self.child]
  if childResult == nil then
    error("the scroll box's child returned no render result")
  end
  local childWidth = childResult.Width or 0
  local childHeight = childResult.Height or 0
  self.scrollChild:SetHeight(math.max(1, childHeight))
  self.child:Show()

  local viewport = childHeight
  if parentResult and parentResult.Height then
    viewport = parentResult.Height
  elseif parentResult and parentResult.MaxHeight then
    viewport = math.min(childHeight, parentResult.MaxHeight)
  end
  local scrollable = childHeight > viewport + 0.5
  self.scrollBar:SetAttribute("nodeignore", not scrollable)
  self.scrollBox:FullUpdate(true)

  local width = parentResult and parentResult.Width or (childWidth + BAR_WIDTH)
  return { Width = width, Height = viewport, Scrollable = scrollable }
end

-- Create builds a scroll box parented to parent. The caller anchors sb.frame.
---@param parent Frame
---@param name? string
---@return ScrollboxDrawable
function scrollbox:Create(parent, name)
  ---@type ScrollboxDrawable
  local sb = drawable:Create(scrollboxProto)
  local frame = CreateFrame("Frame", name, parent)
  local box = CreateFrame("Frame", name and (name .. "Box") or nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetAllPoints(frame)
  box:SetInterpolateScroll(true)
  local bar = CreateFrame("EventFrame", nil, box, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", -12, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", -12, 0)
  bar:SetInterpolateScroll(true)
  bar:SetHideIfUnscrollable(true)

  -- Initializing the box moves every child marked scrollable under its scroll target and
  -- anchors it there, stretched to the box's width.
  local child = CreateFrame("Frame", nil, box)
  child:SetHeight(1)
  child.scrollable = true

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(100)
  ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view)

  sb.frame = frame
  sb.scrollBox = box
  sb.scrollBar = bar
  sb.scrollChild = child
  sb.scrollView = view
  return sb
end
