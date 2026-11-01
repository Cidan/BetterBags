local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextStyle is BetterBags Next's look, read from the current Next theme (.claude/rules/next-themes.md):
-- SonataNext hands it every theme it applies (Use). Its long-standing fields (ICON, PAD, Color,
-- Time, Small, Chain, Cloud, ...) are views of the theme, so Next's code reads them as it always
-- has; the theme's widget specs are on style.Theme. Read them when drawing, never into a value kept
-- at load: a theme can change them at any time. Font objects are made per theme application and
-- never changed (text).
---@class NextStyle: AceModule
---@field Theme table The current Next theme, resolved.
---@field Color table<string, number[]> The theme's palette.
local style = addon:NewModule('NextStyle')

-- The player's Icon Scale (the Size tab, docs/next-appearance-size.md), in percent: SetIconScale.
style.iconScale = 100

-- How far past its end each ease swings (next/tween.lua): outBack about a tenth, outBackSoft a
-- fiftieth. Opening with one, the body must reach that much past the screen edge (OVERREACH).
local OVERSHOOT = { outBack = 0.1, outBackSoft = 0.02 }

-- SetIconScale sets the player's Icon Scale (docs/next-appearance-size.md), in percent, and sizes the
-- item buttons for it (sizeIcons). Nothing else changes, and no font object is made: a slider dragged
-- through its steps calls it on every step.
---@param percent number
function style:SetIconScale(percent)
  self.iconScale = percent
  self:sizeIcons()
end

-- sizeIcons sizes the item buttons: the theme's icon size (Layout.Icon) times the Icon Scale, in whole
-- pixels, as every other size is. A vendor's card is as tall as its icon, and never shorter than the theme's
-- icon size, which two lines of name and a price beside the icon need.
---@private
function style:sizeIcons()
  local theme = self.Theme.Layout.Icon
  self.ICON = math.max(1, math.floor(theme * self.iconScale / 100 + 0.5))
  self.CARD_HEIGHT = math.max(self.ICON, theme)
end

-- palette returns a theme's palette as colors: each { r, g, b, a } as given, and each entry naming one of the
-- client's colors ({ Global = "PANEL_BACKGROUND_COLOR", Alpha? }: Color.lua, Blizzard_SharedXMLBase, makes every
-- named UI color a Lua global ColorMixin on every client) read now, its alpha replaced by the entry's Alpha.
---@param theme table
---@return table<string, number[]>
local function palette(theme)
  local colors = {}
  for name, value in pairs(theme.Palette) do
    if type(value) == "table" and value.Global ~= nil then
      local color = _G[value.Global]
      if type(color) ~= "table" or color.GetRGBA == nil then
        error("the Next theme's color " .. name .. " names no client color " .. tostring(value.Global))
      end
      local r, g, b, a = color:GetRGBA()
      colors[name] = { r, g, b, value.Alpha or a or 1 }
    else
      colors[name] = value
    end
  end
  return colors
end

