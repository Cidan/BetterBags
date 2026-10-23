local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextDialog: AceModule
local nextDialog = addon:GetModule('NextDialog')

---@class NextSettingsRows: AceModule
local rows = addon:GetModule('NextSettingsRows')

---@class NextSettingsPages: AceModule
local pages = addon:GetModule('NextSettingsPages')

---@class NextSettings: AceModule
local settings = addon:GetModule('NextSettings')

---@class NextSettingsThemes: AceModule
local themes = addon:GetModule('NextSettingsThemes')

---@class NextSettingsCategories: AceModule
local categoryEditor = addon:GetModule('NextSettingsCategories')

---@class NextSettingsBagCategories: AceModule
local bagCategories = addon:GetModule('NextSettingsBagCategories')

---@class NextSettingsCurrency: AceModule
local currencyList = addon:GetModule('NextSettingsCurrency')

-- NextSettingsContent is what BetterBags Next's settings window shows (next-settings.md §4): its pages,
-- defined in Init in the order of the sidebar (General, Appearance, Item Colors; a page per bag;
-- Profiles; QuickFind), and a page per plugin (AddPlugin, from Config:AddPluginConfig). Settings of the
-- catalog are named by id; the rest (profiles, import and export, item level colors, a plugin's
-- AceConfig options) are options and blocks of this module, writing through the same database calls
-- as the classic window and asking in BetterBags Next's dialogs.
---@class NextSettingsContent: AceModule
---@field exportArea? NextSettingsRow
---@field importArea? NextSettingsRow
local content = addon:NewModule('NextSettingsContent')

-- The share of the highest level seen where the item level colors change (util/color.lua's levels).
local MID_SHARE, HIGH_SHARE = 0.61, 0.86

-- A profile's name is at most this long, as in the classic window.
local PROFILE_NAME_LETTERS = 48

-- owner returns the window dialogs show over.
---@return Frame
local function owner()
  return settings.frame
end

-- say shows a message with one button.
---@param title string
---@param text string
local function say(title, text)
  nextDialog:Show(owner(), { title = title, text = text, buttons = { { text = L:G("OK"), onClick = function() end } } })
end

-- ask shows a question: Cancel, and a button doing what was asked.
---@param title string
---@param text string
---@param yes string
---@param style NextButtonStyle
---@param onYes fun(ctx: Context)
local function ask(title, text, yes, style, onYes)
  nextDialog:Show(owner(), {
    title = title, text = text,
    buttons = { { text = L:G("Cancel"), onClick = function() end }, { text = yes, style = style, onClick = onYes } },
  })
end

-- offerReload asks to reload the UI now.
---@param title string
---@param text string
local function offerReload(title, text)
  nextDialog:Show(owner(), {
    title = title, text = text,
    buttons = {
      { text = L:G("Later"), onClick = function() end },
      { text = L:G("Reload"), style = "Primary", onClick = function() ReloadUI() end },
    },
  })
end

-- breakpoints returns the highest item level seen and where the mid and high colors start.
---@return number max, number mid, number high
local function breakpoints()
  local max = db:GetMaxItemLevel()
  return max, math.floor(max * MID_SHARE), math.floor(max * HIGH_SHARE)
end

-- colorOption is the option of an item level color, named with its range.
---@param key "low"|"mid"|"high"|"max"
---@param name fun(max: number, mid: number, high: number): string
---@return NextSettingsOption
local function colorOption(key, name)
  return {
    kind = "color",
    hasOpacity = true,
    title = function() return name(breakpoints()) end,
    description = L:G("The color of an item level in this range. The ranges follow the highest item level you have seen."),
    keywords = { "item level", "ilvl", "color" },
    get = function()
      local c = db:GetItemLevelColors()[key]
      return { c.red, c.green, c.blue, c.alpha }
    end,
    set = function(ctx, c)
      db:SetItemLevelColor(key, { red = c[1], green = c[2], blue = c[3], alpha = c[4] })
      events:SendMessage(ctx, 'itemLevel/MaxChanged', db:GetMaxItemLevel())
    end,
  }
end

-- profileCounts says how many characters use each profile in use.
---@return string
local function profileCounts()
  local parts = {}
  for name, count in pairs(db:GetProfileCharacterCounts()) do
    if count > 0 then
      table.insert(parts, format("%s: %d %s", name, count, count == 1 and L:G("character") or L:G("characters")))
    end
  end
  table.sort(parts)
  return L:G("Characters") .. ": " .. table.concat(parts, "  |  ")
end

-- askName asks for a profile name; onName gets it trimmed, and the dialog stays open for none.
---@param title string
---@param text string
---@param yes string
---@param start string
---@param onName fun(ctx: Context, name: string)
local function askName(title, text, yes, start, onName)
  nextDialog:Show(owner(), {
    title = title, text = text,
    input = { text = start, help = L:G("Profile name"), maxLetters = PROFILE_NAME_LETTERS },
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = yes, style = "Primary", onClick = function(ctx, typed)
        local name = strtrim(typed or "")
        if name == "" then
          return true
        end
        onName(ctx, name)
      end },
    },
  })
