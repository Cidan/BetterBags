-- tracechart_spec.lua -- The in-game timeline of a call trace (frames/tracechart.lua): calls
-- drawn on a time axis, one row per call depth.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("debug/perf/format.lua")
LoadBetterBagsModule("frames/flamegraph.lua")
LoadBetterBagsModule("frames/tracechart.lua")

local perf = addon:GetModule("Perf")
local perfFormat = addon:GetModule("PerfFormat")
local traceChart = addon:GetModule("TraceChart")

local A = addon:GetModule("PerfChartA", true) or addon:NewModule("PerfChartA")

local now = 0

-- [0,8] TOuter > [1,6] TInner; then [20,22] TOuter > (nothing)
local function sampleTrace()
  now = 0
  perf:Init()
  perf:SetClock(function() return now end)
  function A:TOuter(withInner)
    now = now + 1
    if withInner then self:TInner(9) end
    now = now + (withInner and 2 or 1)
  end
  function A:TInner(n)
    now = now + 5
    return n * 2
  end
  perf:Start({ modules = { "PerfChartA" }, prototypes = {}, includeRoot = false, calibrate = false, trace = true, traceArgs = true })
  A:TOuter(true)
  perf:_OnFrame()
  now = 20
  A:TOuter(false)
  perf:_OnFrame()
  return perfFormat:OpenTrace(perf:Stop())
end

local function shownBars(chart)
  local shown = {}
  for _, bar in ipairs(chart.bars) do
    if bar:IsShown() then shown[#shown + 1] = bar end
  end
  return shown
end

local function barFor(chart, name)
  for _, bar in ipairs(chart.bars) do
    if bar:IsShown() and bar.rect.slice.name == name then return bar end
  end
end

describe("TraceChart", function()
  local chart

  before_each(function()
    chart = traceChart:Create(UIParent)
    chart.canvas:SetSize(800, 200)
  end)

  it("shows a placeholder and no bars without a trace", function()
    chart:SetTrace(nil)
    assert.are.equal(0, #shownBars(chart))
    assert.is_true(chart.empty:IsShown())
  end)

  it("draws each call on the time axis, one row per depth", function()
    chart:SetTrace(sampleTrace())
    chart:SetWindow(0, 8)
    assert.is_false(chart.empty:IsShown())
    assert.are.equal(2, #shownBars(chart))
    local outer, inner = barFor(chart, "PerfChartA.TOuter"), barFor(chart, "PerfChartA.TInner")
    local _, _, _, ox, oy = outer:GetPoint(1)
    local _, _, _, ix, iy = inner:GetPoint(1)
    assert.are.equal(0, ox)
    assert.are.equal(0, oy)
    assert.are.equal(100, ix)
    assert.are.equal(-chart.ROW_HEIGHT, iy)
    assert.are.equal(500 - 1, inner:GetWidth())
  end)

  it("finds the call under a point", function()
    chart:SetTrace(sampleTrace())
    chart:SetWindow(0, 8)
    assert.are.equal("PerfChartA.TInner", chart:HitTest(150, chart.ROW_HEIGHT + 2).slice.name)
    assert.are.equal("PerfChartA.TOuter", chart:HitTest(50, 2).slice.name)
    assert.is_nil(chart:HitTest(50, chart.ROW_HEIGHT * 3))
  end)

  it("zooms to a call when it is clicked and back out with a right-click", function()
    chart:SetTrace(sampleTrace())
    chart:SetWindow(0, 8)
    chart:ZoomToCall(chart:HitTest(150, chart.ROW_HEIGHT + 2).slice.call)
    assert.are.equal(1, chart.from)
    assert.are.equal(6, chart.to)
    chart.canvas:GetScript("OnMouseUp")(chart.canvas, "RightButton")
    -- Twice as wide around the same center (-1.5 to 8.5), kept inside the capture.
    assert.are.equal(0, chart.from)
    assert.are.equal(8.5, chart.to)
  end)

  it("zooms around a point with the mouse wheel and scrolls rows with Shift", function()
    chart:SetTrace(sampleTrace())
    chart:SetWindow(0, 8)
    chart:ZoomAt(0.25, 0.5)
    assert.are.equal(1, chart.from)
    assert.are.equal(5, chart.to)
    chart.canvas:SetSize(800, chart.ROW_HEIGHT)
    chart:SetWindow(0, 8)
    _G._isShiftKeyDown = true
    chart.canvas:GetScript("OnMouseWheel")(chart.canvas, -1)
    _G._isShiftKeyDown = false
    assert.are.equal(1, chart.depthOffset)
    assert.is_not_nil(barFor(chart, "PerfChartA.TInner"))
  end)

  it("keeps the window inside the capture", function()
    local trace = sampleTrace()
    chart:SetTrace(trace)
    chart:SetWindow(-10, 1000)
    assert.are.equal(0, chart.from)
    assert.are.equal(trace.session.stats.durationMs, chart.to)
  end)

  it("describes a call in the tooltip, with its arguments and return values", function()
    chart:SetTrace(sampleTrace())
    chart:SetWindow(0, 8)
    chart:ShowTooltip(chart:HitTest(150, chart.ROW_HEIGHT + 2))
    local text = {}
    for _, l in ipairs(GameTooltip.doubleLines) do text[l.left] = l.right end
    assert.are.equal("5.00 ms", text["Duration"])
    assert.are.equal("1", text["Frame"])
    local lines = {}
    for _, l in ipairs(GameTooltip.lines) do lines[#lines + 1] = l.text end
    local all = table.concat(lines, "\n")
    assert.is_truthy(all:find("<PerfChartA>, 9", 1, true), all)
    assert.is_truthy(all:find("18", 1, true), all)
  end)

  it("tells the owner when the window changes", function()
    local windows = {}
    chart.onWindowChanged = function(from, to) table.insert(windows, { from, to }) end
    chart:SetTrace(sampleTrace())
    chart:SetWindow(2, 4)
    assert.are.same({ 2, 4 }, windows[#windows])
  end)
end)
