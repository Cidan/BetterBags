local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- HelpSearch ranks the help's articles for what a player types (help.md §2). Text is made comparable first: the
-- client's escape codes dropped, lowercased (ASCII, Latin-1 and Cyrillic), accents folded. Words are stemmed (a light
-- Porter stemmer, English only) and stop words left out; Korean, Chinese and Japanese runs, which have no spaces
-- between words, become pairs of characters. Documents are ranked by BM25F over their fields (a title counts most, a
-- body least); a document matching every word typed comes before one matching some. The word still being typed (no
-- space after it) also matches the start of longer words, a word typed with a letter wrong, missing, added or swapped
-- matches the word meant, and two words typed as one match both. Everything runs in Lua 5.1: the index is plain
-- tables built from the articles' text when the help first searches.
---@class HelpSearch: AceModule
local search = addon:NewModule('HelpSearch')

-- Each field's weight and how much its length counts against it (BM25F's b). Tuned against held-out searches players
-- would type (help.md §2): an article's keywords say best what it is for, and its long body least.
search.FIELDS = {
  title = { weight = 6, b = 0.5 },
  keywords = { weight = 4, b = 0.75 },
  questions = { weight = 3, b = 0.9 },
  headings = { weight = 0.75, b = 0.5 },
  body = { weight = 0.4, b = 0.9 },
}

-- BM25's saturation: how quickly more of a word stops counting for more.
local K1 = 1.2

-- The share of a document's score kept when it matches none of the words typed but one: a document matching all of
-- them keeps all of it (0.3 + 0.7 * matched / typed).
local COVERAGE_FLOOR = 0.3

-- How much a match by a synonym counts, against the word itself.
local SYNONYM = 0.8

-- A player's words for what the help names otherwise, searched for as well (a document using the word itself first).
-- Measured against held-out searches (help.md §2): players say storage for the bank, a bucket for a category.
search.SYNONYMS = {
  bucket = { "category" }, buckets = { "category" }, group = { "category" }, groups = { "category" },
  header = { "section", "title" }, headers = { "section", "title" }, heading = { "section", "title" },
  storage = { "bank" }, stash = { "bank" }, vault = { "bank" }, account = { "warbank", "warband" },
  pouch = { "bag" }, pouches = { "bag" }, satchel = { "bag" },
  frame = { "window", "panel" }, frames = { "window", "panel" },
  skin = { "theme" }, skins = { "theme" }, style = { "theme" }, look = { "theme" },
  loot = { "item" }, stuff = { "item" },
  config = { "setting" }, configure = { "setting" }, options = { "setting" }, option = { "setting" },
  preferences = { "setting" }, toggle = { "setting" },
  hotkey = { "binding", "key" }, hotkeys = { "binding", "key" }, keybind = { "binding", "key" },
  keybinds = { "binding", "key" }, shortcut = { "binding", "key" }, shortcuts = { "binding", "key" },
  keyboard = { "binding", "key" },
  tidy = { "sort" }, organize = { "sort" }, organise = { "sort" }, cleanup = { "sort" },
  delete = { "destroy" }, trash = { "destroy", "junk" }, discard = { "destroy" },
  grey = { "poor", "junk" }, gray = { "poor", "junk" },
  shop = { "vendor", "merchant" }, store = { "vendor", "merchant" }, vendoring = { "vendor", "sell" },
  ilv = { "ilvl" }, gearscore = { "ilvl" }, coins = { "gold" }, money = { "gold" },
  alt = { "character", "profile" }, alts = { "character", "profile" }, toon = { "character", "profile" },
  toons = { "character", "profile" },
  reorder = { "order" }, rearrange = { "order" }, arrange = { "order", "sort" },
  horizontal = { "side" }, horizontally = { "side" }, sidebyside = { "side" },
  hole = { "gap", "empty" }, holes = { "gap", "empty" }, blank = { "gap", "empty" },
  shine = { "sheen" }, gleam = { "sheen" }, pointer = { "arrow" },
  mats = { "reagent", "materials" },
  page = { "tab" }, pages = { "tab" }, clan = { "guild" }, vaults = { "bank" },
  box = { "section" }, boxes = { "section" }, container = { "bag" }, containers = { "bag" },
  liquidate = { "sell" }, consumes = { "consumable" }, crest = { "currency" }, crests = { "currency" },
  respawn = { "reappear" }, respawns = { "reappear" }, intro = { "introduction", "overview" },
  tour = { "overview", "introduction" }, popup = { "open", "pop" }, popups = { "open", "pop" },
  boolean = { "true", "false" }, logic = { "operator" }, bulk = { "whole" }, transfer = { "move" },
}

