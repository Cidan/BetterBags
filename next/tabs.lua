local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextTabs is BetterBagsNext's tab rail (next.md §3): a tab per backpack group, stacked down the
-- body's left edge and sticking out over the feathered edge like bookmarks. The selected tab is
-- brighter and a gold bar glides to it; a hovered tab slides out a little.
---@class NextTabs: AceModule
local nextTabs = addon:NewModule('NextTabs')

---@class (exact) NextTabEntry
---@field id number
---@field name string
---@field tooltip? string[] { title, text } shown on hover.

---@class (exact) NextTab
---@field id number
---@field button Button
---@field text FontString
---@field bg Texture
---@field slide number How far it is slid out, in pixels.
---@field index number Its place in the rail, from 1.
---@field tooltip? string[]

---@class NextTabRail
---@field frame Frame
---@field indicator Texture The gold bar beside the selected tab.
---@field indicatorY number Where the bar is.
---@field tabs NextTab[]
---@field pool NextTab[] Tabs not in use, hidden.
---@field selected? number
---@field onClick? fun(ctx: Context, id: number, button: string)
local railProto = {}
addon:GetModule('Perf'):RegisterPrototype(railProto, 'NextTabRail')

-- The distance from one tab's top to the next's.
local STEP = style.TAB_HEIGHT + style.TAB_SPACING

---@param body Frame
---@return NextTabRail
function nextTabs:Create(body)
  local rail = setmetatable({}, { __index = railProto })
  rail.frame = CreateFrame("Frame", nil, body)
  rail.frame:SetPoint("TOPRIGHT", body, "TOPLEFT", 0, -style.CONTENT_TOP)
  rail.frame:SetSize(style.TAB_MAX_WIDTH, 1)
  rail.indicator = rail.frame:CreateTexture(nil, "OVERLAY")
  rail.indicator:SetColorTexture(unpack(style.Color.Gold))
  rail.indicator:SetSize(3, style.TAB_HEIGHT)
  rail.indicator:Hide()
  rail.indicatorY = 0
  rail.tabs = {}
  rail.pool = {}
  return rail
end

---@param fn fun(ctx: Context, id: number, button: string)
function railProto:SetClickHandler(fn)
  self.onClick = fn
end

---@private
---@return NextTab
function railProto:newTab()
  local button = CreateFrame("Button", nil, self.frame)
  button:SetHeight(style.TAB_HEIGHT)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 1)
  local text = button:CreateFontString(nil, "OVERLAY")
  text:SetFontObject(style:Font("Tab"))
  text:SetPoint("RIGHT", button, "RIGHT", -style.TAB_PADDING, 0)
  text:SetJustifyH("RIGHT")
  ---@type NextTab
  local tab = { id = 0, button = button, text = text, bg = bg, slide = 0, index = 1 }
  addon.SetScript(button, "OnClick", function(ctx, _, mouseButton)
    if self.onClick then
      self.onClick(ctx, tab.id, mouseButton)
    end
  end)
  button:SetScript("OnEnter", function()
    self:slideTo(tab, style.TAB_HOVER)
    if tab.tooltip then
      GameTooltip:SetOwner(button, "ANCHOR_LEFT")
      GameTooltip:SetText(tab.tooltip[1], 1, 1, 1, 1, true)
      if tab.tooltip[2] then
        GameTooltip:AddLine(tab.tooltip[2], 1, 1, 1, true)
      end
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    self:slideTo(tab, 0)
    if tab.tooltip then
      GameTooltip:Hide()
    end
  end)
  return tab
end

---@private
---@param tab NextTab
function railProto:place(tab)
  tab.button:ClearAllPoints()
  tab.button:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -tab.slide, -(tab.index - 1) * STEP)
end

---@private
---@param tab NextTab
---@param to number
function railProto:slideTo(tab, to)
  tween:Play(tab, {
    duration = style.Time.Hover,
    from = tab.slide,
    to = to,
    onUpdate = function(v)
      tab.slide = v
      self:place(tab)
    end,
  })
end

-- SetTabs shows a tab per entry, in order, reusing the tabs it has.
---@param entries NextTabEntry[]
function railProto:SetTabs(entries)
  for i = #self.tabs, #entries + 1, -1 do
    local tab = table.remove(self.tabs, i)
    tween:Stop(tab)
    tab.button:Hide()
    table.insert(self.pool, tab)
  end
  for i, entry in ipairs(entries) do
    local tab = self.tabs[i]
    if tab == nil then
      tab = table.remove(self.pool) or self:newTab()
      self.tabs[i] = tab
    end
    tab.id = entry.id
    tab.index = i
    tab.tooltip = entry.tooltip
    tab.text:SetText(entry.name)
    local width = tab.text:GetStringWidth() + style.TAB_PADDING * 2
    tab.button:SetWidth(math.min(style.TAB_MAX_WIDTH, math.max(style.TAB_MIN_WIDTH, width)))
    self:place(tab)
    tab.button:Show()
  end
  self.frame:SetHeight(math.max(1, #entries * STEP))
  self:Select(self.selected)
end

---@private
---@param tab NextTab
function railProto:paint(tab)
  local selected = tab.id == self.selected
  local color = selected and style.Color.TabSelected or style.Color.Tab
  tab.bg:SetGradient("HORIZONTAL", CreateColor(color[1], color[2], color[3], color[4] * 0.35),
    CreateColor(color[1], color[2], color[3], color[4]))
  tab.text:SetFontObject(style:Font(selected and "TabSelected" or "Tab"))
end

---@private
---@param y number
function railProto:moveIndicator(y)
  self.indicatorY = y
  self.indicator:ClearAllPoints()
  self.indicator:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, y)
end

-- Select makes id's tab the selected one; with animate the gold bar glides to it.
---@param id? number
---@param animate? boolean
function railProto:Select(id, animate)
  self.selected = id
  local target
  for _, tab in ipairs(self.tabs) do
    self:paint(tab)
    if tab.id == id then
      target = -(tab.index - 1) * STEP
    end
  end
  if target == nil then
    tween:Stop(self.indicator)
    self.indicator:Hide()
    return
  end
  if animate and self.indicator:IsShown() then
    tween:Play(self.indicator, {
      duration = style.Time.Glide,
      from = self.indicatorY,
      to = target,
      onUpdate = function(v)
        self:moveIndicator(v)
      end,
    })
  else
    tween:Stop(self.indicator)
    self:moveIndicator(target)
  end
  self.indicator:Show()
end
