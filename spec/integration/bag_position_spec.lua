-- bag_position_spec.lua -- Where a classic bag opens, on the whole addon (spec/helpers/whole_addon.lua) with its frames
-- resolved on a real screen (spec/helpers/layout.lua): the real bag, window and LibWindow-1.1 (window.md §3c). Reported
-- by several players on v0.8.10: "frames no longer remember their last position and open partially off screen". A bag
-- sized to its content kept its bottom edge, and the first bottom it kept was a placeholder's (200 tall, as it was made)
-- or the first bank tab's, so a bag saved by its top or its middle opened somewhere else, and past the top of the screen.
--
-- The frame mock has no item button template, so no item can be drawn on the whole addon (test-harness.md §5): every bag
-- is empty, and a bag's content height stands in for what it holds (MinContentHeight, MinContentWidth).

local WholeAddon = dofile("spec/helpers/whole_addon.lua")
local layout = dofile("spec/helpers/layout.lua")

-- The screen: 1366 x 768 units at a UI scale of 1.
local SCREEN_WIDTH, SCREEN_HEIGHT = 1366, 768
local BACKPACK, BANK = 0, 1

local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

describe("where a classic bag opens", function()
  local handle, undoScreen, timers

  local function stop()
    if handle then
      handle:Restore()
    end
    handle = nil
    if undoScreen then
      undoScreen()
    end
    undoScreen = nil
    timers = nil
  end

  after_each(stop)

  local function frames()
    for _ = 1, 40 do
      local due = {}
      for i = #timers, 1, -1 do
        if timers[i].delay == 0 then
          table.insert(due, 1, table.remove(timers, i))
        end
      end
      if #due == 0 then
        return
      end
      for _, t in ipairs(due) do
        if not t.cancelled then t.fn() end
      end
    end
  end

  -- start starts the whole addon on the screen with the positions given saved, and returns it past the startup read,
  -- unless opts.unread. opts.profile changes any other default. Starting again is a /reload.
  local function start(positions, opts)
    opts = opts or {}
    stop()
    undoScreen = layout.UseScreen(SCREEN_WIDTH, SCREEN_HEIGHT, 1)
    timers = {}
    local gameMenu = _G.CreateFrame("Frame")
    gameMenu:Hide()
    handle = WholeAddon.Load({
      globals = {
        -- The mock's own: the harness's gives every frame a rect at the origin, and these are resolved on the screen.
        CreateFrame = _G.CreateFrame,
        GameMenuFrame = gameMenu,
        C_Container = setmetatable({ GetContainerNumSlots = function() return 0 end }, { __index = _G.C_Container }),
        C_Bank = setmetatable({ CloseBankFrame = function() end }, { __index = _G.C_Bank }),
        C_Timer = {
          After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end,
          NewTimer = function(delay, fn)
            local t = { delay = delay, fn = fn }
            function t:Cancel() self.cancelled = true end
            table.insert(timers, t)
            return t
          end,
        },
      },
      profile = function(defaults, const)
        for kind, position in pairs(positions or {}) do
          defaults.positions[kind] = copy(position)
        end
        if opts.profile then
          opts.profile(defaults, const)
        end
      end,
    })
    handle:Start()
    local addon = handle.addon
    if not opts.unread then
      local refresh = addon:GetModule("Refresh")
      refresh._worldFrame:GetScript("OnEvent")(refresh._worldFrame, "LOADING_SCREEN_DISABLED")
      refresh._worldFrame:GetScript("OnUpdate")(refresh._worldFrame, 0.016)
      frames()
    end
    return addon
  end

  local function ctxOf(addon)
    return addon:GetModule("Context"):New("bag position")
  end

  -- holding gives a bag content of a height (and a width), read on each render.
  local function holding(bag, height, width)
    bag.window.opts.MinContentHeight = function() return height end
    if width ~= nil then
      bag.window.opts.MinContentWidth = function() return width end
    end
  end

  -- drag moves a bag as the player does: its top right corner dropped at a place on the screen.
  local function drag(bag, right, top)
    local frame = bag.frame
    frame:GetScript("OnDragStart")(frame, "LeftButton")
    local scale = frame:GetScale()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (right - frame:GetWidth() * scale) / scale, top / scale)
    frame:GetScript("OnDragStop")(frame)
  end

  local function rect(bag)
    return layout.Rect(bag.frame)
  end

  local function near(a, b)
    return math.abs(a - b) < 0.01
  end

  local function sameRect(a, b, what)
    for _, side in ipairs({ "left", "right", "top", "bottom" }) do
      assert.is_true(near(a[side], b[side]),
        string.format("%s: %s is %.1f, wanted %.1f", what, side, b[side], a[side]))
    end
  end

  local function onScreen(r, what)
    assert.is_true(r.left >= -0.01 and r.bottom >= -0.01, what .. ": past the left or the bottom")
    assert.is_true(r.right <= SCREEN_WIDTH + 0.01, what .. ": past the right")
    assert.is_true(r.top <= SCREEN_HEIGHT + 0.01, string.format("%s: top is %.1f, past the screen's", what, r.top))
  end

  -- redraw is the backpack's next read: its window draws what the bags hold now.
  local function redraw(addon)
    addon:GetModule("Events"):SendMessage(ctxOf(addon), "items/RefreshBackpack/Done",
      addon:GetModule("Items"):GetAllSlotInfo()[BACKPACK])
  end

  -- readBank reads the bank, for real: a read draws what it read (a bank never read has nothing to draw).
  local function readBank(addon)
    addon.atBank = true
    addon:GetModule("Refresh"):RequestUpdate({ bank = true })
    frames()
  end

  describe("after a reload", function()
    -- Each place is saved a different way (LibWindow-1.1 picks the point nearest the screen's edges and middle), and only
    -- a bottom point came back right: a real player's file holds RIGHT and TOPLEFT.
    for _, case in ipairs({
      { name = "near the top of the screen, saved by its top", right = 1350, top = 750, content = 400, point = "TOPRIGHT" },
      { name = "in the middle of the screen, saved by its middle", right = 1350, top = 500, content = 300, point = "RIGHT" },
      { name = "low on the screen, saved by its bottom", right = 1350, top = 300, content = 100, point = "BOTTOMRIGHT" },
      { name = "at the top in the middle, saved by its top", right = 800, top = 760, content = 200, point = "TOP" },
      { name = "in the very middle", right = 833, top = 500, content = 200, point = "CENTER" },
    }) do
      it("opens where it was dropped: " .. case.name, function()
        local addon = start()
        local bag = addon.Bags.Backpack
        holding(bag, case.content)
        bag:Show(ctxOf(addon))
        drag(bag, case.right, case.top)
        local dropped = rect(bag)
        onScreen(dropped, "dropped")
        local saved = copy(addon:GetModule("Database"):GetBagPosition(BACKPACK))
        assert.are.equal(case.point, saved.point)

        addon = start({ [BACKPACK] = saved })
        bag = addon.Bags.Backpack
        holding(bag, case.content)
        bag:Show(ctxOf(addon))
        sameRect(dropped, rect(bag), "after a reload")
        assert.are.same({}, handle.errors)
      end)
    end

    it("opens where it was dropped at the scale it is drawn at", function()
      local function scaled(defaults, const)
        for _, view in pairs(defaults.size) do
          view[const.BAG_KIND.BACKPACK].scale = 80
        end
      end
      local addon = start(nil, { profile = scaled })
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 750)
      local dropped = rect(bag)
      local saved = copy(addon:GetModule("Database"):GetBagPosition(BACKPACK))

      addon = start({ [BACKPACK] = saved }, { profile = scaled })
      bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      sameRect(dropped, rect(bag), "after a reload")
    end)

    -- A real player's saved backpack, from their SavedVariables: its middle 22.5 under the screen's, at a scale of 0.92.
    it("keeps a real player's saved backpack where its save says", function()
      local addon = start({ [BACKPACK] = { point = "RIGHT", x = -55.238033039903, y = -22.538492329663, scale = 0.9200000166893 } },
        { profile = function(defaults, const)
          for _, view in pairs(defaults.size) do
            view[const.BAG_KIND.BACKPACK].scale = 92
          end
        end })
      local bag = addon.Bags.Backpack
      holding(bag, 600)
      bag:Show(ctxOf(addon))
      local r = rect(bag)
      assert.is_true(near((r.top + r.bottom) / 2, SCREEN_HEIGHT / 2 - 22.538492329663),
        string.format("its middle is %.1f", (r.top + r.bottom) / 2))
      onScreen(r, "a real player's backpack")
    end)

    it("opens in the middle of the screen with nothing saved, a tall bag too", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 600)
      bag:Show(ctxOf(addon))
      local r = rect(bag)
      assert.is_true(near((r.top + r.bottom) / 2, SCREEN_HEIGHT / 2))
      assert.is_true(near((r.left + r.right) / 2, SCREEN_WIDTH / 2))
      onScreen(r, "nothing saved")
    end)

    it("goes by its save while it says Loading..., opened before the first read", function()
      local saved = { point = "TOPRIGHT", x = -16, y = -18, scale = 1 }
      local addon = start({ [BACKPACK] = saved }, { unread = true })
      local bag = addon.Bags.Backpack
      assert.is_true(bag.loading, "nothing read yet")
      holding(bag, 100)
      bag:Show(ctxOf(addon))
      assert.is_true(near(rect(bag).top, SCREEN_HEIGHT - 18), "while Loading...")
      holding(bag, 400)
      local refresh = addon:GetModule("Refresh")
      refresh._worldFrame:GetScript("OnEvent")(refresh._worldFrame, "LOADING_SCREEN_DISABLED")
      refresh._worldFrame:GetScript("OnUpdate")(refresh._worldFrame, 0.016)
      frames()
      assert.is_false(bag.loading, "read")
      assert.is_true(near(rect(bag).top, SCREEN_HEIGHT - 18), "drawn")
    end)

    -- It had grown since it was dropped (more items now): saved by its middle it spreads past the top by itself.
    it("stays on the screen when it holds more than when it was dropped", function()
      local addon = start({ [BACKPACK] = { point = "RIGHT", x = -16, y = 200, scale = 1 } })
      local bag = addon.Bags.Backpack
      holding(bag, 600)
      bag:Show(ctxOf(addon))
      onScreen(rect(bag), "taller than when it was dropped")
    end)
  end)

  describe("while it is open", function()
    it("stays where it is, closed and opened again", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      local ctx = ctxOf(addon)
      bag:Show(ctx)
      drag(bag, 1350, 750)
      local dropped = rect(bag)
      bag:Hide(ctx)
      bag:Show(ctx)
      sameRect(dropped, rect(bag), "opened again")
    end)

    it("keeps its bottom edge as it grows, so it grows upward", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 200)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 400)
      local dropped = rect(bag)
      holding(bag, 300)
      redraw(addon)
      local grown = rect(bag)
      assert.is_true(near(grown.bottom, dropped.bottom), "its bottom stays")
      assert.is_true(near(grown.top, dropped.top + 100), "its top goes up")
    end)

    it("stops at the top of the screen as it grows, and comes back as it shrinks", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 750)
      local dropped = rect(bag)
      holding(bag, 600)
      redraw(addon)
      local grown = rect(bag)
      onScreen(grown, "grown")
      assert.is_true(near(grown.top, SCREEN_HEIGHT), "pressed against the top")
      holding(bag, 400)
      redraw(addon)
      sameRect(dropped, rect(bag), "back as it shrank")
    end)

    it("stops at the right of the screen as it grows wider", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 200, 300)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 400)
      holding(bag, 200, 500)
      redraw(addon)
      onScreen(rect(bag), "wider")
    end)

    it("stays on the screen when the screen gets smaller", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 750)
      UIParent:_SetRect(0, 0, 1000, 600)
      redraw(addon)
      local r = rect(bag)
      assert.is_true(r.right <= 1000.01 and r.top <= 600.01, "inside the smaller screen")
    end)
  end)

  -- Clamp Bags to Screen off (window.md §3a): a player may drag a bag off the screen, and it stays where they put it.
  describe("dropped partly off the screen", function()
    it("stays there as it grows, and after a reload", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 900)
      local dropped = rect(bag)
      assert.is_true(dropped.top > SCREEN_HEIGHT, "past the top")
      holding(bag, 500)
      redraw(addon)
      local grown = rect(bag)
      assert.is_true(near(grown.bottom, dropped.bottom), "its bottom stays where the player put it")
      assert.is_true(grown.top > dropped.top, "not pulled back")
      holding(bag, 400)
      redraw(addon)
      local saved = copy(addon:GetModule("Database"):GetBagPosition(BACKPACK))

      addon = start({ [BACKPACK] = saved })
      bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      sameRect(dropped, rect(bag), "after a reload")
      holding(bag, 500)
      redraw(addon)
      assert.is_true(rect(bag).top > SCREEN_HEIGHT, "not pulled back after a reload either")
    end)

    it("fits the screen again once it is dropped on it", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 900)
      drag(bag, 1350, 750)
      holding(bag, 600)
      redraw(addon)
      onScreen(rect(bag), "dropped back on the screen")
    end)
  end)

  describe("with the setting on", function()
    -- The mock does not move a frame for its clamp: this does, as the client does (warcraft.wiki.gg
    -- Frame:SetClampedToScreen), on a frame anchored by its bottom left, or by what LibWindow-1.1 saved.
    local function clampLikeTheClient(bag)
      local frame = bag.frame
      local set = frame.SetClampedToScreen
      frame.SetClampedToScreen = function(f, clamped)
        set(f, clamped)
        if clamped then
          local r = layout.Rect(f)
          local scale = f:GetEffectiveScale()
          local left = math.min(r.left, SCREEN_WIDTH - (r.right - r.left))
          local bottom = math.min(r.bottom, SCREEN_HEIGHT - (r.top - r.bottom))
          f:ClearAllPoints()
          f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.max(0, left) / scale, math.max(0, bottom) / scale)
        end
      end
    end

    it("puts a bag dropped off the screen back on it, which stays when the setting goes off again", function()
      local addon = start()
      local bag = addon.Bags.Backpack
      clampLikeTheClient(bag)
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 900)
      assert.is_true(rect(bag).top > SCREEN_HEIGHT, "dropped off it")
      local database = addon:GetModule("Database")
      local events = addon:GetModule("Events")
      database:SetClampBagsToScreen(true)
      events:SendMessage(ctxOf(addon), "bags/ClampChanged")
      local back = rect(bag)
      onScreen(back, "turned on")
      database:SetClampBagsToScreen(false)
      events:SendMessage(ctxOf(addon), "bags/ClampChanged")
      redraw(addon)
      sameRect(back, rect(bag), "turned off again and drawn")
    end)
  end)

  -- The bank's tabs read in one at a time (refresh-scheduler.md §11a): it grows as it opens, every visit. Reported in the
  -- reproduction: saved at the top left, its top went 747, then 917, then 1097.
  describe("the bank", function()
    local TOPLEFT = { point = "TOPLEFT", x = 0, y = -20, scale = 1 }

    -- visit opens the bank as the refresh scheduler does: said to be opening, shown, its tabs read in, said to be loaded.
    local function visit(addon, heights)
      local bank = addon.Bags.Bank
      local ctx = ctxOf(addon)
      local events = addon:GetModule("Events")
      local tops = {}
      holding(bank, 100)
      events:SendMessage(ctx, "bags/BankOpening")
      bank:Show(ctx)
      for _, height in ipairs(heights) do
        holding(bank, height)
        readBank(addon)
        table.insert(tops, rect(bank).top)
      end
      events:SendMessage(ctx, "bags/BankLoaded")
      return tops
    end

    local function leave(addon)
      local ctx = ctxOf(addon)
      addon.Bags.Bank:Hide(ctx)
      addon.Bags.Bank:SwitchToBankAndWipe(ctx)
      addon.atBank = false
    end

    it("keeps its saved top as its tabs read in, every visit", function()
      local addon = start({ [BANK] = TOPLEFT })
      for _, name in ipairs({ "first visit", "second visit" }) do
        for i, top in ipairs(visit(addon, { 250, 420, 600 })) do
          assert.is_true(near(top, SCREEN_HEIGHT - 20), string.format("%s, tab %d: top %.1f", name, i, top))
        end
        onScreen(rect(addon.Bags.Bank), name)
        leave(addon)
      end
    end)

    it("goes back to its saved position on the next visit, holding something else by then", function()
      local addon = start({ [BANK] = TOPLEFT })
      visit(addon, { 250, 400 })
      leave(addon)
      visit(addon, { 250, 300 })
      assert.is_true(near(rect(addon.Bags.Bank).top, SCREEN_HEIGHT - 20), "its saved top, once loaded")
    end)

    it("leaves the backpack where it is as it opens", function()
      local addon = start({ [BANK] = TOPLEFT })
      local bag = addon.Bags.Backpack
      holding(bag, 100)
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 500)
      assert.are.equal("RIGHT", addon:GetModule("Database"):GetBagPosition(BACKPACK).point, "saved by its middle")
      -- Grown since it was dropped, so it is not where its save says.
      holding(bag, 200)
      redraw(addon)
      local before = rect(bag)
      addon:GetModule("Events"):SendMessage(ctxOf(addon), "bags/BankOpening")
      sameRect(before, rect(bag), "the bank opening")
      holding(bag, 250)
      redraw(addon)
      assert.is_true(near(rect(bag).bottom, before.bottom), "it still keeps its bottom edge")
      assert.is_true(near(rect(bag).top, before.top + 50), "and grows upward")
    end)

    it("goes back to where it was dropped on the next visit, whatever it read last", function()
      local addon = start()
      local bank = addon.Bags.Bank
      visit(addon, { 300 })
      drag(bank, 500, 700)
      local dropped = rect(bank)
      leave(addon)
      visit(addon, { 100, 200, 300 })
      sameRect(dropped, rect(bank), "next visit")
    end)

    it("keeps its bottom edge once its tabs have read in, stopping at the top of the screen", function()
      local addon = start({ [BANK] = TOPLEFT })
      local bank = addon.Bags.Bank
      visit(addon, { 250, 400 })
      local loaded = rect(bank)
      holding(bank, 450)
      readBank(addon)
      local grown = rect(bank)
      assert.is_true(near(grown.bottom, loaded.bottom) or near(grown.top, SCREEN_HEIGHT), "its bottom kept, or at the top")
      assert.is_true(grown.top <= SCREEN_HEIGHT + 0.01, "never past the top")
    end)

    it("fits the screen once loaded when its tabs took it past the screen around its saved middle", function()
      local addon = start({ [BANK] = { point = "LEFT", x = 10, y = 250, scale = 1 } })
      local bank = addon.Bags.Bank
      visit(addon, { 300, 600 })
      onScreen(rect(bank), "loaded")
    end)

    it("keeps a place the player dropped it at while its tabs were reading", function()
      local addon = start({ [BANK] = TOPLEFT })
      local bank = addon.Bags.Bank
      local ctx = ctxOf(addon)
      local events = addon:GetModule("Events")
      holding(bank, 100)
      events:SendMessage(ctx, "bags/BankOpening")
      bank:Show(ctx)
      holding(bank, 300)
      readBank(addon)
      drag(bank, 900, 700)
      local dropped = rect(bank)
      events:SendMessage(ctx, "bags/BankLoaded")
      sameRect(dropped, rect(bank), "loaded after it was dropped")
    end)

    -- Through the real event: a bank with no tab with slots reads once, then says it is loaded.
    it("is told when an open starts and when its reads are done", function()
      local addon = start({ [BANK] = { point = "TOPLEFT", x = 0, y = -200, scale = 1 } })
      local bank = addon.Bags.Bank
      holding(bank, 300)
      addon:GetModule("Events")._eventMap["BANKFRAME_OPENED"].fn("BANKFRAME_OPENED")
      frames()
      assert.is_true(bank:IsShown())
      assert.is_true(near(rect(bank).top, SCREEN_HEIGHT - 200), "at its saved top")
      assert.is_false(bank.bankOpening, "its reads are done")
      holding(bank, 350)
      readBank(addon)
      assert.is_true(near(rect(bank).top, SCREEN_HEIGHT - 200 + 50), "loaded: it keeps its bottom edge")
      assert.are.same({}, handle.errors)
    end)
  end)

  describe("placed some other way", function()
    it("follows its anchor while the anchor is on, and the bank's stays on its anchor as it opens", function()
      local anchorAt = { point = "TOPRIGHT", x = -16, y = -18, scale = 1 }
      local addon = start(nil, { profile = function(defaults, const)
        for _, kind in ipairs({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }) do
          defaults.anchorState[kind].enabled = true
          defaults.anchorPositions[kind] = copy(anchorAt)
        end
      end })
      local bag = addon.Bags.Backpack
      holding(bag, 400)
      bag:Show(ctxOf(addon))
      assert.is_true(near(rect(bag).top, SCREEN_HEIGHT - 18))
      assert.is_true(near(rect(bag).right, SCREEN_WIDTH - 16))
      local bank = addon.Bags.Bank
      local ctx = ctxOf(addon)
      holding(bank, 400)
      addon:GetModule("Events"):SendMessage(ctx, "bags/BankOpening")
      assert.is_true(near(rect(bank).top, SCREEN_HEIGHT - 18), "on its anchor from the start, before anything draws")
      bank:Show(ctx)
      readBank(addon)
      addon:GetModule("Events"):SendMessage(ctx, "bags/BankLoaded")
      assert.is_true(near(rect(bank).top, SCREEN_HEIGHT - 18), "the bank at its anchor")
    end)

    local function sized(defaults, const)
      for _, view in pairs(defaults.size) do
        local v = view[const.BAG_KIND.BACKPACK]
        v.sizeMode, v.width, v.height = "window", 400, 491
      end
    end

    it("keeps a bag the player sized where it was dropped, after a reload", function()
      local addon = start(nil, { profile = sized })
      local bag = addon.Bags.Backpack
      bag:Show(ctxOf(addon))
      drag(bag, 1350, 750)
      local dropped = rect(bag)
      local saved = copy(addon:GetModule("Database"):GetBagPosition(BACKPACK))
      addon = start({ [BACKPACK] = saved }, { profile = sized })
      bag = addon.Bags.Backpack
      bag:Show(ctxOf(addon))
      sameRect(dropped, rect(bag), "after a reload")
    end)

    -- Sized by its grip (its bottom edge moved), then back to sized by its content: it stays where it is, not at the
    -- bottom edge it had before the grip moved it.
    it("does not jump when Drag to Resize goes off after the grip moved its bottom edge", function()
      local addon = start(nil, { profile = sized })
      local bag = addon.Bags.Backpack
      local ctx = ctxOf(addon)
      bag:Show(ctx)
      drag(bag, 1350, 750)
      local top = rect(bag).top
      -- The grip: the bottom right corner dragged, the top left where it was (window.md §3).
      local frame = bag.frame
      frame:SetSize(frame:GetWidth(), 300)
      bag.window.opts.OnResized(ctx, frame:GetWidth(), 300)
      bag.window:SavePosition()
      assert.is_true(near(rect(bag).top, top), "the top stays as the grip moves the bottom")
      local database = addon:GetModule("Database")
      database:SetBagSizeMode(BACKPACK, "content")
      holding(bag, 209)
      redraw(addon)
      assert.is_true(near(rect(bag).top, top), string.format("top %.1f, wanted %.1f", rect(bag).top, top))
    end)
  end)
end)
