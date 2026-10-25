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
  self.lastRegions = setmetatable({}, { __mode = "k" })
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
  self.lastRegions = nil
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

-- inside says whether frame is root or one of its descendants.
---@param frame Frame
---@param root Frame
---@return boolean
local function inside(frame, root)
  local f = frame
  while f ~= nil do
    if f == root then
      return true
    end
    f = f:GetParent()
  end
  return false
end

-- sideOf describes one side of an edge in screen pixels (k pixels per unit of its frame): across its
-- thickness (bottom to top for a top or bottom side, left to right for a left or right one), and
-- whether both ends round to the same pixel, in which case it draws nothing.
---@param name string
---@param texture Texture
---@param k number
---@return string?
local function sideOf(name, texture, k)
  if not texture:IsShown() or texture:GetLeft() == nil then
    return nil
  end
  local a, b
  if name == "Top" or name == "Bottom" then
    a, b = texture:GetBottom() * k, texture:GetTop() * k
  else
    a, b = texture:GetLeft() * k, texture:GetRight() * k
  end
  local collapses = math.floor(a + 0.5) == math.floor(b + 0.5)
  return string.format("%s %.2f-%.2f%s", name:lower(), a, b, collapses and " collapses" or "")
end

-- SettingsSnapshot describes BetterBags Next's settings window as drawn: its scale and the screen,
-- then every control edge shown in it (render-recorder.md §2), top to bottom.
---@param frame Frame
---@return string[]
function recorder:SettingsSnapshot(frame)
  local width, height = GetPhysicalScreenSize()
  local effective = frame:GetEffectiveScale()
  local lines = {
    string.format("settings scale=%.4f effective=%.4f screen=%dx%d pixels per unit=%.4f", frame:GetScale(), effective,
      width, height, effective * height / 768),
  }
  local controls = addon:GetModule('NextControls', true)
  local found = {}
  for edge in pairs(controls and controls.edges or {}) do
    local f = edge.frame
    if f:IsVisible() and inside(f, frame) and f:GetLeft() ~= nil then
      local k = f:GetEffectiveScale() * height / 768
      local parts = {}
      for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        local part = sideOf(side, edge[side], k)
        if part then
          table.insert(parts, part)
        end
      end
      local text = edge.label and edge.label:GetText()
      table.insert(found, {
        top = f:GetTop() or 0, left = f:GetLeft() or 0,
        line = string.format("edge %s%s | %s", text and string.format("%q ", text) or "", rectIn(f, frame),
          table.concat(parts, " ")),
      })
    end
  end
  table.sort(found, function(a, b)
    if a.top ~= b.top then
      return a.top > b.top
    end
    if a.left ~= b.left then
      return a.left < b.left
    end
    return a.line < b.line
  end)
  for _, e in ipairs(found) do
    table.insert(lines, e.line)
  end
  return lines
end

-- SettingsRendered adds a snapshot of the settings window when what it shows changed since its last.
---@param frame Frame
function recorder:SettingsRendered(frame)
  if not self.recording then
    return
  end
  local lines = self:SettingsSnapshot(frame)
  local key = table.concat(lines, "\n")
  if self.last.settings == key then
    return
  end
  self.last.settings = key
  self:add({ kind = "settings", lines = lines })
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

-- pixelRect describes where the client put a region, in screen pixels (k of them per unit at scale 1) with their
-- fractions: its left, top, right and bottom edges.
---@param region? ScriptRegion
---@param k number
---@return string
local function pixelRect(region, k)
  if region == nil then
    return "none"
  end
  local left, bottom, width, height = region:GetScaledRect()
  if left == nil then
    return "unplaced"
  end
  return string.format("l %.3f t %.3f r %.3f b %.3f", left * k, (bottom + height) * k, (left + width) * k, bottom * k)
end

---@param region ScriptRegion
---@return string
local function anchorsOf(region)
  local parts = {}
  for i = 1, region:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
    local name = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
    table.insert(parts, string.format("%s %s %s %.4f,%.4f", point, tostring(name), tostring(relativePoint), x or 0, y or 0))
  end
  return table.concat(parts, "; ")
