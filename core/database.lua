local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
---@field private data databaseOptions
local DB = addon:NewModule('Database')

---@class (exact) ColorDef
---@field red number
---@field green number
---@field blue number
---@field alpha number

function DB:Init()
  -- A new install has no saved variables yet: AceDB creates them only when the global is nil
  -- (AceDB-3.0 New), and nothing reads them before this. A character new to an existing install is
  -- no new install: every character shares the Default profile.
  local newInstall = _G[addonName .. 'DB'] == nil
  -- Create the settings database.
  DB.data = LibStub('AceDB-3.0'):New(addonName .. 'DB', const.DATABASE_DEFAULTS --[[@as AceDB.Schema]], true) --[[@as databaseOptions]]
  -- At PLAYER_LOGOUT AceDB strips every setting still at its default, and every table left empty,
  -- from the profile, right after this callback: a setting read after it can be nil
  -- (initialization.md §7).
  addon.loggingOut = false
  DB.data.RegisterCallback(DB, 'OnDatabaseShutdown', function()
    addon.loggingOut = true
  end)
  if newInstall then
    -- New installs start with BetterBags Next (next.md §1). Saved in the profile: the default stays
    -- off, so a profile from before that never turned Next on keeps the classic bags.
    DB.data.profile.nextEnabled = true
  end
  DB:Migrate()
end

---@return databaseOptions
function DB:GetData()
  return DB.data
end

-- GetChangelogLastSeen returns the id of the newest changelog release the player has seen.
-- The changelog's state is account wide (AceDB global).
---@return number
function DB:GetChangelogLastSeen()
  return DB.data.global.changelog.lastSeen
end

---@param id number
function DB:SetChangelogLastSeen(id)
  DB.data.global.changelog.lastSeen = id
end

-- GetChangelogAutoOpen returns whether the changelog opens by itself on login.
---@return boolean
function DB:GetChangelogAutoOpen()
  return DB.data.global.changelog.autoOpen
end

---@param value boolean
function DB:SetChangelogAutoOpen(value)
  DB.data.global.changelog.autoOpen = value
end

---@param kind BagKind
---@return table
function DB:GetBagPosition(kind)
  return DB.data.profile.positions[kind]
end

---@param kind BagKind
---@return table
function DB:GetAnchorPosition(kind)
  return DB.data.profile.anchorPositions[kind]
end

---@param kind BagKind
---@return AnchorState
function DB:GetAnchorState(kind)
  return DB.data.profile.anchorState[kind]
end

---@param kind BagKind
---@return BagView
function DB:GetBagView(kind)
  return DB.data.profile.views[kind]
end

---@param kind BagKind
---@return boolean
function DB:GetMarkRecentItems(kind)
  return DB.data.profile.newItems[kind].markRecentItems
end

---@param kind BagKind
---@param value boolean
function DB:SetMarkRecentItems(kind, value)
  DB.data.profile.newItems[kind].markRecentItems = value
end

---@param kind BagKind
---@return boolean
function DB:GetShowNewItemFlash(kind)
  return DB.data.profile.newItems[kind].showNewItemFlash
end

---@param kind BagKind
---@param value boolean
function DB:SetShowNewItemFlash(kind, value)
  DB.data.profile.newItems[kind].showNewItemFlash = value
end

---@param kind BagKind
---@param view BagView
function DB:SetBagView(kind, view)
  DB.data.profile.views[kind] = view
end

---@param kind BagKind
---@param view BagView
function DB:SetPreviousView(kind, view)
  DB.data.profile.previousViews[kind] = view
end

---@param kind BagKind
---@return BagView
function DB:GetPreviousView(kind)
  return DB.data.profile.previousViews[kind]
end

function DB:GetCategoryFilter(kind, filter)
  return DB.data.profile.categoryFilters[kind][filter]
end

function DB:SetCategoryFilter(kind, filter, value)
  DB.data.profile.categoryFilters[kind][filter] = value
end

function DB:GetCategoryFilters(kind)
  return DB.data.profile.categoryFilters[kind]
end

---@param show boolean
function DB:SetShowBagButton(show)
  DB.data.profile.showBagButton = show
end

---@return boolean
function DB:GetShowBagButton()
  return DB.data.profile.showBagButton
end

---@param enabled boolean
function DB:SetEnableBankBag(enabled)
  DB.data.profile.enableBankBag = enabled
end

---@return boolean
function DB:GetEnableBankBag()
  return DB.data.profile.enableBankBag
end

---@param shown boolean
function DB:SetShowBankTabs(shown)
  DB.data.profile.showBankTabs = shown
end

---@return boolean
function DB:GetShowBankTabs()
  return DB.data.profile.showBankTabs
end

-- The guild bank shows its own tabs, one at a time, instead of every tab in categories
-- (guild-bank.md §4).
---@param shown boolean
function DB:SetShowGuildBankTabs(shown)
  DB.data.profile.showGuildBankTabs = shown
end

---@return boolean
function DB:GetShowGuildBankTabs()
  return DB.data.profile.showGuildBankTabs
end

---@param enabled boolean
function DB:SetEnableBagFading(enabled)
  DB.data.profile.enableBagFading = enabled
end

---@return boolean
function DB:GetEnableBagFading()
  return DB.data.profile.enableBagFading
end

-- GetAnimateItemMovement returns whether items, sections and rows travel to their new places when
-- the bags rearrange (render-pipeline.md §4c). Off unless turned on.
---@return boolean
function DB:GetAnimateItemMovement()
  return DB.data.profile.animateItemMovement
end

---@param enabled boolean
function DB:SetAnimateItemMovement(enabled)
  DB.data.profile.animateItemMovement = enabled
end

-- GetClampBagsToScreen returns whether every bag is kept on the screen (window.md §3a): the classic
-- bags and their slots panels, and BetterBags Next's small panels. Off unless turned on.
---@return boolean
function DB:GetClampBagsToScreen()
  return DB.data.profile.clampBagsToScreen
end

---@param enabled boolean
function DB:SetClampBagsToScreen(enabled)
  DB.data.profile.clampBagsToScreen = enabled
end

-- GetNextEnabled returns whether the backpack is BetterBags Next's panel (next.md); it takes
-- effect after a reload. Off unless turned on.
---@return boolean
function DB:GetNextEnabled()
  return DB.data.profile.nextEnabled
end

---@param enabled boolean
function DB:SetNextEnabled(enabled)
  DB.data.profile.nextEnabled = enabled
end

---@alias NextChainLayout "apart"|"left"|"right"

-- GetNextChain returns how BetterBags Next's backpack and its companion (the bank or a vendor) sit:
-- apart on opposite edges, or chained on the left or the right (next.md §12).
---@return NextChainLayout
function DB:GetNextChain()
  return DB.data.profile.nextChain
end

---@param layout NextChainLayout
function DB:SetNextChain(layout)
  if layout ~= "apart" and layout ~= "left" and layout ~= "right" then
    error("unknown BetterBags Next chain layout: " .. tostring(layout))
  end
  DB.data.profile.nextChain = layout
end

-- GetNextTabOrder returns the order the player moved a BetterBags Next tab rail's tabs to (tab ids; none
-- until moved). key names the rail: "backpack", "bank", "bankTabs", "guild", "vendor".
---@param key string
---@return number[]
function DB:GetNextTabOrder(key)
  return DB.data.profile.nextTabOrder[key] or {}
end

---@param key string
---@param ids number[]
function DB:SetNextTabOrder(key, ids)
  local copy = {}
  for i, id in ipairs(ids) do
    copy[i] = id
  end
  DB.data.profile.nextTabOrder[key] = copy
end

-- A BetterBags Next scale (docs/next-appearance-size.md): a whole percentage in 50 to 150, 100 for
-- anything but a number.
---@param value any
---@return number
local function nextScale(value)
  value = tonumber(value)
  if value == nil then
    return 100
  end
  return math.max(50, math.min(150, math.floor(value + 0.5)))
end

-- GetNextIconScale returns how big BetterBags Next's item buttons are, in percent of the Next theme's
-- icon size.
---@return number
function DB:GetNextIconScale()
  return DB.data.profile.nextIconScale
end

---@param value number
function DB:SetNextIconScale(value)
  DB.data.profile.nextIconScale = nextScale(value)
end

-- GetNextBagScale returns the scale of BetterBags Next's small panels, in percent; full panels are
-- always at their size.
---@return number
function DB:GetNextBagScale()
  return DB.data.profile.nextBagScale
end

---@param value number
function DB:SetNextBagScale(value)
  DB.data.profile.nextBagScale = nextScale(value)
end

---@alias NextSize "full"|"small"

-- GetNextSize returns BetterBags Next's panel size: "full" height on the screen's edges, or "small"
-- movable panels (docs/next-small-mode.md).
---@return NextSize
function DB:GetNextSize()
  return DB.data.profile.nextSize
end

---@param size NextSize
function DB:SetNextSize(size)
  if size ~= "full" and size ~= "small" then
    error("unknown BetterBags Next size: " .. tostring(size))
  end
  DB.data.profile.nextSize = size
end

-- GetNextSmallPlace returns where a kind's small panel was left: its top left in UIParent's units,
-- or nothing before it was first moved.
---@param kind BagKind
---@return number? x, number? y
function DB:GetNextSmallPlace(kind)
  local place = DB.data.profile.nextSmallPlaces[kind]
  if place == nil then
    return nil
  end
  return place.x, place.y
end

---@param kind BagKind
---@param x number
---@param y number
function DB:SetNextSmallPlace(kind, x, y)
  DB.data.profile.nextSmallPlaces[kind] = { x = x, y = y }
