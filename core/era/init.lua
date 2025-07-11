---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addon = GetBetterBags()

function addon:HideBlizzardBags()
  local sneakyFrame = CreateFrame("Frame", "BetterBagsSneakyFrame")
  sneakyFrame:Hide()

  for i = 1, 13 do
    _G["ContainerFrame"..i]:SetParent(sneakyFrame)
  end

  BankFrame:SetParent(sneakyFrame)
  BankFrame:SetScript("OnHide", nil)
  BankFrame:SetScript("OnShow", nil)
  BankFrame:SetScript("OnEvent", nil)
end

function addon:UpdateButtonHighlight()
  for _, button in pairs(addon._buttons) do
    button:SetChecked(addon.Bags.Backpack:IsShown())
  end
end