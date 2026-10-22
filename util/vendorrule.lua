local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class QueryParser: AceModule
local QueryParser = addon:GetModule('QueryParser')

-- VendorRule converts a rule of the Vendor addon into a BetterBags search (docs/vendor-compat.md,
-- .claude/rules/search-indexing.md §18). A Vendor rule is a Lua expression over an item's properties
-- (Vendor's systems/itemproperties/itemproperties.lua), Vendor's functions and constants
-- (systems/rules/builtins.lua) and the rule's parameters. The rule is never run: it is read as Lua 5.1
-- and each part is written as the search that means the same.
---@class VendorRule: AceModule
local VendorRule = addon:NewModule('VendorRule')

---@class VendorRuleOptions
---@field params? table<string, any> The rule's parameters (ITEMLEVEL, ...) and their values.
---@field classic? boolean Convert for a Classic client: its binding and CURRENT_EXPANSION.
---@field globals? table Where Blizzard's stat names are read (default _G).

---@class VendorRuleResult
---@field query? string The search, when the rule converts.
---@field problem? string Why it does not.
---@field notes string[] What the search reads differently from Vendor.

-- ─── Vendor's names ──────────────────────────────────────────────────────────────────────────────

-- Numeric properties and the field each is.
local NUMBERS = {
  Id = "id", Count = "count", StackSize = "stacksize", Level = "ilvl", MinLevel = "minlevel",
  MaxLevel = "maxlevel", UnitValue = "price", TypeId = "class", SubTypeId = "subclass", Quality = "rarity",
  BindType = "bindtype", CraftedQuality = "quality", PetCount = "petcount", PetLimit = "petlimit",
  UpgradeLevel = "upgradelevel", UpgradeMax = "upgrademax", Bag = "bagid", Slot = "slotid",
}

-- Values Vendor works out from others: the search's expression and its precedence (sum 1, product 2,
-- a single value 3).
local DERIVED = {
  TotalValue = { "price * count", 2 },
  UnitGoldValue = { "floor(price / 10000)", 3 },
  TotalGoldValue = { "floor(price * count / 10000)", 3 },
}

-- Text properties of the item.
local TEXTS = { Name = "name", Type = "type", SubType = "subtype", GUID = "guid", UpgradeTrack = "track" }

-- Boolean properties and the field each is.
local BOOLS = {
  IsCraftingReagent = "reagent", HasUseAbility = "hasuse", IsEquipment = "equipment", IsUsable = "usable",
  IsEquippable = "equippable", IsToy = "toy", IsAlreadyKnown = "known", IsPet = "pet",
  IsPetCollectable = "collectable", IsScrappable = "scrappable", IsUpgradeable = "upgradeable",
  IsCosmetic = "cosmetic", HasAppearance = "transmoggable", IsTransmogEquipment = "transmoggable",
}

local NOTES = {
  IsTransmogEquipment = "IsTransmogEquipment reads as transmoggable: the item has an appearance (Vendor checks its slot).",
  IsAppearanceCollected = "Vendor also counts every soulbound item's appearance as collected; BetterBags asks the collection.",
  IsUnknownAppearance = "Vendor also counts every soulbound item's appearance as collected; BetterBags asks the collection.",
}

-- Properties BetterBags' search has nothing for.
local UNSUPPORTED = {
  Link = true, InventoryType = true, IsConduit = true, IsAzeriteItem = true, PetName = true, PetType = true,
  IsPetTradeable = true, PetSpeciesId = true, AppearanceId = true, SourceId = true, TooltipLeft = true,
  TooltipRight = true, TooltipData = true, Location = true, TransmogInfoSource = true,
}

-- Vendor's constants (systems/rules/builtins.lua), and Blizzard's INVSLOT_ values
-- (Blizzard_FrameXMLBase/Constants.lua), which Vendor imports.
local CONSTANTS = {
  POOR = 0, COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5, ARTIFACT = 6, HEIRLOOM = 7, TOKEN = 8,
  CLASSIC = 0, BURNING_CRUSADE = 1, WRATH_OF_THE_LICH_KING = 2, CATACLYSM = 3, MISTS_OF_PANDARIA = 4,
  WARLORDS_OF_DRAENOR = 5, LEGION = 6, BATTLE_FOR_AZEROTH = 7, SHADOWLANDS = 8, DRAGONFLIGHT = 9, WAR_WITHIN = 10,
  ALCHEMY = 171, BLACKSMITHING = 164, ENCHANTING = 333, ENGINEERING = 202, HERBALISM = 182, INSCRIPTION = 773,
  JEWELCRAFTING = 755, LEATHERWORKING = 165, MINING = 186, SKINNING = 393, TAILORING = 197,
  INVSLOT_AMMO = 0, INVSLOT_HEAD = 1, INVSLOT_FIRST_EQUIPPED = 1, INVSLOT_NECK = 2, INVSLOT_SHOULDER = 3,
  INVSLOT_BODY = 4, INVSLOT_CHEST = 5, INVSLOT_WAIST = 6, INVSLOT_LEGS = 7, INVSLOT_FEET = 8, INVSLOT_WRIST = 9,
  INVSLOT_HAND = 10, INVSLOT_FINGER1 = 11, INVSLOT_FINGER2 = 12, INVSLOT_TRINKET1 = 13, INVSLOT_TRINKET2 = 14,
  INVSLOT_BACK = 15, INVSLOT_MAINHAND = 16, INVSLOT_OFFHAND = 17, INVSLOT_RANGED = 18, INVSLOT_TABARD = 19,
  INVSLOT_LAST_EQUIPPED = 19,
}

