-- bag_switch_spec.lua -- Switching between the classic bags and BetterBags Next without a reload
-- (next.md §11), on the whole addon (spec/helpers/whole_addon.lua): every file of the TOC loaded
-- as the client loads it, started as the client starts it. spec/bagsystem_spec.lua covers
-- BagSystem's own steps with stand-in bags; this covers the real bags, which is where the classic
-- bags made after a theme was applied failed in game (frames/bag.lua: "attempt to index field
-- 'searchBox'").
local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("switching bag designs on the whole addon", function()
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

  local function switch(addon, design)
    assert.is_true(addon:GetModule("BagSystem"):Switch(ctx(addon), design))
    assert.are.same({}, handle.errors, "switching to " .. design)
    assert.are.equal(design, addon:GetModule("BagSystem"):ActiveDesign())
  end

  -- listening lists every event and message BetterBags listens to, with how many callbacks each.
  local function listening(addon)
    local events = addon:GetModule("Events")
    local out = {}
    for name, entry in pairs(events._eventMap) do out["event " .. name] = #entry.cbs end
    for name, entry in pairs(events._messageMap) do out["message " .. name] = #entry.cbs end
    return out
  end

  local function freshStart(opts)
    local addon = start(opts)
    local found = listening(addon)
    handle:Restore()
    handle = nil
    return found
  end

  -- A load and start take about 940 MB of mock frames: anything the loaded addon leaves reachable
  -- after Restore keeps all of it, and a CI runner ran out of memory over a run of these specs.
  it("lets the loaded addon be collected once restored", function()
    local held = setmetatable({}, { __mode = "v" })
    local function loadAndSwitch()
      local addon = start({ next = true })
      switch(addon, "classic")
      held.addon, held.frame, held.items = addon, addon.Bags.Backpack.frame, addon:GetModule("Items")
      handle:Restore()
      handle = nil
    end
    loadAndSwitch()
    collectgarbage("collect")
    assert.is_nil(held.addon, "the addon")
    assert.is_nil(held.frame, "its frames")
    assert.is_nil(held.items, "its modules")
  end)

  -- AceEvent dispatches through CallbackHandler, which calls each handler with
  -- securecallfunction: an error in a handler goes to the error handler (warcraft.wiki.gg
  -- API:securecall), so the harness sees it (test-harness.md §5).
  it("collects an error thrown in a message or event handler", function()
    local addon = start({})
    local events = addon:GetModule("Events")
    events:RegisterMessage("spec/Throws", function() error("thrown in a handler") end)
    events:SendMessage(addon:GetModule("Context"):New("spec"), "spec/Throws")
    assert.equal(1, #handle.errors)
    assert.is_truthy(tostring(handle.errors[1]):find("thrown in a handler", 1, true))
    handle.errors = {}
  end)

  -- Asked: "if this is a net new install of the addon, i now want to default to the next
  -- experience". A new install has no saved variables at all.
  it("starts a new install with BetterBags Next", function()
    local addon = start({ install = "new" })
    assert.are.equal("next", addon:GetModule("BagSystem"):ActiveDesign())
    assert.is_true(addon:GetModule("Database"):GetNextEnabled())
    assert.is_not_nil(addon.Vendor)
  end)

  it("keeps the classic bags on an install that never turned BetterBags Next on", function()
    local addon = start({ install = "existing" })
    assert.are.equal("classic", addon:GetModule("BagSystem"):ActiveDesign())
    assert.is_false(addon:GetModule("Database"):GetNextEnabled())
  end)

  it("starts with the classic bags and switches to BetterBags Next and back", function()
    local addon = start()
    assert.are.equal("classic", addon:GetModule("BagSystem"):ActiveDesign())
    switch(addon, "next")
    assert.is_not_nil(addon.Vendor)
    switch(addon, "classic")
    assert.is_nil(addon.Vendor)
    switch(addon, "next")
  end)

  it("starts with BetterBags Next and makes the classic bags after the theme was applied, parts placed", function()
    local addon = start({ next = true })
    assert.are.equal("next", addon:GetModule("BagSystem"):ActiveDesign())
    switch(addon, "classic")
    local backpack = addon.Bags.Backpack
    assert.is_not_nil(backpack.searchBox.frame:GetPoint(1), "the search box placed by the theme's layout")
    assert.is_not_nil(backpack.bottomBar:GetPoint(1), "the footer placed")
    assert.is_not_nil(addon.Bags.Bank.searchBox.frame:GetPoint(1), "the bank's search box placed")
    switch(addon, "next")
  end)

  -- A resizable window sets its size limits as it is styled, which reads the bag's minimum
  -- width: before the bag has made what it reads (reported in game for a resizable bank).
  it("switches both ways with bags the player sizes (Drag to Resize)", function()
    local addon = start({ next = true, sizeMode = "window" })
    switch(addon, "classic")
    assert.are.equal("window", addon.Bags.Bank.window:GetSizeMode())
    switch(addon, "next")
    switch(addon, "classic")
    handle:Restore()
    addon = start({ sizeMode = "window" })
    switch(addon, "next")
    switch(addon, "classic")
  end)

  -- What changes the code that runs while a window is styled or a bag is made: the theme (each
  -- lays out different parts; Guild Wars 2 has action buttons and no menu button), the size mode
  -- (here the backpack sized to its content and the bank by the player, at once), the client, and
  -- the settings a bag reads as it is made.
  describe("on every theme, on WoW: Forever, and with other settings", function()
    local function mixedSizes(defaults, const)
      for _, kinds in pairs(defaults.size) do
        kinds[const.BAG_KIND.BACKPACK].sizeMode = "content"
        kinds[const.BAG_KIND.BANK].sizeMode = "window"
      end
    end

    -- The addons the ElvUI and Guild Wars 2 themes need, as spec/sonata/theme_ports_spec.lua
    -- stands in for them (the media, textures and pixel settings ElvUI's theme reads; GW2_UI's
    -- font settings).
    local function elvui()
      local E = {
        media = { blankTex = "Interface\\ElvUIBlank", glossTex = "Interface\\ElvUINorm",
          bordercolor = { 0.1, 0.1, 0.1 }, backdropcolor = { 0.2, 0.2, 0.2 },
          backdropfadecolor = { 0.06, 0.06, 0.06, 0.8 }, rgbvaluecolor = { 0.1, 0.6, 0.9 } },
        Media = { Textures = { Close = "Interface\\ElvUIClose", BagQuestIcon = "Interface\\ElvUIQuest",
          BagUpgradeIcon = "Interface\\ElvUIUpgrade" } },
        PixelMode = true, twoPixelsPlease = false, Modern = true, Border = 1,
        TexCoords = { 0.08, 0.92, 0.08, 0.92 },
      }
      function E:Scale(n) return n end
      return { ElvUI = { E } }
    end
    local THEME_ADDONS = {
      elvui = elvui,
      GW2 = function()
        return { GW2_ADDON = { settings = { fonts = { size = { bigHeader = 20, normal = 13, small = 11 },
          outline = "NONE" } } } }
      end,
    }

    for _, theme in ipairs({ "Default", "SimpleDark", "Dark", "Parchment", "Slate", "elvui", "GW2" }) do
      it("makes the classic bags after the " .. theme .. " theme was applied, and switches back and forth", function()
        local addons = THEME_ADDONS[theme]
        local addon = start({ next = true, theme = theme, profile = mixedSizes, globals = addons and addons() })
        assert.are.equal(theme, addon:GetModule("Sonata"):GetCurrentThemeKey())
        switch(addon, "classic")
        assert.is_not_nil(addon.Bags.Bank.searchBox.frame:GetPoint(1))
        switch(addon, "next")
        switch(addon, "classic")
      end)
    end

    for _, first in ipairs({ "next", "classic" }) do
      it("switches both ways on WoW: Forever, starting with " .. first, function()
        local addon = start({ client = "forever", next = first == "next", profile = mixedSizes })
        assert.is_true(addon.isForever)
        local other = first == "next" and "classic" or "next"
        switch(addon, other)
        switch(addon, first)
        switch(addon, other)
      end)
    end

    it("switches both ways with in-bag search and groups off, in the Show Bags view", function()
      local function others(defaults, const)
        mixedSizes(defaults, const)
        defaults.inBagSearch = false
        for kind in pairs(defaults.groupsEnabled) do defaults.groupsEnabled[kind] = false end
        for kind in pairs(defaults.views) do defaults.views[kind] = const.BAG_VIEW.SECTION_ALL_BAGS end
      end
      local addon = start({ next = true, profile = others })
      switch(addon, "classic")
      switch(addon, "next")
      handle:Restore()
      addon = start({ profile = others })
      switch(addon, "next")
      switch(addon, "classic")
    end)
  end)

  it("switches with the backpack open, the other design opening in its place", function()
    local addon = start()
    addon.Bags.Backpack:Show(ctx(addon))
    local classic = addon.Bags.Backpack
    switch(addon, "next")
    assert.is_false(classic.frame:IsShown())
    assert.is_true(addon.Bags.Backpack:IsShown())
    addon.Bags.Backpack:Hide(ctx(addon))
    switch(addon, "classic")
    assert.is_false(addon.Bags.Backpack:IsShown())
    addon.Bags.Backpack:Show(ctx(addon))
    addon.Bags.Backpack:Hide(ctx(addon))
    assert.are.same({}, handle.errors, "opening and closing")
  end)

  -- The design not in use is unhooked entirely (asked: "performance especially, we need to unhook
  -- the classic bags when we swap, and vice versa"): after a switch, BetterBags listens to exactly
  -- what a fresh start in that design listens to.
  it("listens to what a fresh start in BetterBags Next listens to, after switching from the classic bags", function()
    local fresh = freshStart({ next = true })
    local addon = start()
    switch(addon, "next")
    assert.are.same(fresh, listening(addon))
  end)

  it("listens to what a fresh start in the classic bags listens to, after switching from BetterBags Next", function()
    local fresh = freshStart()
    local addon = start({ next = true })
    switch(addon, "classic")
    assert.are.same(fresh, listening(addon))
  end)

  -- Switching back to a design made earlier hooks its registrations again, and only those.
  it("listens to what a fresh start in each design listens to, switching back to one made earlier", function()
    local freshClassic = freshStart()
    local freshNext = freshStart({ next = true })
    local addon = start()
    switch(addon, "next")
    switch(addon, "classic")
    assert.are.same(freshClassic, listening(addon))
    switch(addon, "next")
    assert.are.same(freshNext, listening(addon))
  end)
end)
