-- bag_spec.lua -- NextBag (next/bag.lua): BetterBagsNext's backpack. A full-height panel that slides
-- in from the right, with a feathered left edge, the title and its sparkles, a search box, the
-- group tabs down its left side and the content in one column; it stands in for the backpack
-- everywhere the addon talks to it (next.md §1, §3).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }
local BACKPACK = const.BAG_KIND.BACKPACK

local stubs = {
  L = trackStub("Localization"),
  itemFrame = trackStub("ItemFrame"),
  items = trackStub("Items"),
  database = trackStub("Database"),
  groups = trackStub("Groups"),
  events = trackStub("Events"),
  searchBox = trackStub("SearchBox"),
  sonata = trackStub("Sonata"),
  money = trackStub("MoneyFrame"),
  cursorPlacement = trackStub("CursorPlacement"),
  backpackBehavior = trackStub("BackpackBehavior"),
  sectionFrame = trackStub("SectionFrame"),
  bagSystem = trackStub("BagSystem"),
}

-- Every function this spec replaces on a module, put back after each test and the file.
local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDrag", "next/drag.lua" }, { "NextPanel", "next/panel.lua" }, { "NextBag", "next/bag.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBag = addon:GetModule("NextBag")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

describe("NextBag", function()
  local buttons, sent, messages, buckets, groupsEnabled, activeGroup, allGroups, expired, inBagSearch
  local box, helper, placed, slotInfo

  -- fakeButton stands in for an item button, recording what is done to it.
  local function fakeButton(slotkey)
    local b = { slotkey = slotkey, frame = CreateFrame("Frame"), searched = {}, cooldowns = 0, released = 0 }
    b.frame:SetSize(37, 37)
    function b:SetItemFromData(_, data) self.data = data self.isFreeSlot = false end
    function b:SetFreeSlots(_, data) self.data = data self.isFreeSlot = true end
    function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
    function b:GetItemData() return self.data end
    function b:UpdateSearch(_, found)
      self.searches = (self.searches or 0) + 1
      table.insert(self.searched, found)
    end
    function b:UpdateCooldown() self.cooldowns = self.cooldowns + 1 return "start" end
    function b:Release() self.released = self.released + 1 end
    return b
  end

  local function item(slotkey, category)
    return { slotkey = slotkey, itemInfo = { category = category } }
  end

  -- tabData builds slot info with tab 1 holding a Weapons category and tab 2 a Herbs category.
  local function data(tab1Items, tab2Items, free)
    return {
      sortedItems = {},
      tabs = {
        [1] = { categories = { { name = "Weapons" } }, items = tab1Items or { item("0_1", "Weapons") }, freeSpace = free },
        [2] = { categories = { { name = "Herbs" } }, items = tab2Items or { item("0_7", "Herbs") } },
      },
    }
  end

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    buttons, sent, messages, buckets = {}, {}, {}, {}
    groupsEnabled, activeGroup, expired, inBagSearch = true, 1, false, true
    allGroups = { [1] = { id = 1, name = "Backpack" }, [2] = { id = 2, name = "Herbs" } }
    placed = {}
    slotInfo = data()
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.itemFrame, "GetButton", function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
      return buttons[slotkey]
    end)
    override(stubs.items, "GetAllSlotInfo", function() return { [BACKPACK] = slotInfo } end)
    override(stubs.items, "ExpireRecentItems", function() return expired end)
    override(stubs.database, "GetGroupsEnabled", function() return groupsEnabled end)
    override(stubs.database, "GetActiveGroup", function() return activeGroup end)
    override(stubs.database, "SetActiveGroup", function(_, _, id) activeGroup = id end)
    override(stubs.database, "GetInBagSearch", function() return inBagSearch end)
    override(stubs.groups, "GetAllGroups", function() return allGroups end)
    override(stubs.groups, "GetGroup", function(_, _, id) return allGroups[id] end)
    override(stubs.events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    override(stubs.events, "RegisterMessage", function(_, name, fn) messages[name] = fn end)
    override(stubs.events, "BucketEvent", function(_, name, fn, filter) buckets[name] = { fn, filter } end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      box.textBox = CreateFrame("EditBox", nil, box.frame)
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function(_, kind, element)
      table.insert(sent, { "unregistered", kind, element })
    end)
    override(stubs.money, "Create", function() return { frame = CreateFrame("Frame") } end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function(_, kind) table.insert(placed, kind) return "placed" end)
    helper = { menus = {}, created = 0 }
    function helper:ShowGroupContextMenu(_, id) table.insert(self.menus, id) end
    function helper:ShowCreateGroupDialog() self.created = self.created + 1 end
    override(stubs.backpackBehavior, "Create", function(_, bag) helper.bag = bag return helper end)
    override(_G, "PlaySound", function() end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
  end)

  after_each(function()
    restore()
  end)

  teardown(function()
    for _, m in ipairs({ "NextBag", "NextPanel", "NextDrag", "NextContent", "NextTabs", "NextSparkles", "NextTween", "NextStyle" }) do
      ResetModuleStub(m)
    end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function offset(bag)
    local _, _, _, x = bag.frame:GetPoint(1)
    return x
  end

  local function sentNamed(name)
    local out = {}
    for _, m in ipairs(sent) do
      if m[1] == name then table.insert(out, m) end
    end
    return out
  end

  local function opened()
    local bag = nextBag:Create(ctx())
    bag:Draw(ctx(), slotInfo, function() end)
    bag:Show(ctx())
    finishTweens()
    return bag
  end

  describe("the panel", function()
    it("is a hidden, named, full-height panel on the right edge of the screen", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(BACKPACK, bag.kind)
      assert.are.equal("BetterBagsNextBackpack", bag:GetName())
      assert.is_false(bag:IsShown())
      assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 }, { bag.frame:GetPoint(2) })
      assert.are.equal(style.WIDTH, bag.frame:GetWidth())
    end)

    -- Above every other part of the UI (MEDIUM panels, LOW bars, addon frames up to HIGH), below
    -- what must cover it: Blizzard's popups and game menu (DIALOG), menus (FULLSCREEN_DIALOG),
    -- tooltips, and the toplevel HIGH boxes that raise themselves when shown (the stack split).
    it("sits in the HIGH strata, raising itself when shown or clicked", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal("HIGH", bag.frame:GetFrameStrata())
      assert.is_true(bag.frame:IsToplevel())
    end)

    it("feathers its left edge out to nothing and takes no clicks there", function()
      local bag = nextBag:Create(ctx())
      local g = bag.feather._gradient
      assert.are.equal("HORIZONTAL", g.orientation)
      assert.are.equal(0, g.min.a)
      assert.are.equal(style.Color.Body[4], g.max.a)
      assert.are.equal(style.FEATHER, bag.feather:GetWidth())
      assert.are.same({ style.FEATHER, 0, 0, 0 }, { bag.frame:GetHitRectInsets() })
    end)

    it("titles itself in its title", function()
      local bag = nextBag:Create(ctx())
      bag:SetTitle("Backpack")
      assert.are.equal("Backpack", bag.title:GetText())
      assert.are.equal(style:Font("Title"), bag.title:GetFontObject())
    end)

    it("uses the backpack's in-bag search box, drawn by Next instead of the theme", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(BACKPACK, box.kind)
      assert.are.equal(box, bag.searchBox)
      assert.are.same({ "unregistered", "SearchBox", box.textBox }, sent[1])
      assert.is_true(box.frame:IsShown())
    end)

    it("hides the search box while in-bag search is off, and recalculates when it changes", function()
      inBagSearch = false
      local bag = nextBag:Create(ctx())
      assert.is_false(box.frame:IsShown())
      inBagSearch = true
      messages["search/SetInFrame"](ctx())
      assert.is_true(box.frame:IsShown())
      assert.are.same({ { "bags/Rederive", { resetLayout = true, buttons = true } } }, sentNamed("bags/Rederive"))
      local _ = bag
    end)
  end)

  -- The ribbon flows into a cloud round the title (asked: "flow into a bubble behind and around
  -- the word backpack, with the sparkles and glow ... don't drown the text", "seamless and not
  -- abrupt", "more like a cloud, no hard lines around it"; next.md §3).
  describe("the title's cloud", function()
    local C = style.Cloud
    -- The window's hard edge, from the title's left: where the body (and its wash) starts.
    local edge = -(style.PAD + 4)
    local function width(bag) return bag.title:GetStringWidth() end
    local function span(bag) return width(bag) - edge + C.Pad end

    it("gathers soft puffs round the title, below it and additive, nothing but soft glow", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal("OVERLAY", (bag.title:GetDrawLayer()))
      assert.are.equal(#C.Puffs, #bag.cloud.puffs)
      for i, puff in ipairs(bag.cloud.puffs) do
        local spec, t, base = C.Puffs[i], puff.texture, puff.base
        assert.are.equal(style.CLOUD_GLOW, t:GetTexture(), "the soft glow, no outline")
        assert.are.equal("ADD", t:GetBlendMode())
        assert.are.equal("ARTWORK", (t:GetDrawLayer()))
        assert.are.equal(edge + spec.F * span(bag), base.x)
        assert.are.equal(spec.Y, base.y)
        assert.are.equal(spec.W or span(bag) * spec.Wide, base.w)
        assert.are.equal(spec.H, base.h)
        assert.are.equal(spec.A, base.a)
        local point, to, relative, x, y = t:GetPoint(1)
        assert.are.same({ "CENTER", bag.title, "LEFT", base.x }, { point, to, relative, x })
        assert.is_true(math.abs(y - base.y) <= C.Drift + 1e-9)
        assert.are.same({ base.w, base.h }, { t:GetWidth(), t:GetHeight() })
        local color, r, g, b = style.Color[spec.Color], t:GetVertexColor()
        assert.are.same({ color[1], color[2], color[3] }, { r, g, b })
        assert.is_true(math.abs(t:GetAlpha() - base.a) <= base.a * C.Depth + 1e-9)
        assert.is_true(base.a <= 0.25, "faint: the title stays clear")
      end
      local join = bag.cloud.join
      assert.are.equal(style.CLOUD_GLOW, join:GetTexture())
      assert.are.same({ "CENTER", bag.title, "LEFT", edge, 0 }, { join:GetPoint(1) })
      assert.are.equal(C.Join.A, join:GetAlpha())
      -- Back to front: the puffs, the ribbon, the join's puff.
      local function sub(t) return select(2, t:GetDrawLayer()) end
      assert.is_true(sub(bag.cloud.puffs[1].texture) < sub(bag.ribbon))
      assert.is_true(sub(bag.ribbon) < sub(join))
    end)

    -- Asked: the bar's glow went "a tad bit too far into the window, should stop flush with the
    -- hard edge of the window".
    it("ends the ribbon and its glow flush with the window's hard edge, where the cloud begins", function()
      local bag = nextBag:Create(ctx())
      local lines = 0
      for _, t in ipairs(bag.frame._textures) do
        if t._width == 300 and t._height == 2 then
          lines = lines + 1
          local point, to, relative, x = t:GetPoint(1)
          assert.are.same({ "RIGHT", bag.title, "LEFT", edge }, { point, to, relative, x }, "every line of its glow")
        end
      end
      assert.are.equal(7, lines)
      assert.is_nil(bag.cloud.tail, "nothing of it goes on into the window")
      assert.are.equal(edge, bag.cloud.puffs[1].base.x - C.Puffs[1].F * span(bag), "the cloud begins there")
    end)

    it("spreads the cloud across a new title", function()
      local bag = nextBag:Create(ctx())
      bag:SetTitle("A much longer title")
      for i, puff in ipairs(bag.cloud.puffs) do
        assert.are.equal(edge + C.Puffs[i].F * span(bag), puff.base.x)
        assert.are.equal(puff.base.x, select(4, puff.texture:GetPoint(1)))
      end
    end)

    it("breathes slowly, each puff out of step with the others", function()
      local bag = opened()
      tween:Stop(bag.spark)
      bag:SetCloudSwell(0)
      local driver = bag.cloud.driver
      local seen, rose = {}, {}
      for step = 1, 200 do
        driver:GetScript("OnUpdate")(driver, 0.05)
        for i, puff in ipairs(bag.cloud.puffs) do
          local y, a = select(5, puff.texture:GetPoint(1)), puff.texture:GetAlpha()
          if math.abs(y - puff.base.y) > C.Drift / 2 then rose[i] = true end
          assert.is_true(math.abs(y - puff.base.y) <= C.Drift + 1e-9)
          assert.is_true(math.abs(a - puff.base.a) <= puff.base.a * C.Depth + 1e-9)
          seen[i] = seen[i] or {}
          seen[i][step] = a / puff.base.a
        end
      end
      local moved, differ = false, false
      for i = 1, #bag.cloud.puffs do
        if math.abs(seen[i][1] - seen[i][100]) > 0.01 then moved = true end
        if math.abs(seen[i][50] - seen[1][50]) > 0.01 then differ = true end
      end
      assert.is_true(moved, "it breathes")
      assert.is_true(differ, "out of step")
      for i = 1, #bag.cloud.puffs do assert.is_true(rose[i], "puff " .. i .. " drifts up and down") end
    end)

    -- The shimmer glides in along the ribbon, easing to rest just inside the cloud, before the
    -- title; there it grows and fades while the cloud swells and settles: nothing jumps, nothing
    -- crosses the title.
    it("glides the shimmer into the cloud, where it settles while the cloud swells", function()
      local bag = opened()
      tween:Stop(bag.spark)
      bag:playShimmer()
      local driver = tween.driver
      local samples = {}
      local function cloudAlpha()
        local sum = 0
        for _, puff in ipairs(bag.cloud.puffs) do sum = sum + puff.texture:GetAlpha() / puff.base.a end
        return sum / #bag.cloud.puffs
      end
      local total = style.Time.ShimmerEvery
      for _ = 1, math.ceil(total / 0.02) do
        driver:GetScript("OnUpdate")(driver, 0.02)
        local _, to, _, x = bag.spark:GetPoint(1)
        table.insert(samples, { to = to, x = x, a = bag.spark:GetAlpha(), size = bag.spark:GetWidth(),
          join = bag.cloud.join:GetAlpha(), cloud = cloudAlpha(), swell = bag.cloud.swell })
      end
      local lit = {}
      for _, s in ipairs(samples) do
        if s.a > 0 then table.insert(lit, s) end
      end
      assert.is_true(#lit > 20)
      assert.is_true(lit[1].x < -0.9 * 300, "from the far end of the ribbon")
      local stop = lit[#lit].x
      assert.are.equal(0, stop, "at rest where the ribbon ends, at the window's edge")
      local peakJoin, peakSwell = 0, 0
      for i = 2, #samples do
        local s, p = samples[i], samples[i - 1]
        -- What shows: between shimmers the spark waits unseen.
        if s.a > 0 and p.a > 0 then
          assert.is_true(s.x >= p.x - 1e-9, "only ever inward")
          assert.is_true(s.x - p.x <= 300 * 0.05, "no jump")
          assert.is_true(math.abs(s.size - p.size) < 2, "grows smoothly")
        end
        assert.is_true(math.abs(s.join - p.join) < 0.1, "the join's puff never steps")
        assert.is_true(math.abs(s.swell - p.swell) < 0.1, "the cloud never steps")
        peakJoin, peakSwell = math.max(peakJoin, s.join), math.max(peakSwell, s.swell)
      end
      -- Easing to rest: the last steps in are short.
      local arrived
      for i, s in ipairs(samples) do
        if s.x == stop and not arrived then arrived = i end
      end
      assert.is_true(samples[arrived].x - samples[arrived - 1].x < 2, "eases to rest")
      assert.is_true(peakJoin > C.Join.A + 0.3, "the join's puff swells as it arrives")
      assert.is_true(peakSwell > 0.9, "the cloud swells")
      local brightest = 0
      for _, s in ipairs(samples) do brightest = math.max(brightest, s.cloud) end
      assert.is_true(brightest > (1 + C.Swell * 0.9) * (1 - C.Depth), "its puffs brighten with it")
      -- Settling: quick at first, then gently. Halfway through, most of the growth, the fade and
      -- the cloud's easing back are done.
      local settle = {}
      for i = arrived, math.min(#samples, arrived + math.floor(style.Time.Absorb / 0.02 + 0.5)) do
        table.insert(settle, samples[i])
      end
      local half, biggest = settle[math.floor(#settle / 2)], 0
      for _, x in ipairs(settle) do biggest = math.max(biggest, x.size) end
      local grownFirst = (half.size - settle[1].size) / (biggest - settle[1].size)
      assert.is_true(grownFirst > 0.6, "grows quickly, then gently: " .. grownFirst)
      assert.is_true(half.a < 0.45, "fades quickly, then gently: " .. half.a)
      assert.is_true(half.swell < 0.4, "the cloud eases back quickly, then gently: " .. half.swell)
      local final = samples[#samples]
      assert.is_true(final.a < 1e-6 and final.swell < 1e-6, "and settles")
      assert.are.equal(C.Join.A, final.join)
    end)

    it("sparkles out of the cloud above and below the title, never over it, most near the ribbon", function()
      local bag = opened()
      local e = bag.cloudSparkles
      assert.is_not_nil(e.frame:GetScript("OnUpdate"))
      assert.are.equal(-1, e.options.Direction)
      local nearHalf, above, below = 0, 0, 0
      math.randomseed(7)
      for _ = 1, 300 do
        local x, y = e.options.Spawn()
        local tx, ty = x - (style.FEATHER + style.PAD + 4), y + (style.TITLE_TOP + 13)
        assert.is_true(tx >= edge and tx <= width(bag) + C.Pad, "within the cloud")
        assert.is_true(math.abs(ty) >= 14 and math.abs(ty) <= 28, "above or below the title: " .. ty)
        if ty > 0 then above = above + 1 else below = below + 1 end
        if tx < width(bag) / 2 then nearHalf = nearHalf + 1 end
      end
      assert.is_true(nearHalf > 170, "most near the ribbon: " .. nearHalf)
      assert.is_true(above > 90 and below > 90, "above and below")
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_nil(e.frame:GetScript("OnUpdate"))
      assert.are.equal(C.Join.A, bag.cloud.join:GetAlpha())
      assert.are.equal(0, bag.cloud.swell)
    end)
  end)

  describe("opening and closing", function()
    it("keeps a draw for when it opens, and draws it as it opens", function()
      local bag = nextBag:Create(ctx())
      local called = 0
      bag:Draw(ctx(), slotInfo, function() called = called + 1 end)
      assert.are.equal(1, called, "calls back at once")
      assert.is_nil(buttons["0_1"], "draws nothing while hidden")
      assert.is_true(bag:Show(ctx()))
      assert.is_not_nil(buttons["0_1"])
      assert.is_false(bag:Show(ctx()), "already open")
    end)

    it("leaves an open panel alone when asked to open again", function()
      local bag = opened()
      bag:Show(ctx())
      assert.are.equal(1, bag.content.order[1].frame:GetAlpha(), "no new cascade")
      assert.is_false(tween:IsPlaying(bag), "no new slide")
    end)

    it("closes once when asked to close while it is closing", function()
      local bag = opened()
      local sounds = 0
      override(_G, "PlaySound", function() sounds = sounds + 1 end)
      bag:Hide(ctx())
      tween:Step(0.1)
      bag:Hide(ctx())
      assert.are.equal(1, sounds)
      finishTweens()
      assert.is_false(bag:IsShown())
    end)

    it("slides in from the right, past its place a little and back", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      assert.is_true(bag:IsShown())
      assert.are.equal(style.WIDTH + style.OVERREACH, offset(bag))
      local past = false
      for _ = 1, 40 do
        tween:Step(0.0125)
        if offset(bag) < 0 then past = true end
      end
      assert.is_true(past, "overshoots")
      assert.are.equal(0, offset(bag))
    end)

    -- The bank is loaded once its panel has slid into place (refresh-scheduler.md §11); every
    -- panel shows the same way.
    describe("telling the caller it has finished showing", function()
      local function counter()
        local c = { n = 0 }
        c.fn = function() c.n = c.n + 1 end
        return c
      end

      it("calls back once it has slid into place, not before", function()
        local bag = nextBag:Create(ctx())
        local c = counter()
        bag:Show(ctx(), nil, c.fn)
        tween:Step(style.Time.Open * 0.9)
        assert.equal(0, c.n, "still sliding")
        tween:Step(style.Time.Open * 0.2)
        assert.equal(1, c.n)
        assert.equal(0, offset(bag), "in its place")
        finishTweens()
        assert.equal(1, c.n, "once")
      end)

      it("calls back at once when it is already open", function()
        local bag = opened()
        local c = counter()
        assert.is_false(bag:Show(ctx(), nil, c.fn))
        assert.equal(1, c.n)
      end)

      it("calls back when a slide still playing ends", function()
        local bag = nextBag:Create(ctx())
        local first = counter()
        bag:Show(ctx(), nil, first.fn)
        tween:Step(style.Time.Open / 3)
        local second = counter()
        bag:Show(ctx(), nil, second.fn)
        assert.equal(0, second.n)
        tween:Step(style.Time.Open)
        assert.equal(1, first.n)
        assert.equal(1, second.n)
      end)

      it("never calls back for a slide that closing or Escape cut short", function()
        local bag = nextBag:Create(ctx())
        local closed = counter()
        bag:Show(ctx(), nil, closed.fn)
        tween:Step(style.Time.Open / 3)
        bag:Hide(ctx())
        finishTweens()
        local escaped = counter()
        bag:Show(ctx(), nil, escaped.fn)
        tween:Step(style.Time.Open / 3)
        bag.frame:Hide()
        bag.frame:GetScript("OnHide")(bag.frame)
        finishTweens()
        local again = counter()
        bag:Show(ctx(), nil, again.fn)
        finishTweens()
        assert.equal(0, closed.n)
        assert.equal(0, escaped.n)
        assert.equal(1, again.n)
      end)

      it("calls back once it has slid back in, when opened again while closing", function()
        local bag = opened()
        bag:Hide(ctx())
        tween:Step(style.Time.Close / 2)
        local c = counter()
        bag:Show(ctx(), nil, c.fn)
        assert.equal(0, c.n)
        tween:Step(style.Time.Open + 0.05)
        assert.equal(1, c.n)
      end)
    end)

    -- Asked: the bounce showed what is under the bag at the screen edge (next.md §3). The fill
    -- reaches far enough past the panel that the screen edge stays covered through the bounce.
    it("keeps its fill over the screen edge through the whole bounce", function()
      local bag = nextBag:Create(ctx())
      local point, to, relative, reach = bag.fill:GetPoint(2)
      assert.are.same({ "BOTTOMRIGHT", bag.frame, "BOTTOMRIGHT" }, { point, to, relative })
      bag:Show(ctx())
      local deepest = 0
      for _ = 1, 250 do
        tween:Step(0.002)
        deepest = math.max(deepest, -offset(bag))
        assert.is_true(offset(bag) + reach >= 0, "the fill reaches the screen edge: " .. offset(bag) .. " + " .. reach)
      end
      assert.is_true(deepest > 0.09 * (style.WIDTH + style.OVERREACH), "it still bounces: " .. deepest)
      assert.are.equal(0, offset(bag))
    end)

    it("fades its sections in one after the other as it opens", function()
      local bag = nextBag:Create(ctx())
      bag:Draw(ctx(), slotInfo, function() end)
      bag:Show(ctx())
      assert.are.equal(0, bag.content.order[1].frame:GetAlpha())
      finishTweens()
      assert.are.equal(1, bag.content.order[1].frame:GetAlpha())
    end)

    it("starts its sparkles while open, and stops them when it hides", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      assert.is_not_nil(bag.sparkles.frame:GetScript("OnUpdate"))
      assert.is_not_nil(bag.edgeSparkles.frame:GetScript("OnUpdate"))
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_nil(bag.sparkles.frame:GetScript("OnUpdate"))
      assert.is_nil(bag.edgeSparkles.frame:GetScript("OnUpdate"))
    end)

    it("slides out to the right, then hides", function()
      local bag = opened()
      bag:Hide(ctx())
      assert.is_true(bag:IsShown(), "still sliding")
      finishTweens()
      assert.is_false(bag:IsShown())
      assert.are.equal(style.WIDTH + style.OVERREACH, offset(bag))
    end)

    it("toggles open and closed", function()
      local bag = nextBag:Create(ctx())
      bag:Toggle(ctx())
      finishTweens()
      assert.is_true(bag:IsShown())
      bag:Toggle(ctx())
      finishTweens()
      assert.is_false(bag:IsShown())
    end)

    -- Escape hides the frame directly (UISpecialFrames); every way it hides runs this.
    it("expires Recent Items when it hides, and recalculates when any expired or gaps are held", function()
      local bag = opened()
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.same({}, sentNamed("bags/Rederive"))
      expired = true
      bag.frame:Show()
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false } } }, sentNamed("bags/Rederive"))
      expired = false
      bag.drawOnClose = true
      bag.frame:Show()
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.equal(2, #sentNamed("bags/Rederive"))
      assert.is_false(bag.drawOnClose)
    end)

    it("does nothing on a hide while it is still shown (a parent hid)", function()
      local bag = opened()
      expired = true
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.same({}, sentNamed("bags/Rederive"))
    end)
  end)

  -- Switching between the classic design and BetterBags Next without a reload (next.md §11).
  describe("switching designs (Deactivate, Activate)", function()
    it("says it is closing while it slides out", function()
      local bag = opened()
      assert.is_false(bag:IsClosing())
      bag:Hide(ctx())
      assert.is_true(bag:IsClosing())
      finishTweens()
      assert.is_false(bag:IsClosing())
    end)

    it("hides at once and lets go of every button it drew", function()
      local bag = opened()
      bag:Deactivate(ctx())
      assert.is_false(bag.frame:IsShown())
      assert.is_false(bag.closing, "not through the slide")
      for slotkey, b in pairs(buttons) do
        assert.are.equal(1, b.released, slotkey)
      end
      assert.are.same({}, bag.drawnButtons)
    end)

    it("catches up on its search box, its tabs and its money", function()
      local bag = nextBag:Create(ctx())
      local updates = 0
      bag.moneyFrame.Update = function() updates = updates + 1 end
      inBagSearch = false
      allGroups[3] = { id = 3, name = "Ore" }
      bag:Activate(ctx())
      assert.is_false(bag.searchBox.frame:IsShown())
      assert.is_not_nil(bag.tabs:Tab(3), "Ore listed")
      assert.are.equal(1, updates)
    end)
  end)

  describe("drawing", function()
    it("releases the buttons it drew last time and did not draw again", function()
      local bag = opened()
      local sword = buttons["0_1"]
      slotInfo = data({ item("0_2", "Weapons") })
      bag:Draw(ctx(), slotInfo, function() end)
      assert.are.equal(1, sword.released)
      assert.are.equal(0, buttons["0_2"].released)
    end)

    it("says so when the tab it shows holds nothing", function()
      local bag = opened()
      assert.is_false(bag.emptyText:IsShown())
      slotInfo = data({})
      bag:Draw(ctx(), slotInfo, function() end)
      assert.is_true(bag.emptyText:IsShown())
      assert.are.equal("Nothing here yet", bag.emptyText:GetText())
    end)

    it("shows its free slots in the footer", function()
      slotInfo = data(nil, nil, { showAll = false, buttons = { { slotkey = "1_5", count = 12 } } })
      local bag = opened()
      assert.are.equal("12 free slots", bag.freeText:GetText())
    end)

    it("searches the buttons it shows, leaving free slots alone", function()
      slotInfo = data(nil, nil, { showAll = false, buttons = { { slotkey = "1_5", count = 12 } } })
      local bag = opened()
      bag:Search(ctx(), { ["0_1"] = false })
      assert.are.same({ false }, buttons["0_1"].searched)
      assert.is_nil(buttons["1_5"].searches)
      bag:ResetSearch(ctx())
      assert.are.same({ false, true }, buttons["0_1"].searched)
    end)

    it("refreshes its buttons' cooldowns while shown, from the bucketed event and as it opens", function()
      local bag = nextBag:Create(ctx())
      local bucket = buckets["BAG_UPDATE_COOLDOWN"]
      assert.is_false(bucket[2](), "fires are dropped while hidden")
      bag:Draw(ctx(), slotInfo, function() end)
      bag:Show(ctx())
      assert.is_true(bucket[2]())
      local before = buttons["0_1"].cooldowns
      bucket[1](ctx())
      assert.are.equal(before + 1, buttons["0_1"].cooldowns)
    end)

    it("is a drop target for the backpack", function()
      local bag = opened()
      bag.frame:GetScript("OnReceiveDrag")(bag.frame)
      assert.are.same({ BACKPACK }, placed)
    end)
  end)

  describe("tabs", function()
    it("lists the groups as tabs, with one to make a group, and selects the active one", function()
      local bag = opened()
      local ids = {}
      for _, tab in ipairs(bag.tabs.tabs) do table.insert(ids, tab.id) end
      assert.are.same({ 1, 2, 0 }, ids)
      assert.are.equal(1, bag.tabs.selected)
      assert.is_true(bag.tabs.frame:IsShown())
    end)

    it("hides the tabs while groups are off", function()
      groupsEnabled = false
      local bag = opened()
      assert.is_false(bag.tabs.frame:IsShown())
      assert.are.equal(1, bag:GetCurrentTabID())
    end)

    it("switches group on a click: the tab's items, fading in", function()
      local bag = opened()
      local herbs = bag.tabs.tabs[2].button
      herbs:GetScript("OnClick")(herbs, "LeftButton")
      assert.are.equal(2, activeGroup)
      assert.are.equal(2, bag.tabs.selected)
      assert.are.equal("Herbs", bag.content.order[1].name)
      assert.are.equal(1, buttons["0_1"].released)
      assert.are.equal(0, bag.content.order[1].frame:GetAlpha())
    end)

    it("fades in a section it shows again when the tab changes", function()
      slotInfo = data(nil, { item("0_9", "Weapons") })
      slotInfo.tabs[2].categories = { { name = "Weapons" } }
      local bag = opened()
      local weapons = bag.content.order[1]
      bag:SwitchToGroup(ctx(), 2)
      assert.are.equal(weapons, bag.content.order[1], "the same section")
      assert.are.equal(0, weapons.frame:GetAlpha())
    end)

    it("switches group for Quick Find and the group dialogs through its behavior", function()
      local bag = opened()
      bag.behavior:SwitchToGroup(ctx(), 2)
      assert.are.equal(2, activeGroup)
    end)

    it("opens a group's menu on a right click, and the new group dialog from its last tab", function()
      local bag = opened()
      local herbs, backpack, plus = bag.tabs.tabs[2].button, bag.tabs.tabs[1].button, bag.tabs.tabs[3].button
      herbs:GetScript("OnClick")(herbs, "RightButton")
      backpack:GetScript("OnClick")(backpack, "RightButton")
      assert.are.same({ 2 }, helper.menus, "the Backpack group has no menu")
      plus:GetScript("OnClick")(plus, "LeftButton")
      assert.are.equal(1, helper.created)
      assert.are.equal(1, activeGroup)
    end)

    it("lists the groups again when they change, and goes back to Backpack when its group goes", function()
      local bag = opened()
      bag:SwitchToGroup(ctx(), 2)
      allGroups[2] = nil
      messages["groups/Deleted"](ctx(), 2, nil, BACKPACK)
      assert.are.equal(1, activeGroup)
      assert.are.equal(2, #bag.tabs.tabs)
      allGroups[3] = { id = 3, name = "Ore" }
      messages["groups/Created"](ctx(), { kind = BACKPACK })
      assert.are.equal(3, #bag.tabs.tabs)
    end)
  end)

  describe("buttons and search", function()
    -- Both atlases are in the atlas table of retail, WoW: Forever, Classic Era, Mists and
    -- Anniversary; GM-icon-settings, the first settings icon, is missing on Classic Era and Mists.
    it("draws its header icons with atlases every client has, settings at the screen edge", function()
      local bag = opened()
      assert.are.equal("uitools-icon-settings", bag.settingsButton.icon:GetAtlas())
      assert.are.equal("bags-button-autosort-up", bag.sortButton.icon:GetAtlas())
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -style.PAD, -(style.TITLE_TOP + 3) },
        { bag.settingsButton:GetPoint(1) })
      assert.are.same({ "RIGHT", bag.settingsButton, "LEFT", -8, 0 }, { bag.sortButton:GetPoint(1) })
    end)

    -- The way back from BetterBags Next without a reload (next.md §11): the backpack's own icon,
    -- Blizzard's backpack button's art on each client (bag-main on retail and WoW: Forever,
    -- MainMenuBarBagButtons.lua; Button-Backpack-Up on Classic, MainMenuBarBagButtons.xml).
    it("switches the bags to the classic design from a backpack button in its header", function()
      local switched = {}
      override(stubs.bagSystem, "Switch", function(_, c, design)
        assert.is_not_nil(c)
        table.insert(switched, design)
        return true
      end)
      override(addon, "isRetail", true)
      local bag = opened()
      assert.are.equal("bag-main", bag.classicButton.icon:GetAtlas())
      assert.are.same({ "RIGHT", bag.sortButton, "LEFT", -8, 0 }, { bag.classicButton:GetPoint(1) })
      bag.classicButton:GetScript("OnClick")(bag.classicButton, "LeftButton")
      assert.are.same({ "classic" }, switched)
      bag.classicButton:GetScript("OnEnter")(bag.classicButton)
      assert.are.equal("Switch to Classic Bags", GameTooltip:GetText())
      override(addon, "isRetail", false)
      local classicClient = nextBag:Create(ctx())
      assert.are.equal("Interface\\Buttons\\Button-Backpack-Up", classicClient.classicButton.icon:GetTexture())
    end)

    it("sorts the backpack and opens the settings from its header", function()
      local bag = opened()
      bag.sortButton:GetScript("OnClick")(bag.sortButton, "LeftButton")
      bag.settingsButton:GetScript("OnClick")(bag.settingsButton, "LeftButton")
      assert.are.equal(1, #sentNamed("bags/SortBackpack"))
      assert.are.equal(1, #sentNamed("config/Open"))
    end)

    it("opens and focuses its search box from the search keybinding", function()
      local bag = nextBag:Create(ctx())
      bag:ToggleSearch(ctx())
      assert.is_true(bag:IsShown())
      assert.is_true(box.textBox:HasFocus())
      bag:ToggleSearch(ctx())
      assert.is_false(box.textBox:HasFocus(), "a second press lets go of the box")
    end)
  end)
end)