end

---@param ctx Context
local function newProfile(ctx)
  local _ = ctx
  askName(L:G("New Profile"), L:G("Name the new profile:"), L:G("Create"), "", function(_, name)
    local ok, message = db:CreateProfile(name)
    if not ok then
      say(L:G("New Profile"), message)
      return
    end
    ask(L:G("Profile Created"), format(L:G("Profile '%s' was created. Switch to it now? The UI reloads."), name),
      L:G("Switch"), "Primary", function()
        db:SwitchToProfile(name)
        ReloadUI()
      end)
  end)
end

---@param ctx Context
local function copyProfile(ctx)
  local _ = ctx
  local current = db:GetCurrentProfileName()
  askName(L:G("Copy Profile"), format(L:G("Copy '%s' to a new profile named:"), current), L:G("Copy"), "", function(_, name)
    local ok, message = db:CreateProfile(name)
    if ok then
      ok, message = db:CopyFromProfile(current)
    end
    if not ok then
      say(L:G("Copy Profile"), message)
      return
    end
    offerReload(L:G("Profile Copied"), format(L:G("'%s' was copied to '%s'. Reload the UI to use it."), current, name))
  end)
end

---@param ctx Context
local function renameProfile(ctx)
  local _ = ctx
  local current = db:GetCurrentProfileName()
  if current == "Default" then
    say(L:G("Rename Profile"), L:G("The Default profile cannot be renamed."))
    return
  end
  askName(L:G("Rename Profile"), format(L:G("Rename profile '%s' to:"), current), L:G("Rename"), current, function(_, name)
    if name == current then
      return
    end
    local ok, message = db:RenameProfile(current, name)
    if not ok then
      say(L:G("Rename Profile"), message)
      return
    end
    ReloadUI()
  end)
end

---@param ctx Context
local function deleteProfile(ctx)
  local _ = ctx
  local current = db:GetCurrentProfileName()
  if current == "Default" then
    say(L:G("Delete Profile"), L:G("The Default profile cannot be deleted."))
    return
  end
  ask(L:G("Delete Profile"),
    format(L:G("Delete profile '%s'? This cannot be undone. You will be switched to the Default profile, and the UI reloads."), current),
    L:G("Delete"), "Danger", function()
      db:SwitchToProfile("Default")
      db:DeleteProfile(current)
      ReloadUI()
    end)
end

---@param ctx Context
local function resetProfile(ctx)
  local _ = ctx
  ask(L:G("Reset Profile"),
    format(L:G("Reset profile '%s' to its defaults? All of its settings and categories are lost. This cannot be undone, and the UI reloads."),
      db:GetCurrentProfileName()),
    L:G("Reset"), "Danger", function()
      db:ResetCurrentProfile()
      ReloadUI()
    end)
end

---@param ctx Context
local function exportCategories(ctx)
  local _ = ctx
  local area = content.exportArea.area
  area:SetText(db:ExportSettings())
  area:SelectAll()
end

---@param ctx Context
local function importCategories(ctx)
  local _ = ctx
  local area = content.importArea.area
  local text = strtrim(area:GetText())
  if text == "" then
    say(L:G("Import Categories"), L:G("Paste a category configuration string to import first."))
    return
  end
  ask(L:G("Import Categories"), L:G("This replaces your categories with the ones imported. Continue?"), L:G("Import"),
    "Primary", function()
      local ok, message = db:ImportSettings(text)
      if not ok then
        say(L:G("Import Categories"), L:G("The categories could not be imported: ") .. tostring(message))
        return
      end
      area:SetText("")
      offerReload(L:G("Categories Imported"), L:G("Your categories were imported. Reload the UI to apply them?"))
    end)
end

-- The bag pages, in the sidebar's order: their ids and bags.
---@type {id: string, bag: SettingBag}[]
local BAG_PAGES = {}

