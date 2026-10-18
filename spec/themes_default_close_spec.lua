-- themes_default_close_spec.lua -- The Default theme's window close buttons must
-- sit ABOVE the owner frame's mouse layer. The owner frame (bag / config form)
-- is mouse-enabled for drag-move at a higher frame level than the themed
-- decoration (decoration = owner level - 1), so a close button left at the
-- decoration's level is occluded by the owner frame and only clickable on the
-- sliver hanging outside the frame corner. The Portrait (bag) path raised it to
-- 1001; the Simple (config) path did not — reproduced here.

LoadBetterBagsModule("core/context.lua")

local searchBox = StubBetterBagsModule("SearchBox")
searchBox.CreateBox = function()
  return { frame = { SetPoint = function() end } }
end

local fonts = StubBetterBagsModule("Fonts")
fonts.UnitFrame12Yellow = {}

-- Capture the theme registered by default.lua and the close buttons it creates.
local registered = {}
local themes = StubBetterBagsModule("Themes")
themes.titles = {}
themes.RegisterTheme = function(_, name, theme) registered[name] = theme end
themes.SetupBagButton = function() end

local lastCloseButton
local realCreateFrame = _G.CreateFrame
local function makeCloseButton()
  local b = {}
  b.SetScript = function() end
  b.SetFrameLevel = function(_, lvl) b._level = lvl end
  b.GetFrameLevel = function() return b._level or 0 end
  return b
end
local function makeDecoration()
  local d = {}
  d.SetAllPoints = function() end
  d.SetFrameLevel = function() end
  d.GetFrameLevel = function() return 499 end
  d.Show = function() end
  d.SetTitle = function() end
  d.TitleContainer = { TitleText = { SetFontObject = function() end }, SetFrameLevel = function() end, Hide = function() end }
  d.NineSlice = { SetFrameLevel = function() end }
  return d
end
local function themedCreateFrame(kind, name, parent, template)
  if template == "UIPanelCloseButtonDefaultAnchors" then
    lastCloseButton = makeCloseButton()
    return lastCloseButton
  end
  if template == "DefaultPanelTemplate" or template == "DefaultPanelFlatTemplate" then
    return makeDecoration()
  end
  return realCreateFrame(kind, name, parent, template)
end

LoadBetterBagsModule("themes/default.lua")

local function newOwnerFrame(name)
  return {
    GetName = function() return name end,
    GetFrameLevel = function() return 500 end,
    Owner = { kind = 0 },
  }
end

describe("Default theme window close buttons", function()
  local theme

  before_each(function()
    theme = registered["Default"]
    lastCloseButton = nil
    _G.CreateFrame = themedCreateFrame
  end)

  after_each(function()
    _G.CreateFrame = realCreateFrame
  end)

  it("raises the Simple (config) window close button above the owner mouse layer", function()
    theme.Simple(newOwnerFrame("TestSimpleWindowClose"))
    assert.is_not_nil(lastCloseButton)
    assert.equal(1001, lastCloseButton._level)
  end)

  it("raises the Portrait (bag) window close button above the owner mouse layer", function()
    theme.Portrait(newOwnerFrame("TestPortraitWindowClose"))
    assert.is_not_nil(lastCloseButton)
    assert.equal(1001, lastCloseButton._level)
  end)
end)
