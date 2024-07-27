local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Trees: AceModule
local trees = addon:GetModule('Trees')

---@class IntervalTreeNode
---@field value number
---@field left? IntervalTreeNode
---@field right? IntervalTreeNode
---@field min number
---@field max number
---@field data? table<any, any>

---@class IntervalTree
---@field root IntervalTreeNode
trees.IntervalTree = {}

---@param value number
---@param data table<any, any>
function trees.IntervalTree:Insert(value, data)
  -- Insert a new value into the tree
  if not self.root then
    self.root = { value = value, left = nil, right = nil, min = value, max = value, data = data }
  else
    self:InsertRecursive(self.root, value, data)
  end
end

---@private
---@param node IntervalTreeNode
---@param value number
---@param data table<any, any>
function trees.IntervalTree:InsertRecursive(node, value, data)
  -- Recursively insert a new value into the tree
  if value < node.value then
    if not node.left then
      node.left = { value = value, left = nil, right = nil, min = value, max = value, data = data }
    else
      self:InsertRecursive(node.left, value, data)
    end
  elseif value > node.value then
    if not node.right then
      node.right = { value = value, left = nil, right = nil, min = value, max = value, data = data }
    else
      self:InsertRecursive(node.right, value, data)
    end
  else
    for k, v in pairs(data) do
      node.data[k] = v
    end
  end
end

---@param value number
---@return IntervalTreeNode[]
function trees.IntervalTree:LessThan(value)
  ---@type IntervalTreeNode[]
  local result = {}
  self:LessThanRecursive(self.root, value, result)
  return result
end

---@private
---@param node IntervalTreeNode
---@param value number
---@param result IntervalTreeNode[]
function trees.IntervalTree:LessThanRecursive(node, value, result)
  if node then
    if node.max < value then
      table.insert(result, node)
      self:LessThanRecursive(node.left, value, result)
      self:LessThanRecursive(node.right, value, result)
    elseif node.min < value then
      self:LessThanRecursive(node.left, value, result)
    end
  end
end

---@param value number
---@return IntervalTreeNode[]
function trees.IntervalTree:GreaterThan(value)
  ---@type IntervalTreeNode[]
  local result = {}
  self:GreaterThanRecursive(self.root, value, result)
  return result
end

---@private
---@param node IntervalTreeNode
---@param value number
---@param result IntervalTreeNode[]
function trees.IntervalTree:GreaterThanRecursive(node, value, result)
  if node then
    if node.min > value then
      table.insert(result, node)
      self:GreaterThanRecursive(node.left, value, result)
      self:GreaterThanRecursive(node.right, value, result)
    elseif node.max > value then
      self:GreaterThanRecursive(node.right, value, result)
    end
  end
end

---@param value number
---@return IntervalTreeNode?
function trees.IntervalTree:ExactMatch(value)
  -- Return the node with the exact matching value
  return self:ExactMatchRecursive(self.root, value)
end

---@private
---@param node IntervalTreeNode
---@param value number
---@return IntervalTreeNode?
function trees.IntervalTree:ExactMatchRecursive(node, value)
  -- Recursively search for the exact matching value
  if node then
    if node.value == value then
      return node
    elseif value < node.value then
      return self:ExactMatchRecursive(node.left, value)
    else
      return self:ExactMatchRecursive(node.right, value)
    end
  end
  return nil -- not found
end

---@param value number
---@param key any
function trees.IntervalTree:RemoveData(value, key)
  -- Remove metadata for a given value
  local node = self:ExactMatch(value)
  if node then
    node.data[key] = nil
    if next(node.data) == nil then
      -- Remove node if metadata table is empty
      self:RemoveNode(node)
    end
  end
end

---@param node IntervalTreeNode
function trees.IntervalTree:RemoveNode(node)
  -- Remove a node from the tree
  if node.left then
    self:RemoveNodeRecursive(node.left, node)
  elseif node.right then
    self:RemoveNodeRecursive(node.right, node)
  else
    -- Node has no children, remove it
    if node == self.root then
      self.root = nil
    else
      local parent = self:FindParent(node)
      if not parent then
        self.root = nil
      elseif parent.left == node then
        parent.left = nil
      else
        parent.right = nil
      end
    end
  end
end

---@private
---@param node IntervalTreeNode
---@param targetNode IntervalTreeNode
function trees.IntervalTree:RemoveNodeRecursive(node, targetNode)
  -- Recursively find the node to remove
  if node == targetNode then
    -- Node found, remove it
    if node.left then
      self:RemoveNodeRecursive(node.left, node)
    elseif node.right then
      self:RemoveNodeRecursive(node.right, node)
    else
      -- Node has no children, remove it
      local parent = self:FindParent(node)
      if not parent then
        self.root = nil
      elseif parent.left == node then
        parent.left = nil
      else
        parent.right = nil
      end
    end
  else
    if node.left then
      self:RemoveNodeRecursive(node.left, targetNode)
    end
    if node.right then
      self:RemoveNodeRecursive(node.right, targetNode)
    end
  end
end

---@param node IntervalTreeNode
---@return IntervalTreeNode?
function trees.IntervalTree:FindParent(node)
  -- Find the parent node of a given node
  if self.root == node then
    return nil
  end
  local parent = self.root
  while parent do
    if parent.left == node or parent.right == node then
      return parent
    end
    if node.value < parent.value then
      parent = parent.left
    else
      parent = parent.right
    end
  end
  return nil
end