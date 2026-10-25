local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextSettingsPage is a page of BetterBags Next's settings window (next-settings.md §3): a drawable
-- laying its sections out at the width it is given (render-pipeline.md), inside the window's scroll
-- box. A section is its title in capitals (and a note after it), then a card of its rows: two columns
-- when the page is at least twice MinColumn wide, a pair of rows as tall as the taller, a wide row
-- across both on a line of its own; lines between the card's lines and between its columns. A row with
-- a hidden function (row.hidden) is left out while it says so, checked at every layout (the window lays
-- itself out again after every change), and a section with no row shown is left out; a section's title
-- can be left out alone (section.titleHidden).
---@class NextSettingsPage: AceModule
---@field all NextSettingsPageFrame[]
local nextPage = addon:NewModule('NextSettingsPage')

-- A section as a page shows it.
---@class (exact) NextSettingsSection
---@field title string
---@field note? string
---@field titleHidden? fun(): boolean Its title left out while it says so.
---@field rows NextSettingsRow[]

---@class NextSettingsPageFrame: Drawable
---@field frame Frame
---@field sections NextSettingsSection[]
---@field titles FontString[] One per section shown, made as needed.
---@field notes FontString[]
---@field cards Texture[]
---@field lines Texture[] The lines between rows and columns, made as needed.
---@field empty FontString Shown when it has no sections.
---@field emptyText string
---@field shownRows table<NextSettingsRow, boolean> The rows of the last layout.
local pageProto = drawable:Extend({}, 'NextSettingsPageFrame')

nextPage.all = {}

---@param ctx? Context
function nextPage:ApplyStyle(ctx)
  local _ = ctx
  for _, page in ipairs(self.all) do
    page:Style()
    render:Invalidate(page)
  end
end

---@param parent Frame
---@return NextSettingsPageFrame
function nextPage:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextSettingsPageFrame
  local page = drawable:Create(pageProto, {
    frame = frame, sections = {}, titles = {}, notes = {}, cards = {}, lines = {}, shownRows = {}, emptyText = "",
  })
  page.empty = style:CreateText(frame, style.Theme.Settings.Content.TextFont)
  page.empty:Hide()
  table.insert(self.all, page)
  sonataNext:RegisterWidget(self)
  return page
end

---@return RenderPlan
function pageProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

-- SetSections shows these sections (laid out on the next render).
---@param sections NextSettingsSection[]
function pageProto:SetSections(sections)
  self.sections = sections
  render:Invalidate(self)
end

-- SetEmptyText says what the page shows with no sections.
---@param text string
function pageProto:SetEmptyText(text)
  self.emptyText = text
  self.empty:SetText(text)
end

-- Leave tells the rows the page is left (another page, the window closing; a row that cares has
-- OnPageLeft): a theme preview ends.
---@param ctx Context
function pageProto:Leave(ctx)
  for _, section in ipairs(self.sections) do
    for _, row in ipairs(section.rows) do
      if row.OnPageLeft ~= nil then
        row:OnPageLeft(ctx)
      end
    end
  end
end

-- Refresh shows every row's value again.
---@param ctx? Context
function pageProto:Refresh(ctx)
  for _, section in ipairs(self.sections) do
    for _, row in ipairs(section.rows) do
      row:Refresh(ctx)
    end
  end
end

-- Style redraws the page's own parts from the theme: fonts, cards and lines.
function pageProto:Style()
  local C = style.Theme.Settings.Content
  for _, t in ipairs(self.titles) do style:SetFont(t, C.TitleFont) end
  for _, n in ipairs(self.notes) do style:SetFont(n, C.NoteFont) end
  for _, card in ipairs(self.cards) do controls:Paint(card, C.Card) end
  for _, line in ipairs(self.lines) do controls:Paint(line, C.Divider and { Color = C.Divider.Color } or false, C.Divider and C.Divider.Alpha) end
  style:SetFont(self.empty, C.TextFont)
end

-- part returns the i-th of a kind of the page's parts, made the first time it is needed.
---@private
---@param list table
---@param i number
---@param make fun(): Region
---@return Region
function pageProto:part(list, i, make)
  local p = list[i]
  if p == nil then
    p = make()
    list[i] = p
  end
  return p
end

-- line draws the next line between rows or columns.
---@private
---@param n number How many lines are drawn so far.
---@param x number
---@param y number
---@param width number
---@param height number
---@return number n
function pageProto:line(n, x, y, width, height)
  local C = style.Theme.Settings.Content
  n = n + 1
  local line = self:part(self.lines, n, function()
    return self.frame:CreateTexture(nil, "BORDER")
  end)
  -- A theme may draw no lines between rows (Divider = false).
  controls:Paint(line, C.Divider and { Color = C.Divider.Color } or false, C.Divider and C.Divider.Alpha)
  line:ClearAllPoints()
  pixel:Point(line, "TOPLEFT", self.frame, "TOPLEFT", x, -y)
  pixel:Size(line, width, height)
  line:SetShown(C.Divider ~= nil and C.Divider ~= false)
  return n
end

