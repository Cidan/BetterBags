---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:GetModule('BagSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class BagButtonFrame: AceModule
local bagButton = addon:GetModule('BagButton')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@param ctx Context
---@param kind BagKind
---@return bagSlots
function BagSlots:CreatePanel(ctx, kind)
  ---@class bagSlots
  local b = {}
  setmetatable(b, {__index = BagSlots.bagSlotProto})
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"
  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", name .. "BagSlots", UIParent)
  b.frame = f

  themes:RegisterSimpleWindow(f, L:G("Equipped Bags"))
  --ButtonFrameTemplate_HidePortrait(b.frame)
  --ButtonFrameTemplate_HideButtonBar(b.frame)
  --b.frame.Inset:Hide()
  --b.frame:SetTitle(L:G("Equipped Bags"))

  b.content = grid:Create(b.frame)
  b.content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET, -30)
  b.content:GetContainer():SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, 12)
  b.content.maxCellWidth = 10
  b.content:HideScrollBar()
  b.content:Show()

  local bags = kind == const.BAG_KIND.BACKPACK and const.BACKPACK_ONLY_BAGS_LIST or const.BANK_ONLY_BAGS_LIST
  for i, bag in pairs(bags) do
    local iframe = bagButton:Create()
    iframe:SetBag(ctx, bag)
    b.content:AddCell(tostring(i), iframe)
  end

  b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeAndSlideTop(b.frame)
  b.fadeInGroup:HookScript("OnFinished", function()
    local ectx = context:New()
    ectx:Set('event', 'bag_slots_fade_in_finished')
    if database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
      return
    end
    database:SetPreviousView(kind, database:GetBagView(kind))
    database:SetBagView(kind, const.BAG_VIEW.SECTION_ALL_BAGS)
    events:SendMessage('bags/FullRefreshAll', ectx)
  end)
  b.fadeOutGroup:HookScript("OnFinished", function()
    local ectx = context:New()
    ectx:Set('event', 'bag_slots_fade_out_finished')
    database:SetBagView(kind, database:GetPreviousView(kind))
    events:SendMessage('bags/FullRefreshAll', ectx)
  end)
  events:RegisterEvent("BAG_CONTAINER_UPDATE", function() b:Draw() end)
  b.kind = kind
  b:Hide()
  return b
end