end

-- GetNextSmallSize returns the size the player gave a kind's small panel with its grips (next.md
-- §14g), in UIParent's units, or nothing while it is the default size.
---@param kind BagKind
---@return number? width, number? height
function DB:GetNextSmallSize(kind)
  local size = DB.data.profile.nextSmallSizes[kind]
  if size == nil then
    return nil
  end
  return size.width, size.height
end

-- SetNextSmallSize saves a kind's small panel's size; nothing puts it back to the default size.
---@param kind BagKind
---@param width? number
---@param height? number
function DB:SetNextSmallSize(kind, width, height)
  if width == nil then
    DB.data.profile.nextSmallSizes[kind] = nil
    return
  end
  DB.data.profile.nextSmallSizes[kind] = { width = width, height = height }
end

-- GetNextTheme returns BetterBags Next's saved theme (SonataNext): Default until another is picked.
---@return string
function DB:GetNextTheme()
  return DB.data.profile.nextTheme
end

---@param key string
function DB:SetNextTheme(key)
  DB.data.profile.nextTheme = key
end

---@alias NextAnimation "sparkles"|"shimmer"|"titleCloud"|"ribbon"|"braid"|"ornaments"|"glitch"|"rain"|"shatter"|"snow"

-- nextAnimationName checks an Animation switch's name: one of the defaults' (const.DATABASE_DEFAULTS), nothing else.
---@param name string
local function nextAnimationName(name)
  if const.DATABASE_DEFAULTS.profile.nextAnimation[name] == nil then
    error("unknown BetterBags Next animation: " .. tostring(name))
  end
end

-- GetNextAnimation says whether one of BetterBags Next's effects is on (Appearance > Animation, next-themes.md §20):
-- every one until the player turns it off.
---@param name NextAnimation
---@return boolean
function DB:GetNextAnimation(name)
  nextAnimationName(name)
  return DB.data.profile.nextAnimation[name]
end

---@param name NextAnimation
---@param on boolean
function DB:SetNextAnimation(name, on)
  nextAnimationName(name)
  DB.data.profile.nextAnimation[name] = on
end

---@alias NextCurrencyKind "currency"|"item"

-- NextTrackedCurrency is something BetterBags Next tracks as a currency (currency.md): a currency, or an item counted
-- as one.
---@class (exact) NextTrackedCurrency
---@field kind NextCurrencyKind
---@field id number

-- GetNextCurrencies returns what BetterBags Next tracks, in the order it shows: a copy, so nothing a caller does
-- changes what is saved.
---@return NextTrackedCurrency[]
function DB:GetNextCurrencies()
  local out = {}
  for _, entry in ipairs(DB.data.profile.nextCurrencies) do
    table.insert(out, { kind = entry.kind, id = entry.id })
  end
  return out
end

-- SetNextCurrencies saves what BetterBags Next tracks, in order: a copy of the list, refusing anything that is no
-- currency or item.
---@param list NextTrackedCurrency[]
function DB:SetNextCurrencies(list)
  local saved = {}
  for _, entry in ipairs(list) do
    if (entry.kind ~= "currency" and entry.kind ~= "item") or type(entry.id) ~= "number" then
      error("not a currency or an item: " .. tostring(entry.kind) .. " " .. tostring(entry.id))
    end
    table.insert(saved, { kind = entry.kind, id = entry.id })
  end
  DB.data.profile.nextCurrencies = saved
end

---@alias NextCurrencyOption "capBars"|"gains"|"hideEmpty"|"itemsEverywhere"|"layout"|"scale"|"background"|"hideInCombat"|"growX"|"growY"

-- The values an option is checked against: the tracker's layouts and the ways it grows (currency.md §5).
local CURRENCY_CHOICES = {
  layout = { row = true, column = true, list = true },
  growX = { left = true, right = true },
  growY = { up = true, down = true },
}

-- nextCurrencyOption checks a currency option's name: one of the defaults' (const.DATABASE_DEFAULTS), nothing else.
---@param name string
local function nextCurrencyOption(name)
  if const.DATABASE_DEFAULTS.profile.nextCurrency[name] == nil then
    error("unknown BetterBags Next currency option: " .. tostring(name))
  end
end

-- GetNextCurrencyOption returns how BetterBags Next's currencies show (currency.md §6): cap bars, gains, what you
-- have none of hidden, items counted everywhere, and the tracker's layout, scale (percent), background, whether it
-- hides in combat, and which way it grows (growX "left" or "right", growY "down" or "up").
---@param name NextCurrencyOption
---@return any
function DB:GetNextCurrencyOption(name)
  nextCurrencyOption(name)
  return DB.data.profile.nextCurrency[name]
end

---@param name NextCurrencyOption
---@param value any
function DB:SetNextCurrencyOption(name, value)
  nextCurrencyOption(name)
  local choices = CURRENCY_CHOICES[name]
  if choices ~= nil and not choices[value] then
    error("not a currency tracker " .. name .. ": " .. tostring(value))
  end
  DB.data.profile.nextCurrency[name] = value
end

-- GetNextCurrencyTracker returns whether the currency tracker is out of the backpack, and where it was left: the corner
-- it grows from (growX, growY), in UIParent's units from the screen's top left; nothing before it was first placed.
-- Put away, it remembers where it was.
---@return boolean out, number? x, number? y
function DB:GetNextCurrencyTracker()
  local t = DB.data.profile.nextCurrencyTracker
  return t.out == true, t.x, t.y
end

---@param out boolean
---@param x? number
---@param y? number
function DB:SetNextCurrencyTracker(out, x, y)
  local t = DB.data.profile.nextCurrencyTracker
  t.out = out
  if x ~= nil then
    t.x, t.y = x, y
  end
end

---@alias NextSmallChain "apart"|"backpack"|"companion"

-- GetNextSmallChain returns which small panel anchors a chained pair (docs/next-small-mode.md):
-- "apart", "backpack" (a companion was dropped beside it) or "companion" (the backpack was dropped
-- beside a companion, and sits beside whichever is open).
---@return NextSmallChain
function DB:GetNextSmallChain()
  return DB.data.profile.nextSmallChain
end

---@param layout NextSmallChain
function DB:SetNextSmallChain(layout)
  if layout ~= "apart" and layout ~= "backpack" and layout ~= "companion" then
    error("unknown BetterBags Next small chain: " .. tostring(layout))
  end
  DB.data.profile.nextSmallChain = layout
end

---@param kind BagKind
---@return boolean
function DB:GetGroupsEnabled(kind)
  if DB.data.profile.groupsEnabled == nil then
    return true
  end
  if DB.data.profile.groupsEnabled[kind] == nil then
    return true
  end
  return DB.data.profile.groupsEnabled[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetGroupsEnabled(kind, value)
  if DB.data.profile.groupsEnabled == nil then
    DB.data.profile.groupsEnabled = {}
  end
  DB.data.profile.groupsEnabled[kind] = value
end

---@param kind BagKind
---@param view BagView
---@return SizeInfo
function DB:GetBagSizeInfo(kind, view)
  return DB.data.profile.size[view][kind]
end

---@param kind BagKind
---@param view BagView
---@param count number
function DB:SetBagViewSizeColumn(kind, view, count)
  DB.data.profile.size[view][kind].columnCount = count
end

---@param kind BagKind
---@param view BagView
---@param count number
function DB:SetBagViewSizeItems(kind, view, count)
  DB.data.profile.size[view][kind].itemsPerRow = count
end
---@param kind BagKind
---@param view BagView
---@param scale number
function DB:SetBagViewSizeScale(kind, view, scale)
  DB.data.profile.size[view][kind].scale = scale
end

---@param kind BagKind
---@param view BagView
---@return number, number
function DB:GetBagViewFrameSize(kind, view)
  local s = DB.data.profile.size[view][kind]
  return s.width, s.height
end

---@param kind BagKind
---@param view BagView
---@param width number
---@param height number
function DB:SetBagViewFrameSize(kind, view, width, height)
  DB.data.profile.size[view][kind].width = width
  DB.data.profile.size[view][kind].height = height
end

-- GetBagSizeMode returns how the bag's window is sized in the view it shows: "content" (it
-- fits its contents) or "window" (the player sizes it and its contents reflow).
---@param kind BagKind
---@return WindowSizeMode
function DB:GetBagSizeMode(kind)
  return DB.data.profile.size[DB:GetBagView(kind)][kind].sizeMode
end

---@param kind BagKind
---@param mode WindowSizeMode
function DB:SetBagSizeMode(kind, mode)
  if mode ~= "content" and mode ~= "window" then
    error("unknown bag size mode: " .. tostring(mode))
  end
  DB.data.profile.size[DB:GetBagView(kind)][kind].sizeMode = mode
end

-- GetBagSnapToContent returns whether the bag's window, in the view it shows, shrinks to its
-- content's width, and its height when there is room below it, when the player finishes
-- resizing it. On unless turned off.
---@param kind BagKind
---@return boolean
function DB:GetBagSnapToContent(kind)
  return DB.data.profile.size[DB:GetBagView(kind)][kind].snapToContent ~= false
end

---@param kind BagKind
---@param value boolean
function DB:SetBagSnapToContent(kind, value)
  DB.data.profile.size[DB:GetBagView(kind)][kind].snapToContent = value
end

function DB:GetItemLevelOptions(kind)
  return DB.data.profile.itemLevel[kind]
end

function DB:SetItemLevelEnabled(kind, enabled)
  DB.data.profile.itemLevel[kind].enabled = enabled
