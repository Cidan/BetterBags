local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

-- The way Pawn asks a bag addon to work with it (PawnBags.lua): ask PawnShouldItemLinkHaveUpgradeArrow about each item, which
-- answers nil past its budget or without an item's data, so check back soon on a timer; and register as a third-party bag, to
-- hear when arrows may have changed. caches.md §2a.
---@class Pawn: AceModule
---@field keys table<string, string> What each link's answer is kept under (keyOf).
---@field links table<string, string> The link to ask about for each key: the last one the bags were seen holding.
---@field answers table<string, boolean> What Pawn last said about each key: shown until it says otherwise.
---@field answeredAt table<string, number> The upgrade generation each answer was asked in; older, it waits to be checked again.
---@field queue table<number, string> The keys waiting to be asked, from first to last.
---@field queued table<string, boolean> Which keys are in the queue.
---@field first number Where the queue starts.
---@field last number Where the queue ends.
---@field unsure table<string, number> How many times Pawn has answered nil about each key since it last answered.
---@field gaveUp table<string, boolean> Keys that stopped waiting after too many of those; until answered, a bag shows them as not known.
---@field changed table<string, boolean> Keys whose answer the bags have not been shown since it changed.
---@field arrowChanged boolean Whether one of those changes an arrow, rather than only making an answer known.
---@field changedAt? number When the oldest of those was marked.
---@field turnWaiting boolean A turn of asking is on a timer: there is never more than one.
---@field recalculatedAt? number When the bags were last recalculated for changed answers.
local pawn = addon:NewModule('Pawn')

-- Pawn's budget for the question comes back every quarter second (Pawn.lua, BudgetThrottle), so a turn sooner finds it spent.
local TURN_SECONDS = 0.25
-- Nil from a link with no data looks the same as nil from a spent budget. After this many, a link waits for the next read, so
-- one Pawn can never answer about does not keep the timer going.
local MAX_UNSURE = 20
-- Changed arrows recalculate the bags at most this often while others still wait: a scale edit can change many.
local RECALCULATE_SECONDS = 1
-- First answers that move no arrow wait this long for one, or for the queue to empty, which it may not while Pawn keeps signalling.
local FIRST_ANSWERS_SECONDS = 5
-- A link without the two fields that follow the player, after the item ID and seven more (warcraft.wiki.gg, itemLink).
local LEVEL_AND_SPEC = "(|Hitem:%d*" .. string.rep(":[^:|]*", 7) .. "):[^:|]*:[^:|]*"

-- Whether Pawn can answer. It answers nothing until it has started, or ever, if its start-up failed, printing a failure each time.
---@return boolean
local function pawnIsReady()
  return not PawnIsReady or PawnIsReady()
end

-- Forget drops every answer and everything waiting. A turn already on the timer runs, and finds nothing.
function pawn:Forget()
  self.keys, self.links, self.answers, self.answeredAt = {}, {}, {}, {}
  self.unsure, self.gaveUp, self.changed, self.arrowChanged, self.changedAt = {}, {}, {}, false, nil
  self.queue, self.queued, self.first, self.last = {}, {}, 1, 0
end

-- keyOf is what a link's answer is kept under: the link without the player's level and spec, which every bag item's link
-- carries. A level-up or a respec changes every link in the bags, and keeps every arrow until its turn to be checked again.
---@private
---@param link string
---@return string
function pawn:keyOf(link)
  local key = self.keys[link]
  if not key then
    key = (string.gsub(link, LEVEL_AND_SPEC, "%1::", 1))
    self.keys[link] = key
  end
  return key
end

-- Waiting is how many items wait to be asked about.
---@return number
function pawn:Waiting()
  return self.last - self.first + 1
end

-- scheduleTurn puts a turn on the timer unless one is there already, however many ask for it.
---@private
function pawn:scheduleTurn()
  if self.turnWaiting then
    return
  end
  self.turnWaiting = true
  C_Timer.After(TURN_SECONDS, function() self:Turn() end)
end

-- wait has a key wait for its turn, in the queue once whoever asks: at the front when it shows no answer yet, else at the back,
-- behind what already waits, so what waits is never pushed back and nothing starves however often Pawn signals.
---@private
---@param key string
---@param link string The link to ask about: the one the bags hold now.
---@param soonest? boolean
function pawn:wait(key, link, soonest)
  self.links[key] = link
  if not self.queued[key] then
    self.queued[key] = true
    if soonest then
      self.first = self.first - 1
      self.queue[self.first] = key
    else
      self.last = self.last + 1
      self.queue[self.last] = key
    end
  end
  -- Even when it was queued: a turn that raised an error put no other on the timer.
  self:scheduleTurn()
