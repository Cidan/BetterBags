---@diagnostic disable: duplicate-set-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Constants
local const = addon:GetModule('Constants')

---@class ElvItemButton: ItemButton
---@field SetTemplate fun(self:ElvItemButton|ItemButton, template?: string, texture: boolean)

---@type ElvUI
local E
---@type ElvUISkin
local S

if ElvUI then
  E = unpack(ElvUI --[[@as ElvUI]]) --[[@as ElvUI]]
  S = E:GetModule('Skins')
end

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class ElvUIDecoration: Frame
---@field title FontString
---@field search SearchFrame
---@field backdrop Frame

---@type table<string, ElvUIDecoration>
local decoratorFrames = {}

---@type table<string, ItemButton>
local itemButtons = {}

---@type table<string, PanelTabButtonTemplate>
local tabs = {}

---@type Theme
local theme = {
  Name = 'ElvUI',
  Description = "An ElvUI Theme for BetterBags",
  Available = ElvUI and true or false,
  DisableMasque = true,
  Portrait = function (frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName().."ThemeElvUI", frame) --[[@as ElvUIDecoration]]
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      decoration.CloseButton = CreateFrame("Button", frame:GetName().."CloseButton", decoration) --[[@as Button]]
      addon.SetScript(decoration.CloseButton, "OnClick", function(ctx)
        frame.Owner:Hide(ctx)
      end)
      decoration.CloseButton:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -4, -4)
      decoration.CloseButton:SetSize(24,24)
      decoration.CloseButton:SetFrameLevel(1001)

      local box = searchBox:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      box.frame:SetPoint("TOPLEFT", decoration, "TOPLEFT", 10, -40)
      box.frame:SetPoint("BOTTOMRIGHT", decoration, "TOPRIGHT", -10, -60)
      decoration.search = box

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
      S:HandleEditBox(box.textBox)
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
    local _ = frame
    _ = opacity
  end,
  Reset = function ()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
    for _, button in pairs(itemButtons) do
      button:Hide()
    end
    for _, tab in pairs(tabs) do
      tab:Hide()
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
    end
  end,
  ItemButton = function(item)
    local buttonName = item.button:GetName()
    local button = itemButtons[buttonName]
    if button then
      button.backdrop:SetFrameLevel(0)
      button:Show()
      return button
    end
    button = themes.CreateBlankItemButtonDecoration(item.frame, "ElvUI", buttonName)
    S:HandleItemButton(button, true)
    S:HandleIconBorder(button.IconBorder)
    button:Show()
    if not addon.isRetail then
      button.searchOverlay = button:CreateTexture(nil, "ARTWORK")
      button.searchOverlay:SetColorTexture(0, 0, 0, 0.8)
      button.searchOverlay:SetAllPoints()
    end

    button:GetNormalTexture():SetAlpha(0)
    button:SetHighlightTexture(E.Media.Textures.White8x8)
    button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.3)
    button:SetPushedTexture(E.Media.Textures.White8x8)
    button:GetPushedTexture():SetVertexColor(1, 1, 1, 0.3)
    -- Cache the common quality value with defensive nil checking
    local commonQuality = const and const.ITEM_QUALITY and const.ITEM_QUALITY.Common
    if button.SetItemButtonQuality and commonQuality then
      hooksecurefunc(button, 'SetItemButtonQuality', function(_, quality)
        -- ElvUI Icon Borders are super edgy.
        if quality == commonQuality then
          button.IconBorder:SetVertexColor(0, 0, 0, 1)
        end
      end)
    end
    local quest_overlay = button:CreateTexture(nil, "OVERLAY")
    quest_overlay:SetTexture(E.Media.Textures.BagQuestIcon)
    quest_overlay:SetTexCoord(0, 1, 0, 1)
    quest_overlay:SetAllPoints()
    quest_overlay:Hide()
    if button.IconQuestTexture then
      button.IconQuestTexture:Hide()
      button.IconQuestTexture.Show = function()
        quest_overlay:Show()
        button.IconBorder:SetVertexColor(1, 0.8, 0, 1)
      end
      button.IconQuestTexture.Hide = function()
        quest_overlay:Hide()
      end
    end
    if button.Cooldown then
      E:RegisterCooldown(button.Cooldown, 'bags')
    end
    button.UpgradeIcon:SetTexture(E.Media.Textures.BagUpgradeIcon)
    button.UpgradeIcon:SetScale(1.2)
    button.backdrop:SetFrameLevel(0)
    itemButtons[buttonName] = button --[[@as ItemButton]]
    return button --[[@as ItemButton]]
  end,
  Tab = function(tab)
    local tabName = tab:GetName()
    local decoration = tabs[tabName]
    if decoration then
      decoration:Show()
      return decoration
    end
    decoration = themes.CreateDefaultTabDecoration(tab --[[@as TabButton]])
    S:HandleTab(decoration)
    tabs[tabName] = decoration
    return decoration
  end,
}
themes:RegisterTheme('elvui', theme)
