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
local search = addon:GetModule('Search')

---@class SearchBox: AceModule
---@field searchFrame SearchFrame
local searchBox = addon:NewModule('SearchBox')

---@class (exact) SearchFrame
---@field frame Frame
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
---@field textBox EditBox
---@field helpText FontString
---@field kind BagKind
searchBox.searchProto = {}

-- BetterBags_ToggleSearch toggles the search view. This function is used in the
-- search key bind.
function BetterBags_ToggleSearch()
  searchBox.searchFrame:Toggle()
end

function searchBox.searchProto:Toggle()
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

function searchBox.searchProto:Hide()
  if self.frame:IsShown() then
    self.textBox:SetText("")
    self.textBox:ClearFocus()
    if self.fadeOutGroup then
      self.fadeOutGroup:Play()
    else
      self.frame:Hide()
    end
  end
end

function searchBox.searchProto:Show()
  if not self.frame:IsShown() then
    self.textBox:ClearFocus()
    if self.fadeInGroup then
      self.fadeInGroup:Play()
    else
      self.frame:Show()
    end
  end
end

function searchBox.searchProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

function searchBox.searchProto:UpdateSearch()
  local text = self.textBox:GetText()
  if text == "" then
    self.helpText:Show()
  else
    self.helpText:Hide()
  end
  if self.kind ~= nil then
    if self.kind == const.BAG_KIND.BACKPACK then
      if text == "" then
        addon.Bags.Backpack:ResetSearch()
      else
        local results = search:Search(text)
        addon.Bags.Backpack:Search(results)
      end
    else
      if text == "" then
        addon.Bags.Bank:ResetSearch()
      else
        local results = search:Search(text)
        addon.Bags.Bank:Search(results)
      end
    end
  else
    if text == "" then
      addon.Bags.Backpack:ResetSearch()
      addon.Bags.Bank:ResetSearch()
    else
      local results = search:Search(text)
      addon.Bags.Backpack:Search(results)
      addon.Bags.Bank:Search(results)
    end
  end
end

function searchBox:GetText()
  return self.searchFrame.textBox:GetText()
end

---@param parent Frame
---@return SearchFrame
function searchBox:Create(parent)
  local sf = setmetatable({}, {__index = searchBox.searchProto})
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
  searchBox.searchFrame = sf

  events:RegisterMessage('addon/CloseSpecialWindows', function()
    sf:Hide()
  end)
  return sf
end

---@param kind BagKind
---@param parent Frame
---@return SearchFrame
function searchBox:CreateBox(kind, parent)
  local sf = setmetatable({}, {__index = searchBox.searchProto})
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