-- Use makes theme the look: every field below is read from it, and every text drawn with a role
-- moves to a new font object of its role, unless keepFonts says the theme's fonts have not changed.
---@param theme table A resolved Next theme (SonataNext:Resolve).
---@param keepFonts? boolean
function style:Use(theme, keepFonts)
  self.Theme = theme
  -- A theme's animations as stop motion (Motion.StopMotion, next-themes.md §25): what steps itself reads it here.
  self.StopMotion = theme.Motion.StopMotion or nil
  local L, M = theme.Layout, theme.Motion
  self.Color = palette(theme)

  -- Item buttons are the theme's icon size times the player's Icon Scale (sizeIcons); the grid keeps the
  -- theme's own, so a row fits as many buttons as its width allows.
  self:sizeIcons()
  self.GAP = L.Gap
  self.PER_ROW = L.PerRow
  self.GUTTER = L.Gutter
  self.PAD = L.Pad
  self.FEATHER = L.Feather
  self.GRID_WIDTH = self.PER_ROW * L.Icon + (self.PER_ROW - 1) * self.GAP
  -- The vendor's cards (next.md §10b): VendorColumns across the full grid; a small panel made wider
  -- fits more of them.
  self.VENDOR_COLUMNS = L.VendorColumns
  self.VENDOR_TEXT_GAP = L.VendorTextGap
  self.VENDOR_PRICE_RAISE = L.VendorPriceRaise
  self.VENDOR_CARD_WIDTH = math.floor((self.GRID_WIDTH - (self.VENDOR_COLUMNS - 1) * self.GAP) / self.VENDOR_COLUMNS)
  -- The strip the header buttons go down, along the body's inner side (Header.Buttons.Rail,
  -- next-themes.md §13); 0 when they go across the header. Inside the body (RAIL) the body is that much
  -- wider, its content not; outside it (RAIL_OUT, Outside) the strip stands beside the body, and the tabs and
  -- a chained bag beyond it.
  local rail = theme.Header.Buttons.Rail
  self.RAIL = (rail and not rail.Outside) and rail.Width or 0
  self.RAIL_OUT = (rail and rail.Outside) and rail.Width or 0
  self.BODY_WIDTH = self.GRID_WIDTH + self.GUTTER + self.PAD * 2 + self.RAIL
  self.WIDTH = self.FEATHER + self.BODY_WIDTH
  -- How far the body reaches past the screen edge, so the opening bounce never shows what is behind
  -- the panel: it slides in WIDTH + OVERREACH (HiddenOffset) and swings OPEN_OVERSHOOT of that past
  -- its place; 4 more spare it rounding.
  local overshoot = OVERSHOOT[M.Ease.Open] or 0
  self.OPEN_OVERSHOOT = overshoot
  self.OVERREACH = math.ceil(self.WIDTH * overshoot / (1 - overshoot)) + 4

  self.TITLE_TOP = L.TitleTop
  self.TITLE_INSET = L.TitleInset
  self.SEARCH_TOP = L.SearchTop
  self.SEARCH_HEIGHT = L.SearchHeight
  self.SEARCH_ICON = L.SearchIcon
  self.SEARCH_GAP = L.SearchGap
  self.SEARCH_RIGHT = L.SearchRight
  self.CONTENT_TOP = L.ContentTop
  self.FOOTER = L.Footer
  self.SECTION_HEADER = L.SectionHeader
  self.SECTION_SPACING = L.SectionSpacing
  self.TAB_HEIGHT = L.TabHeight
  self.TAB_SPACING = L.TabSpacing
  self.TAB_MIN_WIDTH = L.TabMinWidth
  self.TAB_MAX_WIDTH = L.TabMaxWidth
  self.TAB_PADDING = L.TabPadding
  self.TAB_HOVER = L.TabHover
  self.TAB_ICON = L.TabIcon
  self.TAB_ICON_GAP = L.TabIconGap
  self.TAB_GROUP_GAP = L.TabGroupGap
  self.HEADER_BUTTON = L.HeaderButton
  self.HEADER_BUTTON_GAP = L.HeaderButtonGap
  self.HEADER_BUTTON_TOP = L.HeaderButtonTop
  self.EMPTY_TOP = L.EmptyTop
  self.FOOTER_TEXT = L.FooterText
  self.FOOTER_MONEY = L.FooterMoney

  local edge, icon = theme.Search.Edge or { Idle = 0, Hover = 0, Focus = 0 }, theme.Search.Icon
  self.SearchEdge = { Idle = edge.Idle, Hover = edge.Hover, Focus = edge.Focus }
  self.SearchIcon = { Idle = icon.Idle, Active = icon.Active }

  self.Time = M.Time
  self.RISE = M.Rise
  self.Small = {}
  for key, value in pairs(theme.Small) do
    self.Small[key] = value
  end
  self.Small.Edge = theme.Panel.Edge and theme.Panel.Edge.Alpha or 0
  self.Chain = theme.Chain
  self.Cloud = theme.Header.Cloud or nil
  local ribbon = theme.Header.Ribbon
  self.RIBBON_LENGTH = ribbon and ribbon.Length or 0
  self.SPARKLE_TEXTURE = self:TexturePath(theme.Sparkles and theme.Sparkles.Texture or "Sparkle")
  self.CLOUD_GLOW = self:TexturePath("Glow")

  -- The font objects stay as they are when the theme's fonts have not changed (the Animation switches laid over the
  -- theme in use again, SonataNext:ApplyAnimation): font objects can never be freed.
  if keepFonts then
    return
  end
  -- The pixel grid the fonts are made for (NextPixel: a new one applies the theme again).
  self.gridKey = pixel:Key()
  self:newFonts()
