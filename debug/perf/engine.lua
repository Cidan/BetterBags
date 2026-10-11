local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Perf is an instrumenting profiler. While a capture runs, every function on the selected
-- modules and registered prototypes is replaced by a wrapper that records a calling-context
-- tree; Stop puts the original functions back. Nothing is wrapped while it is off.
--
-- Time is charged by a cursor: at every call, return, yield and resume, the time since the
-- previous transition is added to the node on top of the running stack. That gives exact
-- self time without double counting, and time with none of our code on the stack (between
-- frames, between events) is never counted.
--
-- Coroutines keep their own stack. A coroutine that yields through async:Yield (which
-- calls BeforeYield/AfterResume) is paused, and on resume its open frames are re-attached
-- under whatever resumed it, so paused time never inflates a frame.
---@class Perf: AceModule
---@field active boolean
---@field frame Frame
---@field clock? fun(): number
---@field prototypes {tbl: table, name: string}[]
local perf = addon:NewModule('Perf')

perf.active = false
perf.prototypes = {}

-- Modules that must never be wrapped: the profiler itself, the debug window that hosts
-- its UI, and Context, whose Get/Set calls are so frequent the wrappers would dominate
-- the measurement.
local ALWAYS_EXCLUDED = {
  Perf = true,
  PerfFormat = true,
  PerfSessions = true,
  PerfPane = true,
  FlameGraph = true,
  DebugWindow = true,
  Context = true,
}

local HISTOGRAM_BOUNDS = { 1, 5, 16, 33, 50, 100 }
local ROOT_NAME = '[all]'
local OVERFLOW_NAME = '[node limit reached]'
-- Calibration rotates through many distinct wrapped functions taking a few arguments,
-- because the cost of a wrapped call depends on how many different functions and nodes
-- are in play (table and cache effects); a single hot function underestimates it. Checked
-- against unprofiled runs of the real refresh pipeline; see .claude/rules/perf-profiler.md.
local CALIBRATION_LABELS = 64
local CALIBRATION_CALLS = 2048
local CALIBRATION_RUNS = 5

local coroutineRunning = coroutine.running
local MAIN = {}

-- Capture state. Kept in upvalues rather than on the module table because the wrappers
-- read and write them on every call.
local active = false
local clock
local root, overflow, cursor
local last, startTime
local nodeCount, maxNodes, droppedNodes
local threads, chain, chainN, curKey
local serial = 0
local fnCalls, fnIncl, fnMax, depth
local totalCalls, abortedFrames, abortedNames
local trackAlloc, lastKb, allocTotal, gcFreed
local frameSeq, frameTotal, frameCalls, frameNested, dirty, dirtyN
local frames, activeFrames, worstFrameMs
local histogram, blizzardHistogram
local worst, worstCap, spikeThreshold
-- The frame closed at the previous OnUpdate, held until the next Blizzard reading has been
-- credited (see considerFrame).
local pHas, pFrame, pAt, pMs, pBlizzard, pEntries
local timelineOurs, timelineBlizzard, timelineCalls, timelineNested, timelineCap
local frameMetric, maxDurationMs, onAutoStop, autoStopSent
local wrapped, overheadParent, overheadChild
local captureOptions

local function newNode(name, parent)
  return {
    name = name,
    parent = parent,
    children = {},
    self = 0,
    calls = 0,
    max = 0,
    alloc = 0,
    fseq = -1,
    fself = 0,
    fcalls = 0,
    falloc = 0,
  }
end

local function child(parent, name)
  local node = parent.children[name]
  if node then return node end
  if parent == overflow then return overflow end
  if nodeCount >= maxNodes then
    droppedNodes = droppedNodes + 1
    if not overflow then
      overflow = newNode(OVERFLOW_NAME, root)
      root.children[OVERFLOW_NAME] = overflow
      nodeCount = nodeCount + 1
    end
    return overflow
  end
  node = newNode(name, parent)
  parent.children[name] = node
  nodeCount = nodeCount + 1
  return node
end

