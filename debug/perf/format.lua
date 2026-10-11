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

---@param session table
---@param tree PerfTree
---@return PerfFunctionStats[]
function perfFormat:DecodeFunctions(session, tree)
  local selfByName, allocByName = {}, {}
  for _, node in ipairs(tree.nodes) do
    selfByName[node.name] = (selfByName[node.name] or 0) + node.self
    allocByName[node.name] = (allocByName[node.name] or 0) + node.alloc
  end
  local out = {}
  for _, packed in ipairs(session.functions or {}) do
    local f = splitNumbers(packed)
    local name = session.names[f[1]]
    local incl = f[3] / 1000
    out[#out + 1] = {
      name = name,
      calls = f[2],
      incl = incl,
      self = selfByName[name] or 0,
      max = f[4] / 1000,
      avg = f[2] > 0 and incl / f[2] or 0,
      alloc = allocByName[name] or 0,
    }
  end
  table.sort(out, function(a, b)
    if a.self ~= b.self then return a.self > b.self end
    return a.name < b.name
  end)
  return out
end

---@class PerfFrame
---@field frame number
---@field ms number BetterBags time measured by the profiler in this frame.
---@field blizzardMs number|nil Blizzard's addon profiler reading for this frame.
---@field atMs number Milliseconds from the start of the capture.
---@field tree PerfTree

---@param session table
---@param index number
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
  for _, node in pairs(nodes) do
    table.sort(node.children, function(a, b) return a.id < b.id end)
  end
  local hasAlloc = sumTotals(nodes, maxId)
  return {
    frame = entry.frame,
    ms = entry.us / 1000,
    blizzardMs = entry.blizzardUs and entry.blizzardUs / 1000 or nil,
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

---@param session table
---@return {ours: number[], blizzard: number[]|nil}
function perfFormat:DecodeTimeline(session)
  local function decode(s)
    if s == nil then return nil end
    local out = {}
    for _, v in ipairs(splitNumbers(s)) do
      out[#out + 1] = v / 1000
    end
    return out
  end
  local timeline = session.timeline or {}
  return { ours = decode(timeline.ours) or {}, blizzard = decode(timeline.blizzard) }
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
-- microseconds, allocation values are bytes.
---@param tree PerfTree
---@param metric "time"|"alloc"
---@return string[]
function perfFormat:Folded(tree, metric)
  local lines = {}
  local function visit(node, prefix)
    for _, c in ipairs(node.children) do
      local path = prefix and (prefix .. ';' .. c.name) or c.name
      local value
      if metric == 'alloc' then
        value = math.floor(c.alloc * 1024 + 0.5)
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

---@class PerfRect
---@field node PerfNode
---@field depth number 0 for the layout root.
---@field x number Left edge as a fraction of the full width.
---@field w number Width as a fraction of the full width.

---@class PerfLayoutOptions
---@field metric "time"|"alloc"
---@field minFraction number Nodes narrower than this fraction are skipped.
---@field maxDepth? number

-- Layout places rootNode across the full width at depth 0 and every descendant inside its
-- parent, left to right, sized by its subtree total.
---@param rootNode PerfNode
---@param opts PerfLayoutOptions
---@return PerfRect[]
function perfFormat:Layout(rootNode, opts)
  local field = opts.metric == 'alloc' and 'totalAlloc' or 'total'
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
