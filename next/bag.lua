local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class CursorPlacement: AceModule
local cursorPlacement = addon:GetModule('CursorPlacement')

---@class BackpackBehavior: AceModule
local backpackBehavior = addon:GetModule('BackpackBehavior')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Scrollbox: AceModule
local scrollbox = addon:GetModule('Scrollbox')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextSparkles: AceModule
local sparkles = addon:GetModule('NextSparkles')

---@class NextTabs: AceModule
local nextTabs = addon:GetModule('NextTabs')

---@class NextContent: AceModule
local nextContent = addon:GetModule('NextContent')

-- NextBag is BetterBagsNext's backpack (next.md): a full-height panel that slides in from the
-- right edge of the screen, its left edge feathered out to nothing, with the title and its
-- sparkles, a search box, the group tabs down its left side and the content in one column. It
-- stands in for the backpack everywhere the addon talks to it (next.md §1).
---@class NextBag: AceModule
local nextBag = addon:NewModule('NextBag')

-- The ribbon running left from the title, out of the window.
local RIBBON_LENGTH = 300
-- The ribbon's glow: thin lines above and below it, fainter the further out.
local RIBBON_GLOW = { { 0, 0.9 }, { 2, 0.35 }, { -2, 0.35 }, { 4, 0.15 }, { -4, 0.15 }, { 6, 0.06 }, { -6, 0.06 } }

---@class NextBackpack
---@field kind BagKind
---@field frame Frame The panel.
---@field body Frame The opaque part, right of the feathered edge.
---@field feather Texture
---@field title FontString
---@field ribbon Texture The ribbon's brightest line.
---@field spark Texture What sweeps along the ribbon.
---@field sortButton Button
---@field settingsButton Button
---@field searchBox SearchFrame
---@field scroll ScrollboxDrawable
---@field content NextCanvas
---@field root Drawable
---@field tabs NextTabRail
---@field moneyFrame Money
---@field freeText FontString
---@field emptyText FontString Shown while the tab holds nothing.
---@field sparkles NextSparkleEmitter Around the title's ribbon.
---@field edgeSparkles NextSparkleEmitter Along the feathered edge.
---@field behavior {SwitchToGroup: fun(self: any, ctx: Context, id: number)}
---@field helper BackpackBehaviorProto The classic behavior, for its group dialogs.
---@field offset number How far right of its place the panel is.
---@field closing boolean It is sliding out.
---@field opening boolean It is drawing as it opens.
---@field tabChanged boolean The next draw shows another tab.
---@field drawOnClose boolean
---@field drawPendingOnShow boolean
---@field lastSlotInfo? SlotInfo
---@field drawnButtons table<Item, boolean>
---@field claims? table<Item, boolean>
---@field loaded boolean
local bagProto = {}
addon:GetModule('Perf'):RegisterPrototype(bagProto, 'NextBackpack')

-- The panel's render root: it hands the scroll box the content's width and the height between
-- the header and the footer.
local rootProto = drawable:Extend({}, 'NextPanel')

---@return RenderPlan
function rootProto:GetRenderPlan()
  return { Plan = { { step = render.PRE }, { step = render.DEP, target = self.bag.scroll }, { step = render.SELF } } }
end

---@return RenderResult
function rootProto:PreRender()
  return {
    Width = style.GRID_WIDTH + style.GUTTER,
    Height = math.max(1, UIParent:GetHeight() - style.CONTENT_TOP - style.FOOTER),
  }
end

---@return RenderResult
function rootProto:Render()
  return { Width = style.WIDTH, Height = UIParent:GetHeight() }
end

---@param ctx Context
---@return NextBackpack
function nextBag:Create(ctx)
  ---@type NextBackpack
  local b = setmetatable({}, { __index = bagProto })
  b.kind = const.BAG_KIND.BACKPACK
  b.offset = 0
  b.closing = false
  b.opening = false
  b.tabChanged = false
  b.drawOnClose = false
  b.drawPendingOnShow = false
  b.drawnButtons = {}
  b:BuildPanel()
  b:BuildSearch()
  b:BuildHeader()
  b:BuildContent()
  b:BuildFooter()
  b:BuildSparkles()
  b.helper = backpackBehavior:Create(b)
  b.behavior = {
    SwitchToGroup = function(_, ectx, id)
      b:SwitchToGroup(ectx, id)
    end,
  }
  b:BuildTabs()
  b:Watch()
  local _ = ctx
  return b
