-- flamegraph.lua turns BetterBags profiler sessions saved in SavedVariables into flame
-- graphs. Run it with Lua 5.1 from anywhere:
--
--   lua tools/flamegraph/flamegraph.lua <WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua> [options]
--
-- See tools/flamegraph/README.md for the options and outputs.

local M = {}

local scriptDir = string.match(debug.getinfo(1, 'S').source, '^@(.*)[/\\]') or '.'
local perfFormat = dofile(scriptDir .. '/../../debug/perf/format.lua')

local USAGE = {
  'Usage: lua tools/flamegraph/flamegraph.lua <SavedVariables/BetterBags.lua> [options]',
  '  --list                 list the saved sessions and exit',
  '  --session <id|latest>  session to export (default: latest)',
  '  --frame <n>            export the n-th worst frame instead of the whole session',
  '  --metric <time|alloc>  size bars by time (default) or allocated memory',
  '  --out <dir>            directory for the output files (default: .)',
}

-- LoadSavedVariables runs the SavedVariables file in an empty environment, so nothing it
-- assigns leaks into this process's globals.
---@param path string
---@return table|nil db
---@return string|nil err
function M.LoadSavedVariables(path)
  local chunk, err = loadfile(path)
  if not chunk then return nil, err end
  local env = {}
  setfenv(chunk, env)
  local ok, runErr = pcall(chunk)
  if not ok then return nil, runErr end
  if type(env.BetterBagsPerfDB) ~= 'table' or type(env.BetterBagsPerfDB.sessions) ~= 'table' then
    return nil, 'no BetterBagsPerfDB sessions in ' .. path
  end
  return env.BetterBagsPerfDB
end