-- Words too common in questions to tell articles apart.
local STOP = {}
for word in ([[a an the and or but if then of to in on at by for with from into onto about as is are was were be
  been being am do does did doing done how what why where when which who whom i im me my mine you your yours we our
  it its this that these those there here can could should would will shall may might must get got have has had so
  too very just any some help please want wanna need]]):gmatch("%S+") do
  STOP[word] = true
end
search.STOP = STOP

-- The lowercase, accent-free form of each two-byte UTF-8 letter that has one: Latin-1's letters (German, French,
-- Spanish, Italian, Portuguese) folded to ASCII, and Cyrillic's capitals to their small letters.
local FOLD = {}

---@param cp number A code point below 0x800.
---@return string
local function utf8Char(cp)
  if cp < 0x80 then
    return string.char(cp)
  end
  return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
end

do
  -- U+00C0 to U+00FF, in order: × (U+00D7) and ÷ (U+00F7) are left as they are.
  local latin = {
    "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
    "d", "n", "o", "o", "o", "o", "o", false, "o", "u", "u", "u", "u", "y", "th", "ss",
    "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
    "d", "n", "o", "o", "o", "o", "o", false, "o", "u", "u", "u", "u", "y", "th", "y",
  }
  for i, base in ipairs(latin) do
    if base then
      FOLD[utf8Char(0xBF + i)] = base
    end
  end
  FOLD[utf8Char(0x152)], FOLD[utf8Char(0x153)] = "oe", "oe"
  -- Ѐ to Џ (U+0400 to U+040F) to ѐ to џ, А to Я (U+0410 to U+042F) to а to я.
  for cp = 0x400, 0x40F do
    FOLD[utf8Char(cp)] = utf8Char(cp + 0x50)
  end
  for cp = 0x410, 0x42F do
    FOLD[utf8Char(cp)] = utf8Char(cp + 0x20)
  end
end

-- StripCodes drops the client's escape codes from text: colors, textures, atlases and line breaks (as spaces); a
-- link keeps its text.
---@param text string
---@return string
function search:StripCodes(text)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
  text = text:gsub("|n", " "):gsub("||", "|")
  return text
end

-- Normalize returns text as the search compares it: without escape codes, in small letters, accents folded.
---@param text string
---@return string
function search:Normalize(text)
  return (self:StripCodes(text):lower():gsub("[\192-\223][\128-\191]", FOLD))
end

