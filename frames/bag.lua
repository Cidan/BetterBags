local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:NewModule('BagFrame')

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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

local LSM = LibStub('LibSharedMedia-3.0')

---@class LibWindow-1.1: AceAddon
local Window = LibStub('LibWindow-1.1')

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class Bag
---@field kind BagKind
---@field frame Frame The fancy frame of the bag.
---@field leftHeader Frame The top left header of the bag.
---@field content Grid The main content frame of the bag.
---@field recentItems Section The recent items section.
---@field freeSlots Section The free slots section.
---@field freeBagSlotsButton Item The free bag slots button.
---@field freeReagentBagSlotsButton Item The free reagent bag slots button.
---@field itemsByBagAndSlot table<number, table<number, Item>>
---@field sections table<string, Section>
---@field slots bagSlots
---@field isReagentBank boolean
---@field decorator Texture
---@field bg Texture
local bagProto = {}

function bagProto:Show()
  if self.frame:IsShown() then
    return
  end
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_OPEN or SOUNDKIT.IG_BACKPACK_OPEN)
  self.frame:Show()
end

function bagProto:Hide()
  if not self.frame:IsShown() then
    return
  end
  PlaySound(self.kind == const.BAG_KIND.BANK and SOUNDKIT.IG_MAINMENU_CLOSE or SOUNDKIT.IG_BACKPACK_CLOSE)
  self.frame:Hide()
end

function bagProto:Toggle()
  if self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function bagProto:IsShown()
  return self.frame:IsShown()
end

---@return number x
---@return number y
function bagProto:GetPosition()
  local scale = self.frame:GetScale()
  local x, y = self.frame:GetCenter()
  return x * scale, y * scale
end

function bagProto:WipeFreeSlots()
  self.content:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.content:RemoveCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
  self.freeSlots.content:RemoveCell("freeBagSlots", self.freeBagSlotsButton)
  self.freeSlots.content:RemoveCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
end

-- Wipe will wipe the contents of the bag and release all cells.
function bagProto:Wipe()
  self:WipeFreeSlots()
  self.content:RemoveCell(self.freeSlots.title:GetText(), self.freeSlots)
  self.content:Wipe()
  wipe(self.itemsByBagAndSlot)
  wipe(self.sections)
end

function bagProto:Refresh()
  if self.kind == const.BAG_KIND.BACKPACK then
    items:RefreshBackpack()
  elseif self.kind == const.BAG_KIND.BANK and not self.isReagentBank then
    items:RefreshBank()
  else
    items:RefreshReagentBank()
  end
end

function bagProto:UpdateCellWidth()
  if database:GetBagView(self.kind) == const.BAG_VIEW.ONE_BAG then
    self.content.maxCellWidth = 15
  else
    self.content.maxCellWidth = self.kind == const.BAG_KIND.BACKPACK and 3 or 5
  end
end

---@param dirtyItems table<number, table<number, ItemMixin>>
function bagProto:Draw(dirtyItems)
  self:UpdateCellWidth()
  if database:GetBagView(self.kind) == const.BAG_VIEW.ONE_BAG then
    self:DrawOneBag(dirtyItems)
  elseif database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_GRID then
    self:DrawSectionGridBag(dirtyItems)
  elseif database:GetBagView(self.kind) == const.BAG_VIEW.LIST then
    self:DrawSectionListBag(dirtyItems)
  end
end

