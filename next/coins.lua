local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextCoins puts the money a BetterBags Next footer shows on whole screen pixels (docs/next-pixel-perfect.md).
-- The backpack and the bank show the shared money frame (frames/money.lua), each its own instance: its coins
-- are lined up by their middles (RIGHT anchors), 13 units tall, as wide as their amounts, between pixels
-- wherever a unit is not a whole pixel. Fit lays that instance out again by corners in whole pixels, and
-- again after every update (the widths follow the amounts); the classic bags' instances are left alone.
---@class NextCoins: AceModule
local coins = addon:NewModule('NextCoins')

-- The money frame's size, a coin's size and the room between coins, as frames/money.lua makes them.
local WIDTH, HEIGHT, COIN, GAP = 128, 18, 13, 4

-- Style draws a money frame's amounts in a font of a Next theme's (Footer.CoinFont), out of the bags' theme's hands, or,
-- given none, in the shared money frame's own role. A font string keeps the width it was sized to through a font change
-- and cuts its text short past it (Blizzard resets it with a width of 0 and the text again, QuestLogTitleButton_Resize).
---@param m Money
---@param font? FontObject
function coins:Style(m, font)
  ---@class Sonata: AceModule
  local sonata = addon:GetModule('Sonata')
  for _, button in ipairs({ m.copperButton, m.silverButton, m.goldButton }) do
    if font ~= nil then
      sonata:ClearButtonTextRole(button)
      button:SetNormalFontObject(font)
    else
      sonata:SetButtonTextRole(button, "Money")
    end
    button:GetFontString():SetWidth(0)
  end
  m:Update()
end

-- Fit lays a money frame out on whole pixels now and after each of its updates, and gives it Place, which
-- lays it out again (its owner places the frame, then calls it: styleFooter).
---@param m Money
function coins:Fit(m)
  local function place()
    local frame = m.frame
    pixel:Size(frame, WIDTH, HEIGHT)
    local coin, gap = pixel:Length(frame, COIN), pixel:Snap(frame, GAP)
    local top = -pixel:Floor(frame, (frame:GetHeight() - coin) / 2)
    local previous
    for _, button in ipairs({ m.copperButton, m.silverButton, m.goldButton }) do
      button:SetSize(pixel:Ceil(button, button:GetTextWidth()) + coin, coin)
      button:ClearAllPoints()
      if previous == nil then
        button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, top)
      else
        button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -gap, 0)
      end
      local icon = button:GetNormalTexture()
      icon:ClearAllPoints()
      icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
      icon:SetSize(coin, coin)
      local text = button:GetFontString()
      local _, fontHeight = text:GetFont()
      text:ClearAllPoints()
      pixel:Point(text, "TOPRIGHT", button, "TOPRIGHT", -coin, -pixel:Floor(button, (coin - (fontHeight or 0)) / 2))
      previous = button
    end
  end
  local update = m.Update
  m.Update = function(instance)
    update(instance)
    place()
  end
  m.Place = place
  place()
end
