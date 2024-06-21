local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class DefaultThemeTemplate: Frame
---@field Bg Texture
---@field PortraitContainer PortraitContainer
---@field CloseButton Button
---@field SearchBox SearchBox
---@field Backdrop BackdropTemplate
---@field NineSlice NineSlicePanelTemplate
---@field TopTileStreaks Texture
---@field TitleContainer TitleContainer
---@field search SearchFrame

---@type table<string, DefaultThemeTemplate>
local decoratorFrames = {}

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@type Theme
local defaultTheme = {
  Name = 'Default',
  Description = 'The default theme.',
  Available = true,
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeDefault", frame, "DefaultPanelTemplate") --[[@as DefaultThemeTemplate]]
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.TitleContainer.TitleText:SetFontObject(fonts.UnitFrame12Yellow)
      decoration.CloseButton = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonDefaultAnchors") --[[@as Button]]
      decoration.CloseButton:SetScript("OnClick", function()
        frame.Owner:Hide()
      end)

      local searchBox = search:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      searchBox.frame:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -22, -2)
      searchBox.frame:SetSize(150, 20)
      decoration.search = searchBox

      decoration.CloseButton:SetFrameLevel(1001)
      decoration.TitleContainer:SetFrameLevel(1001)
      decoration.NineSlice:SetFrameLevel(1000)
      if themes.titles[frame:GetName()] then
        decoration:SetTitle(themes.titles[frame:GetName()])
      end
      themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Simple = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeDefault", frame, "DefaultPanelTemplate") --[[@as DefaultThemeTemplate]]
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.CloseButton = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonDefaultAnchors") --[[@as Button]]
      decoration.CloseButton:SetScript("OnClick", function()
        frame:Hide()
      end)
      decoration.TitleContainer.TitleText:SetFontObject(fonts.UnitFrame12Yellow)
      if themes.titles[frame:GetName()] then
        decoration:SetTitle(themes.titles[frame:GetName()])
      end
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Flat = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeDefault", frame, "DefaultPanelFlatTemplate") --[[@as DefaultThemeTemplate]]
      decoration:SetAllPoints()
      decoration.TitleContainer.TitleText:SetFontObject(fonts.UnitFrame12Yellow)
      if themes.titles[frame:GetName()] then
        decoration:SetTitle(themes.titles[frame:GetName()])
      end
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Opacity = function(frame, alpha)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.Bg:SetAlpha(alpha / 100)
    end
  end,
  SectionFont = function(font)
    font:SetFontObject(fonts.UnitFrame12Yellow)
  end,
  Reset = function()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
  end,
  SetTitle = function(frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration:SetTitle(title)
    end
  end,
  ToggleSearch = function (frame, shown)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.search:SetShown(shown)
    end
  end
}

themes:RegisterTheme('Default', defaultTheme)