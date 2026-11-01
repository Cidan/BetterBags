local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextMerchant: AceModule
local merchant = addon:GetModule('NextMerchant')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- How far in from the icon's corners the stack count and the stock sit.
local COUNT_INSET = 2

-- NextVendorButton is a button of BetterBags Next's vendor (next.md §10): an item for sale, a
-- buyback, or an item to repair. It shows the icon, stack size, stock, quality, the quest mark, what
-- makes it unusable or sold out (as Blizzard's MerchantFrame_UpdateMerchantInfo tints them), and, on
-- a card beside the icon, its name and price; its tooltip is Blizzard's; its clicks buy (NextMerchant:Purchase, through
-- Blizzard's confirmations), ask a quantity (our own dialog, as CompactVendor has its own), buy
-- back or repair, the way Blizzard's merchant item buttons do. A left click never puts the item on
-- the cursor, so it cannot be bought by dropping it on a bag slot past Blizzard's confirmations.
-- An item dropped on it is sold, as on Blizzard's merchant item buttons. The buttons are plain
-- Buttons: nothing they call is protected.
---@class NextVendorButton: AceModule
local vendorButton = addon:NewModule('NextVendorButton')

local COIN_ICONS = {
  "Interface\\MoneyFrame\\UI-GoldIcon",
  "Interface\\MoneyFrame\\UI-SilverIcon",
  "Interface\\MoneyFrame\\UI-CopperIcon",
}

-- paintCard fills a card's background or its hover light: art (a texture spec with a Texture or an Atlas) or a color.
---@param texture Texture
---@param fill table|string
local function paintCard(texture, fill)
  if style:IsArt(fill) then
    style:Paint(texture, fill, fill.Alpha)
  else
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetVertexColor(style:RGBA(fill))
  end
end

---@alias NextVendorButtonMode "buy"|"buyback"|"repair"

---@class NextVendorButtonFrame
---@field key string What the canvas knows it by.
---@field frame Frame The card the canvas places: the button, and its name and price beside it.
---@field button Button The square button: it takes the clicks, and Masque skins it.
---@field card Button The whole card: it takes the clicks and the pointer beside the icon too.
---@field cardFill Texture
---@field cardHover Texture Shown while the pointer is over the card or its icon.
---@field name FontString
---@field highlight Texture
---@field icon Texture
---@field border Texture
---@field quest Texture
---@field count FontString
---@field stock FontString
---@field price FontString
---@field durability Texture
---@field mode? NextVendorButtonMode
---@field item? NextVendorItem
---@field quantity? number How many a shopping list buys of it, in the vendor's Shopping List.
---@field buyback? NextBuybackItem
---@field repair? NextRepairEntry
local buttonProto = {}
addon:GetModule('Perf'):RegisterPrototype(buttonProto, 'NextVendorButtonFrame')

function vendorButton:Init()
  self.pool = {} ---@type NextVendorButtonFrame[]
  -- Every button made, for a theme to restyle (ApplyStyle).
  self.all = {} ---@type NextVendorButtonFrame[]
end

vendorButton:Init()

-- PriceText is a price on one line, as Blizzard's merchant writes it: each coin of the gold it has
-- (gold, silver, copper; none for a coin it has none of), each amount then its coin, then each other
-- cost the same way (Vendor.CoinSize). It is cut short when it does not fit; the tooltip shows it all.
---@param price number
---@param costs NextVendorCost[]
---@return string
function vendorButton:PriceText(price, costs)
  local size = style.Theme.Vendor.CoinSize
  local parts = {}
  local function add(n, texture)
    table.insert(parts, BreakUpLargeNumbers(n) .. "|T" .. texture .. ":" .. size .. ":" .. size .. ":2:0|t")
  end
  if price and price > 0 then
    local coins = { math.floor(price / 10000), math.floor(price / 100) % 100, price % 100 }
    for i, n in ipairs(coins) do
      if n > 0 then
        add(n, COIN_ICONS[i])
      end
    end
  end
  for _, cost in ipairs(costs) do
    add(cost.value, cost.texture)
  end
  return table.concat(parts, " ")
end

---@return NextVendorButtonFrame
-- newButton makes a button: a card the canvas places (asked: as Blizzard's merchant and GW2_UI draw
-- an item, its icon with its name and price beside it), and on it the square button that takes the
-- clicks and that Masque skins, over the card's own click area. Masque sizes a skin to the button it
-- skins (Core.lua UpdateScale), and finds an item button's parts by these names (Masque 12.1.0
-- Skins/Regions.lua, Item): icon, IconBorder, Count.
---@return NextVendorButtonFrame
local function newButton()
  local frame = CreateFrame("Frame")
  local cardFill = frame:CreateTexture(nil, "BACKGROUND")
  cardFill:SetAllPoints(frame)
  cardFill:SetColorTexture(1, 1, 1, 1)
  local cardHover = frame:CreateTexture(nil, "BORDER")
  cardHover:SetAllPoints(frame)
  cardHover:SetColorTexture(1, 1, 1, 1)
  cardHover:Hide()
  local card = CreateFrame("Button", nil, frame)
  card:SetAllPoints(frame)
  card:SetFrameLevel(frame:GetFrameLevel() + 1)
  card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local button = CreateFrame("Button", nil, frame)
  button:SetFrameLevel(frame:GetFrameLevel() + 2)
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.icon = icon
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetAllPoints(icon)
  border:Hide()
  button.IconBorder = border
  local quest = button:CreateTexture(nil, "OVERLAY", nil, 2)
  quest:SetAllPoints(icon)
  quest:Hide()
  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(icon)
  local durability = button:CreateTexture(nil, "OVERLAY", nil, 3)
  durability:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
  durability:SetColorTexture(1, 1, 1, 1)
  durability:Hide()
  local count = button:CreateFontString(nil, "OVERLAY")
  button.Count = count
  local stock = button:CreateFontString(nil, "OVERLAY")
  local name = frame:CreateFontString(nil, "OVERLAY")
  local price = frame:CreateFontString(nil, "OVERLAY")
  ---@type NextVendorButtonFrame
  local b = setmetatable({
    key = "", frame = frame, button = button, card = card, cardFill = cardFill, cardHover = cardHover,
    icon = icon, border = border, quest = quest, count = count, stock = stock, name = name, price = price,
    durability = durability, highlight = highlight, affordable = true, quality = nil,
  }, { __index = buttonProto })
  b:Style()
  for _, target in ipairs({ button, card }) do
    target:SetScript("OnEnter", function() b:OnEnter() end)
    target:SetScript("OnLeave", function() b:OnLeave() end)
    addon.SetScript(target, "OnClick", function(_, _, mouse) b:OnClick(mouse) end)
    addon.SetScript(target, "OnReceiveDrag", function() b:OnReceiveDrag() end)
  end
  return b