end

-- keep records what Pawn said about a key, under the generation it was asked in: a signal from inside the question came after
-- the question was asked. An answer the bags have not been shown is marked: a first one that is no upgrade moves no arrow, but
-- the item shows as not known until it arrives.
---@private
---@param key string
---@param answer boolean
---@param generation number
---@param shown boolean Whether the read asking shows it to every bag waiting on it.
function pawn:keep(key, answer, generation, shown)
  local was = self.answers[key]
  if not shown and was ~= answer then
    self.changed[key] = true
    self.changedAt = self.changedAt or GetTime()
    self.arrowChanged = self.arrowChanged or (was == true) ~= answer
  end
  self.answers[key], self.answeredAt[key], self.unsure[key] = answer, generation, nil
end

-- Answer is the upgrade provider: what the bags show for an item, from what Pawn last said about its link. A link never seen is
-- asked about here, so a looted item has its arrow on the read that found it, unless Pawn's budget is spent. One that is out of
-- date keeps its answer while it waits for its turn, and is not asked about in a read: that was the freeze on every loot.
---@param data ItemData
---@return boolean?
function pawn:Answer(data)
  if not data or data.isItemEmpty or not data.itemInfo or not data.itemInfo.itemLink then
    return false
  end
  if not pawnIsReady() then
    return false
  end
  local link = data.itemInfo.itemLink
  local key = self:keyOf(link)
  local answer = self.answers[key]
  local generation = items:GetUpgradeGeneration()
  if answer ~= nil then
    if self.answeredAt[key] ~= generation then
      self:wait(key, link)
    end
    return answer
  end
  -- Pawn reads only item links (PawnGetItemData). A caged pet's is a battlepet: link, which it could never answer about.
  if not strfind(link, "|Hitem:", 1, true) then
    return false
  end
  answer = PawnShouldItemLinkHaveUpgradeArrow(link, true)
  if answer == nil then
    self:wait(key, link, true)
    return nil
  end
  -- Another bag's read may have found no answer for it, and must be told.
  local otherBags = self.queued[key] or self.gaveUp[key]
  self:keep(key, answer, generation, not otherBags)
  if otherBags then
    self:scheduleTurn()
  end
  return answer
end

-- notSure sends a key Pawn answered nil about to the back of the queue, so it holds nothing up, or, after enough of them, out of
-- it until a read wants it again.
---@private
---@param key string
function pawn:notSure(key)
  local times = (self.unsure[key] or 0) + 1
  if times < MAX_UNSURE then
    self.unsure[key] = times
    self:wait(key, self.links[key])
  else
    self.unsure[key], self.gaveUp[key] = nil, true
  end
end

-- holdsChanged says whether a bag holds an item whose answer changed.
---@private
---@param kind BagKind
---@return boolean
function pawn:holdsChanged(kind)
  local info = items:GetAllSlotInfo()[kind]
  for _, item in pairs(info and info.itemsBySlotKey or {}) do
    local link = item.itemInfo and item.itemInfo.itemLink
    if link and self.changed[self:keyOf(link)] then
      return true
    end
  end
  return false
end

-- recalculate shows answers that changed: the open bags holding them are recalculated, reading nothing and working out no
-- category, and a button draws only if what it shows changed (item-drawing.md §7b). No changed answer, no recalculation. While
-- others wait a changed arrow is worth one at most so often, and what only became known goes with it, or at the end, or later.
---@private
function pawn:recalculate()
  if next(self.changed) == nil then
    return
  end
  local now = GetTime()
  if self:Waiting() > 0 then
    if self.arrowChanged then
      if self.recalculatedAt and now - self.recalculatedAt < RECALCULATE_SECONDS then
        return
      end
    elseif now - self.changedAt < FIRST_ANSWERS_SECONDS then
      return
    end
  end
  local backpack = self:holdsChanged(const.BAG_KIND.BACKPACK)
  local bank = addon.atBank == true and self:holdsChanged(const.BAG_KIND.BANK)
  local guild = addon.atGuildBank == true and self:holdsChanged(const.BAG_KIND.GUILD)
  self.changed, self.arrowChanged, self.changedAt = {}, false, nil
  if backpack or bank or guild then
    self.recalculatedAt = now
    events:SendMessage(context:New('PawnAnswers'), 'bags/Rederive',
      { backpack = backpack, bank = bank, guild = guild, categoriesUnchanged = true })
  end
