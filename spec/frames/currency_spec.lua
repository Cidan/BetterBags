local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Real modules the currency frame depends on.
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
local events = addon:GetModule("Events")
events:Init()

-- Stubbed dependencies needed to load frames/currency.lua.
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end

local const = StubBetterBagsModule("Constants")
const.OFFSETS = const.OFFSETS or { BAG_LEFT_INSET = 0, BAG_BOTTOM_INSET = 0 }

-- Minimal Grid stub: currency:CreateIconGrid calls grid:Create directly and then
-- drives the returned grid, so the fake grid must implement the surface the
-- currency module touches.
local grid = StubBetterBagsModule("Grid")
grid.Create = function()
  local container = {
    ClearAllPoints = function() end,
    SetPoint = function() end,
    SetWidth = function() end,
    SetSize = function() end,
  }
  local g = { cells = {} }
  function g:GetContainer() return container end
  function g:HideScrollBar() end
  function g:EnableMouseWheelScroll() end
  function g:Wipe() self.cells = {} end
  function g:AddCell(key, item) self.cells[key] = item end
  function g:Draw() return 0, 0 end
  return g
end

ResetModuleStub("Currency", "frames/currency.lua")
LoadBetterBagsModule("frames/currency.lua")
local currency = addon:GetModule("Currency")

describe("Currency icon grid", function()
  describe("Classic legacy currency globals (no C_CurrencyInfo namespace)", function()
    local savedNamespace
    local expandCalls

    before_each(function()
      savedNamespace = _G.C_CurrencyInfo
      _G.C_CurrencyInfo = nil
      expandCalls = {}
      _G.GetCurrencyListSize = function() return 1 end
      -- Order matches getCurrencyInfo(): name, isHeader, isExpanded, isUnused,
      -- isWatched, count, icon, maximum, hasWeeklyLimit, currentWeeklyAmount,
      -- unknown, itemID. A single header row forces the expand branch.
      _G.GetCurrencyListInfo = function(index)
        return "Header " .. index, true, false, false, false, 0, 0, 0, false, 0, 0, 0
      end
      -- Faithful to the Classic C contract (warcraft.wiki.gg API:ExpandCurrencyList):
      -- expand is a Number (0 = collapse, 1 = expand). Passing a boolean raises the
      -- game's "Usage: ExpandCurrencyList(index,expand)" C-level error.
      _G.ExpandCurrencyList = function(index, expand)
        if type(index) ~= "number" or type(expand) ~= "number" then
          error("Usage: ExpandCurrencyList(index,expand)")
        end
        table.insert(expandCalls, { index = index, expand = expand })
      end
    end)

    after_each(function()
      _G.C_CurrencyInfo = savedNamespace
      _G.GetCurrencyListSize = nil
      _G.GetCurrencyListInfo = nil
      _G.ExpandCurrencyList = nil
    end)

    it("passes a numeric expand flag (1), not a boolean, to the legacy global", function()
      assert.has_no.errors(function()
        currency:CreateIconGrid(CreateFrame("Frame"))
      end)
      assert.equal(1, expandCalls[1].expand)
    end)
  end)

  describe("Retail C_CurrencyInfo namespace", function()
    local savedNamespace
    local expandCalls

    before_each(function()
      savedNamespace = _G.C_CurrencyInfo
      expandCalls = {}
      _G.C_CurrencyInfo = {
        GetCurrencyListSize = function() return 1 end,
        GetCurrencyListInfo = function()
          return { name = "Header", isHeader = true, isShowInBackpack = false }
        end,
        -- The modern namespace takes a boolean (CurrencyInfoDocumentation.lua).
        ExpandCurrencyList = function(index, expand)
          if type(expand) ~= "boolean" then
            error("C_CurrencyInfo.ExpandCurrencyList expects a boolean expand flag")
          end
          table.insert(expandCalls, { index = index, expand = expand })
        end,
      }
    end)

    after_each(function()
      _G.C_CurrencyInfo = savedNamespace
    end)

    it("passes a boolean expand flag to the modern namespace", function()
      assert.has_no.errors(function()
        currency:CreateIconGrid(CreateFrame("Frame"))
      end)
      assert.equal(true, expandCalls[1].expand)
    end)
  end)
end)
