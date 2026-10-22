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
--
-- With tracing on, every measured call is also recorded in the order it started: its start,
-- duration, node, flags, and (optionally) its arguments and return values. Each distinct
-- value is described once and each distinct argument list stored once; a call only holds
-- the id of its argument list. Time the profiler spends on its own bookkeeping (describing
-- values, packing records) is taken off a virtual clock, so it is charged to nothing.
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
  TraceChart = true,
  DebugWindow = true,
  RenderRecorder = true,
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

-- A call record is RECORD numbers: start (microseconds after the previous call in its
-- chunk; 0 for the first), node id, argument set id, duration (-1 while running),
-- return set id, flags. Records are kept as numbers until every call of a chunk has
-- ended, then the chunk is packed into one string.
local RECORD = 6
local DEFAULT_CHUNK_SIZE = 4096
local DEFAULT_MAX_CALLS = 1000000
local CALL_ABORTED = 1
local CALL_UNFINISHED = 2
local CALL_PAUSED = 4
perf.CALL_ABORTED = CALL_ABORTED
perf.CALL_UNFINISHED = CALL_UNFINISHED
perf.CALL_PAUSED = CALL_PAUSED

-- Limits on how much of a value is described.
local MAX_STRING = 64
local MAX_FIELDS = 8
local MAX_DEPTH = 2
local CONTEXT_SKIP = { event = true, events = true }
local BROKEN_TEXT = '<arguments could not be described>'

local coroutineRunning = coroutine.running
local MAIN = {}

-- Capture state. Kept in upvalues rather than on the module table because the wrappers
-- read and write them on every call.
local active = false
local capturing = false
local clock
local excluded = 0
local root, overflow, cursor
local last, startTime
local nodeCount, maxNodes, droppedNodes, nodeList
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
-- Named per-frame readings recorded beside ours (options.frameSeries): { name, fn, data }.
local frameSeries = {}
local wrapped, overheadParent, overheadChild
local captureOptions
local frozen, frozenAt, stopReason

-- Trace state.
local tracing, traceArgs, traceMax, chunkSize
local sidBase, traceCount
local chunks, packed, chunkStart, chunkEnd, chunkPool
local segments, frameEnds
local values, valueIds, numIds, strIds, objIds, protoNames, instanceCounts
local setRoots, sets, scratch, brokenSetId
local canAccess, contextModule

-- The virtual clock: the real clock minus the time the profiler excluded for itself.
local function vclock()
  return clock() - excluded
end

local function us(ms)
  return math.floor(ms * 1000 + 0.5)
end

local function bytes(kb)
  return math.floor(kb * 1024 + 0.5)
end

