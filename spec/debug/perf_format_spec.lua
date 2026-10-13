-- perf_format_spec.lua -- Decoding saved profiler sessions (debug/perf/format.lua).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("debug/perf/format.lua")

local perfFormat = addon:GetModule("PerfFormat")

local function sampleSession()
  return {
    formatVersion = 1,
    names = { "[all]", "[event] BAG_UPDATE", "Items.RunRefresh", "Items.Harvest", "Bag.Draw" },
    -- parent,name,self(us),calls,max(us),alloc(bytes)
    nodes = {
      "0,1,0,0,0,0",
      "1,2,1000,3,500,0",
      "2,3,2000,1,9000,2048",
      "3,4,6000,1,6000,1024",
      "1,5,500,2,300,0",
    },
    -- name,calls,incl(us),max(us)
    functions = {
      "2,3,9000,3000",
      "3,1,8000,8000",
      "4,1,6000,6000",
      "5,2,500,300",
    },
    histogram = { bounds = { 1, 5, 16, 33, 50, 100 }, counts = { 5, 1, 0, 0, 0, 1, 0 } },
    worst = {
      { frame = 7, atUs = 1500000, us = 7500, blizzardUs = 9000, nodes = { "3,1500,1,0", "4,4000,1,512" } },
    },
    timeline = { ours = "0,1500,7500", blizzard = "0,2000,9000" },
    stats = { instrumentedMs = 9.5 },
  }
end