end

-- Style draws the button from the Next theme (Layout, Vendor): its card's size (VendorColumns across
-- the grid), fill and hover light, its name at the top beside the icon (up to two lines) and its price
-- on one line at the bottom, its highlight, quest mark and durability bar, its stack, stock, name and
-- price in their roles.
function buttonProto:Style()
  local V = style.Theme.Vendor
  -- In whole pixels on the grid it is drawn on (docs/next-pixel-perfect.md); Fit styles it again when
  -- that changes (a card is made before the canvas it goes in).
  local frame = self.frame
  self.unit = pixel:Unit(frame)
  -- A card keeps the theme's icon size (CARD_ICON): Icon Scale is the bags' item buttons'
  -- (docs/next-appearance-size.md), and a smaller icon would not fit two lines of name beside it.
  local icon, width = pixel:Lengths(frame, style.CARD_ICON, style.VENDOR_CARD_WIDTH)
  frame:SetSize(width, icon)
  self.button:SetSize(icon, icon)
  self.icon:SetSize(icon, icon)
  local gap = pixel:Snap(frame, style.VENDOR_TEXT_GAP)
  local textWidth = width - icon - 2 * gap
  local name, price = self.name, self.price
  name:ClearAllPoints()
  pixel:Point(name, "TOPLEFT", self.button, "TOPRIGHT", gap, 0)
  name:SetWidth(textWidth)
  price:ClearAllPoints()
  pixel:Point(price, "BOTTOMLEFT", self.button, "BOTTOMRIGHT", gap, pixel:Snap(frame, style.VENDOR_PRICE_RAISE))
  price:SetWidth(textWidth)
  local inset = pixel:Snap(frame, COUNT_INSET)
  self.count:ClearAllPoints()
  pixel:Point(self.count, "BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", -inset, inset)
  self.stock:ClearAllPoints()
  pixel:Point(self.stock, "TOPLEFT", self.icon, "TOPLEFT", inset, -inset)
  self.cardFill:SetShown(V.CardFill and true or false)
  if V.CardFill then
    paintCard(self.cardFill, V.CardFill)
  end
  if V.CardHover then
    paintCard(self.cardHover, V.CardHover)
  else
    self.cardHover:Hide()
  end
  self.highlight:SetColorTexture(style:RGBA(V.Highlight))
  self.quest:SetTexture(style:TexturePath(V.QuestMark))
  if V.QualityBorder then
    self.border:SetTexture(style:TexturePath(V.QualityBorder))
  else
    self.border:Hide()
  end
  pixel:Height(self.durability, V.DurabilityHeight)
  self:sizeDurability()
  style:SetFont(self.count, V.StackFont)
  style:SetFont(self.stock, V.StackFont)
  self:setNameFont()
  self:setPriceFont()
