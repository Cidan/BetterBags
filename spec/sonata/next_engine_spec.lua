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

local sonataNext = FreshNextThemes()
local context = addon:GetModule("Context")

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }

describe("SonataNext", function()
  local saved, sent, used, savedFlags

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
    saved, sent, used = "Default", {}, {}
    db.GetNextTheme = function() return saved end
    db.SetNextTheme = function(_, key) saved = key end
    events.SendMessage = function(_, _, name, key) table.insert(sent, { name, key }) end
    nextStyle.Use = function(_, theme) table.insert(used, theme) end
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
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "R1", Requires = "ElvUI" }) end)
      assert.has_error(function() sonataNext:RegisterTheme({ Name = "R2", Requires = { 3 } }) end)
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
      sonataNext.themes = {}
      FreshNextThemes()
      sonataNext = addon:GetModule("SonataNext")
      sonataNext:Init()
    end)

    it("finds nothing wrong with Default", function()
      assert.are.same({}, sonataNext:Check("Default"))
    end)

    it("names every color, role, texture and ease it cannot find, by where it is", function()
      sonataNext:RegisterTheme({ Name = "Broken",
        Panel = { Fill = { Color = "Nope" }, DropGlow = { Color = { 1, 0, 0, 1 } } },
        Sections = { TitleFont = "Missing" },
        Header = { Cloud = { Texture = "NoArt" }, Spark = { Texture = "Interface\\Art\\Spark" } },
        Sparkles = { Colors = { "Gold", "Ghost" } },
        Motion = { Ease = { Open = "wobbly" } },
        Fonts = { Title = { Color = "AlsoNope" } },
      })
      local problems = sonataNext:Check("Broken")
      table.sort(problems)
      assert.are.same({
        "Fonts.Title.Color: no color named AlsoNope",
        "Header.Cloud.Texture: no texture named NoArt",
        "Motion.Ease.Open: no ease named wobbly",
        "Panel.Fill.Color: no color named Nope",
        "Sections.TitleFont: no font named Missing",
        "Sparkles.Colors.2: no color named Ghost",
      }, problems)
    end)
  end)

  -- The other registration path on Sonata itself (asked: "original themes, next themes").
  it("is reached from Sonata's RegisterNextTheme too", function()
    LoadBetterBagsModule("sonata/engine.lua")
    addon:GetModule("Sonata"):RegisterNextTheme({ Name = "ViaSonata" })
    assert.is_not_nil(sonataNext:GetTheme("ViaSonata"))
  end)
end)
