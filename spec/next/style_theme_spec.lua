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
        "ICON", "VENDOR_PRICE", "GAP", "PER_ROW", "GUTTER", "PAD", "GRID_WIDTH", "BODY_WIDTH", "FEATHER",
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
        "Footer", "ConfirmTitle", "ConfirmWarning", "ConfirmHint", "Search", "SearchText", "Price", "Stack" }) do
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
      for role, was in pairs({ Empty = "Footer", DragHint = "TabSelected", PriceUnaffordable = "Price" }) do
        assert.are.same({ old:Font(was):GetFont() }, { style:Font(role):GetFont() }, role)
        assert.are.same({ old:Font(was):GetShadowOffset() }, { style:Font(role):GetShadowOffset() }, role)
      end
      assert.are.same({ 1, 0.25, 0.25, 1 }, { style:Font("PriceUnaffordable"):GetTextColor() })
    end)
  end)

  describe("another theme", function()
    local function register(theme)
      theme.Name = "Spec"
      sonataNext:RegisterTheme(theme)
      return resolved("Spec")
    end

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
  end)

  -- Asked: "take care with text! remember our lessons from before (don't re-use text objects across
  -- themes, make whole new ones)" (sonata.md 3c).
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

    it("refuses a role no theme defines", function()
      assert.has_error(function() style:Font("NoSuchRole") end)
    end)
  end)
end)
