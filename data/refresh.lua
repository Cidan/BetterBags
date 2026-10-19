local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class (exact) Refresh: AceModule
local refresh = addon:NewModule('Refresh')

-- How long a sort waits for its item moves before refreshing anyway. WoW has no "sort
-- finished" event, and a sort that moves nothing fires no BAG_UPDATE at all.
refresh.SORT_FALLBACK_SECONDS = 0.5

-- The startup read (.claude/rules/refresh-scheduler.md §8). How long the bags may keep
-- changing after the loading screen before the read runs anyway:
refresh.STARTUP_SETTLE_TIMEOUT = 2
-- How long to wait for the item data before reading anyway (the late data is read again):
refresh.STARTUP_PRIME_TIMEOUT = 2
-- Seconds a bank open waits for the bank's item data before reading it anyway (the captured
-- opens received it 1.2 s after BANKFRAME_OPENED).
refresh.BANK_PRIME_TIMEOUT = 2
-- Seconds a bank open waits for the bank window to say it has finished showing before loading the
-- bank anyway (Escape can hide it mid-animation while the bank stays open). The longest built-in
-- show animation is BetterBags Next's 0.45 s slide.
refresh.BANK_SHOW_TIMEOUT = 1
-- How long after PLAYER_ENTERING_WORLD to stop waiting for the end of the loading screen:
refresh.STARTUP_LOADING_TIMEOUT = 10
-- The guild bank (guild-bank.md §3). Seconds it waits for its window to say it has finished
-- showing before loading its tabs anyway, as the bank does (BANK_SHOW_TIMEOUT):
refresh.GUILD_SHOW_TIMEOUT = 1
-- Seconds a guild bank tab waits for its items' data before it is read anyway (the late data is
-- read again), as a bank open does (BANK_PRIME_TIMEOUT):
refresh.GUILD_PRIME_TIMEOUT = 2

-- The events the startup frame listens to. The bag events mean the client is still
-- delivering the bags.
local STARTUP_EVENTS = { 'PLAYER_ENTERING_WORLD', 'LOADING_SCREEN_DISABLED', 'BAG_UPDATE', 'BAG_CONTAINER_UPDATE' }

---@param name string
---@return boolean
local function isEventValid(name)
  if _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
    return _G.C_EventUtils.IsEventValid(name)
  end
  return true
end

function refresh:Init()
  -- Serialized refresh queue. RequestUpdate only enqueues; the pump (_Step) runs exactly
  -- ONE unit at a time in a single coroutine, with a deliberate idle hand-off frame
  -- between units. Because no two sweeps are ever in flight, no request-time side effect
  -- (ClearItemCache / ClearNewItems / Sort) can mutate state a parked sweep still depends
  -- on, and a unit's commit+draw can never share a frame with the next unit's harvest.
  self._queue = {}
  self._active = nil
  self._idlePending = false
  self._running = false
  -- While held (from OnEnable until the startup read), requests wait in the queue.
  self._held = false
  self._startup = nil
  -- The redraw asked for this frame (RequestRedraw), if any.
  self._redrawPending = nil
  -- The guild bank visit under way (_OpenGuildBank), if any.
  self._guildBankOpen = nil
end

-- RequestRedraw draws the bags again on the next frame (Redraw). Every request made in the
-- same frame shares that one draw, which restyles the buttons if any request asked for it:
-- dragging a slider asks on every value it passes, and a captured glow-intensity drag asked
-- for 22 redraws in one frame, each restyling every button.
---@param buttons? boolean
function refresh:RequestRedraw(buttons)
  local pending = self._redrawPending
  if pending then
    pending.buttons = pending.buttons or buttons == true
    return
  end
  pending = { buttons = buttons == true }
  self._redrawPending = pending
  C_Timer.After(0, function()
    self._redrawPending = nil
    self:Redraw(context:New('Redraw'), pending.buttons)
  end)
end

