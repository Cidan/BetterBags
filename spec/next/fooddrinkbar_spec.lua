-- fooddrinkbar_spec.lua -- NextFoodDrinkBar (next/fooddrinkbar.lua): BetterBags Next's Food & Drink bar
-- (food-drink.md §3, §4): the food and the drink FoodDrink picks, each on one of BetterBags' item buttons pointed at its
-- slot, eaten with a right click only, on the card the currency tracker is (NextScreenCard), coming out of the open
-- backpack when it is switched on. The item buttons here are the mock widgets ItemFrame:Create makes, recording what the
-- bar does to them; frames/item.lua's own specs cover the buttons themselves (SetSlot: spec/frames/item_classic_spec.lua).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local stubs = {
  L = trackStub("Localization"), events = trackStub("Events"), nextDrag = trackStub("NextDrag"),
  database = trackStub("Database"), itemFrame = trackStub("ItemFrame"), itemFit = trackStub("NextItemFit"),
  foodDrink = trackStub("FoodDrink"), settings = trackStub("NextSettings"),
}

local MODULES = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextScreenCard", "next/screencard.lua" },
  { "NextFoodDrinkBar", "next/fooddrinkbar.lua" } }
for _, m in ipairs(MODULES) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local layout = dofile("spec/helpers/layout.lua")
local bar = addon:GetModule("NextFoodDrinkBar")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local lift = addon:GetModule("NextLift")
local motion = addon:GetModule("Motion")
local pixel = addon:GetModule("NextPixel")
local context = addon:GetModule("Context")

