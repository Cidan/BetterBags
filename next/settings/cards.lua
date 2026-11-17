local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextSettingsCards draws the settings window's cards (next-settings.md §4): a name, a status on the right and two
-- lines of text under the name, from the theme's Settings.Cards: filled, lit under the pointer, edged, the chosen one
-- edged in its own color. The theme picker's cards and the Help page's (help.md §5) are these, so they look the same
-- (CLAUDE.md, "UI Consistency"). Each owner sets what a card says and what a click does, and where it goes.
---@class NextSettingsCards: AceModule
local cards = addon:NewModule('NextSettingsCards')

---@class NextSettingsCard
---@field frame Button
---@field fill Texture
---@field edge NextEdge
---@field name FontString
---@field text FontString
---@field status FontString
---@field hovered boolean

-- Create makes a card.
---@param parent Frame
---@return NextSettingsCard
function cards:Create(parent)
  local K = style.Theme.Settings.Cards
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp")
  ---@type NextSettingsCard
  local card = {
    frame = frame,
    fill = frame:CreateTexture(nil, "BACKGROUND"),
    edge = controls:CreateEdge(frame),
    name = style:CreateText(frame, K.NameFont),
    text = style:CreateText(frame, K.TextFont),
    status = style:CreateText(frame, K.TextFont),
    hovered = false,
  }
  card.fill:SetAllPoints(frame)
  card.name:SetJustifyH("LEFT")
  card.text:SetJustifyH("LEFT")
  card.text:SetJustifyV("TOP")
  card.text:SetWordWrap(true)
  card.text:SetMaxLines(2)
  card.status:SetJustifyH("RIGHT")
  return card
end

-- Paint draws a card: lit under the pointer (card.hovered), edged in the chosen color when chosen; its name and text in
-- their fonts (its status's font is its owner's).
---@param card NextSettingsCard
---@param chosen boolean
function cards:Paint(card, chosen)
  local K = style.Theme.Settings.Cards
  controls:Paint(card.fill, card.hovered and K.HoverFill or K.Fill)
  controls:PaintEdge(card.edge, chosen and K.SelectedEdge or K.Edge)
  style:SetFont(card.name, K.NameFont)
  style:SetFont(card.text, K.TextFont)
end

---@class (exact) NextSettingsCardMetrics
---@field height number
---@field gap number Between cards.
---@field pad number Inside a card.
---@field minWidth number

-- Metrics returns the cards' lengths in whole pixels on a frame's grid (docs/next-pixel-perfect.md).
---@param frame Frame
---@return NextSettingsCardMetrics
function cards:Metrics(frame)
  local K = style.Theme.Settings.Cards
  return { height = pixel:Length(frame, K.Height), gap = pixel:Snap(frame, K.Gap), pad = pixel:Snap(frame, K.Pad),
    minWidth = pixel:Length(frame, K.MinWidth) }
end

-- Place puts a card x across and y down its parent, width x height, in whole pixels (docs/next-pixel-perfect.md), so its
-- edge lands on whole pixels at any scale; its name and status Pad in from its top, its text under its name's font
-- height rounded up, never its name's far edge.
---@param card NextSettingsCard
---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
function cards:Place(card, parent, x, y, width, height)
  card.frame:ClearAllPoints()
  card.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  self:Layout(card, parent, width, height)
end

-- Layout sizes a card and lays its parts out as Place does, leaving where it is to its owner (a card Motion slides).
---@param card NextSettingsCard
---@param parent Frame Its grid's frame.
---@param width number
---@param height number
function cards:Layout(card, parent, width, height)
  local frame = card.frame
  local pad = pixel:Snap(parent, style.Theme.Settings.Cards.Pad)
  frame:SetSize(width, height)
  card.name:ClearAllPoints()
  pixel:Point(card.name, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
  card.status:ClearAllPoints()
  pixel:Point(card.status, "TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
  card.text:ClearAllPoints()
  pixel:Point(card.text, "TOPLEFT", frame, "TOPLEFT", pad,
    -(pad + pixel:Ceil(parent, pixel:TextHeight(card.name)) + pixel:Snap(parent, 6)))
  card.text:SetWidth(math.max(pixel:Unit(parent), width - 2 * pad))
end