-- Redraw draws the bags again from their committed data: no bag is read and nothing is
-- derived. It is for settings that only change how the bags look: layout sizes, section
-- titles, how item buttons draw, the theme (.claude/rules/refresh-scheduler.md §9). With
-- buttons, every item button runs all of its setters (ItemFrame:RestyleButtons). Like the
-- draw after a sweep, it draws the backpack (which defers the draw while it is hidden) and
-- the bank only while it is shown.
---@param ctx Context
---@param buttons? boolean
function refresh:Redraw(ctx, buttons)
  if buttons then
    local itemFrame = addon:GetModule('ItemFrame', true)
    if itemFrame then
      itemFrame:RestyleButtons()
    end
  end
  local slotInfo = items:GetAllSlotInfo()
  local bags = addon.Bags
  if not slotInfo or not bags then return end
  if bags.Backpack and slotInfo[const.BAG_KIND.BACKPACK] then
    bags.Backpack:Draw(ctx, slotInfo[const.BAG_KIND.BACKPACK], function()
      events:SendMessage(ctx, 'bags/Draw/Backpack/Done')
    end)
  end
  if bags.Bank and bags.Bank:IsShown() and slotInfo[const.BAG_KIND.BANK] then
    bags.Bank:Draw(ctx, slotInfo[const.BAG_KIND.BANK], function()
      events:SendMessage(ctx, 'bags/Draw/Bank/Done')
    end)
  end
end

---@class RefreshRequest
---@field wipe? boolean Clear cache before refresh
---@field backpack? boolean Update backpack items
---@field bank? boolean Update bank items
---@field sort? boolean Sort backpack items
---@field sortBank? boolean Sort character bank items
---@field sortWarbank? boolean Sort account/warbank items
---@field bags? table<number, boolean> Table of specific bagIDs that changed
---@field resetLayout? boolean Ignore the previous gap layout and rebuild a fresh, gapless sort
---@field onlyIfSortPending? boolean Sweep each requested kind only if its sort has not been shown yet (the sort fallback)
---@field derive? boolean Recalculate from the items the last read committed, reading no bag slot (§10)
---@field restyle? boolean Every button of the swept kinds draws in full (a new draw generation)
---@field merged? number How many requests this one carries (set by merging, for profiler traces)
---@field startup? string Why the startup read ran (set on the startup read, for profiler traces)
---@field bankOpen? string Why a bank open's read ran, "primed" or "timeout" (for profiler traces)
---@field guild? boolean Update the guild bank's items (only while it is open)
---@field guildLoad? string Why a guild bank read ran, "primed" or "timeout" (for profiler traces)

---@param request RefreshRequest
---@return boolean
local function isSortRequest(request)
  return (request.sort or request.sortBank or request.sortWarbank or request.onlyIfSortPending) and true or false
end

-- canMerge says whether incoming can ride on waiting, a request that has not started.
-- waiting reads the client when it runs, after incoming was made, so it sees everything
-- incoming is about; running incoming afterwards would find nothing new. A wipe covers
-- anything. A plain request never absorbs a wipe: that would skip its check for newly
-- acquired items (MarkAddedItemsRecent does not run on wipes). A layout reset applies to
-- every kind a request names, so it only merges into a wipe, which resets every layout.
-- Sorts and the sort fallback are ordered against the sweeps around them and never merge.
-- A derive reads no bag, so a read never rides on one. A derive rides on a read that reads
-- every bag of its kinds, which recalculates everything too; a read of some bags carries
-- the others' items over without refreshing them (a re-scanned tooltip), so it does not.
---@param waiting RefreshRequest
---@param incoming RefreshRequest
---@return boolean
local function canMerge(waiting, incoming)
  if isSortRequest(waiting) or isSortRequest(incoming) then return false end
  if waiting.wipe then return true end
  if incoming.wipe then return false end
  if (waiting.resetLayout == true) ~= (incoming.resetLayout == true) then return false end
  if waiting.derive then
    return incoming.derive == true
  end
  if incoming.derive then
    return waiting.bags == nil
      and (not incoming.backpack or waiting.backpack == true)
      and (not incoming.bank or waiting.bank == true)
      and (not incoming.guild or waiting.guild == true)
  end
  return true
end

