local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

-- NextTopTabs is the row of tabs across a settings page (next-settings.md §2), drawn from the theme
-- (Controls.TopTabs): labels left to right, Gap apart, the chosen one in its font and underlined by a
-- marker that glides to the tab chosen, over a line under them all (reaching past them by Line.Outset, and stopping
-- under the chosen tab with Line.Open, so it opens onto the page as a tab on a pane). Tabs too wide for their row give
-- up half their padding, then half their gaps, then cut their names short, the longest first.
---@class NextTopTabs: AceModule
---@field all NextTopTabsFrame[]
local nextTopTabs = addon:NewModule('NextTopTabs')

---@class (exact) NextTopTab
---@field id any
---@field text string

---@class (exact) NextTopTabsOptions
---@field onSelect fun(ctx: Context, id: any)

---@class NextTopTabButton
---@field frame Button
---@field label FontString
---@field id any
---@field hovered boolean

---@class NextTopTabsFrame
---@field frame Frame
---@field line Texture The line under the tabs, or its part left of the chosen tab (Line.Open).
---@field lineRight Texture The line's part right of the chosen tab (Line.Open).
---@field gap number The room between tabs, as fitted to the row (Paint).
---@field marker Texture
---@field tabs NextTopTabButton[] Every tab made; the first #list are shown.
---@field list NextTopTab[]
---@field selected any
---@field markerX number
---@field markerWidth number
---@field opts NextTopTabsOptions
local tabsProto = {}
addon:GetModule('Perf'):RegisterPrototype(tabsProto, 'NextTopTabsFrame')

nextTopTabs.all = {}

---@param ctx? Context
function nextTopTabs:ApplyStyle(ctx)
  local _ = ctx
  for _, t in ipairs(self.all) do
    t:Style()
  end
end

---@param parent Frame
---@param opts NextTopTabsOptions
---@return NextTopTabsFrame
function nextTopTabs:Create(parent, opts)
  local frame = CreateFrame("Frame", nil, parent)
  local line = frame:CreateTexture(nil, "BACKGROUND")
  local lineRight = frame:CreateTexture(nil, "BACKGROUND")
  local marker = frame:CreateTexture(nil, "ARTWORK")
  ---@type NextTopTabsFrame
  local t = setmetatable({
    frame = frame, line = line, lineRight = lineRight, marker = marker, tabs = {}, list = {}, markerX = 0,
    markerWidth = 0, gap = 0, opts = opts,
  }, { __index = tabsProto })
  -- Fitted to the row again when its width changes (a plain hook: only on size changes).
  frame:HookScript("OnSizeChanged", function()
    t:Fit()
  end)
  table.insert(self.all, t)
  sonataNext:RegisterWidget(self)
  t:Style()
  return t
end

-- tab returns the i-th tab button, made the first time it is needed.
---@private
---@param i number
---@return NextTopTabButton
function tabsProto:tab(i)
  local tab = self.tabs[i]
  if tab ~= nil then
    return tab
  end
  local frame = CreateFrame("Button", nil, self.frame)
  frame:RegisterForClicks("LeftButtonUp")
  local label = frame:CreateFontString(nil, "OVERLAY")
  -- The tab's own art (Fill, HoverFill, SelectedFill: Blizzard's MinimalTab), behind its label.
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(frame)
  fill:Hide()
  fills:Wrap(fill, frame)
  tab = { frame = frame, label = label, fill = fill, hovered = false }
  style:SetFont(label, controls:Theme("TopTabs").Font)
  addon.SetScript(frame, "OnClick", function(ctx) self:Click(ctx, tab) end)
  addon.SetScript(frame, "OnEnter", function() tab.hovered = true self:Paint() end)
  addon.SetScript(frame, "OnLeave", function() tab.hovered = false self:Paint() end)
  self.tabs[i] = tab
  return tab
end

-- SetTabs shows these tabs, hiding the rest.
---@param list NextTopTab[]
function tabsProto:SetTabs(list)
  self.list = list
  for i, entry in ipairs(list) do
    local tab = self:tab(i)
    tab.id = entry.id
    tab.label:SetText(entry.text)
    tab.frame:Show()
  end
  for i = #list + 1, #self.tabs do
    self.tabs[i].frame:Hide()
    self.tabs[i].id = nil
  end
  self:Style()