-- DrawOneBag draws all items as a combined container view, similar to the Blizzard
-- combined bag view.
---@param dirtyItems table<number, table<number, ItemMixin>>
function bagProto:DrawOneBag(dirtyItems)
  self:WipeFreeSlots()
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  for bid, bagData in pairs(dirtyItems) do
    self.itemsByBagAndSlot[bid] = self.itemsByBagAndSlot[bid] or {}
    for sid, itemData in pairs(bagData) do
      local bagid, slotid = itemData:GetItemLocation():GetBagAndSlot()

      if itemData:IsItemEmpty() then
        if bagid == Enum.BagIndex.ReagentBag then
          freeReagentSlotsData.count = freeReagentSlotsData.count + 1
          freeReagentSlotsData.bagid = bagid
          freeReagentSlotsData.slotid = slotid
        else
          freeSlotsData.count = freeSlotsData.count + 1
          freeSlotsData.bagid = bagid
          freeSlotsData.slotid = slotid
        end
      end

      local oldFrame = self.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]

      -- The old frame does not exist, so we need to create a new one.
      if oldFrame == nil and not itemData:IsItemEmpty() then
        local newFrame = itemFrame:Create()
        newFrame:SetItem(itemData)
        newFrame:AddToMasqueGroup(self.kind)
        self.content:AddCell(itemData:GetItemGUID(), newFrame)
        self.itemsByBagAndSlot[bagid][slotid] = newFrame
      elseif oldFrame ~= nil and not itemData:IsItemEmpty() then
        -- The old frame exists, so we need to update it.
        oldFrame:SetItem(itemData)
      elseif itemData:IsItemEmpty() and oldFrame ~= nil then
        -- The old frame exists, but the item is empty, so we need to delete it.
        self.itemsByBagAndSlot[bid][sid] = nil
        self.content:RemoveCell(oldFrame.guid, oldFrame)
        oldFrame:Release()
      end
    end
  end

  self.content:Sort(function (a, b)
    ---@cast a +Item
    ---@cast b +Item
    if not a.mixin or not b.mixin then return false end
    if a.mixin:GetItemQuality() == nil or b.mixin:GetItemQuality() == nil then return false end
    if a.mixin:GetItemQuality() == b.mixin:GetItemQuality() then
      if a.mixin:GetItemName() == nil or b.mixin:GetItemName() == nil then return false end
      return a.mixin:GetItemName() < b.mixin:GetItemName()
    end
    return a.mixin:GetItemQuality() > b.mixin:GetItemQuality()
  end)

  self.content:AddCell("freeBagSlots", self.freeBagSlotsButton)
  self.content:AddCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)
  self.freeBagSlotsButton:SetFreeSlots(freeSlotsData.bagid, freeSlotsData.slotid, freeSlotsData.count, false)
  self.freeReagentBagSlotsButton:SetFreeSlots(freeReagentSlotsData.bagid, freeReagentSlotsData.slotid, freeReagentSlotsData.count, true)
  -- Redraw the world.
  local w, h = self.content:Draw()
  self.frame:SetWidth(w + 12)
  self.frame:SetHeight(h + 28 + self.leftHeader:GetHeight())
end

