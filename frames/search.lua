local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Search: AceModule
---@field searchFrame SearchFrame
local search = addon:NewModule('Search')

---@class (exact) SearchFrame
---@field frame Frame
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
---@field textBox EditBox
---@field helpText FontString
search.searchProto = {}

-- BetterBags_ToggleSearch toggles the search view. This function is used in the
-- search key bind.
function BetterBags_ToggleSearch()
  search.searchFrame:Toggle()
end

function search.searchProto:Toggle()
  if self.frame:GetAlpha() > 0 then
    self.textBox:ClearFocus()
    self.fadeOutGroup:Play()
  else
    self.textBox:ClearFocus()
    addon.Bags.Backpack:Show()
    self.fadeInGroup:Play()
  end
end

function search.searchProto:Hide()
  if self.frame:GetAlpha() > 0 then
    self.textBox:ClearFocus()
    self.fadeOutGroup:Play()
  end
end

function search.searchProto:UpdateSearch()
  local text = self.textBox:GetText()
  if text == "" then
    self.helpText:Show()
  else
    self.helpText:Hide()
  end
  addon.Bags.Backpack:Search(text)
  addon.Bags.Bank:Search(text)
end

---@param parent Frame
---@return SearchFrame
function search:Create(parent)
  local sf = setmetatable({}, {__index = search.searchProto})
  local f = CreateFrame("Frame", "BetterBagsSearchFrame", UIParent, "SimplePanelTemplate") --[[@as Frame]]
  f:SetSize(400, 75)
  f:SetPoint("BOTTOM", parent, "TOP", 0, 10)
  f:SetFrameStrata("HIGH")
  f:SetFrameLevel(700)
  f:SetAlpha(0)
  f.Inset:Hide()
  f:Show()

  local textBox = CreateFrame("EditBox", nil, f) --[[@as EditBox]]
  textBox:SetFontObject("GameFontNormalHuge")
  textBox:SetTextColor(1, 1, 1, 1)
  textBox:SetParent(f)
  textBox:SetPoint("TOPLEFT", f, "TOPLEFT", 10, 0)
  textBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 0)
  textBox:ClearFocus()
  textBox:SetAutoFocus(false)
  textBox:SetJustifyH("CENTER")
  textBox:SetScript("OnEscapePressed", function(me)
    ---@cast me +EditBox
    me:ClearFocus()
    sf:Toggle()
  end)
  textBox:SetScript("OnTextChanged", function()
    sf:UpdateSearch()
  end)

  local helpText = textBox:CreateFontString("BetterBagsSearchHelpText", "ARTWORK", "GameFontDisableLarge")
  helpText:SetPoint("CENTER", textBox, "CENTER", 0, 0)
  helpText:SetText("Start typing to search your bags...")
  helpText:Show()
  sf.helpText = helpText

  sf.fadeInGroup, sf.fadeOutGroup = animations:AttachFadeAndSlideLeft(f, true)
  sf.fadeInGroup:HookScript("OnFinished", function()
    textBox:SetFocus()
  end)
  sf.fadeOutGroup:HookScript("OnFinished", function()
    textBox:SetText("")
    helpText:Show()
  end)

  sf.frame = f
  sf.textBox = textBox
  search.searchFrame = sf

  events:RegisterMessage('addon/CloseSpecialWindows', function()
    sf:Hide()
  end)
  return sf
end
