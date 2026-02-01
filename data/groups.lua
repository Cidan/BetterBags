local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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
---@param name string
---@return Group
function groups:CreateGroup(ctx, name)
  local newID = database:CreateGroup(name)
  local group = database:GetGroup(newID)
  debug:Log("groups", "Created group: %s (ID: %d)", name, newID)
  events:SendMessage(ctx, 'groups/Created', group)
  return group
end

-- DeleteGroup deletes a group and moves its categories back to Backpack.
---@param ctx Context
---@param groupID number
function groups:DeleteGroup(ctx, groupID)
  -- Don't allow deleting the default Backpack group
  if groupID == 1 then
    debug:Log("groups", "Cannot delete default Backpack group")
    return
  end

  local group = database:GetGroup(groupID)
  if not group then
    debug:Log("groups", "Group not found: %d", groupID)
    return
  end

  local groupName = group.name
  database:DeleteGroup(groupID)
  debug:Log("groups", "Deleted group: %s (ID: %d)", groupName, groupID)
  events:SendMessage(ctx, 'groups/Deleted', groupID, groupName)
end

-- RenameGroup renames a group.
---@param ctx Context
---@param groupID number
---@param name string
function groups:RenameGroup(ctx, groupID, name)
  local group = database:GetGroup(groupID)
  if not group then
    debug:Log("groups", "Group not found: %d", groupID)
    return
  end

  local oldName = group.name
  database:RenameGroup(groupID, name)
  debug:Log("groups", "Renamed group: %s -> %s (ID: %d)", oldName, name, groupID)
  events:SendMessage(ctx, 'groups/Changed', groupID, name, oldName)
end

-- GetGroup returns a group by its ID.
---@param groupID number
---@return Group?
function groups:GetGroup(groupID)
  return database:GetGroup(groupID)
end

-- GetAllGroups returns all groups.
---@return table<number, Group>
function groups:GetAllGroups()
  return database:GetAllGroups()
end

-------
--- Category-Group Assignment
-------

-- AssignCategoryToGroup assigns a category to a group.
---@param ctx Context
---@param categoryName string
---@param groupID number
function groups:AssignCategoryToGroup(ctx, categoryName, groupID)
  -- If assigning to Backpack (ID 1), just remove the explicit assignment
  if groupID == 1 then
    self:RemoveCategoryFromGroup(ctx, categoryName)
    return
  end

  local group = database:GetGroup(groupID)
  if not group then
    debug:Log("groups", "Cannot assign to non-existent group: %d", groupID)
    return
  end

  database:SetCategoryGroup(categoryName, groupID)
  debug:Log("groups", "Assigned category '%s' to group '%s' (ID: %d)", categoryName, group.name, groupID)
  events:SendMessage(ctx, 'groups/CategoryAssigned', categoryName, groupID)
end

-- RemoveCategoryFromGroup removes a category's group assignment (moves it to Backpack).
---@param ctx Context
---@param categoryName string
function groups:RemoveCategoryFromGroup(ctx, categoryName)
  local previousGroup = database:GetCategoryGroup(categoryName)
  database:RemoveCategoryFromGroup(categoryName)
  if previousGroup then
    debug:Log("groups", "Removed category '%s' from group (ID: %d)", categoryName, previousGroup)
    events:SendMessage(ctx, 'groups/CategoryRemoved', categoryName, previousGroup)
  end
end

-- GetGroupForCategory returns the group ID for a category.
-- Returns nil if the category has no explicit assignment (belongs to Backpack).
---@param categoryName string
---@return number? The group ID, or nil if unassigned (belongs to Backpack)
function groups:GetGroupForCategory(categoryName)
  return database:GetCategoryGroup(categoryName)
end

-- GetCategoriesInGroup returns all categories explicitly assigned to a group.
---@param groupID number
---@return table<string, boolean>
function groups:GetCategoriesInGroup(groupID)
  return database:GetGroupCategories(groupID)
end

-- CategoryBelongsToGroup checks if a category belongs to a specific group.
-- Categories without explicit assignment belong to Backpack (ID 1).
---@param categoryName string
---@param groupID number
---@return boolean
function groups:CategoryBelongsToGroup(categoryName, groupID)
  local assignedGroup = database:GetCategoryGroup(categoryName)
  if groupID == 1 then
    -- Backpack group includes all categories without explicit assignment
    return assignedGroup == nil
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
