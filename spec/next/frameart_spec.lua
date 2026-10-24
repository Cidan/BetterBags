-- frameart_spec.lua -- NextFrameArt (next/frameart.lua): a Blizzard nine-slice frame drawn round a region, from one
-- of the client's own layouts by name (NineSliceUtil.GetLayout) or from a theme's pieces, placed by the rules of
-- Blizzard's NineSliceUtil.ApplyLayout (Blizzard_SharedXML/NineSlice.lua, every client): corners at their corner by
-- their offsets at their atlas size, edges between their corners tiled as their atlas says, the center between the
-- top left and bottom right corners. Mirrored for a panel whose inner side is on the right. For the Plain theme
-- (docs/next-plain-theme.md): the default UI of the client played.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextFrameArt", "next/frameart.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local frameArt = addon:GetModule("NextFrameArt")

describe("NextFrameArt", function()
  local owner, region, art

  before_each(function()
    ResetMockAtlases()
    UseNineSliceLayouts("Retail")
    -- Sizes of the client's atlases are game data, not the UI source's: stand-ins.
    MockAtlas("ui-frame-portraitmetal-cornertopleftsmall", 64, 64)
    MockAtlas("UI-Frame-Metal-CornerTopRight", 32, 32)
    MockAtlas("UI-Frame-Metal-CornerBottomLeft", 16, 16)
    MockAtlas("UI-Frame-Metal-CornerBottomRight", 16, 16)
    MockAtlas("_UI-Frame-Metal-EdgeTop", 32, 32, true, false)
    MockAtlas("_UI-Frame-Metal-EdgeBottom", 32, 8, true, false)
    MockAtlas("!UI-Frame-Metal-EdgeLeft", 8, 32, false, true)
    MockAtlas("!UI-Frame-Metal-EdgeRight", 8, 32, false, true)
    owner = CreateFrame("Frame", nil, UIParent)
    owner:SetSize(300, 400)
    region = CreateFrame("Frame", nil, owner)
    region:SetAllPoints(owner)
    art = frameArt:Create(owner, region)
  end)

  after_each(function()
    UseNextTheme(nil)
    ResetMockAtlases()
    UseNineSliceLayouts("Retail")
  end)

  local function points(texture)
    local out = {}
    for i = 1, texture:GetNumPoints() do
      out[i] = { texture:GetPoint(i) }
    end
    return out
  end

  local function coords(texture)
    local ulx, uly, _, lly, urx = texture:GetTexCoord()
    return { ulx, urx, uly, lly }
  end

  describe("one of the client's layouts by name", function()
    it("puts each corner at its corner by its offsets, at its atlas size", function()
      art:Apply({ Layout = "HeldBagLayout" })
      local p = art.pieces
      assert.are.equal("ui-frame-portraitmetal-cornertopleftsmall", p.TopLeftCorner:GetAtlas())
      assert.are.same({ { "TOPLEFT", region, "TOPLEFT", -13, 16 } }, points(p.TopLeftCorner))
      assert.are.same({ 64, 64 }, { p.TopLeftCorner:GetSize() })
      assert.are.same({ { "TOPRIGHT", region, "TOPRIGHT", 4, 16 } }, points(p.TopRightCorner))
      assert.are.same({ { "BOTTOMLEFT", region, "BOTTOMLEFT", -13, -3 } }, points(p.BottomLeftCorner))
      assert.are.same({ { "BOTTOMRIGHT", region, "BOTTOMRIGHT", 4, -3 } }, points(p.BottomRightCorner))
      for _, name in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }) do
        assert.is_true(p[name]:IsShown(), name)
        assert.are.same({ 0, 1, 0, 1 }, coords(p[name]), name .. " unflipped")
      end
    end)

    it("stretches each edge between its corners, at its atlas thickness, tiled as its atlas says", function()
      art:Apply({ Layout = "HeldBagLayout" })
      local p = art.pieces
      assert.are.same({ { "TOPLEFT", p.TopLeftCorner, "TOPRIGHT", 0, 0 }, { "TOPRIGHT", p.TopRightCorner, "TOPLEFT", 0, 0 } },
        points(p.TopEdge))
      assert.are.equal(32, p.TopEdge:GetHeight())
      assert.is_true(p.TopEdge:GetHorizTile())
      assert.is_false(p.TopEdge:GetVertTile())
      assert.are.same({ { "BOTTOMLEFT", p.BottomLeftCorner, "BOTTOMRIGHT", 0, 0 },
        { "BOTTOMRIGHT", p.BottomRightCorner, "BOTTOMLEFT", 0, 0 } }, points(p.BottomEdge))
      assert.are.same({ { "TOPLEFT", p.TopLeftCorner, "BOTTOMLEFT", 0, 0 }, { "BOTTOMLEFT", p.BottomLeftCorner, "TOPLEFT", 0, 0 } },
        points(p.LeftEdge))
      assert.are.equal(8, p.LeftEdge:GetWidth())
      assert.is_true(p.LeftEdge:GetVertTile())
      assert.are.same({ { "TOPRIGHT", p.TopRightCorner, "BOTTOMRIGHT", 0, 0 },
        { "BOTTOMRIGHT", p.BottomRightCorner, "TOPRIGHT", 0, 0 } }, points(p.RightEdge))
      assert.is_false(p.Center:IsShown(), "the layout has none")
    end)

    -- Blizzard turns pixel snapping off for the metal (NineSliceUtil.DisableSharpening); a later layout without it
    -- gets the textures' own back.
    it("draws a layout's pieces unsharpened when it says so, and gives a texture its snapping back after", function()
      local corner = art.pieces.TopLeftCorner
      local snap, bias = corner:IsSnappingToPixelGrid(), corner:GetTexelSnappingBias()
      art:Apply({ Layout = "HeldBagLayout" })
      assert.is_false(corner:IsSnappingToPixelGrid())
      assert.are.equal(0, corner:GetTexelSnappingBias())
      MockAtlas("UI-Frame-DiamondMetal-CornerTopLeft", 32, 32)
      art:Apply({ Layout = "Dialog" })
      assert.are.same({ snap, bias }, { corner:IsSnappingToPixelGrid(), corner:GetTexelSnappingBias() })
    end)

    -- Forever adjusts the layouts in place at load (Camelot/NineSliceLayoutOverrides.lua): read from the client,
    -- its own numbers are drawn.
    it("draws the client's own numbers for a layout, Forever's adjusted ones on Forever", function()
      UseNineSliceLayouts("Forever")
      art:Apply({ Layout = "HeldBagLayout" })
      assert.are.same({ { "TOPRIGHT", region, "TOPRIGHT", 2, 16 } }, points(art.pieces.TopRightCorner))
      assert.are.same({ { "BOTTOMLEFT", region, "BOTTOMLEFT", -13, -8 } }, points(art.pieces.BottomLeftCorner))
    end)

    it("draws Classic's art for a layout on Classic", function()
      UseNineSliceLayouts("Classic")
      MockAtlas("UI-Frame-TopLeftCornerNoPortrait", 32, 32)
      MockAtlas("!UI-Frame-RightTile", 8, 32, false, true)
      art:Apply({ Layout = "ButtonFrameTemplateNoPortrait" })
      local p = art.pieces
      assert.are.equal("UI-Frame-TopLeftCornerNoPortrait", p.TopLeftCorner:GetAtlas())
      assert.are.same({ { "TOPRIGHT", p.TopRightCorner, "BOTTOMRIGHT", -8, 0 },
        { "BOTTOMRIGHT", p.BottomRightCorner, "TOPRIGHT", 8, 0 } }, points(p.RightEdge))
    end)

    -- An atlas the client lacks: Blizzard sets no art on the piece (SetupPieceVisuals checks GetAtlasInfo).
    it("draws nothing for a piece whose atlas the client lacks", function()
      MockAtlases["UI-Frame-Metal-CornerTopRight"] = nil
      art:Apply({ Layout = "HeldBagLayout" })
      assert.is_false(art.pieces.TopRightCorner:IsShown())
      assert.is_true(art.pieces.TopLeftCorner:IsShown())
    end)

    it("names a layout the client lacks, and refuses what it cannot draw", function()
      assert.has_error(function() art:Apply({ Layout = "NoSuchLayout" }) end,
        "the client has no nine-slice layout named NoSuchLayout")
      NineSliceLayouts.Custom = { setupPieceVisualsFunction = function() end, TopEdge = { atlas = "x" } }
      assert.has_error(function() art:Apply({ Layout = "Custom" }) end,
        "BetterBags Next cannot draw Custom: it sets its pieces up itself")
      NineSliceLayouts.Kit = { TopEdge = { atlas = "%s-edge" } }
      assert.has_error(function() art:Apply({ Layout = "Kit" }) end,
        "BetterBags Next cannot draw Kit: it needs a texture kit")
    end)

    it("anchors a three-slice layout's edges to the region", function()
      MockAtlas("left-cap", 10, 20)
      MockAtlas("right-cap", 10, 20)
      MockAtlas("_middle", 10, 20, true, false)
      NineSliceLayouts.Bar = { threeSliceHorizontal = true, LeftEdge = { atlas = "left-cap" },
        RightEdge = { atlas = "right-cap" }, Center = { atlas = "_middle" } }
      art:Apply({ Layout = "Bar" })
      local p = art.pieces
      assert.are.same({ { "TOPLEFT", region, "TOPLEFT", 0, 0 }, { "BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0 } },
        points(p.LeftEdge))
      assert.are.same({ { "TOPLEFT", p.LeftEdge, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", p.RightEdge, "BOTTOMLEFT", 0, 0 } },
        points(p.Center))
    end)

    -- mirrorLayout: the layout gives one corner and edge, the others flipped from them (NineSlice.lua).
    it("flips the mirrored pieces of a layout that mirrors itself", function()
      MockAtlas("corner", 16, 16)
      NineSliceLayouts.Mirrored = { mirrorLayout = true, TopLeftCorner = { atlas = "corner" },
        TopRightCorner = { atlas = "corner" }, BottomLeftCorner = { atlas = "corner" }, BottomRightCorner = { atlas = "corner" } }
      art:Apply({ Layout = "Mirrored" })
      local p = art.pieces
      assert.are.same({ 0, 1, 0, 1 }, coords(p.TopLeftCorner))
      assert.are.same({ 1, 0, 0, 1 }, coords(p.TopRightCorner))
      assert.are.same({ 0, 1, 1, 0 }, coords(p.BottomLeftCorner))
      assert.are.same({ 1, 0, 1, 0 }, coords(p.BottomRightCorner))
    end)
  end)

  -- A panel whose inner side is on the right (the bank, on the left of the screen) draws its frame mirrored, as its
  -- ornaments are: the portrait corner at its top right.
  describe("mirrored", function()
    it("draws each piece's mirror image in the opposite place, flipped", function()
      art:Apply({ Layout = "HeldBagLayout" }, true)
      local p = art.pieces
      assert.are.equal("ui-frame-portraitmetal-cornertopleftsmall", p.TopRightCorner:GetAtlas())
      assert.are.same({ { "TOPRIGHT", region, "TOPRIGHT", 13, 16 } }, points(p.TopRightCorner))
      assert.are.same({ 1, 0, 0, 1 }, coords(p.TopRightCorner))
      assert.are.equal("UI-Frame-Metal-CornerTopRight", p.TopLeftCorner:GetAtlas())
      assert.are.same({ { "TOPLEFT", region, "TOPLEFT", -4, 16 } }, points(p.TopLeftCorner))
      assert.are.equal("UI-Frame-Metal-CornerBottomLeft", p.BottomRightCorner:GetAtlas())
      assert.are.same({ { "BOTTOMRIGHT", region, "BOTTOMRIGHT", 13, -3 } }, points(p.BottomRightCorner))
      assert.are.same({ { "TOPRIGHT", p.TopRightCorner, "TOPLEFT", 0, 0 }, { "TOPLEFT", p.TopLeftCorner, "TOPRIGHT", 0, 0 } },
        points(p.TopEdge))
      assert.are.same({ 1, 0, 0, 1 }, coords(p.TopEdge))
      assert.are.equal("!UI-Frame-Metal-EdgeLeft", p.RightEdge:GetAtlas())
      assert.are.same({ { "TOPRIGHT", p.TopRightCorner, "BOTTOMRIGHT", 0, 0 },
        { "BOTTOMRIGHT", p.BottomRightCorner, "TOPRIGHT", 0, 0 } }, points(p.RightEdge))
    end)

    it("mirrors an edge's offsets too", function()
      UseNineSliceLayouts("Classic")
      MockAtlas("!UI-Frame-RightTile", 8, 32, false, true)
      art:Apply({ Layout = "ButtonFrameTemplateNoPortrait" }, true)
      local p = art.pieces
      assert.are.equal("!UI-Frame-RightTile", p.LeftEdge:GetAtlas())
      assert.are.same({ { "TOPLEFT", p.TopLeftCorner, "BOTTOMLEFT", 8, 0 },
        { "BOTTOMLEFT", p.BottomLeftCorner, "TOPLEFT", -8, 0 } }, points(p.LeftEdge))
    end)

    it("draws unmirrored again", function()
      art:Apply({ Layout = "HeldBagLayout" }, true)
      art:Apply({ Layout = "HeldBagLayout" })
      assert.are.equal("ui-frame-portraitmetal-cornertopleftsmall", art.pieces.TopLeftCorner:GetAtlas())
      assert.are.same({ 0, 1, 0, 1 }, coords(art.pieces.TopLeftCorner))
      assert.are.same({ 0, 1, 0, 1 }, coords(art.pieces.TopEdge))
    end)
  end)

  describe("a theme's own pieces", function()
    it("draws files with their coordinates and sizes, tiled as told, and atlases at their size", function()
      art:Apply({ Pieces = {
        TopLeftCorner = { Texture = "Interface\\Spec\\frame.png", TexCoords = { 0, 0.25, 0, 0.25 }, Width = 20, Height = 24,
          X = -4, Y = 6 },
        TopEdge = { Texture = "Interface\\Spec\\frame.png", TexCoords = { 0.25, 0.75, 0, 0.25 }, Height = 12, HorizTile = true },
        TopRightCorner = { Atlas = "UI-Frame-Metal-CornerTopRight" },
        Center = { Texture = "Interface\\Spec\\fill.png", HorizTile = true, VertTile = true },
      } })
      local p = art.pieces
      assert.are.equal("Interface\\Spec\\frame.png", p.TopLeftCorner:GetTexture())
      assert.are.same({ 0, 0.25, 0, 0.25 }, coords(p.TopLeftCorner))
      assert.are.same({ 20, 24 }, { p.TopLeftCorner:GetSize() })
      assert.are.same({ { "TOPLEFT", region, "TOPLEFT", -4, 6 } }, points(p.TopLeftCorner))
      assert.are.equal(12, p.TopEdge:GetHeight())
      assert.is_true(p.TopEdge:GetHorizTile())
      assert.are.same({ 32, 32 }, { p.TopRightCorner:GetSize() })
      assert.is_true(p.Center:IsShown())
      assert.is_true(p.Center:GetVertTile())
      assert.is_false(p.BottomEdge:IsShown())
    end)
  end)

  it("tints its pieces, draws them where the theme says, and hides them all for none", function()
    art:Apply({ Layout = "HeldBagLayout", Color = { 1, 0.5, 0, 1 }, Alpha = 0.5, Layer = "BORDER", SubLevel = 3 })
    local corner = art.pieces.TopLeftCorner
    assert.are.same({ 1, 0.5, 0, 0.5 }, { corner:GetVertexColor() })
    assert.are.same({ "BORDER", 3 }, { corner:GetDrawLayer() })
    art:Apply({ Layout = "HeldBagLayout" })
    assert.are.same({ 1, 1, 1, 1 }, { corner:GetVertexColor() })
    assert.are.same({ "ARTWORK", 5 }, { corner:GetDrawLayer() })
    art:Apply(false)
    for name, piece in pairs(art.pieces) do
      assert.is_false(piece:IsShown(), name)
    end
  end)
end)
