---@meta

---@class ItemButton: Button
---@field bagID number
---@field NewItemTexture Texture
---@field minDisplayCount number
---@field NormalTexture Texture
---@field PushedTexture Texture
---@field HighlightTexture Texture
---@field BattlepayItemTexture Texture
---@field IconBorder Texture
---@field UpgradeIcon Texture
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

---@class Button
local Button = {}

function Button:RegisterForClicks(...) end

---@return Texture
function itemButton:GetHighlightTexture() end

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
function Masque:Group(name, group) end

---@class LibWindow-1.1
Window = {}

function Window.RegisterConfig(frame, config) end
function Window.SavePosition(frame) end
function Window.RestorePosition(frame) end

---@class ContainerFrameCombinedBags: Frame
ContainerFrameCombinedBags = {}

---@class BankFrame: Frame
BankFrame = {}

---@class BagsBar: Frame
BagsBar = {}

---@class MainMenuBarBackpackButton: Button
MainMenuBarBackpackButton = {}

---@class BagBarExpandToggle: Button
BagBarExpandToggle = {}

---@class BetterBagsDebugListButton: Button
---@field RowNumber FontString
---@field Category FontString
---@field Message FontString

---@class ScrollingFlatPanelTemplate: Frame
---@field ScrollBox WowScrollBox
---@field ScrollBar MinimalScrollBar

---@class DLAPI
DLAPI = {}

function DLAPI.RegisterFormat(name, format) end
function DLAPI.SetFormat(name, format) end
function DLAPI.DebugLog(category, message) end

---@param createFunc fun(): any
---@param resetFunc fun(any)
---@return ObjectPool
function CreateObjectPool(createFunc, resetFunc) end

---@class ObjectPool
local ObjectPool = {}
---@return any
function ObjectPool:Acquire() end
function ObjectPool:Release(o) end
function ObjectPool:SetResetDisallowedIfNew(disallow) end

---@class LibUIDropDownMenu-4.0
local LibUIDropDownMenu = {}

---@param name string
---@param parent Frame
---@return frame
function LibUIDropDownMenu:Create_UIDropDownMenu(name, parent) end
function LibUIDropDownMenu:EasyMenu_Initialize(frame, level, menuList, anchor, x, y, displayMode, autoHideDelay) end
function LibUIDropDownMenu:EasyMenu(menuList, frame, anchor, x, y, displayMode, autoHideDelay) end
function LibUIDropDownMenu:HideDropDownMenu(level) end

---@class SearchBox: EditBox
---@field Instructions FontString
local SearchBox = {}

---@class BetterBagsBagPortraitTemplate
---@field Bg Texture
---@field PortraitContainer Frame
---@field CloseButton Button
---@field SearchBox SearchBox
local BetterBagsBagPortraitTemplate = {}

function BetterBagsBagPortraitTemplate:SetPortraitToAsset(texture) end
function BetterBagsBagPortraitTemplate:SetPortraitTextureSizeAndOffset(size, offsetX, offsetY) end
function BetterBagsBagPortraitTemplate:SetTitle(title) end

---@class BetterBagsClassicBagPortrait
---@field Inset Texture
---@field PortraitFrame Texture
---@field CloseButton Button
---@field SearchBox SearchBox
local BetterBagsClassicBagPortrait = {}

---@class FontString
local FontString = {}
function FontString:SetScript(event, func) end

---@class WowScrollBox: Frame
local WowScrollBox = {}
function WowScrollBox:SetInterpolateScroll(interpolate) end
function WowScrollBox:ScrollInDirection(percent, direction) end
function WowScrollBox:FullUpdate() end
function WowScrollBox:OnMouseWheel(delta) end
function WowScrollBox:ScrollToEnd() end
---@return Texture
function WowScrollBox:GetUpperShadowTexture() end
---@return Texture
function WowScrollBox:GetLowerShadowTexture() end
function WowScrollBox:SetDataProvider(provider) end

---@class Frame
---@field scrollable boolean
local frameProto = {}

---@class MinimalScrollBar: Frame
local MinimalScrollBar = {}
function MinimalScrollBar:SetInterpolateScroll(interpolate) end