-- Vendor's primary professions by name (HasProfession reads names upper-cased), and their skill lines.
local PROFESSIONS = {
  ALCHEMY = 171, BLACKSMITHING = 164, ENCHANTING = 333, ENGINEERING = 202, HERBALISM = 182, INSCRIPTION = 773,
  JEWELCRAFTING = 755, LEATHERWORKING = 165, MINING = 186, SKINNING = 393, TAILORING = 197,
}
local PROFESSION_LINES = {}
for _, line in pairs(PROFESSIONS) do PROFESSION_LINES[line] = true end

-- The INVTYPE_ constants Vendor imports (rules/manager.lua, ITEM_CONSTANTS).
local INVTYPES = {}
for _, token in ipairs({ "AMMO", "HEAD", "NECK", "SHOULDER", "BODY", "CHEST", "ROBE", "WAIST", "LEGS", "FEET",
  "WRIST", "HAND", "FINGER", "TRINKET", "CLOAK", "WEAPON", "SHIELD", "2HWEAPON", "WEAPONMAINHAND", "WEAPONOFFHAND",
  "HOLDABLE", "RANGED", "THROWN", "RANGEDRIGHT", "RELIC", "TABARD", "BAG", "QUIVER" }) do
  INVTYPES["INVTYPE_" .. token] = true
end

-- HasStat's names and the global string of each stat (Vendor's STATS, systems/rules/builtins.lua).
local STATS = {
  agi = "ITEM_MOD_AGILITY_SHORT", agility = "ITEM_MOD_AGILITY_SHORT", ap = "ITEM_MOD_ATTACK_POWER_SHORT",
  attackpower = "ITEM_MOD_ATTACK_POWER_SHORT", ["attack power"] = "ITEM_MOD_ATTACK_POWER_SHORT",
  block = "ITEM_MOD_BLOCK_RATING_SHORT", corruption = "ITEM_MOD_CORRUPTION", crit = "ITEM_MOD_CRIT_RATING_SHORT",
  critical = "ITEM_MOD_CRIT_RATING_SHORT", ["critical strike"] = "ITEM_MOD_CRIT_RATING_SHORT",
  avoidance = "ITEM_MOD_CR_AVOIDANCE_SHORT", leach = "ITEM_MOD_CR_LIFESTEAL_SHORT",
  multistrike = "ITEM_MOD_CR_MULTISTRIKE_SHORT", speed = "ITEM_MOD_CR_SPEED_SHORT",
  industructable = "ITEM_MOD_CR_STURDINESS_SHORT", defense = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
  dodge = "ITEM_MOD_DODGE_RATING_SHORT", armor = "ITEM_MOD_EXTRA_ARMOR_SHORT", bonusarmor = "ITEM_MOD_EXTRA_ARMOR_SHORT",
  ["bonus armor"] = "ITEM_MOD_EXTRA_ARMOR_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT",
  health = "ITEM_MOD_HEALTH_SHORT", hit = "ITEM_MOD_HIT_RATING_SHORT", int = "ITEM_MOD_INTELLECT_SHORT",
  intellect = "ITEM_MOD_INTELLECT_SHORT", manaregen = "ITEM_MOD_MANA_REGENERATION_SHORT", mana = "ITEM_MOD_MANA_SHORT",
  mastery = "ITEM_MOD_MASTERY_RATING_SHORT", parry = "ITEM_MOD_PARRY_RATING_SHORT",
  bonushealing = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", spirit = "ITEM_MOD_SPIRIT_SHORT",
  stam = "ITEM_MOD_STAMINA_SHORT", stamina = "ITEM_MOD_STAMINA_SHORT", str = "ITEM_MOD_STRENGTH_SHORT",
  strength = "ITEM_MOD_STRENGTH_SHORT", vers = "ITEM_MOD_VERSATILITY", versatility = "ITEM_MOD_VERSATILITY",
}

-- Vendor's player functions: what kind of value each is, and the player value it reads.
local PLAYER = {
  PlayerLevel = { "num", "player.level" }, PlayerItemLevel = { "num", "player.ilvl" },
  PlayerClassId = { "num", "player.classid" }, PlayerSpecializationId = { "num", "player.specid" },
  PlayerClass = { "text", "player.class" }, PlayerSpecialization = { "text", "player.spec" },
}

-- Vendor's list functions (systems/lists/functions.lua).
local LISTS = { IsInList = true, IsNeverSellItem = true, IsAlwaysSellItem = true, IsDestroyItem = true,
  IsImportantItem = true }

-- Functions other addons give Vendor (systems/extensionmanager), by their names' prefix.
local ADDONS = { { "^TSM_", "TSM" }, { "^Auctionator_", "Auctionator" }, { "^Auc_", "Auctionator" },
  { "^ATT_", "All The Things" }, { "^CIMI_", "Can I Mog It" }, { "^Pawn_", "Pawn" } }

-- The other functions a rule can name.
local FUNCTIONS = {
  TooltipContains = true, HasStat = true, IsInEquipmentSet = true, HasProfession = true, TotalItemCount = true,
  WatermarkLevel = true, CurrentEquippedLevel = true, tostring = true, tonumber = true, print = true,
}

local MATH = { min = math.min, max = math.max, floor = math.floor, ceil = math.ceil, abs = math.abs }

local FLIP = { ["<"] = ">", [">"] = "<", ["<="] = ">=", [">="] = "<=", ["=="] = "==", ["~="] = "~=" }
local NUMBER_OPS = { ["=="] = "=", ["~="] = "!=", ["<"] = "<", ["<="] = "<=", [">"] = ">", [">="] = ">=" }

---@param message string
local function fail(message)
  error({ vendorRule = message }, 0)
end

-- ─── Reading Lua ─────────────────────────────────────────────────────────────────────────────────

