local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- NextSettingsPages is the list of BetterBags Next's settings pages (next-settings.md §3), in the order
-- they are defined: each page is in a group (the sidebar's headings, in the order their first page
-- was defined), has a title, a description and one or more tabs, and each tab sections of rows. A
-- row is a setting of the settings catalog (setting, bound to the page's bag), an option of the
-- page's own, text, buttons, or a block (a function making the row, with its searching words). A
-- page may be shown only sometimes (shown); a tab's sections may be a function, read each time it
-- is built. Pages are data: the window (NextSettings) makes their rows.
---@class NextSettingsPages: AceModule
---@field list NextSettingsPageDef[]
local pages = addon:NewModule('NextSettingsPages')

---@class (exact) NextSettingsRowDef
---@field setting? string A settings catalog id.
---@field option? NextSettingsOption
---@field text? string
---@field buttons? {text: string, style?: NextButtonStyle, onClick: fun(ctx: Context), tooltip?: string}[]
---@field block? fun(parent: Frame, owner: Frame): NextSettingsRow A row of the page's own making (wide).
---@field title? string A block's name, for search.
---@field keywords? string[] A block's searching words.

---@class (exact) NextSettingsSectionDef
---@field title string
---@field note? string
---@field rows NextSettingsRowDef[]

---@class (exact) NextSettingsTabDef
---@field id string
---@field title string
---@field sections NextSettingsSectionDef[]|fun(): NextSettingsSectionDef[]

---@class (exact) NextSettingsPageDef
---@field id string
---@field group string
---@field title string
---@field description string
---@field bag? SettingBag The bag its settings are bound to.
---@field shown? fun(): boolean
---@field keywords? string[]
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

-- IsShown says whether a page is shown now.
---@param page NextSettingsPageDef
---@return boolean
function pages:IsShown(page)
  return page.shown == nil or page.shown() == true
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
