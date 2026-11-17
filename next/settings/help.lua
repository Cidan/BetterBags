local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class NextScrollBar: AceModule
local nextScrollBar = addon:GetModule('NextScrollBar')

---@class NextSettings: AceModule
local settings = addon:GetModule('NextSettings')

---@class NextSettingsNav: AceModule
local nav = addon:GetModule('NextSettingsNav')

---@class NextSettingsCards: AceModule
local cards = addon:GetModule('NextSettingsCards')

---@class NextHelpArticle: AceModule
local helpArticle = addon:GetModule('NextHelpArticle')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSettingsHelp is the settings window's Help page (help.md §4). Choosing it slides the pages out of the sidebar
-- and a tree of the help's articles in (a page's own list, next-settings.md §3): Help Home, then each group's heading
-- and every article under it, always open (asked: "expand and keep expanded, all the help headers"); the rows fade in
-- one after another as it slides in, and the chosen row's fill and bar glide to the next one chosen. Its
-- content is one block filling the page: the home asks "What do you need help with?" over a search box and the
-- featured articles, rising and fading in; typing glides the box to the page's top and lists the articles found as
-- cards, staggering in and sliding to new places as the ranking changes, the words matched lit; an article slides in
-- from the right going forward and from the left going back. The page's header shows the article's title and summary,
-- or the search. /bb help [words] and the settings window's search open it (help/Open, help/OpenArticle).
---@class NextSettingsHelp: AceModule
---@field trees NextHelpTree[]
---@field views NextHelpView[]
---@field state {view: "home"|"results"|"article", query: string, articleId?: string}
---@field direction "forward"|"back" Where the last article shown came from in the tree.
local help = addon:NewModule('NextSettingsHelp')

help.trees = {}
help.views = {}

-- At most this many articles found, and featured on the home.
local RESULTS = 30
local FEATURED = 6

-- Init starts a session on the home.
function help:Init()
  self.state = { view = "home", query = "" }
  self.direction = "forward"
end

help:Init()

-- OnEnable opens the page on help/Open (/bb help, with what to search for) and help/OpenArticle (the settings window's
-- search).
function help:OnEnable()
  events:RegisterMessage('help/Open', function(ctx, query) self:Open(ctx, query) end)
  events:RegisterMessage('help/OpenArticle', function(ctx, id) self:OpenArticle(ctx, id) end)
end

---@param ctx? Context
function help:ApplyStyle(ctx)
  local _ = ctx
  for _, view in ipairs(self.views) do
    view:Style()
  end
  for _, tree in ipairs(self.trees) do
    tree:Style()
  end
end

-- Page returns the Help page's definition (NextSettingsPages:Define): its tree in the sidebar, its heading read from
-- what it shows, and one tab of one block, the view.
---@return NextSettingsPageDef
function help:Page()
  local keywords = { "help", "guide", "faq", "how to", "manual", "documentation", "tutorial" }
  return {
    id = "help", group = L:G("Help"), title = L:G("Help"), description = L:G("Guides to BetterBags features and settings"),
    keywords = keywords,
    sidebar = function(parent, window) return self:CreateTree(parent, window) end,
    heading = function() return self:Heading() end,
    tabs = { { id = "help", title = L:G("Help"), sections = { {
      title = L:G("Help"), titleHidden = function() return true end,
      rows = { { title = L:G("Help"), keywords = keywords,
        block = function(parent, window) return self:CreateView(parent, window) end } },
    } } } },
  }
end

-- Settle leaves an article the bags in use do not show (they were switched while it showed): for the search it was
-- opened from, else the home.
function help:Settle()
  local s = self.state
  if s.view ~= "article" then
    return
  end
  local article = articles:Get(s.articleId)
  if article ~= nil and articles:IsShown(article) then
    return
  end
  self.state = s.query ~= "" and { view = "results", query = s.query } or { view = "home", query = "" }
  self.direction = "back"
end

-- Heading returns the page's title and description now: the article's, the search's, or the home's.
---@return string, string
function help:Heading()
  self:Settle()
  local s = self.state
  if s.view == "article" then
    local article = articles:Get(s.articleId)
    if article ~= nil then
      return article.title, article.summary
    end
  elseif s.view == "results" then
    return L:G("Search Results"), format(L:G("Help articles matching \"%s\""), strtrim(s.query))
  end
  return L:G("Help"), L:G("Searchable guides to BetterBags")
end

-- ChosenKey returns the key of the tree's row for what the page shows: the article's, else Help Home's.
---@return string
function help:ChosenKey()
  self:Settle()
  if self.state.view == "article" then
    return "article:" .. self.state.articleId
  end
  return "home"
end

-- show opens the window on the page, or shows the page again.
---@private
---@param ctx? Context
function help:show(ctx)
  if settings:IsShown() then
    settings:Select("help", nil, ctx)
  else
    settings:Open("help")
  end
end

-- Open opens the page on its home, or on what a search finds when given words.
---@param ctx? Context
---@param query? string
function help:Open(ctx, query)
  query = strtrim(query or "")
  self.state = query ~= "" and { view = "results", query = query } or { view = "home", query = "" }
  self.direction = "forward"
  self:show(ctx)
end

-- indexOf returns an article's place in the tree, or nil.
---@param id? string
---@return number?
local function indexOf(id)
  for i, article in ipairs(articles:Shown()) do
    if article.id == id then
      return i
    end
  end
  return nil
end

-- OpenArticle opens the page on an article shown: forward when it is later in the tree than the article shown (or none
-- is), back when earlier.
---@param ctx? Context
---@param id string
function help:OpenArticle(ctx, id)
  local article = articles:Get(id)
  if article == nil or not articles:IsShown(article) then
    return
  end
  local from, to = self.state.view == "article" and indexOf(self.state.articleId) or nil, indexOf(id)
  self.direction = (from ~= nil and to ~= nil and to < from) and "back" or "forward"
  self.state = { view = "article", query = self.state.query, articleId = id }
  self:show(ctx)
