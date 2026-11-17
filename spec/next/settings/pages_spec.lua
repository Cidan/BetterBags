-- pages_spec.lua -- NextSettingsPages (next/settings/pages.lua): ShowsSetting, whether the settings window shows a
-- setting's row now, as the window decides: a page and a tab shown now, bound to the bag (matched by its kind), a section
-- and a row for the bags in use and not hidden, and a setting the page's bag has (help.md §5).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local catalog = StubBetterBagsModule("SettingsCatalog")
local bagSystem = StubBetterBagsModule("BagSystem")
ResetModuleStub("NextSettingsPages", "next/settings/pages.lua")
LoadBetterBagsModule("next/settings/pages.lua")
local pages = addon:GetModule("NextSettingsPages")

describe("NextSettingsPages", function()
  describe("ShowsSetting", function()
    local saved, design, has

    before_each(function()
      saved = { catalog.Has, bagSystem.ActiveDesign }
      design = "next"
      has = {}
      catalog.Has = function(_, id, bag) return has[id .. ":" .. (bag and bag.kind or "none")] == true end
      bagSystem.ActiveDesign = function() return design end
      pages:Clear()
    end)

    after_each(function()
      catalog.Has, bagSystem.ActiveDesign = saved[1], saved[2]
      pages:Clear()
    end)

    -- define makes a page of one tab of the sections given.
    local function define(def, sections)
      def.group, def.title, def.description = "Group", def.id, def.id
      def.tabs = def.tabs or { { id = "main", title = "Main", sections = sections } }
      pages:Define(def)
    end

    it("shows a setting of no bag on a page of none", function()
      has["fade:none"] = true
      define({ id = "general" }, { { title = "Bags", rows = { { setting = "fade" } } } })
      assert.is_true(pages:ShowsSetting("fade", nil))
      assert.is_false(pages:ShowsSetting("other", nil))
    end)

    it("matches a setting's bag to the page's by its kind, not the table", function()
      has["scale:0"], has["scale:1"] = true, true
      define({ id = "backpack", bag = { name = "Backpack", kind = 0 } }, { { title = "Size", rows = { { setting = "scale" } } } })
      assert.is_true(pages:ShowsSetting("scale", { name = "Backpack", kind = 0 }), "another table of the same bag")
      assert.is_false(pages:ShowsSetting("scale", { name = "Bank", kind = 1 }), "another bag")
      assert.is_false(pages:ShowsSetting("scale", nil), "no bag")
    end)

    it("leaves out a setting the page's bag does not have", function()
      has["scale:0"] = true
      define({ id = "bank", bag = { name = "Bank", kind = 1 } }, { { title = "Size", rows = { { setting = "scale" } } } })
      assert.is_false(pages:ShowsSetting("scale", { name = "Bank", kind = 1 }))
    end)

    it("leaves out a page not shown, and a tab not shown", function()
      has["fade:none"], has["glow:none"] = true, true
      define({ id = "hidden", shown = function() return false end }, { { title = "A", rows = { { setting = "fade" } } } })
      define({ id = "tabs", tabs = {
        { id = "shown", title = "Shown", sections = { { title = "A", rows = {} } } },
        { id = "gone", title = "Gone", shown = function() return false end,
          sections = { { title = "B", rows = { { setting = "glow" } } } } },
      } })
      assert.is_false(pages:ShowsSetting("fade", nil), "on a page not shown")
      assert.is_false(pages:ShowsSetting("glow", nil), "on a tab not shown")
    end)

    it("leaves out a section or a row of the other bags, or hidden", function()
      for _, id in ipairs({ "a", "b", "c", "d" }) do has[id .. ":none"] = true end
      define({ id = "general" }, {
        { title = "Classic", design = "classic", rows = { { setting = "a" } } },
        { title = "Rows", rows = { { setting = "b", design = "classic" }, { setting = "c", hidden = function() return true end } } },
        { title = "Hidden", hidden = function() return true end, rows = { { setting = "d" } } },
      })
      for _, id in ipairs({ "a", "b", "c", "d" }) do
        assert.is_false(pages:ShowsSetting(id, nil), id)
      end
      design = "classic"
      assert.is_true(pages:ShowsSetting("a", nil), "a section of the bags in use")
      assert.is_true(pages:ShowsSetting("b", nil), "a row of the bags in use")
    end)
  end)
end)
