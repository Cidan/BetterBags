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

---@class NextListReorder: AceModule
local reorder = addon:GetModule('NextListReorder')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextSettingsCategories is the Categories page (next-settings.md §5, category-lifecycle.md §6), where
-- every category is defined once: one kind of category, a rule, items added by hand, or both. The page
-- shows its own list in the window's sidebar (pages.lua sidebar): every category, yours and the plugins',
-- in their order, which is their priority (category-lifecycle.md §7: dragging a row moves it), filtered
-- by name, New Category under them. The chosen category's name and what is in it are the
-- page's heading, Rename and Delete its buttons in the header, and four tabs show it:
-- - Settings: the bags it is used in, its group by and color, and what of your bags shows in
--   it now, as items.
-- - Search Rule: its search, Apply Search Rule, and the Search Results (counted beside their name as it
--   is typed) as items, those showing in another category saying where.
-- - Automation: what it does with your backpack's items on its own (automation.md): Auto Sell, and
--   Destroy What Can't Be Sold, which needs Auto Sell on, as settings rows (AutomationOptions).
-- - Added Items: the items added to it by hand, as a grid that holds thousands (NextItemGrid), filtered
--   by name; an item dropped anywhere on it is added, a right click removes one, Remove All asks first.
-- A plugin's category can be used in bags, colored, ordered and automated; its rule (when it has one)
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

-- What a category does on its own (automation.md), in its heading's line.
local DOES = { sell = L:G("Sells at merchants"), destroy = L:G("Sells, destroys the rest") }

-- The messages that say a bag's items were read (data/items.lua Phase11): the list counts again.
local BAG_READ = { 'items/RefreshBackpack/Done', 'items/RefreshBank/Done', 'items/RefreshGuildBank/Done' }

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

-- describe says whose a category is (a plugin's), what is in it and what it does on its own: its
-- heading's line.
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
  local line = what
  if isPlugins(filter) then
    line = L:G("Made by a plugin") .. " · " .. line
  end
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

-- ordered returns every category's name in their order (categories:GetOrder: not a group by's
-- sections), those whose name has needle.
---@param needle? string
---@return string[]
local function ordered(needle)
  local names = {}
  for _, name in ipairs(categories:GetOrder()) do
    if needle == nil or needle == "" or name:lower():find(needle, 1, true) then
      table.insert(names, name)
    end
  end
  return names
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
  self.selected = ordered()[1]
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
  return self.selected, describe(filter)
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

-- AutomationOptions returns the Automation tab's settings (automation.md §5), which the page draws as
-- rows of a section, as every page draws its settings: Auto Sell ("sell"), Confirm Auto Sell (on unless
-- turned off: the category's section waits in the vendor's dock to be sold), and Destroy What Can't Be
-- Sold ("destroy", which sells too); the last two disabled while Auto Sell is off, which takes Destroy
-- with it. Each saves at once and shows the page's rows again, so the others follow.
---@return NextSettingsOption[]
function editor:AutomationOptions()
  local function automation()
    local filter = self:Chosen()
    return filter and filter.automation
  end
  local function sells()
    local a = automation()
    return a == "sell" or a == "destroy"
  end
  local function save(ctx, value)
    if self.selected then
      categories:UpdateCategory(ctx, self.selected, { automation = value })
    end
    settings:Refresh(ctx)
  end
  return {
    {
      kind = "toggle",
      title = L:G("Auto Sell"),
      description = L:G("Sell this category's items when you open a merchant. Hold Shift to keep them."),
      keywords = { "automation", "sell", "vendor", "merchant", "junk" },
      get = sells,
      set = function(ctx, on) save(ctx, on and "sell" or false) end,
    },
    {
      kind = "toggle",
      title = L:G("Confirm Auto Sell"),
      description = L:G("At a vendor, this category's section waits there to be sold with a double click (BetterBags Next). Turned off, it is sold as soon as the vendor opens."),
      keywords = { "automation", "sell", "confirm", "vendor", "merchant" },
      disabled = function() return not sells() end,
      get = function()
        local filter = self:Chosen()
        return not (filter and filter.confirmSale == false)
      end,
      set = function(ctx, on)
        if self.selected then
          categories:UpdateCategory(ctx, self.selected, { confirmSale = on })
        end
        settings:Refresh(ctx)
      end,
    },
    {
      kind = "toggle",
      title = L:G("Destroy What Can't Be Sold"),
      description = L:G("Destroy this category's items no merchant buys, one per click. Needs Auto Sell."),
      keywords = { "automation", "destroy", "delete", "junk" },
      disabled = function() return not sells() end,
      get = function() return automation() == "destroy" end,
      set = function(ctx, on) save(ctx, on and "destroy" or "sell") end,
    },
  }
