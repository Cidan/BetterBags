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

---@class ItemRowFrame: AceModule
local itemRowFrame = addon:GetModule('ItemRowFrame')

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

---@class NextDropdown: AceModule
local nextDropdown = addon:GetModule('NextDropdown')

---@class NextSwatch: AceModule
local nextSwatch = addon:GetModule('NextSwatch')

---@class NextMenu: AceModule
local nextMenu = addon:GetModule('NextMenu')

---@class NextDialog: AceModule
local nextDialog = addon:GetModule('NextDialog')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSettingsCategories is the category manager on a bag's Categories tab (next-settings.md §5), a
-- wide row: the bag's categories down its left (Pinned in their order, then every other one by name),
-- and the chosen one's settings on its right. It keeps everything the classic settings window's
-- category pane did (category-lifecycle.md) through the same Categories and Database calls:
-- pinning and reordering (customSectionSort), a search category's query and group by kept in step, its
-- priority, color (Warcraft gold, the default, saved as none), Show Section, the items added to it, Save,
-- Rename (not a dynamic category), Delete (not a group by sub-category), and Remove for a built-in or
-- leftover category. New: a new item list category, and a new search category, made once it has a query.
---@class NextSettingsCategories: AceModule
---@field all NextCategoryManager[]
local manager = addon:NewModule('NextSettingsCategories')

