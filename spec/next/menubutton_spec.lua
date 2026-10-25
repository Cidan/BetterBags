-- menubutton_spec.lua -- NextMenuButton (next/menubutton.lua): a BetterBags Next panel's bag button, for a theme that
-- puts its header's row in a menu (Header.Buttons.Menu, next-themes.md §19; docs/next-plain-theme.md, round three). Asked:
-- "on plain, let's remove all top bar buttons ... let's bring back the drop down menu with these options, just like the
-- original bags ... just the options we are removing from the bar", the same on the bank and the vendor, and "vendors
-- should have their portrait for the bag button, not the bag texture".
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
-- The panels a button's own layers are for are named by their bag kinds (core/constants.lua), the kinds another
-- spec's Constants stub leaves out added for this one.
local const, createdConstants = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or {}
local addedKinds = {}
for name, kind in pairs({ UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = 2 }) do
  if const.BAG_KIND[name] == nil then
    const.BAG_KIND[name] = kind
    table.insert(addedKinds, name)
  end
end
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextOrnaments", "next/ornaments.lua" }, { "NextMenuButton", "next/menubutton.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local menuButton = addon:GetModule("NextMenuButton")
local tween = addon:GetModule("NextTween")
local contextMenu = StubBetterBagsModule("ContextMenu")

local BAGSLOTS = "Interface\\Containerframe\\Bagslots2x"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

