local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class QueryParser: AceModule
local QueryParser = addon:NewModule('QueryParser')

---@class QueryNode
---@field type string
---@field value? string
---@field left? QueryNode
---@field right? QueryNode
---@field operator? string
---@field field? string
---@field expression? QueryNode

---@private
---@param input string
---@return QueryNode[]
function QueryParser:Lexer(input)
  ---@type QueryNode[]
  local tokens = {}
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
    return char:match("[%w]") ~= nil
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

    if is_whitespace(char) then
      advance()
    elseif char == "(" or char == ")" then
      table.insert(tokens, {type = "paren", value = char})
      advance()
    elseif char == "=" or char == "<" or char == ">" then
      if char == "<" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = "<="})
        advance(2)
      elseif char == ">" and peek(1) == "=" then
        table.insert(tokens, {type = "operator", value = ">="})
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
  end

  return tokens
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

  parse_expression = function()
    local left = parse_term()

    while peek() and peek().type == "logical" do
      local op = peek().value
      advance()
      local right = parse_term()
      left = {type = "logical", operator = op, left = left, right = right}
    end
    return left
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

function QueryParser:Query(input)
  local ok, ast = pcall(function()
    local tokens = self:Lexer(input)
    return self:Parser(tokens)
  end)
  if not ok then return end
  return ast
end