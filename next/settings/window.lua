local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Scrollbox: AceModule
local scrollbox = addon:GetModule('Scrollbox')

---@class SettingsCatalog: AceModule
local catalog = addon:GetModule('SettingsCatalog')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextScrollBar: AceModule
local nextScrollBar = addon:GetModule('NextScrollBar')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class NextMenu: AceModule
local nextMenu = addon:GetModule('NextMenu')

---@class NextTopTabs: AceModule
local nextTopTabs = addon:GetModule('NextTopTabs')

---@class NextDialog: AceModule
local nextDialog = addon:GetModule('NextDialog')

---@class NextSettingsRows: AceModule
local rows = addon:GetModule('NextSettingsRows')

---@class NextSettingsPage: AceModule
local nextPage = addon:GetModule('NextSettingsPage')

---@class NextSettingsPages: AceModule
local pages = addon:GetModule('NextSettingsPages')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSettings is BetterBags Next's settings window (next-settings.md §3), drawn from the Next theme
-- (Settings): the sidebar (the brand, a search box, the pages of NextSettingsPages under their
-- headings, the version), a page's header (its title and description; the close button), its tabs
-- when it has more than one, its sections scrolling in the content (NextSettingsPage), and the footer
-- (What's New, Done). It is built the first time it opens, centered, shrunk to fit a small screen,
-- moved by its header, and closed with Escape (the controls' Escape stack: a menu or a dialog open
-- over it closes first). It comes and goes as a detached Next bag does: sliding a short way in from
-- the right as it fades in, and out again as it fades out; Escape closes it at once, as it does a bag. It shows the page and tab it showed last this session. Typing in the
-- search box lists every setting that matches as live rows under their page and tab. A page with its
-- own list (the Categories page) slides the pages out of the sidebar and its list in, Back on top
-- (the first Escape goes back too), with its heading and buttons in the header.
---@class NextSettings: AceModule
---@field frame? Frame
---@field root Drawable
---@field scroll ScrollboxDrawable
---@field page NextSettingsPageFrame The page shown.
---@field cache table<NextSettingsPageDef, table<string, NextSettingsPageFrame>>
---@field results NextSettingsPageFrame
---@field resultRows table<string, NextSettingsRow>
---@field navRows table[]
---@field pageId? string
---@field tabId? string
---@field query? string
---@field shown boolean Open: shown and not fading out.
---@field closing boolean Fading out.
---@field offset number How far right of where it rests it is, as it slides.
---@field motion table The slide's tween key.
---@field sidebarPage? NextSettingsPageDef The page whose own list the sidebar shows.
---@field returnTo? {pageId: string, tabId: string} Where Back goes.
---@field shift number How far the sidebar has slid to a page's own list, from 0 (the pages) to 1.
---@field shiftMotion table The sidebar slide's tween key.
---@field lists table<NextSettingsPageDef, NextSettingsSidebar>
---@field actionsOf table<NextSettingsPageDef, NextSettingsActions>
---@field actions? NextSettingsActions The buttons in the header now.
---@field backKeyHeld boolean The frame the first Escape hides holds Escape.
---@field arriving boolean The window is coming in (Open is showing a page).
local settings = addon:NewModule('NextSettings')

-- The share of the screen the window takes at most.
local SCREEN_SHARE = 0.95

-- The window's render root: it hands its scroll box the content's width and height.
local rootProto = drawable:Extend({}, 'NextSettingsRoot')

---@return RenderPlan
function rootProto:GetRenderPlan()
  return { Plan = { { step = render.PRE }, { step = render.DEP, target = self.settings.scroll }, { step = render.SELF } } }
end

---@return RenderResult
function rootProto:PreRender()
  local s = self.settings
  return { Width = s.scroll.frame:GetWidth(), Height = math.max(1, s:ContentHeight()) }
end

---@return RenderResult
function rootProto:Render()
  return { Width = self.frame:GetWidth(), Height = self.frame:GetHeight() }
end

-- Init starts a session: nothing built, no page shown yet.
function settings:Init()
  if self.frame ~= nil then
    self.frame:Hide()
  end
  self.frame = nil
  self.page = nil
  self.cache = {}
  self.resultRows = {}
  self.navRows = {}
  self.pageId, self.tabId, self.query = nil, nil, nil
  self.shown = false
  self.closing = false
  self.offset = 0
  self.motion = {}
  self.sidebarPage, self.returnTo, self.actions = nil, nil, nil
  self.backKeyHeld, self.arriving = false, false
  self.shift = 0
  self.shiftMotion = {}
  self.lists = {}
  self.actionsOf = {}
end

settings:Init()

-- Open shows the window on a page (and tab) when given, else the one it showed last.
---@param pageId? string
---@param tabId? string
function settings:Open(pageId, tabId)
  self:build()
  local frame = self.frame
  if not frame:IsShown() then
    local T = style.Theme.Settings
    local scale = math.min(1, UIParent:GetWidth() * SCREEN_SHARE / T.Width, UIParent:GetHeight() * SCREEN_SHARE / T.Height)
    frame:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:anchorSlide()
    self:setOffset(style.Small.Slide)
  end
  local coming = self.closing or not frame:IsShown()
  self.closing = false
  self:buildNav()
  frame:Show()
  self.shown = true
  controls:PushEscape(frame)
  -- Coming in, a page's own list is in place at once: the window slides as a whole.
  self.arriving = coming
  self:Select(pageId or self.pageId, tabId or (pageId == nil and self.tabId or nil))
  self.arriving = false
  if coming then
    tween:Play(self.motion, {
      duration = style.Time.Open,
      ease = style:Ease("SmallOpen"),
      from = self.offset,
      to = 0,
      onUpdate = function(x) self:setOffset(x) end,
    })
  end
end

-- anchorSlide keeps where the window is (centered, or where it was moved) as the place it slides from.
---@private
function settings:anchorSlide()
  local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(1)
  self.slideFrom = { point or "CENTER", relativeTo or UIParent, relativePoint or "CENTER", (x or 0) - self.offset, y or 0 }
end

-- setOffset puts the window x right of where it rests, as faded as a detached bag that far from its
-- place (next/panel.lua setOffset).
---@private
---@param x number
function settings:setOffset(x)
  self.offset = x
  local a = self.slideFrom
  local frame = self.frame
  frame:ClearAllPoints()
  frame:SetPoint(a[1], a[2], a[3], a[4] + x, a[5])
  frame:SetAlpha(1 - math.min(1, math.abs(x) / style.Small.Slide))
end

---@return boolean
function settings:IsShown()
  return self.frame ~= nil and self.shown
end

-- Close fades the window out, sliding right, then hides it. It is closed from the start: what is open
-- over it closes, and the page it shows is left.
function settings:Close()
  if self.frame == nil or not self.shown then
    return
  end
  self:ended()
  self.closing = true
  self:anchorSlide()
  tween:Play(self.motion, {
    duration = style.Time.Close,
    ease = style:Ease("SmallClose"),
    from = self.offset,
    to = style.Small.Slide,
    onUpdate = function(x) self:setOffset(x) end,
    onDone = function()
      self.frame:Hide()
      self:hidden()
    end,
  })
end

-- ended ends the window's showing: the menu and dialog over it close, its page is left.
---@private
function settings:ended()
  if not self.shown then
    return
  end
  self.shown = false
  -- Escape's first press goes back only while the window shows: a hidden key frame still shown would
  -- take Escape from the game (CloseSpecialWindows reads IsShown).
  self:releaseBackKey()
  if self.page ~= nil then
    self.page:Leave(context:New('NextSettings_Hidden'))
  end
  nextMenu:Close()
  if nextDialog:IsShown() then
    nextDialog:Hide()
  end
end

-- hidden runs however the window hid (its fade ended, Escape hid it at once): its showing ends, its
-- slide stops, and it is back in place and at full strength for the next time.
---@private
function settings:hidden()
  self:ended()
  self.closing = false
  tween:Stop(self.motion)
  self.offset = 0
  self.frame:SetAlpha(1)
  controls:ReleaseEscape(self.frame)
end

-- build makes the window, the first time it opens.
---@private
function settings:build()
  if self.frame ~= nil then
    return
  end
  local frame = CreateFrame("Frame", "BetterBagsNextSettings", UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:Hide()
  self.frame = frame
  self.fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  self.fill:SetAllPoints(frame)
  self.wash = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  self.wash:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  self.wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  self.edge = controls:CreateEdge(frame, "BORDER", 2)

  self:buildSidebar()
  self:buildHeader()
  self:buildContent()
  self:buildFooter()

  self.root = drawable:Create(rootProto, { frame = frame, settings = self })
  addon.SetScript(frame, "OnHide", function() self:hidden() end)
  sonataNext:RegisterWidget(self)
  self:Style()
end

---@private
function settings:buildSidebar()
  local frame = self.frame
  local sidebar = CreateFrame("Frame", nil, frame)
  sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  -- The pages and a page's own list slide past each other inside it.
  sidebar:SetClipsChildren(true)
  self.sidebar = sidebar
  self.sidebarFill = sidebar:CreateTexture(nil, "BACKGROUND", nil, -7)
  self.sidebarFill:SetAllPoints(sidebar)
  self.sidebarLine = sidebar:CreateTexture(nil, "BORDER")
  self.sidebarLine:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
  self.sidebarLine:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
  -- The brand's row: dragging it moves the window, as the header does. It stays as the panels slide.
  local brand = CreateFrame("Frame", nil, sidebar)
  brand:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
  brand:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
  self:makeMover(brand)
  self.brand = brand
  -- The pages: the brand, the search box, the pages, the version.
  local navPanel = CreateFrame("Frame", nil, sidebar)
  self.navPanel = navPanel
  self.brandIcon = navPanel:CreateTexture(nil, "ARTWORK")
  self.brandText = style:CreateText(navPanel, style.Theme.Settings.Brand.Font)
  self.brandText:SetText(L:G("BetterBags"))
  self.brandLine = navPanel:CreateTexture(nil, "ARTWORK")
  self:buildListPanel()
  self.search = nextInput:Create(navPanel, {
    help = L:G("Search settings"),
    onChange = function(ctx, text) self:Search(ctx, text) end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  addon.HookScript(self.search.frame, "OnEscapePressed", function(ctx) self:Search(ctx, "") end)
  local navBox = CreateFrame("Frame", nil, navPanel, "WowScrollBox") --[[@as WowScrollBox]]
  navBox:SetInterpolateScroll(true)
  local navList = CreateFrame("Frame", nil, navBox)
  navList.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(28)
  navBox:Init(view)
  self.navBar = nextScrollBar:Create(navBox)
  self.navBar:Bind(navBox)
  self.navBox, self.navList = navBox, navList
  self.version = style:CreateText(navPanel, style.Theme.Settings.Version.Font)
  self.version:SetText(self:VersionText())
end

-- buildListPanel makes the panel a page's own list slides in on: Back in the brand's row (above the
-- brand's mover), its line, and the place the list goes; and the frame Escape hides first while it
-- shows, which goes back.
---@private
function settings:buildListPanel()
  local panel = CreateFrame("Frame", nil, self.sidebar)
  panel:Hide()
  self.listPanel = panel
  local back = CreateFrame("Button", nil, panel)
  back:RegisterForClicks("LeftButtonUp")
  back:SetFrameLevel(self.brand:GetFrameLevel() + 5)
  self.back = back
  self.backIcon = back:CreateTexture(nil, "ARTWORK")
  self.backLabel = style:CreateText(back, style.Theme.Settings.Back.Font)
  self.backLabel:SetText(L:G("All Settings"))
  self.backLine = panel:CreateTexture(nil, "ARTWORK")
  addon.SetScript(back, "OnClick", function(ctx) self:Back(ctx) end)
  addon.SetScript(back, "OnEnter", function() style:SetFont(self.backLabel, style.Theme.Settings.Back.HoverFont) end)
  addon.SetScript(back, "OnLeave", function() style:SetFont(self.backLabel, style.Theme.Settings.Back.Font) end)
  self.listHost = CreateFrame("Frame", nil, panel)
  local key = CreateFrame("Frame", "BetterBagsNextSettingsBack", self.frame)
  key:Hide()
  -- Escape hid it (its own flag is off) while the window shows: go back. Hidden with the window, or
  -- by leaving the list, it does nothing.
  addon.SetScript(key, "OnHide", function(ctx)
    if self.shown and self.sidebarPage ~= nil and not key:IsShown() then
      self:Back(ctx)
    end
  end)
  self.backKey = key
end

-- VersionText returns "v" and the addon's version, nothing for a copy that has none (a source
-- checkout's TOC says @project-version@).
---@return string
function settings:VersionText()
  local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, 'Version') or nil
  if version == nil or version == "" or version:sub(1, 1) == "@" then
    return ""
  end
  return "v" .. version
end

-- makeMover makes a part of the window move the window when dragged.
---@private
---@param part Frame
function settings:makeMover(part)
  part:EnableMouse(true)
  part:RegisterForDrag("LeftButton")
  addon.SetScript(part, "OnDragStart", function()
    -- Sliding in, it settles into place first: the slide would fight the drag.
    if not self.closing then
      tween:Stop(self.motion, true)
    end
    self.frame:StartMoving()
  end)
  addon.SetScript(part, "OnDragStop", function()
    self.frame:StopMovingOrSizing()
    -- It opens centered every time: the client is not to keep where it was moved.
    self.frame:SetUserPlaced(false)
  end)
end

---@private
function settings:buildHeader()
  local frame = self.frame
  local header = CreateFrame("Frame", nil, frame)
  self:makeMover(header)
  self.header = header
  self.title = style:CreateText(header, style.Theme.Settings.Header.TitleFont)
  self.title:SetJustifyH("LEFT")
  self.title:SetWordWrap(false)
  self.description = style:CreateText(header, style.Theme.Settings.Header.DescriptionFont)
  self.description:SetJustifyH("LEFT")
  self.description:SetWordWrap(false)
  local close = CreateFrame("Button", nil, frame)
  close:RegisterForClicks("LeftButtonUp")
  close:SetFrameLevel(header:GetFrameLevel() + 5)
  self.closeIcon = close:CreateTexture(nil, "ARTWORK")
  self.closeIcon:SetAllPoints(close)
  addon.SetScript(close, "OnClick", function() self:Close() end)
  addon.SetScript(close, "OnEnter", function() self:paintClose(true) end)
  addon.SetScript(close, "OnLeave", function() self:paintClose(false) end)
  self.closeButton = close
  self.tabs = nextTopTabs:Create(frame, {
    onSelect = function(ctx, id) self:Select(self.pageId, id, ctx) end,
  })
end

---@private
function settings:buildContent()
  self.scroll = scrollbox:Create(self.frame, nil, {
    CreateBar = function(box, opts) return nextScrollBar:Create(box, opts) end,
  })
  self.results = nextPage:Create(self.scroll.scrollChild)
end

---@private
function settings:buildFooter()
  local frame = self.frame
  local footer = CreateFrame("Frame", nil, frame)
  self.footer = footer
  self.footerLine = footer:CreateTexture(nil, "BORDER")
  self.whatsNew = nextButton:Create(footer, {
    text = L:G("What's New"), style = "Link",
    onClick = function(ctx) events:SendMessage(ctx, 'changelog/Open') end,
  })
  self.done = nextButton:Create(footer, {
    text = L:G("Done"), style = "Primary",
    onClick = function() self:Close() end,
  })
end

-- ApplyStyle restyles the window and lays it out again (SonataNext applied a theme).
---@param ctx? Context
function settings:ApplyStyle(ctx)
  if self.frame == nil then
    return
  end
  self:Style()
  self:buildNav()
  if self.shown then
    render:RenderNow(self.root, { ctx = ctx or context:New('NextSettings_Theme') })
  end
end

-- Style draws the window from the theme and places its parts.
function settings:Style()
  local T = style.Theme.Settings
  local frame = self.frame
  frame:SetSize(T.Width, T.Height)
  controls:Paint(self.fill, T.Fill)
  local W = T.Wash
  if W then
    self.wash:SetHeight(W.Height)
    self.wash:SetBlendMode(W.BlendMode or "ADD")
    local r, g, b, a = style:RGBA(W.Color)
    self.wash:SetColorTexture(1, 1, 1, 1)
    self.wash:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
    self.wash:Show()
  else
    self.wash:Hide()
  end
  controls:PaintEdge(self.edge, T.Edge)

  local SB, B = T.Sidebar, T.Brand
  self.sidebar:SetWidth(SB.Width)
  controls:Paint(self.sidebarFill, SB.Fill)
  self.sidebarLine:SetWidth(SB.Line and SB.Line.Size or 1)
  controls:Paint(self.sidebarLine, SB.Line)
  self.brand:SetHeight(B.Height)
  self.brandIcon:SetSize(B.IconSize, B.IconSize)
  self.brandIcon:ClearAllPoints()
  self.brandIcon:SetPoint("LEFT", self.navPanel, "TOPLEFT", SB.Pad, -B.Height / 2)
  controls:Paint(self.brandIcon, { Texture = B.Icon, Color = B.IconColor })
  style:SetFont(self.brandText, B.Font)
  self.brandText:ClearAllPoints()
  self.brandText:SetPoint("LEFT", self.brandIcon, "RIGHT", B.Gap, 0)
  self:paintBrandLine(self.brandLine, self.navPanel)

  local search, SR = self.search, T.Search
  search.frame:ClearAllPoints()
  search.frame:SetPoint("TOPLEFT", self.navPanel, "TOPLEFT", SB.Pad, -(B.Height + SR.Gap))
  search.frame:SetPoint("TOPRIGHT", self.navPanel, "TOPRIGHT", -SB.Pad, -(B.Height + SR.Gap))
  search:Style()

  local V = T.Version
  style:SetFont(self.version, V.Font)
  self.version:ClearAllPoints()
  self.version:SetPoint("BOTTOMLEFT", self.navPanel, "BOTTOMLEFT", SB.Pad, V.Bottom)
  self.navBox:ClearAllPoints()
  self.navBox:SetPoint("TOPLEFT", search.frame, "BOTTOMLEFT", -SB.Pad, -SR.Gap)
  self.navBox:SetPoint("BOTTOMRIGHT", self.navPanel, "BOTTOMRIGHT", 0, V.Bottom * 2 + 12)
  self:styleListPanel()

  local H = T.Header
  self.header:ClearAllPoints()
  self.header:SetPoint("TOPLEFT", frame, "TOPLEFT", SB.Width, 0)
  self.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  self.header:SetHeight(H.Height)
  style:SetFont(self.title, H.TitleFont)
  self:placeHeading()
  style:SetFont(self.description, H.DescriptionFont)
  self.description:ClearAllPoints()
  self.description:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -H.Gap)
  self.description:SetPoint("RIGHT", self.header, "RIGHT", -H.Pad, 0)
  local X = H.Close
  self.closeButton:SetSize(X.Size, X.Size)
  self.closeButton:ClearAllPoints()
  self.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -X.Inset, -X.Inset)
  self:paintClose(false)

  local F = T.Footer
  self.footer:ClearAllPoints()
  self.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SB.Width, 0)
  self.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  self.footer:SetHeight(F.Height)
  self.footerLine:ClearAllPoints()
  self.footerLine:SetPoint("TOPLEFT", self.footer, "TOPLEFT", 0, 0)
  self.footerLine:SetPoint("TOPRIGHT", self.footer, "TOPRIGHT", 0, 0)
  self.footerLine:SetHeight(F.Line and F.Line.Size or 1)
  controls:Paint(self.footerLine, F.Line)
  self.whatsNew.frame:ClearAllPoints()
  self.whatsNew.frame:SetPoint("LEFT", self.footer, "LEFT", F.Pad, 0)
  self.done.frame:ClearAllPoints()
  self.done.frame:SetPoint("RIGHT", self.footer, "RIGHT", -F.Pad, 0)
  self:placeContent()
end

-- paintBrandLine draws the gold line under the brand's row of a panel (the pages', a page's list's).
---@private
---@param line Texture
---@param panel Frame
function settings:paintBrandLine(line, panel)
  local SB, B = style.Theme.Settings.Sidebar, style.Theme.Settings.Brand
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", panel, "TOPLEFT", SB.Pad, -(B.Height - (B.Line and B.Line.Size or 1)))
  line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -SB.Pad, -(B.Height - (B.Line and B.Line.Size or 1)))
  line:SetHeight(B.Line and B.Line.Size or 1)
  if B.Line then
    local r, g, b = style:RGBA(B.Line.Color)
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", CreateColor(r, g, b, B.Line.From), CreateColor(r, g, b, B.Line.To))
    line:Show()
  else
    line:Hide()
  end
