-- PerfFormat decodes profiler sessions saved by debug/perf/engine.lua. It has no WoW
-- dependencies, so tools/flamegraph loads this same file outside the game with dofile;
-- in that case there is no addon name and the functions come back as a plain table.
local addonName = ... ---@type string|nil

---@class PerfFormat
local perfFormat
if addonName then
  ---@class BetterBags: AceAddon
  local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
  perfFormat = addon:NewModule('PerfFormat')
else
  perfFormat = {}
end

---@class PerfNode
---@field id number
---@field name string
---@field parent PerfNode|nil
---@field children PerfNode[]
---@field childByName table<string, PerfNode>
---@field self number Milliseconds spent in this node itself.
---@field calls number
---@field max number Worst single call in milliseconds.
---@field alloc number Kilobytes allocated in this node itself.
---@field total number Milliseconds in this node and everything below it.
---@field totalAlloc number Kilobytes allocated in this node and everything below it.

---@class PerfTree
---@field root PerfNode
---@field nodes PerfNode[]
---@field hasAlloc boolean

local function splitNumbers(s)
  local out = {}
  for v in string.gmatch(s, '[^,]+') do
    out[#out + 1] = tonumber(v)
  end
  return out
end

local function newNode(id, name)
  return {
    id = id,
    name = name,
    children = {},
    childByName = {},
    self = 0,
    calls = 0,
    max = 0,
    alloc = 0,
    total = 0,
    totalAlloc = 0,
  }
end

local function link(node, parent)
  node.parent = parent
  parent.children[#parent.children + 1] = node
  parent.childByName[node.name] = node
end

local function byName(a, b)
  if a.name ~= b.name then return a.name < b.name end
  return a.id < b.id
end

-- Node ids are assigned parent-first, so walking them backwards sums every subtree.
local function sumTotals(nodes, maxId)
  local hasAlloc = false
  for id = maxId, 1, -1 do
    local node = nodes[id]
    if node then
      node.total = node.total + node.self
      node.totalAlloc = node.totalAlloc + node.alloc
      if node.alloc > 0 then hasAlloc = true end
      if node.parent then
        node.parent.total = node.parent.total + node.total
        node.parent.totalAlloc = node.parent.totalAlloc + node.totalAlloc
      end
    end
  end
  return hasAlloc
end

---@param session table
---@return PerfTree
function perfFormat:Decode(session)
  local nodes = {}
  for id, packed in ipairs(session.nodes) do
    local f = splitNumbers(packed)
    local node = newNode(id, session.names[f[2]])
    node.self = f[3] / 1000
    node.calls = f[4]
    node.max = f[5] / 1000
    node.alloc = f[6] / 1024
    nodes[id] = node
    if f[1] > 0 then
      link(node, nodes[f[1]])
    end
  end
  -- From format version 3 node ids are creation order; earlier sessions stored them
  -- already sorted by name.
  if (session.formatVersion or 1) >= 3 then
    for _, node in ipairs(nodes) do
      table.sort(node.children, byName)
    end
  end
  local hasAlloc = sumTotals(nodes, #nodes)
  return { root = nodes[1], nodes = nodes, hasAlloc = hasAlloc }
end

---@class PerfFunctionStats
---@field name string
---@field calls number
---@field incl number Milliseconds, counting recursive calls once.
---@field self number
---@field max number
---@field avg number
---@field alloc number
---@field adjIncl? number Inclusive time with profiler overhead removed (adjusted trees only).
---@field adjSelf? number
---@field adjAvg? number
---@field overheadShare? number Fraction of the raw inclusive time that was profiler overhead.

-- DecodeFunctions summarizes the session per function. On a tree that went through Adjust
-- it also reports overhead-adjusted times, summed over each function's outermost nodes so
-- recursion is counted once.
---@param session table
---@param tree PerfTree
---@return PerfFunctionStats[]
function perfFormat:DecodeFunctions(session, tree)
  local selfByName, allocByName, adjSelfByName = {}, {}, {}
  for _, node in ipairs(tree.nodes) do
    selfByName[node.name] = (selfByName[node.name] or 0) + node.self
    allocByName[node.name] = (allocByName[node.name] or 0) + node.alloc
    if tree.adjusted then
      adjSelfByName[node.name] = (adjSelfByName[node.name] or 0) + node.adjSelf
    end
  end
  local rawInclByName, adjInclByName = {}, {}
  if tree.adjusted then
    local onPath = {}
    local function visit(node)
      local outermost = not onPath[node.name]
      if outermost then
        rawInclByName[node.name] = (rawInclByName[node.name] or 0) + node.total
        adjInclByName[node.name] = (adjInclByName[node.name] or 0) + node.adjTotal
        onPath[node.name] = true
      end
      for _, c in ipairs(node.children) do
        visit(c)
      end
      if outermost then
        onPath[node.name] = nil
      end
    end
    visit(tree.root)
  end
  local out = {}
  for _, packed in ipairs(session.functions or {}) do
    local f = splitNumbers(packed)
    local name = session.names[f[1]]
    local incl = f[3] / 1000
    local fn = {
      name = name,
      calls = f[2],
      incl = incl,
      self = selfByName[name] or 0,
      max = f[4] / 1000,
      avg = f[2] > 0 and incl / f[2] or 0,
      alloc = allocByName[name] or 0,
    }
    if tree.adjusted then
      local raw = rawInclByName[name] or 0
      fn.adjIncl = adjInclByName[name] or 0
      fn.adjSelf = adjSelfByName[name] or 0
      fn.adjAvg = fn.calls > 0 and fn.adjIncl / fn.calls or 0
      fn.overheadShare = raw > 0 and (raw - fn.adjIncl) / raw or 0
    end
    out[#out + 1] = fn
  end
  table.sort(out, function(a, b)
    if a.self ~= b.self then return a.self > b.self end
    return a.name < b.name
  end)
  return out
end

-- Sessions before format version 2 stored, on each worst frame, Blizzard's reading taken
-- in that same frame. That reading usually describes the previous frame's work (see
-- considerFrame in engine.lua), so those sessions are re-paired from their per-frame
-- timeline with the rule the engine now applies while capturing.
local pairingCache = setmetatable({}, { __mode = 'k' })

---@param session table
---@return (fun(frame: number): number|nil)|nil
local function oldSessionPairing(session)
  if (session.formatVersion or 1) >= 2 then return nil end
  local cached = pairingCache[session]
  if cached ~= nil then return cached or nil end
  local timeline = session.timeline
  if not timeline or not timeline.ours or not timeline.blizzard then
    pairingCache[session] = false
    return nil
  end
  local ours = splitNumbers(timeline.ours)
  local blizzard = splitNumbers(timeline.blizzard)
  -- The reading taken at the end of frame f is blizzard[f + 1]; ours[f + 1] is frame f.
  local function creditedTo(f)
    local reading = blizzard[f + 1]
    local previous = ours[f]
    if previous and math.abs(previous - reading) < math.abs((ours[f + 1] or 0) - reading) then
      return f - 1
    end
    return f
  end
  local pairing = function(frame)
    if not ours[frame + 1] or not blizzard[frame + 1] then return nil end
    local sum = 0
    if creditedTo(frame) == frame then sum = sum + blizzard[frame + 1] end
    if blizzard[frame + 2] and creditedTo(frame + 1) == frame then sum = sum + blizzard[frame + 2] end
    return sum / 1000
  end
  pairingCache[session] = pairing
  return pairing
end

-- blizzardFor returns Blizzard's reading for a worst frame and whether it was re-paired.
---@param session table
---@param entry table
---@return number|nil blizzardMs
---@return boolean repaired
local function blizzardFor(session, entry)
  local pairing = oldSessionPairing(session)
  local paired = pairing and pairing(entry.frame)
  if paired then return paired, true end
  return entry.blizzardUs and entry.blizzardUs / 1000 or nil, false
end

---@class PerfWorstFrame
---@field index number Position in session.worst, for DecodeFrame.
---@field frame number
---@field ms number
---@field blizzardMs number|nil Blizzard's reading credited to this frame.
---@field atMs number

-- WorstFrames lists the worst frames to show, worst first. Frames of an older session
-- that only qualified on a Blizzard reading belonging to another frame are left out.
---@param session table
---@return PerfWorstFrame[]
function perfFormat:WorstFrames(session)
  local threshold = (session.options and session.options.spikeThresholdMs) or 16
  local out = {}
  for i, entry in ipairs(session.worst or {}) do
    local ms = entry.us / 1000
    local blizzardMs, repaired = blizzardFor(session, entry)
    local rank = math.max(ms, blizzardMs or 0)
    if not repaired or rank >= threshold then
      out[#out + 1] = { index = i, frame = entry.frame, ms = ms, blizzardMs = blizzardMs, atMs = entry.atUs / 1000, rank = rank }
    end
  end
  table.sort(out, function(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    return a.index < b.index
  end)
  return out
end

---@class PerfFrame
---@field frame number
---@field ms number BetterBags time measured by the profiler in this frame.
---@field blizzardMs number|nil Blizzard's addon profiler reading credited to this frame.
---@field atMs number Milliseconds from the start of the capture.
---@field tree PerfTree

---@param session table
---@param index number Position in session.worst.
---@return PerfFrame
function perfFormat:DecodeFrame(session, index)
  local entry = session.worst[index]
  local parents, names = {}, {}
  for id, packed in ipairs(session.nodes) do
    local parentId, nameId = string.match(packed, '^(%d+),(%d+),')
    parents[id] = tonumber(parentId)
    names[id] = session.names[tonumber(nameId)]
  end
  local nodes, maxId = {}, 0
  for _, packed in ipairs(entry.nodes) do
    local f = splitNumbers(packed)
    local node = newNode(f[1], names[f[1]])
    node.self = f[2] / 1000
    node.calls = f[3]
    node.alloc = f[4] / 1024
    nodes[f[1]] = node
    if f[1] > maxId then maxId = f[1] end
  end
  -- A frame only records the nodes that ran in it; ancestors that were already on the
  -- stack from an earlier frame are filled in with zero cost so the tree stays connected.
  local ids = {}
  for id in pairs(nodes) do ids[#ids + 1] = id end
  for _, id in ipairs(ids) do
    local parentId = parents[id]
    while parentId and parentId > 0 and not nodes[parentId] do
      nodes[parentId] = newNode(parentId, names[parentId])
      parentId = parents[parentId]
    end
  end
  for id, node in pairs(nodes) do
    local parent = nodes[parents[id]]
    if parent then link(node, parent) end
  end
  if not nodes[1] then
    nodes[1] = newNode(1, names[1])
  end
  if maxId < 1 then maxId = 1 end
  local sortByName = (session.formatVersion or 1) >= 3
  for _, node in pairs(nodes) do
    table.sort(node.children, sortByName and byName or function(a, b) return a.id < b.id end)
  end
  local hasAlloc = sumTotals(nodes, maxId)
  return {
    frame = entry.frame,
    ms = entry.us / 1000,
    blizzardMs = (blizzardFor(session, entry)),
    atMs = entry.atUs / 1000,
    tree = { root = nodes[1], nodes = nodes, hasAlloc = hasAlloc },
  }
end

-- DecodeAborted lists the calls an error cut short, most frequent first.
---@param session table
---@return {name: string, count: number}[]
function perfFormat:DecodeAborted(session)
  local out = {}
  for _, packed in ipairs(session.aborted or {}) do
    local f = splitNumbers(packed)
    out[#out + 1] = { name = session.names[f[1]], count = f[2] }
  end
  table.sort(out, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  return out
end

-- DecodeTimeline returns the per-frame series in milliseconds and, when the session
-- recorded them, each frame's measured calls and how many of those were made from inside
-- another measured call.
---@param session table
---@return {ours: number[], blizzard: number[]|nil, calls: number[]|nil, nested: number[]|nil}
function perfFormat:DecodeTimeline(session)
  local function decode(s, scale)
    if s == nil then return nil end
    local out = {}
    for _, v in ipairs(splitNumbers(s)) do
      out[#out + 1] = v / scale
    end
    return out
  end
  local timeline = session.timeline or {}
  return {
    ours = decode(timeline.ours, 1000) or {},
    blizzard = decode(timeline.blizzard, 1000),
    calls = decode(timeline.calls, 1),
    nested = decode(timeline.nested, 1),
  }
end

---------------------------------------------------------------------------------------
-- Call trace (format version 3)
---------------------------------------------------------------------------------------

-- Call flags, as recorded by the engine.
perfFormat.CALL_ABORTED = 1
perfFormat.CALL_UNFINISHED = 2
perfFormat.CALL_PAUSED = 4

local RECORD = 6
local DECODED_CHUNKS_KEPT = 8

local function hasFlag(flags, flag)
  return math.floor(flags / flag) % 2 == 1
end

---@class PerfTraceSegment
---@field pausedAt number Milliseconds from the start of the capture.
---@field resumedAt number
---@field node number Node the call continued under after resuming.

---@class PerfTraceCall
---@field index number Position in start order, from 1.
---@field start number Milliseconds from the start of the capture.
---@field finish number
---@field wall number finish - start, including any time the call was paused.
---@field incl number wall without paused time.
---@field node number
---@field name string
---@field depth number 1 for a call with no measured caller.
---@field args number Argument set id; 0 when none was recorded.
---@field returns number Return value set id; 0 when none was recorded.
---@field flags number
---@field aborted boolean
---@field unfinished boolean
---@field paused boolean
---@field segments PerfTraceSegment[]|nil

---@class PerfTraceSlice
---@field call PerfTraceCall
---@field node number
---@field name string
---@field depth number
---@field start number
---@field finish number

---@class PerfTrace
local traceProto = {}

local traceCache = setmetatable({}, { __mode = 'k' })

-- OpenTrace returns an accessor over a session's call trace, or nil when the session has
-- none. Chunks are decoded on demand and the last few are kept.
---@param session table|nil
---@return PerfTrace|nil
function perfFormat:OpenTrace(session)
  local tr = session and session.trace
  if not tr or not tr.chunks then return nil end
  local cached = traceCache[session]
  if cached then return cached end

  local parents, nameIds, depths = {}, {}, {}
  for id, packedNode in ipairs(session.nodes) do
    local parentId, nameId = string.match(packedNode, '^(%d+),(%d+),')
    parents[id] = tonumber(parentId)
    nameIds[id] = tonumber(nameId)
    local p = parents[id]
    depths[id] = (p and p > 0) and ((depths[p] or 0) + 1) or 0
  end

  local segmentsByCall = {}
  local flat = splitNumbers(tr.segments or '')
  for i = 1, #flat, 4 do
    local index = flat[i]
    local list = segmentsByCall[index]
    if not list then
      list = {}
      segmentsByCall[index] = list
    end
    list[#list + 1] = { pausedAt = flat[i + 1] / 1000, resumedAt = flat[i + 2] / 1000, node = flat[i + 3] }
  end

  local trace = setmetatable({
    session = session,
    names = session.names,
    nameIds = nameIds,
    depths = depths,
    chunkSize = tr.chunkSize,
    count = tr.calls or 0,
    chunks = tr.chunks,
    chunkStarts = splitNumbers(tr.chunkStarts or ''),
    chunkEnds = splitNumbers(tr.chunkEnds or ''),
    frameEnds = splitNumbers(tr.frameEnds or ''),
    segments = segmentsByCall,
    values = tr.values or {},
    sets = tr.sets or {},
    full = tr.full == true,
    hasArgs = tr.args == true,
    decoded = {},
    decodedOrder = {},
    texts = {},
  }, { __index = traceProto })
  traceCache[session] = trace
  return trace
end

---@return number
function traceProto:Count()
  return self.count
end

-- Chunk decodes one packed chunk into parallel arrays of absolute values.
---@param ci number
---@return table|nil
function traceProto:Chunk(ci)
  local d = self.decoded[ci]
  if d then return d end
  local packedChunk = self.chunks[ci]
  if not packedChunk then return nil end
  local f = splitNumbers(packedChunk)
  local n = #f / RECORD
  d = { n = n, starts = {}, nodes = {}, args = {}, walls = {}, returns = {}, flags = {} }
  local s = self.chunkStarts[ci] or 0
  for i = 1, n do
    local o = (i - 1) * RECORD
    s = s + f[o + 1]
    d.starts[i] = s
    d.nodes[i] = f[o + 2]
    d.args[i] = f[o + 3]
    d.walls[i] = f[o + 4]
    d.returns[i] = f[o + 5]
    d.flags[i] = f[o + 6]
  end
  self.decoded[ci] = d
  local order = self.decodedOrder
  order[#order + 1] = ci
  if #order > DECODED_CHUNKS_KEPT then
    self.decoded[table.remove(order, 1)] = nil
  end
  return d
end

---@param index number
---@return PerfTraceCall|nil
function traceProto:Get(index)
  if index < 1 or index > self.count then return nil end
  local ci = math.floor((index - 1) / self.chunkSize) + 1
  local d = self:Chunk(ci)
  if not d then return nil end
  local k = index - (ci - 1) * self.chunkSize
  local start, wall = d.starts[k] / 1000, d.walls[k] / 1000
  local node, flags = d.nodes[k], d.flags[k]
  local segments = self.segments[index]
  local paused = 0
  if segments then
    for _, seg in ipairs(segments) do
      paused = paused + (seg.resumedAt - seg.pausedAt)
    end
  end
  return {
    index = index,
    start = start,
    finish = start + wall,
    wall = wall,
    incl = wall - paused,
    node = node,
    name = self.names[self.nameIds[node]] or '?',
    depth = self.depths[node] or 0,
    args = d.args[k],
    returns = d.returns[k],
    flags = flags,
    aborted = hasFlag(flags, perfFormat.CALL_ABORTED),
    unfinished = hasFlag(flags, perfFormat.CALL_UNFINISHED),
    paused = hasFlag(flags, perfFormat.CALL_PAUSED),
    segments = segments,
  }
end

-- Text joins the descriptions of an argument or return value set; nil when nothing was
-- recorded for the call.
---@param setId number|nil
---@return string|nil
function traceProto:Text(setId)
  if not setId or setId == 0 then return nil end
  local cached = self.texts[setId]
  if cached then return cached end
  local spec = self.sets[setId]
  if not spec then return nil end
  local parts = {}
  for id in string.gmatch(spec, '%d+') do
    parts[#parts + 1] = self.values[tonumber(id)] or '?'
  end
  local text = table.concat(parts, ', ')
  self.texts[setId] = text
  return text
end

-- NodeName and NodeDepth describe a node id from the session's call tree.
---@param node number
---@return string
function traceProto:NodeName(node)
  return self.names[self.nameIds[node]] or '?'
end

---@param node number
---@return number
function traceProto:NodeDepth(node)
  return self.depths[node] or 0
end

-- Slices lists what ran between fromMs and toMs, one slice per uninterrupted stretch of a
-- call: a call that paused (a coroutine that yielded) has one slice before each pause and
-- one after, under the node it resumed under. Slices shorter than minMs are skipped.
---@param fromMs number
---@param toMs number
---@param minMs? number
---@return PerfTraceSlice[]
function traceProto:Slices(fromMs, toMs, minMs)
  local out = {}
  local fromUs, toUs = fromMs * 1000, toMs * 1000
  local minUs = (minMs or 0) * 1000
  for ci = 1, #self.chunks do
    local cs, ce = self.chunkStarts[ci], self.chunkEnds[ci]
    if cs and cs > toUs then break end
    if cs and ce and ce >= fromUs then
      local d = self:Chunk(ci)
      for k = 1, d.n do
        local s = d.starts[k]
        if s > toUs then break end
        local e = s + d.walls[k]
        if e >= fromUs and e - s >= minUs then
          local index = (ci - 1) * self.chunkSize + k
          local call = self:Get(index)
          local segs = call.segments
          local pieces = {}
          if segs then
            local pieceStart, pieceNode = call.start, call.node
            for _, seg in ipairs(segs) do
              pieces[#pieces + 1] = { pieceStart, seg.pausedAt, pieceNode }
              pieceStart, pieceNode = seg.resumedAt, seg.node
            end
            pieces[#pieces + 1] = { pieceStart, call.finish, pieceNode }
          else
            pieces[1] = { call.start, call.finish, call.node }
          end
          for _, piece in ipairs(pieces) do
            if piece[2] >= fromMs and piece[1] <= toMs and piece[2] >= piece[1] then
              out[#out + 1] = {
                call = call,
                node = piece[3],
                name = self:NodeName(piece[3]),
                depth = self:NodeDepth(piece[3]),
                start = piece[1],
                finish = piece[2],
              }
            end
          end
        end
      end
    end
  end
  return out
end

---@return number
function traceProto:FrameCount()
  return #self.frameEnds
end

-- FrameOf returns the frame a moment falls in: frame n ends at the n-th frame boundary.
-- Moments after the last boundary are in the frame that was still running at stop.
---@param ms number
---@return number
function traceProto:FrameOf(ms)
  local us = ms * 1000
  local ends = self.frameEnds
  local lo, hi = 1, #ends
  if hi == 0 or us > ends[hi] then return hi + 1 end
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if ends[mid] >= us then
      hi = mid
    else
      lo = mid + 1
    end
  end
  return lo
end

-- FrameBounds returns when a frame started and ended, in milliseconds.
---@param frame number
---@return number fromMs
---@return number toMs
function traceProto:FrameBounds(frame)
  local ends = self.frameEnds
  local from = frame > 1 and (ends[frame - 1] or ends[#ends] or 0) / 1000 or 0
  local to = ends[frame] and ends[frame] / 1000 or ((self.session.stats and self.session.stats.durationMs) or from)
  return from, to
end

-- Matches tells whether a call's function name, arguments or return values contain the
-- query, ignoring case. query must already be lower case.
---@param call PerfTraceCall
---@param query string
---@return boolean
function traceProto:Matches(call, query)
  if string.find(string.lower(call.name), query, 1, true) then return true end
  local args = self:Text(call.args)
  if args and string.find(string.lower(args), query, 1, true) then return true end
  local returns = self:Text(call.returns)
  return returns ~= nil and string.find(string.lower(returns), query, 1, true) ~= nil
end

-- TraceBytes estimates how much of the SavedVariables file a session's trace takes.
---@param session table
---@return number
function perfFormat:TraceBytes(session)
  local tr = session and session.trace
  if not tr then return 0 end
  local total = 0
  for _, chunk in ipairs(tr.chunks or {}) do
    total = total + #chunk
  end
  for _, text in ipairs(tr.values or {}) do
    total = total + #text
  end
  for _, spec in ipairs(tr.sets or {}) do
    total = total + #spec
  end
  return total + #(tr.segments or '') + #(tr.frameEnds or '') + #(tr.chunkStarts or '') + #(tr.chunkEnds or '')
end

---@class PerfOverhead
---@field parentMs number Profiler cost per measured call that lands on the caller.
---@field childMs number Profiler cost per measured call that lands on the called function.
---@field approximate boolean True for older sessions that only stored a single per-call cost.

-- Overhead reads the per-call profiler cost measured when the capture started. Older
-- sessions stored only the total per call; it is split evenly, which matches what the
-- split calibration measures, and marked approximate.
---@param session table
---@return PerfOverhead|nil
function perfFormat:Overhead(session)
  local stats = session.stats or {}
  if stats.overheadParentMs and stats.overheadChildMs then
    return { parentMs = stats.overheadParentMs, childMs = stats.overheadChildMs, approximate = false }
  end
  if stats.overheadPerCallMs and stats.overheadPerCallMs > 0 then
    local half = stats.overheadPerCallMs / 2
    return { parentMs = half, childMs = half, approximate = true }
  end
  return nil
end

-- Adjust removes the estimated profiler cost from a decoded tree. Each measured call costs
-- childMs on its own node and parentMs on its caller, so a node's own time loses
-- calls x childMs plus its children's calls x parentMs, never going below zero. It sets
-- adjSelf, adjTotal, and overheadShare (the fraction of the raw subtree total that was
-- overhead) on every node.
---@param tree PerfTree
---@param overhead PerfOverhead
function perfFormat:Adjust(tree, overhead)
  local parentMs, childMs = overhead.parentMs, overhead.childMs
  local function visit(node)
    local childCalls, childTotal = 0, 0
    for _, c in ipairs(node.children) do
      childCalls = childCalls + c.calls
      childTotal = childTotal + visit(c)
    end
    local adjSelf = node.self - node.calls * childMs - childCalls * parentMs
    if adjSelf < 0 then adjSelf = 0 end
    node.adjSelf = adjSelf
    node.adjTotal = adjSelf + childTotal
    node.overheadShare = node.total > 0 and (node.total - node.adjTotal) / node.total or 0
    return node.adjTotal
  end
  visit(tree.root)
  tree.adjusted = true
end

-- AdjustTimeline removes the estimated profiler cost from per-frame times, the same way
-- Adjust does for a tree: childMs for every call, parentMs only for calls made from inside
-- another measured call. Returns nil for sessions that did not record call counts.
---@param timeline {ours: number[], calls: number[]|nil, nested: number[]|nil}
---@param overhead PerfOverhead
---@return number[]|nil
function perfFormat:AdjustTimeline(timeline, overhead)
  local calls, nested = timeline.calls, timeline.nested
  if not calls or not nested then return nil end
  local out = {}
  for i, ms in ipairs(timeline.ours) do
    local v = ms - (calls[i] or 0) * overhead.childMs - (nested[i] or 0) * overhead.parentMs
    out[i] = v > 0 and v or 0
  end
  return out
end

---@param tree PerfTree
---@param path string[]
---@return PerfNode|nil
function perfFormat:Find(tree, path)
  local node = tree.root
  for _, name in ipairs(path) do
    node = node and node.childByName[name]
  end
  return node
end

-- PathOf names a node's ancestry, top of the tree first, without the [all] root.
---@param node PerfNode
---@return string[]
function perfFormat:PathOf(node)
  local path = {}
  while node and node.parent do
    table.insert(path, 1, node.name)
    node = node.parent
  end
  return path
end

-- Folded renders the tree in the collapsed-stack format read by flamegraph.pl, inferno
-- and speedscope: one "a;b;c value" line per node with a non-zero value. Time values are
-- microseconds ("adjusted" uses the overhead-adjusted self time), allocation values are
-- bytes.
---@param tree PerfTree
---@param metric "time"|"adjusted"|"alloc"
---@return string[]
function perfFormat:Folded(tree, metric)
  local lines = {}
  local function visit(node, prefix)
    for _, c in ipairs(node.children) do
      local path = prefix and (prefix .. ';' .. c.name) or c.name
      local value
      if metric == 'alloc' then
        value = math.floor(c.alloc * 1024 + 0.5)
      elseif metric == 'adjusted' then
        value = math.floor(c.adjSelf * 1000 + 0.5)
      else
        value = math.floor(c.self * 1000 + 0.5)
      end
      if value > 0 then
        lines[#lines + 1] = path .. ' ' .. value
      end
      visit(c, path)
    end
  end
  visit(tree.root, nil)
  return lines
end

-- TOTAL_FIELD and SELF_FIELD name the node fields that hold each metric.
perfFormat.TOTAL_FIELD = { time = 'total', adjusted = 'adjTotal', alloc = 'totalAlloc' }
perfFormat.SELF_FIELD = { time = 'self', adjusted = 'adjSelf', alloc = 'alloc' }

---@class PerfRect
---@field node PerfNode
---@field depth number 0 for the layout root.
---@field x number Left edge as a fraction of the full width.
---@field w number Width as a fraction of the full width.

---@class PerfLayoutOptions
---@field metric "time"|"adjusted"|"alloc"
---@field minFraction number Nodes narrower than this fraction are skipped.
---@field maxDepth? number

-- Layout places rootNode across the full width at depth 0 and every descendant inside its
-- parent, left to right, sized by its subtree total.
---@param rootNode PerfNode
---@param opts PerfLayoutOptions
---@return PerfRect[]
function perfFormat:Layout(rootNode, opts)
  local field = perfFormat.TOTAL_FIELD[opts.metric] or 'total'
  local denom = rootNode[field]
  local rects = {}
  if not denom or denom <= 0 then return rects end
  local minFraction = opts.minFraction or 0
  local maxDepth = opts.maxDepth
  local function place(node, depth, x)
    local w = node[field] / denom
    if w <= 0 or w < minFraction then return end
    rects[#rects + 1] = { node = node, depth = depth, x = x, w = w }
    if maxDepth and depth >= maxDepth then return end
    local acc = 0
    for _, c in ipairs(node.children) do
      place(c, depth + 1, x + acc / denom)
      acc = acc + c[field]
    end
  end
  place(rootNode, 0, 0)
  return rects
end

---@param ms number
---@return string
function perfFormat:Ms(ms)
  if ms >= 1000 then return string.format('%.2f s', ms / 1000) end
  if ms >= 100 then return string.format('%.0f ms', ms) end
  if ms >= 10 then return string.format('%.1f ms', ms) end
  if ms >= 0.1 then return string.format('%.2f ms', ms) end
  return string.format('%.3f ms', ms)
end

---@param n number
---@return string
function perfFormat:Count(n)
  local s = tostring(math.floor(n))
  local out = string.gsub(string.reverse(s), '(%d%d%d)', '%1,')
  out = string.reverse(out)
  return (string.gsub(out, '^(-?),', '%1'))
end

---@param kb number
---@return string
function perfFormat:KB(kb)
  if kb >= 1024 then return string.format('%.1f MB', kb / 1024) end
  return string.format('%.1f KB', kb)
end

return perfFormat
