local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class QueryParser: AceModule
local QueryParser = addon:GetModule('QueryParser')

---@class Search: AceModule
local search = addon:GetModule('Search')

-- SearchCompletion offers what may come at a search rule's cursor (search-completion.md): the fields, NOT, player
-- values and functions a condition starts with, the operators a field takes, the values it is compared with, and
-- AND and OR after a whole condition. Each suggestion carries the query it makes and how many of the items given
-- that query matches then: a value's, the whole rule with it; a field's, the items the rest of the rule leaves that
-- have the field (its word alone, for a true-or-false field: the items where it is true); 0 for what makes no
-- whole rule (an operator, AND, OR, NOT, a player value, a function).
---@class SearchCompletion: AceModule
local completion = addon:NewModule('SearchCompletion')

---@class SearchSuggestion
---@field label string What its row shows.
---@field kind "field"|"operator"|"value"|"keyword"|"player"|"function"
---@field text string The query with it taken.
---@field cursor number Where the cursor goes then (the bytes before it).
---@field count number How many of the items given the query then matches.
---@field chain? boolean The next suggestions show at once (an operator after a field, a value after an operator).
---@field score number How close it is to what is typed (4 the same, 3 starting with it, 2 a word in it starting with it, 1 nothing typed).
---@field rank number Its place among the suggestions as they were made, for the ones as close.

-- At most this many suggestions, the closest.
local MAX = 50

-- SENTINEL stands for a field's word while its suggestion is counted: a word that names no field.
local SENTINEL = "__bbcompletionfield__"

-- The operators each kind of field takes, in the order they are offered. An expansion also compares in release
-- order (search-indexing.md §8).
local OPERATORS = {
  text = { "=", "==", "!=", "~=", "%=" },
  number = { "=", "!=", "<", "<=", ">", ">=" },
  boolean = { "=", "!=" },
  ordered = { "=", "==", "!=", "~=", "%=", "<", "<=", ">", ">=" },
}

-- ORDERED are the operators after which numbers are offered from the lowest, not the most common first.
local ORDERED = { ["<"] = true, ["<="] = true, [">"] = true, [">="] = true }

-- NOT_A_WORD are the characters that keep a value from being read as one word (QueryParser:Lexer), and OWN_WORDS the
-- words that are operators of their own. A backslash is part of a word: quoted, one at the end would escape the
-- closing quote.
local NOT_A_WORD = "[%s%c()=!<>,\"'%%~]"
local OWN_WORDS = { AND = true, OR = true, NOT = true, ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true }

