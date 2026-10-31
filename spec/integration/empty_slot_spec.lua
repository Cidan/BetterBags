-- empty_slot_spec.lua -- Every way BetterBags could ask the client about a bag slot it has emptied, on the whole addon
-- (spec/helpers/whole_addon.lua): every real listener, loader, bucket, queue and pipeline. Reported in game, from a
-- tooltip finishing, a window closing, the queue's step and others: "data/items.lua: bad argument #1 to 'GetItemGUID'
-- (Usage: local itemGUID = C_Item.GetItemGUID(itemLocation))".
--
-- The client here holds the bags and answers for them as Blizzard's API documentation says: every call taking an
-- ItemLocation (not an EmptiableItemLocation) raises that error for a slot with no item. Nothing but the client is a
-- stand-in, except that item buttons are not drawn (the frame mock has no item button template, test-harness.md §5).
--
-- BB_SIM_REPORT=1 prints what each run covered; BB_SIM_FULL=1 runs the long versions.

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

local REPORT = os.getenv("BB_SIM_REPORT") ~= nil
local FULL = os.getenv("BB_SIM_FULL") ~= nil

-- ItemDocumentation.lua and BankDocumentation.lua: what BetterBags calls with an ItemLocation that must hold an item.
local TAKES_AN_ITEM = { "CanBeRefunded", "CanScrapItem", "GetCurrentItemLevel", "GetCurrentItemTransmogInfo",
  "GetItemGUID", "GetItemIcon", "GetItemQuality", "GetStackCount", "IsBound", "IsBoundToAccountUntilEquip" }

-- The line players report: where a recalculation asks a stored item's GUID (Phase2_Rederive).
local function lineOf(path, text)
  local number = 0
  for line in io.lines(path) do
    number = number + 1
    if line:find(text, 1, true) then return number end
  end
  error(text .. " is not in " .. path)
end
local RECALCULATION_LINE = "data/items.lua:" .. lineOf("data/items.lua", "C_Item.GetItemGUID(itemMixin:GetItemLocation())")
local THE_REPORTED_ERROR = RECALCULATION_LINE .. ": bad argument #1 to 'GetItemGUID'"

local BAG_SIZES = { [0] = 6, [1] = 6, [5] = 3 }
local BANK_SIZES = { [6] = 6, [12] = 6 }
local BACKPACK = { 0, 1, 5 }
local MERCHANT, BANKER = 5, 8
local FRAME = 1 / 60

-- Runs every nth case, or every case with BB_SIM_FULL.
local function sampled(count, nth)
  return FULL or count % nth == 0
end

