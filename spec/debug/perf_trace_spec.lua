-- perf_trace_spec.lua -- The profiler's call trace: every measured call recorded in order
-- with its start, duration, arguments and return values (debug/perf/engine.lua), and the
-- decoder that reads it back (debug/perf/format.lua). A fake clock makes timings exact.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadFreshBetterBagsModule("Context", "core/context.lua")
LoadBetterBagsModule("debug/perf/format.lua")

local perf = addon:GetModule("Perf")
local perfFormat = addon:GetModule("PerfFormat")
local context = addon:GetModule("Context")

local now = 0
local function advance(ms)
  now = now + ms
end

local function getOrNewModule(name)
  return addon:GetModule(name, true) or addon:NewModule(name)
end

local A = getOrNewModule("PerfTraceA")
local B = getOrNewModule("PerfTraceB")

local function options(overrides)
  local o = {
    modules = { "PerfTraceA", "PerfTraceB" },
    prototypes = {},
    includeRoot = false,
    calibrate = false,
    trace = true,
    traceArgs = false,
  }
  for k, v in pairs(overrides or {}) do
    o[k] = v
  end
  return o
end

local function capture(overrides, body)
  assert.is_true(perf:Start(options(overrides)))
  body()
  return perf:Stop()
end

local function traceOf(session)
  local trace = perfFormat:OpenTrace(session)
  assert.is_not_nil(trace, "the session has no trace")
  return trace
end

