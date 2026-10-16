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
-- window and gives templates and close buttons back the state they were created with, so
-- switching themes leaves nothing behind.
--
-- Where things go, so the window's content always draws above its fill: the backdrop is on
-- the window frame itself, the background, border and textures are the window frame's own
-- regions (a frame's regions draw below its child frames), and a template sits below the
-- window. What a style marks Above, the title and the close button go on the overlay frame,
-- which is above the content and never takes the mouse. Templates never take the mouse
-- either: the window frame is the drop target for everything under the content.
---@class SonataDecoration: AceModule
local decorationModule = addon:NewModule('SonataDecoration')

-- How far above the window the overlay frame sits: above every frame of the window's content.
local OVERLAY_OFFSET = 500

-- The size of a close button without a template, when the style gives none (Blizzard's).
local CLOSE_SIZE = 24

local BUTTON_STATES = {
  { key = "Normal", get = "GetNormalTexture", setTexture = "SetNormalTexture", setAtlas = "SetNormalAtlas", clear = "ClearNormalTexture" },
  { key = "Highlight", get = "GetHighlightTexture", setTexture = "SetHighlightTexture", setAtlas = "SetHighlightAtlas", clear = "ClearHighlightTexture" },
  { key = "Pushed", get = "GetPushedTexture", setTexture = "SetPushedTexture", setAtlas = "SetPushedAtlas", clear = "ClearPushedTexture" },
  { key = "Disabled", get = "GetDisabledTexture", setTexture = "SetDisabledTexture", setAtlas = "SetDisabledAtlas", clear = "ClearDisabledTexture" },
}

---@class SonataWindowStyle
---@field Insets? {Left?: number, Right?: number, Top?: number, Bottom?: number} The content box.
---@field Template? {Name: string, Level?: number, Levels?: table<string, number>, TitleFont?: SonataFont, Title?: boolean, HideTitleWhenEmpty?: boolean, Opacity?: string, Hide?: string[]}
---@field Backdrop? {BgFile?: string, EdgeFile?: string, EdgeSize?: number, Tile?: boolean, TileEdge?: boolean, TileSize?: number, Insets?: table, Color?: SonataColor, BorderColor?: SonataColor, Opacity?: boolean, BorderOpacity?: boolean, Outlines?: table[]}
---@field Background? SonataTexture|{Inset?: table, Points?: SonataPoint[], Opacity?: boolean}
---@field Border? SonataTexture|{Inset?: table, Points?: SonataPoint[], Above?: boolean}
---@field Textures? table[] Named textures: SonataTexture plus Name, Points, Size, Inset, Above, Opacity.
---@field Title? {Font?: SonataFont, Color?: SonataColor, Points?: SonataPoint[], Height?: number, Justify?: string}
---@field CloseButton? {Template?: string, Size?: number|{Width: number, Height: number}, Points?: SonataPoint[], Normal?: SonataTexture, Highlight?: SonataTexture, Pushed?: SonataTexture, Disabled?: SonataTexture, HoverColor?: SonataColor, Text?: string, HitRectInsets?: number[]}
---@field Resize? table The resize grip, built by the window.
---@field Animations? table Show and hide animations, built by the window.
---@field Layout? table Geometry for parts the window itself owns (search box, menu button, footer).

---@class (exact) SonataTemplateRecord
---@field frame Frame
---@field offsets table<Frame, number> Each child frame's level relative to the template when it was made.
---@field titleFont? FontObject The template title's own font object.
---@field changed {alpha: table<Region, number>, shown: table<Region, boolean>, titleFont: boolean}

---@class (exact) SonataWindowDecoration
---@field window table
---@field frame Frame
---@field overlay Frame
---@field style SonataWindowStyle
---@field templates table<string, SonataTemplateRecord>
---@field template? Frame
---@field templateRecord? SonataTemplateRecord
---@field closeButtons table<string, Button>
---@field closeSnapshots table<Button, table>
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

---@param value any
---@return table?
local function spec(value)
  if type(value) == "table" then
    return value
  end
  return nil
end

-- snapshotButton records what a button looks like, to give it back on a theme switch.
---@param button Button
---@return table
local function snapshotButton(button)
  local points = {}
  for i = 1, button:GetNumPoints() do
    points[i] = { button:GetPoint(i) }
  end
  local states = {}
  for _, state in ipairs(BUTTON_STATES) do
    local region = button[state.get](button)
    if region ~= nil then
      states[state.key] = {
        texture = region:GetTexture(),
        atlas = region:GetAtlas(),
        coords = { region:GetTexCoord() },
        color = { region:GetVertexColor() },
        blend = region:GetBlendMode(),
        alpha = region:GetAlpha(),
      }
    end
  end
  return {
    points = points,
    width = button:GetWidth(),
    height = button:GetHeight(),
    text = button:GetText() or "",
    hit = { button:GetHitRectInsets() },
    states = states,
  }
end

---@param button Button
---@param snap table
local function restoreButton(button, snap)
  button:ClearAllPoints()
  for _, p in ipairs(snap.points) do
    button:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
  button:SetSize(snap.width, snap.height)
  button:SetText(snap.text)
  button:SetHitRectInsets(snap.hit[1] or 0, snap.hit[2] or 0, snap.hit[3] or 0, snap.hit[4] or 0)
  for _, state in ipairs(BUTTON_STATES) do
    local saved = snap.states[state.key]
    if saved == nil or (saved.atlas == nil and saved.texture == nil) then
      button[state.clear](button)
    else
      if saved.atlas ~= nil then
        button[state.setAtlas](button, saved.atlas)
      else
        button[state.setTexture](button, saved.texture)
      end
      local region = button[state.get](button)
      if saved.atlas == nil then
        region:SetTexCoord(unpack(saved.coords))
      end
      region:SetVertexColor(unpack(saved.color))
      region:SetBlendMode(saved.blend)
      region:SetAlpha(saved.alpha)
      region:ClearAllPoints()
      region:SetAllPoints(button)
    end
  end
end

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
    closeSnapshots = {},
    textures = {},
    pool = { under = {}, over = {} },
    used = {},
    fading = {},
    capped = {},
    outlines = {},
    outlineCount = 0,
  }, { __index = decorationProto })
  -- The overlay fills the window, so its size follows the window's, and a script the window's
  -- owner sets on the window frame cannot remove this.
  addon.HookScript(overlay, "OnSizeChanged", function()
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
function decorationProto:releaseTemplate()
  local record = self.templateRecord
  if record == nil then
    return
  end
  local frame = record.frame
  for region, alpha in pairs(record.changed.alpha) do
    region:SetAlpha(alpha)
  end
  for region, shown in pairs(record.changed.shown) do
    region:SetShown(shown)
  end
  if record.changed.titleFont and record.titleFont ~= nil then
    apply:Font(frame:GetTitleText(), { Object = record.titleFont })
  end
  record.changed = { alpha = {}, shown = {}, titleFont = false }
  frame:Hide()
  self.template = nil
  self.templateRecord = nil
end

---@private
function decorationProto:releaseTitle()
  local title = self.titleText
  if title == nil then
    return
  end
  title:Hide()
  title:ClearAllPoints()
  title:SetText("")
  title:SetHeight(0)
  apply:Font(title, { Object = "GameFontNormal" })
  title:SetJustifyH("CENTER")
end

---@private
function decorationProto:Release()
  self:releaseTemplate()
  if self.frame.SetBackdrop ~= nil then
    self.frame:SetBackdrop(nil)
  end
  for i = 1, self.outlineCount do
    self.outlines[i]:SetBackdrop(nil)
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
  self:releaseTitle()
  if self.closeButton ~= nil then
    local button = self.closeButton
    button:Hide()
    restoreButton(button, self.closeSnapshots[button])
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
    if spec(self.style.Title) ~= nil then
      return self.titleText
    end
    return nil
  end
  return self.textures[name]
end

---@private
---@param name string
---@param textureSpec table
---@param defaultLayer DrawLayer
---@param fillDefault boolean Fill the window when the spec gives no points.
---@return Texture
function decorationProto:buildTexture(name, textureSpec, defaultLayer, fillDefault)
  local texture = self:acquireTexture(textureSpec.Above == true)
  apply:Texture(texture, setmetatable({ Layer = textureSpec.Layer or defaultLayer }, { __index = textureSpec }))
  if textureSpec.Points ~= nil then
    apply:Points(texture, textureSpec.Points, self.frame, function(n) return self:resolve(n) end)
  elseif textureSpec.Inset ~= nil or fillDefault then
    apply:Inset(texture, self.frame, textureSpec.Inset)
  end
  local size = textureSpec.Size
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
---@param name string
---@return SonataTemplateRecord
function decorationProto:templateRecordFor(name)
  local record = self.templates[name]
  if record ~= nil then
    return record
  end
  local frame = CreateFrame("Frame", nil, self.frame, name)
  frame:SetAllPoints(self.frame)
  frame:EnableMouse(false)
  local offsets = {}
  for _, child in ipairs({ frame:GetChildren() }) do
    offsets[child] = child:GetFrameLevel() - frame:GetFrameLevel()
    if not child:IsObjectType("Button") then
      child:EnableMouse(false)
    end
  end
  record = {
    frame = frame,
    offsets = offsets,
    titleFont = frame.GetTitleText ~= nil and frame:GetTitleText():GetFontObject() or nil,
    changed = { alpha = {}, shown = {}, titleFont = false },
  }
  self.templates[name] = record
  return record
end

---@private
---@param templateSpec table
function decorationProto:applyTemplate(templateSpec)
  local record = self:templateRecordFor(templateSpec.Name)
  local frame = record.frame
  local level = self.frame:GetFrameLevel()
  local templateLevel = math.max(0, level + (templateSpec.Level or -1))
  frame:SetFrameLevel(templateLevel)
  -- A child pushed below level 0 by moving its parent jumps to the top level (10000), so
  -- every child is put back where it sat relative to the template.
  for child, offset in pairs(record.offsets) do
    child:SetFrameLevel(math.max(0, templateLevel + offset))
  end
  for key, offset in pairs(templateSpec.Levels or {}) do
    local child = frame[key]
    if type(child) ~= "table" or child.IsObjectType == nil or not child:IsObjectType("Frame") then
      error("template " .. templateSpec.Name .. " has no frame named " .. tostring(key) .. " to set a level for")
    end
    child:SetFrameLevel(math.max(0, level + offset))
  end
  if templateSpec.TitleFont ~= nil and frame.GetTitleText ~= nil then
    apply:Font(frame:GetTitleText(), templateSpec.TitleFont)
    record.changed.titleFont = true
  end
  for _, key in ipairs(templateSpec.Hide or {}) do
    local region = frame[key]
    if region == nil then
      error("template " .. templateSpec.Name .. " has nothing named " .. tostring(key) .. " to hide")
    end
    if record.changed.shown[region] == nil then
      record.changed.shown[region] = region:IsShown()
    end
    region:Hide()
  end
  frame:Show()
  self.template = frame
  self.templateRecord = record
end

---@private
---@param backdropSpec table
function decorationProto:applyBackdrop(backdropSpec)
  if self.frame.SetBackdrop == nil then
    error("a window with a backdrop style must inherit BackdropTemplate")
  end
  local insets = backdropSpec.Insets or {}
  self.frame:SetBackdrop({
    bgFile = backdropSpec.BgFile,
    edgeFile = backdropSpec.EdgeFile,
    edgeSize = backdropSpec.EdgeSize,
    tile = backdropSpec.Tile,
    tileEdge = backdropSpec.TileEdge,
    tileSize = backdropSpec.TileSize,
    insets = { left = insets.Left or 0, right = insets.Right or 0, top = insets.Top or 0, bottom = insets.Bottom or 0 },
  })
  self.frame:SetBackdropBorderColor(apply:Color(backdropSpec.BorderColor))
  for i, outline in ipairs(backdropSpec.Outlines or {}) do
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
    f:SetBackdrop({ edgeFile = outline.EdgeFile or "Interface\\Buttons\\WHITE8X8", edgeSize = outline.EdgeSize or 1 })
    f:SetBackdropBorderColor(apply:Color(outline.Color, { 0, 0, 0, 1 }))
    f:Show()
    self.outlineCount = i
  end
end

---@private
---@param titleSpec table
function decorationProto:prepareTitle(titleSpec)
  if self.titleText == nil then
    self.titleText = self.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  end
  local title = self.titleText
  apply:Font(title, titleSpec.Font)
  if titleSpec.Color ~= nil then
    title:SetTextColor(apply:Color(titleSpec.Color))
  end
  if titleSpec.Height ~= nil then
    title:SetHeight(titleSpec.Height)
  end
  title:SetJustifyH(titleSpec.Justify or (titleSpec.Font and titleSpec.Font.Justify) or "CENTER")
end

---@private
---@param titleSpec table
function decorationProto:anchorTitle(titleSpec)
  apply:Points(self.titleText, titleSpec.Points or { { Point = "TOP", Y = -5 } }, self.frame,
    function(n) return self:resolve(n) end)
  self.titleText:Show()
end

---@private
---@param closeSpec table
function decorationProto:applyCloseButton(closeSpec)
  local key = closeSpec.Template or "plain"
  local button = self.closeButtons[key]
  if button == nil then
    button = CreateFrame("Button", nil, self.overlay, closeSpec.Template)
    addon.SetScript(button, "OnClick", function(ctx)
      self.window:OnCloseClicked(ctx)
    end)
    addon.HookScript(button, "OnEnter", function(_, b)
      if b.sonataHoverColor ~= nil then
        b:GetNormalTexture():SetVertexColor(apply:Color(b.sonataHoverColor))
      end
    end)
    addon.HookScript(button, "OnLeave", function(_, b)
      if b.sonataHoverColor ~= nil then
        b:GetNormalTexture():SetVertexColor(apply:Color(b.sonataNormalColor))
      end
    end)
    self.closeButtons[key] = button
    self.closeSnapshots[button] = snapshotButton(button)
  end
  button:SetFrameLevel(self.overlay:GetFrameLevel() + 1)
  local size = closeSpec.Size
  if type(size) == "number" then
    button:SetSize(size, size)
  elseif type(size) == "table" then
    button:SetSize(size.Width, size.Height)
  elseif closeSpec.Template == nil then
    button:SetSize(CLOSE_SIZE, CLOSE_SIZE)
  end
  if closeSpec.Points ~= nil then
    apply:Points(button, closeSpec.Points, self.frame, function(n) return self:resolve(n) end)
  elseif closeSpec.Template == nil then
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)
  end
  apply:ButtonStates(button, closeSpec)
  local normal = spec(closeSpec.Normal)
  button.sonataHoverColor = closeSpec.HoverColor
  button.sonataNormalColor = normal and (normal.Color or normal.VertexColor) or nil
  if closeSpec.Text ~= nil then
    button:SetText(closeSpec.Text)
  end
  local hit = closeSpec.HitRectInsets
  if hit ~= nil then
    button:SetHitRectInsets(hit[1] or 0, hit[2] or 0, hit[3] or 0, hit[4] or 0)
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

  local templateSpec = spec(s.Template)
  if templateSpec ~= nil and templateSpec.Name ~= nil then
    self:applyTemplate(templateSpec)
  end
  local backdropSpec = spec(s.Backdrop)
  if backdropSpec ~= nil then
    self:applyBackdrop(backdropSpec)
  end
  local titleSpec = spec(s.Title)
  if titleSpec ~= nil then
    self:prepareTitle(titleSpec)
  end
  local backgroundSpec = spec(s.Background)
  if backgroundSpec ~= nil then
    local bg = self:buildTexture("Background", backgroundSpec, "BACKGROUND", true)
    if backgroundSpec.Opacity ~= false then
      table.insert(self.fading, { texture = bg, alpha = backgroundSpec.Alpha or 1 })
    end
  end
  local borderSpec = spec(s.Border)
  if borderSpec ~= nil then
    self:buildTexture("Border", borderSpec, "BORDER", true)
  end
  for i, textureSpec in ipairs(spec(s.Textures) or {}) do
    local texture = self:buildTexture(textureSpec.Name or ("Texture" .. i), textureSpec, "ARTWORK", false)
    if textureSpec.Opacity == true then
      table.insert(self.fading, { texture = texture, alpha = textureSpec.Alpha or 1 })
    end
  end
  if titleSpec ~= nil then
    self:anchorTitle(titleSpec)
  end
  self:UpdateCappedSizes()
  local closeSpec = spec(s.CloseButton)
  if closeSpec ~= nil then
    self:applyCloseButton(closeSpec)
  end

  self:SetTitle(self.window:GetTitle() or "")
  self:SetOpacity(self.window:GetOpacity() or 100)
  if self.window.OnDecorated ~= nil then
    self.window:OnDecorated(self)
  end