describe("a bag slot the client has emptied", function()
  local handle, c, addon, refresh, items, events, context, const, scanner, methods
  local setScript, registerEvent, eventFrames, updateFrames, loaded

  ---------------------------------------------------------------------------------------------------------------------
  -- The client.
  ---------------------------------------------------------------------------------------------------------------------

  local function nameOf(id) return "Item " .. id end
  local function linkOf(id) return "|cffffffff|Hitem:" .. id .. "|h[" .. nameOf(id) .. "]|h|r" end
  local function slotOf(bag, slot) return c.bags[bag] and c.bags[bag][slot] or nil end

  local function clientGlobals()
    local cItem = setmetatable({}, { __index = _G.C_Item })
    function cItem.DoesItemExist(location)
      local bag, slot = location:GetBagAndSlot()
      local item = bag ~= nil and slotOf(bag, slot) or nil
      return item ~= nil and not item.objectGone
    end
    function cItem.GetItemInfo(id)
      local n = tonumber(id) or tonumber(tostring(id):match("item:(%d+)")) or 0
      if c.cold[n] then return nil end
      return nameOf(n), linkOf(n), 1, 100, 1, "Misc", "Junk", 20, "INVTYPE_NON_EQUIP", 134400, 10, 1, 0, 1, 0, 0, false
    end
    function cItem.GetItemStats() return nil end
    function cItem.GetItemSubClassInfo() return "Bag" end
    for _, name in ipairs(TAKES_AN_ITEM) do
      local answer = _G.C_Item[name]
      cItem[name] = function(location, ...)
        if type(location) == "table" and location.GetBagAndSlot then
          local bag, slot = location:GetBagAndSlot()
          if bag ~= nil then
            local item = slotOf(bag, slot)
            if not item or item.objectGone then
              table.insert(c.asked, { api = name, bag = bag, slot = slot, marked = items._unreadBags[bag] ~= nil,
                held = refresh._held, idlePending = refresh._idlePending, running = refresh._running })
              error("bad argument #1 to '" .. name .. "' (Usage: local " .. name .. " = C_Item." .. name ..
                "(itemLocation))", 2)
            end
            if name == "GetItemGUID" then return item.guid end
          end
        end
        if answer then return answer(location, ...) end
      end
    end

    local container = setmetatable({}, { __index = _G.C_Container })
    function container.GetContainerNumSlots(bag) return c.sizes[bag] or 0 end
    function container.GetContainerItemID(bag, slot)
      local item = slotOf(bag, slot)
      return item and item.itemID or nil
    end
    function container.GetContainerItemLink(bag, slot)
      local item = slotOf(bag, slot)
      return item and linkOf(item.itemID) or nil
    end
    function container.GetContainerItemInfo(bag, slot)
      local item = slotOf(bag, slot)
      if not item then return nil end
      return { iconFileID = 134400, stackCount = item.count or 1, isLocked = false, quality = 1, isReadable = false,
        hasLoot = false, hyperlink = linkOf(item.itemID), isFiltered = false, hasNoValue = false, itemID = item.itemID,
        isBound = false, itemName = nameOf(item.itemID) }
    end
    function container.GetContainerNumFreeSlots(bag)
      local free = 0
      for slot = 1, c.sizes[bag] or 0 do
        if not slotOf(bag, slot) then free = free + 1 end
      end
      return free, 0
    end
    function container.ContainerIDToInventoryID() return nil end
    -- The server moves the items a few frames later; each bag it changed says so.
    function container.SortBags() c.sorted = true end

    local tooltipInfo = setmetatable({}, { __index = _G.C_TooltipInfo })
    function tooltipInfo.GetBagItem(bag, slot)
      local item = slotOf(bag, slot)
      if not item then return nil end
      c.instance = c.instance + 1
      c.instanceSlots[c.instance] = item.guid
      return { dataInstanceID = c.instance, lines = { { leftText = nameOf(item.itemID), type = 0 } } }
    end

    local item = setmetatable({}, { __index = _G.Item })
    function item:CreateFromEquipmentSlot(slot)
      local location = _G.ItemLocation:CreateFromEquipmentSlot(slot)
      return { GetItemLocation = function() return location end, IsItemEmpty = function() return true end }
    end

    local function after(delay, fn)
      local t = { at = c.now + math.max(delay or 0, 0.001), fn = fn }
      table.insert(c.timers, t)
      return t
    end
    local gameMenu = _G.CreateFrame("Frame")
    gameMenu:Hide()
    return {
      GameMenuFrame = gameMenu,
      C_Item = cItem,
      C_Container = container,
      C_TooltipInfo = tooltipInfo,
      Item = item,
      C_Bank = setmetatable({ CloseBankFrame = function() end }, { __index = _G.C_Bank }),
      C_NewItems = setmetatable({
        IsNewItem = function(bag, slot) return c.new[bag .. "_" .. slot] or false end,
        RemoveNewItem = function(bag, slot) c.new[bag .. "_" .. slot] = nil end,
      }, { __index = _G.C_NewItems }),
      C_PlayerInfo = setmetatable({ CanUseItem = function() return c.usable end }, { __index = _G.C_PlayerInfo }),
      GetInventoryItemLink = function() return nil end,
      C_Timer = {
        After = function(delay, fn) after(delay, fn) end,
        NewTimer = function(delay, fn)
          local t = after(delay, nil)
          t.fn = function() if not t.cancelled then fn(t) end end
          function t:Cancel() self.cancelled = true end
          return t
        end,
      },
      -- The items' data is loaded, or arrives when load() runs.
      ContinuableContainer = {
        Create = function()
          return {
            AddContinuable = function() end,
            ContinueOnLoad = function(_, callback)
              if c.warm then callback() else table.insert(c.loading, callback) end
            end,
          }
        end,
      },
    }
  end

  -- A WoW event reaches every listener: the events module's, and every frame registered for it.
  local function fire(name, ...)
    local entry = events._eventMap[name]
    if entry then entry.fn(name, ...) end
    for _, f in ipairs(eventFrames) do
      if f._events[name] and f:GetScript("OnEvent") then
        f:GetScript("OnEvent")(f, name, ...)
      end
    end
  end

  -- The data of every item waiting for it arrives.
  local function load()
    c.cold = {}
    local callbacks = c.loading
    c.loading = {}
    for _, callback in ipairs(callbacks) do callback() end
  end

  local function serverMoves()
    if not c.sorted then return end
    c.sorted = false
    for _, bag in ipairs(BACKPACK) do
      local slots = c.bags[bag]
      for i = c.sizes[bag] or 0, 2, -1 do slots[i], slots[1] = slots[1], slots[i] end
      c.changed = true
      fire("BAG_UPDATE", bag)
    end
  end

  -- One frame: OnUpdate scripts and the timers due. BAG_UPDATE_DELAYED ends a frame with a bag change (a UniqueEvent).
  local function frame(noDelayed)
    c.now = c.now + FRAME
    serverMoves()
    for _, f in ipairs(updateFrames) do
      local onUpdate = f:GetScript("OnUpdate")
      if onUpdate and f:IsVisible() then onUpdate(f, FRAME) end
    end
    local due, rest = {}, {}
    for _, t in ipairs(c.timers) do
      if t.at <= c.now + 1e-9 then table.insert(due, t) else table.insert(rest, t) end
    end
    c.timers = rest
    for _, t in ipairs(due) do t.fn() end
    if c.changed and not noDelayed then
      c.changed = false
      fire("BAG_UPDATE_DELAYED")
    end
  end

  local function frames(n)
    for _ = 1, n do frame() end
  end

  local function report(bag)
    c.changed = true
    fire("BAG_UPDATE", bag)
  end

  -- Until nothing is left to happen: time skips to the next timer once the queue is idle.
  local function drain()
    for _ = 1, 5000 do
      load()
      local idle = not refresh._running and not c.changed and not c.sorted
      if idle and #c.timers == 0 then return end
      if idle then
        local soonest = math.huge
        for _, t in ipairs(c.timers) do soonest = math.min(soonest, t.at) end
        c.now = math.max(c.now, soonest - FRAME)
      end
      frame()
    end
    error("the client never went quiet")
  end

  local function fresh()
    c.guid = c.guid + 1
    return "g" .. c.guid
  end

  -- An item new to the client has no data until load(), while c.warm is off.
  local function give(bag, slot, itemID, count)
    c.bags[bag][slot] = { itemID = itemID, guid = fresh(), count = count or 1 }
    if not c.warm then c.cold[itemID] = true end
  end

  -- A single item, a stack and a partial stack of one item, a piece of gear; a second bag; the reagent bag.
  local function fill()
    c.bags, c.sizes = {}, {}
    for bag, size in pairs(BAG_SIZES) do
      c.bags[bag], c.sizes[bag] = {}, size
    end
    give(0, 1, 101); give(0, 2, 102, 5); give(0, 3, 102, 3); give(0, 4, 103)
    give(1, 1, 104); give(1, 2, 105, 2); give(1, 3, 106)
    give(5, 1, 107, 10)
  end

  local function backpackHeld()
    local held = {}
    for _, bag in ipairs(BACKPACK) do
      for slot = 1, c.sizes[bag] or 0 do
        local item = slotOf(bag, slot)
        if item then held[bag .. "_" .. slot] = item.guid end
      end
    end
    return held
  end

  -- A bank bag stays marked until the bank next opens and reads it.
  local function backpackMarked()
    local marked = {}
    for _, bag in ipairs(BACKPACK) do
      if items._unreadBags[bag] ~= nil then table.insert(marked, bag) end
    end
    return marked
  end

  local function backpackCommitted()
    local held = {}
    for slotkey, item in pairs(items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
      if not item.isItemEmpty then held[slotkey] = item.itemInfo.itemGUID end
    end
    return held
  end

  -- Starts from: the bags as fill() leaves them, all read, nothing marked, nothing waiting.
  local function reset()
    if addon.atBank then
      fire("BANKFRAME_CLOSED")
      fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", BANKER)
    end
    c.random, c.bankOpen = nil, false
    drain()
    fill()
    c.warm, c.usable, c.cold = true, true, {}
    fire("BAG_CONTAINER_UPDATE")
    drain()
    c.asked = {}
    for i = #handle.errors, 1, -1 do handle.errors[i] = nil end
    assert.same({}, backpackMarked())
    assert.same(backpackHeld(), backpackCommitted())
  end

  local function stop()
    if handle then handle:Restore() end
    if methods then
      methods.SetScript, methods.RegisterEvent = setScript, registerEvent
    end
    -- busted keeps these closures for the whole run: none may keep the loaded addon.
    handle, c, addon, refresh, items, events, context, const, scanner = nil, nil, nil, nil, nil, nil, nil, nil, nil
    eventFrames, updateFrames, methods, loaded = nil, nil, nil, nil
  end

  -- Tests of a kind of client share one load, as a session does; each starts from reset().
  local function start(opts)
    local variant = tostring(opts and opts.next) .. "/" .. tostring(opts and opts.client)
    if loaded == variant then
      reset()
      c.derives = 0
      return
    end
    stop()
    loaded = variant
    c = { bags = {}, sizes = {}, now = 0, timers = {}, asked = {}, new = {}, guid = 0, instance = 0, instanceSlots = {},
      warm = true, cold = {}, loading = {}, usable = true }
    fill()
    eventFrames, updateFrames = {}, {}
    methods = _G.__mockWidgetMethods
    setScript, registerEvent = methods.SetScript, methods.RegisterEvent
    local aceFrame = LibStub("AceEvent-3.0").frame
    local tracked = {}
    methods.SetScript = function(self, name, fn)
      if name == "OnUpdate" and fn and not tracked[self] then
        tracked[self] = true
        table.insert(updateFrames, self)
      end
      return setScript(self, name, fn)
    end
    methods.RegisterEvent = function(self, event)
      if self ~= aceFrame and not self._listed then
        self._listed = true
        table.insert(eventFrames, self)
      end
      return registerEvent(self, event)
    end
    handle = WholeAddon.Load({ next = opts and opts.next, client = opts and opts.client, globals = clientGlobals() })
    handle:Start()
    addon = handle.addon
    refresh, items, events, context = addon:GetModule("Refresh"), addon:GetModule("Items"), addon:GetModule("Events"),
      addon:GetModule("Context")
    const, scanner = addon:GetModule("Constants"), addon:GetModule("TooltipScanner")
    for _, bag in pairs({ addon.Bags.Backpack, addon.Bags.Bank, addon.Bags.GuildBank }) do
      bag.Draw = function(_, _, _, callback) if callback then callback() end end
    end
    assert.same({}, handle.errors, "starting")
    fire("LOADING_SCREEN_DISABLED")
    drain()
    assert.is_false(refresh._held, "past the startup read")
    reset()
    c.derives = 0
    local rederive = items.Phase2_Rederive
    items.Phase2_Rederive = function(...)
      c.derives = c.derives + 1
      return rederive(...)
    end
  end

  teardown(stop)

  local function send(message, options)
    events:SendMessage(context:New(message), message, options)
  end

  -- The first slot that fits; in a session (c.random), any that fits.
  local function pick(found)
    if #found == 0 then return nil end
    return unpack(found[c.random and c.random(#found) or 1])
  end

  local function firstFilled(bags, wantedID)
    local found = {}
    for _, bag in ipairs(bags) do
      for slot = 1, c.sizes[bag] or 0 do
        local item = slotOf(bag, slot)
        if item and (not wantedID or item.itemID == wantedID) then table.insert(found, { bag, slot, item }) end
      end
    end
    return pick(found)
  end

  local function firstEmpty(bags)
    local found = {}
    for _, bag in ipairs(bags) do
      for slot = 1, c.sizes[bag] or 0 do
        if not slotOf(bag, slot) then table.insert(found, { bag, slot }) end
      end
    end
    return pick(found)
  end

  ---------------------------------------------------------------------------------------------------------------------
  -- What changes a bag's contents. Each reports every bag it changed, as it changes it (BAG_UPDATE is a
  -- SynchronousEvent, ContainerDocumentation.lua), along with the other events the change brings.
  ---------------------------------------------------------------------------------------------------------------------

  local function emptyOne(bags, around)
    local bag, slot = firstFilled(bags or BACKPACK)
    if not bag then return end
    if around then around("before", bag, slot) end
    c.bags[bag][slot] = nil
    report(bag)
    if around then around("after", bag, slot) end
  end

  local function moveTo(toBags, order)
    local fromBag, fromSlot, item = firstFilled({ 0 })
    local toBag, toSlot = firstEmpty(toBags)
    if not (fromBag and toBag) then return end
    if order == "emptied first" then
      c.bags[fromBag][fromSlot] = nil
      report(fromBag)
      c.bags[toBag][toSlot] = item
      report(toBag)
    elseif order == "filled first" then
      c.bags[toBag][toSlot] = item
      report(toBag)
      c.bags[fromBag][fromSlot] = nil
      report(fromBag)
    else
      c.bags[fromBag][fromSlot], c.bags[toBag][toSlot] = nil, item
      report(fromBag)
      if toBag ~= fromBag then report(toBag) end
    end
  end

  local CHANGES = {
    { "the last of a stack used", function() emptyOne() end },
    { "one of a stack used", function()
      local bag, _, item = firstFilled(BACKPACK, 102)
      if not bag then return end
      item.count = math.max(1, (item.count or 1) - 1)
      report(bag)
    end },
    { "an item looted into an empty slot", function()
      local bag, slot = firstEmpty({ 0, 1 })
      if not bag then return end
      give(bag, slot, 200)
      c.new[bag .. "_" .. slot] = true
      report(bag)
    end },
    { "an item looted onto a stack", function()
      local bag, _, item = firstFilled(BACKPACK, 102)
      if not bag then return end
      item.count = (item.count or 1) + 1
      report(bag)
    end },
    { "a reagent looted into the reagent bag", function()
      local bag, slot = firstEmpty({ 5 })
      if not bag then return end
      give(bag, slot, 201)
      report(bag)
    end },
    { "an item moved in its bag", function() moveTo({ 0 }) end },
    { "an item moved to another bag", function() moveTo({ 1 }) end },
    { "an item moved to another bag, emptied first", function() moveTo({ 1 }, "emptied first") end },
    { "an item moved to another bag, filled first", function() moveTo({ 1 }, "filled first") end },
    { "two items swapped across bags", function()
      local aBag, aSlot, a = firstFilled({ 0 })
      local bBag, bSlot, b = firstFilled({ 1 })
      if not (a and b) then return end
      c.bags[aBag][aSlot], c.bags[bBag][bSlot] = b, a
      report(aBag)
      report(bBag)
    end },
    { "a stack split", function()
      local bag, _, item = firstFilled({ 0 }, 102)
      local toBag, toSlot = firstEmpty({ 0 })
      if not (bag and toBag) then return end
      item.count = math.max(1, (item.count or 1) - 1)
      give(toBag, toSlot, item.itemID, 1)
      report(bag)
    end },
    { "a stack merged into another, its slot emptied", function()
      local bag, slot, item = firstFilled({ 0 }, 102)
      if not bag then return end
      for other = slot + 1, c.sizes[bag] do
        local into = slotOf(bag, other)
        if into and into.itemID == item.itemID then
          into.count = (into.count or 1) + (item.count or 1)
          c.bags[bag][slot] = nil
          report(bag)
          return
        end
      end
    end },
    { "gear equipped from a bag, the gear's event first", function()
      emptyOne({ 0 }, function(at) if at == "before" then fire("PLAYER_EQUIPMENT_CHANGED", 1, true) end end)
    end },
    { "gear equipped from a bag, the bag's event first", function()
      emptyOne({ 0 }, function(at) if at == "after" then fire("PLAYER_EQUIPMENT_CHANGED", 1, true) end end)
    end },
    { "gear taken off into a bag", function()
      local bag, slot = firstEmpty({ 0, 1 })
      if not bag then return end
      fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
      give(bag, slot, 202)
      report(bag)
    end },
    { "an item picked up and destroyed", function()
      emptyOne(nil, function(at, bag, slot) if at == "before" then fire("ITEM_LOCK_CHANGED", bag, slot) end end)
    end },
    { "a quest item taken away", function()
      emptyOne(nil, function(at) if at == "before" then fire("QUEST_LOG_UPDATE") end end)
    end },
    { "an item sold", function()
      emptyOne(nil, function(at) if at == "after" then fire("PLAYER_MONEY") end end)
    end },
    { "a whole bag emptied at once", function()
      local bag = firstFilled({ 0, 1 })
      if not bag then return end
      c.bags[bag] = {}
      report(bag)
    end },
    { "two bags emptied at once", function()
      c.bags[0], c.bags[1] = {}, {}
      report(0)
      report(1)
    end },
    { "a bag swapped for a smaller one, its container event first", function()
      c.sizes[1] = 2
      c.bags[1][3], c.bags[1][4], c.bags[1][5], c.bags[1][6] = nil, nil, nil, nil
      fire("BAG_CONTAINER_UPDATE")
      report(1)
    end },
    { "a bag swapped for a smaller one, its bag's event first", function()
      c.sizes[1] = 2
      c.bags[1][3], c.bags[1][4], c.bags[1][5], c.bags[1][6] = nil, nil, nil, nil
      report(1)
      fire("BAG_CONTAINER_UPDATE")
    end },
    { "a bag taken off", function()
      c.sizes[1], c.bags[1] = 0, {}
      fire("BAG_CONTAINER_UPDATE")
    end },
  }

  ---------------------------------------------------------------------------------------------------------------------
  -- What asks for a recalculation (every sender of bags/Rederive sends one of these shapes). Each goes through what
  -- sends it in game where one can be driven from here.
  ---------------------------------------------------------------------------------------------------------------------

  local function aTooltipInstance()
    local found
    for id in pairs(scanner.instanceToGUID) do
      if not found or id < found then found = id end
    end
    return found
  end

  local TRIGGERS = {
    { "a tooltip finishing (the report's)", function()
      local id = aTooltipInstance()
      if id then fire("TOOLTIP_DATA_UPDATE", id) end
      frames(13)
    end },
    { "a window closing", function() fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", MERCHANT) end },
    { "a window opening", function()
      fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", MERCHANT)
      frame()
    end },
    { "gear changing", function()
      fire("PLAYER_EQUIPMENT_CHANGED", 2, true)
      frame()
    end },
    { "skills changing", function()
      fire("SKILL_LINES_CHANGED")
      frame()
    end },
    { "learning a spell in a skill line", function()
      fire("LEARNED_SPELL_IN_SKILL_LINE")
      frame()
    end },
    { "the specialization changing", function()
      fire("PLAYER_SPECIALIZATION_CHANGED", "player")
      frame()
    end },
    { "spells changing an item's usability", function()
      c.usable = not c.usable
      fire("SPELLS_CHANGED")
      frames(13)
    end },
    { "a reputation changing an item's usability", function()
      c.usable = not c.usable
      fire("UPDATE_FACTION")
      frames(13)
    end },
    -- It recalculates when the journal first loads: every time here, or later cases would do nothing.
    { "the pet journal loading", function()
      items._petJournalLoaded = false
      fire("PET_JOURNAL_LIST_UPDATE")
    end },
    { "gear sets changing", function() fire("EQUIPMENT_SETS_CHANGED") end },
    { "a category changed", function()
      local categories = addon:GetModule("Categories")
      c.category = (c.category or 0) + 1
      local name = "Sim " .. c.category
      categories:CreateCategory(context:New("sim"), { name = name, itemList = {}, save = true })
      categories:UpdateCategory(context:New("sim"), name, { priority = 5 })
    end },
    { "a setting changing", function() send("bags/Rederive", { resetLayout = true, buttons = true }) end },
    { "Show Bags toggled", function() send("bags/Rederive", { resetLayout = true }) end },
    { "a bag closing", function()
      send("bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true })
    end },
    { "another addon's provider arriving", function() send("bags/Rederive", { categoriesUnchanged = true }) end },
    { "a section dropped", function() send("bags/Rederive", { resetLayout = true, backpack = true }) end },
  }

  -- What reads the bags: never asked to recalculate, but it is what a mark waits for.
  local READS = {
    { "a read", function() send("bags/RefreshBackpack") end },
    { "a full read", function() send("bags/FullRefreshAll") end },
    { "a sort", function() send("bags/SortBackpack") end },
    { "a level gained", function()
      fire("PLAYER_LEVEL_UP")
      frame()
    end },
  }

  -- Every moment a recalculation can come, against a change. A read and a recalculation park at their yield, after
  -- their harvest and before they commit.
  local TIMINGS = {
    { "before the change, the same frame", function(change, trigger) trigger(); change() end },
    { "after the change, the same frame", function(change, trigger) change(); trigger() end },
    { "from a timer in the frame of the change", function(change, trigger)
      _G.C_Timer.After(0, trigger)
      change()
      frame()
    end },
    { "before BAG_UPDATE_DELAYED ends the frame", function(change, trigger)
      change()
      frame(true)
      trigger()
    end },
    { "while the change's read waits for item data", function(change, trigger)
      c.warm = false
      change()
      frame()
      trigger()
      c.warm = true
    end },
    { "with a read parked, the change, then it", function(change, trigger)
      send("bags/RefreshBackpack")
      change()
      trigger()
    end },
    { "with a read parked, it, then the change", function(change, trigger)
      send("bags/RefreshBackpack")
      trigger()
      change()
    end },
    { "with a recalculation parked, the change, then it", function(change, trigger)
      send("bags/Rederive", { backpack = true })
      change()
      trigger()
    end },
    { "in the queue's idle frame after a read", function(change, trigger)
      send("bags/RefreshBackpack")
      frame()
      change()
      trigger()
    end },
    { "once the change's read has committed", function(change, trigger)
      change()
      drain()
      trigger()
    end },
  }

  local function failure(what)
    local lines = {}
    for _, asked in ipairs(c.asked) do
      table.insert(lines, string.format("%s of %d_%d (marked %s, held %s)", asked.api, asked.bag, asked.slot,
        tostring(asked.marked), tostring(asked.held)))
    end
    for _, err in ipairs(handle.errors) do table.insert(lines, err) end
    return what .. ":\n  " .. table.concat(lines, "\n  ")
  end

  local function check(what)
    if #c.asked > 0 or #handle.errors > 0 then error(failure(what), 0) end
    assert.same(backpackHeld(), backpackCommitted(), what)
    assert.same({}, backpackMarked(), what)
  end

  -- A last recalculation once the client is quiet: nothing committed may name a slot the client emptied.
  local function finish(what)
    drain()
    send("bags/Rederive", { backpack = true })
    drain()
    check(what)
  end

  for _, design in ipairs({ "classic", "next" }) do
    describe("with a client that reports each change as it makes it, " .. design .. " bags", function()
      it("reaches a recalculation from every trigger", function()
        start({ next = design == "next" })
        for _, trigger in ipairs(TRIGGERS) do
          reset()
          c.derives = 0
          trigger[2]()
          drain()
          assert.is_true(c.derives > 0, trigger[1] .. " recalculates")
          check(trigger[1])
        end
      end)

      it("never asks about an empty slot: every change, every trigger, every moment", function()
        start({ next = design == "next" })
        local cases, derives = 0, 0
        for _, change in ipairs(CHANGES) do
          for _, trigger in ipairs(TRIGGERS) do
            for _, timing in ipairs(TIMINGS) do
              if sampled(cases, 131) then
                reset()
                c.derives = 0
                local what = change[1] .. " / " .. trigger[1] .. " / " .. timing[1]
                local ok, err = pcall(timing[2], change[2], trigger[2])
                if not ok then error(what .. ": " .. tostring(err), 0) end
                finish(what)
                derives = derives + c.derives
              end
              cases = cases + 1
            end
          end
        end
        if REPORT then print(string.format("%s: %d cases, %d recalculations", design, cases, derives)) end
        assert.is_true(derives > 40)
      end)

      it("never asks about an empty slot: every change against every read", function()
        start({ next = design == "next" })
        local cases = 0
        for _, change in ipairs(CHANGES) do
          for _, read in ipairs(READS) do
            for _, timing in ipairs(TIMINGS) do
              if sampled(cases, 37) then
                reset()
                local what = change[1] .. " / " .. read[1] .. " / " .. timing[1]
                local ok, err = pcall(timing[2], change[2], read[2])
                if not ok then error(what .. ": " .. tostring(err), 0) end
                finish(what)
              end
              cases = cases + 1
            end
          end
        end
      end)
    end)
  end

  ---------------------------------------------------------------------------------------------------------------------
  -- Every order of the steps of one change: the slot emptying (E), the client reporting it (U), the frame's
  -- BAG_UPDATE_DELAYED (D), the bag's item data arriving (L), a recalculation asked for (T), a read asked for (R), and
  -- frames passing (F).
  ---------------------------------------------------------------------------------------------------------------------

  -- Calls visit with every distinct order of the tokens (counts by token).
  local function eachOrder(counts, visit)
    local names = {}
    local total = 0
    for name, count in pairs(counts) do
      table.insert(names, name)
      total = total + count
    end
    table.sort(names)
    local order = {}
    local function walk(depth)
      if depth > total then
        visit(order)
        return
      end
      for _, name in ipairs(names) do
        if counts[name] > 0 then
          counts[name] = counts[name] - 1
          order[depth] = name
          walk(depth + 1)
          counts[name] = counts[name] + 1
        end
      end
    end
    walk(1)
  end

  local function steps()
    return {
      E = function() c.bags[0][1] = nil end,
      U = function() report(0) end,
      EU = function()
        c.bags[0][1] = nil
        report(0)
      end,
      D = function()
        c.changed = false
        fire("BAG_UPDATE_DELAYED")
      end,
      L = load,
      T = function() send("bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true }) end,
      R = function() send("bags/RefreshBackpack") end,
      W = function() send("bags/FullRefreshAll") end,
      F = function() frame(true) end,
    }
  end

  -- Runs an order. It returns whether a recalculation asked about the empty slot during the order, and whether one
  -- did once the client went quiet, with the queue's state at the first time asked.
  local function runOrder(order, s)
    reset()
    c.warm = false
    for _, token in ipairs(order) do s[token]() end
    local during = #c.asked > 0
    c.warm = true
    drain()
    local duringDrain = #c.asked > 0
    local first = c.asked[1]
    local askedBefore = #c.asked
    send("bags/Rederive", { backpack = true })
    drain()
    return during or duringDrain, #c.asked > askedBefore, first
  end

  it("never asks in any order of a change reported as it is made", function()
    start()
    local s = steps()
    local count = 0
    eachOrder({ EU = 1, D = 1, L = 1, T = 2, R = 1, W = FULL and 1 or 0, F = 2 }, function(order)
      count = count + 1
      if sampled(count, 211) then
        local what = table.concat(order, " ")
        reset()
        c.warm = false
        for _, token in ipairs(order) do s[token]() end
        c.warm = true
        finish(what)
      end
    end)
    if REPORT then print("orders of a change reported as it is made: " .. count) end
  end)

  it("reproduces the reported error, and only when the change is not reported as it is made", function()
    start()
    local s = steps()
    -- By what the order says of the slot emptying (E) and its report (U).
    local stats = {}
    local function classOf(order)
      local e, u
      for i, token in ipairs(order) do
        if token == "E" then e = i elseif token == "U" then u = i end
      end
      if u == nil then return "never reported" end
      if u == e + 1 then return "reported as it is made" end
      if u > e then return "reported later" end
      return "reported before it is made"
    end
    local tally = function(class, during, after)
      local stat = stats[class] or { orders = 0, during = 0, after = 0 }
      stats[class] = stat
      stat.orders = stat.orders + 1
      if during then stat.during = stat.during + 1 end
      if after then stat.after = stat.after + 1 end
    end
    local count = 0
    local function each(order)
      count = count + 1
      if sampled(count, 43) then
        local during, after, first = runOrder(order, s)
        tally(classOf(order), during, after)
        if during and first then
          -- The same error the player sent, in the same state: not held, the failed unit just ended.
          assert.equal("GetItemGUID", first.api, table.concat(order, " "))
          assert.is_false(first.marked, table.concat(order, " "))
        end
        local stale
        for _, err in ipairs(handle.errors) do
          if not err:find(THE_REPORTED_ERROR, 1, true) then stale = err end
        end
        assert.is_nil(stale, table.concat(order, " "))
      end
    end
    eachOrder({ E = 1, U = 1, D = 1, L = 1, T = 1, R = 1, F = 2 }, each)
    eachOrder({ E = 1, U = 1, D = 1, L = 1, T = 1, F = 3 }, each)
    eachOrder({ E = 1, D = 1, L = 1, T = 1, R = 1, F = 2 }, each)
    if FULL then
      eachOrder({ E = 1, U = 1, D = 1, L = 1, T = 1, R = 1, F = 4 }, each)
    end
    if REPORT then
      for class, stat in pairs(stats) do
        print(string.format("%-28s %6d orders, asked during %6d, asked once quiet %6d", class, stat.orders, stat.during,
          stat.after))
      end
    end
    assert.equal(0, stats["reported as it is made"].during)
    assert.equal(0, stats["reported as it is made"].after)
    assert.is_true(stats["reported later"].during > 0, "a recalculation between the change and its report")
    assert.equal(0, stats["reported later"].after, "the report ends it")
    assert.is_true(stats["reported before it is made"].after > 0, "a read commits before the slot empties")
    assert.is_true(stats["never reported"].after > 0, "nothing ever ends it")
  end)

  it("shows the player's stack and state when a tooltip finishes over an unreported empty slot", function()
    start()
    assert.is_truthy(aTooltipInstance())
    c.bags[0][1] = nil
    fire("TOOLTIP_DATA_UPDATE", aTooltipInstance())
    frames(13)
    assert.equal(1, #handle.errors, failure("one error"))
    assert.is_truthy(handle.errors[1]:find(THE_REPORTED_ERROR, 1, true), handle.errors[1])
    assert.is_false(refresh._held)
    assert.is_nil(refresh._world)
  end)

  ---------------------------------------------------------------------------------------------------------------------
  -- Every order of a loading screen's steps: its two signals, the items taken, the player back, the loading screen
  -- ending, the items given back; with a recalculation among them.
  ---------------------------------------------------------------------------------------------------------------------

  it("loading screens: asks only when the items leave while the bags are not held", function()
    start()
    local held, takenWhile
    local actions = {
      LSE = function() fire("LOADING_SCREEN_ENABLED") end,
      PLW = function() fire("PLAYER_LEAVING_WORLD") end,
      X = function()
        takenWhile = refresh._held and "held" or "not held"
        held = c.bags
        c.bags = { [0] = {}, [1] = {}, [5] = {} }
      end,
      PEW = function() fire("PLAYER_ENTERING_WORLD", false, false) end,
      LSD = function() fire("LOADING_SCREEN_DISABLED") end,
      B = function()
        c.bags = held
        for _, bag in ipairs(BACKPACK) do report(bag) end
      end,
      T = function() send("bags/Rederive", { backpack = true, bank = false, categoriesUnchanged = true }) end,
      F = function() frame() end,
    }
    local function position(order, name)
      for i, token in ipairs(order) do
        if token == name then return i end
      end
    end
    local stats = { held = { orders = 0, asked = 0 }, ["not held"] = { orders = 0, asked = 0 } }
    local count = 0
    eachOrder({ LSE = 1, PLW = 1, X = 1, PEW = 1, LSD = 1, B = 1, T = 1, F = 3 }, function(order)
      -- The items cannot come back before they left; each signal's end comes after it.
      if position(order, "X") < position(order, "B") and position(order, "LSE") < position(order, "LSD")
        and position(order, "PLW") < position(order, "PEW") then
        count = count + 1
        if sampled(count, 601) then
          reset()
          for _, token in ipairs(order) do actions[token]() end
          drain()
          local stat = stats[takenWhile]
          stat.orders = stat.orders + 1
          if #c.asked > 0 then stat.asked = stat.asked + 1 end
          local other
          for _, err in ipairs(handle.errors) do
            if not err:find(THE_REPORTED_ERROR, 1, true) then other = err end
          end
          assert.is_nil(other, table.concat(order, " "))
        end
      end
    end)
    if REPORT then
      print(string.format("loading screens: %d orders; items leaving while held: %d (asked %d); while not held: %d " ..
        "(asked %d)", count, stats.held.orders, stats.held.asked, stats["not held"].orders, stats["not held"].asked))
    end
    assert.is_true(stats.held.orders > 0)
    assert.equal(0, stats.held.asked)
    assert.is_true(stats["not held"].asked > 0)
  end)

  ---------------------------------------------------------------------------------------------------------------------
  -- Leaving a bank: the bank's containers, BANKFRAME_CLOSED (twice; warcraft.wiki.gg: the data is there only at the
  -- first) and the banker interaction's end, in every order.
  ---------------------------------------------------------------------------------------------------------------------

  local function openBank()
    for bag, size in pairs(BANK_SIZES) do
      c.sizes[bag], c.bags[bag] = size, {}
      give(bag, 1, 301)
      give(bag, 2, 302)
    end
    c.bankOpen = true
    fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", BANKER)
    fire("BANKFRAME_OPENED")
    drain()
    for i = #handle.errors, 1, -1 do handle.errors[i] = nil end
    c.asked = {}
    assert.is_true(next(items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey) ~= nil, "the bank was read")
  end

  -- BANKFRAME_CLOSED fires twice; the bank's data is there only at the first (warcraft.wiki.gg).
  local function closeBank()
    fire("BANKFRAME_CLOSED")
    c.sizes[6], c.sizes[12], c.bags[6], c.bags[12] = 0, 0, {}, {}
    fire("BANKFRAME_CLOSED")
    fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", BANKER)
    c.bankOpen = false
  end

  local BANK = { 6, 12 }

  local function moved(fromBags, toBags)
    local fromBag, fromSlot, item = firstFilled(fromBags)
    local toBag, toSlot = firstEmpty(toBags)
    if not (fromBag and toBag) then return end
    c.bags[fromBag][fromSlot], c.bags[toBag][toSlot] = nil, item
    report(fromBag)
    if toBag ~= fromBag then report(toBag) end
  end

  it("the bank closing: asks only when its slots go while the bank is still open", function()
    start()
    local stats = { ["before it closed"] = { orders = 0, asked = 0 }, ["once it closed"] = { orders = 0, asked = 0 } }
    local goneWhen
    local actions = {
      X = function()
        goneWhen = addon.atBank and "before it closed" or "once it closed"
        c.sizes[6], c.sizes[12] = 0, 0
        c.bags[6], c.bags[12] = {}, {}
      end,
      C = function() fire("BANKFRAME_CLOSED") end,
      H = function() fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", BANKER) end,
      T = function() send("bags/Rederive", { backpack = true, bank = addon.atBank == true, categoriesUnchanged = true }) end,
      F = function() frame() end,
    }
    local count = 0
    eachOrder({ X = 1, C = 2, H = 1, T = 1, F = 1 }, function(order)
      count = count + 1
      if sampled(count, 3) then
        reset()
        openBank()
        for _, token in ipairs(order) do actions[token]() end
        drain()
        local stat = stats[goneWhen]
        stat.orders = stat.orders + 1
        if #c.asked > 0 then stat.asked = stat.asked + 1 end
      end
    end)
    if REPORT then
      print(string.format("the bank closing: %d orders; slots going before BANKFRAME_CLOSED: %d (asked %d); once it " ..
        "fired: %d (asked %d)", count, stats["before it closed"].orders, stats["before it closed"].asked,
        stats["once it closed"].orders, stats["once it closed"].asked))
    end
    assert.is_true(stats["once it closed"].orders > 0)
    assert.equal(0, stats["once it closed"].asked)
    assert.is_true(stats["before it closed"].asked > 0)
  end)

  it("never asks while at the bank: every change there, every trigger, every moment", function()
    start()
    local function bankHeld()
      local held = {}
      for bag in pairs(BANK_SIZES) do
        for slot = 1, c.sizes[bag] or 0 do
          local item = slotOf(bag, slot)
          if item then held[bag .. "_" .. slot] = item.guid end
        end
      end
      return held
    end
    local function bankCommitted()
      local held = {}
      for slotkey, item in pairs(items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey) do
        if not item.isItemEmpty then held[slotkey] = item.itemInfo.itemGUID end
      end
      return held
    end
    local changes = {
      { "an item deposited", function() moved(BACKPACK, BANK) end },
      { "an item withdrawn", function() moved(BANK, BACKPACK) end },
      { "an item moved between bank tabs", function() moved(BANK, BANK) end },
      { "a bank slot emptied", function()
        local bag, slot = firstFilled(BANK)
        if bag then
          c.bags[bag][slot] = nil
          report(bag)
        end
      end },
    }
    local triggers = { { "a recalculation of both", function() send("bags/Rederive", { backpack = true, bank = true }) end } }
    for _, trigger in ipairs(TRIGGERS) do table.insert(triggers, trigger) end
    local cases, derives = 0, 0
    for _, change in ipairs(changes) do
      for _, trigger in ipairs(triggers) do
        for _, timing in ipairs(TIMINGS) do
          if sampled(cases, 61) then
            reset()
            openBank()
            c.derives = 0
            local what = change[1] .. " / " .. trigger[1] .. " / " .. timing[1]
            local ok, err = pcall(timing[2], change[2], trigger[2])
            if not ok then error(what .. ": " .. tostring(err), 0) end
            finish(what)
            -- The bank is read tab by tab: the last recalculation reads whichever it committed.
            send("bags/RefreshBank")
            drain()
            assert.same(bankHeld(), bankCommitted(), what)
            derives = derives + c.derives
            closeBank()
            drain()
            check(what .. ", closing")
          end
          cases = cases + 1
        end
      end
    end
    if REPORT then print(string.format("at the bank: %d cases, %d recalculations", cases, derives)) end
    assert.is_true(derives > 0)
  end)

  -- A recalculation is waiting behind a read when a bag goes: it runs first, and the full read the bag's event asked for
  -- cannot ride on it.
  it("leaves alone a bag swapped while a recalculation waits", function()
    start()
    send("bags/RefreshBackpack")
    send("bags/Rederive", { backpack = true })
    c.sizes[1] = 2
    c.bags[1][3] = nil
    fire("BAG_CONTAINER_UPDATE")
    finish("a bag swapped behind a waiting recalculation")
  end)

  -- A unit recalculating the bank and the backpack has done the bank's half when the player leaves the world. It goes on
  -- first once the wait ends, before the world's read, with the items not back yet.
  it("leaves alone the items taken from a unit parked between the bank and the backpack", function()
    start()
    openBank()
    send("bags/Rederive", { backpack = true, bank = true })
    assert.is_not_nil(refresh._active, "the unit is parked after the bank's half")
    fire("LOADING_SCREEN_ENABLED")
    local held = { [0] = c.bags[0], [1] = c.bags[1], [5] = c.bags[5] }
    c.bags[0], c.bags[1], c.bags[5] = {}, {}, {}
    fire("PLAYER_LEAVING_WORLD")
    fire("PLAYER_ENTERING_WORLD", false, false)
    fire("LOADING_SCREEN_DISABLED")
    frames(4)
    assert.same({}, c.asked)
    c.bags[0], c.bags[1], c.bags[5] = held[0], held[1], held[5]
    for _, bag in ipairs(BACKPACK) do report(bag) end
    closeBank()
    finish("a unit parked across a loading screen")
  end)

  -- While the bags are held nothing goes on: a read parked as the player leaves commits what it harvested once the wait
  -- ends, and a recalculation asked for meanwhile waits for the world's read.
  it("starts and finishes no unit while the bags are held", function()
    start()
    send("bags/RefreshBackpack")
    local parked = refresh._active
    assert.is_not_nil(parked)
    fire("LOADING_SCREEN_ENABLED")
    send("bags/Rederive", { backpack = true })
    frames(5)
    assert.equal(parked, refresh._active)
    fire("LOADING_SCREEN_DISABLED")
    finish("a read parked across a loading screen")
  end)

  ---------------------------------------------------------------------------------------------------------------------
  -- What it takes: a slot empty on the client, unmarked, reaches the same error from every trigger.
  ---------------------------------------------------------------------------------------------------------------------

  it("raises the reported error from every trigger once a slot empties unreported", function()
    start()
    for _, trigger in ipairs(TRIGGERS) do
      reset()
      c.bags[0][1] = nil
      trigger[2]()
      drain()
      assert.is_true(#c.asked > 0, trigger[1])
      assert.equal("GetItemGUID", c.asked[1].api, trigger[1])
      assert.is_truthy(handle.errors[1]:find(THE_REPORTED_ERROR, 1, true), trigger[1] .. ": " .. tostring(handle.errors[1]))
    end
  end)

  it("keeps raising it, once per recalculation, until a read of that bag", function()
    start()
    c.bags[0][1] = nil
    for _ = 1, 8 do
      send("bags/Rederive", { backpack = true })
      drain()
    end
    assert.equal(8, #handle.errors)
    -- A change reported in another bag reads only that bag: the same error next time.
    c.bags[1][1] = nil
    report(1)
    drain()
    send("bags/Rederive", { backpack = true })
    drain()
    assert.equal(9, #handle.errors)
    -- A report of this bag, of anything in it, ends it.
    report(0)
    drain()
    send("bags/Rederive", { backpack = true })
    drain()
    assert.equal(9, #handle.errors)
    assert.same(backpackHeld(), backpackCommitted())
  end)

  it("names another line when the item object is gone and the slot still reads as filled", function()
    start()
    c.bags[0][1].objectGone = true
    send("bags/Rederive", { backpack = true })
    drain()
    assert.equal(1, #handle.errors)
    assert.is_truthy(handle.errors[1]:find(THE_REPORTED_ERROR, 1, true), handle.errors[1])
    -- A read of the bag asks too, where a truly empty slot asks nothing: no player has reported these lines.
    for i = #handle.errors, 1, -1 do handle.errors[i] = nil end
    send("bags/RefreshBackpack")
    drain()
    assert.equal(1, #handle.errors)
    assert.is_nil(handle.errors[1]:find(RECALCULATION_LINE, 1, true), handle.errors[1])
    assert.is_truthy(handle.errors[1]:find("data/items.lua", 1, true), handle.errors[1])
    if REPORT then print("the item object gone, on a read: " .. handle.errors[1]) end
  end)

  ---------------------------------------------------------------------------------------------------------------------
  -- Long sessions: everything above at random, in every design and client.
  ---------------------------------------------------------------------------------------------------------------------

  local function session(seed, length)
    local function random(n)
      seed = (seed * 1103515245 + 12345) % 2147483648
      return (math.floor(seed / 65536) % n) + 1
    end
    c.random = random
    local log = {}
    local ops = {}
    for _, change in ipairs(CHANGES) do
      -- Changes that take a bag off put it back, so a session goes on having bags.
      table.insert(ops, change)
    end
    for _, trigger in ipairs(TRIGGERS) do table.insert(ops, trigger) end
    for _, read in ipairs(READS) do table.insert(ops, read) end
    table.insert(ops, { "frames pass", function() frames(random(12)) end })
    table.insert(ops, { "item data starts arriving late", function() c.warm = false end })
    table.insert(ops, { "item data arrives", function()
      c.warm = true
      load()
    end })
    table.insert(ops, { "the bank opening", function()
      if c.bankOpen then return end
      c.bankOpen = true
      for bag, size in pairs(BANK_SIZES) do
        c.sizes[bag], c.bags[bag] = size, {}
        give(bag, 1, 301)
        give(bag, 2, 302)
      end
      fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", BANKER)
      fire("BANKFRAME_OPENED")
    end })
    table.insert(ops, { "the bank closing", function()
      if c.bankOpen then closeBank() end
    end })
    table.insert(ops, { "an item deposited", function()
      if c.bankOpen then moved(BACKPACK, BANK) end
    end })
    table.insert(ops, { "an item withdrawn", function()
      if c.bankOpen then moved(BANK, BACKPACK) end
    end })
    table.insert(ops, { "a recalculation of the bank", function()
      send("bags/Rederive", { backpack = true, bank = true })
    end })
    table.insert(ops, { "a loading screen", function()
      fire("LOADING_SCREEN_ENABLED")
      frames(random(10))
      if c.bankOpen then closeBank() end
      local held = { [0] = c.bags[0], [1] = c.bags[1], [5] = c.bags[5] }
      c.bags = { [0] = {}, [1] = {}, [5] = {} }
      send("bags/Rederive", { backpack = true })
      frames(random(10))
      fire("PLAYER_LEAVING_WORLD")
      frames(random(5))
      fire("BAG_CONTAINER_UPDATE")
      fire("PLAYER_ENTERING_WORLD", false, false)
      fire("LOADING_SCREEN_DISABLED")
      frames(random(3))
      c.bags = held
      for _, bag in ipairs(BACKPACK) do report(bag) end
    end })
    table.insert(ops, { "new bags", function()
      if c.bankOpen then return end
      fill()
      fire("BAG_CONTAINER_UPDATE")
      report(0)
    end })
    for _ = 1, length do
      local op = ops[random(#ops)]
      table.insert(log, op[1])
      local ok, err = pcall(op[2])
      if not ok then error(table.concat(log, ", ", math.max(1, #log - 12)) .. ": " .. tostring(err), 0) end
      if #c.asked > 0 or #handle.errors > 0 then
        error(failure("after " .. table.concat(log, ", ", math.max(1, #log - 12))), 0)
      end
    end
    c.warm, c.random = true, nil
    if c.bankOpen then closeBank() end
    finish("end of a session")
  end

  for _, variant in ipairs({
    { "classic bags", {} },
    { "BetterBags Next", { next = true } },
    { "WoW: Forever", { client = "forever" } },
  }) do
    it("long random sessions never ask: " .. variant[1], function()
      start(variant[2])
      local seeds = FULL and 300 or 2
      for seed = 1, seeds do
        reset()
        session(seed, 200)
      end
      if REPORT then print(variant[1] .. ": " .. seeds .. " sessions, 200 steps each") end
    end)
  end
end)
