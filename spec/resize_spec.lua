-- resize_spec.lua -- Unit tests for util/resize.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

StubBetterBagsModule("Constants")
StubBetterBagsModule("Localization")

-- Enhanced CreateFrame mock that records calls and stores scripts

local frameRegistry = {}

local function spyCreateFrame(frameType, name, parent)
  local scripts = {}
  local calls = {}
  local frame = {
    _type = frameType,
    _name = name,
    _parent = parent,
    _calls = calls,
    _scripts = scripts,
    SetScript = function(self, script, handler)
      scripts[script] = handler
      table.insert(calls, {method = "SetScript", args = {script}})
    end,
    Show = function() table.insert(calls, {method = "Show"}) end,
    Hide = function() table.insert(calls, {method = "Hide"}) end,
    RegisterEvent = function() end,
    UnregisterEvent = function() end,
    SetResizable = function(self, val)
      table.insert(calls, {method = "SetResizable", args = {val}})
    end,
    SetResizeBounds = function(self, minW, minH)
      table.insert(calls, {method = "SetResizeBounds", args = {minW, minH}})
    end,
    EnableMouse = function(self, val)
      table.insert(calls, {method = "EnableMouse", args = {val}})
    end,
    SetPoint = function(self, point)
      table.insert(calls, {method = "SetPoint", args = {point}})
    end,
    SetSize = function(self, w, h)
      table.insert(calls, {method = "SetSize", args = {w, h}})
    end,
    SetNormalTexture = function(self, tex)
      table.insert(calls, {method = "SetNormalTexture", args = {tex}})
    end,
    SetHighlightTexture = function(self, tex)
      table.insert(calls, {method = "SetHighlightTexture", args = {tex}})
    end,
    SetPushedTexture = function(self, tex)
      table.insert(calls, {method = "SetPushedTexture", args = {tex}})
    end,
    SetAlpha = function(self, alpha)
      table.insert(calls, {method = "SetAlpha", args = {alpha}})
    end,
    GetParent = function() return parent end,
    StartSizing = function(self, point)
      table.insert(calls, {method = "StartSizing", args = {point}})
    end,
    StopMovingOrSizing = function(self, point)
      table.insert(calls, {method = "StopMovingOrSizing", args = {point}})
    end,
  }
  table.insert(frameRegistry, frame)
  if name then _G[name] = frame end
  return frame
end

_G.CreateFrame = spyCreateFrame

LoadBetterBagsModule("util/resize.lua")
local resize = addon:GetModule("Resize")