---@param db table
---@param which string|nil "latest" or a session id
---@return table|nil
function M.FindSession(db, which)
  local sessions = db.sessions
  if which == nil or which == 'latest' then
    return sessions[#sessions]
  end
  local id = tonumber(which)
  for _, session in ipairs(sessions) do
    if session.id == id then return session end
  end
  return nil
end

---@param db table
---@return string[]
function M.ListSessions(db)
  local lines = {}
  for i = #db.sessions, 1, -1 do
    local s = db.sessions[i]
    local meta, stats = s.meta or {}, s.stats or {}
    lines[#lines + 1] = string.format('#%d  %s  %s - %s  %s  measured %s  %d frames  %d worst frames%s',
      s.id or 0, meta.startedAt and os.date('%Y-%m-%d %H:%M:%S', meta.startedAt) or '?',
      meta.character or '?', meta.realm or '?', perfFormat:Ms(stats.durationMs or 0),
      perfFormat:Ms(stats.instrumentedMs or 0), stats.frames or 0, #(s.worst or {}),
      meta.reason == 'reload' and '  (reload)' or '')
  end
  return lines
end

-- Tree decodes a whole session, or one of its worst frames when frameIndex is given.
---@param session table
---@param frameIndex number|nil
---@return PerfTree
function M.Tree(session, frameIndex)
  if frameIndex then
    return perfFormat:DecodeFrame(session, frameIndex).tree
  end
  return perfFormat:Decode(session)
end

---@param tree PerfTree
---@param metric "time"|"alloc"
---@return string
function M.Folded(tree, metric)
  local lines = perfFormat:Folded(tree, metric)
  if #lines == 0 then return '' end
  return table.concat(lines, '\n') .. '\n'
end

local function isArray(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  for i = 1, n do
    if t[i] == nil then return false end
  end
  return true
end

local function encodeString(s)
  s = string.gsub(s, '[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    if c == '\n' then return '\\n' end
    if c == '\t' then return '\\t' end
    return string.format('\\u%04x', string.byte(c))
  end)
  return '"' .. s .. '"'
end

-- encodeJSON writes compact JSON. orderedKeys fixes the key order of objects that have it,
-- so output is stable.
local function encodeJSON(value, orderedKeys)
  local t = type(value)
  if t == 'string' then return encodeString(value) end
  if t == 'number' then
    if value == math.floor(value) then return string.format('%d', value) end
    return string.format('%.6g', value)
  end
  if t == 'boolean' then return value and 'true' or 'false' end
  if t == 'nil' then return 'null' end
  if isArray(value) then
    local out = {}
    for i, v in ipairs(value) do out[i] = encodeJSON(v, orderedKeys) end
    return '[' .. table.concat(out, ',') .. ']'
  end
  local keys = {}
  if orderedKeys then
    for _, k in ipairs(orderedKeys) do
      if value[k] ~= nil then keys[#keys + 1] = k end
    end
  else
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys)
  end
  local out = {}
  for _, k in ipairs(keys) do
    out[#out + 1] = encodeString(k) .. ':' .. encodeJSON(value[k], orderedKeys)
  end
  return '{' .. table.concat(out, ',') .. '}'
end

local SPEEDSCOPE_KEYS = {
  '$schema', 'name', 'exporter', 'activeProfileIndex', 'shared', 'frames', 'profiles',
  'type', 'unit', 'startValue', 'endValue', 'samples', 'weights',
}

local function value(node, metric)
  if metric == 'alloc' then return math.floor(node.alloc * 1024 + 0.5) end
  return math.floor(node.self * 1000 + 0.5)
end

-- Speedscope renders the tree as a speedscope "sampled" profile: every node with a value
-- becomes one sample whose stack runs from the top of the tree down to it, weighted by
-- its self time (microseconds) or its allocations (bytes).
---@param tree PerfTree
---@param metric "time"|"alloc"
---@param name string
---@return string
function M.Speedscope(tree, metric, name)
  local frames, frameIndex = {}, {}
  local samples, weights = {}, {}
  local total = 0
  local stack = {}
  local function visit(node)
    for _, c in ipairs(node.children) do
      local index = frameIndex[c.name]
      if not index then
        index = #frames
        frames[#frames + 1] = { name = c.name }
        frameIndex[c.name] = index
      end
      stack[#stack + 1] = index
      local v = value(c, metric)
      if v > 0 then
        local sample = {}
        for i, f in ipairs(stack) do sample[i] = f end
        samples[#samples + 1] = sample
        weights[#weights + 1] = v
        total = total + v
      end
      visit(c)
      stack[#stack] = nil
    end
  end
  visit(tree.root)
  return encodeJSON({
    ['$schema'] = 'https://www.speedscope.app/file-format-schema.json',
    name = name,
    exporter = 'BetterBags tools/flamegraph',
    activeProfileIndex = 0,
    shared = { frames = frames },
    profiles = {
      {
        type = 'sampled',
        name = name,
        unit = metric == 'alloc' and 'bytes' or 'microseconds',
        startValue = 0,
        endValue = total,
        samples = samples,
        weights = weights,
      },
    },
  }, SPEEDSCOPE_KEYS)
end

local function escapeHtml(s)
  return (string.gsub(s, '[&<>"]', { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }))
end

local function htmlNode(node, metric)
  local field = metric == 'alloc' and 'totalAlloc' or 'total'
  local selfField = metric == 'alloc' and 'alloc' or 'self'
  local scale = metric == 'alloc' and 1024 or 1000
  local out = {
    n = node.name,
    t = math.floor(node[field] * scale + 0.5),
    s = math.floor(node[selfField] * scale + 0.5),
    c = node.calls,
    m = math.floor(node.max * 1000 + 0.5),
  }
  local children = {}
  for _, c in ipairs(node.children) do
    if c[field] > 0 then
      children[#children + 1] = htmlNode(c, metric)
    end
  end
  if #children > 0 then out.k = children end
  return out
end

local HTML_TEMPLATE = [==[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>%TITLE%</title>
<style>
body { font: 12px -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; margin: 0; background: #1d1d22; color: #ddd; }
header { padding: 8px 12px; display: flex; gap: 12px; align-items: center; background: #26262c; }
h1 { font-size: 14px; margin: 0; font-weight: 600; white-space: nowrap; }
#crumb { flex: 1; color: #aaa; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
input { background: #111; color: #eee; border: 1px solid #444; padding: 3px 6px; }
button { background: #333; color: #eee; border: 1px solid #555; padding: 3px 8px; cursor: pointer; }
#chart { position: relative; margin: 8px 12px; }
.bar { position: absolute; height: 17px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis;
  font-size: 11px; line-height: 17px; padding: 0 3px; box-sizing: border-box; color: #111; cursor: pointer;
  border-right: 1px solid #1d1d22; }
.bar.dim { opacity: 0.25; }
#tip { position: fixed; pointer-events: none; background: rgba(0, 0, 0, 0.85); color: #eee; padding: 6px 8px;
  border: 1px solid #555; display: none; white-space: pre; }
#summary { margin: 8px 12px; color: #aaa; white-space: pre-wrap; }
</style>
</head>
<body>
<header><h1>%TITLE%</h1><span id="crumb"></span><input id="search" placeholder="Search"><button id="reset">Reset zoom</button></header>
<div id="chart"></div>
<div id="tip"></div>
<pre id="summary">%SUMMARY%</pre>
<script>
var DATA = %DATA%;
(function () {
  var ROW = 18;
  var root = DATA.root, zoom = root, query = '';
  var chart = document.getElementById('chart');
  var crumb = document.getElementById('crumb');
  var tip = document.getElementById('tip');
  var search = document.getElementById('search');
  function link(n, p) { n.p = p; (n.k || []).forEach(function (c) { link(c, n); }); }
  link(root, null);
  function hash(s) { var h = 0; for (var i = 0; i < s.length; i++) { h = (h * 31 + s.charCodeAt(i)) | 0; } return Math.abs(h); }
  function color(n) {
    var kind = n.n.match(/^\[(\w+)/);
    if (kind) { return { event: '#4d85d9', msg: '#6b9ee6', bucket: '#4daeb8', script: '#8c73d9', all: '#66666e' }[kind[1]] || '#808088'; }
    var mod = n.n.split('.')[0];
    return 'hsl(' + (10 + hash(mod) % 40) + ',75%,' + (50 + hash(mod + '.') % 15) + '%)';
  }
  function fmtTime(us) {
    var ms = us / 1000;
    if (ms >= 1000) return (ms / 1000).toFixed(2) + ' s';
    if (ms >= 100) return ms.toFixed(0) + ' ms';
    if (ms >= 10) return ms.toFixed(1) + ' ms';
    if (ms >= 0.1) return ms.toFixed(2) + ' ms';
    return ms.toFixed(3) + ' ms';
  }
  function fmt(v) {
    if (DATA.unit !== 'bytes') return fmtTime(v);
    return v >= 1048576 ? (v / 1048576).toFixed(1) + ' MB' : (v / 1024).toFixed(1) + ' KB';
  }
  function matches(n) { return query !== '' && n.n.toLowerCase().indexOf(query) >= 0; }
  function matchTotal(n) {
    if (matches(n)) return n.t;
    var s = 0; (n.k || []).forEach(function (c) { s += matchTotal(c); }); return s;
  }
  function path(n) { var out = []; while (n && n.p) { out.unshift(n.n); n = n.p; } return out; }
  function showTip(e, n) {
    var lines = [n.n, 'Total: ' + fmt(n.t) + ' (' + (n.t / zoom.t * 100).toFixed(1) + '% of view)', 'Self: ' + fmt(n.s), 'Calls: ' + n.c];
    if (n.m) lines.push('Slowest call: ' + fmtTime(n.m));
    tip.textContent = lines.join('\n');
    tip.style.left = (e.clientX + 12) + 'px';
    tip.style.top = (e.clientY + 12) + 'px';
    tip.style.display = 'block';
  }
  function render() {
    chart.innerHTML = '';
    var width = chart.clientWidth, maxDepth = 0, total = zoom.t;
    if (!total) { chart.textContent = 'Nothing measured.'; return; }
    function place(n, depth, x) {
      var w = n.t / total * width;
      if (w < 1) return;
      if (depth > maxDepth) maxDepth = depth;
      var d = document.createElement('div');
      d.className = 'bar' + (query !== '' && !matches(n) ? ' dim' : '');
      d.style.left = x + 'px';
      d.style.top = depth * ROW + 'px';
      d.style.width = w + 'px';
      d.style.background = color(n);
      if (w > 30) d.textContent = n.n;
      d.onclick = function () { zoom = n; render(); };
      d.oncontextmenu = function (e) { e.preventDefault(); if (zoom.p) { zoom = zoom.p; render(); } };
      d.onmousemove = function (e) { showTip(e, n); };
      d.onmouseout = function () { tip.style.display = 'none'; };
      chart.appendChild(d);
      var acc = x;
      (n.k || []).forEach(function (c) { place(c, depth + 1, acc); acc += c.t / total * width; });
    }
    place(zoom, 0, 0);
    chart.style.height = ((maxDepth + 1) * ROW) + 'px';
    var text = (path(zoom).join(' > ') || 'All measured time') + '   ' + fmt(zoom.t);
    if (query !== '') {
      var m = matchTotal(zoom);
      text += '   matches: ' + fmt(m) + ' (' + (m / zoom.t * 100).toFixed(1) + '%)';
    }
    crumb.textContent = text;
  }
  search.oninput = function () { query = search.value.toLowerCase(); render(); };
  document.getElementById('reset').onclick = function () { zoom = root; render(); };
  window.onresize = render;
  render();
})();
</script>
</body>
</html>
]==]

-- Html renders a single self-contained page: the tree is embedded as JSON and drawn by an
-- inline script (click to zoom, right-click to zoom out, search to highlight).
---@param tree PerfTree
---@param metric "time"|"alloc"
---@param title string
---@param summaryLines string[]
---@return string
function M.Html(tree, metric, title, summaryLines)
  local data = encodeJSON({
    unit = metric == 'alloc' and 'bytes' or 'microseconds',
    root = htmlNode(tree.root, metric),
  })
  data = string.gsub(data, '</', '<\\/')
  local page = string.gsub(HTML_TEMPLATE, '%%TITLE%%', function() return escapeHtml(title) end)
  page = string.gsub(page, '%%SUMMARY%%', function() return escapeHtml(table.concat(summaryLines, '\n')) end)
  page = string.gsub(page, '%%DATA%%', function() return data end)
  return page
end

---@param session table
---@param frameIndex number|nil
---@return string[]
local function summaryLines(session, frameIndex)
  local meta, stats = session.meta or {}, session.stats or {}
  local lines = {
    string.format('Session #%d, %s - %s, captured %s (%s).', session.id or 0, meta.character or '?',
      meta.realm or '?', meta.startedAt and os.date('%Y-%m-%d %H:%M:%S', meta.startedAt) or '?', meta.reason or '?'),
    string.format('Duration %s, measured BetterBags time %s, %d frames, %d calls.',
      perfFormat:Ms(stats.durationMs or 0), perfFormat:Ms(stats.instrumentedMs or 0), stats.frames or 0, stats.calls or 0),
  }
  if frameIndex then
    local frame = perfFormat:DecodeFrame(session, frameIndex)
    local line = string.format('Worst frame #%d: %s at %s into the capture', frameIndex, perfFormat:Ms(frame.ms), perfFormat:Ms(frame.atMs))
    if frame.blizzardMs then
      line = line .. string.format(' (Blizzard addon profiler: %s)', perfFormat:Ms(frame.blizzardMs))
    end
    lines[#lines + 1] = line .. '.'
  end
  return lines
end

local function writeFile(path, contents)
  local f, err = io.open(path, 'w')
  if not f then return false, err end
  f:write(contents)
  f:close()
  return true
end

---@param args string[]
---@param out fun(line: string)
---@return number exitCode
function M.Main(args, out)
  local svPath
  local opts = { session = 'latest', metric = 'time', out = '.' }
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == '--list' then
      opts.list = true
    elseif a == '--session' or a == '--frame' or a == '--metric' or a == '--out' then
      opts[string.sub(a, 3)] = args[i + 1]
      i = i + 1
    elseif string.sub(a, 1, 2) == '--' then
      out('Unknown option ' .. a)
      return 1
    else
      svPath = a
    end
    i = i + 1
  end
  if not svPath then
    for _, line in ipairs(USAGE) do out(line) end
    return 1
  end
  if opts.metric ~= 'time' and opts.metric ~= 'alloc' then
    out('--metric must be time or alloc')
    return 1
  end

  local db, err = M.LoadSavedVariables(svPath)
  if not db then
    out('Could not read ' .. svPath .. ': ' .. tostring(err))
    return 1
  end
  if opts.list then
    for _, line in ipairs(M.ListSessions(db)) do out(line) end
    return 0
  end

  local session = M.FindSession(db, opts.session)
  if not session then
    out('No session ' .. tostring(opts.session) .. ' in ' .. svPath .. '. Use --list to see the saved sessions.')
    return 1
  end
  local frameIndex = opts.frame and tonumber(opts.frame) or nil
  if opts.frame and (not frameIndex or not (session.worst or {})[frameIndex]) then
    out(string.format('Session #%d has no worst frame %s (it kept %d).', session.id, tostring(opts.frame), #(session.worst or {})))
    return 1
  end

  local tree = M.Tree(session, frameIndex)
  local base = string.format('%s/betterbags-%d%s%s', opts.out, session.id,
    frameIndex and ('-frame' .. frameIndex) or '', opts.metric == 'alloc' and '-alloc' or '')
  local title = string.format('BetterBags session #%d%s', session.id, frameIndex and (', worst frame ' .. frameIndex) or '')
  local outputs = {
    { base .. '.folded', M.Folded(tree, opts.metric) },
    { base .. '.speedscope.json', M.Speedscope(tree, opts.metric, title) },
    { base .. '.html', M.Html(tree, opts.metric, title, summaryLines(session, frameIndex)) },
  }
  for _, output in ipairs(outputs) do
    local ok, writeErr = writeFile(output[1], output[2])
    if not ok then
      out('Could not write ' .. output[1] .. ': ' .. tostring(writeErr))
      return 1
    end
    out('Wrote ' .. output[1])
  end
  return 0
end

if (...) ~= 'flamegraph-module' then
  os.exit(M.Main({ ... }, print))
end

return M
