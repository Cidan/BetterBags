-- apply_spec.lua -- Sonata's spec appliers (sonata/apply.lua): colors, fonts, textures, anchors
-- and button states turned into widget calls. Every texture spec sets everything it controls,
-- so a pooled texture keeps nothing of what it drew before, and an atlas keeps the texture
-- coordinates, tiling and slicing it brings.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local fonts = trackStub("Fonts")
fonts.SpecTitleFont = fonts.SpecTitleFont or CreateFont("BetterBagsSpecTitleFont")

LoadBetterBagsModule("sonata/apply.lua")
local apply = addon:GetModule("SonataApply")

describe("SonataApply", function()
  describe("colors", function()
    it("reads list colors, with full alpha when unset", function()
      assert.are.same({ 0.1, 0.2, 0.3, 1 }, { apply:Color({ 0.1, 0.2, 0.3 }) })
      assert.are.same({ 0.1, 0.2, 0.3, 0.4 }, { apply:Color({ 0.1, 0.2, 0.3, 0.4 }) })
    end)

    it("reads keyed colors", function()
      assert.are.same({ 0.1, 0.2, 0.3, 0.5 }, { apply:Color({ r = 0.1, g = 0.2, b = 0.3, a = 0.5 }) })
      assert.are.same({ 0.1, 0.2, 0.3, 1 }, { apply:Color({ r = 0.1, g = 0.2, b = 0.3 }) })
    end)

    it("falls back, then to white", function()
      assert.are.same({ 0, 0, 0, 1 }, { apply:Color(nil, { 0, 0, 0, 1 }) })
      assert.are.same({ 1, 1, 1, 1 }, { apply:Color(nil) })
    end)
  end)

  describe("fonts", function()
    it("finds BetterBags' font objects before the client's, and takes an object", function()
      assert.are.equal(fonts.SpecTitleFont, apply:FontObject("SpecTitleFont"))
      assert.are.equal(_G.GameFontNormal, apply:FontObject("GameFontNormal"))
      assert.are.equal(_G.GameFontNormal, apply:FontObject(_G.GameFontNormal))
      assert.has_error(function() apply:FontObject("NoSuchFont") end)
    end)

    it("takes a font object's color and shadow along with the object", function()
      local fs = UIParent:CreateFontString()
      fs:SetTextColor(1, 0, 0, 1)
      fs:SetShadowOffset(5, 5)
      apply:Font(fs, { Object = "GameFontNormal" })
      assert.are.equal(_G.GameFontNormal, fs._fontObject)
      assert.are.same({ r = 1, g = 0.82, b = 0, a = 1 }, fs._textColor)
      assert.are.same({ x = 1, y = -1 }, fs._shadowOffset)
    end)

    it("applies a path, size and flags after the object, and the color, shadow and justification last", function()
      local fs = UIParent:CreateFontString()
      apply:Font(fs, {
        Object = "GameFontNormal",
        Path = "f.ttf", Size = 13, Flags = "OUTLINE",
        Color = { 0, 1, 0, 1 },
        Shadow = { Color = { 0, 0, 0, 0.5 }, X = 2, Y = -2 },
        Justify = "LEFT",
      })
      assert.are.same({ "f.ttf", 13, "OUTLINE" }, { fs._font, fs._fontSize, fs._fontFlags })
      assert.are.same({ r = 0, g = 1, b = 0, a = 1 }, fs._textColor)
      assert.are.same({ r = 0, g = 0, b = 0, a = 0.5 }, fs._shadowColor)
      assert.are.same({ x = 2, y = -2 }, fs._shadowOffset)
      assert.are.equal("LEFT", fs:GetJustifyH())
    end)

    it("does nothing without a spec", function()
      local fs = UIParent:CreateFontString()
      apply:Font(fs, nil)
      assert.is_nil(fs._fontObject)
    end)
  end)

  describe("textures", function()
    local function used()
      local t = UIParent:CreateTexture(nil, "ARTWORK")
      t:SetTexture("old.png")
      t:SetTexCoord(0.2, 0.8, 0.2, 0.8)
      t:SetTextureSliceMargins(1, 2, 3, 4)
      t:SetTextureSliceMode(1)
      t:SetVertexColor(1, 0, 0, 1)
      t:SetBlendMode("ADD")
      t:SetDesaturated(true)
      t:SetHorizTile(true)
      t:SetVertTile(true)
      t:SetAlpha(0.3)
      return t
    end

    it("resets everything a file texture spec leaves out", function()
      local t = used()
      apply:Texture(t, { Texture = "new.png", Layer = "BORDER" })
      assert.are.equal("new.png", t:GetTexture())
      assert.are.equal("BORDER", t._drawLayer)
      assert.are.equal(0, t._sublevel)
      assert.are.same({ 0, 1, 0, 1 }, t._texCoords)
      assert.is_nil(t._sliceMargins)
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, t._vertexColor)
      assert.are.equal("BLEND", t:GetBlendMode())
      assert.is_false(t:IsDesaturated())
      assert.is_false(t._horizTile)
      assert.is_false(t._vertTile)
      assert.are.equal(1, t:GetAlpha())
    end)

    it("keeps the coordinates, tiling and slicing an atlas brings", function()
      local t = used()
      apply:Texture(t, { Atlas = "bags-icon", Layer = "ARTWORK" })
      assert.are.equal("bags-icon", t:GetAtlas())
      assert.is_nil(t._texCoords)
      assert.is_nil(t._horizTile)
      assert.is_nil(t._sliceMargins)
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, t._vertexColor)
      assert.are.equal("BLEND", t:GetBlendMode())
      assert.are.equal(1, t:GetAlpha())
    end)

    it("applies what an atlas spec sets explicitly", function()
      local t = used()
      apply:Texture(t, { Atlas = "bags-icon", TexCoords = { 0, 0.5, 0, 0.5 }, HorizTile = true, UseAtlasSize = true,
        SliceMargins = { Left = 4, Top = 4, Right = 4, Bottom = 4 }, SliceMode = "Tiled" })
      assert.are.same({ 0, 0.5, 0, 0.5 }, t._texCoords)
      assert.is_true(t._horizTile)
      assert.is_true(t._useAtlasSize)
      assert.are.same({ left = 4, top = 4, right = 4, bottom = 4 }, t._sliceMargins)
      assert.are.equal(Enum.UITextureSliceMode.Tiled, t._sliceMode)
    end)

    -- Tiling from Lua needs the REPEAT wrap mode on the file or atlas, as Blizzard's
    -- SetTextureWithAddressModeOptions does (Blizzard_SharedXMLBase/TextureUtil.lua): with the
    -- default CLAMP, a texture tiled past its size repeats its edge pixels in streaks.
    it("loads a tiled file with the REPEAT wrap mode in each tiled direction", function()
      local t = used()
      apply:Texture(t, { Texture = "marble.png", HorizTile = true, VertTile = true })
      assert.are.equal("REPEAT", t._wrapH)
      assert.are.equal("REPEAT", t._wrapV)
      assert.is_true(t._horizTile)
      assert.is_true(t._vertTile)
      apply:Texture(t, { Texture = "marble.png", HorizTile = true })
      assert.are.equal("REPEAT", t._wrapH)
      assert.is_nil(t._wrapV)
      apply:Texture(t, { Texture = "plain.png" })
      assert.is_nil(t._wrapH)
      assert.is_nil(t._wrapV)
    end)

    it("loads a tiled atlas with the REPEAT wrap mode too", function()
      local t = used()
      apply:Texture(t, { Atlas = "bags-icon", VertTile = true })
      assert.is_nil(t._wrapH)
      assert.are.equal("REPEAT", t._wrapV)
      assert.is_true(t._vertTile)
    end)

    it("draws a solid color", function()
      local t = used()
      apply:Texture(t, { Color = { 0, 0, 0, 0.5 } })
      assert.are.same({ r = 0, g = 0, b = 0, a = 0.5 }, t._colorTexture)
      assert.is_nil(t:GetTexture())
    end)

    it("keeps the texture's draw layer without one, and still sets the sublevel", function()
      local t = UIParent:CreateTexture(nil, "OVERLAY")
      t:SetDrawLayer("OVERLAY", 3)
      apply:Texture(t, { Texture = "x.png" })
      assert.are.equal("OVERLAY", t._drawLayer)
      assert.are.equal(0, t._sublevel)
      apply:Texture(t, { Texture = "x.png", SubLevel = 2 })
      assert.are.equal(2, t._sublevel)
    end)

    it("resets a texture for reuse, size included", function()
      local t = used()
      t:SetSize(84, 84)
      t:SetPoint("TOP")
      apply:ResetTexture(t)
      assert.is_false(t:IsShown())
      assert.is_nil(t:GetPoint(1))
      assert.is_nil(t:GetTexture())
      assert.is_nil(t._sliceMargins)
      assert.are.same({ 0, 1, 0, 1 }, t._texCoords)
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, t._vertexColor)
      assert.are.equal("BLEND", t:GetBlendMode())
      assert.is_false(t:IsDesaturated())
      assert.is_false(t._horizTile)
      assert.are.equal(1, t:GetAlpha())
      assert.are.same({ 0, 0 }, { t:GetWidth(), t:GetHeight() })
    end)
  end)

  describe("anchors", function()
    it("anchors to the owner, or to a resolved name, with the point as the default relative point", function()
      local owner = CreateFrame("Frame")
      local other = CreateFrame("Frame")
      local t = owner:CreateTexture()
      apply:Points(t, { { Point = "TOP", Y = -5 }, { Point = "LEFT", RelativeTo = "Other", RelativePoint = "RIGHT", X = 2 } }, owner,
        function(name) if name == "Other" then return other end end)
      assert.are.same({ "TOP", owner, "TOP", 0, -5 }, { t:GetPoint(1) })
      assert.are.same({ "LEFT", other, "RIGHT", 2, 0 }, { t:GetPoint(2) })
    end)

    it("errors on a name it cannot resolve", function()
      local owner = CreateFrame("Frame")
      assert.has_error(function()
        apply:Points(owner:CreateTexture(), { { Point = "TOP", RelativeTo = "Nope" } }, owner, function() return nil end)
      end)
    end)

    it("insets a region to fill its owner", function()
      local owner = CreateFrame("Frame")
      local t = owner:CreateTexture()
      apply:Inset(t, owner, { Left = 1, Right = 2, Top = 3, Bottom = 4 })
      assert.are.same({ "TOPLEFT", owner, "TOPLEFT", 1, -3 }, { t:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", owner, "BOTTOMRIGHT", -2, 4 }, { t:GetPoint(2) })
    end)
  end)

  describe("button states", function()
    it("sets a state's file, atlas or color, with its blend mode", function()
      local b = CreateFrame("Button")
      apply:ButtonStates(b, {
        Normal = { Texture = "n.png" },
        Highlight = { Atlas = "h-atlas", BlendMode = "ADD" },
        Pushed = { Color = { 0.9, 0.8, 0.1, 0.3 }, BlendMode = "ADD" },
        Disabled = { Texture = 12345 },
      })
      assert.are.equal("n.png", b:GetNormalTexture():GetTexture())
      assert.are.equal("h-atlas", b:GetHighlightTexture():GetAtlas())
      assert.are.equal("ADD", b:GetHighlightTexture():GetBlendMode())
      assert.are.equal("Interface\\Buttons\\WHITE8X8", b:GetPushedTexture():GetTexture())
      assert.are.same({ r = 0.9, g = 0.8, b = 0.1, a = 0.3 }, b:GetPushedTexture()._vertexColor)
      assert.are.equal("ADD", b:GetPushedTexture():GetBlendMode())
      assert.are.equal(12345, b:GetDisabledTexture():GetTexture())
    end)

    it("tints a state without replacing what it draws", function()
      local b = CreateFrame("Button")
      b:SetNormalTexture("template.png")
      apply:ButtonStates(b, { Normal = { VertexColor = { 0.5, 0.5, 0.5, 1 }, TexCoords = { 0.1, 0.9, 0.1, 0.9 }, Alpha = 0.8 } })
      assert.are.equal("template.png", b:GetNormalTexture():GetTexture())
      assert.are.same({ r = 0.5, g = 0.5, b = 0.5, a = 1 }, b:GetNormalTexture()._vertexColor)
      assert.are.same({ 0.1, 0.9, 0.1, 0.9 }, b:GetNormalTexture()._texCoords)
      assert.are.equal(0.8, b:GetNormalTexture():GetAlpha())
    end)

    it("clears a state set to false and keeps one left out", function()
      local b = CreateFrame("Button")
      b:SetHighlightTexture("h.png")
      b:SetPushedTexture("p.png")
      apply:ButtonStates(b, { Highlight = false })
      assert.is_nil(b:GetHighlightTexture():GetTexture())
      assert.are.equal("p.png", b:GetPushedTexture():GetTexture())
    end)

    it("gives a state new art without the tint, alpha, coordinates or inset of the last", function()
      local b = CreateFrame("Button")
      apply:ButtonStates(b, { Highlight = { Color = { 1, 0, 0, 0.3 }, TexCoords = { 0.1, 0.9, 0.1, 0.9 }, Alpha = 0.5,
        Inset = { Left = 2, Right = 2, Top = 2, Bottom = 2 } } })
      apply:ButtonStates(b, { Highlight = { Texture = "h.png" } })
      local region = b:GetHighlightTexture()
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, region._vertexColor)
      assert.are.same({ 0, 1, 0, 1 }, region._texCoords)
      assert.are.equal(1, region:GetAlpha())
      assert.are.equal(b, region._allPoints)
      assert.are.equal(2, region:GetNumPoints())
      assert.are.same({ "TOPLEFT", b, "TOPLEFT", 0, 0 }, { region:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0 }, { region:GetPoint(2) })
    end)

    it("insets a state's region", function()
      local b = CreateFrame("Button")
      apply:ButtonStates(b, { Highlight = { Texture = "h.png", Inset = { Left = 1, Right = 1, Top = 1, Bottom = 1 } } })
      assert.are.same({ "TOPLEFT", b, "TOPLEFT", 1, -1 }, { b:GetHighlightTexture():GetPoint(1) })
    end)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
