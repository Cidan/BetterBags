-- window_spec.lua -- The Window module (window/window.lua): the root every BetterBags window
-- is built on. A window owns its frame, registers with Sonata for its chrome, places its
-- content in the box the theme's insets leave, and lays itself out through the render
-- pipeline, either sized to its content or at a size the player dragged it to.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local db = StubBetterBagsModule("Database")
local savedTheme = "Default"
db.GetTheme = function() return savedTheme end
db.SetTheme = function(_, key) savedTheme = key end

StubBetterBagsModule("Fonts")

-- LibWindow-1.1 records what windows registered, restored and saved.
local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow._registered, libWindow._restored, libWindow._saved = {}, {}, {}
libWindow.RegisterConfig = function(frame, config) libWindow._registered[frame] = config end
libWindow.RestorePosition = function(frame) libWindow._restored[frame] = true end
libWindow.SavePosition = function(frame) libWindow._saved[frame] = true end

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

-- content builds a drawable of a fixed natural size that records the constraints it got.
local function content(width, height)
  local c = drawable:Create({})
  c.frame = CreateFrame("Frame")
  c.given = {}
  function c:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
  function c:Render(parentResult)
    table.insert(self.given, parentResult)
    return { Width = (parentResult and parentResult.Width) or width, Height = (parentResult and parentResult.Height) or height }
  end
  return c
end

local function themes(insetsTop)
  sonata.themes = {}
  sonata:RegisterTheme({
    Name = "Base",
    Hidden = true,
    Windows = { Bag = { Insets = { Left = 6, Right = 6, Top = insetsTop or 42, Bottom = 3 } } },
  })
  sonata:RegisterTheme({ Name = "Default" })
  sonata:RegisterTheme({ Name = "Tall", Windows = { Bag = { Insets = { Top = 60 } } } })
  sonata:RegisterTheme({
    Name = "Animated",
    Windows = { Bag = { Animations = {
      Show = { { Type = "Alpha", From = 0, To = 1, Duration = 0.2, Smoothing = "OUT" }, { Type = "Translation", X = 0, Y = 10, Duration = 0.2 } },
      Hide = { { Type = "Scale", From = { 1, 1 }, To = { 0.9, 0.9 }, Duration = 0.1 } },
    } } },
  })
end