-- mergeInto folds incoming into waiting: the kinds of both, and the bags of both (none
-- named means every bag). The caller's bag tables are never changed.
---@param waiting RefreshRequest
---@param incoming RefreshRequest
local function mergeInto(waiting, incoming)
  waiting.backpack = waiting.backpack or incoming.backpack
  waiting.bank = waiting.bank or incoming.bank
  waiting.guild = waiting.guild or incoming.guild
  if waiting.wipe or not waiting.bags or not incoming.bags then
    waiting.bags = nil
  else
    local bags = {}
    for bagID in pairs(waiting.bags) do bags[bagID] = true end
    for bagID in pairs(incoming.bags) do bags[bagID] = true end
    waiting.bags = bags
  end
  waiting.restyle = waiting.restyle or incoming.restyle
  waiting.merged = (waiting.merged or 1) + (incoming.merged or 1)
end

-- RequestUpdate enqueues an update request onto the serialized refresh queue. It performs
-- NO side effects itself: the request's mutations (cache wipe, recent-item clearing,
-- Blizzard sort calls) and data sweeps all run inside the request's own unit when the
-- pump reaches it, so a request queued while another is in flight can never corrupt the
-- in-flight sweep. A request that another request still waiting in the queue already
-- covers is merged into it (canMerge). If the scheduler is idle, the first step runs
-- synchronously in this call (harvesting this frame's client state); every subsequent step
-- is handed off to the next frame via _Arm. While the scheduler is held for the startup
-- read, requests only wait.
---@param request RefreshRequest
function refresh:RequestUpdate(request)
  local waiting = self._queue[#self._queue]
  if waiting and canMerge(waiting, request) then
    mergeInto(waiting, request)
  else
    table.insert(self._queue, request)
  end
  if not self._running and not self._held then
    self._running = true
    self:_Step()
  end
end

-- _Arm schedules the next pump step for the next frame. This is the ONLY clock that steps
-- the pump: a single chain, never one-per-refresh, so step ordering is deterministic. (The
-- sort fallback timer only calls RequestUpdate.)
function refresh:_Arm()
  C_Timer.After(0, function()
    self:_Step()
  end)
end

-- _Resume advances the active unit's coroutine by one step. When the unit finishes it
-- flags an idle hand-off frame; a failed unit is dropped (reported, not swallowed) so a
-- single bad sweep cannot wedge the whole queue.
function refresh:_Resume()
  local co = self._active
  local ok, err = coroutine.resume(co)
  if not ok then
    self._active = nil
    self._idlePending = true
    if geterrorhandler then
      geterrorhandler()(err)
    end
    return
  end
  if coroutine.status(co) == 'dead' then
    self._active = nil
    self._idlePending = true
  end
end

-- _Step is one frame of the pump: advance the active unit, else burn the idle hand-off
-- frame, else start the next queued unit. When the queue drains it stops the clock.
function refresh:_Step()
  if self._active then
    self:_Resume()
    self:_Arm()
    return
  end

  if self._idlePending then
    self._idlePending = false
    self:_Arm()
    return
  end

  local request = not self._held and table.remove(self._queue, 1) or nil
  if not request then
    self._running = false
    return
  end

  self._active = coroutine.create(function()
    self:_RunUnit(request)
  end)
  self:_Resume()
  self:_Arm()
end

local function backpackSorter()
  if addon.isRetail and C_Container and C_Container.SortBags then
    return C_Container.SortBags
  end
  return _G.SortBags
end

local function bankSorter()
  if addon.isRetail and C_Container and C_Container.SortBankBags then
    return C_Container.SortBankBags
  end
  return _G.SortBankBags
end

local function warbankSorter()
  if addon.isRetail and C_Container and C_Container.SortAccountBankBags then
    return C_Container.SortAccountBankBags
  end
  return nil
end

-- _ArmSortFallback guarantees that a sort is shown even if none of its item moves ever
-- produce a refresh (the bags were already sorted, or the client refused the sort). When
-- the timer fires it requests a sweep of each kind whose sort is still unshown; that unit
-- checks again when it runs, so a moves refresh queued ahead of it is never repeated.
---@param backpack boolean
---@param bank boolean
function refresh:_ArmSortFallback(backpack, bank)
  C_Timer.After(self.SORT_FALLBACK_SECONDS, function()
    local request = { onlyIfSortPending = true }
    request.backpack = backpack and items:IsSortSweepPending(const.BAG_KIND.BACKPACK) or nil
    request.bank = bank and items:IsSortSweepPending(const.BAG_KIND.BANK) or nil
    if request.backpack or request.bank then
      self:RequestUpdate(request)
    end
  end)
end

-- _RunUnit executes a single request end-to-end inside the pump's coroutine: request-time
-- mutations and sort calls first, then the bank sweep, then the backpack sweep (each an
-- inline items:RunRefresh that yields once). Because this is the only sweep in flight,
-- ClearItemCache/ClearNewItems run with nothing parked to corrupt.
---@param request RefreshRequest
function refresh:_RunUnit(request)
  local ctx = context:New('BagUpdate')

  if request.onlyIfSortPending then
    if request.backpack and not items:IsSortSweepPending(const.BAG_KIND.BACKPACK) then
      request.backpack = nil
    end
    if request.bank and not items:IsSortSweepPending(const.BAG_KIND.BANK) then
      request.bank = nil
    end
  end

  if request.bags then
    ctx:Set('targetedBags', request.bags)
  end

  -- resetLayout collapses any persistent item gaps: the sweep rebuilds a fresh,
  -- gapless sort instead of diffing against the previous layout. Set before the
  -- bank ctx:Copy() below so both kinds inherit it.
  if request.resetLayout then
    ctx:Set('resetLayout', true)
  end

  if request.derive then
    ctx:Set('derive', true)
  end
  if request.restyle then
    ctx:Set('restyle', true)
  end

  if request.wipe then
    items:ClearItemCache(ctx)
    ctx:Set('wipe', true)
    request.backpack = true
    request.bank = true
    request.guild = true
  end

  -- Sorting. Every sorted kind is marked "sort sweep pending": the next committed sweep of
  -- that kind re-reads all of its bags with a fresh layout and clears the mark. When the
  -- client can sort now, the sort is issued here and this unit does not sweep that kind,
  -- since the sweep would only redraw the pre-sort contents the moves replace a moment
  -- later; the moves' BAG_UPDATE refresh shows the result, and the fallback timer covers a
  -- sort that moves nothing. When it cannot sort (combat, no sort API), the kind is swept
  -- here, now. The mark and the fallback are set before any call that could fail.
  local sorters = {}
  local deferBackpack, deferBank = false, false
  local canSort = not InCombatLockdown()
  local sortsBank = request.sortBank or request.sortWarbank

  if request.sort then
    items:MarkSortSweepPending(const.BAG_KIND.BACKPACK)
    local sorter = canSort and backpackSorter() or nil
    if sorter then
      table.insert(sorters, sorter)
      deferBackpack = true
    else
      request.backpack = true
    end
  end

  if sortsBank then
    items:MarkSortSweepPending(const.BAG_KIND.BANK)
    local bank = request.sortBank and canSort and bankSorter() or nil
    local warbank = request.sortWarbank and canSort and warbankSorter() or nil
    if bank then table.insert(sorters, bank) end
    if warbank then table.insert(sorters, warbank) end
    if bank or warbank then
      deferBank = true
    else
      request.bank = true
    end
  end

  if deferBackpack or deferBank then
    self:_ArmSortFallback(deferBackpack, deferBank)
  end

  if request.sort then
    items:ClearNewItems(const.BAG_KIND.BACKPACK)
  end
  if sortsBank then
    items:ClearNewItems(const.BAG_KIND.BANK)
  end

  for _, sorter in ipairs(sorters) do
    sorter()
  end

  -- While the bank window shows after an open, the bank is not swept: the open's read, which
  -- follows, reads every bank bag (_OpenBank).
  if request.bank and addon.atBank and addon.Bags.Bank and not self:BankShowing() then
    local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
    if addon.atWarbank and addon.Bags.Bank.bankTab and accountBankStart and addon.Bags.Bank.bankTab < accountBankStart then
      addon.Bags.Bank.bankTab = accountBankStart
    end

    items:RunRefresh(ctx:Copy(), const.BAG_KIND.BANK)
  end

  -- While the guild bank window shows after an open, the guild bank is not swept: its tabs load
  -- after, and each is read as it arrives (_GuildTabLoaded).
  if request.guild and addon.atGuildBank and addon.Bags.GuildBank and not self:GuildBankShowing() then
    items:RunRefresh(ctx:Copy(), const.BAG_KIND.GUILD)
  end

  if request.backpack then
    items:RunRefresh(ctx, const.BAG_KIND.BACKPACK)
  end
end

function refresh:OnEnable()
  local itemLoader = addon:GetModule('ItemLoader')
  itemLoader:TellMeWhenABagIsUpdated(function(updatedBags)
    local backpackChanged = false
    local bankChanged = false

    for bagID in pairs(updatedBags) do
      if const.BACKPACK_BAGS[bagID] then
        backpackChanged = true
      elseif const.BANK_BAGS[bagID] or (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagID]) then
        bankChanged = true
      end
    end

    if backpackChanged or bankChanged then
      self:RequestUpdate({
        backpack = backpackChanged,
        bank = bankChanged,
        bags = updatedBags
      })
    end
  end)

  events:RegisterMessage('bags/RefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)
  events:RegisterMessage('bags/FullRefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)
  events:RegisterMessage('bags/RefreshBackpack', function()
    self:RequestUpdate({ backpack = true })
  end)
  -- bags/Redraw (ctx, { buttons = boolean }?) redraws without reading the bags.
  events:RegisterMessage('bags/Redraw', function(_, options)
    self:RequestRedraw(options ~= nil and options.buttons == true)
  end)
  -- bags/Rederive (ctx, { backpack?, bank?, guild?, resetLayout?, buttons? }?) recalculates the
  -- bags from the items already read (§10); naming no kind recalculates every kind. buttons makes
  -- every button draw in full, for settings the buttons draw from.
  events:RegisterMessage('bags/Rederive', function(_, options)
    options = options or {}
    local all = options.backpack == nil and options.bank == nil and options.guild == nil
    self:RequestUpdate({
      derive = true,
      backpack = (all or options.backpack == true) or nil,
      bank = (all or options.bank == true) or nil,
      guild = (all or options.guild == true) or nil,
      resetLayout = options.resetLayout == true or nil,
      restyle = options.buttons == true or nil,
    })
  end)
  events:RegisterMessage('bags/RefreshBank', function()
    self:RequestUpdate({ bank = true })
  end)
  events:RegisterMessage('bags/SortBackpack', function()
    -- Sorting the backpack while the bank is open also sorts the open bank, so a
    -- single right-click cleans up everything on screen (restores the classic
    -- "sort inventory also sorts the bank" behavior). Both bank sorts ride the
    -- same serialized refresh unit as the backpack sort.
    local request = { sort = true }
    if addon.atBank then
      request.sortBank = true
      if addon.hasWarbank then
        request.sortWarbank = true
      end
    end
    self:RequestUpdate(request)
  end)
  events:RegisterMessage('bags/SortBank', function()
    self:RequestUpdate({ sortBank = true })
  end)
  events:RegisterMessage('bags/SortWarbank', function()
    self:RequestUpdate({ sortWarbank = true })
  end)

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  -- Gear sets come from the set map rebuilt every sweep, never from a bag slot.
  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:RequestUpdate({ derive = true, backpack = true, bank = true, resetLayout = true })
  end)

  events:RegisterEvent('BANKFRAME_OPENED', function()
    if GameMenuFrame:IsShown() then
      return
    end
    addon.atBank = true
    if addon.isRetail and database:GetShowBankTabs()
      and addon.Bags and addon.Bags.Bank then
      local slots = addon.Bags.Bank.slots
      local firstButton = slots and slots.buttons and slots.buttons[1]
      if firstButton then
        addon.Bags.Bank.blizzardBankTab = firstButton.bagIndex
      end
    end
    self:_OpenBank(context:New('BANKFRAME_OPENED'))
  end)

  events:RegisterEvent('BANKFRAME_CLOSED', function()
    addon.atBank = false
    self._bankOpen = nil
  end)

  if not addon.isRetail then
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
      self:RequestUpdate({ bank = true, bags = { [-1] = true } })
    end)
  elseif addon.isForever then
    -- A bag placed in or removed from a bank tab's bag socket resizes that tab's
    -- container, so sweep every bank bag. Bag -1 is the keyring on Forever.
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
      self:RequestUpdate({ bank = true })
    end)
  end

  -- The guild bank (guild-bank.md §3), told by the guild bank's data source (data/guildbank.lua).
  events:RegisterMessage('guildbank/Opened', function(ctx)
    self:_OpenGuildBank(ctx)
  end)
  events:RegisterMessage('guildbank/TabLoaded', function(_, tab)
    self:_GuildTabLoaded(tab)
  end)
  events:RegisterMessage('guildbank/Changed', function()
    self:_GuildBankChanged()
  end)
  events:RegisterMessage('guildbank/TabsChanged', function()
    self:RequestUpdate({ guild = true })
  end)
  events:RegisterMessage('guildbank/Closed', function(ctx)
    self._guildBankOpen = nil
    items:ClearGuildBankCache(ctx)
  end)

  self:HoldForStartup()
