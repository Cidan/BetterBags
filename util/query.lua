local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class QueryParser: AceModule
---@field VERSION number The version of the query language saved rules are written in (DB:MigrateSearchRules).
local QueryParser = addon:NewModule('QueryParser')

-- 1: AND and OR at one precedence, grouped left to right. 2: AND binds tighter than OR, as in Lua.
QueryParser.VERSION = 2

-- Node types: "logical" (AND, OR with left and right; NOT with expression), "comparison" (field op
-- value, both plain words: what the search has always read), "compare" (left op right, either an
-- expression), "term" (a word searched for everywhere), and the expressions: "word" (a word the
-- search resolves: a field, a player value, a number, money, or text), "arith" (+ - * / %), "neg"
-- (unary minus), "call" (a function). Never parsed: "set", items given in place of a condition (search-completion.md
-- §2).
---@class QueryNode
---@field type string
---@field value? string
---@field quoted? boolean The word was quoted: always text.
---@field left? QueryNode
---@field right? QueryNode
---@field operator? string
---@field field? string
---@field expression? QueryNode
---@field name? string A call's function.
---@field args? QueryNode[] A call's arguments.
---@field set? table<string, boolean> A set's items, by slot key.

-- FUNCTIONS are the functions a query can call; Vendor's math. spelling names the same.
QueryParser.FUNCTIONS = { min = true, max = true, floor = true, ceil = true, abs = true }

-- ARITH_SIGNS are words that are arithmetic operators when they stand alone; inside a word (100-10,
-- -5) they are part of it, as every query read them before arithmetic.
local ARITH_SIGNS = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true }