---@param ch string One UTF-8 character.
---@return number
local function codePoint(ch)
  local b1, b2, b3, b4 = ch:byte(1, 4)
  if b1 < 0x80 then
    return b1
  elseif b1 < 0xE0 then
    return (b1 - 0xC0) * 64 + (b2 - 0x80)
  elseif b1 < 0xF0 then
    return (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
  end
  return (b1 - 0xF0) * 262144 + (b2 - 0x80) * 4096 + (b3 - 0x80) * 64 + (b4 - 0x80)
end

-- isWide says whether a code point is a letter of a script written without spaces between words: kana, CJK
-- ideographs, Hangul.
---@param cp number
---@return boolean
local function isWide(cp)
  return (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x3400 and cp <= 0x4DBF) or (cp >= 0x4E00 and cp <= 0x9FFF)
    or (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0xF900 and cp <= 0xFAFF)
end

-- isLetter says whether a code point past ASCII is part of a word: Latin, Greek and Cyrillic letters.
---@param cp number
---@return boolean
local function isLetter(cp)
  return (cp >= 0xC0 and cp <= 0x24F and cp ~= 0xD7 and cp ~= 0xF7) or (cp >= 0x370 and cp <= 0x4FF)
end

-- One UTF-8 character at the place matched from (a stray continuation byte alone).
local CHAR = "^[%z\1-\127\194-\244]?[\128-\191]*"

---@class (exact) HelpWord
---@field text string The word as compared: in small letters, accents folded.
---@field wide boolean A run of a script without spaces (its text is that run).
---@field s number Its first byte in the text scanned.
---@field e number Its last byte.

-- scan returns the words of text (no escape codes in it) with where each is: letters and digits run together, an
-- apostrophe inside a word dropped ("what's" is "whats"), a run of a wide script its own word.
---@param text string
---@return HelpWord[]
local function scan(text)
  local words, parts, kind, s, e = {}, {}, nil, nil, nil
  local function flush()
    if kind ~= nil then
      table.insert(words, { text = table.concat(parts), wide = kind == "wide", s = s, e = e })
    end
    parts, kind, s, e = {}, nil, nil, nil
  end
  local pos, n = 1, #text
  while pos <= n do
    local ch = text:match(CHAR, pos)
    if ch == nil or ch == "" then
      ch = text:sub(pos, pos)
    end
    local cp = codePoint(ch)
    local wordKind, add
    if cp < 0x80 then
      if ch:find("^%w$") then
        wordKind, add = "word", ch:lower()
      elseif (cp == 39) and kind == "word" then
        wordKind, add = "word", ""
      end
    elseif cp == 0x2019 and kind == "word" then
      wordKind, add = "word", ""
    elseif isWide(cp) then
      wordKind, add = "wide", ch
    elseif isLetter(cp) then
      wordKind, add = "word", FOLD[ch] or ch
    end
    if wordKind == nil then
      flush()
    else
      if kind ~= wordKind then
        flush()
        kind, s = wordKind, pos
      end
      table.insert(parts, add)
      e = pos + #ch - 1
    end
    pos = pos + #ch
  end
  flush()
  return words
end

---@param text string
---@return string[]
local function chars(text)
  local list = {}
  for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    table.insert(list, ch)
  end
  return list
end

-- pairsOf returns a wide run's pairs of characters (the run itself when it is one character).
---@param run string
---@return string[]
local function pairsOf(run)
  local list = chars(run)
  if #list == 1 then
    return list
  end
  local out = {}
  for i = 1, #list - 1 do
    table.insert(out, list[i] .. list[i + 1])
  end
  return out
end

---@param s string
---@return boolean
local function hasVowel(s)
  return s:find("[aeiou]") ~= nil
end

-- Words whose stem the rules below would give another word's: a setting is no equipment set.
local STEMS = { setting = "setting", settings = "setting" }

-- Stem returns the stem of an English word in small letters, so its plural, past and -ing forms compare equal
-- (Porter's first step, and a final e dropped): "categories" and "category" are "categori", "sorting" and "sort" are
-- "sort". A word with digits or letters past ASCII, or shorter than three letters, is its own stem.
---@param word string
---@return string
function search:Stem(word)
  if STEMS[word] then
    return STEMS[word]
  end
  if #word < 3 or word:find("[^a-z]") then
    return word
  end
  local w = word
  -- "-ies" needs no rule of its own: "categories" loses its s here and its e at the end, as "category" becomes
  -- "categori".
  if w:sub(-4) == "sses" then
    w = w:sub(1, -3)
  elseif w:sub(-2) ~= "ss" and w:sub(-2) ~= "us" and w:sub(-2) ~= "is" and w:sub(-1) == "s" and #w > 3 then
    w = w:sub(1, -2)
  end
  local cut = false
  if w:sub(-3) == "eed" then
    cut = false
  elseif w:sub(-2) == "ed" and hasVowel(w:sub(1, -3)) then
    w, cut = w:sub(1, -3), true
  elseif w:sub(-3) == "ing" and hasVowel(w:sub(1, -4)) then
    w, cut = w:sub(1, -4), true
  end
  if cut then
    if w:find("at$") or w:find("bl$") or w:find("iz$") then
      w = w .. "e"
    elseif w:find("([^aeiouylsz])%1$") then
      w = w:sub(1, -2)
    end
  end
  if w:sub(-1) == "y" and #w > 2 and hasVowel(w:sub(1, -2)) then
    w = w:sub(1, -2) .. "i"
  end
  if #w >= 3 and w:sub(-1) == "e" then
    w = w:sub(1, -2)
  end
  return w
end

-- termsOf returns the terms a word is indexed and searched by: its stem, nothing for a stop word, a wide run's pairs.
---@param word HelpWord
---@return string[]
local function termsOf(word)
  if word.wide then
    return pairsOf(word.text)
  end
  if STOP[word.text] then
    return {}
  end
  return { search:Stem(word.text) }
end

-- Terms returns the terms of text, in order.
---@param text string
---@return string[]
function search:Terms(text)
  local list = {}
  for _, word in ipairs(scan(self:StripCodes(text))) do
    for _, term in ipairs(termsOf(word)) do
      table.insert(list, term)
    end
  end
  return list
end

-- osa returns the optimal string alignment distance between two words (letters changed, missing, added, or two
-- side by side swapped), or limit + 1 once it is past limit.
---@param a string
---@param b string
---@param limit number
---@return number
local function osa(a, b, limit)
  local la, lb = #a, #b
  if math.abs(la - lb) > limit then
    return limit + 1
  end
  local prev2, prev = {}, {}
  for j = 0, lb do
    prev[j] = j
  end
  for i = 1, la do
    local cur = { [0] = i }
    local best = i
    local ai = a:byte(i)
    for j = 1, lb do
      local bj = b:byte(j)
      local cost = ai == bj and 0 or 1
      local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
      if i > 1 and j > 1 and ai == b:byte(j - 1) and a:byte(i - 1) == bj then
        v = math.min(v, prev2[j - 2] + 1)
      end
      cur[j] = v
      if v < best then
        best = v
      end
    end
    if best > limit then
      return limit + 1
    end
    prev2, prev = prev, cur
  end
  return prev[lb]
end

-- deletes returns a word with each of its letters left out in turn.
---@param word string
---@return string[]
local function deletes(word)
  local list = {}
  for i = 1, #word do
    table.insert(list, word:sub(1, i - 1) .. word:sub(i + 1))
  end
  return list
end

---@class (exact) HelpSearchDoc
---@field id string
---@field fields table<string, string[]> Each field's text, by the field's name (search.FIELDS).

---@class (exact) HelpPosting
---@field doc table The document's entry: { id, order }.
---@field tf number The term's weight in the document: its count in each field, by the field's weight, for its length.

---@class (exact) HelpSearchResult
---@field id string
---@field score number

---@class HelpIndex
---@field postings table<string, HelpPosting[]> The documents each term is in.
---@field idf table<string, number>
---@field raw table<string, string> Every word in the documents (not a stop word) and its stem.
---@field sorted string[] Those words in order, to find the ones a word typed starts.
---@field dels table<string, string[]> For each word with a letter left out, the words it comes from.
---@field count number
local indexProto = {}
addon:GetModule('Perf'):RegisterPrototype(indexProto, 'HelpIndex')

-- Build makes an index of documents, in the order given (it breaks ties between equal scores).
---@param docs HelpSearchDoc[]
---@return HelpIndex
function search:Build(docs)
  local index = setmetatable({ postings = {}, idf = {}, raw = {}, sorted = {}, dels = {}, count = #docs },
    { __index = indexProto })
  local entries, totals, counts = {}, {}, {}
  for order, d in ipairs(docs) do
    local entry = { id = d.id, order = order, tf = {}, len = {} }
    for field in pairs(search.FIELDS) do
      local tf, len = {}, 0
      for _, text in ipairs(d.fields[field] or {}) do
        for _, word in ipairs(scan(self:StripCodes(text))) do
          for _, term in ipairs(termsOf(word)) do
            tf[term] = (tf[term] or 0) + 1
            len = len + 1
          end
          if not word.wide and not STOP[word.text] then
            index.raw[word.text] = self:Stem(word.text)
          end
        end
      end
      entry.tf[field], entry.len[field] = tf, len
      if len > 0 then
        totals[field] = (totals[field] or 0) + len
        counts[field] = (counts[field] or 0) + 1
      end
    end
    entries[order] = entry
  end
  local df = {}
  for _, entry in ipairs(entries) do
    local weights = {}
    for field, spec in pairs(search.FIELDS) do
      local len = entry.len[field]
      if len > 0 then
        local avg = totals[field] / counts[field]
        local norm = 1 - spec.b + spec.b * len / avg
        for term, n in pairs(entry.tf[field]) do
          weights[term] = (weights[term] or 0) + spec.weight * n / norm
        end
      end
    end
    local doc = { id = entry.id, order = entry.order }
    for term, tf in pairs(weights) do
      local list = index.postings[term]
      if list == nil then
        list = {}
        index.postings[term] = list
      end
      table.insert(list, { doc = doc, tf = tf })
      df[term] = (df[term] or 0) + 1
    end
  end
  local n = #docs
  for term, count in pairs(df) do
    index.idf[term] = math.log(1 + (n - count + 0.5) / (count + 0.5))
  end
  for word in pairs(index.raw) do
    table.insert(index.sorted, word)
    if #word >= 4 and not word:find("[^a-z]") then
      for _, del in ipairs(deletes(word)) do
        local list = index.dels[del]
        if list == nil then
          list = {}
          index.dels[del] = list
        end
        table.insert(list, word)
      end
    end
  end
  table.sort(index.sorted)
  return index
end

-- prefixed returns the words of the documents that start with a word typed, longer than it (at most 40).
---@param word string
---@return string[]
function indexProto:prefixed(word)
  local list, sorted = {}, self.sorted
  local lo, hi = 1, #sorted + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if sorted[mid] < word then
      lo = mid + 1
    else
      hi = mid
    end
  end
  for i = lo, #sorted do
    local w = sorted[i]
    if w:sub(1, #word) ~= word or #list >= 40 then
      break
    end
    if w ~= word then
      table.insert(list, w)
    end
  end
  return list
end

-- near returns the words of the documents within limit edits of a word typed, each with its distance: found by
-- the words a letter left out makes of either (a letter missing, added, changed or two swapped), then checked.
---@param word string
---@param limit number
---@return table<string, number>
function indexProto:near(word, limit)
  local found, seen = {}, {}
  local function try(candidate)
    if candidate ~= word and not seen[candidate] then
      seen[candidate] = true
      local d = osa(word, candidate, limit)
      if d <= limit then
        found[candidate] = d
      end
    end
  end
  for _, w in ipairs(self.dels[word] or {}) do
    try(w)
  end
  for _, del in ipairs(deletes(word)) do
    if self.raw[del] then
      try(del)
    end
    for _, w in ipairs(self.dels[del] or {}) do
      try(w)
    end
  end
  return found
end

-- half returns what one of two words run together searches for: its stem, else its synonyms; "stop" for a stop word;
-- nil for a word the documents do not have.
---@private
---@param word string
---@return table<string, number>|"stop"|nil
function indexProto:half(word)
  if STOP[word] then
    return "stop"
  end
  if #word < 3 then
    return nil
  end
  local stem = search:Stem(word)
  if self.postings[stem] then
    return { [stem] = 1 }
  end
  local alts
  for _, other in ipairs(search.SYNONYMS[word] or {}) do
    local s = search:Stem(other)
    if self.postings[s] then
      alts = alts or {}
      alts[s] = SYNONYM
    end
  end
  return alts
end

-- split returns what a word typed as two words run together searches for, each half counting 0.9 of what it would
-- alone: two words the documents have, else one of them and a stop word ("myvault", "filterby"); nil when no cut
-- gives either.
---@private
---@param word string
---@return table<string, number>[]?
function indexProto:split(word)
  local withStop
  for cut = 2, #word - 2 do
    local a, b = self:half(word:sub(1, cut)), self:half(word:sub(cut + 1))
    if a and b and (a ~= "stop" or b ~= "stop") then
      local items = {}
      for _, half in ipairs({ a, b }) do
        if half ~= "stop" then
          local item = {}
          for term, weight in pairs(half) do
            item[term] = 0.9 * weight
          end
          table.insert(items, item)
        end
      end
      if #items == 2 then
        return items
      end
      withStop = withStop or items
    end
  end
  return withStop
end

-- items returns what a word typed searches for: one or more sets of terms, each term with how much a match counts
-- (its stem 1; a longer word it starts, while it is still being typed, less the shorter it is; a synonym 0.8; each of
-- two words run together 0.9, tried before a near word; a near word 0.7 for one edit, 0.5 for two). A stop word
-- searches for nothing, unless it is still being typed ("the" may become "theme").
---@param word string
---@param open boolean It is the last word and still being typed.
---@return table<string, number>[]
function indexProto:items(word, open)
  local alts = {}
  local stop = STOP[word] == true
  local stem = search:Stem(word)
  if not stop and self.postings[stem] then
    alts[stem] = 1
  end
  if open and #word >= 2 then
    for _, w in ipairs(self:prefixed(word)) do
      local s = self.raw[w]
      local weight = 0.6 + 0.3 * #word / #w
      if s ~= stem and weight > (alts[s] or 0) then
        alts[s] = weight
      end
    end
  end
  if stop then
    return next(alts) ~= nil and { alts } or {}
  end
  for _, other in ipairs(search.SYNONYMS[word] or {}) do
    local s = search:Stem(other)
    if self.postings[s] and SYNONYM > (alts[s] or 0) then
      alts[s] = SYNONYM
    end
  end
  if next(alts) == nil and #word >= 5 and not word:find("[^a-z]") then
    local split = self:split(word)
    if split then
      return split
    end
  end
  if next(alts) == nil and #word >= 4 and not word:find("[^a-z]") then
    for w, d in pairs(self:near(word, #word >= 8 and 2 or 1)) do
      local s = self.raw[w]
      local weight = d == 1 and 0.7 or 0.5
      if weight > (alts[s] or 0) then
        alts[s] = weight
      end
    end
  end
  return { alts }
end

---@class (exact) HelpQueryOptions
---@field limit? number At most this many results.

-- Query ranks the documents for what was typed, best first (ties in the order the documents were given), and
-- returns the terms that matched (to mark them in a snippet). The last word is still being typed unless a space
-- follows it.
---@param text string
---@param opts? HelpQueryOptions
---@return HelpSearchResult[] results
---@return table<string, boolean> matched
function indexProto:Query(text, opts)
  local plain = search:StripCodes(text or "")
  local open = plain:find("%s$") == nil
  local words = scan(plain)
  local items = {}
  for i, word in ipairs(words) do
    if word.wide then
      for _, term in ipairs(pairsOf(word.text)) do
        table.insert(items, { [term] = 1 })
      end
    else
      for _, item in ipairs(self:items(word.text, open and i == #words)) do
        table.insert(items, item)
      end
    end
  end
  local matched = {}
  if #items == 0 then
    return {}, matched
  end
  local scores, hits, docs = {}, {}, {}
  for _, item in ipairs(items) do
    local best = {}
    for term, weight in pairs(item) do
      local list = self.postings[term]
      if list ~= nil then
        matched[term] = true
        local idf = self.idf[term]
        for _, p in ipairs(list) do
          local s = weight * idf * p.tf / (K1 + p.tf)
          if s > (best[p.doc] or 0) then
            best[p.doc] = s
          end
        end
      end
    end
    for doc, s in pairs(best) do
      scores[doc] = (scores[doc] or 0) + s
      hits[doc] = (hits[doc] or 0) + 1
      docs[doc] = true
    end
  end
  local results = {}
  for doc in pairs(docs) do
    local coverage = hits[doc] / #items
    table.insert(results, { id = doc.id, score = scores[doc] * (COVERAGE_FLOOR + (1 - COVERAGE_FLOOR) * coverage),
      order = doc.order })
  end
  table.sort(results, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.order < b.order
  end)
  local limit = opts and opts.limit
  local out = {}
  for i, r in ipairs(results) do
    if limit ~= nil and i > limit then
      break
    end
    out[i] = { id = r.id, score = r.score }
  end
  return out, matched
end

-- sentences returns text's sentences, each ending with its stop (. ! ? and their full-width forms) or a line's end,
-- trimmed.
---@param text string
---@return string[]
local function sentences(text)
  local list, pos, n = {}, 1, #text
  local patterns = { "[%.!%?]+%s+", "[%.!%?]+$", "\n+", "\227\128\130", "\239\188\129", "\239\188\159" }
  while pos <= n do
    local bestS, bestE, bestStop
    for _, pattern in ipairs(patterns) do
      local s, e = text:find(pattern, pos)
      if s ~= nil and (bestS == nil or s < bestS) then
        local _, stop = text:find("^[%.!%?]+", s)
        if stop == nil and text:sub(s, s) == "\n" then
          stop = s - 1
        end
        bestS, bestE, bestStop = s, e, stop or e
      end
    end
    local piece
    if bestS == nil then
      piece, pos = text:sub(pos), n + 1
    else
      piece, pos = text:sub(pos, bestStop), bestE + 1
    end
    piece = piece:gsub("^%s+", ""):gsub("%s+$", "")
    if piece ~= "" then
      table.insert(list, piece)
    end
  end
  return list
end

-- matches says whether a word of a snippet is one of the terms matched (a wide run when any of its pairs is).
---@param word HelpWord
---@param terms table<string, boolean>
---@return boolean
local function matches(word, terms)
  for _, term in ipairs(termsOf(word)) do
    if terms[term] then
      return true
    end
  end
  return false
end

-- Snippet returns the sentence of text with the most terms matched (the first sentence when none is), at most width
-- characters of it round its first match, cut at a word's edge with an ellipsis; and where each matched word is in
-- what it returns (first and last byte), to mark them.
---@param text string
---@param terms table<string, boolean>
---@param width number
---@return string snippet
---@return {[1]: number, [2]: number}[] spans
function search:Snippet(text, terms, width)
  local plain = self:StripCodes(text)
  local list = sentences(plain)
  local best, bestCount = list[1] or "", 0
  for _, sentence in ipairs(list) do
    local found, count = {}, 0
    for _, word in ipairs(scan(sentence)) do
      for _, term in ipairs(termsOf(word)) do
        if terms[term] and not found[term] then
          found[term] = true
          count = count + 1
        end
      end
    end
    if count > bestCount then
      best, bestCount = sentence, count
    end
  end
  local letters = chars(best)
  local snippet = best
  if #letters > width then
    local first = 1
    for _, word in ipairs(scan(best)) do
      if matches(word, terms) then
        first = #chars(best:sub(1, word.s - 1)) + 1
        break
      end
    end
    local from = math.max(1, first - math.floor(width / 3))
    local to = math.min(#letters, from + width - 1)
    if to == #letters then
      from = math.max(1, to - width + 1)
    end
    if from > 1 and letters[from - 1] ~= " " then
      while from <= first and letters[from] ~= " " do
        from = from + 1
      end
    end
    while from < #letters and letters[from] == " " do
      from = from + 1
    end
    if to < #letters and letters[to + 1] ~= " " then
      while to > from and letters[to] ~= " " do
        to = to - 1
      end
    end
    while to > from and letters[to] == " " do
      to = to - 1
    end
    snippet = (from > 1 and "…" or "") .. table.concat(letters, "", from, to) .. (to < #letters and "…" or "")
  end
  local spans = {}
  for _, word in ipairs(scan(snippet)) do
    if matches(word, terms) then
      table.insert(spans, { word.s, word.e })
    end
  end
  return snippet, spans
end