end

-- RecentOptions returns the Automation tab's Recent Items settings (docs/next-batch-2.md §1), a section of
-- its own (asked: "not under 'merchant'"): Skip Recent Items, independent of the merchant settings, for
-- any category, a plugin's too. It saves at once and shows the page's rows again.
---@return NextSettingsOption[]
function editor:RecentOptions()
  return {
    {
      kind = "toggle",
      title = L:G("Skip Recent Items"),
      description = L:G("Items that land in this category skip Recent Items: they are no longer marked new, and show here at once."),
      keywords = { "automation", "recent", "new", "skip" },
      get = function()
        local filter = self:Chosen()
        return filter ~= nil and filter.skipRecent == true
      end,
      set = function(ctx, on)
        if self.selected then
          categories:UpdateCategory(ctx, self.selected, { skipRecent = on })
        end
        settings:Refresh(ctx)
      end,
    },
  }
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

-- matchingCounts returns how many items each category holds in bags, as its Settings tab's Current Items
-- in this Group lists them: each item once, its group by's sections with it (isShownIn: an item in
-- "Potions - Flask" counts for Potions). One pass: an item counts for its category and for every name
-- that category is a section of.
---@param bags SettingBag[]
---@return table<string, number>
local function matchingCounts(bags)
  local seen, counts = {}, {}
  bagItemsOf(bags, function(_, _, data)
    local id = data.itemInfo.itemID
    local name = data.itemInfo.category
    while name ~= nil and name ~= "" do
      seen[name] = seen[name] or {}
      if not seen[name][id] then
        seen[name][id] = true
        counts[name] = (counts[name] or 0) + 1
      end
      name = name:match("^(.*) %- ")
    end
  end)
  return counts
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
---@field bags fun(): SettingBag[] The bags the settings show.
---@field entries table[] { name }, in their order
---@field rows NextCategoryListRow[] The rows of the entries, in the same order.
---@field byName table<string, NextCategoryListRow> Each category's own row: moved in the order, it slides.
---@field free NextCategoryListRow[] Rows no category has, hidden, to reuse.
---@field drag NextListReorderList Arranges the rows; dragging one moves its category in the order.
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextCategoryList')

-- CreateList makes the page's list (pages.lua sidebar).
---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategoryList
function editor:CreateList(parent, owner, bags)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextCategoryList
  local list = setmetatable({ frame = frame, owner = owner, bags = bags, entries = {}, rows = {}, byName = {},
    free = {} }, { __index = listProto })
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
  list.drag = reorder:Create({
    box = box, content = content,
    entries = function() return list.entries end,
    rowOf = function(entry) return list.byName[entry.name].frame end,
    heightOf = function() return pixel:Length(frame, style.Theme.Settings.Categories.RowHeight) end,
    onDrop = function(name, after) list:Drop(name, after) end,
  })
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
  -- A bag's items were read: what each category holds may have changed.
  for _, message in ipairs(BAG_READ) do
    events:RegisterMessage(message, function()
      if frame:IsVisible() then
        list:RefreshRows()
      end
    end)
  end
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
-- All in whole pixels (docs/next-pixel-perfect.md).
function listProto:Place(width, height)
  self.width, self.height = width, height
  local T = style.Theme.Settings
  local B, I = controls:Theme("Button"), controls:Theme("Input")
  local frame = self.frame
  local pad, gap, bottomGap = pixel:Snap(frame, T.Sidebar.Pad), pixel:Snap(frame, T.Search.Gap), pixel:Snap(frame, T.Version.Bottom)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", 0, 0)
  pixel:Size(frame, width, height)
  width, height = frame:GetWidth(), frame:GetHeight()
  self.filter.frame:ClearAllPoints()
  self.filter.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -gap)
  self.filter.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -gap)
  self.filter:Style()
  self.newCategory.frame:ClearAllPoints()
  self.newCategory.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, bottomGap)
  self.newCategory:SetWidth(width - 2 * pad)
  local top = gap + pixel:Length(frame, I.Height) + gap
  local bottom = bottomGap + pixel:Length(frame, B.Height) + gap
  self.box:ClearAllPoints()
  self.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
  self.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottom)
  self.box:SetSize(width, math.max(pixel:Unit(frame), height - top - bottom))
  self.drag:Arrange(width)
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