local function newNode(name, parent)
  nodeCount = nodeCount + 1
  local node = {
    id = nodeCount,
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
  nodeList[nodeCount] = node
  return node
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
    end
    return overflow
  end
  node = newNode(name, parent)
  parent.children[name] = node
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

---------------------------------------------------------------------------------------
-- Call records
---------------------------------------------------------------------------------------

---@param index number
---@return table chunk
---@return number offset
local function recordOf(index)
  local ci = math.floor((index - 1) / chunkSize) + 1
  return chunks[ci], ((index - 1) % chunkSize) * RECORD
end

-- packChunk turns a chunk whose calls have all ended into one string, and remembers where
-- its first call starts and its last call ends, so a time window can skip whole chunks.
local function packChunk(ci)
  local x0 = clock()
  local chunk = chunks[ci]
  local data, n = chunk.data, chunk.n
  local s, maxEnd = chunk.start, chunk.start
  for i = 0, n - 1 do
    local o = i * RECORD
    s = s + data[o + 1]
    local e = s + data[o + 4]
    if e > maxEnd then maxEnd = e end
  end
  packed[ci] = table.concat(data, ',', 1, n * RECORD)
  chunkStart[ci] = chunk.start
  chunkEnd[ci] = maxEnd
  chunks[ci] = nil
  chunkPool[#chunkPool + 1] = data
  excluded = excluded + (clock() - x0)
end

---@param sid number
---@param node table
---@param startUs number
local function traceEnter(sid, node, startUs)
  local index = sid - sidBase
  local ci = math.floor((index - 1) / chunkSize) + 1
  local chunk = chunks[ci]
  if not chunk then
    chunk = { data = table.remove(chunkPool) or {}, n = 0, open = 0, start = startUs, last = startUs }
    chunks[ci] = chunk
  end
  local data = chunk.data
  local o = chunk.n * RECORD
  data[o + 1] = startUs - chunk.last
  data[o + 2] = node.id
  data[o + 3] = 0
  data[o + 4] = -1
  data[o + 5] = 0
  data[o + 6] = 0
  chunk.last = startUs
  chunk.n = chunk.n + 1
  chunk.open = chunk.open + 1
  traceCount = index
end

-- traceClose ends a call record: it ran from startUs to endUs.
---@param sid number
---@param startUs number
---@param endUs number
---@param flags number
---@param retId number
local function traceClose(sid, startUs, endUs, flags, retId)
  local index = sid - sidBase
  local chunk, o = recordOf(index)
  if not chunk then return end
  local data = chunk.data
  data[o + 4] = endUs - startUs
  data[o + 5] = retId
  data[o + 6] = flags
  chunk.open = chunk.open - 1
  if chunk.open == 0 and chunk.n == chunkSize then
    packChunk(math.floor((index - 1) / chunkSize) + 1)
  end
end

---@param sid number
---@param setId number
local function traceSetArgs(sid, setId)
  local chunk, o = recordOf(sid - sidBase)
  if chunk then
    chunk.data[o + 3] = setId
  end
end

-- tracePause gives every open call of a paused thread a provisional end where it paused.
-- If the thread resumes, the call reopens and a segment records the pause.
local function tracePause(t, now)
  local pauseUs = us(now - startTime)
  t.pauseUs = pauseUs
  for i = 1, t.n do
    local chunk, o = recordOf(t.sids[i] - sidBase)
    if chunk then
      chunk.data[o + 4] = pauseUs - t.us0[i]
      chunk.data[o + 6] = CALL_PAUSED
    end
  end
end

local function traceResume(t, now)
  local resumeUs = us(now - startTime)
  for i = 1, t.n do
    local index = t.sids[i] - sidBase
    local chunk, o = recordOf(index)
    if chunk then
      chunk.data[o + 4] = -1
      chunk.data[o + 6] = 0
    end
    local n = #segments
    segments[n + 1] = index
    segments[n + 2] = t.pauseUs
    segments[n + 3] = resumeUs
    segments[n + 4] = t.nodes[i].id
  end
end

-- closeOpenCalls ends every call still open when the capture stops, and packs the chunks
-- that held them. Calls on the running stack end at stop and are unfinished; calls of a
-- paused coroutine keep the end where they paused; those of a coroutine that died are
-- calls an error cut short.
---@param now number
local function closeOpenCalls(now)
  local endUs = us(now - startTime)
  local dead = {}
  for key, t in pairs(threads) do
    if type(key) == 'thread' and t.n > 0 and coroutine.status(key) == 'dead' then
      for i = 1, t.n do
        dead[t.sids[i]] = true
      end
    end
  end
  local open = {}
  for ci in pairs(chunks) do
    open[#open + 1] = ci
  end
  table.sort(open)
  for _, ci in ipairs(open) do
    local chunk = chunks[ci]
    local data = chunk.data
    local s = chunk.start
    for i = 0, chunk.n - 1 do
      local o = i * RECORD
      s = s + data[o + 1]
      local sid = (ci - 1) * chunkSize + i + 1 + sidBase
      if data[o + 4] == -1 then
        data[o + 4] = endUs - s
        data[o + 6] = CALL_UNFINISHED
      elseif data[o + 6] == CALL_PAUSED then
        data[o + 6] = dead[sid] and CALL_ABORTED or (CALL_UNFINISHED + CALL_PAUSED)
      end
    end
    chunk.open = 0
    packChunk(ci)
  end
end

---------------------------------------------------------------------------------------
-- Describing arguments and return values
---------------------------------------------------------------------------------------

local function internText(text)
  local id = valueIds[text]
  if not id then
    id = #values + 1
    values[id] = text
    valueIds[text] = id
  end
  return id
end

local NIL_ID, TRUE_ID, FALSE_ID = 1, 2, 3

local describeTable

local function quoteString(s)
  local more = #s - MAX_STRING
  if more > 0 then
    return string.format('%q', string.sub(s, 1, MAX_STRING)) .. '...+' .. more
  end
  return (string.gsub(string.format('%q', s), '\\\n', '\\n'))
end

---@param v any
---@return number
local function valueId(v)
  if v == nil then return NIL_ID end
  local t = type(v)
  if canAccess and not canAccess(v) then
    return internText('<secret ' .. t .. '>')
  end
  if t == 'number' then
    local id = numIds[v]
    if id then return id end
    if v ~= v then return internText('nan') end
    id = internText(tostring(v))
    numIds[v] = id
    return id
  elseif t == 'string' then
    local id = strIds[v]
    if id then return id end
    id = internText(quoteString(v))
    strIds[v] = id
    return id
  elseif t == 'boolean' then
    return v and TRUE_ID or FALSE_ID
  end
  local id = objIds[v]
  if id then return id end
  if t == 'table' then
    local text, keep = describeTable(v, 1)
    id = internText(text)
    if keep then objIds[v] = id end
    return id
  end
  id = internText(t)
  objIds[v] = id
  return id
end

local function valueText(v, level)
  if type(v) == 'table' and not (canAccess and not canAccess(v)) then
    local id = objIds[v]
    if id then return values[id] end
    local text, keep = describeTable(v, level)
    if keep then objIds[v] = internText(text) end
    return text
  end
  return values[valueId(v)]
end

local function keyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  if ta == 'number' or ta == 'string' then return a < b end
  return false
end

local function keyText(k)
  if type(k) == 'string' and string.match(k, '^[%a_][%w_]*$') then
    return k
  end
  return '[' .. valueText(k, MAX_DEPTH + 1) .. ']'
end

local function fieldsText(t, level, skip)
  if type(t) ~= 'table' then return '{}' end
  if level > MAX_DEPTH then return '{...}' end
  local keys, n, more = {}, 0, 0
  for k in pairs(t) do
    if not (skip and skip[k]) then
      if n < MAX_FIELDS then
        n = n + 1
        keys[n] = k
      else
        more = more + 1
      end
    end
  end
  table.sort(keys, keyLess)
  local parts = {}
  for i = 1, n do
    local k = keys[i]
    parts[i] = keyText(k) .. '=' .. valueText(rawget(t, k), level + 1)
  end
  if more > 0 then
    parts[n + 1] = '...+' .. more
  end
  return '{' .. table.concat(parts, ', ') .. '}'
end

-- describeTable names a table. The second result says whether the description can be kept
-- for the table's lifetime: frames, prototype instances and item data are named by
-- identity; contexts and plain tables are described as they are at each call.
---@param v table
---@param level number
---@return string text
---@return boolean keep
function describeTable(v, level)
  if type(rawget(v, 0)) == 'userdata' then
    local name = v.GetName and v:GetName()
    return 'frame ' .. (type(name) == 'string' and name or '<unnamed>'), true
  end
  local mt = getmetatable(v)
  local index = type(mt) == 'table' and rawget(mt, '__index') or nil
  if index ~= nil then
    if index == contextModule then
      local keys = rawget(v, 'keys')
      local event = type(keys) == 'table' and rawget(keys, 'event') or nil
      return 'ctx ' .. tostring(event) .. ' ' .. fieldsText(keys, level, CONTEXT_SKIP), false
    end
    local protoName = protoNames[index]
    if protoName then
      local count = (instanceCounts[protoName] or 0) + 1
      instanceCounts[protoName] = count
      return '<' .. protoName .. ' #' .. count .. '>', true
    end
  end
  local slotkey, itemInfo = rawget(v, 'slotkey'), rawget(v, 'itemInfo')
  if type(slotkey) == 'string' and type(itemInfo) == 'table' then
    if rawget(v, 'isItemGap') then return 'gap ' .. slotkey, true end
    if rawget(v, 'isItemEmpty') then return 'empty ' .. slotkey, true end
    return 'item ' .. slotkey .. ' #' .. tostring(rawget(itemInfo, 'itemID')), true
  end
  return fieldsText(v, level, nil), false
end

-- argSet returns the id of an argument list, storing the list the first time it is seen.
-- Lists are found through a trie keyed by value id, so a repeated list costs one lookup
-- per value and allocates nothing.
local function argSet(...)
  local n = select('#', ...)
  local node = setRoots[n]
  if not node then
    node = {}
    setRoots[n] = node
  end
  for i = 1, n do
    local id = valueId((select(i, ...)))
    scratch[i] = id
    local nextNode = node[id]
    if not nextNode then
      nextNode = {}
      node[id] = nextNode
    end
    node = nextNode
  end
  local setId = node[0]
  if not setId then
    setId = #sets + 1
    sets[setId] = table.concat(scratch, ',', 1, n)
    node[0] = setId
  end
  return setId
end

local function brokenSet()
  if not brokenSetId then
    brokenSetId = #sets + 1
    sets[brokenSetId] = tostring(internText(BROKEN_TEXT))
  end
  return brokenSetId
end

-- describe runs off the clock: its time is excluded from every measurement.
local function describe(...)
  local x0 = clock()
  local ok, setId = pcall(argSet, ...)
  if not ok then setId = brokenSet() end
  excluded = excluded + (clock() - x0)
  return setId
end

local function resetValues()
  values, valueIds = {}, {}
  numIds, strIds = {}, {}
  objIds = setmetatable({}, { __mode = 'k' })
  protoNames, instanceCounts = {}, {}
  setRoots, sets, scratch, brokenSetId = {}, {}, {}, nil
  internText('nil')
  internText('true')
  internText('false')
  for name, module in addon:IterateModules() do
    objIds[module] = internText('<' .. name .. '>')
  end
  objIds[addon] = internText('<' .. addonName .. '>')
  for _, proto in ipairs(perf.prototypes) do
    protoNames[proto.tbl] = proto.name
    objIds[proto.tbl] = internText('<' .. proto.name .. ' prototype>')
  end
end

---------------------------------------------------------------------------------------
-- Threads and the call stack
---------------------------------------------------------------------------------------

local function newThread(base)
  return {
    n = 0,
    nodes = {},
    labels = {},
    sids = {},
    t0 = {},
    us0 = {},
    pz = {},
    base = base,
    pausedTotal = 0,
    pauseStart = 0,
    pauseUs = 0,
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
    if tracing then
      tracePause(t, now)
    end
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
    if tracing then
      traceResume(t, now)
    end
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

-- freeze stops all recording at once when the trace is full, so the call tree, frames and
-- trace all end at the same moment. The capture's owner is told on the next frame and
-- stops it; nothing recorded so far is dropped.
local function freeze(now)
  frozen = true
  frozenAt = now
  stopReason = 'traceFull'
  active = false
  perf.active = false
end

---@param label string
---@return number sid 0 when the trace just filled and nothing was recorded.
local function enter(label)
  local now = vclock()
  local t = sync(now)
  if tracing and serial - sidBase >= traceMax then
    freeze(now)
    return 0
  end
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
  if tracing then
    local startUs = us(now - startTime)
    t.us0[n] = startUs
    traceEnter(serial, node, startUs)
  end
  return serial
end

---@param sid number
---@param retId? number
local function finish(sid, retId)
  local now = vclock()
  local t = sync(now)
  local sids = t.sids
  local n = t.n
  while n > 0 and sids[n] ~= sid do
    n = n - 1
  end
  if n == 0 then return end
  local endUs = tracing and us(now - startTime) or 0
  -- Frames above ours were left open by an error caught somewhere below them.
  for i = t.n, n + 1, -1 do
    local label = t.labels[i]
    depth[label] = depth[label] - 1
    abortedFrames = abortedFrames + 1
    abortedNames[label] = (abortedNames[label] or 0) + 1
    if tracing then
      traceClose(sids[i], t.us0[i], endUs, CALL_ABORTED, 0)
    end
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
  if tracing then
    traceClose(sid, t.us0[n], endUs, 0, retId or 0)
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

local function exitWithReturns(sid, ...)
  if active then
    finish(sid, describe(...))
  end
  return ...
end

local function makeWrapper(label, fn)
  return function(...)
    if not active then
      return fn(...)
    end
    local sid = enter(label)
    if traceArgs and sid ~= 0 then
      traceSetArgs(sid, describe(...))
      return exitWithReturns(sid, fn(...))
    end
    return exit(sid, fn(...))
  end
end

-- Lua 5.1 allows 60 upvalues per function, so the reset is split by area.
local function resetTree()
  nodeCount = 0
  nodeList = {}
  root = newNode(ROOT_NAME, nil)
  overflow = nil
  cursor = root
  droppedNodes = 0
  threads = setmetatable({}, { __mode = 'k' })
  threads[MAIN] = newThread(root)
  chain = { MAIN }
  chainN = 1
  curKey = MAIN
  fnCalls, fnIncl, fnMax, depth = {}, {}, {}, {}
  totalCalls, abortedFrames, abortedNames = 0, 0, {}
  allocTotal, gcFreed = 0, 0
end

local function resetFrames()
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
  for i = 1, #frameSeries do
    frameSeries[i].data = {}
  end
  autoStopSent = false
  frozen, frozenAt, stopReason = false, nil, nil
end

local function resetTrace()
  sidBase, traceCount = serial, 0
  chunks, packed, chunkStart, chunkEnd, chunkPool = {}, {}, {}, {}, {}
  segments, frameEnds = {}, {}
  if tracing then
    resetValues()
  end
end

local function resetState()
  excluded = 0
  resetTree()
  resetFrames()
  resetTrace()
  last = vclock()
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
  local excludedNames = toSet(options.exclude) or {}
  for name, module in addon:IterateModules() do
    if not ALWAYS_EXCLUDED[name] and not excludedNames[name] and (only == nil or only[name]) then
      wrapTable(module, name, foreign)
    end
  end
  local onlyProtos = toSet(options.prototypes)
  for _, proto in ipairs(perf.prototypes) do
    if (onlyProtos == nil or onlyProtos[proto.name]) and not excludedNames[proto.name] then
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

-- finalize packs the capture into a session. Node ids are creation order, which puts every
-- parent before its children, and are the ids the trace's call records refer to.
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

  local nodes = {}
  local instrumentedUs = 0
  for id = 1, nodeCount do
    local node = nodeList[id]
    local selfUs = us(node.self)
    instrumentedUs = instrumentedUs + selfUs
    local parentId = node.parent and node.parent.id or 0
    nodes[id] = string.format('%d,%d,%d,%d,%d,%d', parentId, nameId(node.name), selfUs, node.calls, us(node.max), bytes(node.alloc))
  end

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
      entries[#entries + 1] = { flat[i].id, flat[i + 1], flat[i + 2], flat[i + 3] }
    end
    table.sort(entries, function(a, b) return a[1] < b[1] end)
    local packedEntries = {}
    for i, e in ipairs(entries) do
      packedEntries[i] = string.format('%d,%d,%d,%d', e[1], us(e[2]), e[3], bytes(e[4]))
    end
    worstOut[#worstOut + 1] = {
      frame = snap.frame,
      atUs = us(snap.atMs),
      us = us(snap.ms),
      blizzardUs = snap.blizzardMs and us(snap.blizzardMs) or nil,
      nodes = packedEntries,
    }
  end

  local function packTimeline(list)
    local out = {}
    for i, v in ipairs(list) do
      out[i] = us(v)
    end
    return table.concat(out, ',')
  end

  local packedSeries
  for i = 1, #frameSeries do
    packedSeries = packedSeries or {}
    packedSeries[frameSeries[i].name] = packTimeline(frameSeries[i].data)
  end

  local trace
  if tracing then
    trace = {
      chunkSize = chunkSize,
      calls = traceCount,
      chunks = packed,
      chunkStarts = table.concat(chunkStart, ','),
      chunkEnds = table.concat(chunkEnd, ','),
      segments = table.concat(segments, ','),
      frameEnds = table.concat(frameEnds, ','),
      values = traceArgs and values or {},
      sets = traceArgs and sets or {},
      args = traceArgs or nil,
      full = frozen or nil,
    }
  end

  return {
    formatVersion = 3,
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
      trace = tracing,
      traceArgs = traceArgs,
      traceMaxCalls = tracing and traceMax or nil,
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
      excludedMs = us(excluded) / 1000,
      traceCalls = tracing and traceCount or nil,
      stopReason = stopReason,
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
      series = packedSeries,
    },
    trace = trace,
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
  capturing = false
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

-- IsActive is true from Start until Stop, including after a full trace froze recording.
---@return boolean
function perf:IsActive()
  return capturing
end

-- ElapsedMs is how long the running capture has run, on the clock its trace is timed with
-- (excluding the profiler's own time); nil while no capture runs.
---@return number?
function perf:ElapsedMs()
  if not capturing then return nil end
  return vclock() - startTime
end

---@return number overheadMs
-- Calibrate measures what one wrapped call costs, split by where the cursor charges it:
-- the part before the entry clock read and after the exit read lands on the caller, the
-- rest on the called function. Each side is the time a wrapped loop spends on that node
-- minus what the same loop costs unwrapped. The best of several runs is kept. It runs with
-- the capture's tracing settings, so the cost of recording a call is part of it.
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
  local limit = traceMax
  traceMax = math.huge
  for _ = 1, CALIBRATION_RUNS do
    resetState()
    active = true

    local k = 1
    local t0 = vclock()
    for _ = 1, CALIBRATION_CALLS do
      k = k + 1
      if k > CALIBRATION_LABELS then k = 1 end
    end
    local rotation = (vclock() - t0) / CALIBRATION_CALLS

    k = 1
    t0 = vclock()
    for _ = 1, CALIBRATION_CALLS do
      k = k + 1
      if k > CALIBRATION_LABELS then k = 1 end
      body(x, y, z)
    end
    local bare = (vclock() - t0) / CALIBRATION_CALLS

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
  traceMax = limit
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
---@field trace? boolean Record every measured call in order.
---@field traceArgs? boolean Also record each call's arguments and return values.
---@field traceMaxCalls? number Recording stops (the capture freezes) after this many calls.
---@field traceChunkSize? number Calls per packed chunk.
---@field frameMetric? fun(): number|nil Per-frame external metric in ms (Blizzard's addon profiler).
---@field frameSeries? table<string, fun(): number|nil> More named per-frame readings in ms, recorded as timeline.series[name].
---@field onAutoStop? fun(reason: "maxDuration"|"traceFull") Called once when the capture should stop on its own.

---@param options? PerfOptions
---@return boolean started
function perf:Start(options)
  if capturing then return false end
  options = options or {}
  captureOptions = options
  clock = self.clock or debugprofilestop
  maxNodes = options.maxNodes or 5000
  worstCap = options.worstFrames or 10
  spikeThreshold = options.spikeThresholdMs or 16
  timelineCap = options.timelineFrames or 18000
  frameMetric = options.frameMetric
  frameSeries = {}
  for name, fn in pairs(options.frameSeries or {}) do
    frameSeries[#frameSeries + 1] = { name = name, fn = fn, data = {} }
  end
  table.sort(frameSeries, function(a, b) return a.name < b.name end)
  onAutoStop = options.onAutoStop
  maxDurationMs = (options.maxDurationSec or 0) * 1000
  trackAlloc = options.trackAllocations == true
  tracing = options.trace == true
  traceArgs = tracing and options.traceArgs == true
  traceMax = options.traceMaxCalls or DEFAULT_MAX_CALLS
  chunkSize = options.traceChunkSize or DEFAULT_CHUNK_SIZE
  canAccess = type(_G.canaccessvalue) == 'function' and _G.canaccessvalue or nil
  contextModule = addon:GetModule('Context', true)

  overheadParent, overheadChild = nil, nil
  if options.calibrate ~= false then
    overheadParent, overheadChild = self:Calibrate()
  end

  if options.pauseGC then
    collectgarbage("stop")
  end
  resetState()
  install(options)
  capturing = true
  active = true
  self.active = true
  self.frame:SetScript('OnUpdate', function()
    perf:_OnFrame()
  end)
  return true
end

---@return table|nil session
function perf:Stop()
  if not capturing then return nil end
  local now
  if frozen then
    now = frozenAt
  else
    now = vclock()
    charge(now)
  end
  active = false
  capturing = false
  self.active = false
  self.frame:SetScript('OnUpdate', nil)
  uninstall()
  if captureOptions.pauseGC then
    collectgarbage("restart")
  end
  flushPending()
  if tracing then
    closeOpenCalls(now)
  end
  local session = finalize(now)
  root, overflow, cursor, threads, dirty, worst, nodeList = nil, nil, nil, nil, nil, nil, nil
  chunks, packed, chunkStart, chunkEnd, chunkPool, segments, frameEnds = nil, nil, nil, nil, nil, nil, nil
  values, valueIds, numIds, strIds, objIds, setRoots, sets, scratch = nil, nil, nil, nil, nil, nil, nil, nil
  frozen = false
  return session
end

-- _OnFrame closes one frame of measurements. It runs from the profiler's own OnUpdate,
-- where no measured call can legitimately be open on the main thread, so anything still
-- open there was left behind by an uncaught error.
function perf:_OnFrame()
  if frozen then
    if not autoStopSent then
      autoStopSent = true
      if onAutoStop then onAutoStop(stopReason) end
    end
    return
  end
  if not active then return end
  local now = vclock()
  local mainThread = threads[MAIN]
  if mainThread.n > 0 then
    local endUs = tracing and us(last - startTime) or 0
    for i = mainThread.n, 1, -1 do
      local label = mainThread.labels[i]
      depth[label] = depth[label] - 1
      abortedNames[label] = (abortedNames[label] or 0) + 1
      if tracing then
        traceClose(mainThread.sids[i], mainThread.us0[i], endUs, CALL_ABORTED, 0)
      end
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
    for i = 1, #frameSeries do
      local series = frameSeries[i]
      series.data[#series.data + 1] = series.fn() or 0
    end
  end
  if tracing then
    frameEnds[#frameEnds + 1] = us(now - startTime)
  end
  considerFrame(ms, blizzardMs, now)

  frameSeq = frameSeq + 1
  frameTotal = 0
  frameCalls = 0
  frameNested = 0
  dirtyN = 0

  if maxDurationMs > 0 and not autoStopSent and now - startTime >= maxDurationMs then
    autoStopSent = true
    stopReason = 'maxDuration'
    if onAutoStop then onAutoStop('maxDuration') end
  end
end

-- Enter opens a manual span. It returns nil when nothing is being recorded; pass the result
-- to Exit either way. Any extra arguments are recorded as the span's arguments when the
-- capture records them (event and message payloads).
---@param label string
---@return number|nil token
function perf:Enter(label, ...)
  if not active then return nil end
  local sid = enter(label)
  if sid == 0 then return nil end
  if traceArgs and select('#', ...) > 0 then
    traceSetArgs(sid, describe(...))
  end
  return sid
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
  local now = vclock()
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
  sync(vclock())
end

---@return table|nil
function perf:GetLiveStats()
  if not capturing then return nil end
  local now = frozen and frozenAt or vclock()
  return {
    elapsedMs = now - startTime,
    calls = totalCalls,
    frames = frames,
    worstFrameMs = worstFrameMs,
    nodes = nodeCount,
    wrappedFunctions = #wrapped,
    traceCalls = tracing and traceCount or nil,
    traceFull = frozen,
  }
end
