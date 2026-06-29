---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Create the bagslot module.
---@class BagSlots: AceModule
local BagSlots = addon:NewModule('BagSlots')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class BagButtonFrame: AceModule
local bagButton = addon:GetModule('BagButton')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Database: AceModule
local database = addon:GetModule('Database')

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

  local headerHeight = themes:GetFlatHeaderHeight(self.frame)
  local topInset = headerHeight > 0 and headerHeight or 12
  local leftInset = addon.isRetail and (const.OFFSETS.BAG_LEFT_INSET + 4) or const.OFFSETS.BAG_LEFT_INSET

  self.content:GetContainer():ClearAllPoints()
  self.content:GetContainer():SetPoint("TOPLEFT", self.frame, "TOPLEFT", leftInset, -topInset)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", const.OFFSETS.BAG_RIGHT_INSET, 12)

  self.frame:SetHeight(h + topInset + 12)
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
  self.frame:ClearAllPoints()
  self.frame:SetPoint("TOPLEFT", self.bagFrame, "BOTTOMLEFT", 0, -2)

  local parentBag = addon.Bags and (self.kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank)
  if parentBag and parentBag.tabs then
    if not self:IsShown() then
      self.tabsWereShown = parentBag.tabs.frame:IsShown()
    end
    parentBag.tabs.frame:Hide()
  else
    if not self:IsShown() then
      self.tabsWereShown = false
    end
  end

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

---@param _ctx Context
function BagSlots.bagSlotProto:OnClose(_ctx)
  local parentBag = addon.Bags and (self.kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank)
  if self.tabsWereShown and parentBag and parentBag.tabs then
    parentBag.tabs.frame:Show()
  end
  self.tabsWereShown = false
end

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

  b.content = grid:Create(b.frame)
  b.content:GetContainer():SetPoint("TOPLEFT", b.frame, "TOPLEFT", const.OFFSETS.BAG_LEFT_INSET + 4, -30)
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

    b.frame:ClearAllPoints()
    b.frame:SetPoint("BOTTOMLEFT", bagFrame, "TOPLEFT", 0, 14)

    local parentBag = addon.Bags and (kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank)
    if b.tabsWereShown and parentBag and parentBag.tabs then
      parentBag.tabs.frame:Show()
    end
    b.tabsWereShown = false
  end)

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function(ectx) b:Draw(ectx) end)
  if not addon.isRetail then
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function(ectx) b:Draw(ectx) end)
  end
  b.kind = kind
  b.frame:Hide()
  return b
end
