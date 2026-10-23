-- next_themes_spec.lua -- BetterBags Next's shipped themes (sonata/themes/next/*.lua,
-- next-themes.md): every one is data, resolves on every client, and names nothing it does not define
-- (SonataNext:Check); and each looks the way it says.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

if addon:GetModule("NextTween", true) == nil then
  ResetModuleStub("NextTween", "next/tween.lua")
  LoadBetterBagsModule("next/tween.lua")
end

local FLAGS = { "isRetail", "isForever", "isClassic", "isBCC", "isMists", "isAnniversary", "isCata" }
-- Every client SonataResolve knows, by the flags that pick its override keys.
local CLIENTS = {
  Retail = { isRetail = true },
  Forever = { isRetail = true, isForever = true },
  Era = { isClassic = true },
  TBC = { isBCC = true },
  Anniversary = { isAnniversary = true, isBCC = true },
  Mists = { isMists = true },
  Cata = { isCata = true },
}

describe("BetterBags Next's shipped themes", function()
  local sonataNext, saved

  before_each(function()
    sonataNext = FreshNextThemes()
    saved = {}
    for _, flag in ipairs(FLAGS) do saved[flag] = addon[flag] end
  end)

  after_each(function()
    for _, flag in ipairs(FLAGS) do addon[flag] = saved[flag] end
  end)

  teardown(function()
    FreshNextThemes()
  end)

  local function shipped()
    local keys = {}
    for key in pairs(sonataNext:GetThemes()) do table.insert(keys, key) end
    table.sort(keys)
    return keys
  end

  it("ships Default and at least three others", function()
    assert.are.same({ "Default", "Ember", "Parchment", "Quiet" }, shipped())
  end)

  it("resolves every one on every client and finds nothing it does not define", function()
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(shipped()) do
        local theme = sonataNext:Resolve(key)
        assert.are.equal(key, theme.Name, client)
        assert.is_true(theme.DisplayName ~= "" and theme.Description ~= "", key .. " describes itself")
        assert.are.same({}, sonataNext:Check(key), key .. " on " .. client)
      end
    end
  end)

  -- Every header button's glyph (next-themes.md §3, tools/textures/next_icons.py): one per key, each
  -- its own file, shipped with BetterBags as a 64 x 64 PNG with an alpha channel (the shape is in the
  -- alpha, white, so the theme tints it).
  it("names a glyph BetterBags ships for every header button in Default", function()
    local theme = sonataNext:Resolve("Default")
    local icons = theme.Header.Buttons.Icons
    local keys = { "settingsButton", "closeButton", "sortButton", "bagsButton", "sizeButtonFull",
      "sizeButtonSmall", "bankTabsButton", "depositButton", "depositGoldButton", "withdrawGoldButton",
      "filterButton", "sellJunkButton", "repairAllButton", "guildRepairButton" }
    local files = {}
    for _, key in ipairs(keys) do
      local spec = icons[key]
      assert.is_not_nil(spec, key)
      assert.is_nil(spec.Atlas, key)
      assert.is_not_false(spec.Glyph, key)
      local path = theme.Textures[spec.Texture]
      assert.is_not_nil(path, key .. " names one of the theme's textures")
      assert.is_nil(files[path], key .. " has a file of its own")
      files[path] = true
      local file = path:gsub("^Interface\\AddOns\\BetterBags\\", ""):gsub("\\", "/")
      local f = io.open(file, "rb")
      assert.is_not_nil(f, file)
      local data = f:read("*a")
      f:close()
      assert.are.equal("\137PNG\r\n\26\n", data:sub(1, 8), file)
      local function u32(i)
        local a, b, c, d = data:byte(i, i + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
      end
      assert.are.same({ 64, 64, 8, 6 }, { u32(17), u32(21), data:byte(25), data:byte(26) }, file .. ": 64 x 64 RGBA")
    end
    local count = 0
    for _ in pairs(icons) do count = count + 1 end
    assert.are.equal(#keys, count, "and nothing else")
  end)

  -- The vendor's cards (next.md §10b): two lines of an item's name and a line of its price (raised off
  -- the card's edge) fit beside its icon, the coins no taller than the price, in every theme on every
  -- client.
  it("fits a vendor card's name and price beside its icon", function()
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(shipped()) do
        local t = sonataNext:Resolve(key)
        local L, V = t.Layout, t.Vendor
        local name = t.Fonts[V.NameFont].Size
        for _, role in ipairs({ V.PriceFont, V.UnaffordableFont }) do
          local size = t.Fonts[role].Size
          assert.is_true(2 * name + size + L.VendorPriceRaise <= L.Icon, key .. " " .. role .. " on " .. client)
          assert.is_true(V.CoinSize <= size + 1, key .. " coins no taller than the price")
        end
        assert.is_true(L.VendorColumns >= 1, key)
      end
    end
  end)

  it("needs no other addon", function()
    for _, key in ipairs(shipped()) do
      assert.is_true(sonataNext:IsSelectable(key), key)
    end
  end)

  describe("Ember", function()
    it("is warm: amber and ember colors, its sparkles rising like embers", function()
      local t = sonataNext:Resolve("Ember")
      assert.is_true(t.Palette.Body[1] > t.Palette.Body[3], "a red-brown body")
      assert.are.same({ "Gold", "Ember", "White" }, t.Sparkles.Colors)
      assert.is_true(t.Sparkles.Ribbon.Rise[1] > 0, "its ribbon's sparkles rise")
      assert.is_true(t.Sparkles.Edge.Rise[1] > 0, "its edge sparkles rise")
    end)
  end)

  -- The settings window and its controls (next-settings.md §6) take each theme's look: Default's are
  -- indigo, which on another theme's body would be a patch of the wrong color.
  local function warm(c) return c[1] > c[3] + 0.05 end
  local function cool(c) return c[3] >= c[1] and (math.max(c[1], c[2], c[3]) - math.min(c[1], c[2], c[3])) < 0.1 end

  describe("Ember's settings and controls", function()
    it("are charcoal and amber, with a danger red apart from its amber", function()
      local t = sonataNext:Resolve("Ember")
      for _, name in ipairs({ "ControlFill", "ControlHover", "ControlPressed", "Track" }) do
        assert.is_true(warm(t.Palette[name]), name)
      end
      assert.is_true(t.Palette.ControlHover[1] > t.Palette.ControlFill[1], "lighter under the pointer")
      assert.is_true(t.Palette.ControlPressed[1] < t.Palette.ControlFill[1], "darker when pressed")
      assert.is_true(t.Palette.Gold[2] - t.Palette.Danger[2] > 0.2, "danger is redder than amber")
    end)
  end)

  describe("Quiet's settings and controls", function()
    it("are cool grays, its settings' titles smaller and its controls' motion quicker", function()
      local t = sonataNext:Resolve("Quiet")
      local default = sonataNext:Resolve("Default")
      for _, name in ipairs({ "ControlFill", "ControlHover", "ControlPressed", "Track" }) do
        assert.is_true(cool(t.Palette[name]), name)
      end
      assert.is_true(t.Fonts.SettingsTitle.Size < default.Fonts.SettingsTitle.Size)
      assert.is_true(t.Fonts.SettingsBrand.Size < default.Fonts.SettingsBrand.Size)
      assert.is_true(t.Motion.Time.Toggle < default.Motion.Time.Toggle)
      assert.is_true(t.Motion.Time.TabMarker < default.Motion.Time.TabMarker)
    end)
  end)

  describe("Parchment's settings and controls", function()
    it("are paper and ink: the window on the paper art, dark text, sealing wax for the accents", function()
      local t = sonataNext:Resolve("Parchment")
      assert.are.equal("Paper", t.Settings.Fill.Texture)
      assert.is_nil(t.Settings.Wash, "no light washed over the paper")
      assert.are.equal("Paper", t.Controls.Menu.Fill.Texture, "a menu is a slip of paper")
      assert.are.equal("Paper", t.Controls.Dialog.Card.Texture)
      for _, role in ipairs({ "SettingsBrand", "SettingsNav", "SettingsNavHover", "SettingsNavSelected",
        "SettingsTitle", "SettingsDescription", "SettingsSection", "SettingsLabel", "SettingsText", "SettingsVersion",
        "ControlText", "ControlHelp", "Button", "MenuItem", "TopTab", "TopTabHover", "TopTabSelected", "DialogTitle",
        "DialogText", "Link" }) do
        local c = t.Palette[t.Fonts[role].Color]
        assert.is_true(c[1] < 0.5 and c[2] < 0.5 and c[3] < 0.5, role .. " is ink")
      end
      for _, accent in ipairs({ t.Settings.Nav.Indicator, t.Settings.Brand, t.Controls.TopTabs.Indicator,
        t.Controls.Toggle.On, t.Settings.Categories.Indicator }) do
        assert.are.equal("Seal", accent.Color or accent.IconColor)
      end
      assert.are.same({ 172 / 255, 3 / 255, 3 / 255, 1 }, t.Palette.Danger, "Blizzard's parchment red")
      assert.are.equal("Ink", t.Controls.ScrollBar.Thumb.Color)
    end)
  end)

  describe("Parchment", function()
    it("is paper: art for its body and cards, dark ink with no shadow, no glowing effects", function()
      local t = sonataNext:Resolve("Parchment")
      assert.are.equal("Paper", t.Panel.Fill.Texture)
      assert.are.equal("Interface\\AddOns\\BetterBags\\textures\\moonlight\\parchment.png", t.Textures.Paper)
      assert.are.equal("Paper", t.Dock.Card.Texture)
      assert.are.equal(0, t.FontShadow.Color[4], "its shadows draw nothing")
      local ink = t.Palette[t.Fonts.Title.Color]
      assert.is_true(ink[1] < 0.3 and ink[2] < 0.3 and ink[3] < 0.3, "dark titles on the paper")
      assert.is_nil(t.Sparkles)
      assert.is_nil(t.Header.Cloud)
      assert.is_nil(t.Header.Spark)
      assert.is_nil(t.Panel.Wash)
      assert.are.equal("BLEND", t.Header.Ribbon.BlendMode, "ink, not light")
      -- Glyphs inked, colored icons in their own colors (inked, they turned into black shapes).
      assert.are.equal("Ink", t.Header.Buttons.Color)
      local art = t.Palette[t.Header.Buttons.ArtColor]
      assert.is_true(art[1] > 0.8 and art[2] > 0.8 and art[3] > 0.8, "a light tint keeps their colors")
    end)
  end)

  describe("Quiet", function()
    it("is calm and compact: smaller icons, no flourishes, quicker motion without bounce", function()
      local t = sonataNext:Resolve("Quiet")
      assert.is_true(t.Layout.Icon < 44)
      assert.is_true(t.Layout.Feather < 96)
      for _, part in ipairs({ "Ribbon", "Cloud", "Spark", "TitleGlow" }) do
        assert.is_nil(t.Header[part], part)
      end
      assert.is_nil(t.Sparkles)
      assert.is_false(t.Chain.Braid)
      assert.are.equal("outCubic", t.Motion.Ease.Open)
      assert.are.equal("outCubic", t.Motion.Ease.Enter)
      assert.is_true(t.Motion.Time.Open < 0.45)
      -- Asked: no border on a full panel docked at its edge ("there shouldn't be").
      assert.is_false(t.Panel.Edge.Full)
      -- Its vendor prices smaller than Default's, with its smaller icons (still larger than v0.7.0's 10).
      local default = sonataNext:Resolve("Default")
      assert.is_true(t.Fonts.Price.Size < default.Fonts.Price.Size and t.Fonts.Price.Size > 10)
      assert.are.equal(t.Fonts.Price.Size, t.Fonts.PriceUnaffordable.Size)
      -- Asked: its header icons scaled down, with its smaller title (next-themes.md §11).
      assert.is_true(t.Header.Buttons.Scale < 1)
      assert.are.equal(1, sonataNext:Resolve("Default").Header.Buttons.Scale)
    end)
  end)
end)
