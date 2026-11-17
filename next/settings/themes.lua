local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextSettingsCards: AceModule
local cards = addon:GetModule('NextSettingsCards')

-- NextSettingsThemes is the Appearance page's theme picker (next-settings.md §4), a wide row: a card
-- per theme an engine lists (SonataNext, BetterBags Next's themes; or Sonata, the bags' themes, which
-- draw Next's item buttons and dialogs unless the Next theme styles them), sorted by name, each with its
-- description and whether it is active, previewed or cannot be used (its addon is not loaded). A pick
-- is previewed (applied unsaved) on the next frame: applying restyles this window, which must not
-- happen inside the click (the classic theme pane's lesson, sonata.md §2); the last pick before then
-- wins. Apply Theme saves it. Leaving the page puts the saved theme back.
---@class NextSettingsThemes: AceModule
---@field all NextSettingsThemesBlock[]
local themes = addon:NewModule('NextSettingsThemes')

-- The engines answer these (sonata/engine.lua, sonata/next.lua).
---@class (exact) NextThemeEngine
---@field GetThemes fun(self): table<string, table>
---@field IsAvailable fun(self, key: string): boolean
---@field IsSelectable fun(self, key: string): boolean
---@field GetCurrentThemeKey fun(self): string?
---@field GetSavedThemeKey fun(self): string
---@field ApplyTheme fun(self, ctx: Context, key: string, save?: boolean)
---@field RestoreSavedTheme fun(self, ctx: Context)

---@class NextSettingsThemeCard: NextSettingsCard
---@field key? string

---@class NextSettingsThemesBlock
---@field frame Frame
---@field wide boolean
---@field engine NextThemeEngine
---@field cards NextSettingsThemeCard[]
---@field entries table[]
---@field apply NextButtonFrame
---@field picked? string
---@field pending? string
---@field queued boolean
local blockProto = {}
addon:GetModule('Perf'):RegisterPrototype(blockProto, 'NextSettingsThemesBlock')

themes.all = {}

---@param ctx? Context
function themes:ApplyStyle(ctx)
  local _ = ctx
  for _, block in ipairs(self.all) do
    block:Paint()
  end
end

---@param parent Frame
---@param engine NextThemeEngine
---@return NextSettingsThemesBlock
function themes:Create(parent, engine)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextSettingsThemesBlock
  local block = setmetatable({
    frame = frame, wide = true, engine = engine, cards = {}, entries = {}, queued = false,
  }, { __index = blockProto })
  block.apply = nextButton:Create(frame, {
    text = L:G("Apply Theme"), style = "Primary",
    onClick = function(ctx) block:Apply(ctx) end,
  })
  table.insert(self.all, block)
  sonataNext:RegisterWidget(self)
  return block
end

-- card returns the i-th card, made the first time it is needed.
---@private
---@param i number
---@return NextSettingsThemeCard
function blockProto:card(i)
  local card = self.cards[i]
  if card ~= nil then
    return card
  end
  card = cards:Create(self.frame) --[[@as NextSettingsThemeCard]]
  local frame = card.frame
  addon.SetScript(frame, "OnClick", function() self:Pick(card.key) end)
  addon.SetScript(frame, "OnEnter", function() card.hovered = true self:Paint() end)
  addon.SetScript(frame, "OnLeave", function() card.hovered = false self:Paint() end)
  self.cards[i] = card
  return card
end

-- entriesOf lists the themes an engine knows (not hidden), those whose addon is not loaded too,
-- sorted by name.
---@param engine NextThemeEngine
---@return {key: string, name: string, description: string, available: boolean}[]
local function entriesOf(engine)
  local list = {}
  for key, theme in pairs(engine:GetThemes()) do
    table.insert(list, {
      key = key,
      name = theme.DisplayName or theme.Name or key,
      description = theme.Description or "",
      available = engine:IsAvailable(key),
    })
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

-- Refresh lists the themes again.
---@param ctx? Context
function blockProto:Refresh(ctx)
  local _ = ctx
  self.entries = entriesOf(self.engine)
  for i, entry in ipairs(self.entries) do
    local card = self:card(i)
    card.key = entry.key
    card.name:SetText(entry.name)
    card.text:SetText(entry.description)
    card.frame:Show()
  end
  for i = #self.entries + 1, #self.cards do
    self.cards[i].key = nil
    self.cards[i].frame:Hide()
  end
  self:Paint()
end

-- Paint draws every card as it is: the chosen one (picked, else the saved theme) edged, the one under
-- the pointer lit, each with its status; and whether Apply Theme has a theme to save.
function blockProto:Paint()
  local K = style.Theme.Settings.Cards
  local engine = self.engine
  local saved = engine:GetSavedThemeKey()
  local chosen = self.picked or saved
  for i = 1, #self.entries do
    local card, entry = self.cards[i], self.entries[i]
    cards:Paint(card, entry.key == chosen)
    local status, font = "", K.TextFont
    if not entry.available then
      status, font = L:G("Unavailable"), K.UnavailableFont
    elseif entry.key == saved then
      status, font = L:G("Active"), K.ActiveFont
    elseif entry.key == self.picked then
      status, font = L:G("Previewing"), K.PreviewFont
    end
    style:SetFont(card.status, font)
    card.status:SetText(status)
  end
  local picked = self.picked
  self.apply:SetEnabled(picked ~= nil and picked ~= saved and engine:IsSelectable(picked))
end

-- Pick chooses a theme, previewed on the next frame.
---@param key? string
function blockProto:Pick(key)
  if key == nil then
    return
  end
  self.picked = key
  self.pending = key
  self:Paint()
  if self.queued then
    return
  end
  self.queued = true
  C_Timer.After(0, function()
    self.queued = false
    local pending = self.pending
    self.pending = nil
    if pending ~= nil then
      self:Preview(context:New('NextSettingsThemes_Preview'), pending)
    end
  end)
end

-- Preview applies a picked theme unsaved; a theme that cannot be used shows the saved one.
---@param ctx Context
---@param key string
function blockProto:Preview(ctx, key)
  local engine = self.engine
  if engine:IsSelectable(key) then
    if engine:GetCurrentThemeKey() ~= key then
      engine:ApplyTheme(ctx, key, false)
    end
  else
    engine:RestoreSavedTheme(ctx)
  end
  self:Paint()
end

-- Apply saves the theme previewed.
---@param ctx Context
function blockProto:Apply(ctx)
  local picked = self.picked
  if picked == nil or not self.engine:IsSelectable(picked) then
    return
  end
  self.engine:ApplyTheme(ctx, picked, true)
  self.picked = nil
  self:Paint()
end

-- OnPageLeft puts the saved theme back and forgets the pick (another page, the window closing).
---@param ctx Context
function blockProto:OnPageLeft(ctx)
  self.pending = nil
  self.picked = nil
  self.engine:RestoreSavedTheme(ctx)
  self:Paint()
end

-- metrics are the cards' lengths in whole pixels (docs/next-pixel-perfect.md): the padding round them and
-- its half above and below, their height, the gap between them, their own padding.
---@private
---@return {pad: number, half: number, height: number, gap: number, cardPad: number, minWidth: number}
function blockProto:metrics()
  local K, frame = style.Theme.Settings.Cards, self.frame
  local pad = pixel:Snap(frame, style.Theme.Settings.Content.RowPad)
  return { pad = pad, half = pixel:Floor(frame, pad / 2), height = pixel:Length(frame, K.Height),
    gap = pixel:Snap(frame, K.Gap), cardPad = pixel:Snap(frame, K.Pad), minWidth = pixel:Length(frame, K.MinWidth) }
end

-- layout returns the cards' columns and width at a width, in whole pixels.
---@private
---@param width number
---@return number columns, number cardWidth
function blockProto:layout(width)
  local m = self:metrics()
  local inner = width - 2 * m.pad
  local columns = inner >= 2 * m.minWidth + m.gap and 2 or 1
  return columns, pixel:Floor(self.frame, (inner - (columns - 1) * m.gap) / columns)
end

---@param width number
---@return number
function blockProto:Measure(width)
  local m = self:metrics()
  local columns = self:layout(width)
  local lines = math.max(1, math.ceil(#self.entries / columns))
  return m.half + lines * m.height + (lines - 1) * m.gap + m.gap + self.apply.frame:GetHeight() + m.half
end

---@param x number
---@param y number
---@param width number
---@param height number
-- Place lays the cards out in whole pixels (docs/next-pixel-perfect.md), so each card's edge lands on whole
-- pixels at any scale: a one-unit line between pixels drew two pixels thick or not at all (the reported
-- missing top and bottom borders of the selected card at 65% and 70%). A card's description is below its
-- name's font height rounded up, never its name's far edge.
function blockProto:Place(x, y, width, height)
  local m = self:metrics()
  local frame = self.frame
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  pixel:Size(frame, width, height)
  local columns, cardWidth = self:layout(frame:GetWidth())
  for i = 1, #self.entries do
    local card = self.cards[i]
    local column, line = (i - 1) % columns, math.floor((i - 1) / columns)
    cards:Place(card, frame, m.pad + column * (cardWidth + m.gap), m.half + line * (m.height + m.gap), cardWidth, m.height)
  end
  local lines = math.max(1, math.ceil(#self.entries / columns))
  self.apply.frame:ClearAllPoints()
  self.apply.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", m.pad, -(m.half + lines * (m.height + m.gap)))
  frame:Show()
end
