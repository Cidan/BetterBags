-- stacked_text_spec.lua -- The stacked form layout (forms/layouts/stacked.lua) draws its text with
-- Sonata's text roles, so a theme restyles it: section headings and text, option titles and
-- descriptions, and the navigation in its normal, hovered and open states.
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

local animations = trackStub("Animations")
animations.AttachFadeGroup = animations.AttachFadeGroup or function()
  local group = { Play = function() end }
  return group, group
end
local db = trackStub("Database")
local originalGetTheme = db.GetTheme

local sonata = UseSonataTextRoles()
LoadBetterBagsModule("forms/layouts/layout.lua")
LoadBetterBagsModule("forms/layouts/stacked.lua")
local layouts = addon:GetModule("FormLayouts")

describe("stacked layout text", function()
  local originalCurrent

  before_each(function()
    db.GetTheme = function() return "Default" end
    originalCurrent = sonata.current
    sonata:Init()
    UseSonataTextRoles()
  end)

  after_each(function()
    db.GetTheme = originalGetTheme
    sonata.current = originalCurrent
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  local function newLayout(index, tabbed)
    local scrollBox = CreateFrame("Frame")
    scrollBox.RegisterCallback = function() end
    return layouts:NewStackedLayout(CreateFrame("Frame"), CreateFrame("Frame"), scrollBox, index, tabbed)
  end

  local function role(name)
    return sonata:GetTextFont(name)
  end

  it("draws an option's title and description with the Label and Description roles", function()
    local layout = newLayout(false, false)
    layout:AddCheckbox({ title = "Enable In-Bag Search", description = "A search bar at the top of your bags.",
      getValue = function() return true end, setValue = function() end })
    local container = next(layout.checkboxes)
    assert.are.equal(role("Label"), container.title:GetFontObject())
    assert.are.equal(role("Description"), container.description:GetFontObject())
    -- Text that sets its own color stops following its role's font object.
    assert.is_nil(container.title._textColor)
    assert.is_nil(container.description._textColor)
  end)

  it("draws a section's heading and text with the Heading and Body roles", function()
    local layout = newLayout(false, false)
    layout:AddSection({ title = "General", description = "General settings for BetterBags." })
    local container = layout.nextFrame
    assert.are.equal(role("Heading"), container.title:GetFontObject())
    assert.are.equal(role("Body"), container.description:GetFontObject())
    assert.is_nil(container.title._textColor)
  end)

  it("draws the navigation with the Nav roles: the open section, a hovered one, and back", function()
    local layout = newLayout(true, true)
    layout:AddSection({ title = "General", description = "" })
    layout:AddSection({ title = "Bags", description = "" })
    layout:AddSubIndex({ title = "Sizes" })
    local general = layout.sections[1].button:GetFontString()
    local bags = layout.sections[2].button
    local sizes = layout.sections[3].button
    assert.are.equal(role("NavActive"), general:GetFontObject())
    assert.are.equal(role("Nav"), bags:GetFontString():GetFontObject())
    assert.are.equal(role("NavSub"), sizes:GetFontString():GetFontObject())

    bags:GetScript("OnEnter")(bags)
    assert.are.equal(role("NavHover"), bags:GetFontString():GetFontObject())
    bags:GetScript("OnLeave")(bags)
    assert.are.equal(role("Nav"), bags:GetFontString():GetFontObject())

    sizes:GetScript("OnEnter")(sizes)
    assert.are.equal(role("NavSubHover"), sizes:GetFontString():GetFontObject())

    layout:UpdateTabHighlighting(2)
    assert.are.equal(role("Nav"), general:GetFontObject())
    assert.are.equal(role("NavActive"), bags:GetFontString():GetFontObject())
    assert.is_nil(general._textColor)
  end)

  -- The settings window is built before Sonata applies the saved theme, and a font object
  -- changed while its text used it left that text out of step: hovering an entry changed its
  -- size until a theme switch. Font objects are now made per theme and never changed.
  it("leaves a hovered entry on the same font object as the entries never hovered", function()
    local layout = newLayout(true, true)
    layout:AddSection({ title = "General", description = "" })
    layout:AddSection({ title = "Bags", description = "" })
    layout:AddSection({ title = "Items", description = "" })
    local bags, items = layout.sections[2].button, layout.sections[3].button
    local before = bags:GetFontString():GetFontObject()
    local events = addon:GetModule("Events")
    local originalSend = events.SendMessage
    events.SendMessage = function() end
    sonata:ApplyTheme(addon:GetModule("Context"):New("spec"), "Default", false)
    events.SendMessage = originalSend
    local nav = sonata:GetTextFont("Nav")
    assert.are_not.equal(before, nav)
    assert.are.equal(nav, items:GetFontString():GetFontObject())
    local height = select(2, nav:GetFont())
    bags:GetScript("OnEnter")(bags)
    bags:GetScript("OnLeave")(bags)
    assert.are.equal(nav, bags:GetFontString():GetFontObject())
    assert.are.equal(nav, items:GetFontString():GetFontObject())
    assert.are.equal(height, select(2, nav:GetFont()))
  end)

  -- An entry wrapped onto a clipped second line in game ("Import/" for "Import/Export"). A render
  -- recording on WoW: Forever showed why: the Nav role's shadow (offset 1) makes the text 0.8
  -- wider than the hover and selected roles' glow (offset 0), and once sized in one of those the
  -- entry kept the narrower width (110.0 for a 110.8 string). Setting the width to 0 and the text
  -- again (Blizzard's QuestLogTitleButton_Resize) refreshed the string's width but not the
  -- entry's. So after every font change the entry is measured, then given that width
  -- explicitly, rounded up with a pixel to spare.
  it("re-measures every navigation entry after each change of its font, and sets that width", function()
    local layout = newLayout(true, true)
    layout:AddSection({ title = "General", description = "" })
    layout:AddSubIndex({ title = "Sizes" })
    layout:AddPaneLink({ title = "Import/Export", createPane = function(parent) return CreateFrame("Frame", nil, parent) end })
    local steps = {}
    for i = 1, 3 do
      local button = layout.sections[i].button
      local fs = button:GetFontString()
      local setWidth, setText = fs.SetWidth, button.SetText
      fs.SetWidth = function(self, width)
        table.insert(steps, { i, "width", width })
        return setWidth(self, width)
      end
      button.SetText = function(self, text)
        table.insert(steps, { i, "text", text })
        return setText(self, text)
      end
    end
    -- The frame mock measures 6 pixels per character.
    local function refit(i, text)
      return { { i, "width", 0 }, { i, "text", text }, { i, "width", #text * 6 + 1 } }
    end
    local link = layout.sections[3].button
    link:GetScript("OnEnter")(link)
    assert.are.same(refit(3, "  Import/Export"), steps)
    steps = {}
    link:GetScript("OnLeave")(link)
    assert.are.same(refit(3, "  Import/Export"), steps)
    steps = {}
    local sizes = layout.sections[2].button
    sizes:GetScript("OnEnter")(sizes)
    assert.are.same(refit(2, "  Sizes"), steps)
    steps = {}
    layout:UpdateTabHighlighting(1)
    local expected = {}
    for _, step in ipairs(refit(1, "General")) do table.insert(expected, step) end
    for _, step in ipairs(refit(2, "  Sizes")) do table.insert(expected, step) end
    for _, step in ipairs(refit(3, "  Import/Export")) do table.insert(expected, step) end
    assert.are.same(expected, steps)
    steps = {}
    local events = addon:GetModule("Events")
    local originalSend = events.SendMessage
    events.SendMessage = function() end
    sonata:ApplyTheme(addon:GetModule("Context"):New("spec"), "Default", false)
    events.SendMessage = originalSend
    -- Sonata moves texts to the new theme's font objects in no set order: each entry is refit once.
    assert.are.equal(9, #steps)
    local byEntry = {}
    for _, step in ipairs(steps) do
      byEntry[step[1]] = byEntry[step[1]] or {}
      table.insert(byEntry[step[1]], step)
    end
    assert.are.same(refit(1, "General"), byEntry[1])
    assert.are.same(refit(2, "  Sizes"), byEntry[2])
    assert.are.same(refit(3, "  Import/Export"), byEntry[3])
  end)

  it("gives every navigation entry its measured width when it is made", function()
    local layout = newLayout(true, true)
    layout:AddSection({ title = "General", description = "" })
    layout:AddSubIndex({ title = "Sizes" })
    layout:AddPaneLink({ title = "Import/Export", createPane = function(parent) return CreateFrame("Frame", nil, parent) end })
    assert.are.equal(#"General" * 6 + 1, layout.sections[1].button:GetFontString():GetWidth())
    assert.are.equal(#"  Sizes" * 6 + 1, layout.sections[2].button:GetFontString():GetWidth())
    assert.are.equal(#"  Import/Export" * 6 + 1, layout.sections[3].button:GetFontString():GetWidth())
  end)

  it("draws a pane link with the sub navigation roles", function()
    local layout = newLayout(true, true)
    layout:AddSection({ title = "General", description = "" })
    layout:AddPaneLink({ title = "Categories", createPane = function(parent) return CreateFrame("Frame", nil, parent) end })
    local link = layout.sections[2].button
    assert.are.equal(role("NavSub"), link:GetFontString():GetFontObject())
    link:GetScript("OnEnter")(link)
    assert.are.equal(role("NavSubHover"), link:GetFontString():GetFontObject())
    link:GetScript("OnLeave")(link)
    assert.are.equal(role("NavSub"), link:GetFontString():GetFontObject())
  end)
end)
