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

---@class BagButtonFrame: AceModule
local bagButton = addon:GetModule('BagButton')

local EMPTY_BAG_SLOT_TEXTURE = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]

-- NextBag is BetterBagsNext's backpack (next.md): the panel on the right of the screen
-- (next/panel.lua), its tabs the backpack's groups. It stands in for the backpack everywhere the
-- addon talks to it (next.md §1).
---@class NextBag: AceModule
local nextBag = addon:NewModule('NextBag')

---@class NextBackpack: NextPanelFrame
---@field sortButton Button
---@field sizeButton Button Switches every panel between full and small (UpdateSizeButton).
---@field closeButton Button
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
    -- Asked: "an X at the top right of the backpack to close it" (first: the screen edge).
    { key = "closeButton", tooltip = L:G("Close"), onClick = function(ctx) self:Hide(ctx) end },
    { key = "settingsButton", tooltip = L:G("Open Options Screen"),
      onClick = function(ctx) events:SendMessage(ctx, "config/Open") end },
    { key = "sortButton", tooltip = L:G("Sort Bags"),
      onClick = function(ctx) self:Sort(ctx) end },
    -- Show Blizzard Bags (asked: "the 'Switch to Classic Bags' icon now becomes 'Show Blizzard Bags'";
    -- docs/next-batch-2.md §4). The way back to the classic bags is in the settings and /bb next.
    { key = "bagsButton", tooltipFunc = function() self:BagsTooltip() end,
      onClick = function(ctx) self:ToggleBlizzardBags(ctx) end },
    -- Small mode (docs/next-small-mode.md): every BetterBags Next panel full height or small and
    -- movable. Its icon is its state's (SizeIconKey).
    { key = "sizeButton", iconKey = self:SizeIconKey(), tooltipFunc = function() self:SizeTooltip() end,
      onClick = function(ctx) nextPanel:SetSize(ctx, self:IsSmall() and "full" or "small") end },
  }
end

-- SizeIconKey is the size button's icon for the panel's size (Header.Buttons.Icons): sizeButtonFull
-- while full (arrows in: Small Bags), sizeButtonSmall while small (arrows out: Full Size Bags).
---@return string
function bagProto:SizeIconKey()
  return self:IsSmall() and "sizeButtonSmall" or "sizeButtonFull"
end

-- UpdateSizeButton shows what the size button does.
function bagProto:UpdateSizeButton()
  self:SetHeaderIcon(self.sizeButton, self:SizeIconKey())
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

-- ShowsBlizzardBags says whether the backpack shows Blizzard's bags (Show Blizzard Bags): its bag slots
-- in the tabs, its items bag by bag in slot order. It is the Show Bags view (SECTION_ALL_BAGS), the
-- classic bags' Show Bags, so it lasts across sessions and follows the classic bags' setting.
---@return boolean
function bagProto:ShowsBlizzardBags()
  return database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS
end

-- ToggleBlizzardBags switches between the groups and Blizzard's bags, as the classic backpack's Show
-- Bags does (ContextMenu:ToggleBagSlots): the view saved and the Show Bags view, or the saved view back;
-- the tabs listed again and the backpack recalculated. Not in combat.
---@param ctx Context
function bagProto:ToggleBlizzardBags(ctx)
  if InCombatLockdown() then
    print("BetterBags: " .. L:G("Cannot toggle bag slots in combat."))
    return
  end
  if self:ShowsBlizzardBags() then
    database:SetBagView(self.kind, database:GetPreviousView(self.kind))
  else
    database:SetPreviousView(self.kind, database:GetBagView(self.kind))
    database:SetBagView(self.kind, const.BAG_VIEW.SECTION_ALL_BAGS)
  end
  self.tabChanged = true
  self:RefreshTabs()
  events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = false, resetLayout = true })
end

