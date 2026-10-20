local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class Context: AceModule
local context = addon:GetModule('Context')

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
---@field accent? string|number[] The bar's color while it is selected: an accent of the theme by name
--- (Tabs.Accents: Warbank, Guild), a palette color, or a color; the theme's bar color by default.
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
---@field glow Texture Lit while the tab is a drop target, and when it pulses.
---@field slide number How far it is slid out, in pixels.
---@field width number The width it was given (never read back from the client, which returns it with
--- float error at a UI scale).
---@field y number How far below the rail's top it is.
---@field secure boolean It is a purchase tab.
---@field accent? string|number[]
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
---@field dropTarget? number The tab a dragged section would drop on (next.md §7).
---@field entries NextTabEntry[] What SetTabs was last given, laid out again by a theme (ApplyStyle).
---@field onClick? fun(ctx: Context, id: number, button: string)
---@field onDrag? fun(ctx: Context, id: number)
---@field onResize? fun(ctx: Context) Runs after the tabs are set, which can change the rail's width.
local railProto = {}
addon:GetModule('Perf'):RegisterPrototype(railProto, 'NextTabRail')

-- step is the distance from one tab's top to the next's, for the current theme.
---@return number
local function step()
  return style.TAB_HEIGHT + style.TAB_SPACING
end

-- accentColor is the color of the bar beside a selected tab: its accent (an accent of the theme by
-- name, a palette color, or a color given outright), else the theme's bar color.
---@param accent? string|number[]
---@return number r, number g, number b, number a
local function accentColor(accent)
  local T = style.Theme.Tabs
  if accent == nil then
    return style:RGBA(T.Indicator and T.Indicator.Color or "Gold")
  end
  if type(accent) == "string" then
    return style:RGBA(T.Accents[accent] or accent)
  end
  return style:RGBA(accent)
end

-- Create makes a rail for a panel on side of the screen ("RIGHT", the default, or "LEFT").
---@param body Frame
---@param side? "RIGHT"|"LEFT"
---@return NextTabRail
function nextTabs:Create(body, side)
  local rail = setmetatable({}, { __index = railProto })
  rail.side = side or "RIGHT"
  rail.body = body
  rail.frame = CreateFrame("Frame", nil, body)
  rail.indicator = rail.frame:CreateTexture(nil, "OVERLAY")
  rail.indicator:SetColorTexture(1, 1, 1, 1)
  rail.indicator:Hide()
  rail.indicatorY = 0
  rail.tabs = {}
  rail.entries = {}
  rail.pool = {}
  rail.securePool = {}
  rail:styleRail()
  return rail
end

-- styleRail hangs the rail below the header and sizes the bar from the theme.
---@private
function railProto:styleRail()
  local frame, body = self.frame, self.body
  frame:ClearAllPoints()
  if self.side == "LEFT" then
    frame:SetPoint("TOPLEFT", body, "TOPRIGHT", 0, -style.CONTENT_TOP)
  else
    frame:SetPoint("TOPRIGHT", body, "TOPLEFT", 0, -style.CONTENT_TOP)
  end
  frame:SetSize(style.TAB_MAX_WIDTH, 1)
  local bar = style.Theme.Tabs.Indicator
  self.indicator:SetSize(bar and bar.Width or 0, style.TAB_HEIGHT)
end

