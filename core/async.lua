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

-- Yield is a small wrapper around coroutine.yield.
function async:Yield()
  coroutine.yield()
end
