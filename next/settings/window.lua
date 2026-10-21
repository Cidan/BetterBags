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
-- over it closes first). It shows the page and tab it showed last this session. Typing in the
-- search box lists every setting that matches as live rows under their page and tab.
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
---@field shown boolean
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
end

settings:Init()

-- Open shows the window on a page (and tab) when given, else the one it showed last.
---@param pageId? string
---@param tabId? string
function settings:Open(pageId, tabId)
  self:build()
  local frame = self.frame
  local T = style.Theme.Settings
  local scale = math.min(1, UIParent:GetWidth() * SCREEN_SHARE / T.Width, UIParent:GetHeight() * SCREEN_SHARE / T.Height)
  frame:SetScale(scale)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  self:buildNav()
  frame:Show()
  self.shown = true
  controls:PushEscape(frame)
  self:Select(pageId or self.pageId, tabId or (pageId == nil and self.tabId or nil))
end

---@return boolean
function settings:IsShown()
  return self.frame ~= nil and self.frame:IsShown()
end

-- Close hides the window.
function settings:Close()
  if self.frame == nil or not self.shown then
    return
  end
  self.frame:Hide()
  self:hidden()
end

-- hidden ends the window's showing however it hid (Close, Escape): the menu and dialog over it close.
---@private
function settings:hidden()
  if not self.shown then
    return
  end
  self.shown = false
  controls:ReleaseEscape(self.frame)
  if self.page ~= nil then
    self.page:Leave(context:New('NextSettings_Hidden'))
  end
  nextMenu:Close()
  if nextDialog:IsShown() then
    nextDialog:Hide()
  end
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
  self.sidebar = sidebar
  self.sidebarFill = sidebar:CreateTexture(nil, "BACKGROUND", nil, -7)
  self.sidebarFill:SetAllPoints(sidebar)
  self.sidebarLine = sidebar:CreateTexture(nil, "BORDER")
  self.sidebarLine:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
  self.sidebarLine:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
  -- The brand: dragging it moves the window, as the header does.
  local brand = CreateFrame("Frame", nil, sidebar)
  brand:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
  brand:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
  self:makeMover(brand)
  self.brand = brand
  self.brandIcon = brand:CreateTexture(nil, "ARTWORK")
  self.brandText = style:CreateText(brand, style.Theme.Settings.Brand.Font)
  self.brandText:SetText(L:G("BetterBags"))
  self.brandLine = brand:CreateTexture(nil, "ARTWORK")
  self.search = nextInput:Create(sidebar, {
    help = L:G("Search settings"),
    onChange = function(ctx, text) self:Search(ctx, text) end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  addon.HookScript(self.search.frame, "OnEscapePressed", function(ctx) self:Search(ctx, "") end)
  local navBox = CreateFrame("Frame", nil, sidebar, "WowScrollBox") --[[@as WowScrollBox]]
  navBox:SetInterpolateScroll(true)
  local navList = CreateFrame("Frame", nil, navBox)
  navList.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(28)
  navBox:Init(view)
  self.navBar = nextScrollBar:Create(navBox)
  self.navBar:Bind(navBox)
  self.navBox, self.navList = navBox, navList
  self.version = style:CreateText(sidebar, style.Theme.Settings.Version.Font)
  self.version:SetText(self:VersionText())
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
  addon.SetScript(part, "OnDragStart", function() self.frame:StartMoving() end)
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
  self.brandIcon:SetPoint("LEFT", self.brand, "LEFT", SB.Pad, 0)
  controls:Paint(self.brandIcon, { Texture = B.Icon, Color = B.IconColor })
  style:SetFont(self.brandText, B.Font)
  self.brandText:ClearAllPoints()
  self.brandText:SetPoint("LEFT", self.brandIcon, "RIGHT", B.Gap, 0)
  self.brandLine:ClearAllPoints()
  self.brandLine:SetPoint("BOTTOMLEFT", self.brand, "BOTTOMLEFT", SB.Pad, 0)
  self.brandLine:SetPoint("BOTTOMRIGHT", self.brand, "BOTTOMRIGHT", -SB.Pad, 0)
  self.brandLine:SetHeight(B.Line and B.Line.Size or 1)
  if B.Line then
    local r, g, b = style:RGBA(B.Line.Color)
    self.brandLine:SetColorTexture(1, 1, 1, 1)
    self.brandLine:SetGradient("HORIZONTAL", CreateColor(r, g, b, B.Line.From), CreateColor(r, g, b, B.Line.To))
    self.brandLine:Show()
  else
    self.brandLine:Hide()
  end

  local search, SR = self.search, T.Search
  search.frame:ClearAllPoints()
  search.frame:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", SB.Pad, -(B.Height + SR.Gap))
  search.frame:SetPoint("TOPRIGHT", self.sidebar, "TOPRIGHT", -SB.Pad, -(B.Height + SR.Gap))
  search:Style()

  local V = T.Version
  style:SetFont(self.version, V.Font)
  self.version:ClearAllPoints()
  self.version:SetPoint("BOTTOMLEFT", self.sidebar, "BOTTOMLEFT", SB.Pad, V.Bottom)
  self.navBox:ClearAllPoints()
  self.navBox:SetPoint("TOPLEFT", search.frame, "BOTTOMLEFT", -SB.Pad, -SR.Gap)
  self.navBox:SetPoint("BOTTOMRIGHT", self.sidebar, "BOTTOMRIGHT", 0, V.Bottom * 2 + 12)

  local H = T.Header
  self.header:ClearAllPoints()
  self.header:SetPoint("TOPLEFT", frame, "TOPLEFT", SB.Width, 0)
  self.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  self.header:SetHeight(H.Height)
  style:SetFont(self.title, H.TitleFont)
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", self.header, "TOPLEFT", H.Pad, -H.TitleTop)
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

-- makeRow makes the row of a row definition on a page, nil for a setting its bag does not have.
---@private
---@param page NextSettingsPageDef
---@param def NextSettingsRowDef
---@param parent Frame
---@return NextSettingsRow?
function settings:makeRow(page, def, parent)
  if def.setting ~= nil then
    if not catalog:Has(def.setting, page.bag) then
      return nil
    end
    return rows:Create(parent, catalog:Get(def.setting, page.bag), self.frame)
  elseif def.option ~= nil then
    return rows:Create(parent, def.option, self.frame)
  elseif def.text ~= nil then
    return rows:CreateText(parent, def.text)
  elseif def.buttons ~= nil then
    return rows:CreateButtons(parent, def.buttons)
  elseif def.block ~= nil then
    return def.block(parent, self.frame)
  end
  return nil
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
  local drawn = byTab[tab.id]
  if drawn ~= nil then
    return drawn
  end
  drawn = nextPage:Create(self.scroll.scrollChild)
  local sections = {}
  for _, sdef in ipairs(pages:Sections(tab)) do
    local list = {}
    for _, rdef in ipairs(sdef.rows) do
      local row = self:makeRow(page, rdef, drawn.frame)
      if row ~= nil then
        table.insert(list, row)
      end
    end
    -- A section none of whose rows the page's bag has is left out.
    if #list > 0 then
      table.insert(sections, { title = sdef.title, note = sdef.note, rows = list })
    end
  end
  drawn:SetSections(sections)
  byTab[tab.id] = drawn
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
  local tab = page.tabs[1]
  for _, t in ipairs(page.tabs) do
    if t.id == tabId then
      tab = t
    end
  end
  self.pageId, self.tabId = page.id, tab.id
  if self.query ~= nil then
    self.query = nil
    self.search:SetText("")
  end
  self.title:SetText(page.title)
  self.description:SetText(page.description or "")
  if #page.tabs > 1 then
    local list = {}
    for i, t in ipairs(page.tabs) do
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
  local key = page.id .. "\0" .. tab.id .. "\0" .. s .. "\0" .. r
  local row = self.resultRows[key]
  if row == nil and def.block == nil then
    row = self:makeRow(page, def, self.results.frame)
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
  local needle = string.lower(text)
  local sections = {}
  for _, page in ipairs(pages:List()) do
    for _, tab in ipairs(page.tabs) do
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
        local title = #page.tabs > 1 and (page.title .. " > " .. tab.title) or page.title
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
