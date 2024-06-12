local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Theme
---@field key? string The key used to identify this theme. This will be set by the Themes module when registering the theme, you do not need to provide this.
---@field Name string The display name used by this theme in the theme selection window.
---@field Description string A description of the theme used by this theme in the theme selection window.
---@field Available boolean Whether or not this theme is available to the user.
---@field Portrait fun(frame: Frame) A function that applies the theme to a portrait frame.
---@field Simple fun(frame: Frame) A function that applies the theme to a simple frame.
---@field Flat fun(frame: Frame) A function that applies the theme to a flat frame.
---@field Opacity fun(frame: Frame, opacity: number) A callback that is called when the user changes the opacity of the frame. You should use this to change the alpha of your backdrops.
---@field SectionFont fun(font: FontString) A function that applies the theme to a section font.
---@field SetTitle fun(frame: Frame, title: string) A function that sets the title of the frame.
---@field Reset fun() A function that resets the theme to its default state and removes any special styling.

---@class Themes: AceModule
---@field themes table<string, Theme>
---@field windows table<WindowKind, Frame[]>
---@field sectionFonts table<string, FontString>
local themes = addon:NewModule('Themes')

-- Initialize this bare as we will be adding themes from bare files.
themes.themes = {}

function themes:OnInitialize()
  self.windows = {
    [const.WINDOW_KIND.PORTRAIT] = {},
    [const.WINDOW_KIND.SIMPLE] = {},
    [const.WINDOW_KIND.FLAT] = {}
  }
  self.sectionFonts = {}
end

function themes:OnEnable()
  local theme = db:GetTheme()
  if self.themes[theme] and self.themes[theme].Available then
    self:ApplyTheme(theme)
  else
    db:SetTheme('Default')
    self:ApplyTheme('Default')
  end
end

---@param key string
---@param themeTemplate Theme
function themes:RegisterTheme(key, themeTemplate)
  themeTemplate.key = key
  self.themes[key] = themeTemplate
end

-- ApplyTheme is used to apply a theme to every window registered with RegisterWindow.
---@param key string
function themes:ApplyTheme(key)
  assert(self.themes[key], 'Theme does not exist.')

  -- Reset the old theme.
  local oldTheme = db:GetTheme()
  if self.themes[oldTheme] then
    self.themes[oldTheme].Reset()
  end

  local theme = self.themes[key]

  -- Apply all portrait themes.
  for _, frame in pairs(self.windows[const.WINDOW_KIND.PORTRAIT]) do
    theme.Portrait(frame)
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end

  -- Apply all simple frame themes.
  for _, frame in pairs(self.windows[const.WINDOW_KIND.SIMPLE]) do
    theme.Simple(frame)
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end

  -- Apply all flat frame themes.
  for _, frame in pairs(self.windows[const.WINDOW_KIND.FLAT]) do
    theme.Flat(frame)
  end

  -- Apply all section fonts.
  for _, font in pairs(self.sectionFonts) do
    theme.SectionFont(font)
  end

  db:SetTheme(key)
end

-- RegisterPortraitWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
function themes:RegisterPortraitWindow(frame)
  table.insert(self.windows[const.WINDOW_KIND.PORTRAIT], frame)
end

-- RegisterSimpleWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
function themes:RegisterSimpleWindow(frame)
  table.insert(self.windows[const.WINDOW_KIND.SIMPLE], frame)
end

-- RegisterFlatWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
function themes:RegisterFlatWindow(frame)
  table.insert(self.windows[const.WINDOW_KIND.FLAT], frame)
end

-- RegisterSectionFont is used to register a font to be used in the section headers.
---@param font FontString
function themes:RegisterSectionFont(font)
  table.insert(self.sectionFonts, font)
end

---@return table<string, Theme>
function themes:GetAllThemes()
  ---@type table<string, Theme>
  local list = {}
  for key, theme in pairs(self.themes) do
    if theme.Available then
      list[key] = theme
    end
  end
  return list
end

