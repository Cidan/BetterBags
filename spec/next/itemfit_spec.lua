-- itemfit_spec.lua -- NextItemFit (next/itemfit.lua): the parts of the item buttons BetterBags Next draws on
-- whole screen pixels (docs/next-pixel-perfect.md), put back for the classic bags.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end
local sonata = trackStub("Sonata")
local events = trackStub("Events")

ResetModuleStub("NextItemFit", "next/itemfit.lua")
LoadBetterBagsModule("next/itemfit.lua")
local itemFit = addon:GetModule("NextItemFit")
local pixel = addon:GetModule("NextPixel")
local layout = dofile("spec/helpers/layout.lua")

describe("NextItemFit", function()
  local undo, window, decoration, ilvl, restyled, sent, generation

  teardown(function()
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local saved = {}
  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  -- buildDecoration makes what ContainerFrameItemButtonTemplate gives a decoration, anchored as Blizzard's
  -- XML anchors it (Blizzard_ItemButton/Shared/ItemButtonTemplate.xml, Blizzard_UIPanels_Game/Mainline/
  -- ContainerFrame.xml), sized as frames/item.lua sizes it (SetSize: the border, overlay and quest art the
  -- button's size), and the family glyph frames/item.lua adds (24 x 24 at its middle). The mock reads no
  -- atlas sizes: the art drawn at its atlas's size gets stand-in sizes here.
  local function buildDecoration(width, height)
    local d = CreateFrame("ItemButton", nil, window)
    d:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    d:SetSize(width, height)
    d.icon:SetAllPoints(d)
    d.Count:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -5, 2)
    d.Stock = d:CreateFontString(nil, "ARTWORK", "NumberFontNormalYellow")
    d.Stock:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -2)
    d.searchOverlay:SetAllPoints(d)
    d.ItemContextOverlay:SetAllPoints(d)
    for _, key in ipairs({ "IconBorder", "IconOverlay" }) do
      d[key]:SetPoint("CENTER", d, "CENTER", 0, 0)
      d[key]:SetSize(width, height)
    end
    d.IconOverlay2 = d:CreateTexture(nil, "OVERLAY", nil, 2)
    d.IconOverlay2:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.IconOverlay2:SetSize(37, 37)
    d.IconQuestTexture = d:CreateTexture(nil, "OVERLAY", nil, 2)
    d.IconQuestTexture:SetPoint("TOP", d, "TOP", 0, 0)
    d.IconQuestTexture:SetSize(width, height)
    d.UpgradeIcon:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    d.flash = d:CreateTexture(nil, "OVERLAY", nil, 2)
    d.flash:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.flash:SetSize(41.3, 41.3)
    d.NewItemTexture:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.NewItemTexture:SetSize(46.7, 46.7)
    d.BattlepayItemTexture:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.ExtendedSlot = d:CreateTexture(nil, "OVERLAY", nil, 2)
    d.ExtendedSlot:SetPoint("CENTER", d, "CENTER", 0, -1)
    d.ExtendedSlot:SetSize(64, 64)
    d.JunkIcon = d:CreateTexture(nil, "OVERLAY", nil, 5)
    d.JunkIcon:SetPoint("TOPLEFT", d, "TOPLEFT", 1, 0)
    d.JunkIcon:SetSize(13.3, 13.3)
    d.BetterBagsFamilyIcon = d:CreateTexture(nil, "OVERLAY")
    d.BetterBagsFamilyIcon:SetPoint("CENTER", d, "CENTER", 0, 0)
    d.BetterBagsFamilyIcon:SetSize(24, 24)
    for _, key in ipairs({ "Count", "Stock", "IconBorder", "IconOverlay", "IconOverlay2", "flash", "NewItemTexture",
      "BattlepayItemTexture", "ExtendedSlot", "JunkIcon", "BetterBagsFamilyIcon", "searchOverlay", "ItemContextOverlay" }) do
      d[key]:Show()
    end
    for _, key in ipairs({ "Count", "Stock" }) do
      d[key]:SetFontObject(GameFontNormal)
      d[key]:SetText("20")
    end
    return d
  end

  -- What the fitter leaves to Sonata's item button styler, which rounds them itself (SonataElements,
  -- spec/sonata/elements_spec.lua): the icon, the count, the upgrade arrow.
  local function sonataParts(d)
    return { [d.icon] = true, [d.Count] = true, [d.UpgradeIcon] = true }
  end

  before_each(function()
    -- The reporter's window at 65%: a unit is 1.153 pixels.
    undo = layout.UseScreen(3396, 1362, 0.65)
    window = CreateFrame("Frame", nil, UIParent)
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pixel:Snap(UIParent, 200), -pixel:Snap(UIParent, 100))
    window:SetSize(400, 400)
    -- 44 units, the Default theme's icon: 51 pixels, an odd number.
    local size = pixel:Length(window, 44)
    decoration = buildDecoration(size, size)
    local button = CreateFrame("Button", nil, window)
    button:SetAllPoints(decoration)
    ilvl = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    ilvl:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    ilvl:SetFontObject(GameFontNormal)
    ilvl:SetText("600")
    restyled, sent, generation = {}, {}, 3
    override(sonata, "RestyleElement", function(_, kind, element)
      table.insert(restyled, { kind, element })
      element.sonataSnapUnit = pixel:Unit(element)
      return true
    end)
    override(sonata, "GetGeneration", function() return generation end)
    override(events, "SendMessage", function(_, ctx, name, item, d)
      table.insert(sent, { ctx ~= nil, name, item, d })
    end)
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
    saved = {}
    itemFit:RestoreAll()
    undo()
  end)

  local function offGrid(d)
    return layout.PixelCheck(window, { owners = { decoration = d }, skip = sonataParts(d) })
  end

  it("finds the template's parts between pixels where a unit is not a pixel", function()
    assert.is_true(#offGrid(decoration) > 0)
  end)

  it("puts every part on whole pixels: from their corner, filling the button, or centered at their size", function()
    assert.are.equal("placed", itemFit:Fit({}, decoration, { ilvl }))
    assert.are.same({}, offGrid(decoration))
    -- The Blizzard Store's highlight takes the new-item glow's box: its own is its image's, unknown.
    assert.are.same({ decoration.NewItemTexture:GetSize() }, { decoration.BattlepayItemTexture:GetSize() })
  end)

  it("keeps its template offsets, rounded, and its parts' sizes", function()
    itemFit:Fit({}, decoration, { ilvl })
    local unit = pixel:Unit(decoration)
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    local _, _, _, x, y = decoration.Stock:GetPoint(1)
    assert.is_true(near(0, x) and near(-2 * unit, y), "2 units are 2.3 pixels: 2")
    _, _, _, x, y = ilvl:GetPoint(1)
    assert.is_true(near(2 * unit, x) and near(2 * unit, y))
    assert.is_true(near(28 * unit, decoration.BetterBagsFamilyIcon:GetWidth()), "24 units are 27.7 pixels: 28")
    assert.are.equal(decoration, decoration.IconBorder._allPoints, "the border fills the button")
    assert.are.equal(decoration, decoration.IconQuestTexture._allPoints, "the quest art too")
  end)

  it("does the work once per grid, size and Sonata theme", function()
    itemFit:Fit({}, decoration, { ilvl })
    assert.are.equal("kept", itemFit:Fit({}, decoration, { ilvl }))
    generation = 4
    assert.are.equal("placed", itemFit:Fit({}, decoration, { ilvl }), "a new theme")
    decoration:SetSize(pixel:Length(window, 60), pixel:Length(window, 60))
    assert.are.equal("placed", itemFit:Fit({}, decoration, { ilvl }), "a new size")
    assert.are.same({}, offGrid(decoration))
  end)

  it("places them again on a new grid, from where the template put them", function()
    itemFit:Fit({}, decoration, { ilvl })
    undo()
    undo = layout.UseScreen(1920, 1080, 0.64)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    decoration:SetSize(pixel:Length(window, 44), pixel:Length(window, 44))
    assert.are.equal("placed", itemFit:Fit({}, decoration, { ilvl }))
    assert.are.same({}, offGrid(decoration))
    local _, _, _, _, y = decoration.Stock:GetPoint(1)
    assert.is_true(math.abs(y - pixel:Snap(decoration, -2)) < 1e-9, "from the template's -2, not the last rounding")
  end)

  -- Sonata rounds its own parts (the icon, the count, the upgrade arrow) to the grid the button is on when it
  -- styles it, and records that grid; on another, the button is styled again, and Masque told.
  it("has Sonata style the button again on a grid it was not styled on, saying so for Masque", function()
    local item = {}
    itemFit:Fit({}, decoration, { ilvl }, item)
    assert.are.same({ { "ItemButton", decoration } }, restyled)
    assert.are.same({ { true, "item/Updated", item, decoration } }, sent)
    generation = 5
    itemFit:Fit({}, decoration, { ilvl }, item)
    assert.are.equal(1, #restyled, "the same grid")
    decoration.sonataSnapUnit = 0.25
    generation = 6
    itemFit:Fit({}, decoration, { ilvl }, item)
    assert.are.equal(2, #restyled, "styled on another")
  end)

  it("puts every part back where it was for the classic bags", function()
    local before = {}
    for _, region in ipairs({ decoration.Stock, decoration.IconBorder, decoration.IconOverlay2, decoration.NewItemTexture,
      decoration.JunkIcon, decoration.BattlepayItemTexture, ilvl }) do
      before[region] = { { region:GetPoint(1) }, { region:GetSize() }, region:GetNumPoints() }
    end
    itemFit:Fit({}, decoration, { ilvl })
    itemFit:RestoreAll()
    for region, was in pairs(before) do
      assert.are.same(was, { { region:GetPoint(1) }, { region:GetSize() }, region:GetNumPoints() })
    end
    assert.is_nil(itemFit.saved[decoration])
    assert.are.equal("placed", itemFit:Fit({}, decoration, { ilvl }), "placed again when Next draws it")
  end)
end)
