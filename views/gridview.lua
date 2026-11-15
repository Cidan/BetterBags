---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Views: AceModule
local views = addon:GetModule('Views')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Debug : AceModule
local debug = addon:GetModule('Debug')

-- The hint in an empty group's tab wraps at HINT_WIDTH and keeps HINT_MARGIN around it, so it takes 260 across: as wide
-- as a bag's content at its narrowest (MIN_CONTENT_WIDTH, frames/bag.lua), which puts it in the middle of a bag sized to
-- its content unless something else, a wide tab bar, makes the window wider.
local HINT_WIDTH = 220
local HINT_MARGIN = 20

-- EmptyGroupSize is the room the hint in an empty group's tab takes: its width and its text's height, with the margin
-- around them. The height is read each time, as a theme's font may have changed it.
---@param view View
---@return number width, number height
local function EmptyGroupSize(view)
  return HINT_WIDTH + 2 * HINT_MARGIN, view.emptyGroupHint:GetStringHeight() + 2 * HINT_MARGIN
end

---@param view View
---@param ctx Context
local function Wipe(view, ctx)
  debug:Log("Wipe", "Grid View Wipe")
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
function views:NewGrid(parent, kind, tabID)
  local view = views:NewBlankView()
  view.itemCount = 0
  view.bagview = const.BAG_VIEW.SECTION_GRID
  view.kind = kind
  view.tabID = tabID or 1
  view.content = grid:Create(parent, false)
  view.content:SortVertical()
  view.content:GetContainer():ClearAllPoints()
  view.content:GetContainer():SetAllPoints(parent)
  view.content.compactStyle = const.GRID_COMPACT_STYLE.NONE
  view.content:Hide()
  view.WipeHandler = Wipe
  view.sortRequired = false
  view.isNew = true

  -- Create empty group state frame (only for backpack)
  if kind == const.BAG_KIND.BACKPACK then
    local emptyGroupFrame = CreateFrame("Frame", nil, view.content:GetContainer())
    emptyGroupFrame:SetAllPoints()
    emptyGroupFrame:SetFrameLevel(view.content:GetContainer():GetFrameLevel() + 10)
    emptyGroupFrame:Hide()

    local helpText = sonata:CreateText(emptyGroupFrame, "Muted")
    helpText:SetPoint("CENTER", emptyGroupFrame, "CENTER", 0, 0)
    helpText:SetText(L:G("Drag a section header to this tab at the bottom of the window to add a section to this group!"))
    helpText:SetWidth(HINT_WIDTH)
    helpText:SetJustifyH("CENTER")

    view.emptyGroupFrame = emptyGroupFrame
    view.emptyGroupHint = helpText
    view.EmptyGroupSizeHandler = EmptyGroupSize
  end

  return view
end
