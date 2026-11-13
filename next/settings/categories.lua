local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Database: AceModule
local database = addon:GetModule('Database')

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

---@class NextSettingsItemsTab: AceModule
local itemsTab = addon:GetModule('NextSettingsItemsTab')

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
--   Destroy What Can't Be Sold, which needs Auto Sell on (AutomationOptions), and Auto Deposit, into the
--   bank or the Warbank (DepositOptions), as settings rows.
-- - Added Items: the items added to it by hand, as a grid that holds thousands (NextItemGrid), filtered
--   by name; an item dropped anywhere on it is added, a right click removes one, Remove All asks first.
-- A plugin's category can be used in bags, colored, ordered and automated; its rule (when it has one)
-- and its items show read-only. Under the categories, a heading and the Blizzard categories the backpack
-- shows now, in the same list (category-lifecycle.md §11): one chosen shows what it is and Convert to
-- Category, which makes it yours.
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
local DEPOSITS = { bank = L:G("Deposits in the bank"), warbank = L:G("Deposits in the Warbank") }

-- The banks Deposit Into chooses from, in the dropdown's order, and what each saves (categories:DepositOf).
local BANK_NAMES = { L:G("Bank"), L:G("Warbank") }
local DEPOSIT_OF_NAME = { [L:G("Bank")] = "bank", [L:G("Warbank")] = "warbank" }

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

local count = itemsTab.Count

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
  elseif filter.blizzard then
    -- Blizzard's items show in it whatever was added: nothing added is not nothing in it.
    line = L:G("Converted from Blizzard") .. " · " .. (what == L:G("Nothing in it yet") and L:G("Nothing added yet") or what)
  end
  if DOES[filter.automation] then
    line = line .. " · " .. DOES[filter.automation]
  end
  -- Where there is no Warbank, Auto Deposit puts everything in the bank (Automation:DepositList).
  local deposit = filter.deposit
  if deposit == "warbank" and not addon.hasWarbank then
    deposit = "bank"
  end
  if DEPOSITS[deposit] then
    line = line .. " · " .. DEPOSITS[deposit]
  end
  return line
end

