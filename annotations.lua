---@meta

---@class AnimationGroup
---@field callback fun()

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
---@field flashAnim AnimationGroup
---@field newitemglowAnim AnimationGroup
---@field IconOverlay Texture
---@field GetItemContextMatchResult function
---@field ItemContextOverlay Texture
---@field Cooldown Cooldown
---@field UpdateTooltip function
---@field LockTexture Texture
---@field IconQuestTexture Texture
---@field IconTexture Texture
---@field ItemSlotBackground Texture
---@field backdrop Frame
---@field searchOverlay Texture
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

---@return Enum.BagIndex
function itemButton:GetBagID() end

---@class Button
---@field isSkinned boolean
local Button = {}

function Button:RegisterForClicks(...) end

---@return Texture
function itemButton:GetHighlightTexture() end

---@class ContinuableContainer 
ContinuableContainer = {}

---@class MasqueGroup
---@field Buttons ItemButton[]
MasqueGroup = {}

function MasqueGroup:AddButton(group, button) end
function MasqueGroup:RemoveButton(group, button) end
function MasqueGroup:ReSkin(boolean) end
function MasqueGroup:RegisterCallback(func, obj) end
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


---@class ColorPickerFrame: Frame
ColorPickerFrame = {}

function ColorPickerFrame:SetupColorPickerAndShow(opts) end

---@return number, number, number
function ColorPickerFrame:GetColorRGB() end

---@return number
function ColorPickerFrame:GetColorAlpha() end


---@class DropdownButton: Button
local dropdownButton = {}

---@param setupFunction fun(dropdown: DropdownButton, root: table)
function dropdownButton:SetupMenu(setupFunction) end

function dropdownButton:GenerateMenu() end

function dropdownButton:Update() end

---@class BetterBagsDebugListButton: Button
---@field RowNumber FontString
---@field Category FontString
---@field Message FontString

---@class ScrollingFlatPanelTemplate: Frame
---@field ScrollBox WowScrollBox
---@field ScrollBar MinimalScrollBar
---@field ClosePanelButton Button

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

---@class ButtonFrameTemplate: Frame
---@field Bg Texture
---@field PortraitContainer PortraitContainer
---@field CloseButton Button
---@field TitleContainer TitleContainer

---@class BetterBagsBagPortraitTemplate
---@field Bg Texture
---@field PortraitContainer PortraitContainer
---@field CloseButton Button
---@field SearchBox SearchBox
---@field Backdrop BackdropTemplate
---@field NineSlice NineSlicePanelTemplate
---@field TopTileStreaks Texture
---@field TitleContainer TitleContainer
---@field Owner Bag
local BetterBagsBagPortraitTemplate = {}
---@return string
function BetterBagsBagPortraitTemplate:GetName() end

---@class PortraitContainer: Frame
---@field portrait Texture
---@field CircleMask MaskTexture

---@class TitleContainer: Frame
---@field TitleText FontString

---@class BetterBagsBagDefaultPanelTemplate
---@field Bg Texture
---@field CloseButton Button
---@field Backdrop BackdropTemplate
---@field NineSlice NineSlicePanelTemplate
---@field TopTileStreaks Texture
local BetterBagsBagDefaultPanelTemplate = {}

---@class NineSlicePanelTemplate: Frame
local NineSlicePanelTemplate = {}
function NineSlicePanelMixin:GetFrameLayoutTextureKit() end

---@class BackdropTemplate
local BackdropTemplate = {}
function BackdropTemplate:Show() end
function BackdropTemplate:Hide() end

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
function WowScrollBox:FullUpdate(const) end
function WowScrollBox:OnMouseWheel(delta) end
function WowScrollBox:ScrollToEnd() end
---@return Texture
function WowScrollBox:GetUpperShadowTexture() end
---@return Texture
function WowScrollBox:GetLowerShadowTexture() end
function WowScrollBox:SetDataProvider(provider) end
function WowScrollBox:ScrollToOffset(offset) end
function WowScrollBox:RegisterCallback(event, callback) end
---@return number
function WowScrollBox:GetDerivedScrollOffset() end
---@return number
function WowScrollBox:GetDerivedScrollRange() end
---@param percent number
function WowScrollBox:SetScrollPercentage(percent) end

---@class InputScrollFrameTemplate: Frame
---@field EditBox EditBox