end

-- styleListPanel lays out the panel a page's own list slides in on: Back in the brand's row, its line,
-- and the list under it; then both panels where the slide has them.
---@private
function settings:styleListPanel()
  local T = style.Theme.Settings
  local SB, B, K = T.Sidebar, T.Brand, T.Back
  self.back:ClearAllPoints()
  self.back:SetPoint("TOPLEFT", self.listPanel, "TOPLEFT", 0, 0)
  self.back:SetPoint("TOPRIGHT", self.listPanel, "TOPRIGHT", 0, 0)
  self.back:SetHeight(B.Height)
  self.backIcon:SetSize(K.IconSize, K.IconSize)
  self.backIcon:ClearAllPoints()
  self.backIcon:SetPoint("LEFT", self.back, "LEFT", SB.Pad, 0)
  controls:Paint(self.backIcon, { Texture = K.Icon, Color = K.IconColor })
  style:SetFont(self.backLabel, K.Font)
  self.backLabel:ClearAllPoints()
  self.backLabel:SetPoint("LEFT", self.backIcon, "RIGHT", K.Gap, 0)
  self:paintBrandLine(self.backLine, self.listPanel)
  self.listHost:ClearAllPoints()
  self.listHost:SetPoint("TOPLEFT", self.listPanel, "TOPLEFT", 0, -B.Height)
  self.listHost:SetSize(SB.Width, T.Height - B.Height)
  if self.sidebarPage ~= nil then
    self:listOf(self.sidebarPage):Place(SB.Width, T.Height - B.Height)
  end
  self:placeSidebar()
