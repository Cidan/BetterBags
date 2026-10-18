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
  local made, fired, nextOn, bankOn, calls, slotInfo, sent

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
    made, fired, calls, sent = {}, {}, { takeOver = {}, giveBack = 0, consoleport = {}, watched = {} }, {}
    nextOn, bankOn = false, true
    slotInfo = { [BACKPACK] = { "backpack data" }, [BANK] = { "bank data" } }
    override(addon, "Bags", {})
    override(addon, "Vendor", nil)
    override(addon, "atBank", false)
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.database, "GetNextEnabled", function() return nextOn end)
    override(stubs.database, "SetNextEnabled", function(_, on) nextOn = on end)
    override(stubs.database, "GetEnableBankBag", function() return bankOn end)
    override(stubs.items, "GetAllSlotInfo", function() return slotInfo end)
    override(stubs.bagFrame, "Create", spy.new(function(_, _, kind) return fakeBag("classic", kind) end))
    override(stubs.nextBag, "Create", spy.new(function() return fakeBag("next", BACKPACK) end))
    override(stubs.nextBank, "Create", spy.new(function() return fakeBag("next", BANK) end))
    override(stubs.nextVendor, "Create", spy.new(function()
      local v = fakeBag("next", "vendor")
      v.atMerchant = false
      return v
    end))
    override(stubs.nextVendor, "TakeOver", function(_, hidden) table.insert(calls.takeOver, hidden) end)
    override(stubs.nextVendor, "GiveBack", function() calls.giveBack = calls.giveBack + 1 end)
    override(stubs.consoleport, "Add", function(_, frame) table.insert(calls.consoleport, frame) end)
    override(addon, "WatchBackpackFrame", function(_, frame) table.insert(calls.watched, frame) end)
    override(addon, "UpdateButtonHighlight", function() calls.highlight = (calls.highlight or 0) + 1 end)
    override(_G, "InCombatLockdown", function() return false end)
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
      assert.are.same({ "next 0", "next 1", "next message 0", "next message 1", "next message vendor",
        "next vendor" }, fire())
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
      assert.are.same({ addon.Bags.Backpack.frame, addon.Bags.Bank.frame }, calls.consoleport)
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
      assert.are.equal(2, #UISpecialFrames - 3, "the classic frames listed once")
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
end)