---@class DataProviderMixin: CallbackRegistryMixin
local DataProviderMixin = {}
function DataProviderMixin:Enumerate(indexBegin, indexEnd) end
function DataProviderMixin:Insert(...) end
function DataProviderMixin:InsertTable(tbl) end
function DataProviderMixin:InsertAtIndex(elementData, insertIndex) end
---@return number
function DataProviderMixin:GetSize() end
---@param elementData table
---@return number
function DataProviderMixin:FindIndex(elementData) end
function DataProviderMixin:RemoveIndex(index) end
function DataProviderMixin:Flush() end
---@param predicate fun(elementData: table<any, any>): boolean
---@return boolean
function DataProviderMixin:ContainsByPredicate(predicate) end
---@return fun(): number, table
function DataProviderMixin:EnumerateEntireRange() end
---@return table[]
function DataProviderMixin:GetCollection() end
---@param index number
---@return table
function DataProviderMixin:Find(index) end
---@param elementData table
---@param newIndex number
function DataProviderMixin:MoveElementDataToIndex(elementData, newIndex) end
---@return number
function DataProviderMixin:GetSize() end
function DataProviderMixin:Remove(...) end

---@class ScrollBoxDragBehavior
local ScrollBoxDragBehavior = {}
---@param reorderable boolean
function ScrollBoxDragBehavior:SetReorderable(reorderable) end
function ScrollBoxDragBehavior:SetDropPredicate(fn) end
function ScrollBoxDragBehavior:SetDragPredicate(fn) end
function ScrollBoxDragBehavior:SetFinalizeDrop(fn) end

---@class C_Bank
---@field CloseBankFrame fun()
---@field FetchNumPurchasedBankTabs fun(bankType: BankType): number
---@field FetchPurchasedBankTabData fun(bankType: BankType): BankTabData[]
---@field HasMaxBankTabs fun(bankType: BankType): boolean
---@field FetchDepositedMoney fun(bankType: BankType): number
---@field AutoDepositItemsIntoBank fun(bankType: BankType)
C_Bank = {}

-- Backwards compatible function for Classic.
function CloseBankFrame() end

---@enum BagSlotFlags
BagSlotFlags = {
  DisableAutoSort = 1,
  ClassEquipment = 2,
  ClassConsumables = 4,
  ClassProfessionGoods = 8,
  ClassJunk = 16,
  ClassQuestItems = 32,
  ExcludeJunkSell = 64,
  ClassReagents = 128,
  ExpansionCurrent = 256,
  ExpansionLegacy = 512,
}

---@class Frame
---@field scrollable boolean
local frameProto = {}

---@class MinimalScrollBar: Frame
local MinimalScrollBar = {}
function MinimalScrollBar:SetInterpolateScroll(interpolate) end
function MinimalScrollBar:SetHideIfUnscrollable(hide) end

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
---@field itemQuality ItemQuality
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
---@field equipmentSets string[]|nil

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
_G.LE_EXPANSION_WAR_WITHIN = 10

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
_G.EXPANSION_NAME10 = "The War Within"

_G.BANK_BAG_PURCHASE = "Purchasable Bag Slot"
_G.COSTS_LABEL = "Cost:"

_G.UNIT_NAME_FONT = ""
_G.DAMAGE_TEXT_FONT = ""

-- Type fixes for quality constants.
---@type string
_G.ITEM_QUALITY0_DESC = _G.ITEM_QUALITY0_DESC
---@type string
_G.ITEM_QUALITY1_DESC = _G.ITEM_QUALITY1_DESC
---@type string
_G.ITEM_QUALITY2_DESC = _G.ITEM_QUALITY2_DESC
---@type string
_G.ITEM_QUALITY3_DESC = _G.ITEM_QUALITY3_DESC
---@type string
_G.ITEM_QUALITY4_DESC = _G.ITEM_QUALITY4_DESC
---@type string
_G.ITEM_QUALITY5_DESC = _G.ITEM_QUALITY5_DESC
---@type string
_G.ITEM_QUALITY6_DESC = _G.ITEM_QUALITY6_DESC
---@type string
_G.ITEM_QUALITY7_DESC = _G.ITEM_QUALITY7_DESC
---@type string
_G.ITEM_QUALITY8_DESC = _G.ITEM_QUALITY8_DESC

Enum.BagIndex.AccountBankTab_1 = 13
Enum.BagIndex.AccountBankTab_2 = 14
Enum.BagIndex.AccountBankTab_3 = 15
Enum.BagIndex.AccountBankTab_4 = 16
Enum.BagIndex.AccountBankTab_5 = 17

Enum.PlayerInteractionType.AccountBanker = 68

---@enum BankType
Enum.BankType = {
  Character = 0,
  Guild = 1,
  Account = 2,
}

---@class TabSettingsMenu: Frame
TabSettingsMenu = {}
function TabSettingsMenu:Show() end
function TabSettingsMenu:Hide() end
function TabSettingsMenu:SetSelectedTab(index) end
function TabSettingsMenu:Update() end
function TabSettingsMenu:GetBankFrame() end

---@class AccountBankPanel: Frame
---@field TabSettingsMenu TabSettingsMenu
AccountBankPanel = {}

