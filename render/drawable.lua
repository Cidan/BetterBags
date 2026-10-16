local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class Perf: AceModule
local perf = addon:GetModule('Perf')

-- Drawable is the base of everything the render pipeline draws. An instance has a frame and
-- a render plan. Instances look their methods up through their prototype, and every
-- prototype through the drawable defaults here, so the profiler's wrappers on a prototype
-- reach every instance.
---@class DrawableModule: AceModule
---@field proto Drawable The drawable defaults every prototype chains to.
local drawable = addon:NewModule('Drawable')

---@class (exact) Point
---@field Point FramePoint
---@field RelativeTo? Frame|Region|string
---@field RelativePoint? FramePoint
---@field XOffset? number
---@field YOffset? number

---@class Drawable
---@field frame Frame
---@field sortKey number
---@field renderParent? Drawable The drawable that rendered this one in the last chain.
---@field renderParentResult? RenderResult The constraints renderParent last gave this one.
---@field renderRoot? boolean Invalidation stops here even when the drawable has a parent.
---@field renderPending? boolean Invalidated while ShouldRender returned false.
---@field ShouldRender? fun(self: Drawable): boolean
local drawableProto = {}
drawable.proto = drawableProto
perf:RegisterPrototype(drawableProto, 'DrawableFrame')

-- Extend makes proto a drawable prototype: its instances fall back to the drawable defaults,
-- and the profiler measures its methods under name.
---@generic T
---@param proto T
---@param name string
---@return T
function drawable:Extend(proto, name)
  setmetatable(proto, { __index = drawableProto })
  perf:RegisterPrototype(proto, name)
  return proto
end

-- Create returns a new instance of proto with fields copied in. A prototype that was not
-- extended is chained to the drawable defaults.
---@param proto table
---@param fields? table
---@return any
function drawable:Create(proto, fields)
  if getmetatable(proto) == nil then
    setmetatable(proto, { __index = drawableProto })
  end
  local instance = setmetatable({}, { __index = proto })
  for k, v in pairs(fields or {}) do
    instance[k] = v
  end
  if instance.sortKey == nil then
    instance.sortKey = 1
  end
  return instance
end

-- A FrameDrawable wraps a frame laid out by its own code (a grid, a form): rendering asks
-- measure(parentResult, options) for the size it took.
---@class (exact) FrameDrawable: Drawable
---@field measure fun(parentResult: RenderResult?, options: RenderChainOptions): number, number
local frameDrawableProto = drawable:Extend({}, 'FrameDrawable')

---@return RenderPlan
function frameDrawableProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

---@param parentResult? RenderResult
---@param options RenderChainOptions
---@return RenderResult
function frameDrawableProto:Render(parentResult, options)
  local width, height = self.measure(parentResult, options)
  return { Width = width, Height = height }
end

-- FromFrame returns a drawable for frame, sized by measure.
---@param frame Frame
---@param measure fun(parentResult: RenderResult?, options: RenderChainOptions): number, number
---@return FrameDrawable
function drawable:FromFrame(frame, measure)
  return drawable:Create(frameDrawableProto, { frame = frame, measure = measure })
end

---@param parent? Frame
function drawableProto:SetParent(parent)
  self.frame:SetParent(parent)
end

function drawableProto:ClearAllPoints()
  self.frame:ClearAllPoints()
end

---@param point Point
function drawableProto:SetPoint(point)
  self.frame:SetPoint(point.Point, point.RelativeTo, point.RelativePoint, point.XOffset, point.YOffset)
end

function drawableProto:Hide()
  self.frame:Hide()
end

function drawableProto:Show()
  self.frame:Show()
end

---@param width number
---@param height number
function drawableProto:SetSize(width, height)
  self.frame:SetSize(width, height)
end

---@param width number
function drawableProto:SetWidth(width)
  self.frame:SetWidth(width)
end

---@param height number
function drawableProto:SetHeight(height)
  self.frame:SetHeight(height)
end

---@return Frame
function drawableProto:GetFrame()
  return self.frame
end

---@return boolean
function drawableProto:IsVisible()
  return self.frame:IsVisible()
end

---@param key number
function drawableProto:SetSortKey(key)
  self.sortKey = key
end

---@return number
function drawableProto:GetSortKey()
  return self.sortKey
end

-- Invalidate renders this drawable's tree again on the next frame.
function drawableProto:Invalidate()
  render:Invalidate(self)
end

---@return RenderPlan
function drawableProto:GetRenderPlan()
  error("you must specify a render plan function for this drawable")
end

---@param parentResult? RenderResult
---@param options RenderChainOptions
---@return RenderResult?
function drawableProto:PreRender(parentResult, options)
  local _ = parentResult
  _ = options
  error("you must specify a pre render function for this drawable")
end

---@param parentResult? RenderResult
---@param options RenderChainOptions
---@param results RenderResults
---@return RenderResult?
function drawableProto:Render(parentResult, options, results)
  local _ = parentResult
  _ = options
  _ = results
  error("you must specify a render function for this drawable")
end
