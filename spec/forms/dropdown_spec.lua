-- dropdown_spec.lua -- Unit tests for the stacked form layout's dropdown.
--
-- Regression coverage for the "Pawn is registered but never shows in the Upgrade
-- Icon Provider dropdown" bug. The dropdown's item list used to be snapshotted
-- once at pane-build time, so any provider that registered afterwards (Pawn
-- enables after Config in core/init.lua, and can register even later via
-- ADDON_LOADED) never appeared. The fix resolves opts.itemsFunction lazily on
-- every menu generation.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

-- Animations is referenced at file scope by stacked.lua but only used by the
-- tab/pane paths, so a stub suffices for the dropdown path.
local animations = StubBetterBagsModule("Animations")
animations.AttachFadeGroup = animations.AttachFadeGroup or function() return {}, {} end

LoadBetterBagsModule("forms/layouts/layout.lua")
LoadBetterBagsModule("forms/layouts/stacked.lua")

local layouts = addon:GetModule("FormLayouts")

---Build a fresh stacked layout backed by mock frames.
---@return FormLayout
local function newLayout()
  local targetFrame = CreateFrame("Frame")
  local baseFrame = CreateFrame("Frame")
  local scrollBox = CreateFrame("Frame")
  return layouts:NewStackedLayout(targetFrame, baseFrame, scrollBox, false, false)
end

---Return the single dropdown container registered on a layout.
local function onlyDropdown(layout)
  local found
  for container in pairs(layout.dropdowns) do
    found = container
  end
  return found
end

describe("stacked layout dropdown (retail)", function()
  local savedIsRetail
  before_each(function()
    savedIsRetail = addon.isRetail
    addon.isRetail = true
  end)
  after_each(function()
    addon.isRetail = savedIsRetail
  end)

  it("resolves itemsFunction lazily so late-registered entries appear on regenerate", function()
    local layout = newLayout()

    -- The provider list as it stands when the pane is built: Pawn has NOT
    -- registered yet (it enables after Config in core/init.lua).
    local providers = { "None", "BetterBags" }

    local queried = 0
    layout:AddDropdown({
      title = "Upgrade Icon Provider",
      description = "Select the icon provider for item upgrades.",
      itemsFunction = function()
        queried = queried + 1
        local copy = {}
        for i, v in ipairs(providers) do copy[i] = v end
        return copy
      end,
      getValue = function(_, value) return value == "None" end,
      setValue = function() end,
    })

    local container = onlyDropdown(layout)
    assert.is_not_nil(container)

    -- At build time the menu reflects only what was registered then.
    assert.are.same({ "None", "BetterBags" }, container.dropdown._lastMenuItems)

    -- Pawn registers later; regenerating the menu (reopen / ReloadAllFormElements)
    -- must pick it up without rebuilding the pane.
    table.insert(providers, "Pawn")
    container.dropdown:Update()

    assert.are.same({ "None", "BetterBags", "Pawn" }, container.dropdown._lastMenuItems)
    -- itemsFunction was consulted on both the build and the regenerate.
    assert.is_true(queried >= 2)
  end)

  it("regenerating via ReloadAllFormElements re-queries the item list", function()
    local layout = newLayout()
    local providers = { "None", "BetterBags" }
    layout:AddDropdown({
      title = "Provider",
      description = "d",
      itemsFunction = function()
        local copy = {}
        for i, v in ipairs(providers) do copy[i] = v end
        return copy
      end,
      getValue = function() return false end,
      setValue = function() end,
    })

    table.insert(providers, "SimpleItemLevel")
    layout:ReloadAllFormElements()

    local container = onlyDropdown(layout)
    assert.are.same({ "None", "BetterBags", "SimpleItemLevel" }, container.dropdown._lastMenuItems)
  end)

  it("still supports a static items list", function()
    local layout = newLayout()
    layout:AddDropdown({
      title = "Static",
      description = "d",
      items = { "A", "B", "C" },
      getValue = function() return false end,
      setValue = function() end,
    })
    local container = onlyDropdown(layout)
    assert.are.same({ "A", "B", "C" }, container.dropdown._lastMenuItems)
  end)
end)
