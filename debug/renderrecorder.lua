local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- RenderRecorder records how BetterBags' windows render, for debugging layout and sizing: while
-- it records, every render of a window that changed what the window shows adds a snapshot of the
-- window, from its frame down to its item buttons, and every step of a resize or a move adds the
-- window's geometry. Recordings are kept in the BetterBagsPerfDB SavedVariable
-- (renderRecordings), read offline. Started and stopped from the debug window's Performance tab.
---@class RenderRecorder: AceModule
---@field recording boolean
---@field db table
---@field current? table The recording in progress.
local recorder = addon:NewModule('RenderRecorder')

recorder.recording = false

-- How many recordings are kept, and how many entries one recording takes before it stops
-- adding more.
recorder.MAX_RECORDINGS = 5
recorder.MAX_ENTRIES = 20000

---@param n? number
---@return string
local function num(n)
  return string.format("%.1f", n or 0)
end

-- Init keeps the recordings in BetterBagsPerfDB (PerfSessions creates it first) and saves a
-- recording still running at logout.
function recorder:Init()
  local db = BetterBagsPerfDB
  if type(db) ~= 'table' then
    db = {}
    BetterBagsPerfDB = db
  end
  if type(db.renderRecordings) ~= 'table' then
    db.renderRecordings = {}
  end
  if type(db.nextRenderRecordingId) ~= 'number' then
    db.nextRenderRecordingId = 1
  end
  self.db = db
  self.recording = false
  self.current = nil
  events:RegisterEvent('PLAYER_LOGOUT', function()
    self:Stop()
  end)
end

---@return boolean
function recorder:IsRecording()
  return self.recording
end

-- Start begins a recording; it does nothing while one runs.
---@return boolean started
function recorder:Start()
  if self.recording then
    return false
  end
  local gameVersion, gameBuild = GetBuildInfo()
  self.current = {
    id = self.db.nextRenderRecordingId,
    startedAt = time(),
    character = UnitName('player'),
    realm = GetRealmName(),
    gameVersion = gameVersion,
    gameBuild = gameBuild,
    entries = {},
  }
  self.db.nextRenderRecordingId = self.db.nextRenderRecordingId + 1
  self.started = debugprofilestop()
  self.last = {}
  self.recording = true
  events:SendMessage(context:New('RenderRecorder_Start'), 'renderRecorder/StateChanged', true)
  return true
end

-- Stop ends the recording and keeps it, the newest last, dropping the oldest past MAX_RECORDINGS.
---@return table? recording
function recorder:Stop()
  if not self.recording then
    return nil
  end
  self.recording = false
  local recording = self.current
  self.current = nil
  self.last = nil
  recording.stoppedAt = time()
  local list = self.db.renderRecordings
  table.insert(list, recording)
  while #list > self.MAX_RECORDINGS do
    table.remove(list, 1)
  end
  events:SendMessage(context:New('RenderRecorder_Stop'), 'renderRecorder/StateChanged', false)
  return recording
end

---@return number
function recorder:GetEntryCount()
  return self.current and #self.current.entries or 0
end

---@return table[]
function recorder:GetRecordings()
  return self.db and self.db.renderRecordings or {}
end

---@private
---@param entry table
function recorder:add(entry)
  local entries = self.current.entries
  if #entries >= self.MAX_ENTRIES then
    self.current.full = true
    return
  end
  entry.t = string.format("%.1f", debugprofilestop() - self.started)
  table.insert(entries, entry)
end

---@param frame Frame
---@param origin Frame
---@return string
local function rectIn(frame, origin)
  local left, top = frame:GetLeft(), frame:GetTop()
  local originLeft, originTop = origin:GetLeft(), origin:GetTop()
  local x = (left or 0) - (originLeft or 0)
  local y = (originTop or 0) - (top or 0)
  return string.format("@%s,%s %sx%s", num(x), num(y), num(frame:GetWidth()), num(frame:GetHeight()))
end

---@param window BetterBagsWindow
---@return Bag?
local function bagOf(window)
  for _, bag in pairs(addon.Bags or {}) do
    if type(bag) == "table" and bag.window == window then
      return bag
    end
  end
  return nil
end

---@param section Section
---@return string
local function titleOf(section)
  local title = section.title
  if title ~= nil and title.GetText ~= nil then
    return tostring(title:GetText())
  end
  return "?"
end

---@param frame? Frame
---@return boolean
local function shown(frame)
  return frame ~= nil and frame:IsShown() == true
end