describe("Perf call trace", function()
  before_each(function()
    now = 0
    perf:Init()
    perf:SetClock(function() return now end)
    for _, mod in ipairs({ A, B }) do
      for k in pairs(mod) do
        if type(mod[k]) == "function" and k:match("^T") then mod[k] = nil end
      end
    end
  end)

  after_each(function()
    if perf:IsActive() then
      perf:Stop()
    end
  end)

  describe("recording", function()
    it("records every call in start order with its start, duration and function", function()
      function A:TOuter()
        advance(1)
        B:TInner()
        advance(2)
      end
      function B:TInner()
        advance(5)
      end
      local session = capture(nil, function()
        A:TOuter()
        advance(10)
        A:TOuter()
      end)
      local trace = traceOf(session)
      assert.are.equal(4, trace:Count())

      local outer, inner, again = trace:Get(1), trace:Get(2), trace:Get(3)
      assert.are.equal("PerfTraceA.TOuter", outer.name)
      assert.are.equal(0, outer.start)
      assert.are.equal(8, outer.wall)
      assert.are.equal(1, outer.depth)
      assert.are.equal("PerfTraceB.TInner", inner.name)
      assert.are.equal(1, inner.start)
      assert.are.equal(5, inner.wall)
      assert.are.equal(2, inner.depth)
      assert.are.equal(18, again.start)
      assert.are.equal(0, outer.flags)
      assert.are.equal(4, session.stats.traceCalls)
    end)

    it("decodes calls packed across chunk boundaries", function()
      function A:TTick() advance(1) end
      local session = capture({ traceChunkSize = 3 }, function()
        for _ = 1, 10 do
          A:TTick()
          advance(2)
        end
      end)
      local trace = traceOf(session)
      assert.are.equal(10, trace:Count())
      assert.are.equal(4, #session.trace.chunks)
      for i = 1, 10 do
        local call = trace:Get(i)
        assert.are.equal((i - 1) * 3, call.start, "call " .. i)
        assert.are.equal(1, call.wall, "call " .. i)
      end
    end)

    it("keeps a call that spans a coroutine yield as one call with a slice on each side", function()
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
      local session = capture(nil, function()
        B:TResumeFirst()
        advance(5000)
        B:TResumeSecond()
      end)
      local trace = traceOf(session)
      local sweep
      for i = 1, trace:Count() do
        if trace:Get(i).name == "PerfTraceA.TSweep" then sweep = trace:Get(i) end
      end
      assert.is_not_nil(sweep)
      assert.are.equal(1, sweep.start)
      assert.are.equal(11, sweep.segments[1].pausedAt)
      assert.are.equal(5012, sweep.segments[1].resumedAt)
      assert.are.equal(5032, sweep.finish)
      assert.are.equal(30, sweep.incl)
      assert.are.equal(0, sweep.flags)

      local sweepSlices = {}
      for _, slice in ipairs(trace:Slices(0, 6000)) do
        if slice.call.index == sweep.index then
          table.insert(sweepSlices, slice)
        end
      end
      assert.are.equal(2, #sweepSlices)
      assert.are.equal(1, sweepSlices[1].start)
      assert.are.equal(11, sweepSlices[1].finish)
      assert.are.equal(2, sweepSlices[1].depth)
      assert.are.equal(5012, sweepSlices[2].start)
      assert.are.equal(5032, sweepSlices[2].finish)
    end)

    it("marks calls an error cut short", function()
      function A:TCatches()
        pcall(function() B:TBoom() end)
        advance(1)
      end
      function B:TBoom()
        advance(2)
        error("boom")
      end
      local session = capture(nil, function()
        A:TCatches()
      end)
      local trace = traceOf(session)
      local boom = trace:Get(2)
      assert.are.equal("PerfTraceB.TBoom", boom.name)
      assert.is_true(boom.aborted)
      assert.are.equal(perfFormat.CALL_ABORTED, boom.flags)
      assert.is_false(trace:Get(1).aborted)
    end)

    it("marks calls left open by an uncaught error when the frame closes", function()
      function A:TThrows()
        advance(1)
        error("boom")
      end
      perf:Start(options())
      pcall(A.TThrows, A)
      advance(3)
      perf:_OnFrame()
      local trace = traceOf(perf:Stop())
      assert.is_true(trace:Get(1).aborted)
    end)

    it("marks calls still running when the capture stops", function()
      local session
      function A:TStops()
        advance(4)
        session = perf:Stop()
      end
      perf:Start(options())
      A:TStops()
      local call = traceOf(session):Get(1)
      assert.is_true(call.unfinished)
      assert.are.equal(4, call.wall)
    end)

    it("marks a coroutine paused when the capture stops as unfinished, ending where it paused", function()
      function A:TWaits()
        advance(3)
        perf:BeforeYield()
        coroutine.yield()
        perf:AfterResume()
      end
      local co = coroutine.create(function() A:TWaits() end)
      function B:TStarts() coroutine.resume(co) end
      local session = capture(nil, function()
        B:TStarts()
        advance(100)
      end)
      local waits = traceOf(session):Get(2)
      assert.are.equal("PerfTraceA.TWaits", waits.name)
      assert.is_true(waits.unfinished)
      assert.is_true(waits.paused)
      assert.are.equal(3, waits.wall)
    end)

    it("stops the whole capture once the trace is full, without dropping or truncating anything", function()
      local reasons = {}
      function A:TCount(n)
        advance(1)
        return n * 2
      end
      perf:Start(options({
        traceMaxCalls = 3,
        onAutoStop = function(reason) table.insert(reasons, reason) end,
      }))
      local results = {}
      for i = 1, 5 do
        results[i] = A:TCount(i)
      end
      -- Calls after the trace filled still run normally; they are just not measured.
      assert.same({ 2, 4, 6, 8, 10 }, results)
      assert.is_true(perf:IsActive(), "the capture is stopped by its owner, not dropped")
      perf:_OnFrame()
      perf:_OnFrame()
      assert.same({ "traceFull" }, reasons)

      local session = perf:Stop()
      assert.is_false(perf:IsActive())
      assert.are.equal("traceFull", session.stats.stopReason)
      assert.is_true(session.trace.full)
      assert.are.equal(3, session.stats.calls)
      assert.are.equal(3, traceOf(session):Count())
      assert.are.equal(3, session.stats.durationMs)
    end)

    it("records where every frame ends, so each call maps to its frame", function()
      function A:TWork() advance(2) end
      local session = capture(nil, function()
        A:TWork()
        perf:_OnFrame()
        advance(10)
        A:TWork()
        perf:_OnFrame()
      end)
      local trace = traceOf(session)
      assert.are.equal(1, trace:FrameOf(trace:Get(1).start))
      assert.are.equal(2, trace:FrameOf(trace:Get(2).start))
      local from, to = trace:FrameBounds(2)
      assert.are.equal(2, from)
      assert.are.equal(14, to)
    end)

    it("records no trace when tracing is off", function()
      function A:TWork() advance(2) end
      local session = capture({ trace = false }, function()
        A:TWork()
      end)
      assert.is_nil(session.trace)
      assert.is_nil(perfFormat:OpenTrace(session))
      assert.are.equal(1, session.stats.calls)
    end)
  end)

  describe("arguments and return values", function()
    it("records each call's arguments and return values", function()
      function A:TAdd(a, b)
        advance(1)
        return a + b, "sum"
      end
      local session = capture({ traceArgs = true }, function()
        A:TAdd(2, 3)
      end)
      local trace = traceOf(session)
      local call = trace:Get(1)
      assert.are.equal("<PerfTraceA>, 2, 3", trace:Text(call.args))
      assert.are.equal('5, "sum"', trace:Text(call.returns))
    end)

    it("stores an argument set once and points every call with the same arguments at it", function()
      function A:TAdd(a, b) return a + b end
      local session = capture({ traceArgs = true }, function()
        A:TAdd(2, 3)
        A:TAdd(2, 3)
        A:TAdd(2, 3)
        A:TAdd(4, 3)
      end)
      local trace = traceOf(session)
      local first = trace:Get(1).args
      assert.are.equal(first, trace:Get(2).args)
      assert.are.equal(first, trace:Get(3).args)
      assert.are_not.equal(first, trace:Get(4).args)
      local threes = 0
      for _, text in ipairs(session.trace.values) do
        if text == "3" then threes = threes + 1 end
      end
      assert.are.equal(1, threes, "each distinct value is described once")
    end)

    it("describes tables, frames, contexts, item data and prototype instances", function()
      local proto = {}
      function proto:TNoop() end
      perf:RegisterPrototype(proto, "PerfTraceProto")
      local instance = setmetatable({}, { __index = proto })
      local frame = { [0] = newproxy(), GetName = function() return "BetterBagsBagBackpack" end }
      local ctx = context:New("BagUpdate")
      ctx:Set("wipe", true)
      local item = { slotkey = "0_1", itemInfo = { itemID = 1234 } }
      function A:TTakes() end
      local session = capture({ traceArgs = true }, function()
        A:TTakes({ backpack = true, bags = { [1] = true } }, frame, ctx, item, instance)
      end)
      local trace = traceOf(session)
      local text = trace:Text(trace:Get(1).args)
      assert.is_truthy(text:find("{backpack=true, bags={[1]=true}}", 1, true), text)
      assert.is_truthy(text:find("frame BetterBagsBagBackpack", 1, true), text)
      assert.is_truthy(text:find('ctx BagUpdate {wipe=true}', 1, true), text)
      assert.is_truthy(text:find("item 0_1 #1234", 1, true), text)
      assert.is_truthy(text:find("<PerfTraceProto #1>", 1, true), text)
    end)

    it("copies a mutable argument's contents when the call is made", function()
      local request = { backpack = true }
      function A:TRequest() end
      local session = capture({ traceArgs = true }, function()
        A:TRequest(request)
        request.bank = true
        A:TRequest(request)
      end)
      local trace = traceOf(session)
      assert.are.equal("<PerfTraceA>, {backpack=true}", trace:Text(trace:Get(1).args))
      assert.are.equal("<PerfTraceA>, {backpack=true, bank=true}", trace:Text(trace:Get(2).args))
    end)

    it("never counts the time spent describing arguments", function()
      local slowFrame = { [0] = newproxy(), GetName = function() advance(50); return "Slow" end }
      function A:TTakesFrame()
        advance(2)
      end
      local session = capture({ traceArgs = true }, function()
        A:TTakesFrame(slowFrame)
      end)
      local call = traceOf(session):Get(1)
      assert.are.equal(2, call.wall)
      assert.are.equal(2, session.stats.instrumentedMs)
      assert.are.equal(50, session.stats.excludedMs)
    end)

    it("describes a value the caller may not read as secret", function()
      local savedCanAccess = _G.canaccessvalue
      _G.canaccessvalue = function(v) return v ~= 777 end
      function A:TSecret() end
      local ok, session = pcall(capture, { traceArgs = true }, function()
        A:TSecret(777, 1)
      end)
      _G.canaccessvalue = savedCanAccess
      assert.is_true(ok, tostring(session))
      local trace = traceOf(session)
      assert.are.equal("<PerfTraceA>, <secret number>, 1", trace:Text(trace:Get(1).args))
    end)

    it("still runs the call when an argument cannot be described", function()
      local broken = { [0] = newproxy(), GetName = function() error("no name") end }
      function A:TBroken(x) return x end
      local result
      local session = capture({ traceArgs = true }, function()
        result = A:TBroken(broken)
      end)
      assert.are.equal(broken, result)
      local trace = traceOf(session)
      assert.are.equal("<arguments could not be described>", trace:Text(trace:Get(1).args))
    end)

    it("records the payload of event and message entry points", function()
      local session = capture({ traceArgs = true }, function()
        local token = perf:Enter("[event] BAG_UPDATE", 3)
        advance(1)
        perf:Exit(token)
      end)
      local trace = traceOf(session)
      assert.are.equal("[event] BAG_UPDATE", trace:Get(1).name)
      assert.are.equal("3", trace:Text(trace:Get(1).args))
    end)

    it("scans for calls by function name or argument text, a budget of calls at a time", function()
      function A:TFind(n) return n end
      function B:TOther() end
      local session = capture({ traceArgs = true, traceChunkSize = 4 }, function()
        for i = 1, 20 do
          A:TFind(i)
          B:TOther()
        end
      end)
      local trace = traceOf(session)
      local found = {}
      local nextIndex = trace:Scan("tother", 1, 15, found)
      assert.are.equal(16, nextIndex)
      assert.are.same({ 2, 4, 6, 8, 10, 12, 14 }, found)
      while nextIndex do
        nextIndex = trace:Scan("tother", nextIndex, 15, found)
      end
      assert.are.equal(20, #found)

      local byArg = {}
      trace:Scan("<perftracea>, 1", 1, 1000, byArg)
      -- "1", "10".."19": every TFind call whose argument text starts with 1.
      assert.are.same({ 1, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37 }, byArg)
    end)

    it("records no arguments when argument tracing is off", function()
      function A:TAdd(a, b) return a + b end
      local session = capture({ traceArgs = false }, function()
        A:TAdd(2, 3)
      end)
      local call = traceOf(session):Get(1)
      assert.are.equal(0, call.args)
      assert.is_nil(traceOf(session):Text(call.args))
    end)
  end)
end)