describe("NextFoodDrinkBar", function()
  local replaced, messages, registered, options, place, picks, home, made, opened, unscreen

  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx() return context:New("spec") end

  local function fire(name)
    for _, fn in ipairs(messages[name] or {}) do fn(ctx()) end
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

  -- An item button as ItemFrame:Create makes one (frames/item.lua _DoCreate): a hidden holder, the interaction button in
  -- it registered for both clicks and a drag, Blizzard's OnDragStart and OnReceiveDrag (ContainerFrameItemButtonMixin),
  -- and a decoration. It records what is drawn on it and where it points.
  local function newItem()
    local holder = CreateFrame("Frame")
    holder:Hide()
    local button = CreateFrame("Button", nil, holder)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function() button.pickedUp = true end)
    button:SetScript("OnReceiveDrag", function() button.received = true end)
    local decoration = CreateFrame("Button", nil, holder)
    local item = { frame = holder, button = button, ilvlText = button:CreateFontString(nil, "OVERLAY"), drawn = {} }
    function item:GetDecoration() return decoration end
    function item:SetSlot(_, bag, slot) self.bag, self.slot = bag, slot end
    -- Each draw notes the size it was drawn at: Masque sizes a skin to the button as the draw's item/Updated skins it.
    function item:SetStaticItemFromData(_, data)
      table.insert(self.drawn, data)
      self.drawnAt = holder:GetWidth()
      self.data = data
      decoration.matches = data.isSearchResult ~= false
      holder:Show()
    end
    function item:SetSize(_, w, h) holder:SetSize(w, h) end
    decoration.SetMatchesSearch = function(me, match) me.matches = match end
    made = made or {}
    table.insert(made, item)
    return item
  end

  local function pick(bag, slot, id, count, fields)
    local data = { slotkey = bag .. "_" .. slot, bagid = bag, slotid = slot, isItemEmpty = false,
      itemInfo = { itemID = id, currentItemCount = count, itemLevel = 1 } }
    for k, v in pairs(fields or {}) do data[k] = v end
    return { data = data, count = count }
  end

  local function create()
    return bar:Create(ctx(), home)
  end

  -- The size a button takes at rest (style.ICON on the card's grid at its scale, not the lift's while it moves).
  local function restingSize(b)
    return pixel:LengthIn(pixel:UnitAt(UIParent:GetEffectiveScale() * b:Scale()), style.ICON)
  end

  before_each(function()
    replaced, messages, registered, made, opened = {}, {}, {}, nil, {}
    unscreen = layout.UseScreen(1920, 1080, 1)
    UseNextTheme(nil)
    tween:Init()
    motion:Init()
    bar.instance = nil
    options = { pick = "highest", layout = "row", growX = "left", growY = "down", scale = 100, background = true,
      hideInCombat = true }
    place = { out = false }
    picks = {}
    home = { frame = CreateFrame("Frame", nil, UIParent), closing = false }
    home.body = CreateFrame("Frame", nil, home.frame)
    home.frame:_SetRect(1500, 100, 400, 900)
    home.body:SetAllPoints(home.frame)
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.events, "RegisterEvent", function(_, name, fn)
      registered[name] = registered[name] or {}
      table.insert(registered[name], fn)
    end)
    override(stubs.events, "RegisterMessage", function(_, name, fn)
      messages[name] = messages[name] or {}
      table.insert(messages[name], fn)
    end)
    override(stubs.nextDrag, "IsActive", function() return false end)
    override(stubs.database, "GetNextFoodDrinkOption", function(_, name) return options[name] end)
    override(stubs.database, "GetNextFoodDrinkBar", function() return place.out, place.x, place.y end)
    override(stubs.database, "SetNextFoodDrinkBar", function(_, out, x, y)
      place.out = out
      if x ~= nil then place.x, place.y = x, y end
    end)
    override(stubs.itemFrame, "Create", function() return newItem() end)
    override(stubs.itemFit, "Fit", function() end)
    override(stubs.foodDrink, "Picks", function() return picks end)
    override(stubs.settings, "Open", function(_, page, tab) table.insert(opened, page .. " > " .. tostring(tab)) end)
    override(_G, "InCombatLockdown", function() return false end)
    -- Blizzard's SetItemButtonCount (Blizzard_ItemButton ItemButtonTemplate.lua) keeps the count on the button.
    override(_G, "SetItemButtonCount", function(button, count) button.count = count end)
    _G._cursorX, _G._cursorY = 600, 400
    _G._mouseButtonsDown = { LeftButton = true }
  end)

  after_each(function()
    if bar.instance then
      bar.instance:Cancel()
      bar.instance.frame:Hide()
    end
    bar.instance = nil
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

  describe("its buttons", function()
    it("shows the food and the drink picked, each a button pointed at its slot, with the count of every stack", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      picks.drink = pick(1, 7, 159, 4)
      local b = create()
      local food, drink = b.buttons.food, b.buttons.drink
      assert.are.same({ 0, 3 }, { food.bag, food.slot })
      assert.are.same({ 1, 7 }, { drink.bag, drink.slot })
      assert.are.equal(picks.food.data, food.data)
      assert.are.equal(10, food:GetDecoration().count)
      assert.are.equal(4, drink:GetDecoration().count)
      assert.are.same({ "food", "drink" }, b.order)
      assert.are.equal(b.frame, food.frame:GetParent())
      assert.is_true(food.frame:IsShown())
      assert.is_true(b.frame:IsShown())
    end)

    it("eats with a right click only, takes no item dropped on it, and picks the bar up when dragged", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      local button = b.buttons.food.button
      assert.are.same({ "RightButtonUp" }, button._registeredClicks)
      assert.is_nil(button:GetScript("OnReceiveDrag"), "Blizzard's would place what the cursor holds in the slot")
      button:GetScript("OnDragStart")(button)
      assert.is_nil(button.pickedUp, "Blizzard's drag picks the item up")
      assert.are.equal(b.held, lift.held)
      _G._cursorX, _G._cursorY = 300, 600
      b:Update(0.01)
      _G._mouseButtonsDown = {}
      button:GetScript("OnDragStop")(button)
      finishTweens()
      assert.is_nil(b.held)
      assert.is_true(place.out)
      assert.are_not.equal(900, place.x)
    end)

    it("puts its buttons in the Food & Drink Masque group", function()
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      assert.are.equal("Food & Drink", b.buttons.food.masqueGroup)
    end)

    it("is never dimmed by a search in the bags", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10, { isSearchResult = false })
      local b = create()
      assert.is_true(b.buttons.food:GetDecoration().matches)
    end)

    it("hides a kind there is none of, the other closing up, and the bar with neither", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      picks.drink = pick(1, 7, 159, 4)
      local b = create()
      finishTweens()
      local both = b.frame:GetWidth()
      picks.food = nil
      fire("fooddrink/Changed")
      finishTweens()
      assert.is_false(b.buttons.food.frame:IsShown())
      assert.are.same({ "drink" }, b.order)
      assert.is_true(b.frame:GetWidth() < both)
      picks.drink = nil
      fire("fooddrink/Changed")
      finishTweens()
      assert.is_false(b.frame:IsShown())
      picks.drink = pick(1, 7, 159, 4)
      fire("fooddrink/Changed")
      finishTweens()
      assert.is_true(b.frame:IsShown(), "back as some arrives")
    end)

    it("moves a button to the next pick as it changes", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 1)
      local b = create()
      picks.food = pick(0, 9, 117, 20)
      fire("fooddrink/Changed")
      local food = b.buttons.food
      assert.are.same({ 0, 9 }, { food.bag, food.slot })
      assert.are.equal(20, food:GetDecoration().count)
      assert.are.equal(1, #made, "the same button")
    end)

    it("lays its buttons out in a row, or a column, the theme's item size apart by its gap", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      picks.drink = pick(1, 7, 159, 4)
      local b = create()
      finishTweens()
      local size = pixel:Length(b.frame, style.ICON)
      local gap = pixel:Length(b.frame, style.GAP)
      local pad = pixel:Length(b.frame, style.Theme.Currency.Tracker.Pad)
      assert.are.equal(size, b.buttons.food.frame:GetWidth())
      assert.is_true(math.abs(b.frame:GetWidth() - (pad * 2 + size * 2 + gap)) < 0.01)
      assert.is_true(math.abs(b.frame:GetHeight() - (pad * 2 + size)) < 0.01)
      options.layout = "column"
      fire("fooddrink/OptionsChanged")
      finishTweens()
      assert.is_true(math.abs(b.frame:GetWidth() - (pad * 2 + size)) < 0.01)
      assert.is_true(math.abs(b.frame:GetHeight() - (pad * 2 + size * 2 + gap)) < 0.01)
    end)
  end)

  describe("its card", function()
    it("comes out of the open backpack when switched on", function()
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      assert.is_false(b.frame:IsShown())
      place.out, place.x, place.y = true, 900, 300
      fire("fooddrink/OptionsChanged")
      assert.is_truthy(b.emerging)
      assert.is_true(b.frame:IsShown())
      finishTweens()
      assert.is_nil(b.emerging)
      assert.are.equal(1, b.frame:GetAlpha())
    end)

    it("fades in where it was left when switched on with the backpack closed", function()
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      home.frame:Hide()
      place.out, place.x, place.y = true, 900, 300
      fire("fooddrink/OptionsChanged")
      assert.is_nil(b.emerging)
      finishTweens()
      assert.is_true(b.frame:IsShown())
    end)

    it("dropped on the open backpack, is put away and switched off", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      assert.is_true(b:PickUp())
      override(home.body, "IsMouseOver", function() return true end)
      b:Update(0.01)
      _G._mouseButtonsDown = {}
      b:Drop(ctx())
      finishTweens()
      assert.is_false(b.frame:IsShown())
      assert.is_false(place.out)
      -- Switched on again, it comes back out.
      place.out = true
      fire("fooddrink/OptionsChanged")
      assert.is_truthy(b.emerging)
    end)

    it("hides in combat by default: nothing on it can be eaten there", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      fire("PLAYER_REGEN_DISABLED")
      finishTweens()
      assert.is_false(b.frame:IsShown())
      fire("PLAYER_REGEN_ENABLED")
      finishTweens()
      assert.is_true(b.frame:IsShown())
    end)

    it("takes its scale, and grows from its corner", function()
      place = { out = true, x = 900, y = 300 }
      options.scale = 150
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      local at = lift:ScreenPoint(b.frame)
      assert.is_true(math.abs(at.scale - 1.5) < 1e-6)
      local right = at.left + b.frame:GetWidth() * at.scale
      assert.is_true(math.abs(right - 900) <= pixel:Unit(UIParent) / 2 + 1e-6)
    end)

    it("opens the Food & Drink page on a right click on its card", function()
      local b = create()
      b.frame:GetScript("OnMouseUp")(b.frame, "RightButton")
      assert.are.same({ "fooddrink > display" }, opened)
    end)

    it("hides with BetterBags Next switched off, and shows again where it was left when it is back", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      b:SetActive(ctx(), false)
      assert.is_false(b.frame:IsShown())
      fire("fooddrink/Changed")
      assert.is_false(b.frame:IsShown(), "not while the classic bags are in use")
      b:SetActive(ctx(), true)
      assert.is_true(b.frame:IsShown())
    end)

    it("is one bar: made again for a new backpack, it is the same", function()
      local b = create()
      local other = { frame = CreateFrame("Frame"), body = CreateFrame("Frame"), closing = false }
      assert.are.equal(b, bar:Create(ctx(), other))
      assert.are.equal(other, b:Home())
    end)
  end)

  -- Found by the bug review (food-drink.md §6).
  describe("found by review", function()
    after_each(function()
      style:SetIconScale(100)
    end)

    -- The bags switched to BetterBags Next mid-session: the picks were read while the classic bags were in use, and
    -- nothing changes them again for a while.
    it("shows the picks already read as it is made", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      assert.is_true(b.frame:IsShown())
      assert.are.same({ "food" }, b.order)
    end)

    it("follows Icon Scale, as the bags' buttons do", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      local before = b.buttons.food.frame:GetWidth()
      override(stubs.database, "GetNextIconScale", function() return 150 end)
      fire("next/ScalesChanged")
      finishTweens()
      local size = b.buttons.food.frame:GetWidth()
      assert.is_true(size > before)
      assert.are.equal(pixel:Length(b.frame, style.ICON), size)
    end)

    -- Masque sizes a skin to the button as it skins it, on the draw's item/Updated: each draw comes at the button's size.
    it("draws a button at its size, as it is made and as a theme or the Icon Scale changes it", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      local food = b.buttons.food
      assert.are.equal(food.frame:GetWidth(), food.drawnAt)
      override(stubs.database, "GetNextIconScale", function() return 150 end)
      fire("next/ScalesChanged")
      finishTweens()
      assert.are.equal(food.frame:GetWidth(), food.drawnAt)
      override(stubs.database, "GetNextIconScale", function() return 100 end)
      style:SetIconScale(100)
      b:ApplyStyle(ctx())
      finishTweens()
      assert.are.equal(food.frame:GetWidth(), food.drawnAt)
    end)

    it("lays out what changes as it comes out once it is out, at its own size", function()
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      place.out, place.x, place.y = true, 900, 300
      fire("fooddrink/OptionsChanged")
      assert.is_truthy(b.emerging)
      local flying = b.frame:GetScale()
      picks.drink = pick(1, 7, 159, 4)
      fire("fooddrink/Changed")
      assert.are.equal(flying, b.frame:GetScale(), "coming out, it stays at its flight's scale")
      finishTweens()
      local unit = pixel:UnitAt(UIParent:GetEffectiveScale() * b:Scale())
      local size, gap = restingSize(b), pixel:LengthIn(unit, style.GAP)
      local pad = pixel:LengthIn(unit, style.Theme.Currency.Tracker.Pad)
      assert.are.equal(size, b.buttons.food.frame:GetWidth())
      assert.are.equal(size, b.buttons.drink.frame:GetWidth())
      assert.is_true(math.abs(b.frame:GetWidth() - (pad * 2 + size * 2 + gap)) < 1e-6)
      assert.are.equal(size, b.buttons.drink.drawnAt)
    end)

    it("lays out what changes while it is held once it lands, at its own size", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      assert.is_true(b:PickUp())
      finishTweens()
      local held = b.frame:GetScale()
      picks.drink = pick(1, 7, 159, 4)
      fire("fooddrink/Changed")
      assert.are.equal(held, b.frame:GetScale(), "held, it stays at the lift's scale")
      _G._cursorX, _G._cursorY = 300, 600
      b:Update(0.01)
      _G._mouseButtonsDown = {}
      b:Drop(ctx())
      finishTweens()
      local size = restingSize(b)
      assert.are.equal(size, b.buttons.food.frame:GetWidth())
      assert.are.equal(size, b.buttons.drink.frame:GetWidth())
      assert.are.same({ "food", "drink" }, b.order)
      assert.is_true(b.buttons.drink.frame:IsShown())
    end)

    it("hides a button whose pick is gone at once, even while it is held", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      picks.drink = pick(1, 7, 159, 4)
      local b = create()
      finishTweens()
      assert.is_true(b:PickUp())
      picks.drink = nil
      fire("fooddrink/Changed")
      assert.is_false(b.buttons.drink.frame:IsShown(), "nothing to click on a slot that changed")
    end)

    it("lays its buttons out on the new pixel grid when the UI scale changes", function()
      place = { out = true, x = 900, y = 300 }
      picks.food = pick(0, 3, 2287, 10)
      local b = create()
      finishTweens()
      unscreen()
      unscreen = layout.UseScreen(1920, 1080, 0.71)
      fire("UI_SCALE_CHANGED")
      finishTweens()
      assert.are.equal(pixel:Length(b.frame, style.ICON), b.buttons.food.frame:GetWidth())
    end)
  end)
end)
