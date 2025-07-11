

---@type BetterBags
local addon = GetBetterBags()

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Task
---@field fn fun()
---@field cb fun()
---@field thread thread
---@field worker fun()

---@class Async: AceModule
---@field AfterCombatCallbacks fun(ctx: Context)[]
local async = addon:NewModule('Async')

function async:OnInitialize()
  self.AfterCombatCallbacks = {}
end

function async:OnEnable()
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function(ctx)
    for _, cb in ipairs(self.AfterCombatCallbacks) do
      cb(ctx)
    end
    wipe(self.AfterCombatCallbacks)
  end)
end

-- DoWithDelay will run the coroutine function with a delay between each yield.
-- You must call async:Yield() in your function to yield when you wait for the next frame. 
---@param ctx Context
---@param delay number
---@param fn fun(ctx: Context)
---@param event string|fun(ctx: Context)
function async:DoWithDelay(ctx, delay, fn, event)
  local task = {
    ctx = ctx,
    fn = fn,
    event = event,
    thread = coroutine.create(fn),
  }

  task.worker = function()
    local success, err = coroutine.resume(task.thread, task.ctx)
    if not success then
      error(err)
    end

    if coroutine.status(task.thread) == 'dead' then
      if task.event then
        if type(task.event) == 'function' then
          task.event(task.ctx)
        elseif type(task.event) == 'string' then
          events:SendMessage(task.ctx, task.event --[[@as string]])
        end
      end
      return
    end
    C_Timer.After(delay, task.worker)
  end

 task.worker()
end

-- Do will run the coroutine function with no delay between each yield.
-- This is the same as DoWithDelay(0, fn, cb).
---@param ctx Context
---@param fn fun(ctx: Context)
---@param event string|fun(ctx: Context)
function async:Do(ctx, fn, event)
  self:DoWithDelay(ctx, 0, fn, event)
end

--- Each will call function fn for each item in list, one call per frame.
--- Do not call async:Yield() in fn, as it will be called automatically.
---@generic T
---@param ctx Context
---@param list T[]
---@param fn fun(ctx: Context, item: T, index: number)
---@param event string
function async:Each(ctx, list, fn, event)
  self:Do(ctx, function(ectx)
    for i = 1, #list do
      fn(ectx, list[i], i)
      self:Yield()
    end
  end, event)
end

-- Batch will call function fn for each item in list, with a batch size of count per frame.
-- Do not call async:Yield() in fn, as it will be called automatically.
---@generic T
---@param ctx Context
---@param count number
---@param list T[]
---@param fn fun(ctx: Context, item: T, index: number)
---@param event string|fun(ctx: Context)
function async:Batch(ctx, count, list, fn, event)
  self:Do(ctx, function(ectx)
    for i = 1, #list, count do
      for j = i, math.min(i + count - 1, #list) do
        fn(ectx, list[j], j)
      end
      self:Yield()
    end
  end, event)
end

-- Batch will call function fn for each item in list, with a batch size of count per frame.
-- You must call async:Yield() in fn, as it will not be called automatically.
---@generic T
---@param ctx Context
---@param count number
---@param list T[]
---@param fn fun(ctx: Context, item: T, index: number)
---@param event string
function async:BatchNoYield(ctx, count, list, fn, event)
  self:Do(ctx, function(ectx)
    for i = 1, #list, count do
      for j = i, math.min(i + count - 1, #list) do
        fn(ectx, list[j], j)
      end
    end
  end, event)
end

-- RawBatch will call function fn for each item in list, with a batch size of count per frame.
-- Yield is called for you, but not inside of a Do function, for each batch. You must call this
-- from a coroutine.
---@generic T
---@param ctx Context
---@param count number
---@param list T[]
---@param fn fun(ctx: Context, item: T, index: number)
function async:RawBatch(ctx, count, list, fn)
  for i = 1, #list, count do
    for j = i, math.min(i + count - 1, #list) do
      fn(ctx, list[j], j)
    end
   async:Yield()
  end
end

-- StableIterate will adjust the iteration speed of the list based on the frame rate.
-- Higher framerates will iterate faster, lower framerates will iterate slower.
---@generic T
---@param ctx Context
---@param delta number
---@param list T[]
---@param fn fun(ctx: Context, item: T, index: number)
---@param event string
function async:StableIterate(ctx, delta, list, fn, event)
  local framerate = GetFramerate()
  -- Just in case :)
  if framerate == 0 then framerate = 1 end
  local count = math.ceil((#list / (#list / framerate)) * delta)
  self:Batch(ctx, count, list, fn, event)
end

-- Chain will call each function in the list, one after the other.
-- The functions will be called one per frame via async:Do()
---@param ctx Context
---@param event? string
---@param ... fun(ctx: Context)
function async:Chain(ctx, event, ...)
  local functions = {...}
  local index = 1
  local function executeNext()
    if index <= #functions then
      async:Do(ctx,
        function(ectx)
          functions[index](ectx)
        end,
        function()
          index = index + 1
          executeNext()
        end
      )
    elseif event ~= nil then
      events:SendMessage(ctx, event)
    end
  end
  executeNext()
end

-- Until will call function fn until it returns true, once per frame, then call cb.
-- Do not call async:Yield() in fn, as it will be called automatically.
---@param ctx Context
---@param fn fun(ctx: Context): boolean
---@param event string|fun(ctx: Context)
function async:Until(ctx, fn, event)
  self:Do(ctx, function(ectx)
    while not fn(ectx) do
      self:Yield()
    end
  end, event)
end

-- AfterCombat will call function cb after the player leaves combat.
-- If the player is already out of combat, cb will be called immediately.
---@param ctx Context
---@param cb fun(ctx: Context)
function async:AfterCombat(ctx, cb)
  if InCombatLockdown() then
    table.insert(self.AfterCombatCallbacks, cb)
  else
    cb(ctx)
  end
end

-- Yield is a small wrapper around coroutine.yield.
function async:Yield()
  coroutine.yield()
end