-- styleTab draws a tab's parts from the theme: its height, its glow's color, its name and icon where
-- they go (its fill and font are its state's, paint).
---@private
---@param tab NextTab
function railProto:styleTab(tab)
  local button, text, icon = tab.button, tab.text, tab.icon
  button:SetHeight(style.TAB_HEIGHT)
  local glow = style.Theme.Tabs.Glow
  if glow then
    tab.glow:SetVertexColor(style:RGBA(glow.Color))
    tab.glow:SetBlendMode(glow.BlendMode or "ADD")
  else
    tween:Stop(tab.glow)
    tab.glow:Hide()
  end
  icon:SetSize(style.TAB_ICON, style.TAB_ICON)
  text:ClearAllPoints()
  icon:ClearAllPoints()
  if self.side == "LEFT" then
    text:SetPoint("LEFT", button, "LEFT", style.TAB_PADDING, 0)
    text:SetJustifyH("LEFT")
    icon:SetPoint("LEFT", text, "RIGHT", style.TAB_ICON_GAP, 0)
  else
    text:SetPoint("RIGHT", button, "RIGHT", -style.TAB_PADDING, 0)
    text:SetJustifyH("RIGHT")
    icon:SetPoint("RIGHT", text, "LEFT", -style.TAB_ICON_GAP, 0)
  end
end

-- ApplyStyle restyles the rail and every tab it holds (shown or pooled) for the current theme, and
-- lays its tabs out again: their widths follow their names in the new fonts (SonataNext applied a
-- theme).
---@param ctx? Context
function railProto:ApplyStyle(ctx)
  local _ = ctx
  self:styleRail()
  for _, list in ipairs({ self.tabs, self.pool, self.securePool }) do
    for _, tab in ipairs(list) do
      self:styleTab(tab)
      self:paint(tab)
    end
  end
  self:SetTabs(self.entries)
end

---@param fn fun(ctx: Context, id: number, button: string)
function railProto:SetClickHandler(fn)
  self.onClick = fn
end

---@param fn fun(ctx: Context, id: number)
function railProto:SetDragHandler(fn)
  self.onDrag = fn
end

-- SetResizeHandler sets what runs after the tabs are set (their widths can have changed).
---@param fn fun(ctx: Context)
function railProto:SetResizeHandler(fn)
  self.onResize = fn
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
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 1)
  local glow = button:CreateTexture(nil, "ARTWORK")
  glow:SetAllPoints()
  glow:SetColorTexture(1, 1, 1, 1)
  glow:Hide()
  local text = style:CreateText(button, style.Theme.Tabs.Font)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:Hide()
  ---@type NextTab
  local tab = { id = 0, button = button, text = text, icon = icon, bg = bg, glow = glow, slide = 0, y = 0, secure = secure }
  self:styleTab(tab)
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
    if tab.id ~= self.dropTarget then
      self:slideTo(tab, 0)
    end
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
    ease = style:Ease("Hover"),
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
  tween:Stop(tab.glow)
  tab.glow:Hide()
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
  self.entries = entries
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
      y = y + step()
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
    tab.width = math.min(style.TAB_MAX_WIDTH, math.max(style.TAB_MIN_WIDTH, width))
    tab.button:SetWidth(tab.width)
    self:place(tab)
    tab.button:Show()
  end
  self.frame:SetHeight(#entries > 0 and (y + step()) or 1)
  self:Select(self.selected)
  if self.onResize then
    self.onResize(context:New("NextTabs_Resize"))
  end
end

-- Width is how far the rail's tabs stick out from the body: its widest tab, without the hover
-- slide; 0 with no tabs. From the widths the rail gave its tabs: the client hands a frame's size
-- back with float error at a UI scale (window.md §3b), and a chained bag's place, computed from
-- this, must come out the same every time (next.md §12).
---@return number
function railProto:Width()
  local widest = 0
  for _, tab in ipairs(self.tabs) do
    widest = math.max(widest, tab.width)
  end
  return widest
end

---@private
---@param tab NextTab
function railProto:paint(tab)
  local T = style.Theme.Tabs
  local selected = tab.id == self.selected or tab.id == self.dropTarget
  local r, g, b, a = style:RGBA(selected and T.SelectedFill or T.Fill)
  local faint = CreateColor(r, g, b, a * T.Fade)
  local solid = CreateColor(r, g, b, a)
  if self.side == "LEFT" then
    tab.bg:SetGradient("HORIZONTAL", solid, faint)
  else
    tab.bg:SetGradient("HORIZONTAL", faint, solid)
  end
  style:SetFont(tab.text, selected and T.SelectedFont or T.Font)
end

---@private
---@param y number
function railProto:moveIndicator(y)
  self.indicatorY = y
  self.indicator:ClearAllPoints()
  self.indicator:SetPoint(self:edge(), self.frame, self:edge(), 0, y)
end

-- tab returns the tab of an id.
---@param id? number
---@return NextTab?
function railProto:Tab(id)
  for _, tab in ipairs(self.tabs) do
    if tab.id == id then
      return tab
    end
  end
  return nil
end

-- TabAt returns the tab under the cursor, by position (IsMouseOver), whatever lies above it: a
-- dragged section follows the cursor.
---@return NextTab?
function railProto:TabAt()
  if not self.frame:IsShown() then
    return nil
  end
  for _, tab in ipairs(self.tabs) do
    if tab.button:IsShown() and tab.button:IsMouseOver() then
      return tab
    end
  end
  return nil
end

-- SetDropTarget lights id's tab, slid out, as the tab a dragged section would drop on, or no tab.
---@param id? number
function railProto:SetDropTarget(id)
  if id == self.dropTarget then
    return
  end
  local old = self:Tab(self.dropTarget)
  self.dropTarget = id
  if old then
    tween:Stop(old.glow)
    old.glow:Hide()
    self:slideTo(old, 0)
    self:paint(old)
  end
  local new = self:Tab(id)
  if new then
    tween:Stop(new.glow)
    local glow = style.Theme.Tabs.Glow
    if glow then
      new.glow:SetAlpha(glow.Drop)
      new.glow:Show()
    end
    self:slideTo(new, style.TAB_HOVER)
    self:paint(new)
  end
end

-- Pulse flashes id's tab: it received a section.
---@param id number
function railProto:Pulse(id)
  local tab = self:Tab(id)
  local spec = style.Theme.Tabs.Glow
  if tab == nil or not spec then
    return
  end
  local glow = tab.glow
  glow:Show()
  tween:Play(glow, {
    duration = style.Time.Pulse,
    from = spec.Pulse,
    to = 0,
    ease = style:Ease("Pulse"),
    onUpdate = function(v)
      glow:SetAlpha(v)
    end,
    onDone = function()
      if tab.id ~= self.dropTarget then
        glow:Hide()
      end
    end,
  })
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
  if target == nil or not style.Theme.Tabs.Indicator then
    tween:Stop(self.indicator)
    self.indicator:Hide()
    return
  end
  self.indicator:SetVertexColor(accentColor(accent))
  if animate and self.indicator:IsShown() then
    tween:Play(self.indicator, {
      duration = style.Time.Glide,
      from = self.indicatorY,
      to = target,
      ease = style:Ease("Glide"),
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
