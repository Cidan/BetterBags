-- render_spec.lua -- The staged render pipeline (render/render.lua): plans of PRE, DEP and
-- SELF steps, constraints passed down, sizes passed up, invalidation bubbling to the root.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")

local render = addon:GetModule("Render")
local drawable = addon:GetModule("Drawable")

-- A frame clock: C_Timer.After callbacks wait until advance() runs them.
local pending
local function advance()
  local due = pending
  pending = {}
  for _, fn in ipairs(due) do
    fn()
  end
end

-- node builds a drawable that records every step it runs into log.
---@param name string
---@param log string[]
---@param opts? table
local function node(name, log, opts)
  opts = opts or {}
  local d = drawable:Create({})
  d.frame = CreateFrame("Frame")
  d.children = opts.children or {}
  function d:GetRenderPlan()
    local plan = { Plan = {} }
    if opts.pre ~= false then
      table.insert(plan.Plan, { step = render.PRE })
    end
    for _, child in ipairs(self.children) do
      table.insert(plan.Plan, { step = render.DEP, target = child })
    end
    table.insert(plan.Plan, { step = render.SELF })
    return plan
  end
  function d:PreRender(parentResult)
    table.insert(log, name .. ":pre")
    local width = parentResult and parentResult.Width or 100
    return { Width = width - (opts.inset or 0) }
  end
  function d:Render(parentResult, _, results)
    table.insert(log, name .. ":self")
    local height = opts.height or 0
    for _, child in ipairs(self.children) do
      height = height + results.Results[child].Height
    end
    return { Width = parentResult and parentResult.Width or 100, Height = height }
  end
  return d
end

