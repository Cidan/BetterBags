local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Search: AceModule
local search = addon:GetModule('Search')

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

---@class NextItemGrid: AceModule
local nextItemGrid = addon:GetModule('NextItemGrid')

---@class NextSettings: AceModule
local settings = addon:GetModule('NextSettings')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSettingsCategories is the Categories page (next-settings.md §5, category-lifecycle.md §6), where
-- every category is defined once: one kind of category, a rule, items added by hand, or both. The page
-- shows its own list in the window's sidebar (pages.lua sidebar): your categories, then the plugins',
-- filtered by name, New Category under them. The chosen category's name and what is in it are the
-- page's heading, Rename and Delete its buttons in the header, and four tabs show it:
-- - Settings: the bags it is used in, its priority, group by and color, and what of your bags shows in
--   it now, as items.
-- - Search Rule: its search, Apply Search Rule, and the Search Results (counted beside their name as it
--   is typed) as items, those showing in another category saying where.
-- - Automation: what it does with your backpack's items on its own (automation.md): two switches, at
--   most one on, to sell them at merchants or destroy them on command.
-- - Added Items: the items added to it by hand, as a grid that holds thousands (NextItemGrid), filtered
--   by name; an item dropped anywhere on it is added, a right click removes one, Remove All asks first.
-- A plugin's category can be used in bags, colored, prioritized and automated; its rule (when it has one)
-- and its items show read-only.
---@class NextSettingsCategories: AceModule
---@field selected? string The category chosen.
---@field pendingRule? string A search to make a new category of, the next time the list shows.
---@field all table[] Every part made (the lists, the buttons, the tabs), for the theme.
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

-- What a category does on its own (automation.md), in its list line.
local DOES = { sell = L:G("Sells at merchants"), destroy = L:G("Destroys on command") }

-- The messages a bag kind's committed sweep sends (data/items.lua Phase11): what the bags hold changed.
local READ = { 'items/RefreshBackpack/Done', 'items/RefreshBank/Done', 'items/RefreshGuildBank/Done' }

editor.all = {}

-- Init forgets the category chosen and a search waiting for the list.
function editor:Init()
  self.selected = nil
  self.pendingRule = nil
end

---@param ctx? Context
function editor:ApplyStyle(ctx)
  local _ = ctx
  for _, part in ipairs(self.all) do
    part:Style()
  end
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

-- isPlugins says whether a category is a plugin's: not saved by the player.
---@param filter? CustomCategoryFilter
---@return boolean
local function isPlugins(filter)
  return filter ~= nil and filter.save ~= true
end

-- addedCount returns how many items were added to a category by hand.
---@param filter CustomCategoryFilter
---@return number
local function addedCount(filter)
  local n = 0
  for _ in pairs(filter.itemList or {}) do
    n = n + 1
  end
  return n
end

-- describe says what is in a category and its priority: its list row's line, and its heading's.
---@param filter CustomCategoryFilter
---@return string
local function describe(filter)
  local n = addedCount(filter)
  local rule = categories:RuleOf(filter) ~= nil
  local what
  if rule and n > 0 then
    what = L:G("Search Rule and ") .. count(n, L:G("%d added item"), L:G("%d added items"))
  elseif rule then
    what = L:G("Search Rule")
  elseif n > 0 then
    what = count(n, L:G("%d added item"), L:G("%d added items"))
  else
    what = L:G("Nothing in it yet")
  end
  local line = what .. " · " .. format(L:G("Priority %d"), filter.priority or 10)
  if DOES[filter.automation] then
    line = line .. " · " .. DOES[filter.automation]
  end
  return line
end

-- isShownIn says whether a section name is a category's own or one of its group by's.
---@param name string
---@param category string
---@return boolean
local function isShownIn(name, category)
  return category == name or category:sub(1, #name + 3) == name .. " - "
end

-- namesOf returns the categories defined, your own then the plugins', each by name (not a group by's
-- sub-categories), those whose name has needle.
---@param needle? string
---@return string[] yours, string[] plugins
local function namesOf(needle)
  local yours, plugins = {}, {}
  for name, filter in pairs(categories:GetAllCategories()) do
    if not filter.isGroupBySubcategory and (needle == nil or needle == "" or name:lower():find(needle, 1, true)) then
      table.insert(isPlugins(filter) and plugins or yours, name)
    end
  end
  table.sort(yours)
  table.sort(plugins)
  return yours, plugins
end

-- Chosen returns the category chosen.
---@return CustomCategoryFilter?
function editor:Chosen()
  return self.selected and categories:GetCategoryByName(self.selected) or nil
end

-- EnsureChosen chooses the first category when none is, or the one chosen is gone.
function editor:EnsureChosen()
  if self:Chosen() ~= nil then
    return
  end
  local yours, plugins = namesOf()
  self.selected = yours[1] or plugins[1]
end

-- Choose chooses a category and shows the page again for it.
---@param ctx? Context
---@param name? string
function editor:Choose(ctx, name)
  self.selected = name
  settings:Reselect(ctx)
end