-- bagPage defines a bag's page: its layout, items and categories, its settings bound to it.
---@param id string
---@param bag SettingBag
---@param shown? fun(): boolean
---@param design? BagDesign
local function bagPage(id, bag, shown, design)
  local name = string.lower(bag.name)
  table.insert(BAG_PAGES, { id = id, bag = bag })
  pages:Define({
    id = id, group = L:G("Bags"), title = L:G(bag.name), bag = bag, shown = shown, design = design,
    description = format(L:G("How the %s lays out, shows and sorts its items."), name),
    tabs = {
      { id = "layout", title = L:G("Layout"), sections = {
        { title = L:G("Order"), rows = { { setting = 'sectionOrder' }, { setting = 'itemOrder' } } },
        { title = L:G("Tabs"), rows = { { setting = 'enableGroups' } } },
        { title = L:G("Slots"), rows = { { setting = 'showAllFreeSpace' }, { setting = 'preserveGaps' } } },
        -- Only the classic bags read these (frames/bag.lua, frames/bagcanvas.lua, frames/section.lua).
        { title = L:G("Window"), design = "classic", rows = {
          { setting = 'resizableWindow' }, { setting = 'snapToContent' }, { setting = 'itemsPerRow' },
          { setting = 'columns' }, { setting = 'opacity' }, { setting = 'scale' },
        } },
        { title = L:G("Sections"), design = "classic", rows = { { setting = 'fullSectionNames' } } },
      } },
      { id = "items", title = L:G("Items"), sections = {
        { title = L:G("Item Level"), rows = { { setting = 'itemLevel' }, { setting = 'itemLevelColor' } } },
        { title = L:G("Quality"), rows = { { setting = 'glowIntensity' } } },
        { title = L:G("Stacking"), rows = {
          { setting = 'markRecentItems' }, { setting = 'newItemFlash' }, { setting = 'mergeStacks' },
          { setting = 'mergeUnstackable' }, { setting = 'dontMergePartial' }, { setting = 'dontMergeTransmog' },
          { setting = 'unmergeAtShop' },
        } },
      } },
      { id = "categories", title = L:G("Categories"), sections = {
        { title = L:G("Automatic"), note = L:G("(Blizzard's item categories)"), rows = {
          { setting = 'filterEquipmentLocation' }, { setting = 'filterExpansion' }, { setting = 'filterGearSet' },
          { setting = 'filterRecentItems' }, { setting = 'filterTradeSkill' }, { setting = 'filterType' },
          { setting = 'filterSubtype' },
        } },
        -- Categories are defined on the Categories page; a bag arranges them (category-lifecycle.md §6).
        { title = L:G("In This Bag"), note = L:G("(drag to reorder, Shift-click to pin)"), rows = { {
          title = L:G("Categories in This Bag"),
          keywords = { "category", "categories", "pinned", "pin", "order", "used", "custom" },
          block = function(parent, window) return bagCategories:Create(parent, window, bag) end,
        } } },
      } },
    },
  })
end

-- shownBags returns the bags whose pages the settings show (the guild bank's only with BetterBags Next,
-- on a client with one): the bags a category can be used in.
---@return SettingBag[]
local function shownBags()
  local list = {}
  for _, entry in ipairs(BAG_PAGES) do
    local page = pages:Get(entry.id)
    if page and pages:IsShown(page) then
      table.insert(list, entry.bag)
    end
  end
  return list
end

-- tabSection is a tab of the Categories page: one block filling it, its section's title hidden (the
-- tab's name says it), found by its name and searching words.
---@param title string
---@param keywords string[]
---@param block fun(parent: Frame, owner: Frame): NextSettingsRow
---@return NextSettingsSectionDef
local function tabSection(title, keywords, block)
  return {
    title = title, titleHidden = function() return true end,
    rows = { { title = title, keywords = keywords, block = block } },
  }
end