end

---@return any
function tabsProto:GetSelected()
  return self.selected
end

-- Style lays the tabs out and draws them, the marker under the chosen one, all in whole pixels
-- (docs/next-pixel-perfect.md).
function tabsProto:Style()
  local T = controls:Theme("TopTabs")
  local frame = self.frame
  pixel:Height(frame, T.Height)
  -- A theme may draw no line under the tabs and no marker under the chosen one (false: Blizzard's tabs, MinimalTab,
  -- show the chosen one in their own art).
  for _, line in ipairs({ self.line, self.lineRight }) do
    pixel:Height(line, T.Line and T.Line.Size or 1)
    controls:Paint(line, T.Line)
  end
  local marker = T.Indicator
  pixel:Height(self.marker, marker and marker.Height or 1)
  -- Art when the indicator names some, else its color.
  controls:Paint(self.marker, marker and (style:IsArt(marker) and marker or { Color = marker.Color }) or false)
  self:Fit()
end

-- Fit lays the tabs out in the row's width again and puts the marker and the line under the chosen one.
function tabsProto:Fit()
  self:Paint()
  local x, width = self:placeOf(self.selected)
  self:Mark(x, width)
end

-- fitted works out the room the tabs take: their Padding and Gap, while every name fits the row; else half the padding,
-- then half the gaps, then the names cut to the widest each may keep (those shorter keep theirs). A row with no width
-- yet (not laid out) takes every tab whole. In whole pixels: the room a tab may take rounded down
-- (docs/next-pixel-perfect.md).
---@private
---@param names number[] Each tab's name's width.
---@return number pad, number gap, number? cap
function tabsProto:fitted(names)
  local T, frame = controls:Theme("TopTabs"), self.frame
  local n = #names
  local pad, gap = pixel:Snap(frame, T.Padding or 0), pixel:Snap(frame, T.Gap)
  local room = frame:GetWidth()
  local text = 0
  for _, width in ipairs(names) do
    text = text + width
  end
  local function total(p, g)
    return text + 2 * n * p + math.max(0, n - 1) * g
  end
  if n == 0 or room <= 0 or total(pad, gap) <= room then
    return pad, gap, nil
  end
  pad = math.max(pixel:Floor(frame, pad / 2), pixel:Floor(frame, (room - text - math.max(0, n - 1) * gap) / (2 * n)))
  if total(pad, gap) <= room then
    return pad, gap, nil
  end
  if n > 1 then
    gap = math.max(pixel:Floor(frame, gap / 2), pixel:Floor(frame, (room - text - 2 * n * pad) / (n - 1)))
  end
  if total(pad, gap) <= room then
    return pad, gap, nil
  end
  -- The names' room shared out: each name its share, a shorter one keeping its own and leaving the rest to the others.
  local budget = room - 2 * n * pad - math.max(0, n - 1) * gap
  local sorted = {}
  for i, width in ipairs(names) do
    sorted[i] = width
  end
  table.sort(sorted)
  local cap = 0
  for i, width in ipairs(sorted) do
    local share = budget / (n - i + 1)
    if width > share then
      cap = share
      break
    end
    budget = budget - width
    cap = width
  end
  return pad, gap, math.max(0, pixel:Floor(frame, cap))
end

