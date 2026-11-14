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
local picker, createdPicker = StubBetterBagsModule("NextCategoryPicker")

local BAGSLOTS = "Interface\\Containerframe\\Bagslots2x"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

describe("NextMenuButton", function()
  local shown, clicked, savedShow, picks, hints, savedHint

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
    -- What a right click on it does and its name (NextPanel:OnTitleRightClick, TitleRightClickLabel: none here unless a spec
    -- gives one), and the entries its menu adds after its row (NextPanel:MenuEntries).
    function panel:OnTitleRightClick(c)
      assert.is_not_nil(c)
      table.insert(clicked, "right")
    end
    function panel:TitleRightClickLabel() return panel.rightLabel end
    function panel:MenuEntries() return panel.menuEntries or {} end
    -- Where the theme takes an item dropped to file it (NextPanel:ItemDropTarget), and the picker it opens there.
    function panel:ItemDropTarget() return panel.dropTarget end
    function panel:PickCategory(c, anchor)
      assert.is_not_nil(c)
      table.insert(picks, anchor)
      return "picking"
    end
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
    shown, clicked, picks, hints = nil, {}, {}, {}
    savedShow = rawget(contextMenu, "Show")
    contextMenu.Show = function(_, _, list) shown = list end
    savedHint = rawget(picker, "Hint")
    picker.Hint = function(_, owner, point) table.insert(hints, { owner, point }) end
    tween:Init()
    MockUnits.npc = nil
  end)

  after_each(function()
    contextMenu.Show = savedShow
    picker.Hint = savedHint
    UseNextTheme(nil)
    MockUnits.npc = nil
    _G._cursorHasItem, _G._cursorType, _G._cursorItemID = false, nil, nil
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

    -- What only the menu offers (asked: "add the missing button interactions to the plain drop down menu"): a panel's sort,
    -- the switch to small bags on a panel with no size button of its own.
    it("lists its panel's own entries after its row, Open Options Screen still last", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.menuEntries = {
        { label = "Clean Up", onClick = function(c) assert.is_not_nil(c); table.insert(clicked, "clean up") end },
        { label = "Tiny Bags", checked = function() return true end, menuTooltip = function() return "Smaller." end,
          onClick = function() table.insert(clicked, "tiny") end },
      }
      panel.menuButton:Style()
      local list = open(panel)
      local names = {}
      for i = 2, #list do
        names[i - 1] = list[i].text
      end
      assert.are.same({ "Sort Bags", "Small Bags", "Clean Up", "Tiny Bags", "Open Options Screen" }, names)
      local clean, tiny = list[4], list[5]
      assert.is_true(clean.notCheckable)
      assert.is_false(clean.disabled)
      assert.is_nil(clean.tooltipText)
      assert.is_false(tiny.notCheckable)
      assert.is_true(tiny.checked())
      assert.are.equal("Smaller.", tiny.tooltipText)
      clean.func()
      tiny.func()
      assert.are.same({ "clean up", "tiny" }, clicked)
    end)
  end)

  -- The original bags' button sorted on a right click (frames/menubutton.lua; reported of Plain: "right clicking the bag button
  -- on plain doesn't seem to sort bags like it does on the other themes", where the title's right click sorts).
  describe("a right click", function()
    it("does what a right click on its panel's title does, its menu closed, and says what that is", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.rightLabel = "Sort Bags"
      panel.menuButton:Style()
      local frame = panel.menuButton.frame
      assert.are.same({ "LeftButtonUp", "RightButtonUp" }, frame._registeredClicks)
      frame:GetScript("OnClick")(frame, "RightButton")
      assert.are.same({ "right" }, clicked)
      assert.is_nil(shown, "its menu stays closed")
      frame:GetScript("OnEnter")(frame)
      assert.are.same({ { "Left Click", "Open Menu" }, { "Right Click", "Sort Bags" } },
        { { GameTooltip.doubleLines[1].left, GameTooltip.doubleLines[1].right },
          { GameTooltip.doubleLines[2].left, GameTooltip.doubleLines[2].right } })
      frame:GetScript("OnLeave")(frame)
    end)

    it("says nothing of a right click its panel does nothing on", function()
      theme()
      local panel = panelOn("LEFT", -1)
      panel.menuButton:Style()
      local frame = panel.menuButton.frame
      frame:GetScript("OnEnter")(frame)
      assert.are.equal(1, #GameTooltip.doubleLines)
      frame:GetScript("OnLeave")(frame)
    end)
  end)

  -- Issue #1270: in a theme that takes an item dropped to file it on the bag button (Header.ItemDrop, Plain), the
  -- button opens the category picker for an item dropped or clicked on it (asked: "drag an item to the bag name (or in the
  -- case of Plain, the bag button ...)").
  describe("an item dropped on it", function()
    local function hold()
      _G._cursorHasItem, _G._cursorType, _G._cursorItemID = true, "item", 501
    end

    it("opens the category picker under it for an item dropped or clicked on it, where the theme takes it there", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.dropTarget = "Menu"
      panel.menuButton:Style()
      local frame = panel.menuButton.frame
      hold()
      frame:GetScript("OnReceiveDrag")(frame)
      assert.are.same({ frame }, picks)
      frame:GetScript("OnClick")(frame, "LeftButton")
      assert.are.same({ frame, frame }, picks)
      assert.is_nil(shown, "its menu stays closed")
    end)

    it("opens its menu as before where the theme takes an item elsewhere, or with nothing held", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.dropTarget = "Title"
      panel.menuButton:Style()
      local frame = panel.menuButton.frame
      hold()
      frame:GetScript("OnReceiveDrag")(frame)
      assert.are.same({}, picks)
      frame:GetScript("OnClick")(frame, "LeftButton")
      assert.is_not_nil(shown)
      panel.dropTarget = "Menu"
      shown = nil
      ClearCursor()
      frame:GetScript("OnClick")(frame, "LeftButton")
      assert.is_not_nil(shown)
      assert.are.same({}, picks)
    end)

    it("opens its menu, and says what a click does, while what is held is not an item of yours", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.dropTarget = "Menu"
      panel.menuButton:Style()
      local frame = panel.menuButton.frame
      _G._cursorHasItem, _G._cursorType, _G._cursorItemID = true, "merchant", 3
      frame:GetScript("OnEnter")(frame)
      assert.are.same({}, hints)
      assert.are.equal("Open Menu", GameTooltip.doubleLines[1] and GameTooltip.doubleLines[1].right)
      frame:GetScript("OnLeave")(frame)
      frame:GetScript("OnClick")(frame, "LeftButton")
      assert.are.same({}, picks)
      assert.is_not_nil(shown)
    end)

    it("lights and says what a drop does while an item is held over it", function()
      theme()
      local panel = panelOn("RIGHT")
      panel.dropTarget = "Menu"
      panel.menuButton:Style()
      local frame = panel.menuButton.frame
      hold()
      GameTooltip.doubleLines = {}
      frame:GetScript("OnEnter")(frame)
      tween:Step(1)
      assert.are.equal(1, panel.menuButton.highlight:GetAlpha())
      assert.are.same({ { frame, "ANCHOR_LEFT" } }, hints)
      assert.are.same({}, GameTooltip.doubleLines, "not its click's line")
      frame:GetScript("OnLeave")(frame)
      ClearCursor()
      frame:GetScript("OnEnter")(frame)
      assert.are.equal(1, #hints, "nothing held: what a click does")
      frame:GetScript("OnLeave")(frame)
    end)
  end)

  -- How far it reaches past the body's top and its bottom (Reach), placed as Style places it: a docked panel keeps it clear of
  -- the screen's top and bottom with its frame (Panel.DockMargin; asked of the Plain theme: "the bag button is in a better
  -- place" docked).
  describe("its reach", function()
    -- One unit a pixel, as the specs' screen draws it.
    local PIXEL = 1

    it("is its offset above the body's top and its art's past it, the most of every panel's own", function()
      theme()
      -- 15 above the top, the bag and its glow 2 above that; the vendor's portrait reaches no higher.
      assert.are.same({ 17, 0 }, { menuButton:Reach(addon:GetModule("NextStyle").Theme.Header.Buttons.Menu, PIXEL) })
      assert.are.same({ 32, 0 }, { menuButton:Reach({ Point = "TOPINNER", Y = -15, Width = 40, Height = 40,
        Layers = { bag() }, Panels = { Vendor = { Y = -30 } } }, PIXEL) }, "a panel's own reaching higher")
    end)

    it("hangs from its own anchor, and at a bottom corner below the body's bottom", function()
      assert.are.same({ 30, 0 }, { menuButton:Reach({ Point = "TOPINNER", Anchor = "BOTTOMINNER", Y = 10, Width = 40, Height = 40 },
        PIXEL) })
      assert.are.same({ 0, 9 }, { menuButton:Reach({ Point = "BOTTOMOUTER", Y = 5, Width = 40, Height = 40,
        Layers = { { Texture = BAGSLOTS, Inset = { Bottom = -4 } } } }, PIXEL) })
      assert.are.same({ 0, 0 }, { menuButton:Reach({ Point = "TOPINNER", Y = 4, Width = 40, Height = 40 }, PIXEL) }, "inside")
    end)

    -- Style rounds its offset, its size and its art's insets to whole pixels of the grid it draws on (found by the bug review:
    -- a reach that did not left a docked panel's gaps a pixel apart at some UI scales).
    it("is in whole pixels of the grid it is drawn on, each offset and size rounded as Style rounds them", function()
      local function near(a, b) return math.abs(a - b) < 1e-9 end
      local top = menuButton:Reach({ Point = "TOPINNER", Y = -15, Width = 40, Height = 40, Layers = { bag() } }, 0.6)
      assert.is_true(near(16.8, top), "15 is 25 pixels, its art's 2 is 3: " .. top)
      top = menuButton:Reach({ Point = "TOPINNER", Anchor = "BOTTOMINNER", Y = 1, Width = 40, Height = 41 }, 0.6)
      assert.is_true(near(39.6, top), "41 is 68 pixels, less 1's 2: " .. top)
    end)

    it("reaches nowhere without a bag button", function()
      assert.are.same({ 0, 0 }, { menuButton:Reach(nil, PIXEL) })
      assert.are.same({ 0, 0 }, { menuButton:Reach(false, PIXEL) })
    end)
  end)

  teardown(function()
    for _, name in ipairs(addedKinds) do const.BAG_KIND[name] = nil end
    if createdConstants then ResetModuleStub("Constants") end
    if createdPicker then ResetModuleStub("NextCategoryPicker") end
  end)
end)
