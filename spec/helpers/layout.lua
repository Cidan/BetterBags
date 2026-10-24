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
  if region._rect ~= nil then
    local l, b = region._rect.left, region._rect.bottom
    return { left = l * scale, bottom = b * scale, right = (l + region:GetWidth()) * scale,
      top = (b + region:GetHeight()) * scale }
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
  local w, ht = region:GetWidth() * scale, region:GetHeight() * scale
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
function layout.UseScreen(width, height, uiScale)
  local getSize = _G.GetPhysicalScreenSize
  local scale, rect = UIParent._scale, UIParent._rect
  local w, h = UIParent._width, UIParent._height
  _G.GetPhysicalScreenSize = function() return width, height end
  UIParent:SetScale(uiScale)
  local units = 768 / uiScale
  UIParent:_SetRect(0, 0, units * width / height, units)
  return function()
    _G.GetPhysicalScreenSize = getSize
    UIParent._scale, UIParent._rect = scale, rect
    UIParent._width, UIParent._height = w, h
  end
end

-- visible says whether a region would draw: shown, and every parent shown.
local function visible(region)
  if not region._shown then
    return false
  end
  local parent = region._parent
  while parent ~= nil do
    if parent._shown == false then
      return false
    end
    parent = parent._parent
  end
  return true
end

-- names maps regions to the field paths an owner table reaches them by (for messages).
local function names(owners)
  local map, seen = {}, {}
  local function walk(t, path, depth)
    if type(t) ~= "table" or seen[t] or depth > 4 then
      return
    end
    seen[t] = true
    for k, v in pairs(t) do
      if type(v) == "table" and type(k) == "string" and k:sub(1, 1) ~= "_" then
        local p = path .. "." .. k
        if v._type ~= nil and map[v] == nil then
          map[v] = p
        end
        walk(v, p, depth + 1)
      elseif type(v) == "table" and type(k) == "number" then
        walk(v, path .. "[" .. k .. "]", depth + 1)
      end
    end
  end
  for name, owner in pairs(owners or {}) do
    walk(owner, name, 0)
  end
  return map
end

local function onPixel(value)
  return math.abs(value - math.floor(value + 0.5)) < 1e-3
end

-- PixelCheck lists every shown region under root that is not on whole screen pixels: a frame's or a
-- texture's four edges (and so its size), a font string's anchor points. A region its anchors do not
-- place is not drawn and is skipped, as is everything under a region in skip. owners (name -> table)
-- name the regions in the messages. It returns the problems, one string each.
---@param root table
---@param opts? { skip?: table<table, boolean>, owners?: table<string, table> }
---@return string[]
function layout.PixelCheck(root, opts)
  opts = opts or {}
  local skip, named = opts.skip or {}, names(opts.owners)
  local k = layout.PixelsPerUnit()
  local problems = {}
  local function label(region, path)
    return named[region] or ((region._name or region._type) .. " " .. path)
  end
  local function check(region, path)
    if skip[region] or not visible(region) then
      return
    end
    local r = layout.Rect(region)
    if r ~= nil then
      local bad = {}
      if isText(region) then
        for _, a in ipairs(region._points) do
          local x, y = pointOf(r, a.point)
          if not onPixel(x * k) then
            table.insert(bad, string.format("%s x %.3f", a.point, x * k))
          end
          if not onPixel(y * k) then
            table.insert(bad, string.format("%s y %.3f", a.point, y * k))
          end
        end
      else
        for _, side in ipairs({ "left", "right", "top", "bottom" }) do
          if not onPixel(r[side] * k) then
            table.insert(bad, string.format("%s %.3f", side, r[side] * k))
          end
        end
      end
      if #bad > 0 then
        table.insert(problems, label(region, path) .. ": " .. table.concat(bad, ", "))
      end
    end
    for i, t in ipairs(region._textures or {}) do
      check(t, path .. ">t" .. i)
    end
    for i, f in ipairs(region._fontstrings or {}) do
      check(f, path .. ">s" .. i)
    end
    for i, c in ipairs(region._children or {}) do
      check(c, path .. ">" .. i)
    end
  end
  check(root, "")
  return problems
end

return layout