end

-- Turn asks about what waits until Pawn's budget for this quarter second is spent, then shows what changed. It returns how many
-- it asked about and how many still wait, or why it did nothing, for profiler traces.
---@return number|string asked
---@return number? waiting
function pawn:Turn()
  self.turnWaiting = false
  if items:GetActiveUpgradeProvider() ~= "Pawn" or not pawnIsReady() then
    self:Forget()
    return "not asking"
  end
  -- What waits keeps its answer meanwhile. Pawn skips its own check of the gear in combat too (PawnOnInventoryChanged).
  if InCombatLockdown() then
    if self:Waiting() > 0 then
      self:scheduleTurn()
    end
    self:recalculate()
    return "in combat"
  end
  local asked = 0
  while self:Waiting() > 0 do
    local key = self.queue[self.first]
    self.queue[self.first], self.queued[key] = nil, nil
    self.first = self.first + 1
    local generation = items:GetUpgradeGeneration()
    if self.answeredAt[key] ~= generation then
      local answer = PawnShouldItemLinkHaveUpgradeArrow(self.links[key], true)
      if answer == nil then
        self:notSure(key)
        break
      end
      self:keep(key, answer, generation, false)
      asked = asked + 1
    end
  end
  if self:Waiting() > 0 then
    self:scheduleTurn()
  end
  self:recalculate()
  return asked, self:Waiting()
end

-- OnArrowsReset is Pawn saying arrows may have changed (PawnResetBags, through RefreshAll): on its scale and setting edits, its
-- spec changes, and its check after every inventory change, which is most loots, though few of those change an answer. Every
-- item the bags hold is checked again, a few at a time, showing its old answer meanwhile. Nothing is cleared and nothing is
-- refreshed: another signal while items wait costs nothing, those keep their turn, and what was answered goes behind them.
---@return number|string
function pawn:OnArrowsReset()
  if items:GetActiveUpgradeProvider() ~= "Pawn" then
    -- What it knows goes out of date while it misses these.
    self:Forget()
    return "not the provider"
  end
  items:InvalidateUpgrades(false)
  for _, info in pairs(items:GetAllSlotInfo()) do
    for _, item in pairs(info.itemsBySlotKey or {}) do
      local link = item.itemInfo and item.itemInfo.itemLink
      if link and strfind(link, "|Hitem:", 1, true) then
        local key = self:keyOf(link)
        self:wait(key, link, self.answers[key] == nil)
      end
    end
  end
  return self:Waiting()
end

-- Register registers with Pawn. It returns true once that has happened, and false while Pawn's API is not there yet, so OnEnable
-- can retry after Pawn finishes loading (Pawn may load after BetterBags enables its modules). Registering also turns off Pawn's
-- arrows on Blizzard's own bags and bank (PawnBags.lua).
---@return boolean
function pawn:Register()
  if self._registered then
    return true
  end
  if not PawnShouldItemLinkHaveUpgradeArrow or not PawnRegisterThirdPartyBag then
    -- PawnRegisterThirdPartyBag came with Pawn 2.13.1.
    if PawnVersion and not self._toldTooOld then
      self._toldTooOld = true
      print("BetterBags: this version of Pawn is too old to show upgrade arrows. Please update Pawn.")
    end
    return false
  end
  items:RegisterUpgradeProvider("Pawn", function(data) return self:Answer(data) end)
  PawnRegisterThirdPartyBag("BetterBags", { RefreshAll = function() self:OnArrowsReset() end })
  self._registered = true
  print("BetterBags: Pawn integration enabled.")
  return true
end

function pawn:OnEnable()
  if self:Register() then
    return
  end
  -- Pawn is not loaded yet; retry as addons finish loading so the provider
  -- still appears once Pawn is present (load-order resilience). When it finally
  -- registers, request a refresh so already-drawn arrows re-resolve against it.
  events:RegisterEvent("ADDON_LOADED", function(ctx)
    if pawn._registered then return end
    if pawn:Register() then
      events:SendMessage(ctx, 'bags/Rederive', { categoriesUnchanged = true })
    end
  end)
end

pawn:Forget()
