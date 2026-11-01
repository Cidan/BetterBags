-- layout.lua -- A layout resolver for the frame mock, and the pixel check built on it
-- (docs/next-pixel-perfect.md). The mock records anchors, sizes, scales and parents but works out no
-- rect from them (GetLeft is nil unless a spec sets one with _SetRect). This works rects out the way the
-- client does, for specs that ask:
--
-- - A region's effective scale is its own scale times every parent's (GetEffectiveScale).
-- - Rects here are "absolute": a region's own units times its effective scale, so regions at different
--   scales compare. A screen pixel is 768 / the screen's height (GetPhysicalScreenSize) of them.
-- - An anchor puts the region's point at its relative region's point (its parent when none is named, the
--   same point when no relative point is) plus the offsets, which are in the anchored region's own units
--   (SimpleScriptRegionResizingAPIDocumentation; warcraft.wiki.gg SetPoint).
-- - On each axis a region takes its edges from its anchors: two on an axis set its size there, one sets
--   one edge (or its middle) and its size sets the other. A size is SetSize's (own units); a font string
--   without one is as wide as its text (GetStringWidth) and as tall as its lines (GetStringHeight).
-- - A spec's _SetRect stands: it is the client's rect for that region (own units, its scale applied).
local layout = {}

local H_SIDE = {
  TOPLEFT = "left", LEFT = "left", BOTTOMLEFT = "left",
  TOPRIGHT = "right", RIGHT = "right", BOTTOMRIGHT = "right",
  TOP = "middle", CENTER = "middle", BOTTOM = "middle",
}
local V_SIDE = {
  TOPLEFT = "top", TOP = "top", TOPRIGHT = "top",
  BOTTOMLEFT = "bottom", BOTTOM = "bottom", BOTTOMRIGHT = "bottom",
  LEFT = "middle", CENTER = "middle", RIGHT = "middle",
}

local function isText(region)
  return region._type == "FontString" or region._type == "EditBox"
end

-- pointOf returns where a point of a rect is.
---@param r table { left, right, top, bottom }
---@param point string
---@return number x, number y
local function pointOf(r, point)
  local h, v = H_SIDE[point], V_SIDE[point]
  if h == nil then
    error("layout: unknown point " .. tostring(point))
  end
  local x = (h == "left" and r.left) or (h == "right" and r.right) or (r.left + r.right) / 2
  local y = (v == "top" and r.top) or (v == "bottom" and r.bottom) or (r.top + r.bottom) / 2
  return x, y
end

local resolving = {}

-- Rect returns a region's rect in absolute units ({ left, right, top, bottom }), or nil when its
-- anchors do not place it (no anchor, an anchor to a region that is not placed, a size missing).
---@param region table
---@return table?
function layout.Rect(region)
  if region == nil then
    return nil
  end
  local scale = region:GetEffectiveScale()
  -- The size set (SetSize), not GetWidth: while a screen is set up GetWidth asks this.
  local setWidth, setHeight = region._width or 0, region._height or 0
  if region._rect ~= nil then
    local l, b = region._rect.left, region._rect.bottom
    return { left = l * scale, bottom = b * scale, right = (l + setWidth) * scale, top = (b + setHeight) * scale }
  end
  if resolving[region] then
    error("layout: anchor cycle")
  end
  local points = region._points or {}
  if #points == 0 then
    return nil
  end
  resolving[region] = true
  local h, v = {}, {}
  local ok = true
  for _, a in ipairs(points) do
    local rel, relPoint, ox, oy = a.relativeTo, a.relativePoint, a.x, a.y
    -- SetPoint(point, offsetX, offsetY): the offsets where the relative region would be.
    if type(rel) == "number" then
      rel, relPoint, ox, oy = nil, nil, rel, relPoint
    end
    if type(rel) == "string" then
      rel = _G[rel]
    end
    if rel == nil then
      rel = region:GetParent()
    end
    local r = layout.Rect(rel)
    if r == nil then
      ok = false
      break
    end
    local x, y = pointOf(r, relPoint or a.point)
    x, y = x + (ox or 0) * scale, y + (oy or 0) * scale
    h[H_SIDE[a.point]] = x
    v[V_SIDE[a.point]] = y
  end
  resolving[region] = nil
  if not ok then
    return nil
  end
  local w, ht = setWidth * scale, setHeight * scale
  if isText(region) then
    if region._width == nil or region._width == 0 then
      w = (region.GetStringWidth and region:GetStringWidth() or 0) * scale
    end
    if region._height == nil or region._height == 0 then
      ht = (region.GetStringHeight and region:GetStringHeight() or 0) * scale
    end
  end
  local function axis(sides, size, low, high)
    local lo, hi, mid = sides[low], sides[high], sides.middle
    if lo ~= nil and hi ~= nil then
      return lo, hi
    end
    if lo ~= nil then
      return lo, lo + size
    end
    if hi ~= nil then
      return hi - size, hi
    end
    if mid ~= nil then
      return mid - size / 2, mid + size / 2
    end
    return nil, nil
  end
  local left, right = axis(h, w, "left", "right")
  local bottom, top = axis(v, ht, "bottom", "top")
  if left == nil or bottom == nil then
    return nil
  end
  return { left = left, right = right, top = top, bottom = bottom }
end

