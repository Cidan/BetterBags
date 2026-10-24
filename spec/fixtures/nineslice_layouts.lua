-- Blizzard's nine-slice layouts BetterBags Next's Plain theme draws (docs/next-plain-theme.md), copied verbatim from
-- Blizzard's UI source (.libraries/wow-ui-source):
--   Retail: live, Interface/AddOns/Blizzard_SharedXML/Mainline/NineSliceLayouts.lua (forever's file is the same).
--   Classic: classic_era, classic and classic_anniversary, Interface/AddOns/Blizzard_SharedXML/Classic/NineSliceLayouts.lua
--     (the same three tables on every Classic branch).
--   Forever: Retail with forever's Interface/AddOns/Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua applied,
--     which adjusts NineSliceLayouts in place at load (copied below).
-- The client's NineSliceUtil.GetLayout(name) returns NineSliceLayouts[name] (Blizzard_SharedXML/NineSlice.lua).

local layouts = {}

layouts.Retail = {
  ButtonFrameTemplateNoPortrait =
  {
    disableSharpening = true,
    TopLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -8, y = 16, },
    TopRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16, },
    BottomLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -8, y = -3, },
    BottomRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
    TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", },
    BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", },
    LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", },
    RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", },
  },
  Dialog =
  {
    TopLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopLeft", },
    TopRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopRight", },
    BottomLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomLeft", },
    BottomRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomRight", },
    TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop", },
    BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom", },
    LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft", },
    RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight", },
  },
  HeldBagLayout =
  {
    disableSharpening = true,
    TopLeftCorner =	{ layer = "OVERLAY", atlas = "ui-frame-portraitmetal-cornertopleftsmall", x = -13, y = 16, },
    TopRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16, },
    BottomLeftCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3, },
    BottomRightCorner =	{ layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3, },
    TopEdge = { layer="OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0, },
    BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0, },
    LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0 },
    RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0, },
  },
}

layouts.Classic = {
  Dialog =
  {
    TopLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopLeft", },
    TopRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerTopRight", },
    BottomLeftCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomLeft", },
    BottomRightCorner =	{ atlas = "UI-Frame-DiamondMetal-CornerBottomRight", },
    TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop", },
    BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom", },
    LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft", },
    RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight", },
  },
  ButtonFrameTemplateNoPortrait =
  {
    TopLeftCorner = {  atlas = "UI-Frame-TopLeftCornerNoPortrait"},
    TopRightCorner = {  atlas = "UI-Frame-TopCornerRight"},
    BottomLeftCorner = {  atlas = "UI-Frame-BotCornerLeft",},
    BottomRightCorner = {  atlas = "UI-Frame-BotCornerRight",},
    TopEdge = {  atlas = "_UI-Frame-TitleTile", },
    BottomEdge = {  atlas = "_UI-Frame-Bot"},
    LeftEdge = {  atlas = "!UI-Frame-LeftTile", },
    RightEdge = {  atlas = "!UI-Frame-RightTile",  x = -8, x1 = 8},
  },
}

-- Forever: a copy of Retail's tables with Camelot/NineSliceLayoutOverrides.lua's adjustments applied.
local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

-- Adjustments are added to whatever the existing offset value is, while overrides completely replace it.
local NINE_SLICE_OFFSET_OVERRIDES =
{
  {
    pieceName = "TopRightCorner",
    atlas = "UI-Frame-Metal-CornerTopRight",
    xAdjustment = -2,
  },
  {
    pieceName = "TopRightCorner",
    atlas = "UI-Frame-Metal-CornerTopRightDouble",
    xAdjustment = -2,
  },
  {
    pieceName = "BottomLeftCorner",
    atlas = "UI-Frame-Metal-CornerBottomLeft",
    yOverride = -8,
  },
  {
    pieceName = "BottomRightCorner",
    atlas = "UI-Frame-Metal-CornerBottomRight",
    xAdjustment = -2,
    yOverride = -8,
  },
};

layouts.Forever = copy(layouts.Retail)
for _, layout in pairs(layouts.Forever) do
  for _, offsetOverride in ipairs(NINE_SLICE_OFFSET_OVERRIDES) do
    local piece = layout[offsetOverride.pieceName]
    if piece and piece.atlas == offsetOverride.atlas then
      if offsetOverride.xAdjustment then
        piece.x = (piece.x or 0) + offsetOverride.xAdjustment
      end
      if offsetOverride.yOverride then
        piece.y = offsetOverride.yOverride
      end
    end
  end
end

return layouts
