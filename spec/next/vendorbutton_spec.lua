-- vendorbutton_spec.lua -- NextVendorButton (next/vendorbutton.lua): the buttons of BetterBags Next's
-- vendor (next.md §10). A button shows an item for sale, a buyback or an item to repair: its icon,
-- stack, stock, quality, what makes it unusable or sold out, and its price under it; its tooltip is
-- Blizzard's; its clicks buy (through Blizzard's confirmations, NextMerchant), ask a quantity, buy back
-- or repair, the way Blizzard's merchant buttons do.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
local stubs = {
  merchant = trackStub("NextMerchant"),
  question = trackStub("Question"),
  L = trackStub("Localization"),
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

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextVendorButton", "next/vendorbutton.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local vendorButton = addon:GetModule("NextVendorButton")
local style = addon:GetModule("NextStyle")

describe("NextVendorButton", function()
  local calls, asked

  local function item(opts)
    local i = { index = 4, link = "|Hitem:10|h[Ten]|h", itemID = 10, name = "Ten", texture = 1234, price = 0,
      stackCount = 1, numAvailable = -1, maxStack = 20, isPurchasable = true, isUsable = true,
      hasExtendedCost = false, isQuestStartItem = false, canAfford = true, refundable = true,
      isKnownHeirloom = false, quality = 1, costs = {} }
    for k, v in pairs(opts or {}) do i[k] = v end
    return i
  end

  local function click(b, mouse)
    b.frame:GetScript("OnClick")(b.frame, mouse or "RightButton")
  end

  before_each(function()
    calls = { purchase = {}, buyback = {}, repair = {} }
    asked = nil
    vendorButton:Init()
    override(const, "ITEM_QUALITY_COLOR", { [1] = { 1, 1, 1, 1 }, [2] = { 0.12, 1, 0, 1 }, [4] = { 0.64, 0.21, 0.93, 1 } })
    override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2 })
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.merchant, "Purchase", function(_, frame, i, quantity)
      table.insert(calls.purchase, { frame = frame, item = i, quantity = quantity })
    end)
    override(stubs.merchant, "MaxPurchasable", function() return 12 end)
    override(stubs.merchant, "Buyback", function(_, index) table.insert(calls.buyback, index) end)
    override(stubs.merchant, "RepairOne", function(_, entry) table.insert(calls.repair, entry) end)
    override(stubs.question, "AskForInput", function(_, title, text, onInput)
      asked = { title = title, text = text, onInput = onInput }
    end)
    _G._isShiftKeyDown, _G._isControlKeyDown = false, false
    _G._modifiedClickHandled = false
    _G._cursor = nil
  end)

  after_each(function()
    restore()
    _G._isShiftKeyDown, _G._isControlKeyDown = false, false
    _G._modifiedClickHandled = false
  end)

  teardown(function()
    ResetModuleStub("NextVendorButton")
    ResetModuleStub("NextStyle")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("its look", function()
    it("is a big icon with room for its price under it, and is reused once released", function()
      local b = vendorButton:Acquire()
      assert.are.same({ style.ICON, style.ICON + style.VENDOR_PRICE }, { b.frame:GetSize() })
      assert.are.same({ style.ICON, style.ICON }, { b.icon:GetSize() })
      b:Release()
      assert.is_false(b.frame:IsShown())
      assert.are.equal(b, vendorButton:Acquire())
      assert.are_not.equal(b, vendorButton:Acquire())
    end)

    it("shows an item for sale: icon, stack size, stock and the quest mark", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ stackCount = 5, numAvailable = 3, isQuestStartItem = true }))
      assert.are.equal("vendor:4", b.key)
      assert.are.equal(1234, b.icon:GetTexture())
      assert.are.equal("5", b.count:GetText())
      assert.is_true(b.count:IsShown())
      assert.are.equal("(3)", b.stock:GetText())
      assert.is_true(b.quest:IsShown())
      b:SetBuy(item())
      assert.is_false(b.count:IsShown(), "no count for one")
      assert.is_false(b.stock:IsShown(), "no stock without a limit")
      assert.is_false(b.quest:IsShown())
    end)

    it("draws a quality border from Uncommon up, in the quality's color", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ quality = 4 }))
      assert.is_true(b.border:IsShown())
      assert.are.same({ r = 0.64, g = 0.21, b = 0.93, a = 1 }, b.border._vertexColor)
      b:SetBuy(item({ quality = 1 }))
      assert.is_false(b.border:IsShown())
    end)

    it("tints red what cannot be bought or used, dims what is sold out, greys a known heirloom", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ isUsable = false }))
      assert.are.same({ r = 0.9, g = 0, b = 0, a = 1 }, b.icon._vertexColor)
      b:SetBuy(item({ isPurchasable = false }))
      assert.are.same({ r = 0.9, g = 0, b = 0, a = 1 }, b.icon._vertexColor)
      b:SetBuy(item({ numAvailable = 0 }))
      assert.are.same({ r = 0.5, g = 0.5, b = 0.5, a = 1 }, b.icon._vertexColor)
      b:SetBuy(item({ numAvailable = 0, isUsable = false }))
      assert.are.same({ r = 0.5, g = 0, b = 0, a = 1 }, b.icon._vertexColor)
      b:SetBuy(item({ isKnownHeirloom = true }))
      assert.is_true(b.icon:IsDesaturated())
      assert.are.same({ r = 0.5, g = 0.5, b = 0.5, a = 1 }, b.icon._vertexColor)
      b:SetBuyback({ index = 1, texture = 1, price = 1, quantity = 1, isUsable = true })
      assert.is_false(b.icon:IsDesaturated(), "a buyback shown after it is not greyed")
      b:SetBuy(item())
      assert.are.same({ r = 1, g = 1, b = 1, a = 1 }, b.icon._vertexColor)
      assert.is_false(b.icon:IsDesaturated())
    end)

    it("prices it in its largest coin, or its first cost, marking more", function()
      assert.are.equal("12|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", vendorButton:PriceText(123456, {}))
      assert.are.equal("34|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t", vendorButton:PriceText(3456, {}))
      assert.are.equal("7|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", vendorButton:PriceText(7, {}))
      assert.are.equal("30|T77:12:12:2:0|t", vendorButton:PriceText(0, { { texture = 77, value = 30 } }))
      assert.are.equal("30|T77:12:12:2:0|t+", vendorButton:PriceText(0, { { texture = 77, value = 30 }, { texture = 78, value = 1 } }))
      assert.are.equal("30|T77:12:12:2:0|t+", vendorButton:PriceText(500, { { texture = 77, value = 30 } }))
      assert.are.equal("", vendorButton:PriceText(0, {}))
    end)

    it("prices what it cannot afford in red", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ price = 500, canAfford = false }))
      assert.are.same({ 1, 0.25, 0.25, 1 }, { b.price:GetTextColor() })
      b:SetBuy(item({ price = 500 }))
      assert.are.same({ 1, 1, 1, 1 }, { b.price:GetTextColor() })
    end)

    it("dims what a search leaves out", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item())
      b:SetSearchMatch(false)
      assert.are.equal(0.25, b.frame:GetAlpha())
      b:SetSearchMatch(true)
      assert.are.equal(1, b.frame:GetAlpha())
    end)
  end)

  describe("its tooltip", function()
    it("is Blizzard's merchant item tooltip with its price and what clicking does, and the buy cursor", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ price = 1500, costs = { { texture = 77, value = 2, currencyName = "Valor" } } }))
      b.frame:GetScript("OnEnter")(b.frame)
      assert.are.equal(4, GameTooltip._merchantItem)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ " ", "Price: 15s", "|T77:0|t 2 Valor", "Right-click to buy", "Shift-click to buy a quantity" }, text)
      assert.are.equal("BUY_CURSOR", _G._cursor)
      b.frame:GetScript("OnLeave")(b.frame)
      assert.is_nil(_G._cursor)
      b:SetBuy(item({ canAfford = false }))
      b.frame:GetScript("OnEnter")(b.frame)
      assert.are.equal("BUY_ERROR_CURSOR", _G._cursor)
    end)

    it("shows a buyback's and a repair's", function()
      local b = vendorButton:Acquire()
      b:SetBuyback({ index = 2, name = "Sold", texture = 5, price = 90, quantity = 3, isUsable = true, quality = 2 })
      b.frame:GetScript("OnEnter")(b.frame)
      assert.are.equal(2, GameTooltip._buybackItem)
      b:SetRepair({ slot = 5, texture = 6, durability = 25, maxDurability = 100, cost = 3000 })
      b.frame:GetScript("OnEnter")(b.frame)
      assert.are.same({ unit = "player", slot = 5 }, GameTooltip._inventoryItem)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ " ", "Durability: 25 / 100", "Repair: 30s", "Click to repair" }, text)
      b:SetRepair({ bag = 0, slot = 2, texture = 6, durability = 1, maxDurability = 2, cost = 5 })
      b.frame:GetScript("OnEnter")(b.frame)
      assert.are.same({ bag = 0, slot = 2 }, GameTooltip._bagItem)
    end)
  end)

  describe("its clicks", function()
    it("buys on a right click, through NextMerchant, and does nothing on a left click", function()
      local b = vendorButton:Acquire()
      local i = item()
      b:SetBuy(i)
      click(b, "LeftButton")
      assert.are.same({}, calls.purchase)
      click(b, "RightButton")
      assert.are.equal(1, #calls.purchase)
      assert.are.equal(b.frame, calls.purchase[1].frame)
      assert.are.equal(i, calls.purchase[1].item)
      assert.is_nil(calls.purchase[1].quantity)
    end)

    it("leaves a modified click Blizzard handles (a chat link, a preview) to Blizzard", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item())
      _G._isControlKeyDown = true
      _G._modifiedClickHandled = true
      click(b, "LeftButton")
      click(b, "RightButton")
      assert.are.same({}, calls.purchase)
      assert.is_nil(asked)
    end)

    it("asks how many on a Shift-click, buying what was asked within what can be bought", function()
      local b = vendorButton:Acquire()
      local i = item({ maxStack = 20 })
      b:SetBuy(i)
      _G._isShiftKeyDown = true
      click(b, "LeftButton")
      assert.are.equal("Buy Ten", asked.title)
      assert.are.equal("How many? (up to 12)", asked.text)
      asked.onInput("5")
      asked.onInput("50")
      asked.onInput("none")
      asked.onInput("0")
      assert.are.same({ 5, 12 }, { calls.purchase[1].quantity, calls.purchase[2].quantity })
      assert.are.equal(2, #calls.purchase)
    end)

    it("asks nothing for an item bought one at a time", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ maxStack = 1 }))
      _G._isShiftKeyDown = true
      click(b, "RightButton")
      assert.is_nil(asked)
      assert.are.same({}, calls.purchase)
    end)

    it("buys back on any click, and repairs on any click", function()
      local b = vendorButton:Acquire()
      b:SetBuyback({ index = 3, texture = 1, price = 1, quantity = 1, isUsable = true })
      click(b, "LeftButton")
      click(b, "RightButton")
      assert.are.same({ 3, 3 }, calls.buyback)
      local entry = { slot = 1, texture = 1, durability = 1, maxDurability = 2, cost = 1 }
      b:SetRepair(entry)
      click(b, "LeftButton")
      assert.are.same({ entry }, calls.repair)
    end)
  end)

  describe("a repair", function()
    it("shows how worn it is as a bar along the icon's bottom, and what repairing it costs", function()
      local b = vendorButton:Acquire()
      b:SetRepair({ slot = 1, texture = 7, durability = 25, maxDurability = 100, cost = 30000 })
      assert.are.equal(7, b.icon:GetTexture())
      assert.is_true(b.durability:IsShown())
      assert.are.equal(style.ICON * 0.25, b.durability:GetWidth())
      assert.are.equal("3|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", b.price:GetText())
      b:SetBuy(item())
      assert.is_false(b.durability:IsShown())
    end)
  end)
end)
