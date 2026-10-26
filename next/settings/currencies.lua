local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextScrollBar: AceModule
local nextScrollBar = addon:GetModule('NextScrollBar')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextListReorder: AceModule
local reorder = addon:GetModule('NextListReorder')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextSettingsItemsTab: AceModule
local itemsTab = addon:GetModule('NextSettingsItemsTab')

---@class Currencies: AceModule
local currencies = addon:GetModule('Currencies')

-- NextSettingsCurrencies is BetterBags Next's Currencies page's own parts (currency.md §6); its Currencies tab is the
-- currency list every client's Currency page shows (NextSettingsCurrency, made with track), its Display tab settings
-- rows (the catalog's). Here:
-- - the Tracked tab: what is tracked, currencies and items together, in the order the strip and the tracker show them,
--   as a list drawn as a bag's categories are (NextSettingsBagCategories' theme keys): each row its icon, its name, how
--   many you have and Remove; dragging a row moves it (NextListReorder, the drag every settings list shares);
-- - the Items tab's source: the items tracked, in the shared items tab (NextSettingsItemsTab, as a category's Added
--   Items): an item dropped on it is tracked (one that stacks, as the strip takes), a right click removes one.
---@class NextSettingsCurrencies: AceModule
---@field all NextTrackedList[]
local page = addon:NewModule('NextSettingsCurrencies')

---@class NextTrackedRow
---@field frame Button
---@field hover Texture
---@field icon Texture
---@field label FontString
---@field note FontString
---@field remove NextButtonFrame
---@field entry? { name: string, state: NextCurrencyState }
---@field hovered boolean

---@class NextTrackedList
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field fill Texture
---@field help FontString
---@field empty FontString
---@field listBox WowScrollBox
---@field listContent Frame
---@field bar NextScrollBarFrame
---@field entries { name: string, state: NextCurrencyState }[] What is tracked, in order; name is its key.
---@field rows NextTrackedRow[] The rows of the entries, in the same order.
---@field byKey table<string, NextTrackedRow> Each entry's own row: moved in the order, it slides.
---@field free NextTrackedRow[] Rows no entry has, hidden, to reuse.
---@field drag NextListReorderList
---@field x? number
---@field y? number
---@field width? number
---@field height? number
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextTrackedList')

page.all = {}

---@param ctx? Context
function page:ApplyStyle(ctx)
  local _ = ctx
  for _, list in ipairs(self.all) do
    list:Style()
  end
end

-- countOf writes how many of a tracked entry you have (of the most a currency holds).
---@param state NextCurrencyState
---@return string
local function countOf(state)
  local have = BreakUpLargeNumbers(state.count)
  local most = state.max or (state.season and state.season.max)
  if most then
    return have .. " / " .. BreakUpLargeNumbers(most)
  end
  return have
end

-- nameOf is a tracked entry's name, or what it is while the client has not loaded it.
---@param state NextCurrencyState
---@return string
local function nameOf(state)
  if state.name ~= nil and state.name ~= "" then
    return state.name
  end
  return format(state.kind == "item" and L:G("Item %d") or L:G("Currency %d"), state.id)
end

-- CreateTracked makes the Tracked tab's list.
---@param parent Frame
---@param owner Frame
---@return NextTrackedList
function page:CreateTracked(parent, owner)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextTrackedList
  local list = setmetatable({ frame = frame, wide = true, owner = owner, entries = {}, rows = {}, byKey = {},
    free = {} }, { __index = listProto })
  list.fill = frame:CreateTexture(nil, "BACKGROUND")
  list.help = style:CreateText(frame, style.Theme.Settings.Categories.HintFont)
  list.help:SetJustifyH("LEFT")
  list.help:SetWordWrap(true)
  list.help:SetText(L:G("What shows at the bottom of your backpack and in its tracker, in this order. Drag one to "
    .. "move it. Add currencies on the Currencies tab, and items on the Items tab or by dropping them on your "
    .. "backpack's currencies."))
  list.empty = style:CreateText(frame, style.Theme.Settings.Content.TextFont)
  list.empty:SetText(L:G("Nothing tracked yet."))
  list.empty:Hide()
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  pixel:SnapScroll(box)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(30)
  box:Init(view)
  list.bar = nextScrollBar:Create(box)
  list.bar:Bind(box)
  list.listBox, list.listContent = box, content
  list.drag = reorder:Create({
    box = box, content = content,
    entries = function() return list.entries end,
    rowOf = function(entry) return list.byKey[entry.name].frame end,
    heightOf = function() return list:rowHeight() end,
    onDrop = function(name, after) list:Drop(name, after) end,
  })
  table.insert(self.all, list)
  sonataNext:RegisterWidget(self)
  -- What is tracked, its order and what each reads change elsewhere too (the strip, the other tabs, a gain).
  for _, message in ipairs({ 'currencies/Changed', 'currencies/Updated' }) do
    events:RegisterMessage(message, function(ctx)
      if frame:IsVisible() then
        list:Refresh(ctx)
      end
    end)
  end
  list:Style()
  return list
