-- flamegraph_spec.lua -- The offline flame graph exporter (tools/flamegraph/flamegraph.lua).

local tool = assert(loadfile("tools/flamegraph/flamegraph.lua"))("flamegraph-module")

local SAVED_VARIABLES = [[
BetterBagsDB = {
  ["profileKeys"] = {},
}
BetterBagsPerfDB = {
  ["version"] = 1,
  ["nextId"] = 3,
  ["settings"] = {},
  ["sessions"] = {
    {
      ["id"] = 1,
      ["formatVersion"] = 1,
      ["meta"] = { ["character"] = "Old", ["realm"] = "R", ["startedAt"] = 1700000000, ["reason"] = "manual" },
      ["stats"] = { ["durationMs"] = 1000, ["instrumentedMs"] = 1, ["frames"] = 60 },
      ["names"] = { "[all]", "Items.Old" },
      ["nodes"] = { "0,1,0,0,0,0", "1,2,1000,1,1000,0" },
      ["functions"] = { "2,1,1000,1000" },
      ["worst"] = {},
      ["timeline"] = { ["ours"] = "" },
    },
    {
      ["id"] = 2,
      ["formatVersion"] = 1,
      ["meta"] = { ["character"] = "TestChar", ["realm"] = "TestRealm", ["startedAt"] = 1700000500, ["reason"] = "reload" },
      ["stats"] = { ["durationMs"] = 45200, ["instrumentedMs"] = 9.5, ["frames"] = 3 },
      ["names"] = { "[all]", "[event] BAG_UPDATE", "Items.RunRefresh", "Items.Harvest", "Bag.Draw" },
      ["nodes"] = {
        "0,1,0,0,0,0",
        "1,2,1000,3,500,0",
        "2,3,2000,1,9000,2048",
        "3,4,6000,1,6000,1024",
        "1,5,500,2,300,0",
      },
      ["functions"] = { "2,3,9000,3000", "3,1,8000,8000", "4,1,6000,6000", "5,2,500,300" },
      ["worst"] = {
        { ["frame"] = 7, ["atUs"] = 1500000, ["us"] = 7500, ["blizzardUs"] = 9000, ["nodes"] = { "3,1500,1,0", "4,4000,1,0" } },
      },
      ["timeline"] = { ["ours"] = "0,1500,7500" },
    },
  },
}
]]

local function tempDir()
  local path = os.tmpname()
  os.remove(path)
  assert(os.execute("mkdir -p '" .. path .. "'") == 0)
  return path
end

