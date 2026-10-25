-- itemgrid_spec.lua -- NextItemGrid (next/controls/itemgrid.lua): a scrolling grid of item icons for the
-- settings window (next-settings.md §5). Only the cells of the rows in view exist, reused as it scrolls,
-- so a list of thousands costs what a screenful does. A cell shows an item's icon, its quality on its
-- edge, its count, and a faded look for an item that shows in another category; its tooltip is the
-- item's, with a note and a hint. The grid takes an item dropped anywhere on it, and passes right
-- clicks and modified clicks on.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local const = StubBetterBagsModule("Constants")
-- core/constants.lua's colors; other specs leave the shared stub with only some of them.
local QUALITY_COLOR = {
  [0] = { 0.62, 0.62, 0.62, 1 }, [1] = { 1, 1, 1, 1 }, [2] = { 0.12, 1, 0, 1 }, [3] = { 0, 0.44, 0.87, 1 },
  [4] = { 0.64, 0.21, 0.93, 1 },
}
LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextItemGrid", "next/controls/itemgrid.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local itemGrid = addon:GetModule("NextItemGrid")
local controls = addon:GetModule("NextControls")
local style = addon:GetModule("NextStyle")

describe("NextItemGrid", function()
  local grid, dropped, rightClicked, saved

  local function G()
    return controls:Theme("ItemGrid")
  end

  local function entries(n)
    local list = {}
    for i = 1, n do
      list[i] = { id = i, itemID = 1000 + i, icon = 5000 + i }
    end
    return list
  end

  -- shown returns the entries of the cells shown, in their order.
  local function shown()
    local list = {}
    for _, cell in ipairs(grid.cells) do
      if cell.frame:IsShown() then table.insert(list, cell.entry.id) end
    end
    return list
  end

  local function cellOf(id)
    for _, cell in ipairs(grid.cells) do
      if cell.frame:IsShown() and cell.entry.id == id then return cell end
    end
  end

  before_each(function()
    dropped, rightClicked = 0, {}
    saved = { CursorHasItem = _G.CursorHasItem, HandleModifiedItemClick = _G.HandleModifiedItemClick,
      IsModifiedClick = _G.IsModifiedClick, colors = rawget(const, "ITEM_QUALITY_COLOR") }
    const.ITEM_QUALITY_COLOR = QUALITY_COLOR
    _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
    grid = itemGrid:Create(CreateFrame("Frame"), {
      onDrop = function() dropped = dropped + 1 end,
      onRightClick = function(_, entry) table.insert(rightClicked, entry.id) end,
      hint = "Right-click to remove it.",
      empty = "Nothing here yet.",
    })
  end)

  after_each(function()
    _G.CursorHasItem, _G.HandleModifiedItemClick, _G.IsModifiedClick =
      saved.CursorHasItem, saved.HandleModifiedItemClick, saved.IsModifiedClick
    const.ITEM_QUALITY_COLOR = saved.colors
    GameTooltip:Hide()
  end)

  describe("laying out", function()
    it("puts as many columns as fit, and makes the content as tall as every row", function()
      local K = G()
      local step = K.Size + K.Gap
      grid:Place(400, 200)
      grid:SetEntries(entries(25))
      local columns = math.floor((400 - 2 * K.Pad + K.Gap) / step)
      assert.are.equal(columns, grid.columns)
      local rows = math.ceil(25 / columns)
      assert.are.equal(2 * K.Pad + rows * step - K.Gap, grid.content:GetHeight())
      local fifth = cellOf(columns + 2)
      assert.are.same({ "TOPLEFT", grid.content, "TOPLEFT", K.Pad + step, -(K.Pad + step) }, { fifth.frame:GetPoint(1) })
      assert.are.equal(K.Size, fifth.frame:GetWidth())
    end)

    it("makes only the cells of the rows in view, and reuses them as it scrolls", function()
      local K = G()
      local step = K.Size + K.Gap
      grid:Place(400, 200)
      grid:SetEntries(entries(3000))
      local columns = grid.columns
      local inView = math.floor((200 - K.Pad) / step) + 1
      assert.are.equal(inView * columns, #shown())
      assert.are.equal(1, shown()[1])
      local made = #grid.cells
      grid.box._scrollRange = grid.content:GetHeight() - 200
      grid.box:SetScrollPercentage(0.5)
      local offset = grid.box:GetDerivedScrollOffset()
      local first = math.max(0, math.floor((offset - K.Pad) / step))
      assert.are.equal(first * columns + 1, shown()[1])
      grid.box:SetScrollPercentage(1)
      assert.are.equal(3000, shown()[#shown()], "the last row")
      assert.is_true(#grid.cells <= made + columns, "never more than a screenful and a row")
      local last = cellOf(3000)
      local row = math.floor((3000 - 1) / columns)
      assert.are.same({ "TOPLEFT", grid.content, "TOPLEFT", K.Pad + ((3000 - 1) % columns) * step, -(K.Pad + row * step) },
        { last.frame:GetPoint(1) })
    end)

    it("shows its empty text with no entries, and hides it with some", function()
      grid:Place(400, 200)
      grid:SetEntries({})
      assert.is_true(grid.empty:IsShown())
      assert.are.equal("Nothing here yet.", grid.empty:GetText())
      assert.are.same({}, shown())
      grid:SetEntries(entries(2))
      assert.is_false(grid.empty:IsShown())
      assert.are.same({ 1, 2 }, shown())
    end)

    it("hides the cells of entries it no longer has", function()
      grid:Place(400, 200)
      grid:SetEntries(entries(20))
      grid:SetEntries(entries(3))
      assert.are.same({ 1, 2, 3 }, shown())
    end)
  end)

  describe("a cell", function()
    it("shows the icon, the count above one, the quality on its edge, and fades for elsewhere", function()
      grid:Place(400, 200)
      grid:SetEntries({
        { id = 1, itemID = 11, icon = 501, quality = 4, count = 20 },
        { id = 2, itemID = 12, icon = 502, quality = 1, count = 1, dim = true },
      })
      local epic, common = cellOf(1), cellOf(2)
      assert.are.equal(501, epic.icon:GetTexture())
      assert.are.equal("20", epic.count:GetText())
      assert.is_true(epic.count:IsShown())
      local c = const.ITEM_QUALITY_COLOR[4]
      assert.are.same({ r = c[1], g = c[2], b = c[3], a = 1 }, epic.edge.Top._colorTexture)
      assert.are.equal(1, epic.frame:GetAlpha())
      assert.is_false(common.count:IsShown())
      assert.are.equal(G().CommonEdge.Alpha, common.edge.Top._colorTexture.a, "common items: the plain edge")
      assert.are.equal(G().DimAlpha, common.frame:GetAlpha())
    end)

    it("shows the item's tooltip, by link or by ID, with its note and the grid's hint", function()
      grid:Place(400, 200)
      grid:SetEntries({
        { id = 1, itemID = 11, icon = 501, link = "|Hitem:11|h[Ore]|h", note = "Shows in Junk instead." },
        { id = 2, itemID = 12, icon = 502 },
      })
      local first = cellOf(1)
      first.frame:GetScript("OnEnter")(first.frame)
      assert.are.equal(first.frame, GameTooltip._owner)
      assert.are.equal("|Hitem:11|h[Ore]|h", GameTooltip._hyperlink)
      assert.are.same({ "Shows in Junk instead.", "Right-click to remove it." },
        { GameTooltip.lines[1].text, GameTooltip.lines[2].text })
      first.frame:GetScript("OnLeave")(first.frame)
      assert.is_false(GameTooltip:IsShown())
      local second = cellOf(2)
      second.frame:GetScript("OnEnter")(second.frame)
      assert.are.equal(12, GameTooltip._itemByID)
    end)

    it("passes a right click on with its entry, and a modified click to Blizzard's handler", function()
      grid:Place(400, 200)
      grid:SetEntries({ { id = 7, itemID = 11, icon = 501, link = "|Hitem:11|h[Ore]|h" } })
      local cell = cellOf(7)
      cell.frame:GetScript("OnClick")(cell.frame, "RightButton")
      assert.are.same({ 7 }, rightClicked)
      local linked
      _G.IsModifiedClick = function() return true end
      _G.HandleModifiedItemClick = function(link) linked = link return true end
      cell.frame:GetScript("OnClick")(cell.frame, "LeftButton")
      assert.are.equal("|Hitem:11|h[Ore]|h", linked)
      assert.are.equal(0, dropped)
    end)
  end)

  describe("dropping", function()
    it("takes an item dropped on a cell, on the empty part of the grid, or clicked onto either", function()
      grid:Place(400, 200)
      grid:SetEntries(entries(2))
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 99, true
      local cell = cellOf(1)
      cell.frame:GetScript("OnReceiveDrag")(cell.frame)
      cell.frame:GetScript("OnClick")(cell.frame, "LeftButton")
      grid.box:GetScript("OnReceiveDrag")(grid.box)
      grid.box:GetScript("OnMouseUp")(grid.box, "LeftButton")
      grid.frame:GetScript("OnReceiveDrag")(grid.frame)
      grid.frame:GetScript("OnMouseUp")(grid.frame, "LeftButton")
      assert.are.equal(6, dropped)
      assert.are.same({}, rightClicked, "a click with an item drops it, never removes")
    end)

    it("ignores a click with nothing on the cursor, and drops nothing without onDrop", function()
      grid:Place(400, 200)
      grid:SetEntries(entries(1))
      grid.frame:GetScript("OnMouseUp")(grid.frame, "LeftButton")
      assert.are.equal(0, dropped)
      local plain = itemGrid:Create(CreateFrame("Frame"), {})
      plain:Place(400, 200)
      plain:SetEntries(entries(1))
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 99, true
      assert.is_nil(plain.frame:GetScript("OnReceiveDrag"))
      local c = plain.cells[1]
      assert.has_no.errors(function() c.frame:GetScript("OnReceiveDrag")(c.frame) end)
    end)
  end)

  -- Its box (docs/next-plain-theme.md, round three): the grid drew the input's fill, which for a fill in pieces (Plain's
  -- search border) painted the whole box white. It draws its own fill, edge and frame, the input's when the theme gives
  -- it none.
  describe("its box", function()
    after_each(function()
      UseNextTheme(nil)
      itemGrid:ApplyStyle()
    end)

    it("is drawn in the input's fill and edge when the theme gives it none of its own", function()
      UseNextTheme({ Controls = { Input = { Fill = { Color = { 0.1, 0.2, 0.3, 1 } } } } })
      itemGrid:ApplyStyle()
      local c = grid.fill._colorTexture
      assert.is_true(grid.fill:IsShown())
      assert.are.same({ 0.1, 0.2, 0.3, 1 }, { c.r, c.g, c.b, c.a })
      assert.is_true(grid.edge.Top:IsShown())
      assert.is_false(grid.frameArt.pieces.TopLeftCorner:IsShown())
    end)

    it("is drawn in its own fill, edge and frame when the theme gives them", function()
      UseNextTheme({ Controls = { ItemGrid = { Fill = false, Edge = false, Frame = { Pieces = {
        TopLeftCorner = { Texture = "Interface\\Common\\Common-Input-Border-TL", Width = 8, Height = 8, X = -5, Y = 5 },
      } } } } })
      itemGrid:ApplyStyle()
      assert.is_false(grid.fill:IsShown())
      assert.is_false(grid.edge.Top:IsShown())
      local corner = grid.frameArt.pieces.TopLeftCorner
      assert.is_true(corner:IsShown())
      assert.are.equal("Interface\\Common\\Common-Input-Border-TL", corner:GetTexture())
      assert.are.same({ "TOPLEFT", grid.frame, "TOPLEFT", -5, 5 }, { corner:GetPoint(1) })
      -- Under its cells.
      assert.are.equal(grid.frame, corner:GetParent())
    end)
  end)

  it("is restyled by a theme", function()
    grid:Place(400, 200)
    grid:SetEntries(entries(2))
    UseNextTheme({ Controls = { ItemGrid = { Size = 20, Gap = 2 } } })
    itemGrid:ApplyStyle()
    assert.are.equal(20, grid.cells[1].frame:GetWidth())
    UseNextTheme(nil)
    itemGrid:ApplyStyle()
    local _ = style
  end)
end)
