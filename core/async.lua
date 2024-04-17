local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Task
---@field fn fun()
---@field cb fun()
---@field thread thread
---@field worker fun()

---@class Async: AceModule
local async = addon:NewModule('Async')

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
        return
      end
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

-- Yield is a small wrapper around coroutine.yield.
function async:Yield()
  coroutine.yield()
end