-- A category without a color is drawn in Warcraft gold (the section titles' default).
local GOLD = { 1, 0.82, 0, 1 }

local GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY
-- The group by choices, in the dropdown's order, and the words the query names them by.
local GROUP_BY_NAMES = { L:G("None"), L:G("Type"), L:G("Subtype"), L:G("Expansion") }
local GROUP_BY_OF_NAME = {
  [L:G("None")] = GROUP_BY.NONE, [L:G("Type")] = GROUP_BY.TYPE,
  [L:G("Subtype")] = GROUP_BY.SUBTYPE, [L:G("Expansion")] = GROUP_BY.EXPANSION,
}
local NAME_OF_GROUP_BY = {
  [GROUP_BY.NONE] = L:G("None"), [GROUP_BY.TYPE] = L:G("Type"),
  [GROUP_BY.SUBTYPE] = L:G("Subtype"), [GROUP_BY.EXPANSION] = L:G("Expansion"),
}
local GROUP_BY_OF_WORD = {
  none = GROUP_BY.NONE, type = GROUP_BY.TYPE, subtype = GROUP_BY.SUBTYPE,
  expansion = GROUP_BY.EXPANSION, exp = GROUP_BY.EXPANSION,
}
local WORD_OF_GROUP_BY = {
  [GROUP_BY.NONE] = "none", [GROUP_BY.TYPE] = "type", [GROUP_BY.SUBTYPE] = "subtype", [GROUP_BY.EXPANSION] = "expansion",
}

-- A query's group by clause, at its end (the classic pane's and the search category editor's).
local GROUP_BY_PATTERN = "%s+group%s+by%s+(%w+)%s*$"

---@param query string
---@return number?
local function groupByOf(query)
  local word = query:lower():match(GROUP_BY_PATTERN)
  return word and GROUP_BY_OF_WORD[word] or nil
end

---@param query string
---@return string
local function withoutGroupBy(query)
  local stripped = query:gsub("%s+[Gg][Rr][Oo][Uu][Pp]%s+[Bb][Yy]%s+%w+%s*$", "")
  return stripped
end

---@param query string
---@param groupBy number
---@return string
local function withGroupBy(query, groupBy)
  local clean = withoutGroupBy(query)
  if groupBy == GROUP_BY.NONE then
    return clean
  end
  local word = WORD_OF_GROUP_BY[groupBy]
  if clean ~= "" then
    return clean .. " group by " .. word
  end
  return "group by " .. word
end

-- The message a bag kind's committed sweep sends (data/items.lua Phase11).
local DONE = {
  [const.BAG_KIND.BACKPACK] = 'items/RefreshBackpack/Done',
  [const.BAG_KIND.BANK] = 'items/RefreshBank/Done',
  [const.BAG_KIND.GUILD] = 'items/RefreshGuildBank/Done',
}

---@class NextCategoryListRow
---@field frame Button
---@field fill Texture
---@field hover Texture
---@field indicator Texture
---@field label FontString
---@field note FontString
---@field entry? table
---@field hovered boolean

---@class NextCategoryManager
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field bag SettingBag
---@field entries table[] { header = true, title } or { name }
---@field rows NextCategoryListRow[]
---@field selected? string
---@field draft? string The name of a new search category not made yet.
---@field detail "empty"|"search"|"items"|"builtin"|"draft"
---@field groupByValue number
---@field itemRows ItemRow[]
---@field dragging? string
local managerProto = {}
addon:GetModule('Perf'):RegisterPrototype(managerProto, 'NextCategoryManager')

manager.all = {}

---@param ctx? Context
function manager:ApplyStyle(ctx)
  local _ = ctx
  for _, block in ipairs(self.all) do
    block:Style()
  end
end

-- rederive recalculates the bags with a fresh layout, as every category change does
-- (refresh-scheduler.md §10).
---@param ctx Context
local function rederive(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@param bag SettingBag
---@return NextCategoryManager
function manager:Create(parent, owner, bag)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextCategoryManager
  local block = setmetatable({
    frame = frame, wide = true, owner = owner, bag = bag, entries = {}, rows = {}, detail = "empty",
    groupByValue = GROUP_BY.NONE, itemRows = {},
  }, { __index = managerProto })
  block:buildList()
  block:buildDetail()
  table.insert(self.all, block)
  sonataNext:RegisterWidget(self)
  -- The list names the bag's sections: read them again when its items are.
  events:RegisterMessage(DONE[bag.kind], function(ctx)
    if frame:IsVisible() then
      block:RefreshList(ctx)
    end
  end)
  block:Style()
  return block
end

---@private
function managerProto:buildList()
  local frame = self.frame
  self.fill = frame:CreateTexture(nil, "BACKGROUND")
  local list = CreateFrame("Frame", nil, frame)
  self.list = list
  local box = CreateFrame("Frame", nil, list, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(26)
  box:Init(view)
  self.listBar = nextScrollBar:Create(box)
  self.listBar:Bind(box)
  self.listBox, self.listContent = box, content
  self.marker = content:CreateTexture(nil, "OVERLAY")
  self.marker:Hide()
  local width = style.Theme.Settings.Categories.ListWidth
  self.newCategory = nextButton:Create(list, {
    text = L:G("New Category"), width = width,
    onClick = function(ctx) self:AskNewCategory(ctx, false) end,
  })
  self.newSearch = nextButton:Create(list, {
    text = L:G("New Search Category"), width = width,
    onClick = function(ctx) self:AskNewCategory(ctx, true) end,
  })
end

---@private
function managerProto:buildDetail()
  local K = style.Theme.Settings.Categories
  local detail = CreateFrame("Frame", nil, self.frame)
  self.detailFrame = detail
  self.title = style:CreateText(detail, K.TitleFont)
  self.title:SetJustifyH("LEFT")
  self.info = style:CreateText(detail, K.TextFont)
  self.info:SetJustifyH("LEFT")
  self.info:SetJustifyV("TOP")
  self.info:SetWordWrap(true)
  self.labels = {}
  local function label(key, text)
    local l = style:CreateText(detail, K.LabelFont)
    l:SetJustifyH("LEFT")
    l:SetText(text)
    self.labels[key] = l
    return l
  end
  label("query", L:G("Search Query"))
  self.query = nextInput:CreateArea(detail, {
    height = K.QueryHeight, help = L:G("A search, as in the bags' search box"),
    onChange = function(ctx, text) self:OnQueryTyped(ctx, text) end,
  })
  label("priority", L:G("Priority (0-99)"))
  self.priority = nextInput:Create(detail, { width = 60, numeric = true, maxLetters = 2 })
  label("groupBy", L:G("Group By"))
  self.groupBy = nextDropdown:Create(detail, {
    items = GROUP_BY_NAMES, width = 150,
    get = function() return NAME_OF_GROUP_BY[self.groupByValue] end,
    onChange = function(ctx, name) self:OnGroupByPicked(ctx, name) end,
  })
  label("color", L:G("Color"))
  self.swatch = nextSwatch:Create(detail, { color = GOLD, onChange = function() end })
  self.resetColor = nextButton:Create(detail, {
    text = L:G("Reset Color"), onClick = function() self.swatch:SetColor(GOLD) end,
  })
  label("shown", L:G("Show Section"))
  self.shown = nextToggle:Create(detail, {
    onChange = function(ctx)
      if self.selected then
        categories:ToggleCategoryShown(ctx, self.selected)
      end
    end,
  })
  label("items", L:G("Items (drop an item here to add it)"))
  local drop = CreateFrame("Frame", nil, detail)
  drop:EnableMouse(true)
  self.itemFill = drop:CreateTexture(nil, "BACKGROUND")
  self.itemFill:SetAllPoints(drop)
  self.itemEdge = controls:CreateEdge(drop)
  local itemBox = CreateFrame("Frame", nil, drop, "WowScrollBox") --[[@as WowScrollBox]]
  itemBox:SetInterpolateScroll(true)
  local itemContent = CreateFrame("Frame", nil, itemBox)
  itemContent.scrollable = true
  local itemView = CreateScrollBoxLinearView()
  itemView:SetPanExtent(26)
  itemBox:Init(itemView)
  self.itemBar = nextScrollBar:Create(itemBox)
  self.itemBar:Bind(itemBox)
  self.itemDrop, self.itemBox, self.itemContent = drop, itemBox, itemContent
  addon.SetScript(drop, "OnReceiveDrag", function(ctx) self:DropItem(ctx) end)
  addon.SetScript(drop, "OnMouseUp", function(ctx, _, button)
    if button == "LeftButton" and CursorHasItem() then
      self:DropItem(ctx)
    end
  end)
  addon.SetScript(itemBox, "OnReceiveDrag", function(ctx) self:DropItem(ctx) end)
  addon.HookScript(itemBox, "OnMouseUp", function(ctx, _, button)
    if button == "LeftButton" and CursorHasItem() then
      self:DropItem(ctx)
    end
  end)
  self.warning = style:CreateText(detail, K.WarningFont)
  self.warning:SetJustifyH("LEFT")
  self.save = nextButton:Create(detail, { text = L:G("Save"), style = "Primary", onClick = function(ctx) self:Save(ctx) end })
  self.rename = nextButton:Create(detail, { text = L:G("Rename"), onClick = function(ctx) self:AskRename(ctx) end })
  self.delete = nextButton:Create(detail, {
    text = L:G("Delete Category"), style = "Danger", onClick = function(ctx) self:AskDelete(ctx) end,
  })
  self.remove = nextButton:Create(detail, {
    text = L:G("Remove Category"), style = "Danger", onClick = function(ctx) self:AskRemove(ctx) end,
  })
end

-- Style draws the manager from the theme and lays it out again.
function managerProto:Style()
  local K = style.Theme.Settings.Categories
  controls:Paint(self.fill, K.Fill)
  controls:Paint(self.marker, { Color = K.DropMarker.Color }, K.DropMarker.Alpha)
  self.marker:SetHeight(K.DropMarker.Size or 2)
  style:SetFont(self.title, K.TitleFont)
  style:SetFont(self.info, K.TextFont)
  style:SetFont(self.warning, K.WarningFont)
  for _, l in pairs(self.labels) do
    style:SetFont(l, K.LabelFont)
  end
  local I = controls:Theme("Input")
  controls:Paint(self.itemFill, I.Fill)
  controls:PaintEdge(self.itemEdge, I.Edge, I.Edge.Idle)
  for _, row in ipairs(self.rows) do
    self:paintRow(row)
  end
  if self.width then
    self:Place(self.x, self.y, self.width, self.height)
  end
end

-- RowFor returns the list row of a category.
---@param name string
---@return NextCategoryListRow?
function managerProto:RowFor(name)
  for i, entry in ipairs(self.entries) do
    if entry.name == name then
      return self.rows[i]
    end
  end
  return nil
end

-- names returns the category names the list shows: every category defined and the bag's sections from
-- its committed items (not Recent Items or Free Space, and none in Show Bags, whose sections are the
-- bags), pinned or not.
---@return table<string, boolean>
function managerProto:names()
  local set = {}
  for name in pairs(categories:GetAllCategories()) do
    set[name] = true
  end
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

-- RefreshList lists the categories again: Pinned in their order, then the rest by name.
---@param ctx? Context
function managerProto:RefreshList(ctx)
  local _ = ctx
  local pins = db:GetCustomSectionSort(self.bag.kind) or {}
  local pinnedList = {}
  for name, index in pairs(pins) do
    table.insert(pinnedList, { name = name, index = index })
  end
  table.sort(pinnedList, function(a, b) return a.index < b.index end)
  local entries = { { header = true, title = L:G("Pinned") } }
  for _, p in ipairs(pinnedList) do
    table.insert(entries, { name = p.name })
  end
  table.insert(entries, { header = true, title = L:G("Other Categories") })
  local others = {}
  for name in pairs(self:names()) do
    if pins[name] == nil then
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

-- row returns the i-th list row, made the first time it is needed.
---@private
---@param i number
---@return NextCategoryListRow
function managerProto:row(i)
  local row = self.rows[i]
  if row ~= nil then
    return row
  end
  local K = style.Theme.Settings.Categories
  local frame = CreateFrame("Button", nil, self.listContent)
  frame:RegisterForClicks("LeftButtonUp")
  frame:RegisterForDrag("LeftButton")
  row = {
    frame = frame,
    fill = frame:CreateTexture(nil, "BACKGROUND"),
    hover = frame:CreateTexture(nil, "BACKGROUND", nil, 1),
    indicator = frame:CreateTexture(nil, "ARTWORK"),
    label = style:CreateText(frame, K.Font),
    note = style:CreateText(frame, K.NoteFont),
    hovered = false,
  }
  row.fill:SetAllPoints(frame)
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
      self:StartDrag(row.entry.name)
    end
  end)
  self.rows[i] = row
  return row
end

-- layoutList places the list's rows, headings GroupHeight tall and categories RowHeight tall.
---@private
function managerProto:layoutList()
  local K = style.Theme.Settings.Categories
  local y = 0
  for i, entry in ipairs(self.entries) do
    local row = self:row(i)
    row.entry = entry
    local height = entry.header and K.GroupHeight or K.RowHeight
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -y)
    row.frame:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -y)
    row.frame:SetHeight(height)
    row.frame:EnableMouse(entry.header ~= true)
    row.label:SetText(entry.header and string.upper(entry.title) or entry.name)
    local filter = entry.name and categories:GetCategoryByName(entry.name)
    row.note:SetText(filter and filter.priority and format("P:%d", filter.priority) or "")
    row.frame:Show()
    self:paintRow(row)
    y = y + height
  end
  for i = #self.entries + 1, #self.rows do
    self.rows[i].entry = nil
    self.rows[i].frame:Hide()
  end
  self.listContent:SetHeight(math.max(1, y))
  self.listBox:FullUpdate(true)
