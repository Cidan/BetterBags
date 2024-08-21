local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Task
---@field fn fun()
---@field cb fun()
---@field thread thread
---@field worker fun()

---@class Async: AceModule
---@field AfterCombatCallbacks fun()[]
local async = addon:NewModule('Async')

function async:OnInitialize()
  self.AfterCombatCallbacks = {}
end

function async:OnEnable()
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function()
    for _, cb in ipairs(self.AfterCombatCallbacks) do
      cb()
    end
    wipe(self.AfterCombatCallbacks)
  end)
end

-- DoWithDelay will run the coroutine function with a delay between each yield.
-- You must call async:Yield() in your function to yield when you wait for the next frame. 
---@param delay number
---@param fn fun()
---@param cb fun()
function async:DoWithDelay(delay, fn, cb)
  local task = {
    fn = fn,
    cb = cb,
    thread = coroutine.create(fn),
  }

  task.worker = function()
    local success, err = coroutine.resume(task.thread)
    if not success then
      error(err)
    end

    if coroutine.status(task.thread) == 'dead' then
      if task.cb then
        task.cb()
      end
      return
    end
    C_Timer.After(delay, task.worker)
  end

 task.worker()
end

-- Do will run the coroutine function with no delay between each yield.
-- This is the same as DoWithDelay(0, fn, cb).
---@param fn fun()
---@param cb fun()
function async:Do(fn, cb)
  self:DoWithDelay(0, fn, cb)
end

--- Each will call function fn for each item in list, one call per frame.
--- Do not call async:Yield() in fn, as it will be called automatically.
---@generic T
---@param list `T`[]
---@param fn fun(item: `T`, index: number)
---@param cb fun()
function async:Each(list, fn, cb)
  self:Do(function()
    for i = 1, #list do
      fn(list[i], i)
      self:Yield()
    end
  end, cb)
end

-- Batch will call function fn for each item in list, with a batch size of count per frame.
-- Do not call async:Yield() in fn, as it will be called automatically.
---@generic T
---@param count number
---@param list `T`[]
---@param fn fun(item: `T`, index: number)
---@param cb fun()
function async:Batch(count, list, fn, cb)
  self:Do(function()
    for i = 1, #list, count do
      for j = i, math.min(i + count - 1, #list) do
        fn(list[j], j)
      end
      self:Yield()
    end
  end, cb)
end

-- StableIterate will adjust the iteration speed of the list based on the frame rate.
-- Higher framerates will iterate faster, lower framerates will iterate slower.
---@generic T
---@param delta number
---@param list `T`[]
---@param fn fun(item: `T`, index: number)
---@param cb fun()
function async:StableIterate(delta, list, fn, cb)
  local framerate = GetFramerate()
  -- Just in case :)
  if framerate == 0 then framerate = 1 end
  local count = math.ceil((#list / (#list / framerate)) * delta)
  self:Batch(count, list, fn, cb)
end

-- Chain will call each function in the list, one after the other.
-- The functions will be called one per frame via async:Do()
---@param ... fun()
function async:Chain(...)
  local functions = {...}
  local index = 1
  local function executeNext()
    if index <= #functions then
      async:Do(
        function()
          functions[index]()
        end,
        function()
          index = index + 1
          executeNext()
        end
      )
    end
  end
  executeNext()
end

-- Until will call function fn until it returns true, once per frame, then call cb.
-- Do not call async:Yield() in fn, as it will be called automatically.
---@param fn fun(): boolean
---@param cb fun()
function async:Until(fn, cb)
  self:Do(function()
    while not fn() do
      self:Yield()
    end
  end, cb)
end

-- AfterCombat will call function cb after the player leaves combat.
-- If the player is already out of combat, cb will be called immediately.
---@param cb fun()
function async:AfterCombat(cb)
  if InCombatLockdown() then
    table.insert(self.AfterCombatCallbacks, cb)
  else
    cb()
  end
end

-- Yield is a small wrapper around coroutine.yield.
function async:Yield()
  coroutine.yield()
end
