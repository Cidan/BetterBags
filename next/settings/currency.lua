local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextToggle: AceModule
local nextToggle = addon:GetModule('NextToggle')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class Currencies: AceModule
local currencies = addon:GetModule('Currencies')

-- NextSettingsCurrency is the classic bags' Currency page (next-settings.md §8), a wide row in place of
-- the classic window's currency panes: every currency under its headings (the headings Blizzard keeps
-- collapsed expanded, as the backpack's currency icons expand them, frames/currency.lua), each with its
-- icon, how many you have (of its most), and a switch that shows it in the backpack. The switch writes
-- Blizzard's own setting (SetCurrencyBackpack) and, once the game has taken it, reads the list again and
-- tells the backpack (currency/Updated), as the classic pane did. C_CurrencyInfo where the client has
-- it, else the legacy globals (Mists Classic), whose flags are numbers.
--
-- The same block is BetterBags Next's Currencies tab (currency.md §6), made with track: there each switch tracks the
-- currency in BetterBags' own list (Currencies, by currency ID, nothing written to Blizzard), and Blizzard's list is
-- read with the headings the player keeps collapsed opened and closed again (Currencies:List).
---@class NextSettingsCurrency: AceModule
---@field all NextSettingsCurrencyBlock[]
local currency = addon:NewModule('NextSettingsCurrency')

-- The game updates the list a moment after SetCurrencyBackpack (the classic pane waited as long).
local SETTLE = 0.1

---@class NextCurrencyRow
---@field frame Frame
---@field hover Texture
---@field icon Texture
---@field name FontString
---@field count FontString
---@field toggle? NextToggleFrame
---@field header boolean
---@field entry? NextCurrencyListEntry

---@class NextSettingsCurrencyBlock
---@field frame Frame
---@field wide boolean
---@field entries NextCurrencyListEntry[]
---@field rows NextCurrencyRow[] Every row made: currencies and headings, the first #entries shown.
---@field empty FontString
---@field track boolean Its switches track currencies (BetterBags Next) rather than show them in the backpack.
local blockProto = {}
addon:GetModule('Perf'):RegisterPrototype(blockProto, 'NextSettingsCurrencyBlock')

currency.all = {}

---@param ctx? Context
function currency:ApplyStyle(ctx)
  local _ = ctx
  for _, block in ipairs(self.all) do
    block:Style()
  end
end

---@param index number
---@param shown boolean
local function setShown(index, shown)
  if C_CurrencyInfo and C_CurrencyInfo.SetCurrencyBackpack then
    C_CurrencyInfo.SetCurrencyBackpack(index, shown)
  elseif SetCurrencyBackpack then
    SetCurrencyBackpack(index, shown and 1 or 0)
  end
end

---@param parent Frame
---@param opts? { track?: boolean }
---@return NextSettingsCurrencyBlock
function currency:Create(parent, opts)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextSettingsCurrencyBlock
  local block = setmetatable({ frame = frame, wide = true, entries = {}, rows = {}, track = opts ~= nil and opts.track == true },
    { __index = blockProto })
  block.empty = style:CreateText(frame, style.Theme.Settings.Content.TextFont)
  block.empty:SetText(L:G("You have no currencies yet."))
  block.empty:Hide()
  table.insert(self.all, block)
  sonataNext:RegisterWidget(self)
  if block.track then
    -- What is tracked changes elsewhere too (the strip's menu, the Tracked tab): the switches follow.
    events:RegisterMessage('currencies/Changed', function()
      if frame:IsVisible() then
        block:ShowTracked()
      end
    end)
  end
  return block
end

-- read reads Blizzard's list: for the classic bags, expanding every collapsed heading (the list grows as it does;
-- each entry's index is where Blizzard's own setting is written); tracking, through Currencies:List, which leaves the
-- list as the player keeps it.
---@private
---@return NextCurrencyListEntry[]
function blockProto:read()
  if self.track then
    return currencies:List()
  end
  local entries = {}
  local i = 1
  while i <= currencies:ListSize() do
    local entry = currencies:ListEntry(i)
    if entry ~= nil then
      if entry.isHeader and not entry.isHeaderExpanded then
        currencies:ExpandListHeading(i, true)
        entry.isHeaderExpanded = true
      end
      table.insert(entries, entry)
    end
    i = i + 1
  end
  return entries
