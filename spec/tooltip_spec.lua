-- tooltip_spec.lua -- Unit tests for data/tooltip.lua (TooltipScanner cache)

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

-- For tooltip tests, set addon as non-retail so it tries to create a GameTooltip
-- (which we'll mock). We'll test cache behavior, not extraction.
addon.isRetail = true

-- Mock WorldFrame for Classic path
_G.WorldFrame = {}

-- data/tooltip.lua resolves Events + Context at file scope and, on retail, registers
-- a TOOLTIP_DATA_UPDATE bucket during Init. Reuse the real modules if they already
-- exist; only load them (which marks them loaded so later specs don't double-register)
-- when absent. Then override the two Events methods we need to observe, restoring them
-- on teardown so nothing leaks into specs that run after this file.
local context = addon:GetModule("Context", true)
if not context then
  LoadBetterBagsModule("core/context.lua")
  context = addon:GetModule("Context")
end
if not context.New then
  context.New = function(_, name) return { _name = name, Event = name } end
end

local events = addon:GetModule("Events", true)
if not events then
  LoadBetterBagsModule("core/events.lua")
  events = addon:GetModule("Events")
end
local origBucketEvent, origSendMessage = events.BucketEvent, events.SendMessage
local capturedBucket
local sentMessages = {}
events.BucketEvent = function(_, event, cb)
  if event == "TOOLTIP_DATA_UPDATE" then capturedBucket = cb end
end
events.SendMessage = function(_, _, msg) table.insert(sentMessages, msg) end

ResetModuleStub("TooltipScanner", "data/tooltip.lua")
LoadBetterBagsModule("data/tooltip.lua")
local tooltipScanner = addon:GetModule("TooltipScanner")

describe("TooltipScanner", function()
  local oldCTooltipInfo

  before_each(function()
    oldCTooltipInfo = _G.C_TooltipInfo
    tooltipScanner:Init()
  end)

  after_each(function()
    _G.C_TooltipInfo = oldCTooltipInfo
  end)

  teardown(function()
    events.BucketEvent = origBucketEvent
    events.SendMessage = origSendMessage
  end)

  -- ─── Cache ──────────────────────────────────────────────────────────────────

  describe("Cache", function()

    it("starts with an empty cache", function()
      assert.are.equal(0, tooltipScanner:GetCacheSize())
    end)

    it("caches tooltip text after extraction", function()
      -- Simulate cached text by inserting directly
      tooltipScanner.cache["guid-1"] = "Thunderfury tooltip text"
      assert.are.equal(1, tooltipScanner:GetCacheSize())
    end)

    it("returns cached text on repeat lookups", function()
      tooltipScanner.cache["guid-1"] = "cached tooltip"
      local text = tooltipScanner:GetTooltipText(0, 1, "guid-1")
      assert.are.equal("cached tooltip", text)
    end)

    it("RemoveFromCache removes a specific entry", function()
      tooltipScanner.cache["guid-1"] = "text1"
      tooltipScanner.cache["guid-2"] = "text2"
      tooltipScanner:RemoveFromCache("guid-1")
      assert.is_nil(tooltipScanner.cache["guid-1"])
      assert.are.equal("text2", tooltipScanner.cache["guid-2"])
      assert.are.equal(1, tooltipScanner:GetCacheSize())
    end)

    it("RemoveFromCache is safe for missing GUIDs", function()
      tooltipScanner:RemoveFromCache("nonexistent") -- should not error
    end)

    it("ClearCache removes all entries", function()
      tooltipScanner.cache["guid-1"] = "text1"
      tooltipScanner.cache["guid-2"] = "text2"
      tooltipScanner.cache["guid-3"] = "text3"
      tooltipScanner:ClearCache()
      assert.are.equal(0, tooltipScanner:GetCacheSize())
    end)

    it("GetCacheSize returns correct count", function()
      tooltipScanner.cache["a"] = "1"
      tooltipScanner.cache["b"] = "2"
      tooltipScanner.cache["c"] = "3"
      assert.are.equal(3, tooltipScanner:GetCacheSize())
    end)
  end)

  -- ─── ExtractRetail ──────────────────────────────────────────────────────────

  describe("ExtractRetail", function()

    it("returns nil and bypasses C_TooltipInfo.GetBagItem for battle pet links", function()
      local oldGetContainerItemLink = C_Container.GetContainerItemLink
      local getBagItemCalled = false
      _G.C_TooltipInfo = {
        GetBagItem = function()
          getBagItemCalled = true
          return {lines = {{leftText = "Some Battle Pet Text", rightText = ""}}}
        end,
      }
      C_Container.GetContainerItemLink = function(bagid, slotid)
        return "|cf10307ff|Hbattlepet:123:1:2:3:4:5:0000000000000000|h[Battle Pet Link]|h|r"
      end

      local text = tooltipScanner:ExtractRetail(0, 1)
      C_Container.GetContainerItemLink = oldGetContainerItemLink
      assert.is_nil(text)
      assert.is_false(getBagItemCalled)
    end)

    it("returns nil when C_TooltipInfo is unavailable", function()
      _G.C_TooltipInfo = nil
      local text = tooltipScanner:ExtractRetail(0, 1)
      assert.is_nil(text)
    end)

    it("returns nil when GetBagItem returns nil", function()
      _G.C_TooltipInfo = {
        GetBagItem = function() return nil end,
      }
      local text = tooltipScanner:ExtractRetail(0, 1)
      assert.is_nil(text)
    end)

    it("returns nil when tooltip has no lines", function()
      _G.C_TooltipInfo = {
        GetBagItem = function() return {lines = {}} end,
      }
      local text = tooltipScanner:ExtractRetail(0, 1)
      assert.is_nil(text)
    end)

    it("extracts left and right text from tooltip lines", function()
      _G.C_TooltipInfo = {
        GetBagItem = function()
          return {
            lines = {
              {leftText = "Thunderfury", rightText = ""},
              {leftText = "Item Level 80", rightText = ""},
              {leftText = "Binds when picked up", rightText = ""},
            },
          }
        end,
      }
      local text = tooltipScanner:ExtractRetail(0, 1)
      assert.is_not_nil(text)
      assert.is_truthy(text:find("Thunderfury"))
      assert.is_truthy(text:find("Item Level 80"))
    end)

    it("includes right-aligned text (stat values)", function()
      _G.C_TooltipInfo = {
        GetBagItem = function()
          return {
            lines = {
              {leftText = "Stamina", rightText = "+50"},
            },
          }
        end,
      }
      local text = tooltipScanner:ExtractRetail(0, 1)
      assert.is_truthy(text:find("Stamina"))
      assert.is_truthy(text:find("%+50"))
    end)
  end)

  -- ─── GetTooltipText caching integration ─────────────────────────────────────

  describe("GetTooltipText", function()

    it("caches results from extraction", function()
      _G.C_TooltipInfo = {
        GetBagItem = function()
          return {
            lines = {{leftText = "Test Item", rightText = ""}},
          }
        end,
      }
      local text = tooltipScanner:GetTooltipText(0, 1, "guid-new")
      assert.are.equal("Test Item", text)
      assert.are.equal("Test Item", tooltipScanner.cache["guid-new"])
    end)

    it("returns cached value without re-extracting", function()
      tooltipScanner.cache["guid-cached"] = "previously cached"
      local extractCalled = false
      _G.C_TooltipInfo = {
        GetBagItem = function()
          extractCalled = true
          return {lines = {{leftText = "Fresh", rightText = ""}}}
        end,
      }
      local text = tooltipScanner:GetTooltipText(0, 1, "guid-cached")
      assert.are.equal("previously cached", text)
      assert.is_false(extractCalled)
    end)

    it("does not cache nil/empty extraction results", function()
      _G.C_TooltipInfo = {
        GetBagItem = function() return nil end,
      }
      tooltipScanner:GetTooltipText(0, 1, "guid-nil")
      assert.is_nil(tooltipScanner.cache["guid-nil"])
    end)

    it("does not cache empty string extraction results", function()
      _G.C_TooltipInfo = {
        GetBagItem = function()
          return {lines = {{leftText = "", rightText = ""}}}
        end,
      }
      tooltipScanner:GetTooltipText(0, 1, "guid-empty")
      assert.is_nil(tooltipScanner.cache["guid-empty"])
    end)
  end)

  -- ─── TOOLTIP_DATA_UPDATE resolution (retail sparse tooltips) ────────────────

  describe("TOOLTIP_DATA_UPDATE resolution", function()
    before_each(function()
      for i = #sentMessages, 1, -1 do sentMessages[i] = nil end
      addon.atBank = false
      -- Cold scan: a sparse tooltip (name only, no "Use:" line) carrying instance 555.
      _G.C_TooltipInfo = {
        GetBagItem = function()
          return { dataInstanceID = 555, lines = {{ leftText = "Minor Healing Potion" }} }
        end,
      }
    end)

    it("records a dataInstanceID -> GUID mapping when scanning a retail tooltip", function()
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      assert.are.equal("guid-potion", tooltipScanner.instanceToGUID[555])
      assert.are.equal(555, tooltipScanner.guidToInstance["guid-potion"])
    end)

    it("invalidates the cached tooltip and re-harvests when its instance resolves", function()
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      assert.are.equal("Minor Healing Potion", tooltipScanner.cache["guid-potion"])
      assert.is_function(capturedBucket)

      -- Debounced TOOLTIP_DATA_UPDATE batch resolving instance 555.
      capturedBucket(context:New("t"), { { eventName = "TOOLTIP_DATA_UPDATE", args = { 555 } } })

      assert.is_nil(tooltipScanner.cache["guid-potion"], "stale cache entry must be dropped")
      assert.is_nil(tooltipScanner.instanceToGUID[555])
      assert.is_nil(tooltipScanner.guidToInstance["guid-potion"])
      assert.are.same({ "bags/RefreshBackpack" }, sentMessages)
    end)

    it("re-scans warm on the next lookup after invalidation", function()
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      capturedBucket(context:New("t"), { { eventName = "TOOLTIP_DATA_UPDATE", args = { 555 } } })
      -- The spell line has now loaded; the next scan must pick up the full text.
      _G.C_TooltipInfo.GetBagItem = function()
        return { dataInstanceID = 555, lines = {
          { leftText = "Minor Healing Potion" },
          { leftText = "Use: Restores 70 to 90 health." },
        } }
      end
      local text = tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      assert.is_truthy(text:find("health"))
      assert.is_truthy(tooltipScanner.cache["guid-potion"]:find("health"))
    end)

    it("ignores updates for unknown or nil dataInstanceIDs (no invalidation, no refresh)", function()
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      capturedBucket(context:New("t"), {
        { eventName = "TOOLTIP_DATA_UPDATE", args = { 999 } }, -- unknown instance
        { eventName = "TOOLTIP_DATA_UPDATE", args = { } },     -- nil dataInstanceID
      })
      assert.are.equal("Minor Healing Potion", tooltipScanner.cache["guid-potion"])
      assert.are.equal(0, #sentMessages)
    end)

    it("re-harvests the bank too, but only when at the bank", function()
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      addon.atBank = true
      capturedBucket(context:New("t"), { { eventName = "TOOLTIP_DATA_UPDATE", args = { 555 } } })
      assert.are.same({ "bags/RefreshBackpack", "bags/RefreshBank" }, sentMessages)
    end)

    it("keeps the instance maps 1:1 with the cache when re-scanned under a new instance", function()
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      assert.are.equal("guid-potion", tooltipScanner.instanceToGUID[555])
      -- A later scan of the same GUID reports a different instance id; the old
      -- reverse mapping must not linger.
      tooltipScanner.cache["guid-potion"] = nil
      _G.C_TooltipInfo.GetBagItem = function()
        return { dataInstanceID = 777, lines = {{ leftText = "Minor Healing Potion" }} }
      end
      tooltipScanner:GetTooltipText(0, 1, "guid-potion")
      assert.is_nil(tooltipScanner.instanceToGUID[555], "old instance mapping must be dropped")
      assert.are.equal("guid-potion", tooltipScanner.instanceToGUID[777])
      assert.are.equal(777, tooltipScanner.guidToInstance["guid-potion"])
    end)

    it("does not register the bucket again on repeated Init (no handler leak)", function()
      local count = 0
      local saved = events.BucketEvent
      events.BucketEvent = function(_, event) if event == "TOOLTIP_DATA_UPDATE" then count = count + 1 end end
      tooltipScanner:Init()
      tooltipScanner:Init()
      events.BucketEvent = saved
      assert.are.equal(0, count, "already hooked; further Inits must not re-register")
    end)
  end)

  -- ─── ExtractClassic ─────────────────────────────────────────────────────────

  describe("ExtractClassic", function()

    local originalIsRetail
    local originalScanTooltip

    before_each(function()
      originalIsRetail = addon.isRetail
      addon.isRetail = false
      -- Re-run Init so it creates the scanTooltip frame for Classic.
      tooltipScanner:Init()
      originalScanTooltip = tooltipScanner.scanTooltip
    end)

    after_each(function()
      addon.isRetail = originalIsRetail
      tooltipScanner.scanTooltip = originalScanTooltip
    end)

    it("returns nil when scanTooltip is not initialized", function()
      tooltipScanner.scanTooltip = nil
      local text = tooltipScanner:ExtractClassic(0, 1)
      assert.is_nil(text)
    end)

    it("returns nil when the tooltip has no lines", function()
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 0 end,
      }
      local text = tooltipScanner:ExtractClassic(0, 1)
      assert.is_nil(text)
    end)

    it("extracts text from left-aligned FontStrings", function()
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 2 end,
      }
      _G["BetterBagsScanTooltipTextLeft1"] = {GetText = function() return "Item Name" end}
      _G["BetterBagsScanTooltipTextRight1"] = nil
      _G["BetterBagsScanTooltipTextLeft2"] = {GetText = function() return "Binds when picked up" end}
      _G["BetterBagsScanTooltipTextRight2"] = nil
      local text = tooltipScanner:ExtractClassic(0, 1)
      assert.is_not_nil(text)
      assert.is_truthy(text:find("Item Name"))
      assert.is_truthy(text:find("Binds when picked up"))
    end)

    it("extracts text from right-aligned FontStrings (stat values)", function()
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 1 end,
      }
      _G["BetterBagsScanTooltipTextLeft1"] = {GetText = function() return "Stamina" end}
      _G["BetterBagsScanTooltipTextRight1"] = {GetText = function() return "+42" end}
      local text = tooltipScanner:ExtractClassic(0, 1)
      assert.is_not_nil(text)
      assert.is_truthy(text:find("Stamina"))
      assert.is_truthy(text:find("%+42"))
    end)

    it("skips FontStrings that return empty text", function()
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 2 end,
      }
      _G["BetterBagsScanTooltipTextLeft1"] = {GetText = function() return "" end}
      _G["BetterBagsScanTooltipTextRight1"] = nil
      _G["BetterBagsScanTooltipTextLeft2"] = {GetText = function() return "Second Line" end}
      _G["BetterBagsScanTooltipTextRight2"] = nil
      local text = tooltipScanner:ExtractClassic(0, 1)
      assert.is_not_nil(text)
      assert.is_falsy(text:find("^%s*$"))
      assert.is_truthy(text:find("Second Line"))
    end)

    it("caps iteration at 30 lines (Classic FontString bug workaround)", function()
      -- Simulate 100 lines but only 30 should be read
      local readCount = 0
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 100 end,
      }
      for i = 1, 100 do
        _G["BetterBagsScanTooltipTextLeft" .. i] = {
          GetText = function() readCount = readCount + 1; return "line" end,
        }
        _G["BetterBagsScanTooltipTextRight" .. i] = nil
      end
      tooltipScanner:ExtractClassic(0, 1)
      assert.is_true(readCount <= 30)
    end)

    it("returns nil when all lines are empty", function()
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 2 end,
      }
      _G["BetterBagsScanTooltipTextLeft1"] = {GetText = function() return "" end}
      _G["BetterBagsScanTooltipTextRight1"] = nil
      _G["BetterBagsScanTooltipTextLeft2"] = {GetText = function() return "" end}
      _G["BetterBagsScanTooltipTextRight2"] = nil
      local text = tooltipScanner:ExtractClassic(0, 1)
      assert.is_nil(text)
    end)
  end)

  -- ─── GetTooltipText Classic path ────────────────────────────────────────────

  describe("GetTooltipText (Classic)", function()

    local originalIsRetail
    local originalScanTooltip

    before_each(function()
      originalIsRetail = addon.isRetail
      addon.isRetail = false
      tooltipScanner:Init()
      originalScanTooltip = tooltipScanner.scanTooltip
    end)

    after_each(function()
      addon.isRetail = originalIsRetail
      tooltipScanner.scanTooltip = originalScanTooltip
    end)

    it("extracts via the Classic path when not on retail", function()
      tooltipScanner.scanTooltip = {
        ClearLines = function() end,
        SetBagItem = function() end,
        NumLines = function() return 1 end,
      }
      _G["BetterBagsScanTooltipTextLeft1"] = {GetText = function() return "Classic Tooltip" end}
      _G["BetterBagsScanTooltipTextRight1"] = nil
      local text = tooltipScanner:GetTooltipText(0, 1, "classic-guid")
      assert.are.equal("Classic Tooltip", text)
      assert.are.equal("Classic Tooltip", tooltipScanner.cache["classic-guid"])
    end)
  end)

  -- ─── Init ───────────────────────────────────────────────────────────────────

  describe("Init", function()

    it("creates a scanTooltip frame for non-retail clients", function()
      local originalIsRetail = addon.isRetail
      addon.isRetail = false
      local oldWorldFrame = _G.WorldFrame
      local oldCreateFrame = _G.CreateFrame
      _G.WorldFrame = {}
      local frames = {}
      _G.CreateFrame = function(_, name, _, _)
        local f = {
          SetOwner = function() end,
        }
        table.insert(frames, f)
        return f
      end
      tooltipScanner:Init()
      addon.isRetail = originalIsRetail
      _G.WorldFrame = oldWorldFrame
      _G.CreateFrame = oldCreateFrame
      assert.is_not_nil(tooltipScanner.scanTooltip)
      assert.is_true(#frames >= 1)
    end)

    it("uses nil scanTooltip on retail clients (C_TooltipInfo path)", function()
      local originalIsRetail = addon.isRetail
      addon.isRetail = true
      tooltipScanner:Init()
      addon.isRetail = originalIsRetail
      assert.is_nil(tooltipScanner.scanTooltip)
    end)

    it("resets the cache", function()
      tooltipScanner.cache["x"] = "old"
      tooltipScanner:Init()
      assert.are.equal(0, tooltipScanner:GetCacheSize())
    end)
  end)
end)
