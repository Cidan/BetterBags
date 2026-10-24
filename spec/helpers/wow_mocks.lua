-- wow_mocks.lua -- Mock basic World of Warcraft globals required by Ace3 and addon modules.
-- This file is loaded by spec/setup.lua before any libraries or addon code.

-- Core game functions
_G.GetTime = function() return os.clock() end

-- FrameScriptDocumentation.lua: debugprofilestop() -> elapsedMilliseconds (number).
_G.debugprofilestop = function() return os.clock() * 1000 end

-- PerformanceDocumentation.lua: UpdateAddOnMemoryUsage() refreshes the numbers that
-- GetAddOnMemoryUsage(name) -> result (kilobytes) returns.
_G.UpdateAddOnMemoryUsage = function() end
_G.GetAddOnMemoryUsage = function() return 0 end

-- AddOnProfilerConstantsDocumentation.lua. C_AddOnProfiler itself is left undefined so
-- code has to cope with clients that lack it; specs install it when they need it.
_G.Enum = _G.Enum or {}
_G.Enum.AddOnProfilerMetric = {
  SessionAverageTime = 0,
  RecentAverageTime = 1,
  EncounterAverageTime = 2,
  LastTime = 3,
  PeakTime = 4,
  CountTimeOver1Ms = 5,
  CountTimeOver5Ms = 6,
  CountTimeOver10Ms = 7,
  CountTimeOver50Ms = 8,
  CountTimeOver100Ms = 9,
  CountTimeOver500Ms = 10,
  CountTimeOver1000Ms = 11,
}

-- scriptable gives a mock object SetScript / GetScript / HookScript.
local function scriptable(obj)
  obj._scripts = {}
  function obj:SetScript(scriptName, handler) self._scripts[scriptName] = handler end
  function obj:GetScript(scriptName) return self._scripts[scriptName] end
  function obj:HookScript(scriptName, handler)
    local original = self._scripts[scriptName]
    if original then
      self._scripts[scriptName] = function(...) original(...) handler(...) end
    else
      self._scripts[scriptName] = handler
    end
  end
  function obj:fire(scriptName, ...)
    local handler = self._scripts[scriptName]
    if handler then handler(self, ...) end
  end
  return obj
end

-- An animation (SimpleAnimAPIDocumentation.lua and the Alpha, Translation and Scale
-- animation APIs): SetDuration, SetSmoothing, SetStartDelay, SetFromAlpha/SetToAlpha,
-- SetOffset, SetScaleFrom/SetScaleTo/SetOrigin, Play/Stop/IsPlaying.
local function CreateMockAnimation(group, animationType, name)
  local anim = scriptable({ _type = animationType, _name = name, _group = group })
  function anim:GetParent() return self._group end
  function anim:SetDuration(duration) self._duration = duration end
  function anim:SetSmoothing(smoothing) self._smoothing = smoothing end
  function anim:SetStartDelay(delay) self._startDelay = delay end
  function anim:SetFromAlpha(alpha) self._fromAlpha = alpha end
  function anim:SetToAlpha(alpha) self._toAlpha = alpha end
  function anim:SetOffset(x, y) self._offset = { x = x, y = y } end
  function anim:SetScaleFrom(x, y) self._scaleFrom = { x = x, y = y } end
  function anim:SetScaleTo(x, y) self._scaleTo = { x = x, y = y } end
  function anim:SetOrigin(point, x, y) self._origin = { point = point, x = x, y = y } end
  function anim:Play() self._playing = true self:fire("OnPlay") end
  function anim:Stop() self._playing = false self:fire("OnStop") end
  function anim:IsPlaying() return self._playing == true end
  return anim
end

-- An animation group (SimpleAnimGroupAPIDocumentation.lua): CreateAnimation(animationType?,
-- name?, templateName?), Play(reverse, offset), Stop(), Finish(), IsPlaying(), SetLooping,
-- SetToFinalAlpha. There is no time in specs:
-- * Play runs the OnPlay scripts of the group and its animations; on a group already playing
--   it does nothing (the client has a separate Restart).
-- * Stop runs OnStop(self, requested) on a playing group and stops its animations.
-- * Finish ends a playing group (OnFinished(self, requested = true), warcraft.wiki.gg
--   UIHANDLER_OnFinished) and does nothing otherwise.
-- * _complete is test-only: the group's time ran out (OnFinished with requested = false).
local function CreateMockAnimationGroup(region, name)
  local group = scriptable({ _region = region, _name = name, _animations = {} })
  function group:GetParent() return self._region end
  function group:CreateAnimation(animationType, animName)
    local anim = CreateMockAnimation(self, animationType, animName)
    table.insert(self._animations, anim)
    return anim
  end
  function group:Play(reverse)
    if self._playing then return end
    self._playing = true
    self._reverse = reverse == true
    self._plays = (self._plays or 0) + 1
    for _, anim in ipairs(self._animations) do anim._playing = true end
    self:fire("OnPlay")
    for _, anim in ipairs(self._animations) do anim:fire("OnPlay") end
  end
  function group:Stop()
    if not self._playing then return end
    self._playing = false
    for _, anim in ipairs(self._animations) do anim._playing = false end
    self:fire("OnStop", true)
  end
  local function finish(g, requested)
    g._playing = false
    for _, anim in ipairs(g._animations) do
      anim._playing = false
      anim:fire("OnFinished", requested)
    end
    g:fire("OnFinished", requested)
  end
  function group:Finish()
    if not self._playing then return end
    finish(self, true)
  end
  function group:_complete()
    if not self._playing then return end
    finish(self, false)
  end
  function group:IsPlaying() return self._playing == true end
  -- Restart(reverse, offset) stops the group and plays it again from the start.
  function group:Restart(reverse)
    self:Stop()
    self:Play(reverse)
  end
  function group:SetLooping(loopType) self._looping = loopType end
  function group:SetToFinalAlpha(setToFinalAlpha) self._toFinalAlpha = setToFinalAlpha end
  return group
end

-- Stateful Widget factory helper
-- Secret values (warcraft.wiki.gg Secret Values, patch 12.0.0): under addon restrictions some APIs
-- return secrets. Addon (tainted) code may store them, pass them to Lua functions and concatenate
-- them; arithmetic, comparisons and indexing error. MockSecret(value) makes one, IsMockSecret(v)
-- tells one. issecretvalue is not defined here: Classic has none, and specs that need it install
-- _G.issecretvalue = IsMockSecret.
local secretMeta = {}
local function secretError(operation)
  return function()
    error("attempt to perform " .. operation .. " on a secret value (execution tainted by 'BetterBags')", 2)
  end
end
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
  secretMeta[event] = secretError("arithmetic")
end
for _, event in ipairs({ "__lt", "__le", "__eq" }) do
  secretMeta[event] = secretError("comparison")
end
secretMeta.__index = secretError("indexed access")
secretMeta.__newindex = secretError("indexed assignment")
-- Concatenation is allowed, and its result is secret too.
secretMeta.__concat = function(a, b)
  return _G.MockSecret(nil)
end
_G.MockSecret = function(value)
  return setmetatable({ value }, secretMeta)
end
_G.IsMockSecret = function(value)
  return type(value) == "table" and getmetatable(value) == secretMeta
