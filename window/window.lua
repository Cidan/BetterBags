local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class SonataApply: AceModule
local apply = addon:GetModule('SonataApply')

---@class LibWindow-1.1: AceAddon
local LibWindow = LibStub('LibWindow-1.1')

-- Window is the root every BetterBags window is built on (Moonlight's window). A window owns
-- its frame, registers with Sonata for its chrome, places its content in the box the theme's
-- insets leave (plus what the window's own parts reserve), and lays itself out through the
-- render pipeline in one of two modes: sized to its content (the content takes its natural
-- width, its height capped at most of the screen) or at the size the player dragged it to
-- (the content fills the box inside it and reflows, like a browser window).
---@class WindowModule: AceModule
local window = addon:NewModule('Window')

-- How much of the screen's height a window sized to its content may take.
local SCREEN_FRACTION = 0.9

-- The fade every window uses when its theme gives no animations (animations/fade.lua).
local DEFAULT_ANIMATIONS = {
  Show = { { Type = "Alpha", From = 0, To = 1, Duration = 0.10, Smoothing = "IN" } },
  Hide = { { Type = "Alpha", From = 1, To = 0, Duration = 0.10, Smoothing = "IN" } },
}

-- The resize grip when the theme gives none (Interface\ChatFrame size grabber).
local DEFAULT_GRIP = {
  Size = 16,
  Normal = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down" },
  Highlight = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight" },
  Pushed = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" },
}

---@alias WindowSizeMode "content"|"window"

---@class WindowOptions
---@field Name string The frame's global name.
---@field Kind string The Sonata window kind: Bag, Panel, Flat or Dialog.
---@field Title? string
---@field Parent? Frame UIParent when unset.
---@field Strata? FrameStrata
---@field Level? number
---@field Toplevel? boolean
---@field Movable? boolean false: dragging never moves it.
---@field CanMove? fun(): boolean Asked when a drag starts; false leaves the window where it is.
---@field OnMoved? fun() Called after the player moved it.
---@field Position? table A LibWindow-1.1 config table: the position is restored and saved.
---@field Escape? boolean Close with Escape (UISpecialFrames).
---@field Opacity? fun(): number The window's background opacity, 0 to 100.
---@field SizeMode? fun(): WindowSizeMode
---@field Size? fun(): number, number The size the player left it at, for the window mode.
---@field OnResized? fun(width: number, height: number) Called after the player resized it.
---@field MinWidth? number
---@field MinHeight? number
---@field Fade? fun(): boolean false: show and hide at once. Fades when unset.
---@field OnClose? fun(ctx: Context) Called when its close button is clicked, instead of hiding.
---@field Content? Drawable

---@class (exact) BetterBagsWindow: Drawable
---@field frame Frame
---@field content Frame
---@field kind string
---@field title string
---@field decoration? SonataWindowDecoration
---@field contentDrawable? Drawable
---@field extraInsets table
---@field plan RenderPlan
---@field animations table<string, {show: AnimationGroup, hide: AnimationGroup}>
---@field showAnimation? AnimationGroup
---@field hideAnimation? AnimationGroup
---@field resizeGrip? Button
---@field sizing boolean
---@field moving boolean
---@field opts WindowOptions
local windowProto = drawable:Extend({}, 'WindowFrame')

---@param opts WindowOptions
---@return BetterBagsWindow
function window:Create(opts)
  if type(opts) ~= "table" or type(opts.Name) ~= "string" then
    error("a window needs a Name")
  end
  if type(opts.Kind) ~= "string" then
    error("a window needs a Kind")
  end
  ---@type BetterBagsWindow
  local w = drawable:Create(windowProto)
  w.opts = opts
  w.kind = opts.Kind
  w.title = opts.Title or ""
  w.extraInsets = {}
  w.animations = {}
  w.sizing = false
  w.moving = false

  local frame = CreateFrame("Frame", opts.Name, opts.Parent or UIParent, "BackdropTemplate")
  frame:Hide()
  if opts.Strata ~= nil then
    frame:SetFrameStrata(opts.Strata)
  end
  if opts.Level ~= nil then
    frame:SetFrameLevel(opts.Level)
  end
  if opts.Toplevel then
    frame:SetToplevel(true)
  end
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  w.frame = frame

  w.content = CreateFrame("Frame", nil, frame)
  w:UpdateContentAnchors()

  if opts.Movable ~= false then
    w:WatchDrag()
  end
  if opts.Position ~= nil then
    LibWindow.RegisterConfig(frame, opts.Position)
    LibWindow.RestorePosition(frame)
  end
  if opts.Escape then
    table.insert(UISpecialFrames, opts.Name)
  end

  frame:HookScript("OnSizeChanged", function()
    if w:GetSizeMode() == "window" then
      render:Invalidate(w)
    end
  end)

  if opts.Content ~= nil then
    w:SetContent(opts.Content)
  else
    w:updatePlan()
  end
  sonata:RegisterWindow(w, opts.Kind)
  return w
end

---@private
function windowProto:updatePlan()
  if self.contentDrawable == nil then
    self.plan = { Plan = { { step = render.SELF } } }
    return
  end
  self.plan = {
    Plan = {
      { step = render.PRE },
      { step = render.DEP, target = self.contentDrawable },
      { step = render.SELF },
    }
  }
end

-- WatchDrag makes the window move when dragged and saves where it was dropped.
function windowProto:WatchDrag()
  local frame = self.frame
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(f)
    if self.opts.CanMove ~= nil and not self.opts.CanMove() then
      return
    end
    self.moving = true
    f:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(f)
    if not self.moving then
      return
    end
    self.moving = false
    f:StopMovingOrSizing()
    if self.opts.Position ~= nil then
      LibWindow.SavePosition(f)
    end
    if self.opts.OnMoved ~= nil then
      self.opts.OnMoved()
    end
  end)
end

---@param content Drawable
function windowProto:SetContent(content)
  self.contentDrawable = content
  content:SetParent(self.content)
  content:ClearAllPoints()
  content.frame:SetAllPoints(self.content)
  self:updatePlan()
end

---@return Drawable?
function windowProto:GetContent()
  return self.contentDrawable
end

---@return WindowSizeMode
function windowProto:GetSizeMode()
  if self.opts.SizeMode ~= nil then
    return self.opts.SizeMode()
  end
  return "content"
end

-- GetContentInsets returns the box the content goes in: the theme's insets plus what the
-- window's own parts reserve (SetExtraInsets).
---@return {Left: number, Right: number, Top: number, Bottom: number}
function windowProto:GetContentInsets()
  local i = self.decoration and self.decoration:GetInsets() or { Left = 0, Right = 0, Top = 0, Bottom = 0 }
  local e = self.extraInsets
  return {
    Left = i.Left + (e.Left or 0),
    Right = i.Right + (e.Right or 0),
    Top = i.Top + (e.Top or 0),
    Bottom = i.Bottom + (e.Bottom or 0),
  }
end

-- SetExtraInsets reserves room at the window's edges for its own parts (a search box, a
-- footer), inside the theme's insets.
---@param insets {Left?: number, Right?: number, Top?: number, Bottom?: number}
function windowProto:SetExtraInsets(insets)
  self.extraInsets = insets or {}
  self:UpdateContentAnchors()
  self:Invalidate()
