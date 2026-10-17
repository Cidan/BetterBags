-- window_spec.lua -- The Window module (window/window.lua): the root every BetterBags window
-- is built on. A window owns its frame, registers with Sonata for its chrome, places its
-- content in the box the theme's insets leave, and lays itself out through the render
-- pipeline, either sized to its content or at a size the player dragged it to.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = trackStub("Database")
local savedTheme = "Default"
db.GetTheme = function() return savedTheme end
db.SetTheme = function(_, key) savedTheme = key end

trackStub("Fonts")

local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")

local render = addon:GetModule("Render")
local drawable = addon:GetModule("Drawable")
local sonata = addon:GetModule("Sonata")
local window = addon:GetModule("Window")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

local count = 0
local function name()
  count = count + 1
  return "BetterBagsSpecWindow" .. count
end

local function ctx()
  return context:New("spec")
end

-- content builds a drawable of a fixed natural size that records the constraints it got.
local function content(width, height)
  local c = drawable:Create({})
  c.frame = CreateFrame("Frame")
  c.given = {}
  c.natural = { width, height }
  function c:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
  function c:Render(parentResult)
    table.insert(self.given, parentResult)
    return { Width = (parentResult and parentResult.Width) or self.natural[1], Height = (parentResult and parentResult.Height) or self.natural[2] }
  end
  return c
end

local FADE = {
  Show = { { Type = "Alpha", From = 0, To = 1, Duration = 0.1 } },
  Hide = { { Type = "Alpha", From = 1, To = 0, Duration = 0.1 } },
}

local function themes()
  sonata.themes = {}
  sonata:RegisterTheme({
    Name = "Base",
    Hidden = true,
    Windows = { Bag = { Insets = { Left = 6, Right = 6, Top = 42, Bottom = 3 }, Animations = FADE } },
  })
  sonata:RegisterTheme({ Name = "Default" })
  sonata:RegisterTheme({ Name = "Tall", Windows = { Bag = { Insets = { Top = 60 } } } })
  sonata:RegisterTheme({
    Name = "Animated",
    Windows = { Bag = { Animations = {
      Show = { { Type = "Alpha", From = 0, To = 1, Duration = 0.2, Smoothing = "OUT" } },
      Hide = { { Type = "Scale", From = { 1, 1 }, To = { 0.9, 0.9 }, Duration = 0.1 }, { Type = "Translation", X = 0, Y = -10, Duration = 0.1 } },
    } } },
  })
  sonata:RegisterTheme({ Name = "Still", Windows = { Bag = { Animations = false } } })
  sonata:RegisterTheme({ Name = "PopIn", Windows = { Bag = { Animations = { Hide = false } } } })
end

