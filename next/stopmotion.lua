local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextStopMotion is a Next theme's say that its animations run as stop motion (Motion.StopMotion, next-themes.md §25; the
-- Papercraft theme; asked: "the animations? should be stop-motion esque. meaning they are not just staggered in that stop
-- motion FPS, but imperfect in their placement from frame to frame"). FPS is how many poses a second, Spacing how far a
-- pose lands from its even place, as a share of a frame's step (under a half, so it never goes back), Wobble how many
-- units a moving frame lands off its line. NextTween steps every tween by it, Motion the frames a layout moves, and
-- NextPaper, NextSparkles and the ornaments' boil draw by it. A theme without Motion.StopMotion runs everything every frame.
---@class NextStopMotion: AceModule
local stopMotion = addon:NewModule('NextStopMotion')

-- Spec returns the theme's Motion.StopMotion, nil without one.
---@return table?
function stopMotion:Spec()
  return style.Theme.Motion.StopMotion or nil
end

-- Frame is which frame t seconds falls in, whatever the float error in adding its time up.
---@param t number
---@param fps number
---@return integer
function stopMotion:Frame(t, fps)
  return math.floor(t * fps + 1e-6)
end

-- Noise is a number from -1 to 1 for a frame and a key, always the same for the same two: a held frame never moves.
---@param frame number
---@param key number
---@return number
function stopMotion:Noise(frame, key)
  return tween.Noise(frame, key)
end

tween.Stepping = function()
  return stopMotion:Spec()
end
