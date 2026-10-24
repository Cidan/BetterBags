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

-- NextTopTabs is the row of tabs across a settings page (next-settings.md §2), drawn from the theme
-- (Controls.TopTabs): labels left to right, Gap apart, the chosen one in its font and underlined by a
-- marker that glides to the tab chosen, over a line under them all.
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
---@field line Texture
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
  local marker = frame:CreateTexture(nil, "ARTWORK")
  ---@type NextTopTabsFrame
  local t = setmetatable({
    frame = frame, line = line, marker = marker, tabs = {}, list = {}, markerX = 0, markerWidth = 0, opts = opts,
  }, { __index = tabsProto })
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
  tab = { frame = frame, label = label, hovered = false }
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
  self.line:ClearAllPoints()
  self.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  self.line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  pixel:Height(self.line, T.Line.Size or 1)
  controls:Paint(self.line, T.Line)
  pixel:Height(self.marker, T.Indicator.Height)
  -- Art when the indicator names some, else its color.
  controls:Paint(self.marker, style:IsArt(T.Indicator) and T.Indicator or { Color = T.Indicator.Color })
  local gap = pixel:Snap(frame, T.Gap)
  local previous
  for i = 1, #self.list do
    local tab = self.tabs[i]
    tab.frame:ClearAllPoints()
    if previous == nil then
      tab.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    else
      tab.frame:SetPoint("BOTTOMLEFT", previous.frame, "BOTTOMRIGHT", gap, 0)
    end
    tab.frame:SetHeight(frame:GetHeight())
    previous = tab
  end
  self:Paint()
  local x, width = self:placeOf(self.selected)
  self:Mark(x, width)
end

-- Paint gives each tab its font (and its width, the label's, which the font sets): chosen, under the
-- pointer, or neither.
function tabsProto:Paint()
  local T = controls:Theme("TopTabs")
  for i = 1, #self.list do
    local tab = self.tabs[i]
    local font = T.Font
    if tab.id == self.selected then
      font = T.SelectedFont
    elseif tab.hovered then
      font = T.HoverFont
    end
    style:SetFont(tab.label, font)
    -- As wide as its label rounded up to whole pixels, the label by its top left, centered on its height.
    tab.frame:SetWidth(pixel:Ceil(tab.frame, tab.label:GetStringWidth()))
    tab.label:ClearAllPoints()
    pixel:Row(tab.label, "TOPLEFT", tab.frame, 0, pixel:Length(tab.frame, T.Height))
  end
end

-- placeOf returns where the tab with id starts, across from the row's left, and its width.
---@private
---@param id any
---@return number x, number width
function tabsProto:placeOf(id)
  local T = controls:Theme("TopTabs")
  local x, gap = 0, pixel:Snap(self.frame, T.Gap)
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

-- Mark puts the marker under x, width wide (hidden at no width).
---@param x number
---@param width number
function tabsProto:Mark(x, width)
  self.markerX, self.markerWidth = x, width
  self.marker:ClearAllPoints()
  self.marker:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 0)
  self.marker:SetWidth(math.max(1, width))
  self.marker:SetShown(width > 0)
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