end

function DB:SetItemLevelColorEnabled(kind, enabled)
  DB.data.profile.itemLevel[kind].color = enabled
end

---@return number
function DB:GetMaxItemLevel()
  local characterKey = UnitName("player") .. "-" .. GetRealmName()
  local byCharacter = DB.data.profile.itemLevelColor.maxItemLevelByCharacter
  return byCharacter[characterKey] or 1
end

---@param itemLevel number
function DB:UpdateMaxItemLevel(itemLevel)
  local characterKey = UnitName("player") .. "-" .. GetRealmName()
  local byCharacter = DB.data.profile.itemLevelColor.maxItemLevelByCharacter
  local current = byCharacter[characterKey] or 1
	if itemLevel > current then
		byCharacter[characterKey] = itemLevel
		-- Notify listeners to refresh item level visuals and options pane.
		local events = addon:GetModule('Events')
		local context = addon:GetModule('Context')
		local ctx = context:New('UpdateMaxItemLevel')
		events:SendMessage(ctx, 'itemLevel/MaxChanged', itemLevel)
	end
end

---@return {low: ColorDef, mid: ColorDef, high: ColorDef, max: ColorDef}
function DB:ResetMaxItemLevel()
  local characterKey = UnitName("player") .. "-" .. GetRealmName()
  local byCharacter = DB.data.profile.itemLevelColor.maxItemLevelByCharacter
  byCharacter[characterKey] = 1
  -- Notify listeners to refresh item level visuals and options pane.
  local events = addon:GetModule('Events')
  local context = addon:GetModule('Context')
  local ctx = context:New('ResetMaxItemLevel')
  events:SendMessage(ctx, 'itemLevel/MaxChanged', 1)
  -- The maximum is learned while items are read, and sweeps keep the items of unchanged
  -- slots without reading them again; re-read everything so it is learned again.
  events:SendMessage(ctx, 'bags/FullRefreshAll')
end

function DB:GetItemLevelColors()
  return DB.data.profile.itemLevelColor.colors
end

---@param colorKey "low"|"mid"|"high"|"max"
---@param color ColorDef
function DB:SetItemLevelColor(colorKey, color)
  DB.data.profile.itemLevelColor.colors[colorKey] = color
end

function DB:ResetItemLevelColors()
  -- Deep copy the colors from constants to avoid reference issues
  local defaults = const.DATABASE_DEFAULTS.profile.itemLevelColor.colors
  DB.data.profile.itemLevelColor.colors = {
    low = { red = defaults.low.red, green = defaults.low.green, blue = defaults.low.blue, alpha = defaults.low.alpha },
    mid = { red = defaults.mid.red, green = defaults.mid.green, blue = defaults.mid.blue, alpha = defaults.mid.alpha },
    high = { red = defaults.high.red, green = defaults.high.green, blue = defaults.high.blue, alpha = defaults.high.alpha },
    max = { red = defaults.max.red, green = defaults.max.green, blue = defaults.max.blue, alpha = defaults.max.alpha }
  }
end

function DB:GetFirstTimeMenu()
  return DB.data.profile.firstTimeMenu
end

function DB:SetFirstTimeMenu(value)
  DB.data.profile.firstTimeMenu = value
end

---@param kind BagKind
---@param view BagView
---@param opacity number
function DB:SetBagViewSizeOpacity(kind, view, opacity)
  DB.data.profile.size[view][kind].opacity = opacity
end

---@param kind BagKind
---@param view BagView
---@return SectionSortType
function DB:GetSectionSortType(kind, view)
  return DB.data.profile.sectionSort[kind][view]
end

---@param kind BagKind
---@param view BagView
---@param sort SectionSortType
function DB:SetSectionSortType(kind, view, sort)
  DB.data.profile.sectionSort[kind][view] = sort
end

---@param kind BagKind
---@return number
function DB:GetGlowIntensity(kind)
  return DB.data.profile.glowIntensity[kind]
end

---@param kind BagKind
---@param value number
function DB:SetGlowIntensity(kind, value)
  value = math.floor((tonumber(value) or 0) + 0.5)
  if value < 0 then
    value = 0
  elseif value > const.GLOW_INTENSITY_MAX then
    value = const.GLOW_INTENSITY_MAX
  end
  DB.data.profile.glowIntensity[kind] = value
end

---@param kind BagKind
---@param view BagView
---@return ItemSortType
function DB:GetItemSortType(kind, view)
  return DB.data.profile.itemSort[kind][view]
end

---@param kind BagKind
---@param view BagView
---@param sort ItemSortType
function DB:SetItemSortType(kind, view, sort)
  DB.data.profile.itemSort[kind][view] = sort
end

---@param itemID number
---@param category string
function DB:SaveItemToCategory(itemID, category)
  assert(DB.data.profile.customCategoryFilters[category] ~= nil, "Category does not exist: " .. category)
  DB.data.profile.customCategoryFilters[category].itemList[itemID] = true
  local previousCategory = DB.data.profile.customCategoryIndex[itemID]
  if previousCategory and previousCategory ~= category and DB.data.profile.customCategoryFilters[previousCategory] then
    DB.data.profile.customCategoryFilters[previousCategory].itemList[itemID] = nil
  end
  DB.data.profile.customCategoryIndex[itemID] = category
end

---@param itemID number
---@param category string
function DB:DeleteItemFromCategory(itemID, category)
  if DB.data.profile.customCategoryFilters[category] then
    DB.data.profile.customCategoryFilters[category].itemList[itemID] = nil
    -- Only its home: an item filed elsewhere stays filed there.
    if DB.data.profile.customCategoryIndex[itemID] == category then
      DB.data.profile.customCategoryIndex[itemID] = nil
    end
  end
end

---@param kind BagKind
---@param category string
---@param enabled boolean
function DB:SetItemCategoryEnabled(kind, category, enabled)
  assert(DB.data.profile.customCategoryFilters[category] ~= nil, "Category does not exist: " .. category)
  DB.data.profile.customCategoryFilters[category].enabled[kind] = enabled
end

function DB:SetEphemeralItemCategoryEnabled(kind, category, enabled)
  local filter = DB.data.profile.ephemeralCategoryFilters[category]
  if filter then
    filter.enabled[kind] = enabled
  end
end