-- RefreshRows lists the categories whose name has the filter's text, in their order.
function listProto:RefreshRows()
  local entries = {}
  for _, name in ipairs(ordered(strtrim(self.filter:GetText() or ""):lower())) do
    table.insert(entries, { name = name })
  end
  self.entries = entries
  self:layoutRows()
end

-- Drop moves a category let go after the after-th row shown, in the order: after the category of that
-- row, or, let go above every row shown, right before the first of them (at the top when nothing is
-- above it, or when no filter hides any). The categories a filter hides keep their places.
---@param name string
---@param after number
function listProto:Drop(name, after)
  local shown = {}
  for i, entry in ipairs(self.entries) do
    if entry.name == name then
      if i <= after then
        after = after - 1
      end
    else
      table.insert(shown, entry.name)
    end
  end
  local anchor
  if after >= 1 then
    anchor = shown[math.min(after, #shown)]
  elseif shown[1] ~= nil then
    for _, n in ipairs(categories:GetOrder()) do
      if n == shown[1] then
        break
      end
      if n ~= name then
        anchor = n
      end
    end
  end
  categories:MoveCategory(context:New('NextCategoryList_Drop'), name, anchor)
end

-- RowFor returns the row of a category the list shows.
---@param name string
---@return NextCategoryListRow?
function listProto:RowFor(name)
  return self.byName[name]
end

-- rowFor returns a category's own row, taking one no category has, or making one, the first time.
---@private
---@param name string
---@return NextCategoryListRow
function listProto:rowFor(name)
  local row = self.byName[name]
  if row == nil then
    row = table.remove(self.free) or self:newRow()
    self.byName[name] = row
  end
  return row
end

-- newRow makes a row.
---@private
---@return NextCategoryListRow
function listProto:newRow()
  local K = style.Theme.Settings.Categories
  local frame = CreateFrame("Button", nil, self.content)
  frame:RegisterForClicks("LeftButtonUp")
  frame:RegisterForDrag("LeftButton")
  ---@type NextCategoryListRow
  local row = {
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
  addon.SetScript(frame, "OnDragStart", function()
    if row.entry and row.entry.name then
      self.drag:Start(row.entry.name)
    end
  end)
  return row
end

-- layoutRows shows each category listed in its own row, RowHeight tall, saying how many of the shown bags'
-- items it holds (asked: "x items matching"), and puts the rows of those no longer listed away; the list's arrangement places them (NextListReorder: a row that moved slides).
---@private
function listProto:layoutRows()
  local K = style.Theme.Settings.Categories
  local listed = {}
  local counts = matchingCounts(self.bags())
  self.rows = {}
  for i, entry in ipairs(self.entries) do
    local row = self:rowFor(entry.name)
    listed[entry.name] = true
    self.rows[i] = row
    row.entry = entry
    row.frame:SetHeight(pixel:Length(self.frame, K.RowHeight))
    local filter = categories:GetCategoryByName(entry.name)
    row.label:SetText(entry.name)
    row.detail:SetText(count(counts[entry.name] or 0, L:G("%d item matching"), L:G("%d items matching")))
    local c = filter and filter.color or GOLD
    row.dot:SetColorTexture(c[1], c[2], c[3], 1)
    row.frame:Show()
    self:paintRow(row)
  end
  for name, row in pairs(self.byName) do
    if not listed[name] then
      self.byName[name] = nil
      row.entry = nil
      row.frame:Hide()
      table.insert(self.free, row)
    end
  end
  self.drag:Arrange()
end

-- paintRow draws a row: its category chosen, under the pointer, or neither.
---@private
---@param row NextCategoryListRow
function listProto:paintRow(row)
  local K, SB = style.Theme.Settings.Categories, style.Theme.Settings.Sidebar
  local entry = row.entry
  row.label:ClearAllPoints()
  row.detail:ClearAllPoints()
  if entry == nil then
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
  -- The name and the count under it, the two lines centered on the row by their top in whole pixels
  -- (docs/next-pixel-perfect.md); the dot left of the name, centered on its line.
  local frame = row.frame
  local pad = pixel:Snap(frame, SB.Pad)
  local left = pad + pixel:Snap(frame, K.Indent)
  local nameHeight, detailHeight = pixel:Ceil(frame, pixel:TextHeight(row.label)), pixel:Ceil(frame, pixel:TextHeight(row.detail))
  local between = pixel:Snap(frame, 3)
  local top = pixel:Middle(frame, frame:GetHeight(), nameHeight + between + detailHeight)
  pixel:Size(row.dot, K.Dot, K.Dot)
  row.dot:ClearAllPoints()
  row.dot:SetPoint("TOPLEFT", frame, "TOPLEFT", left - pixel:Snap(frame, 6) - row.dot:GetWidth(),
    -(top + pixel:Middle(frame, nameHeight, row.dot:GetHeight())))
  row.dot:Show()
  row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
  row.label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -top)
  local detailTop = top + nameHeight + between
  row.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -detailTop)
  row.detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -detailTop)
  row.detail:Show()
  controls:Paint(row.fill, chosen and K.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and K.HoverFill or false)
  row.indicator:ClearAllPoints()
  row.indicator:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
  row.indicator:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
  pixel:Width(row.indicator, K.Indicator.Width)
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
  local gap = pixel:Snap(self.frame, K.FieldGap)
  self.delete.frame:ClearAllPoints()
  self.delete.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
  self.rename.frame:ClearAllPoints()
  self.rename.frame:SetPoint("TOPRIGHT", self.delete.frame, "TOPLEFT", -gap, 0)
  local shown = self.rename.frame:IsShown()
  local width = shown and (self.rename.frame:GetWidth() + gap + self.delete.frame:GetWidth()) or pixel:Unit(self.frame)
  self.frame:SetSize(width, pixel:Length(self.frame, B.Height))
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
---@param frame Frame The tab's, on the window's grid.
---@return number
local function tabHeight(frame)
  local C = style.Theme.Settings.Content
  return math.max(1, settings:ContentHeight() - pixel:Snap(frame, C.Top) - pixel:Snap(frame, C.Bottom))
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