end

-- _OpenGuildBank shows the guild bank's window at once and loads its tabs only once the window has
-- finished showing, as a bank open does (_OpenBank). Without a window that shows the guild bank (the
-- classic bags), Blizzard's own guild bank frame shows it and nothing is read.
---@param ctx Context
function refresh:_OpenGuildBank(ctx)
  local bag = addon.Bags and addon.Bags.GuildBank
  if bag == nil then
    return
  end
  local open = { showing = true, read = false }
  self._guildBankOpen = open
  C_Timer.After(self.GUILD_SHOW_TIMEOUT, function() self:_GuildBankShown(open, 'timeout') end)
  bag:Show(ctx, nil, function() self:_GuildBankShown(open, 'finished') end)
end

-- _GuildBankShown ends a guild bank open's wait for its window, once, and loads its tabs
-- (GuildBank:Load). reason says what ended it. It returns what it did, for profiler traces:
-- "loading", "already" (the wait had ended) or "ended" (the visit has ended).
---@param open table
---@param reason string
---@return string
function refresh:_GuildBankShown(open, reason)
  local _ = reason
  if self._guildBankOpen ~= open then
    return 'ended'
  end
  if not open.showing then
    return 'already'
  end
  open.showing = false
  addon:GetModule('GuildBank'):Load()
  return 'loading'