end

-- paintRow draws a list row: a heading, or a category chosen, under the pointer, or neither.
---@private
---@param row NextCategoryListRow
function managerProto:paintRow(row)
  local K = style.Theme.Settings.Categories
  local entry = row.entry
  row.label:ClearAllPoints()
  row.note:ClearAllPoints()
  if entry == nil or entry.header then
    style:SetFont(row.label, K.GroupFont)
    row.label:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", K.Indent, 4)
    row.fill:Hide()
    row.hover:Hide()
    row.indicator:Hide()
    return
  end
  local chosen = entry.name == self.selected
  style:SetFont(row.label, K.Font)
  style:SetFont(row.note, K.NoteFont)
  row.note:SetPoint("RIGHT", row.frame, "RIGHT", -K.Indent, 0)
  row.label:SetPoint("LEFT", row.frame, "LEFT", K.Indent, 0)
  row.label:SetPoint("RIGHT", row.note, "LEFT", -6, 0)
  controls:Paint(row.fill, chosen and K.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and K.HoverFill or false)
  row.indicator:ClearAllPoints()
  row.indicator:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
  row.indicator:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
  row.indicator:SetWidth(K.Indicator.Width)
  controls:Paint(row.indicator, chosen and { Color = K.Indicator.Color } or false)
end

