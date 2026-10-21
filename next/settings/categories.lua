local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Search: AceModule
local search = addon:GetModule('Search')

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

-- NextSettingsCategories is the Categories page (next-settings.md §5, category-lifecycle.md §6): every
-- category defined once, one kind of category (a rule, items placed by hand, or both). A wide row: the
-- categories down its left (yours, then the plugins', each by name, filtered by what is typed), and the
-- chosen one's settings on its right: the bags it is used in, priority, group by, color, its rule (with
-- how many items in the bags it matches, as it is typed), the items placed in it by hand, and what it
-- holds in the bags now, with where the rest of what it claims shows. A plugin's category can be used in
-- bags, colored and prioritized; its rule and items are the plugin's.
---@class NextSettingsCategories: AceModule
---@field all NextCategoryEditor[]
---@field pendingShow? string A category to choose the next time the page shows.
---@field pendingRule? string A search to make a new category of the next time the page shows.
local editor = addon:NewModule('NextSettingsCategories')

-- A category without a color is drawn in Warcraft gold (the section titles' default).
local GOLD = { 1, 0.82, 0, 1 }

local GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY
-- The group by choices, in the dropdown's order.
local GROUP_BY_NAMES = { L:G("None"), L:G("Type"), L:G("Subtype"), L:G("Expansion") }
local GROUP_BY_OF_NAME = {
  [L:G("None")] = GROUP_BY.NONE, [L:G("Type")] = GROUP_BY.TYPE,
  [L:G("Subtype")] = GROUP_BY.SUBTYPE, [L:G("Expansion")] = GROUP_BY.EXPANSION,
}
local NAME_OF_GROUP_BY = {
  [GROUP_BY.NONE] = L:G("None"), [GROUP_BY.TYPE] = L:G("Type"),
  [GROUP_BY.SUBTYPE] = L:G("Subtype"), [GROUP_BY.EXPANSION] = L:G("Expansion"),
}

-- The messages a bag kind's committed sweep sends (data/items.lua Phase11): what it holds changed.
local READ = { 'items/RefreshBackpack/Done', 'items/RefreshBank/Done', 'items/RefreshGuildBank/Done' }

---@class NextCategoryEditorRow
---@field frame Button
---@field fill Texture
---@field hover Texture
---@field indicator Texture
---@field dot Texture
---@field label FontString
---@field detail FontString
---@field entry? table
---@field hovered boolean

---@class NextCategoryEditor
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field bags fun(): SettingBag[] The bags the settings show.
---@field entries table[] { header = true, title } or { name }
---@field rows NextCategoryEditorRow[]
---@field selected? string
---@field itemRows ItemRow[]
---@field bagToggles table<BagKind, NextToggleFrame>
---@field bagLabels table<BagKind, FontString>
---@field icons Texture[]
local editorProto = {}
addon:GetModule('Perf'):RegisterPrototype(editorProto, 'NextCategoryEditor')

editor.all = {}

-- Init forgets a category or search waiting for the page.
function editor:Init()
  self.pendingShow = nil
  self.pendingRule = nil
end

---@param ctx? Context
function editor:ApplyStyle(ctx)
  local _ = ctx
  for _, block in ipairs(self.all) do
    block:Style()
  end
end

-- Show chooses a category the next time the page shows (a bag's Categories tab links here).
---@param name string
function editor:Show(name)
  self.pendingShow = name
end

-- NewFromSearch makes a new category whose rule is a search, asking for its name, the next time the
-- page shows (the search box's Enter to Make Category).
---@param query string
function editor:NewFromSearch(query)
  self.pendingRule = query
end

-- rederive recalculates the bags with a fresh layout, as every category change does
-- (refresh-scheduler.md §10).
---@param ctx Context
local function rederive(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

---@param n number
---@param one string
---@param many string
---@return string
local function count(n, one, many)
  return format(n == 1 and one or many, n)
end

---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@param bags fun(): SettingBag[]
---@return NextCategoryEditor
function editor:Create(parent, owner, bags)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextCategoryEditor
  local block = setmetatable({
    frame = frame, wide = true, owner = owner, bags = bags, entries = {}, rows = {}, itemRows = {},
    bagToggles = {}, bagLabels = {}, icons = {},
  }, { __index = editorProto })
  block:buildList()
  block:buildDetail()
  table.insert(self.all, block)
  sonataNext:RegisterWidget(self)
  events:RegisterMessage('categories/Changed', function(ctx)
    if frame:IsVisible() then
      block:RefreshList(ctx)
      block:ShowSummary()
    end
  end)
  for _, message in ipairs(READ) do
    events:RegisterMessage(message, function()
      if frame:IsVisible() then
        block:ShowSummary()
      end
    end)
  end
  block:Style()
  return block
end

---@private
function editorProto:buildList()
  local frame = self.frame
  self.fill = frame:CreateTexture(nil, "BACKGROUND")
  local list = CreateFrame("Frame", nil, frame)
  self.list = list
  self.filter = nextInput:Create(list, {
    help = L:G("Find a category"),
    onChange = function() self:RefreshList() end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  local box = CreateFrame("Frame", nil, list, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(38)
  box:Init(view)
  self.listBar = nextScrollBar:Create(box)
  self.listBar:Bind(box)
  self.listBox, self.listContent = box, content
  self.newCategory = nextButton:Create(list, {
    text = L:G("New Category"), width = style.Theme.Settings.Categories.ListWidth,
    onClick = function(ctx) self:AskNewCategory(ctx) end,
  })
end

---@private
function editorProto:buildDetail()
  local K = style.Theme.Settings.Categories
  local detail = CreateFrame("Frame", nil, self.frame)
  self.detailFrame = detail
  self.title = style:CreateText(detail, K.TitleFont)
  self.title:SetJustifyH("LEFT")
  self.title:SetWordWrap(false)
  self.rename = nextButton:Create(detail, { text = L:G("Rename"), onClick = function(ctx) self:AskRename(ctx) end })
  self.delete = nextButton:Create(detail, {
    text = L:G("Delete"), style = "Danger", onClick = function(ctx) self:AskDelete(ctx) end,
  })
  self.info = style:CreateText(detail, K.HintFont)
  self.info:SetJustifyH("LEFT")
  self.info:SetWordWrap(true)
  self.labels = {}
  local function label(key, text)
    local l = style:CreateText(detail, K.LabelFont)
    l:SetJustifyH("LEFT")
    l:SetText(text)
    self.labels[key] = l
  end
  label("bags", L:G("Used In"))
  label("priority", L:G("Priority"))
  self.priority = nextInput:Create(detail, {
    width = 50, numeric = true, maxLetters = 2, commitOnBlur = true,
    onEnter = function(ctx, text) self:SavePriority(ctx, text) end,
  })
  self.priorityHint = style:CreateText(detail, K.HintFont)
  self.priorityHint:SetText(L:G("Lower wins when an item fits more than one category."))
  label("groupBy", L:G("Group By"))
  self.groupBy = nextDropdown:Create(detail, {
    items = GROUP_BY_NAMES, width = 130,
    get = function()
      local filter = self:chosen()
      return NAME_OF_GROUP_BY[filter and filter.groupBy or GROUP_BY.NONE]
    end,
    onChange = function(ctx, name) self:update(ctx, { groupBy = GROUP_BY_OF_NAME[name] or GROUP_BY.NONE }) end,
  })
  label("color", L:G("Color"))
  self.swatch = nextSwatch:Create(detail, {
    color = GOLD,
    onChange = function(ctx, c) self:update(ctx, { color = { c[1], c[2], c[3] } }) end,
  })
  self.resetColor = nextButton:Create(detail, {
    text = L:G("Reset Color"), style = "Link",
    onClick = function(ctx)
      self.swatch:SetColor(GOLD)
      self:update(ctx, { color = false })
    end,
  })
  label("rule", L:G("Rule"))
  self.rule = nextInput:CreateArea(detail, {
    height = K.QueryHeight, help = L:G("A search, as in the bags' search box: its matches belong here."),
    onChange = function() self:CheckRule() end,
  })
  self.ruleCount = style:CreateText(detail, K.HintFont)
  self.ruleCount:SetJustifyH("LEFT")
  self.applyRule = nextButton:Create(detail, {
    text = L:G("Apply Rule"), style = "Primary", onClick = function(ctx) self:ApplyRule(ctx) end,
  })
  label("items", L:G("Placed Here (drop an item)"))
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
  local function dropped(ctx, _, button)
    if button == nil or (button == "LeftButton" and CursorHasItem()) then
      self:DropItem(ctx)
    end
  end
  addon.SetScript(drop, "OnReceiveDrag", function(ctx) self:DropItem(ctx) end)
  addon.SetScript(drop, "OnMouseUp", dropped)
  addon.SetScript(itemBox, "OnReceiveDrag", function(ctx) self:DropItem(ctx) end)
  addon.HookScript(itemBox, "OnMouseUp", dropped)
  self.inBags = style:CreateText(detail, K.TextFont)
  self.inBags:SetJustifyH("LEFT")
  self.elsewhere = style:CreateText(detail, K.HintFont)
  self.elsewhere:SetJustifyH("LEFT")
  self.elsewhere:SetWordWrap(true)
end

-- toggleFor returns the switch for a bag, made the first time it is needed.
---@private
---@param bag SettingBag
---@return NextToggleFrame
function editorProto:toggleFor(bag)
  local toggle = self.bagToggles[bag.kind]
  if toggle == nil then
    toggle = nextToggle:Create(self.detailFrame, {
      onChange = function(ctx, on) self:update(ctx, { enabled = { [bag.kind] = on } }) end,
    })
    local text = style:CreateText(self.detailFrame, style.Theme.Settings.Categories.TextFont)
    self.bagToggles[bag.kind], self.bagLabels[bag.kind] = toggle, text
  end
  self.bagLabels[bag.kind]:SetText(L:G(bag.name))
  return toggle
end

-- Style draws the page from the theme and lays it out again.
function editorProto:Style()
  local K = style.Theme.Settings.Categories
  controls:Paint(self.fill, K.Fill)
  style:SetFont(self.title, K.TitleFont)
  style:SetFont(self.info, K.HintFont)
  style:SetFont(self.priorityHint, K.HintFont)
  style:SetFont(self.ruleCount, K.HintFont)
  style:SetFont(self.inBags, K.TextFont)
  style:SetFont(self.elsewhere, K.HintFont)
  for _, l in pairs(self.labels) do
    style:SetFont(l, K.LabelFont)
  end
  for _, l in pairs(self.bagLabels) do
    style:SetFont(l, K.TextFont)
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

-- chosen returns the chosen category.
---@private
---@return CustomCategoryFilter?
function editorProto:chosen()
  return self.selected and categories:GetCategoryByName(self.selected) or nil
end

-- isPlugins says whether a category is a plugin's: not saved by the player.
---@param filter? CustomCategoryFilter
---@return boolean
local function isPlugins(filter)
  return filter ~= nil and filter.save ~= true
end

-- RowFor returns the list row of a category.
---@param name string
---@return NextCategoryEditorRow?
function editorProto:RowFor(name)
  for i, entry in ipairs(self.entries) do
    if entry.name == name then
      return self.rows[i]
    end
  end
  return nil
end

-- describe says what is in a category and its priority, for its list row.
---@param filter CustomCategoryFilter
---@return string
local function describeCategory(filter)
  local n = 0
  for _ in pairs(filter.itemList or {}) do
    n = n + 1
  end
  local rule = categories:RuleOf(filter) ~= nil
  local what
  if rule and n > 0 then
    what = L:G("Rule and ") .. count(n, L:G("%d item"), L:G("%d items"))
  elseif rule then
    what = L:G("Rule")
  elseif n > 0 then
    what = count(n, L:G("%d item"), L:G("%d items"))
  else
    what = L:G("Nothing in it yet")
  end
  return what .. " · " .. format(L:G("Priority %d"), filter.priority or 10)
end

-- RefreshList lists the categories again: yours, then the plugins' (not a group by's sub-categories),
-- each by name, those whose name has the filter's text.
---@param ctx? Context
function editorProto:RefreshList(ctx)
  local _ = ctx
  local needle = strtrim(self.filter:GetText() or ""):lower()
  local yours, plugins = {}, {}
  for name, filter in pairs(categories:GetAllCategories()) do
    if not filter.isGroupBySubcategory and (needle == "" or name:lower():find(needle, 1, true)) then
      table.insert(isPlugins(filter) and plugins or yours, name)
    end
  end
  table.sort(yours)
  table.sort(plugins)
  local entries = {}
  for _, group in ipairs({ { L:G("Your Categories"), yours }, { L:G("From Plugins"), plugins } }) do
    if #group[2] > 0 then
      table.insert(entries, { header = true, title = group[1] })
      for _, name in ipairs(group[2]) do
        table.insert(entries, { name = name })
      end
    end
  end
  self.entries = entries
  self:layoutList()
end

-- row returns the i-th list row, made the first time it is needed.
---@private
---@param i number
---@return NextCategoryEditorRow
function editorProto:row(i)
  local row = self.rows[i]
  if row ~= nil then
    return row
  end
  local K = style.Theme.Settings.Categories
  local frame = CreateFrame("Button", nil, self.listContent)
  frame:RegisterForClicks("LeftButtonUp")
  row = {
    frame = frame,
    fill = frame:CreateTexture(nil, "BACKGROUND"),
    hover = frame:CreateTexture(nil, "BACKGROUND", nil, 1),
    indicator = frame:CreateTexture(nil, "ARTWORK"),
    dot = frame:CreateTexture(nil, "ARTWORK"),
    label = style:CreateText(frame, K.Font),
    detail = style:CreateText(frame, K.NoteFont),
    hovered = false,
  }
  row.fill:SetAllPoints(frame)
  row.hover:SetAllPoints(frame)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  row.detail:SetJustifyH("LEFT")
  row.detail:SetWordWrap(false)
  addon.SetScript(frame, "OnClick", function(ctx)
    if row.entry and row.entry.name then
      self:Select(ctx, row.entry.name)
    end
  end)
  addon.SetScript(frame, "OnEnter", function()
    row.hovered = true
    self:paintRow(row)
  end)
  addon.SetScript(frame, "OnLeave", function()
    row.hovered = false
    self:paintRow(row)
  end)
  self.rows[i] = row
  return row
end

-- layoutList places the list's rows, headings GroupHeight tall and categories RowHeight tall.
---@private
function editorProto:layoutList()
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
    if entry.header then
      row.label:SetText(string.upper(entry.title))
      row.detail:SetText("")
    else
      local filter = categories:GetCategoryByName(entry.name)
      row.label:SetText(entry.name)
      row.detail:SetText(filter and describeCategory(filter) or "")
      local c = filter and filter.color or GOLD
      row.dot:SetColorTexture(c[1], c[2], c[3], 1)
    end
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
---@param row NextCategoryEditorRow
function editorProto:paintRow(row)
  local K = style.Theme.Settings.Categories
  local entry = row.entry
  row.label:ClearAllPoints()
  row.detail:ClearAllPoints()
  if entry == nil or entry.header then
    style:SetFont(row.label, K.GroupFont)
    row.label:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", K.Indent, 4)
    row.fill:Hide()
    row.hover:Hide()
    row.indicator:Hide()
    row.dot:Hide()
    row.detail:Hide()
    return
  end
  local chosen = entry.name == self.selected
  style:SetFont(row.label, K.Font)
  style:SetFont(row.detail, K.NoteFont)
  row.dot:ClearAllPoints()
  row.dot:SetPoint("TOPLEFT", row.frame, "TOPLEFT", K.Indent, -(K.RowHeight / 2 - 9))
  row.dot:SetSize(6, 6)
  row.dot:Show()
  row.label:SetPoint("BOTTOMLEFT", row.frame, "LEFT", K.Indent + 12, 1)
  row.label:SetPoint("RIGHT", row.frame, "RIGHT", -K.Indent, 0)
  row.detail:SetPoint("TOPLEFT", row.frame, "LEFT", K.Indent + 12, -2)
  row.detail:SetPoint("RIGHT", row.frame, "RIGHT", -K.Indent, 0)
  row.detail:Show()
  controls:Paint(row.fill, chosen and K.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and K.HoverFill or false)
  row.indicator:ClearAllPoints()
  row.indicator:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
  row.indicator:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
  row.indicator:SetWidth(K.Indicator.Width)
  controls:Paint(row.indicator, chosen and { Color = K.Indicator.Color } or false)
end

-- firstCategory returns the first category the list shows.
---@private
---@return string?
function editorProto:firstCategory()
  for _, entry in ipairs(self.entries) do
    if entry.name then
      return entry.name
    end
  end
  return nil
end

-- Refresh lists the categories and shows the chosen one again (the page shows): a category asked for
-- (Show) is chosen, else the one chosen if it still exists, else the first; a search asked to become a
-- category (NewFromSearch) asks for its name.
---@param ctx? Context
function editorProto:Refresh(ctx)
  self:RefreshList(ctx)
  local wanted = editor.pendingShow
  editor.pendingShow = nil
  if wanted and categories:GetCategoryByName(wanted) then
    self.selected = wanted
  elseif self.selected == nil or categories:GetCategoryByName(self.selected) == nil then
    self.selected = self:firstCategory()
  end
  self:Select(ctx, self.selected)
  local rule = editor.pendingRule
  editor.pendingRule = nil
  if rule then
    self:AskNewCategory(ctx or context:New('NextSettingsCategories_Search'), rule)
  end
end

-- Select chooses a category and shows its settings.
---@param ctx? Context
---@param name? string
function editorProto:Select(ctx, name)
  local _ = ctx
  self.selected = name
  self:ShowDetail()
  for _, row in ipairs(self.rows) do
    self:paintRow(row)
  end
end

-- ShowDetail shows the chosen category's settings.
function editorProto:ShowDetail()
  local filter = self:chosen()
  local plugins = isPlugins(filter)
  self.title:SetText(self.selected or L:G("No categories yet: make one."))
  self.info:SetText(plugins and L:G("A plugin made this category: its rule and items are the plugin's.") or "")
  local shown = {}
  for _, bag in ipairs(self.bags()) do
    local toggle = self:toggleFor(bag)
    toggle:SetChecked(filter ~= nil and filter.enabled ~= nil and filter.enabled[bag.kind] ~= false)
    shown[bag.kind] = true
  end
  for kind, toggle in pairs(self.bagToggles) do
    local on = filter ~= nil and shown[kind] == true
    toggle.frame:SetShown(on)
    self.bagLabels[kind]:SetShown(on)
  end
  if filter then
    self.priority:SetText(tostring(filter.priority or 10))
    local c = filter.color
    self.swatch:SetColor(c and { c[1], c[2], c[3], 1 } or GOLD)
    self.groupBy:Refresh()
    self.rule:SetText(categories:RuleOf(filter) or "")
  end
  self:showParts(filter, plugins)
  self:CheckRule()
  if filter and not plugins then
    self:LoadItems()
  else
    self:ReleaseItems()
  end
  self:ShowSummary()
  if self.width then
    self:layoutDetail()
  end
end

-- showParts shows the parts a category has: none without one; a plugin's has no rule, items, group by,
-- rename or delete.
---@private
---@param filter? CustomCategoryFilter
---@param plugins boolean
function editorProto:showParts(filter, plugins)
  local any = filter ~= nil
  local yours = any and not plugins
  self.info:SetShown(plugins)
  for _, part in ipairs({ self.labels.bags, self.labels.priority, self.priority.frame, self.priorityHint,
    self.labels.color, self.swatch.frame, self.resetColor.frame, self.inBags, self.elsewhere }) do
    part:SetShown(any)
  end
  for _, part in ipairs({ self.rename.frame, self.delete.frame, self.labels.groupBy, self.groupBy.frame,
    self.labels.rule, self.rule.frame, self.ruleCount, self.applyRule.frame, self.labels.items, self.itemDrop }) do
    part:SetShown(yours)
  end
  for _, icon in ipairs(self.icons) do
    if not any then
      icon:Hide()
    end
  end
end

-- update changes the chosen category (categories:UpdateCategory recalculates the bags).
---@private
---@param ctx Context
---@param fields table
function editorProto:update(ctx, fields)
  if self.selected then
    categories:UpdateCategory(ctx, self.selected, fields)
  end
end

-- SavePriority saves the priority entered (the field takes two digits: 0 to 99); nothing shows the
-- priority again.
---@param ctx Context
---@param text string
function editorProto:SavePriority(ctx, text)
  local filter = self:chosen()
  local n = tonumber(text)
  if filter == nil then
    return
  end
  if n == nil then
    self.priority:SetText(tostring(filter.priority or 10))
    return
  end
  if n ~= (filter.priority or 10) then
    self:update(ctx, { priority = n })
  end
end

-- matchesOf returns the committed items of the bags the settings show a search matches, or nil and the
-- error for a search with a mistake.
---@private
---@param query string
---@return table<string, ItemData>?
function editorProto:matchesOf(query)
  local ok, found = pcall(search.Search, search, query)
  if not ok then
    return nil
  end
  local list = {}
  for _, bag in ipairs(self.bags()) do
    local slotInfo = items.slotInfo and items.slotInfo[bag.kind]
    for slotkey, data in pairs(slotInfo and slotInfo.itemsBySlotKey or {}) do
      if found[slotkey] then
        list[slotkey] = data
      end
    end
  end
  return list
end

-- CheckRule says, as the rule is typed, how many items in the bags it matches, and turns Apply Rule on
-- when it changed and has no mistake.
function editorProto:CheckRule()
  local filter = self:chosen()
  local text = strtrim(self.rule:GetText() or "")
  local valid = true
  if text == "" then
    self.ruleCount:SetText(L:G("No rule: only the items placed here."))
  else
    local found = self:matchesOf(text)
    if found == nil then
      valid = false
      self.ruleCount:SetText(L:G("This search has a mistake."))
    else
      local n = 0
      for _ in pairs(found) do
        n = n + 1
      end
      self.ruleCount:SetText(count(n, L:G("Matches %d item in your bags."), L:G("Matches %d items in your bags.")))
    end
  end
  local saved = filter and categories:RuleOf(filter) or ""
  self.applyRule:SetEnabled(filter ~= nil and valid and text ~= saved)
end

-- ApplyRule saves the rule typed (none for an empty one).
---@param ctx Context
function editorProto:ApplyRule(ctx)
  if not self.applyRule.frame:IsEnabled() then
    return
  end
  self:update(ctx, { rule = strtrim(self.rule:GetText() or "") })
  self:CheckRule()
end

-- ShowSummary shows what the chosen category holds in the bags now: what shows in it (its group by's
-- sub-categories too), by bag, with up to Icons icons; and where what else it claims (its rule's
-- matches, the items placed in it) shows instead.
function editorProto:ShowSummary()
  local K = style.Theme.Settings.Categories
  local filter = self:chosen()
  local shownIcons = 0
  if filter then
    local name = self.selected
    local prefix = name .. " - "
    local rule = categories:RuleOf(filter)
    local matched = rule and self:matchesOf(rule) or {}
    local placed = filter.itemList or {}
    local total, parts, elsewhere = 0, {}, {}
    for _, bag in ipairs(self.bags()) do
      local slotInfo = items.slotInfo and items.slotInfo[bag.kind]
      local here = 0
      for slotkey, data in pairs(slotInfo and slotInfo.itemsBySlotKey or {}) do
        if not data.isItemEmpty and data.itemInfo then
          local category = data.itemInfo.category or ""
          if category == name or category:sub(1, #prefix) == prefix then
            here = here + 1
            if shownIcons < K.Icons then
              shownIcons = shownIcons + 1
              local icon = self.icons[shownIcons]
              if icon == nil then
                icon = self.detailFrame:CreateTexture(nil, "ARTWORK")
                self.icons[shownIcons] = icon
              end
              icon:SetTexture(data.itemInfo.itemIcon)
              icon:Show()
            end
          elseif matched[slotkey] or placed[data.itemInfo.itemID] then
            elsewhere[category] = (elsewhere[category] or 0) + 1
          end
        end
      end
      if here > 0 then
        table.insert(parts, format("%s %d", L:G(bag.name), here))
        total = total + here
      end
    end
    if total == 0 then
      self.inBags:SetText(L:G("In your bags now: none."))
    else
      self.inBags:SetText(format(L:G("In your bags now: %d (%s)."), total, table.concat(parts, ", ")))
    end
    local names = {}
    for category in pairs(elsewhere) do
      table.insert(names, category)
    end
    table.sort(names, function(a, b)
      if elsewhere[a] ~= elsewhere[b] then
        return elsewhere[a] > elsewhere[b]
      end
      return a < b
    end)
    local list = {}
    for _, category in ipairs(names) do
      table.insert(list, format(L:G("%d in %s"), elsewhere[category], category))
    end
    self.elsewhere:SetText(#list > 0 and format(L:G("Shown elsewhere: %s."), table.concat(list, ", ")) or "")
  end
  for i = shownIcons + 1, #self.icons do
    self.icons[i]:Hide()
  end
  if self.width then
    self:layoutIcons()
  end
end

-- ReleaseItems gives the item rows back.
---@private
function editorProto:ReleaseItems()
  local ctx = context:New('NextSettingsCategories_Items')
  for _, row in ipairs(self.itemRows) do
    row.rowButton:SetScript("OnMouseDown", nil)
    row:Release(ctx)
  end
  self.itemRows = {}
end

-- LoadItems lists the items placed in the chosen category, an item row each; a right click on one
-- offers to take it out.
function editorProto:LoadItems()
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
            items = { { text = L:G("Take Out") } },
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

-- DropItem places the item on the cursor in the chosen category.
---@param ctx Context
function editorProto:DropItem(ctx)
  local filter = self:chosen()
  if filter == nil or not CursorHasItem() then
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
  self:ShowSummary()
end

---@param ctx Context
---@param id number
function editorProto:RemoveItem(ctx, id)
  categories:RemoveItemFromCategory(id, self.selected)
  rederive(ctx)
  self:LoadItems()
  self:ShowSummary()
end

-- askName asks for a category name; onName gets it trimmed, and is asked again while it is empty or
-- taken (taken: unless allowed, the category's own name).
---@private
---@param title string
---@param text string
---@param yes string
---@param start string
---@param allowed? string
---@param onName fun(ctx: Context, name: string)
function editorProto:askName(title, text, yes, start, allowed, onName)
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
            ask(format(L:G("A category named '%s' already exists."), name), name)
            return
          end
          onName(ctx, name)
        end },
      },
    })
  end
  ask(text, start)
end

-- AskNewCategory makes a new category (with a rule when given one), chosen.
---@param ctx Context
---@param rule? string
function editorProto:AskNewCategory(ctx, rule)
  local _ = ctx
  self:askName(L:G("New Category"), L:G("Name the new category:"), L:G("Create"), "", nil, function(nctx, name)
    local filter = { name = name, itemList = {}, save = true }
    if rule and strtrim(rule) ~= "" then
      filter.searchCategory = { query = strtrim(rule) }
    end
    categories:CreateCategory(nctx, filter)
    rederive(nctx)
    self:RefreshList(nctx)
    self:Select(nctx, name)
  end)
end

---@param ctx Context
function editorProto:AskRename(ctx)
  local _ = ctx
  local current = self.selected
  if current == nil then
    return
  end
  self:askName(L:G("Rename Category"), format(L:G("Rename the category '%s' to:"), current), L:G("Rename"), current,
    current, function(rctx, name)
      if name == current then
        return
      end
      if not categories:RenameCategory(rctx, current, name) then
        nextDialog:Show(self.owner, {
          title = L:G("Rename Category"), text = format(L:G("The category '%s' could not be renamed."), current),
          buttons = { { text = L:G("OK"), onClick = function() end } },
        })
        return
      end
      self:RefreshList(rctx)
      self:Select(rctx, name)
    end)
end

---@param ctx Context
function editorProto:AskDelete(ctx)
  local _ = ctx
  local name = self.selected
  nextDialog:Show(self.owner, {
    title = L:G("Delete Category"), text = format(L:G("Delete the category '%s'? This cannot be undone."), name),
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = L:G("Delete"), style = "Danger", onClick = function(dctx)
        categories:DeleteCategory(dctx, name)
        self.selected = nil
        self:RefreshList(dctx)
        self:Select(dctx, self:firstCategory())
      end },
    },
  })
end

---@param width number
---@return number
function editorProto:Measure(width)
  local _ = width
  return style.Theme.Settings.Categories.Height
end

-- Place lays the page out: the list (its filter above, New Category under it) on the left, the chosen
-- category's settings on the right.
---@param x number
---@param y number
---@param width number
---@param height number
function editorProto:Place(x, y, width, height)
  self.x, self.y, self.width, self.height = x, y, width, height
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local I = controls:Theme("Input")
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
  self.filter.frame:ClearAllPoints()
  self.filter.frame:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  self.filter.frame:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
  self.newCategory.frame:ClearAllPoints()
  self.newCategory.frame:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, 0)
  self.listBox:ClearAllPoints()
  self.listBox:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(I.Height + K.FieldGap))
  self.listBox:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, B.Height + K.FieldGap)
  local detail = self.detailFrame
  detail:ClearAllPoints()
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", K.Gap, 0)
  detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
  self:layoutDetail()
  frame:Show()
