local addonName = ...

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
---@field frame Frame The raw frame of the bag.
---@field leftHeader Frame The top left header of the bag.
---@field title FontString The title of the bag.
---@field content Grid The main content frame of the bag.
---@field recentItems Section The recent items section.
---@field itemsByBagAndSlot table<number, table<number, Item>>
---@field sections table<string, Section>
---@field slots bagSlots
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
  self.frame:SetShown(not self.frame:IsShown())
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

-- Wipe will wipe the contents of the bag and release all cells.
function bagProto:Wipe()
  for _, cell in ipairs(self.content.cells) do
    ---@cast cell -Section,-Cell
    itemFrame:Release(cell)
  end
  for _, section in pairs(self.sections) do
    sectionFrame:Release(section)
  end
  self.content:Wipe()
  wipe(self.itemsByBagAndSlot)
  wipe(self.sections)
end

-- DrawOneBag draws all items as a combined container view, similar to the Blizzard
-- combined bag view.
function bagProto:DrawOneBag(dirtyItems)
  for bid, bagData in pairs(dirtyItems) do
    self.itemsByBagAndSlot[bid] = self.itemsByBagAndSlot[bid] or {}
    for sid, itemData in pairs(bagData) do
      local bagid, slotid = itemData:GetItemLocation():GetBagAndSlot()
      local oldFrame = self.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]

      -- The old frame does not exist, so we need to create a new one.
      if oldFrame == nil and not itemData:IsItemEmpty() then
        local newFrame = itemFrame:Create()
        newFrame:SetItem(itemData)
        self.content:AddCell(itemData:GetItemGUID(), newFrame)
        self.itemsByBagAndSlot[bagid][slotid] = newFrame
      elseif oldFrame ~= nil and not itemData:IsItemEmpty() then
        -- The old frame exists, so we need to update it.
        oldFrame:SetItem(itemData)
      elseif itemData:IsItemEmpty() and oldFrame ~= nil then
        -- The old frame exists, but the item is empty, so we need to delete it.
        self.itemsByBagAndSlot[bid][sid] = nil
        self.content:RemoveCell(oldFrame.guid, oldFrame)
        itemFrame:Release(oldFrame)
      end
    end
  end

  self.content:Sort(function (a, b)
    ---@cast a +Item
    ---@cast b +Item
    return a.mixin:GetItemQuality() > b.mixin:GetItemQuality()
  end)

  -- Redraw the world.
  local w, h = self.content:Draw()
  self.frame:SetWidth(w + 12)
  self.frame:SetHeight(h + 12 + self.leftHeader:GetHeight() + self.title:GetHeight())
end

-- DrawSectionGridBag draws all items in sections according to their configured type.
-- This is the tradition AdiBags style.
---@param dirtyItems table<number, table<number, ItemMixin>>
function bagProto:DrawSectionGridBag(dirtyItems)
  for bid, bagData in pairs(dirtyItems) do
    self.itemsByBagAndSlot[bid] = self.itemsByBagAndSlot[bid] or {}
    for sid, itemData in pairs(bagData) do
      local bagid, slotid = itemData:GetItemLocation():GetBagAndSlot()
      local oldFrame = self.itemsByBagAndSlot[bagid][slotid] --[[@as Item]]
      -- The old frame does not exist, so we need to create a new one.
      if oldFrame == nil and not itemData:IsItemEmpty() then
        local newFrame = itemFrame:Create()
        newFrame:SetItem(itemData)
        local category = newFrame:GetCategory()
        local section
        if newFrame:IsNewItem() then
          section = self.recentItems
        else
          section = self.sections[category]
        end
        -- Create the section if it doesn't exist.
        if section == nil then
          debug:Log("create", "creating category " .. category)
          section = sectionFrame:Create()
          section:SetTitle(category)
          section.content.maxCellWidth = 5
          self.content:AddCell(category, section)
          self.sections[category] = section
        end
        section.content:AddCell(itemData:GetItemGUID(), newFrame)
        newFrame:AddToMasqueGroup(self.kind)
        self.itemsByBagAndSlot[bagid][slotid] = newFrame
      elseif oldFrame ~= nil and not itemData:IsItemEmpty() then
        -- The old frame exists, so we need to update it.
        oldFrame:SetItem(itemData)
      elseif itemData:IsItemEmpty() and oldFrame ~= nil then
        -- The old frame exists, but the item is empty, so we need to delete it.
        self.itemsByBagAndSlot[bid][sid] = nil

        -- Special handling for the recent items section.
        if self.recentItems:HasItem(oldFrame) then
          self.recentItems.content:RemoveCell(oldFrame.guid, oldFrame)
        else
          local section = self.sections[oldFrame:GetCategory()]
          section.content:RemoveCell(oldFrame.guid, oldFrame)
          -- Delete the section if it's empty as well.
          if #section.content.cells == 0 then
            self.content:RemoveCell(oldFrame:GetCategory(), section)
            sectionFrame:Release(section)
            self.sections[oldFrame:GetCategory()] = nil
          end
        end
        itemFrame:Release(oldFrame)
      end
    end
  end

  -- Loop through each section and draw it's size.
  local recentW, recentH = self.recentItems:Draw()
  for _, section in pairs(self.sections) do
    section:Draw()
  end

  -- Sort all sections by title.
  self.content:Sort(function(a, b)
    ---@cast a +Section
    ---@cast b +Section
    return a.title:GetText() < b.title:GetText()
  end)

  -- Position all sections and draw the main bag.
  local w, h = self.content:Draw()
  -- Reposition the content frame if the recent items section is empty.
  if recentW == 0 then
    self.content.frame:SetPoint("TOPLEFT", self.leftHeader, "BOTTOMLEFT", 3, -3)
  else
    self.content.frame:SetPoint("TOPLEFT", self.recentItems.frame, "BOTTOMLEFT", 3, -3)
  end

  --debug:DrawDebugBorder(self.content.frame, 1, 1, 1)
  self.frame:SetWidth(w + 3)
  self.frame:SetHeight(h + 12 + self.leftHeader:GetHeight() + self.title:GetHeight() + recentH)
