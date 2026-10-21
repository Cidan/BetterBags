local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Bucket: AceModule
local bucket = addon:GetModule('Bucket')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- SettingsCatalog defines every setting once (docs/next-settings.md): its kind, name, description,
-- choices or range, how it is read and written, and what it sends so the bags show it. Both settings
-- windows build their rows from it: the classic one (config/config.lua) and BetterBags Next's
-- (next/settings/). A bag's settings are bound to a bag when they are asked for (Get(id, bag)).
---@class SettingsCatalog: AceModule
---@field private defs table<string, SettingDefinition>
---@field private order string[]
local catalog = addon:NewModule('SettingsCatalog')

---@alias SettingKind "toggle"|"dropdown"|"slider"

-- A bag with settings of its own.
---@class (exact) SettingBag
---@field name string "Backpack", "Bank" or "Guild Bank".
---@field kind BagKind

-- How a setting is defined. A bag's setting (bag = true) gets the bag in every function, a text
-- naming it may be a function of it, and only (when set) lists the kinds of bag that have it.
---@class (exact) SettingDefinition
---@field kind SettingKind
---@field bag? boolean
---@field only? BagKind[]
---@field title string
---@field description string|fun(bag: SettingBag): string
---@field keywords? string[] Words a search finds it by, beside its name and description.
---@field items? string[] A dropdown's choices.
---@field itemsFunction? fun(ctx: Context): string[] A dropdown's choices, read each time the menu opens.
---@field min? number
---@field max? number
---@field step? number
---@field reload? boolean It takes effect after a reload.
---@field get fun(ctx: Context, bag?: SettingBag): any A toggle's boolean, a choice's item, a number.
---@field set fun(ctx: Context, value: any, bag?: SettingBag): boolean? False when the change was refused.

-- A setting as a window reads it, bound to its bag.
---@class (exact) SettingOption
---@field id string
---@field kind SettingKind
---@field title string
---@field description string
---@field keywords string[]
---@field items? string[]
---@field itemsFunction? fun(ctx: Context): string[]
---@field min? number
---@field max? number
---@field step? number
---@field reload? boolean
---@field get fun(ctx: Context): any
---@field set fun(ctx: Context, value: any): boolean?

-- What a window does around a change: ask for a reload, show the settings again.
---@class (exact) SettingHooks
---@field reload? fun()
---@field refresh? fun()

catalog.defs = {}
catalog.order = {}

---@param id string
---@param def SettingDefinition
local function define(id, def)
  if catalog.defs[id] ~= nil then
    error("the settings catalog defines " .. id .. " twice")
  end
  catalog.defs[id] = def
  table.insert(catalog.order, id)
end

