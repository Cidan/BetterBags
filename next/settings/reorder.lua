local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

-- NextListReorder arranges a settings list's rows one under another and lets the player drag them to a
-- new place, the way BetterBags Next's sections are dragged (next.md §7; asked: "animate the move like we
-- do categories"): the row picked up is lifted (NextLift: it shrinks a little, casts a shadow and follows
-- the cursor), the list keeps a room its height where it would land, under the cursor, and the other rows
-- slide out of its way through Motion in the interaction time, as a bag's sections do (Time.Interaction).
-- Let go, the row lands into its room and the list's owner is told where it went. One for every list that
-- reorders (CLAUDE.md, "UI Consistency"): a bag's Order tab (its pins) and the Categories page's list
-- (the order of the categories, category-lifecycle.md §7). Each row belongs to its entry (rowOf), so a
-- row moved in the order slides to its new place.
---@class NextListReorder: AceModule
local reorder = addon:NewModule('NextListReorder')

---@class (exact) NextListReorderOptions
---@field box WowScrollBox The scroll box the list scrolls in.
---@field content Frame What the rows hang from, top down, anywhere in what the box scrolls.
---@field entries fun(): table[] The list's entries, in order; { name } can be dragged, others (headings) not.
---@field rowOf fun(entry: table): Frame The row frame that shows an entry, its own.
---@field heightOf fun(entry: table): number How tall an entry's row is.
---@field first? number The first place among the other rows a row may land (default 1).
---@field onDrop fun(name: string, after: number) A row let go after the entry at after in the list as it
--- was, counted with the row itself (0: before the first).

-- NextListDrag is a row's drag; NextLift fills in where it was grabbed and its scale.
---@class NextListDrag: NextLifted
---@field name string
---@field index number Where its room is among the other rows (it lands before the index-th of them).
---@field start number Where its room was at pickup.
---@field height number

---@class NextListReorderList
---@field opts NextListReorderOptions
---@field width? number The width the rows were last given.
---@field state? NextListDrag
---@field roomY? number Where the room was laid out last, down from the content's top.
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextListReorderList')

-- Create makes a list's arrangement. A drag ends (the row put back where it was) when the list hides.
---@param opts NextListReorderOptions
---@return NextListReorderList
function reorder:Create(opts)
  local list = setmetatable({ opts = opts }, { __index = listProto })
  addon.HookScript(opts.content, "OnHide", function()
    if list.state ~= nil then
      list:Cancel()
    end
  end)
  return list
end

-- find returns an entry's place in the list, or nil.
---@param entries table[]
---@param name string
---@return number?
local function find(entries, name)
  for i, entry in ipairs(entries) do
    if entry.name == name then
      return i
    end
  end
  return nil
end

-- Arrange puts every row in its place, width wide (the width it was last given when nil), one under
-- another, a dragged row's room among them; while the list shows, a row that changed place slides there
-- (Motion, Time.Interaction), else it is put there at once. The content is as tall as the rows. It
-- returns that height. A drag whose entry left the list ends, its row put back.
---@param width? number
---@return number
function listProto:Arrange(width)
  if width ~= nil then
    self.width = width
  end
  width = self.width or self.opts.content:GetWidth()
  local content, entries = self.opts.content, self.opts.entries()
  if self.state ~= nil and find(entries, self.state.name) == nil then
    self:putBack()
  end
  local state = self.state
  local animated = content:IsVisible()
  if animated then
    motion:BeginPass(self, style.Time.Interaction, style.StopMotion)
  else
    motion:Forget(self)
  end
  local y, others = 0, 0
  self.roomY = nil
  local function room()
    self.roomY = y
    y = y + state.height
  end
  for _, entry in ipairs(entries) do
    if state == nil or entry.name ~= state.name then
      others = others + 1
      if state ~= nil and others == state.index then
        room()
      end
      local row = self.opts.rowOf(entry)
      row:SetWidth(width)
      motion:Place(row, content, 0, -y)
      y = y + self.opts.heightOf(entry)
    end
  end
  if state ~= nil and state.index > others then
    room()
  end
  if animated then
    motion:EndPass()
  end
  content:SetHeight(math.max(1, y))
  self.opts.box:FullUpdate(true)
  return y