end

---@private
---@param x number
function bagProto:setOffset(x)
  self.offset = x
  local frame = self.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, 0)
  frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x, 0)
end

-- BuildPanel makes the panel: full height on the right edge of the screen, its body a deep
-- indigo with a faint wash of lavender at the top, its left edge feathered out to nothing.
function bagProto:BuildPanel()
  local frame = CreateFrame("Frame", "BetterBagsNextBackpack", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetFrameLevel(500)
  frame:SetToplevel(true)
  frame:SetWidth(style.WIDTH)
  frame:EnableMouse(true)
  frame:SetHitRectInsets(style.FEATHER, 0, 0, 0)
  frame:Hide()
  self.frame = frame
  self:setOffset(0)

  local body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", frame, "TOPLEFT", style.FEATHER, 0)
  body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  self.body = body

  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetPoint("TOPLEFT", frame, "TOPLEFT", style.FEATHER, 0)
  fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", style.OVERREACH, 0)
  fill:SetColorTexture(unpack(style.Color.Body))

  local feather = frame:CreateTexture(nil, "BACKGROUND")
  feather:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  feather:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  feather:SetWidth(style.FEATHER)
  feather:SetColorTexture(1, 1, 1, 1)
  feather:SetGradient("HORIZONTAL", style:CreateColor("Body", 0), style:CreateColor("Body"))
  self.feather = feather

  local wash = frame:CreateTexture(nil, "BORDER")
  wash:SetPoint("TOPLEFT", frame, "TOPLEFT", style.FEATHER, 0)
  wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", style.OVERREACH, 0)
  wash:SetHeight(260)
  wash:SetColorTexture(1, 1, 1, 1)
  wash:SetGradient("VERTICAL", style:CreateColor("Wash", 0), style:CreateColor("Wash"))
  wash:SetBlendMode("ADD")
end

---@private
---@param atlas string
---@param tooltip string
---@param onClick fun(ctx: Context)
---@return Button
function bagProto:headerButton(atlas, tooltip, onClick)
  local button = CreateFrame("Button", nil, self.frame)
  button:SetSize(22, 22)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetAtlas(atlas)
  icon:SetVertexColor(0.85, 0.82, 1, 1)
  button:SetScript("OnEnter", function()
    icon:SetVertexColor(1, 1, 1, 1)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    icon:SetVertexColor(0.85, 0.82, 1, 1)
    GameTooltip:Hide()
  end)
  addon.SetScript(button, "OnClick", function(ctx)
    onClick(ctx)
  end)
  return button
end

-- BuildHeader makes the title, the ribbon running left from it out of the window (a thin gold
-- line with a soft glow, fading out to the left) and the spark that sweeps along it, and the sort
-- and settings buttons.
function bagProto:BuildHeader()
  local frame, body = self.frame, self.body
  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(style:Font("Title"))
  title:SetPoint("TOPLEFT", body, "TOPLEFT", style.PAD + 4, -style.TITLE_TOP)
  title:SetText(L:G("Backpack"))
  self.title = title

  for _, glow in ipairs(RIBBON_GLOW) do
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("RIGHT", title, "LEFT", -10, glow[1])
    line:SetSize(RIBBON_LENGTH, 2)
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", style:CreateColor("Gold", 0), style:CreateColor("Gold", glow[2]))
    line:SetBlendMode("ADD")
    if glow[1] == 0 then
      self.ribbon = line
    end
  end

  local spark = frame:CreateTexture(nil, "OVERLAY")
  spark:SetTexture(style.SPARKLE_TEXTURE)
  spark:SetBlendMode("ADD")
  spark:SetVertexColor(unpack(style.Color.Gold))
  spark:SetSize(26, 26)
  spark:SetPoint("CENTER", self.ribbon, "RIGHT", 0, 0)
  spark:SetAlpha(0)
  self.spark = spark

  self.settingsButton = self:headerButton("GM-icon-settings", L:G("Open Options Screen"), function(ctx)
    events:SendMessage(ctx, "config/Open")
  end)
  self.settingsButton:SetPoint("TOPRIGHT", body, "TOPRIGHT", -style.PAD, -(style.TITLE_TOP + 3))
  self.sortButton = self:headerButton("bags-button-autosort-up", L:G("Sort Bags"), function(ctx)
    self:Sort(ctx)
  end)
  self.sortButton:SetPoint("RIGHT", self.settingsButton, "LEFT", -8, 0)
end

-- BuildSearch takes the backpack's in-bag search box (the data phase reads its query,
-- searchBox:GetSearchText) out of the theme's hands and draws it flat: a soft pill and a fading
-- underline instead of the template's border.
function bagProto:BuildSearch()
  local sf = searchBox:CreateBox(self.kind, self.frame)
  sonata:UnregisterElement("SearchBox", sf.textBox)
  sf.frame:ClearAllPoints()
  sf.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", style.PAD, -style.SEARCH_TOP)
  sf.frame:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -style.PAD, -style.SEARCH_TOP)
  sf.frame:SetHeight(style.SEARCH_HEIGHT)
  for _, key in ipairs({ "Left", "Middle", "Right" }) do
    if sf.textBox[key] then
      sf.textBox[key]:SetAlpha(0)
    end
  end
  local pill = sf.frame:CreateTexture(nil, "BACKGROUND")
  pill:SetAllPoints()
  pill:SetColorTexture(1, 1, 1, 1)
  pill:SetGradient("HORIZONTAL", style:CreateColor("TabSelected", 0.55), style:CreateColor("Tab", 0.35))
  local underline = sf.frame:CreateTexture(nil, "BORDER")
  underline:SetPoint("BOTTOMLEFT", sf.frame, "BOTTOMLEFT", 0, 0)
  underline:SetPoint("BOTTOMRIGHT", sf.frame, "BOTTOMRIGHT", 0, 0)
  underline:SetHeight(1)
  underline:SetColorTexture(1, 1, 1, 1)
  underline:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.5), style:CreateColor("Lavender", 0))
  self.searchBox = sf
  self:UpdateSearchShown()
