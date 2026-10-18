local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- NextStyle holds BetterBagsNext's look in one place (next.md): sizes, colors, timings and fonts.
-- Next draws itself and does not follow the theme.
---@class NextStyle: AceModule
local style = addon:NewModule('NextStyle')

-- Item icons and the room between them.
style.ICON = 44
-- The room under a vendor button's icon for its price (next.md §10).
style.VENDOR_PRICE = 14
style.GAP = 6
style.PER_ROW = 8
-- The scroll box keeps its bar's room on both sides (render/scrollbox.lua, Symmetric).
style.GUTTER = 28
-- The room between the body's edges and the scroll box.
style.PAD = 18
style.GRID_WIDTH = style.PER_ROW * style.ICON + (style.PER_ROW - 1) * style.GAP
style.BODY_WIDTH = style.GRID_WIDTH + style.GUTTER + style.PAD * 2
-- The feathered edge left of the body, transparent to opaque.
style.FEATHER = 96
style.WIDTH = style.FEATHER + style.BODY_WIDTH
-- How far the body reaches past the screen edge, so the opening bounce never shows what is behind
-- the panel (next.md §3). The panel slides in WIDTH + OVERREACH (HiddenOffset) with outBack
-- (next/tween.lua), which swings a tenth of that past its place, so the reach must be at least
-- WIDTH / 9; 4 pixels more spare it rounding.
style.OPEN_OVERSHOOT = 0.1
style.OVERREACH = math.ceil(style.WIDTH * style.OPEN_OVERSHOOT / (1 - style.OPEN_OVERSHOOT)) + 4

-- The header, from the body's top: the title, then the search box; the content starts below.
style.TITLE_TOP = 24
style.SEARCH_TOP = 70
style.SEARCH_HEIGHT = 26
style.CONTENT_TOP = 110
style.FOOTER = 40

-- Sections: a header row above the icons, and the room between sections.
style.SECTION_HEADER = 24
style.SECTION_SPACING = 16

-- Tabs down the body's left edge.
style.TAB_HEIGHT = 30
style.TAB_SPACING = 6
style.TAB_MIN_WIDTH = 76
style.TAB_MAX_WIDTH = 150
style.TAB_PADDING = 14
style.TAB_HOVER = 6
style.TAB_ICON = 16
style.TAB_ICON_GAP = 6
-- The room between the bank's character tabs and its Warbank tabs.
style.TAB_GROUP_GAP = 10

-- Colors as { r, g, b, a }.
style.Color = {
  Body = { 0.045, 0.04, 0.085, 0.94 },
  Wash = { 0.55, 0.45, 1.0, 0.16 },
  Gold = { 1.0, 0.84, 0.5, 1 },
  -- The Warbank's accent, and the wash the panel takes while it shows a Warbank tab.
  Warbank = { 0.35, 0.85, 0.95, 1 },
  WarbankWash = { 0.3, 0.75, 1.0, 0.16 },
  White = { 1, 1, 1, 1 },
  Lavender = { 0.78, 0.72, 1.0, 1 },
  Text = { 0.96, 0.95, 1.0, 1 },
  Muted = { 0.62, 0.58, 0.78, 1 },
  Tab = { 0.09, 0.08, 0.16, 0.92 },
  TabSelected = { 0.18, 0.15, 0.32, 0.96 },
}

-- Timings, in seconds, and the cascade's rise in pixels.
-- How long everything that moves in answer to the player takes: items and sections gliding to their
-- new places (sorting, looting, switching tabs, making room for a dragged section), a dropped
-- section landing or flying into its target, and the tab bar gliding. Not the panel's own slides
-- in and out (Open, Close), which are tuned on their own.
local INTERACTION = 0.24

style.Time = {
  Interaction = INTERACTION,
  Open = 0.45,
  Close = 0.24,
  Cascade = 0.32,
  Stagger = 0.045,
  OpenCascadeDelay = 0.12,
  Glide = INTERACTION,
  -- The wash at the top of the panel fading to another color.
  Wash = 0.44,
  Hover = 0.15,
  Shimmer = 1.4,
  ShimmerEvery = 3.4,
  -- How long the shimmer takes to settle into the title's cloud once it arrives.
  Absorb = 0.7,
  -- Moving sections (next.md §7).
  Lift = 0.12,
  Land = INTERACTION,
  FlyAway = INTERACTION,
  Pulse = 0.6,
  -- Chaining (next.md §12): a bag flying to its partner, or home, or both moving across; a chained
  -- bag coming in beside its open partner; the ribbons twisting together, and coming apart.
  Fly = 0.7,
  Enter = 0.55,
  Couple = 0.5,
  Uncouple = 0.3,
}
style.RISE = 12

-- The sparkle sprite: the cooldown "bling" star, on every client.
style.SPARKLE_TEXTURE = "Interface\\Cooldown\\star4"
-- The ribbon running from the title out of the window, at full length.
style.RIBBON_LENGTH = 300

