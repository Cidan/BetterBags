local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Trees: AceModule
local trees = addon:GetModule('Trees')

---@class (exact) IntervalTreeNode
---@field value number
---@field left? IntervalTreeNode
---@field right? IntervalTreeNode
---@field min number
---@field max number
---@field data? table<any, any>

---@class (exact) IntervalTree
---@field private root IntervalTreeNode
trees.IntervalTree = {}

-- Insert adds a new value to the tree. If the value already exists,
-- the data table for the value will be appended to with the data
-- provided.
---@param value number
---@param data table<any, any>
function trees.IntervalTree:Insert(value, data)
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
  -- Bubble up min/max after insertion.
  self:RecalculateMinMax(node)
end

---@private
---@param node IntervalTreeNode
function trees.IntervalTree:RecalculateMinMax(node)
  node.min = node.value
  node.max = node.value
  if node.left then
    node.min = math.min(node.min, node.left.min)
    node.max = math.max(node.max, node.left.max)
  end
  if node.right then
    node.min = math.min(node.min, node.right.min)
    node.max = math.max(node.max, node.right.max)
  end
end

---@private
---@param startNode IntervalTreeNode
function trees.IntervalTree:RecalculateMinMaxPathToRoot(startNode)
  local node = startNode
  while node do
    self:RecalculateMinMax(node)
    node = self:FindParent(node)
  end
end

---@private
---@param node IntervalTreeNode
---@param result IntervalTreeNode[]
function trees.IntervalTree:CollectSubtree(node, result)
  if not node then return end
  table.insert(result, node)
  self:CollectSubtree(node.left, result)
  self:CollectSubtree(node.right, result)
end

-- LessThan will return a list of all nodes with values less than the
-- provided value.
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
  if not node then return end
  if node.min >= value then
    return
  end
  if node.max < value then
    self:CollectSubtree(node, result)
    return
  end
  if node.value < value then
    table.insert(result, node)
  end
  self:LessThanRecursive(node.left, value, result)
  self:LessThanRecursive(node.right, value, result)
end

-- LessThanEqual will return a list of all nodes with values less than
-- or equal to the provided value.
---@param value number
---@return IntervalTreeNode[]
function trees.IntervalTree:LessThanEqual(value)
  ---@type IntervalTreeNode[]
  local result = {}
  self:LessThanEqualRecursive(self.root, value, result)
  return result
end

---@private
---@param node IntervalTreeNode
---@param value number
---@param result IntervalTreeNode[]
function trees.IntervalTree:LessThanEqualRecursive(node, value, result)
  if not node then return end
  if node.min > value then
    return
  end
  if node.max <= value then
    self:CollectSubtree(node, result)
    return
  end
  if node.value <= value then
    table.insert(result, node)
  end
  self:LessThanEqualRecursive(node.left, value, result)
  self:LessThanEqualRecursive(node.right, value, result)
end

-- GreaterThan will return a list of all nodes with values greater than
-- the provided value.
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
  if not node then return end
  if node.max <= value then
    return
  end
  if node.min > value then
    self:CollectSubtree(node, result)
    return
  end
  if node.value > value then
    table.insert(result, node)
  end
  self:GreaterThanRecursive(node.left, value, result)
  self:GreaterThanRecursive(node.right, value, result)
end

-- GreaterThanEqual will return a list of all nodes with values greater
-- than or equal to the provided value.
---@param value number
---@return IntervalTreeNode[]
function trees.IntervalTree:GreaterThanEqual(value)
  ---@type IntervalTreeNode[]
  local result = {}
  self:GreaterThanEqualRecursive(self.root, value, result)
  return result
end

---@private
---@param node IntervalTreeNode
---@param value number
---@param result IntervalTreeNode[]
function trees.IntervalTree:GreaterThanEqualRecursive(node, value, result)
  if not node then return end
  if node.max < value then
    return
  end
  if node.min >= value then
    self:CollectSubtree(node, result)
    return
  end
  if node.value >= value then
    table.insert(result, node)
  end
  self:GreaterThanEqualRecursive(node.left, value, result)
  self:GreaterThanEqualRecursive(node.right, value, result)
end

-- ExactMatch will return the node with the exact matching value, or nil
-- if no such node exists.
---@param value number
---@return IntervalTreeNode?
function trees.IntervalTree:ExactMatch(value)
  return self:ExactMatchRecursive(self.root, value)
end

---@private
---@param node IntervalTreeNode
---@param value number
---@return IntervalTreeNode?
function trees.IntervalTree:ExactMatchRecursive(node, value)
  if node then
    if node.value == value then
      return node
    elseif value < node.value then
      return self:ExactMatchRecursive(node.left, value)
    else
      return self:ExactMatchRecursive(node.right, value)
    end
  end
  return nil
end

-- RemoveData will remove the metadata for a given value and key.
-- If the metadata table is empty after removing the key, the node
-- will be removed from the tree.
---@param value number The node value to remove metadata from.
---@param key any The key to remove from the metadata table.
function trees.IntervalTree:RemoveData(value, key)
  local node = self:ExactMatch(value)
  if node then
    node.data[key] = nil
    if next(node.data) == nil then
      self:RemoveNode(node)
    end
  end
end

---@private
---@param node IntervalTreeNode
function trees.IntervalTree:RemoveNode(node)
  local parent = self:FindParent(node)

  -- Leaf node: unlink directly.
  if not node.left and not node.right then
    if not parent then
      self.root = nil
    elseif parent.left == node then
      parent.left = nil
    else
      parent.right = nil
    end
    if parent then
      self:RecalculateMinMaxPathToRoot(parent)
    end
    return
  end

  -- Node with only right child.
  if not node.left then
    if not parent then
      self.root = node.right
    elseif parent.left == node then
      parent.left = node.right
    else
      parent.right = node.right
    end
    if parent then
      self:RecalculateMinMaxPathToRoot(parent)
    else
      self:RecalculateMinMaxPathToRoot(self.root)
    end
    return
  end

  -- Node with only left child.
  if not node.right then
    if not parent then
      self.root = node.left
    elseif parent.left == node then
      parent.left = node.left
    else
      parent.right = node.left
    end
    if parent then
      self:RecalculateMinMaxPathToRoot(parent)
    else
      self:RecalculateMinMaxPathToRoot(self.root)
    end
    return
  end

  -- Node with two children: replace with inorder predecessor.
  local predecessor = node.left
  local predParent = node
  while predecessor.right do
    predParent = predecessor
    predecessor = predecessor.right
  end

  node.value = predecessor.value
  node.data = predecessor.data

  if predParent == node then
    predParent.left = predecessor.left
    self:RecalculateMinMaxPathToRoot(node)
  else
    predParent.right = predecessor.left
    self:RecalculateMinMaxPathToRoot(predParent)
  end
end

---@private
---@param node IntervalTreeNode
---@return IntervalTreeNode?
function trees.IntervalTree:FindParent(node)
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