local function touch(node)
  if node.fseq ~= frameSeq then
    node.fseq = frameSeq
    node.fself = 0
    node.fcalls = 0
    node.falloc = 0
    dirtyN = dirtyN + 1
    dirty[dirtyN] = node
  end
end

local function charge(now)
  local node = cursor
  if node ~= root then
    local dt = now - last
    touch(node)
    node.self = node.self + dt
    node.fself = node.fself + dt
    frameTotal = frameTotal + dt
  end
  last = now
  if trackAlloc then
    local kb = collectgarbage("count")
    local delta = kb - lastKb
    if delta >= 0 then
      if node ~= root then
        node.alloc = node.alloc + delta
        node.falloc = node.falloc + delta
        allocTotal = allocTotal + delta
      end
    else
      gcFreed = gcFreed - delta
    end
    lastKb = kb
  end
end

local function newThread(base)
  return {
    n = 0,
    nodes = {},
    labels = {},
    sids = {},
    t0 = {},
    pz = {},
    base = base,
    pausedTotal = 0,
    pauseStart = 0,
    detached = false,
  }
end

local function topOf(t)
  if t.n > 0 then return t.nodes[t.n] end
  return t.base
end

local function detach(t, now)
  if t.n > 0 and not t.detached then
    t.detached = true
    t.pauseStart = now
  end
end

-- attach re-roots a thread's open frames under a new base: the code that resumed it.
local function attach(t, base, now)
  t.base = base
  if t.detached then
    t.pausedTotal = t.pausedTotal + (now - t.pauseStart)
    local prev = base
    for i = 1, t.n do
      local node = child(prev, t.labels[i])
      t.nodes[i] = node
      prev = node
    end
    t.detached = false
  end
end

-- switchTo runs when a measured call happens on a different thread than the last one.
-- A thread already in the resume chain means everything above it has finished, yielded,
-- or died; a thread not in the chain is being resumed by the current one.
local function switchTo(key, now)
  charge(now)
  local index
  for i = chainN, 1, -1 do
    if chain[i] == key then
      index = i
      break
    end
  end
  if index then
    for i = chainN, index + 1, -1 do
      local t = threads[chain[i]]
      if t then detach(t, now) end
      chain[i] = nil
    end
    chainN = index
  else
    local t = threads[key]
    if not t then
      t = newThread(cursor)
      threads[key] = t
    end
    attach(t, cursor, now)
    chainN = chainN + 1
    chain[chainN] = key
  end
  curKey = key
  cursor = topOf(threads[key])
end

local function sync(now)
  local key = coroutineRunning() or MAIN
  if key ~= curKey then
    switchTo(key, now)
  else
    charge(now)
  end
  return threads[key]
end

local function enter(label)
  local now = clock()
  local t = sync(now)
  -- A call made from inside a measured call charges its caller-side overhead to that
  -- caller; a top-level call charges it to the root, which is never counted.
  if cursor ~= root then
    frameNested = frameNested + 1
  end
  local node = child(cursor, label)
  node.calls = node.calls + 1
  touch(node)
  node.fcalls = node.fcalls + 1
  serial = serial + 1
  local n = t.n + 1
  t.n = n
  t.nodes[n] = node
  t.labels[n] = label
  t.sids[n] = serial
  t.t0[n] = now
  t.pz[n] = t.pausedTotal
  cursor = node
  totalCalls = totalCalls + 1
  frameCalls = frameCalls + 1
  fnCalls[label] = (fnCalls[label] or 0) + 1
  depth[label] = (depth[label] or 0) + 1
  return serial
end

local function finish(sid)
  local now = clock()
  local t = sync(now)
  local sids = t.sids
  local n = t.n
  while n > 0 and sids[n] ~= sid do
    n = n - 1
  end
  if n == 0 then return end
  -- Frames above ours were left open by an error caught somewhere below them.
  for i = t.n, n + 1, -1 do
    local label = t.labels[i]
    depth[label] = depth[label] - 1
    abortedFrames = abortedFrames + 1
    abortedNames[label] = (abortedNames[label] or 0) + 1
  end
  local node = t.nodes[n]
  local label = t.labels[n]
  local incl = (now - t.t0[n]) - (t.pausedTotal - t.pz[n])
  if incl > node.max then node.max = incl end
  local d = depth[label] - 1
  depth[label] = d
  if d == 0 then
    fnIncl[label] = (fnIncl[label] or 0) + incl
  end
  if incl > (fnMax[label] or 0) then
    fnMax[label] = incl
  end
  t.n = n - 1
  if n > 1 then
    cursor = t.nodes[n - 1]
  else
    cursor = t.base
  end
