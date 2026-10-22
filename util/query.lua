local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class QueryParser: AceModule
---@field VERSION number The version of the query language saved rules are written in (DB:MigrateSearchRules).
local QueryParser = addon:NewModule('QueryParser')

-- 1: AND and OR at one precedence, grouped left to right. 2: AND binds tighter than OR, as in Lua.
QueryParser.VERSION = 2

---@class QueryNode
---@field type string
---@field value? string
---@field left? QueryNode
---@field right? QueryNode
---@field operator? string
---@field field? string
---@field expression? QueryNode

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
    return char:match("[^%s%c()=!<>]+") ~= nil
  end

  local function read_word()
    local value = ""
    while i <= #input do
      local char = peek()
      if is_alphanumeric(char) or char == "_" then
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
    elseif char == "=" or char == "<" or char == ">" or char == "%" or char == "!" then
      if char == "<" and peek(1) == "=" then
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
      table.insert(tokens, {type = "term", value = quoted_string})
    elseif is_alphanumeric(char) then
      local word = read_word()
      if word:upper() == "AND" or word:upper() == "OR" or word:upper() == "NOT" then
        table.insert(tokens, {type = "logical", value = word:upper()})
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

  ---@type fun(): QueryNode
  local parse_expression
  ---@type fun(): QueryNode
  local parse_term

  -- binary reads terms joined by op, grouped left to right; next reads each side. NOT only comes
  -- before what it negates (parse_term), never after a term.
  ---@param op string
  ---@param next fun(): QueryNode
  ---@return QueryNode
  local function binary(op, next)
    local left = next()
    while peek() and peek().type == "logical" do
      if peek().value == "NOT" then
        error("Unexpected NOT after a term")
      end
      if peek().value ~= op then
        break
      end
      advance()
      left = {type = "logical", operator = op, left = left, right = next()}
    end
    return left
  end

  -- AND binds tighter than OR, as in Lua.
  local function parse_and()
    return binary("AND", parse_term)
  end

  parse_expression = function()
    return binary("OR", parse_and)
  end

  parse_term = function()
    if peek() and peek().type == "paren" and peek().value == "(" then
      advance()
      local expr = parse_expression()
      if peek() and peek().type == "paren" and peek().value == ")" then
        advance()
      end
      return expr
    elseif peek() and peek().type == "logical" and peek().value == "NOT" then
      advance()
      local expr = parse_term()
      return {type = "logical", operator = "NOT", expression = expr}
    elseif peek() and peek().type == "term" then
      local term = peek().value
      advance()
      if peek() and peek().type == "operator" then
        local op = peek().value
        advance()
        if not (peek() and peek().type == "term") then
          error("Expected term after operator")
        end
        local value = peek().value
        advance()
        return {type = "comparison", field = term, operator = op, value = value}
      else
        return {type = "term", value = term}
      end
    else
      error("Unexpected token: " .. (peek() and peek().type or "nil"))
    end
  end

  return parse_expression()
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