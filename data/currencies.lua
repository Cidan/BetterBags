local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- Currencies is what BetterBags Next tracks as currencies (.claude/rules/currency.md): currencies and items, in the
-- player's order, saved in the profile, never through Blizzard's "show on backpack" flag. It reads each one (how
-- many, how close to its cap, where an item is) and tells how much each changed since it was last read, so the
-- strip at the bottom of the backpack and the tracker dragged out of it can show gains as they happen.
---@class Currencies: AceModule
---@field states table<string, NextCurrencyState> What each tracked entry read last, by key.
---@field baselines table<string, number> Each entry's count when the bags were first read, for its session's gain.
---@field ready boolean The bags have been read once: counts before then are the client arriving, no gains.
---@field loading table<number, boolean> Items whose data was asked for and has not arrived.
local currencies = addon:NewModule('Currencies')

-- NextCurrencyState is what a tracked currency or item read.
---@class NextCurrencyState
---@field key string
---@field kind NextCurrencyKind
---@field id number
---@field name? string Nothing for an item the client has not loaded, or a currency it does not know.
---@field icon? number|string
---@field quality? number
---@field count number How many: a currency's, or an item's in the bags and, counted everywhere, the bank and Warband.
---@field bags? number An item's in the bags.
---@field none boolean Nothing of it, or a currency never discovered.
---@field cap? "week"|"season"|"most" The cap closest to being reached.
---@field progress? number Toward that cap, 0 to 1.
---@field capped boolean At a cap: more is wasted.
---@field weekly? { earned: number, max: number }
---@field season? { earned: number, max: number }
---@field max? number The most it holds.
---@field accountWide boolean
---@field transferable boolean

function currencies:Init()
  self.states = {}
  self.baselines = {}
  self.ready = false
  self.loading = {}
end

function currencies:OnEnable()
  events:RegisterEvent('CURRENCY_DISPLAY_UPDATE', function(ctx, _, currencyType)
    self:OnCurrencyChanged(ctx, currencyType)
  end)
  events:RegisterEvent('ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED', function(ctx)
    events:SendMessage(ctx, 'currencies/AltsReady')
  end)
  -- Items are counted once the bags were read: the refresh pipeline's draws (refresh-scheduler.md).
  for _, message in ipairs({ 'items/RefreshBackpack/Done', 'items/RefreshBank/Done' }) do
    events:RegisterMessage(message, function(ctx)
      self:Refresh(ctx)
      self.ready = true
    end)
  end
  events:RegisterMessage('currencies/OptionsChanged', function(ctx)
    self:Refresh(ctx)
  end)
end

-- Available says whether the client has currencies: retail, WoW: Forever and Mists Classic (TBC and Era have none:
-- next-settings.md §8). Items are tracked everywhere.
---@return boolean
function currencies:Available()
  return addon.isRetail == true or addon.isMists == true
end

-- Key names a tracked entry: its kind and ID.
---@param kind NextCurrencyKind
---@param id number
---@return string
function currencies:Key(kind, id)
  return kind .. ":" .. id
end

-- Tracked is what is tracked, in order (a copy).
---@return NextTrackedCurrency[]
function currencies:Tracked()
  return database:GetNextCurrencies()
end

---@param kind NextCurrencyKind
---@param id number
---@return number?
local function indexOf(list, kind, id)
  for i, entry in ipairs(list) do
    if entry.kind == kind and entry.id == id then
      return i
    end
  end
  return nil
end

---@param kind NextCurrencyKind
---@param id number
---@return boolean
function currencies:IsTracked(kind, id)
  return indexOf(self:Tracked(), kind, id) ~= nil
end

