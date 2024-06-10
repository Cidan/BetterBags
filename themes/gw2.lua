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

local function newPanelButton(panel, texture, tooltip, onClick)
  local button = CreateFrame("Button", nil, panel)
  button:SetSize(32, 32)
  button:SetNormalTexture(texture)
  button:SetHighlightTexture(texture)
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  local previousButton = panel.panelButtons[#panel.panelButtons]
  if not previousButton then
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", -35, -40)
  else
    button:SetPoint("TOP", previousButton, "BOTTOM", 0, -5)
  end
  table.insert(panel.panelButtons, button)
  return button
end

---@type Theme
local gw2Theme = {
  Name = "Guild Wars 2",
  Description = "A theme using the GW2_UI style.",
  Available = gw ~= nil,
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame)
      decoration.panelButtons = {}
      decoratorFrames[frame:GetName()] = decoration
      local font = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")
      table.insert(titles, font)
      table.insert(buttons, frame.CloseButton)

      decoration:SetAllPoints()
      decoration:SetFrameStrata("BACKGROUND")

      gw.CreateFrameHeaderWithBody(decoration, font, "Interface/AddOns/GW2_UI/textures/bag/bagicon", {})

      decoration.gwHeader:ClearAllPoints()
      decoration.gwHeader:SetPoint("BOTTOMLEFT", decoration, "TOPLEFT", 0, -25)
      decoration.gwHeader:SetPoint("BOTTOMRIGHT", decoration, "TOPRIGHT", 0, -25)

      decoration.gwHeader.windowIcon:ClearAllPoints()
      decoration.gwHeader.windowIcon:SetPoint("CENTER", decoration, "TOPLEFT", -16, 0)

      font:ClearAllPoints()
      font:SetPoint("BOTTOMLEFT", decoration.gwHeader, "BOTTOMLEFT", 35, 10)
      font:SetText(frame.TitleContainer.TitleText:GetText())

      local footer = decoration:CreateTexture(decoration:GetName().."Footer", "BACKGROUND", nil, 7)
      footer:SetTexture("Interface/AddOns/GW2_UI/textures/bag/bagfooter")
      footer:SetHeight(55)
      footer:SetPoint("TOPLEFT", decoration, "BOTTOMLEFT", 0, 30)
      footer:SetPoint("TOPRIGHT", decoration, "BOTTOMRIGHT", -3, 30)

      local leftSide = decoration:CreateTexture(decoration:GetName().."Left", "BACKGROUND", nil, 7)
      leftSide:SetTexture("Interface/AddOns/GW2_UI/textures/bag/bagleftpanel")
      leftSide:SetWidth(40)
      leftSide:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 25)
      leftSide:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 25)

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/textures/icons/BagMicroButton-Up", "Show Bags", function()
        if frame.Owner.slots:IsShown() then
          frame.Owner.slots:Hide()
        else
          frame.Owner.slots:Draw()
          frame.Owner.slots:Show()
        end
      end)
    else
      decoration:Show()
    end
    frame.CloseButton:GwSkinButton(true)
    frame.TitleContainer:Hide()
    frame.NineSlice:Hide()
    frame.Backdrop:Hide()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
    frame.PortraitContainer:Hide()
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