-- Init defines the pages, in the sidebar's order.
function content:Init()
  self.exportArea, self.importArea = nil, nil
  BAG_PAGES = {}
  categoryEditor:Init()
  pages:Define({
    id = "general", group = L:G("BetterBags"), title = L:G("General"),
    description = L:G("How BetterBags works in every bag."),
    tabs = { { id = "main", title = L:G("General"), sections = {
      { title = L:G("Bags"), rows = {
        { setting = 'nextEnabled' }, { setting = 'enableBankBags' }, { setting = 'showBagButton' },
        { setting = 'bagFading', design = "classic" }, { setting = 'animateItemMovement', design = "classic" },
      } },
      -- Only the classic bags' search box makes a category on Enter (frames/search.lua).
      { title = L:G("Search"), rows = { { setting = 'inBagSearch' }, { setting = 'enterToMakeCategory', design = "classic" } } },
      { title = L:G("Items"), rows = { { setting = 'upgradeProvider' }, { setting = 'newItemDuration' }, { setting = 'categorySell' } } },
      { title = L:G("What's New"), rows = { { setting = 'changelogOnLogin' } } },
    } } },
  })
  pages:Define({
    id = "appearance", group = L:G("BetterBags"), title = L:G("Appearance"),
    description = L:G("How BetterBags looks. A theme you pick shows at once; Apply Theme keeps it."),
    -- BetterBags Next's themes draw its bags and this window; the classic bags' themes draw theirs.
    tabs = { { id = "main", title = L:G("Appearance"), sections = {
      { title = L:G("Theme"), design = "next", rows = { {
        title = L:G("Theme"), keywords = { "theme", "look", "skin", "appearance", "style" },
        block = function(parent) return themes:Create(parent, sonataNext) end,
      } } },
      { title = L:G("Bag Theme"), design = "classic", rows = { {
        title = L:G("Bag Theme"), keywords = { "theme", "look", "skin", "appearance", "style", "bags" },
        block = function(parent) return themes:Create(parent, sonata) end,
      } } },
      { title = L:G("Settings Window"), design = "classic", note = L:G("(BetterBags Next's themes draw this window)"),
        rows = { {
          title = L:G("Settings Window Theme"), keywords = { "theme", "settings", "window" },
          block = function(parent) return themes:Create(parent, sonataNext) end,
        } } },
    } } },
  })
  pages:Define({
    id = "itemcolors", group = L:G("BetterBags"), title = L:G("Item Colors"),
    description = L:G("The colors of item levels, scaled to the highest item level you have seen."),
    tabs = { { id = "main", title = L:G("Item Colors"), sections = {
      { title = L:G("Colors"), rows = {
        { option = colorOption("low", function(_, mid) return format(L:G("Low Item Level Color (1-%d)"), mid - 1) end) },
        { option = colorOption("mid", function(_, mid, high)
          return format(L:G("Mid Item Level Color (%d-%d)"), mid, high - 1)
        end) },
        { option = colorOption("high", function(max, _, high)
          return format(L:G("High Item Level Color (%d-%d)"), high, max - 1)
        end) },
        { option = colorOption("max", function(max) return format(L:G("Max Item Level Color (%d+)"), max) end) },
        { text = function()
          local max = breakpoints()
          return format(L:G("The highest item level you have seen is %d. The ranges move up as you get better gear."), max)
        end },
        { buttons = {
          { text = L:G("Reset Colors"), onClick = function(ctx)
            db:ResetItemLevelColors()
            events:SendMessage(ctx, 'itemLevel/MaxChanged', db:GetMaxItemLevel())
            settings:Refresh(ctx)
          end },
          { text = L:G("Reset Max Item Level"), onClick = function(ctx)
            db:ResetMaxItemLevel()
            settings:Refresh(ctx)
          end },
        } },
      } },
    } } },
  })
  -- Every category, defined once (category-lifecycle.md §6), for both designs.
  pages:Define({
    id = "categories", group = L:G("BetterBags"), title = L:G("Categories"),
    description = L:G("Your categories: a rule, items you add, or both. Each bag uses those you choose."),
    -- Its own list in the sidebar, the chosen category's name and buttons in the header (next-settings.md §5).
    sidebar = function(parent, window) return categoryEditor:CreateList(parent, window) end,
    heading = function() return categoryEditor:Heading() end,
    actions = function(parent, window) return categoryEditor:CreateActions(parent, window) end,
    tabs = {
      { id = "settings", title = L:G("Settings"), sections = { tabSection(L:G("Category Settings"),
        { "category", "categories", "custom", "priority", "color", "group by", "bags", "used in" },
        function(parent, window) return categoryEditor:CreateSettingsTab(parent, window, shownBags) end) } },
      { id = "rule", title = L:G("Search Rule"), shown = function() return categoryEditor:RuleTabShown() end,
        sections = { tabSection(L:G("Search Rule"), { "rule", "search rule", "search category", "search", "query" },
          function(parent, window) return categoryEditor:CreateRuleTab(parent, window, shownBags) end) } },
      { id = "items", title = L:G("Added Items"), shown = function() return categoryEditor:ItemsTabShown() end,
        sections = { tabSection(L:G("Added Items"), { "items", "added", "manual", "drag" },
          function(parent, window) return categoryEditor:CreateItemsTab(parent, window, shownBags) end) } },
      -- What the category does on its own (automation.md).
      { id = "automation", title = L:G("Automation"), shown = function() return categoryEditor:AutomationTabShown() end,
        sections = { tabSection(L:G("Automation"), { "automation", "sell", "vendor", "merchant", "destroy", "junk" },
          function(parent, window) return categoryEditor:CreateAutomationTab(parent, window, shownBags) end) } },
    },
  })
  -- The classic bags' currency icons (frames/currency.lua), on clients with currencies: retail, WoW:
  -- Forever and Mists Classic (TBC and Era have none: the classic window said so there).
  pages:Define({
    id = "currency", group = L:G("BetterBags"), title = L:G("Currency"), design = "classic",
    shown = function() return addon.isRetail == true or addon.isMists == true end,
    description = L:G("The currencies shown at the bottom of your backpack."),
    tabs = { { id = "main", title = L:G("Currency"), sections = {
      { title = L:G("Currencies"), note = L:G("(the backpack shows up to 7)"), rows = { {
        title = L:G("Currency"), keywords = { "currency", "currencies", "tokens", "backpack" },
        block = function(parent) return currencyList:Create(parent) end,
      } } },
    } } },
  })
  bagPage("backpack", { name = 'Backpack', kind = const.BAG_KIND.BACKPACK })
  bagPage("bank", { name = 'Bank', kind = const.BAG_KIND.BANK })
  -- BetterBags Next's guild bank (guild-bank.md §5), on a client with one; the classic bags have none.
  bagPage("guild", { name = 'Guild Bank', kind = const.BAG_KIND.GUILD }, function() return addon.hasGuildBank == true end,
    "next")
  pages:Define({
    id = "profiles", group = L:G("Profiles"), title = L:G("Profiles"),
    description = L:G("Your settings, saved under a name and shared by the characters that use it."),
    tabs = {
      { id = "profiles", title = L:G("Profiles"), sections = {
        { title = L:G("Active Profile"), rows = {
          { option = {
            kind = "dropdown", title = L:G("Active Profile"),
            description = L:G("The profile this character uses. Switching reloads the UI."),
            keywords = { "profile", "switch" },
            itemsFunction = function() return db:GetAvailableProfiles() end,
            get = function() return db:GetCurrentProfileName() end,
            set = function(_, name)
              ask(L:G("Switch Profile"), format(L:G("Switch to profile '%s'? The UI reloads."), name), L:G("Switch"),
                "Primary", function()
                  db:SwitchToProfile(name)
                  ReloadUI()
                end)
            end,
          } },
          { text = profileCounts },
        } },
        { title = L:G("Manage"), rows = { { buttons = {
          { text = L:G("New Profile"), onClick = newProfile },
          { text = L:G("Copy Profile"), onClick = copyProfile },
          { text = L:G("Rename Profile"), onClick = renameProfile },
          { text = L:G("Delete Profile"), style = "Danger", onClick = deleteProfile },
          { text = L:G("Reset to Defaults"), style = "Danger", onClick = resetProfile },
        } } } },
      } },
      { id = "transfer", title = L:G("Import / Export"), sections = {
        { title = L:G("Export"), rows = {
          { text = L:G("Export your categories to a string you can share. Only categories are included, no other settings.") },
          { buttons = { { text = L:G("Export Categories"), style = "Primary", onClick = exportCategories } } },
          { title = L:G("Export Categories"), keywords = { "export", "share" }, block = function(parent)
            self.exportArea = rows:CreateArea(parent, { height = 120, help = L:G("Export your categories, then copy them with Ctrl+C.") })
            return self.exportArea
          end },
        } },
        { title = L:G("Import"), rows = {
          { text = L:G("Paste a category configuration string and import it. It replaces your categories.") },
          { title = L:G("Import Categories"), keywords = { "import", "share" }, block = function(parent)
            self.importArea = rows:CreateArea(parent, { height = 120, help = L:G("Paste a string here with Ctrl+V.") })
            return self.importArea
          end },
          { buttons = { { text = L:G("Import Categories"), style = "Primary", onClick = importCategories } } },
        } },
      } },
    },
  })
  pages:Define({
    id = "quickfind", group = L:G("Integrations"), title = L:G("QuickFind"),
    description = L:G("Your items, searchable from the QuickFind addon."),
    tabs = { { id = "main", title = L:G("QuickFind"), sections = {
      { title = L:G("How it works"), rows = {
        { text = L:G("BetterBags integrates with the QuickFind addon to make your items searchable.") },
        { text = L:G("All items in your backpack and bank are registered as a QuickFind source, tagged with their type, category and location.") },
        { text = L:G("When you press Enter on an item in QuickFind, BetterBags opens the bag it is in, switches to the tab that holds it, and searches for its name.") },
      } },
    } } },
  })
