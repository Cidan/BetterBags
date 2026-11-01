local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Motion positions the frames of a layout: each anchored by its TOPLEFT to the TOPLEFT of the
-- frame it hangs from, at an offset. In a pass of a root (BeginPass .. EndPass: one render of a
-- bag's canvas), a frame the root's previous pass also placed travels from where it is to its new
-- place. Anything else is placed at once: outside a pass, in a root's first pass (and its first
-- after Forget), and a frame the previous pass did not place (newly shown, or released and drawn
-- again).
--
-- Only frames whose place changed move, each on its own, and an offset is from the frame a frame
-- hangs from: a section can move while its items stay put in it, an item can move inside a section
-- that stays, and both can move at once. A frame that changes parent starts where it was: its old
-- and new places are worked out from the anchors (and links) up to the frame both hang from.
--
-- A move eases slow, fast, slow: a cubic that starts and ends at rest, over MOVE_DURATION, or the
-- duration the pass that started it gives. Turned toward a new place mid-move, a frame keeps its
-- speed rather than stopping first. A pass under a stop motion ({ FPS, Wobble }: a theme's, next-themes.md §25) holds each
-- pose of its moves for a whole frame, a little off its line, and still ends exactly where it goes.
---@class Motion: AceModule
local motion = addon:NewModule('Motion')

-- Where a stop motion's wobble takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
motion.Random = math.random

-- How long a move takes, in seconds.
local MOVE_DURATION = 0.3

-- How close a frame may be to its place and count as there: closer than this it is put there at
-- once. Anchors read back from the client carry float error.
local CLOSE = 0.5

-- How close a frame's anchor must be to its place for it to be left alone.
local EXACT = 0.01

-- A size snapping to what it holds (a window to its content, window.md §3b; a BetterBags Next panel to its columns,
-- next.md §14g): the share of the snap spent reaching the bounce, and how far past the size the bounce goes (a share
-- of the distance, at most SNAP_OVERSHOOT). The bounce stays inside the room a scroll box keeps beside its content.
local SNAP_TURN = 0.65
local SNAP_OVERSHOOT = 10
local SNAP_OVERSHOOT_SHARE = 0.1

-- SnapSizeAt returns a width or height of a snap from from to to at progress p (0 to 1): it eases out to overshoot
-- past to by SNAP_TURN of the way, then settles back on to.
---@param from number
---@param to number
---@param overshoot number
---@param p number
---@return number
function motion.SnapSizeAt(from, to, overshoot, p)
  if p <= 0 then
    return from
  end
  if p >= 1 then
    return to
  end
  local low = to - overshoot
  if p <= SNAP_TURN then
    local q = p / SNAP_TURN
    return from + (low - from) * (1 - (1 - q) ^ 3)
  end
  local q = (p - SNAP_TURN) / (1 - SNAP_TURN)
  return low + overshoot * q * q * (3 - 2 * q)
end

-- SnapOvershoot returns how far a snap from from to to bounces past to: a share of the distance, at most
-- SNAP_OVERSHOOT, never below floor (the size's minimum); none for a size that grows.
---@param from number
---@param to number
---@param floor number
---@return number
function motion.SnapOvershoot(from, to, floor)
  return math.max(0, math.min(SNAP_OVERSHOOT, (from - to) * SNAP_OVERSHOOT_SHARE, to - floor))
end

---@class (exact) Move
---@field root any The root whose pass started it.
---@field relativeTo Frame
---@field x0 number Where it started.
---@field y0 number
---@field vx number Its speed at the start, in pixels per second.
---@field vy number
---@field x1 number Where it goes.
---@field y1 number
---@field elapsed number
---@field duration number How long it takes, in seconds.
---@field x number Where it was put last.
---@field y number
---@field stepping? table The stop motion it runs under: its FPS and Wobble.
---@field pose? integer The pose it holds under one.

---@class (exact) MotionLink
---@field to Frame
---@field offset fun(): number, number

---@class (exact) MotionPass
---@field root any
---@field id number
---@field previous? number The id of the root's previous pass.
---@field started number
---@field duration? number How long the moves it starts take, when not MOVE_DURATION.
---@field stepping? table The stop motion the moves it starts run under.

-- reset empties every table; the driver stops.
local function reset()
  motion.moves = {} ---@type table<Frame, Move>
  motion.placed = {} ---@type table<Frame, number> The pass that placed each frame last.
  motion.roots = {} ---@type table<any, {current: number}>
  motion.links = motion.links or {} ---@type table<Frame, MotionLink>
  motion.pass = nil ---@type MotionPass?
  motion.nextPass = motion.nextPass or 0
  if motion.driver ~= nil then
    motion.driver:SetScript("OnUpdate", nil)
  end
end

reset()

-- Init forgets every move and pass. Links stay: they belong to frames that last the session.
function motion:Init()
  reset()
end

-- at returns where a move is at u (0 to 1 of its duration), and its speed: a cubic Hermite from its
-- start (at its start speed) to where it goes (at rest). From rest it is 3u^2 - 2u^3.
---@param move Move
---@param u number
---@return number x, number y, number vx, number vy
local function at(move, u)
  local u2 = u * u
  local u3 = u2 * u
  local h00, h10, h01 = 2 * u3 - 3 * u2 + 1, u3 - 2 * u2 + u, 3 * u2 - 2 * u3
  local d00, d10, d01 = 6 * u2 - 6 * u, 3 * u2 - 4 * u + 1, 6 * u - 6 * u2
  local t = move.duration
  local x = h00 * move.x0 + h10 * t * move.vx + h01 * move.x1
  local y = h00 * move.y0 + h10 * t * move.vy + h01 * move.y1
  local vx = (d00 * move.x0 + d10 * t * move.vx + d01 * move.x1) / t
  local vy = (d00 * move.y0 + d10 * t * move.vy + d01 * move.y1) / t
  return x, y, vx, vy
end

---@param frame Frame
---@param relativeTo Frame
---@param x number
---@param y number
local function anchor(frame, relativeTo, x, y)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, y)
end

-- put anchors frame at x, y from relativeTo, unless it is anchored there already.
---@param frame Frame
---@param relativeTo Frame
---@param x number
---@param y number
local function put(frame, relativeTo, x, y)
  if frame:GetNumPoints() == 1 then
    local point, rel, relPoint, ox, oy = frame:GetPoint(1)
    if rel == relativeTo and point == "TOPLEFT" and relPoint == "TOPLEFT"
      and math.abs(ox - x) < EXACT and math.abs(oy - y) < EXACT then
      return
    end
  end
  anchor(frame, relativeTo, x, y)
end

-- locate returns where frame's top left is from the top left of the highest frame its anchors lead
-- to, and that frame: it follows links, and anchors from a TOPLEFT to a TOPLEFT.
---@param frame Frame
---@return number x, number y, Frame top
local function locate(frame)
  local x, y, f = 0, 0, frame
  for _ = 1, 64 do
    local link = motion.links[f]
    if link ~= nil then
      local lx, ly = link.offset()
      x, y, f = x + lx, y + ly, link.to
    else
      local point, relativeTo, relativePoint, ox, oy = f:GetPoint(1)
      if point ~= "TOPLEFT" or relativePoint ~= "TOPLEFT" or type(relativeTo) ~= "table" then
        return x, y, f
      end
      x, y, f = x + ox, y + oy, relativeTo
    end
  end
  return x, y, f
end

-- whereIn returns where frame is now, as an offset from relativeTo's top left, or nil when its
-- anchors do not lead to the frame relativeTo's lead to.
---@param frame Frame
---@param relativeTo Frame
---@return number? x, number? y
local function whereIn(frame, relativeTo)
  local point, rel, relPoint, ox, oy = frame:GetPoint(1)
  if rel == relativeTo and point == "TOPLEFT" and relPoint == "TOPLEFT" then
    return ox, oy
  end
  local fx, fy, frameTop = locate(frame)
  local px, py, parentTop = locate(relativeTo)
  if frameTop ~= parentTop then
    return nil, nil
  end
  return fx - px, fy - py
end

-- Link says where frame's top left is when that is not one of its anchors: offset() from to's top
-- left. A section links its cells' frame, which Blizzard's scroll box positions, to its own frame.
---@param frame Frame
---@param to Frame
---@param offset fun(): number, number
function motion:Link(frame, to, offset)
  self.links[frame] = { to = to, offset = offset }
end

-- BeginPass starts placing root's frames: frames root's previous pass placed move to their new
-- places, the rest are placed at once. duration is how long the moves it starts take (default
-- MOVE_DURATION), and stepping the stop motion they run under (none: every frame).
---@param root any
---@param duration? number
---@param stepping? table
function motion:BeginPass(root, duration, stepping)
  self.nextPass = self.nextPass + 1
  local state = self.roots[root]
  if state == nil then
    state = {}
    self.roots[root] = state
  end
  self.pass = { root = root, id = self.nextPass, previous = state.current, started = 0, duration = duration,
    stepping = stepping }
  state.current = self.nextPass
end

-- EndPass ends the pass and returns how many moves it started.
---@return number
function motion:EndPass()
  local pass = self.pass
  self.pass = nil
  return pass and pass.started or 0
end

-- Place puts frame at x, y from relativeTo's top left: moving from where it is when the root's
-- previous pass placed it too, at once otherwise.
---@param frame Frame
---@param relativeTo Frame
---@param x number
---@param y number
function motion:Place(frame, relativeTo, x, y)
  local pass = self.pass
  local move = self.moves[frame]
  if pass == nil then
    self.moves[frame] = nil
    put(frame, relativeTo, x, y)
    return
  end
  -- Pass ids are unique across roots, so a frame placed by the root's previous pass was placed
  -- by this root.
  local placedBefore = pass.previous ~= nil and self.placed[frame] == pass.previous
  self.placed[frame] = pass.id
  if not placedBefore then
    self.moves[frame] = nil
    put(frame, relativeTo, x, y)
    return
  end
  if move ~= nil and move.relativeTo == relativeTo and move.x1 == x and move.y1 == y then
    return
  end
  local cx, cy = whereIn(frame, relativeTo)
  local vx, vy = 0, 0
  if move ~= nil then
    local _, _, mvx, mvy = at(move, math.min(1, move.elapsed / move.duration))
    vx, vy = mvx, mvy
  end
  self.moves[frame] = nil
  if cx == nil or cy == nil or (math.abs(cx - x) < CLOSE and math.abs(cy - y) < CLOSE) then
    put(frame, relativeTo, x, y)
    return
  end
  self.moves[frame] = {
    root = pass.root, relativeTo = relativeTo, x0 = cx, y0 = cy, vx = vx, vy = vy, x1 = x, y1 = y,
    elapsed = 0, duration = pass.duration or MOVE_DURATION, x = cx, y = cy, stepping = pass.stepping,
  }
  anchor(frame, relativeTo, cx, cy)
  pass.started = pass.started + 1
  self:run()
end

-- GetMove returns where a moving frame started and where it goes, or nothing when it is not moving.
---@param frame Frame
---@return number? x0, number? y0, number? x1, number? y1
function motion:GetMove(frame)
  local move = self.moves[frame]
  if move == nil then
    return
  end
  return move.x0, move.y0, move.x1, move.y1
end

-- Forget ends root's moves where they were going and forgets which frames it placed, so its next
-- pass places everything at once. A bag forgets when it hides.
---@param root any
function motion:Forget(root)
  for frame, move in pairs(self.moves) do
    if move.root == root then
      self.moves[frame] = nil
      local _, rel = frame:GetPoint(1)
      if rel == move.relativeTo then
        anchor(frame, move.relativeTo, move.x1, move.y1)
      end
    end
  end
  self.roots[root] = nil
  self:stopIfIdle()
end

---@private
function motion:run()
  if self.driver == nil then
    self.driver = CreateFrame("Frame")
  end
  if self.driver:GetScript("OnUpdate") == nil then
    self.driver:SetScript("OnUpdate", function(_, elapsed)
      self:Step(elapsed)
    end)
  end
end

---@private
function motion:stopIfIdle()
  if next(self.moves) == nil and self.driver ~= nil then
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- pose is where a move under a stop motion lands when it has reached a new frame (nothing while it holds its last): on
-- its way at that frame's time, a little off its line.
---@private
---@param move Move
---@return number? x, number? y
function motion:pose(move)
  local S = move.stepping
  local pose = math.floor(move.elapsed * S.FPS + 1e-6)
  if pose <= (move.pose or 0) then
    return nil, nil
  end
  move.pose = pose
  local x, y = at(move, pose / S.FPS / move.duration)
  local wobble = S.Wobble or 0
  return x + (2 * self.Random() - 1) * wobble, y + (2 * self.Random() - 1) * wobble
end

-- Step moves every moving frame elapsed seconds along. A move whose frame something else
-- re-anchored, released or hid is dropped: that frame is not ours to move any more.
---@param elapsed number
function motion:Step(elapsed)
  for frame, move in pairs(self.moves) do
    local point, rel, relPoint, ox, oy = frame:GetPoint(1)
    if rel ~= move.relativeTo or point ~= "TOPLEFT" or relPoint ~= "TOPLEFT"
      or math.abs(ox - move.x) > CLOSE or math.abs(oy - move.y) > CLOSE or not frame:IsShown() then
      self.moves[frame] = nil
    else
      move.elapsed = move.elapsed + elapsed
      local x, y
      if move.elapsed >= move.duration then
        x, y = move.x1, move.y1
        self.moves[frame] = nil
      elseif move.stepping ~= nil then
        x, y = self:pose(move)
      else
        x, y = at(move, move.elapsed / move.duration)
      end
      if x ~= nil then
        anchor(frame, move.relativeTo, x, y)
        move.x, move.y = x, y
      end
    end
  end
  self:stopIfIdle()
end
