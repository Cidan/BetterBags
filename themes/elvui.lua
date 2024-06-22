local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class ElvUIDecoration: Frame
---@field search SearchFrame

---@type table<string, ElvUIDecoration>
local decoratorFrames = {}

---@type Theme
local theme = {
  Name = 'ElvUI',
  Description = "An ElvUI Theme for BetterBags",
  Available = ElvUI and true or false,
  Portrait = function (frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeElvUI", frame) --[[@as ElvUIDecoration]]
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.CloseButton = CreateFrame("Button", frame:GetName().."CloseButton", decoration) --[[@as Button]]
      decoration.CloseButton:SetScript("OnClick", function()
        print("close")
        frame.Owner:Hide()
      end)
      decoration.CloseButton:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -4, -4)
      decoration.CloseButton:SetSize(14,14)
      decoration.CloseButton:SetFrameLevel(1001)

      local searchBox = search:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      searchBox.frame:SetPoint("TOP", decoration, "TOP", 0, -14)
      searchBox.frame:SetSize(150, 20)
      decoration.search = searchBox

      local bagButton = themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
      bagButton:SetPoint("TOPLEFT", decoration, "TOPLEFT", 4, -6)
      local w, h = bagButton.portrait:GetSize()
      bagButton.portrait:SetSize((w / 10) * 8.5, (h / 10) * 8.5)
      bagButton.highlightTex:SetSize((w / 10) * 8.5, (h / 10) * 8.5)
      S:HandleEditBox(searchBox.frame)
      S:HandleFrame(decoration)
      --decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      --decoration.TitleContainer.TitleText:SetFontObject(fonts.UnitFrame12Yellow)
      --decoration.CloseButton = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonDefaultAnchors") --[[@as Button]]
      --decoration.CloseButton:SetScript("OnClick", function()
      --  frame.Owner:Hide()
      --end)
--
      --local searchBox = search:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      --searchBox.frame:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -22, -2)
      --searchBox.frame:SetSize(150, 20)
      --decoration.search = searchBox
--
      --decoration.CloseButton:SetFrameLevel(1001)
      --decoration.TitleContainer:SetFrameLevel(1001)
      --decoration.NineSlice:SetFrameLevel(1000)
      --if themes.titles[frame:GetName()] then
      --  decoration:SetTitle(themes.titles[frame:GetName()])
      --end
      --themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Simple = function (frame)
    --S:HandleCloseButton(frame.CloseButton)
    --S:HandleEditBox(frame.SearchBox)
    --S:HandleButton(frame.SearchBox.searchButton)
    --S:HandleButton(frame.SearchBox.clearButton)
    --S:HandleButton(frame.SearchBox.resetButton)
    --S:HandleButton(frame.SearchBox.sortButton)
    --S:HandleButton(frame.SearchBox.filter
  end,
  Flat = function (frame)
    --S:HandleCloseButton(frame.CloseButton)
    --S:HandleEditBox(frame.SearchBox)
    --S:HandleButton(frame.SearchBox.searchButton)
    --S:HandleButton(frame.SearchBox.clearButton)
    --S:HandleButton(frame.SearchBox.resetButton)
    --S:HandleButton(frame.SearchBox.sortButton)
    --S:HandleButton(frame.SearchBox.filter
  end,
  Opacity = function (frame, opacity)
  end,
  Reset = function ()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
  end,
  SectionFont = function (font)
    font:SetFontObject("GameFontNormal")
  end,
  SetTitle = function (frame, title)
  end,
  ToggleSearch = function (frame, show)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.search:SetShown(show)
    end
  end,
}
themes:RegisterTheme('elvui', theme)