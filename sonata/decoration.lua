local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class SonataApply: AceModule
local apply = addon:GetModule('SonataApply')

-- SonataDecoration builds a window's chrome from a Sonata window style: a Blizzard frame
-- template, a backdrop, sliced background and border textures, extra textures, a title, and
-- a close button. Applying a style first takes everything the previous one built off the
-- window, so switching themes leaves nothing behind.
--
-- Where things go, so the window's content always draws above its fill: the backdrop is on
-- the window frame itself, the background, border and textures are the window frame's own
-- regions (a frame's regions draw below its child frames), and a template sits one level
-- below the window. Only what a style marks Above, the title and the close button go on the
-- overlay frame, which is above the content and never takes the mouse.
---@class SonataDecoration: AceModule
local decorationModule = addon:NewModule('SonataDecoration')

-- How far above the window the overlay frame sits: above every frame of the window's content.
local OVERLAY_OFFSET = 500

---@class SonataWindowStyle
---@field Insets? {Left?: number, Right?: number, Top?: number, Bottom?: number} The content box.
---@field Template? {Name: string, Level?: number, Levels?: table<string, number>, TitleFont?: SonataFont, Title?: boolean, HideTitleWhenEmpty?: boolean, Opacity?: string}
---@field Backdrop? {BgFile?: string, EdgeFile?: string, EdgeSize?: number, Tile?: boolean, TileEdge?: boolean, TileSize?: number, Insets?: table, Color?: SonataColor, BorderColor?: SonataColor, Opacity?: boolean, Outlines?: table[]}
---@field Background? SonataTexture|{Inset?: table, Points?: SonataPoint[], Opacity?: boolean}
---@field Border? SonataTexture|{Inset?: table, Points?: SonataPoint[], Above?: boolean}
---@field Textures? table[] Named textures: SonataTexture plus Name, Points, Size, Inset, Above, Opacity.
---@field Title? {Font?: SonataFont, Color?: SonataColor, Points?: SonataPoint[], Height?: number, Justify?: string}
---@field CloseButton? {Template?: string, Size?: number|{Width: number, Height: number}, Points?: SonataPoint[], Normal?: SonataTexture, Highlight?: SonataTexture, Pushed?: SonataTexture, Disabled?: SonataTexture, HoverColor?: SonataColor, Text?: string}
---@field Resize? table The resize grip, built by the window.
---@field Animations? table Show and hide animations, built by the window.
---@field Layout? table Geometry for parts the window itself owns (search box, menu button, footer).

---@class (exact) SonataWindowDecoration
---@field window table
---@field frame Frame
---@field overlay Frame
---@field style SonataWindowStyle
---@field templates table<string, Frame>
---@field template? Frame
---@field closeButtons table<string, Button>
---@field closeButton? Button
---@field titleText? FontString
---@field textures table<string, Texture>
---@field pool {under: Texture[], over: Texture[]}
---@field used Texture[]
---@field fading {texture: Texture, alpha: number}[]
---@field capped {texture: Texture, size: table}[]
---@field outlines Frame[]
---@field outlineCount number
local decorationProto = {}
addon:GetModule('Perf'):RegisterPrototype(decorationProto, 'SonataWindowDecoration')

---@param window table
---@return SonataWindowDecoration
function decorationModule:Create(window)
  local frame = window.frame
  local overlay = CreateFrame("Frame", nil, frame)
  overlay:SetAllPoints(frame)
  overlay:EnableMouse(false)
  overlay:SetFrameLevel(frame:GetFrameLevel() + OVERLAY_OFFSET)
  ---@type SonataWindowDecoration
  local deco = setmetatable({
    window = window,
    frame = frame,
    overlay = overlay,
    style = {},
    templates = {},
    closeButtons = {},
    textures = {},
    pool = { under = {}, over = {} },
    used = {},
    fading = {},
    capped = {},
    outlines = {},
    outlineCount = 0,
  }, { __index = decorationProto })
  frame:HookScript("OnSizeChanged", function()
    deco:UpdateCappedSizes()
  end)
  return deco
end

-- Decorate applies style to window, creating the window's decoration on first use.
---@param window table
---@param style SonataWindowStyle
---@param theme SonataTheme
---@return SonataWindowDecoration
function decorationModule:Decorate(window, style, theme)
  local deco = window.decoration
  if deco == nil then
    deco = self:Create(window)
    window.decoration = deco
  end
  deco:Apply(style, theme)
  return deco
end

sonata:SetWindowDecorator(function(window, style, theme)
  return decorationModule:Decorate(window, style, theme)
end)

---@private
function decorationProto:Release()
  if self.template ~= nil then
    self.template:Hide()
    self.template = nil
  end
  if self.frame.SetBackdrop ~= nil then
    self.frame:SetBackdrop(nil)
  end
  for i = 1, self.outlineCount do
    self.outlines[i]:Hide()
  end
  self.outlineCount = 0
  for _, texture in ipairs(self.used) do
    apply:ResetTexture(texture)
    local poolKey = texture:GetParent() == self.overlay and "over" or "under"
    table.insert(self.pool[poolKey], texture)
  end
  self.used = {}
  self.textures = {}
  self.fading = {}
  self.capped = {}
  if self.titleText ~= nil then
    self.titleText:Hide()
  end
  if self.closeButton ~= nil then
    self.closeButton:Hide()
    self.closeButton = nil
  end
end

---@private
---@param above boolean?
---@return Texture
function decorationProto:acquireTexture(above)
  local poolKey = above and "over" or "under"
  local texture = table.remove(self.pool[poolKey])
  if texture == nil then
    local parent = above and self.overlay or self.frame
    texture = parent:CreateTexture()
  end
  table.insert(self.used, texture)
  return texture
end

---@private
---@param name string
---@return Region?
function decorationProto:resolve(name)
  if name == "Window" then
    return self.frame
  elseif name == "Title" then
    return self.titleText
  end
  return self.textures[name]
end

---@private
---@param name string
---@param spec table
---@param defaultLayer DrawLayer
---@param fillDefault boolean Fill the window when the spec gives no points.
---@return Texture
function decorationProto:buildTexture(name, spec, defaultLayer, fillDefault)
  local texture = self:acquireTexture(spec.Above == true)
  local textureSpec = setmetatable({ Layer = spec.Layer or defaultLayer }, { __index = spec })
  apply:Texture(texture, textureSpec)
  if spec.Points ~= nil then
    apply:Points(texture, spec.Points, self.frame, function(n) return self:resolve(n) end)
  elseif spec.Inset ~= nil or fillDefault then
    apply:Inset(texture, self.frame, spec.Inset)
  end
  local size = spec.Size
  if size ~= nil then
    if size.MaxWidth ~= nil then
      table.insert(self.capped, { texture = texture, size = size })
    elseif size.Width ~= nil then
      texture:SetWidth(size.Width)
    end
    if size.Height ~= nil then
      texture:SetHeight(size.Height)
    end
  end
  texture:Show()
  self.textures[name] = texture
  return texture
end

-- UpdateCappedSizes sizes the textures whose width follows the window, up to a maximum.
function decorationProto:UpdateCappedSizes()
  local width = self.frame:GetWidth()
  for _, entry in ipairs(self.capped) do
    local w = width + (entry.size.WidthOffset or 0)
    entry.texture:SetWidth(math.max(0, math.min(entry.size.MaxWidth, w)))
  end
end

---@private
---@param spec table
function decorationProto:applyTemplate(spec)
  local frame = self.templates[spec.Name]
  if frame == nil then
    frame = CreateFrame("Frame", nil, self.frame, spec.Name)
    frame:SetAllPoints(self.frame)
    self.templates[spec.Name] = frame
  end
  local level = self.frame:GetFrameLevel()
  frame:SetFrameLevel(math.max(0, level + (spec.Level or -1)))
  for key, offset in pairs(spec.Levels or {}) do
    if frame[key] ~= nil then
      frame[key]:SetFrameLevel(math.max(0, level + offset))
    end
  end
  if spec.TitleFont ~= nil and frame.GetTitleText ~= nil then
    apply:Font(frame:GetTitleText(), spec.TitleFont)
  end
  frame:Show()
  self.template = frame
end

---@private
---@param spec table
function decorationProto:applyBackdrop(spec)
  if self.frame.SetBackdrop == nil then
    error("a window with a backdrop style must inherit BackdropTemplate")
  end
  local insets = spec.Insets or {}
  self.frame:SetBackdrop({
    bgFile = spec.BgFile,
    edgeFile = spec.EdgeFile,
    edgeSize = spec.EdgeSize,
    tile = spec.Tile,
    tileEdge = spec.TileEdge,
    tileSize = spec.TileSize,
    insets = { left = insets.Left or 0, right = insets.Right or 0, top = insets.Top or 0, bottom = insets.Bottom or 0 },
  })
  self.frame:SetBackdropBorderColor(apply:Color(spec.BorderColor))
  for i, outline in ipairs(spec.Outlines or {}) do
    local f = self.outlines[i]
    if f == nil then
      f = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
      f:EnableMouse(false)
      self.outlines[i] = f
    end
    local offset = outline.Offset or 0
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -offset, offset)
    f:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", offset, -offset)
    f:SetFrameLevel(self.frame:GetFrameLevel())
    f:SetBackdrop({ edgeFile = outline.EdgeFile, edgeSize = outline.EdgeSize or 1 })
    f:SetBackdropBorderColor(apply:Color(outline.Color, { 0, 0, 0, 1 }))
    f:Show()
    self.outlineCount = i
  end