end

-- ShowHome shows the home.
---@param ctx? Context
function help:ShowHome(ctx)
  self.state = { view = "home", query = "" }
  self.direction = "back"
  self:show(ctx)
end

-- refresh shows the state again in the trees and views shown, and the header.
---@private
---@param ctx Context
---@param trees boolean The tree's choice may have changed.
function help:refresh(ctx, trees)
  for _, view in ipairs(self.views) do
    if view.frame:IsVisible() then
      view:Refresh(ctx)
    end
  end
  if trees then
    for _, tree in ipairs(self.trees) do
      if tree.frame:IsVisible() then
        tree:Refresh(ctx)
      end
    end
  end
  settings:ShowHeading()
end

-- Search shows what the words typed find (the home again once they are gone), as they are typed.
---@param ctx Context
---@param text string
function help:Search(ctx, text)
  text = text or ""
  local was = self.state.view
  if strtrim(text) == "" then
    if was == "home" then
      return
    end
    self.state = { view = "home", query = "" }
    self.direction = "back"
  else
    self.state = { view = "results", query = text }
    self.direction = was == "article" and "back" or "forward"
  end
  self:refresh(ctx, was == "article")
end

-- groupTitle returns the title of an article's group.
---@param article HelpArticleDef
---@return string
local function groupTitle(article)
  local group = articles:GroupOf(article.group)
  return group and group.title or ""
end

---------------------------------------------------------------------------------------------------
-- The tree, in the sidebar.

---@class NextHelpTreeRow: NextSettingsNavRow
---@field kind "heading"|"entry"
---@field entry? table What it shows now: { key, kind, title?, group?, index?, article? }.
---@field y number Where it was placed, down the list.
---@field height number

---@class NextHelpTree
---@field frame Frame
---@field owner Frame The window.
---@field box WowScrollBox
---@field content Frame
---@field entries table[] What it lists, in order.
---@field byKey table<string, NextHelpTreeRow>
---@field free table<string, NextHelpTreeRow[]> Rows nothing is listed in, by kind.
---@field marker Frame The chosen row's fill and bar, gliding from one row to the next.
---@field markerParts NextSettingsNavMarker
---@field markerMotion table
---@field markerKey? string The row it marks.
---@field revealedKey? string The row last scrolled into view: a row newly chosen is, once.
---@field unseen boolean It has not shown since it hid (it fades its rows in when it shows).
---@field width? number
local treeProto = {}
addon:GetModule('Perf'):RegisterPrototype(treeProto, 'NextHelpTree')

-- CreateTree makes the page's list (pages.lua sidebar).
---@param parent Frame
---@param owner Frame
---@return NextHelpTree
function help:CreateTree(parent, owner)
  local frame = CreateFrame("Frame", nil, parent)
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  pixel:SnapScroll(box)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(28)
  box:Init(view)
  local bar = nextScrollBar:Create(box)
  bar:Bind(box)
  local markerParts = nav:CreateMarker(content)
  ---@type NextHelpTree
  local tree = setmetatable({ frame = frame, owner = owner, box = box, content = content, bar = bar, entries = {},
    byKey = {}, free = { heading = {}, entry = {} }, marker = markerParts.frame, markerParts = markerParts,
    markerMotion = {}, unseen = true }, { __index = treeProto })
  markerParts.frame:Hide()
  addon.HookScript(frame, "OnHide", function() tree.unseen, tree.revealedKey = true, nil end)
  table.insert(self.trees, tree)
  sonataNext:RegisterWidget(self)
  return tree
end

function treeProto:Style()
  self:paint()
  nav:PaintMarker(self.markerParts)
  if self.width ~= nil then
    self:Place(self.width, self.height)
  end
end

-- Place lays the tree out in the sidebar under Back, as the window lists its pages under its search box: Search.Gap
-- from its top, Version.Bottom from its bottom.
---@param width number
---@param height number
function treeProto:Place(width, height)
  self.width, self.height = width, height
  local T = style.Theme.Settings
  local frame = self.frame
  local gap, bottom = pixel:Snap(frame, T.Search.Gap), pixel:Snap(frame, T.Version.Bottom)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", 0, 0)
  pixel:Size(frame, width, height)
  self.box:ClearAllPoints()
  self.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -gap)
  self.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottom)
  self.box:SetSize(width, math.max(pixel:Unit(frame), height - gap - bottom))
  self.content:SetWidth(width)
  self:arrange(false)
  self:choose(false)
end

-- Refresh lists the articles shown again (the bags switched) and marks what the page shows: sliding what moved while it
-- shows, fading its rows in one after another when it was hidden.
---@param ctx? Context
function treeProto:Refresh(ctx)
  local _ = ctx
  local appearing = self.unseen or not self.frame:IsVisible()
  self.unseen = false
  self:build()
  self:arrange(not appearing)
  self:paint()
  self:choose(not appearing)
  if appearing then
    self:cascade()
  end
end

-- build lists what the tree shows: Help Home, then each group with articles shown, and its articles.
---@private
function treeProto:build()
  local entries = { { key = "home", kind = "entry", title = L:G("Help Home") } }
  for g, item in ipairs(articles:Tree()) do
    table.insert(entries, { key = "group:" .. item.group.id, kind = "heading", group = item.group, index = g })
    for _, article in ipairs(item.articles) do
      table.insert(entries, { key = "article:" .. article.id, kind = "entry", title = article.title, article = article })
    end
  end
  self.entries = entries
end

