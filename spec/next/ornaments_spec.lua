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

  teardown(function()
    for _, name in ipairs(addedKinds) do const.BAG_KIND[name] = nil end
    if createdConstants then ResetModuleStub("Constants") end
  end)
end)
