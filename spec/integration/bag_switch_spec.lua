-- bag_switch_spec.lua -- Switching between the classic bags and BetterBags Next without a reload
-- (next.md §11), on the whole addon (spec/helpers/whole_addon.lua): every file of the TOC loaded
-- as the client loads it, started as the client starts it. spec/bagsystem_spec.lua covers
-- BagSystem's own steps with stand-in bags; this covers the real bags, which is where the classic
-- bags made after a theme was applied failed in game (frames/bag.lua: "attempt to index field
-- 'searchBox'").
local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("switching bag designs on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
      handle = nil
    end
  end)

  local function start(opts)
    handle = WholeAddon.Load(opts)
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    return handle.addon
  end

  local function ctx(addon)
    return addon:GetModule("Context"):New("spec")
  end

  local function switch(addon, design)
    assert.is_true(addon:GetModule("BagSystem"):Switch(ctx(addon), design))
    assert.are.same({}, handle.errors, "switching to " .. design)
    assert.are.equal(design, addon:GetModule("BagSystem"):ActiveDesign())
  end

  -- listening lists every event and message BetterBags listens to, with how many callbacks each.
  local function listening(addon)
    local events = addon:GetModule("Events")
    local out = {}
    for name, entry in pairs(events._eventMap) do out["event " .. name] = #entry.cbs end
    for name, entry in pairs(events._messageMap) do out["message " .. name] = #entry.cbs end
    return out
  end

  local function freshStart(opts)
    local addon = start(opts)
    local found = listening(addon)
    handle:Restore()
    handle = nil
    return found
  end

  it("starts with the classic bags and switches to BetterBags Next and back", function()
    local addon = start()
    assert.are.equal("classic", addon:GetModule("BagSystem"):ActiveDesign())
    switch(addon, "next")
    assert.is_not_nil(addon.Vendor)
    switch(addon, "classic")
    assert.is_nil(addon.Vendor)
    switch(addon, "next")
  end)

  it("starts with BetterBags Next and makes the classic bags after the theme was applied, parts placed", function()
    local addon = start({ next = true })
    assert.are.equal("next", addon:GetModule("BagSystem"):ActiveDesign())
    switch(addon, "classic")
    local backpack = addon.Bags.Backpack
    assert.is_not_nil(backpack.searchBox.frame:GetPoint(1), "the search box placed by the theme's layout")
    assert.is_not_nil(backpack.bottomBar:GetPoint(1), "the footer placed")
    assert.is_not_nil(addon.Bags.Bank.searchBox.frame:GetPoint(1), "the bank's search box placed")
    switch(addon, "next")
  end)

  it("switches with the backpack open, the other design opening in its place", function()
    local addon = start()
    addon.Bags.Backpack:Show(ctx(addon))
    local classic = addon.Bags.Backpack
    switch(addon, "next")
    assert.is_false(classic.frame:IsShown())
    assert.is_true(addon.Bags.Backpack:IsShown())
    addon.Bags.Backpack:Hide(ctx(addon))
    switch(addon, "classic")
    assert.is_false(addon.Bags.Backpack:IsShown())
    addon.Bags.Backpack:Show(ctx(addon))
    addon.Bags.Backpack:Hide(ctx(addon))
    assert.are.same({}, handle.errors, "opening and closing")
  end)

  -- The design not in use is unhooked entirely (asked: "performance especially, we need to unhook
  -- the classic bags when we swap, and vice versa"): after a switch, BetterBags listens to exactly
  -- what a fresh start in that design listens to.
  it("listens to what a fresh start in BetterBags Next listens to, after switching from the classic bags", function()
    local fresh = freshStart({ next = true })
    local addon = start()
    switch(addon, "next")
    assert.are.same(fresh, listening(addon))
  end)

  it("listens to what a fresh start in the classic bags listens to, after switching from BetterBags Next", function()
    local fresh = freshStart()
    local addon = start({ next = true })
    switch(addon, "classic")
    assert.are.same(fresh, listening(addon))
  end)

  -- Switching back to a design made earlier hooks its registrations again, and only those.
  it("listens to what a fresh start in each design listens to, switching back to one made earlier", function()
    local freshClassic = freshStart()
    local freshNext = freshStart({ next = true })
    local addon = start()
    switch(addon, "next")
    switch(addon, "classic")
    assert.are.same(freshClassic, listening(addon))
    switch(addon, "next")
    assert.are.same(freshNext, listening(addon))
  end)
end)
