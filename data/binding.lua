local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Binding: AceModule
local binding = addon:NewModule('Binding')

---@class (exact) BindingInfo
---@field binding BindingScope
---@field bound boolean

---@param itemID number
---@param itemLink string
---@return Enum.ItemBind
function binding.GetBindType(itemID,itemLink)
  ---@type ItemInfo
  local ItemInfo = itemLink -- itemLink has better information for items, but no information for pets
  if ( strfind(itemLink, "battlepet:") ) then
    ItemInfo = itemID
  end
  local bindType, _, _, _ = select(14,C_Item.GetItemInfo(ItemInfo ))
  return bindType
end

---@param itemID number
---@param itemLocation ItemLocationMixin
---@param itemLink string
---@return BindingInfo?
function binding.GetItemBinding(itemID, itemLocation, itemLink)
  local bagID,slotID = itemLocation:GetBagAndSlot()
  ---@type Enum.ItemBind
  local bindType = binding.GetBindType(itemID,itemLink)
  if not bindType then return nil end

  ---@type BindingInfo
  local bindinginfo = {
    binding = const.BINDING_SCOPE.UNKNOWN,
    bound = false
  }

  if not C_Item.IsBound(itemLocation) then
    if (bindType == 0) then
      bindinginfo.binding = const.BINDING_SCOPE.NONBINDING
    elseif (bindType == 2) then
      bindinginfo.binding = const.BINDING_SCOPE.BOE
    elseif (bindType == 3) then
      bindinginfo.binding = const.BINDING_SCOPE.BOU
    elseif (bindType == 8) then -- only Hoard of Draconic Delicacies uses this
      bindinginfo.binding = const.BINDING_SCOPE.BNET
    end
    -- retail only Warbound until Equip
    if C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(itemLocation) then
      bindinginfo.bound = true
      bindinginfo.binding = const.BINDING_SCOPE.WUE
    end
  else -- isBound
    bindinginfo.bound = true

    if (bindType == 1) then
      bindinginfo.binding = const.BINDING_SCOPE.BOUND -- we don't register a bare keyword 'bound' as it is too common. Should expand after toolip scanning
    end

    -- on retail we can distingush Soulbound and Warbound
    if C_Bank and C_Bank.IsItemAllowedInBankType then
      bindinginfo.binding = const.BINDING_SCOPE.SOULBOUND
    end

    if C_Bank and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
      bindinginfo.binding = const.BINDING_SCOPE.ACCOUNT
    end

    if C_Container.GetContainerItemPurchaseInfo(bagID, slotID, false) then
      bindinginfo.binding = const.BINDING_SCOPE.REFUNDABLE
    end

    if (bindType == 4) then
      bindinginfo.binding = const.BINDING_SCOPE.QUEST
    end
  end -- isBound
  if bindingInfo.binding == const.BINDING_SCOPE.UNKNOWN then
    return nil
  end
  return bindinginfo
end


