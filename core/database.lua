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

---@alias InteractionBags "openClose"|"open"|"none"

-- The values an interaction's choice is checked against (interaction-bags.md).
local INTERACTION_BAGS = { openClose = true, open = true, none = true }

-- interactionName checks an interaction's name: one of the defaults' (const.DATABASE_DEFAULTS), nothing else.
---@param name string
local function interactionName(name)
  if const.DATABASE_DEFAULTS.profile.interactionBags[name] == nil then
    error("unknown interaction: " .. tostring(name))
  end
end

-- GetInteractionBags returns what the backpack does at an interaction, by its name in Enum.PlayerInteractionType
-- (interaction-bags.md): "openClose" (it opens with the interaction's window and closes with it), "open" (it opens,
-- and stays open after) or "none" (it is left as it is). Opened and closed at every interaction until told otherwise.
---@param name string
---@return InteractionBags
function DB:GetInteractionBags(name)
  interactionName(name)
  return DB.data.profile.interactionBags[name]
end

---@param name string
---@param value InteractionBags
function DB:SetInteractionBags(name, value)
  interactionName(name)
  if not INTERACTION_BAGS[value] then
    error("not what the backpack does at an interaction: " .. tostring(value))
  end
  DB.data.profile.interactionBags[name] = value
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

-- GetNextVendorEnabled returns whether BetterBags Next's vendor stands in for Blizzard's merchant frame (Enable Vendor
-- Window, next-bagsystem.md §11g). On unless turned off.
---@return boolean
function DB:GetNextVendorEnabled()
  return DB.data.profile.nextVendorEnabled
end

---@param enabled boolean
function DB:SetNextVendorEnabled(enabled)
  DB.data.profile.nextVendorEnabled = enabled
end

-- GetNextGuildBankEnabled returns whether BetterBags Next's guild bank stands in for Blizzard's guild bank frame (Enable
-- Guild Bank Window, next-bagsystem.md §11g). On unless turned off.
---@return boolean
function DB:GetNextGuildBankEnabled()
  return DB.data.profile.nextGuildBankEnabled
end

---@param enabled boolean
function DB:SetNextGuildBankEnabled(enabled)
  DB.data.profile.nextGuildBankEnabled = enabled
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

-- Each BetterBags Next bag has its own Size tab (its settings page): kind is the bag's, the vendor's UNDEFINED (next/vendor.lua).

-- sizeOption is one of a bag's Size tab settings. The logout's strip (initialization.md §7) removes one left at its
-- default, and a bag's table once all of its are: a panel drawn after it reads the default.
---@param kind BagKind
---@param key string
---@return any
local function sizeOption(kind, key)
  local options = DB.data.profile.nextSizeOptions
  local own = options and options[kind]
  if own == nil or own[key] == nil then
    return const.DATABASE_DEFAULTS.profile.nextSizeOptions[kind][key]
  end
  return own[key]
end

-- GetNextIconScale returns how big a BetterBags Next bag's item buttons are, in percent of the Next theme's icon size.
---@param kind BagKind
---@return number
function DB:GetNextIconScale(kind)
  return sizeOption(kind, "iconScale")
end

---@param kind BagKind
---@param value number
function DB:SetNextIconScale(kind, value)
  DB.data.profile.nextSizeOptions[kind].iconScale = nextScale(value)
end

-- GetNextBagScale returns the scale of a BetterBags Next bag's small panel, in percent; a full panel is always at its size.
---@param kind BagKind
---@return number
function DB:GetNextBagScale(kind)
  return sizeOption(kind, "bagScale")
end

---@param kind BagKind
---@param value number
function DB:SetNextBagScale(kind, value)
  DB.data.profile.nextSizeOptions[kind].bagScale = nextScale(value)
end

-- GetNextFitNamesWhileOpen returns whether a BetterBags Next bag's small panel follows what it shows while open: wider when
-- a section's name or the title would be cut short, back once it fits (next.md §14g).
---@param kind BagKind
---@return boolean
function DB:GetNextFitNamesWhileOpen(kind)
  return sizeOption(kind, "fitNamesWhileOpen")
end

---@param kind BagKind
---@param on boolean
function DB:SetNextFitNamesWhileOpen(kind, on)
  DB.data.profile.nextSizeOptions[kind].fitNamesWhileOpen = on
end