-- buttonState describes what an item button shows: how it was last drawn ("item", "free" with
-- its count and bag name, "empty"), its quality border's color, Blizzard's padlock (the frame
-- ContainerFrameItemButtonMixin:UpdateExtended shows on a slot past the bag's usable slots,
-- which also stops the mouse), whether it takes the mouse, and the empty slot glyph.
---@param cell Item
---@return string
local function buttonState(cell)
  local parts = { tostring(cell.drawnAs) }
  if cell.drawnAs == "free" then
    table.insert(parts, string.format("count=%s name=%s", tostring(cell.freeSlotCount), tostring(cell.freeSlotName)))
  end
  local decoration = cell._decoration
  local border = "off"
  if decoration ~= nil and shown(decoration.IconBorder) then
    local r, g, b = decoration.IconBorder:GetVertexColor()
    border = string.format("%.2f,%.2f,%.2f", r, g, b)
  end
  local button = cell.button
  local padlock = (button ~= nil and shown(button.extendedFrame)) or (decoration ~= nil and shown(decoration.extendedFrame))
  local glyph = decoration ~= nil and shown(decoration.BetterBagsFamilyIcon) and decoration.BetterBagsFamilyIcon:GetAtlas() or "none"
  table.insert(parts, string.format("border=%s padlock=%s mouse=%s glyph=%s", border, tostring(padlock),
    tostring(button ~= nil and button:IsMouseEnabled() == true), tostring(glyph)))
  return table.concat(parts, " ")
end

-- describeSections adds a line for each section (sorted by title) and each of its items.
---@param lines string[]
---@param label string
---@param sections table<any, Section>
---@param origin Frame
-- moving says where a frame Motion is moving started and where it goes, as offsets from the frame
-- it hangs from, or nothing when it is still (render/motion.lua).
---@param frame Frame
---@return string
local function moving(frame)
  local x0, y0, x1, y1 = addon:GetModule('Motion'):GetMove(frame)
  if x0 == nil then
    return ""
  end
  return string.format(" moving from %s,%s to %s,%s", num(x0), num(y0), num(x1), num(y1))
end

