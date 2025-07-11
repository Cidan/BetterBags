

---@type BetterBags
local addon = GetBetterBags()

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class MovementFlow: AceModule
local movementFlow = addon:NewModule('MovementFlow')

---@return boolean
function movementFlow:AtSendMail()
  local frame = _G["SendMailFrame"] --[[@as Frame]]
  return frame ~= nil and frame:IsVisible()
end

---@return boolean
function movementFlow:AtTradeWindow()
  local frame = _G["TradeFrame"] --[[@as Frame]]
  return frame ~= nil and frame:IsVisible()
end

---@return boolean
function movementFlow:AtNPCShopWindow()
  local frame = _G["MerchantFrame"] --[[@as Frame]]
  return frame ~= nil and frame:IsVisible()
end

---@return MovementFlowType
function movementFlow:GetMovementFlow()
  if addon.atBank and addon.Bags.Bank.bankTab >= const.BANK_TAB.ACCOUNT_BANK_1 then return const.MOVEMENT_FLOW.WARBANK end
  if addon.atBank and addon.Bags.Bank.bankTab == const.BANK_TAB.REAGENT then return const.MOVEMENT_FLOW.REAGENT end
  if addon.atBank then return const.MOVEMENT_FLOW.BANK end
  if movementFlow:AtSendMail() then return const.MOVEMENT_FLOW.SENDMAIL end
  if movementFlow:AtTradeWindow() then return const.MOVEMENT_FLOW.TRADE end
  if movementFlow:AtNPCShopWindow() then return const.MOVEMENT_FLOW.NPCSHOP end
  return const.MOVEMENT_FLOW.UNDEFINED
end