end

-- GuildBankShowing says the guild bank window is still showing after an open: nothing reads it.
---@return boolean
function refresh:GuildBankShowing()
  return self._guildBankOpen ~= nil and self._guildBankOpen.showing == true
end

-- _PrimeGuildAndRead loads the item data of the guild bank tabs given, then reads the guild bank;
-- the first read of a visit rebuilds the layout. It reads after GUILD_PRIME_TIMEOUT if the data has
-- not all arrived, and again when it does. Nothing happens for a visit that has ended.
---@param tabs number[]
function refresh:_PrimeGuildAndRead(tabs)
  local open = self._guildBankOpen
  if open == nil or open.showing then
    return
  end
  local read = false
  local function readGuild(reason)
    if self._guildBankOpen ~= open then return end
    if read then
      if reason == 'primed' then
        self:RequestUpdate({ guild = true })
      end
      return
    end
    read = true
    local first = not open.read
    open.read = true
    self:RequestUpdate({ guild = true, resetLayout = first or nil, guildLoad = reason })
  end
  C_Timer.After(self.GUILD_PRIME_TIMEOUT, function() readGuild('timeout') end)
  addon:GetModule('ItemLoader'):PrimeGuildBank(tabs, function() readGuild('primed') end)
end

-- _GuildTabLoaded reads a guild bank tab the server has sent (GuildBank:Load), once its items' data
-- has loaded.
---@param tab number
function refresh:_GuildTabLoaded(tab)
  self:_PrimeGuildAndRead({ tab })