end

-- RGBA returns a color: a palette name, or { r, g, b, a } given outright, alpha replaced when given.
---@param ref string|number[]
---@param alpha? number
---@return number r, number g, number b, number a
function style:RGBA(ref, alpha)
  local c = ref
  if type(ref) == "string" then
    c = self.Color[ref]
    if c == nil then
      error("the Next theme has no color named " .. ref)
    end
  end
  return c[1], c[2], c[3], alpha or c[4] or 1
end

-- CreateColor returns a color as a ColorMixin: a palette name or { r, g, b, a }, alpha replaced when
-- given.
---@param ref string|number[]
---@param alpha? number
---@return ColorMixin
function style:CreateColor(ref, alpha)
  return CreateColor(self:RGBA(ref, alpha))
end

-- Ease returns the ease the theme gives an animation (next/tween.lua's names).
---@param name string
---@return NextEase
function style:Ease(name)
  return self.Theme.Motion.Ease[name] or "outCubic"
end

-- TexturePath returns a texture the theme names (its Textures), or ref itself (a file or file ID).
---@param ref string|number
---@return string|number
function style:TexturePath(ref)
  local named = type(ref) == "string" and self.Theme.Textures[ref]
  return named or ref
end

-- Text. Every theme application makes a new font object for each role asked for, and moves every
-- text drawn with a role to its role's new one: a font object is never changed after it is made
-- (asked: "don't re-use text objects across themes, make whole new ones"; Sonata's lesson, sonata.md
-- 3c: a font object changed while text used it left that text out of step). Text drawn with a role
-- must not set its own color or shadow: a state that looks different is another role.

style.fonts = {} ---@type table<string, Font>
style.texts = setmetatable({}, { __mode = "k" }) ---@type table<FontString|EditBox, string>
-- Text whose template colors it, colored by its role too (SetTemplateFont).
style.templated = setmetatable({}, { __mode = "k" }) ---@type table<FontString|EditBox, boolean>

-- The number of font objects made: their names must be unique.
local fontCount = 0

-- shadowFont gives a font object a role's shadow: true for the theme's, a table, or none.
---@private
---@param font Font
---@param shadow? boolean|table
function style:shadowFont(font, shadow)
  if shadow == true then
    shadow = self.Theme.FontShadow
  end
  if type(shadow) == "table" then
    font:SetShadowColor(self:RGBA(shadow.Color or "Black"))
    font:SetShadowOffset(shadow.X or 0, shadow.Y or 0)
  else
    font:SetShadowColor(0, 0, 0, 0)
    font:SetShadowOffset(0, 0)
  end
end

-- lookOf names what a font object draws: its file, size, flags, color and shadow.
---@param font Font
---@return string
local function lookOf(font)
  local path, size, flags = font:GetFont()
  local r, g, b, a = font:GetTextColor()
  local sr, sg, sb, sa = font:GetShadowColor()
  local sx, sy = font:GetShadowOffset()
  return table.concat({ tostring(path), tostring(size), tostring(flags), tostring(r), tostring(g), tostring(b),
    tostring(a), tostring(sr), tostring(sg), tostring(sb), tostring(sa), tostring(sx), tostring(sy) }, "|")
end

-- CopiesStale says whether a client font one of the roles copied (Object) no longer draws what it drew when it
-- was copied: UI addons rewrite the client's fonts once the game has loaded (GW2_UI at PLAYER_LOGIN,
-- docs/next-gw2-theme.md), after BetterBags made its fonts. Only the copies made with the current fonts count.
---@return boolean
function style:CopiesStale()
  for _, copy in pairs(self.copies) do
    if lookOf(copy.base) ~= copy.look then
      return true
    end
  end
  return false
end

