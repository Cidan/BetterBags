local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local aceAddon = LibStub("AceAddon-3.0")
_G.PanelTemplates_TabResize = _G.PanelTemplates_TabResize or function() end
_G.GetAppropriateTooltip = _G.GetAppropriateTooltip or function() return GameTooltip end
_G.GameTooltip.IsOwned = _G.GameTooltip.IsOwned or function() return false end

describe("Backpack Module Loading and Compatibility Tests", function()
  local oldModules = {}
  local oldAddons = {}
  local oldGetTabButton

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
    const.BAG_VIEW = { UNDEFINED = 0, ONE_BAG = 1, SECTION_GRID = 2, LIST = 3, SECTION_ALL_BAGS = 4 }
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
        extraGlowyButtons = { [0] = false, [1] = false },
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
        collapsedSections = { [0] = {}, [1] = {} },
        size = {
          [1] = {
            [0] = { columnCount = 15, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
            [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
          },
          [2] = {
            [0] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89 },
            [1] = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89 },
          },
          [3] = {
            [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
            [1] = { columnCount = 5, itemsPerRow = 5, scale = 100, width = 700, height = 500, opacity = 89 },
          },
          [4] = {
            [0] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
            [1] = { columnCount = 1, itemsPerRow = 15, scale = 100, width = 700, height = 500, opacity = 89 },
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
    events.OnInitialize = events.OnInitialize or function() end
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
      return { frame = CreateFrame("Frame") }
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

    StubBetterBagsModule("ThemeConfig")
    local tc = addon:GetModule("ThemeConfig")
    tc.Create = tc.Create or function()
      return CreateFrame("Frame")
    end

    StubBetterBagsModule("MoneyFrame")
    local money = addon:GetModule("MoneyFrame")
    money.Create = money.Create or function()
      return { frame = CreateFrame("Frame") }
    end

    StubBetterBagsModule("ContextMenu")
    StubBetterBagsModule("SectionFrame")

    -- Load real Context, Database, Groups, Tabs
    ResetModuleStub("Context", "core/context.lua")
    LoadBetterBagsModule("core/context.lua")
    LoadBetterBagsModule("core/database.lua")
    LoadBetterBagsModule("data/groups.lua")

    -- Mock/Stub Themes before loading Tabs
    local themes = StubBetterBagsModule("Themes")
    oldGetTabButton = themes.GetTabButton
    themes.GetTabButton = function(self, ctx, tab)
      local decoration = CreateFrame("Button")
      decoration.Enable = decoration.Enable or function() end
      decoration.Disable = decoration.Disable or function() end
      decoration.SetDisabledFontObject = decoration.SetDisabledFontObject or function() end
      decoration.Text = decoration:CreateFontString()
      decoration.Text.SetFontObject = decoration.Text.SetFontObject or function() end
      decoration.Left = decoration:CreateTexture()
      decoration.Middle = decoration:CreateTexture()
      decoration.Right = decoration:CreateTexture()
      decoration.LeftActive = decoration:CreateTexture()
      decoration.MiddleActive = decoration:CreateTexture()
      decoration.RightActive = decoration:CreateTexture()
      return decoration
    end

    LoadBetterBagsModule("frames/tabs.lua")

    -- Setup database defaults
    local DB = addon:GetModule("Database")
    DB.Migrate = function() end
    DB:OnInitialize()
    DB.data:ResetProfile(false, true)
  end)

  after_each(function()
    -- Restore themes
    local themes = addon:GetModule("Themes")
    themes.GetTabButton = oldGetTabButton

    -- Restore original modules to not affect other tests
    addon.modules["BackpackBehavior"] = oldModules["BackpackBehavior"]
    aceAddon.addons["BetterBags_BackpackBehavior"] = oldAddons["BackpackBehavior"]
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
  end)
end)