-- visibleRows returns a section's rows shown now, marking in hidden each one its hidden function hides.
---@param section NextSettingsSection
---@param hidden table<NextSettingsRow, boolean>
---@return NextSettingsRow[]
local function visibleRows(section, hidden)
  local visible = {}
  for _, row in ipairs(section.rows) do
    if row.hidden ~= nil and row.hidden() == true then
      hidden[row] = true
    else
      table.insert(visible, row)
    end
  end
  return visible
end

---@param parentResult? RenderResult
---@return RenderResult
-- It lays everything out in whole pixels (docs/next-pixel-perfect.md): its width rounded down, every
-- length rounded, each row's height its measure rounded up, a section's note beside its title's width
-- rounded up; so every row and line starts on a whole pixel.
function pageProto:Render(parentResult)
  local C = style.Theme.Settings.Content
  local f = self.frame
  local pad, minColumn = pixel:Snap(f, C.Pad), pixel:Length(f, C.MinColumn)
  local width = pixel:Floor(f, parentResult and parentResult.Width or 2 * (minColumn + pad))
  local inner = width - 2 * pad
  local columns = inner >= 2 * minColumn and 2 or 1
  local column = columns == 2 and pixel:Floor(f, inner / 2) or inner
  local divider = pixel:Length(f, C.Divider and C.Divider.Size or 1)
  local sectionGap, titleHeight = pixel:Snap(f, C.SectionGap), pixel:Snap(f, C.TitleHeight)
  local placed = {}
  local hidden = {}
  local lines = 0
  local y = pixel:Snap(f, C.Top)
  local shown = 0
  for _, section in ipairs(self.sections) do
    local visible = visibleRows(section, hidden)
    if #visible > 0 then
      shown = shown + 1
      local i = shown
      if i > 1 then
        y = y + sectionGap
      end
      local titled = section.titleHidden == nil or section.titleHidden() ~= true
      local title = self:part(self.titles, i, function() return style:CreateText(f, C.TitleFont) end)
      title:SetText(string.upper(section.title or ""))
      title:ClearAllPoints()
      local bottom = y + titleHeight - pixel:Snap(f, 6)
      title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", pad, -bottom)
      title:SetShown(titled)
      local note = self:part(self.notes, i, function() return style:CreateText(f, C.NoteFont) end)
      note:SetText(section.note or "")
      note:ClearAllPoints()
      -- Beside the title, centered on its line by its top (never by the title's middle or far edge).
      local titleFont = pixel:Ceil(f, pixel:TextHeight(title))
      local noteTop = bottom - titleFont + pixel:Middle(f, titleFont, pixel:TextHeight(note))
      note:SetPoint("TOPLEFT", f, "TOPLEFT", pad + pixel:Ceil(f, title:GetStringWidth()) + pixel:Snap(f, 6), -noteTop)
      note:SetShown(titled and section.note ~= nil and section.note ~= "")
      if titled then
        y = y + titleHeight
      end
      local top = y
      local pending = {}
      local first = true
      -- flush lays the pending pair (or single row) out on a line of its own.
      local function flush()
        if #pending == 0 then
          return
        end
        if not first then
          lines = self:line(lines, pad, y, inner, divider)
        end
        first = false
        local height = 0
        for k = 1, #pending do
          height = math.max(height, pixel:Ceil(f, pending[k]:Measure(k == 1 and column or inner - column)))
        end
        for k, row in ipairs(pending) do
          row:Place(pad + (k - 1) * column, y, k == 1 and column or inner - column, height)
          placed[row] = true
        end
        if #pending == 2 then
          lines = self:line(lines, pad + column, y, divider, height)
        end
        y = y + height
        pending = {}
      end
      for _, row in ipairs(visible) do
        if row.wide then
          flush()
          if not first then
            lines = self:line(lines, pad, y, inner, divider)
          end
          first = false
          local height = pixel:Ceil(f, row:Measure(inner))
          row:Place(pad, y, inner, height)
          placed[row] = true
          y = y + height
        else
          table.insert(pending, row)
          if #pending == columns then
            flush()
          end
        end
      end
      flush()
      local card = self:part(self.cards, i, function() return self.frame:CreateTexture(nil, "BACKGROUND") end)
      controls:Paint(card, C.Card)
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -top)
      card:SetSize(inner, math.max(pixel:Unit(f), y - top))
      card:SetShown(y > top)
    end
  end
  for i = shown + 1, #self.titles do
    self.titles[i]:Hide()
    self.notes[i]:Hide()
    self.cards[i]:Hide()
  end
  for i = lines + 1, #self.lines do
    self.lines[i]:Hide()
  end
  -- A row not placed is hidden: those of the last layout, and those hidden from the start.
  for row in pairs(self.shownRows) do
    if not placed[row] then
      row.frame:Hide()
    end
  end
  for row in pairs(hidden) do
    row.frame:Hide()
  end
  self.shownRows = placed
  local empty = shown == 0
  self.empty:SetShown(empty)
  if empty then
    -- Across the page, centered by the client: by its middle it would sit between two pixels.
    local top = pixel:Snap(f, C.Top) + titleHeight
    self.empty:ClearAllPoints()
    self.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    self.empty:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
    self.empty:SetJustifyH("CENTER")
    y = top + pixel:Ceil(f, self.empty:GetStringHeight())
  end
  local height = y + pixel:Snap(f, C.Bottom)
  f:SetSize(width, height)
  return { Width = width, Height = height }
end