-- fileOf returns the font file a role's spec names, if it is drawn in this client's locale: a file covers some
-- alphabets, and Locales names the locales it is drawn in (the Glitch theme's terminal fonts are Latin only).
---@param spec table
---@return string?
local function fileOf(spec)
  if spec.File == nil or spec.Locales == nil then
    return spec.File
  end
  local locale = GetLocale()
  for _, name in ipairs(spec.Locales) do
    if name == locale then
      return spec.File
    end
  end
  return nil
end

-- makeFont makes a font object for a role's spec: the client's own font file (the locale's) unless
-- the spec names one for this locale (Locales), at its size and flags, in its color, with its shadow or none. A role naming one
-- of the client's fonts (Object, a font object's global name) copies it (its file, size and flags,
-- in every locale, its color and shadow), changing only what the role also sets; one that copies it
-- outright (Copy) takes nothing the role inherits but its Size (false: the client font's own). Its height is a whole
-- number of screen pixels where BetterBags Next's windows are drawn (NextPixel:FontHeight,
-- docs/next-pixel-perfect.md): a new grid (the UI scale, the screen's size) applies the theme again.
---@param role string
---@param spec table
---@return Font
function style:makeFont(role, spec)
  fontCount = fontCount + 1
  local font = CreateFont("BetterBagsNextFont" .. role .. fontCount)
  -- Copy: a client font as it is (the Plain theme), nothing the role inherits changing it but its Size (Default's, unless
  -- the role says false: the client's own), its height on whole pixels and its own Justify.
  local copy = spec.Copy
  if copy ~= nil then
    local base = _G[copy]
    if type(base) ~= "table" or base.GetFont == nil then
      error("BetterBags Next's font role " .. role .. " copies no client font named " .. tostring(copy))
    end
    font:CopyFontObject(base)
    self.copies[role] = { base = base, look = lookOf(base) }
    local path, size, flags = font:GetFont()
    font:SetFont(path, pixel:FontHeight(spec.Size or size), flags)
  elseif spec.Object ~= nil then
    local base = _G[spec.Object]
    if type(base) ~= "table" or base.GetFont == nil then
      error("BetterBags Next's font role " .. role .. " copies no client font named " .. tostring(spec.Object))
    end
    font:CopyFontObject(base)
    self.copies[role] = { base = base, look = lookOf(base) }
    local path, size, flags = font:GetFont()
    font:SetFont(fileOf(spec) or path, pixel:FontHeight(spec.Size or size), spec.Flags or flags)
    if spec.Color ~= nil then
      font:SetTextColor(self:RGBA(spec.Color))
    end
    if spec.Shadow ~= nil then
      self:shadowFont(font, spec.Shadow)
    end
  else
    font:SetFont(fileOf(spec) or GameFontNormal:GetFont(), pixel:FontHeight(spec.Size), spec.Flags or "")
    font:SetTextColor(self:RGBA(spec.Color or "White"))
    self:shadowFont(font, spec.Shadow)
  end
  if spec.Justify ~= nil then
    font:SetJustifyH(spec.Justify)
  end
  return font
end

-- Font returns the current theme's font object of a role, made the first time it is asked for.
---@param role string
---@return Font
function style:Font(role)
  local font = self.fonts[role]
  if font ~= nil then
    return font
  end
  local spec = self.Theme.Fonts[role]
  if spec == nil then
    error("BetterBags Next has no font role named " .. tostring(role))
  end
  font = self:makeFont(role, spec)
  self.fonts[role] = font
  return font
end

-- SetFont draws a font string or edit box with a role, and keeps it on its role's font object
-- through every theme.
---@param text FontString|EditBox
---@param role string
function style:SetFont(text, role)
  text:SetFontObject(self:Font(role))
  self.texts[text] = role
end

-- SetTemplateFont draws text a Blizzard template colors itself with a role: SetFont, and the role's
-- color and shadow set on the text too, now and with every theme. A template's own color wins over
-- a font object's (an XML <Color>, as InputBoxInstructionsTemplate gives its help text 0.35 gray), as
-- Sonata's apply:Font handles it.
---@param text FontString|EditBox
---@param role string
function style:SetTemplateFont(text, role)
  self.templated[text] = true
  self:SetFont(text, role)
  self:colorText(text)
end

-- colorText sets the color and shadow of a text's role on the text itself: from the role's font
-- object, never one read back from the text (an InputBoxTemplate edit box's GetFontObject returns a
-- font of its own, .context/patterns-ui.md).
---@private
---@param text FontString|EditBox
function style:colorText(text)
  local font = self:Font(self.texts[text])
  text:SetTextColor(font:GetTextColor())
  text:SetShadowColor(font:GetShadowColor())
  text:SetShadowOffset(font:GetShadowOffset())
end

-- Paint draws a texture from a theme's texture spec: a solid Color (a palette name or a color, alpha
-- replaced when given), or a Texture (one of the theme's Textures by name, a file or file ID) or an
-- Atlas tinted by Color; with TexCoords { left, right, top, bottom }, HorizTile and VertTile (the
-- REPEAT wrap mode, so a tiled texture repeats rather than streaking its edge), BlendMode and
-- Desaturated. Everything it does not set is reset, so a texture painted again keeps nothing of
-- the last spec.
---@param texture Texture
---@param spec table
---@param alpha? number
function style:Paint(texture, spec, alpha)
  local r, g, b, a = self:RGBA(spec.Color or "White", alpha)
  texture:SetTexCoord(0, 1, 0, 1)
  texture:SetHorizTile(false)
  texture:SetVertTile(false)
  if spec.Texture ~= nil or spec.Atlas ~= nil then
    local wrapH = spec.HorizTile and "REPEAT" or nil
    local wrapV = spec.VertTile and "REPEAT" or nil
    if spec.Atlas ~= nil then
      texture:SetAtlas(spec.Atlas, false, nil, nil, wrapH, wrapV)
    else
      texture:SetTexture(self:TexturePath(spec.Texture), wrapH, wrapV)
    end
    local c = spec.TexCoords
    if c ~= nil then
      texture:SetTexCoord(c[1], c[2], c[3], c[4])
    end
    texture:SetHorizTile(spec.HorizTile == true)
    texture:SetVertTile(spec.VertTile == true)
    texture:SetVertexColor(r, g, b, a)
  else
    texture:SetColorTexture(r, g, b, a)
    texture:SetVertexColor(1, 1, 1, 1)
  end
  texture:SetBlendMode(spec.BlendMode or "BLEND")
  texture:SetDesaturated(spec.Desaturated == true)
end

-- AtlasSize returns an atlas's own size as the client has it (C_Texture.GetAtlasInfo, every client), or nil for no
-- atlas or one the client lacks: what Blizzard's useAtlasSize draws a texture at.
---@param atlas? string
---@return number? width, number? height
function style:AtlasSize(atlas)
  local info = atlas ~= nil and C_Texture.GetAtlasInfo(atlas) or nil
  if info == nil then
    return nil, nil
  end
  return info.width, info.height
end

-- SizeOf returns the size a spec draws at: its Size (a number, square), or the size of its art's atlas for
-- Size = "Atlas" (Blizzard's useAtlasSize), or fallback when its atlas is not one the client has.
---@param spec table
---@param art? table The art drawn now (a state's), whose Atlas is measured; spec's own when nil.
---@param fallback? number
---@return number width, number height
function style:SizeOf(spec, art, fallback)
  if spec.Size ~= "Atlas" then
    return spec.Size or fallback, spec.Size or fallback
  end
  local width, height = self:AtlasSize((art or spec).Atlas or spec.Atlas)
  return width or fallback, height or fallback
end

-- IsArt says whether a fill names art (a texture spec with a Texture or an Atlas) rather than a color (a palette
-- name or { r, g, b, a }): a part that takes either draws art with Paint and a color its own way.
---@param fill any
---@return boolean
function style:IsArt(fill)
  return type(fill) == "table" and (fill.Texture ~= nil or fill.Atlas ~= nil)
end

-- CreateText makes a font string drawn with a role.
---@param parent Frame
---@param role string
---@param layer? DrawLayer OVERLAY when unset.
---@return FontString
function style:CreateText(parent, role, layer)
  local text = parent:CreateFontString(nil, layer or "OVERLAY")
  self:SetFont(text, role)
  return text
end

-- newFonts starts a new set of font objects and moves every text to its role's new one. Text whose
-- role the theme does not define (another theme's own role) keeps its font object: its widget gives
-- it one of this theme's roles as it restyles.
---@private
function style:newFonts()
  self.fonts = {}
  self.copies = {}
  local roles = self.Theme.Fonts
  for text, role in pairs(self.texts) do
    if roles[role] ~= nil then
      text:SetFontObject(self:Font(role))
      if self.templated[text] then
        self:colorText(text)
      end
    end
  end
end

-- Until SonataNext starts (with the saved theme), and for specs, the look is the Default theme.
style:Use(sonataNext:Resolve("Default"))
