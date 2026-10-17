local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class SearchCategoryConfig: AceModule
local searchCategoryConfig = addon:GetModule('SearchCategoryConfig')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class WindowModule: AceModule
local window = addon:GetModule('Window')

---@class SearchBox: AceModule
---@field searchFrame SearchFrame
local searchBox = addon:NewModule('SearchBox')

-- A SearchFrame is the overlay search panel (searchBox:Create, a Search window) or a bag's
-- in-bag search box (searchBox:CreateBox, which has no window).
---@class (exact) SearchFrame
---@field frame Frame
---@field window? BetterBagsWindow
---@field textBox EditBox
---@field helpText FontString
---@field kind BagKind
---@field enterLabel FontString
---@field enterLabelFadeIn AnimationGroup
---@field enterLabelFadeOut AnimationGroup
---@field helpTextFadeIn AnimationGroup
---@field helpTextFadeOut AnimationGroup
searchBox.searchProto = {}
addon:GetModule('Perf'):RegisterPrototype(searchBox.searchProto, 'SearchBoxFrame')

-- BetterBags_ToggleSearch toggles the search view. This function is used in the
-- search key bind.
function BetterBags_ToggleSearch()
  local ctx = context:New('BetterBags_ToggleSearch')
  searchBox.searchFrame:Toggle(ctx)
end

---@param ctx Context
-- Toggle opens the overlay over the backpack, focusing its box once shown, or closes it.
---@param ctx Context
function searchBox.searchProto:Toggle(ctx)
  if self.frame:IsShown() and not (self.window and self.window:IsClosing()) then
    self:Hide(ctx)
  else
    addon.Bags.Backpack:Show(ctx)
    self:Show(ctx)
  end
end

-- Hide empties the box and closes it; the overlay fades out with its theme, then shows its
-- help again.
---@param ctx? Context
function searchBox.searchProto:Hide(ctx)
  if not self.frame:IsShown() then
    return
  end
  self.textBox:SetText("")
  self.textBox:ClearFocus()
  if self.window == nil then
    self.frame:Hide()
    return
  end
  self.window:Hide(ctx or context:New('SearchBox_Hide'), function()
    self.textBox:SetText("")
    self.helpText:Show()
  end)
end

-- Show opens the box; the overlay fades in with its theme and focuses its box once shown.
---@param ctx? Context
function searchBox.searchProto:Show(ctx)
  self.textBox:ClearFocus()
  if self.window == nil then
    self.frame:Show()
    return
  end
  self.window:Show(ctx or context:New('SearchBox_Show'), function()
    self.textBox:SetFocus()
  end)
end

function searchBox.searchProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

---@param ctx Context
function searchBox.searchProto:UpdateSearch(ctx)
  local text = self.textBox:GetText()
  if text == "" then
    if self.helpTextFadeIn then
      self.helpTextFadeIn:Play()
    else
      self.helpText:Show()
    end
  else
    if self.helpTextFadeOut then
      if self.helpText:IsShown() then
        self.helpTextFadeOut:Play()
      end
    else
      self.helpText:Hide()
    end
  end

  if text == "" then
    self.enterLabelFadeOut:Play()
  else
    if not self.enterLabel:IsShown() then
      self.enterLabelFadeIn:Play()
    end
  end

  if self.kind ~= nil then
    if self.kind == const.BAG_KIND.BACKPACK then
      if text == "" then
        addon.Bags.Backpack:ResetSearch(ctx)
      else
        local results = search:Search(text)
        addon.Bags.Backpack:Search(ctx, results)
      end
    else
      if addon.Bags.Bank then
        if text == "" then
          addon.Bags.Bank:ResetSearch(ctx)
        else
          local results = search:Search(text)
          addon.Bags.Bank:Search(ctx, results)
        end
      end
    end
  else
    if text == "" then
      self.enterLabelFadeOut:Play()
      addon.Bags.Backpack:ResetSearch(ctx)
      if not addon.isRetail and addon.Bags.Bank then
        addon.Bags.Bank:ResetSearch(ctx)
      end
    else
      if not self.enterLabel:IsShown() then
        self.enterLabelFadeIn:Play()
      end
      local results = search:Search(text)
      addon.Bags.Backpack:Search(ctx, results)
      if addon.Bags.Bank then
        addon.Bags.Bank:Search(ctx, results)
      end
    end
  end
end

function searchBox:GetText()
  if not self.searchFrame then return "" end
  return self.searchFrame.textBox:GetText()
end