end

local function exit(sid, ...)
  if active then
    finish(sid)
  end
  return ...
end

local function makeWrapper(label, fn)
  return function(...)
    if not active then
      return fn(...)
    end
    local sid = enter(label)
    return exit(sid, fn(...))
  end
end

local function resetState()
  root = newNode(ROOT_NAME, nil)
  overflow = nil
  cursor = root
  nodeCount = 1
  droppedNodes = 0
  threads = setmetatable({}, { __mode = 'k' })
  threads[MAIN] = newThread(root)
  chain = { MAIN }
  chainN = 1
  curKey = MAIN
  fnCalls, fnIncl, fnMax, depth = {}, {}, {}, {}
  totalCalls, abortedFrames, abortedNames = 0, 0, {}
  allocTotal, gcFreed = 0, 0
  frameSeq, frameTotal, frameCalls, frameNested, dirty, dirtyN = 0, 0, 0, 0, {}, 0
  frames, activeFrames, worstFrameMs = 0, 0, 0
  histogram, blizzardHistogram = {}, {}
  for i = 1, #HISTOGRAM_BOUNDS + 1 do
    histogram[i] = 0
    blizzardHistogram[i] = 0
  end
  worst = {}
  pHas, pFrame, pAt, pMs, pBlizzard, pEntries = false, nil, nil, nil, nil, nil
  timelineOurs, timelineBlizzard, timelineCalls, timelineNested = {}, {}, {}, {}
  autoStopSent = false
  last = clock()
  startTime = last
  if trackAlloc then
    lastKb = collectgarbage("count")
  end
end

local function bucketOf(ms)
  for i = 1, #HISTOGRAM_BOUNDS do
    if ms < HISTOGRAM_BOUNDS[i] then return i end
  end
  return #HISTOGRAM_BOUNDS + 1
end

-- collectForeign finds functions that are not ours: anything a LibStub library carries
-- (embedded Ace methods), and the AceAddon mixins, which are the same function object on
-- the root addon and on every module.
local function collectForeign()
  local foreign = {}
  for _, lib in LibStub:IterateLibraries() do
    if type(lib) == 'table' then
      for _, v in pairs(lib) do
        if type(v) == 'function' then foreign[v] = true end
      end
    end
  end
  local firstByKey = {}
  for _, module in addon:IterateModules() do
    for k, v in pairs(module) do
      if type(v) == 'function' then
        if rawget(addon, k) == v then
          foreign[v] = true
        end
        local first = firstByKey[k]
        if first == nil then
          firstByKey[k] = v
        elseif first == v then
          foreign[v] = true
        end
      end
    end
  end
  return foreign
end

