-- screencard_spec.lua -- NextScreenCard (next/screencard.lua): the card the currency tracker and the Food & Drink bar
-- are both kinds of (food-drink.md §4, currency.md §5), as a kind of its own here: where it shows and grows from, picked
-- up and dropped, remembered, put away on the open backpack, emerging from it, and hidden in combat and pet battles.
-- The currency tracker's own specs (spec/next/currency_spec.lua) cover it as the tracker.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local stubs = { L = trackStub("Localization"), events = trackStub("Events"), nextDrag = trackStub("NextDrag") }

local MODULES = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextScreenCard", "next/screencard.lua" } }
for _, m in ipairs(MODULES) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local layout = dofile("spec/helpers/layout.lua")
local card = addon:GetModule("NextScreenCard")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local lift = addon:GetModule("NextLift")
local motion = addon:GetModule("Motion")
local pixel = addon:GetModule("NextPixel")
local context = addon:GetModule("Context")

describe("NextScreenCard", function()
  local replaced, registered, saved, opts, home, opened, putAway, unscreen, made

  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx() return context:New("spec") end

  local function fire(name)
    for _, fn in ipairs(registered[name] or {}) do fn(ctx(), name) end
  end

  local function finishTweens()
    for _ = 1, 600 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      local moving = motion.driver and motion.driver:GetScript("OnUpdate")
      if update == nil and moving == nil then return end
      if update then update(tween.driver, 0.05) end
      if moving then moving(motion.driver, 0.05) end
    end
  end

  -- A kind of card of the spec's own: 100 by 40, its options, place and home the spec's.
  local kind = card:Extend({})
  function kind:Option(name) return opts[name] end
  function kind:Saved() return saved.out, saved.x, saved.y end
  function kind:Save(out, x, y)
    saved.out = out
    if x ~= nil then saved.x, saved.y = x, y end
  end
  function kind:Home() return home end
  function kind:PutAwayPoint() return lift:Center(home.body) end
  function kind:OnPutAway() putAway = putAway + 1 end
  function kind:Wants() return true end
  function kind:LayOut()
    if self.held == nil then self.frame:SetScale(self:Scale()) end
    pixel:Size(self.frame, 100, 40)
  end
  function kind:OpenSettings() opened = opened + 1 end

  local function make()
    local c = setmetatable({}, { __index = kind })
    card:Build(c, nil)
    c:Style()
    made = c
    return c
  end

  local function edges(c)
    local at = lift:ScreenPoint(c.frame)
    local w, h = c.frame:GetWidth() * at.scale, c.frame:GetHeight() * at.scale
    return { left = at.left, right = at.left + w, top = at.top, bottom = at.top - h, scale = at.scale }
  end

  local function near(a, b) return math.abs(a - b) <= pixel:Unit(UIParent) / 2 + 1e-6 end

  before_each(function()
    replaced, registered, opened, putAway = {}, {}, 0, 0
    unscreen = layout.UseScreen(1920, 1080, 1)
    UseNextTheme(nil)
    tween:Init()
    motion:Init()
    saved = { out = false }
    opts = { layout = "row", growX = "left", growY = "down", scale = 100, background = true, hideInCombat = false }
    home = { frame = CreateFrame("Frame", nil, UIParent), closing = false }
    home.body = CreateFrame("Frame", nil, home.frame)
    home.frame:_SetRect(1500, 100, 400, 900)
    home.body:SetAllPoints(home.frame)
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.events, "RegisterEvent", function(_, name, fn)
      registered[name] = registered[name] or {}
      table.insert(registered[name], fn)
    end)
    override(stubs.events, "RegisterMessage", function() end)
    override(stubs.nextDrag, "IsActive", function() return false end)
    override(_G, "InCombatLockdown", function() return false end)
    _G._cursorX, _G._cursorY = 600, 400
    _G._mouseButtonsDown = { LeftButton = true }
  end)

  after_each(function()
    if made then
      made:Cancel()
      made.frame:Hide()
      made = nil
    end
    lift.held = nil
    for i = #replaced, 1, -1 do
      local r = replaced[i]
      r[1][r[2]] = r[3]
    end
    unscreen()
    _G._mouseButtonsDown = nil
  end)

  teardown(function()
    for i = #MODULES, 1, -1 do ResetModuleStub(MODULES[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  it("shows where it was left, by the corner it grows from, kept on the screen", function()
    saved = { out = true, x = 900, y = 300 }
    local c = make()
    c:Draw(ctx())
    finishTweens()
    assert.is_true(c.frame:IsShown())
    local e = edges(c)
    assert.is_true(near(e.right, 900), "its right edge, growing left")
    assert.is_true(near(e.top, UIParent:GetHeight() - 300))
    opts.growX = "right"
    c:PlaceSaved()
    assert.is_true(near(edges(c).left, 900), "its left edge, growing right")
    saved.x = 5000
    c:PlaceSaved()
    assert.is_true(edges(c).right <= UIParent:GetWidth() + 1e-6)
  end)

  it("first shows in the middle of the screen's top third", function()
    saved = { out = true }
    local c = make()
    c:Draw(ctx())
    local e = edges(c)
    assert.is_true(near((e.left + e.right) / 2, UIParent:GetWidth() / 2))
    assert.is_true(near(e.top, UIParent:GetHeight() - UIParent:GetHeight() / 3))
  end)

  it("picked up and dropped away from the backpack, lands there and remembers where, on whole pixels", function()
    saved = { out = true, x = 900, y = 300 }
    local c = make()
    c:Draw(ctx())
    finishTweens()
    assert.is_true(c:PickUp())
    assert.are.equal(c.held, lift.held)
    _G._cursorX, _G._cursorY = 300, 600
    c:Update(0.01)
    assert.are.equal("Keep on Screen", c.hint:GetText())
    _G._mouseButtonsDown = {}
    c:Drop(ctx())
    finishTweens()
    assert.is_nil(c.held)
    assert.are.equal(UIParent, c.frame:GetParent())
    assert.is_true(saved.out)
    local unit = pixel:Unit(UIParent)
    assert.is_true(math.abs(saved.x / unit - math.floor(saved.x / unit + 0.5)) < 1e-6)
    assert.is_true(math.abs(saved.y / unit - math.floor(saved.y / unit + 0.5)) < 1e-6)
    assert.are_not.equal(900, saved.x)
  end)

  it("dropped on the open backpack, says Put Away, flies in, is put away and tells its kind", function()
    saved = { out = true, x = 900, y = 300 }
    local c = make()
    c:Draw(ctx())
    finishTweens()
    assert.is_true(c:PickUp())
    override(home.body, "IsMouseOver", function() return true end)
    c:Update(0.01)
    assert.are.equal("Put Away", c.hint:GetText())
    _G._mouseButtonsDown = {}
    c:Drop(ctx())
    finishTweens()
    assert.is_false(c.frame:IsShown())
    assert.is_false(saved.out)
    assert.are.equal(900, saved.x, "it remembers where it was")
    assert.are.equal(1, putAway)
  end)

  it("is not put away over a backpack that is closing", function()
    saved = { out = true, x = 900, y = 300 }
    local c = make()
    c:Draw(ctx())
    finishTweens()
    c:PickUp()
    home.closing = true
    override(home.body, "IsMouseOver", function() return true end)
    c:Update(0.01)
    assert.are.equal("Keep on Screen", c.hint:GetText())
  end)

  it("opens its settings on a right click", function()
    local c = make()
    c.frame:GetScript("OnMouseUp")(c.frame, "RightButton")
    assert.are.equal(1, opened)
  end)

  it("fades out in combat when told, and in a pet battle", function()
    saved = { out = true, x = 900, y = 300 }
    local c = make()
    c:Draw(ctx())
    finishTweens()
    fire("PLAYER_REGEN_DISABLED")
    finishTweens()
    assert.is_true(c.frame:IsShown(), "not unless told")
    fire("PLAYER_REGEN_ENABLED")
    opts.hideInCombat = true
    fire("PLAYER_REGEN_DISABLED")
    finishTweens()
    assert.is_false(c.frame:IsShown())
    fire("PLAYER_REGEN_ENABLED")
    finishTweens()
    assert.is_true(c.frame:IsShown())
    fire("PET_BATTLE_OPENING_START")
    finishTweens()
    assert.is_false(c.frame:IsShown())
    fire("PET_BATTLE_CLOSE")
    finishTweens()
    assert.is_true(c.frame:IsShown())
  end)

  describe("emerging", function()
    it("comes out of the open backpack's middle, small, to where it was left at its scale, sparkles bursting", function()
      saved = { out = true, x = 900, y = 300 }
      opts.scale = 150
      local c = make()
      c:Emerge(ctx())
      assert.is_true(c.frame:IsShown())
      assert.is_true(c.frame:GetAlpha() < 1, "it fades in")
      local start = edges(c)
      local hx, hy = lift:Center(home.body)
      assert.is_true(near((start.left + start.right) / 2, hx))
      assert.is_true(near((start.top + start.bottom) / 2, hy))
      assert.is_true(math.abs(start.scale - style.Theme.Drag.FlyScale * 1.5) < 1e-6)
      assert.is_true(#c.burst.alive > 0, "sparkles burst as it comes out")
      assert.is_false(c:PickUp(), "it cannot be picked up while it comes out")
      finishTweens()
      local e = edges(c)
      assert.is_true(math.abs(e.scale - 1.5) < 1e-6)
      assert.is_true(near(e.right, 900))
      assert.is_true(near(e.top, UIParent:GetHeight() - 300))
      assert.are.equal(1, c.frame:GetAlpha())
      assert.is_nil(c.emerging)
      assert.is_true(c:PickUp(), "and can be once it is out")
    end)

    it("fades in where it was left with the backpack closed", function()
      saved = { out = true, x = 900, y = 300 }
      home.frame:Hide()
      local c = make()
      c:Emerge(ctx())
      assert.is_nil(c.emerging)
      local e = edges(c)
      assert.is_true(near(e.right, 900))
      finishTweens()
      assert.is_true(c.frame:IsShown())
      assert.are.equal(1, c.frame:GetAlpha())
    end)

    -- Found by the bug review: the card came out in its own strata, under the backpack it came out of (HIGH), while
    -- it is put away over everything (the drag layer).
    it("comes out over the backpack, on the drag layer, and rests on the screen as before", function()
      saved = { out = true, x = 900, y = 300 }
      home.frame:SetFrameStrata("HIGH")
      local c = make()
      c:Emerge(ctx())
      assert.are.equal(lift.layer, c.frame:GetParent())
      assert.are.equal("TOOLTIP", c.frame:GetFrameStrata())
      finishTweens()
      assert.are.equal(UIParent, c.frame:GetParent())
      assert.are.equal("MEDIUM", c.frame:GetFrameStrata())
      assert.is_true(near(edges(c).right, 900))
      c:Emerge(ctx())
      c:Cancel()
      assert.are.equal(UIParent, c.frame:GetParent())
      assert.are.equal("MEDIUM", c.frame:GetFrameStrata())
    end)

    -- Found by the second bug review: putting the card back on the screen as it landed set its alpha to 1, cutting a
    -- theme's longer fade in short (Frost's: from 0.915 to 1 in a frame).
    it("goes on fading in after it lands, where its fade is longer than its flight", function()
      saved = { out = true, x = 900, y = 300 }
      override(style.Time, "Hover", style.Time.Land * 2)
      local c = make()
      c:Emerge(ctx())
      local update = tween.driver:GetScript("OnUpdate")
      for _ = 1, 200 do
        if c.emerging == nil then break end
        update(tween.driver, 0.01)
      end
      assert.is_nil(c.emerging)
      local alpha = c.frame:GetAlpha()
      assert.is_true(alpha < 1, "still fading in")
      update(tween.driver, 0.01)
      assert.is_true(c.frame:GetAlpha() >= alpha, "on from where it was")
      finishTweens()
      assert.are.equal(1, c.frame:GetAlpha())
    end)

    it("stops where it is switched off as it comes out", function()
      saved = { out = true, x = 900, y = 300 }
      local c = make()
      c:Emerge(ctx())
      c:SetActive(ctx(), false)
      assert.is_nil(c.emerging)
      assert.is_false(c.frame:IsShown())
      finishTweens()
      assert.is_false(c.frame:IsShown())
    end)
  end)
end)
