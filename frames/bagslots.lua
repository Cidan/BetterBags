local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:NewModule('BagSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

local LSM = LibStub('LibSharedMedia-3.0')

---@class bagButton
local bagButtonProto = {}

---@class bagSlots
---@field frame Frame
---@field title FontString
---@field content Grid
local bagSlotProto = {}

function bagSlotProto:Draw()
  local w, h = self.content:Draw()
  w = w + 100
  h = h + 70
  self.frame:SetWidth(w + 6)
  self.frame:SetHeight(h + self.title:GetHeight() + 3)
end

function bagSlotProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

function bagSlotProto:Show()
  PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
  self.frame:Show()
end

function bagSlotProto:Hide()
  PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
  self.frame:Hide()
end

---@param kind BagKind
---@return bagSlots
function BagSlots:CreatePanel(kind)
  ---@class bagSlots
  local b = {}
  setmetatable(b, {__index = bagSlotProto})
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", name .. "BagSlots", UIParent, "BackdropTemplate")
  b.frame = f
  b.frame:SetBackdropColor(0, 0, 0, 1)
  b.frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = LSM:Fetch(LSM.MediaType.BORDER, "Blizzard Tooltip"),
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })

  local title = b.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText(L:G("Equipped Bags"))
  title:SetFontObject("GameFontNormal")
  title:SetHeight(18)
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", b.frame, "TOPLEFT", 6, -3)
  b.title = title

  b.content = grid:Create(b.frame)
  b.content.frame:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, 3)
  b.content:Show()
  return b
end