-- click does what a row is for: Help Home shows the home, an article opens; a heading is a heading only.
---@private
---@param ctx Context
---@param row NextHelpTreeRow
function treeProto:click(ctx, row)
  local entry = row.entry
  if entry == nil or entry.kind == "heading" then
    return
  elseif entry.key == "home" then
    help:ShowHome(ctx)
  else
    help:OpenArticle(ctx, entry.article.id)
  end
end

-- rowFor returns the row of an entry: its own, else one nothing is listed in, else a new one.
---@private
---@param entry table
---@return NextHelpTreeRow
function treeProto:rowFor(entry)
  local row = self.byKey[entry.key]
  if row ~= nil then
    return row
  end
  row = table.remove(self.free[entry.kind]) --[[@as NextHelpTreeRow]]
  if row == nil then
    row = nav:CreateRow(self.content) --[[@as NextHelpTreeRow]]
    row.kind = entry.kind
    addon.SetScript(row.frame, "OnClick", function(ctx) self:click(ctx, row) end)
    addon.SetScript(row.frame, "OnEnter", function() row.hovered = true self:paintRow(row) end)
    addon.SetScript(row.frame, "OnLeave", function() row.hovered = false self:paintRow(row) end)
  end
  tween:Stop(row)
  row.frame:SetAlpha(1)
  row.frame:EnableMouse(entry.kind ~= "heading")
  row.entry = nil
  self.byKey[entry.key] = row
  return row
end

-- arrange puts each row in its place, one under another as the window's pages are (a heading GroupGap below what is
-- above it); while the tree shows, a row that changed place slides there (Motion, Time.Interaction), a row new to the
-- list fades in, and one leaving it fades out.
---@private
---@param animate boolean
function treeProto:arrange(animate)
  local frame, N = self.owner, style.Theme.Settings.Nav
  local m = nav:Metrics(frame)
  local width = N.ItemWidth and pixel:Length(frame, N.ItemWidth) or (self.width or self.content:GetWidth())
  -- A pass either way, so the next one slides what moves: without animate, everything is placed at once.
  if not animate then
    motion:Forget(self)
  end
  motion:BeginPass(self, style.Time.Interaction, style.StopMotion)
  local listed, fresh, y = {}, 0, 0
  for i, entry in ipairs(self.entries) do
    local row = self:rowFor(entry)
    local new = row.entry == nil
    row.entry = entry
    listed[entry.key] = true
    local height
    if entry.kind == "heading" then
      y = y + m.groupGap + (i > 1 and m.spacing or 0)
      height = m.groupHeight
    else
      y = y + (i > 1 and m.spacing or 0)
      height = m.itemHeight
    end
    row.y, row.height = y, height
    row.frame:SetSize(width, height)
    motion:Place(row.frame, self.content, 0, -y)
    row.frame:Show()
    if new and animate then
      fresh = fresh + 1
      row.frame:SetAlpha(0)
      tween:Play(row, { duration = style.Time.Cascade, ease = style:Ease("Cascade"),
        delay = (fresh - 1) * style.Time.Stagger, from = 0, to = 1, onUpdate = function(v) row.frame:SetAlpha(v) end })
    end
    y = y + height
  end
  motion:EndPass()
  for key, row in pairs(self.byKey) do
    if not listed[key] then
      self.byKey[key] = nil
      row.entry = nil
      row.frame:EnableMouse(false)
      table.insert(self.free[row.kind], row)
      if animate and row.frame:IsShown() then
        tween:Play(row, { duration = style.Time.Interaction / 2, ease = style:Ease("Glide"), from = row.frame:GetAlpha(),
          to = 0, onUpdate = function(v) row.frame:SetAlpha(v) end,
          onDone = function() row.frame:Hide() row.frame:SetAlpha(1) end })
      else
        row.frame:Hide()
      end
    end
  end
  self.content:SetHeight(math.max(1, y))
  self.box:FullUpdate(true)
end

-- paintRow draws a row as the window's list draws its own: a heading, or an entry, the marker drawing the chosen one's
-- fill and bar.
---@private
---@param row NextHelpTreeRow
function treeProto:paintRow(row)
  local entry = row.entry
  if entry == nil then
    return
  end
  local frame = self.owner
  if entry.kind == "heading" then
    -- In capitals, unless the theme writes them as they are (Nav.GroupUpper = false), as the window's headings.
    local title = entry.group.title
    row.label:SetText(style.Theme.Settings.Nav.GroupUpper == false and title or string.upper(title))
    nav:PaintHeading(row, frame, entry.index)
  else
    row.label:SetText(entry.title)
    nav:PaintEntry(row, frame, entry.key == help:ChosenKey(), true)
  end
end

-- paint draws every row.
---@private
function treeProto:paint()
  for _, entry in ipairs(self.entries) do
    local row = self.byKey[entry.key]
    if row ~= nil then
      self:paintRow(row)
    end
  end
end

-- reveal scrolls the tree just enough to show a row (an article opened from a search or a card may be far down it).
---@private
---@param row NextHelpTreeRow
---@param animate boolean
function treeProto:reveal(row, animate)
  local box = self.box
  local offset, visible = box:GetDerivedScrollOffset(), box:GetHeight()
  if row.y < offset then
    box:ScrollToOffset(row.y, not animate)
  elseif row.y + row.height > offset + visible then
    box:ScrollToOffset(row.y + row.height - visible, not animate)
  end
end