function themes:UpdateOpacity()
  local theme = self.themes[db:GetTheme()]
  for _, frame in pairs(self.windows[const.WINDOW_KIND.PORTRAIT]) do
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end
  for _, frame in pairs(self.windows[const.WINDOW_KIND.SIMPLE]) do
    local sizeInfo = db:GetBagSizeInfo(const.BAG_KIND.BACKPACK, db:GetBagView(const.BAG_KIND.BACKPACK))
    theme.Opacity(frame, sizeInfo.opacity)
  end
end

---@param font FontString
function themes:UpdateSectionFont(font)
  local theme = self.themes[db:GetTheme()]
  theme.SectionFont(font)
end

---@param button Button
function themes:resetCloseButton(button)
  button:SetDisabledAtlas("RedButton-Exit-Disabled")
  button:SetNormalAtlas("RedButton-Exit")
  button:SetPushedAtlas("RedButton-exit-pressed")
  button:SetHighlightAtlas("RedButton-Highlight", "ADD")
end

function themes:SetTitle(frame, title)
  local theme = self.themes[db:GetTheme()]
  theme.SetTitle(frame, title)
end

---@param bag Bag
---@param decoration Frame
function themes.SetupBagButton(bag, decoration)
  -- JIT include the context menu, due to load order.

  ---@class ContextMenu: AceModule
  local contextMenu = addon:GetModule('ContextMenu')

  local bagButton = CreateFrame("Button", nil, decoration)
  bagButton:EnableMouse(true)
  bagButton:SetHighlightTexture([[Interface\AddOns\BetterBags\Textures\glow.png]])
  bagButton:SetWidth(40)
  bagButton:SetHeight(40)
  bagButton:SetPoint("TOPLEFT", decoration.PortraitContainer.portrait, "TOPLEFT", -1, 2)
  bagButton:SetFrameLevel(950)

  local highlightTex = bagButton:CreateTexture("BetterBagsBagButtonTextureHighlight", "BACKGROUND")
  highlightTex:SetTexture([[Interface\AddOns\BetterBags\Textures\glow.png]])
  highlightTex:SetAllPoints()
  highlightTex:SetAlpha(0)

  local anig = highlightTex:CreateAnimationGroup("BetterBagsBagButtonTextureHighlightAnim")
  local ani = anig:CreateAnimation("Alpha")
  ani:SetFromAlpha(0)
  ani:SetToAlpha(1)
  ani:SetDuration(0.2)
  ani:SetSmoothing("IN")
  if db:GetFirstTimeMenu() then
    ani:SetDuration(0.4)
    anig:SetLooping("BOUNCE")
    anig:Play()
  end
  bagButton:SetScript("OnEnter", function()
    if not db:GetFirstTimeMenu() then
      anig:Stop()
      highlightTex:SetAlpha(1)
      anig:Play()
    end
    GameTooltip:SetOwner(bagButton, "ANCHOR_LEFT")
    if bag.kind == const.BAG_KIND.BACKPACK then
      GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Sort Bags"), 1, 0.81, 0, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Swap Between Bank/Reagent Bank"), 1, 0.81, 0, 1, 1, 1)
    end

    if CursorHasItem() then
      local cursorType, _, itemLink = GetCursorInfo()
      if cursorType == "item" then
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(format(L:G("Drop %s here to create a new category for it."), itemLink), 1, 1, 1)
      end
    end
    GameTooltip:Show()
  end)
  bagButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not db:GetFirstTimeMenu() then
      anig:Stop()
      highlightTex:SetAlpha(0)
      anig:Restart(true)
    end
  end)
  bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  bagButton:SetScript("OnReceiveDrag", bag.CreateCategoryForItemInCursor)
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      if db:GetFirstTimeMenu() then
        db:SetFirstTimeMenu(false)
        highlightTex:SetAlpha(1)
        anig:SetLooping("NONE")
        anig:Restart()
      end
      if IsShiftKeyDown() then
        BetterBags_ToggleSearch()
      elseif CursorHasItem() and GetCursorInfo() == "item" then
        bag:CreateCategoryForItemInCursor()
      else
        contextMenu:Show(bag.menuList)
      end

    elseif e == "RightButton" and bag.kind == const.BAG_KIND.BANK then
      bag:ToggleReagentBank()
    elseif e == "RightButton" and bag.kind == const.BAG_KIND.BACKPACK then
      bag:Sort()
    end
  end)
end