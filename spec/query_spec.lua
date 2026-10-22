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

    it("parses mixed AND then OR as (a AND b) OR c", function()
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

    -- Asked (docs/vendor-compat.md, "Decisions"): AND binds tighter than OR, as in Lua. Queries used
    -- to group left to right, so `a OR b AND c` read as `(a OR b) AND c`.
    it("binds AND tighter than OR, as Lua does", function()
      local function shape(n)
        if n.type == "term" then return n.value end
        if n.type == "comparison" then return n.field .. n.operator .. n.value end
        if n.operator == "NOT" then return "NOT " .. shape(n.expression) end
        return "(" .. shape(n.left) .. " " .. n.operator .. " " .. shape(n.right) .. ")"
      end
      assert.are.equal("(a OR (b AND c))", shape(parse("a OR b AND c")))
      assert.are.equal("((a OR (b AND c)) OR d)", shape(parse("a OR b AND c OR d")))
      assert.are.equal("((a AND b) OR (c AND d))", shape(parse("a AND b OR c AND d")))
      assert.are.equal("(NOT a OR (b AND c))", shape(parse("NOT a OR b AND c")))
      assert.are.equal("(a OR (NOT b AND c))", shape(parse("a OR NOT b AND c")))
      assert.are.equal("((a OR b) OR c)", shape(parse("a OR b OR c")), "OR still groups left to right")
      assert.are.equal("((a OR b) AND c)", shape(parse("(a OR b) AND c")))
      assert.are.equal("(ilvl>5 OR (rarity=4 AND name=x))", shape(parse("ilvl > 5 or rarity = 4 and name = x")))
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

  -- ─── Rewriting rules written before AND bound tighter than OR ─────────────────

  describe("GroupLeftToRight", function()
    -- The parser as it was before AND bound tighter than OR: AND and OR at one precedence, grouped
    -- left to right; a term, `field op value`, `NOT term` or a parenthesized group, the closing
    -- parenthesis optional; whatever follows the first expression ignored.
    local function oldParse(tokens)
      local i = 1
      local function peek() return tokens[i] end
      local expression
      local function term()
        local t = peek()
        if t and t.type == "paren" and t.value == "(" then
          i = i + 1
          local e = expression()
          if peek() and peek().type == "paren" and peek().value == ")" then i = i + 1 end
          return e
        elseif t and t.type == "logical" and t.value == "NOT" then
          i = i + 1
          return { type = "logical", operator = "NOT", expression = term() }
        elseif t and t.type == "term" then
          i = i + 1
          if peek() and peek().type == "operator" then
            local op = peek().value
            i = i + 1
            local v = assert(peek() and peek().type == "term" and peek(), "value")
            i = i + 1
            return { type = "comparison", field = t.value, operator = op, value = v.value }
          end
          return { type = "term", value = t.value }
        end
        error("unexpected")
      end
      expression = function()
        local left = term()
        while peek() and peek().type == "logical" do
          local op = peek().value
          assert(op ~= "NOT", "binary NOT")
          i = i + 1
          left = { type = "logical", operator = op, left = left, right = term() }
        end
        return left
      end
      return expression()
    end

    local function shape(n)
      if n == nil then return "nil" end
      if n.type == "term" then return n.value end
      if n.type == "comparison" then return n.field .. n.operator .. n.value end
      if n.operator == "NOT" then return "NOT " .. shape(n.expression) end
      return "(" .. shape(n.left) .. " " .. n.operator .. " " .. shape(n.right) .. ")"
    end

    local function oldShape(text)
      local ok, ast = pcall(function() return oldParse(QueryParser:Lexer(text)) end)
      return ok and shape(ast) or "invalid"
    end

    it("adds parentheses so a rule keeps the meaning it had", function()
      assert.are.equal("(a OR b) AND c", QueryParser:GroupLeftToRight("a OR b AND c"))
      assert.are.equal("((a OR b) AND c OR d) AND e", QueryParser:GroupLeftToRight("a OR b AND c OR d AND e"))
      assert.are.equal("(a AND b OR c) AND d", QueryParser:GroupLeftToRight("a AND b OR c AND d"))
      assert.are.equal("(a OR b) AND c AND d", QueryParser:GroupLeftToRight("a OR b AND c AND d"), "no more than needed")
      assert.are.equal("x AND ((a OR b) AND c)", QueryParser:GroupLeftToRight("x AND (a OR b AND c)"))
      assert.are.equal("(NOT a or b) and c", QueryParser:GroupLeftToRight("NOT a or b and c"))
      assert.are.equal('(type = armor OR name = "Large Sack") AND ilvl > 200',
        QueryParser:GroupLeftToRight('type = armor OR name = "Large Sack" AND ilvl > 200'), "quotes kept")
      assert.are.equal("(tradeskill OR (a OR b)) AND exp = tww",
        QueryParser:GroupLeftToRight("tradeskill OR (a OR b) AND exp = tww"))
    end)

    it("leaves a rule that does not mix them, or that does not parse, as it is", function()
      for _, q in ipairs({ "a AND b OR c", "a OR b OR c", "a AND b AND c", "(a OR b) AND c", "rarity = epic",
        "exp = mid and not \"housing decor\"", "ilvl < 220 and (armor or weapon)", "", "AND a", "a = ", "a NOT b" }) do
        assert.are.equal(q, QueryParser:GroupLeftToRight(q), q)
      end
    end)

    -- The lexer rejects a control character; a saved rule holding one must not stop the load.
    it("leaves a rule the lexer cannot read as it is, without failing", function()
      local odd = "a OR b\001 AND c"
      assert.are.equal(odd, QueryParser:GroupLeftToRight(odd))
      assert.are.equal("a OR AND b", QueryParser:GroupLeftToRight("a OR AND b"))
    end)

    it("keeps what an unclosed parenthesis or a stray one meant", function()
      assert.are.equal(oldShape("(a OR b AND c"), shape(QueryParser:Query(QueryParser:GroupLeftToRight("(a OR b AND c"))))
      assert.are.equal(oldShape("a OR b) AND c"), shape(QueryParser:Query(QueryParser:GroupLeftToRight("a OR b) AND c"))))
    end)

    -- A thousand random rules, each read as the old parser read it and as the current one reads its
    -- rewrite: the two must be the same expression.
    it("gives every rule the meaning it had, over random rules", function()
      local seed = 1177
      local function random(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed % n + 1
      end
      local atoms = { "a", "b", "c", "ilvl > 5", 'name = "x y"', "rarity = epic", "tradeskill" }
      local ops = { "AND", "OR", "and", "or" }
      local function expr(depth)
        local parts = {}
        for n = 1, random(4) do
          if n > 1 then table.insert(parts, ops[random(#ops)]) end
          local item = atoms[random(#atoms)]
          if depth < 3 and random(4) == 1 then item = "(" .. expr(depth + 1) .. ")" end
          if random(5) == 1 then item = "NOT " .. item end
          table.insert(parts, item)
        end
        return table.concat(parts, " ")
      end
      for _ = 1, 1000 do
        local q = expr(1)
        local rewritten = QueryParser:GroupLeftToRight(q)
        assert.are.equal(oldShape(q), shape(QueryParser:Query(rewritten)), q .. " -> " .. rewritten)
        assert.are.equal(rewritten, QueryParser:GroupLeftToRight(rewritten), "a rewrite needs no other")
      end
    end)
  end)

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

    -- NOT only ever comes before what it negates. After a term it used to make a NOT node with two
    -- sides and nothing to negate, which the search evaluated to nothing, or failed on.
    it("returns nil for a NOT right after a term", function()
      assert.is_nil(QueryParser:Query("alpha NOT beta"))
      assert.is_nil(QueryParser:Query("alpha AND beta NOT gamma"))
      assert.is_not_nil(QueryParser:Query("alpha AND NOT beta"))
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