-- choose puts the marker on the row of what the page shows, gliding there from the row it was on while the tree shows
-- (Time.TabMarker, as a page's tab marker glides), the tree scrolled to show it; none when that row is not listed.
---@private
---@param animate boolean
function treeProto:choose(animate)
  local marker = self.marker
  local row = self.byKey[help:ChosenKey()]
  nav:PaintMarker(self.markerParts)
  -- Only for a row newly chosen: a restyle places the tree again and keeps where the player scrolled it.
  if row ~= nil and self.revealedKey ~= help:ChosenKey() then
    self:reveal(row, animate)
    self.revealedKey = help:ChosenKey()
  end
  if row == nil then
    tween:Stop(self.markerMotion)
    marker:Hide()
    self.markerKey = nil
    return
  end
  local was = self.markerKey ~= nil and self.byKey[self.markerKey] or nil
  self.markerKey = help:ChosenKey()
  local function settle()
    marker:ClearAllPoints()
    marker:SetAllPoints(row.frame)
  end
  if not animate or not marker:IsShown() or was == nil or was == row then
    tween:Stop(self.markerMotion)
    marker:Show()
    settle()
    return
  end
  local _, rel, _, _, fromY = marker:GetPoint(1)
  if rel ~= self.content then
    fromY = select(5, was.frame:GetPoint(1))
  end
  local width, height = row.frame:GetWidth(), row.height
  tween:Play(self.markerMotion, { duration = style.Time.TabMarker, ease = style:Ease("TabMarker"), from = -(fromY or 0),
    to = row.y, onUpdate = function(y)
      marker:ClearAllPoints()
      marker:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
      marker:SetSize(width, height)
    end, onDone = settle })
end

-- cascade fades the rows in one after another, from the top (the marker with its row), as the tree comes into view.
---@private
function treeProto:cascade()
  local T = style.Time
  for i, entry in ipairs(self.entries) do
    local row = self.byKey[entry.key]
    local delay = math.min(i - 1, 12) * T.Stagger
    row.frame:SetAlpha(0)
    tween:Play(row, { duration = T.Cascade, ease = style:Ease("Cascade"), delay = delay, from = 0, to = 1,
      onUpdate = function(v) row.frame:SetAlpha(v) end })
    if entry.key == self.markerKey then
      self.marker:SetAlpha(0)
      tween:Play(self.marker, { duration = T.Cascade, ease = style:Ease("Cascade"), delay = delay, from = 0, to = 1,
        onUpdate = function(v) self.marker:SetAlpha(v) end })
    end
  end
end

---------------------------------------------------------------------------------------------------
-- The view: the home, the articles found, an article.

---@class NextHelpCard: NextSettingsCard
---@field article? HelpArticleDef
---@field mouse boolean Under the pointer.
---@field rise number How far below its place it is as it rises in, from 1 to 0.

---@class NextHelpLayer
---@field alpha number
---@field dx number How far right of its place it is.

---@class NextHelpView
---@field frame Frame
---@field owner Frame
---@field wide boolean
---@field showing? "home"|"results"|"article"
---@field articleId? string The article shown.
---@field unseen boolean It has not shown since it hid.
---@field search NextInputFrame
---@field hero Frame The prompt and the line under it.
---@field prompt FontString
---@field lead FontString
---@field halo Texture
---@field home Frame The featured articles under their title.
---@field popular FontString
---@field featuredCards NextHelpCard[] Every featured card made.
---@field featured NextHelpCard[] Shown, in order.
---@field results Frame The articles found, scrolling.
---@field empty FontString
---@field cardsById table<string, NextHelpCard>
---@field freeCards NextHelpCard[]
---@field shownCards NextHelpCard[] The articles found, in order.
---@field cursor? number The card the arrow keys chose.
---@field articleScroll Frame An article, scrolling.
---@field article NextHelpArticleView
---@field layers table<string, NextHelpLayer>
---@field p {search: number, enter: number, halo: number} The search box's glide (0 the home, 1 the top), the home's entrance, the halo's strength.
---@field motion table<string, table> Tween keys.
---@field geo? table Where everything goes at the size it was placed.
---@field width? number
---@field height? number
local viewProto = {}
addon:GetModule('Perf'):RegisterPrototype(viewProto, 'NextHelpView')

-- scroller makes a frame holding a scroll box and its bar, with what scrolls (holder.box, holder.content).
---@param parent Frame
---@return Frame
local function scroller(parent)
  local holder = CreateFrame("Frame", nil, parent)
  local box = CreateFrame("Frame", nil, holder, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  pixel:SnapScroll(box)
  box:SetAllPoints(holder)
  local content = CreateFrame("Frame", nil, box)
  content.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(38)
  box:Init(view)
  local bar = nextScrollBar:Create(box)
  bar:Bind(box)
  holder.box, holder.content, holder.bar = box, content, bar
  holder:Hide()
  return holder
end

-- CreateView makes the page's block, filling the page's content.
---@param parent Frame
---@param owner Frame
---@return NextHelpView
function help:CreateView(parent, owner)
  local H = style.Theme.Settings.Help
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetClipsChildren(true)
  ---@type NextHelpView
  local view = setmetatable({ frame = frame, owner = owner, wide = true, unseen = true, featuredCards = {},
    featured = {}, cardsById = {}, freeCards = {}, shownCards = {},
    layers = { results = { alpha = 0, dx = 0 }, article = { alpha = 0, dx = 0 } },
    p = { search = 0, enter = 1, halo = 0 },
    motion = { search = {}, enter = {}, halo = {} }, resultsRoot = {} }, { __index = viewProto })
  view.halo = frame:CreateTexture(nil, "BACKGROUND")
  view.hero = CreateFrame("Frame", nil, frame)
  view.prompt = style:CreateText(view.hero, H.PromptFont)
  view.prompt:SetJustifyH("CENTER")
  view.prompt:SetText(L:G("What do you need help with?"))
  view.lead = style:CreateText(view.hero, H.LeadFont)
  view.lead:SetJustifyH("CENTER")
  view.lead:SetText(L:G("Search all articles, select a card below, or choose a topic from the sidebar."))
  view.home = CreateFrame("Frame", nil, frame)
  view.popular = style:CreateText(view.home, H.SectionFont)
  view.popular:SetJustifyH("LEFT")
  view.results = scroller(frame)
  view.empty = style:CreateText(view.results.content, H.TextFont)
  view.empty:SetJustifyH("LEFT")
  view.empty:SetWordWrap(true)
  view.articleScroll = scroller(frame)
  view.article = helpArticle:Create(view.articleScroll.content, owner, {
    onArticle = function(ctx, id) help:OpenArticle(ctx, id) end,
    onPage = function(ctx, page, tab) settings:Select(page, tab, ctx) end,
  })
  view.search = nextInput:Create(frame, {
    help = L:G("Search help articles"),
    width = function() return style.Theme.Settings.Help.SearchWidth end,
    onChange = function(ctx, text) help:Search(ctx, text) end,
    onEnter = function(ctx) view:OpenChosen(ctx) end,
    onEscape = function(ctx)
      view.search:SetText("")
      help:Search(ctx, "")
    end,
    onArrow = function(_, key) view:MoveCursor(key) end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Atlas = SR.Atlas, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  view.search.frame:SetFrameLevel(frame:GetFrameLevel() + 5)
  addon.HookScript(view.search.frame, "OnEditFocusGained", function() view:Glow(true) end)
  addon.HookScript(view.search.frame, "OnEditFocusLost", function() view:Glow(false) end)
  addon.HookScript(frame, "OnHide", function() view.unseen = true end)
  table.insert(self.views, view)
  sonataNext:RegisterWidget(self)
  view:Style()
  return view
end

-- matchCode returns the color code a matched word is drawn in.
---@return string
local function matchCode()
  local r, g, b = style:RGBA(style.Theme.Settings.Help.MatchColor)
  return format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- marked returns a snippet with its matched words in the match color (a bar the text holds written so it stays one).
---@param text string
---@param spans {[1]: number, [2]: number}[]
---@return string
local function marked(text, spans)
  local code, out, pos = matchCode(), {}, 1
  for _, span in ipairs(spans) do
    table.insert(out, (text:sub(pos, span[1] - 1):gsub("|", "||")))
    table.insert(out, code .. text:sub(span[1], span[2]):gsub("|", "||") .. "|r")
    pos = span[2] + 1
  end
  table.insert(out, (text:sub(pos):gsub("|", "||")))
  return table.concat(out)
end

-- Style draws the view from the theme.
function viewProto:Style()
  local H = style.Theme.Settings.Help
  style:SetFont(self.prompt, H.PromptFont)
  style:SetFont(self.lead, H.LeadFont)
  style:SetFont(self.popular, H.SectionFont)
  style:SetFont(self.empty, H.TextFont)
  local title = L:G("Featured Articles")
  self.popular:SetText(style.Theme.Settings.Content.TitleUpper == false and title or string.upper(title))
  controls:Paint(self.halo, H.Halo)
  self:paintCards()
  -- The article's fonts first, whichever is restyled first: its blocks are measured in them.
  self.article:Style()
  if self.width ~= nil then
    self:Place(self.x or 0, self.y or 0, self.width, self.height)
    self:layoutResults(false)
    self:layoutArticle()
    self:placeAll()
  end
end

-- Measure returns the height of the page's content: the view fills it.
---@param width number
---@return number
function viewProto:Measure(width)
  local _ = width
  local C = style.Theme.Settings.Content
  return math.max(1, settings:ContentHeight() - pixel:Snap(self.frame, C.Top) - pixel:Snap(self.frame, C.Bottom))
end

-- geometry returns where everything goes at a size, in whole pixels (docs/next-pixel-perfect.md): the home centered
-- down the page (the prompt, the line under it, the search box, the featured cards), the box at the top otherwise,
-- and what is found or read under it.
---@private
---@param width number
---@param height number
---@return table
function viewProto:geometry(width, height)
  local H, C = style.Theme.Settings.Help, style.Theme.Settings.Content
  local frame = self.frame
  local pad, gap = pixel:Snap(frame, C.RowPad), pixel:Snap(frame, H.Gap)
  local searchW = math.max(pixel:Unit(frame), math.min(pixel:Length(frame, H.SearchWidth), width - 2 * pad))
  local searchH = pixel:Length(frame, controls:Theme("Input").Height)
  local promptH = pixel:Ceil(frame, pixel:TextHeight(self.prompt))
  local leadH = pixel:Ceil(frame, pixel:TextHeight(self.lead))
  local heroH = promptH + pixel:Snap(frame, H.PromptGap) + leadH
  local m = cards:Metrics(frame)
  local homeW = math.max(pixel:Unit(frame), math.min(width - 2 * pad, pixel:Length(frame, H.MaxWidth)))
  local columns = homeW >= 3 * m.minWidth + 2 * m.gap and 3 or (homeW >= 2 * m.minWidth + m.gap and 2 or 1)
  local count = #self.featured
  local lines = math.ceil(count / columns)
  local titleH = pixel:Ceil(frame, pixel:TextHeight(self.popular))
  local titleGap = pixel:Snap(frame, 8)
  local homeH = count > 0 and (titleH + titleGap + lines * m.height + (lines - 1) * m.gap) or 0
  local total = heroH + gap + searchH + (count > 0 and (gap + homeH) or 0)
  local top = math.max(pad, pixel:Floor(frame, (height - total) / 2))
  local searchY = top + heroH + gap
  local bodyY = pad + searchH + gap
  local S = controls:Theme("ScrollBar")
  local bodyW = math.max(pixel:Unit(frame), width - 2 * pad)
  return {
    width = width, height = height, pad = pad, searchW = searchW, searchH = searchH, heroY = top, heroH = heroH,
    promptH = promptH, homeSearch = { x = pixel:Floor(frame, (width - searchW) / 2), y = searchY },
    topSearch = { x = pad, y = pad }, homeX = pixel:Floor(frame, (width - homeW) / 2), homeY = searchY + searchH + gap,
    homeW = homeW, homeH = homeH, columns = columns, titleH = titleH, titleGap = titleGap,
    cardW = math.max(pixel:Unit(frame), pixel:Floor(frame, (homeW - (columns - 1) * m.gap) / columns)),
    bodyX = pad, bodyY = bodyY, bodyW = bodyW, bodyH = math.max(pixel:Unit(frame), height - bodyY),
    resultW = math.max(pixel:Unit(frame), bodyW - pixel:Length(frame, (S.Width or 12) + (S.Inset or 0) + 4)),
  }
end

-- Place puts the view where the page put it and lays everything out for its size.
---@param x number
---@param y number
---@param width number
---@param height number
function viewProto:Place(x, y, width, height)
  local frame = self.frame
  self.x, self.y = x, y
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  pixel:Size(frame, width, height)
  local resized = self.width ~= frame:GetWidth() or self.height ~= frame:GetHeight()
  self.width, self.height = frame:GetWidth(), frame:GetHeight()
  self.geo = self:geometry(self.width, self.height)
  if resized then
    self:layoutResults(false)
    self:layoutArticle()
  end
  self:placeAll()
  frame:Show()
end

-- placeAll puts the search box, the home, and the results and article layers where they are now in their motions.
---@private
function viewProto:placeAll()
  local g = self.geo
  if g == nil then
    return
  end
  local frame, H = self.frame, style.Theme.Settings.Help
  local p, enter = self.p.search, self.p.enter
  local rise = style.Theme.Motion.Rise
  local homeAlpha = (1 - p) * enter
  local search = self.search.frame
  search:ClearAllPoints()
  search:SetPoint("TOPLEFT", frame, "TOPLEFT", g.homeSearch.x + (g.topSearch.x - g.homeSearch.x) * p,
    -(g.homeSearch.y + (g.topSearch.y - g.homeSearch.y) * p))
  pixel:Width(search, g.searchW)
  self.hero:ClearAllPoints()
  self.hero:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(g.heroY + (1 - enter) * rise - p * rise))
  self.hero:SetSize(g.width, math.max(1, g.heroH))
  -- Text a quarter pixel off its whole pixel (docs/next-pixel-perfect.md), the hero on whole pixels once it settles.
  local leadY = g.promptH + pixel:Snap(frame, H.PromptGap)
  self.prompt:ClearAllPoints()
  pixel:Point(self.prompt, "TOPLEFT", self.hero, "TOPLEFT", 0, 0)
  pixel:Point(self.prompt, "TOPRIGHT", self.hero, "TOPRIGHT", 0, 0)
  self.lead:ClearAllPoints()
  pixel:Point(self.lead, "TOPLEFT", self.hero, "TOPLEFT", 0, -leadY)
  pixel:Point(self.lead, "TOPRIGHT", self.hero, "TOPRIGHT", 0, -leadY)
  self.hero:SetAlpha(homeAlpha)
  self.hero:SetShown(homeAlpha > 0)
  local spread = pixel:Length(frame, H.Halo and H.Halo.Spread or 0)
  self.halo:ClearAllPoints()
  self.halo:SetPoint("TOPLEFT", search, "TOPLEFT", -spread, spread)
  self.halo:SetPoint("BOTTOMRIGHT", search, "BOTTOMRIGHT", spread, -spread)
  local haloAlpha = (H.Halo and H.Halo.Alpha or 0) + ((H.FocusAlpha or 0) - (H.Halo and H.Halo.Alpha or 0)) * self.p.halo
  self.halo:SetAlpha(haloAlpha * homeAlpha)
  self.halo:SetShown(H.Halo ~= false and H.Halo ~= nil and homeAlpha > 0)
  self.home:ClearAllPoints()
  self.home:SetPoint("TOPLEFT", frame, "TOPLEFT", g.homeX, -(g.homeY + (1 - enter) * rise * 2 - p * rise))
  self.home:SetSize(g.homeW, math.max(1, g.homeH))
  self.home:SetAlpha(homeAlpha)
  self.home:SetShown(homeAlpha > 0 and #self.featured > 0)
  self:placeLayers()
  self:layoutHome()
end

-- placeLayers puts the results and the article where they are as they slide and fade.
---@private
function viewProto:placeLayers()
  local g = self.geo
  if g == nil then
    return
  end
  for name, holder in pairs({ results = self.results, article = self.articleScroll }) do
    local layer = self.layers[name]
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", self.frame, "TOPLEFT", g.bodyX + layer.dx, -g.bodyY)
    holder:SetSize(g.bodyW, g.bodyH)
    holder:SetAlpha(layer.alpha)
    holder:SetShown(layer.alpha > 0)
  end
end

-- layoutHome lays the featured cards out under their title, each rising into its place as it fades in.
---@private
function viewProto:layoutHome()
  local g = self.geo
  if g == nil then
    return
  end
  local m = cards:Metrics(self.frame)
  local rise = style.Theme.Motion.Rise
  self.popular:ClearAllPoints()
  pixel:Point(self.popular, "TOPLEFT", self.home, "TOPLEFT", 0, 0)
  for i, card in ipairs(self.featured) do
    local column, line = (i - 1) % g.columns, math.floor((i - 1) / g.columns)
    cards:Place(card, self.home, column * (g.cardW + m.gap),
      g.titleH + g.titleGap + line * (m.height + m.gap) + (card.rise or 0) * rise, g.cardW, m.height)
  end
end

-- makeCard makes a card that opens its article.
---@private
---@param parent Frame
---@return NextHelpCard
function viewProto:makeCard(parent)
  local card = cards:Create(parent) --[[@as NextHelpCard]]
  card.mouse, card.rise = false, 0
  addon.SetScript(card.frame, "OnClick", function(ctx)
    if card.article ~= nil then
      help:OpenArticle(ctx, card.article.id)
    end
  end)
  addon.SetScript(card.frame, "OnEnter", function() card.mouse = true self:paintCards() end)
  addon.SetScript(card.frame, "OnLeave", function() card.mouse = false self:paintCards() end)
  return card
end

-- paintCards draws every card: lit under the pointer, or chosen with the arrow keys.
---@private
function viewProto:paintCards()
  for _, card in ipairs(self.featuredCards) do
    card.hovered = card.mouse
    cards:Paint(card, false)
  end
  for i, card in ipairs(self.shownCards) do
    card.hovered = card.mouse or self.cursor == i
    cards:Paint(card, false)
  end
end

-- fillHome shows the featured articles' cards: their title, their group, their summary.
---@private
function viewProto:fillHome()
  local list = articles:Featured()
  self.featured = {}
  for i = 1, math.min(#list, FEATURED) do
    local article = list[i]
    local card = self.featuredCards[i] or self:makeCard(self.home)
    self.featuredCards[i] = card
    card.article = article
    card.name:SetText(article.title)
    card.status:SetText(groupTitle(article))
    card.text:SetText(article.summary)
    card.frame:Show()
    self.featured[i] = card
  end
  for i = #self.featured + 1, #self.featuredCards do
    self.featuredCards[i].article = nil
    self.featuredCards[i].frame:Hide()
  end
  self:paintCards()
end

-- enterHome rises and fades the home in, its featured cards one after another.
---@private
function viewProto:enterHome()
  local T = style.Time
  self.p.enter = 0
  tween:Play(self.motion.enter, { duration = T.Open, ease = style:Ease("Cascade"), from = 0, to = 1,
    onUpdate = function(v) self.p.enter = v self:placeAll() end })
  for i, card in ipairs(self.featured) do
    card.rise = 1
    card.frame:SetAlpha(0)
    tween:Play(card, { duration = T.Cascade, ease = style:Ease("Cascade"), delay = (T.OpenCascadeDelay or 0) + (i - 1) * T.Stagger,
      from = 0, to = 1, onUpdate = function(v)
        card.frame:SetAlpha(v)
        card.rise = 1 - v
        self:layoutHome()
      end })
  end
end

-- fillResults lists the articles a search finds as cards, best first, the words matched lit: a card of an article
-- still found keeps its card (sliding to its new place while the results show), a new one fades in after those before
-- it; nothing found says so.
---@private
---@param query string
---@param animate boolean
function viewProto:fillResults(query, animate)
  local found = articles:Search(query, RESULTS)
  local listed = {}
  -- While the results show, a card still found slides to its place; coming into view, every card fades in in turn.
  local live = animate and self.showing == "results" and self.layers.results.alpha > 0
  -- A pass either way, so the next one slides what moves: unless the results show, every card is placed at once.
  if not live then
    motion:Forget(self.resultsRoot)
  end
  motion:BeginPass(self.resultsRoot, style.Time.Interaction, style.StopMotion)
  local m = cards:Metrics(self.frame)
  local shown, fresh = {}, 0
  for i, r in ipairs(found) do
    local id = r.article.id
    local card = self.cardsById[id]
    local new = card == nil
    if new then
      card = table.remove(self.freeCards) or self:makeCard(self.results.content)
      self.cardsById[id] = card
    end
    if animate and (new or not live) then
      fresh = fresh + 1
      card.frame:SetAlpha(0)
      tween:Play(card, { duration = style.Time.Cascade, ease = style:Ease("Cascade"), delay = (fresh - 1) * style.Time.Stagger,
        from = 0, to = 1, onUpdate = function(v) card.frame:SetAlpha(v) end })
    elseif not animate then
      tween:Stop(card)
      card.frame:SetAlpha(1)
    end
    listed[id] = true
    card.article = r.article
    card.name:SetText(r.article.title)
    card.status:SetText(groupTitle(r.article))
    card.text:SetText(marked(r.snippet, r.spans))
    motion:Place(card.frame, self.results.content, 0, -((i - 1) * (m.height + m.gap)))
    card.frame:Show()
    shown[i] = card
  end
  motion:EndPass()
  for id, card in pairs(self.cardsById) do
    if not listed[id] then
      self.cardsById[id] = nil
      tween:Stop(card)
      card.article = nil
      card.mouse = false
      card.frame:SetAlpha(1)
      card.frame:Hide()
      table.insert(self.freeCards, card)
    end
  end
  self.shownCards = shown
  self.cursor = nil
  self.empty:SetShown(#found == 0)
  self.empty:SetText(format(L:G("No articles match \"%s\". Try different words, or choose a topic from the sidebar."),
    strtrim(query)))
  self:layoutResults(false)
  -- A new search shows from its top, as the window's own search does, and so does one coming into view.
  if query ~= self.resultsQuery or not live then
    self.results.box:ScrollToOffset(0, true)
  end
  self.resultsQuery = query
  self:paintCards()
end

-- layoutResults sizes the cards for the view's width and the list for its cards; with place, puts each card in its
-- place at once.
---@private
---@param place boolean
function viewProto:layoutResults(place)
  local g = self.geo
  if g == nil then
    return
  end
  local m = cards:Metrics(self.frame)
  for i, card in ipairs(self.shownCards) do
    cards:Layout(card, self.frame, g.resultW, m.height)
    if place then
      motion:Place(card.frame, self.results.content, 0, -((i - 1) * (m.height + m.gap)))
    end
  end
  self.empty:ClearAllPoints()
  pixel:Point(self.empty, "TOPLEFT", self.results.content, "TOPLEFT", 0, 0)
  self.empty:SetWidth(g.resultW)
  local count = #self.shownCards
  local height = count > 0 and (count * m.height + (count - 1) * m.gap) or pixel:Ceil(self.frame, self.empty:GetStringHeight())
  self.results.content:SetSize(g.bodyW, math.max(1, height))
  self.results.box:FullUpdate(true)
end

-- fillArticle shows an article from its top, or where it was scrolled when it is read again (what it draws is read
-- when it shows: coming back into view, it may draw another link or setting).
---@private
---@param id string
---@param ctx? Context
---@param again? boolean The article shown, read again.
function viewProto:fillArticle(id, ctx, again)
  local article = articles:Get(id)
  if article == nil then
    return
  end
  self.article:Show(article, ctx)
  self:layoutArticle()
  if not again then
    self.articleScroll.box:ScrollToOffset(0, true)
  end
end

-- layoutArticle lays the article shown out at the view's width.
---@private
function viewProto:layoutArticle()
  local g = self.geo
  if g == nil or self.article.article == nil then
    return
  end
  local height = self.article:Layout(g.resultW)
  self.articleScroll.content:SetSize(g.bodyW, math.max(1, height))
  self.articleScroll.box:FullUpdate(true)
end

-- slideLayer slides and fades a layer to an alpha and an offset, from a start when given; at once unless animated.
---@private
---@param name string
---@param animate boolean
---@param alpha number
---@param dx number
---@param fromAlpha? number
---@param fromDx? number
function viewProto:slideLayer(name, animate, alpha, dx, fromAlpha, fromDx)
  local layer = self.layers[name]
  if not animate then
    tween:Stop(layer)
    layer.alpha, layer.dx = alpha, dx
    return
  end
  if fromAlpha ~= nil then
    layer.alpha, layer.dx = fromAlpha, fromDx
  end
  local a0, d0 = layer.alpha, layer.dx
  tween:Play(layer, { duration = style.Time.Glide, ease = style:Ease("Glide"), from = 0, to = 1, onUpdate = function(t)
    layer.alpha, layer.dx = a0 + (alpha - a0) * t, d0 + (dx - d0) * t
    self:placeLayers()
  end })
end

-- go moves the view to what it shows: the search box gliding to the top (or back to the home), the results and the
-- article sliding in from the side they come from and out to the side they leave by, the home rising in.
---@private
---@param target "home"|"results"|"article"
---@param animate boolean
---@param direction "forward"|"back"
function viewProto:go(target, animate, direction)
  local from = self.showing
  self.showing = target
  local slide = style.Small.Slide
  if target == "results" then
    if from == "article" then
      self:slideLayer("results", animate, 1, 0, 0, -slide)
    elseif from ~= "results" then
      self:slideLayer("results", animate, 1, 0, 0, 0)
    end
  else
    self:slideLayer("results", animate and from == "results", 0, target == "article" and -slide or 0)
  end
  if target == "article" then
    self:slideLayer("article", animate, 1, 0, 0, (direction == "back" and -1 or 1) * slide)
  else
    self:slideLayer("article", animate and from == "article", 0, target == "results" and slide or 0)
  end
  local to = target == "home" and 0 or 1
  if animate and self.p.search ~= to then
    tween:Play(self.motion.search, { duration = style.Time.Glide, ease = style:Ease("Glide"), from = self.p.search,
      to = to, onUpdate = function(v) self.p.search = v self:placeAll() end })
  else
    tween:Stop(self.motion.search)
    self.p.search = to
  end
end

-- Refresh shows what the page shows now: the home, what a search finds, or an article; moving there while the view
-- shows, the home rising in whenever it comes into view.
---@param ctx? Context
function viewProto:Refresh(ctx)
  help:Settle()
  local s = help.state
  local appearing = self.unseen or not self.frame:IsVisible()
  self.unseen = false
  local animate = not appearing and self.showing ~= nil
  if self.search:GetText() ~= s.query then
    self.search:SetText(s.query)
  end
  local target = s.view
  local newArticle = target == "article" and self.articleId ~= s.articleId
  if target == "results" then
    self:fillResults(s.query, not appearing)
  elseif target == "article" and (newArticle or appearing) then
    self:fillArticle(s.articleId, ctx, not newArticle)
  elseif target == "home" then
    self:fillHome()
  end
  local entering = target == "home" and (self.showing ~= "home" or appearing)
  if target ~= self.showing or newArticle then
    self:go(target, animate, help.direction)
  end
  self.articleId = target == "article" and s.articleId or nil
  if self.geo ~= nil then
    self.geo = self:geometry(self.width, self.height)
  end
  if entering then
    self:enterHome()
  end
  self:placeAll()
end

-- Glow brightens the halo round the search box while it is focused.
---@param focused boolean
function viewProto:Glow(focused)
  tween:Play(self.motion.halo, { duration = style.Time.Hover, ease = style:Ease("Hover"), from = self.p.halo,
    to = focused and 1 or 0, onUpdate = function(v) self.p.halo = v self:placeAll() end })
end

-- MoveCursor chooses the next card found (DOWN) or the one before (UP) with the arrow keys.
---@param key string
function viewProto:MoveCursor(key)
  local count = #self.shownCards
  if count == 0 or (key ~= "DOWN" and key ~= "UP") then
    return
  end
  local at = self.cursor or 0
  at = key == "DOWN" and math.min(count, at + 1) or math.max(1, at - 1)
  self.cursor = at
  self:paintCards()
  local m = cards:Metrics(self.frame)
  local top = (at - 1) * (m.height + m.gap)
  local box = self.results.box
  local offset = box:GetDerivedScrollOffset()
  local visible = self.results:GetHeight()
  if top < offset then
    box:ScrollToOffset(top)
  elseif top + m.height > offset + visible then
    box:ScrollToOffset(top + m.height - visible)
  end
end

-- OpenChosen opens the card the arrow keys chose (Enter), else the first found.
---@param ctx Context
function viewProto:OpenChosen(ctx)
  local card = self.shownCards[self.cursor or 1]
  if self.showing == "results" and card ~= nil and card.article ~= nil then
    help:OpenArticle(ctx, card.article.id)
  end
end
