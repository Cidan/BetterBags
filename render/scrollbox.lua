local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

-- Scrollbox is a drawable that scrolls one child: a WowScrollBox with a MinimalScrollBar.
-- It hands the child the width left of the bar's room (or nothing, for a natural width), sizes
-- the scroll child to the height the child took, and reports the viewport it occupies: the
-- child's height capped at MaxHeight when the window sizes to its content, or the fixed
-- Height of a window the player sized. A child's FitWidth goes up and a LayoutWidth comes down
-- with the room added or taken off; FitHeight goes up as the child's height, the viewport that
-- shows all of it. The bar shows and hides itself (SetHideIfUnscrollable): it
-- is updated from the scroll box's own size, which the window sets after this render. A bag's
-- box keeps the bar's room on both sides and shows the bar only while it is used
-- (ScrollboxOptions). Each window owns one scroll box for its lifetime.
---@class Scrollbox: AceModule
local scrollbox = addon:NewModule('Scrollbox')

-- The width kept free for the scroll bar, whether or not it shows, so the content does not
-- move when the bar appears.
local BAR_WIDTH = 14

-- The auto-hiding bar: how long it takes to fade in and out, and how long it stays after the
-- last wheel scroll or after the pointer leaves its room.
local FADE_IN = 0.15
local FADE_OUT = 0.3
local LINGER = 1