end

-- placeSidebar puts the pages and a page's list where the slide has them: the pages shift left out of
-- the sidebar as the list comes in from its right, each fading as it leaves; a panel all the way out
-- hides.
---@private
function settings:placeSidebar()
  local T = style.Theme.Settings
  local width, p = T.Sidebar.Width, self.shift
  for _, part in ipairs({ { self.navPanel, -p * width, 1 - p }, { self.listPanel, (1 - p) * width, p } }) do
    local panel = part[1]
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", part[2], 0)
    panel:SetSize(width, T.Height)
    panel:SetAlpha(part[3])
    panel:SetShown(part[3] > 0)
  end
end

-- slideTo slides the sidebar to the pages (0) or a page's list (1); at once while the window is not
-- shown or is opening.
---@private
---@param target number
---@param animate boolean
function settings:slideTo(target, animate)
  if not animate then
    tween:Stop(self.shiftMotion)
    self.shift = target
    self:placeSidebar()
    return
  end
  tween:Play(self.shiftMotion, {
    duration = style.Theme.Settings.Back.Slide,
    ease = style:Ease("Glide"),
    from = self.shift,
    to = target,
    onUpdate = function(v)
      self.shift = v
      self:placeSidebar()
    end,
  })
end

-- listOf returns a page's own list, made the first time it shows.
---@private
---@param page NextSettingsPageDef
---@return NextSettingsSidebar
function settings:listOf(page)
  local list = self.lists[page]
  if list == nil then
    list = page.sidebar(self.listHost, self.frame)
    self.lists[page] = list
    local T = style.Theme.Settings
    list:Place(T.Sidebar.Width, T.Height - T.Brand.Height)
  end
  return list