end

---@param text string
function decorationProto:SetTitle(text)
  local tmpl = spec(self.style.Template)
  local record = self.templateRecord
  if self.template ~= nil and tmpl ~= nil and self.template.SetTitle ~= nil then
    if tmpl.Title == false then
      self.template:SetTitle("")
    else
      self.template:SetTitle(text)
    end
    local container = self.template.TitleContainer
    if tmpl.HideTitleWhenEmpty and container ~= nil then
      if record.changed.shown[container] == nil then
        record.changed.shown[container] = container:IsShown()
      end
      container:SetShown(text ~= "")
    end
  end
  if self.titleText ~= nil and spec(self.style.Title) ~= nil then
    self.titleText:SetText(text)
  end
end

-- SetOpacity fades the window's fill: the template region the style names, the backdrop
-- fill (and its border when the style says so), the background, and textures marked
-- Opacity. Other borders keep their alpha.
---@param opacity number 0 to 100.
function decorationProto:SetOpacity(opacity)
  local alpha = opacity / 100
  local tmpl = spec(self.style.Template)
  if self.template ~= nil and tmpl ~= nil and tmpl.Opacity ~= nil then
    local region = self.template[tmpl.Opacity]
    if region ~= nil then
      local record = self.templateRecord
      if record.changed.alpha[region] == nil then
        record.changed.alpha[region] = region:GetAlpha()
      end
      region:SetAlpha(alpha)
    end
  end
  local backdrop = spec(self.style.Backdrop)
  if backdrop ~= nil then
    local r, g, b, a = apply:Color(backdrop.Color)
    if backdrop.Opacity ~= false then
      a = a * alpha
    end
    self.frame:SetBackdropColor(r, g, b, a)
    if backdrop.BorderOpacity == true then
      local br, bg, bb, ba = apply:Color(backdrop.BorderColor)
      self.frame:SetBackdropBorderColor(br, bg, bb, ba * alpha)
    end
  end
  for _, entry in ipairs(self.fading) do
    entry.texture:SetAlpha(entry.alpha * alpha)
  end
end

---@return {Left: number, Right: number, Top: number, Bottom: number}
function decorationProto:GetInsets()
  local i = spec(self.style.Insets) or {}
  return { Left = i.Left or 0, Right = i.Right or 0, Top = i.Top or 0, Bottom = i.Bottom or 0 }
end

---@return table
function decorationProto:GetLayout()
  return spec(self.style.Layout) or {}
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
