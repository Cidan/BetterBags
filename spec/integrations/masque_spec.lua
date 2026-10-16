-- masque_spec.lua -- The Masque integration (integrations/masque.lua).
--
-- Item buttons are redrawn without being released between passes, and a release no longer
-- removes a button from its group (item/Clearing). Masque's AddButton
-- returns early for a button already in the group, so the integration must re-skin it
-- instead, or BetterBags' quality border (texcoords, blend) would stay drawn over the skin.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end

local const = stubModule("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
local debug = stubModule("Debug")
debug.Log = debug.Log or function() end
local sonata = stubModule("Sonata")

-- A Masque group with the behavior of Masque 12.1.0 Core/Group.lua: AddButton returns
-- early when the button is already in this group (and moves it from another group),
-- RemoveButton unskins and forgets it, ReSkin(Button) re-applies the skin to a member.
local groups = {}
local function newGroup(name)
  local group = { name = name, Buttons = {}, log = {} }
  function group:AddButton(button)
    if self.Buttons[button] then return end
    for _, other in pairs(groups) do
      other.Buttons[button] = nil
    end
    self.Buttons[button] = true
    table.insert(self.log, "skin")
  end
  function group:RemoveButton(button)
    self.Buttons[button] = nil
    table.insert(self.log, "unskin")
  end
  function group:ReSkin(button)
    if self.Buttons[button] then
      table.insert(self.log, "skin")
    end
  end
  function group:RegisterCallback() end
  groups[name] = group
  return group
end

local Masque = LibStub:NewLibrary("Masque", 1) or LibStub("Masque")
Masque.Group = function(_, _, name)
  return groups[name] or newGroup(name)
end

LoadFreshBetterBagsModule("Masque", "integrations/masque.lua")
local masque = addon:GetModule("Masque")

-- Enabled once: OnEnable registers its message handlers, and registering them again for
-- every test would leave the earlier handlers firing too.
local disableMasque = false
local savedUsesMasque = sonata.UsesMasque
sonata.UsesMasque = function() return not disableMasque end
events:Init()
local savedPrint = _G.print
_G.print = function() end
masque:OnEnable()
_G.print = savedPrint

describe("Masque integration", function()

  local function newButton(kind)
    local decoration = CreateFrame("Button")
    decoration.IconBorder = decoration:CreateTexture()
    return { kind = kind }, decoration
  end

  local function send(event, item, decoration)
    events:SendMessage(context:New("test"), event, item, decoration)
  end

  before_each(function()
    disableMasque = false
    for _, group in pairs(groups) do
      group.Buttons = {}
      group.log = {}
    end
    masque.added = setmetatable({}, { __mode = "k" })
  end)

  teardown(function()
    sonata.UsesMasque = savedUsesMasque
    ResetModuleStub("Masque", "integrations/masque.lua")
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  it("skins a button again on every redraw, not just the first", function()
    local item, decoration = newButton(const.BAG_KIND.BACKPACK)
    send("item/Updated", item, decoration)
    send("item/Updated", item, decoration)
    send("item/Updated", item, decoration)
    assert.are.same({ "skin", "skin", "skin" }, groups["Backpack"].log)
  end)

  -- Item buttons exist for the whole session (they are created at boot), so a released
  -- button stays in its group. Masque's RemoveButton is a full pass restoring the default
  -- look, which the button's next draw would undo with another full pass: leaving Show Bags
  -- spent 9.5 ms un-skinning 145 empty-slot buttons. The next draw re-skins it as any
  -- redraw does.
  it("keeps a released button in its group, and skins it again when it is drawn", function()
    local item, decoration = newButton(const.BAG_KIND.BACKPACK)
    send("item/Updated", item, decoration)
    send("item/Clearing", item, decoration)
    assert.are.same({ "skin" }, groups["Backpack"].log, "a release does not un-skin")
    assert.is_true(groups["Backpack"].Buttons[decoration])
    send("item/Updated", item, decoration)
    assert.are.same({ "skin", "skin" }, groups["Backpack"].log)
  end)

  it("moves a released button reused for the other bag into that bag's group", function()
    local item, decoration = newButton(const.BAG_KIND.BACKPACK)
    send("item/Updated", item, decoration)
    send("item/Clearing", item, decoration)
    item.kind = const.BAG_KIND.BANK
    send("item/Updated", item, decoration)
    assert.is_nil(groups["Backpack"].Buttons[decoration])
    assert.is_true(groups["Bank"].Buttons[decoration])
  end)

  it("moves a button reused for the other bag into that bag's group", function()
    local item, decoration = newButton(const.BAG_KIND.BACKPACK)
    send("item/Updated", item, decoration)
    item.kind = const.BAG_KIND.BANK
    send("item/Updated", item, decoration)
    assert.is_nil(groups["Backpack"].Buttons[decoration])
    assert.is_true(groups["Bank"].Buttons[decoration])
    assert.are.same({ "skin" }, groups["Bank"].log)
  end)

  it("leaves buttons alone when the theme disables Masque", function()
    disableMasque = true
    local item, decoration = newButton(const.BAG_KIND.BACKPACK)
    send("item/Updated", item, decoration)
    assert.are.same({}, groups["Backpack"].log)
  end)

  -- Item buttons keep one decoration across themes, which the theme restyles: a theme that
  -- turns Masque off takes the buttons Masque skinned back out of their groups, so Masque's
  -- skin does not stay under the theme's look. The next draw under a Masque theme adds them.
  it("takes every skinned button out of its group when a theme turns Masque off", function()
    local backpackItem, backpackDecoration = newButton(const.BAG_KIND.BACKPACK)
    local bankItem, bankDecoration = newButton(const.BAG_KIND.BANK)
    send("item/Updated", backpackItem, backpackDecoration)
    send("item/Updated", bankItem, bankDecoration)
    disableMasque = true
    events:SendMessage(context:New("test"), "sonata/ThemeChanged", "Flat")
    assert.is_nil(groups["Backpack"].Buttons[backpackDecoration])
    assert.is_nil(groups["Bank"].Buttons[bankDecoration])
    assert.are.same({ "skin", "unskin" }, groups["Backpack"].log)
    disableMasque = false
    events:SendMessage(context:New("test"), "sonata/ThemeChanged", "Default")
    send("item/Updated", backpackItem, backpackDecoration)
    assert.is_true(groups["Backpack"].Buttons[backpackDecoration])
  end)
end)
