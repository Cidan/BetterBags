local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class FoodDrink: AceModule
local foodDrink = addon:GetModule('FoodDrink')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextItemFit: AceModule
local itemFit = addon:GetModule('NextItemFit')

---@class NextScreenCard: AceModule
local card = addon:GetModule('NextScreenCard')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class Texels: AceModule
local texels = addon:GetModule('Texels')

---@class PixelAudit: AceModule
local pixelAudit = addon:GetModule('PixelAudit')

-- NextFoodDrinkBar is BetterBags Next's Food & Drink bar (.claude/rules/food-drink.md): the food and the drink FoodDrink
-- picks, each on one of BetterBags' own item buttons pointed at its stack, on a card (NextScreenCard, the currency
-- tracker's) that stays on screen, the bags open or not. A right click eats or drinks it, as a right click on the item
-- in the bags does; a left click does nothing; a drag moves the bar. Switched on (Show Food & Drink Bar) it comes out of
-- the open backpack; dropped on the backpack it flies in and is switched off.
---@class NextFoodDrinkBar: AceModule
---@field instance? NextFoodDrinkBarFrame
local bar = addon:NewModule('NextFoodDrinkBar')

-- The kinds of button, in the bar's order.
bar.KINDS = { "food", "drink" }

---@class NextFoodDrinkBarFrame: NextScreenCardFrame
---@field panel NextBackpack The backpack it comes out of and is put away in.
---@field buttons table<NextFoodDrinkKind, Item> Made the first time there is one to show.
---@field order NextFoodDrinkKind[] The kinds shown, in order.
---@field shown table<NextFoodDrinkKind, NextFoodDrinkPick> What each kind shown shows.
---@field wasOut boolean Whether it was out when its options were last read: switched on, it comes out of the backpack.
local barProto = card:Extend({})
addon:GetModule('Perf'):RegisterPrototype(barProto, 'NextFoodDrinkBarFrame')

-- Create makes the bar the first time (for the backpack), showing what is picked already (the bags may switch to
-- BetterBags Next long after the picks were read), and returns it.
---@param ctx Context
---@param panel NextBackpack
---@return NextFoodDrinkBarFrame
function bar:Create(ctx, panel)
  if self.instance then
    self.instance.panel = panel
    return self.instance
  end
  ---@type NextFoodDrinkBarFrame
  local b = setmetatable({ panel = panel, buttons = {}, order = {}, shown = {} }, { __index = barProto })
  card:Build(b, "BetterBagsNextFoodDrinkBar")
  b.wasOut = b:IsOut()
  self.instance = b
  sonataNext:RegisterWidget(b)
  b:Watch()
  b:Style()
  pixelAudit:Register(b.frame, {
    title = L:G("Food & Drink Bar"), owners = { bar = b },
    skip = function() return b:MovingParts() end,
  })
  b:Draw(ctx)
  return b
end