-- GetSearchText returns the active search query for the given bag kind.
--
-- The live filter is driven by whichever box the user typed into. When in-bag
-- search is enabled (the default), that is the per-kind in-bag box created by
-- searchBox:CreateBox and kept by its bag as `bag.searchBox`
-- -- a distinct SearchFrame instance from the module-level overlay searchFrame.
-- GetText() only ever sees the overlay box, so the data pipeline
-- (data/items.lua Phase8_EnrichCategories) must call this kind-aware getter when
-- it recomputes item.isSearchResult on every redraw. Reading only the overlay
-- box reset the filter to "everything matches" whenever a redraw fired while the
-- in-bag search was active (e.g. right-clicking an item to send it to the bank).
---@param kind BagKind?
---@return string
function searchBox:GetSearchText(kind)
  if kind ~= nil and database:GetInBagSearch() then
    local box = self:GetInBagBox(kind)
    if box and box.textBox then
      local text = box.textBox:GetText()
      if text and text ~= "" then
        return text
      end
    end
  end
  -- No active in-bag query: fall back to the overlay box (which searches both
  -- bags), and returns "" when it holds no text.
  return self:GetText()
end

-- GetInBagBox returns the in-bag search box of the bag of a kind, if that bag exists.
---@param kind BagKind
---@return SearchFrame?
function searchBox:GetInBagBox(kind)
  local bags = addon.Bags
  if bags == nil then
    return nil
  end
  local bag
  if kind == const.BAG_KIND.BANK then
    bag = bags.Bank
  else
    bag = bags.Backpack
  end
  return bag and bag.searchBox or nil
end

---@param ctx Context
---@param parent Frame
---@return SearchFrame
-- Create makes the overlay search panel the search keybinding toggles: a Search window of a
-- fixed size above the backpack, drawn and animated by the theme, hidden until toggled.
---@param _ctx Context
---@param parent Frame
---@return SearchFrame
function searchBox:Create(_ctx, parent)
  local sf = setmetatable({}, {__index = searchBox.searchProto})
  sf.window = window:Create({
    Kind = "Search",
    Name = "BetterBagsSearchFrame",
    Title = "",
    Strata = "HIGH",
    Level = 700,
    Movable = false,
    SizeMode = function() return "window" end,
    Resizable = false,
    Points = { { Point = "BOTTOM", RelativeTo = parent, RelativePoint = "TOP", X = 0, Y = 10 } },
  })
  local f = sf.window.frame
  f:SetSize(400, 75)
  local content = sf.window.content

  local enterLabel = sonata:CreateText(content, "Muted", "ARTWORK")
  enterLabel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 6, 6)
  enterLabel:SetText("[Enter] Create a new category...")
  enterLabel:Hide()
  sf.enterLabelFadeIn, sf.enterLabelFadeOut = animations:AttachFadeGroup(enterLabel)

  sf.enterLabel = enterLabel

  local textBox = CreateFrame("EditBox", nil, content) --[[@as EditBox]]
  sonata:SetTextRole(textBox, "Search")
  textBox:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  textBox:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  textBox:ClearFocus()
  textBox:SetAutoFocus(false)
  textBox:SetJustifyH("CENTER")
  addon.SetScript(textBox, "OnEscapePressed", function(ectx, me)
    ---@cast me +EditBox
    me:ClearFocus()
    sf:Toggle(ectx)
  end)

  addon.SetScript(textBox, "OnTextChanged", function(ectx)
    sf:UpdateSearch(ectx)
  end)

  textBox:SetScript("OnEnterPressed", function()
    if database:GetEnterToMakeCategory() then
      searchCategoryConfig:Open({
        name = "",
        itemList = {},
        priority = 10,
        searchCategory = {
          query = searchBox:GetText(),
        }
      })
    end
  end)

  local helpText = textBox:CreateFontString("BetterBagsSearchHelpText", "ARTWORK")
  sonata:SetTextRole(helpText, "Empty")
  helpText:SetPoint("CENTER", textBox, "CENTER", 0, 0)
  helpText:SetText("Start typing to search your bags...")
  helpText:Show()
  sf.helpTextFadeIn, sf.helpTextFadeOut = animations:AttachFadeGroup(helpText)
  sf.helpText = helpText

  sf.frame = f
  sf.textBox = textBox
  searchBox.searchFrame = sf

  events:RegisterMessage('addon/CloseSpecialWindows', function(ectx)
    sf:Hide(ectx)
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
  addon.SetScript(textBox, "OnTextChanged", function(ctx)
    sf:UpdateSearch(ctx)
  end)

  textBox:SetScript("OnEnterPressed", function()
    if database:GetEnterToMakeCategory() then
      searchCategoryConfig:Open({
        name = "",
        itemList = {},
        priority = 10,
        searchCategory = {
          query = textBox:GetText(),
        }
      })
    end
  end)

  textBox:SetAllPoints()

  local enterLabel = textBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  enterLabel:SetPoint("RIGHT", textBox, "RIGHT", -20, 0)
  enterLabel:SetText("[Enter] Create a new category...")
  enterLabel:Hide()
  sf.enterLabelFadeIn, sf.enterLabelFadeOut = animations:AttachFadeGroup(enterLabel)

  sf.enterLabel = enterLabel

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
  addon:GetModule('Sonata'):RegisterElement("SearchBox", textBox)
  return sf
end