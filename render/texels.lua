local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Texels draws BetterBags' bags without the client's texture sharpening (texture-sharpening.md). By default the client
-- rounds a texture's corners to the pixel grid as it draws and "sharpens" what is in it, picking a texel rather than
-- blending two (a Blizzard developer on warcraft.wiki.gg, TextureBase:SetTexelSnappingBias: "anything >0 implies
-- snapToPixelGrid; the stronger the texelSnappingBias the more aggressive the renderer will be in selecting a texel
-- instead of blending texels"). Measured in game (retail 12.1.5): while a bag was resized, each icon's art was picked
-- up to half a pixel differently from frame to frame though the icon never moved (its rect the same at every step);
-- with sharpening off on every texture of the bag, it held still. Blizzard turns it off on its own textures that
-- resize (PlayerFrame.lua, TargetFrame.lua, NineSliceUtil.DisableSharpening), ElvUI on every texture it touches.
---@class Texels: AceModule
local texels = addon:NewModule('Texels')

-- The regions the client sharpens: TextureBase's (SimpleTextureBaseAPIDocumentation, every client). Text is drawn
-- by the client's font renderer and has no such setting.
local SHARPENED = { Texture = true, MaskTexture = true, Line = true }

-- Frames that draw their own textures each time they are drawn (an item button): a window's walk leaves them out, so
-- a bag of hundreds of buttons is walked by the buttons that changed, not all of them on every draw.
local own = setmetatable({}, { __mode = "k" })

-- DrawsItself marks a frame whose draws unsharpen it themselves (Unsharpen with it as the root): the walk of a window
-- it is in leaves it out.
---@param frame Frame
function texels:DrawsItself(frame)
  own[frame] = true
end

-- Unsharpen turns the client's sharpening off on every texture, line and mask under root, shown or not (a hover
-- highlight shows later with no draw), but under a frame that draws itself (DrawsItself), unless that frame is root.
-- It sets them every time: whether a new file or atlas brings the sharpening back is not known. It returns how many
-- it set, for profiler traces.
---@param root Frame
---@return number
function texels:Unsharpen(root)
  local count = 0
  local function walk(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
      if SHARPENED[region:GetObjectType()] then
        region:SetSnapToPixelGrid(false)
        region:SetTexelSnappingBias(0)
        count = count + 1
      end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
      if not own[child] then
        walk(child)
      end
    end
  end
  walk(root)
  return count
end
