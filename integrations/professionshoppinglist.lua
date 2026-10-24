local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- ProfessionShoppingList is the Profession Shopping List integration (Slackluster's addon,
-- .claude/rules/profession-shopping-list.md): what its list still needs, and buying it from the open
-- merchant, for BetterBags Next's vendor. It is there only while Profession Shopping List has both
-- functions BetterBags calls, ProfessionShoppingList:GetShoppingList() and :BuyFromMerchant() (asked:
-- "if PSL (and this function, because it's new) isn't available, don't show this integration/don't
-- try to call this"); without them nothing of it shows and nothing is called.
---@class ProfessionShoppingListIntegration: AceModule
---@field _watching? boolean It listens to the list's changes.
local shoppingList = addon:NewModule('ProfessionShoppingList')

---@class (exact) ProfessionShoppingListReagent
---@field required number How many the tracked recipes need.
---@field owned number How many the player has, as Profession Shopping List counts them.

-- api returns Profession Shopping List's API when it has both functions BetterBags calls, else nil.
---@return {GetShoppingList: fun(self): table<number, ProfessionShoppingListReagent>, BuyFromMerchant: fun(self)}?
local function api()
  local psl = _G.ProfessionShoppingList
  if type(psl) == "table" and type(psl.GetShoppingList) == "function" and type(psl.BuyFromMerchant) == "function" then
    return psl
  end
  return nil
end

-- Available says whether Profession Shopping List is loaded with both functions BetterBags calls.
---@return boolean
function shoppingList:Available()
  return api() ~= nil
end

-- Needs returns what the list still needs, by item ID: what the tracked recipes need less what the player
-- has, only for what it needs at least one more of. BuyFromMerchant buys exactly that.
---@return table<number, number>
function shoppingList:Needs()
  local needs = {}
  local psl = api()
  if psl == nil then
    return needs
  end
  for itemID, reagent in pairs(psl:GetShoppingList()) do
    local missing = reagent.required - reagent.owned
    if missing >= 1 then
      needs[itemID] = missing
    end
  end
  return needs
end

-- Buy buys what the list needs from the open merchant (ProfessionShoppingList:BuyFromMerchant). It
-- returns whether it asked.
---@return boolean
function shoppingList:Buy()
  local psl = api()
  if psl == nil then
    return false
  end
  psl:BuyFromMerchant()
  return true
end

-- Watch sends shoppingList/Changed whenever the tracked recipes change (Profession Shopping List's
-- ProfessionShoppingList.OnTrackedRecipesChanged), once Profession Shopping List is there. It returns
-- whether it listens.
---@return boolean
function shoppingList:Watch()
  if self._watching then
    return true
  end
  if api() == nil then
    return false
  end
  EventRegistry:RegisterCallback("ProfessionShoppingList.OnTrackedRecipesChanged", function()
    events:SendMessage(context:New('ProfessionShoppingList_Changed'), 'shoppingList/Changed')
  end, self)
  self._watching = true
  print("BetterBags: Profession Shopping List integration enabled.")
  return true
end

-- OnEnable listens to the list, or waits for Profession Shopping List to load (it may load after
-- BetterBags enables its modules) and then says the list is there.
function shoppingList:OnEnable()
  if self:Watch() then
    return
  end
  events:RegisterEvent("ADDON_LOADED", function(ctx)
    if self._watching then
      return
    end
    if self:Watch() then
      events:SendMessage(ctx, 'shoppingList/Changed')
    end
  end)
end