-- scoreOf says how close a suggestion is to what is typed: 4 the same, 3 starting with it, 2 (with words) a word
-- in it starting with it after a space or a sign, 0 not at all; 1 when nothing is typed. Without case.
---@param label string
---@param typed string
---@param words? boolean
---@return number
local function scoreOf(label, typed, words)
  if typed == "" then
    return 1
  end
  local l, t = string.lower(label), string.lower(typed)
  if l == t then
    return 4
  end
  if l:sub(1, #t) == t then
    return 3
  end
  if words then
    local at = l:find("[%s%p]")
    while at ~= nil do
      if l:sub(at + 1, at + #t) == t then
        return 2
      end
      at = l:find("[%s%p]", at + 1)
    end
  end
  return 0
end

-- valueText returns a value as a query writes it: in the quote it was typed in, or in double quotes when it is not
-- one word.
---@param value any
---@param quote? string
---@return string
local function valueText(value, quote)
  local text = tostring(value)
  if quote == nil and text ~= "" and not text:find(NOT_A_WORD) and not OWN_WORDS[string.upper(text)] then
    return text
  end
  quote = quote or '"'
  return quote .. (text:gsub(quote, "\\" .. quote)) .. quote
end

-- rarityNames returns the quality names a rarity is compared with (core/constants.lua: each in the client's
-- language, lower case), by quality.
---@return string[]
local function rarityNames()
  local list = {}
  for name, quality in pairs(const.ITEM_QUALITY_TO_ENUM) do
    if name == string.lower(name) then
      table.insert(list, { name = name, quality = quality })
    end
  end
  table.sort(list, function(a, b)
    if a.quality ~= b.quality then
      return a.quality < b.quality
    end
    return a.name < b.name
  end)
  local names = {}
  for i, entry in ipairs(list) do
    names[i] = entry.name
  end
  return names
end

-- namesOf returns a map's names, each once, ordered by their lowest key (an expansion's ID, a binding's scope), the
-- empty ones left out.
---@param map table<number, string>
---@return string[]
local function namesOf(map)
  local lowest = {}
  for key, name in pairs(map) do
    if name ~= "" and (lowest[name] == nil or key < lowest[name]) then
      lowest[name] = key
    end
  end
  local names = {}
  for name in pairs(lowest) do
    table.insert(names, name)
  end
  table.sort(names, function(a, b) return lowest[a] < lowest[b] end)
  return names
end

-- FIXED are the fields compared with names of their own, every one offered whatever the items have.
local FIXED = {
  rarity = rarityNames,
  expansion = function() return namesOf(const.BRIEF_EXPANSION_MAP) end,
  binding = function() return namesOf(const.BINDING_MAP) end,
  appearance = function() return { "known", "unknown" } end,
  source = function() return { "known", "unknown" } end,
}

-- NO_VALUES are the text fields whose values are never offered: a whole tooltip, an item's own GUID.
local NO_VALUES = { tooltip = true, guid = true }

---@param name string The word after "player.", lower case.
---@return string? kind
local function playerKind(name)
  for _, value in ipairs(search.PLAYER_VALUES) do
    if value.name == name then
      return value.kind
    end
  end
  return nil
end

---@return string[]
local function functionNames()
  local names = {}
  for name in pairs(QueryParser.FUNCTIONS) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

---@param found table<string, any>
---@param within table<string, any>
---@return number
local function countIn(found, within)
  local n = 0
  for slotkey in pairs(found) do
    if within[slotkey] then
      n = n + 1
    end
  end
  return n
end

-- replaceSentinel puts set where the sentinel word is a condition of its own; found says whether it was.
---@param node QueryNode
---@param set QueryNode
---@return QueryNode, boolean
local function replaceSentinel(node, set)
  if node.type == "term" and node.value == SENTINEL and not node.quoted then
    return set, true
  end
  local found = false
  if node.type == "logical" then
    for _, key in ipairs({ "expression", "left", "right" }) do
      if node[key] ~= nil then
        local here
        node[key], here = replaceSentinel(node[key], set)
        found = found or here
      end
    end
  end
  return node, found
end

-- CountOf returns how many of the items given (slot keys) a query matches: 0 for one that cannot be read.
---@param query string
---@param within table<string, any>
---@return number
function completion:CountOf(query, within)
  local ok, found = pcall(search.Search, search, query)
  if not ok then
    return 0
  end
  return countIn(found, within)
end

-- CountWithField returns how many of the items given the query matches with the field's word, from..to, standing
-- for the items that have a value for the field (Search:HasValue): what the rest of the rule leaves that has it.
---@param text string
---@param from number
---@param to number
---@param field string
---@param within table<string, any>
---@return number
function completion:CountWithField(text, from, to, field, within)
  local ast = QueryParser:Query(text:sub(1, from - 1) .. SENTINEL .. text:sub(to + 1))
  if ast == nil then
    return 0
  end
  local node, found = replaceSentinel(ast, { type = "set", set = search:HasValue(field, within) })
  if not found then
    return 0
  end
  local ok, result = pcall(search.EvaluateQuery, search, node)
  if not ok then
    return 0
  end
  return countIn(result, within)
end

-- ValueCounter returns a function counting, among the items given, what the query matches with a value in place of
-- the one at the cursor, or nil when the query cannot be read without its comparison. The rest of the query is
-- evaluated once, its comparison standing for every item (all) and for none (none): whether an item matches follows
-- only whether it matches the comparison (AND, OR and NOT work item by item), so each value costs its comparison
-- alone: the items that do not match none, then each item the comparison matches counted as all says, not none.
---@param text string
---@param c QueryContext A value's, with its comparison's start.
---@param within table<string, any>
---@return (fun(value: string): number?)?
function completion:ValueCounter(text, c, within)
  if c.start == nil then
    return nil
  end
  local function restWith(set)
    local ast = QueryParser:Query(text:sub(1, c.start - 1) .. SENTINEL .. text:sub(c.to + 1))
    if ast == nil then
      return nil
    end
    local node, found = replaceSentinel(ast, { type = "set", set = set })
    if not found then
      return nil
    end
    local ok, result = pcall(search.EvaluateQuery, search, node)
    return ok and result or nil
  end
  local all, none = restWith(search:Universe()), restWith({})
  if all == nil or none == nil then
    return nil
  end
  local base = countIn(none, within)
  local numbers
  local head = text:sub(c.start, c.from - 1)
  return function(value)
    if numbers == nil and value:find("^%-?[%d%.]+$") then
      numbers = self:numberCounter(c, within, all, none, base) or false
    end
    local fast = numbers and numbers(value) or nil
    if fast ~= nil then
      return fast
    end
    local ast = QueryParser:Query(head .. value)
    if ast == nil then
      return nil
    end
    local ok, matched = pcall(search.EvaluateQuery, search, ast)
    if not ok then
      return nil
    end
    local n = base
    for slotkey in pairs(matched) do
      if within[slotkey] and (all[slotkey] == true) ~= (none[slotkey] == true) then
        n = n + (all[slotkey] and 1 or -1)
      end
    end
    return n
  end
end

-- NUMBER_OPERATORS are the comparisons of a number field the index answers from its numbers (search:EvaluateAST:
-- == and ~= as = and !=, which the items without a value match).
local NUMBER_OPERATORS = { ["="] = "=", ["=="] = "=", ["!="] = "!=", ["~="] = "!=", ["<"] = "<", ["<="] = "<=",
  [">"] = ">", [">="] = ">=" }

-- numberCounter returns, for a number field's comparison, a function counting a plain number in its place from its
-- items' values put in order once (a binary search each), with what the rest of the rule matches for every item
-- (all) and for none (none); nil for any other comparison, and the function nil for a value not a plain number.
---@private
---@param c QueryContext
---@param within table<string, any>
---@param all table<string, boolean>
---@param none table<string, boolean>
---@param base number How many of the items given none holds.
---@return (fun(value: string): number?)?
function completion:numberCounter(c, within, all, none, base)
  local field = search:FieldOf(c.field)
  local op = NUMBER_OPERATORS[c.operator]
  if field == nil or field.kind ~= "number" or field.list or op == nil then
    return nil
  end
  local values = search:ValuesBySlot(c.field, within)
  -- Each item's difference: 1 where the rule matches it only when it matches the comparison, -1 only when not.
  local entries, byValue, total = {}, {}, 0
  for slotkey in pairs(within) do
    local d = (all[slotkey] and 1 or 0) - (none[slotkey] and 1 or 0)
    total = total + d
    local v = values[slotkey]
    if type(v) == "number" then
      table.insert(entries, { v = v, d = d })
      byValue[v] = (byValue[v] or 0) + d
    end
  end
  table.sort(entries, function(a, b) return a.v < b.v end)
  local sums = { [0] = 0 }
  for i, e in ipairs(entries) do
    sums[i] = sums[i - 1] + e.d
  end
  -- below returns how many values are less than n (or, with equal, no greater).
  local function below(n, equal)
    local lo, hi = 1, #entries + 1
    while lo < hi do
      local mid = math.floor((lo + hi) / 2)
      local v = entries[mid].v
      if v < n or (equal and v == n) then
        lo = mid + 1
      else
        hi = mid
      end
    end
    return lo - 1
  end
  return function(value)
    local n = value:find("^%-?[%d%.]+$") and tonumber(value) or nil
    if n == nil then
      return nil
    end
    if op == "=" then
      return base + (byValue[n] or 0)
    elseif op == "!=" then
      return base + total - (byValue[n] or 0)
    elseif op == "<" then
      return base + sums[below(n)]
    elseif op == "<=" then
      return base + sums[below(n, true)]
    elseif op == ">" then
      return base + sums[#entries] - sums[below(n, true)]
    end
    return base + sums[#entries] - sums[below(n)]
  end
end

-- Suggest returns the suggestions at a query's cursor, the closest first (at most MAX), each counted among the
-- items given, and what the query expects there (QueryParser:Context: what a suggestion replaces). Nothing for a
-- condition or AND and OR until a letter is typed, for a quoted word that is not a value, inside a function's
-- arguments after one, or when the only suggestion is what is typed already.
---@param text string
---@param cursor number The bytes before the cursor.
---@param within table<string, any> The items counted, by slot key.
---@return SearchSuggestion[], QueryContext?
function completion:Suggest(text, cursor, within)
  local c = QueryParser:Context(text, cursor)
  if c == nil then
    return {}, nil
  end
  local list, rank = {}, 0
  local nextChar = text:sub(c.to + 1, c.to + 1)

  -- offer adds a suggestion that puts insert where the context replaces, when it is close to what is typed.
  ---@param label string
  ---@param kind string
  ---@param insert string
  ---@param opts {chain?: boolean, open?: boolean, words?: boolean, field?: SearchField}
  local function offer(label, kind, insert, opts)
    local score = scoreOf(label, c.prefix, opts.words)
    if score == 0 then
      return
    end
    rank = rank + 1
    table.insert(list, { label = label, kind = kind, count = 0, chain = opts.chain, open = opts.open, score = score,
      rank = rank, field = opts.field, insert = insert })
  end

  -- place gives a suggestion kept the query it makes and its cursor: its insert, then a space unless one, a closing
  -- parenthesis or a comma follows (none after a function's opening parenthesis); one that chains puts the cursor
  -- past a space that follows, where the next suggestions are.
  local function place(s)
    local head = text:sub(1, c.from - 1) .. s.insert
    local cursorAt = #head
    if not s.open then
      if nextChar == "" or not (nextChar:find("%s") or nextChar == ")" or nextChar == ",") then
        head = head .. " "
        cursorAt = #head
      elseif s.chain and nextChar:find("%s") then
        cursorAt = cursorAt + 1
      end
    end
    s.text, s.cursor, s.open = head .. text:sub(c.to + 1), cursorAt, nil
  end

  -- numbers offers what a number is worked out from: the number fields, the player's numbers, the functions.
  local function numbers()
    for _, field in ipairs(search:Fields()) do
      if field.kind == "number" and not field.list then
        offer(field.name, "field", field.name, { field = field })
      end
    end
    for _, value in ipairs(search.PLAYER_VALUES) do
      if value.kind == "number" then
        offer("player." .. value.name, "player", "player." .. value.name, {})
      end
    end
    for _, name in ipairs(functionNames()) do
      offer(name .. "(", "function", name .. "(", { open = true })
    end
  end

  local typedWord = c.prefix:find("^%a") ~= nil
  if c.expects == "condition" then
    if c.prefix == "" or c.quote ~= nil then
      return {}, c
    end
    local chain = c.after ~= "operator"
    for _, field in ipairs(search:Fields()) do
      offer(field.name, "field", field.name, { chain = chain, field = field })
    end
    offer("NOT", "keyword", "NOT", {})
    for _, value in ipairs(search.PLAYER_VALUES) do
      offer("player." .. value.name, "player", "player." .. value.name, { chain = chain })
    end
    for _, name in ipairs(functionNames()) do
      offer(name .. "(", "function", name .. "(", { open = true })
    end
  elseif c.expects == "operator" or c.expects == "join" then
    if c.quote ~= nil then
      return {}, c
    end
    if typedWord then
      offer("AND", "keyword", "AND", {})
      offer("OR", "keyword", "OR", {})
    elseif c.expects == "operator" and c.field ~= nil then
      local field, kind = search:FieldOf(c.field), nil
      if field ~= nil then
        kind = (field.alias or field.name) == "expansion" and "ordered" or field.kind
      elseif string.lower(c.field):sub(1, 7) == "player." then
        kind = playerKind(string.lower(c.field):sub(8))
      end
      -- No values follow at once when one is there already.
      for _, op in ipairs(kind and OPERATORS[kind] or {}) do
        offer(op, "operator", op, { chain = c.after ~= "term" })
      end
    end
  elseif c.expects == "value" then
    local field = c.field and search:FieldOf(c.field)
    local own = field and (field.alias or field.name)
    if field ~= nil and (FIXED[own] ~= nil or field.kind == "boolean") then
      local names = FIXED[own] and FIXED[own]() or { "true", "false" }
      for _, name in ipairs(names) do
        offer(name, "value", valueText(name, c.quote), { words = true })
      end
    elseif field == nil or (field.kind == "number" and typedWord) then
      if typedWord and c.quote == nil and (field ~= nil or c.field == nil) then
        numbers()
      end
    elseif not NO_VALUES[own] then
      local values = search:ValuesOf(c.field, within)
      if field.kind == "number" and ORDERED[c.operator] then
        table.sort(values, function(a, b)
          if type(a.value) == "number" and type(b.value) == "number" then
            return a.value < b.value
          end
          return tostring(a.value) < tostring(b.value)
        end)
      end
      for _, entry in ipairs(values) do
        if entry.value ~= "" then
          offer(tostring(entry.value), "value", valueText(entry.value, c.quote), { words = true })
        end
      end
    end
  end

  if #list == 1 and list[1].score == 4 then
    return {}, c
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.rank < b.rank
  end)
  for i = #list, MAX + 1, -1 do
    list[i] = nil
  end
  for _, s in ipairs(list) do
    place(s)
  end
  -- Whatever comes after an operator makes a whole comparison: each counted as the whole rule with it.
  local counter = c.expects == "value" and list[1] ~= nil and self:ValueCounter(text, c, within) or nil
  for _, s in ipairs(list) do
    local field = s.field
    if c.expects == "value" then
      s.count = counter and counter(s.insert) or self:CountOf(s.text, within)
    elseif s.kind == "field" and c.expects == "condition" then
      if field.kind == "boolean" or c.after == "operator" then
        s.count = self:CountOf(s.text, within)
      else
        s.count = self:CountWithField(text, c.from, c.to, field.name, within)
      end
    end
    s.field, s.insert = nil, nil
  end
  return list, c
end
