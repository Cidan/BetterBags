local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- PixelAudit holds BetterBags Next to the screen's pixel grid (next-pixel-perfect.md) in game: Check lists the
-- shown parts of a window that are not on whole screen pixels. It reads only what the client gives an addon
-- (where a region is, GetScaledRect; its anchors; its regions and children; whether it shows), so it judges the
-- real layout: real fonts, art, Blizzard's templates, other addons. The specs run the same check
-- (spec/helpers/layout.lua, PixelCheck), the mock answering those calls from its own layout resolver.
---@class PixelAudit: AceModule
local audit = addon:NewModule('PixelAudit')

-- What draws, so its own edges must be on the grid: textures, lines, text, edit boxes. A frame draws nothing
-- itself unless it clips its children (its edges cut what is inside).
local DRAWS = { Texture = true, Line = true, MaskTexture = true, FontString = true, EditBox = true }

-- Which edge or middle of a rect each anchor point is on.
local H_SIDE = {
  TOPLEFT = "left", LEFT = "left", BOTTOMLEFT = "left",
  TOPRIGHT = "right", RIGHT = "right", BOTTOMRIGHT = "right",
  TOP = "middle", CENTER = "middle", BOTTOM = "middle",
}
local V_SIDE = {
  TOPLEFT = "top", TOP = "top", TOPRIGHT = "top",
  BOTTOMLEFT = "bottom", BOTTOM = "bottom", BOTTOMRIGHT = "bottom",
  LEFT = "middle", CENTER = "middle", RIGHT = "middle",
}

local SIDES = { "left", "right", "top", "bottom" }

---@param r table { left, right, top, bottom }
---@param point string
---@return number x, number y
local function pointOf(r, point)
  local h, v = H_SIDE[point], V_SIDE[point]
  local x = (h == "left" and r.left) or (h == "right" and r.right) or (r.left + r.right) / 2
  local y = (v == "top" and r.top) or (v == "bottom" and r.bottom) or (r.top + r.bottom) / 2
  return x, y
end

local function onPixel(value)
  return math.abs(value - math.floor(value + 0.5)) < 1e-3
end

