---@class ItemButton: Button
---@field bagID number
local itemButton = {}

---@param bagid number
function itemButton:SetBagID(bagid) end

---@param hasItem string|number|boolean
function itemButton:UpdateCooldown(hasItem) end

---@param texture string|number
function itemButton:SetItemButtonTexture(texture) end

---@param hasItem string|number|boolean
function itemButton:SetHasItem(hasItem) end

function itemButton:UpdateExtended() end

function itemButton:UpdateQuestItem(isQuestItem, questID, isActive) end

function itemButton:UpdateNewItem(quality) end

function itemButton:UpdateJunkItem(quality, noValue) end

function itemButton:UpdateItemContextMatching() end

function itemButton:SetReadable(readable) end

function itemButton:CheckUpdateTooltip(tooltipOwner) end

function itemButton:SetMatchesSearch(matchesSearch) end

---@class ContinuableContainer 
ContinuableContainer = {}

---@class MasqueGroup
MasqueGroup = {}

function MasqueGroup:AddButton() end

---@class Masque
Masque = {}

---@param name string
---@param group string
---@return MasqueGroup
function Masque:Group(name, group) return {} end