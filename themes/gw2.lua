local addonName = ... ---@type string
local gw = GW2_ADDON

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

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
  button:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
  button:SetHighlightTexture(texture)
  button:GetHighlightTexture():SetTexCoord(0, 1, 0, 1)
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

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/BagMicroButton-Up", "Show Bags", function()
        if frame.Owner.slots:IsShown() then
          frame.Owner.slots:Hide()
        else
          frame.Owner.slots:Draw()
          frame.Owner.slots:Show()
        end
      end)

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/CollectionsMicroButton-Up", "Sort Bags", function()
        frame.Owner:Sort()
      end)

      newPanelButton(decoration,  "Interface/AddOns/GW2_UI/Textures/icons/microicons/StoreMicroButton-Up", "Show Currency", function()
        if frame.Owner.currencyFrame:IsShown() then
          frame.Owner.currencyFrame:Hide()
        else
          frame.Owner.windowGrouping:Show("currencyConfig")
        end
      end)

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/QuestLogMicroButton-Up", "Show Categories", function()
        if frame.Owner.sectionConfigFrame:IsShown() then
          frame.Owner.sectionConfigFrame:Hide()
        else
          frame.Owner.windowGrouping:Show("sectionConfig")
        end
      end)

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/EJMicroButton-Up", "Show Themes", function()
        if frame.Owner.themeConfigFrame:IsShown() then
          frame.Owner.themeConfigFrame:Hide()
        else
          frame.Owner.windowGrouping:Show("themeConfig")
        end
      end)

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/MainMenuMicroButton-Up", "Open Settings", function()
        contextMenu:Show(frame.Owner.menuList)
      end)

    else
      decoration:Show()
    end
    frame.Owner.sideAnchor:ClearAllPoints()
    frame.Owner.sideAnchor:SetPoint("TOPRIGHT", frame, "TOPLEFT", -35, 0)
    frame.Owner.sideAnchor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -35, 0)
    frame.CloseButton:GwSkinButton(true)
    frame.TitleContainer:Hide()
    frame.NineSlice:Hide()
    frame.Backdrop:Hide()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
    frame.PortraitContainer:Hide()
  end,
  -- The simple panel template, i.e. left config panels.
  Simple = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame)
      decoratorFrames[frame:GetName()] = decoration
      local font = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")
      table.insert(titles, font)
      table.insert(buttons, frame.CloseButton)

      decoration:SetAllPoints()
      decoration:SetFrameStrata("BACKGROUND")

      gw.CreateFrameHeaderWithBody(decoration, font, "", {})

      decoration.gwHeader:ClearAllPoints()
      decoration.gwHeader:SetPoint("BOTTOMLEFT", decoration, "TOPLEFT", 0, -25)
      decoration.gwHeader:SetPoint("BOTTOMRIGHT", decoration, "TOPRIGHT", 0, -25)

      font:ClearAllPoints()
      font:SetPoint("BOTTOMLEFT", decoration.gwHeader, "BOTTOMLEFT", 35, 10)
      font:SetText(frame.TitleContainer.TitleText:GetText())
    else
      decoration:Show()
    end
    frame.CloseButton:GwSkinButton(true)
    frame.TitleContainer:Hide()
    frame.NineSlice:Hide()
    frame.Backdrop:Hide()
    frame.Bg:Hide()
    frame.TopTileStreaks:Hide()
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