---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:GetModule('BagFrame')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class BagSlots: AceModule
local bagSlots = addon:GetModule('BagSlots')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Resize: AceModule
local resize = addon:GetModule('Resize')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

---@class Currency: AceModule
local currency = addon:GetModule('Currency')

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class SectionConfig: AceModule
local sectionConfig = addon:GetModule('SectionConfig')

---@class ThemeConfig: AceModule
local themeConfig = addon:GetModule('ThemeConfig')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class WindowGroup: AceModule
local windowGroup = addon:GetModule('WindowGroup')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Anchor: AceModule
local anchor = addon:GetModule('Anchor')

---@param ctx Context
function bagFrame.bagProto:SwitchToBankAndWipe(ctx)
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.bankTab = const.BANK_TAB.BANK
  BankFrame.selectedTab = 1
  ctx:Set("wipe", true)
  --self.frame:SetTitle(L:G("Bank"))
  items:ClearBankCache(ctx)
  self:Wipe(ctx)
end

---@param ctx Context
function bagFrame.bagProto:Sort(ctx)
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  if _G.SortBags ~= nil then
    events:SendMessage('bags/SortBackpackClassic', ctx)
  end
end

-------
--- Bag Frame
-------

--- Create creates a new bag view.
---@param ctx Context
---@param kind BagKind
---@return Bag
function bagFrame:Create(ctx, kind)
  ---@class Bag
  local b = {}
  setmetatable(b, { __index = bagFrame.bagProto })
  b.currentItemCount = 0
  b.drawOnClose = false
  b.bankTab = const.BANK_TAB.BANK
  b.sections = {}
  b.toRelease = {}
  b.toReleaseSections = {}
  b.kind = kind
  b.windowGrouping = windowGroup:Create()
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsClassicBagPortrait
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil)

  -- Register this window with the theme system.
  themes:RegisterPortraitWindow(f, name)

  --Mixin(f, PortraitFrameMixin)
  -- Setup the main frame defaults.
  b.frame = f
  b.frame:SetParent(UIParent)
  b.frame:SetToplevel(true)
  if b.kind == const.BAG_KIND.BACKPACK then
    b.frame:SetFrameStrata("MEDIUM")
    b.frame:SetFrameLevel(500)
  else
    b.frame:SetFrameStrata("HIGH")
  end
  b.sideAnchor = CreateFrame("Frame", f:GetName().."LeftAnchor", b.frame)
  b.sideAnchor:SetWidth(1)
  b.sideAnchor:SetPoint("TOPRIGHT", b.frame, "TOPLEFT")
  b.sideAnchor:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMLEFT")
  f.Owner = b

  b.frame:Hide()
  b.frame:SetSize(200, 200)
  --b.frame.CloseButton = b.frame.DefaultDecoration.CloseButton
  --b.frame.PortraitFrame = b.frame.DefaultDecoration.PortraitFrame
  --b.frame.TitleContainer = b.frame.DefaultDecoration.TitleContainer
  --b.frame.Bg = b.frame.DefaultDecoration.Bg
  --ButtonFrameTemplate_HidePortrait(b.frame.DefaultDecoration)
  --ButtonFrameTemplate_HideButtonBar(b.frame.DefaultDecoration)
  --b.frame.DefaultDecoration.Inset:Hide()
  --b.frame.SetTitle = function(_, title)
  --  b.frame.DefaultDecoration:SetTitle(title)
  --end
  --b.frame:SetTitle(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  --b.frame.CloseButton:SetScript("OnClick", function()
  --  b:Hide()
  --  if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
  --end)

  b.views = {
    [const.BAG_VIEW.SECTION_GRID] = views:NewGrid(f, b.kind),
    [const.BAG_VIEW.SECTION_ALL_BAGS] = views:NewBagView(f, b.kind),
  }

  -- Register the bag frame so that window positions are saved.
  Window.RegisterConfig(b.frame, database:GetBagPosition(kind))

  -- Create the bottom bar for currency and money display.
  local bottomBar = CreateFrame("Frame", nil, b.frame)
  bottomBar:SetPoint("BOTTOMLEFT", b.frame, "BOTTOMLEFT", const.OFFSETS.BOTTOM_BAR_LEFT_INSET, const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET)
  bottomBar:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BOTTOM_BAR_RIGHT_INSET, const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET)
  bottomBar:SetHeight(20)
  bottomBar:Show()
  b.bottomBar = bottomBar

  -- Create the money frame only in the player backpack bag.
  if kind == const.BAG_KIND.BACKPACK then
    local moneyFrame = money:Create()
    moneyFrame.frame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", -4, 0)
    moneyFrame.frame:SetParent(b.frame)
    b.moneyFrame = moneyFrame
  end

  -- Setup the context menu.
  b.menuList = contextMenu:CreateContextMenu(b)

  -- Create the invisible menu button.
  --local bagButton = CreateFrame("Button")
  --bagButton:EnableMouse(true)
  --bagButton:SetParent(b.frame)
  --bagButton:SetSize(portraitSize - 5, portraitSize - 5)
  --bagButton:SetPoint("CENTER", portrait, "CENTER", -2, 8)
  --local highlightTex = b.frame:CreateTexture("BetterBagsBagButtonTextureHighlight", "BACKGROUND")
  --highlightTex:SetTexture([[Interface\Containerframe\Bagslots2x]])
  --highlightTex:SetSize(portraitSize, portraitSize * 1.25)
  --highlightTex:SetTexCoord(0.2, 0.4, 0, 1)
  --highlightTex:SetPoint("CENTER", portrait, "CENTER", 2, 0)
  --highlightTex:SetAlpha(0)
  --highlightTex:SetDrawLayer("OVERLAY", 7)

  --local anig = highlightTex:CreateAnimationGroup("BetterBagsBagButtonTextureHighlightAnim")
  --local ani = anig:CreateAnimation("Alpha")
  --ani:SetFromAlpha(0)
  --ani:SetToAlpha(1)
  --ani:SetDuration(0.2)
  --ani:SetSmoothing("IN")
  --if database:GetFirstTimeMenu() then
  --  ani:SetDuration(0.4)
  --  anig:SetLooping("BOUNCE")
  --  anig:Play()
  --end
  --bagButton:SetScript("OnEnter", function()
  --  if not database:GetFirstTimeMenu() then
  --    anig:Stop()
  --    highlightTex:SetAlpha(1)
  --    anig:Play()
  --  end
  --  GameTooltip:SetOwner(bagButton, "ANCHOR_LEFT")
  --  if kind == const.BAG_KIND.BACKPACK then
  --    GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
  --    GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
  --    if _G.SortBags ~= nil then
  --      GameTooltip:AddDoubleLine(L:G("Right Click"), L:G("Sort Bags"), 1, 0.81, 0, 1, 1, 1)
  --    end
  --  else
  --    GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
  --    GameTooltip:AddDoubleLine(L:G("Shift Left Click"), L:G("Search Bags"), 1, 0.81, 0, 1, 1, 1)
  --  end
  --  if CursorHasItem() then
  --    local cursorType, _, itemLink = GetCursorInfo()
  --    if cursorType == "item" then
  --      GameTooltip:AddLine(" ", 1, 1, 1)
  --      GameTooltip:AddLine(format(L:G("Drop %s here to create a new category for it."), itemLink), 1, 1, 1)
  --    end
  --  end
  --  GameTooltip:Show()
  --end)
  --bagButton:SetScript("OnLeave", function()
  --  GameTooltip:Hide()
  --  if not database:GetFirstTimeMenu() then
  --    anig:Stop()
  --    highlightTex:SetAlpha(0)
  --    anig:Restart(true)
  --  end
  --end)
  --bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  --bagButton:SetScript("OnReceiveDrag", b.CreateCategoryForItemInCursor)
  --bagButton:SetScript("OnClick", function(_, e)
  --  if e == "LeftButton" then
  --    if database:GetFirstTimeMenu() then
  --      database:SetFirstTimeMenu(false)
  --      highlightTex:SetAlpha(1)
  --      anig:SetLooping("NONE")
  --      anig:Restart()
  --    end
  --    if IsShiftKeyDown() then
  --      BetterBags_ToggleSearch()
  --    elseif CursorHasItem() and GetCursorInfo() == "item" then
  --      b:CreateCategoryForItemInCursor()
  --    else
  --      contextMenu:Show(b.menuList)
  --    end
  --  elseif e == "RightButton" and kind == const.BAG_KIND.BACKPACK then
  --    b:Sort()
  --  end
  --end)

  local slots = bagSlots:CreatePanel(ctx, kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  if kind == const.BAG_KIND.BACKPACK then
    b.searchFrame = searchBox:Create(b.frame)
  end

  if kind == const.BAG_KIND.BACKPACK then
    b.themeConfigFrame = themeConfig:Create(b.sideAnchor)
    b.windowGrouping:AddWindow('themeConfig', b.themeConfigFrame)
  end

  if kind == const.BAG_KIND.BANK then
    b.bankTab = const.BANK_TAB.BANK
  end
  b.sectionConfigFrame = sectionConfig:Create(kind, b.frame)
  b.windowGrouping:AddWindow('sectionConfig', b.sectionConfigFrame)

  -- Enable dragging of the bag frame.
  b.frame:SetMovable(true)
  b.frame:EnableMouse(true)
  b.frame:RegisterForDrag("LeftButton")
  b.frame:SetClampedToScreen(true)
  b.frame:SetScript("OnDragStart", function(drag)
    b:KeepBagInBounds()
    drag:StartMoving()
  end)
  b.frame:SetScript("OnDragStop", function(drag)
    drag:StopMovingOrSizing()
    Window.SavePosition(b.frame)
    b.previousSize = b.frame:GetBottom()
    b:OnResize()
  end)

  b.frame:SetScript("OnSizeChanged", function()
    b:OnResize()
  end)

  b.anchor = anchor:New(kind, b.frame, name)
  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)

  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
  end)
  b.resizeHandle:Hide()
  b:KeepBagInBounds()

  if b.kind == const.BAG_KIND.BACKPACK then
    events:BucketEvent('BAG_UPDATE_COOLDOWN',function(ectx) b:OnCooldown(ectx) end)
  end

  events:RegisterEvent('ITEM_LOCKED', function(ectx, _, bagid, slotid)
    b:OnLock(ectx, bagid, slotid)
  end)

  events:RegisterEvent('ITEM_UNLOCKED', function(ectx, _, bagid, slotid)
    b:OnUnlock(ectx, bagid, slotid)
  end)

  events:RegisterMessage('search/SetInFrame', function (ectx, _, shown)
    themes:SetSearchState(ectx, b.frame, shown)
  end)

  events:RegisterMessage('bag/RedrawIcons', function(ectx)
    if not b.currentView then return end
    for _, item in pairs(b.currentView:GetItemsByBagAndSlot()) do
      item:UpdateUpgrade(ectx)
    end
  end)

  return b
end
