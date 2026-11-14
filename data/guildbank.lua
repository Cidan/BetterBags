local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- GuildBank is the guild bank as a source of items for the data engine (guild-bank.md §2): whether
-- it is open, its tabs and their permissions, which tabs the client has received, a slot's
-- contents, and the actions on it. It reads and asks; the data phase reads the slots it names
-- (items:Phase2_Harvest), and what shows the guild bank (BetterBags Next's panel) draws them.
--
-- Two rules come from Blizzard's own guild bank frame (Blizzard_GuildBankUI, Mainline and TBC):
-- - A tab's contents come from the server: its tab click makes the tab current and queries it
--   (GuildBankTabMixin:OnClick: SetCurrentGuildBankTab, then QueryGuildBankTab), and the answer is
--   GUILDBANKBAGSLOTS_CHANGED, which names no tab. So tabs load one at a time, each answer being
--   the tab last queried (Load).
-- - Its item buttons act on the current tab only (GuildBankItemButtonMixin passes
--   GetCurrentGuildBankTab() to PickupGuildBankItem, AutoStoreGuildBankItem, SplitGuildBankItem):
--   an item of another tab is acted on once its tab is current (MakeCurrent).
-- The logs and the tabs' info text come from the server the same way (Blizzard's Log, Money Log and Info tabs):
-- QueryGuildBankLog is answered by GUILDBANKLOG_UPDATE, which names no log, so logs are asked for one at a time
-- (LoadLogs); QueryGuildBankText by GUILDBANK_UPDATE_TEXT, which names its tab, asked for one at a time too (LoadTexts).
-- None of the guild bank functions is protected (warcraft.wiki.gg World_of_Warcraft_API).
---@class GuildBank: AceModule
---@field open boolean The guild bank is open (the guild banker interaction).
---@field loaded table<number, boolean> The tabs received this visit.
---@field loading? GuildBankLoading
---@field asking table<string, GuildBankAsking> The logs ("log") and texts ("text") being asked for.
---@field logsLoaded table<number, boolean> The logs received this visit, by what QueryGuildBankLog takes.
---@field textsLoaded table<number, boolean> The tabs whose info text was received this visit.
local guildBank = addon:NewModule('GuildBank')

-- Seconds a tab's query waits for the server's answer before the tab counts as loaded anyway.
guildBank.QUERY_TIMEOUT = 2

---@class (exact) GuildBankLoading
---@field queue number[] The tabs still to query, in order.
---@field tab? number The tab queried, waiting for its answer.
---@field query? table The query waited on (a timeout of an earlier one does nothing).
---@field restore? number The tab to make current again once every tab has loaded.

---@class (exact) GuildBankAsking
---@field queue number[] What is still to ask for, in order.
---@field id? number What was asked for, waiting for its answer.
---@field query? table The question waited on (a timeout of an earlier one does nothing).

