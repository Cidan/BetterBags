-- rain_spec.lua -- NextRain (next/rain.lua): a Next theme's data rain (Panel.Rain, next-themes.md §21): columns of
-- glyphs falling a cell at a time, a bright head writing a new glyph in each cell it reaches and a trail fading behind
-- it, the glyphs it wrote staying where they were written; down the feather beside a panel's inner side or behind its
-- content, drawn on the panel's own frame (under its tabs and content), only while the panel shows.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextRain", "next/rain.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local rain = addon:GetModule("NextRain")
local style = addon:GetModule("NextStyle")
local pixel = addon:GetModule("NextPixel")

describe("NextRain", function()
  local savedRandom, savedCombat

  -- panelOn makes what the rain reads of a panel: its frame (600 tall), where its body starts in it and how wide it is,
  -- the side of the screen it belongs to and its size.
  local function panelOn(side, small)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(496, 600)
    local panel = { frame = frame, side = side, small = small == true }
    function panel:IsSmall() return self.small end
    function panel:BodyLeft() return self.side == "LEFT" and 0 or 96 end
    function panel:BodyWidth() return 400 end
    panel.rain = rain:Create(panel)
    return panel
  end

  local function theme(list)
    UseNextTheme({
      Fonts = { RainGlyph = { Size = 16, Color = "Gold" }, RainHead = { Size = 16, Color = "White" } },
      Panel = { Rain = list },
    })
  end

  local RAIN = { Where = "Feather", Font = "RainGlyph", HeadFont = "RainHead", Glyphs = "01", Spacing = 32,
    Speed = { 10, 10 }, Trail = { 4, 4 }, Alpha = 0.8, Swap = 0 }

  local function with(changes)
    local spec = {}
    for k, v in pairs(RAIN) do spec[k] = v end
    for k, v in pairs(changes or {}) do spec[k] = v end
    return spec
  end

  local function started(list, side, small)
    theme(list)
    local panel = panelOn(side or "RIGHT", small)
    panel.rain:Style()
    panel.rain:Start()
    return panel
  end

  local function step(panel, dt)
    local d = panel.rain.driver
    d:GetScript("OnUpdate")(d, dt)
  end

  local function shownGlyphs(column)
    local out = {}
    for _, g in ipairs(column.glyphs) do
      if g:IsShown() then table.insert(out, g) end
    end
    return out
  end

  local function offsetOf(g)
    local _, _, _, x, y = g:GetPoint(1)
    return x, y
  end

  local function cell()
    return pixel:FontHeight(16)
  end

  -- toRow lets the first column's head fall into a row, half way through it (10 rows a second).
  local function toRow(panel, row)
    step(panel, (row + 0.5 - panel.rain.columns[1].head) / 10)
  end

  -- yOf is where a glyph in a row is anchored: on whole pixels, the text a quarter pixel up.
  local function yOf(g, row)
    return pixel:Snap(g, -row * cell()) + pixel:TextOffset(g)
  end

  -- The rows a 600 tall frame holds.
  local function rows()
    return math.floor(600 / cell())
  end

  before_each(function()
    savedRandom = rain.Random
    rain.Random = function() return 0.5 end
    savedCombat = _G.InCombatLockdown
    _G.InCombatLockdown = function() return false end
  end)

  after_each(function()
    rain.Random = savedRandom
    _G.InCombatLockdown = savedCombat
    UseNextTheme(nil)
  end)

  it("falls in columns down the feather beside the body's inner side, a bright head and a fading trail", function()
    local panel = started({ with() })
    local column = panel.rain.columns[1]
    assert.are.equal(3, #panel.rain.columns, "the feather, 96 wide, holds three columns 32 apart")
    -- It starts rows * 0.5 * 0.5 rows above the top, falling 10 rows a second: a second later its head is in, the
    -- trail above the top yet.
    local start = -rows() * 0.25
    step(panel, (0.75 - start) / 10)
    assert.are.equal(1, #shownGlyphs(column), "its head has come in")
    step(panel, 0.5)
    local glyphs = shownGlyphs(column)
    assert.are.equal(5, #glyphs, "its head and a trail of 4")
    local head = column.glyphs[1]
    assert.are.equal(style:Font("RainHead"), head:GetFontObject())
    for i = 2, 5 do
      assert.are.equal(style:Font("RainGlyph"), column.glyphs[i]:GetFontObject(), "the trail in its own font")
    end
    local x, y = offsetOf(head)
    local q = pixel:TextOffset(head)
    -- The feather's 96 wide strip left of the body, three columns 32 wide: the first's cell from 8, on whole pixels,
    -- the text a quarter pixel right and up.
    assert.are.equal(pixel:Snap(head, 8) + q, x)
    assert.are.equal(pixel:Snap(head, -5 * cell()) + q, y, "five rows down")
    assert.are.equal(pixel:Snap(head, -4 * cell()) + q, select(2, offsetOf(column.glyphs[2])), "the trail above it")
    assert.are.equal(0.8, head:GetAlpha())
    for i = 2, 5 do
      assert.is_true(column.glyphs[i]:GetAlpha() < column.glyphs[i - 1]:GetAlpha(), "fading down its trail")
      assert.is_true(column.glyphs[i]:GetAlpha() > 0)
    end
    assert.is_true(head:GetText() == "0" or head:GetText() == "1")
    assert.are.equal(cell(), head:GetWidth())
    assert.are.equal(cell(), head:GetHeight())
    assert.are.equal("CENTER", head:GetJustifyH())
  end)

  it("shows only as long a trail as it fell with, shorter than its longest", function()
    -- Trails from 4 to 8: at 0.5, 6.
    local panel = started({ with({ Trail = { 4, 8 } }) })
    local column = panel.rain.columns[1]
    assert.are.equal(9, #column.glyphs, "as many as its longest trail and its head")
    toRow(panel, 12)
    assert.are.equal(7, #shownGlyphs(column))
  end)

  it("keeps the glyphs it wrote where it wrote them as it falls on", function()
    local panel = started({ with({ Glyphs = "ABCDEFGHIJKLMNOP" }) })
    local n = 0
    rain.Random = function()
      n = n + 1
      return (n % 16) / 16
    end
    local column = panel.rain.columns[1]
    toRow(panel, 5)
    local second = column.glyphs[2]
    local text = second:GetText()
    toRow(panel, 6)
    assert.are.equal(second, column.glyphs[3], "a row further down its trail")
    assert.are.equal(text, second:GetText(), "its glyph kept")
    assert.are.equal(yOf(second, 4), select(2, offsetOf(second)), "in its cell")
    assert.are.equal(yOf(column.glyphs[1], 6), select(2, offsetOf(column.glyphs[1])), "the head in the next row")
  end)

  it("writes a glyph in every row a slow frame passes, and catches up its trail", function()
    local panel = started({ with() })
    local column = panel.rain.columns[1]
    toRow(panel, 5)
    step(panel, 0.3)
    for i = 1, 5 do
      local g = column.glyphs[i]
      assert.are.equal(yOf(g, 8 - (i - 1)), select(2, offsetOf(g)), "each a row above the one before")
      assert.is_true(g:IsShown())
    end
  end)

  it("falls down the feather on the right of a panel whose inner side is on the right", function()
    local panel = started({ with() }, "LEFT")
    toRow(panel, 5)
    local head = panel.rain.columns[1].glyphs[1]
    assert.are.equal(pixel:Snap(head, 400 + 8) + pixel:TextOffset(head), (offsetOf(head)), "right of the body")
  end)

  it("falls behind the content across the body, at any size, and down the feather only on a full panel", function()
    local panel = started({ with({ Where = "Body", Spacing = 100 }), with() }, "RIGHT", true)
    local counts = {}
    for _, column in ipairs(panel.rain.columns) do
      counts[column.rain.Where] = (counts[column.rain.Where] or 0) + 1
    end
    assert.are.same({ Body = 4 }, counts, "a small panel has no feather")
    toRow(panel, 5)
    local head = panel.rain.columns[1].glyphs[1]
    -- The body from 96, 400 wide, four columns 100 apart: the first's cell from 96 + 50 - 8.
    assert.are.equal(pixel:Snap(head, 138) + pixel:TextOffset(head), (offsetOf(head)))
    panel.small = false
    panel.rain:Layout()
    counts = {}
    for _, column in ipairs(panel.rain.columns) do
      counts[column.rain.Where] = (counts[column.rain.Where] or 0) + 1
    end
    assert.are.same({ Body = 4, Feather = 3 }, counts, "full again, its feather has rain")
  end)

  it("centers its columns in the room when they do not fill it", function()
    local panel = started({ with({ Spacing = 40 }) })
    toRow(panel, 5)
    local head = panel.rain.columns[1].glyphs[1]
    -- Two columns 40 apart in 96: 8 to spare on each side, the first's cell from 8 + 12.
    assert.are.equal(2, #panel.rain.columns)
    assert.are.equal(pixel:Snap(head, 20) + pixel:TextOffset(head), (offsetOf(head)))
  end)

  it("follows a change in the panel's height: the rows it holds", function()
    local panel = started({ with() })
    toRow(panel, 5)
    panel.frame:SetHeight(200)
    panel.rain:Layout()
    for _ = 1, 40 do
      step(panel, 0.05)
    end
    -- Never a glyph past the frame's new bottom.
    for _, column in ipairs(panel.rain.columns) do
      for _, g in ipairs(shownGlyphs(column)) do
        local _, y = offsetOf(g)
        assert.is_true(-(y - pixel:TextOffset(g)) + cell() <= 200, "nothing past the bottom")
      end
    end
  end)

  it("lays itself out again as the panel's frame changes size (a grip, a size switch)", function()
    local panel = started({ with() })
    toRow(panel, 5)
    panel.frame:SetWidth(600)
    panel.small = true
    panel.frame:GetScript("OnSizeChanged")(panel.frame, 600, 600)
    assert.are.equal(0, #panel.rain.columns, "a small panel has no feather")
  end)

  it("starts a column again above the top once its trail has fallen past the bottom", function()
    local panel = started({ with() })
    local column = panel.rain.columns[1]
    toRow(panel, 5)
    step(panel, (rows() + 4 - column.head) / 10 + 0.05)
    assert.is_true(column.head < 0, "again from above: " .. column.head)
    assert.are.equal(0, #shownGlyphs(column))
  end)

  it("starts no column again in combat, and does once combat is over", function()
    local panel = started({ with() })
    local column = panel.rain.columns[1]
    toRow(panel, 5)
    _G.InCombatLockdown = function() return true end
    step(panel, (rows() + 4 - column.head) / 10 + 0.05)
    assert.is_true(column.head > rows(), "waiting below")
    assert.are.equal(0, #shownGlyphs(column))
    local writes = 0
    for _, g in ipairs(column.glyphs) do
      local set = g.SetText
      g.SetText = function(self, text)
        writes = writes + 1
        return set(self, text)
      end
    end
    step(panel, 1)
    assert.are.equal(0, writes, "nothing written while it waits")
    _G.InCombatLockdown = function() return false end
    step(panel, 0.01)
    assert.is_true(column.head < 0, "again from above")
  end)

  it("changes glyphs of its column now and then, Swap a second", function()
    local panel = started({ with({ Speed = { 1, 1 }, Swap = 20 }) })
    local column = panel.rain.columns[1]
    step(panel, rows() * 0.25 + 5.5)
    local writes = 0
    for _, g in ipairs(column.glyphs) do
      local set = g.SetText
      g.SetText = function(self, text)
        writes = writes + 1
        return set(self, text)
      end
    end
    local third = column.glyphs[3]
    local thirdWrites = 0
    local counted = third.SetText
    third.SetText = function(self, text)
      thirdWrites = thirdWrites + 1
      return counted(self, text)
    end
    step(panel, 0.1)
    assert.are.equal(2, writes, "two in a tenth of a second, no row passed")
    -- At 0.5, the middle of its five shown: any glyph of its column, not its head alone.
    assert.are.equal(2, thirdWrites)
    panel.rain:Stop()
    UseNextTheme(nil)
    panel = started({ with({ Speed = { 1, 1 }, Swap = 0 }) })
    column = panel.rain.columns[1]
    step(panel, rows() * 0.25 + 5.5)
    writes = 0
    for _, g in ipairs(column.glyphs) do
      local set = g.SetText
      g.SetText = function(self, text)
        writes = writes + 1
        return set(self, text)
      end
    end
    step(panel, 0.1)
    assert.are.equal(0, writes)
  end)

  it("reads its glyphs as characters, not bytes", function()
    local panel = started({ with({ Glyphs = "ｱｲ" }) })
    toRow(panel, 5)
    local text = panel.rain.columns[1].glyphs[1]:GetText()
    assert.is_true(text == "ｱ" or text == "ｲ", "a whole character: " .. tostring(text))
  end)

  it("falls only while started, and clears every glyph when it stops", function()
    theme({ with() })
    local panel = panelOn("RIGHT")
    panel.rain:Style()
    assert.is_nil(panel.rain.driver:GetScript("OnUpdate"))
    panel.rain:Start()
    toRow(panel, 5)
    panel.rain:Stop()
    assert.is_nil(panel.rain.driver:GetScript("OnUpdate"))
    assert.are.equal(0, #shownGlyphs(panel.rain.columns[1]))
    panel.rain:Start()
    assert.is_true(panel.rain.columns[1].head < 0, "again from above")
  end)

  it("draws its glyphs on the panel's own frame, under its content", function()
    local panel = started({ with() })
    toRow(panel, 5)
    local head = panel.rain.columns[1].glyphs[1]
    assert.are.equal(panel.frame, head:GetParent())
    assert.are.equal("BORDER", head:GetDrawLayer())
  end)

  it("has nothing to fall for a theme without rain, and hides what fell for one that had it", function()
    local panel = started({ with() })
    toRow(panel, 5)
    local glyph = panel.rain.columns[1].glyphs[1]
    UseNextTheme({ Panel = { Rain = false } })
    panel.rain:Style()
    assert.is_false(glyph:IsShown())
    assert.are.equal(0, #panel.rain.columns)
    assert.is_nil(panel.rain.driver:GetScript("OnUpdate"), "nothing to drive")
  end)

  it("falls on through a new theme with rain while it runs, in the new theme's fonts", function()
    local panel = started({ with() })
    toRow(panel, 5)
    UseNextTheme({
      Fonts = { RainGlyph = { Size = 16, Color = "Lavender" }, RainHead = { Size = 16, Color = "Gold" } },
      Panel = { Rain = { with() } },
    })
    panel.rain:Style()
    assert.is_not_nil(panel.rain.driver:GetScript("OnUpdate"))
    toRow(panel, 5)
    assert.are.equal(style:Font("RainHead"), panel.rain.columns[1].glyphs[1]:GetFontObject())
  end)

  it("names its glyphs for the pixel checks: they rest nowhere", function()
    local panel = started({ with() })
    toRow(panel, 5)
    local skip = {}
    panel.rain:MovingParts(skip)
    for _, g in ipairs(panel.rain.columns[1].glyphs) do
      assert.is_true(skip[g])
    end
  end)
end)