-- DrawSectionGridBag draws all items in sections according to their configured type.
-- This is the tradition AdiBags style.
---@param dirtyItems table<number, table<number, ItemMixin>>
function bagProto:DrawSectionGridBag(dirtyItems)
  self:WipeFreeSlots()
  local freeSlotsData = {count = 0, bagid = 0, slotid = 0}
  local freeReagentSlotsData = {count = 0, bagid = 0, slotid = 0}
  for bid, bagData in pairs(dirtyItems) do
    self.itemsByBagAndSlot[bid] = self.itemsByBagAndSlot[bid] or {}
    for sid, itemData in pairs(bagData) do
      local bagid, slotid = itemData:GetItemLocation():GetBagAndSlot()

      if itemData:IsItemEmpty() then
        if bagid == Enum.BagIndex.ReagentBag then
          freeReagentSlotsData.count = freeReagentSlotsData.count + 1
          freeReagentSlotsData.bagid = bagid
          freeReagentSlotsData.slotid = slotid
        else
          freeSlotsData.count = freeSlotsData.count + 1
          freeSlotsData.bagid = bagid
          freeSlotsData.slotid = slotid
        end
      end

      local oldFrame = self.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]
      -- The old frame does not exist, so we need to create a new one.
      if oldFrame == nil and not itemData:IsItemEmpty() then
        local newFrame = itemFrame:Create()
        newFrame:SetItem(itemData)
        local category = newFrame:GetCategory()
        local section ---@type Section|nil
        if newFrame:IsNewItem() then
          section = self.recentItems
        else
          section = self.sections[category]
        end
        -- Create the section if it doesn't exist.
        if section == nil then
          section = sectionFrame:Create()
          section:SetTitle(category)
          section.content.maxCellWidth = 5
          self.content:AddCell(category, section)
          self.sections[category] = section
        end
        section.content:AddCell(itemData:GetItemGUID(), newFrame)
        newFrame:AddToMasqueGroup(self.kind)
        self.itemsByBagAndSlot[bagid][slotid] = newFrame
      elseif oldFrame ~= nil and not itemData:IsItemEmpty() and oldFrame.mixin:GetItemGUID() ~= itemData:GetItemGUID() then
        -- This case handles the situation where the item in this slot no longer matches the item displayed.
        -- The old frame exists, so we need to update it.
        local oldCategory = oldFrame:GetCategory()
        local oldSection = self.sections[oldCategory]
        if self.recentItems:HasItem(oldFrame) then
          oldSection = self.recentItems
          oldCategory = self.recentItems.title:GetText()
        end
        local oldGuid = oldFrame.guid
        oldFrame:SetItem(itemData)
        local newCategory = oldFrame:GetCategory()
        local newSection = self.sections[newCategory]
        -- Create the section if it doesn't exist.
        if newSection == nil then
          newSection = sectionFrame:Create()
          newSection:SetTitle(newCategory)
          newSection.content.maxCellWidth = 5
          self.content:AddCell(newCategory, newSection)
          self.sections[newCategory] = newSection
        end
        if oldCategory ~= newCategory then
          oldSection.content:RemoveCell(oldGuid, oldFrame)
          newSection.content:AddCell(oldFrame.guid, oldFrame)
        end
        if oldSection == self.recentItems then
        elseif #oldSection.content.cells == 0 then
          self.sections[oldCategory] = nil
          self.content:RemoveCell(oldCategory, oldSection)
          oldSection:Release()
        end
      elseif oldFrame ~= nil and not itemData:IsItemEmpty() and oldFrame.mixin:GetItemGUID() == itemData:GetItemGUID() then
        -- This case handles when the item in this slot is the same as the item displayed.
        oldFrame:SetItem(itemData)

        -- The item in this same slot may no longer be a new item, i.e. it was moused over. If so, we
        -- need to resection it.
        if not oldFrame:IsNewItem() and self.recentItems:HasItem(oldFrame) then
          self.recentItems.content:RemoveCell(oldFrame.guid, oldFrame)
          local category = oldFrame:GetCategory()
          local section = self.sections[category]
          if section == nil then
            section = sectionFrame:Create()
            section:SetTitle(category)
            section.content.maxCellWidth = 5
            self.content:AddCell(category, section)
            self.sections[category] = section
          end
          section.content:AddCell(oldFrame.guid, oldFrame)
        end
      elseif itemData:IsItemEmpty() and oldFrame ~= nil then
        -- The old frame exists, but the item is empty, so we need to delete it.
        self.itemsByBagAndSlot[bagid][slotid] = nil
        -- Special handling for the recent items section.
        if self.recentItems:HasItem(oldFrame) then
          self.recentItems.content:RemoveCell(oldFrame.guid, oldFrame)
        else
          local section = self.sections[oldFrame:GetCategory()]
          section.content:RemoveCell(oldFrame.guid, oldFrame)
          -- Delete the section if it's empty as well.
          if #section.content.cells == 0 then
            self.sections[oldFrame:GetCategory()] = nil
            self.content:RemoveCell(oldFrame:GetCategory(), section)
            section:Release()
          end
        end
        oldFrame:Release()
      end
    end
  end

  self.freeSlots.content:AddCell("freeBagSlots", self.freeBagSlotsButton)
  self.freeSlots.content:AddCell("freeReagentBagSlots", self.freeReagentBagSlotsButton)

  self.freeBagSlotsButton:SetFreeSlots(freeSlotsData.bagid, freeSlotsData.slotid, freeSlotsData.count, false)
  self.freeReagentBagSlotsButton:SetFreeSlots(freeReagentSlotsData.bagid, freeReagentSlotsData.slotid, freeReagentSlotsData.count, true)

  -- Loop through each section and draw it's size.
  local recentW, recentH = self.recentItems:Draw()
  for _, section in pairs(self.sections) do
    section:Draw()
  end
  self.freeSlots:Draw()

  -- Remove the freeSlots section.
  self.content:RemoveCell(self.freeSlots.title:GetText(), self.freeSlots)

  -- Sort all sections by title.
  self.content:Sort(function(a, b)
    ---@cast a +Section
    ---@cast b +Section
    if not a.title or not b.title then return false end
    return a.title:GetText() < b.title:GetText()
  end)

  -- Add the freeSlots section back to the end of all sections
  self.content:AddCellToLastColumn(self.freeSlots.title:GetText(), self.freeSlots)

  -- Position all sections and draw the main bag.
  local w, h = self.content:Draw()
  -- Reposition the content frame if the recent items section is empty.
  if recentW == 0 then
    self.content.frame:SetPoint("TOPLEFT", self.leftHeader, "BOTTOMLEFT", 3, -3)
  else
    self.content.frame:SetPoint("TOPLEFT", self.recentItems.frame, "BOTTOMLEFT", 3, -3)
  end

  --debug:DrawDebugBorder(self.content.frame, 1, 1, 1)
  if w < 160 then
    w = 160
  end
  if h == 0 then
    h = 40
  end

  self.frame:SetWidth(w + 12)
  self.frame:SetHeight(h + 24 + self.leftHeader:GetHeight() + recentH)