-- ClickRow chooses a category, or pins or unpins it with Shift.
---@param ctx Context
---@param row NextCategoryListRow
function managerProto:ClickRow(ctx, row)
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
  self:Select(ctx, entry.name)
end

-- otherHeading returns where the heading of the categories not pinned is in the list.
---@private
---@return number
function managerProto:otherHeading()
  for i = 2, #self.entries do
    if self.entries[i].header then
      return i
    end
  end
  return #self.entries
end

-- Drop moves a category to just after the after-th entry of the list: pinned at that place when it
-- lands above the heading of the categories not pinned, unpinned below it. The pinned order is saved
-- (from 1, as the classic pane saves it) and the bags recalculated.
---@param name string
---@param after number
function managerProto:Drop(name, after)
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
  rederive(context:New('NextSettingsCategories_Pin'))
  self:RefreshList()
end

-- gapAt returns the entry a row dropped where the pointer is would land after: the one above an entry's
-- middle, in list order.
---@private
---@return number?
function managerProto:gapAt()
  local top = self.listBox:GetTop()
  if top == nil then
    return nil
  end
  local K = style.Theme.Settings.Categories
  local _, cursorY = GetCursorPosition()
  local down = top - cursorY / self.listBox:GetEffectiveScale() + self.listBox:GetDerivedScrollOffset()
  local y = 0
  for i, entry in ipairs(self.entries) do
    local height = entry.header and K.GroupHeight or K.RowHeight
    if down < y + height then
      if down - y < height / 2 then
        return i - 1, y
      end
      return i, y + height
    end
    y = y + height
  end
  return #self.entries, y
