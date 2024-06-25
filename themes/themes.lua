local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class BagButton: Button
---@field portrait Texture
---@field highlightTex Texture

---@class (exact) Theme
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
---@field ToggleSearch fun(frame: Frame, shown: boolean) A function that toggles the search box on the frame.
---@field PositionBagSlots? fun(frame: Frame, bagSlotWindow: Frame) A function that positions the bag slots on the frame.
---@field OffsetSidebar? fun(): number A function that offsets the sidebar by x pixels. 
---@field ItemButton? fun(button: Item): ItemButton A function that applies the theme to an item button.
---@field Reset fun() A function that resets the theme to its default state and removes any special styling.

---@class Themes: AceModule
---@field themes table<string, Theme>
---@field windows table<WindowKind, Frame[]>
---@field sectionFonts table<string, FontString>
---@field titles table<string, string>
---@field itemButtons table<string, ItemButton>
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
  self.titles = {}
  self.itemButtons = {}
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
    theme.ToggleSearch(frame, db:GetInBagSearch())
    -- Apply bagslots positioning if the theme has a custom function for it.
    if frame.Owner.slots then
      if theme.PositionBagSlots then
        theme.PositionBagSlots(frame, frame.Owner.slots.frame)
      else
        frame.Owner.slots.frame:ClearAllPoints()
        frame.Owner.slots.frame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 14)
      end
    end

    local offset = 0
    if theme.OffsetSidebar then
      offset = theme.OffsetSidebar()
    end
    frame.Owner.sideAnchor:ClearAllPoints()
    frame.Owner.sideAnchor:SetPoint("TOPRIGHT", frame, "TOPLEFT", offset, 0)
    frame.Owner.sideAnchor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", offset, 0)
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

  for _, button in pairs(self.itemButtons) do
    button:Hide()
  end

  db:SetTheme(key)
  --TODO(lobato): Create a new message just for redrawing items.
  events:SendMessage('bags/FullRefreshAll')
end

-- SetSearchState will show or hide the search bar for the given frame.
---@param frame Frame
---@param shown boolean
function themes:SetSearchState(frame, shown)
  local theme = self.themes[db:GetTheme()]
  theme.ToggleSearch(frame, shown)
end

-- RegisterPortraitWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
---@param title string
function themes:RegisterPortraitWindow(frame, title)
  table.insert(self.windows[const.WINDOW_KIND.PORTRAIT], frame)
  self.titles[frame:GetName()] = title
end

-- RegisterSimpleWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
---@param title string
function themes:RegisterSimpleWindow(frame, title)
  table.insert(self.windows[const.WINDOW_KIND.SIMPLE], frame)
  self.titles[frame:GetName()] = title
end

-- RegisterFlatWindow is used to register a protrait window frame to be themed by themes.
---@param frame Frame
---@param title string
function themes:RegisterFlatWindow(frame, title)
  table.insert(self.windows[const.WINDOW_KIND.FLAT], frame)
  self.titles[frame:GetName()] = title
end

-- RegisterSectionFont is used to register a font to be used in the section headers.
---@param font FontString
function themes:RegisterSectionFont(font)
  table.insert(self.sectionFonts, font)
end

---@param button Item
function themes:UpdateItemButton(button)
  local theme = self.themes[db:GetTheme()]
  if theme.ItemButton then
    theme.ItemButton(button)
  end
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
  self.titles[frame:GetName()] = title
end

---@param item Item
---@return ItemButton
function themes:GetItemButton(item)
  local theme = self.themes[db:GetTheme()]
  if theme.ItemButton then
    return theme.ItemButton(item)
  end
  local buttonName = item.button:GetName()
  local button = self.itemButtons[buttonName]
  if button then
    button:Show()
    events:SendMessage('item/NewButton', item, button)
    return button
  end
  button = themes.CreateBlankItemButtonDecoration(item.frame, "default", buttonName)
  events:SendMessage('item/NewButton', item, button)
  self.itemButtons[buttonName] = button
  return button
