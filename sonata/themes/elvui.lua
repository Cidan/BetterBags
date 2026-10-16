local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- ElvUI: BetterBags drawn the way ElvUI's skins draw Blizzard's frames, as data. Nothing of
-- ElvUI's is called; the variables read ElvUI's media and pixel settings when the theme is
-- applied (ElvUI fills them while it loads, before BetterBags), so the theme follows the
-- player's ElvUI colors and textures.
--   Windows: ElvUI's "Transparent" template (SetTemplate): a blank-texture backdrop in the
--     fade color with a one-pixel edge (two with "two pixels please"), and, outside pixel mode,
--     black lines inside and outside the edge. ElvUI owns the opacity of its frames.
--   Close buttons: ElvUI's close art, 12 pixels in a 24 pixel button, tinted on hover.
--   Item buttons (HandleItemButton, HandleIconBorder): the default template behind the icon,
--     quality on the edge (common items black), ElvUI's quest and upgrade icons; no Masque.
--   Tabs (HandleTab), the search box and edit boxes (HandleEditBox), dialog buttons
--     (HandleButton): flat in the default template.

---@return table?
local function engine()
  local elvui = _G.ElvUI
  return type(elvui) == "table" and elvui[1] or nil
end

---@param c? number[]
---@param alpha? number
---@return number[]
local function rgba(c, alpha)
  c = c or { 0.1, 0.1, 0.1 }
  return { c[1] or 0, c[2] or 0, c[3] or 0, alpha or c[4] or 1 }
end

---@param n number
---@return number
local function scale(n)
  local E = engine()
  return E and E.Scale and E:Scale(n) or n
end

---@return table
local function media()
  local E = engine()
  return E and E.media or {}
end

---@param key string
---@return string
local function texture(key)
  local E = engine()
  local textures = E and E.Media and E.Media.Textures or {}
  return textures[key] or "Interface\\Buttons\\WHITE8X8"
end

local BACKDROP = {
  BgFile = "$BlankTex",
  EdgeFile = "$BlankTex",
  EdgeSize = "$EdgeSize",
  Color = "$BackdropFadeColor",
  BorderColor = "$BorderColor",
  Opacity = false,
  Outlines = "$Outlines",
}

local TITLE = { Font = { Object = "GameFontWhite" }, Points = { { Point = "TOP", X = 0, Y = 0 } }, Height = 30 }

local CLOSE = {
  Size = 24,
  Points = { { Point = "TOPRIGHT", X = -4, Y = -4 } },
  Normal = { Texture = "$CloseTex", Inset = { Left = 6, Right = 6, Top = 6, Bottom = 6 } },
  HoverColor = "$ValueColor",
  HitRectInsets = { 6, 6, 7, 7 },
}

---@param noClose? boolean
---@return table
local function titled(noClose)
  return { Backdrop = BACKDROP, Title = TITLE, CloseButton = not noClose and CLOSE or nil }
end

local bag = titled()
bag.Layout = {
  Search = {
    Points = {
      { Point = "TOPLEFT", X = 10, Y = -40 },
      { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -60 },
    },
  },
  MenuButton = { Points = { { Point = "TOPLEFT", X = 4, Y = -6 } } },
}

local PORTRAIT = { Width = 40.8, Height = 51 }
local HOVER = { Color = { 1, 1, 1, 0.3 }, BlendMode = "ADD", Inset = "$Inside" }
local OUTSIDE_SEARCH = { Left = -4, Right = -4, Top = 0, Bottom = 0 }

