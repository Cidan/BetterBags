local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

-- BagMenuButton is the round portrait button at the top left of the backpack and the bank.
-- The bag owns it; a theme places it (its bag window's Layout.MenuButton) and styles it (the
-- BagButton element). Its clicks are in .claude/rules/bag-menu-button.md.
---@class BagMenuButton: AceModule
local menuButton = addon:NewModule('BagMenuButton')

-- The level above the window's overlay (its close button sits at overlay + 1).
local LEVEL_ABOVE_OVERLAY = 3

---@class BagButton: Button
---@field portrait Texture
---@field highlightTex Texture
---@field highlightAnimation AnimationGroup

---@param button BagButton
---@param bag Bag
local function showTooltip(button, bag)
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
  GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
  if bag.kind == const.BAG_KIND.BACKPACK then
    GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Sort Bags"), 1, 0.81, 0, 1, 1, 1)
  elseif addon.isRetail then
    GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Sort Bank"), 1, 0.81, 0, 1, 1, 1)
    if addon.hasWarbank then
      GameTooltip:AddDoubleLine(L:G("Shift Right Click"), L:G("Deposit Warbank Items"), 1, 0.81, 0, 1, 1, 1)
    end
  end
  if CursorHasItem() then
    local cursorType, _, itemLink = GetCursorInfo()
    if cursorType == "item" then
      GameTooltip:AddLine(" ", 1, 1, 1)
      GameTooltip:AddLine(format(L:G("Drop %s here to create a new category for it."), itemLink), 1, 1, 1)
    end
  end
  GameTooltip:Show()
end

-- Sort is the menu button's right click: it sorts the bag (on the retail bank, the bank type
-- of the active tab), or with Shift deposits into the Warbank. A theme's Sort action button
-- (frames/bagactions.lua) does the same.
---@param ctx Context
---@param bag Bag
function menuButton:Sort(ctx, bag)
  if bag.kind ~= const.BAG_KIND.BANK or not addon.isRetail then
    bag:Sort(ctx)
    return
  end
  if not addon.hasWarbank then
    events:SendMessage(ctx, "bags/SortBank")
  elseif IsShiftKeyDown() then
    C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)
  elseif const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bag.bankTab] then
    events:SendMessage(ctx, "bags/SortWarbank")
  else
    events:SendMessage(ctx, "bags/SortBank")
  end
end

-- Create builds the menu button for bag, on the bag's frame.
---@param bag Bag
---@return BagButton
function menuButton:Create(bag)
  local button = CreateFrame("Button", nil, bag.frame) --[[@as BagButton]]
  button:SetFrameStrata("HIGH")
  button:EnableMouse(true)
  button:SetSize(40, 40)

  button.portrait = button:CreateTexture()
  button.portrait:SetTexture([[Interface\Containerframe\Bagslots2x]])
  button.portrait:SetTexCoord(0, 0.2, 0, 1)
  button.portrait:SetSize(48, 60)
  button.portrait:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.portrait:SetDrawLayer("OVERLAY", 7)

  button.highlightTex = button:CreateTexture(nil, "BACKGROUND")
  button.highlightTex:SetTexture([[Interface\Containerframe\Bagslots2x]])
  button.highlightTex:SetSize(48, 60)
  button.highlightTex:SetTexCoord(0.2, 0.3992, 0, 1)
  button.highlightTex:SetPoint("CENTER", button, "CENTER", 2, 0)
  button.highlightTex:SetAlpha(0)
  button.highlightTex:SetDrawLayer("OVERLAY", 7)

  local animation = button.highlightTex:CreateAnimationGroup()
  local fade = animation:CreateAnimation("Alpha")
  fade:SetFromAlpha(0)
  fade:SetToAlpha(1)
  fade:SetDuration(0.2)
  fade:SetSmoothing("IN")
  button.highlightAnimation = animation
  if db:GetFirstTimeMenu() then
    fade:SetDuration(0.4)
    animation:SetLooping("BOUNCE")
    animation:Play()
  end

  addon.SetScript(button, "OnEnter", function()
    if not db:GetFirstTimeMenu() then
      animation:Stop()
      button.highlightTex:SetAlpha(1)
      animation:Play()
    end
    showTooltip(button, bag)
  end)
  addon.SetScript(button, "OnLeave", function()
    GameTooltip:Hide()
    if not db:GetFirstTimeMenu() then
      animation:Stop()
      button.highlightTex:SetAlpha(0)
      animation:Restart(true)
    end
  end)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  addon.SetScript(button, "OnReceiveDrag", function(ctx)
    bag:CreateCategoryForItemInCursor(ctx)
  end)
  addon.SetScript(button, "OnClick", function(ctx, _, mouse)
    if mouse == "LeftButton" then
      if db:GetFirstTimeMenu() then
        db:SetFirstTimeMenu(false)
        button.highlightTex:SetAlpha(1)
        animation:SetLooping("NONE")
        animation:Restart()
      end
      if IsShiftKeyDown() then
        BetterBags_ToggleSearch()
      elseif CursorHasItem() and GetCursorInfo() == "item" then
        bag:CreateCategoryForItemInCursor(ctx)
      else
        addon:GetModule('ContextMenu'):Show(ctx, bag.menuList)
      end
    elseif mouse == "RightButton" then
      menuButton:Sort(ctx, bag)
    end
  end)

  sonata:RegisterElement("BagButton", button)
  return button
end

-- Place puts the button where a theme's layout says (points relative to the window frame),
-- above the window's overlay; a layout of false hides it.
---@param button BagButton
---@param layout table|false|nil
---@param frame Frame
---@param overlay? Frame
function menuButton:Place(button, layout, frame, overlay)
  if type(layout) ~= "table" then
    button:Hide()
    return
  end
  button:ClearAllPoints()
  for _, p in ipairs(layout.Points or { { Point = "TOPLEFT", X = -10, Y = 7 } }) do
    button:SetPoint(p.Point, frame, p.RelativePoint or p.Point, p.X or 0, p.Y or 0)
  end
  button:SetFrameLevel((overlay or frame):GetFrameLevel() + LEVEL_ABOVE_OVERLAY)
  button:Show()
end