end

-- DrawSectionListBag draws the bag as a scrollable list of sections with a small icon
-- and the item name as a single row.
function bagProto:DrawSectionListBag()
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

  b.itemsByBagAndSlot = {}
  b.sections = {}
  b.kind = kind
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  -- The main display frame for the bag.
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", "BetterBagsBag"..name, nil, "BackdropTemplate")

  -- Setup the main frame defaults.
  b.frame = f
  b.frame:SetParent(UIParent)
  b.frame:Hide()
  b.frame:SetSize(200, 200)

  Window.RegisterConfig(b.frame, database:GetBagPosition(kind))
  -- Setup the default skin/theme.
  -- TODO(lobato): Move this to a separate module for themes.
  b.frame:SetBackdropColor(0, 0, 0, 1)
  b.frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = LSM:Fetch(LSM.MediaType.BORDER, "Blizzard Tooltip"),
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })

  -- Create the top left header.
  ---@class Frame: BackdropTemplate
  local leftHeader = CreateFrame("Frame", nil, b.frame, "BackdropTemplate")
  leftHeader:SetPoint("TOPLEFT", 3, -8)
  leftHeader:SetPoint("TOPRIGHT", -3, 3)
  leftHeader:SetHeight(20)
  leftHeader:Show()
  b.leftHeader = leftHeader

  --debug:DrawDebugBorder(leftHeader, 1, 1, 1)

  local bagButton = CreateFrame("Button")
  bagButton:SetParent(leftHeader)
  bagButton:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
  bagButton:SetHighlightTexture([[Interface\Buttons\CheckButtonHilight]])
  bagButton:SetWidth(18)
  bagButton:SetHeight(18)
  bagButton:SetPoint("LEFT", leftHeader, "LEFT", 4, 0)


  -- Create the bag title.
  local title = b.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  title:SetFontObject("GameFontNormal")
  title:SetHeight(18)
  title:SetJustifyH("LEFT")
  title:SetPoint("LEFT", bagButton, "RIGHT", 4, 0)
  b.title = title

  -- Create the bag content frame.
  local content = grid:Create(b.frame)
  content.frame:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 3, -3)
  content.frame:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -3, 3)
  content.maxCellWidth = 3
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

  local slots = bagSlots:CreatePanel(kind)
  slots.frame:SetPoint("BOTTOMLEFT", b.frame, "TOPLEFT", 0, 3)
  slots.frame:SetParent(b.frame)
  b.slots = slots

  -- Enable dragging of the bag frame.
  b.frame:SetMovable(true)
  b.frame:EnableMouse(true)
  b.frame:RegisterForDrag("LeftButton")
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
  bagButton:SetScript("OnClick", function()
    context:Show(contextMenu)
  end)
  return b
end

--- Destroy destroys the given bag view.
---@param bag Bag
function bagFrame:Destroy(bag)
end