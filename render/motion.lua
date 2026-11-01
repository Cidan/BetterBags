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
-- A frame that says what it shows (Place's shows: an item button, ShownBy) moves by that, not by the frame: a button belongs to a
-- bag slot, and a sort moves items from button to button while the bag can look exactly as it did. Shown where it already showed
-- it stays, whichever button shows it now; shown somewhere else it travels from where it showed, on the button that shows it now,
-- across sections too, even out of one that has gone; never shown in the last pass, it is put there at once. These are placed at
-- the pass's end, once every frame of the pass has said where it goes.
--
-- A move eases slow, fast, slow: a cubic that starts and ends at rest, over MOVE_DURATION, or the
-- duration the pass that started it gives. Turned toward a new place mid-move, a frame keeps its
-- speed rather than stopping first. A pass under a stop motion ({ FPS, Wobble }: a theme's, next-themes.md §25) holds each
-- pose of its moves for a whole frame, a little off its line, and still ends exactly where it goes.
---@class Motion: AceModule
local motion = addon:NewModule('Motion')

-- Where a stop motion's wobble takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
motion.Random = math.random

-- What an empty slot shows, for Place: one looks like another, so it stays put when slots change hands, and never travels from
-- where another stood. It still moves from its own place when the rows change.
motion.NOTHING = "nothing"

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
---@field pending? table<Frame, MotionPending> What shows something new, or somewhere new, placed when the pass ends.
---@field stop? Frame The root's own frame, which places in different frames are measured from: what moves all of it (a scroll box,
---a window dragged) moves nothing within it.

---@class (exact) MotionShown What a frame showed, and where, in a root's last pass.
---@field frame Frame
---@field shows string
---@field relativeTo Frame
---@field x number
---@field y number
---@field pass number The pass that last placed it.
---@field taken? number The pass that started something from it.

---@class (exact) MotionPending
---@field shows string
---@field relativeTo Frame
---@field x number
---@field y number
---@field source? MotionShown Where what it shows showed.
---@field fromX? number Where its source stands now, in its source's frame.
---@field fromY? number
---@field vx? number Its source's speed, in flight.
---@field vy? number

-- reset empties every table; the driver stops.
local function reset()
  motion.moves = {} ---@type table<Frame, Move>
  motion.placed = {} ---@type table<Frame, number> The pass that placed each frame last.
  motion.roots = {} ---@type table<any, {current: number, shown: table<Frame, MotionShown>, origins: table<Frame, {x: number, y: number, top: Frame}>}>
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
-- to, or of stop when they lead there, and that frame: it follows links, and anchors from a TOPLEFT
-- to a TOPLEFT. With resting, a moving frame counts as where it is going. With letGo, a frame let go
-- of on its way counts as where it had got to: its anchors are gone, and its move stays until the next Step.
---@param frame Frame
---@param resting? boolean
---@param stop? Frame
---@param letGo? boolean
---@return number x, number y, Frame top
local function locate(frame, resting, stop, letGo)
  local x, y, f = 0, 0, frame
  for _ = 1, 64 do
    if f == stop then
      return x, y, f
    end
    local link = motion.links[f]
    local move = resting and motion.moves[f]
    if link ~= nil then
      local lx, ly = link.offset()
      x, y, f = x + lx, y + ly, link.to
    elseif move then
      x, y, f = x + move.x1, y + move.y1, move.relativeTo
    else
      local point, relativeTo, relativePoint, ox, oy = f:GetPoint(1)
      local stopped = letGo and point == nil and motion.moves[f]
      if stopped then
        x, y, f = x + stopped.x, y + stopped.y, stopped.relativeTo
      elseif point ~= "TOPLEFT" or relativePoint ~= "TOPLEFT" or type(relativeTo) ~= "table" then
        return x, y, f
      else
        x, y, f = x + ox, y + oy, relativeTo
      end
    end
  end
  return x, y, f
end

-- close says whether two places are near enough to count as one.
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return boolean
local function close(ax, ay, bx, by)
  return math.abs(ax - bx) < CLOSE and math.abs(ay - by) < CLOSE
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

-- ShownBy says what a cell of a layout shows, for Place: an item button's item, as its look goes (itemHash: two stacks of one item
-- look alike whichever slot holds them), or NOTHING for an empty slot. Nothing for what is no item button, or holds no item.
---@param cell table
---@return string?
function motion.ShownBy(cell)
  if cell.GetItemData == nil then
    return nil
  end
  if cell.isFreeSlot then
    return motion.NOTHING
  end
  local data = cell:GetItemData()
  if data == nil then
    return nil
  end
  if data.isItemEmpty then
    return motion.NOTHING
  end
  return data.itemHash
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
  self:EndPass()
  self.nextPass = self.nextPass + 1
  local state = self.roots[root]
  if state == nil then
    state = { shown = {}, origins = {} }
    self.roots[root] = state
  end
  local stop = type(root) == "table" and root.frame or nil
  self.pass = { root = root, id = self.nextPass, previous = state.current, started = 0, duration = duration,
    stepping = stepping, stop = stop }
  state.current = self.nextPass
  -- Where each frame stands as the pass starts: what the last pass kept is where it was going, and a frame may be on its way, or
  -- something else (a canvas centering its layout) may have moved it. One let go of at rest keeps what was kept.
  for relativeTo, origin in pairs(state.origins) do
    local x, y, top = locate(relativeTo, false, stop, true)
    if top == origin.top then
      origin.x, origin.y = x, y
    end
  end