-- A log entry (ItemLog, MoneyLog). How long ago is the client's, in its parts (each of years, months, days, hours
-- counted on its own, as Blizzard's TimeUtil.GetRecentTimeDate reads them), and in hours (age: a month of thirty days,
-- a year of twelve months, as TimeUtil.lua counts them), to order entries of different logs.
---@class (exact) GuildBankLogEntry
---@field kind string Blizzard's type: "deposit", "withdraw" or "move" for an item; "deposit", "withdraw", "repair", "withdrawForTab", "buyTab", "depositSummary", "buyRename" or "refundRename" for gold.
---@field name? string Who; nil when the client does not know (Blizzard's frame says UNKNOWN).
---@field link? string The item.
---@field count? number How many.
---@field tab? number The tab whose log it is.
---@field from? number A move's tab it left.
---@field to? number A move's tab it went to.
---@field amount? number The gold, in copper.
---@field years number
---@field months number
---@field days number
---@field hours number
---@field age number How long ago, in hours.
---@field index number Its place in its log: higher is newer.

---@class (exact) GuildBankTabInfo
---@field tab number
---@field container number Its container in the data engine (const.GUILD_BANK_TAB_CONTAINER).
---@field name string
---@field icon number|string
---@field viewable boolean
---@field canDeposit boolean
---@field numWithdrawals number Stacks a day this player may withdraw (0: none, -1: no limit).
---@field remainingWithdrawals number Stacks left today (-1: no limit).

---@class (exact) GuildBankSlotRead
---@field link string
---@field texture number|string
---@field count number
---@field locked boolean Another player is moving it.
---@field isFiltered boolean
---@field quality? number

---@param name string
---@return boolean
local function isEventValid(name)
  if _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
    return _G.C_EventUtils.IsEventValid(name)
  end
  return true
end

function guildBank:Init()
  self.open = false
  self:forget()
end

-- forget drops what a visit received and anything still being asked for.
---@private
function guildBank:forget()
  self.loaded = {}
  self.loading = nil
  self.asking = {}
  self.logsLoaded = {}
  self.textsLoaded = {}
end

function guildBank:OnEnable()
  if not addon.hasGuildBank then
    return
  end
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', function(ctx, _, interactionType)
    if interactionType == Enum.PlayerInteractionType.GuildBanker then
      self:OnOpened(ctx)
    end
  end)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_HIDE', function(ctx, _, interactionType)
    if interactionType == Enum.PlayerInteractionType.GuildBanker then
      self:OnClosed(ctx)
    end
  end)
  local watched = {
    GUILDBANKBAGSLOTS_CHANGED = function(ctx) self:OnSlotsChanged(ctx) end,
    GUILDBANK_ITEM_LOCK_CHANGED = function(ctx) self:say(ctx, 'guildbank/Changed') end,
    GUILDBANK_UPDATE_TABS = function(ctx) self:say(ctx, 'guildbank/TabsChanged') end,
    GUILDBANK_UPDATE_MONEY = function(ctx) self:say(ctx, 'guildbank/MoneyChanged') end,
    GUILDBANK_UPDATE_WITHDRAWMONEY = function(ctx) self:say(ctx, 'guildbank/MoneyChanged') end,
    GUILDBANKLOG_UPDATE = function(ctx) self:OnLogUpdate(ctx) end,
    GUILDBANK_UPDATE_TEXT = function(ctx, _, tab) self:OnTextUpdate(ctx, tonumber(tab)) end,
    GUILDBANK_TEXT_CHANGED = function(_, _, tab) self:OnTextChanged(tonumber(tab)) end,
  }
  for event, fn in pairs(watched) do
    if isEventValid(event) then
      events:RegisterEvent(event, fn)
    end
  end
end

-- say sends a guild bank message while the guild bank is open.
---@private
---@param ctx Context
---@param message string
function guildBank:say(ctx, message, ...)
  if self.open then
    events:SendMessage(ctx, message, ...)
  end
end

-- OnOpened starts a visit (the guild banker interaction): nothing is loaded yet.
---@param ctx Context
function guildBank:OnOpened(ctx)
  self.open = true
  self:forget()
  addon.atGuildBank = true
  events:SendMessage(ctx, 'guildbank/Opened')
end

-- OnClosed ends the visit, forgetting what it loaded (and any loading under way).
---@param ctx Context
function guildBank:OnClosed(ctx)
  self.open = false
  self:forget()
  addon.atGuildBank = false
  events:SendMessage(ctx, 'guildbank/Closed')
end

---@return boolean
function guildBank:IsOpen()
  return self.open
end

---@return boolean
function guildBank:IsLoading()
  return self.loading ~= nil
end

---@param tab number
---@return boolean
function guildBank:IsLoaded(tab)
  return self.loaded[tab] == true
end

---@param tab number
---@return number
function guildBank:ContainerOf(tab)
  return const.GUILD_BANK_TAB_CONTAINER[tab]
