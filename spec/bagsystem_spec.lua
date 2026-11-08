-- bagsystem_spec.lua -- BagSystem (core/bagsystem.lua): BetterBags' two bag designs, the classic
-- bags and BetterBags Next, made and switched between without a reload (next.md §11). Each design
-- is made once, in an event scope of its own; switching hides the shown design, lets go of its
-- buttons and unhooks everything it registered, then makes or switches on the other, which catches
-- up and draws what was read.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
local BACKPACK, BANK = const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK

local stubs = {
  L = trackStub("Localization"),
  database = trackStub("Database"),
  items = trackStub("Items"),
  bagFrame = trackStub("BagFrame"),
  nextBag = trackStub("NextBag"),
  nextBank = trackStub("NextBank"),
  nextVendor = trackStub("NextVendor"),
  nextGuildBank = trackStub("NextGuildBank"),
  consoleport = trackStub("ConsolePort"),
}

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

ResetModuleStub("Events", "core/events.lua")
LoadBetterBagsModule("core/events.lua")
ResetModuleStub("BagSystem", "core/bagsystem.lua")
LoadBetterBagsModule("core/bagsystem.lua")

local bagSystem = addon:GetModule("BagSystem")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")

describe("BagSystem", function()
  local made, fired, nextOn, bankOn, vendorOn, guildOn, calls, slotInfo, sent

  local function ctx() return context:New("spec") end

  -- fakeBag is a design's bag: it registers a WoW event and a bucket while it is made, as the real
  -- ones do, and logs what is asked of it.
  local function fakeBag(design, kind)
    local name = "BagSystemSpec" .. design .. kind
    local b = { design = design, kind = kind, frame = CreateFrame("Frame", name), log = {}, loaded = false }
    b.frame:Hide()
    b.searchBox = { textBox = CreateFrame("EditBox") }
    function b:GetName() return name end
    function b:IsShown() return self.frame:IsShown() end
    function b:IsClosing() return self.closingNow == true end
    function b:Show(_) table.insert(self.log, "show") self.frame:Show() return true end
    function b:Draw(_, data, callback)
      table.insert(self.log, { "draw", data })
      if callback then callback() end
    end
    function b:Deactivate(_) table.insert(self.log, "deactivate") self.frame:Hide() end
    function b:Activate(_) table.insert(self.log, "activate") end
    function b:SetTitle(text) self.title = text end
    events:RegisterEvent("BAGSYSTEM_SPEC_EVENT", function() table.insert(fired, design .. " " .. kind) end)
    events:RegisterMessage("bagsystem/SpecMessage", function() table.insert(fired, design .. " message " .. kind) end)
    table.insert(made, b)
    return b
  end

  local function fire()
    fired = {}
    local entry = events._eventMap["BAGSYSTEM_SPEC_EVENT"]
    if entry then entry.fn("BAGSYSTEM_SPEC_EVENT") end
    events:SendMessage(ctx(), "bagsystem/SpecMessage")
    table.sort(fired)
    return fired
  end

  -- start makes the saved design as core/init.lua does.
  local function start()
    local c = ctx()
    local design = bagSystem:SavedDesign()
    addon.Bags.Backpack = bagSystem:CreateBackpack(c, design)
    bagSystem:CreateRest(c, design)
    bagSystem:Use(design)
    bagSystem:Finish(design)
    return design
  end

  before_each(function()
    events:Init()
    bagSystem:Init()
    made, fired, calls, sent = {}, {}, { takeOver = {}, giveBack = 0, consoleport = {}, watched = {},
      guildTakeOver = {}, guildGiveBack = 0 }, {}
    nextOn, bankOn, vendorOn, guildOn = false, true, true, true
    slotInfo = { [BACKPACK] = { "backpack data" }, [BANK] = { "bank data" } }
    override(addon, "Bags", {})
    override(addon, "Vendor", nil)
    override(addon, "atBank", false)
    override(addon, "atGuildBank", false)
    override(addon, "hasGuildBank", true)
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.database, "GetNextEnabled", function() return nextOn end)
    override(stubs.database, "SetNextEnabled", function(_, on) nextOn = on end)
    override(stubs.database, "GetEnableBankBag", function() return bankOn end)
    override(stubs.database, "GetNextVendorEnabled", function() return vendorOn end)
    override(stubs.database, "SetNextVendorEnabled", function(_, on) vendorOn = on end)
    override(stubs.database, "GetNextGuildBankEnabled", function() return guildOn end)
    override(stubs.database, "SetNextGuildBankEnabled", function(_, on) guildOn = on end)
    override(stubs.database, "GetBagView", function() return 2 end)
    override(stubs.database, "GetSectionSortType", function() return nextOn and 2 or 1 end)
    override(stubs.items, "GetAllSlotInfo", function() return slotInfo end)
    override(stubs.bagFrame, "Create", spy.new(function(_, _, kind) return fakeBag("classic", kind) end))
    override(stubs.nextBag, "Create", spy.new(function() return fakeBag("next", BACKPACK) end))
    override(stubs.nextBank, "Create", spy.new(function() return fakeBag("next", BANK) end))
    override(stubs.nextVendor, "Create", spy.new(function()
      local v = fakeBag("next", "vendor")
      v.atMerchant = false
      return v
    end))
    override(stubs.nextGuildBank, "Create", spy.new(function() return fakeBag("next", "guild") end))
    override(stubs.nextGuildBank, "TakeOver", function(_, hidden) table.insert(calls.guildTakeOver, hidden) end)
    override(stubs.nextGuildBank, "GiveBack", function() calls.guildGiveBack = calls.guildGiveBack + 1 end)
    override(stubs.nextVendor, "TakeOver", function(_, hidden) table.insert(calls.takeOver, hidden) end)
    override(stubs.nextVendor, "GiveBack", function() calls.giveBack = calls.giveBack + 1 end)
    override(stubs.consoleport, "Add", function(_, frame) table.insert(calls.consoleport, frame) end)
    override(addon, "WatchBackpackFrame", function(_, frame) table.insert(calls.watched, frame) end)
    override(addon, "UpdateButtonHighlight", function() calls.highlight = (calls.highlight or 0) + 1 end)
    override(_G, "InCombatLockdown", function() return false end)
    calls.nextActive = {}
    override(addon:GetModule("SonataNext"), "SetActive", function(_, active) table.insert(calls.nextActive, active) end)
    override(_G, "UISpecialFrames", {})
    override(_G, "BetterBagsSneakyFrame", CreateFrame("Frame"))
    override(_G, "MerchantFrame", CreateFrame("Frame"))
    MerchantFrame:Hide()
    UIErrorsFrame._messages = {}
    events:RegisterMessage("bags/DesignChanged", function(_, design) table.insert(sent, design) end)
  end)

  after_each(function()
    restore()
    UIErrorsFrame._messages = {}
  end)

  teardown(function()
    ResetModuleStub("BagSystem")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function special()
    local out = {}
    for _, name in ipairs(UISpecialFrames) do out[name] = true end
    return out
  end

  describe("making the saved design", function()
    it("makes the classic bags, their registrations hooked", function()
      assert.are.equal("classic", start())
      assert.are.equal("classic", bagSystem:ActiveDesign())
      assert.are.equal(made[1], addon.Bags.Backpack)
      assert.are.equal(made[2], addon.Bags.Bank)
      assert.is_nil(addon.Vendor)
      assert.are.same({}, calls.takeOver)
      assert.are.same({ "classic 0", "classic 1", "classic message 0", "classic message 1" }, fire())
      assert.are.equal("Backpack", addon.Bags.Backpack.title)
      assert.is_true(special()["BagSystemSpecclassic0"])
      assert.is_true(special()["BagSystemSpecclassic1"])
    end)

    it("makes BetterBags Next with its vendor, which takes over Blizzard's merchant frame", function()
      nextOn = true
      assert.are.equal("next", start())
      assert.are.equal("next", addon.Bags.Backpack.design)
      assert.are.equal("vendor", addon.Vendor.kind)
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.takeOver)
      assert.is_true(special()["BagSystemSpecnextvendor"])
      assert.spy(stubs.bagFrame.Create).was_not.called()
    end)

    -- BetterBags Next's guild bank (guild-bank.md §5) stands in for Blizzard's guild bank frame; the
    -- classic bags leave Blizzard's frame to show the guild bank.
    it("makes BetterBags Next's guild bank, which takes over Blizzard's guild bank frame", function()
      nextOn = true
      start()
      assert.are.equal("guild", addon.Bags.GuildBank.kind)
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.guildTakeOver)
      assert.is_true(special()["BagSystemSpecnextguild"])
    end)

    it("makes no guild bank for the classic bags, nor on a client without one (Classic Era)", function()
      start()
      assert.is_nil(addon.Bags.GuildBank)
      assert.spy(stubs.nextGuildBank.Create).was_not.called()
      bagSystem:Init()
      override(addon, "hasGuildBank", false)
      nextOn = true
      start()
      assert.is_nil(addon.Bags.GuildBank)
      assert.spy(stubs.nextGuildBank.Create).was_not.called()
      assert.are.same({}, calls.guildTakeOver)
    end)

    it("makes no bank without bank bags", function()
      bankOn = false
      start()
      assert.is_nil(addon.Bags.Bank)
      assert.spy(stubs.bagFrame.Create).was.called(1)
    end)
  end)

  describe("switching", function()
    it("switches the shown design off: hidden, its buttons let go of, everything it registered unhooked", function()
      start()
      local old = addon.Bags.Backpack
      assert.is_true(bagSystem:Switch(ctx(), "next"))
      assert.are.same({ "deactivate" }, old.log)
      assert.are.same({ "deactivate" }, made[2].log)
      assert.are.same({ "next 0", "next 1", "next guild", "next message 0", "next message 1", "next message guild",
        "next message vendor", "next vendor" }, fire())
    end)

    -- Each design has its own Section Order, and what the bags last read was sorted by the other's.
    it("recalculates the backpack when the design in use sorts its sections another way", function()
      start()
      local asked = {}
      events:RegisterMessage("bags/Rederive", function(_, opts) table.insert(asked, opts) end)
      bagSystem:Switch(ctx(), "next")
      assert.are.same({ { backpack = true, bank = false, categoriesUnchanged = true } }, asked)
    end)

    it("recalculates nothing when both designs sort their sections the same way", function()
      override(stubs.database, "GetSectionSortType", function() return 2 end)
      start()
      local asked = {}
      events:RegisterMessage("bags/Rederive", function(_, opts) table.insert(asked, opts) end)
      bagSystem:Switch(ctx(), "next")
      assert.are.same({}, asked)
    end)

    it("makes the other design once, uses it, saves the setting and says so", function()
      start()
      bagSystem:Switch(ctx(), "next")
      assert.are.equal("next", bagSystem:ActiveDesign())
      assert.are.equal("next", addon.Bags.Backpack.design)
      assert.are.equal("next", addon.Bags.Bank.design)
      assert.are.equal("vendor", addon.Vendor.kind)
      assert.is_true(nextOn)
      assert.are.same({ "next" }, sent)
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.takeOver)
      assert.are.equal("Backpack", addon.Bags.Backpack.title)
      local names = special()
      assert.is_true(names["BagSystemSpecnext0"] and names["BagSystemSpecnext1"] and names["BagSystemSpecnextvendor"])
      assert.are.same({ addon.Bags.Backpack.frame }, calls.watched)
      assert.are.same({ addon.Bags.Backpack.frame, addon.Bags.Bank.frame, addon.Bags.GuildBank.frame }, calls.consoleport)
    end)

    -- A Next theme styles the item buttons only while BetterBags Next is in use (next-themes.md).
    it("tells the Next theme engine which design is in use", function()
      start()
      assert.are.same({ false }, calls.nextActive)
      bagSystem:Switch(ctx(), "next")
      assert.are.same({ false, true }, calls.nextActive)
      bagSystem:Switch(ctx(), "classic")
      assert.are.same({ false, true, false }, calls.nextActive)
    end)

    it("draws the new backpack with what was read, and opens it only when the old one was open", function()
      start()
      bagSystem:Switch(ctx(), "next")
      assert.are.same({ { "draw", slotInfo[BACKPACK] } }, addon.Bags.Backpack.log)
      bagSystem:Switch(ctx(), "classic")
      addon.Bags.Backpack.frame:Show()
      bagSystem:Switch(ctx(), "next")
      assert.are.same({ { "draw", slotInfo[BACKPACK] }, "deactivate", "activate", { "draw", slotInfo[BACKPACK] },
        "show" }, addon.Bags.Backpack.log)
      assert.is_true(calls.highlight > 0)
    end)

    -- A backpack sliding or fading out was closed: the new one stays closed.
    it("does not open the new backpack when the old one was closing", function()
      start()
      addon.Bags.Backpack.frame:Show()
      addon.Bags.Backpack.closingNow = true
      bagSystem:Switch(ctx(), "next")
      assert.are.same({ { "draw", slotInfo[BACKPACK] } }, addon.Bags.Backpack.log)
    end)

    it("switches back without making anything again, the old design's registrations hooked again", function()
      start()
      local classic = addon.Bags.Backpack
      bagSystem:Switch(ctx(), "next")
      bagSystem:Switch(ctx(), "classic")
      assert.are.equal(classic, addon.Bags.Backpack)
      assert.is_nil(addon.Vendor)
      assert.are.equal(1, calls.giveBack)
      assert.is_false(nextOn)
      assert.spy(stubs.bagFrame.Create).was.called(2)
      assert.spy(stubs.nextBag.Create).was.called(1)
      assert.are.same({ "deactivate", "activate", { "draw", slotInfo[BACKPACK] } }, classic.log)
      assert.are.same({ "classic 0", "classic 1", "classic message 0", "classic message 1" }, fire())
      assert.are.equal(2, #UISpecialFrames - 4, "the classic frames listed once")
      bagSystem:Switch(ctx(), "next")
      assert.are.same({ _G.BetterBagsSneakyFrame, _G.BetterBagsSneakyFrame }, calls.takeOver,
        "the merchant frame taken again")
    end)

    it("carries the loaded flag and the search over", function()
      start()
      addon.Bags.Backpack.loaded = true
      addon.Bags.Backpack.searchBox.textBox:SetText("ore")
      addon.Bags.Bank.searchBox.textBox:SetText("gems")
      bagSystem:Switch(ctx(), "next")
      assert.is_true(addon.Bags.Backpack.loaded)
      assert.are.equal("ore", addon.Bags.Backpack.searchBox.textBox:GetText())
      assert.are.equal("gems", addon.Bags.Bank.searchBox.textBox:GetText())
      addon.Bags.Backpack.searchBox.textBox:SetText("")
      bagSystem:Switch(ctx(), "classic")
      assert.are.equal("", addon.Bags.Backpack.searchBox.textBox:GetText(), "no stale search comes back")
    end)

    it("does nothing for the design already in use", function()
      start()
      assert.is_true(bagSystem:Switch(ctx(), "classic"))
      assert.are.same({}, made[1].log)
      assert.are.same({}, sent)
    end)

    local function refused(message)
      assert.are.equal("classic", bagSystem:ActiveDesign())
      assert.are.equal("classic", addon.Bags.Backpack.design)
      assert.is_false(nextOn)
      assert.are.same({}, made[1].log)
      assert.are.equal(message, UIErrorsFrame._messages[#UIErrorsFrame._messages].text)
    end

    it("refuses in combat", function()
      start()
      override(_G, "InCombatLockdown", function() return true end)
      assert.is_false(bagSystem:Switch(ctx(), "next"))
      refused("You can't switch bags in combat.")
    end)

    it("refuses at the bank", function()
      start()
      override(addon, "atBank", true)
      assert.is_false(bagSystem:Switch(ctx(), "next"))
      refused("Close the bank to switch bags.")
    end)

    it("refuses at the guild bank", function()
      start()
      override(addon, "atGuildBank", true)
      assert.is_false(bagSystem:Switch(ctx(), "next"))
      refused("Close the guild bank to switch bags.")
    end)

    it("switches the guild bank off with BetterBags Next, giving Blizzard's frame back, and on again", function()
      nextOn = true
      start()
      local guild = addon.Bags.GuildBank
      assert.is_true(bagSystem:Switch(ctx(), "classic"))
      assert.are.same({ "deactivate" }, guild.log)
      assert.are.equal(1, calls.guildGiveBack)
      assert.is_nil(addon.Bags.GuildBank)
      assert.is_true(bagSystem:Switch(ctx(), "next"))
      assert.are.equal(guild, addon.Bags.GuildBank)
      assert.are.same({ "deactivate", "activate" }, guild.log)
      assert.are.equal(2, #calls.guildTakeOver)
    end)

    it("makes the guild bank the first time BetterBags Next is switched to, for the cursor too", function()
      start()
      assert.is_true(bagSystem:Switch(ctx(), "next"))
      assert.are.equal("guild", addon.Bags.GuildBank.kind)
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.guildTakeOver)
      local added = false
      for _, frame in ipairs(calls.consoleport) do
        if frame == addon.Bags.GuildBank.frame then added = true end
      end
      assert.is_true(added)
    end)

    it("refuses at a vendor, Blizzard's or BetterBags Next's", function()
      start()
      MerchantFrame:Show()
      assert.is_false(bagSystem:Switch(ctx(), "next"))
      refused("Close the vendor to switch bags.")
      MerchantFrame:Hide()
      nextOn = true
      bagSystem:Init()
      start()
      addon.Vendor.atMerchant = true
      assert.is_false(bagSystem:Switch(ctx(), "classic"))
      assert.are.equal("next", bagSystem:ActiveDesign())
    end)
  end)

  -- Enable Vendor Window and Enable Guild Bank Window (#1262): BetterBags Next's vendor and guild bank, each
  -- switched off and on at once; while one is off, Blizzard's own frame shows the vendor or the guild bank.
  describe("the vendor and guild bank windows", function()
    local function listed(name)
      local n = 0
      for _, frame in ipairs(UISpecialFrames) do
        if frame == name then n = n + 1 end
      end
      return n
    end

    local function lastError()
      return UIErrorsFrame._messages[#UIErrorsFrame._messages].text
    end

    it("makes neither while they are off, leaving Blizzard's frames to show them", function()
      nextOn, vendorOn, guildOn = true, false, false
      start()
      assert.is_nil(addon.Vendor)
      assert.is_nil(addon.Bags.GuildBank)
      assert.spy(stubs.nextVendor.Create).was_not.called()
      assert.spy(stubs.nextGuildBank.Create).was_not.called()
      assert.are.same({}, calls.takeOver)
      assert.are.same({}, calls.guildTakeOver)
      assert.are.same({ "next 0", "next 1", "next message 0", "next message 1" }, fire())
    end)

    it("switches the vendor off at once: hidden, its buttons let go of, Blizzard's merchant frame given back", function()
      nextOn = true
      start()
      local vendor = addon.Vendor
      assert.is_true(bagSystem:SetVendorEnabled(ctx(), false))
      assert.is_false(vendorOn)
      assert.are.same({ "deactivate" }, vendor.log)
      assert.are.equal(1, calls.giveBack)
      assert.is_nil(addon.Vendor)
      assert.are.equal(0, calls.guildGiveBack, "the guild bank keeps Blizzard's guild bank frame")
      assert.are.same({}, addon.Bags.GuildBank.log)
      assert.are.equal("next", bagSystem:ActiveDesign())
    end)

    it("switches the vendor back on: the same one, caught up, taking Blizzard's merchant frame again", function()
      nextOn = true
      start()
      local vendor = addon.Vendor
      bagSystem:SetVendorEnabled(ctx(), false)
      assert.is_true(bagSystem:SetVendorEnabled(ctx(), true))
      assert.is_true(vendorOn)
      assert.are.equal(vendor, addon.Vendor)
      assert.are.same({ "deactivate", "activate" }, vendor.log)
      assert.are.same({ _G.BetterBagsSneakyFrame, _G.BetterBagsSneakyFrame }, calls.takeOver)
      assert.spy(stubs.nextVendor.Create).was.called(1)
      assert.are.equal(1, listed("BagSystemSpecnextvendor"), "Escape closes it, listed once")
    end)

    it("makes the vendor the first time it is switched on, in BetterBags Next's scope, Escape closing it", function()
      nextOn, vendorOn = true, false
      start()
      assert.is_true(bagSystem:SetVendorEnabled(ctx(), true))
      assert.are.equal("vendor", addon.Vendor.kind)
      assert.are.same({}, addon.Vendor.log, "nothing to catch up on")
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.takeOver)
      assert.are.equal(1, listed("BagSystemSpecnextvendor"))
      assert.are.same({ "next 0", "next 1", "next guild", "next message 0", "next message 1", "next message guild",
        "next message vendor", "next vendor" }, fire())
      bagSystem:Switch(ctx(), "classic")
      assert.are.same({ "classic 0", "classic 1", "classic message 0", "classic message 1" }, fire(),
        "unhooked with BetterBags Next")
    end)

    it("switches the guild bank off and on at once, made the first time it is on, for the cursor too", function()
      nextOn, guildOn = true, false
      start()
      assert.is_nil(addon.Bags.GuildBank)
      assert.is_true(bagSystem:SetGuildBankEnabled(ctx(), true))
      local guild = addon.Bags.GuildBank
      assert.are.equal("guild", guild.kind)
      assert.is_true(guildOn)
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.guildTakeOver)
      assert.are.equal(1, listed("BagSystemSpecnextguild"))
      assert.are.same({ guild.frame }, calls.consoleport)
      assert.is_true(bagSystem:SetGuildBankEnabled(ctx(), false))
      assert.is_false(guildOn)
      assert.is_nil(addon.Bags.GuildBank)
      assert.are.same({ "deactivate" }, guild.log)
      assert.are.equal(1, calls.guildGiveBack)
      assert.are.equal(0, calls.giveBack, "the vendor keeps Blizzard's merchant frame")
      assert.is_true(bagSystem:SetGuildBankEnabled(ctx(), true))
      assert.are.equal(guild, addon.Bags.GuildBank)
      assert.are.same({ "deactivate", "activate" }, guild.log)
      assert.are.equal(2, #calls.guildTakeOver)
      assert.spy(stubs.nextGuildBank.Create).was.called(1)
      assert.are.same({ guild.frame }, calls.consoleport, "added once")
      assert.are.equal(1, listed("BagSystemSpecnextguild"), "listed once")
    end)

    it("refuses at a vendor, Blizzard's or BetterBags Next's, saying so", function()
      nextOn = true
      start()
      local vendor = addon.Vendor
      vendor.atMerchant = true
      assert.is_false(bagSystem:SetVendorEnabled(ctx(), false))
      assert.is_true(vendorOn)
      assert.are.equal(vendor, addon.Vendor)
      assert.are.same({}, vendor.log)
      assert.are.equal(0, calls.giveBack)
      assert.are.equal("Close the vendor to switch vendor windows.", lastError())
      vendor.atMerchant = false
      bagSystem:SetVendorEnabled(ctx(), false)
      MerchantFrame:Show()
      assert.is_false(bagSystem:SetVendorEnabled(ctx(), true))
      assert.is_false(vendorOn)
      assert.is_nil(addon.Vendor)
      assert.are.equal(1, #calls.takeOver)
    end)

    it("refuses at the guild bank, saying so", function()
      nextOn = true
      start()
      local guild = addon.Bags.GuildBank
      override(addon, "atGuildBank", true)
      assert.is_false(bagSystem:SetGuildBankEnabled(ctx(), false))
      assert.is_true(guildOn)
      assert.are.equal(guild, addon.Bags.GuildBank)
      assert.are.same({}, guild.log)
      assert.are.equal(0, calls.guildGiveBack)
      assert.are.equal("Close the guild bank to switch guild bank windows.", lastError())
    end)

    it("only saves the choice while the classic bags are in use, BetterBags Next following it when switched to", function()
      start()
      assert.is_true(bagSystem:SetVendorEnabled(ctx(), false))
      assert.is_true(bagSystem:SetGuildBankEnabled(ctx(), false))
      assert.is_false(vendorOn)
      assert.is_false(guildOn)
      assert.are.equal(0, calls.giveBack)
      assert.are.equal(0, calls.guildGiveBack)
      assert.is_true(bagSystem:Switch(ctx(), "next"))
      assert.is_nil(addon.Vendor)
      assert.is_nil(addon.Bags.GuildBank)
      assert.spy(stubs.nextVendor.Create).was_not.called()
      assert.spy(stubs.nextGuildBank.Create).was_not.called()
      assert.are.same({}, calls.takeOver)
      assert.are.same({}, calls.guildTakeOver)
      assert.are.same({ addon.Bags.Backpack.frame, addon.Bags.Bank.frame }, calls.consoleport)
    end)

    it("leaves a vendor and guild bank switched off as they are when the bags switch", function()
      nextOn = true
      start()
      local vendor, guild = addon.Vendor, addon.Bags.GuildBank
      bagSystem:SetVendorEnabled(ctx(), false)
      bagSystem:SetGuildBankEnabled(ctx(), false)
      assert.is_true(bagSystem:Switch(ctx(), "classic"))
      assert.are.equal(1, calls.giveBack, "given back once, when switched off")
      assert.are.equal(1, calls.guildGiveBack)
      assert.is_true(bagSystem:Switch(ctx(), "next"))
      assert.is_nil(addon.Vendor)
      assert.is_nil(addon.Bags.GuildBank)
      assert.are.same({ "deactivate" }, vendor.log, "not caught up while off")
      assert.are.same({ "deactivate" }, guild.log)
      assert.are.equal(1, #calls.takeOver)
      assert.are.equal(1, #calls.guildTakeOver)
      assert.is_true(bagSystem:SetVendorEnabled(ctx(), true))
      assert.are.equal(vendor, addon.Vendor)
      assert.are.same({ "deactivate", "activate" }, vendor.log)
    end)

    it("makes a vendor switched on while the classic bags were in use once BetterBags Next is back", function()
      nextOn, vendorOn = true, false
      start()
      bagSystem:Switch(ctx(), "classic")
      bagSystem:SetVendorEnabled(ctx(), true)
      bagSystem:Switch(ctx(), "next")
      assert.are.equal("vendor", addon.Vendor.kind)
      assert.are.same({}, addon.Vendor.log, "made, nothing to catch up on")
      assert.are.same({ _G.BetterBagsSneakyFrame }, calls.takeOver)
      assert.are.equal(1, listed("BagSystemSpecnextvendor"))
    end)
  end)
end)