describe("Resize", function()

  --- Create a mock parent frame that records calls
  local function mockParentFrame()
    local calls = {}
    return {
      _calls = calls,
      SetResizable = function(self, val)
        table.insert(calls, {method = "SetResizable", args = {val}})
      end,
      SetResizeBounds = function(self, minW, minH)
        table.insert(calls, {method = "SetResizeBounds", args = {minW, minH}})
      end,
      StartSizing = function(self, point)
        table.insert(calls, {method = "StartSizing", args = {point}})
      end,
      StopMovingOrSizing = function(self, point)
        table.insert(calls, {method = "StopMovingOrSizing", args = {point}})
      end,
    }
  end

  before_each(function()
    -- Clear frame registry for test isolation
    for i = #frameRegistry, 1, -1 do
      frameRegistry[i] = nil
    end
  end)

  describe("MakeResizable", function()

    it("returns a Button frame", function()
      local parent = mockParentFrame()
      local handle = resize:MakeResizable(parent, function() end)
      assert.is_not_nil(handle)
      assert.are.equal("Button", handle._type)
    end)

    it("calls SetResizable(true) on the parent frame", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      -- Verify SetResizable was called on parent
      local hasSetResizable = false
      for _, c in ipairs(parent._calls) do
        if c.method == "SetResizable" then
          assert.are.same({true}, c.args)
          hasSetResizable = true
        end
      end
      assert.is_true(hasSetResizable)
    end)

    it("calls SetResizeBounds(300, 300) on the parent frame", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local hasSetBounds = false
      for _, c in ipairs(parent._calls) do
        if c.method == "SetResizeBounds" then
          assert.are.same({300, 300}, c.args)
          hasSetBounds = true
        end
      end
      assert.is_true(hasSetBounds)
    end)

    it("creates handle at BOTTOMRIGHT with size 24x24", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local calls = handle._calls

      local setPointCall = nil
      local setSizeCall = nil
      for _, c in ipairs(calls) do
        if c.method == "SetPoint" then setPointCall = c end
        if c.method == "SetSize" then setSizeCall = c end
      end
      assert.is_not_nil(setPointCall)
      assert.are.same({"BOTTOMRIGHT"}, setPointCall.args)
      assert.are.same({24, 24}, setSizeCall.args)
    end)

    it("sets up resize handle textures", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local calls = handle._calls

      local hasNormalTex = false
      local hasHighlightTex = false
      local hasPushedTex = false
      for _, c in ipairs(calls) do
        if c.method == "SetNormalTexture" then hasNormalTex = true end
        if c.method == "SetHighlightTexture" then hasHighlightTex = true end
        if c.method == "SetPushedTexture" then hasPushedTex = true end
      end
      assert.is_true(hasNormalTex)
      assert.is_true(hasHighlightTex)
      assert.is_true(hasPushedTex)
    end)

    it("enables mouse on the resize handle", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local calls = handle._calls

      local hasEnableMouse = false
      for _, c in ipairs(calls) do
        if c.method == "EnableMouse" then
          assert.are.same({true}, c.args)
          hasEnableMouse = true
        end
      end
      assert.is_true(hasEnableMouse)
    end)

    it("starts with alpha 0 (hidden)", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local calls = handle._calls

      local setAlphaCalled = false
      for _, c in ipairs(calls) do
        if c.method == "SetAlpha" then
          setAlphaCalled = true
        end
      end
      assert.is_true(setAlphaCalled)
      -- Verify the initial SetAlpha(0) happened
      assert.are.same({0}, calls[#calls].args)
    end)

    -- ─── Script wiring ──────────────────────────────────────────────────────────

    it("wires OnEnter to set alpha to 1", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local scripts = handle._scripts

      assert.is_not_nil(scripts["OnEnter"])
      scripts["OnEnter"](handle)
      local setAlphaCalls = {}
      for _, c in ipairs(handle._calls) do
        if c.method == "SetAlpha" then table.insert(setAlphaCalls, c) end
      end
      assert.are.same({1}, setAlphaCalls[#setAlphaCalls].args)
    end)

    it("wires OnLeave to set alpha to 0", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local scripts = handle._scripts

      assert.is_not_nil(scripts["OnLeave"])
      scripts["OnLeave"](handle)
      local setAlphaCalls = {}
      for _, c in ipairs(handle._calls) do
        if c.method == "SetAlpha" then table.insert(setAlphaCalls, c) end
      end
      assert.are.same({0}, setAlphaCalls[#setAlphaCalls].args)
    end)

    it("wires OnMouseDown to start sizing on the parent", function()
      local parent = mockParentFrame()
      resize:MakeResizable(parent, function() end)
      local handle = frameRegistry[1]
      local scripts = handle._scripts

      assert.is_not_nil(scripts["OnMouseDown"])
      scripts["OnMouseDown"](handle)
      -- StartSizing is called on the parent frame (p:GetParent())
      local startSizingCalls = {}
      for _, c in ipairs(parent._calls) do
        if c.method == "StartSizing" then table.insert(startSizingCalls, c) end
      end
      assert.are.equal(1, #startSizingCalls)
      assert.are.same({"BOTTOMRIGHT"}, startSizingCalls[1].args)
    end)

    it("wires OnMouseUp to stop sizing on the parent and call onDone", function()
      local parent = mockParentFrame()
      local doneCalled = false
      local onDone = function() doneCalled = true end
      resize:MakeResizable(parent, onDone)
      local handle = frameRegistry[1]
      local scripts = handle._scripts

      assert.is_not_nil(scripts["OnMouseUp"])
      scripts["OnMouseUp"](handle)

      -- StopMovingOrSizing is called on the parent frame
      local stopCalls = {}
      for _, c in ipairs(parent._calls) do
        if c.method == "StopMovingOrSizing" then table.insert(stopCalls, c) end
      end
      assert.are.equal(1, #stopCalls)
      assert.are.same({"BOTTOMRIGHT"}, stopCalls[1].args)

      assert.is_true(doneCalled)
    end)
  end)
end)
