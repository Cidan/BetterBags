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

-- NextSettingsPage is a page of BetterBags Next's settings window (next-settings.md §3): a drawable
-- laying its sections out at the width it is given (render-pipeline.md), inside the window's scroll
-- box. A section is its title in capitals (and a note after it), then a card of its rows: two columns
-- when the page is at least twice MinColumn wide, a pair of rows as tall as the taller, a wide row
-- across both on a line of its own; lines between the card's lines and between its columns.
---@class NextSettingsPage: AceModule
---@field all NextSettingsPageFrame[]
local nextPage = addon:NewModule('NextSettingsPage')

-- A section as a page shows it.
---@class (exact) NextSettingsSection
---@field title string
---@field note? string
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
  for _, line in ipairs(self.lines) do controls:Paint(line, { Color = C.Divider.Color }, C.Divider.Alpha) end
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
  controls:Paint(line, { Color = C.Divider.Color }, C.Divider.Alpha)
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -y)
  line:SetSize(width, height)
  line:Show()
  return n
end

---@param parentResult? RenderResult
---@return RenderResult
function pageProto:Render(parentResult)
  local C = style.Theme.Settings.Content
  local width = parentResult and parentResult.Width or 2 * (C.MinColumn + C.Pad)
  local inner = width - 2 * C.Pad
  local columns = inner >= 2 * C.MinColumn and 2 or 1
  local column = columns == 2 and inner / 2 or inner
  local divider = C.Divider.Size or 1
  local placed = {}
  local lines = 0
  local y = C.Top
  for i, section in ipairs(self.sections) do
    if i > 1 then
      y = y + C.SectionGap
    end
    local title = self:part(self.titles, i, function() return style:CreateText(self.frame, C.TitleFont) end)
    title:SetText(string.upper(section.title or ""))
    title:ClearAllPoints()
    title:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", C.Pad, -(y + C.TitleHeight - 6))
    title:Show()
    local note = self:part(self.notes, i, function() return style:CreateText(self.frame, C.NoteFont) end)
    note:SetText(section.note or "")
    note:ClearAllPoints()
    note:SetPoint("LEFT", title, "RIGHT", 6, 0)
    note:SetShown(section.note ~= nil and section.note ~= "")
    y = y + C.TitleHeight
    local top = y
    local pending = {}
    local first = true
    -- flush lays the pending pair (or single row) out on a line of its own.
    local function flush()
      if #pending == 0 then
        return
      end
      if not first then
        lines = self:line(lines, C.Pad, y, inner, divider)
      end
      first = false
      local height = 0
      for _, row in ipairs(pending) do
        height = math.max(height, row:Measure(column))
      end
      for k, row in ipairs(pending) do
        row:Place(C.Pad + (k - 1) * column, y, column, height)
        placed[row] = true
      end
      if #pending == 2 then
        lines = self:line(lines, C.Pad + column, y, divider, height)
      end
      y = y + height
      pending = {}
    end
    for _, row in ipairs(section.rows) do
      if row.wide then
        flush()
        if not first then
          lines = self:line(lines, C.Pad, y, inner, divider)
        end
        first = false
        local height = row:Measure(inner)
        row:Place(C.Pad, y, inner, height)
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
    card:SetPoint("TOPLEFT", self.frame, "TOPLEFT", C.Pad, -top)
    card:SetSize(inner, math.max(1, y - top))
    card:SetShown(y > top)
  end
  for i = #self.sections + 1, #self.titles do
    self.titles[i]:Hide()
    self.notes[i]:Hide()
    self.cards[i]:Hide()
  end
  for i = lines + 1, #self.lines do
    self.lines[i]:Hide()
  end
  for row in pairs(self.shownRows) do
    if not placed[row] then
      row.frame:Hide()
    end
  end
  self.shownRows = placed
  local empty = #self.sections == 0
  self.empty:SetShown(empty)
  if empty then
    self.empty:ClearAllPoints()
    self.empty:SetPoint("TOP", self.frame, "TOP", 0, -(C.Top + C.TitleHeight))
    y = C.Top + C.TitleHeight + math.ceil(self.empty:GetStringHeight())
  end
  local height = y + C.Bottom
  self.frame:SetSize(width, height)
  return { Width = width, Height = height }
end
