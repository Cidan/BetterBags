---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:GetModule('BagSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class BagButtonFrame: AceModule
local bagButton = addon:GetModule('BagButton')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@param ctx Context
---@param kind BagKind
---@param bagFrame Frame
---@return bagSlots
function BagSlots:CreatePanel(ctx, kind, bagFrame)
  ---@class bagSlots
  local b = {}
  setmetatable(b, {__index = BagSlots.bagSlotProto})
  b.bagFrame = bagFrame
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", name .. "BagSlots", UIParent)
  b.frame = f

  themes:RegisterFlatWindow(f, "")
  --ButtonFrameTemplate_HidePortrait(b.frame)
  --ButtonFrameTemplate_HideButtonBar(b.frame)
  --b.frame.Inset:Hide()
  --b.frame:SetTitle(L:G("Equipped Bags"))

  b.content = grid:Create(b.frame)
  b.content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, -30)
  b.content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, 12)
  b.content.maxCellWidth = 10
  b.content:HideScrollBar()
  -- Bag slots grid is not scrollable; disable mouse wheel so scroll events
  -- pass through to the outer scrollable bag container.
  b.content:EnableMouseWheelScroll(false)
  b.content:Show()

  local bags = kind == const.BAG_KIND.BACKPACK and const.BACKPACK_ONLY_BAGS_LIST or const.BANK_ONLY_BAGS_LIST
  for i, bag in pairs(bags) do
    local iframe = bagButton:Create(ctx)
    iframe:SetBag(ctx, bag)
    b.content:AddCell(tostring(i), iframe)
  end

  b.tabsWereShown = false
  b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeAndSlideTop(b.frame)
  b.fadeOutGroup:HookScript("OnFinished", function()
    b.frame:ClearAllPoints()
    b.frame:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", 0, 14)

    local parentBag = addon.Bags and (kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank)
    if (b.tabsWereShown or database:GetGroupsEnabled(kind)) and parentBag and parentBag.tabs then
      parentBag.tabs.frame:Show()
    end
    b.tabsWereShown = false
  end)
  events:RegisterEvent("BAG_CONTAINER_UPDATE", function(ectx) b:Draw(ectx) end)
  b.kind = kind
  b:Hide()
  return b
end
