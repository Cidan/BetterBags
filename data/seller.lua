local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

-- Seller sells items to the merchant open (automation.md §3): every sale BetterBags makes goes through
-- it (Auto Sell, a section sold in BetterBags Next's vendor dock, Classic's Sell Junk, a category title's
-- right click). It sends one item at a time, the next one an interval later, the larger of the home and
-- world latency and at least 0.2 seconds (Dejunk's Addon:GetLatency; asked: "dejunk's works fine"),
-- on one pace for every sale. Sending a sale's items all at once made the client answer most of them
-- "That object is busy." (ERR_OBJECT_IS_BUSY): reported, and the same error players describe for other
-- addons that sell in bulk.
--
-- Each item has its interval to be answered: an error the client raises meanwhile (UI_ERROR_MESSAGE) is
-- about it. Busy: it is tried again later, after a beat with nothing sent, three times at most. Not
-- wanted (ERR_VENDOR_NOT_INTERESTED, or the Azerite one): this merchant refuses it, remembered by the
-- merchant's GUID for the session, so it goes back to the bags and is tried at another merchant (asked:
-- "refused items go back to the backpack until we find a merchant that buys it"). The merchant buys
-- nothing (ERR_VENDOR_DOESNT_BUY, ERR_VENDOR_HATES_YOU): every sale stops, and this merchant is sold
-- nothing again. Too far (ERR_VENDOR_TOO_FAR): every sale stops.
---@class Seller: AceModule
---@field atMerchant boolean A merchant is open (MERCHANT_SHOW to MERCHANT_CLOSED).
---@field jobs SellerJob[] The sales waiting, the first selling.
---@field sending? SellerSent The item sent last, waiting for its answer.
---@field timer boolean The pace's next beat is scheduled.
---@field skipBeat boolean The client was busy: the next beat sends nothing.
---@field refused table<string, table<string, boolean>> Item GUIDs each merchant (by its GUID) refused.
---@field buysNothing table<string, boolean> The merchants that buy nothing.
local seller = addon:NewModule('Seller')

seller.MIN_INTERVAL = 0.2
seller.MAX_TRIES = 3

---@class SellerItem
---@field bag number
---@field slot number
---@field guid? string The item it was given, when given one (else whatever the slot holds).
---@field data? ItemData
---@field tries number
---@field count? number How many the slot held when it was sent.

---@class SellerJob
---@field items SellerItem[]
---@field next number The next item to send.
---@field sold SellerItem[] Sent and not refused.
---@field refusedNow number Refused by this merchant during this sale.
---@field unsold number Refused, given up, or never sent.
---@field finished? boolean
---@field onDone? fun(job: SellerJob, reason: string)
---@field onProgress? fun(job: SellerJob)
---@field stillOpen? fun(): boolean

---@class SellerSent
---@field job SellerJob
---@field item SellerItem
---@field answered? boolean

function seller:Init()
  self.atMerchant = false
  self.jobs = {}
  self.sending = nil
  self.timer = false
  self.skipBeat = false
  self.refused = {}
  self.buysNothing = {}
end

function seller:OnEnable()
  events:RegisterEvent('MERCHANT_SHOW', function() self.atMerchant = true end)
  events:RegisterEvent('MERCHANT_CLOSED', function()
    self.atMerchant = false
    self:StopAll("closed")
  end)
  events:RegisterEvent('UI_ERROR_MESSAGE', function(_, _, _, message) self:OnError(message) end)
end

-- Interval is how long the pace waits between items: the larger of the home and world latency
-- (GetNetStats), at least MIN_INTERVAL.
---@return number
function seller:Interval()
  local _, _, home, world = GetNetStats()
  return math.max((math.max(home or 0, world or 0)) / 1000, self.MIN_INTERVAL)
end

-- merchant is the open merchant's GUID (the "npc" unit while a merchant is open).
---@return string
local function merchant()
  return UnitGUID("npc") or "?"
end

---@param data ItemData|{bag: number, slot: number}
---@return string?
local function guidOf(data)
  return data.itemInfo and data.itemInfo.itemGUID or nil
end

