-- next_engine_spec.lua -- SonataNext (sonata/next.lua): BetterBags Next's themes. The same engine
-- as the classic bags' (inheritance, per-client overrides, variables; sonata/resolve.lua), its own
-- registry and saved choice, and themes that are data only: no functions anywhere.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = trackStub("Database")
local events = trackStub("Events")
local nextStyle = trackStub("NextStyle")
-- The panels an ornament may be on are named by their bag kinds (NextOrnaments, loaded by the checks).
local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = 2 }

local sonataNext = FreshNextThemes()
local context = addon:GetModule("Context")

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }

describe("SonataNext", function()
  local saved, sent, used, savedFlags, iconScale, scales, animation, keeps

  local function default()
    return {
      Name = "Default",
      DisplayName = "Default",
      Variables = { Accent = { 1, 0.8, 0.5, 1 } },
      Palette = { Gold = "$Accent", Body = { 0, 0, 0, 0.9 } },
      Fonts = { Title = { Size = 26, Color = "Gold" } },
      Tabs = { Fill = "Body", Corners = { 1, 2, 3 } },
      Header = { Ribbon = { Length = 300 } },
    }
  end

  before_each(function()
    sonataNext.themes = {}
    saved, sent, used, iconScale = "Default", {}, {}, 120
    animation, keeps = {}, {}
    db.GetNextAnimation = function(_, name) return animation[name] ~= false end
    db.GetNextTheme = function() return saved end
    db.SetNextTheme = function(_, key) saved = key end
    db.GetNextIconScale = function() return iconScale end
    events.SendMessage = function(_, _, name, key) table.insert(sent, { name, key }) end
    nextStyle.Use = function(_, theme, keepFonts)
      table.insert(used, theme)
      keeps[#used] = keepFonts == true
    end
    scales = {}
    nextStyle.SetIconScale = function(_, percent) table.insert(scales, { percent, #used }) end
    savedFlags = {}
    for _, flag in ipairs(FLAGS) do savedFlags[flag] = addon[flag] end
    addon.isRetail, addon.isForever = true, false
    _G._loadedAddOns = {}
    sonataNext:RegisterTheme(default())
    sonataNext:Init()
  end)

  after_each(function()
    for _, flag in ipairs(FLAGS) do addon[flag] = savedFlags[flag] end
    _G._loadedAddOns = nil
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
    FreshNextThemes()
  end)

  local function ctx() return context:New("spec") end

  -- The Size tab's Icon Scale (docs/next-appearance-size.md) is the player's, kept across themes: Next's
  -- style starts at the saved one, before the theme is handed to it.
  it("starts Next's style at the saved Icon Scale, then the saved theme", function()
    assert.are.same({ { 120, 0 } }, scales, "before any theme was handed over")
    assert.are.equal("Default", used[1].Name)
  end)

  -- Asked: "we need a way to disable sparkles etc on any theme, not just switching to a theme without them", on
  -- Appearance's Animation tab. Each switch turned off takes its parts out of whatever theme is in use, as a theme
  -- without them leaves them out (next-themes.md §20).
  describe("the player's Animation switches", function()
    local function full()
      local t = default()
      t.Header = { Ribbon = { Length = 300 }, Spark = { Size = 26 }, Cloud = { Join = 4 }, TitleGlow = { Alpha = 0.6 } }
      t.Sparkles = { Ribbon = { Rate = 8 } }
      t.Chain = { Braid = true, Color = "Gold" }
      t.Motion = { StopMotion = { FPS = 12 } }
      t.Panel = { Ornaments = {
        { Texture = "Roots", Point = "INNER", Width = 20, Motion = { Sway = 4, Period = 6 } },
        { Texture = "Leaf", Point = "TOPINNER", Width = 8, Height = 8 },
      },
        Glitch = { Open = { Time = 0.4 }, Close = { Time = 0.2 }, Bursts = { Every = 10, Time = 0.2 } },
        Rain = { { Where = "Feather", Font = "Title", HeadFont = "Title", Glyphs = "01", Speed = { 4, 8 }, Trail = { 4, 8 } } },
        Shatter = { Shards = { Size = 100 }, Frost = {}, Seams = {}, Open = { Time = 0.4 }, Close = { Time = 0.5 } },
        Paper = { Rate = 12 },
        Snow = { Flakes = { { Where = "Body", Count = 4 } } },
        Threads = { { Points = { { 0, 1 }, { 1, 2 } }, Sway = { Amplitude = 2, Period = 5 },
          Glint = { Every = 4, Time = 1 }, Draw = 0.5 } },
        Smoke = { Puffs = { Size = { 80, 120 } }, Open = { Rise = 0.3 } },
        Bats = { Frames = 4, Close = { Shudder = 0.1 }, Flutter = { Every = { 5, 9 } } },
        Beam = { Sparkles = { Density = 2 }, Open = { Reveal = { 0.2, 0.6 } }, Close = { Fade = { 0.2, 0.5 } } },
      }
      return t
    end

    -- What each switch takes out, read from a resolved theme.
    local PARTS = {
      sparkles = function(t) return t.Sparkles end,
      shimmer = function(t) return t.Header.Spark end,
      titleCloud = function(t) return t.Header.Cloud end,
      ribbon = function(t) return t.Header.Ribbon end,
      braid = function(t) return t.Chain.Braid or nil end,
      ornaments = function(t) return t.Panel.Ornaments[1].Motion end,
      -- The Glitch theme's (next-themes.md §21): glitching in, out and now and then; the data rain.
      glitch = function(t) return t.Panel.Glitch end,
      rain = function(t) return t.Panel.Rain end,
      -- The Frost theme's (next-themes.md §22): freezing together and shattering; the snow.
      shatter = function(t) return t.Panel.Shatter end,
      snow = function(t) return t.Panel.Snow end,
      -- The Halloween theme's (next-themes.md §23): coming in out of smoke; breaking up into bats, and the bats
      -- fluttering out of the header.
      paper = function(t) return t.Panel.Paper end,
      stopMotion = function(t) return t.Motion.StopMotion end,
      smoke = function(t) return t.Panel.Smoke end,
      bats = function(t) return t.Panel.Bats end,
      -- The Make It So theme's (next-themes.md §24): beaming in and out.
      beam = function(t) return t.Panel.Beam end,
    }

    before_each(function()
      sonataNext.themes = {}
      sonataNext:RegisterTheme(full())
    end)

    it("takes each part a switch turns off out of the theme in use, and leaves the rest as the theme has it", function()
      for name in pairs(PARTS) do
        animation = { [name] = false }
        sonataNext:Init()
        local theme = used[#used]
        for other, part in pairs(PARTS) do
          if other == name then
            assert.is_nil(part(theme), name .. " off takes it out")
          else
            assert.is_not_nil(part(theme), name .. " off leaves " .. other)
          end
        end
        assert.are.equal(theme, sonataNext:GetCurrentTheme())
        assert.are.equal(0.6, theme.Header.TitleGlow.Alpha, "the title's glow is no animation")
        assert.are.equal("Leaf", theme.Panel.Ornaments[2].Texture)
        assert.are.equal("Roots", theme.Panel.Ornaments[1].Texture, "a still ornament keeps its art")
      end
    end)

    -- A thread of light's sway and glint are a theme's moving ornaments: Moving Ornaments off holds it still, its art and
    -- its draw-in as the panel opens kept.
    it("takes a thread's sway and glint out with Moving Ornaments, keeping the thread", function()
      animation = { ornaments = false }
      sonataNext:Init()
      local thread = used[#used].Panel.Threads[1]
      assert.is_nil(thread.Sway)
      assert.is_nil(thread.Glint)
      assert.are.equal(0.5, thread.Draw)
      assert.are.equal(2, #thread.Points)
    end)

    -- A glint that flashes now and then (the Make It So theme's comm badge) is light, not art at rest: held still it would
    -- shine for good, so Moving Ornaments off takes the piece out; a piece that only moves stays, still.
    it("takes a piece that only flashes out with Moving Ornaments", function()
      local t = full()
      table.insert(t.Panel.Ornaments, 1, { Texture = "Glint", Point = "TOPOUTER", Width = 8, Height = 8,
        Motion = { Flash = { Every = { 4, 8 }, Time = 0.3 } } })
      sonataNext.themes = {}
      sonataNext:RegisterTheme(t)
      animation = { ornaments = false }
      sonataNext:Init()
      local pieces = used[#used].Panel.Ornaments
      assert.are.equal(2, #pieces)
      assert.are.equal("Roots", pieces[1].Texture)
      assert.is_nil(pieces[1].Motion)
      assert.are.equal("Leaf", pieces[2].Texture)
    end)

    -- Glitch Effects off is for players flicker is hard on: an ornament's glitch (its blinking twitch) goes with it, its
    -- other motion left to Moving Ornaments. Found by the adversarial review.
    it("takes an ornament's glitch out with Glitch Effects, leaving its other motion", function()
      local t = full()
      t.Panel.Ornaments[1].Motion.Glitch = { Every = 3, Blink = 0.2 }
      sonataNext.themes = {}
      sonataNext:RegisterTheme(t)
      animation = { glitch = false }
      sonataNext:Init()
      local motion = used[#used].Panel.Ornaments[1].Motion
      assert.is_nil(motion.Glitch)
      assert.are.equal(4, motion.Sway)
    end)

    it("takes nothing out while every switch is on", function()
      sonataNext:Init()
      for name, part in pairs(PARTS) do
        assert.is_not_nil(part(used[#used]), name)
      end
    end)

    it("lays them over every theme applied, previews included, saving nothing more", function()
      sonataNext:RegisterTheme({ Name = "Ember", Palette = { Gold = { 1, 0.5, 0, 1 } } })
      animation = { sparkles = false, braid = false }
      sonataNext:ApplyTheme(ctx(), "Ember", false)
      assert.is_nil(used[#used].Sparkles)
      assert.is_false(used[#used].Chain.Braid)
      assert.are.equal("Default", saved, "a preview")
      sonataNext:ApplyTheme(ctx(), "Ember")
      assert.is_nil(used[#used].Sparkles)
      assert.are.equal("Ember", saved)
    end)

    it("keeps a theme as it is written for its authors (Resolve, Check)", function()
      animation = { sparkles = false, shimmer = false, titleCloud = false, ribbon = false, braid = false, ornaments = false,
        glitch = false, rain = false }
      sonataNext:Init()
      local raw = sonataNext:Resolve("Default")
      for name, part in pairs(PARTS) do
        assert.is_not_nil(part(raw), name)
      end
    end)

    it("lays the switches over the current theme again, keeping its font objects and restyling every widget", function()
      sonataNext:Init()
      local restyled = 0
      local widget = { ApplyStyle = function() restyled = restyled + 1 end }
      sonataNext:RegisterWidget(widget)
      local before = #used
      animation = { shimmer = false }
      assert.is_true(sonataNext:ApplyAnimation(ctx()))
      assert.are.equal(before + 1, #used)
      assert.is_nil(used[#used].Header.Spark)
      assert.is_not_nil(used[#used].Sparkles)
      assert.is_true(keeps[#used], "no new font objects: the switches touch no font, and font objects are never freed")
      assert.is_false(keeps[before], "a theme applied makes new ones")
      assert.are.equal(used[#used], sonataNext:GetCurrentTheme())
      assert.are.equal(1, restyled)
      assert.are.same({}, sent, "no theme changed")
      assert.are.equal("Default", sonataNext:GetCurrentThemeKey())
    end)

    it("does nothing before Next starts", function()
      sonataNext.started = false
      assert.is_false(sonataNext:ApplyAnimation(ctx()))
    end)

    it("lays them over the theme it hands out before any theme is in use too", function()
      sonataNext.resolved, sonataNext.current = nil, nil
      animation = { sparkles = false }
      local theme = sonataNext:GetCurrentTheme()
      assert.is_nil(theme.Sparkles)
      assert.is_not_nil(theme.Header.Spark)
    end)

    -- Each switch sends next/AnimationChanged (the settings catalog); SonataNext follows it, registered once.
    it("follows next/AnimationChanged, registered once however often it starts watching", function()
      local handlers = {}
      local savedRegister = events.RegisterMessage
      events.RegisterMessage = function(_, name, fn) table.insert(handlers, { name, fn }) end
      sonataNext.watchingAnimation = nil
      sonataNext:WatchAnimation()
      sonataNext:WatchAnimation()
      events.RegisterMessage = savedRegister
      assert.are.equal(1, #handlers)
      assert.are.equal("next/AnimationChanged", handlers[1][1])
      sonataNext:Init()
      animation = { titleCloud = false }
      handlers[1][2](ctx())
      assert.is_nil(used[#used].Header.Cloud)
    end)
  end)

  describe("registering", function()
    it("registers a theme by its name, once", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      assert.is_not_nil(sonataNext:GetTheme("Ember"))
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "Ember" }) end)
      assert.has_error(function() sonataNext:RegisterTheme({}) end)
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "" }) end)
    end)

    -- Asked: "apply with a declarative spec, no functions!"
    it("takes data only: a function anywhere is refused, its path named", function()
      local ok, err = pcall(function()
        sonataNext:RegisterTheme({ Name = "Bad", Fonts = { Title = { Size = function() return 12 end } } })
      end)
      assert.is_false(ok)
      assert.is_truthy(tostring(err):find("Bad.Fonts.Title.Size", 1, true), tostring(err))
      assert.is_nil(sonataNext:GetTheme("Bad"))
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "Avail", Available = function() return true end }) end)
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "Var", Variables = { X = function() return 1 end } }) end)
      assert.has_error(function()
        sonataNext:RegisterTheme({ Name = "Listy", Palette = { Colors = { { 1, 1, 1 }, print } } })
      end)
    end)

    it("refuses objects (tables with a metatable, frames) and userdata", function()
      assert.has_error(function()
        sonataNext:RegisterTheme({ Name = "Obj", Panel = setmetatable({}, {}) })
      end)
      assert.has_error(function()
        sonataNext:RegisterTheme({ Name = "Frame", Panel = { Parent = CreateFrame("Frame") } })
      end)
    end)

    it("refuses overrides for a client that does not exist", function()
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "Odd", Clients = { Moon = {} } }) end)
      sonataNext:RegisterTheme({ Name = "Fine", Clients = { Classic = { Header = { Ribbon = false } } } })
    end)

    it("takes Requires as a list of addon names, and nothing else", function()
      sonataNext:RegisterTheme({ Name = "Elvish", Requires = { "ElvUI" } })
      for _, bad in ipairs({ { Name = "R1", Requires = "ElvUI" }, { Name = "R2", Requires = { 3 } } }) do
        local ok, err = pcall(function() sonataNext:RegisterTheme(bad) end)
        assert.is_false(ok)
        assert.is_truthy(tostring(err):find("Requires is a list of addon names", 1, true), tostring(err))
      end
    end)
  end)

  describe("availability and listing", function()
    it("is available only while every addon it requires is loaded", function()
      sonataNext:RegisterTheme({ Name = "Elvish", Requires = { "ElvUI", "ElvUI_Libraries" } })
      assert.is_false(sonataNext:IsAvailable("Elvish"))
      _G._loadedAddOns.ElvUI = true
      assert.is_false(sonataNext:IsAvailable("Elvish"))
      _G._loadedAddOns.ElvUI_Libraries = true
      assert.is_true(sonataNext:IsAvailable("Elvish"))
      assert.is_false(sonataNext:IsAvailable("Nope"))
    end)

    it("lists every theme not hidden, and the ones a player can pick", function()
      sonataNext:RegisterTheme({ Name = "Elvish", Requires = { "ElvUI" } })
      sonataNext:RegisterTheme({ Name = "Secret", Hidden = true })
      local all, pickable = {}, {}
      for key in pairs(sonataNext:GetThemes()) do table.insert(all, key) end
      for key in pairs(sonataNext:GetAllThemes()) do table.insert(pickable, key) end
      table.sort(all)
      table.sort(pickable)
      assert.are.same({ "Default", "Elvish" }, all)
      assert.are.same({ "Default" }, pickable)
    end)
  end)

  describe("resolving", function()
    it("inherits everything from Default, its variables filled in", function()
      sonataNext:RegisterTheme({ Name = "Ember", Palette = { Body = { 0.1, 0, 0, 1 } } })
      local theme = sonataNext:Resolve("Ember")
      assert.are.same({ 0.1, 0, 0, 1 }, theme.Palette.Body)
      assert.are.same({ 1, 0.8, 0.5, 1 }, theme.Palette.Gold)
      assert.are.equal(26, theme.Fonts.Title.Size)
      assert.are.equal("Ember", theme.Name)
      assert.are.equal("Ember", theme.DisplayName)
    end)

    it("follows its parent, replaces lists, and turns off what it sets false", function()
      sonataNext:RegisterTheme({ Name = "Warm", Tabs = { Corners = { 9 } } })
      sonataNext:RegisterTheme({ Name = "Warmer", Parent = "Warm", Header = { Ribbon = false } })
      local theme = sonataNext:Resolve("Warmer")
      assert.are.same({ 9 }, theme.Tabs.Corners)
      assert.is_nil(theme.Header.Ribbon)
      assert.are.equal("Body", theme.Tabs.Fill)
    end)

    it("applies its client overrides on this client", function()
      sonataNext:RegisterTheme({ Name = "Era", Clients = { Classic = { Fonts = { Title = { Size = 20 } } } } })
      assert.are.equal(26, sonataNext:Resolve("Era").Fonts.Title.Size)
      addon.isRetail, addon.isClassic = false, true
      assert.are.equal(20, sonataNext:Resolve("Era").Fonts.Title.Size)
    end)

    it("leaves the registered tables untouched", function()
      local raw = { Name = "Ember", Palette = { Body = "$Accent" } }
      sonataNext:RegisterTheme(raw)
      sonataNext:Resolve("Ember")
      assert.are.equal("$Accent", raw.Palette.Body)
    end)
  end)

  describe("applying", function()
    it("hands the saved theme to Next's style when it starts, without saving or sending anything", function()
      sonataNext:RegisterTheme({ Name = "Ember", Palette = { Body = { 0.1, 0, 0, 1 } } })
      saved = "Ember"
      used = {}
      sonataNext:Init()
      assert.are.equal(1, #used)
      assert.are.equal("Ember", used[1].Name)
      assert.are.equal("Ember", sonataNext:GetCurrentThemeKey())
      assert.are.same({}, sent)
    end)

    it("uses Default while the saved theme is missing or unavailable, keeping the saved choice", function()
      sonataNext:RegisterTheme({ Name = "Elvish", Requires = { "ElvUI" } })
      saved = "Elvish"
      used = {}
      sonataNext:Init()
      assert.are.equal("Default", used[1].Name)
      assert.are.equal("Elvish", saved)
      assert.are.equal("Default", sonataNext:GetSavedThemeKey())
      saved = "Gone"
      sonataNext:Init()
      assert.are.equal("Default", sonataNext:GetCurrentThemeKey())
    end)

    it("applies a theme: saved, to Next's style, to every widget, then says so", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      local styled = {}
      local a = { ApplyStyle = function(self, c) assert.is_not_nil(c) table.insert(styled, self) end }
      local b = { ApplyStyle = function(self) table.insert(styled, self) end }
      sonataNext:RegisterWidget(a)
      sonataNext:RegisterWidget(b)
      local generation = sonataNext:GetGeneration()
      used = {}
      sonataNext:ApplyTheme(ctx(), "Ember")
      assert.are.equal("Ember", saved)
      assert.are.equal("Ember", used[1].Name)
      assert.are.equal(2, #styled)
      assert.are.equal(generation + 1, sonataNext:GetGeneration())
      assert.are.same({ { "sonata/NextThemeChanged", "Ember" } }, sent)
      assert.are.equal("Ember", sonataNext:GetCurrentTheme().Name)
    end)

    it("does not save a preview, and puts the saved theme back", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      sonataNext:ApplyTheme(ctx(), "Ember", false)
      assert.are.equal("Default", saved)
      assert.are.equal("Ember", sonataNext:GetCurrentThemeKey())
      sonataNext:RestoreSavedTheme(ctx())
      assert.are.equal("Default", sonataNext:GetCurrentThemeKey())
    end)

    it("refuses an unknown, hidden or unavailable theme, changing nothing", function()
      sonataNext:RegisterTheme({ Name = "Secret", Hidden = true })
      sonataNext:RegisterTheme({ Name = "Elvish", Requires = { "ElvUI" } })
      used = {}
      for _, key in ipairs({ "Nope", "Secret", "Elvish" }) do
        assert.has_error(function() sonataNext:ApplyTheme(ctx(), key) end)
      end
      assert.are.same({}, used)
      assert.are.equal("Default", saved)
      assert.are.same({}, sent)
    end)

    -- A window drawn at a new scale (the settings window, docs/next-pixel-perfect.md): every widget laid out
    -- again for the new pixel grid, with the theme in effect; nothing saved, nothing announced.
    it("restyles every widget with the theme in effect, saving and announcing nothing", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      sonataNext:ApplyTheme(ctx(), "Ember")
      local styled, errors = {}, {}
      sonataNext:RegisterWidget({ ApplyStyle = function(_, c) assert.is_not_nil(c) table.insert(styled, 1) end })
      sonataNext:RegisterWidget({ ApplyStyle = function() error("broken widget") end })
      sonataNext:RegisterWidget({ ApplyStyle = function() table.insert(styled, 2) end })
      local generation = sonataNext:GetGeneration()
      sent, used, saved = {}, {}, "Default"
      local original = _G.geterrorhandler
      _G.geterrorhandler = function() return function(e) table.insert(errors, e) end end
      sonataNext:RestyleWidgets(ctx())
      _G.geterrorhandler = original
      assert.are.equal(2, #styled)
      assert.are.equal(1, #errors)
      assert.are.equal(generation, sonataNext:GetGeneration())
      assert.are.same({}, sent)
      assert.are.same({}, used)
      assert.are.equal("Default", saved)
    end)

    it("styles every widget even when one fails, reporting the failure", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      local styled, errors = 0, {}
      sonataNext:RegisterWidget({ ApplyStyle = function() error("broken widget") end })
      sonataNext:RegisterWidget({ ApplyStyle = function() styled = styled + 1 end })
      local original = _G.geterrorhandler
      _G.geterrorhandler = function() return function(e) table.insert(errors, e) end end
      sonataNext:ApplyTheme(ctx(), "Ember")
      _G.geterrorhandler = original
      assert.are.equal(1, styled)
      assert.are.equal(1, #errors)
      assert.is_truthy(tostring(errors[1]):find("broken widget", 1, true))
    end)

    -- A widget restyling can make another go away (a panel releasing a part): one gone before its turn
    -- is not styled.
    it("skips a widget unregistered while another restyles", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      local styled, widgets = 0, {}
      for i = 1, 5 do
        widgets[i] = { ApplyStyle = function()
          styled = styled + 1
          for _, other in ipairs(widgets) do sonataNext:UnregisterWidget(other) end
        end }
        sonataNext:RegisterWidget(widgets[i])
      end
      sonataNext:ApplyTheme(ctx(), "Ember")
      assert.are.equal(1, styled)
    end)

    it("restores nothing while the saved theme is the one in use", function()
      sent = {}
      local generation = sonataNext:GetGeneration()
      sonataNext:RestoreSavedTheme(ctx())
      assert.are.equal(generation, sonataNext:GetGeneration())
      assert.are.same({}, sent)
    end)

    it("forgets a widget unregistered", function()
      sonataNext:RegisterTheme({ Name = "Ember" })
      local styled = 0
      local w = { ApplyStyle = function() styled = styled + 1 end }
      sonataNext:RegisterWidget(w)
      sonataNext:UnregisterWidget(w)
      sonataNext:ApplyTheme(ctx(), "Ember")
      assert.are.equal(0, styled)
    end)

    -- Another addon's Next theme registers when that addon loads, after BetterBags started.
    it("applies the saved theme, unsaved, once it registers late", function()
      saved = "Late"
      sonataNext:Init()
      used = {}
      sonataNext:RegisterTheme({ Name = "Late", Palette = { Body = { 1, 0, 0, 1 } } })
      assert.are.equal("Late", sonataNext:GetCurrentThemeKey())
      assert.are.equal("Late", used[1].Name)
      assert.are.equal("Late", saved)
    end)
  end)

  -- Item buttons are styled by Sonata's ItemButton element (the bags' theme); while Next is the design
  -- in use, a Next theme's own ItemButton style replaces it.
  describe("item buttons", function()
    local overrides, restyled, originals

    before_each(function()
      LoadBetterBagsModule("sonata/engine.lua")
      local sonata = addon:GetModule("Sonata")
      local itemFrame = trackStub("ItemFrame")
      originals = { sonata.SetElementStyleOverride, itemFrame.RestyleButtons }
      overrides, restyled = {}, 0
      sonata.SetElementStyleOverride = function(_, kind, style) table.insert(overrides, { kind, style }) end
      itemFrame.RestyleButtons = function() restyled = restyled + 1 end
      sonataNext:RegisterTheme({ Name = "Glassy", ItemButton = { Backdrop = { Color = { 0, 0, 0, 0.5 } } } })
    end)

    after_each(function()
      addon:GetModule("Sonata").SetElementStyleOverride = originals[1]
      addon:GetModule("ItemFrame").RestyleButtons = originals[2]
    end)

    it("styles them with the theme's ItemButton while Next is in use, and the bags' theme otherwise", function()
      sonataNext:ApplyTheme(ctx(), "Glassy", false)
      assert.are.same({}, overrides, "not while the classic bags are in use")
      sonataNext:SetActive(true)
      assert.are.equal("ItemButton", overrides[1][1])
      assert.are.same({ Backdrop = { Color = { 0, 0, 0, 0.5 } } }, overrides[1][2])
      assert.are.equal(1, restyled, "every button draws in full again")
      sonataNext:SetActive(false)
      assert.are.same({ "ItemButton", nil }, overrides[2])
      assert.are.equal(2, restyled)
    end)

    -- BetterBags Next draws its item buttons on whole screen pixels (docs/next-pixel-perfect.md): while it is
    -- in use Sonata's styler rounds with NextPixel, and the template parts Next placed go back before the
    -- classic bags take the buttons over.
    it("rounds item buttons to whole pixels while Next is in use, putting them back for the classic bags", function()
      local elements = trackStub("SonataElements")
      local fit = trackStub("NextItemFit")
      local pixel = addon:GetModule("NextPixel")
      local calls = {}
      local savedSnap, savedRestore = elements.SetItemButtonSnap, fit.RestoreAll
      elements.SetItemButtonSnap = function(_, snap) table.insert(calls, { "snap", snap }) end
      fit.RestoreAll = function() table.insert(calls, { "restore" }) end
      sonataNext:SetActive(true)
      local snap = calls[1][2]
      assert.are.equal("snap", calls[1][1])
      local region = CreateFrame("Frame", nil, UIParent)
      assert.are.equal(pixel:Snap(region, 2.4), snap.Offset(region, 2.4))
      assert.are.equal(pixel:Length(region, 0.2), snap.Length(region, 0.2))
      assert.are.equal(pixel:Unit(region), snap.Unit(region))
      local count = region:CreateFontString()
      assert.are.equal(pixel:TextOffset(count), snap.Text(count), "a count a quarter pixel right and up")
      assert.is_true(snap.Text(count) > 0)
      assert.are.equal(0, snap.Text(region), "anything else on whole pixels")
      sonataNext:SetActive(false)
      -- The stubs stay for the spec's other tests, doing nothing.
      elements.SetItemButtonSnap = savedSnap or function() end
      fit.RestoreAll = savedRestore or function() end
      assert.are.same({ { "restore" }, { "snap", nil } }, { calls[2], calls[3] }, "put back, then the rounding off")
    end)

    it("follows the theme applied while Next is in use, back to the bags' theme with one without", function()
      sonataNext:SetActive(true)
      assert.are.same({}, overrides, "Default has none: nothing to change")
      sonataNext:ApplyTheme(ctx(), "Glassy", false)
      assert.is_not_nil(overrides[1][2])
      sonataNext:ApplyTheme(ctx(), "Default", false)
      assert.is_nil(overrides[2][2])
    end)
  end)

  -- Check finds what a theme names but no theme defines: a palette color, a text role, a texture,
  -- an ease. Every shipped theme is checked (next_themes_spec.lua).
  describe("checking a theme", function()
    before_each(function()
      -- The eases a theme may name are NextTween's.
      if addon:GetModule("NextTween", true) == nil then
        ResetModuleStub("NextTween", "next/tween.lua")
        LoadBetterBagsModule("next/tween.lua")
      end
      -- The points, sizes and motions an ornament may name are NextOrnaments'.
      if addon:GetModule("NextOrnaments", true) == nil then
        ResetModuleStub("NextOrnaments", "next/ornaments.lua")
        LoadBetterBagsModule("next/ornaments.lua")
      end
      sonataNext.themes = {}
      FreshNextThemes()
      sonataNext = addon:GetModule("SonataNext")
      sonataNext:Init()
    end)

    it("finds nothing wrong with Default", function()
      assert.are.same({}, sonataNext:Check("Default"))
    end)

    -- Reported in game on the Papercraft theme: its caps took their Size from the fill, which reads each cap's own, so they
    -- had no width, and a texture with none draws at its file's: a sliver of art stretched 128 units across, over the
    -- control and past it.
    it("names a fill's cap drawn from a file with no length of its own, and an atlas's, which has one, not at all", function()
      sonataNext:RegisterTheme({ Name = "NoCaps",
        Textures = { Art = "a.png" },
        Controls = {
          Input = { Fill = { Pieces = "Horizontal", Size = 12, Color = "White",
            Begin = { Texture = "Art" }, Middle = { Texture = "Art" }, End = { Texture = "Art", Size = 12 } } },
          Dropdown = { Fill = { Pieces = "Vertical", Texture = "Art", Color = "White", Begin = { Size = 4 } } },
          Slider = { Track = { Pieces = "Horizontal", Thickness = "Atlas", Color = "White",
            Begin = { Atlas = "cap" }, Middle = { Atlas = "middle" }, End = { Atlas = "cap" } } },
          Button = { Plain = { Fill = { Pieces = "Horizontal", Atlas = "cap", Color = "White" } } },
        },
      })
      local problems = sonataNext:Check("NoCaps")
      table.sort(problems)
      assert.are.same({
        "Controls.Dropdown.Fill.End.Size: a cap drawn from a file needs its length",
        "Controls.Input.Fill.Begin.Size: a cap drawn from a file needs its length",
      }, problems)
    end)

    it("names every color, role, texture and ease it cannot find, by where it is", function()
      sonataNext:RegisterTheme({ Name = "Broken",
        Panel = { Fill = { Color = "Nope" }, DropGlow = { Color = { 1, 0, 0, 1 } } },
        Header = { Buttons = { ArtColor = "Pale" }, Cloud = { Texture = "NoArt" },
          Spark = { Texture = "Interface\\Art\\Spark" } },
        Sections = { TitleFont = "Missing" },

        Sparkles = { Colors = { "Gold", "Ghost" } },
        Motion = { Ease = { Open = "wobbly" } },
        Fonts = { Title = { Color = "AlsoNope" } },
        Dock = { DestroyColor = "Blood", BuyColor = "Moss" },
        Footer = { CoinFont = "NoHand" },
        Settings = { Header = { Close = { HoverIcon = "NoHover" } } },
        Controls = { Button = { Plain = { DisabledFont = "NoGray" } } },
        Palette = { Client = { Global = "NO_SUCH_COLOR" }, Fine = { Global = "PANEL_BACKGROUND_COLOR" } },
      })
      local problems = sonataNext:Check("Broken")
      table.sort(problems)
      assert.are.same({
        "Controls.Button.Plain.DisabledFont: no font named NoGray",
        "Dock.BuyColor: no color named Moss",
        "Dock.DestroyColor: no color named Blood",
        "Fonts.Title.Color: no color named AlsoNope",
        "Footer.CoinFont: no font named NoHand",
        "Header.Buttons.ArtColor: no color named Pale",
        "Header.Cloud.Texture: no texture named NoArt",
        "Motion.Ease.Open: no ease named wobbly",
        "Palette.Client.Global: no client color named NO_SUCH_COLOR",
        "Panel.Fill.Color: no color named Nope",
        "Sections.TitleFont: no font named Missing",
        "Settings.Header.Close.HoverIcon: no texture named NoHover",
        "Sparkles.Colors.2: no color named Ghost",
      }, problems)
    end)
  end)

  -- Frames (next-themes.md §15): a layout the client lacks, a piece no frame has, a frame with nothing to draw.
  it("names what is wrong with a frame, by where it is", function()
    sonataNext:RegisterTheme({ Name = "BadFrames",
      Panel = { Frame = { Layout = "NoSuchLayout" } },
      Settings = { Frame = { Pieces = { TopLeftCorner = { Atlas = "x" }, Middle = { Atlas = "y" } } } },
      Controls = { Dialog = { Frame = { Alpha = 0.5 } }, Menu = { Frame = { Layout = "Dialog" } } },
    })
    local problems = sonataNext:Check("BadFrames")
    table.sort(problems)
    assert.are.same({
      "Controls.Dialog.Frame: a Layout or Pieces",
      "Panel.Frame.Layout: the client has no nine-slice layout named NoSuchLayout",
      "Settings.Frame.Pieces.Middle: no piece named Middle",
    }, problems)
  end)

  -- Ornaments (Panel.Ornaments, next-themes.md §12): a place, an anchor, a size or a motion no ornament has, a
  -- missing size, an origin no motion turns about.
  -- An ornament's blink and flicker (next-themes.md §23).
  it("names what is wrong with an ornament's blink or flicker", function()
    if addon:GetModule("NextOrnaments", true) == nil then
      ResetModuleStub("NextOrnaments", "next/ornaments.lua")
      LoadBetterBagsModule("next/ornaments.lua")
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadBlinks", Panel = { Ornaments = {
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4,
        Motion = { Blink = { Every = { 3 }, Wink = 1 }, Flicker = { Low = 2, Glow = 1 } } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, Motion = { Blink = 3, Flicker = true } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, Motion = { Blink = {}, Flicker = { Speed = 0 } } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4,
        Motion = { Flash = { Every = { 5, 1 }, Time = 0, First = -1, Spark = 1 } } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, Motion = { Flash = 2 } },
    } } })
    local problems = sonataNext:Check("BadBlinks")
    table.sort(problems)
    assert.are.same({
      "Panel.Ornaments.1.Motion.Blink.Every: two numbers, soonest and latest",
      "Panel.Ornaments.1.Motion.Blink.Wink: no blink part named Wink",
      "Panel.Ornaments.1.Motion.Flicker.Glow: no flicker part named Glow",
      "Panel.Ornaments.1.Motion.Flicker.Low: from 0 to 1",
      "Panel.Ornaments.2.Motion.Blink: a table",
      "Panel.Ornaments.2.Motion.Flicker: a table",
      "Panel.Ornaments.3.Motion.Blink.Every: two numbers, soonest and latest",
      "Panel.Ornaments.3.Motion.Flicker.Speed: more than nothing",
      "Panel.Ornaments.4.Motion.Flash.Every: two numbers, soonest and latest",
      "Panel.Ornaments.4.Motion.Flash.First: no less than nothing",
      "Panel.Ornaments.4.Motion.Flash.Spark: no flash part named Spark",
      "Panel.Ornaments.4.Motion.Flash.Time: more than nothing",
      "Panel.Ornaments.5.Motion.Flash: a table",
    }, problems)
    sonataNext:RegisterTheme({ Name = "GoodBlinks", Panel = { Ornaments = {
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4,
        Motion = { Blink = { Every = { 2, 5 }, Time = 0.1, Twice = 0.3 }, Flicker = { Low = 0.6, Speed = 8 } } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4,
        Motion = { Flash = { Every = { 5, 9 }, Time = 0.4, First = 0.8 } } },
    } } })
    assert.are.same({}, sonataNext:Check("GoodBlinks"))
  end)

  it("names what is wrong with an ornament, by where it is", function()
    if addon:GetModule("NextOrnaments", true) == nil then
      ResetModuleStub("NextOrnaments", "next/ornaments.lua")
      LoadBetterBagsModule("next/ornaments.lua")
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadOrnaments", Panel = { Ornaments = {
      { Texture = "Glow", Point = "MIDDLE", Width = 4, Height = 4 },
      { Texture = "Glow", Point = "INNER", Tile = 20 },
      { Texture = "Glow", Point = "TOP", Width = 20 },
      { Texture = "Glow", Point = "TOPINNER", Anchor = "CENTER", Width = 4 },
      { Texture = "Glow", Point = "BOTTOMOUTER", Width = 4, Height = 4, Sizes = "Huge",
        Motion = { Wiggle = 3, Origin = "LEFTISH" } },
      { Texture = "Glow", Point = "TOPOUTER", Width = 4, Height = 4, Motion = { Sway = 3, Origin = "OUTER" } },
      { Texture = "Glow", Point = "INNER", Width = 4, Tile = 8, TexCoords = { 0, 1, 0, 0.5 } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, TexCoords = { 0, 1 }, Panels = { "Bank", "Mailbox" } },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, Panels = "Bank" },
      { Point = "TOPINNER", Width = 4, Height = 4 },
      { Atlas = "spec-corner", Point = "INNER", Width = 4, Tile = 8 },
      { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, Mask = { Inset = { Left = 2 } } },
    } } })
    local problems = sonataNext:Check("BadOrnaments")
    table.sort(problems)
    assert.are.same({
      "Panel.Ornaments.1.Point: no place named MIDDLE",
      "Panel.Ornaments.10.Texture: a Texture or an Atlas",
      "Panel.Ornaments.11.Atlas: not with Tile",
      "Panel.Ornaments.12.Mask.Texture: a mask needs one",
      "Panel.Ornaments.2.Width: a span along a side needs one",
      "Panel.Ornaments.3.Height: a span along an edge needs one",
      "Panel.Ornaments.4.Anchor: no corner named CENTER",
      "Panel.Ornaments.4.Height: a piece at a corner needs one",
      "Panel.Ornaments.5.Motion.Origin: no point named LEFTISH",
      "Panel.Ornaments.5.Motion.Wiggle: no motion named Wiggle",
      "Panel.Ornaments.5.Sizes: no size named Huge",
      "Panel.Ornaments.8.Panels: no panel named Mailbox",
      "Panel.Ornaments.8.TexCoords: four numbers, left, right, top and bottom",
      "Panel.Ornaments.9.Panels: a list of panels",
    }, problems)
  end)

  -- The Glitch theme's parts (next-themes.md §21): a glitch's keys and the times it needs, a data rain's entries, an
  -- ornament's glitch and scroll, and the fonts they name.
  it("names what is wrong with a glitch, a data rain and an ornament's glitch, by where it is", function()
    for _, m in ipairs({ { "NextOrnaments", "next/ornaments.lua" }, { "NextGlitch", "next/glitch.lua" },
      { "NextRain", "next/rain.lua" }, { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" }, { "NextThreads", "next/threads.lua" }, { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" } }) do
      if addon:GetModule(m[1], true) == nil then
        ResetModuleStub(m[1], m[2])
        LoadBetterBagsModule(m[2])
      end
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadGlitch", Panel = {
      Glitch = { Open = { PowerOn = 0.2 }, Close = {}, Bursts = { Every = 4 }, Wobble = 3, Flicker = { 0.2 },
        Corrupt = { Glyphs = "", Chance = 0.5 }, Tears = { Texture = "Nope" } },
      Rain = {
        { Where = "Sky", Font = "Nope", HeadFont = "Nada", Glyphs = "01", Speed = { 4 }, Trail = { 4, 8 }, Drizzle = 1 },
        { Where = "Body", Font = "Title", HeadFont = "Title", Glyphs = "", Speed = { 4, 8 }, Trail = "long" },
      },
      Ornaments = {
        { Texture = "Glow", Point = "BODY", Motion = { Glitch = { Every = 3, Twitch = 1 }, Scroll = { Z = 4 } } },
      },
    } })
    local problems = sonataNext:Check("BadGlitch")
    table.sort(problems)
    assert.are.same({
      "Panel.Glitch.Bursts.Time: bursts need one",
      "Panel.Glitch.Close.Time: a glitch closing needs one",
      "Panel.Glitch.Corrupt.Glyphs: some glyphs",
      "Panel.Glitch.Flicker: two numbers, dark and lit",
      "Panel.Glitch.Open.Time: a glitch opening needs one",
      "Panel.Glitch.Step: a glitch needs one",
      "Panel.Glitch.Tears.Texture: no texture named Nope",
      "Panel.Glitch.Wobble: no part named Wobble",
      "Panel.Ornaments.1.Motion.Glitch.Twitch: no glitch part named Twitch",
      "Panel.Ornaments.1.Motion.Scroll.Z: X or Y",
      "Panel.Rain.1.Drizzle: no part named Drizzle",
      "Panel.Rain.1.Font: no font named Nope",
      "Panel.Rain.1.HeadFont: no font named Nada",
      "Panel.Rain.1.Speed: two numbers, slowest and fastest",
      "Panel.Rain.1.Where: no place named Sky",
      "Panel.Rain.2.Glyphs: some glyphs",
      "Panel.Rain.2.Trail: two numbers, shortest and longest",
    }, problems)
    sonataNext:RegisterTheme({ Name = "GoodGlitch", Panel = {
      Glitch = { Open = { Time = 0.4, PowerOn = 0.2 }, Close = { Time = 0.2 }, Bursts = { Every = 4, Time = 0.3 },
        Step = 0.05, Flicker = { 0.2, 1 }, Corrupt = { Glyphs = "#@", Chance = 0.5 }, Tears = { Texture = "Glow" } },
      Rain = { { Where = "Feather", Font = "Title", HeadFont = "Title", Glyphs = "01", Speed = { 4, 8 }, Trail = { 4, 8 } } },
      Ornaments = { { Texture = "Glow", Point = "BODY", Tile = 64, Motion = { Glitch = { Every = 3, Jump = 2 }, Scroll = { Y = 4 } } } },
    } })
    assert.are.same({}, sonataNext:Check("GoodGlitch"))
    -- Found by the adversarial review: data Check took that the runtime cannot run (an error on every moment, a burst
    -- that never schedules, a rain laying out columns without end).
    sonataNext:RegisterTheme({ Name = "WorseGlitch", Panel = {
      Glitch = { Open = true, Close = { Time = 0.2 }, Bursts = { Time = 0.3 } },
      Rain = {
        { Where = "Body", Glyphs = "01", Spacing = 0, Speed = { 8, 4 }, Trail = { -2, 4 } },
      },
      Ornaments = {
        { Texture = "Glow", Point = "BODY", Motion = { Glitch = true, Scroll = 4 } },
      },
    } })
    problems = sonataNext:Check("WorseGlitch")
    table.sort(problems)
    assert.are.same({
      "Panel.Glitch.Bursts.Every: bursts need one",
      "Panel.Glitch.Open: a table",
      "Panel.Glitch.Step: a glitch needs one",
      "Panel.Ornaments.1.Motion.Glitch: a table",
      "Panel.Ornaments.1.Motion.Scroll: a table",
      "Panel.Rain.1.Font: a text role",
      "Panel.Rain.1.HeadFont: a text role",
      "Panel.Rain.1.Spacing: more than nothing",
      "Panel.Rain.1.Speed: two numbers, slowest and fastest",
      "Panel.Rain.1.Trail: two numbers, shortest and longest",
    }, problems)
  end)

  -- The Frost theme's engine (next-themes.md §22): data Check must not take that the runtime cannot run (a shard size of
  -- nothing cuts the body into cells without end; jitter of half a cell or more folds triangles over; a gust, a glint or
  -- a sway without its time divides by nothing).
  it("names what is wrong with a shatter, snow and threads, by where it is", function()
    for _, m in ipairs({ { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" },
      { "NextThreads", "next/threads.lua" }, { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" } }) do
      if addon:GetModule(m[1], true) == nil then
        ResetModuleStub(m[1], m[2])
        LoadBetterBagsModule(m[2])
      end
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadFrost", Panel = {
      Shatter = { Shards = { Size = 0, Jitter = 0.5, Texture = "Nope" }, Close = {}, Thaw = 1,
        Open = { Spread = { 3 }, Storm = { From = "MIDDLE", Gale = 1, Flakes = { Count = "lots", Life = { 2 }, Puff = 1 },
          Mist = { Size = { 5, 1 }, Fog = 1 } } } },
      Snow = { Flakes = { { Where = "Sky", Count = "lots", Fall = { 2 }, Sleet = true } },
        Gusts = { Every = 0, Strength = 4, Streaks = { Length = { 9, 3 }, Gale = 1 } }, Hail = 1,
        Flybys = { Every = { 2 }, Travel = { 9, 3 }, Comet = 1, Head = { Size = { 1 }, Tail = 1 } } },
      Threads = {
        { Anchor = "MIDDLE", Points = { { 0, 1 } }, Segments = 0, Sway = { Amplitude = 2 },
          Glint = { Every = 0, Shine = 1 }, Sizes = "Huge", Knot = 1 },
      },
    } })
    local problems = sonataNext:Check("BadFrost")
    table.sort(problems)
    assert.are.same({
      "Panel.Shatter.Close.Time: a shatter closing needs one",
      "Panel.Shatter.Frost: a shatter needs one",
      "Panel.Shatter.Open.Spread: two numbers, nearest and farthest",
      "Panel.Shatter.Open.Storm.Flakes.Count: a number",
      "Panel.Shatter.Open.Storm.Flakes.Life: two numbers, shortest and longest",
      "Panel.Shatter.Open.Storm.Flakes.Puff: no part named Puff",
      "Panel.Shatter.Open.Storm.From: no corner named MIDDLE",
      "Panel.Shatter.Open.Storm.Gale: no part named Gale",
      "Panel.Shatter.Open.Storm.Mist.Count: a number",
      "Panel.Shatter.Open.Storm.Mist.Fog: no part named Fog",
      "Panel.Shatter.Open.Storm.Mist.Size: two numbers, smallest and largest",
      "Panel.Shatter.Open.Time: a shatter opening needs one",
      "Panel.Shatter.Seams: a shatter needs one",
      "Panel.Shatter.Shards.Jitter: from 0 to below half a cell",
      "Panel.Shatter.Shards.Size: more than nothing",
      "Panel.Shatter.Shards.Texture: no texture named Nope",
      "Panel.Shatter.Thaw: no part named Thaw",
      "Panel.Snow.Flakes.1.Count: a number",
      "Panel.Snow.Flakes.1.Fall: two numbers, slowest and fastest",
      "Panel.Snow.Flakes.1.Sleet: no part named Sleet",
      "Panel.Snow.Flakes.1.Where: no place named Sky",
      "Panel.Snow.Flybys.Comet: no part named Comet",
      "Panel.Snow.Flybys.Every: two numbers, soonest and latest",
      "Panel.Snow.Flybys.Head.Size: two numbers, smallest and largest",
      "Panel.Snow.Flybys.Head.Tail: no part named Tail",
      "Panel.Snow.Flybys.Max: flybys need one",
      "Panel.Snow.Flybys.Speed: two numbers, slowest and fastest",
      "Panel.Snow.Flybys.Travel: two numbers, shortest and longest",
      "Panel.Snow.Gusts.Every: gusts need one",
      "Panel.Snow.Gusts.Streaks.Gale: no part named Gale",
      "Panel.Snow.Gusts.Streaks.Length: two numbers, shortest and longest",
      "Panel.Snow.Gusts.Time: gusts need one",
      "Panel.Snow.Hail: no part named Hail",
      "Panel.Threads.1.Anchor: no anchor named MIDDLE",
      "Panel.Threads.1.Glint.Every: a glint needs one",
      "Panel.Threads.1.Glint.Shine: no part named Shine",
      "Panel.Threads.1.Glint.Time: a glint needs one",
      "Panel.Threads.1.Knot: no part named Knot",
      "Panel.Threads.1.Points: two points or more, each two numbers",
      "Panel.Threads.1.Segments: more than nothing",
      "Panel.Threads.1.Sizes: Full or Small",
      "Panel.Threads.1.Sway.Period: a sway needs one",
    }, problems)
    sonataNext:RegisterTheme({ Name = "GoodFrost", Panel = {
      Shatter = { Shards = { Size = 100, Jitter = 0.3, Texture = "Glow" }, Frost = { Texture = "Glow" },
        Seams = { Color = "White" }, Close = { Time = 0.5, Speed = { 1, 2 } },
        Open = { Time = 0.4, Spread = { 10, 20 }, Storm = { From = "TOPOUTER", Appear = 0.1,
          Flakes = { Texture = "Glow", Count = 40, Size = { 4, 8 }, Life = { 0.3, 0.6 }, Colors = { "White" } },
          Mist = { Texture = "Glow", Count = 6, Size = { 80, 120 }, Color = "White", Alpha = 0.2 } } } },
      Snow = { Flakes = { { Where = "Body", Count = 4, Texture = "Glow", Fall = { 2, 4 }, Wobble = { 3, 1 } } },
        Gusts = { Every = 8, Time = 2, Strength = 40, Streaks = { Count = 2, Texture = "Glow", Length = { 3, 9 } } },
        Flybys = { Every = { 4, 9 }, Max = 1, Travel = { 60, 90 }, Speed = { 40, 60 }, Texture = "Glow",
          Head = { Texture = "Glow", Size = { 4, 6 }, Twinkle = 3 } } },
      Threads = { { Anchor = "BOTTOM", Points = { { 0, 1 }, { 1, 2 } }, Segments = 8, Texture = "Glow",
        Sway = { Amplitude = 2, Period = 5 }, Glint = { Every = 4, Time = 1, Color = "White" }, Sizes = "Full" } },
    } })
    assert.are.same({}, sonataNext:Check("GoodFrost"))
  end)

  -- The Halloween theme's smoke and bats (next-themes.md §23): their parts are the modules', and what their runtimes
  -- divide by or count.
  -- A body's rounded corners (Panel.Corners, next-themes.md §24): by the corner's side, each a radius.
  it("names what is wrong with a body's corners", function()
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadCorners", Panel = { Corners = { TOPLEFT = 4, TOPINNER = -1, BOTTOMOUTER = "round" } } })
    local problems = sonataNext:Check("BadCorners")
    table.sort(problems)
    assert.are.same({
      "Panel.Corners.BOTTOMOUTER: a radius, no less than nothing",
      "Panel.Corners.TOPINNER: a radius, no less than nothing",
      "Panel.Corners.TOPLEFT: no corner named TOPLEFT (TOPINNER, TOPOUTER, BOTTOMINNER, BOTTOMOUTER)",
    }, problems)
    sonataNext:RegisterTheme({ Name = "GoodCorners", Panel = { Corners = { TOPINNER = 20, BOTTOMOUTER = 0 } },
      Sections = { Header = { Texture = "Glow", Height = 20 } } })
    assert.are.same({}, sonataNext:Check("GoodCorners"))
    sonataNext:RegisterTheme({ Name = "BadHeader", Sections = { Header = { Texture = "Glow", Height = 0 } } })
    assert.are.same({ "Sections.Header.Height: more than nothing" }, sonataNext:Check("BadHeader"))
    -- The client masks a texture at most three times (spec/helpers/wow_mocks.lua); a corner left square is none.
    sonataNext:RegisterTheme({ Name = "FourCorners",
      Panel = { Corners = { TOPINNER = 4, TOPOUTER = 4, BOTTOMINNER = 4, BOTTOMOUTER = 4 } } })
    assert.are.same({ "Panel.Corners: at most 3 rounded, the most masks the client puts on a texture" },
      sonataNext:Check("FourCorners"))
    sonataNext:RegisterTheme({ Name = "ThreeCorners",
      Panel = { Corners = { TOPINNER = 4, TOPOUTER = 4, BOTTOMINNER = 4, BOTTOMOUTER = 0 } } })
    assert.are.same({}, sonataNext:Check("ThreeCorners"))
  end)

  -- A transporter's beam (next-themes.md §24).
  it("names what is wrong with a stop motion, a boil and a sheet of paper, by where it is", function()
    for _, m in ipairs({ { "NextShatter", "next/shatter.lua" }, { "NextStopMotion", "next/stopmotion.lua" },
      { "NextPaper", "next/paper.lua" }, { "NextOrnaments", "next/ornaments.lua" } }) do
      if addon:GetModule(m[1], true) == nil then
        ResetModuleStub(m[1], m[2])
        LoadBetterBagsModule(m[2])
      end
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadStop", Motion = { StopMotion = { FPS = 0, Spacing = 0.7, Wobble = -1, Hop = 1 } },
      Panel = { Ornaments = {
        { Texture = "Glow", Point = "TOPINNER", Width = 4, Height = 4, Frames = 0, Locales = "enUS",
          Motion = { Boil = { FPS = 0, Jiggle = -1, Hum = 1 } } },
      } } })
    local problems = sonataNext:Check("BadStop")
    for _, expected in ipairs({
      "Motion.StopMotion.Hop: no stop motion part named Hop",
      "Motion.StopMotion.FPS: more than nothing",
      "Motion.StopMotion.Spacing: from 0 to under a half",
      "Motion.StopMotion.Wobble: no less than nothing",
      "Panel.Ornaments.1.Frames: a whole number, at least one",
      "Panel.Ornaments.1.Locales: a list of locales",
      "Panel.Ornaments.1.Motion.Boil.Hum: no boil part named Hum",
      "Panel.Ornaments.1.Motion.Boil.FPS: more than nothing",
      "Panel.Ornaments.1.Motion.Boil.Jiggle: no less than nothing",
    }) do
      local found = false
      for _, p in ipairs(problems) do found = found or p == expected end
      assert.is_true(found, "not named: " .. expected .. " in " .. table.concat(problems, "; "))
    end
    sonataNext:RegisterTheme({ Name = "NoPaperArt", Panel = { Paper = { Rate = 12 } } })
    problems = sonataNext:Check("NoPaperArt")
    assert.are.same({ "Panel.Paper.Front: a sheet needs it", "Panel.Paper.Back: a sheet needs it" }, problems)
    sonataNext:RegisterTheme({ Name = "BadPaper", Panel = { Paper = {
      Hum = 1,
      Front = { Texture = "Glow" }, Back = { Texture = "Glow" },
      Rate = 0,
      Edge = { Width = -1, Tile = 0, Hum = 1 },
      Shadow = { Spread = -1, Hum = 1 },
      Wobble = { Move = -1, Hum = 1 },
      Open = { From = "MIDDLE", Cells = 0, Curl = -1, Depth = -1, Lit = 2, Reveal = -1, Hum = 1, Half = {}, Full = { "up" },
        Note = { { Hum = 1, Width = 0 } } },
      Close = { Grab = -1, Tremble = -1, Cell = 0, Jitter = 0.6, Ball = 0, Lump = -1, Wrinkle = -1, Jag = -1, Wrap = 2, Lag = 1,
        Lit = 2, Facet = -1, Crop = 0.6, Hum = 1, Poses = {},
        Toss = { Up = "high", Gravity = -1, Drift = { 2, 1 }, Tumble = { 1 }, Life = 0, Hum = 1 } },
    } } })
    problems = sonataNext:Check("BadPaper")
    for _, expected in ipairs({
      "Panel.Paper.Hum: no sheet part named Hum",
      "Panel.Paper.Rate: more than nothing",
      "Panel.Paper.Edge.Hum: no edge part named Hum",
      "Panel.Paper.Edge.Width: no less than nothing",
      "Panel.Paper.Edge.Tile: more than nothing",
      "Panel.Paper.Shadow.Hum: no shadow part named Hum",
      "Panel.Paper.Shadow.Spread: no less than nothing",
      "Panel.Paper.Wobble.Hum: no wobble part named Hum",
      "Panel.Paper.Wobble.Move: no less than nothing",
      "Panel.Paper.Open.Hum: no open part named Hum",
      "Panel.Paper.Open.From: no corner named MIDDLE",
      "Panel.Paper.Open.Cells: a whole number, at least one",
      "Panel.Paper.Open.Curl: no less than nothing",
      "Panel.Paper.Open.Depth: no less than nothing",
      "Panel.Paper.Open.Lit: from 0 to 1",
      "Panel.Paper.Open.Reveal: no less than nothing",
      "Panel.Paper.Open.Half: a pose or more, each an angle",
      "Panel.Paper.Open.Full: a pose or more, each an angle",
      "Panel.Paper.Open.Note.1.Hum: no note part named Hum",
      "Panel.Paper.Open.Note.1.Width: more than nothing",
      "Panel.Paper.Open.Note.1.Height: more than nothing",
      "Panel.Paper.Close.Hum: no close part named Hum",
      "Panel.Paper.Close.Grab: no less than nothing",
      "Panel.Paper.Close.Tremble: no less than nothing",
      "Panel.Paper.Close.Cell: more than nothing",
      "Panel.Paper.Close.Jitter: from 0 to under a half",
      "Panel.Paper.Close.Ball: more than nothing",
      "Panel.Paper.Close.Lump: no less than nothing",
      "Panel.Paper.Close.Wrinkle: no less than nothing",
      "Panel.Paper.Close.Jag: no less than nothing",
      "Panel.Paper.Close.Wrap: from 0 to 1",
      "Panel.Paper.Close.Lag: from 0 to under 1",
      "Panel.Paper.Close.Lit: from 0 to 1",
      "Panel.Paper.Close.Facet: no less than nothing",
      "Panel.Paper.Close.Crop: from 0 to under a half",
      "Panel.Paper.Close.Poses: a pose or more, each from 0 to 1, the last 1",
      "Panel.Paper.Close.Toss.Hum: no toss part named Hum",
      "Panel.Paper.Close.Toss.Up: no less than nothing",
      "Panel.Paper.Close.Toss.Gravity: no less than nothing",
      "Panel.Paper.Close.Toss.Drift: two numbers, the least first",
      "Panel.Paper.Close.Toss.Tumble: two numbers",
      "Panel.Paper.Close.Toss.Life: more than nothing",
    }) do
      local found = false
      for _, p in ipairs(problems) do found = found or p == expected end
      assert.is_true(found, "not named: " .. expected .. " in " .. table.concat(problems, "; "))
    end
  end)

  it("names what is wrong with a beam, by where it is", function()
    if addon:GetModule("NextBeam", true) == nil then
      ResetModuleStub("NextBeam", "next/beam.lua")
      LoadBetterBagsModule("next/beam.lua")
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadBeam", Panel = { Beam = {
      Sparkles = { Density = 0, Size = { 9, 3 }, Stretch = 0, Alpha = { 1 }, Twinkle = { 2 }, Sharpness = 0,
        Drift = { 5 }, Spread = -1, Colors = { "Nope" }, Fizz = 1 },
      Column = { Spread = -2, Shimmer = { 2, 1 }, Scroll = "up", Color = "Nope", Hum = 1 },
      Glow = { Color = "Nope", Halo = 1 },
      Open = { Reveal = { 0.5, 0.2 }, Sparkles = { 0, 0.5, 0.2, 0.8 }, Column = { 1 }, Fade = { 0, 1 } },
      Close = { Sparkles = { 0, 0.1, 0.2, 0.3 }, Glow = { 0.1, 0.2, 0.3 }, Column = { 0, 0.1, 0.2, 0.3, 0.4 } },
      Phaser = 1, Margin = -1, Ends = "far",
    } } })
    local problems = sonataNext:Check("BadBeam")
    table.sort(problems)
    assert.are.same({
      "Panel.Beam.Close.Column: four numbers in order, in, full, out and gone",
      "Panel.Beam.Close.Fade: two numbers, from and to",
      "Panel.Beam.Close.Glow: four numbers in order, in, full, out and gone",
      "Panel.Beam.Column.Color: no color named Nope",
      "Panel.Beam.Column.Hum: no part named Hum",
      "Panel.Beam.Column.Scroll: a number",
      "Panel.Beam.Column.Shimmer: two numbers, how deep (0 to 1) and how fast",
      "Panel.Beam.Column.Spread: no less than nothing",
      "Panel.Beam.Ends: no less than nothing",
      "Panel.Beam.Glow.Color: no color named Nope",
      "Panel.Beam.Glow.Halo: no part named Halo",
      "Panel.Beam.Margin: no less than nothing",
      "Panel.Beam.Open.Column: four numbers in order, in, full, out and gone",
      "Panel.Beam.Open.Fade: no part named Fade",
      "Panel.Beam.Open.Reveal: two numbers, from and to",
      "Panel.Beam.Open.Sparkles: four numbers in order, in, full, out and gone",
      "Panel.Beam.Phaser: no part named Phaser",
      "Panel.Beam.Sparkles.Alpha: two numbers, faintest and strongest",
      "Panel.Beam.Sparkles.Colors.1: no color named Nope",
      "Panel.Beam.Sparkles.Density: more than nothing",
      "Panel.Beam.Sparkles.Drift: two numbers, slowest and fastest",
      "Panel.Beam.Sparkles.Fizz: no part named Fizz",
      "Panel.Beam.Sparkles.Sharpness: more than nothing",
      "Panel.Beam.Sparkles.Size: two numbers, smallest and largest",
      "Panel.Beam.Sparkles.Spread: no less than nothing",
      "Panel.Beam.Sparkles.Stretch: more than nothing",
      "Panel.Beam.Sparkles.Twinkle: two numbers, slowest and fastest",
    }, problems)
    sonataNext:RegisterTheme({ Name = "NoSparkles", Panel = { Beam = { Open = { Reveal = { 0.2, 0.6 } } } } })
    assert.are.same({ "Panel.Beam.Sparkles: a beam needs them" }, sonataNext:Check("NoSparkles"))
    sonataNext:RegisterTheme({ Name = "GoodBeam", Panel = { Beam = { Margin = 12, Ends = 40,
      Sparkles = { Texture = "Glow", Colors = { "White", "Gold" }, Density = 2, Size = { 6, 12 }, Stretch = 2,
        Alpha = { 0.6, 1 }, BlendMode = "ADD", Twinkle = { 3, 8 }, Sharpness = 3, Drift = { 20, 50 }, Spread = 10 },
      Column = { Texture = "Glow", Color = "White", Alpha = 0.5, BlendMode = "ADD", Spread = 20, Shimmer = { 0.3, 4 },
        Scroll = 0.6 },
      Glow = { Texture = "Glow", Color = "Gold", Alpha = 0.6, BlendMode = "ADD" },
      Open = { Reveal = { 0.3, 0.6 }, Sparkles = { 0, 0.2, 0.5, 0.8 }, Column = { 0, 0.15, 0.55, 0.9 },
        Glow = { 0.1, 0.35, 0.45, 0.7 } },
      Close = { Fade = { 0.2, 0.5 }, Sparkles = { 0, 0.15, 0.5, 0.8 } },
    } } })
    assert.are.same({}, sonataNext:Check("GoodBeam"))
  end)

  it("names what is wrong with a smoke and bats, by where it is", function()
    for _, m in ipairs({ { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" } }) do
      if addon:GetModule(m[1], true) == nil then
        ResetModuleStub(m[1], m[2])
        LoadBetterBagsModule(m[2])
      end
    end
    sonataNext.themes = {}
    FreshNextThemes()
    sonataNext = addon:GetModule("SonataNext")
    sonataNext:Init()
    sonataNext:RegisterTheme({ Name = "BadSpooky", Panel = {
      Smoke = { Puffs = { Size = { 9, 3 }, Alpha = { 0.8, 0.2 }, Fog = 1 },
        Sparks = { Count = "lots", Life = { 1 }, Rise = { 3 }, Glow = 1 },
        Open = { Spacing = 0, Reveal = { 0.5 }, Lift = { 3 }, Life = { 1 }, Start = -1, Growth = 0, FadeIn = 2,
          Swirl = { 4 }, Burst = 0, Jitter = -1, Buoyancy = "up", Waft = 1 }, Haze = 1 },
      Bats = { Frames = 0, FrameRate = -1, Squeak = 1,
        Close = { Count = { 15, 10 }, Speed = { 1 }, Shudder = -1, Break = -1, Morph = -1, Gap = -2, Jitter = 0.5,
          Dark = "Nope", Flap = 1 },
        Flutter = { Every = { 3 }, Travel = 0, Band = { 50, 10 }, Swoop = 1 } },
    } })
    local problems = sonataNext:Check("BadSpooky")
    table.sort(problems)
    assert.are.same({
      "Panel.Bats.Close.Break: no less than nothing",
      "Panel.Bats.Close.Count: two numbers, fewest and most",
      "Panel.Bats.Close.Dark: no color named Nope",
      "Panel.Bats.Close.Flap: no part named Flap",
      "Panel.Bats.Close.Gap: no less than nothing",
      "Panel.Bats.Close.Jitter: from 0 to below half a cell",
      "Panel.Bats.Close.Morph: no less than nothing",
      "Panel.Bats.Close.Pieces: a bats close needs them",
      "Panel.Bats.Close.Shudder: no less than nothing",
      "Panel.Bats.Close.Speed: two numbers, slowest and fastest",
      "Panel.Bats.Flutter.Band: two numbers, highest and lowest",
      "Panel.Bats.Flutter.Every: two numbers, soonest and latest",
      "Panel.Bats.Flutter.Swoop: no part named Swoop",
      "Panel.Bats.Flutter.Travel: more than nothing",
      "Panel.Bats.FrameRate: no less than nothing",
      "Panel.Bats.Frames: more than nothing",
      "Panel.Bats.Squeak: no part named Squeak",
      "Panel.Smoke.Haze: no part named Haze",
      "Panel.Smoke.Open.Buoyancy: a number",
      "Panel.Smoke.Open.Burst: more than nothing",
      "Panel.Smoke.Open.FadeIn: from 0 to 1",
      "Panel.Smoke.Open.Growth: more than nothing",
      "Panel.Smoke.Open.Jitter: no less than nothing",
      "Panel.Smoke.Open.Life: two numbers, shortest and longest",
      "Panel.Smoke.Open.Lift: two numbers, slowest and fastest",
      "Panel.Smoke.Open.Reveal: two numbers, from and to",
      "Panel.Smoke.Open.Rise: an opening needs one",
      "Panel.Smoke.Open.Spacing: more than nothing",
      "Panel.Smoke.Open.Start: more than nothing",
      "Panel.Smoke.Open.Swirl: two numbers, how far and how often",
      "Panel.Smoke.Open.Waft: no part named Waft",
      "Panel.Smoke.Puffs.Alpha: two numbers, faintest and strongest",
      "Panel.Smoke.Puffs.Fog: no part named Fog",
      "Panel.Smoke.Puffs.Size: two numbers, smallest and largest",
      "Panel.Smoke.Sparks.Count: a number",
      "Panel.Smoke.Sparks.Glow: no part named Glow",
      "Panel.Smoke.Sparks.Life: two numbers, shortest and longest",
      "Panel.Smoke.Sparks.Rise: two numbers, slowest and fastest",
    }, problems)
    sonataNext:RegisterTheme({ Name = "NoPuffs", Panel = { Smoke = { Open = { Rise = 0.3, Spacing = 50,
      Life = { 0.5, 0.8 } } } } })
    assert.are.same({ "Panel.Smoke.Puffs: a smoke opening needs them" }, sonataNext:Check("NoPuffs"))
    sonataNext:RegisterTheme({ Name = "NoSizes", Panel = {
      Smoke = { Puffs = { Texture = "Glow" }, Open = { Rise = 0.3, Spacing = 50 } },
      Bats = { Flutter = { Travel = 100 } },
    } })
    problems = sonataNext:Check("NoSizes")
    table.sort(problems)
    assert.are.same({ "Panel.Bats.Flutter.Every: two numbers, soonest and latest",
      "Panel.Smoke.Open.Life: two numbers, shortest and longest",
      "Panel.Smoke.Puffs.Size: two numbers, smallest and largest" }, problems)
    sonataNext:RegisterTheme({ Name = "GoodSpooky", Panel = {
      Smoke = { Puffs = { Texture = "Glow", Size = { 80, 120 }, Alpha = { 0.4, 0.7 }, Colors = { "White" } },
        Sparks = { Texture = "Glow", Count = 4, Life = { 0.2, 0.3 }, Rise = { 20, 40 } },
        Open = { Rise = 0.3, Spacing = 50, Life = { 0.6, 0.9 }, Start = 0.5, Growth = 2, FadeIn = 0.1,
          Lift = { 10, 20 }, Buoyancy = 30, Swirl = { 6, 1 }, Burst = 3, Jitter = 0.3, Reveal = { 0.1, 0.3 } } },
      Bats = { Texture = "Glow", Frames = 4, FrameRate = 10,
        Close = { Count = { 10, 15 }, Pieces = { Texture = "Glow" }, Speed = { 100, 200 }, Shudder = 0.1, Break = 0.1,
          Morph = 0.3, Gap = 8, Jitter = 0.25, Dark = "Black" },
        Flutter = { Every = { 5, 9 }, Travel = 200, Band = { 20, 50 } } },
    } })
    assert.are.same({}, sonataNext:Check("GoodSpooky"))
  end)

  -- The header buttons down a side rail (Header.Buttons.Rail, next-themes.md §13).
  it("names what a side rail lacks", function()
    sonataNext:RegisterTheme({ Name = "BadRail", Header = { Buttons = { Rail = { Gap = 4 } } } })
    local problems = sonataNext:Check("BadRail")
    table.sort(problems)
    assert.are.same({
      "Header.Buttons.Rail.Top: a side rail needs one",
      "Header.Buttons.Rail.Width: a side rail needs one",
    }, problems)
    sonataNext:RegisterTheme({ Name = "GoodRail", Header = { Buttons = { Rail = { Width = 40, Top = 60 } } } })
    assert.are.same({}, sonataNext:Check("GoodRail"))
    sonataNext:RegisterTheme({ Name = "BadToggle", Controls = { Toggle = { Style = "Checkbox" } } })
    assert.are.same({ "Controls.Toggle.Style: no style named Checkbox" }, sonataNext:Check("BadToggle"))
    sonataNext:RegisterTheme({ Name = "GoodCheck", Controls = { Toggle = { Style = "Check" } } })
    assert.are.same({}, sonataNext:Check("GoodCheck"))
    sonataNext:RegisterTheme({ Name = "BadPin", Header = { Buttons = { Pinned = { closeButton = { Point = "MIDDLE" } } } } })
    assert.are.same({ "Header.Buttons.Pinned.closeButton.Point: no corner named MIDDLE" }, sonataNext:Check("BadPin"))
    sonataNext:RegisterTheme({ Name = "SidePin", Header = { Buttons = { Pinned = { closeButton = { Point = "TOPOUTER" } } } } })
    assert.are.same({}, sonataNext:Check("SidePin"))
  end)

  -- A bag button holding the header's row (Header.Buttons.Menu, next-themes.md §19; docs/next-plain-theme.md, round
  -- three): a corner of the body named by its side, its size, art in each layer, the panels it names.
  it("names what is wrong with a bag button, by where it is", function()
    if addon:GetModule("NextOrnaments", true) == nil then
      ResetModuleStub("NextOrnaments", "next/ornaments.lua")
      LoadBetterBagsModule("next/ornaments.lua")
    end
    sonataNext:RegisterTheme({ Name = "BadMenu", Header = { Buttons = { Menu = { Point = "MIDDLE", Anchor = "CENTER",
      Layers = { { Alpha = 1 }, { Texture = "Interface\\Spec\\bag.png" } }, Panels = { Shop = { Layers = {} } } } } } })
    local problems = sonataNext:Check("BadMenu")
    table.sort(problems)
    assert.are.same({
      "Header.Buttons.Menu.Anchor: no corner named CENTER",
      "Header.Buttons.Menu.Height: a bag button needs one",
      "Header.Buttons.Menu.Layers[1]: draws nothing",
      "Header.Buttons.Menu.Panels.Shop: no panel named Shop",
      "Header.Buttons.Menu.Point: no corner named MIDDLE",
      "Header.Buttons.Menu.Width: a bag button needs one",
    }, problems)
    sonataNext:RegisterTheme({ Name = "GoodMenu", Header = { Buttons = { Menu = { Point = "TOPINNER", Width = 40, Height = 40,
      Layers = { { Texture = "Interface\\Spec\\bag.png" }, { Unit = "npc" } },
      Panels = { Vendor = { Layers = { { Atlas = "x" }, { Alpha = 1 } } } } } } } })
    assert.are.same({ "Header.Buttons.Menu.Panels.Vendor.Layers[2]: draws nothing" }, sonataNext:Check("GoodMenu"),
      "a panel's own layers too")
    sonataNext:RegisterTheme({ Name = "NowhereMenu", Header = { Buttons = { Menu = { Width = 40, Height = 40 } } } })
    assert.are.same({ "Header.Buttons.Menu.Point: no corner named nil" }, sonataNext:Check("NowhereMenu"))
  end)

  -- GW2_UI rewrites the client's fonts at PLAYER_LOGIN (docs/next-gw2-theme.md), after BetterBags copied some of
  -- them for its roles: once the game has started, a theme whose copies are stale is applied again, unsaved.
  describe("watching the client's fonts", function()
    local handlers, stale, savedRegister, savedStale

    before_each(function()
      handlers, stale = {}, false
      savedRegister, savedStale = rawget(events, "RegisterEvent"), rawget(nextStyle, "CopiesStale")
      events.RegisterEvent = function(_, event, fn)
        handlers[event] = handlers[event] or {}
        table.insert(handlers[event], fn)
      end
      nextStyle.CopiesStale = function() return stale end
      sonataNext.watchingFonts = nil
      sonataNext:RegisterTheme({ Name = "Other" })
    end)

    after_each(function()
      events.RegisterEvent, nextStyle.CopiesStale = savedRegister, savedStale
      sonataNext.watchingFonts = nil
    end)

    it("applies the current theme again, unsaved, when the game starts with a copy stale", function()
      sonataNext:ApplyTheme(ctx(), "Other", false)
      sonataNext:WatchClientFonts()
      assert.are.equal(1, #handlers.PLAYER_ENTERING_WORLD)
      local applied = #used
      stale = true
      assert.is_true(sonataNext:OnClientFontsChanged(ctx()))
      assert.are.equal(applied + 1, #used)
      assert.are.equal("Other", used[#used].Name)
      assert.are.equal("Other", sonataNext:GetCurrentThemeKey())
      assert.are.equal("Default", saved, "not saved")
      handlers.PLAYER_ENTERING_WORLD[1](ctx())
      assert.are.equal(applied + 2, #used, "through the event")
    end)

    it("does nothing while every copy is current, or before it started", function()
      sonataNext:WatchClientFonts()
      local applied = #used
      assert.is_false(sonataNext:OnClientFontsChanged(ctx()))
      sonataNext.started = false
      stale = true
      assert.is_false(sonataNext:OnClientFontsChanged(ctx()))
      assert.are.equal(applied, #used)
      sonataNext.started = true
    end)

    it("listens once however often it starts", function()
      sonataNext:WatchClientFonts()
      sonataNext:WatchClientFonts()
      assert.are.equal(1, #handlers.PLAYER_ENTERING_WORLD)
    end)
  end)

  -- The other registration path on Sonata itself (asked: "original themes, next themes").
  it("is reached from Sonata's RegisterNextTheme too", function()
    LoadBetterBagsModule("sonata/engine.lua")
    addon:GetModule("Sonata"):RegisterNextTheme({ Name = "ViaSonata" })
    assert.is_not_nil(sonataNext:GetTheme("ViaSonata"))
  end)
end)
