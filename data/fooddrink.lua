local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Async: AceModule
local async = addon:GetModule('Async')

-- FoodDrink is what BetterBags Next's Food & Drink bar eats and drinks (.claude/rules/food-drink.md): the food and the
-- drink in the bags that the player's rule picks, the highest item level or the lowest, read again whenever the bags
-- are read, never in combat (nothing on the bar can be eaten there) and once more when combat ends.
---@class FoodDrink: AceModule
---@field names table<string, NextFoodDrinkKind> The reference spells' names in the client's language, read once.
---@field picks table<NextFoodDrinkKind, NextFoodDrinkPick?>
---@field waiting boolean A read waits for combat to end.
local foodDrink = addon:NewModule('FoodDrink')

---@alias NextFoodDrinkKind "food"|"drink"|"both"

-- NextFoodDrinkPick is what a button of the bar shows: a stack in the bags, and how many of its item every stack holds.
---@class (exact) NextFoodDrinkPick
---@field data ItemData
---@field count number

-- The spells whose names say what an item restores, named by the client in its own language: Tough Jerky's Food,
-- Refreshing Spring Water's Drink (in every client's spell table) and Dragonflight's Food & Drink (retail's only: the
-- classic clients have no Food & Drink items). Measured in each client's item and spell tables (food-drink.md §1).
local REFERENCE = { { 433, "food" }, { 430, "drink" }, { 369166, "both" } }

-- A mage's conjured food is named Refreshment, as buff food is: every spell a "Conjured Mana ..." item casts in the
-- retail, Mists, TBC and Era tables (food-drink.md §1). It restores health and mana.
local CONJURED_REFRESHMENT = {
  [44166] = true, [61828] = true, [92726] = true, [92738] = true, [92798] = true, [92801] = true, [92804] = true,
  [95197] = true, [128701] = true, [167152] = true,
}

function foodDrink:Init()
  self.picks = {}
  self.waiting = false
  self.names = {}
  for _, ref in ipairs(REFERENCE) do
    local name = C_Spell.GetSpellName(ref[1])
    if name ~= nil and name ~= "" then
      self.names[name] = ref[2]
    end
  end
end

function foodDrink:OnEnable()
  events:RegisterMessage('items/RefreshBackpack/Done', function(ctx)
    self:Refresh(ctx)
  end)
  events:RegisterMessage('fooddrink/OptionsChanged', function(ctx)
    self:Refresh(ctx)
  end)
end

-- Kind says what an item in the bags restores, by the spell it casts when used: "food", "drink", "both", or nothing
-- (not a consumable, buff food, alcohol, no use spell, or its data has not loaded yet).
---@param data ItemData
---@return NextFoodDrinkKind?
function foodDrink:Kind(data)
  if data == nil or data.isItemEmpty then
    return nil
  end
  local info = data.itemInfo
  if info.traits == nil or info.classID ~= Enum.ItemClass.Consumable or info.itemLink == nil then
    return nil
  end
  local name, spellID = C_Item.GetItemSpell(info.itemLink)
  if spellID ~= nil and CONJURED_REFRESHMENT[spellID] then
    return "both"
  end
  return name ~= nil and self.names[name] or nil
end

-- better says whether a should be picked over b: by the rule's item level, then the lower item ID; of one item, the
-- smallest stack, then the first bag and slot.
---@param a ItemData
---@param b ItemData
---@param lowest boolean
---@return boolean
local function better(a, b, lowest)
  local ai, bi = a.itemInfo, b.itemInfo
  if ai.itemLevel ~= bi.itemLevel then
    if lowest then
      return ai.itemLevel < bi.itemLevel
    end
    return ai.itemLevel > bi.itemLevel
  end
  if ai.itemID ~= bi.itemID then
    return ai.itemID < bi.itemID
  end
  if ai.currentItemCount ~= bi.currentItemCount then
    return ai.currentItemCount < bi.currentItemCount
  end
  if a.bagid ~= b.bagid then
    return a.bagid < b.bagid
  end
  return a.slotid < b.slotid
end

-- read works out the picks from the bags as they are.
---@private
---@return table<NextFoodDrinkKind, NextFoodDrinkPick?>
function foodDrink:read()
  local slotInfo = items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK]
  local lowest = database:GetNextFoodDrinkOption("pick") == "lowest"
  local best, counts = {}, {}
  for _, data in pairs(slotInfo and slotInfo.itemsBySlotKey or {}) do
    local kind = self:Kind(data)
    if kind ~= nil then
      local id = data.itemInfo.itemID
      counts[id] = (counts[id] or 0) + data.itemInfo.currentItemCount
      for _, want in ipairs({ "food", "drink" }) do
        if (kind == want or kind == "both") and (best[want] == nil or better(data, best[want], lowest)) then
          best[want] = data
        end
      end
    end
  end
  local picks = {}
  for kind, data in pairs(best) do
    picks[kind] = { data = data, count = counts[data.itemInfo.itemID] }
  end
  return picks
end

-- same says whether two picks show the same: the same slot, item and count.
---@param a? NextFoodDrinkPick
---@param b? NextFoodDrinkPick
---@return boolean
local function same(a, b)
  if a == nil or b == nil then
    return a == b
  end
  return a.data.slotkey == b.data.slotkey and a.data.itemInfo.itemID == b.data.itemInfo.itemID and a.count == b.count
end

-- Refresh reads the picks again and tells the bar when one changed (fooddrink/Changed). In combat it changes nothing,
-- and one read waits for combat to end (asked: "if in combat, update after combat ends").
---@param ctx Context
function foodDrink:Refresh(ctx)
  if InCombatLockdown() then
    if not self.waiting then
      self.waiting = true
      async:AfterCombat(ctx, function(actx)
        self.waiting = false
        self:Refresh(actx)
      end)
    end
    return
  end
  local picks = self:read()
  local changed = not same(picks.food, self.picks.food) or not same(picks.drink, self.picks.drink)
  self.picks = picks
  if changed then
    events:SendMessage(ctx, 'fooddrink/Changed')
  end
end

-- Picks is what the bar shows: the food and the drink picked, each nothing when there is none.
---@return table<NextFoodDrinkKind, NextFoodDrinkPick?>
function foodDrink:Picks()
  return self.picks
end
