-- engine_spec.lua -- The Sonata theme engine (sonata/engine.lua): themes are data, resolved
-- by inheritance (Base <- Parent chain <- theme), per-client overrides and variables, and
-- applied to every registered window and element.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local db = StubBetterBagsModule("Database")
local savedTheme = "Default"
db.GetTheme = function() return savedTheme end
db.SetTheme = function(_, key) savedTheme = key end

LoadBetterBagsModule("sonata/engine.lua")
local sonata = addon:GetModule("Sonata")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

local function base()
  return {
    Name = "Base",
    Hidden = true,
    Variables = { Accent = { 1, 1, 1, 1 } },
    Windows = {
      Bag = {
        Insets = { Left = 1, Right = 2, Top = 3, Bottom = 4 },
        Title = { Color = "$Accent", Height = 20 },
        CloseButton = { Size = 32 },
      },
    },
    Elements = {
      SectionHeader = { Font = { Object = "GameFontNormal" } },
    },
  }
end

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }

-- withHandler runs fn with geterrorhandler replaced, restoring it even when fn errors.
local function withHandler(handler, fn)
  local original = _G.geterrorhandler
  _G.geterrorhandler = function() return handler end
  local ok, err = pcall(fn)
  _G.geterrorhandler = original
  if not ok then error(err, 0) end
end

