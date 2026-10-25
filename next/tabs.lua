local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

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
---@field bag? boolean A bag slot (the backpack's Show Blizzard Bags): no section is dropped on it.
---@field fixed? boolean It never moves, nor does a moved tab pass it (the tab that makes a group or buys one).
---@field block? string The tabs it moves among: those of the same block, next to each other (the bank's own
--- groups and its Warbank's). A block's gap stays above whichever of its tabs is first.

---@class (exact) NextTab
---@field id number
---@field button Button
---@field text FontString
---@field icon Texture
---@field bg Texture
---@field glow Texture Lit while the tab is a drop target, and when it pulses.
---@field highlight Texture Art over its fill under the pointer or selected (Tabs.Highlight, SelectedHighlight).
---@field hovered? boolean Under the pointer.
---@field slide number How far it is slid out, in pixels.
---@field width number The width it was given (never read back from the client, which returns it with
--- float error at a UI scale).
---@field y number How far below the rail's top it is.
---@field secure boolean It is a purchase tab.
---@field accent? string|number[]
---@field tooltip? string[]|fun(owner: Button)
---@field draggable? boolean
---@field bag? boolean
---@field fixed? boolean
---@field block? string
---@field movable boolean The player can move it (the rail has a reorder handler, and it is not fixed,
--- a purchase tab or draggable).
---@field yKey table The key of its slide up or down (NextTween), apart from its hover slide.
---@field yTarget? number Where it is sliding to.

-- NextTabMove is a tab being moved; NextLift fills in where it was grabbed and its scale.
---@class NextTabMove: NextLifted
---@field tab NextTab
---@field index number Where its room is among its block's other movable tabs (before the index-th).
---@field start number Where its room was at pickup.
---@field roomY number Where the room is, down from the rail's top.

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
---@field onReorder? fun(ctx: Context, ids: number[]) Runs when a tab moved lands in a new place, with every tab's id in the new order.
---@field moving? NextTabMove The tab being moved.
---@field gaps table<string, number> Each block's gap, above its first tab.
local railProto = {}
addon:GetModule('Perf'):RegisterPrototype(railProto, 'NextTabRail')

-- step is the distance from one tab's top to the next's, for the current theme, in whole pixels on the
-- rail's grid (docs/next-pixel-perfect.md).
---@param rail NextTabRail
---@return number
local function step(rail)
  return pixel:Length(rail.frame, style.TAB_HEIGHT) + pixel:Length(rail.frame, style.TAB_SPACING)
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
  rail.gaps = {}
  rail:styleRail()
  -- A tab being moved goes back to its place when the rail hides (its panel closed).
  addon.HookScript(rail.frame, "OnHide", function()
    rail:CancelMove()
  end)
  return rail
end

-- Ordered returns the entries in the order saved (a list of tab ids), as a rail's owner lists them: in each
-- run of tabs that move among themselves (the same block, not fixed nor purchase tabs), those saved in their
-- saved order, the others after them in the order given. Fixed and purchase tabs stay where they are. The
-- list given is left alone.
---@param entries NextTabEntry[]
---@param saved? number[]
---@return NextTabEntry[]
function nextTabs:Ordered(entries, saved)
  local rank = {}
  for i, id in ipairs(saved or {}) do
    rank[id] = i
  end
  local function moves(entry)
    return not entry.fixed and entry.secure == nil
  end
  local out, i = {}, 1
  while i <= #entries do
    local entry = entries[i]
    if not moves(entry) then
      table.insert(out, entry)
      i = i + 1
    else
      local run = {}
      while i <= #entries and moves(entries[i]) and entries[i].block == entry.block do
        table.insert(run, { entry = entries[i], at = #run + 1 })
        i = i + 1
      end
      table.sort(run, function(a, b)
        local ra, rb = rank[a.entry.id], rank[b.entry.id]
        if ra ~= nil and rb ~= nil then
          return ra < rb
        end
        if ra ~= nil or rb ~= nil then
          return ra ~= nil
        end
        return a.at < b.at
      end)
      for _, r in ipairs(run) do
        table.insert(out, r.entry)
      end
    end
  end
  return out
end

-- styleRail hangs the rail below the header, past a side rail standing outside the body
-- (Header.Buttons.Rail.Outside), and sizes the bar from the theme.
---@private
function railProto:styleRail()
  local frame, body = self.frame, self.body
  frame:ClearAllPoints()
  if self.side == "LEFT" then
    pixel:Point(frame, "TOPLEFT", body, "TOPRIGHT", style.RAIL_OUT, -style.CONTENT_TOP)
  else
    pixel:Point(frame, "TOPRIGHT", body, "TOPLEFT", -style.RAIL_OUT, -style.CONTENT_TOP)
  end
  pixel:Size(frame, style.TAB_MAX_WIDTH, 1)
  local bar = style.Theme.Tabs.Indicator
  pixel:Size(self.indicator, bar and bar.Width or 0, style.TAB_HEIGHT)
  -- A bar of art or of a color, tinted by the selected tab's accent as it is selected (Select).
  if style:IsArt(bar) then
    style:Paint(self.indicator, bar)
  else
    self.indicator:SetTexCoord(0, 1, 0, 1)
    self.indicator:SetColorTexture(1, 1, 1, 1)
  end
end

-- styleTab draws a tab's parts from the theme: its height, its glow's color, its name and icon where
-- they go (its fill and font are its state's, paint).
---@private
---@param tab NextTab
function railProto:styleTab(tab)
  local button, text, icon = tab.button, tab.text, tab.icon
  pixel:Height(button, style.TAB_HEIGHT)
  local glow = style.Theme.Tabs.Glow
  if glow then
    -- A texture's alpha is its vertex color's (NextPanel:paintEdges): colored, it keeps what it shows.
    local alpha = tab.glow:GetAlpha()
    local r, g, b = style:RGBA(glow.Color)
    tab.glow:SetVertexColor(r, g, b)
    tab.glow:SetAlpha(alpha)
    tab.glow:SetBlendMode(glow.BlendMode or "ADD")
  else
    tween:Stop(tab.glow)
    tab.glow:Hide()
  end
  pixel:Size(icon, style.TAB_ICON, style.TAB_ICON)
  text:SetJustifyH(self.side == "LEFT" and "LEFT" or "RIGHT")
  self:placeContent(tab)
end

-- placeContent puts a tab's name and icon on whole pixels (docs/next-pixel-perfect.md): the name the padding
-- in from its edge side, the icon after the name's text (its width rounded up), each by its corner,
-- centered on the tab's height by its font's height and its own. Anchored by their middles they would
-- sit between two pixels on a tab an odd number of pixels tall. Its name's width changes with its text
-- and its state's font (paint), so it is placed again then.
---@private
---@param tab NextTab
function railProto:placeContent(tab)
  local button, text, icon = tab.button, tab.text, tab.icon
  -- As wide as its text in the font it has now. The client keeps the width a font string took when its text was set
  -- through a later font change and cuts text past it (Blizzard sets the width to 0 and the text again,
  -- QuestLogTitleButton_Resize; sonata.md 3c): a selected tab's font, wider by its shadow, cut "Backpack" short
  -- (reported in game).
  text:SetWidth(0)
  text:SetText(text:GetText())
  text:SetWidth(math.ceil(text:GetStringWidth()) + 1)
  local height = button:GetHeight()
  local pad, gap = pixel:Snap(button, style.TAB_PADDING), pixel:Snap(button, style.TAB_ICON_GAP)
  local _, fontHeight = text:GetFont()
  local textTop = -pixel:Floor(button, (height - (fontHeight or 0)) / 2)
  local iconTop = -pixel:Floor(button, (height - icon:GetHeight()) / 2)
  local iconX = pad + pixel:Ceil(button, text:GetStringWidth()) + gap
  text:ClearAllPoints()
  icon:ClearAllPoints()
  if self.side == "LEFT" then
    pixel:Point(text, "TOPLEFT", button, "TOPLEFT", pad, textTop)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", iconX, iconTop)
  else
    pixel:Point(text, "TOPRIGHT", button, "TOPRIGHT", -pad, textTop)
    icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -iconX, iconTop)
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

-- SetReorderHandler lets the player move the rail's tabs (docs/next-batch-2.md §5; asked: "reorderable by
-- clicking and holding to slide ... pin the X axis"): a tab pressed and moved is lifted (NextLift) and
-- follows the cursor up and down only, the other tabs of its block sliding out of its way; let go, it
-- lands in its place and fn gets every tab's id in the new order, to save it. Set before the tabs are.
---@param fn fun(ctx: Context, ids: number[])
function railProto:SetReorderHandler(fn)
  self.onReorder = fn
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
  local highlight = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  highlight:SetAllPoints()
  highlight:Hide()
  local text = style:CreateText(button, style.Theme.Tabs.Font)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:Hide()
  ---@type NextTab
  local tab = { id = 0, button = button, text = text, icon = icon, bg = bg, glow = glow, highlight = highlight, slide = 0,
    y = 0, secure = secure, movable = false, yKey = {} }
  self:styleTab(tab)
  if not secure then
    addon.SetScript(button, "OnClick", function(ctx, _, mouseButton)
      if self.onClick then
        self.onClick(ctx, tab.id, mouseButton)
      end
    end)
    addon.SetScript(button, "OnDragStart", function(ctx)
      if tab.draggable then
        if self.onDrag then
          self.onDrag(ctx, tab.id)
        end
      elseif tab.movable then
        self:BeginMove(tab)
      end
    end)
    addon.SetScript(button, "OnDragStop", function(ctx)
      if self.moving ~= nil and self.moving.tab == tab then
        self:EndMove(ctx)
      end
    end)
    addon.SetScript(button, "OnReceiveDrag", function(ctx)
      if tab.draggable and self.onDrag then
        self.onDrag(ctx, tab.id)
      end
    end)
  end
  button:SetScript("OnEnter", function()
    tab.hovered = true
    self:paint(tab)
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
    tab.hovered = false
    self:paint(tab)
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
  if self.moving ~= nil and self.moving.tab == tab then
    return
  end
  tab.button:ClearAllPoints()
  -- Whole pixels from the rail's edge (docs/next-pixel-perfect.md): sliding, it steps a pixel at a time.
  pixel:Point(tab.button, self:edge(), self.frame, self:edge(), self:outward() * tab.slide, -tab.y)
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
  tab.hovered = false
  tab.highlight:Hide()
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
  self:CancelMove()
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
  self.gaps = {}
  for i, entry in ipairs(entries) do
    local tab = self.tabs[i]
    if i > 1 then
      y = y + step(self)
    end
    y = y + pixel:Snap(self.frame, entry.gap or 0)
    if entry.block ~= nil and self.gaps[entry.block] == nil then
      self.gaps[entry.block] = entry.gap or 0
    end
    tween:Stop(tab.yKey)
    tab.yTarget = nil
    tab.id = entry.id
    tab.y = y
    tab.accent = entry.accent
    tab.tooltip = entry.tooltip
    tab.draggable = entry.draggable
    tab.bag = entry.bag
    tab.fixed = entry.fixed
    tab.block = entry.block
    tab.movable = self.onReorder ~= nil and entry.secure == nil and not entry.fixed and not entry.draggable
    if entry.secure ~= nil then
      tab.button:SetAttribute("overrideBankType", entry.secure)
    elseif entry.draggable or tab.movable then
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
      pixel:Size(tab.icon, style.TAB_ICON, style.TAB_ICON)
      tab.icon:Show()
      width = width + style.TAB_ICON + style.TAB_ICON_GAP
    else
      tab.icon:Hide()
    end
    tab.width = pixel:Ceil(tab.button, math.min(style.TAB_MAX_WIDTH, math.max(style.TAB_MIN_WIDTH, width)))
    tab.button:SetWidth(tab.width)
    self:placeContent(tab)
    self:place(tab)
    tab.button:Show()
  end
  self.frame:SetHeight(#entries > 0 and (y + step(self)) or 1)
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
  local fill = selected and T.SelectedFill or T.Fill
  if style:IsArt(fill) then
    -- Art is drawn for the backpack's tabs, sticking out to the left, and mirrored on the other panels.
    style:Paint(tab.bg, fill)
    if self.side == "LEFT" then
      local c = fill.TexCoords or { 0, 1, 0, 1 }
      tab.bg:SetTexCoord(c[2], c[1], c[3], c[4])
    end
  else
    tab.bg:SetTexCoord(0, 1, 0, 1)
    tab.bg:SetColorTexture(1, 1, 1, 1)
    local r, g, b, a = style:RGBA(fill)
    local faint = CreateColor(r, g, b, a * T.Fade)
    local solid = CreateColor(r, g, b, a)
    if self.side == "LEFT" then
      tab.bg:SetGradient("HORIZONTAL", solid, faint)
    else
      tab.bg:SetGradient("HORIZONTAL", faint, solid)
    end
  end
  -- Art over the fill: selected, or under the pointer (Blizzard's list rows: Options_List_Active, Options_List_Hover),
  -- drawn for the backpack's tabs and mirrored on the other panels, as tab art is.
  local lit = (selected and T.SelectedHighlight) or (tab.hovered and T.Highlight) or nil
  if lit then
    style:Paint(tab.highlight, lit, lit.Alpha)
    if self.side == "LEFT" then
      local c = lit.TexCoords or { 0, 1, 0, 1 }
      tab.highlight:SetTexCoord(c[2], c[1], c[3], c[4])
    end
    tab.highlight:Show()
  else
    tab.highlight:Hide()
  end
  style:SetFont(tab.text, selected and T.SelectedFont or T.Font)
  self:placeContent(tab)
end

---@private
---@param y number
function railProto:moveIndicator(y)
  self.indicatorY = y
  self.indicator:ClearAllPoints()
  pixel:Point(self.indicator, self:edge(), self.frame, self:edge(), 0, y)
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

-- BeginMove lifts a tab to move it (SetReorderHandler), unless one is already moving or another frame is
-- lifted (NextLift holds one at a time). Its x stays where it was (pinX): it moves only up and down.
---@param tab NextTab
---@return boolean
function railProto:BeginMove(tab)
  if self.moving ~= nil or lift:IsHolding() then
    return false
  end
  local index = self:blockIndexOf(tab)
  ---@type NextTabMove
  local state = { tab = tab, index = index, start = index, roomY = tab.y }
  state.pinX = lift:Cursor()
  tween:Stop(tab.yKey)
  if not lift:Pick(state, tab.button, function() self:UpdateMove() end) then
    return false
  end
  self.moving = state
  self:arrange(true)
  return true
end

-- blockIndexOf returns where a tab is among the movable tabs of its block (the first being 1).
---@private
---@param tab NextTab
---@return number
function railProto:blockIndexOf(tab)
  local n = 0
  for _, other in ipairs(self.tabs) do
    if other.movable and other.block == tab.block then
      n = n + 1
      if other == tab then
        return n
      end
    end
  end
  return n
end

-- layout returns every tab's place down the rail, the moving tab's room among its block's tabs when
-- withRoom (where it was, when its block has no other tab it can pass), a block's gap above whichever of
-- its tabs (or the room) is first; and where the room is.
---@private
---@param withRoom boolean
---@return table<NextTab, number> ys, number? roomY
function railProto:layout(withRoom)
  local state = self.moving
  local ys, roomY = {}, nil
  local y, first, seen, others = 0, true, {}, 0
  local function put(block)
    if not first then
      y = y + step(self)
    end
    first = false
    if block ~= nil and not seen[block] then
      seen[block] = true
      y = y + pixel:Snap(self.frame, self.gaps[block] or 0)
    end
    return y
  end
  local lastOfBlock
  for i, tab in ipairs(self.tabs) do
    if tab.movable and state ~= nil and tab.block == state.tab.block and tab ~= state.tab then
      lastOfBlock = i
    end
  end
  for i, tab in ipairs(self.tabs) do
    if state ~= nil and tab == state.tab then
      if not withRoom then
        ys[tab] = put(tab.block)
      elseif lastOfBlock == nil then
        roomY = put(tab.block)
      end
    else
      local inBlock = state ~= nil and tab.movable and tab.block == state.tab.block
      if withRoom and inBlock then
        others = others + 1
        if others == state.index then
          roomY = put(tab.block)
        end
      end
      ys[tab] = put(tab.block)
      if withRoom and inBlock and i == lastOfBlock and state.index > others then
        roomY = put(tab.block)
      end
    end
  end
  return ys, roomY
end

-- slideY slides a tab up or down to y (NextTween, Time.Interaction), or puts it there at once.
---@private
---@param tab NextTab
---@param y number
---@param animate boolean
function railProto:slideY(tab, y, animate)
  if not animate or tab.y == y then
    tween:Stop(tab.yKey)
    tab.yTarget = nil
    tab.y = y
    self:place(tab)
    return
  end
  if tab.yTarget == y and tween:IsPlaying(tab.yKey) then
    return
  end
  tab.yTarget = y
  tween:Play(tab.yKey, {
    duration = style.Time.Interaction,
    from = tab.y,
    to = y,
    ease = style:Ease("Glide"),
    onUpdate = function(v)
      tab.y = v
      self:place(tab)
    end,
    onDone = function()
      tab.yTarget = nil
    end,
  })
end

-- arrange puts the tabs where they go with the moving tab's room among them, sliding (animate) or at once,
-- the bar following the selected tab.
---@private
---@param animate boolean
function railProto:arrange(animate)
  local ys, roomY = self:layout(true)
  for tab, y in pairs(ys) do
    self:slideY(tab, y, animate)
  end
  self.moving.roomY = roomY
  self:followSelected(self.moving.tab.id == self.selected and roomY or nil, animate)
end

-- followSelected moves the bar to the selected tab's place (y, when given: where it is going).
---@private
---@param y? number
---@param animate boolean
function railProto:followSelected(y, animate)
  local tab = self:Tab(self.selected)
  if tab == nil or not self.indicator:IsShown() then
    return
  end
  local target = -(y or tab.yTarget or tab.y)
  if not animate then
    tween:Stop(self.indicator)
    self:moveIndicator(target)
    return
  end
  tween:Play(self.indicator, {
    duration = style.Time.Interaction,
    from = self.indicatorY,
    to = target,
    ease = style:Ease("Glide"),
    onUpdate = function(v)
      self:moveIndicator(v)
    end,
  })
end

-- moveIndexAt returns where among its block's other tabs the moving tab would land with the cursor at y:
-- before the first whose middle is below the cursor (in the rail without the moving tab), after the last
-- when none is.
---@private
---@param y number
---@return number
function railProto:moveIndexAt(y)
  local state = self.moving
  -- The cursor is on the screen; the rail is laid out in its own units (a small panel's Bag Scale).
  local at = lift:ScreenPoint(self.frame)
  if at == nil then
    return state.index
  end
  local down = (at.top - y) / at.scale
  local ys = self:layout(false)
  local index, others = nil, 0
  for _, tab in ipairs(self.tabs) do
    if tab ~= state.tab and tab.movable and tab.block == state.tab.block then
      others = others + 1
      if index == nil and down < ys[tab] + style.TAB_HEIGHT / 2 then
        index = others
      end
    end
  end
  return index or (others + 1)
end

-- UpdateMove runs a frame of a move: the tab follows the cursor up and down, the room goes where the
-- cursor is (the others sliding out of its way); once the left button is up, the tab is let go.
function railProto:UpdateMove()
  local state = self.moving
  if state == nil or state.landing then
    return
  end
  if not IsMouseButtonDown("LeftButton") then
    self:EndMove(context:New("NextTabs_Drop"))
    return
  end
  local x, y = lift:Cursor()
  lift:Place(state, x, y)
  local index = self:moveIndexAt(y)
  if index ~= state.index then
    state.index = index
    self:arrange(true)
  end
end

-- EndMove lets the moving tab go: it lands in its room (asked: "animate this transition"), then takes
-- that place (landMove).
---@param ctx Context
function railProto:EndMove(ctx)
  local state = self.moving
  if state == nil or state.landing then
    return
  end
  state.landing = true
  local tab = state.tab
  lift:Land(state, function(left0, top0)
    local at = lift:ScreenPoint(self.frame)
    if at == nil then
      return left0, top0
    end
    -- On the screen, at the rail's scale (a small panel's Bag Scale).
    local left = at.left
    if self.side ~= "LEFT" then
      left = at.left + (self.frame:GetWidth() - tab.width) * at.scale
    end
    return left, at.top - state.roomY * at.scale, at.scale
  end, function()
    self:landMove(ctx)
  end)
end

-- landMove ends a move whose tab landed: the tab goes back in the rail in its new place, the rail shows the
-- new order (each block's gap above its new first tab), and the handler gets every tab's id in it (nothing
-- for a tab back where it was).
---@private
---@param ctx Context
function railProto:landMove(ctx)
  local state = self.moving
  local moved = state.tab
  local ys = self:layout(true)
  local order, entryOf = {}, {}
  for i, tab in ipairs(self.tabs) do
    entryOf[tab] = self.entries[i]
  end
  local placeOf = {}
  for tab, y in pairs(ys) do
    placeOf[tab] = y
  end
  placeOf[moved] = state.roomY
  for _, tab in ipairs(self.tabs) do
    table.insert(order, tab)
  end
  table.sort(order, function(a, b) return placeOf[a] < placeOf[b] end)
  lift:Put(state, self.frame)
  self.moving = nil
  local entries, ids, firstOf = {}, {}, {}
  for i, tab in ipairs(order) do
    local entry = entryOf[tab]
    entries[i] = entry
    ids[i] = tab.id
    if entry and tab.block ~= nil and firstOf[tab.block] == nil then
      firstOf[tab.block] = entry
    end
  end
  for _, entry in ipairs(entries) do
    if entry.block ~= nil then
      entry.gap = firstOf[entry.block] == entry and (self.gaps[entry.block] ~= 0 and self.gaps[entry.block] or nil) or nil
    end
  end
  self.tabs, self.entries = order, entries
  for _, tab in ipairs(order) do
    self:slideY(tab, placeOf[tab], false)
  end
  if state.index ~= state.start and self.onReorder then
    self.onReorder(ctx, ids)
  end
end

-- CancelMove puts a tab being moved straight back in its place, telling nothing.
function railProto:CancelMove()
  local state = self.moving
  if state == nil then
    return
  end
  lift:Put(state, self.frame)
  self.moving = nil
  local ys = self:layout(false)
  for tab, y in pairs(ys) do
    self:slideY(tab, y, false)
  end
  self:followSelected(nil, false)
end
