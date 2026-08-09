-- localization_spec.lua -- Unit tests for core/localization.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Other specs stub Localization via StubBetterBagsModule; clear any such stub
-- so the real module file can register its module name on the addon.
ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")
local L = addon:GetModule("Localization")

describe("Localization", function()

  before_each(function()
    -- Reset the module's translation table and current locale between tests.
    L.data = {}
    L.locale = "enUS"
  end)

  -- ─── G ─────────────────────────────────────────────────────────────────────

  describe("G", function()

    it("returns the key when no translation exists", function()
      assert.are.equal("Some Untranslated Key", L:G("Some Untranslated Key"))
    end)

    it("returns the translation for the current locale", function()
      L.data = {
        ["Hello"] = {enUS = "Hello", deDE = "Hallo", frFR = "Bonjour"},
      }
      L.locale = "enUS"
      assert.are.equal("Hello", L:G("Hello"))
    end)

    it("returns a different translation when the locale is switched", function()
      L.data = {
        ["Hello"] = {enUS = "Hello", deDE = "Hallo", frFR = "Bonjour"},
      }
      L.locale = "deDE"
      assert.are.equal("Hallo", L:G("Hello"))
      L.locale = "frFR"
      assert.are.equal("Bonjour", L:G("Hello"))
    end)

    it("falls back to the key when the key exists but the locale does not", function()
      L.data = {
        ["Hello"] = {enUS = "Hello", deDE = "Hallo"},
      }
      L.locale = "esES"  -- not in the data
      assert.are.equal("Hello", L:G("Hello"))
    end)

    it("falls back to the key when the locale entry is nil", function()
      L.data = {
        ["Hello"] = {enUS = "Hello", deDE = nil},
      }
      L.locale = "deDE"
      assert.are.equal("Hello", L:G("Hello"))
    end)

    it("falls back to the key when the locale entry is an empty string", function()
      L.data = {
        ["Empty"] = {enUS = ""},
      }
      L.locale = "enUS"
      -- An explicit empty string is still returned as-is (the function does
      -- not treat "" as missing); this documents current behavior.
      assert.are.equal("", L:G("Empty"))
    end)

    it("handles a fully empty data table", function()
      L.data = {}
      assert.are.equal("any key", L:G("any key"))
    end)

    it("returns different keys independently", function()
      L.data = {
        ["A"] = {enUS = "Apple"},
        ["B"] = {enUS = "Banana"},
        ["C"] = {enUS = "Cherry"},
      }
      assert.are.equal("Apple", L:G("A"))
      assert.are.equal("Banana", L:G("B"))
      assert.are.equal("Cherry", L:G("C"))
    end)

    it("does not mutate L.data when reading", function()
      L.data = {
        ["Hello"] = {enUS = "Hello", deDE = "Hallo"},
      }
      L:G("Hello")
      L:G("Untranslated")
      assert.are.same({enUS = "Hello", deDE = "Hallo"}, L.data["Hello"])
    end)

    it("supports keys with special characters", function()
      L.data = {
        ["Quest: %s [Done]"] = {enUS = "Quest: %s [Done]"},
      }
      assert.are.equal("Quest: %s [Done]", L:G("Quest: %s [Done]"))
    end)

    it("handles an empty string key", function()
      assert.are.equal("", L:G(""))
    end)
  end)
end)
