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

  -- A chained bag's place is computed from the rails' widths (next.md §12): they must come out the
  -- same every time, and the client reads a frame's size back with float error at a UI scale.
  it("says how wide it is from the widths it gave its tabs, not from what the client reads back", function()
    rail:SetTabs({ { id = 1, name = "Backpack" }, { id = 2, name = string.rep("W", 40) } })
    assert.are.equal(style.TAB_MAX_WIDTH, rail:Width())
    for _, t in ipairs(rail.tabs) do
      t.button.GetWidth = function() return style.TAB_MAX_WIDTH + 1e-4 end
    end
    assert.are.equal(style.TAB_MAX_WIDTH, rail:Width())
    rail:SetTabs({})
    assert.are.equal(0, rail:Width())
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

  it("draws the gold bar in the selected tab's accent, gold unless the tab has its own", function()
    local teal = { 0.2, 0.8, 0.9, 1 }
    rail:SetTabs({ { id = 1, name = "Bank" }, { id = 2, name = "Warbank", accent = teal } })
    rail:Select(2)
    assert.are.same(teal, { rail.indicator:GetVertexColor() })
    rail:Select(1)
    assert.are.same(style.Color.Gold, { rail.indicator:GetVertexColor() })
  end)

  it("leaves a gap above a tab that asks for one, moving every tab after it down", function()
    rail:SetTabs({ { id = 1, name = "Bank" }, { id = 2, name = "Warbank", gap = 12 }, { id = 3, name = "More" } })
    local step = style.TAB_HEIGHT + style.TAB_SPACING
    assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(step + 12) }, { rail.tabs[2].button:GetPoint(1) })
    assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(2 * step + 12) }, { rail.tabs[3].button:GetPoint(1) })
    rail:Select(3)
    assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(2 * step + 12) }, { rail.indicator:GetPoint(1) })
    assert.are.equal(3 * step + 12, rail.frame:GetHeight())
  end)

  it("shows a tab's icon beside its name, from a file or an atlas, and makes room for it", function()
    rail:SetTabs({ { id = 1, name = "Ore Deposits", icon = 12345 }, { id = 2, name = "Warbank", atlas = "warbands-icon" },
      { id = 3, name = "Plain" } })
    local ore, warbank, plain = rail.tabs[1], rail.tabs[2], rail.tabs[3]
    assert.are.equal(12345, ore.icon:GetTexture())
    assert.is_true(ore.icon:IsShown())
    assert.are.equal("warbands-icon", warbank.icon:GetAtlas())
    assert.is_false(plain.icon:IsShown())
    assert.are.equal(#"Ore Deposits" * 6 + style.TAB_PADDING * 2 + style.TAB_ICON + style.TAB_ICON_GAP, ore.button:GetWidth())
    rail:SetTabs({ { id = 1, name = "Ore" } })
    assert.is_false(rail.tabs[1].icon:IsShown(), "a reused tab drops the icon it had")
  end)

  it("fills the tooltip itself when a tab's tooltip is a function", function()
    local filled
    rail:SetTabs({ { id = 1, name = "Tab", tooltip = function(owner)
      filled = owner
      GameTooltip:AddLine("custom")
    end } })
    local button = rail.tabs[1].button
    button:GetScript("OnEnter")(button)
    assert.are.equal(button, filled)
    assert.are.equal("custom", GameTooltip.lines[1].text)
  end)

  -- Buying a bank tab is protected: the button must be Blizzard's purchase template, whose own
  -- click opens the purchase dialog; it is never given an OnClick (next.md §6).
  describe("purchase tabs", function()
    it("makes a purchase tab from Blizzard's purchase template, for its bank type, with no click of ours", function()
      rail:SetTabs({ { id = -1, name = "+", secure = 1 }, { id = -2, name = "+", secure = 2 } })
      local char, account = rail.tabs[1].button, rail.tabs[2].button
      assert.are.equal("BankPanelPurchaseButtonScriptTemplate", char._template)
      assert.are.equal(1, char:GetAttribute("overrideBankType"))
      assert.are.equal(2, account:GetAttribute("overrideBankType"))
      assert.is_nil(char:GetScript("OnClick"))
      local step = style.TAB_HEIGHT + style.TAB_SPACING
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, { account:GetPoint(1) })
    end)

    it("keeps purchase tabs and ordinary tabs apart when it reuses them", function()
      rail:SetTabs({ { id = 1, name = "Bank" }, { id = -1, name = "+", secure = 1 } })
      local plain, purchase = rail.tabs[1].button, rail.tabs[2].button
      rail:SetTabs({ { id = -2, name = "+", secure = 2 }, { id = 5, name = "Tab" } })
      assert.are.equal(purchase, rail.tabs[1].button)
      assert.are.equal(2, purchase:GetAttribute("overrideBankType"))
      assert.are.equal(plain, rail.tabs[2].button)
      assert.is_not_nil(plain:GetScript("OnClick"))
    end)
  end)

  -- A WoW: Forever bank tab is a bag socket: dragging it or dropping a bag on it moves the bag.
  it("tells its drag handler when a draggable tab is dragged or has something dropped on it", function()
    local drags = {}
    rail:SetDragHandler(function(ctx, id)
      assert.is_not_nil(ctx)
      table.insert(drags, id)
    end)
    rail:SetTabs({ { id = 7, name = "Socket", draggable = true }, { id = 8, name = "Plain" } })
    local socket, plain = rail.tabs[1].button, rail.tabs[2].button
    assert.are.same({ "LeftButton" }, socket._registeredDrags)
    assert.is_nil(plain._registeredDrags)
    socket:GetScript("OnDragStart")(socket)
    socket:GetScript("OnReceiveDrag")(socket)
    plain:GetScript("OnDragStart")(plain)
    plain:GetScript("OnReceiveDrag")(plain)
    assert.are.same({ 7, 7 }, drags)
  end)

  -- The bank's panel is on the left of the screen: its rail hangs from the body's right edge and
  -- its tabs stick out to the right (next.md §3, "one panel, two sides").
  describe("on the left side of the screen", function()
    local left

    before_each(function()
      left = nextTabs:Create(body, "LEFT")
      left:SetTabs(groups)
    end)

    it("hangs from the body's right edge, its tabs sticking out to the right", function()
      assert.are.same({ "TOPLEFT", body, "TOPRIGHT", 0, -style.CONTENT_TOP }, { left.frame:GetPoint(1) })
      local step = style.TAB_HEIGHT + style.TAB_SPACING
      assert.are.same({ "TOPLEFT", left.frame, "TOPLEFT", 0, -step }, { left.tabs[2].button:GetPoint(1) })
      assert.are.equal("LEFT", left.tabs[2].text:GetJustifyH())
    end)

    it("slides a hovered tab out to the right", function()
      local button = left.tabs[2].button
      button:GetScript("OnEnter")(button)
      finishTweens()
      local _, _, _, x = button:GetPoint(1)
      assert.are.equal(style.TAB_HOVER, x)
    end)

    it("puts the gold bar on the body side of the selected tab", function()
      left:Select(2)
      local step = style.TAB_HEIGHT + style.TAB_SPACING
      assert.are.same({ "TOPLEFT", left.frame, "TOPLEFT", 0, -step }, { left.indicator:GetPoint(1) })
    end)

    it("fades each tab out toward its outer end", function()
      local g = left.tabs[1].bg._gradient
      assert.is_true(g.min.a > g.max.a, "opaque at the body, fainter outside")
      local right = rail
      right:SetTabs(groups)
      local rg = right.tabs[1].bg._gradient
      assert.is_true(rg.max.a > rg.min.a)
    end)
  end)

  -- A section dragged over a tab (next.md §7).
  describe("as a drop target", function()
    it("finds the tab under the cursor, by position", function()
      rail:SetTabs(groups)
      UIParent:_SetRect(0, 0, 1920, 1200)
      for i, t in ipairs(rail.tabs) do t.button:_SetRect(100, 1000 - i * 40, 80, 30) end
      _G._cursorX, _G._cursorY = 120, 925
      assert.are.equal(rail.tabs[2], rail:TabAt())
      _G._cursorX = 20
      assert.is_nil(rail:TabAt())
      rail.frame:Hide()
      _G._cursorX = 120
      assert.is_nil(rail:TabAt(), "nothing while the rail is hidden")
      _G._cursorX, _G._cursorY = nil, nil
    end)

    it("lights the tab a section would drop on, slid out, and puts it back after", function()
      rail:SetTabs(groups)
      rail:Select(1)
      rail:SetDropTarget(2)
      finishTweens()
      local tab = rail.tabs[2]
      assert.are.equal(style:Font("TabSelected"), tab.text:GetFontObject())
      assert.is_true(tab.glow:IsShown())
      local _, _, _, x = tab.button:GetPoint(1)
      assert.are.equal(-style.TAB_HOVER, x)
      rail:SetDropTarget(nil)
      finishTweens()
      assert.are.equal(style:Font("Tab"), tab.text:GetFontObject())
      assert.is_false(tab.glow:IsShown())
      _, _, _, x = tab.button:GetPoint(1)
      assert.are.equal(0, x)
      assert.are.equal(style:Font("TabSelected"), rail.tabs[1].text:GetFontObject(), "the selected tab stays bright")
    end)

    it("keeps the lit tab slid out when the pointer leaves it mid-drag", function()
      rail:SetTabs(groups)
      rail:SetDropTarget(2)
      local button = rail.tabs[2].button
      button:GetScript("OnLeave")(button)
      finishTweens()
      local _, _, _, x = button:GetPoint(1)
      assert.are.equal(-style.TAB_HOVER, x)
    end)

    it("pulses a tab that received a section, then fades the glow out", function()
      rail:SetTabs(groups)
      rail:Pulse(2)
      local glow = rail.tabs[2].glow
      assert.is_true(glow:IsShown())
      assert.is_true(glow:GetAlpha() > 0.5)
      finishTweens()
      assert.is_false(glow:IsShown())
    end)
  end)

  -- A Next theme (next-themes.md): the rail draws everything from it, and a theme applied while its
  -- tabs show restyles and lays them out again.
  describe("a theme", function()
    after_each(function()
      UseNextTheme(nil)
    end)

    local function restyle(theme)
      UseNextTheme(theme)
      rail:ApplyStyle(nil)
    end

    it("sizes, steps and places its tabs with its layout, laying them out again", function()
      rail:SetTabs(groups)
      restyle({ Layout = { TabHeight = 20, TabSpacing = 2, TabPadding = 5, TabMinWidth = 10, ContentTop = 90 } })
      assert.are.same({ "TOPRIGHT", body, "TOPLEFT", 0, -90 }, { rail.frame:GetPoint(1) })
      for i, tab in ipairs(rail.tabs) do
        assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(i - 1) * 22 }, { tab.button:GetPoint(1) })
        assert.are.equal(20, tab.button:GetHeight())
      end
      assert.are.equal(#"Consumables" * 6 + 10, rail.tabs[2].button:GetWidth())
      assert.are.same({ "RIGHT", rail.tabs[2].button, "RIGHT", -5, 0 }, { rail.tabs[2].text:GetPoint(1) })
    end)

    it("fills its tabs with its colors, fading by its share, the selected one in its own", function()
      rail:SetTabs(groups)
      rail:Select(1)
      restyle({ Palette = { A = { 0.1, 0.2, 0.3, 0.8 }, B = { 0.5, 0.6, 0.7, 1 } },
        Tabs = { Fill = "A", SelectedFill = "B", Fade = 0.5 } })
      local g = rail.tabs[2].bg._gradient
      assert.are.same({ 0.1, 0.2, 0.3, 0.4 }, { g.min.r, g.min.g, g.min.b, g.min.a }, "faded on the far side")
      assert.are.same({ 0.1, 0.2, 0.3, 0.8 }, { g.max.r, g.max.g, g.max.b, g.max.a })
      assert.are.equal(1, rail.tabs[1].bg._gradient.max.a)
    end)

    it("writes its tabs in its roles, moving them to its new fonts", function()
      rail:SetTabs(groups)
      rail:Select(2)
      local before = rail.tabs[1].text:GetFontObject()
      restyle({ Fonts = { Tab = { Size = 9 }, Shout = { Size = 16 } }, Tabs = { SelectedFont = "Shout" } })
      assert.are_not.equal(before, rail.tabs[1].text:GetFontObject())
      assert.are.equal(style:Font("Tab"), rail.tabs[1].text:GetFontObject())
      assert.are.equal(style:Font("Shout"), rail.tabs[2].text:GetFontObject())
    end)

    it("draws the bar in its color and width, an accent by its name, or no bar", function()
      rail:SetTabs({ { id = 1, name = "Bank" }, { id = 2, name = "Warbank", accent = "Warbank" } })
      rail:Select(1)
      restyle({ Palette = { Sky = { 0.3, 0.6, 1, 1 }, Sea = { 0, 0.4, 0.5, 1 } },
        Tabs = { Indicator = { Color = "Sky", Width = 5 }, Accents = { Warbank = "Sea" } } })
      assert.are.same({ 0.3, 0.6, 1, 1 }, { rail.indicator:GetVertexColor() })
      assert.are.equal(5, rail.indicator:GetWidth())
      assert.are.equal(style.TAB_HEIGHT, rail.indicator:GetHeight())
      rail:Select(2)
      assert.are.same({ 0, 0.4, 0.5, 1 }, { rail.indicator:GetVertexColor() })
      restyle({ Tabs = { Indicator = false } })
      assert.is_false(rail.indicator:IsShown())
      rail:Select(1)
      assert.is_false(rail.indicator:IsShown())
    end)

    it("lights a drop target and a pulse in its glow, or none", function()
      rail:SetTabs(groups)
      restyle({ Palette = { Mint = { 0.4, 1, 0.7, 1 } }, Tabs = { Glow = { Color = "Mint", Drop = 0.5, Pulse = 0.9 } } })
      rail:SetDropTarget(2)
      local glow = rail.tabs[2].glow
      local r, g, b = glow:GetVertexColor()
      assert.are.same({ 0.4, 1, 0.7 }, { r, g, b })
      assert.are.equal(0.5, glow:GetAlpha())
      -- A texture's alpha is its vertex color's: restyled, it keeps what it shows.
      rail:ApplyStyle(nil)
      assert.are.equal(0.5, glow:GetAlpha())
      rail:SetDropTarget(nil)
      restyle({ Tabs = { Glow = false } })
      rail:SetDropTarget(2)
      assert.is_false(glow:IsShown())
      rail:Pulse(2)
      assert.is_false(glow:IsShown())
    end)

    it("slides a hovered tab out by its hover, in its time and ease", function()
      restyle({ Layout = { TabHover = 12 }, Motion = { Time = { Hover = 1 }, Ease = { Hover = "linear" } } })
      rail:SetTabs(groups)
      local button = rail.tabs[1].button
      button:GetScript("OnEnter")(button)
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.25)
      local _, _, _, x = button:GetPoint(1)
      assert.is_true(math.abs(x + 3) < 1e-6, "a quarter of the way, linearly: " .. x)
    end)
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