-- scaledRect answers GetScaledRect from the resolver: the rect in absolute units (own units times the
-- effective scale, what the client's GetScaledRect returns), or nothing when the anchors do not place it.
local function scaledRect(region)
  local r = layout.Rect(region)
  if r == nil then
    return
  end
  return r.left, r.bottom, r.right - r.left, r.top - r.bottom
end

-- PixelsPerUnit is how many screen pixels one absolute unit is (Blizzard's GetPixelToUIUnitFactor is
-- its inverse).
---@return number
function layout.PixelsPerUnit()
  local _, height = GetPhysicalScreenSize()
  return height / 768
end

-- UseScreen sets the screen up as the client would for a screen of width x height pixels at a UI
-- scale: GetPhysicalScreenSize, and UIParent at that scale, as wide and tall as the screen in its own
-- units. It returns a function that puts everything back.
---@param width number
---@param height number
---@param uiScale number
---@return fun()
--
-- While it is set up, a region with no size of its own on an axis reports the size its anchors give it
-- (GetWidth, GetHeight, GetSize), as the client reports a region's resolved size (warcraft.wiki.gg
-- Region:GetWidth); a font string still reports its own (the mock measures its text). GetScaledRect, GetLeft,
-- GetRight, GetTop, GetBottom, GetCenter and GetRect report where its anchors put it (the edges in its own
-- units), unless a spec set its rect.
function layout.UseScreen(width, height, uiScale)
  local getSize = _G.GetPhysicalScreenSize
  local scale, rect = UIParent._scale, UIParent._rect
  local w, h = UIParent._width, UIParent._height
  local methods = _G.__mockWidgetMethods
  local getWidth, getHeight = methods.GetWidth, methods.GetHeight
  local function resolved(region, key, get, low, high)
    local size = get(region)
    if size ~= 0 or isText(region) or #(region._points or {}) < 2 then
      return size
    end
    local r = layout.Rect(region)
    if r == nil then
      return size
    end
    return (r[high] - r[low]) / region:GetEffectiveScale()
  end
  methods.GetWidth = function(region) return resolved(region, "_width", getWidth, "left", "right") end
  methods.GetHeight = function(region) return resolved(region, "_height", getHeight, "bottom", "top") end
  local getScaledRect = methods.GetScaledRect
  methods.GetScaledRect = scaledRect
  -- A region's edges where its anchors put it, in its own units, as the client reports them (a rect a spec set
  -- stands, as in the plain mock).
  local edges = {}
  for _, key in ipairs({ "GetLeft", "GetRight", "GetTop", "GetBottom", "GetCenter", "GetRect" }) do
    edges[key] = methods[key]
  end
  local function own(region)
    if region._rect ~= nil then
      return nil
    end
    local r = layout.Rect(region)
    if r == nil then
      return nil
    end
    local sc = region:GetEffectiveScale()
    return { left = r.left / sc, right = r.right / sc, top = r.top / sc, bottom = r.bottom / sc }
  end
  local function edge(key, read)
    methods[key] = function(region)
      local r = own(region)
      if r == nil then
        return edges[key](region)
      end
      return read(r)
    end
  end
  edge("GetLeft", function(r) return r.left end)
  edge("GetRight", function(r) return r.right end)
  edge("GetTop", function(r) return r.top end)
  edge("GetBottom", function(r) return r.bottom end)
  edge("GetCenter", function(r) return (r.left + r.right) / 2, (r.top + r.bottom) / 2 end)
  edge("GetRect", function(r) return r.left, r.bottom, r.right - r.left, r.top - r.bottom end)
  _G.GetPhysicalScreenSize = function() return width, height end
  UIParent:SetScale(uiScale)
  local units = 768 / uiScale
  UIParent:_SetRect(0, 0, units * width / height, units)
  return function()
    methods.GetWidth, methods.GetHeight = getWidth, getHeight
    methods.GetScaledRect = getScaledRect
    for key, fn in pairs(edges) do
      methods[key] = fn
    end
    _G.GetPhysicalScreenSize = getSize
    UIParent._scale, UIParent._rect = scale, rect
    UIParent._width, UIParent._height = w, h
  end
end

-- ArtWithNoSize lists the shown textures under root that draw a file and have no width or height: a texture with none
-- draws at its file's own size (seen in game: pencil art 128 units wide over a 48-unit box), which the mock cannot show.
---@param root Frame
---@return string[]
function layout.ArtWithNoSize(root)
  local out = {}
  local function visit(frame, path)
    if not frame:IsShown() then
      return
    end
    for i, region in ipairs({ frame:GetRegions() }) do
      if region:IsObjectType("Texture") and region:IsShown() and region:GetTexture() ~= nil then
        local rect = layout.Rect(region)
        if rect ~= nil and (rect.right - rect.left <= 0 or rect.top - rect.bottom <= 0) then
          table.insert(out, path .. ">" .. i .. " " .. tostring(region:GetTexture()))
        end
      end
    end
    for i, child in ipairs({ frame:GetChildren() }) do
      visit(child, path .. ">" .. i)
    end
  end
  visit(root, "root")
  return out
end

-- PixelCheck runs BetterBags' pixel check (PixelAudit:Check, debug/pixelaudit.lua: the same check the game
-- runs from the /bbdb debug window) on the mock, the client's GetScaledRect answered by the resolver. It lists
-- every shown region under root that draws and is not on whole screen pixels, one string each; opts.skip and
-- opts.owners are PixelAudit's.
---@param root table
---@param opts? { skip?: table<table, boolean>, owners?: table<string, table> }
---@return string[]
function layout.PixelCheck(root, opts)
  local methods = _G.__mockWidgetMethods
  local get = methods.GetScaledRect
  methods.GetScaledRect = scaledRect
  local audit = LibStub("AceAddon-3.0"):GetAddon("BetterBags"):GetModule("PixelAudit")
  local ok, problems = pcall(audit.Check, audit, root, opts)
  methods.GetScaledRect = get
  if not ok then
    error(problems, 0)
  end
  return problems
end

return layout
