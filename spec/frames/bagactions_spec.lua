-- bagactions_spec.lua -- A bag's action buttons (frames/bagactions.lua): the buttons a theme
-- gives a bag window in its Layout.Actions (GW2's side panel). Each names one of BetterBags'
-- actions; the theme gives only where they go and their art.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local L = stubModule("Localization")
L.G = L.G or function(_, key) return key end
local contextMenu = stubModule("ContextMenu")
local menuButton = stubModule("BagMenuButton")

LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
ResetModuleStub("BagActions", "frames/bagactions.lua")
LoadBetterBagsModule("frames/bagactions.lua")
local bagActions = addon:GetModule("BagActions")

describe("BagActions", function()
  local saved, ran

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved, ran = {}, {}
    override(contextMenu, "ToggleBagSlots", function(_, _, bag) table.insert(ran, { "ShowBags", bag }) end)
    override(contextMenu, "Show", function(_, _, list) table.insert(ran, { "Menu", list }) end)
    override(menuButton, "Sort", function(_, _, bag) table.insert(ran, { "Sort", bag }) end)
    override(events, "SendMessage", function(_, _, message) table.insert(ran, { "message", message }) end)
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    ResetModuleStub("BagActions", "frames/bagactions.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function newBag()
    local bag = { menuList = { "menu" } }
    bag.frame = CreateFrame("Frame", nil, UIParent)
    bag.frame:SetFrameLevel(500)
    return bag
  end

  local LAYOUT = {
    Points = { { Point = "TOPLEFT", X = -35, Y = -40 } },
    Size = 32,
    Spacing = 5,
    Buttons = {
      { Action = "ShowBags", Normal = { Texture = "Interface\\bags-up" }, Highlight = { Texture = "Interface\\bags-up" } },
      { Action = "Sort", Normal = { Texture = "Interface\\sort-up" } },
      { Action = "Settings", Normal = { Texture = "Interface\\settings-up" } },
      { Action = "Menu", Normal = { Texture = "Interface\\menu-up" } },
    },
  }

  local function place(bag, layout)
    local overlay = CreateFrame("Frame", nil, bag.frame)
    overlay:SetFrameLevel(1000)
    local actions = bag.actions or bagActions:Create(bag)
    bag.actions = actions
    bagActions:Place(actions, layout, bag.frame, overlay)
    return actions
  end

  it("builds a button per action, stacked down from the first point, above the window's chrome", function()
    local bag = newBag()
    local actions = place(bag, LAYOUT)
    local buttons = actions.buttons
    assert.are.equal(4, #buttons)
    assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", -35, -40 }, { buttons[1]:GetPoint(1) })
    for i = 2, 4 do
      assert.are.same({ "TOP", buttons[i - 1], "BOTTOM", 0, -5 }, { buttons[i]:GetPoint(1) })
    end
    for i, button in ipairs(buttons) do
      assert.are.same({ 32, 32 }, { button:GetWidth(), button:GetHeight() })
      assert.is_true(button:IsShown())
      assert.is_true(button:GetFrameLevel() > 1000)
      assert.are.equal(LAYOUT.Buttons[i].Normal.Texture, button:GetNormalTexture():GetTexture())
    end
    assert.are.equal("Interface\\bags-up", buttons[1]:GetHighlightTexture():GetTexture())
  end)

  it("runs BetterBags' own action for each button", function()
    local bag = newBag()
    local buttons = place(bag, LAYOUT).buttons
    for _, button in ipairs(buttons) do
      button:GetScript("OnClick")(button, "LeftButton")
    end
    assert.are.same({ "ShowBags", bag }, ran[1])
    assert.are.same({ "Sort", bag }, ran[2])
    assert.are.same({ "message", "config/Open" }, ran[3])
    assert.are.same({ "Menu", bag.menuList }, ran[4])
  end)

  it("names each action in its tooltip", function()
    local buttons = place(newBag(), LAYOUT).buttons
    for i, text in ipairs({ "Show Bags", "Sort Bags", "Open Settings", "Open Menu" }) do
      buttons[i]:GetScript("OnEnter")(buttons[i])
      assert.are.equal(buttons[i], GameTooltip._owner)
      assert.are.equal(text, GameTooltip._text)
    end
  end)

  it("hides its buttons for a theme without actions, and reuses them, art cleared, for the next", function()
    local bag = newBag()
    local first = place(bag, LAYOUT).buttons[1]
    place(bag, false)
    for _, button in ipairs(bag.actions.buttons) do
      assert.is_false(button:IsShown())
    end
    place(bag, { Size = 20, Buttons = { { Action = "Menu", Normal = { Texture = "Interface\\other" } } } })
    assert.are.equal(first, bag.actions.buttons[1])
    assert.is_true(first:IsShown())
    assert.are.same({ 20, 20 }, { first:GetWidth(), first:GetHeight() })
    assert.is_nil(first:GetHighlightTexture():GetTexture())
    assert.is_false(bag.actions.buttons[2]:IsShown())
    first:GetScript("OnClick")(first, "LeftButton")
    assert.are.same({ "Menu", bag.menuList }, ran[1])
  end)

  it("rejects an action it does not know", function()
    assert.has_error(function()
      place(newBag(), { Buttons = { { Action = "Juggle" } } })
    end)
  end)
end)