local KEYWORDS = {
  ["and"] = true, ["or"] = true, ["not"] = true, ["true"] = true, ["false"] = true, ["nil"] = true,
  ["function"] = true, ["end"] = true, ["if"] = true, ["then"] = true, ["else"] = true, ["elseif"] = true,
  ["local"] = true, ["return"] = true, ["do"] = true, ["for"] = true, ["while"] = true, ["repeat"] = true,
  ["until"] = true, ["in"] = true, ["break"] = true,
}
local TWO = { ["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, [".."] = true }
local ONE = "+-*/%^#<>=(){}[];:,."
local ESCAPES = { n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v" }

---@param text string
---@param i number At a quote.
---@return string value, number next
local function readQuoted(text, i)
  local quote, parts, j = text:sub(i, i), {}, i + 1
  while true do
    local ch = text:sub(j, j)
    if ch == "" or ch == "\n" then
      fail(L:G("The rule is not valid Lua: a text is not closed."))
    end
    if ch == quote then
      return table.concat(parts), j + 1
    end
    if ch == "\\" then
      local digits = text:match("^%d%d?%d?", j + 1)
      if digits then
        table.insert(parts, string.char(tonumber(digits) % 256))
        j = j + 1 + #digits
      else
        local escaped = text:sub(j + 1, j + 1)
        table.insert(parts, ESCAPES[escaped] or escaped)
        j = j + 2
      end
    else
      table.insert(parts, ch)
      j = j + 1
    end
  end
end

-- readLong reads a long bracket ([[...]], [==[...]==]) at i: its text and where the rest begins.
---@param text string
---@param i number
---@return string value, number next
local function readLong(text, i)
  local level = text:match("^%[(=*)%[", i)
  local close = "]" .. level .. "]"
  local start = i + 2 + #level
  local stop = text:find(close, start, true)
  if not stop then
    fail(L:G("The rule is not valid Lua: a long text or comment is not closed."))
  end
  local value = text:sub(start, stop - 1)
  if value:sub(1, 1) == "\n" then
    value = value:sub(2)
  end
  return value, stop + #close
end

-- lex splits a rule into Lua's tokens: { t = "num" | "str" | "name" | "kw" | "op" | "eof", v }.
---@param text string
---@return table[]
local function lex(text)
  local tokens, i, n = {}, 1, #text
  while i <= n do
    local c = text:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif text:sub(i, i + 1) == "--" then
      if text:match("^%-%-%[=*%[", i) then
        local _, after = readLong(text, i + 2)
        i = after
      else
        local stop = text:find("\n", i, true)
        i = stop and stop + 1 or n + 1
      end
    elseif c:match("[%a_]") then
      local word = text:match("^[%a_][%w_]*", i)
      table.insert(tokens, { t = KEYWORDS[word] and "kw" or "name", v = word })
      i = i + #word
    elseif c:match("%d") or (c == "." and text:sub(i + 1, i + 1):match("%d")) then
      local number = text:match("^0[xX]%x+", i) or text:match("^%d*%.?%d*[eE][%+%-]?%d+", i)
        or text:match("^%d*%.?%d*", i)
      local value = tonumber(number)
      if value == nil or text:sub(i + #number, i + #number):match("[%w_]") then
        fail(format(L:G("The rule is not valid Lua: %s is not a number."), text:match("^[%w_%.]+", i)))
      end
      table.insert(tokens, { t = "num", v = value })
      i = i + #number
    elseif c == '"' or c == "'" then
      local value, after = readQuoted(text, i)
      table.insert(tokens, { t = "str", v = value })
      i = after
    elseif text:match("^%[=*%[", i) then
      local value, after = readLong(text, i)
      table.insert(tokens, { t = "str", v = value })
      i = after
    elseif text:sub(i, i + 2) == "..." then
      table.insert(tokens, { t = "op", v = "..." })
      i = i + 3
    elseif TWO[text:sub(i, i + 1)] then
      table.insert(tokens, { t = "op", v = text:sub(i, i + 1) })
      i = i + 2
    elseif ONE:find(c, 1, true) then
      table.insert(tokens, { t = "op", v = c })
      i = i + 1
    else
      fail(format(L:G("The rule is not valid Lua: %s is not part of Lua."), c))
    end
  end
  table.insert(tokens, { t = "eof" })
  return tokens
end

-- Lua 5.1's binary operators: their left and right priorities (lparser.c). Unary operators bind at 8.
local BINARY = {
  ["or"] = { 1, 1 }, ["and"] = { 2, 2 },
  ["<"] = { 3, 3 }, [">"] = { 3, 3 }, ["<="] = { 3, 3 }, [">="] = { 3, 3 }, ["~="] = { 3, 3 }, ["=="] = { 3, 3 },
  [".."] = { 5, 4 }, ["+"] = { 6, 6 }, ["-"] = { 6, 6 }, ["*"] = { 7, 7 }, ["/"] = { 7, 7 }, ["%"] = { 7, 7 },
  ["^"] = { 10, 9 },
}
local UNARY = 8

-- parse reads one Lua expression: nodes { k = "num" | "str" | "bool" | "nil", v }, { k = "name", v },
-- { k = "paren", e }, { k = "index", obj, key }, { k = "call", fn, args }, { k = "method", obj, name,
-- args }, { k = "un", op, e }, { k = "bin", op, l, r }.
---@param tokens table[]
---@return table
local function parse(tokens)
  local pos = 1
  local function peek() return tokens[pos] end
  local function take()
    local token = tokens[pos]
    pos = pos + 1
    return token
  end
  local function is(t, v)
    local token = tokens[pos]
    return token.t == t and (v == nil or token.v == v)
  end
  local function need(t, v, what)
    if not is(t, v) then
      fail(format(L:G("The rule is not valid Lua: %s is missing."), what))
    end
    return take()
  end

  local subexpr

  local function arguments()
    if is("str") then
      return { { k = "str", v = take().v } }
    end
    need("op", "(", "(")
    local args = {}
    if not is("op", ")") then
      repeat
        table.insert(args, subexpr(0))
        local more = is("op", ",")
        if more then take() end
      until not more
    end
    need("op", ")", ")")
    return args
  end

  local function primary()
    local node
    if is("name") then
      node = { k = "name", v = take().v }
    elseif is("op", "(") then
      take()
      node = { k = "paren", e = subexpr(0) }
      need("op", ")", ")")
    else
      fail(L:G("The rule is not valid Lua: a value is missing."))
    end
    while true do
      if is("op", ".") then
        take()
        node = { k = "index", obj = node, key = need("name", nil, L:G("a name after .")).v }
      elseif is("op", "[") then
        fail(L:G("Indexing with [ ] is not supported in an imported rule."))
      elseif is("op", ":") then
        take()
        local name = need("name", nil, L:G("a name after :")).v
        node = { k = "method", obj = node, name = name, args = arguments() }
      elseif is("op", "(") or is("str") then
        node = { k = "call", fn = node, args = arguments() }
      else
        return node
      end
    end
  end

  local function simple()
    local token = peek()
    if token.t == "num" then take() return { k = "num", v = token.v } end
    if token.t == "str" then take() return { k = "str", v = token.v } end
    if is("kw", "true") or is("kw", "false") then take() return { k = "bool", v = token.v == "true" } end
    if is("kw", "nil") then take() return { k = "nil" } end
    if is("kw", "function") then
      fail(L:G("Functions written in the rule are not supported in an imported rule."))
    end
    if is("op", "{") then
      fail(L:G("A table ({ }) is not supported in an imported rule."))
    end
    return primary()
  end

  subexpr = function(limit)
    local node
    if is("kw", "not") or is("op", "-") or is("op", "#") then
      local op = take().v
      node = { k = "un", op = op, e = subexpr(UNARY) }
    else
      node = simple()
    end
    while true do
      local token = peek()
      local priority = (token.t == "op" or token.t == "kw") and BINARY[token.v]
      if not priority or priority[1] <= limit then
        return node
      end
      take()
      node = { k = "bin", op = token.v, l = node, r = subexpr(priority[2]) }
    end
  end

  local root = subexpr(0)
  if is("op", ";") then take() end
  if not is("eof") then
    fail(L:G("The rule is not valid Lua: something follows the end of the rule."))
  end
  return root
end

-- source writes a node back as Lua, for notes.
---@param node table
---@return string
local function source(node)
  local k = node.k
  if k == "num" then return string.format("%.14g", node.v) end
  if k == "str" then return string.format("%q", node.v) end
  if k == "bool" then return tostring(node.v) end
  if k == "nil" then return "nil" end
  if k == "name" then return node.v end
  if k == "paren" then return "(" .. source(node.e) .. ")" end
  if k == "index" then return source(node.obj) .. "." .. node.key end
  local function args()
    local parts = {}
    for i, arg in ipairs(node.args) do parts[i] = source(arg) end
    return "(" .. table.concat(parts, ", ") .. ")"
  end
  if k == "call" then return source(node.fn) .. args() end
  if k == "method" then return source(node.obj) .. ":" .. node.name .. args() end
  if k == "un" then return node.op .. (node.op == "not" and " " or "") .. source(node.e) end
  return source(node.l) .. " " .. node.op .. " " .. source(node.r)
end

-- ─── Writing the search ──────────────────────────────────────────────────────────────────────────

-- Values while converting: { k = "const", v } (a Lua value), { k = "num", e, p, plain? } (a number of
-- the item or the player: the search's expression, its precedence, a plainer field for a comparison
-- with a number), { k = "text", e, item, slot? } (a text: the search's word, whether the item's, and
-- for the slot whether it holds the token or the name), { k = "cond", q, p, inner?, nilWhenFalse? } (a
-- condition: the search, its precedence OR 1, AND 2, else 3; what it negates; nil rather than false
-- when it fails, as string.find), { k = "token", v } (an INVTYPE_ constant), { k = "fn", name }.

local function const(v) return { k = "const", v = v } end
local function truthy(v) return v ~= nil and v ~= false end
local function cond(q, p) return { k = "cond", q = q, p = p or 3 } end

local function wrapCond(c, min)
  if c.p < min then return "(" .. c.q .. ")" end
  return c.q
end

local function andCond(a, b)
  if a.k == "const" then return truthy(a.v) and b or const(false) end
  if b.k == "const" then return truthy(b.v) and a or const(false) end
  return cond(wrapCond(a, 2) .. " AND " .. wrapCond(b, 2), 2)
end

-- Nothing binds looser than OR, so its sides need no parentheses.
local function orCond(a, b)
  if a.k == "const" then return truthy(a.v) and const(true) or b end
  if b.k == "const" then return truthy(b.v) and const(true) or a end
  return cond(a.q .. " OR " .. b.q, 1)
end

local function notCond(c)
  if c.k == "const" then return const(not truthy(c.v)) end
  if c.inner then return c.inner end
  local negated = cond("NOT " .. wrapCond(c, 3), 3)
  negated.inner = c
  return negated
end

-- quote writes a text as the search reads it quoted.
---@param text string
---@return string
local function quote(text)
  if not text:find('"', 1, true) then return '"' .. text .. '"' end
  if not text:find("'", 1, true) then return "'" .. text .. "'" end
  return '"' .. (text:gsub('"', '\\"')) .. '"'
end

---@param n number
---@return string
local function numText(n)
  if n ~= n or n == math.huge or n == -math.huge then
    fail(L:G("The rule works out a number that is not finite."))
  end
  local text = string.format("%.14g", n)
  if tonumber(text) ~= n then
    text = string.format("%.17g", n)
  end
  return text
end

---@param state table
---@param text string
local function note(state, text)
  if not state.noted[text] then
    state.noted[text] = true
    table.insert(state.notes, text)
  end
end

-- numExpr writes a number for the search, wrapped in parentheses when its precedence is below min
-- (or equal to it, on the right of an operator).
local function numExpr(v, min, right)
  if v.k == "const" then
    if type(v.v) ~= "number" then
      fail(format(L:G("%s is not a number."), tostring(v.v)))
    end
    return numText(v.v)
  end
  if min and (v.p < min or (right and v.p == min)) then
    return "(" .. v.e .. ")"
  end
  return v.e
end

local value, truth

---@param state table
---@param name string
---@return table
local function resolveName(state, name)
  if NUMBERS[name] then return { k = "num", e = NUMBERS[name], p = 3 } end
  if name == "ExpansionPackId" then return { k = "num", e = "expansionid", p = 3, plain = "exp" } end
  if DERIVED[name] then return { k = "num", e = DERIVED[name][1], p = DERIVED[name][2] } end
  if name == "EquipLoc" then return { k = "text", e = "slot", item = true, slot = "token" } end
  if name == "EquipLocName" then return { k = "text", e = "slot", item = true, slot = "name" } end
  if TEXTS[name] then return { k = "text", e = TEXTS[name], item = true } end
  if name == "PlayerName" then return { k = "text", e = "player.name" } end
  if name == "PlayerRealm" then return { k = "text", e = "player.realm" } end
  if NOTES[name] then note(state, L:G(NOTES[name])) end
  if BOOLS[name] then return cond(BOOLS[name] .. " = true") end
  local classic = state.opts.classic == true
  if name == "IsSoulbound" then
    return classic and cond("bound = true") or cond("binding = soulbound OR binding = quest OR binding = refundable", 1)
  end
  if name == "IsBindOnEquip" then
    return classic and cond("binding = boe") or cond("binding = boe OR binding = wue", 1)
  end
  if name == "IsBindOnUse" then return cond("binding = bou") end
  if name == "IsWarbound" or name == "IsAccountBound" then return cond("binding = warbound OR binding = wue", 1) end
  if name == "IsWarboundUntilEquip" then return cond("binding = wue") end
  if name == "IsUnsellable" then return cond("price = 0") end
  if name == "IsFullyUpgraded" then return cond("upgradeable = true AND upgradelevel = upgrademax", 2) end
  if name == "IsProfessionEquipment" then return cond("equipment = true AND class = 19", 2) end
  if name == "IsAppearanceCollected" then return cond("appearance = known") end
  if name == "IsUnknownAppearance" then return cond("appearance = unknown") end
  if name == "IsBagAndSlot" then return const(true) end
  if name == "IsEquipped" then return const(false) end
  if UNSUPPORTED[name] then
    fail(format(L:G("BetterBags' search has nothing for %s."), name))
  end
  local params = state.opts.params
  if params and params[name] ~= nil then return const(params[name]) end
  if name == "CURRENT_EXPANSION" then return const(classic and CONSTANTS.MISTS_OF_PANDARIA or CONSTANTS.WAR_WITHIN) end
  if CONSTANTS[name] ~= nil then return const(CONSTANTS[name]) end
  if INVTYPES[name] then return { k = "token", v = name } end
  if name == "math" or name == "string" then return { k = "namespace", v = name } end
  if PLAYER[name] or LISTS[name] or FUNCTIONS[name] or MATH[name] or name == "Pawn_IsUpgrade" then
    return { k = "fn", name = name }
  end
  for _, prefix in ipairs(ADDONS) do
    if name:find(prefix[1]) then return { k = "fn", name = name } end
  end
  fail(format(L:G("%s is not something a Vendor rule can use."), name))
end

-- constArgs works out a call's arguments, each a constant.
---@param state table
---@param args table[]
---@param name string
---@return any[]
local function constArgs(state, args, name)
  local values = {}
  for i, arg in ipairs(args) do
    local v = value(state, arg)
    if v.k ~= "const" then
      fail(format(L:G("%s takes only fixed values in an imported rule."), name))
    end
    values[i] = v.v
  end
  return values
end

-- plainOf reads a Lua pattern of plain characters as the text it finds; a pattern that matches by
-- character classes or anchors cannot be.
---@param state table
---@param pattern string
---@return string
local function plainOf(state, pattern)
  if pattern:find("%%%w") or pattern:find("[%[%]]") or pattern:sub(1, 1) == "^"
    or (pattern:sub(-1) == "$" and pattern:sub(-2, -2) ~= "%") then
    fail(format(L:G("%s is a Lua pattern; BetterBags searches for plain text."), quote(pattern)))
  end
  if (pattern:gsub("%%%p", "")):find("[%.%*%+%-%?%(%)]") then
    note(state, format(L:G("%s is read as plain text, not as a Lua pattern."), quote(pattern)))
  end
  return (pattern:gsub("%%(%p)", "%1"))
end

-- textFind is string.find or string.match of a text: found anywhere in it.
---@param state table
---@param subject table
---@param args table[] The pattern, then string.find's init and plain.
---@param name string
---@return table
local function textFind(state, subject, args, name)
  if subject.k ~= "text" or subject.slot == "token" then
    fail(format(L:G("%s can only search an item's text in an imported rule."), name))
  end
  local values = constArgs(state, args, name)
  local pattern, init, plain = values[1], values[2], values[3]
  if type(pattern) ~= "string" or (init ~= nil and init ~= 1) then
    fail(format(L:G("%s takes a text to find in an imported rule."), name))
  end
  local found = cond(subject.e .. " %= " .. quote(truthy(plain) and pattern or plainOf(state, pattern)))
  found.nilWhenFalse = true
  return found
end

---@param state table
---@param name string
---@param args table[]
---@return table
local function mathCall(state, name, args)
  if #args == 0 then
    fail(format(L:G("%s needs a number."), name))
  end
  local values, constant = {}, true
  for i, arg in ipairs(args) do
    local v = value(state, arg)
    if v.k ~= "num" and not (v.k == "const" and type(v.v) == "number") then
      fail(format(L:G("%s needs numbers."), name))
    end
    values[i] = v
    constant = constant and v.k == "const"
  end
  if name ~= "min" and name ~= "max" then
    values = { values[1] }
  end
  if constant then
    local numbers = {}
    for i, v in ipairs(values) do numbers[i] = v.v end
    return const(MATH[name](unpack(numbers)))
  end
  local parts = {}
  for i, v in ipairs(values) do parts[i] = numExpr(v) end
  return { k = "num", e = name .. "(" .. table.concat(parts, ", ") .. ")", p = 3 }
end

---@param state table
---@param node table A call node.
---@return table
local function call(state, node)
  local fn = value(state, node.fn)
  if fn.k ~= "fn" then
    -- Properties used to be written as functions (Level(), SubTypeId()).
    if node.fn.k == "name" and #node.args == 0 and (fn.k == "num" or fn.k == "text" or fn.k == "cond") then
      note(state, format(L:G("%s() is read as %s, as Vendor writes properties now."), node.fn.v, node.fn.v))
      return fn
    end
    fail(format(L:G("%s is not a function."), source(node.fn)))
  end
  local name, args = fn.name, node.args
  if PLAYER[name] then
    return { k = PLAYER[name][1], e = PLAYER[name][2], p = 3 }
  end
  if LISTS[name] then
    fail(format(L:G("%s reads Vendor's lists: add the items to the category instead."), name))
  end
  if name == "Pawn_IsUpgrade" then
    note(state, L:G("Pawn_IsUpgrade reads as upgrade: the upgrade arrow BetterBags draws, from the upgrade provider chosen (Pawn's while Pawn is on)."))
    return cond("upgrade = true")
  end
  for _, prefix in ipairs(ADDONS) do
    if name:find(prefix[1]) then
      fail(format(L:G("%s reads another addon's data (%s)."), name, prefix[2]))
    end
  end
  local short = name:match("^math%.(%a+)$") or name
  if MATH[short] then
    return mathCall(state, short, args)
  end
  if name == "string.find" or name == "string.match" then
    if #args == 0 then fail(format(L:G("%s needs a text."), name)) end
    local rest = {}
    for i = 2, #args do rest[i - 1] = args[i] end
    return textFind(state, value(state, args[1]), rest, name)
  end
  if name == "TooltipContains" then
    local text = args[1] and value(state, args[1])
    local found
    if text and text.k == "const" and type(text.v) == "string" then
      found = cond("tooltip %= " .. quote(plainOf(state, text.v)))
    elseif text and text.k == "text" and not text.item then
      found = cond("tooltip %= " .. text.e)
    else
      fail(L:G("TooltipContains takes a text, or a player's text, in an imported rule."))
    end
    local more = constArgs(state, { args[2], args[3] }, name)
    if more[1] ~= nil then
      note(state, format(L:G("TooltipContains looks in the whole tooltip, not only its %s side."), tostring(more[1])))
    end
    if more[2] ~= nil then
      note(state, format(L:G("TooltipContains looks in the whole tooltip, not only line %s."), tostring(more[2])))
    end
    return found
  end
  if name == "HasStat" then
    local found = const(false)
    for _, alias in ipairs(constArgs(state, args, name)) do
      local key = type(alias) == "string" and STATS[string.lower(alias)]
      local statName = key and state.globals[key]
      if type(statName) == "string" and statName ~= "" then
        found = orCond(found, cond("stat == " .. quote(statName)))
      end
    end
    return found
  end
  if name == "IsInEquipmentSet" then
    if #args == 0 then return cond("inset = true") end
    local found = const(false)
    for _, set in ipairs(constArgs(state, args, name)) do
      if type(set) ~= "string" then fail(L:G("IsInEquipmentSet takes the names of equipment sets.")) end
      found = orCond(found, cond("equipmentset == " .. quote(set)))
    end
    return found
  end
  if name == "HasProfession" then
    local found = const(false)
    for _, profession in ipairs(constArgs(state, args, name)) do
      local line = type(profession) == "string" and PROFESSIONS[string.upper(profession)] or profession
      if PROFESSION_LINES[line] then
        found = orCond(found, cond("player.profession = " .. line))
      end
    end
    return found
  end
  if name == "TotalItemCount" then
    for _, given in ipairs(constArgs(state, args, name)) do
      if truthy(given) then
        note(state, L:G("total counts the item in the bags it is in (the backpack's or the bank's), not in both."))
      end
    end
    return { k = "num", e = "total", p = 3 }
  end
  if name == "WatermarkLevel" then
    if truthy(constArgs(state, args, name)[1]) then
      fail(L:G("WatermarkLevel(true) asks for the account's best item level, which BetterBags does not keep."))
    end
    return { k = "num", e = "slotbest", p = 3 }
  end
  if name == "CurrentEquippedLevel" then
    return { k = "num", e = "slotequipped", p = 3 }
  end
  fail(format(L:G("%s is not supported in an imported rule."), name))
end

-- compare converts a comparison of two values.
---@param state table
---@param op string Lua's operator.
---@param a table
---@param b table
---@return table
local function compare(state, op, a, b)
  local equality = op == "==" or op == "~="
  if a.k == "fn" or b.k == "fn" or a.k == "namespace" or b.k == "namespace" then
    fail(L:G("A function is compared without being called."))
  end
  if a.k == "const" and b.k == "const" then
    if equality then return const((a.v == b.v) == (op == "==")) end
    if type(a.v) ~= type(b.v) or (type(a.v) ~= "number" and type(a.v) ~= "string") then
      fail(L:G("The rule orders values that cannot be ordered."))
    end
    local x, y = a.v, b.v
    if op == "<" then return const(x < y) end
    if op == "<=" then return const(x <= y) end
    if op == ">" then return const(x > y) end
    return const(x >= y)
  end
  if (a.k == "const" and b.k ~= "const") or (a.k == "token" and b.k == "text") then
    a, b, op = b, a, FLIP[op]
  end
  local function always()
    if not equality then fail(L:G("The rule orders values that cannot be ordered.")) end
    return const(op == "~=")
  end
  if a.k == "cond" then
    if b.k == "const" then
      if not equality then fail(L:G("The rule orders a condition.")) end
      local result
      if b.v == true then
        result = a
      elseif b.v == false then
        result = notCond(a)
      elseif b.v == nil and a.nilWhenFalse then
        result = notCond(a)
      else
        result = const(false)
      end
      if op == "~=" then return notCond(result) end
      return result
    end
    if b.k == "cond" then
      if not equality then fail(L:G("The rule orders a condition.")) end
      if op == "==" then return orCond(andCond(a, b), andCond(notCond(a), notCond(b))) end
      return orCond(andCond(a, notCond(b)), andCond(notCond(a), b))
    end
    return always()
  end
  if a.k == "num" then
    if b.k == "const" then
      if type(b.v) ~= "number" then return always() end
      return cond((a.plain or numExpr(a)) .. " " .. NUMBER_OPS[op] .. " " .. numText(b.v))
    end
    if b.k == "num" then
      return cond(numExpr(a) .. " " .. NUMBER_OPS[op] .. " " .. numExpr(b))
    end
    if b.k == "cond" then return compare(state, FLIP[op], b, a) end
    return always()
  end
  if a.k == "text" then
    if not equality then
      fail(L:G("BetterBags' search does not order texts."))
    end
    if b.k == "const" then
      if type(b.v) ~= "string" then return always() end
      if a.slot == "token" then
        if not b.v:match("^INVTYPE_[%w_]+$") then
          fail(format(L:G("EquipLoc holds a slot's INVTYPE_ token; it never is %s."), quote(b.v)))
        end
        return cond("slot " .. op .. " " .. b.v)
      end
      return cond(a.e .. " " .. op .. " " .. quote(b.v))
    end
    if b.k == "token" then
      if not a.slot then
        fail(format(L:G("%s is compared with a slot."), a.e))
      end
      if a.slot == "token" then
        note(state, format(L:G("In Vendor %s is the slot's name, so EquipLoc == %s never matches; it is read as the slot."), b.v, b.v))
      end
      return cond("slot " .. op .. " " .. b.v)
    end
    if b.k == "text" then
      if a.item and b.item then
        fail(L:G("BetterBags' search cannot compare two texts of the item."))
      end
      if b.item then a, b = b, a end
      return cond(a.e .. " " .. op .. " " .. b.e)
    end
    if b.k == "cond" then return compare(state, FLIP[op], b, a) end
    return always()
  end
  if a.k == "token" then
    if b.k == "const" and type(b.v) == "string" then
      fail(format(L:G("%s is compared with a text."), a.v))
    end
    if b.k == "cond" then return compare(state, FLIP[op], b, a) end
    return always()
  end
  fail(L:G("The rule compares values that cannot be compared."))
end

-- arithmetic converts + - * / % of two values.
---@param op string
---@param a table
---@param b table
---@return table
local function arithmetic(op, a, b)
  local function number(v)
    return v.k == "num" or (v.k == "const" and type(v.v) == "number")
  end
  if not number(a) or not number(b) then
    fail(format(L:G("The rule does arithmetic (%s) on something that is not a number."), op))
  end
  if a.k == "const" and b.k == "const" then
    local x, y = a.v, b.v
    if op == "+" then return const(x + y) end
    if op == "-" then return const(x - y) end
    if op == "*" then return const(x * y) end
    if op == "/" then return const(x / y) end
    return const(x % y)
  end
  local level = (op == "+" or op == "-") and 1 or 2
  local left = numExpr(a, level, false)
  local right = numExpr(b, level, true)
  if a.k == "const" then left = numText(a.v) end
  if b.k == "const" then right = numText(b.v) end
  return { k = "num", e = left .. " " .. op .. " " .. right, p = level }
end

-- logic converts and / or used as a value (in a comparison or arithmetic): two conditions are a
-- condition; two constants are Lua's answer, its first or second value.
---@param state table
---@param node table
---@return table
local function logic(state, node)
  local a, b = value(state, node.l), value(state, node.r)
  local function boolish(v) return v.k == "cond" or (v.k == "const" and type(v.v) == "boolean") end
  if a.k == "const" and b.k == "const" then
    local chosen
    if node.op == "and" then
      chosen = truthy(a.v) and node.r or node.l
    else
      chosen = truthy(a.v) and node.l or node.r
    end
    if type(a.v) ~= "boolean" or type(b.v) ~= "boolean" then
      note(state, format(L:G("Vendor reads %s as %s: Lua's %s gives one of its values, not both."), source(node),
        source(chosen), node.op))
    end
    return chosen == node.l and a or b
  end
  if boolish(a) and boolish(b) then
    return node.op == "and" and andCond(a, b) or orCond(a, b)
  end
  fail(format(L:G("%s uses %s as a value; BetterBags' search has no such value."), source(node), node.op))
end

---@param state table
---@param node table
---@return table
value = function(state, node)
  local k = node.k
  if k == "num" or k == "str" or k == "bool" then return const(node.v) end
  if k == "nil" then return const(nil) end
  if k == "name" then return resolveName(state, node.v) end
  if k == "paren" then return value(state, node.e) end
  if k == "index" then
    local obj = value(state, node.obj)
    if obj.k == "namespace" then return { k = "fn", name = obj.v .. "." .. node.key } end
    fail(format(L:G("%s is not supported in an imported rule."), source(node)))
  end
  if k == "call" then return call(state, node) end
  if k == "method" then
    if node.name == "find" or node.name == "match" then
      return textFind(state, value(state, node.obj), node.args, source(node.obj) .. ":" .. node.name)
    end
    fail(format(L:G("%s is not supported in an imported rule."), source(node)))
  end
  if k == "un" then
    if node.op == "not" then return notCond(truth(state, node.e)) end
    local v = value(state, node.e)
    if node.op == "#" then
      if v.k == "const" and type(v.v) == "string" then return const(#v.v) end
      fail(L:G("The length operator (#) is not supported in an imported rule."))
    end
    if v.k == "const" and type(v.v) == "number" then return const(-v.v) end
    if v.k ~= "num" then fail(L:G("The rule negates something that is not a number.")) end
    return { k = "num", e = "- " .. numExpr(v, 3), p = 3 }
  end
  local op = node.op
  if op == "and" or op == "or" then return logic(state, node) end
  if FLIP[op] then return compare(state, op, value(state, node.l), value(state, node.r)) end
  local a, b = value(state, node.l), value(state, node.r)
  if op == "^" then
    if a.k == "const" and b.k == "const" and type(a.v) == "number" and type(b.v) == "number" then
      return const(a.v ^ b.v)
    end
    fail(L:G("BetterBags' search has no powers (^)."))
  end
  if op == ".." then
    local function text(v) return v.k == "const" and (type(v.v) == "string" or type(v.v) == "number") end
    if text(a) and text(b) then return const(a.v .. b.v) end
    fail(L:G("The rule joins texts (..) that are not fixed."))
  end
  return arithmetic(op, a, b)
end

-- truth converts a node used as a condition (inside and, or and not): Lua's truth, where every value
-- of an item is true (Vendor's properties are never nil).
---@param state table
---@param node table
---@return table
truth = function(state, node)
  if node.k == "paren" then return truth(state, node.e) end
  if node.k == "bin" and node.op == "and" then return andCond(truth(state, node.l), truth(state, node.r)) end
  if node.k == "bin" and node.op == "or" then return orCond(truth(state, node.l), truth(state, node.r)) end
  local v = value(state, node)
  if v.k == "cond" then return v end
  if v.k == "const" then return const(truthy(v.v)) end
  if v.k == "fn" or v.k == "namespace" then
    fail(format(L:G("%s is used without being called."), source(node)))
  end
  return const(true)
end

-- top converts the whole rule as Vendor reads its result (RulesEngine/rule.lua): a boolean as is, a
-- number when it is not 0, anything else false. and / or give one of their values, as in Lua.
---@param state table
---@param node table
---@return table
local function top(state, node)
  if node.k == "paren" then return top(state, node.e) end
  if node.k == "bin" and node.op == "and" then return andCond(truth(state, node.l), top(state, node.r)) end
  if node.k == "bin" and node.op == "or" then
    local left = node.l
    while left.k == "paren" do left = left.e end
    if left.k == "bin" and (left.op == "and" or left.op == "or") then
      return orCond(truth(state, left), top(state, node.r))
    end
    local a = value(state, left)
    if a.k == "cond" then return orCond(a, top(state, node.r)) end
    if a.k == "const" then
      if truthy(a.v) then return top(state, left) end
      return top(state, node.r)
    end
    return top(state, left)
  end
  local v = value(state, node)
  if v.k == "cond" then return v end
  if v.k == "const" then
    return const(v.v == true or (type(v.v) == "number" and v.v ~= 0))
  end
  if v.k == "num" then return cond(numExpr(v) .. " != 0") end
  if v.k == "fn" or v.k == "namespace" then
    fail(format(L:G("%s is used without being called."), source(node)))
  end
  return const(false)
end

-- Convert converts a Vendor rule into a BetterBags search: the search, or why it cannot be, and what
-- the search reads differently.
---@param script string The rule, as Vendor saves it (Script).
---@param opts? VendorRuleOptions
---@return VendorRuleResult
function VendorRule:Convert(script, opts)
  local state = { opts = opts or {}, notes = {}, noted = {} }
  state.globals = state.opts.globals or _G
  local ok, result = pcall(function()
    local converted = top(state, parse(lex(script)))
    if converted.k == "const" then
      fail(truthy(converted.v) and L:G("It matches every item.") or L:G("It matches no item."))
    end
    return converted.q
  end)
  if not ok then
    local problem = type(result) == "table" and result.vendorRule or tostring(result)
    return { problem = problem, notes = state.notes }
  end
  if QueryParser:Query(result) == nil then
    return { problem = format(L:G("%s could not be converted."), script), notes = state.notes }
  end
  return { query = result, notes = state.notes }
end