-- GetNextAutosize returns whether a BetterBags Next bag's small panel is as tall as what it shows (Autosize,
-- next-small-autosize.md): growing and shrinking with it while open, never past the screen.
---@param kind BagKind
---@return boolean
function DB:GetNextAutosize(kind)
  return sizeOption(kind, "autosize")
end

---@param kind BagKind
---@param on boolean
function DB:SetNextAutosize(kind, on)
  DB.data.profile.nextSizeOptions[kind].autosize = on
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

-- GetNextSmallPlace returns where a kind's small panel was left before it held its bottom corner
-- (docs/next-bag-anchor.md): its top left in UIParent's units, or nothing. The panel works its corner out from it the
-- first time it shows, and clears it.
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
function DB:ClearNextSmallPlace(kind)
  DB.data.profile.nextSmallPlaces[kind] = nil
end

---@alias NextSmallSide "LEFT"|"RIGHT"
---@alias NextSmallEdge "TOP"|"BOTTOM"

-- GetNextSmallCorner returns the corner a kind's small panel holds (docs/next-bag-anchor.md): one of its four corners in
-- UIParent's units, and which, its side ("LEFT" or "RIGHT") and its edge ("TOP" or "BOTTOM"); nothing before it was first
-- placed. A corner saved before corners had an edge (the anchor's first build, run in game) held its bottom.
---@param kind BagKind
---@return number? x, number? y, NextSmallSide? side, NextSmallEdge? edge
function DB:GetNextSmallCorner(kind)
  local corner = DB.data.profile.nextSmallCorners[kind]
  if corner == nil then
    return nil
  end
  return corner.x, corner.y, corner.side, corner.edge or "BOTTOM"
end

---@param kind BagKind
---@param x number
---@param y number
---@param side NextSmallSide
---@param edge NextSmallEdge
function DB:SetNextSmallCorner(kind, x, y, side, edge)
  if side ~= "LEFT" and side ~= "RIGHT" then
    error("unknown BetterBags Next corner side: " .. tostring(side))
  end
  if edge ~= "TOP" and edge ~= "BOTTOM" then
    error("unknown BetterBags Next corner edge: " .. tostring(edge))
  end
  DB.data.profile.nextSmallCorners[kind] = { x = x, y = y, side = side, edge = edge }
end

---@alias NextAnchorState "free"|"shown"|"locked"

-- GetNextAnchorState returns a kind's anchor (docs/next-bag-anchor.md): "free" (the bag moves and sizes), "shown" (its
-- anchor shows, and drags it), or "locked" (it neither moves nor sizes).
---@param kind BagKind
---@return NextAnchorState
function DB:GetNextAnchorState(kind)
  return DB.data.profile.nextAnchorStates[kind] or "free"
end

---@param kind BagKind
---@param state NextAnchorState
function DB:SetNextAnchorState(kind, state)
  if state ~= "free" and state ~= "shown" and state ~= "locked" then
    error("unknown BetterBags Next anchor state: " .. tostring(state))
  end
  DB.data.profile.nextAnchorStates[kind] = state ~= "free" and state or nil
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

---@alias NextAnimation "sparkles"|"shimmer"|"titleCloud"|"ribbon"|"braid"|"ornaments"|"glitch"|"rain"|"shatter"|"snow"|"smoke"|"bats"|"beam"|"paper"|"stopMotion"|"glassRain"|"lightning"|"sheen"

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

-- GetNextGlassTint returns how dark a glass theme's bags are (Appearance > Theme > Glass Tint, next-themes-glass.md
-- §26): in percent of the way from clear glass to the theme's smoke.
---@return number
function DB:GetNextGlassTint()
  return DB.data.profile.nextGlassTint
end

-- SetNextGlassTint saves it, a whole number from 0 to 100.
---@param value number
function DB:SetNextGlassTint(value)
  DB.data.profile.nextGlassTint = math.max(0, math.min(100, math.floor(value + 0.5)))
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

---@alias NextFoodDrinkOption "pick"|"layout"|"growX"|"growY"|"scale"|"background"|"hideInCombat"

-- The values a Food & Drink option is checked against: the rule, the bar's layouts and the ways it grows
-- (food-drink.md §5).
local FOOD_DRINK_CHOICES = {
  pick = { highest = true, lowest = true },
  layout = { row = true, column = true },
  growX = { left = true, right = true },
  growY = { up = true, down = true },
}

-- nextFoodDrinkOption checks a Food & Drink option's name: one of the defaults' (const.DATABASE_DEFAULTS), nothing else.
---@param name string
local function nextFoodDrinkOption(name)
  if const.DATABASE_DEFAULTS.profile.nextFoodDrink[name] == nil then
    error("unknown BetterBags Next Food & Drink option: " .. tostring(name))
  end
