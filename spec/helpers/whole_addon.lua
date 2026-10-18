-- whole_addon.lua -- Loads all of BetterBags the way the client does, for tests of behavior that
-- crosses the whole addon (switching bag designs, next.md §11). Every other spec loads the few
-- modules it needs next to stubs; that hid an error a switch made in game, because no spec ran the
-- real classic bags' creation after a theme was applied.
--
-- local WholeAddon = dofile("spec/helpers/whole_addon.lua"). WholeAddon.Load(opts) makes a fresh
-- BetterBags addon object (the one spec/helpers/addon_loader.lua
-- made is set aside), sets up the retail client the files expect, loads every Lua file of
-- BetterBags.toc in order (libraries the specs do not load are loaded or stood in for), and records
-- every error that reaches the error handler. handle:Start() starts it as the client does, through
-- AceAddon's own handler: ADDON_LOADED initializes the addon (its OnInitialize) while its modules
-- are still queued, so the modules it enables are only marked, then PLAYER_LOGIN enables the addon
-- (its OnEnable) and every marked module (Sonata applies the theme then, after the bags exist).
-- Saved variables start empty. handle:Restore() puts back everything Load changed in place, so later spec files see
-- the addon they expect: the AceAddon registry, LibStub's libraries, the Enum tables, the globals it
-- set, and the events and hooks the loaded addon registered.
--
-- The client set up here is live retail or WoW: Forever: Enum.BagIndex, Enum.PlayerInteractionType
-- and Enum.ItemQuality are Blizzard's (Blizzard_APIDocumentationGenerated on the live and forever
-- branches: BagIndexConstants, PlayerInteractionType, ItemQuality; the last two are the same on
-- both), the other values are the ones spec/core/constants_spec.lua uses. The mocks have no layout engine, so every frame the loaded addon makes is resolved at the
-- screen's origin, as if laid out, and the cursor is far off screen, so no frame is under it.

local WholeAddon = {}

-- WoW: Forever 1.60.1 (the forever branch's BagIndexConstantsDocumentation.lua): retail-shaped,
-- 9 character and 9 account bank tabs.
local FOREVER_BAG_INDEX = {
  Accountbanktab = -3, Characterbanktab = -2, Keyring = -1, Backpack = 0, Bag_1 = 1, Bag_2 = 2,
  Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
}
for i = 1, 9 do
  FOREVER_BAG_INDEX["CharacterBankTab_" .. i] = 5 + i
  FOREVER_BAG_INDEX["AccountBankTab_" .. i] = 14 + i
end

local RETAIL_BAG_INDEX = {
  Accountbanktab = -3, Characterbanktab = -2, Keyring = -1, Backpack = 0, Bag_1 = 1, Bag_2 = 2,
  Bag_3 = 3, Bag_4 = 4, ReagentBag = 5, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7,
  CharacterBankTab_3 = 8, CharacterBankTab_4 = 9, CharacterBankTab_5 = 10, CharacterBankTab_6 = 11,
  AccountBankTab_1 = 12, AccountBankTab_2 = 13, AccountBankTab_3 = 14, AccountBankTab_4 = 15,
  AccountBankTab_5 = 16,
}

local PLAYER_INTERACTION_TYPE = {
  None = 0, TradePartner = 1, Item = 2, Merchant = 5, Banker = 8, GuildBanker = 10, MailInfo = 17,
  Auctioneer = 21, VoidStorageBanker = 26, ScrappingMachine = 40, ItemUpgrade = 53,
  CharacterBanker = 67, AccountBanker = 68,
}

local ITEM_QUALITY = {
  Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7,
  WoWToken = 8,
}

local INVENTORY_TYPE = {
  IndexHeadType = 1, IndexNeckType = 2, IndexShoulderType = 3, IndexBodyType = 4, IndexChestType = 5,
  IndexWaistType = 6, IndexLegsType = 7, IndexFeetType = 8, IndexWristType = 9, IndexHandType = 10,
  IndexFingerType = 11, IndexTrinketType = 12, IndexWeaponType = 13, IndexShieldType = 14,
  IndexRangedType = 15, IndexCloakType = 16, Index2HweaponType = 17, IndexTabardType = 18,
  IndexRobeType = 20, IndexWeaponmainhandType = 21, IndexWeaponoffhandType = 22,
  IndexHoldableType = 23, IndexThrownType = 25, IndexRangedrightType = 26,
}

local INVENTORY_SLOTS = { "HEAD", "NECK", "SHOULDER", "BODY", "CHEST", "WAIST", "LEGS", "FEET", "WRIST",
  "HAND", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2", "BACK", "MAINHAND", "OFFHAND", "RANGED", "TABARD" }

local EXPANSIONS = {
  { "CLASSIC", "Classic" }, { "BURNING_CRUSADE", "Burning Crusade" },
  { "WRATH_OF_THE_LICH_KING", "Wrath of the Lich King" }, { "CATACLYSM", "Cataclysm" },
  { "MISTS_OF_PANDARIA", "Mists of Pandaria" }, { "WARLORDS_OF_DRAENOR", "Warlords of Draenor" },
  { "LEGION", "Legion" }, { "BATTLE_FOR_AZEROTH", "Battle for Azeroth" }, { "SHADOWLANDS", "Shadowlands" },
  { "DRAGONFLIGHT", "Dragonflight" }, { "WAR_WITHIN", "The War Within" }, { "MIDNIGHT", "Midnight" },
}

local QUALITY_NAMES = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom",
  "WoWToken" }

-- The bag-bar buttons (Blizzard_MainMenuBarBagButtons): each has a SlotHighlightTexture
-- (BaseBagSlotButtonTemplate). Live retail has no KeyRingButton; WoW: Forever has one
-- (Camelot/MainMenuBarBagButtons.xml, ShapedBagSlotButtonTemplate).
local BAG_BAR_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
  "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot" }

