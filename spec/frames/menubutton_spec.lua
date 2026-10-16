-- menubutton_spec.lua -- The bag's menu button (frames/menubutton.lua): the round portrait
-- button at the top left of the backpack and bank. It belongs to the bag, not to a theme: a
-- theme only places it (its window Layout.MenuButton) and styles it (the BagButton element).
-- Its click map and tooltip follow .claude/rules/bag-menu-button.md.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

-- Stubs this file creates are removed after it (the teardown at the end), so a later spec
-- file can load the real modules.
local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }

local L = trackStub("Localization")
L.G = L.G or function(_, text) return text end

local db = trackStub("Database")
local firstTime = false
local originals = {}

local contextMenu, createdContextMenu = StubBetterBagsModule("ContextMenu")
local sonata, createdSonata = StubBetterBagsModule("Sonata")

LoadBetterBagsModule("frames/menubutton.lua")
local menuButton = addon:GetModule("BagMenuButton")
local events = addon:GetModule("Events")

describe("BagMenuButton", function()
  local sent, shownMenu, registered, sorted, created, deposited, toggledSearch
  local savedFlags, savedGlobals

  -- Stubs this file made are removed, so a later spec file can load the real modules.
  teardown(function()
    if createdSonata then ResetModuleStub("Sonata") end
    if createdContextMenu then ResetModuleStub("ContextMenu") end
    ResetModuleStub("BagMenuButton", "frames/menubutton.lua")
  end)

  local function newBag(kind, bankTab)
    local bag = { kind = kind or const.BAG_KIND.BACKPACK, bankTab = bankTab, menuList = { "menu" } }
    bag.frame = CreateFrame("Frame", nil, UIParent)
    bag.frame:SetFrameLevel(500)
    function bag:Sort() sorted = sorted + 1 end
    function bag:CreateCategoryForItemInCursor() created = created + 1 end
    return bag
  end

  local function click(button, mouse)
    button:GetScript("OnClick")(button, mouse)
  end

  before_each(function()
    sent, registered = {}, {}
    sorted, created, toggledSearch = 0, 0, 0
    deposited = nil
    shownMenu = nil
    firstTime = false
    originals = {
      send = events.SendMessage,
      GetFirstTimeMenu = db.GetFirstTimeMenu,
      SetFirstTimeMenu = db.SetFirstTimeMenu,
      Show = contextMenu.Show,
      RegisterElement = sonata.RegisterElement,
    }
    events.SendMessage = function(_, _, message) table.insert(sent, message) end
    db.GetFirstTimeMenu = function() return firstTime end
    db.SetFirstTimeMenu = function(_, value) firstTime = value end
    contextMenu.Show = function(_, _, list) shownMenu = list end
    sonata.RegisterElement = function(_, kind, element) table.insert(registered, { kind, element }) end
    savedFlags = { isRetail = addon.isRetail, hasWarbank = addon.hasWarbank }
    savedGlobals = {
      IsShiftKeyDown = _G.IsShiftKeyDown, CursorHasItem = _G.CursorHasItem, GetCursorInfo = _G.GetCursorInfo,
      BetterBags_ToggleSearch = _G.BetterBags_ToggleSearch, C_Bank = _G.C_Bank,
    }
    _G.IsShiftKeyDown = function() return false end
    _G.CursorHasItem = function() return false end
    _G.GetCursorInfo = function() return nil end
    _G.BetterBags_ToggleSearch = function() toggledSearch = toggledSearch + 1 end
    _G.C_Bank = { AutoDepositItemsIntoBank = function(bankType) deposited = bankType end }
    addon.isRetail = true
    addon.hasWarbank = true
  end)

  after_each(function()
    events.SendMessage = originals.send
    db.GetFirstTimeMenu = originals.GetFirstTimeMenu
    db.SetFirstTimeMenu = originals.SetFirstTimeMenu
    contextMenu.Show = originals.Show
    sonata.RegisterElement = originals.RegisterElement
    for k, v in pairs(savedFlags) do addon[k] = v end
    for k, v in pairs(savedGlobals) do _G[k] = v end
  end)

  it("belongs to the bag's frame, with a portrait and a highlight, and is styled by Sonata", function()
    local bag = newBag()
    local button = menuButton:Create(bag)
    assert.are.equal(bag.frame, button:GetParent())
    assert.are.same({ 40, 40 }, { button:GetWidth(), button:GetHeight() })
    assert.are.equal("Interface\\Containerframe\\Bagslots2x", button.portrait:GetTexture())
    assert.are.equal("Interface\\Containerframe\\Bagslots2x", button.highlightTex:GetTexture())
    assert.are.equal(0, button.highlightTex:GetAlpha())
    assert.are.same({ "BagButton", button }, registered[1])
    assert.are.same({ "LeftButtonUp", "RightButtonUp" }, button._registeredClicks)
  end)

  it("sits where the theme's layout puts it, above the window's chrome", function()
    local bag = newBag()
    local button = menuButton:Create(bag)
    local overlay = CreateFrame("Frame", nil, bag.frame)
    overlay:SetFrameLevel(1000)
    menuButton:Place(button, { Points = { { Point = "TOPLEFT", X = -10, Y = 7 } } }, bag.frame, overlay)
    assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", -10, 7 }, { button:GetPoint(1) })
    assert.is_true(button:GetFrameLevel() > overlay:GetFrameLevel())
    assert.is_true(button:IsShown())
    menuButton:Place(button, false, bag.frame, overlay)
    assert.is_false(button:IsShown())
  end)

  describe("left click", function()
    it("opens the bag's menu", function()
      local bag = newBag()
      click(menuButton:Create(bag), "LeftButton")
      assert.are.equal(bag.menuList, shownMenu)
    end)

    it("toggles search with Shift", function()
      _G.IsShiftKeyDown = function() return true end
      click(menuButton:Create(newBag()), "LeftButton")
      assert.are.equal(1, toggledSearch)
      assert.is_nil(shownMenu)
    end)

    it("creates a category for the item on the cursor", function()
      _G.CursorHasItem = function() return true end
      _G.GetCursorInfo = function() return "item" end
      click(menuButton:Create(newBag()), "LeftButton")
      assert.are.equal(1, created)
      assert.is_nil(shownMenu)
    end)

    it("stops the first-time highlight once clicked", function()
      firstTime = true
      local button = menuButton:Create(newBag())
      assert.is_true(button.highlightAnimation:IsPlaying())
      click(button, "LeftButton")
      assert.is_false(firstTime)
      assert.are.equal("NONE", button.highlightAnimation._looping)
    end)
  end)

  describe("right click", function()
    it("sorts the backpack", function()
      click(menuButton:Create(newBag()), "RightButton")
      assert.are.equal(1, sorted)
    end)

    it("sorts the character bank, or the Warbank on a Warbank tab", function()
      local bag = newBag(const.BAG_KIND.BANK, 6)
      const.ACCOUNT_BANK_BAGS = { [12] = 12 }
      click(menuButton:Create(bag), "RightButton")
      assert.are.same({ "bags/SortBank" }, sent)
      bag.bankTab = 12
      click(menuButton:Create(bag), "RightButton")
      assert.are.equal("bags/SortWarbank", sent[2])
      assert.is_nil(deposited)
    end)

    it("deposits into the Warbank with Shift", function()
      _G.IsShiftKeyDown = function() return true end
      _G.Enum.BankType = _G.Enum.BankType or { Character = 0, Account = 2 }
      click(menuButton:Create(newBag(const.BAG_KIND.BANK, 6)), "RightButton")
      assert.are.equal(Enum.BankType.Account, deposited)
      assert.are.same({}, sent)
    end)

    it("always sorts the character bank without a Warbank (WoW: Forever)", function()
      addon.hasWarbank = false
      _G.IsShiftKeyDown = function() return true end
      click(menuButton:Create(newBag(const.BAG_KIND.BANK, 12)), "RightButton")
      assert.are.same({ "bags/SortBank" }, sent)
      assert.is_nil(deposited)
    end)

    it("is the Sort action the bag's action buttons share", function()
      const.ACCOUNT_BANK_BAGS = { [12] = 12 }
      menuButton:Sort({}, newBag())
      assert.are.equal(1, sorted)
      menuButton:Sort({}, newBag(const.BAG_KIND.BANK, 12))
      assert.are.same({ "bags/SortWarbank" }, sent)
    end)

    it("sorts through the bag on Classic", function()
      addon.isRetail = false
      click(menuButton:Create(newBag(const.BAG_KIND.BANK)), "RightButton")
      assert.are.equal(1, sorted)
    end)
  end)

  it("creates a category for an item dropped on it", function()
    local button = menuButton:Create(newBag())
    button:GetScript("OnReceiveDrag")(button)
    assert.are.equal(1, created)
  end)

  describe("tooltip", function()
    local lines, originalDouble, originalLine

    before_each(function()
      lines = {}
      originalDouble, originalLine = _G.GameTooltip.AddDoubleLine, _G.GameTooltip.AddLine
      _G.GameTooltip.AddDoubleLine = function(_, left, right) table.insert(lines, left .. " = " .. right) end
      _G.GameTooltip.AddLine = function(_, text) table.insert(lines, text) end
    end)

    after_each(function()
      _G.GameTooltip.AddDoubleLine, _G.GameTooltip.AddLine = originalDouble, originalLine
    end)

    it("lists the backpack's clicks", function()
      local button = menuButton:Create(newBag())
      button:GetScript("OnEnter")(button)
      assert.are.same({ "Left Click = Open Menu", "Shift Left Click = Search Bags", "Right Click = Sort Bags" }, lines)
      button:GetScript("OnLeave")(button)
      assert.are.equal(0, button.highlightTex:GetAlpha())
    end)

    it("lists the bank's clicks, the deposit only with a Warbank", function()
      local button = menuButton:Create(newBag(const.BAG_KIND.BANK))
      button:GetScript("OnEnter")(button)
      assert.are.same({ "Left Click = Open Menu", "Shift Left Click = Search Bags", "Right Click = Sort Bank",
        "Shift Right Click = Deposit Warbank Items" }, lines)
      lines = {}
      addon.hasWarbank = false
      button:GetScript("OnEnter")(button)
      assert.are.equal(3, #lines)
    end)

    it("says an item on the cursor can be dropped to make a category", function()
      _G.CursorHasItem = function() return true end
      _G.GetCursorInfo = function() return "item", 1, "[Thing]" end
      local button = menuButton:Create(newBag())
      button:GetScript("OnEnter")(button)
      assert.are.equal("Drop [Thing] here to create a new category for it.", lines[#lines])
    end)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)