-- metricsOf returns a tab's lengths in whole pixels on its grid (docs/next-pixel-perfect.md): its padding,
-- the gap between fields, a field row's height (a button's), a label's width.
---@param frame Frame
---@return {pad: number, gap: number, row: number, labelWidth: number}
local function metricsOf(frame)
  local K = style.Theme.Settings.Categories
  return { pad = pixel:Snap(frame, K.Pad), gap = pixel:Snap(frame, K.FieldGap),
    row = pixel:Length(frame, controls:Theme("Button").Height), labelWidth = pixel:Snap(frame, K.LabelWidth) }
end

-- boxRows returns where the Settings and Search Rule tabs put their item box's name row and the box,
-- down from the tab's top: under three rows of settings, the same in both, so the box stays put as the
-- tabs change (asked).
---@param frame Frame
---@return number nameRow, number box
local function boxRows(frame)
  local m = metricsOf(frame)
  local row = m.pad + 3 * (m.row + m.gap) + m.gap
  return row, row + m.row + m.gap
end

-- placeTab anchors a tab's frame where the page put it.
---@param tab table
---@param x number
---@param y number
---@param width number
---@param height number
local function placeTab(tab, x, y, width, height)
  local frame = tab.frame
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  pixel:Size(frame, width, height)
  tab.x, tab.y, tab.width, tab.height = x, y, frame:GetWidth(), frame:GetHeight()
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
  for _, hint in ipairs({ self.groupByHint, self.inBags }) do
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
  return tabHeight(self.frame)
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
  for _, part in ipairs({ self.labels.bags, self.labels.color, self.swatch.frame, self.resetColor.frame, self.labels.inBags, self.inBags, self.grid.frame }) do
    part:SetShown(filter ~= nil)
  end
  for _, part in ipairs({ self.labels.groupBy, self.groupBy.frame, self.groupByHint }) do
    part:SetShown(yours)
  end
  if filter ~= nil then
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

