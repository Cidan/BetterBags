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

---@class Context: AceModule
local context = addon:GetModule('Context')

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

function bagFrame.bagProto:WipeFreeSlots()
  self.content:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.freeSlots:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.freeSlots:GetContent():Hide()
end

-- Draw will draw the correct bag view based on the bag view configuration.
---@param dirtyItems ItemData[]
function bagFrame.bagProto:Draw(dirtyItems)
  if self.slots:IsShown() then
    self:Wipe()
  end
  self:UpdateCellWidth()
  if database:GetBagView(self.kind) == const.BAG_VIEW.ONE_BAG then
    self.resizeHandle:Hide()
    views:OneBagView(self, dirtyItems)
  elseif database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_GRID then
    self.resizeHandle:Hide()
    views:GridView(self, dirtyItems)
  elseif database:GetBagView(self.kind) == const.BAG_VIEW.LIST then
    self.resizeHandle:Show()
    views:ListView(self, dirtyItems)
  end
  self.frame:SetScale(database:GetBagSizeInfo(self.kind, database:GetBagView(self.kind)).scale / 100)
  --local text = self.frame.SearchBox:GetText()
  --self:Search(text)
  self:KeepBagInBounds()
end


function bagFrame.bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  --self.frame:SetTitle(L:G("Bank"))
  self:Wipe()
end


-------
--- Bag Frame
-------

