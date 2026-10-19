local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("Core Init and Enable flow", function()
  local savedDatabase
  local oldOnInitialize, oldOnEnable
  local oldBags
  local originalUISpecialFrames
  local oldBindingFrame
  local oldModules
  local oldAddons
  local oldCCVar

  before_each(function()
    oldBags = addon.Bags
    addon.Bags = {}
    originalUISpecialFrames = _G.UISpecialFrames
    _G.UISpecialFrames = {}
    oldBindingFrame = addon._bindingFrame
    addon._bindingFrame = nil

    oldCCVar = _G.C_CVar
    _G.C_CVar = _G.C_CVar or {
      SetCVar = function() end,
      SetCVarBitfield = function() end,
    }

    -- Save all modules and addons to restore them later
    oldModules = {}
    for k, v in pairs(addon.modules) do
      oldModules[k] = v
    end

    local aceAddon = LibStub("AceAddon-3.0")
    oldAddons = {}
    for k, v in pairs(aceAddon.addons) do
      oldAddons[k] = v
    end

    -- Save original hooks if any
    oldOnInitialize = addon.OnInitialize
    oldOnEnable = addon.OnEnable

    -- Stub all modules that core/init.lua GetModule's
    local modules = {
      "Localization", "Database", "BagFrame", "Constants", "Items", "ItemFrame",
      "Events", "Masque", "SectionFrame", "Categories", "ContextMenu", "Config",
      "Currency", "Search", "ConsolePort", "Pawn", "Question", "SimpleItemLevel",
      "QuickFind", "Refresh", "ItemLoader", "Views", "SearchCategoryConfig",
      "Async", "Context", "Debug", "Form", "Bucket", "TooltipScanner", "Groups",
      "EquipmentSets", "BagButton", "ItemRowFrame", "Perf", "PerfSessions", "RenderRecorder", "Simulator", "Render", "Window", "Sonata", "Tabs", "ChangelogWindow", "NextBag", "NextBank", "NextVendor",
      "GuildBank", "NextGuildBank"
    }

    for _, name in ipairs(modules) do
      local stub = StubBetterBagsModule(name)
      stub.Init = stub.Init or spy.new(function() end)
      stub.Enable = stub.Enable or spy.new(function() end)
    end
    local perfSessions = addon:GetModule("PerfSessions")
    perfSessions.StartIfArmed = perfSessions.StartIfArmed or spy.new(function() return false end)
    local nextVendor = addon:GetModule("NextVendor")
    nextVendor.Create = nextVendor.Create or function()
      return { frame = CreateFrame("Frame"), GetName = function() return "BetterBagsNextVendor" end }
    end
    nextVendor.TakeOver = nextVendor.TakeOver or function() end

    -- Provide specific mock implementations needed by init
    local L = addon:GetModule("Localization")
    L.G = L.G or function(_, val) return val end

    local const = addon:GetModule("Constants")
    const.BAG_KIND = { BACKPACK = 0, BANK = 1 }

    local db = addon:GetModule("Database")
    db.GetEnableBankBag = db.GetEnableBankBag or function() return true end
    -- Replaced, not defaulted with "or": an earlier spec in the suite may have loaded the real
    -- Database, whose Init would open AceDB on whatever BetterBagsDB it left (none is a new install,
    -- which starts with BetterBags Next, next.md §1) and whose GetNextEnabled would read that
    -- profile (.context/patterns-state.md, "Spec Files Must Pass Alone and Shuffled").
    savedDatabase = { Init = rawget(db, "Init"), GetNextEnabled = rawget(db, "GetNextEnabled") }
    db.Init = spy.new(function() end)
    db.GetNextEnabled = function() return false end
    db.GetShowBagButton = db.GetShowBagButton or function() return true end

    local eventsMod = addon:GetModule("Events")
    eventsMod.RegisterEvent = eventsMod.RegisterEvent or function() end
    eventsMod.RegisterMessage = eventsMod.RegisterMessage or function() end

    local contextMod = addon:GetModule("Context")
    contextMod.New = contextMod.New or function()
      return {
        Copy = function(self) return self end
      }
    end

    local bagFrame = addon:GetModule("BagFrame")
    bagFrame.Create = spy.new(function(_, ctx, kind)
      return {
        frame = CreateFrame("Frame"),
        GetName = function() return "MockBag_" .. tostring(kind) end,
        SetTitle = function() end,
      }
    end)

    -- Stub other global functions that init.lua touches
    _G.ContainerFrameCombinedBags = _G.ContainerFrameCombinedBags or CreateFrame("Frame")
    _G.BagsBar = _G.BagsBar or CreateFrame("Frame")
    _G.BankFrame = _G.BankFrame or CreateFrame("Frame")
    for i = 1, 13 do
      _G["ContainerFrame" .. i] = _G["ContainerFrame" .. i] or CreateFrame("Frame")
    end
    _G.MainMenuBarBackpackButton = _G.MainMenuBarBackpackButton or CreateFrame("Button")
    _G.CharacterBag0Slot = _G.CharacterBag0Slot or CreateFrame("Button")
    _G.CharacterBag1Slot = _G.CharacterBag1Slot or CreateFrame("Button")
    _G.CharacterBag2Slot = _G.CharacterBag2Slot or CreateFrame("Button")
    _G.CharacterBag3Slot = _G.CharacterBag3Slot or CreateFrame("Button")
    _G.KeyRingButton = _G.KeyRingButton or CreateFrame("Button")

    addon.HookScript = function() end
    addon.SecureHook = function() end

    -- The bag designs are made through the real BagSystem (core/bagsystem.lua, next.md §11), in
    -- scopes of the events module.
    eventsMod.NewScope = eventsMod.NewScope or function(_, name)
      return { name = name, Enable = function() end, Disable = function() end }
    end
    eventsMod.InScope = eventsMod.InScope or function(_, _, fn) fn() end
    _G.ResetModuleStub("BagSystem", "core/bagsystem.lua")
    assert(loadfile("core/bagsystem.lua"))("BetterBags")

    -- Reset core/init.lua load status
    _G.ResetModuleStub("BetterBags", "core/init.lua")
    local fn = assert(loadfile("core/init.lua"))
    fn("BetterBags")
  end)

  after_each(function()
    local db = addon:GetModule("Database")
    db.Init, db.GetNextEnabled = savedDatabase.Init, savedDatabase.GetNextEnabled
    addon.OnInitialize = oldOnInitialize
    addon.OnEnable = oldOnEnable
    addon.Bags = oldBags
    _G.UISpecialFrames = originalUISpecialFrames
    addon._bindingFrame = oldBindingFrame
    _G.C_CVar = oldCCVar

    -- Restore modules
    addon.modules = {}
    for k, v in pairs(oldModules) do
      addon.modules[k] = v
    end

    -- Restore registered sub-addons
    local aceAddon = LibStub("AceAddon-3.0")
    aceAddon.addons = {}
    for k, v in pairs(oldAddons) do
      aceAddon.addons[k] = v
    end
  end)

  it("starts the profiler right after Events, so a capture armed for this reload sees every other module initialize", function()
    local order = {}
    local perf = addon:GetModule("Perf")
    local perfSessions = addon:GetModule("PerfSessions")
    local eventsMod = addon:GetModule("Events")
    local db = addon:GetModule("Database")
    local simulatorMod = addon:GetModule("Simulator")
    local saved = {
      { perf, "Init", perf.Init },
      { perfSessions, "Init", perfSessions.Init },
      { perfSessions, "StartIfArmed", perfSessions.StartIfArmed },
      { simulatorMod, "Init", simulatorMod.Init },
      { eventsMod, "Init", eventsMod.Init },
      { db, "Init", db.Init },
    }
    simulatorMod.Init = function() table.insert(order, "Simulator") end
    eventsMod.Init = function() table.insert(order, "Events") end
    perf.Init = function() table.insert(order, "Perf") end
    perfSessions.Init = function() table.insert(order, "PerfSessions") end
    perfSessions.StartIfArmed = function() table.insert(order, "StartIfArmed") end
    db.Init = function() table.insert(order, "Database") end

    local ok, err = pcall(function() addon:OnInitialize() end)

    for _, s in ipairs(saved) do
      s[1][s[2]] = s[3]
    end
    assert.is_true(ok, err)
    assert.are.same({ "Events", "Perf", "PerfSessions", "StartIfArmed", "Simulator", "Database" }, order)
  end)

  -- core/boot.lua turns Ace's automatic module enabling off (SetDefaultModuleState(false)), so
  -- OnEnable enables each module whose OnEnable registers something. The changelog window
  -- registers its login check and changelog/Open there: not enabled, it never opens.
  it("enables the changelog window", function()
    local changelogWindow = addon:GetModule("ChangelogWindow")
    changelogWindow.Enable = spy.new(function() end)
    addon:OnInitialize()
    addon:OnEnable()
    assert.spy(changelogWindow.Enable).was.called(1)
  end)

  -- The guild bank's data source (data/guildbank.lua) follows the guild banker interaction from its
  -- OnEnable: initialized with the data models, enabled with the rest (guild-bank.md §2).
  it("initializes the guild bank with the data models and enables it", function()
    local guildBank = addon:GetModule("GuildBank")
    guildBank.Init = spy.new(function() end)
    guildBank.Enable = spy.new(function() end)
    addon:OnInitialize()
    assert.spy(guildBank.Init).was.called(1)
    addon:OnEnable()
    assert.spy(guildBank.Enable).was.called(1)
  end)

  it("finds the guild bank's panel by its kind and by a guild bank tab's container", function()
    addon:OnInitialize()
    local const = addon:GetModule("Constants")
    local saved = {}
    for _, key in ipairs({ "BAG_KIND", "GUILD_BANK_BAGS", "BACKPACK_BAGS", "BANK_BAGS", "ACCOUNT_BANK_BAGS" }) do
      saved[key] = const[key]
    end
    const.BAG_KIND = { BACKPACK = 0, BANK = 1, GUILD = 2 }
    const.GUILD_BANK_BAGS = { [1001] = 1 }
    const.BACKPACK_BAGS, const.BANK_BAGS, const.ACCOUNT_BANK_BAGS = { [0] = 0 }, { [6] = 6 }, {}
    local panel = {}
    addon.Bags.GuildBank = panel
    local byKind, byBag = addon:GetBagFromKind(2), addon:GetBagFromBagID(1001)
    for key, value in pairs(saved) do
      const[key] = value
    end
    assert.are.equal(panel, byKind)
    assert.are.equal(panel, byBag)
  end)

  -- Classic has no Warbank, so no const.ACCOUNT_BANK_BAGS (core/constants.lua), yet it has a guild
  -- bank (TBC Anniversary, Mists).
  it("finds the guild bank's panel by a container on Classic, which has no Warbank", function()
    addon:OnInitialize()
    local const = addon:GetModule("Constants")
    local saved = {}
    for _, key in ipairs({ "GUILD_BANK_BAGS", "BACKPACK_BAGS", "BANK_BAGS", "ACCOUNT_BANK_BAGS" }) do
      saved[key] = const[key]
    end
    const.GUILD_BANK_BAGS = { [1001] = 1 }
    const.BACKPACK_BAGS, const.BANK_BAGS, const.ACCOUNT_BANK_BAGS = { [0] = 0 }, { [-1] = -1 }, nil
    local panel = {}
    addon.Bags.GuildBank = panel
    local ok, byBag = pcall(function() return addon:GetBagFromBagID(1001) end)
    local okUnknown, unknown = pcall(function() return addon:GetBagFromBagID(55) end)
    for key, value in pairs(saved) do
      const[key] = value
    end
    assert.is_true(ok, tostring(byBag))
    assert.are.equal(panel, byBag)
    assert.is_true(okUnknown, tostring(unknown))
    assert.is_nil(unknown)
  end)

  -- BetterBagsNext (next.md §1): with it on, the backpack is a NextBag; with the bank off, the
  -- classic frame is made for neither bag.
  it("makes the backpack a BetterBags Next panel when it is on", function()
    local bagFrame = addon:GetModule("BagFrame")
    local nextBag = addon:GetModule("NextBag")
    local db = addon:GetModule("Database")
    local savedGet, savedCreate, savedBank = db.GetNextEnabled, nextBag.Create, db.GetEnableBankBag
    local panel = { frame = CreateFrame("Frame"), GetName = function() return "BetterBagsNextBackpack" end,
      SetTitle = function() end }
    db.GetNextEnabled = function() return true end
    db.GetEnableBankBag = function() return false end
    nextBag.Create = spy.new(function() return panel end)
    local ok, err = pcall(function() addon:OnInitialize() end)
    db.GetNextEnabled, nextBag.Create, db.GetEnableBankBag = savedGet, savedCreate, savedBank
    assert.is_true(ok, err)
    assert.are.equal(panel, addon.Bags.Backpack)
    assert.is_nil(addon.Bags.Bank)
    assert.spy(bagFrame.Create).was_not.called()
  end)

  -- BetterBags Next covers the bank too (next.md §6): with it on, the bank is a NextBank and the
  -- classic frame is made for neither bag.
  it("makes the bank a BetterBags Next panel when it is on", function()
    local bagFrame = addon:GetModule("BagFrame")
    local nextBag = addon:GetModule("NextBag")
    local nextBankMod = addon:GetModule("NextBank")
    local db = addon:GetModule("Database")
    local savedGet, savedBag, savedBank = db.GetNextEnabled, nextBag.Create, nextBankMod.Create
    local function panel(name)
      return { frame = CreateFrame("Frame"), GetName = function() return name end, SetTitle = function() end }
    end
    local backpack, bank = panel("BetterBagsNextBackpack"), panel("BetterBagsNextBank")
    db.GetNextEnabled = function() return true end
    nextBag.Create = function() return backpack end
    nextBankMod.Create = spy.new(function() return bank end)
    local ok, err = pcall(function() addon:OnInitialize() end)
    local made = nextBankMod.Create
    db.GetNextEnabled, nextBag.Create, nextBankMod.Create = savedGet, savedBag, savedBank
    assert.is_true(ok, err)
    assert.are.equal(bank, addon.Bags.Bank)
    assert.spy(made).was.called(1)
    assert.spy(bagFrame.Create).was_not.called()
    local special = {}
    for _, name in ipairs(UISpecialFrames) do special[name] = true end
    assert.is_true(special["BetterBagsNextBank"], "Escape closes it")
  end)

  -- BetterBags Next's vendor (next.md §10): with it on, the vendor is made, takes Blizzard's merchant
  -- frame under the hidden frame Blizzard's bags go under, and closes with Escape; with it off,
  -- nothing is made and the merchant frame is Blizzard's.
  describe("the vendor", function()
    local function panel(name)
      return { frame = CreateFrame("Frame"), GetName = function() return name end, SetTitle = function() end }
    end

    local function initialize(nextOn)
      local db = addon:GetModule("Database")
      local nextBag = addon:GetModule("NextBag")
      local nextBankMod = addon:GetModule("NextBank")
      local nextVendor = addon:GetModule("NextVendor")
      local saved = { db.GetNextEnabled, nextBag.Create, nextBankMod.Create, nextVendor.Create, nextVendor.TakeOver }
      local vendor = panel("BetterBagsNextVendor")
      local took
      db.GetNextEnabled = function() return nextOn end
      nextBag.Create = function() return panel("BetterBagsNextBackpack") end
      nextBankMod.Create = function() return panel("BetterBagsNextBank") end
      nextVendor.Create = spy.new(function() return vendor end)
      nextVendor.TakeOver = function(_, hidden) took = hidden end
      addon.Vendor = nil
      local ok, err = pcall(function() addon:OnInitialize() end)
      local made = nextVendor.Create
      db.GetNextEnabled, nextBag.Create, nextBankMod.Create, nextVendor.Create, nextVendor.TakeOver = unpack(saved)
      assert.is_true(ok, err)
      return vendor, made, took
    end

    it("is made with BetterBags Next, under the hidden frame, closing with Escape", function()
      local vendor, made, took = initialize(true)
      assert.spy(made).was.called(1)
      assert.are.equal(vendor, addon.Vendor)
      assert.are.equal(_G.BetterBagsSneakyFrame, took)
      assert.is_false(took:IsShown())
      local special = {}
      for _, name in ipairs(UISpecialFrames) do special[name] = true end
      assert.is_true(special["BetterBagsNextVendor"])
    end)

    it("is not made without it, leaving Blizzard's merchant frame alone", function()
      local _, made, took = initialize(false)
      assert.spy(made).was_not.called()
      assert.is_nil(addon.Vendor)
      assert.is_nil(took)
    end)
  end)

  it("should create UI frames during OnInitialize and NOT during OnEnable", function()
    local bagFrame = addon:GetModule("BagFrame")

    -- Call OnInitialize
    addon:OnInitialize()

    -- BagFrame.Create should be called twice (for Backpack and Bank)
    assert.spy(bagFrame.Create).was.called(2)

    -- Reset the spy to see if OnEnable calls it again (it shouldn't)
    bagFrame.Create:clear()

    addon:OnEnable()
    assert.spy(bagFrame.Create).was_not.called()
  end)

  -- Regression: issue #1076. AceAddon runs OnInitialize inside a safecall
  -- (xpcall), so if any frame/theme creation throws partway through, the addon
  -- still proceeds to OnEnable and hooks ToggleAllBags. The button/highlight
  -- setup must therefore be established BEFORE any fallible frame/theme/bank
  -- creation, or every subsequent bag toggle crashes in UpdateButtonHighlight
  -- with "bad argument #1 to 'pairs' (table expected, got nil)".
  it("populates addon._buttons even if a later OnInitialize step throws", function()
    local bagFrame = addon:GetModule("BagFrame")
    addon._buttons = nil

    -- Simulate a client-specific failure after the Backpack frame is created:
    -- the Bank frame creation throws (e.g. a theme/bank API not ready yet).
    bagFrame.Create = spy.new(function(_, _, kind)
      local const = addon:GetModule("Constants")
      if kind == const.BAG_KIND.BANK then
        error("simulated bank creation failure")
      end
      return {
        frame = CreateFrame("Frame"),
        GetName = function() return "MockBag_" .. tostring(kind) end,
        SetTitle = function() end,
        IsShown = function() return false end,
      }
    end)

    -- Mimic AceAddon's safecall: a throw is swallowed, execution continues.
    local ok = pcall(function() addon:OnInitialize() end)
    assert.is_false(ok)

    assert.is_table(addon._buttons)
    assert.is_true(#addon._buttons > 0)
  end)

  it("UpdateButtonHighlight does not error after a partial OnInitialize", function()
    local bagFrame = addon:GetModule("BagFrame")
    addon._buttons = nil

    -- Give the bag-slot button globals the highlight texture the real frames
    -- have, so the only possible failure is pairs(nil) on addon._buttons.
    local function withHighlight(button)
      button.SlotHighlightTexture = { SetShown = function() end }
      return button
    end
    withHighlight(_G.MainMenuBarBackpackButton)
    withHighlight(_G.CharacterBag0Slot)
    withHighlight(_G.CharacterBag1Slot)
    withHighlight(_G.CharacterBag2Slot)
    withHighlight(_G.CharacterBag3Slot)
    withHighlight(_G.KeyRingButton)

    bagFrame.Create = spy.new(function(_, _, kind)
      local const = addon:GetModule("Constants")
      if kind == const.BAG_KIND.BANK then
        error("simulated bank creation failure")
      end
      return {
        frame = CreateFrame("Frame"),
        GetName = function() return "MockBag_" .. tostring(kind) end,
        SetTitle = function() end,
        IsShown = function() return false end,
      }
    end)

    pcall(function() addon:OnInitialize() end)

    assert.has_no.errors(function() addon:UpdateButtonHighlight() end)
  end)

  -- A capture of opening the bank drew it twice in one frame: showing it drew what was
  -- deferred while hidden (176 ms raw), then the refresh handler drew the same data again
  -- (every button skipped; 19 ms with profiler overhead subtracted).
  describe("bank refresh draw", function()
    local handlers, sent, drawn, savedRegister, savedSend

    before_each(function()
      handlers, sent, drawn = {}, {}, 0
      local eventsMod = addon:GetModule("Events")
      savedRegister, savedSend = eventsMod.RegisterMessage, eventsMod.SendMessage
      eventsMod.RegisterMessage = function(_, name, fn) handlers[name] = fn end
      eventsMod.SendMessage = function(_, _, name) table.insert(sent, name) end
      local debugMod = addon:GetModule("Debug")
      debugMod.Log = debugMod.Log or function() end
      addon:OnInitialize()
      addon:OnEnable()
    end)

    after_each(function()
      local eventsMod = addon:GetModule("Events")
      eventsMod.RegisterMessage, eventsMod.SendMessage = savedRegister, savedSend
      addon.atBank = nil
    end)

    local function bank(shown, drawsOnShow)
      addon.Bags.Bank = {
        IsShown = function() return shown end,
        Show = function() shown = true; return drawsOnShow end,
        Draw = function(_, _, _, cb) drawn = drawn + 1; if cb then cb() end end,
      }
    end

    -- The guild bank's panel (BetterBags Next) is made with the design, maybe after OnEnable (a
    -- switch), so the handler looks for it at each read (guild-bank.md §5).
    it("draws the guild bank's panel after each guild bank read, when there is one", function()
      local slotInfo = {}
      handlers["items/RefreshGuildBank/Done"]({}, slotInfo)
      assert.same({}, sent)
      local drewWith
      addon.Bags.GuildBank = { Draw = function(_, _, info, cb) drewWith = info; cb() end }
      handlers["items/RefreshGuildBank/Done"]({}, slotInfo)
      assert.are.equal(slotInfo, drewWith)
      assert.same({ "bags/Draw/GuildBank/Done" }, sent)
      addon.Bags.GuildBank = nil
    end)

    it("draws the bank once when showing it drew it", function()
      addon.atBank = true
      bank(false, true)
      handlers["items/RefreshBank/Done"]({}, {})
      assert.equal(0, drawn)
      assert.same({ "bags/Draw/Bank/Done", "bags/Draw/Bank/Loaded" }, sent)
    end)

    it("draws the bank when showing it did not", function()
      addon.atBank = true
      bank(false, false)
      handlers["items/RefreshBank/Done"]({}, {})
      assert.equal(1, drawn)
    end)

    it("draws a bank that was already shown", function()
      addon.atBank = true
      bank(true, false)
      handlers["items/RefreshBank/Done"]({}, {})
      assert.equal(1, drawn)
    end)
  end)
end)