-- visible says whether a region draws: shown with every parent, and neither it nor a parent at alpha 0 (a
-- template's art hidden that way, a glow before it is lit).
---@param region ScriptRegion
---@return boolean
local function visible(region)
  if not region:IsVisible() then
    return false
  end
  local r = region
  while r ~= nil do
    if r:GetAlpha() == 0 then
      return false
    end
    r = r:GetParent()
  end
  return true
end

---@param region ScriptRegion
---@return boolean
local function isFrame(region)
  return region:IsObjectType("Frame")
end

-- rectOf is where the client puts a region, in UI units at scale 1 (GetScaledRect: its own units times its
-- effective scale, Blizzard's RegionUtil.GetRegionPoint), or nil while it is not placed. warcraft.wiki.gg
-- ScriptRegion:GetRect: not allowed on restricted frames, so a refusal is nil too.
---@param region ScriptRegion
---@return table?
local function rectOf(region)
  local ok, left, bottom, width, height = pcall(region.GetScaledRect, region)
  if not ok or left == nil then
    return nil
  end
  return { left = left, right = left + width, bottom = bottom, top = bottom + height }
end

-- names maps the regions wanted to the field paths owner tables reach them by (for messages). It only
-- iterates tables and compares what it finds with the regions wanted: reading a key of a table it does not know
-- could run its __index (AceDB's defaults write a saved table when a wildcard key is read).
---@param owners? table<string, table>
---@param wanted table<table, boolean>
---@return table<table, string>
local function names(owners, wanted)
  local map, seen = {}, {}
  local function walk(t, path, depth)
    if type(t) ~= "table" or seen[t] or depth > 4 then
      return
    end
    seen[t] = true
    for k, v in pairs(t) do
      if type(v) == "table" and type(k) == "string" and k:sub(1, 1) ~= "_" then
        local p = path .. "." .. k
        if wanted[v] and map[v] == nil then
          map[v] = p
        end
        walk(v, p, depth + 1)
      elseif type(v) == "table" and type(k) == "number" then
        walk(v, path .. "[" .. k .. "]", depth + 1)
      end
    end
  end
  for name, owner in pairs(owners or {}) do
    walk(owner, name, 0)
  end
  return map
end

-- fieldsOf maps a frame's own regions and children (own) that it keeps in its fields (a template's parentKeys, a
-- button's state art) to their keys.
---@param frame table
---@param own table<table, boolean>
---@return table<table, string>
local function fieldsOf(frame, own)
  local map = {}
  for k, v in pairs(frame) do
    if type(k) == "string" and k:sub(1, 1) ~= "_" and own[v] and map[v] == nil then
      map[v] = k
    end
  end
  return map
end

-- Check lists every shown part under root that draws and is not on whole screen pixels: a texture's, an edit
-- box's or a clipping frame's four edges, an edit box's text insets, a font string's anchor points (its far
-- edges are its text's measure). A part the client does not place is skipped, as is everything under a region
-- in skip. owners (name -> table) name the parts in the messages; a part no owner reaches is named by the field
-- its parent keeps it in, else by its place in the tree. It returns one string per part.
---@param root ScriptRegion
---@param opts? { skip?: table<table, boolean>, owners?: table<string, table> }
---@return string[]
function audit:Check(root, opts)
  opts = opts or {}
  local skip = opts.skip or {}
  local k = 1 / PixelUtil.GetPixelToUIUnitFactor()
  local found = {}
  local function check(region, path)
    if skip[region] or not visible(region) then
      return
    end
    local frame = isFrame(region)
    local r = (DRAWS[region:GetObjectType()] or (frame and region:DoesClipChildren())) and rectOf(region) or nil
    if r ~= nil then
      local bad = {}
      if region:GetObjectType() == "FontString" then
        for i = 1, region:GetNumPoints() do
          local point = region:GetPoint(i)
          local x, y = pointOf(r, point)
          if not onPixel(x * k) then
            table.insert(bad, string.format("%s x %.3f", point, x * k))
          end
          if not onPixel(y * k) then
            table.insert(bad, string.format("%s y %.3f", point, y * k))
          end
        end
      else
        for _, side in ipairs(SIDES) do
          if not onPixel(r[side] * k) then
            table.insert(bad, string.format("%s %.3f", side, r[side] * k))
          end
        end
      end
      -- An edit box draws its text inside its insets, in its own units (SetTextInsets).
      if region:GetObjectType() == "EditBox" then
        local s = region:GetEffectiveScale()
        local insets = { region:GetTextInsets() }
        for i, side in ipairs(SIDES) do
          if not onPixel(insets[i] * s * k) then
            table.insert(bad, string.format("text inset %s %.3f", side, insets[i] * s * k))
          end
        end
      end
      if #bad > 0 then
        table.insert(found, { region = region, path = path, bad = table.concat(bad, ", ") })
      end
    end
    if not frame then
      return
    end
    local regions, children = { region:GetRegions() }, { region:GetChildren() }
    local own = {}
    for _, part in ipairs(regions) do own[part] = true end
    for _, part in ipairs(children) do own[part] = true end
    local keys = fieldsOf(region, own)
    local textures, texts = 0, 0
    for _, child in ipairs(regions) do
      local segment
      if child:GetObjectType() == "FontString" then
        texts = texts + 1
        segment = "s" .. texts
      else
        textures = textures + 1
        segment = "t" .. textures
      end
      check(child, path .. ">" .. (keys[child] or segment))
    end
    for i, child in ipairs(children) do
      check(child, path .. ">" .. (keys[child] or i))
    end
  end
  check(root, "")
  local problems = {}
  if #found == 0 then
    return problems
  end
  local wanted = {}
  for _, f in ipairs(found) do
    wanted[f.region] = true
  end
  local named = names(opts.owners, wanted)
  for _, f in ipairs(found) do
    local label = named[f.region] or ((f.region:GetName() or f.region:GetObjectType()) .. " " .. f.path)
    table.insert(problems, label .. ": " .. f.bad)
  end
  return problems
end

---------------------------------------------------------------------------------------------------
-- The watcher, turned on and off in the debug window's Pixels tab (frames/pixelpane.lua) and kept on across
-- reloads until turned off. While on, a window that changed (BetterBags Next's windows say so as they render
-- and when shown) is checked once it has not changed for QUIET, then again every GAP until two checks agree:
-- what moves (a slide, a glide, a sparkle) is left out, and what stays off the grid where the window comes to
-- rest is reported, once per set of parts: a chat line, a report kept in BetterBagsPerfDB (pixelAudit.reports,
-- read offline too), and pixelAudit/Found, on which the debug window opens on the Pixels tab. Off, it costs
-- nothing: windows check the watching field before saying they changed, and its frame has no update script.

audit.watching = false

-- How long a window must stay the same before it is checked, and how long between two checks of it.
audit.QUIET = 0.3
audit.GAP = 0.25
-- A window still changing after this many checks is reported for what stayed where it was.
audit.MAX_PASSES = 8
-- How many reports are kept, and how many lines of each.
audit.MAX_REPORTS = 50
audit.MAX_LINES = 200

-- The windows registered, by their root frame; each one's record is kept on the frame (RECORD), so nothing
-- here keeps a window alive.
audit.windows = setmetatable({}, { __mode = "k" })
audit.pending = {}
audit.reported = setmetatable({}, { __mode = "k" })

local RECORD = "betterBagsPixelAudit"

---@return Events
local function events()
  return addon:GetModule('Events')
end

---@param name string
---@return Context
local function newContext(name)
  return addon:GetModule('Context'):New(name)
end

-- Init keeps the reports and whether it watches in BetterBagsPerfDB (PerfSessions creates it first), and starts
-- watching when it was left on.
function audit:Init()
  local db = BetterBagsPerfDB
  if type(db) ~= 'table' then
    db = {}
    BetterBagsPerfDB = db
  end
  if type(db.pixelAudit) ~= 'table' then
    db.pixelAudit = { watching = false, reports = {}, nextId = 1 }
  end
  self.db = db.pixelAudit
  if type(self.db.reports) ~= 'table' then
    self.db.reports = {}
  end
  if type(self.db.nextId) ~= 'number' then
    self.db.nextId = 1
  end
  self.windows = setmetatable({}, { __mode = "k" })
  self.pending = {}
  self.reported = setmetatable({}, { __mode = "k" })
  self.driver = self.driver or CreateFrame("Frame")
  self.driver:SetScript("OnUpdate", nil)
  self.watching = self.db.watching == true
end

-- Register makes a window one the watcher checks: its root frame, its title for the reports, the tables that
-- name its parts (owners, Check), the parts that move by nature (skip, read at each check), and what to say
-- about its state in a report (describe: its size, its scale). It is checked again whenever it is shown.
---@param root Frame
---@param opts {title: string, owners?: table<string, table>, skip?: fun(): table<table, boolean>, describe?: fun(): string?}
function audit:Register(root, opts)
  root[RECORD] = { title = opts.title, owners = opts.owners, skip = opts.skip, describe = opts.describe }
  self.windows[root] = true
  -- A plain hook: it must cost nothing while the check is off, and addon.HookScript makes a Context per call.
  root:HookScript("OnShow", function()
    if self.watching then
      self:Changed(root)
    end
  end)
end

-- WindowOf returns a registered window's record (Register's options), or nil.
---@param root Frame
---@return {title: string, owners?: table<string, table>, skip?: fun(): table<table, boolean>, describe?: fun(): string?}?
function audit:WindowOf(root)
  return root[RECORD]
end

---@return boolean
function audit:IsWatching()
  return self.watching
end

-- SetWatching turns the watcher on (checking every shown window at once) or off, and remembers it.
---@param ctx Context
---@param on boolean
function audit:SetWatching(ctx, on)
  on = on == true
  self.db.watching = on
  if on == self.watching then
    return
  end
  self.watching = on
  if not on then
    self.pending = {}
    self.driver:SetScript("OnUpdate", nil)
  end
  events():SendMessage(ctx, 'pixelAudit/StateChanged', on)
  if on then
    self:CheckNow(ctx)
  end
end

-- mark has a window checked once it has stayed the same for wait seconds.
---@private
---@param root Frame
---@param wait number
function audit:mark(root, wait)
  self.pending[root] = { wait = wait, passes = 0 }
  self.driver:SetScript("OnUpdate", function(_, elapsed)
    self:Step(elapsed)
  end)
end

-- Changed says a window changed (it rendered, it was shown): checked once it stays the same. Callers check
-- the watching field first, so this costs nothing while the watcher is off.
---@param root Frame
function audit:Changed(root)
  if self.watching and root[RECORD] ~= nil then
    self:mark(root, self.QUIET)
  end
end

-- CheckNow checks every shown window registered, as soon as it stays the same, watching or not.
---@param ctx Context
function audit:CheckNow(ctx)
  local _ = ctx
  for root in pairs(self.windows) do
    if root:IsVisible() then
      self:mark(root, 0)
    end
  end
end

-- sameLines says whether two checks found the same parts at the same places.
---@param a string[]
---@param b string[]
---@return boolean
local function sameLines(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

-- stayed lists the lines both checks found, in the second's order: the parts off the grid that did not move.
---@param a string[]
---@param b string[]
---@return string[]
local function stayed(a, b)
  local first, list = {}, {}
  for _, line in ipairs(a) do
    first[line] = true
  end
  for _, line in ipairs(b) do
    if first[line] then
      table.insert(list, line)
    end
  end
  return list
end

-- Step is the watcher's frame update: it checks each window waiting whose time has come, until two checks of
-- it agree (or MAX_PASSES), then reports it. A window hidden meanwhile is dropped.
---@param elapsed number
function audit:Step(elapsed)
  for root, p in pairs(self.pending) do
    if not root:IsVisible() then
      self.pending[root] = nil
    else
      p.wait = p.wait - elapsed
      if p.wait <= 0 then
        local w = root[RECORD]
        local lines = self:Check(root, { owners = w.owners, skip = w.skip and w.skip() or nil })
        p.passes = p.passes + 1
        if p.last ~= nil and (sameLines(p.last, lines) or p.passes >= self.MAX_PASSES) then
          self.pending[root] = nil
          self:settled(root, w, stayed(p.last, lines))
        else
          p.last, p.wait = lines, self.GAP
        end
      end
    end
  end
  if next(self.pending) == nil then
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- settled takes a window's result: a report when it found parts off the grid that it did not report last time
-- for this window (one with nothing off forgets what it reported, so the parts coming back are reported again).
---@private
---@param root Frame
---@param w table The window's record.
---@param lines string[]
function audit:settled(root, w, lines)
  local labels = {}
  for _, line in ipairs(lines) do
    table.insert(labels, line:match("^(.-): ") or line)
  end
  table.sort(labels)
  local key = table.concat(labels, "\n")
  local ctx = newContext('PixelAudit_Settled')
  self.lastChecked = { window = w.title, count = #lines, at = time() }
  if #lines == 0 then
    self.reported[root] = nil
  elseif self.reported[root] ~= key then
    self.reported[root] = key
    self:report(ctx, root, w, lines)
  end
  events():SendMessage(ctx, 'pixelAudit/Checked', w.title, #lines)
end

-- report keeps a report of a window's parts off the grid, with the state it was in, and says so.
---@private
---@param ctx Context
---@param root Frame
---@param w table
---@param lines string[]
function audit:report(ctx, root, w, lines)
  local width, height = GetPhysicalScreenSize()
  local sonataNext = addon:GetModule('SonataNext', true)
  local r = {
    id = self.db.nextId,
    at = time(),
    window = w.title,
    screen = string.format("%dx%d", width, height),
    uiScale = UIParent:GetScale(),
    scale = root:GetEffectiveScale(),
    theme = sonataNext ~= nil and sonataNext.started and sonataNext:GetCurrentThemeKey() or nil,
    details = w.describe and w.describe() or nil,
    total = #lines,
    lines = {},
  }
  for i = 1, math.min(#lines, self.MAX_LINES) do
    r.lines[i] = lines[i]
  end
  self.db.nextId = self.db.nextId + 1
  local list = self.db.reports
  table.insert(list, r)
  while #list > self.MAX_REPORTS do
    table.remove(list, 1)
  end
  print(string.format("BetterBags: %d %s of %s off the screen's pixels. See the Pixels tab of /bbdb.", #lines,
    #lines == 1 and "part" or "parts", w.title))
  events():SendMessage(ctx, 'pixelAudit/Found', r)
end

-- GetReports returns the reports kept, the newest last.
---@return table[]
function audit:GetReports()
  return self.db and self.db.reports or {}
end

-- ClearReports drops every report kept, and what was reported, so what is still off is reported again.
---@param ctx Context
function audit:ClearReports(ctx)
  local list = self.db.reports
  for i = #list, 1, -1 do
    list[i] = nil
  end
  self.reported = setmetatable({}, { __mode = "k" })
  events():SendMessage(ctx, 'pixelAudit/Cleared')
end