-- CanTrackItem says whether an item can be tracked: one that stacks (Plumber's rule: gear does not), as the client
-- says once it has loaded the item.
---@param itemID number
---@return boolean
function currencies:CanTrackItem(itemID)
  local stack = C_Item.GetItemMaxStackSizeByID(itemID)
  return stack ~= nil and stack > 1
end

-- Track adds a currency or an item, at index (the end without one), says the list changed and reads it. It returns
-- whether it did (nothing for what is already tracked).
---@param ctx Context
---@param kind NextCurrencyKind
---@param id number
---@param index? number
---@return boolean
function currencies:Track(ctx, kind, id, index)
  local list = self:Tracked()
  if indexOf(list, kind, id) ~= nil then
    return false
  end
  table.insert(list, math.min(index or (#list + 1), #list + 1), { kind = kind, id = id })
  database:SetNextCurrencies(list)
  events:SendMessage(ctx, 'currencies/Changed')
  self:Refresh(ctx, { [self:Key(kind, id)] = true })
  return true
end

-- Untrack stops tracking a currency or an item. It returns whether it did.
---@param ctx Context
---@param kind NextCurrencyKind
---@param id number
---@return boolean
function currencies:Untrack(ctx, kind, id)
  local list = self:Tracked()
  local i = indexOf(list, kind, id)
  if i == nil then
    return false
  end
  table.remove(list, i)
  database:SetNextCurrencies(list)
  self.states[self:Key(kind, id)] = nil
  events:SendMessage(ctx, 'currencies/Changed')
  return true
end

-- Move puts the entry named key after the entry at after in the list as it was, counted with it (0: first), as a
-- list's dragged row lands (NextListReorder). It returns whether anything moved.
---@param ctx Context
---@param key string
---@param after number
---@return boolean
function currencies:Move(ctx, key, after)
  local list = self:Tracked()
  local from
  for i, entry in ipairs(list) do
    if self:Key(entry.kind, entry.id) == key then
      from = i
    end
  end
  if from == nil then
    return false
  end
  local entry = table.remove(list, from)
  -- Counted with the entry itself: past it, the places move up by one.
  local at = after >= from and after or after + 1
  at = math.max(1, math.min(at, #list + 1))
  if at == from then
    return false
  end
  table.insert(list, at, entry)
  database:SetNextCurrencies(list)
  events:SendMessage(ctx, 'currencies/Changed')
  return true
end

-- capOf finds the cap a currency is closest to: the week's, the season's (what it has earned toward the most it
-- holds: useTotalEarnedForMaxQty), or the most it holds.
---@param info CurrencyInfo
---@return string? cap, number? progress
local function capOf(info)
  local best, progress
  local function consider(cap, earned, max)
    if max and max > 0 then
      local p = math.min(1, (earned or 0) / max)
      if progress == nil or p > progress then
        best, progress = cap, p
      end
    end
  end
  if info.canEarnPerWeek and info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then
    consider("week", info.quantityEarnedThisWeek, info.maxWeeklyQuantity)
  end
  if info.useTotalEarnedForMaxQty then
    consider("season", info.totalEarned, info.maxQuantity)
  else
    consider("most", info.quantity, info.maxQuantity)
  end
  return best, progress
end

---@param id number
---@return NextCurrencyState
local function readCurrency(id)
  local key = currencies:Key("currency", id)
  local info = C_CurrencyInfo.GetCurrencyInfo(id)
  if info == nil then
    return { key = key, kind = "currency", id = id, count = 0, none = true, capped = false, accountWide = false,
      transferable = false }
  end
  local cap, progress = capOf(info)
  local capped = progress ~= nil and progress >= 1
  if C_CurrencyInfo.PlayerHasMaxQuantity and C_CurrencyInfo.PlayerHasMaxQuantity(id) then
    capped = true
  end
  if C_CurrencyInfo.PlayerHasMaxWeeklyQuantity and C_CurrencyInfo.PlayerHasMaxWeeklyQuantity(id) then
    capped = true
  end
  local count = info.quantity or 0
  ---@type NextCurrencyState
  local state = {
    key = key, kind = "currency", id = id, name = info.name, icon = info.iconFileID, quality = info.quality,
    count = count, none = count == 0 or info.discovered == false, cap = cap, progress = progress,
    capped = capped, accountWide = info.isAccountWide == true, transferable = info.isAccountTransferable == true,
  }
  if info.canEarnPerWeek and (info.maxWeeklyQuantity or 0) > 0 then
    state.weekly = { earned = info.quantityEarnedThisWeek or 0, max = info.maxWeeklyQuantity }
  end
  if info.useTotalEarnedForMaxQty and (info.maxQuantity or 0) > 0 then
    state.season = { earned = info.totalEarned or 0, max = info.maxQuantity }
  elseif (info.maxQuantity or 0) > 0 then
    state.max = info.maxQuantity
  end
  return state
end

-- ItemPlaces says where an item is: the bags, the bank, the reagent bank and the Warband bank (where there is one).
---@param id number
---@return { bags: number, bank: number, reagent: number, warband: number }
function currencies:ItemPlaces(id)
  local bags = C_Item.GetItemCount(id)
  local withBank = C_Item.GetItemCount(id, true)
  local withReagent = C_Item.GetItemCount(id, false, false, true)
  local warband = 0
  if addon.hasWarbank then
    warband = C_Item.GetItemCount(id, false, false, false, true) - bags
  end
  return { bags = bags, bank = withBank - bags, reagent = withReagent - bags, warband = warband }
end

---@param id number
---@return NextCurrencyState
function currencies:readItem(id)
  local places = self:ItemPlaces(id)
  local count = places.bags
  if database:GetNextCurrencyOption("itemsEverywhere") then
    count = places.bags + places.bank + places.reagent + places.warband
  end
  local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
  -- Rule #1 (data-loader.md §19): nothing but GetItemInfoInstant before the item's data has loaded.
  local name = C_Item.GetItemNameByID(id)
  local quality
  if name ~= nil then
    quality = C_Item.GetItemQualityByID(id)
  else
    self:load(id)
  end
  return { key = self:Key("item", id), kind = "item", id = id, name = name, icon = icon, quality = quality,
    count = count, bags = places.bags, none = count == 0, capped = false, accountWide = false, transferable = false }
end

-- load asks for an item's data once, and reads it again when it arrives.
---@private
---@param id number
function currencies:load(id)
  if self.loading[id] then
    return
  end
  self.loading[id] = true
  local container = ContinuableContainer:Create()
  container:AddContinuable(Item:CreateFromItemID(id))
  container:ContinueOnLoad(function()
    self.loading[id] = nil
    self:Refresh(context:New('Currencies_ItemLoaded'), { [self:Key("item", id)] = true })
  end)
end

-- gainOf is how much an entry gained (or lost) between two reads. An item counted everywhere gained only what both
-- its count and its bags' count gained: moved between the bags and the bank, or the bank's count arriving after the
-- bags', it gained nothing (currency.md §2).
---@param old NextCurrencyState
---@param new NextCurrencyState
---@return number
local function gainOf(old, new)
  local total = new.count - old.count
  if new.kind ~= "item" or new.bags == nil or old.bags == nil then
    return total
  end
  local bags = new.bags - old.bags
  if total > 0 and bags > 0 then
    return math.min(total, bags)
  end
  if total < 0 and bags < 0 then
    return math.max(total, bags)
  end
  return 0
end

---@param a NextCurrencyState
---@param b NextCurrencyState
---@return boolean
local function same(a, b)
  for _, field in ipairs({ "name", "icon", "quality", "count", "bags", "none", "cap", "progress", "capped",
    "max", "accountWide", "transferable" }) do
    if a[field] ~= b[field] then
      return false
    end
  end
  for _, field in ipairs({ "weekly", "season" }) do
    local x, y = a[field], b[field]
    if (x == nil) ~= (y == nil) or (x and (x.earned ~= y.earned or x.max ~= y.max)) then
      return false
    end
  end
  return true
end

-- Refresh reads every tracked entry again (only the keys in only, when given) and, when anything changed, sends
-- currencies/Updated with how much each gained or lost: none before the bags were first read, none for an entry
-- read the first time. It returns the gains.
---@param ctx Context
---@param only? table<string, boolean>
---@return table<string, number>
function currencies:Refresh(ctx, only)
  local gains, changed = {}, false
  for _, entry in ipairs(self:Tracked()) do
    local key = self:Key(entry.kind, entry.id)
    if only == nil or only[key] then
      local state = entry.kind == "currency" and readCurrency(entry.id) or self:readItem(entry.id)
      local old = self.states[key]
      if old == nil or not same(old, state) then
        changed = true
      end
      if old ~= nil and self.ready then
        local gain = gainOf(old, state)
        if gain ~= 0 then
          gains[key] = gain
        end
      end
      if self.ready and self.baselines[key] == nil then
        self.baselines[key] = old ~= nil and old.count or state.count
      end
      self.states[key] = state
    end
  end
  if changed then
    events:SendMessage(ctx, 'currencies/Updated', gains)
  end
  return gains
end

-- OnCurrencyChanged reads a tracked currency again when the client says it changed (CURRENCY_DISPLAY_UPDATE), every
-- tracked currency when it names none.
---@param ctx Context
---@param currencyType? number
function currencies:OnCurrencyChanged(ctx, currencyType)
  local only = {}
  local any = false
  for _, entry in ipairs(self:Tracked()) do
    if entry.kind == "currency" and (currencyType == nil or entry.id == currencyType) then
      only[self:Key(entry.kind, entry.id)] = true
      any = true
    end
  end
  if any then
    self:Refresh(ctx, only)
  end
end

-- State is what a tracked entry read last, read now the first time.
---@param key string
---@return NextCurrencyState?
function currencies:State(key)
  if self.states[key] == nil then
    self:Refresh(context:New('Currencies_State'), { [key] = true })
  end
  return self.states[key]
end

-- States is what every tracked entry read last, in order.
---@return NextCurrencyState[]
function currencies:States()
  local out = {}
  for _, entry in ipairs(self:Tracked()) do
    local state = self:State(self:Key(entry.kind, entry.id))
    if state ~= nil then
      table.insert(out, state)
    end
  end
  return out
end

-- SessionGain is how much an entry gained since the bags were first read (net), 0 before then.
---@param key string
---@return number
function currencies:SessionGain(key)
  local base, state = self.baselines[key], self.states[key]
  if base == nil or state == nil then
    return 0
  end
  return state.count - base
end

-- Alts lists the Warband's other characters' amounts of a currency, the most first, leaving out those who have none:
-- nothing while the server has not answered (it is asked, and currencies/AltsReady tells when it does), none where
-- the client cannot say.
---@param id number
---@return { name: string, quantity: number }[]?
function currencies:Alts(id)
  if not C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters or not C_CurrencyInfo.IsAccountCharacterCurrencyDataReady then
    return {}
  end
  if not C_CurrencyInfo.IsAccountCharacterCurrencyDataReady() then
    C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
    return nil
  end
  local out = {}
  for _, data in ipairs(C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters(id) or {}) do
    if (data.quantity or 0) > 0 then
      table.insert(out, { name = data.characterName or data.fullCharacterName or "", quantity = data.quantity })
    end
  end
  table.sort(out, function(a, b)
    if a.quantity ~= b.quantity then
      return a.quantity > b.quantity
    end
    return a.name < b.name
  end)
  return out
end

-- NextCurrencyListEntry is a heading or a currency of Blizzard's currency list (its Currency tab's).
---@class (exact) NextCurrencyListEntry
---@field index number Its place in the list as it read.
---@field name string
---@field isHeader boolean
---@field isHeaderExpanded boolean
---@field depth number How deep under headings: retail nests them; Mists Classic has headings and currencies.
---@field id? number A currency's ID.
---@field isShowInBackpack boolean Blizzard's own "show on backpack" flag (the classic bags' currency icons).
---@field quantity number
---@field maxQuantity number
---@field icon? number|string

-- ListSize is how many rows Blizzard's currency list shows now (the currencies under a collapsed heading are not
-- counted), from whichever API the client has: C_CurrencyInfo on retail and WoW: Forever, the legacy globals on Mists
-- Classic (Blizzard_TokenUI), none on TBC and Era.
---@return number
function currencies:ListSize()
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
    return C_CurrencyInfo.GetCurrencyListSize()
  end
  if GetCurrencyListSize then
    return GetCurrencyListSize()
  end
  return 0
end

-- ListEntry reads the list's row at index. A legacy row's currency ID is GetCurrencyListInfo's twelfth return, the
-- value Blizzard_TokenUI (Mists) compares with Constants.CurrencyConsts.CLASSIC_HONOR_CURRENCY_ID.
---@param index number
---@return NextCurrencyListEntry?
function currencies:ListEntry(index)
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo then
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    if info == nil then
      return nil
    end
    local header = info.isHeader == true
    return {
      index = index, name = info.name or "", isHeader = header, isHeaderExpanded = info.isHeaderExpanded == true,
      depth = info.currencyListDepth or 0, id = (not header and info.currencyID ~= 0) and info.currencyID or nil,
      isShowInBackpack = info.isShowInBackpack == true, quantity = info.quantity or 0,
      maxQuantity = info.maxQuantity or 0, icon = info.iconFileID,
    }
  end
  if GetCurrencyListInfo then
    local name, header, expanded, _, watched, count, icon, maximum, _, _, _, id = GetCurrencyListInfo(index)
    if name == nil then
      return nil
    end
    return {
      index = index, name = name, isHeader = header == true, isHeaderExpanded = expanded == true,
      depth = header and 0 or 1, id = not header and id or nil, isShowInBackpack = watched == true,
      quantity = count or 0, maxQuantity = maximum or 0, icon = icon,
    }
  end
  return nil
end

-- ExpandListHeading opens or closes the heading at index (the legacy globals take 1 and 0).
---@param index number
---@param open boolean
function currencies:ExpandListHeading(index, open)
  if C_CurrencyInfo and C_CurrencyInfo.ExpandCurrencyList then
    C_CurrencyInfo.ExpandCurrencyList(index, open)
  elseif ExpandCurrencyList then
    ExpandCurrencyList(index, open and 1 or 0)
  end
end

-- List reads every heading of Blizzard's currency list and every currency under it. A heading the player keeps
-- collapsed in the Currency tab is opened to be read and closed again afterwards, the last opened first so each one's
-- place is still its own (ElvUI reads it so), leaving the list as the player had it. Each entry's index is its place
-- while everything was open: it is only for reading. What is tracked goes by currency ID.
---@return NextCurrencyListEntry[]
function currencies:List()
  local entries, opened = {}, {}
  local i = 1
  while i <= self:ListSize() do
    local entry = self:ListEntry(i)
    if entry ~= nil then
      if entry.isHeader and not entry.isHeaderExpanded then
        self:ExpandListHeading(i, true)
        table.insert(opened, i)
      end
      table.insert(entries, entry)
    end
    i = i + 1
  end
  for k = #opened, 1, -1 do
    self:ExpandListHeading(opened[k], false)
  end
  return entries
end