end

function windowProto:UpdateContentAnchors()
  apply:Inset(self.content, self.frame, self:GetContentInsets())
end

---@return table
function windowProto:GetLayout()
  return self.decoration and self.decoration:GetLayout() or {}
end

---@return string
function windowProto:GetTitle()
  return self.title
end

---@param text string
function windowProto:SetTitle(text)
  self.title = text or ""
  if self.decoration ~= nil then
    self.decoration:SetTitle(self.title)
  end
end

---@return number
function windowProto:GetOpacity()
  if self.opts.Opacity ~= nil then
    return self.opts.Opacity()
  end
  return 100
end

function windowProto:UpdateOpacity()
  if self.decoration ~= nil then
    self.decoration:SetOpacity(self:GetOpacity())
  end
end

---@param ctx Context
function windowProto:OnCloseClicked(ctx)
  if self.opts.OnClose ~= nil then
    self.opts.OnClose(ctx)
    return
  end
  self:Hide()
end

-- OnDecorated runs after Sonata applied a theme to the window: the content moves to the new
-- insets, the grip and animations follow the theme, and the window lays out again.
---@param decoration SonataWindowDecoration
function windowProto:OnDecorated(decoration)
  self.decoration = decoration
  self:UpdateContentAnchors()
  self:buildAnimations()
  self:UpdateSizeMode()
  self:Invalidate()
