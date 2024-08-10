local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class movementFlow: AceModule
local movementFlow = addon:NewModule('MovementFlow')

---@return boolean
function movementFlow:AtSendMail()
  local frame = _G["SendMailFrame"];
  return frame ~= nil and frame:IsVisible()
end

---@return boolean
function movementFlow:AtTradeWindow()
  local frame = _G["TradeFrame"];
  return frame ~= nil and frame:IsVisible()
end

---@return boolean
function movementFlow:AtNPCShopWindow()
  local frame = _G["MerchantFrame"];
  return frame ~= nil and frame:IsVisible()
end

---@return MovementFlow
function movementFlow:GetMovementFlow()
  if addon.atBank then return const.MOVEMENT_FLOW.BANK end
  if movementFlow:AtSendMail() then return const.MOVEMENT_FLOW.SENDMAIL end
  if movementFlow:AtTradeWindow() then return const.MOVEMENT_FLOW.TRADE end
  if movementFlow:AtNPCShopWindow() then return const.MOVEMENT_FLOW.NPCSHOP end
  return const.MOVEMENT_FLOW.UNDEFINED
end