-- Libraries the TOC loads that spec/setup.lua does not. Two start with a UTF-8 byte order mark,
-- which the client skips and Lua 5.1's loadfile rejects.
local LIBRARIES = { "libs/LibWindow-1.1/LibWindow-1.1.lua", "libs/WagoAnalytics/Shim.lua" }
local LIBRARY_NAMES = { "LibWindow-1.1", "WagoAnalytics", "LibUIDropDownMenu-4.0" }

-- The files spec/setup.lua already loaded, with their modules, into the addon set aside; the fresh
-- addon gets its own copy of each.
---@param toc string
local function tocFiles(toc)
  local files = {}
  for line in io.lines(toc) do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") and not line:match("^libs") and line:match("%.lua$") then
      table.insert(files, (line:gsub("\\", "/")))
    end
  end
  return files
end

---@param path string
local function loadWithoutBOM(path, ...)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  src = src:gsub("^\239\187\191", "")
  return assert(loadstring(src, "@" .. path))(...)
end

---@class WholeAddonHandle
---@field addon table The fresh BetterBags addon.
---@field errors string[] Every error that reached the error handler, in order.

-- opts.client is "retail" (live, BetterBags.toc; the default) or "forever" (WoW: Forever,
-- BetterBags_Camelot.toc). opts.next starts with BetterBags Next on; opts.sizeMode ("content" or
-- "window") sizes every bag in every view that way (the bags' "Drag to Resize"); opts.theme is the
-- saved theme; opts.profile(defaults, const) changes any other default the profile starts with;
-- opts.globals sets globals other addons would (a theme's addon), restored afterwards.
-- opts.install is "existing" (the default: the saved variables of an install that never changed a
-- setting) or "new" (no saved variables at all: a new install, which starts with BetterBags Next,
-- next.md §1).
---@param opts? { client?: "retail"|"forever", next?: boolean, sizeMode?: WindowSizeMode, theme?: string, profile?: fun(defaults: table, const: table), globals?: table<string, any>, install?: "existing"|"new" }
---@return WholeAddonHandle
function WholeAddon.Load(opts)
  opts = opts or {}
  local restorers = {}
  -- Every global as it was: the loaded addon makes named frames and functions (keybindings,
  -- slash commands), and any of them left behind keeps the whole addon in memory.
  local globalsBefore = {}
  for name, value in pairs(_G) do globalsBefore[name] = value end
  table.insert(restorers, function()
    for name in pairs(_G) do
      if globalsBefore[name] == nil then rawset(_G, name, nil) end
    end
    for name, value in pairs(globalsBefore) do
      if rawget(_G, name) ~= value then rawset(_G, name, value) end
    end
  end)
  local function setGlobal(name, value)
    local old = rawget(_G, name)
    table.insert(restorers, function() rawset(_G, name, old) end)
    rawset(_G, name, value)
  end
  local function setField(tbl, key, value)
    local old = rawget(tbl, key)
    table.insert(restorers, function() rawset(tbl, key, old) end)
    rawset(tbl, key, value)
  end

  -- Tables shared with the rest of the specs that the loaded addon adds to in place: each is put
  -- back as it was.
  local function keepAsIs(tbl)
    if tbl == nil then return end
    local before = {}
    for key, value in pairs(tbl) do before[key] = value end
    table.insert(restorers, function()
      for key in pairs(tbl) do
        if before[key] == nil then tbl[key] = nil end
      end
      for key, value in pairs(before) do tbl[key] = value end
    end)
  end
  keepAsIs(_G.SlashCmdList)
  -- The libraries' own registries: what they were embedded in (AceHook's embeded, keyed by the
  -- addon), AceDB's databases, AceConsole's commands, and the like.
  for _, lib in pairs(LibStub.libs) do
    if type(lib) == "table" then
      for _, field in pairs(lib) do
        if type(field) == "table" then keepAsIs(field) end
      end
    end
  end
  -- A mock frame lists the frames parented to it (_children, for GetChildren): the loaded addon
  -- parents thousands to UIParent and other frames made before it.
  local seenFrames = {}
  for _, value in pairs(globalsBefore) do
    if type(value) == "table" and type(rawget(value, "_children")) == "table" and not seenFrames[value] then
      seenFrames[value] = true
      local children = { unpack(value._children) }
      table.insert(restorers, function() value._children = children end)
    end
  end

  -- The addon set aside: AceAddon's registry, statuses and queues.
  local aceAddon = LibStub("AceAddon-3.0")
  local setAside, statuses = {}, {}
  for name, object in pairs(aceAddon.addons) do
    if name == "BetterBags" or name:match("^BetterBags_") then
      setAside[name], statuses[name] = object, aceAddon.statuses[name]
      aceAddon.addons[name], aceAddon.statuses[name] = nil, nil
    end
  end
  -- AceAddon's queues hold only the fresh addon while it is loaded and started.
  local queued = {}
  for _, queue in ipairs({ aceAddon.initializequeue, aceAddon.enablequeue }) do
    local entries = {}
    for i = #queue, 1, -1 do table.insert(entries, 1, table.remove(queue, i)) end
    queued[queue] = entries
  end
  table.insert(restorers, function()
    for name in pairs(aceAddon.addons) do
      if name == "BetterBags" or name:match("^BetterBags_") then
        aceAddon.addons[name], aceAddon.statuses[name] = nil, nil
      end
    end
    for name, object in pairs(setAside) do
      aceAddon.addons[name], aceAddon.statuses[name] = object, statuses[name]
    end
    for queue, entries in pairs(queued) do
      for i = #queue, 1, -1 do table.remove(queue, i) end
      for _, entry in ipairs(entries) do table.insert(queue, entry) end
    end
  end)

  -- Libraries added to LibStub are taken out again: other specs install stand-ins only when a
  -- library is missing.
  local libs, minors = {}, {}
  for name, lib in pairs(LibStub.libs) do libs[name] = lib end
  for name, minor in pairs(LibStub.minors) do minors[name] = minor end
  table.insert(restorers, function()
    for name in pairs(LibStub.libs) do
      if libs[name] == nil then LibStub.libs[name], LibStub.minors[name] = nil, nil end
    end
    for name, lib in pairs(libs) do LibStub.libs[name], LibStub.minors[name] = lib, minors[name] end
  end)

  -- The client, with the saved variables of an install that never changed a setting, or none (a new
  -- install). WoW: Forever is the camelot project
  -- (Blizzard_ProjectConstants/Camelot/ProjectConstants.lua: WOW_PROJECT_CAMELOT = 18).
  local forever = opts.client == "forever"
  setGlobal("BetterBagsDB", opts.install ~= "new" and {} or nil)
  setGlobal("BetterBagsPerfDB", nil)
  setGlobal("WOW_PROJECT_MAINLINE", 1)
  setGlobal("WOW_PROJECT_CAMELOT", forever and 18 or nil)
  setGlobal("WOW_PROJECT_ID", forever and 18 or 1)
  setField(Enum, "BagIndex", forever and FOREVER_BAG_INDEX or RETAIL_BAG_INDEX)
  setField(Enum, "PlayerInteractionType", PLAYER_INTERACTION_TYPE)
  setField(Enum, "ItemQuality", ITEM_QUALITY)
  setField(Enum, "InventoryType", INVENTORY_TYPE)
  for i, slot in ipairs(INVENTORY_SLOTS) do setGlobal("INVSLOT_" .. slot, i) end
  for i, expansion in ipairs(EXPANSIONS) do
    setGlobal("LE_EXPANSION_" .. expansion[1], i - 1)
    setGlobal("EXPANSION_NAME" .. (i - 1), expansion[2])
  end
  for i, quality in ipairs(QUALITY_NAMES) do setGlobal("ITEM_QUALITY" .. (i - 1) .. "_DESC", quality) end
  setGlobal("UISpecialFrames", {})
  -- Blizzard's own frames and functions BetterBags hides, hooks or reads at startup.
  for _, name in ipairs({ "ContainerFrameCombinedBags", "BagsBar", "BankFrame" }) do
    setGlobal(name, CreateFrame("Frame", name))
  end
  for i = 1, 13 do setGlobal("ContainerFrame" .. i, CreateFrame("Frame", "ContainerFrame" .. i)) end
  local bagBar = { unpack(BAG_BAR_BUTTONS) }
  if forever then table.insert(bagBar, "KeyRingButton") end
  for _, name in ipairs(bagBar) do
    local button = CreateFrame("Button", name)
    button.SlotHighlightTexture = button:CreateTexture(nil, "OVERLAY")
    setGlobal(name, button)
  end
  -- Live retail: 4 bag slots and the reagent bag (ContainerFrame.lua, ItemConstants_Mainline).
  setGlobal("NUM_BAG_FRAMES", 4)
  setGlobal("NUM_TOTAL_BAG_FRAMES", 5)
  setGlobal("OpenBag", function() end)
  setGlobal("CloseBag", function() end)
  setGlobal("ToggleAllBags", function() end)
  setGlobal("CloseSpecialWindows", function() end)
  -- GetInventoryItemTexture(unit, invSlot) -> texture?, GetInventoryItemQuality(unit, invSlot) ->
  -- quality?: no bag is in any bag slot here.
  setGlobal("GetInventoryItemTexture", function() return nil end)
  setGlobal("GetInventoryItemQuality", function() return nil end)
  setGlobal("GetScreenWidth", function() return UIParent:GetWidth() end)
  setGlobal("GetScreenHeight", function() return UIParent:GetHeight() end)
  setGlobal("C_CVar", { SetCVar = function() end, SetCVarBitfield = function() end, GetCVar = function() end })
  -- Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua: the button's own method when it has one.
  setGlobal("SetItemButtonTexture", function(button, texture)
    if not button then return end
    if button.SetItemButtonTexture then
      button:SetItemButtonTexture(texture)
    elseif button.icon then
      button.icon:SetTexture(texture)
    end
  end)
  setGlobal("SetItemButtonQuality", function(button, ...)
    if button and button.SetItemButtonQuality then button:SetItemButtonQuality(...) end
  end)
  setGlobal("SetItemButtonCount", function(button, count)
    if not button then return end
    count = count or 0
    button.count = count
    local countString = button.Count
    if countString == nil then return end
    if count > (button.minDisplayCount or 1) or (button.isBag and count > 0) then
      countString:SetText(count)
      countString:Show()
    else
      countString:Hide()
    end
  end)
  local createFrame = CreateFrame
  setGlobal("CreateFrame", function(...)
    local frame = createFrame(...)
    if frame._rect == nil then frame._rect = { left = 0, bottom = 0 } end
    return frame
  end)
  setGlobal("_cursorX", -10000)
  setGlobal("_cursorY", -10000)

  for name, value in pairs(opts.globals or {}) do setGlobal(name, value) end

  ---@type WholeAddonHandle
  local handle = { errors = {} }
  setGlobal("geterrorhandler", function()
    return function(e) table.insert(handle.errors, tostring(e)) end
  end)

  -- Each library loads fresh: a copy another spec registered (a stand-in, or the same library)
  -- would be upgraded in place by NewLibrary, keeping what the loaded addon put in it. The
  -- copy is put back with the rest of LibStub.
  for _, name in ipairs(LIBRARY_NAMES) do
    LibStub.libs[name], LibStub.minors[name] = nil, nil
  end
  for _, path in ipairs(LIBRARIES) do loadWithoutBOM(path) end
  -- LibUIDropDownMenu needs much of Blizzard's frame code; the context menu's calls are stood in for.
  local dropdown = LibStub:NewLibrary("LibUIDropDownMenu-4.0", 1)
  if dropdown then
    function dropdown:Create_UIDropDownMenu(name, parent) return CreateFrame("Frame", name, parent) end
    function dropdown:EasyMenu_Initialize() end
    function dropdown:EasyMenu() end
    function dropdown:HideDropDownMenu() end
  end

  for _, path in ipairs(tocFiles(forever and "BetterBags_Camelot.toc" or "BetterBags.toc")) do
    assert(loadfile(path))("BetterBags", {})
  end
  handle.addon = aceAddon:GetAddon("BetterBags")
  local const = handle.addon:GetModule("Constants")
  local defaults = const.DATABASE_DEFAULTS.profile
  if opts.next then
    defaults.nextEnabled = true
  end
  if opts.sizeMode then
    for _, kinds in pairs(defaults.size) do
      for _, info in pairs(kinds) do info.sizeMode = opts.sizeMode end
    end
  end
  if opts.theme then
    defaults.theme = opts.theme
  end
  if opts.profile then
    opts.profile(defaults, const)
  end

  -- Runs first (restorers run last to first): unhooking reads the libraries' registries, which
  -- are put back afterwards.
  table.insert(restorers, function()
    local events = handle.addon:GetModule("Events")
    if events._eventHandler and events._eventHandler.UnregisterAllEvents then
      events._eventHandler:UnregisterAllEvents()
      events._eventHandler:UnregisterAllMessages()
    end
    handle.addon:UnhookAll()
    -- Sonata follows the client's text size (sonata.md §3c).
    EventRegistry:UnregisterCallback("TextSizeManager.OnTextScaleUpdated", handle.addon:GetModule("Sonata"))
  end)

  -- Start runs what the client runs as BetterBags loads and the player logs in: AceAddon's own
  -- handler of ADDON_LOADED (not logged in yet), then of PLAYER_LOGIN.
  function handle:Start()
    local onEvent = aceAddon.frame:GetScript("OnEvent")
    setGlobal("IsLoggedIn", function() return false end)
    onEvent(aceAddon.frame, "ADDON_LOADED", "BetterBags")
    setGlobal("IsLoggedIn", function() return true end)
    onEvent(aceAddon.frame, "PLAYER_LOGIN")
  end

  -- Restore frees the loaded addon too (a load and start take about 940 MB of mock frames): a full
  -- collection, so no more than one load is ever in memory.
  function handle:Restore()
    for i = #restorers, 1, -1 do restorers[i]() end
    restorers = {}
    self.addon = nil
    collectgarbage("collect")
  end

  return handle
end

return WholeAddon
