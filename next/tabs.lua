local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextTabs is BetterBagsNext's tab rail (next.md §3): a tab per entry, stacked down the body's
-- inner edge and sticking out over the feathered edge like bookmarks: to the left of the
-- backpack's panel (the right side of the screen), to the right of the bank's (the left side).
-- The selected tab is brighter and a bar in its accent glides to it; a hovered tab slides out a
-- little.
---@class NextTabs: AceModule
local nextTabs = addon:NewModule('NextTabs')

---@class (exact) NextTabEntry
---@field id number
---@field name string
---@field tooltip? string[]|fun(owner: Button) { title, text }, or a function that fills GameTooltip.
---@field accent? number[] The bar's color while it is selected; default gold.
---@field icon? number|string A texture shown beside the name.
---@field atlas? string An atlas shown beside the name.
---@field gap? number Extra room above the tab, in pixels.
---@field secure? number A purchase tab for this bank type (Blizzard's purchase template).
---@field draggable? boolean Dragging it, or dropping on it, calls the drag handler.

---@class (exact) NextTab
---@field id number
---@field button Button
---@field text FontString
---@field icon Texture
---@field bg Texture
---@field slide number How far it is slid out, in pixels.
---@field y number How far below the rail's top it is.
---@field secure boolean It is a purchase tab.
---@field accent? number[]
---@field tooltip? string[]|fun(owner: Button)
---@field draggable? boolean

---@class NextTabRail
---@field frame Frame
---@field side "RIGHT"|"LEFT" The side of the screen the panel is on.
---@field indicator Texture The bar beside the selected tab.
---@field indicatorY number Where the bar is.
---@field tabs NextTab[]
---@field pool NextTab[] Ordinary tabs not in use, hidden.
---@field securePool NextTab[] Purchase tabs not in use, hidden.
---@field selected? number
---@field onClick? fun(ctx: Context, id: number, button: string)
---@field onDrag? fun(ctx: Context, id: number)
local railProto = {}
addon:GetModule('Perf'):RegisterPrototype(railProto, 'NextTabRail')

-- The distance from one tab's top to the next's.
local STEP = style.TAB_HEIGHT + style.TAB_SPACING

-- Create makes a rail for a panel on side of the screen ("RIGHT", the default, or "LEFT").
---@param body Frame
---@param side? "RIGHT"|"LEFT"
---@return NextTabRail
function nextTabs:Create(body, side)
  local rail = setmetatable({}, { __index = railProto })
  rail.side = side or "RIGHT"
  rail.frame = CreateFrame("Frame", nil, body)
  if rail.side == "LEFT" then
    rail.frame:SetPoint("TOPLEFT", body, "TOPRIGHT", 0, -style.CONTENT_TOP)
  else
    rail.frame:SetPoint("TOPRIGHT", body, "TOPLEFT", 0, -style.CONTENT_TOP)
  end
  rail.frame:SetSize(style.TAB_MAX_WIDTH, 1)
  rail.indicator = rail.frame:CreateTexture(nil, "OVERLAY")
  rail.indicator:SetColorTexture(1, 1, 1, 1)
  rail.indicator:SetVertexColor(unpack(style.Color.Gold))
  rail.indicator:SetSize(3, style.TAB_HEIGHT)
  rail.indicator:Hide()
  rail.indicatorY = 0
  rail.tabs = {}
  rail.pool = {}
  rail.securePool = {}
  return rail
end

---@param fn fun(ctx: Context, id: number, button: string)
function railProto:SetClickHandler(fn)
  self.onClick = fn
end

---@param fn fun(ctx: Context, id: number)
function railProto:SetDragHandler(fn)
  self.onDrag = fn
end

-- edge is the point a tab and the bar hang from: the body's side of the rail.
---@private
---@return FramePoint
function railProto:edge()
  return self.side == "LEFT" and "TOPLEFT" or "TOPRIGHT"
end

-- outward is the direction tabs stick out and slide: left (-1) or right (1).
---@private
---@return number
function railProto:outward()
  return self.side == "LEFT" and 1 or -1
end

---@private
---@param secure boolean
---@return NextTab
function railProto:newTab(secure)
  local button
  if secure then
    button = CreateFrame("Button", nil, self.frame, "BankPanelPurchaseButtonScriptTemplate")
  else
    button = CreateFrame("Button", nil, self.frame)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end
  button:SetHeight(style.TAB_HEIGHT)
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 1)
  local text = button:CreateFontString(nil, "OVERLAY")
  text:SetFontObject(style:Font("Tab"))
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(style.TAB_ICON, style.TAB_ICON)
  icon:Hide()
  if self.side == "LEFT" then
    text:SetPoint("LEFT", button, "LEFT", style.TAB_PADDING, 0)
    text:SetJustifyH("LEFT")
    icon:SetPoint("LEFT", text, "RIGHT", style.TAB_ICON_GAP, 0)
  else
    text:SetPoint("RIGHT", button, "RIGHT", -style.TAB_PADDING, 0)
    text:SetJustifyH("RIGHT")
    icon:SetPoint("RIGHT", text, "LEFT", -style.TAB_ICON_GAP, 0)
  end
  ---@type NextTab
  local tab = { id = 0, button = button, text = text, icon = icon, bg = bg, slide = 0, y = 0, secure = secure }
  if not secure then
    addon.SetScript(button, "OnClick", function(ctx, _, mouseButton)
      if self.onClick then
        self.onClick(ctx, tab.id, mouseButton)
      end
    end)
    addon.SetScript(button, "OnDragStart", function(ctx)
      if tab.draggable and self.onDrag then
        self.onDrag(ctx, tab.id)
      end
    end)
    addon.SetScript(button, "OnReceiveDrag", function(ctx)
      if tab.draggable and self.onDrag then
        self.onDrag(ctx, tab.id)
      end
    end)
  end
  button:SetScript("OnEnter", function()
    self:slideTo(tab, style.TAB_HOVER)
    if tab.tooltip then
      GameTooltip:SetOwner(button, self.side == "LEFT" and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
      if type(tab.tooltip) == "function" then
        tab.tooltip(button)
      else
        GameTooltip:SetText(tab.tooltip[1], 1, 1, 1, 1, true)
        if tab.tooltip[2] then
          GameTooltip:AddLine(tab.tooltip[2], 1, 1, 1, true)
        end
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
  tab.button:SetPoint(self:edge(), self.frame, self:edge(), self:outward() * tab.slide, -tab.y)
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

---@private
---@param tab NextTab
function railProto:release(tab)
  tween:Stop(tab)
  tab.slide = 0
  tab.button:Hide()
  table.insert(tab.secure and self.securePool or self.pool, tab)
end

-- take returns a pooled tab of the right kind, or a new one.
---@private
---@param secure boolean
---@return NextTab
function railProto:take(secure)
  local pool = secure and self.securePool or self.pool
  return table.remove(pool) or self:newTab(secure)
end

-- SetTabs shows a tab per entry, in order, reusing the tabs it has: each entry takes the next tab
-- it had of the same kind (ordinary or purchase), so kept tabs are never hidden in between.
---@param entries NextTabEntry[]
function railProto:SetTabs(entries)
  local had = { [false] = {}, [true] = {} }
  for _, tab in ipairs(self.tabs) do
    table.insert(had[tab.secure], tab)
  end
  local taken = { [false] = 1, [true] = 1 }
  self.tabs = {}
  for i, entry in ipairs(entries) do
    local secure = entry.secure ~= nil
    local tab = had[secure][taken[secure]]
    if tab ~= nil then
      had[secure][taken[secure]] = false
      taken[secure] = taken[secure] + 1
    else
      tab = self:take(secure)
    end
    self.tabs[i] = tab
  end
  for _, kind in pairs(had) do
    for _, tab in ipairs(kind) do
      if tab then
        self:release(tab)
      end
    end
  end

  local y = 0
  for i, entry in ipairs(entries) do
    local tab = self.tabs[i]
    if i > 1 then
      y = y + STEP
    end
    y = y + (entry.gap or 0)
    tab.id = entry.id
    tab.y = y
    tab.accent = entry.accent
    tab.tooltip = entry.tooltip
    tab.draggable = entry.draggable
    if entry.secure ~= nil then
      tab.button:SetAttribute("overrideBankType", entry.secure)
    elseif entry.draggable then
      tab.button:RegisterForDrag("LeftButton")
    end
    tab.text:SetText(entry.name)
    local width = tab.text:GetStringWidth() + style.TAB_PADDING * 2
    if entry.icon ~= nil or entry.atlas ~= nil then
      if entry.atlas ~= nil then
        tab.icon:SetAtlas(entry.atlas)
      else
        tab.icon:SetTexture(entry.icon)
      end
      tab.icon:SetSize(style.TAB_ICON, style.TAB_ICON)
      tab.icon:Show()
      width = width + style.TAB_ICON + style.TAB_ICON_GAP
    else
      tab.icon:Hide()
    end
    tab.button:SetWidth(math.min(style.TAB_MAX_WIDTH, math.max(style.TAB_MIN_WIDTH, width)))
    self:place(tab)
    tab.button:Show()
  end
  self.frame:SetHeight(#entries > 0 and (y + STEP) or 1)
  self:Select(self.selected)
end

---@private
---@param tab NextTab
function railProto:paint(tab)
  local selected = tab.id == self.selected
  local color = selected and style.Color.TabSelected or style.Color.Tab
  local faint = CreateColor(color[1], color[2], color[3], color[4] * 0.35)
  local solid = CreateColor(color[1], color[2], color[3], color[4])
  if self.side == "LEFT" then
    tab.bg:SetGradient("HORIZONTAL", solid, faint)
  else
    tab.bg:SetGradient("HORIZONTAL", faint, solid)
  end
  tab.text:SetFontObject(style:Font(selected and "TabSelected" or "Tab"))
end

---@private
---@param y number
function railProto:moveIndicator(y)
  self.indicatorY = y
  self.indicator:ClearAllPoints()
  self.indicator:SetPoint(self:edge(), self.frame, self:edge(), 0, y)
end

-- Select makes id's tab the selected one; with animate the bar glides to it.
---@param id? number
---@param animate? boolean
function railProto:Select(id, animate)
  self.selected = id
  local target, accent
  for _, tab in ipairs(self.tabs) do
    self:paint(tab)
    if tab.id == id then
      target = -tab.y
      accent = tab.accent
    end
  end
  if target == nil then
    tween:Stop(self.indicator)
    self.indicator:Hide()
    return
  end
  self.indicator:SetVertexColor(unpack(accent or style.Color.Gold))
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