end

-- UpdateSearchShown shows the search box while in-bag search is on, as the classic bag does.
function bagProto:UpdateSearchShown()
  self.searchBox.frame:SetShown(database:GetInBagSearch() and true or false)
end

-- BuildContent makes the scroll box between the header and the footer and the canvas it holds.
function bagProto:BuildContent()
  local scroll = scrollbox:Create(self.frame, "BetterBagsNextScroll", { Symmetric = true, AutoHideBar = true })
  scroll.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", style.PAD, -style.CONTENT_TOP)
  scroll.frame:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", -style.PAD, style.FOOTER)
  self.scroll = scroll
  self.content = nextContent:Create(scroll.scrollChild)
  scroll:SetChild(self.content)
  self.root = drawable:Create(rootProto, { frame = self.frame, bag = self })

  local emptyText = self.frame:CreateFontString(nil, "OVERLAY")
  emptyText:SetFontObject(style:Font("Footer"))
  emptyText:SetPoint("TOP", scroll.frame, "TOP", 0, -40)
  emptyText:SetText(L:G("Nothing here yet"))
  emptyText:Hide()
  self.emptyText = emptyText
end

-- BuildFooter puts the free slots on the left and the money on the right, under a fading line.
function bagProto:BuildFooter()
  local body = self.body
  local line = self.frame:CreateTexture(nil, "ARTWORK")
  line:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", style.PAD, style.FOOTER - 4)
  line:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -style.PAD, style.FOOTER - 4)
  line:SetHeight(1)
  line:SetColorTexture(1, 1, 1, 1)
  line:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.35), style:CreateColor("Lavender", 0.05))

  local freeText = self.frame:CreateFontString(nil, "OVERLAY")
  freeText:SetFontObject(style:Font("Footer"))
  freeText:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", style.PAD + 4, 14)
  self.freeText = freeText

  local m = money:Create()
  m.frame:SetParent(self.frame)
  m.frame:ClearAllPoints()
  m.frame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -style.PAD, 12)
  self.moneyFrame = m
end