end

-- ForgetShown forgets what root's frames showed and where, so nothing travels from there: another tab or view shows other slots,
-- or the same ones in other sections, and an item looking like one shown before has not moved. What does not say what it shows goes
-- on moving as it was (Place).
---@param root any
function motion:ForgetShown(root)
  local state = self.roots[root]
  if state ~= nil then
    state.shown = {}
  end
end

-- EndPass places what the pass left for its end, ends it, and returns how many moves it started.
---@return number
function motion:EndPass()
  local pass = self.pass
  self.pass = nil
  if pass == nil then
    return 0
  end
  self:settleShown(pass)
  return pass.started
end

-- placeShown places a frame that says what it shows, in a pass. Showing what it showed where it showed it, nothing has changed on
-- screen and it is done here, with nothing kept. Anything else waits for the pass's end: a place can only be told free, or kept
-- by the same item on another button, once every frame has said where it goes.
---@private
---@param pass MotionPass
---@param frame Frame
---@param relativeTo Frame
---@param x number
---@param y number
---@param shows string
function motion:placeShown(pass, frame, relativeTo, x, y, shows)
  self.placed[frame] = pass.id
  local was = self.roots[pass.root].shown[frame]
  if was ~= nil and was.shows == shows and was.relativeTo == relativeTo and close(was.x, was.y, x, y) then
    was.pass, was.x, was.y = pass.id, x, y
    if pass.pending ~= nil then
      pass.pending[frame] = nil
    end
    local move = self.moves[frame]
    if move ~= nil and select(2, frame:GetPoint(1)) == relativeTo then
      move.x1, move.y1 = x, y
    else
      self.moves[frame] = nil
      put(frame, relativeTo, x, y)
    end
    return
  end
  pass.pending = pass.pending or {}
  pass.pending[frame] = { shows = shows, relativeTo = relativeTo, x = x, y = y }
end

-- findSources gives what the pass left for its end where what it shows showed in the last pass, each place once: the place it is
-- going to first, for an item that changed buttons only; then its own, for a button that kept its item; then, unless it shows
-- nothing, the nearest left, for an item that changed place.
---@private
---@param pass MotionPass
---@param shown table<Frame, MotionShown>
---@param origins table<Frame, {x: number, y: number, top: Frame}>
function motion:findSources(pass, shown, origins)
  local bySight = {}
  -- Places by frame, then by whole x and y, so a bag full of what looks alike is not searched for each: a place within CLOSE of
  -- another is at most one whole number off along each axis.
  local byPlace = {}
  for _, entry in pairs(shown) do
    if entry.pass ~= pass.id then
      local list = bySight[entry.shows]
      if list == nil then
        list = {}
        bySight[entry.shows] = list
      end
      table.insert(list, entry)
      local xs = byPlace[entry.relativeTo]
      if xs == nil then
        xs = {}
        byPlace[entry.relativeTo] = xs
      end
      local gx, gy = math.floor(entry.x + 0.5), math.floor(entry.y + 0.5)
      local ys = xs[gx]
      if ys == nil then
        ys = {}
        xs[gx] = ys
      end
      local here = ys[gy]
      if here == nil then
        here = {}
        ys[gy] = here
      end
      table.insert(here, entry)
    end
  end
  local function take(p, entry)
    entry.taken = pass.id
    p.source = entry
  end
  local function shownThere(p)
    local xs = byPlace[p.relativeTo]
    if xs == nil then
      return nil
    end
    local gx, gy = math.floor(p.x + 0.5), math.floor(p.y + 0.5)
    for ix = gx - 1, gx + 1 do
      local ys = xs[ix]
      for iy = gy - 1, gy + 1 do
        for _, entry in ipairs(ys and ys[iy] or {}) do
          if entry.shows == p.shows and close(entry.x, entry.y, p.x, p.y) then
            return entry
          end
        end
      end
    end
    return nil
  end
  for _, p in pairs(pass.pending) do
    local entry = shownThere(p)
    if entry ~= nil then
      take(p, entry)
    end
  end
  for frame, p in pairs(pass.pending) do
    local own = shown[frame]
    if p.source == nil and own ~= nil and own.shows == p.shows and own.taken ~= pass.id then
      take(p, own)
    end
  end
  for _, p in pairs(pass.pending) do
    if p.source == nil and p.shows ~= motion.NOTHING then
      local px, py, top = locate(p.relativeTo, false, pass.stop)
      local nearest, distance
      for _, entry in ipairs(bySight[p.shows] or {}) do
        local origin = origins[entry.relativeTo]
        if entry.taken ~= pass.id and origin ~= nil and origin.top == top then
          local dx, dy = origin.x + entry.x - px - p.x, origin.y + entry.y - py - p.y
          local d = dx * dx + dy * dy
          if distance == nil or d < distance then
            nearest, distance = entry, d
          end
        end
      end
      if nearest ~= nil then
        take(p, nearest)
      end
    end
  end