end

-- enterList shows a page's own list in the sidebar, sliding it in from the pages (at once while the
-- window opens), and makes the first Escape go back.
---@private
---@param page NextSettingsPageDef
---@param ctx Context
---@param animate boolean
function settings:enterList(page, ctx, animate)
  local list = self:listOf(page)
  for p, other in pairs(self.lists) do
    other.frame:SetShown(p == page)
  end
  if self.sidebarPage ~= page then
    self.sidebarPage = page
    self:slideTo(1, animate)
  end
  list:Refresh(ctx)
  if self.shown and not self.backKeyHeld then
    self.backKey:Show()
    controls:PushEscape(self.backKey)
    self.backKeyHeld = true
  end
end

-- releaseBackKey hides the frame the first Escape hides (when Escape did not already) and gives
-- Escape back to the window.
---@private
function settings:releaseBackKey()
  if not self.backKeyHeld then
    return
  end
  self.backKeyHeld = false
  self.backKey:Hide()
  controls:ReleaseEscape(self.backKey)
end

-- leaveList slides the pages back into the sidebar; Escape closes the window again.
---@private
---@param animate boolean
function settings:leaveList(animate)
  if self.sidebarPage == nil then
    return
  end
  self.sidebarPage = nil
  self:slideTo(0, animate)
  self:releaseBackKey()
