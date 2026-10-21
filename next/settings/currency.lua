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

-- NextSettingsCurrency is the classic bags' Currency page (next-settings.md §8), a wide row in place of
-- the classic window's currency panes: every currency under its headings (the headings Blizzard keeps
-- collapsed expanded, as the backpack's currency icons expand them, frames/currency.lua), each with its
-- icon, how many you have (of its most), and a switch that shows it in the backpack. The switch writes
-- Blizzard's own setting (SetCurrencyBackpack) and, once the game has taken it, reads the list again and
-- tells the backpack (currency/Updated), as the classic pane did. C_CurrencyInfo where the client has
-- it, else the legacy globals (Mists Classic), whose flags are numbers.
---@class NextSettingsCurrency: AceModule
---@field all NextSettingsCurrencyBlock[]
local currency = addon:NewModule('NextSettingsCurrency')

-- The game updates the list a moment after SetCurrencyBackpack (the classic pane waited as long).
local SETTLE = 0.1

---@class (exact) NextCurrencyEntry
---@field index number Its place in Blizzard's list.
---@field name string
---@field isHeader boolean
---@field isHeaderExpanded boolean
---@field isShowInBackpack boolean
---@field quantity number
---@field maxQuantity number
---@field icon? number|string

---@class NextCurrencyRow
---@field frame Frame
---@field hover Texture
---@field icon Texture
---@field name FontString
---@field count FontString
---@field toggle? NextToggleFrame
---@field header boolean
---@field entry? NextCurrencyEntry

---@class NextSettingsCurrencyBlock
---@field frame Frame
---@field wide boolean
---@field entries NextCurrencyEntry[]
---@field rows NextCurrencyRow[] Every row made: currencies and headings, the first #entries shown.
---@field empty FontString
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

-- read returns the entry at index, from whichever API the client has.
---@param index number
---@return NextCurrencyEntry?
local function read(index)
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo then
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    if info == nil then
      return nil
    end
    return {
      index = index, name = info.name or "", isHeader = info.isHeader == true,
      isHeaderExpanded = info.isHeaderExpanded == true, isShowInBackpack = info.isShowInBackpack == true,
      quantity = info.quantity or 0, maxQuantity = info.maxQuantity or 0, icon = info.iconFileID,
    }
  end
  if GetCurrencyListInfo then
    local name, isHeader, isExpanded, _, isWatched, count, icon, maximum = GetCurrencyListInfo(index)
    if name == nil then
      return nil
    end
    return {
      index = index, name = name, isHeader = isHeader == true, isHeaderExpanded = isExpanded == true,
      isShowInBackpack = isWatched == true, quantity = count or 0, maxQuantity = maximum or 0, icon = icon,
    }
  end
  return nil
end

---@return number
local function size()
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
    return C_CurrencyInfo.GetCurrencyListSize()
  end
  if GetCurrencyListSize then
    return GetCurrencyListSize()
  end
  return 0
end

---@param index number
local function expand(index)
  if C_CurrencyInfo and C_CurrencyInfo.ExpandCurrencyList then
    C_CurrencyInfo.ExpandCurrencyList(index, true)
  elseif ExpandCurrencyList then
    ExpandCurrencyList(index, 1)
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
---@return NextSettingsCurrencyBlock
function currency:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  ---@type NextSettingsCurrencyBlock
  local block = setmetatable({ frame = frame, wide = true, entries = {}, rows = {} }, { __index = blockProto })
  block.empty = style:CreateText(frame, style.Theme.Settings.Content.TextFont)
  block.empty:SetText(L:G("You have no currencies yet."))
  block.empty:Hide()
  table.insert(self.all, block)
  sonataNext:RegisterWidget(self)
  return block
end

-- Refresh reads Blizzard's list again, expanding every collapsed heading (the list grows as it does).
---@param ctx? Context
function blockProto:Refresh(ctx)
  local _ = ctx
  local entries = {}
  local i = 1
  while i <= size() do
    local entry = read(i)
    if entry ~= nil then
      if entry.isHeader and not entry.isHeaderExpanded then
        expand(i)
        entry.isHeaderExpanded = true
      end
      table.insert(entries, entry)
    end
    i = i + 1
  end
  self.entries = entries
  for k, entry in ipairs(entries) do
    local row = self:row(k, entry.isHeader)
    row.entry = entry
    row.name:SetText(entry.name)
    if not entry.isHeader then
      row.icon:SetTexture(entry.icon)
      local have = BreakUpLargeNumbers(entry.quantity)
      row.count:SetText(entry.maxQuantity > 0 and (have .. " / " .. BreakUpLargeNumbers(entry.maxQuantity)) or have)
      row.toggle:SetChecked(entry.isShowInBackpack)
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
      onChange = function(ctx, shown) self:ShowInBackpack(ctx, row, shown) end,
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
function blockProto:Measure(width)
  local _ = width
  local C = style.Theme.Settings.Currency
  local pad = style.Theme.Settings.Content.RowPad
  if #self.entries == 0 then
    return math.ceil(self.empty:GetStringHeight()) + pad
  end
  local height = 0
  for _, entry in ipairs(self.entries) do
    height = height + (entry.isHeader and C.HeaderHeight or C.RowHeight)
  end
  return height + pad
end

-- Place lays the rows out: a heading's name, then each currency's icon, name, count and switch.
---@param x number
---@param y number
---@param width number
---@param height number
function blockProto:Place(x, y, width, height)
  self.x, self.y, self.width, self.height = x, y, width, height
  local C = style.Theme.Settings.Currency
  local pad = style.Theme.Settings.Content.RowPad
  local frame = self.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  frame:SetSize(width, height)
  self.empty:ClearAllPoints()
  self.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad / 2)
  local top = pad / 2
  for k, entry in ipairs(self.entries) do
    local row = self.rows[k]
    local h = entry.isHeader and C.HeaderHeight or C.RowHeight
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
    row.frame:SetSize(width - 2 * pad, h)
    row.name:ClearAllPoints()
    if entry.isHeader then
      row.icon:Hide()
      row.count:Hide()
      row.name:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 4)
    else
      row.icon:Show()
      row.count:Show()
      row.icon:SetSize(C.IconSize, C.IconSize)
      row.icon:ClearAllPoints()
      row.icon:SetPoint("LEFT", row.frame, "LEFT", C.Gap, 0)
      row.toggle.frame:ClearAllPoints()
      row.toggle.frame:SetPoint("RIGHT", row.frame, "RIGHT", -C.Gap, 0)
      row.count:ClearAllPoints()
      row.count:SetPoint("RIGHT", row.toggle.frame, "LEFT", -2 * C.Gap, 0)
      row.name:SetPoint("LEFT", row.icon, "RIGHT", C.Gap, 0)
      row.name:SetPoint("RIGHT", row.count, "LEFT", -C.Gap, 0)
    end
    top = top + h
  end
  frame:Show()
end
