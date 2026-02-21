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
local groups = addon:NewModule('Groups')

function groups:OnInitialize()
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

-- DeleteGroup deletes a group and moves its categories back to Backpack.
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
  database:DeleteGroup(kind, groupID)
  debug:Log("groups", "Deleted group: %s (ID: %d)", groupName, groupID)
  events:SendMessage(ctx, 'groups/Deleted', groupID, groupName, kind)
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

-- GetDefaultBankGroup returns the default Bank group.
---@return Group?
function groups:GetDefaultBankGroup()
  local charBankType = Enum.BankType and Enum.BankType.Character or 1
  for _, group in pairs(database:GetAllGroups(const.BAG_KIND.BANK)) do
    if group.isDefault and group.bankType == charBankType then
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
function groups:AssignCategoryToGroup(ctx, kind, categoryName, groupID)
  -- If assigning to a default group, just remove the explicit assignment
  if self:IsDefaultGroup(kind, groupID) then
    self:RemoveCategoryFromGroup(ctx, kind, categoryName)
    return
  end

  local group = database:GetGroup(kind, groupID)
  if not group then
    debug:Log("groups", "Cannot assign to non-existent group: %d", groupID)
    return
  end

  database:SetCategoryGroup(kind, categoryName, groupID)
  debug:Log("groups", "Assigned category '%s' to group '%s' (ID: %d)", categoryName, group.name, groupID)
  events:SendMessage(ctx, 'groups/CategoryAssigned', categoryName, groupID, kind)
end

-- RemoveCategoryFromGroup removes a category's group assignment (moves it to Backpack).
---@param ctx Context
---@param kind BagKind
---@param categoryName string
function groups:RemoveCategoryFromGroup(ctx, kind, categoryName)
  local previousGroup = database:GetCategoryGroup(kind, categoryName)
  database:RemoveCategoryFromGroup(kind, categoryName)
  if previousGroup then
    debug:Log("groups", "Removed category '%s' from group (ID: %d)", categoryName, previousGroup)
    events:SendMessage(ctx, 'groups/CategoryRemoved', categoryName, previousGroup, kind)
  end
end

-- GetGroupForCategory returns the group ID for a category.
-- Returns nil if the category has no explicit assignment (belongs to Backpack).
---@param kind BagKind
---@param categoryName string
---@return number? The group ID, or nil if unassigned (belongs to default)
function groups:GetGroupForCategory(kind, categoryName)
  return database:GetCategoryGroup(kind, categoryName)
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
---@return boolean
function groups:CategoryBelongsToGroup(kind, categoryName, groupID)
  local assignedGroup = database:GetCategoryGroup(kind, categoryName)
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
  local group = database:GetGroup(groupID)
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
  local groupID = database:GetCategoryGroup(categoryName)
  if groupID then
    database:RemoveCategoryFromGroup(categoryName)
    debug:Log("groups", "Cleaned up deleted category '%s' from group ID: %d", categoryName, groupID)
  end
end

groups:Enable()
