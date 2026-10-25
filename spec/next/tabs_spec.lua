-- A text sits a quarter pixel right of and above its whole pixel (next-pixel-perfect.md §2); one pixel is one unit here.
local TEXT = 0.25
-- tabs_spec.lua -- NextTabs (next/tabs.lua): the backpack's groups as tabs down the body's left
-- edge, sticking out like bookmarks; the selected one is brighter, with a gold bar that glides to
-- it, and a hovered one slides out (next.md §3).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")
ResetModuleStub("NextTween", "next/tween.lua")
LoadBetterBagsModule("next/tween.lua")
ResetModuleStub("NextLift", "next/lift.lua")
LoadBetterBagsModule("next/lift.lua")
ResetModuleStub("NextTabs", "next/tabs.lua")
LoadBetterBagsModule("next/tabs.lua")
local nextTabs = addon:GetModule("NextTabs")
local tween = addon:GetModule("NextTween")
local style = addon:GetModule("NextStyle")
local lift = addon:GetModule("NextLift")

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
      -- By its corner, centered on the tab's height by its font's (docs/next-pixel-perfect.md).
      local text = rail.tabs[2].text
      local _, fontHeight = text:GetFont()
      assert.are.same({ "TOPRIGHT", rail.tabs[2].button, "TOPRIGHT", -5 + TEXT, -math.floor((20 - fontHeight) / 2) + TEXT },
        { text:GetPoint(1) })
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

    -- GW2_UI's side tab art (docs/next-gw2-theme.md, round two): drawn for the backpack's tabs, sticking out to the
    -- left, mirrored on the other panels; no fade, which is for colors.
    it("fills its tabs with art when its fills are art, mirrored on the left of the screen, and colors after", function()
      local ART = "Interface\\Spec\\tab.png"
      rail:SetTabs(groups)
      rail:Select(1)
      restyle({ Palette = { Lit = { 1, 0.9, 0.8, 1 } }, Tabs = {
        Fill = { Texture = ART, TexCoords = { 0.86, 0, 0, 0.06 }, Color = "White" },
        SelectedFill = { Texture = ART, TexCoords = { 0.86, 0, 0, 0.06 }, Color = "Lit" } } })
      local bg = rail.tabs[2].bg
      assert.are.equal(ART, bg:GetTexture())
      assert.is_nil(bg._gradient)
      local ulx, uly, _, lly, urx = bg:GetTexCoord()
      assert.are.same({ 0.86, 0, 0, 0.06 }, { ulx, urx, uly, lly })
      assert.are.same({ 1, 0.9, 0.8, 1 }, { rail.tabs[1].bg:GetVertexColor() }, "the selected one in its own")
      local left = nextTabs:Create(CreateFrame("Frame"), "LEFT")
      left:SetTabs(groups)
      left:Select(1)
      ulx, uly, _, lly, urx = left.tabs[2].bg:GetTexCoord()
      assert.are.same({ 0, 0.86, 0, 0.06 }, { ulx, urx, uly, lly }, "mirrored")
      restyle({ Palette = { A = { 0.1, 0.2, 0.3, 0.8 } }, Tabs = { Fill = "A", Fade = 0.5 } })
      assert.is_nil(bg:GetTexture(), "a color again")
      assert.are.same({ 0.1, 0.2, 0.3, 0.8 }, { bg._gradient.max.r, bg._gradient.max.g, bg._gradient.max.b, bg._gradient.max.a })
      ulx, uly, _, lly, urx = bg:GetTexCoord()
      assert.are.same({ 0, 1, 0, 1 }, { ulx, urx, uly, lly })
    end)

    -- The Plain theme (docs/next-plain-theme.md): Blizzard's list rows (Blizzard_CategoryList.lua): Options_List_Hover
    -- under the pointer, Options_List_Active when selected, over the tab's fill, mirrored on the left of the screen.
    it("draws its highlight over a tab under the pointer and its selected highlight over the selected one", function()
      rail:SetTabs(groups)
      rail:Select(1)
      restyle({ Tabs = { Highlight = { Atlas = "Options_List_Hover", Color = "White", Alpha = 1 },
        SelectedHighlight = { Atlas = "Options_List_Active", Color = "White", Alpha = 1 } } })
      local selected, other = rail.tabs[1], rail.tabs[2]
      assert.are.equal("Options_List_Active", selected.highlight:GetAtlas())
      assert.is_true(selected.highlight:IsShown())
      assert.is_false(other.highlight:IsShown())
      other.button:GetScript("OnEnter")(other.button)
      assert.are.equal("Options_List_Hover", other.highlight:GetAtlas())
      assert.is_true(other.highlight:IsShown())
      other.button:GetScript("OnLeave")(other.button)
      assert.is_false(other.highlight:IsShown())
      local left = nextTabs:Create(CreateFrame("Frame"), "LEFT")
      left:SetTabs(groups)
      left:Select(1)
      local ulx, _, _, _, urx = left.tabs[1].highlight:GetTexCoord()
      assert.are.same({ 1, 0 }, { ulx, urx }, "mirrored")
      restyle({})
      assert.is_false(selected.highlight:IsShown(), "a theme without")
    end)

    it("draws the bar in art when it names some, tinted by the tab's accent", function()
      rail:SetTabs({ { id = 1, name = "Bank" } })
      rail:Select(1)
      restyle({ Palette = { Sky = { 0.3, 0.6, 1, 1 } }, Tabs = { Indicator = { Texture = "Interface\\Spec\\bar.png", Color = "Sky", Width = 4 } } })
      rail:Select(1)
      assert.are.equal("Interface\\Spec\\bar.png", rail.indicator:GetTexture())
      assert.are.same({ 0.3, 0.6, 1, 1 }, { rail.indicator:GetVertexColor() })
      restyle({ Tabs = { Indicator = { Color = "Gold", Width = 3 } } })
      assert.is_nil(rail.indicator:GetTexture())
    end)

    -- Reported in game: a selected tab's name cut short ("Backpa..."). The client keeps the width a font string took
    -- when its text was set through a later font change, and cuts text past it (Blizzard resets it by setting the
    -- width to 0 and the text again: QuestLogTitleButton_Resize, "HACK"; measured on the classic settings window,
    -- sonata.md 3c: 110.0 kept for a 110.8 string). Guild Wars 2's selected tab font has a shadow, wider by about that.
    it("keeps a tab's name as wide as its text in the font it has now, selected or not", function()
      restyle({ Fonts = { Wide = { Size = 12, Shadow = true } }, Tabs = { SelectedFont = "Wide" } })
      rail:SetTabs(groups)
      local wide = style:Font("Wide")
      for _, tab in ipairs(rail.tabs) do
        local base = tab.text.GetStringWidth
        tab.text.GetStringWidth = function(self) return base(self) + (self:GetFontObject() == wide and 0.8 or 0) end
      end
      rail:Select(1)
      for _, tab in ipairs(rail.tabs) do
        local text = tab.text
        assert.are.equal(math.ceil(text:GetStringWidth()) + 1, text:GetWidth(), text:GetText())
      end
      rail:Select(2)
      local text = rail.tabs[1].text
      assert.are.equal(math.ceil(text:GetStringWidth()) + 1, text:GetWidth(), "back in its idle font")
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

  -- Asked: "all tabs in all Next windows should be reorderable by clicking and holding to slide. animate
  -- the slide, but pin the X axis so you can't move it left and right, just drag it up and down. animate
  -- this transition and make sure it saves." (docs/next-batch-2.md §5)
  describe("moving a tab", function()
    local orders, step, RAIL_TOP, RAIL_RIGHT

    before_each(function()
      UIParent:_SetRect(0, 0, 1920, 1200)
      orders = {}
      rail:SetReorderHandler(function(ctx, ids)
        assert.is_not_nil(ctx)
        table.insert(orders, ids)
      end)
      step = style.TAB_HEIGHT + style.TAB_SPACING
      RAIL_TOP, RAIL_RIGHT = 800, 1020
      _G._mouseButtonsDown = nil
    end)

    after_each(function()
      rail:CancelMove()
      _G._mouseButtonsDown = nil
    end)

    -- layOut gives the rail and its tabs the rects the client would (specs have no layout engine).
    local function layOut()
      rail.frame:_SetRect(RAIL_RIGHT - 120, RAIL_TOP - 600, 120, 600)
      for _, tab in ipairs(rail.tabs) do
        tab.button:_SetRect(RAIL_RIGHT - tab.width, RAIL_TOP - tab.y - style.TAB_HEIGHT, tab.width, style.TAB_HEIGHT)
      end
    end

    local function press(tab)
      local x, y = tab.button:GetLeft() + 10, tab.button:GetTop() - style.TAB_HEIGHT / 2
      _G._cursorX, _G._cursorY = x, y
      _G._mouseButtonsDown = { LeftButton = true }
      tab.button:GetScript("OnDragStart")(tab.button)
      return x, y
    end

    local function move(x, y)
      _G._cursorX, _G._cursorY = x, y
      lift.layer:GetScript("OnUpdate")(lift.layer, 0.016)
    end

    local function release(tab)
      _G._mouseButtonsDown = nil
      tab.button:GetScript("OnDragStop")(tab.button)
    end

    -- middleOf is the cursor's y over the middle of the place-th tab.
    local function middleOf(place, gap)
      return RAIL_TOP - (place - 1) * step - (gap or 0) - style.TAB_HEIGHT / 2
    end

    local function ids()
      local out = {}
      for _, t in ipairs(rail.tabs) do table.insert(out, t.id) end
      return out
    end

    local function placed(id)
      local tab = rail:Tab(id)
      return { tab.button:GetPoint(1) }
    end

    local groupsAndPlus = { { id = 1, name = "Backpack" }, { id = 2, name = "Herbs" }, { id = 3, name = "Ore" },
      { id = 0, name = "+", fixed = true } }

    it("lifts a tab pressed and moved, which follows the cursor up and down but never sideways", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local tab = rail:Tab(1)
      assert.are.same({ "LeftButton" }, tab.button._registeredDrags)
      local x, y = press(tab)
      assert.is_true(lift:IsHolding())
      move(x - 80, y - 10)
      local before = { tab.button:GetPoint(1) }
      move(x + 120, y - 30)
      local after = { tab.button:GetPoint(1) }
      assert.are.equal("TOPLEFT", after[1])
      assert.are.equal(UIParent, after[2])
      assert.are.equal(before[4], after[4], "its X pinned")
      assert.is_true(after[5] < before[5], "it went down with the cursor")
      finishTweens()
      local settled = { tab.button:GetPoint(1) }
      move(x - 200, y - 40)
      assert.are.equal(settled[4], ({ tab.button:GetPoint(1) })[4], "pinned once lifted too")
    end)

    it("stays with the cursor when the pointer leaves it, its hover slide never pulling it back", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local tab = rail:Tab(1)
      local x, y = press(tab)
      move(x, y - 15)
      finishTweens()
      local held = { tab.button:GetPoint(1) }
      tab.button:GetScript("OnLeave")(tab.button)
      finishTweens()
      assert.are.equal(UIParent, ({ tab.button:GetPoint(1) })[2])
      assert.are.equal(held[5], ({ tab.button:GetPoint(1) })[5])
    end)

    it("lands where its room is: the rail's edge, below the tabs above it", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local land, landTo = lift.Land, nil
      lift.Land = function(self, held, to, ...)
        landTo = to
        return land(self, held, to, ...)
      end
      local tab = rail:Tab(1)
      local x = press(tab)
      move(x, middleOf(2) - 2)
      release(tab)
      lift.Land = land
      local left, top = landTo(0, 0)
      assert.are.equal(RAIL_RIGHT - tab.width, left)
      assert.are.equal(RAIL_TOP - step, top)
      finishTweens()
    end)

    -- Reported: "when i let go, it snaps to the mouse's position for a second before it slips over to the
    -- correct point, no matter how far away the mouse is to the left or right".
    it("lands from where it is, its x pinned, however far the cursor went sideways", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local tab = rail:Tab(1)
      local x = press(tab)
      move(x + 300, middleOf(2) - 2)
      finishTweens()
      local before = { tab.button:GetPoint(1) }
      release(tab)
      local after = { tab.button:GetPoint(1) }
      assert.are.equal(before[4], after[4], "no jump to the cursor's x")
      assert.are.equal(before[5], after[5])
      finishTweens()
    end)

    -- BetterBags Next's small panels have a Bag Scale (docs/next-appearance-size.md): the rail is read on
    -- screen, in UIParent's units, and the tab keeps its size there.
    it("moves a tab in a scaled panel's rail, reading the rail on screen", function()
      body:SetScale(0.5)
      rail:SetTabs(groupsAndPlus)
      layOut()
      local tab = rail:Tab(1)
      local x, y = (tab.button:GetLeft() + 10) * 0.5, (tab.button:GetTop() - style.TAB_HEIGHT / 2) * 0.5
      _G._cursorX, _G._cursorY = x, y
      _G._mouseButtonsDown = { LeftButton = true }
      tab.button:GetScript("OnDragStart")(tab.button)
      assert.are.equal(0.5, tab.button:GetScale(), "lifted at its size on screen")
      move(x, middleOf(2) * 0.5 - 1)
      assert.are.equal(2, rail.moving.index)
      release(tab)
      tween:Step(style.Time.Land - 0.00001)
      local s = tab.button:GetScale()
      assert.is_true(math.abs(s - 0.5) < 0.01, "lands at the rail's scale: " .. s)
      local _, _, _, ox, oy = tab.button:GetPoint(1)
      assert.is_true(math.abs(ox * s - (RAIL_RIGHT - tab.width) * 0.5) < 0.5, "at the rail's edge")
      assert.is_true(math.abs(oy * s - (RAIL_TOP - step) * 0.5) < 0.5, "in its room")
      finishTweens()
      assert.are.same({ { 2, 1, 3, 0 } }, orders)
      body:SetScale(1)
    end)

    it("slides the tabs in its way out of it, animated", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local x = press(rail:Tab(1))
      move(x, middleOf(2) - 2)
      assert.is_true(tween:IsPlaying(rail:Tab(2).yKey), "Herbs slides up into its place")
      finishTweens()
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, 0 }, placed(2))
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -2 * step }, placed(3))
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -3 * step }, placed(0))
    end)

    it("lands it in its new place, telling its handler the new order, which it shows", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local tab = rail:Tab(1)
      local x = press(tab)
      move(x, middleOf(2) - 2)
      release(tab)
      assert.are.same({}, orders, "not before it landed")
      finishTweens()
      assert.are.same({ { 2, 1, 3, 0 } }, orders)
      assert.are.same({ 2, 1, 3, 0 }, ids())
      assert.is_false(lift:IsHolding())
      assert.are.equal(rail.frame, tab.button:GetParent())
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, placed(1))
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, 0 }, placed(2))
    end)

    it("lets it go when the button is up even without a drag stop, telling nothing for no move", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local x, y = press(rail:Tab(2))
      _G._mouseButtonsDown = nil
      move(x, y)
      finishTweens()
      assert.is_false(lift:IsHolding())
      assert.are.same({}, orders)
      assert.are.same({ 1, 2, 3, 0 }, ids())
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, placed(2))
    end)

    it("keeps a tab its owner fixes, a purchase tab and a draggable one where they are", function()
      local drags = {}
      rail:SetDragHandler(function(_, id) table.insert(drags, id) end)
      rail:SetTabs({ { id = 1, name = "Backpack" }, { id = 7, name = "Socket", draggable = true },
        { id = 0, name = "+", fixed = true }, { id = -1, name = "+", secure = 1 } })
      layOut()
      press(rail:Tab(0))
      assert.is_false(lift:IsHolding())
      press(rail:Tab(7))
      assert.is_false(lift:IsHolding())
      assert.are.same({ 7 }, drags, "a draggable tab's drag is its own")
      local x = press(rail:Tab(1))
      move(x, middleOf(4) - 2)
      release(rail:Tab(1))
      finishTweens()
      assert.are.same({}, orders, "nothing to move past: the others stay")
      assert.are.same({ 1, 7, 0, -1 }, ids())
    end)

    it("moves nothing on a rail without a handler", function()
      local other = nextTabs:Create(body)
      other:SetTabs(groupsAndPlus)
      other.frame:_SetRect(RAIL_RIGHT - 120, RAIL_TOP - 600, 120, 600)
      local tab = other.tabs[1]
      tab.button:_SetRect(RAIL_RIGHT - tab.width, RAIL_TOP - style.TAB_HEIGHT, tab.width, style.TAB_HEIGHT)
      assert.is_nil(tab.button._registeredDrags)
      tab.button:GetScript("OnDragStart")(tab.button)
      assert.is_false(lift:IsHolding())
    end)

    -- The bank's own groups and its Warbank groups are two blocks, as its Blizzard tabs are.
    it("moves a tab only among its block's tabs, the block's gap staying at its first", function()
      rail:SetTabs({ { id = 1, name = "Bank", block = "bank" }, { id = 2, name = "Vault", block = "bank" },
        { id = 3, name = "Warbank", block = "warbank", gap = 10 }, { id = 4, name = "Shared", block = "warbank" } })
      layOut()
      local x = press(rail:Tab(1))
      move(x, middleOf(4, 10) - 2)
      release(rail:Tab(1))
      finishTweens()
      assert.are.same({ { 2, 1, 3, 4 } }, orders, "kept in its block")
      x = press(rail:Tab(3))
      move(x, middleOf(4, 10) - 2)
      release(rail:Tab(3))
      finishTweens()
      assert.are.same({ 2, 1, 4, 3 }, orders[2])
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(2 * step + 10) }, placed(4), "the gap above the block")
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(3 * step + 10) }, placed(3))
      rail:SetTabs(rail.entries)
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -(2 * step + 10) }, placed(4), "and when listed again")
    end)

    it("keeps a tab dragged over another block's tabs at its own block's edge", function()
      rail:SetTabs({ { id = 1, name = "Bank", block = "bank" }, { id = 2, name = "Vault", block = "bank" },
        { id = 3, name = "Warbank", block = "warbank", gap = 10 }, { id = 4, name = "Shared", block = "warbank" } })
      layOut()
      local x = press(rail:Tab(3))
      move(x, middleOf(1) - 2)
      release(rail:Tab(3))
      finishTweens()
      assert.are.same({}, orders, "still first of its block")
      assert.are.same({ 1, 2, 3, 4 }, ids())
    end)

    it("keeps the bar on the selected tab", function()
      rail:SetTabs(groupsAndPlus)
      rail:Select(1)
      layOut()
      local x = press(rail:Tab(1))
      move(x, middleOf(2) - 2)
      release(rail:Tab(1))
      finishTweens()
      assert.are.equal(-step, rail.indicatorY)
      assert.are.equal(1, rail.selected)
    end)

    it("puts a tab back when its rail hides or its tabs are listed again mid-move, telling nothing", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local x = press(rail:Tab(1))
      move(x, middleOf(3) - 2)
      rail.frame:GetScript("OnHide")(rail.frame)
      assert.is_false(lift:IsHolding())
      assert.are.equal(rail.frame, rail:Tab(1).button:GetParent())
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, 0 }, placed(1))
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, placed(2))
      layOut()
      x = press(rail:Tab(1))
      move(x, middleOf(3) - 2)
      rail:SetTabs(groupsAndPlus)
      assert.is_false(lift:IsHolding())
      finishTweens()
      assert.are.same({}, orders)
      assert.are.same({ "TOPRIGHT", rail.frame, "TOPRIGHT", 0, -step }, placed(2))
    end)

    it("starts no move while something else is lifted", function()
      rail:SetTabs(groupsAndPlus)
      layOut()
      local other = CreateFrame("Frame", nil, UIParent)
      other:_SetRect(0, 0, 10, 10)
      local held = {}
      assert.is_true(lift:Pick(held, other, function() end))
      press(rail:Tab(1))
      assert.are.equal(held, lift.held)
      lift:Release(held)
    end)
  end)

  -- How each panel lists its tabs in the order the player saved (Ordered).
  describe("a saved order", function()
    local function names(list)
      local out = {}
      for _, e in ipairs(list) do table.insert(out, e.id) end
      return out
    end

    it("puts the saved tabs in their order, the others after them in theirs", function()
      local entries = { { id = 1 }, { id = 2 }, { id = 3 }, { id = 4 } }
      assert.are.same({ 3, 1, 2, 4 }, names(nextTabs:Ordered(entries, { 3, 1 })))
      assert.are.same({ 1, 2, 3, 4 }, names(nextTabs:Ordered(entries, nil)))
      assert.are.same({ 1, 2, 3, 4 }, names(entries), "the list given is left alone")
    end)

    it("never moves a fixed tab, nor a tab past one", function()
      local entries = { { id = 1 }, { id = 0, fixed = true }, { id = 2 } }
      assert.are.same({ 1, 0, 2 }, names(nextTabs:Ordered(entries, { 2, 1 })))
    end)

    it("orders each block apart, next to each other", function()
      local entries = { { id = 1, block = "a" }, { id = 2, block = "a" }, { id = 3, block = "b" }, { id = 4, block = "b" } }
      assert.are.same({ 1, 2, 3, 4 }, names(nextTabs:Ordered(entries, { 3, 1 })))
      assert.are.same({ 2, 1, 4, 3 }, names(nextTabs:Ordered(entries, { 4, 2 })))
    end)

    it("keeps fixed and purchase tabs where they are, each block's tabs among themselves", function()
      local entries = { { id = 1, block = "a" }, { id = 2, block = "a" }, { id = -1, secure = 1 },
        { id = 3, block = "b" }, { id = 4, block = "b" }, { id = 0, fixed = true } }
      assert.are.same({ 2, 1, -1, 4, 3, 0 }, names(nextTabs:Ordered(entries, { 4, 2, 3, 1 })))
    end)
  end)
end)