---@class EventFrame
local EventFrame = {}

---@param location number
---@return boolean, boolean, boolean, boolean, number, number
function EquipmentManager_UnpackLocation(location) end

-- ItemInfo is the information about an item that is returned by GetItemInfo.
---@class (exact) ExpandedItemInfo
---@field itemID number
---@field itemGUID string
---@field itemName string
---@field itemLink string
---@field itemQuality Enum.ItemQuality
---@field itemLevel number
---@field itemMinLevel number
---@field itemType string
---@field itemSubType string
---@field itemStackCount number
---@field itemEquipLoc string
---@field itemTexture number
---@field sellPrice number
---@field classID Enum.ItemClass
---@field subclassID number
---@field bindType Enum.ItemBind
---@field expacID ExpansionType
---@field setID number
---@field isCraftingReagent boolean
---@field effectiveIlvl number
---@field isPreview boolean
---@field baseIlvl number
---@field itemIcon? number
---@field isBound boolean
---@field isLocked boolean
---@field isNewItem boolean
---@field currentItemCount number
---@field category string
---@field currentItemLevel number
---@field equipmentSet string|nil

---@return Frame
function CreateScrollBoxLinearView() end

---@param itemLink string
---@return number, boolean, number
function GetDetailedItemLevelInfo(itemLink) end

_G.LE_EXPANSION_CLASSIC = 0
_G.LE_EXPANSION_BURNING_CRUSADE = 1
_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2
_G.LE_EXPANSION_CATACLYSM = 3
_G.LE_EXPANSION_MISTS_OF_PANDARIA = 4
_G.LE_EXPANSION_WARLORDS_OF_DRAENOR = 5
_G.LE_EXPANSION_LEGION = 6
_G.LE_EXPANSION_BATTLE_FOR_AZEROTH = 7
_G.LE_EXPANSION_SHADOWLANDS = 8
_G.LE_EXPANSION_DRAGONFLIGHT = 9

-- Write out all the expansion names.
_G.EXPANSION_NAME0 = "Classic"
_G.EXPANSION_NAME1 = "The Burning Crusade"
_G.EXPANSION_NAME2 = "Wrath of the Lich King"
_G.EXPANSION_NAME3 = "Cataclysm"
_G.EXPANSION_NAME4 = "Mists of Pandaria"
_G.EXPANSION_NAME5 = "Warlords of Draenor"
_G.EXPANSION_NAME6 = "Legion"
_G.EXPANSION_NAME7 = "Battle for Azeroth"
_G.EXPANSION_NAME8 = "Shadowlands"
_G.EXPANSION_NAME9 = "Dragonflight"

_G.BANK_BAG_PURCHASE = "Purchasable Bag Slot"
_G.COSTS_LABEL = "Cost:"


---@class AceConfig.OptionsTable
---@field values? table<any, any>
---[Documentation](http://www.wowace.com/addons/ace3/pages/ace-config-3-0-options-tables/)
local OptionsTable = {}

---@class AceItemList
---@field type string
---@field frame Frame
---@field section Section
---@field parent AceGUIFrame
local AceItemList = {}

---@param values CustomCategoryFilter
function AceItemList:SetList(values) end

---@class AceGUILabel
---@field frame Frame

---@class MoneyFrameButtonTemplate

-- Legacy UpdateCooldown function for Classic.
---@param id number
---@param button Button
function ContainerFrame_UpdateCooldown(id, button) end

----
-- ConsolePort annotations
----

ConsolePort = {}

---@param frame Frame
function ConsolePort:AddInterfaceCursorFrame(frame) end


--- Pawn Globals

-- PawnIsContainerItemAnUpgrade returns whether the item in the given bag and slot is an upgrade.
---@param bag number
---@param slot number
function PawnIsContainerItemAnUpgrade(bag, slot) end

PawnVersion = _G['PawnVersion'] --[[@as number]]
PawnGetItemData = _G['PawnGetItemData'] --[[@as fun(itemLink: string): table]]
PawnIsItemAnUpgrade = _G['PawnIsItemAnUpgrade'] --[[@as fun(itemData: table): boolean]]