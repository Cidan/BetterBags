-- tabs_spec.lua -- Unit tests for icon-tab anchoring in frames/tabs.lua.
--
-- The "+" (new group) tab renders an atlas icon instead of a text label. Its
-- icon must sit in the tab template's content region. On Classic that region is
-- ~10px above the frame center (the template's deselectedTextY), while on retail
-- it is at the frame center, so anchoring the icon to a fixed frame-center offset
-- left it low and bleeding out the bottom on Classic.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

local themes = StubBetterBagsModule("Themes")
StubBetterBagsModule("SectionFrame")
StubBetterBagsModule("Database")
local groups = StubBetterBagsModule("Groups")
groups.IsDefaultGroup = function() return false end
local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }

local context = addon:GetModule("Context")

_G.GameFontNormalSmall = _G.GameFontNormalSmall or {}
_G.PanelTemplates_TabResize = function() end

ResetModuleStub("Tabs", "frames/tabs.lua")
LoadBetterBagsModule("frames/tabs.lua")
local tabs = addon:GetModule("Tabs")

-- Build a decoration shaped like a tab button: records the tabIcon anchor.
local function newDecoration(deselectedTextY)
  local function newTexture()
    local t = {}
    t.SetSize = function() end
    t.SetAtlas = function(_, atlas) t._atlas = atlas end
    t.Show = function() t._shown = true end
    t.Hide = function() t._shown = false end
    t.ClearAllPoints = function() t._point = nil end
    t.SetPoint = function(_, point, rel, relPoint, x, y)
      t._point = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
    end
    return t
  end
  local d = {}
  d.deselectedTextY = deselectedTextY
  d.Text = { SetFontObject = function() end, SetText = function() end, SetAlpha = function() end }
  d.CreateTexture = function() return newTexture() end
  d.Show = function() end
  d.GetWidth = function() return 50 end
  d.GetFrameLevel = function() return 5 end
  d.SetFrameLevel = function() end
  d.SetScript = function() end
  d.GetScript = function() return nil end
  d.SetAttribute = function() end
  return d
end

local function newTab()
  return {
    id = 0, -- the "+" new-group tab
    index = 1,
    icon = "communities-icon-addchannelplus",
    name = "New Group",
    GetName = function() return "BetterBagsTab1" end,
    SetWidth = function() end,
    SetHeight = function() end,
    GetFrameLevel = function() return 4 end,
  }
end

describe("Tab icon anchoring", function()
  local function resizeWith(deselectedTextY)
    local decoration = newDecoration(deselectedTextY)
    themes.GetTabButton = function() return decoration end

    local container = tabs:Create(CreateFrame("Frame", "TabsSpecParent"), const.BAG_KIND.BACKPACK)
    container.tabIndex[1] = newTab()
    container:ResizeTabByIndex(context:New("resize"), 1)
    return decoration
  end

  it("anchors the '+' icon to the content region on Classic (deselectedTextY)", function()
    local decoration = resizeWith(10)
    assert.is_not_nil(decoration.tabIcon)
    assert.is_not_nil(decoration.tabIcon._point)
    assert.equal("CENTER", decoration.tabIcon._point.point)
    assert.equal(0, decoration.tabIcon._point.x)
    -- Tracks the tab's content region (label baseline 10, dropped a few px so an
    -- icon's center reads centered rather than sitting on the text baseline).
    assert.equal(6, decoration.tabIcon._point.y)
  end)

  it("keeps the retail anchor when the template has no deselectedTextY", function()
    local decoration = resizeWith(nil)
    assert.is_not_nil(decoration.tabIcon._point)
    assert.equal(0, decoration.tabIcon._point.x)
    assert.equal(1, decoration.tabIcon._point.y)
  end)
end)