-- layout puts the settings in three rows (the bags it is used in, group by, color; group by's row left
-- empty for a plugin's), then the current items in their box, where the Search Rule tab puts its own.
---@private
-- Each field by its top left in whole pixels (docs/next-pixel-perfect.md), centered on its row's height;
-- what follows a text starts past its width rounded up.
function settingsTabProto:layout()
  local frame = self.frame
  local m = metricsOf(frame)
  local pad, gap = m.pad, m.gap
  local width = self.width - 2 * pad
  -- Across the tab, centered by the client, at its middle line by its top.
  self.none:ClearAllPoints()
  self.none:SetJustifyH("CENTER")
  local noneTop = pixel:Middle(frame, self.height, pixel:Ceil(frame, self.none:GetStringHeight()))
  self.none:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -noneTop)
  self.none:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -noneTop)
  -- rowTop is how far down a row (1 to 3) of settings starts.
  local function rowTop(i)
    return pad + (i - 1) * (m.row + gap)
  end
  -- at puts a region x across in a row starting top down, centered on the row's height.
  local function at(region, x, top)
    region:ClearAllPoints()
    pixel:Row(region, "TOPLEFT", frame, x, m.row, nil, top)
  end
  at(self.labels.bags, pad, rowTop(1))
  local x = pad + m.labelWidth
  for _, bag in ipairs(self.bags()) do
    local toggle, text = self.toggles[bag.kind], self.toggleLabels[bag.kind]
    if toggle and toggle.frame:IsShown() then
      at(toggle.frame, x, rowTop(1))
      local textX = x + toggle.frame:GetWidth() + pixel:Snap(frame, 6)
      at(text, textX, rowTop(1))
      x = textX + pixel:Ceil(frame, text:GetStringWidth()) + 2 * gap
    end
  end
  at(self.labels.groupBy, pad, rowTop(2))
  at(self.groupBy.frame, pad + m.labelWidth, rowTop(2))
  at(self.groupByHint, pad + m.labelWidth + self.groupBy.frame:GetWidth() + gap, rowTop(2))
  at(self.labels.color, pad, rowTop(3))
  at(self.swatch.frame, pad + m.labelWidth, rowTop(3))
  at(self.resetColor.frame, pad + m.labelWidth + self.swatch.frame:GetWidth() + gap, rowTop(3))
  local nameRow, box = boxRows(frame)
  at(self.labels.inBags, pad, nameRow)
  at(self.inBags, pad + pixel:Ceil(frame, self.labels.inBags:GetStringWidth()) + gap, nameRow)
  self.grid.frame:ClearAllPoints()
  self.grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -box)
  self.grid:Place(width, math.max(pixel:Unit(frame), self.height - box - pad))
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
  return tabHeight(self.frame)
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
-- In whole pixels (docs/next-pixel-perfect.md): the help beside the rule's name, centered on its line by
-- its top; the field below the name's height rounded up; Search Results and its button centered on their
-- row by their tops.
function ruleTabProto:layout()
  local frame = self.frame
  local m = metricsOf(frame)
  local pad, gap = m.pad, m.gap
  local width = self.width - 2 * pad
  local nameRow, box = boxRows(frame)
  local nameHeight = pixel:Ceil(frame, pixel:TextHeight(self.labels.rule))
  self.labels.rule:ClearAllPoints()
  self.labels.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
  local helpX = pad + pixel:Ceil(frame, self.labels.rule:GetStringWidth()) + gap
  self.help:ClearAllPoints()
  pixel:Row(self.help, "TOPLEFT", frame, helpX, nameHeight, nil, pad)
  pixel:Row(self.help, "TOPRIGHT", frame, pad, nameHeight, nil, pad)
  local top = pad + nameHeight + gap
  self.rule.frame:ClearAllPoints()
  self.rule.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
  self.rule.frame:SetSize(width, math.max(m.row, nameRow - gap - top))
  self.rule:Style()
  self.apply.frame:ClearAllPoints()
  pixel:Row(self.apply.frame, "TOPRIGHT", frame, pad, m.row, nil, nameRow)
  self.results:ClearAllPoints()
  pixel:Row(self.results, "TOPLEFT", frame, pad, m.row, nil, nameRow)
  pixel:Row(self.results, "TOPRIGHT", frame, pad + self.apply.frame:GetWidth() + gap, m.row, nil, nameRow)
  self.grid.frame:ClearAllPoints()
  self.grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -box)
  self.grid:Place(width, math.max(pixel:Unit(frame), self.height - box - pad))