---@param category string
function DB:DeleteItemCategory(category)
  if DB.data.profile.customCategoryFilters[category] ~= nil then
    DB.data.profile.customCategoryFilters[category].itemList = DB.data.profile.customCategoryFilters[category].itemList or {}
    for itemID, _ in pairs(DB.data.profile.customCategoryFilters[category].itemList) do
      DB:DeleteItemFromCategory(itemID, category)
    end
  end
  DB.data.profile.customCategoryFilters[category] = nil
  DB.data.profile.ephemeralCategoryFilters[category] = nil

  -- Scrub every side-table reference so the category cannot linger as an
  -- orphan. This mirrors RenameCategory; without it a leftover
  -- customSectionSort ("Pinned") entry resurfaces the deleted category forever
  -- as an undeletable "dynamic" category (see config's LoadPinnedItems /
  -- UpdateDetailPanel). Also drops any grouped sub-categories ("Name - X").
  local groupedPrefix = category .. " - "

  for name in pairs(DB.data.profile.ephemeralCategoryFilters) do
    if name:sub(1, #groupedPrefix) == groupedPrefix then
      DB.data.profile.ephemeralCategoryFilters[name] = nil
    end
  end

  for _, kind in pairs(const.BAG_KIND) do
    if DB.data.profile.customSectionSort[kind] then
      DB.data.profile.customSectionSort[kind][category] = nil
      for name in pairs(DB.data.profile.customSectionSort[kind]) do
        if name:sub(1, #groupedPrefix) == groupedPrefix then
          DB.data.profile.customSectionSort[kind][name] = nil
        end
      end
    end

    if DB.data.profile.categoryToGroup[kind] then
      DB.data.profile.categoryToGroup[kind][category] = nil
      if addon.isRetail and kind == const.BAG_KIND.BANK then
        for _, tbl in pairs(DB.data.profile.categoryToGroup[kind]) do
          if type(tbl) == "table" then
            tbl[category] = nil
          end
        end
      end
    end
  end
end

-- The name GetCategory now gives a category whose name repeated its item type
-- ("Quest - Quest" is "Quest", "Quest - Quest - Classic" is "Quest - Classic"), or nil.
---@param name string
---@return string|nil
local function nameWithoutRepeatedType(name)
  local separator = string.find(name, " - ", 1, true)
  if not separator then return nil end
  local typeName = string.sub(name, 1, separator - 1)
  local rest = string.sub(name, separator + 3)
  if rest == typeName or string.sub(rest, 1, #typeName + 3) == typeName .. " - " then
    return rest
  end
  return nil
end

-- RenameRepeatedTypeCategories moves the group assignments and pinned order saved under a
-- category name that repeated its item type (issue #183) to the category's current name. Custom
-- categories keep their names, and a setting already saved under the current name wins.
function DB:RenameRepeatedTypeCategories()
  local profile = DB.data.profile
  ---@param map table<any, any>
  local function renameKeys(map)
    local renames = {}
    for name in pairs(map) do
      if type(name) == "string"
        and profile.customCategoryFilters[name] == nil
        and profile.ephemeralCategoryFilters[name] == nil then
        renames[name] = nameWithoutRepeatedType(name)
      end
    end
    for oldName, newName in pairs(renames) do
      if map[newName] == nil then
        map[newName] = map[oldName]
      end
      map[oldName] = nil
    end
  end

  for _, kind in pairs(const.BAG_KIND) do
    if type(profile.customSectionSort[kind]) == "table" then
      renameKeys(profile.customSectionSort[kind])
    end
    local groupsByName = profile.categoryToGroup[kind]
    if type(groupsByName) == "table" then
      renameKeys(groupsByName)
      for _, groupsByBankType in pairs(groupsByName) do
        if type(groupsByBankType) == "table" then
          renameKeys(groupsByBankType)
        end
      end
    end
  end
end

-- The words a search's "group by" clause names, and the group by each means.
local GROUP_BY_WORDS = { none = 0, type = 1, subtype = 2, expansion = 3, exp = 3 }

-- categoryKinds returns every bag kind a category can be used in.
---@return BagKind[]
local function categoryKinds()
  local kinds = {}
  for name, kind in pairs(const.BAG_KIND) do
    if name ~= "UNDEFINED" then
      table.insert(kinds, kind)
    end
  end
  return kinds
end

-- normalizeEnabled returns the bags a category is used in, one entry per bag: a bag it does not name,
-- it is used in; the old single flag (a boolean) holds for every bag.
---@param enabled any
---@return table<BagKind, boolean>
local function normalizeEnabled(enabled)
  local all
  if type(enabled) == "boolean" then
    all = enabled
  end
  if type(enabled) ~= "table" then
    enabled = {}
  end
  for _, kind in ipairs(categoryKinds()) do
    if enabled[kind] == nil then
      if all ~= nil then
        enabled[kind] = all
      else
        enabled[kind] = true
      end
    end
  end
  return enabled
end

-- normalizeRule makes group by the category's own (from its rule, or a "group by" clause left at the
-- end of its search) and drops a rule whose search is empty.
---@param filter CustomCategoryFilter
local function normalizeRule(filter)
  local rule = filter.searchCategory
  if type(rule) ~= "table" then
    filter.searchCategory = nil
    return
  end
  local query = strtrim(rule.query or "")
  local lower = query:lower()
  local from, _, word = lower:find("group%s+by%s+(%w+)%s*$")
  if from ~= nil and (from == 1 or lower:sub(from - 1, from - 1):match("%s")) and GROUP_BY_WORDS[word] then
    filter.groupBy = GROUP_BY_WORDS[word]
    query = strtrim(query:sub(1, from - 1))
  elseif filter.groupBy == nil and rule.groupBy ~= nil then
    filter.groupBy = rule.groupBy
  end
  if query == "" then
    filter.searchCategory = nil
  else
    filter.searchCategory = { query = query }
  end
end

-- NormalizeCategories brings saved categories to the unified shape (category-lifecycle.md §6): every
-- category used in every bag it does not leave out, marked saved, an item list, group by its own and no
-- empty rule;
-- the item index rebuilt from the item lists (an item listed in several keeps the category its index
-- names, else the lowest priority number, then the first name; entries naming no list are dropped);
-- hidden sections dropped (hiding was retired). Run on every load and every import; it changes nothing
-- a second time.
function DB:NormalizeCategories()
  local profile = DB.data.profile
  profile.categoryOptions = nil
  profile.customCategoryFilters = profile.customCategoryFilters or {}
  profile.ephemeralCategoryFilters = profile.ephemeralCategoryFilters or {}
  for name, filter in pairs(profile.customCategoryFilters) do
    filter.name = name
    filter.save = true
    filter.itemList = type(filter.itemList) == "table" and filter.itemList or {}
    filter.enabled = normalizeEnabled(filter.enabled)
    normalizeRule(filter)
  end
  for name, filter in pairs(profile.ephemeralCategoryFilters) do
    filter.name = name
    filter.enabled = normalizeEnabled(filter.enabled)
  end

  local old = profile.customCategoryIndex or {}
  local claims = {}
  for _, filter in pairs(profile.customCategoryFilters) do
    for itemID in pairs(filter.itemList) do
      claims[itemID] = claims[itemID] or {}
      table.insert(claims[itemID], filter)
    end
  end
  local index = {}
  for itemID, list in pairs(claims) do
    local home
    for _, filter in ipairs(list) do
      if filter.name == old[itemID] then
        home = filter
      end
    end
    if home == nil then
      table.sort(list, function(a, b)
        local pa, pb = a.priority or 10, b.priority or 10
        if pa ~= pb then
          return pa < pb
        end
        return a.name < b.name
      end)
      home = list[1]
    end
    for _, filter in ipairs(list) do
      if filter ~= home then
        filter.itemList[itemID] = nil
      end
    end
    index[itemID] = home.name
  end
  profile.customCategoryIndex = index
end

-- MigrateSearchRules brings the profile's saved rules to the query language QueryParser reads
-- now, once: rules written in version 1 (AND and OR at one precedence, grouped left to right) get
-- the parentheses that keep their meaning with AND binding tighter (QueryParser:GroupLeftToRight).
-- from is the version they were written in: the profile's (searchRuleVersion), else 1.
---@param from? number
function DB:MigrateSearchRules(from)
  ---@class QueryParser: AceModule
  local QueryParser = addon:GetModule('QueryParser')
  local profile = DB.data.profile
  if (from or profile.searchRuleVersion or 1) < 2 then
    for _, filter in pairs(profile.customCategoryFilters or {}) do
      local rule = filter.searchCategory
      if type(rule) == "table" and type(rule.query) == "string" then
        rule.query = QueryParser:GroupLeftToRight(rule.query)
      end
    end
  end
  profile.searchRuleVersion = QueryParser.VERSION
end

---@param category string
function DB:WipeItemCategory(category)
  if DB.data.profile.customCategoryFilters[category] then
    DB.data.profile.customCategoryFilters[category].itemList = DB.data.profile.customCategoryFilters[category].itemList or {}
    for itemID, _ in pairs(DB.data.profile.customCategoryFilters[category].itemList) do
      DB:DeleteItemFromCategory(itemID, category)
    end
  end
end

---@return table<string, CustomCategoryFilter>
function DB:GetAllItemCategories()
  for category, _ in pairs(DB.data.profile.customCategoryFilters) do
    DB.data.profile.customCategoryFilters[category].name = category
  end
  return DB.data.profile.customCategoryFilters
end

---@param category string
---@return CustomCategoryFilter?
function DB:GetItemCategory(category)
  return DB.data.profile.customCategoryFilters[category]
end

---@param category string
---@return CustomCategoryFilter?
function DB:GetEphemeralItemCategory(category)
  return DB.data.profile.ephemeralCategoryFilters[category]
end

function DB:GetAllEphemeralItemCategories()
  return DB.data.profile.ephemeralCategoryFilters
end

---@param category string
---@return boolean
function DB:ItemCategoryExists(category)
  return DB.data.profile.customCategoryFilters[category] ~= nil
end

---@param itemID number
---@return CustomCategoryFilter
function DB:GetItemCategoryByItemID(itemID)
  return DB.data.profile.customCategoryFilters[DB.data.profile.customCategoryIndex[itemID]] or {}
end

---@param category CustomCategoryFilter
function DB:CreateOrUpdateCategory(category)
  if category.save then
    DB.data.profile.customCategoryFilters[category.name] = category
    category.itemList = category.itemList or {}
    for itemID, _ in pairs(category.itemList) do
      DB.data.profile.customCategoryIndex[itemID] = category.name
    end
  else
    -- A plugin's category saves only what is the player's (its bags, and the color, priority,
    -- automation and confirming they set): the plugin gives the rest again when it makes it.
    local saved = DB.data.profile.ephemeralCategoryFilters[category.name]
    DB.data.profile.ephemeralCategoryFilters[category.name] = {
      name = category.name,
      enabled = category.enabled,
      dynamic = category.dynamic,
      isGroupBySubcategory = category.isGroupBySubcategory,
      groupByParent = category.groupByParent,
      itemList = {},
      color = saved and saved.color,
      priority = saved and saved.priority,
      automation = saved and saved.automation,
      confirmSale = saved and saved.confirmSale,
      skipRecent = saved and saved.skipRecent,
      ignoredItems = saved and saved.ignoredItems,
      hidden = saved and saved.hidden,
    }
  end
end

-- UpdateEphemeralItemCategory saves what a player set for a plugin's category (its bags, color,
-- priority, automation, confirming, skipping Recent Items, its Ignored Items, the bags it is hidden in).
---@param name string
---@param fields {enabled?: table<BagKind, boolean>, color?: number[], priority?: number, automation?: string, confirmSale?: boolean, skipRecent?: boolean, ignoredItems?: table<number, boolean>}
function DB:UpdateEphemeralItemCategory(name, fields)
  local saved = DB.data.profile.ephemeralCategoryFilters[name]
  if saved == nil then
    saved = { name = name, itemList = {} }
    DB.data.profile.ephemeralCategoryFilters[name] = saved
  end
  saved.enabled = fields.enabled
  saved.color = fields.color
  saved.priority = fields.priority
  saved.automation = fields.automation
  saved.confirmSale = fields.confirmSale
  saved.skipRecent = fields.skipRecent
  saved.ignoredItems = fields.ignoredItems
  saved.hidden = fields.hidden
end

---@param category string
---@return boolean
function DB:IsSearchCategory(category)
  return DB.data.profile.searchCategories[category] ~= nil
end

---@return boolean
function DB:GetEnterToMakeCategory()
  return DB.data.profile.enterToMakeCategory
end

---@param value boolean
function DB:SetEnterToMakeCategory(value)
  DB.data.profile.enterToMakeCategory = value
end

---@param kind BagKind
function DB:ClearCustomSectionSort(kind)
  DB.data.profile.customSectionSort[kind] = {}
end

---@param kind BagKind
---@param category string
---@param sort number
function DB:SetCustomSectionSort(kind, category, sort)
  DB.data.profile.customSectionSort[kind][category] = sort
end

---@param kind BagKind
---@return table<string, number>
function DB:GetCustomSectionSort(kind)
  return DB.data.profile.customSectionSort[kind]
end

---@param guid string
---@param locked boolean
function DB:SetItemLock(guid, locked)
  DB.data.profile.lockedItems[guid] = locked
end

---@param guid string
---@return boolean
function DB:GetItemLock(guid)
  return DB.data.profile.lockedItems[guid]
end

---@param t number
function DB:SetNewItemTime(t)
  DB.data.profile.newItemTime = t
end

---@return number
function DB:GetNewItemTime()
  return DB.data.profile.newItemTime
end

---@param enabled boolean
function DB:SetDebugMode(enabled)
  DB.data.profile.debug = enabled
end

---@return boolean
function DB:GetDebugMode()
  return DB.data.profile.debug
end

---@param enabled boolean
function DB:SetInBagSearch(enabled)
  DB.data.profile.inBagSearch = enabled
end

---@return boolean
function DB:GetInBagSearch()
  return DB.data.profile.inBagSearch
end

---@param enabled boolean
function DB:SetCategorySell(enabled)
  DB.data.profile.categorySell = enabled
end


---@return boolean
function DB:GetCategorySell()
  return DB.data.profile.categorySell
end

function DB:GetStackingOptions(kind)
  return DB.data.profile.stacking[kind]
end

function DB:SetMergeItems(kind, value)
  DB.data.profile.stacking[kind].mergeStacks = value
end

function DB:SetMergeUnstackable(kind, value)
  DB.data.profile.stacking[kind].mergeUnstackable = value
end

function DB:SetUnmergeAtShop(kind, value)
  DB.data.profile.stacking[kind].unmergeAtShop = value
end

function DB:SetDontMergePartial(kind, value)
  DB.data.profile.stacking[kind].dontMergePartial = value
end

function DB:SetDontMergeTransmog(kind, value)
  DB.data.profile.stacking[kind].dontMergeTransmog = value
end

function DB:GetShowKeybindWarning()
  return DB.data.profile.showKeybindWarning
end

function DB:SetShowKeybindWarning(value)
  DB.data.profile.showKeybindWarning = value
end

---@param kind BagKind
---@return boolean
function DB:GetShowFullSectionNames(kind)
  return DB.data.profile.showFullSectionNames[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetShowFullSectionNames(kind, value)
  DB.data.profile.showFullSectionNames[kind] = value
end

---@param key string
function DB:SetTheme(key)
  DB.data.profile.theme = key
end

---@return string
function DB:GetTheme()
  return DB.data.profile.theme
end

---@return string
function DB:GetUpgradeIconProvider()
  return DB.data.profile.upgradeIconProvider
end

---@param value string
function DB:SetUpgradeIconProvider(value)
  DB.data.profile.upgradeIconProvider = value
  -- Record that the user made an explicit choice, so external-provider
  -- precedence (see items:GetActiveUpgradeProvider) stops overriding it.
  DB.data.profile.upgradeIconProviderUserSet = true
end

---@return boolean
function DB:GetUpgradeIconProviderUserSet()
  return DB.data.profile.upgradeIconProviderUserSet or false
end

---@param kind BagKind
---@return boolean
function DB:GetShowAllFreeSpace(kind)
  return DB.data.profile.showAllFreeSpace[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetShowAllFreeSpace(kind, value)
  DB.data.profile.showAllFreeSpace[kind] = value
end

---@param kind BagKind
---@return boolean
function DB:GetPreserveItemGaps(kind)
  local t = DB.data.profile.preserveItemGaps
  if not t then return false end
  return t[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetPreserveItemGaps(kind, value)
  DB.data.profile.preserveItemGaps = DB.data.profile.preserveItemGaps or {}
  DB.data.profile.preserveItemGaps[kind] = value
end

-------
--- Groups Feature
-------

---@param kind BagKind
---@return table<number, Group>
function DB:GetAllGroups(kind)
  if not kind or not DB.data.profile.groups[kind] then return {} end
  return DB.data.profile.groups[kind]
end

---@param kind BagKind
---@param groupID number
---@return Group?
function DB:GetGroup(kind, groupID)
  if not kind or not DB.data.profile.groups[kind] then return nil end
  return DB.data.profile.groups[kind][groupID]
end

---@param kind BagKind
---@param name string
---@param bankType? number
---@return number The new group ID
function DB:CreateGroup(kind, name, bankType)
  local newID = DB.data.profile.groupCounter[kind] + 1
  DB.data.profile.groupCounter[kind] = newID
  DB.data.profile.groups[kind][newID] = {
    id = newID,
    name = name,
    order = newID,
    kind = kind,
    bankType = bankType,
  }
  return newID
end

---@param kind BagKind
---@param groupID number
function DB:DeleteGroup(kind, groupID)
  local group = DB.data.profile.groups[kind][groupID]
  if not group then return end

  -- Don't allow deleting default groups
  if group.isDefault then return end

  -- Remove category associations for this group
  if addon.isRetail and kind == const.BAG_KIND.BANK then
    local bankType = group.bankType
    if bankType ~= nil and type(DB.data.profile.categoryToGroup[kind][bankType]) == "table" then
      for categoryName, gID in pairs(DB.data.profile.categoryToGroup[kind][bankType]) do
        if gID == groupID then
          DB.data.profile.categoryToGroup[kind][bankType][categoryName] = nil
        end
      end
    else
      for _, tbl in pairs(DB.data.profile.categoryToGroup[kind]) do
        if type(tbl) == "table" then
          for categoryName, gID in pairs(tbl) do
            if gID == groupID then
              tbl[categoryName] = nil
            end
          end
        end
      end
    end
  else
    for categoryName, gID in pairs(DB.data.profile.categoryToGroup[kind]) do
      if gID == groupID then
        DB.data.profile.categoryToGroup[kind][categoryName] = nil
      end
    end
  end

  -- Remove the group
  DB.data.profile.groups[kind][groupID] = nil

  -- If this was the active group, switch to default
  if DB.data.profile.activeGroup[kind] == groupID then
    if kind == const.BAG_KIND.BACKPACK then
      DB.data.profile.activeGroup[kind] = 1
    elseif kind == const.BAG_KIND.BANK then
      local charBankType = Enum.BankType and Enum.BankType.Character or 1
      for id, g in pairs(DB.data.profile.groups[kind]) do
        if g.isDefault and g.bankType == charBankType then
          DB.data.profile.activeGroup[kind] = id
          break
        end
      end
    end
  end
end

---@param kind BagKind
---@param groupID number
---@param name string
function DB:RenameGroup(kind, groupID, name)
  if DB.data.profile.groups[kind][groupID] then
    DB.data.profile.groups[kind][groupID].name = name
  end
end

-- RenameCategory renames a category by updating all data structures that use the category name as a key.
---@param oldName string
---@param newName string
---@return boolean success
function DB:RenameCategory(oldName, newName)
  -- Trim whitespace and validate new name
  newName = strtrim(newName)
  if newName == "" then
    return false
  end

  -- Validate old category exists and new name doesn't conflict
  if not DB.data.profile.customCategoryFilters[oldName] then
    return false
  end
  if DB.data.profile.customCategoryFilters[newName] then
    return false
  end

  -- 1. Move main category data structure
  DB.data.profile.customCategoryFilters[newName] = DB.data.profile.customCategoryFilters[oldName]
  DB.data.profile.customCategoryFilters[newName].name = newName
  DB.data.profile.customCategoryFilters[oldName] = nil

  -- 2. Update item index for all items pointing to old category
  for itemID, categoryName in pairs(DB.data.profile.customCategoryIndex) do
    if categoryName == oldName then
      DB.data.profile.customCategoryIndex[itemID] = newName
    end
  end

  -- 3. Update group mapping
  for _, kind in pairs(const.BAG_KIND) do
    if DB.data.profile.categoryToGroup[kind] then
      if DB.data.profile.categoryToGroup[kind][oldName] then
        DB.data.profile.categoryToGroup[kind][newName] = DB.data.profile.categoryToGroup[kind][oldName]
        DB.data.profile.categoryToGroup[kind][oldName] = nil
      end
      if addon.isRetail and kind == const.BAG_KIND.BANK then
        for _, tbl in pairs(DB.data.profile.categoryToGroup[kind]) do
          if type(tbl) == "table" and tbl[oldName] then
            tbl[newName] = tbl[oldName]
            tbl[oldName] = nil
          end
        end
      end
    end
  end

  -- 4. Update ephemeral filters
  if DB.data.profile.ephemeralCategoryFilters[oldName] then
    DB.data.profile.ephemeralCategoryFilters[newName] = DB.data.profile.ephemeralCategoryFilters[oldName]
    DB.data.profile.ephemeralCategoryFilters[oldName] = nil
  end

  -- Delete grouped sub-categories from ephemeral filters (e.g., "OldName - Consumable")
  -- These will be recreated with the new name on next refresh
  local groupedPrefix = oldName .. " - "
  for categoryName, _ in pairs(DB.data.profile.ephemeralCategoryFilters) do
    if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
      DB.data.profile.ephemeralCategoryFilters[categoryName] = nil
    end
  end

  -- 5. Update custom section sort (pinned position) for all bag kinds
  for _, kind in pairs(const.BAG_KIND) do
    if DB.data.profile.customSectionSort[kind] and DB.data.profile.customSectionSort[kind][oldName] ~= nil then
      DB.data.profile.customSectionSort[kind][newName] = DB.data.profile.customSectionSort[kind][oldName]
      DB.data.profile.customSectionSort[kind][oldName] = nil
    end

    -- Delete grouped sub-categories from custom section sort
    if DB.data.profile.customSectionSort[kind] then
      for categoryName, _ in pairs(DB.data.profile.customSectionSort[kind]) do
        if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
          DB.data.profile.customSectionSort[kind][categoryName] = nil
        end
      end
    end
  end

  return true
end

---@param kind BagKind
---@return number
function DB:GetNextGroupID(kind)
  return DB.data.profile.groupCounter[kind] + 1
end

---@param kind BagKind
---@param categoryName string
---@param bankType? number
---@return number? The group ID, or nil if not assigned (belongs to Backpack/Bank default)
function DB:GetCategoryGroup(kind, categoryName, bankType)
  local categoryMap = DB.data.profile.categoryToGroup[kind]
  if not categoryMap then return nil end

  if addon.isRetail and kind == const.BAG_KIND.BANK then
    if bankType ~= nil then
      local bankTypeTable = categoryMap[bankType]
      if bankTypeTable then
        return bankTypeTable[categoryName]
      end
    else
      local charBankType = Enum.BankType and Enum.BankType.Character or 0
      local accountBankType = Enum.BankType and Enum.BankType.Account or 2
      local charTable = categoryMap[charBankType]
      if charTable and charTable[categoryName] then return charTable[categoryName] end
      local accountTable = categoryMap[accountBankType]
      if accountTable and accountTable[categoryName] then return accountTable[categoryName] end
    end
    -- Fallback for flat unmigrated entries if any
    return categoryMap[categoryName]
  end

  return categoryMap[categoryName]
end

---@param kind BagKind
---@param categoryName string
---@param groupID number
---@param bankType? number
function DB:SetCategoryGroup(kind, categoryName, groupID, bankType)
  if addon.isRetail and kind == const.BAG_KIND.BANK then
    if bankType == nil then
      local group = DB:GetGroup(kind, groupID)
      bankType = group and group.bankType or ((Enum.BankType and Enum.BankType.Character) or 0)
    end
    if not DB.data.profile.categoryToGroup[kind][bankType] then
      DB.data.profile.categoryToGroup[kind][bankType] = {}
    end
    DB.data.profile.categoryToGroup[kind][bankType][categoryName] = groupID
    return
  end
  DB.data.profile.categoryToGroup[kind][categoryName] = groupID
end

---@param kind BagKind
---@param categoryName string
---@param bankType? number
function DB:RemoveCategoryFromGroup(kind, categoryName, bankType)
  if addon.isRetail and kind == const.BAG_KIND.BANK then
    if bankType ~= nil then
      if DB.data.profile.categoryToGroup[kind][bankType] then
        DB.data.profile.categoryToGroup[kind][bankType][categoryName] = nil
      end
    else
      for _, tbl in pairs(DB.data.profile.categoryToGroup[kind]) do
        if type(tbl) == "table" then
          tbl[categoryName] = nil
        end
      end
      DB.data.profile.categoryToGroup[kind][categoryName] = nil
    end
    return
  end
  DB.data.profile.categoryToGroup[kind][categoryName] = nil
end

---@param kind BagKind
---@param groupID number
---@return table<string, boolean> Category names in this group
function DB:GetGroupCategories(kind, groupID)
  local categories = {}
  if addon.isRetail and kind == const.BAG_KIND.BANK then
    local group = DB:GetGroup(kind, groupID)
    local bankType = group and group.bankType
    if bankType ~= nil and type(DB.data.profile.categoryToGroup[kind][bankType]) == "table" then
      for categoryName, gID in pairs(DB.data.profile.categoryToGroup[kind][bankType]) do
        if gID == groupID then
          categories[categoryName] = true
        end
      end
      return categories
    end
    for _, tbl in pairs(DB.data.profile.categoryToGroup[kind]) do
      if type(tbl) == "table" then
        for categoryName, gID in pairs(tbl) do
          if gID == groupID then
            categories[categoryName] = true
          end
        end
      end
    end
    return categories
  end
  for categoryName, gID in pairs(DB.data.profile.categoryToGroup[kind]) do
    if gID == groupID then
      categories[categoryName] = true
    end
  end
  return categories
end

---@param kind BagKind
---@return number The active group ID (defaults to 1 for Backpack)
function DB:GetActiveGroup(kind)
  return DB.data.profile.activeGroup[kind] or 1
end

---@param kind BagKind
---@param groupID number
function DB:SetActiveGroup(kind, groupID)
  DB.data.profile.activeGroup[kind] = groupID
end

---@param kind BagKind
---@param groupID number
---@param order number
function DB:SetGroupOrder(kind, groupID, order)
  local group = DB.data.profile.groups[kind][groupID]
  if group then
    group.order = order
  end
end

---@param kind BagKind
---@param groupID number
---@return number
function DB:GetGroupOrder(kind, groupID)
  local group = DB.data.profile.groups[kind][groupID]
  return group and group.order or groupID  -- Default to ID if order not set
end

-- Export category configuration to a base64-encoded string
---@return string
function DB:ExportSettings()
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')

  -- Create a table with only category configuration settings
  -- Version 2: unified categories (DB:NormalizeCategories), no hidden sections. Version 3: rules
  -- written with AND binding tighter than OR (search rule version 2). Older imports are brought to it.
  local exportData = {
    version = 3,
    customCategoryFilters = serialization:DeepCopy(DB.data.profile.customCategoryFilters),
    customCategoryIndex = serialization:DeepCopy(DB.data.profile.customCategoryIndex),
    ephemeralCategoryFilters = serialization:DeepCopy(DB.data.profile.ephemeralCategoryFilters),
    categoryFilters = serialization:DeepCopy(DB.data.profile.categoryFilters),
    customSectionSort = serialization:DeepCopy(DB.data.profile.customSectionSort),
  }

  -- Serialize the table
  local serialized = serialization:Serialize(exportData)

  -- Encode to base64
  local encoded = serialization:EncodeBase64(serialized)

  -- Add BetterBags prefix for identification
  return "!BB" .. encoded
end

-- Import category configuration from a base64-encoded string
---@param dataString string
---@return boolean, string
function DB:ImportSettings(dataString)
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')

  if not dataString or dataString == "" then
    return false, "Import data is empty"
  end

  -- Remove whitespace
  dataString = dataString:gsub("%s+", "")

  -- Validate and strip BetterBags prefix
  if not dataString:match("^!BB") then
    return false, "Invalid import string: Missing !BB prefix. Please make sure you copied the full export string."
  end
  dataString = dataString:sub(4) -- Remove "!BB" prefix

  -- Decode from base64
  local decoded = serialization:DecodeBase64(dataString)
  if not decoded then
    return false, "Failed to decode import data"
  end

  -- Deserialize the table
  local importData, err = serialization:Deserialize(decoded)
  if not importData then
    return false, "Failed to parse import data: " .. (err or "unknown error")
  end

  -- Validate version
  if not importData.version or type(importData.version) ~= "number" then
    return false, "Invalid import data format"
  end

  -- Apply the imported category configuration
  if importData.customCategoryFilters then
    DB.data.profile.customCategoryFilters = serialization:DeepCopy(importData.customCategoryFilters)
  end

  if importData.customCategoryIndex then
    DB.data.profile.customCategoryIndex = serialization:DeepCopy(importData.customCategoryIndex)
  end

  if importData.ephemeralCategoryFilters then
    DB.data.profile.ephemeralCategoryFilters = serialization:DeepCopy(importData.ephemeralCategoryFilters)
  end

  if importData.categoryFilters then
    DB.data.profile.categoryFilters = serialization:DeepCopy(importData.categoryFilters)
  end

  if importData.customSectionSort then
    DB.data.profile.customSectionSort = serialization:DeepCopy(importData.customSectionSort)
  end

  DB:NormalizeCategories()
  -- Exports before version 3 hold rules of search rule version 1.
  DB:MigrateSearchRules(importData.version >= 3 and 2 or 1)
  return true, "Category configuration imported successfully"
end

function DB:Migrate()

  --[[
    Deletion of the old lockedItems table.
    Do not remove before Q1'25.
  ]]--
  DB.data.profile.lockedItems = {}

  --[[
    Migration away from multi-view bags and bank to a single view.
    Do not remove before Q1'25.
  ]]--
  if DB:GetBagView(const.BAG_KIND.BACKPACK) ~= const.BAG_VIEW.SECTION_GRID and DB:GetBagView(const.BAG_KIND.BACKPACK) ~= const.BAG_VIEW.SECTION_ALL_BAGS then
    DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
  end

  if DB:GetBagView(const.BAG_KIND.BANK) ~= const.BAG_VIEW.SECTION_GRID and DB:GetBagView(const.BAG_KIND.BANK) ~= const.BAG_VIEW.SECTION_ALL_BAGS then
    DB:SetBagView(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID)
  end

  -- Unified categories, every load (category-lifecycle.md §6). It also turns the old single enabled
  -- flag into one per bag.
  DB:NormalizeCategories()

  -- Saved rules from before AND bound tighter than OR, once per profile (search-indexing.md §6).
  DB:MigrateSearchRules()

  -- Fix the column count and items per row values from a previous bug.
  -- Do not remove before Q1'25.
  for _, bagView in pairs(const.BAG_VIEW) do
    for _, bagKind in pairs(const.BAG_KIND) do
      if DB.data.profile.size[bagView] then
        local t = DB.data.profile.size[bagView][bagKind]
        if t then
          if t.itemsPerRow and (t.itemsPerRow > 30 or t.itemsPerRow < 1) then
            t.itemsPerRow = 7
          end
        end
      end
    end
  end

  --[[
    Section collapsing was removed: drop its saved state.
    Do not remove before Q3'27.
  ]]--
  DB.data.profile.collapsedSections = nil

  --[[
    Category automation sells everything in waves (automation.md §3): the 12-item limit setting
    is gone. Do not remove before Q3'27.
  ]]--
  DB.data.profile.autoSellLimit = nil

  -- ============================================================
  -- Dynamic Item Level Coloring Migration (Q1'27)
  -- Do not remove before Q3'27
  -- ============================================================
  if not DB.data.profile.itemLevelColor then
    -- Use defaults from constants
    local defaults = const.DATABASE_DEFAULTS.profile.itemLevelColor
    DB.data.profile.itemLevelColor = {
      maxItemLevelByCharacter = {},
      colors = {
        low = { red = defaults.colors.low.red, green = defaults.colors.low.green, blue = defaults.colors.low.blue, alpha = defaults.colors.low.alpha },
        mid = { red = defaults.colors.mid.red, green = defaults.colors.mid.green, blue = defaults.colors.mid.blue, alpha = defaults.colors.mid.alpha },
        high = { red = defaults.colors.high.red, green = defaults.colors.high.green, blue = defaults.colors.high.blue, alpha = defaults.colors.high.alpha },
        max = { red = defaults.colors.max.red, green = defaults.colors.max.green, blue = defaults.colors.max.blue, alpha = defaults.colors.max.alpha }
      }
    }
  end

  -- Migrate old single maxItemLevel to per-character tracking
  if DB.data.profile.itemLevelColor.maxItemLevel then
    local oldMax = DB.data.profile.itemLevelColor.maxItemLevel
    local characterKey = UnitName("player") .. "-" .. GetRealmName()
    if not DB.data.profile.itemLevelColor.maxItemLevelByCharacter then
      DB.data.profile.itemLevelColor.maxItemLevelByCharacter = {}
    end
    -- Preserve old value for current character
    DB.data.profile.itemLevelColor.maxItemLevelByCharacter[characterKey] = oldMax
    -- Remove old field
    DB.data.profile.itemLevelColor.maxItemLevel = nil
  end

  -- Add missing fields if partial migration occurred
  if not DB.data.profile.itemLevelColor.maxItemLevelByCharacter then
    DB.data.profile.itemLevelColor.maxItemLevelByCharacter = {}
  end
  if not DB.data.profile.itemLevelColor.colors then
    local defaults = const.DATABASE_DEFAULTS.profile.itemLevelColor.colors
    DB.data.profile.itemLevelColor.colors = {
      low = { red = defaults.low.red, green = defaults.low.green, blue = defaults.low.blue, alpha = defaults.low.alpha },
      mid = { red = defaults.mid.red, green = defaults.mid.green, blue = defaults.mid.blue, alpha = defaults.mid.alpha },
      high = { red = defaults.high.red, green = defaults.high.green, blue = defaults.high.blue, alpha = defaults.high.alpha },
      max = { red = defaults.max.red, green = defaults.max.green, blue = defaults.max.blue, alpha = defaults.max.alpha }
    }
  end


  -- ============================================================
  -- "Extra Glowy" boolean -> glow intensity slider migration (Q3'27)
  -- Do not remove before Q3'28
  -- ============================================================
  -- The retired per-kind boolean extraGlowyButtons is replaced by a 0-100
  -- glowIntensity slider. Preserve the user's prior look: an enabled "Extra
  -- Glowy" maps to the full blinding halo (100), a disabled one to the flat
  -- colored border at the halo threshold (60). The old field is then dropped so
  -- this runs exactly once.
  if DB.data.profile.extraGlowyButtons ~= nil then
    for _, kind in pairs(const.BAG_KIND) do
      if DB.data.profile.glowIntensity[kind] ~= nil then
        DB.data.profile.glowIntensity[kind] = DB.data.profile.extraGlowyButtons[kind]
          and const.GLOW_INTENSITY_MAX
          or const.GLOW_INTENSITY_DEFAULT
      end
    end
    DB.data.profile.extraGlowyButtons = nil
  end

  -- Migrate to kind-scoped groups, groupCounter, and categoryToGroup
  if not DB.data.profile.__groupsScopedByKind then
    local oldGroups = DB.data.profile.groups
    local oldCategoryToGroup = DB.data.profile.categoryToGroup
    local oldGroupCounter = DB.data.profile.groupCounter

    -- Check if it's already scoped (e.g. fresh install with new defaults)
    -- We must ensure oldGroups[1] isn't just the old Backpack group.
    -- A scoped namespace will NOT have a 'name' field, whereas a group object will.
    local isAlreadyScoped = false
    if oldGroups and type(oldGroups) == "table" then
      local maybeBackpackNamespace = oldGroups[const.BAG_KIND.BACKPACK]
      local maybeBankNamespace = oldGroups[const.BAG_KIND.BANK]

      -- If it's a namespace, it shouldn't have an 'id' or 'name' directly on it
      if (maybeBackpackNamespace and type(maybeBackpackNamespace) == "table" and maybeBackpackNamespace.name == nil) or
         (maybeBankNamespace and type(maybeBankNamespace) == "table" and maybeBankNamespace.name == nil) then
        isAlreadyScoped = true
      end
    end

    if not isAlreadyScoped then
      DB.data.profile.groups = {
        [const.BAG_KIND.BACKPACK] = {},
        [const.BAG_KIND.BANK] = {}
      }
      DB.data.profile.categoryToGroup = {
        [const.BAG_KIND.BACKPACK] = {},
        [const.BAG_KIND.BANK] = {}
      }

      if type(oldGroupCounter) == "number" then
        DB.data.profile.groupCounter = {
          [const.BAG_KIND.BACKPACK] = oldGroupCounter,
          [const.BAG_KIND.BANK] = 0
        }
      end

      if oldGroups then
        -- First, move all groups to their respective kind
        for id, group in pairs(oldGroups) do
          if type(group) == "table" then
            local kind = group.kind or const.BAG_KIND.BACKPACK

            -- Fix bug where AceDB merged default Bank/Warbank fields into existing user groups with IDs 2 or 3.
            if id ~= 1 and group.isDefault then
              kind = const.BAG_KIND.BACKPACK
              group.kind = const.BAG_KIND.BACKPACK
              group.isDefault = nil
              group.bankType = nil
            end

            if id == 1 then
              group.isDefault = true
              kind = const.BAG_KIND.BACKPACK
              group.kind = const.BAG_KIND.BACKPACK
            end

            DB.data.profile.groups[kind][id] = group
          end
        end
      end

      if oldCategoryToGroup then
        for categoryName, groupID in pairs(oldCategoryToGroup) do
          if type(groupID) == "number" then
            -- We only know the old categoryToGroup mapped to backpacks
            local group = DB.data.profile.groups[const.BAG_KIND.BACKPACK] and DB.data.profile.groups[const.BAG_KIND.BACKPACK][groupID]
            if group then
              DB.data.profile.categoryToGroup[const.BAG_KIND.BACKPACK][categoryName] = groupID
            end
          end
        end
      end
    end

    DB.data.profile.__groupsScopedByKind = true
    DB.data.profile.__bankDefaultTabsFixed = true
  end

  -- Catch-all for users who may have slipped past the migration or had AceDB merge incorrectly
  if type(DB.data.profile.groupCounter) == "number" then
    DB.data.profile.groupCounter = {
      [const.BAG_KIND.BACKPACK] = DB.data.profile.groupCounter,
      [const.BAG_KIND.BANK] = 0
    }
  end

  -- Ensure defaults exist
  local charBankType = Enum.BankType and Enum.BankType.Character or 1
  local accountBankType = Enum.BankType and Enum.BankType.Account or 2

  if not DB.data.profile.groups[const.BAG_KIND.BACKPACK] then
    DB.data.profile.groups[const.BAG_KIND.BACKPACK] = {}
  end
  if not DB.data.profile.groups[const.BAG_KIND.BANK] then
    DB.data.profile.groups[const.BAG_KIND.BANK] = {}
  end

  local hasBank = false
  local hasWarbank = false

  for _, group in pairs(DB.data.profile.groups[const.BAG_KIND.BANK]) do
    if group.isDefault then
      if group.bankType == charBankType then
        hasBank = true
      elseif group.bankType == accountBankType then
        hasWarbank = true
      end
    end
  end

  if not hasBank then
    local newID = DB.data.profile.groupCounter[const.BAG_KIND.BANK] + 1
    DB.data.profile.groupCounter[const.BAG_KIND.BANK] = newID
    DB.data.profile.groups[const.BAG_KIND.BANK][newID] = {
      id = newID,
      name = L:G("Bank"),
      order = newID,
      kind = const.BAG_KIND.BANK,
      bankType = charBankType,
      isDefault = true,
    }
    if not DB.data.profile.activeGroup[const.BAG_KIND.BANK] then
      DB.data.profile.activeGroup[const.BAG_KIND.BANK] = newID
    end
  end

  -- Only seed the default Warbank group on clients that actually have a warbank.
  -- WoW: Forever (Camelot) is retail-shaped but has no account bank, so it must
  -- not get a Warbank group (which would otherwise create an empty account tab
  -- section and drive the whole data-side warbank surface). `hasWarbank` here is
  -- the local "profile already has a warbank group" flag; addon.hasWarbank is the
  -- client capability.
  if not hasWarbank and addon.hasWarbank then
    local newID = DB.data.profile.groupCounter[const.BAG_KIND.BANK] + 1
    DB.data.profile.groupCounter[const.BAG_KIND.BANK] = newID
    DB.data.profile.groups[const.BAG_KIND.BANK][newID] = {
      id = newID,
      name = L:G("Warbank"),
      order = newID,
      kind = const.BAG_KIND.BANK,
      bankType = accountBankType,
      isDefault = true,
    }
  end

  if DB.data.profile.activeGroup[const.BAG_KIND.BANK] == nil then
    -- Find the default Bank group ID
    for id, g in pairs(DB.data.profile.groups[const.BAG_KIND.BANK]) do
      if g.isDefault and g.bankType == charBankType then
        DB.data.profile.activeGroup[const.BAG_KIND.BANK] = id
        break
      end
    end
  end

  if DB.data.profile.groupsEnabled[const.BAG_KIND.BANK] == nil then
    DB.data.profile.groupsEnabled[const.BAG_KIND.BANK] = true
  end

  -- Migrate Retail Bank categories to be scoped by bankType
  if addon.isRetail and not DB.data.profile.__bankCategoriesScopedByBankType then
    local bankGroups = DB.data.profile.groups[const.BAG_KIND.BANK] or {}
    local oldBankCategoryToGroup = DB.data.profile.categoryToGroup[const.BAG_KIND.BANK]

    local flatEntries = {}
    if oldBankCategoryToGroup then
      for k, v in pairs(oldBankCategoryToGroup) do
        if type(k) == "string" and type(v) == "number" then
          flatEntries[k] = v
        end
      end
    end

    local newBankCategoryToGroup = {
      [charBankType] = (type(oldBankCategoryToGroup) == "table" and type(oldBankCategoryToGroup[charBankType]) == "table") and oldBankCategoryToGroup[charBankType] or {},
      [accountBankType] = (type(oldBankCategoryToGroup) == "table" and type(oldBankCategoryToGroup[accountBankType]) == "table") and oldBankCategoryToGroup[accountBankType] or {},
    }

    for catName, gID in pairs(flatEntries) do
      local grp = bankGroups[gID]
      local bType = grp and grp.bankType or charBankType
      if not newBankCategoryToGroup[bType] then
        newBankCategoryToGroup[bType] = {}
      end
      newBankCategoryToGroup[bType][catName] = gID
    end

    DB.data.profile.categoryToGroup[const.BAG_KIND.BANK] = newBankCategoryToGroup
    DB.data.profile.__bankCategoriesScopedByBankType = true
  end

  -- Ensure retail bank category tables exist
  if addon.isRetail and DB.data.profile.categoryToGroup and DB.data.profile.categoryToGroup[const.BAG_KIND.BANK] then
    local bankTable = DB.data.profile.categoryToGroup[const.BAG_KIND.BANK]
    if not bankTable[charBankType] then
      bankTable[charBankType] = {}
    end
    if not bankTable[accountBankType] then
      bankTable[accountBankType] = {}
    end
  end

  -- ============================================================
  -- Profile System Migration (Q1'26)
  -- Do not remove before Q3'26
  -- ============================================================
  if not DB.data.profile.__profileSystemMigrated then
    -- Detect current profile name
    local currentProfile = DB.data:GetCurrentProfile()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local autoProfile = playerName .. " - " .. realmName

    -- If using auto-generated character name profile, migrate to Default
    if currentProfile == autoProfile then
      local profiles = {}
      DB.data:GetProfiles(profiles)

      local hasDefault = false
      for _, name in ipairs(profiles) do
        if name == "Default" then
          hasDefault = true
          break
        end
      end

      if not hasDefault then
        -- Create Default and copy current settings
        DB.data:SetProfile("Default")
        DB.data:CopyProfile(autoProfile)
      else
        -- Switch to existing Default
        DB.data:SetProfile("Default")
      end
    end

    -- Mark migration complete
    DB.data.profile.__profileSystemMigrated = true
  end

  -- Quest items are no longer named "Quest - Quest"; their settings follow the new name.
  DB:RenameRepeatedTypeCategories()

  --[[
    The Moonlight themes were first released (alpha, 2026-10-16) under these keys.
    Do not remove before Q3'27.
  ]]--
  local renamedThemes = { MoonlightDark = "Dark", MoonlightParchment = "Parchment" }
  if renamedThemes[DB.data.profile.theme] ~= nil then
    DB.data.profile.theme = renamedThemes[DB.data.profile.theme]
  end
end

-- ============================================================
-- Profile Management
-- ============================================================

--- Get the name of the currently active profile
---@return string
function DB:GetCurrentProfileName()
  return DB.data:GetCurrentProfile()
end

--- Get list of all available profiles
---@return table<number, string>
function DB:GetAvailableProfiles()
  local profiles = {}
  DB.data:GetProfiles(profiles)
  return profiles
end

--- Get how many characters are using each profile
---@return table<string, number>
function DB:GetProfileCharacterCounts()
  local counts = {}

  -- Initialize all profiles with 0 count
  local profiles = {}
  DB.data:GetProfiles(profiles)
  for _, profileName in ipairs(profiles) do
    counts[profileName] = 0
  end

  -- Count characters per profile from profileKeys
  if DB.data.sv.profileKeys then
    for _, profileName in pairs(DB.data.sv.profileKeys) do
      counts[profileName] = (counts[profileName] or 0) + 1
    end
  end

  return counts
end

--- Switch to a different profile (creates if doesn't exist)
---@param name string
---@return boolean success
function DB:SwitchToProfile(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  DB.data:SetProfile(name)
  return true
end

--- Create a new profile with the given name
---@param name string
---@return boolean success
---@return string message
function DB:CreateProfile(name)
  if type(name) ~= "string" or name == "" then
    return false, "Profile name cannot be empty"
  end

  -- Check if profile already exists
  local profiles = {}
  DB.data:GetProfiles(profiles)
  for _, existingName in ipairs(profiles) do
    if existingName == name then
      return false, "A profile with this name already exists"
    end
  end

  -- SetProfile creates new profile if doesn't exist
  DB.data:SetProfile(name)
  -- No old rules in it; rules written before the next load are current ones.
  DB:MigrateSearchRules(addon:GetModule('QueryParser').VERSION)
  return true, "Profile created successfully"
end

--- Copy data from another profile to the current profile
---@param sourceName string
---@return boolean success
---@return string message
function DB:CopyFromProfile(sourceName)
  if type(sourceName) ~= "string" or sourceName == "" then
    return false, "Source profile name cannot be empty"
  end

  -- Verify source profile exists
  local profiles = {}
  DB.data:GetProfiles(profiles)
  local found = false
  for _, existingName in ipairs(profiles) do
    if existingName == sourceName then
      found = true
      break
    end
  end

  if not found then
    return false, "Source profile does not exist"
  end

  -- Copy from source to current profile
  DB.data:CopyProfile(sourceName)
  -- The copy has the source's rules, in the version the source has.
  DB:MigrateSearchRules()
  return true, "Profile copied successfully"
end

--- Rename the current profile
---@param oldName string
---@param newName string
---@return boolean success
---@return string message
function DB:RenameProfile(oldName, newName)
  if oldName == "Default" then
    return false, "Cannot rename the Default profile"
  end

  if type(newName) ~= "string" or newName == "" then
    return false, "Profile name cannot be empty"
  end

  -- Check if new name already exists
  local profiles = {}
  DB.data:GetProfiles(profiles)
  for _, existingName in ipairs(profiles) do
    if existingName == newName then
      return false, "A profile with this name already exists"
    end
  end

  -- Switch to old profile, copy to new name, delete old
  DB.data:SetProfile(oldName)
  DB.data:SetProfile(newName)
  DB.data:CopyProfile(oldName)

  -- Delete old profile
  DB.data:DeleteProfile(oldName, true)

  return true, "Profile renamed successfully"
end

--- Delete a profile (cannot delete Default or active profile)
---@param name string
---@return boolean success
---@return string message
function DB:DeleteProfile(name)
  if name == "Default" then
    return false, "Cannot delete the Default profile"
  end

  local currentProfile = DB.data:GetCurrentProfile()
  if currentProfile == name then
    return false, "Cannot delete the active profile. Switch to another profile first."
  end

  DB.data:DeleteProfile(name, true)
  return true, "Profile deleted successfully"
end

--- Reset the current profile to default settings
---@return boolean success
---@return string message
function DB:ResetCurrentProfile()
  DB.data:ResetProfile(false, true)
  DB:MigrateSearchRules(addon:GetModule('QueryParser').VERSION)
  return true, "Profile reset to defaults"
end

--- Get the saved backpack dump
---@return table
function DB:GetDebugBackpackDump()
  return DB.data.profile.debugBackpackDump or {}
end

--- Save a backpack dump
---@param dump table
function DB:SetDebugBackpackDump(dump, client, extras)
  DB.data.profile.debugBackpackDump = dump
  -- The client the dump was taken on (ItemProbe:Client).
  DB.data.profile.debugBackpackDumpClient = client
  -- What else the dump recorded: the player values, the worn gear, every bag's name, the open
  -- bank's items (frames/debug.lua).
  DB.data.profile.debugDumpExtras = extras
end

DB:Enable()