end

-- GetNextFoodDrinkOption returns how BetterBags Next's Food & Drink bar picks and shows (food-drink.md §5): which item
-- level it picks ("highest" or "lowest"), its layout ("row" or "column"), which way it grows (growX "left" or "right",
-- growY "down" or "up"), its scale (percent), its background, and whether it hides in combat.
---@param name NextFoodDrinkOption
---@return any
function DB:GetNextFoodDrinkOption(name)
  nextFoodDrinkOption(name)
  return DB.data.profile.nextFoodDrink[name]
end

---@param name NextFoodDrinkOption
---@param value any
function DB:SetNextFoodDrinkOption(name, value)
  nextFoodDrinkOption(name)
  local choices = FOOD_DRINK_CHOICES[name]
  if choices ~= nil and not choices[value] then
    error("not a Food & Drink " .. name .. ": " .. tostring(value))
  end
  DB.data.profile.nextFoodDrink[name] = value
end

-- GetNextFoodDrinkBar returns whether the Food & Drink bar is out, and where it was left: the corner it grows from, in
-- UIParent's units from the screen's top left; nothing before it was first placed. Put away, it remembers where it was.
---@return boolean out, number? x, number? y
function DB:GetNextFoodDrinkBar()
  local t = DB.data.profile.nextFoodDrinkBar
  return t.out == true, t.x, t.y
end

---@param out boolean
---@param x? number
---@param y? number
function DB:SetNextFoodDrinkBar(out, x, y)
  local t = DB.data.profile.nextFoodDrinkBar
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

-- GetHideEmptyGroups is whether a bag leaves out the tab of a group with nothing in it (Hide Empty Groups, groups.md §3).
-- Off once the logout's strip took the table, every value of which was its default (initialization.md §7).
---@param kind BagKind
---@return boolean
function DB:GetHideEmptyGroups(kind)
  local t = DB.data.profile.hideEmptyGroups
  return t ~= nil and t[kind] == true
end

---@param kind BagKind
---@param value boolean
function DB:SetHideEmptyGroups(kind, value)
  if DB.data.profile.hideEmptyGroups == nil then
    DB.data.profile.hideEmptyGroups = {}
  end
  DB.data.profile.hideEmptyGroups[kind] = value
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

-- sectionSortOf is the Section Order of the bags in use: each design keeps its own, as BetterBags Next's section columns
-- are apart from the classic bags' columns (next.md §7a).
---@param profile table
---@return table
local function sectionSortOf(profile)
  return profile.nextEnabled and profile.nextSectionSort or profile.sectionSort
end

---@param kind BagKind
---@param view BagView
---@return SectionSortType
function DB:GetSectionSortType(kind, view)
  return sectionSortOf(DB.data.profile)[kind][view]
end

---@param kind BagKind
---@param view BagView
---@param sort SectionSortType
function DB:SetSectionSortType(kind, view, sort)
  sectionSortOf(DB.data.profile)[kind][view] = sort
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