end

-- StartDrag drags a category until the left button is let go, a marker where it would land.
---@param name string
function managerProto:StartDrag(name)
  self.dragging = name
  addon.SetScript(self.listBox, "OnUpdate", function() self:FollowDrag() end)
end

---@private
function managerProto:FollowDrag()
  local after, y = self:gapAt()
  if not IsMouseButtonDown("LeftButton") then
    self.listBox:SetScript("OnUpdate", nil)
    self.marker:Hide()
    local name = self.dragging
    self.dragging = nil
    if name and after then
      self:Drop(name, after)
    end
    return
  end
  if after == nil then
    self.marker:Hide()
    return
  end
  self.marker:ClearAllPoints()
  self.marker:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -y)
  self.marker:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -y)
  self.marker:Show()
end

-- Refresh lists the categories and shows the chosen one again (the page shows).
---@param ctx? Context
function managerProto:Refresh(ctx)
  self:RefreshList(ctx)
  self:ShowDetail()
end

-- Select chooses a category and shows its settings.
---@param ctx? Context
---@param name? string
function managerProto:Select(ctx, name)
  local _ = ctx
  self.selected = name
  self.draft = nil
  self:ShowDetail()
  for _, row in ipairs(self.rows) do
    self:paintRow(row)
  end
end

-- ShowDetail shows the chosen category's settings: a search category's, an item list category's, a
-- built-in or leftover one's (it has no filter), a new search category's not made yet, or none.
function managerProto:ShowDetail()
  self.warning:SetText("")
  local name = self.draft or self.selected
  local filter = self.selected and categories:GetCategoryByName(self.selected)
  if self.draft then
    self.detail = "draft"
  elseif name == nil then
    self.detail = "empty"
  elseif filter and filter.searchCategory then
    self.detail = "search"
  elseif filter then
    self.detail = "items"
  else
    self.detail = "builtin"
  end
  self.title:SetText(name or "")
  local d = self.detail
  if d == "empty" then
    self.info:SetText(L:G("Choose a category to see its settings."))
  elseif d == "builtin" then
    self.info:SetText(L:G("BetterBags makes this category by itself, and it cannot be edited. If it is a leftover you no longer see or use, remove it from the list."))
  end
  if d == "search" or d == "draft" then
    local query = d == "search" and (filter.searchCategory.query or "") or ""
    local stored = d == "search" and filter.searchCategory.groupBy or GROUP_BY.NONE
    local parsed = groupByOf(query)
    if parsed ~= nil then
      self.groupByValue = parsed
    else
      self.groupByValue = stored or GROUP_BY.NONE
      if self.groupByValue ~= GROUP_BY.NONE then
        query = withGroupBy(query, self.groupByValue)
      end
    end
    self.query:SetText(query)
    self.groupBy:Refresh()
  end
  if d == "search" or d == "draft" or d == "items" then
    self.priority:SetText(tostring(filter and filter.priority or 10))
    local c = filter and filter.color
    self.swatch:SetColor(c and { c[1], c[2], c[3], 1 } or GOLD)
  end
  if d == "search" or d == "items" then
    self.shown:SetChecked(categories:IsCategoryShown(name))
    local dynamic, groupBy = categories:IsDynamicCategory(name), categories:IsGroupBySubcategory(name)
    self.rename:SetEnabled(not dynamic)
    self.rename:SetText(dynamic and L:G("Cannot Rename") or L:G("Rename"))
    self.delete:SetEnabled(not groupBy)
    self.delete:SetText(groupBy and L:G("Cannot Delete") or L:G("Delete Category"))
    self:LoadItems()
  else
    self:ReleaseItems()
  end
  self:showParts()
  if self.width then
    self:layoutDetail()
  end
end

-- showParts shows the fields and buttons the chosen category has.
---@private
function managerProto:showParts()
  local d = self.detail
  local editing = d == "search" or d == "draft" or d == "items"
  local search = d == "search" or d == "draft"
  local exists = d == "search" or d == "items"
  self.info:SetShown(d == "empty" or d == "builtin")
  for _, part in ipairs({ self.labels.query, self.query.frame, self.labels.groupBy, self.groupBy.frame }) do
    part:SetShown(search)
  end
  for _, part in ipairs({ self.labels.priority, self.priority.frame, self.labels.color, self.swatch.frame,
    self.resetColor.frame, self.save.frame }) do
    part:SetShown(editing)
  end
  for _, part in ipairs({ self.labels.shown, self.shown.frame, self.labels.items, self.itemDrop,
    self.rename.frame, self.delete.frame }) do
    part:SetShown(exists)
  end
  self.remove.frame:SetShown(d == "builtin")