end

-- Back leaves a page's own list for the page (and tab) shown before it, or the first page.
---@param ctx? Context
function settings:Back(ctx)
  local to = self.returnTo
  self:Select(to and to.pageId or nil, to and to.tabId or nil, ctx)
end

-- Reselect shows the page again: its heading, buttons, tabs, list and rows read again (a page's own
-- list chose something else, or what it shows changed).
---@param ctx? Context
function settings:Reselect(ctx)
  if self.frame ~= nil and self.shown and self.query == nil then
    self:Select(self.pageId, self.tabId, ctx)
  end
end

-- placeHeading puts the page's buttons (when it has them) right of its title, left of the close
-- button, the title stopping short of them.
---@private
function settings:placeHeading()
  local H = style.Theme.Settings.Header
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", self.header, "TOPLEFT", H.Pad, -H.TitleTop)
  local actions = self.actions
  if actions ~= nil then
    local X = H.Close
    actions.frame:ClearAllPoints()
    actions.frame:SetPoint("TOPRIGHT", self.header, "TOPRIGHT", -(X.Inset + X.Size + H.Actions.Gap), -H.Actions.Top)
    self.title:SetPoint("RIGHT", actions.frame, "LEFT", -H.Actions.Gap, 0)
  end
end

-- showActions shows a page's buttons in the header (none for a page without), read again.
---@private
---@param page? NextSettingsPageDef
---@param ctx Context
function settings:showActions(page, ctx)
  local actions
  if page ~= nil and page.actions ~= nil then
    actions = self.actionsOf[page]
    if actions == nil then
      actions = page.actions(self.header, self.frame)
      self.actionsOf[page] = actions
    end
    actions:Refresh(ctx)
  end
  for _, other in pairs(self.actionsOf) do
    other.frame:SetShown(other == actions)
  end
  self.actions = actions
  self:placeHeading()
end

