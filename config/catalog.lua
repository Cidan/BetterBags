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
-- choices or range, how it is read and written, and what it sends so the bags show it. The settings
-- window (next/settings/) builds its rows from it, for the classic bags and BetterBags Next alike. A
-- bag's settings are bound to a bag when they are asked for (Get(id, bag)).
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

-- One setting for every bag: the bags follow it at once (bags/ClampChanged, window.md §3a).
define('clampBagsToScreen', {
  kind = "toggle",
  title = 'Clamp Bags to Screen',
  description = 'If enabled, bags are kept on the screen: they cannot be moved or grow past its edges. '
    .. 'In BetterBags Next this applies to small bags; full-size bags rest at the edges of the screen.',
  keywords = { 'clamp', 'screen', 'edge', 'off screen', 'move', 'position' },
  get = function() return db:GetClampBagsToScreen() end,
  set = function(ctx, value)
    db:SetClampBagsToScreen(value)
    events:SendMessage(ctx, 'bags/ClampChanged')
  end,
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

-- Before the settings window had it, only the changelog window's "Don't show me this again" checkbox
-- set it (frames/changelog.lua, changelog.md).
define('changelogOnLogin', {
  kind = "toggle",
  title = "Show What's New on Login",
  description = "Open What's New when you log in after BetterBags was updated.",
  keywords = { 'changelog', "what's new", 'updates', 'patch notes' },
  get = function() return db:GetChangelogAutoOpen() == true end,
  set = function(_, value) db:SetChangelogAutoOpen(value) end,
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

-- BetterBags Next's Size tab (docs/next-appearance-size.md). The panels size themselves on
-- next/ScalesChanged: nothing is read or recalculated.
define('nextIconScale', {
  kind = "slider",
  title = 'Icon Scale',
  description = "How big item buttons are in BetterBags Next's bags, in percent of the theme's size. "
    .. 'A row fits as many as its width allows.',
  keywords = { 'size', 'icon', 'button', 'item', 'zoom', 'per row' },
  min = 50,
  max = 150,
  step = 5,
  get = function() return db:GetNextIconScale() end,
  set = function(ctx, value)
    db:SetNextIconScale(value)
    events:SendMessage(ctx, 'next/ScalesChanged')
  end,
})

define('nextBagScale', {
  kind = "slider",
  title = 'Bag Scale',
  description = "The scale of BetterBags Next's small bags, in percent. Full-height bags on the edges of "
    .. 'the screen keep their size.',
  keywords = { 'size', 'scale', 'zoom', 'small', 'window' },
  min = 50,
  max = 150,
  step = 5,
  get = function() return db:GetNextBagScale() end,
  set = function(ctx, value)
    db:SetNextBagScale(value)
    events:SendMessage(ctx, 'next/ScalesChanged')
  end,
})

-- BetterBags Next's Animation tab (Appearance > Animation, next-themes.md §20): each effect on or off, on any theme.
-- Asked: "we need a way to disable sparkles etc on any theme, not just switching to a theme without them". Each one
-- saves its choice and tells BetterBags Next, which lays the switches over the theme in use again (SonataNext).
for _, effect in ipairs({
  { id = 'nextSparkles', name = 'sparkles', title = 'Sparkles',
    description = "The sparkles drifting out of BetterBags Next's titles and feathered edges, and from the knot "
      .. 'when two bags couple.',
    keywords = { 'sparkle', 'particles', 'stars', 'glitter' } },
  { id = 'nextShimmer', name = 'shimmer', title = 'Title Shimmer',
    description = "The spark that glides along a bag's ribbon into its title every few seconds.",
    keywords = { 'shimmer', 'spark', 'ribbon', 'title' } },
  { id = 'nextTitleCloud', name = 'titleCloud', title = 'Title Cloud',
    description = "The soft glow that breathes behind a bag's title.",
    keywords = { 'cloud', 'glow', 'title', 'breathe' } },
  -- Asked: "another option to turn off the spike that comes off of the bag".
  { id = 'nextTitleRibbon', name = 'ribbon', title = 'Title Ribbon',
    description = "The gold line running from a bag's title out past the window's edge.",
    keywords = { 'ribbon', 'spike', 'line', 'beam', 'title' } },
  { id = 'nextBraid', name = 'braid', title = 'Braid',
    description = 'The ribbons twisting together between two chained bags.',
    keywords = { 'braid', 'ribbon', 'chain', 'chained', 'couple' } },
  { id = 'nextOrnamentMotion', name = 'ornaments', title = 'Moving Ornaments',
    description = "A theme's swaying, spinning or pulsing pieces. Off, they stand still and keep their art.",
    keywords = { 'ornament', 'sway', 'spin', 'pulse', 'theme' } },
  -- The Glitch theme's (next-themes.md §21). Flicker can be hard on some players' eyes: off, its bags slide in and out
  -- as any theme's and never glitch while they show.
  { id = 'nextGlitch', name = 'glitch', title = 'Glitch Effects',
    description = "A theme's bags flickering and tearing as they open and close, and now and then while they show. "
      .. 'Off, they slide in and out.',
    keywords = { 'glitch', 'flicker', 'flash', 'tear', 'static', 'theme' } },
  { id = 'nextRain', name = 'rain', title = 'Data Rain',
    description = "A theme's columns of glyphs falling down a bag's feathered edge and behind its items.",
    keywords = { 'rain', 'data', 'glyphs', 'matrix', 'theme' } },
  -- The Frost theme's (next-themes.md §22): off, its bags slide in and out as any theme's.
  { id = 'nextShatter', name = 'shatter', title = 'Ice Shatter',
    description = "A theme's bags freezing together from shards of ice as they open, and shattering as they close. "
      .. 'Off, they slide in and out.',
    keywords = { 'shatter', 'ice', 'shards', 'frost', 'freeze', 'crack', 'theme' } },
  -- The Frost theme's snow, the Halloween theme's falling leaves and the Make It So theme's stars streaking past at warp
  -- (one engine: next-themes.md §22).
  { id = 'nextSnow', name = 'snow', title = 'Snow, Leaves and Stars',
    description = "A theme's snow, autumn leaves or stars drifting across a bag and down its feathered edge, and the "
      .. 'gusts that sweep them along.',
    keywords = { 'snow', 'flakes', 'leaves', 'autumn', 'fall', 'wind', 'breeze', 'gust', 'weather', 'stars', 'warp',
      'theme' } },
  -- The Halloween theme's (next-themes.md §23): off, its bags slide in and out as any theme's.
  { id = 'nextSmoke', name = 'smoke', title = 'Smoke Puff',
    description = "A theme's bags appearing out of rising smoke as they open. Off, they slide in.",
    keywords = { 'smoke', 'puff', 'poof', 'cloud', 'halloween', 'theme' } },
  { id = 'nextBats', name = 'bats', title = 'Bats',
    description = "A theme's bags breaking up into bats that fly away as they close, and bats fluttering out of a bag now "
      .. 'and then. Off, they slide out.',
    keywords = { 'bats', 'bat', 'fly', 'flutter', 'vampire', 'halloween', 'theme' } },
  -- The Make It So theme's (next-themes.md §24): off, its bags slide in and out as any theme's.
  { id = 'nextBeam', name = 'beam', title = 'Transporter',
    description = "A theme's bags beaming in and out in a shimmer of light, as a starship's transporter does. Off, they "
      .. 'slide in and out.',
    keywords = { 'transporter', 'beam', 'energize', 'shimmer', 'star', 'trek', 'theme' } },
}) do
  local keywords = { 'animation', 'effects', 'motion' }
  for _, word in ipairs(effect.keywords) do
    table.insert(keywords, word)
  end
  define(effect.id, {
    kind = "toggle",
    title = effect.title,
    description = effect.description,
    keywords = keywords,
    get = function() return db:GetNextAnimation(effect.name) end,
    set = function(ctx, value)
      db:SetNextAnimation(effect.name, value)
      events:SendMessage(ctx, 'next/AnimationChanged')
    end,
  })
end

-- BetterBags Next's currencies (currency.md §6, the Currencies page's Display tab): how the strip at the bottom of the
-- backpack and the tracker dragged out of it show what is tracked. Each saves the player's choice (one of the
-- currency options, unless it says how to read and write its own) and tells them (currencies/OptionsChanged), which
-- read it again.
---@param id string
---@param def table
local function currencyOption(id, def)
  local name = def.option
  def.option = nil
  def.get = def.get or function() return db:GetNextCurrencyOption(name) end
  local write = def.write or function(value) db:SetNextCurrencyOption(name, value) end
  def.write = nil
  def.set = function(ctx, value)
    write(value)
    events:SendMessage(ctx, 'currencies/OptionsChanged')
  end
  define(id, def)
end

currencyOption('nextCurrencyCapBars', {
  option = 'capBars',
  kind = "toggle",
  title = 'Cap Bars',
  description = 'A thin bar under each currency with a cap, filling toward it, in a warning color once it is reached: '
    .. 'what you earn past a cap is wasted.',
  keywords = { 'currency', 'currencies', 'cap', 'bar', 'weekly', 'season' },
})

currencyOption('nextCurrencyGains', {
  option = 'gains',
  kind = "toggle",
  title = 'Show Gains',
  description = 'A number floating off a currency or an item as you gain some, or spend it.',
  keywords = { 'currency', 'currencies', 'gain', 'earn', 'loot', 'float' },
})

currencyOption('nextCurrencyHideEmpty', {
  option = 'hideEmpty',
  kind = "toggle",
  title = 'Hide What You Have None Of',
  description = 'Currencies and items you have none of wait behind +N in your backpack, and are left out of the '
    .. 'tracker. Off, they show faded.',
  keywords = { 'currency', 'currencies', 'empty', 'none', 'zero', 'hide' },
})

currencyOption('nextCurrencyItemsEverywhere', {
  option = 'itemsEverywhere',
  kind = "toggle",
  title = 'Count Items Everywhere',
  description = 'Count a tracked item in your bank and Warband bank too, not only in your bags.',
  keywords = { 'currency', 'item', 'count', 'bank', 'warband', 'reagent' },
})

local currencyLayouts = { ["Row"] = "row", ["Column"] = "column", ["List"] = "list" }

currencyOption('nextCurrencyLayout', {
  kind = "dropdown",
  title = 'Tracker Layout',
  description = 'How the tracker you drag out of your backpack lays out what it tracks: in a row, in a column, or a '
    .. 'list with their names.',
  keywords = { 'currency', 'tracker', 'layout', 'row', 'column', 'list', 'names' },
  items = { 'Row', 'Column', 'List' },
  get = function() return choiceOf(currencyLayouts, db:GetNextCurrencyOption('layout')) end,
  write = function(value) db:SetNextCurrencyOption('layout', currencyLayouts[value]) end,
})

-- Asked: "a grow direction for the tracker ... grow direction should probably be left (anchor point is right, frame
-- grows out left) ... for list view we need up and down as options". One choice for the layout shown: Left or Right in
-- a row, Up or Down in a column or a list (the tracker keeps both).
local currencyGrowth = { ["Left"] = { "growX", "left" }, ["Right"] = { "growX", "right" },
  ["Up"] = { "growY", "up" }, ["Down"] = { "growY", "down" } }

currencyOption('nextCurrencyGrow', {
  kind = "dropdown",
  title = 'Tracker Grows',
  description = 'Which way the tracker grows as what it tracks gets longer: left from its right edge or right from its '
    .. 'left edge in a row; down from its top or up from its bottom in a column or a list.',
  keywords = { 'currency', 'tracker', 'grow', 'direction', 'anchor', 'left', 'right', 'up', 'down' },
  itemsFunction = function()
    if db:GetNextCurrencyOption('layout') == 'row' then
      return { 'Left', 'Right' }
    end
    return { 'Up', 'Down' }
  end,
  get = function()
    if db:GetNextCurrencyOption('layout') == 'row' then
      return db:GetNextCurrencyOption('growX') == 'right' and 'Right' or 'Left'
    end
    return db:GetNextCurrencyOption('growY') == 'up' and 'Up' or 'Down'
  end,
  write = function(value)
    local growth = currencyGrowth[value]
    db:SetNextCurrencyOption(growth[1], growth[2])
  end,
})

currencyOption('nextCurrencyScale', {
  option = 'scale',
  kind = "slider",
  title = 'Tracker Scale',
  description = 'The scale of the tracker you drag out of your backpack, in percent.',
  keywords = { 'currency', 'tracker', 'size', 'scale', 'zoom' },
  min = 50,
  max = 200,
  step = 5,
})

currencyOption('nextCurrencyBackground', {
  option = 'background',
  kind = "toggle",
  title = 'Tracker Background',
  description = "The tracker's card behind what it tracks. Off, the card shows faintly only while the pointer is "
    .. 'over it, to grab it by.',
  keywords = { 'currency', 'tracker', 'background', 'card', 'border', 'transparent' },
})

currencyOption('nextCurrencyHideInCombat', {
  option = 'hideInCombat',
  kind = "toggle",
  title = 'Hide Tracker in Combat',
  description = 'Fade the tracker out while you are in combat, and back in after.',
  keywords = { 'currency', 'tracker', 'combat', 'hide', 'fade' },
})

currencyOption('nextCurrencyTracker', {
  kind = "toggle",
  title = 'Show Tracker',
  description = 'The tracker you drag out of the bottom of your backpack, kept on screen with your bags closed. On, '
    .. 'it shows where you left it; dropping it back on your backpack puts it away.',
  keywords = { 'currency', 'tracker', 'show', 'detach', 'float' },
  get = function()
    local out = db:GetNextCurrencyTracker()
    return out
  end,
  write = function(value) db:SetNextCurrencyTracker(value) end,
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
