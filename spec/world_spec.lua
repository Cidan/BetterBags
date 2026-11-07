-- world_spec.lua -- every spec file starts from a world of its own (spec/setup.lua, spec/helpers/world.lua): the
-- mocks, the libraries and the addon, built again when the file starts, and let go with the file's tests when it ends
-- (.claude/rules/test-harness.md §6). Run on two fixture spec files in a busted of their own.

-- The fixtures are named *_world.lua, so the suite itself never runs them.
local FIXTURES = "spec/fixtures/world"

local function quote(word)
  return "'" .. (tostring(word):gsub("'", "'\\''")) .. "'"
end

-- runBusted runs busted as this run was started (the interpreter, its options and the busted script, arg[-n] to
-- arg[0]), with args, from the repository root; it returns the output and the exit status. Not a vararg function:
-- Lua 5.1 gives one a local named arg, which hides the global.
---@param args string[]
---@return string output
---@return number status
local function runBusted(args)
  local first = 0
  while arg[first - 1] ~= nil do first = first - 1 end
  local words = {}
  for i = first, 0 do table.insert(words, quote(arg[i])) end
  for _, word in ipairs(args) do table.insert(words, quote(word)) end
  local pipe = assert(io.popen(table.concat(words, " ") .. " 2>&1; echo \"status $?\""))
  local output = pipe:read("*a")
  pipe:close()
  local status = tonumber(output:match("status (%d+)%s*$"))
  return output, status
end

describe("A world of its own for every spec file", function()
  it("starts the next file from a fresh world and lets the last file's world be collected", function()
    local output, status = runBusted({ "--output=TAP", "--pattern=_world", FIXTURES })
    assert.are.equal(0, status, output)
    local passed = 0
    for _ in ("\n" .. output):gmatch("\nok %d+") do passed = passed + 1 end
    assert.are.equal(5, passed, output)
  end)

  it("still lists every file's tests, which busted -l runs without its file events", function()
    local output, status = runBusted({ "--list", "--pattern=_world", FIXTURES })
    assert.are.equal(0, status, output)
    assert.is_truthy(output:find("a spec file leaves a stub module, a frame and a mark on a mocked API behind", 1, true), output)
    assert.is_truthy(output:find("the spec file after it lets the first file's world be collected", 1, true), output)
  end)
end)