sonata:RegisterTheme({
  Name = "elvui",
  DisplayName = "ElvUI",
  Description = "An ElvUI theme for BetterBags.",
  Available = function()
    return engine() ~= nil
  end,
  Masque = false,
  Variables = {
    BlankTex = function() return media().blankTex or "Interface\\Buttons\\WHITE8X8" end,
    GlossTex = function() return media().glossTex or media().blankTex or "Interface\\Buttons\\WHITE8X8" end,
    CloseTex = function() return texture("Close") end,
    QuestTex = function() return texture("BagQuestIcon") end,
    UpgradeTex = function() return texture("BagUpgradeIcon") end,
    BorderColor = function() return rgba(media().bordercolor, 1) end,
    BackdropColor = function() return rgba(media().backdropcolor, 1) end,
    BackdropFadeColor = function() return rgba(media().backdropfadecolor) end,
    ValueColor = function() return rgba(media().rgbvaluecolor, 1) end,
    EdgeSize = function()
      local E = engine()
      return scale(E and E.twoPixelsPlease and 2 or 1)
    end,
    -- Outside pixel mode ElvUI draws black one-pixel lines inside and outside the edge.
    Outlines = function()
      local E = engine()
      if E == nil or E.PixelMode then
        return {}
      end
      local size = scale(1)
      return {
        { Offset = -1, EdgeSize = size, Color = { 0, 0, 0, 1 } },
        { Offset = 1, EdgeSize = size, Color = { 0, 0, 0, 1 } },
      }
    end,
    -- SetInside's offset: the border width.
    Inside = function()
      local E = engine()
      local n = scale(E and E.Border or 1)
      return { Left = n, Right = n, Top = n, Bottom = n }
    end,
    IconInset = function()
      local E = engine()
      return scale(E and E.Border or 1)
    end,
    TexCoords = function()
      local E = engine()
      local c = E and E.TexCoords or { 0, 1, 0, 1 }
      return { c[1], c[2], c[3], c[4] }
    end,
    -- HandleTab: the backdrop 3 pixels in from the sides (10 on older clients), 1 from the
    -- top in pixel mode (3 otherwise) and 3 from the bottom.
    TabInset = function()
      local E = engine()
      local side = E and E.Modern and 3 or 10
      return { Left = side, Right = side, Top = E and E.PixelMode and 1 or 3, Bottom = 3 }
    end,
  },
  Windows = {
    Bag = bag,
    Panel = titled(),
    Flat = titled(),
    Dialog = titled(true),
    Slots = { Backdrop = BACKDROP },
    Search = { Backdrop = BACKDROP },
  },
  Elements = {
    ItemButton = {
      Icon = { Inset = "$IconInset", TexCoords = "$TexCoords" },
      Highlight = HOVER,
      Pushed = HOVER,
      Backdrop = { Color = "$BackdropColor", BorderColor = "$BorderColor", EdgeSize = "$EdgeSize" },
      QualityBorder = "Backdrop",
      -- ElvUI draws common items' edge black.
      QualityColors = { [1] = { 0, 0, 0, 1 } },
      QuestIcon = { Texture = "$QuestTex" },
      QuestBorderColor = { 1, 0.8, 0, 1 },
      UpgradeIcon = { Texture = "$UpgradeTex", Scale = 1.2 },
    },
    Tab = {
      Art = "Flat",
      Background = { Color = "$BackdropColor", Inset = "$TabInset" },
      Border = { Color = "$BorderColor", EdgeSize = "$EdgeSize", Inset = "$TabInset" },
      TextOffset = { X = 0, Y = 0 },
      SelectedTextOffset = { X = 0, Y = 0 },
    },
    SearchBox = {
      Strip = true,
      Background = { Color = "$BackdropColor", Inset = OUTSIDE_SEARCH },
      Border = { Color = "$BorderColor", EdgeSize = "$EdgeSize", Inset = OUTSIDE_SEARCH },
    },
    Button = {
      Strip = true,
      Background = { Texture = "$GlossTex", VertexColor = "$BackdropColor" },
      Border = { Color = "$BorderColor", EdgeSize = "$EdgeSize" },
      HoverBorderColor = "$ValueColor",
      Highlight = false,
    },
    EditBox = {
      Strip = true,
      Background = { Color = "$BackdropColor" },
      Border = { Color = "$BorderColor", EdgeSize = "$EdgeSize" },
    },
    BagButton = { Portrait = PORTRAIT, Highlight = PORTRAIT },
  },
})