-- isShownIn says whether a section name is a category's own or one of its group by's. A Blizzard category, and one
-- made from it, never groups: a longer Blizzard name ("Consumable - Potion") is not one of its sections.
---@param name string
---@param category string
---@return boolean
local function isShownIn(name, category)
  if category == name then
    return true
  end
  if category:sub(1, #name + 3) ~= name .. " - " then
    return false
  end
  local filter = categories:GetCategoryByName(name)
  return filter ~= nil and not filter.blizzard
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

-- eachBlizzard calls fn with the Blizzard category of every item the backpack shows in one (asked, issue #1278: "only
-- for categories currently visible in the backpack"), until fn returns true: a section no category has, holding items
-- where BetterBags puts what no category takes (Items:BuiltInCategory). Not Recent Items or a gear set, nor a category
-- just deleted or renamed, whose items keep its name until the bags are recalculated. Only the items the backpack's
-- sections show (a stack's largest pile, not those it hides: SlotInfo:GetVisibleItems), none in Show Bags, whose
-- sections are the bags.
---@param fn fun(name: string): boolean?
local function eachBlizzard(fn)
  local kind = const.BAG_KIND.BACKPACK
  local slotInfo = items.slotInfo and items.slotInfo[kind]
  if slotInfo == nil or database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    return
  end
  for _, data in pairs(slotInfo.visibleItemsBySlotKey or slotInfo.itemsBySlotKey or {}) do
    local name = not data.isItemEmpty and data.itemInfo and data.itemInfo.category
    if name and name ~= "" and items:BuiltInCategory(data) == name and not categories:DoesCategoryExist(name) then
      if fn(name) then
        return
      end
    end
  end
end

-- blizzardNames returns the Blizzard categories the backpack shows, by name, those whose name has needle.
---@param needle string
---@return string[]
local function blizzardNames(needle)
  local set, names = {}, {}
  eachBlizzard(function(name)
    if not set[name] and (needle == "" or name:lower():find(needle, 1, true)) then
      set[name] = true
      table.insert(names, name)
    end
  end)
  table.sort(names)
  return names
end

-- Chosen returns the category chosen.
---@return CustomCategoryFilter?
function editor:Chosen()
  return self.selected and categories:GetCategoryByName(self.selected) or nil
end

-- BlizzardChosen says whether the one chosen is a Blizzard category the backpack shows.
---@return boolean
function editor:BlizzardChosen()
  local found = false
  if self.selected ~= nil then
    eachBlizzard(function(name)
      found = name == self.selected
      return found
    end)
  end
  return found
end

-- EnsureChosen chooses the first category when none is, or the one chosen is gone.
function editor:EnsureChosen()
  if self:Chosen() ~= nil or self:BlizzardChosen() then
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

-- Show chooses a category for the next time the page shows (a bag's Order tab opens it here).
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
    if self:BlizzardChosen() then
      return self.selected, L:G("Made by Blizzard")
    end
    return L:G("Categories"), L:G("Make a category to sort your items your way.")
  end
  return self.selected, describe(filter)
end

-- SettingsTabShown says whether the Settings tab shows: for anything but a Blizzard category, which shows what it is
-- instead (BlizzardHelp, Convert).
---@return boolean
function editor:SettingsTabShown()
  return not self:BlizzardChosen()
end

-- BlizzardHelp says what the Blizzard category chosen is, and what making it yours does.
---@return string
function editor:BlizzardHelp()
  return format(L:G("%s is a built-in category that BetterBags creates from Blizzard's item types. Convert it to your "
    .. "own category to customize it. Its items will still show up in it, and you'll be able to change its color, hide "
    .. "it, auto-sell or auto-deposit its items, add or ignore items, and give it a search rule. Converted categories "
    .. "can't be grouped."), self.selected or "")
end

-- Convert makes the Blizzard category chosen yours (Categories:Convert), the bags recalculated, and shows it.
---@param ctx Context
function editor:Convert(ctx)
  local name = self.selected
  if name == nil then
    return
  end
  categories:Convert(ctx, name)
  rederive(ctx)
  self:Choose(ctx, name)
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
      description = L:G("At a vendor, this category's section waits there to be sold with a double click (BetterBags Next's vendor window; without it, sell it by right-clicking its title). Turned off, it is sold as soon as the vendor opens."),
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

-- DepositOptions returns the Automation tab's Bank settings (automation.md §7), a section of their own,
-- independent of the merchant settings: Auto Deposit (on saves "bank"), and Deposit Into, the bank or the
-- Warbank, disabled while Auto Deposit is off. Each saves at once and shows the page's rows again.
---@return NextSettingsOption[]
function editor:DepositOptions()
  local function deposit()
    local filter = self:Chosen()
    return filter and filter.deposit
  end
  local function save(ctx, value)
    if self.selected then
      categories:UpdateCategory(ctx, self.selected, { deposit = value })
    end
    settings:Refresh(ctx)
  end
  return {
    {
      kind = "toggle",
      title = L:G("Auto Deposit"),
      description = L:G("Deposit this category's items in your bank when you open it. Hold Shift to keep them."),
      keywords = { "automation", "deposit", "bank", "warbank", "store" },
      get = function() return deposit() ~= nil end,
      set = function(ctx, on) save(ctx, on and "bank" or false) end,
    },
    {
      kind = "dropdown",
      title = L:G("Deposit Into"),
      description = L:G("The bank Auto Deposit puts this category's items in: yours, or the Warbank. Items the Warbank does not take stay in your bags."),
      keywords = { "automation", "deposit", "bank", "warbank", "account" },
      items = BANK_NAMES,
      disabled = function() return deposit() == nil end,
      get = function() return deposit() == "warbank" and L:G("Warbank") or L:G("Bank") end,
      set = function(ctx, name) save(ctx, DEPOSIT_OF_NAME[name]) end,
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

-- holds says whether an item shown in a bag under a name is that name's: a category of yours holds the items of the
-- bags that use it (elsewhere a section of its name is Blizzard's, category-lifecycle.md §11), a Blizzard category
-- every item of its name.
---@param name string
---@param bag SettingBag
---@return boolean
local function holds(name, bag)
  return categories:GetCategoryByName(name) == nil or categories:CategoryIn(name, bag.kind) ~= nil
end

-- matchingCounts returns how many items each category holds in bags, as its Settings tab's Current Items
-- in this Group lists them: each item once, its group by's sections with it (isShownIn: an item in
-- "Potions - Flask" counts for Potions), in the bags that use it (holds). One pass: an item counts for its
-- category and for every name that category is a section of.
---@param bags SettingBag[]
---@return table<string, number>
local function matchingCounts(bags)
  local seen, counts = {}, {}
  bagItemsOf(bags, function(bag, _, data)
    local id = data.itemInfo.itemID
    local category = data.itemInfo.category
    local name = category
    while name ~= nil and name ~= "" do
      seen[name] = seen[name] or {}
      if not seen[name][id] and isShownIn(name, category) and holds(name, bag) then
        seen[name][id] = true
        counts[name] = (counts[name] or 0) + 1
      end
      name = name:match("^(.*) %- ")
    end
  end)
  return counts
end

local byName = itemsTab.ByName

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
---@field entries table[] { name } for each category in their order, then { header = true, title } and { name, blizzard = true } for each Blizzard category
---@field managed number How many of the entries are categories (the ones that can be dragged), before the Blizzard ones.
---@field rows NextCategoryListRow[] The rows of the entries, in the same order.
---@field byName table<string|table, NextCategoryListRow> Each category's own row (moved in the order, it slides), and the heading's.
---@field free NextCategoryListRow[] Rows no category has, hidden, to reuse.
---@field drag NextListReorderList Arranges the rows; dragging one moves its category in the order.
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextCategoryList')

-- The Blizzard categories' heading's row is kept under a table of its own, a key no category's name can be.
local HEADING = {}

-- keyOf returns the key of the row an entry has: its category's name, or the heading's.
---@param entry table
---@return string|table
local function keyOf(entry)
  return entry.header and HEADING or entry.name
end

-- CreateList makes the page's list (pages.lua sidebar).
---@param parent Frame
---@param owner Frame The window its dialogs show over.
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategoryList
function editor:CreateList(parent, owner, bags)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextCategoryList
  local list = setmetatable({ frame = frame, owner = owner, bags = bags, entries = {}, managed = 0, rows = {},
    byName = {}, free = {} }, { __index = listProto })
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
  pixel:SnapScroll(box)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(38)
  box:Init(view)
  list.bar = nextScrollBar:Create(box)
  list.bar:Bind(box)
  list.box, list.content = box, content
  -- A category lands among the categories, never among Blizzard's under them: they have no place in the order.
  list.drag = reorder:Create({
    box = box, content = content,
    entries = function() return list.entries end,
    rowOf = function(entry) return list.byName[keyOf(entry)].frame end,
    heightOf = function(entry)
      local K = style.Theme.Settings.Categories
      return pixel:Length(frame, entry.header and K.GroupHeight or K.RowHeight)
    end,
    last = function() return list.managed end,
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
  -- A bag's items were read: what each category holds may have changed, and the Blizzard category chosen may
  -- have left the backpack, another one chosen for it.
  for _, message in ipairs(BAG_READ) do
    events:RegisterMessage(message, function(ctx)
      if frame:IsVisible() then
        local chosen = editor.selected
        editor:EnsureChosen()
        list:RefreshRows()
        if editor.selected ~= chosen then
          settings:Reselect(ctx)
        end
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

-- RefreshRows lists the categories whose name has the filter's text, in their order, then under a heading the
-- Blizzard categories the backpack shows whose name has it, by name, in the same list (asked, issue #1278: "it's one
-- big scroll list, not two").
function listProto:RefreshRows()
  local needle = strtrim(self.filter:GetText() or ""):lower()
  local entries = {}
  for _, name in ipairs(ordered(needle)) do
    table.insert(entries, { name = name })
  end
  self.managed = #entries
  local blizzard = blizzardNames(needle)
  if #blizzard > 0 then
    table.insert(entries, { header = true, title = L:G("Blizzard Categories") })
    for _, name in ipairs(blizzard) do
      table.insert(entries, { name = name, blizzard = true })
    end
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
  for i = 1, self.managed do
    local entry = self.entries[i]
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

-- rowFor returns an entry's own row, taking one no entry has, or making one, the first time.
---@private
---@param entry table
---@return NextCategoryListRow
function listProto:rowFor(entry)
  local key = keyOf(entry)
  local row = self.byName[key]
  if row == nil then
    row = table.remove(self.free) or self:newRow()
    self.byName[key] = row
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
  -- A Blizzard category has no place in the order to drag it to.
  addon.SetScript(frame, "OnDragStart", function()
    if row.entry and row.entry.name and not row.entry.blizzard then
      self.drag:Start(row.entry.name)
    end
  end)
  return row
end

-- layoutRows shows each entry listed in its own row: a category RowHeight tall, saying how many of the shown bags'
-- items it holds (asked: "x items matching"), a Blizzard category marked as Blizzard's, the heading GroupHeight tall;
-- and puts the rows of those no longer listed away; the list's arrangement places them (NextListReorder: a row that moved slides).
---@private
function listProto:layoutRows()
  local K = style.Theme.Settings.Categories
  local listed = {}
  local counts = matchingCounts(self.bags())
  self.rows = {}
  for i, entry in ipairs(self.entries) do
    local row = self:rowFor(entry)
    listed[keyOf(entry)] = true
    self.rows[i] = row
    row.entry = entry
    row.frame:EnableMouse(entry.header ~= true)
    if entry.header then
      row.frame:SetHeight(pixel:Length(self.frame, K.GroupHeight))
      row.label:SetText(string.upper(entry.title))
      row.detail:SetText("")
    else
      row.frame:SetHeight(pixel:Length(self.frame, K.RowHeight))
      local filter = categories:GetCategoryByName(entry.name)
      row.label:SetText(entry.name)
      local matching = count(counts[entry.name] or 0, L:G("%d item matching"), L:G("%d items matching"))
      row.detail:SetText(entry.blizzard and (L:G("Blizzard") .. " · " .. matching) or matching)
      local c = filter and filter.color or GOLD
      row.dot:SetColorTexture(c[1], c[2], c[3], 1)
    end
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

-- paintRow draws a row: its category chosen, under the pointer, or neither; the heading as a bag's Order tab draws
-- its headings, its name above its bottom.
---@private
---@param row NextCategoryListRow
function listProto:paintRow(row)
  local K, SB = style.Theme.Settings.Categories, style.Theme.Settings.Sidebar
  local entry = row.entry
  row.label:ClearAllPoints()
  row.detail:ClearAllPoints()
  if entry == nil or entry.header then
    row.fill:Hide()
    row.hover:Hide()
    row.indicator:Hide()
    row.dot:Hide()
    row.detail:Hide()
    if entry ~= nil then
      style:SetFont(row.label, K.GroupFont)
      pixel:Point(row.label, "BOTTOMLEFT", row.frame, "BOTTOMLEFT", pixel:Snap(row.frame, SB.Pad), pixel:Snap(row.frame, 4))
    end
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
  pixel:Point(row.label, "TOPLEFT", frame, "TOPLEFT", left, -top)
  pixel:Point(row.label, "TOPRIGHT", frame, "TOPRIGHT", -pad, -top)
  local detailTop = top + nameHeight + between
  pixel:Point(row.detail, "TOPLEFT", frame, "TOPLEFT", left, -detailTop)
  pixel:Point(row.detail, "TOPRIGHT", frame, "TOPRIGHT", -pad, -detailTop)
  row.detail:Show()
  controls:Paint(row.fill, chosen and K.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and K.HoverFill or false)
  row.indicator:ClearAllPoints()
  row.indicator:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
  row.indicator:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
  -- A theme may draw no bar (Indicator = false: Blizzard's list marks the chosen row with its fill).
  local bar = K.Indicator
  pixel:Width(row.indicator, bar and bar.Width or 1)
  controls:Paint(row.indicator, (chosen and bar) and { Color = bar.Color } or false)
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

-- AskRename renames the chosen category, keeping it chosen, or says why it cannot. Renaming one made from a Blizzard
-- category makes it a new category (asked: "accept with a warning that it's making a new category technically").
function actionsProto:AskRename()
  local current = editor.selected
  if current == nil then
    return
  end
  local filter = editor:Chosen()
  local text = format(L:G("Rename the category '%s' to:"), current)
  if filter and filter.blizzard then
    text = format(L:G("Renaming '%s' turns it into a separate category. Blizzard's items will go back to the built-in "
      .. "'%s' category, and only your changes move to the new name. Rename it to:"), current, current)
  end
  askName(self.owner, L:G("Rename Category"), text, L:G("Rename"),
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

---@param frame Frame
---@return number
local function tabHeight(frame)
  return itemsTab:TabHeight(frame)
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

---@param frame Frame
---@return {pad: number, gap: number, row: number, labelWidth: number}
local function metricsOf(frame)
  return itemsTab:Metrics(frame)
end

-- boxRows returns where the Settings and Search Rule tabs put their item box's name row and the box,
-- down from the tab's top: under four rows of settings, the same in both, so the box stays put as the
-- tabs change (asked).
---@param frame Frame
---@return number nameRow, number box
local function boxRows(frame)
  local m = metricsOf(frame)
  local row = m.pad + 4 * (m.row + m.gap) + m.gap
  return row, row + m.row + m.gap
end

---@param tab table
---@param x number
---@param y number
---@param width number
---@param height number
local function placeTab(tab, x, y, width, height)
  itemsTab:PlaceTab(tab, x, y, width, height)
end

-- The Blizzard tab: what a Blizzard category is and the button that makes it yours, centered in the whole tab
-- (asked, issue #1278: the text "bigger", the button "in the middle of that panel entirely").

---@class NextCategoryBlizzardTab
---@field frame Frame
---@field wide boolean
---@field text FontString
---@field convert NextButtonFrame
---@field width? number
---@field height? number
local blizzardTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(blizzardTabProto, 'NextCategoryBlizzardTab')

---@param parent Frame
---@param owner Frame
---@return NextCategoryBlizzardTab
function editor:CreateBlizzardTab(parent, owner)
  local _ = owner
  local tab = makeTab(parent, blizzardTabProto, {})
  tab.text = style:CreateText(tab.frame, style.Theme.Settings.Categories.LeadFont)
  tab.text:SetJustifyH("CENTER")
  tab.text:SetWordWrap(true)
  tab.convert = nextButton:Create(tab.frame, {
    text = L:G("Convert to Category"), onClick = function(ctx) editor:Convert(ctx) end,
  })
  tab:Style()
  return tab
end

-- Style draws the tab from the theme, its button sized for it first: it is centered by its width, and themes restyle
-- their widgets in no set order.
function blizzardTabProto:Style()
  style:SetFont(self.text, style.Theme.Settings.Categories.LeadFont)
  self.convert:Style()
  if self.width then
    self:layout()
  end
end

---@param width number
---@return number
function blizzardTabProto:Measure(width)
  local _ = width
  return tabHeight(self.frame)
end

---@param x number
---@param y number
---@param width number
---@param height number
function blizzardTabProto:Place(x, y, width, height)
  placeTab(self, x, y, width, height)
  self:layout()
end

-- Refresh says what the Blizzard category chosen is.
---@param ctx? Context
function blizzardTabProto:Refresh(ctx)
  local _ = ctx
  self.text:SetText(editor:BlizzardHelp())
  if self.width then
    self:layout()
  end
end

-- layout centers the text, at most LeadWidth wide, and the button under it, two FieldGaps apart, across the tab and
-- together down it, in whole pixels (docs/next-pixel-perfect.md).
---@private
function blizzardTabProto:layout()
  local frame = self.frame
  local K = style.Theme.Settings.Categories
  local m = metricsOf(frame)
  local width = pixel:Floor(frame, math.max(1, math.min(self.width - 2 * m.pad, K.LeadWidth)))
  self.text:SetWidth(width)
  local textHeight = pixel:Ceil(frame, self.text:GetStringHeight())
  local button = self.convert.frame
  local gap = 2 * m.gap
  local top = pixel:Middle(frame, self.height, textHeight + gap + button:GetHeight())
  self.text:ClearAllPoints()
  pixel:Point(self.text, "TOPLEFT", frame, "TOPLEFT", pixel:Middle(frame, self.width, width), -top)
  button:ClearAllPoints()
  pixel:Point(button, "TOPLEFT", frame, "TOPLEFT", pixel:Middle(frame, self.width, button:GetWidth()),
    -(top + textHeight + gap))
end

-- The Settings tab.

---@class NextCategorySettingsTab
---@field frame Frame
---@field wide boolean
---@field bags fun(): SettingBag[]
---@field labels table<string, FontString>
---@field toggles table<BagKind, NextToggleFrame>
---@field toggleLabels table<BagKind, FontString>
---@field hideToggles table<BagKind, NextToggleFrame>
---@field hideLabels table<BagKind, FontString>
---@field owner Frame
local settingsTabProto = {}
addon:GetModule('Perf'):RegisterPrototype(settingsTabProto, 'NextCategorySettingsTab')

---@param parent Frame
---@param owner Frame
---@param bags fun(): SettingBag[] The bags the settings show.
---@return NextCategorySettingsTab
function editor:CreateSettingsTab(parent, owner, bags)
  local tab = makeTab(parent, settingsTabProto, { bags = bags, owner = owner, labels = {}, toggles = {},
    toggleLabels = {}, hideToggles = {}, hideLabels = {} })
  local K = style.Theme.Settings.Categories
  local frame = tab.frame
  tab.none = style:CreateText(frame, K.TextFont)
  tab.none:SetText(L:G("You have no categories yet. Make one with New Category, under the list."))
  label(tab, "bags", L:G("Used In"))
  label(tab, "hide", L:G("Hide In"))
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
  for _, l in pairs(self.hideLabels) do
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

-- hideToggleFor returns a bag's Hide In switch, made the first time it is needed.
---@private
---@param bag SettingBag
---@return NextToggleFrame
function settingsTabProto:hideToggleFor(bag)
  local toggle = self.hideToggles[bag.kind]
  if toggle == nil then
    toggle = nextToggle:Create(self.frame, {
      onChange = function(ctx, on)
        if on then
          self:askHide(bag)
        else
          self:update(ctx, { hidden = { [bag.kind] = false } })
        end
      end,
    })
    self.hideToggles[bag.kind] = toggle
    self.hideLabels[bag.kind] = style:CreateText(self.frame, style.Theme.Settings.Categories.TextFont)
  end
  self.hideLabels[bag.kind]:SetText(L:G(bag.name))
  return toggle
end

-- askHide asks before hiding: hiding a category used to leave players wondering where their items went.
-- Closing the question any other way answers Cancel (NextDialog).
---@private
---@param bag SettingBag
function settingsTabProto:askHide(bag)
  local name = editor.selected
  nextDialog:Show(self.owner, {
    title = format(L:G("Hide %s?"), name),
    text = format(L:G("Its items will not show in your %s. They stay in your bags, and the bag's footer says how "
      .. "many are hidden. Turn this off to see them again."), L:G(bag.name)),
    buttons = {
      { text = L:G("Cancel"), onClick = function() self.hideToggles[bag.kind]:SetChecked(false) end },
      { text = L:G("Hide"), style = "Primary", onClick = function(ctx)
        self:update(ctx, { hidden = { [bag.kind] = true } })
      end },
    },
  })
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
    local used = filter ~= nil and filter.enabled ~= nil and filter.enabled[bag.kind] ~= false
    toggle:SetChecked(used)
    local hide = self:hideToggleFor(bag)
    hide:SetChecked(filter ~= nil and filter.hidden ~= nil and filter.hidden[bag.kind] == true)
    hide:SetEnabled(used)
    shown[bag.kind] = filter ~= nil
  end
  for kind, toggle in pairs(self.toggles) do
    toggle.frame:SetShown(shown[kind] == true)
    self.toggleLabels[kind]:SetShown(shown[kind] == true)
    self.hideToggles[kind].frame:SetShown(shown[kind] == true)
    self.hideLabels[kind]:SetShown(shown[kind] == true)
  end
  for _, part in ipairs({ self.labels.bags, self.labels.hide, self.labels.color, self.swatch.frame, self.resetColor.frame, self.labels.inBags, self.inBags, self.grid.frame }) do
    part:SetShown(filter ~= nil)
  end
  -- A category made from a Blizzard category never groups (asked, issue #1278).
  for _, part in ipairs({ self.labels.groupBy, self.groupBy.frame, self.groupByHint }) do
    part:SetShown(yours and not filter.blizzard)
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

-- showInBags shows what of your bags shows in a category now (its group by's sections too), in the bags
-- that use it (holds): how many items in each bag, and the items, one cell per item with how many there are.
---@private
---@param name string
function settingsTabProto:showInBags(name)
  local perBag, order, byItem, list = {}, {}, {}, {}
  bagItemsOf(self.bags(), function(bag, _, data)
    local info = data.itemInfo
    if not isShownIn(name, info.category or "") or not holds(name, bag) then
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

-- layout puts the settings in four rows (the bags it is used in, the bags it is hidden in, group by, color;
-- group by's row left empty for a plugin's), then the current items in their box, where the Search Rule tab
-- puts its own.
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
  pixel:Point(self.none, "TOPLEFT", frame, "TOPLEFT", 0, -noneTop)
  pixel:Point(self.none, "TOPRIGHT", frame, "TOPRIGHT", 0, -noneTop)
  -- rowTop is how far down a row (1 to 4) of settings starts.
  local function rowTop(i)
    return pad + (i - 1) * (m.row + gap)
  end
  -- at puts a region x across in a row starting top down, centered on the row's height.
  local function at(region, x, top)
    region:ClearAllPoints()
    pixel:Row(region, "TOPLEFT", frame, x, m.row, nil, top)
  end
  -- switches puts a switch per bag along a row, each with its bag's name.
  local function switches(row, toggles, labels)
    local x = pad + m.labelWidth
    for _, bag in ipairs(self.bags()) do
      local toggle, text = toggles[bag.kind], labels[bag.kind]
      if toggle and toggle.frame:IsShown() then
        at(toggle.frame, x, rowTop(row))
        local textX = x + toggle.frame:GetWidth() + pixel:Snap(frame, 6)
        at(text, textX, rowTop(row))
        x = textX + pixel:Ceil(frame, text:GetStringWidth()) + 2 * gap
      end
    end
  end
  at(self.labels.bags, pad, rowTop(1))
  switches(1, self.toggles, self.toggleLabels)
  at(self.labels.hide, pad, rowTop(2))
  switches(2, self.hideToggles, self.hideLabels)
  at(self.labels.groupBy, pad, rowTop(3))
  at(self.groupBy.frame, pad + m.labelWidth, rowTop(3))
  at(self.groupByHint, pad + m.labelWidth + self.groupBy.frame:GetWidth() + gap, rowTop(3))
  at(self.labels.color, pad, rowTop(4))
  at(self.swatch.frame, pad + m.labelWidth, rowTop(4))
  at(self.resetColor.frame, pad + m.labelWidth + self.swatch.frame:GetWidth() + gap, rowTop(4))
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

-- The Added Items and Ignored Items tabs: the shared items tab (NextSettingsItemsTab) over the chosen category's lists.

-- CreateItemsTab makes a tab of a category's items: those added by hand (Added Items), or with mode "ignored" those
-- it ignores (Ignored Items, docs/next-batch-2.md §2; asked: "same interface/layout as Added Items"). A plugin's added
-- items show read-only; what a category ignores is always the player's. An added item that lands elsewhere (ignored
-- here, or in another category) is faded with a note; an ignored item in your bags says where it shows.
---@param parent Frame
---@param owner Frame The window its dialogs and menus show over.
---@param bags fun(): SettingBag[] The bags the settings show.
---@param mode? "added"|"ignored"
---@return NextItemsTab
function editor:CreateItemsTab(parent, owner, bags, mode)
  local ignored = mode == "ignored"
  ---@type NextItemsSource
  local source = {
    key = function()
      return editor:Chosen() ~= nil and editor.selected or nil
    end,
    list = function(name)
      if ignored then
        return categories:GetIgnoredItems(name)
      end
      return categories:GetMergedCategory(name).itemList
    end,
    readOnly = function(name)
      return not ignored and isPlugins(categories:GetCategoryByName(name))
    end,
    help = function(_, readOnly)
      if ignored then
        return L:G("Drag an item here so it never shows in this category.")
      end
      return readOnly and L:G("The plugin that made this category adds these items.")
        or L:G("Drag an item here to manually add it to this category.")
    end,
    words = function()
      if ignored then
        return L:G("%d ignored item"), L:G("%d ignored items")
      end
      return L:G("%d added item"), L:G("%d added items")
    end,
    empty = ignored and L:G("No items ignored.") or L:G("No items added yet."),
    readOnlyEmpty = L:G("The plugin added no items."),
    notes = function(name, list)
      local elsewhere = {}
      bagItemsOf(bags(), function(_, _, data)
        local info = data.itemInfo
        local category = info.category or ""
        if list[info.itemID] and not isShownIn(name, category) and elsewhere[info.itemID] == nil then
          elsewhere[info.itemID] = category
        end
      end)
      local notes = {}
      for itemID in pairs(list) do
        local where = elsewhere[itemID]
        if ignored then
          notes[itemID] = { dim = false, note = where and format(L:G("Shows in %s."), where) or nil }
        elseif categories:IgnoresItem(name, itemID) then
          notes[itemID] = { dim = true, note = L:G("Ignored in this category.") }
        else
          notes[itemID] = { dim = where ~= nil, note = where and format(L:G("Shows in %s instead."), where) or nil }
        end
      end
      return notes
    end,
    add = function(ctx, name, itemID)
      if ignored then
        categories:IgnoreItem(ctx, itemID, name)
      else
        categories:AddPermanentItemToCategory(ctx, itemID, name)
      end
      rederive(ctx)
      return true
    end,
    remove = function(ctx, name, itemID)
      if ignored then
        categories:UnignoreItem(ctx, itemID, name)
      else
        categories:RemoveItemFromCategory(itemID, name)
      end
      rederive(ctx)
    end,
    clear = function(ctx, name)
      if ignored then
        categories:ClearIgnoredItems(ctx, name)
      else
        categories:WipeCategory(ctx, name)
      end
      rederive(ctx)
    end,
    clearText = function(name, counted)
      return format(L:G("Remove all %s from '%s'? This cannot be undone."), counted, name)
    end,
  }
  return itemsTab:Create(parent, owner, source)
end