end

-- OnEnable names the item level colors' ranges again when the highest item level seen changes while
-- they show.
function content:OnEnable()
  events:RegisterMessage('itemLevel/MaxChanged', function(ctx)
    if settings:IsShown() and settings.pageId == "itemcolors" and settings.query == nil then
      settings:Refresh(ctx)
    end
  end)
end

-- What a plugin's AceConfig options are read with (AceConfigDialog-3.0's rules): these members are
-- inherited from the groups above an option; a string is a method of the handler except for these.
local INHERITED = { set = true, get = true, func = true, confirm = true, validate = true, disabled = true, hidden = true }
local STRING_LITERAL = { name = true, desc = true, icon = true, usage = true, width = true, image = true,
  fontSize = true, tooltipHyperlink = true }

-- A plugin option where it is: the groups down to it (the root first, the option last), the keys of
-- the way, its handler (the last a group or the option names), and the plugin.
---@class (exact) NextPluginOption
---@field option table
---@field chain table[]
---@field path string[]
---@field handler? table
---@field root table
---@field appName string

---@param o NextPluginOption
---@return table
local function infoOf(o)
  local info = {
    options = o.root, appName = o.appName, [0] = o.appName, arg = o.option.arg, handler = o.handler,
    option = o.option, type = o.option.type, uiType = "dialog", uiName = "BetterBags",
  }
  for i, key in ipairs(o.path) do
    info[i] = key
  end
  return info