end

---@private
---@param spec table
function decorationProto:applyTitle(spec)
  if self.titleText == nil then
    self.titleText = self.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  end
  local title = self.titleText
  apply:Font(title, spec.Font)
  if spec.Color ~= nil then
    title:SetTextColor(apply:Color(spec.Color))
  end
  apply:Points(title, spec.Points or { { Point = "TOP", Y = -5 } }, self.frame, function(n) return self:resolve(n) end)
  if spec.Height ~= nil then
    title:SetHeight(spec.Height)
  end
  title:SetJustifyH(spec.Justify or "CENTER")
  title:Show()
end

---@private
---@param spec table
function decorationProto:applyCloseButton(spec)
  local key = spec.Template or "plain"
  local button = self.closeButtons[key]
  if button == nil then
    button = CreateFrame("Button", nil, self.frame, spec.Template)
    addon.SetScript(button, "OnClick", function(ctx)
      self.window:OnCloseClicked(ctx)
    end)
    button:HookScript("OnEnter", function(b)
      if b.sonataHoverColor ~= nil then
        b:GetNormalTexture():SetVertexColor(apply:Color(b.sonataHoverColor))
      end
    end)
    button:HookScript("OnLeave", function(b)
      if b.sonataHoverColor ~= nil then
        b:GetNormalTexture():SetVertexColor(apply:Color(b.sonataNormalColor))
      end
    end)
    self.closeButtons[key] = button
  end
  button:SetFrameLevel(self.overlay:GetFrameLevel() + 1)
  local size = spec.Size
  if type(size) == "number" then
    button:SetSize(size, size)
  elseif type(size) == "table" then
    button:SetSize(size.Width, size.Height)
  end
  if spec.Points ~= nil then
    apply:Points(button, spec.Points, self.frame, function(n) return self:resolve(n) end)
  elseif spec.Template == nil then
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)
  end
  apply:ButtonStates(button, spec)
  button.sonataHoverColor = spec.HoverColor
  button.sonataNormalColor = spec.Normal and spec.Normal.VertexColor
  if spec.Text ~= nil then
    button:SetText(spec.Text)
  end
  button:Show()
  self.closeButton = button
