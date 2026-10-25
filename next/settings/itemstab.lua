local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

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

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextSettingsItemsTab is a settings tab of items the player lists by dropping them on it (next-settings.md §5): the
-- Categories page's Added Items and Ignored Items, and the Currencies page's Tracked Items (currency.md §6). One look
-- for one action (CLAUDE.md, "UI Consistency"): the count, a filter by name and Remove All on top, a line of help,
-- and the items in a grid that holds thousands (NextItemGrid); an item dropped anywhere on the grid is added, a right
-- click offers Remove, Remove All asks first. What it lists and what each action does is its source's. It also holds
-- the frame helpers the settings pages' tabs share (each a wide row filling the page's content, no scrolling).
---@class NextSettingsItemsTab: AceModule
---@field all NextItemsTab[]
local itemsTab = addon:NewModule('NextSettingsItemsTab')

-- NextItemsSource says what an items tab lists and what its actions do.
---@class (exact) NextItemsSource
---@field key fun(): string? What the tab shows now (a category's name); nothing, and it shows nothing.
---@field list fun(key: string): table<number, boolean> The items listed, by item ID.
---@field readOnly? fun(key: string): boolean Shown, not changed (a plugin's added items).
---@field help fun(key: string, readOnly: boolean): string The line under the top row.
---@field words fun(): string, string How it counts its items: one, many ("%d added item", "%d added items").
---@field empty string The grid's text while it lists nothing.
---@field readOnlyEmpty? string The read-only grid's.
---@field notes? fun(key: string, list: table<number, boolean>): table<number, { dim: boolean, note?: string, count?: number }>
---@field add fun(ctx: Context, key: string, itemID: number): boolean Adds a dropped item; false leaves it on the cursor.
---@field remove fun(ctx: Context, key: string, itemID: number)
---@field clear fun(ctx: Context, key: string)
---@field clearText fun(key: string, counted: string): string What Remove All asks.
---@field messages? string[] Messages that change what it lists, besides the bags being read: it shows again on each.

---@class NextItemsTab
---@field frame Frame
---@field wide boolean
---@field owner Frame
---@field source NextItemsSource
---@field loading table<string, boolean> The keys whose item names are loading.
---@field count FontString
---@field filter NextInputFrame
---@field removeAll NextButtonFrame
---@field help FontString
---@field grid NextItemGridFrame
---@field readOnly NextItemGridFrame
---@field x? number
---@field y? number
---@field width? number
---@field height? number
local tabProto = {}
addon:GetModule('Perf'):RegisterPrototype(tabProto, 'NextItemsTab')

-- The messages a bag kind's committed sweep sends (data/items.lua Phase11): what the bags hold changed.
itemsTab.READ = { 'items/RefreshBackpack/Done', 'items/RefreshBank/Done', 'items/RefreshGuildBank/Done' }

itemsTab.all = {}

---@param ctx? Context
function itemsTab:ApplyStyle(ctx)
  local _ = ctx
  for _, tab in ipairs(self.all) do
    tab:Style()
  end
end

---@param n number
---@param one string
---@param many string
---@return string
function itemsTab.Count(n, one, many)
  return format(n == 1 and one or many, n)
end

-- ByName orders grid entries by name (those not known yet after, by item ID).
---@param a table
---@param b table
---@return boolean
function itemsTab.ByName(a, b)
  if (a.name == nil) ~= (b.name == nil) then
    return a.name ~= nil
  end
  if a.name ~= nil and a.name ~= b.name then
    return a.name:lower() < b.name:lower()
  end
  return a.itemID < b.itemID
end

-- TabHeight returns the height a tab's row fills: the content's, less the page's own room above and below its
-- section (the section's title is hidden).
---@param frame Frame The tab's, on the window's grid.
---@return number
function itemsTab:TabHeight(frame)
  local C = style.Theme.Settings.Content
  return math.max(1, settings:ContentHeight() - pixel:Snap(frame, C.Top) - pixel:Snap(frame, C.Bottom))
end

-- Metrics returns a tab's lengths in whole pixels on its grid (docs/next-pixel-perfect.md): its padding, the gap
-- between fields, a field row's height (a button's), a label's width.
---@param frame Frame
---@return {pad: number, gap: number, row: number, labelWidth: number}
function itemsTab:Metrics(frame)
  local K = style.Theme.Settings.Categories
  return { pad = pixel:Snap(frame, K.Pad), gap = pixel:Snap(frame, K.FieldGap),
    row = pixel:Length(frame, controls:Theme("Button").Height), labelWidth = pixel:Snap(frame, K.LabelWidth) }
end

-- PlaceTab anchors a tab's frame where the page put it.
---@param tab table
---@param x number
---@param y number
---@param width number
---@param height number
function itemsTab:PlaceTab(tab, x, y, width, height)
  local frame = tab.frame
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  pixel:Size(frame, width, height)
  tab.x, tab.y, tab.width, tab.height = x, y, frame:GetWidth(), frame:GetHeight()
  frame:Show()
end

-- Create makes an items tab of a source.
---@param parent Frame
---@param owner Frame The window its dialogs and menus show over.
---@param source NextItemsSource
---@return NextItemsTab
function itemsTab:Create(parent, owner, source)
  local frame = CreateFrame("Frame", nil, parent)
  local tab = setmetatable({ frame = frame, wide = true, owner = owner, source = source, loading = {} },
    { __index = tabProto })
  ---@cast tab NextItemsTab
  local messages = {}
  for _, message in ipairs(itemsTab.READ) do
    table.insert(messages, message)
  end
  for _, message in ipairs(source.messages or {}) do
    table.insert(messages, message)
  end
  for _, message in ipairs(messages) do
    events:RegisterMessage(message, function(ctx)
      if frame:IsVisible() then
        tab:Refresh(ctx)
      end
    end)
  end
  local K = style.Theme.Settings.Categories
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
    empty = source.empty,
  })
  tab.readOnly = nextItemGrid:Create(frame, { empty = source.readOnlyEmpty or source.empty })
  table.insert(self.all, tab)
  sonataNext:RegisterWidget(self)
  tab:Style()
  return tab
