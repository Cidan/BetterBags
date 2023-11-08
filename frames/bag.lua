local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class BagFrame: AceModule
local bagFrame = addon:NewModule('BagFrame')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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
---@field content Frame The main content frame of the bag.
local bagProto = {}

function bagProto:Show()
  self.frame:Show()
end

function bagProto:Hide()
  self.frame:Hide()
end

function bagProto:Toggle()
  if self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

--- Draw is the main entry point for drawing the bag.
function bagProto:Draw()
  
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
  ---@class Frame: BackdropTemplate
  local content = CreateFrame("Frame", nil, b.frame, "BackdropTemplate")
  content:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -3)
  content:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -3, 3)
  content:Show()
  b.content = content

  --debug:DrawDebugBorder(content, 1, 1, 1)

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