describe("Render", function()
  local originalAfter

  before_each(function()
    render:Init()
    pending = {}
    originalAfter = _G.C_Timer.After
    _G.C_Timer.After = function(_, fn) table.insert(pending, fn) end
  end)

  after_each(function()
    _G.C_Timer.After = originalAfter
  end)

  describe("render plans", function()
    it("runs the steps in plan order, children before their parent's SELF", function()
      local log = {}
      local leafA = node("a", log)
      local leafB = node("b", log)
      local root = node("root", log, { children = { leafA, leafB } })

      render:NewRenderChain(root, {})

      assert.are.same({ "root:pre", "a:pre", "a:self", "b:pre", "b:self", "root:self" }, log)
    end)

    it("passes the parent's PRE result down and the children's results up", function()
      local log = {}
      local leaf = node("leaf", log, { height = 40, inset = 10 })
      local mid = node("mid", log, { children = { leaf }, height = 5, inset = 20 })
      local root = node("root", log, { children = { mid } })
      local seenWidth
      local originalRender = leaf.Render
      function leaf:Render(parentResult, options, results)
        seenWidth = parentResult.Width
        return originalRender(self, parentResult, options, results)
      end

      local result = render:NewRenderChain(root, {})

      -- root PRE hands down 100, mid PRE takes 20 off for its children.
      assert.are.equal(80, seenWidth)
      assert.are.equal(45, result.Height)
    end)

    it("returns the root's own result and every result by drawable", function()
      local log = {}
      local leaf = node("leaf", log, { height = 12 })
      local root = node("root", log, { children = { leaf } })

      local result, results = render:NewRenderChain(root, {})

      assert.are.equal(12, result.Height)
      assert.are.equal(12, results.Results[leaf].Height)
      assert.are.equal(result, results.Results[root])
    end)

    it("passes the options to every step", function()
      local seen = {}
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = render.PRE }, { step = render.SELF } } } end
      function d:PreRender(_, options) table.insert(seen, options) return {} end
      function d:Render(_, options) table.insert(seen, options) return {} end
      local options = { OnlyRedraw = true }

      render:NewRenderChain(d, options)

      assert.are.equal(options, seen[1])
      assert.are.equal(options, seen[2])
    end)

    it("errors on a dependency step without a target", function()
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = render.DEP } } } end
      assert.has_error(function() render:NewRenderChain(d, {}) end)
    end)

    it("errors on an object that has no render plan", function()
      assert.has_error(function() render:NewRenderChain({}, {}) end)
    end)

    it("errors on an unknown step", function()
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = "RENDER_BOGUS" } } } end
      assert.has_error(function() render:NewRenderChain(d, {}) end)
    end)

    it("links every rendered child to the parent that rendered it", function()
      local log = {}
      local leaf = node("leaf", log)
      local mid = node("mid", log, { children = { leaf } })
      local root = node("root", log, { children = { mid } })

      render:NewRenderChain(root, {})

      assert.are.equal(mid, leaf.renderParent)
      assert.are.equal(root, mid.renderParent)
      assert.is_nil(root.renderParent)
      assert.are.equal(root, render:GetRoot(leaf))
    end)

    it("relinks a child that moved to another parent", function()
      local log = {}
      local leaf = node("leaf", log)
      local first = node("first", log, { children = { leaf } })
      local second = node("second", log, { children = { leaf } })
      render:NewRenderChain(first, {})
      render:NewRenderChain(second, {})
      assert.are.equal(second, leaf.renderParent)
    end)

    it("detaches a drawable from its parent", function()
      local log = {}
      local leaf = node("leaf", log)
      local root = node("root", log, { children = { leaf } })
      render:NewRenderChain(root, {})

      render:Detach(leaf)

      assert.is_nil(leaf.renderParent)
      assert.are.equal(leaf, render:GetRoot(leaf))
    end)

    it("re-renders a nested render root with the constraints its parent last gave it", function()
      local log = {}
      local seen = {}
      local leaf = node("leaf", log)
      local inner = node("inner", log, { children = { leaf } })
      local originalPre = inner.PreRender
      function inner:PreRender(parentResult, ...)
        table.insert(seen, parentResult and parentResult.Width or false)
        return originalPre(self, parentResult, ...)
      end
      local outer = node("outer", log, { children = { inner }, inset = 0 })
      function outer:PreRender() return { Width = 300 } end
      render:NewRenderChain(outer, {})
      inner.renderRoot = true

      render:Invalidate(leaf)
      advance()

      assert.are.same({ 300, 300 }, seen)
    end)

    it("takes explicit constraints for a chain", function()
      local seen
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function d:Render(parentResult) seen = parentResult return {} end
      local constraints = { Width = 42 }
      render:NewRenderChain(d, {}, constraints)
      assert.are.equal(constraints, seen)
    end)

    it("errors on a parent link cycle instead of hanging", function()
      local a = drawable:Create({})
      local b = drawable:Create({})
      a.renderParent = b
      b.renderParent = a
      assert.has_error(function() render:GetRoot(a) end)
    end)

    it("treats a render root as the top of invalidation even when it has a parent", function()
      local log = {}
      local leaf = node("leaf", log)
      local inner = node("inner", log, { children = { leaf } })
      local outer = node("outer", log, { children = { inner } })
      render:NewRenderChain(outer, {})
      inner.renderRoot = true

      assert.are.equal(inner, render:GetRoot(leaf))
    end)
  end)

  describe("invalidation", function()
    it("renders the root once on the next frame, however many of its nodes were invalidated", function()
      local log = {}
      local leafA = node("a", log)
      local leafB = node("b", log)
      local root = node("root", log, { children = { leafA, leafB } })
      render:NewRenderChain(root, {})
      for k in pairs(log) do log[k] = nil end

      render:Invalidate(leafA)
      render:Invalidate(leafB)
      render:Invalidate(root)
      assert.are.same({}, log)
      assert.are.equal(1, #pending)

      advance()

      assert.are.same({ "root:pre", "a:pre", "a:self", "b:pre", "b:self", "root:self" }, log)
      assert.are.equal(0, #pending)
    end)

    it("renders every invalidated root in the same frame", function()
      local logA, logB = {}, {}
      local rootA = node("A", logA)
      local rootB = node("B", logB)

      render:Invalidate(rootA)
      render:Invalidate(rootB)
      advance()

      assert.are.same({ "A:pre", "A:self" }, logA)
      assert.are.same({ "B:pre", "B:self" }, logB)
    end)

    it("renders now with Flush", function()
      local log = {}
      local root = node("root", log)
      render:Invalidate(root)

      render:Flush()

      assert.are.same({ "root:pre", "root:self" }, log)
      advance()
      assert.are.same({ "root:pre", "root:self" }, log)
    end)

    it("passes the invalidation options to the render", function()
      local seen
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function d:Render(_, options) seen = options return {} end

      render:Invalidate(d)
      advance()

      assert.is_true(seen.Invalidated)
    end)

    it("skips a root that asks not to render (hidden window)", function()
      local log = {}
      local root = node("root", log)
      function root:ShouldRender() return false end

      render:Invalidate(root)
      advance()

      assert.are.same({}, log)
    end)

    it("renders again after a chain that invalidated its own root", function()
      local log = {}
      local root = node("root", log)
      local count = 0
      local originalRender = root.Render
      function root:Render(...)
        count = count + 1
        if count == 1 then
          render:Invalidate(self)
        end
        return originalRender(self, ...)
      end

      render:NewRenderChain(root, {})
      assert.are.equal(1, count)
      advance()

      assert.are.equal(2, count)
    end)

    it("defers a chain started for a root that is already rendering", function()
      local log = {}
      local root = node("root", log)
      local count = 0
      local nested
      local originalRender = root.Render
      function root:Render(...)
        count = count + 1
        if count == 1 then
          nested = render:NewRenderChain(self, {})
          assert.is_true(render:IsRendering(self))
        end
        return originalRender(self, ...)
      end

      render:NewRenderChain(root, {})

      assert.is_nil(nested)
      assert.are.equal(1, count)
      assert.is_false(render:IsRendering(root))
      advance()
      assert.are.equal(2, count)
    end)

    it("reports a failing root and still renders the others", function()
      local reported
      local originalHandler = _G.geterrorhandler
      _G.geterrorhandler = function() return function(err) reported = err end end
      local log = {}
      local bad = drawable:Create({})
      function bad:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function bad:Render() error("boom") end
      local good = node("good", log)

      render:Invalidate(bad)
      render:Invalidate(good)
      advance()
      _G.geterrorhandler = originalHandler

      assert.is_not_nil(reported)
      assert.is_truthy(tostring(reported):find("boom"))
      assert.are.same({ "good:pre", "good:self" }, log)
      assert.is_false(render:IsRendering(bad))
    end)

    it("reports a root whose ShouldRender fails and still renders the others", function()
      local reported
      local originalHandler = _G.geterrorhandler
      _G.geterrorhandler = function() return function(err) reported = err end end
      local log = {}
      local bad = node("bad", log)
      function bad:ShouldRender() error("cannot tell") end
      local good = node("good", log)

      render:Invalidate(bad)
      render:Invalidate(good)
      advance()
      _G.geterrorhandler = originalHandler

      assert.is_truthy(tostring(reported):find("cannot tell"))
      assert.are.same({ "good:pre", "good:self" }, log)
    end)

    it("marks a root invalidated while it could not render, and clears the mark once it renders", function()
      local log = {}
      local root = node("root", log)
      local renderable = false
      function root:ShouldRender() return renderable end

      render:Invalidate(root)
      advance()
      assert.is_true(root.renderPending)

      renderable = true
      render:Invalidate(root)
      advance()
      assert.is_nil(root.renderPending)
      assert.are.same({ "root:pre", "root:self" }, log)
    end)

    it("defers a chain started for a node inside a tree that is rendering", function()
      local log = {}
      local leaf = node("leaf", log)
      local root = node("root", log, { children = { leaf } })
      render:NewRenderChain(root, {})
      for k in pairs(log) do log[k] = nil end
      local nested = "unset"
      local originalRender = leaf.Render
      local count = 0
      function leaf:Render(...)
        count = count + 1
        if count == 1 then
          nested = render:NewRenderChain(self, {})
        end
        return originalRender(self, ...)
      end

      render:NewRenderChain(root, {})

      assert.is_nil(nested)
      assert.are.same({ "root:pre", "leaf:pre", "leaf:self", "root:self" }, log)
      advance()
      assert.are.same({ "root:pre", "leaf:pre", "leaf:self", "root:self", "root:pre", "leaf:pre", "leaf:self", "root:self" }, log)
    end)

    it("renders a root another root invalidated during a flush, on the next frame", function()
      local logA, logB = {}, {}
      local rootB = node("B", logB)
      local rootA = node("A", logA)
      local originalRender = rootA.Render
      function rootA:Render(...)
        render:Invalidate(rootB)
        return originalRender(self, ...)
      end

      render:Invalidate(rootA)
      advance()
      assert.are.same({}, logB)
      assert.are.equal(1, #pending)
      advance()
      assert.are.same({ "B:pre", "B:self" }, logB)
    end)

    it("lets a pending frame pick up what a direct flush invalidated", function()
      local logA, logB = {}, {}
      local rootA = node("A", logA)
      local rootB = node("B", logB)
      local originalRender = rootA.Render
      function rootA:Render(...)
        render:Invalidate(rootB)
        return originalRender(self, ...)
      end
      render:Invalidate(rootA)

      render:Flush()

      assert.are.same({ "A:pre", "A:self" }, logA)
      assert.are.equal(1, #pending)
      advance()
      assert.are.same({ "B:pre", "B:self" }, logB)
      assert.are.same({ "A:pre", "A:self" }, logA)
    end)

    it("says whether a tree waits for the next frame", function()
      local log = {}
      local leaf = node("leaf", log)
      local root = node("root", log, { children = { leaf } })
      render:NewRenderChain(root, {})
      assert.is_false(render:IsDirty(leaf))
      render:Invalidate(leaf)
      assert.is_true(render:IsDirty(leaf))
      assert.is_true(render:IsDirty(root))
      advance()
      assert.is_false(render:IsDirty(root))
    end)

    it("renders a tree now and drops the render it waited for", function()
      local log = {}
      local root = node("root", log)
      render:Invalidate(root)
      local seen
      local originalRender = root.Render
      function root:Render(parentResult, options, results)
        seen = options
        return originalRender(self, parentResult, options, results)
      end

      local result = render:RenderNow(root, { ctx = "the context" })

      assert.are.same({ "root:pre", "root:self" }, log)
      assert.are.equal("the context", seen.ctx)
      assert.is_true(seen.Invalidated)
      assert.is_not_nil(result)
      assert.is_false(render:IsDirty(root))
      advance()
      assert.are.same({ "root:pre", "root:self" }, log)
    end)

    it("renders a tree now even when it was not waiting", function()
      local log = {}
      local root = node("root", log)
      render:RenderNow(root, {})
      assert.are.same({ "root:pre", "root:self" }, log)
    end)

    it("gives every invalidated render a context", function()
      local seen
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function d:Render(_, options) seen = options.ctx return {} end

      render:Invalidate(d)
      advance()

      assert.is_not_nil(seen)
      assert.is_function(seen.Get)
    end)

    it("clears every rendering mark when a chain errors deep in the tree", function()
      local bad = drawable:Create({})
      function bad:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function bad:Render() error("deep") end
      local mid = node("mid", {}, { children = { bad } })
      local root = node("root", {}, { children = { mid } })

      assert.has_error(function() render:NewRenderChain(root, {}) end)
      assert.is_false(render:IsRendering(root))
      assert.is_false(render:IsRendering(mid))
      assert.is_false(render:IsRendering(bad))
    end)

    it("clears the rendering mark when a direct chain errors", function()
      local d = drawable:Create({})
      function d:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
      function d:Render() error("boom") end

      assert.has_error(function() render:NewRenderChain(d, {}) end)
      assert.is_false(render:IsRendering(d))
    end)
  end)
end)

describe("Drawable", function()
  before_each(function()
    render:Init()
  end)

  it("looks methods up through its prototype, with the drawable defaults behind it", function()
    local proto = drawable:Extend({ Hello = function() return "hi" end }, "SpecDrawableFrame")
    local d = drawable:Create(proto, { value = 1 })
    assert.are.equal("hi", d:Hello())
    assert.are.equal(1, d.value)
    assert.is_nil(rawget(d, "Hello"))
    assert.are.equal(drawable.proto.GetSortKey, d.GetSortKey)
    proto.Hello = function() return "wrapped" end
    assert.are.equal("wrapped", d:Hello())
  end)

  it("registers prototypes with the profiler", function()
    local perf = addon:GetModule("Perf")
    local registered = {}
    local original = perf.RegisterPrototype
    perf.RegisterPrototype = function(_, proto, name) registered[name] = proto end
    local proto = drawable:Extend({}, "SpecProfiledFrame")
    perf.RegisterPrototype = original
    assert.are.equal(proto, registered.SpecProfiledFrame)
  end)

  it("chains a bare prototype to the drawable defaults", function()
    local d = drawable:Create({})
    d.frame = CreateFrame("Frame")
    d:Hide()
    assert.is_false(d.frame:IsShown())
  end)

  it("forwards frame methods to its frame", function()
    local d = drawable:Create({})
    d.frame = CreateFrame("Frame")
    local parent = CreateFrame("Frame")
    d:SetParent(parent)
    d:SetSize(10, 20)
    d:SetPoint({ Point = "TOPLEFT", RelativeTo = parent, RelativePoint = "TOPLEFT", XOffset = 3, YOffset = -4 })
    d:Hide()

    assert.are.equal(parent, d.frame:GetParent())
    assert.are.equal(10, d.frame:GetWidth())
    assert.are.equal(20, d.frame:GetHeight())
    local point, relativeTo, relativePoint, x, y = d.frame:GetPoint(1)
    assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 3, -4 }, { point, relativeTo, relativePoint, x, y })
    assert.is_false(d.frame:IsShown())
    assert.are.equal(d.frame, d:GetFrame())
  end)

  it("forwards the rest of the frame calls", function()
    local d = drawable:Create({})
    d.frame = CreateFrame("Frame")
    d:SetPoint({ Point = "TOPLEFT" })
    d:SetWidth(7)
    d:SetHeight(9)
    d:Hide()
    d:Show()
    d:ClearAllPoints()
    assert.are.equal(7, d.frame:GetWidth())
    assert.are.equal(9, d.frame:GetHeight())
    assert.is_true(d.frame:IsShown())
    assert.is_nil(d.frame:GetPoint(1))
    assert.is_true(d:IsVisible())
  end)

  it("errors when a plan, pre-render or render step is missing", function()
    local d = drawable:Create({})
    assert.has_error(function() d:GetRenderPlan() end)
    assert.has_error(function() d:PreRender() end)
    assert.has_error(function() d:Render() end)
  end)

  it("invalidates itself through the render module", function()
    local invalidated
    local original = render.Invalidate
    render.Invalidate = function(_, d) invalidated = d end
    local d = drawable:Create({})
    d:Invalidate()
    render.Invalidate = original
    assert.are.equal(d, invalidated)
  end)

  it("keeps its sort key", function()
    local d = drawable:Create({})
    assert.are.equal(1, d:GetSortKey())
    d:SetSortKey(5)
    assert.are.equal(5, d:GetSortKey())
  end)

  it("wraps a frame laid out by its own code, sized by a function", function()
    local frame = CreateFrame("Frame")
    local given = {}
    local d = drawable:FromFrame(frame, function(parentResult, options)
      table.insert(given, { parentResult, options })
      return 120, 40
    end)
    assert.are.equal(frame, d.frame)
    local result = render:NewRenderChain(d, { ctx = "the context" }, { Width = 300 })
    assert.are.same({ 120, 40 }, { result.Width, result.Height })
    assert.are.equal(300, given[1][1].Width)
    assert.are.equal("the context", given[1][2].ctx)
    local perf = addon:GetModule("Perf")
    local name
    for _, entry in ipairs(perf.prototypes) do
      if entry.tbl == getmetatable(d).__index then name = entry.name end
    end
    assert.are.equal("FrameDrawable", name)
  end)
end)