-- Lexer splits a query into tokens. Its second result is each token's span in the input:
-- { first character, last character }.
---@private
---@param input string
---@return QueryNode[], number[][]
function QueryParser:Lexer(input)
  ---@type QueryNode[]
  local tokens = {}
  ---@type number[][]
  local spans = {}
  local i = 1

  local function peek(offset)
    offset = offset or 0
    return input:sub(i + offset, i + offset)
  end

  local function advance(count)
    count = count or 1
    i = i + count --[[@as number]]
  end

  local function is_whitespace(char)
    return char:match("%s") ~= nil
  end

  local function is_alphanumeric(char)
    return char:match("[^%s%c()=!<>,]+") ~= nil
  end

  local function read_word()
    local value = ""
    while i <= #input do
      local char = peek()
      if char == "~" and peek(1) == "=" then
        break
      elseif is_alphanumeric(char) or char == "_" then
        value = value .. char
        advance()
      else
        break
      end
    end
    return value
  end

  ---@param quote_char string
  ---@return string
  local function read_quoted_string(quote_char)
    local value = ""
    advance() -- Skip the opening quote
    while i <= #input do
      local char = peek()
      if char == quote_char then
        advance() -- Skip the closing quote
        break
      elseif char == "\\" and peek(1) == quote_char then
        value = value .. quote_char
        advance(2) -- Skip the backslash and the escaped quote
      else
        value = value .. char
        advance()
      end
    end
    return value
  end

  while i <= #input do
    local char = peek()
    local first = i
    local count = #tokens

    if is_whitespace(char) then
      advance()
    elseif char == "(" or char == ")" then
      table.insert(tokens, {type = "paren", value = char})
      advance()
    elseif char == "," then
      table.insert(tokens, {type = "comma", value = char})
      advance()
    elseif char == "~" and peek(1) == "=" then
      table.insert(tokens, {type = "operator", value = "~="})
      advance(2)
    elseif char == "%" and peek(1) ~= "=" then
      table.insert(tokens, {type = "arith", value = "%"})
      advance()
    elseif char == "=" or char == "<" or char == ">" or char == "%" or char == "!" then
      if char == "=" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = "=="})
        advance(2)
      elseif char == "<" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = "<="})
        advance(2)
      elseif char == ">" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = ">="})
        advance(2)
      elseif char == "%" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = "%="})
        advance(2)
      elseif char == "!" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = "!="})
        advance(2)
      else
        table.insert(tokens, {type = "operator", value = char})
        advance()
      end
    elseif char == "'" or char == '"' then
      local quoted_string = read_quoted_string(char)
      table.insert(tokens, {type = "term", value = quoted_string, quoted = true})
    elseif is_alphanumeric(char) then
      local word = read_word()
      if word:upper() == "AND" or word:upper() == "OR" or word:upper() == "NOT" then
        table.insert(tokens, {type = "logical", value = word:upper()})
      elseif ARITH_SIGNS[word] then
        table.insert(tokens, {type = "arith", value = word})
      else
        table.insert(tokens, {type = "term", value = word})
      end
    else
      error("Unexpected character: " .. char)
    end
    if #tokens > count then
      spans[#tokens] = { first, i - 1 }
    end
  end

  return tokens, spans
end

-- TYPED are the tokens a cursor can be part way through typing; a parenthesis, a comma or a lone sign is whole as
-- soon as it is typed.
local TYPED = { term = true, operator = true, logical = true }

-- closedAt returns where a quoted token's closing quote is, or nil for a quote that runs to the end of the query.
---@param input string
---@param first number The opening quote.
---@param last number
---@return number?
local function closedAt(input, first, last)
  local quote = input:sub(first, first)
  local i = first + 1
  while i <= last do
    local char = input:sub(i, i)
    if char == "\\" and input:sub(i + 1, i + 1) == quote then
      i = i + 2
    elseif char == quote then
      return i
    else
      i = i + 1
    end
  end
  return nil
end

---@class QueryContext
---@field expects "condition"|"operator"|"value"|"join"|"none" What may come at the cursor.
---@field prefix string What is typed of the word at the cursor, up to it (inside its quotes for a quoted one).
---@field from number The first byte a suggestion replaces.
---@field to number The last byte it replaces (from - 1: none).
---@field quote? string The quote the word at the cursor opened with.
---@field field? string For an operator or a value: the one word on the left of the comparison.
---@field operator? string For a value: the comparison's operator.
---@field start? number For a value of a field: where the comparison starts, its field's first byte.
---@field after? string The type of the token after what is replaced.

-- Context returns what a query expects at its cursor (search-completion.md §1), from its tokens alone, so a query
-- typed only part way says it too: a condition (a field, NOT, a word), an operator after a word, a value after an
-- operator, AND or OR after a whole condition, or nothing (inside a function's arguments, after one). The word the
-- cursor is in or at the end of is what a suggestion replaces, all of it: a quoted one from its opening quote to
-- its closing quote, or to the cursor when it has none (it would run to the end of the query). nil when the lexer
-- cannot read the query.
---@param input string
---@param cursor number The bytes before the cursor (EditBox:GetCursorPosition).
---@return QueryContext?
function QueryParser:Context(input, cursor)
  local ok, tokens, spans = pcall(self.Lexer, self, input)
  if not ok then
    return nil
  end
  local current, before = nil, 0
  for n, span in ipairs(spans) do
    local first, last = span[1], span[2]
    if first > cursor then
      break
    end
    local token = tokens[n]
    local stop = last
    if token.quoted and closedAt(input, first, last) ~= nil then
      stop = last - 1
    end
    if TYPED[token.type] and cursor <= stop then
      current = n
      break
    end
    before = n
  end
  ---@type QueryContext
  local c = { expects = "condition", prefix = "", from = cursor + 1, to = cursor }
  if current ~= nil then
    local first, last = spans[current][1], spans[current][2]
    if tokens[current].quoted then
      local quote = input:sub(first, first)
      c.quote = quote
      c.prefix = input:sub(first + 1, cursor):gsub("\\" .. quote, quote)
      c.from, c.to = first, closedAt(input, first, last) or cursor
    else
      c.prefix = input:sub(first, cursor)
      c.from, c.to = first, last
    end
  end
  local following = tokens[(current or before) + 1]
  c.after = following and following.type or nil

  -- What the tokens before the word at the cursor leave expected: the condition being read (its side of the
  -- comparison, how many parts that side has, its one word and the operator), each parenthesis it is inside, and
  -- whether an operand or what follows one comes next.
  local stack = {}
  local cur = { side = "left", parts = 0 }
  local expect = "operand"
  for n = 1, before do
    local t = tokens[n]
    if t.type == "paren" and t.value == "(" then
      local prev = tokens[n - 1]
      local call = expect == "after" and prev ~= nil and prev.type == "term" and not prev.quoted
      table.insert(stack, { cur = cur, call = call })
      -- A call's arguments, and a parenthesis in a value (after an operator), are a value worked out; a parenthesis
      -- where a condition starts groups conditions.
      cur = { side = (call or cur.side ~= "left") and "arg" or "left", parts = 0 }
      expect = "operand"
    elseif t.type == "paren" then
      local top = table.remove(stack)
      if top ~= nil then
        cur = top.cur
        cur.expr = true
        cur.done = top.cond and not top.call
      end
      expect = "after"
    elseif t.type == "comma" then
      expect = "operand"
    elseif t.type == "logical" or t.type == "operator" then
      if stack[#stack] ~= nil then
        stack[#stack].cond = true
      end
      if t.type == "operator" then
        cur.field = cur.side == "left" and cur.parts == 1 and not cur.expr and cur.word or nil
        cur.start = cur.field and cur.wordAt or nil
        cur.op, cur.side, cur.parts, cur.expr = t.value, "right", 0, false
      elseif t.value ~= "NOT" then
        cur = { side = "left", parts = 0 }
      end
      expect = "operand"
    elseif t.type == "arith" then
      cur.expr = true
      expect = "operand"
    else
      cur.parts = cur.parts + 1
      cur.word = not t.quoted and t.value or nil
      cur.wordAt = spans[n][1]
      expect = "after"
    end
  end
  if expect == "operand" then
    if cur.side == "right" then
      c.expects, c.operator = "value", cur.op
      c.field = cur.parts == 0 and not cur.expr and cur.field or nil
      c.start = c.field and cur.start or nil
    elseif cur.side == "arg" then
      c.expects = "value"
    end
  elseif cur.side == "arg" then
    c.expects = "none"
  elseif cur.side == "left" and not cur.done then
    c.expects = "operator"
    c.field = cur.parts == 1 and not cur.expr and cur.word or nil
  else
    c.expects = "join"
  end
  return c
end

-- CONDITIONS are the node types that are true or false for an item; the others are values.
local CONDITIONS = { logical = true, comparison = true, compare = true, term = true }

---@private
---@param tokens QueryNode[]
---@return QueryNode
function QueryParser:Parser(tokens)
  local i = 1

  local function peek()
    return tokens[i]
  end

  local function advance()
    i = i + 1
  end

  local function is(type, value)
    local token = peek()
    return token ~= nil and token.type == type and (value == nil or token.value == value)
  end

  ---@param node QueryNode
  ---@return QueryNode
  local function condition(node)
    if not CONDITIONS[node.type] then
      error("Expected a comparison")
    end
    return node
  end

  ---@param node QueryNode
  ---@return QueryNode
  local function value(node)
    if CONDITIONS[node.type] then
      error("Expected a value")
    end
    return node
  end

  ---@type fun(): QueryNode
  local parse_or
  ---@type fun(): QueryNode
  local parse_sum

  -- primary: a parenthesized expression, a word (or a function called with it), or a quoted text.
  ---@return QueryNode
  local function parse_primary()
    if is("paren", "(") then
      advance()
      local expr = parse_or()
      -- A missing ")" at the end of the query is forgiven, as it always was.
      if is("paren", ")") then
        advance()
      elseif peek() then
        error("Expected )")
      end
      return expr
    elseif is("term") then
      local token = peek()
      advance()
      if not token.quoted and is("paren", "(") then
        local name = string.lower(token.value):gsub("^math%.", "")
        if not QueryParser.FUNCTIONS[name] then
          error("Unknown function: " .. token.value)
        end
        advance()
        local args = {}
        if not is("paren", ")") then
          repeat
            table.insert(args, value(parse_sum()))
            local more = is("comma")
            if more then advance() end
          until not more
        end
        if not is("paren", ")") then
          error("Expected ) after the arguments")
        end
        advance()
        return { type = "call", name = name, args = args }
      end
      return { type = "word", value = token.value, quoted = token.quoted }
    end
    error("Unexpected token: " .. (peek() and peek().type or "nil"))
  end

  ---@return QueryNode
  local function parse_unary()
    if is("arith", "-") then
      advance()
      return { type = "neg", expression = value(parse_unary()) }
    end
    return parse_primary()
  end

  -- binaryArith reads operands joined by any of signs, grouped left to right.
  ---@param signs table<string, boolean>
  ---@param next fun(): QueryNode
  ---@return QueryNode
  local function binaryArith(signs, next)
    local left = next()
    while is("arith") and signs[peek().value] do
      local op = peek().value
      advance()
      left = { type = "arith", operator = op, left = value(left), right = value(next()) }
    end
    return left
  end

  local PRODUCT = { ["*"] = true, ["/"] = true, ["%"] = true }
  local SUM = { ["+"] = true, ["-"] = true }

  local function parse_product()
    return binaryArith(PRODUCT, parse_unary)
  end

  parse_sum = function()
    return binaryArith(SUM, parse_product)
  end

  -- comparison: two values and an operator, or one condition. A word compared with a word is a
  -- plain comparison, as queries have always been read; anything else compares expressions.
  ---@return QueryNode
  local function parse_comparison()
    local left = parse_sum()
    if is("operator") then
      local op = peek().value
      advance()
      if not peek() then
        error("Expected term after operator")
      end
      local right = value(parse_sum())
      value(left)
      if left.type == "word" and right.type == "word" then
        return { type = "comparison", field = left.value, operator = op, value = right.value,
          quoted = right.quoted }
      end
      return { type = "compare", left = left, operator = op, right = right }
    end
    if left.type == "word" then
      return { type = "term", value = left.value, quoted = left.quoted }
    end
    return left
  end

  ---@return QueryNode
  local function parse_not()
    if is("logical", "NOT") then
      advance()
      return { type = "logical", operator = "NOT", expression = condition(parse_not()) }
    end
    return parse_comparison()
  end

  -- binary reads conditions joined by op, grouped left to right. NOT only comes before what it
  -- negates (parse_not), never after a term.
  ---@param op string
  ---@param next fun(): QueryNode
  ---@return QueryNode
  local function binary(op, next)
    local left = next()
    while is("logical") do
      if peek().value == "NOT" then
        error("Unexpected NOT after a term")
      end
      if peek().value ~= op then
        break
      end
      advance()
      left = { type = "logical", operator = op, left = condition(left), right = condition(next()) }
    end
    return left
  end

  -- AND binds tighter than OR, as in Lua.
  local function parse_and()
    return binary("AND", parse_not)
  end

  parse_or = function()
    return binary("OR", parse_and)
  end

  return condition(parse_or())
end

-- GroupLeftToRight returns a query with parentheses added where it mixes AND and OR, so that,
-- read with AND binding tighter than OR, it means what it meant when the two had one precedence and
-- grouped left to right: wherever an AND follows an OR at the same level, everything before the AND
-- at that level is put in parentheses. A query that needs none, or does not parse, is returned as
-- it is. Run once per saved rule (DB:MigrateSearchRules): a rule written for the current precedence
-- would change meaning.
---@param input string
---@return string
function QueryParser:GroupLeftToRight(input)
  if self:Query(input) == nil then
    return input
  end
  local tokens, spans = self:Lexer(input)
  local opens, closes = {}, {}
  local changed = false
  local levels = { { start = spans[1] and spans[1][1], mixed = false } }
  for n, token in ipairs(tokens) do
    local level = levels[#levels]
    if token.type == "paren" and token.value == "(" then
      -- A group's own parentheses open where its "(" is: "((" either way.
      table.insert(levels, { start = spans[n][1], mixed = false })
    elseif token.type == "paren" then
      -- A stray closing parenthesis ended the query; what follows it never counted.
      if #levels == 1 then
        break
      end
      table.remove(levels)
    elseif token.type == "logical" and token.value == "OR" then
      level.mixed = true
    elseif token.type == "logical" and token.value == "AND" and level.mixed then
      opens[level.start] = (opens[level.start] or 0) + 1
      local stop = spans[n - 1][2]
      closes[stop] = (closes[stop] or 0) + 1
      level.mixed = false
      changed = true
    end
  end
  if not changed then
    return input
  end
  local out = {}
  for at = 1, #input do
    table.insert(out, string.rep("(", opens[at] or 0))
    table.insert(out, input:sub(at, at))
    table.insert(out, string.rep(")", closes[at] or 0))
  end
  return table.concat(out)
end

function QueryParser:Query(input)
  local ok, ast = pcall(function()
    local tokens = self:Lexer(input)
    return self:Parser(tokens)
  end)
  if not ok then return end
  return ast
end