end

-- ReleaseItems gives the item rows back.
---@private
function managerProto:ReleaseItems()
  local ctx = context:New('NextSettingsCategories_Items')
  for _, row in ipairs(self.itemRows) do
    row.rowButton:SetScript("OnMouseDown", nil)
    row:Release(ctx)
  end
  self.itemRows = {}
end

-- LoadItems lists the items added to the chosen category, an item row each; a right click on one
-- offers to remove it.
function managerProto:LoadItems()
  self:ReleaseItems()
  local name = self.selected
  local merged = name and categories:GetMergedCategory(name)
  if not merged then
    return
  end
  local ids = {}
  for id in pairs(merged.itemList or {}) do
    table.insert(ids, id)
  end
  table.sort(ids)
  local ctx = context:New('NextSettingsCategories_Items')
  items:GetItemData(ctx, ids, function(ectx, dataList)
    if self.selected ~= name then
      return
    end
    local K = style.Theme.Settings.Categories
    for i, data in ipairs(dataList) do
      local row = itemRowFrame:Create(ectx)
      row.frame:SetParent(self.itemContent)
      row.frame:ClearAllPoints()
      row.frame:SetPoint("TOPLEFT", self.itemContent, "TOPLEFT", 4, -(i - 1) * K.ItemHeight)
      row.frame:SetPoint("TOPRIGHT", self.itemContent, "TOPRIGHT", -4, -(i - 1) * K.ItemHeight)
      row:SetStaticItemFromData(ectx, data)
      local id = ids[i]
      addon.SetScript(row.rowButton, "OnMouseDown", function(_, _, button)
        if button == "RightButton" then
          nextMenu:Open(row.rowButton, {
            items = { { text = L:G("Remove") } },
            onPick = function(pctx) self:RemoveItem(pctx, id) end,
          })
        end
      end)
      table.insert(self.itemRows, row)
    end
    self.itemContent:SetHeight(math.max(1, #dataList * K.ItemHeight))
    self.itemBox:FullUpdate(true)
  end)
end

-- DropItem adds the item on the cursor to the chosen category.
---@param ctx Context
function managerProto:DropItem(ctx)
  if not self.selected or (self.detail ~= "search" and self.detail ~= "items") or not CursorHasItem() then
    return
  end
  local kind, itemID = GetCursorInfo()
  if kind ~= "item" then
    return
  end
  categories:AddPermanentItemToCategory(ctx, itemID, self.selected)
  ClearCursor()
  rederive(ctx)
  self:LoadItems()
end

---@param ctx Context
---@param id number
function managerProto:RemoveItem(ctx, id)
  db:DeleteItemFromCategory(id, self.selected)
  rederive(ctx)
  self:LoadItems()
end

-- OnQueryTyped follows a group by clause the player typed in the query.
---@param ctx Context
---@param text string
function managerProto:OnQueryTyped(ctx, text)
  local _ = ctx
  local parsed = groupByOf(text)
  if parsed ~= nil then
    self.groupByValue = parsed
  elseif self.groupByValue ~= GROUP_BY.NONE then
    self.groupByValue = GROUP_BY.NONE
  end
  self.groupBy:Refresh()
end

-- OnGroupByPicked writes the group by picked into the query.
---@param ctx Context
---@param name string
function managerProto:OnGroupByPicked(ctx, name)
  local _ = ctx
  self.groupByValue = GROUP_BY_OF_NAME[name] or GROUP_BY.NONE
  self.query:SetText(withGroupBy(self.query:GetText(), self.groupByValue))
end

-- colorToSave returns the swatch's color as a category saves it: none for Warcraft gold.
---@private
---@return number[]?
function managerProto:colorToSave()
  local c = self.swatch:GetColor()
  if math.abs(c[1] - GOLD[1]) < 0.01 and math.abs(c[2] - GOLD[2]) < 0.01 and math.abs(c[3] - GOLD[3]) < 0.01 then
    return nil
  end
  return { c[1], c[2], c[3] }
end

-- Save saves the chosen category's settings (a new search category is made), as the classic pane does.
---@param ctx Context
function managerProto:Save(ctx)
  local priority = tonumber(self.priority:GetText()) or 10
  if self.detail == "draft" or self.detail == "search" then
    local query = withoutGroupBy(self.query:GetText())
    if strtrim(query) == "" then
      self.warning:SetText(L:G("Write a search query first."))
      return
    end
    local name = self.draft or self.selected
    local filter = self.selected and categories:GetCategoryByName(self.selected)
    categories:CreateCategory(ctx, {
      name = name,
      priority = priority,
      save = true,
      itemList = filter and filter.itemList or {},
      color = self:colorToSave(),
      searchCategory = { query = query, groupBy = self.groupByValue },
    })
    rederive(ctx)
    self:RefreshList(ctx)
    self:Select(ctx, name)
    return
  end
  if self.detail == "items" then
    local filter = categories:GetCategoryByName(self.selected)
    categories:CreateCategory(ctx, {
      name = self.selected,
      save = filter.save,
      itemList = filter.itemList or {},
      priority = priority,
      color = self:colorToSave(),
    })
    rederive(ctx)
    self:RefreshList(ctx)
  end
end

-- askName asks for a category name; onName gets it trimmed, and is asked again while it is empty or
-- taken (taken: unless allowed, the category's own name).
---@private
---@param title string
---@param text string
---@param yes string
---@param start string
---@param allowed? string
---@param takenText string A format for the name taken.
---@param onName fun(ctx: Context, name: string)
function managerProto:askName(title, text, yes, start, allowed, takenText, onName)
  local function ask(message, typed)
    nextDialog:Show(self.owner, {
      title = title, text = message, input = { text = typed, help = L:G("Category name") },
      buttons = {
        { text = L:G("Cancel"), onClick = function() end },
        { text = yes, style = "Primary", onClick = function(ctx, entered)
          local name = strtrim(entered or "")
          if name == "" then
            return true
          end
          if name ~= allowed and categories:DoesCategoryExist(name) then
            ask(format(takenText, name), name)
            return
          end
          onName(ctx, name)
        end },
      },
    })
  end
  ask(text, start)
end

-- AskNewCategory makes a new item list category, or starts a new search category (made once its
-- query is saved).
---@param ctx Context
---@param search boolean
function managerProto:AskNewCategory(ctx, search)
  local _ = ctx
  self:askName(search and L:G("New Search Category") or L:G("New Category"),
    search and L:G("Name the new search category:") or L:G("Name the new category:"), L:G("Create"), "", nil,
    L:G("A category named '%s' already exists."), function(nctx, name)
      if search then
        self.selected = nil
        self.draft = name
        self:ShowDetail()
        for _, row in ipairs(self.rows) do
          self:paintRow(row)
        end
        return
      end
      categories:CreateCategory(nctx, { name = name, itemList = {}, save = true })
      rederive(nctx)
      self:RefreshList(nctx)
      self:Select(nctx, name)
    end)
end

---@param ctx Context
function managerProto:AskRename(ctx)
  local _ = ctx
  local current = self.selected
  if current == nil then
    return
  end
  self:askName(L:G("Rename Category"), format(L:G("Rename the category '%s' to:"), current), L:G("Rename"), current,
    current, L:G("A category named '%s' may already exist."), function(rctx, name)
      if name == current then
        return
      end
      if not categories:RenameCategory(rctx, current, name) then
        nextDialog:Show(self.owner, {
          title = L:G("Rename Category"), text = format(L:G("A category named '%s' may already exist."), name),
          buttons = { { text = L:G("OK"), onClick = function() end } },
        })
        return
      end
      self:RefreshList(rctx)
      self:Select(rctx, name)
    end)
end

-- confirm asks a question over the window, doing it on the Danger button.
---@private
---@param title string
---@param text string
---@param yes string
---@param onYes fun(ctx: Context)
function managerProto:confirm(title, text, yes, onYes)
  nextDialog:Show(self.owner, {
    title = title, text = text,
    buttons = { { text = L:G("Cancel"), onClick = function() end }, { text = yes, style = "Danger", onClick = onYes } },
  })
end

---@param ctx Context
function managerProto:AskDelete(ctx)
  local _ = ctx
  local name = self.selected
  self:confirm(L:G("Delete Category"), format(L:G("Delete the category '%s'? This cannot be undone."), name),
    L:G("Delete"), function(dctx)
      categories:DeleteCategory(dctx, name)
      self:RefreshList(dctx)
      self:Select(dctx, nil)
    end)
end

---@param ctx Context
function managerProto:AskRemove(ctx)
  local _ = ctx
  local name = self.selected
  self:confirm(L:G("Remove Category"),
    format(L:G("Remove the category '%s' from the list? Its pin, visibility and tab are cleared."), name),
    L:G("Remove"), function(dctx)
      categories:DeleteCategory(dctx, name)
      self:RefreshList(dctx)
      self:Select(dctx, nil)
    end)
end

---@param width number
---@return number
function managerProto:Measure(width)
  local _ = width
  return style.Theme.Settings.Categories.Height
end

-- Place lays the manager out: its list (and the two new category buttons under it) on the left, the
-- chosen category's settings on the right.
---@param x number
---@param y number
---@param width number
---@param height number
function managerProto:Place(x, y, width, height)
  self.x, self.y, self.width, self.height = x, y, width, height
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local frame, pad = self.frame, K.Pad
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  frame:SetSize(width, height)
  self.fill:ClearAllPoints()
  self.fill:SetAllPoints(frame)
  local list = self.list
  list:ClearAllPoints()
  list:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
  list:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, pad)
  list:SetWidth(K.ListWidth)
  self.newSearch.frame:ClearAllPoints()
  self.newSearch.frame:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, 0)
  self.newCategory.frame:ClearAllPoints()
  self.newCategory.frame:SetPoint("BOTTOMLEFT", self.newSearch.frame, "TOPLEFT", 0, K.FieldGap / 2)
  self.listBox:ClearAllPoints()
  self.listBox:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  self.listBox:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 2 * B.Height + K.FieldGap * 1.5)
  local detail = self.detailFrame
  detail:ClearAllPoints()
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", K.Gap, 0)
  detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
  self:layoutDetail()
  frame:Show()
