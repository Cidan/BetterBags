-- Regression coverage for the bag-bar backpack button (far-right button in the
-- Blizzard BagsBar) no longer opening BetterBags.
--
-- Root cause: the OnClick hook loop was changed from the native
-- `button:HookScript("OnClick", ...)` (commit b5576f2, "Clicking the bag button
-- now works again") to the malformed AceHook dot-call
-- `addon.HookScript(button, "OnClick", ...)` (commit b029d3a). The dot-call
-- passes the frame as `self` and the script name as the object, so AceHook
-- throws "'object' - nil or table expected got string". It never installed a
-- hook; it was only harmless because it originally ran at the very end of
-- OnInitialize. The manual-init refactor moved the loop into the MIDDLE of
-- OnInitialize, so the throw now aborts everything after it (bank creation,
-- themes:Enable, SetTitle, UISpecialFrames registration).
--
-- These tests use the REAL AceHook (they do NOT stub addon.HookScript) so the
-- production throw reproduces, and they only reload core/init.lua so its module
-- upvalues bind to the stubs below. The click handlers are exercised by spying
-- on addon.ToggleAllBags, so the (un-reloaded) hooks.lua internals never run.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("Bag-bar backpack button click", function()
  local oldOnInitialize, oldOnEnable, oldToggleAllBags
  local oldBags, originalUISpecialFrames, oldBindingFrame
  local oldModules, oldAddons, oldCCVar, oldEnum

  before_each(function()
    oldBags = addon.Bags
    addon.Bags = {}
    originalUISpecialFrames = _G.UISpecialFrames
    _G.UISpecialFrames = {}
    oldBindingFrame = addon._bindingFrame
    addon._bindingFrame = nil
    oldToggleAllBags = addon.ToggleAllBags

    oldCCVar = _G.C_CVar
    _G.C_CVar = _G.C_CVar or { SetCVar = function() end, SetCVarBitfield = function() end }

    oldEnum = _G.Enum
    _G.Enum = _G.Enum or {}
    _G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or
      setmetatable({}, { __index = function(_, k) return k end })

    oldModules = {}
    for k, v in pairs(addon.modules) do oldModules[k] = v end
    local aceAddon = LibStub("AceAddon-3.0")
    oldAddons = {}
    for k, v in pairs(aceAddon.addons) do oldAddons[k] = v end

    oldOnInitialize = addon.OnInitialize
    oldOnEnable = addon.OnEnable

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
      stub.Init = stub.Init or function() end
      stub.Enable = stub.Enable or function() end
    end

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
    eventsMod.SendMessage = eventsMod.SendMessage or function() end
    eventsMod.SendMessageLater = eventsMod.SendMessageLater or function() end

    local contextMod = addon:GetModule("Context")
    contextMod.New = contextMod.New or function()
      return { Copy = function(self) return self end }
    end

    local bagFrame = addon:GetModule("BagFrame")
    bagFrame.Create = function(_, _, kind)
      local frame = CreateFrame("Frame")
      frame:SetShown(false)
      return {
        frame = frame,
        GetName = function() return "MockBag_" .. tostring(kind) end,
        SetTitle = function() end,
        IsShown = function() return frame:IsShown() end,
      }
    end

    local themes = addon:GetModule("Themes")
    themes.Enable = function() end

    _G.ContainerFrameCombinedBags = _G.ContainerFrameCombinedBags or CreateFrame("Frame")
    _G.BagsBar = _G.BagsBar or CreateFrame("Frame")
    _G.BankFrame = _G.BankFrame or CreateFrame("Frame")
    for i = 1, 13 do
      _G["ContainerFrame" .. i] = _G["ContainerFrame" .. i] or CreateFrame("Frame")
    end

    local function makeBagButton()
      local b = CreateFrame("Button")
      b.HasScript = function() return true end
      b.IsProtected = function() return false, false end
      b.RegisterForClicks = function() end
      b.RegisterForDrag = function() end
      b.SlotHighlightTexture = {
        shown = false,
        SetShown = function(self, value) self.shown = value end,
      }
      return b
    end
    _G.MainMenuBarBackpackButton = makeBagButton()
    _G.CharacterBag0Slot = makeBagButton()
    _G.CharacterBag1Slot = makeBagButton()
    _G.CharacterBag2Slot = makeBagButton()
    _G.CharacterBag3Slot = makeBagButton()
    _G.KeyRingButton = makeBagButton()

    -- Reload ONLY core/init.lua so its upvalues bind to the stubs above.
    -- Crucially, do NOT stub addon.HookScript here: the production throw must
    -- reproduce.
    _G.ResetModuleStub("BetterBags", "core/init.lua")
    local fn = assert(loadfile("core/init.lua"))
    fn("BetterBags")
  end)

  after_each(function()
    addon.OnInitialize = oldOnInitialize
    addon.OnEnable = oldOnEnable
    addon.ToggleAllBags = oldToggleAllBags
    addon.Bags = oldBags
    _G.UISpecialFrames = originalUISpecialFrames
    addon._bindingFrame = oldBindingFrame
    _G.C_CVar = oldCCVar
    _G.Enum = oldEnum

    addon.modules = {}
    for k, v in pairs(oldModules) do addon.modules[k] = v end
    local aceAddon = LibStub("AceAddon-3.0")
    aceAddon.addons = {}
    for k, v in pairs(oldAddons) do aceAddon.addons[k] = v end
  end)

  it("runs OnInitialize to completion without aborting on the hook loop", function()
    -- SetTitle and UISpecialFrames registration run AFTER the button hook loop.
    -- If the loop throws, they never execute and UISpecialFrames stays empty.
    local ok = pcall(function() addon:OnInitialize() end)
    assert.is_true(ok)
    assert.is_true(#_G.UISpecialFrames > 0)
  end)

  it("opens the bag with exactly one toggle when the main backpack button is clicked", function()
    pcall(function() addon:OnInitialize() end)

    local count = 0
    addon.ToggleAllBags = function() count = count + 1 end

    local onclick = _G.MainMenuBarBackpackButton:GetScript("OnClick")
    assert.is_function(onclick)
    onclick(_G.MainMenuBarBackpackButton, "LeftButton")

    assert.are.equal(1, count)
  end)

  it("toggles BetterBags when an auxiliary bag-slot button is clicked", function()
    pcall(function() addon:OnInitialize() end)

    local count = 0
    addon.ToggleAllBags = function() count = count + 1 end

    local onclick = _G.CharacterBag0Slot:GetScript("OnClick")
    assert.is_function(onclick)
    onclick(_G.CharacterBag0Slot, "LeftButton")

    assert.are.equal(1, count)
  end)

  -- The "X" close button and ESC both hide the backpack frame directly, bypassing
  -- addon:ToggleAllBags/addon.OnUpdate (the only callers of UpdateButtonHighlight).
  -- The frame's own OnShow/OnHide must drive the bag-bar highlight so it never sticks
  -- lit after the bag is closed by any path.
  it("clears the bag-bar highlight when the backpack frame hides (X / ESC path)", function()
    pcall(function() addon:OnInitialize() end)

    local frame = addon.Bags.Backpack.frame

    -- Simulate the bag opening: frame shown, OnShow fires -> highlight lit.
    frame:SetShown(true)
    local onShow = frame:GetScript("OnShow")
    assert.is_function(onShow)
    onShow(frame)
    assert.is_true(_G.MainMenuBarBackpackButton.SlotHighlightTexture.shown)

    -- Simulate the X button / ESC hiding the frame directly.
    frame:SetShown(false)
    local onHide = frame:GetScript("OnHide")
    assert.is_function(onHide)
    onHide(frame)
    assert.is_false(_G.MainMenuBarBackpackButton.SlotHighlightTexture.shown)
    assert.is_false(_G.CharacterBag0Slot.SlotHighlightTexture.shown)
  end)
end)
