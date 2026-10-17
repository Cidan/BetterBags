-- flow_spec.lua -- Flow (render/flow.lua): the pure packing every BetterBags grid lays out with.
-- It places boxes in rows within columns from their sizes alone and touches no frame, so a
-- layout can be measured (how wide would this be?) before anything moves (render-pipeline.md,
-- the layout engine).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("render/flow.lua")
local flow = addon:GetModule("Flow")

local function sizes(...)
  local out = {}
  for i, wh in ipairs({ ... }) do out[i] = { wh[1], wh[2] } end
  return out
end

local function xy(packed)
  local out = {}
  for i, p in ipairs(packed.positions) do out[i] = { p.x, p.y } end
  return out
end

describe("Flow", function()
  it("places boxes left to right, wrapping a row when the next box would pass the limit", function()
    local packed = flow:Pack(sizes({ 37, 37 }, { 37, 37 }, { 37, 37 }), { rowLimit = 80 })
    assert.are.same({ { 0, 0 }, { 41, 0 }, { 0, -41 } }, xy(packed))
    assert.are.equal(78, packed.width)
    assert.are.equal(78, packed.height)
  end)

  -- The limit is checked without the gap before a row's last box, so a row can run one spacing
  -- past it: two 131-wide sections share a row limited to 262 and take 266.
  it("lets a row run one spacing past its limit", function()
    local packed = flow:Pack(sizes({ 131, 61 }, { 131, 61 }), { rowLimit = 262 })
    assert.are.same({ { 0, 0 }, { 135, 0 } }, xy(packed))
    assert.are.equal(266, packed.width)
  end)

  it("makes a row as tall as its tallest box", function()
    local packed = flow:Pack(sizes({ 50, 20 }, { 50, 60 }, { 50, 10 }), { rowLimit = 110 })
    assert.are.same({ { 0, 0 }, { 54, 0 }, { 0, -64 } }, xy(packed))
    assert.are.equal(74, packed.height)
  end)

  it("reports an empty layout as one spacing wide and nothing tall", function()
    local packed = flow:Pack({}, { rowLimit = 100 })
    assert.are.same({}, packed.positions)
    assert.are.same({ 4, 0 }, { packed.width, packed.height })
    assert.are.same({ 4, 0 }, { flow:Pack({}, { rowLimit = 100, columns = 3 }).width, 0 })
  end)

  -- Columns: boxes fill a column until it is about its share of the total height, then the next
  -- column starts at a row boundary; columns sit side by side at their own widths.
  it("splits rows into columns by height, each column as wide as its widest row", function()
    local packed = flow:Pack(sizes({ 131, 200 }, { 213, 200 }, { 90, 200 }), { rowLimit = 220, columns = 3 })
    assert.are.same({ { 0, 0 }, { 131, 0 }, { 344, 0 } }, xy(packed))
    assert.are.same({ 434, 200 }, { packed.width, packed.height })
    assert.are.same({ 1, 2, 3 }, packed.columnOf)
  end)

  -- 200 + 50 + 200 tall rows in 2 columns: the first share (249) puts each row in its own column,
  -- three of them, so the share grows by the overshoot over twice the columns (50) and it tries
  -- again: the first two rows share a column.
  it("tries a larger share when the rows split into more columns than asked", function()
    local packed = flow:Pack(sizes({ 300, 200 }, { 300, 50 }, { 300, 200 }), { rowLimit = 300, columns = 2 })
    assert.are.same({ 1, 1, 2 }, packed.columnOf)
    assert.are.same({ { 0, 0 }, { 0, -204 }, { 300, 0 } }, xy(packed))
  end)

  it("keeps everything in one column when it asks for one", function()
    local packed = flow:Pack(sizes({ 100, 50 }, { 100, 50 }), { rowLimit = 120, columns = 1 })
    assert.are.same({ { 0, 0 }, { 0, -54 } }, xy(packed))
    assert.are.same({ 1, 1 }, packed.columnOf)
  end)

  it("uses the spacing it is given", function()
    local packed = flow:Pack(sizes({ 10, 10 }, { 10, 10 }), { rowLimit = 100, spacing = 2 })
    assert.are.same({ { 0, 0 }, { 12, 0 } }, xy(packed))
  end)

  it("touches nothing it was given", function()
    local given = sizes({ 37, 37 }, { 37, 37 })
    flow:Pack(given, { rowLimit = 40, columns = 2 })
    assert.are.same(sizes({ 37, 37 }, { 37, 37 }), given)
  end)
end)
