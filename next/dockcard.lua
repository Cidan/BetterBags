local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

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
  warning:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  warning:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
  local slot = CreateFrame("Frame", nil, frame)
  slot:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", 0, -10)
  local hint = frame:CreateFontString(nil, "OVERLAY")
  hint:SetJustifyH("LEFT")
  hint:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -8)
  local card = setmetatable({ frame = frame, background = background, halo = halo, glow = glow, title = title,
    warning = warning, slot = slot, hint = hint }, { __index = cardProto })
  card:Style()
  return card
end

-- Height is how tall a card holding something that tall is.
---@param height number
---@return number
function dockCard:Height(height)
  local D = style.Theme.Dock
  return D.Pad + D.TitleHeight + 4 + D.LineHeight + 10 + height + 8 + D.LineHeight + D.Pad
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
    self.halo:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -H.Spread, H.Spread)
    self.halo:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", H.Spread, -H.Spread)
    self.halo:Show()
  else
    self.halo:Hide()
  end
  style:SetFont(self.title, D.TitleFont)
  style:SetFont(self.warning, D.WarningFont)
  style:SetFont(self.hint, D.HintFont)
  self.title:SetHeight(D.TitleHeight)
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", D.Pad, -D.Pad)
  self.title:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -D.Pad, -D.Pad)
  self.warning:SetHeight(D.LineHeight)
  self.hint:SetHeight(D.LineHeight)
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
  self.slot:SetSize(width, height)
  local cardHeight = dockCard:Height(height)
  self.frame:SetSize(width + D.Pad * 2, cardHeight)
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