AccountBankPanel.PurchasePrompt = {}
AccountBankPanel.PurchasePrompt.TabCostFrame = {}
---@type Button
AccountBankPanel.PurchasePrompt.TabCostFrame.PurchaseButton = {
  BattlepayItemTexture = {},
  isSkinned = true,
}

ACCOUNT_BANK_PANEL_TITLE = ""

---@class AceConfig.OptionsTable
---@field values? table<any, any>
---[Documentation](http://www.wowace.com/addons/ace3/pages/ace-config-3-0-options-tables/)
local OptionsTable = {}

---@class AceItemList
---@field type string
---@field frame Frame
---@field section Section
---@field parent AceGUIFrame
---@field label AceGUILabel
local AceItemList = {}

---@param values CustomCategoryFilter
function AceItemList:SetList(values) end

---@class AceGUILabel
---@field frame Frame

---@class MoneyFrameButtonTemplate

---@class DefaultPanelFlatTemplate

---@class UIPanelButtonTemplate

---@class InputBoxTemplate

-- Legacy UpdateCooldown function for Classic.
---@param id number
---@param button Button
function ContainerFrame_UpdateCooldown(id, button) end

---@type Frame
GameMenuFrame = {
  scrollable = true,
}

---@type CheckButton
KeyRingButton = {}

---@type Button
CharacterReagentBag0Slot = {
  BattlepayItemTexture = {},
  isSkinned = true,
}

---@class MainMenuBagButton: Button
---@field SlotHighlightTexture Texture

ItemButtonUtil = {}

---@enum ItemContextMatchResult
ItemButtonUtil.ItemContextMatchResult = {
	Match = 1,
	Mismatch = 2,
	DoesNotApply = 3,
}

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
PawnShouldItemLinkHaveUpgradeArrow = _G['PawnShouldItemLinkHaveUpgradeArrow'] --[[@as fun(itemLink: string): boolean]]
PawnShouldItemLinkHaveUpgradeArrowUnbudgeted = _G['PawnShouldItemLinkHaveUpgradeArrowUnbudgeted'] --[[@as fun(itemLink: string, level?: boolean): boolean]]

--- SimpleItemLevel API Globals
---@class SimpleItemLevel
SimpleItemLevel = {}
SimpleItemLevel.API = {}

---@param itemLink string
---@return boolean
function SimpleItemLevel.API.ItemIsUpgrade(itemLink) end

--- SortBags

-- Sort bags for classic.
function SortBags() end

--- DevTool
---@class DevTool
_G.DevTool = {}

---@param value any
---@param tag string
function _G.DevTool:AddData(value, tag) end

---@param index number
---@param backpack number
function SetCurrencyBackpack(index, backpack) end

---@param index number
---@return CurrencyInfo
function GetCurrencyListInfo(index) end

---@return number
function GetCurrencyListSize() end


--- WagoAnalytics
---@class WagoAnalytics
local WagoAnalytics = {}

---@param id string
function WagoAnalytics:Register(id) end

---@param label string
---@param enabled boolean
function WagoAnalytics:Switch(label, enabled) end

---@param counter string
---@param amount? number
function WagoAnalytics:IncrementCounter(counter, amount) end

---@param counter string
---@param amount? number
function WagoAnalytics:DecrementCounter(counter, amount) end

---@param counter string
---@param amount number
function WagoAnalytics:SetCounter(counter, amount) end


---@class DecorationFrame: Frame

--- GuildWars2 API
---@class GuildWars2
GW2_ADDON = {}

GW2_ADDON.BackdropTemplates = {}
function GW2_ADDON.CreateFrameHeaderWithBody(frame, titletext, icon, details) end
function GW2_ADDON.SkinBagSearchBox(searchBox) end

function Button:GwSkinButton(x) end
function Button:GwStripTextures() end

---@class GuildWarsHeader: Frame
---@field windowIcon Texture

---@class ElvUI
---@field RegisterCooldown fun(self: ElvUI, tex: Cooldown, b: string)
ElvUI = {
  media = {
    bordercolor = {}
  },
  Media = {
    Textures = {},
    bordercolor = {}
  }
}

---@class ElvUISkin
local ElvUISkin = {}

---@param frame Frame
function ElvUISkin:HandleEditBox(frame) end

---@param frame Frame
function ElvUISkin:HandleFrame(frame) end

---@param button ItemButton
---@param outer boolean
function ElvUISkin:HandleItemButton(button, outer) end

---@param IconBorder Texture
function ElvUISkin:HandleIconBorder(IconBorder) end

---@param tab PanelTabButtonTemplate
function ElvUISkin:HandleTab(tab) end

---@param name string
---@return ElvUISkin
function ElvUI:GetModule(name) end