end

-- member returns an option's member, an inherited one from the nearest group that has it.
---@param o NextPluginOption
---@param name string
---@return any
local function member(o, name)
  if not INHERITED[name] then
    return o.option[name]
  end
  local found
  for _, group in ipairs(o.chain) do
    if group[name] ~= nil then
      found = group[name]
    end
  end
  return found
end

-- callMember calls a member: a function with the info, or the handler's method it names.
---@param o NextPluginOption
---@param name string
---@param m function|string
---@return any ...
local function callMember(o, name, m, ...)
  if type(m) == "function" then
    return m(infoOf(o), ...)
  end
  local handler = o.handler
  if handler == nil or handler[m] == nil then
    error(format("Method %s doesn't exist in handler for type %s", tostring(m), name))
  end
  return handler[m](handler, infoOf(o), ...)
end

-- value returns a member's value: called when it is a function or a method's name, else as it is.
---@param o NextPluginOption
---@param name string
---@return any ...
local function value(o, name, ...)
  local m = member(o, name)
  if type(m) == "function" or (type(m) == "string" and not STRING_LITERAL[name]) then
    return callMember(o, name, m, ...)
  end
  return m
end

-- optionAt is the child of a group at key.
---@param parent NextPluginOption
---@param key string
---@param option table
---@return NextPluginOption
local function optionAt(parent, key, option)
  local chain, path = {}, {}
  for i, g in ipairs(parent.chain) do chain[i] = g end
  for i, k in ipairs(parent.path) do path[i] = k end
  table.insert(chain, option)
  table.insert(path, key)
  return {
    option = option, chain = chain, path = path, handler = option.handler or parent.handler,
    root = parent.root, appName = parent.appName,
  }
end

-- sortedChildren lists a group's options in AceConfigDialog's order: by order (100 when unset, the
-- negative ones last), then by name.
---@param group NextPluginOption
---@return NextPluginOption[]
local function sortedChildren(group)
  local list = {}
  for key, option in pairs(group.option.args or {}) do
    local o = optionAt(group, key, option)
    local order = value(o, "order")
    local name = value(o, "name")
    table.insert(list, { o = o, order = type(order) == "number" and order or 100, name = type(name) == "string" and name or "" })
  end
  table.sort(list, function(a, b)
    if a.order == b.order then
      return a.name:upper() < b.name:upper()
    end
    if (a.order < 0) ~= (b.order < 0) then
      return b.order < 0
    end
    return a.order < b.order
  end)
  local sorted = {}
  for i, entry in ipairs(list) do
    sorted[i] = entry.o
  end
  return sorted
end