-- Refuses says whether the merchant open refused this item (by its GUID) this session.
---@param data ItemData
---@return boolean
function seller:Refuses(data)
  local guid = guidOf(data)
  local refused = self.refused[merchant()]
  return guid ~= nil and refused ~= nil and refused[guid] == true
end

-- BuysNothing says whether the merchant open refused to buy anything this session.
---@return boolean
function seller:BuysNothing()
  return self.buysNothing[merchant()] == true
end

-- StillThere returns how many items a slot holds when it still holds the item (its GUID, when known),
-- unlocked and not refundable now, and, to sell, one merchants buy; else nil. The bags may have changed
-- since they were read. A purchase that can still be refunded is left alone: Blizzard asks before
-- refunding one (ContainerFrame_GetExtendedPriceString), and CanBeRefunded raises an error for an empty
-- location, so it is asked only once the slot holds something.
---@param data ItemData|{bag: number, slot: number}
---@param forSale boolean
---@return number?
function seller:StillThere(data, forSale)
  local bag, slot = data.bagid or data.bag, data.slotid or data.slot
  local guid = guidOf(data)
  if data.itemInfo ~= nil and (guid == nil or guid == "") then
    return nil
  end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if info == nil or info.isLocked or (forSale and info.hasNoValue) then
    return nil
  end
  local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
  if guid ~= nil and C_Item.GetItemGUID(location) ~= guid then
    return nil
  end
  if C_Item.CanBeRefunded ~= nil and C_Item.CanBeRefunded(location) == true then
    return nil
  end
  return info.stackCount or 1
end

-- Sell queues a sale: items (ItemData, or slots {bag, slot} sold as they hold then), sold one at a time
-- on the pace, each when its turn comes if it is still there (StillThere) and this merchant has not
-- refused it. The pace starts at once when idle. opts.onProgress runs after each item sent;
-- opts.onDone once it ends, with why: "done", "closed" (the merchant closed, the player walked away, or
-- stillOpen said so), "refused" (the merchant buys nothing). Cancel ends it without calling back.
---@param list (ItemData|{bag: number, slot: number})[]
---@param opts? {onDone?: fun(job: SellerJob, reason: string), onProgress?: fun(job: SellerJob), stillOpen?: fun(): boolean}
---@return SellerJob
function seller:Sell(list, opts)
  opts = opts or {}
  ---@type SellerJob
  local job = { items = {}, next = 1, sold = {}, refusedNow = 0, unsold = 0, onDone = opts.onDone,
    onProgress = opts.onProgress, stillOpen = opts.stillOpen }
  for _, data in ipairs(list) do
    table.insert(job.items, { bag = data.bagid or data.bag, slot = data.slotid or data.slot, guid = guidOf(data),
      data = data.itemInfo and data or nil, tries = 0 })
  end
  table.insert(self.jobs, job)
  if not self.timer then
    self:Step()
  end
  return job
end