-- Paint gives each tab its font (and its width, the label's, which the font sets, fitted to the row) and its art:
-- chosen, under the pointer, or neither; and lays the tabs out left to right, the fitted gap apart.
function tabsProto:Paint()
  local T = controls:Theme("TopTabs")
  local frame = self.frame
  local names = {}
  for i = 1, #self.list do
    local tab = self.tabs[i]
    local chosen = tab.id == self.selected
    local font, art = T.Font, T.Fill
    if chosen then
      font, art = T.SelectedFont, T.SelectedFill or T.Fill
    elseif tab.hovered then
      font, art = T.HoverFont, T.HoverFill or T.Fill
    end
    style:SetFont(tab.label, font)
    controls:Paint(tab.fill, art or false)
    -- Its whole name's width: the width a font string keeps is reset (Blizzard's QuestLogTitleButton_Resize).
    tab.label:SetWidth(0)
    tab.label:SetWordWrap(false)
    names[i] = pixel:Ceil(tab.frame, tab.label:GetStringWidth())
  end
  local pad, gap, cap = self:fitted(names)
  self.gap = gap
  local previous
  for i = 1, #self.list do
    local tab = self.tabs[i]
    local chosen = tab.id == self.selected
    tab.frame:ClearAllPoints()
    if previous == nil then
      tab.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    else
      tab.frame:SetPoint("BOTTOMLEFT", previous.frame, "BOTTOMRIGHT", gap, 0)
    end
    tab.frame:SetHeight(frame:GetHeight())
    previous = tab
    -- As wide as its label rounded up to whole pixels (cut to the row's room, cap) and Padding either side; the label by
    -- its top left, centered on its height, or by its bottom TextBottom above the tab's (SelectedTextBottom when chosen:
    -- Blizzard's MinimalTab).
    local name = names[i]
    if cap ~= nil and name > cap then
      name = cap
      tab.label:SetWidth(cap)
    end
    tab.frame:SetWidth(name + 2 * pad)
    tab.label:ClearAllPoints()
    local raise = chosen and (T.SelectedTextBottom or T.TextBottom) or T.TextBottom
    if raise ~= nil then
      pixel:Point(tab.label, "BOTTOM", tab.frame, "BOTTOM", 0, raise)
    else
      pixel:Row(tab.label, "TOPLEFT", tab.frame, pad, pixel:Length(tab.frame, T.Height))
    end
  end
end

-- placeOf returns where the tab with id starts, across from the row's left, and its width.
---@private
---@param id any
---@return number x, number width
function tabsProto:placeOf(id)
  local x, gap = 0, self.gap
  for i = 1, #self.list do
    local tab = self.tabs[i]
    local width = tab.frame:GetWidth()
    if tab.id == id then
      return x, width
    end
    x = x + width + gap
  end
  return 0, 0
end

-- Mark puts the marker under x, width wide (hidden at no width), and the line under the tabs: past them by its
-- Outset on either side, and, for a line that opens (Line.Open), in two parts that stop under the chosen tab, keeping
-- its sides on the line, so it glides with the marker.
---@param x number
---@param width number
function tabsProto:Mark(x, width)
  local T, frame = controls:Theme("TopTabs"), self.frame
  self.markerX, self.markerWidth = x, width
  self.marker:ClearAllPoints()
  self.marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 0)
  self.marker:SetWidth(math.max(1, width))
  local marker = T.Indicator
  self.marker:SetShown(width > 0 and marker ~= nil and marker ~= false)
  local L = T.Line
  local out = L and L.Outset or {}
  local left, right = pixel:Snap(frame, out.Left or 0), pixel:Snap(frame, out.Right or 0)
  self.line:ClearAllPoints()
  self.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -left, 0)
  if L and L.Open and width > 0 then
    local size = self.line:GetHeight()
    self.line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x + size, 0)
    self.lineRight:ClearAllPoints()
    self.lineRight:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x + width - size, 0)
    self.lineRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, 0)
    self.lineRight:Show()
  else
    self.line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, 0)
    self.lineRight:Hide()
  end
end

-- Select chooses a tab, its marker gliding there with animate, calling nothing back.
---@param id any
---@param animate? boolean
function tabsProto:Select(id, animate)
  self.selected = id
  self:Paint()
  local x, width = self:placeOf(id)
  if not animate then
    tween:Stop(self)
    self:Mark(x, width)
    return
  end
  local fromX, fromWidth = self.markerX, self.markerWidth
  tween:Play(self, {
    duration = style.Time.TabMarker,
    ease = style:Ease("TabMarker"),
    from = 0,
    to = 1,
    onUpdate = function(u)
      self:Mark(fromX + (x - fromX) * u, fromWidth + (width - fromWidth) * u)
    end,
  })
end

-- Click chooses a tab and says which, unless it is the one chosen.
---@param ctx Context
---@param tab NextTopTabButton
function tabsProto:Click(ctx, tab)
  if tab.id == self.selected then
    return
  end
  self:Select(tab.id, true)
  self.opts.onSelect(ctx, tab.id)
end
