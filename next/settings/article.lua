local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class NextSettingsRows: AceModule
local rows = addon:GetModule('NextSettingsRows')

---@class NextSettingsCards: AceModule
local cards = addon:GetModule('NextSettingsCards')

---@class SettingsCatalog: AceModule
local catalog = addon:GetModule('SettingsCatalog')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

---@class NextSettingsPages: AceModule
local pages = addon:GetModule('NextSettingsPages')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextHelpArticle draws a help article's body (help.md §5) one block under another, no wider than the theme's
-- Settings.Help.MaxWidth: a heading in capitals (as a settings page's section titles), a paragraph, a list after its
-- bullets, numbered steps, a search example as typed in a field (the input's fill and edge) with what it finds, a
-- tip and a warning over their fill with their accent down their left, a link to another article or to a settings
-- page, and a setting itself (the settings window's own row, which changes it). Under them, the related articles as
-- links and the articles before and after it in the tree as cards. Its blocks are made once per kind and reused.
---@class NextHelpArticle: AceModule
---@field all NextHelpArticleView[]
local helpArticle = addon:NewModule('NextHelpArticle')

---@class (exact) NextHelpArticleOptions
---@field onArticle fun(ctx: Context, id: string) An article's link or card clicked.
---@field onPage fun(ctx: Context, page: string, tab?: string) A settings page's link clicked.

---@class NextHelpBlock
---@field kind string
---@field frame Frame
---@field label? FontString
---@field lines? table[] A list's or steps' lines: { frame, label, bullet?, number? }.
---@field code? FontString An example's text.
---@field field? table An example's field: { fill, edge, icon }.
---@field fill? Texture A tip's or warning's.
---@field accent? Texture
---@field button? NextButtonFrame A link's.
---@field row? NextSettingsRow A setting's.
---@field card? Texture The card behind a setting.
---@field def? HelpBlock What it shows.

---@class NextHelpArticleView
---@field frame Frame What the blocks hang from.
---@field owner Frame The window (a setting's dialogs show over it).
---@field opts NextHelpArticleOptions
---@field article? HelpArticleDef
---@field blocks NextHelpBlock[] Shown, in order.
---@field free table<string, NextHelpBlock[]> Blocks of each kind no article shows now.
---@field settingRows table<string, NextHelpBlock> A setting's block, made once per setting and bag.
---@field relatedTitle FontString
---@field related NextButtonFrame[] Shown, in order.
---@field relatedFree NextButtonFrame[]
---@field previous NextSettingsCard
---@field nextCard NextSettingsCard
---@field before? HelpArticleDef
---@field after? HelpArticleDef
local viewProto = {}
addon:GetModule('Perf'):RegisterPrototype(viewProto, 'NextHelpArticleView')

helpArticle.all = {}

---@param ctx? Context
function helpArticle:ApplyStyle(ctx)
  local _ = ctx
  for _, view in ipairs(self.all) do
    view:Style()
  end
end

-- Create makes an article's view on a frame (a scroll box's content).
---@param parent Frame
---@param owner Frame
---@param opts NextHelpArticleOptions
---@return NextHelpArticleView
function helpArticle:Create(parent, owner, opts)
  local H = style.Theme.Settings.Help
  ---@type NextHelpArticleView
  local view = setmetatable({ frame = parent, owner = owner, opts = opts, blocks = {}, free = {}, settingRows = {},
    related = {}, relatedFree = {} }, { __index = viewProto })
  view.relatedTitle = style:CreateText(parent, H.HeadingFont)
  view.relatedTitle:SetJustifyH("LEFT")
  view.previous = view:neighbour(L:G("Previous"), function() return view.before end)
  view.nextCard = view:neighbour(L:G("Next"), function() return view.after end)
  table.insert(self.all, view)
  sonataNext:RegisterWidget(self)
  return view
end

-- neighbour makes the card of the article before or after this one in the tree.
---@private
---@param status string
---@param target fun(): HelpArticleDef?
---@return NextSettingsCard
function viewProto:neighbour(status, target)
  local card = cards:Create(self.frame)
  card.status:SetText(status)
  style:SetFont(card.status, style.Theme.Settings.Cards.ActiveFont)
  addon.SetScript(card.frame, "OnClick", function(ctx)
    local article = target()
    if article ~= nil then
      self.opts.onArticle(ctx, article.id)
    end
  end)
  addon.SetScript(card.frame, "OnEnter", function() card.hovered = true cards:Paint(card, false) end)
  addon.SetScript(card.frame, "OnLeave", function() card.hovered = false cards:Paint(card, false) end)
  cards:Paint(card, false)
  card.frame:Hide()
  return card
end

-- text makes a font string of a block in a role, left aligned and wrapping.
---@param parent Frame
---@param role string
---@return FontString
local function text(parent, role)
  local t = style:CreateText(parent, role)
  t:SetJustifyH("LEFT")
  t:SetJustifyV("TOP")
  t:SetWordWrap(true)
  return t
end

-- line makes a list's or steps' line: its text, and a bullet or a number before it.
---@param block NextHelpBlock
---@param i number
---@return table
local function line(block, i)
  local entry = block.lines[i]
  if entry ~= nil then
    return entry
  end
  local H = style.Theme.Settings.Help
  entry = { label = text(block.frame, H.TextFont) }
  if block.kind == "list" then
    entry.bullet = block.frame:CreateTexture(nil, "ARTWORK")
  else
    entry.number = style:CreateText(block.frame, H.TextFont)
    entry.number:SetJustifyH("LEFT")
  end
  block.lines[i] = entry
  return entry
end

-- block returns a block of a kind no article shows now, or makes one.
---@private
---@param kind string
---@return NextHelpBlock
function viewProto:block(kind)
  local free = self.free[kind]
  local block = free and table.remove(free)
  if block ~= nil then
    return block
  end
  local H = style.Theme.Settings.Help
  local frame = CreateFrame("Frame", nil, self.frame)
  block = { kind = kind, frame = frame }
  if kind == "heading" then
    block.label = text(frame, H.HeadingFont)
  elseif kind == "text" then
    block.label = text(frame, H.TextFont)
  elseif kind == "list" or kind == "steps" then
    block.lines = {}
  elseif kind == "example" then
    local field = CreateFrame("Frame", nil, frame)
    block.field = { frame = field, fill = field:CreateTexture(nil, "BACKGROUND"), edge = controls:CreateEdge(field),
      icon = field:CreateTexture(nil, "ARTWORK") }
    block.field.fill:SetAllPoints(field)
    block.code = style:CreateText(field, H.ExampleFont)
    block.code:SetJustifyH("LEFT")
    block.code:SetWordWrap(false)
    block.label = text(frame, H.TextFont)
  elseif kind == "tip" or kind == "warning" then
    block.fill = frame:CreateTexture(nil, "BACKGROUND")
    block.fill:SetAllPoints(frame)
    block.accent = frame:CreateTexture(nil, "ARTWORK")
    block.label = text(frame, H.TextFont)
  elseif kind == "see" or kind == "open" then
    block.button = nextButton:Create(frame, { text = "", style = "Link", onClick = function(ctx)
      local def = block.def
      if def == nil then
        return
      elseif def.see ~= nil then
        self.opts.onArticle(ctx, def.see)
      elseif def.open ~= nil then
        self.opts.onPage(ctx, def.open.page, def.open.tab)
      end
    end })
  end
  return block
end

-- bagOf returns the settings bag a setting block names (catalog:Bags() by name), nil for none.
---@param name? string
---@return SettingBag?
local function bagOf(name)
  if name == nil then
    return nil
  end
  for _, bag in ipairs(catalog:Bags()) do
    if bag.name == name then
      return bag
    end
  end
  return nil
end

-- settingBlock returns the block of a setting (the settings window's own row of it), made once per setting and bag;
-- nil for one the bag does not have, or the settings window does not show now (Show Keystone Level is retail's).
---@private
---@param def HelpBlock
---@return NextHelpBlock?
function viewProto:settingBlock(def)
  local bag = bagOf(def.bag)
  if (def.bag ~= nil and bag == nil) or not pages:ShowsSetting(def.setting, bag) then
    return nil
  end
  local key = def.setting .. "\0" .. (def.bag or "")
  local block = self.settingRows[key]
  if block ~= nil then
    return block
  end
  if not catalog:Has(def.setting, bag) then
    return nil
  end
  local frame = CreateFrame("Frame", nil, self.frame)
  block = { kind = "setting", frame = frame, card = frame:CreateTexture(nil, "BACKGROUND") }
  block.card:SetAllPoints(frame)
  block.row = rows:Create(frame, catalog:Get(def.setting, bag), self.owner)
  -- Every setting shown again, as a settings page shows its own after a change: one may follow another (Compact Sections
  -- is used only with Section Columns over 1).
  block.row.onChanged = function(ctx) self:RefreshSettings(ctx) end
  self.settingRows[key] = block
  return block
end

-- RefreshSettings shows the value of every setting the article shows again.
---@param ctx Context
function viewProto:RefreshSettings(ctx)
  for _, block in ipairs(self.blocks) do
    if block.kind == "setting" then
      block.row:Refresh(ctx)
    end
  end
end

-- release puts the blocks shown away.
---@private
function viewProto:release()
  for _, block in ipairs(self.blocks) do
    block.frame:Hide()
    if block.kind ~= "setting" then
      self.free[block.kind] = self.free[block.kind] or {}
      table.insert(self.free[block.kind], block)
    end
  end
  self.blocks = {}
  for _, link in ipairs(self.related) do
    link.frame:Hide()
    table.insert(self.relatedFree, link)
  end
  self.related = {}
end

-- opensShown says whether a link's settings page, and its tab when it names one, are shown now: the window opens another
-- page or tab in place of one it does not show.
---@param open {page: string, tab?: string}
---@return boolean
local function opensShown(open)
  local page = pages:Get(open.page)
  if page == nil or not pages:IsShown(page) then
    return false
  end
  if open.tab == nil then
    return true
  end
  if page.choose ~= nil then
    page.choose()
  end
  for _, tab in ipairs(pages:ShownTabs(page)) do
    if tab.id == open.tab then
      return true
    end
  end
  return false
end

-- kindOf returns which kind of block a piece of an article's body is.
---@param def HelpBlock
---@return string?
local function kindOf(def)
  for _, kind in ipairs({ "heading", "example", "list", "steps", "tip", "warning", "see", "open", "setting" }) do
    if def[kind] ~= nil then
      return kind
    end
  end
  if def.text ~= nil then
    return "text"
  end
  return nil
end

-- Show shows an article's body, its related articles and its neighbours, read now (what is shown changes with the
-- bags in use): a link only to an article, page or tab shown now, a setting only where the settings window shows it,
-- and under Related Articles only those its body does not link already. Lay it out with Layout.
---@param article HelpArticleDef
---@param ctx? Context
function viewProto:Show(article, ctx)
  local C = style.Theme.Settings.Content
  self:release()
  self.article = article
  local linked = {}
  for _, def in ipairs(article.body) do
    local kind = kindOf(def)
    local block
    if kind == "setting" then
      block = self:settingBlock(def)
      if block ~= nil then
        block.row:Refresh(ctx)
      end
    elseif kind == "see" then
      local other = articles:Get(def.see)
      if other ~= nil and articles:IsShown(other) then
        block = self:block(kind)
        linked[def.see] = true
      end
    elseif kind == "open" then
      if opensShown(def.open) then
        block = self:block(kind)
      end
    elseif kind ~= nil then
      block = self:block(kind)
    end
    if block ~= nil then
      block.def = def
      if kind == "heading" then
        -- A search keyword (keyword = true) is typed as it is written.
        block.label:SetText((C.TitleUpper == false or def.keyword) and def.heading or string.upper(def.heading))
      elseif kind == "text" or kind == "tip" or kind == "warning" then
        block.label:SetText(def[kind] or def.text)
      elseif kind == "list" or kind == "steps" then
        for i, value in ipairs(def[kind]) do
          local entry = line(block, i)
          entry.label:SetText(value)
          if entry.number then
            entry.number:SetText(i .. ".")
          end
        end
        block.count = #def[kind]
      elseif kind == "example" then
        block.code:SetText(def.example)
        block.label:SetText(def.text or "")
      elseif kind == "see" then
        block.button:SetText((articles:Get(def.see) --[[@as HelpArticleDef]]).title)
      elseif kind == "open" then
        block.button:SetText(def.open.text)
      end
      block.frame:Show()
      table.insert(self.blocks, block)
    end
  end
  for _, other in ipairs(articles:Related(article)) do
    if not linked[other.id] then
      local link = table.remove(self.relatedFree) or nextButton:Create(self.frame, { text = "", style = "Link",
        onClick = function() end })
      link:SetText(other.title)
      link.onClick = function(ctx2) self.opts.onArticle(ctx2, other.id) end
      link.frame:Show()
      table.insert(self.related, link)
    end
  end
  self.before, self.after = articles:Adjacent(article)
  for _, pair in ipairs({ { self.previous, self.before }, { self.nextCard, self.after } }) do
    local card, other = pair[1], pair[2]
    card.frame:SetShown(other ~= nil)
    if other ~= nil then
      card.name:SetText(other.title)
      card.text:SetText(other.summary)
    end
  end
  self:Style()
end

-- Style draws every block shown from the theme.
function viewProto:Style()
  local H, I = style.Theme.Settings.Help, controls:Theme("Input")
  local SR = style.Theme.Settings.Search
  style:SetFont(self.relatedTitle, H.HeadingFont)
  for _, block in ipairs(self.blocks) do
    local kind = block.kind
    if kind == "heading" then
      style:SetFont(block.label, H.HeadingFont)
    elseif kind == "text" or kind == "tip" or kind == "warning" then
      style:SetFont(block.label, H.TextFont)
    end
    if kind == "tip" or kind == "warning" then
      local look = kind == "tip" and H.Tip or H.Warning
      controls:Paint(block.fill, look.Fill)
      controls:Paint(block.accent, look.Accent)
    elseif kind == "list" or kind == "steps" then
      for i = 1, block.count or 0 do
        local entry = block.lines[i]
        style:SetFont(entry.label, H.TextFont)
        if entry.bullet then
          controls:Paint(entry.bullet, H.Bullet)
        else
          style:SetFont(entry.number, H.TextFont)
        end
      end
    elseif kind == "example" then
      controls:Paint(block.field.fill, I.Fill)
      controls:PaintEdge(block.field.edge, I.Edge, I.Edge.Idle)
      controls:Paint(block.field.icon, { Texture = SR.Icon, Atlas = SR.Atlas, Color = SR.IconColor })
      style:SetFont(block.code, H.ExampleFont)
      style:SetFont(block.label, H.TextFont)
    elseif kind == "setting" then
      controls:Paint(block.card, style.Theme.Settings.Content.Card)
    end
  end
  for _, card in ipairs({ self.previous, self.nextCard }) do
    cards:Paint(card, false)
    style:SetFont(card.status, style.Theme.Settings.Cards.ActiveFont)
  end
end

-- textHeight sets a text's width and returns its height in whole pixels.
---@param frame Frame
---@param t FontString
---@param width number
---@return number
local function textHeight(frame, t, width)
  t:SetWidth(math.max(pixel:Unit(frame), width))
  return pixel:Ceil(frame, math.max(t:GetStringHeight(), pixel:TextHeight(t)))
end

-- layoutBlock lays a block's parts out at a width and returns its height, in whole pixels (docs/next-pixel-perfect.md).
---@private
---@param block NextHelpBlock
---@param width number
---@return number
function viewProto:layoutBlock(block, width)
  local H = style.Theme.Settings.Help
  local frame = self.frame
  local kind = block.kind
  if kind == "heading" or kind == "text" then
    block.label:ClearAllPoints()
    pixel:Point(block.label, "TOPLEFT", block.frame, "TOPLEFT", 0, 0)
    return textHeight(frame, block.label, width)
  elseif kind == "list" or kind == "steps" then
    local indent = pixel:Snap(frame, H.ListIndent)
    local between = pixel:Snap(frame, 4)
    local y = 0
    for i = 1, block.count do
      local entry = block.lines[i]
      local height = textHeight(frame, entry.label, width - indent)
      entry.label:ClearAllPoints()
      pixel:Point(entry.label, "TOPLEFT", block.frame, "TOPLEFT", indent, -y)
      entry.label:Show()
      local lineHeight = pixel:Ceil(frame, pixel:TextHeight(entry.label))
      if entry.bullet then
        local size = pixel:Length(frame, H.Bullet.Size or 4)
        entry.bullet:ClearAllPoints()
        entry.bullet:SetPoint("TOPLEFT", block.frame, "TOPLEFT", pixel:Floor(frame, (indent - size) / 2),
          -(y + pixel:Middle(frame, lineHeight, size)))
        entry.bullet:SetSize(size, size)
        entry.bullet:Show()
      else
        entry.number:ClearAllPoints()
        pixel:Point(entry.number, "TOPLEFT", block.frame, "TOPLEFT", 0, -y)
        entry.number:Show()
      end
      y = y + height + (i < block.count and between or 0)
    end
    for i = block.count + 1, #block.lines do
      local entry = block.lines[i]
      entry.label:Hide()
      if entry.bullet then entry.bullet:Hide() else entry.number:Hide() end
    end
    return y
  elseif kind == "example" then
    local I, SR = controls:Theme("Input"), style.Theme.Settings.Search
    local field = block.field.frame
    local height = pixel:Length(frame, I.Height)
    local pad = pixel:Length(frame, I.Padding)
    local icon = pixel:Length(frame, SR.IconSize)
    field:ClearAllPoints()
    field:SetPoint("TOPLEFT", block.frame, "TOPLEFT", 0, 0)
    field:SetSize(width, height)
    block.field.icon:ClearAllPoints()
    block.field.icon:SetPoint("TOPLEFT", field, "TOPLEFT", pad, -pixel:Middle(frame, height, icon))
    block.field.icon:SetSize(icon, icon)
    block.code:ClearAllPoints()
    pixel:Row(block.code, "TOPLEFT", field, pad + icon + pixel:Snap(frame, 6), height)
    local y = height
    if block.label:GetText() ~= nil and block.label:GetText() ~= "" then
      y = y + pixel:Snap(frame, 6)
      block.label:ClearAllPoints()
      pixel:Point(block.label, "TOPLEFT", block.frame, "TOPLEFT", 0, -y)
      y = y + textHeight(frame, block.label, width)
      block.label:Show()
    else
      block.label:Hide()
    end
    return y
  elseif kind == "tip" or kind == "warning" then
    local pad, accent = pixel:Snap(frame, H.NotePad), pixel:Length(frame, H.AccentWidth)
    block.accent:ClearAllPoints()
    block.accent:SetPoint("TOPLEFT", block.frame, "TOPLEFT", 0, 0)
    block.accent:SetPoint("BOTTOMLEFT", block.frame, "BOTTOMLEFT", 0, 0)
    block.accent:SetWidth(accent)
    block.label:ClearAllPoints()
    pixel:Point(block.label, "TOPLEFT", block.frame, "TOPLEFT", accent + pad, -pad)
    return textHeight(frame, block.label, width - accent - 2 * pad) + 2 * pad
  elseif kind == "see" or kind == "open" then
    -- Restyled before it is measured: a theme applied may reach the article before the buttons (patterns-ui-themes.md).
    block.button:Style()
    block.button.frame:ClearAllPoints()
    block.button.frame:SetPoint("TOPLEFT", block.frame, "TOPLEFT", 0, 0)
    return block.button.frame:GetHeight()
  elseif kind == "setting" then
    local height = pixel:Ceil(frame, block.row:Measure(width))
    block.row:Place(0, 0, width, height)
    return height
  end
  return 0
end

-- Layout lays the article out at a width (at most MaxWidth) and returns its height: its blocks BlockGap apart (a
-- heading HeadingGap below what is above it), then its related articles under their heading, then its neighbours'
-- cards side by side.
---@param width number
---@return number
function viewProto:Layout(width)
  local H = style.Theme.Settings.Help
  local frame = self.frame
  width = pixel:Floor(frame, math.min(width, pixel:Length(frame, H.MaxWidth)))
  local gap, headingGap = pixel:Snap(frame, H.BlockGap), pixel:Snap(frame, H.HeadingGap)
  local y = 0
  for i, block in ipairs(self.blocks) do
    if i > 1 then
      y = y + (block.kind == "heading" and headingGap or gap)
    end
    local height = self:layoutBlock(block, width)
    block.frame:ClearAllPoints()
    block.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
    block.frame:SetSize(width, math.max(pixel:Unit(frame), height))
    y = y + height
  end
  self.relatedTitle:SetShown(#self.related > 0)
  if #self.related > 0 then
    y = y + headingGap
    self.relatedTitle:SetText(style.Theme.Settings.Content.TitleUpper == false and L:G("Related Articles")
      or string.upper(L:G("Related Articles")))
    self.relatedTitle:ClearAllPoints()
    pixel:Point(self.relatedTitle, "TOPLEFT", frame, "TOPLEFT", 0, -y)
    y = y + pixel:Ceil(frame, pixel:TextHeight(self.relatedTitle)) + pixel:Snap(frame, 6)
    for _, link in ipairs(self.related) do
      link.frame:ClearAllPoints()
      link.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
      y = y + link.frame:GetHeight()
    end
  end
  if self.before ~= nil or self.after ~= nil then
    local m = cards:Metrics(frame)
    y = y + headingGap
    local half = pixel:Floor(frame, (width - m.gap) / 2)
    if self.before ~= nil then
      cards:Place(self.previous, frame, 0, y, half, m.height)
    end
    if self.after ~= nil then
      cards:Place(self.nextCard, frame, width - half, y, half, m.height)
      self.nextCard.status:SetJustifyH("RIGHT")
    end
    y = y + m.height
  end
  return y
end