end

-- isOn says whether a currency's switch is on: tracked, or shown in the backpack.
---@private
---@param entry NextCurrencyListEntry
---@return boolean
function blockProto:isOn(entry)
  if self.track then
    return entry.id ~= nil and currencies:IsTracked("currency", entry.id)
  end
  return entry.isShowInBackpack
end

-- ShowTracked sets every switch again to whether its currency is tracked (it slides when that changed).
function blockProto:ShowTracked()
  for k, entry in ipairs(self.entries) do
    local row = self.rows[k]
    if row and row.toggle and not entry.isHeader then
      row.toggle:SetChecked(self:isOn(entry))
    end
  end
end

-- Refresh reads Blizzard's list again and shows it.
---@param ctx? Context
function blockProto:Refresh(ctx)
  local _ = ctx
  local entries = self:read()
  self.entries = entries
  for k, entry in ipairs(entries) do
    local row = self:row(k, entry.isHeader)
    row.entry = entry
    row.name:SetText(entry.name)
    if not entry.isHeader then
      row.icon:SetTexture(entry.icon)
      local have = BreakUpLargeNumbers(entry.quantity)
      row.count:SetText(entry.maxQuantity > 0 and (have .. " / " .. BreakUpLargeNumbers(entry.maxQuantity)) or have)
      row.toggle:SetChecked(self:isOn(entry))
    end
    row.frame:Show()
  end
  for k = #entries + 1, #self.rows do
    self.rows[k].frame:Hide()
    self.rows[k].entry = nil
  end
  self.empty:SetShown(#entries == 0)
  self:Style()
end

-- row returns the k-th row, made (or made again) as a heading or a currency.
---@private
---@param k number
---@param header boolean
---@return NextCurrencyRow
function blockProto:row(k, header)
  local row = self.rows[k]
  if row ~= nil and row.header == header then
    return row
  end
  if row ~= nil then
    row.frame:Hide()
  end
  local C = style.Theme.Settings.Currency
  local frame = CreateFrame("Frame", nil, self.frame)
  frame:EnableMouse(not header)
  row = {
    frame = frame, header = header,
    hover = frame:CreateTexture(nil, "BACKGROUND"),
    icon = frame:CreateTexture(nil, "ARTWORK"),
    name = style:CreateText(frame, header and C.GroupFont or C.NameFont),
    count = style:CreateText(frame, C.TextFont),
  }
  row.hover:SetAllPoints(frame)
  row.hover:Hide()
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  if not header then
    row.toggle = nextToggle:Create(frame, {
      onChange = function(ctx, on)
        if self.track then
          self:Track(ctx, row, on)
        else
          self:ShowInBackpack(ctx, row, on)
        end
      end,
    })
    addon.SetScript(frame, "OnEnter", function() row.hover:Show() end)
    addon.SetScript(frame, "OnLeave", function()
      if not frame:IsMouseOver() then
        row.hover:Hide()
      end
    end)
  end
  self.rows[k] = row
  return row
end

-- Track tracks a currency, or stops tracking it (BetterBags Next: its strip and tracker show it at once).
---@param ctx Context
---@param row NextCurrencyRow
---@param on boolean
function blockProto:Track(ctx, row, on)
  local id = row.entry and row.entry.id
  if id == nil then
    return
  end
  if on then
    currencies:Track(ctx, "currency", id)
  else
    currencies:Untrack(ctx, "currency", id)
  end
end

-- ShowInBackpack writes whether a currency shows in the backpack, then, once the game has taken it, reads the
-- list again and tells the backpack.
---@param ctx Context
---@param row NextCurrencyRow
---@param shown boolean
function blockProto:ShowInBackpack(ctx, row, shown)
  local _ = ctx
  if row.entry == nil then
    return
  end
  setShown(row.entry.index, shown)
  C_Timer.After(SETTLE, function()
    local uctx = context:New('NextSettingsCurrency_Shown')
    self:Refresh(uctx)
    events:SendMessage(uctx, 'currency/Updated')
  end)
end

-- Style draws the rows from the theme.
function blockProto:Style()
  local C = style.Theme.Settings.Currency
  style:SetFont(self.empty, style.Theme.Settings.Content.TextFont)
  for _, row in ipairs(self.rows) do
    style:SetFont(row.name, row.header and C.GroupFont or C.NameFont)
    style:SetFont(row.count, C.TextFont)
    controls:Paint(row.hover, C.Hover)
    row.hover:Hide()
  end
  if self.width then
    self:Place(self.x, self.y, self.width, self.height)
  end
end

---@param width number
---@return number
-- In whole pixels (docs/next-pixel-perfect.md).
function blockProto:Measure(width)
  local _ = width
  local frame = self.frame
  local pad = pixel:Snap(frame, style.Theme.Settings.Content.RowPad)
  if #self.entries == 0 then
    return pixel:Ceil(frame, self.empty:GetStringHeight()) + pad
  end
  local height = 0
  for _, entry in ipairs(self.entries) do
    height = height + self:heightOf(entry)
  end
  return height + pad
end

-- heightOf is a heading's or a currency's row's height in whole pixels.
---@private
---@param entry table
---@return number
function blockProto:heightOf(entry)
  local C = style.Theme.Settings.Currency
  return pixel:Length(self.frame, entry.isHeader and C.HeaderHeight or C.RowHeight)
end

-- Place lays the rows out: a heading's name, then each currency's icon, name, count and switch.
---@param x number
---@param y number
---@param width number
---@param height number
function blockProto:Place(x, y, width, height)
  self.x, self.y, self.width, self.height = x, y, width, height
  local C = style.Theme.Settings.Currency
  local frame = self.frame
  local pad, gap = pixel:Snap(frame, style.Theme.Settings.Content.RowPad), pixel:Snap(frame, C.Gap)
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  pixel:Size(frame, width, height)
  local half = pixel:Floor(frame, pad / 2)
  self.empty:ClearAllPoints()
  pixel:Point(self.empty, "TOPLEFT", frame, "TOPLEFT", pad, -half)
  local top = half
  -- Each part from its row's corners, centered on the row by its top (docs/next-pixel-perfect.md); the count
  -- right of the switch, the name between the icon and the count by the count's width rounded up.
  for k, entry in ipairs(self.entries) do
    local row = self.rows[k]
    local h = self:heightOf(entry)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
    row.frame:SetSize(frame:GetWidth() - 2 * pad, h)
    row.name:ClearAllPoints()
    if entry.isHeader then
      row.icon:Hide()
      row.count:Hide()
      pixel:Point(row.name, "BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, pixel:Snap(frame, 4))
    else
      row.icon:Show()
      row.count:Show()
      pixel:Size(row.icon, C.IconSize, C.IconSize)
      row.icon:ClearAllPoints()
      pixel:Row(row.icon, "TOPLEFT", row.frame, gap, h)
      row.toggle.frame:ClearAllPoints()
      pixel:Row(row.toggle.frame, "TOPRIGHT", row.frame, gap, h)
      local countRight = gap + row.toggle.frame:GetWidth() + 2 * gap
      row.count:ClearAllPoints()
      pixel:Row(row.count, "TOPRIGHT", row.frame, countRight, h)
      pixel:Row(row.name, "TOPLEFT", row.frame, gap + row.icon:GetWidth() + gap, h)
      pixel:Row(row.name, "TOPRIGHT", row.frame, countRight + pixel:Ceil(frame, row.count:GetStringWidth()) + gap, h)
    end
    top = top + h
  end
  frame:Show()
end
