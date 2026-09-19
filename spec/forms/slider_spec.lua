-- slider_spec.lua -- Unit tests for the stacked form layout's slider.
--
-- Regression coverage for the "slider description does not wrap" bug. Every
-- other widget in stacked.lua bounds its description FontString with both a
-- TOPLEFT and a RIGHT anchor so SetWordWrap can wrap the text; AddSlider only
-- set TOPLEFT, leaving the FontString unbounded so the description ran off the
-- frame edge on a single clipped line (seen on "Quality Glow Intensity").

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

-- Animations is referenced at file scope by stacked.lua but only used by the
-- tab/pane paths, so a stub suffices for the slider path.
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

---Return the single slider container registered on a layout.
local function onlySlider(layout)
  local found
  for container in pairs(layout.sliders) do
    found = container
  end
  return found
end

---True when the FontString has a point whose own anchor or relative anchor is RIGHT.
local function hasRightAnchor(fs)
  for _, p in ipairs(fs._points) do
    if p.point == "RIGHT" or p.relativePoint == "RIGHT" then
      return true
    end
  end
  return false
end

describe("stacked layout slider", function()
  local savedIsRetail
  before_each(function()
    savedIsRetail = addon.isRetail
    addon.isRetail = true
  end)
  after_each(function()
    addon.isRetail = savedIsRetail
  end)

  it("bounds the description with a RIGHT anchor so the text word-wraps", function()
    local layout = newLayout()
    layout:AddSlider({
      title = "Quality Glow Intensity",
      description = "How strongly item buttons show their quality color, from 0 to 100. "
        .. "At 0 there is no border at all. Up to 60 it is a flat colored border that fades in. "
        .. "Above 60 the glowing halo alphas in, reaching a blinding maximum at 100.",
      min = 0,
      max = 100,
      step = 1,
      getValue = function() return 60 end,
      setValue = function() end,
    })

    local container = onlySlider(layout)
    assert.is_not_nil(container, "a slider container must be registered")
    assert.is_true(container.description._wordWrap,
      "the description must have word wrap enabled")
    assert.is_true(hasRightAnchor(container.description),
      "the description must be bounded on the right so it can wrap instead of clipping")
  end)
end)
