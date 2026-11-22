local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextSettingsPages: AceModule
local pages = addon:GetModule('NextSettingsPages')

---@class HelpSearch: AceModule
local search = addon:GetModule('HelpSearch')

-- HelpArticles holds the help's articles (help.md §1), in groups, in the order they are defined (help/articles/*.lua):
-- what the Help page's sidebar lists as a tree, its home page features, and its search ranks. An article is shown only
-- with the bags it is about (design, as a settings page) and while it says so (shown: a client without a guild bank
-- has no guild bank article); the tree, the search and an article's related articles leave out the rest.
---@class HelpArticles: AceModule
---@field groups HelpGroupDef[]
---@field list HelpArticleDef[]
local articles = addon:NewModule('HelpArticles')

---@class (exact) HelpGroupDef
---@field id string
---@field title string

-- A piece of an article's body, one of: a heading, a paragraph, a list, numbered steps, a search example (its text
-- typed as is, never translated, and what it finds), a tip, a warning, a link that opens a settings page (and tab),
-- a link to another article, or a setting shown as its own row, which changes it.
---@class (exact) HelpBlock
---@field heading? string
---@field keyword? boolean With heading: a search keyword (a field, an operator, AND, a function, a player value), never translated, shown as it is typed.
---@field text? string A paragraph; with example, what the example finds.
---@field list? string[]
---@field steps? string[]
---@field example? string
---@field tip? string
---@field warning? string
---@field open? {page: string, tab?: string, text: string}
---@field see? string An article's id.
---@field setting? string A settings catalog id.
---@field bag? string With setting: the name of the bag a bag's own setting is bound to (SettingsCatalog:Bags).

---@class (exact) HelpArticleDef
---@field id string
---@field group string A group's id.
---@field title string
---@field summary string One sentence: under its title, and in search results.
---@field body HelpBlock[]
---@field keywords? string[] Words and names a player may search for it by.
---@field questions? string[] Questions a player may ask that it answers.
---@field related? string[] Other articles' ids, listed under it.
---@field featured? boolean On the Help page's home.
---@field design? BagDesign Shown only while these bags are in use.
---@field shown? fun(): boolean Shown only while it says so.
---@field settings? string[] The settings catalog's ids it explains (spec/help/content_spec.lua checks every one is).
---@field pages? string[] The settings pages ("page") and tabs ("page:tab") it explains.

---@class (exact) HelpResult
---@field article HelpArticleDef
---@field score number
---@field snippet string
---@field spans {[1]: number, [2]: number}[]

-- How many characters of an article a search result shows.
local SNIPPET = 140

articles.groups = {}
articles.list = {}
-- Changes with every article defined, so the next search indexes again.
articles.version = 0

-- Group adds a group after the others (or replaces the one with its id, in its place).
---@param def HelpGroupDef
function articles:Group(def)
  for i, group in ipairs(self.groups) do
    if group.id == def.id then
      self.groups[i] = def
      return
    end
  end
  table.insert(self.groups, def)
end

---@param id string
---@return HelpGroupDef?
function articles:GroupOf(id)
  for _, group in ipairs(self.groups) do
    if group.id == id then
      return group
    end
  end
  return nil
end

-- Define adds an article after the others in its group (or replaces the one with its id, in its place). Its group
-- must be defined first.
---@param def HelpArticleDef
function articles:Define(def)
  if self:GroupOf(def.group) == nil then
    error("the help has no group named " .. tostring(def.group) .. " for " .. tostring(def.id))
  end
  self.version = self.version + 1
  for i, article in ipairs(self.list) do
    if article.id == def.id then
      self.list[i] = def
      return
    end
  end
  table.insert(self.list, def)
end

-- Clear forgets every group and article (specs).
function articles:Clear()
  self.groups = {}
  self.list = {}
  self.version = self.version + 1
  self.index, self.indexKey = nil, nil
end

---@param id string
---@return HelpArticleDef?
function articles:Get(id)
  for _, article in ipairs(self.list) do
    if article.id == id then
      return article
    end
  end
  return nil
end

-- IsShown says whether an article is shown now: with the bags in use, and while it says so.
---@param article HelpArticleDef
---@return boolean
function articles:IsShown(article)
  return pages:InDesign(article) and (article.shown == nil or article.shown() == true)
end

---@class (exact) HelpTreeGroup
---@field group HelpGroupDef
---@field articles HelpArticleDef[]

