
local addon = GetBetterBags()

local const = addon:GetConstants()
---@class Binding: AceModule
local binding = addon:NewModule('Binding')

---@class (exact) BindingInfo
---@field binding BindingScope
---@field bound boolean

---@param itemLocation ItemLocationMixin
---@param bindType Enum.ItemBind
---@return BindingInfo
function binding.GetItemBinding(itemLocation, bindType)
  local bagID, slotID = itemLocation:GetBagAndSlot()
  local equipSlotIndex = itemLocation:GetEquipmentSlot()
  local isEquipped = itemLocation:IsEquipmentSlot() or false
  ---@type BindingInfo
  local bindinginfo = {
    binding = const.BINDING_SCOPE.UNKNOWN,
    bound = false
  }

  ---@diagnostic disable-next-line: param-type-not-match
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
    ---@diagnostic disable-next-line: param-type-not-match
    -- retail only Warbound until Equip
    if C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(itemLocation) then
      bindinginfo.bound = true
      bindinginfo.binding = const.BINDING_SCOPE.WUE
    end
  else -- isBound
    bindinginfo.bound = true
    bindinginfo.binding = const.BINDING_SCOPE.BOUND -- we don't register a bare keyword 'bound' as it is too common. Should expand after toolip scanning

    ---@diagnostic disable-next-line: undefined-field
    -- on retail we can distingush Soulbound and Warbound
    if C_Bank and C_Bank.IsItemAllowedInBankType then
      bindinginfo.binding = const.BINDING_SCOPE.SOULBOUND
    end

    ---@diagnostic disable-next-line: undefined-field
    if C_Bank and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
      bindinginfo.binding = const.BINDING_SCOPE.ACCOUNT
    end

    ---@diagnostic disable-next-line: unnecessary-if
    if C_Container.GetContainerItemPurchaseInfo(bagID or 0, slotID or equipSlotIndex, isEquipped) then
      bindinginfo.binding = const.BINDING_SCOPE.REFUNDABLE
    end

    if (bindType == 4) then
      bindinginfo.binding = const.BINDING_SCOPE.QUEST
    end
  end -- isBound

  return bindinginfo
end