-- write applies a change the way AceConfigDialog does: an input's pattern and validate (false or a
-- message refuses it, said in a dialog), confirm (asked in a dialog), then set, or func for an execute,
-- and the page shows every value again. It returns false when the change did not happen now.
---@param o NextPluginOption
---@param ctx Context
---@return boolean
local function write(o, ctx, ...)
  local option = o.option
  local name = value(o, "name") or ""
  local validated = true
  if option.type == "input" and type(option.pattern) == "string" and not string.match((...) or "", option.pattern) then
    validated = false
  end
  local validate = member(o, "validate")
  if validated and option.type ~= "execute" and validate ~= nil then
    local ok, result = pcall(callMember, o, "validate", validate, ...)
    validated = ok and result
  end
  if not validated or type(validated) == "string" then
    local message = validated
    if not validated then
      if option.usage then
        message = name .. ": " .. option.usage
      elseif option.pattern then
        message = name .. ": Expected " .. option.pattern
      else
        message = name .. ": Invalid Value"
      end
    end
    say(name, message)
    return false
  end
  local confirm, confirmText = member(o, "confirm"), option.confirmText
  if type(confirm) == "function" or type(confirm) == "string" then
    local ok, result = pcall(callMember, o, "confirm", confirm, ...)
    if ok and type(result) == "string" then
      confirm, confirmText = true, result
    elseif not ok then
      confirm = false
    else
      confirm = result
    end
  end
  local funcName = option.type == "execute" and "func" or "set"
  local func = member(o, funcName)
  local args = { n = select("#", ...), ... }
  local function run(rctx)
    if type(func) == "function" or type(func) == "string" then
      local ok, err = pcall(callMember, o, funcName, func, unpack(args, 1, args.n))
      if not ok then
        geterrorhandler()(err)
      end
    end
    settings:Refresh(rctx)
  end
  if confirm == true then
    if not confirmText then
      local desc = value(o, "desc")
      confirmText = desc and (name .. " - " .. desc) or name
    end
    ask(name, confirmText, L:G("Accept"), "Primary", run)
    return false
  end
  run(ctx)
  return true
end

-- optionOf is the settings option of a plugin option of a kind.
---@param o NextPluginOption
---@param kind string
---@return NextSettingsOption
local function optionOf(o, kind)
  return {
    kind = kind,
    title = function() return value(o, "name") or "" end,
    description = function() return value(o, "desc") end,
    disabled = function() return value(o, "disabled") and true or false end,
    get = function() return value(o, "get") end,
    set = function(ctx, v) return write(o, ctx, v) end,
  }
end

-- valueNames returns a select's values (key to name) and its names in AceConfigDialog's order: its
-- sorting, else its keys sorted as strings.
---@param o NextPluginOption
---@return table<any, string> values, string[] names
local function valueNames(o)
  local values = value(o, "values") or {}
  local keys = value(o, "sorting")
  if keys == nil then
    keys = {}
    for key in pairs(values) do
      table.insert(keys, key)
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  end
  local names = {}
  for _, key in ipairs(keys) do
    if values[key] ~= nil then
      table.insert(names, tostring(values[key]))
    end
  end
  return values, names
end

