---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addon = GetBetterBags()

local bagFrame = addon:GetBagFrame()

local const = addon:GetConstants()

local items = addon:GetItems()

local bagSlots = addon:GetBagSlots()

local database = addon:GetDatabase()

local contextMenu = addon:GetContextMenu()

local money = addon:GetMoneyFrame()

local views = addon:GetViews()

local resize = addon:GetResize()

local events = addon:GetEvents()

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

local currency = addon:GetCurrency()

local searchBox = addon:GetSearchBox()

local themes = addon:GetThemes()

local themeConfig = addon:GetThemeConfig()

local windowGroup = addon:GetWindowGroup()

local sectionConfig = addon:GetSectionConfig()

local anchor = addon:GetAnchor()

---@param ctx Context
function bagFrame.bagProto:SwitchToBankAndWipe(ctx)
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.bankTab = const.BANK_TAB.BANK
  BankFrame.selectedTab = 1
  ctx:Set('wipe', true)
  --self.frame:SetTitle(L:G("Bank"))
  items:ClearBankCache(ctx)
  self:Wipe(ctx)
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
  -- Setup the main frame defaults.
  b.frame = f
  b.sideAnchor = CreateFrame("Frame", f:GetName().."LeftAnchor", b.frame)
  b.sideAnchor:SetWidth(1)
  b.sideAnchor:SetPoint("TOPRIGHT", b.frame, "TOPLEFT")
  b.sideAnchor:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMLEFT")
  b.frame.Owner = b
  themes:RegisterPortraitWindow(f, name)

  b.frame:SetParent(UIParent)
  b.frame:SetToplevel(true)
  if b.kind == const.BAG_KIND.BACKPACK then
    b.frame:SetFrameStrata("MEDIUM")
    b.frame:SetFrameLevel(500)
  else
    b.frame:SetFrameStrata("HIGH")
  end

  b.frame:Hide()
  b.frame:SetSize(200, 200)

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

  local slots = bagSlots:CreatePanel(ctx, kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  if kind == const.BAG_KIND.BACKPACK then
    b.searchFrame = searchBox:Create(ctx, b.frame)
  end

  if kind == const.BAG_KIND.BACKPACK then
    local currencyFrame = currency:Create(b.frame)
    currencyFrame:Hide()
    b.currencyFrame = currencyFrame

    b.themeConfigFrame = themeConfig:Create(b.sideAnchor)
    b.windowGrouping:AddWindow('themeConfig', b.themeConfigFrame)
    b.windowGrouping:AddWindow('currencyConfig', b.currencyFrame)
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

  events:RegisterMessage('search/SetInFrame', function (ectx, shown)
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