-- A change most settings make to what the data phase works out (refresh-scheduler.md §10).
---@param ctx Context
local function rederive(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

---@param bag SettingBag
---@return string
local function lower(bag)
  return string.lower(bag.name)
end

-- Bags returns the bags with settings of their own: the backpack, the bank, and the guild bank
-- (BetterBags Next's, guild-bank.md §5) on a client with one.
---@return SettingBag[]
function catalog:Bags()
  local bags = {
    { name = 'Backpack', kind = const.BAG_KIND.BACKPACK },
    { name = 'Bank', kind = const.BAG_KIND.BANK },
  }
  if addon.hasGuildBank then
    table.insert(bags, { name = 'Guild Bank', kind = const.BAG_KIND.GUILD })
  end
  return bags
end

-- Ids returns every setting's id, in the order they are defined.
---@return string[]
function catalog:Ids()
  local ids = {}
  for i, id in ipairs(self.order) do
    ids[i] = id
  end
  return ids
end

-- Has says whether a setting exists, for a bag when given: a setting limited to some kinds of bag
-- (only) is not another bag's.
---@param id string
---@param bag? SettingBag
---@return boolean
function catalog:Has(id, bag)
  local def = self.defs[id]
  if def == nil then
    return false
  end
  if def.only ~= nil and bag ~= nil then
    for _, kind in ipairs(def.only) do
      if kind == bag.kind then
        return true
      end
    end
    return false
  end
  return true
end

-- Get returns a setting as a window reads it, bound to bag for a bag's setting.
---@param id string
---@param bag? SettingBag
---@return SettingOption
function catalog:Get(id, bag)
  local def = self.defs[id]
  if def == nil then
    error("the settings catalog has no setting named " .. tostring(id))
  end
  if def.bag and bag == nil then
    error("the setting " .. id .. " belongs to a bag")
  end
  if not def.bag and bag ~= nil then
    error("the setting " .. id .. " belongs to no bag")
  end
  if not self:Has(id, bag) then
    error("the " .. lower(bag) .. " has no setting " .. id)
  end
  local description = def.description
  if type(description) == "function" then
    description = description(bag)
  end
  return {
    id = id,
    kind = def.kind,
    title = def.title,
    description = description,
    keywords = def.keywords or {},
    items = def.items,
    itemsFunction = def.itemsFunction,
    min = def.min,
    max = def.max,
    step = def.step,
    reload = def.reload,
    get = function(ctx) return def.get(ctx, bag) end,
    set = function(ctx, value) return def.set(ctx, value, bag) end,
  }
end

-- Form returns a setting as the classic window's form takes it (forms/layouts/layout.lua): a
-- choice's getValue tests an item. After a change it asks for a reload (hooks.reload) for a setting
-- that needs one, and shows the settings again (hooks.refresh) when the change was refused.
---@param id string
---@param bag? SettingBag
---@param hooks? SettingHooks
---@return table
function catalog:Form(id, bag, hooks)
  local setting = self:Get(id, bag)
  local opts = {
    title = setting.title,
    description = setting.description,
    setValue = function(ctx, value)
      local applied = setting.set(ctx, value)
      if applied == false then
        if hooks and hooks.refresh then hooks.refresh() end
        return
      end
      if setting.reload and hooks and hooks.reload then
        hooks.reload()
      end
    end,
  }
  if setting.kind == "dropdown" then
    opts.items = setting.items
    opts.itemsFunction = setting.itemsFunction
    opts.getValue = function(ctx, value) return setting.get(ctx) == value end
  else
    opts.getValue = setting.get
  end
  if setting.kind == "slider" then
    opts.min, opts.max, opts.step = setting.min, setting.max, setting.step
  end
  return opts
end

--[[
-- General
]]--

define('inBagSearch', {
  kind = "toggle",
  title = 'Enable In-Bag Search',
  description = 'If enabled, a search bar will appear at the top of your bags.',
  keywords = { 'search box', 'filter' },
  get = function() return db:GetInBagSearch() end,
  set = function(ctx, value)
    db:SetInBagSearch(value)
    events:SendMessage(ctx, 'search/SetInFrame', value)
  end,
})

define('enterToMakeCategory', {
  kind = "toggle",
  title = 'Enable Enter to Make Category',
  description = 'If enabled, pressing Enter with a search query will open the make category menu.',
  keywords = { 'search', 'category', 'enter key' },
  get = function() return db:GetEnterToMakeCategory() end,
  set = function(_, value) db:SetEnterToMakeCategory(value) end,
})

define('categorySell', {
  kind = "toggle",
  title = 'Enable Category Sell and Deposit',
  description = 'If enabled, right-clicking a category header at an NPC shop will sell all its contents, or deposit to bank.',
  keywords = { 'vendor', 'merchant', 'sell', 'bank', 'deposit', 'right click' },
  get = function() return db:GetCategorySell() end,
  set = function(_, value) db:SetCategorySell(value) end,
})

define('showBagButton', {
  kind = "toggle",
  title = 'Show Blizzard Bag Button',
  description = 'Show or hide the default Blizzard bag button.',
  keywords = { 'bag bar', 'micro menu', 'backpack button' },
  get = function() return db:GetShowBagButton() end,
  set = function(_, value)
    db:SetShowBagButton(value)
    local sneakyFrame = _G["BetterBagsSneakyFrame"] ---@type Frame
    if value then
      BagsBar:SetParent(UIParent)
    else
      BagsBar:SetParent(sneakyFrame)
    end
  end,
})

define('enableBankBags', {
  kind = "toggle",
  title = 'Enable Bank Bags',
  description = 'Enable BetterBags for bank. If disabled, the default Blizzard bank UI will be used. Requires a UI reload to take effect.',
  keywords = { 'bank', 'blizzard bank', 'reload' },
  reload = true,
  get = function() return db:GetEnableBankBag() end,
  set = function(_, value) db:SetEnableBankBag(value) end,
})

define('bagFading', {
  kind = "toggle",
  title = 'Enable Bag Fading',
  description = 'If enabled, bags will smoothly fade in and out when opening/closing.',
  keywords = { 'fade', 'animation' },
  get = function() return db:GetEnableBagFading() end,
  set = function(_, value) db:SetEnableBagFading(value) end,
})

define('animateItemMovement', {
  kind = "toggle",
  title = 'Animate Item Movement',
  description = 'If enabled, items, sections and rows glide to their new places when the bags rearrange (sorting, looting, resizing).',
  keywords = { 'animation', 'motion', 'glide' },
  get = function() return db:GetAnimateItemMovement() end,
  set = function(_, value) db:SetAnimateItemMovement(value) end,
})

define('nextEnabled', {
  kind = "toggle",
  title = 'BetterBags Next (experimental)',
  description = 'An experimental new backpack: a panel that slides in from the right edge of the screen, '
    .. 'with tabs down its side and your categories in one column. Switches at once, outside combat, '
    .. 'the bank and vendors.',
  keywords = { 'next', 'design', 'classic bags', 'original' },
  get = function() return db:GetNextEnabled() end,
  -- A switch refused (combat, the bank, a vendor) leaves the setting as it was.
  set = function(ctx, value)
    return addon:GetModule('BagSystem'):Switch(ctx, value and "next" or "classic") and true or false
  end,
})

define('upgradeProvider', {
  kind = "dropdown",
  title = 'Upgrade Icon Provider',
  description = 'Select the icon provider for item upgrades.',
  keywords = { 'upgrade', 'arrow', 'pawn', 'simple item level' },
  itemsFunction = function()
    local list = {'None', 'BetterBags'}
    local itemsModule = addon:GetModule('Items')
    if itemsModule and itemsModule.upgradeProviders then
      for provider in pairs(itemsModule.upgradeProviders) do
        if provider ~= 'BetterBags' then
          table.insert(list, provider)
        end
      end
    end
    return list
  end,
  -- The provider actually in effect (which may be an external provider taking precedence when the
  -- user has not made an explicit choice), so the choice shown matches the arrows being drawn.
  get = function() return addon:GetModule('Items'):GetActiveUpgradeProvider() end,
  set = function(ctx, value)
    db:SetUpgradeIconProvider(value)
    -- The data sweep re-resolves each item's data.isUpgrade with the newly selected provider; a
    -- redraw alone would draw the committed (stale) isUpgrade.
    rederive(ctx)
  end,
})

define('newItemDuration', {
  kind = "slider",
  title = 'New Item Duration',
  description = 'The duration in minutes that an item is considered new.',
  keywords = { 'recent items', 'new items', 'minutes', 'glow' },
  min = 1,
  max = 120,
  step = 1,
  get = function() return db:GetData().profile.newItemTime / 60 end,
  set = function(_, value) db:GetData().profile.newItemTime = value * 60 end,
})

--[[
-- Each bag
]]--

local sectionOrders = {
  ["Alphabetically"] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
  ["Size Descending"] = const.SECTION_SORT_TYPE.SIZE_DESCENDING,
  ["Size Ascending"] = const.SECTION_SORT_TYPE.SIZE_ASCENDING,
}

-- choiceOf returns the item of a choice whose value is value, or nil.
---@param choices table<string, any>
---@param value any
---@return string?
local function choiceOf(choices, value)
  for item, v in pairs(choices) do
    if v == value then
      return item
    end
  end
  return nil
end

define('sectionOrder', {
  kind = "dropdown",
  bag = true,
  title = 'Section Order',
  description = function(bag) return 'The order of sections in the ' .. lower(bag) .. ' when not pinned.' end,
  keywords = { 'sort', 'sections', 'categories', 'alphabetical', 'size' },
  items = {'Alphabetically', 'Size Descending', 'Size Ascending'},
  get = function(_, bag)
    return choiceOf(sectionOrders, db:GetSectionSortType(bag.kind, db:GetBagView(bag.kind)))
  end,
  set = function(ctx, value, bag)
    db:SetSectionSortType(bag.kind, db:GetBagView(bag.kind), sectionOrders[value])
    rederive(ctx)
  end,
})

local itemOrders = {
  ["Alphabetically"] = const.ITEM_SORT_TYPE.ALPHABETICALLY_THEN_QUALITY,
  ["Quality"] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
  ["Item Level"] = const.ITEM_SORT_TYPE.ITEM_LEVEL,
  ["Expansion"] = const.ITEM_SORT_TYPE.EXPANSION,
}

define('itemOrder', {
  kind = "dropdown",
  bag = true,
  title = 'Item Order',
  description = 'The default order of items within each section.',
  keywords = { 'sort', 'items', 'quality', 'item level', 'expansion', 'alphabetical' },
  items = {'Alphabetically', 'Quality', 'Item Level', 'Expansion'},
  get = function(_, bag)
    return choiceOf(itemOrders, db:GetItemSortType(bag.kind, db:GetBagView(bag.kind)))
  end,
  set = function(ctx, value, bag)
    db:SetItemSortType(bag.kind, db:GetBagView(bag.kind), itemOrders[value])
    rederive(ctx)
  end,
})

define('enableGroups', {
  kind = "toggle",
  bag = true,
  only = { const.BAG_KIND.BACKPACK },
  title = 'Enable Groups',
  description = 'Show group tabs at the bottom of the backpack. Groups allow you to organize categories into separate tabs. When disabled, all categories are shown in a single view.',
  keywords = { 'tabs', 'groups' },
  get = function(_, bag) return db:GetGroupsEnabled(bag.kind) end,
  set = function(ctx, value, bag)
    db:SetGroupsEnabled(bag.kind, value)
    events:SendMessage(ctx, 'groups/EnabledChanged', bag.kind, value)
    rederive(ctx)
  end,
})

-- Blizzard's item categories, each a category filter of the bag.
local filters = {
  { 'filterEquipmentLocation', 'EquipmentLocation', 'Equipment Location',
    'Sort items into categories based on equipment location (Main Hand, Head, etc).', { 'slot', 'gear' } },
  { 'filterExpansion', 'Expansion', 'Expansion', 'Sort items into categories based on their expansion.', {} },
  { 'filterGearSet', 'GearSet', 'Equipment Set', 'Sort items into categories based on equipment sets.',
    { 'gear set', 'equipment manager' } },
  { 'filterRecentItems', 'RecentItems', 'Recent Items', 'Enable the Recent Items category for new items.',
    { 'new items' } },
  { 'filterTradeSkill', 'TradeSkill', 'Trade Skill', 'Sort items into categories based on their trade skill usage.',
    { 'profession', 'reagent', 'crafting' } },
  { 'filterType', 'Type', 'Type', 'Sort items into categories based on their equipment type (Consumable, Quest, etc).',
    { 'item type' } },
  { 'filterSubtype', 'Subtype', 'Sub Type', 'Sort items into categories based on sub type (Potions, Bandages, etc).',
    { 'subtype', 'item type' } },
}
for _, f in ipairs(filters) do
  local id, key, title, description, keywords = f[1], f[2], f[3], f[4], f[5]
  define(id, {
    kind = "toggle",
    bag = true,
    title = title,
    description = description,
    keywords = keywords,
    get = function(_, bag) return db:GetCategoryFilters(bag.kind)[key] end,
    set = function(ctx, value, bag)
      db:GetCategoryFilters(bag.kind)[key] = value
      rederive(ctx)
    end,
  })
end

define('markRecentItems', {
  kind = "toggle",
  bag = true,
  title = 'All Items Recent',
  description = 'All new items you loot, pickup, or move into the bag will be marked as recent.',
  keywords = { 'recent items', 'new items', 'loot' },
  get = function(_, bag) return db:GetMarkRecentItems(bag.kind) end,
  set = function(_, value, bag) db:SetMarkRecentItems(bag.kind, value) end,
})

define('newItemFlash', {
  kind = "toggle",
  bag = true,
  title = 'Flash Stacks',
  description = 'When a stack of items gets a new item, the stack will flash.',
  keywords = { 'new items', 'flash', 'glow' },
  get = function(_, bag) return db:GetShowNewItemFlash(bag.kind) end,
  set = function(_, value, bag) db:SetShowNewItemFlash(bag.kind, value) end,
})

-- The bag's stacking options, each a field of its stacking table.
local stackingOptions = {
  { 'mergeStacks', 'mergeStacks', 'Merge Stacks', function(bag)
    return 'Stackable items will merge into a single item button in your ' .. lower(bag) .. '.'
  end, { 'stack', 'combine' } },
  { 'mergeUnstackable', 'mergeUnstackable', 'Merge Unstackable', function(bag)
    return 'Unstackable items, such as armor and weapons, will merge into a single item button in your ' .. lower(bag) .. '.'
  end, { 'stack', 'combine', 'armor', 'weapons' } },
  { 'dontMergePartial', 'dontMergePartial', "Don't Merge Partial Stacks",
    'Partial stacks of items will not merge with other partial or full stacks.', { 'stack', 'partial' } },
}
for _, o in ipairs(stackingOptions) do
  local id, key, title, description, keywords = o[1], o[2], o[3], o[4], o[5]
  define(id, {
    kind = "toggle",
    bag = true,
    title = title,
    description = description,
    keywords = keywords,
    get = function(_, bag) return db:GetStackingOptions(bag.kind)[key] end,
    set = function(ctx, value, bag)
      db:GetStackingOptions(bag.kind)[key] = value
      rederive(ctx)
    end,
  })
end

define('dontMergeTransmog', {
  kind = "toggle",
  bag = true,
  title = "Split Transmogged Items",
  description = function(bag)
    return 'Transmogged items will be split into a separate, stackable button in your ' .. lower(bag) .. '.'
  end,
  keywords = { 'stack', 'transmog', 'appearance' },
  get = function(_, bag) return db:GetStackingOptions(bag.kind).dontMergeTransmog end,
  set = function(ctx, value, bag)
    db:GetStackingOptions(bag.kind).dontMergeTransmog = value
    -- The item hash includes the transmog appearance only with this setting, and a slot's hash is
    -- computed when the slot is read, so the bags are read again.
    events:SendMessage(ctx, 'bags/FullRefreshAll')
  end,
})

define('unmergeAtShop', {
  kind = "toggle",
  bag = true,
  title = 'Unmerge on Interactions',
  description = 'When you interact a vendor, mailbox, auction house, etc, all merged items will unmerge.',
  keywords = { 'stack', 'vendor', 'mailbox', 'auction house' },
  get = function(_, bag) return db:GetStackingOptions(bag.kind).unmergeAtShop end,
  set = function(ctx, value, bag)
    db:GetStackingOptions(bag.kind).unmergeAtShop = value
    rederive(ctx)
  end,
})

define('itemLevel', {
  kind = "toggle",
  bag = true,
  title = 'Show Item Level',
  description = function(bag) return 'Show the item level on item buttons in the ' .. lower(bag) .. '.' end,
  keywords = { 'ilvl', 'item level' },
  get = function(_, bag) return db:GetItemLevelOptions(bag.kind).enabled end,
  set = function(ctx, value, bag)
    db:GetItemLevelOptions(bag.kind).enabled = value
    events:SendMessage(ctx, 'bags/Redraw', { buttons = true })
  end,
})

define('itemLevelColor', {
  kind = "toggle",
  bag = true,
  title = 'Show Item Level Color',
  description = function(bag) return 'Show the item level in color on item buttons in the ' .. lower(bag) .. '.' end,
  keywords = { 'ilvl', 'item level', 'color' },
  get = function(_, bag) return db:GetItemLevelOptions(bag.kind).color end,
  set = function(ctx, value, bag)
    db:GetItemLevelOptions(bag.kind).color = value
    events:SendMessage(ctx, 'bags/Redraw', { buttons = true })
  end,
})

define('fullSectionNames', {
  kind = "toggle",
  bag = true,
  title = 'Show Full Section Names',
  description = 'Show the full section names for each section and do not cut them off.',
  keywords = { 'section', 'title', 'truncate' },
  get = function(_, bag) return db:GetShowFullSectionNames(bag.kind) end,
  set = function(ctx, value, bag)
    db:SetShowFullSectionNames(bag.kind, value)
    events:SendMessage(ctx, 'bags/Redraw')
  end,
})

define('showAllFreeSpace', {
  kind = "toggle",
  bag = true,
  title = 'Show All Free Space Slots',
  description = function(bag)
    return 'Show all free space slots, individually, at the bottom of the ' .. lower(bag) .. '.'
  end,
  keywords = { 'free space', 'empty slots' },
  get = function(_, bag) return db:GetShowAllFreeSpace(bag.kind) end,
  set = function(ctx, value, bag)
    db:SetShowAllFreeSpace(bag.kind, value)
    rederive(ctx)
  end,
})

define('preserveGaps', {
  kind = "toggle",
  bag = true,
  title = 'Preserve Empty Slots as Gaps',
  description = function(bag)
    return 'When an item is used, sold, moved, or removed, keep an empty gap in its place until you close the '
      .. lower(bag) .. ' or sort it. New items appear elsewhere and never fill the gap.'
  end,
  keywords = { 'gaps', 'empty slots', 'holes' },
  get = function(_, bag) return db:GetPreserveItemGaps(bag.kind) end,
  set = function(ctx, value, bag)
    db:SetPreserveItemGaps(bag.kind, value)
    rederive(ctx)
  end,
})

define('glowIntensity', {
  kind = "slider",
  bag = true,
  title = 'Quality Glow Intensity',
  description = 'How strongly item buttons show their quality color, from 0 to 100. '
    .. 'At 0 there is no border at all. Up to 60 it is a flat colored border that fades in. '
    .. 'Above 60 the glowing halo alphas in, reaching a blinding maximum at 100.',
  keywords = { 'quality', 'border', 'glow', 'rarity', 'color' },
  min = 0,
  max = 100,
  step = 1,
  get = function(_, bag) return db:GetGlowIntensity(bag.kind) end,
  set = function(ctx, value, bag)
    db:SetGlowIntensity(bag.kind, value)
    events:SendMessage(ctx, 'bags/Redraw', { buttons = true })
  end,
})

define('resizableWindow', {
  kind = "toggle",
  bag = true,
  title = 'Resizable Window',
  description = function(bag)
    return 'If enabled, the ' .. lower(bag) .. ' is a window you size by dragging its corner, '
      .. 'and its sections fill it (Columns still sets how many sit side by side). '
      .. 'If disabled, it sizes itself to its items, Items Per Row wide.'
  end,
  keywords = { 'size', 'resize', 'window' },
  get = function(_, bag) return db:GetBagSizeMode(bag.kind) == "window" end,
  set = function(ctx, value, bag)
    db:SetBagSizeMode(bag.kind, value and "window" or "content")
    events:SendMessage(ctx, 'bags/Redraw')
  end,
})

define('snapToContent', {
  kind = "toggle",
  bag = true,
  title = 'Snap to Content',
  description = function(bag)
    return 'With Resizable Window on, when you let go after resizing the ' .. lower(bag)
      .. ', it shrinks to fit its items, so there is no empty space at the sides or below them.'
  end,
  keywords = { 'size', 'resize', 'window', 'snap' },
  get = function(_, bag) return db:GetBagSnapToContent(bag.kind) end,
  set = function(_, value, bag) db:SetBagSnapToContent(bag.kind, value) end,
})

define('itemsPerRow', {
  kind = "slider",
  bag = true,
  title = 'Items Per Row',
  description = 'The number of items per row in each section.',
  keywords = { 'width', 'columns', 'size' },
  min = 3,
  max = 20,
  step = 1,
  get = function(_, bag)
    local perRow = db:GetBagSizeInfo(bag.kind, db:GetBagView(bag.kind)).itemsPerRow
    return perRow > 20 and 20 or perRow
  end,
  set = function(ctx, value, bag)
    db:SetBagViewSizeItems(bag.kind, db:GetBagView(bag.kind), value)
    bucket:Later("setItemsPerRow", 0.2, function()
      events:SendMessage(ctx, 'bags/Redraw')
    end)
  end,
})

define('columns', {
  kind = "slider",
  bag = true,
  title = 'Columns',
  description = function(bag) return 'The number of columns in the ' .. lower(bag) .. '.' end,
  keywords = { 'width', 'sections', 'size' },
  min = 1,
  max = 20,
  step = 1,
  get = function(_, bag)
    local columns = db:GetBagSizeInfo(bag.kind, db:GetBagView(bag.kind)).columnCount
    return columns > 20 and 20 or columns
  end,
  set = function(ctx, value, bag)
    db:SetBagViewSizeColumn(bag.kind, db:GetBagView(bag.kind), value)
    bucket:Later("setSectionsPerRow", 0.2, function()
      events:SendMessage(ctx, 'bags/Redraw')
    end)
  end,
})

define('opacity', {
  kind = "slider",
  bag = true,
  title = 'Opacity',
  description = function(bag) return 'The opacity of the background of the ' .. lower(bag) .. '.' end,
  keywords = { 'transparency', 'background', 'alpha' },
  min = 0,
  max = 100,
  step = 1,
  get = function(_, bag) return db:GetBagSizeInfo(bag.kind, db:GetBagView(bag.kind)).opacity end,
  set = function(_, value, bag)
    db:SetBagViewSizeOpacity(bag.kind, db:GetBagView(bag.kind), value)
    sonata:UpdateOpacity()
  end,
})

define('scale', {
  kind = "slider",
  bag = true,
  title = 'Scale',
  description = function(bag) return 'The scale of the ' .. lower(bag) .. '.' end,
  keywords = { 'size', 'zoom' },
  min = 50,
  max = 200,
  step = 1,
  get = function(_, bag) return db:GetBagSizeInfo(bag.kind, db:GetBagView(bag.kind)).scale end,
  set = function(_, value, bag)
    db:SetBagViewSizeScale(bag.kind, db:GetBagView(bag.kind), value)
    local bagFrame = addon:GetBagFromKind(bag.kind)
    -- A BetterBags Next backpack has no window: it has one size.
    if bagFrame and bagFrame.window then
      bagFrame.window:UpdateScale()
    end
  end,
})
