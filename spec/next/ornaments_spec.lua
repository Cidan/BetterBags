-- ornaments_spec.lua -- NextOrnaments (next/ornaments.lua): a Next theme's ornaments (Panel.Ornaments,
-- next-themes.md): art anchored to a panel body's corners and edges, drawn for a body whose inner side (the one
-- away from its screen edge) is on the left and mirrored for the right, on whole pixels at rest, with ambient
-- motion (sway, spin, pulse, bob) on the client's animation groups. Asked: borders in the spirit of the classic
-- race themes, "smaller and less large, more tasteful, and animated feeling".
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local layout = dofile("spec/helpers/layout.lua")

LoadBetterBagsModule("core/context.lua")
-- The panels a piece may be on are named by their bag kinds (core/constants.lua), the kinds another spec's
-- Constants stub leaves out added for this one.
local const, createdConstants = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or {}
local addedKinds = {}
for name, kind in pairs({ UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = 2 }) do
  if const.BAG_KIND[name] == nil then
    const.BAG_KIND[name] = kind
    table.insert(addedKinds, name)
  end
end
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextOrnaments", "next/ornaments.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local ornaments = addon:GetModule("NextOrnaments")
local pixel = addon:GetModule("NextPixel")

local ROOTS = "Interface\\AddOns\\BetterBags\\textures\\next\\themes\\spec\\roots.png"
local LEAF = "Interface\\AddOns\\BetterBags\\textures\\next\\themes\\spec\\leaf.png"

