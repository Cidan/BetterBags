local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextRain draws a Next theme's data rain on a panel (Panel.Rain, next-themes.md §21; the Glitch theme): columns of
-- glyphs falling a cell at a time, as a terminal's screen rains in the films. Each column's head writes a new glyph in
-- every cell it reaches, in its own bright font, and the glyphs it wrote stay where they were written, fading behind it
-- in the column's font; now and then one changes. A theme's entry falls down the feather beside the body's inner side
-- (a full panel's) or across the body, behind the content: the glyphs are the panel frame's own font strings, in its
-- BORDER layer, over its fill and feather and under every child frame (tabs, content). A column is a ring of font
-- strings as long as its longest trail, so a column costs its trail, whatever the panel's height; each row the head
-- passes moves one of them. It falls only while the panel shows (its driver is a child of the panel's frame); in combat
-- no column starts again, so the rain thins out and stops, as sparkles do.
---@class NextRain: AceModule
local rain = addon:NewModule('NextRain')

-- Where the rain takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
rain.Random = math.random

-- The keys of a Panel.Rain entry, and the places it falls, for SonataNext:Check.
rain.KEYS = { Where = true, Font = true, HeadFont = true, Glyphs = true, Spacing = true, Speed = true, Trail = true,
  Alpha = true, Swap = true }
rain.WHERE = { Feather = true, Body = true }

---@class (exact) NextRainColumn
---@field rain table The theme's entry it falls for.
---@field glyphs FontString[] Its ring: the head first, then its trail, a row above each other.
---@field x? number Its cells' left edge, from the panel's top left (nil until placed).
---@field cell number A cell's size, in units: its font's height, on whole pixels of the panel's grid.
---@field rows number The rows the panel's frame holds.
---@field head number Where its head is, in rows from the top (fractional; negative above the top).
---@field row number The row its head last wrote in.
---@field speed number Rows a second.
---@field trail number How many glyphs follow its head.
---@field swap number Glyph changes owed.

---@class (exact) NextRainSet
---@field panel table The panel: its frame, its side, IsSmall, BodyLeft, BodyWidth.
---@field driver Frame Runs the rain while it falls; a child of the panel's frame.
---@field onUpdate fun(frame: Frame, elapsed: number) The driver's script, made once.
---@field entries table[] The theme's entries.
---@field columns NextRainColumn[]
---@field glyphs table<table, string[]> Each entry's glyphs, read as characters.
---@field pool FontString[] Font strings no column holds.
---@field running boolean Falling (the panel shows).
local setProto = {}
addon:GetModule('Perf'):RegisterPrototype(setProto, 'NextRainSet')

-- Create gives a panel its rain, none until styled (Style). The panel's frame changing size (a small panel sized by a
-- grip, a size switch) lays it out again.
---@param panel table
---@return NextRainSet
function rain:Create(panel)
  local set = setmetatable({ panel = panel, entries = {}, columns = {}, glyphs = {}, pool = {}, running = false },
    { __index = setProto })
  set.driver = CreateFrame("Frame", nil, panel.frame)
  set.onUpdate = function(_, elapsed)
    set:Step(elapsed)
  end
  -- A plain hook: it runs on every frame of a resize, and addon.HookScript makes a Context per call.
  panel.frame:HookScript("OnSizeChanged", function()
    if #set.entries > 0 then
      set:Layout()
    end
  end)
  return set
end

-- characters reads a string as its characters (UTF-8), so a theme's glyphs may be any the font has.
---@param text string
---@return string[]
local function characters(text)
  local out = {}
  for c in string.gmatch(text or "", "[%z\1-\127\194-\244][\128-\191]*") do
    table.insert(out, c)
  end
  return out
end

---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * rain.Random()
end

-- Style takes the theme's rain: its entries, their glyphs, and its columns laid out again (Layout). Falling while the
-- panel showed, it falls on (Start), every column from above.
function setProto:Style()
  local running = self.running
  self:Stop()
  local list = style.Theme.Panel.Rain or {}
  self.entries = list
  self.glyphs = {}
  for _, entry in ipairs(list) do
    self.glyphs[entry] = characters(entry.Glyphs)
  end
  for _, column in ipairs(self.columns) do
    self:release(column)
  end
  self.columns = {}
  self:Layout()
  if running then
    self:Start()
  end
end

-- release gives a column's font strings back to the pool, hidden.
---@private
---@param column NextRainColumn
function setProto:release(column)
  for _, g in ipairs(column.glyphs) do
    g:Hide()
    table.insert(self.pool, g)
  end
  column.glyphs = {}
end

-- strip returns where an entry falls, from the panel's top left: the left edge and the width. The feather is beside the
-- body's inner side (left of a panel that belongs to the right, right of one that belongs to the left), as wide as the
-- theme's feather; a small panel has none.
---@private
---@param entry table
---@return number? left, number width
function setProto:strip(entry)
  local panel = self.panel
  if entry.Where == "Body" then
    return panel:BodyLeft(), panel:BodyWidth()
  end
  if panel:IsSmall() then
    return nil, 0
  end
  if panel.side == "LEFT" then
    return panel:BodyLeft() + panel:BodyWidth(), style.FEATHER
  end
  return panel:BodyLeft() - style.FEATHER, style.FEATHER
end

-- Layout lays the columns out for the panel's size and side: each entry's columns Spacing apart across its strip,
-- centered in it, each cell its font's height square. A column already falling keeps falling (its glyphs placed again
-- in their rows); columns no longer needed give their glyphs back, new ones start from above.
function setProto:Layout()
  local frame = self.panel.frame
  local columns, n = self.columns, 0
  for _, entry in ipairs(self.entries) do
    local _, height = style:Font(entry.Font):GetFont()
    local cell = pixel:Length(frame, height)
    local rows = math.max(1, math.floor(frame:GetHeight() / cell))
    local left, width = self:strip(entry)
    local spacing = entry.Spacing or cell
    local count = left ~= nil and math.floor(width / spacing) or 0
    local x0 = (left or 0) + (width - count * spacing) / 2 + (spacing - cell) / 2
    for i = 1, count do
      n = n + 1
      local column = columns[n]
      if column == nil or column.rain ~= entry then
        if column ~= nil then
          self:release(column)
        end
        column = { rain = entry, glyphs = {}, cell = 0, rows = rows, head = 0, row = 0, speed = 0, trail = 0, swap = 0 }
        columns[n] = column
        self:fill(column)
        self:drop(column)
      end
      -- Only what changed: a resize lays the rain out on each of its frames.
      local x = x0 + (i - 1) * spacing
      -- A new cell moves its cells' left edge too (x), so its glyphs are placed again below.
      if cell ~= column.cell then
        column.cell = cell
        for _, g in ipairs(column.glyphs) do
          g:SetSize(cell, cell)
        end
      end
      if x ~= column.x then
        column.x = x
        self:placeAll(column)
      end
      if rows ~= column.rows then
        column.rows = rows
        self:draw(column)
      end
    end
  end
  for i = #columns, n + 1, -1 do
    self:release(columns[i])
    columns[i] = nil
  end
  if self.running then
    self:drive()
  end