-- placeContent puts the tabs under the header and the content between them (or the header) and the
-- footer.
---@private
function settings:placeContent()
  local T = style.Theme.Settings
  local SB, H, F = T.Sidebar, T.Header, T.Footer
  local tabs = self.tabs
  tabs.frame:ClearAllPoints()
  tabs.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", SB.Width + H.Pad, -H.Height)
  tabs.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -H.Pad, -H.Height)
  local scroll = self.scroll.frame
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", SB.Width, -self:ContentTop())
  scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, F.Height)
  scroll:SetSize(T.Width - SB.Width, self:ContentHeight())
end

-- ContentTop returns how far below the window's top the content starts: under the header, and the
-- tabs while they show.
---@return number
function settings:ContentTop()
  local H = style.Theme.Settings.Header
  local top = H.Height
  if self.tabs.frame:IsShown() then
    top = top + controls:Theme("TopTabs").Height
  end
  return top
end

---@return number
function settings:ContentHeight()
  local T = style.Theme.Settings
  return T.Height - self:ContentTop() - T.Footer.Height
end

---@private
---@param hovered boolean
function settings:paintClose(hovered)
  local X = style.Theme.Settings.Header.Close
  controls:Paint(self.closeIcon, { Texture = X.Icon, Color = hovered and X.HoverColor or X.Color })
end

-- navRow returns the i-th row of the sidebar's list, made the first time it is needed.
---@private
---@param i number
---@return table
function settings:navRow(i)
  local row = self.navRows[i]
  if row ~= nil then
    return row
  end
  local frame = CreateFrame("Button", nil, self.navList)
  frame:RegisterForClicks("LeftButtonUp")
  local N = style.Theme.Settings.Nav
  row = {
    frame = frame,
    fill = frame:CreateTexture(nil, "BACKGROUND"),
    hover = frame:CreateTexture(nil, "BACKGROUND", nil, 1),
    indicator = frame:CreateTexture(nil, "ARTWORK"),
    label = style:CreateText(frame, N.Font),
    hovered = false,
  }
  row.fill:SetAllPoints(frame)
  row.hover:SetAllPoints(frame)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  addon.SetScript(frame, "OnClick", function(ctx)
    if row.page then
      self:Select(row.page.id, nil, ctx)
    end
  end)
  addon.SetScript(frame, "OnEnter", function() row.hovered = true self:paintNavRow(row) end)
  addon.SetScript(frame, "OnLeave", function() row.hovered = false self:paintNavRow(row) end)
  self.navRows[i] = row
  return row
end

-- buildNav lists the pages shown under their headings, in the order the headings' first pages were
-- defined.
---@private
function settings:buildNav()
  local N = style.Theme.Settings.Nav
  local groups, order = {}, {}
  for _, page in ipairs(pages:List()) do
    if groups[page.group] == nil then
      groups[page.group] = {}
      table.insert(order, page.group)
    end
    table.insert(groups[page.group], page)
  end
  local i, y = 0, 0
  for g, group in ipairs(order) do
    if g > 1 then
      y = y + N.GroupGap
    end
    i = i + 1
    local heading = self:navRow(i)
    heading.group, heading.page = group, nil
    heading.label:SetText(string.upper(group))
    heading.frame:EnableMouse(false)
    heading.frame:ClearAllPoints()
    heading.frame:SetPoint("TOPLEFT", self.navList, "TOPLEFT", 0, -y)
    heading.frame:SetPoint("TOPRIGHT", self.navList, "TOPRIGHT", 0, -y)
    heading.frame:SetHeight(N.GroupHeight)
    heading.frame:Show()
    self:paintNavRow(heading)
    y = y + N.GroupHeight
    for _, page in ipairs(groups[group]) do
      i = i + 1
      local row = self:navRow(i)
      row.group, row.page = nil, page
      row.label:SetText(page.title)
      row.frame:EnableMouse(true)
      row.frame:ClearAllPoints()
      row.frame:SetPoint("TOPLEFT", self.navList, "TOPLEFT", 0, -y)
      row.frame:SetPoint("TOPRIGHT", self.navList, "TOPRIGHT", 0, -y)
      row.frame:SetHeight(N.ItemHeight)
      row.frame:Show()
      self:paintNavRow(row)
      y = y + N.ItemHeight
    end
  end
  for k = i + 1, #self.navRows do
    local row = self.navRows[k]
    row.page, row.group = nil, nil
    row.frame:Hide()
  end
  self.navList:SetHeight(math.max(1, y))
  self.navBox:FullUpdate(true)
end

-- paintNavRow draws an entry: a heading, or a page chosen, under the pointer, or neither.
---@private
---@param row table
function settings:paintNavRow(row)
  local SB, N = style.Theme.Settings.Sidebar, style.Theme.Settings.Nav
  local chosen = row.page ~= nil and self.query == nil and row.page.id == self.pageId
  row.label:ClearAllPoints()
  if row.group then
    style:SetFont(row.label, N.GroupFont)
    row.label:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", SB.Pad, 4)
    row.fill:Hide()
    row.hover:Hide()
    row.indicator:Hide()
    return
  end
  local font = N.Font
  if chosen then
    font = N.SelectedFont
  elseif row.hovered then
    font = N.HoverFont
  end
  style:SetFont(row.label, font)
  row.label:SetPoint("LEFT", row.frame, "LEFT", SB.Pad + N.Indent, 0)
  row.label:SetPoint("RIGHT", row.frame, "RIGHT", -SB.Pad, 0)
  controls:Paint(row.fill, chosen and N.SelectedFill or false)
  controls:Paint(row.hover, (row.hovered and not chosen) and N.HoverFill or false)
  row.indicator:ClearAllPoints()
  row.indicator:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
  row.indicator:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
  row.indicator:SetWidth(N.Indicator.Width)
  controls:Paint(row.indicator, chosen and { Color = N.Indicator.Color } or false)