end

-- _GuildBankChanged reads the guild bank's loaded tabs again when something in them changed (an item
-- moved, or locked while another player moves it), once their items' data has loaded.
function refresh:_GuildBankChanged()
  local guildBank = addon:GetModule('GuildBank')
  local tabs = {}
  for container in pairs(guildBank:LoadedContainers()) do
    table.insert(tabs, guildBank:TabOf(container))
  end
  table.sort(tabs)
  self:_PrimeGuildAndRead(tabs)
end

-- HoldForStartup holds every sweep until the client has delivered the bags, then reads
-- them once (.claude/rules/refresh-scheduler.md §8). At PLAYER_LOGIN, when OnEnable runs,
-- the client has not attached the bags or sent their contents yet: a captured login read a
-- backpack of 20 empty slots here, and the bags then arrived over five seconds, each step
-- requesting another sweep. Requests made meanwhile wait in the queue; the startup read
-- absorbs them. The read runs:
--   1. after the loading screen ends (LOADING_SCREEN_DISABLED, or PLAYER_ENTERING_WORLD
--      where the client lacks it, or STARTUP_LOADING_TIMEOUT after PLAYER_ENTERING_WORLD),
--   2. at the first frame without bag events (or after STARTUP_SETTLE_TIMEOUT),
--   3. once the item data of every bag slot and equipped slot has loaded (or after
--      STARTUP_PRIME_TIMEOUT; the late data is read again when it arrives).
-- Opening the backpack before then reads at once.
function refresh:HoldForStartup()
  self._held = true
  self._startup = { phase = 'loading', bagActivity = false }
  addon:GetModule('ItemLoader'):Hold()

  local frame = self._startupFrame
  if not frame then
    frame = CreateFrame('Frame')
    self._startupFrame = frame
  end
  for _, event in ipairs(STARTUP_EVENTS) do
    if isEventValid(event) then
      frame:RegisterEvent(event)
    end
  end
  frame:SetScript('OnEvent', function(_, event)
    self:_OnStartupEvent(event)
  end)

  local backpack = addon.Bags and addon.Bags.Backpack
  if backpack and backpack.frame then
    addon.HookScript(backpack.frame, 'OnShow', function()
      self:_OnStartupBagShown()
    end)
  end