end

-- fill gives a column the font strings its longest trail needs, and its head, from the pool or made on the panel's
-- frame.
---@private
---@param column NextRainColumn
function setProto:fill(column)
  local entry = column.rain
  local frame = self.panel.frame
  for i = 1, math.floor(entry.Trail[2] + 0.5) + 1 do
    local g = table.remove(self.pool)
    if g == nil then
      g = style:CreateText(frame, entry.Font, "BORDER")
      -- Over the wash (BORDER 0) and a small panel's edge (BORDER 1).
      g:SetDrawLayer("BORDER", 2)
      g:SetJustifyH("CENTER")
      g:SetJustifyV("MIDDLE")
      g:SetWordWrap(false)
    end
    g:Hide()
    -- Its head takes the head's font as it writes (advance).
    style:SetFont(g, entry.Font)
    column.glyphs[i] = g
  end
end

-- drop starts a column again from above the top: a new speed and trail, up to half the panel's height above it.
---@private
---@param column NextRainColumn
function setProto:drop(column)
  local entry = column.rain
  column.head = -column.rows * rain.Random() * 0.5
  column.row = math.floor(column.head)
  column.speed = between(entry.Speed)
  column.trail = math.min(#column.glyphs - 1, math.floor(between(entry.Trail) + 0.5))
  column.swap = 0
end

-- glyph returns one of an entry's glyphs, at random.
---@private
---@param entry table
---@return string
function setProto:glyph(entry)
  local list = self.glyphs[entry]
  return list[math.min(#list, math.floor(rain.Random() * #list) + 1)] or ""
end

-- place anchors one of a column's glyphs in its row, on whole pixels of the frame's grid (a quarter pixel right and up:
-- text, next-pixel-perfect.md §2).
---@private
---@param column NextRainColumn
---@param g FontString
---@param row number
function setProto:place(column, g, row)
  g:ClearAllPoints()
  pixel:Point(g, "TOPLEFT", self.panel.frame, "TOPLEFT", column.x, -row * column.cell)
end

---@private
---@param column NextRainColumn
function setProto:placeAll(column)
  for i, g in ipairs(column.glyphs) do
    self:place(column, g, column.row - (i - 1))
  end
end

-- draw shows a column as it is: its head and its trail in the rows the panel holds, fading down the trail from the
-- entry's Alpha; the rest hidden. Its font first, then its alpha (a font object brings its color's).
---@private
---@param column NextRainColumn
function setProto:draw(column)
  local alpha = column.rain.Alpha or 1
  for i, g in ipairs(column.glyphs) do
    local row = column.row - (i - 1)
    if i <= column.trail + 1 and row >= 0 and row < column.rows and self.running then
      g:SetAlpha(alpha * (1 - (i - 1) / (column.trail + 1)))
      g:Show()
    else
      g:Hide()
    end
  end
end

-- advance moves a column's head down a row: the glyph at the end of its trail becomes its head in the new row, with a
-- new glyph, and the old head joins the trail.
---@private
---@param column NextRainColumn
function setProto:advance(column)
  local entry, glyphs = column.rain, column.glyphs
  column.row = column.row + 1
  local g = table.remove(glyphs)
  table.insert(glyphs, 1, g)
  style:SetFont(g, entry.HeadFont)
  g:SetText(self:glyph(entry))
  self:place(column, g, column.row)
  if glyphs[2] ~= nil then
    style:SetFont(glyphs[2], entry.Font)
  end
end

-- Step lets every column fall elapsed seconds: its head writes in each row it reaches (all of them, however long the
-- frame), Swap of its glyphs a second change, and once its trail has fallen past the bottom it starts again from
-- above, unless in combat.
---@param elapsed number
function setProto:Step(elapsed)
  local combat = InCombatLockdown()
  for _, column in ipairs(self.columns) do
    -- Its glyphs are drawn again only when it passed a row or started again: nothing else changes what shows.
    local moved = false
    if column.row - column.trail < column.rows then
      column.head = column.head + column.speed * elapsed
      local target = math.floor(column.head)
      -- More rows than the ring holds are written over anyway: only the last of them.
      if target - column.row > #column.glyphs then
        column.row = target - #column.glyphs
      end
      while column.row < target do
        self:advance(column)
        moved = true
      end
      self:swap(column, elapsed)
    end
    -- Its trail is past the bottom, nothing of it shows: it starts again above the top, out of sight.
    if column.row - column.trail >= column.rows and not combat then
      self:drop(column)
    end
    if moved then
      self:draw(column)
    end
  end
end

-- swap changes Swap of a column's shown glyphs a second, at random.
---@private
---@param column NextRainColumn
---@param elapsed number
function setProto:swap(column, elapsed)
  local rate = column.rain.Swap or 0
  if rate <= 0 then
    return
  end
  column.swap = column.swap + rate * elapsed
  local count = math.min(column.trail + 1, #column.glyphs)
  while column.swap >= 1 do
    column.swap = column.swap - 1
    local g = column.glyphs[math.min(count, math.floor(rain.Random() * count) + 1)]
    g:SetText(self:glyph(column.rain))
  end
end

-- drive runs the driver while there are columns, and stops it when none.
---@private
function setProto:drive()
  if #self.columns == 0 then
    self.driver:SetScript("OnUpdate", nil)
    return
  end
  self.driver:SetScript("OnUpdate", self.onUpdate)
end

-- Start lets the rain fall (the panel shows), every column from above.
function setProto:Start()
  self.running = true
  for _, column in ipairs(self.columns) do
    self:drop(column)
    self:placeAll(column)
    self:draw(column)
  end
  self:drive()
end

-- Stop ends the rain (the panel hid): every glyph hidden.
function setProto:Stop()
  self.running = false
  self.driver:SetScript("OnUpdate", nil)
  for _, column in ipairs(self.columns) do
    self:draw(column)
  end
end

-- MovingParts adds every glyph to skip: they rest nowhere, so the pixel checks leave them out.
---@param skip table<table, boolean>
function setProto:MovingParts(skip)
  for _, column in ipairs(self.columns) do
    for _, g in ipairs(column.glyphs) do
      skip[g] = true
    end
  end
end