describe("Window", function()
  local originalSend, originalAfter, originalSpecial, originalLibWindow
  local pending, registered, restored, saved

  before_each(function()
    render:Init()
    sonata:Init()
    themes()
    savedTheme = "Default"
    originalSend = events.SendMessage
    events.SendMessage = function() end
    pending = {}
    originalAfter = _G.C_Timer.After
    _G.C_Timer.After = function(_, fn) table.insert(pending, fn) end
    originalSpecial = _G.UISpecialFrames
    _G.UISpecialFrames = {}
    registered, restored, saved = {}, {}, {}
    originalLibWindow = {
      RegisterConfig = libWindow.RegisterConfig,
      RestorePosition = libWindow.RestorePosition,
      SavePosition = libWindow.SavePosition,
    }
    libWindow.RegisterConfig = function(frame, config) registered[frame] = config end
    libWindow.RestorePosition = function(frame) restored[frame] = true end
    libWindow.SavePosition = function(frame) saved[frame] = (saved[frame] or 0) + 1 end
  end)

  after_each(function()
    events.SendMessage = originalSend
    _G.C_Timer.After = originalAfter
    _G.UISpecialFrames = originalSpecial
    for k, v in pairs(originalLibWindow) do
      libWindow[k] = v
    end
  end)

  local function apply(key)
    sonata:ApplyTheme(ctx(), key or "Default")
  end

  local function advance()
    local due = pending
    pending = {}
    for _, fn in ipairs(due) do fn() end
  end

  describe("creation", function()
    it("builds a named frame that can take a backdrop, with a content frame", function()
      local n = name()
      local w = window:Create({ Name = n, Kind = "Bag", Title = "Backpack", Strata = "MEDIUM", Level = 500, Toplevel = true })
      assert.are.equal(_G[n], w.frame)
      assert.is_true(w.frame._backdropTemplate)
      assert.are.equal(UIParent, w.frame:GetParent())
      assert.are.equal("MEDIUM", w.frame:GetFrameStrata())
      assert.are.equal(500, w.frame:GetFrameLevel())
      assert.is_true(w.frame._toplevel)
      assert.is_true(w.frame._clamped)
      assert.are.equal(w.frame, w.content:GetParent())
      assert.are.equal("Backpack", w:GetTitle())
      assert.is_false(w.frame:IsShown())
    end)

    it("needs a kind, and a name only to close with Escape", function()
      assert.has_error(function() window:Create({ Name = name() }) end)
      assert.has_no.errors(function() window:Create({ Kind = "Dialog" }) end)
      assert.has_error(function() window:Create({ Kind = "Dialog", Escape = true }) end)
    end)

    it("registers with Sonata under its kind and is decorated once a theme applies", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      assert.is_not_nil(w.decoration)
      assert.are.equal(w.decoration, sonata:GetDecoration(w))
    end)

    it("closes with Escape when asked", function()
      local n = name()
      window:Create({ Name = n, Kind = "Bag", Escape = true })
      assert.are.equal(n, _G.UISpecialFrames[#_G.UISpecialFrames])
    end)

    it("registers and restores its saved position", function()
      local config = {}
      local w = window:Create({ Name = name(), Kind = "Bag", Position = config })
      assert.are.equal(config, registered[w.frame])
      assert.is_true(restored[w.frame])
    end)

    it("sits in the middle of the screen, or where its owner says, without a saved position", function()
      local w = window:Create({ Kind = "Dialog" })
      assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { w.frame:GetPoint(1) })
      local anchor = CreateFrame("Frame")
      w = window:Create({ Kind = "Dialog", Points = {
        { Point = "TOPLEFT", RelativeTo = anchor, RelativePoint = "TOPRIGHT", X = 4 },
        { Point = "BOTTOMLEFT", RelativeTo = anchor, RelativePoint = "BOTTOMRIGHT", Y = 2 },
      } })
      assert.are.same({ "TOPLEFT", anchor, "TOPRIGHT", 4, 0 }, { w.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, 2 }, { w.frame:GetPoint(2) })
    end)

    it("is a drawable prototype the profiler measures", function()
      local perf = addon:GetModule("Perf")
      local w = window:Create({ Name = name(), Kind = "Bag" })
      assert.is_nil(rawget(w, "Render"))
      local proto = getmetatable(w).__index
      local registeredName
      for _, entry in ipairs(perf.prototypes) do
        if entry.tbl == proto then registeredName = entry.name end
      end
      assert.are.equal("WindowFrame", registeredName)
      assert.is_function(w.GetRenderPlan)
    end)

    it("calls its owner on every show and hide of its frame, however it happened", function()
      local shown, hidden = 0, 0
      local w = window:Create({ Kind = "Dialog", OnShow = function(c) assert.is_not_nil(c) shown = shown + 1 end,
        OnHide = function(c) assert.is_not_nil(c) hidden = hidden + 1 end })
      w.frame:GetScript("OnShow")(w.frame)
      w.frame:GetScript("OnHide")(w.frame)
      assert.are.same({ 1, 1 }, { shown, hidden })
    end)
  end)

  describe("the content box", function()
    it("places the content inside the theme's insets", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      assert.are.same({ "TOPLEFT", w.frame, "TOPLEFT", 6, -42 }, { w.content:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", -6, 3 }, { w.content:GetPoint(2) })
    end)

    it("adds the space the window's own parts reserve, and keeps its own copy of it", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      local extra = { Top = 20, Bottom = 25 }
      w:SetExtraInsets(extra)
      extra.Top = 99
      assert.are.same({ Left = 6, Right = 6, Top = 62, Bottom = 28 }, w:GetContentInsets())
      local _, _, _, _, y = w.content:GetPoint(1)
      assert.are.equal(-62, y)
    end)

    it("moves the content and lays out again when the theme changes", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(100, 50), Fade = function() return false end })
      apply()
      w:Show(ctx())
      apply("Tall")
      local _, _, _, _, y = w.content:GetPoint(1)
      assert.are.equal(-60, y)
      advance()
      assert.are.equal(50 + 60 + 3, w.frame:GetHeight())
    end)

    it("tells its owner after every theme it was decorated with, once its content moved", function()
      local seen = {}
      local w
      w = window:Create({ Name = name(), Kind = "Bag", OnDecorated = function(c, decoration)
        assert.is_not_nil(c)
        table.insert(seen, { decoration, select(5, w.content:GetPoint(1)) })
      end })
      apply()
      apply("Tall")
      assert.are.equal(2, #seen)
      assert.are.equal(w.decoration, seen[1][1])
      assert.are.equal(-42, seen[1][2])
      assert.are.equal(-60, seen[2][2])
    end)

    it("hands out the theme's layout", function()
      sonata.themes.Base.Windows.Bag.Layout = { Search = { Top = 30 } }
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      assert.are.equal(30, w:GetLayout().Search.Top)
    end)

    it("hides and lets go of content it replaces", function()
      local first, second = content(1, 1), content(2, 2)
      local w = window:Create({ Name = name(), Kind = "Bag", Content = first })
      render:NewRenderChain(w, {})
      assert.are.equal(w, first.renderParent)
      w:SetContent(second)
      assert.is_false(first.frame:IsShown())
      assert.is_nil(first.renderParent)
      assert.are.equal(second, w:GetContent())
      assert.is_true(render:IsDirty(w))
    end)
  end)

  describe("title, close and opacity", function()
    it("retitles its decoration", function()
      sonata.themes.Base.Windows.Bag.Title = {}
      local w = window:Create({ Name = name(), Kind = "Bag", Title = "A" })
      apply()
      assert.are.equal("A", w.decoration:GetTitleText():GetText())
      w:SetTitle("B")
      assert.are.equal("B", w:GetTitle())
      assert.are.equal("B", w.decoration:GetTitleText():GetText())
    end)

    it("hides itself when its close button is clicked, or asks its owner", function()
      sonata.themes.Base.Windows.Bag.CloseButton = { Size = 12 }
      local w = window:Create({ Name = name(), Kind = "Bag", Fade = function() return false end })
      apply()
      w:Show(ctx())
      local close = w.decoration:GetCloseButton()
      close:GetScript("OnClick")(close, "LeftButton")
      assert.is_false(w.frame:IsShown())

      local asked
      local owned = window:Create({ Name = name(), Kind = "Bag", OnClose = function(c) asked = c end })
      apply()
      owned.frame:Show()
      close = owned.decoration:GetCloseButton()
      close:GetScript("OnClick")(close, "LeftButton")
      assert.is_not_nil(asked)
      assert.is_true(owned.frame:IsShown())
    end)

    it("hands its owner the mouse button that clicked close, for the clicks it asked for", function()
      sonata.themes.Base.Windows.Bag.CloseButton = { Size = 12 }
      local clicks = {}
      local w = window:Create({ Name = name(), Kind = "Bag", CloseClicks = { "LeftButtonUp", "RightButtonUp" },
        OnClose = function(_, button) table.insert(clicks, button) end })
      apply()
      assert.are.same({ "LeftButtonUp", "RightButtonUp" }, w.decoration:GetCloseButton()._registeredClicks)
      local close = w.decoration:GetCloseButton()
      close:GetScript("OnClick")(close, "RightButton")
      assert.are.same({ "RightButton" }, clicks)
      assert.are.same({ "LeftButtonUp" }, window:Create({ Name = name(), Kind = "Bag" }):GetCloseClicks())
    end)

    it("reads its opacity from its owner and fades its decoration with it", function()
      sonata.themes.Base.Windows.Bag.Background = { Color = { 0, 0, 0, 1 } }
      local opacity = 40
      local w = window:Create({ Name = name(), Kind = "Bag", Opacity = function() return opacity end })
      apply()
      assert.are.equal(0.4, w.decoration:GetTexture("Background"):GetAlpha())
      opacity = 90
      w:UpdateOpacity()
      assert.are.equal(0.9, w.decoration:GetTexture("Background"):GetAlpha())
    end)

    it("is fully opaque without an owner's opacity", function()
      assert.are.equal(100, window:Create({ Name = name(), Kind = "Bag" }):GetOpacity())
    end)
  end)

  describe("moving", function()
    it("moves when dragged and saves where it was dropped, telling its owner", function()
      local started, moved = 0, 0
      local w = window:Create({ Name = name(), Kind = "Bag", Position = {},
        OnMoveStart = function(c) assert.is_not_nil(c) started = started + 1 end,
        OnMoved = function(c) assert.is_not_nil(c) moved = moved + 1 end })
      assert.is_true(w.frame._movable)
      assert.are.same({ "LeftButton" }, w.frame._registeredDrags)
      w.frame:GetScript("OnDragStart")(w.frame, "LeftButton")
      assert.is_true(w.frame._moving)
      assert.are.equal(1, started)
      w.frame:GetScript("OnDragStop")(w.frame)
      assert.is_false(w.frame._moving)
      assert.are.equal(1, saved[w.frame])
      assert.are.equal(1, moved)
    end)

    it("moves when its owner says it can, and not when it says it cannot", function()
      local can = true
      local w = window:Create({ Name = name(), Kind = "Bag", CanMove = function(c) assert.is_not_nil(c) return can end })
      w.frame:GetScript("OnDragStart")(w.frame, "LeftButton")
      assert.is_true(w.frame._moving)
      w.frame:GetScript("OnDragStop")(w.frame)
      can = false
      w.frame:GetScript("OnDragStart")(w.frame, "LeftButton")
      assert.is_false(w.frame._moving)
    end)

    it("does not move at all when it is not movable", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Movable = false })
      assert.is_nil(w.frame:GetScript("OnDragStart"))
    end)
  end)

  describe("sizing to its content", function()
    it("gives the content its natural width and a height cap, and wraps it", function()
      local c = content(300, 200)
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c })
      apply()
      local result = render:NewRenderChain(w, {})
      local given = c.given[#c.given]
      assert.is_nil(given.Width)
      assert.are.equal(UIParent:GetHeight() * 0.9 - 42 - 3, given.MaxHeight)
      assert.are.equal(300 + 12, w.frame:GetWidth())
      assert.are.equal(200 + 45, w.frame:GetHeight())
      assert.are.equal(312, result.Width)
    end)

    it("caps the height at the screen measured in its own scale", function()
      local c = content(300, 200)
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c, Scale = function() return 2 end })
      apply()
      render:NewRenderChain(w, {})
      assert.are.equal(2, w.frame:GetScale())
      assert.are.equal(UIParent:GetHeight() * 0.9 / 2 - 45, c.given[#c.given].MaxHeight)
    end)

    it("applies a new scale and lays out again", function()
      local scale = 1
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(1, 1), Scale = function() return scale end })
      scale = 1.5
      w:UpdateScale()
      assert.are.equal(1.5, w.frame:GetScale())
      assert.is_true(render:IsDirty(w))
    end)

    it("never makes the content or the window smaller than their minimums", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(10, 10), MinWidth = 260, MinHeight = 100 })
      apply()
      render:NewRenderChain(w, {})
      assert.are.equal(260, w.frame:GetWidth())
      assert.are.equal(100, w.frame:GetHeight())
      local minContent = 300
      w = window:Create({ Name = name(), Kind = "Bag", Content = content(10, 10),
        MinContentWidth = function() return minContent end, MinContentHeight = 100 })
      apply()
      render:NewRenderChain(w, {})
      assert.are.equal(300 + 12, w.frame:GetWidth())
      assert.are.equal(100 + 45, w.frame:GetHeight())
    end)

    it("tells its owner the size it rendered at", function()
      local seen
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(100, 50),
        OnRendered = function(c, width, height) assert.is_not_nil(c) seen = { width, height } end })
      apply()
      render:NewRenderChain(w, { ctx = ctx() })
      assert.are.same({ 112, 95 }, seen)
    end)

    it("parents its content to the content frame", function()
      local c = content(1, 1)
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c })
      assert.are.equal(w.content, c.frame:GetParent())
      assert.are.equal(w.content, c.frame._allPoints)
      assert.are.equal(c, w:GetContent())
    end)

    it("renders without content at its current size", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      w.frame:SetSize(123, 45)
      local result = render:NewRenderChain(w, {})
      assert.are.same({ 123, 45 }, { result.Width, result.Height })
    end)

    it("errors when its content returns no result, in both modes", function()
      local c = drawable:Create({})
      c.frame = CreateFrame("Frame")
      function c:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function c:Render() return nil end
      local mode = "content"
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c, SizeMode = function() return mode end })
      assert.has_error(function() render:NewRenderChain(w, {}) end)
      mode = "window"
      assert.has_error(function() render:NewRenderChain(w, {}) end)
    end)
  end)

  describe("sizing by the player", function()
    local mode, saveSize, size

    local function resizable(c, opts, initialSize)
      mode = "window"
      saveSize = nil
      size = initialSize or { 640, 480 }
      local o = {
        Name = name(), Kind = "Bag", Content = c, MinWidth = 260, MinHeight = 100, Position = {},
        SizeMode = function() return mode end,
        Size = function() return size[1], size[2] end,
        OnResized = function(cx, width, height) assert.is_not_nil(cx) saveSize = { width, height } end,
      }
      for k, v in pairs(opts or {}) do o[k] = v end
      return window:Create(o)
    end

    it("takes its saved size and hands the content the box inside it", function()
      local c = content(300, 200)
      local w = resizable(c)
      apply()
      w:UpdateSizeMode()
      render:NewRenderChain(w, {})
      local given = c.given[#c.given]
      assert.are.equal(640 - 12, given.Width)
      assert.are.equal(480 - 45, given.Height)
      assert.are.equal(640, w.frame:GetWidth())
      assert.are.equal(480, w.frame:GetHeight())
      assert.is_true(w.frame._resizable)
      assert.are.equal(260, w.frame._resizeBounds.minWidth)
      assert.are.equal(100, w.frame._resizeBounds.minHeight)
    end)

    it("never lets the player size it smaller than its insets", function()
      local w = resizable(content(1, 1), { MinWidth = false, MinHeight = false })
      apply()
      w:UpdateSizeMode()
      assert.are.equal(13, w.frame._resizeBounds.minWidth)
      assert.are.equal(46, w.frame._resizeBounds.minHeight)
    end)

    it("clamps a saved size to its minimums", function()
      local w = resizable(content(1, 1))
      size = { 10, 10 }
      apply()
      w:UpdateSizeMode()
      assert.are.same({ 260, 100 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    end)

    it("keeps the size it has when nothing was saved", function()
      local w = resizable(content(1, 1), nil, {})
      w.frame:SetSize(500, 400)
      apply()
      w:UpdateSizeMode()
      assert.are.same({ 500, 400 }, { w.frame:GetWidth(), w.frame:GetHeight() })
      w = resizable(content(1, 1), nil, {})
      apply()
      w:UpdateSizeMode()
      assert.are.same({ 260, 100 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    end)

    it("lays out again when its mode changes", function()
      local c = content(300, 200)
      local w = resizable(c)
      apply()
      w:UpdateSizeMode()
      w:Show(ctx())
      advance()
      mode = "content"
      w:UpdateSizeMode()
      assert.is_true(render:IsDirty(w))
      advance()
      assert.are.equal(312, w.frame:GetWidth())
    end)

    it("keeps a fixed size the player cannot change when it is not resizable", function()
      local w = resizable(content(1, 1), { Resizable = false })
      apply()
      w:UpdateSizeMode()
      assert.is_false(w.frame._resizable)
      assert.is_true(w.resizeGrip == nil or not w.resizeGrip:IsShown())
      assert.are.same({ 640, 480 }, { w.frame:GetWidth(), w.frame:GetHeight() })
    end)

    it("shows a resize grip only while the player sizes it", function()
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      assert.is_true(w.resizeGrip:IsShown())
      mode = "content"
      w:UpdateSizeMode()
      assert.is_false(w.resizeGrip:IsShown())
      assert.is_false(w.frame._resizable)
    end)

    it("sizes from its corner with the left button, lays out as it changes size, and saves its size and position", function()
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      w:Show(ctx())
      advance()
      w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "RightButton")
      assert.is_nil(w.frame._sizing)
      w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "LeftButton")
      assert.are.equal("BOTTOMRIGHT", w.frame._sizing)
      w.frame:SetSize(700, 500)
      w.frame:GetScript("OnSizeChanged")(w.frame, 700, 500)
      assert.is_true(render:IsDirty(w))
      w.resizeGrip:GetScript("OnMouseUp")(w.resizeGrip, "LeftButton")
      assert.are.same({ 700, 500 }, saveSize)
      assert.are.equal(1, saved[w.frame])
    end)

    it("does not lay out again for size changes it made itself while sized to its content", function()
      local w = resizable(content(1, 1))
      mode = "content"
      apply()
      w:Show(ctx())
      advance()
      w.frame:GetScript("OnSizeChanged")(w.frame, 10, 10)
      assert.is_false(render:IsDirty(w))
    end)

    -- No window is ever off the screen: clamped with nothing allowed off it, never sized past
    -- it, and pulled back after every change that can push it off (window.md, "on the screen").
    describe("kept on the screen", function()
      local function clampCalls(w)
        local calls = {}
        local original = w.frame.SetClampedToScreen
        w.frame.SetClampedToScreen = function(f, on)
          table.insert(calls, on)
          return original(f, on)
        end
        return calls
      end

      it("is clamped to the screen with nothing allowed off it", function()
        local w = resizable(content(1, 1))
        assert.is_true(w.frame:IsClampedToScreen())
        assert.are.same({ 0, 0, 0, 0 }, w.frame._clampRectInsets)
      end)

      it("can never be sized past the screen, measured in its own scale", function()
        local w = resizable(content(1, 1))
        apply()
        w:UpdateSizeMode()
        assert.are.same({ 1920, 1200 }, { w.frame._resizeBounds.maxWidth, w.frame._resizeBounds.maxHeight })
        local scaled = resizable(content(1, 1), { Scale = function() return 2 end })
        apply()
        scaled:UpdateSizeMode()
        assert.are.same({ 960, 600 }, { scaled.frame._resizeBounds.maxWidth, scaled.frame._resizeBounds.maxHeight })
      end)

      it("cuts a saved size larger than the screen down to it", function()
        local w = resizable(content(1, 1), nil, { 3000, 2500 })
        apply()
        w:UpdateSizeMode()
        assert.are.same({ 1920, 1200 }, { w.frame:GetWidth(), w.frame:GetHeight() })
      end)

      it("fits itself to the screen again when its scale grows", function()
        local scale = 1
        local w = resizable(content(1, 1), { Scale = function() return scale end }, { 1500, 1000 })
        apply()
        w:UpdateSizeMode()
        scale = 2
        w:UpdateScale(true)
        assert.are.same({ 960, 600 }, { w.frame:GetWidth(), w.frame:GetHeight() })
        assert.are.same({ 960, 600 }, { w.frame._resizeBounds.maxWidth, w.frame._resizeBounds.maxHeight })
      end)

      it("pulls itself back on the screen after every render, once its owner has placed it", function()
        for _, m in ipairs({ "window", "content" }) do
          local order = {}
          local w = resizable(content(1, 1), { OnRendered = function() table.insert(order, "rendered") end })
          mode = m
          apply()
          w:UpdateSizeMode()
          local original = w.frame.SetClampedToScreen
          w.frame.SetClampedToScreen = function(f, on)
            table.insert(order, on)
            return original(f, on)
          end
          render:NewRenderChain(w, {})
          assert.are.same({ "rendered", false, true }, order, m)
          assert.is_true(w.frame:IsClampedToScreen(), m)
        end
      end)

      it("leaves the player's resize alone until they let go, then pulls it back on the screen", function()
        local w = resizable(content(1, 1))
        apply()
        w:UpdateSizeMode()
        w:Show(ctx())
        advance()
        local calls = clampCalls(w)
        w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "LeftButton")
        w.frame:SetSize(700, 500)
        w.frame:GetScript("OnSizeChanged")(w.frame, 700, 500)
        advance()
        assert.are.same({}, calls)
        w.resizeGrip:GetScript("OnMouseUp")(w.resizeGrip, "LeftButton")
        assert.are.same({ false, true }, calls)
      end)

      it("fits every window to the screen again when the UI scale or the display size changes", function()
        local current = addon:GetModule("Events")
        current:Init()
        window:Init()
        local w = resizable(content(1, 1), nil, { 1800, 1100 })
        apply()
        w:UpdateSizeMode()
        render:Init()
        local calls = clampCalls(w)
        UIParent:SetSize(1280, 720)
        for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
          current._eventMap[event].fn(event)
        end
        UIParent:SetSize(1920, 1200)
        assert.are.same({ 1280, 720 }, { w.frame:GetWidth(), w.frame:GetHeight() })
        assert.are.same({ 1280, 720 }, { w.frame._resizeBounds.maxWidth, w.frame._resizeBounds.maxHeight })
        assert.are.same({ false, true, false, true }, calls)
        assert.is_true(render:IsDirty(w))
      end)

      -- Diagnostics: while a profiler capture runs, each step of a resize or a move records the
      -- window's anchors and rect as Geometry's return value in the call trace.
      it("describes itself to a running profiler at each step of a resize and a move", function()
        local perf = addon:GetModule("Perf")
        local w = resizable(content(1, 1))
        apply()
        w:UpdateSizeMode()
        w:Show(ctx())
        advance()
        local steps = {}
        local geometry = w.Geometry
        w.Geometry = function(self, step)
          table.insert(steps, step)
          return geometry(self, step)
        end
        w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "LeftButton")
        w.resizeGrip:GetScript("OnMouseUp")(w.resizeGrip, "LeftButton")
        assert.are.same({}, steps)
        local wasActive = perf.active
        perf.active = true
        w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "LeftButton")
        w.frame:GetScript("OnSizeChanged")(w.frame, 700, 500)
        advance()
        w.resizeGrip:GetScript("OnMouseUp")(w.resizeGrip, "LeftButton")
        w.frame:GetScript("OnDragStart")(w.frame)
        w.frame:GetScript("OnDragStop")(w.frame)
        perf.active = wasActive
        assert.are.same({ "resize start", "resize started", "resizing", "rendered while resizing",
          "resize stop", "resize stopped", "on screen", "position saved",
          "move start", "move stopped", "on screen", "position saved" }, steps)
      end)

      it("describes its anchors, rect, scale, clamp and the cursor", function()
        local w = resizable(content(1, 1))
        apply()
        w:UpdateSizeMode()
        w.frame:ClearAllPoints()
        w.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
        _G._cursorX, _G._cursorY = 1500, 200
        local text = w:Geometry("spec")
        _G._cursorX, _G._cursorY = nil, nil
        assert.is_truthy(text:find("BOTTOMRIGHT>UIParent BOTTOMRIGHT -20.0,30.0", 1, true), text)
        assert.is_truthy(text:find("640.0x480.0", 1, true), text)
        assert.is_truthy(text:find("scale 1.00", 1, true), text)
        assert.is_truthy(text:find("clamped true", 1, true), text)
        assert.is_truthy(text:find("cursor 1500.0,200.0", 1, true), text)
      end)
    end)

    it("draws the grip the theme describes, above its close button", function()
      sonata.themes.Base.Windows.Bag.Resize = { Size = { Width = 24, Height = 20 }, Normal = { Texture = "grip.png" },
        Points = { { Point = "BOTTOMRIGHT", X = -2, Y = 2 } } }
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      assert.are.same({ 24, 20 }, { w.resizeGrip:GetWidth(), w.resizeGrip:GetHeight() })
      assert.are.equal("grip.png", w.resizeGrip:GetNormalTexture():GetTexture())
      assert.are.same({ "BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", -2, 2 }, { w.resizeGrip:GetPoint(1) })
      assert.is_true(w.resizeGrip:GetFrameLevel() > w.decoration:GetOverlayFrame():GetFrameLevel())
    end)

    it("shows the default grip only while the pointer is on it", function()
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      assert.are.equal(0, w.resizeGrip:GetAlpha())
      w.resizeGrip:GetScript("OnEnter")(w.resizeGrip)
      assert.are.equal(1, w.resizeGrip:GetAlpha())
      w.resizeGrip:GetScript("OnLeave")(w.resizeGrip)
      assert.are.equal(0, w.resizeGrip:GetAlpha())
    end)

    it("gives the grip nothing of the last theme's", function()
      sonata.themes.Base.Windows.Bag.Resize = { Normal = { Texture = "grip.png", TexCoords = { 0.1, 0.9, 0.1, 0.9 }, Alpha = 0.5 },
        ShowOnHover = false }
      sonata:RegisterTheme({ Name = "PlainGrip", Windows = { Bag = { Resize = false } } })
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      assert.are.equal(1, w.resizeGrip:GetAlpha())
      apply("PlainGrip")
      local normal = w.resizeGrip:GetNormalTexture()
      assert.are.equal("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down", normal:GetTexture())
      assert.are.same({ 0, 1, 0, 1 }, normal._texCoords)
      assert.are.equal(1, normal:GetAlpha())
      assert.are.equal(0, w.resizeGrip:GetAlpha())
    end)
  end)

  describe("rendering while hidden", function()
    it("does not render while hidden, and renders once, before its callback, when shown", function()
      local c = content(100, 50)
      local order = {}
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c, Fade = function() return false end })
      local originalRender = c.Render
      function c:Render(...)
        table.insert(order, "render")
        return originalRender(self, ...)
      end
      apply()
      advance()
      local before = #c.given
      w:Invalidate()
      advance()
      assert.are.equal(before, #c.given)
      assert.is_true(w.renderPending)

      local rendered = w:Show(ctx(), function() table.insert(order, "callback") end)

      assert.is_true(rendered)
      assert.are.same({ "render", "callback" }, order)
      assert.is_false(render:IsDirty(w))
      advance()
      assert.are.equal(before + 1, #c.given)
    end)

    it("renders on show what was invalidated earlier in the same frame", function()
      local c = content(100, 50)
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c, Fade = function() return false end })
      w:Invalidate()
      assert.is_true(w:Show(ctx()))
      assert.are.equal(1, #c.given)
      advance()
      assert.are.equal(1, #c.given)
    end)

    it("says it did not render when nothing waited", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(1, 1), Fade = function() return false end })
      assert.is_true(w:Show(ctx()))
      w:Hide(ctx())
      assert.is_false(w:Show(ctx()))
    end)
  end)

  describe("showing and hiding", function()
    local function fading(opts)
      local o = { Name = name(), Kind = "Bag" }
      for k, v in pairs(opts or {}) do o[k] = v end
      local w = window:Create(o)
      apply()
      return w
    end

    it("shows and hides at once without fading", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Fade = function() return false end })
      local shown, hidden = 0, 0
      w:Show(ctx(), function() shown = shown + 1 end)
      assert.is_true(w.frame:IsShown())
      assert.are.equal(1, shown)
      w:Hide(ctx(), function() hidden = hidden + 1 end)
      assert.is_false(w.frame:IsShown())
      assert.are.equal(1, hidden)
    end)

    it("fades with its theme's animations and calls back once done", function()
      local w = fading()
      local shown, hidden = 0, 0
      w:Show(ctx(), function() shown = shown + 1 end)
      assert.is_true(w.frame:IsShown())
      assert.are.equal(0, w.frame:GetAlpha())
      assert.are.equal(0, shown)
      w.showAnimation:_complete()
      assert.are.equal(1, w.frame:GetAlpha())
      assert.are.equal(1, shown)
      w:Hide(ctx(), function() hidden = hidden + 1 end)
      assert.is_true(w.frame:IsShown())
      w.hideAnimation:_complete()
      assert.is_false(w.frame:IsShown())
      assert.are.equal(1, w.frame:GetAlpha())
      assert.are.equal(1, hidden)
    end)

    it("shows and hides at once for a theme that turns animations off", function()
      local w = fading()
      apply("Still")
      assert.is_nil(w.showAnimation)
      local shown = 0
      w:Show(ctx(), function() shown = shown + 1 end)
      assert.is_true(w.frame:IsShown())
      assert.are.equal(1, w.frame:GetAlpha())
      assert.are.equal(1, shown)
    end)

    it("fades in but hides at once for a theme that turns only the hide off", function()
      local w = fading()
      apply("PopIn")
      assert.is_not_nil(w.showAnimation)
      assert.is_nil(w.hideAnimation)
      w:Show(ctx())
      w.showAnimation:_complete()
      w:Hide(ctx())
      assert.is_false(w.frame:IsShown())
    end)

    it("builds the theme's show and hide animations", function()
      local w = fading()
      apply("Animated")
      local show = w.showAnimation._animations
      assert.are.equal("Alpha", show[1]._type)
      assert.are.equal(0.2, show[1]._duration)
      assert.are.equal("OUT", show[1]._smoothing)
      local hide = w.hideAnimation._animations
      assert.are.equal("Scale", hide[1]._type)
      assert.are.same({ x = 0.9, y = 0.9 }, hide[1]._scaleTo)
      assert.are.equal("Translation", hide[2]._type)
      assert.are.same({ x = 0, y = -10 }, hide[2]._offset)
    end)

    it("keeps one pair of animations per theme", function()
      local w = fading()
      apply("Animated")
      local first = w.showAnimation
      apply()
      apply("Animated")
      assert.are.equal(first, w.showAnimation)
    end)

    it("finishes a fade in progress when the theme changes", function()
      local w = fading()
      local shown = 0
      w:Show(ctx(), function() shown = shown + 1 end)
      local old = w.showAnimation
      apply("Animated")
      assert.is_false(old:IsPlaying())
      assert.are.equal(1, shown)
      assert.are.equal(1, w.frame:GetAlpha())
    end)

    it("stops a fade-in it hides, at full alpha, without its callback", function()
      local w = fading()
      local shown, hidden = 0, 0
      w:Show(ctx(), function() shown = shown + 1 end)
      w:Hide(ctx(), function() hidden = hidden + 1 end)
      assert.is_false(w.showAnimation:IsPlaying())
      assert.is_true(w.hideAnimation:IsPlaying())
      w.hideAnimation:_complete()
      assert.are.equal(0, shown)
      assert.are.equal(1, hidden)
      assert.are.equal(1, w.frame:GetAlpha())
      w.frame:Show()
      assert.are.equal(1, w.frame:GetAlpha())
    end)

    it("stops a fade-out it shows, and fades back in", function()
      local w = fading()
      w:Show(ctx())
      w.showAnimation:_complete()
      local hidden = 0
      w:Hide(ctx(), function() hidden = hidden + 1 end)
      local shown = 0
      w:Show(ctx(), function() shown = shown + 1 end)
      assert.is_false(w.hideAnimation:IsPlaying())
      assert.is_true(w.showAnimation:IsPlaying())
      assert.are.equal(0, w.frame:GetAlpha())
      assert.is_true(w.frame:IsShown())
      w.showAnimation:_complete()
      assert.are.equal(0, hidden)
      assert.are.equal(1, shown)
    end)

    it("does nothing but call back when shown while shown", function()
      local w = fading()
      w:Show(ctx())
      w.showAnimation:_complete()
      local plays = w.showAnimation._plays
      local shown = 0
      w:Show(ctx(), function() shown = shown + 1 end)
      assert.are.equal(plays, w.showAnimation._plays)
      assert.are.equal(1, w.frame:GetAlpha())
      assert.are.equal(1, shown)
    end)

    it("calls both back when shown again while fading in", function()
      local w = fading()
      local calls = {}
      w:Show(ctx(), function() table.insert(calls, "first") end)
      w:Show(ctx(), function() table.insert(calls, "second") end)
      w.showAnimation:_complete()
      assert.are.same({ "first", "second" }, calls)
    end)

    it("calls back at once when hidden while hidden", function()
      local w = fading()
      local hidden = 0
      w:Hide(ctx(), function() hidden = hidden + 1 end)
      assert.are.equal(1, hidden)
      assert.is_false(w.hideAnimation:IsPlaying())
    end)

    it("shows again after Escape hid it in the middle of a fade-in", function()
      local w = fading()
      w:Show(ctx())
      w.frame:Hide()
      w:Show(ctx())
      assert.is_true(w.frame:IsShown())
      assert.is_true(w.showAnimation:IsPlaying())
      assert.are.equal(0, w.frame:GetAlpha())
    end)

    it("toggles, and shows again when toggled during a fade-out", function()
      local w = fading()
      w:Toggle(ctx())
      assert.is_true(w:IsShown())
      w.showAnimation:_complete()
      w:Toggle(ctx())
      assert.is_true(w.hideAnimation:IsPlaying())
      w:Toggle(ctx())
      assert.is_false(w.hideAnimation:IsPlaying())
      assert.is_true(w.showAnimation:IsPlaying())
    end)

    it("says it is closing during a fade-out", function()
      local w = fading()
      w:Show(ctx())
      w.showAnimation:_complete()
      assert.is_false(w:IsClosing())
      w:Hide(ctx())
      assert.is_true(w:IsClosing())
      w.hideAnimation:_complete()
      assert.is_false(w:IsClosing())
    end)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
