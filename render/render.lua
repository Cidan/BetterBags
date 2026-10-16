local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

-- Render runs the staged render plans of drawables (Moonlight's render pipeline). Every
-- drawable declares a plan of steps: RENDER_PRE works out what to hand its children (the
-- constraints, such as the width they may use), RENDER_DEP renders a child with that
-- result, and RENDER_SELF sizes and places the drawable from its children's results. A
-- chain started at a root renders the whole tree below it, top-down for constraints and
-- bottom-up for sizes.
--
-- A drawable that changes outside a chain invalidates itself: the invalidation walks the
-- parent links the last chain recorded up to the root, and the root renders once on the
-- next frame however many of its nodes were invalidated. Nothing in a render may yield: a
-- chain runs inside a protected call, which a coroutine cannot yield across in Lua 5.1.
---@class Render: AceModule
---@field private dirty table<Drawable, boolean>
---@field private dirtyOrder Drawable[]
---@field private active table<Drawable, table>
---@field private scheduled boolean
local render = addon:NewModule('Render')

render.PRE = "RENDER_PRE"
render.DEP = "RENDER_DEP"
render.SELF = "RENDER_SELF"

-- Parent links deeper than this are a cycle.
local MAX_DEPTH = 1000

---@alias RenderStepType "RENDER_PRE"|"RENDER_DEP"|"RENDER_SELF"

---@class RenderResult
---@field Width? number Down: the width a child may use (nil: its natural width). Up: the width it took.
---@field Height? number Down: the height a child must fill (nil: its natural height). Up: the height it took.
---@field MaxHeight? number Down: the most height a child may take before it scrolls.
---@field FullWidth? number Down: the full width, for children that span every column.
---@field Scrollable? boolean Up: the content is taller than the viewport it was given.

---@class RenderResults
---@field Results table<Drawable, RenderResult>

---@class RenderStep
---@field step RenderStepType
---@field target? Drawable

---@class RenderPlan
---@field Plan RenderStep[]

---@class RenderChainOptions
---@field OnlyRedraw? boolean Layout only: nothing a drawable shows changed.
---@field Invalidated? boolean The chain renders an invalidated root.
---@field ctx? Context

function render:Init()
  self.dirty = {}
  self.dirtyOrder = {}
  self.active = {}
  self.scheduled = false
end

---@param d Drawable
---@param parentResult? RenderResult
---@param options RenderChainOptions
---@param results RenderResults
---@param chain table The token marking the drawables this chain is rendering.
function render:execute(d, parentResult, options, results, chain)
  if type(d) ~= "table" or d.GetRenderPlan == nil then
    error("invalid rendering chain, there is no GetRenderPlan on an object in the chain")
  end
  self.active[d] = chain

  local plan = d:GetRenderPlan()
  if plan == nil or plan.Plan == nil then
    error("a drawable returned no render plan")
  end

  ---@type RenderResult?
  local preResult

  for _, step in ipairs(plan.Plan) do
    if step.step == render.PRE then
      preResult = d:PreRender(parentResult, options)
    elseif step.step == render.DEP then
      local target = step.target
      if target == nil then
        error("a render dep has no target -- did you set the target field in your render plan?")
      end
      target.renderParent = d
      target.renderParentResult = preResult
      self:execute(target, preResult, options, results, chain)
    elseif step.step == render.SELF then
      results.Results[d] = d:Render(parentResult, options, results)
    else
      error("unknown render step: " .. tostring(step.step))
    end
  end
  self.active[d] = nil
end

---@param err any
---@return any
local function withStack(err)
  if debugstack ~= nil then
    return tostring(err) .. "\n" .. debugstack(2)
  end
  return err
end

-- NewRenderChain renders d and everything below it, and returns d's result and the result
-- of every drawable in the chain. d is rendered with constraints when given, else with the
-- constraints its parent last gave it. A chain started for a drawable whose tree is already
-- rendering is deferred to the next frame and returns nil.
---@param d Drawable
---@param options? RenderChainOptions
---@param constraints? RenderResult
---@return RenderResult?, RenderResults?
function render:NewRenderChain(d, options, constraints)
  local root = self:GetRoot(d)
  if self.active[d] ~= nil or self.active[root] ~= nil then
    self:markDirty(root)
    return nil, nil
  end
  ---@type RenderResults
  local results = {
    Results = {}
  }
  if constraints == nil and d.renderParent ~= nil then
    constraints = d.renderParentResult
  end
  local chain = {}
  local ok, err = xpcall(function()
    self:execute(d, constraints, options or {}, results, chain)
  end, withStack)
  if not ok then
    for node, token in pairs(self.active) do
      if token == chain then
        self.active[node] = nil
      end
    end
    error(err, 0)
  end
  return results.Results[d], results
end

---@param d Drawable
---@return boolean
function render:IsRendering(d)
  return self.active[d] ~= nil
end

-- GetRoot returns the top of the tree d was last rendered in: the first drawable up its
-- parent links that has no parent or is marked as a render root.
---@param d Drawable
---@return Drawable
function render:GetRoot(d)
  local root = d
  local depth = 0
  while root.renderParent ~= nil and root.renderRoot ~= true do
    root = root.renderParent
    depth = depth + 1
    if depth > MAX_DEPTH then
      error("render parent links form a cycle")
    end
  end
  return root
end

-- Detach removes d from the tree it was last rendered in, so its invalidations stop
-- reaching that tree.
---@param d Drawable
function render:Detach(d)
  d.renderParent = nil
  d.renderParentResult = nil
end

---@private
---@param root Drawable
function render:markDirty(root)
  if not self.dirty[root] then
    self.dirty[root] = true
    table.insert(self.dirtyOrder, root)
  end
  if not self.scheduled then
    self.scheduled = true
    C_Timer.After(0, function()
      self.scheduled = false
      self:Flush()
    end)
  end
end

-- Invalidate marks the tree d belongs to for a render on the next frame.
---@param d Drawable
function render:Invalidate(d)
  self:markDirty(self:GetRoot(d))
end

---@private
---@param root Drawable
---@param ctx Context
function render:flushRoot(root, ctx)
  if root.ShouldRender ~= nil and not root:ShouldRender() then
    root.renderPending = true
    return
  end
  root.renderPending = nil
  self:NewRenderChain(root, { Invalidated = true, ctx = ctx })
end

-- Flush renders every invalidated root now. A root that fails is reported and does not stop
-- the others. A root whose ShouldRender returns false (a hidden window) is skipped and left
-- with renderPending set; its owner renders it when it can.
function render:Flush()
  local order = self.dirtyOrder
  self.dirtyOrder = {}
  self.dirty = {}
  local ctx = context:New('Render_Flush')
  for _, root in ipairs(order) do
    local ok, err = pcall(self.flushRoot, self, root, ctx)
    if not ok then
      geterrorhandler()(err)
    end
  end
end