end

---@param parent Button|ItemButton|Frame
---@param theme string
---@param buttonName string
---@return ItemButton
function themes.CreateBlankItemButtonDecoration(parent, theme, buttonName)
  ---@type ItemButton
  local button
  if not addon.isClassic then
    button = CreateFrame("ItemButton", buttonName.."Decoration"..theme, parent, "ContainerFrameItemButtonTemplate") --[[@as ItemButton]]
    button:SetAllPoints()
  else
    button = CreateFrame("Button", buttonName.."Decoration"..theme, parent, "ContainerFrameItemButtonTemplate") --[[@as ItemButton]]
    button:SetAllPoints()
    button.SetMatchesSearch = function(me, match)
      if match then
        me.searchOverlay:Hide()
      else
        me.searchOverlay:Show()
      end
    end
  end

  if addon.isRetail then
    button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
    button.ItemSlotBackground:SetAllPoints(button)
    button.ItemSlotBackground:Hide()
  end

  button:SetFrameLevel(parent:GetFrameLevel() > 0 and parent:GetFrameLevel() - 1 or 0)
  button.IconTexture = _G[buttonName.."Decoration"..theme.."IconTexture"]
  if not button.IconQuestTexture then
    button.IconQuestTexture = _G[buttonName.."Decoration"..theme.."IconQuestTexture"]
  end
  button:Show()
  return button
end

---@param bag Bag
---@param decoration Frame
---@return BagButton
function themes.SetupBagButton(bag, decoration)
  -- JIT include the context menu, due to load order.

  ---@class ContextMenu: AceModule
  local contextMenu = addon:GetModule('ContextMenu')

  local bagButton = CreateFrame("Button", nil, decoration) --[[@as BagButton]]
  bagButton:SetFrameStrata("HIGH")
  bagButton:EnableMouse(true)
  bagButton:SetWidth(40)
  bagButton:SetHeight(40)
  bagButton:SetPoint("TOPLEFT", decoration, "TOPLEFT", -10, 7)
  bagButton:SetFrameLevel(1001)

  local portraitSize = 48
  bagButton.portrait = bagButton:CreateTexture()
  bagButton.portrait:SetTexture([[Interface\Containerframe\Bagslots2x]])
  bagButton.portrait:SetTexCoord(0, 0.2, 0, 1)
  bagButton.portrait:SetSize(portraitSize, portraitSize * 1.25)
  bagButton.portrait:SetPoint("CENTER", bagButton, "CENTER", 0, 0)
  bagButton.portrait:SetDrawLayer("OVERLAY", 7)

  bagButton.highlightTex = bagButton:CreateTexture("BetterBagsBagButtonTextureHighlight", "BACKGROUND")
  bagButton.highlightTex:SetTexture([[Interface\Containerframe\Bagslots2x]])
  bagButton.highlightTex:SetSize(portraitSize, portraitSize * 1.25)
  bagButton.highlightTex:SetTexCoord(0.2, 0.3992, 0, 1)
  bagButton.highlightTex:SetPoint("CENTER", bagButton, "CENTER", 2, 0)
  bagButton.highlightTex:SetAlpha(0)
  bagButton.highlightTex:SetDrawLayer("OVERLAY", 7)

  local anig = bagButton.highlightTex:CreateAnimationGroup("BetterBagsBagButtonTextureHighlightAnim")
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
      bagButton.highlightTex:SetAlpha(1)
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
      bagButton.highlightTex:SetAlpha(0)
      anig:Restart(true)
    end
  end)
  bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  bagButton:SetScript("OnReceiveDrag", bag.CreateCategoryForItemInCursor)
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      if db:GetFirstTimeMenu() then
        db:SetFirstTimeMenu(false)
        bagButton.highlightTex:SetAlpha(1)
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
  return bagButton
end