local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Items: AceModule
local items = addon:GetModule('Items')

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

---@class NextToggle: AceModule
local nextToggle = addon:GetModule('NextToggle')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class NextDialog: AceModule
local nextDialog = addon:GetModule('NextDialog')

---@class NextSettings: AceModule
local settings = addon:GetModule('NextSettings')

---@class NextSettingsCategories: AceModule
local editor = addon:GetModule('NextSettingsCategories')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextListReorder: AceModule
local reorder = addon:GetModule('NextListReorder')

-- NextSettingsBagCategories is a bag's categories, on its Categories tab (next-settings.md §5,
-- category-lifecycle.md §6): categories are defined once on the Categories page, and a bag arranges
-- them. A wide row listing the pinned categories in their order (customSectionSort), then every other
-- one by name: the categories defined and the bag's sections read from its committed items (not Recent
-- Items, Free Space, empty slots, or the bags of Show Bags). A defined category has a switch for whether
-- this bag uses it, and its name opens it on the Categories page; a group by's sub-category says whose it
-- is and opens that one; a built-in section says it is automatic; a pinned name that is neither (a
-- leftover) can be removed. Shift-click pins or unpins; dragging a row puts it where it is let go.
---@class NextSettingsBagCategories: AceModule
---@field all NextBagCategoryList[]
local bagCategories = addon:NewModule('NextSettingsBagCategories')

-- The message a bag kind's committed sweep sends (data/items.lua Phase11).
local DONE = {
  [const.BAG_KIND.BACKPACK] = 'items/RefreshBackpack/Done',
  [const.BAG_KIND.BANK] = 'items/RefreshBank/Done',
  [const.BAG_KIND.GUILD] = 'items/RefreshGuildBank/Done',
}

---@class NextBagCategoryRow
---@field frame Button
---@field hover Texture
---@field label FontString
---@field note FontString
---@field toggle NextToggleFrame
---@field remove NextButtonFrame
---@field entry? table
---@field hovered boolean

---@class NextBagCategoryList
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field bag SettingBag
---@field entries table[] { header = true, title } or { name }
---@field rows NextBagCategoryRow[] The rows of the entries, in the same order.
---@field byKey table<string|table, NextBagCategoryRow> Each entry's own row (a category's by its name, a
--- heading's by its own key): moved in the order, it slides.
---@field free NextBagCategoryRow[] Rows no entry has, hidden, to reuse.
---@field drag NextListReorderList Arranges the rows; dragging one pins it where it lands, or unpins it.
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextBagCategoryList')

bagCategories.all = {}

---@param ctx? Context
function bagCategories:ApplyStyle(ctx)
  local _ = ctx
  for _, block in ipairs(self.all) do
    block:Style()
  end
end