-- itemOrderOf returns an item order as one is kept (item-sort.md §1): the keys BetterBags has (const.ITEM_ORDER_KEY), each
-- once, at most ITEM_ORDER_DEPTH of them, read from a value that may be anything (a pasted string's); nil for none.
---@param value any
---@return ItemOrderKey[]?
local function itemOrderOf(value)
  if type(value) ~= "table" then
    return nil
  end
  local known = {}
  for _, key in pairs(const.ITEM_ORDER_KEY) do
    known[key] = true
  end
  local order, taken = {}, {}
  for _, key in ipairs(value) do
    if known[key] and not taken[key] and #order < const.ITEM_ORDER_DEPTH then
      taken[key] = true
      table.insert(order, key)
    end
  end
  return #order > 0 and order or nil
end

-- GetItemOrder returns the order of the items within each section of a bag in a view (item-sort.md §1): the keys it sorts
-- by, first to last, as a new list; DEFAULT_ITEM_ORDER until one is chosen.
---@param kind BagKind
---@param view BagView
---@return ItemOrderKey[]
function DB:GetItemOrder(kind, view)
  local byView = DB.data.profile.itemOrder[kind]
  return { unpack(byView and byView[view] or const.DEFAULT_ITEM_ORDER) }
end

-- SetItemOrder saves a copy of a bag's item order in a view.
---@param kind BagKind
---@param view BagView
---@param order ItemOrderKey[]
function DB:SetItemOrder(kind, view, order)
  local orders = DB.data.profile.itemOrder
  orders[kind] = orders[kind] or {}
  orders[kind][view] = { unpack(order) }
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
-- end of its search) and drops a rule whose search is empty. A category made from a Blizzard category
-- never groups: its clause is dropped (category-lifecycle.md §11).
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
    if not filter.blizzard then
      filter.groupBy = GROUP_BY_WORDS[word]
    end
    query = strtrim(query:sub(1, from - 1))
  elseif filter.groupBy == nil and rule.groupBy ~= nil and not filter.blizzard then
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
-- hidden sections dropped (hiding was retired); an item order of keys BetterBags has (itemOrderOf). Run on every load
-- and every import; it changes nothing a second time.
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
    filter.itemOrder = itemOrderOf(filter.itemOrder)
    normalizeRule(filter)
  end
  for name, filter in pairs(profile.ephemeralCategoryFilters) do
    filter.name = name
    filter.enabled = normalizeEnabled(filter.enabled)
    filter.itemOrder = itemOrderOf(filter.itemOrder)
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
    -- automation, confirming, deposit and item order they set): the plugin gives the rest again when it makes it.
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
      deposit = saved and saved.deposit,
      skipRecent = saved and saved.skipRecent,
      ignoredItems = saved and saved.ignoredItems,
      hidden = saved and saved.hidden,
      itemOrder = saved and saved.itemOrder,
    }
  end
end

-- UpdateEphemeralItemCategory saves what a player set for a plugin's category (its bags, color,
-- priority, automation, confirming, where it deposits, skipping Recent Items, its Ignored Items, the bags it
-- is hidden in, its own item order).
---@param name string
---@param fields {enabled?: table<BagKind, boolean>, color?: number[], priority?: number, automation?: string, confirmSale?: boolean, deposit?: string, skipRecent?: boolean, ignoredItems?: table<number, boolean>, hidden?: table<BagKind, boolean>, itemOrder?: ItemOrderKey[]}
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
  saved.deposit = fields.deposit
  saved.skipRecent = fields.skipRecent
  saved.ignoredItems = fields.ignoredItems
  saved.hidden = fields.hidden
  saved.itemOrder = fields.itemOrder
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

-- GetQuickFindEnabled returns whether the items in the backpack and bank can be found from the QuickFind addon
-- (quickfind.md). On unless turned off.
---@return boolean
function DB:GetQuickFindEnabled()
  return DB.data.profile.quickFindEnabled
end

---@param enabled boolean
function DB:SetQuickFindEnabled(enabled)
  DB.data.profile.quickFindEnabled = enabled
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

-- GetNextSectionColumns is how many columns of sections a bag of BetterBags Next is set to (next.md §7a).
---@param kind BagKind
---@return number
function DB:GetNextSectionColumns(kind)
  local count = DB.data.profile.nextSectionColumns[kind]
  if type(count) ~= "number" then
    return const.NEXT_SECTION_COLUMNS_DEFAULT
  end
  return math.max(1, math.min(const.NEXT_SECTION_COLUMNS_MAX, math.floor(count)))
end

---@param kind BagKind
---@param count number
function DB:SetNextSectionColumns(kind, count)
  DB.data.profile.nextSectionColumns[kind] = math.max(1, math.min(const.NEXT_SECTION_COLUMNS_MAX, math.floor(count)))
end

-- GetNextSectionFill is how a bag's sections fill its columns: "across" a row and then the next, or "down" a
-- column and then the next.
---@param kind BagKind
---@return "across"|"down"
function DB:GetNextSectionFill(kind)
  return DB.data.profile.nextSectionFill[kind] or "across"
end

---@param kind BagKind
---@param fill "across"|"down"
function DB:SetNextSectionFill(kind, fill)
  DB.data.profile.nextSectionFill[kind] = fill
end

-- GetNextSectionSpan is whether a bag's wide sections take more than one of its columns.
---@param kind BagKind
---@return boolean
function DB:GetNextSectionSpan(kind)
  return DB.data.profile.nextSectionSpan[kind] ~= false
end

---@param kind BagKind
---@param on boolean
function DB:SetNextSectionSpan(kind, on)
  DB.data.profile.nextSectionSpan[kind] = on
end