-- Tree returns the groups that have articles shown, in order, each with its articles shown, in order.
---@return HelpTreeGroup[]
function articles:Tree()
  local tree = {}
  for _, group in ipairs(self.groups) do
    local list = {}
    for _, article in ipairs(self.list) do
      if article.group == group.id and self:IsShown(article) then
        table.insert(list, article)
      end
    end
    if #list > 0 then
      table.insert(tree, { group = group, articles = list })
    end
  end
  return tree
end

-- Shown returns every article shown, in the tree's order.
---@return HelpArticleDef[]
function articles:Shown()
  local list = {}
  for _, entry in ipairs(self:Tree()) do
    for _, article in ipairs(entry.articles) do
      table.insert(list, article)
    end
  end
  return list
end

-- Featured returns the articles marked for the home page that are shown, in the tree's order.
---@return HelpArticleDef[]
function articles:Featured()
  local list = {}
  for _, article in ipairs(self:Shown()) do
    if article.featured then
      table.insert(list, article)
    end
  end
  return list
end

-- Related returns an article's related articles that are shown, in its order.
---@param article HelpArticleDef
---@return HelpArticleDef[]
function articles:Related(article)
  local list = {}
  for _, id in ipairs(article.related or {}) do
    local other = self:Get(id)
    if other ~= nil and self:IsShown(other) then
      table.insert(list, other)
    end
  end
  return list
end

-- Adjacent returns the articles shown before and after an article in the tree (nil at either end).
---@param article HelpArticleDef
---@return HelpArticleDef? before
---@return HelpArticleDef? after
function articles:Adjacent(article)
  local list = self:Shown()
  for i, other in ipairs(list) do
    if other == article then
      return list[i - 1], list[i + 1]
    end
  end
  return nil, nil
end

-- textsOf returns the text of each block of an article's body a player reads, in order (headings left out).
---@param article HelpArticleDef
---@return string[]
local function textsOf(article)
  local list = {}
  for _, block in ipairs(article.body) do
    for _, key in ipairs({ "text", "tip", "warning" }) do
      if block[key] ~= nil then
        table.insert(list, block[key])
      end
    end
    for _, key in ipairs({ "list", "steps" }) do
      for _, line in ipairs(block[key] or {}) do
        table.insert(list, line)
      end
    end
  end
  return list
end

-- TextOf returns an article's text for its snippet: its summary, then its body's paragraphs, lists, steps, tips and
-- warnings, a line each.
---@param article HelpArticleDef
---@return string
function articles:TextOf(article)
  local list = { article.summary }
  for _, text in ipairs(textsOf(article)) do
    table.insert(list, text)
  end
  return table.concat(list, "\n")
end

-- Docs returns the articles shown as the search indexes them: each field's text (the body with its examples as
-- typed, the headings apart).
---@return HelpSearchDoc[]
function articles:Docs()
  local docs = {}
  for _, article in ipairs(self:Shown()) do
    local headings, body = {}, { article.summary }
    for _, block in ipairs(article.body) do
      if block.heading ~= nil then
        table.insert(headings, block.heading)
      end
      if block.example ~= nil then
        table.insert(body, block.example)
      end
      if block.open ~= nil then
        table.insert(body, block.open.text)
      end
    end
    for _, text in ipairs(textsOf(article)) do
      table.insert(body, text)
    end
    table.insert(docs, { id = article.id, fields = {
      title = { article.title }, keywords = article.keywords or {}, questions = article.questions or {},
      headings = headings, body = body,
    } })
  end
  return docs
end

-- indexNow returns the index of the articles shown, made again when an article was defined since, or the articles
-- shown changed (the bags switched, a guild bank appeared).
---@private
---@return HelpIndex
function articles:indexNow()
  local ids = { tostring(self.version) }
  for _, article in ipairs(self:Shown()) do
    table.insert(ids, article.id)
  end
  local key = table.concat(ids, "\0")
  if self.index == nil or self.indexKey ~= key then
    self.index = search:Build(self:Docs())
    self.indexKey = key
  end
  return self.index
end

-- Search ranks the articles shown for what was typed, best first, at most limit of them, each with its snippet.
---@param text string
---@param limit? number
---@return HelpResult[]
function articles:Search(text, limit)
  local results, matched = self:indexNow():Query(text, { limit = limit })
  local out = {}
  for i, r in ipairs(results) do
    local article = self:Get(r.id) --[[@as HelpArticleDef]]
    local snippet, spans = search:Snippet(self:TextOf(article), matched, SNIPPET)
    out[i] = { article = article, score = r.score, snippet = snippet, spans = spans }
  end
  return out
end