describe("PerfFormat", function()
  -- How a capture started: a manual start, or one armed for the next load, which is a login
  -- or a reload once the game says which (debug/perf/sessions.lua).
  describe("capture reason", function()
    it("labels armed captures and leaves manual ones unlabeled", function()
      assert.equal("login", perfFormat:ReasonLabel("login"))
      assert.equal("reload", perfFormat:ReasonLabel("reload"))
      assert.equal("startup", perfFormat:ReasonLabel("startup"))
      assert.is_nil(perfFormat:ReasonLabel("manual"))
      assert.is_nil(perfFormat:ReasonLabel(nil))
    end)

    it("describes how a capture started", function()
      assert.equal("at login", perfFormat:ReasonPhrase("login"))
      assert.equal("from a reload", perfFormat:ReasonPhrase("reload"))
      assert.equal("at startup", perfFormat:ReasonPhrase("startup"))
      assert.equal("manually", perfFormat:ReasonPhrase("manual"))
      assert.equal("manually", perfFormat:ReasonPhrase(nil))
    end)
  end)

  describe("Decode", function()
    it("rebuilds the call tree with self and subtree totals in milliseconds", function()
      local tree = perfFormat:Decode(sampleSession())
      assert.are.equal("[all]", tree.root.name)
      assert.are.equal(9.5, tree.root.total)
      local event = perfFormat:Find(tree, { "[event] BAG_UPDATE" })
      assert.are.equal(1, event.self)
      assert.are.equal(9, event.total)
      assert.are.equal(3, event.calls)
      assert.are.equal(0.5, event.max)
      local run = perfFormat:Find(tree, { "[event] BAG_UPDATE", "Items.RunRefresh" })
      assert.are.equal(8, run.total)
      assert.are.equal(2, run.alloc)
      assert.are.equal(3, run.totalAlloc)
      assert.are.equal(event, run.parent)
      assert.is_true(tree.hasAlloc)
    end)

    it("returns nil for a path that does not exist", function()
      local tree = perfFormat:Decode(sampleSession())
      assert.is_nil(perfFormat:Find(tree, { "Nope" }))
      assert.is_nil(perfFormat:Find(tree, { "[event] BAG_UPDATE", "Bag.Draw" }))
    end)

    it("names the path from the top of the tree down to a node", function()
      local tree = perfFormat:Decode(sampleSession())
      local harvest = perfFormat:Find(tree, { "[event] BAG_UPDATE", "Items.RunRefresh", "Items.Harvest" })
      assert.are.same({ "[event] BAG_UPDATE", "Items.RunRefresh", "Items.Harvest" }, perfFormat:PathOf(harvest))
    end)
  end)

  describe("DecodeFunctions", function()
    it("derives per-function self time and allocations from the tree", function()
      local session = sampleSession()
      local fns = perfFormat:DecodeFunctions(session, perfFormat:Decode(session))
      local byName = {}
      for _, fn in ipairs(fns) do byName[fn.name] = fn end
      assert.are.equal(6, byName["Items.Harvest"].self)
      assert.are.equal(8, byName["Items.RunRefresh"].incl)
      assert.are.equal(2, byName["Items.RunRefresh"].self)
      assert.are.equal(2, byName["Items.RunRefresh"].alloc)
      assert.are.equal(3, byName["[event] BAG_UPDATE"].avg)
      assert.are.equal(0.3, byName["Bag.Draw"].max)
      -- Sorted by self time, largest first.
      assert.are.equal("Items.Harvest", fns[1].name)
    end)
  end)

  describe("DecodeFrame", function()
    it("rebuilds a worst frame's own call tree, including zero-cost ancestors", function()
      local frame = perfFormat:DecodeFrame(sampleSession(), 1)
      assert.are.equal(7.5, frame.ms)
      assert.are.equal(9, frame.blizzardMs)
      assert.are.equal(1500, frame.atMs)
      assert.are.equal(7, frame.frame)
      local event = perfFormat:Find(frame.tree, { "[event] BAG_UPDATE" })
      assert.are.equal(0, event.self)
      assert.are.equal(5.5, event.total)
      local harvest = perfFormat:Find(frame.tree, { "[event] BAG_UPDATE", "Items.RunRefresh", "Items.Harvest" })
      assert.are.equal(4, harvest.self)
      assert.are.equal(0.5, harvest.alloc)
      assert.is_nil(perfFormat:Find(frame.tree, { "Bag.Draw" }))
    end)
  end)

  describe("DecodeAborted", function()
    it("lists calls cut short by errors, most frequent first", function()
      local session = sampleSession()
      session.aborted = { "3,1", "5,4" }
      assert.are.same({
        { name = "Bag.Draw", count = 4 },
        { name = "Items.RunRefresh", count = 1 },
      }, perfFormat:DecodeAborted(session))
    end)

    it("returns an empty list for sessions without aborted calls", function()
      assert.are.same({}, perfFormat:DecodeAborted(sampleSession()))
    end)
  end)

  describe("DecodeTimeline", function()
    it("decodes both per-frame series in milliseconds", function()
      local timeline = perfFormat:DecodeTimeline(sampleSession())
      assert.are.same({ 0, 1.5, 7.5 }, timeline.ours)
      assert.are.same({ 0, 2, 9 }, timeline.blizzard)
    end)
  end)

  describe("Folded", function()
    it("emits collapsed stacks of self time in microseconds", function()
      local lines = perfFormat:Folded(perfFormat:Decode(sampleSession()), "time")
      assert.are.same({
        "[event] BAG_UPDATE 1000",
        "[event] BAG_UPDATE;Items.RunRefresh 2000",
        "[event] BAG_UPDATE;Items.RunRefresh;Items.Harvest 6000",
        "Bag.Draw 500",
      }, lines)
    end)

    it("emits collapsed stacks of allocated bytes", function()
      local lines = perfFormat:Folded(perfFormat:Decode(sampleSession()), "alloc")
      assert.are.same({
        "[event] BAG_UPDATE;Items.RunRefresh 2048",
        "[event] BAG_UPDATE;Items.RunRefresh;Items.Harvest 1024",
      }, lines)
    end)
  end)

  describe("Layout", function()
    it("lays children out left to right inside their parent", function()
      local tree = perfFormat:Decode(sampleSession())
      local rects = perfFormat:Layout(tree.root, { metric = "time", minFraction = 0 })
      local byName = {}
      for _, r in ipairs(rects) do byName[r.node.name] = r end
      assert.are.equal(5, #rects)
      assert.are.same({ 0, 0, 1 }, { byName["[all]"].depth, byName["[all]"].x, byName["[all]"].w })
      assert.are.equal(1, byName["[event] BAG_UPDATE"].depth)
      assert.are.equal(9 / 9.5, byName["[event] BAG_UPDATE"].w)
      assert.are.equal(3, byName["Items.Harvest"].depth)
      assert.are.equal(9 / 9.5, byName["Bag.Draw"].x)
      assert.are.equal(0.5 / 9.5, byName["Bag.Draw"].w)
    end)

    it("drops nodes narrower than the minimum fraction", function()
      local tree = perfFormat:Decode(sampleSession())
      local rects = perfFormat:Layout(tree.root, { metric = "time", minFraction = 0.06 })
      for _, r in ipairs(rects) do
        assert.are_not.equal("Bag.Draw", r.node.name)
      end
    end)

    it("zooms into a node, which then spans the full width", function()
      local tree = perfFormat:Decode(sampleSession())
      local event = perfFormat:Find(tree, { "[event] BAG_UPDATE" })
      local rects = perfFormat:Layout(event, { metric = "time", minFraction = 0 })
      assert.are.equal(3, #rects)
      assert.are.equal(1, rects[1].w)
      assert.are.equal(8 / 9, rects[2].w)
      assert.are.equal(1, rects[2].depth)
    end)

    it("lays out by allocations when asked", function()
      local tree = perfFormat:Decode(sampleSession())
      local rects = perfFormat:Layout(tree.root, { metric = "alloc", minFraction = 0 })
      local byName = {}
      for _, r in ipairs(rects) do byName[r.node.name] = r end
      assert.are.equal(1, byName["Items.RunRefresh"].w)
      assert.are.equal(1 / 3, byName["Items.Harvest"].w)
      assert.is_nil(byName["Bag.Draw"])
    end)
  end)

  describe("worst frames", function()
    -- Mirrors a real capture saved before Blizzard's readings were paired: a harvest
    -- (frame 1) and a redraw (frame 2), each reported by Blizzard one frame later. The
    -- engine ranked frame 3 as the worst frame on Blizzard's late reading alone.
    local function laggedV1Session()
      return {
        formatVersion = 1,
        options = { spikeThresholdMs = 16 },
        names = { "[all]", "Bag.Draw" },
        nodes = { "0,1,0,0,0,0", "1,2,39430,1,39430,0" },
        worst = {
          { frame = 3, atUs = 60000, us = 30, blizzardUs = 40960, nodes = {} },
          { frame = 2, atUs = 40000, us = 39430, blizzardUs = 11990, nodes = { "2,39430,1,0" } },
        },
        timeline = { ours = "0,12450,39430,30,0", blizzard = "20,680,11990,40960,60" },
      }
    end

    it("re-pairs an older session's Blizzard readings and drops frames listed only for a late reading", function()
      local session = laggedV1Session()
      local list = perfFormat:WorstFrames(session)
      assert.are.equal(1, #list)
      assert.are.equal(2, list[1].index)
      assert.are.equal(2, list[1].frame)
      assert.are.equal(39.43, list[1].ms)
      assert.are.equal(40.96, list[1].blizzardMs)
      assert.are.equal(40.96, perfFormat:DecodeFrame(session, 2).blizzardMs)
    end)

    it("keeps an older session's readings when its timeline does not cover the frame", function()
      local session = laggedV1Session()
      session.timeline = { ours = "0", blizzard = "0" }
      local list = perfFormat:WorstFrames(session)
      assert.are.equal(2, #list)
      assert.are.equal(40.96, list[1].blizzardMs)
      assert.are.equal(11.99, perfFormat:DecodeFrame(session, 2).blizzardMs)
    end)

    it("uses a paired session's stored readings and order as they are", function()
      local session = laggedV1Session()
      session.formatVersion = 2
      session.worst = { session.worst[2] }
      session.worst[1].blizzardUs = 40960
      local list = perfFormat:WorstFrames(session)
      assert.are.equal(1, #list)
      assert.are.equal(1, list[1].index)
      assert.are.equal(40.96, list[1].blizzardMs)
    end)

    it("keeps an older session's frames as captured when it has no Blizzard readings", function()
      local session = laggedV1Session()
      session.timeline = { ours = "0,12450,39430,30,0" }
      session.worst = { session.worst[2] }
      session.worst[1].blizzardUs = nil
      local list = perfFormat:WorstFrames(session)
      assert.are.equal(1, #list)
      assert.are.equal(39.43, list[1].ms)
      assert.is_nil(list[1].blizzardMs)
    end)
  end)

  describe("overhead adjustment", function()
    -- A (4 ms self, 2 calls) calls B (2 ms self, 4 calls); C (0.5 ms self, 4 calls) is a
    -- sibling of A. Each wrapped call costs 0.125 ms on its caller and 0.25 ms on itself.
    local function overheadSession()
      return {
        names = { "[all]", "A", "B", "C" },
        nodes = {
          "0,1,0,0,0,0",
          "1,2,4000,2,3000,0",
          "2,3,2000,4,600,0",
          "1,4,500,4,200,0",
        },
        functions = { "2,2,6000,3000", "3,4,2000,600", "4,4,500,200" },
        worst = {
          { frame = 1, atUs = 0, us = 6500, nodes = { "2,4000,2,0", "3,2000,4,0" } },
        },
        timeline = { ours = "6000,500", calls = "6,4", nested = "4,0" },
        stats = { overheadParentMs = 0.125, overheadChildMs = 0.25, overheadPerCallMs = 0.375 },
      }
    end

    it("reads the calibrated split, or splits an older single figure evenly", function()
      local split = perfFormat:Overhead(overheadSession())
      assert.are.same({ parentMs = 0.125, childMs = 0.25, approximate = false }, split)
      local old = overheadSession()
      old.stats = { overheadPerCallMs = 0.375 }
      assert.are.same({ parentMs = 0.1875, childMs = 0.1875, approximate = true }, perfFormat:Overhead(old))
      old.stats = { overheadPerCallMs = 0 }
      assert.is_nil(perfFormat:Overhead(old))
    end)

    it("removes each call's cost from its own node and from its caller", function()
      local session = overheadSession()
      local tree = perfFormat:Decode(session)
      perfFormat:Adjust(tree, perfFormat:Overhead(session))
      local a = perfFormat:Find(tree, { "A" })
      local b = perfFormat:Find(tree, { "A", "B" })
      local c = perfFormat:Find(tree, { "C" })
      assert.are.equal(3, a.adjSelf)
      assert.are.equal(1, b.adjSelf)
      assert.are.equal(4, a.adjTotal)
      assert.are.equal(4, tree.root.adjTotal)
      assert.is_true(tree.adjusted)
      -- Never below zero: C's measured time is less than its estimated overhead.
      assert.are.equal(0, c.adjSelf)
      assert.are.equal(1, c.overheadShare)
      assert.are.equal(1 / 3, a.overheadShare)
    end)

    it("lays out and folds adjusted time", function()
      local session = overheadSession()
      local tree = perfFormat:Decode(session)
      perfFormat:Adjust(tree, perfFormat:Overhead(session))
      local rects = perfFormat:Layout(tree.root, { metric = "adjusted", minFraction = 0 })
      local byName = {}
      for _, r in ipairs(rects) do byName[r.node.name] = r end
      assert.are.equal(1, byName["A"].w)
      assert.are.equal(0.25, byName["B"].w)
      assert.is_nil(byName["C"])
      assert.are.same({ "A 3000", "A;B 1000" }, perfFormat:Folded(tree, "adjusted"))
    end)

    it("adjusts per-function totals and flags functions that are mostly overhead", function()
      local session = overheadSession()
      local tree = perfFormat:Decode(session)
      perfFormat:Adjust(tree, perfFormat:Overhead(session))
      local byName = {}
      for _, fn in ipairs(perfFormat:DecodeFunctions(session, tree)) do byName[fn.name] = fn end
      assert.are.equal(4, byName["A"].adjIncl)
      assert.are.equal(3, byName["A"].adjSelf)
      assert.are.equal(2, byName["A"].adjAvg)
      assert.are.equal(1 / 3, byName["A"].overheadShare)
      assert.are.equal(0, byName["C"].adjIncl)
      assert.are.equal(1, byName["C"].overheadShare)
    end)

    it("adjusts a worst frame's tree and the per-frame timeline", function()
      local session = overheadSession()
      local overhead = perfFormat:Overhead(session)
      local frame = perfFormat:DecodeFrame(session, 1)
      perfFormat:Adjust(frame.tree, overhead)
      assert.are.equal(4, frame.tree.root.adjTotal)
      local timeline = perfFormat:DecodeTimeline(session)
      assert.are.same({ 6, 4 }, timeline.calls)
      assert.are.same({ 4, 0 }, timeline.nested)
      -- Frame 1 is the worst frame above: the timeline agrees with its adjusted tree.
      assert.are.same({ 4, 0 }, perfFormat:AdjustTimeline(timeline, overhead))
    end)
  end)

  describe("number formatting", function()
    it("formats milliseconds with precision that suits their size", function()
      assert.are.equal("0.004 ms", perfFormat:Ms(0.0042))
      assert.are.equal("0.42 ms", perfFormat:Ms(0.42))
      assert.are.equal("4.20 ms", perfFormat:Ms(4.2))
      assert.are.equal("42.0 ms", perfFormat:Ms(42))
      assert.are.equal("420 ms", perfFormat:Ms(420))
      assert.are.equal("4.20 s", perfFormat:Ms(4200))
    end)

    it("groups counts in thousands", function()
      assert.are.equal("7", perfFormat:Count(7))
      assert.are.equal("1,234", perfFormat:Count(1234))
      assert.are.equal("12,345,678", perfFormat:Count(12345678))
    end)

    it("formats kilobytes, switching to megabytes past 1024", function()
      assert.are.equal("0.5 KB", perfFormat:KB(0.5))
      assert.are.equal("512.0 KB", perfFormat:KB(512))
      assert.are.equal("2.0 MB", perfFormat:KB(2048))
    end)
  end)

  describe("standalone use", function()
    it("loads outside the addon and returns the same functions", function()
      local standalone = dofile("debug/perf/format.lua")
      local tree = standalone:Decode(sampleSession())
      assert.are.equal(9.5, tree.root.total)
    end)
  end)
end)