-- BuildSparkles makes the two emitters: one around the title's ribbon, one along the feathered
-- edge, both drifting left out of the window.
function bagProto:BuildSparkles()
  local fx = CreateFrame("Frame", nil, self.frame)
  fx:SetAllPoints(self.frame)
  fx:SetFrameLevel(self.frame:GetFrameLevel() + 50)
  local titleLeft = style.FEATHER + style.PAD + 4 - 10
  local titleMiddle = -(style.TITLE_TOP + 13)
  self.sparkles = sparkles:Create(fx, {
    Rate = 8, Max = 28, Life = { 2.0, 3.6 }, Size = { 6, 15 }, Speed = { 22, 64 }, Rise = { -8, 10 },
    Wobble = 4, Spin = 1.5,
    Spawn = function()
      return titleLeft - math.random() * 70, titleMiddle + (math.random() * 2 - 1) * 8
    end,
  })
  self.edgeSparkles = sparkles:Create(fx, {
    Rate = 2.5, Max = 12, Life = { 2.4, 4.2 }, Size = { 4, 9 }, Speed = { 14, 36 }, Rise = { -6, 6 },
    Wobble = 3, Spin = 1, Alpha = 0.6,
    Spawn = function()
      return style.FEATHER - math.random() * 24, -math.random() * fx:GetHeight()
    end,
  })
end

-- BuildTabs makes the tab rail down the body's left edge.
function bagProto:BuildTabs()
  self.tabs = nextTabs:Create(self.body)
  self.tabs:SetClickHandler(function(ctx, id, button)
    self:OnTabClicked(ctx, id, button)
  end)
  self:RefreshTabs()
end

-- RefreshTabs lists the backpack's groups as tabs, in their order, with a last one to make a
-- group, and selects the active one. With groups off there are no tabs.
function bagProto:RefreshTabs()
  if not database:GetGroupsEnabled(self.kind) then
    self.tabs.frame:Hide()
    return
  end
  local entries = {}
  for id, group in pairs(groups:GetAllGroups(self.kind)) do
    table.insert(entries, { id = id, name = group.name })
  end
  table.sort(entries, function(a, b) return a.id < b.id end)
  table.insert(entries, {
    id = 0,
    name = "+",
    tooltip = { L:G("New Group..."), L:G("Click to create a new group for organizing categories.") },
  })
  self.tabs:SetTabs(entries)
  self.tabs:Select(self:GetCurrentTabID())
  self.tabs.frame:Show()
end

-- OnTabClicked switches group on a left click, opens a group's menu on a right click (not the
-- Backpack group's), and opens the new group dialog from the last tab.
---@param ctx Context
---@param id number
---@param button string
function bagProto:OnTabClicked(ctx, id, button)
  if id == 0 then
    self.helper:ShowCreateGroupDialog()
    return
  end
  if button == "RightButton" then
    if id ~= 1 then
      self.helper:ShowGroupContextMenu(ctx, id)
    end
    return
  end
  self:SwitchToGroup(ctx, id)
end

-- SwitchToGroup shows a group: the same data, drawn for its tab, fading in.
---@param ctx Context
---@param id number
function bagProto:SwitchToGroup(ctx, id)
  if groups:GetGroup(self.kind, id) == nil then
    return
  end
  database:SetActiveGroup(self.kind, id)
  self.tabs:Select(id, true)
  self.tabChanged = true
  self:Draw(ctx, items:GetAllSlotInfo()[self.kind], function() end)
  addon.TriggerItemContextChanged()
end

---@return number
function bagProto:GetCurrentTabID()
  if database:GetGroupsEnabled(self.kind) then
    return database:GetActiveGroup(self.kind) or 1
  end
  return 1
end