describe("NextOrnaments", function()
  local undo

  -- panelOn makes what the ornaments read of a panel: its frame, its body (filling it here), the screen side it
  -- belongs to, and its size.
  local function panelOn(side, small, kind)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pixel:Snap(UIParent, 100), -pixel:Snap(UIParent, 50))
    pixel:Size(frame, 400, 600)
    local body = CreateFrame("Frame", nil, frame)
    body:SetAllPoints(frame)
    local panel = { frame = frame, body = body, side = side, small = small == true, kind = kind or 0 }
    function panel:IsSmall() return self.small end
    panel.ornaments = ornaments:Create(panel)
    return panel
  end

  local function theme(list)
    UseNextTheme({ Textures = { Roots = ROOTS, Leaf = LEAF }, Panel = { Ornaments = list } })
  end

  local function texture(panel, i)
    return panel.ornaments.pieces[i].texture
  end

  local function points(region)
    local out = {}
    for i = 1, region:GetNumPoints() do
      local point, rel, relPoint, x, y = region:GetPoint(i)
      out[i] = { point, rel, relPoint, x, y }
    end
    return out
  end

  local function near(a, b)
    return math.abs(a - b) < 1e-9
  end

  before_each(function()
    undo = layout.UseScreen(3396, 1362, 0.65)
  end)

  after_each(function()
    undo()
    UseNextTheme(nil)
  end)

  describe("placing", function()
    it("lays a span along the inner side, its art repeating every Tile down it, smooth", function()
      theme({ { Texture = "Roots", Point = "INNER", Width = 20, Tile = 100, Start = 10, End = 20, X = -6 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local x, start, finish = pixel:Snap(t, -6), pixel:Snap(t, 10), pixel:Snap(t, 20)
      assert.are.same({ { "TOPLEFT", panel.body, "TOPLEFT", x, -start }, { "BOTTOMLEFT", panel.body, "BOTTOMLEFT", x, finish } },
        points(t))
      assert.is_true(near(pixel:Length(t, 20), t:GetWidth()))
      assert.are.equal(ROOTS, t:GetTexture())
      assert.are.same({ nil, "REPEAT", "TRILINEAR" }, { t._wrapH, t._wrapV, t._filterMode })
      local length = panel.body:GetHeight() - start - finish
      local ulx, uly, llx, lly, urx = t:GetTexCoord()
      assert.are.same({ 0, 0, 0 }, { ulx, uly, llx })
      assert.is_true(near(length / 100, lly), "repeats every 100 down its length")
      assert.are.equal(1, urx)
      assert.is_true(t:IsShown())
    end)

    it("mirrors it on a panel whose inner side is on the right", function()
      theme({ { Texture = "Roots", Point = "INNER", Width = 20, Tile = 100, X = -6 } })
      local panel = panelOn("LEFT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local x = pixel:Snap(t, 6)
      assert.are.same({ { "TOPRIGHT", panel.body, "TOPRIGHT", x, 0 }, { "BOTTOMRIGHT", panel.body, "BOTTOMRIGHT", x, 0 } },
        points(t))
      local ulx, _, _, _, urx = t:GetTexCoord()
      assert.are.same({ 1, 0 }, { ulx, urx }, "drawn for the left, flipped")
    end)

    it("spans the top edge from its inner end to its outer end, its art repeating every Tile across", function()
      theme({ { Texture = "Roots", Point = "TOP", Height = 12, Tile = 80, Start = 30, End = 4, Y = -3 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local y, inner, outer = pixel:Snap(t, -3), pixel:Snap(t, 30), pixel:Snap(t, 4)
      assert.are.same({ { "TOPLEFT", panel.body, "TOPLEFT", inner, -y }, { "TOPRIGHT", panel.body, "TOPRIGHT", -outer, -y } },
        points(t))
      assert.are.same({ "REPEAT", nil }, { t._wrapH, t._wrapV })
      local _, _, _, _, urx = t:GetTexCoord()
      assert.is_true(near((panel.body:GetWidth() - inner - outer) / 80, urx))
      local mirrored = panelOn("LEFT")
      mirrored.ornaments:Style()
      assert.are.same({ { "TOPRIGHT", mirrored.body, "TOPRIGHT", -inner, -y }, { "TOPLEFT", mirrored.body, "TOPLEFT", outer, -y } },
        points(texture(mirrored, 1)), "the inner end on the right")
    end)

    it("places a piece by a corner, X toward the middle and Y down, mirrored, Anchor naming its own point", function()
      theme({
        { Texture = "Leaf", Point = "TOPINNER", X = 4, Y = 30, Width = 32, Height = 48 },
        { Texture = "Leaf", Point = "BOTTOMOUTER", Anchor = "TOPOUTER", X = 2, Y = -8, Width = 16, Height = 16 },
      })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local a, b = texture(panel, 1), texture(panel, 2)
      assert.are.same({ { "TOPLEFT", panel.body, "TOPLEFT", pixel:Snap(a, 4), -pixel:Snap(a, 30) } }, points(a))
      assert.is_true(near(pixel:Length(a, 32), a:GetWidth()) and near(pixel:Length(a, 48), a:GetHeight()))
      assert.are.same({ { "TOPRIGHT", panel.body, "BOTTOMRIGHT", -pixel:Snap(b, 2), pixel:Snap(b, 8) } }, points(b))
      local mirrored = panelOn("LEFT")
      mirrored.ornaments:Style()
      local m = texture(mirrored, 1)
      assert.are.same({ { "TOPRIGHT", mirrored.body, "TOPRIGHT", -pixel:Snap(m, 4), -pixel:Snap(m, 30) } }, points(m))
      local ulx, _, _, _, urx = m:GetTexCoord()
      assert.are.same({ 1, 0 }, { ulx, urx })
    end)

    it("draws its art in its color, alpha, blend mode and layer", function()
      UseNextTheme({ Textures = { Leaf = LEAF }, Palette = { Moss = { 0.2, 0.6, 0.3, 1 } }, Panel = { Ornaments = {
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Color = "Moss", Alpha = 0.5, BlendMode = "ADD",
          Layer = "OVERLAY", SubLevel = 3 },
      } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local r, g, b = t:GetVertexColor()
      assert.are.same({ 0.2, 0.6, 0.3 }, { r, g, b })
      assert.are.equal(0.5, t:GetAlpha())
      assert.are.equal("ADD", t:GetBlendMode())
      assert.are.same({ "OVERLAY", 3 }, { t:GetDrawLayer() })
    end)

    it("shows a piece only at the size it is for", function()
      theme({
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Sizes = "Full" },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Sizes = "Small" },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 },
      })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      assert.are.same({ true, false, true }, { texture(panel, 1):IsShown(), texture(panel, 2):IsShown(), texture(panel, 3):IsShown() })
      panel.small = true
      panel.ornaments:Layout()
      assert.are.same({ false, true, true }, { texture(panel, 1):IsShown(), texture(panel, 2):IsShown(), texture(panel, 3):IsShown() })
    end)

    -- Art that is part of its file (GW2_UI's header and footer bands, docs/next-gw2-theme.md).
    it("crops a piece's art to its TexCoords, mirrored on the other side, through a resize", function()
      theme({
        { Texture = "Leaf", Point = "TOPOUTER", Width = 32, Height = 16, TexCoords = { 0.25, 1, 0.3, 0.9 } },
        { Texture = "Roots", Point = "BOTTOM", Height = 34, TexCoords = { 0, 1, 0, 0.53 } },
      })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local function coords(t)
        local ulx, uly, _, lly, urx = t:GetTexCoord()
        return { ulx, urx, uly, lly }
      end
      assert.are.same({ 0.25, 1, 0.3, 0.9 }, coords(texture(panel, 1)))
      assert.are.same({ 0, 1, 0, 0.53 }, coords(texture(panel, 2)))
      pixel:Size(panel.frame, 500, 700)
      panel.body:GetScript("OnSizeChanged")(panel.body, 500, 700)
      assert.are.same({ 0.25, 1, 0.3, 0.9 }, coords(texture(panel, 1)), "kept as the body changes size")
      local mirrored = panelOn("LEFT")
      mirrored.ornaments:Style()
      assert.are.same({ 1, 0.25, 0.3, 0.9 }, coords(texture(mirrored, 1)))
      assert.are.same({ 1, 0, 0, 0.53 }, coords(texture(mirrored, 2)))
    end)

    -- GW2_UI puts its bag's emblem on its bag, bank and guild bank, and another on its merchant.
    it("shows a piece only on the panels it names, and everywhere without Panels", function()
      theme({
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Panels = { "Backpack", "Bank", "GuildBank" } },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Panels = { "Vendor" } },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 },
      })
      local function shown(kind)
        local panel = panelOn("RIGHT", false, kind)
        panel.ornaments:Style()
        return { texture(panel, 1):IsShown(), texture(panel, 2):IsShown(), texture(panel, 3):IsShown() }
      end
      assert.are.same({ true, false, true }, shown(0), "the backpack")
      assert.are.same({ true, false, true }, shown(1), "the bank")
      assert.are.same({ true, false, true }, shown(2), "the guild bank")
      assert.are.same({ false, true, true }, shown(-1), "the vendor")
    end)

    it("repeats its art down the body's height as the body changes size", function()
      theme({ { Texture = "Roots", Point = "INNER", Width = 20, Tile = 100 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      pixel:Size(panel.frame, 400, 300)
      panel.body:GetScript("OnSizeChanged")(panel.body, panel.body:GetWidth(), panel.body:GetHeight())
      local _, _, _, lly = texture(panel, 1):GetTexCoord()
      assert.is_true(near(panel.body:GetHeight() / 100, lly))
    end)

    it("puts every piece at rest on whole pixels", function()
      theme({
        { Texture = "Roots", Point = "INNER", Width = 21.3, Tile = 100, Start = 7.7, End = 3.3, X = -5.4 },
        { Texture = "Roots", Point = "TOP", Height = 9.6, Tile = 40, Start = 11.1, End = 2.2, Y = 1.7 },
        { Texture = "Leaf", Point = "TOPINNER", Anchor = "TOPOUTER", X = 3.3, Y = 27.7, Width = 31.5, Height = 47.3 },
        { Texture = "Leaf", Point = "BOTTOMOUTER", X = 1.1, Y = -2.6, Width = 15.5, Height = 15.5 },
      })
      for _, side in ipairs({ "RIGHT", "LEFT" }) do
        local panel = panelOn(side)
        panel.ornaments:Style()
        assert.are.same({}, layout.PixelCheck(panel.frame), side)
      end
    end)
  end)

  -- The Plain theme (docs/next-plain-theme.md): the retail bag window's portrait, its art round
  -- (PortraitFrameBaseTemplate's CircleMask, TempPortraitAlphaMask, 2, 0, 2 and 4 in), the bag's icon or the NPC
  -- (SetPortraitToUnit("npc")), never flipped.
  describe("portraits", function()
    local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local BAG = "Interface\\Icons\\Inv_misc_bag_08"

    after_each(function()
      MockUnits.npc = nil
    end)

    -- Classic's title band (_UI-Frame-TitleTileBg: Interface\FrameGeneral\_UI-Frame, a 17-pixel strip of it, tiled
    -- across): a span tiled along it, cropped across it by its TexCoords.
    it("tiles a span along it and crops it across by its TexCoords", function()
      theme({ { Texture = "Interface\\FrameGeneral\\_UI-Frame", TexCoords = { 0, 1, 0.2890625, 0.421875 }, Point = "TOP",
        Height = 17, Tile = 256 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local ulx, uly, _, lly, urx = t:GetTexCoord()
      assert.are.same({ 0, 0.2890625, 0.421875 }, { ulx, uly, lly })
      assert.is_true(near(panel.body:GetWidth() / 256, urx), "repeats every 256 across")
    end)

    it("draws an atlas, flipped on a mirrored panel unless told not to", function()
      theme({ { Atlas = "spec-corner", Point = "TOPINNER", Width = 20, Height = 20 },
        { Atlas = "spec-corner", Point = "TOPOUTER", Width = 20, Height = 20, Mirror = false } })
      local panel = panelOn("LEFT")
      panel.ornaments:Style()
      local t, kept = texture(panel, 1), texture(panel, 2)
      assert.are.equal("spec-corner", t:GetAtlas())
      local ulx, _, _, _, urx = t:GetTexCoord()
      assert.are.same({ 1, 0 }, { ulx, urx })
      ulx, _, _, _, urx = kept:GetTexCoord()
      assert.are.same({ 0, 1 }, { ulx, urx }, "Mirror = false")
      local point, rel, relPoint = kept:GetPoint(1)
      assert.are.same({ "TOPLEFT", panel.body, "TOPLEFT" }, { point, rel, relPoint }, "placed mirrored all the same")
    end)

    it("cuts a piece round by its mask, inset into it and mirrored with the panel, and stops when it has none", function()
      theme({ { Texture = BAG, Point = "TOPINNER", Width = 36, Height = 36,
        Mask = { Texture = MASK, Inset = { Left = 2, Right = 3, Top = 0, Bottom = 4 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      assert.are.equal(1, t:GetNumMaskTextures())
      local mask = t:GetMaskTexture(1)
      assert.are.equal(MASK, mask:GetTexture())
      assert.are.same({ { "TOPLEFT", t, "TOPLEFT", pixel:Snap(t, 2), 0 }, { "BOTTOMRIGHT", t, "BOTTOMRIGHT", -pixel:Snap(t, 3), pixel:Snap(t, 4) } },
        points(mask))
      local mirrored = panelOn("LEFT")
      mirrored.ornaments:Style()
      local m = texture(mirrored, 1):GetMaskTexture(1)
      assert.are.same({ "TOPLEFT", texture(mirrored, 1), "TOPLEFT", pixel:Snap(t, 3), 0 }, { m:GetPoint(1) }, "its sides swapped")
      theme({ { Texture = BAG, Point = "TOPINNER", Width = 36, Height = 36 } })
      panel.ornaments:Style()
      assert.are.equal(0, t:GetNumMaskTextures())
    end)

    -- The original bags' menu button (frames/menubutton.lua) is over their border and their search box (strata HIGH): a
    -- piece that says Above is drawn on the panel's overlay, over the content and a frame drawn above it; its mask with it.
    it("draws a piece that says Above on the panel's overlay, its mask with it, and back on the frame without", function()
      theme({ { Texture = BAG, Point = "TOPINNER", Width = 48, Height = 60, Above = true, Layer = "OVERLAY", SubLevel = 7,
        Mask = { Texture = MASK } } })
      local panel = panelOn("RIGHT")
      panel.overlay = CreateFrame("Frame", nil, panel.frame)
      panel.ornaments:Style()
      local t = texture(panel, 1)
      assert.are.equal(panel.overlay, t:GetParent())
      assert.are.equal(panel.overlay, t:GetMaskTexture(1):GetParent())
      assert.are.same({ "OVERLAY", 7 }, { t:GetDrawLayer() })
      assert.is_true(t:IsShown())
      theme({ { Texture = BAG, Point = "TOPINNER", Width = 48, Height = 60 } })
      panel.ornaments:Style()
      assert.is_false(t:IsShown(), "the one above hidden")
      assert.are.equal(panel.frame, texture(panel, 1):GetParent())
      assert.is_true(texture(panel, 1):IsShown())
      theme({ { Texture = BAG, Point = "TOPINNER", Width = 48, Height = 60, Above = true } })
      panel.ornaments:Style()
      assert.are.equal(t, texture(panel, 1), "the same texture above again")
    end)

    it("draws a unit's portrait while there is one, its own art otherwise, as the panel shows", function()
      theme({ { Texture = BAG, Point = "TOPINNER", Width = 36, Height = 36, Unit = "npc" } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      assert.are.equal(BAG, t:GetTexture(), "no NPC")
      MockUnits.npc = true
      panel.ornaments:Start()
      assert.are.equal("npc", t._portraitUnit)
      MockUnits.npc = nil
      panel.ornaments:Start()
      assert.are.equal(BAG, t:GetTexture(), "gone again")
    end)
  end)

  describe("restyling", function()
    it("hides pieces a new theme no longer has, and every piece for a theme without ornaments", function()
      theme({
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4, Period = 3 } },
      })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      panel.ornaments:Start()
      local swaying = texture(panel, 2)
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 } })
      panel.ornaments:Style()
      assert.is_true(texture(panel, 1):IsShown())
      assert.is_false(swaying:IsShown())
      for _, group in pairs(panel.ornaments.pieces[2].groups) do
        assert.is_false(group:IsPlaying(), "its motion stopped")
      end
      UseNextTheme(nil)
      panel.ornaments:Style()
      assert.is_false(texture(panel, 1):IsShown(), "Default has none")
    end)

    it("reuses its textures across themes", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local first = texture(panel, 1)
      theme({ { Texture = "Roots", Point = "INNER", Width = 10, Tile = 50 } })
      panel.ornaments:Style()
      assert.are.equal(first, texture(panel, 1))
      assert.are.equal(ROOTS, first:GetTexture())
      assert.are.equal(2, first:GetNumPoints(), "anchored afresh")
    end)
  end)

  describe("motion", function()
    local function animations(group)
      local list = { group:GetAnimations() }
      table.sort(list, function(a, b) return a:GetOrder() < b:GetOrder() end)
      return list
    end

    it("sways a piece either way of its rest about its origin, mirrored on the other side", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10,
        Motion = { Sway = 6, Period = 4, Origin = "BOTTOMINNER" } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local group = panel.ornaments.pieces[1].groups.Sway
      assert.are.equal("REPEAT", group:GetLooping())
      local list = animations(group)
      assert.are.same({ 6, -12, 6 }, { list[1]:GetDegrees(), list[2]:GetDegrees(), list[3]:GetDegrees() })
      assert.are.same({ 1, 2, 3 }, { list[1]:GetOrder(), list[2]:GetOrder(), list[3]:GetOrder() })
      assert.are.same({ 1, 2, 1 }, { list[1]._duration, list[2]._duration, list[3]._duration })
      for _, anim in ipairs(list) do
        assert.are.same({ "BOTTOMLEFT", 0, 0 }, { anim:GetOrigin() })
      end
      -- Reported in game: "very jerky". Eased in and out on every step, the last step stopped dead at rest and the
      -- loop started again from a standstill, a halt mid-swing once a cycle. It eases only where it turns: out of
      -- rest at speed and slowing to its first turn, across between its turns, and from its last turn speeding back
      -- through rest, so it passes rest at full speed every time.
      assert.are.same({ "OUT", "IN_OUT", "IN" }, { list[1]._smoothing, list[2]._smoothing, list[3]._smoothing })
      local mirrored = panelOn("LEFT")
      mirrored.ornaments:Style()
      list = animations(mirrored.ornaments.pieces[1].groups.Sway)
      assert.are.same({ -6, 12, -6 }, { list[1]:GetDegrees(), list[2]:GetDegrees(), list[3]:GetDegrees() })
      assert.are.same({ "BOTTOMRIGHT", 0, 0 }, { list[1]:GetOrigin() })
    end)

    it("spins, pulses and bobs", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10,
        Motion = { Spin = 1, Pulse = { 0.4, 0.9 }, Bob = 2, Period = 30 } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local groups = panel.ornaments.pieces[1].groups
      local spin = animations(groups.Spin)
      assert.are.equal(1, #spin)
      assert.are.equal(-360, spin[1]:GetDegrees(), "clockwise")
      assert.are.equal(30, spin[1]._duration)
      assert.are.equal("NONE", spin[1]._smoothing)
      assert.are.same({ "CENTER", 0, 0 }, { spin[1]:GetOrigin() })
      assert.are.equal("REPEAT", groups.Spin:GetLooping())
      local pulse = animations(groups.Pulse)[1]
      assert.are.same({ 0.4, 0.9, 15 }, { pulse._fromAlpha, pulse._toAlpha, pulse._duration })
      assert.are.equal("BOUNCE", groups.Pulse:GetLooping())
      local bob = animations(groups.Bob)[1]
      assert.are.same({ x = 0, y = pixel:Snap(texture(panel, 1), 2) }, bob._offset)
      assert.are.equal("BOUNCE", groups.Bob:GetLooping())
    end)

    it("moves only while the panel shows, each piece from a phase of its own", function()
      theme({
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4, Period = 4, Delay = 1.5 } },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Sizes = "Small", Motion = { Pulse = { 0, 1 } } },
      })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local sway = panel.ornaments.pieces[1].groups.Sway
      assert.is_false(sway:IsPlaying())
      panel.ornaments:Start()
      assert.is_true(sway:IsPlaying())
      assert.are.equal(1.5, sway._offset)
      assert.is_nil(panel.ornaments.pieces[2].groups, "a still piece has none")
      assert.is_false(panel.ornaments.pieces[3].groups.Pulse:IsPlaying(), "not at this size")
      panel.ornaments:Stop()
      assert.is_false(sway:IsPlaying())
    end)

    it("names its moving pieces shown at the panel's size for the pixel checks: they rest nowhere", function()
      theme({
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4 } },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 },
        { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Sizes = "Small", Motion = { Sway = 4 } },
      })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local skip = {}
      panel.ornaments:MovingParts(skip)
      assert.is_true(skip[texture(panel, 1)])
      assert.is_nil(skip[texture(panel, 2)])
      assert.is_nil(skip[texture(panel, 3)], "hidden at this size: checked as nothing")
    end)

    it("starts a moving piece a size switch shows while the panel moves", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Sizes = "Small", Motion = { Pulse = { 0.2, 1 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      panel.ornaments:Start()
      local pulse = panel.ornaments.pieces[1].groups.Pulse
      assert.is_false(pulse:IsPlaying())
      panel.small = true
      panel.ornaments:Layout()
      assert.is_true(pulse:IsPlaying())
    end)

    it("drops a motion a new theme no longer gives a piece", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4 } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Pulse = { 0.2, 1 } } } })
      panel.ornaments:Style()
      panel.ornaments:Start()
      local groups = panel.ornaments.pieces[1].groups
      assert.is_nil(groups.Sway:GetAnimations(), "emptied")
      assert.is_false(groups.Sway:IsPlaying())
      assert.is_true(groups.Pulse:IsPlaying())
    end)
  end)

  -- The Glitch theme (next-themes.md §21): art over the whole body (a grid, scanlines, a CRT's vignette), art that
  -- scrolls (scanlines rolling, a grid drifting) and art that glitches now and then (a HUD bracket jumping, blinking,
  -- its art slipping). Scroll and Glitch run on a driver of the set's own, only while the panel shows.
  describe("a strip of drawings (Frames) that boils", function()
    local function coords(t)
      local ulx, _, _, _, urx = t:GetTexCoord()
      return ulx, urx
    end

    it("shows its first drawing at rest, whether it moves or not", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Frames = 3 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local left, right = coords(texture(panel, 1))
      assert.is_true(math.abs(left) < 1e-6)
      assert.is_true(math.abs(right - 1 / 3) < 1e-6)
    end)

    it("is mirrored with the panel", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Frames = 3 } })
      local panel = panelOn("LEFT")
      panel.ornaments:Style()
      local left, right = coords(texture(panel, 1))
      assert.is_true(math.abs(left - 1 / 3) < 1e-6)
      assert.is_true(math.abs(right) < 1e-6)
    end)

    local function boiling(fps, jiggle)
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, X = 20, Y = 20, Frames = 3,
        Motion = { Boil = { FPS = fps, Jiggle = jiggle } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      panel.ornaments:Start()
      return panel, panel.ornaments
    end

    it("draws itself again every pose, never the same drawing twice running", function()
      local _, set = boiling(10)
      local t = set.pieces[1].texture
      local last = coords(t)
      for _ = 1, 20 do
        set:Step(0.1)
        local now = coords(t)
        assert.is_true(math.abs(now - last) > 1e-6, "another drawing")
        assert.is_true(math.abs(now * 3 - math.floor(now * 3 + 0.5)) < 1e-6, "one of its three")
        last = now
      end
    end)

    it("holds a drawing for its whole pose", function()
      local _, set = boiling(10)
      local t = set.pieces[1].texture
      local last = coords(t)
      set:Step(0.04)
      set:Step(0.04)
      assert.are.equal(last, (coords(t)))
      set:Step(0.04)
      assert.are_not.equal(last, (coords(t)))
    end)

    it("draws FPS poses a second, keeping the time a slow frame ran over", function()
      local _, set = boiling(10)
      local t = set.pieces[1].texture
      local poses, last = 0, coords(t)
      for _ = 1, 25 do
        set:Step(0.04)
        local now = coords(t)
        if now ~= last then
          poses, last = poses + 1, now
        end
      end
      assert.are.equal(10, poses, "ten poses in a second")
    end)

    it("jiggles on whole pixels, and only by its Jiggle", function()
      local _, set = boiling(10, 2)
      local t = set.pieces[1].texture
      local _, _, _, rest = t:GetPoint(1)
      local unit = addon:GetModule("NextPixel"):Unit(t)
      local moved = false
      for _ = 1, 30 do
        set:Step(0.1)
        local _, _, _, x = t:GetPoint(1)
        assert.is_true(math.abs(x - rest) <= 2 + unit, "by at most its Jiggle")
        local pixels = (x - rest) / unit
        assert.is_true(math.abs(pixels - math.floor(pixels + 0.5)) < 1e-6, "on whole pixels")
        moved = moved or x ~= rest
      end
      assert.is_true(moved)
    end)

    it("goes back to its first drawing, where it rests, as the panel hides", function()
      local _, set = boiling(10, 2)
      local t = set.pieces[1].texture
      local _, _, _, rest = t:GetPoint(1)
      for _ = 1, 7 do set:Step(0.1) end
      set:Stop()
      local left = coords(t)
      assert.is_true(math.abs(left) < 1e-6)
      local _, _, _, x = t:GetPoint(1)
      assert.are.equal(rest, x)
    end)

    it("moves only while the panel shows, and counts as a moving part", function()
      local panel, set = boiling(10)
      assert.is_not_nil(set.driver:GetScript("OnUpdate"))
      local skip = {}
      set:MovingParts(skip)
      assert.is_true(skip[set.pieces[1].texture])
      set:Stop()
      assert.is_nil(set.driver:GetScript("OnUpdate"))
      local _ = panel
    end)
  end)

  describe("a piece for some locales (Locales)", function()
    local saved

    before_each(function()
      saved = _G.GetLocale
    end)

    after_each(function()
      _G.GetLocale = saved
    end)

    it("shows in the locales it names, and only those", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Locales = { "enUS", "enGB" } } })
      _G.GetLocale = function() return "enGB" end
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      assert.is_true(texture(panel, 1):IsShown())
      _G.GetLocale = function() return "deDE" end
      panel.ornaments:Layout()
      assert.is_false(texture(panel, 1):IsShown())
    end)

    it("shows everywhere without any", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10 } })
      _G.GetLocale = function() return "koKR" end
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      assert.is_true(texture(panel, 1):IsShown())
    end)
  end)

  describe("glitch art", function()
    local savedRandom

    before_each(function()
      savedRandom = ornaments.Random
    end)

    after_each(function()
      ornaments.Random = savedRandom
    end)

    local function driver(panel)
      return panel.ornaments.driver
    end

    local function step(panel, dt)
      local d = driver(panel)
      d:GetScript("OnUpdate")(d, dt)
    end

    local function coords(t)
      local ulx, uly, _, lly, urx = t:GetTexCoord()
      return ulx, urx, uly, lly
    end

    it("fills the body, inset, its art repeating every Tile both ways, mirrored on the other side", function()
      theme({ { Texture = "Roots", Point = "BODY", Inset = { Left = 4, Right = 6, Top = 10, Bottom = 12 }, Tile = 50 } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local l, r, top, bottom = pixel:Snap(t, 4), pixel:Snap(t, 6), pixel:Snap(t, 10), pixel:Snap(t, 12)
      assert.are.same({ { "TOPLEFT", panel.body, "TOPLEFT", l, -top }, { "BOTTOMRIGHT", panel.body, "BOTTOMRIGHT", -r, bottom } },
        points(t))
      assert.are.same({ "REPEAT", "REPEAT", "TRILINEAR" }, { t._wrapH, t._wrapV, t._filterMode })
      local w, h = panel.body:GetWidth() - l - r, panel.body:GetHeight() - top - bottom
      local u0, u1, v0, v1 = coords(t)
      assert.is_true(near(0, u0) and near(w / 50, u1) and near(0, v0) and near(h / 50, v1))
      local mirrored = panelOn("LEFT")
      mirrored.ornaments:Style()
      t = texture(mirrored, 1)
      assert.are.same({ { "TOPLEFT", mirrored.body, "TOPLEFT", r, -top },
        { "BOTTOMRIGHT", mirrored.body, "BOTTOMRIGHT", -l, bottom } }, points(t), "its inner side on the right")
      u0, u1 = coords(t)
      assert.is_true(near(w / 50, u0) and near(0, u1), "flipped")
    end)

    it("stretches its art over the body without a Tile", function()
      theme({ { Texture = "Roots", Point = "BODY" } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      assert.are.same({ nil, nil }, { t._wrapH, t._wrapV })
      assert.are.same({ 0, 1, 0, 1 }, { coords(t) })
      assert.are.same({ { "TOPLEFT", panel.body, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", panel.body, "BOTTOMRIGHT", 0, 0 } }, points(t))
    end)

    it("scrolls a tiled piece's art Y units a second down and X across, only while it moves", function()
      theme({ { Texture = "Roots", Point = "BODY", Tile = 50, Motion = { Scroll = { X = 10, Y = 10 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      assert.is_nil(driver(panel) and driver(panel):GetScript("OnUpdate"), "still until the panel shows")
      panel.ornaments:Start()
      step(panel, 1)
      local t = texture(panel, 1)
      local w, h = panel.body:GetWidth(), panel.body:GetHeight()
      local u0, u1, v0, v1 = coords(t)
      -- Moved 10 right and 10 down: the art starts that far back in it, kept within a tile.
      assert.is_true(near(0.8, u0) and near(0.8 + w / 50, u1), "across: " .. u0)
      assert.is_true(near(0.8, v0) and near(0.8 + h / 50, v1), "down: " .. v0)
      local skip = {}
      panel.ornaments:MovingParts(skip)
      assert.is_true(skip[t], "it rests nowhere")
      panel.ornaments:Stop()
      assert.is_nil(driver(panel):GetScript("OnUpdate"))
    end)

    it("scrolls a span along its length", function()
      theme({ { Texture = "Roots", Point = "INNER", Width = 20, Tile = 100, Motion = { Scroll = { Y = 25 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      panel.ornaments:Start()
      step(panel, 1)
      local _, _, v0 = coords(texture(panel, 1))
      assert.is_true(near(0.75, v0), "a quarter of a tile down: " .. v0)
    end)

    it("glitches now and then: jumps by whole pixels, blinks and slips its art, then is back at rest", function()
      ornaments.Random = function() return 0.1 end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, X = 8, Y = 8, Alpha = 0.8,
        Motion = { Glitch = { Every = 2, Hold = 0.2, Jump = 5, Blink = 0.25, Slip = 0.5 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local rest = points(t)
      panel.ornaments:Start()
      -- Its first glitch after 2 * (0.3 + 1.4 * 0.1) = 0.88 seconds.
      step(panel, 0.5)
      assert.are.same(rest, points(t))
      step(panel, 0.5)
      local now = points(t)[1]
      -- (2 * 0.1 - 1) * 5 = -4: four units left and down, on whole pixels.
      assert.are.equal(rest[1][4] + pixel:Snap(t, -4), now[4])
      assert.are.equal(rest[1][5] + pixel:Snap(t, -4), now[5])
      assert.is_true(near(0.2, t:GetAlpha()), "blinked to a quarter")
      local u0, u1 = coords(t)
      assert.is_true(near(-0.4, u0) and near(0.6, u1), "its art slipped")
      local skip = {}
      panel.ornaments:MovingParts(skip)
      assert.is_true(skip[t])
      -- Rolled anew every GLITCH_STEP while it lasts, held in between.
      ornaments.Random = function() return 0.9 end
      step(panel, ornaments.GLITCH_STEP / 2)
      assert.are.equal(rest[1][4] + pixel:Snap(t, -4), points(t)[1][4], "held until its next roll")
      step(panel, ornaments.GLITCH_STEP * 0.75)
      assert.are.equal(rest[1][4] + pixel:Snap(t, 4), points(t)[1][4], "rolled anew")
      step(panel, 0.25)
      assert.are.same(rest, points(t), "back at rest after Hold")
      assert.is_true(near(0.8, t:GetAlpha()))
      assert.are.same({ 0, 1, 0, 1 }, { coords(t) })
    end)

    it("jumps a piece over the whole body as it glitches, by whole pixels", function()
      ornaments.Random = function() return 0.1 end
      theme({ { Texture = "Roots", Point = "BODY", Tile = 50,
        Motion = { Glitch = { Every = 1, Hold = 1, Jump = 5 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local rest = points(t)
      panel.ornaments:Start()
      step(panel, 0.5)
      for i = 1, 2 do
        assert.are.equal(rest[i][4] + pixel:Snap(t, -4), points(t)[i][4], "across")
        assert.are.equal(rest[i][5] + pixel:Snap(t, -4), points(t)[i][5], "down")
      end
    end)

    it("is back at rest when the panel hides mid-glitch", function()
      ornaments.Random = function() return 0.1 end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Alpha = 0.8,
        Motion = { Glitch = { Every = 1, Hold = 1, Jump = 5, Blink = 0.25, Slip = 0.5 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      local rest = points(t)
      panel.ornaments:Start()
      step(panel, 0.5)
      assert.are_not.same(rest, points(t))
      panel.ornaments:Stop()
      assert.are.same(rest, points(t))
      assert.is_true(near(0.8, t:GetAlpha()))
      assert.are.same({ 0, 1, 0, 1 }, { coords(t) })
    end)

    -- The Halloween theme's black cat blinking now and then (next-themes.md §23): its eyes out for Time and back, now and
    -- then twice in a row.
    it("blinks now and then: out for its Time, back at its alpha, sometimes twice in a row", function()
      ornaments.Random = function() return 0.1 end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Alpha = 0.8,
        Motion = { Blink = { Every = { 2, 4 }, Time = 0.1, Twice = 0.5 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      panel.ornaments:Start()
      -- Its first blink after 2 + (4 - 2) * 0.1 = 2.2 seconds.
      step(panel, 2.1)
      assert.is_true(near(0.8, t:GetAlpha()))
      local skip = {}
      panel.ornaments:MovingParts(skip)
      assert.is_true(skip[t], "it rests nowhere")
      step(panel, 0.15)
      assert.are.equal(0, t:GetAlpha(), "shut")
      step(panel, 0.1)
      assert.is_true(near(0.8, t:GetAlpha()), "open again")
      step(panel, 0.1)
      assert.are.equal(0, t:GetAlpha(), "and shut again (0.1 is below Twice)")
      step(panel, 0.1)
      assert.is_true(near(0.8, t:GetAlpha()), "then open")
      step(panel, 1)
      assert.is_true(near(0.8, t:GetAlpha()), "not a third time")
      panel.ornaments:Stop()
      assert.is_true(near(0.8, t:GetAlpha()))
    end)

    it("is open again when the panel hides mid-blink", function()
      ornaments.Random = function() return 0.9 end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Alpha = 0.8,
        Motion = { Blink = { Every = { 1, 1 }, Time = 0.3 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      panel.ornaments:Start()
      step(panel, 1.1)
      assert.are.equal(0, t:GetAlpha())
      panel.ornaments:Stop()
      assert.is_true(near(0.8, t:GetAlpha()))
    end)

    -- And its jack-o'-lantern's candle flickering.
    it("flickers like a candle: its alpha wandering between Low and its own, never still", function()
      local seq, i = { 0, 1, 0.5, 0.2, 0.9, 0.35, 0.75 }, 0
      ornaments.Random = function()
        i = i % #seq + 1
        return seq[i]
      end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Alpha = 0.8,
        Motion = { Flicker = { Low = 0.5, Speed = 10 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      panel.ornaments:Start()
      local seen = {}
      for _ = 1, 30 do
        step(panel, 0.03)
        local a = t:GetAlpha()
        assert.is_true(a >= 0.8 * 0.5 - 1e-9 and a <= 0.8 + 1e-9, "between Low and its own: " .. a)
        seen[math.floor(a * 1000)] = true
      end
      local n = 0
      for _ in pairs(seen) do n = n + 1 end
      assert.is_true(n > 10, "never still")
      local skip = {}
      panel.ornaments:MovingParts(skip)
      assert.is_true(skip[t])
      panel.ornaments:Stop()
      assert.is_true(near(0.8, t:GetAlpha()), "back at its own once still")
    end)

    -- Reported: "the Next theme has no color named LcarsLilac", switching away from Make It So. Restyling stopped the
    -- moving pieces with their old theme's spec, in the new theme's palette.
    for name, motion in pairs({
      Flicker = { Flicker = { Low = 0.5, Speed = 10 } },
      Blink = { Blink = { Every = { 1, 2 }, Time = 0.1 } },
      Glitch = { Glitch = { Every = 1, Hold = 1, Jump = 5, Blink = 0.25, Slip = 0.5 } },
      Flash = { Flash = { Every = { 1, 2 }, Time = 0.1, First = 0.01 } },
      Boil = { Boil = { FPS = 8, Jiggle = 1 } },
    }) do
      it("restyles for another theme a piece caught in its " .. name .. ", in a color only its old theme has", function()
        ornaments.Random = function() return 0.25 end
        UseNextTheme({ Palette = { OnlyHere = { 1, 0, 0, 1 } }, Textures = { Roots = ROOTS, Leaf = LEAF },
          Panel = { Ornaments = { { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Color = "OnlyHere",
            Motion = motion } } } })
        local panel = panelOn("RIGHT")
        panel.ornaments:Style()
        panel.ornaments:Start()
        for _ = 1, 40 do step(panel, 0.05) end
        UseNextTheme({ Textures = { Roots = ROOTS, Leaf = LEAF }, Panel = { Ornaments = {
          { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Alpha = 0.7 } } } })
        panel.ornaments:Style()
        assert.is_true(near(0.7, texture(panel, 1):GetAlpha()), "at the new theme's alpha")
      end)
    end

    -- The Make It So theme's comm badge chirping (next-themes.md §24): a glint over it, unseen, that flashes a moment
    -- after the bag has beamed in and now and then after.
    it("flashes now and then: unseen at rest, up to its alpha and out again over its Time, first after First", function()
      ornaments.Random = function() return 0.25 end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16, Alpha = 0.8,
        Motion = { Flash = { Every = { 4, 8 }, Time = 0.4, First = 0.7 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      assert.are.equal(0, t:GetAlpha(), "unseen at rest")
      panel.ornaments:Start()
      local skip = {}
      panel.ornaments:MovingParts(skip)
      assert.is_true(skip[t], "it rests nowhere")
      step(panel, 0.65)
      assert.are.equal(0, t:GetAlpha(), "not yet")
      step(panel, 0.15)
      -- 0.1 into its 0.4: sin(pi / 4) of its alpha.
      assert.is_true(near(0.8 * math.sin(math.pi / 4), t:GetAlpha()))
      step(panel, 0.1)
      assert.is_true(near(0.8, t:GetAlpha()), "at its alpha half way")
      step(panel, 0.25)
      assert.are.equal(0, t:GetAlpha(), "out again")
      -- The next after 4 + (8 - 4) * 0.25 = 5 seconds.
      step(panel, 4.9)
      assert.are.equal(0, t:GetAlpha())
      step(panel, 0.2)
      assert.is_true(t:GetAlpha() > 0, "again")
      panel.ornaments:Stop()
      assert.are.equal(0, t:GetAlpha(), "unseen once still")
      panel.ornaments:Start()
      step(panel, 0.65)
      assert.are.equal(0, t:GetAlpha(), "its First again each time the panel shows")
      step(panel, 0.25)
      assert.is_true(t:GetAlpha() > 0)
    end)

    it("waits a whole Every for its first flash without a First", function()
      ornaments.Random = function() return 0.5 end
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 16, Height = 16,
        Motion = { Flash = { Every = { 2, 4 }, Time = 0.2 } } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      local t = texture(panel, 1)
      panel.ornaments:Start()
      step(panel, 2.95)
      assert.are.equal(0, t:GetAlpha())
      step(panel, 0.1)
      assert.is_true(t:GetAlpha() > 0)
    end)

    it("runs no driver for pieces that only move on the client's animations", function()
      theme({ { Texture = "Leaf", Point = "TOPINNER", Width = 10, Height = 10, Motion = { Sway = 4 } } })
      local panel = panelOn("RIGHT")
      panel.ornaments:Style()
      panel.ornaments:Start()
      assert.is_nil(driver(panel) and driver(panel):GetScript("OnUpdate"))
    end)
  end)

  teardown(function()
    for _, name in ipairs(addedKinds) do const.BAG_KIND[name] = nil end
    if createdConstants then ResetModuleStub("Constants") end
  end)
end)