local function describeSections(lines, label, sections, origin)
  local sorted = {}
  for _, section in pairs(sections or {}) do
    table.insert(sorted, section)
  end
  table.sort(sorted, function(a, b) return titleOf(a) < titleOf(b) end)
  for _, section in ipairs(sorted) do
    local frame = section.frame
    local cells = section.content and section.content.cells or {}
    table.insert(lines, string.format("%s section %s ipr=%s cells=%d shown=%s %s%s", label, titleOf(section),
      tostring(section.maxItemsPerRow), #cells, tostring(frame:IsShown()), rectIn(frame, origin), moving(frame)))
    for _, cell in ipairs(cells) do
      if cell.isGap then
        table.insert(lines, "  gap")
      elseif cell.frame ~= nil then
        local line = string.format("  item %s %s", tostring(cell.slotkey), rectIn(cell.frame, origin))
        if cell.drawnAs ~= nil then
          line = line .. " " .. buttonState(cell)
        end
        table.insert(lines, line .. moving(cell.frame))
      end
    end
  end
end

-- bounds returns how far the shown frames are from the window's left and right edges, or nil
-- when none is shown.
---@param frames Frame[]
---@param window Frame
---@return number? left, number? right
local function bounds(frames, window)
  local left, right
  for _, f in ipairs(frames) do
    if f:IsShown() and f:GetLeft() ~= nil then
      local l, r = f:GetLeft() - window:GetLeft(), window:GetRight() - f:GetRight()
      left = left == nil and l or math.min(left, l)
      right = right == nil and r or math.min(right, r)
    end
  end
  return left, right
end

-- describeBorder describes the theme's border, and returns how far in from the window's left
-- and right edges its art ends when that can be read: a backdrop's edge size. A template's
-- NineSlice edge pieces are given as where they lie (from the window's edge, inward; negative is
-- outside it): a piece is wider than the art drawn in it (Default's are 75 pixels), so the visible
-- border cannot be read from them. Other art (a texture with its border painted in) neither.
---@param window BetterBagsWindow
---@return string text, number? left, number? right
local function describeBorder(window)
  local frame = window.frame
  local template = window.decoration and window.decoration.template
  local nine = template and template.NineSlice
  if nine ~= nil and nine.LeftEdge ~= nil and nine.RightEdge ~= nil and nine.LeftEdge:GetRight() ~= nil then
    local left, right = frame:GetLeft(), frame:GetRight()
    return string.format("border NineSlice pieces left=%s..%s right=%s..%s",
      num(nine.LeftEdge:GetLeft() - left), num(nine.LeftEdge:GetRight() - left),
      num(right - nine.RightEdge:GetRight()), num(right - nine.RightEdge:GetLeft()))
  end
  local backdrop = frame.GetBackdrop ~= nil and frame:GetBackdrop() or nil
  if backdrop ~= nil and backdrop.edgeFile ~= nil and backdrop.edgeFile ~= "" then
    local edge = backdrop.edgeSize or 0
    return string.format("border backdrop left=%s right=%s", num(edge), num(edge)), edge, edge
  end
  return "border unknown"
end

-- describePadding measures how far the bag's items, and its sections (titles included), are
-- from each side of the window, where the theme's border ends, and so how far the items are
-- from the border: the left and right figures should match (window.md, centering).
---@param window BetterBagsWindow
---@param bag Bag
---@return string
local function describePadding(window, bag)
  local sections, items = {}, {}
  local function collect(list)
    for _, section in pairs(list or {}) do
      table.insert(sections, section.frame)
      for _, cell in ipairs(section.content and section.content.cells or {}) do
        if not cell.isGap and cell.frame ~= nil then
          table.insert(items, cell.frame)
        end
      end
    end
  end
  collect(bag.globalSections)
  collect(bag.currentView and bag.currentView.sections)
  local frame = window.frame
  local itemLeft, itemRight = bounds(items, frame)
  local sectionLeft, sectionRight = bounds(sections, frame)
  local parts = {
    itemLeft and string.format("padding items left=%s right=%s", num(itemLeft), num(itemRight)) or "padding items none",
    sectionLeft and string.format("sections left=%s right=%s", num(sectionLeft), num(sectionRight)) or "sections none",
  }
  local border, borderLeft, borderRight = describeBorder(window)
  table.insert(parts, border)
  if borderLeft ~= nil and itemLeft ~= nil then
    table.insert(parts, string.format("visible left=%s right=%s", num(itemLeft - borderLeft), num(itemRight - borderRight)))
  end
  return table.concat(parts, " | ")
end

-- Snapshot describes what a window shows, one line per part: the window (Geometry), its
-- content box, and for a bag its scroll area, canvas, layout, sections and item buttons.
-- Positions are relative to the window's top left.
---@param window BetterBagsWindow
---@return string[]
function recorder:Snapshot(window)
  local frame = window.frame
  local insets = window:GetContentInsets()
  local lines = {
    string.format("window %s mode=%s sizing=%s | %s", tostring(frame:GetName()), window:GetSizeMode(),
      tostring(window.sizing == true), window:Geometry("record")),
    string.format("content insets %s,%s,%s,%s %s", num(insets.Left), num(insets.Right), num(insets.Top),
      num(insets.Bottom), rectIn(window.content, frame)),
  }
  local bag = bagOf(window)
  if bag == nil then
    return lines
  end
  local scroll = bag.scroll
  if scroll ~= nil then
    table.insert(lines, string.format("scroll %s child %s bar=%s", rectIn(scroll.frame, frame),
      num(scroll.scrollChild:GetHeight()), tostring(scroll.scrollBar:IsShown())))
  end
  local canvas = bag.canvas
  if canvas ~= nil then
    local plan = canvas.plan or {}
    local plannedFor = canvas.plannedFor and string.format("%.6f", canvas.plannedFor) or "content"
    local line = string.format("canvas %s layout ipr=%s columns=%s width=%s for=%s header=%s tab=%s footer=%s",
      rectIn(canvas.frame, frame), tostring(plan.itemsPerRow), tostring(plan.columns), num(plan.width or 0), plannedFor,
      num(canvas.headerContainer:GetHeight()), num(canvas.tabContainer:GetHeight()), num(canvas.footerContainer:GetHeight()))
    for _, part in ipairs({ { "tab", canvas.tabContainer }, { "footer", canvas.footerContainer } }) do
      local move = moving(part[2])
      if move ~= "" then
        line = line .. " | " .. part[1] .. move
      end
    end
    table.insert(lines, line)
  end
  table.insert(lines, describePadding(window, bag))
  describeSections(lines, "global", bag.globalSections, frame)
  if bag.currentView ~= nil then
    describeSections(lines, "view", bag.currentView.sections, frame)
  end
  return lines
end

-- WindowRendered adds a snapshot of the window when what it shows changed since its last.
---@param window BetterBagsWindow
function recorder:WindowRendered(window)
  if not self.recording then
    return
  end
  local lines = self:Snapshot(window)
  local key = table.concat(lines, "\n")
  if self.last[window] == key then
    return
  end
  self.last[window] = key
  self:add({ kind = "render", window = tostring(window.frame:GetName()), lines = lines })
end

-- describeText describes a font string as drawn: its text, its font object, file and size, its
-- width against its string's, its lines, and its parent's width.
---@param text FontString
---@return string
local function describeText(text)
  local path, size, flags = text:GetFont()
  local fontObject = text:GetFontObject()
  local parent = text:GetParent()
  return string.format("%q font=%s %s %s %s | w=%s h=%s string=%s lines=%s truncated=%s wrap=%s | parent w=%s",
    tostring(text:GetText()), fontObject and tostring(fontObject:GetName()) or "nil", tostring(path), num(size),
    tostring(flags), num(text:GetWidth()), num(text:GetHeight()), num(text:GetStringWidth()),
    tostring(text:GetNumLines()), tostring(text:IsTruncated()), tostring(text:CanWordWrap()),
    parent and parent.GetWidth and num(parent:GetWidth()) or "?")
end

-- TextChanged adds a Sonata text whose font changed ("font") or that its watcher refit after it
-- ("refit"), with its role.
---@param text FontString|EditBox
---@param role? string
---@param step string
function recorder:TextChanged(text, role, step)
  if not self.recording or text.GetStringWidth == nil then
    return
  end
  self:add({ kind = "text", step = step, role = tostring(role), line = describeText(text) })
end

-- WindowStep adds a step of a resize or a move, with the window's geometry.
---@param window BetterBagsWindow
---@param step string
function recorder:WindowStep(window, step)
  if not self.recording then
    return
  end
  self:add({ kind = "step", window = tostring(window.frame:GetName()), step = step, geometry = window:Geometry(step) })
end
