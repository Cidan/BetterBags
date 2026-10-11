-- flamegraph_spec.lua -- The in-game flame graph widget (frames/flamegraph.lua).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("debug/perf/format.lua")
LoadBetterBagsModule("frames/flamegraph.lua")

local perfFormat = addon:GetModule("PerfFormat")
local flameGraph = addon:GetModule("FlameGraph")

-- [all] 10ms: A 8ms (self 2) > B 6ms; C 2ms
local function sampleTree()
  return perfFormat:Decode({
    names = { "[all]", "Items.A", "Items.B", "[event] C" },
    nodes = {
      "0,1,0,0,0,0",
      "1,2,2000,1,8000,4096",
      "2,3,6000,2,3000,0",
      "1,4,2000,5,500,1024",
    },
  })
end

local function shownBars(fg)
  local shown = {}
  for _, bar in ipairs(fg.bars) do
    if bar:IsShown() then shown[#shown + 1] = bar end
  end
  return shown
end

local function barFor(fg, name)
  for _, bar in ipairs(fg.bars) do
    if bar:IsShown() and bar.rect.node.name == name then return bar end
  end
end

describe("FlameGraph", function()
  local fg

  before_each(function()
    fg = flameGraph:Create(UIParent)
    fg.canvas:SetSize(400, 180)
  end)

  it("shows a placeholder and no bars without a tree", function()
    fg:SetTree(nil)
    assert.are.equal(0, #shownBars(fg))
    assert.is_true(fg.empty:IsShown())
  end)

  it("draws one bar per node, sized and placed by its share of the total", function()
    fg:SetTree(sampleTree())
    assert.is_false(fg.empty:IsShown())
    assert.are.equal(4, #shownBars(fg))
    local b = barFor(fg, "Items.B")
    local point, relativeTo, relativePoint, x, y = b:GetPoint(1)
    assert.are.equal("TOPLEFT", point)
    assert.are.equal(fg.canvas, relativeTo)
    assert.are.equal("TOPLEFT", relativePoint)
    assert.are.equal(0, x)
    assert.are.equal(-2 * fg.ROW_HEIGHT, y)
    assert.are.equal(400 * 0.6 - 1, b:GetWidth())
    local c = barFor(fg, "[event] C")
    local _, _, _, cx = c:GetPoint(1)
    assert.are.equal(400 * 0.8, cx)
  end)

  it("labels bars wide enough to read", function()
    fg:SetTree(sampleTree())
    local b = barFor(fg, "Items.B")
    assert.is_true(b.label:IsShown())
    assert.are.equal("Items.B", b.label:GetText())
  end)

  it("finds the node under a point", function()
    fg:SetTree(sampleTree())
    assert.are.equal("[all]", fg:HitTest(10, 5).node.name)
    assert.are.equal("Items.A", fg:HitTest(10, fg.ROW_HEIGHT + 5).node.name)
    assert.are.equal("[event] C", fg:HitTest(350, fg.ROW_HEIGHT + 5).node.name)
    assert.are.equal("Items.B", fg:HitTest(100, 2 * fg.ROW_HEIGHT + 5).node.name)
    assert.is_nil(fg:HitTest(350, 2 * fg.ROW_HEIGHT + 5))
  end)

  it("zooms into a clicked node and back out on right click", function()
    local tree = sampleTree()
    fg:SetTree(tree)
    local a = perfFormat:Find(tree, { "Items.A" })
    fg.RectUnderCursor = function() return { node = a } end
    fg.canvas:GetScript("OnMouseUp")(fg.canvas, "LeftButton")
    assert.are.equal(a, fg.zoom)
    assert.are.equal(1, barFor(fg, "Items.A").rect.w)
    assert.is_nil(barFor(fg, "[event] C"))
    assert.is_truthy(fg.breadcrumb:GetText():find("Items.A", 1, true))
    fg.canvas:GetScript("OnMouseUp")(fg.canvas, "RightButton")
    assert.are.equal(tree.root, fg.zoom)
  end)

  it("resets the zoom from its button", function()
    local tree = sampleTree()
    fg:SetTree(tree)
    fg:Zoom(perfFormat:Find(tree, { "Items.A", "Items.B" }))
    fg.resetButton:GetScript("OnClick")()
    assert.are.equal(tree.root, fg.zoom)
  end)

  it("dims bars that do not match the search and totals the matches", function()
    fg:SetTree(sampleTree())
    fg:SetSearch("items.b")
    assert.are.equal(1, barFor(fg, "Items.B")._colorTexture.a)
    assert.is_true(barFor(fg, "[event] C")._colorTexture.a < 1)
    assert.is_truthy(fg.breadcrumb:GetText():find("6.00 ms", 1, true))
    fg:SetSearch("")
    assert.are.equal(1, barFor(fg, "[event] C")._colorTexture.a)
  end)

  it("lays out by allocations when switched to that metric", function()
    fg:SetTree(sampleTree())
    fg:SetMetric("alloc")
    assert.is_nil(barFor(fg, "Items.B"))
    assert.are.equal(0.8, barFor(fg, "Items.A").rect.w)
  end)

  it("scrolls deep trees a row at a time within bounds", function()
    fg.canvas:SetSize(400, fg.ROW_HEIGHT * 2)
    fg:SetTree(sampleTree())
    assert.is_nil(barFor(fg, "Items.B"))
    fg.canvas:GetScript("OnMouseWheel")(fg.canvas, -1)
    assert.are.equal(1, fg.depthOffset)
    assert.is_not_nil(barFor(fg, "Items.B"))
    fg.canvas:GetScript("OnMouseWheel")(fg.canvas, -1)
    assert.are.equal(1, fg.depthOffset)
    fg.canvas:GetScript("OnMouseWheel")(fg.canvas, 1)
    assert.are.equal(0, fg.depthOffset)
  end)

  it("describes a node in the tooltip", function()
    local tree = sampleTree()
    fg:SetTree(tree)
    fg:ShowTooltip({ node = perfFormat:Find(tree, { "Items.A" }) })
    local text = {}
    for _, l in ipairs(GameTooltip.doubleLines) do text[l.left] = l.right end
    assert.are.equal("8.00 ms (80.0%)", text["Total"])
    assert.are.equal("2.00 ms", text["Self"])
    assert.are.equal("1", text["Calls"])
    assert.are.equal("8.00 ms", text["Slowest call"])
    assert.are.equal("4.0 KB", text["Allocated"])
  end)
end)