end

---@private
---@param group AnimationGroup
---@param specs table[]
---@return number? fromAlpha The alpha the first fade starts at.
local function addAnimations(group, specs)
  local fromAlpha
  for _, spec in ipairs(specs) do
    local anim = group:CreateAnimation(spec.Type)
    anim:SetDuration(spec.Duration or 0.1)
    if spec.Smoothing ~= nil then
      anim:SetSmoothing(spec.Smoothing)
    end
    if spec.Delay ~= nil then
      anim:SetStartDelay(spec.Delay)
    end
    if spec.Type == "Alpha" then
      anim:SetFromAlpha(spec.From or 0)
      anim:SetToAlpha(spec.To or 1)
      if fromAlpha == nil then
        fromAlpha = spec.From or 0
      end
    elseif spec.Type == "Translation" then
      anim:SetOffset(spec.X or 0, spec.Y or 0)
    elseif spec.Type == "Scale" then
      local from, to = spec.From or { 1, 1 }, spec.To or { 1, 1 }
      anim:SetScaleFrom(from[1], from[2])
      anim:SetScaleTo(to[1], to[2])
      if spec.Origin ~= nil then
        anim:SetOrigin(spec.Origin.Point or "CENTER", spec.Origin.X or 0, spec.Origin.Y or 0)
      end
    end
  end
  return fromAlpha
end

---@param group AnimationGroup
local function runCallback(group)
  local callback = group.callback
  group.callback = nil
  if callback ~= nil then
    callback()
  end
end

---@private
function windowProto:buildAnimations()
  local key = sonata:GetCurrentThemeKey() or ""
  local built = self.animations[key]
  if built == nil then
    local specs = self.decoration and self.decoration:GetStyle().Animations or DEFAULT_ANIMATIONS
    local frame = self.frame
    local show = frame:CreateAnimationGroup()
    local fromAlpha = addAnimations(show, specs.Show or DEFAULT_ANIMATIONS.Show)
    show:SetScript("OnPlay", function()
      if fromAlpha ~= nil then
        frame:SetAlpha(fromAlpha)
      end
      frame:Show()
    end)
    show:SetScript("OnFinished", function(group)
      frame:SetAlpha(1)
      frame:Show()
      runCallback(group)
    end)
    local hide = frame:CreateAnimationGroup()
    addAnimations(hide, specs.Hide or DEFAULT_ANIMATIONS.Hide)
    hide:SetScript("OnFinished", function(group)
      frame:Hide()
      runCallback(group)
    end)
    built = { show = show, hide = hide }
    self.animations[key] = built
  end
  self.showAnimation = built.show
  self.hideAnimation = built.hide
end

---@return boolean
function windowProto:fades()
  return self.opts.Fade == nil or self.opts.Fade()
end

-- Show shows the window (fading in unless its owner turned fading off) and renders it when it
-- was invalidated while hidden. callback runs once it is fully shown.
---@param callback? fun()
function windowProto:Show(callback)
  if self.hideAnimation ~= nil and self.hideAnimation:IsPlaying() then
    self.hideAnimation:Stop()
  end
  if self:fades() and self.showAnimation ~= nil then
    self.showAnimation.callback = callback
    self.showAnimation:Play()
  else
    self.frame:SetAlpha(1)
    self.frame:Show()
    if callback ~= nil then
      callback()
    end
  end
  if self.renderPending then
    self.renderPending = nil
    render:NewRenderChain(self, {})
  end
end