end

-- Apply replaces the window's chrome with what style describes.
---@param style SonataWindowStyle
---@param theme? SonataTheme
function decorationProto:Apply(style, theme)
  local _ = theme
  self:Release()
  self.style = style or {}
  self.overlay:SetFrameLevel(self.frame:GetFrameLevel() + OVERLAY_OFFSET)
  local s = self.style

  if s.Template ~= nil and s.Template.Name ~= nil then
    self:applyTemplate(s.Template)
  end
  if s.Backdrop ~= nil then
    self:applyBackdrop(s.Backdrop)
  end
  if s.Background ~= nil then
    local bg = self:buildTexture("Background", s.Background, "BACKGROUND", true)
    if s.Background.Opacity ~= false then
      table.insert(self.fading, { texture = bg, alpha = s.Background.Alpha or 1 })
    end
  end
  if s.Border ~= nil then
    self:buildTexture("Border", s.Border, "BORDER", true)
  end
  if s.Title ~= nil then
    self:applyTitle(s.Title)
  end
  for i, spec in ipairs(s.Textures or {}) do
    local texture = self:buildTexture(spec.Name or ("Texture" .. i), spec, "ARTWORK", false)
    if spec.Opacity == true then
      table.insert(self.fading, { texture = texture, alpha = spec.Alpha or 1 })
    end
  end
  self:UpdateCappedSizes()
  if s.CloseButton ~= nil then
    self:applyCloseButton(s.CloseButton)
  end

  self:SetTitle(self.window:GetTitle() or "")
  self:SetOpacity(self.window:GetOpacity() or 100)