end

---@param event string
function refresh:_OnStartupEvent(event)
  local startup = self._startup
  if not startup then return end
  if event == 'BAG_UPDATE' or event == 'BAG_CONTAINER_UPDATE' then
    startup.bagActivity = true
  elseif event == 'LOADING_SCREEN_DISABLED' then
    self:_StartupSettle()
  elseif event == 'PLAYER_ENTERING_WORLD' then
    if not isEventValid('LOADING_SCREEN_DISABLED') then
      self:_StartupSettle()
    else
      C_Timer.After(self.STARTUP_LOADING_TIMEOUT, function()
        self:_StartupSettle()
      end)
    end
  end
end

-- _StartupSettle starts waiting for a frame without bag events. Frames do not run during
-- the loading screen, so the first one comes after it.
function refresh:_StartupSettle()
  local startup = self._startup
  if not startup or startup.phase ~= 'loading' then return end
  startup.phase = 'settling'
  startup.bagActivity = false
  startup.settleStart = GetTime()
  self._startupFrame:SetScript('OnUpdate', function()
    self:_OnStartupFrame()
  end)
end

function refresh:_OnStartupFrame()
  local startup = self._startup
  if not startup or startup.phase ~= 'settling' then return end
  if startup.bagActivity and GetTime() - startup.settleStart < self.STARTUP_SETTLE_TIMEOUT then
    startup.bagActivity = false
    return
  end
  self:_StartupPrime()
end

