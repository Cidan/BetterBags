-- next_settings_spec.lua -- BetterBags Next's settings window (next-settings.md) on the whole addon
-- (spec/helpers/whole_addon.lua): every file of the TOC loaded and started as the client does, with the
-- real database, catalog, categories and bags. The settings open in the window of the design in use,
-- every page and tab builds, search finds settings, and switching design from the window opens the
-- other design's.
local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("BetterBags Next's settings window on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
      handle = nil
    end
  end)

  local function start(opts)
    handle = WholeAddon.Load(opts)
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    return handle.addon
  end

  local function ctx(addon)
    return addon:GetModule("Context"):New("spec")
  end

  local function rowOf(settings, id)
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        if row.option and row.option.id == id then
          return row
        end
      end
    end
  end

  it("opens BetterBags Next's window while Next is in use, and builds every page and tab", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    addon:GetModule("Events"):SendMessage(ctx(addon), "config/Open")
    assert.is_true(settings:IsShown())
    assert.is_false(addon:GetModule("Config").configFrame:GetFrame():IsShown())
    local pages = addon:GetModule("NextSettingsPages")
    local built = 0
    for _, page in ipairs(pages:List()) do
      for _, tab in ipairs(page.tabs) do
        settings:Open(page.id, tab.id)
        assert.are.same({}, handle.errors, page.id .. " > " .. tab.id)
        assert.are.equal(page.id, settings.pageId)
        assert.is_true(#settings.page.sections > 0, page.id .. " > " .. tab.id .. " shows something")
        built = built + 1
      end
    end
    assert.is_true(built >= 13, "every page and tab")
    settings:Close()
    assert.are.same({}, handle.errors, "closing")
  end)

  it("reads the real settings into its rows", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    local db = addon:GetModule("Database")
    settings:Open("backpack", "items")
    local row = rowOf(settings, "mergeStacks")
    assert.are.equal(db:GetStackingOptions(0).mergeStacks == true, row.control:GetChecked())
    settings:Open("general")
    assert.is_true(rowOf(settings, "nextEnabled").control:GetChecked())
  end)

  it("finds settings by what they do", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    settings:Open()
    settings:Search(ctx(addon), "stack")
    assert.are.same({}, handle.errors)
    assert.is_true(#settings.page.sections >= 2, "the stacking settings of every bag")
  end)

  it("opens the classic window while the classic bags are in use", function()
    local addon = start({})
    addon:GetModule("Events"):SendMessage(ctx(addon), "config/Open")
    assert.is_true(addon:GetModule("Config").configFrame:GetFrame():IsShown())
    assert.is_false(addon:GetModule("NextSettings"):IsShown())
  end)

  it("opens the classic window when BetterBags Next is turned off from its own", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    settings:Open("general")
    local row = rowOf(settings, "nextEnabled")
    row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
    assert.are.same({}, handle.errors, "switching")
    assert.are.equal("classic", addon:GetModule("BagSystem"):ActiveDesign())
    assert.is_false(settings:IsShown())
    assert.is_true(addon:GetModule("Config").configFrame:GetFrame():IsShown())
  end)
end)
