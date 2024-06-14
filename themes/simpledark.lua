local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type table<string, Frame>
local decoratorFrames = {}

---@type Theme
local simpleDark = {
  Name = 'Simple Dark',
  Description = 'A simple dark theme.',
  Available = true,
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      -- Backdrop
      decoration = CreateFrame("Frame", frame:GetName().."ThemeSimpleDark", frame, "BackdropTemplate")
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration:SetBackdrop({
        bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
        edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
      })
      decoration:SetBackdropColor(0, 0, 0, 1)
      decoration:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

      -- Title text
      local title = decoration:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      title:SetFont(UNIT_NAME_FONT, 12, "")
      title:SetTextColor(1, 1, 1)
      title:SetPoint("TOP", decoration, "TOP", 0, 0)
      title:SetHeight(30)
      decoration.title = title

      themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
      -- Save the decoration frame for reuse.
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
    --frame.NineSlice:Hide()
    --frame.Bg:Hide()
    --frame.TopTileStreaks:Hide()
    --frame.PortraitContainer.CircleMask:SetTexture([[Interface\Common\Common-IconMask]])
    --frame.PortraitContainer.CircleMask:SetPoint("TOPLEFT", frame.PortraitContainer.portrait, "TOPLEFT", 2, -2)
    --frame.PortraitContainer.CircleMask:SetPoint("BOTTOMRIGHT", frame.PortraitContainer.portrait, "BOTTOMRIGHT", -2, 1)
    --frame:SetPortraitTextureSizeAndOffset(30, 4, -7)
    --frame.Backdrop:SetBackdrop({
    --  bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
    --  edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    --  edgeSize = 16,
    --  insets = {left = 4, right = 4, top = 4, bottom = 4}
    --})
    --frame.Backdrop:SetBackdropColor(0, 0, 0, 1)
    --frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    --frame.Backdrop:Show()
    --frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    --frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    --frame.TitleContainer:Show()
    --frame.PortraitContainer:Show()
    --frame.Owner.sideAnchor:ClearAllPoints()
    --frame.Owner.sideAnchor:SetPoint("TOPRIGHT", frame, "TOPLEFT")
    --frame.Owner.sideAnchor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
    --themes:resetCloseButton(frame.CloseButton)
    --frame.CloseButton:Show()
  end,
  Simple = function(frame)
    --frame.NineSlice:Hide()
    --frame.Bg:Hide()
    --frame.TopTileStreaks:Hide()
    --frame.Backdrop:SetBackdrop({
    --  bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
    --  edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    --  edgeSize = 16,
    --  insets = {left = 4, right = 4, top = 4, bottom = 4}
    --})
    --frame.Backdrop:SetBackdropColor(0, 0, 0, 1)
    --frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    --frame.Backdrop:Show()
    --frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    --frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    --frame.TitleContainer:Show()
    --themes:resetCloseButton(frame.CloseButton)
    --frame.CloseButton:Show()
  end,
  Flat = function (frame)
    --frame.NineSlice:Hide()
    --frame.Bg:Hide()
    --frame.Backdrop:SetBackdrop({
    --  bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
    --  edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
    --  edgeSize = 16,
    --  insets = {left = 4, right = 4, top = 4, bottom = 4}
    --})
    --frame.Backdrop:SetBackdropColor(0, 0, 0, 1)
    --frame.Backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    --frame.Backdrop:Show()
    --frame.TitleContainer.TitleText:SetFont(UNIT_NAME_FONT, 12, "")
    --frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    --frame.TitleContainer:Show()
  end,
  Opacity = function(frame, alpha)
    --frame.Backdrop:SetBackdropColor(0, 0, 0, alpha / 100)
  end,
  SectionFont = function(font)
    font:SetFont(UNIT_NAME_FONT, 12, "")
    font:SetTextColor(1, 1, 1)
  end,
  SetTitle = function(frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.title:SetText(title)
    end
    --frame.TitleContainer.TitleText:SetText(title)
  end,
  Reset = function()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
  end
}

themes:RegisterTheme('SimpleDark', simpleDark)