end

-- DrawSectionListBag draws the bag as a scrollable list of sections with a small icon
-- and the item name as a single row.
---@param dirtyItems table<number, table<number, ItemMixin>>
function bagProto:DrawSectionListBag(dirtyItems)
  self:WipeFreeSlots()
end

function bagProto:ToggleReagentBank()
  -- This should never happen, but just in case!
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = not self.isReagentBank
  if self.isReagentBank then
    BankFrame.selectedTab = 2
    self.frame:SetTitle(L:G("Reagent Bank"))
    self:Wipe()
    items:RefreshReagentBank()
  else
    BankFrame.selectedTab = 1
    self.frame:SetTitle(L:G("Bank"))
    self:Wipe()
    items:RefreshBank()
  end
end

function bagProto:SwitchToBank()
  if self.kind == const.BAG_KIND.BACKPACK then return end
  self.isReagentBank = false
  BankFrame.selectedTab = 1
  self.frame:SetTitle(L:G("Bank"))
end

-------
--- Bag Frame
-------

---@param bag Bag
---@return MenuList[]
local function createContextMenu(bag)
  local menuList = {}

  -- Context Menu title.
  table.insert(menuList, {
    text = L:G("BetterBags Menu"),
    isTitle = true,
    notCheckable = true
  })

  -- View menu for switching between one bag and section grid.
  table.insert(menuList, {
    text = L:G("View"),
    hasArrow = true,
    notCheckable = true,
    menuList = {
      {
        text = L:G("One Bag"),
        keepShownOnClick = false,
        checked = function() return database:GetBagView(bag.kind) == const.BAG_VIEW.ONE_BAG end,
        func = function()
          context:Hide()
          database:SetBagView(bag.kind, const.BAG_VIEW.ONE_BAG)
          bag:Wipe()
          bag:Refresh()
        end
      },
      {
        text = L:G("Section Grid"),
        keepShownOnClick = false,
        checked = function() return database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_GRID end,
        func = function()
          context:Hide()
          database:SetBagView(bag.kind, const.BAG_VIEW.SECTION_GRID)
          bag:Wipe()
          bag:Refresh()
        end
      },
      --[[
      {
        text = L:G("List"),
        keepShownOnClick = false,
        checked = function() return database:GetBagView(bag.kind) == const.BAG_VIEW.LIST end,
        func = function()
          context:Hide()
          database:SetBagView(bag.kind, const.BAG_VIEW.LIST)
          bag:Wipe()
          if bag.kind == const.BAG_KIND.BACKPACK then items:RefreshBackpack() else items:RefreshBank() end
        end
      }
      --]]
    }
  })

  -- Category filter menu for selecting how categories are created in grid view.
  table.insert(menuList, {
    text = L:G("Section Categories"),
    hasArrow = true,
    notCheckable = true,
    menuList = {
      {
        text = L:G("Type"),
        checked = function() return database:GetCategoryFilter(bag.kind, "Type") end,
        func = function()
          context:Hide()
          database:SetCategoryFilter(bag.kind, "Type", not database:GetCategoryFilter(bag.kind, "Type"))
          bag:Wipe()
          bag:Refresh()
        end
      },
      {
        text = L:G("Expansion"),
        tooltipTitle = L:G("Expansion"),
        tooltipText = L:G("If enabled, will categorize items by expansion."),
        checked = function() return database:GetCategoryFilter(bag.kind, "Expansion") end,
        func = function()
          context:Hide()
          database:SetCategoryFilter(bag.kind, "Expansion", not database:GetCategoryFilter(bag.kind, "Expansion"))
          bag:Wipe()
          bag:Refresh()
        end
      },
      {
        text = L:G("Trade Skill (Reagents Only)"),
        tooltipTitle = L:G("Trade Skill"),
        tooltipText = L:G("If enabled, will categorize items by trade skill."),
        checked = function() return database:GetCategoryFilter(bag.kind, "TradeSkill") end,
        func = function()
          context:Hide()
          database:SetCategoryFilter(bag.kind, "TradeSkill", not database:GetCategoryFilter(bag.kind, "TradeSkill"))
          bag:Wipe()
          bag:Refresh()
        end
      }
    }
  })

  -- Show bag slot toggle.
  table.insert(menuList, {
    text = L:G("Show Bags"),
    checked = function() return bag.slots:IsShown() end,
    func = function()
      if bag.slots:IsShown() then
        bag.slots:Hide()
      else
        bag.slots:Draw()
        bag.slots:Show()
      end
    end
  })
  return menuList
