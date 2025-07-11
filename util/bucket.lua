


local addon = GetBetterBags()

---@class Bucket: AceModule
---@field private bucketsFunctions table<string, BucketFunction>
local bucket = addon:NewModule('Bucket')

---@class BucketFunction
---@field name string
---@field func fun()
---@field delay number

function bucket:OnInitialize()
  self.bucketsFunctions = {}
end

function bucket:Later(name, delay, func)
  if self.bucketsFunctions[name] then return end
  self.bucketsFunctions[name] = {
    name = name,
    func = func,
    delay = delay
  }
  C_Timer.After(delay, function()
    func()
    self.bucketsFunctions[name] = nil
  end)
end