end

-- The Added Items tab.

---@class NextCategoryItemsTab
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field bags fun(): SettingBag[]
---@field labels table<string, FontString>
---@field loading table<string, boolean> The categories whose item names are loading.
---@field mode "added"|"ignored" Its list: the items added to the category by hand (Added Items), or those it ignores (Ignored Items).
local itemsTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(itemsTabProto, 'NextCategoryItemsTab')

-- CreateItemsTab makes a tab of a category's items: those added by hand (Added Items), or with mode
-- "ignored" those it ignores (Ignored Items, docs/next-batch-2.md §2; asked: "same interface/layout as
-- Added Items"). One tab, two lists: the count, the filter, Remove All, the help and the item grid,
-- taking drops and removing on a right click.
---@param parent Frame
---@param owner Frame The window its dialogs and menus show over.
---@param bags fun(): SettingBag[] The bags the settings show.
---@param mode? "added"|"ignored"
---@return NextCategoryItemsTab
function editor:CreateItemsTab(parent, owner, bags, mode)
  local tab = makeTab(parent, itemsTabProto,
    { owner = owner, bags = bags, labels = {}, loading = {}, mode = mode or "added" })
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
    empty = tab.mode == "ignored" and L:G("No items ignored.") or L:G("No items added yet."),
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
  return tabHeight(self.frame)
end

---@param x number
---@param y number
---@param width number
---@param height number
function itemsTabProto:Place(x, y, width, height)
  placeTab(self, x, y, width, height)
  self:layout()
end

-- readOnlyFor says whether the tab only shows a category's list: the items a plugin added to its
-- category are the plugin's; what a category ignores is always the player's.
---@private
---@param filter CustomCategoryFilter
---@return boolean
function itemsTabProto:readOnlyFor(filter)
  return self.mode == "added" and isPlugins(filter)
end

-- words returns how the tab counts its items ("%d added item", "%d added items").
---@private
---@return string one, string many
function itemsTabProto:words()
  if self.mode == "ignored" then
    return L:G("%d ignored item"), L:G("%d ignored items")
  end
  return L:G("%d added item"), L:G("%d added items")
end

-- listOf returns the chosen category's list for this tab: its items added by hand, or those it ignores.
---@private
---@param name string
---@return table<number, boolean>
function itemsTabProto:listOf(name)
  if self.mode == "ignored" then
    return categories:GetIgnoredItems(name)
  end
  return categories:GetMergedCategory(name).itemList
end

-- Refresh shows the chosen category's list: yours to add to and remove from; a plugin's added items
-- read-only.
---@param ctx? Context
function itemsTabProto:Refresh(ctx)
  local _ = ctx
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local readOnly = self:readOnlyFor(filter)
  self.grid.frame:SetShown(not readOnly)
  self.readOnly.frame:SetShown(readOnly)
  self.removeAll.frame:SetShown(not readOnly)
  if self.mode == "ignored" then
    self.help:SetText(L:G("Drag an item here so it never shows in this category."))
  else
    self.help:SetText(readOnly and L:G("The plugin that made this category adds these items.")
      or L:G("Drag an item here to manually add it to this category."))
  end
  self:ShowItems()
  if self.width then
    self:layout()
  end
end

-- note returns how an item of the list shows: faded with a note for an added item that lands elsewhere
-- (ignored here, or in another category), a note saying where an ignored item in your bags shows.
---@private
---@param name string
---@param itemID number
---@param where? string The category it shows in, for an item in your bags outside this one.
---@return boolean dim, string? note
function itemsTabProto:note(name, itemID, where)
  if self.mode == "ignored" then
    return false, where and format(L:G("Shows in %s."), where) or nil
  end
  if categories:IgnoresItem(name, itemID) then
    return true, L:G("Ignored in this category.")
  end
  return where ~= nil, where and format(L:G("Shows in %s instead."), where) or nil
end

-- ShowItems lists the tab's items, by name, those whose name has the filter's text, each with its
-- note (note). Names not loaded yet are asked for, and the list is shown again once they arrive.
function itemsTabProto:ShowItems()
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local name = filter.name
  local list = self:listOf(name)
  local elsewhere = {}
  bagItemsOf(self.bags(), function(_, _, data)
    local info = data.itemInfo
    local category = info.category or ""
    if list[info.itemID] and not isShownIn(name, category) and elsewhere[info.itemID] == nil then
      elsewhere[info.itemID] = category
    end
  end)
  local needle = strtrim(self.filter:GetText() or ""):lower()
  local all, shown, cold = 0, {}, {}
  for itemID in pairs(list) do
    all = all + 1
    local itemName = C_Item.GetItemNameByID(itemID)
    if itemName == nil then
      table.insert(cold, itemID)
    end
    if needle == "" or (itemName ~= nil and itemName:lower():find(needle, 1, true)) then
      local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
      local dim, note = self:note(name, itemID, elsewhere[itemID])
      table.insert(shown, {
        id = itemID, itemID = itemID, icon = icon, quality = C_Item.GetItemQualityByID(itemID), name = itemName,
        dim = dim, note = note,
      })
    end
  end
  table.sort(shown, byName)
  local one, many = self:words()
  if needle == "" then
    self.count:SetText(count(all, one, many))
  else
    self.count:SetText(format(L:G("%d of %s"), #shown, count(all, one, many)))
  end
  self.removeAll:SetEnabled(all > 0)
  local grid = self:readOnlyFor(filter) and self.readOnly or self.grid
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

-- Drop adds the item on the cursor to the chosen category's list: added to it, or ignored by it.
---@param ctx Context
function itemsTabProto:Drop(ctx)
  local filter = editor:Chosen()
  if filter == nil or self:readOnlyFor(filter) or not CursorHasItem() then
    return
  end
  local kind, itemID = GetCursorInfo()
  if kind ~= "item" then
    return
  end
  if self.mode == "ignored" then
    categories:IgnoreItem(ctx, itemID, editor.selected)
  else
    categories:AddPermanentItemToCategory(ctx, itemID, editor.selected)
  end
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
      if self.mode == "ignored" then
        categories:UnignoreItem(pctx, entry.itemID, editor.selected)
      else
        categories:RemoveItemFromCategory(entry.itemID, editor.selected)
      end
      rederive(pctx)
      self:ShowItems()
    end,
  })
end

-- AskRemoveAll empties the chosen category's list, after asking.
function itemsTabProto:AskRemoveAll()
  local name = editor.selected
  local filter = editor:Chosen()
  if filter == nil then
    return
  end
  local n = 0
  for _ in pairs(self:listOf(name)) do
    n = n + 1
  end
  local one, many = self:words()
  nextDialog:Show(self.owner, {
    title = L:G("Remove All"),
    text = format(L:G("Remove all %s from '%s'? This cannot be undone."), count(n, one, many), name),
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = L:G("Remove All"), style = "Danger", onClick = function(ctx)
        if self.mode == "ignored" then
          categories:ClearIgnoredItems(ctx, name)
        else
          categories:WipeCategory(ctx, name)
        end
        rederive(ctx)
        self:ShowItems()
      end },
    },
  })
