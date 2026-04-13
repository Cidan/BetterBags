-- query_spec.lua -- Unit tests for util/query.lua (QueryParser module)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
LoadBetterBagsModule("util/query.lua")
local QueryParser = addon:GetModule("QueryParser")

describe("QueryParser", function()

  -- ─── Lexer ──────────────────────────────────────────────────────────────────

  describe("Lexer", function()

    it("tokenizes a simple word", function()
      local tokens = QueryParser:Lexer("sword")
      assert.same({{type = "term", value = "sword"}}, tokens)
    end)

    it("tokenizes multiple words as separate terms", function()
      local tokens = QueryParser:Lexer("sword shield")
      assert.same({
        {type = "term", value = "sword"},
        {type = "term", value = "shield"},
      }, tokens)
    end)

    it("tokenizes double-quoted strings", function()
      local tokens = QueryParser:Lexer('"hello world"')
      assert.same({{type = "term", value = "hello world"}}, tokens)
    end)

    it("tokenizes single-quoted strings", function()
      local tokens = QueryParser:Lexer("'hello world'")
      assert.same({{type = "term", value = "hello world"}}, tokens)
    end)

    it("handles escaped quotes inside quoted strings", function()
      local tokens = QueryParser:Lexer('"he said \\"hello\\""')
      assert.same({{type = "term", value = 'he said "hello"'}}, tokens)
    end)

    it("tokenizes the = operator", function()
      local tokens = QueryParser:Lexer("quality = epic")
      assert.same({
        {type = "term", value = "quality"},
        {type = "operator", value = "="},
        {type = "term", value = "epic"},
      }, tokens)
    end)

    it("tokenizes the != operator", function()
      local tokens = QueryParser:Lexer("type != junk")
      assert.same({
        {type = "term", value = "type"},
        {type = "operator", value = "!="},
        {type = "term", value = "junk"},
      }, tokens)
    end)

    it("tokenizes the <= operator", function()
      local tokens = QueryParser:Lexer("level <= 60")
      assert.same({
        {type = "term", value = "level"},
        {type = "operator", value = "<="},
        {type = "term", value = "60"},
      }, tokens)
    end)

    it("tokenizes the >= operator", function()
      local tokens = QueryParser:Lexer("level >= 10")
      assert.same({
        {type = "term", value = "level"},
        {type = "operator", value = ">="},
        {type = "term", value = "10"},
      }, tokens)
    end)

    it("tokenizes the %= operator", function()
      local tokens = QueryParser:Lexer("name %= sword")
      assert.same({
        {type = "term", value = "name"},
        {type = "operator", value = "%="},
        {type = "term", value = "sword"},
      }, tokens)
    end)

    it("tokenizes single-char operators", function()
      local tokens = QueryParser:Lexer("a < b")
      assert.same({
        {type = "term", value = "a"},
        {type = "operator", value = "<"},
        {type = "term", value = "b"},
      }, tokens)
    end)

    it("tokenizes AND as a logical operator", function()
      local tokens = QueryParser:Lexer("sword AND shield")
      assert.same({
        {type = "term", value = "sword"},
        {type = "logical", value = "AND"},
        {type = "term", value = "shield"},
      }, tokens)
    end)

    it("tokenizes OR as a logical operator", function()
      local tokens = QueryParser:Lexer("sword OR shield")
      assert.same({
        {type = "term", value = "sword"},
        {type = "logical", value = "OR"},
        {type = "term", value = "shield"},
      }, tokens)
    end)

    it("tokenizes NOT as a logical operator", function()
      local tokens = QueryParser:Lexer("NOT sword")
      assert.same({
        {type = "logical", value = "NOT"},
        {type = "term", value = "sword"},
      }, tokens)
    end)

    it("treats logical operators as case-insensitive", function()
      local tokens = QueryParser:Lexer("sword and shield or not axe")
      assert.same({
        {type = "term", value = "sword"},
        {type = "logical", value = "AND"},
        {type = "term", value = "shield"},
        {type = "logical", value = "OR"},
        {type = "logical", value = "NOT"},
        {type = "term", value = "axe"},
      }, tokens)
    end)

    it("tokenizes parentheses", function()
      local tokens = QueryParser:Lexer("(sword)")
      assert.same({
        {type = "paren", value = "("},
        {type = "term", value = "sword"},
        {type = "paren", value = ")"},
      }, tokens)
    end)

    it("handles words with underscores", function()
      local tokens = QueryParser:Lexer("item_level")
      assert.same({{type = "term", value = "item_level"}}, tokens)
    end)

    it("handles words with numbers", function()
      local tokens = QueryParser:Lexer("tier5")
      assert.same({{type = "term", value = "tier5"}}, tokens)
    end)

    it("returns an empty table for empty input", function()
      local tokens = QueryParser:Lexer("")
      assert.same({}, tokens)
    end)

    it("returns an empty table for whitespace-only input", function()
      local tokens = QueryParser:Lexer("   ")
      assert.same({}, tokens)
    end)

    it("tokenizes a complex expression", function()
      local tokens = QueryParser:Lexer("quality >= 4 AND (name %= sword OR name %= shield)")
      assert.same({
        {type = "term", value = "quality"},
        {type = "operator", value = ">="},
        {type = "term", value = "4"},
        {type = "logical", value = "AND"},
        {type = "paren", value = "("},
        {type = "term", value = "name"},
        {type = "operator", value = "%="},
        {type = "term", value = "sword"},
        {type = "logical", value = "OR"},
        {type = "term", value = "name"},
        {type = "operator", value = "%="},
        {type = "term", value = "shield"},
        {type = "paren", value = ")"},
      }, tokens)
    end)
  end)

  -- ─── Parser ─────────────────────────────────────────────────────────────────

  describe("Parser", function()

    -- Helper: lex then parse
    local function parse(input)
      local tokens = QueryParser:Lexer(input)
      return QueryParser:Parser(tokens)
    end

    it("parses a simple term", function()
      local ast = parse("sword")
      assert.same({type = "term", value = "sword"}, ast)
    end)

    it("parses a comparison with =", function()
      local ast = parse("quality = epic")
      assert.same({
        type = "comparison",
        field = "quality",
        operator = "=",
        value = "epic",
      }, ast)
    end)

    it("parses a comparison with >=", function()
      local ast = parse("level >= 60")
      assert.same({
        type = "comparison",
        field = "level",
        operator = ">=",
        value = "60",
      }, ast)
    end)

    it("parses a comparison with <=", function()
      local ast = parse("level <= 20")
      assert.same({
        type = "comparison",
        field = "level",
        operator = "<=",
        value = "20",
      }, ast)
    end)

    it("parses a comparison with !=", function()
      local ast = parse("type != junk")
      assert.same({
        type = "comparison",
        field = "type",
        operator = "!=",
        value = "junk",
      }, ast)
    end)

    it("parses a comparison with %=", function()
      local ast = parse("name %= sword")
      assert.same({
        type = "comparison",
        field = "name",
        operator = "%=",
        value = "sword",
      }, ast)
    end)

    it("parses AND expression", function()
      local ast = parse("sword AND shield")
      assert.same({
        type = "logical",
        operator = "AND",
        left = {type = "term", value = "sword"},
        right = {type = "term", value = "shield"},
      }, ast)
    end)

    it("parses OR expression", function()
      local ast = parse("sword OR shield")
      assert.same({
        type = "logical",
        operator = "OR",
        left = {type = "term", value = "sword"},
        right = {type = "term", value = "shield"},
      }, ast)
    end)

    it("parses NOT expression", function()
      local ast = parse("NOT sword")
      assert.same({
        type = "logical",
        operator = "NOT",
        expression = {type = "term", value = "sword"},
      }, ast)
    end)

    it("parses chained AND as left-associative", function()
      local ast = parse("a AND b AND c")
      assert.same({
        type = "logical",
        operator = "AND",
        left = {
          type = "logical",
          operator = "AND",
          left = {type = "term", value = "a"},
          right = {type = "term", value = "b"},
        },
        right = {type = "term", value = "c"},
      }, ast)
    end)

    it("parses mixed AND/OR left-to-right (no precedence)", function()
      local ast = parse("a AND b OR c")
      assert.same({
        type = "logical",
        operator = "OR",
        left = {
          type = "logical",
          operator = "AND",
          left = {type = "term", value = "a"},
          right = {type = "term", value = "b"},
        },
        right = {type = "term", value = "c"},
      }, ast)
    end)

    it("parses parenthesized expressions for grouping", function()
      local ast = parse("a AND (b OR c)")
      assert.same({
        type = "logical",
        operator = "AND",
        left = {type = "term", value = "a"},
        right = {
          type = "logical",
          operator = "OR",
          left = {type = "term", value = "b"},
          right = {type = "term", value = "c"},
        },
      }, ast)
    end)

    it("parses NOT with a comparison", function()
      local ast = parse("NOT quality = junk")
      assert.same({
        type = "logical",
        operator = "NOT",
        expression = {
          type = "comparison",
          field = "quality",
          operator = "=",
          value = "junk",
        },
      }, ast)
    end)

    it("parses NOT with parenthesized group", function()
      local ast = parse("NOT (a OR b)")
      assert.same({
        type = "logical",
        operator = "NOT",
        expression = {
          type = "logical",
          operator = "OR",
          left = {type = "term", value = "a"},
          right = {type = "term", value = "b"},
        },
      }, ast)
    end)

    it("parses a complex nested expression", function()
      local ast = parse("quality >= 4 AND (name %= sword OR name %= shield)")
      assert.same({
        type = "logical",
        operator = "AND",
        left = {
          type = "comparison",
          field = "quality",
          operator = ">=",
          value = "4",
        },
        right = {
          type = "logical",
          operator = "OR",
          left = {
            type = "comparison",
            field = "name",
            operator = "%=",
            value = "sword",
          },
          right = {
            type = "comparison",
            field = "name",
            operator = "%=",
            value = "shield",
          },
        },
      }, ast)
    end)
  end)

  -- ─── Query (integration) ───────────────────────────────────────────────────

  describe("Query", function()

    it("returns an AST for a valid simple query", function()
      local ast = QueryParser:Query("sword")
      assert.is_not_nil(ast)
      assert.same({type = "term", value = "sword"}, ast)
    end)

    it("returns an AST for a valid complex query", function()
      local ast = QueryParser:Query("quality >= 4 AND name %= sword")
      assert.is_not_nil(ast)
      assert.are.equal("logical", ast.type)
      assert.are.equal("AND", ast.operator)
    end)

    it("returns nil for malformed input (missing value after operator)", function()
      local ast = QueryParser:Query("quality =")
      assert.is_nil(ast)
    end)

    it("returns nil for unexpected tokens", function()
      -- A lone closing paren with nothing before it
      local ast = QueryParser:Query(")")
      assert.is_nil(ast)
    end)

    it("handles quoted strings in queries", function()
      local ast = QueryParser:Query('"Thunderfury, Blessed Blade of the Windseeker"')
      assert.is_not_nil(ast)
      assert.same({
        type = "term",
        value = "Thunderfury, Blessed Blade of the Windseeker",
      }, ast)
    end)

    it("handles single-word queries", function()
      local ast = QueryParser:Query("potion")
      assert.is_not_nil(ast)
      assert.are.equal("term", ast.type)
      assert.are.equal("potion", ast.value)
    end)

    it("handles NOT queries", function()
      local ast = QueryParser:Query("NOT junk")
      assert.is_not_nil(ast)
      assert.are.equal("logical", ast.type)
      assert.are.equal("NOT", ast.operator)
      assert.same({type = "term", value = "junk"}, ast.expression)
    end)
  end)
end)
