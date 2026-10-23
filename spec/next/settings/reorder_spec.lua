-- reorder_spec.lua -- NextListReorder (next/settings/reorder.lua): dragging a row of a settings list
-- to a new place, shared by the bag's Categories tab and the Categories page's list (CLAUDE.md, "UI
-- Consistency"): it follows the pointer while the left button is down, a marker where the row would land,
-- and drops it after the entry above the pointer's half of a row.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextListReorder", "next/settings/reorder.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local reorder = addon:GetModule("NextListReorder")
local style = addon:GetModule("NextStyle")

describe("NextListReorder", function()
  local box, content, entries, drops, drag

  before_each(function()
    UseNextTheme(nil)
    box = CreateFrame("Frame", nil, UIParent, "WowScrollBox")
    box:_SetRect(0, 0, 300, 300)
    content = CreateFrame("Frame", nil, box)
    entries = { { header = true }, { name = "A" }, { name = "B" }, { name = "C" } }
    drops = {}
    drag = reorder:Create({
      box = box, content = content,
      entries = function() return entries end,
      heightOf = function(entry) return entry.header and 20 or 40 end,
      onDrop = function(name, after) table.insert(drops, { name, after }) end,
    })
    _G._mouseButtonsDown = { LeftButton = true }
  end)

  after_each(function()
    _G._mouseButtonsDown = nil
    _G._cursorX, _G._cursorY = 0, 0
  end)

  -- at puts the pointer that far down the list, from its top.
  local function at(down)
    _G._cursorX, _G._cursorY = 20, 300 - down
  end

  local function step()
    box:GetScript("OnUpdate")(box, 0.016)
  end

  local function markerY()
    local _, _, _, _, y = drag.marker:GetPoint(1)
    return -y
  end

  it("draws the theme's drop marker, hidden until a drag", function()
    local K = style.Theme.Settings.BagCategories.DropMarker
    assert.are.equal(content, drag.marker:GetParent())
    assert.is_false(drag.marker:IsShown())
    assert.are.equal(K.Size or 2, drag.marker:GetHeight())
  end)

  it("marks where the row would land: before a row in its top half, after it in its bottom half", function()
    drag:Start("C")
    at(20 + 10)
    step()
    assert.is_true(drag.marker:IsShown())
    assert.are.equal(20, markerY(), "the top of A")
    at(20 + 30)
    step()
    assert.are.equal(60, markerY(), "the bottom of A")
    at(500)
    step()
    assert.are.equal(140, markerY(), "past the last row: after it")
  end)

  it("drops the row after the entry above where it is let go, once", function()
    drag:Start("C")
    at(20 + 30)
    step()
    _G._mouseButtonsDown = {}
    step()
    assert.are.same({ { "C", 2 } }, drops)
    assert.is_false(drag.marker:IsShown())
    assert.is_nil(box:GetScript("OnUpdate"))
  end)

  it("counts what the list is scrolled", function()
    box._scrollRange, box._scrollPercentage = 100, 0.5
    drag:Start("A")
    at(10 + 40)
    step()
    assert.are.equal(100, markerY(), "50 scrolled: the bottom of B")
  end)

  it("marks nothing and drops nothing while the list has no place on screen", function()
    box._rect = nil
    drag:Start("A")
    step()
    assert.is_false(drag.marker:IsShown())
    _G._mouseButtonsDown = {}
    step()
    assert.are.same({}, drops)
  end)

  -- Painting a texture shows it (controls:Paint): a theme applied after a drag must not bring the
  -- marker back where the drag last left it.
  it("restyles its marker with the theme, keeping it hidden outside a drag", function()
    drag:Start("C")
    at(20 + 30)
    step()
    _G._mouseButtonsDown = {}
    step()
    UseNextTheme({ Settings = { BagCategories = { DropMarker = { Size = 4 } } } })
    drag:Style()
    assert.are.equal(4, drag.marker:GetHeight())
    assert.is_false(drag.marker:IsShown())
    _G._mouseButtonsDown = { LeftButton = true }
    drag:Start("C")
    step()
    drag:Style()
    assert.is_true(drag.marker:IsShown(), "still shown mid-drag")
  end)
end)