end

-- layoutDetail stacks the chosen category's settings: its name with Rename and Delete; a plugin's note;
-- the bags it is used in; priority; group by; color; the rule with its count and Apply Rule; the items
-- placed here, taking the room left; what it holds in the bags now at the bottom.
---@private
function editorProto:layoutDetail()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local detail = self.detailFrame
  local width = math.max(1, self.width - 2 * K.Pad - K.ListWidth - K.Gap)
  local gap = K.FieldGap
  self.delete.frame:ClearAllPoints()
  self.delete.frame:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, 0)
  self.rename.frame:ClearAllPoints()
  self.rename.frame:SetPoint("RIGHT", self.delete.frame, "LEFT", -gap, 0)
  self.title:ClearAllPoints()
  self.title:SetPoint("LEFT", detail, "TOPLEFT", 0, -B.Height / 2)
  self.title:SetPoint("RIGHT", self.rename.frame, "LEFT", -gap, 0)
  local y = B.Height + gap
  if self.info:IsShown() then
    self.info:ClearAllPoints()
    self.info:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    self.info:SetWidth(width)
    y = y + math.ceil(self.info:GetStringHeight()) + gap
  end
  -- row puts a field's name on the left of a line height tall, and returns where its controls start.
  local function row(key, height)
    local l = self.labels[key]
    l:ClearAllPoints()
    l:SetPoint("LEFT", detail, "TOPLEFT", 0, -(y + height / 2))
    return y + height / 2
  end
  if self.labels.bags:IsShown() then
    local middle = row("bags", B.Height)
    local x = K.LabelWidth
    for _, bag in ipairs(self.bags()) do
      local toggle, text = self.bagToggles[bag.kind], self.bagLabels[bag.kind]
      if toggle and toggle.frame:IsShown() then
        toggle.frame:ClearAllPoints()
        toggle.frame:SetPoint("LEFT", detail, "TOPLEFT", x, -middle)
        text:ClearAllPoints()
        text:SetPoint("LEFT", toggle.frame, "RIGHT", 6, 0)
        x = x + toggle.frame:GetWidth() + 6 + math.ceil(text:GetStringWidth()) + 2 * gap
      end
    end
    y = y + B.Height + gap
    local pmiddle = row("priority", B.Height)
    self.priority.frame:ClearAllPoints()
    self.priority.frame:SetPoint("LEFT", detail, "TOPLEFT", K.LabelWidth, -pmiddle)
    self.priorityHint:ClearAllPoints()
    self.priorityHint:SetPoint("LEFT", self.priority.frame, "RIGHT", gap, 0)
    self.priorityHint:SetPoint("RIGHT", detail, "RIGHT", 0, 0)
    y = y + B.Height + gap
  end
  if self.groupBy.frame:IsShown() then
    local gmiddle = row("groupBy", B.Height)
    self.groupBy.frame:ClearAllPoints()
    self.groupBy.frame:SetPoint("LEFT", detail, "TOPLEFT", K.LabelWidth, -gmiddle)
    y = y + B.Height + gap
  end
  if self.swatch.frame:IsShown() then
    local cmiddle = row("color", B.Height)
    self.swatch.frame:ClearAllPoints()
    self.swatch.frame:SetPoint("LEFT", detail, "TOPLEFT", K.LabelWidth, -cmiddle)
    self.resetColor.frame:ClearAllPoints()
    self.resetColor.frame:SetPoint("LEFT", self.swatch.frame, "RIGHT", gap, 0)
    y = y + B.Height + gap
  end
  if self.rule.frame:IsShown() then
    self.labels.rule:ClearAllPoints()
    self.labels.rule:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    y = y + math.ceil(self.labels.rule:GetStringHeight()) + gap / 2
    self.rule.frame:ClearAllPoints()
    self.rule.frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    self.rule.frame:SetSize(width, K.QueryHeight)
    y = y + K.QueryHeight + gap / 2
    self.applyRule.frame:ClearAllPoints()
    self.applyRule.frame:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -y)
    self.ruleCount:ClearAllPoints()
    self.ruleCount:SetPoint("LEFT", detail, "TOPLEFT", 0, -(y + B.Height / 2))
    self.ruleCount:SetPoint("RIGHT", self.applyRule.frame, "LEFT", -gap, 0)
    y = y + B.Height + gap
  end
  -- What it holds in the bags now, at the bottom: its line, its icons, where the rest shows.
  local bottom = 0
  if self.inBags:IsShown() then
    self.elsewhere:ClearAllPoints()
    self.elsewhere:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    self.elsewhere:SetWidth(width)
    bottom = math.ceil(self.elsewhere:GetStringHeight()) + gap / 2
    self.iconTop = bottom + K.IconSize
    self.inBags:ClearAllPoints()
    self.inBags:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, self.iconTop + gap / 2)
    self.inBags:SetWidth(width)
    bottom = self.iconTop + gap / 2 + math.ceil(self.inBags:GetStringHeight()) + gap
    self:layoutIcons()
  end
  if self.itemDrop:IsShown() then
    self.labels.items:ClearAllPoints()
    self.labels.items:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    y = y + math.ceil(self.labels.items:GetStringHeight()) + gap / 2
    self.itemDrop:ClearAllPoints()
    self.itemDrop:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    self.itemDrop:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, bottom)
    self.itemBox:ClearAllPoints()
    self.itemBox:SetPoint("TOPLEFT", self.itemDrop, "TOPLEFT", 2, -2)
    self.itemBox:SetPoint("BOTTOMRIGHT", self.itemDrop, "BOTTOMRIGHT", -2, 2)
  end
end

-- layoutIcons lines up the icons of what the chosen category holds, above where the rest shows.
---@private
function editorProto:layoutIcons()
  local K = style.Theme.Settings.Categories
  for i, icon in ipairs(self.icons) do
    icon:ClearAllPoints()
    icon:SetSize(K.IconSize, K.IconSize)
    icon:SetPoint("BOTTOMLEFT", self.detailFrame, "BOTTOMLEFT", (i - 1) * (K.IconSize + K.IconGap), self.iconTop or 0)
  end
end