-- rederive recalculates the bags with a fresh layout (refresh-scheduler.md §10).
---@param ctx Context
local function rederive(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

-- A heading's row is kept under a table of its own, a key no category's name can be.
local headingKeys = setmetatable({}, { __index = function(keys, title)
  local key = {}
  keys[title] = key
  return key
end })

-- keyOf returns the key of the row an entry has: a category's name, or its heading's own key.
---@param entry table
---@return string|table
local function keyOf(entry)
  return entry.name or headingKeys[entry.title]
end

---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@param bag SettingBag
---@return NextBagCategoryList
function bagCategories:Create(parent, owner, bag)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextBagCategoryList
  local block = setmetatable({ frame = frame, wide = true, owner = owner, bag = bag, entries = {}, rows = {},
    byKey = {}, free = {} }, { __index = listProto })
  block.fill = frame:CreateTexture(nil, "BACKGROUND")
  block.filter = nextInput:Create(frame, {
    help = L:G("Find a category"),
    onChange = function() block:Refresh() end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(30)
  box:Init(view)
  block.bar = nextScrollBar:Create(box)
  block.bar:Bind(box)
  block.listBox, block.listContent = box, content
  -- A row lands after the Pinned heading, the list's first entry.
  block.drag = reorder:Create({
    box = box, content = content, first = 2,
    entries = function() return block.entries end,
    rowOf = function(entry) return block.byKey[keyOf(entry)].frame end,
    heightOf = function(entry)
      local K = style.Theme.Settings.BagCategories
      return entry.header and K.GroupHeight or K.RowHeight
    end,
    onDrop = function(name, after) block:Drop(name, after) end,
  })
  table.insert(self.all, block)
  sonataNext:RegisterWidget(self)
  for _, message in ipairs({ DONE[bag.kind], 'categories/Changed' }) do
    events:RegisterMessage(message, function(ctx)
      if frame:IsVisible() then
        block:Refresh(ctx)
      end
    end)
  end
  block:Style()
  return block
end

-- Style draws the list from the theme and lays it out again.
function listProto:Style()
  local K = style.Theme.Settings.BagCategories
  controls:Paint(self.fill, K.Fill)
  for _, row in ipairs(self.rows) do
    self:paintRow(row)
  end
  if self.width then
    self:Place(self.x, self.y, self.width, self.height)
  end
end

-- RowFor returns the row of a category the list shows.
---@param name string
---@return NextBagCategoryRow?
function listProto:RowFor(name)
  return self.byKey[name]
end

-- sections returns the bag's sections from its committed items (none in Show Bags, whose sections are
-- the bags).
---@private
---@return table<string, boolean>
function listProto:sections()
  local set = {}
  local slotInfo = items.slotInfo and items.slotInfo[self.bag.kind]
  if slotInfo and db:GetBagView(self.bag.kind) ~= const.BAG_VIEW.SECTION_ALL_BAGS then
    for _, data in pairs(slotInfo.itemsBySlotKey or {}) do
      local category = not data.isItemEmpty and data.itemInfo and data.itemInfo.category
      if category and category ~= L:G("Recent Items") and category ~= L:G("Free Space") then
        set[category] = true
      end
    end
  end
  return set
end

-- Refresh lists the categories again: the pinned ones in their order, then the rest by name, those
-- whose name has the filter's text.
---@param ctx? Context
function listProto:Refresh(ctx)
  local _ = ctx
  local needle = strtrim(self.filter:GetText() or ""):lower()
  local function wanted(name)
    return needle == "" or name:lower():find(needle, 1, true) ~= nil
  end
  self.sectionSet = self:sections()
  local names = {}
  for name in pairs(categories:GetAllCategories()) do
    names[name] = true
  end
  for name in pairs(self.sectionSet) do
    names[name] = true
  end
  local pins = db:GetCustomSectionSort(self.bag.kind) or {}
  local pinnedList = {}
  for name, index in pairs(pins) do
    if wanted(name) then
      table.insert(pinnedList, { name = name, index = index })
    end
  end
  table.sort(pinnedList, function(a, b) return a.index < b.index end)
  local entries = { { header = true, title = L:G("Pinned") } }
  for _, p in ipairs(pinnedList) do
    table.insert(entries, { name = p.name })
  end
  table.insert(entries, { header = true, title = L:G("Other Categories") })
  local others = {}
  for name in pairs(names) do
    if pins[name] == nil and wanted(name) then
      table.insert(others, name)
    end
  end
  table.sort(others)
  for _, name in ipairs(others) do
    table.insert(entries, { name = name })
  end
  self.entries = entries
  self:layoutList()
end

-- kindOf says what a name in the list is: a category defined ("defined"), a group by's sub-category
-- ("group"), a section BetterBags makes ("automatic"), or a pinned name that is none of them ("leftover").
---@private
---@param name string
---@return "defined"|"group"|"automatic"|"leftover", CustomCategoryFilter?
function listProto:kindOf(name)
  local filter = categories:GetCategoryByName(name)
  if filter and filter.isGroupBySubcategory then
    return "group", filter
  end
  if filter then
    return "defined", filter
  end
  if self.sectionSet and self.sectionSet[name] then
    return "automatic"
  end
  return "leftover"
end

-- rowFor returns an entry's own row, taking one no entry has, or making one, the first time.
---@private
---@param entry table
---@return NextBagCategoryRow
function listProto:rowFor(entry)
  local key = keyOf(entry)
  local row = self.byKey[key]
  if row == nil then
    row = table.remove(self.free) or self:newRow()
    self.byKey[key] = row
  end
  return row
end

-- newRow makes a row.
---@private
---@return NextBagCategoryRow
function listProto:newRow()
  local K = style.Theme.Settings.BagCategories
  local frame = CreateFrame("Button", nil, self.listContent)
  frame:RegisterForClicks("LeftButtonUp")
  frame:RegisterForDrag("LeftButton")
  ---@type NextBagCategoryRow
  local row = {
    frame = frame,
    hover = frame:CreateTexture(nil, "BACKGROUND"),
    label = style:CreateText(frame, K.Font),
    note = style:CreateText(frame, K.NoteFont),
    hovered = false,
  }
  row.toggle = nextToggle:Create(frame, {
    onChange = function(ctx, on)
      if row.entry and row.entry.name then
        categories:UpdateCategory(ctx, row.entry.name, { enabled = { [self.bag.kind] = on } })
      end
    end,
  })
  row.remove = nextButton:Create(frame, {
    text = L:G("Remove"), style = "Link",
    onClick = function(ctx)
      if row.entry and row.entry.name then
        self:AskRemove(ctx, row.entry.name)
      end
    end,
  })
  row.hover:SetAllPoints(frame)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  row.note:SetJustifyH("RIGHT")
  addon.SetScript(frame, "OnClick", function(ctx) self:ClickRow(ctx, row) end)
  addon.SetScript(frame, "OnEnter", function()
    row.hovered = true
    self:paintRow(row)
    if row.entry and row.entry.name then
      GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
      GameTooltip:SetText(L:G("Shift-click to pin or unpin this category. Drag it to reorder it."), 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  addon.SetScript(frame, "OnLeave", function()
    row.hovered = false
    self:paintRow(row)
    if GameTooltip:IsOwned(frame) then
      GameTooltip:Hide()
    end
  end)
  addon.SetScript(frame, "OnDragStart", function()
    if row.entry and row.entry.name then
      self.drag:Start(row.entry.name)
    end
  end)
  return row
end

-- layoutList shows each entry in its own row, headings GroupHeight tall and categories RowHeight tall,
-- each with what belongs on its right, and puts the rows of entries no longer listed away; the list's
-- arrangement places them (NextListReorder: a row that moved slides).
---@private
function listProto:layoutList()
  local K = style.Theme.Settings.BagCategories
  local listed = {}
  self.rows = {}
  for i, entry in ipairs(self.entries) do
    local row = self:rowFor(entry)
    listed[keyOf(entry)] = true
    self.rows[i] = row
    row.entry = entry
    row.frame:SetHeight(entry.header and K.GroupHeight or K.RowHeight)
    row.frame:EnableMouse(entry.header ~= true)
    row.toggle.frame:Hide()
    row.remove.frame:Hide()
    row.note:SetText("")
    if entry.header then
      row.label:SetText(string.upper(entry.title))
    else
      row.label:SetText(entry.name)
      local kind, filter = self:kindOf(entry.name)
      if kind == "defined" then
        row.toggle:SetChecked(filter.enabled == nil or filter.enabled[self.bag.kind] ~= false)
        row.toggle.frame:Show()
      elseif kind == "group" then
        local parent = filter.groupByParent or entry.name:match("^(.-) %- ") or entry.name
        row.note:SetText(format(L:G("Grouped by %s"), parent))
      elseif kind == "automatic" then
        row.note:SetText(L:G("Automatic"))
      else
        row.remove.frame:Show()
      end
    end
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
  self.drag:Arrange()
end

-- paintRow draws a row: a heading, or a category, lit under the pointer.
---@private
---@param row NextBagCategoryRow
function listProto:paintRow(row)
  local K = style.Theme.Settings.BagCategories
  local entry = row.entry
  row.label:ClearAllPoints()
  row.note:ClearAllPoints()
  if entry == nil or entry.header then
    style:SetFont(row.label, K.GroupFont)
    row.label:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", K.Indent, 4)
    row.hover:Hide()
    return
  end
  style:SetFont(row.label, K.Font)
  style:SetFont(row.note, K.NoteFont)
  row.toggle.frame:ClearAllPoints()
  row.toggle.frame:SetPoint("RIGHT", row.frame, "RIGHT", -K.Indent, 0)
  row.remove.frame:ClearAllPoints()
  row.remove.frame:SetPoint("RIGHT", row.frame, "RIGHT", -K.Indent, 0)
  row.note:SetPoint("RIGHT", row.frame, "RIGHT", -K.Indent, 0)
  row.label:SetPoint("LEFT", row.frame, "LEFT", K.Indent, 0)
  row.label:SetPoint("RIGHT", row.note, "LEFT", -6, 0)
  controls:Paint(row.hover, row.hovered and K.HoverFill or false)
end

-- ClickRow opens a category on the Categories page (a group by's sub-category: its category), or pins
-- or unpins it with Shift.
---@param ctx Context
---@param row NextBagCategoryRow
function listProto:ClickRow(ctx, row)
  local _ = ctx
  local entry = row.entry
  if entry == nil or entry.name == nil then
    return
  end
  if IsShiftKeyDown() then
    local pins = db:GetCustomSectionSort(self.bag.kind) or {}
    if pins[entry.name] ~= nil then
      self:Drop(entry.name, self:otherHeading())
    else
      self:Drop(entry.name, 1)
    end
    return
  end
  local kind, filter = self:kindOf(entry.name)
  local open
  if kind == "defined" then
    open = entry.name
  elseif kind == "group" then
    open = filter.groupByParent or entry.name:match("^(.-) %- ")
  end
  if open then
    editor:Show(open)
    settings:Open("categories")
  end
end

-- otherHeading returns where the heading of the categories not pinned is in the list.
---@private
---@return number
function listProto:otherHeading()
  for i = 2, #self.entries do
    if self.entries[i].header then
      return i
    end
  end
  return #self.entries
end

-- Drop moves a category to just after the after-th entry of the list: pinned at that place when it
-- lands above the heading of the categories not pinned, unpinned below it. The pinned order is saved
-- (from 1) and the bags recalculated.
---@param name string
---@param after number
function listProto:Drop(name, after)
  local list = {}
  local old
  for i, entry in ipairs(self.entries) do
    list[i] = entry
    if entry.name == name then
      old = i
    end
  end
  if old == nil then
    return
  end
  if old <= after then
    after = after - 1
  end
  table.remove(list, old)
  after = math.max(1, math.min(after, #list))
  table.insert(list, after + 1, { name = name })
  local kind = self.bag.kind
  local pins = db:GetCustomSectionSort(kind) or {}
  -- A filtered list shows only some pins; those it hides keep their order after the ones it shows.
  local hidden = {}
  local shownPins = {}
  for i = 2, #list do
    if list[i].header then
      break
    end
    shownPins[list[i].name] = true
  end
  for pinName, index in pairs(pins) do
    if not shownPins[pinName] and pinName ~= name then
      table.insert(hidden, { name = pinName, index = index })
    end
  end
  table.sort(hidden, function(a, b) return a.index < b.index end)
  db:ClearCustomSectionSort(kind)
  local index = 0
  for i = 2, #list do
    local entry = list[i]
    if entry.header then
      break
    end
    index = index + 1
    db:SetCustomSectionSort(kind, entry.name, index)
  end
  for _, h in ipairs(hidden) do
    index = index + 1
    db:SetCustomSectionSort(kind, h.name, index)
  end
  rederive(context:New('NextSettingsBagCategories_Pin'))
  self:Refresh()
end

-- AskRemove removes a leftover after asking: categories:DeleteCategory scrubs what it left in every bag
-- (its pins and tabs, category-lifecycle.md §2).
---@param ctx Context
---@param name string
function listProto:AskRemove(ctx, name)
  local _ = ctx
  nextDialog:Show(self.owner, {
    title = L:G("Remove Category"),
    text = format(L:G("Remove '%s' from the list? What it left in every bag (its pins and tabs) goes."), name),
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = L:G("Remove"), style = "Danger", onClick = function(dctx)
        categories:DeleteCategory(dctx, name)
        self:Refresh(dctx)
      end },
    },
  })
end

---@param width number
---@return number
function listProto:Measure(width)
  local _ = width
  return style.Theme.Settings.BagCategories.Height
end

-- Place lays the list out: its filter at the top, the rows under it.
---@param x number
---@param y number
---@param width number
---@param height number
function listProto:Place(x, y, width, height)
  self.x, self.y, self.width, self.height = x, y, width, height
  local K = style.Theme.Settings.BagCategories
  local I = controls:Theme("Input")
  local frame, pad = self.frame, K.Pad
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  frame:SetSize(width, height)
  self.fill:ClearAllPoints()
  self.fill:SetAllPoints(frame)
  self.filter.frame:ClearAllPoints()
  self.filter.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
  self.filter.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
  self.listBox:ClearAllPoints()
  self.listBox:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(pad + I.Height + pad))
  self.listBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
  self.drag:Arrange(width - 2 * pad)
  frame:Show()
end