end

-- rowHeight is a row's height in whole pixels (docs/next-pixel-perfect.md).
---@return number
function listProto:rowHeight()
  return pixel:Length(self.frame, style.Theme.Settings.BagCategories.RowHeight)
end

-- Style draws the list from the theme and lays it out again.
function listProto:Style()
  local K = style.Theme.Settings.BagCategories
  controls:Paint(self.fill, K.Fill)
  style:SetFont(self.help, style.Theme.Settings.Categories.HintFont)
  style:SetFont(self.empty, style.Theme.Settings.Content.TextFont)
  for _, row in ipairs(self.rows) do
    self:paintRow(row)
  end
  if self.width then
    self:Place(self.x, self.y, self.width, self.height)
  end
end

-- Refresh lists what is tracked again, in order.
---@param ctx? Context
function listProto:Refresh(ctx)
  local _ = ctx
  local entries = {}
  for _, state in ipairs(currencies:States()) do
    table.insert(entries, { name = state.key, state = state })
  end
  self.entries = entries
  self:layoutList()
end

-- RowFor returns the row of a tracked entry the list shows, by its key.
---@param key string
---@return NextTrackedRow?
function listProto:RowFor(key)
  return self.byKey[key]
end

-- rowFor returns an entry's own row, taking one no entry has, or making one, the first time.
---@private
---@param entry table
---@return NextTrackedRow
function listProto:rowFor(entry)
  local row = self.byKey[entry.name]
  if row == nil then
    row = table.remove(self.free) or self:newRow()
    self.byKey[entry.name] = row
  end
  return row
end