end

---@private
function settings:paintNav()
  for _, row in ipairs(self.navRows) do
    if row.frame:IsShown() then
      self:paintNavRow(row)
    end
  end
end

-- hiddenOf returns whether a row is hidden now: its own hidden or its section's (nil when neither
-- can hide it).
---@param section NextSettingsSectionDef
---@param def NextSettingsRowDef
---@return (fun(): boolean)?
local function hiddenOf(section, def)
  local own, theirs = def.hidden, section.hidden
  if own == nil and theirs == nil then
    return nil
  end
  return function()
    return (theirs ~= nil and theirs() == true) or (own ~= nil and own() == true)
  end
end

-- isHidden says whether a row definition of a section is hidden now.
---@param section NextSettingsSectionDef
---@param def NextSettingsRowDef
---@return boolean
local function isHidden(section, def)
  local hidden = hiddenOf(section, def)
  return hidden ~= nil and hidden()
end

-- makeRow makes the row of a row definition of a section on a page, nil for a setting its bag does not
-- have. A row that can be hidden (its own hidden or its section's) carries it, for the page to check.
---@private
---@param page NextSettingsPageDef
---@param def NextSettingsRowDef
---@param parent Frame
---@param section NextSettingsSectionDef
---@return NextSettingsRow?
function settings:makeRow(page, def, parent, section)
  local row
  if def.setting ~= nil then
    if not catalog:Has(def.setting, page.bag) then
      return nil
    end
    row = rows:Create(parent, catalog:Get(def.setting, page.bag), self.frame)
  elseif def.option ~= nil then
    row = rows:Create(parent, def.option, self.frame)
  elseif def.text ~= nil then
    row = rows:CreateText(parent, def.text)
  elseif def.buttons ~= nil then
    row = rows:CreateButtons(parent, def.buttons)
  elseif def.block ~= nil then
    row = def.block(parent, self.frame)
  end
  if row ~= nil then
    row.hidden = hiddenOf(section, def)
  end
  return row
end

-- pageFor returns a page's tab as a page of rows, made the first time it shows.
---@private
---@param page NextSettingsPageDef
---@param tab NextSettingsTabDef
---@return NextSettingsPageFrame
function settings:pageFor(page, tab)
  local byTab = self.cache[page]
  if byTab == nil then
    byTab = {}
    self.cache[page] = byTab
  end
  -- A tab is made once for each design: the two show different rows.
  local key = pages:DesignInUse() .. ":" .. tab.id
  local drawn = byTab[key]
  if drawn ~= nil then
    return drawn
  end
  drawn = nextPage:Create(self.scroll.scrollChild)
  local sections = {}
  for _, sdef in ipairs(pages:Sections(tab)) do
    local list = {}
    for _, rdef in ipairs(pages:InDesign(sdef) and sdef.rows or {}) do
      local row = pages:InDesign(rdef) and self:makeRow(page, rdef, drawn.frame, sdef) or nil
      if row ~= nil then
        table.insert(list, row)
      end
    end
    -- A section none of whose rows the page's bag has is left out.
    if #list > 0 then
      table.insert(sections, { title = sdef.title, note = sdef.note, titleHidden = sdef.titleHidden, rows = list })
    end
  end
  drawn:SetSections(sections)
  byTab[key] = drawn
  return drawn
end

-- show puts a page of rows in the content, scrolled to its top, its values read again.
---@private
---@param drawn NextSettingsPageFrame
---@param ctx Context
function settings:show(drawn, ctx)
  if self.page ~= drawn then
    if self.page ~= nil then
      self.page:Leave(ctx)
    end
    self.scroll:SetChild(drawn)
    self.page = drawn
  end
  drawn:Refresh(ctx)
  self:placeContent()
  render:RenderNow(self.root, { ctx = ctx })
  self.scroll.scrollBox:SetScrollPercentage(0, true)
  self:recordRender()
end

-- recordRender gives the render recorder (render-recorder.md §2) the window as it is drawn now.
---@private
function settings:recordRender()
  local recorder = addon:GetModule('RenderRecorder', true)
  if recorder ~= nil and recorder.recording then
    recorder:SettingsRendered(self.frame)
  end
end

-- Select shows a page's tab (General, the first page shown, for a page not shown now; its first tab
-- for a tab it does not have), leaving a search.
---@param pageId? string
---@param tabId? string
---@param ctx? Context
function settings:Select(pageId, tabId, ctx)
  ctx = ctx or context:New('NextSettings_Select')
  local page = pageId and pages:Get(pageId) or nil
  if page == nil or not pages:IsShown(page) then
    page = pages:List()[1]
  end
  if page == nil then
    return
  end
  -- Coming into a page's own list from the pages: Back goes to the page left.
  if page.sidebar ~= nil and self.sidebarPage == nil then
    self.returnTo = self.pageId and { pageId = self.pageId, tabId = self.tabId } or nil
  end
  if self.query ~= nil then
    self.query = nil
    self.search:SetText("")
  end
  -- The list first: it may choose what the page shows, and so its tabs.
  local animate = self.shown and not self.arriving
  if page.sidebar ~= nil then
    self:enterList(page, ctx, animate)
  else
    self:leaveList(animate)
  end
  local tabs = pages:ShownTabs(page)
  local tab = tabs[1] or page.tabs[1]
  for _, t in ipairs(tabs) do
    if t.id == tabId then
      tab = t
    end
  end
  self.pageId, self.tabId = page.id, tab.id
  local title, description = page.title, page.description
  if page.heading ~= nil then
    title, description = page.heading()
  end
  self.title:SetText(title)
  self.description:SetText(description or "")
  self:showActions(page, ctx)
  if #tabs > 1 then
    local list = {}
    for i, t in ipairs(tabs) do
      list[i] = { id = t.id, text = t.title }
    end
    self.tabs:SetTabs(list)
    self.tabs:Select(tab.id)
    self.tabs.frame:Show()
  else
    self.tabs.frame:Hide()
  end
  self:paintNav()
  self:show(self:pageFor(page, tab), ctx)
