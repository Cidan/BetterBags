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

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

local LSM = LibStub('LibSharedMedia-3.0')

-------
--- Bag Prototype
-------

--- Bag is a view of a single bag object. Note that this is not
--- a single bag slot, but a combined view of all bags for a given
--- kind (i.e. bank, backpack).
---@class Bag
---@field frame Frame The raw frame of the bag.
---@field leftHeader Frame The top left header of the bag.
---@field title FontString The title of the bag.
---@field content Grid The main content frame of the bag.
---@field guidToItemFrame table<string, Item> A map of item GUIDs to item frames.
local bagProto = {}

function bagProto:Show()
  self.frame:Show()
end

function bagProto:Hide()
  self.frame:Hide()
end

function bagProto:Toggle()
  self.frame:SetShown(not self.frame:IsShown())
end

-- Wipe will wipe the contents of the bag and release all cells.
function bagProto:Wipe()
  for _, cell in ipairs(self.content.cells) do
    ---@cast cell -Section,-Cell
    itemFrame:Release(cell)
  end
  self.content:Wipe()
  wipe(self.guidToItemFrame)
end

--- Draw does a complete redraw of the bags.
function bagProto:Draww()
  self:Wipe()
  debug:Log("bagProto/Draw", "Drawing bag", self.kind)
  for _, itemData in pairs(items.items) do
    for guid, item in pairs(itemData) do
      local iframe = itemFrame:Create()
      iframe:SetItem(item)
      self.content:AddCell(guid, iframe)
      self.guidToItemFrame[guid] = iframe
    end
  end
  local w, h = self.content:Draw()
  self.frame:SetWidth(w + 12)
  self.frame:SetHeight(h + 12 + self.leftHeader:GetHeight() + self.title:GetHeight())
end

-- Refresh will only refresh the dirty items in a bag.
function bagProto:Refresh()
  for _, bagData in pairs(items.dirtyItems) do
   for _, itemData in pairs(bagData) do
    local guid
    if itemData:IsItemEmpty() then
      guid = "0"
    else
      guid = itemData:GetItemGUID()
    end
    local oldFrame = self.guidToItemFrame[guid] --[[@as Item]]

    -- The old frame does not exist, so we need to create a new one.
    if oldFrame == nil and not itemData:IsItemEmpty() then
      local newFrame = itemFrame:Create()
      newFrame:SetItem(itemData)
      self.content:AddCell(guid, newFrame)
      self.guidToItemFrame[itemData:GetItemGUID()] = newFrame
    elseif itemData:IsItemEmpty() and oldFrame ~= nil then
      --TODO(lobato): delete the item frame.
      -- remove cell from grid
      -- remove item from guidToItemFrame
      -- release item frame 
    elseif oldFrame ~= nil then
      -- The old frame exists, so we need to update it.
      oldFrame:SetItem(itemData)
    end
   end
  end
  local w, h = self.content:Draw()
  self.frame:SetWidth(w + 12)
  self.frame:SetHeight(h + 12 + self.leftHeader:GetHeight() + self.title:GetHeight())
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
  setmetatable(b, { __index = bagProto })
  -- TODO(lobato): Compose the entire frame here.

  b.guidToItemFrame = {}
  b.kind = kind
  -- The main display frame for the bag.
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")

  -- Setup the main frame defaults.
  b.frame = f
  b.frame:SetParent(UIParent)
  b.frame:Hide()
  b.frame:SetSize(200, 200)
  b.frame:SetPoint("CENTER")

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
  leftHeader:SetPoint("TOPLEFT", 3, -3)
  leftHeader:SetPoint("TOPRIGHT", -3, -3)
  leftHeader:SetHeight(20)
  leftHeader:Show()
  b.leftHeader = leftHeader

  --debug:DrawDebugBorder(leftHeader, 1, 1, 1)

  -- Create the bag title.
  local title = b.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText(L:G(kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"))
  title:SetFontObject("GameFontNormal")
  title:SetHeight(18)
  title:SetJustifyH("LEFT")
  title:SetPoint("LEFT", leftHeader, "LEFT", 4, 0)
  b.title = title

  -- Create the bag content frame.
  local content = grid:Create(b.frame)
  content.frame:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 3, -3)
  content.frame:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -3, 3)
  content:Show()
  b.content = content

  --debug:DrawDebugBorder(content.frame, 1, 1, 1)

  -- Enable dragging of the bag frame.
  b.frame:SetMovable(true)
  b.frame:EnableMouse(true)
  b.frame:RegisterForDrag("LeftButton")
  b.frame:SetScript("OnDragStart", function(drag)
    drag:StartMoving()
  end)
  b.frame:SetScript("OnDragStop", function(drag)
    drag:StopMovingOrSizing()
  end)
  return b
end

--- Destroy destroys the given bag view.
---@param bag Bag
function bagFrame:Destroy(bag)
end