end

function tabProto:Style()
  local K = style.Theme.Settings.Categories
  style:SetFont(self.count, K.SectionFont)
  style:SetFont(self.help, K.HintFont)
  if self.width then
    self:layout()
  end
end

---@param width number
---@return number
function tabProto:Measure(width)
  local _ = width
  return itemsTab:TabHeight(self.frame)
end

---@param x number
---@param y number
---@param width number
---@param height number
function tabProto:Place(x, y, width, height)
  itemsTab:PlaceTab(self, x, y, width, height)
  self:layout()
end

-- isReadOnly says whether the tab only shows what it lists now.
---@private
---@param key string
---@return boolean
function tabProto:isReadOnly(key)
  return self.source.readOnly ~= nil and self.source.readOnly(key) == true
end

-- Refresh shows the source's list, to add to and remove from, or read-only.
---@param ctx? Context
function tabProto:Refresh(ctx)
  local _ = ctx
  local key = self.source.key()
  if key == nil then
    return
  end
  local readOnly = self:isReadOnly(key)
  self.grid.frame:SetShown(not readOnly)
  self.readOnly.frame:SetShown(readOnly)
  self.removeAll.frame:SetShown(not readOnly)
  self.help:SetText(self.source.help(key, readOnly))
  self:ShowItems()
  if self.width then
    self:layout()
  end
end