-- rowsOf returns the row definitions of a plugin option.
---@param o NextPluginOption
---@return NextSettingsRowDef[]
local function rowsOf(o)
  local option, kind = o.option, o.option.type
  if kind == "toggle" then
    local opt = optionOf(o, "toggle")
    opt.get = function() return value(o, "get") and true or false end
    return { { option = opt } }
  elseif kind == "select" then
    local opt = optionOf(o, "dropdown")
    opt.itemsFunction = function()
      local _, names = valueNames(o)
      return names
    end
    opt.get = function()
      local values = valueNames(o)
      local current = values[value(o, "get")]
      return current ~= nil and tostring(current) or nil
    end
    opt.set = function(ctx, name)
      for key, text in pairs((valueNames(o))) do
        if tostring(text) == name then
          return write(o, ctx, key)
        end
      end
      return false
    end
    return { { option = opt } }
  elseif kind == "multiselect" then
    local list = {}
    local values, names = valueNames(o)
    for _, name in ipairs(names) do
      local key
      for k, text in pairs(values) do
        if tostring(text) == name then key = k end
      end
      local opt = optionOf(o, "toggle")
      opt.title = function() return (value(o, "name") or "") .. ": " .. name end
      opt.get = function() return value(o, "get", key) and true or false end
      opt.set = function(ctx, v) return write(o, ctx, key, v) end
      table.insert(list, { option = opt })
    end
    return list
  elseif kind == "range" then
    local opt = optionOf(o, "slider")
    local min, max = option.softMin or option.min or 0, option.softMax or option.max or 100
    local step = option.bigStep or option.step
    if step == nil or step <= 0 then
      step = max > min and (max - min) / 100 or 1
    end
    opt.min, opt.max, opt.step = min, max, step
    opt.get = function()
      local v = value(o, "get")
      return type(v) == "number" and v or 0
    end
    return { { option = opt } }
  elseif kind == "input" and option.multiline then
    local area
    return {
      { title = value(o, "name"), block = function(parent)
        area = rows:CreateArea(parent, { height = type(option.multiline) == "number" and option.multiline * 14 or 120 },
          function() return tostring(value(o, "get") or "") end)
        return area
      end },
      { buttons = { { text = L:G("Accept"), style = "Primary",
        disabled = function() return value(o, "disabled") and true or false end,
        onClick = function(ctx) write(o, ctx, area.area:GetText()) end,
      } } },
    }
  elseif kind == "input" then
    local opt = optionOf(o, "input")
    opt.get = function() return tostring(value(o, "get") or "") end
    return { { option = opt } }
  elseif kind == "color" then
    local opt = optionOf(o, "color")
    opt.hasOpacity = value(o, "hasAlpha") and true or false
    opt.get = function()
      local r, g, b, a = value(o, "get")
      return { r or 1, g or 1, b or 1, a or 1 }
    end
    opt.set = function(ctx, c) return write(o, ctx, c[1], c[2], c[3], c[4]) end
    return { { option = opt } }
  elseif kind == "execute" then
    return { { buttons = { {
      text = function() return value(o, "name") or "" end, tooltip = value(o, "desc"),
      disabled = function() return value(o, "disabled") and true or false end,
      onClick = function(ctx) write(o, ctx) end,
    } } } }
  elseif kind == "description" then
    return { { text = function() return value(o, "name") or "" end } }
  end
  debug:Log("PluginConfig", "Unsupported option type for plugin config: ", kind)
  return {}
end

-- pluginSections makes a plugin's sections: its own options under its title, each group's under the
-- group's name, a header starting a section of its own. What a plugin hides (hidden: its own, or a
-- group's it is in, whatever it says of itself, as AceConfigDialog never shows a hidden group's
-- options) is left out while it is hidden, read again at every layout as AceConfigDialog reads it
-- after every change. A hidden header is a line left out: the options after it stay.
---@param title string
---@param options table An AceConfig group, or the args of one (Config:AddPluginConfig's).
---@return NextSettingsSectionDef[]
local function pluginSections(title, options)
  local root = options
  if options.type ~= "group" or type(options.args) ~= "table" then
    root = { type = "group", args = options }
  end
  ---@type NextPluginOption
  local top = { option = root, chain = { root }, path = {}, handler = root.handler, root = root, appName = title }
  local sections = {}
  -- walk adds a group's sections; groupHidden says whether the group (or one it is in) is hidden now.
  local function walk(group, sectionTitle, groupHidden)
    local current = { title = sectionTitle, rows = {}, hidden = groupHidden }
    table.insert(sections, current)
    for _, o in ipairs(sortedChildren(group)) do
      local function hidden()
        return groupHidden() or value(o, "hidden") and true or false
      end
      local kind = o.option.type
      if kind == "group" then
        walk(o, value(o, "name") or o.path[#o.path], hidden)
        current = { title = sectionTitle, rows = {}, hidden = groupHidden }
        table.insert(sections, current)
      elseif kind == "header" then
        current = { title = value(o, "name") or "", rows = {}, hidden = groupHidden, titleHidden = hidden }
        table.insert(sections, current)
      else
        for _, def in ipairs(rowsOf(o)) do
          def.hidden = hidden
          table.insert(current.rows, def)
        end
      end
    end
  end
  walk(top, title, function() return false end)
  local kept = {}
  for _, section in ipairs(sections) do
    if #section.rows > 0 then
      table.insert(kept, section)
    end
  end
  return kept
end

-- AddPlugin adds a plugin's page under Integrations, made from its AceConfig options.
---@param title string
---@param options table
function content:AddPlugin(title, options)
  pages:Define({
    id = "plugin:" .. title, group = L:G("Integrations"), title = title,
    description = format(L:G("Settings added by the %s plugin."), title),
    tabs = { { id = "main", title = title, sections = pluginSections(title, options) } },
  })
end