end

--- Create creates a new bag view.
---@param kind BagKind
---@return Bag
function bagFrame:Create(kind)
  ---@class Bag
  local b = {}
  setmetatable(b, { __index = bagProto })
  -- TODO(lobato): Compose the entire frame here.
  b.isReagentBank = false
  b.itemsByBagAndSlot = {}
  b.sections = {}
  b.kind = kind
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BetterBagsBagPortraitTemplate
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil, "BetterBagsBagPortraitTemplate")
  --[[
    local f = CreateFrame("Frame", "BetterBagsBag"..name, nil, "BetterBagsBagTemplate")
    Mixin(f, PortraitFrameMixin)
  ]]
  -- Setup the main frame defaults.
  b.frame = f
  b.frame:SetParent(UIParent)
  b.frame:Hide()
  b.frame:SetSize(200, 200)
  b.frame.Bg:SetAlpha(0.8)
  b.frame.CloseButton:SetScript("OnClick", function()
    b:Hide()
    if b.kind == const.BAG_KIND.BANK then CloseBankFrame() end
  end)

  --
  --  

--[[
  local bg = b.frame:CreateTexture(name .. "BagBackground", "BACKGROUND", nil, -6)
  bg:SetPoint("TOPLEFT", 2, -4)
  bg:SetPoint("BOTTOMRIGHT", -2, 2)
  bg:SetTexture('Interface\\FrameGeneral\\UI-Background-Rock')
  bg:SetHorizTile(true)
  bg:SetVertTile(true)
  bg:SetAlpha(0.9)
  b.bg = bg

  local decorator = b.frame:CreateTexture(name .. "Decorator", "BORDER", "_UI-Frame-TopTileStreaks", -7)
  decorator:SetPoint("TOPLEFT", 0, -6)
  decorator:SetPoint("TOPRIGHT", -2, 6)
  decorator:SetAlpha(0.9)
  self.decorator = decorator
  --]]

  b.frame:SetPortraitToAsset([[Interface\Icons\INV_Misc_Bag_07]])
  b.frame:SetPortraitTextureSizeAndOffset(38, -5, 0)
  Window.RegisterConfig(b.frame, database:GetBagPosition(kind))
    --bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
  -- Setup the default skin/theme.
  -- TODO(lobato): Move this to a separate module for themes.
  --[[
  b.frame:SetBackdropColor(0, 0, 0, 1)
  b.frame:SetBackdrop({
    bgFile = LSM:Fetch(LSM.MediaType.BACKGROUND, "Blizzard Dialog Background"),
    edgeFile = LSM:Fetch(LSM.MediaType.BORDER, "Blizzard Tooltip"),
    tile = false,
    tileEdge = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  ]]--
  -- Create the top left header.
  ---@class Frame: BackdropTemplate
  local leftHeader = CreateFrame("Frame", nil, b.frame, "BackdropTemplate")
  leftHeader:SetPoint("TOPLEFT", 3, -20) -- -8 to -20
  leftHeader:SetPoint("TOPRIGHT", -3, 3)
  leftHeader:SetHeight(20)
  leftHeader:Show()
  b.leftHeader = leftHeader

  --debug:DrawDebugBorder(leftHeader, 1, 1, 1)

  local bagButton = CreateFrame("Button")
  bagButton:EnableMouse(true)
  bagButton:SetParent(b.frame.PortraitContainer)
  --bagButton:ClearBackdrop()
  --bagButton:SetNormalTexture([[Interface\Icons\INV_Misc_Bag_07]])
  bagButton:SetHighlightTexture([[Interface\Buttons\CheckButtonHilight]])
  bagButton:SetHighlightTexture([[Interface\AddOns\BetterBags\Textures\glow.png]])
  bagButton:SetWidth(40)
  bagButton:SetHeight(40)
  --bagButton:SetPoint("LEFT", leftHeader, "LEFT", 4, 0)
  bagButton:SetPoint("TOPLEFT", b.frame.PortraitContainer, "TOPLEFT", -6, 2)
  bagButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(bagButton, "ANCHOR_LEFT")
    if kind == const.BAG_KIND.BACKPACK then
      GameTooltip:SetText(L:G("Left Click to open the menu."))
    else
      GameTooltip:SetText(L:G("Left Click to open the menu, right click to swap to reagent bank and back."))
    end
    GameTooltip:Show()
  end)
  bagButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  bagButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  b.frame:SetTitle(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  -- Create the bag content frame.
  local content = grid:Create(b.frame)
  content.frame:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 3, -3)
  content.frame:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -3, 3)
  content.maxCellWidth = kind == const.BAG_KIND.BACKPACK and 3 or 5
  content:Show()
  b.content = content

  local recentItems = sectionFrame:Create()
  recentItems:SetTitle(L:G("Recent Items"))
  recentItems.content.maxCellWidth = 5
  recentItems.frame:SetParent(b.frame)
  recentItems.frame:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 3, -3)
  recentItems.frame:Hide()
  b.recentItems = recentItems
  --debug:DrawDebugBorder(content.frame, 1, 1, 1)

  local freeBagSlotsButton = itemFrame:Create()
  b.freeBagSlotsButton = freeBagSlotsButton

  local freeReagentBagSlotsButton = itemFrame:Create()
  b.freeReagentBagSlotsButton = freeReagentBagSlotsButton

  local freeSlots = sectionFrame:Create()
  freeSlots:SetTitle(L:G("Free Slots"))
  freeSlots.content.maxCellWidth = 5
  b.freeSlots = freeSlots

  local slots = bagSlots:CreatePanel(kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 3)
  slots.frame:SetParent(b.frame)
  b.slots = slots

  -- Setup the search box events.
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

  -- Enable dragging of the bag frame.
  b.frame:SetMovable(true)
  b.frame:EnableMouse(true)
  b.frame:RegisterForDrag("LeftButton")
  b.frame:SetClampedToScreen(true)
  b.frame:SetScript("OnDragStart", function(drag)
    drag:StartMoving()
  end)
  b.frame:SetScript("OnDragStop", function(drag)
    drag:StopMovingOrSizing()
    Window.SavePosition(b.frame)
  end)

  -- Load the bag position from settings.
  Window.RestorePosition(b.frame)

  -- Setup the context menu.
  local contextMenu = createContextMenu(b)
  bagButton:SetScript("OnClick", function(_, e)
    if e == "LeftButton" then
      context:Show(contextMenu)
    else
      b:ToggleReagentBank()
    end
  end)

  return b
end

--- Destroy destroys the given bag view.
---@param bag Bag
function bagFrame:Destroy(bag)
end