-- ShowItems lists the source's items, by name, those whose name has the filter's text, each with what the source
-- notes of it. Names not loaded yet are asked for, and the list is shown again once they arrive.
function tabProto:ShowItems()
  local key = self.source.key()
  if key == nil then
    return
  end
  local list = self.source.list(key)
  local notes = self.source.notes and self.source.notes(key, list) or {}
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
      local note = notes[itemID]
      table.insert(shown, {
        id = itemID, itemID = itemID, icon = icon, quality = C_Item.GetItemQualityByID(itemID), name = itemName,
        dim = note ~= nil and note.dim or false, note = note and note.note, count = note and note.count,
      })
    end
  end
  table.sort(shown, itemsTab.ByName)
  local one, many = self.source.words()
  if needle == "" then
    self.count:SetText(itemsTab.Count(all, one, many))
  else
    self.count:SetText(format(L:G("%d of %s"), #shown, itemsTab.Count(all, one, many)))
  end
  self.removeAll:SetEnabled(all > 0)
  local grid = self:isReadOnly(key) and self.readOnly or self.grid
  grid:SetEntries(shown)
  self:loadNames(key, cold)
end

-- loadNames asks for the item data of items whose names are not known yet, once per key, and shows the list again
-- when it has arrived (if the tab still shows that key).
---@private
---@param key string
---@param ids number[]
function tabProto:loadNames(key, ids)
  if #ids == 0 or self.loading[key] then
    return
  end
  self.loading[key] = true
  local container = ContinuableContainer:Create()
  for _, itemID in ipairs(ids) do
    container:AddContinuable(Item:CreateFromItemID(itemID))
  end
  container:ContinueOnLoad(function()
    self.loading[key] = nil
    if self.source.key() == key and self.frame:IsVisible() then
      self:ShowItems()
    end
  end)
end

-- Drop adds the item on the cursor to the list, which the source may refuse (the item stays on the cursor).
---@param ctx Context
function tabProto:Drop(ctx)
  local key = self.source.key()
  if key == nil or self:isReadOnly(key) or not CursorHasItem() then
    return
  end
  local kind, itemID = GetCursorInfo()
  if kind ~= "item" then
    return
  end
  if not self.source.add(ctx, key, itemID) then
    return
  end
  ClearCursor()
  self:ShowItems()
end

-- OfferRemove offers to remove an item, from a right click on it.
---@param ctx Context
---@param entry NextItemGridEntry
---@param cell Button
function tabProto:OfferRemove(ctx, entry, cell)
  local _ = ctx
  local key = self.source.key()
  if key == nil then
    return
  end
  nextMenu:Open(cell, {
    items = { { text = L:G("Remove") } },
    onPick = function(pctx)
      self.source.remove(pctx, key, entry.itemID)
      self:ShowItems()
    end,
  })
end

-- AskRemoveAll empties the list, after asking.
function tabProto:AskRemoveAll()
  local key = self.source.key()
  if key == nil then
    return
  end
  local n = 0
  for _ in pairs(self.source.list(key)) do
    n = n + 1
  end
  local one, many = self.source.words()
  nextDialog:Show(self.owner, {
    title = L:G("Remove All"),
    text = self.source.clearText(key, itemsTab.Count(n, one, many)),
    buttons = {
      { text = L:G("Cancel"), onClick = function() end },
      { text = L:G("Remove All"), style = "Danger", onClick = function(ctx)
        self.source.clear(ctx, key)
        self:ShowItems()
      end },
    },
  })
end

-- layout puts the count, the filter and Remove All on top, the help under them, and the items taking the room left.
---@private
-- In whole pixels (docs/next-pixel-perfect.md): the top row's parts centered on it by their tops, from the tab's
-- corners; the help's height rounded up.
function tabProto:layout()
  local frame = self.frame
  local m = itemsTab:Metrics(frame)
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
  pixel:Point(self.help, "TOPLEFT", frame, "TOPLEFT", pad, -y)
  self.help:SetWidth(width)
  y = y + pixel:Ceil(frame, self.help:GetStringHeight()) + gap
  for _, grid in ipairs({ self.grid, self.readOnly }) do
    grid.frame:ClearAllPoints()
    grid.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
    grid:Place(width, math.max(pixel:Unit(frame), self.height - y - pad))
  end
end
