-- next_themes_spec.lua -- BetterBags Next's shipped themes (sonata/themes/next/*.lua,
-- next-themes.md): every one is data, resolves on every client, and names nothing it does not define
-- (SonataNext:Check); and each looks the way it says.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

if addon:GetModule("NextTween", true) == nil then
  ResetModuleStub("NextTween", "next/tween.lua")
  LoadBetterBagsModule("next/tween.lua")
end
-- SonataNext:Check reads a glitch's and a rain's parts from their modules (and an ornament's): loaded, every theme's are
-- checked too. The panels an ornament may be on are named by their bag kinds: a Constants stub when none is loaded,
-- taken away again after.
local constants, createdConstants = StubBetterBagsModule("Constants")
constants.BAG_KIND = constants.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = 2 }
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextOrnaments", "next/ornaments.lua" },
  { "NextGlitch", "next/glitch.lua" }, { "NextRain", "next/rain.lua" }, { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" }, { "NextThreads", "next/threads.lua" } }) do
  if addon:GetModule(m[1], true) == nil then
    ResetModuleStub(m[1], m[2])
    LoadBetterBagsModule(m[2])
  end
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
    if createdConstants then
      ResetModuleStub("Constants")
    end
  end)

  local function shipped()
    local keys = {}
    for key in pairs(sonataNext:GetThemes()) do table.insert(keys, key) end
    table.sort(keys)
    return keys
  end

  it("ships Default and at least three others", function()
    assert.are.same({ "Default", "Ember", "Frost", "GW2", "Glitch", "Parchment", "Plain", "Quiet" }, shipped())
  end)

  it("resolves every one on every client and finds nothing it does not define", function()
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(shipped()) do
        local theme = sonataNext:Resolve(key)
        assert.are.equal(key, theme.Name, client)
        assert.is_true(theme.DisplayName ~= "" and theme.Description ~= "", key .. " describes itself")
        assert.are.same({}, sonataNext:Check(key), key .. " on " .. client)
        -- The cards waiting in a dock glow in these (automation.md §4, profession-shopping-list.md).
        assert.is_not_nil(theme.Dock.DestroyColor, key .. " destroy color")
        assert.is_not_nil(theme.Dock.BuyColor, key .. " buy color")
      end
    end
  end)

  -- Themes merge with Default key by key (next-themes.md §2), so art a theme draws over one of Default's colored
  -- fills took that fill's Alpha. Reported in game: Guild Wars 2's cream Done and Delete buttons drew at 14% and 10%
  -- (Default's Primary and Danger fills), dark and unreadable. Art a theme sets resolves with the alpha it set.
  it("draws the art each theme sets at the alpha it sets, never one inherited from Default", function()
    local found = {}
    -- An alpha may be a range (a snow entry's, NextSnow): resolution copies it, so it is compared by value.
    local function same(a, b)
      if type(a) == "table" and type(b) == "table" then
        return a[1] == b[1] and a[2] == b[2]
      end
      return a == b
    end
    local function walk(raw, resolved, path)
      for k, v in pairs(raw) do
        local r = type(resolved) == "table" and resolved[k] or nil
        if type(v) == "table" and type(r) == "table" then
          if (v.Texture ~= nil or v.Atlas ~= nil) and not same(r.Alpha, v.Alpha) then
            table.insert(found, path .. "." .. tostring(k) .. " " .. tostring(r.Alpha))
          end
          walk(v, r, path .. "." .. tostring(k))
        end
      end
    end
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(shipped()) do
        walk(sonataNext.themes[key], sonataNext:Resolve(key), key .. " on " .. client)
      end
    end
    table.sort(found)
    assert.are.same({}, found)
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
  -- A dock card's lines are as tall as the theme says (Dock.TitleHeight, LineHeight; next/dockcard.lua), whatever their
  -- font: a font taller than its line may be cut or not drawn. Found by the adversarial review: Glitch's 24 title in 22.
  it("fits a dock card's title and lines in their heights", function()
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(shipped()) do
        local t = sonataNext:Resolve(key)
        local D = t.Dock
        for _, pair in ipairs({ { D.TitleFont, D.TitleHeight }, { D.WarningFont, D.LineHeight }, { D.HintFont, D.LineHeight } }) do
          local size = t.Fonts[pair[1]].Size
          if size then
            assert.is_true(size <= pair[2], key .. " on " .. client .. ": " .. pair[1] .. " " .. size .. " in " .. pair[2])
          end
        end
      end
    end
  end)

  it("fits a vendor card's name and price beside its icon", function()
    for client, flags in pairs(CLIENTS) do
      for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
      for _, key in ipairs(shipped()) do
        local t = sonataNext:Resolve(key)
        local L, V = t.Layout, t.Vendor
        -- A role's size: its Size; a role copying a client font outright (Copy) without one (Size = false), the font's.
        local function sizeOf(role)
          local spec = t.Fonts[role]
          if spec.Copy ~= nil and not spec.Size then
            local _, size = _G[spec.Copy]:GetFont()
            return size
          end
          return spec.Size
        end
        local name = sizeOf(V.NameFont)
        for _, role in ipairs({ V.PriceFont, V.UnaffordableFont }) do
          local size = sizeOf(role)
          assert.is_true(2 * name + size + L.VendorPriceRaise <= L.Icon, key .. " " .. role .. " on " .. client)
          assert.is_true(V.CoinSize <= size + 1, key .. " coins no taller than the price")
        end
        assert.is_true(L.VendorColumns >= 1, key)
      end
    end
  end)

  it("needs no other addon, but Guild Wars 2, which needs GW2_UI", function()
    for _, key in ipairs(shipped()) do
      if key ~= "GW2" then
        assert.is_true(sonataNext:IsSelectable(key), key)
      end
    end
    assert.is_false(sonataNext:IsSelectable("GW2"))
    _G._loadedAddOns = { GW2_UI = true }
    assert.is_true(sonataNext:IsSelectable("GW2"))
    _G._loadedAddOns = nil
  end)

  -- Asked: "guild wars 2 theme! we need to use the guild wars 2 assets when it's installed ... don't use their draw
  -- functions" (docs/next-gw2-theme.md).
  describe("Guild Wars 2", function()
    local GW = "Interface\\AddOns\\GW2_UI\\Textures\\"

    -- every GW2_UI file a table names, at any depth.
    local function gw2Files(node, out)
      for _, v in pairs(node) do
        if type(v) == "string" and v:sub(1, #GW) == GW then
          out[v] = true
        elseif type(v) == "table" then
          gw2Files(v, out)
        end
      end
      return out
    end

    local function art(t, spec)
      return t.Textures[spec.Texture] or spec.Texture
    end

    it("draws from GW2_UI's own files, every one there in GW2_UI", function()
      local t = sonataNext:Resolve("GW2")
      assert.are.same({ "GW2_UI" }, sonataNext.themes.GW2.Requires)
      local files = gw2Files(t, {})
      local count = 0
      for path in pairs(files) do
        count = count + 1
        local file = ".libraries/GW2_UI/" .. path:sub(#"Interface\\AddOns\\GW2_UI\\" + 1):gsub("\\", "/")
        local f = io.open(file, "rb")
        assert.is_not_nil(f, file .. " (install-deps.sh clones GW2_UI)")
        f:close()
      end
      assert.is_true(count >= 30, "its art is GW2_UI's: " .. count)
    end)

    -- Asked: "this is how betterbags original looks like (non-next), we need to use those icons, that bag frame
    -- style, that icon ... X button should still be top right" (sonata/themes/gw2.lua, docs/next-gw2-theme.md).
    it("is the original's frame: the world map painting, the header band, the footer band, the emblem, no feather", function()
      local t = sonataNext:Resolve("GW2")
      assert.are.equal(GW .. "character\\worldmap-background.png", art(t, t.Panel.Fill))
      -- Reported in game: a thin white line between the side panel and the bag. The side panel art's last column (31
      -- of 32, the one against the window) is white at 55%, every other one black; the painting's last 17 columns
      -- (from 1007 of 1024) fade out, which shows the world through on the bank's side panel side (measured). Both
      -- are cropped to what is solid.
      assert.are.same({ 0, 1007 / 1024, 0, 1 }, t.Panel.Fill.TexCoords)
      assert.are.same({ 0, 31 / 32, 0, 481 / 512 }, t.Header.Buttons.Rail.Fill.TexCoords)
      assert.is_nil(t.Panel.Feather, "asked: no feather while docked (false removes the inherited one)")
      local byTexture = {}
      for _, o in ipairs(t.Panel.Ornaments) do byTexture[art(t, o)] = o end
      local band = byTexture[GW .. "bag\\bagheader.png"]
      assert.are.equal("TOP", band.Point, "across the top")
      assert.are.same({ 0, 1, 19 / 64, 1 }, band.TexCoords, "its painted rows (measured)")
      local finish = byTexture[GW .. "bag\\bagheader-right.png"]
      assert.are.equal("TOPOUTER", finish.Point)
      assert.are.same({ 196 / 512, 1, 19 / 64, 1 }, finish.TexCoords)
      local footer = byTexture[GW .. "bag\\bagfooter.png"]
      assert.are.same({ "BOTTOM", { 0, 1, 0, 34 / 64 } }, { footer.Point, footer.TexCoords })
      local emblem = byTexture[GW .. "bag\\bagicon.png"]
      assert.are.same({ 84, 84, "TOPINNER" }, { emblem.Width, emblem.Height, emblem.Point }, "the original's 84 at the top inner corner")
      -- Asked: the emblem, the header band and the painting as GW2_UI's character window has them
      -- (GwCharacterWindowTemplate, Character/windowBase.xml): the band above the window's top (the painting starts
      -- there, so the band is drawn over what is behind the window), starting over the side panel (40 out); the
      -- emblem's bottom right corner 18 in and 22 below the window's top, so it straddles the side panel; the title 31
      -- in, its middle 18 above the window's top; the side panel from the window's top; the close 10 in, 10 to 30
      -- above the window's top.
      local top = band.Y + band.Height
      assert.are.equal(-40, band.Start, "over the side panel")
      assert.are.same({ 18 - 84, top + 22 - 84 }, { emblem.X, emblem.Y or 0 }, "its corner 18 in, 22 down")
      assert.are.equal(top, t.Panel.Fill.Inset.Top, "the painting from the window's top")
      assert.are.equal(top, t.Header.Buttons.Rail.Start)
      assert.are.equal(31, t.Layout.Pad + t.Layout.TitleInset)
      assert.are.equal(top - 18, t.Layout.TitleTop + t.Fonts.Title.Size / 2)
      local close = t.Header.Buttons.Pinned.closeButton
      assert.are.equal(top - 20, -close.Y + t.Layout.HeaderButton / 2, "the close's middle 20 above the top")
      assert.are.equal(-20, close.X - t.Layout.HeaderButton / 2, "and 20 in")
      assert.is_true(t.Header.Buttons.Rail.Top >= (emblem.Y or 0) + emblem.Height, "the side buttons below the emblem")
      assert.is_true(t.Layout.SearchTop >= top, "the search bar below the band")
      assert.is_nil(t.Panel.Edge, "no border round the see-through header")
      assert.are.same({ "Backpack", "Bank", "GuildBank" }, emblem.Panels)
      assert.are.same({ "Vendor" }, byTexture[GW .. "character\\macro-window-icon.png"].Panels, "GW2_UI's merchant's")
      assert.is_nil(t.Footer.Line, "the band is the footer's line")
    end)

    it("puts the actions down GW2's side panel outside the window, in the original's icons, the X at the top right", function()
      local t = sonataNext:Resolve("GW2")
      local B = t.Header.Buttons
      assert.are.same({ 40, true }, { B.Rail.Width, B.Rail.Outside }, "GW2_UI's side panel stands beside its windows")
      assert.are.equal(GW .. "bag\\bagleftpanel.png", art(t, B.Rail.Fill))
      assert.are.equal(32, t.Layout.HeaderButton, "the original's actions are 32")
      assert.are.equal(5, B.Rail.Gap, "and 5 apart")
      assert.are.equal("TOPOUTER", B.Pinned.closeButton.Point, "top right on the backpack")
      -- Asked: the size button beside the X, out of the side panel.
      local close, size = B.Pinned.closeButton, B.Pinned.sizeButton
      assert.are.same({ "TOPOUTER", close.Y }, { size.Point, size.Y })
      assert.are.equal(close.X - t.Layout.HeaderButton, size.X, "its left, side by side")
      local icons = B.Icons
      assert.are.equal(GW .. "uistuff\\window-close-button-normal.png", art(t, icons.closeButton))
      assert.are.equal(GW .. "uistuff\\window-close-button-hover.png", art(t, icons.closeButton.Highlight))
      -- The original's actions: Show Bags, Sort, Settings (sonata/themes/gw2.lua).
      assert.are.equal(GW .. "icons\\bagmicrobutton-up.png", art(t, icons.bagsButton))
      assert.are.equal(GW .. "icons\\bagmicrobutton-down.png", art(t, icons.bagsButton.Highlight))
      -- Asked: one highlight for every button, as Show Blizzard Bags has: art over the icon (GW2_UI's -down art, or
      -- its own icon again as its micro menu draws it), no tint.
      for key, icon in pairs(icons) do
        if icon.Glyph == false then
          assert.is_not_nil(icon.Highlight, key .. " has a highlight")
        end
      end
      assert.are.equal("White", B.ArtHoverColor)
      assert.are.equal(GW .. "icons\\microicons\\collectionsmicrobutton-up.png", art(t, icons.sortButton))
      assert.are.equal(GW .. "icons\\microicons\\questlogmicrobutton-up.png", art(t, icons.settingsButton))
      -- Asked: GW2_UI's size art (its only, 32 x 32) drew blurry; BetterBags' own glyphs instead, an underscore and a
      -- box, in the theme's glyph color.
      local BB = "Interface\\AddOns\\BetterBags\\textures\\next\\icons\\"
      assert.are.same({ BB .. "minimize.png", true }, { art(t, icons.sizeButtonFull), icons.sizeButtonFull.Glyph ~= false })
      assert.are.same({ BB .. "maximize.png", true }, { art(t, icons.sizeButtonSmall), icons.sizeButtonSmall.Glyph ~= false })
      for _, name in ipairs({ "minimize", "maximize" }) do
        local f = io.open("textures/next/icons/" .. name .. ".png", "rb")
        assert.is_not_nil(f, name .. " (tools/textures/next_icons.py)")
        local data = f:read("*a")
        f:close()
        local function u32(i)
          local a, b, c, d = data:byte(i, i + 3)
          return ((a * 256 + b) * 256 + c) * 256 + d
        end
        assert.are.same({ 64, 64, 8, 6 }, { u32(17), u32(21), data:byte(25), data:byte(26) }, name .. ": 64 x 64 RGBA")
      end
      -- And GW2_UI's own where it has one (Inventory/bank.xml: the character and Warbank tab icons).
      assert.are.same({ 0, 0.5, 0.5, 1 }, icons.bankTabsButton.TexCoords)
      assert.are.same({ 0.5, 1, 0, 0.5 }, icons.depositButton.TexCoords)
      assert.are.equal(GW .. "icons\\repair.png", art(t, icons.repairAllButton))
      for key, icon in pairs(icons) do
        if gw2Files(icon, {})[art(t, icon)] then
          assert.is_false(icon.Glyph, key .. " is art")
        end
      end
    end)

    it("draws every text role in GW2_UI's fonts: its normal family, or its header family for titles", function()
      local t = sonataNext:Resolve("GW2")
      local default = sonataNext:Resolve("Default")
      local headers = { Title = true, ConfirmTitle = true, DialogTitle = true, SettingsBrand = true, SettingsTitle = true }
      for role in pairs(default.Fonts) do
        local spec = t.Fonts[role]
        if role == "Stack" then
          assert.are.equal("NumberFontNormal", spec.Object, "the bags' count font, which GW2_UI rewrites too")
        elseif headers[role] then
          assert.are.equal("SystemFont_Shadow_Large", spec.Object, role)
        else
          assert.are.equal("GameFontHighlight", spec.Object, role)
        end
        assert.is_nil(spec.File, role .. " follows GW2_UI's font for the locale")
      end
    end)

    it("is GW2_UI's colors: LightHeader titles, its wine accent, nothing starry", function()
      local t = sonataNext:Resolve("GW2")
      assert.are.same({ 1, 0.9450, 0.8196, 1 }, t.Palette.LightHeader)
      assert.are.same({ 150 / 255, 50 / 255, 50 / 255, 1 }, t.Palette.Accent)
      assert.are.equal("LightHeader", t.Fonts.Title.Color)
      assert.are.equal("Accent", t.Tabs.Indicator.Color)
      assert.is_nil(t.Sparkles)
      for _, part in ipairs({ "Ribbon", "Cloud", "Spark" }) do
        assert.is_nil(t.Header[part], part)
      end
      assert.is_nil(t.Panel.Wash)
      assert.is_false(t.Chain.Braid)
    end)

    -- Asked: "when i say theme for gw2, i also mean tabs, i mean everything ... art of buttons, art of toggles".
    it("draws its tabs, search box and sections in GW2_UI's art", function()
      local t = sonataNext:Resolve("GW2")
      assert.are.equal(GW .. "uistuff\\tab-tex-right-left.png", art(t, t.Tabs.Fill))
      -- GW2_UI's left tab (flipped, for tabs out to the left), its solid columns (0 to 48 of 64, at least 56% opaque:
      -- its outer 40% fades to nothing, under a name) and 64 of its 1,024 rows (squeezed whole into a tab, its ragged
      -- edge streaked). Asked: "the art on the left tabs makes the text tough to read".
      assert.are.same({ 48 / 64, 0, 0, 64 / 1024 }, t.Tabs.Fill.TexCoords)
      assert.are.same(t.Tabs.Fill.TexCoords, t.Tabs.SelectedFill.TexCoords)
      assert.are.equal(GW .. "uistuff\\tab-tex-right-left.png", art(t, t.Tabs.SelectedFill))
      assert.are.equal(GW .. "bag\\bagsearchbg.png", art(t, t.Search.Fill))
      assert.are.equal(GW .. "bag\\bagsearchbg.png", art(t, t.Search.FocusFill))
      assert.is_nil(t.Search.Edge, "GW2_UI's search bar has no border")
      assert.are.equal(GW .. "bag\\bag-sep.png", art(t, t.Sections.Header), "GwBagHeaderTemplate's row")
      assert.are.equal(GW .. "character\\menu-hover.png", art(t, t.Sections.Highlight))
    end)

    it("draws every control in GW2_UI's art: buttons, check boxes, sliders, scroll bars, fields, dropdowns, menus", function()
      local C = sonataNext:Resolve("GW2").Controls
      local t = sonataNext:Resolve("GW2")
      for _, kind in ipairs({ "Plain", "Primary" }) do
        assert.are.equal(GW .. "uistuff\\button.png", art(t, C.Button[kind].Fill), kind)
        assert.are.equal(GW .. "uistuff\\button_disable.png", art(t, C.Button[kind].DisabledFill), kind)
      end
      local ink = t.Palette[t.Fonts.Button.Color]
      assert.is_true(ink[1] < 0.2 and ink[2] < 0.2 and ink[3] < 0.2, "dark text on GW2's cream buttons")
      assert.are.equal("Check", C.Toggle.Style)
      assert.are.equal(GW .. "uistuff\\checkbox.png", art(t, C.Toggle.Off))
      assert.are.equal(GW .. "uistuff\\checkboxchecked.png", art(t, C.Toggle.On))
      assert.are.equal(GW .. "uistuff\\checkbox-disabled.png", art(t, C.Toggle.Disabled))
      assert.are.same({ 0.6, 0.6, 0.6, 1 }, t.Palette[C.Toggle.DisabledOn.Color], "SkinColors.Disabled")
      assert.are.equal(GW .. "uistuff\\sliderbg.png", art(t, C.Slider.Track))
      assert.are.equal(GW .. "uistuff\\sliderhandle.png", art(t, C.Slider.Thumb))
      assert.are.equal(GW .. "uistuff\\scrollbg.png", art(t, C.ScrollBar.Track))
      assert.are.equal(GW .. "uistuff\\scrollbarmiddle.png", art(t, C.ScrollBar.Thumb))
      assert.are.equal(GW .. "uistuff\\statusbar.png", art(t, C.Input.Fill))
      assert.are.equal(GW .. "uistuff\\ui-tooltip-background.png", art(t, C.Dropdown.Fill))
      assert.are.equal(GW .. "uistuff\\arrowdown_down.png", art(t, C.Dropdown.Chevron))
      assert.are.equal(GW .. "uistuff\\ui-tooltip-background.png", art(t, C.Menu.Fill))
      assert.are.equal(GW .. "uistuff\\checkboxchecked.png", art(t, C.Menu.Check))
      assert.are.equal(GW .. "uistuff\\ui-tooltip-background.png", art(t, C.Dialog.Card))
    end)

    it("skins item buttons as GW2_UI does: cropped icons on its backdrop, its border in the quality's color", function()
      local b = sonataNext:Resolve("GW2").ItemButton
      assert.are.same({ 0.07, 0.93, 0.07, 0.93 }, b.Icon.TexCoords)
      assert.are.equal(GW .. "bag\\bagitembackdrop.png", b.Backdrop.Texture)
      assert.are.same({ Texture = GW .. "bag\\bagitemborder.png", Alpha = 0.9 }, b.QualityBorder)
      assert.are.same({ Texture = GW .. "bag\\bagitemborder.png", BlendMode = "ADD", Alpha = 0.33 }, b.Highlight)
      assert.are.equal(GW .. "uistuff\\ui-quickslot-depress.png", b.Pushed.Texture)
      assert.are.same({ { Point = "TOPRIGHT", X = 0, Y = -3 } }, b.Count.Points)
    end)

    it("draws the settings window as GW2_UI's: its panel painting, menu backing, brand separator and divider", function()
      local t = sonataNext:Resolve("GW2")
      local S = t.Settings
      assert.are.equal(GW .. "uistuff\\settingspanelbg.png", art(t, S.Fill))
      assert.are.same({ 0, 1, 0, 754 / 1024 }, S.Fill.TexCoords, "its painted rows (measured)")
      assert.are.equal(GW .. "uistuff\\236menubg.png", art(t, S.Sidebar.Fill))
      assert.are.equal(GW .. "uistuff\\settingspanelsep.png", art(t, S.Sidebar.Line))
      assert.are.equal(GW .. "hud\\levelreward-sep.png", art(t, S.Brand.Line))
      assert.are.equal(GW .. "character\\menu-hover.png", art(t, S.Nav.HoverFill))
      -- Asked: one close button, the bags'.
      assert.are.equal(art(t, t.Header.Buttons.Icons.closeButton), t.Textures[S.Header.Close.Icon])
      assert.are.equal(GW .. "uistuff\\window-close-button-hover.png", t.Textures[S.Header.Close.HoverIcon])
      assert.are.equal(GW .. "character\\menu-hover.png", art(t, S.Nav.SelectedFill))
    end)
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

  -- Round three of the Plain theme (docs/next-plain-theme.md; asked: "scale for Plain should be the same as our Default",
  -- of the settings window "keep it like we do in default, just, pass over with skin a bit", the header's actions in the
  -- bag button's menu, the vendor's portrait on its button).
  describe("Plain", function()
    it("draws everything at Default's scale, but what Blizzard's frame fixes", function()
      for client, flags in pairs(CLIENTS) do
        for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
        local t, default = sonataNext:Resolve("Plain"), sonataNext:Resolve("Default")
        for _, key in ipairs({ "Icon", "Gap", "Pad", "SectionHeader", "SectionSpacing", "Footer", "TabHeight", "TabSpacing" }) do
          assert.are.equal(default.Layout[key], t.Layout[key], key .. " on " .. client)
        end
        for role, spec in pairs(t.Fonts) do
          if spec.Copy ~= nil and default.Fonts[role] ~= nil and spec.Size ~= false then
            assert.are.equal(default.Fonts[role].Size, spec.Size, role .. " on " .. client)
          end
        end
        -- The title bar holds the client's own GameFontNormal; Blizzard's list headers and sections are larger than
        -- Default's roles.
        for _, role in ipairs({ "Title", "SettingsNavGroup", "SettingsSection" }) do
          assert.is_false(t.Fonts[role].Size, role)
        end
        assert.are.same({ default.Settings.Width, default.Settings.Height }, { t.Settings.Width, t.Settings.Height })
        assert.are.equal(default.Settings.Sidebar.Width, t.Settings.Sidebar.Width)
        assert.are.equal(default.Settings.Sidebar.Pad, t.Settings.Sidebar.Pad, "the category list lined up again")
        assert.is_nil(t.Settings.Content.Layout, "Default's rows, not Blizzard's list")
        assert.is_nil(t.Settings.Tabs, "the page tabs under the header")
        assert.is_nil(t.Settings.InnerFrame)
        assert.are.same({ default.Controls.Dropdown.Width, default.Controls.Slider.Width },
          { t.Controls.Dropdown.Width, t.Controls.Slider.Width })
        assert.is_nil(t.Controls.Dropdown.Steppers)
        assert.is_nil(t.Controls.Slider.Steppers)
        assert.are.equal(default.Controls.Input.Height, t.Controls.Input.Height)
        assert.is_nil(t.Controls.Input.Fill.Thickness, "the field's art over all of what takes its clicks")
      end
    end)

    it("frames its settings sidebar as Blizzard's inset, its text areas and item boxes as Blizzard's edit box", function()
      local t = sonataNext:Resolve("Plain")
      local S = t.Settings.Sidebar
      assert.are.same({ 4, 24, 4 }, { S.Left, S.Top, S.Bottom })
      assert.are.equal("InsetFrameTemplate", S.Frame.Layout)
      assert.are.equal("Interface\\FrameGeneral\\UI-Background-Marble", S.Fill.Texture)
      for _, box in ipairs({ t.Controls.TextArea, t.Controls.ItemGrid }) do
        assert.is_false(box.Fill)
        assert.is_false(box.Edge)
        local tl = box.Frame.Pieces.TopLeftCorner
        assert.are.same({ "Interface\\Common\\Common-Input-Border-TL", 8, 8, -5, 5 }, { tl.Texture, tl.Width, tl.Height, tl.X, tl.Y })
        assert.are.equal("Interface\\Common\\Common-Input-Border-M", box.Frame.Pieces.Center.Texture)
      end
      local line = t.Controls.TopTabs.Line
      assert.is_true(line.Open)
      assert.are.same({ 32, 32 }, { line.Outset.Left, line.Outset.Right })
      assert.are.equal(6, t.Settings.Header.Right, "the content clear of the frame's right edge")
      assert.is_false(t.Settings.Content.TitleUpper, "section titles as written, as Blizzard's")
    end)

    it("puts the header's actions in the original bags' bag button, the vendor's portrait on the vendor's", function()
      for client, flags in pairs(CLIENTS) do
        for _, flag in ipairs(FLAGS) do addon[flag] = flags[flag] == true end
        local t = sonataNext:Resolve("Plain")
        local M = t.Header.Buttons.Menu
        assert.are.same({ "TOPINNER", -12, -15, 40, 40 }, { M.Point, M.X, M.Y, M.Width, M.Height }, client)
        assert.are.equal("Interface\\Containerframe\\Bagslots2x", M.Layers[1].Texture)
        assert.are.same({ 0, 0.2, 0, 1 }, M.Layers[1].TexCoords)
        assert.are.same({ 0.2, 0.3992, 0, 1 }, M.Highlight.TexCoords)
        local vendor = M.Panels.Vendor.Layers
        assert.are.equal("npc", vendor[2].Unit)
        assert.are.equal("Interface\\CharacterFrame\\TempPortraitAlphaMask", vendor[2].Mask.Texture)
        assert.are.same({ 0.578125, 0.689453125, 0.0234375, 0.46875 }, vendor[3].TexCoords, "Bagslots2x's empty gold ring")
        assert.is_not_nil(t.Header.Buttons.Pinned.closeButton, "the close stays in the header")
        assert.is_nil(t.Panel.Ornaments, "the bag is the button now, not an ornament")
      end
    end)
  end)
  -- Glitch (next-themes.md §21): asked for "flickers, glitched blinking textures that wobble suddenly and harshly, think
  -- green mesh".
  -- Frost (next-themes.md §22): deep winter blue threaded with gold, freezing together from shards and shattering, snow
  -- on a breeze, threads of gold light.
  describe("Frost", function()
    local function readFile(path)
      local file = path:gsub("^Interface\\AddOns\\BetterBags\\", ""):gsub("\\", "/")
      local f = io.open(file, "rb")
      assert.is_not_nil(f, file)
      local data = f:read("*a")
      f:close()
      return data, file
    end

    it("draws its display text in Cinzel, which it ships with its license, in the locales it covers", function()
      local t = sonataNext:Resolve("Frost")
      local files = {}
      for role, spec in pairs(t.Fonts) do
        if spec.File ~= nil then
          files[spec.File] = true
          assert.are.same({ "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }, spec.Locales, role)
        end
      end
      local count = 0
      for path in pairs(files) do
        count = count + 1
        local data, file = readFile(path)
        assert.are.equal("\0\1\0\0", data:sub(1, 4), file .. " is a TrueType font")
      end
      assert.are.equal(2, count, "regular and bold")
      local license = readFile("Interface\\AddOns\\BetterBags\\fonts\\frost\\Cinzel_OFL.txt")
      assert.is_truthy(license:find("SIL Open Font License", 1, true))
      assert.is_not_nil(t.Fonts.Title.File, "the title")
      assert.is_not_nil(t.Fonts.Section.File, "sections")
      assert.is_nil(t.Fonts.Count.File, "counts in the client's font")
    end)

    it("ships every texture it names, as a PNG", function()
      local t = sonataNext:Resolve("Frost")
      local count = 0
      for name, path in pairs(t.Textures) do
        if path:find("textures\\next\\frost\\", 1, true) then
          count = count + 1
          local data, file = readFile(path)
          assert.are.equal("\137PNG\r\n\26\n", data:sub(1, 8), name .. ": " .. file)
        end
      end
      assert.are.equal(10, count)
    end)

    it("freezes together from shards of its own fill and shatters, with snow on a breeze and threads of gold", function()
      local t = sonataNext:Resolve("Frost")
      local S = t.Panel.Shatter
      assert.are.equal(t.Panel.Fill.Texture, S.Shards.Texture, "its shards carry the body's own art")
      assert.is_not_nil(S.Open)
      assert.is_not_nil(S.Close)
      assert.is_true(S.Shards.Jitter < 0.5)
      -- It appears out of a frost storm growing from its bottom inner corner.
      assert.are.equal("BOTTOMINNER", S.Open.Storm.From)
      -- Asked: the shatter's lines "don't need to show" as it opens.
      assert.is_nil(S.Open.Flash)
      assert.is_not_nil(S.Open.Storm.Flakes)
      assert.is_not_nil(S.Open.Storm.Mist)
      assert.is_true(S.Open.Time + S.Open.Storm.Appear + S.Open.Clear < 0.9, "shown before a bank's 1 second wait ends")
      assert.is_true(t.Panel.Snow.Gusts.OnOpen)
      local wheres = {}
      for _, entry in ipairs(t.Panel.Snow.Flakes) do wheres[entry.Where] = true end
      assert.are.same({ Body = true, Feather = true }, wheres)
      assert.are.equal(3, #t.Panel.Threads)
      for _, thread in ipairs(t.Panel.Threads) do
        assert.are.equal("Gold", thread.Color)
        assert.is_not_nil(thread.Draw)
      end
    end)

    -- Asked: "the streaks i see, make those animated and not static? also get rid of that big rune in the background";
    -- then, of the streaks blown across the whole body: "slightly too noisy ... the wrong color -- more golden, and A LOT
    -- less of them, more like... slower, shooting star, then don't even go the full length of the bag, more like...
    -- flyby twinkles".
    it("sends a few slow gold shooting stars across its body, and has no streaks or rune", function()
      local t = sonataNext:Resolve("Frost")
      assert.is_nil(t.Textures.Rune)
      assert.is_nil(t.Textures.Streaks)
      for _, piece in ipairs(t.Panel.Ornaments) do
        assert.are_not.equal("Rune", piece.Texture)
        assert.are_not.equal("Streaks", piece.Texture)
      end
      local F = t.Panel.Snow.Flybys
      assert.are.equal("Gold", F.Color)
      assert.is_true(F.Max <= 2, "a lot less of them")
      assert.is_true(F.Every[1] >= 3, "now and then")
      assert.is_true(F.Speed[2] <= 120, "slow")
      assert.is_true(F.Travel[2] <= 200, "never the length of the bag (400 across)")
      assert.is_not_nil(F.Head.Twinkle)
      assert.are.equal("Gold", F.Head.Color)
    end)

    it("is in the screenshot's blues and gold", function()
      local t = sonataNext:Resolve("Frost")
      local gold, body = t.Palette.Gold, t.Palette.Body
      assert.is_true(gold[1] > gold[3] + 0.3, "gold: warm")
      assert.is_true(body[3] > body[2] and body[2] > body[1], "the body: blue over teal over red")
      assert.is_true(t.Palette.Ice[3] > 0.9 and t.Palette.Ice[1] < 0.6, "ice: a cold light blue")
    end)
  end)

  describe("Glitch", function()
    -- readFile returns a file shipped with BetterBags, by its game path.
    local function readFile(path)
      local file = path:gsub("^Interface\\AddOns\\BetterBags\\", ""):gsub("\\", "/")
      local f = io.open(file, "rb")
      assert.is_not_nil(f, file)
      local data = f:read("*a")
      f:close()
      return data, file
    end

    it("draws its text in two terminal fonts it ships, with their licenses, in the locales they cover", function()
      local t = sonataNext:Resolve("Glitch")
      local files = {}
      for role, spec in pairs(t.Fonts) do
        if spec.File ~= nil then
          files[spec.File] = true
          assert.are.same({ "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }, spec.Locales, role)
        end
      end
      local count = 0
      for path in pairs(files) do
        count = count + 1
        local data, file = readFile(path)
        assert.are.equal("\0\1\0\0", data:sub(1, 4), file .. " is a TrueType font")
        local license = readFile((path:gsub("%-Regular%.ttf$", "-OFL.txt")))
        assert.is_truthy(license:find("SIL Open Font License", 1, true))
      end
      assert.are.equal(2, count)
      assert.is_not_nil(t.Fonts.Title.File, "the title")
      assert.is_not_nil(t.Fonts.Section.File, "sections")
      assert.is_not_nil(t.Fonts.Count.File, "counts")
    end)

    it("ships every texture it names, as a PNG", function()
      local t = sonataNext:Resolve("Glitch")
      for name, path in pairs(t.Textures) do
        if path:find("textures\\next\\glitch\\", 1, true) then
          local data, file = readFile(path)
          assert.are.equal("\137PNG\r\n\26\n", data:sub(1, 8), name .. ": " .. file)
        end
      end
      assert.is_not_nil(t.Textures.Mesh, "the green mesh")
    end)

    it("glitches open, closed and now and then, its title split and corrupted", function()
      local t = sonataNext:Resolve("Glitch")
      local G = t.Panel.Glitch
      assert.is_true(G.Open.Time > 0 and G.Open.PowerOn > 0, "a CRT warming up, then flickering in")
      assert.is_true(G.Close.Time > 0 and G.Close.PowerOff > 0, "flickering out, then a CRT turning off")
      assert.is_true(G.Bursts.Every >= 10, "now and then, not often")
      assert.is_true(G.Flicker[1] >= 0.3, "never flickering to nothing")
      assert.is_true(G.Step >= 0.05)
      local ghosts = t.Header.Title.Ghosts
      assert.are.same({ "TitleCyan", "TitleMagenta" }, { ghosts[1].Font, ghosts[2].Font })
      assert.are.equal("Cyan", t.Fonts.TitleCyan.Color)
      assert.are.equal("Magenta", t.Fonts.TitleMagenta.Color)
      for c in G.Corrupt.Glyphs:gmatch(".") do
        assert.is_true(c:byte() < 128, "ASCII, which every client's fonts have")
      end
      assert.are.equal("flicker", t.Motion.Ease.Cascade, "sections flicker into place")
    end)

    it("rains data down the feather and faintly behind the items, in ASCII", function()
      local t = sonataNext:Resolve("Glitch")
      local wheres = {}
      for _, entry in ipairs(t.Panel.Rain) do
        wheres[entry.Where] = entry.Alpha
        for c in entry.Glyphs:gmatch(".") do
          assert.is_true(c:byte() < 128)
        end
        assert.is_not_nil(t.Fonts[entry.Font])
        assert.is_not_nil(t.Fonts[entry.HeadFont])
      end
      assert.is_true(wheres.Feather > wheres.Body, "faint behind the items")
      assert.is_true(wheres.Body <= 0.15)
    end)

    it("draws a CRT round its content: a grid, the mesh floor, a vignette, scanlines, a rolling bar, HUD brackets", function()
      local t = sonataNext:Resolve("Glitch")
      local by, corners = {}, {}
      for _, o in ipairs(t.Panel.Ornaments) do
        by[o.Texture] = o
        if o.Texture == "Bracket" then
          corners[o.Point] = o.TexCoords
          assert.is_not_nil(o.Motion.Glitch, "twitching now and then")
          assert.is_true(o.Above, "over the frame's edge")
        end
      end
      assert.are.same({ TOPINNER = { 0, 1, 0, 1 }, TOPOUTER = { 1, 0, 0, 1 }, BOTTOMINNER = { 0, 1, 1, 0 },
        BOTTOMOUTER = { 1, 0, 1, 0 } }, corners, "the L flipped for each corner")
      assert.are.equal("BOTTOM", by.Mesh.Point)
      assert.are.equal("BODY", by.Grid.Point)
      assert.is_nil(by.Grid.Above, "behind the content")
      assert.is_true(by.Scanlines.Above, "over the items")
      assert.is_not_nil(by.Bar.Motion.Scroll, "rolling")
      assert.is_true(t.Sparkles.Upright, "square pixel sparks")
      assert.is_nil(t.Tabs.Indicator, "no bar: the selected tab is lit")
      assert.is_not_nil(t.Tabs.Edge, "tabs as HUD boxes")
      assert.are.equal("Dash", t.Sections.Line.Texture)
    end)

    it("draws in phosphor where Default draws gold and lavender", function()
      local t = sonataNext:Resolve("Glitch")
      for _, name in ipairs({ "Gold", "Lavender", "Text", "Muted" }) do
        local c = t.Palette[name]
        assert.is_true(c[2] > c[1] and c[2] > c[3], name .. " is green")
      end
    end)
  end)
end)