end

-- SizingSnapshot describes a BetterBags Next panel as the client draws it now: the screen and its scales and the
-- cursor; the panel's anchors and where it is; its scroll box's offset and its scroll target's anchor; then each shown
-- section's first and last icons: the button's frame, its art and its quality border (render-recorder.md §2).
---@param panel table
---@return string[]
function recorder:SizingSnapshot(panel)
  local width, height = GetPhysicalScreenSize()
  local k = height / 768
  local frame = panel.frame
  local x, y = GetCursorPosition()
  local lines = {
    string.format("screen %dx%d uiScale %.4f scale %.4f effective %.4f cursor %.3f,%.3f", width, height,
      UIParent:GetScale(), frame:GetScale(), frame:GetEffectiveScale(), x, y),
    string.format("frame %s | %s", anchorsOf(frame), pixelRect(frame, k)),
  }
  local box = panel.scroll and panel.scroll.scrollBox
  if box ~= nil then
    table.insert(lines, string.format("scroll offset %.3f of %.3f (%.5f) | target %s", box:GetDerivedScrollOffset(),
      box:GetDerivedScrollRange(), box:GetScrollPercentage(), anchorsOf(box:GetScrollTarget())))
  end
  for _, section in ipairs(panel.content and panel.content.order or {}) do
    if section.frame:IsShown() then
      local first, last
      for _, entry in ipairs(section.entries) do
        if entry.item ~= nil then
          first = first or entry.item
          last = entry.item
        end
      end
      for _, item in ipairs({ first, last ~= first and last or nil }) do
        local decoration = rawget(item, "_decoration")
        local art = decoration and decoration.icon or item.icon
        local border = decoration and decoration.IconBorder or item.IconBorder
        table.insert(lines, string.format("%s %s frame %s | art %s | border %s", tostring(section.name),
          tostring(item.slotkey), pixelRect(item.frame, k), pixelRect(art, k), pixelRect(border, k)))
      end
    end
  end
  return lines
end

-- sizingRegions is what changed in a panel since the last step recorded of it (PixelAudit:Regions, every region that
-- draws in it but its moving parts): "+ path | what" for a region drawn now and not then, "- path" for one no longer
-- drawn, "~ path | what" for one drawn differently, sorted; nil for nothing. The first step of a panel in a recording
-- lists every region ("= path | what").
---@param panel table
---@return string[]?
function recorder:sizingRegions(panel)
  local now = addon:GetModule('PixelAudit'):Regions(panel.frame, { skip = panel.MovingParts and panel:MovingParts() })
  local before = self.lastRegions[panel]
  self.lastRegions[panel] = now
  local lines = {}
  for path, what in pairs(now) do
    if before == nil then
      table.insert(lines, "= " .. path .. " | " .. what)
    elseif before[path] == nil then
      table.insert(lines, "+ " .. path .. " | " .. what)
    elseif before[path] ~= what then
      table.insert(lines, "~ " .. path .. " | " .. what)
    end
  end
  for path in pairs(before or {}) do
    if now[path] == nil then
      table.insert(lines, "- " .. path)
    end
  end
  table.sort(lines)
  return #lines > 0 and lines or nil
end

-- PanelSizing adds a step of a BetterBags Next panel being sized by a grip or gliding to a size, with where the client
-- put it and a few of its icons (SizingSnapshot), and what changed on screen in it (sizingRegions). Added for icons that
-- jittered "ever so slight" in game while the specs' model kept every one on the same whole pixels; the regions for a
-- change reported at an icon's bottom edge while every icon recorded stayed on the same whole pixels.
---@param panel table
---@param step string
function recorder:PanelSizing(panel, step)
  if not self.recording then
    return
  end
  self:add({ kind = "sizing", panel = tostring(panel.label or panel.frame:GetName()), step = step,
    lines = self:SizingSnapshot(panel), regions = self:sizingRegions(panel) })
end