-- BagsTooltip says what the Show Blizzard Bags button does.
function bagProto:BagsTooltip()
  if self:ShowsBlizzardBags() then
    GameTooltip:SetText(L:G("Show Categories"), 1, 1, 1, 1, true)
    GameTooltip:AddLine(L:G("Your groups in the tabs, your items in their categories."), nil, nil, nil, true)
  else
    GameTooltip:SetText(L:G("Show Blizzard Bags"), 1, 1, 1, 1, true)
    GameTooltip:AddLine(L:G("Your bags in the tabs, to swap them, and your items bag by bag."), nil, nil, nil, true)
  end
end

-- ListBags lists the backpack's bag slots as tabs (Show Blizzard Bags), as the classic Show Bags panel
-- does: each slot its bag's icon and name, an empty one Blizzard's empty bag slot art and "Empty Bag
-- Slot"; none selected. The backpack itself has no slot.
function bagProto:ListBags()
  local entries = {}
  for _, bag in ipairs(const.BACKPACK_ONLY_BAGS_LIST) do
    local invID = C_Container.ContainerIDToInventoryID(bag)
    local icon = GetInventoryItemTexture("player", invID)
    local empty = const.BACKPACK_ONLY_REAGENT_BAGS[bag] ~= nil and L:G("Empty Reagent Bag Slot") or L:G("Empty Bag Slot")
    table.insert(entries, {
      id = bag,
      name = icon ~= nil and C_Container.GetBagName(bag) or empty,
      icon = icon or EMPTY_BAG_SLOT_TEXTURE,
      draggable = true,
      bag = true,
      tooltip = function() self:BagSlotTooltip(invID, icon ~= nil, empty) end,
    })
  end
  self.tabs:SetTabs(entries)
  self.tabs:Select(nil)
  self.tabs.frame:Show()
end

-- BagSlotTooltip shows a bag slot's tooltip, as Blizzard's bag slots do: the bag's own, or what the slot
-- takes; then how to swap it.
---@param invID number
---@param hasBag boolean
---@param empty string
function bagProto:BagSlotTooltip(invID, hasBag, empty)
  if hasBag then
    GameTooltip:SetInventoryItem("player", invID)
    GameTooltip:AddLine(L:G("Drag it, or Shift-click it, to take it out."), nil, nil, nil, true)
  else
    GameTooltip:SetText(empty, 1, 1, 1, 1, true)
  end
  GameTooltip:AddLine(L:G("Drop a bag here to put it in this slot."), nil, nil, nil, true)
end

-- RefreshTabs lists the backpack's groups as tabs, in their order, with a last one to make a
-- group, and selects the active one. With groups off there are no tabs. Showing Blizzard's bags, it
-- lists the bag slots (ListBags).
function bagProto:RefreshTabs()
  if self:ShowsBlizzardBags() then
    self:ListBags()
    return
  end
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
-- Backpack group's), and opens the new group dialog from the last tab. A bag slot's tab (Show Blizzard
-- Bags), left-clicked holding a bag, puts it in the slot; Shift-clicked, picks the slot's bag up.
---@param ctx Context
---@param id number
---@param button string
function bagProto:OnTabClicked(ctx, id, button)
  if self:ShowsBlizzardBags() then
    if button ~= "LeftButton" then
      return
    end
    local invID = C_Container.ContainerIDToInventoryID(id)
    if GetCursorInfo() == "item" then
      bagButton:PutInBag(invID)
    elseif IsModifiedClick("PICKUPITEM") then
      bagButton:PickupBag(invID)
    end
    return
  end
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

-- OnTabDragged swaps the bag in a bag slot's tab (Show Blizzard Bags): a bag dropped on it goes in, a
-- drag from it picks the slot's bag up, as Blizzard's bag slots do.
---@param ctx Context
---@param id number
function bagProto:OnTabDragged(ctx, id)
  local _ = ctx
  if not self:ShowsBlizzardBags() then
    return
  end
  local invID = C_Container.ContainerIDToInventoryID(id)
  if CursorHasItem() then
    bagButton:PutInBag(invID)
  else
    bagButton:PickupBag(invID)
  end
end

-- WatchKind lists the groups again when they change, and the bags when they do.
function bagProto:WatchKind()
  events:RegisterEvent("BAG_CONTAINER_UPDATE", function()
    if self:ShowsBlizzardBags() then
      self:RefreshTabs()
    end
  end)
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
