-- uipanels_spec.lua -- NextUIPanels (next/uipanels.lua): Blizzard's UI panels (the Character pane, the Dressing Room,
-- the Friends list...) open beside BetterBags Next's panels docked at the left edge of the screen, never under them.
-- Reported: the Character pane moved over by the width of Blizzard's merchant frame, not the vendor's (#1247); the
-- Dressing Room opened behind the vendor (#1282). Run against each client's own panel manager, from Blizzard's UI
-- source (spec/helpers/uipanels.lua), with stand-in panels in the real chain (next/chain.lua).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local uiSource = dofile("spec/helpers/ui_source.lua")
local blizzard = dofile("spec/helpers/uipanels.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local stubs = {
  L = trackStub("Localization"),
  database = trackStub("Database"),
  events = trackStub("Events"),
}

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

local modules = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" }, { "NextChain", "next/chain.lua" },
  { "NextUIPanels", "next/uipanels.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local style = addon:GetModule("NextStyle")
local chain = addon:GetModule("NextChain")
local uiPanels = addon:GetModule("NextUIPanels")

local SCREEN = 1920

-- Blizzard's panels, at the sizes their XML gives them (retail): the merchant frame (MerchantFrame.xml), the Character
-- pane (ButtonFrameTemplate at PANEL_DEFAULT_WIDTH, Constants.lua), the Dressing Room (DressUpFrames.xml), the Friends
-- list (FriendsFrame.xml), the bank and the guild bank (their UIPanelWindows widths stand for their frames').
local SIZES = {
  MerchantFrame = { 336, 444 }, CharacterFrame = { 338, 424 }, DressUpFrame = { 450, 545 }, FriendsFrame = { 385, 424 },
  BankFrame = { 425, 440 }, GuildBankFrame = { 793, 440 },
  -- Wide ones: the landing page (Blizzard_ExpansionLandingPage.xml), the guild and communities window (CommunitiesFrame.xml).
  ExpansionLandingPage = { 910, 670 }, CommunitiesFrame = { 814, 426 },
}

-- Each client's guild bank registers itself as its load-on-demand addon loads.
local GUILD_BANK = {
  Retail = "Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua",
  Forever = "Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua",
  Anniversary = "Interface/AddOns/Blizzard_GuildBankUI/TBC/Blizzard_GuildBankUI.lua",
  Mists = "Interface/AddOns/Blizzard_GuildBankUI/TBC/Blizzard_GuildBankUI.lua",
}

-- A classic client's Character pane registers itself in its own addon, by game type (Blizzard_CharacterFrame.toc);
-- retail's is in the manager's UIPanelWindows.lua.
local CHARACTER = {
  Era = "Interface/AddOns/Blizzard_CharacterFrame/Vanilla/CharacterFrame.lua",
  Anniversary = "Interface/AddOns/Blizzard_CharacterFrame/TBC/CharacterFrame.lua",
  Mists = "Interface/AddOns/Blizzard_CharacterFrame/Cata/CharacterFrame.lua",
}

describe("NextUIPanels", function()
  local layout, tabWidth, backpack, vendor, bank, guild, putBack

  -- A panel as the chain sees it: its frame shown while open, its size, its tab rail's width, the edge it faces from,
  -- and the frame of Blizzard's it stands in for.
  local function panel(role, side, standIn)
    local p = { frame = CreateFrame("Frame"), size = "full", closing = false, waiting = false, side = side,
      standIn = standIn, tabs = { Width = function() return tabWidth end } }
    p.frame:Hide()
    function p:Outward() return self.side == "LEFT" and 1 or -1 end
    function p:IsSmall() return self.size == "small" end
    chain:Register(p, role)
    return p
  end

  local function open(p)
    p.frame:Show()
    p.closing = false
    uiPanels:Update()
  end

  local function close(p)
    p.closing = true
    uiPanels:Update()
    p.frame:Hide()
    p.closing = false
    uiPanels:Update()
  end

  local function blizzardFrame(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(SIZES[name][1], SIZES[name][2])
    f:Hide()
    override(_G, name, f)
    return f
  end

  -- How far a docked companion's tab rail, with its hover slide, or its feather reaches past its body.
  local function reach()
    return math.max(style.FEATHER, style.RAIL_OUT + tabWidth + style.TAB_HOVER)
  end

  -- nextFrame runs what NextUIPanels left for the next frame (its driver's OnUpdate): placing Blizzard's panels again
  -- once the manager has laid them out.
  local function nextFrame()
    local driver = uiPanels.driver
    local update = driver and driver:GetScript("OnUpdate")
    if update then update(driver, 1 / 60) end
  end

  -- Where a panel's right edge is, in UIParent's units.
  local function right(frame)
    return blizzard.Left(frame) + GetUIPanelWidth(frame)
  end

  local function leftOffset()
    if rawget(_G, "GetUIPanelLayoutAttribute") then
      return GetUIPanelLayoutAttribute("LEFT_OFFSET")
    end
    return UIParent:GetAttribute("LEFT_OFFSET")
  end

  local function setup(client)
    putBack = blizzard.Load(client)
    UIParent:_SetRect(0, 0, SCREEN, 1200)
    if GUILD_BANK[client] then
      blizzard.Register(client, GUILD_BANK[client], "GuildBankFrame")
    end
    if CHARACTER[client] then
      blizzard.Register(client, CHARACTER[client], "CharacterFrame")
    end
    for name in pairs(SIZES) do
      blizzardFrame(name)
    end
    chain:Init()
    uiPanels:Init()
    backpack = panel("backpack", "RIGHT")
    vendor = panel("companion", "LEFT", "MerchantFrame")
    bank = panel("companion", "LEFT", "BankFrame")
    guild = panel("companion", "LEFT", "GuildBankFrame")
  end

  before_each(function()
    -- Tabs that reach past the feather (96 in the Default theme, with a hover slide of 6).
    layout, tabWidth = "apart", 120
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.database, "GetNextChain", function() return layout end)
    override(stubs.events, "RegisterEvent", function() end)
    override(stubs.events, "RegisterMessage", function() end)
  end)

  after_each(function()
    for _, p in ipairs({ vendor, bank, guild, backpack }) do
      if p and p.frame:IsShown() then close(p) end
    end
    if putBack then putBack() end
    putBack = nil
    restore()
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  it("can be checked: the UI source has every client's branch", function()
    local available, why = uiSource.Available()
    assert.is_true(available, why)
  end)

  describe("on retail", function()
    before_each(function() setup("Retail") end)

    it("opens the Character pane past the vendor's tabs, and their hover slide (#1247)", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(style.BODY_WIDTH + style.RAIL_OUT + tabWidth + style.TAB_HOVER + 16, blizzard.Left(CharacterFrame))
    end)

    it("keeps clear of the vendor's feather when its tabs are narrower", function()
      tabWidth = 10
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(style.BODY_WIDTH + style.FEATHER + 16, blizzard.Left(CharacterFrame))
    end)

    -- A theme whose header buttons go down a rail standing outside the body (GW2, Header.Buttons.Rail.Outside): the tabs
    -- hang past it.
    it("keeps clear of a header rail standing outside the vendor's body, and the tabs past it", function()
      override(style, "RAIL_OUT", 40)
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(style.BODY_WIDTH + 40 + tabWidth + style.TAB_HOVER + 16, blizzard.Left(CharacterFrame))
    end)

    it("moves a pane open before the vendor beside it as the vendor opens", function()
      ShowUIPanel(CharacterFrame)
      assert.are.equal(16, blizzard.Left(CharacterFrame))
      ShowUIPanel(MerchantFrame)
      open(vendor)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
    end)

    it("opens the Dressing Room beside the vendor, not behind it (#1282)", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(DressUpFrame)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame))
      ShowUIPanel(CharacterFrame)
      -- Both beside the vendor, the merchant frame taking no room between them: the Character pane ranks after the
      -- Dressing Room (pushable 3 to its 2, UIPanelWindows.lua).
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame))
      assert.are.equal(style.BODY_WIDTH + reach() + 16 + 450 + 32, blizzard.Left(CharacterFrame))
    end)

    it("follows the vendor's tabs as they change", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      tabWidth = 140
      uiPanels:Update()
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
    end)

    it("opens panels beside the bank, which Blizzard's manager puts after the Character pane", function()
      ShowUIPanel(BankFrame)
      open(bank)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
      assert.are.equal("CharacterFrame", GetUIPanel("left"):GetName())
    end)

    it("opens a panel that takes the bank frame's place beside the bank", function()
      ShowUIPanel(BankFrame)
      open(bank)
      ShowUIPanel(FriendsFrame)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(FriendsFrame))
    end)

    it("opens panels beside the guild bank, which Blizzard lays out across two places", function()
      ShowUIPanel(GuildBankFrame)
      open(guild)
      ShowUIPanel(CharacterFrame)
      assert.are.equal("GuildBankFrame", GetUIPanel("doublewide"):GetName())
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
    end)

    it("opens panels past the backpack chained beside the vendor, and its far feather", function()
      layout = "left"
      ShowUIPanel(MerchantFrame)
      open(backpack)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      local room = 2 * style.BODY_WIDTH + chain:Gap(vendor, backpack) + style.Chain.OuterFeather
      assert.are.equal(room + 16, blizzard.Left(CharacterFrame))
    end)

    it("leaves the left edge to Blizzard's panels when the vendor is chained beside the backpack on the right", function()
      layout = "right"
      ShowUIPanel(MerchantFrame)
      open(backpack)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(16, blizzard.Left(CharacterFrame))
      assert.are.equal(16, leftOffset())
    end)

    it("leaves the left edge to them while a vendor chained on the right waits for the backpack", function()
      layout = "right"
      ShowUIPanel(MerchantFrame)
      vendor.waiting = true
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(16, blizzard.Left(CharacterFrame))
    end)

    it("lays them out as beside Blizzard's merchant frame while the vendor is small", function()
      vendor.size = "small"
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(16 + 336 + 32, blizzard.Left(CharacterFrame))
      assert.is_nil(MerchantFrame:GetAttribute("UIPanelLayout-width"))
    end)

    it("gives Blizzard's layout back as the vendor closes", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are_not.equal(80, GetUIPanelLayoutAttribute("RIGHT_OFFSET_BUFFER"), "moved with the left edge")
      vendor.closing = true
      uiPanels:Update()
      assert.are.equal(16, leftOffset())
      assert.are.equal(80, GetUIPanelLayoutAttribute("RIGHT_OFFSET_BUFFER"))
      assert.is_nil(MerchantFrame:GetAttribute("UIPanelLayout-width"), "the merchant frame's own width")
      -- Blizzard's merchant code hides its frame as the visit ends (MerchantFrame_MerchantClosed).
      HideUIPanel(MerchantFrame)
      assert.are.equal(16, blizzard.Left(CharacterFrame))
    end)

    it("gives a stand-in back the width Blizzard registered for it", function()
      ShowUIPanel(BankFrame)
      open(bank)
      assert.are_not.equal(425, BankFrame:GetAttribute("UIPanelLayout-width"))
      close(bank)
      assert.are.equal(425, BankFrame:GetAttribute("UIPanelLayout-width"))
    end)

    it("moves the layout back from where it found it", function()
      SetUIPanelLayoutAttribute("LEFT_OFFSET", 40)
      open(vendor)
      assert.are.equal(style.BODY_WIDTH + reach() + 40, leftOffset())
      close(vendor)
      assert.are.equal(40, leftOffset())
    end)

    it("lays Blizzard's panels out again only when where they go changes", function()
      ShowUIPanel(MerchantFrame)
      local updates = 0
      local update = UpdateUIPanelPositions
      override(_G, "UpdateUIPanelPositions", function(...)
        updates = updates + 1
        return update(...)
      end)
      assert.are.equal("same", uiPanels:Update())
      assert.are.equal(0, updates)
      open(vendor)
      local placed = updates
      assert.is_true(placed > 0)
      assert.are.equal("same", uiPanels:Update())
      -- The layout BetterBags Next asked for leaves a place for the next frame, which finds nothing to move.
      assert.are.equal("same", uiPanels:Place())
      nextFrame()
      assert.are.equal(placed, updates)
      tabWidth = 150
      assert.are.equal("placed", uiPanels:Update())
      assert.is_true(updates > placed)
    end)

    it("hands the stand-in over when another companion opens as one closes", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      -- The visit ends: the vendor slides out as Blizzard hides its merchant frame (MerchantFrame_MerchantClosed).
      vendor.closing = true
      HideUIPanel(MerchantFrame)
      ShowUIPanel(BankFrame)
      open(bank)
      assert.is_nil(MerchantFrame:GetAttribute("UIPanelLayout-width"))
      assert.are_not.equal(425, BankFrame:GetAttribute("UIPanelLayout-width"))
      ShowUIPanel(CharacterFrame)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
    end)
  end)

  -- Where the screen has no room for a panel past BetterBags Next, Blizzard's manager keeps the panels it keeps beside
  -- nothing at the left (its frames take no room), and they move only as far past it as the screen allows: never the
  -- vendor or the bank's frame closed, never a panel off the screen. Found by the bug review: told the whole room, the
  -- manager closed the merchant frame (ending the visit) and dropped the bank's for panels that no longer fitted beside
  -- it, and placed wide ones past the screen's edge. UI scale 1 on a 16:9 screen is about 1366 across.
  describe("on a narrow screen", function()
    local WIDE = 1366

    before_each(function()
      setup("Retail")
      UIParent:_SetRect(0, 0, WIDE, 768)
    end)

    it("keeps the vendor chained left open as the Character pane opens, the pane as far right as the screen allows", function()
      layout = "left"
      ShowUIPanel(MerchantFrame)
      open(backpack)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      nextFrame()
      assert.is_true(MerchantFrame:IsShown(), "the visit goes on")
      assert.are.equal(MerchantFrame, GetUIPanel("left"))
      assert.are.equal(WIDE - 16 - 338, blizzard.Left(CharacterFrame))
    end)

    it("keeps the vendor open as the landing page opens, past it as far as the screen allows", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(ExpansionLandingPage)
      nextFrame()
      assert.is_true(MerchantFrame:IsShown(), "the visit goes on")
      assert.are.equal(WIDE - 16 - 910, blizzard.Left(ExpansionLandingPage))
    end)

    it("keeps the bank's frame as a wide panel takes the left, on the screen", function()
      ShowUIPanel(BankFrame)
      open(bank)
      ShowUIPanel(CommunitiesFrame)
      nextFrame()
      assert.is_true(BankFrame:IsShown(), "the bank frame stays")
      assert.are.equal(WIDE - 16, right(CommunitiesFrame))
    end)

    it("keeps the Dressing Room open as the Character pane opens beside the vendor", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(DressUpFrame)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame), "past the vendor while it fits")
      ShowUIPanel(CharacterFrame)
      nextFrame()
      assert.is_true(DressUpFrame:IsShown() and CharacterFrame:IsShown() and MerchantFrame:IsShown())
      assert.are.equal(WIDE - 16, right(CharacterFrame))
      assert.are.equal(WIDE - 16 - 338 - 32 - 450, blizzard.Left(DressUpFrame))
    end)

    it("moves the panels back past the vendor as room frees up", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(DressUpFrame)
      ShowUIPanel(CharacterFrame)
      nextFrame()
      HideUIPanel(DressUpFrame)
      nextFrame()
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
    end)

    -- Found by the second bug review: how far they move depends on the screen's width, and a screen that changed moved
    -- nothing (the room, in UIParent's units, and the stand-in stay the same; NextChain:Update runs on UI_SCALE_CHANGED
    -- and DISPLAY_SIZE_CHANGED).
    it("moves them again as the screen narrows, and back as it widens", function()
      UIParent:_SetRect(0, 0, 1920, 768)
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(DressUpFrame)
      ShowUIPanel(CharacterFrame)
      nextFrame()
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame))
      UIParent:_SetRect(0, 0, WIDE, 768)
      uiPanels:Update()
      assert.are.equal(WIDE - 16, right(CharacterFrame), "on the narrower screen")
      UIParent:_SetRect(0, 0, 1920, 768)
      uiPanels:Update()
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame), "past the vendor again")
    end)

    -- Found by the second bug review: Blizzard scales every open panel to fit the screen as the UI scale changes
    -- (UpdateScaleForFitForOpenPanels, GameEvent.HandleUiScaleChanged) by the screen's width over its width in the layout;
    -- the stand-in's, taking no room, gave it a negative scale and closed the panels beside it.
    it("leaves the stand-in at its own scale as Blizzard scales its panels to fit the screen", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(DressUpFrame)
      ShowUIPanel(CharacterFrame)
      nextFrame()
      UpdateScaleForFitForOpenPanels()
      assert.are.equal(1, MerchantFrame:GetScale())
      assert.is_true(DressUpFrame:IsShown() and CharacterFrame:IsShown() and MerchantFrame:IsShown())
      close(vendor)
      assert.is_nil(MerchantFrame:GetAttribute("UIPanelLayout-checkFitExtraWidth"), "given back")
    end)

    it("moves two panels side by side only as far as both fit", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CommunitiesFrame)
      ShowUIPanel(CharacterFrame)
      nextFrame()
      assert.is_true(CommunitiesFrame:IsShown() and CharacterFrame:IsShown() and MerchantFrame:IsShown())
      assert.are.equal(WIDE - 16, right(CharacterFrame))
      assert.are.equal(WIDE - 16 - 338 - 32 - 814, blizzard.Left(CommunitiesFrame))
    end)
  end)

  describe("on WoW: Forever", function()
    before_each(function() setup("Forever") end)

    it("opens the Character pane beside the vendor", function()
      ShowUIPanel(MerchantFrame)
      open(vendor)
      ShowUIPanel(CharacterFrame)
      assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(CharacterFrame))
    end)
  end)

  -- A classic client keeps its layout in UIParent's attributes (UIParent.xml), and its bank and guild bank frames sit
  -- 16 left of their place (xoffset -16, UIPanelWindows.lua, Blizzard_GuildBankUI.lua).
  for _, client in ipairs({ "Era", "Anniversary", "Mists" }) do
    describe("on " .. client, function()
      before_each(function() setup(client) end)

      it("opens the Dressing Room beside the vendor, and gives the layout back as it closes", function()
        ShowUIPanel(MerchantFrame)
        open(vendor)
        ShowUIPanel(DressUpFrame)
        assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame))
        close(vendor)
        assert.are.equal(16, UIParent:GetAttribute("LEFT_OFFSET"))
        assert.is_nil(MerchantFrame:GetAttribute("UIPanelLayout-width"))
      end)

      -- A 4:3 screen at UI scale 1 is 1024 across: the Dressing Room does not fit past the vendor.
      it("keeps the vendor open as the Dressing Room opens on a narrow screen, on the screen", function()
        UIParent:_SetRect(0, 0, 1024, 768)
        ShowUIPanel(MerchantFrame)
        open(vendor)
        ShowUIPanel(DressUpFrame)
        nextFrame()
        assert.is_true(MerchantFrame:IsShown())
        assert.are.equal(1024 - 16 - 450, blizzard.Left(DressUpFrame))
      end)

      -- Found by the second bug review: a classic client lays the panels out as each of UIParent's layout attributes is
      -- set (UpdateUIPanelPositions.lua), so moving LEFT_OFFSET before RIGHT_OFFSET_BUFFER asked whether the panels fit
      -- with only one of them moved, and the manager closed the Character pane and the bank's frame.
      for _, which in ipairs({ "vendor", "bank" }) do
        it("keeps the panels open as the " .. which .. " opens beside them on a narrow screen", function()
          UIParent:_SetRect(0, 0, 1366, 768)
          ShowUIPanel(DressUpFrame)
          ShowUIPanel(CharacterFrame)
          local frame = which == "vendor" and MerchantFrame or BankFrame
          ShowUIPanel(frame)
          open(which == "vendor" and vendor or bank)
          nextFrame()
          assert.is_true(frame:IsShown(), "Blizzard's frame stays")
          assert.is_true(DressUpFrame:IsShown() and CharacterFrame:IsShown(), "the panels stay")
          assert.is_true(blizzard.Left(DressUpFrame) >= 16 and right(CharacterFrame) <= 1366 - 16)
        end)
      end

      -- The other way (found by the third bug review, untested until then): as the panels move back, LEFT_OFFSET goes
      -- first. A wide panel opening beside the bank on a 4:3 screen moves them back, and the bank's frame stays.
      it("keeps the bank's frame as a wide panel opens beside the bank and moves the panels back", function()
        UIParent:_SetRect(0, 0, 1024, 768)
        ShowUIPanel(BankFrame)
        open(bank)
        ShowUIPanel(CommunitiesFrame)
        nextFrame()
        assert.is_true(BankFrame:IsShown(), "the bank frame stays")
        assert.is_true(CommunitiesFrame:IsShown())
      end)

      it("opens the Dressing Room beside the bank", function()
        ShowUIPanel(BankFrame)
        open(bank)
        ShowUIPanel(DressUpFrame)
        assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame))
        close(bank)
        assert.are.equal(353, BankFrame:GetAttribute("UIPanelLayout-width"))
      end)

      if GUILD_BANK[client] then
        it("opens the Dressing Room beside the guild bank", function()
          ShowUIPanel(GuildBankFrame)
          open(guild)
          ShowUIPanel(DressUpFrame)
          assert.are.equal(style.BODY_WIDTH + reach() + 16, blizzard.Left(DressUpFrame))
        end)
      end
    end)
  end
end)
