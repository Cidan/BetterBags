---@diagnostic disable: duplicate-set-field,duplicate-doc-field



local addon = GetBetterBags()

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:NewModule('BagSlots')

local const = addon:GetConstants()
local L = addon:GetLocalization()

local grid = addon:GetGrid()

local bagButton = addon:GetBagButton()

local events = addon:GetEvents()

local items = addon:GetItems()

local debug = addon:GetDebug()

local animations = addon:GetAnimations()

local themes = addon:GetThemes()

local database = addon:GetDatabase()

local context = addon:GetContext()

---@class bagSlots
---@field frame Frame
---@field content Grid
---@field kind BagKind
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
BagSlots.bagSlotProto = {}

---@param ctx Context
function BagSlots.bagSlotProto:Draw(ctx)
  debug:Log('BagSlots', "Bag Slots Draw called")
  for _, cell in ipairs(self.content.cells) do
    ---@cast cell +BagButton
    cell:Draw(ctx)
  end
  local w, h = self.content:Draw({
    cells = self.content.cells,
    maxWidthPerRow = 1024,
  })
  self.frame:SetWidth(w + const.OFFSETS.BAG_LEFT_INSET + -const.OFFSETS.BAG_RIGHT_INSET + 4)
  self.frame:SetHeight(h + 42)
end

function BagSlots.bagSlotProto:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

---@param callback? fun()
function BagSlots.bagSlotProto:Show(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeInGroup.callback = function()
      self.fadeInGroup.callback = nil
      callback()
    end
  end
  self.fadeInGroup:Play()
end

---@param callback? fun()
function BagSlots.bagSlotProto:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOutGroup.callback = function()
      self.fadeOutGroup.callback = nil
      callback()
    end
  end
  self.fadeOutGroup:Play()
end

function BagSlots.bagSlotProto:IsShown()
  return self.frame:IsShown()
end

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

  themes:RegisterFlatWindow(f, L:G("Equipped Bags"))

  b.content = grid:Create(b.frame)
  b.content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET + 4, -30)
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

  addon.HookScript(b.fadeInGroup, "OnFinished", function(ectx)
    if database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
      return
    end
    database:SetPreviousView(kind, database:GetBagView(kind))
    database:SetBagView(kind, const.BAG_VIEW.SECTION_ALL_BAGS)
    events:SendMessage(ectx, 'bags/FullRefreshAll')
  end)

  addon.HookScript(b.fadeOutGroup, "OnFinished", function(ectx)
    database:SetBagView(kind, database:GetPreviousView(kind))
    events:SendMessage(ectx, 'bags/FullRefreshAll')
  end)

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function(ectx) b:Draw(ectx) end)
  events:RegisterEvent('PLAYERBANKBAGSLOTS_CHANGED', function(ectx) b:Draw(ectx) end)
  b.kind = kind
  b.frame:Hide()
  return b
end