-- GetNextSectionCompact is whether a bag's sections stand on the next free grid position rather than in its columns.
---@param kind BagKind
---@return boolean
function DB:GetNextSectionCompact(kind)
  return DB.data.profile.nextSectionCompact[kind] == true
end

---@param kind BagKind
---@param on boolean
function DB:SetNextSectionCompact(kind, on)
  DB.data.profile.nextSectionCompact[kind] = on
end

-- GetNextSectionGap is whether a bag leaves an empty cell of the icon grid between its sections side by side.
---@param kind BagKind
---@return boolean
function DB:GetNextSectionGap(kind)
  return DB.data.profile.nextSectionGap[kind] == true
end

---@param kind BagKind
---@param on boolean
function DB:SetNextSectionGap(kind, on)
  DB.data.profile.nextSectionGap[kind] = on
end

-- GetNextSectionWideRows is how many rows a section takes in one of a bag's columns before it counts as wide.
---@param kind BagKind
---@return number
function DB:GetNextSectionWideRows(kind)
  local rows = DB.data.profile.nextSectionWideRows[kind]
  if type(rows) ~= "number" then
    return 2
  end
  return math.max(2, math.floor(rows))
end

---@param kind BagKind
---@param rows number
function DB:SetNextSectionWideRows(kind, rows)
  DB.data.profile.nextSectionWideRows[kind] = math.max(2, math.floor(rows))
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

