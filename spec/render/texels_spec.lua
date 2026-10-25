-- texels_spec.lua -- Texels (render/texels.lua): BetterBags draws its bags' textures without the client's sharpening
-- (texture-sharpening.md). Measured in game: with it, an icon's art was drawn a fraction of a pixel differently from
-- frame to frame while a bag was resized, though nothing moved; with it off, it held still.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local texels = addon:GetModule("Texels")

describe("Texels", function()
  -- sharpened says whether a texture is drawn with the client's sharpening: snapped to the pixel grid, or with a texel
  -- snapping bias above 0 (which implies snapping; Blizzard, warcraft.wiki.gg TextureBase:SetTexelSnappingBias).
  local function sharpened(texture)
    return texture:IsSnappingToPixelGrid() or texture:GetTexelSnappingBias() > 0
  end

  it("draws every texture, line and mask under a root without the client's sharpening, hidden ones too", function()
    local root = CreateFrame("Frame")
    local art = root:CreateTexture()
    art:SetTexture(123)
    local hover = root:CreateTexture()
    hover:Hide()
    local line = root:CreateLine()
    local mask = root:CreateMaskTexture()
    local child = CreateFrame("Button", nil, root)
    local deep = child:CreateTexture()
    local hidden = CreateFrame("Frame", nil, root)
    hidden:Hide()
    local underHidden = hidden:CreateTexture()
    for _, t in ipairs({ art, hover, line, mask, deep, underHidden }) do
      assert.is_true(sharpened(t), "the client sharpens a texture by default")
    end
    assert.are.equal(6, texels:Unsharpen(root))
    for _, t in ipairs({ art, hover, line, mask, deep, underHidden }) do
      assert.is_false(t:IsSnappingToPixelGrid())
      assert.are.equal(0, t:GetTexelSnappingBias())
    end
  end)

  it("leaves text alone", function()
    local root = CreateFrame("Frame")
    local text = root:CreateFontString()
    local before = { text:IsSnappingToPixelGrid(), text:GetTexelSnappingBias() }
    assert.are.equal(0, texels:Unsharpen(root))
    assert.are.same(before, { text:IsSnappingToPixelGrid(), text:GetTexelSnappingBias() })
  end)

  it("leaves a frame that draws itself to its own draws, unless it is the root", function()
    local root = CreateFrame("Frame")
    local own = CreateFrame("Frame", nil, root)
    texels:DrawsItself(own)
    local inside = CreateFrame("Button", nil, own):CreateTexture()
    local panelArt = root:CreateTexture()
    assert.are.equal(1, texels:Unsharpen(root))
    assert.is_false(sharpened(panelArt))
    assert.is_true(sharpened(inside), "the walk of the window it is in skips it")
    assert.are.equal(1, texels:Unsharpen(own))
    assert.is_false(sharpened(inside), "its own draw unsharpens it")
  end)

  it("sets every texture again each time, so a texture something sharpened again is drawn unsharpened once more", function()
    local root = CreateFrame("Frame")
    local art = root:CreateTexture()
    texels:Unsharpen(root)
    art:SetSnapToPixelGrid(true)
    art:SetTexelSnappingBias(1)
    assert.are.equal(1, texels:Unsharpen(root))
    assert.is_false(sharpened(art))
  end)
end)