end
-- rejectSecret raises the error a C function not marked up to take secrets from tainted callers
-- raises (warcraft.wiki.gg Secret Values: "an API must be explicitly marked up as accepting
-- secrets from tainted callers").
local function rejectSecret(api, ...)
  for i = 1, select("#", ...) do
    if _G.IsMockSecret((select(i, ...))) then
      error(api .. ": secret value given to an API that does not take secrets from tainted callers", 3)
    end
  end
end

local WidgetMethods = {}
-- For helpers that model more of the client while a spec asks (spec/helpers/layout.lua: sizes from
-- anchors while a screen is set up).
_G.__mockWidgetMethods = WidgetMethods
local ItemButtonMethods = {}
local CreateMockWidget

-- Regions (textures, font strings) are not child frames: GetChildren lists frames only.
---@param widgetType string
---@return boolean
local function isRegionType(widgetType)
  return widgetType == "Texture" or widgetType == "FontString" or widgetType == "MaskTexture"
end

-- The textures every widget but a texture carries, made the first time something reads them: the
-- button state regions through their getters, the rest as plain textures. Making all of them for
-- every widget, each with its own copy of every method, made a mocked frame cost about 1,500
-- closures, and the whole-addon specs over 1.5 GB live per load (spec/helpers/whole_addon.lua).
local LAZY_TEXTURES = {
  NormalTexture = "GetNormalTexture",
  PushedTexture = "GetPushedTexture",
  HighlightTexture = "GetHighlightTexture",
  NewItemTexture = true,
  BattlepayItemTexture = true,
  ItemContextOverlay = true,
  UpgradeIcon = true,
}

-- Every widget looks its methods up here: one shared copy of each (item buttons' own first).
local WidgetMeta = {
  __index = function(self, key)
    local itemButton = rawget(self, "_type") == "ItemButton" and ItemButtonMethods[key]
    if itemButton then
      return itemButton
    end
    local method = WidgetMethods[key]
    if method ~= nil then
      return method
    end
    local lazy = LAZY_TEXTURES[key]
    if lazy ~= nil and rawget(self, "_type") ~= "Texture" then
      local texture
      if lazy == true then
        texture = CreateMockWidget("Texture", nil, self)
        rawset(self, key, texture)
      else
        texture = WidgetMethods[lazy](self)
      end
      return texture
    end
    return nil
  end,
}

-- Core frame behavior
function WidgetMethods:SetScript(scriptName, handler)
  self._scripts[scriptName] = handler
end
function WidgetMethods:GetScript(scriptName)
  return self._scripts[scriptName]
end
function WidgetMethods:HookScript(scriptName, handler)
  local original = self:GetScript(scriptName)
  if original then
    self:SetScript(scriptName, function(...)
      original(...)
      handler(...)
    end)
  else
    self:SetScript(scriptName, handler)
  end
end
function WidgetMethods:Show()
  self._shown = true
end
function WidgetMethods:Hide()
  self._shown = false
end
function WidgetMethods:IsShown()
  return self._shown
end
-- ScriptRegion:IsVisible() -> true only when this region and every parent are shown.
function WidgetMethods:IsVisible()
  if not self._shown then return false end
  local owner = self._parent
  if owner and owner.IsVisible then
    return owner:IsVisible()
  end
  return true
end
function WidgetMethods:SetShown(shown)
  self._shown = shown
end
function WidgetMethods:GetName()
  return self._name
end
function WidgetMethods:RegisterEvent(event)
  self._events[event] = true
end
function WidgetMethods:UnregisterEvent(event)
  self._events[event] = nil
end
function WidgetMethods:SetOwner(owner, anchor, x, y)
  self._owner = owner
  self._anchor = anchor
  self._ownerX = x
  self._ownerY = y
end
function WidgetMethods:SetParent(parentFrame)
  local previous = self._parent
  if not isRegionType(self._type) and previous ~= parentFrame then
    if previous ~= nil and type(previous._children) == "table" then
      for i, c in ipairs(previous._children) do
        if c == self then
          table.remove(previous._children, i)
          break
        end
      end
    end
    if parentFrame ~= nil and type(parentFrame._children) == "table" then
      table.insert(parentFrame._children, self)
    end
  end
  self._parent = parentFrame
end
-- Frame:GetChildren() -> the frame's child frames.
function WidgetMethods:GetChildren()
  return unpack(self._children)
end
function WidgetMethods:GetParent()
  return self._parent
end
function WidgetMethods:SetID(id)
  self._id = id
end
function WidgetMethods:GetID()
  return self._id or 0
end
function WidgetMethods:SetSize(w, h)
  self._width = w
  self._height = h
end
function WidgetMethods:SetWidth(w)
  self._width = w
end
function WidgetMethods:SetHeight(h)
  self._height = h
end
function WidgetMethods:GetWidth()
  return self._width or 0
end
function WidgetMethods:GetHeight()
  return self._height or 0
end
-- ScriptRegion:GetSize(ignoreRect?) -> width, height.
function WidgetMethods:GetSize()
  return self:GetWidth(), self:GetHeight()
end
-- ScriptRegion:GetLeft/GetRight/GetTop/GetBottom/GetCenter "MayReturnNothing": with no
-- layout engine in specs, a frame's rect is never resolved unless a spec sets it with
-- _SetRect(left, bottom, width, height).
function WidgetMethods:_SetRect(left, bottom, width, height)
  self._rect = { left = left, bottom = bottom }
  self:SetSize(width, height)
end
function WidgetMethods:GetLeft()
  return self._rect and self._rect.left
end
function WidgetMethods:GetBottom()
  return self._rect and self._rect.bottom
end
function WidgetMethods:GetRight()
  return self._rect and (self._rect.left + self:GetWidth())
end
function WidgetMethods:GetTop()
  return self._rect and (self._rect.bottom + self:GetHeight())
end
function WidgetMethods:GetCenter()
  if self._rect == nil then return nil end
  return self._rect.left + self:GetWidth() / 2, self._rect.bottom + self:GetHeight() / 2
end
-- ScriptRegion:GetRect() -> left, bottom, width, height ("MayReturnNothing": nothing while
-- the rect is not resolved, SimpleScriptRegionAPIDocumentation).
function WidgetMethods:GetRect()
  if self._rect == nil then return end
  return self._rect.left, self._rect.bottom, self:GetWidth(), self:GetHeight()
end
-- ScriptRegion:IsMouseOver(offsetTop, offsetBottom, offsetLeft, offsetRight)
-- (SimpleScriptRegionAPIDocumentation): whether the cursor (GetCursorPosition, in the region's
-- scale) is inside the region's rect moved out by the offsets; Blizzard enlarges it with
-- IsMouseOver(10, -10, 0, 10) (FloatingChatFrame.lua). False for a region with no rect.
function WidgetMethods:IsMouseOver(offsetTop, offsetBottom, offsetLeft, offsetRight)
  local left, right, top, bottom = self:GetLeft(), self:GetRight(), self:GetTop(), self:GetBottom()
  if left == nil then return false end
  local scale = self:GetEffectiveScale()
  local x, y = GetCursorPosition()
  x, y = x / scale, y / scale
  return x >= left + (offsetLeft or 0) and x <= right + (offsetRight or 0)
    and y >= bottom + (offsetBottom or 0) and y <= top + (offsetTop or 0)
end
-- A texture's (and a line's) alpha is its vertex color's alpha: SetAlpha replaces the alpha
-- SetVertexColor gave it, and SetVertexColor (its alpha defaulting to 1) replaces the one SetAlpha
-- gave it. Both setters add the same Alpha secret aspect (SimpleRegionAPIDocumentation.lua); the rest
-- is inferred from the client (next-themes.md §10: a size switch's SetAlpha(1) brightened BetterBags
-- Next's 0.35 border until its vertex color was set again, and a SetVertexColor after SetAlpha(0)
-- lit the title's glow until a hover set its alpha). A gradient's alphas are its own: SetAlpha does
-- not fade a gradient texture (BetterBags Next's feathers did not fade with it).
local function isTextureType(widget)
  return widget._type == "Texture" or widget._type == "Line"
end
function WidgetMethods:SetAlpha(alpha)
  self._alpha = alpha
  if isTextureType(self) and self._vertexColor then
    self._vertexColor.a = alpha
  end
end
function WidgetMethods:GetAlpha()
  return self._alpha or 1
end
-- ScriptRegionResizing:SetAllPoints([relativeTo, doResize]): only the TOPLEFT and BOTTOMRIGHT
-- points are set, after clearing the others (warcraft.wiki.gg); relativeTo defaults to the
-- parent.
function WidgetMethods:SetAllPoints(other)
  local relativeTo = other or self:GetParent()
  self._points = {
    { point = "TOPLEFT", relativeTo = relativeTo, relativePoint = "TOPLEFT", x = 0, y = 0 },
    { point = "BOTTOMRIGHT", relativeTo = relativeTo, relativePoint = "BOTTOMRIGHT", x = 0, y = 0 },
  }
  self._allPoints = other or true
end
function WidgetMethods:ClearAllPoints()
  self._points = {}
  self._allPoints = nil
end
-- ScriptRegion:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
-- (SimpleScriptRegionResizingAPIDocumentation): both offsets are required together. In game an
-- x offset given with a nil y offset was dropped (a render recording: a scroll box's child
-- anchored 14 in sat at 0), so the mock rejects one offset without the other.
function WidgetMethods:SetPoint(point, relativeTo, relativePoint, x, y)
  if type(relativePoint) == "string" and (x == nil) ~= (y == nil) then
    error("SetPoint: offsetX and offsetY must be given together, got " .. tostring(x) .. ", " .. tostring(y), 2)
  end
  -- SetPoint(point, offsetX, offsetY): relative to the parent, at the same point (warcraft.wiki.gg
  -- ScriptRegionResizing:SetPoint); GetPoint then names the parent and the point.
  if type(relativeTo) == "number" then
    relativeTo, relativePoint, x, y = self:GetParent(), point, relativeTo, relativePoint
  end
  -- A region has one anchor per point: setting a point again replaces it (warcraft.wiki.gg's
  -- SetPoint example sets the same point several times "with the same result").
  local anchor = {
    point = point,
    relativeTo = relativeTo,
    relativePoint = relativePoint,
    x = x,
    y = y
  }
  for i, existing in ipairs(self._points) do
    if existing.point == point then
      self._points[i] = anchor
      return
    end
  end
  table.insert(self._points, anchor)
end
-- ScriptRegion:GetNumPoints() -> numPoints.
function WidgetMethods:GetNumPoints()
  return #self._points
end
function WidgetMethods:GetPoint(index)
  index = index or 1
  local p = self._points[index]
  if p then
    return p.point, p.relativeTo, p.relativePoint, p.x or 0, p.y or 0
  end
  return nil
end
function WidgetMethods:EnableMouse(enable)
  self._mouseEnabled = enable
end
-- ScriptRegion:IsMouseEnabled() -> enabled (SimpleScriptRegionAPIDocumentation). Buttons take
-- the mouse until told otherwise.
function WidgetMethods:IsMouseEnabled()
  if self._mouseEnabled ~= nil then
    return self._mouseEnabled == true
  end
  return self._type == "Button" or self._type == "CheckButton"
end
function WidgetMethods:EnableMouseWheel(enable)
  self._mouseWheelEnabled = enable
end
-- Frame:IsMouseWheelEnabled() (SimpleFrameAPIDocumentation).
function WidgetMethods:IsMouseWheelEnabled()
  return self._mouseWheelEnabled == true
end
-- Frame:EnableKeyboard(enable)
function WidgetMethods:EnableKeyboard(enable)
  self._keyboardEnabled = enable
end
function WidgetMethods:RegisterForClicks(...)
  self._registeredClicks = {...}
end
function WidgetMethods:RegisterForDrag(...)
  self._registeredDrags = {...}
end
-- Frame:StartMoving() / StopMovingOrSizing() (SimpleFrameAPIDocumentation.lua).
-- Frame:StartMoving() errors on a frame that is not movable, and flags the frame user-placed
-- (warcraft.wiki.gg).
function WidgetMethods:StartMoving()
  if not self._movable then
    error("Frame:StartMoving(): Frame is not movable", 2)
  end
  self._moving = true
  self._userPlaced = true
end
-- Frame:SetUserPlaced(userPlaced) / IsUserPlaced() -> isUserPlaced (SimpleFrameAPIDocumentation).
function WidgetMethods:SetUserPlaced(userPlaced)
  self._userPlaced = userPlaced
end
function WidgetMethods:IsUserPlaced()
  return self._userPlaced == true
end
function WidgetMethods:StopMovingOrSizing()
  self._moving = false
  self._sizing = nil
end
-- Button: Enable() / Disable() / IsEnabled() -> boolean, LockHighlight() / UnlockHighlight().
function WidgetMethods:Enable()
  self._enabled = true
end
function WidgetMethods:Disable()
  self._enabled = false
end
function WidgetMethods:IsEnabled()
  return self._enabled ~= false
end
-- SetEnabled(enabled) (SimpleButtonAPIDocumentation.lua).
-- Button:SetMotionScriptsWhileDisabled(motionScriptsWhileDisabled) / GetMotionScriptsWhileDisabled()
-- (SimpleButtonAPIDocumentation, every client): OnEnter and OnLeave fire on a disabled button too.
function WidgetMethods:SetMotionScriptsWhileDisabled(enabled)
  self._motionWhileDisabled = enabled
end
function WidgetMethods:GetMotionScriptsWhileDisabled()
  return self._motionWhileDisabled == true
end
function WidgetMethods:SetEnabled(enabled)
  self._enabled = enabled and true or false
end
function WidgetMethods:LockHighlight()
  self._highlightLocked = true
end
function WidgetMethods:UnlockHighlight()
  self._highlightLocked = false
end
-- CheckButton: SetChecked(checked) / GetChecked() -> boolean.
function WidgetMethods:SetChecked(checked)
  self._checked = checked == true
end
function WidgetMethods:GetChecked()
  return self._checked == true
end

-- Textures and FontStrings
-- Frame:CreateTexture(name, drawLayer, templateName, subLevel) (SimpleFrameAPIDocumentation).
function WidgetMethods:CreateTexture(textureName, drawLayer, inherits, subLevel)
  local tex = CreateMockWidget("Texture", textureName, self)
  tex._drawLayer = drawLayer
  tex._sublevel = subLevel
  tex._inherits = inherits
  table.insert(self._textures, tex)
  return tex
end
-- Frame:CreateLine(name, drawLayer, templateName, subLevel) (SimpleFrameAPIDocumentation) makes a
-- Line: a texture drawn from a start point to an end point (SimpleLineAPIDocumentation, on the
-- live, forever, classic, classic_era and classic_anniversary branches). SetStartPoint and
-- SetEndPoint take (relativePoint, relativeTo, offsetX = 0, offsetY = 0).
function WidgetMethods:CreateLine(lineName, drawLayer, inherits, subLevel)
  local line = CreateMockWidget("Line", lineName, self)
  line._drawLayer = drawLayer
  line._sublevel = subLevel
  line._inherits = inherits
  line._thickness = 1
  line._hitRectThickness = 0
  line.SetStartPoint = function(l, relativePoint, relativeTo, offsetX, offsetY)
    l._startPoint = { relativePoint, relativeTo, offsetX or 0, offsetY or 0 }
  end
  line.SetEndPoint = function(l, relativePoint, relativeTo, offsetX, offsetY)
    l._endPoint = { relativePoint, relativeTo, offsetX or 0, offsetY or 0 }
  end
  line.GetStartPoint = function(l)
    local p = l._startPoint or {}
    return p[1], p[2], p[3], p[4]
  end
  line.GetEndPoint = function(l)
    local p = l._endPoint or {}
    return p[1], p[2], p[3], p[4]
  end
  line.SetThickness = function(l, thickness) l._thickness = thickness end
  line.GetThickness = function(l) return l._thickness end
  line.SetHitRectThickness = function(l, thickness) l._hitRectThickness = thickness end
  line.GetHitRectThickness = function(l) return l._hitRectThickness end
  table.insert(self._textures, line)
  return line
end
function WidgetMethods:CreateFontString(fontStringName, drawLayer, inherits)
  local fs = CreateMockWidget("FontString", fontStringName, self)
  fs._drawLayer = drawLayer
  fs._inherits = inherits
  table.insert(self._fontstrings, fs)
  return fs
end
-- SimpleButtonAPIDocumentation.lua: Set{Normal,Pushed,Disabled,Highlight}Texture(asset)
-- take a texture file or file ID (non-nilable) and draw it in the state's region; a texture
-- object becomes the region.
local function setStateTexture(button, getter, field, texture, fnName)
  if texture == nil then
    error("bad argument #1 to '" .. fnName .. "' (Usage: self:" .. fnName .. "(asset))", 3)
  end
  if type(texture) == "string" or type(texture) == "number" then
    button[getter](button):SetTexture(texture)
  else
    button[field] = texture
  end
end
function WidgetMethods:SetNormalTexture(texture)
  setStateTexture(self, "GetNormalTexture", "NormalTexture", texture, "SetNormalTexture")
end
-- A button's state region (its normal, pushed, highlight or disabled texture) fills the button unless
-- anchored otherwise: Blizzard sets a button's state textures to an icon and never anchors them
-- (Blizzard_CharacterCreate.lua CharacterCreateSpecButtonMixin:SetSpec), and an XML <NormalTexture>
-- without anchors fills its button.
local function stateRegion(button)
  local tex = CreateMockWidget("Texture", nil, button)
  tex:SetAllPoints(button)
  return tex
end
function WidgetMethods:GetNormalTexture()
  if (not rawget(self, "NormalTexture") or type(rawget(self, "NormalTexture")) == "string") and self._type ~= "Texture" then
    self.NormalTexture = stateRegion(self)
  end
  return self.NormalTexture
end
function WidgetMethods:GetPushedTexture()
  if not rawget(self, "PushedTexture") and self._type ~= "Texture" then
    self.PushedTexture = stateRegion(self)
  end
  return self.PushedTexture
end
function WidgetMethods:GetHighlightTexture()
  if not rawget(self, "HighlightTexture") and self._type ~= "Texture" then
    self.HighlightTexture = stateRegion(self)
  end
  return self.HighlightTexture
end
-- SimpleButtonAPIDocumentation.lua: SetHighlightTexture(asset, blendMode?) sets the
-- button's highlight region; Set{Pushed,Disabled}Texture(asset) and the Set*Atlas
-- variants likewise set their state region.
-- Button:SetHighlightTexture(asset, blendMode?): the blend mode defaults to ADD
-- (wowprogramming, Button:SetHighlightTexture).
function WidgetMethods:SetHighlightTexture(texture, blendMode)
  self._highlightTexture = texture
  setStateTexture(self, "GetHighlightTexture", "HighlightTexture", texture, "SetHighlightTexture")
  self:GetHighlightTexture():SetBlendMode(blendMode or "ADD")
end
function WidgetMethods:SetPushedTexture(texture)
  setStateTexture(self, "GetPushedTexture", "PushedTexture", texture, "SetPushedTexture")
end
function WidgetMethods:GetDisabledTexture()
  if not self.DisabledTexture and self._type ~= "Texture" then
    self.DisabledTexture = stateRegion(self)
  end
  return self.DisabledTexture
end
function WidgetMethods:SetDisabledTexture(texture)
  setStateTexture(self, "GetDisabledTexture", "DisabledTexture", texture, "SetDisabledTexture")
end
-- Clear{Normal,Pushed,Disabled,Highlight}Texture() remove what the state draws.
local function clearState(button, getter)
  local region = button[getter](button)
  if region ~= nil then
    region:SetTexture(nil)
  end
end
function WidgetMethods:ClearNormalTexture() clearState(self, "GetNormalTexture") end
function WidgetMethods:ClearPushedTexture() clearState(self, "GetPushedTexture") end
function WidgetMethods:ClearDisabledTexture() clearState(self, "GetDisabledTexture") end
function WidgetMethods:ClearHighlightTexture() clearState(self, "GetHighlightTexture") end
-- Frame:SetHitRectInsets(left, right, top, bottom) / GetHitRectInsets().
function WidgetMethods:SetHitRectInsets(left, right, top, bottom)
  self._hitRectInsets = { left, right, top, bottom }
end
function WidgetMethods:GetHitRectInsets()
  local i = self._hitRectInsets or { 0, 0, 0, 0 }
  return i[1], i[2], i[3], i[4]
end
-- UIObject:GetObjectType() -> the widget type ("Frame", "Button", "Texture", ...);
-- IsObjectType(type) is also true for the types it derives from (every frame type is a
-- Frame, every widget a Region).
function WidgetMethods:GetObjectType()
  return self._type
end
function WidgetMethods:IsObjectType(objectType)
  if objectType == self._type or objectType == "Region" or objectType == "Object" then
    return true
  end
  if objectType == "Frame" then
    return not isRegionType(self._type)
  end
  if objectType == "Button" then
    return self._type == "CheckButton" or self._type == "ItemButton"
  end
  return false
end
function WidgetMethods:SetHighlightAtlas(atlas, blendMode)
  self._highlightAtlas = atlas
  local highlight = self:GetHighlightTexture()
  highlight:SetAtlas(atlas)
  if blendMode then highlight:SetBlendMode(blendMode) end
end
function WidgetMethods:SetPushedAtlas(atlas)
  self._pushedAtlas = atlas
  self:GetPushedTexture():SetAtlas(atlas)
end
function WidgetMethods:SetDisabledAtlas(atlas)
  self._disabledAtlas = atlas
  self:GetDisabledTexture():SetAtlas(atlas)
end
-- SimpleTextureBaseAPIDocumentation.lua: SetTextureSliceMargins(left, top, right, bottom),
-- SetTextureSliceMode(sliceMode), SetHorizTile(tiling), SetVertTile(tiling); GetTexture()
-- and GetAtlas() return what was set.
function WidgetMethods:SetTextureSliceMargins(left, top, right, bottom)
  self._sliceMargins = { left = left, top = top, right = right, bottom = bottom }
end
function WidgetMethods:SetTextureSliceMode(sliceMode)
  self._sliceMode = sliceMode
end
-- ClearTextureSlice() drops the slice margins and mode.
function WidgetMethods:ClearTextureSlice()
  self._sliceMargins = nil
  self._sliceMode = nil
end
function WidgetMethods:SetHorizTile(tiling)
  self._horizTile = tiling
end
function WidgetMethods:SetVertTile(tiling)
  self._vertTile = tiling
end
-- TextureBase:GetHorizTile() / GetVertTile() -> tiling.
function WidgetMethods:GetHorizTile()
  return self._horizTile == true
end
function WidgetMethods:GetVertTile()
  return self._vertTile == true
end
function WidgetMethods:GetTexture()
  return self._texturePath
end
function WidgetMethods:GetAtlas()
  return self._atlas
end
function WidgetMethods:GetVertexColor()
  local c = self._vertexColor
  if c then return c.r, c.g, c.b, c.a end
  if isTextureType(self) then return 1, 1, 1, self._alpha end
  return 1, 1, 1, 1
end
-- FontInstance: SetFontObject(font) / GetFontObject(), SetShadowOffset(offsetX, offsetY).
function WidgetMethods:SetFontObject(font)
  if self._ownFont ~= nil and font == self._ownFont then
    -- What the client does (issue #1152, see InputBoxTemplate below): the font would inherit
    -- from itself, and the call recurses until the process's stack overflows.
    error("stack overflow: an edit box was given its own font object", 2)
  end
  self._fontObject = font
end
function WidgetMethods:SetShadowOffset(x, y)
  self._shadowOffset = { x = x, y = y }
end
-- Frame:SetResizable(resizable), SetResizeBounds(minWidth, minHeight, maxWidth?, maxHeight?),
-- StartSizing(resizePoint?), SetToplevel(topLevel), SetClampedToScreen(clamped),
-- SetMovable(movable), SetScale(scale) / GetScale().
function WidgetMethods:SetResizable(resizable)
  self._resizable = resizable
end
-- Frame:IsResizable() -> resizable (SimpleFrameAPIDocumentation).
function WidgetMethods:IsResizable()
  return self._resizable == true
end
function WidgetMethods:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  self._resizeBounds = { minWidth = minWidth, minHeight = minHeight, maxWidth = maxWidth, maxHeight = maxHeight }
end
-- Frame:StartSizing(resizePoint?, alwaysStartFromMouse = false) (SimpleFrameAPIDocumentation).
function WidgetMethods:StartSizing(point, alwaysStartFromMouse)
  self._sizing = point or "BOTTOMRIGHT"
  self._sizingFromMouse = alwaysStartFromMouse == true
end
-- Frame:SetToplevel(topLevel) / IsToplevel(): a toplevel frame raises its level when clicked or
-- shown (warcraft.wiki.gg API:Frame_SetToplevel).
function WidgetMethods:SetToplevel(topLevel)
  self._toplevel = topLevel
end
function WidgetMethods:IsToplevel()
  return self._toplevel == true
end
function WidgetMethods:SetClampedToScreen(clamped)
  self._clamped = clamped
end
function WidgetMethods:IsClampedToScreen()
  return self._clamped == true
end
-- Frame:SetClampRectInsets(left, right, top, bottom).
function WidgetMethods:SetClampRectInsets(left, right, top, bottom)
  self._clampRectInsets = { left, right, top, bottom }
end
function WidgetMethods:SetMovable(movable)
  self._movable = movable
end
-- Frame:IsMovable() -> isMovable (SimpleFrameAPIDocumentation).
function WidgetMethods:IsMovable()
  return self._movable == true
end
function WidgetMethods:SetScale(scale)
  self._scale = scale
end
function WidgetMethods:GetScale()
  return self._scale or 1
end
-- Frame:SetClipsChildren(clipped) and DoesClipChildren() (SimpleFrameAPIDocumentation.lua, every
-- client): whether the frame cuts its children's drawing at its edges.
function WidgetMethods:SetClipsChildren(clipped)
  self._clipsChildren = clipped == true
end
function WidgetMethods:DoesClipChildren()
  return self._clipsChildren == true
end
-- GetPhysicalScreenSize() -> sizeX, sizeY (ScreenDocumentation.lua; Blizzard's PixelUtil calls it on
-- every client). By default a screen 768 pixels high: at a UI scale of 1 a UI unit is then exactly a
-- screen pixel (PixelUtil.GetPixelToUIUnitFactor is 768 over the height), so specs of layouts in units
-- see them unchanged by BetterBags Next's pixel grid (docs/next-pixel-perfect.md). Specs of the pixel
-- grid set real screens (spec/helpers/layout.lua, UseScreen).
_G.GetPhysicalScreenSize = function() return 1920, 768 end
-- Round(value) (Blizzard_SharedXMLBase/MathUtil.lua: Classic's, half away from zero; live is math.round)
-- and PixelUtil (Blizzard_SharedXML/PixelUtil.lua, every client), as Blizzard writes them.
_G.Round = _G.Round or function(value)
  if value < 0.0 then
    return math.ceil(value - .5)
  end
  return math.floor(value + .5)
end
_G.PixelUtil = _G.PixelUtil or {}
function _G.PixelUtil.GetPixelToUIUnitFactor()
  local _, physicalHeight = GetPhysicalScreenSize()
  return 768.0 / physicalHeight
end
function _G.PixelUtil.GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
  if uiUnitSize == 0 and (not minPixels or minPixels == 0) then
    return 0
  end
  local uiUnitFactor = PixelUtil.GetPixelToUIUnitFactor()
  local numPixels = Round((uiUnitSize * layoutScale) / uiUnitFactor)
  if minPixels then
    if uiUnitSize < 0.0 then
      if numPixels > -minPixels then
        numPixels = -minPixels
      end
    else
      if numPixels < minPixels then
        numPixels = minPixels
      end
    end
  end
  return numPixels * uiUnitFactor / layoutScale
end
-- Region:GetEffectiveScale() -> the frame's scale times every parent's.
function WidgetMethods:GetEffectiveScale()
  local scale = self:GetScale()
  local owner = self._parent
  if owner ~= nil and owner.GetEffectiveScale ~= nil then
    scale = scale * owner:GetEffectiveScale()
  end
  return scale
end
-- SimpleAnimatableObjectAPIDocumentation.lua: CreateAnimationGroup(name?, templateName?).
function WidgetMethods:CreateAnimationGroup(groupName)
  return CreateMockAnimationGroup(self, groupName)
end
function WidgetMethods:SetBlendMode(mode)
  self._blendMode = mode
end
-- TextureBase:GetBlendMode() -> blendMode (non-nilable; textures default to "BLEND").
function WidgetMethods:GetBlendMode()
  return self._blendMode or "BLEND"
end
function WidgetMethods:SetDrawLayer(layer, sublevel)
  self._drawLayer = layer
  self._sublevel = sublevel
end
-- Region:GetDrawLayer() -> layer, sublevel.
function WidgetMethods:GetDrawLayer()
  return self._drawLayer or "ARTWORK", self._sublevel or 0
end
-- TextureBase:SetTexture(textureAsset) replaces whatever the texture drew (an atlas or a
-- color texture); nil clears it.
-- TextureBase:SetTexture(asset, wrapModeHorizontal?, wrapModeVertical?, filterMode?).
function WidgetMethods:SetTexture(path, wrapH, wrapV, filterMode)
  self._texturePath = path
  self._wrapH, self._wrapV, self._filterMode = wrapH, wrapV, filterMode
  self._atlas = nil
  self._colorTexture = nil
end
function WidgetMethods:SetTexCoord(...)
  self._texCoords = {...}
end
-- TextureBase:SetRotation(radians, normalizedRotationPoint?) and GetRotation() -> radians
-- (SimpleTextureBaseAPIDocumentation, every client).
function WidgetMethods:SetRotation(radians)
  self._rotation = radians
end
function WidgetMethods:GetRotation()
  return self._rotation or 0
end
-- TextureBase:SetGradient(orientation, minColor, maxColor) with two ColorMixins.
function WidgetMethods:SetGradient(orientation, minColor, maxColor)
  self._gradient = { orientation = orientation, min = minColor, max = maxColor }
end
-- TextureBase:GetTexCoord() -> the eight corner coordinates (ULx, ULy, LLx, LLy, URx, URy,
-- LRx, LRy); a texture set with left, right, top, bottom reports its corners.
function WidgetMethods:GetTexCoord()
  local c = self._texCoords or { 0, 1, 0, 1 }
  if #c == 4 then
    local left, right, top, bottom = c[1], c[2], c[3], c[4]
    return left, top, left, bottom, right, top, right, bottom
  end
  return unpack(c)
end
-- TextureBase:SetAtlas(atlas, useAtlasSize) draws the atlas with its own texture
-- coordinates, tiling and nine-slice data (SimpleTextureBaseAPIDocumentation.lua; the
-- mock leaves those unset, so a later SetTexCoord, tiling or slicing call shows).
-- TextureBase:SetAtlas(atlas, useAtlasSize?, filterMode?, resetTexCoords?, wrapModeHorizontal?,
-- wrapModeVertical?).
function WidgetMethods:SetAtlas(atlas, useAtlasSize, filterMode, _, wrapH, wrapV)
  self._atlas = atlas
  self._useAtlasSize = useAtlasSize
  self._wrapH, self._wrapV, self._filterMode = wrapH, wrapV, filterMode
  self._texturePath = nil
  self._colorTexture = nil
  self._texCoords = nil
  self._horizTile = nil
  self._vertTile = nil
  self._sliceMargins = nil
  self._sliceMode = nil
end
-- TextureBase:SetColorTexture(r, g, b, a?) replaces a texture or atlas with a solid color.
function WidgetMethods:SetColorTexture(r, g, b, a)
  self._colorTexture = {r = r, g = g, b = b, a = a or 1}
  self._wrapH, self._wrapV = nil, nil
  self._atlas = nil
  self._texturePath = nil
end
-- TextureBase:SetDesaturated(desaturated?) / IsDesaturated() -> boolean.
function WidgetMethods:SetDesaturated(desaturated)
  self._desaturated = desaturated == true
end
function WidgetMethods:IsDesaturated()
  return self._desaturated == true
end
function WidgetMethods:SetNormalAtlas(atlas)
  self._normalAtlas = atlas
  self:GetNormalTexture():SetAtlas(atlas)
end
function WidgetMethods:SetNormalFontObject(fontObject)
  self._normalFontObject = fontObject
end
-- SimpleButtonAPIDocumentation.lua: Get{Normal,Highlight,Disabled}FontObject().
function WidgetMethods:GetNormalFontObject() return self._normalFontObject end
function WidgetMethods:GetHighlightFontObject() return self._highlightFontObject end
function WidgetMethods:GetDisabledFontObject() return self._disabledFontObject end
-- SimpleButtonAPIDocumentation.lua: SetHighlightFontObject(font), SetDisabledFontObject(font).
function WidgetMethods:SetHighlightFontObject(fontObject)
  self._highlightFontObject = fontObject
end
function WidgetMethods:SetDisabledFontObject(fontObject)
  self._disabledFontObject = fontObject
end
-- SimpleEditBoxAPIDocumentation.lua: SetTextInsets(left, right, top, bottom).
function WidgetMethods:SetTextInsets(left, right, top, bottom)
  self._textInsets = { left, right, top, bottom }
end
-- GetTextInsets() -> left, right, top, bottom (none nilable; 0 until set).
function WidgetMethods:GetTextInsets()
  local insets = self._textInsets or { 0, 0, 0, 0 }
  return insets[1] or 0, insets[2] or 0, insets[3] or 0, insets[4] or 0
end
function WidgetMethods:SetFontString(fontString)
  self._fontString = fontString
end
function WidgetMethods:GetFontString()
  if not self._fontString then
    self._fontString = CreateMockWidget("FontString", nil, self)
  end
  return self._fontString
end

-- Text and Fonts. A button's text is its font string's (Blizzard sizes buttons from
-- button:GetFontString():GetStringWidth() after setting their text, InspectPaperDollFrame.lua,
-- Blizzard_CompactRaidFrameManager.lua).
-- FontString:SetText(text): the font must be set before showing text (warcraft.wiki.gg
-- API_FontString_SetText); the client raises "FontString:SetText(): Font not set" for a font
-- string with no font (none set, no inherited template).
-- FontString:SetText takes secrets (SecretArguments AllowedWhenTainted) and gives the font
-- string the secret Text aspect (SecretArgumentsAddAspect): GetText returns the secret, and
-- GetStringWidth a secret number (SecretWhenAnchoringSecret, SimpleFontStringAPIDocumentation),
-- until a plain text is set.
function WidgetMethods:SetText(text)
  if self._type == "FontString" and self._font == nil and self._fontObject == nil and self._inherits == nil then
    error("FontString:SetText(): Font not set", 2)
  end
  if _G.IsMockSecret(text) then
    self._secretText = text
    self._text = ""
    return
  end
  self._secretText = nil
  self._text = tostring(text or "")
  if self._fontString ~= nil then
    self._fontString._text = self._text
  end
end
function WidgetMethods:SetTextHeight(height)
  self._textHeight = height
end
function WidgetMethods:SetWordWrap(wrap)
  self._wordWrap = wrap
end
function WidgetMethods:SetNonSpaceWrap(wrap)
  self._nonSpaceWrap = wrap
end
-- Slider widget API (UISliderTemplate / HorizontalSliderTemplate).
function WidgetMethods:SetOrientation(orientation)
  self._orientation = orientation
end
function WidgetMethods:SetMinMaxValues(minValue, maxValue)
  self._minValue = minValue
  self._maxValue = maxValue
end
function WidgetMethods:SetValueStep(step)
  self._valueStep = step
end
function WidgetMethods:SetObeyStepOnDrag(obey)
  self._obeyStepOnDrag = obey
end
-- Slider:SetValue(value [, treatAsMouseEvent]) fires OnValueChanged(self, value, userInput)
-- when the value changes; userInput is false for a value set from code
-- (warcraft.wiki.gg UIHANDLER_OnValueChanged, API Slider_SetValue).
function WidgetMethods:SetValue(value, treatAsMouseEvent)
  local changed = self._value ~= value
  self._value = value
  local onValueChanged = changed and self._scripts.OnValueChanged
  if onValueChanged then
    onValueChanged(self, value, treatAsMouseEvent == true)
  end
end
function WidgetMethods:GetValue()
  return self._value or 0
end
-- EditBox widget API (InputBoxTemplate).
-- EditBox:SetMaxLetters(maxLetters) / GetMaxLetters().
function WidgetMethods:SetMaxLetters(maxLetters)
  self._maxLetters = maxLetters
end
function WidgetMethods:GetMaxLetters()
  return self._maxLetters or 0
end
function WidgetMethods:SetNumeric(numeric)
  self._numeric = numeric
end
-- EditBox:SetMultiLine(multiline) / IsMultiLine(), SetCountInvisibleLetters(count)
-- (SimpleEditBoxAPIDocumentation).
function WidgetMethods:SetMultiLine(multiline)
  self._multiLine = multiline
end
function WidgetMethods:IsMultiLine()
  return self._multiLine == true
end
function WidgetMethods:SetCountInvisibleLetters(count)
  self._countInvisibleLetters = count
end
function WidgetMethods:SetAutoFocus(autoFocus)
  self._autoFocus = autoFocus
end
-- EditBox:IsAutoFocus() and HighlightText(start = 0, stop = -1) (SimpleEditBoxAPIDocumentation): an
-- edit box focuses itself when shown unless told not to.
function WidgetMethods:IsAutoFocus()
  return self._autoFocus ~= false
end
function WidgetMethods:HighlightText(start, stop)
  self._highlight = { start or 0, stop or -1 }
end
function WidgetMethods:SetFocus()
  self._hasFocus = true
end
function WidgetMethods:ClearFocus()
  self._hasFocus = false
end
function WidgetMethods:HasFocus()
  return self._hasFocus == true
end
function WidgetMethods:GetLineHeight()
  return self._lineHeight or 12
end
function WidgetMethods:SetShadowColor(r, g, b, a)
  self._shadowColor = {r = r, g = g, b = b, a = a or 1}
end
-- A font instance's own shadow, else that of the font object it inherits.
function WidgetMethods:GetShadowColor()
  local c = self._shadowColor
  if c then
    return c.r, c.g, c.b, c.a
  end
  local fo = self:GetFontObject()
  if fo.GetShadowColor then
    return fo:GetShadowColor()
  end
  return 0, 0, 0, 0
end
function WidgetMethods:GetShadowOffset()
  local o = self._shadowOffset
  if o then
    return o.x, o.y
  end
  local fo = self:GetFontObject()
  if fo.GetShadowOffset then
    return fo:GetShadowOffset()
  end
  return 0, 0
end
-- EditBox:GetText() is "" for an empty box, never nil.
function WidgetMethods:GetText()
  if self._secretText ~= nil then
    return self._secretText
  end
  if self._type == "EditBox" and self._text == nil then
    return ""
  end
  return self._text
end
function WidgetMethods:GetTextWidth()
  if self._secretText ~= nil then
    return _G.MockSecret(nil)
  end
  return #self._text * 6
end
function WidgetMethods:GetStringWidth()
  if self._secretText ~= nil then
    return _G.MockSecret(nil)
  end
  return #self._text * 6
end
-- FontString:GetNumLines() -> numLines, IsTruncated() -> isTruncated, CanWordWrap() -> wrap
-- (SimpleFontStringAPIDocumentation). Lines as GetStringHeight counts them; never truncated.
function WidgetMethods:GetNumLines()
  local text = self._text or ""
  if text == "" then return 0 end
  local width = self:GetWidth()
  if width > 0 then
    return math.max(1, math.ceil(self:GetStringWidth() / width))
  end
  return 1
end
function WidgetMethods:IsTruncated()
  return false
end
function WidgetMethods:CanWordWrap()
  return self._wordWrap ~= false
end
-- FontString:GetStringHeight() -> the height of the text as drawn: no text is 0; otherwise
-- one line per GetWidth() worth of characters (6 pixels each, as GetStringWidth), times the
-- line height. A stand-in for the client's text layout.
function WidgetMethods:GetStringHeight()
  local text = self._text or ""
  if text == "" then return 0 end
  local width = self:GetWidth()
  local lines = 1
  if width > 0 then
    lines = math.max(1, math.ceil(self:GetStringWidth() / width))
  end
  return lines * self:GetLineHeight()
end
function WidgetMethods:SetFont(font, size, flags)
  if flags and flags ~= "" then
    for token in string.gmatch(flags, "[^,%s]+") do
      local upperToken = string.upper(token)
      if upperToken ~= "OUTLINE" and
         upperToken ~= "THICKOUTLINE" and
         upperToken ~= "MONOCHROME" and
         upperToken ~= "FILTER" and
         upperToken ~= "FIXEDHEIGHT" and
         upperToken ~= "NEVERCULL" and
         upperToken ~= "SLUG" then
        error("bad argument #3 to 'SetFont' (supported flags: OUTLINE, THICKOUTLINE, MONOCHROME, FILTER, FIXEDHEIGHT, NEVERCULL, SLUG)", 2)
      end
    end
  end
  self._font = font
  self._fontSize = size
  self._fontFlags = flags
end
-- GetFont() -> fontFile, height, flags (SimpleFontAPIDocumentation.lua): set with SetFont, else
-- the font object's it inherits (warcraft.wiki.gg UIOBJECT_FontInstance).
function WidgetMethods:GetFont()
  if self._font == nil then
    local fo = self:GetFontObject()
    if fo.GetFont ~= nil then
      local file, height, flags = fo:GetFont()
      return file, height, flags or ""
    end
  end
  return self._font, self._fontSize, self._fontFlags or ""
end
function WidgetMethods:SetTextColor(r, g, b, a)
  self._textColor = {r = r, g = g, b = b, a = a or 1}
end
-- A font instance's own color, else the default color of the font object it inherits
-- (changing a font object updates every font string set to it with SetFontObject).
function WidgetMethods:GetTextColor()
  if self._textColor then
    return self._textColor.r, self._textColor.g, self._textColor.b, self._textColor.a
  end
  return self:GetFontObject():GetTextColor()
end
-- FontInstance:GetFontObject() -> the font object set with SetFontObject, else the one the
-- font string inherits (CreateFontString's template).
function WidgetMethods:GetFontObject()
  if self._ownFont ~= nil then
    return self._ownFont
  end
  local fo = self._fontObject or (self._inherits and _G[self._inherits])
  if type(fo) == "string" then
    fo = _G[fo]
  end
  if fo ~= nil then
    return fo
  end
  return {
    GetTextColor = function()
      return 1, 1, 1, 1
    end
  }
end
function WidgetMethods:SetVertexColor(r, g, b, a)
  self._vertexColor = {r = r, g = g, b = b, a = a or 1}
  if isTextureType(self) then
    self._alpha = a or 1
  end
end
function WidgetMethods:SetJustifyH(justify)
  self._justifyH = justify
end
-- Centered until justified otherwise: justifyH defaults to CENTER (Blizzard_SharedXML/UI.xsd).
function WidgetMethods:GetJustifyH()
  return self._justifyH or "CENTER"
end
-- FontString:SetSpacing(spacing) / GetSpacing(), SetMaxLines(maxLines) / GetMaxLines()
-- (SimpleFontStringAPIDocumentation, every client): the room between lines, and the most lines shown.
function WidgetMethods:SetSpacing(spacing)
  self._spacing = spacing
end
function WidgetMethods:GetSpacing()
  return self._spacing or 0
end
function WidgetMethods:SetMaxLines(maxLines)
  self._maxLines = maxLines
end
function WidgetMethods:GetMaxLines()
  return self._maxLines or 0
end
function WidgetMethods:SetJustifyV(justify)
  self._justifyV = justify
end
function WidgetMethods:GetJustifyV()
  return self._justifyV
end

function WidgetMethods:SetAttribute(attrName, value)
  self._attributes[attrName] = value
end
function WidgetMethods:GetAttribute(attrName)
  return self._attributes[attrName]
end

-- Strata / Level / Backdrop
function WidgetMethods:SetFrameStrata(strata)
  self._frameStrata = strata
end
-- A frame shares its parent's strata unless it sets its own (warcraft.wiki.gg "Frame Strata").
function WidgetMethods:GetFrameStrata()
  if self._frameStrata ~= nil then
    return self._frameStrata
  end
  local owner = self._parent
  if owner ~= nil and owner.GetFrameStrata ~= nil then
    return owner:GetFrameStrata()
  end
  return "MEDIUM"
end
-- warcraft.wiki.gg "Frame Strata": when a frame's level changes, every descendant shifts by
-- the same amount, and a descendant that would go below 0 is set to 10000.
local function shiftDescendants(frame, delta)
  for _, child in ipairs(frame._children or {}) do
    if child._frameLevel ~= nil then
      local level = child._frameLevel + delta
      if level < 0 then
        level = 10000
      end
      child._frameLevel = level
    end
    shiftDescendants(child, delta)
  end
end
function WidgetMethods:SetFrameLevel(level)
  if not level or type(level) ~= "number" or level < 0 or level > 65535 then
    error("bad argument #1 to 'SetFrameLevel' (outside of expected range 0 to 65535 - Usage: self:SetFrameLevel(frameLevel))", 2)
  end
  local previous = self._frameLevel or 0
  self._frameLevel = level
  if level ~= previous then
    shiftDescendants(self, level - previous)
  end
end
function WidgetMethods:GetFrameLevel()
  return self._frameLevel or 0
end

-- Grid Frame scroll/mousewheel APIs
function WidgetMethods:HideScrollBar()
  self._scrollBarShown = false
end
function WidgetMethods:ShowScrollBar()
  self._scrollBarShown = true
end
function WidgetMethods:EnableMouseWheelScroll(enable)
  self._mouseWheelScrollEnabled = enable
end
function WidgetMethods:GetContainer()
  if not self._container then
    self._container = CreateMockWidget("Frame", nil, self)
  end
  return self._container
end

-- Modern DropdownButton menu APIs. The generator passed to SetupMenu is run on
-- every GenerateMenu()/Update() call (mirroring the live client, which re-runs
-- the generator each time the menu is opened). Each run builds a fresh menu
-- root and records the created entries on self._lastMenuItems so tests can
-- assert what the menu currently shows.
function WidgetMethods:SetupMenu(generator)
  self._menuGenerator = generator
  self:GenerateMenu()
end
function WidgetMethods:GenerateMenu()
  if not self._menuGenerator then return end
  local items = {}
  local root = {
    SetScrollMode = function() end,
    CreateButton = function(_, text) table.insert(items, text); return {} end,
    CreateCheckbox = function(_, text) table.insert(items, text); return {} end,
    -- CreateRadio(text, isSelected, setSelected, data) (11_0_0_MenuImplementationGuide.lua).
    CreateRadio = function(_, text, isSelected, setSelected, data)
      table.insert(items, text)
      self._lastMenuRadios = self._lastMenuRadios or {}
      self._lastMenuRadios[text] = { isSelected = isSelected, setSelected = setSelected, data = data }
      return {}
    end,
  }
  self._lastMenuRadios = {}
  self._menuGenerator(self, root)
  self._lastMenuItems = items
end
function WidgetMethods:Update()
  self:GenerateMenu()
end


function ItemButtonMethods.SetHasItem() end
function ItemButtonMethods:SetBagID(id)
  self.bagID = id
end
function ItemButtonMethods:GetBagID()
  return self.bagID or (self:GetParent() and self:GetParent():GetID() or nil)
end
-- ContainerFrameItemButtonMixin:Initialize (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua,
-- 12.1.5): bag and slot, the extended-slot state, the combined-bags background, then Show.
function ItemButtonMethods:Initialize(bag, slot)
  self:SetBagID(bag)
  self:SetID(slot)
  self:UpdateExtended()
  local isCombined = self:GetParent():IsCombinedBagContainer()
  if isCombined and not self.ItemSlotBackground then
    self.ItemSlotBackground = self:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
    self.ItemSlotBackground:SetAllPoints(self)
  end
  if self.ItemSlotBackground then
    self.ItemSlotBackground:SetShown(isCombined)
  end
  self:Show()
end
function ItemButtonMethods:GetSlotAndBagID()
  return self:GetID(), self:GetBagID()
end
function ItemButtonMethods:IsExtended()
  return self.isExtended or false
end
function ItemButtonMethods:SetIsExtended(isExtended)
  self.isExtended = isExtended
end
function ItemButtonMethods:UpdateExtended()
  local slotId, bagId = self:GetSlotAndBagID()
  local _, currentNumSlots = _G.ContainerFrame_GetContainerNumSlots(bagId)
  self:SetIsExtended(slotId > currentNumSlots)
  self.updateExtendedCalledCount = (self.updateExtendedCalledCount or 0) + 1
end

CreateMockWidget = function(widgetType, name, parent)
  local widget = setmetatable({}, WidgetMeta)
  widget._type = widgetType
  widget._name = name
  widget._parent = parent
  widget._shown = true
  widget._width = 0
  widget._height = 0
  widget._alpha = 1
  widget._text = ""
  widget._scripts = {}
  widget._events = {}
  widget._children = {}
  widget._points = {}
  widget._textures = {}
  widget._fontstrings = {}
  -- Regions (textures, font strings) are not child frames: GetChildren lists frames only.
  local isRegion = isRegionType(widgetType)
  if parent ~= nil and not isRegion and type(parent._children) == "table" then
    table.insert(parent._children, widget)
  end
  -- warcraft.wiki.gg "Frame Strata": every frame starts one level above its parent.
  if not isRegion then
    if parent ~= nil and type(parent.GetFrameLevel) == "function" then
      widget._frameLevel = parent:GetFrameLevel() + 1
    else
      widget._frameLevel = 0
    end
  end

  widget._attributes = {}
  if widgetType == "ItemButton" then
    _G.__mockItemButtonParts(widget, true)
  end
  return widget
end

_G.IsAccountSecured = function() return true end

-- C_AddOns.IsAddOnLoaded(name) -> loadedOrLoading, loaded (AddOnsDocumentation.lua, every client).
-- Specs mark an addon loaded with _G._loadedAddOns[name] = true.
_G.C_AddOns = _G.C_AddOns or {}
_G.C_AddOns.IsAddOnLoaded = function(name)
  local loaded = (_G._loadedAddOns or {})[name] == true
  return loaded, loaded
end

_G.ContainerFrame_GetContainerNumSlots = function(bagID)
  local numSlots = _G.C_Container and _G.C_Container.GetContainerNumSlots(bagID) or 16
  return bagID, numSlots
end

-- The parts of an item button (Blizzard_ItemButton ItemButtonTemplate.xml): the ItemButton
-- intrinsic on retail and WoW: Forever (Shared, mixin ItemButtonMixin), ItemButtonTemplate on Classic
-- (Classic, no mixin). Both: icon, Count (NumberFontNormal, hidden), searchOverlay and IconBorder
-- (WhiteIconFrame), both hidden, and IconOverlay. The intrinsic adds ItemContextOverlay and
-- ItemButtonMixin's SetMatchesSearch / GetMatchesSearch: a button that does not match shows its
-- ItemContextOverlay (UpdateItemContextOverlay, the Standard mode: black at 0.8).
function _G.__mockItemButtonParts(button, intrinsic)
  -- Anchored as the XML anchors them (Shared/ItemButtonTemplate.xml): the icon, with no anchor and no size,
  -- fills the button; the count at the bottom right, -5, 2; the stock at the top left, 0, -2; the search
  -- overlay all over; the border and the overlays 37 x 37 at the middle.
  button.icon = button:CreateTexture(nil, "BORDER")
  button.icon:SetAllPoints(button)
  button.Count = button:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
  button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 2)
  button.Count:Hide()
  button.Stock = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalYellow")
  button.Stock:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -2)
  button.Stock:Hide()
  button.searchOverlay = button:CreateTexture(nil, "OVERLAY")
  button.searchOverlay:SetAllPoints(button)
  button.searchOverlay:Hide()
  button.IconBorder = button:CreateTexture(nil, "OVERLAY")
  button.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
  button.IconBorder:SetSize(37, 37)
  button.IconBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.IconBorder:Hide()
  button.IconOverlay = button:CreateTexture(nil, "OVERLAY")
  button.IconOverlay:SetSize(37, 37)
  button.IconOverlay:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.IconOverlay:Hide()
  button.IconOverlay2 = button:CreateTexture(nil, "OVERLAY")
  button.IconOverlay2:SetSize(37, 37)
  button.IconOverlay2:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.IconOverlay2:Hide()
  if intrinsic then
    button.ItemContextOverlay = button:CreateTexture(nil, "OVERLAY")
    button.ItemContextOverlay:SetAllPoints(button)
    button.ItemContextOverlay:Hide()
    function button:SetMatchesSearch(matchesSearch)
      self.matchesSearch = matchesSearch
      self.ItemContextOverlay:SetShown(matchesSearch == false)
    end
    function button:GetMatchesSearch()
      return self.matchesSearch
    end
  end
end

-- Templates a mocked frame can inherit. CreateFrame applies each template named in its
-- comma-separated template list, so a frame gets the regions and mixin methods its XML
-- template gives it in the client. Each entry is built from Blizzard's own template.
_G.__mockTemplates = _G.__mockTemplates or {}

_G.__mockTemplates.ItemButtonTemplate = function(frame)
  _G.__mockItemButtonParts(frame, false)
end

-- UIPanelButtonTemplate (Blizzard_SharedXML/SecureUIPanelTemplates.xml, UIPanelButtonNoTooltipTemplate,
-- which it inherits): 40 x 22; its art in three pieces of UI-Panel-Button-Up, Left and Right 12 wide down
-- its ends, Middle between them; its text (ButtonText, parentKey Text) in GameFontNormal at its middle (a
-- ButtonText the XML gives no anchor is centered by the client); its highlight filling it.
_G.__mockTemplates.UIPanelButtonTemplate = function(frame)
  frame:SetSize(40, 22)
  local function piece(key, coords)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    t:SetSize(12, 22)
    frame[key] = t
    return t
  end
  local left = piece("Left", { 0, 0.09375, 0, 0.6875 })
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local right = piece("Right", { 0.53125, 0.625, 0, 0.6875 })
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local middle = piece("Middle", { 0.09375, 0.53125, 0, 0.6875 })
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.Text = text
  frame:SetFontString(text)
  frame:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
  frame:GetHighlightTexture():SetAllPoints(frame)
end

-- WowScrollBox (Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua, ScrollBox.xml): a ScrollTarget
-- child frame; Init(view) sets the view and scrolls to the beginning; SetView(view) binds the
-- view (ScrollBoxViewMixin:SetScrollBox anchors the scroll target), reparents every child
-- marked scrollable under the scroll target (ScrollBoxLinearViewMixin:ReparentScrollChildren)
-- and lays them out (ScrollBoxViewUtil.SetPoint: TOPLEFT, and TOPRIGHT unless stretch is
-- disabled). FullUpdate(immediately) lays them out again; SetPanExtent forwards to the view;
-- SetInterpolateScroll comes from ScrollControllerMixin.
_G.__mockTemplates.WowScrollBox = function(frame)
  frame.ScrollTarget = CreateMockWidget("EventFrame", nil, frame)
  function frame:GetScrollTarget() return self.ScrollTarget end
  function frame:GetView() return self.view end
  function frame:SetInterpolateScroll(canInterpolate) self._interpolateScroll = canInterpolate end
  function frame:SetPanExtent(panExtent) self:GetView():SetPanExtent(panExtent) end
  function frame:layoutScrollChildren()
    local target = self:GetScrollTarget()
    for _, child in ipairs(self.view and self.view.frames or {}) do
      child:ClearAllPoints()
      child:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
      child:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)
    end
  end
  function frame:SetView(view)
    if not view then
      error("ScrollBoxBaseMixin:SetView requires a valid view.")
    end
    if type(view.SetScrollBox) ~= "function" or type(view.IsHorizontal) ~= "function" then
      error("ScrollBoxBaseMixin:SetView requires a valid view.")
    end
    self.view = view
    view:SetScrollBox(self)
    view:ReparentScrollChildren(self:GetChildren())
    self:layoutScrollChildren()
  end
  function frame:Init(view)
    self:SetView(view)
    self._scrolledToBegin = true
  end
  -- CallbackRegistryMixin (CallbackRegistry.lua): RegisterCallback(event, func, owner) keeps one
  -- callback per owner per event; TriggerEvent(event, ...) calls each as func(owner, ...).
  frame._callbacks = {}
  function frame:RegisterCallback(event, func, owner)
    self._callbacks[event] = self._callbacks[event] or {}
    self._callbacks[event][owner or func] = func
    return owner
  end
  function frame:UnregisterCallback(event, owner)
    if self._callbacks[event] then self._callbacks[event][owner] = nil end
  end
  function frame:TriggerEvent(event, ...)
    local list = {}
    for owner, func in pairs(self._callbacks[event] or {}) do list[#list + 1] = { owner, func } end
    for _, entry in ipairs(list) do entry[2](entry[1], ...) end
  end
  -- ScrollBoxBaseMixin (ScrollBox.lua): GetDerivedExtent() is the view's extent (here, the
  -- scrollable children's heights; specs may set _extent), GetVisibleExtent() the box's own height,
  -- rounded; GetDerivedScrollRange() the extent less the visible extent (specs may set
  -- _scrollRange), GetDerivedScrollOffset() range * scroll percentage; GetVisibleExtentPercentage()
  -- visible / extent (0 without an extent); HasScrollableExtent() that percentage strictly between
  -- 0 and 1; GetPanExtent() the view's pan extent, CalculatePanExtentPercentage() it over the range.
  function frame:GetDerivedExtent()
    if self._extent ~= nil then return self._extent end
    local extent = 0
    for _, child in ipairs(self.view and self.view.frames or {}) do extent = extent + (child:GetHeight() or 0) end
    return extent
  end
  function frame:GetVisibleExtent() return math.floor((self:GetHeight() or 0) + 0.5) end
  function frame:GetDerivedScrollRange()
    if self._scrollRange ~= nil then return self._scrollRange end
    return math.max(0, self:GetDerivedExtent() - self:GetVisibleExtent())
  end
  function frame:GetDerivedScrollOffset() return self:GetDerivedScrollRange() * (self._scrollPercentage or 0) end
  function frame:GetVisibleExtentPercentage()
    local extent = self:GetDerivedExtent()
    if extent > 0 then return self:GetVisibleExtent() / extent end
    return 0
  end
  function frame:HasScrollableExtent()
    local p = self:GetVisibleExtentPercentage()
    return p > 0.0001 and p < 0.9999
  end
  function frame:GetPanExtent() return self.view and self.view._panExtent or 0 end
  function frame:CalculatePanExtentPercentage()
    local range = self:GetDerivedScrollRange()
    if range > 0 then return self:GetPanExtent() / range end
    return 0
  end
  -- ScrollControllerMixin: GetScrollPercentage(); SetScrollPercentage(percentage, noInterpolation)
  -- saturates it, and ScrollBoxBaseMixin sends OnScroll(percentage, visible extent percentage, pan
  -- extent percentage) as it moves the scroll target (SetScrollTargetOffset); here at once, the
  -- last call's noInterpolation kept in _noInterpolation. ScrollToOffset(offset, noInterpolation):
  -- nothing without a range, else that percentage. ScrollInDirection(percentage, direction) moves
  -- by percentage (Directions: Increase 1, Decrease -1) unless scrolling is not allowed;
  -- SetScrollAllowed sends OnAllowScrollChanged when it changes.
  function frame:GetScrollPercentage() return self._scrollPercentage or 0 end
  function frame:sendScroll()
    self:TriggerEvent(BaseScrollBoxEvents.OnScroll, self:GetScrollPercentage(), self:GetVisibleExtentPercentage(),
      self:CalculatePanExtentPercentage())
  end
  -- ScrollBoxBaseMixin:SetScrollTargetOffset(offset): the scroll target TOPLEFT and TOPRIGHT of the box,
  -- offset up (a linear view without padding), then OnScroll. ScrollBoxMixin:Update calls it with the
  -- derived scroll offset (less the view's upper padding, none here) every time the box scrolls or lays
  -- out (ScrollBox.lua).
  function frame:SetScrollTargetOffset(offset)
    local target = self:GetScrollTarget()
    target:SetPoint("TOPLEFT", self, "TOPLEFT", 0, offset)
    target:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, offset)
    self:sendScroll()
  end
  function frame:SetScrollPercentage(percentage, noInterpolation)
    self._noInterpolation = noInterpolation
    self._scrollPercentage = math.max(0, math.min(1, percentage))
    self:SetScrollTargetOffset(self:GetDerivedScrollOffset())
  end
  function frame:ScrollToOffset(offset, noInterpolation)
    local range = self:GetDerivedScrollRange()
    if range > 0 then
      self:SetScrollPercentage(offset / range, noInterpolation)
    end
  end
  function frame:IsScrollAllowed() return self._allowScroll ~= false end
  function frame:SetScrollAllowed(allowScroll)
    local old = self:IsScrollAllowed()
    self._allowScroll = allowScroll
    if old ~= allowScroll then self:TriggerEvent(BaseScrollBoxEvents.OnAllowScrollChanged, allowScroll) end
  end
  function frame:ScrollInDirection(percentage, direction)
    if not self:IsScrollAllowed() then return end
    self:SetScrollPercentage(self:GetScrollPercentage() + percentage * direction)
  end
  -- FullUpdate lays the children out again, which places the scroll target (OnScroll).
  function frame:FullUpdate(immediately)
    self._fullUpdates = (self._fullUpdates or 0) + 1
    self._lastFullUpdateImmediate = immediately
    self:layoutScrollChildren()
    self:SetScrollTargetOffset(self:GetDerivedScrollOffset())
  end
end

-- BaseScrollBoxEvents (ScrollBox.lua, CopyValuesAsKeys) and ScrollControllerMixin.Directions
-- (ScrollController.lua).
_G.BaseScrollBoxEvents = { OnAllowScrollChanged = "OnAllowScrollChanged", OnSizeChanged = "OnSizeChanged",
  OnScroll = "OnScroll", OnLayout = "OnLayout" }
_G.ScrollControllerMixin = _G.ScrollControllerMixin or {}
_G.ScrollControllerMixin.Directions = { Increase = 1, Decrease = -1 }

-- WowScrollBoxList (Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml: ScrollBoxBaseTemplate
-- with ScrollBoxListMixin): a scroll box whose view holds a data provider. Init(view) sets the
-- view; SetDataProvider(provider) and GetDataProvider() go through the view (a view is required
-- first); ScrollToEnd() sets the scroll percentage to 1 (ScrollBoxBaseMixin);
-- SetInterpolateScroll comes from ScrollControllerMixin.
_G.__mockTemplates.WowScrollBoxList = function(frame)
  function frame:Init(view) self.view = view end
  function frame:GetView() return self.view end
  function frame:SetDataProvider(provider)
    if not self.view then
      error("A view is required before assigning the data provider.")
    end
    self.view.dataProvider = provider
  end
  function frame:GetDataProvider() return self.view.dataProvider end
  function frame:ScrollToEnd() self._scrollPercentage = 1 end
  function frame:SetInterpolateScroll(canInterpolate) self._interpolateScroll = canInterpolate end
end

-- CreateScrollBoxListLinearView() (Blizzard_SharedXML/Shared/Scroll/ScrollBoxListLinearView.lua):
-- the setters BetterBags' list frame calls keep their values.
_G.CreateScrollBoxListLinearView = function()
  local view = {}
  function view:SetElementInitializer(template, initializer) self.template, self.initializer = template, initializer end
  function view:SetElementResetter(resetter) self.resetter = resetter end
  function view:SetPadding(top, bottom, left, right, spacing) self.padding = { top, bottom, left, right, spacing } end
  function view:SetExtent(extent) self.extent = extent end
  return view
end

-- DataProviderMixin and CreateDataProvider(tbl) (Blizzard_SharedXML/DataProvider.lua): a list of
-- element data with callbacks (CallbackRegistryMixin; its event names map to themselves,
-- GenerateCallbackEvents). Inserting triggers OnInsert, then OnSizeChanged; removing OnRemove,
-- then OnSizeChanged; Flush OnRemove for each element, then OnSizeChanged.
_G.DataProviderMixin = { Event = { OnSizeChanged = "OnSizeChanged", OnInsert = "OnInsert",
  OnRemove = "OnRemove", OnSort = "OnSort", OnMove = "OnMove" } }
_G.CreateDataProvider = function(tbl)
  local provider = { collection = {}, callbacks = {} }
  function provider:RegisterCallback(event, func, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], { func = func, owner = owner })
  end
  function provider:TriggerEvent(event, ...)
    for _, cb in ipairs(self.callbacks[event] or {}) do
      cb.func(cb.owner, ...)
    end
  end
  function provider:Enumerate() return ipairs(self.collection) end
  function provider:GetCollection() return self.collection end
  function provider:GetSize() return #self.collection end
  function provider:IsEmpty() return #self.collection == 0 end
  function provider:InsertAtIndex(elementData, index)
    if index == nil then
      table.insert(self.collection, elementData)
      index = #self.collection
    else
      table.insert(self.collection, index, elementData)
    end
    self:TriggerEvent("OnInsert", index, elementData, false)
    self:TriggerEvent("OnSizeChanged", false)
  end
  function provider:Insert(...)
    for i = 1, select("#", ...) do
      local elementData = select(i, ...)
      table.insert(self.collection, elementData)
      self:TriggerEvent("OnInsert", #self.collection, elementData, false)
    end
    if select("#", ...) > 0 then self:TriggerEvent("OnSizeChanged", false) end
  end
  function provider:InsertTable(t)
    for _, elementData in ipairs(t) do
      table.insert(self.collection, elementData)
      self:TriggerEvent("OnInsert", #self.collection, elementData, false)
    end
    if #t > 0 then self:TriggerEvent("OnSizeChanged", false) end
  end
  function provider:RemoveIndex(index)
    local elementData = table.remove(self.collection, index)
    if elementData ~= nil then
      self:TriggerEvent("OnRemove", elementData, index)
      self:TriggerEvent("OnSizeChanged", false)
    end
  end
  function provider:Find(index) return self.collection[index] end
  function provider:FindIndex(elementData)
    for index, e in ipairs(self.collection) do
      if e == elementData then return index, e end
    end
  end
  function provider:FindByPredicate(predicate)
    for index, e in ipairs(self.collection) do
      if predicate(e) then return index, e end
    end
  end
  function provider:ContainsByPredicate(predicate) return self:FindByPredicate(predicate) ~= nil end
  function provider:ForEach(func)
    for _, e in ipairs(self.collection) do func(e) end
  end
  function provider:Flush()
    local old = self.collection
    self.collection = {}
    for index, elementData in ipairs(old) do self:TriggerEvent("OnRemove", elementData, index) end
    self:TriggerEvent("OnSizeChanged", false)
  end
  if tbl then provider:InsertTable(tbl) end
  return provider
end

-- MinimalScrollBar (Blizzard_SharedXML/Shared/Scroll/ScrollBar.lua, ScrollBarMixin):
-- SetHideIfUnscrollable(hide), SetInterpolateScroll(canInterpolateScroll).
_G.__mockTemplates.MinimalScrollBar = function(frame)
  function frame:SetHideIfUnscrollable(hide) self._hideIfUnscrollable = hide end
  function frame:SetInterpolateScroll(canInterpolate) self._interpolateScroll = canInterpolate end
end

-- UITextureConstantsDocumentation.lua: Enum.UITextureSliceMode.
_G.Enum.UITextureSliceMode = { Stretched = 0, Tiled = 1 }

-- Font objects (SimpleFontAPIDocumentation.lua; CreateFont(name) in FontDocumentation.lua):
-- SetFont/GetFont, SetTextColor/GetTextColor, SetShadowColor/GetShadowColor,
-- SetShadowOffset/GetShadowOffset, SetJustifyH/GetJustifyH, SetFontObject/CopyFontObject.
local function CreateMockFont(name)
  local font = { _name = name, _color = { 1, 1, 1, 1 }, _shadowColor = { 0, 0, 0, 0 }, _shadowOffset = { 0, 0 } }
  function font:GetName() return self._name end
  function font:SetFont(path, height, flags) self._path, self._height, self._flags = path, height, flags end
  function font:GetFont() return self._path, self._height, self._flags end
  function font:SetTextColor(r, g, b, a) self._color = { r, g, b, a or 1 } end
  function font:GetTextColor() return unpack(self._color) end
  function font:SetShadowColor(r, g, b, a) self._shadowColor = { r, g, b, a or 1 } end
  function font:GetShadowColor() return unpack(self._shadowColor) end
  function font:SetShadowOffset(x, y) self._shadowOffset = { x, y } end
  function font:GetShadowOffset() return unpack(self._shadowOffset) end
  -- Font:SetFontHeight(height) / GetFontHeight() (SimpleFontAPIDocumentation.lua); Blizzard's
  -- Text Size setting rescales the client fonts with it (TextSizeManager.lua).
  function font:SetFontHeight(height) self._height = height end
  function font:GetFontHeight() return self._height end
  function font:SetJustifyH(justify) self._justifyH = justify end
  function font:GetJustifyH() return self._justifyH or "CENTER" end
  function font:CopyFontObject(other)
    self._path, self._height, self._flags = other:GetFont()
    self._color = { other:GetTextColor() }
    self._shadowColor = { other:GetShadowColor() }
    self._shadowOffset = { other:GetShadowOffset() }
    self._justifyH = other._justifyH
  end
  font.SetFontObject = font.CopyFontObject
  if name then _G[name] = font end
  return font
end
_G.CreateFont = CreateMockFont

-- EventRegistry (Blizzard_SharedXMLBase/GlobalCallbackRegistry.lua, CallbackRegistryMixin in
-- CallbackRegistry.lua): RegisterCallback(event, func, owner?) keeps one callback per owner
-- per event (registering again replaces it) and returns the owner; TriggerEvent(event, ...)
-- calls each func(owner, ...); UnregisterCallback(event, owner). Undefined events are allowed.
do
  local callbacks = {}
  local nextOwner = 0
  _G.EventRegistry = {
    RegisterCallback = function(_, event, func, owner)
      if owner == nil then
        nextOwner = nextOwner + 1
        owner = nextOwner
      end
      callbacks[event] = callbacks[event] or {}
      callbacks[event][owner] = func
      return owner
    end,
    UnregisterCallback = function(_, event, owner)
      if callbacks[event] then
        callbacks[event][owner] = nil
      end
    end,
    TriggerEvent = function(_, event, ...)
      local list = {}
      for owner, func in pairs(callbacks[event] or {}) do
        table.insert(list, { owner, func })
      end
      for _, entry in ipairs(list) do
        entry[2](entry[1], ...)
      end
    end,
  }
end

-- CreateColor(r, g, b, a?) -> a ColorMixin (Blizzard_SharedXMLBase/Color.lua).
_G.CreateColor = _G.CreateColor or function(r, g, b, a)
  local color = { r = r, g = g, b = b, a = a }
  function color:GetRGB() return self.r, self.g, self.b end
  function color:GetRGBA() return self.r, self.g, self.b, self.a end
  function color:SetRGBA(nr, ng, nb, na) self.r, self.g, self.b, self.a = nr, ng, nb, na end
  return color
end

-- The font files of the default locale (Blizzard_Fonts_Shared/Shared/GameFonts.xml).
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.UNIT_NAME_FONT = "Fonts\\FRIZQT__.TTF"
_G.DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- The client font objects BetterBags uses (Blizzard_Fonts_Shared FontStyles.xml / Fonts.xml):
-- the font file, height, outline, shadow and NORMAL_FONT_COLOR (1, 0.82, 0),
-- HIGHLIGHT/WHITE (1, 1, 1), DISABLED (0.5, 0.5, 0.5) colors their templates inherit.
local function clientFont(name, path, height, flags, color, shadow)
  local font = CreateMockFont(name)
  font:SetFont(path, height, flags or "")
  font:SetTextColor(color[1], color[2], color[3], 1)
  if shadow then
    font:SetShadowColor(0, 0, 0, 1)
    font:SetShadowOffset(1, -1)
  end
  return font
end
local NORMAL = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local DISABLED = { 0.5, 0.5, 0.5 }
clientFont("GameFontNormal", "Fonts\\FRIZQT__.TTF", 12, "", NORMAL, true)
clientFont("GameFontHighlight", "Fonts\\FRIZQT__.TTF", 12, "", WHITE, true)
clientFont("GameFontDisable", "Fonts\\FRIZQT__.TTF", 12, "", DISABLED, true)
clientFont("GameFontNormalSmall", "Fonts\\FRIZQT__.TTF", 10, "", NORMAL, true)
clientFont("GameFontHighlightSmall", "Fonts\\FRIZQT__.TTF", 10, "", WHITE, true)
clientFont("GameFontDisableSmall", "Fonts\\FRIZQT__.TTF", 10, "", DISABLED, true)
clientFont("NumberFontNormal", "Fonts\\ARIALN.TTF", 14, "OUTLINE", WHITE, false)
clientFont("ChatFontNormal", "Fonts\\ARIALN.TTF", 14, "", WHITE, true)
-- GameFontWhite inherits GameFontBlack (SystemFont_Med1, FRIZQT__ 12, no shadow) with white.
clientFont("GameFontWhite", "Fonts\\FRIZQT__.TTF", 12, "", WHITE, false)
-- GameFontNormalLarge inherits SystemFont_Shadow_Large (FRIZQT__ 16, black shadow) in gold;
-- Number12Font is ARIALN 12 with no color or shadow (GameFonts.xml); NumberFontNormalRight is
-- NumberFontNormal justified right.
clientFont("GameFontNormalLarge", "Fonts\\FRIZQT__.TTF", 16, "", NORMAL, true)
-- GameFontBlack inherits SystemFont_Med1 (FRIZQT__ 12, no shadow) in black.
clientFont("GameFontBlack", "Fonts\\FRIZQT__.TTF", 12, "", { 0, 0, 0 }, false)
-- GameFontNormalHuge inherits SystemFont_Shadow_Huge1 (FRIZQT__ 20, black shadow) in gold.
clientFont("GameFontNormalHuge", "Fonts\\FRIZQT__.TTF", 20, "", NORMAL, true)
clientFont("Number12Font", "Fonts\\ARIALN.TTF", 12, "", WHITE, false)
clientFont("NumberFontNormalRight", "Fonts\\ARIALN.TTF", 14, "OUTLINE", WHITE, false):SetJustifyH("RIGHT")

-- Mixin(object, ...) copies every key of each mixin into object (Blizzard_SharedXMLBase).
_G.Mixin = function(object, ...)
  for i = 1, select("#", ...) do
    for k, v in pairs((select(i, ...))) do
      object[k] = v
    end
  end
  return object
end

-- BackdropTemplateMixin (Blizzard_SharedXML/Backdrop.lua): only frames that inherit
-- BackdropTemplate (or mix it in) have a backdrop. SetBackdrop(info) ignores the table it
-- already shows, clears the backdrop for nil or an info with neither bgFile nor edgeFile,
-- and otherwise applies it with both colors reset to white; SetBackdropColor and
-- SetBackdropBorderColor do nothing without a backdrop.
_G.BackdropTemplateMixin = {
  SetBackdrop = function(self, backdropInfo)
    if backdropInfo then
      if self._backdrop == backdropInfo then
        return
      end
      if not backdropInfo.edgeFile and not backdropInfo.bgFile then
        self:ClearBackdrop()
        return
      end
      self._backdrop = backdropInfo
      self._backdropColor = { r = 1, g = 1, b = 1, a = 1 }
      self._backdropBorderColor = { r = 1, g = 1, b = 1, a = 1 }
    else
      self:ClearBackdrop()
    end
  end,
  ClearBackdrop = function(self)
    self._backdrop = nil
    self._backdropColor = nil
    self._backdropBorderColor = nil
  end,
  GetBackdrop = function(self)
    return self._backdrop
  end,
  SetBackdropColor = function(self, r, g, b, a)
    if not self._backdrop then return end
    self._backdropColor = { r = r, g = g, b = b, a = a or 1 }
  end,
  GetBackdropColor = function(self)
    local c = self._backdropColor
    if c then return c.r, c.g, c.b, c.a end
  end,
  SetBackdropBorderColor = function(self, r, g, b, a)
    if not self._backdrop then return end
    self._backdropBorderColor = { r = r, g = g, b = b, a = a or 1 }
  end,
  GetBackdropBorderColor = function(self)
    local c = self._backdropBorderColor
    if c then return c.r, c.g, c.b, c.a end
  end,
}

-- BackdropTemplate (Blizzard_SharedXML/Backdrop.xml): mixin="BackdropTemplateMixin".
_G.__mockTemplates.BackdropTemplate = function(frame)
  frame._backdropTemplate = true
  Mixin(frame, BackdropTemplateMixin)
end

-- TooltipBackdropTemplate (Blizzard_SharedXML/SharedTooltipTemplates.xml/.lua, every client
-- branch): not a BackdropTemplate. A NineSlice frame (useParentLevel) and
-- TooltipBackdropTemplateMixin, whose SetBackdropColor / SetBackdropBorderColor color the
-- NineSlice; OnLoad sets the center color (backdropColorAlpha, default 1).
-- TooltipBorderedFrameTemplate sets backdropColorAlpha to 0.8.
_G.__mockTemplates.TooltipBackdropTemplate = function(frame)
  frame.NineSlice = CreateMockWidget("Frame", nil, frame)
  frame.NineSlice:SetFrameLevel(frame:GetFrameLevel())
  function frame:SetBackdropColor(r, g, b, a) self._backdropColor = { r = r, g = g, b = b, a = a or 1 } end
  function frame:SetBackdropBorderColor(r, g, b, a) self._backdropBorderColor = { r = r, g = g, b = b, a = a or 1 } end
  function frame:GetBackdropColor()
    local c = self._backdropColor
    if c then return c.r, c.g, c.b, c.a end
  end
  function frame:GetBackdropBorderColor()
    local c = self._backdropBorderColor
    if c then return c.r, c.g, c.b, c.a end
    return 1, 1, 1, 1
  end
  frame:SetBackdropColor(0, 0, 0, frame.backdropColorAlpha or 1)
end
_G.__mockTemplates.TooltipBorderedFrameTemplate = function(frame)
  frame.backdropColorAlpha = 0.8
  _G.__mockTemplates.TooltipBackdropTemplate(frame)
end

-- DefaultPanelBaseTemplate (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml): a
-- TitleContainer frame (frameLevel 510) holding the TitleText font string, and a NineSlice
-- frame; DefaultPanelMixin (TitledPanelMixin, Blizzard_SharedXML/PortraitFrame.lua) gives
-- GetTitleText and SetTitle.
local function defaultPanelBase(frame)
  local titleContainer = CreateMockWidget("Frame", nil, frame)
  titleContainer:SetFrameLevel(510)
  titleContainer.TitleText = titleContainer:CreateFontString(frame._name and (frame._name .. "TitleText") or nil, "OVERLAY", "GameFontNormal")
  frame.TitleContainer = titleContainer
  frame.NineSlice = CreateMockWidget("Frame", nil, frame)
  function frame:GetTitleText() return self.TitleContainer.TitleText end
  function frame:SetTitle(title) self:GetTitleText():SetText(title) end
end

-- DefaultPanelTemplate: a tiled rock Bg texture (BACKGROUND -6) and TopTileStreaks.
_G.__mockTemplates.DefaultPanelTemplate = function(frame)
  defaultPanelBase(frame)
  frame.Bg = frame:CreateTexture(frame._name and (frame._name .. "Bg") or nil, "BACKGROUND")
  frame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
  frame.TopTileStreaks = frame:CreateTexture(nil, "BACKGROUND")
end

-- DefaultPanelFlatTemplate: a Bg frame (FlatPanelBackgroundTemplate) at frameLevel 0.
_G.__mockTemplates.DefaultPanelFlatTemplate = function(frame)
  defaultPanelBase(frame)
  frame.Bg = CreateMockWidget("Frame", nil, frame)
  frame.Bg:SetFrameLevel(0)
end

-- UIPanelCloseButtonNoScripts (SharedUIPanelTemplates.xml): 24x24, frameLevel 510, red exit
-- atlases; UIPanelCloseButton adds an OnClick that hides the parent; ...DefaultAnchors
-- anchors it TOPRIGHT x=1.
_G.__mockTemplates.UIPanelCloseButtonNoScripts = function(frame)
  frame:SetSize(24, 24)
  frame:SetFrameLevel(510)
  frame:SetDisabledAtlas("RedButton-Exit-Disabled")
  frame:SetNormalAtlas("RedButton-Exit")
  frame:SetPushedAtlas("RedButton-exit-pressed")
  frame:SetHighlightAtlas("RedButton-Highlight", "ADD")
end
_G.__mockTemplates.UIPanelCloseButton = function(frame)
  _G.__mockTemplates.UIPanelCloseButtonNoScripts(frame)
  frame:SetScript("OnClick", function(self) self:GetParent():Hide() end)
end
_G.__mockTemplates.UIPanelCloseButtonDefaultAnchors = function(frame)
  _G.__mockTemplates.UIPanelCloseButton(frame)
  frame:SetPoint("TOPRIGHT", frame:GetParent(), "TOPRIGHT", 1, 0)
end

-- InputBoxTemplate = InputBoxScriptTemplate + InputBoxVisualTemplate (Blizzard_SharedXML/Shared/
-- InputBox/InputBoxTemplates.xml): the Left, Right and Middle border textures, and the box's font
-- declared in XML with <FontString inherits="ChatFontNormal"/>. What the 12.1.5 client does with
-- that font is from a crash report (issue #1152): after SetFontObject("GameFontHighlight"), the
-- box's GetFontObject() returned an unnamed font object, not GameFontHighlight, and
-- SetFontObject() with that object overflowed the client's stack inside the call. The mock's box
-- reports an unnamed font of its own (with the look of the font it was given) and raises a stack
-- overflow when it is handed back. Blizzard's code never hands an edit box its own font object.
_G.__mockTemplates.InputBoxTemplate = function(frame)
  frame.Left = frame:CreateTexture(nil, "BACKGROUND")
  frame.Left:SetAtlas("common-search-border-left")
  frame.Right = frame:CreateTexture(nil, "BACKGROUND")
  frame.Right:SetAtlas("common-search-border-right")
  frame.Middle = frame:CreateTexture(nil, "BACKGROUND")
  frame.Middle:SetAtlas("common-search-border-middle")
  frame._fontObject = _G.ChatFontNormal
  local function parent()
    local fo = frame._fontObject
    if type(fo) == "string" then
      fo = _G[fo]
    end
    return fo
  end
  frame._ownFont = {
    GetName = function() return nil end,
    GetFont = function() return parent():GetFont() end,
    GetTextColor = function() return parent():GetTextColor() end,
    GetShadowColor = function() return parent():GetShadowColor() end,
    GetShadowOffset = function() return parent():GetShadowOffset() end,
    GetJustifyH = function() return parent():GetJustifyH() end,
  }
end

_G.CreateFrame = function(frameType, name, parent, template)
  local frame = CreateMockWidget(frameType, name, parent)
  if name then
    _G[name] = frame
  end
  if type(template) == "string" then
    frame._template = template
    for templateName in string.gmatch(template, "[^,%s]+") do
      local apply = _G.__mockTemplates[templateName]
      if apply then
        apply(frame)
      end
    end
  end
  return frame
end

-- CreateScrollBoxLinearView(top, bottom, left, right, spacing) -> a ScrollBoxLinearViewMixin
-- (Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua, ScrollBoxView.lua): SetPanExtent,
-- SetScrollBox (anchors the scroll target TOPLEFT and TOPRIGHT), GetScrollBox, GetScrollTarget,
-- IsHorizontal, GetFrames, and ReparentScrollChildren(...), which moves every child marked
-- scrollable under the scroll target.
_G.CreateScrollBoxLinearView = function(top, bottom, left, right, spacing)
  return {
    frames = {},
    _padding = { top = top or 0, bottom = bottom or 0, left = left or 0, right = right or 0, spacing = spacing or 0 },
    SetPanExtent = function(self, panExtent) self._panExtent = panExtent end,
    SetScrollBox = function(self, scrollBox)
      self.scrollBox = scrollBox
      local target = scrollBox:GetScrollTarget()
      target:ClearAllPoints()
      target:SetPoint("TOPLEFT")
      target:SetPoint("TOPRIGHT")
    end,
    GetScrollBox = function(self) return self.scrollBox end,
    GetScrollTarget = function(self) return self:GetScrollBox():GetScrollTarget() end,
    IsHorizontal = function() return false end,
    GetFrames = function(self) return self.frames end,
    ReparentScrollChildren = function(self, ...)
      local scrollTarget = self:GetScrollTarget()
      for index = 1, select("#", ...) do
        local child = select(index, ...)
        if child.scrollable then
          child:SetParent(scrollTarget)
          table.insert(self.frames, child)
        end
      end
    end,
  }
end

-- ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, scrollBoxView)
-- (Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua): binds the bar to the box, then
-- scrollBox:Init(scrollBoxView).
_G.ScrollUtil = {}
_G.ScrollUtil.InitScrollBoxWithScrollBar = function(scrollBox, scrollBar, view)
  scrollBox._scrollBar = scrollBar
  scrollBox:Init(view)
end

-- ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view) binds the bar and
-- initializes the box with the view, as InitScrollBoxWithScrollBar does (ScrollUtil.lua);
-- ScrollUtil.InitDefaultLinearDragBehavior(scrollBox) returns the box's drag behavior
-- (ScrollBoxDragBehavior), whose setters keep their values: SetReorderable, SetDragPredicate,
-- SetDropPredicate, SetFinalizeDrop.
_G.ScrollUtil.InitScrollBoxListWithScrollBar = function(scrollBox, scrollBar, view)
  scrollBox._scrollBar = scrollBar
  scrollBox:Init(view)
end
_G.ScrollUtil.InitDefaultLinearDragBehavior = function(scrollBox)
  local behavior = { scrollBox = scrollBox, reorderable = false }
  function behavior:SetReorderable(canReorder) self.reorderable = canReorder end
  function behavior:SetDragPredicate(predicate) self.dragPredicate = predicate end
  function behavior:SetDropPredicate(predicate) self.dropPredicate = predicate end
  function behavior:SetFinalizeDrop(finalize) self.finalizeDrop = finalize end
  return behavior
end

-- hooksecurefunc([table,] name, hook): replaces the function with one that calls the original,
-- then the hook with the same arguments, and returns what the original returned
-- (warcraft.wiki.gg API_hooksecurefunc).
_G.hooksecurefunc = function(tbl, name, hook)
  if type(tbl) == "string" then
    tbl, name, hook = _G, tbl, name
  end
  local original = tbl[name]
  tbl[name] = function(...)
    local results = { original(...) }
    hook(...)
    return unpack(results)
  end
end
-- ShowUIPanel(frame, force) and HideUIPanel(frame) (UIParentPanelManager): the panel manager places
-- the frame among the open panels and shows it, or hides it. Specs only see the show and the hide.
_G.ShowUIPanel = function(frame)
  if frame then frame:Show() end
end
_G.HideUIPanel = function(frame)
  if frame then frame:Hide() end
end
-- issecurevariable([tbl,] variable) -> isSecure, taint (warcraft.wiki.gg API_issecurevariable):
-- true, nil for a key nothing has tainted, which is every key in specs (they model no taint).
-- AceHook reads it to refuse raw hooks of secure functions.
_G.issecurevariable = function()
  return true, nil
end
_G.UIParent = CreateMockWidget("Frame", "UIParent")
_G.UIParent:SetSize(1920, 1200)
-- UIParent's effective scale is its own scale, the UI scale (it has no parent that scales it).
function _G.UIParent:GetEffectiveScale()
  return self:GetScale()
end

_G.C_Timer = {
  After = function(_, _) end,
  NewTimer = function(_, _)
    return { Cancel = function() end }
  end,
}
_G.IsLoggedIn = function() return true end
_G.SlashCmdList = {}
_G.hash_SlashCmdList = {}
_G.GetLocale = function() return "enUS" end
-- Blizzard_Fonts_Shared/Shared/GameFonts.xml sets the locale's font file at load; this is
-- the roman (enUS) branch, matching GetLocale above.
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.GetBuildInfo = function() return "10.0.0", "12345", "Jan 1 2024", 100000 end
_G.GetRealmName = function() return "TestRealm" end
_G.UnitName = function() return "TestChar", "TestRealm" end
-- UnitDocumentation.lua: UnitNameUnmodified(unit) -> unitName, unitServer (read by AceDB-3.0 r1417+).
_G.UnitNameUnmodified = function() return "TestChar", "TestRealm" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.UnitRace = function() return "Human", "Human" end
_G.GetCurrentRegion = function() return 1 end
_G.GetCurrentRegionName = function() return "US" end

-- Error handling and secure call wrappers
_G.geterrorhandler = function()
  return function(err) return err end
end
-- securecallfunction(func, ...) and securecall(func or name, ...): an error in the function is not
-- passed to the caller; it goes to the default error handler and the call returns nothing,
-- otherwise the call returns what the function returned (warcraft.wiki.gg API:securecall).
-- CallbackHandler dispatches every AceEvent message and event through it.
_G.securecallfunction = function(fn, ...)
  local results = { pcall(fn, ...) }
  if not results[1] then
    geterrorhandler()(results[2])
    return
  end
  return unpack(results, 2, table.maxn(results))
end
_G.securecall = function(fn, ...)
  if type(fn) == "string" then
    fn = _G[fn]
  end
  return _G.securecallfunction(fn, ...)
end

-- Table utilities
_G.CopyTable = function(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      copy[k] = _G.CopyTable(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Combat and gameplay state
_G.InCombatLockdown = function() return false end
_G.GetFramerate = function() return 60 end

-- String utilities (WoW-specific)
_G.format = string.format
_G.strtrim = function(str)
  if not str then return "" end
  return str:match("^%s*(.-)%s*$")
end

-- Item info stubs
_G.C_Item = _G.C_Item or {}
if not _G.C_Item.GetItemInfoInstant then
  _G.C_Item.GetItemInfoInstant = function(id) return id end
end
_G.C_Item.IsBound = _G.C_Item.IsBound or function() return false end
_G.C_Item.IsEquippableItem = _G.C_Item.IsEquippableItem or function() return true end
_G.C_Item.GetItemQuality = _G.C_Item.GetItemQuality or function() return 1 end
_G.C_Item.GetDetailedItemLevelInfo = _G.C_Item.GetDetailedItemLevelInfo or function() return 1, false, 1 end
_G.C_Item.GetCurrentItemLevel = _G.C_Item.GetCurrentItemLevel or function() return 1 end
_G.C_Item.GetItemGUID = _G.C_Item.GetItemGUID or function() return "mock-guid" end
_G.C_Item.GetStackCount = _G.C_Item.GetStackCount or function() return 1 end
_G.C_Item.GetItemInfo = _G.C_Item.GetItemInfo or function()
  return "Mock Item", "[Mock Item Link]", 1, 1, 0, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", 12345, 100, 2, 0, 0, 0, 0
end
_G.C_Item.GetItemSubClassInfo = _G.C_Item.GetItemSubClassInfo or function(classID, subclassID)
  return "Bag"
end
-- C_Item.GetItemNameByID(itemInfo) -> itemName and GetItemQualityByID(itemInfo) -> itemQuality, both
-- nilable (ItemDocumentation.lua; nil while the client has not loaded the item): read from whatever
-- C_Item.GetItemInfo answers now, so a spec's own GetItemInfo drives them.
_G.C_Item.GetItemNameByID = _G.C_Item.GetItemNameByID or function(itemID)
  return (_G.C_Item.GetItemInfo(itemID))
end
_G.C_Item.GetItemQualityByID = _G.C_Item.GetItemQualityByID or function(itemID)
  return (select(3, _G.C_Item.GetItemInfo(itemID)))
end
-- GetInventoryItemID(unit, slot) -> itemID, nothing for an empty slot (Blizzard_TutorialLogic.lua
-- reads it so); by default nothing is worn.
_G.GetInventoryItemID = _G.GetInventoryItemID or function(unit, slot) return nil end
_G.GetInventoryItemLink = _G.GetInventoryItemLink or function(unit, invid)
  return "|Hitem:12345|h[Mock Bag]|h"
end

-- New item tracking
_G.C_NewItems = _G.C_NewItems or {
  IsNewItem = function() return false end,
  RemoveNewItem = function() end,
  ClearAll = function() end,
}

-- Time functions (WoW exposes os.time and os.date as the globals time and date)
_G.time = _G.time or os.time
_G.date = _G.date or os.date

-- string.split (WoW alias for strsplit, available as string method)
string.split = string.split or function(sep, str)
  return _G.strsplit(sep, str)
end

-- strsplittable: like strsplit but returns a table
_G.strsplittable = function(sep, str, max)
  return {_G.strsplit(sep, str, max)}
end

-- Lua 5.1/5.3 compatibility shims
if not _G.unpack and _G.table and _G.table.unpack then
  _G.unpack = _G.table.unpack
end

if not _G.loadstring and _G.load then
  _G.loadstring = _G.load
end

-- String functions (WoW global aliases for string library)
_G.strmatch = string.match
_G.strsub = string.sub
_G.strlen = string.len
_G.strfind = string.find
_G.strlower = string.lower
_G.strupper = string.upper
_G.strbyte = string.byte
_G.strchar = string.char
_G.strrep = string.rep
_G.strjoin = function(sep, ...) return table.concat({...}, sep) end

-- strlenutf8: WoW global returning the number of UTF-8 characters (code points)
-- in a string. Not part of stock Lua 5.1, so provide a faithful mock that counts
-- lead bytes (any byte that is not a 0x80-0xBF continuation byte).
_G.strlenutf8 = function(s)
  if type(s) ~= "string" then return 0 end
  local count = 0
  for i = 1, #s do
    local b = string.byte(s, i)
    if b < 0x80 or b > 0xBF then
      count = count + 1
    end
  end
  return count
end

_G.strsplit = function(sep, str, max)
  if str == nil then return end
  local t = {}
  local start = 1
  local splitStart, splitEnd = string.find(str, sep, start, true)
  while splitStart do
    if max and #t >= max - 1 then break end
    table.insert(t, string.sub(str, start, splitStart - 1))
    start = splitEnd + 1
    splitStart, splitEnd = string.find(str, sep, start, true)
  end
  table.insert(t, string.sub(str, start))
  return unpack(t)
end

-- Table functions (WoW global aliases for table library)
_G.tinsert = table.insert
_G.tremove = table.remove
_G.tconcat = table.concat
_G.wipe = function(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
end

-- Equipment set API
_G.C_EquipmentSet = {
  GetEquipmentSetIDs = function() return {} end,
  GetEquipmentSetInfo = function() return "" end,
  GetItemLocations = function() return {} end,
}

-- Equipment location unpack helpers
_G.EquipmentManager_UnpackLocation = function()
  return 0, false, true, false, 1, 0
end

_G.EquipmentManager_GetLocationData = function()
  return { isBank = false, isBags = true, slot = 1, bag = 0 }
end

-- Subsystems and Money APIs
_G._playerMoney = 100000 -- Default to 10 gold (in copper)
_G._depositedMoney = 50000 -- Default to 5 gold (in copper)

_G.GetMoney = function()
  return _G._playerMoney
end

_G.BreakUpLargeNumbers = function(val)
  local left, right = string.match(tostring(val), "^([^%d]*%d+)(.-)$")
  if not left then return tostring(val) end
  return left:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") .. (right or "")
end

-- StaticPopupDialogs: Blizzard's table of popup definitions (StaticPopup.lua), filled by addons.
_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
_G._lastPopupShown = nil
_G.StaticPopup_Show = function(name, ...)
  _G._lastPopupShown = { name = name, args = {...} }
  return {}
end

_G.PlaySound = function() end
_G.SOUNDKIT = {
  IG_BACKPACK_OPEN = 1,
  IG_BACKPACK_CLOSE = 2,
}

-- xpcall(f, msgh, ...) passes ... on to f in WoW (warcraft.wiki.gg API_xpcall); PUC Lua 5.1's
-- xpcall takes only f and msgh and drops the rest.
do
  local nativeXpcall = xpcall
  _G.xpcall = function(f, msgh, ...)
    local n = select("#", ...)
    if n == 0 then
      return nativeXpcall(f, msgh)
    end
    local args = { ... }
    return nativeXpcall(function() return f(unpack(args, 1, n)) end, msgh)
  end
end

-- UIDropDownMenu (Blizzard_SharedXML/Mainline/UIDropDownMenu.lua, UIDropDownMenuTemplates.xml):
-- the template gives Left/Middle/Right textures and a Text font string; Initialize stores the
-- init function and calls it at once, and the buttons it adds (AddButton) go to that dropdown's
-- list (recorded as _dropdownButtons); SetWidth sizes Middle, the frame (width + padding, 25
-- on each side by default) and Text; SetText/GetText use Text.
-- InputScrollFrameTemplate (Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml): a
-- scroll frame with a CharCount font string and an EditBox scroll child (multi-line, not
-- focused automatically) holding an Instructions font string.
_G.__mockTemplates.InputScrollFrameTemplate = function(frame)
  frame.CharCount = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
  frame.EditBox = CreateFrame("EditBox", nil, frame)
  frame.EditBox:SetAutoFocus(false)
  frame.EditBox.Instructions = frame.EditBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
end

-- SearchBoxTemplate (Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml): an edit box
-- inheriting InputBoxInstructionsTemplate, so InputBoxVisualTemplate's Left, Right and Middle art
-- (BACKGROUND, the common-search-border atlases) and an Instructions font string (ARTWORK,
-- GameFontDisableSmall, 16 in on the left and 20 on the right); its own searchIcon (OVERLAY,
-- common-search-magnifyingglass, 10 x 10 at LEFT 1, -1), a hidden 17 x 17 clearButton at RIGHT
-- -3 with an Icon (common-search-clearbutton at 0.5, 10 x 10 at TOPLEFT 3, -3), text insets 16,
-- 20, 0, 0. BagSearchBoxTemplate (Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml)
-- inherits it.
_G.__mockTemplates.SearchBoxTemplate = function(box)
  box.Left = box:CreateTexture(nil, "BACKGROUND")
  box.Left:SetAtlas("common-search-border-left")
  box.Right = box:CreateTexture(nil, "BACKGROUND")
  box.Right:SetAtlas("common-search-border-right")
  box.Middle = box:CreateTexture(nil, "BACKGROUND")
  box.Middle:SetAtlas("common-search-border-middle")
  box.Instructions = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  -- Its XML <Color r="0.35" g="0.35" b="0.35"/> (InputBoxInstructionsTemplate): the font string's own
  -- color, over its font object's.
  box.Instructions:SetTextColor(0.35, 0.35, 0.35)
  box.Instructions:SetPoint("TOPLEFT", box, "TOPLEFT", 16, 0)
  box.Instructions:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -20, 0)
  box.searchIcon = box:CreateTexture(nil, "OVERLAY")
  box.searchIcon:SetAtlas("common-search-magnifyingglass")
  box.searchIcon:SetSize(10, 10)
  box.searchIcon:SetPoint("LEFT", box, "LEFT", 1, -1)
  box.clearButton = CreateFrame("Button", nil, box)
  box.clearButton:SetSize(17, 17)
  box.clearButton:SetPoint("RIGHT", box, "RIGHT", -3, 0)
  box.clearButton:Hide()
  box.clearButton.Icon = box.clearButton:CreateTexture(nil, "ARTWORK")
  box.clearButton.Icon:SetAtlas("common-search-clearbutton")
  box.clearButton.Icon:SetAlpha(0.5)
  box.clearButton.Icon:SetSize(10, 10)
  box.clearButton.Icon:SetPoint("TOPLEFT", box.clearButton, "TOPLEFT", 3, -3)
  box:SetTextInsets(16, 20, 0, 0)
  -- Its scripts (InputBoxTemplates.lua): SearchBoxTemplate_OnLoad dims the magnifier to 0.6 and sets
  -- the instructions (SEARCH); focus gained brightens it and shows the clear button; focus lost dims
  -- it and hides the button while the box is empty; text changed does both by focus and text, then
  -- shows the instructions only while the box is empty (InputBoxInstructions_OnTextChanged). A
  -- SetScript replaces one of them, as in the client.
  box.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
  box.Instructions:SetText(_G.SEARCH or "Search")
  box:SetScript("OnEditFocusGained", function(self)
    self.searchIcon:SetVertexColor(1, 1, 1)
    self.clearButton:Show()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then
      self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
      self.clearButton:Hide()
    end
  end)
  box:SetScript("OnTextChanged", function(self)
    if not self:HasFocus() and self:GetText() == "" then
      self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
      self.clearButton:Hide()
    else
      self.searchIcon:SetVertexColor(1, 1, 1)
      self.clearButton:Show()
    end
    self.Instructions:SetShown(self:GetText() == "")
  end)
end
_G.__mockTemplates.BagSearchBoxTemplate = _G.__mockTemplates.SearchBoxTemplate

-- SimplePanelTemplate (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml): 338 x 424, a
-- rock Bg texture, an Inset frame and a NineSlice frame. BetterBags' BetterBagsSearchPanelTemplate
-- is SimplePanelTemplate on retail (templates/container.xml) and, on Classic
-- (templates/era/container.xml), InsetFrameTemplate with border art and an Inset frame.
_G.__mockTemplates.SimplePanelTemplate = function(frame)
  frame:SetSize(338, 424)
  frame.Bg = frame:CreateTexture(frame._name and (frame._name .. "Bg") or nil, "BACKGROUND")
  frame.Inset = CreateMockWidget("Frame", nil, frame)
  frame.NineSlice = CreateMockWidget("Frame", nil, frame)
end
_G.__mockTemplates.BetterBagsSearchPanelTemplate = _G.__mockTemplates.SimplePanelTemplate

-- PanelTabButtonTemplate (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml): 10 x 32,
-- the tab art Left/Middle/Right, their Active versions, their Highlight versions (alpha 0.4),
-- and the Text button text at CENTER 0, 2. BetterBags' BetterBagsSecureBagTabTemplate
-- (templates/container.xml) is PanelTabButtonTemplate + InsecureActionButtonTemplate.
_G.__mockTemplates.PanelTabButtonTemplate = function(frame)
  frame:SetSize(10, 32)
  for _, key in ipairs({ "LeftActive", "RightActive", "MiddleActive", "Left", "Right", "Middle" }) do
    frame[key] = frame:CreateTexture(nil, "BACKGROUND")
  end
  for _, key in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
    frame[key] = frame:CreateTexture(nil, "HIGHLIGHT")
    frame[key]:SetAlpha(0.4)
  end
  frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.Text:SetPoint("CENTER", frame, "CENTER", 0, 2)
  frame:SetFontString(frame.Text)
end
_G.__mockTemplates.BetterBagsSecureBagTabTemplate = _G.__mockTemplates.PanelTabButtonTemplate

-- PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
-- (SharedUIPanelTemplates.lua; TAB_SIDES_PADDING is 20).
function _G.PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
  local sidesPadding = 20
  tab.Text:SetWidth(absoluteTextSize or 0)
  local textWidth = tab.Text:GetStringWidth()
  local width = textWidth + sidesPadding + (padding or 0)
  local sideWidths = tab.Left:GetWidth() + tab.Right:GetWidth()
  minWidth = minWidth or sideWidths
  if absoluteSize then
    width = absoluteSize < sideWidths and sideWidths or absoluteSize
    textWidth = width - sidesPadding - (padding or 0)
  elseif maxWidth and width > maxWidth then
    width = maxWidth
    textWidth = width - sidesPadding - (padding or 0)
  elseif minWidth and width < minWidth then
    width = minWidth
    textWidth = width - sidesPadding - (padding or 0)
  end
  tab.Text:SetWidth(textWidth)
  tab:SetWidth(width)
end

_G.UIDROPDOWNMENU_DEFAULT_WIDTH_PADDING = 25
_G.__mockTemplates.UIDropDownMenuTemplate = function(frame)
  frame.Left = frame:CreateTexture(nil, "ARTWORK")
  frame.Middle = frame:CreateTexture(nil, "ARTWORK")
  frame.Right = frame:CreateTexture(nil, "ARTWORK")
  frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
end
local initializingDropdown
function _G.UIDropDownMenu_Initialize(frame, initFunction, _, level, menuList)
  frame.menuList = menuList
  if initFunction then
    frame.initialize = initFunction
    frame._dropdownButtons = {}
    initializingDropdown = frame
    initFunction(frame, level, menuList)
    initializingDropdown = nil
  end
end
function _G.UIDropDownMenu_CreateInfo()
  return {}
end
function _G.UIDropDownMenu_AddButton(info)
  if initializingDropdown ~= nil then
    table.insert(initializingDropdown._dropdownButtons, info)
  end
end
function _G.UIDropDownMenu_SetWidth(frame, width, padding)
  frame.Middle:SetWidth(width)
  if padding then
    frame:SetWidth(width + padding)
    frame.Text:SetWidth(width)
  else
    frame:SetWidth(width + UIDROPDOWNMENU_DEFAULT_WIDTH_PADDING * 2)
    frame.Text:SetWidth(width - UIDROPDOWNMENU_DEFAULT_WIDTH_PADDING)
  end
end
function _G.UIDropDownMenu_SetText(frame, text)
  frame.Text:SetText(text)
end
function _G.UIDropDownMenu_GetText(frame)
  return frame.Text:GetText()
end

-- CreateObjectPool(createFunc, resetFunc) (Blizzard_SharedXMLBase/Pools.lua): Acquire
-- reuses a released object or creates one with createFunc(pool), running resetFunc(pool,
-- object, true) on a new one, and returns object, isNew; Release runs resetFunc(pool, object)
-- and keeps the object for the next Acquire.
function _G.CreateObjectPool(createFunc, resetFunc)
  local pool = { active = {}, inactive = {} }
  function pool:Acquire()
    local object = table.remove(self.inactive)
    local new = object == nil
    if new then
      object = createFunc(self)
      resetFunc(self, object, true)
    end
    self.active[object] = true
    return object, new
  end
  function pool:Release(object)
    if not self.active[object] then return false end
    resetFunc(self, object)
    self.active[object] = nil
    table.insert(self.inactive, object)
    return true
  end
  function pool:GetNumActive()
    local n = 0
    for _ in pairs(self.active) do n = n + 1 end
    return n
  end
  function pool:ReleaseAll()
    for object in pairs(self.active) do self:Release(object) end
  end
  return pool
end

-- GameTooltip Mock
_G.GameTooltip = CreateMockWidget("Frame", "GameTooltip")
_G.GameTooltip.lines = {}
_G.GameTooltip.doubleLines = {}
function _G.GameTooltip:SetOwner(owner, anchor, x, y)
  self._owner = owner
  self._anchor = anchor
  self._ownerX = x
  self._ownerY = y
  self.lines = {}
  self.doubleLines = {}
end
-- GameTooltip:SetText and AddLine are not in the generated API documentation, so nothing marks
-- them as taking secrets from tainted callers: they reject them.
function _G.GameTooltip:AddLine(text, r, g, b)
  rejectSecret("GameTooltip:AddLine", text)
  table.insert(self.lines, {text = text, r = r, g = g, b = b})
end
function _G.GameTooltip:SetText(text, ...)
  rejectSecret("GameTooltip:SetText", text)
  self._text = tostring(text or "")
  self._header = text
end
-- GameTooltip:IsOwned(frame) is true when frame owns the tooltip.
function _G.GameTooltip:IsOwned(frame)
  return self._owner == frame
end
-- GetAppropriateTooltip() (Blizzard_SharedXMLBase/FrameUtil.lua): GameTooltip in game.
function _G.GetAppropriateTooltip()
  return _G.GameTooltip
end
function _G.GameTooltip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
  table.insert(self.doubleLines, {left = left, right = right, lr = lr, lg = lg, lb = lb, rr = rr, rg = rg, rb = rb})
end
-- GameTooltip:SetBagItem(bag, slot) is a TooltipDataHandler accessor (GetBagItem): it
-- returns true and shows the tooltip when the slot holds an item, otherwise it hides the
-- tooltip and returns false (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua).
function _G.GameTooltip:SetBagItem(bag, slot)
  self._bagItem = { bag = bag, slot = slot }
  if _G.C_Item.DoesItemExist(_G.ItemLocation:CreateFromBagAndSlot(bag, slot)) then
    self.lines = {}
    self:Show()
    return true
  end
  self:Hide()
  return false
end

-- GameTooltip:SetHyperlink(link) and SetItemByID(itemID) are TooltipDataHandler accessors on retail
-- (GetHyperlink, GetItemByID; Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua) and native on
-- Classic: they fill the tooltip with the item's and show it.
function _G.GameTooltip:SetHyperlink(link)
  self._hyperlink, self._itemByID = link, nil
  self:Show()
end
function _G.GameTooltip:SetItemByID(itemID)
  self._itemByID, self._hyperlink = itemID, nil
  self:Show()
end

-- Cursor APIs
_G._cursorHasItem = false
_G._isShiftKeyDown = false
_G._isControlKeyDown = false
_G._isAltKeyDown = false
_G._cursorType = nil
_G._cursorItemID = nil
_G._cursorItemLink = nil
_G._cursorX = 0
_G._cursorY = 0

_G.CursorHasItem = function() return _G._cursorHasItem or false end
-- DeleteCursorItem destroys the item on the cursor (GameCursorDocumentation.lua: no arguments, no
-- returns, HasRestrictions).
_G.DeleteCursorItem = function() _G._cursorHasItem = false end
_G.IsShiftKeyDown = function() return _G._isShiftKeyDown or false end
-- IsMouseButtonDown([button]) -> down (InputDocumentation.lua): any button without one. Specs set
-- _G._mouseButtonsDown = { LeftButton = true }.
_G.IsMouseButtonDown = function(button)
  local down = _G._mouseButtonsDown or {}
  if button == nil then
    return next(down) ~= nil
  end
  return down[button] == true
end
_G.IsControlKeyDown = function() return _G._isControlKeyDown or false end
_G.IsAltKeyDown = function() return _G._isAltKeyDown or false end
_G.GetCursorInfo = function() return _G._cursorType, _G._cursorItemID, _G._cursorItemLink end
-- IsModifiedClick(action?) -> isHeld, with the default bindings (Bindings_*.xml ModifiedClick):
-- PICKUPITEM, SPLITSTACK and CHATLINK on SHIFT, DRESSUP on CTRL; with no action, any modifier.
_G.IsModifiedClick = function(action)
  if action == "PICKUPITEM" or action == "SPLITSTACK" or action == "CHATLINK" then return _G.IsShiftKeyDown() end
  if action == "DRESSUP" then return _G.IsControlKeyDown() end
  if action == nil then return _G.IsShiftKeyDown() or _G.IsControlKeyDown() or _G.IsAltKeyDown() end
  return false
end
_G.ClearCursor = function()
  _G._cursorHasItem = false
  _G._cursorType = nil
  _G._cursorItemID = nil
  _G._cursorItemLink = nil
  _G._cursorItemLocation = nil
end
-- C_Cursor.GetCursorItem() -> ItemLocation, or nothing (CursorDocumentation.lua,
-- MayReturnNothing). Specs set _G._cursorItemLocation to where the cursor item came from.
_G._cursorItemLocation = nil
_G.C_Cursor = _G.C_Cursor or {}
_G.C_Cursor.GetCursorItem = function() return _G._cursorItemLocation end
_G.GetCursorPosition = function() return _G._cursorX or 0, _G._cursorY or 0 end

-- Enum Setup
_G.Enum = _G.Enum or {}
_G.Enum.BankType = {
  Character = 1,
  Account = 2,
}
_G.Enum.BagIndex = {
  Keyring = -2,
}
_G.Enum.ItemClass = {
  Consumable = 0,
  Container = 1,
  Weapon = 2,
  Gem = 3,
  Armor = 4,
  Tradegoods = 7,
  Quiver = 11,
}

-- C_ActionBar.ShouldShowKeyring() -> isKeyringEnabled (WoW: Forever only,
-- ActionBarFrameDocumentation.lua). Specs set _G._keyringEnabled = false to turn it off.
_G.C_ActionBar = _G.C_ActionBar or {}
_G.C_ActionBar.ShouldShowKeyring = function() return _G._keyringEnabled ~= false end

-- C_Bank Setup
_G.C_Bank = _G.C_Bank or {}
_G.C_Bank.FetchDepositedMoney = function(bankType)
  return _G._depositedMoney
end
-- BankDocumentation.lua: FetchNumPurchasedBankTabs(bankType) -> numPurchasedBankTabs (number,
-- non-nilable); FetchNextPurchasableBankTabData(bankType) -> nextPurchasableTabData
-- (PurchasableBankTabData: tabCost, canAfford, purchasePromptTitle, purchasePromptBody,
-- purchasePromptConfirmation; nilable). Specs set _G._purchasedBankTabs[bankType] (a count)
-- and _G._nextPurchasableBankTab[bankType].
_G._purchasedBankTabs = {}
_G._nextPurchasableBankTab = {}
_G.C_Bank.FetchNumPurchasedBankTabs = function(bankType)
  return _G._purchasedBankTabs[bankType] or 0
end
_G.C_Bank.FetchNextPurchasableBankTabData = function(bankType)
  return _G._nextPurchasableBankTab[bankType]
end

-- C_Container Setup
_G.C_Container = _G.C_Container or {}
_G.C_Container._usedItems = {}
_G.C_Container.ContainerIDToInventoryID = function(bagid) return bagid and (bagid + 20) or nil end
_G.C_Container.GetBagName = function(bagid)
  if bagid == -2 then return "Keyring" end
  return "Mock Bag " .. bagid
end
_G.C_Container.GetContainerNumSlots = function(bagid)
  return 16
end
_G.C_Container.GetContainerItemID = function(bagid, slotid)
  return _G._containerItems and _G._containerItems[bagid] and _G._containerItems[bagid][slotid] or nil
end
_G.C_Container.GetContainerItemLink = function(bagid, slotid)
  local itemID = _G.C_Container.GetContainerItemID(bagid, slotid)
  if itemID then
    return string.format("|cffff8000|Hitem:%d:0:0:0:0:0:0:0|h[Mock Item %d]|h|r", itemID, itemID)
  end
  return nil
end
-- C_Container.GetContainerItemCooldown(containerIndex, slotIndex) -> startTime, duration, enable
-- (ContainerDocumentation.lua: three non-nilable numbers). Specs set a slot's cooldown via
-- _G._containerCooldowns["bag_slot"] = { start, duration, enable }; otherwise none.
_G._containerCooldowns = {}
_G.C_Container.GetContainerItemCooldown = function(containerIndex, slotIndex)
  local cd = _G._containerCooldowns[tostring(containerIndex) .. "_" .. tostring(slotIndex)]
  if cd then
    return cd[1], cd[2], cd[3]
  end
  return 0, 0, 1
end
_G.C_Container.GetContainerNumFreeSlots = function(bagid)
  return 4, nil
end
_G.C_Container.GetContainerItemQuestInfo = _G.C_Container.GetContainerItemQuestInfo or function(bagid, slotid)
  return { isQuestItem = false, questID = nil, isActive = false }
end
_G.C_Container.GetContainerItemInfo = _G.C_Container.GetContainerItemInfo or function(bagid, slotid)
  return { iconFileID = 12345, stackCount = 1, isLocked = false, quality = 1, isReadable = false, hasLoot = false, hyperlink = "[Mock Link]", isFiltered = false, hasNoValue = false, itemID = 123 }
end
-- C_Container.PickupContainerItem(containerIndex, slotIndex): picks up, places, or swaps
-- the cursor item with the item at that container slot. Calls are recorded for specs.
_G.C_Container._pickups = {}
_G.C_Container.PickupContainerItem = function(containerIndex, slotIndex)
  table.insert(_G.C_Container._pickups, { bag = containerIndex, slot = slotIndex })
end
-- C_Container.GetContainerFreeSlots(containerIndex) -> freeSlots: the container's empty slot
-- indexes (ContainerDocumentation.lua). Specs set _G._containerFreeSlots[bag] = { slots }.
_G._containerFreeSlots = {}
_G.C_Container.GetContainerFreeSlots = function(containerIndex)
  return _G._containerFreeSlots[containerIndex] or {}
end
-- C_Item.GetItemFamily(itemInfo) -> bag family bitfield, nil for an uncached item
-- (ItemDocumentation.lua, Nilable). Specs set _G._itemFamilies[itemID].
_G._itemFamilies = {}
_G.C_Item = _G.C_Item or {}
_G.C_Item.GetItemFamily = function(itemInfo) return _G._itemFamilies[itemInfo] end
-- C_TradeSkillUI.GetItemReagentQualityByItemInfo / GetItemCraftedQualityByItemInfo(itemInfo) ->
-- the item's crafting quality tier, a reagent's or a crafted item's (TradeSkillUIDocumentation.lua,
-- Nilable). No item has one unless a spec gives it one.
_G.C_TradeSkillUI = _G.C_TradeSkillUI or {}
_G.C_TradeSkillUI.GetItemReagentQualityByItemInfo = function(itemInfo) return nil end
_G.C_TradeSkillUI.GetItemCraftedQualityByItemInfo = function(itemInfo) return nil end
-- What items are, from ItemDocumentation.lua; by default an item has none of these (no Use spell,
-- not cosmetic, no upgrade track, not scrappable). GetItemSpell is documented with non-nilable
-- returns, but Blizzard's /use code treats its result as a truth value (ChatFrameUtilOverrides.lua),
-- and an item with no spell returns nothing.
_G.C_Item.GetItemSpell = function(itemInfo) return nil end
_G.C_Item.IsCosmeticItem = function(itemInfo) return false end
_G.C_Item.GetItemUpgradeInfo = function(itemInfo) return nil end
_G.C_Item.CanScrapItem = function(itemLocation) return false end
-- C_PetJournal.GetPetInfoByItemID(itemID) -> name, ..., speciesID (13th), nothing for an item that
-- teaches no pet (warcraft.wiki.gg; Blizzard's PlayerChoice treats it as a truth value).
_G.C_PetJournal = _G.C_PetJournal or {}
_G.C_PetJournal.GetPetInfoByItemID = function(itemID) return nil end
-- C_Item.CanBeRefunded(itemLocation) -> bool (ItemDocumentation.lua). Specs list
-- refundable locations in _G._refundableLocations["bag:slot"]. Its argument is an ItemLocation,
-- not an EmptiableItemLocation (DoesItemExist's): a location with no item is an error, as a capture
-- from the game showed ("bad argument #1 to '?' (Usage: local canBeRefunded =
-- C_Item.CanBeRefunded(itemLocation))"). Blizzard's callers check itemLocation:IsValid() first.
_G._refundableLocations = {}
_G.C_Item.CanBeRefunded = function(itemLocation)
  if not _G.C_Item.DoesItemExist(itemLocation) then
    error("bad argument #1 to '?' (Usage: local canBeRefunded = C_Item.CanBeRefunded(itemLocation))", 2)
  end
  local bag, slot = itemLocation:GetBagAndSlot()
  return bag ~= nil and _G._refundableLocations[bag .. ":" .. slot] == true
end
-- UIErrorsFrame:AddMessage(text, r, g, b, a): the red error text in the middle of the
-- screen. Messages are recorded for specs.
_G.UIErrorsFrame = _G.UIErrorsFrame or {}
_G.UIErrorsFrame._messages = {}
_G.UIErrorsFrame.AddMessage = function(self, text, r, g, b, a)
  table.insert(self._messages, { text = text, r = r, g = g, b = b, a = a })
end
-- Client global strings (GlobalStrings/enUS.lua on every client).
_G.ERR_INV_FULL = "Inventory is full."
_G.ERR_BANK_FULL = "Your bank is full"
-- The client's bit library (BitLib): bit.band on non-negative 32-bit integers.
_G.bit = _G.bit or {
  band = function(a, b)
    local result, place = 0, 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then
        result = result + place
      end
      a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
  end,
}
_G.C_Container.UseContainerItem = function(bagid, slotid, target, bankType, isReagent)
  table.insert(_G.C_Container._usedItems, {
    bagid = bagid,
    slotid = slotid,
    target = target,
    bankType = bankType,
    isReagent = isReagent
  })
end

-- ItemLocation Setup
_G.ItemLocation = _G.ItemLocation or {}
_G.ItemLocation.CreateFromBagAndSlot = function(_, bagID, slotID)
  local loc = {
    _bagID = bagID,
    _slotID = slotID,
    _isBagAndSlot = true,
    _isEquipmentSlot = false,
  }
  function loc:GetBagAndSlot() return self._bagID, self._slotID end
  function loc:GetEquipmentSlot() return nil end
  function loc:IsEquipmentSlot() return false end
  function loc:IsBagAndSlot() return true end
  -- ItemLocationMixin:HasAnyLocation (Blizzard_ObjectAPI/Mainline/ItemLocation.lua).
  function loc:HasAnyLocation() return true end
  function loc:IsValid() return true end
  return loc
end
_G.ItemLocation.CreateFromEquipmentSlot = function(_, slotID)
  local loc = {
    _bagID = nil,
    _slotID = nil,
    _isBagAndSlot = false,
    _isEquipmentSlot = true,
    _equipSlot = slotID,
  }
  function loc:GetBagAndSlot() return nil, nil end
  function loc:GetEquipmentSlot() return self._equipSlot end
  function loc:IsEquipmentSlot() return true end
  function loc:IsBagAndSlot() return false end
  function loc:HasAnyLocation() return true end
  function loc:IsValid() return true end
  return loc
end

-- Location-based C_Item APIs (ItemDocumentation.lua). Specs describe what sits at a
-- bag/slot via _G._itemsAtLocation["bag:slot"] = { icon = fileID, quality = n }.
_G._itemsAtLocation = {}
local function itemAtLocation(itemLocation)
  local bag, slot = itemLocation:GetBagAndSlot()
  if bag == nil then return nil end
  return _G._itemsAtLocation[bag .. ":" .. slot]
end
-- C_Item.DoesItemExist(emptiableItemLocation) -> itemExists: an item is at a bag slot when a spec put
-- one there (_itemsAtLocation) or the container reports one (C_Container.GetContainerItemID, as the
-- client's bags do).
_G.C_Item.DoesItemExist = function(itemLocation)
  if itemAtLocation(itemLocation) ~= nil then
    return true
  end
  local bag, slot = itemLocation:GetBagAndSlot()
  return bag ~= nil and _G.C_Container ~= nil and _G.C_Container.GetContainerItemID ~= nil
    and _G.C_Container.GetContainerItemID(bag, slot) ~= nil
end
-- C_Item.GetItemIcon(itemLocation) -> icon (fileID, nilable)
_G.C_Item.GetItemIcon = function(itemLocation)
  local item = itemAtLocation(itemLocation)
  return item and item.icon or nil
end

-- Item Setup
_G.Item = _G.Item or {}
_G.Item.CreateFromBagAndSlot = function(_, bagID, slotID)
  local loc = _G.ItemLocation:CreateFromBagAndSlot(bagID, slotID)
  local item = {
    _location = loc,
    _bagID = bagID,
    _slotID = slotID,
  }
  function item:GetItemLocation() return self._location end
  function item:GetInventoryType() return 1 end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  function item:IsItemLocked() return false end
  function item:GetItemName() return "Mock Item" end
  function item:GetItemIcon() return 12345 end
  function item:GetItemLink() return "[Mock Item]" end
  function item:GetItemID() return 12345 end
  function item:IsItemEmpty() return false end
  return item
end
_G.Item.CreateFromEquipmentSlot = function(_, slotID)
  local loc = _G.ItemLocation:CreateFromEquipmentSlot(slotID)
  local item = {
    _location = loc,
    _equipSlot = slotID,
  }
  function item:GetItemLocation() return self._location end
  function item:GetInventoryType() return 1 end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  function item:IsItemLocked() return false end
  function item:GetItemName() return "Mock Item" end
  function item:GetItemIcon() return 12345 end
  function item:GetItemLink() return "[Mock Item]" end
  function item:GetItemID() return 12345 end
  function item:IsItemEmpty() return false end
  return item
end
_G.Item.CreateFromItemLocation = function(_, itemLocation)
  local item = {
    _location = itemLocation,
  }
  function item:GetItemLocation() return self._location end
  function item:GetInventoryType() return 1 end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  function item:IsItemLocked() return false end
  function item:GetItemName() return "Mock Item" end
  function item:GetItemIcon() return 12345 end
  function item:GetItemLink() return "[Mock Item]" end
  function item:GetItemID() return 12345 end
  function item:IsItemEmpty() return false end
  return item
end
-- Item:CreateFromItemLink(itemLink): an item known by its link alone (Blizzard_ObjectAPI Item.lua).
_G.Item.CreateFromItemLink = function(_, itemLink)
  local item = {
    _itemLink = itemLink,
  }
  function item:GetItemLink() return self._itemLink end
  function item:IsItemEmpty() return false end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  return item
end
_G.Item.CreateFromItemID = function(_, itemID)
  local item = {
    _itemID = itemID,
  }
  function item:GetItemID() return self._itemID end
  function item:IsItemEmpty() return false end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  return item
end

-- ContinuableContainer Setup
_G.ContinuableContainer = _G.ContinuableContainer or {}
_G.ContinuableContainer.Create = function(_)
  local container = {
    _items = {}
  }
  function container:AddContinuable(itemMixin)
    table.insert(self._items, itemMixin)
  end
  function container:ContinueOnLoad(callback)
    callback()
  end
  return container
end

-- Math aliases
_G.floor = math.floor
_G.ceil = math.ceil
_G.abs = math.abs
_G.max = math.max
_G.min = math.min

-- Equipment Slot constants (Blizzard_FrameXMLBase/Constants.lua)
_G.INVSLOT_FIRST_EQUIPPED = 1
_G.INVSLOT_LAST_EQUIPPED = 19
_G.INVSLOT_AMMO = _G.INVSLOT_AMMO or 0
_G.INVSLOT_HEAD = _G.INVSLOT_HEAD or 1
_G.INVSLOT_NECK = _G.INVSLOT_NECK or 2
_G.INVSLOT_SHOULDER = _G.INVSLOT_SHOULDER or 3
_G.INVSLOT_BODY = _G.INVSLOT_BODY or 4
_G.INVSLOT_CHEST = _G.INVSLOT_CHEST or 5
_G.INVSLOT_WAIST = _G.INVSLOT_WAIST or 6
_G.INVSLOT_LEGS = _G.INVSLOT_LEGS or 7
_G.INVSLOT_FEET = _G.INVSLOT_FEET or 8
_G.INVSLOT_WRIST = _G.INVSLOT_WRIST or 9
_G.INVSLOT_HAND = _G.INVSLOT_HAND or 10
_G.INVSLOT_FINGER1 = _G.INVSLOT_FINGER1 or 11
_G.INVSLOT_FINGER2 = _G.INVSLOT_FINGER2 or 12
_G.INVSLOT_TRINKET1 = _G.INVSLOT_TRINKET1 or 13
_G.INVSLOT_TRINKET2 = _G.INVSLOT_TRINKET2 or 14
_G.INVSLOT_BACK = _G.INVSLOT_BACK or 15
_G.INVSLOT_MAINHAND = _G.INVSLOT_MAINHAND or 16
_G.INVSLOT_OFFHAND = _G.INVSLOT_OFFHAND or 17
_G.INVSLOT_RANGED = _G.INVSLOT_RANGED or 18
_G.INVSLOT_TABARD = _G.INVSLOT_TABARD or 19

-- UnitStat indexes (client constants; values from Blizzard's LuaEnum, matching the
-- SPELL_STAT<n>_NAME global strings: 1 Strength, 2 Agility, 3 Stamina, 4 Intellect).
_G.LE_UNIT_STAT_STRENGTH = 1
_G.LE_UNIT_STAT_AGILITY = 2
_G.LE_UNIT_STAT_STAMINA = 3
_G.LE_UNIT_STAT_INTELLECT = 4

-- PlayerScriptDocumentation.lua: CanDualWield() -> result (bool, not nilable).
_G.CanDualWield = function() return true end
-- UnitDocumentation.lua: UnitLevel(name) -> result (number); UnitSex(unit) -> sex (number, nilable).
_G.UnitLevel = function() return 80 end
_G.UnitSex = function() return 2 end

-- ItemButtonUtil Setup
_G.ItemButtonUtil = {
  Event = { ItemContextChanged = 1 },
  TriggerEvent = function() end,
}

-- Merchants. The merchant functions are legacy globals with no generated documentation; their
-- shapes are what Blizzard's own merchant code reads (Blizzard_UIPanels_Game/Mainline,
-- Vanilla and TBC MerchantFrame.lua and .xml; MerchantFrameDocumentation.lua for C_MerchantFrame).
-- Specs describe the open merchant in _G._merchant and read what was asked of it in
-- _G._merchantCalls (reset both with ResetMockMerchant):
--   items[i] = { link, itemID, name, texture, price, stackCount, numAvailable, isPurchasable,
--     isUsable, hasExtendedCost, currencyID, spellID, isQuestStartItem, maxStack, canAfford,
--     refundable, costs = { { texture, value, link, currencyName } } }
--   buyback[i] = { name, texture, price, quantity, numAvailable, isUsable, isBound, link }
--   canRepair, repairCost, canGuildRepair, junk, sellJunkEnabled (the guild's money: _G._guildBank),
--   currencies, filter, open
function _G.ResetMockMerchant()
  _G._merchant = { items = {}, buyback = {}, canRepair = false, repairCost = 0, canGuildRepair = false,
    junk = 0, sellJunkEnabled = true, currencies = {}, filter = 1,
    open = true, repairMode = false }
  _G._merchantCalls = { buy = {}, buyback = {}, repair = {}, pickup = {}, closed = 0, sellJunk = 0,
    confirmExtended = {}, confirmHighCost = {}, sellJunkClicked = 0, inventoryPickups = {}, filters = {} }
  _G._durability = {}
  _G._bagDurability = {}
  _G._repairCosts = {}
end
_G.ResetMockMerchant()

local function merchantItem(index)
  return _G._merchant.items[index]
end

-- GetMerchantNumItems() -> numItems.
_G.GetMerchantNumItems = function() return #_G._merchant.items end
-- C_MerchantFrame.GetItemInfo(index) -> MerchantItemInfo (retail and WoW: Forever; nilable).
_G.C_MerchantFrame = _G.C_MerchantFrame or {}
_G.C_MerchantFrame.GetItemInfo = function(index)
  local item = merchantItem(index)
  if item == nil then return nil end
  return { name = item.name, texture = item.texture or 0, price = item.price or 0, stackCount = item.stackCount or 1,
    numAvailable = item.numAvailable or -1, isPurchasable = item.isPurchasable ~= false,
    isUsable = item.isUsable ~= false, hasExtendedCost = item.hasExtendedCost == true, currencyID = item.currencyID,
    spellID = item.spellID, isQuestStartItem = item.isQuestStartItem == true }
end
-- GetMerchantItemInfo(index) -> name, texture, price, stackCount, numAvailable, isPurchasable,
-- isUsable, extendedCost, currencyID (Classic: Vanilla/TBC MerchantFrame.lua).
_G.GetMerchantItemInfo = function(index)
  local item = merchantItem(index)
  if item == nil then return nil end
  return item.name, item.texture or 0, item.price or 0, item.stackCount or 1, item.numAvailable or -1,
    item.isPurchasable ~= false, item.isUsable ~= false, item.hasExtendedCost == true, item.currencyID
end
_G.GetMerchantItemLink = function(index) local item = merchantItem(index) return item and item.link end
_G.GetMerchantItemID = function(index) local item = merchantItem(index) return item and item.itemID end
_G.GetMerchantItemMaxStack = function(index) local item = merchantItem(index) return item and item.maxStack or 1 end
-- CanAffordMerchantItem(index) -> canAfford (nil when the client does not know).
_G.CanAffordMerchantItem = function(index) local item = merchantItem(index) return item and item.canAfford ~= false end
-- GetMerchantItemCostInfo(index) -> number of cost entries; GetMerchantItemCostItem(index, i) ->
-- itemTexture, itemValue, itemLink, currencyName (MerchantFrame_UpdateAltCurrency).
_G.GetMerchantItemCostInfo = function(index) local item = merchantItem(index) return item and #(item.costs or {}) or 0 end
_G.GetMerchantItemCostItem = function(index, costIndex)
  local item = merchantItem(index)
  local cost = item and item.costs and item.costs[costIndex]
  if cost == nil then return nil end
  return cost.texture, cost.value, cost.link, cost.currencyName
end
_G.C_MerchantFrame.IsMerchantItemRefundable = function(index) local item = merchantItem(index) return item ~= nil and item.refundable ~= false end
_G.C_MerchantFrame.GetNumJunkItems = function() return _G._merchant.junk end
_G.C_MerchantFrame.IsSellAllJunkEnabled = function() return _G._merchant.sellJunkEnabled end
_G.C_MerchantFrame.SellAllJunkItems = function() _G._merchantCalls.sellJunk = _G._merchantCalls.sellJunk + 1 end
_G.C_MerchantFrame.GetMerchantCurrencies = function() return _G._merchant.currencies end
-- BuyMerchantItem(index, quantity?), PickupMerchantItem(index) (0 sells the cursor item),
-- CloseMerchant().
_G.BuyMerchantItem = function(index, quantity) table.insert(_G._merchantCalls.buy, { index, quantity }) end
_G.PickupMerchantItem = function(index) table.insert(_G._merchantCalls.pickup, index) end
_G.CloseMerchant = function()
  _G._merchantCalls.closed = _G._merchantCalls.closed + 1
  _G._merchant.open = false
end
-- Buyback: GetNumBuybackItems(), GetBuybackItemInfo(i) -> name, texture, price, quantity,
-- numAvailable, isUsable, isBound; GetBuybackItemLink(i); BuybackItem(i).
_G.GetNumBuybackItems = function() return #_G._merchant.buyback end
_G.GetBuybackItemInfo = function(index)
  local item = _G._merchant.buyback[index]
  if item == nil then return nil end
  return item.name, item.texture or 0, item.price or 0, item.quantity or 1, item.numAvailable or -1,
    item.isUsable ~= false, item.isBound == true
end
_G.GetBuybackItemLink = function(index) local item = _G._merchant.buyback[index] return item and item.link end
_G.BuybackItem = function(index) table.insert(_G._merchantCalls.buyback, index) end
-- Repair: CanMerchantRepair(), GetRepairAllCost() -> repairAllCost, canRepair, RepairAllItems
-- (guildBankRepair?), CanGuildBankRepair(), GetGuildBankWithdrawMoney() (-1: no limit),
-- GetGuildBankMoney(), ShowRepairCursor(), HideRepairCursor(), InRepairMode().
_G.CanMerchantRepair = function() return _G._merchant.canRepair end
_G.GetRepairAllCost = function() return _G._merchant.repairCost, _G._merchant.repairCost > 0 end
_G.RepairAllItems = function(guild) table.insert(_G._merchantCalls.repair, guild == true) end
_G.CanGuildBankRepair = function() return _G._merchant.canGuildRepair end
_G.ShowRepairCursor = function() _G._merchant.repairMode = true end
_G.HideRepairCursor = function() _G._merchant.repairMode = false end
_G.InRepairMode = function() return _G._merchant.repairMode end
-- PickupInventoryItem(slot): in repair mode it repairs that slot (PaperDollItemSlotButton_OnClick).
_G.PickupInventoryItem = function(slot)
  table.insert(_G._merchantCalls.inventoryPickups, { slot = slot, repairing = _G._merchant.repairMode })
end
-- GetInventoryItemDurability(slot) -> current, maximum (EquipmentManager.lua);
-- C_Container.GetContainerItemDurability(bag, slot) -> durability, maxDurability
-- (ContainerDocumentation.lua). Specs set _G._durability[slot] and _G._bagDurability["bag:slot"].
_G.GetInventoryItemDurability = function(slot)
  local d = _G._durability[slot]
  if d == nil then return nil end
  return d[1], d[2]
end
_G.C_Container.GetContainerItemDurability = function(bag, slot)
  local d = _G._bagDurability[bag .. ":" .. slot]
  if d == nil then return nil end
  return d[1], d[2]
end
-- The filter: SetMerchantFilter(filter), GetMerchantFilter(), and the LE_LOOT_FILTER_* values
-- (retail MerchantFrame_OnLoad).
_G.LE_LOOT_FILTER_ALL = 1
_G.LE_LOOT_FILTER_CLASS = 2
_G.LE_LOOT_FILTER_SPEC1 = 3
_G.LE_LOOT_FILTER_BOE = 7
_G.SetMerchantFilter = function(filter)
  _G._merchant.filter = filter
  table.insert(_G._merchantCalls.filters, filter)
end
_G.GetMerchantFilter = function() return _G._merchant.filter end
-- Blizzard's confirmations (MerchantFrame.lua): MERCHANT_HIGH_PRICE_COST, and the functions an
-- item button's right click goes through; they read the button's ID, price, link, count, name,
-- texture and showNonrefundablePrompt. The Sell All Junk button's confirmation.
_G.MERCHANT_HIGH_PRICE_COST = 1500000
_G.MerchantFrame_ConfirmExtendedItemCost = function(button, quantity)
  table.insert(_G._merchantCalls.confirmExtended, { id = button:GetID(), quantity = quantity, price = button.price,
    link = button.link, count = button.count, name = button.name, texture = button.texture,
    nonrefundable = button.showNonrefundablePrompt })
end
_G.MerchantFrame_ConfirmHighCostItem = function(button, quantity)
  table.insert(_G._merchantCalls.confirmHighCost, { id = button:GetID(), quantity = quantity, price = button.price,
    link = button.link })
end
_G.MerchantFrame_OnSellAllJunkButtonClicked = function()
  _G._merchantCalls.sellJunkClicked = _G._merchantCalls.sellJunkClicked + 1
end
-- C_CurrencyInfo.GetCoinTextureString(amount) (CurrencyInfoDocumentation.lua): the amount in
-- gold, silver and copper with their icons; the mock writes "1g 2s 3c", leaving out zeros.
_G.C_CurrencyInfo = _G.C_CurrencyInfo or {}
_G.C_CurrencyInfo.GetCoinTextureString = function(amount)
  local gold, silver, copper = math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100
  local parts = {}
  if gold > 0 then table.insert(parts, gold .. "g") end
  if silver > 0 then table.insert(parts, silver .. "s") end
  if copper > 0 or #parts == 0 then table.insert(parts, copper .. "c") end
  return table.concat(parts, " ")
end
-- C_CurrencyInfo.GetCurrencyInfo(type) -> CurrencyInfo; specs set _G._currencies[id].
_G._currencies = {}
_G.C_CurrencyInfo.GetCurrencyInfo = function(id) return _G._currencies[id] end
-- Tooltips for merchants: GameTooltip:SetMerchantItem(index), SetBuybackItem(index),
-- SetInventoryItem(unit, slot) -> hasItem, hasCooldown, repairCost (ItemUtil.lua). C_TooltipInfo
-- (retail; TooltipInfoDocumentation.lua) returns TooltipData, whose repairCost
-- TooltipDataRules.lua reads. Specs set _G._repairCosts["inv:slot"] and ["bag:bag:slot"].
function _G.GameTooltip:SetMerchantItem(index) self._merchantItem = index self:Show() end
function _G.GameTooltip:SetBuybackItem(index) self._buybackItem = index self:Show() end
function _G.GameTooltip:SetInventoryItem(unit, slot)
  self._inventoryItem = { unit = unit, slot = slot }
  self:Show()
  return true, false, _G._repairCosts["inv:" .. slot]
end
-- Enum.TransmogCollectionType (TransmogSharedDocumentation.lua), every value.
_G.Enum.TransmogCollectionType = {
  None = 0, Head = 1, Shoulder = 2, Back = 3, Chest = 4, Shirt = 5, Tabard = 6, Wrist = 7,
  Hands = 8, Waist = 9, Legs = 10, Feet = 11, Wand = 12, OneHAxe = 13, OneHSword = 14,
  OneHMace = 15, Dagger = 16, Fist = 17, Shield = 18, Holdable = 19, TwoHAxe = 20, TwoHSword = 21,
  TwoHMace = 22, Staff = 23, Polearm = 24, Bow = 25, Gun = 26, Crossbow = 27, Warglaives = 28,
  Paired = 29,
}
-- Enum.TooltipDataLineType (TooltipInfoSharedDocumentation.lua), every value.
_G.Enum.TooltipDataLineType = {
  None = 0, Blank = 1, UnitName = 2, GemSocket = 3, AzeriteEssenceSlot = 4,
  AzeriteEssencePower = 5, LearnableSpell = 6, UnitThreat = 7, QuestObjective = 8,
  AzeriteItemPowerDescription = 9, RuneforgeLegendaryPowerDescription = 10, SellPrice = 11,
  ProfessionCraftingQuality = 12, SpellName = 13, CurrencyTotal = 14,
  ItemEnchantmentPermanent = 15, UnitOwner = 16, QuestTitle = 17, QuestPlayer = 18,
  NestedBlock = 19, ItemBinding = 20, EquipSlot = 21, ItemName = 22, Separator = 23, ToyName = 24,
  ToyText = 25, ToyEffect = 26, ToyDuration = 27, ToyDescription = 28, ToySource = 29,
  GemSocketEnchantment = 30, ItemLevel = 31, ItemUpgradeLevel = 32, SpellPassive = 33,
  SpellDescription = 34, ItemQuality = 35, TradeTimeRemaining = 36, FlavorText = 37,
  ItemSpellTriggerLearn = 38, LearnTransmogSet = 39, LearnTransmogIllusion = 40, ErrorLine = 41,
  DisabledLine = 42, UsageRequirement = 43, ItemSpellTriggerOnUse = 44,
  ItemSpellTriggerOnEquip = 45, ItemSpellTriggerOnProc = 46, UnitLevel = 47, UnitType = 48,
  UnitDead = 49, UnitCriteriaProgress = 50, AuraCaster = 51,
}
_G.C_TooltipInfo = _G.C_TooltipInfo or {}
_G.C_TooltipInfo.GetInventoryItem = function(unit, slot)
  return { type = 0, lines = {}, repairCost = _G._repairCosts["inv:" .. slot] }
end
_G.C_TooltipInfo.GetBagItem = _G.C_TooltipInfo.GetBagItem or function(bag, slot)
  return { type = 0, lines = {}, repairCost = _G._repairCosts["bag:" .. bag .. ":" .. slot] }
end
_G.C_TooltipInfo.GetMerchantItem = function(index)
  local item = merchantItem(index)
  return { type = 0, lines = item and item.tooltipLines or {} }
end
-- The guild bank. Its functions are legacy globals with no generated documentation (only
-- C_GuildBank.IsGuildBankEnabled and its events are documented, GuildBankDocumentation.lua); their
-- shapes are what Blizzard's guild bank UI reads (Blizzard_GuildBankUI Mainline and TBC
-- Blizzard_GuildBankUI.lua) and warcraft.wiki.gg's API list (World_of_Warcraft_API, Guild Bank).
-- Specs describe the guild bank in _G._guildBank and read what was asked of it in
-- _G._guildBankCalls (reset both with ResetMockGuildBank):
--   tabs[t] = { name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals, filtered,
--     slots = { [slot] = { link, texture, count, locked, isFiltered, quality, tooltipLines } } }
--   delivered[t]: the server sent the tab (a query was answered). Until then its slots read nothing,
--     like a tab the client never received.
--   current: the current tab (GetCurrentGuildBankTab; Blizzard's frame acts only on it).
--   money, withdrawMoney (-1: no limit), canWithdrawMoney, isLeader, tabCost (nil when every tab is
--   bought), canEditTabs, guildName (nil: not in a guild).
-- Each action records the current tab when it was asked (current), so a spec sees which tab it
-- acted on.
_G.MAX_GUILDBANK_TABS = 8
_G.MAX_BUY_GUILDBANK_TABS = 6
-- The guild bank's bootstrap file defines this at startup on retail (Blizzard_GuildBankUI_Bootstrap.lua).
_G.GuildBankFrame_LoadUI = function() return true end
function _G.ResetMockGuildBank()
  _G._guildBank = { tabs = {}, delivered = {}, current = 1, money = 0, withdrawMoney = 0, canWithdrawMoney = false,
    isLeader = false, tabCost = nil, canEditTabs = false, guildName = "The Guild" }
  _G._guildBankCalls = { queries = {}, setCurrent = {}, pickup = {}, autoStore = {}, split = {}, deposits = {},
    withdrawals = {}, closed = 0, bought = 0, tabInfo = {}, tooltips = {}, splitFrames = {}, cursorMoneyDropped = 0,
    splitHidden = 0 }
end
_G.ResetMockGuildBank()

local function guildSlot(tab, slot)
  local t = _G._guildBank.tabs[tab]
  if t == nil or not _G._guildBank.delivered[tab] then return nil end
  return t.slots and t.slots[slot]
end

-- GetNumGuildBankTabs() -> numTabs (purchased tabs).
_G.GetNumGuildBankTabs = function() return #_G._guildBank.tabs end
-- GetGuildBankTabInfo(tab) -> name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals,
-- filtered. Nothing for a tab past the purchased ones.
_G.GetGuildBankTabInfo = function(tab)
  local t = _G._guildBank.tabs[tab]
  if t == nil then return nil end
  return t.name, t.icon, t.isViewable ~= false, t.canDeposit ~= false, t.numWithdrawals or 0,
    t.remainingWithdrawals or 0, t.filtered == true
end
-- GetGuildBankItemInfo(tab, slot) -> texture, itemCount, locked, isFiltered, quality; nothing for an
-- empty slot.
_G.GetGuildBankItemInfo = function(tab, slot)
  local item = guildSlot(tab, slot)
  if item == nil then return nil end
  return item.texture, item.count or 1, item.locked == true, item.isFiltered == true, item.quality
end
_G.GetGuildBankItemLink = function(tab, slot) local item = guildSlot(tab, slot) return item and item.link end
_G.GetCurrentGuildBankTab = function() return _G._guildBank.current end
_G.SetCurrentGuildBankTab = function(tab)
  table.insert(_G._guildBankCalls.setCurrent, tab)
  _G._guildBank.current = tab
end
_G.QueryGuildBankTab = function(tab) table.insert(_G._guildBankCalls.queries, tab) end
_G.PickupGuildBankItem = function(tab, slot)
  table.insert(_G._guildBankCalls.pickup, { tab = tab, slot = slot, current = _G._guildBank.current })
end
_G.AutoStoreGuildBankItem = function(tab, slot)
  table.insert(_G._guildBankCalls.autoStore, { tab = tab, slot = slot, current = _G._guildBank.current })
end
_G.SplitGuildBankItem = function(tab, slot, amount)
  table.insert(_G._guildBankCalls.split, { tab = tab, slot = slot, amount = amount, current = _G._guildBank.current })
end
_G.GetGuildBankMoney = function() return _G._guildBank.money end
_G.GetGuildBankWithdrawMoney = function() return _G._guildBank.withdrawMoney end
_G.CanWithdrawGuildBankMoney = function() return _G._guildBank.canWithdrawMoney end
_G.DepositGuildBankMoney = function(money) table.insert(_G._guildBankCalls.deposits, money) end
_G.WithdrawGuildBankMoney = function(money) table.insert(_G._guildBankCalls.withdrawals, money) end
-- DropCursorMoney() puts money on the cursor back (Blizzard's item button, for "guildbankmoney").
_G.DropCursorMoney = function() _G._guildBankCalls.cursorMoneyDropped = _G._guildBankCalls.cursorMoneyDropped + 1 end
_G.CloseGuildBankFrame = function() _G._guildBankCalls.closed = _G._guildBankCalls.closed + 1 end
_G.IsGuildLeader = function() return _G._guildBank.isLeader end
_G.GetGuildBankTabCost = function() return _G._guildBank.tabCost end
_G.BuyGuildBankTab = function() _G._guildBankCalls.bought = _G._guildBankCalls.bought + 1 end
_G.CanEditGuildBankTabInfo = function() return _G._guildBank.canEditTabs end
_G.SetGuildBankTabInfo = function(tab, name, icon)
  table.insert(_G._guildBankCalls.tabInfo, { tab = tab, name = name, icon = icon })
end
-- GetGuildInfo(unit) -> guildName, guildRankName, guildRankIndex; nothing when not in a guild.
_G.GetGuildInfo = function()
  if _G._guildBank.guildName == nil then return nil end
  return _G._guildBank.guildName, "Member", 3
end
-- C_TooltipInfo.GetGuildBankItem(tab, slot) -> TooltipData (TooltipInfoDocumentation.lua).
_G.C_TooltipInfo.GetGuildBankItem = function(tab, slot)
  local item = guildSlot(tab, slot)
  return { type = 0, lines = item and item.tooltipLines or {}, dataInstanceID = item and item.dataInstanceID }
end
-- GameTooltip:SetGuildBankItem(tab, slot) as retail and WoW: Forever define it: a tooltip data
-- accessor (TooltipDataHandler.lua, GameTooltipDataMixin = CreateFromMixins(TooltipDataHandlerMixin)),
-- which shows C_TooltipInfo.GetGuildBankItem's data and returns true, or hides the tooltip and returns
-- false without data (TooltipDataHandlerMixin:InternalProcessInfo). It returns nothing else. Classic's
-- is the native method, which returns a caged battle pet's values (TBC Blizzard_GuildBankUI.lua); specs
-- for Classic install it.
function _G.GameTooltip:SetGuildBankItem(tab, slot)
  table.insert(_G._guildBankCalls.tooltips, { tab = tab, slot = slot })
  if not _G.C_TooltipInfo.GetGuildBankItem(tab, slot) then
    self:Hide()
    return false
  end
  self:Show()
  return true
end
-- The stack split frame: StackSplitFrame:OpenStackSplitFrame(maxStack, parent, anchor, anchorTo) on
-- retail, the global OpenStackSplitFrame on Classic (each guild bank's item button).
_G.StackSplitFrame = _G.StackSplitFrame or {}
function _G.StackSplitFrame:OpenStackSplitFrame(maxStack, owner, anchor, anchorTo)
  table.insert(_G._guildBankCalls.splitFrames, { max = maxStack, owner = owner, anchor = anchor, anchorTo = anchorTo })
end
function _G.StackSplitFrame:Hide()
  _G._guildBankCalls.splitHidden = _G._guildBankCalls.splitHidden + 1
end
_G.OpenStackSplitFrame = function(maxStack, owner, anchor, anchorTo)
  _G.StackSplitFrame:OpenStackSplitFrame(maxStack, owner, anchor, anchorTo)
end
-- Blizzard's strings its guild bank UI formats (GlobalStrings, enUS).
_G.GUILDBANK_TAB_NUMBER = "Tab %d"
_G.GUILDBANK_TAB_FULL_ACCESS = "(Full Access)"
_G.GUILDBANK_TAB_DEPOSIT_ONLY = "(Deposit Only)"
_G.GUILDBANK_TAB_WITHDRAW_ONLY = "(Withdraw Only)"
_G.GUILDBANK_TAB_LOCKED = "(Locked)"
_G.GUILDBANK_REMAINING_MONEY = "Remaining daily withdrawals for %s: %s"
_G.STACKS = "%d stacks"
_G.UNLIMITED = "Unlimited"
_G.NONE = _G.NONE or "None"
_G.BUY_GUILDBANK_TAB = "Buy Guild Bank Tab"
_G.SOUNDKIT.GUILD_VAULT_OPEN = _G.SOUNDKIT.GUILD_VAULT_OPEN or 12188
_G.SOUNDKIT.GUILD_VAULT_CLOSE = _G.SOUNDKIT.GUILD_VAULT_CLOSE or 12189
_G.SOUNDKIT.GUILD_BANK_OPEN_BAG = _G.SOUNDKIT.GUILD_BANK_OPEN_BAG or 12206
-- Enum.PlayerInteractionType: the interactions BetterBags follows (PlayerInteractionType in
-- Blizzard_APIDocumentationGenerated, live branch).
_G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or {
  None = 0, TradePartner = 1, Item = 2, Gossip = 3, QuestGiver = 4, Merchant = 5, TaxiNode = 6, Trainer = 7,
  Banker = 8, GuildBanker = 10, Vendor = 12, MailInfo = 17, Auctioneer = 21, VoidStorageBanker = 26,
  ScrappingMachine = 40, ItemUpgrade = 53, CharacterBanker = 67, AccountBanker = 68,
}

-- HandleModifiedItemClick(link) -> handled (a chat link, a dress-up: ItemButtonTemplate.lua);
-- DressUpItemLink(link); SetCursor(cursor), ResetCursor().
_G.HandleModifiedItemClick = function() return _G._modifiedClickHandled == true end
_G.SetCursor = function(cursor) _G._cursor = cursor end
_G.ResetCursor = function() _G._cursor = nil end

-- The merchant frame's helpers. ResetSetMerchantFilter() (retail; MerchantFrame_OnShow calls it on
-- every open) resets the filter to the client's default. ContainerFrame_GetExtendedPriceString(
-- itemButton, isEquipped, quantity) shows Blizzard's refund confirmation and returns true when the
-- item is refundable (ContainerFrame.lua); specs set _G._extendedPriceShown. StaticPopup_Hide(which).
_G.ResetSetMerchantFilter = function()
  _G._merchant.filter = _G.LE_LOOT_FILTER_CLASS
  _G._merchantCalls.filterReset = (_G._merchantCalls.filterReset or 0) + 1
end
_G.ContainerFrame_GetExtendedPriceString = function(itemButton, isEquipped)
  _G._extendedPriceAsked = { button = itemButton, isEquipped = isEquipped }
  return _G._extendedPriceShown == true
end
_G._hiddenPopups = {}
_G.StaticPopup_Hide = function(which) table.insert(_G._hiddenPopups, which) end
-- C_GameRules.IsGameRuleActive(rule) (GameRulesDocumentation.lua); MerchantFrame.lua checks
-- Enum.GameRule.MerchantFilterDisabled. Specs set _G._gameRules[rule].
_G.Enum.GameRule = _G.Enum.GameRule or { MerchantFilterDisabled = 54 }
_G._gameRules = {}
_G.C_GameRules = _G.C_GameRules or {}
_G.C_GameRules.IsGameRuleActive = function(rule) return _G._gameRules[rule] == true end
-- GetNumSpecializations() and C_SpecializationInfo.GetSpecializationInfo(index, ...) -> id, name
-- (MerchantFrame_OnLoad lists the specs as filters).
_G.GetNumSpecializations = _G.GetNumSpecializations or function() return 2 end
_G.C_SpecializationInfo = _G.C_SpecializationInfo or {}
_G.C_SpecializationInfo.GetSpecializationInfo = _G.C_SpecializationInfo.GetSpecializationInfo
  or function(index) return 100 + index, "Spec " .. index end
-- MenuUtil.CreateContextMenu(ownerRegion, generator, ...) (Blizzard_Menu/MenuUtil.lua): calls
-- generator(ownerRegion, rootDescription, ...). The mock's root description records what is made:
-- SetTag, CreateRadio(text, isSelected, setSelected, data), CreateDivider. Specs read
-- _G._lastContextMenu.
_G.MenuUtil = _G.MenuUtil or {}
_G.MenuUtil.CreateContextMenu = function(owner, generator, ...)
  local root = { entries = {} }
  function root:SetTag(tag) self.tag = tag end
  function root:CreateRadio(text, isSelected, setSelected, data)
    table.insert(self.entries, { kind = "radio", text = text, isSelected = isSelected, setSelected = setSelected, data = data })
  end
  function root:CreateDivider() table.insert(self.entries, { kind = "divider" }) end
  generator(owner, root, ...)
  _G._lastContextMenu = { owner = owner, root = root }
  return root
end

-- ColorPickerFrame (Blizzard_ColorPickerFrame, loaded at login on every client: ColorPickerFrameMixin):
-- SetupColorPickerAndShow(info) keeps info's swatchFunc, opacityFunc, cancelFunc and hasOpacity, its
-- color as previousValues ({ r, g, b, a = info.opacity }), and shows; GetColorRGB() and
-- GetColorAlpha() read the color picked. Blizzard calls swatchFunc as the color changes, opacityFunc as
-- the opacity does, and cancelFunc(previousValues) on Cancel. Specs pick with _Pick(r, g, b, a) and
-- cancel with _Cancel().
_G.ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame")
_G.ColorPickerFrame:Hide()
function _G.ColorPickerFrame:SetupColorPickerAndShow(info)
  self.info = info
  self.swatchFunc, self.opacityFunc, self.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
  self.hasOpacity = info.hasOpacity
  self.previousValues = { r = info.r, g = info.g, b = info.b, a = info.opacity }
  self._r, self._g, self._b, self._a = info.r, info.g, info.b, info.opacity or 1
  self:Show()
end
function _G.ColorPickerFrame:GetColorRGB() return self._r, self._g, self._b end
function _G.ColorPickerFrame:GetColorAlpha() return self._a end
function _G.ColorPickerFrame:_Pick(r, g, b, a)
  self._r, self._g, self._b = r, g, b
  if self.swatchFunc then self.swatchFunc() end
  if a ~= nil then
    self._a = a
    if self.opacityFunc then self.opacityFunc() end
  end
end
function _G.ColorPickerFrame:_Cancel()
  self:Hide()
  if self.cancelFunc then self.cancelFunc(self.previousValues) end
end
