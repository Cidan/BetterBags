---@meta

---@class ItemButton: Button
---@field bagID number
---@field NewItemTexture Texture
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

function itemButton:SetItemButtonQuality(quality) end

function itemButton:HasItem() end

---@class ContinuableContainer 
ContinuableContainer = {}

---@class MasqueGroup
MasqueGroup = {}

function MasqueGroup:AddButton(group, button) end
function MasqueGroup:RemoveButton(group, button) end

---@class Masque
Masque = {}

---@param name string
---@param group string
---@return MasqueGroup
function Masque:Group(name, group) return {} end

---@class LibWindow-1.1
Window = {}

function Window.RegisterConfig(frame, config) end
function Window.SavePosition(frame) end
function Window.RestorePosition(frame) end

---@class ContainerFrameCombinedBags: Frame
ContainerFrameCombinedBags = {}

---@class BankFrame: Frame
BankFrame = {}

---@class DLAPI
DLAPI = {}

function DLAPI.RegisterFormat(name, format) end
function DLAPI.SetFormat(name, format) end
function DLAPI.DebugLog(category, message) end

---@return ObjectPool
function CreateObjectPool(createFunc, resetFunc) end

---@class ObjectPool
local ObjectPool = {}
---@return any
function ObjectPool:Acquire() end
function ObjectPool:Release(o) end
function ObjectPool:SetResetDisallowedIfNew() end

---@class LibUIDropDownMenu-4.0
local LibUIDropDownMenu = {}
---@return frame
function LibUIDropDownMenu:Create_UIDropDownMenu(name, parent) end
function LibUIDropDownMenu:EasyMenu_Initialize(frame, level, menuList, anchor, x, y, displayMode, autoHideDelay) end
function LibUIDropDownMenu:EasyMenu(menuList, frame, anchor, x, y, displayMode, autoHideDelay) end

---@class BetterBagsBagPortraitTemplate
---@field Bg Texture
local BetterBagsBagPortraitTemplate = {}

function BetterBagsBagPortraitTemplate:SetPortraitToAsset(texture) end
function BetterBagsBagPortraitTemplate:SetPortraitTextureSizeAndOffset(size, offsetX, offsetY) end
function BetterBagsBagPortraitTemplate:SetTitle(title) end