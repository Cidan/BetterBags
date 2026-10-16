---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Debug : AceModule
local debug = addon:GetModule('Debug')

---@param view View
---@param ctx Context
local function Wipe(view, ctx)
  debug:Log("Wipe", "Bag View Wipe")
  view.content:Wipe()
  if view.freeSlot ~= nil then
    view.freeSlot:Release(ctx)
    view.freeSlot = nil
  end
  if view.freeReagentSlot ~= nil then
    view.freeReagentSlot:Release(ctx)
    view.freeReagentSlot = nil
  end
  view.itemCount = 0
  local k, section = next(view.sections)
  while k do
    view.sections[k] = nil
    section:ReleaseAllCells(ctx)
    section:Release(ctx)
    k, section = next(view.sections)
  end
  wipe(view.itemsByBagAndSlot)
  view.sortRequired = true
  view.isNew = true
end



---@param parent Frame
---@param kind BagKind
---@param tabID? number
---@return View
function views:NewBagView(parent, kind, tabID)
  local view = views:NewBlankView()
  view.itemFrames = {}
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_ALL_BAGS
  view.kind = kind
  view.tabID = tabID or 1
  view.content = grid:Create(parent, false)
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetAllPoints(parent)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.WipeHandler = Wipe
  view.isNew = true

  return view
end
