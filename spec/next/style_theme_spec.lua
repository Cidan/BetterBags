-- style_theme_spec.lua -- NextStyle (next/style.lua) as a view of the current Next theme
-- (.claude/rules/next-themes.md): the Default theme is BetterBags Next's design as it was before
-- themes (v0.7.0, frozen in spec/fixtures/next_style_v0_7_0.lua), and every theme application makes
-- new font objects and moves text to them (asked: "don't re-use text objects across themes, make
-- whole new ones").
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end
local db = trackStub("Database")
db.GetNextTheme = function() return "Default" end

FreshNextThemes()
ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
ResetModuleStub("NextStyleV070", "spec/fixtures/next_style_v0_7_0.lua")
LoadBetterBagsModule("spec/fixtures/next_style_v0_7_0.lua")

local sonataNext = addon:GetModule("SonataNext")
local style = addon:GetModule("NextStyle")
local old = addon:GetModule("NextStyleV070")

describe("NextStyle", function()
  local function resolved(key)
    return sonataNext:Resolve(key)
  end

  after_each(function()
    sonataNext.themes.Spec = nil
    style:Use(resolved("Default"))
  end)

  teardown(function()
    ResetModuleStub("NextStyleV070")
    ResetModuleStub("NextStyle")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
    FreshNextThemes()
  end)

  -- Asked: "the current design should be the default".
  describe("the Default theme", function()
    it("is BetterBags Next's design as it was before themes, value for value", function()
      style:Use(resolved("Default"))
      local fields = {
        -- VENDOR_PRICE (the room under a vendor icon for its price) went with the vendor's cards
        -- (asked: prices too small to read), below.
        "ICON", "GAP", "PER_ROW", "GUTTER", "PAD", "GRID_WIDTH", "BODY_WIDTH", "FEATHER",
        "WIDTH", "OPEN_OVERSHOOT", "OVERREACH", "TITLE_TOP", "SEARCH_TOP", "SEARCH_HEIGHT", "SEARCH_ICON",
        "SEARCH_GAP", "SearchEdge", "SearchIcon", "CONTENT_TOP", "FOOTER", "SECTION_HEADER",
        "SECTION_SPACING", "TAB_HEIGHT", "TAB_SPACING", "TAB_MIN_WIDTH", "TAB_MAX_WIDTH", "TAB_PADDING",
        "TAB_HOVER", "TAB_ICON", "TAB_ICON_GAP", "TAB_GROUP_GAP", "Color", "Time", "RISE", "Small",
        "SPARKLE_TEXTURE", "RIBBON_LENGTH", "Chain", "Cloud", "CLOUD_GLOW",
      }
      -- Every value v0.7.0 had is the same; a table may hold more now (new palette colors, theme keys).
      local function contains(a, b, path)
        if type(a) ~= "table" or a[1] ~= nil then
          assert.are.same(a, b, path)
          return
        end
        assert.are.equal("table", type(b), path)
        for k, v in pairs(a) do
          contains(v, b[k], path .. "." .. tostring(k))
        end
      end
      for _, field in ipairs(fields) do
        contains(old[field], style[field], field)
      end
    end)

    it("draws every font as it was", function()
      style:Use(resolved("Default"))
      for _, name in ipairs({ "Title", "Section", "SectionRecent", "SectionFree", "Count", "Tab", "TabSelected",
        "Footer", "ConfirmTitle", "ConfirmWarning", "ConfirmHint", "Search", "SearchText" }) do
        local a, b = old:Font(name), style:Font(name)
        assert.are.same({ a:GetFont() }, { b:GetFont() }, name)
        assert.are.same({ a:GetTextColor() }, { b:GetTextColor() }, name)
        assert.are.same({ a:GetShadowColor() }, { b:GetShadowColor() }, name)
        assert.are.same({ a:GetShadowOffset() }, { b:GetShadowOffset() }, name)
      end
    end)

    -- Roles that used another role's font before themes split off, drawn the same.
    it("draws the roles split off from others as those were", function()
      style:Use(resolved("Default"))
      for role, was in pairs({ Empty = "Footer", DragHint = "TabSelected" }) do
        assert.are.same({ old:Font(was):GetFont() }, { style:Font(role):GetFont() }, role)
        assert.are.same({ old:Font(was):GetShadowOffset() }, { style:Font(role):GetShadowOffset() }, role)
      end
      assert.are.same({ 1, 0.25, 0.25, 1 }, { style:Font("PriceUnaffordable"):GetTextColor() })
    end)

    -- Changed since v0.7.0 on purpose (asked: "the count for items in vendor, that font size should match
    -- our item count in bags"): the vendor's stack counts in the bags' count font.
    it("writes vendor stack counts in the bags' item count font, NumberFontNormal", function()
      style:Use(resolved("Default"))
      local font = style:Font("Stack")
      assert.are.same({ NumberFontNormal:GetFont() }, { font:GetFont() })
      assert.are.same({ NumberFontNormal:GetTextColor() }, { font:GetTextColor() })
      assert.are.same({ NumberFontNormal:GetShadowOffset() }, { font:GetShadowOffset() })
    end)

    -- Changed since v0.7.0 on purpose (asked: a user found vendor prices too small to read; then cards
    -- as GW2_UI draws the merchant): each vendor item a card, its name and price beside its icon, in
    -- larger fonts; what cannot be afforded in the price's font, red.
    it("draws vendor items as cards, their prices larger than v0.7.0", function()
      style:Use(resolved("Default"))
      local _, oldSize = old:Font("Price"):GetFont()
      local file, size, flags = style:Font("Price"):GetFont()
      assert.is_true(size > oldSize, "larger than " .. oldSize)
      assert.are.same({ old:Font("Price"):GetTextColor() }, { style:Font("Price"):GetTextColor() })
      assert.are.same({ old:Font("Price"):GetShadowOffset() }, { style:Font("Price"):GetShadowOffset() })
      assert.are.same({ file, size, flags }, { style:Font("PriceUnaffordable"):GetFont() })
      assert.is_nil(style.VENDOR_PRICE)
      assert.are.equal(2, style.VENDOR_COLUMNS)
      assert.are.equal(math.floor((style.GRID_WIDTH - style.GAP) / 2), style.VENDOR_CARD_WIDTH)
      -- Two lines of its name and a line of its price, raised off the card's edge, fit beside the icon.
      local _, nameSize = style:Font(style.Theme.Vendor.NameFont):GetFont()
      assert.is_true(nameSize >= size)
      assert.is_true(2 * nameSize + size + style.VENDOR_PRICE_RAISE <= style.ICON)
    end)
  end)

  describe("another theme", function()
    local function register(theme)
      theme.Name = "Spec"
      sonataNext:RegisterTheme(theme)
      return resolved("Spec")
    end

    -- A role can copy one of the client's fonts (Object: its file, size and flags, in every locale,
    -- its color and shadow), changing only what the role also sets.
    it("copies a client font for a role that names one, changing only what the role sets", function()
      style:Use(register({ Palette = { Ruby = { 1, 0, 0, 1 } },
        Fonts = { Plain = { Object = "NumberFontNormal" }, Shadowed = { Object = "GameFontNormal" },
          Bigger = { Object = "NumberFontNormal", Size = 18, Color = "Ruby", Shadow = true } } }))
      local plain, bigger = style:Font("Plain"), style:Font("Bigger")
      assert.are.same({ NumberFontNormal:GetFont() }, { plain:GetFont() })
      assert.are.same({ NumberFontNormal:GetTextColor() }, { plain:GetTextColor() })
      assert.are.same({ NumberFontNormal:GetShadowOffset() }, { plain:GetShadowOffset() })
      assert.are.same({ GameFontNormal:GetShadowOffset() }, { style:Font("Shadowed"):GetShadowOffset() },
        "the client font's own shadow kept")
      assert.are.same({ GameFontNormal:GetShadowColor() }, { style:Font("Shadowed"):GetShadowColor() })
      local path, _, flags = NumberFontNormal:GetFont()
      assert.are.same({ path, 18, flags }, { bigger:GetFont() })
      assert.are.same({ 1, 0, 0, 1 }, { bigger:GetTextColor() })
      assert.are.same({ style.Theme.FontShadow.X or 0, style.Theme.FontShadow.Y or 0 }, { bigger:GetShadowOffset() })
      sonataNext.themes.Spec = nil
      style:Use(register({ Fonts = { Odd = { Object = "NoSuchFont" } } }))
      assert.has_error(function() style:Font("Odd") end, "BetterBags Next's font role Odd copies no client font named NoSuchFont")
    end)

    -- The Plain theme (docs/next-plain-theme.md) draws the client's own fonts as they are: a role that copies one
    -- outright (Copy) takes nothing from the role it inherits (Default's Size, Color and Shadow), only its own Justify.
    it("copies a client font outright for a role that says Copy, whatever the role it inherits sets", function()
      style:Use(register({ Fonts = { Price = { Copy = "GameFontHighlightSmall" }, Tab = { Copy = "GameFontNormal", Justify = "RIGHT" } } }))
      local price = style:Font("Price")
      assert.are.same({ GameFontHighlightSmall:GetFont() }, { price:GetFont() })
      assert.are.same({ GameFontHighlightSmall:GetTextColor() }, { price:GetTextColor() })
      assert.are.same({ GameFontHighlightSmall:GetShadowOffset() }, { price:GetShadowOffset() })
      assert.are.same({ GameFontHighlightSmall:GetShadowColor() }, { price:GetShadowColor() })
      assert.are.equal("RIGHT", style:Font("Tab"):GetJustifyH())
      sonataNext.themes.Spec = nil
      style:Use(register({ Fonts = { Odd = { Copy = "NoSuchFont" } } }))
      assert.has_error(function() style:Font("Odd") end, "BetterBags Next's font role Odd copies no client font named NoSuchFont")
    end)

    it("lays everything out from its own sizes, the reach past the screen edge from its open ease", function()
      style:Use(register({ Layout = { Icon = 36, Gap = 4, PerRow = 9, Pad = 10, Feather = 64 },
        Motion = { Ease = { Open = "outBackSoft" } } }))
      assert.are.equal(9 * 36 + 8 * 4, style.GRID_WIDTH)
      assert.are.equal(style.GRID_WIDTH + style.GUTTER + 2 * 10, style.BODY_WIDTH)
      assert.are.equal(64 + style.BODY_WIDTH, style.WIDTH)
      assert.are.equal(0.02, style.OPEN_OVERSHOOT)
      assert.are.equal(math.ceil(style.WIDTH * 0.02 / 0.98) + 4, style.OVERREACH)
      assert.are.equal("outBackSoft", style:Ease("Open"))
    end)

    it("reaches no further past the screen edge than it needs with an open ease that does not overshoot", function()
      style:Use(register({ Motion = { Ease = { Open = "outCubic" } } }))
      assert.are.equal(0, style.OPEN_OVERSHOOT)
      assert.are.equal(4, style.OVERREACH)
    end)

    it("names its colors by the palette or gives them outright, with an alpha", function()
      style:Use(register({ Palette = { Gold = { 0.9, 0.5, 0.1, 1 } } }))
      assert.are.same({ 0.9, 0.5, 0.1, 1 }, { style:RGBA("Gold") })
      assert.are.same({ 0.9, 0.5, 0.1, 0.4 }, { style:RGBA("Gold", 0.4) })
      assert.are.same({ 0.2, 0.3, 0.4, 1 }, { style:RGBA({ 0.2, 0.3, 0.4 }) })
      assert.are.same({ 0.9, 0.5, 0.1, 1 }, style.Color.Gold)
      assert.has_error(function() style:RGBA("NoSuchColor") end)
    end)

    -- The Plain theme (docs/next-plain-theme.md) draws in the client's own colors: Color.lua (Blizzard_SharedXMLBase,
    -- every client) makes each named UI color a Lua global. A palette entry naming one is its color when the theme
    -- applies, its alpha replaced by the entry's Alpha.
    it("takes a palette color from one of the client's named colors, read when the theme applies", function()
      local was = _G.PANEL_BACKGROUND_COLOR
      _G.PANEL_BACKGROUND_COLOR = CreateColor(0.1, 0.2, 0.3, 0.9)
      local theme = register({ Palette = { Panel = { Global = "PANEL_BACKGROUND_COLOR" },
        Faint = { Global = "PANEL_BACKGROUND_COLOR", Alpha = 0.5 } } })
      style:Use(theme)
      assert.are.same({ 0.1, 0.2, 0.3, 0.9 }, { style:RGBA("Panel") })
      assert.are.same({ 0.1, 0.2, 0.3, 0.5 }, { style:RGBA("Faint") })
      assert.are.same({ Global = "PANEL_BACKGROUND_COLOR" }, theme.Palette.Panel, "the theme itself unchanged")
      -- Read again by the next application: the client can change its colors.
      _G.PANEL_BACKGROUND_COLOR = CreateColor(0.4, 0.5, 0.6, nil)
      style:Use(theme)
      assert.are.same({ 0.4, 0.5, 0.6, 1 }, { style:RGBA("Panel") }, "no alpha is a whole one")
      _G.PANEL_BACKGROUND_COLOR = was
      sonataNext.themes.Spec = nil
      local broken = register({ Palette = { Gone = { Global = "NO_SUCH_COLOR" } } })
      assert.has_error(function() style:Use(broken) end,
        "the Next theme's color Gone names no client color NO_SUCH_COLOR")
    end)
  end)

  -- Asked: "take care with text! remember our lessons from before (don't re-use text objects across
  -- themes, make whole new ones)" (sonata.md 3c).
  -- BetterBags Next, pixel perfect (docs/next-pixel-perfect.md): a font's height is a whole number of
  -- screen pixels for the screen and UI scale its text is drawn at.
  describe("on the screen's pixels", function()
    local layout = dofile("spec/helpers/layout.lua")
    local undo

    before_each(function()
      -- The reporter's window (Logs/gx.log: 3396x1362, maximized) at the game's UI scale of 65%.
      undo = layout.UseScreen(3396, 1362, 0.65)
    end)

    after_each(function()
      undo()
    end)

    local function pixels(font)
      local _, size = font:GetFont()
      return size * layout.PixelsPerUnit() * UIParent:GetEffectiveScale()
    end

    local function whole(value)
      return math.abs(value - math.floor(value + 0.5)) < 1e-6
    end

    it("draws every role of every shipped theme at a whole number of pixels, the nearest", function()
      for _, key in ipairs({ "Default", "Ember", "Parchment", "Quiet" }) do
        local theme = resolved(key)
        style:Use(theme)
        for role, spec in pairs(theme.Fonts) do
          local font = style:Font(role)
          assert.is_true(whole(pixels(font)), key .. " " .. role .. ": " .. pixels(font))
          if spec.Size ~= nil then
            local want = math.floor(spec.Size * layout.PixelsPerUnit() * 0.65 + 0.5)
            assert.are.equal(want, math.floor(pixels(font) + 0.5), key .. " " .. role)
          end
        end
      end
    end)

    it("rounds a copied client font's own height too, keeping its file and flags", function()
      local theme = resolved("Default")
      theme.Fonts.Plain = { Object = "NumberFontNormal" }
      style:Use(theme)
      local path, size, flags = NumberFontNormal:GetFont()
      local file, height, f = style:Font("Plain"):GetFont()
      assert.are.same({ path, flags }, { file, f })
      assert.is_true(whole(pixels(style:Font("Plain"))))
      assert.is_true(math.abs(height - size) * layout.PixelsPerUnit() * 0.65 <= 0.5 + 1e-9)
    end)

    it("draws a font as the theme says where a UI unit is a whole pixel", function()
      undo()
      undo = layout.UseScreen(1536, 768, 1)
      style:Use(resolved("Default"))
      local _, size = style:Font("Title"):GetFont()
      assert.are.equal(resolved("Default").Fonts.Title.Size, size)
    end)
  end)

  describe("text", function()
    it("moves text to a new font object with every theme, never changing one it made", function()
      local parent = CreateFrame("Frame")
      local title = style:CreateText(parent, "Title")
      local before = title:GetFontObject()
      assert.are.equal(style:Font("Title"), before)
      sonataNext:RegisterTheme({ Name = "Spec", Fonts = { Title = { Size = 30, Color = "Gold" } } })
      style:Use(resolved("Spec"))
      local after = title:GetFontObject()
      assert.are_not.equal(before, after)
      assert.are.equal(30, select(2, after:GetFont()))
      assert.are.equal(26, select(2, before:GetFont()), "the old font object is untouched")
      assert.are.same({ 1, 1, 1, 1 }, { before:GetTextColor() })
    end)

    it("makes new font objects even when the theme applied again is the same", function()
      local text = style:CreateText(CreateFrame("Frame"), "Section")
      local before = text:GetFontObject()
      style:Use(resolved("Default"))
      assert.are_not.equal(before, text:GetFontObject())
    end)

    it("moves edit boxes and text switched between roles too, by the role they have now", function()
      local box = CreateFrame("EditBox")
      style:SetFont(box, "SearchText")
      local tab = style:CreateText(CreateFrame("Frame"), "Tab")
      style:SetFont(tab, "TabSelected")
      style:Use(resolved("Default"))
      assert.are.equal(style:Font("SearchText"), box:GetFontObject())
      assert.are.equal(style:Font("TabSelected"), tab:GetFontObject())
    end)

    it("names every font object it makes uniquely, after its role", function()
      local a = style:Font("Count")
      style:Use(resolved("Default"))
      local b = style:Font("Count")
      assert.are_not.equal(a:GetName(), b:GetName())
      assert.is_truthy(a:GetName():find("BetterBagsNextFontCount", 1, true))
    end)

    -- A theme may add roles of its own; text left on one keeps its font object until its widget
    -- restyles it with the next theme's roles.
    it("leaves text on a role the next theme lacks on its font object", function()
      sonataNext:RegisterTheme({ Name = "Spec", Fonts = { Mine = { Size = 9 } } })
      style:Use(resolved("Spec"))
      local text = style:CreateText(CreateFrame("Frame"), "Mine")
      local mine = text:GetFontObject()
      style:Use(resolved("Default"))
      assert.are.equal(mine, text:GetFontObject())
      style:SetFont(text, "Count")
      assert.are.equal(style:Font("Count"), text:GetFontObject())
    end)

    -- A Blizzard template colors its own text; such text takes its role's color too, with every theme,
    -- with nothing else restyling it.
    it("colors text a template colors by its role, with every theme", function()
      local text = CreateFrame("Frame"):CreateFontString(nil, "OVERLAY")
      text:SetTextColor(0.35, 0.35, 0.35, 1)
      style:SetTemplateFont(text, "Search")
      assert.are.same({ style:Font("Search"):GetTextColor() }, { text:GetTextColor() })
      sonataNext:RegisterTheme({ Name = "Spec", Fonts = { Search = { Color = "Gold" } } })
      style:Use(resolved("Spec"))
      assert.are.same({ 1, 0.84, 0.5, 1 }, { text:GetTextColor() })
    end)

    it("refuses a role no theme defines", function()
      assert.has_error(function() style:Font("NoSuchRole") end)
    end)
  end)

  -- UI addons rewrite the client's fonts once the game has loaded (GW2_UI at PLAYER_LOGIN, docs/next-gw2-theme.md),
  -- after BetterBags made its copies of them: a copy is stale once what it copied changed.
  describe("copies of the client's fonts", function()
    local client

    before_each(function()
      client = CreateFont("SpecClientFont")
      client:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
      client:SetTextColor(1, 1, 1, 1)
      sonataNext:RegisterTheme({ Name = "Spec", Fonts = { Copy = { Object = "SpecClientFont", Size = 14 },
        Unused = { Object = "SpecClientFont" } } })
      style:Use(resolved("Spec"))
    end)

    after_each(function()
      _G.SpecClientFont = nil
    end)

    it("says none is stale while what each copied is unchanged", function()
      style:Font("Copy")
      assert.is_false(style:CopiesStale())
    end)

    it("says one is stale once its client font's file, size, flags, color or shadow changed", function()
      local changes = {
        function() client:SetFont("Interface\\AddOns\\GW2_UI\\fonts\\menomonia.ttf", 12, "") end,
        function() client:SetFont("Fonts\\FRIZQT__.TTF", 13, "") end,
        function() client:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") end,
        function() client:SetTextColor(1, 0.9, 0.8, 1) end,
        function() client:SetShadowColor(0, 0, 0, 1) end,
        function() client:SetShadowOffset(1, -1) end,
      }
      for i, change in ipairs(changes) do
        client:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        client:SetTextColor(1, 1, 1, 1)
        client:SetShadowColor(0, 0, 0, 0)
        client:SetShadowOffset(0, 0)
        style:Use(resolved("Spec"))
        style:Font("Copy")
        assert.is_false(style:CopiesStale(), i)
        change()
        assert.is_true(style:CopiesStale(), i)
      end
    end)

    it("checks only copies it made, and none once a theme makes new ones", function()
      client:SetFont("Interface\\AddOns\\GW2_UI\\fonts\\menomonia.ttf", 12, "")
      assert.is_false(style:CopiesStale(), "no role made yet")
      style:Font("Copy")
      client:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
      assert.is_true(style:CopiesStale())
      style:Use(resolved("Spec"))
      assert.is_false(style:CopiesStale())
      style:Font("Copy")
      assert.are.same({ "Fonts\\FRIZQT__.TTF", 14, "" }, { style:Font("Copy"):GetFont() }, "the new copy is of the font now")
    end)
  end)
end)
