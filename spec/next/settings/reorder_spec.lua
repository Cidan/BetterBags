-- reorder_spec.lua -- NextListReorder (next/settings/reorder.lua): a settings list's rows, arranged one
-- under another and dragged to a new place the way BetterBags Next's sections are (next.md §7): the row
-- is lifted (NextLift) and follows the cursor, the list keeps a room its height under the cursor, the
-- other rows slide out of its way (Motion), and the row lands into its room when let go. Shared by the
-- bag's Order tab and the Categories page's list (CLAUDE.md, "UI Consistency"). Asked: "instead of a
-- line on drag, let's animate the move like we do categories".
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextLift", "next/lift.lua" }, { "NextListReorder", "next/settings/reorder.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local reorder = addon:GetModule("NextListReorder")
local lift = addon:GetModule("NextLift")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")
local style = addon:GetModule("NextStyle")

describe("NextListReorder", function()
  local box, content, entries, rows, drops, drag, first

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function keyOf(entry)
    return entry.name or ("# " .. entry.title)
  end

  -- placeContent puts the list's top where the client would, whatever its rows make its height.
  local function placeContent(top, left)
    content.GetLeft, content.GetTop = function() return left or 0 end, function() return top end
  end

  local function make()
    drag = reorder:Create({
      box = box, content = content, first = first,
      entries = function() return entries end,
      rowOf = function(entry) return rows[keyOf(entry)] end,
      heightOf = function(entry) return entry.header and 20 or 40 end,
      onDrop = function(name, after) table.insert(drops, { name, after }) end,
    })
  end

  before_each(function()
    UseNextTheme(nil)
    tween:Init()
    motion:Init()
    box = CreateFrame("Frame", nil, UIParent, "WowScrollBox")
    box:_SetRect(0, 0, 300, 300)
    box:Hide()
    content = CreateFrame("Frame", nil, box)
    placeContent(300)
    entries = { { header = true, title = "Pinned" }, { name = "A" }, { name = "B" }, { name = "C" } }
    rows = {}
    for _, entry in ipairs(entries) do
      rows[keyOf(entry)] = CreateFrame("Button", nil, content)
    end
    drops = {}
    first = nil
    make()
    _G._mouseButtonsDown = { LeftButton = true }
  end)

  after_each(function()
    if lift:IsHolding() then
      lift:Put(lift.held, content)
    end
    _G._mouseButtonsDown = nil
    _G._cursorX, _G._cursorY = 0, 0
  end)

  local function yOf(key)
    local _, _, _, _, y = rows[key]:GetPoint(1)
    return y and -y
  end

  -- at puts the cursor that far down the list, from its top.
  local function at(down)
    _G._cursorX, _G._cursorY = 20, 300 - down
  end

  -- start picks a row up where the client placed it (Arrange, at the list's left).
  local function start(name, down)
    rows[name]:_SetRect(0, 300 - yOf(name) - 40, 280, 40)
    at(down or yOf(name) + 10)
    return drag:Start(name)
  end

  local function step()
    drag:Update(0.016)
  end

  describe("arranging", function()
    it("puts the rows one under another, as wide as the list, the content as tall as they are", function()
      assert.are.equal(140, drag:Arrange(280))
      assert.are.same({ 0, 20, 60, 100 }, { yOf("# Pinned"), yOf("A"), yOf("B"), yOf("C") })
      local point, rel, relPoint = rows.A:GetPoint(1)
      assert.are.same({ "TOPLEFT", content, "TOPLEFT" }, { point, rel, relPoint })
      assert.are.equal(280, rows.C:GetWidth())
      assert.are.equal(140, content:GetHeight())
      assert.is_true((box._fullUpdates or 0) > 0)
      rows.C:SetWidth(10)
      drag:Arrange()
      assert.are.equal(280, rows.C:GetWidth(), "the width it was last given")
    end)

    it("puts the rows at once while hidden, and slides them to their new places while shown", function()
      drag:Arrange(280)
      entries[3], entries[4] = entries[4], entries[3]
      drag:Arrange(280)
      assert.is_nil(motion:GetMove(rows.C), "hidden: at once")
      assert.are.equal(60, yOf("C"))
      box:Show()
      drag:Arrange(280)
      entries[3], entries[4] = entries[4], entries[3]
      drag:Arrange(280)
      local _, y0, _, y1 = motion:GetMove(rows.C)
      assert.are.same({ -60, -100 }, { y0, y1 }, "shown: it slides")
      assert.is_not_nil(motion:GetMove(rows.B))
      assert.is_nil(motion:GetMove(rows.A), "a row that keeps its place stays still")
    end)

    it("slides its rows a pose at a time under a theme's stop motion", function()
      local saved = style.StopMotion
      local stepping = { FPS = 10 }
      style.StopMotion = stepping
      box:Show()
      drag:Arrange(280)
      entries[3], entries[4] = entries[4], entries[3]
      drag:Arrange(280)
      style.StopMotion = saved
      assert.are.equal(stepping, motion.moves[rows.C].stepping)
      motion:Step(1)
    end)

    it("slides its rows in the interaction time, as the bags' sections do", function()
      box:Show()
      drag:Arrange(280)
      entries[3], entries[4] = entries[4], entries[3]
      drag:Arrange(280)
      motion:Step(style.Time.Interaction - 0.001)
      assert.is_not_nil(motion:GetMove(rows.C))
      motion:Step(0.002)
      assert.is_nil(motion:GetMove(rows.C))
      assert.are.equal(60, yOf("C"))
    end)
  end)

  describe("dragging a row", function()
    before_each(function()
      drag:Arrange(280)
    end)

    it("lifts it and keeps its room where it was", function()
      assert.is_true(start("B"))
      assert.are.equal(lift.layer, rows.B:GetParent())
      assert.is_true(drag:IsDragging())
      assert.are.same({ 0, 20, 100 }, { yOf("# Pinned"), yOf("A"), yOf("C") })
    end)

    it("moves its room under the cursor, the other rows making way, and follows the cursor", function()
      start("B")
      at(130)
      step()
      assert.are.same({ 20, 60 }, { yOf("A"), yOf("C") }, "past C's middle: C moves up into B's place")
      local _, rel, _, x, y = rows.B:GetPoint(1)
      assert.are.same({ UIParent, 0, 300 - 130 + 10 }, { rel, x, y }, "the point grabbed under the cursor")
      at(30)
      step()
      assert.are.same({ 60, 100 }, { yOf("A"), yOf("C") }, "in A's top half: before A")
      at(50)
      step()
      assert.are.same({ 20, 100 }, { yOf("A"), yOf("C") }, "in A's bottom half: after A")
    end)

    it("never puts its room before the first place it may land", function()
      first = 2
      make()
      drag:Arrange(280)
      start("B")
      at(1)
      step()
      assert.are.same({ 0, 60, 100 }, { yOf("# Pinned"), yOf("A"), yOf("C") }, "after the heading")
    end)

    it("goes by where the list is on screen, as it scrolls", function()
      start("A")
      placeContent(350)
      box._scrollRange, box._scrollPercentage = 100, 0.5
      at(20)
      step()
      assert.are.equal(20, yOf("B"), "20 down on screen is 70 in the list: past B's middle, before C's")
      assert.are.equal(100, yOf("C"))
    end)

    -- A list partway down what its box scrolls: the tab's own content, with a filter above it (a bag's Order tab).
    it("goes by where the list is, wherever that is in its box", function()
      start("A")
      placeContent(200)
      at(150)
      step()
      assert.are.same({ 20, 100 }, { yOf("B"), yOf("C") }, "150 down the box is 50 into the list: past B's middle, before C")
    end)

    it("keeps its room while the list has no place on screen", function()
      start("B")
      placeContent(nil)
      at(130)
      step()
      assert.are.equal(100, yOf("C"))
    end)

    it("scrolls the list near its edges", function()
      box._scrollRange, box._scrollPercentage = 1000, 0.5
      start("B")
      _G._cursorX, _G._cursorY = 20, 5
      step()
      assert.is_true(box._scrollPercentage > 0.5)
    end)

    it("drags one row at a time, and none while another drag holds the lift", function()
      start("B")
      rows.C:_SetRect(0, 160, 280, 40)
      assert.is_false(drag:Start("C"))
      drag:Cancel()
      local other = {}
      rows.A:_SetRect(0, 240, 280, 40)
      assert.is_true(lift:Pick(other, rows.A, function() end))
      assert.is_false(start("C"))
      lift:Put(other, content)
    end)
  end)

  describe("letting go", function()
    before_each(function()
      drag:Arrange(280)
    end)

    local function release()
      _G._mouseButtonsDown = {}
      step()
    end

    it("lands the row into its room, then says what it lands after, counted with itself", function()
      start("B")
      at(130)
      step()
      release()
      assert.are.same({}, drops, "while it lands")
      finishTweens()
      assert.are.same({ { "B", 4 } }, drops, "after C")
      assert.are.equal(content, rows.B:GetParent())
      assert.are.equal(1, rows.B:GetScale())
      assert.are.equal(100, yOf("B"))
      assert.is_false(drag:IsDragging())
      assert.is_false(lift:IsHolding())
    end)

    it("aims at its room as it lands", function()
      start("B")
      at(130)
      step()
      release()
      tween:Step(style.Time.Land - 0.001)
      tween:Step(0.0005)
      local _, _, _, x, y = rows.B:GetPoint(1)
      local s = rows.B:GetScale()
      assert.is_true(math.abs(x * s - 0) < 0.5 and math.abs(y * s - (300 - 100)) < 0.5,
        "about at the room's top left on screen: " .. x * s .. ", " .. y * s)
    end)

    -- The settings window scales itself down to fit a small screen (next-settings.md §3): the list is read
    -- on screen, in UIParent's units, and the row keeps its size there.
    it("moves its room under the cursor and lands in it in a window scaled down", function()
      local window = CreateFrame("Frame", nil, UIParent)
      window:SetScale(0.5)
      box:SetParent(window)
      content:SetParent(box)
      drag:Arrange(280)
      rows.B:_SetRect(0, 300 - yOf("B") - 40, 280, 40)
      _G._cursorX, _G._cursorY = 10, (300 - yOf("B") - 10) * 0.5
      assert.is_true(drag:Start("B"))
      assert.are.equal(0.5, rows.B:GetScale(), "lifted at its size on screen")
      _G._cursorY = (300 - 130) * 0.5
      step()
      assert.are.same({ 20, 60 }, { yOf("A"), yOf("C") }, "past C's middle, on screen")
      release()
      tween:Step(style.Time.Land - 0.00001)
      local _, _, _, x, y = rows.B:GetPoint(1)
      local s = rows.B:GetScale()
      assert.is_true(math.abs(s - 0.5) < 0.01, "lands at the window's scale: " .. s)
      assert.is_true(math.abs(x * s) < 0.5 and math.abs(y * s - (300 - 100) * 0.5) < 0.5,
        "at the room's top left on screen: " .. x * s .. ", " .. y * s)
      finishTweens()
      assert.are.same({ { "B", 4 } }, drops)
    end)

    it("aims at its room on screen as the list is scrolled", function()
      start("B")
      placeContent(350, 30)
      box._scrollRange, box._scrollPercentage = 100, 0.5
      at(80)
      step()
      release()
      tween:Step(style.Time.Land - 0.001)
      tween:Step(0.0005)
      local _, _, _, x, y = rows.B:GetPoint(1)
      local s = rows.B:GetScale()
      assert.is_true(math.abs(y * s - (300 + 50 - 100)) < 0.5, "50 scrolled: " .. y * s)
      assert.is_true(math.abs(x * s - 30) < 0.5, "at the list's left: " .. x * s)
    end)

    it("ignores the cursor while it lands", function()
      start("B")
      at(130)
      step()
      release()
      _G._mouseButtonsDown = { LeftButton = true }
      at(1)
      step()
      assert.are.same({ 20, 60 }, { yOf("A"), yOf("C") })
      finishTweens()
      assert.are.same({ { "B", 4 } }, drops)
    end)

    it("says 0 for a row landing before every other", function()
      start("C")
      at(1)
      step()
      release()
      finishTweens()
      assert.are.same({ { "C", 0 } }, drops)
    end)

    it("shows the new order itself when its owner does not draw the list again", function()
      start("B")
      at(130)
      step()
      release()
      finishTweens()
      local names = {}
      for i, entry in ipairs(entries) do names[i] = keyOf(entry) end
      assert.are.same({ "# Pinned", "A", "C", "B" }, names)
      assert.are.same({ 60, 100 }, { yOf("C"), yOf("B") })
    end)

    it("leaves the order to its owner when it draws the list again", function()
      local fresh = { entries[1], entries[3], entries[2], entries[4] }
      drag.opts.onDrop = function(name, after)
        table.insert(drops, { name, after })
        entries = fresh
        drag:Arrange()
      end
      start("B")
      at(30)
      step()
      release()
      finishTweens()
      assert.are.same({ { "B", 1 } }, drops)
      assert.are.equal(fresh, entries)
      assert.are.same({ 20, 60 }, { yOf("B"), yOf("A") })
    end)

    it("says nothing when it lands where it was", function()
      start("B")
      release()
      finishTweens()
      assert.are.same({}, drops)
      assert.are.equal(60, yOf("B"))
    end)
  end)

  describe("ending early", function()
    before_each(function()
      drag:Arrange(280)
    end)

    it("puts the row straight back in its place when the list hides", function()
      box:Show()
      start("B")
      at(130)
      step()
      content:Hide()
      content:GetScript("OnHide")(content)
      assert.is_false(drag:IsDragging())
      assert.is_false(lift:IsHolding())
      assert.are.equal(content, rows.B:GetParent())
      assert.are.same({ 60, 100 }, { yOf("B"), yOf("C") })
      assert.are.same({}, drops)
    end)

    it("ends the drag of a row whose entry left the list", function()
      start("B")
      table.remove(entries, 3)
      drag:Arrange()
      assert.is_false(drag:IsDragging())
      assert.are.equal(content, rows.B:GetParent())
      assert.are.equal(60, yOf("C"))
    end)
  end)
end)
