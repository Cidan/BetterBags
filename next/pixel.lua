local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- NextPixel puts BetterBags Next on the screen's pixel grid (docs/next-pixel-perfect.md): every length
-- and offset Next gives a region is a whole number of screen pixels on that region's grid, so at rest
-- every frame and texture has its edges on whole pixels and every text its anchor on one, at any
-- screen size, UI scale and Bag Scale. A region's grid is its effective scale: one screen pixel in its
-- units is Blizzard's GetPixelToUIUnitFactor (768 over the screen's height in pixels) over it, as
-- Blizzard's PixelUtil and GW2_UI (GW.mult) work it out.
---@class NextPixel: AceModule
local pixel = addon:NewModule('NextPixel')

-- Round is half away from zero, as Blizzard's (Blizzard_SharedXMLBase/MathUtil.lua).
---@param value number
---@return number
local function round(value)
  if value < 0 then
    return math.ceil(value - 0.5)
  end
  return math.floor(value + 0.5)
end

-- Unit is one screen pixel in region's units.
---@param region ScriptRegion
---@return number
function pixel:Unit(region)
  return PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
end

-- Pixels is how many whole screen pixels units are on region's grid, rounded: an offset, which may be
-- none.
---@param region ScriptRegion
---@param units number
---@return number
function pixel:Pixels(region, units)
  return round(units / self:Unit(region))
end

-- Snap is units rounded to whole screen pixels on region's grid: an offset, which may be none.
---@param region ScriptRegion
---@param units number
---@return number
function pixel:Snap(region, units)
  local unit = self:Unit(region)
  return round(units / unit) * unit
end

-- Length is a length (a size, a gap, a line's thickness) in whole screen pixels on region's grid:
-- rounded, and never less than one pixel when it is not none, so a thin line always draws.
---@param region ScriptRegion
---@param units number
---@return number
function pixel:Length(region, units)
  if units == 0 then
    return 0
  end
  local unit = self:Unit(region)
  local n = round(units / unit)
  if n == 0 then
    n = units < 0 and -1 or 1
  end
  return n * unit
end

-- Point anchors region by a point, its offsets in whole pixels on its own grid (SetPoint takes them in
-- the anchored region's units). The relative point must itself be on a whole pixel: a corner or edge of
-- a region on the grid, or the middle of one an even number of pixels across.
---@param region ScriptRegion
---@param point FramePoint
---@param relativeTo? ScriptRegion|string
---@param relativePoint? FramePoint
---@param x? number
---@param y? number
function pixel:Point(region, point, relativeTo, relativePoint, x, y)
  region:SetPoint(point, relativeTo, relativePoint or point, self:Snap(region, x or 0), self:Snap(region, y or 0))
end

-- Inset anchors region inside relativeTo (its parent by default), its edges in from relativeTo's by left,
-- right, top and bottom, in whole pixels.
---@param region ScriptRegion
---@param relativeTo? ScriptRegion
---@param left? number
---@param right? number
---@param top? number
---@param bottom? number
function pixel:Inset(region, relativeTo, left, right, top, bottom)
  relativeTo = relativeTo or region:GetParent()
  region:ClearAllPoints()
  self:Point(region, "TOPLEFT", relativeTo, "TOPLEFT", left or 0, -(top or 0))
  self:Point(region, "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", -(right or 0), bottom or 0)
end

-- Size sizes region in whole pixels on its grid (a length that is not none is at least a pixel).
---@param region ScriptRegion
---@param width number
---@param height number
function pixel:Size(region, width, height)
  region:SetSize(self:Length(region, width), self:Length(region, height))
end

---@param region ScriptRegion
---@param width number
function pixel:Width(region, width)
  region:SetWidth(self:Length(region, width))
end

---@param region ScriptRegion
---@param height number
function pixel:Height(region, height)
  region:SetHeight(self:Length(region, height))
end

-- Center anchors region by its top left so that it sits in the middle of relativeTo, both widthxheight
-- sized as given (in units), on whole pixels: the middle of a frame an odd number of pixels across is
-- between two pixels, so the room left over is split with the extra pixel on the right and bottom.
---@param region ScriptRegion
---@param relativeTo ScriptRegion
---@param outerWidth number
---@param outerHeight number
---@param width number
---@param height number
---@param dx? number An offset from the middle, in units.
---@param dy? number
function pixel:Center(region, relativeTo, outerWidth, outerHeight, width, height, dx, dy)
  local unit = self:Unit(region)
  local ow, oh = self:Pixels(region, outerWidth), self:Pixels(region, outerHeight)
  local w, h = math.max(1, self:Pixels(region, width)), math.max(1, self:Pixels(region, height))
  local x = math.floor((ow - w) / 2) + self:Pixels(region, dx or 0)
  local y = math.floor((oh - h) / 2) - self:Pixels(region, dy or 0)
  region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x * unit, -y * unit)
  region:SetSize(w * unit, h * unit)
end

-- Key names the screen's pixel grid at UIParent: its scale and the screen's height. It changes with the
-- UI scale and the window's size (UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED), when everything is laid out
-- again (SonataNext).
---@return string
function pixel:Key()
  local _, height = GetPhysicalScreenSize()
  return string.format("%.6f@%d", UIParent:GetEffectiveScale(), height)
end

-- FontHeight is a font's height in whole screen pixels at UIParent's grid, where BetterBags Next's
-- windows are drawn (a small panel at a Bag Scale draws it scaled).
---@param size number
---@return number
function pixel:FontHeight(size)
  return self:Length(UIParent, size)
end
