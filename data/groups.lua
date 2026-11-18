local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) Groups: AceModule
---@field private assignedSince table<BagKind, table<number, table|false>> For each group a category was assigned to, the
--- bag's data by tab (SlotInfo.tabs) when it was, false before the bag's data was first worked out (HiddenGroups).
local groups = addon:NewModule('Groups')

groups.assignedSince = {}

function groups:Init()
end

function groups:OnEnable()
  -- Listen for category deletion to cleanup group references
  events:RegisterMessage('categories/Deleted', function(_, ctx, categoryName)
    self:OnCategoryDeleted(ctx, categoryName)
  end)
end

-------
--- Group CRUD Operations
-------

-- CreateGroup creates a new group with the given name.
---@param ctx Context
---@param kind BagKind
---@param name string
---@param bankType? number
---@return Group
function groups:CreateGroup(ctx, kind, name, bankType)
  local newID = database:CreateGroup(kind, name, bankType)
  local group = database:GetGroup(kind, newID)
  debug:Log("groups", "Created group: %s (ID: %d)", name, newID)
  events:SendMessage(ctx, 'groups/Created', group)
  return group
end

-- DeleteGroup deletes a group and moves its categories back to Backpack. groups/Deleted says
-- whether the group was the one shown: the database has already made the default group active.
---@param ctx Context
---@param kind BagKind
---@param groupID number
function groups:DeleteGroup(ctx, kind, groupID)
  -- Don't allow deleting any default groups
  if self:IsDefaultGroup(kind, groupID) then
    debug:Log("groups", "Cannot delete a default group: %d", groupID)
    return
  end

  local group = database:GetGroup(kind, groupID)
  if not group then
    debug:Log("groups", "Group not found: %d", groupID)
    return
  end

  local groupName = group.name
  local wasActive = database:GetActiveGroup(kind) == groupID
  database:DeleteGroup(kind, groupID)
  debug:Log("groups", "Deleted group: %s (ID: %d)", groupName, groupID)
  events:SendMessage(ctx, 'groups/Deleted', groupID, groupName, kind, wasActive)
end

-- RenameGroup renames a group.
---@param ctx Context
---@param kind BagKind
---@param groupID number
---@param name string
function groups:RenameGroup(ctx, kind, groupID, name)
  local group = database:GetGroup(kind, groupID)
  if not group then
    debug:Log("groups", "Group not found: %d", groupID)
    return
  end

  local oldName = group.name
  database:RenameGroup(kind, groupID, name)
  debug:Log("groups", "Renamed group: %s -> %s (ID: %d)", oldName, name, groupID)
  events:SendMessage(ctx, 'groups/Changed', groupID, name, oldName, kind)
end

-- GetGroup returns a group by its ID.
---@param kind BagKind
---@param groupID number
---@return Group?
function groups:GetGroup(kind, groupID)
  return database:GetGroup(kind, groupID)
end

-- IsDefaultGroup returns whether the group ID belongs to a default system group.
---@param kind BagKind
---@param groupID number
---@return boolean
function groups:IsDefaultGroup(kind, groupID)
  if kind == const.BAG_KIND.BACKPACK and groupID == 1 then return true end
  local group = database:GetGroup(kind, groupID)
  return group and group.isDefault == true
end

-- GetDefaultBankGroup returns the default group of a bank type: the Bank's (the character bank, when none is given), or
-- the Warbank's.
---@param bankType? BankType
---@return Group?
function groups:GetDefaultBankGroup(bankType)
  bankType = bankType or (Enum.BankType and Enum.BankType.Character or 1)
  for _, group in pairs(database:GetAllGroups(const.BAG_KIND.BANK)) do
    if group.isDefault and group.bankType == bankType then
      return group
    end
  end
  return nil
end

-- GetAllGroups returns all groups.
---@param kind BagKind
---@return table<number, Group>
function groups:GetAllGroups(kind)
  return database:GetAllGroups(kind)
end

-------
--- Category-Group Assignment
-------

-- AssignCategoryToGroup assigns a category to a group.
---@param ctx Context
---@param kind BagKind
---@param categoryName string
---@param groupID number
---@param bankType? number
function groups:AssignCategoryToGroup(ctx, kind, categoryName, groupID, bankType)
  local group = database:GetGroup(kind, groupID)
  bankType = bankType or (group and group.bankType)

  -- If assigning to a default group, just remove the explicit assignment
  if self:IsDefaultGroup(kind, groupID) then
    self:RemoveCategoryFromGroup(ctx, kind, categoryName, bankType)
    return
  end

  if not group then
    debug:Log("groups", "Cannot assign to non-existent group: %d", groupID)
    return
  end

  database:SetCategoryGroup(kind, categoryName, groupID, bankType)
  local data = addon:GetModule('Items'):GetAllSlotInfo()[kind]
  self.assignedSince[kind] = self.assignedSince[kind] or {}
  self.assignedSince[kind][groupID] = data and data.tabs or false
  debug:Log("groups", "Assigned category '%s' to group '%s' (ID: %d)", categoryName, group.name, groupID)
  events:SendMessage(ctx, 'groups/CategoryAssigned', categoryName, groupID, kind)
end

