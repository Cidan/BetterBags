-- papercraft_spec.lua -- The Papercraft theme (next-themes.md §25) on the whole addon (spec/helpers/whole_addon.lua): its
-- text written by hand on the parts the bags share with the classic design, whatever the classic themes do around it,
-- and a real bag unfolding and crumpling, in and out of its switches. Asked: "the text should all look like it's hand
-- drawn".

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("the Papercraft theme on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
    end
    handle = nil
  end)

  local function start(theme)
    handle = WholeAddon.Load({
      next = true,
      profile = function(defaults) defaults.nextTheme = theme or "Papercraft" end,
    })
    handle:Start()
    return handle.addon
  end

  local function module(name)
    return handle.addon:GetModule(name)
  end

  local function ctx()
    return module("Context"):New("spec")
  end

  -- Runs the drivers a paper bag lives on, seconds of them, a frame at a time.
  local function run(seconds)
    local tween, paper = module("NextTween"), module("NextPaper")
    for _ = 1, math.ceil(seconds * 60) do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update then update(tween.driver, 1 / 60) end
      local driver = paper.layer and paper.layer.driver
      update = driver and driver:GetScript("OnUpdate")
      if update then update(driver, 1 / 60) end
    end
  end

  local function living()
    local n = 0
    for _ in pairs(module("NextPaper").living) do
      n = n + 1
    end
    return n
  end

  local function buttons(bag)
    local m = bag.moneyFrame
    return { m.copperButton, m.silverButton, m.goldButton }
  end

  it("starts with no error, the bags' money written in a hand", function()
    local addon = start()
    assert.same({}, handle.errors)
    local price = module("NextStyle"):Font("Price")
    for _, bag in ipairs({ addon.Bags.Backpack, addon.Bags.Bank }) do
      for _, button in ipairs(buttons(bag)) do
        assert.are.equal(price, button:GetNormalFontObject())
      end
    end
    local file = price:GetFont()
    assert.is_true(file:find("papercraft", 1, true) ~= nil, file)
  end)

  it("keeps the money in a hand when the bags' theme applies, and gives it back to another Next theme", function()
    local addon = start()
    local bag = addon.Bags.Backpack
    module("Sonata"):ApplyTheme(ctx(), "Dark", false)
    assert.same({}, handle.errors)
    for _, button in ipairs(buttons(bag)) do
      assert.are.equal(module("NextStyle"):Font("Price"), button:GetNormalFontObject())
    end
    module("SonataNext"):ApplyTheme(ctx(), "Default", false)
    for _, button in ipairs(buttons(bag)) do
      assert.are.equal(module("Sonata"):GetTextFont("Money"), button:GetNormalFontObject())
    end
    module("Sonata"):ApplyTheme(ctx(), "Default", false)
    for _, button in ipairs(buttons(bag)) do
      assert.are.equal(module("Sonata"):GetTextFont("Money"), button:GetNormalFontObject(), "a theme moves it again")
    end
    assert.same({}, handle.errors)
  end)

  it("leaves the money in the frame's own font under a Next theme that names none", function()
    local addon = start("Default")
    for _, button in ipairs(buttons(addon.Bags.Backpack)) do
      assert.are.equal(module("Sonata"):GetTextFont("Money"), button:GetNormalFontObject())
    end
  end)

  it("unfolds a real bag, crumples it, tosses it off the screen, and does it all again", function()
    local addon = start()
    local bag = addon.Bags.Backpack
    for _ = 1, 2 do
      local shown = false
      bag:Show(ctx(), nil, function() shown = true end)
      run(0.5)
      assert.is_false(shown, "still unfolding")
      assert.are.equal(0, bag.frame:GetAlpha(), "the sheet in its place")
      run(2)
      assert.is_true(shown)
      assert.are.equal(1, bag.frame:GetAlpha())
      assert.are.equal(0, living(), "the sheet gone over it")
      bag:Hide(ctx())
      run(0.1)
      assert.is_true(bag.frame:IsShown(), "grabbed")
      run(0.4)
      assert.is_false(bag.frame:IsShown(), "the sheet in its place")
      assert.are.equal(1, living(), "a ball flying")
      run(4)
      assert.are.equal(0, living(), "fallen off the screen")
    end
    assert.same({}, handle.errors)
  end)

  it("slides a bag in and out with Paper Folding off, on no sheet", function()
    local addon = start()
    local bag = addon.Bags.Backpack
    local db, events = module("Database"), module("Events")
    db:SetNextAnimation("paper", false)
    events:SendMessage(ctx(), "next/AnimationChanged")
    bag:Show(ctx())
    assert.are.equal(0, living())
    run(1)
    assert.are.equal(0, bag.offset)
    bag:Hide(ctx())
    assert.are.equal(0, living())
    run(1)
    assert.is_false(bag.frame:IsShown())
    assert.same({}, handle.errors)
  end)

  it("ends a sheet when the bags switch design under it", function()
    local addon = start()
    local system = module("BagSystem")
    addon.Bags.Backpack:Show(ctx())
    run(0.2)
    system:Switch(ctx(), "classic")
    run(3)
    assert.are.equal(0, living())
    assert.same({}, handle.errors)
    system:Switch(ctx(), "next")
    run(1)
    assert.same({}, handle.errors)
  end)
end)
