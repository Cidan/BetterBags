local addonName = ... ---@type string
local gw = GW2_ADDON

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type table<string, Frame>
local decoratorFrames = {}

---@type Button[]
local buttons = {}

---@type FontString[]
local titles = {}

---@type Theme
local gw2Theme = {
  Name = "Guild Wars 2",
  Description = "A theme using the GW2_UI style.",
  Available = gw ~= nil,
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame)
      decoration:SetAllPoints()
      decoration:SetFrameStrata("BACKGROUND")
      local font = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")
      font:SetText(frame.TitleContainer.TitleText:GetText())
      table.insert(titles, font)
      gw.CreateFrameHeaderWithBody(decoration, font, "Interface/AddOns/GW2_UI/textures/bag/bagicon", {})
      table.insert(buttons, frame.CloseButton)
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
    frame.CloseButton:GwSkinButton(true)
    frame.TitleContainer:Hide()
    frame.NineSlice:Hide()
    frame.Backdrop:Hide()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
    --frame.PortraitContainer:Hide()
  end,
  Simple = function(frame)
  end,
  Flat = function(frame)
  end,
  Opacity = function(frame, alpha)
  end,
  SectionFont = function(font)
  end,
  Reset = function(windows, sectionFonts)
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
    for _, button in pairs(buttons) do
      button:GwStripTextures()
      button.isSkinned = false
    end
  end
}

themes:RegisterTheme('GW2', gw2Theme)