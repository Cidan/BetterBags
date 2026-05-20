local addonName = ... ---@type string
local gw = GW2_ADDON

local GW2_UI_ADDON_IDS = {
  "GW2_UI",
  "GW2_UI_Mainline",
  "GW2_UI_Mists",
  "GW2_UI_TBC",
  "GW2_UI_Vanilla",
  "GW2_UI_Classic",
  "GW2_UI_Wrath",
}

local function getAddonInfo(addonNameOrIndex)
  local api = C_AddOns
  local fn = api and api.GetAddOnInfo or GetAddOnInfo
  if not fn then return nil end

  local ok, name, title, notes, loadable, reason, security = pcall(fn, addonNameOrIndex)
  if not ok or reason == "MISSING" then return nil end
  return name, title, notes, loadable, reason, security
end

local function getAddonEnableState(gw2AddonName)
  local fallbackState

  if C_AddOns and C_AddOns.GetAddOnEnableState then
    local checks = {
      { gw2AddonName },
      { gw2AddonName, "player" },
      { "player", gw2AddonName },
    }
    for _, args in ipairs(checks) do
      local ok, state = pcall(C_AddOns.GetAddOnEnableState, unpack(args))
      if ok and state ~= nil then
        if state > 0 then return state end
        fallbackState = fallbackState or state
      end
    end
  end

  if GetAddOnEnableState then
    local checks = {
      { "player", gw2AddonName },
      { gw2AddonName },
    }
    for _, args in ipairs(checks) do
      local ok, state = pcall(GetAddOnEnableState, unpack(args))
      if ok and state ~= nil then
        if state > 0 then return state end
        fallbackState = fallbackState or state
      end
    end
  end

  return fallbackState
end

local function getNumAddOns()
  if C_AddOns and C_AddOns.GetNumAddOns then
    local ok, count = pcall(C_AddOns.GetNumAddOns)
    if ok then return count end
  end
  if GetNumAddOns then
    local ok, count = pcall(GetNumAddOns)
    if ok then return count end
  end
  return 0
end

local function addonEnabledById(gw2AddonName)
  local name, _, _, loadable, reason = getAddonInfo(gw2AddonName)
  if not name then return false end

  local state = getAddonEnableState(name)
  if state ~= nil then return state > 0 end

  return loadable ~= false and reason ~= "DISABLED"
end

local function normalizeAddonTitle(value)
  value = tostring(value or ""):lower()
  value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  value = value:gsub("[^%w]+", " ")
  return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function addonTitleLooksLikeGW2UI(title)
  local normalized = normalizeAddonTitle(title)
  return normalized == "gw2 ui" or normalized:match("^gw2 ui ")
end

local function findEnabledGW2UIAddon()
  for _, gw2AddonName in ipairs(GW2_UI_ADDON_IDS) do
    if addonEnabledById(gw2AddonName) then return gw2AddonName end
  end

  for i = 1, getNumAddOns() do
    local name, title = getAddonInfo(i)
    if name and addonTitleLooksLikeGW2UI(title or name) and addonEnabledById(name) then
      return name
    end
  end
  return nil
end

local gw2AddonName = findEnabledGW2UIAddon() or (gw and "GW2_UI" or nil)

local function gw2Texture(path)
  return "Interface/AddOns/" .. (gw2AddonName or "GW2_UI") .. "/" .. path
end

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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
  Available = gw ~= nil and gw2AddonName ~= nil,
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      decoration = CreateFrame("Frame", frame:GetName() .. "GW2", frame) --[[@as GuildWarsDecoration]]
      decoration.panelButtons = {}
      decoration.title = decoration:CreateFontString(frame:GetName().."GW2_title", "OVERLAY", "GameFontNormal")

      decoration:SetAllPoints()
      decoration:SetFrameStrata("BACKGROUND")

      gw.CreateFrameHeaderWithBody(decoration, decoration.title, gw2Texture("textures/bag/bagicon"), {})

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
      footer:SetTexture(gw2Texture("textures/bag/bagfooter"))
      footer:SetHeight(55)
      footer:SetPoint("TOPLEFT", decoration, "BOTTOMLEFT", 0, 30)
      footer:SetPoint("TOPRIGHT", decoration, "BOTTOMRIGHT", -3, 30)

      local leftSide = decoration:CreateTexture(decoration:GetName().."Left", "BACKGROUND", nil, 7)
      leftSide:SetTexture(gw2Texture("textures/bag/bagleftpanel"))
      leftSide:SetWidth(40)
      leftSide:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 25)
      leftSide:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 25)

      newPanelButton(decoration, gw2Texture("Textures/icons/bagmicrobutton-up"), "Show Bags", function(ctx)
        if frame.Owner.slots:IsShown() then
          -- Persist bank-slots visibility to DB so re-opening the bank restores the correct state.
          if frame.Owner.kind == const.BAG_KIND.BANK then
            database:SetShowBankTabs(false)
          end
          frame.Owner.slots:Hide()
        else
          if frame.Owner.kind == const.BAG_KIND.BANK then
            database:SetShowBankTabs(true)
          end
          frame.Owner.slots:Draw(ctx)
          frame.Owner.slots:Show()
        end
      end)

      newPanelButton(decoration, gw2Texture("Textures/icons/microicons/collectionsmicrobutton-up"), "Sort Bags", function(ctx)
        frame.Owner:Sort(ctx)
      end)

      newPanelButton(decoration, gw2Texture("Textures/icons/microicons/questlogmicrobutton-up.png"), "Open Settings", function()
        local ctx = context:New("GW2OpenSettings")
        events:SendMessage(ctx, "config/Open")
      end)

      newPanelButton(decoration, gw2Texture("Textures/icons/microicons/mainmenumicrobutton-up"), "Open Settings", function(ctx)
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
