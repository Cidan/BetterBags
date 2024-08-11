local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Binding: AceModule
local binding = addon:NewModule('Binding')

---@class (exact) BindingInfo
---@field binding string
---@field bound boolean

---@param itemLocation ItemLocationMixin
---@param bindType Enum.ItemBind
---@return BindingInfo
function binding.GetItemBinding(itemLocation, bindType)
  local bindinginfo = {}
  ---@cast bindinginfo +BindingInfo

  if not C_Item.IsBound(itemLocation) then
    bindinginfo.bound = false
    if (bindType == 0) then
      bindinginfo.binding = "nonbinding"
    elseif (bindType == 2) then
      bindinginfo.binding = "boe"
    elseif (bindType == 3) then
      bindinginfo.binding = "bou"
    end
    -- retail only Warbound until Equip
    if C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(itemLocation) then
      bindinginfo.bound = true
      bindinginfo.binding = "wue"
    end
  else -- isBound
    bindinginfo.bound = true
    bindinginfo.binding = "" -- we don't register a bare keyword 'bound' as it is too common. Should expand after toolip scanning

    -- on retail we can distingush Soulbound and Warbound
    if C_Bank and C_Bank.IsItemAllowedInBankType then
      bindinginfo.binding = "soulbound"
    end
    if C_Bank and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
      bindinginfo.binding = "warbound"
    end

    if (bindType == 4) then
      bindinginfo.binding = "quest"
    end
  end -- isBound
  assert(bindinginfo.binding, (format("Binding module error. Unknown bindType:%d bag:%d slot:%d", bindType, itemLocation:GetBagAndSlot())))
  return bindinginfo
end