end

-- layout puts the count, the filter and Remove All on top, the help under them, and the items taking
-- the room left.
---@private
-- In whole pixels (docs/next-pixel-perfect.md): the top row's parts centered on it by their tops, from
-- the tab's corners; the help's height rounded up.
function itemsTabProto:layout()
  local frame = self.frame
  local m = metricsOf(frame)
  local pad, gap = m.pad, m.gap
  local width = self.width - 2 * pad
  local y = pad
  self.removeAll.frame:ClearAllPoints()
  pixel:Row(self.removeAll.frame, "TOPRIGHT", frame, pad, m.row, nil, y)
  local filterRight = self.removeAll.frame:IsShown() and (pad + self.removeAll.frame:GetWidth() + gap) or pad
  self.filter.frame:ClearAllPoints()
  pixel:Row(self.filter.frame, "TOPRIGHT", frame, filterRight, m.row, nil, y)
  self.count:ClearAllPoints()
  pixel:Row(self.count, "TOPLEFT", frame, pad, m.row, nil, y)
  y = y + m.row + gap
  self.help:ClearAllPoints()
  self.help:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
  self.help:SetWidth(width)
  y = y + pixel:Ceil(frame, self.help:GetStringHeight()) + gap
  for _, grid in ipairs({ self.grid, self.readOnly }) do
    grid.frame:ClearAllPoints()
    grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
    grid:Place(width, math.max(pixel:Unit(frame), self.height - y - pad))
  end
end
