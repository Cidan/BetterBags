-- perf_engine_spec.lua -- The instrumenting profiler engine (debug/perf/engine.lua).
-- A fake clock drives every test so timings are exact.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("debug/perf/format.lua")

local perf = addon:GetModule("Perf")
local perfFormat = addon:GetModule("PerfFormat")

local now = 0
local function advance(ms)
  now = now + ms
end

local function getOrNewModule(name)
  return addon:GetModule(name, true) or addon:NewModule(name)
end

local A = getOrNewModule("PerfSpecA")
local B = getOrNewModule("PerfSpecB")

local function options(overrides)
  local o = {
    modules = { "PerfSpecA", "PerfSpecB" },
    prototypes = {},
    includeRoot = false,
    calibrate = false,
    maxNodes = 5000,
    worstFrames = 10,
    spikeThresholdMs = 16,
    timelineFrames = 100,
  }
  for k, v in pairs(overrides or {}) do
    o[k] = v
  end
  return o
end

local function find(tree, path)
  return perfFormat:Find(tree, path)
end

local function functionStats(session, tree, name)
  for _, fn in ipairs(perfFormat:DecodeFunctions(session, tree)) do
    if fn.name == name then
      return fn
    end
  end
end

describe("Perf engine", function()
  before_each(function()
    now = 0
    perf:Init()
    perf:SetClock(function() return now end)
    for k in pairs(A) do
      if type(A[k]) == "function" and k:match("^T") then A[k] = nil end
    end
    for k in pairs(B) do
      if type(B[k]) == "function" and k:match("^T") then B[k] = nil end
    end
  end)

  after_each(function()
    if perf:IsActive() then
      perf:Stop()
    end
  end)

  describe("lifecycle", function()
    it("is inactive by default and refuses a second Start", function()
      assert.is_false(perf:IsActive())
      assert.is_nil(perf:Enter("[x]"))
      assert.is_true(perf:Start(options()))
      assert.is_true(perf:IsActive())
      assert.is_false(perf:Start(options()))
      assert.is_table(perf:Stop())
      assert.is_false(perf:IsActive())
      assert.is_nil(perf:Stop())
    end)

    it("restores the exact original functions on Stop", function()
      local original = function() return 1 end
      A.TOriginal = original
      perf:Start(options())
      assert.are_not.equal(original, A.TOriginal)
      perf:Stop()
      assert.are.equal(original, A.TOriginal)
    end)

    it("keeps a wrapper captured during a capture working as a pass-through after Stop", function()
      A.TCaptured = function(_, x) return x * 2 end
      perf:Start(options())
      local captured = A.TCaptured
      perf:Stop()
      assert.are.equal(14, captured(A, 7))
    end)

    it("does not clobber a method that was replaced during the capture", function()
      A.TReplaced = function() return "old" end
      perf:Start(options())
      local newer = function() return "new" end
      A.TReplaced = newer
      perf:Stop()
      assert.are.equal(newer, A.TReplaced)
    end)

    it("does not wrap AceAddon mixin functions shared by every module", function()
      local getModule = A.GetModule
      local enable = A.Enable
      perf:Start(options())
      assert.are.equal(getModule, A.GetModule)
      assert.are.equal(enable, A.Enable)
      perf:Stop()
    end)

    it("only wraps the modules it was asked to", function()
      local other = getOrNewModule("PerfSpecUntouched")
      local fn = function() end
      other.TFn = fn
      perf:Start(options())
      assert.are.equal(fn, other.TFn)
      perf:Stop()
    end)

    it("never wraps the profiler, its window, or Context, even when asked to", function()
      local created = {}
      local fns = {}
      for _, name in ipairs({ "DebugWindow", "Context", "PerfSessions", "PerfPane", "FlameGraph", "PerfFormat" }) do
        local mod, wasCreated = StubBetterBagsModule(name)
        if wasCreated then table.insert(created, name) end
        fns[name] = function() end
        mod.TNeverWrapped = fns[name]
      end
      perf:Start(options({ modules = { "DebugWindow", "Context", "Perf", "PerfSessions", "PerfPane", "FlameGraph", "PerfFormat" } }))
      for name, fn in pairs(fns) do
        assert.are.equal(fn, addon:GetModule(name).TNeverWrapped, name)
      end
      assert.are.equal(perf.Enter, addon:GetModule("Perf").Enter)
      perf:Stop()
      for name in pairs(fns) do
        addon:GetModule(name).TNeverWrapped = nil
      end
      for _, name in ipairs(created) do
        ResetModuleStub(name)
      end
    end)

    it("honors the exclude list", function()
      local fn = function() end
      B.TExcluded = fn
      perf:Start(options({ exclude = { "PerfSpecB" } }))
      assert.are.equal(fn, B.TExcluded)
      perf:Stop()
    end)
  end)

  describe("call tree", function()
    it("attributes self and total time through nested methods", function()
      function A:TOuter()
        advance(1)
        self:TInner()
        advance(2)
      end
      function A:TInner()
        advance(5)
      end
      perf:Start(options())
      A:TOuter()
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)
      local outer = find(tree, { "PerfSpecA.TOuter" })
      local inner = find(tree, { "PerfSpecA.TOuter", "PerfSpecA.TInner" })
      assert.are.equal(3, outer.self)
      assert.are.equal(8, outer.total)
      assert.are.equal(5, inner.self)
      assert.are.equal(1, outer.calls)
      assert.are.equal(1, inner.calls)
      assert.are.equal(8, session.stats.instrumentedMs)
    end)

    it("preserves every return value, including nils and the value count", function()
      function A:TReturns()
        return nil, 2, nil
      end
      perf:Start(options())
      local count = select("#", A:TReturns())
      local a, b, c = A:TReturns()
      perf:Stop()
      assert.are.equal(3, count)
      assert.is_nil(a)
      assert.are.equal(2, b)
      assert.is_nil(c)
    end)

    it("passes every argument through, including trailing nils", function()
      local seen
      function A:TArgs(...)
        seen = select("#", ...)
      end
      perf:Start(options())
      A:TArgs(1, nil, nil)
      perf:Stop()
      assert.are.equal(3, seen)
    end)

    it("counts recursive inclusive time only once per outermost call", function()
      function A:TRecurse(n)
        advance(1)
        if n > 1 then self:TRecurse(n - 1) end
      end
      perf:Start(options())
      A:TRecurse(3)
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)
      local fn = functionStats(session, tree, "PerfSpecA.TRecurse")
      assert.are.equal(3, fn.calls)
      assert.are.equal(3, fn.incl)
      assert.are.equal(3, fn.self)
      assert.are.equal(3, fn.max)
    end)

    it("does not count idle time between top-level calls", function()
      function A:TWork()
        advance(4)
      end
      perf:Start(options())
      A:TWork()
      advance(1000)
      A:TWork()
      local session = perf:Stop()
      assert.are.equal(8, session.stats.instrumentedMs)
      local tree = perfFormat:Decode(session)
      assert.are.equal(2, find(tree, { "PerfSpecA.TWork" }).calls)
    end)

    it("records the worst single call per node", function()
      local cost = { 2, 9, 3 }
      local i = 0
      function A:TVaries()
        i = i + 1
        advance(cost[i])
      end
      perf:Start(options())
      A:TVaries()
      A:TVaries()
      A:TVaries()
      local tree = perfFormat:Decode(perf:Stop())
      assert.are.equal(9, find(tree, { "PerfSpecA.TVaries" }).max)
    end)

    it("supports manual spans and wrapped local functions", function()
      local localFn = perf:Wrap("[local] helper", function() advance(3) end)
      function A:TSpans()
        local token = perf:Enter("[span] work")
        advance(2)
        localFn()
        perf:Exit(token)
      end
      perf:Start(options())
      A:TSpans()
      local tree = perfFormat:Decode(perf:Stop())
      local span = find(tree, { "PerfSpecA.TSpans", "[span] work" })
      assert.are.equal(2, span.self)
      assert.are.equal(3, find(tree, { "PerfSpecA.TSpans", "[span] work", "[local] helper" }).self)
    end)

    it("wraps registered prototypes so every instance is measured", function()
      local proto = {}
      function proto:TDraw() advance(6) end
      perf:RegisterPrototype(proto, "PerfSpecProto")
      local instance = setmetatable({}, { __index = proto })
      perf:Start(options({ prototypes = { "PerfSpecProto" } }))
      instance:TDraw()
      local tree = perfFormat:Decode(perf:Stop())
      assert.are.equal(6, find(tree, { "PerfSpecProto.TDraw" }).self)
    end)

    it("never wraps a table that is a WoW frame", function()
      local frameLike = { [0] = newproxy() }
      local fn = function() end
      frameLike.TFn = fn
      perf:RegisterPrototype(frameLike, "PerfSpecFrame")
      perf:Start(options({ prototypes = { "PerfSpecFrame" } }))
      assert.are.equal(fn, frameLike.TFn)
      perf:Stop()
    end)

    it("folds new paths into a single overflow node past the node limit", function()
      function A:TLeaf1() advance(1) end
      function A:TLeaf2() advance(1) end
      function A:TLeaf3() advance(1) end
      perf:Start(options({ maxNodes = 3 }))
      A:TLeaf1()
      A:TLeaf2()
      A:TLeaf3()
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)
      assert.is_true(session.stats.droppedNodes > 0)
      assert.is_not_nil(find(tree, { "[node limit reached]" }))
      assert.are.equal(3, session.stats.instrumentedMs)
    end)
  end)

  describe("errors", function()
    it("repairs frames leaked by an uncaught error at the next frame boundary", function()
      function A:TThrows()
        advance(1)
        B:TBoom()
      end
      function B:TBoom()
        advance(1)
        error("boom")
      end
      function A:TAfter()
        advance(2)
      end
      perf:Start(options())
      assert.has_error(function() A:TThrows() end)
      perf:_OnFrame()
      A:TAfter()
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)
      assert.are.equal(2, session.stats.aborted)
      local aborted = {}
      for _, entry in ipairs(perfFormat:DecodeAborted(session)) do aborted[entry.name] = entry.count end
      assert.are.same({ ["PerfSpecA.TThrows"] = 1, ["PerfSpecB.TBoom"] = 1 }, aborted)
      assert.are.equal(2, find(tree, { "PerfSpecA.TAfter" }).self)
      assert.is_nil(find(tree, { "PerfSpecA.TThrows", "PerfSpecB.TBoom", "PerfSpecA.TAfter" }))
    end)

    it("repairs frames leaked inside a pcall when the enclosing call returns", function()
      function B:TFails()
        error("nope")
      end
      function A:TCatches()
        pcall(function() B:TFails() end)
        advance(1)
      end
      perf:Start(options())
      A:TCatches()
      local session = perf:Stop()
      assert.are.equal(1, session.stats.aborted)
      assert.are.same({ { name = "PerfSpecB.TFails", count = 1 } }, perfFormat:DecodeAborted(session))
      local tree = perfFormat:Decode(session)
      assert.are.equal(1, find(tree, { "PerfSpecA.TCatches" }).calls)
    end)
  end)

  describe("coroutines", function()
    it("pauses a yielded coroutine and re-attaches it under whatever resumes it", function()
      function A:THarvest() advance(10) end
      function A:TCommit() advance(20) end
      function A:TSweep()
        self:THarvest()
        perf:BeforeYield()
        coroutine.yield()
        perf:AfterResume()
        self:TCommit()
      end
      local co = coroutine.create(function() A:TSweep() end)
      function B:TResumeFirst()
        advance(1)
        coroutine.resume(co)
      end
      function B:TResumeSecond()
        advance(1)
        coroutine.resume(co)
      end
      perf:Start(options())
      B:TResumeFirst()
      advance(5000)
      B:TResumeSecond()
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)

      local first = find(tree, { "PerfSpecB.TResumeFirst" })
      local second = find(tree, { "PerfSpecB.TResumeSecond" })
      assert.are.equal(1, first.self)
      assert.are.equal(1, second.self)
      assert.are.equal(10, find(tree, { "PerfSpecB.TResumeFirst", "PerfSpecA.TSweep", "PerfSpecA.THarvest" }).self)
      assert.are.equal(20, find(tree, { "PerfSpecB.TResumeSecond", "PerfSpecA.TSweep", "PerfSpecA.TCommit" }).self)
      -- The second slice is a continuation, not a new call.
      assert.are.equal(1, find(tree, { "PerfSpecB.TResumeFirst", "PerfSpecA.TSweep" }).calls)
      assert.are.equal(0, find(tree, { "PerfSpecB.TResumeSecond", "PerfSpecA.TSweep" }).calls)
      -- The 5 second gap between frames is never counted.
      assert.are.equal(32, session.stats.instrumentedMs)
      local sweep = functionStats(session, tree, "PerfSpecA.TSweep")
      assert.are.equal(30, sweep.incl)
    end)

    it("hands time back to the resumer when a coroutine finishes without yielding", function()
      function A:TBody() advance(7) end
      function B:TRunner()
        local co = coroutine.create(function() A:TBody() end)
        coroutine.resume(co)
        advance(2)
      end
      perf:Start(options())
      B:TRunner()
      local tree = perfFormat:Decode(perf:Stop())
      assert.are.equal(2, find(tree, { "PerfSpecB.TRunner" }).self)
      assert.are.equal(7, find(tree, { "PerfSpecB.TRunner", "PerfSpecA.TBody" }).self)
    end)

    it("recovers when a coroutine dies with an error", function()
      function A:TDies() advance(1); error("dead") end
      function B:TResumesDead()
        local co = coroutine.create(function() A:TDies() end)
        coroutine.resume(co)
        advance(3)
      end
      function B:TLater() advance(4) end
      perf:Start(options())
      B:TResumesDead()
      B:TLater()
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)
      -- Nothing is observable between the error and the resumer's next measured call, so
      -- that gap lands on the dead coroutine's last frame; the totals stay exact.
      local resumer = find(tree, { "PerfSpecB.TResumesDead" })
      assert.are.equal(4, resumer.total)
      assert.are.equal(4, find(tree, { "PerfSpecB.TLater" }).self)
      assert.is_nil(find(tree, { "PerfSpecB.TResumesDead", "PerfSpecA.TDies", "PerfSpecB.TLater" }))
      assert.are.equal(8, session.stats.instrumentedMs)
    end)
  end)

  describe("frames", function()
    it("buckets per-frame time, keeps the worst frames, and records their call trees", function()
      function A:TCheap() advance(2) end
      function A:TExpensive() advance(40); B:TNested() end
      function B:TNested() advance(10) end
      perf:Start(options({ worstFrames = 2, spikeThresholdMs = 16 }))
      A:TCheap()
      perf:_OnFrame()
      A:TExpensive()
      perf:_OnFrame()
      perf:_OnFrame()
      local session = perf:Stop()

      assert.are.equal(3, session.stats.frames)
      assert.are.equal(2, session.stats.activeFrames)
      -- Buckets: <1, 1-5, 5-16, 16-33, 33-50, 50-100, >=100
      assert.are.same({ 1, 5, 16, 33, 50, 100 }, session.histogram.bounds)
      assert.are.same({ 1, 1, 0, 0, 0, 1, 0 }, session.histogram.counts)

      assert.are.equal(1, #session.worst)
      local frame = perfFormat:DecodeFrame(session, 1)
      assert.are.equal(50, frame.ms)
      assert.are.equal(40, perfFormat:Find(frame.tree, { "PerfSpecA.TExpensive" }).self)
      assert.are.equal(10, perfFormat:Find(frame.tree, { "PerfSpecA.TExpensive", "PerfSpecB.TNested" }).self)
    end)

    it("keeps only the N worst frames, worst first", function()
      function A:TCost(ms) advance(ms) end
      perf:Start(options({ worstFrames = 2, spikeThresholdMs = 1 }))
      for _, ms in ipairs({ 20, 50, 30, 10 }) do
        A:TCost(ms)
        perf:_OnFrame()
      end
      local session = perf:Stop()
      assert.are.equal(2, #session.worst)
      assert.are.equal(50, perfFormat:DecodeFrame(session, 1).ms)
      assert.are.equal(30, perfFormat:DecodeFrame(session, 2).ms)
    end)

    it("includes ancestors that only carried time in earlier frames", function()
      function A:TPhase() advance(30) end
      function A:TLongSweep()
        advance(1)
        perf:BeforeYield()
        coroutine.yield()
        perf:AfterResume()
        self:TPhase()
      end
      local co = coroutine.create(function() A:TLongSweep() end)
      function B:TStep() coroutine.resume(co) end
      perf:Start(options({ spikeThresholdMs = 16 }))
      B:TStep()
      perf:_OnFrame()
      B:TStep()
      perf:_OnFrame()
      local session = perf:Stop()
      local frame = perfFormat:DecodeFrame(session, 1)
      local phase = perfFormat:Find(frame.tree, { "PerfSpecB.TStep", "PerfSpecA.TLongSweep", "PerfSpecA.TPhase" })
      assert.are.equal(30, phase.self)
    end)

    it("records a per-frame timeline, capped at timelineFrames", function()
      function A:TTick(ms) advance(ms) end
      perf:Start(options({ timelineFrames = 2 }))
      A:TTick(3)
      perf:_OnFrame()
      perf:_OnFrame()
      A:TTick(5)
      perf:_OnFrame()
      local session = perf:Stop()
      local timeline = perfFormat:DecodeTimeline(session)
      assert.are.same({ 3, 0 }, timeline.ours)
      assert.are.same({ 1, 0 }, timeline.calls)
      assert.are.same({ 0, 0 }, timeline.nested)
      assert.is_nil(timeline.blizzard)
    end)

    -- A top-level call's caller-side profiler cost lands on the root, which is never
    -- measured, so only calls made from inside a measured call carry it.
    it("counts per frame the calls made from inside another measured call", function()
      function A:TOuter()
        B:TInner()
        B:TInner()
      end
      function B:TInner() end
      perf:Start(options())
      A:TOuter()
      B:TInner()
      perf:_OnFrame()
      local timeline = perfFormat:DecodeTimeline(perf:Stop())
      assert.are.same({ 4 }, timeline.calls)
      assert.are.same({ 2 }, timeline.nested)
    end)

    it("samples an external per-frame metric and flags spikes it reports", function()
      perf:Start(options({ frameMetric = function() return 80 end, spikeThresholdMs = 50 }))
      perf:_OnFrame()
      local session = perf:Stop()
      assert.are.same({ 0, 0, 0, 0, 0, 1, 0 }, session.histogram.blizzard)
      assert.are.equal(1, #session.worst)
      local frame = perfFormat:DecodeFrame(session, 1)
      assert.are.equal(0, frame.ms)
      assert.are.equal(80, frame.blizzardMs)
      assert.are.same({ 80 }, perfFormat:DecodeTimeline(session).blizzard)
    end)

    it("drives the frame boundary from its own OnUpdate while capturing", function()
      perf:Start(options())
      local onUpdate = perf.frame:GetScript("OnUpdate")
      assert.is_function(onUpdate)
      onUpdate()
      local session = perf:Stop()
      assert.are.equal(1, session.stats.frames)
      assert.is_nil(perf.frame:GetScript("OnUpdate"))
    end)

    it("asks to stop once the maximum duration has passed", function()
      local stopped = false
      perf:Start(options({ maxDurationSec = 2, onAutoStop = function() stopped = true end }))
      advance(1000)
      perf:_OnFrame()
      assert.is_false(stopped)
      advance(1500)
      perf:_OnFrame()
      assert.is_true(stopped)
    end)
  end)

  describe("allocations", function()
    local realCollectgarbage
    local kb

    before_each(function()
      realCollectgarbage = _G.collectgarbage
      kb = 1000
      _G.collectgarbage = function(opt)
        if opt == "count" then return kb end
        return 0
      end
    end)

    after_each(function()
      _G.collectgarbage = realCollectgarbage
    end)

    it("attributes allocated memory to the running node and counts collections separately", function()
      function A:TAllocates()
        kb = kb + 64
        B:TFrees()
      end
      function B:TFrees()
        kb = kb - 32
      end
      perf:Start(options({ trackAllocations = true }))
      A:TAllocates()
      local session = perf:Stop()
      local tree = perfFormat:Decode(session)
      assert.are.equal(64, find(tree, { "PerfSpecA.TAllocates" }).alloc)
      assert.are.equal(0, find(tree, { "PerfSpecA.TAllocates", "PerfSpecB.TFrees" }).alloc)
      assert.are.equal(32, session.stats.gcFreedKB)
      assert.are.equal(64, session.stats.allocatedKB)
    end)

    it("stops and restarts the garbage collector when asked", function()
      local calls = {}
      _G.collectgarbage = function(opt)
        table.insert(calls, opt)
        return kb
      end
      perf:Start(options({ pauseGC = true }))
      perf:Stop()
      assert.are.equal("stop", calls[1])
      assert.are.equal("restart", calls[#calls])
    end)
  end)

  describe("calibration", function()
    -- With a clock that advances 0.001 ms every time it is read, a wrapped call reads it
    -- once on entry (charging the caller) and once on return (charging itself), so each
    -- side of the call costs exactly one tick.
    it("measures what a wrapped call costs its caller and itself", function()
      perf:SetClock(function()
        now = now + 0.001
        return now
      end)
      perf:Start(options({ calibrate = true }))
      local session = perf:Stop()
      assert.is_near(0.001, session.stats.overheadParentMs, 1e-9)
      assert.is_near(0.001, session.stats.overheadChildMs, 1e-9)
      assert.is_near(0.002, session.stats.overheadPerCallMs, 1e-9)
    end)

    it("records no overhead when calibration is off", function()
      perf:Start(options({ calibrate = false }))
      local session = perf:Stop()
      assert.are.equal(0, session.stats.overheadPerCallMs)
      assert.is_nil(session.stats.overheadParentMs)
      assert.is_nil(session.stats.overheadChildMs)
    end)
  end)

  describe("live stats", function()
    it("reports elapsed time, calls, frames, and the worst frame so far", function()
      function A:TLive() advance(25) end
      perf:Start(options())
      A:TLive()
      perf:_OnFrame()
      local live = perf:GetLiveStats()
      assert.are.equal(25, live.elapsedMs)
      assert.are.equal(1, live.calls)
      assert.are.equal(1, live.frames)
      assert.are.equal(25, live.worstFrameMs)
      perf:Stop()
    end)
  end)
end)