-- newRow makes a row.
---@private
---@return NextTrackedRow
function listProto:newRow()
  local K = style.Theme.Settings.BagCategories
  local frame = CreateFrame("Button", nil, self.listContent)
  frame:RegisterForDrag("LeftButton")
  ---@type NextTrackedRow
  local row = {
    frame = frame,
    hover = frame:CreateTexture(nil, "BACKGROUND"),
    icon = frame:CreateTexture(nil, "ARTWORK"),
    label = style:CreateText(frame, K.Font),
    note = style:CreateText(frame, K.NoteFont),
    hovered = false,
  }
  row.remove = nextButton:Create(frame, {
    text = L:G("Remove"), style = "Link",
    onClick = function(ctx)
      if row.entry then
        currencies:Untrack(ctx, row.entry.state.kind, row.entry.state.id)
      end
    end,
  })
  row.hover:SetAllPoints(frame)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  row.note:SetJustifyH("RIGHT")
  addon.SetScript(frame, "OnEnter", function()
    row.hovered = true
    self:paintRow(row)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(L:G("Drag it to move it."), 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  addon.SetScript(frame, "OnLeave", function()
    row.hovered = false
    self:paintRow(row)
    if GameTooltip:IsOwned(frame) then
      GameTooltip:Hide()
    end
  end)
  addon.SetScript(frame, "OnDragStart", function()
    if row.entry then
      self.drag:Start(row.entry.name)
    end
  end)
  return row
end

-- layoutList shows each entry in its own row and puts the rows of entries no longer listed away; the list's
-- arrangement places them (NextListReorder: a row that moved slides).
---@private
function listProto:layoutList()
  local listed = {}
  self.rows = {}
  for i, entry in ipairs(self.entries) do
    local row = self:rowFor(entry)
    listed[entry.name] = true
    self.rows[i] = row
    row.entry = entry
    row.frame:SetHeight(self:rowHeight())
    row.icon:SetTexture(entry.state.icon)
    row.label:SetText(nameOf(entry.state))
    row.note:SetText(countOf(entry.state))
    row.frame:Show()
    self:paintRow(row)
  end
  for key, row in pairs(self.byKey) do
    if not listed[key] then
      self.byKey[key] = nil
      row.entry = nil
      row.frame:Hide()
      table.insert(self.free, row)
    end
  end
  self.empty:SetShown(#self.entries == 0)
  self.drag:Arrange()
end

-- paintRow draws a row, lit under the pointer: its icon, its name, how many (faded with none) and Remove.
---@private
-- From the row's corners, each centered on its height by its top (docs/next-pixel-perfect.md); the name stops short
-- of the count by the count's width rounded up, never at the count's far edge.
---@param row NextTrackedRow
function listProto:paintRow(row)
  local K = style.Theme.Settings.BagCategories
  local C = style.Theme.Settings.Currency
  local frame = row.frame
  style:SetFont(row.label, K.Font)
  style:SetFont(row.note, K.NoteFont)
  controls:Paint(row.hover, row.hovered and K.HoverFill or false)
  local height = self:rowHeight()
  local indent, gap = pixel:Snap(frame, K.Indent), pixel:Snap(frame, C.Gap)
  pixel:Size(row.icon, C.IconSize, C.IconSize)
  row.icon:ClearAllPoints()
  pixel:Row(row.icon, "TOPLEFT", frame, indent, height)
  row.icon:SetDesaturated(row.entry ~= nil and row.entry.state.none)
  row.remove.frame:ClearAllPoints()
  pixel:Row(row.remove.frame, "TOPRIGHT", frame, indent, height)
  local right = indent + row.remove.frame:GetWidth() + gap
  row.note:ClearAllPoints()
  pixel:Row(row.note, "TOPRIGHT", frame, right, height)
  right = right + pixel:Ceil(frame, row.note:GetStringWidth()) + gap
  row.label:ClearAllPoints()
  pixel:Row(row.label, "TOPLEFT", frame, indent + pixel:Length(frame, C.IconSize) + gap, height)
  pixel:Row(row.label, "TOPRIGHT", frame, right, height)
end

-- Drop moves a tracked entry to just after the after-th entry of the list (counted with it; 0: first).
---@param name string
---@param after number
function listProto:Drop(name, after)
  currencies:Move(context:New('NextSettingsCurrencies_Move'), name, after)
end

---@param width number
---@return number
function listProto:Measure(width)
  local _ = width
  return itemsTab:TabHeight(self.frame)
end

-- Place lays the list out: its help at the top, the rows under it.
---@param x number
---@param y number
---@param width number
---@param height number
function listProto:Place(x, y, width, height)
  itemsTab:PlaceTab(self, x, y, width, height)
  local frame = self.frame
  local m = itemsTab:Metrics(frame)
  local pad = m.pad
  self.fill:ClearAllPoints()
  self.fill:SetAllPoints(frame)
  self.help:ClearAllPoints()
  pixel:Point(self.help, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
  self.help:SetWidth(self.width - 2 * pad)
  local top = pad + pixel:Ceil(frame, self.help:GetStringHeight()) + m.gap
  self.empty:ClearAllPoints()
  pixel:Point(self.empty, "TOPLEFT", frame, "TOPLEFT", pad, -top)
  self.listBox:ClearAllPoints()
  self.listBox:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
  self.listBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
  self.drag:Arrange(self.width - 2 * pad)
end

-- placesOf says where you have an item: in your bags, bank, reagent bank and Warband bank, each that has some.
---@param id number
---@return string
local function placesOf(id)
  local places = currencies:ItemPlaces(id)
  local parts = {}
  for _, place in ipairs({ { "bags", L:G("%s in your bags") }, { "bank", L:G("%s in your bank") },
    { "reagent", L:G("%s in your reagent bank") }, { "warband", L:G("%s in your Warband bank") } }) do
    local n = places[place[1]]
    if n > 0 then
      table.insert(parts, format(place[2], BreakUpLargeNumbers(n)))
    end
  end
  return table.concat(parts, ", ")
end

-- ItemsSource is the Items tab's: the items tracked.
---@return NextItemsSource
function page:ItemsSource()
  ---@type NextItemsSource
  return {
    key = function() return "tracked" end,
    list = function()
      local set = {}
      for _, entry in ipairs(currencies:Tracked()) do
        if entry.kind == "item" then
          set[entry.id] = true
        end
      end
      return set
    end,
    help = function()
      return L:G("Drag an item here to track it at the bottom of your backpack. Only items that stack can be "
        .. "tracked.")
    end,
    words = function() return L:G("%d tracked item"), L:G("%d tracked items") end,
    empty = L:G("No items tracked yet."),
    notes = function(_, list)
      local notes = {}
      for id in pairs(list) do
        local state = currencies:State(currencies:Key("item", id))
        if state == nil or state.none then
          notes[id] = { dim = true, note = L:G("You have none.") }
        else
          notes[id] = { dim = false, note = placesOf(id), count = state.count }
        end
      end
      return notes
    end,
    add = function(ctx, _, itemID)
      if not currencies:CanTrackItem(itemID) then
        print("BetterBags: " .. L:G("Only items that stack can be tracked."))
        return false
      end
      currencies:Track(ctx, "item", itemID)
      return true
    end,
    remove = function(ctx, _, itemID)
      currencies:Untrack(ctx, "item", itemID)
    end,
    clear = function(ctx)
      for _, entry in ipairs(currencies:Tracked()) do
        if entry.kind == "item" then
          currencies:Untrack(ctx, entry.kind, entry.id)
        end
      end
    end,
    clearText = function(_, counted)
      return format(L:G("Stop tracking %s? Drop them here again to track them."), counted)
    end,
    messages = { 'currencies/Changed', 'currencies/Updated' },
  }
end

-- CreateItems makes the Items tab: the shared items tab over the items tracked.
---@param parent Frame
---@param owner Frame
---@return NextItemsTab
function page:CreateItems(parent, owner)
  return itemsTab:Create(parent, owner, self:ItemsSource())
end