end

-- OnDesignChanged shows, while the window is open, the settings of the design the bags switched to:
-- its pages again, and the page it showed (the first page for one the design does not have) or its
-- search.
---@param ctx Context
function settings:OnDesignChanged(ctx)
  if not self.shown then
    return
  end
  self:buildNav()
  if self.query ~= nil then
    self:Search(ctx, self.query)
  else
    self:Select(self.pageId, self.tabId, ctx)
  end
end

-- Refresh shows the values of the page shown again (a block changed them: a reset).
---@param ctx? Context
function settings:Refresh(ctx)
  if self.page ~= nil then
    self.page:Refresh(ctx or context:New('NextSettings_Refresh'))
    render:Invalidate(self.root)
  end
end

-- matches says whether a row definition of a page matches a search: a setting by its name,
-- description, searching words or section; a block by its name or searching words.
---@private
---@param page NextSettingsPageDef
---@param section NextSettingsSectionDef
---@param def NextSettingsRowDef
---@param needle string
---@return boolean
function settings:matches(page, section, def, needle)
  if not pages:InDesign(section) or not pages:InDesign(def) or isHidden(section, def) then
    return false
  end
  local option
  if def.setting ~= nil then
    if not catalog:Has(def.setting, page.bag) then
      return false
    end
    option = catalog:Get(def.setting, page.bag)
  elseif def.option ~= nil then
    option = def.option
  end
  local function has(text)
    text = rows:TextOf(text)
    return type(text) == "string" and string.find(string.lower(text), needle, 1, true) ~= nil
  end
  local words = option and option.keywords or def.keywords or {}
  for _, word in ipairs(words) do
    if has(word) then
      return true
    end
  end
  if option ~= nil then
    return has(option.title) or has(option.description) or has(section.title)
  end
  return def.block ~= nil and has(def.title)
end

-- resultRow returns the live row of a matching setting, made once and kept for later searches.
---@private
---@param page NextSettingsPageDef
---@param tab NextSettingsTabDef
---@param s number The section's place.
---@param r number The row's place.
---@param def NextSettingsRowDef
---@return NextSettingsRow?
function settings:resultRow(page, tab, s, r, def)
  local key = page.id .. "\0" .. tab.id .. "\0" .. s .. "\0" .. r .. "\0" .. pages:DesignInUse()
  local row = self.resultRows[key]
  if row == nil and def.block == nil then
    row = self:makeRow(page, def, self.results.frame, pages:Sections(tab)[s])
    self.resultRows[key] = row
  end
  return row
end

-- resultLink returns the link to a page's tab, made once and kept.
---@private
---@param page NextSettingsPageDef
---@param tab NextSettingsTabDef
---@param title string
---@return NextSettingsRow
function settings:resultLink(page, tab, title)
  local key = page.id .. "\0" .. tab.id
  local row = self.resultRows[key]
  if row == nil then
    row = rows:CreateLink(self.results.frame, L:G("Open") .. " " .. title, function(ctx)
      self:Select(page.id, tab.id, ctx)
    end)
    self.resultRows[key] = row
  end
  return row
end

-- Search lists every setting matching text (in any case), live, a section per page and tab with a
-- link to it; nothing left goes back to the page.
---@param ctx Context
---@param text string
function settings:Search(ctx, text)
  text = strtrim(text or "")
  if text == "" then
    if self.query ~= nil then
      self:Select(self.pageId, self.tabId, ctx)
    end
    return
  end
  self.query = text
  self:leaveList(self.shown)
  self:showActions(nil, ctx)
  local needle = string.lower(text)
  local sections = {}
  for _, page in ipairs(pages:List()) do
    local tabs = pages:ShownTabs(page)
    for _, tab in ipairs(tabs) do
      local found = {}
      for s, section in ipairs(pages:Sections(tab)) do
        for r, def in ipairs(section.rows) do
          if self:matches(page, section, def, needle) then
            local row = self:resultRow(page, tab, s, r, def)
            if row ~= nil then
              table.insert(found, row)
            elseif def.block ~= nil then
              table.insert(found, false)
            end
          end
        end
      end
      if #found > 0 then
        local title = #tabs > 1 and (page.title .. " > " .. tab.title) or page.title
        local list = { self:resultLink(page, tab, title) }
        for _, row in ipairs(found) do
          if row then
            table.insert(list, row)
          end
        end
        table.insert(sections, { title = title, rows = list })
      end
    end
  end
  self.title:SetText(L:G("Search"))
  self.description:SetText(format(L:G("Settings matching \"%s\""), text))
  self.tabs.frame:Hide()
  self.results:SetSections(sections)
  self.results:SetEmptyText(format(L:G("No settings match \"%s\"."), text))
  self:paintNav()
  self:show(self.results, ctx)
end
