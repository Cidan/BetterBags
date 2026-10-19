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
-- None of the guild bank functions is protected (warcraft.wiki.gg World_of_Warcraft_API).
---@class GuildBank: AceModule
---@field open boolean The guild bank is open (the guild banker interaction).
---@field loaded table<number, boolean> The tabs received this visit.
---@field loading? GuildBankLoading
local guildBank = addon:NewModule('GuildBank')

-- Seconds a tab's query waits for the server's answer before the tab counts as loaded anyway.
guildBank.QUERY_TIMEOUT = 2

---@class (exact) GuildBankLoading
---@field queue number[] The tabs still to query, in order.
---@field tab? number The tab queried, waiting for its answer.
---@field query? table The query waited on (a timeout of an earlier one does nothing).
---@field restore? number The tab to make current again once every tab has loaded.

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
  self.loaded = {}
  self.loading = nil
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
  self.loaded = {}
  self.loading = nil
  addon.atGuildBank = true
  events:SendMessage(ctx, 'guildbank/Opened')
end

-- OnClosed ends the visit, forgetting what it loaded (and any loading under way).
---@param ctx Context
function guildBank:OnClosed(ctx)
  self.open = false
  self.loaded = {}
  self.loading = nil
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