---@class (exact) ScrollboxOptions
---@field Symmetric? boolean Keep the bar's room on both sides, so the child is centered.
---@field AutoHideBar? boolean Show the bar only while the wheel scrolls or the pointer is over its room.
---@field CreateBar? fun(box: WowScrollBox, opts: {AutoHide: boolean}): ScrollboxBar A bar of the caller's in place of Blizzard's MinimalScrollBar (BetterBags Next's, next-settings.md §2), made once the box has its view; it hides itself when AutoHide.
---@field Snap? fun(region: ScriptRegion, units: number): number Rounds the bar's room to whole screen pixels on a region's grid (BetterBags Next's NextPixel:Length, docs/next-pixel-perfect.md), so the child sits on them.
---@field SnapScroll? fun(box: WowScrollBox) Makes the box scroll by whole screen pixels (BetterBags Next's NextPixel:SnapScroll), called once with it.

-- A bar of the caller's: its frame, and Bind(box), which makes it follow and drive the box.
---@class (exact) ScrollboxBar
---@field frame Frame
---@field Bind fun(self: ScrollboxBar, box: WowScrollBox)

---@class (exact) ScrollboxDrawable: Drawable
---@field frame Frame
---@field scrollBox WowScrollBox
---@field scrollBar Frame Blizzard's MinimalScrollBar, or a caller's bar's frame (CreateBar).
---@field bar? ScrollboxBar A caller's bar (CreateBar).
---@field scrollChild Frame
---@field scrollView table
---@field child? Drawable
---@field plan? RenderPlan
---@field symmetric boolean
---@field snap? fun(region: ScriptRegion, units: number): number
---@field barDriver? Frame Updates the auto-hiding bar each frame while the bar is shown.
---@field barIdle number Seconds since the wheel last scrolled or the pointer left the bar's room.
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
  self:placeChild()
  child:Hide()
  self.plan = {
    Plan = {
      { step = render.PRE },
      { step = render.DEP, target = child },
      { step = render.SELF },
    }
  }
end

-- placeChild hangs the child from the scroll child's top left, past the bar's room on a symmetric box.
---@private
function scrollboxProto:placeChild()
  local child = self.child
  child:ClearAllPoints()
  child:SetPoint({ Point = "TOPLEFT", RelativeTo = self.scrollChild, RelativePoint = "TOPLEFT",
    XOffset = self.symmetric and self:GetBarWidth() or 0 })
end

---@return Drawable?
function scrollboxProto:GetChild()
  return self.child
end

-- GetBarWidth returns the bar's room, in whole pixels on the box's grid when it snaps (Snap).
---@return number
function scrollboxProto:GetBarWidth()
  if self.snap ~= nil then
    return self.snap(self.frame, BAR_WIDTH)
  end
  return BAR_WIDTH
end

-- GetGutterWidth returns the width the box keeps free beside its child: the bar's room, on the
-- right, or on both sides for a symmetric box.
---@return number
function scrollboxProto:GetGutterWidth()
  return self.symmetric and 2 * self:GetBarWidth() or self:GetBarWidth()
end

-- GutterWidthFor returns the width a box made with opts keeps free beside its child, known before
-- the box is made (a window can read its owner's minimums while the owner is still being built).
---@param opts? ScrollboxOptions
---@return number
function scrollbox:GutterWidthFor(opts)
  return opts ~= nil and opts.Symmetric == true and BAR_WIDTH * 2 or BAR_WIDTH
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
  -- Rounded to whole pixels, the bar's room follows the box's grid (a scale it took since).
  if self.snap ~= nil then
    self:placeChild()
  end
  local width = parentResult and parentResult.Width
  local layoutWidth = parentResult and parentResult.LayoutWidth
  -- The width to lay out for loses the room in units, never rounded to the grid: what the child is laid out
  -- for must not depend on the grid it is drawn on (BetterBags Next, next-pixel-perfect.md §3).
  return {
    Width = width and math.max(0, width - self:GetGutterWidth()) or nil,
    LayoutWidth = layoutWidth and math.max(0, layoutWidth - scrollbox:GutterWidthFor({ Symmetric = self.symmetric })) or nil,
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

  local width = parentResult and parentResult.Width or (childWidth + self:GetGutterWidth())
  local fit = childResult.FitWidth and childResult.FitWidth + self:GetGutterWidth() or nil
  return { Width = width, Height = viewport, Scrollable = scrollable, FitWidth = fit, FitHeight = childHeight }
end

-- updateBar fades the auto-hiding bar in while the pointer is over its room on the right or the
-- wheel scrolled less than LINGER seconds ago, and out otherwise. It runs every frame the bar is
-- shown (Blizzard shows it only when the child does not fit).
---@private
---@param elapsed number
function scrollboxProto:updateBar(elapsed)
  local frame = self.frame
  if frame:IsMouseOver(0, 0, frame:GetWidth() - self:GetBarWidth(), 0) then
    self.barIdle = 0
  else
    self.barIdle = self.barIdle + elapsed
  end
  local bar = self.scrollBar
  local alpha = bar:GetAlpha()
  if self.barIdle < LINGER then
    alpha = math.min(1, alpha + elapsed / FADE_IN)
  else
    alpha = math.max(0, alpha - elapsed / FADE_OUT)
  end
  if alpha ~= bar:GetAlpha() then
    bar:SetAlpha(alpha)
  end
end

-- hideBar makes the auto-hiding bar invisible until the wheel or the pointer shows it.
---@private
function scrollboxProto:hideBar()
  self.barIdle = LINGER
  self.scrollBar:SetAlpha(0)
end

-- Create builds a scroll box parented to parent. The caller anchors sb.frame.
---@param parent Frame
---@param name? string
---@param opts? ScrollboxOptions
---@return ScrollboxDrawable
function scrollbox:Create(parent, name, opts)
  ---@type ScrollboxDrawable
  local sb = drawable:Create(scrollboxProto)
  sb.symmetric = opts ~= nil and opts.Symmetric == true
  sb.snap = opts ~= nil and opts.Snap or nil
  local frame = CreateFrame("Frame", name, parent)
  local box = CreateFrame("Frame", name and (name .. "Box") or nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetAllPoints(frame)
  box:SetInterpolateScroll(true)
  if opts ~= nil and opts.SnapScroll then
    opts.SnapScroll(box)
  end

  -- Initializing the box moves every child marked scrollable under its scroll target and
  -- anchors it there, stretched to the box's width.
  local child = CreateFrame("Frame", nil, box)
  child:SetHeight(1)
  child.scrollable = true

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(100)

  sb.frame = frame
  sb.scrollBox = box
  sb.scrollChild = child
  sb.scrollView = view

  if opts ~= nil and opts.CreateBar then
    -- The caller's bar hides itself when asked, so the box's own fading below is not used.
    box:Init(view)
    local own = opts.CreateBar(box, { AutoHide = opts.AutoHideBar == true })
    own:Bind(box)
    sb.bar = own
    sb.scrollBar = own.frame
    return sb
  end

  local bar = CreateFrame("EventFrame", nil, box, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", -12, 0)
  bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", -12, 0)
  bar:SetInterpolateScroll(true)
  bar:SetHideIfUnscrollable(true)
  ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view)
  sb.scrollBar = bar

  if opts ~= nil and opts.AutoHideBar then
    -- A child of the bar updates only while the bar is shown; it starts hidden each time the bar
    -- reappears. Wheel scrolls reach the box's own OnMouseWheel, which scrolls it.
    local driver = CreateFrame("Frame", nil, bar)
    driver:SetScript("OnUpdate", function(_, elapsed)
      sb:updateBar(elapsed)
    end)
    driver:SetScript("OnShow", function()
      sb:hideBar()
    end)
    box:HookScript("OnMouseWheel", function()
      sb.barIdle = 0
    end)
    sb.barDriver = driver
    sb:hideBar()
  end
  return sb
end
