local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class List: AceModule
local list = addon:GetModule('List')

---@class PixelAudit: AceModule
local audit = addon:GetModule('PixelAudit')

-- The Pixels tab of the debug window: turns the pixel check run in game (debug/pixelaudit.lua,
-- next-pixel-perfect.md) on and off, checks the windows shown now, clears its reports, and lists them, the
-- newest first, each part off the grid under its window with the state the window was in. The debug window
-- opens on it when the check finds something.
---@class PixelPane: AceModule
local pixelPane = addon:NewModule('PixelPane')

---@class PixelPaneFrame
---@field frame Frame
---@field toggleButton Button
---@field checkButton Button
---@field clearButton Button
---@field status FontString
---@field list ListFrame
local paneProto = {}
addon:GetModule('Perf'):RegisterPrototype(paneProto, 'PixelPaneFrame')

---@param parent Frame
---@param text string
---@param width number
---@return Button
local function button(parent, text, width)
  local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate') --[[@as Button]]
  b:SetSize(width, 22)
  b:SetText(text)
  return b
end

---@param parent Frame
---@return PixelPaneFrame
function pixelPane:Create(parent)
  local pane = setmetatable({}, { __index = paneProto }) --[[@as PixelPaneFrame]]
  local f = CreateFrame('Frame', nil, parent)
  pane.frame = f

  local title = sonata:CreateText(f, "Title")
  title:SetPoint('TOPLEFT', f, 'TOPLEFT', 10, -8)
  title:SetText('Pixel check')

  local help = sonata:CreateText(f, "BodySmall")
  help:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -6)
  help:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
  help:SetJustifyH('LEFT')
  help:SetText('Checks BetterBags Next\'s windows as you use them, once each one stops moving, and lists the '
    .. 'parts that are not on whole screen pixels. It stays on across reloads until stopped. Reports are also '
    .. 'saved in the BetterBagsPerfDB SavedVariable.')

  pane.toggleButton = button(f, 'Start Checking', 130)
  pane.toggleButton:SetPoint('TOPLEFT', help, 'BOTTOMLEFT', 0, -12)
  addon.SetScript(pane.toggleButton, 'OnClick', function(ctx)
    audit:SetWatching(ctx, not audit:IsWatching())
    pane:Update()
  end)

  pane.checkButton = button(f, 'Check Now', 110)
  pane.checkButton:SetPoint('LEFT', pane.toggleButton, 'RIGHT', 10, 0)
  addon.SetScript(pane.checkButton, 'OnClick', function(ctx)
    audit:CheckNow(ctx)
  end)

  pane.clearButton = button(f, 'Clear', 80)
  pane.clearButton:SetPoint('LEFT', pane.checkButton, 'RIGHT', 10, 0)
  addon.SetScript(pane.clearButton, 'OnClick', function(ctx)
    audit:ClearReports(ctx)
    pane:Update()
  end)

  pane.status = sonata:CreateText(f, "Body")
  pane.status:SetPoint('TOPLEFT', pane.toggleButton, 'BOTTOMLEFT', 0, -10)
  pane.status:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
  pane.status:SetJustifyH('LEFT')

  pane.list = list:Create(f)
  pane.list.frame:SetPoint('TOPLEFT', pane.status, 'BOTTOMLEFT', -10, -8)
  pane.list.frame:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 0, 0)
  pane.list:SetupDataSource('BetterBagsPlainTextListButton', function(row, entry)
    pane:InitRow(row, entry)
  end, function() end)

  for _, message in ipairs({ 'pixelAudit/StateChanged', 'pixelAudit/Found', 'pixelAudit/Checked', 'pixelAudit/Cleared' }) do
    events:RegisterMessage(message, function()
      if f:IsVisible() then
        pane:Update()
      end
    end)
  end
  return pane
end

-- InitRow draws an entry in a list row: a report's head in the Title role, its parts in Body.
---@param row Button
---@param entry {text: string, role: string}
function paneProto:InitRow(row, entry)
  local text = row.text
  if text == nil then
    text = sonata:CreateText(row, entry.role)
    text:SetPoint('LEFT', row, 'LEFT', 8, 0)
    text:SetPoint('RIGHT', row, 'RIGHT', -8, 0)
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    row.text = text
  end
  sonata:SetTextRole(text, entry.role)
  text:SetText(entry.text)
end

---@param n number
---@return string
local function parts(n)
  return string.format('%d %s', n, n == 1 and 'part' or 'parts')
end

-- head is a report's first line: when, which window, how many parts were off (and how many Masque places, its
-- skin, left to it), and the state it was in.
---@param r table
---@return string
local function head(r)
  local off = string.format('%s  %s: %s off', date('%H:%M:%S', r.at), r.window, parts(r.total))
  if (r.othersTotal or 0) > 0 then
    off = string.format('%s, %d more Masque places', off, r.othersTotal)
  end
  local fields = { off,
    string.format('%s at %d%%', r.screen, math.floor(r.uiScale * 100 + 0.5)) }
  if r.details then
    table.insert(fields, r.details)
  end
  if r.theme then
    table.insert(fields, 'theme ' .. r.theme)
  end
  return table.concat(fields, ' · ')
end

-- Update shows whether the check runs and what it checked last, and lists the reports (the debug window calls
-- it on showing the tab, and the pane on every change the check announces while it is shown).
function paneProto:Update()
  local watching = audit:IsWatching()
  self.toggleButton:SetText(watching and 'Stop Checking' or 'Start Checking')
  local status = watching and 'Checking BetterBags Next\'s windows as you use them.'
    or 'Not checking. Check Now checks the windows shown once.'
  local last = audit.lastChecked
  if last ~= nil then
    local off = last.count == 0 and 'nothing off' or (parts(last.count) .. ' off')
    if (last.others or 0) > 0 then
      off = string.format('%s (%s Masque places)', off, parts(last.others))
    end
    status = string.format('%s Last checked: %s, %s, %s.', status, last.window, off, date('%H:%M:%S', last.at))
  end
  self.status:SetText(status)
  local entries = {}
  local reports = audit:GetReports()
  for i = #reports, 1, -1 do
    local r = reports[i]
    table.insert(entries, { text = head(r), role = 'Title' })
    for _, line in ipairs(r.lines) do
      table.insert(entries, { text = '    ' .. line, role = 'Body' })
    end
    if r.total > #r.lines then
      table.insert(entries, { text = string.format('    and %d more', r.total - #r.lines), role = 'Muted' })
    end
  end
  if #entries == 0 then
    entries = { { text = 'Nothing off the grid found yet.', role = 'Muted' } }
  end
  self.list:Wipe()
  self.list:InsertTable(entries)
end

function paneProto:Show()
  self.frame:Show()
end

function paneProto:Hide()
  self.frame:Hide()
end
