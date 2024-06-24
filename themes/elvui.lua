---@diagnostic disable: duplicate-set-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@type ElvUI
local E
---@type ElvUISkin
local S

if ElvUI then
  E = unpack(ElvUI --[[@as ElvUI]]) --[[@as ElvUI]]
  S = E:GetModule('Skins')
end

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class ElvUIDecoration: Frame
---@field title FontString
---@field search SearchFrame

---@type table<string, ElvUIDecoration>
local decoratorFrames = {}

---@type table<string, ItemButton>
local itemButtons = {}

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
        frame.Owner:Hide()
      end)
      decoration.CloseButton:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -4, -4)
      decoration.CloseButton:SetSize(24,24)
      decoration.CloseButton:SetFrameLevel(1001)

      local searchBox = search:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      searchBox.frame:SetPoint("TOP", decoration, "TOP", 0, -14)
      searchBox.frame:SetSize(150, 20)
      decoration.search = searchBox

      local title = decoration:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      title:SetPoint("TOP", decoration, "TOP", 0, 0)
      title:SetHeight(30)
      decoration.title = title

      if themes.titles[frame:GetName()] then
        decoration.title:SetText(themes.titles[frame:GetName()])
      end

      local bagButton = themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
      bagButton:SetPoint("TOPLEFT", decoration, "TOPLEFT", 4, -6)
      local w, h = bagButton.portrait:GetSize()
      bagButton.portrait:SetSize((w / 10) * 8.5, (h / 10) * 8.5)
      bagButton.highlightTex:SetSize((w / 10) * 8.5, (h / 10) * 8.5)
      S:HandleEditBox(searchBox.frame)
      S:HandleFrame(decoration)
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Simple = function (frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeElvUI", frame) --[[@as ElvUIDecoration]]
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.CloseButton = CreateFrame("Button", frame:GetName().."CloseButton", decoration) --[[@as Button]]
      decoration.CloseButton:SetScript("OnClick", function()
        frame:Hide()
      end)
      decoration.CloseButton:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -4, -4)
      decoration.CloseButton:SetSize(24,24)
      decoration.CloseButton:SetFrameLevel(1001)

      local title = decoration:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      title:SetPoint("TOP", decoration, "TOP", 0, 0)
      title:SetHeight(30)
      decoration.title = title

      if themes.titles[frame:GetName()] then
        decoration.title:SetText(themes.titles[frame:GetName()])
      end

      S:HandleFrame(decoration)
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Flat = function (frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeElvUI", frame) --[[@as ElvUIDecoration]]
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      S:HandleFrame(decoration)
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  Opacity = function (frame, opacity)
    -- This function isn't used, as ElvUI manages the opacity of its frames.
    _ = frame
    _ = opacity
  end,
  Reset = function ()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
    for _, button in pairs(itemButtons) do
      button:Hide()
    end
  end,
  SectionFont = function (font)
    font:SetFontObject("GameFontNormal")
  end,
  SetTitle = function (frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.title:SetText(title)
    end
  end,
  ToggleSearch = function (frame, shown)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.search:SetShown(shown)
      if shown then
        decoration.title:Hide()
      else
        decoration.title:Show()
      end
    end
  end,
  ItemButton = function(item)
    local buttonName = item.button:GetName()
    local button = itemButtons[buttonName]
    if button then
      button:Show()
      return button
    end
    button = themes.CreateBlankItemButtonDecoration(item.frame, "ElvUI", buttonName)
    S:HandleItemButton(button, true)
    S:HandleIconBorder(button.IconBorder)
    button:Show()

    button:GetNormalTexture():SetAlpha(0)
    button:SetHighlightTexture(E.Media.Textures.White8x8)
    button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.3)
    button:SetPushedTexture(E.Media.Textures.White8x8)
    button:GetPushedTexture():SetVertexColor(1, 1, 1, 0.3)

    local quest_overlay = button:CreateTexture(nil, "OVERLAY")
    quest_overlay:SetTexture(E.Media.Textures.BagQuestIcon)
    quest_overlay:SetTexCoord(0, 1, 0, 1)
    quest_overlay:SetAllPoints()
    quest_overlay:Hide()
    if button.IconQuestTexture then
      button.IconQuestTexture:Hide()
      button.IconQuestTexture.Show = function()
        quest_overlay:Show()
        --button.IconBorder:SetVertexColor(1, 0.8, 0, 1)
      end
      button.IconQuestTexture.Hide = function()
        quest_overlay:Hide()
        --button.IconBorder:SetVertexColor(1, 1, 1, 1)
      end
    end
    E:RegisterCooldown(button.Cooldown, 'bags')
    itemButtons[buttonName] = button
    return button
  end,
}
themes:RegisterTheme('elvui', theme)