end

-- sizeDurability makes the durability bar its share of the icon's width, in whole pixels.
---@private
function buttonProto:sizeDurability()
  pixel:Width(self.durability, math.max(1, self.icon:GetWidth() * (self.durabilityFraction or 1)))
end

-- Fit styles the card again when the grid it is drawn on is not the one it was styled for: the canvas calls
-- it as it places the card (docs/next-pixel-perfect.md).
function buttonProto:Fit()
  if self.unit == nil or math.abs(self.unit - pixel:Unit(self.frame)) > 1e-9 then
    self:Style()
    -- Styling drew its icon, count and highlight again, over Masque's skin: Masque's integration skins it
    -- again on this, so its skin goes last, as after a theme.
    events:SendMessage(context:New('NextVendorButton_Fit'), 'vendor/Updated', self)
  else
    -- Filled before it was placed (SetRepair), its bar was sized on the grid it had then.
    self:sizeDurability()
  end
end

-- setNameFont writes the name in the theme's role, left-aligned from the top, at most two lines (a
-- font string wraps unless told not to, UI.xsd), in its quality's color from Uncommon up. The layout is set again after the font object: a font string
-- takes its layout from the font object it is given.
---@private
function buttonProto:setNameFont()
  local name = self.name
  style:SetFont(name, style.Theme.Vendor.NameFont)
  name:SetJustifyH("LEFT")
  name:SetJustifyV("TOP")
  name:SetMaxLines(2)
  local color = self.quality ~= nil and self.quality >= const.ITEM_QUALITY.Uncommon and const.ITEM_QUALITY_COLOR[self.quality]
  if color then
    name:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  else
    name:SetTextColor(style:Font(style.Theme.Vendor.NameFont):GetTextColor())
  end
end

-- setName shows an item's name in its quality's color.
---@private
---@param text? string
---@param quality? number
function buttonProto:setName(text, quality)
  self.quality = quality
  self.name:SetText(text or "")
  self:setNameFont()
end

-- setPriceFont writes the price in the theme's role for whether the player can afford it, on one
-- line, left-aligned; set again after the font object, as the name's is.
---@private
function buttonProto:setPriceFont()
  local V, price = style.Theme.Vendor, self.price
  style:SetFont(price, self.affordable and V.PriceFont or V.UnaffordableFont)
  price:SetJustifyH("LEFT")
  price:SetWordWrap(false)
  price:SetMaxLines(1)
end

-- ApplyStyle restyles every vendor button made, in use or pooled (SonataNext applied a theme); the
-- vendor draws the ones in use again.
---@param ctx? Context
function vendorButton:ApplyStyle(ctx)
  local _ = ctx
  for _, b in ipairs(self.all) do
    b:Style()
  end
end

-- MasqueRegions returns the parts Masque skins, by its region names (Skins/Regions.lua, Item).
---@return table<string, Region>
function buttonProto:MasqueRegions()
  return { Icon = self.icon, IconBorder = self.border, Count = self.count, Highlight = self.highlight }
end

-- Acquire returns a released button, or a new one, announced once (vendor/NewButton: Masque adds
-- it to its Vendor group).
---@return NextVendorButtonFrame
function vendorButton:Acquire()
  local b = table.remove(self.pool)
  if b == nil then
    b = newButton()
    table.insert(self.all, b)
    sonataNext:RegisterWidget(self)
    events:SendMessage(context:New('NextVendorButton'), 'vendor/NewButton', b)
  end
  b.frame:Show()
  return b
end

-- Release hides the button and pools it.
function buttonProto:Release()
  self.frame:Hide()
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.mode, self.item, self.buyback, self.repair = nil, nil, nil, nil
  table.insert(vendorButton.pool, self)
end