end

-- IsDragging says whether a row is being dragged.
---@return boolean
function listProto:IsDragging()
  return self.state ~= nil
end

-- Start picks the row of the entry named up, unless a row is already being dragged here or anywhere
-- (NextLift holds one frame at a time), or the client has not placed it yet. It returns whether it did.
---@param name string
---@return boolean
function listProto:Start(name)
  if self.state ~= nil or lift:IsHolding() then
    return false
  end
  local entries = self.opts.entries()
  local at = find(entries, name)
  if at == nil then
    return false
  end
  local entry = entries[at]
  ---@type NextListDrag
  local state = { name = name, index = at, start = at, height = self.opts.heightOf(entry) }
  if not lift:Pick(state, self.opts.rowOf(entry), function(elapsed) self:Update(elapsed) end) then
    return false
  end
  self.state = state
  self:Arrange()
  return true
end

-- IndexAt returns where among the other rows a row let go where the cursor is would land: before the
-- first whose middle is below the cursor, kept from the first place it may land; nil while the list has
-- no place on screen.
---@return number?
function listProto:IndexAt()
  -- The cursor is on the screen; the list in its own units (the settings window scales down to fit a
  -- small screen).
  local at = lift:ScreenPoint(self.opts.content)
  if at == nil then
    return nil
  end
  local _, cursorY = lift:Cursor()
  local down = (at.top - cursorY) / at.scale
  local y, index, others = 0, nil, 0
  for _, entry in ipairs(self.opts.entries()) do
    if entry.name ~= self.state.name then
      others = others + 1
      local height = self.opts.heightOf(entry)
      if index == nil and down < y + height / 2 then
        index = others
      end
      y = y + height
    end
  end
  return math.max(self.opts.first or 1, index or (others + 1))
end

-- Update runs a frame of the drag: the row follows the cursor, its room moves under the cursor (the
-- other rows sliding out of its way) and the list scrolls near its edges; once the left button is up,
-- the row is let go.
---@param elapsed number
function listProto:Update(elapsed)
  local state = self.state
  if state == nil or state.landing then
    return
  end
  if not IsMouseButtonDown("LeftButton") then
    self:Drop()
    return
  end
  local x, y = lift:Cursor()
  lift:Place(state, x, y)
  local index = self:IndexAt()
  if index ~= nil and index ~= state.index then
    state.index = index
    self:Arrange()
  end
  local box = self.opts.box
  lift:AutoScroll(box, box, y, elapsed)
end

-- Drop lets the row go: it lands into its room (aiming at it every frame: the list may still be
-- scrolling), then takes that place (land).
function listProto:Drop()
  local state = self.state
  if state == nil or state.landing then
    return
  end
  state.landing = true
  lift:Land(state, function(left0, top0)
    local at = lift:ScreenPoint(self.opts.content)
    if at == nil then
      return left0, top0
    end
    return at.left, at.top - (self.roomY or 0) * at.scale, at.scale
  end, function()
    self:land()
  end)
end

-- land ends a drag whose row landed: the row goes back in the list and its owner is told where it went
-- (nothing when it is where it was). An owner that draws the list again shows the new order; otherwise
-- the list shows it.
---@private
function listProto:land()
  local state = self.state
  local entries = self.opts.entries()
  local from = find(entries, state.name)
  self:putBack()
  if from == nil or state.index == state.start then
    self:Arrange()
    return
  end
  local after = state.index - 1
  if after >= from then
    after = state.index
  end
  self.opts.onDrop(state.name, after)
  if self.opts.entries() == entries then
    local entry = table.remove(entries, from)
    table.insert(entries, state.index, entry)
    self:Arrange()
  end
end

-- putBack puts the dragged row back in the list (its owner places it) and ends the drag.
---@private
function listProto:putBack()
  local state = self.state
  tween:Stop(state)
  lift:Put(state, self.opts.content)
  self.state = nil
end

-- Cancel ends a drag at once, the row straight back in its place.
function listProto:Cancel()
  if self.state == nil then
    return
  end
  self:putBack()
  self:Arrange()
end
