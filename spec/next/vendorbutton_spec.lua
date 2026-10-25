-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
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
  events = trackStub("Events"),
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
    b.button:GetScript("OnClick")(b.button, mouse or "RightButton")
  end

  local function enter(b)
    b.button:GetScript("OnEnter")(b.button)
  end

  before_each(function()
    calls = { purchase = {}, buyback = {}, repair = {}, messages = {} }
    asked = nil
    vendorButton:Init()
    override(const, "ITEM_QUALITY_COLOR", { [1] = { 1, 1, 1, 1 }, [2] = { 0.12, 1, 0, 1 }, [4] = { 0.64, 0.21, 0.93, 1 } })
    override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2 })
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.events, "SendMessage", function(_, _, name, ...)
      table.insert(calls.messages, { name = name, args = { ... } })
    end)
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
    UseNextTheme(nil)
    ResetModuleStub("NextVendorButton")
    ResetModuleStub("NextStyle")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("its look", function()
    -- Asked (a user found the price under the icon too small, then: "let's actually do this like this,
    -- which is the gw2 addon ... name too?"): each item a card, as Blizzard's merchant and GW2_UI draw
    -- it: the icon, its name beside it, its price on one line under the name, in larger fonts.
    it("is a card as wide as its theme's columns make it and as tall as its icon, reused once released", function()
      local b = vendorButton:Acquire()
      local width = math.floor((style.GRID_WIDTH - (style.VENDOR_COLUMNS - 1) * style.GAP) / style.VENDOR_COLUMNS)
      assert.are.equal(width, style.VENDOR_CARD_WIDTH)
      assert.are.same({ width, style.ICON }, { b.frame:GetSize() })
      assert.are.same({ style.ICON, style.ICON }, { b.button:GetSize() })
      b:Release()
      assert.is_false(b.frame:IsShown())
      assert.are.equal(b, vendorButton:Acquire())
      assert.are_not.equal(b, vendorButton:Acquire())
    end)

    -- Icon Scale is the bags' item buttons' (docs/next-appearance-size.md): a card keeps the theme's
    -- size, its name's two lines beside the icon.
    it("keeps the theme's icon size whatever the player's Icon Scale", function()
      style:SetIconScale(150)
      local b = vendorButton:Acquire()
      b:Style()
      assert.are.same({ style.VENDOR_CARD_WIDTH, style.CARD_ICON }, { b.frame:GetSize() })
      assert.are.same({ style.CARD_ICON, style.CARD_ICON }, { b.button:GetSize() })
      assert.are.equal(style.Theme.Layout.Icon, style.CARD_ICON)
      assert.are_not.equal(style.ICON, style.CARD_ICON)
      style:SetIconScale(100)
      b:Release()
    end)

    -- Masque skins a button against its own size (Core.lua UpdateScale), so the button it skins is
    -- the square icon; the name and price are labels beside it on the card the canvas places.
    it("holds a square button with Masque's parts, its name and price beside it", function()
      local b = vendorButton:Acquire()
      assert.are.equal("Button", b.button:GetObjectType())
      assert.are.equal(b.frame, b.button:GetParent())
      assert.are.same({ "TOPLEFT", b.frame, "TOPLEFT", 0, 0 }, { b.button:GetPoint(1) })
      assert.are.same({ style.ICON, style.ICON }, { b.icon:GetSize() })
      -- Masque's names for an item button's parts (Masque 12.1.0 Skins/Regions.lua, Item).
      assert.are.equal(b.icon, b.button.icon)
      assert.are.equal(b.border, b.button.IconBorder)
      assert.are.equal(b.count, b.button.Count)
      assert.are.same({ Icon = b.icon, IconBorder = b.border, Count = b.count, Highlight = b.highlight },
        b:MasqueRegions())
      assert.are.equal("HIGHLIGHT", b.highlight:GetDrawLayer())
      local textWidth = style.VENDOR_CARD_WIDTH - style.ICON - 2 * style.VENDOR_TEXT_GAP
      assert.are.same({ "TOPLEFT", b.button, "TOPRIGHT", style.VENDOR_TEXT_GAP + TEXT, TEXT }, { b.name:GetPoint(1) })
      assert.are.equal(textWidth, b.name:GetWidth())
      assert.are.same({ "LEFT", "TOP" }, { b.name:GetJustifyH(), b.name:GetJustifyV() })
      assert.is_true(b.name:CanWordWrap())
      assert.are.equal(2, b.name:GetMaxLines())
      -- Raised a little off the card's bottom edge (asked: "2-3 pixels up from the border").
      assert.is_true(style.VENDOR_PRICE_RAISE >= 2 and style.VENDOR_PRICE_RAISE <= 3)
      assert.are.same({ "BOTTOMLEFT", b.button, "BOTTOMRIGHT", style.VENDOR_TEXT_GAP + TEXT, style.VENDOR_PRICE_RAISE + TEXT },
        { b.price:GetPoint(1) })
      assert.are.equal(textWidth, b.price:GetWidth())
      assert.are.equal("LEFT", b.price:GetJustifyH())
      assert.is_false(b.price:CanWordWrap())
      assert.are.equal(1, b.price:GetMaxLines())
      assert.are.equal(style:Font(style.Theme.Vendor.NameFont), b.name:GetFontObject())
    end)

    it("announces each new button once, for Masque", function()
      local b = vendorButton:Acquire()
      b:Release()
      vendorButton:Acquire()
      assert.are.equal(1, #calls.messages)
      assert.are.same({ "vendor/NewButton", b }, { calls.messages[1].name, calls.messages[1].args[1] })
    end)

    -- A card is made before the canvas it goes in: placed on another grid (docs/next-pixel-perfect.md) it
    -- styles itself again, which draws its icon, count and highlight again over Masque's skin, so it says
    -- so (vendor/Updated: Masque's integration skins it again). On the grid it was styled for it does nothing.
    it("announces that it styled itself again on a new grid, for Masque, and nothing on the same grid", function()
      local b = vendorButton:Acquire()
      local parent = CreateFrame("Frame")
      parent:SetScale(0.8)
      b.frame:SetParent(parent)
      calls.messages = {}
      b:Fit()
      assert.are.same({ { name = "vendor/Updated", args = { b } } }, { calls.messages[1] })
      assert.are.equal(1, #calls.messages)
      b:Fit()
      assert.are.equal(1, #calls.messages, "the same grid")
    end)

    -- Asked: "the count for items in vendor, that font size should match our item count in bags":
    -- the bags' item buttons write their count in NumberFontNormal (ItemButtonTemplate.xml's Count),
    -- which the Stack role copies (its file, size and outline, in every locale).
    it("writes its stack count and stock in the bags' item count font", function()
      local b = vendorButton:Acquire()
      assert.are.equal(style:Font("Stack"), b.count:GetFontObject())
      assert.are.equal(style:Font("Stack"), b.stock:GetFontObject())
      assert.are.same({ NumberFontNormal:GetFont() }, { style:Font("Stack"):GetFont() })
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

    -- One line, as Blizzard's merchant writes a price: each coin it has (gold, silver, copper; none for
    -- a coin it has none of), each amount then its coin, then each other cost the same way.
    local GOLD, SILVER, COPPER = "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon",
      "Interface\\MoneyFrame\\UI-CopperIcon"
    local function coin(amount, texture)
      local size = style.Theme.Vendor.CoinSize
      return amount .. "|T" .. texture .. ":" .. size .. ":" .. size .. ":2:0|t"
    end

    -- In the vendor's Shopping List (profession-shopping-list.md): how many the list buys, and what that
    -- many costs (NextMerchant:PriceOf).
    it("shows how many a shopping list buys of it and what they cost, and its own count again after", function()
      override(stubs.merchant, "PriceOf", function(_, i, quantity)
        return i.price * quantity / i.stackCount, { { texture = 77, value = quantity } }
      end)
      local b = vendorButton:Acquire()
      b:SetBuy(item({ price = 100, stackCount = 5 }), 7)
      assert.are.equal("7", b.count:GetText())
      assert.is_true(b.count:IsShown())
      assert.are.equal(vendorButton:PriceText(140, { { texture = 77, value = 7 } }), b.price:GetText())
      b:SetBuy(item({ price = 100, stackCount = 5 }))
      assert.are.equal("5", b.count:GetText())
      assert.are.equal(vendorButton:PriceText(100, {}), b.price:GetText())
    end)

    it("prices it on one line: each coin it has, then each other cost", function()
      assert.are.equal(coin(12, GOLD) .. " " .. coin(34, SILVER) .. " " .. coin(56, COPPER),
        vendorButton:PriceText(123456, {}))
      assert.are.equal(coin(34, SILVER) .. " " .. coin(56, COPPER), vendorButton:PriceText(3456, {}))
      assert.are.equal(coin(7, COPPER), vendorButton:PriceText(7, {}))
      assert.are.equal(coin(2, GOLD) .. " " .. coin(5, COPPER), vendorButton:PriceText(20005, {}))
      assert.are.equal(coin(123456, GOLD), vendorButton:PriceText(1234560000, {}))
      assert.are.equal(coin(30, 77), vendorButton:PriceText(0, { { texture = 77, value = 30 } }))
      assert.are.equal(coin(5, SILVER) .. " " .. coin(30, 77) .. " " .. coin(1, 78),
        vendorButton:PriceText(500, { { texture = 77, value = 30 }, { texture = 78, value = 1 } }))
      assert.are.equal("", vendorButton:PriceText(0, {}))
    end)

    it("names it in its quality's color from Uncommon up, else in its role's color", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ name = "Arcanite Reaper", quality = 4, price = 123456 }))
      assert.are.equal("Arcanite Reaper", b.name:GetText())
      assert.are.same({ 0.64, 0.21, 0.93, 1 }, { b.name:GetTextColor() })
      assert.are.equal(coin(12, GOLD) .. " " .. coin(34, SILVER) .. " " .. coin(56, COPPER), b.price:GetText())
      b:SetBuy(item({ name = "Bread", quality = 1 }))
      assert.are.equal("Bread", b.name:GetText())
      assert.are.same({ style:Font(style.Theme.Vendor.NameFont):GetTextColor() }, { b.name:GetTextColor() })
      b:SetBuyback({ index = 1, name = "Sold Sword", texture = 1, price = 300, quantity = 1, isUsable = true, quality = 2 })
      assert.are.equal("Sold Sword", b.name:GetText())
      assert.are.same({ 0.12, 1, 0, 1 }, { b.name:GetTextColor() })
    end)

    it("lights its whole card under the pointer, from its icon or its card", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item())
      assert.is_false(b.cardHover:IsShown())
      b.card:GetScript("OnEnter")(b.card)
      assert.is_true(b.cardHover:IsShown())
      assert.are.same({ style:RGBA(style.Theme.Vendor.CardHover) }, { b.cardHover:GetVertexColor() })
      assert.is_true(GameTooltip:IsOwned(b.button), "the item's tooltip, from its card too")
      b.card:GetScript("OnLeave")(b.card)
      assert.is_false(b.cardHover:IsShown())
      enter(b)
      assert.is_true(b.cardHover:IsShown())
      b.button:GetScript("OnLeave")(b.button)
      assert.is_false(b.cardHover:IsShown())
      assert.are.same({ b.frame:GetPoint(1) }, { b.frame:GetPoint(1) })
      assert.are.equal("BACKGROUND", b.cardFill:GetDrawLayer())
      assert.is_true(b.card:GetFrameLevel() < b.button:GetFrameLevel(), "under its icon")
    end)

    it("buys from its card as from its icon", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item())
      b.card:GetScript("OnClick")(b.card, "RightButton")
      assert.are.equal(1, #calls.purchase)
      assert.are.equal(b.button, calls.purchase[1].frame)
    end)

    -- As Blizzard's merchant item buttons sell what is dropped on them (OnReceiveDrag runs their
    -- left click, which picks the merchant item up while holding the player's: a sale): the cards
    -- cover most of the panel, so a drop on one sells, through NextMerchant:SellCursorItem.
    it("sells what is dropped on it or left-clicked onto it, on its icon or its card", function()
      local sold = 0
      override(stubs.merchant, "SellCursorItem", function() sold = sold + 1 return "sold" end)
      local b = vendorButton:Acquire()
      b:SetBuy(item())
      b.card:GetScript("OnReceiveDrag")(b.card)
      b.button:GetScript("OnReceiveDrag")(b.button)
      assert.are.equal(2, sold)
      _G._cursorHasItem = true
      click(b, "LeftButton")
      b.card:GetScript("OnClick")(b.card, "LeftButton")
      _G._cursorHasItem = false
      assert.are.equal(4, sold)
      assert.are.equal(0, #calls.purchase, "nothing bought")
      click(b, "LeftButton")
      assert.are.equal(4, sold, "a plain left click sells nothing")
      -- As on Blizzard's merchant buttons, only a left click sells what is held: a right click buys.
      _G._cursorHasItem = true
      click(b, "RightButton")
      _G._cursorHasItem = false
      assert.are.equal(4, sold)
      assert.are.equal(1, #calls.purchase)
    end)

    it("prices what it cannot afford in red", function()
      local b = vendorButton:Acquire()
      b:SetBuy(item({ price = 500, canAfford = false }))
      assert.are.same({ 1, 0.25, 0.25, 1 }, { b.price:GetTextColor() })
      assert.are.equal(style:Font("PriceUnaffordable"), b.price:GetFontObject())
      b:SetBuy(item({ price = 500 }))
      assert.are.same({ 1, 1, 1, 1 }, { b.price:GetTextColor() })
      assert.are.equal(style:Font("Price"), b.price:GetFontObject())
    end)

    -- A Next theme (next-themes.md): sizes, roles, tints, highlight and search dimming, applied to
    -- every button made, pooled ones too.
    describe("a theme", function()
      after_each(function()
        UseNextTheme(nil)
        vendorButton:ApplyStyle()
      end)

      it("sizes every button it made to its icon and columns, and writes them in its roles", function()
        local live, pooled = vendorButton:Acquire(), vendorButton:Acquire()
        pooled:Release()
        UseNextTheme({ Palette = { Fog = { 0.5, 0.5, 0.5, 0.2 } }, Fonts = { Tiny = { Size = 8 } },
          Layout = { Icon = 32, VendorColumns = 3, VendorTextGap = 5, VendorPriceRaise = 4 },
          Vendor = { StackFont = "Tiny", PriceFont = "Tiny", NameFont = "Tiny", DurabilityHeight = 5, CoinSize = 9,
            CardFill = "Fog", CardHover = false } })
        vendorButton:ApplyStyle()
        assert.are.equal("7|TInterface\\MoneyFrame\\UI-CopperIcon:9:9:2:0|t", vendorButton:PriceText(7, {}))
        local width = math.floor((style.GRID_WIDTH - 2 * style.GAP) / 3)
        for _, b in ipairs({ live, pooled }) do
          assert.are.same({ width, 32 }, { b.frame:GetSize() })
          assert.are.same({ "BOTTOMLEFT", b.button, "BOTTOMRIGHT", 5 + TEXT, 4 + TEXT }, { b.price:GetPoint(1) })
          assert.are.equal(width - 32 - 10, b.name:GetWidth())
          assert.are.equal(style:Font("Tiny"), b.name:GetFontObject())
          assert.are.same({ 0.5, 0.5, 0.5, 0.2 }, { b.cardFill:GetVertexColor() })
          assert.is_true(b.cardFill:IsShown())
          b.card:GetScript("OnEnter")(b.card)
          assert.is_false(b.cardHover:IsShown(), "no hover light")
          b.card:GetScript("OnLeave")(b.card)
          assert.are.same({ 32, 32 }, { b.button:GetSize() })
          assert.are.same({ 32, 32 }, { b.icon:GetSize() })
          assert.are.equal(style:Font("Tiny"), b.count:GetFontObject())
          assert.are.equal(style:Font("Tiny"), b.price:GetFontObject())
          assert.are.equal(5, b.durability:GetHeight())
        end
        UseNextTheme({ Vendor = { CardFill = false } })
        vendorButton:ApplyStyle()
        for _, b in ipairs({ live, pooled }) do
          assert.is_false(b.cardFill:IsShown(), "no fill")
        end
      end)

      it("fills its cards with art when its fills are art, and colors after", function()
        local b = vendorButton:Acquire()
        UseNextTheme({ Vendor = { CardFill = { Texture = "Interface\\Spec\\card.png", Color = "White", Alpha = 0.8 },
          CardHover = { Texture = "Interface\\Spec\\card-lit.png", Color = "White" } } })
        vendorButton:ApplyStyle()
        assert.are.equal("Interface\\Spec\\card.png", b.cardFill:GetTexture())
        assert.are.equal(0.8, b.cardFill:GetAlpha())
        assert.are.equal("Interface\\Spec\\card-lit.png", b.cardHover:GetTexture())
        UseNextTheme({ Palette = { Fog = { 0.5, 0.5, 0.5, 0.2 } }, Vendor = { CardFill = "Fog" } })
        vendorButton:ApplyStyle()
        assert.is_nil(b.cardFill:GetTexture())
        assert.are.same({ 0.5, 0.5, 0.5, 0.2 }, { b.cardFill:GetVertexColor() })
        b:Release()
      end)

      it("tints with its colors, lights in its highlight, and dims by its share", function()
        UseNextTheme({ Palette = { Blood = { 0.6, 0.1, 0.1, 1 }, Ash = { 0.3, 0.3, 0.3, 1 } },
          Vendor = { Unusable = "Blood", SoldOut = "Ash", Highlight = { 1, 0.9, 0.6, 0.3 }, SearchDim = 0.5 } })
        vendorButton:ApplyStyle()
        local b = vendorButton:Acquire()
        b:SetBuy(item({ isUsable = false }))
        assert.are.same({ r = 0.6, g = 0.1, b = 0.1, a = 1 }, b.icon._vertexColor)
        b:SetBuy(item({ numAvailable = 0 }))
        assert.are.same({ r = 0.3, g = 0.3, b = 0.3, a = 1 }, b.icon._vertexColor)
        local h = b.highlight._colorTexture
        assert.are.same({ 1, 0.9, 0.6, 0.3 }, { h.r, h.g, h.b, h.a })
        b:SetSearchMatch(false)
        assert.are.equal(0.5, b.frame:GetAlpha())
      end)

      it("draws a quality border in its art, or none", function()
        local b = vendorButton:Acquire()
        UseNextTheme({ Vendor = { QualityBorder = false } })
        vendorButton:ApplyStyle()
        b:SetBuy(item({ quality = 4 }))
        assert.is_false(b.border:IsShown())
        UseNextTheme(nil)
        vendorButton:ApplyStyle()
        b:SetBuy(item({ quality = 4 }))
        assert.is_true(b.border:IsShown())
        assert.are.equal("Interface\\Common\\WhiteIconFrame", b.border:GetTexture())
      end)
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
      enter(b)
      assert.are.equal(b.button, GameTooltip._owner)
      assert.are.equal(4, GameTooltip._merchantItem)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ " ", "Price: 15s", "|T77:0|t 2 Valor", "Right-click to buy", "Shift-click to buy a quantity" }, text)
      assert.are.equal("BUY_CURSOR", _G._cursor)
      b.button:GetScript("OnLeave")(b.button)
      assert.is_nil(_G._cursor)
      b:SetBuy(item({ canAfford = false }))
      enter(b)
      assert.are.equal("BUY_ERROR_CURSOR", _G._cursor)
    end)

    it("says how many a shopping list needs, then only as long as it shows them", function()
      override(stubs.merchant, "PriceOf", function(_, i) return i.price, {} end)
      local b = vendorButton:Acquire()
      b:SetBuy(item({ price = 1500 }), 7)
      enter(b)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ " ", "Price: 15s", "Your shopping list needs 7", "Right-click to buy",
        "Shift-click to buy a quantity" }, text)
      b:SetBuy(item({ price = 1500 }))
      enter(b)
      text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ " ", "Price: 15s", "Right-click to buy", "Shift-click to buy a quantity" }, text)
    end)

    it("shows a buyback's and a repair's", function()
      local b = vendorButton:Acquire()
      b:SetBuyback({ index = 2, name = "Sold", texture = 5, price = 90, quantity = 3, isUsable = true, quality = 2 })
      enter(b)
      assert.are.equal(2, GameTooltip._buybackItem)
      b:SetRepair({ slot = 5, texture = 6, durability = 25, maxDurability = 100, cost = 3000 })
      enter(b)
      assert.are.same({ unit = "player", slot = 5 }, GameTooltip._inventoryItem)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ " ", "Durability: 25 / 100", "Repair: 30s", "Click to repair" }, text)
      b:SetRepair({ bag = 0, slot = 2, texture = 6, durability = 1, maxDurability = 2, cost = 5 })
      enter(b)
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
      assert.are.equal(b.button, calls.purchase[1].frame)
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
      b:SetRepair({ slot = 1, texture = 7, link = "|Hitem:10|h[Ten]|h", durability = 25, maxDurability = 100, cost = 30000 })
      assert.are.equal(7, b.icon:GetTexture())
      assert.is_true(b.durability:IsShown())
      assert.are.equal(style.ICON * 0.25, b.durability:GetWidth())
      local size = style.Theme.Vendor.CoinSize
      assert.are.equal("3|TInterface\\MoneyFrame\\UI-GoldIcon:" .. size .. ":" .. size .. ":2:0|t", b.price:GetText())
      assert.are.equal("Ten", b.name:GetText(), "named from its link")
      b:SetBuy(item())
      assert.is_false(b.durability:IsShown())
    end)
  end)
end)