-- _OpenBank shows the bank window at once (with the bank's committed items: none after a close)
-- and loads the bank only once the window has finished showing, so the bank's read and draw never
-- land in its show animation (asked: "finish our bank window show animation, before we start
-- loading in bank info, just to prevent hitching"; refresh-scheduler.md §11). Until then no sweep
-- reads the bank (_RunUnit): the open's read reads every bank bag after.
---@param ctx Context
function refresh:_OpenBank(ctx)
  local open = { showing = true }
  self._bankOpen = open
  C_Timer.After(self.BANK_SHOW_TIMEOUT, function() self:_BankShown(open, 'timeout') end)
  if addon.Bags and addon.Bags.Bank then
    addon.Bags.Bank:Show(ctx, nil, function() self:_BankShown(open, 'finished') end)
  else
    self:_BankShown(open, 'no window')
  end
end

-- _BankShown ends a bank open's wait for its window, once, and loads the bank. reason says what
-- ended it ("finished", "timeout", "no window"). It returns what it did, for profiler traces:
-- "loading", "already" (the wait had ended) or "ended" (the open has ended).
---@param open table
---@param reason string
---@return string
function refresh:_BankShown(open, reason)
  local _ = reason
  if self._bankOpen ~= open then
    return 'ended'
  end
  if not open.showing then
    return 'already'
  end
  open.showing = false
  self:_PrimeBankAndRead(open)
  return 'loading'
end

-- BankShowing says the bank window is still showing after a bank open: nothing reads the bank.
---@return boolean
function refresh:BankShowing()
  return self._bankOpen ~= nil and self._bankOpen.showing == true
end

-- _PrimeBankAndRead loads the bank's item data, then reads the bank, from a clean, gapless
-- layout (gaps held from a previous visit collapse). It reads after BANK_PRIME_TIMEOUT if the
-- data has not all arrived, and reads again when it does, since that read found it cold.
-- Neither happens for an open that has ended (the bank closed, or opened again).
---@param open table The open being loaded (refresh._bankOpen).
function refresh:_PrimeBankAndRead(open)
  local read = false
  local function readBank(reason)
    if self._bankOpen ~= open then return end
    if read then
      if reason == 'primed' then
        self:RequestUpdate({ bank = true })
      end
      return
    end
    read = true
    self:RequestUpdate({ bank = true, resetLayout = true, bankOpen = reason })
  end
  C_Timer.After(self.BANK_PRIME_TIMEOUT, function() readBank('timeout') end)
  addon:GetModule('ItemLoader'):PrimeBank(function() readBank('primed') end)
end

-- _StartupPrime loads the item data of every bag slot and every equipped slot, then reads.
function refresh:_StartupPrime()
  local startup = self._startup
  if not startup or startup.priming then return end
  startup.phase = 'priming'
  startup.priming = true
  self._startupFrame:SetScript('OnUpdate', nil)
  C_Timer.After(self.STARTUP_PRIME_TIMEOUT, function()
    self:_StartupRead('timeout')
  end)
  addon:GetModule('ItemLoader'):PrimeAll(function()
    self:_OnStartupPrimed()
  end)
end

function refresh:_OnStartupPrimed()
  if self._startup then
    self:_StartupRead('primed')
    return
  end
  -- The read ran before the item data arrived (timeout, or the backpack opened), so the
  -- items it read cold are read again.
  self:RequestUpdate({ backpack = true, bank = true })
end

function refresh:_OnStartupBagShown()
  local startup = self._startup
  if not startup then return end
  if not startup.priming then
    -- Reads at once when the item data is already loaded.
    self:_StartupPrime()
  end
  self:_StartupRead('bagShown')
end

-- _StartupRead ends the hold: one wipe of both kinds absorbs every request made while
-- held, and sorts asked for meanwhile run after it.
---@param reason string
function refresh:_StartupRead(reason)
  if not self._startup then return end
  self._startup = nil
  local frame = self._startupFrame
  frame:SetScript('OnUpdate', nil)
  frame:SetScript('OnEvent', nil)
  for _, event in ipairs(STARTUP_EVENTS) do
    frame:UnregisterEvent(event)
  end
  addon:GetModule('ItemLoader'):Release()

  ---@type RefreshRequest
  local read = { wipe = true, backpack = true, bank = true, startup = reason, merged = 0 }
  local queue = { read }
  for _, request in ipairs(self._queue) do
    if isSortRequest(request) then
      table.insert(queue, request)
    else
      read.merged = read.merged + (request.merged or 1)
    end
  end
  self._queue = queue
  self._held = false
  if not self._running then
    self._running = true
    self:_Step()
  end
end
