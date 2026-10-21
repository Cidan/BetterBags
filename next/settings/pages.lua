local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- NextSettingsPages is the list of BetterBags Next's settings pages (next-settings.md §3), in the order
-- they are defined: each page is in a group (the sidebar's headings, in the order their first page
-- was defined), has a title, a description and one or more tabs, and each tab sections of rows. A
-- row is a setting of the settings catalog (setting, bound to the page's bag), an option of the
-- page's own, text, buttons, or a block (a function making the row, with its searching words). A
-- page may be shown only sometimes (shown); a tab's sections may be a function, read each time it
-- is built. A page, a section or a row with a design ("next" or "classic") shows only while the bags
-- of that design are in use: the window shows what the bags in use read. Pages are data: the window
-- (NextSettings) makes their rows.
---@class NextSettingsPages: AceModule
---@field list NextSettingsPageDef[]
local pages = addon:NewModule('NextSettingsPages')

---@class (exact) NextSettingsRowDef
---@field setting? string A settings catalog id.
---@field option? NextSettingsOption
---@field text? string
---@field buttons? {text: string|fun(): string, style?: NextButtonStyle, onClick: fun(ctx: Context), tooltip?: string, disabled?: fun(): boolean}[] A button's text and disabled are read again with every refresh.
---@field block? fun(parent: Frame, owner: Frame): NextSettingsRow A row of the page's own making (wide).
---@field title? string A block's name, for search.
---@field keywords? string[] A block's searching words.
---@field design? BagDesign Shown only while these bags are in use.
---@field hidden? fun(): boolean Left out while it says so, checked at every layout (a plugin's hidden).

---@class (exact) NextSettingsSectionDef
---@field title string
---@field note? string
---@field design? BagDesign
---@field hidden? fun(): boolean Left out, rows and all, while it says so.
---@field titleHidden? fun(): boolean Its title left out while it says so, its rows kept (a plugin's hidden header).
---@field rows NextSettingsRowDef[]

---@class (exact) NextSettingsTabDef
---@field id string
---@field title string
---@field shown? fun(): boolean Left out of the tabs while it says so.
---@field sections NextSettingsSectionDef[]|fun(): NextSettingsSectionDef[]

-- A page's own list, shown in the sidebar in place of the pages while the page shows.
---@class NextSettingsSidebar
---@field frame Frame
---@field Place fun(self: NextSettingsSidebar, width: number, height: number)
---@field Refresh fun(self: NextSettingsSidebar, ctx: Context)

-- A page's buttons in the header, right of its title.
---@class NextSettingsActions
---@field frame Frame Sized by itself.
---@field Refresh fun(self: NextSettingsActions, ctx: Context)

---@class (exact) NextSettingsPageDef
---@field id string
---@field group string
---@field title string
---@field description string
---@field bag? SettingBag The bag its settings are bound to.
---@field shown? fun(): boolean
---@field design? BagDesign
---@field keywords? string[]
---@field sidebar? fun(parent: Frame, owner: Frame): NextSettingsSidebar Its own list (next-settings.md §5), made once.
---@field heading? fun(): string, string? Its title and description now, in place of title and description.
---@field actions? fun(parent: Frame, owner: Frame): NextSettingsActions Its buttons in the header, made once.
---@field tabs NextSettingsTabDef[]

pages.list = {}

-- Define adds a page after the others (or replaces the one with its id, in its place).
---@param def NextSettingsPageDef
function pages:Define(def)
  for i, page in ipairs(self.list) do
    if page.id == def.id then
      self.list[i] = def
      return
    end
  end
  table.insert(self.list, def)
end

-- Clear forgets every page (specs).
function pages:Clear()
  self.list = {}
end

---@param id string
---@return NextSettingsPageDef?
function pages:Get(id)
  for _, page in ipairs(self.list) do
    if page.id == id then
      return page
    end
  end
  return nil
end

-- DesignInUse returns the design of the bags in use: "next", else "classic".
---@return BagDesign
function pages:DesignInUse()
  return addon:GetModule('BagSystem'):ActiveDesign() == "next" and "next" or "classic"
end

-- InDesign says whether a page, section or row shows with the bags in use.
---@param thing {design?: BagDesign}
---@return boolean
function pages:InDesign(thing)
  return thing.design == nil or thing.design == self:DesignInUse()
end

-- IsShown says whether a page is shown now.
---@param page NextSettingsPageDef
---@return boolean
function pages:IsShown(page)
  return self:InDesign(page) and (page.shown == nil or page.shown() == true)
end

-- ShownTabs returns a page's tabs shown now, in order.
---@param page NextSettingsPageDef
---@return NextSettingsTabDef[]
function pages:ShownTabs(page)
  local list = {}
  for _, tab in ipairs(page.tabs) do
    if tab.shown == nil or tab.shown() == true then
      table.insert(list, tab)
    end
  end
  return list
end

-- List returns the pages shown now, in order.
---@return NextSettingsPageDef[]
function pages:List()
  local list = {}
  for _, page in ipairs(self.list) do
    if self:IsShown(page) then
      table.insert(list, page)
    end
  end
  return list
end

-- Sections returns a tab's sections, read now when they are a function.
---@param tab NextSettingsTabDef
---@return NextSettingsSectionDef[]
function pages:Sections(tab)
  if type(tab.sections) == "function" then
    return tab.sections()
  end
  return tab.sections
end
