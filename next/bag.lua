local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class BackpackBehavior: AceModule
local backpackBehavior = addon:GetModule('BackpackBehavior')

---@class NextPanel: AceModule
local nextPanel = addon:GetModule('NextPanel')

-- NextBag is BetterBagsNext's backpack (next.md): the panel on the right of the screen
-- (next/panel.lua), its tabs the backpack's groups. It stands in for the backpack everywhere the
-- addon talks to it (next.md §1).
---@class NextBag: AceModule
local nextBag = addon:NewModule('NextBag')

---@class NextBackpack: NextPanelFrame
---@field sortButton Button
---@field sizeButton Button Switches every panel between full and small (UpdateSizeButton).
---@field settingsButton Button
---@field behavior {SwitchToGroup: fun(self: any, ctx: Context, id: number)}
---@field helper BackpackBehaviorProto The classic behavior, for its group dialogs.
local bagProto = nextPanel:Extend({}, 'NextBackpack')
bagProto.watchesCooldowns = true

---@param ctx Context
---@return NextBackpack
function nextBag:Create(ctx)
  local _ = ctx
  ---@type NextBackpack
  local b = nextPanel:Create(bagProto, {
    kind = const.BAG_KIND.BACKPACK,
    side = "RIGHT",
    name = "BetterBagsNextBackpack",
    scrollName = "BetterBagsNextScroll",
    title = L:G("Backpack"),
    openSound = SOUNDKIT.IG_BACKPACK_OPEN,
    closeSound = SOUNDKIT.IG_BACKPACK_CLOSE,
    chainRole = "backpack",
  })
  b:UpdateSizeButton()
  b.helper = backpackBehavior:Create(b)
  b.behavior = {
    SwitchToGroup = function(_, ectx, id)
      b:SwitchToGroup(ectx, id)
    end,
  }
  return b
end

---@return NextHeaderButton[]
function bagProto:GetHeaderButtons()
  return {
    { key = "settingsButton", atlas = "uitools-icon-settings", glyph = true, tooltip = L:G("Open Options Screen"),
      onClick = function(ctx) events:SendMessage(ctx, "config/Open") end },
    { key = "sortButton", atlas = "bags-button-autosort-up", tooltip = L:G("Sort Bags"),
      onClick = function(ctx) self:Sort(ctx) end },
    -- The way back to the classic bags, without a reload (next.md §11): Blizzard's backpack button's
    -- art, bag-main on retail and WoW: Forever, Button-Backpack-Up on Classic.
    { key = "classicButton", atlas = addon.isRetail and "bag-main" or nil,
      texture = not addon.isRetail and "Interface\\Buttons\\Button-Backpack-Up" or nil,
      tooltip = L:G("Switch to Classic Bags"),
      onClick = function(ctx) addon:GetModule('BagSystem'):Switch(ctx, "classic") end },
    -- Small mode (docs/next-small-mode.md): every BetterBags Next panel full height or small and
    -- movable. Its art is UpdateSizeButton's.
    { key = "sizeButton", tooltipFunc = function() self:SizeTooltip() end,
      onClick = function(ctx) nextPanel:SetSize(ctx, self:IsSmall() and "full" or "small") end },
  }
end

-- UpdateSizeButton shows what the size button does: Blizzard's minimize art while full, its maximize
-- art while small (MaximizeMinimizeButtonFrameTemplate's RedButton-Condense and RedButton-Expand on
-- retail and WoW: Forever; Classic's smaller and bigger buttons, SharedUIPanelTemplates.xml).
function bagProto:UpdateSizeButton()
  local small = self:IsSmall()
  local art
  if addon.isRetail then
    art = { atlas = small and "RedButton-Expand" or "RedButton-Condense" }
  else
    art = { texture = small and "Interface\\Buttons\\UI-Panel-BiggerButton-Up"
      or "Interface\\Buttons\\UI-Panel-SmallerButton-Up" }
  end
  -- A theme can draw its own for either state (Header.Buttons.Icons: sizeButtonSmall, sizeButtonFull).
  self:SetHeaderIcon(self.sizeButton, small and "sizeButtonSmall" or "sizeButtonFull", art)
end

-- SizeTooltip says what the size button does.
function bagProto:SizeTooltip()
  if self:IsSmall() then
    GameTooltip:SetText(L:G("Full Size Bags"), 1, 1, 1, 1, true)
    GameTooltip:AddLine(L:G("Full-height bags on the edges of the screen."), nil, nil, nil, true)
  else
    GameTooltip:SetText(L:G("Small Bags"), 1, 1, 1, 1, true)
    GameTooltip:AddLine(L:G("Smaller bags you can move anywhere: drag a bag by its title."), nil, nil, nil, true)
  end
end

---@return Money
function bagProto:CreateMoney()
  return money:Create()
end

-- RefreshTabs lists the backpack's groups as tabs, in their order, with a last one to make a
-- group, and selects the active one. With groups off there are no tabs.
function bagProto:RefreshTabs()
  if not database:GetGroupsEnabled(self.kind) then
    self.tabs.frame:Hide()
    return
  end
  local entries = {}
  for id, group in pairs(groups:GetAllGroups(self.kind)) do
    table.insert(entries, { id = id, name = group.name })
  end
  table.sort(entries, function(a, b) return a.id < b.id end)
  table.insert(entries, {
    id = 0,
    name = "+",
    tooltip = { L:G("New Group..."), L:G("Click to create a new group for organizing categories.") },
  })
  self.tabs:SetTabs(entries)
  self.tabs:Select(self:GetCurrentTabID())
  self.tabs.frame:Show()
end

-- OnTabClicked switches group on a left click, opens a group's menu on a right click (not the
-- Backpack group's), and opens the new group dialog from the last tab.
---@param ctx Context
---@param id number
---@param button string
function bagProto:OnTabClicked(ctx, id, button)
  if id == 0 then
    self.helper:ShowCreateGroupDialog()
    return
  end
  if button == "RightButton" then
    if id ~= 1 then
      self.helper:ShowGroupContextMenu(ctx, id)
    end
    return
  end
  self:SwitchToGroup(ctx, id)
end

-- SwitchToGroup shows a group: the same data, drawn for its tab, fading in.
---@param ctx Context
---@param id number
function bagProto:SwitchToGroup(ctx, id)
  if groups:GetGroup(self.kind, id) == nil then
    return
  end
  database:SetActiveGroup(self.kind, id)
  self.tabs:Select(id, true)
  self.tabChanged = true
  self:Draw(ctx, items:GetAllSlotInfo()[self.kind], function() end)
  addon.TriggerItemContextChanged()
end

-- WatchKind lists the groups again when they change.
function bagProto:WatchKind()
  events:RegisterMessage("groups/Created", function(_, group)
    if group.kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("groups/Changed", function(_, _, _, _, kind)
    if kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("groups/Deleted", function(ctx, groupID, _, kind)
    if kind ~= self.kind then
      return
    end
    if database:GetActiveGroup(self.kind) == groupID then
      self:SwitchToGroup(ctx, 1)
    end
    self:RefreshTabs()
  end)
  events:RegisterMessage("groups/EnabledChanged", function(_, kind)
    if kind == self.kind then
      self:RefreshTabs()
    end
  end)
end

-- Refresh recalculates the backpack from what was last read.
---@param ctx Context
function bagProto:Refresh(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = false, categoriesUnchanged = true })
end

---@param ctx Context
function bagProto:Sort(ctx)
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  events:SendMessage(ctx, "bags/SortBackpack")
end