-- takeBagSettings returns what each bag saved for a category (its tab, the retail bank's tab of each bank type, its pin)
-- and forgets it there.
---@param name string
---@return table
local function takeBagSettings(name)
  local taken = { tabs = {}, bankTabs = {}, pins = {} }
  for _, kind in pairs(const.BAG_KIND) do
    local groups = DB.data.profile.categoryToGroup[kind]
    if groups then
      taken.tabs[kind], groups[name] = groups[name], nil
      if addon.isRetail and kind == const.BAG_KIND.BANK then
        for bankType, tbl in pairs(groups) do
          if type(tbl) == "table" then
            taken.bankTabs[bankType], tbl[name] = tbl[name], nil
          end
        end
      end
    end
    local pins = DB.data.profile.customSectionSort[kind]
    if pins then
      taken.pins[kind], pins[name] = pins[name], nil
    end
  end
  return taken
end

-- putBagSettings saves under a category's name what takeBagSettings took, where it had something.
---@param name string
---@param taken table
local function putBagSettings(name, taken)
  for kind, groupID in pairs(taken.tabs) do
    DB.data.profile.categoryToGroup[kind][name] = groupID
  end
  for bankType, groupID in pairs(taken.bankTabs) do
    DB.data.profile.categoryToGroup[const.BAG_KIND.BANK][bankType][name] = groupID
  end
  for kind, index in pairs(taken.pins) do
    DB.data.profile.customSectionSort[kind][name] = index
  end
end

-- moveBagSettings moves what each bag saved for a category (its tab, its pin) to a new name.
---@param oldName string
---@param newName string
local function moveBagSettings(oldName, newName)
  putBagSettings(newName, takeBagSettings(oldName))
end

-- An equipment set's category, saved in the profile by the set's ID (category-lifecycle.md §12): what the player set for
-- it, and the name it last had ("Gear: " and the set's name), which its pins and tabs are saved under.
---@class (exact) GearSetRecord
---@field name string
---@field older? string The older entry (ephemeralCategoryFilters) the record was copied from, deleted with the set.
---@field enabled? table<BagKind, boolean>
---@field color? number[]
---@field priority? number
---@field automation? string
---@field confirmSale? boolean
---@field deposit? string
---@field skipRecent? boolean
---@field ignoredItems? table<number, boolean>
---@field hidden? table<BagKind, boolean>
---@field itemOrder? ItemOrderKey[]

-- What the player sets for a gear set's category (UpdateGearSet).
local GEAR_SET_FIELDS = { "enabled", "color", "priority", "automation", "confirmSale", "deposit", "skipRecent",
  "ignoredItems", "hidden", "itemOrder" }

---@param id number
---@return GearSetRecord?
function DB:GetGearSet(id)
  return DB.data.profile.gearSets[id]
end

-- GetGearSets returns every set's record, by set ID: every character's of the profile.
---@return table<number, GearSetRecord>
function DB:GetGearSets()
  return DB.data.profile.gearSets
end

---@param id number
---@param record GearSetRecord
function DB:SetGearSet(id, record)
  DB.data.profile.gearSets[id] = record
end

-- UpdateGearSet saves what the player set for a set's category (each field as given, none clearing it), keeping its
-- name. Nothing for a set with no record.
---@param id number
---@param fields table
function DB:UpdateGearSet(id, fields)
  local record = DB.data.profile.gearSets[id]
  if record == nil then
    return
  end
  for _, key in ipairs(GEAR_SET_FIELDS) do
    record[key] = fields[key]
  end
end

-- RenameGearSets gives sets' categories their sets' new names (renames: { id, name, bags }), moving each bag's pins and
-- tabs for a rename that says so (bags: what was saved under the old name is the set's alone, no other category or set
-- using either name: categories:renameGearSets). They move together, every old name's settings taken before any is
-- saved under its new name.
---@param renames {id: number, name: string, bags: boolean}[]
function DB:RenameGearSets(renames)
  local taken = {}
  for i, rename in ipairs(renames) do
    if rename.bags then
      taken[i] = takeBagSettings(DB.data.profile.gearSets[rename.id].name)
    end
  end
  for i, rename in ipairs(renames) do
    if taken[i] then
      putBagSettings(rename.name, taken[i])
    end
    DB.data.profile.gearSets[rename.id].name = rename.name
  end
end

-- DeleteGearSet forgets what was saved for a deleted set's category: with bags (no other category having its name), each
-- bag's pin and tab for it; with older, the older entry it copied (newGearSetRecord), so a set made again under that
-- name starts fresh (asked: "deleted should mean deleted"). An entry the set never copied is left alone.
---@param id number
---@param bags boolean
---@param older? string
function DB:DeleteGearSet(id, bags, older)
  local record = DB.data.profile.gearSets[id]
  if record == nil then
    return
  end
  if bags then
    takeBagSettings(record.name)
  end
  if older ~= nil then
    DB.data.profile.ephemeralCategoryFilters[older] = nil
  end
  DB.data.profile.gearSets[id] = nil
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

  -- 3. Update group mapping and custom section sort (pinned position) for all bag kinds
  moveBagSettings(oldName, newName)

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

  -- 5. Delete grouped sub-categories from custom section sort
  for _, kind in pairs(const.BAG_KIND) do
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

-- itemSet returns the item IDs a list holds, each true, or nil when it holds none. An item ID is a whole number above 0
-- and below 2^31 (an int32): a pasted string can hold any number, and one like inf would be saved as a key the next
-- load cannot read.
---@param list any
---@return table<number, boolean>?
local function itemSet(list)
  if type(list) ~= "table" then
    return nil
  end
  local set
  for id, on in pairs(list) do
    if type(id) == "number" and id > 0 and id < 2 ^ 31 and id == math.floor(id) and on == true then
      set = set or {}
      set[id] = true
    end
  end
  return set
end

-- colorOf returns a color of three or four parts, each from 0 to 1, or nil for anything else.
---@param color any
---@return number[]?
local function colorOf(color)
  if type(color) ~= "table" or (#color ~= 3 and #color ~= 4) then
    return nil
  end
  local copy = {}
  for i = 1, #color do
    local part = color[i]
    if type(part) ~= "number" or not (part >= 0 and part <= 1) then
      return nil
    end
    copy[i] = part
  end
  return copy
end

-- sharedCategory returns what a category shares (#1250, .claude/rules/import-export.md §7): its name, rule, items,
-- Ignored Items, group by, color, bags, the bags it is hidden in, its note, Skip Recent Items and its own item order, each
-- of the shape it has. What it does on its own (Auto Sell, Auto Deposit), its place in the order and what each bag set for it (pins,
-- tabs) stay with the player. Made alike for a category of yours to export and for one read from a pasted string,
-- whose fields may be anything; nil for one with no name.
---@param filter any
---@return CustomCategoryFilter?
local function sharedCategory(filter)
  if type(filter) ~= "table" or type(filter.name) ~= "string" or strtrim(filter.name) == "" then
    return nil
  end
  local shared = { name = strtrim(filter.name), itemList = itemSet(filter.itemList) or {} }
  shared.ignoredItems = itemSet(filter.ignoredItems)
  local query = type(filter.searchCategory) == "table" and filter.searchCategory.query
  if type(query) == "string" and strtrim(query) ~= "" then
    shared.searchCategory = { query = strtrim(query) }
  end
  for _, groupBy in pairs(const.SEARCH_CATEGORY_GROUP_BY) do
    if filter.groupBy == groupBy then
      shared.groupBy = groupBy
    end
  end
  shared.color = colorOf(filter.color)
  local enabled = {}
  for _, kind in ipairs(categoryKinds()) do
    if type(filter.enabled) == "table" and type(filter.enabled[kind]) == "boolean" then
      enabled[kind] = filter.enabled[kind]
    end
    if type(filter.hidden) == "table" and filter.hidden[kind] == true then
      shared.hidden = shared.hidden or {}
      shared.hidden[kind] = true
    end
  end
  shared.enabled = normalizeEnabled(enabled)
  if type(filter.note) == "string" and filter.note ~= "" then
    shared.note = filter.note
  end
  if filter.skipRecent == true then
    shared.skipRecent = true
  end
  shared.itemOrder = itemOrderOf(filter.itemOrder)
  return shared
end

-- Export category configuration: "!BB2!", then Serialization:Encode's Base64 (#1317). Before, "!BB" and a Lua table
-- constructor in Base64, which ReadImport still reads.
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

  return "!BB2!" .. serialization:Encode(exportData)
end

-- ExportCategory writes one category of yours to share (#1250): "!BB2!", then Serialization:Encode of
-- { version = 3, category = what it shares (sharedCategory) }. Nothing for a name that is not a category of yours.
---@param name string
---@return string?
function DB:ExportCategory(name)
  local filter = DB.data.profile.customCategoryFilters[name]
  if filter == nil then
    return nil
  end
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')
  return "!BB2!" .. serialization:Encode({ version = 3, category = sharedCategory(filter) })
end

-- ReadImport reads a string ExportSettings or ExportCategory wrote, of either format, as data, never run
-- (.claude/rules/import-export.md): your categories, which ApplyImport puts in place, or { version, category } with
-- only what a category shares (sharedCategory), which Categories:ImportCategory adds. It returns nil and why for a
-- string it cannot read.
---@param dataString string
---@return table?, string?
function DB:ReadImport(dataString)
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')

  if not dataString or dataString == "" then
    return nil, "Import data is empty"
  end

  -- Remove whitespace
  dataString = dataString:gsub("%s+", "")

  -- "!BB2!" first: "!BB" is a prefix of it, and an old string never holds "!" after "!BB" (Base64 has none).
  local importData, err
  if dataString:match("^!BB2!") then
    importData, err = serialization:Decode(dataString:sub(6))
  elseif dataString:match("^!BB") then
    importData, err = serialization:DecodeLegacy(dataString:sub(4))
  else
    return nil, "Invalid import string: Missing !BB prefix. Please make sure you copied the full export string."
  end
  if not importData then
    return nil, "Failed to read import data: " .. err
  end

  if type(importData.version) ~= "number" then
    return nil, "Invalid import data format"
  end
  if importData.category ~= nil then
    local category = sharedCategory(importData.category)
    if category == nil then
      return nil, "Invalid import data format"
    end
    return { version = importData.version, category = category }
  end
  return importData
end

-- ApplyImport puts the categories ReadImport read (a whole set) in place of yours, as they were exported, then brings
-- them to the current shape and rules.
---@param importData table
function DB:ApplyImport(importData)
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')
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
end

-- MigrateItemOrders gives every bag in every view, once, the keys the Item Order it saved as one of seven orders
-- (profile.itemSort, const.ITEM_SORT_TYPE) sorted by, then drops the old orders. An order at the old default (Quality)
-- was never saved (AceDB strips it at logout) and stays the default; an order already made of keys is kept.
function DB:MigrateItemOrders()
  local profile = DB.data.profile
  if profile.itemSort == nil then
    return
  end
  local KEY, TYPE = const.ITEM_ORDER_KEY, const.ITEM_SORT_TYPE
  local orderOf = {
    [TYPE.ALPHABETICALLY_THEN_QUALITY] = { KEY.NAME, KEY.QUALITY },
    [TYPE.QUALITY_THEN_ALPHABETICALLY] = { KEY.QUALITY },
    [TYPE.ITEM_LEVEL] = { KEY.ITEM_LEVEL },
    [TYPE.EXPANSION] = { KEY.EXPANSION },
    [TYPE.SELL_PRICE_STACK] = { KEY.SELL_PRICE_STACK },
    [TYPE.SELL_PRICE_EACH] = { KEY.SELL_PRICE_EACH },
    [TYPE.UPGRADE_TRACK] = { KEY.UPGRADE_TRACK, KEY.ITEM_LEVEL },
  }
  for kind, views in pairs(profile.itemSort) do
    for view, sortType in pairs(views) do
      local chosen = profile.itemOrder[kind] and profile.itemOrder[kind][view]
      if chosen == nil and orderOf[sortType] ~= nil then
        DB:SetItemOrder(kind, view, orderOf[sortType])
      end
    end
  end
  profile.itemSort = nil
end

-- SplitSectionOrder gives BetterBags Next, once, a Section Order a player chose when both designs shared one.
function DB:SplitSectionOrder()
  local profile = DB.data.profile
  if profile.nextSectionSortSplit then
    return
  end
  profile.nextSectionSortSplit = true
  for kind, views in pairs(profile.nextSectionSort) do
    for view in pairs(views) do
      local chosen = profile.sectionSort[kind] and profile.sectionSort[kind][view]
      if chosen ~= nil and chosen ~= const.SECTION_SORT_TYPE.ALPHABETICALLY then
        views[view] = chosen
      end
    end
  end
end

-- The Size tab's settings when one set sized every BetterBags Next bag (Appearance > Size): each old key, the bag's own it
-- became (nextSizeOptions), and its old default.
local SHARED_SIZE_OPTIONS = {
  nextIconScale = { "iconScale", 100 },
  nextBagScale = { "bagScale", 100 },
  nextFitNamesWhileOpen = { "fitNamesWhileOpen", false },
  nextAutosize = { "autosize", true },
}

-- SplitSizeOptions gives every BetterBags Next bag, the vendor too, the Size tab's settings a player chose when one set
-- sized them all. A setting at its old default was never saved (AceDB strips it at logout) and cannot be told from one
-- chosen: each bag keeps its own default (the vendor is not autosized). The old keys are dropped, so it runs once.
function DB:SplitSizeOptions()
  local profile = DB.data.profile
  for old, new in pairs(SHARED_SIZE_OPTIONS) do
    local chosen = profile[old]
    if chosen ~= nil and chosen ~= new[2] then
      for _, options in pairs(profile.nextSizeOptions) do
        options[new[1]] = chosen
      end
    end
    profile[old] = nil
  end
end

function DB:Migrate()

  --[[
    BetterBags Next's Section Order was the classic bags' until it took a default of its own. What a player
    chose carries over once; the old default cannot be told from a choice, and takes the new one.
  ]]--
  DB:SplitSectionOrder()

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

  --[[
    BetterBags Next's Size tab sized every bag at once until each bag had its own (2026-11-14). Last: the profile
    system's migration above may switch to another profile, whose old keys it splits.
    Do not remove before Q3'27.
  ]]--
  DB:SplitSizeOptions()

  --[[
    An Item Order was one of seven orders until an order was the keys it sorts by (issue #108, 2026-11-15). Last, as
    above: the profile system's migration may switch to another profile.
    Do not remove before Q3'27.
  ]]--
  DB:MigrateItemOrders()
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
  -- No old rules in it; rules written before the next load are current ones. No order to carry over either.
  DB:MigrateSearchRules(addon:GetModule('QueryParser').VERSION)
  DB.data.profile.nextSectionSortSplit = true
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
  -- The copy has the source's rules, in the version the source has, its order, split or not, its Size tab, one for
  -- every bag or one per bag, and its item orders, of keys or not.
  DB:MigrateSearchRules()
  DB:SplitSectionOrder()
  DB:SplitSizeOptions()
  DB:MigrateItemOrders()
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
  DB.data.profile.nextSectionSortSplit = true
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

-- How many dumps' equipment sets are kept (AddDebugEquipmentSets): the oldest go first.
DB.DEBUG_EQUIPMENT_SETS_KEPT = 50

-- AddDebugEquipmentSets keeps what a dump read of the character's equipment sets (frames/debug.lua), account wide, after
-- those of earlier dumps, so dumps across a relog, a set deleted and another character can be compared (issue #1333:
-- whether a set keeps its ID).
---@param entry table
function DB:AddDebugEquipmentSets(entry)
  local kept = DB.data.global.debugEquipmentSets
  table.insert(kept, entry)
  while #kept > DB.DEBUG_EQUIPMENT_SETS_KEPT do
    table.remove(kept, 1)
  end
end

---@return table[]
function DB:GetDebugEquipmentSets()
  return DB.data.global.debugEquipmentSets
end

function DB:ClearDebugEquipmentSets()
  DB.data.global.debugEquipmentSets = {}
end

DB:Enable()
