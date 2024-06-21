local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Search: AceModule
local search = addon:GetModule('Search')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class SimpleDarkDecoration: Frame
---@field title FontString
---@field search SearchFrame

---@type table<string, SimpleDarkDecoration>
local decoratorFrames = {}

---@type Theme
local simpleDark = {
  -- This is the name of the theme, as it appears in the UI when selecting themes.
  Name = 'Simple Dark',
  -- This is a description of the theme, as it appears in the UI when selecting themes.
  Description = 'A simple dark theme.',
  -- This is a boolean that determines if the theme is available to the user. You can use this to
  -- detect if the user has a specific addon installed, or if a specific condition is met, and only
  -- then present this theme, i.e. only show this theme if ElvUI is installed.
  Available = true,
  -- This function will theme a portrait frame. These frames are used for the main bag and
  -- bank windows.
  Portrait = function(frame)
    -- 'frame' is the main frame of the window. Do not add anything to this frame
    -- except for your decoration frame.

    -- You want to only generate your decoration frame once, when the user first activates the theme.
    -- After generation, you need to cache the decoration frame so you can show and hide it as needed.
    local decoration = decoratorFrames[frame:GetName()]

    -- The decoration does not exist, so make it.
    if not decoration then
      -- A decoration is just another frame that we "overlay" on top of the 'frame' provided by this function
      -- This decoration will be used to add a backdrop, title, and close button to the frame.
      decoration = CreateFrame("Frame", frame:GetName().."ThemeSimpleDark", frame, "BackdropTemplate") --[[@as SimpleDarkDecoration]]
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

      -- Titles for frames can change at any time, so make sure you pull the title text
      -- from the themes title table for this specific frame.
      if themes.titles[frame:GetName()] then
        decoration.title:SetText(themes.titles[frame:GetName()])
      end

      local close = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonNoScripts")
      close:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", 1, 0)
      close:SetScript("OnClick", function()
        -- frame.Owner is the bag construct itself in 'frames\bag.lua'. You can use this
        -- to access the bag construct's methods and properties if needed.
        frame.Owner:Hide()
      end)

      local searchBox = search:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
      searchBox.frame:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", -22, -2)
      searchBox.frame:SetSize(150, 20)
      decoration.search = searchBox

      -- The bag button is abstracted here as it's a common element across all themes.
      -- This function does return the bag button, and you can modify it as you need.
      themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])

      -- Save the decoration frame for reuse.
      decoratorFrames[frame:GetName()] = decoration
    else
      -- The decoration frame was previously created here, so just show it.
      decoration:Show()
    end
  end,
  -- Simple frames are the frames for sidebar and configuration screens.
  Simple = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      -- Backdrop
      decoration = CreateFrame("Frame", frame:GetName().."ThemeSimpleDark", frame, "BackdropTemplate") --[[@as SimpleDarkDecoration]]
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

      local close = CreateFrame("Button", nil, decoration, "UIPanelCloseButtonNoScripts")
      close:SetPoint("TOPRIGHT", decoration, "TOPRIGHT", 1, 0)
      close:SetScript("OnClick", function()
        frame:Hide()
      end)

      if themes.titles[frame:GetName()] then
        decoration.title:SetText(themes.titles[frame:GetName()])
      end
      -- Save the decoration frame for reuse.
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  -- Flat frames are small frames with no close buttons, such as modals, the bag slot menu, etc.
  Flat = function (frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      -- Backdrop
      decoration = CreateFrame("Frame", frame:GetName().."ThemeSimpleDark", frame, "BackdropTemplate") --[[@as SimpleDarkDecoration]]
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

      if themes.titles[frame:GetName()] then
        decoration.title:SetText(themes.titles[frame:GetName()])
      end
      -- Save the decoration frame for reuse.
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  -- The Opacity function is called when the user updates the opacity for a given frame. You need
  -- to apply the opacity to the decoration frame you created in the Portrait, Simple, or Flat functions.
  Opacity = function(frame, alpha)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration:SetAlpha(alpha / 100)
    end
  end,
  -- The SetSectionFont function is called when the user updates the font for item sections
  -- such as "Reagent", "Recent Items", etc. This is also applied on load.
  SectionFont = function(font)
    font:SetFont(UNIT_NAME_FONT, 12, "")
    font:SetTextColor(1, 1, 1)
  end,
  -- SetTitle is called when the title of a frame changes.
  SetTitle = function(frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.title:SetText(title)
    end
  end,
  -- Reset is called when your frame is unloaded. You should hide your decoration frames here.
  -- Ideally, all changes made should only exist within a decoration frame, making reset a simple
  -- function to hide all decoration frames.
  Reset = function()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
  end,
  -- ToggleSearch is called when the user enables or disables in-bag search.
  ToggleSearch = function (frame, shown)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.search:SetShown(shown)
    end
  end
}

themes:RegisterTheme('SimpleDark', simpleDark)