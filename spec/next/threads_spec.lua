-- threads_spec.lua -- NextThreads (next/threads.lua): a Next theme's threads of light (Panel.Threads, next-themes.md §22;
-- the Frost theme's gold): smooth curves through a theme's points round the body, drawn as Lines on the panel's own
-- frame (under its content), swaying slowly, a glint running along them now and then; they draw themselves in as the
-- panel opens and unravel as it closes. Mirrored on a panel whose inner side is on the right.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextThreads", "next/threads.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local threads = addon:GetModule("NextThreads")

describe("NextThreads", function()
  local savedRandom

  -- panelOn makes what the threads read of a panel: its frame, its body (400 x 600 in it), its side and size.
  local function panelOn(side, small)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(496, 600)
    local body = CreateFrame("Frame", nil, frame)
    body:SetSize(400, 600)
    local panel = { frame = frame, body = body, side = side, small = small == true }
    function panel:IsSmall() return self.small end
    panel.threads = threads:Create(panel)
    return panel
  end

  local THREAD = { Anchor = "TOP", Points = { { 0, 20 }, { 0.5, 60 }, { 1, 20 } }, Segments = 8, Width = 6,
    Texture = "Thread", Color = "Gold", Alpha = 0.5, BlendMode = "ADD", Layer = "ARTWORK", SubLevel = 4 }

  local function with(changes)
    local spec = {}
    for k, v in pairs(THREAD) do spec[k] = v end
    for k, v in pairs(changes or {}) do spec[k] = v end
    return spec
  end

  local function theme(list)
    UseNextTheme({ Textures = { Thread = "thread.png" }, Panel = { Threads = list } })
  end

  local function started(list, side, small)
    theme(list)
    local panel = panelOn(side or "RIGHT", small)
    panel.threads:Style()
    panel.threads:Start()
    return panel
  end

  local function step(panel, dt)
    local d = panel.threads.driver
    local update = d:GetScript("OnUpdate")
    if update then update(d, dt) end
  end

  -- Where a line starts and ends, from the body's top left (y down).
  local function ends(line)
    local p1, rel1, x1, y1 = line:GetStartPoint()
    local p2, rel2, x2, y2 = line:GetEndPoint()
    return { p1, p2 }, rel1, rel2, x1, -y1, x2, -y2
  end

  before_each(function()
    savedRandom = threads.Random
    local seed = 9
    threads.Random = function()
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    end
  end)

  after_each(function()
    threads.Random = savedRandom
    UseNextTheme(nil)
  end)

  it("draws nothing for a theme without threads", function()
    UseNextTheme({})
    local panel = panelOn("RIGHT")
    panel.threads:Style()
    panel.threads:Start()
    assert.are.equal(0, #panel.threads.threads)
    assert.is_nil(panel.threads.driver:GetScript("OnUpdate"))
  end)

  it("draws each thread as Segments lines on the panel's frame, as the theme says", function()
    local panel = started({ THREAD })
    local t = panel.threads.threads[1]
    assert.are.equal(8, #t.lines)
    for _, line in ipairs(t.lines) do
      assert.are.equal("Line", line._type)
      assert.are.equal(panel.frame, line:GetParent())
      assert.are.same({ "ARTWORK", 4 }, { line:GetDrawLayer() })
      assert.are.equal("thread.png", line:GetTexture())
      assert.are.equal("ADD", line:GetBlendMode())
      assert.are.equal(6, line:GetThickness())
      assert.is_true(line:IsShown())
      assert.is_true(math.abs(line:GetAlpha() - 0.5) < 1e-9)
      local points, rel1, rel2 = ends(line)
      assert.are.same({ "TOPLEFT", "TOPLEFT" }, points)
      assert.are.equal(panel.body, rel1)
      assert.are.equal(panel.body, rel2)
    end
  end)

  it("runs smoothly through its points, from the body's inner side, joined end to end", function()
    local panel = started({ THREAD })
    local lines = panel.threads.threads[1].lines
    local _, _, _, x1, y1 = ends(lines[1])
    assert.are.same({ 0, 20 }, { x1, y1 })
    local _, _, _, _, _, xe, ye = ends(lines[8])
    assert.is_true(math.abs(xe - 400) < 1e-9 and math.abs(ye - 20) < 1e-9)
    -- Through the middle point, half way.
    local _, _, _, _, _, xm, ym = ends(lines[4])
    assert.is_true(math.abs(xm - 200) < 1e-9 and math.abs(ym - 60) < 1e-9)
    for i = 2, 8 do
      local _, _, _, _, _, px, py = ends(lines[i - 1])
      local _, _, _, sx, sy = ends(lines[i])
      assert.is_true(math.abs(px - sx) < 1e-9 and math.abs(py - sy) < 1e-9)
    end
  end)

  it("is mirrored on a panel whose inner side is on the right", function()
    local panel = started({ with({ Points = { { 0, 20 }, { 0.25, 60 } } }) }, "LEFT")
    local lines = panel.threads.threads[1].lines
    local _, _, _, x1 = ends(lines[1])
    assert.is_true(math.abs(x1 - 400) < 1e-9)
    local _, _, _, _, _, xe = ends(lines[8])
    assert.is_true(math.abs(xe - 300) < 1e-9)
  end)

  it("measures from the body's bottom, or as shares of its height", function()
    local panel = started({ with({ Anchor = "BOTTOM", Points = { { 0, 30 }, { 1, 30 } } }),
      with({ Anchor = "BODY", Points = { { 0, 0.25 }, { 1, 0.5 } } }) })
    local _, _, _, _, y1 = ends(panel.threads.threads[1].lines[1])
    assert.are.equal(570, y1)
    local _, _, _, _, b1 = ends(panel.threads.threads[2].lines[1])
    local _, _, _, _, _, _, b2 = ends(panel.threads.threads[2].lines[8])
    assert.are.same({ 150, 300 }, { b1, b2 })
  end)

  it("draws a thread only at its size", function()
    local small = started({ with({ Sizes = "Full" }) }, "RIGHT", true)
    for _, line in ipairs(small.threads.threads[1].lines) do
      assert.is_false(line:IsShown())
    end
    local full = started({ with({ Sizes = "Full" }) }, "RIGHT", false)
    assert.is_true(full.threads.threads[1].lines[1]:IsShown())
  end)

  it("sways while the panel shows, and holds still without Sway or once stopped", function()
    local panel = started({ with({ Sway = { Amplitude = 8, Period = 4 } }) })
    local line = panel.threads.threads[1].lines[3]
    local _, _, _, x0, y0 = ends(line)
    step(panel, 0.5)
    local _, _, _, x1, y1 = ends(line)
    assert.is_true(math.abs(x1 - x0) > 0.05 and math.abs(y1 - y0) > 0.05, "swaying both ways")
    panel.threads:Stop()
    assert.is_nil(panel.threads.driver:GetScript("OnUpdate"))
    local still = started({ THREAD })
    assert.is_nil(still.threads.driver:GetScript("OnUpdate"), "nothing to move")
  end)

  it("runs a glint along it now and then, start to end", function()
    local panel = started({ with({ Glint = { Every = 4, Time = 1, Length = 0.2, Color = "White", Strength = 1 } }) })
    local t = panel.threads.threads[1]
    local function brightest()
      local best, at = -1, nil
      for i, line in ipairs(t.lines) do
        if line:GetAlpha() > best then best, at = line:GetAlpha(), i end
      end
      return at, best
    end
    local glinted = false
    for _ = 1, 140 do
      step(panel, 0.05)
      if t.glint ~= nil then glinted = true break end
    end
    assert.is_true(glinted, "a glint by 6.4 seconds")
    step(panel, 0.25)
    local early = brightest()
    step(panel, 0.4)
    local later, peak = brightest()
    assert.is_true(later > early, "along it: " .. early .. " then " .. later)
    assert.is_true(peak > 0.9)
    local r, g, b = t.lines[later]:GetVertexColor()
    assert.is_true(r > 0.9 and g > 0.9 and b > 0.9, "toward its glint's colour")
    step(panel, 0.5)
    assert.is_nil(t.glint)
    for _, line in ipairs(t.lines) do
      assert.is_true(math.abs(line:GetAlpha() - 0.5) < 1e-9)
    end
  end)

  describe("drawing in and unravelling", function()
    local function shown(t)
      local n = 0
      for _, line in ipairs(t.lines) do
        if line:IsShown() then n = n + 1 end
      end
      return n
    end

    it("draws itself in from its start once its delay is up, its tip bright", function()
      local panel = started({ with({ Draw = 1 }) })
      local t = panel.threads.threads[1]
      panel.threads:DrawIn(0.2)
      assert.are.equal(0, shown(t))
      step(panel, 0.2)
      assert.are.equal(0, shown(t))
      step(panel, 0.5)
      local n = shown(t)
      assert.is_true(n > 0 and n < 8, "half drawn: " .. n)
      assert.is_true(t.lines[1]:IsShown())
      assert.is_false(t.lines[8]:IsShown())
      assert.is_true(t.lines[n]:GetAlpha() > 0.5, "its tip bright")
      step(panel, 0.6)
      assert.are.equal(8, shown(t))
      for _, line in ipairs(t.lines) do
        assert.is_true(math.abs(line:GetAlpha() - 0.5) < 1e-9)
      end
    end)

    it("ends a part-drawn segment where it has reached", function()
      local panel = started({ with({ Draw = 1, Points = { { 0, 0 }, { 1, 0 } } }) })
      local t = panel.threads.threads[1]
      panel.threads:DrawIn(0)
      step(panel, 0.4)
      local last
      for _, line in ipairs(t.lines) do
        if line:IsShown() then last = line end
      end
      local _, _, _, _, _, x = ends(last)
      -- Eased out: 0.4 of its time in it has reached 1 - 0.6 * 0.6 of the way, inside its sixth segment.
      assert.is_true(math.abs(x - 0.64 * 400) < 1e-6, "reached " .. x)
    end)

    it("unravels back to nothing", function()
      local panel = started({ THREAD })
      local t = panel.threads.threads[1]
      panel.threads:Unravel(0.4)
      step(panel, 0.2)
      local n = shown(t)
      assert.is_true(n > 0 and n < 8)
      step(panel, 0.3)
      assert.are.equal(0, shown(t))
    end)

    -- The panel's open asks for its draw-in before it starts what moves (Show).
    it("keeps a draw-in asked for before it starts", function()
      theme({ with({ Draw = 1 }) })
      local panel = panelOn("RIGHT")
      panel.threads:Style()
      panel.threads:DrawIn(0)
      panel.threads:Start()
      assert.are.equal(0, shown(panel.threads.threads[1]))
      step(panel, 1.1)
      assert.are.equal(8, shown(panel.threads.threads[1]))
    end)

    it("shows whole once started again without drawing in", function()
      local panel = started({ with({ Draw = 1 }) })
      panel.threads:DrawIn(0)
      panel.threads:Stop()
      panel.threads:Start()
      assert.are.equal(8, shown(panel.threads.threads[1]))
    end)
  end)

  it("takes a new theme's threads, and none from a theme without", function()
    local panel = started({ THREAD })
    local line = panel.threads.threads[1].lines[1]
    theme({ with({ Segments = 4 }), with({ Segments = 3 }) })
    panel.threads:Style()
    assert.are.equal(2, #panel.threads.threads)
    assert.are.equal(4, #panel.threads.threads[1].lines)
    UseNextTheme({})
    panel.threads:Style()
    assert.are.equal(0, #panel.threads.threads)
    assert.is_false(line:IsShown())
  end)

  it("follows the body's size", function()
    local panel = started({ with({ Anchor = "BOTTOM", Points = { { 0, 30 }, { 1, 30 } } }) })
    panel.body:SetSize(300, 400)
    panel.threads:Layout()
    local _, _, _, _, y1, x2 = ends(panel.threads.threads[1].lines[1])
    local _, _, _, _, _, xe = ends(panel.threads.threads[1].lines[8])
    assert.are.equal(370, y1)
    assert.is_true(math.abs(xe - 300) < 1e-9)
    assert.is_number(x2)
  end)

  it("names every line a moving part", function()
    local panel = started({ THREAD })
    local skip = {}
    panel.threads:MovingParts(skip)
    for _, line in ipairs(panel.threads.threads[1].lines) do
      assert.is_true(skip[line])
    end
  end)
end)