--- Create creates a new bag view.
---@param kind BagKind
---@return Bag
function bagFrame:Create(kind)
  ---@class Bag
  local b = {}
  setmetatable(b, { __index = bagFrame.bagProto })
  b.currentItemCount = 0
  b.drawOnClose = false
  b.isReagentBank = false
  b.itemsByBagAndSlot = {}
  b.sections = {}
  b.toRelease = {}
  b.toReleaseSections = {}
  b.kind = kind
  local sizeInfo = database:GetBagSizeInfo(b.kind, database:GetBagView(b.kind))
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsClassicBagPortrait
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil, "BetterBagsClassicBagPortraitTemplate")
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

  -- Create a custom portrait texture.
  local portraitSize = 48
  local portrait = b.frame:CreateTexture(nil, "ARTWORK")
  portrait:SetTexture([[Interface\Containerframe\Bagslots2x]])
  portrait:SetTexCoord(0, 0.2, 0, 1)
  portrait:SetDrawLayer("OVERLAY", 7)
  portrait:SetSize(portraitSize, portraitSize * 1.25)
  portrait:ClearAllPoints()
  portrait:SetPoint("TOPLEFT", b.frame, "TOPLEFT", -10, 10)

  b.frame:Hide()
  b.frame:SetSize(200, 200)
  ButtonFrameTemplate_HidePortrait(b.frame)
  ButtonFrameTemplate_HideButtonBar(b.frame)
  b.frame.Inset:Hide()
  b.frame:SetTitle(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  b.frame.CloseButton:SetScript("OnClick", function()
    b:Hide()
    if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
  end)


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
  b.menuList = context:CreateContextMenu(b)

  -- Create the invisible menu button.
  local bagButton = CreateFrame("Button")
  bagButton:EnableMouse(true)
  bagButton:SetParent(b.frame)
  bagButton:SetSize(portraitSize - 5, portraitSize - 5)
  bagButton:SetPoint("CENTER", portrait, "CENTER", -2, 8)
  local highlightTex = b.frame:CreateTexture("BetterBagsBagButtonTextureHighlight", "BACKGROUND")
  highlightTex:SetTexture([[Interface\Containerframe\Bagslots2x]])
  highlightTex:SetSize(portraitSize, portraitSize * 1.25)
  highlightTex:SetTexCoord(0.2, 0.4, 0, 1)
  highlightTex:SetPoint("CENTER", portrait, "CENTER", 2, 0)
  highlightTex:SetAlpha(0)
  highlightTex:SetDrawLayer("OVERLAY", 7)
  local anig = highlightTex:CreateAnimationGroup("BetterBagsBagButtonTextureHighlightAnim")
  local ani = anig:CreateAnimation("Alpha")
  ani:SetFromAlpha(0)
  ani:SetToAlpha(1)
  ani:SetDuration(0.2)
  ani:SetSmoothing("IN")
  if database:GetFirstTimeMenu() then
    ani:SetDuration(0.4)
    anig:SetLooping("BOUNCE")
    anig:Play()
  end
  bagButton:SetScript("OnEnter", function()
    if not database:GetFirstTimeMenu() then
      anig:Stop()
      highlightTex:SetAlpha(1)
      anig:Play()
    end
    GameTooltip:SetOwner(bagButton, "ANCHOR_LEFT")
    if kind == const.BAG_KIND.BACKPACK then
      GameTooltip:SetText(L:G("Left Click to open the menu, right click to clear recent items."))
    else
      GameTooltip:SetText(L:G("Left Click to open the menu."))
    end
    GameTooltip:Show()
  end)
  bagButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not database:GetFirstTimeMenu() then
      anig:Stop()
      highlightTex:SetAlpha(0)
      anig:Restart(true)
    end
  end)
  bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      if database:GetFirstTimeMenu() then
        database:SetFirstTimeMenu(false)
        highlightTex:SetAlpha(1)
        anig:SetLooping("NONE")
        anig:Restart()
      end
      context:Show(b.menuList)
    elseif e == "RightButton" and kind == const.BAG_KIND.BACKPACK then
    PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
    items:RemoveNewItemFromAllItems()
    b:Refresh()
    end
  end)

  -- Create the bag content frame.
  local content = grid:Create(b.frame)
  content:GetContainer():ClearAllPoints()
  content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, const.OFFSETS.BAG_TOP_INSET)
  content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, const.OFFSETS.BAG_BOTTOM_INSET + const.OFFSETS.BOTTOM_BAR_BOTTOM_INSET + 20)
  content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  content:Show()
  b.content = content

  -- Create the recent items section.
  local recentItems = sectionFrame:Create()
  recentItems:SetTitle(L:G("Recent Items"))
  recentItems:SetMaxCellWidth(sizeInfo.itemsPerRow)
  recentItems.frame:Hide()
  content:AddHeader(recentItems)
  b.recentItems = recentItems

  -- Create the free bag slots buttons and free bag slot section.
  local freeBagSlotsButton = itemFrame:Create()
  b.freeBagSlotsButton = freeBagSlotsButton

  local freeSlots = sectionFrame:Create()
  freeSlots:SetTitle(L:G("Free Slots"))
  freeSlots:SetMaxCellWidth(sizeInfo.itemsPerRow)
  b.freeSlots = freeSlots

  local slots = bagSlots:CreatePanel(kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 8)
  slots.frame:SetParent(b.frame)
  slots.frame:Hide()
  b.slots = slots

  -- Setup the search box events.
  --[[
  b.frame.SearchBox:SetAlpha(0)
  b.frame.SearchBox:SetScript("OnEnter", function()
    b.frame.SearchBox:SetAlpha(1)
  end)
  b.frame.SearchBox:SetScript("OnLeave", function()
    if b.frame.SearchBox:HasFocus() then return end
    if b.frame.SearchBox:GetText() ~= "" then return end
    b.frame.SearchBox:SetAlpha(0)
  end)
  b.frame.SearchBox:SetScript("OnEditFocusGained", function()
    b.frame.SearchBox:SetAlpha(1)
  end)
  b.frame.SearchBox:SetScript("OnEditFocusLost", function()
    if b.frame.SearchBox:GetText() ~= "" then return end
    b.frame.SearchBox:SetAlpha(0)
  end)

  b.frame.SearchBox:SetScript("OnTextChanged", function()
    local text = b.frame.SearchBox:GetText()
    if text == "" or text == nil then
      b.frame.SearchBox.Instructions:Show()
    else
      b.frame.SearchBox.Instructions:Hide()
    end
    b:Search(text)
  end)
  --]]

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
  end)

  b.frame:SetScript("OnSizeChanged", function()
    b:OnResize()
  end)
  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)

  b.resizeHandle = resize:MakeResizable(b.frame, function()
    local fw, fh = b.frame:GetSize()
    database:SetBagViewFrameSize(b.kind, database:GetBagView(b.kind), fw, fh)
  end)
  b:KeepBagInBounds()

  if b.kind == const.BAG_KIND.BACKPACK then
    events:BucketEvent('BAG_UPDATE_COOLDOWN',function(_) b:OnCooldown() end)
  end

  return b
end
