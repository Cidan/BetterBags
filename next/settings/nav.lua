local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

-- NextSettingsNav draws the rows of a list down the settings window's sidebar (next-settings.md §3): entries under
-- headings. The window lists its pages with them and the Help page its articles (help.md §4), so both look the same
-- (CLAUDE.md, "UI Consistency"), from the theme's Settings.Nav: a heading in its group font above its bottom, the
-- theme's heading art cycled through the headings; an entry Indent in, the chosen one with its bar, its fill and its
-- font, the others lit under the pointer. Each list makes its rows, sets what a click does, and places them.
---@class NextSettingsNav: AceModule
local nav = addon:NewModule('NextSettingsNav')

---@class NextSettingsNavRow
---@field frame Button
---@field fill Texture
---@field hover Texture
---@field indicator Texture
---@field label FontString
---@field hovered boolean

-- CreateRow makes a row of a list: a button with its fill, its light under the pointer, its bar and its label.
---@param parent Frame
---@return NextSettingsNavRow
function nav:CreateRow(parent)
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp")
  ---@type NextSettingsNavRow
  local row = {
    frame = frame,
    fill = frame:CreateTexture(nil, "BACKGROUND"),
    hover = frame:CreateTexture(nil, "BACKGROUND", nil, 1),
    indicator = frame:CreateTexture(nil, "ARTWORK"),
    label = style:CreateText(frame, style.Theme.Settings.Nav.Font),
    hovered = false,
  }
  row.fill:SetAllPoints(frame)
  row.hover:SetAllPoints(frame)
  -- Fills (NextFill): filling the row, or an atlas at its own size (Blizzard's settings list).
  fills:Wrap(row.fill, frame)
  fills:Wrap(row.hover, frame)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  return row
end

---@class (exact) NextSettingsNavMetrics
---@field groupGap number Above every heading but the first.
---@field groupHeight number
---@field itemHeight number
---@field spacing number Between every heading and row (Blizzard's settings list: its view's spacing).

-- Metrics returns a list's lengths in whole pixels on a frame's grid (docs/next-pixel-perfect.md).
---@param frame Frame
---@return NextSettingsNavMetrics
function nav:Metrics(frame)
  local N = style.Theme.Settings.Nav
  return { groupGap = pixel:Snap(frame, N.GroupGap), groupHeight = pixel:Length(frame, N.GroupHeight),
    itemHeight = pixel:Length(frame, N.ItemHeight), spacing = pixel:Snap(frame, N.Spacing or 0) }
end

-- PlaceRow puts a row y down its list: across it, or ItemWidth wide from its left (Nav.ItemWidth: Blizzard's rows
-- and headings, 175 wide in a list 199 wide).
---@param row NextSettingsNavRow
---@param list Frame
---@param y number
function nav:PlaceRow(row, list, y)
  local width = style.Theme.Settings.Nav.ItemWidth
  row.frame:ClearAllPoints()
  row.frame:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
  if width then
    pixel:Width(row.frame, width)
  else
    row.frame:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
  end
end

-- PaintHeading draws a row as a heading, the index-th of its list.
---@param row NextSettingsNavRow
---@param frame Frame The window, whose grid it is drawn on.
---@param index number
function nav:PaintHeading(row, frame, index)
  local N = style.Theme.Settings.Nav
  local pad = pixel:Snap(frame, style.Theme.Settings.Sidebar.Pad)
  row.label:ClearAllPoints()
  style:SetFont(row.label, N.GroupFont)
  -- A heading's art, the theme's fills cycled through the headings (Blizzard's settings list cycles
  -- Options_CategoryHeader_1 to 3), and its label where the theme says, else above its bottom.
  local headings, at = N.GroupFills, N.GroupLabel
  if at then
    pixel:Point(row.label, at.Point, row.frame, at.Point, pixel:Snap(frame, at.X or 0), pixel:Snap(frame, at.Y or 0))
  else
    pixel:Point(row.label, "BOTTOMLEFT", row.frame, "BOTTOMLEFT", pad, pixel:Snap(frame, 4))
  end
  controls:Paint(row.fill, (headings and #headings > 0) and headings[((index or 1) - 1) % #headings + 1] or false)
  row.hover:Hide()
  row.indicator:Hide()
end

-- PaintEntry draws a row as an entry: chosen, under the pointer (row.hovered), or neither. With marked, the list's
-- marker draws the chosen entry's fill and bar (it glides from one entry to the next) and the row draws only its font.
---@param row NextSettingsNavRow
---@param frame Frame The window, whose grid it is drawn on.
---@param chosen boolean
---@param marked? boolean
function nav:PaintEntry(row, frame, chosen, marked)
  local N = style.Theme.Settings.Nav
  local pad = pixel:Snap(frame, style.Theme.Settings.Sidebar.Pad)
  row.label:ClearAllPoints()
  local font = N.Font
  if chosen then
    font = N.SelectedFont
  elseif row.hovered then
    font = N.HoverFont
  end
  style:SetFont(row.label, font)
  -- From the row's corners, centered on its height by the font's (its middle may be between pixels), TextRaise above
  -- it (Blizzard's settings list raises its rows' text by 1).
  local height = pixel:Length(frame, N.ItemHeight)
  local raise = -(N.TextRaise or 0)
  pixel:Row(row.label, "TOPLEFT", row.frame, pad + pixel:Snap(frame, N.Indent), height, nil, raise)
  pixel:Row(row.label, "TOPRIGHT", row.frame, pad, height, nil, raise)
  local own = chosen and not marked
  controls:Paint(row.fill, own and N.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and N.HoverFill or false)
  self:paintBar(row.indicator, row.frame, own)
end

-- paintBar draws the chosen entry's bar down a row's (or marker's) left when shown; a theme may draw no bar (Indicator =
-- false: Blizzard's list marks the chosen row with its fill).
---@private
---@param indicator Texture
---@param owner Frame The row or marker.
---@param shown boolean
function nav:paintBar(indicator, owner, shown)
  local bar = style.Theme.Settings.Nav.Indicator
  indicator:ClearAllPoints()
  indicator:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
  indicator:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
  pixel:Width(indicator, bar and bar.Width or 1)
  controls:Paint(indicator, (shown and bar) and { Color = bar.Color } or false)
end

---@class NextSettingsNavMarker
---@field frame Frame
---@field fill Texture
---@field indicator Texture

-- CreateMarker makes a list's marker: the chosen entry's fill and bar on a frame of their own, which the list moves
-- from one entry to another, under the rows.
---@param parent Frame The list.
---@return NextSettingsNavMarker
function nav:CreateMarker(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())
  local marker = { frame = frame, fill = frame:CreateTexture(nil, "BACKGROUND"), indicator = frame:CreateTexture(nil, "ARTWORK") }
  marker.fill:SetAllPoints(frame)
  fills:Wrap(marker.fill, frame)
  return marker
end

-- PaintMarker draws a marker as the chosen entry's fill and bar.
---@param marker NextSettingsNavMarker
function nav:PaintMarker(marker)
  controls:Paint(marker.fill, style.Theme.Settings.Nav.SelectedFill)
  self:paintBar(marker.indicator, marker.frame, true)
end