-- Left is how many of a sale's items are still to be sent.
---@param job SellerJob
---@return number
function seller:Left(job)
  return math.max(0, #job.items - job.next + 1)
end

-- IsSelling says whether a sale is waiting or selling.
---@return boolean
function seller:IsSelling()
  return #self.jobs > 0
end

-- Cancel ends a sale without calling back: what it has not sent is not sent.
---@param job SellerJob
function seller:Cancel(job)
  self:finish(job, nil)
end

-- StopAll ends every sale, calling each back with reason.
---@param reason string
function seller:StopAll(reason)
  self:answer()
  while self.jobs[1] ~= nil do
    self:finish(self.jobs[1], reason)
  end
end

---@private
---@param job SellerJob
---@param reason? string
function seller:finish(job, reason)
  if job.finished then
    return
  end
  job.finished = true
  for i, j in ipairs(self.jobs) do
    if j == job then
      table.remove(self.jobs, i)
      break
    end
  end
  if self.sending ~= nil and self.sending.job == job then
    self:answer()
  end
  job.unsold = job.unsold + self:Left(job)
  job.next = #job.items + 1
  if reason ~= nil and reason ~= "refused" and job.refusedNow > 0 then
    local what = job.refusedNow == 1 and L:G("This merchant would not buy %d item.")
      or L:G("This merchant would not buy %d items.")
    print("BetterBags: " .. format(what, job.refusedNow))
  end
  if reason ~= nil and job.onDone then
    job.onDone(job, reason)
  end
end

-- answer takes the item sent last as answered: sold, unless an error said otherwise.
---@private
function seller:answer()
  local sent = self.sending
  self.sending = nil
  if sent ~= nil and not sent.answered then
    sent.answered = true
    table.insert(sent.job.sold, sent.item)
  end
end

---@private
function seller:schedule()
  self.timer = true
  C_Timer.After(self:Interval(), function()
    self.timer = false
    self:Step()
  end)
end

-- nextOf returns a sale's next item to send, skipping (as unsold) those no longer there or that this
-- merchant refused.
---@private
---@param job SellerJob
---@return SellerItem?
function seller:nextOf(job)
  while job.next <= #job.items do
    local item = job.items[job.next]
    job.next = job.next + 1
    local count = self:StillThere(item.data or item, true)
    if count ~= nil and not (item.data and self:Refuses(item.data)) then
      item.count = count
      return item
    end
    job.unsold = job.unsold + ((item.data and self:Refuses(item.data)) and 1 or 0)
  end
  return nil
end

-- Step is one beat of the pace: the item sent last is answered, then the first sale's next item is
-- sent, the next beat an interval later. It returns what it did, for profiler traces.
---@return string
function seller:Step()
  self:answer()
  local job = self.jobs[1]
  if job == nil then
    return "idle"
  end
  if not self.atMerchant then
    self:StopAll("closed")
    return "closed"
  end
  if self:BuysNothing() then
    self:StopAll("refused")
    return "refused"
  end
  if job.stillOpen and not job.stillOpen() then
    self:finish(job, "closed")
    return self:Step()
  end
  if self.skipBeat or CursorHasItem() then
    self.skipBeat = false
    self:schedule()
    return "waiting"
  end
  local item = self:nextOf(job)
  if item == nil then
    self:finish(job, "done")
    return self:Step()
  end
  item.tries = item.tries + 1
  self.sending = { job = job, item = item }
  C_Container.UseContainerItem(item.bag, item.slot)
  if job.onProgress then
    job.onProgress(job)
  end
  self:schedule()
  return "sent"
end

-- OnError reads an error the client raised (UI_ERROR_MESSAGE) as the answer for the item sent last, when
-- one waits for its answer. It returns what it took it for.
---@param message string
---@return string
function seller:OnError(message)
  local sent = self.sending
  if sent == nil or sent.answered or message == nil then
    return "ignored"
  end
  if message == _G.ERR_OBJECT_IS_BUSY then
    sent.answered = true
    self.skipBeat = true
    if sent.item.tries < self.MAX_TRIES then
      table.insert(sent.job.items, sent.item)
    else
      sent.job.unsold = sent.job.unsold + 1
    end
    return "busy"
  end
  if message == _G.ERR_VENDOR_NOT_INTERESTED
    or (_G.ERR_VENDOR_REFUSE_SCRAPPABLE_AZERITE ~= nil and message == _G.ERR_VENDOR_REFUSE_SCRAPPABLE_AZERITE) then
    sent.answered = true
    local key = merchant()
    self.refused[key] = self.refused[key] or {}
    if sent.item.guid ~= nil then
      self.refused[key][sent.item.guid] = true
    end
    sent.job.refusedNow = sent.job.refusedNow + 1
    sent.job.unsold = sent.job.unsold + 1
    return "refused"
  end
  if message == _G.ERR_VENDOR_DOESNT_BUY or message == _G.ERR_VENDOR_HATES_YOU then
    sent.answered = true
    sent.job.unsold = sent.job.unsold + 1
    self.buysNothing[merchant()] = true
    print("BetterBags: " .. L:G("This merchant buys nothing."))
    self:StopAll("refused")
    return "buys nothing"
  end
  if message == _G.ERR_VENDOR_TOO_FAR then
    sent.answered = true
    sent.job.unsold = sent.job.unsold + 1
    self:StopAll("closed")
    return "too far"
  end
  return "other"
end
