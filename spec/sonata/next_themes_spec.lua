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
  { "NextGlitch", "next/glitch.lua" }, { "NextRain", "next/rain.lua" }, { "NextShatter", "next/shatter.lua" }, { "NextSnow", "next/snow.lua" }, { "NextThreads", "next/threads.lua" }, { "NextSmoke", "next/smoke.lua" }, { "NextBats", "next/bats.lua" }, { "NextBeam", "next/beam.lua" }, { "NextStopMotion", "next/stopmotion.lua" }, { "NextPaper", "next/paper.lua" } }) do
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
    assert.are.same({ "Default", "Ember", "Frost", "GW2", "Glitch", "Halloween", "MakeItSo", "Papercraft", "Parchment",
      "Plain", "Quiet" },
      shipped())
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
  -- Papercraft (next-themes.md §25): a sheet of soft paper taped on, unfolding and crumpling in stop motion, hand-drawn
  -- lettering and doodles in its margins.
  describe("Papercraft", function()
    local function exists(path)
      local file = path:gsub("^Interface\\AddOns\\BetterBags\\", ""):gsub("\\", "/")
      local f = io.open(file, "rb")
      if f == nil then
        return false
      end
      f:close()
      return true
    end

    local function t()
      return sonataNext:Resolve("Papercraft")
    end

    it("draws all its text by hand: every role of Default's in its fonts, which it ships with their licenses", function()
      local theme = t()
      local files = {}
      local default = sonataNext:Resolve("Default")
      for role in pairs(default.Fonts) do
        local spec = theme.Fonts[role]
        assert.is_not_nil(spec.File, role .. " draws in a hand")
        assert.is_true(spec.File:find("papercraft", 1, true) ~= nil, role)
        files[spec.File] = true
      end
      local n = 0
      for file in pairs(files) do
        n = n + 1
        assert.is_true(exists(file), file)
      end
      assert.are.equal(2, n)
      assert.is_true(exists("fonts/papercraft/Caveat_OFL.txt"))
      assert.is_true(exists("fonts/papercraft/PatrickHand_OFL.txt"))
    end)

    it("draws what is written on the bags' shared parts by hand too: money, item levels and cooldown numbers", function()
      local theme = t()
      assert.is_true(theme.Fonts[theme.Footer.CoinFont].File:find("papercraft", 1, true) ~= nil)
      assert.is_true(theme.ItemButton.Count.Font.Path:find("papercraft", 1, true) ~= nil)
      assert.is_true(theme.ItemButton.ItemLevel.Font.Path:find("papercraft", 1, true) ~= nil)
      assert.is_true(theme.ItemButton.Countdown.Font.Path:find("papercraft", 1, true) ~= nil)
      assert.is_not_nil(theme.ItemButton.Countdown.Locales, "minutes and hours are words in some locales")
    end)

    it("draws its fonts only in the locales they cover", function()
      local theme = t()
      local function has(list, locale)
        for _, l in ipairs(list) do
          if l == locale then return true end
        end
        return false
      end
      for role, spec in pairs(theme.Fonts) do
        assert.is_true(has(spec.Locales, "enUS"), role)
        assert.is_false(has(spec.Locales, "koKR"), role)
        assert.is_false(has(spec.Locales, "zhCN"), role)
        assert.is_false(has(spec.Locales, "zhTW"), role)
      end
      -- Patrick Hand has no Cyrillic; Caveat has.
      assert.is_false(has(theme.Fonts.Footer.Locales, "ruRU"))
      assert.is_true(has(theme.Fonts.Title.Locales, "ruRU"))
    end)

    it("ships every picture it names", function()
      local theme = t()
      for name, file in pairs(theme.Textures) do
        if file:find("papercraft", 1, true) then
          assert.is_true(exists(file), name .. ": " .. file)
        end
      end
      for _, file in ipairs({ theme.Vendor.QualityBorder, theme.ItemButton.Backdrop.Texture,
        theme.ItemButton.QualityBorder.Texture, theme.ItemButton.Highlight.Texture, theme.ItemButton.Pushed.Texture,
        theme.ItemButton.EmptySlot.Texture }) do
        assert.is_true(exists(file), file)
      end
    end)

    it("is paper of a soft colour, with no glow, feather, wash or ribbon on it", function()
      local theme = t()
      local p = theme.Palette.Paper
      assert.is_true(p[1] > 0.85 and p[1] < 0.97, "not stark white")
      assert.is_true(p[3] < p[1] - 0.05, "warm")
      assert.are.equal("PaperBody", theme.Panel.Fill.Texture)
      assert.is_nil(theme.Panel.Feather)
      assert.is_nil(theme.Panel.Wash)
      assert.is_nil(theme.Panel.Edge)
      assert.is_nil(theme.Header.Ribbon)
      assert.is_nil(theme.Header.Spark)
      assert.is_nil(theme.Header.Cloud)
      assert.are.equal("BLEND", theme.Sparkles.BlendMode, "paper does not glow")
    end)

    it("frames each sheet in a torn edge that reaches past it, for every window it draws", function()
      local theme = t()
      for name, frame in pairs({ panel = theme.Panel.Frame, settings = theme.Settings.Frame,
        dialog = theme.Controls.Dialog.Frame, tracker = theme.Currency.Tracker.Frame }) do
        assert.are.equal("PaperEdgeSide", frame.Pieces.LeftEdge.Texture, name)
        assert.is_true(frame.Pieces.TopLeftCorner.X < 0 and frame.Pieces.TopLeftCorner.Y > 0, name .. " out from the corner")
      end
    end)

    it("is taped on: over the bag's edge at either size, and on its tabs", function()
      local theme = t()
      local full, small = 0, 0
      for _, piece in ipairs(theme.Panel.Ornaments) do
        if type(piece.Texture) == "string" and piece.Texture:find("^Tape") then
          assert.is_true(piece.Above, "over what it holds")
          if piece.Sizes == nil then
            full, small = full + 1, small + 1
          elseif piece.Sizes == "Small" then
            small = small + 1
          end
        end
      end
      assert.is_true(full >= 2)
      assert.is_true(small >= 4)
      assert.are.equal("TabScrap", theme.Tabs.Fill.Texture)
      assert.are.equal("TabScrapChosen", theme.Tabs.SelectedFill.Texture)
    end)

    it("has doodles that boil in its margins, each a strip of drawings, its corners' places inside the body", function()
      local theme = t()
      local boiling = 0
      for _, piece in ipairs(theme.Panel.Ornaments) do
        if piece.Motion and piece.Motion.Boil then
          boiling = boiling + 1
          assert.are.equal(3, piece.Frames, piece.Texture)
          -- Y is down from its corner: a piece at a bottom corner goes in with a Y up.
          if piece.Point:find("^BOTTOM") then
            assert.is_true(piece.Y < 0, piece.Texture .. " up from the bottom")
          end
        end
      end
      assert.is_true(boiling >= 6)
    end)

    it("writes its notes to self only for those who read them", function()
      for _, piece in ipairs(t().Panel.Ornaments) do
        if type(piece.Texture) == "string" and piece.Texture:find("^Note") then
          assert.are.same({ "enUS", "enGB" }, piece.Locales)
        end
      end
    end)

    it("runs as stop motion: twelve poses a second, each a little off", function()
      local S = t().Motion.StopMotion
      assert.are.equal(12, S.FPS)
      assert.is_true(S.Spacing > 0 and S.Spacing < 0.5)
      assert.is_true(S.Wobble > 0)
      local P = t().Panel.Paper
      assert.are.equal(S.FPS, P.Rate)
      assert.is_true(P.Wobble.Move > 0 and P.Wobble.Turn > 0 and P.Wobble.Vertex > 0 and P.Wobble.Pose > 0)
    end)

    it("unfolds a quarter, then a half, then whole, within the second a bank waits for its panel", function()
      local O = t().Panel.Paper.Open
      assert.is_true(#O.Quarter >= 1 and #O.Half >= 3 and #O.Full >= 3)
      assert.are.equal(0, O.Half[#O.Half], "the first fold ends flat")
      assert.are.equal(0, O.Full[#O.Full], "the second fold ends flat")
      local lock = (#O.Quarter + #O.Half + #O.Full) / t().Panel.Paper.Rate
      assert.is_true(lock < 1, "shown in " .. lock)
    end)

    it("crumples to a ball that is tossed up slightly and falls", function()
      local C = t().Panel.Paper.Close
      assert.are.equal(1, C.Poses[#C.Poses])
      for i = 2, #C.Poses do
        assert.is_true(C.Poses[i] > C.Poses[i - 1])
      end
      local rise = C.Toss.Up * C.Toss.Up / (2 * C.Toss.Gravity)
      assert.is_true(rise > 30 and rise < 120, "tossed up slightly: " .. rise)
      local full = 1100 + rise + C.Ball
      assert.is_true(math.sqrt(2 * full / C.Toss.Gravity) + 0.5 < C.Toss.Life, "falls off a tall screen within its Life")
    end)

    it("mounts each item on lighter paper, its quality in coloured pencil, its count by hand", function()
      local B = t().ItemButton
      assert.is_true(B.Icon.Inset > 0)
      assert.is_true(B.QualityBorder.Texture:find("item_quality", 1, true) ~= nil)
      assert.is_true(B.Count.Font.Path:find("PatrickHand", 1, true) ~= nil)
    end)

    it("draws its controls in pencil: check boxes, outlined buttons and fields", function()
      local C = t().Controls
      assert.are.equal("Check", C.Toggle.Style)
      assert.are.equal("Horizontal", C.Button.Plain.Fill.Pieces)
      assert.are.equal("Horizontal", C.Input.Fill.Pieces)
      assert.are.equal("Horizontal", C.Dropdown.Fill.Pieces)
      assert.are.equal("CheckBox", C.Toggle.Off.Texture)
      assert.are.equal("CheckMark", C.Toggle.On.Texture)
    end)

    it("draws every glyph by hand", function()
      local theme = t()
      for _, name in ipairs({ "IconSettings", "IconClose", "IconSort", "IconBags", "IconSmall", "IconFull", "IconBankTabs",
        "IconDeposit", "IconDepositGold", "IconWithdrawGold", "IconFilter", "IconSellJunk", "IconRepair",
        "IconGuildRepair", "IconChevron", "IconBack", "IconCheck", "IconSearch", "IconPlus" }) do
        assert.is_true(theme.Textures[name]:find("papercraft", 1, true) ~= nil, name)
      end
    end)

    it("names no art it does not ship in its Check", function()
      assert.are.same({}, sonataNext:Check("Papercraft"))
    end)
  end)

  -- Halloween (next-themes.md §23): pumpkin orange and black, coming in out of smoke and breaking up into bats as it
  -- closes, a black cat on a jack-o'-lantern, leaves falling.
  describe("Halloween", function()
    local function readFile(path)
      local file = path:gsub("^Interface\\AddOns\\BetterBags\\", ""):gsub("\\", "/")
      local f = io.open(file, "rb")
      assert.is_not_nil(f, file)
      local data = f:read("*a")
      f:close()
      return data, file
    end

    local function lum(c)
      return 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3]
    end

    local function u32(data, at)
      return data:byte(at) * 2 ^ 24 + data:byte(at + 1) * 2 ^ 16 + data:byte(at + 2) * 256 + data:byte(at + 3)
    end

    -- pixels reads an 8-bit RGBA PNG whose data is stored uncompressed (zlib's stored blocks, unfiltered rows), as the
    -- generator writes the body: its rows, each a list of { r, g, b, a } from 0 to 1.
    local function pixels(data)
      assert.are.equal("\137PNG\r\n\26\n", data:sub(1, 8))
      local at, width, height, stream = 9, nil, nil, {}
      while at <= #data do
        local length, kind = u32(data, at), data:sub(at + 4, at + 7)
        local chunk = data:sub(at + 8, at + 7 + length)
        if kind == "IHDR" then
          width, height = u32(chunk, 1), u32(chunk, 5)
          assert.are.equal(8, chunk:byte(9), "8 bits a channel")
          assert.are.equal(6, chunk:byte(10), "RGBA")
        elseif kind == "IDAT" then
          table.insert(stream, chunk)
        end
        at = at + 12 + length
      end
      stream = table.concat(stream)
      local raw, pos = {}, 3
      repeat
        local final = stream:byte(pos) % 2
        assert.are.equal(0, math.floor(stream:byte(pos) / 2) % 4, "stored, not compressed")
        local len = stream:byte(pos + 1) + stream:byte(pos + 2) * 256
        table.insert(raw, stream:sub(pos + 5, pos + 4 + len))
        pos = pos + 5 + len
      until final == 1
      raw = table.concat(raw)
      local rows, stride = {}, 1 + 4 * width
      for y = 0, height - 1 do
        assert.are.equal(0, raw:byte(y * stride + 1), "unfiltered")
        local row = {}
        for x = 0, width - 1 do
          local p = y * stride + 2 + 4 * x
          row[x + 1] = { raw:byte(p) / 255, raw:byte(p + 1) / 255, raw:byte(p + 2) / 255, raw:byte(p + 3) / 255 }
        end
        rows[y + 1] = row
      end
      return rows, width, height
    end

    it("draws its display text in Creepster, which it ships with its license, in the locales it covers", function()
      local t = sonataNext:Resolve("Halloween")
      local files = {}
      for role, spec in pairs(t.Fonts) do
        if spec.File ~= nil and spec.File:find("halloween", 1, true) then
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
      assert.are.equal(1, count)
      local license = readFile("Interface\\AddOns\\BetterBags\\fonts\\halloween\\Creepster_OFL.txt")
      assert.is_truthy(license:find("SIL Open Font License", 1, true))
      assert.is_not_nil(t.Fonts.Title.File, "the title")
      assert.is_not_nil(t.Fonts.Section.File, "sections")
      assert.is_nil(t.Fonts.Count.File, "counts in the client's font")
      assert.is_nil(t.Fonts.Tab.File, "tabs, small, in the client's font")
    end)

    it("ships every texture it names, as a PNG", function()
      local t = sonataNext:Resolve("Halloween")
      local count = 0
      for name, path in pairs(t.Textures) do
        if path:find("textures\\next\\halloween\\", 1, true) then
          count = count + 1
          local data, file = readFile(path)
          assert.are.equal("\137PNG\r\n\26\n", data:sub(1, 8), name .. ": " .. file)
        end
      end
      assert.are.equal(15, count)
    end)

    -- Asked: "main color should be orange with black accents (so orange backdrop) ... a nice good color of orange,
    -- like that of a pumpkin, not over the top bright".
    it("is a pumpkin's orange, not over bright, with black accents", function()
      local t = sonataNext:Resolve("Halloween")
      local body = t.Palette.Body
      assert.is_true(body[1] > body[2] and body[2] > body[3], "orange: red over green over blue")
      assert.is_true(body[1] < 0.9 and body[1] > 0.75, "not over bright, not dull")
      assert.is_true(body[3] < 0.3, "saturated")
      assert.are.equal("HalloweenBody", t.Panel.Fill.Texture)
      for _, name in ipairs({ "Ink", "Tab", "SearchFill", "Card" }) do
        assert.is_true(lum(t.Palette[name]) < 0.1, name .. " is black")
      end
    end)

    -- Asked, of the first version's soft ribs: "remove the dark streaks on the bag ... make the orange slightly deeper".
    it("is one orange from side to side, no streaks across it, a little deeper than it was", function()
      local t = sonataNext:Resolve("Halloween")
      local body = t.Palette.Body
      assert.is_true(body[1] <= 0.82 and body[2] <= 0.43, "deeper than the first (0.835, 0.455, 0.16)")
      local rows, width, height = pixels(readFile(t.Textures.HalloweenBody))
      assert.is_true(width >= 1 and height >= 64)
      local sum, lightest, darkest = { 0, 0, 0 }, 0, 1
      for y, row in ipairs(rows) do
        for x = 2, width do
          for c = 1, 4 do
            assert.are.equal(row[1][c], row[x][c], "row " .. y .. ": the same all the way across")
          end
        end
        for c = 1, 3 do
          sum[c] = sum[c] + row[1][c]
        end
        lightest, darkest = math.max(lightest, lum(row[1])), math.min(darkest, lum(row[1]))
        assert.are.equal(1, row[1][4], "opaque")
      end
      for c = 1, 3 do
        assert.is_true(math.abs(sum[c] / height - body[c]) < 0.01, "the feather its average color (" .. c .. ")")
      end
      assert.is_true(darkest > 0.9 * lightest, "shaded only a little, top to bottom")
    end)

    -- Text reads on what it sits on: ink on the orange, light on the black tabs, search box, menus and primary buttons.
    it("writes in ink on the orange and in light on the black", function()
      local t = sonataNext:Resolve("Halloween")
      local function color(role)
        local c = t.Fonts[role].Color
        return type(c) == "string" and t.Palette[c] or c
      end
      for _, role in ipairs({ "Title", "Section", "SectionRecent", "SectionFree", "Count", "Footer", "Empty",
        "ConfirmTitle", "Price", "VendorName", "ControlText", "Button", "DialogTitle", "DialogText", "SettingsTitle",
        "SettingsLabel", "SettingsNav", "SettingsText", "TopTabSelected", "CurrencyName" }) do
        assert.is_true(lum(color(role)) < 0.3, role .. " is dark on the orange")
      end
      for _, role in ipairs({ "Tab", "TabSelected", "SearchText", "MenuItem", "MenuItemSelected", "ButtonPrimary" }) do
        assert.is_true(lum(color(role)) > 0.55, role .. " is light on the black")
      end
    end)

    -- Asked: "the bags should appear in a puff of smoke from bottom to top", then of the cartoon smoke: "can you make it
    -- more real-ish?".
    it("appears out of smoke from the bottom up, shown before a bank's wait ends, rising and thinning as smoke does", function()
      local t = sonataNext:Resolve("Halloween")
      local K = t.Panel.Smoke
      local O = K.Open
      assert.is_true(O.Reveal[2] < 0.9, "shown before a bank's 1 second wait ends")
      assert.is_true(O.Reveal[2] <= O.Rise + 0.1, "the bag shown under the smoke about as it reaches the top")
      assert.is_true(K.Puffs.Size[1] * O.Start >= O.Spacing, "puffs overlapping from the start, covering the bag")
      assert.are.equal("Puff", K.Puffs.Texture)
      assert.is_true(K.Puffs.Alpha[2] < 1, "translucent")
      assert.is_true(K.Puffs.Alpha[1] < K.Puffs.Alpha[2], "some thinner than others")
      assert.is_true(O.Start < 1 and O.Growth > 1.4, "swelling as it rises")
      assert.is_true(O.Buoyancy > 0, "rising faster and faster, as warm smoke does")
      assert.is_true(O.Swirl[1] > 0 and O.Swirl[2] > 0, "curling")
      assert.is_true(O.Life[1] < O.Life[2], "each puff thinning away in its own time")
      assert.is_true(K.Sparks.Count > 0, "embers in it")
    end)

    -- Asked: "make the bag 'turn into' several bats, like 10-15 bats, and fly away in random directions off screen", then:
    -- "no puff of smokes: how the frost theme shatters, we want the bag break up *and morph* into bats".
    it("breaks up into 10 to 15 pieces of itself that turn into bats as it closes, and flutters bats out of its header",
      function()
      local t = sonataNext:Resolve("Halloween")
      local B = t.Panel.Bats
      assert.is_true(B.Close.Count[1] >= 10 and B.Close.Count[2] <= 15)
      assert.is_nil(B.Close.Puff, "no smoke")
      assert.are.equal(t.Panel.Fill.Texture, B.Close.Pieces.Texture, "pieces of its own body")
      assert.is_true(B.Close.Shudder > 0 and B.Close.Break > 0 and B.Close.Morph > 0, "trembles, breaks, morphs")
      assert.is_true(B.Close.Shudder < 0.3, "breaking up soon after it is closed")
      assert.are.equal(4, B.Frames, "bats.png: four frames side by side")
      local data = readFile(t.Textures.Bats)
      local w, h = data:byte(17) * 2 ^ 24 + data:byte(18) * 2 ^ 16 + data:byte(19) * 256 + data:byte(20),
        data:byte(21) * 2 ^ 24 + data:byte(22) * 2 ^ 16 + data:byte(23) * 256 + data:byte(24)
      assert.are.equal(4 * h, w, "four square frames")
      assert.is_true(B.Flutter.OnOpen)
    end)

    it("keeps a black cat on a jack-o'-lantern at each size, the cat blinking and its candle flickering", function()
      local t = sonataNext:Resolve("Halloween")
      for _, size in ipairs({ "Full", "Small" }) do
        local cat, eyes, face
        for _, piece in ipairs(t.Panel.Ornaments) do
          if piece.Sizes == size then
            if piece.Texture == "Cat" then cat = piece end
            if piece.Texture == "CatEyes" then eyes = piece end
            if piece.Texture == "PumpkinFace" then face = piece end
          end
        end
        assert.is_not_nil(cat, size)
        assert.is_not_nil(eyes.Motion.Blink, size .. ": blinking")
        assert.is_not_nil(face.Motion.Flicker, size .. ": flickering")
        for _, key in ipairs({ "Point", "Anchor", "Width", "Height", "X", "Y" }) do
          assert.are.equal(cat[key], eyes[key], size .. ": the eyes over the cat exactly (" .. key .. ")")
        end
        assert.is_true(eyes.SubLevel > cat.SubLevel, size .. ": the eyes over the cat")
      end
    end)

    it("drips goo along its top, clear of the title and the header buttons", function()
      local t = sonataNext:Resolve("Halloween")
      local drips
      for _, piece in ipairs(t.Panel.Ornaments) do
        if piece.Texture == "Drips" then drips = piece end
      end
      assert.are.equal("TOP", drips.Point)
      assert.is_true(drips.Height < t.Layout.TitleTop and drips.Height < t.Layout.HeaderButtonTop)
      assert.are.equal("Ink", drips.Color)
    end)

    it("lets autumn leaves fall and grows a vine along its footer", function()
      local t = sonataNext:Resolve("Halloween")
      local wheres = {}
      for _, entry in ipairs(t.Panel.Snow.Flakes) do
        assert.are.equal("Leaf", entry.Texture)
        assert.are.equal("BLEND", entry.BlendMode, "flat, not light")
        wheres[entry.Where] = true
      end
      assert.are.same({ Body = true, Feather = true }, wheres)
      assert.are.equal("Vine", t.Panel.Threads[1].Texture)
      assert.are.equal("BOTTOM", t.Panel.Threads[1].Anchor)
    end)
  end)

  -- Make It So (next-themes.md §24): a starship's computer, beaming in and out, an LCARS frame, a comm badge, the
  -- holodeck's grid and stars at warp. Asked: "star trek TNG themed, the bags obviously need the star trek beam down, and
  -- beam up animation for appearing and closing. star trek comm badge is a part of the theme as well ... LCARS is an
  -- option, but maybe also holodeck too".
  describe("Make It So", function()
    local function readFile(path)
      local file = path:gsub("^Interface\\AddOns\\BetterBags\\", ""):gsub("\\", "/")
      local f = io.open(file, "rb")
      assert.is_not_nil(f, file)
      local data = f:read("*a")
      f:close()
      return data, file
    end

    local function theme()
      return sonataNext:Resolve("MakeItSo")
    end

    it("draws its display text in Antonio, which it ships with its license, in the locales it covers", function()
      local t = theme()
      local files = {}
      for role, spec in pairs(t.Fonts) do
        if spec.File ~= nil and spec.File:find("makeitso", 1, true) then
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
      assert.are.equal(2, count, "bold and semibold")
      local license = readFile("Interface\\AddOns\\BetterBags\\fonts\\makeitso\\Antonio_OFL.txt")
      assert.is_truthy(license:find("SIL Open Font License", 1, true))
      assert.is_not_nil(t.Fonts.Title.File, "the title")
      assert.is_not_nil(t.Fonts.Section.File, "sections")
      assert.is_not_nil(t.Fonts.Tab.File, "tabs")
    end)

    it("ships every texture it names, as a PNG", function()
      local t = theme()
      local count = 0
      for name, path in pairs(t.Textures) do
        if path:find("textures\\next\\makeitso\\", 1, true) then
          count = count + 1
          local data, file = readFile(path)
          assert.are.equal("\137PNG\r\n\26\n", data:sub(1, 8), name .. ": " .. file)
        end
      end
      assert.are.equal(28, count)
    end)

    -- Asked: "the bags obviously need the star trek beam down, and beam up animation for appearing and closing".
    it("beams down, shown before a bank's wait ends, and beams up, in the transporter's pale blue", function()
      local B = theme().Panel.Beam
      assert.is_true(B.Open.Reveal[2] < 0.9, "materialized before a bank's 1 second wait ends")
      assert.is_true(B.Open.Sparkles[4] > B.Open.Reveal[2], "its shimmer going out after")
      assert.is_true(B.Close.Fade[2] < B.Close.Sparkles[4], "gone before its shimmer is")
      assert.is_true(B.Open.Glow[2] < B.Open.Reveal[2], "glowing before it is solid")
      assert.are.equal("Transporter", B.Column.Color)
      local blue = theme().Palette.Transporter
      assert.is_true(blue[3] > blue[1], "blue")
      assert.is_true(B.Sparkles.Drift[2] > 0 and B.Sparkles.Twinkle[1] > 0, "rippling and twinkling")
    end)

    -- An LCARS frame: the header's buttons are the side bar's blocks, each in its own colour and its glyph, the bar's
    -- width across.
    it("puts its header buttons down an LCARS side bar, each a block the bar's width across", function()
      local t = theme()
      local B = t.Header.Buttons
      assert.is_false(B.Rail.Outside == true, "inside the body")
      for key, icon in pairs(B.Icons) do
        if key ~= "closeButton" then
          assert.is_false(icon.Glyph, key)
          assert.is_true(math.abs(t.Layout.HeaderButton * icon.Scale - B.Rail.Width) < 1e-9, key .. " the bar's width")
          assert.are.equal("BlockLight", icon.Highlight.Texture, key)
        end
      end
      for key in pairs(sonataNext:Resolve("Default").Header.Buttons.Icons) do
        assert.is_not_nil(B.Icons[key], key .. " has a block")
      end
      assert.are.equal(B.Rail.Start + 4, B.Rail.Top, "a gap between the elbow and the first block")
      local elbow = t.Panel.Ornaments[1]
      assert.are.equal("ElbowTop", elbow.Texture)
      assert.are.equal(B.Rail.Start, elbow.Height, "the elbow ends where the side bar starts")
    end)

    -- Tap your comm badge: the close button stands under it, its own icon blank.
    it("closes from its comm badge, which chirps once it has beamed in", function()
      local t = theme()
      local pin = t.Header.Buttons.Pinned.closeButton
      assert.are.equal("Blank", t.Header.Buttons.Icons.closeButton.Texture)
      local badge, glint
      for _, piece in ipairs(t.Panel.Ornaments) do
        if piece.Texture == "CommBadge" then badge = piece end
        if piece.Motion and piece.Motion.Flash then glint = piece end
      end
      assert.are.equal(pin.Point, badge.Point)
      -- Larger than the button, centered on where the pin puts it (Y down, X inward).
      local over = (badge.Width - t.Layout.HeaderButton) / 2
      assert.is_true(over > 0, "larger than the button")
      assert.are.equal(badge.Width, badge.Height)
      assert.are.same({ -pin.X - over, -pin.Y - over }, { badge.X, badge.Y }, "centered on the button")
      assert.are.same({ badge.X + badge.Width / 2, badge.Y + badge.Height / 2 },
        { glint.X + glint.Width / 2, glint.Y + glint.Height / 2 }, "the glint centered on the badge")
      assert.is_true(badge.Above, "over the content")
      assert.is_true(glint.Above and glint.SubLevel > badge.SubLevel, "the glint over the badge")
      assert.is_true(glint.Motion.Flash.First > t.Panel.Beam.Open.Reveal[2], "once it has beamed in")
    end)

    it("lays the holodeck's grid behind the items, stars streaking past at warp in its edge", function()
      local t = theme()
      assert.are.equal("Holodeck", t.Panel.Fill.Texture)
      assert.is_true(t.Panel.Fill.HorizTile and t.Panel.Fill.VertTile, "repeating")
      for _, entry in ipairs(t.Panel.Snow.Flakes) do
        assert.are.equal("Feather", entry.Where)
        assert.are.same({ 0, 0 }, entry.Fall, "across, not falling")
        assert.is_true(entry.Drift > 0)
        assert.are.equal(0, entry.Spin, "never turned: a streak stays a streak")
      end
      assert.is_true(t.Panel.Snow.Gusts.Strength > 300, "a jump to warp")
    end)

    -- Asked, after the first look: "softer colors, maybe a bit more translucent in the title of each section, more..
    -- modern a bit. i'll let you decide what this means".
    it("draws in soft LCARS colours: none as saturated as the original's", function()
      local P = theme().Palette
      for _, name in ipairs({ "LcarsOrange", "LcarsPeach", "LcarsLilac", "LcarsBlue", "LcarsSalmon", "LcarsRed", "Sky" }) do
        local c = P[name]
        local hi, lo = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
        assert.is_true((hi - lo) / hi <= 0.6, name .. " soft")
      end
    end)

    it("writes its section names in peach on glass, a solid tip before them, the bar above the icons", function()
      local t = theme()
      for _, role in ipairs({ "Section", "SectionRecent", "SectionFree" }) do
        assert.are.equal("LcarsPeach", t.Fonts[role].Color, role)
      end
      local H = t.Sections.Header
      assert.are.equal("SectionBar", H.Texture)
      assert.is_true(H.Height < t.Layout.SectionHeader, "room between the bar and the first row of icons")
      assert.is_true(t.Sections.Title.X > 0)
    end)

    it("draws its tabs as glass, the chosen one solid with its name in black", function()
      local t = theme()
      local glass = t.Palette[t.Tabs.Fill.Color][4]
      assert.is_true(glass < 0.6, "the others translucent")
      assert.are.equal("LcarsOrange", t.Tabs.SelectedFill.Color)
      assert.are.equal("Black", t.Fonts.TabSelected.Color)
      assert.is_false(t.Fonts.TabSelected.Shadow)
      assert.are.equal("LcarsPeach", t.Fonts.Tab.Color)
      assert.are.equal("LcarsTab", t.Tabs.Fill.Texture)
    end)

    it("is a pane of glass: its holodeck and side bar translucent, its title in LCARS orange", function()
      local t = theme()
      -- Drawn in its colour's alpha (NextStyle:Paint).
      assert.is_true(t.Palette[t.Panel.Fill.Color][4] < 1, "the body")
      local rail = t.Palette[t.Header.Buttons.Rail.Fill.Color]
      assert.is_true(rail[4] < 0.5, "the side bar behind its blocks")
      assert.are.equal("LcarsOrange", t.Fonts.Title.Color)
    end)

    -- Asked: "corner at the top left and bottom left peak out around the LCARS, i think we need a way to shape the window
    -- itself".
    it("rounds its inner corners as round as the elbows round them, its outer ones square", function()
      local C = theme().Panel.Corners
      assert.is_true(C.TOPINNER > 0 and C.BOTTOMINNER > 0)
      assert.is_nil(C.TOPOUTER)
      assert.is_nil(C.BOTTOMOUTER)
      assert.are.same({}, sonataNext:Check("MakeItSo"))
    end)

    -- Asked: "make sure it covers the window + it's decoration fully", "leave tabs out", and "the top and bottom beam are
    -- cut off extremely clean on the horizontal plane".
    it("beams past the window all round, fading out above and below it", function()
      local B = theme().Panel.Beam
      assert.is_true(B.Margin > 0)
      assert.is_true(B.Ends >= 40, "long, soft ends")
    end)
  end)

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