-- reset clears what one mode shows and another does not.
---@private
---@param texture number|string
---@param quality? number
function buttonProto:reset(texture, quality)
  self.icon:SetTexture(texture)
  self.icon:SetDesaturated(false)
  self.icon:SetVertexColor(1, 1, 1, 1)
  self.count:Hide()
  self.stock:Hide()
  self.quest:Hide()
  self.durability:Hide()
  self:setAffordable(true)
  self.frame:SetAlpha(1)
  local color = style.Theme.Vendor.QualityBorder and quality ~= nil and quality >= const.ITEM_QUALITY.Uncommon
    and const.ITEM_QUALITY_COLOR[quality]
  if color then
    self.border:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    self.border:Show()
  else
    self.border:Hide()
  end
end

---@private
---@param n number
function buttonProto:setCount(n)
  if n and n > 1 then
    self.count:SetText(tostring(n))
    self.count:Show()
  end
end

-- SetBuy shows an item for sale. With a quantity (the vendor's Shopping List,
-- profession-shopping-list.md), its count is how many the list buys and its price what that many cost.
---@param item NextVendorItem
---@param quantity? number
function buttonProto:SetBuy(item, quantity)
  self.mode, self.item, self.quantity = "buy", item, quantity
  self.key = "vendor:" .. item.index
  self:reset(item.texture, item.quality)
  self:setCount(quantity or item.stackCount)
  if item.numAvailable and item.numAvailable >= 0 then
    self.stock:SetText("(" .. item.numAvailable .. ")")
    self.stock:Show()
  end
  self.quest:SetShown(item.isQuestStartItem)
  -- As MerchantFrame_UpdateMerchantInfo tints it, in the theme's colors.
  local V = style.Theme.Vendor
  local tintRed = not item.isPurchasable or not item.isUsable
  if item.numAvailable == 0 or item.isKnownHeirloom then
    if tintRed then
      self.icon:SetVertexColor(style:RGBA(V.SoldOutUnusable))
    else
      self.icon:SetVertexColor(style:RGBA(V.SoldOut))
    end
  elseif tintRed then
    self.icon:SetVertexColor(style:RGBA(V.Unusable))
  end
  self.icon:SetDesaturated(item.isKnownHeirloom)
  self:setAffordable(item.canAfford and true or false)
  self:setName(item.name, item.quality)
  if quantity then
    self.price:SetText(vendorButton:PriceText(merchant:PriceOf(item, quantity)))
  else
    self.price:SetText(vendorButton:PriceText(item.price, item.costs))
  end
end

-- setAffordable writes the price in the theme's role for whether the player can afford it.
---@private
---@param affordable boolean
function buttonProto:setAffordable(affordable)
  self.affordable = affordable
  self:setPriceFont()
end

-- SetBuyback shows an item that was sold.
---@param entry NextBuybackItem
function buttonProto:SetBuyback(entry)
  self.mode, self.buyback = "buyback", entry
  self.key = "buyback:" .. entry.index
  self:reset(entry.texture, entry.quality)
  self:setCount(entry.quantity)
  if not entry.isUsable then
    self.icon:SetVertexColor(style:RGBA(style.Theme.Vendor.Unusable))
  end
  self:setName(entry.name, entry.quality)
  self.price:SetText(vendorButton:PriceText(entry.price, {}))
end

-- SetRepair shows a damaged item: how worn it is as a bar along the icon's bottom, green to red,
-- and what repairing it costs.
---@param entry NextRepairEntry
function buttonProto:SetRepair(entry)
  self.mode, self.repair = "repair", entry
  self.key = entry.bag and ("repair:" .. entry.bag .. ":" .. entry.slot) or ("repair:" .. entry.slot)
  local quality = entry.link and select(3, C_Item.GetItemInfo(entry.link)) or nil
  self:reset(entry.texture, quality)
  local fraction = entry.maxDurability > 0 and entry.durability / entry.maxDurability or 0
  self.durabilityFraction = fraction
  self:sizeDurability()
  self.durability:SetVertexColor(1 - fraction, fraction, 0.1, 1)
  self.durability:Show()
  self:setName(entry.link and entry.link:match("%[(.-)%]"), quality)
  self.price:SetText(vendorButton:PriceText(entry.cost, {}))
end

-- SetSearchMatch dims the button when a search leaves it out.
---@param match boolean
function buttonProto:SetSearchMatch(match)
  self.frame:SetAlpha(match and 1 or style.Theme.Vendor.SearchDim)