-- Chaining the backpack and its companion (next.md §12).
-- Enter: how a chained bag comes in beside its open partner: "behind" slides it out from beneath
-- the partner, "edge" flies it in from its own edge across the screen.
-- TabMargin: the room between the two bags' tab rails, which hang into the gap between the bodies.
-- The braid the two ribbons twist into: Segments lines per strand on each bag's half of the gap,
-- Amplitude pixels either side of the ribbon at the middle of the gap (none at the bodies),
-- Wavelength pixels per turn, turning Turn radians a second, Thickness pixels thick, Alpha bright
-- in front (Depth less behind); Beads lights running along it from each cloud to the knot in
-- BeadTime seconds; the knot KnotSize pixels, KnotAlpha bright, swelling by KnotSwell as they couple.
style.Chain = {
  Enter = "behind",
  TabMargin = 24,
  Segments = 16, Amplitude = 7, Wavelength = 64, Turn = 0.9, Thickness = 2, Alpha = 0.85, Depth = 0.5,
  Beads = 3, BeadTime = 1.6, BeadSize = 12,
  KnotSize = 30, KnotAlpha = 0.5, KnotSwell = 0.5,
}

-- The cloud round the title the ribbon flows into (next.md §3): puffs of a soft glow that fades to
-- nothing at its edge (tools/textures/next_glow.py), so there is no line anywhere. The cloud
-- reaches from the window's hard edge, where the ribbon ends, to Pad past the title's far side. A
-- puff sits a share F of the way across it from the ribbon's end, Y above the title's middle, W x H
-- pixels (W false: as wide as the cloud times Wide), in a color of the palette at alpha A. The
-- Join puff sits on the ribbon's end. Each puff breathes, out of step
-- with the others: its alpha by Depth and its height by Drift pixels, over a few seconds. When the
-- shimmer arrives the cloud brightens by Swell and the Join puff by JoinSwell.
style.Cloud = {
  Pad = 16, Swell = 0.6, JoinSwell = 0.45, Depth = 0.15, Drift = 1.5,
  Join = { Size = 34, Color = "Gold", A = 0.35 },
  Puffs = {
    { F = 0.45, Y = 0, W = false, Wide = 1.15, H = 60, Color = "Lavender", A = 0.09 },
    { F = 0.10, Y = 5, W = 54, H = 50, Color = "Gold", A = 0.24 },
    { F = 0.21, Y = -8, W = 50, H = 46, Color = "Gold", A = 0.2 },
    { F = 0.34, Y = 9, W = 60, H = 54, Color = "Lavender", A = 0.17 },
    { F = 0.48, Y = -7, W = 66, H = 56, Color = "Lavender", A = 0.16 },
    { F = 0.62, Y = 8, W = 58, H = 52, Color = "Lavender", A = 0.15 },
    { F = 0.77, Y = -6, W = 52, H = 46, Color = "Lavender", A = 0.12 },
    { F = 0.91, Y = 3, W = 42, H = 40, Color = "Lavender", A = 0.1 },
    { F = 0.16, Y = 17, W = 30, H = 26, Color = "Gold", A = 0.12 },
    { F = 0.28, Y = -19, W = 34, H = 30, Color = "Lavender", A = 0.11 },
    { F = 0.55, Y = 19, W = 38, H = 32, Color = "Lavender", A = 0.11 },
    { F = 0.70, Y = -18, W = 32, H = 28, Color = "Lavender", A = 0.09 },
  },
}
-- White, the shape in the alpha: a soft round glow.
style.CLOUD_GLOW = "Interface\\AddOns\\BetterBags\\textures\\next\\glow.png"
-- The spark that sweeps along the title's ribbon.
style.SPARK_TEXTURE = "Interface\\COMMON\\StreamSpark"

---@class (exact) NextFontSpec
---@field size number
---@field color number[]
---@field shadow? boolean

---@type table<string, NextFontSpec>
local FONTS = {
  Title = { size = 26, color = style.Color.White, shadow = true },
  Section = { size = 14, color = style.Color.Text, shadow = true },
  SectionRecent = { size = 14, color = style.Color.Gold, shadow = true },
  SectionFree = { size = 13, color = style.Color.Muted },
  Count = { size = 11, color = style.Color.Muted },
  Tab = { size = 12, color = style.Color.Muted },
  TabSelected = { size = 12, color = style.Color.White, shadow = true },
  Footer = { size = 12, color = style.Color.Muted },
  -- The vendor's buttons (next.md §10): the price under the icon, the stack size and stock on it.
  Price = { size = 10, color = style.Color.White, shadow = true },
  Stack = { size = 11, color = style.Color.White, shadow = true },
}

style.fonts = {} ---@type table<string, Font>

-- Font returns Next's font object of a name, made the first time it is asked for in the
-- client's own font file (the locale's), at Next's size and color.
---@param name string Title, Section, SectionRecent, SectionFree, Count, Tab, TabSelected, Footer, Price or Stack.
---@return Font
function style:Font(name)
  local font = self.fonts[name]
  if font ~= nil then
    return font
  end
  local spec = FONTS[name]
  if spec == nil then
    error("BetterBagsNext has no font named " .. tostring(name))
  end
  local path = GameFontNormal:GetFont()
  font = CreateFont("BetterBagsNextFont" .. name)
  font:SetFont(path, spec.size, "")
  font:SetTextColor(unpack(spec.color))
  if spec.shadow then
    font:SetShadowColor(0, 0, 0, 0.85)
    font:SetShadowOffset(0, -2)
  else
    font:SetShadowColor(0, 0, 0, 0)
    font:SetShadowOffset(0, 0)
  end
  self.fonts[name] = font
  return font
end

-- Color returns a color of the palette as a ColorMixin, alpha replaced when given.
---@param name string
---@param alpha? number
---@return ColorMixin
function style:CreateColor(name, alpha)
  local c = self.Color[name]
  return CreateColor(c[1], c[2], c[3], alpha or c[4])
end
