local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("Core Init and Enable flow", function()
  local oldOnInitialize, oldOnEnable
  local oldBags
  local originalUISpecialFrames
  local oldBindingFrame
  local oldModules
  local oldAddons
  local oldCCVar

  before_each(function()
    oldBags = addon.Bags
    addon.Bags = {}
    originalUISpecialFrames = _G.UISpecialFrames
    _G.UISpecialFrames = {}
    oldBindingFrame = addon._bindingFrame
    addon._bindingFrame = nil

    oldCCVar = _G.C_CVar
    _G.C_CVar = _G.C_CVar or {
      SetCVar = function() end,
      SetCVarBitfield = function() end,
    }

    -- Save all modules and addons to restore them later
    oldModules = {}
    for k, v in pairs(addon.modules) do
      oldModules[k] = v
    end

    local aceAddon = LibStub("AceAddon-3.0")
    oldAddons = {}
    for k, v in pairs(aceAddon.addons) do
      oldAddons[k] = v
    end

    -- Save original hooks if any
    oldOnInitialize = addon.OnInitialize
    oldOnEnable = addon.OnEnable

    -- Stub all modules that core/init.lua GetModule's
    local modules = {
      "Localization", "Database", "BagFrame", "Constants", "Items", "ItemFrame",
      "Events", "Masque", "SectionFrame", "Categories", "ContextMenu", "Config",
      "Currency", "Search", "ConsolePort", "Pawn", "Question", "SimpleItemLevel",
      "QuickFind", "Refresh", "ItemLoader", "Themes", "Views", "SearchCategoryConfig",
      "Async", "Context", "Debug", "Form", "Bucket", "TooltipScanner", "Groups",
      "EquipmentSets", "BagButton", "ItemRowFrame"
    }

    for _, name in ipairs(modules) do
      local stub = StubBetterBagsModule(name)
      stub.Init = stub.Init or spy.new(function() end)
      stub.Enable = stub.Enable or spy.new(function() end)
    end

    -- Provide specific mock implementations needed by init
    local L = addon:GetModule("Localization")
    L.G = L.G or function(_, val) return val end

    local const = addon:GetModule("Constants")
    const.BAG_KIND = { BACKPACK = 0, BANK = 1 }

    local db = addon:GetModule("Database")
    db.GetEnableBankBag = db.GetEnableBankBag or function() return true end
    db.GetShowBagButton = db.GetShowBagButton or function() return true end

    local eventsMod = addon:GetModule("Events")
    eventsMod.RegisterEvent = eventsMod.RegisterEvent or function() end
    eventsMod.RegisterMessage = eventsMod.RegisterMessage or function() end

    local contextMod = addon:GetModule("Context")
    contextMod.New = contextMod.New or function()
      return {
        Copy = function(self) return self end
      }
    end

    local bagFrame = addon:GetModule("BagFrame")
    bagFrame.Create = spy.new(function(_, ctx, kind)
      return {
        GetName = function() return "MockBag_" .. tostring(kind) end,
        SetTitle = function() end,
      }
    end)

    -- Stub themes:Enable
    local themes = addon:GetModule("Themes")
    themes.Enable = spy.new(function() end)

    -- Stub other global functions that init.lua touches
    _G.ContainerFrameCombinedBags = _G.ContainerFrameCombinedBags or CreateFrame("Frame")
    _G.BagsBar = _G.BagsBar or CreateFrame("Frame")
    _G.BankFrame = _G.BankFrame or CreateFrame("Frame")
    for i = 1, 13 do
      _G["ContainerFrame" .. i] = _G["ContainerFrame" .. i] or CreateFrame("Frame")
    end
    _G.MainMenuBarBackpackButton = _G.MainMenuBarBackpackButton or CreateFrame("Button")
    _G.CharacterBag0Slot = _G.CharacterBag0Slot or CreateFrame("Button")
    _G.CharacterBag1Slot = _G.CharacterBag1Slot or CreateFrame("Button")
    _G.CharacterBag2Slot = _G.CharacterBag2Slot or CreateFrame("Button")
    _G.CharacterBag3Slot = _G.CharacterBag3Slot or CreateFrame("Button")
    _G.KeyRingButton = _G.KeyRingButton or CreateFrame("Button")

    addon.HookScript = function() end
    addon.SecureHook = function() end

    -- Reset core/init.lua load status
    _G.ResetModuleStub("BetterBags", "core/init.lua")
    local fn = assert(loadfile("core/init.lua"))
    fn("BetterBags")
  end)

  after_each(function()
    addon.OnInitialize = oldOnInitialize
    addon.OnEnable = oldOnEnable
    addon.Bags = oldBags
    _G.UISpecialFrames = originalUISpecialFrames
    addon._bindingFrame = oldBindingFrame
    _G.C_CVar = oldCCVar

    -- Restore modules
    addon.modules = {}
    for k, v in pairs(oldModules) do
      addon.modules[k] = v
    end

    -- Restore registered sub-addons
    local aceAddon = LibStub("AceAddon-3.0")
    aceAddon.addons = {}
    for k, v in pairs(oldAddons) do
      aceAddon.addons[k] = v
    end
  end)

  it("should create UI frames during OnInitialize and NOT during OnEnable", function()
    local bagFrame = addon:GetModule("BagFrame")

    -- Call OnInitialize
    addon:OnInitialize()

    -- BagFrame.Create should be called twice (for Backpack and Bank)
    assert.spy(bagFrame.Create).was.called(2)

    -- Reset the spy to see if OnEnable calls it again (it shouldn't)
    bagFrame.Create:clear()

    addon:OnEnable()
    assert.spy(bagFrame.Create).was_not.called()
  end)
end)
