-- pixel_spec.lua -- BetterBags Next's controls on whole screen pixels (docs/next-pixel-perfect.md): every
-- control (next/controls/), in each of its states, placed by its corner at a whole-pixel offset in a window
-- on whole pixels, on the reporter's window at 65%, a common screen at 64%, a large one at 115%, and in a
-- window drawn smaller (the settings window scales itself down to fit a small screen).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
StubBetterBagsModule("Constants")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextSlider", "next/controls/slider.lua" },
  { "NextMenu", "next/controls/menu.lua" }, { "NextDropdown", "next/controls/dropdown.lua" },
  { "NextSwatch", "next/controls/swatch.lua" }, { "NextTopTabs", "next/controls/toptabs.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextItemGrid", "next/controls/itemgrid.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local pixel = addon:GetModule("NextPixel")
local tween = addon:GetModule("NextTween")
local controls = addon:GetModule("NextControls")
local nextButton = addon:GetModule("NextButton")
local nextToggle = addon:GetModule("NextToggle")
local nextInput = addon:GetModule("NextInput")
local nextSlider = addon:GetModule("NextSlider")
local nextMenu = addon:GetModule("NextMenu")
local nextDropdown = addon:GetModule("NextDropdown")
local nextSwatch = addon:GetModule("NextSwatch")
local nextTopTabs = addon:GetModule("NextTopTabs")
local nextDialog = addon:GetModule("NextDialog")
local itemGrid = addon:GetModule("NextItemGrid")
local nextScrollBar = addon:GetModule("NextScrollBar")
local layout = dofile("spec/helpers/layout.lua")

local SCREENS = {
  { 3396, 1362, 0.65, 1 }, { 1920, 1080, 0.64, 1 }, { 2560, 1440, 1.15, 1 }, { 3396, 1362, 0.65, 0.87 },
}

describe("BetterBags Next's controls on the screen's pixels", function()
  local undo, window

  -- The quality colors an item grid's cells are edged in (core/constants.lua's shape).
  local const = addon:GetModule("Constants")
  local colors = rawget(const, "ITEM_QUALITY_COLOR")
  setup(function()
    const.ITEM_QUALITY_COLOR = {}
    for q = 0, 8 do const.ITEM_QUALITY_COLOR[q] = { 1, 1, 1, 1 } end
  end)
  teardown(function()
    const.ITEM_QUALITY_COLOR = colors
  end)

  local function settle()
    for _ = 1, 3 do
      tween:Step(5)
    end
  end

  -- at puts a control's frame by its top left a whole number of pixels into the window.
  local function at(frame, x, y)
    frame:ClearAllPoints()
    pixel:Point(frame, "TOPLEFT", window, "TOPLEFT", x, -y)
    return frame
  end

  local function offGrid()
    settle()
    return layout.PixelCheck(window)
  end

  for _, screen in ipairs(SCREENS) do
    local name = string.format("%dx%d at %d%%, the window at %d%%", screen[1], screen[2], screen[3] * 100,
      screen[4] * 100)

    describe(name, function()
      local saved

      before_each(function()
        undo = layout.UseScreen(screen[1], screen[2], screen[3])
        -- What a new grid does in game (NextPixel:OnGridChanged): the theme applied again, fonts made for
        -- the grid, every control made so far restyled.
        UseNextTheme(nil)
        for _, m in ipairs({ nextButton, nextToggle, nextInput, nextSlider, nextMenu, nextDropdown, nextSwatch,
          nextTopTabs, nextDialog, itemGrid, nextScrollBar }) do
          m:ApplyStyle()
        end
        -- Escape's list, and timers held (ReleaseEscape waits for the next frame).
        saved = { _G.UISpecialFrames, C_Timer.After }
        _G.UISpecialFrames = {}
        C_Timer.After = function() end
        controls.escape = {}
        window = CreateFrame("Frame", nil, UIParent)
        window:SetScale(screen[4])
        pixel:Point(window, "TOPLEFT", UIParent, "TOPLEFT", 37, -23)
        pixel:Size(window, 900, 700)
      end)

      after_each(function()
        nextMenu:Close()
        nextDialog:Hide()
        settle()
        _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
        undo()
      end)

      it("draws a button of every style, idle, under the pointer, pressed and disabled", function()
        local x = 10
        for _, kind in ipairs({ "Plain", "Primary", "Danger", "Link" }) do
          local b = nextButton:Create(window, { text = "Delete " .. kind, style = kind, onClick = function() end })
          at(b.frame, x, 10)
          x = x + 150
          assert.are.same({}, offGrid(), kind)
          b:Enter()
          b:SetPressed(true)
          assert.are.same({}, offGrid(), kind .. " pressed")
          b:Leave()
          b:SetEnabled(false)
          assert.are.same({}, offGrid(), kind .. " disabled")
          b:SetText("A longer label")
          assert.are.same({}, offGrid(), kind .. " relabelled")
        end
        local fixed = nextButton:Create(window, { text = "Done", width = 97.3, onClick = function() end })
        at(fixed.frame, 10, 60)
        assert.are.same({}, offGrid(), "a fixed width")
      end)

      it("draws a switch off, on and sliding to rest, under the pointer and disabled", function()
        local t = nextToggle:Create(window, { checked = false, onChange = function() end })
        at(t.frame, 10, 10)
        assert.are.same({}, offGrid(), "off")
        t:Click({})
        assert.are.same({}, offGrid(), "on, at rest")
        t:SetHovered(true)
        t:SetEnabled(false)
        assert.are.same({}, offGrid(), "disabled")
      end)

      it("draws a slider at every value, under the pointer", function()
        local s = nextSlider:Create(window, { min = 0, max = 100, step = 1, value = 37, onChange = function() end })
        at(s.frame, 10, 10)
        for _, value in ipairs({ 0, 1, 37, 50, 99, 100 }) do
          s:SetValue(value)
          assert.are.same({}, offGrid(), "at " .. value)
        end
        s:SetHovered(true)
        assert.are.same({}, offGrid(), "under the pointer")
        local fine = nextSlider:Create(window, { min = 0.5, max = 2, step = 0.05, value = 1.15, onChange = function() end })
        at(fine.frame, 10, 60)
        assert.are.same({}, offGrid(), "a fine step")
      end)

      it("draws a field, empty with its help, with text, focused, with an icon, and a text area", function()
        local plain = nextInput:Create(window, { help = "Search Settings", width = 213.7 })
        at(plain.frame, 10, 10)
        assert.are.same({}, offGrid(), "empty")
        plain:SetText("ore")
        plain.frame:GetScript("OnEditFocusGained")(plain.frame)
        assert.are.same({}, offGrid(), "focused")
        local search = nextInput:Create(window, { help = "Search", icon = function()
          return { Texture = "Interface\\Common\\UI-Searchbox-Icon", Size = 13, Color = "Muted" }
        end })
        at(search.frame, 10, 60)
        assert.are.same({}, offGrid(), "with its icon")
        local area = nextInput:CreateArea(window, { height = 121.4, help = "Paste an export here" })
        at(area.frame, 10, 110)
        pixel:Width(area.frame, 400)
        area:Style()
        assert.are.same({}, offGrid(), "a text area")
      end)

      it("draws a dropdown, idle, under the pointer and open, and the menu it opens", function()
        local items = { "Alphabetically", "Size Descending", "Size Ascending" }
        local d = nextDropdown:Create(window, { items = items, get = function() return items[2] end,
          onChange = function() end })
        at(d.frame, 10, 10)
        assert.are.same({}, offGrid(), "idle")
        d:SetHovered(true)
        d:Click({})
        assert.is_true(nextMenu.frame:IsShown())
        assert.are.same({}, offGrid(), "open")
        assert.are.same({}, layout.PixelCheck(nextMenu.frame), "its menu")
        nextMenu:Close()
        local many = {}
        for i = 1, 30 do table.insert(many, "Choice " .. i) end
        nextMenu:Open(d.frame, { items = (function()
          local list = {}
          for i, text in ipairs(many) do list[i] = { text = text, selected = i == 3 } end
          return list
        end)(), onPick = function() end, width = 181.6 })
        assert.are.same({}, layout.PixelCheck(nextMenu.frame), "a menu that scrolls")
      end)

      it("draws a swatch, idle and under the pointer", function()
        local s = nextSwatch:Create(window, { color = { 0.2, 0.4, 0.6, 1 }, onChange = function() end })
        at(s.frame, 10, 10)
        assert.are.same({}, offGrid(), "idle")
        s:SetHovered(true)
        assert.are.same({}, offGrid(), "under the pointer")
      end)

      it("draws top tabs, each selected, one under the pointer", function()
        local tabs = nextTopTabs:Create(window, { onSelect = function() end })
        at(tabs.frame, 10, 10)
        pixel:Width(tabs.frame, 500)
        tabs:SetTabs({ { id = "theme", text = "Theme" }, { id = "size", text = "Size" }, { id = "colors", text = "Item Colors" } })
        for _, id in ipairs({ "theme", "size", "colors" }) do
          tabs:Select(id, true)
          assert.are.same({}, offGrid(), id)
        end
        tabs.tabs[1].hovered = true
        tabs:Paint()
        assert.are.same({}, offGrid(), "under the pointer")
      end)

      it("draws a dialog over the window: title, text, a field and its buttons", function()
        nextDialog:Show(window, { title = "Rename Category", text = "What should this category be called? It may be long enough to wrap.",
          input = { text = "Mats", help = "A name" },
          buttons = { { text = "Cancel", onClick = function() end }, { text = "Rename", style = "Primary", onClick = function() end } } })
        assert.are.same({}, offGrid(), "with a field")
        nextDialog:Show(window, { title = "Delete", text = "Delete it?",
          buttons = { { text = "Delete", style = "Danger", onClick = function() end } } })
        assert.are.same({}, offGrid(), "without")
      end)

      it("draws an item grid, empty and full, and a scroll bar along a box", function()
        local grid = itemGrid:Create(window, { empty = "Drop items here" })
        at(grid.frame, 10, 10)
        grid:Place(300.4, 150.2)
        grid:SetEntries({})
        assert.are.same({}, offGrid(), "empty")
        local entries = {}
        for i = 1, 40 do
          table.insert(entries, { id = i, itemID = 1000 + i, icon = 134400, quality = i % 5, count = i })
        end
        grid:SetEntries(entries)
        assert.are.same({}, offGrid(), "full")
        local box = CreateFrame("Frame", nil, window, "WowScrollBox")
        at(box, 400, 10)
        pixel:Size(box, 200, 333)
        local bar = nextScrollBar:Create(box)
        bar:OnScroll(0.37, 0.41)
        assert.is_true(bar.frame:IsShown())
        assert.are.same({}, offGrid(), "a scroll bar")
        bar:SetHovered(true)
        assert.are.same({}, offGrid(), "a scroll bar under the pointer")
      end)
    end)
  end
end)
