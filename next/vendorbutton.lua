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

-- NextVendorButton is a button of BetterBags Next's vendor (next.md §10): an item for sale, a
-- buyback, or an item to repair. It shows the icon, stack size, stock, quality, the quest mark, what
-- makes it unusable or sold out (as Blizzard's MerchantFrame_UpdateMerchantInfo tints them), and its
-- price under the icon; its tooltip is Blizzard's; its clicks buy (NextMerchant:Purchase, through
-- Blizzard's confirmations), ask a quantity (our own dialog, as CompactVendor has its own), buy
-- back or repair, the way Blizzard's merchant item buttons do. A left click never puts the item on
-- the cursor, so it cannot be bought by dropping it on a bag slot past Blizzard's confirmations.
-- The buttons are plain Buttons: nothing they call is protected.
---@class NextVendorButton: AceModule
local vendorButton = addon:NewModule('NextVendorButton')

local COIN_ICONS = {
  "Interface\\MoneyFrame\\UI-GoldIcon",
  "Interface\\MoneyFrame\\UI-SilverIcon",
  "Interface\\MoneyFrame\\UI-CopperIcon",
}

---@alias NextVendorButtonMode "buy"|"buyback"|"repair"

---@class NextVendorButtonFrame
---@field key string What the canvas knows it by.
---@field frame Frame The holder the canvas places: the button and its price under it.
---@field button Button The square button: it takes the clicks, and Masque skins it.
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

-- markup is a texture in text, at the size of the price's font.
---@param texture number|string
---@return string
local function markup(texture)
  return "|T" .. texture .. ":12:12:2:0|t"
end

-- PriceText is what a button shows of a price, short enough to sit under its icon: the first other
-- cost (with "+" when it costs more than that), else the largest coin of the gold. The tooltip shows
-- all of it.
---@param price number
---@param costs NextVendorCost[]
---@return string
function vendorButton:PriceText(price, costs)
  local first = costs[1]
  if first then
    local more = (#costs > 1 or price > 0) and "+" or ""
    return first.value .. markup(first.texture) .. more
  end
  if price <= 0 then
    return ""
  end
  local gold, silver = math.floor(price / 10000), math.floor(price / 100) % 100
  if gold > 0 then
    return gold .. markup(COIN_ICONS[1])
  end
  if silver > 0 then
    return silver .. markup(COIN_ICONS[2])
  end
  return (price % 100) .. markup(COIN_ICONS[3])
end

---@return NextVendorButtonFrame
-- newButton makes a button: a holder the canvas places, as tall as the icon and its price, and in
-- it the square button that takes the clicks and that Masque skins. Masque sizes a skin to the
-- button it skins (Core.lua UpdateScale), and finds an item button's parts by these names
-- (Masque 12.1.0 Skins/Regions.lua, Item): icon, IconBorder, Count.
---@return NextVendorButtonFrame
local function newButton()
  local frame = CreateFrame("Frame")
  local button = CreateFrame("Button", nil, frame)
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
  count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
  button.Count = count
  local stock = button:CreateFontString(nil, "OVERLAY")
  stock:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
  local price = frame:CreateFontString(nil, "OVERLAY")
  price:SetPoint("TOP", button, "BOTTOM", 0, -1)
  ---@type NextVendorButtonFrame
  local b = setmetatable({
    key = "", frame = frame, button = button, icon = icon, border = border, quest = quest, count = count,
    stock = stock, price = price, durability = durability, highlight = highlight, affordable = true,
  }, { __index = buttonProto })
  b:Style()
  button:SetScript("OnEnter", function() b:OnEnter() end)
  button:SetScript("OnLeave", function() b:OnLeave() end)
  addon.SetScript(button, "OnClick", function(_, _, mouse) b:OnClick(mouse) end)
  return b
end

-- Style draws the button from the Next theme (Layout, Vendor): its size and the room for its price,
-- its highlight, quest mark and durability bar, its stack, stock and price in their roles.
function buttonProto:Style()
  local V = style.Theme.Vendor
  self.frame:SetSize(style.ICON, style.ICON + style.VENDOR_PRICE)
  self.button:SetSize(style.ICON, style.ICON)
  self.icon:SetSize(style.ICON, style.ICON)
  self.highlight:SetColorTexture(style:RGBA(V.Highlight))
  self.quest:SetTexture(style:TexturePath(V.QuestMark))
  if V.QualityBorder then
    self.border:SetTexture(style:TexturePath(V.QualityBorder))
  else
    self.border:Hide()
  end
  self.durability:SetHeight(V.DurabilityHeight)
  style:SetFont(self.count, V.StackFont)
  style:SetFont(self.stock, V.StackFont)
  style:SetFont(self.price, self.affordable and V.PriceFont or V.UnaffordableFont)
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

-- SetBuy shows an item for sale.
---@param item NextVendorItem
function buttonProto:SetBuy(item)
  self.mode, self.item = "buy", item
  self.key = "vendor:" .. item.index
  self:reset(item.texture, item.quality)
  self:setCount(item.stackCount)
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
  self.price:SetText(vendorButton:PriceText(item.price, item.costs))
end

-- setAffordable writes the price in the theme's role for whether the player can afford it.
---@private
---@param affordable boolean
function buttonProto:setAffordable(affordable)
  self.affordable = affordable
  local V = style.Theme.Vendor
  style:SetFont(self.price, affordable and V.PriceFont or V.UnaffordableFont)
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
  self.durability:SetWidth(math.max(1, style.ICON * fraction))
  self.durability:SetVertexColor(1 - fraction, fraction, 0.1, 1)
  self.durability:Show()
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
    GameTooltip:AddLine(L:G("Price: ") .. C_CurrencyInfo.GetCoinTextureString(price), 1, 1, 1)
  end
  for _, cost in ipairs(costs) do
    GameTooltip:AddLine("|T" .. cost.texture .. ":0|t " .. cost.value .. " " .. (cost.currencyName or cost.link or ""), 1, 1, 1)
  end
end

-- OnEnter shows Blizzard's tooltip for what the button shows, with its price and what clicking
-- does, and the cursor Blizzard's merchant shows over it.
function buttonProto:OnEnter()
  GameTooltip:SetOwner(self.button, "ANCHOR_RIGHT")
  if self.mode == "buy" then
    local item = self.item
    GameTooltip:SetMerchantItem(item.index)
    if GameTooltip_ShowCompareItem then
      GameTooltip_ShowCompareItem(GameTooltip)
    end
    GameTooltip:AddLine(" ")
    addCosts(item.price, item.costs)
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
    GameTooltip:AddLine(L:G("Repair: ") .. C_CurrencyInfo.GetCoinTextureString(entry.cost), 1, 1, 1)
    GameTooltip:AddLine(L:G("Click to repair"), 0.8, 0.8, 0.8)
  end
  GameTooltip:Show()
end

function buttonProto:OnLeave()
  GameTooltip:Hide()
  ResetCursor()
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

-- OnClick runs a click as Blizzard's merchant buttons do: a modified click Blizzard handles (a
-- chat link, a preview) goes to it, Shift asks a quantity, a right click buys; a buyback is bought
-- back and a damaged item repaired on any click.
---@param mouse string
function buttonProto:OnClick(mouse)
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
