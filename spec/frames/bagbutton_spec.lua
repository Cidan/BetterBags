-- bagbutton_spec.lua -- the bag slot actions (frames/bagbutton.lua, BagButtonFrame:PickupBag and PutInBag):
-- what Blizzard's bag slot buttons do (Blizzard_MainMenuBarBagButtons, BaseBagSlotButtonMixin: a drag
-- picks the bag up with PickupBagFromSlot, a drop or a click puts the one on the cursor there with
-- PutItemInBag), refused in combat. The classic bags' bag buttons and BetterBags Next's Show Blizzard Bags
-- tabs (docs/next-batch-2.md §4) both use them.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end
StubBetterBagsModule("Constants")
StubBetterBagsModule("Events")
LoadBetterBagsModule("core/pool.lua")
ResetModuleStub("BagButton", "frames/bagbutton.lua")
LoadBetterBagsModule("frames/bagbutton.lua")
local bagButton = addon:GetModule("BagButton")

describe("BagButtonFrame's bag slot actions", function()
  local saved, calls, printed, combat

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved, calls, printed, combat = {}, {}, {}, false
    override(_G, "PickupBagFromSlot", function(invID) table.insert(calls, { "pickup", invID }) end)
    override(_G, "PutItemInBag", function(invID) table.insert(calls, { "put", invID }) return true end)
    override(_G, "InCombatLockdown", function() return combat end)
    override(_G, "print", function(text) table.insert(printed, text) end)
    _G._isShiftKeyDown = false
  end)

  after_each(function()
    for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
    _G._isShiftKeyDown = false
  end)

  it("picks a bag up from its slot, and puts the one on the cursor in it", function()
    assert.is_true(bagButton:PickupBag(23))
    assert.is_true(bagButton:PutInBag(24))
    assert.are.same({ { "pickup", 23 }, { "put", 24 } }, calls)
  end)

  it("changes no bag in combat, saying so", function()
    combat = true
    assert.is_false(bagButton:PickupBag(23))
    assert.is_false(bagButton:PutInBag(23))
    assert.are.same({}, calls)
    assert.are.same({ "BetterBags: Cannot change bags in combat.", "BetterBags: Cannot change bags in combat." }, printed)
  end)

  -- The classic bags' bag buttons, as before: a drag picks the bag up, a drop puts one in, a click puts the
  -- one on the cursor in or, with Shift, picks the bag up.
  it("is what the classic bag buttons do", function()
    local proto = bagButton.bagButtonProto
    local b = setmetatable({ invID = 21 }, { __index = proto })
    b:OnDragStart()
    b:OnReceiveDrag()
    b:OnClick()
    _G._isShiftKeyDown = true
    b:OnClick()
    assert.are.same({ { "pickup", 21 }, { "put", 21 }, { "put", 21 }, { "pickup", 21 } }, calls)
    combat = true
    b:OnClick()
    b:OnDragStart()
    assert.are.equal(4, #calls)
  end)
end)