end

-- layoutDetail stacks the fields the chosen category has, its buttons along the bottom.
---@private
function managerProto:layoutDetail()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local detail = self.detailFrame
  local width = math.max(1, self.width - 2 * K.Pad - K.ListWidth - K.Gap)
  local gap = K.FieldGap
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
  self.title:SetWidth(width)
  local y = math.ceil(self.title:GetStringHeight()) + gap
  if self.info:IsShown() then
    self.info:ClearAllPoints()
    self.info:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    self.info:SetWidth(width)
    y = y + math.ceil(self.info:GetStringHeight()) + gap
  end
  -- field puts a field's name on the left and its control after it, LabelWidth in, when it shows.
  local function field(key, control, height)
    local l = self.labels[key]
    if not control:IsShown() then
      return
    end
    height = height or control:GetHeight()
    l:ClearAllPoints()
    l:SetPoint("LEFT", detail, "TOPLEFT", 0, -(y + height / 2))
    control:ClearAllPoints()
    control:SetPoint("LEFT", detail, "TOPLEFT", K.LabelWidth, -(y + height / 2))
    y = y + height + gap
  end
  if self.query.frame:IsShown() then
    self.labels.query:ClearAllPoints()
    self.labels.query:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    y = y + math.ceil(self.labels.query:GetStringHeight()) + gap / 2
    self.query.frame:ClearAllPoints()
    self.query.frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    self.query.frame:SetWidth(width)
    self.query.frame:SetHeight(K.QueryHeight)
    y = y + K.QueryHeight + gap
  end
  field("priority", self.priority.frame)
  field("groupBy", self.groupBy.frame)
  field("color", self.swatch.frame, B.Height)
  self.resetColor.frame:ClearAllPoints()
  self.resetColor.frame:SetPoint("LEFT", self.swatch.frame, "RIGHT", gap, 0)
  field("shown", self.shown.frame)
  local bottom = B.Height + gap
  self.warning:ClearAllPoints()
  self.warning:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, bottom)
  self.warning:SetWidth(width)
  if self.itemDrop:IsShown() then
    self.labels.items:ClearAllPoints()
    self.labels.items:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    y = y + math.ceil(self.labels.items:GetStringHeight()) + gap / 2
    self.itemDrop:ClearAllPoints()
    self.itemDrop:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    self.itemDrop:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, bottom + gap)
    self.itemBox:ClearAllPoints()
    self.itemBox:SetPoint("TOPLEFT", self.itemDrop, "TOPLEFT", 2, -2)
    self.itemBox:SetPoint("BOTTOMRIGHT", self.itemDrop, "BOTTOMRIGHT", -2, 2)
  end
  local buttons = {}
  for _, b in ipairs({ self.save, self.rename, self.delete, self.remove }) do
    if b.frame:IsShown() then
      table.insert(buttons, b)
    end
  end
  local previous
  for _, b in ipairs(buttons) do
    b.frame:ClearAllPoints()
    if previous == nil then
      b.frame:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    else
      b.frame:SetPoint("LEFT", previous.frame, "RIGHT", gap, 0)
    end
    previous = b
  end
end