-- RemoveCategoryFromGroup removes a category's group assignment (moves it to Backpack).
---@param ctx Context
---@param kind BagKind
---@param categoryName string
---@param bankType? number
function groups:RemoveCategoryFromGroup(ctx, kind, categoryName, bankType)
  local previousGroup = database:GetCategoryGroup(kind, categoryName, bankType)
  database:RemoveCategoryFromGroup(kind, categoryName, bankType)
  if previousGroup then
    debug:Log("groups", "Removed category '%s' from group (ID: %d)", categoryName, previousGroup)
    events:SendMessage(ctx, 'groups/CategoryRemoved', categoryName, previousGroup, kind)
  end
end

-- GetGroupForCategory returns the group ID for a category.
-- Returns nil if the category has no explicit assignment (belongs to Backpack).
---@param kind BagKind
---@param categoryName string
---@param bankType? number
---@return number? The group ID, or nil if unassigned (belongs to default)
function groups:GetGroupForCategory(kind, categoryName, bankType)
  return database:GetCategoryGroup(kind, categoryName, bankType)
end

-- GetCategoriesInGroup returns all categories explicitly assigned to a group.
---@param kind BagKind
---@param groupID number
---@return table<string, boolean>
function groups:GetCategoriesInGroup(kind, groupID)
  return database:GetGroupCategories(kind, groupID)
end

-- CategoryBelongsToGroup checks if a category belongs to a specific group.
-- Categories without explicit assignment belong to Backpack (ID 1).
---@param kind BagKind
---@param categoryName string
---@param groupID number
---@param bankType? number
---@return boolean
function groups:CategoryBelongsToGroup(kind, categoryName, groupID, bankType)
  if addon.isRetail and kind == const.BAG_KIND.BANK and bankType == nil then
    local group = database:GetGroup(kind, groupID)
    bankType = group and group.bankType
  end
  local assignedGroup = database:GetCategoryGroup(kind, categoryName, bankType)
  if self:IsDefaultGroup(kind, groupID) then
    -- Default groups include all categories not explicitly assigned to another group of the same kind
    if assignedGroup == nil then return true end
    if assignedGroup == groupID then return true end
    return false
  else
    -- Other groups only include explicitly assigned categories
    return assignedGroup == groupID
  end
end

-------
--- Empty Groups
-------

-- HiddenGroups returns the groups of a bag whose tabs Hide Empty Groups leaves out (groups.md §3): with it on, every group
-- but the bag's default ones and the one shown (shownID) with nothing in tabs, the bag's data by tab
-- (items:Phase10_PartitionIntoTabs: a tab's items counted, those a category hides in the bag left out), unless a category
-- was assigned to it since tabs was worked out (its items go there at the next recalculation). None before the bag's data
-- was first worked out (tabs nil).
---@param kind BagKind
---@param tabs? table<number, {totalItems: number}>
---@param shownID number
---@return table<number, boolean>
function groups:HiddenGroups(kind, tabs, shownID)
  local hidden = {}
  if tabs == nil or not database:GetHideEmptyGroups(kind) then
    return hidden
  end
  local assigned = self.assignedSince[kind] or {}
  for id in pairs(database:GetAllGroups(kind)) do
    local tab = tabs[id]
    if id ~= shownID and not self:IsDefaultGroup(kind, id) and (tab == nil or tab.totalItems == 0)
      and assigned[id] ~= tabs then
      hidden[id] = true
    end
  end
  return hidden
end

-- SameGroups says whether two sets of groups (HiddenGroups) name the same groups.
---@param a table<number, boolean>
---@param b table<number, boolean>
---@return boolean
function groups:SameGroups(a, b)
  for id in pairs(a) do
    if not b[id] then
      return false
    end
  end
  for id in pairs(b) do
    if not a[id] then
      return false
    end
  end
  return true
end

-------
--- Active Group
-------

-- GetActiveGroup returns the currently active group ID for a bag kind.
---@param kind BagKind
---@return number
function groups:GetActiveGroup(kind)
  return database:GetActiveGroup(kind)
end

-- SetActiveGroup sets the active group for a bag kind.
---@param ctx Context
---@param kind BagKind
---@param groupID number
function groups:SetActiveGroup(ctx, kind, groupID)
  local group = database:GetGroup(kind, groupID)
  if not group then
    debug:Log("groups", "Cannot set active group to non-existent group: %d", groupID)
    return
  end

  database:SetActiveGroup(kind, groupID)
  debug:Log("groups", "Set active group for kind %d to '%s' (ID: %d)", kind, group.name, groupID)
  events:SendMessage(ctx, 'groups/ActiveChanged', kind, groupID)
end

-------
--- Cleanup
-------

-- OnCategoryDeleted cleans up group references when a category is deleted.
---@param categoryName string
function groups:OnCategoryDeleted(_, categoryName)
  for _, kind in pairs(const.BAG_KIND) do
    if addon.isRetail and kind == const.BAG_KIND.BANK then
      local charBankType = Enum.BankType and Enum.BankType.Character or 0
      local accountBankType = Enum.BankType and Enum.BankType.Account or 2
      for _, bankType in ipairs({ charBankType, accountBankType }) do
        local groupID = database:GetCategoryGroup(kind, categoryName, bankType)
        if groupID then
          database:RemoveCategoryFromGroup(kind, categoryName, bankType)
          debug:Log("groups", "Cleaned up deleted category '%s' from group ID: %d in bankType: %d", categoryName, groupID, bankType)
        end
      end
    else
      local groupID = database:GetCategoryGroup(kind, categoryName)
      if groupID then
        database:RemoveCategoryFromGroup(kind, categoryName)
        debug:Log("groups", "Cleaned up deleted category '%s' from group ID: %d in bag kind: %s", categoryName, groupID, kind)
      end
    end
  end
end

groups:Enable()
