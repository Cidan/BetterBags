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

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Perf: AceModule
local perf = addon:GetModule('Perf')

---@class LibWindow-1.1: AceAddon
local LibWindow = LibStub('LibWindow-1.1')

-- Window is the root every BetterBags window is built on (Moonlight's window). A window owns
-- its frame, registers with Sonata for its chrome, places its content in the box the theme's
-- insets leave (plus what the window's own parts reserve), and lays itself out through the
-- render pipeline in one of two modes: sized to its content (the content takes its natural
-- width, its height capped at most of the screen) or at the size the player dragged it to
-- (the content fills the inner box and reflows, like a browser window).
--
-- The window sets the frame's drag and size scripts itself. Owners hook the frame's other
-- scripts, or set ones the window does not use (the bag sets OnReceiveDrag and OnMouseUp),
-- and never set OnDragStart, OnDragStop, OnSizeChanged, OnShow or OnHide.
---@class WindowModule: AceModule
local window = addon:NewModule('Window')

-- How much of the screen's height a window sized to its content may take.
local SCREEN_FRACTION = 0.9

-- The resize grip without a theme's: Blizzard's chat size grabber, shown while hovered.
local DEFAULT_GRIP = {
  Size = 16,
  ShowOnHover = true,
  Normal = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down" },
  Highlight = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight" },
  Pushed = { Texture = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" },
}

---@alias WindowSizeMode "content"|"window"

---@class WindowOptions
---@field Kind string The Sonata window kind: Bag, Panel, Flat, Dialog, Slots or Search.
---@field Name? string The frame's global name; needed to close with Escape.
---@field Title? string
---@field Parent? Frame UIParent when unset.
---@field Strata? FrameStrata
---@field Level? number
---@field Toplevel? boolean
---@field Movable? boolean false: dragging never moves it.
---@field CanMove? fun(ctx: Context): boolean Asked when a drag starts; false leaves the window where it is.
---@field OnMoveStart? fun(ctx: Context) Called before the window starts moving.
---@field OnMoved? fun(ctx: Context) Called after the player moved it.
---@field Position? table A LibWindow-1.1 config table: the position is restored and saved.
---@field Points? {Point: FramePoint, RelativeTo?: Region, RelativePoint?: FramePoint, X?: number, Y?: number}[] Where it sits without a saved position (the center of its parent when unset).
---@field Escape? boolean Close with Escape (UISpecialFrames).
---@field Opacity? fun(): number The window's background opacity, 0 to 100.
---@field Scale? fun(): number The window's scale (1 is 100%).
---@field SizeMode? fun(): WindowSizeMode
---@field Size? fun(): number?, number? The size the player left it at, for the window mode.
---@field Resizable? boolean false: in the window mode it keeps its size and has no grip.
---@field OnResized? fun(ctx: Context, width: number, height: number) Called after the player resized it.
---@field MinWidth? number|false|fun(): number The window's minimum width.
---@field MinHeight? number|false|fun(): number The window's minimum height.
---@field MinContentWidth? number|fun(): number The content box's minimum width.
---@field MinContentHeight? number|fun(): number The content box's minimum height.
---@field Fade? fun(): boolean false: show and hide at once. Fades when unset.
---@field OnClose? fun(ctx: Context, button: string?) Called when its close button is clicked, instead of hiding.
---@field CloseClicks? string[] The clicks its close button takes (RegisterForClicks); LeftButtonUp when unset.
---@field OnRendered? fun(ctx: Context?, width: number, height: number) Called after every render, with the size the window took.
---@field OnDecorated? fun(ctx: Context, decoration: SonataWindowDecoration) Called after every theme the window was decorated with, once its content moved: for parts the owner places from the theme's layout.
---@field OnShow? fun(ctx: Context) Called whenever the frame shows, however it was shown.
---@field OnHide? fun(ctx: Context) Called whenever the frame hides, however it was hidden (Escape included).
---@field Content? Drawable

---@class (exact) WindowAnimations
---@field show? AnimationGroup
---@field hide? AnimationGroup
---@field fromAlpha number The alpha the show animation starts at.

---@class (exact) BetterBagsWindow: Drawable
---@field frame Frame
---@field content Frame
---@field kind string
---@field title string
---@field decoration? SonataWindowDecoration
---@field contentDrawable? Drawable
---@field extraInsets table
---@field plan RenderPlan
---@field animations table<string, WindowAnimations>
---@field showAnimation? AnimationGroup
---@field hideAnimation? AnimationGroup
---@field fromAlpha number
---@field resizeGrip? Button
---@field gripHover boolean
---@field moving boolean
---@field sizing? boolean The player is sizing it (between the grip's mouse down and up).
---@field opts WindowOptions
local windowProto = drawable:Extend({}, 'WindowFrame')

---@param value number|false|nil|fun(): number
---@return number?
local function numberOf(value)
  if type(value) == "function" then
    return value()
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

-- Init fits every window to the screen again whenever the screen's size in UI units changes.
function window:Init()
  self.windows = self.windows or setmetatable({}, { __mode = "k" })
  ---@class Events: AceModule
  local events = addon:GetModule('Events')
  for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    events:RegisterEvent(event, function()
      for w in pairs(self.windows) do
        w:FitToScreen()
        w:KeepOnScreen()
        w:Invalidate()
      end
    end)
  end
end

-- recording returns the render recorder (debug/renderrecorder.lua) while it records.
---@return RenderRecorder?
local function recording()
  local recorder = addon:GetModule('RenderRecorder', true)
  if recorder ~= nil and recorder.recording then
    return recorder
  end
  return nil
end

-- trace describes the window at a step of a resize or a move, to a running profiler capture
-- (the call trace records Geometry's return value) and to the render recorder.
---@param w BetterBagsWindow
---@param step string
local function trace(w, step)
  if perf.active then
    w:Geometry(step)
  end
  local recorder = recording()
  if recorder ~= nil then
    recorder:WindowStep(w, step)
  end
end

---@param opts WindowOptions
---@return BetterBagsWindow
function window:Create(opts)
  if type(opts) ~= "table" or type(opts.Kind) ~= "string" then
    error("a window needs a Kind")
  end
  if opts.Escape and type(opts.Name) ~= "string" then
    error("a window that closes with Escape needs a Name")
  end
  ---@type BetterBagsWindow
  local w = drawable:Create(windowProto)
  w.opts = opts
  w.kind = opts.Kind
  w.title = opts.Title or ""
  w.extraInsets = {}
  w.animations = {}
  w.fromAlpha = 0
  w.gripHover = false
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
  -- No part of a window may be off the screen (KeepOnScreen, FitToScreen).
  frame:SetClampedToScreen(true)
  frame:SetClampRectInsets(0, 0, 0, 0)
  frame:EnableMouse(true)
  w.frame = frame
  -- Only the scale: fitting to the screen reads the owner's minimums, which can read parts the
  -- owner makes after the window (a bag's scroll box). UpdateSizeMode fits it later.
  if opts.Scale ~= nil then
    frame:SetScale(opts.Scale())
  end

  w.content = CreateFrame("Frame", nil, frame)
  w:UpdateContentAnchors()

  if opts.Movable ~= false then
    w:WatchDrag()
  end
  if opts.Position ~= nil then
    LibWindow.RegisterConfig(frame, opts.Position)
    LibWindow.RestorePosition(frame)
  else
    for _, p in ipairs(opts.Points or { { Point = "CENTER" } }) do
      frame:SetPoint(p.Point, p.RelativeTo or frame:GetParent(), p.RelativePoint or p.Point, p.X or 0, p.Y or 0)
    end
  end
  if opts.Escape then
    table.insert(UISpecialFrames, opts.Name)
  end

  addon.HookScript(frame, "OnSizeChanged", function()
    if w.sizing then
      trace(w, "resizing")
    end
    if w:GetSizeMode() == "window" then
      render:Invalidate(w)
    end
  end)
  if opts.OnShow ~= nil then
    addon.HookScript(frame, "OnShow", function(ctx)
      opts.OnShow(ctx)
    end)
  end
  if opts.OnHide ~= nil then
    addon.HookScript(frame, "OnHide", function(ctx)
      opts.OnHide(ctx)
    end)
  end

  if opts.Content ~= nil then
    w:SetContent(opts.Content)
  else
    w:updatePlan()
  end
  sonata:RegisterWindow(w, opts.Kind)
  if window.windows ~= nil then
    window.windows[w] = true
  end
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
  addon.SetScript(frame, "OnDragStart", function(ctx, f)
    if self.opts.CanMove ~= nil and not self.opts.CanMove(ctx) then
      return
    end
    if self.opts.OnMoveStart ~= nil then
      self.opts.OnMoveStart(ctx)
    end
    self.moving = true
    trace(self, "move start")
    f:StartMoving()
  end)
  addon.SetScript(frame, "OnDragStop", function(ctx, f)
    if not self.moving then
      return
    end
    self.moving = false
    f:StopMovingOrSizing()
    trace(self, "move stopped")
    self:KeepOnScreen()
    trace(self, "on screen")
    self:SavePosition()
    trace(self, "position saved")
    if self.opts.OnMoved ~= nil then
      self.opts.OnMoved(ctx)
    end
  end)
end

-- SavePosition saves where the window is, when it has a saved position.
function windowProto:SavePosition()
  if self.opts.Position ~= nil then
    LibWindow.SavePosition(self.frame)
  end
end

-- SetContent makes content the drawable the window lays out. The content it replaces is
-- hidden and detached, and the window lays out again.
---@param content Drawable
function windowProto:SetContent(content)
  local previous = self.contentDrawable
  if previous ~= nil and previous ~= content then
    previous:Hide()
    render:Detach(previous)
  end
  self.contentDrawable = content
  content:SetParent(self.content)
  content:ClearAllPoints()
  content.frame:SetAllPoints(self.content)
  content.renderParent = self
  self:updatePlan()
  self:Invalidate()
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
  local i = insets or {}
  self.extraInsets = { Left = i.Left, Right = i.Right, Top = i.Top, Bottom = i.Bottom }
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

-- UpdateScale applies the owner's scale and lays the window out again.
---@param quiet? boolean Only set the scale.
function windowProto:UpdateScale(quiet)
  if self.opts.Scale == nil then
    return
  end
  self.frame:SetScale(self.opts.Scale())
  self:FitToScreen()
  if not quiet then
    self:Invalidate()
  end
end

---@param ctx Context
---@param button? string The mouse button that clicked.
function windowProto:OnCloseClicked(ctx, button)
  if self.opts.OnClose ~= nil then
    self.opts.OnClose(ctx, button)
    return
  end
  self:Hide(ctx)
end

---@return string[]
function windowProto:GetCloseClicks()
  return self.opts.CloseClicks or { "LeftButtonUp" }
end

-- OnDecorated runs after Sonata applied a theme to the window: the content moves to the new
-- insets, the grip and animations follow the theme, and the window lays out again.
---@param decoration SonataWindowDecoration
function windowProto:OnDecorated(decoration)
  self.decoration = decoration
  self:UpdateContentAnchors()
  self:buildAnimations()
  if self.opts.OnDecorated ~= nil then
    self.opts.OnDecorated(context:New('Window_OnDecorated'), decoration)
  end
  self:UpdateSizeMode()
  self:Invalidate()
end

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

-- runCallbacks runs and clears the callbacks a finished animation was carrying.
---@param group AnimationGroup
local function runCallbacks(group)
  local callbacks = group.callbacks
  group.callbacks = nil
  for _, callback in ipairs(callbacks or {}) do
    callback()
  end
end

---@param group AnimationGroup
---@param callback? fun()
local function addCallback(group, callback)
  if callback == nil then
    return
  end
  group.callbacks = group.callbacks or {}
  table.insert(group.callbacks, callback)
end

---@private
function windowProto:buildAnimations()
  for _, group in ipairs({ self.showAnimation or false, self.hideAnimation or false }) do
    if group and group:IsPlaying() then
      group:Finish()
    end
  end
  local key = sonata:GetCurrentThemeKey() or ""
  local built = self.animations[key]
  if built == nil then
    local specs = self.decoration and self.decoration:GetStyle().Animations
    local frame = self.frame
    built = { fromAlpha = 1 }
    if type(specs) == "table" and type(specs.Show) == "table" then
      local show = frame:CreateAnimationGroup()
      built.fromAlpha = addAnimations(show, specs.Show) or 1
      show:SetScript("OnFinished", function(group)
        frame:SetAlpha(1)
        runCallbacks(group)
      end)
      show:SetScript("OnStop", function(group)
        frame:SetAlpha(1)
        group.callbacks = nil
      end)
      built.show = show
    end
    if type(specs) == "table" and type(specs.Hide) == "table" then
      local hide = frame:CreateAnimationGroup()
      addAnimations(hide, specs.Hide)
      hide:SetScript("OnFinished", function(group)
        frame:Hide()
        frame:SetAlpha(1)
        runCallbacks(group)
      end)
      hide:SetScript("OnStop", function(group)
        frame:SetAlpha(1)
        group.callbacks = nil
      end)
      built.hide = hide
    end
    self.animations[key] = built
  end
  self.showAnimation = built.show
  self.hideAnimation = built.hide
  self.fromAlpha = built.fromAlpha
end

---@return boolean
function windowProto:fades()
  return self.opts.Fade == nil or self.opts.Fade()
end

-- IsClosing is true while the window fades out.
---@return boolean
function windowProto:IsClosing()
  return self.hideAnimation ~= nil and self.hideAnimation:IsPlaying()
end

---@private
---@param ctx Context
---@return boolean rendered
function windowProto:renderIfWaiting(ctx)
  if self.renderPending or render:IsDirty(self) then
    render:RenderNow(self, { ctx = ctx })
    return true
  end
  return false
end

-- Show shows the window, fading in with its theme's animation unless fading is off, after
-- rendering it if it changed while hidden. callback runs once it is fully shown. It returns
-- whether it rendered.
---@param ctx Context
---@param callback? fun()
---@return boolean rendered
function windowProto:Show(ctx, callback)
  local frame = self.frame
  if frame:IsShown() and not self:IsClosing() then
    local rendered = self:renderIfWaiting(ctx)
    if self.showAnimation ~= nil and self.showAnimation:IsPlaying() then
      addCallback(self.showAnimation, callback)
    elseif callback ~= nil then
      callback()
    end
    return rendered
  end
  if self.hideAnimation ~= nil then
    self.hideAnimation:Stop()
  end
  local rendered = self:renderIfWaiting(ctx)
  local show = self.showAnimation
  if self:fades() and show ~= nil then
    show:Stop()
    frame:SetAlpha(self.fromAlpha)
    frame:Show()
    addCallback(show, callback)
    show:Play()
  else
    frame:SetAlpha(1)
    frame:Show()
    if callback ~= nil then
      callback()
    end
  end
  return rendered
end

-- Hide hides the window, fading out with its theme's animation unless fading is off.
-- callback runs once it is hidden. A fade-in it interrupts is stopped without its callback.
---@param ctx Context
---@param callback? fun()
function windowProto:Hide(ctx, callback)
  local _ = ctx
  local frame = self.frame
  if self.showAnimation ~= nil then
    self.showAnimation:Stop()
  end
  if not frame:IsShown() then
    if callback ~= nil then
      callback()
    end
    return
  end
  local hide = self.hideAnimation
  if hide ~= nil and hide:IsPlaying() then
    addCallback(hide, callback)
    return
  end
  if self:fades() and hide ~= nil then
    addCallback(hide, callback)
    hide:Play()
  else
    frame:Hide()
    frame:SetAlpha(1)
    if callback ~= nil then
      callback()
    end
  end
end

-- Toggle hides a shown window and shows a hidden one, or one fading out.
---@param ctx Context
function windowProto:Toggle(ctx)
  if self:IsShown() and not self:IsClosing() then
    self:Hide(ctx)
  else
    self:Show(ctx)
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

-- screenSize returns the screen's size measured in the window's own scale, and never less than
-- the minimum given.
---@private
---@param minWidth? number
---@param minHeight? number
---@return number width, number height
function windowProto:screenSize(minWidth, minHeight)
  local ratio = UIParent:GetEffectiveScale() / self.frame:GetEffectiveScale()
  return math.max(minWidth or 0, UIParent:GetWidth() * ratio), math.max(minHeight or 0, UIParent:GetHeight() * ratio)
end

-- FitToScreen makes the screen the largest size the player can give the window (measured in
-- its own scale), and brings the window down to it when it is bigger. Only a window the player
-- sizes, and never while they are sizing it.
function windowProto:FitToScreen()
  if self.sizing or self:GetSizeMode() ~= "window" then
    return
  end
  local frame = self.frame
  local minWidth, minHeight = self:minimumSize()
  local maxWidth, maxHeight = self:screenSize(minWidth, minHeight)
  frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  local width, height = frame:GetWidth(), frame:GetHeight()
  if width > maxWidth or height > maxHeight then
    frame:SetSize(math.min(width, maxWidth), math.min(height, maxHeight))
  end
end

-- KeepOnScreen pulls the window back inside the screen. A clamped frame stays on the screen as
-- it is moved; turning the clamp off and on applies it after the window changed size too. It
-- waits while the player is sizing the window.
function windowProto:KeepOnScreen()
  if self.sizing then
    return
  end
  local frame = self.frame
  frame:SetClampRectInsets(0, 0, 0, 0)
  frame:SetClampedToScreen(false)
  frame:SetClampedToScreen(true)
end

-- Geometry describes the window's anchors, rect, scale, clamp and the cursor, for the
-- profiler's call trace (trace calls it at each step of a resize or a move while a capture runs).
---@param step string Which step of a resize or a move it describes.
---@return string
function windowProto:Geometry(step)
  local _ = step
  local frame = self.frame
  local anchors = {}
  for i = 1, frame:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
    local target = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
    table.insert(anchors, string.format("%s>%s %s %.1f,%.1f", point, tostring(target), tostring(relativePoint), x or 0, y or 0))
  end
  local scale = frame:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  return string.format("%s | rect %.1f,%.1f %.1fx%.1f | scale %.2f | clamped %s | cursor %.1f,%.1f",
    table.concat(anchors, "; "), frame:GetLeft() or 0, frame:GetTop() or 0, frame:GetWidth(), frame:GetHeight(),
    scale, tostring(frame:IsClampedToScreen()), cursorX / scale, cursorY / scale)
end

---@private
---@return number width, number height
function windowProto:minimumSize()
  local insets = self:GetContentInsets()
  local width = math.max(insets.Left + insets.Right + 1, numberOf(self.opts.MinWidth) or 0)
  local height = math.max(insets.Top + insets.Bottom + 1, numberOf(self.opts.MinHeight) or 0)
  local minContentWidth = numberOf(self.opts.MinContentWidth)
  if minContentWidth ~= nil then
    width = math.max(width, minContentWidth + insets.Left + insets.Right)
  end
  local minContentHeight = numberOf(self.opts.MinContentHeight)
  if minContentHeight ~= nil then
    height = math.max(height, minContentHeight + insets.Top + insets.Bottom)
  end
  return width, height
end

-- UpdateSizeMode applies the owner's size mode and lays the window out again: a window the
-- player sizes takes its saved size (or keeps the one it has), can be resized and shows its
-- grip; a window sized to its content cannot.
function windowProto:UpdateSizeMode()
  local frame = self.frame
  if self:GetSizeMode() == "window" then
    local minWidth, minHeight = self:minimumSize()
    local maxWidth, maxHeight = self:screenSize(minWidth, minHeight)
    local resizable = self.opts.Resizable ~= false
    frame:SetResizable(resizable)
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    local width, height
    if self.opts.Size ~= nil then
      width, height = self.opts.Size()
    end
    if width == nil or height == nil then
      width, height = frame:GetWidth(), frame:GetHeight()
    end
    frame:SetSize(math.min(maxWidth, math.max(minWidth, width or 0)), math.min(maxHeight, math.max(minHeight, height or 0)))
    if resizable then
      self:styleResizeGrip()
      self.resizeGrip:Show()
    elseif self.resizeGrip ~= nil then
      self.resizeGrip:Hide()
    end
  else
    frame:SetResizable(false)
    if self.resizeGrip ~= nil then
      self.resizeGrip:Hide()
    end
  end
  self:Invalidate()
end

---@private
function windowProto:updateGripAlpha()
  local grip = self.resizeGrip
  if grip == nil then
    return
  end
  if grip.showOnHover and not self.gripHover then
    grip:SetAlpha(0)
  else
    grip:SetAlpha(1)
  end
end

---@private
function windowProto:styleResizeGrip()
  local grip = self.resizeGrip
  if grip == nil then
    grip = CreateFrame("Button", nil, self.frame)
    grip:EnableMouse(true)
    addon.SetScript(grip, "OnMouseDown", function(_, _, button)
      if button ~= "LeftButton" then
        return
      end
      trace(self, "resize start")
      self.sizing = true
      -- From where the player pressed (alwaysStartFromMouse, as Blizzard's PanelResizeButtonMixin
      -- does): without it the client resized the window the moment sizing started, from a point an
      -- earlier move or resize left, and every click on the grip made the next jump bigger.
      self.frame:StartSizing("BOTTOMRIGHT", true)
      trace(self, "resize started")
    end)
    addon.SetScript(grip, "OnMouseUp", function(ctx, _, button)
      if button ~= "LeftButton" then
        return
      end
      trace(self, "resize stop")
      self.frame:StopMovingOrSizing()
      self.sizing = false
      trace(self, "resize stopped")
      self:KeepOnScreen()
      trace(self, "on screen")
      self:SavePosition()
      trace(self, "position saved")
      if self.opts.OnResized ~= nil then
        self.opts.OnResized(ctx, self.frame:GetWidth(), self.frame:GetHeight())
      end
      self:Invalidate()
    end)
    addon.SetScript(grip, "OnEnter", function()
      self.gripHover = true
      self:updateGripAlpha()
    end)
    addon.SetScript(grip, "OnLeave", function()
      self.gripHover = false
      self:updateGripAlpha()
    end)
    self.resizeGrip = grip
  end
  local style = self.decoration and self.decoration:GetStyle().Resize
  if type(style) ~= "table" then
    style = DEFAULT_GRIP
  end
  local size = style.Size or DEFAULT_GRIP.Size
  if type(size) == "table" then
    grip:SetSize(size.Width, size.Height)
  else
    grip:SetSize(size, size)
  end
  local overlay = self.decoration and self.decoration:GetOverlayFrame()
  grip:SetFrameLevel((overlay and overlay:GetFrameLevel() or self.frame:GetFrameLevel()) + 2)
  apply:Points(grip, style.Points or { { Point = "BOTTOMRIGHT" } }, self.frame)
  apply:ButtonStates(grip, {
    Normal = style.Normal or DEFAULT_GRIP.Normal,
    Highlight = style.Highlight or DEFAULT_GRIP.Highlight,
    Pushed = style.Pushed or DEFAULT_GRIP.Pushed,
  })
  grip.showOnHover = style.ShowOnHover == true
  self:updateGripAlpha()
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
  local _, screen = self:screenSize()
  return {
    MaxHeight = math.max(0, screen * SCREEN_FRACTION - vertical),
  }
end

---@param _ RenderResult?
---@param options RenderChainOptions
---@param results RenderResults
---@return RenderResult
function windowProto:Render(_, options, results)
  local frame = self.frame
  if self.contentDrawable ~= nil then
    local result = results.Results[self.contentDrawable]
    if result == nil then
      error("a window's content returned no render result")
    end
    if self:GetSizeMode() == "content" then
      local insets = self:GetContentInsets()
      local minWidth, minHeight = self:minimumSize()
      local width = math.max(minWidth, (result.Width or 0) + insets.Left + insets.Right)
      local height = math.max(minHeight, (result.Height or 0) + insets.Top + insets.Bottom)
      frame:SetSize(width, height)
    end
    self.contentDrawable:Show()
  end
  local width, height = frame:GetWidth(), frame:GetHeight()
  if self.opts.OnRendered ~= nil then
    self.opts.OnRendered(options and options.ctx, width, height)
  end
  if self.sizing then
    trace(self, "rendered while resizing")
  else
    self:KeepOnScreen()
  end
  local recorder = recording()
  if recorder ~= nil then
    recorder:WindowRendered(self)
  end
  return { Width = width, Height = height }
end
