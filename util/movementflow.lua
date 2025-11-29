local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

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
  -- Fix for retail WoW: use Enum.BagIndex values directly
  local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
  -- Reagent bank was removed in TWW 11.2 for retail, only exists in classic/era
  local reagentBank = not addon.isRetail and const.BANK_TAB.REAGENT or nil

  -- Only check bank-specific flows if Bank bag is enabled
  if addon.Bags.Bank and addon.atBank and addon.Bags.Bank.bankTab then
    if accountBankStart and addon.Bags.Bank.bankTab >= accountBankStart then
      return const.MOVEMENT_FLOW.WARBANK
    end
    if reagentBank and addon.Bags.Bank.bankTab == reagentBank then
      return const.MOVEMENT_FLOW.REAGENT
    end
  end
  if addon.atBank then return const.MOVEMENT_FLOW.BANK end
  if movementFlow:AtSendMail() then return const.MOVEMENT_FLOW.SENDMAIL end
  if movementFlow:AtTradeWindow() then return const.MOVEMENT_FLOW.TRADE end
  if movementFlow:AtNPCShopWindow() then return const.MOVEMENT_FLOW.NPCSHOP end
  return const.MOVEMENT_FLOW.UNDEFINED
end
