local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Search: AceModule
---@field searchFrame SearchFrame
local search = addon:NewModule('Search')

---@class (exact) SearchFrame
---@field frame Frame
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
---@field textBox EditBox
---@field helpText FontString
---@field kind BagKind
search.searchProto = {}

-- BetterBags_ToggleSearch toggles the search view. This function is used in the
-- search key bind.
function BetterBags_ToggleSearch()
  search.searchFrame:Toggle()
end

function search.searchProto:Toggle()
  if self.frame:IsShown() then
    self.textBox:SetText("")
    self.textBox:ClearFocus()
    self.fadeOutGroup:Play()
  else
    self.textBox:ClearFocus()
    addon.Bags.Backpack:Show()
    self.fadeInGroup:Play()
  end
end

function search.searchProto:Hide()
  if self.frame:IsShown() then
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
  if self.kind ~= nil then
    if self.kind == const.BAG_KIND.BACKPACK then
      addon.Bags.Backpack:Search(text)
    else
      addon.Bags.Bank:Search(text)
    end
  else
    addon.Bags.Backpack:Search(text)
    addon.Bags.Bank:Search(text)
  end
end

function search:GetText()
  return self.searchFrame.textBox:GetText()
end

---@param parent Frame
---@return SearchFrame
function search:Create(parent)
  local sf = setmetatable({}, {__index = search.searchProto})
  local f = CreateFrame("Frame", "BetterBagsSearchFrame", UIParent, "BetterBagsSearchPanelTemplate") --[[@as Frame]]
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

  sf.fadeInGroup, sf.fadeOutGroup = animations:AttachFadeAndSlideLeft(f)
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

---@param kind BagKind
---@param parent Frame
---@return SearchFrame
function search:CreateBox(kind, parent)
  local sf = setmetatable({}, {__index = search.searchProto})
  sf.frame = CreateFrame("Frame", nil, parent) --[[@as Frame]]
  sf.frame:SetFrameLevel(2000)
  local textBox = CreateFrame("EditBox", nil, sf.frame, "BagSearchBoxTemplate") --[[@as SearchBox]]
  textBox:SetFontObject("GameFontNormal")
  textBox:SetTextColor(1, 1, 1, 1)
  textBox:ClearFocus()
  textBox:SetAutoFocus(false)
  textBox:SetJustifyH("LEFT")
  textBox:SetScript("OnEscapePressed", function(me)
    ---@cast me +EditBox
    me:ClearFocus()
  end)
  textBox:SetScript("OnTextChanged", function()
    sf:UpdateSearch()
  end)
  textBox:SetAllPoints()

  sf.kind = kind
  sf.helpText = textBox.Instructions
  sf.textBox = textBox
  if kind == const.BAG_KIND.BACKPACK then
    sf.helpText:SetText("Search Backpack")
  else
    sf.helpText:SetText("Search Bank")
  end
  sf.helpText:ClearAllPoints()
  sf.helpText:SetPoint("CENTER")
  sf.frame:Hide()
  return sf
end