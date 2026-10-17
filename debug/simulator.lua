local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Perf: AceModule
local perf = addon:GetModule('Perf')

---@class PerfSessions: AceModule
local perfSessions = addon:GetModule('PerfSessions')

-- The Simulator fires one of the WoW events BetterBags listens to, through BetterBags' own
-- dispatcher (the path a real event takes, Events:addEventCallback), at a rate for a duration,
-- optionally with the bags opened and a profiler capture around the run. It reproduces
-- BetterBags' side of an event storm wherever the player stands (inside a raid or dungeon,
-- under the addon restrictions those apply); the game does not deliver the simulated event
-- to other addons or to Blizzard's frames. The Simulate tab of the debug window drives it.
---@class Simulator: AceModule
---@field frame Frame
---@field run? SimulatorRun
---@field startedCapture boolean
local simulator = addon:NewModule('Simulator')

simulator.RATE = { min = 1, max = 240 }
simulator.DURATION = { min = 1, max = 120 }

-- Events that start or end the addon's life; firing them again would reload or tear down
-- BetterBags' state.
local LIFECYCLE = {
  ADDON_LOADED = true,
  PLAYER_LOGIN = true,
  PLAYER_LOGOUT = true,
  PLAYER_ENTERING_WORLD = true,
}

---@class SimulatorOptions
---@field event string
---@field rate number Fires per second.
---@field duration number Seconds.
---@field payload? any[] The event's arguments.
---@field payloadCount? number How many of payload to pass (payload may hold nils).
---@field payloadText? string The payload as typed, recorded with a capture.
---@field openBags? boolean Open the backpack first.
---@field capture? boolean Capture the run with the profiler.

---@class SimulatorRun
---@field event string
---@field rate number
---@field duration number
---@field payload any[]
---@field payloadCount number
---@field elapsed number
---@field fired number
---@field total number

function simulator:Init()
  if self.frame == nil then
    self.frame = CreateFrame('Frame')
  end
  self.frame:SetScript('OnUpdate', nil)
  self.run = nil
  self.startedCapture = false
end

---@param value number
---@param range {min: number, max: number}
---@return number
local function clamp(value, range)
  value = tonumber(value) or range.min
  if value < range.min then return range.min end
  if value > range.max then return range.max end
  return value
end

-- GetEvents lists the WoW events BetterBags has handlers for, sorted, without its load and
-- logout events.
---@return string[]
function simulator:GetEvents()
  local list = {}
  for name in pairs(events._eventMap or {}) do
    if not LIFECYCLE[name] then
      table.insert(list, name)
    end
  end
  table.sort(list)
  return list
end

---@param name string
---@return boolean
local function listens(name)
  if LIFECYCLE[name] then return false end
  return events._eventMap ~= nil and events._eventMap[name] ~= nil
end

-- Fire delivers one simulated event to BetterBags' handlers, inside a "[simulate] EVENT" span
-- so a call trace tells simulated fires from real ones.
---@param event string
function simulator:Fire(event, ...)
  local entry = events._eventMap[event]
  if entry == nil then return end
  local token = perf.active and perf:Enter('[simulate] ' .. event)
  entry.fn(event, ...)
  if token then perf:Exit(token) end
end

---@param elapsed number
function simulator:Step(elapsed)
  local run = self.run
  if run == nil then return end
  run.elapsed = run.elapsed + (elapsed or 0)
  local due = math.min(run.total, math.floor(run.elapsed * run.rate + 1e-9))
  while run.fired < due do
    run.fired = run.fired + 1
    self:Fire(run.event, unpack(run.payload, 1, run.payloadCount))
  end
  if run.fired >= run.total then
    self:Stop(context:New('Simulator_Done'))
  end
end

-- Start begins a run. It returns false when a run is going or the event is not one
-- BetterBags listens to. The rate and duration are clamped to RATE and DURATION.
---@param ctx Context
---@param opts SimulatorOptions
---@return boolean started
function simulator:Start(ctx, opts)
  if self.run ~= nil or opts == nil or not listens(opts.event) then
    return false
  end
  local rate = clamp(opts.rate, self.RATE)
  local duration = clamp(opts.duration, self.DURATION)
  local payload = opts.payload or {}
  if opts.openBags and addon.Bags and addon.Bags.Backpack then
    addon.Bags.Backpack:Show(ctx)
  end
  self.startedCapture = false
  if opts.capture and not perfSessions:IsCapturing() then
    self.startedCapture = perfSessions:StartCapture('simulate', {
      simulation = {
        event = opts.event,
        rate = rate,
        duration = duration,
        payload = opts.payloadText or '',
        openBags = opts.openBags == true,
      },
    }) == true
  end
  self.run = {
    event = opts.event,
    rate = rate,
    duration = duration,
    payload = payload,
    payloadCount = opts.payloadCount or #payload,
    elapsed = 0,
    fired = 0,
    total = math.max(1, math.floor(rate * duration + 0.5)),
  }
  self.frame:SetScript('OnUpdate', function(_, elapsed)
    self:Step(elapsed)
  end)
  events:SendMessage(ctx, 'simulator/StateChanged', true)
  return true
end

-- Stop ends the run, and the capture it started.
---@param ctx Context
function simulator:Stop(ctx)
  if self.run == nil then return end
  self.frame:SetScript('OnUpdate', nil)
  self.lastRun = self.run
  self.run = nil
  if self.startedCapture then
    self.startedCapture = false
    perfSessions:StopCapture()
  end
  events:SendMessage(ctx, 'simulator/StateChanged', false)
end

---@return boolean
function simulator:IsRunning()
  return self.run ~= nil
end

-- GetStatus describes the current run, or the last one when none is going.
---@return SimulatorRun?
function simulator:GetStatus()
  return self.run or self.lastRun
end

-- ParsePayload reads comma-separated values: numbers, true, false, nil, and strings (quotes
-- optional). It returns the values and how many there are (nils included).
---@param text string
---@return any[] values, number count
function simulator:ParsePayload(text)
  local values, n = {}, 0
  if text == nil or not text:find('%S') then
    return values, 0
  end
  for raw in (text .. ','):gmatch('([^,]*),') do
    local item = raw:match('^%s*(.-)%s*$')
    n = n + 1
    if item == 'nil' then
      values[n] = nil
    elseif item == 'true' then
      values[n] = true
    elseif item == 'false' then
      values[n] = false
    elseif tonumber(item) ~= nil then
      values[n] = tonumber(item)
    else
      values[n] = item:match('^"(.*)"$') or item:match("^'(.*)'$") or item
    end
  end
  return values, n
end
