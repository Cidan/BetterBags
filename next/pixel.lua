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

-- UnitAt is one screen pixel in the units of a region drawn at an effective scale (a panel's own, before
-- it has taken it: it is worked out while the panel still switches size).
---@param effectiveScale number
---@return number
function pixel:UnitAt(effectiveScale)
  return PixelUtil.GetPixelToUIUnitFactor() / effectiveScale
end

-- Unit is one screen pixel in region's units.
---@param region ScriptRegion
---@return number
function pixel:Unit(region)
  return self:UnitAt(region:GetEffectiveScale())
end

-- SnapIn is units rounded to whole pixels of a unit (UnitAt): an offset, which may be none.
---@param unit number
---@param units number
---@return number
function pixel:SnapIn(unit, units)
  return round(units / unit) * unit
end

-- LengthIn is a length in whole pixels of a unit: rounded, never less than one pixel when it is not none.
---@param unit number
---@param units number
---@return number
function pixel:LengthIn(unit, units)
  if units == 0 then
    return 0
  end
  local n = round(units / unit)
  if n == 0 then
    n = units < 0 and -1 or 1
  end
  return n * unit
end

-- FloorIn is units rounded down to whole pixels of a unit.
---@param unit number
---@param units number
---@return number
function pixel:FloorIn(unit, units)
  return math.floor(units / unit + 1e-6) * unit
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
  return self:SnapIn(self:Unit(region), units)
end

-- Length is a length (a size, a gap, a line's thickness) in whole screen pixels on region's grid:
-- rounded, and never less than one pixel when it is not none, so a thin line always draws.
---@param region ScriptRegion
---@param units number
---@return number
function pixel:Length(region, units)
  return self:LengthIn(self:Unit(region), units)
end

-- Floor is units rounded down to whole pixels on region's grid: the room something may take (a width it
-- must not pass).
---@param region ScriptRegion
---@param units number
---@return number
function pixel:Floor(region, units)
  return self:FloorIn(self:Unit(region), units)
end

-- Ceil is units rounded up to whole pixels on region's grid: the room something needs (a text's width,
-- so what comes after it never overlaps it).
---@param region ScriptRegion
---@param units number
---@return number
function pixel:Ceil(region, units)
  local unit = self:Unit(region)
  return math.ceil(units / unit - 1e-6) * unit
end

-- Lengths is Length of each value, on region's grid.
---@param region ScriptRegion
---@param ... number
---@return number ...
function pixel:Lengths(region, ...)
  local out = { ... }
  for i = 1, select("#", ...) do
    out[i] = self:Length(region, out[i])
  end
  return unpack(out, 1, select("#", ...))
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

-- Middle is the offset that puts a length in the middle of another on region's grid, in whole pixels (both
-- rounded first): the room left over split, the odd pixel after (below, or to the right); never negative.
-- A text or an icon is centered on a row by its top this far down, never by its middle, which lies between
-- two pixels on a row an odd number of pixels tall.
---@param region ScriptRegion
---@param outer number
---@param inner number
---@return number
function pixel:Middle(region, outer, inner)
  local left = self:Pixels(region, outer) - self:Pixels(region, inner)
  return math.max(0, math.floor(left / 2)) * self:Unit(region)
end

-- TextHeight is a font string's (or edit box's) font height in its own units: what it is centered by.
---@param text FontString|EditBox
---@return number
function pixel:TextHeight(text)
  local _, height = text:GetFont()
  return height or 0
end

-- Row anchors region by a top corner (TOPLEFT or TOPRIGHT) of relativeTo, x in from that corner's side,
-- centered on a row rowHeight tall that starts top down from relativeTo's top (none: its top), all in whole
-- pixels on region's grid. height is what is centered: region's own height when not given, a text's font
-- height (TextHeight) for a font string.
---@param region ScriptRegion
---@param corner "TOPLEFT"|"TOPRIGHT"
---@param relativeTo ScriptRegion
---@param x number
---@param rowHeight number
---@param height? number
---@param top? number
function pixel:Row(region, corner, relativeTo, x, rowHeight, height, top)
  if height == nil then
    height = region:GetObjectType() == "FontString" and self:TextHeight(region) or region:GetHeight()
  end
  local across = self:Snap(region, x)
  local down = self:Snap(region, top or 0) + self:Middle(region, rowHeight, height)
  region:SetPoint(corner, relativeTo, corner, corner == "TOPRIGHT" and -across or across, -down)
end

-- SnapScroll keeps what a scroll box holds on whole pixels wherever it is scrolled: Blizzard's box anchors its
-- scroll target at the scroll offset in UI units (ScrollBoxBaseMixin:SetScrollTargetOffset, called by its
-- Update each time it scrolls or lays out), between pixels at rest unless rounded. For BetterBags' own boxes
-- (it replaces the box's own method, which the box's mixin copied onto it); once per box.
---@param box WowScrollBox
function pixel:SnapScroll(box)
  if box.nextSnapsScroll then
    return
  end
  box.nextSnapsScroll = true
  local set = box.SetScrollTargetOffset
  box.SetScrollTargetOffset = function(b, offset)
    return set(b, self:Snap(b, offset))
  end
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

-- Init follows the screen's pixel grid (called once SonataNext has applied the saved theme, core/init.lua):
-- the UI scale and the window's size set it (UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED, the events
-- Blizzard's Edit Mode and the Window module follow too). Registered once however often it starts.
function pixel:Init()
  if self.watching then
    return
  end
  self.watching = true
  ---@class Events: AceModule
  local events = addon:GetModule('Events')
  for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    events:RegisterEvent(event, function(ctx)
      self:OnGridChanged(ctx)
    end)
  end
end

-- OnGridChanged applies the current Next theme again, unsaved, when the grid is not the one its fonts were
-- made for (NextStyle.gridKey): every font height and length in whole pixels again, everything laid out
-- again. It returns whether it did, for profiler traces.
---@param ctx Context
---@return boolean
function pixel:OnGridChanged(ctx)
  local sonataNext = addon:GetModule('SonataNext')
  local style = addon:GetModule('NextStyle')
  local key = sonataNext.started and sonataNext:GetCurrentThemeKey() or nil
  if key == nil or style.gridKey == self:Key() then
    return false
  end
  sonataNext:ApplyTheme(ctx, key, false)
  return true
end

