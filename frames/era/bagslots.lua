---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()

-- Create the bagslot module.
local BagSlots = addon:GetBagSlots()

local const = addon:GetConstants()
local L = addon:GetLocalization()

local grid = addon:GetGrid()

local bagButton = addon:GetBagButton()

local events = addon:GetEvents()

local items = addon:GetItems()

local debug = addon:GetDebug()

local animations = addon:GetAnimations()

local database = addon:GetDatabase()

local themes = addon:GetThemes()

local context = addon:GetContext()

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
    local iframe = bagButton:Create(ctx)
    iframe:SetBag(ctx, bag)
    b.content:AddCell(tostring(i), iframe)
  end

  b.fadeInGroup, b.fadeOutGroup = animations:AttachFadeAndSlideTop(b.frame)
  b.fadeInGroup:HookScript("OnFinished", function()
    local ectx = context:New('bag_slots_fade_in_finished')
    if database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
      return
    end
    database:SetPreviousView(kind, database:GetBagView(kind))
    database:SetBagView(kind, const.BAG_VIEW.SECTION_ALL_BAGS)
    events:SendMessage(ectx, 'bags/FullRefreshAll')
  end)
  b.fadeOutGroup:HookScript("OnFinished", function()
    local ectx = context:New('bag_slots_fade_out_finished')
    database:SetBagView(kind, database:GetPreviousView(kind))
    events:SendMessage(ectx, 'bags/FullRefreshAll')
  end)
  events:RegisterEvent("BAG_CONTAINER_UPDATE", function(ectx) b:Draw(ectx) end)
  b.kind = kind
  b:Hide()
  return b
end