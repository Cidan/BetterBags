local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class PortraitFrameTexturedBaseTemplate
---@field Bg Texture
---@field PortraitContainer PortraitContainer
---@field CloseButton Button
---@field SearchBox SearchBox
---@field Backdrop BackdropTemplate
---@field NineSlice NineSlicePanelTemplate
---@field TopTileStreaks Texture
---@field TitleContainer TitleContainer

---@type table<string, Frame|PortraitFrameTexturedBaseTemplate|DefaultPanelTemplate|DefaultPanelFlatTemplate>
local decoratorFrames = {}

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type Theme
local defaultTheme = {
  Name = 'Default',
  Description = 'The default theme.',
  Available = true,
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeDefault", frame, "DefaultPanelTemplate")
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
      decoration.TitleContainer.TitleText:SetTextColor(1, 0.82, 0)
      decoration.CloseButton = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonDefaultAnchors") --[[@as Button]]
      decoration.CloseButton:SetFrameLevel(1001)
      decoration.TitleContainer:SetFrameLevel(1001)
      decoration.NineSlice:SetFrameLevel(1000)
      themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Simple = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeDefault", frame, "DefaultPanelTemplate")
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors") --[[@as Button]]
      decoration.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
      decoration.TitleContainer.TitleText:SetTextColor(1, 0.82, 0)
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
      decoration = CreateFrame("Frame", frame:GetName().."ThemeDefault", frame, "DefaultPanelFlatTemplate")
      decoration:SetAllPoints()
      decoration.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
      decoration.TitleContainer.TitleText:SetTextColor(1, 0.82, 0)
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
    font:SetFont(UNIT_NAME_FONT, 12, "")
    font:SetTextColor(1, 0.82, 0)
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
  end
}

themes:RegisterTheme('Default', defaultTheme)