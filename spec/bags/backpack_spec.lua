local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local aceAddon = LibStub("AceAddon-3.0")
_G.PanelTemplates_TabResize = _G.PanelTemplates_TabResize or function() end
_G.GetAppropriateTooltip = _G.GetAppropriateTooltip or function() return GameTooltip end
_G.GameTooltip.IsOwned = _G.GameTooltip.IsOwned or function() return false end

describe("Backpack Module Loading and Compatibility Tests", function()
  local oldModules = {}
  local oldAddons = {}

  before_each(function()
    -- Only clear BackpackBehavior so we can load it fresh for era/classic behavior
    oldModules["BackpackBehavior"] = addon.modules["BackpackBehavior"]
    oldAddons["BackpackBehavior"] = aceAddon.addons["BetterBags_BackpackBehavior"]
    addon.modules["BackpackBehavior"] = nil
    aceAddon.addons["BetterBags_BackpackBehavior"] = nil

    -- Stub other dependent modules so they are guaranteed to exist
    local L = StubBetterBagsModule("Localization")
    L.data = {}
    L.locale = "enUS"
    function L:G(key) return key end

    local const = StubBetterBagsModule("Constants")
    const.BAG_KIND = { BACKPACK = 0, BANK = 1, UNDEFINED = -1 }
    const.BAG_VIEW = { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }
    const.SECTION_SORT_TYPE = { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
    const.ITEM_SORT_TYPE = { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }
    const.GRID_COMPACT_STYLE = { NONE = 0, SIMPLE = 1, COMPACT = 2 }
    const.SEARCH_CATEGORY_GROUP_BY = { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
    const.FORM_LAYOUT = { TWO_COLUMN = 1, STACKED = 2 }
    const.BINDING_SCOPE = {}
    const.BINDING_MAP = {}
    const.DATABASE_DEFAULTS = {
      profile = {
        firstTimeMenu = true,
        enabled = true,
        enableBagFading = false,
        showBagButton = true,
        enableBankBag = true,
        showBankTabs = false,
        debug = false,
        inBagSearch = true,
        categorySell = false,
        showKeybindWarning = true,
        enterToMakeCategory = true,
        upgradeIconProvider = 'None',
        theme = 'Default',
        showFullSectionNames = { [0] = false, [1] = false },
        showAllFreeSpace = { [0] = false, [1] = false },
        glowIntensity = { [0] = 60, [1] = 60 },
        newItems = {
          [0] = { markRecentItems = true, showNewItemFlash = false },
          [1] = { markRecentItems = true, showNewItemFlash = false },
        },
        stacking = {
          [0] = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = true, dontMergePartial = false, dontMergeTransmog = false },
          [1] = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = true, dontMergePartial = false, dontMergeTransmog = false },
        },
        itemLevel = {
          [0] = { enabled = true, color = true },
          [1] = { enabled = true, color = true },
        },
        itemLevelColor = {
          maxItemLevelByCharacter = {},
          colors = {
            low = { red = 0.62, green = 0.62, blue = 0.62, alpha = 1 },
            mid = { red = 1, green = 1, blue = 1, alpha = 1 },
            high = { red = 0, green = 0.55, blue = 0.87, alpha = 1 },
            max = { red = 1, green = 0.5, blue = 0, alpha = 1 },
          }
        },
        positions = { [0] = {}, [1] = {} },
        anchorPositions = { [0] = {}, [1] = {} },
        anchorState = {
          [0] = { enabled = false, shown = false },
          [1] = { enabled = false, shown = false },
        },
        sectionSort = {
          [0] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 },
          [1] = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 },
        },
        itemSort = {
          [0] = { [1] = 2, [2] = 2, [3] = 2, [4] = 2 },
          [1] = { [1] = 2, [2] = 2, [3] = 2, [4] = 2 },
        },
        customSectionSort = { [0] = {}, [1] = {} },
        size = {
          [1] = {
            [0] = { columnCount = 15, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
            [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
          },
          [2] = {
            [0] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
            [1] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
          },
          [3] = {
            [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
            [1] = { columnCount = 5, itemsPerRow = 5, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
          },
          [4] = {
            [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
            [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89, sizeMode = "content" },
          },
        },
        views = { [0] = 2, [1] = 2 },
        previousViews = { [0] = 2, [1] = 2 },
        categoryOptions = {},
        customCategoryFilters = {},
        ephemeralCategoryFilters = {},
        customCategoryIndex = {},
        categoryFilters = {
          [0] = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true, GearSet = true, EquipmentLocation = true },
          [1] = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true, GearSet = true, EquipmentLocation = true },
        },
        lockedItems = {},
        newItemTime = 300,
        groups = {
          [0] = { [1] = { id = 1, name = "Backpack", order = 1, kind = 0, isDefault = true } },
          [1] = {},
        },
        groupCounter = { [0] = 1, [1] = 0 },
        categoryToGroup = { [0] = {}, [1] = {} },
        activeGroup = { [0] = 1, [1] = 1 },
        groupsEnabled = { [0] = true, [1] = true },
        __profileSystemMigrated = false,
      },
      char = {},
    }

    StubBetterBagsModule("Events")
    local events = addon:GetModule("Events")
    events.Init = events.Init or function() end
    events.SendMessage = events.SendMessage or function() end
    events.BucketEvent = events.BucketEvent or function() end
    events.RegisterMessage = events.RegisterMessage or function() end

    StubBetterBagsModule("Debug")
    local debug = addon:GetModule("Debug")
    debug.Log = function() end
    debug.Inspect = function() end

    StubBetterBagsModule("BagSlots")
    local slots = addon:GetModule("BagSlots")
    slots.CreatePanel = slots.CreatePanel or function()
      local panel = { frame = CreateFrame("Frame") }
      function panel:IsShown() return self.frame:IsShown() end
      function panel:Show() self.frame:Show() end
      function panel:Hide() self.frame:Hide() end
      function panel:Draw() end
      return panel
    end

    StubBetterBagsModule("SearchBox")
    local search = addon:GetModule("SearchBox")
    search.Create = search.Create or function()
      return CreateFrame("Frame")
    end

    StubBetterBagsModule("Currency")
    local currency = addon:GetModule("Currency")
    currency.CreateIconGrid = currency.CreateIconGrid or function()
      return CreateFrame("Frame")
    end

    StubBetterBagsModule("MoneyFrame")
    local money = addon:GetModule("MoneyFrame")
    money.Create = money.Create or function()
      return { frame = CreateFrame("Frame") }
    end

    StubBetterBagsModule("ContextMenu")
    StubBetterBagsModule("SectionFrame")
    StubBetterBagsModule("Items")

    -- Load real Context, Database, Groups, Tabs
    ResetModuleStub("Context", "core/context.lua")
    LoadBetterBagsModule("core/context.lua")
    LoadBetterBagsModule("core/database.lua")
    LoadBetterBagsModule("data/groups.lua")

    -- Tabs draw their decorations through Sonata's element styles.
    LoadBetterBagsModule("core/async.lua")
    LoadBetterBagsModule("sonata/engine.lua")
    LoadBetterBagsModule("sonata/apply.lua")
    LoadBetterBagsModule("sonata/elements.lua")
    addon:GetModule("Sonata"):Init()
    ResetModuleStub("Tabs", "frames/tabs.lua")
    LoadBetterBagsModule("frames/tabs.lua")
    addon:GetModule("Tabs"):Init()

    -- Setup database defaults
    local DB = addon:GetModule("Database")
    DB.Migrate = function() end
    DB:Init()
    DB.data:ResetProfile(false, true)
  end)

  after_each(function()
    -- Restore original modules to not affect other tests
    addon.modules["BackpackBehavior"] = oldModules["BackpackBehavior"]
    aceAddon.addons["BetterBags_BackpackBehavior"] = oldAddons["BackpackBehavior"]
  end)

  -- Switching designs (next.md §11): a classic backpack switched back on lists its groups as tabs
  -- again, what its groups/* handlers would have done while they were off.
  it("catches up on its tabs when the classic design is switched back on (Resync)", function()
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local behavior = addon:GetModule("BackpackBehavior"):Create({ frame = CreateFrame("Frame") })
    local listed = {}
    behavior.GenerateGroupTabs = function(_, c) table.insert(listed, c) end
    local c = {}
    behavior:Resync(c)
    assert.are.same({ c }, listed)
  end)

  it("should successfully run era backpack OnCreate without crashes", function()
    -- Load base backpack behavior using loadfile directly to bypass load-once logic
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")

    -- Load era override
    local fn, err = loadfile("bags/era/backpack.lua")
    assert.is_not_nil(fn, "Failed to loadfile bags/era/backpack.lua: " .. tostring(err))
    fn("BetterBags")

    -- Create fresh backpack behavior instance
    local parentFrame = CreateFrame("Frame", "BetterBagsBackpack")
    parentFrame.GetFrameLevel = function() return 10 end
    parentFrame.GetFrameStrata = function() return "MEDIUM" end

    local mockBag = {
      frame = parentFrame,
      tabsResizedAfterLoad = false,
    }
    local behavior = backpack:Create(mockBag)

    -- Call OnCreate on the era-overridden backpack behavior
    -- Inside OnCreate, it calls: self.bag.tabs = tabs:Create(self.bag.frame) (pre-fix, missing BAG_KIND)
    -- This should not crash if kind is handled or if we applied the fix.
    assert.has_no.errors(function()
      behavior:OnCreate({})
    end)

    -- The era override must create the bag slots panel and search frame so that
    -- the context menu's "Show Bags" entry (gated on bag.slots) appears on Classic.
    assert.is_not_nil(mockBag.slots, "era backpack OnCreate must create the bag slots panel")
    assert.is_not_nil(mockBag.searchFrame, "era backpack OnCreate must create the search frame")
  end)

  it("hands the currency grid its bag's footer bar, on retail and Classic", function()
    local currency = addon:GetModule("Currency")
    local originalCreate = currency.CreateIconGrid
    local calls = {}
    currency.CreateIconGrid = function(_, parent, footer)
      table.insert(calls, { parent, footer })
      return CreateFrame("Frame")
    end
    for _, override in ipairs({ false, "bags/classic/backpack.lua" }) do
      ResetModuleStub("BackpackBehavior")
      assert(loadfile("bags/backpack.lua"))("BetterBags")
      if override then
        assert(loadfile(override))("BetterBags")
      end
      local backpack = addon:GetModule("BackpackBehavior")
      local parentFrame = CreateFrame("Frame", "BetterBagsBackpack")
      parentFrame.GetFrameLevel = function() return 10 end
      parentFrame.GetFrameStrata = function() return "MEDIUM" end
      local mockBag = { frame = parentFrame, bottomBar = CreateFrame("Frame", nil, parentFrame) }
      backpack:Create(mockBag):OnCreate({})
      local call = calls[#calls]
      assert.are.equal(parentFrame, call[1], tostring(override))
      assert.are.equal(mockBag.bottomBar, call[2], tostring(override))
    end
    currency.CreateIconGrid = originalCreate
  end)

  it("should successfully run classic backpack OnCreate without crashes", function()
    -- Load base backpack behavior using loadfile directly to bypass load-once logic
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")

    -- Load classic override
    local fn, err = loadfile("bags/classic/backpack.lua")
    assert.is_not_nil(fn, "Failed to loadfile bags/classic/backpack.lua: " .. tostring(err))
    fn("BetterBags")

    -- Create fresh backpack behavior instance
    local parentFrame = CreateFrame("Frame", "BetterBagsBackpack")
    parentFrame.GetFrameLevel = function() return 10 end
    parentFrame.GetFrameStrata = function() return "MEDIUM" end

    local mockBag = {
      frame = parentFrame,
      tabsResizedAfterLoad = false,
    }
    local behavior = backpack:Create(mockBag)

    -- Call OnCreate on the classic-overridden backpack behavior
    -- Inside OnCreate, it calls: self.bag.tabs = tabs:Create(self.bag.frame) (pre-fix, missing BAG_KIND)
    -- This should not crash if kind is handled or if we applied the fix.
    assert.has_no.errors(function()
      behavior:OnCreate({})
    end)

    -- The classic override must create the bag slots panel and search frame so that
    -- the context menu's "Show Bags" entry (gated on bag.slots) appears on Classic.
    assert.is_not_nil(mockBag.slots, "classic backpack OnCreate must create the bag slots panel")
    assert.is_not_nil(mockBag.searchFrame, "classic backpack OnCreate must create the search frame")
  end)

  it("should use instant pre-rendered tab swap on SwitchToGroup", function()
    local savedTrigger = addon.TriggerItemContextChanged
    addon.TriggerItemContextChanged = function() end
    finally(function() addon.TriggerItemContextChanged = savedTrigger end)
    -- Load base backpack behavior
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")

    -- Stub dependencies
    local items = StubBetterBagsModule("Items")
    local mockSlotInfo = { [0] = { "mock-slot-info-backpack" } }
    items.GetAllSlotInfo = function()
      return mockSlotInfo
    end

    local events = addon:GetModule("Events")
    local refreshMessageSent = false
    events.SendMessage = function(self, ctx, message)
      if message == "bags/RefreshBackpack" or message == "bags/Rederive" then
        refreshMessageSent = true
      end
    end

    local parentFrame = CreateFrame("Frame", "BetterBagsBackpack")
    local drawCalledWithCtx = nil
    local drawCalledWithSlotInfo = nil
    local mockBag = {
      frame = parentFrame,
      currentItemCount = 0,
      tabs = {
        SetTabByID = function() end
      },
      Draw = function(self, ctx, slotInfo, callback)
        drawCalledWithCtx = ctx
        drawCalledWithSlotInfo = slotInfo
        callback()
      end
    }

    local behavior = backpack:Create(mockBag)
    local ctx = addon:GetModule("Context"):New("TestSwitch")

    behavior:SwitchToGroup(ctx, 1)

    -- Assertions
    assert.is_false(refreshMessageSent, "Should NOT trigger a refresh")
    assert.equal(-1, mockBag.currentItemCount, "Should reset currentItemCount to -1")
    assert.equal(ctx, drawCalledWithCtx, "Should call Draw with the correct context object")
    assert.equal(mockSlotInfo[0], drawCalledWithSlotInfo, "Should call Draw with the correct backpack slotInfo")
  end)

  -- The refresh when the bag closes applies expired Recent Items and collapses held gaps:
  -- both are derived, so the backpack is recalculated from the items already read.
  it("recalculates the backpack, without reading it, when it refreshes on close", function()
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")
    local events = addon:GetModule("Events")
    local savedSend = events.SendMessage
    local sent = {}
    events.SendMessage = function(_, _, message, options)
      table.insert(sent, { message = message, options = options })
    end
    local behavior = backpack:Create({ frame = CreateFrame("Frame") })
    behavior:OnRefresh(addon:GetModule("Context"):New("TestClose"))
    events.SendMessage = savedSend
    assert.equal(1, #sent)
    assert.equal("bags/Rederive", sent[1].message)
    assert.same({ backpack = true, bank = false }, sent[1].options)
  end)

  it("only refreshes cooldowns while shown, and refreshes them whenever the bag opens", function()
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")

    local events = addon:GetModule("Events")
    local savedBucketEvent, savedRegisterMessage = events.BucketEvent, events.RegisterMessage
    local buckets = {}
    events.BucketEvent = function(_, event, cb, filter)
      buckets[event] = { cb = cb, filter = filter }
    end
    events.RegisterMessage = function() end

    local frame = CreateFrame("Frame", "BetterBagsBackpackCooldownTest")
    local refreshes = 0
    local mockBag = {
      frame = frame,
      OnCooldown = function() refreshes = refreshes + 1 end,
    }
    function mockBag:IsShown() return self.frame:IsShown() end

    backpack:Create(mockBag):RegisterEvents()
    events.BucketEvent, events.RegisterMessage = savedBucketEvent, savedRegisterMessage

    local bucket = buckets["BAG_UPDATE_COOLDOWN"]
    assert.is_not_nil(bucket, "BAG_UPDATE_COOLDOWN must be bucketed")
    assert.is_function(bucket.filter, "cooldown fires must be filtered on bag visibility")
    frame:Hide()
    assert.is_false(bucket.filter("BAG_UPDATE_COOLDOWN"), "fires while closed must be dropped")
    frame:Show()
    assert.is_true(bucket.filter("BAG_UPDATE_COOLDOWN"))

    -- Cooldowns that started while the bag was closed must be correct the moment it
    -- opens, whichever path shows the frame (toggle, fade-in, direct Show).
    local onShow = frame:GetScript("OnShow")
    assert.is_function(onShow, "the bag frame must refresh cooldowns in OnShow")
    onShow(frame)
    assert.are.equal(1, refreshes)
  end)

  -- The on-close refresh belongs to the bag frame's OnHide (bagProto:OnClosed), which every
  -- close path fires; refreshing here as well would sweep twice on a normal close. Fading is
  -- the window's (window/window.lua), so the behavior hides the same way with or without it.
  -- bagProto:Show hands every behavior what to call once its window has finished showing
  -- (refresh-scheduler.md §11).
  it("hands the window what to call once it has finished showing", function()
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")
    local savedTrigger = addon.TriggerItemContextChanged
    addon.TriggerItemContextChanged = function() end
    finally(function() addon.TriggerItemContextChanged = savedTrigger end)
    local given
    local mockBag = {
      frame = CreateFrame("Frame", "BetterBagsBackpackShowTest"),
      tabsResizedAfterLoad = true,
      window = { Show = function(_, _, onShown) given = onShown end },
    }
    local onShown = function() end
    backpack:Create(mockBag):OnShow(addon:GetModule("Context"):New("TestShow"), onShown)
    assert.are.equal(onShown, given)
  end)

  it("hides through the bag's window and does not refresh from its own OnHide", function()
    local loadBase = assert(loadfile("bags/backpack.lua"))
    loadBase("BetterBags")
    local backpack = addon:GetModule("BackpackBehavior")

    local savedForceHide = addon.ForceHideBlizzardBags
    addon.ForceHideBlizzardBags = function() end
    local savedTrigger = addon.TriggerItemContextChanged
    local triggered = 0
    addon.TriggerItemContextChanged = function() triggered = triggered + 1 end
    finally(function()
      addon.TriggerItemContextChanged = savedTrigger
      addon.ForceHideBlizzardBags = savedForceHide
    end)

    local refreshes, hides = 0, 0
    local searchHidden = false
    local ctx = addon:GetModule("Context"):New("TestClose")
    local mockBag = {
      frame = CreateFrame("Frame", "BetterBagsBackpackCloseTest"),
      drawOnClose = true,
      Refresh = function() refreshes = refreshes + 1 end,
      searchFrame = { Hide = function() searchHidden = true end },
      window = {
        Hide = function(_, hideCtx, callback)
          assert.are.equal(ctx, hideCtx)
          hides = hides + 1
          callback()
        end,
      },
    }

    backpack:Create(mockBag):OnHide(ctx)

    assert.are.equal(1, hides)
    assert.are.equal(0, refreshes)
    assert.is_true(searchHidden)
    assert.are.equal(1, triggered)
  end)
end)