describe("Window", function()
  local originalSend, originalAfter
  local pending

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
    _G.UISpecialFrames = {}
  end)

  after_each(function()
    events.SendMessage = originalSend
    _G.C_Timer.After = originalAfter
  end)

  local function apply(key)
    sonata:ApplyTheme(context:New("test"), key or "Default")
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

    it("requires a name and a kind", function()
      assert.has_error(function() window:Create({ Kind = "Bag" }) end)
      assert.has_error(function() window:Create({ Name = name() }) end)
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
      assert.are.equal(config, libWindow._registered[w.frame])
      assert.is_true(libWindow._restored[w.frame])
    end)

    it("is a drawable prototype the profiler measures", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      assert.is_nil(rawget(w, "Render"))
      assert.is_function(w.GetRenderPlan)
    end)
  end)

  describe("the content box", function()
    it("places the content inside the theme's insets", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      local point, relativeTo, _, x, y = w.content:GetPoint(1)
      assert.are.same({ "TOPLEFT", w.frame, 6, -42 }, { point, relativeTo, x, y })
      point, relativeTo, _, x, y = w.content:GetPoint(2)
      assert.are.same({ "BOTTOMRIGHT", w.frame, -6, 3 }, { point, relativeTo, x, y })
    end)

    it("adds the space the window's own parts reserve", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      w:SetExtraInsets({ Top = 20, Bottom = 25 })
      assert.are.same({ Left = 6, Right = 6, Top = 62, Bottom = 28 }, w:GetContentInsets())
      local _, _, _, _, y = w.content:GetPoint(1)
      assert.are.equal(-62, y)
    end)

    it("moves the content and lays out again when the theme changes", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(100, 50) })
      w.frame:Show()
      apply()
      advance()
      apply("Tall")
      local _, _, _, _, y = w.content:GetPoint(1)
      assert.are.equal(-60, y)
      advance()
      assert.are.equal(50 + 60 + 3, w.frame:GetHeight())
    end)

    it("hands out the theme's layout", function()
      sonata.themes.Base.Windows.Bag.Layout = { Search = { Top = 30 } }
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      assert.are.equal(30, w:GetLayout().Search.Top)
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
      w.frame:Show()
      local close = w.decoration:GetCloseButton()
      close:GetScript("OnClick")(close, "LeftButton")
      assert.is_false(w.frame:IsShown())

      local asked
      local owned = window:Create({ Name = name(), Kind = "Bag", OnClose = function(ctx) asked = ctx end })
      apply()
      owned.frame:Show()
      close = owned.decoration:GetCloseButton()
      close:GetScript("OnClick")(close, "LeftButton")
      assert.is_not_nil(asked)
      assert.is_true(owned.frame:IsShown())
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
    it("moves when dragged and saves where it was dropped", function()
      local moved = 0
      local w = window:Create({ Name = name(), Kind = "Bag", Position = {}, OnMoved = function() moved = moved + 1 end })
      assert.is_true(w.frame._movable)
      assert.are.same({ "LeftButton" }, w.frame._registeredDrags)
      w.frame:GetScript("OnDragStart")(w.frame)
      assert.is_true(w.frame._moving)
      w.frame:GetScript("OnDragStop")(w.frame)
      assert.is_false(w.frame._moving)
      assert.is_true(libWindow._saved[w.frame])
      assert.are.equal(1, moved)
    end)

    it("does not move while its owner says it cannot", function()
      local moved = 0
      local w = window:Create({ Name = name(), Kind = "Bag", CanMove = function() return false end, OnMoved = function() moved = moved + 1 end })
      w.frame:GetScript("OnDragStart")(w.frame)
      assert.is_nil(w.frame._moving)
      w.frame:GetScript("OnDragStop")(w.frame)
      assert.are.equal(0, moved)
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

    it("never shrinks below its minimum size", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Content = content(10, 10), MinWidth = 260, MinHeight = 100 })
      apply()
      render:NewRenderChain(w, {})
      assert.are.equal(260, w.frame:GetWidth())
      assert.are.equal(100, w.frame:GetHeight())
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
  end)

  describe("sizing by the player", function()
    local mode, saved

    local function resizable(c)
      mode = "window"
      saved = nil
      return window:Create({
        Name = name(), Kind = "Bag", Content = c, MinWidth = 260, MinHeight = 100,
        SizeMode = function() return mode end,
        Size = function() return 640, 480 end,
        OnResized = function(width, height) saved = { width, height } end,
      })
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
      assert.are.same({ minWidth = 260, minHeight = 100 }, { minWidth = w.frame._resizeBounds.minWidth, minHeight = w.frame._resizeBounds.minHeight })
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

    it("sizes from its corner, lays out as it changes size, and saves the size it was left at", function()
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      w.frame:Show()
      w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "LeftButton")
      assert.are.equal("BOTTOMRIGHT", w.frame._sizing)
      w.frame:SetSize(700, 500)
      w.frame:GetScript("OnSizeChanged")(w.frame, 700, 500)
      assert.are.equal(1, #pending)
      w.resizeGrip:GetScript("OnMouseUp")(w.resizeGrip, "LeftButton")
      assert.are.same({ 700, 500 }, saved)
    end)

    it("does not lay out again for size changes it made itself while sized to its content", function()
      local w = resizable(content(1, 1))
      mode = "content"
      apply()
      advance()
      w.frame:Show()
      w.frame:GetScript("OnSizeChanged")(w.frame, 10, 10)
      assert.are.equal(0, #pending)
    end)

    it("draws the grip the theme describes", function()
      sonata.themes.Base.Windows.Bag.Resize = { Size = 24, Normal = { Texture = "grip.png" } }
      local w = resizable(content(1, 1))
      apply()
      w:UpdateSizeMode()
      assert.are.equal(24, w.resizeGrip:GetWidth())
      assert.are.equal("grip.png", w.resizeGrip:GetNormalTexture():GetTexture())
    end)
  end)

  describe("rendering while hidden", function()
    it("does not render invalidated while hidden, and renders when shown", function()
      local c = content(100, 50)
      local w = window:Create({ Name = name(), Kind = "Bag", Content = c, Fade = function() return false end })
      apply()
      w.frame:Hide()
      advance()
      local before = #c.given
      w:Invalidate()
      advance()
      assert.are.equal(before, #c.given)
      assert.is_true(w.renderPending)
      w:Show()
      assert.are.equal(before + 1, #c.given)
    end)
  end)

  describe("showing and hiding", function()
    it("shows and hides at once without fading", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Fade = function() return false end })
      local shown, hidden = 0, 0
      w:Show(function() shown = shown + 1 end)
      assert.is_true(w.frame:IsShown())
      assert.are.equal(1, shown)
      w:Hide(function() hidden = hidden + 1 end)
      assert.is_false(w.frame:IsShown())
      assert.are.equal(1, hidden)
    end)

    it("fades in and out with the default fade when the theme has no animations", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      local shown = 0
      w:Show(function() shown = shown + 1 end)
      assert.is_true(w.frame:IsShown())
      assert.are.equal(0, w.frame:GetAlpha())
      assert.are.equal(0, shown)
      w.showAnimation:Finish()
      assert.are.equal(1, w.frame:GetAlpha())
      assert.are.equal(1, shown)
      w:Hide()
      assert.is_true(w.frame:IsShown())
      w.hideAnimation:Finish()
      assert.is_false(w.frame:IsShown())
    end)

    it("builds the theme's show and hide animations", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply("Animated")
      local show = w.showAnimation._animations
      assert.are.equal("Alpha", show[1]._type)
      assert.are.equal(0.2, show[1]._duration)
      assert.are.equal("OUT", show[1]._smoothing)
      assert.are.equal("Translation", show[2]._type)
      assert.are.same({ x = 0, y = 10 }, show[2]._offset)
      local hide = w.hideAnimation._animations
      assert.are.equal("Scale", hide[1]._type)
      assert.are.same({ x = 0.9, y = 0.9 }, hide[1]._scaleTo)
    end)

    it("keeps one pair of animations per theme", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply("Animated")
      local first = w.showAnimation
      apply()
      apply("Animated")
      assert.are.equal(first, w.showAnimation)
    end)

    it("stops showing when it is hidden mid-fade", function()
      local w = window:Create({ Name = name(), Kind = "Bag" })
      apply()
      w:Show()
      w:Hide()
      assert.is_false(w.showAnimation:IsPlaying())
      assert.is_true(w.hideAnimation:IsPlaying())
    end)

    it("toggles", function()
      local w = window:Create({ Name = name(), Kind = "Bag", Fade = function() return false end })
      w:Toggle()
      assert.is_true(w:IsShown())
      w:Toggle()
      assert.is_false(w:IsShown())
    end)
  end)
end)
