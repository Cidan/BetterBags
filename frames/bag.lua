local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:NewModule('BagFrame')

---@class BagPool
---@field Acquire fun(): Frame
---@field Release fun(pool: BagPool, frame: Frame)
local pool = CreateFramePool("Frame", nil, "BackdropTemplate")

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class Bag
---@field frame Frame The raw frame of the bag.
local bagProto = {}

function bagProto:Test()
  print("bag test")
end

--- Create creates a new bag view.
---@param name string
---@return Bag
function bagFrame:Create(name)
  local b = {}
  setmetatable(b, { __index = bagProto })
  local f = pool:Acquire()
  b.frame = f
  return b
end

--- Destroy destroys the given bag view.
---@param bag Bag
function bagFrame:Destroy(bag)
  pool:Release(bag.frame)
end