end

---@param text string
function decorationProto:SetTitle(text)
  local tmpl = self.style.Template
  if self.template ~= nil and tmpl ~= nil and tmpl.Title ~= false and self.template.SetTitle ~= nil then
    self.template:SetTitle(text)
    if tmpl.HideTitleWhenEmpty and self.template.TitleContainer ~= nil then
      self.template.TitleContainer:SetShown(text ~= "")
    end
  end
  if self.titleText ~= nil and self.style.Title ~= nil then
    self.titleText:SetText(text)
  end
end

-- SetOpacity fades the window's fill: the template region the style names, the backdrop
-- fill, the background, and textures marked Opacity. Borders keep their alpha.
---@param opacity number 0 to 100.
function decorationProto:SetOpacity(opacity)
  local alpha = opacity / 100
  local tmpl = self.style.Template
  if self.template ~= nil and tmpl ~= nil and tmpl.Opacity ~= nil then
    local region = self.template[tmpl.Opacity]
    if region ~= nil then
      region:SetAlpha(alpha)
    end
  end
  local backdrop = self.style.Backdrop
  if backdrop ~= nil then
    local r, g, b, a = apply:Color(backdrop.Color)
    if backdrop.Opacity ~= false then
      a = a * alpha
    end
    self.frame:SetBackdropColor(r, g, b, a)
  end
  for _, entry in ipairs(self.fading) do
    entry.texture:SetAlpha(entry.alpha * alpha)
  end
end

---@return {Left: number, Right: number, Top: number, Bottom: number}
function decorationProto:GetInsets()
  local i = self.style.Insets or {}
  return { Left = i.Left or 0, Right = i.Right or 0, Top = i.Top or 0, Bottom = i.Bottom or 0 }
end

---@return table
function decorationProto:GetLayout()
  return self.style.Layout or {}
end

---@return SonataWindowStyle
function decorationProto:GetStyle()
  return self.style
end

---@param name string
---@return Texture?
function decorationProto:GetTexture(name)
  return self.textures[name]
end

---@return Frame?
function decorationProto:GetTemplateFrame()
  return self.template
end

---@return Frame
function decorationProto:GetOverlayFrame()
  return self.overlay
end

---@return FontString?
function decorationProto:GetTitleText()
  return self.titleText
end

---@return Button?
function decorationProto:GetCloseButton()
  return self.closeButton
end

---@return Frame[]
function decorationProto:GetOutlineFrames()
  local list = {}
  for i = 1, self.outlineCount do
    table.insert(list, self.outlines[i])
  end
  return list
end
