-- fill_spec.lua -- NextFill (next/fill.lua): a fill drawn as one piece or as Blizzard draws its buttons, sliders,
-- scroll bars and inputs, a begin cap, a stretched middle and an end cap, inset into its region or reaching past it.
-- For the Plain theme (docs/next-plain-theme.md): UIPanelButtonNoTooltipTemplate's three pieces of
-- UI-Panel-Button-Up, MinimalSliderTemplate's slider bar, MinimalScrollBar's track, InputBoxVisualTemplate's border,
-- WowStyle1DropdownTemplate's background 9 and 8 pixels past its button.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextFill", "next/fill.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local fills = addon:GetModule("NextFill")

local BUTTON = "Interface\\Buttons\\UI-Panel-Button-Up"

describe("NextFill", function()
  local frame, texture, fill

  before_each(function()
    ResetMockAtlases()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(120, 22)
    texture = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill = fills:Wrap(texture, frame)
  end)

  after_each(function()
    ResetMockAtlases()
  end)

  local function points(region)
    local out = {}
    for i = 1, region:GetNumPoints() do
      out[i] = { region:GetPoint(i) }
    end
    return out
  end

  local function coords(region)
    local ulx, uly, _, lly, urx = region:GetTexCoord()
    return { ulx, urx, uly, lly }
  end

  it("finds the fill a texture is", function()
    assert.are.equal(fill, fills:Of(texture))
    assert.is_nil(fills:Of(frame:CreateTexture()))
  end)

  describe("one piece", function()
    it("fills its region as a color or art, and hides for none", function()
      fill:Paint({ Color = { 1, 0, 0, 1 } })
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0 } }, points(texture))
      assert.is_true(texture:IsShown())
      fill:Paint({ Texture = BUTTON, TexCoords = { 0, 0.625, 0, 0.6875 }, BlendMode = "ADD" }, 0.5)
      assert.are.equal(BUTTON, texture:GetTexture())
      assert.are.same({ 0, 0.625, 0, 0.6875 }, coords(texture))
      assert.are.equal("ADD", texture:GetBlendMode())
      assert.are.same({ 1, 1, 1, 0.5 }, { texture:GetVertexColor() })
      fill:Paint(false)
      assert.is_false(texture:IsShown())
    end)

    -- Blizzard's settings list (Blizzard_CategoryList.lua) draws its rows' art at the atlas's own size, centered
    -- (Options_List_Active, useAtlasSize, anchored CENTER), and its headers' at their top left.
    it("draws an atlas at its own size by its Point, and fills its region again after", function()
      MockAtlas("Options_List_Active", 175, 20)
      fill:Paint({ Atlas = "Options_List_Active", AtlasSize = true })
      assert.are.same({ { "CENTER", frame, "CENTER", 0, 0 } }, points(texture))
      assert.are.same({ 175, 20 }, { texture:GetSize() })
      fill:Paint({ Atlas = "Options_List_Active", AtlasSize = true, Point = "TOPLEFT" })
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", 0, 0 } }, points(texture))
      fill:Paint({ Atlas = "Options_List_Active" })
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0 } }, points(texture))
    end)

    -- Blizzard's dropdown background reaches 9 and 8 pixels past its button (WowStyle1DropdownTemplate).
    it("insets itself into its region, or reaches past it", function()
      fill:Paint({ Atlas = "common-dropdown-classic-textholder", Inset = { Left = -9, Top = -8, Right = -8, Bottom = -9 } })
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", -9, 8 }, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -9 } }, points(texture))
      fill:Paint({ Color = "White", Inset = { Left = 7, Top = 18, Right = 3, Bottom = 3 } })
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", 7, -18 }, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3 } }, points(texture))
    end)
  end)

  describe("three pieces", function()
    -- UIPanelButtonNoTooltipTemplate: caps 12 wide, the file's columns 0-0.09375, 0.09375-0.53125, 0.53125-0.625.
    local PANEL_BUTTON = { Pieces = "Horizontal", Texture = BUTTON, Color = "White",
      Begin = { TexCoords = { 0, 0.09375, 0, 0.6875 }, Size = 12 },
      Middle = { TexCoords = { 0.09375, 0.53125, 0, 0.6875 } },
      End = { TexCoords = { 0.53125, 0.625, 0, 0.6875 }, Size = 12 } }

    it("draws a begin cap, a stretched middle and an end cap across, the texture the middle", function()
      fill:Paint(PANEL_BUTTON)
      local begin, finish = fill.Begin, fill.End
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", 0, 0 }, { "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0 } }, points(begin))
      assert.are.equal(12, begin:GetWidth())
      assert.are.same({ { "TOPRIGHT", frame, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0 } }, points(finish))
      assert.are.same({ { "TOPLEFT", begin, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", finish, "BOTTOMLEFT", 0, 0 } }, points(texture))
      for _, piece in ipairs({ begin, texture, finish }) do
        assert.are.equal(BUTTON, piece:GetTexture())
        assert.is_true(piece:IsShown())
        assert.are.same({ "BACKGROUND", 2 }, { piece:GetDrawLayer() })
      end
      assert.are.same({ 0, 0.09375, 0, 0.6875 }, coords(begin))
      assert.are.same({ 0.09375, 0.53125, 0, 0.6875 }, coords(texture))
      assert.are.same({ 0.53125, 0.625, 0, 0.6875 }, coords(finish))
    end)

    it("tints every piece, and hides them all for none or for one piece", function()
      fill:Paint(PANEL_BUTTON, 0.4)
      assert.are.same({ 1, 1, 1, 0.4 }, { fill.Begin:GetVertexColor() })
      assert.are.same({ 1, 1, 1, 0.4 }, { fill.End:GetVertexColor() })
      fill:Paint({ Color = "White" })
      assert.is_false(fill.Begin:IsShown())
      assert.is_false(fill.End:IsShown())
      assert.is_true(texture:IsShown())
      fill:Paint(PANEL_BUTTON)
      fill:Paint(false)
      assert.is_false(fill.Begin:IsShown())
      assert.is_false(texture:IsShown())
    end)

    -- MinimalSliderTemplate: the caps at their atlas size, anchored LEFT and RIGHT, the middle as tall, tiled.
    it("sizes atlas caps from the atlas, a thickness centered on its region, the middle tiled as its atlas says", function()
      MockAtlas("Minimal_SliderBar_Left", 11, 9)
      MockAtlas("Minimal_SliderBar_Right", 11, 9)
      MockAtlas("_Minimal_SliderBar_Middle", 32, 9, true, false)
      fill:Paint({ Pieces = "Horizontal", Thickness = 9, Begin = { Atlas = "Minimal_SliderBar_Left" },
        Middle = { Atlas = "_Minimal_SliderBar_Middle" }, End = { Atlas = "Minimal_SliderBar_Right" } })
      assert.are.same({ { "LEFT", frame, "LEFT", 0, 0 } }, points(fill.Begin))
      assert.are.same({ 11, 9 }, { fill.Begin:GetSize() })
      assert.are.same({ { "RIGHT", frame, "RIGHT", 0, 0 } }, points(fill.End))
      assert.are.equal("_Minimal_SliderBar_Middle", texture:GetAtlas())
      assert.is_true(texture:GetHorizTile())
      assert.are.same({ { "TOPLEFT", fill.Begin, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", fill.End, "BOTTOMLEFT", 0, 0 } },
        points(texture))
    end)

    -- MinimalSliderTemplate exactly: every piece at its atlas's own height (useAtlasSize), the caps by LEFT and RIGHT,
    -- the middle hung from the caps' tops.
    it("draws each piece at its atlas's own thickness, the middle hung from the caps' tops", function()
      MockAtlas("Minimal_SliderBar_Left", 11, 9)
      MockAtlas("Minimal_SliderBar_Right", 11, 9)
      MockAtlas("_Minimal_SliderBar_Middle", 32, 8, true, false)
      fill:Paint({ Pieces = "Horizontal", Thickness = "Atlas", Begin = { Atlas = "Minimal_SliderBar_Left" },
        Middle = { Atlas = "_Minimal_SliderBar_Middle" }, End = { Atlas = "Minimal_SliderBar_Right" } })
      assert.are.same({ { "LEFT", frame, "LEFT", 0, 0 } }, points(fill.Begin))
      assert.are.same({ 11, 9 }, { fill.Begin:GetSize() })
      assert.are.same({ { "RIGHT", frame, "RIGHT", 0, 0 } }, points(fill.End))
      assert.are.same({ { "TOPLEFT", fill.Begin, "TOPRIGHT", 0, 0 }, { "TOPRIGHT", fill.End, "TOPLEFT", 0, 0 } }, points(texture))
      assert.are.equal(8, texture:GetHeight())
    end)

    -- MinimalTabTemplate: the caps by their bottom corners (BOTTOMLEFT, BOTTOMRIGHT), the middle hung from their tops.
    it("aligns atlas-thick pieces by their bottoms when told", function()
      MockAtlas("Options_Tab_Left", 10, 30)
      MockAtlas("Options_Tab_Right", 10, 30)
      MockAtlas("Options_Tab_Middle", 20, 30, true, false)
      fill:Paint({ Pieces = "Horizontal", Thickness = "Atlas", Align = "BOTTOM", Begin = { Atlas = "Options_Tab_Left" },
        Middle = { Atlas = "Options_Tab_Middle" }, End = { Atlas = "Options_Tab_Right" } })
      assert.are.same({ { "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0 } }, points(fill.Begin))
      assert.are.same({ { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0 } }, points(fill.End))
      assert.are.same({ { "TOPLEFT", fill.Begin, "TOPRIGHT", 0, 0 }, { "TOPRIGHT", fill.End, "TOPLEFT", 0, 0 } }, points(texture))
    end)

    it("draws each piece down at its atlas's own thickness too", function()
      MockAtlas("top", 8, 4)
      MockAtlas("bottom", 8, 4)
      MockAtlas("middle", 6, 16, false, true)
      fill:Paint({ Pieces = "Vertical", Thickness = "Atlas", Begin = { Atlas = "top" }, Middle = { Atlas = "middle" },
        End = { Atlas = "bottom" } })
      assert.are.same({ { "TOP", frame, "TOP", 0, 0 } }, points(fill.Begin))
      assert.are.same({ 8, 4 }, { fill.Begin:GetSize() })
      assert.are.same({ { "BOTTOM", frame, "BOTTOM", 0, 0 } }, points(fill.End))
      assert.are.same({ { "TOPLEFT", fill.Begin, "BOTTOMLEFT", 0, 0 }, { "BOTTOMLEFT", fill.End, "TOPLEFT", 0, 0 } },
        points(texture))
      assert.are.equal(6, texture:GetWidth())
    end)

    -- MinimalScrollBar's track: top, a middle tiled down, bottom.
    it("draws down its region too", function()
      MockAtlas("minimal-scrollbar-track-top", 8, 8)
      MockAtlas("minimal-scrollbar-track-bottom", 8, 8)
      MockAtlas("!minimal-scrollbar-track-middle", 8, 32, false, true)
      fill:Paint({ Pieces = "Vertical", Begin = { Atlas = "minimal-scrollbar-track-top" },
        Middle = { Atlas = "!minimal-scrollbar-track-middle" }, End = { Atlas = "minimal-scrollbar-track-bottom" } })
      assert.are.same({ { "TOPLEFT", frame, "TOPLEFT", 0, 0 }, { "TOPRIGHT", frame, "TOPRIGHT", 0, 0 } }, points(fill.Begin))
      assert.are.equal(8, fill.Begin:GetHeight())
      assert.are.same({ { "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0 } },
        points(fill.End))
      assert.are.same({ { "TOPLEFT", fill.Begin, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", fill.End, "TOPRIGHT", 0, 0 } },
        points(texture))
      assert.is_true(texture:GetVertTile())
    end)

    -- InputBoxVisualTemplate: 20 tall, its left cap 5 past the box.
    it("insets three pieces too", function()
      fill:Paint({ Pieces = "Horizontal", Thickness = 20, Inset = { Left = -5 }, Begin = { Atlas = "common-search-border-left", Size = 8 },
        Middle = { Atlas = "common-search-border-middle" }, End = { Atlas = "common-search-border-right", Size = 8 } })
      assert.are.same({ { "LEFT", frame, "LEFT", -5, 0 } }, points(fill.Begin))
      assert.are.same({ 8, 20 }, { fill.Begin:GetSize() })
    end)
  end)

  it("refuses a way of piecing it does not know", function()
    assert.has_error(function() fill:Paint({ Pieces = "Diagonal" }) end, "a fill is pieced Horizontal or Vertical, not Diagonal")
  end)
end)
