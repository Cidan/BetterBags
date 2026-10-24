local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- The room between the card's lines, from its title down: under the title, under the warning, under the
-- slot.
local UNDER_TITLE, UNDER_WARNING, UNDER_SLOT = 4, 10, 8

-- NextDockCard is the card a dragged section waits in to be confirmed (NextDrag's dock, next.md §7)
-- and the vendor's destroy card (automation.md §4): the theme's Dock fill, a glowing edge round it and
-- a halo behind it, both pulsing, a title, a warning, a slot for what it holds and a hint under it.
-- Both are this card (asked: the destroy card styled like the sell dock, "consistent design is key");
-- the destroy card only glows in another color.
---@class NextDockCard: AceModule
local dockCard = addon:NewModule('NextDockCard')

---@class NextDockCardFrame
---@field frame Frame The card.
---@field background Texture
---@field halo Texture
---@field glow Texture[] Its edge: top, bottom, left, right.
---@field title FontString
---@field warning FontString
---@field slot Frame Where what it holds goes.
---@field hint FontString
local cardProto = {}
addon:GetModule('Perf'):RegisterPrototype(cardProto, 'NextDockCardFrame')

-- Create makes a card on parent, styled from the theme.
---@param parent Frame
---@return NextDockCardFrame
function dockCard:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local halo = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
  local background = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
  background:SetAllPoints(frame)
  local glow = {}
  for _ = 1, 4 do
    table.insert(glow, frame:CreateTexture(nil, "BORDER"))
  end
  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetJustifyH("LEFT")
  local warning = frame:CreateFontString(nil, "OVERLAY")
  warning:SetJustifyH("LEFT")
  local slot = CreateFrame("Frame", nil, frame)
  local hint = frame:CreateFontString(nil, "OVERLAY")
  hint:SetJustifyH("LEFT")
  local card = setmetatable({ frame = frame, background = background, halo = halo, glow = glow, title = title,
    warning = warning, slot = slot, hint = hint }, { __index = cardProto })
  card:Style()
  return card
end

-- Height is how tall a card on region's grid holding something that tall is: the sum of its parts, each
-- in whole pixels (docs/next-pixel-perfect.md).
---@param region ScriptRegion
---@param height number
---@return number
function dockCard:Height(region, height)
  local D = style.Theme.Dock
  local pad, title, line = pixel:Lengths(region, D.Pad, D.TitleHeight, D.LineHeight)
  local a, b, c = pixel:Lengths(region, UNDER_TITLE, UNDER_WARNING, UNDER_SLOT)
  return pad + title + a + line + b + pixel:Length(region, height) + c + line + pad
end

-- Style draws the card from the theme (Dock): the fill (a texture spec), the edge round the card
-- (Glow: color, width, or none), the halo behind it (Halo, or none), its lines in their roles. With
-- color, the edge and the halo glow in it instead of the theme's colors; without, in the theme's.
---@param color? string|number[]
function cardProto:Style(color)
  local D = style.Theme.Dock
  style:Paint(self.background, D.Card)
  local G = D.Glow
  local sides = { "TOP", "BOTTOM", "LEFT", "RIGHT" }
  for i, edge in ipairs(self.glow) do
    edge:ClearAllPoints()
    if G then
      local w, side = G.Width, sides[i]
      edge:SetColorTexture(1, 1, 1, 1)
      edge:SetVertexColor(style:RGBA(color or G.Color))
      w = pixel:Length(edge, w)
      if side == "TOP" or side == "BOTTOM" then
        local y = side == "TOP" and w or -w
        edge:SetPoint(side .. "LEFT", self.frame, side .. "LEFT", -w, y)
        edge:SetPoint(side .. "RIGHT", self.frame, side .. "RIGHT", w, y)
        edge:SetHeight(w)
      else
        local x = side == "LEFT" and -w or w
        edge:SetPoint("TOP" .. side, self.frame, "TOP" .. side, x, 0)
        edge:SetPoint("BOTTOM" .. side, self.frame, "BOTTOM" .. side, x, 0)
        edge:SetWidth(w)
      end
      edge:Show()
    else
      edge:Hide()
    end
  end
  local H = D.Halo
  self.halo:ClearAllPoints()
  if H then
    style:Paint(self.halo, { Texture = H.Texture, Color = color or H.Color, BlendMode = H.BlendMode or "ADD" })
    local spread = pixel:Length(self.halo, H.Spread)
    self.halo:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -spread, spread)
    self.halo:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", spread, -spread)
    self.halo:Show()
  else
    self.halo:Hide()
  end
  style:SetFont(self.title, D.TitleFont)
  style:SetFont(self.warning, D.WarningFont)
  style:SetFont(self.hint, D.HintFont)
  -- Each line under the one before by whole pixels: the title at the padding, the warning under it, the
  -- slot under that and the hint under the slot (docs/next-pixel-perfect.md).
  local frame = self.frame
  local pad = pixel:Length(frame, D.Pad)
  pixel:Height(self.title, D.TitleHeight)
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
  self.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
  pixel:Height(self.warning, D.LineHeight)
  pixel:Height(self.hint, D.LineHeight)
  self.warning:ClearAllPoints()
  pixel:Point(self.warning, "TOPLEFT", self.title, "BOTTOMLEFT", 0, -UNDER_TITLE)
  pixel:Point(self.warning, "TOPRIGHT", self.title, "BOTTOMRIGHT", 0, -UNDER_TITLE)
  self.slot:ClearAllPoints()
  pixel:Point(self.slot, "TOPLEFT", self.warning, "BOTTOMLEFT", 0, -UNDER_WARNING)
  self.hint:ClearAllPoints()
  pixel:Point(self.hint, "TOPLEFT", self.slot, "BOTTOMLEFT", 0, -UNDER_SLOT)
end

-- SetText sets the card's title, warning and hint.
---@param title string
---@param warning string
---@param hint string
function cardProto:SetText(title, warning, hint)
  self.title:SetText(title)
  self.warning:SetText(warning)
  self.hint:SetText(hint)
end

-- Size makes the slot width x height and the card as big as its padding, its lines and the slot,
-- returning the card's height.
---@param width number
---@param height number
---@return number
function cardProto:Size(width, height)
  local D = style.Theme.Dock
  local frame = self.frame
  pixel:Size(self.slot, width, height)
  local cardHeight = dockCard:Height(frame, height)
  frame:SetSize(self.slot:GetWidth() + 2 * pixel:Length(frame, D.Pad), cardHeight)
  return cardHeight
end

-- Pulse sets the edge's and the halo's brightness for a moment t seconds into the pulse: each rises and
-- falls between its Low and High over its Period, halfway at 0.
---@param t number
function cardProto:Pulse(t)
  local D = style.Theme.Dock
  local G, H = D.Glow, D.Halo
  local function wave(period)
    return 0.5 + 0.5 * math.sin(t * 2 * math.pi / period)
  end
  if G then
    local alpha = G.Low + (G.High - G.Low) * wave(G.Period)
    for _, edge in ipairs(self.glow) do
      edge:SetAlpha(alpha)
    end
  end
  if H then
    self.halo:SetAlpha(H.Low + (H.High - H.Low) * wave(H.Period))
  end
end