-- Watch follows the picks, the options, the Size tab's scales and the screen (its card follows what hides it:
-- NextScreenCard).
---@private
function barProto:Watch()
  events:RegisterMessage('fooddrink/Changed', function(ctx)
    self:Draw(ctx)
  end)
  events:RegisterMessage('fooddrink/OptionsChanged', function(ctx)
    local out = self:IsOut()
    local emerge = out and not self.wasOut
    self.wasOut = out
    self:Reanchor()
    self:Style()
    self:Refresh(ctx)
    if emerge then
      self:Emerge(ctx)
    else
      self:UpdateShown(ctx)
    end
  end)
  -- Icon Scale sizes its buttons as the bags' (NextChain:ScalesChanged). The order listeners run in is not kept through a
  -- switch of designs, so it takes the scale itself before it lays out.
  events:RegisterMessage('next/ScalesChanged', function()
    style:SetIconScale(database:GetNextIconScale())
    self:LayOut()
  end)
  -- Its buttons on the new pixel grid; the card places itself again (NextScreenCard).
  for _, event in ipairs({ 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED' }) do
    events:RegisterEvent(event, function()
      self:LayOut()
    end)
  end
end

-- buttonFor is a kind's button, made the first time: BetterBags' item button, in the bar's Masque group, eaten with a
-- right click only (Blizzard's left click picks the item up), taking nothing dropped on it (Blizzard's OnReceiveDrag
-- puts what the cursor holds in the slot), a drag moving the bar. Its press and its drag's start make no context: a
-- context made in a mouse script can taint the protected use that follows (patterns-taint.md); a drag's end is followed
-- by none.
---@private
---@param ctx Context
---@param kind NextFoodDrinkKind
---@return Item
function barProto:buttonFor(ctx, kind)
  local item = self.buttons[kind]
  if item ~= nil then
    return item
  end
  item = itemFrame:Create(ctx)
  item.masqueGroup = "Food & Drink"
  item.frame:SetParent(self.frame)
  local button = item.button
  button:RegisterForClicks("RightButtonUp")
  button:SetScript("OnReceiveDrag", nil)
  button:SetScript("OnDragStart", function()
    self:PickUp()
  end)
  button:SetScript("OnDragStop", function()
    self:Drop(context:New('NextFoodDrinkBarDrop'))
  end)
  button:HookScript("OnEnter", function()
    self:SetHovered(true)
  end)
  self.buttons[kind] = item
  return item
end

-- Refresh points each kind's button at its pick's stack, and hides a kind with no pick, at once (nothing to click on a
-- slot that changed); then it lays them out.
---@param ctx Context
function barProto:Refresh(ctx)
  local picks = foodDrink:Picks()
  local order, shown = {}, {}
  for _, kind in ipairs(bar.KINDS) do
    local pick = picks[kind]
    if pick ~= nil then
      local item = self:buttonFor(ctx, kind)
      item:SetSlot(ctx, pick.data.bagid, pick.data.slotid)
      table.insert(order, kind)
      shown[kind] = pick
    elseif self.buttons[kind] ~= nil then
      self.buttons[kind].frame:Hide()
    end
  end
  self.order, self.shown = order, shown
  self:LayOut()
end

---@param ctx Context
function barProto:Draw(ctx)
  self:Refresh(ctx)
  self:UpdateShown(ctx)
end

-- LayOut sizes, draws and places the buttons in a row or a column, each the theme's item size (style.ICON) and its gap
-- apart, the card Pad round them, on whole pixels; buttons that moved glide there (Motion) while it shows. Each is
-- sized before it is drawn: Masque sizes a skin to the button as the draw's item/Updated skins it. A pick is drawn as a
-- row of the item list is (no new-item glow, no upgrade arrow), with the count of every stack of it, never dimmed by a
-- search in the bags. Held or coming out, it is at the lift's scale, whose grid is not its own: it lays out once at
-- rest (layOutLater, NextScreenCard).
function barProto:LayOut()
  local frame = self.frame
  if self.held ~= nil or self.emerging ~= nil then
    self.layOutLater = true
    return
  end
  self.layOutLater = nil
  frame:SetScale(self:Scale())
  local pad = pixel:Length(frame, self:Theme().Pad)
  local size = pixel:Length(frame, style.ICON)
  local gap = pixel:Length(frame, style.GAP)
  local row = self:Layout() ~= "column"
  local ctx
  local visible = frame:IsVisible()
  if visible then
    motion:BeginPass(frame, style.Time.Interaction, style.StopMotion)
  end
  local offset = pad
  for _, kind in ipairs(self.order) do
    local item, pick = self.buttons[kind], self.shown[kind]
    ctx = ctx or context:New('NextFoodDrinkBar_LayOut')
    if math.abs(item.frame:GetWidth() - size) > 0.001 then
      item:SetSize(ctx, size, size)
    end
    item:SetStaticItemFromData(ctx, pick.data)
    local decoration = item:GetDecoration(ctx)
    SetItemButtonCount(decoration, pick.count)
    if decoration.SetMatchesSearch then
      decoration:SetMatchesSearch(true)
    end
    itemFit:Fit(ctx, decoration, { item.ilvlText }, item)
    if row then
      motion:Place(item.frame, frame, offset, -pad)
    else
      motion:Place(item.frame, frame, pad, -offset)
    end
    item.frame:Show()
    offset = offset + size + gap
  end
  if visible then
    motion:EndPass()
  end
  local length = #self.order > 0 and offset - gap + pad or pad * 2
  if row then
    pixel:Size(frame, length, pad + size + pad)
  else
    pixel:Size(frame, pad + size + pad, length)
  end
  texels:Unsharpen(frame)
end

-- The card's (NextScreenCard): the Food & Drink page's options, where it was left, the backpack.

---@param name NextFoodDrinkOption
---@return any
function barProto:Option(name)
  return database:GetNextFoodDrinkOption(name)
end

---@return boolean out, number? x, number? y
function barProto:Saved()
  return database:GetNextFoodDrinkBar()
end

-- Save keeps whether it is out and where; put away (a drop on the backpack), it is switched off.
---@param out boolean
---@param x? number
---@param y? number
function barProto:Save(out, x, y)
  database:SetNextFoodDrinkBar(out, x, y)
  self.wasOut = out
end

---@return NextBackpack
function barProto:Home()
  return self.panel
end

-- Something to eat or drink shows on it.
---@return boolean
function barProto:Wants()
  return #self.order > 0
end

-- OpenSettings opens the settings window on the Food & Drink page.
function barProto:OpenSettings()
  addon:GetModule('NextSettings'):Open("fooddrink", "display")
end

-- MovingParts are what moves by nature (next-pixel-perfect.md): sparkles.
---@return table<table, boolean>
function barProto:MovingParts()
  return { [self.fx] = true, [self.floats] = true }
end