local function wrapTable(tbl, prefix, foreign)
  if type(tbl[0]) == 'userdata' then return end
  for k, v in pairs(tbl) do
    if type(k) == 'string' and type(v) == 'function' and not foreign[v] then
      local w = makeWrapper(prefix .. '.' .. k, v)
      tbl[k] = w
      wrapped[#wrapped + 1] = { tbl, k, v, w }
    end
  end
end

local function toSet(list)
  if list == nil then return nil end
  local set = {}
  for _, v in ipairs(list) do set[v] = true end
  return set
end

local function install(options)
  wrapped = {}
  local foreign = collectForeign()
  local only = toSet(options.modules)
  local excluded = toSet(options.exclude) or {}
  for name, module in addon:IterateModules() do
    if not ALWAYS_EXCLUDED[name] and not excluded[name] and (only == nil or only[name]) then
      wrapTable(module, name, foreign)
    end
  end
  local onlyProtos = toSet(options.prototypes)
  for _, proto in ipairs(perf.prototypes) do
    if (onlyProtos == nil or onlyProtos[proto.name]) and not excluded[proto.name] then
      wrapTable(proto.tbl, proto.name, foreign)
    end
  end
  if options.includeRoot ~= false then
    wrapTable(addon, addonName, foreign)
  end
end

local function uninstall()
  for i = #wrapped, 1, -1 do
    local tbl, k, original, w = wrapped[i][1], wrapped[i][2], wrapped[i][3], wrapped[i][4]
    if tbl[k] == w then
      tbl[k] = original
    end
  end
end

local function us(ms)
  return math.floor(ms * 1000 + 0.5)
end

local function bytes(kb)
  return math.floor(kb * 1024 + 0.5)
end

local function sortedChildren(node)
  local list = {}
  for _, c in pairs(node.children) do
    list[#list + 1] = c
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local function finalize(now)
  local names, nameIds = {}, {}
  local function nameId(label)
    local id = nameIds[label]
    if not id then
      id = #names + 1
      names[id] = label
      nameIds[label] = id
    end
    return id
  end

  local ids, nodes = {}, {}
  local instrumentedUs = 0
  local function visit(node, parentId)
    local id = #nodes + 1
    ids[node] = id
    local selfUs = us(node.self)
    instrumentedUs = instrumentedUs + selfUs
    nodes[id] = string.format('%d,%d,%d,%d,%d,%d', parentId, nameId(node.name), selfUs, node.calls, us(node.max), bytes(node.alloc))
    for _, c in ipairs(sortedChildren(node)) do
      visit(c, id)
    end
  end
  visit(root, 0)

  local labels = {}
  for label in pairs(fnCalls) do
    labels[#labels + 1] = label
  end
  table.sort(labels, function(a, b) return nameId(a) < nameId(b) end)
  local functions = {}
  for _, label in ipairs(labels) do
    functions[#functions + 1] = string.format('%d,%d,%d,%d', nameId(label), fnCalls[label], us(fnIncl[label] or 0), us(fnMax[label] or 0))
  end

  local abortedLabels = {}
  for label in pairs(abortedNames) do
    abortedLabels[#abortedLabels + 1] = label
  end
  table.sort(abortedLabels, function(a, b) return nameId(a) < nameId(b) end)
  local aborted = {}
  for _, label in ipairs(abortedLabels) do
    aborted[#aborted + 1] = string.format('%d,%d', nameId(label), abortedNames[label])
  end

  local worstOut = {}
  for _, snap in ipairs(worst) do
    local entries = {}
    local flat = snap.entries
    for i = 1, #flat, 4 do
      entries[#entries + 1] = { ids[flat[i]], flat[i + 1], flat[i + 2], flat[i + 3] }
    end
    table.sort(entries, function(a, b) return a[1] < b[1] end)
    local packed = {}
    for i, e in ipairs(entries) do
      packed[i] = string.format('%d,%d,%d,%d', e[1], us(e[2]), e[3], bytes(e[4]))
    end
    worstOut[#worstOut + 1] = {
      frame = snap.frame,
      atUs = us(snap.atMs),
      us = us(snap.ms),
      blizzardUs = snap.blizzardMs and us(snap.blizzardMs) or nil,
      nodes = packed,
    }
  end

  local function packTimeline(values)
    local out = {}
    for i, v in ipairs(values) do
      out[i] = us(v)
    end
    return table.concat(out, ',')
  end

  return {
    formatVersion = 2,
    options = {
      modules = captureOptions.modules,
      exclude = captureOptions.exclude,
      prototypes = captureOptions.prototypes,
      maxNodes = maxNodes,
      worstFrames = worstCap,
      spikeThresholdMs = spikeThreshold,
      trackAllocations = trackAlloc,
      pauseGC = captureOptions.pauseGC == true,
      maxDurationSec = captureOptions.maxDurationSec or 0,
      timelineFrames = timelineCap,
    },
    stats = {
      durationMs = us(now - startTime) / 1000,
      instrumentedMs = instrumentedUs / 1000,
      calls = totalCalls,
      frames = frames,
      activeFrames = activeFrames,
      worstFrameMs = us(worstFrameMs) / 1000,
      aborted = abortedFrames,
      nodeCount = nodeCount,
      droppedNodes = droppedNodes,
      wrappedFunctions = #wrapped,
      overheadPerCallMs = (overheadParent or 0) + (overheadChild or 0),
      overheadParentMs = overheadParent,
      overheadChildMs = overheadChild,
      allocatedKB = bytes(allocTotal) / 1024,
      gcFreedKB = bytes(gcFreed) / 1024,
    },
    names = names,
    nodes = nodes,
    functions = functions,
    aborted = aborted,
    histogram = {
      bounds = { unpack(HISTOGRAM_BOUNDS) },
      counts = histogram,
      blizzard = frameMetric and blizzardHistogram or nil,
    },
    worst = worstOut,
    timeline = {
      ours = packTimeline(timelineOurs),
      calls = table.concat(timelineCalls, ','),
      nested = table.concat(timelineNested, ','),
      blizzard = frameMetric and packTimeline(timelineBlizzard) or nil,
    },
  }
end

local NO_ENTRIES = {}

-- considerWorst ranks a closed frame by the larger of our time and the Blizzard reading
-- credited to it, and keeps it if it is among the worst. entries is the frame's flat
-- node,self,calls,alloc snapshot.
local function considerWorst(frame, atMs, ms, blizzardMs, entries)
  if worstCap <= 0 then return end
  local rank = ms
  if blizzardMs and blizzardMs > rank then rank = blizzardMs end
  if rank < spikeThreshold then return end
  if #worst >= worstCap and rank <= worst[#worst].rank then return end
  local snap = { frame = frame, atMs = atMs, ms = ms, blizzardMs = blizzardMs, rank = rank, entries = entries or NO_ENTRIES }
  local pos = #worst + 1
  for i = 1, #worst do
    if rank > worst[i].rank then
      pos = i
      break
    end
  end
  table.insert(worst, pos, snap)
  if #worst > worstCap then
    worst[#worst] = nil
  end
end

-- considerFrame closes the worst-frame bookkeeping for one frame. Blizzard's reading taken
-- now covers the game tick that just finished, which overlaps this frame and the previous
-- one: work run before our OnUpdate in a tick (events, timers) only shows up in the next
-- frame's reading. The reading is credited to whichever of the two frames' measured time
-- it is closer to, so the previous frame can only be judged now.
---@param ms number
---@param blizzardMs number|nil
---@param now number
local function considerFrame(ms, blizzardMs, now)
  if worstCap <= 0 then return end
  local entries
  if dirtyN > 0 and (frameMetric or ms >= spikeThreshold) then
    entries = {}
    local k = 0
    for i = 1, dirtyN do
      local node = dirty[i]
      entries[k + 1] = node
      entries[k + 2] = node.fself
      entries[k + 3] = node.fcalls
      entries[k + 4] = node.falloc
      k = k + 4
    end
  end
  local credited = frameMetric and 0 or nil
  if blizzardMs then
    if pHas and math.abs(pMs - blizzardMs) < math.abs(ms - blizzardMs) then
      pBlizzard = (pBlizzard or 0) + blizzardMs
    else
      credited = credited + blizzardMs
    end
  end
  if pHas then
    considerWorst(pFrame, pAt, pMs, pBlizzard, pEntries)
  end
  pHas, pFrame, pAt, pMs, pBlizzard, pEntries = true, frameSeq, now - startTime, ms, credited, entries
end

-- flushPending judges the last closed frame when the capture stops; no later reading
-- will be credited to it.
local function flushPending()
  if pHas then
    considerWorst(pFrame, pAt, pMs, pBlizzard, pEntries)
    pHas, pEntries = false, nil
  end
end

function perf:Init()
  if not self.frame then
    self.frame = CreateFrame('Frame')
  end
  self.frame:SetScript('OnUpdate', nil)
  self.active = false
  active = false
end

---@param fn fun(): number
function perf:SetClock(fn)
  self.clock = fn
end

-- RegisterPrototype makes a prototype table (one that objects reach through
-- setmetatable __index) available for instrumentation under the given name.
---@param tbl table
---@param name string
function perf:RegisterPrototype(tbl, name)
  for _, proto in ipairs(self.prototypes) do
    if proto.tbl == tbl then return end
  end
  table.insert(self.prototypes, { tbl = tbl, name = name })
end

---@return boolean
function perf:IsActive()
  return active
end

---@return number overheadMs
-- Calibrate measures what one wrapped call costs, split by where the cursor charges it:
-- the part before the entry clock read and after the exit read lands on the caller, the
-- rest on the called function. Each side is the time a wrapped loop spends on that node
-- minus what the same loop costs unwrapped. The best of several runs is kept.
---@return number parentMs
---@return number childMs
function perf:Calibrate()
  local body = function(a) return a end
  local fns = {}
  for i = 1, CALIBRATION_LABELS do
    fns[i] = makeWrapper('[calibration] ' .. i, body)
  end
  local x, y, z = 1, '', true
  local bestParent, bestChild = math.huge, math.huge
  for _ = 1, CALIBRATION_RUNS do
    resetState()
    active = true

    local k = 1
    local t0 = clock()
    for _ = 1, CALIBRATION_CALLS do
      k = k + 1
      if k > CALIBRATION_LABELS then k = 1 end
    end
    local rotation = (clock() - t0) / CALIBRATION_CALLS

    k = 1
    t0 = clock()
    for _ = 1, CALIBRATION_CALLS do
      k = k + 1
      if k > CALIBRATION_LABELS then k = 1 end
      body(x, y, z)
    end
    local bare = (clock() - t0) / CALIBRATION_CALLS

    local sid = enter('[calibration]')
    k = 1
    for _ = 1, CALIBRATION_CALLS do
      k = k + 1
      if k > CALIBRATION_LABELS then k = 1 end
      fns[k](x, y, z)
    end
    finish(sid)
    active = false

    local caller = root.children['[calibration]']
    local calleeSelf = 0
    for _, c in pairs(caller.children) do
      calleeSelf = calleeSelf + c.self
    end
    local callerCost = caller.self / CALIBRATION_CALLS - rotation
    local calleeCost = calleeSelf / CALIBRATION_CALLS - (bare - rotation)
    if callerCost < bestParent then bestParent = callerCost end
    if calleeCost < bestChild then bestChild = calleeCost end
  end
  if bestParent < 0 then bestParent = 0 end
  if bestChild < 0 then bestChild = 0 end
  return bestParent, bestChild
end

---@class PerfOptions
---@field modules? string[] Module names to instrument; nil instruments every module.
---@field exclude? string[] Module or prototype names never to instrument.
---@field prototypes? string[] Registered prototype names to instrument; nil instruments all.
---@field includeRoot? boolean Instrument the root addon table (default true).
---@field maxNodes? number
---@field worstFrames? number
---@field spikeThresholdMs? number
---@field timelineFrames? number
---@field trackAllocations? boolean
---@field pauseGC? boolean
---@field maxDurationSec? number
---@field calibrate? boolean
---@field frameMetric? fun(): number|nil Per-frame external metric in ms (Blizzard's addon profiler).
---@field onAutoStop? fun() Called once when maxDurationSec has passed.

---@param options? PerfOptions
---@return boolean started
function perf:Start(options)
  if active then return false end
  options = options or {}
  captureOptions = options
  clock = self.clock or debugprofilestop
  maxNodes = options.maxNodes or 5000
  worstCap = options.worstFrames or 10
  spikeThreshold = options.spikeThresholdMs or 16
  timelineCap = options.timelineFrames or 18000
  frameMetric = options.frameMetric
  onAutoStop = options.onAutoStop
  maxDurationMs = (options.maxDurationSec or 0) * 1000
  trackAlloc = options.trackAllocations == true

  overheadParent, overheadChild = nil, nil
  if options.calibrate ~= false then
    overheadParent, overheadChild = self:Calibrate()
  end

  if options.pauseGC then
    collectgarbage("stop")
  end
  resetState()
  install(options)
  active = true
  self.active = true
  self.frame:SetScript('OnUpdate', function()
    perf:_OnFrame()
  end)
  return true
end

---@return table|nil session
function perf:Stop()
  if not active then return nil end
  local now = clock()
  charge(now)
  active = false
  self.active = false
  self.frame:SetScript('OnUpdate', nil)
  uninstall()
  if captureOptions.pauseGC then
    collectgarbage("restart")
  end
  flushPending()
  local session = finalize(now)
  root, overflow, cursor, threads, dirty, worst = nil, nil, nil, nil, nil, nil
  return session
end

-- _OnFrame closes one frame of measurements. It runs from the profiler's own OnUpdate,
-- where no measured call can legitimately be open on the main thread, so anything still
-- open there was left behind by an uncaught error.
function perf:_OnFrame()
  if not active then return end
  local now = clock()
  local mainThread = threads[MAIN]
  if mainThread.n > 0 then
    for i = mainThread.n, 1, -1 do
      local label = mainThread.labels[i]
      depth[label] = depth[label] - 1
      abortedNames[label] = (abortedNames[label] or 0) + 1
    end
    abortedFrames = abortedFrames + mainThread.n
    mainThread.n = 0
  end
  for i = chainN, 2, -1 do
    local t = threads[chain[i]]
    if t then detach(t, last) end
    chain[i] = nil
  end
  chainN = 1
  curKey = MAIN
  cursor = root
  last = now
  if trackAlloc then
    lastKb = collectgarbage("count")
  end

  local ms = frameTotal
  local blizzardMs = frameMetric and frameMetric() or nil
  frames = frames + 1
  if ms > 0 then activeFrames = activeFrames + 1 end
  if ms > worstFrameMs then worstFrameMs = ms end
  histogram[bucketOf(ms)] = histogram[bucketOf(ms)] + 1
  if blizzardMs then
    blizzardHistogram[bucketOf(blizzardMs)] = blizzardHistogram[bucketOf(blizzardMs)] + 1
  end
  if #timelineOurs < timelineCap then
    timelineOurs[#timelineOurs + 1] = ms
    timelineCalls[#timelineCalls + 1] = frameCalls
    timelineNested[#timelineNested + 1] = frameNested
    if frameMetric then
      timelineBlizzard[#timelineBlizzard + 1] = blizzardMs or 0
    end
  end
  considerFrame(ms, blizzardMs, now)

  frameSeq = frameSeq + 1
  frameTotal = 0
  frameCalls = 0
  frameNested = 0
  dirtyN = 0

  if maxDurationMs > 0 and not autoStopSent and now - startTime >= maxDurationMs then
    autoStopSent = true
    if onAutoStop then onAutoStop() end
  end
end

-- Enter opens a manual span. It returns nil when no capture is running; pass the result
-- to Exit either way.
---@param label string
---@return number|nil token
function perf:Enter(label)
  if not active then return nil end
  return enter(label)
end

---@param token number|nil
function perf:Exit(token)
  if token and active then
    finish(token)
  end
end

-- Wrap returns fn instrumented under label, for local functions the automatic wrapping
-- cannot reach. Outside a capture it costs one extra call and a flag check.
---@generic F
---@param label string
---@param fn F
---@return F
function perf:Wrap(label, fn)
  return makeWrapper(label, fn)
end

-- BeforeYield must be called inside a coroutine right before it yields, and AfterResume
-- right after the yield returns (core/async.lua does both).
function perf:BeforeYield()
  if not active then return end
  local key = coroutineRunning()
  if not key then return end
  local now = clock()
  local t = sync(now)
  detach(t, now)
  if chain[chainN] == key then
    chain[chainN] = nil
    chainN = chainN - 1
  end
  curKey = chain[chainN]
  cursor = topOf(threads[curKey])
end

function perf:AfterResume()
  if not active then return end
  if not coroutineRunning() then return end
  sync(clock())
end

---@return table|nil
function perf:GetLiveStats()
  if not active then return nil end
  return {
    elapsedMs = clock() - startTime,
    calls = totalCalls,
    frames = frames,
    worstFrameMs = worstFrameMs,
    nodes = nodeCount,
    wrappedFunctions = #wrapped,
  }
end