end

---@param costs NextVendorCost[]
local function addCosts(price, costs)
  if price and price > 0 then
    GameTooltip:AddLine(L:G("Price: ") .. GetMoneyString(price, true), 1, 1, 1)
  end
  for _, cost in ipairs(costs) do
    GameTooltip:AddLine("|T" .. cost.texture .. ":0|t " .. BreakUpLargeNumbers(cost.value) .. " " .. (cost.currencyName or cost.link or ""), 1, 1, 1)
  end
end

-- OnEnter lights the card and shows Blizzard's tooltip for what the button shows, with its price and
-- what clicking does, and the cursor Blizzard's merchant shows over it.
function buttonProto:OnEnter()
  if style.Theme.Vendor.CardHover then
    self.cardHover:Show()
  end
  GameTooltip:SetOwner(self.button, "ANCHOR_RIGHT")
  if self.mode == "buy" then
    local item = self.item
    GameTooltip:SetMerchantItem(item.index)
    if GameTooltip_ShowCompareItem then
      GameTooltip_ShowCompareItem(GameTooltip)
    end
    GameTooltip:AddLine(" ")
    addCosts(item.price, item.costs)
    if self.quantity then
      GameTooltip:AddLine(format(L:G("Your shopping list needs %d"), self.quantity), 1, 1, 1)
    end
    GameTooltip:AddLine(L:G("Right-click to buy"), 0.8, 0.8, 0.8)
    if item.maxStack > 1 then
      GameTooltip:AddLine(L:G("Shift-click to buy a quantity"), 0.8, 0.8, 0.8)
    end
    SetCursor(item.canAfford and "BUY_CURSOR" or "BUY_ERROR_CURSOR")
  elseif self.mode == "buyback" then
    GameTooltip:SetBuybackItem(self.buyback.index)
    if ShowBuybackSellCursor then
      ShowBuybackSellCursor(self.buyback.index)
    end
  elseif self.mode == "repair" then
    local entry = self.repair
    if entry.bag then
      GameTooltip:SetBagItem(entry.bag, entry.slot)
    else
      GameTooltip:SetInventoryItem("player", entry.slot)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(format(L:G("Durability: %d / %d"), entry.durability, entry.maxDurability), 1, 1, 1)
    GameTooltip:AddLine(L:G("Repair: ") .. GetMoneyString(entry.cost, true), 1, 1, 1)
    GameTooltip:AddLine(L:G("Click to repair"), 0.8, 0.8, 0.8)
  end
  GameTooltip:Show()
end

function buttonProto:OnLeave()
  self.cardHover:Hide()
  GameTooltip:Hide()
  ResetCursor()
end

-- OnReceiveDrag sells the item dropped on the card, as Blizzard's merchant item buttons do.
function buttonProto:OnReceiveDrag()
  merchant:SellCursorItem()
end

-- askQuantity asks how many to buy, within what can be bought at once, then buys that many.
---@private
function buttonProto:askQuantity()
  local item = self.item
  local most = merchant:MaxPurchasable(item)
  question:AskForInput(format(L:G("Buy %s"), item.name or ""), format(L:G("How many? (up to %d)"), most),
    function(text)
      local n = tonumber(text)
      if n == nil or n < 1 then
        return
      end
      merchant:Purchase(self.button, item, math.min(math.floor(n), most))
    end)
end

-- OnClick runs a click as Blizzard's merchant buttons do: a left click holding an item sells it, a
-- modified click Blizzard handles (a chat link, a preview) goes to it, Shift asks a quantity, a right
-- click buys; a buyback is bought back and a damaged item repaired on any click.
---@param mouse string
function buttonProto:OnClick(mouse)
  if mouse == "LeftButton" and CursorHasItem() then
    merchant:SellCursorItem()
    return
  end
  local link = self.item and self.item.link or (self.buyback and self.buyback.link) or (self.repair and self.repair.link)
  if IsModifiedClick() and link and HandleModifiedItemClick(link) then
    return
  end
  if self.mode == "buy" then
    if IsModifiedClick("SPLITSTACK") then
      if self.item.maxStack > 1 then
        self:askQuantity()
      end
      return
    end
    if mouse == "RightButton" then
      merchant:Purchase(self.button, self.item)
    end
  elseif self.mode == "buyback" then
    merchant:Buyback(self.buyback.index)
  elseif self.mode == "repair" then
    merchant:RepairOne(self.repair)
  end
end