end

---@param container number
---@return number?
function guildBank:TabOf(container)
  return const.GUILD_BANK_BAGS[container]
end

-- NumTabs is how many tabs the guild bought (at most the client's MAX_GUILDBANK_TABS).
---@return number
function guildBank:NumTabs()
  return math.min(GetNumGuildBankTabs() or 0, #const.GUILD_BANK_BAGS_LIST)
end

-- TabInfo is what the guild bank says of a purchased tab, named as Blizzard's frame names it
-- (GUILDBANK_TAB_NUMBER when it has no name), or nil past the purchased tabs.
---@param tab number
---@return GuildBankTabInfo?
function guildBank:TabInfo(tab)
  if tab < 1 or tab > self:NumTabs() then
    return nil
  end
  local name, icon, viewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(tab)
  if name == nil or name == "" then
    name = format(GUILDBANK_TAB_NUMBER, tab)
  end
  return {
    tab = tab,
    container = self:ContainerOf(tab),
    name = name,
    icon = icon,
    viewable = viewable and true or false,
    canDeposit = canDeposit and true or false,
    numWithdrawals = numWithdrawals or 0,
    remainingWithdrawals = remainingWithdrawals or 0,
  }
end

-- Tabs lists the purchased tabs in order.
---@return GuildBankTabInfo[]
function guildBank:Tabs()
  local tabs = {}
  for tab = 1, self:NumTabs() do
    table.insert(tabs, self:TabInfo(tab))
  end
  return tabs
end

-- LoadedContainers is the containers of the tabs received this visit that this player can view:
-- what a read of the guild bank reads (items:Phase1_DetermineBags).
---@return table<number, number>
function guildBank:LoadedContainers()
  local containers = {}
  for tab in pairs(self.loaded) do
    local info = self:TabInfo(tab)
    if info and info.viewable then
      containers[info.container] = info.container
    end
  end
  return containers
end

-- ReadSlot is a slot's contents, or nil when it is empty (or its tab was never received).
---@param tab number
---@param slot number
---@return GuildBankSlotRead?
function guildBank:ReadSlot(tab, slot)
  local link = GetGuildBankItemLink(tab, slot)
  if link == nil then
    return nil
  end
  local texture, count, locked, isFiltered, quality = GetGuildBankItemInfo(tab, slot)
  return {
    link = link,
    texture = texture,
    count = count or 1,
    locked = locked and true or false,
    isFiltered = isFiltered and true or false,
    quality = quality,
  }
end

---@return number
function guildBank:CurrentTab()
  return GetCurrentGuildBankTab()
end

-- MakeCurrent makes a tab the current one, which is what Blizzard's guild bank acts on and where a
-- right click on a bag item deposits. It returns whether the current tab changed.
---@param tab number
---@return boolean
function guildBank:MakeCurrent(tab)
  if GetCurrentGuildBankTab() == tab then
    return false
  end
  SetCurrentGuildBankTab(tab)
  return true
end

-- Load queries every tab this player can view, one at a time, the current tab first, each made
-- current and queried as Blizzard's tab click does. Each answer marks the tab loaded and says so
-- (guildbank/TabLoaded); a tab with no answer in QUERY_TIMEOUT counts as loaded anyway. The
-- player's current tab is made current again at the end. It returns whether it started (only while
-- the guild bank is open).
---@return boolean
function guildBank:Load()
  if not self.open then
    return false
  end
  local current = GetCurrentGuildBankTab()
  local queue, queued = {}, {}
  local function add(tab)
    local info = self:TabInfo(tab)
    if info and info.viewable and not queued[tab] then
      queued[tab] = true
      table.insert(queue, tab)
    end
  end
  add(current)
  for tab = 1, self:NumTabs() do
    add(tab)
  end
  self.loading = { queue = queue, restore = current }
  self:queryNext()
  return true
end

-- LoadTab queries one tab, made current: a tab the player chose (shown by itself), queried again as
-- Blizzard's tab click does on every click. During a Load it goes first, and stays current after.
---@param tab number
---@return boolean
function guildBank:LoadTab(tab)
  if not self.open then
    return false
  end
  local loading = self.loading
  if loading then
    for i = #loading.queue, 1, -1 do
      if loading.queue[i] == tab then
        table.remove(loading.queue, i)
      end
    end
    table.insert(loading.queue, 1, tab)
    loading.restore = tab
    if loading.tab == nil then
      self:queryNext()
    end
    return true
  end
  self.loading = { queue = { tab } }
  self:queryNext()
  return true
end

-- queryNext queries the next tab of the loading under way, or ends it.
---@private
function guildBank:queryNext()
  local loading = self.loading
  if loading == nil then
    return
  end
  local tab = table.remove(loading.queue, 1)
  if tab == nil then
    self.loading = nil
    if loading.restore ~= nil then
      self:MakeCurrent(loading.restore)
    end
    return
  end
  local query = {}
  loading.tab, loading.query = tab, query
  self:MakeCurrent(tab)
  QueryGuildBankTab(tab)
  C_Timer.After(self.QUERY_TIMEOUT, function()
    if self.loading == loading and loading.query == query then
      self:TabLoaded(context:New('GuildBank_QueryTimeout'), tab, "timeout")
    end
  end)
end

-- TabLoaded marks the tab queried loaded, says so, and queries the next. how says why: the server
-- answered, or the wait timed out. It returns how, for profiler traces.
---@param ctx Context
---@param tab number
---@param how string
---@return string
function guildBank:TabLoaded(ctx, tab, how)
  local loading = self.loading
  self.loaded[tab] = true
  if loading then
    loading.tab, loading.query = nil, nil
  end
  events:SendMessage(ctx, 'guildbank/TabLoaded', tab)
  self:queryNext()
  return how
end

-- OnSlotsChanged runs when the server sends a tab (GUILDBANKBAGSLOTS_CHANGED): the answer to the
-- query under way, else a change (an item moved, by this player or another).
---@param ctx Context
---@return string what it took the event for, for profiler traces
function guildBank:OnSlotsChanged(ctx)
  if not self.open then
    return "closed"
  end
  local loading = self.loading
  if loading and loading.tab then
    return self:TabLoaded(ctx, loading.tab, "answered")
  end
  events:SendMessage(ctx, 'guildbank/Changed')
  return "changed"
end

-- Pickup picks an item up from its tab (or puts the cursor's item there), as Blizzard's item
-- button's left click does.
---@param tab number
---@param slot number
function guildBank:Pickup(tab, slot)
  self:MakeCurrent(tab)
  PickupGuildBankItem(tab, slot)
end

-- Withdraw moves an item into the bags, as Blizzard's item button's right click does.
---@param tab number
---@param slot number
function guildBank:Withdraw(tab, slot)
  self:MakeCurrent(tab)
  AutoStoreGuildBankItem(tab, slot)
end

-- Split puts part of a stack on the cursor, as Blizzard's stack split does for its item button.
---@param tab number
---@param slot number
---@param amount number
function guildBank:Split(tab, slot, amount)
  self:MakeCurrent(tab)
  SplitGuildBankItem(tab, slot, amount)
end

-- DepositSlots deposits bag slots into a tab, made current first: a bag item used at the guild bank
-- goes into the current tab, as Blizzard's right click on a bag item does
-- (ContainerFrameItemButton_OnClick: C_Container.UseContainerItem). It returns how many it deposited
-- (none once the guild bank is closed).
---@param slots {bag: number, slot: number}[]
---@param tab number
---@return number
function guildBank:DepositSlots(slots, tab)
  if not self.open then
    return 0
  end
  self:MakeCurrent(tab)
  for _, s in ipairs(slots) do
    C_Container.UseContainerItem(s.bag, s.slot)
  end
  return #slots
end

-- WithdrawItems moves guild items into the bags, each from its own tab (Withdraw). It returns how
-- many it withdrew (none once the guild bank is closed).
---@param list ItemData[]
---@return number
function guildBank:WithdrawItems(list)
  if not self.open then
    return 0
  end
  for _, data in ipairs(list) do
    self:Withdraw(data.guildTab or self:TabOf(data.bagid), data.slotid)
  end
  return #list
end

-- FreeSlot is a tab's first empty slot, read from the client now, or nil when it is full.
---@param tab number
---@return number?
function guildBank:FreeSlot(tab)
  for slot = 1, const.GUILD_BANK_SLOTS do
    if GetGuildBankItemLink(tab, slot) == nil then
      return slot
    end
  end
  return nil
end

-- PlaceCursorItem puts the item on the cursor into the first free slot of a tab: the tab asked for,
-- else the current tab, else the first other tab, each only when this player may deposit in it and
-- it has loaded (a tab never received reads as empty, and a pickup on a slot that holds an item
-- swaps the two). It returns what it did, for profiler traces: "placed", "full", "loading" (no tab
-- it could use has loaded yet) or "ignored" (no item on the cursor).
---@param tab? number
---@return string
function guildBank:PlaceCursorItem(tab)
  if GetCursorInfo() ~= "item" then
    return "ignored"
  end
  local order, seen = {}, {}
  local function add(t)
    if t ~= nil and not seen[t] then
      seen[t] = true
      table.insert(order, t)
    end
  end
  add(tab)
  add(GetCurrentGuildBankTab())
  for t = 1, self:NumTabs() do
    add(t)
  end
  local anyLoaded = false
  for _, t in ipairs(order) do
    local info = self:TabInfo(t)
    if info and info.viewable and info.canDeposit and self.loaded[t] then
      anyLoaded = true
      local slot = self:FreeSlot(t)
      if slot then
        self:Pickup(t, slot)
        return "placed"
      end
    end
  end
  if not anyLoaded then
    UIErrorsFrame:AddMessage(L:G("The guild bank is still loading."), 1.0, 0.1, 0.1, 1.0)
    return "loading"
  end
  UIErrorsFrame:AddMessage(L:G("The guild bank has no room for it."), 1.0, 0.1, 0.1, 1.0)
  return "full"
end

-- DepositMoney asks how much gold to deposit, with Blizzard's own dialog (its deposit button's).
function guildBank:DepositMoney()
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
  StaticPopup_Hide("GUILDBANK_WITHDRAW")
  StaticPopup_Show("GUILDBANK_DEPOSIT")
end

-- WithdrawMoney asks how much gold to withdraw, with Blizzard's own dialog, when this player may.
function guildBank:WithdrawMoney()
  if not CanWithdrawGuildBankMoney() then
    return
  end
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
  StaticPopup_Hide("GUILDBANK_DEPOSIT")
  StaticPopup_Show("GUILDBANK_WITHDRAW")
end

-- CanBuyTab is whether this player can buy the next tab: the guild leader, while fewer than
-- MAX_BUY_GUILDBANK_TABS are bought (Blizzard's frame offers the purchase only then).
---@return boolean
function guildBank:CanBuyTab()
  return IsGuildLeader() and (GetNumGuildBankTabs() or 0) < MAX_BUY_GUILDBANK_TABS
end

-- BuyTab asks to buy the next tab, with Blizzard's own dialog, whose accept buys it.
function guildBank:BuyTab()
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
  StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
end

-- Close ends the visit.
function guildBank:Close()
  CloseGuildBankFrame()
end

-- MoneyLogID is what QueryGuildBankLog takes for the money log: one past the tabs (GuildBankFrameTabMixin:OnClick).
---@return number
function guildBank:MoneyLogID()
  return MAX_GUILDBANK_TABS + 1
end

-- IsLogLoaded says whether a log (a tab's, or MoneyLogID's) was received this visit.
---@param id number
---@return boolean
function guildBank:IsLogLoaded(id)
  return self.logsLoaded[id] == true
end

-- IsTextLoaded says whether a tab's info text was received this visit.
---@param tab number
---@return boolean
function guildBank:IsTextLoaded(tab)
  return self.textsLoaded[tab] == true
end

-- How each kind of question is asked of the server.
local QUERIES = {
  log = function(id) QueryGuildBankLog(id) end,
  text = function(tab) QueryGuildBankText(tab) end,
}

-- ask asks for a list of logs or texts (kind "log" or "text"), one at a time: the list takes the place of what was
-- still to ask for, and what was asked for and not yet answered is not asked again. It returns whether it asks (only
-- while the guild bank is open).
---@private
---@param kind string
---@param ids number[]
---@return boolean
function guildBank:ask(kind, ids)
  if not self.open then
    return false
  end
  local asking = self.asking[kind]
  if asking == nil then
    asking = { queue = {} }
    self.asking[kind] = asking
  end
  asking.queue = {}
  for _, id in ipairs(ids) do
    if id ~= asking.id then
      table.insert(asking.queue, id)
    end
  end
  if asking.id == nil then
    self:askNext(kind)
  end
  return true
end

-- askNext asks for the next log or text in the list, or ends it. One with no answer in QUERY_TIMEOUT counts as
-- received anyway.
---@private
---@param kind string
function guildBank:askNext(kind)
  local asking = self.asking[kind]
  if asking == nil then
    return
  end
  local id = table.remove(asking.queue, 1)
  if id == nil then
    self.asking[kind] = nil
    return
  end
  local query = {}
  asking.id, asking.query = id, query
  QUERIES[kind](id)
  C_Timer.After(self.QUERY_TIMEOUT, function()
    if self.asking[kind] == asking and asking.query == query then
      self:Answered(context:New('GuildBank_AskTimeout'), kind, id, "timeout")
    end
  end)
end

-- Answered marks a log or text received, says so (guildbank/LogLoaded or guildbank/TextLoaded, with it), and asks for
-- the next when it was the one waited on. how says why: the server answered, or the wait timed out. It returns how, for
-- profiler traces.
---@param ctx Context
---@param kind string
---@param id number
---@param how string
---@return string
function guildBank:Answered(ctx, kind, id, how)
  local asking = self.asking[kind]
  local waited = asking ~= nil and asking.id == id
  if waited then
    asking.id, asking.query = nil, nil
  end
  if kind == "log" then
    self.logsLoaded[id] = true
    events:SendMessage(ctx, 'guildbank/LogLoaded', id)
  else
    self.textsLoaded[id] = true
    events:SendMessage(ctx, 'guildbank/TextLoaded', id)
  end
  if waited then
    self:askNext(kind)
  end
  return how
end

-- LoadLogs asks for logs (tabs, and MoneyLogID for the gold), one at a time: GUILDBANKLOG_UPDATE names no log, so each
-- answer is the log last asked for (OnLogUpdate). It returns whether it asks (only while the guild bank is open).
---@param ids number[]
---@return boolean
function guildBank:LoadLogs(ids)
  return self:ask("log", ids)
end

-- LoadTexts asks for tabs' info text, one at a time, as Blizzard's Info tab asks for one.
---@param tabs number[]
---@return boolean
function guildBank:LoadTexts(tabs)
  return self:ask("text", tabs)
end

-- OnLogUpdate runs when the server sends a log (GUILDBANKLOG_UPDATE): the answer to the log asked for, else a log
-- changed (guildbank/LogChanged).
---@param ctx Context
---@return string what it took the event for, for profiler traces
function guildBank:OnLogUpdate(ctx)
  if not self.open then
    return "closed"
  end
  local asking = self.asking.log
  if asking ~= nil and asking.id ~= nil then
    return self:Answered(ctx, "log", asking.id, "answered")
  end
  events:SendMessage(ctx, 'guildbank/LogChanged')
  return "changed"
end

-- OnTextUpdate runs when the server sends a tab's info text (GUILDBANK_UPDATE_TEXT, which names its tab).
---@param ctx Context
---@param tab? number
---@return string
function guildBank:OnTextUpdate(ctx, tab)
  if not self.open or tab == nil then
    return "closed"
  end
  return self:Answered(ctx, "text", tab, "answered")
end

-- OnTextChanged asks again for a tab's info text another member changed (GUILDBANK_TEXT_CHANGED), when this visit
-- received it (Blizzard's frame asks again for the tab it shows).
---@param tab? number
function guildBank:OnTextChanged(tab)
  if self.open and tab ~= nil and self.textsLoaded[tab] then
    QueryGuildBankText(tab)
  end
end

-- entryOf starts a log entry with how long ago it was: in its parts as the client gives them, and in hours (a month of
-- thirty days and a year of twelve months, as TimeUtil.lua counts them).
---@param kind string
---@param name? string
---@param index number
---@param years? number
---@param months? number
---@param days? number
---@param hours? number
---@return GuildBankLogEntry
local function entryOf(kind, name, index, years, months, days, hours)
  years, months, days, hours = years or 0, months or 0, days or 0, hours or 0
  return { kind = kind, name = name, index = index, years = years, months = months, days = days, hours = hours,
    age = ((years * 12 + months) * 30 + days) * 24 + hours }
end

-- ItemLog is a tab's item log as the client last received it, newest first (higher indices are newer,
-- warcraft.wiki.gg API_GetGuildBankTransaction). Blizzard's frame shows deposits, withdrawals and moves, and nothing
-- else (GuildBankFrame_UpdateLog).
---@param tab number
---@return GuildBankLogEntry[]
function guildBank:ItemLog(tab)
  local log = {}
  for index = GetNumGuildBankTransactions(tab) or 0, 1, -1 do
    local kind, name, link, count, from, to, years, months, days, hours = GetGuildBankTransaction(tab, index)
    if kind == "deposit" or kind == "withdraw" or kind == "move" then
      local entry = entryOf(kind, name, index, years, months, days, hours)
      entry.link, entry.count, entry.tab = link, count, tab
      if kind == "move" then
        entry.from, entry.to = from, to
      end
      table.insert(log, entry)
    end
  end
  return log
end

-- MoneyLog is the guild's money log as the client last received it, newest first. Each index is read only up to the
-- count: asked for one past it, GetGuildBankMoneyTransaction crashes the client (warcraft.wiki.gg).
---@return GuildBankLogEntry[]
function guildBank:MoneyLog()
  local log = {}
  for index = GetNumGuildBankMoneyTransactions() or 0, 1, -1 do
    local kind, name, amount, years, months, days, hours = GetGuildBankMoneyTransaction(index)
    local entry = entryOf(kind, name, index, years, months, days, hours)
    entry.amount = amount or 0
    table.insert(log, entry)
  end
  return log
end

-- Text is a tab's info text as the client last received it ("" for none).
---@param tab number
---@return string
function guildBank:Text(tab)
  return GetGuildBankText(tab) or ""
end

-- CanEditText says whether this member may edit a tab's info text.
---@param tab number
---@return boolean
function guildBank:CanEditText(tab)
  return CanEditGuildTabInfo(tab) and true or false
end

-- SaveText saves a tab's info text, as Blizzard's Info tab's Save button does. It returns whether it saved (only while
-- the guild bank is open).
---@param tab number
---@param text string
---@return boolean
function guildBank:SaveText(tab, text)
  if not self.open then
    return false
  end
  SetGuildBankText(tab, text)
  return true
end
