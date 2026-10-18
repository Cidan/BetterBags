-- tabs_spec.lua -- NextTabs (next/tabs.lua): the backpack's groups as tabs down the body's left
-- edge, sticking out like bookmarks; the selected one is brighter, with a gold bar that glides to
-- it, and a hovered one slides out (next.md §3).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
ResetModuleStub("NextTween", "next/tween.lua")
LoadBetterBagsModule("next/tween.lua")
ResetModuleStub("NextTabs", "next/tabs.lua")
LoadBetterBagsModule("next/tabs.lua")
local nextTabs = addon:GetModule("NextTabs")
local tween = addon:GetModule("NextTween")
local style = addon:GetModule("NextStyle")

describe("NextTabs", function()
  local body, rail, clicks

  before_each(function()
    tween:Init()
    body = CreateFrame("Frame")
    body:Show()
    rail = nextTabs:Create(body)
    clicks = {}
    rail:SetClickHandler(function(ctx, id, button)
      assert.is_not_nil(ctx)
      table.insert(clicks, { id, button })
    end)
  end)

  local function finishTweens()
    for _ = 1, 100 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local groups = { { id = 1, name = "Backpack" }, { id = 2, name = "Consumables" }, { id = 0, name = "+" } }

  it("hangs from the body's left edge, below the header", function()
    assert.are.same({ "TOPRIGHT", body, "TOPLEFT", 0, -style.CONTENT_TOP }, { rail.frame:GetPoint(1) })
  end)

  it("stacks a tab per group down the rail, each sticking out by its name's width", function()
    rail:SetTabs(groups)
    assert.are.equal(3, #rail.tabs)
    local step = style.TAB_HEIGHT + style.TAB_SPACING
    for i, tab in ipairs(rail.tabs) do
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(i - 1) * step }, { tab.button:GetPoint(1) })
      assert.is_true(tab.button:IsShown())
      assert.are.equal(style.TAB_HEIGHT, tab.button:GetHeight())
    end
    assert.are.equal("Consumables", rail.tabs[2].text:GetText())
    assert.are.equal(#"Consumables" * 6 + style.TAB_PADDING * 2, rail.tabs[2].button:GetWidth())
    assert.are.equal(style.TAB_MIN_WIDTH, rail.tabs[3].button:GetWidth(), "never narrower than the minimum")
  end)

  it("caps a long name's tab at the widest a tab may be", function()
    rail:SetTabs({ { id = 1, name = string.rep("x", 60) } })
    assert.are.equal(style.TAB_MAX_WIDTH, rail.tabs[1].button:GetWidth())
  end)

  it("draws the selected tab bright and moves the gold bar to it, gliding when asked", function()
    rail:SetTabs(groups)
    rail:Select(1)
    assert.are.equal(style:Font("TabSelected"), rail.tabs[1].text:GetFontObject())
    assert.are.equal(style:Font("Tab"), rail.tabs[2].text:GetFontObject())
    assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, 0 }, { rail.indicator:GetPoint(1) })
    rail:Select(2, true)
    assert.are.equal(style:Font("TabSelected"), rail.tabs[2].text:GetFontObject())
    assert.are.equal(style:Font("Tab"), rail.tabs[1].text:GetFontObject())
    local _, _, _, _, y = rail.indicator:GetPoint(1)
    assert.are.equal(0, y, "glides from where it was")
    finishTweens()
    local step = style.TAB_HEIGHT + style.TAB_SPACING
    assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, { rail.indicator:GetPoint(1) })
    assert.is_true(rail.indicator:IsShown())
  end)

  it("hides the gold bar when no tab is selected", function()
    rail:SetTabs(groups)
    rail:Select(1)
    assert.is_true(rail.indicator:IsShown())
    rail:Select(42)
    assert.is_false(rail.indicator:IsShown())
  end)

  it("puts the gold bar on the selected tab at once when not asked to glide", function()
    rail:SetTabs(groups)
    rail:Select(1)
    rail:Select(2)
    local step = style.TAB_HEIGHT + style.TAB_SPACING
    assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, { rail.indicator:GetPoint(1) })
    assert.is_false(tween:IsPlaying(rail.indicator))
  end)

  it("tells its handler which tab was clicked, and with which button", function()
    rail:SetTabs(groups)
    local button = rail.tabs[2].button
    button:GetScript("OnClick")(button, "RightButton")
    assert.are.same({ { 2, "RightButton" } }, clicks)
  end)

  it("slides a hovered tab out, and back when the pointer leaves", function()
    rail:SetTabs(groups)
    local button = rail.tabs[2].button
    button:GetScript("OnEnter")(button)
    finishTweens()
    local _, _, _, x = button:GetPoint(1)
    assert.are.equal(-style.TAB_HOVER, x)
    button:GetScript("OnLeave")(button)
    finishTweens()
    _, _, _, x = button:GetPoint(1)
    assert.are.equal(0, x)
  end)

  it("reuses its tabs when the groups change, hiding the ones it no longer needs", function()
    rail:SetTabs(groups)
    local first = rail.tabs[1].button
    rail:SetTabs({ { id = 1, name = "Backpack" } })
    assert.are.equal(1, #rail.tabs)
    assert.are.equal(first, rail.tabs[1].button)
    local hidden = 0
    for _, tab in ipairs(rail.pool) do
      if not tab.button:IsShown() then hidden = hidden + 1 end
    end
    assert.are.equal(2, hidden)
    rail:SetTabs(groups)
    assert.are.equal(3, #rail.tabs)
    assert.are.equal(0, #rail.pool, "the hidden tabs are used again")
  end)
end)
