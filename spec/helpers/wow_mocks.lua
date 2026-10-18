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
local function CreateMockWidget(widgetType, name, parent)
  local widget = {}
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
  local isRegion = widgetType == "Texture" or widgetType == "FontString" or widgetType == "MaskTexture"
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

  -- Core frame behavior
  function widget:SetScript(scriptName, handler)
    self._scripts[scriptName] = handler
  end
  function widget:GetScript(scriptName)
    return self._scripts[scriptName]
  end
  function widget:HookScript(scriptName, handler)
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
  function widget:Show()
    self._shown = true
  end
  function widget:Hide()
    self._shown = false
  end
  function widget:IsShown()
    return self._shown
  end
  -- ScriptRegion:IsVisible() -> true only when this region and every parent are shown.
  function widget:IsVisible()
    if not self._shown then return false end
    local owner = self._parent
    if owner and owner.IsVisible then
      return owner:IsVisible()
    end
    return true
  end
  function widget:SetShown(shown)
    self._shown = shown
  end
  function widget:GetName()
    return self._name
  end
  function widget:RegisterEvent(event)
    self._events[event] = true
  end
  function widget:UnregisterEvent(event)
    self._events[event] = nil
  end
  function widget:SetOwner(owner, anchor, x, y)
    self._owner = owner
    self._anchor = anchor
    self._ownerX = x
    self._ownerY = y
  end
  function widget:SetParent(parentFrame)
    local previous = self._parent
    if not isRegion and previous ~= parentFrame then
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
  function widget:GetChildren()
    return unpack(self._children)
  end
  function widget:GetParent()
    return self._parent
  end
  function widget:SetID(id)
    self._id = id
  end
  function widget:GetID()
    return self._id or 0
  end
  function widget:SetSize(w, h)
    self._width = w
    self._height = h
  end
  function widget:SetWidth(w)
    self._width = w
  end
  function widget:SetHeight(h)
    self._height = h
  end
  function widget:GetWidth()
    return self._width or 0
  end
  function widget:GetHeight()
    return self._height or 0
  end
  -- ScriptRegion:GetSize(ignoreRect?) -> width, height.
  function widget:GetSize()
    return self:GetWidth(), self:GetHeight()
  end
  -- ScriptRegion:GetLeft/GetRight/GetTop/GetBottom/GetCenter "MayReturnNothing": with no
  -- layout engine in specs, a frame's rect is never resolved unless a spec sets it with
  -- _SetRect(left, bottom, width, height).
  function widget:_SetRect(left, bottom, width, height)
    self._rect = { left = left, bottom = bottom }
    self:SetSize(width, height)
  end
  function widget:GetLeft()
    return self._rect and self._rect.left
  end
  function widget:GetBottom()
    return self._rect and self._rect.bottom
  end
  function widget:GetRight()
    return self._rect and (self._rect.left + self:GetWidth())
  end
  function widget:GetTop()
    return self._rect and (self._rect.bottom + self:GetHeight())
  end
  function widget:GetCenter()
    if self._rect == nil then return nil end
    return self._rect.left + self:GetWidth() / 2, self._rect.bottom + self:GetHeight() / 2
  end
  -- ScriptRegion:IsMouseOver(offsetTop, offsetBottom, offsetLeft, offsetRight)
  -- (SimpleScriptRegionAPIDocumentation): whether the cursor (GetCursorPosition, in the region's
  -- scale) is inside the region's rect moved out by the offsets; Blizzard enlarges it with
  -- IsMouseOver(10, -10, 0, 10) (FloatingChatFrame.lua). False for a region with no rect.
  function widget:IsMouseOver(offsetTop, offsetBottom, offsetLeft, offsetRight)
    local left, right, top, bottom = self:GetLeft(), self:GetRight(), self:GetTop(), self:GetBottom()
    if left == nil then return false end
    local scale = self:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    return x >= left + (offsetLeft or 0) and x <= right + (offsetRight or 0)
      and y >= bottom + (offsetBottom or 0) and y <= top + (offsetTop or 0)
  end
  function widget:SetAlpha(alpha)
    self._alpha = alpha
  end
  function widget:GetAlpha()
    return self._alpha or 1
  end
  -- ScriptRegionResizing:SetAllPoints([relativeTo, doResize]): only the TOPLEFT and BOTTOMRIGHT
  -- points are set, after clearing the others (warcraft.wiki.gg); relativeTo defaults to the
  -- parent.
  function widget:SetAllPoints(other)
    local relativeTo = other or self:GetParent()
    self._points = {
      { point = "TOPLEFT", relativeTo = relativeTo, relativePoint = "TOPLEFT", x = 0, y = 0 },
      { point = "BOTTOMRIGHT", relativeTo = relativeTo, relativePoint = "BOTTOMRIGHT", x = 0, y = 0 },
    }
    self._allPoints = other or true
  end
  function widget:ClearAllPoints()
    self._points = {}
    self._allPoints = nil
  end
  -- ScriptRegion:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
  -- (SimpleScriptRegionResizingAPIDocumentation): both offsets are required together. In game an
  -- x offset given with a nil y offset was dropped (a render recording: a scroll box's child
  -- anchored 14 in sat at 0), so the mock rejects one offset without the other.
  function widget:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(relativePoint) == "string" and (x == nil) ~= (y == nil) then
      error("SetPoint: offsetX and offsetY must be given together, got " .. tostring(x) .. ", " .. tostring(y), 2)
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
  function widget:GetNumPoints()
    return #self._points
  end
  function widget:GetPoint(index)
    index = index or 1
    local p = self._points[index]
    if p then
      return p.point, p.relativeTo, p.relativePoint, p.x or 0, p.y or 0
    end
    return nil
  end
  function widget:EnableMouse(enable)
    self._mouseEnabled = enable
  end
  -- ScriptRegion:IsMouseEnabled() -> enabled (SimpleScriptRegionAPIDocumentation). Buttons take
  -- the mouse until told otherwise.
  function widget:IsMouseEnabled()
    if self._mouseEnabled ~= nil then
      return self._mouseEnabled == true
    end
    return self._type == "Button" or self._type == "CheckButton"
  end
  function widget:EnableMouseWheel(enable)
    self._mouseWheelEnabled = enable
  end
  -- Frame:EnableKeyboard(enable)
  function widget:EnableKeyboard(enable)
    self._keyboardEnabled = enable
  end
  function widget:RegisterForClicks(...)
    self._registeredClicks = {...}
  end
  function widget:RegisterForDrag(...)
    self._registeredDrags = {...}
  end
  -- Frame:StartMoving() / StopMovingOrSizing() (SimpleFrameAPIDocumentation.lua).
  -- Frame:StartMoving() errors on a frame that is not movable (warcraft.wiki.gg).
  function widget:StartMoving()
    if not self._movable then
      error("Frame:StartMoving(): Frame is not movable", 2)
    end
    self._moving = true
  end
  function widget:StopMovingOrSizing()
    self._moving = false
  end
  -- Button: Enable() / Disable() / IsEnabled() -> boolean, LockHighlight() / UnlockHighlight().
  function widget:Enable()
    self._enabled = true
  end
  function widget:Disable()
    self._enabled = false
  end
  function widget:IsEnabled()
    return self._enabled ~= false
  end
  -- SetEnabled(enabled) (SimpleButtonAPIDocumentation.lua).
  function widget:SetEnabled(enabled)
    self._enabled = enabled and true or false
  end
  function widget:LockHighlight()
    self._highlightLocked = true
  end
  function widget:UnlockHighlight()
    self._highlightLocked = false
  end
  -- CheckButton: SetChecked(checked) / GetChecked() -> boolean.
  function widget:SetChecked(checked)
    self._checked = checked == true
  end
  function widget:GetChecked()
    return self._checked == true
  end

  -- Textures and FontStrings
  function widget:CreateTexture(textureName, drawLayer, inherits)
    local tex = CreateMockWidget("Texture", textureName, self)
    tex._drawLayer = drawLayer
    tex._inherits = inherits
    table.insert(self._textures, tex)
    return tex
  end
  function widget:CreateFontString(fontStringName, drawLayer, inherits)
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
  function widget:SetNormalTexture(texture)
    setStateTexture(self, "GetNormalTexture", "NormalTexture", texture, "SetNormalTexture")
  end
  function widget:GetNormalTexture()
    if (not self.NormalTexture or type(self.NormalTexture) == "string") and widgetType ~= "Texture" then
      self.NormalTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.NormalTexture
  end
  function widget:GetPushedTexture()
    if not self.PushedTexture and widgetType ~= "Texture" then
      self.PushedTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.PushedTexture
  end
  function widget:GetHighlightTexture()
    if not self.HighlightTexture and widgetType ~= "Texture" then
      self.HighlightTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.HighlightTexture
  end
  -- SimpleButtonAPIDocumentation.lua: SetHighlightTexture(asset, blendMode?) sets the
  -- button's highlight region; Set{Pushed,Disabled}Texture(asset) and the Set*Atlas
  -- variants likewise set their state region.
  -- Button:SetHighlightTexture(asset, blendMode?): the blend mode defaults to ADD
  -- (wowprogramming, Button:SetHighlightTexture).
  function widget:SetHighlightTexture(texture, blendMode)
    self._highlightTexture = texture
    setStateTexture(self, "GetHighlightTexture", "HighlightTexture", texture, "SetHighlightTexture")
    self:GetHighlightTexture():SetBlendMode(blendMode or "ADD")
  end
  function widget:SetPushedTexture(texture)
    setStateTexture(self, "GetPushedTexture", "PushedTexture", texture, "SetPushedTexture")
  end
  function widget:GetDisabledTexture()
    if not self.DisabledTexture and widgetType ~= "Texture" then
      self.DisabledTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.DisabledTexture
  end
  function widget:SetDisabledTexture(texture)
    setStateTexture(self, "GetDisabledTexture", "DisabledTexture", texture, "SetDisabledTexture")
  end
  -- Clear{Normal,Pushed,Disabled,Highlight}Texture() remove what the state draws.
  local function clearState(button, getter)
    local region = button[getter](button)
    if region ~= nil then
      region:SetTexture(nil)
    end
  end
  function widget:ClearNormalTexture() clearState(self, "GetNormalTexture") end
  function widget:ClearPushedTexture() clearState(self, "GetPushedTexture") end
  function widget:ClearDisabledTexture() clearState(self, "GetDisabledTexture") end
  function widget:ClearHighlightTexture() clearState(self, "GetHighlightTexture") end
  -- Frame:SetHitRectInsets(left, right, top, bottom) / GetHitRectInsets().
  function widget:SetHitRectInsets(left, right, top, bottom)
    self._hitRectInsets = { left, right, top, bottom }
  end
  function widget:GetHitRectInsets()
    local i = self._hitRectInsets or { 0, 0, 0, 0 }
    return i[1], i[2], i[3], i[4]
  end
  -- UIObject:GetObjectType() -> the widget type ("Frame", "Button", "Texture", ...);
  -- IsObjectType(type) is also true for the types it derives from (every frame type is a
  -- Frame, every widget a Region).
  function widget:GetObjectType()
    return self._type
  end
  function widget:IsObjectType(objectType)
    if objectType == self._type or objectType == "Region" or objectType == "Object" then
      return true
    end
    if objectType == "Frame" then
      return not isRegion
    end
    if objectType == "Button" then
      return self._type == "CheckButton" or self._type == "ItemButton"
    end
    return false
  end
  function widget:SetHighlightAtlas(atlas, blendMode)
    self._highlightAtlas = atlas
    local highlight = self:GetHighlightTexture()
    highlight:SetAtlas(atlas)
    if blendMode then highlight:SetBlendMode(blendMode) end
  end
  function widget:SetPushedAtlas(atlas)
    self._pushedAtlas = atlas
    self:GetPushedTexture():SetAtlas(atlas)
  end
  function widget:SetDisabledAtlas(atlas)
    self._disabledAtlas = atlas
    self:GetDisabledTexture():SetAtlas(atlas)
  end
  -- SimpleTextureBaseAPIDocumentation.lua: SetTextureSliceMargins(left, top, right, bottom),
  -- SetTextureSliceMode(sliceMode), SetHorizTile(tiling), SetVertTile(tiling); GetTexture()
  -- and GetAtlas() return what was set.
  function widget:SetTextureSliceMargins(left, top, right, bottom)
    self._sliceMargins = { left = left, top = top, right = right, bottom = bottom }
  end
  function widget:SetTextureSliceMode(sliceMode)
    self._sliceMode = sliceMode
  end
  -- ClearTextureSlice() drops the slice margins and mode.
  function widget:ClearTextureSlice()
    self._sliceMargins = nil
    self._sliceMode = nil
  end
  function widget:SetHorizTile(tiling)
    self._horizTile = tiling
  end
  function widget:SetVertTile(tiling)
    self._vertTile = tiling
  end
  -- TextureBase:GetHorizTile() / GetVertTile() -> tiling.
  function widget:GetHorizTile()
    return self._horizTile == true
  end
  function widget:GetVertTile()
    return self._vertTile == true
  end
  function widget:GetTexture()
    return self._texturePath
  end
  function widget:GetAtlas()
    return self._atlas
  end
  function widget:GetVertexColor()
    local c = self._vertexColor
    if c then return c.r, c.g, c.b, c.a end
    return 1, 1, 1, 1
  end
  -- FontInstance: SetFontObject(font) / GetFontObject(), SetShadowOffset(offsetX, offsetY).
  function widget:SetFontObject(font)
    self._fontObject = font
  end
  function widget:SetShadowOffset(x, y)
    self._shadowOffset = { x = x, y = y }
  end
  -- Frame:SetResizable(resizable), SetResizeBounds(minWidth, minHeight, maxWidth?, maxHeight?),
  -- StartSizing(resizePoint?), SetToplevel(topLevel), SetClampedToScreen(clamped),
  -- SetMovable(movable), SetScale(scale) / GetScale().
  function widget:SetResizable(resizable)
    self._resizable = resizable
  end
  function widget:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    self._resizeBounds = { minWidth = minWidth, minHeight = minHeight, maxWidth = maxWidth, maxHeight = maxHeight }
  end
  -- Frame:StartSizing(resizePoint?, alwaysStartFromMouse = false) (SimpleFrameAPIDocumentation).
  function widget:StartSizing(point, alwaysStartFromMouse)
    self._sizing = point or "BOTTOMRIGHT"
    self._sizingFromMouse = alwaysStartFromMouse == true
  end
  function widget:SetToplevel(topLevel)
    self._toplevel = topLevel
  end
  function widget:SetClampedToScreen(clamped)
    self._clamped = clamped
  end
  function widget:IsClampedToScreen()
    return self._clamped == true
  end
  -- Frame:SetClampRectInsets(left, right, top, bottom).
  function widget:SetClampRectInsets(left, right, top, bottom)
    self._clampRectInsets = { left, right, top, bottom }
  end
  function widget:SetMovable(movable)
    self._movable = movable
  end
  function widget:SetScale(scale)
    self._scale = scale
  end
  function widget:GetScale()
    return self._scale or 1
  end
  -- Region:GetEffectiveScale() -> the frame's scale times every parent's.
  function widget:GetEffectiveScale()
    local scale = self:GetScale()
    local owner = self._parent
    if owner ~= nil and owner.GetEffectiveScale ~= nil then
      scale = scale * owner:GetEffectiveScale()
    end
    return scale
  end
  -- SimpleAnimatableObjectAPIDocumentation.lua: CreateAnimationGroup(name?, templateName?).
  function widget:CreateAnimationGroup(groupName)
    return CreateMockAnimationGroup(self, groupName)
  end
  function widget:SetBlendMode(mode)
    self._blendMode = mode
  end
  -- TextureBase:GetBlendMode() -> blendMode (non-nilable; textures default to "BLEND").
  function widget:GetBlendMode()
    return self._blendMode or "BLEND"
  end
  function widget:SetDrawLayer(layer, sublevel)
    self._drawLayer = layer
    self._sublevel = sublevel
  end
  -- Region:GetDrawLayer() -> layer, sublevel.
  function widget:GetDrawLayer()
    return self._drawLayer or "ARTWORK", self._sublevel or 0
  end
  -- TextureBase:SetTexture(textureAsset) replaces whatever the texture drew (an atlas or a
  -- color texture); nil clears it.
  -- TextureBase:SetTexture(asset, wrapModeHorizontal?, wrapModeVertical?, filterMode?).
  function widget:SetTexture(path, wrapH, wrapV, filterMode)
    self._texturePath = path
    self._wrapH, self._wrapV, self._filterMode = wrapH, wrapV, filterMode
    self._atlas = nil
    self._colorTexture = nil
  end
  function widget:SetTexCoord(...)
    self._texCoords = {...}
  end
  -- TextureBase:SetRotation(radians, normalizedRotationPoint?) and GetRotation() -> radians
  -- (SimpleTextureBaseAPIDocumentation, every client).
  function widget:SetRotation(radians)
    self._rotation = radians
  end
  function widget:GetRotation()
    return self._rotation or 0
  end
  -- TextureBase:SetGradient(orientation, minColor, maxColor) with two ColorMixins.
  function widget:SetGradient(orientation, minColor, maxColor)
    self._gradient = { orientation = orientation, min = minColor, max = maxColor }
  end
  -- TextureBase:GetTexCoord() -> the eight corner coordinates (ULx, ULy, LLx, LLy, URx, URy,
  -- LRx, LRy); a texture set with left, right, top, bottom reports its corners.
  function widget:GetTexCoord()
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
  function widget:SetAtlas(atlas, useAtlasSize, filterMode, _, wrapH, wrapV)
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
  function widget:SetColorTexture(r, g, b, a)
    self._colorTexture = {r = r, g = g, b = b, a = a or 1}
    self._wrapH, self._wrapV = nil, nil
    self._atlas = nil
    self._texturePath = nil
  end
  -- TextureBase:SetDesaturated(desaturated?) / IsDesaturated() -> boolean.
  function widget:SetDesaturated(desaturated)
    self._desaturated = desaturated == true
  end
  function widget:IsDesaturated()
    return self._desaturated == true
  end
  function widget:SetNormalAtlas(atlas)
    self._normalAtlas = atlas
    self:GetNormalTexture():SetAtlas(atlas)
  end
  function widget:SetNormalFontObject(fontObject)
    self._normalFontObject = fontObject
  end
  -- SimpleButtonAPIDocumentation.lua: Get{Normal,Highlight,Disabled}FontObject().
  function widget:GetNormalFontObject() return self._normalFontObject end
  function widget:GetHighlightFontObject() return self._highlightFontObject end
  function widget:GetDisabledFontObject() return self._disabledFontObject end
  -- SimpleButtonAPIDocumentation.lua: SetHighlightFontObject(font), SetDisabledFontObject(font).
  function widget:SetHighlightFontObject(fontObject)
    self._highlightFontObject = fontObject
  end
  function widget:SetDisabledFontObject(fontObject)
    self._disabledFontObject = fontObject
  end
  -- SimpleEditBoxAPIDocumentation.lua: SetTextInsets(left, right, top, bottom).
  function widget:SetTextInsets(left, right, top, bottom)
    self._textInsets = { left, right, top, bottom }
  end
  function widget:SetFontString(fontString)
    self._fontString = fontString
  end
  function widget:GetFontString()
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
  function widget:SetText(text)
    if self._type == "FontString" and self._font == nil and self._fontObject == nil and self._inherits == nil then
      error("FontString:SetText(): Font not set", 2)
    end
    self._text = tostring(text or "")
    if self._fontString ~= nil then
      self._fontString._text = self._text
    end
  end
  function widget:SetTextHeight(height)
    self._textHeight = height
  end
  function widget:SetWordWrap(wrap)
    self._wordWrap = wrap
  end
  function widget:SetNonSpaceWrap(wrap)
    self._nonSpaceWrap = wrap
  end
  -- Slider widget API (UISliderTemplate / HorizontalSliderTemplate).
  function widget:SetOrientation(orientation)
    self._orientation = orientation
  end
  function widget:SetMinMaxValues(minValue, maxValue)
    self._minValue = minValue
    self._maxValue = maxValue
  end
  function widget:SetValueStep(step)
    self._valueStep = step
  end
  function widget:SetObeyStepOnDrag(obey)
    self._obeyStepOnDrag = obey
  end
  -- Slider:SetValue(value [, treatAsMouseEvent]) fires OnValueChanged(self, value, userInput)
  -- when the value changes; userInput is false for a value set from code
  -- (warcraft.wiki.gg UIHANDLER_OnValueChanged, API Slider_SetValue).
  function widget:SetValue(value, treatAsMouseEvent)
    local changed = self._value ~= value
    self._value = value
    local onValueChanged = changed and self._scripts.OnValueChanged
    if onValueChanged then
      onValueChanged(self, value, treatAsMouseEvent == true)
    end
  end
  function widget:GetValue()
    return self._value or 0
  end
  -- EditBox widget API (InputBoxTemplate).
  -- EditBox:SetMaxLetters(maxLetters) / GetMaxLetters().
  function widget:SetMaxLetters(maxLetters)
    self._maxLetters = maxLetters
  end
  function widget:GetMaxLetters()
    return self._maxLetters or 0
  end
  function widget:SetNumeric(numeric)
    self._numeric = numeric
  end
  function widget:SetAutoFocus(autoFocus)
    self._autoFocus = autoFocus
  end
  function widget:SetFocus()
    self._hasFocus = true
  end
  function widget:ClearFocus()
    self._hasFocus = false
  end
  function widget:HasFocus()
    return self._hasFocus == true
  end
  function widget:GetLineHeight()
    return self._lineHeight or 12
  end
  function widget:SetShadowColor(r, g, b, a)
    self._shadowColor = {r = r, g = g, b = b, a = a or 1}
  end
  -- A font instance's own shadow, else that of the font object it inherits.
  function widget:GetShadowColor()
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
  function widget:GetShadowOffset()
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
  function widget:GetText()
    return self._text
  end
  function widget:GetTextWidth()
    return #self._text * 6
  end
  function widget:GetStringWidth()
    return #self._text * 6
  end
  -- FontString:GetNumLines() -> numLines, IsTruncated() -> isTruncated, CanWordWrap() -> wrap
  -- (SimpleFontStringAPIDocumentation). Lines as GetStringHeight counts them; never truncated.
  function widget:GetNumLines()
    local text = self._text or ""
    if text == "" then return 0 end
    local width = self:GetWidth()
    if width > 0 then
      return math.max(1, math.ceil(self:GetStringWidth() / width))
    end
    return 1
  end
  function widget:IsTruncated()
    return false
  end
  function widget:CanWordWrap()
    return self._wordWrap ~= false
  end
  -- FontString:GetStringHeight() -> the height of the text as drawn: no text is 0; otherwise
  -- one line per GetWidth() worth of characters (6 pixels each, as GetStringWidth), times the
  -- line height. A stand-in for the client's text layout.
  function widget:GetStringHeight()
    local text = self._text or ""
    if text == "" then return 0 end
    local width = self:GetWidth()
    local lines = 1
    if width > 0 then
      lines = math.max(1, math.ceil(self:GetStringWidth() / width))
    end
    return lines * self:GetLineHeight()
  end
  function widget:SetFont(font, size, flags)
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
  -- GetFont() -> fontFile, height, flags (SimpleFontAPIDocumentation.lua).
  function widget:GetFont()
    return self._font, self._fontSize, self._fontFlags or ""
  end
  function widget:SetTextColor(r, g, b, a)
    self._textColor = {r = r, g = g, b = b, a = a or 1}
  end
  -- A font instance's own color, else the default color of the font object it inherits
  -- (changing a font object updates every font string set to it with SetFontObject).
  function widget:GetTextColor()
    if self._textColor then
      return self._textColor.r, self._textColor.g, self._textColor.b, self._textColor.a
    end
    return self:GetFontObject():GetTextColor()
  end
  -- FontInstance:GetFontObject() -> the font object set with SetFontObject, else the one the
  -- font string inherits (CreateFontString's template).
  function widget:GetFontObject()
    local fo = self._fontObject or (self._inherits and _G[self._inherits])
    if fo ~= nil then
      return fo
    end
    return {
      GetTextColor = function()
        return 1, 1, 1, 1
      end
    }
  end
  function widget:SetVertexColor(r, g, b, a)
    self._vertexColor = {r = r, g = g, b = b, a = a or 1}
  end
  function widget:SetJustifyH(justify)
    self._justifyH = justify
  end
  function widget:GetJustifyH()
    return self._justifyH
  end
  function widget:SetJustifyV(justify)
    self._justifyV = justify
  end
  function widget:GetJustifyV()
    return self._justifyV
  end

  widget._attributes = {}
  function widget:SetAttribute(attrName, value)
    self._attributes[attrName] = value
  end
  function widget:GetAttribute(attrName)
    return self._attributes[attrName]
  end

  -- Strata / Level / Backdrop
  function widget:SetFrameStrata(strata)
    self._frameStrata = strata
  end
  function widget:GetFrameStrata()
    return self._frameStrata or "MEDIUM"
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
  function widget:SetFrameLevel(level)
    if not level or type(level) ~= "number" or level < 0 or level > 65535 then
      error("bad argument #1 to 'SetFrameLevel' (outside of expected range 0 to 65535 - Usage: self:SetFrameLevel(frameLevel))", 2)
    end
    local previous = self._frameLevel or 0
    self._frameLevel = level
    if level ~= previous then
      shiftDescendants(self, level - previous)
    end
  end
  function widget:GetFrameLevel()
    return self._frameLevel or 0
  end

  -- Grid Frame scroll/mousewheel APIs
  function widget:HideScrollBar()
    self._scrollBarShown = false
  end
  function widget:ShowScrollBar()
    self._scrollBarShown = true
  end
  function widget:EnableMouseWheelScroll(enable)
    self._mouseWheelScrollEnabled = enable
  end
  function widget:GetContainer()
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
  function widget:SetupMenu(generator)
    self._menuGenerator = generator
    self:GenerateMenu()
  end
  function widget:GenerateMenu()
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
  function widget:Update()
    self:GenerateMenu()
  end

  if widgetType ~= "Texture" then
    widget.NormalTexture = widget:GetNormalTexture()
    widget.PushedTexture = widget:GetPushedTexture()
    widget.NewItemTexture = CreateMockWidget("Texture", nil, widget)
    widget.BattlepayItemTexture = CreateMockWidget("Texture", nil, widget)
    widget.HighlightTexture = widget:GetHighlightTexture()
    widget.ItemContextOverlay = CreateMockWidget("Texture", nil, widget)
    widget.UpgradeIcon = CreateMockWidget("Texture", nil, widget)
    if widgetType == "ItemButton" then
      widget.SetHasItem = function() end
      widget.SetBagID = function(self, id)
        self.bagID = id
      end
      widget.GetBagID = function(self)
        return self.bagID or (self:GetParent() and self:GetParent():GetID() or nil)
      end
      -- ContainerFrameItemButtonMixin:Initialize (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua,
      -- 12.1.5): bag and slot, the extended-slot state, the combined-bags background, then Show.
      widget.Initialize = function(self, bag, slot)
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
      widget.GetSlotAndBagID = function(self)
        return self:GetID(), self:GetBagID()
      end
      widget.IsExtended = function(self)
        return self.isExtended or false
      end
      widget.SetIsExtended = function(self, isExtended)
        self.isExtended = isExtended
      end
      widget.UpdateExtended = function(self)
        local slotId, bagId = self:GetSlotAndBagID()
        local _, currentNumSlots = _G.ContainerFrame_GetContainerNumSlots(bagId)
        self:SetIsExtended(slotId > currentNumSlots)
        self.updateExtendedCalledCount = (self.updateExtendedCalledCount or 0) + 1
      end
    end
  end

  return widget
end

_G.IsAccountSecured = function() return true end

_G.ContainerFrame_GetContainerNumSlots = function(bagID)
  local numSlots = _G.C_Container and _G.C_Container.GetContainerNumSlots(bagID) or 16
  return bagID, numSlots
end

-- Templates a mocked frame can inherit. CreateFrame applies each template named in its
-- comma-separated template list, so a frame gets the regions and mixin methods its XML
-- template gives it in the client. Each entry is built from Blizzard's own template.
_G.__mockTemplates = _G.__mockTemplates or {}

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
  -- ScrollBoxBaseMixin:GetDerivedScrollRange() (the content's extent less the visible extent;
  -- specs set _scrollRange), GetDerivedScrollOffset() (range * scroll percentage), and
  -- ScrollToOffset(offset, noInterpolation): nothing without a range, else the percentage
  -- offset / range, kept between 0 and 1 (ScrollControllerMixin.SetScrollPercentage saturates).
  function frame:GetDerivedScrollRange() return self._scrollRange or 0 end
  function frame:GetDerivedScrollOffset() return self:GetDerivedScrollRange() * (self._scrollPercentage or 0) end
  function frame:ScrollToOffset(offset)
    local range = self:GetDerivedScrollRange()
    if range > 0 then
      self._scrollPercentage = math.max(0, math.min(1, offset / range))
    end
  end
  function frame:FullUpdate(immediately)
    self._fullUpdates = (self._fullUpdates or 0) + 1
    self._lastFullUpdateImmediate = immediately
    self:layoutScrollChildren()
  end
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

_G.hooksecurefunc = function() end
_G.UIParent = CreateMockWidget("Frame", "UIParent")
_G.UIParent:SetSize(1920, 1200)
function _G.UIParent:GetEffectiveScale()
  return 1.0
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
_G.securecallfunction = function(fn, ...)
  return pcall(fn, ...)
end
_G.securecall = _G.securecallfunction

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
function _G.GameTooltip:AddLine(text, r, g, b)
  table.insert(self.lines, {text = text, r = r, g = g, b = b})
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
-- IsModifiedClick(action?) -> isHeld. PICKUPITEM defaults to SHIFT (Bindings_*.xml).
_G.IsModifiedClick = function(action)
  if action == "PICKUPITEM" then return _G.IsShiftKeyDown() end
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
-- C_Item.CanBeRefunded(itemLocation) -> bool (ItemDocumentation.lua). Specs list
-- refundable locations in _G._refundableLocations["bag:slot"].
_G._refundableLocations = {}
_G.C_Item.CanBeRefunded = function(itemLocation)
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
-- C_Item.DoesItemExist(emptiableItemLocation) -> itemExists
_G.C_Item.DoesItemExist = function(itemLocation)
  return itemAtLocation(itemLocation) ~= nil
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

-- Equipment Slot constants
_G.INVSLOT_FIRST_EQUIPPED = 1
_G.INVSLOT_LAST_EQUIPPED = 19

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