-- Show chooses a category for the next time the page shows (a bag's Categories tab opens it here).
---@param name string
function editor:Show(name)
  self.selected = name
end

-- NewFromSearch makes the list ask for a new category's name, its rule a search, the next time it shows
-- (the search box's Enter to Make Category).
---@param query string
function editor:NewFromSearch(query)
  self.pendingRule = query
end

-- Heading returns the page's title and description: the chosen category's name and what is in it.
---@return string, string
function editor:Heading()
  local filter = self:Chosen()
  if filter == nil then
    return L:G("Categories"), L:G("Make a category to sort your items your way.")
  end
  local line = describe(filter)
  if isPlugins(filter) then
    line = L:G("Made by a plugin") .. " · " .. line
  end
  return self.selected, line
end

-- RuleTabShown says whether the Search Rule tab shows: for your categories, and a plugin's with a rule.
---@return boolean
function editor:RuleTabShown()
  local filter = self:Chosen()
  return filter ~= nil and (not isPlugins(filter) or categories:RuleOf(filter) ~= nil)
end

-- ItemsTabShown says whether the Added Items tab shows: while a category is chosen.
---@return boolean
function editor:ItemsTabShown()
  return self:Chosen() ~= nil
end

-- AutomationTabShown says whether the Automation tab shows: while a category is chosen, a plugin's too
-- (what it does is the player's choice).
---@return boolean
function editor:AutomationTabShown()
  return self:Chosen() ~= nil
end

-- askName asks for a category name over owner; onName gets it trimmed, and is asked again while it is
-- empty or taken (taken: unless allowed, the category's own name).
---@param owner Frame
---@param title string
---@param text string
---@param yes string
---@param start string
---@param allowed? string
---@param onName fun(ctx: Context, name: string)
local function askName(owner, title, text, yes, start, allowed, onName)
  local function ask(message, typed)
    nextDialog:Show(owner, {
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

-- askNewCategory makes a new category (its rule a search when given), and chooses it.
---@param owner Frame
---@param rule? string
local function askNewCategory(owner, rule)
  askName(owner, L:G("New Category"), L:G("Name the new category:"), L:G("Create"), "", nil, function(ctx, name)
    local filter = { name = name, itemList = {}, save = true }
    if rule and strtrim(rule) ~= "" then
      filter.searchCategory = { query = strtrim(rule) }
    end
    categories:CreateCategory(ctx, filter)
    rederive(ctx)
    editor:Choose(ctx, name)
  end)
end

-- bagItemsOf calls fn with every item in the bags given (their committed items), with its bag.
---@param bags SettingBag[]
---@param fn fun(bag: SettingBag, slotkey: string, data: ItemData)
local function bagItemsOf(bags, fn)
  for _, bag in ipairs(bags) do
    local slotInfo = items.slotInfo and items.slotInfo[bag.kind]
    for slotkey, data in pairs(slotInfo and slotInfo.itemsBySlotKey or {}) do
      if not data.isItemEmpty and data.itemInfo then
        fn(bag, slotkey, data)
      end
    end
  end
end

-- byName orders grid entries by name (those not known yet after, by item ID).
---@param a table
---@param b table
---@return boolean
local function byName(a, b)
  if (a.name == nil) ~= (b.name == nil) then
    return a.name ~= nil
  end
  if a.name ~= nil and a.name ~= b.name then
    return a.name:lower() < b.name:lower()
  end
  return a.itemID < b.itemID
end

---------------------------------------------------------------------------------------------------
-- The list, in the window's sidebar.

---@class NextCategoryListRow
---@field frame Button
---@field fill Texture
---@field hover Texture
---@field indicator Texture
---@field dot Texture
---@field label FontString
---@field detail FontString
---@field entry? table
---@field hovered boolean

---@class NextCategoryList
---@field frame Frame
---@field owner Frame
---@field filter NextInputFrame
---@field box WowScrollBox
---@field content Frame
---@field newCategory NextButtonFrame
---@field entries table[] { header = true, title } or { name }
---@field rows NextCategoryListRow[]
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextCategoryList')

-- CreateList makes the page's list (pages.lua sidebar).
---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@return NextCategoryList
function editor:CreateList(parent, owner)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextCategoryList
  local list = setmetatable({ frame = frame, owner = owner, entries = {}, rows = {} }, { __index = listProto })
  list.filter = nextInput:Create(frame, {
    help = L:G("Find a category"),
    onChange = function() list:RefreshRows() end,
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
  view:SetPanExtent(38)
  box:Init(view)
  list.bar = nextScrollBar:Create(box)
  list.bar:Bind(box)
  list.box, list.content = box, content
  list.newCategory = nextButton:Create(frame, {
    text = L:G("New Category"), onClick = function() askNewCategory(owner) end,
  })
  -- A category changed (made, renamed, deleted, edited): the page shows it again, another one chosen for
  -- one that is gone.
  events:RegisterMessage('categories/Changed', function(ctx)
    if frame:IsVisible() then
      editor:EnsureChosen()
      settings:Reselect(ctx)
    end
  end)
  table.insert(self.all, list)
  sonataNext:RegisterWidget(self)
  list:Style()
  return list
end

function listProto:Style()
  for _, row in ipairs(self.rows) do
    self:paintRow(row)
  end
  if self.width then
    self:Place(self.width, self.height)
  end
end

-- Place lays the list out in the sidebar: its filter where the window's search box is, the categories
-- under it, New Category at the bottom.
---@param width number
---@param height number
function listProto:Place(width, height)
  self.width, self.height = width, height
  local T = style.Theme.Settings
  local SB, SR, V = T.Sidebar, T.Search, T.Version
  local B, I = controls:Theme("Button"), controls:Theme("Input")
  local frame = self.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", 0, 0)
  frame:SetSize(width, height)
  self.filter.frame:ClearAllPoints()
  self.filter.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", SB.Pad, -SR.Gap)
  self.filter.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SB.Pad, -SR.Gap)
  self.newCategory.frame:ClearAllPoints()
  self.newCategory.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SB.Pad, V.Bottom)
  self.newCategory:SetWidth(width - 2 * SB.Pad)
  local top = SR.Gap + I.Height + SR.Gap
  local bottom = V.Bottom + B.Height + SR.Gap
  self.box:ClearAllPoints()
  self.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
  self.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottom)
  self.box:SetSize(width, math.max(1, height - top - bottom))
end

-- Refresh lists the categories again, makes sure one is chosen, and asks for a new category's name
-- when a search is waiting to become one (the window shows the page).
---@param ctx? Context
function listProto:Refresh(ctx)
  local _ = ctx
  editor:EnsureChosen()
  self:RefreshRows()
  local rule = editor.pendingRule
  editor.pendingRule = nil
  if rule then
    askNewCategory(self.owner, rule)
  end
end

-- RefreshRows lists the categories whose name has the filter's text: yours, then the plugins'.
function listProto:RefreshRows()
  local yours, plugins = namesOf(strtrim(self.filter:GetText() or ""):lower())
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
  self:layoutRows()
end

-- RowFor returns the row of a category.
---@param name string
---@return NextCategoryListRow?
function listProto:RowFor(name)
  for i, entry in ipairs(self.entries) do
    if entry.name == name then
      return self.rows[i]
    end
  end
  return nil
end

-- row returns the i-th row, made the first time it is needed.
---@private
---@param i number
---@return NextCategoryListRow
function listProto:row(i)
  local row = self.rows[i]
  if row ~= nil then
    return row
  end
  local K = style.Theme.Settings.Categories
  local frame = CreateFrame("Button", nil, self.content)
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
      editor:Choose(ctx, row.entry.name)
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

-- layoutRows places the rows, headings GroupHeight tall and categories RowHeight tall.
---@private
function listProto:layoutRows()
  local K = style.Theme.Settings.Categories
  local y = 0
  for i, entry in ipairs(self.entries) do
    local row = self:row(i)
    row.entry = entry
    local height = entry.header and K.GroupHeight or K.RowHeight
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
    row.frame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -y)
    row.frame:SetHeight(height)
    row.frame:EnableMouse(entry.header ~= true)
    if entry.header then
      row.label:SetText(string.upper(entry.title))
      row.detail:SetText("")
    else
      local filter = categories:GetCategoryByName(entry.name)
      row.label:SetText(entry.name)
      row.detail:SetText(filter and describe(filter) or "")
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
  self.content:SetHeight(math.max(1, y))
  self.box:FullUpdate(true)
end

-- paintRow draws a row: a heading, or a category chosen, under the pointer, or neither.
---@private
---@param row NextCategoryListRow
function listProto:paintRow(row)
  local K, SB = style.Theme.Settings.Categories, style.Theme.Settings.Sidebar
  local entry = row.entry
  row.label:ClearAllPoints()
  row.detail:ClearAllPoints()
  if entry == nil or entry.header then
    style:SetFont(row.label, K.GroupFont)
    row.label:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", SB.Pad, 4)
    row.fill:Hide()
    row.hover:Hide()
    row.indicator:Hide()
    row.dot:Hide()
    row.detail:Hide()
    return
  end
  local chosen = entry.name == editor.selected
  style:SetFont(row.label, K.Font)
  style:SetFont(row.detail, K.NoteFont)
  local left = SB.Pad + K.Indent
  row.dot:ClearAllPoints()
  row.dot:SetPoint("RIGHT", row.label, "LEFT", -6, 0)
  row.dot:SetSize(K.Dot, K.Dot)
  row.dot:Show()
  row.label:SetPoint("BOTTOMLEFT", row.frame, "LEFT", left, 1)
  row.label:SetPoint("RIGHT", row.frame, "RIGHT", -SB.Pad, 0)
  row.detail:SetPoint("TOPLEFT", row.frame, "LEFT", left, -2)
  row.detail:SetPoint("RIGHT", row.frame, "RIGHT", -SB.Pad, 0)
  row.detail:Show()
  controls:Paint(row.fill, chosen and K.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and K.HoverFill or false)
  row.indicator:ClearAllPoints()
  row.indicator:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
  row.indicator:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
  row.indicator:SetWidth(K.Indicator.Width)
  controls:Paint(row.indicator, chosen and { Color = K.Indicator.Color } or false)
end

---------------------------------------------------------------------------------------------------
-- Rename and Delete, in the header.

---@class NextCategoryActions
---@field frame Frame
---@field owner Frame
---@field rename NextButtonFrame
---@field delete NextButtonFrame
local actionsProto = {}
addon:GetModule('Perf'):RegisterPrototype(actionsProto, 'NextCategoryActions')

-- CreateActions makes the page's buttons (pages.lua actions): Rename and Delete, for your categories.
---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@return NextCategoryActions
function editor:CreateActions(parent, owner)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextCategoryActions
  local actions = setmetatable({ frame = frame, owner = owner }, { __index = actionsProto })
  actions.rename = nextButton:Create(frame, { text = L:G("Rename"), onClick = function() actions:AskRename() end })
  actions.delete = nextButton:Create(frame, {
    text = L:G("Delete"), style = "Danger", onClick = function() actions:AskDelete() end,
  })
  table.insert(self.all, actions)
  sonataNext:RegisterWidget(self)
  actions:Style()
  return actions
end

-- Style lines the buttons up, Delete on the right, and sizes the frame to them (to nothing while they
-- are hidden, so the title takes the room).
function actionsProto:Style()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  self.delete.frame:ClearAllPoints()
  self.delete.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
  self.rename.frame:ClearAllPoints()
  self.rename.frame:SetPoint("RIGHT", self.delete.frame, "LEFT", -K.FieldGap, 0)
  local shown = self.rename.frame:IsShown()
  local width = shown and (self.rename.frame:GetWidth() + K.FieldGap + self.delete.frame:GetWidth()) or 1
  self.frame:SetSize(width, B.Height)
end

-- Refresh shows the buttons for your category, and none for a plugin's or none.
---@param ctx? Context
function actionsProto:Refresh(ctx)
  local _ = ctx
  local filter = editor:Chosen()
  local yours = filter ~= nil and not isPlugins(filter)
  self.rename.frame:SetShown(yours)
  self.delete.frame:SetShown(yours)
  self:Style()
end

-- AskRename renames the chosen category, keeping it chosen, or says why it cannot.
function actionsProto:AskRename()
  local current = editor.selected
  if current == nil then
    return
  end
  askName(self.owner, L:G("Rename Category"), format(L:G("Rename the category '%s' to:"), current), L:G("Rename"),
    current, current, function(ctx, name)
      if name == current then
        return
      end
      if not categories:RenameCategory(ctx, current, name) then
        nextDialog:Show(self.owner, {
          title = L:G("Rename Category"), text = format(L:G("The category '%s' could not be renamed."), current),
          buttons = { { text = L:G("OK"), onClick = function() end } },
        })
        return
      end
      editor:Choose(ctx, name)
    end)
end

-- AskDelete deletes the chosen category after asking, choosing the first one left.
function actionsProto:AskDelete()
  local name = editor.selected
  if name == nil then
    return
  end
  nextDialog:Show(self.owner, {
    title = L:G("Delete Category"), text = format(L:G("Delete the category '%s'? This cannot be undone."), name),
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = L:G("Delete"), style = "Danger", onClick = function(ctx)
        categories:DeleteCategory(ctx, name)
        editor:EnsureChosen()
        settings:Reselect(ctx)
      end },
    },
  })
end

---------------------------------------------------------------------------------------------------
-- The tabs: each a wide row filling the page's content (no scrolling).

-- tabHeight returns the height a tab's row fills: the content's, less the page's own room above and
-- below its section (the section's title is hidden).
---@return number
local function tabHeight()
  local C = style.Theme.Settings.Content
  return math.max(1, settings:ContentHeight() - C.Top - C.Bottom)
end

-- makeTab makes a tab's frame and registers it, and has it shown again when the bags are read.
---@param parent Frame
---@param proto table
---@param fields table
---@return table
local function makeTab(parent, proto, fields)
  local frame = CreateFrame("Frame", nil, parent)
  fields.frame, fields.wide = frame, true
  local tab = setmetatable(fields, { __index = proto })
  for _, message in ipairs(READ) do
    events:RegisterMessage(message, function(ctx)
      if frame:IsVisible() then
        tab:Refresh(ctx)
      end
    end)
  end
  table.insert(editor.all, tab)
  sonataNext:RegisterWidget(editor)
  return tab
end

-- label makes a field's name in a tab.
---@param tab table
---@param key string
---@param text string
---@param font? string
local function label(tab, key, text, font)
  local l = style:CreateText(tab.frame, font or style.Theme.Settings.Categories.LabelFont)
  l:SetJustifyH("LEFT")
  l:SetText(text)
  tab.labels[key] = l
end

-- boxRows returns where the Settings and Search Rule tabs put their item box's name row and the box,
-- down from the tab's top: under four rows of settings, the same in both, so the box stays put as the
-- tabs change (asked).
---@return number nameRow, number box
local function boxRows()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local row = K.Pad + 4 * (B.Height + K.FieldGap) + K.FieldGap
  return row, row + B.Height + K.FieldGap
end

-- placeTab anchors a tab's frame where the page put it.
---@param tab table
---@param x number
---@param y number
---@param width number
---@param height number
local function placeTab(tab, x, y, width, height)
  tab.x, tab.y, tab.width, tab.height = x, y, width, height
  local frame = tab.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  frame:SetSize(width, height)
  frame:Show()
end

-- The Settings tab.

---@class NextCategorySettingsTab
---@field frame Frame
---@field wide boolean
---@field bags fun(): SettingBag[]
---@field labels table<string, FontString>
---@field toggles table<BagKind, NextToggleFrame>
---@field toggleLabels table<BagKind, FontString>
local settingsTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(settingsTabProto, 'NextCategorySettingsTab')

---@param parent Frame
---@param owner Frame
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategorySettingsTab
function editor:CreateSettingsTab(parent, owner, bags)
  local _ = owner
  local tab = makeTab(parent, settingsTabProto, { bags = bags, labels = {}, toggles = {}, toggleLabels = {} })
  local K = style.Theme.Settings.Categories
  local frame = tab.frame
  tab.none = style:CreateText(frame, K.TextFont)
  tab.none:SetText(L:G("You have no categories yet. Make one with New Category, under the list."))
  label(tab, "bags", L:G("Used In"))
  label(tab, "priority", L:G("Priority"))
  tab.priority = nextInput:Create(frame, {
    width = 50, numeric = true, maxLetters = 2, commitOnBlur = true,
    onEnter = function(ctx, text) tab:SavePriority(ctx, text) end,
  })
  tab.priorityHint = style:CreateText(frame, K.HintFont)
  tab.priorityHint:SetText(L:G("Lower wins when an item fits more than one category."))
  label(tab, "groupBy", L:G("Group By"))
  tab.groupBy = nextDropdown:Create(frame, {
    items = GROUP_BY_NAMES, width = 140,
    get = function()
      local filter = editor:Chosen()
      return NAME_OF_GROUP_BY[filter and filter.groupBy or GROUP_BY.NONE]
    end,
    onChange = function(ctx, name) tab:update(ctx, { groupBy = GROUP_BY_OF_NAME[name] or GROUP_BY.NONE }) end,
  })
  tab.groupByHint = style:CreateText(frame, K.HintFont)
  tab.groupByHint:SetText(L:G("Splits it into a section for each kind of item."))
  label(tab, "color", L:G("Color"))
  tab.swatch = nextSwatch:Create(frame, {
    color = GOLD,
    onChange = function(ctx, c) tab:update(ctx, { color = { c[1], c[2], c[3] } }) end,
  })
  tab.resetColor = nextButton:Create(frame, {
    text = L:G("Reset Color"), style = "Link",
    onClick = function(ctx)
      tab.swatch:SetColor(GOLD)
      tab:update(ctx, { color = false })
    end,
  })
  label(tab, "inBags", L:G("Current Items in this Group"), K.SectionFont)
  tab.inBags = style:CreateText(frame, K.HintFont)
  tab.inBags:SetJustifyH("LEFT")
  tab.grid = nextItemGrid:Create(frame, {
    empty = L:G("There are no current items in your inventory that match this category"),
  })
  tab:Style()
  return tab
end

function settingsTabProto:Style()
  local K = style.Theme.Settings.Categories
  for key, l in pairs(self.labels) do
    style:SetFont(l, key == "inBags" and K.SectionFont or K.LabelFont)
  end
  for _, l in pairs(self.toggleLabels) do
    style:SetFont(l, K.TextFont)
  end
  style:SetFont(self.none, K.TextFont)
  for _, hint in ipairs({ self.priorityHint, self.groupByHint, self.inBags }) do
    style:SetFont(hint, K.HintFont)
  end
  if self.width then
    self:layout()
  end
end

---@param width number
---@return number
function settingsTabProto:Measure(width)
  local _ = width
  return tabHeight()
end

---@param x number
---@param y number
---@param width number
---@param height number
function settingsTabProto:Place(x, y, width, height)
  placeTab(self, x, y, width, height)
  self:layout()
end

-- toggleFor returns a bag's switch, made the first time it is needed.
---@private
---@param bag SettingBag
---@return NextToggleFrame
function settingsTabProto:toggleFor(bag)
  local toggle = self.toggles[bag.kind]
  if toggle == nil then
    toggle = nextToggle:Create(self.frame, {
      onChange = function(ctx, on) self:update(ctx, { enabled = { [bag.kind] = on } }) end,
    })
    self.toggles[bag.kind] = toggle
    self.toggleLabels[bag.kind] = style:CreateText(self.frame, style.Theme.Settings.Categories.TextFont)
  end
  self.toggleLabels[bag.kind]:SetText(L:G(bag.name))
  return toggle
end

-- update changes the chosen category (categories:UpdateCategory recalculates the bags).
---@private
---@param ctx Context
---@param fields table
function settingsTabProto:update(ctx, fields)
  if editor.selected then
    categories:UpdateCategory(ctx, editor.selected, fields)
  end
end

-- SavePriority saves the priority entered (two digits: 0 to 99); nothing shows the priority again.
---@param ctx Context
---@param text string
function settingsTabProto:SavePriority(ctx, text)
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local n = tonumber(text)
  if n == nil then
    self.priority:SetText(tostring(filter.priority or 10))
    return
  end
  if n ~= (filter.priority or 10) then
    self:update(ctx, { priority = n })
  end
end

-- Refresh shows the chosen category's settings, and what of your bags shows in it now.
---@param ctx? Context
function settingsTabProto:Refresh(ctx)
  local _ = ctx
  local filter = editor:Chosen()
  local yours = filter ~= nil and not isPlugins(filter)
  self.none:SetShown(filter == nil)
  local shown = {}
  for _, bag in ipairs(self.bags()) do
    local toggle = self:toggleFor(bag)
    toggle:SetChecked(filter ~= nil and filter.enabled ~= nil and filter.enabled[bag.kind] ~= false)
    shown[bag.kind] = filter ~= nil
  end
  for kind, toggle in pairs(self.toggles) do
    toggle.frame:SetShown(shown[kind] == true)
    self.toggleLabels[kind]:SetShown(shown[kind] == true)
  end
  for _, part in ipairs({ self.labels.bags, self.labels.priority, self.priority.frame, self.priorityHint,
    self.labels.color, self.swatch.frame, self.resetColor.frame, self.labels.inBags, self.inBags, self.grid.frame }) do
    part:SetShown(filter ~= nil)
  end
  for _, part in ipairs({ self.labels.groupBy, self.groupBy.frame, self.groupByHint }) do
    part:SetShown(yours)
  end
  if filter ~= nil then
    self.priority:SetText(tostring(filter.priority or 10))
    local c = filter.color
    self.swatch:SetColor(c and { c[1], c[2], c[3], 1 } or GOLD)
    self.groupBy:Refresh()
    self:showInBags(filter.name)
  end
  if self.width then
    self:layout()
  end
end

-- showInBags shows what of your bags shows in a category now (its group by's sections too): how many
-- items in each bag, and the items, one cell per item with how many there are.
---@private
---@param name string
function settingsTabProto:showInBags(name)
  local perBag, order, byItem, list = {}, {}, {}, {}
  bagItemsOf(self.bags(), function(bag, _, data)
    local info = data.itemInfo
    if not isShownIn(name, info.category or "") then
      return
    end
    if perBag[bag.kind] == nil then
      perBag[bag.kind] = { bag = bag, items = {} }
      table.insert(order, bag.kind)
    end
    perBag[bag.kind].items[info.itemID] = true
    local entry = byItem[info.itemID]
    if entry == nil then
      entry = { id = info.itemID, itemID = info.itemID, icon = info.itemIcon, quality = info.itemQuality,
        link = info.itemLink, name = info.itemName, count = 0 }
      byItem[info.itemID] = entry
      table.insert(list, entry)
    end
    entry.count = entry.count + (info.currentItemCount or 1)
  end)
  local parts = {}
  for _, bag in ipairs(self.bags()) do
    local here = perBag[bag.kind]
    if here then
      local n = 0
      for _ in pairs(here.items) do
        n = n + 1
      end
      table.insert(parts, format("%s: %s", L:G(bag.name), count(n, L:G("%d item"), L:G("%d items"))))
    end
  end
  self.inBags:SetText(table.concat(parts, " · "))
  table.sort(list, byName)
  self.grid:SetEntries(list)
end

-- layout puts the settings in four rows (the bags it is used in, priority, group by, color; group by's
-- row left empty for a plugin's), then the current items in their box, where the Search Rule tab puts
-- its own.
---@private
function settingsTabProto:layout()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local frame, pad, gap = self.frame, K.Pad, K.FieldGap
  local width = self.width - 2 * pad
  self.none:ClearAllPoints()
  self.none:SetPoint("CENTER", frame, "CENTER", 0, 0)
  -- row puts a setting's name in its row (1 to 4), and returns the middle of the row.
  local function row(key, i)
    local middle = pad + (i - 1) * (B.Height + gap) + B.Height / 2
    local l = self.labels[key]
    l:ClearAllPoints()
    l:SetPoint("LEFT", frame, "TOPLEFT", pad, -middle)
    return middle
  end
  local middle = row("bags", 1)
  local x = pad + K.LabelWidth
  for _, bag in ipairs(self.bags()) do
    local toggle, text = self.toggles[bag.kind], self.toggleLabels[bag.kind]
    if toggle and toggle.frame:IsShown() then
      toggle.frame:ClearAllPoints()
      toggle.frame:SetPoint("LEFT", frame, "TOPLEFT", x, -middle)
      text:ClearAllPoints()
      text:SetPoint("LEFT", toggle.frame, "RIGHT", 6, 0)
      x = x + toggle.frame:GetWidth() + 6 + math.ceil(text:GetStringWidth()) + 2 * gap
    end
  end
  self.priority.frame:ClearAllPoints()
  self.priority.frame:SetPoint("LEFT", frame, "TOPLEFT", pad + K.LabelWidth, -row("priority", 2))
  self.priorityHint:ClearAllPoints()
  self.priorityHint:SetPoint("LEFT", self.priority.frame, "RIGHT", gap, 0)
  self.groupBy.frame:ClearAllPoints()
  self.groupBy.frame:SetPoint("LEFT", frame, "TOPLEFT", pad + K.LabelWidth, -row("groupBy", 3))
  self.groupByHint:ClearAllPoints()
  self.groupByHint:SetPoint("LEFT", self.groupBy.frame, "RIGHT", gap, 0)
  self.swatch.frame:ClearAllPoints()
  self.swatch.frame:SetPoint("LEFT", frame, "TOPLEFT", pad + K.LabelWidth, -row("color", 4))
  self.resetColor.frame:ClearAllPoints()
  self.resetColor.frame:SetPoint("LEFT", self.swatch.frame, "RIGHT", gap, 0)
  local nameRow, box = boxRows()
  self.labels.inBags:ClearAllPoints()
  self.labels.inBags:SetPoint("LEFT", frame, "TOPLEFT", pad, -(nameRow + B.Height / 2))
  self.inBags:ClearAllPoints()
  self.inBags:SetPoint("LEFT", self.labels.inBags, "RIGHT", gap, 0)
  self.grid.frame:ClearAllPoints()
  self.grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -box)
  self.grid:Place(width, math.max(1, self.height - box - pad))
end

-- The Search Rule tab.

---@class NextCategoryRuleTab
---@field frame Frame
---@field wide boolean
---@field bags fun(): SettingBag[]
---@field labels table<string, FontString>
---@field shownFor? string The category whose rule the field shows.
local ruleTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(ruleTabProto, 'NextCategoryRuleTab')

---@param parent Frame
---@param owner Frame
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategoryRuleTab
function editor:CreateRuleTab(parent, owner, bags)
  local _ = owner
  local tab = makeTab(parent, ruleTabProto, { bags = bags, labels = {} })
  local K = style.Theme.Settings.Categories
  local frame = tab.frame
  label(tab, "rule", L:G("Search Rule"))
  tab.help = style:CreateText(frame, K.HintFont)
  tab.help:SetJustifyH("LEFT")
  tab.rule = nextInput:CreateArea(frame, {
    height = 1, help = L:G("For example: type = consumable"),
    onChange = function() tab:Check() end,
  })
  tab.apply = nextButton:Create(frame, {
    text = L:G("Apply Search Rule"), style = "Primary", onClick = function(ctx) tab:Apply(ctx) end,
  })
  tab.results = style:CreateText(frame, K.SectionFont)
  tab.results:SetJustifyH("LEFT")
  tab.grid = nextItemGrid:Create(frame, { empty = L:G("No item in your bags matches.") })
  tab:Style()
  return tab
end

function ruleTabProto:Style()
  local K = style.Theme.Settings.Categories
  style:SetFont(self.labels.rule, K.LabelFont)
  style:SetFont(self.results, K.SectionFont)
  style:SetFont(self.help, K.HintFont)
  if self.width then
    self:layout()
  end
end

---@param width number
---@return number
function ruleTabProto:Measure(width)
  local _ = width
  return tabHeight()
end

---@param x number
---@param y number
---@param width number
---@param height number
function ruleTabProto:Place(x, y, width, height)
  placeTab(self, x, y, width, height)
  self:layout()
end

-- Refresh shows the chosen category's rule (keeping what is typed while the same category shows), and
-- what it matches in your bags. A plugin's rule shows read-only.
---@param ctx? Context
function ruleTabProto:Refresh(ctx)
  local _ = ctx
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local plugins = isPlugins(filter)
  if self.shownFor ~= editor.selected then
    self.shownFor = editor.selected
    self.rule:SetText(categories:RuleOf(filter) or "")
  end
  self.rule:SetEnabled(not plugins)
  self.apply.frame:SetShown(not plugins)
  self.help:SetText(plugins and L:G("The plugin that made this category gives its search rule.")
    or L:G("A search, as in your bags' search box: the items it matches belong here."))
  self:Check()
end

-- matchesOf returns the items in your bags a search matches, or nil for a search with a mistake.
---@private
---@param query string
---@return table[]?
function ruleTabProto:matchesOf(query)
  local ok, found = pcall(search.Search, search, query)
  if not ok then
    return nil
  end
  local list = {}
  bagItemsOf(self.bags(), function(_, slotkey, data)
    if found[slotkey] then
      table.insert(list, data)
    end
  end)
  return list
end

-- Check shows, as the rule is typed, the Search Results (counted beside their name, in full color, those
-- showing in another category saying where in their tooltip), and turns Apply Search Rule on when the
-- rule changed and has no mistake.
function ruleTabProto:Check()
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local text = strtrim(self.rule:GetText() or "")
  local valid = true
  local entries = {}
  local found = text == "" and {} or self:matchesOf(text)
  if found == nil then
    valid = false
    self.results:SetText(format(L:G("Search Results (%s)"), L:G("invalid search")))
  else
    self.results:SetText(format(L:G("Search Results (%s)"), count(#found, L:G("%d result"), L:G("%d results"))))
    for _, data in ipairs(found) do
      local info = data.itemInfo
      local here = isShownIn(filter.name, info.category or "")
      table.insert(entries, {
        id = data.slotkey, itemID = info.itemID, icon = info.itemIcon, quality = info.itemQuality,
        link = info.itemLink, name = info.itemName, count = info.currentItemCount, here = here,
        note = not here and format(L:G("Shows in %s."), info.category or "") or nil,
      })
    end
    table.sort(entries, function(a, b)
      if a.here ~= b.here then
        return a.here
      end
      return byName(a, b)
    end)
  end
  self.grid:SetEntries(entries)
  local saved = categories:RuleOf(filter) or ""
  self.apply:SetEnabled(not isPlugins(filter) and valid and text ~= saved)
end

-- Apply saves the search rule typed (none for an empty one). Its button is on only when that can be
-- saved.
---@param ctx Context
function ruleTabProto:Apply(ctx)
  categories:UpdateCategory(ctx, editor.selected, { rule = strtrim(self.rule:GetText() or "") })
  self:Check()
end

-- layout puts the search rule's name and help, the field taking the room down to the Search Results'
-- row (their name and count, Apply Search Rule on its right), and the results in their box, where the
-- Settings tab puts its own.
---@private
function ruleTabProto:layout()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local frame, pad, gap = self.frame, K.Pad, K.FieldGap
  local width = self.width - 2 * pad
  local nameRow, box = boxRows()
  self.labels.rule:ClearAllPoints()
  self.labels.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
  self.help:ClearAllPoints()
  self.help:SetPoint("LEFT", self.labels.rule, "RIGHT", gap, 0)
  self.help:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
  local top = pad + math.ceil(self.labels.rule:GetStringHeight()) + gap
  self.rule.frame:ClearAllPoints()
  self.rule.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
  self.rule.frame:SetSize(width, math.max(B.Height, nameRow - gap - top))
  local middle = nameRow + B.Height / 2
  self.apply.frame:ClearAllPoints()
  self.apply.frame:SetPoint("RIGHT", frame, "TOPRIGHT", -pad, -middle)
  self.results:ClearAllPoints()
  self.results:SetPoint("LEFT", frame, "TOPLEFT", pad, -middle)
  self.results:SetPoint("RIGHT", self.apply.frame, "LEFT", -gap, 0)
  self.grid.frame:ClearAllPoints()
  self.grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -box)
  self.grid:Place(width, math.max(1, self.height - box - pad))
end

-- The Added Items tab.

---@class NextCategoryItemsTab
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field bags fun(): SettingBag[]
---@field labels table<string, FontString>
---@field loading table<string, boolean> The categories whose item names are loading.
local itemsTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(itemsTabProto, 'NextCategoryItemsTab')

---@param parent Frame
---@param owner Frame The window its dialogs and menus show over.
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategoryItemsTab
function editor:CreateItemsTab(parent, owner, bags)
  local tab = makeTab(parent, itemsTabProto, { owner = owner, bags = bags, labels = {}, loading = {} })
  local K = style.Theme.Settings.Categories
  local frame = tab.frame
  tab.count = style:CreateText(frame, K.SectionFont)
  tab.count:SetJustifyH("LEFT")
  tab.filter = nextInput:Create(frame, {
    width = K.FilterWidth, help = L:G("Find an item"),
    onChange = function() tab:ShowItems() end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  tab.removeAll = nextButton:Create(frame, {
    text = L:G("Remove All"), style = "Danger", onClick = function() tab:AskRemoveAll() end,
  })
  tab.help = style:CreateText(frame, K.HintFont)
  tab.help:SetJustifyH("LEFT")
  tab.help:SetWordWrap(true)
  tab.grid = nextItemGrid:Create(frame, {
    onDrop = function(ctx) tab:Drop(ctx) end,
    onRightClick = function(ctx, entry, cell) tab:OfferRemove(ctx, entry, cell) end,
    hint = L:G("Right-click to remove it."),
    empty = L:G("No items added yet."),
  })
  tab.readOnly = nextItemGrid:Create(frame, { empty = L:G("The plugin added no items.") })
  tab:Style()
  return tab
end

function itemsTabProto:Style()
  local K = style.Theme.Settings.Categories
  style:SetFont(self.count, K.SectionFont)
  style:SetFont(self.help, K.HintFont)
  if self.width then
    self:layout()
  end
end

---@param width number
---@return number
function itemsTabProto:Measure(width)
  local _ = width
  return tabHeight()
end

---@param x number
---@param y number
---@param width number
---@param height number
function itemsTabProto:Place(x, y, width, height)
  placeTab(self, x, y, width, height)
  self:layout()
end

-- Refresh shows the items added to the chosen category: yours to add to and remove from, a plugin's
-- read-only.
---@param ctx? Context
function itemsTabProto:Refresh(ctx)
  local _ = ctx
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local plugins = isPlugins(filter)
  self.grid.frame:SetShown(not plugins)
  self.readOnly.frame:SetShown(plugins)
  self.removeAll.frame:SetShown(not plugins)
  self.help:SetText(plugins and L:G("The plugin that made this category adds these items.")
    or L:G("Drag an item here to manually add it to this category."))
  self:ShowItems()
  if self.width then
    self:layout()
  end
end

-- ShowItems lists the items added, by name, those whose name has the filter's text; an item in your
-- bags showing in another category is faded, saying where. Names not loaded yet are asked for, and
-- the list is shown again once they arrive.
function itemsTabProto:ShowItems()
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local name = filter.name
  local merged = categories:GetMergedCategory(name)
  local elsewhere = {}
  bagItemsOf(self.bags(), function(_, _, data)
    local info = data.itemInfo
    local category = info.category or ""
    if merged.itemList[info.itemID] and not isShownIn(name, category) and elsewhere[info.itemID] == nil then
      elsewhere[info.itemID] = category
    end
  end)
  local needle = strtrim(self.filter:GetText() or ""):lower()
  local all, shown, cold = 0, {}, {}
  for itemID in pairs(merged.itemList) do
    all = all + 1
    local itemName = C_Item.GetItemNameByID(itemID)
    if itemName == nil then
      table.insert(cold, itemID)
    end
    if needle == "" or (itemName ~= nil and itemName:lower():find(needle, 1, true)) then
      local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
      local where = elsewhere[itemID]
      table.insert(shown, {
        id = itemID, itemID = itemID, icon = icon, quality = C_Item.GetItemQualityByID(itemID), name = itemName,
        dim = where ~= nil, note = where and format(L:G("Shows in %s instead."), where) or nil,
      })
    end
  end
  table.sort(shown, byName)
  if needle == "" then
    self.count:SetText(count(all, L:G("%d added item"), L:G("%d added items")))
  else
    self.count:SetText(format(L:G("%d of %s"), #shown, count(all, L:G("%d added item"), L:G("%d added items"))))
  end
  self.removeAll:SetEnabled(all > 0)
  local grid = isPlugins(filter) and self.readOnly or self.grid
  grid:SetEntries(shown)
  self:loadNames(name, cold)
end

-- loadNames asks for the item data of items whose names are not known yet, once per category, and
-- shows the list again when it has arrived (if the category still shows).
---@private
---@param name string
---@param ids number[]
function itemsTabProto:loadNames(name, ids)
  if #ids == 0 or self.loading[name] then
    return
  end
  self.loading[name] = true
  local container = ContinuableContainer:Create()
  for _, itemID in ipairs(ids) do
    container:AddContinuable(Item:CreateFromItemID(itemID))
  end
  container:ContinueOnLoad(function()
    self.loading[name] = nil
    if editor.selected == name and self.frame:IsVisible() then
      self:ShowItems()
    end
  end)
end

-- Drop adds the item on the cursor to the chosen category.
---@param ctx Context
function itemsTabProto:Drop(ctx)
  local filter = editor:Chosen()
  if filter == nil or isPlugins(filter) or not CursorHasItem() then
    return
  end
  local kind, itemID = GetCursorInfo()
  if kind ~= "item" then
    return
  end
  categories:AddPermanentItemToCategory(ctx, itemID, editor.selected)
  ClearCursor()
  rederive(ctx)
  self:ShowItems()
end

-- OfferRemove offers to remove an item, from a right click on it.
---@param ctx Context
---@param entry NextItemGridEntry
---@param cell Button
function itemsTabProto:OfferRemove(ctx, entry, cell)
  local _ = ctx
  nextMenu:Open(cell, {
    items = { { text = L:G("Remove") } },
    onPick = function(pctx)
      categories:RemoveItemFromCategory(entry.itemID, editor.selected)
      rederive(pctx)
      self:ShowItems()
    end,
  })
end

-- AskRemoveAll removes every item added to the chosen category, after asking.
function itemsTabProto:AskRemoveAll()
  local name = editor.selected
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local n = addedCount(categories:GetMergedCategory(name))
  nextDialog:Show(self.owner, {
    title = L:G("Remove All"),
    text = format(L:G("Remove all %s from '%s'? This cannot be undone."), count(n, L:G("%d added item"),
      L:G("%d added items")), name),
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = L:G("Remove All"), style = "Danger", onClick = function(ctx)
        categories:WipeCategory(ctx, name)
        rederive(ctx)
        self:ShowItems()
      end },
    },
  })
end

-- layout puts the count, the filter and Remove All on top, the help under them, and the items taking
-- the room left.
---@private
function itemsTabProto:layout()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local frame, pad, gap = self.frame, K.Pad, K.FieldGap
  local width = self.width - 2 * pad
  local y = pad
  local middle = y + B.Height / 2
  self.removeAll.frame:ClearAllPoints()
  self.removeAll.frame:SetPoint("RIGHT", frame, "TOPRIGHT", -pad, -middle)
  self.filter.frame:ClearAllPoints()
  if self.removeAll.frame:IsShown() then
    self.filter.frame:SetPoint("RIGHT", self.removeAll.frame, "LEFT", -gap, 0)
  else
    self.filter.frame:SetPoint("RIGHT", frame, "TOPRIGHT", -pad, -middle)
  end
  self.count:ClearAllPoints()
  self.count:SetPoint("LEFT", frame, "TOPLEFT", pad, -middle)
  y = y + B.Height + gap
  self.help:ClearAllPoints()
  self.help:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
  self.help:SetWidth(width)
  y = y + math.ceil(self.help:GetStringHeight()) + gap
  for _, grid in ipairs({ self.grid, self.readOnly }) do
    grid.frame:ClearAllPoints()
    grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
    grid:Place(width, math.max(1, self.height - y - pad))
  end
end

-- The Automation tab (automation.md): what the category does with your backpack's items on its own,
-- as two switches, at most one on.

---@class NextCategoryAutomationTab
---@field frame Frame
---@field wide boolean
---@field bags fun(): SettingBag[]
---@field labels table<string, FontString>
---@field sell NextToggleFrame
---@field destroy NextToggleFrame
local automationTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(automationTabProto, 'NextCategoryAutomationTab')

-- The switches, in their rows' order: what each turns on.
local SWITCHES = { "sell", "destroy" }

---@param parent Frame
---@param owner Frame
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategoryAutomationTab
function editor:CreateAutomationTab(parent, owner, bags)
  local _ = owner
  local tab = makeTab(parent, automationTabProto, { bags = bags, labels = {} })
  local K = style.Theme.Settings.Categories
  tab.none = style:CreateText(tab.frame, K.TextFont)
  tab.none:SetText(L:G("You have no categories yet. Make one with New Category, under the list."))
  label(tab, "sell", L:G("Sell at Merchants"))
  label(tab, "destroy", L:G("Destroy"))
  for _, action in ipairs(SWITCHES) do
    tab[action] = nextToggle:Create(tab.frame, {
      onChange = function(ctx, on) tab:Choose(ctx, action, on) end,
    })
  end
  tab:Style()
  return tab
end

function automationTabProto:Style()
  local K = style.Theme.Settings.Categories
  for _, l in pairs(self.labels) do
    style:SetFont(l, K.LabelFont)
  end
  style:SetFont(self.none, K.TextFont)
  if self.width then
    self:layout()
  end
end

---@param width number
---@return number
function automationTabProto:Measure(width)
  local _ = width
  return tabHeight()
end

---@param x number
---@param y number
---@param width number
---@param height number
function automationTabProto:Place(x, y, width, height)
  placeTab(self, x, y, width, height)
  self:layout()
end

-- Choose saves a switch turned on (the other one goes off: a category does one thing) or off.
---@param ctx Context
---@param action string
---@param on boolean
function automationTabProto:Choose(ctx, action, on)
  if editor.selected then
    categories:UpdateCategory(ctx, editor.selected, { automation = on and action or false })
  end
  self:Refresh(ctx)
end

-- Refresh shows the chosen category's switches.
---@param ctx? Context
function automationTabProto:Refresh(ctx)
  local _ = ctx
  local filter = editor:Chosen()
  self.none:SetShown(filter == nil)
  for _, action in ipairs(SWITCHES) do
    self.labels[action]:SetShown(filter ~= nil)
    self[action].frame:SetShown(filter ~= nil)
    self[action]:SetChecked(filter ~= nil and filter.automation == action)
  end
  if self.width then
    self:layout()
  end
end

-- layout puts each switch in its row, its name in the labels' column.
---@private
function automationTabProto:layout()
  local K = style.Theme.Settings.Categories
  local B = controls:Theme("Button")
  local frame, pad, gap = self.frame, K.Pad, K.FieldGap
  self.none:ClearAllPoints()
  self.none:SetPoint("CENTER", frame, "CENTER", 0, 0)
  for i, action in ipairs(SWITCHES) do
    local middle = pad + (i - 1) * (B.Height + gap) + B.Height / 2
    self.labels[action]:ClearAllPoints()
    self.labels[action]:SetPoint("LEFT", frame, "TOPLEFT", pad, -middle)
    self[action].frame:ClearAllPoints()
    self[action].frame:SetPoint("LEFT", frame, "TOPLEFT", pad + K.LabelWidth, -middle)
  end
end
