
local gw = GW2_ADDON


local addon = GetBetterBags()

local contextMenu = addon:GetContextMenu()

local const = addon:GetConstants()
---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

local themes = addon:GetThemes()

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class GuildWarsDecoration: Frame
---@field panelButtons Button[]
---@field gwHeader GuildWarsHeader
---@field title FontString
---@field search SearchFrame

---@type table<string, GuildWarsDecoration>
local decoratorFrames = {}

---@param panel GuildWarsDecoration
---@param texture string
---@param tooltip string
---@param onClick fun(ctx: Context)
---@return Button
local function newPanelButton(panel, texture, tooltip, onClick)
  local button = CreateFrame("Button", nil, panel)
  button:SetSize(32, 32)
  button:SetNormalTexture(texture)
  button:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
  button:SetHighlightTexture(texture)
  button:GetHighlightTexture():SetTexCoord(0, 1, 0, 1)
  addon.SetScript(button, "OnClick", onClick)
  addon.SetScript(button, "OnEnter", function(_)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
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
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame) --[[@as GuildWarsDecoration]]
      decoration.panelButtons = {}
      decoration.title = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")

      decoration:SetAllPoints()
      decoration:SetFrameStrata("BACKGROUND")

      gw.CreateFrameHeaderWithBody(decoration, decoration.title, "Interface/AddOns/GW2_UI/textures/bag/bagicon", {})

      decoration.gwHeader:ClearAllPoints()
      decoration.gwHeader:SetPoint("BOTTOMLEFT", decoration, "TOPLEFT", 0, -25)
      decoration.gwHeader:SetPoint("BOTTOMRIGHT", decoration, "TOPRIGHT", 0, -25)

      decoration.gwHeader.windowIcon:ClearAllPoints()
      decoration.gwHeader.windowIcon:SetPoint("CENTER", decoration, "TOPLEFT", -16, 0)

      decoration.title:ClearAllPoints()
      decoration.title:SetPoint("BOTTOMLEFT", decoration.gwHeader, "BOTTOMLEFT", 35, 10)
      decoration.title:SetText(themes.titles[frame:GetName()])

      local box = searchBox:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      box.frame:SetPoint("TOPLEFT", decoration, "TOPLEFT", 0, -40)
      box.frame:SetPoint("BOTTOMRIGHT", decoration, "TOPRIGHT", -10, -60)
      box.frame:SetFrameStrata("DIALOG")
      box.frame:SetFrameLevel(decoration:GetFrameLevel() + 1)
      gw.SkinBagSearchBox(box.textBox)
      decoration.search = box

      local close = CreateFrame("Button", nil, decoration.gwHeader, "UIPanelCloseButtonNoScripts")
      close:SetPoint("TOPRIGHT", decoration.gwHeader, "TOPRIGHT", -5, -25)
      addon.SetScript(close, "OnClick", function(ctx)
        frame.Owner:Hide(ctx)
      end)
      close:GwSkinButton(true)

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

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/BagMicroButton-Up", "Show Bags", function(ctx)
        if frame.Owner.slots:IsShown() then
          frame.Owner.slots:Hide()
        else
          frame.Owner.slots:Draw(ctx)
          frame.Owner.slots:Show()
        end
      end)

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/CollectionsMicroButton-Up", "Sort Bags", function(ctx)
        frame.Owner:Sort(ctx)
      end)

      if frame.Owner.kind == const.BAG_KIND.BACKPACK then
        newPanelButton(decoration,  "Interface/AddOns/GW2_UI/Textures/icons/microicons/StoreMicroButton-Up", "Show Currency", function()
          if frame.Owner.currencyFrame:IsShown() then
            frame.Owner.currencyFrame:Hide()
          else
            frame.Owner.windowGrouping:Show("currencyConfig")
          end
        end)
      end

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/QuestLogMicroButton-Up", "Show Categories", function()
        if frame.Owner.sectionConfigFrame:IsShown() then
          frame.Owner.sectionConfigFrame:Hide()
        else
          frame.Owner.windowGrouping:Show("sectionConfig")
        end
      end)

      if frame.Owner.kind == const.BAG_KIND.BACKPACK then
        newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/EJMicroButton-Up", "Show Themes", function()
          if frame.Owner.themeConfigFrame:IsShown() then
            frame.Owner.themeConfigFrame:Hide()
          else
            frame.Owner.windowGrouping:Show("themeConfig")
          end
        end)
      end

      newPanelButton(decoration, "Interface/AddOns/GW2_UI/Textures/icons/microicons/MainMenuMicroButton-Up", "Open Settings", function(ctx)
        contextMenu:Show(ctx, frame.Owner.menuList)
      end)

    else
      decoration:Show()
    end
    decoratorFrames[frame:GetName()] = decoration
  end,
  -- The simple panel template, i.e. left config panels.
  Simple = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame, "BackdropTemplate") --[[@as GuildWarsDecoration]]
      decoratorFrames[frame:GetName()] = decoration
      decoration.title = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")

      decoration:SetAllPoints()
      decoration:SetFrameStrata(frame:GetFrameStrata())
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)

      decoration:SetBackdrop(gw.BackdropTemplates.Default)
      decoration.title:ClearAllPoints()
---@diagnostic disable-next-line: param-type-mismatch
      decoration.title:SetFont(DAMAGE_TEXT_FONT, 16, "")
      decoration.title:SetTextColor(255 / 255, 241 / 255, 209 / 255)
      decoration.title:SetPoint("TOP", decoration, "TOP", 0, -5)
      decoration.title:SetText(themes.titles[frame:GetName()])

      local close = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonNoScripts")
      close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
      addon.SetScript(close, "OnClick", function()
        frame:Hide()
      end)
      close:GwSkinButton(true)
    else
      decoration:Show()
    end
  end,
  Flat = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame, "BackdropTemplate") --[[@as GuildWarsDecoration]]
      decoratorFrames[frame:GetName()] = decoration
      decoration.title = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")

      decoration:SetAllPoints()
      decoration:SetFrameStrata(frame:GetFrameStrata())
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)

      decoration:SetBackdrop(gw.BackdropTemplates.Default)
      decoration.title:ClearAllPoints()
---@diagnostic disable-next-line: param-type-mismatch
      decoration.title:SetFont(DAMAGE_TEXT_FONT, 16, "")
      decoration.title:SetTextColor(255 / 255, 241 / 255, 209 / 255)
      decoration.title:SetPoint("TOP", decoration, "TOP", 0, -5)
      decoration.title:SetText(themes.titles[frame:GetName()])
    else
      decoration:Show()
    end
  end,
  Opacity = function(_, _)
  end,
  SectionFont = function(font)
    font:SetFontObject(fonts.UnitFrame12White)
  end,
  SetTitle = function(frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.title:SetText(title)
    end
  end,
  Reset = function()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
  end,
  ToggleSearch = function (frame, shown)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.search:SetShown(shown)
    end
  end,
  PositionBagSlots = function (frame, bagSlotWindow)
    bagSlotWindow:ClearAllPoints()
    bagSlotWindow:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 8, 16)
  end,
  OffsetSidebar = function()
    return -35
  end
}

themes:RegisterTheme('GW2', gw2Theme)