describe("NextMenuButton", function()
  local shown, clicked, savedShow

  -- panelOn makes what the button reads of a panel: its frame, its body (filling it), its overlay, the screen side it
  -- belongs to, its kind, its header buttons (each with its spec) and its name.
  local function panelOn(side, kind)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(400, 600)
    local body = CreateFrame("Frame", nil, frame)
    body:SetAllPoints(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    local panel = { frame = frame, body = body, overlay = overlay, side = side, kind = kind or 0, headerButtons = {},
      label = "Backpack" }
    local function add(spec)
      local button = CreateFrame("Button", nil, frame)
      button.key, button.spec = spec.key, spec
      button:Show()
      table.insert(panel.headerButtons, button)
      panel[spec.key] = button
      return button
    end
    add({ key = "closeButton", tooltip = "Close", onClick = function() table.insert(clicked, "close") end })
    add({ key = "settingsButton", tooltip = "Open Options Screen", menuLast = true,
      onClick = function() table.insert(clicked, "settings") end })
    add({ key = "sortButton", tooltip = "Sort Bags", onClick = function() table.insert(clicked, "sort") end })
    add({ key = "sizeButton", label = "Small Bags", tooltipFunc = function() end,
      checked = function() return panel.small == true end, menuTooltip = function() return "Smaller bags." end,
      onClick = function() table.insert(clicked, "size") end })
    panel.menuButton = menuButton:Create(panel)
    return panel
  end

  local function bag()
    return { Texture = BAGSLOTS, TexCoords = { 0, 0.2, 0, 1 }, Inset = { Left = -2, Top = -2, Right = -6, Bottom = -18 } }
  end

  local function theme(extra)
    local menu = { Point = "TOPINNER", X = -12, Y = -15, Width = 40, Height = 40, Layers = { bag() },
      Highlight = { Texture = BAGSLOTS, TexCoords = { 0.2, 0.3992, 0, 1 }, Inset = { Left = 0, Top = -2, Right = -8, Bottom = -18 } },
      Panels = { Vendor = { Layers = {
        { Color = { 0, 0, 0, 1 }, Inset = { Left = 4, Top = 4, Right = 4, Bottom = 4 }, Mask = { Texture = MASK } },
        { Unit = "npc", Inset = { Left = 4, Top = 4, Right = 4, Bottom = 4 }, Mask = { Texture = MASK } },
        { Texture = BAGSLOTS, TexCoords = { 0.578125, 0.689453125, 0.0234375, 0.46875 },
          Inset = { Left = 0, Top = 1, Right = -3, Bottom = -4 } },
      } } } }
    for k, v in pairs(extra or {}) do
      menu[k] = v
    end
    UseNextTheme({ Header = { Buttons = { Menu = menu, Pinned = { closeButton = { Point = "TOPOUTER", X = 1, Y = 0 } } } } })
  end

  -- coords reads a texture's coordinates as left, right, top and bottom (GetTexCoord gives its four corners).
  local function coords(t)
    local c = { t:GetTexCoord() }
    return { c[1], c[5], c[2], c[4] }
  end

  local function points(region)
    local out = {}
    for i = 1, region:GetNumPoints() do
      local point, rel, relPoint, x, y = region:GetPoint(i)
      out[i] = { point, rel, relPoint, x, y }
    end
    return out
  end

  before_each(function()
    shown, clicked = nil, {}
    savedShow = rawget(contextMenu, "Show")
    contextMenu.Show = function(_, _, list) shown = list end
    tween:Init()
    MockUnits.npc = nil
  end)

  after_each(function()
    contextMenu.Show = savedShow
    UseNextTheme(nil)
    MockUnits.npc = nil
  end)

  it("is hidden and takes no room for a theme without a menu button", function()
    local panel = panelOn("RIGHT")
    panel.menuButton:Style()
    assert.is_false(panel.menuButton.frame:IsShown())
    assert.are.equal(0, panel.menuButton:Room())
  end)

  it("sits at its corner by whole pixels, X toward the middle and Y down, mirrored on a panel on the left", function()
    theme()
    local right, left = panelOn("RIGHT"), panelOn("LEFT", 1)
    right.menuButton:Style()
    left.menuButton:Style()
    assert.is_true(right.menuButton.frame:IsShown())
    assert.are.same({ { "TOPLEFT", right.body, "TOPLEFT", -12, 15 } }, points(right.menuButton.frame))
    assert.are.same({ { "TOPRIGHT", left.body, "TOPRIGHT", 12, 15 } }, points(left.menuButton.frame))
    assert.are.same({ 40, 40 }, { right.menuButton.frame:GetSize() })
    -- Over the panel's frame drawn above its content (Panel.Frame.Above).
    assert.is_true(right.menuButton.frame:GetFrameLevel() > right.overlay:GetFrameLevel())
  end)

  it("takes the room from the body's inner side to its far edge, for the title", function()
    theme()
    assert.are.equal(28, panelOn("RIGHT").menuButton:Room())
  end)

  it("draws its layers in order, inset into it, never flipped", function()
    theme()
    for _, side in ipairs({ "RIGHT", "LEFT" }) do
      local panel = panelOn(side, side == "LEFT" and 1 or 0)
      panel.menuButton:Style()
      local face = panel.menuButton.layers[1]
      assert.is_true(face:IsShown())
      assert.are.equal(BAGSLOTS, face:GetTexture())
      assert.are.same({ 0, 0.2, 0, 1 }, coords(face), side)
      assert.are.same({ { "TOPLEFT", panel.menuButton.frame, "TOPLEFT", -2, 2 },
        { "BOTTOMRIGHT", panel.menuButton.frame, "BOTTOMRIGHT", 6, -18 } }, points(face), side)
    end
  end)

  it("draws the layers its theme gives its panel: the vendor's portrait, masked round, over a dark disc, in a ring", function()
    theme()
    local vendor = panelOn("LEFT", -1)
    vendor.menuButton:Style()
    local disc, portrait, ring = vendor.menuButton.layers[1], vendor.menuButton.layers[2], vendor.menuButton.layers[3]
    local c = disc._colorTexture
    assert.are.same({ 0, 0, 0, 1 }, { c.r, c.g, c.b, c.a }, "a layer naming only a color is filled with it")
    assert.are.equal(MASK, vendor.menuButton.masks[1]:GetTexture())
    assert.is_nil(portrait._portraitUnit, "no portrait while there is no vendor")
    MockUnits.npc = true
    vendor.menuButton:Paint()
    assert.are.equal("npc", portrait._portraitUnit)
    assert.are.equal(MASK, vendor.menuButton.masks[2]:GetTexture())
    assert.are.same({ 0.578125, 0.689453125, 0.0234375, 0.46875 }, coords(ring))
    -- The ring draws over the portrait.
    local _, portraitLevel = portrait:GetDrawLayer()
    local _, ringLevel = ring:GetDrawLayer()
    assert.is_true(ringLevel > portraitLevel)
    local backpack = panelOn("RIGHT")
    backpack.menuButton:Style()
    assert.are.equal(BAGSLOTS, backpack.menuButton.layers[1]:GetTexture(), "the bag on every other panel")
    -- A theme without the vendor's own: the bag, its portrait's layers and masks put away.
    UseNextTheme({ Header = { Buttons = { Menu = { Point = "TOPINNER", Width = 40, Height = 40, Layers = { bag() } } } } })
    vendor.menuButton:Style()
    assert.are.equal(BAGSLOTS, disc:GetTexture())
    assert.is_false(portrait:IsShown() or ring:IsShown())
    assert.is_false(vendor.menuButton.masks[1]:IsShown() or vendor.menuButton.masks[2]:IsShown())
  end)

  it("lights its highlight over its layers under the pointer", function()
    theme()
    local panel = panelOn("RIGHT")
    panel.menuButton:Style()
    local glow = panel.menuButton.highlight
    assert.are.equal(0, glow:GetAlpha())
    assert.are.same({ 0.2, 0.3992, 0, 1 }, coords(glow))
    assert.are.equal("OVERLAY", (glow:GetDrawLayer()))
    panel.menuButton.frame:GetScript("OnEnter")(panel.menuButton.frame)
    tween:Step(1)
    assert.are.equal(1, glow:GetAlpha())
    panel.menuButton.frame:GetScript("OnLeave")(panel.menuButton.frame)
    tween:Step(1)
    assert.are.equal(0, glow:GetAlpha())
  end)

  describe("its menu", function()
    local function open(panel)
      panel.menuButton.frame:GetScript("OnClick")(panel.menuButton.frame, "LeftButton")
      return shown
    end

    it("opens the original bags' menu with the header buttons not pinned, in order, Open Options Screen last", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.menuButton:Style()
      local list = open(panel)
      assert.is_true(list[1].isTitle)
      local names = {}
      for i = 2, #list do
        names[i - 1] = list[i].text
      end
      assert.are.same({ "Sort Bags", "Small Bags", "Open Options Screen" }, names)
    end)

    it("checks its toggles, disables what its buttons do, and gives each its tooltip", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.small = true
      panel.sortButton:SetEnabled(false)
      panel.menuButton:Style()
      local list = open(panel)
      local sort, size = list[2], list[3]
      assert.is_true(sort.notCheckable)
      assert.is_true(sort.disabled)
      assert.is_true(sort.tooltipWhileDisabled)
      assert.is_false(size.notCheckable)
      assert.is_true(size.checked())
      assert.is_true(size.tooltipOnButton)
      assert.are.equal("Small Bags", size.tooltipTitle)
      assert.are.equal("Smaller bags.", size.tooltipText)
    end)

    it("runs a button's action from its entry", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.menuButton:Style()
      open(panel)[3].func()
      assert.are.same({ "size" }, clicked)
    end)

    it("leaves out the buttons its panel does not show", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.sortButton:Hide()
      panel.menuButton:Style()
      local list = open(panel)
      assert.are.equal(3, #list)
      assert.are.equal("Small Bags", list[2].text)
    end)
  end)

  teardown(function()
    for _, name in ipairs(addedKinds) do const.BAG_KIND[name] = nil end
    if createdConstants then ResetModuleStub("Constants") end
  end)
end)