-- Hide hides the window, fading out unless its owner turned fading off. callback runs once it
-- is hidden.
---@param callback? fun()
function windowProto:Hide(callback)
  if self.showAnimation ~= nil and self.showAnimation:IsPlaying() then
    self.showAnimation:Stop()
  end
  if self:fades() and self.hideAnimation ~= nil then
    self.hideAnimation.callback = callback
    self.hideAnimation:Play()
  else
    self.frame:Hide()
    if callback ~= nil then
      callback()
    end
  end
end

function windowProto:Toggle()
  if self:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

---@return boolean
function windowProto:IsShown()
  return self.frame:IsShown()
end

---@return boolean
function windowProto:ShouldRender()
  return self.frame:IsShown()
end

-- UpdateSizeMode applies the owner's size mode: a window the player sizes takes its saved
-- size, can be resized and shows its grip; a window sized to its content cannot.
function windowProto:UpdateSizeMode()
  local frame = self.frame
  if self:GetSizeMode() == "window" then
    frame:SetResizable(true)
    frame:SetResizeBounds(self.opts.MinWidth or 1, self.opts.MinHeight or 1)
    if self.opts.Size ~= nil then
      local width, height = self.opts.Size()
      if width ~= nil and height ~= nil then
        frame:SetSize(width, height)
      end
    end
    self:styleResizeGrip()
    self.resizeGrip:Show()
  else
    frame:SetResizable(false)
    if self.resizeGrip ~= nil then
      self.resizeGrip:Hide()
    end
  end
end

---@private
function windowProto:styleResizeGrip()
  local grip = self.resizeGrip
  if grip == nil then
    grip = CreateFrame("Button", nil, self.frame)
    grip:EnableMouse(true)
    grip:SetScript("OnMouseDown", function()
      self.sizing = true
      self.frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
      self.sizing = false
      self.frame:StopMovingOrSizing()
      if self.opts.OnResized ~= nil then
        self.opts.OnResized(self.frame:GetWidth(), self.frame:GetHeight())
      end
      self:Invalidate()
    end)
    self.resizeGrip = grip
  end
  local style = self.decoration and self.decoration:GetStyle().Resize or DEFAULT_GRIP
  local size = style.Size or DEFAULT_GRIP.Size
  grip:SetSize(size, size)
  local overlay = self.decoration and self.decoration:GetOverlayFrame()
  grip:SetFrameLevel((overlay and overlay:GetFrameLevel() or self.frame:GetFrameLevel()) + 2)
  apply:Points(grip, style.Points or { { Point = "BOTTOMRIGHT" } }, self.frame)
  apply:ButtonStates(grip, {
    Normal = style.Normal or DEFAULT_GRIP.Normal,
    Highlight = style.Highlight or DEFAULT_GRIP.Highlight,
    Pushed = style.Pushed or DEFAULT_GRIP.Pushed,
  })
end

---@return RenderPlan
function windowProto:GetRenderPlan()
  return self.plan
end

---@return RenderResult
function windowProto:PreRender()
  local insets = self:GetContentInsets()
  local vertical = insets.Top + insets.Bottom
  if self:GetSizeMode() == "window" then
    return {
      Width = math.max(0, self.frame:GetWidth() - insets.Left - insets.Right),
      Height = math.max(0, self.frame:GetHeight() - vertical),
    }
  end
  return {
    MaxHeight = math.max(0, UIParent:GetHeight() * SCREEN_FRACTION - vertical),
  }
end

---@param _ RenderResult?
---@param _ RenderChainOptions
---@param results RenderResults
---@return RenderResult
function windowProto:Render(_, _, results)
  local frame = self.frame
  if self.contentDrawable ~= nil and self:GetSizeMode() == "content" then
    local result = results.Results[self.contentDrawable]
    if result == nil then
      error("a window's content returned no render result")
    end
    local insets = self:GetContentInsets()
    local width = math.max(self.opts.MinWidth or 0, (result.Width or 0) + insets.Left + insets.Right)
    local height = math.max(self.opts.MinHeight or 0, (result.Height or 0) + insets.Top + insets.Bottom)
    frame:SetSize(width, height)
  end
  return { Width = frame:GetWidth(), Height = frame:GetHeight() }
end