local function readFile(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

describe("flamegraph tool", function()
  local dir, svPath

  before_each(function()
    dir = tempDir()
    svPath = dir .. "/BetterBags.lua"
    local f = assert(io.open(svPath, "w"))
    f:write(SAVED_VARIABLES)
    f:close()
  end)

  after_each(function()
    os.execute("rm -rf '" .. dir .. "'")
  end)

  it("reads BetterBagsPerfDB out of a SavedVariables file without touching globals", function()
    local db = tool.LoadSavedVariables(svPath)
    assert.are.equal(2, #db.sessions)
    assert.is_nil(rawget(_G, "BetterBagsPerfDB"))
  end)

  it("finds the latest session, a session by id, or nothing", function()
    local db = tool.LoadSavedVariables(svPath)
    assert.are.equal(2, tool.FindSession(db, "latest").id)
    assert.are.equal(1, tool.FindSession(db, "1").id)
    assert.is_nil(tool.FindSession(db, "9"))
  end)

  it("lists sessions with their character and duration", function()
    local lines = tool.ListSessions(tool.LoadSavedVariables(svPath))
    assert.are.equal(2, #lines)
    assert.is_truthy(lines[1]:find("#2", 1, true))
    assert.is_truthy(lines[1]:find("TestChar", 1, true))
    assert.is_truthy(lines[1]:find("45.20 s", 1, true))
  end)

  it("renders folded stacks", function()
    local db = tool.LoadSavedVariables(svPath)
    local tree = tool.Tree(tool.FindSession(db, "2"), nil)
    assert.are.equal(table.concat({
      "[event] BAG_UPDATE 1000",
      "[event] BAG_UPDATE;Items.RunRefresh 2000",
      "[event] BAG_UPDATE;Items.RunRefresh;Items.Harvest 6000",
      "Bag.Draw 500",
    }, "\n") .. "\n", tool.Folded(tree, "time"))
  end)

  it("renders a speedscope sampled profile with stacks root first", function()
    local db = tool.LoadSavedVariables(svPath)
    local json = tool.Speedscope(tool.Tree(tool.FindSession(db, "2"), nil), "time", "BetterBags #2")
    assert.is_truthy(json:find('"$schema":"https://www.speedscope.app/file-format-schema.json"', 1, true))
    assert.is_truthy(json:find('"type":"sampled"', 1, true))
    assert.is_truthy(json:find('"unit":"microseconds"', 1, true))
    assert.is_truthy(json:find('"frames":[{"name":"[event] BAG_UPDATE"},{"name":"Items.RunRefresh"},{"name":"Items.Harvest"},{"name":"Bag.Draw"}]', 1, true))
    assert.is_truthy(json:find('"samples":[[0],[0,1],[0,1,2],[3]]', 1, true))
    assert.is_truthy(json:find('"weights":[1000,2000,6000,500]', 1, true))
    assert.is_truthy(json:find('"endValue":9500', 1, true))
  end)

  it("uses bytes for an allocation profile", function()
    local db = tool.LoadSavedVariables(svPath)
    local json = tool.Speedscope(tool.Tree(tool.FindSession(db, "2"), nil), "alloc", "x")
    assert.is_truthy(json:find('"unit":"bytes"', 1, true))
    assert.is_truthy(json:find('"weights":[2048,1024]', 1, true))
  end)

  it("renders a self-contained interactive HTML page", function()
    local db = tool.LoadSavedVariables(svPath)
    local session = tool.FindSession(db, "2")
    local html = tool.Html(tool.Tree(session, nil), "time", "BetterBags <#2>", { "Character: TestChar" })
    assert.is_truthy(html:find("<!DOCTYPE html>", 1, true))
    assert.is_truthy(html:find("BetterBags &lt;#2&gt;", 1, true))
    assert.is_truthy(html:find('"n":"Items.Harvest"', 1, true))
    assert.is_truthy(html:find("Character: TestChar", 1, true))
    assert.is_nil(html:find("<script src", 1, true))
    assert.is_nil(html:find("<link", 1, true))
  end)

  it("exports one worst frame on request", function()
    local db = tool.LoadSavedVariables(svPath)
    local tree = tool.Tree(tool.FindSession(db, "2"), 1)
    assert.are.equal(table.concat({
      "[event] BAG_UPDATE;Items.RunRefresh 1500",
      "[event] BAG_UPDATE;Items.RunRefresh;Items.Harvest 4000",
    }, "\n") .. "\n", tool.Folded(tree, "time"))
  end)

  it("writes folded, speedscope and HTML files", function()
    local printed = {}
    local code = tool.Main({ svPath, "--out", dir }, function(line) table.insert(printed, line) end)
    assert.are.equal(0, code)
    assert.is_truthy(readFile(dir .. "/betterbags-2.folded"):find("Bag.Draw 500", 1, true))
    assert.is_truthy(readFile(dir .. "/betterbags-2.speedscope.json"):find('"type":"sampled"', 1, true))
    assert.is_truthy(readFile(dir .. "/betterbags-2.html"):find("<!DOCTYPE html>", 1, true))
    assert.is_true(#printed >= 3)
  end)

  it("names frame and allocation exports apart", function()
    assert.are.equal(0, tool.Main({ svPath, "--out", dir, "--session", "2", "--frame", "1", "--metric", "alloc" }, function() end))
    assert.is_not_nil(io.open(dir .. "/betterbags-2-frame1-alloc.html", "r"))
  end)

  it("lists sessions and exits", function()
    local printed = {}
    assert.are.equal(0, tool.Main({ svPath, "--list" }, function(line) table.insert(printed, line) end))
    assert.are.equal(2, #printed)
  end)

  describe("profiler overhead", function()
    -- A (4 ms self, 2 calls) calls B (2 ms self, 4 calls); each measured call cost
    -- 0.125 ms on its caller and 0.25 ms on itself.
    local CALIBRATED = [[
BetterBagsPerfDB = {
  ["sessions"] = {
    {
      ["id"] = 3,
      ["meta"] = { ["character"] = "TestChar", ["realm"] = "TestRealm", ["startedAt"] = 1700000900 },
      ["stats"] = { ["durationMs"] = 1000, ["instrumentedMs"] = 6, ["overheadParentMs"] = 0.125, ["overheadChildMs"] = 0.25, ["overheadPerCallMs"] = 0.375 },
      ["names"] = { "[all]", "A", "B" },
      ["nodes"] = { "0,1,0,0,0,0", "1,2,4000,2,3000,0", "2,3,2000,4,600,0" },
      ["functions"] = { "2,2,6000,3000", "3,4,2000,600" },
      ["worst"] = {},
      ["timeline"] = { ["ours"] = "" },
    },
  },
}
]]
    local calibratedPath

    before_each(function()
      calibratedPath = dir .. "/Calibrated.lua"
      local f = assert(io.open(calibratedPath, "w"))
      f:write(CALIBRATED)
      f:close()
    end)

    it("subtracts the calibrated profiler overhead by default", function()
      assert.are.equal(0, tool.Main({ calibratedPath, "--out", dir }, function() end))
      assert.are.equal("A 3000\nA;B 1000\n", readFile(dir .. "/betterbags-3.folded"))
      assert.is_truthy(readFile(dir .. "/betterbags-3.speedscope.json"):find('"weights":[3000,1000]', 1, true))
      assert.is_truthy(readFile(dir .. "/betterbags-3.html"):find("without profiler overhead", 1, true))
    end)

    it("keeps the measured times with --raw", function()
      assert.are.equal(0, tool.Main({ calibratedPath, "--out", dir, "--raw" }, function() end))
      assert.are.equal("A 4000\nA;B 2000\n", readFile(dir .. "/betterbags-3-raw.folded"))
    end)

    it("leaves sessions without a calibration raw", function()
      assert.are.equal(0, tool.Main({ svPath, "--out", dir, "--session", "2" }, function() end))
      assert.is_truthy(readFile(dir .. "/betterbags-2.folded"):find("Bag.Draw 500", 1, true))
    end)
  end)

  it("numbers worst frames the way the Performance tab lists them", function()
    local lagged = dir .. "/Lagged.lua"
    local f = assert(io.open(lagged, "w"))
    f:write([[
BetterBagsPerfDB = {
  ["sessions"] = {
    {
      ["id"] = 5,
      ["formatVersion"] = 1,
      ["meta"] = {},
      ["stats"] = {},
      ["options"] = { ["spikeThresholdMs"] = 16 },
      ["names"] = { "[all]", "Bag.Draw" },
      ["nodes"] = { "0,1,0,0,0,0", "1,2,39430,1,39430,0" },
      ["functions"] = { "2,1,39430,39430" },
      ["worst"] = {
        { ["frame"] = 3, ["atUs"] = 60000, ["us"] = 30, ["blizzardUs"] = 40960, ["nodes"] = {} },
        { ["frame"] = 2, ["atUs"] = 40000, ["us"] = 39430, ["blizzardUs"] = 11990, ["nodes"] = { "2,39430,1,0" } },
      },
      ["timeline"] = { ["ours"] = "0,12450,39430,30,0", ["blizzard"] = "20,680,11990,40960,60" },
    },
  },
}
]])
    f:close()
    assert.are.equal(0, tool.Main({ lagged, "--out", dir, "--frame", "1", "--raw" }, function() end))
    assert.are.equal("Bag.Draw 39430\n", readFile(dir .. "/betterbags-5-frame1-raw.folded"))
    local printed = {}
    assert.are.equal(1, tool.Main({ lagged, "--out", dir, "--frame", "2" }, function(line) table.insert(printed, line) end))
    assert.is_truthy(printed[1]:find("kept 1", 1, true))
  end)

  it("fails with a message for a missing session, frame, or file", function()
    local printed = {}
    local out = function(line) table.insert(printed, line) end
    assert.are.equal(1, tool.Main({ svPath, "--session", "9" }, out))
    assert.are.equal(1, tool.Main({ svPath, "--frame", "5" }, out))
    assert.are.equal(1, tool.Main({ dir .. "/missing.lua" }, out))
    assert.are.equal(1, tool.Main({}, out))
    assert.is_true(#printed >= 4)
  end)
end)
