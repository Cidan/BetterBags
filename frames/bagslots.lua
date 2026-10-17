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

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class WindowModule: AceModule
local window = addon:GetModule('Window')

---@class SonataApply: AceModule
local apply = addon:GetModule('SonataApply')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- The "Show Bags" panel is a Slots window (window/window.lua) hanging below its bag, sized to
-- its bag buttons plus the theme's padding, and shown in place of the bag's group tabs. The
-- theme draws its chrome (sonata.md section 3b) and says where it sits (Layout.Offset).
---@class bagSlots
---@field window BetterBagsWindow
---@field frame Frame
---@field bagFrame Frame
---@field content Grid
---@field grid Drawable
---@field kind BagKind
---@field tabsWereShown boolean
BagSlots.bagSlotProto = {}
addon:GetModule('Perf'):RegisterPrototype(BagSlots.bagSlotProto, 'BagSlotsPanel')

---@return Bag?
function BagSlots.bagSlotProto:GetParentBag()
  local bags = addon.Bags
  if bags == nil then
    return nil
  end
  if self.kind == const.BAG_KIND.BACKPACK then
    return bags.Backpack
  end
  return bags.Bank
end

-- Draw redraws the bag buttons and lays the panel out again: at once while it shows, else
-- when it is shown.
---@param ctx Context
function BagSlots.bagSlotProto:Draw(ctx)
  debug:Log('BagSlots', "Bag Slots Draw called")
  for _, cell in ipairs(self.content.cells) do
    ---@cast cell +BagButton
    cell:Draw(ctx)
  end
  if self.window:IsShown() then
    render:RenderNow(self.window, { ctx = ctx })
  else
    self.window:Invalidate()
  end
end

-- OnRendered lays the panel's bag out again: the bag is never narrower than the panel.
function BagSlots.bagSlotProto:OnRendered()
  local bag = self:GetParentBag()
  if bag ~= nil and bag.window ~= nil and self.window:IsShown() then
    bag.window:Invalidate()
  end
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
  -- Where the theme says: Layout.Points relative to the bag, else Layout.Offset below it.
  local layout = self.window:GetLayout()
  if layout.Points ~= nil then
    apply:Points(self.frame, layout.Points, self.bagFrame)
  else
    local offset = layout.Offset or {}
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", self.bagFrame, "BOTTOMLEFT", offset.X or 0, offset.Y or 0)
  end

  local parentBag = self:GetParentBag()
  if parentBag and parentBag.tabs then
    if not self:IsShown() then
      self.tabsWereShown = parentBag.tabs.frame:IsShown()
    end
    parentBag.tabs.frame:Hide()
  elseif not self:IsShown() then
    self.tabsWereShown = false
  end

  self.window:Show(context:New('BagSlots_Show'), callback)
end

-- Hide fades the panel out, then gives the bag its tabs back.
---@param callback? fun()
function BagSlots.bagSlotProto:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  local ctx = context:New('BagSlots_Hide')
  self.window:Hide(ctx, function()
    self:OnClose(ctx)
    if callback then
      callback()
    end
  end)
end

function BagSlots.bagSlotProto:IsShown()
  return self.window:IsShown()
end

---@param _ctx Context
function BagSlots.bagSlotProto:OnClose(_ctx)
  local parentBag = self:GetParentBag()
  if (self.tabsWereShown or database:GetGroupsEnabled(self.kind)) and parentBag and parentBag.tabs then
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
  b.kind = kind
  b.tabsWereShown = false
  local name = kind == const.BAG_KIND.BACKPACK and "Backpack" or "Bank"

  b.window = window:Create({
    Kind = "Slots",
    Name = name .. "BagSlots",
    Title = "",
    Parent = bagFrame,
    Movable = false,
    Points = { { Point = "TOPLEFT", RelativeTo = bagFrame, RelativePoint = "BOTTOMLEFT", X = 0, Y = -2 } },
    OnRendered = function()
      b:OnRendered()
    end,
  })
  b.frame = b.window.frame

  b.content = grid:Create(b.window.content)
  b.content.maxCellWidth = 10
  b.content:HideScrollBar()
  -- Bag slots grid is not scrollable; disable mouse wheel so scroll events
  -- pass through to the outer scrollable bag container.
  b.content:EnableMouseWheelScroll(false)
  b.content:Show()
  b.grid = drawable:FromFrame(b.content:GetContainer(), function()
    return b.content:Draw({
      cells = b.content.cells,
      maxWidthPerRow = 1024,
    })
  end)
  b.window:SetContent(b.grid)

  local bags = kind == const.BAG_KIND.BACKPACK and const.BACKPACK_ONLY_BAGS_LIST or const.BANK_ONLY_BAGS_LIST
  for i, bag in pairs(bags) do
    local iframe = bagButton:Create(ctx)
    iframe:SetBag(ctx, bag)
    b.content:AddCell(tostring(i), iframe)
  end

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function(ectx) b:Draw(ectx) end)
  if not addon.isRetail then
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function(ectx) b:Draw(ectx) end)
  end
  return b
end