-- Watch wires the panel to the rest of the addon: its show and hide, cooldowns, drops, the
-- groups and the in-bag search setting.
function bagProto:Watch()
  local frame = self.frame
  addon.SetScript(frame, "OnShow", function(ctx)
    self:OnCooldown(ctx)
  end)
  addon.SetScript(frame, "OnHide", function(ctx)
    self:OnHidden(ctx)
  end)
  addon.SetScript(frame, "OnReceiveDrag", function()
    self:PlaceCursorItem()
  end)
  addon.SetScript(frame, "OnMouseUp", function(_, _, button)
    if button == "LeftButton" then
      self:PlaceCursorItem()
    end
  end)
  events:BucketEvent("BAG_UPDATE_COOLDOWN", function(ctx)
    self:OnCooldown(ctx)
  end, function()
    return self:IsShown()
  end)
  events:RegisterMessage("groups/Created", function(_, group)
    if group.kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("groups/Changed", function(_, _, _, _, kind)
    if kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("groups/Deleted", function(ctx, groupID, _, kind)
    if kind ~= self.kind then
      return
    end
    if database:GetActiveGroup(self.kind) == groupID then
      self:SwitchToGroup(ctx, 1)
    end
    self:RefreshTabs()
  end)
  events:RegisterMessage("groups/EnabledChanged", function(_, kind)
    if kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("search/SetInFrame", function(ctx)
    self:UpdateSearchShown()
    events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
  end)
end

---@private
function bagProto:playShimmer()
  local spark = self.spark
  tween:Play(spark, {
    duration = style.Time.Shimmer,
    delay = style.Time.ShimmerEvery - style.Time.Shimmer,
    from = 0,
    to = 1,
    ease = "inOutSine",
    onUpdate = function(t)
      spark:ClearAllPoints()
      spark:SetPoint("CENTER", self.ribbon, "RIGHT", -t * RIBBON_LENGTH, 0)
      spark:SetAlpha(math.sin(math.pi * t))
    end,
    onDone = function()
      if self.frame:IsShown() and not self.closing then
        self:playShimmer()
      end
    end,
  })
end

-- Show slides the panel in from the right, drawing a draw it kept while hidden (with slotInfo
-- when given), fading its sections in and starting its sparkles. It returns whether it drew.
---@param ctx Context
---@param slotInfo? SlotInfo
---@return boolean drew
function bagProto:Show(ctx, slotInfo)
  if self.frame:IsShown() and not self.closing then
    return false
  end
  local sliding = self.frame:IsShown()
  self.closing = false
  PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
  local from = sliding and self.offset or (style.WIDTH + style.OVERREACH)
  self:setOffset(from)
  self.frame:Show()
  local drew = false
  if self.drawPendingOnShow then
    self.drawPendingOnShow = false
    local data = slotInfo or self.lastSlotInfo
    if data then
      self.opening = true
      self:Draw(ctx, data, function() end)
      self.opening = false
      drew = true
    end
  end
  tween:Play(self, {
    duration = style.Time.Open,
    from = from,
    to = 0,
    ease = "outBack",
    onUpdate = function(x)
      self:setOffset(x)
    end,
  })
  self.content:Cascade(true, style.Time.OpenCascadeDelay)
  self.sparkles:Start()
  self.edgeSparkles:Start()
  self:playShimmer()
  addon.TriggerItemContextChanged()
  return drew
end

-- Hide slides the panel out to the right, then hides it.
---@param ctx Context
function bagProto:Hide(ctx)
  if not self.frame:IsShown() or self.closing then
    return
  end
  local _ = ctx
  addon.ForceHideBlizzardBags()
  PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
  self.closing = true
  tween:Play(self, {
    duration = style.Time.Close,
    from = self.offset,
    to = style.WIDTH + style.OVERREACH,
    ease = "inCubic",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self.closing = false
      self.frame:Hide()
      addon.TriggerItemContextChanged()
    end,
  })
end

---@param ctx Context
function bagProto:Toggle(ctx)
  if self:IsShown() and not self.closing then
    self:Hide(ctx)
  else
    self:Show(ctx)
  end
end

---@return boolean
function bagProto:IsShown()
  return self.frame:IsShown()
end

---@return string
function bagProto:GetName()
  return self.frame:GetName()
end

---@param text string
function bagProto:SetTitle(text)
  self.title:SetText(text)
end

-- OnHidden runs on every way the panel hides (the slide's end, Escape hiding it at once): the
-- slide, the sparkles and the spark stop, and OnClosed runs.
---@param ctx Context
function bagProto:OnHidden(ctx)
  self.closing = false
  tween:Stop(self)
  tween:Stop(self.spark)
  self.spark:SetAlpha(0)
  self.sparkles:Stop()
  self.edgeSparkles:Stop()
  self:OnClosed(ctx)
end

-- OnClosed expires Recent Items, and recalculates once when any expired or gaps are held, while
-- the panel is hidden (recent-items.md §3). A hide while the panel is still shown (a parent hid)
-- does nothing.
---@param ctx Context
function bagProto:OnClosed(ctx)
  if self.frame:IsShown() then
    return
  end
  local expired = items:ExpireRecentItems(self.kind)
  if expired or self.drawOnClose then
    self.drawOnClose = false
    self:Refresh(ctx)
  end
end

-- Draw binds the active tab's data and lays it out, claiming the buttons it draws and releasing
-- the ones the last draw drew that this one did not. A draw while hidden waits for Show.
---@param ctx Context
---@param slotInfo SlotInfo
---@param callback? fun()
function bagProto:Draw(ctx, slotInfo, callback)
  if not self.frame:IsShown() then
    self.lastSlotInfo = slotInfo
    self.drawPendingOnShow = true
    if callback then
      callback()
    end
    return
  end
  if self.claims then
    for item in pairs(self.claims) do
      self.drawnButtons[item] = true
    end
  end
  local claims = {}
  self.claims = claims
  self.content:Bind(ctx, slotInfo, self:GetCurrentTabID(), claims)
  for item in pairs(self.drawnButtons) do
    if not claims[item] then
      item:Release(ctx)
    end
  end
  self.drawnButtons = claims
  self.claims = nil
  self.lastSlotInfo = slotInfo
  render:RenderNow(self.root, { ctx = ctx })
  self.freeText:SetText(format(L:G("%d free slots"), self.content.freeTotal))
  self.emptyText:SetShown(#self.content.order == 0)
  if not self.opening then
    self.content:Cascade(self.tabChanged)
  end
  self.tabChanged = false
  if callback then
    callback()
  end
end

-- Refresh recalculates the backpack from what was last read.
---@param ctx Context
function bagProto:Refresh(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = false })
end

---@param ctx Context
---@param results table<string, boolean>
function bagProto:Search(ctx, results)
  for slotkey, button in pairs(self.content.buttons) do
    if not button.isFreeSlot then
      button:UpdateSearch(ctx, results[slotkey])
    end
  end
end

---@param ctx Context
function bagProto:ResetSearch(ctx)
  for _, button in pairs(self.content.buttons) do
    if not button.isFreeSlot then
      button:UpdateSearch(ctx, true)
    end
  end
end

-- ToggleSearch opens the panel and puts the cursor in its search box, or lets go of the box.
---@param ctx Context
function bagProto:ToggleSearch(ctx)
  local textBox = self.searchBox.textBox
  if self:IsShown() and not self.closing and textBox:HasFocus() then
    textBox:ClearFocus()
    return
  end
  self:Show(ctx)
  if self.searchBox.frame:IsShown() then
    textBox:SetFocus()
  end
end

-- OnCooldown refreshes the cooldown of every item button it shows, and returns how many it
-- checked and how many it applied Blizzard's update to.
---@param ctx Context
---@return number checked, number applied
function bagProto:OnCooldown(ctx)
  if not self:IsShown() then
    return 0, 0
  end
  local checked, applied = 0, 0
  for _, button in pairs(self.content.buttons) do
    local data = not button.isFreeSlot and button:GetItemData() or nil
    if data then
      checked = checked + 1
      local reason = button:UpdateCooldown(ctx, data, true)
      if reason ~= "unchanged" and reason ~= "empty" then
        applied = applied + 1
      end
    end
  end
  return checked, applied
end

---@param ctx Context
function bagProto:Sort(ctx)
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  events:SendMessage(ctx, "bags/SortBackpack")
end

-- PlaceCursorItem puts the item on the cursor into a free slot of the backpack.
---@return string result What CursorPlacement:PlaceCursorItem did.
function bagProto:PlaceCursorItem()
  return cursorPlacement:PlaceCursorItem(self.kind)
end

-- Wipe tears the drawing down: every section and every button drawn is released.
---@param ctx Context
function bagProto:Wipe(ctx)
  self.content:Release()
  for _, drawn in ipairs({ self.drawnButtons, self.claims or {} }) do
    for item in pairs(drawn) do
      item:Release(ctx)
    end
  end
  self.drawnButtons = {}
  self.claims = nil
end
