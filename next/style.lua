local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- NextStyle holds BetterBagsNext's look in one place (next.md): sizes, colors, timings and fonts.
-- Next draws itself and does not follow the theme.
---@class NextStyle: AceModule
local style = addon:NewModule('NextStyle')

-- Item icons and the room between them.
style.ICON = 44
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
-- How far the body reaches past the screen's right edge, so the opening overshoot never shows
-- what is behind the panel.
style.OVERREACH = 40

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
style.Time = {
  Open = 0.45,
  Close = 0.24,
  Cascade = 0.32,
  Stagger = 0.045,
  OpenCascadeDelay = 0.12,
  Glide = 0.22,
  Hover = 0.15,
  Shimmer = 1.4,
  ShimmerEvery = 3.4,
  -- Moving sections (next.md §7).
  Lift = 0.12,
  Land = 0.22,
  FlyAway = 0.3,
  Pulse = 0.6,
}
style.RISE = 12

-- The sparkle sprite: the cooldown "bling" star, on every client.
style.SPARKLE_TEXTURE = "Interface\\Cooldown\\star4"
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
}

style.fonts = {} ---@type table<string, Font>

-- Font returns Next's font object of a name, made the first time it is asked for in the
-- client's own font file (the locale's), at Next's size and color.
---@param name string Title, Section, SectionRecent, SectionFree, Count, Tab, TabSelected or Footer.
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
