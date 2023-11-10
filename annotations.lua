---@class ItemButton: Button
local itemButton = {}

---@param bagid number
function itemButton:SetBagID(bagid) end

---@param hasItem boolean
function itemButton:UpdateCooldown(hasItem) end