end

-- settleShown places what the pass left for its end, then keeps what each frame shows and where, for the next pass. What no frame
-- showed in this pass is forgotten: it left the bags, or the view.
---@private
---@param pass MotionPass
function motion:settleShown(pass)
  local state = self.roots[pass.root]
  if state == nil then
    return
  end
  local shown, origins = state.shown, state.origins
  local pending = pass.pending
  if pending ~= nil then
    self:findSources(pass, shown, origins)
    -- Where each source stands, before anything moves: an icon in flight goes on from where it has got to.
    for _, p in pairs(pending) do
      local source = p.source
      if source ~= nil then
        local move = self.moves[source.frame]
        if move ~= nil then
          local _, _, vx, vy = at(move, math.min(1, move.elapsed / move.duration))
          p.fromX, p.fromY, p.vx, p.vy = move.x, move.y, vx, vy
        else
          p.fromX, p.fromY = source.x, source.y
        end
      end
    end
    for frame, p in pairs(pending) do
      self:startShown(pass, origins, frame, p)
    end
    for frame, p in pairs(pending) do
      local entry = shown[frame]
      if entry == nil then
        entry = { frame = frame }
        shown[frame] = entry
      end
      entry.shows, entry.relativeTo, entry.x, entry.y, entry.pass = p.shows, p.relativeTo, p.x, p.y, pass.id
    end
  end
  local fresh = {}
  for frame, entry in pairs(shown) do
    if entry.pass ~= pass.id then
      shown[frame] = nil
    elseif fresh[entry.relativeTo] == nil then
      local x, y, top = locate(entry.relativeTo, true, pass.stop)
      fresh[entry.relativeTo] = { x = x, y = y, top = top }
    end
  end
  state.origins = fresh
end

-- startShown puts a frame the pass left for its end where it goes: at once when what it shows has no place to travel from, or
-- is there already; otherwise travelling from there.
---@private
---@param pass MotionPass
---@param origins table<Frame, {x: number, y: number, top: Frame}>
---@param frame Frame
---@param p MotionPending
function motion:startShown(pass, origins, frame, p)
  local x0, y0
  local source = p.source
  if source ~= nil then
    if source.relativeTo == p.relativeTo then
      x0, y0 = p.fromX, p.fromY
    else
      local origin = origins[source.relativeTo]
      local px, py, top = locate(p.relativeTo, false, pass.stop)
      if origin ~= nil and origin.top == top then
        x0, y0 = origin.x + p.fromX - px, origin.y + p.fromY - py
      end
    end
  end
  self.moves[frame] = nil
  if x0 == nil or close(x0, y0, p.x, p.y) then
    put(frame, p.relativeTo, p.x, p.y)
    return
  end
  self.moves[frame] = {
    root = pass.root, relativeTo = p.relativeTo, x0 = x0, y0 = y0, vx = p.vx or 0, vy = p.vy or 0, x1 = p.x, y1 = p.y,
    elapsed = 0, duration = pass.duration or MOVE_DURATION, x = x0, y = y0, stepping = pass.stepping,
  }
  anchor(frame, p.relativeTo, x0, y0)
  pass.started = pass.started + 1
  self:run()
end

-- Place puts frame at x, y from relativeTo's top left: moving from where it is when the root's
-- previous pass placed it too, at once otherwise. A frame that says what it shows moves by that
-- instead, when the pass ends (the top of this file).
---@param frame Frame
---@param relativeTo Frame
---@param x number
---@param y number
---@param shows? string
function motion:Place(frame, relativeTo, x, y, shows)
  local pass = self.pass
  if pass ~= nil and shows ~= nil then
    self:placeShown(pass, frame, relativeTo, x, y, shows)
    return
  end
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
  if self.pass ~= nil and self.pass.root == root then
    self:EndPass()
  end
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