describe("Sonata engine", function()
  local sent
  local originalSend
  local savedFlags

  before_each(function()
    sonata:Init()
    sonata.themes = {}
    savedTheme = "Default"
    sent = {}
    originalSend = events.SendMessage
    events.SendMessage = function(_, _, message, ...)
      table.insert(sent, { message = message, args = { ... } })
    end
    savedFlags = {}
    for _, flag in ipairs(FLAGS) do
      savedFlags[flag] = addon[flag]
      addon[flag] = false
    end
    addon.isRetail = true
  end)

  after_each(function()
    events.SendMessage = originalSend
    for _, flag in ipairs(FLAGS) do
      addon[flag] = savedFlags[flag]
    end
  end)

  it("keeps the registered themes across Init", function()
    sonata:RegisterTheme({ Name = "Kept" })
    sonata:Init()
    assert.is_not_nil(sonata:GetTheme("Kept"))
  end)

  describe("registration", function()
    it("registers a theme by its name", function()
      local theme = { Name = "Mine" }
      sonata:RegisterTheme(theme)
      assert.are.equal(theme, sonata:GetTheme("Mine"))
    end)

    it("rejects a theme without a name", function()
      assert.has_error(function() sonata:RegisterTheme({}) end)
    end)

    it("rejects a second theme with the same name", function()
      sonata:RegisterTheme({ Name = "Mine" })
      assert.has_error(function() sonata:RegisterTheme({ Name = "Mine" }) end)
    end)

    it("treats Available as a boolean, a function, or true when unset", function()
      sonata:RegisterTheme({ Name = "Unset" })
      sonata:RegisterTheme({ Name = "Off", Available = false })
      sonata:RegisterTheme({ Name = "Fn", Available = function() return false end })
      assert.is_true(sonata:IsAvailable("Unset"))
      assert.is_false(sonata:IsAvailable("Off"))
      assert.is_false(sonata:IsAvailable("Fn"))
      assert.is_false(sonata:IsAvailable("Missing"))
    end)

    it("lists only available themes that are not hidden", function()
      sonata:RegisterTheme(base())
      sonata:RegisterTheme({ Name = "Shown" })
      sonata:RegisterTheme({ Name = "Gone", Available = false })
      local all = sonata:GetAllThemes()
      assert.is_not_nil(all.Shown)
      assert.is_nil(all.Gone)
      assert.is_nil(all.Base)
    end)
  end)

  describe("resolution", function()
    before_each(function()
      sonata:RegisterTheme(base())
    end)

    it("inherits every value from Base that the theme does not set", function()
      sonata:RegisterTheme({ Name = "Child", Windows = { Bag = { Insets = { Top = 30 } } } })
      local theme = sonata:Resolve("Child")
      assert.are.same({ Left = 1, Right = 2, Top = 30, Bottom = 4 }, theme.Windows.Bag.Insets)
      assert.are.equal(32, theme.Windows.Bag.CloseButton.Size)
      assert.are.equal("GameFontNormal", theme.Elements.SectionHeader.Font.Object)
    end)

    it("inherits through a chain of parents", function()
      sonata:RegisterTheme({ Name = "A", Windows = { Bag = { Title = { Height = 10 } } } })
      sonata:RegisterTheme({ Name = "B", Parent = "A", Windows = { Bag = { CloseButton = { Size = 16 } } } })
      sonata:RegisterTheme({ Name = "C", Parent = "B", Windows = { Bag = { Insets = { Left = 9 } } } })
      local theme = sonata:Resolve("C")
      assert.are.equal(10, theme.Windows.Bag.Title.Height)
      assert.are.equal(16, theme.Windows.Bag.CloseButton.Size)
      assert.are.equal(9, theme.Windows.Bag.Insets.Left)
      assert.are.equal(4, theme.Windows.Bag.Insets.Bottom)
    end)

    it("replaces lists instead of merging them", function()
      sonata:RegisterTheme({ Name = "A", Windows = { Bag = { Textures = { { Texture = "a" }, { Texture = "b" } } } } })
      sonata:RegisterTheme({ Name = "B", Parent = "A", Windows = { Bag = { Textures = { { Texture = "c" } } } } })
      local theme = sonata:Resolve("B")
      assert.are.equal(1, #theme.Windows.Bag.Textures)
      assert.are.equal("c", theme.Windows.Bag.Textures[1].Texture)
    end)

    it("removes an inherited value set to false", function()
      sonata:RegisterTheme({ Name = "NoClose", Windows = { Bag = { CloseButton = false } } })
      local theme = sonata:Resolve("NoClose")
      assert.is_nil(theme.Windows.Bag.CloseButton)
    end)

    it("errors on an unknown parent and on a parent cycle", function()
      sonata:RegisterTheme({ Name = "Orphan", Parent = "Nobody" })
      assert.has_error(function() sonata:Resolve("Orphan") end)
      sonata:RegisterTheme({ Name = "X", Parent = "Y" })
      sonata:RegisterTheme({ Name = "Y", Parent = "X" })
      assert.has_error(function() sonata:Resolve("X") end)
    end)

    it("errors on an unknown theme", function()
      assert.has_error(function() sonata:Resolve("Nope") end)
    end)

    it("never changes the registered tables", function()
      local child = { Name = "Child", Windows = { Bag = { Insets = { Top = 30 } } } }
      sonata:RegisterTheme(child)
      local theme = sonata:Resolve("Child")
      theme.Windows.Bag.Insets.Top = 99
      assert.are.same({ Top = 30 }, child.Windows.Bag.Insets)
      assert.are.equal(3, sonata:GetTheme("Base").Windows.Bag.Insets.Top)
    end)

    it("applies the client's overrides after each level", function()
      addon.isRetail = false
      addon.isClassic = true
      sonata:RegisterTheme({
        Name = "Clienty",
        Windows = { Bag = { Insets = { Top = 30 } } },
        Clients = {
          Classic = { Windows = { Bag = { Insets = { Top = 8 }, Title = false } } },
          Era = { Windows = { Bag = { Insets = { Left = 7 } } } },
          Retail = { Windows = { Bag = { Insets = { Top = 50 } } } },
        },
      })
      local theme = sonata:Resolve("Clienty")
      assert.are.equal(8, theme.Windows.Bag.Insets.Top)
      assert.are.equal(7, theme.Windows.Bag.Insets.Left)
      assert.is_nil(theme.Windows.Bag.Title)
      assert.is_nil(theme.Clients)
    end)

    it("lets a child theme override what a parent's client override set", function()
      addon.isForever = true
      sonata:RegisterTheme({
        Name = "Parent",
        Clients = { Forever = { Windows = { Bag = { Insets = { Top = 12 } } } } },
      })
      sonata:RegisterTheme({ Name = "Kid", Parent = "Parent", Windows = { Bag = { Insets = { Top = 40 } } } })
      assert.are.equal(40, sonata:Resolve("Kid").Windows.Bag.Insets.Top)
    end)

    it("orders the client keys from general to specific", function()
      assert.are.same({ "Retail" }, sonata:GetClientKeys())
      addon.isForever = true
      assert.are.same({ "Retail", "Forever" }, sonata:GetClientKeys())
      addon.isRetail, addon.isForever, addon.isClassic = false, false, true
      assert.are.same({ "Classic", "Era" }, sonata:GetClientKeys())
      addon.isClassic, addon.isBCC = false, true
      assert.are.same({ "Classic", "TBC" }, sonata:GetClientKeys())
      addon.isBCC, addon.isMists = false, true
      assert.are.same({ "Classic", "Mists" }, sonata:GetClientKeys())
      addon.isMists, addon.isBCC, addon.isAnniversary = false, true, true
      assert.are.same({ "Classic", "TBC", "Anniversary" }, sonata:GetClientKeys())
      addon.isBCC, addon.isAnniversary, addon.isCata = false, false, true
      assert.are.same({ "Classic", "Cata" }, sonata:GetClientKeys())
    end)

    it("substitutes variables, including ones a child overrides or computes", function()
      local calls = 0
      sonata:RegisterTheme({
        Name = "Vars",
        Variables = {
          Accent = { 0.5, 0.5, 0.5, 1 },
          Live = function() calls = calls + 1 return calls end,
        },
        Windows = { Bag = { Insets = { Top = "$Live" } } },
      })
      local theme = sonata:Resolve("Vars")
      assert.are.same({ 0.5, 0.5, 0.5, 1 }, theme.Windows.Bag.Title.Color)
      assert.are.equal(1, theme.Windows.Bag.Insets.Top)
      assert.are.equal(2, sonata:Resolve("Vars").Windows.Bag.Insets.Top)
    end)

    it("copies a table variable for every use", function()
      sonata:RegisterTheme({ Name = "Copy", Windows = { Bag = { CloseButton = { Color = "$Accent" } } } })
      local theme = sonata:Resolve("Copy")
      assert.are.same(theme.Windows.Bag.Title.Color, theme.Windows.Bag.CloseButton.Color)
      assert.are_not.equal(theme.Windows.Bag.Title.Color, theme.Windows.Bag.CloseButton.Color)
    end)

    it("errors on an unknown variable", function()
      sonata:RegisterTheme({ Name = "Bad", Windows = { Bag = { Title = { Color = "$Nope" } } } })
      assert.has_error(function() sonata:Resolve("Bad") end)
    end)

    it("fills in variables that refer to other variables, inside tables too", function()
      sonata:RegisterTheme({
        Name = "Nested",
        Variables = { A = "$B", B = 5, T = { Color = "$B" } },
        Windows = { Bag = { Insets = { Top = "$A" }, Title = { Font = "$T" } } },
      })
      local theme = sonata:Resolve("Nested")
      assert.are.equal(5, theme.Windows.Bag.Insets.Top)
      assert.are.equal(5, theme.Windows.Bag.Title.Font.Color)
      assert.are.equal(5, theme.Variables.A)
    end)

    it("errors on variables that refer to each other in a cycle", function()
      sonata:RegisterTheme({ Name = "Loop", Variables = { A = "$B", B = "$A" }, Windows = { Bag = { Insets = { Top = "$A" } } } })
      assert.has_error(function() sonata:Resolve("Loop") end)
    end)

    it("errors when a variable function returns nothing", function()
      sonata:RegisterTheme({ Name = "Empty", Variables = { Gone = function() return nil end }, Windows = { Bag = { Insets = { Top = "$Gone" } } } })
      local ok, err = pcall(sonata.Resolve, sonata, "Empty")
      assert.is_false(ok)
      assert.is_truthy(tostring(err):find("returned nothing"))
    end)

    it("reads a variable name with spaces around it", function()
      sonata:RegisterTheme({ Name = "Spaced", Windows = { Bag = { CloseButton = { Color = " $Accent " } } } })
      assert.are.same({ 1, 1, 1, 1 }, sonata:Resolve("Spaced").Windows.Bag.CloseButton.Color)
    end)

    it("keeps values with a metatable, such as frames, by reference", function()
      local frame = CreateFrame("Frame")
      setmetatable(frame, { __index = {} })
      sonata:RegisterTheme({ Name = "Framed", Windows = { Bag = { Title = { Points = { { RelativeTo = frame } } } } } })
      assert.are.equal(frame, sonata:Resolve("Framed").Windows.Bag.Title.Points[1].RelativeTo)
    end)

    it("keeps the describing keys out of the style", function()
      sonata:RegisterTheme({ Name = "Meta", Parent = "Base", Available = true, Description = "d" })
      local theme = sonata:Resolve("Meta")
      assert.is_nil(theme.Parent)
      assert.is_nil(theme.Available)
      assert.is_nil(theme.Clients)
      assert.are.equal("d", theme.Description)
    end)

    it("applies the general client key before the specific one", function()
      addon.isRetail = false
      addon.isClassic = true
      sonata:RegisterTheme({
        Name = "Order",
        Clients = {
          Era = { Windows = { Bag = { Insets = { Top = 2 } } } },
          Classic = { Windows = { Bag = { Insets = { Top = 1 } } } },
        },
      })
      assert.are.equal(2, sonata:Resolve("Order").Windows.Bag.Insets.Top)
    end)

    it("rejects a client key it does not know", function()
      assert.has_error(function()
        sonata:RegisterTheme({ Name = "Typo", Clients = { Retial = {} } })
      end)
    end)

    it("hands out copies of the variables", function()
      sonata:RegisterTheme({ Name = "VarCopy" })
      local theme = sonata:Resolve("VarCopy")
      theme.Variables.Accent[1] = 0
      assert.are.equal(1, sonata:Resolve("VarCopy").Variables.Accent[1])
    end)

    it("keeps strings that only contain a dollar sign", function()
      sonata:RegisterTheme({ Name = "Money", Windows = { Bag = { Title = { Text = "costs $5 now" } } } })
      assert.are.equal("costs $5 now", sonata:Resolve("Money").Windows.Bag.Title.Text)
    end)
  end)

  describe("applying a theme", function()
    local decorated, styled

    before_each(function()
      sonata:RegisterTheme(base())
      sonata:RegisterTheme({ Name = "Default", Windows = { Bag = { Insets = { Top = 42 } } } })
      sonata:RegisterTheme({ Name = "Other", Windows = { Bag = { Insets = { Top = 7 } } } })
      decorated = {}
      styled = {}
      sonata:SetWindowDecorator(function(window, style, theme)
        table.insert(decorated, { window = window, style = style, theme = theme })
      end)
      sonata:SetElementStyler("SectionHeader", function(element, style, theme)
        table.insert(styled, { element = element, style = style, theme = theme })
      end)
    end)

    it("does not style anything before a theme is applied", function()
      sonata:RegisterWindow({}, "Bag")
      sonata:RegisterElement("SectionHeader", {})
      assert.are.equal(0, #decorated)
      assert.are.equal(0, #styled)
    end)

    it("decorates every registered window with its kind's style and saves the choice", function()
      local window = {}
      sonata:RegisterWindow(window, "Bag")

      sonata:ApplyTheme(context:New("test"), "Other")

      assert.are.equal(1, #decorated)
      assert.are.equal(window, decorated[1].window)
      assert.are.equal(7, decorated[1].style.Insets.Top)
      assert.are.equal("Other", decorated[1].theme.Name)
      assert.are.equal("Other", savedTheme)
      assert.are.equal("Other", sonata:GetCurrentThemeKey())
    end)

    it("styles every registered element", function()
      local font = {}
      sonata:RegisterElement("SectionHeader", font)
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(font, styled[1].element)
      assert.are.equal("GameFontNormal", styled[1].style.Font.Object)
    end)

    it("styles windows and elements registered after a theme was applied at once", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      local window = {}
      sonata:RegisterWindow(window, "Bag")
      sonata:RegisterElement("SectionHeader", {})
      assert.are.equal(window, decorated[#decorated].window)
      assert.are.equal(1, #styled)
    end)

    it("stops styling an element that was unregistered", function()
      local font = {}
      sonata:RegisterElement("SectionHeader", font)
      sonata:UnregisterElement("SectionHeader", font)
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(0, #styled)
    end)

    it("stops decorating a window that was unregistered", function()
      local window = {}
      sonata:RegisterWindow(window, "Bag")
      sonata:UnregisterWindow(window)
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(0, #decorated)
    end)

    it("decorates windows in the order they registered", function()
      local first, second = {}, {}
      sonata:RegisterWindow(first, "Bag")
      sonata:RegisterWindow(second, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(first, decorated[1].window)
      assert.are.equal(second, decorated[2].window)
    end)

    it("bumps the generation on every apply", function()
      local before = sonata:GetGeneration()
      sonata:ApplyTheme(context:New("test"), "Other")
      sonata:ApplyTheme(context:New("test"), "Default")
      assert.are.equal(before + 2, sonata:GetGeneration())
    end)

    it("redraws the bags and announces the change", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      local messages = {}
      for _, m in ipairs(sent) do messages[m.message] = m.args end
      assert.is_not_nil(messages["bags/Redraw"])
      assert.are.equal("Other", messages["sonata/ThemeChanged"][1])
    end)

    it("says a hidden theme is hidden", function()
      local ok, err = pcall(sonata.ApplyTheme, sonata, context:New("test"), "Base")
      assert.is_false(ok)
      assert.is_truthy(tostring(err):find("hidden"))
    end)

    it("errors on an unknown or unavailable theme", function()
      sonata:RegisterTheme({ Name = "Off", Available = false })
      assert.has_error(function() sonata:ApplyTheme(context:New("test"), "Nope") end)
      assert.has_error(function() sonata:ApplyTheme(context:New("test"), "Off") end)
    end)

    it("refuses to apply a hidden theme", function()
      assert.has_error(function() sonata:ApplyTheme(context:New("test"), "Base") end)
    end)

    it("reports a window that fails to decorate and decorates the rest", function()
      local reported
      sonata:SetWindowDecorator(function(window)
        if window.bad then error("bad window") end
        table.insert(decorated, { window = window })
      end)
      local good = {}
      sonata:RegisterWindow({ bad = true }, "Bag")
      sonata:RegisterWindow(good, "Bag")

      withHandler(function(err) reported = err end, function()
        sonata:ApplyTheme(context:New("test"), "Other")
      end)

      assert.is_truthy(tostring(reported):find("bad window"))
      assert.are.equal(good, decorated[1].window)
    end)

    it("decorates a window a decorator registers during an apply once", function()
      local child = {}
      local count = 0
      sonata:SetWindowDecorator(function(window)
        if window == child then count = count + 1 end
        if window.spawns then
          window.spawns = nil
          sonata:RegisterWindow(child, "Bag")
        end
      end)
      sonata:RegisterWindow({ spawns = true }, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(1, count)
    end)

    it("decorates every other window when one unregisters during an apply", function()
      local seen = {}
      local a, b, c = { name = "a" }, { name = "b" }, { name = "c" }
      sonata:SetWindowDecorator(function(window)
        table.insert(seen, window.name)
        if window == a then sonata:UnregisterWindow(a) end
      end)
      sonata:RegisterWindow(a, "Bag")
      sonata:RegisterWindow(b, "Bag")
      sonata:RegisterWindow(c, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.same({ "a", "b", "c" }, seen)
    end)

    it("styles every element once when a styler registers more during an apply", function()
      local counts = {}
      local originals = {}
      for i = 1, 5 do
        originals[i] = { id = i }
        sonata:RegisterElement("SectionHeader", originals[i])
      end
      sonata:SetElementStyler("SectionHeader", function(element)
        counts[element] = (counts[element] or 0) + 1
        if element.id then
          for _ = 1, 10 do sonata:RegisterElement("SectionHeader", {}) end
        end
      end)
      sonata:ApplyTheme(context:New("test"), "Other")
      for i = 1, 5 do
        assert.are.equal(1, counts[originals[i]])
      end
      for element, count in pairs(counts) do
        assert.are.equal(1, count, tostring(element))
      end
    end)

    it("styles an element a window decorator registers once", function()
      local font = {}
      local count = 0
      sonata:SetElementStyler("SectionHeader", function(element)
        if element == font then count = count + 1 end
      end)
      sonata:SetWindowDecorator(function()
        sonata:RegisterElement("SectionHeader", font)
      end)
      sonata:RegisterWindow({}, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(1, count)
    end)

    it("reports an element that fails to style and styles the rest", function()
      local reported
      local styledCount = 0
      sonata:SetElementStyler("SectionHeader", function(element)
        if element.bad then error("bad element") end
        styledCount = styledCount + 1
      end)
      sonata:RegisterElement("SectionHeader", { bad = true })
      sonata:RegisterElement("SectionHeader", {})
      withHandler(function(err) reported = err end, function()
        sonata:ApplyTheme(context:New("test"), "Other")
      end)
      assert.is_truthy(tostring(reported):find("bad element"))
      assert.are.equal(1, styledCount)
    end)

    it("rejects a window registered twice, and takes it back after it unregistered", function()
      local window = {}
      sonata:RegisterWindow(window, "Bag")
      assert.has_error(function() sonata:RegisterWindow(window, "Bag") end)
      sonata:UnregisterWindow(window)
      sonata:RegisterWindow(window, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(window, decorated[1].window)
    end)

    it("keeps the order of the other windows when a middle one unregisters", function()
      local a, b, c = {}, {}, {}
      sonata:RegisterWindow(a, "Bag")
      sonata:RegisterWindow(b, "Bag")
      sonata:RegisterWindow(c, "Bag")
      sonata:UnregisterWindow(b)
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(a, decorated[1].window)
      assert.are.equal(c, decorated[2].window)
      assert.are.equal(2, #decorated)
    end)

    it("styles an element registered twice only once", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      local font = {}
      sonata:RegisterElement("SectionHeader", font)
      sonata:RegisterElement("SectionHeader", font)
      assert.are.equal(1, #styled)
    end)

    it("reuses the resolved theme until the next apply", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      local calls = 0
      local originalResolve = sonata.Resolve
      sonata.Resolve = function(...) calls = calls + 1 return originalResolve(...) end
      local first = sonata:GetCurrentTheme()
      local second = sonata:GetCurrentTheme()
      sonata:GetElementStyle("SectionHeader")
      sonata.Resolve = originalResolve
      assert.are.equal(first, second)
      assert.are.equal(0, calls)
    end)

    it("announces the theme before asking for the redraw", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal("sonata/ThemeChanged", sent[1].message)
      assert.are.equal("bags/Redraw", sent[2].message)
    end)

    it("changes nothing when the theme fails to resolve", function()
      sonata:RegisterTheme({ Name = "Broken", Windows = { Bag = { Title = { Color = "$Nope" } } } })
      local before = sonata:GetGeneration()
      assert.has_error(function() sonata:ApplyTheme(context:New("test"), "Broken") end)
      assert.are.equal(before, sonata:GetGeneration())
      assert.are.equal("Default", savedTheme)
      assert.are.equal(0, #sent)
      assert.is_nil(sonata:GetCurrentThemeKey())
    end)

    it("redecorates windows with the current theme without saving or redrawing", function()
      local a, b = {}, {}
      sonata:RegisterWindow(a, "Bag")
      sonata:RegisterWindow(b, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      local generation = sonata:GetGeneration()
      savedTheme = "Changed"
      for k in pairs(sent) do sent[k] = nil end
      for k in pairs(decorated) do decorated[k] = nil end

      sonata:Redecorate(b)
      assert.are.equal(1, #decorated)
      assert.are.equal(b, decorated[1].window)
      sonata:Redecorate()
      assert.are.equal(3, #decorated)

      assert.are.equal(generation, sonata:GetGeneration())
      assert.are.equal("Changed", savedTheme)
      assert.are.equal(0, #sent)
    end)

    it("keeps what the decorator returned for each window", function()
      local window = {}
      sonata:SetWindowDecorator(function() return "the decoration" end)
      sonata:RegisterWindow(window, "Bag")
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal("the decoration", sonata:GetDecoration(window))
    end)

    it("decorates and styles what is registered when a decorator or styler arrives late", function()
      sonata:SetWindowDecorator(nil)
      sonata:SetElementStyler("SectionHeader", nil)
      local window, font = {}, {}
      sonata:RegisterWindow(window, "Bag")
      sonata:RegisterElement("SectionHeader", font)
      sonata:ApplyTheme(context:New("test"), "Other")
      local lateWindows, lateElements = {}, {}
      sonata:SetWindowDecorator(function(w) table.insert(lateWindows, w) end)
      sonata:SetElementStyler("SectionHeader", function(e) table.insert(lateElements, e) end)
      assert.are.same({ window }, lateWindows)
      assert.are.same({ font }, lateElements)
    end)

    it("hands out one shared empty style for a kind the theme does not style", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(sonata:GetWindowStyle("Nope"), sonata:GetWindowStyle("Other"))
      assert.are.equal(sonata:GetElementStyle("Nope"), sonata:GetWindowStyle("Nope"))
      assert.is_nil(next(sonata:GetElementStyle("Nope")))
    end)

    it("hands the current theme's styles to draw code", function()
      sonata:ApplyTheme(context:New("test"), "Other")
      assert.are.equal(7, sonata:GetWindowStyle("Bag").Insets.Top)
      assert.are.equal("GameFontNormal", sonata:GetElementStyle("SectionHeader").Font.Object)
      assert.are.equal("Other", sonata:GetCurrentTheme().Name)
    end)
  end)

  describe("enabling", function()
    before_each(function()
      sonata:RegisterTheme(base())
      sonata:RegisterTheme({ Name = "Default" })
      sonata:RegisterTheme({ Name = "Other" })
      sonata:RegisterTheme({ Name = "Off", Available = false })
    end)

    it("applies the saved theme", function()
      savedTheme = "Other"
      sonata:OnEnable()
      assert.are.equal("Other", sonata:GetCurrentThemeKey())
    end)

    it("falls back to Default for a saved theme that is missing or unavailable, keeping the choice", function()
      savedTheme = "Missing"
      sonata:OnEnable()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      assert.are.equal("Missing", savedTheme)
      savedTheme = "Off"
      sonata:OnEnable()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
      assert.are.equal("Off", savedTheme)
    end)

    it("falls back to Default for a saved theme that is hidden", function()
      savedTheme = "Base"
      sonata:OnEnable()
      assert.are.equal("Default", sonata:GetCurrentThemeKey())
    end)

    it("resolves the saved theme before any theme was applied, falling back to Default", function()
      savedTheme = "Other"
      assert.are.equal("Other", sonata:GetCurrentTheme().Name)
      savedTheme = "Missing"
      assert.are.equal("Default", sonata:GetCurrentTheme().Name)
    end)

    it("uses Masque unless the theme opts out", function()
      sonata:RegisterTheme({ Name = "NoMasque", Masque = false })
      savedTheme = "Other"
      assert.is_true(sonata:UsesMasque())
      savedTheme = "NoMasque"
      assert.is_false(sonata:UsesMasque())
    end)
  end)
end)
