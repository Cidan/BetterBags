-- pixelaudit_spec.lua -- PixelAudit (debug/pixelaudit.lua): the pixel check BetterBags Next is held to
-- (next-pixel-perfect.md), run in game from the /bbdb debug window and by the specs (spec/helpers/layout.lua's
-- PixelCheck calls it). It reads only what the client gives an addon: where a region is (GetScaledRect),
-- its anchors, its regions and children, whether it shows.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local layout = dofile("spec/helpers/layout.lua")

-- The watcher sends messages and makes contexts; earlier spec files stub those modules without restoring them.
local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

local audit = addon:GetModule("PixelAudit")

describe("PixelAudit", function()
  local undo, unit, window

  before_each(function()
    -- The reporter's window at 65%: a unit is 1.153 pixels.
    undo = layout.UseScreen(3396, 1362, 0.65)
    unit = (768 / 1362) / 0.65
    window = CreateFrame("Frame", nil, UIParent)
    window:SetSize(100 * unit, 50 * unit)
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10 * unit, -20 * unit)
  end)

  after_each(function()
    undo()
  end)

  describe("the check", function()
    -- In game the client says where a region is; the check never works it out from anchors itself.
    it("judges a region where the client puts it (GetScaledRect), whatever its anchors say", function()
      local tex = window:CreateTexture()
      tex:SetPoint("TOPLEFT", window, "TOPLEFT", 0.3, 0)
      tex:SetSize(4 * unit, unit)
      local factor = 768 / 1362
      function tex:GetScaledRect() return 20 * factor, 30 * factor, 4 * factor, factor end
      assert.are.same({}, audit:Check(window), "on whole pixels where the client put it")
      function tex:GetScaledRect() return 20.5 * factor, 30 * factor, 4 * factor, factor end
      assert.are.same({ "window.tex: left 20.500, right 24.500" },
        audit:Check(window, { owners = { window = { tex = tex } } }))
    end)

    it("judges a font string by its anchor points, from where the client puts its text", function()
      local text = window:CreateFontString()
      text:SetFontObject(GameFontNormal)
      text:SetText("odd")
      text:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
      local factor = 768 / 1362
      -- Its right edge is the text's measure, between pixels: not judged.
      function text:GetScaledRect() return 7 * factor, 40 * factor, 19.37 * factor, 12 * factor end
      assert.are.same({}, audit:Check(window))
      function text:GetScaledRect() return 7.25 * factor, 40 * factor, 19.37 * factor, 12 * factor end
      assert.are.equal(1, #audit:Check(window))
    end)

    -- warcraft.wiki.gg ScriptRegion:GetRect (and GetScaledRect): "Not allowed on restricted frames".
    it("skips a region the client will not measure, still judging what is in it", function()
      window:SetClipsChildren(true)
      function window:GetScaledRect() error("restricted frame") end
      local tex = window:CreateTexture()
      tex:SetPoint("TOPLEFT", window, "TOPLEFT", 0.3, 0)
      tex:SetSize(4 * unit, unit)
      local problems = audit:Check(window)
      assert.are.equal(1, #problems, "the texture, not the frame")
    end)

    -- In game an owner table reaches saved settings: reading a key AceDB's defaults do not hold can write it
    -- (wildcard defaults). The check only iterates the tables it walks and compares what it finds by identity.
    it("names parts without reading a key of any table it walks", function()
      local trap = setmetatable({}, { __index = function(_, key) error("read " .. tostring(key)) end })
      local tex = window:CreateTexture()
      tex:SetPoint("TOPLEFT", window, "TOPLEFT", 0.3, 0)
      tex:SetSize(4 * unit, unit)
      window.settings = trap
      local problems = audit:Check(window, { owners = { window = { db = { profile = trap }, tex = tex } } })
      assert.are.equal(1, #problems)
      assert.is_truthy(problems[1]:find("^window.tex: "), problems[1])
    end)

    it("skips a region the client has not placed", function()
      window:SetClipsChildren(true)
      function window:GetScaledRect() end
      assert.are.same({}, audit:Check(window))
    end)

    -- What a message names a part by when no owner table reaches it: the field of its parent it is kept in
    -- (a template's parentKey, a button's state art), else where it is in the tree.
    it("names a part by the field its parent keeps it in, else by its place in the tree", function()
      local button = CreateFrame("Button", nil, window)
      button:SetPoint("TOPLEFT", window, "TOPLEFT", 0.4, 0)
      button:SetSize(10 * unit, 10 * unit)
      button.Glow = button:CreateTexture()
      button.Glow:SetAllPoints(button)
      local loose = button:CreateTexture()
      loose:SetAllPoints(button)
      local problems = audit:Check(window)
      table.sort(problems)
      assert.are.equal(2, #problems)
      assert.is_truthy(problems[1]:find("^Texture >1>Glow: "), problems[1])
      assert.is_truthy(problems[2]:find("^Texture >1>t2: "), problems[2])
    end)
  end)

  -- Asked: a toggle in /bbdb, off by default, that checks BetterBags Next's windows as they are used and pops
  -- up a log of what is off the grid.
  describe("watching", function()
    local savedDB, savedPrint, savedSend, printed, sent

    local function ctx() return context:New("spec") end

    -- run lets time pass for the watcher, a frame at a time.
    local function run(seconds)
      local t = 0
      while t < seconds do
        local update = audit.driver:GetScript("OnUpdate")
        if update == nil then return end
        update(audit.driver, 0.05)
        t = t + 0.05
      end
    end

    -- watched makes a shown window registered with the watcher, holding a texture between pixels.
    local function watched(title, opts)
      local root = CreateFrame("Frame", nil, UIParent)
      root:SetSize(100 * unit, 50 * unit)
      root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10 * unit, -20 * unit)
      local tex = root:CreateTexture()
      tex:SetPoint("TOPLEFT", root, "TOPLEFT", 0.3, 0)
      tex:SetSize(4 * unit, unit)
      opts = opts or {}
      opts.title = title
      opts.owners = opts.owners or { window = { tex = tex } }
      audit:Register(root, opts)
      return root, tex
    end

    local function found()
      local list = {}
      for _, m in ipairs(sent) do
        if m[1] == "pixelAudit/Found" then table.insert(list, m[2]) end
      end
      return list
    end

    before_each(function()
      savedDB, savedPrint, savedSend = _G.BetterBagsPerfDB, _G.print, events.SendMessage
      _G.BetterBagsPerfDB = {}
      printed, sent = {}, {}
      _G.print = function(...) table.insert(printed, table.concat({ ... }, " ")) end
      events.SendMessage = function(_, _, name, payload) table.insert(sent, { name, payload }) end
      audit:Init()
    end)

    after_each(function()
      audit:SetWatching(ctx(), false)
      _G.BetterBagsPerfDB, _G.print, events.SendMessage = savedDB, savedPrint, savedSend
    end)

    it("is off until turned on, and stays as it was left across a reload", function()
      assert.is_false(audit:IsWatching())
      audit:SetWatching(ctx(), true)
      assert.is_true(audit:IsWatching())
      assert.is_true(_G.BetterBagsPerfDB.pixelAudit.watching)
      assert.are.same({ "pixelAudit/StateChanged", true }, sent[1])
      audit:Init()
      assert.is_true(audit:IsWatching(), "on after a reload")
      audit:SetWatching(ctx(), false)
      audit:Init()
      assert.is_false(audit:IsWatching())
    end)

    it("does nothing while off, not even a frame's update", function()
      local root = watched("Backpack")
      audit:Changed(root)
      assert.is_nil(audit.driver:GetScript("OnUpdate"))
      assert.are.same({}, audit:GetReports())
      assert.are.same({}, printed)
    end)

    it("checks a window once it has stayed the same, reports what is off, and pops up the log", function()
      local root = watched("Backpack", { describe = function() return "small, Bag Scale 85%" end })
      audit:SetWatching(ctx(), true)
      audit:Changed(root)
      run(audit.QUIET / 2)
      assert.are.same({}, audit:GetReports(), "not while it may still be changing")
      run(5)
      local reports = audit:GetReports()
      assert.are.equal(1, #reports)
      local r = reports[1]
      assert.are.equal("Backpack", r.window)
      assert.are.equal(1, #r.lines)
      assert.are.same(audit:Check(root, { owners = { window = { tex = root:GetRegions() } } }), r.lines)
      assert.is_truthy(r.lines[1]:find("^window.tex: left "), r.lines[1])
      assert.are.equal(1, r.total)
      assert.are.equal("3396x1362", r.screen)
      assert.are.equal(0.65, r.uiScale)
      assert.are.equal("small, Bag Scale 85%", r.details)
      assert.are.equal(r, _G.BetterBagsPerfDB.pixelAudit.reports[1], "saved")
      assert.are.same({ r }, found())
      assert.are.equal(1, #printed)
      assert.is_truthy(printed[1]:find("1 part of Backpack", 1, true), printed[1])
      assert.is_nil(audit.driver:GetScript("OnUpdate"), "done")
    end)

    -- For the Pixels tab's status: the last window it checked, and how many parts were off.
    it("remembers what it checked last, clean or not", function()
      local root, tex = watched("Backpack")
      audit:SetWatching(ctx(), true)
      run(5)
      assert.are.equal("Backpack", audit.lastChecked.window)
      assert.are.equal(1, audit.lastChecked.count)
      assert.is_number(audit.lastChecked.at)
      tex:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
      audit:Changed(root)
      run(5)
      assert.are.equal(0, audit.lastChecked.count)
    end)

    it("leaves out what moves between its checks, and reports where it comes to rest", function()
      local root, tex = watched("Backpack")
      local factor = 768 / 1362
      local x = 20
      function tex:GetScaledRect()
        x = math.min(x + 1.5, 26)
        return (x + 0.25) * factor, 30 * factor, 4 * factor, factor
      end
      audit:SetWatching(ctx(), true)
      audit:Changed(root)
      run(10)
      local reports = audit:GetReports()
      assert.are.equal(1, #reports)
      assert.are.same({ "window.tex: left 26.250, right 30.250" }, reports[1].lines, "where it rests")
    end)

    it("never reports what never stops moving", function()
      local root, tex = watched("Backpack")
      local factor = 768 / 1362
      local x = 20
      function tex:GetScaledRect()
        x = x + 1.5
        return (x + 0.25) * factor, 30 * factor, 4 * factor, factor
      end
      audit:SetWatching(ctx(), true)
      audit:Changed(root)
      run(10)
      assert.are.same({}, audit:GetReports())
      assert.is_nil(audit.driver:GetScript("OnUpdate"), "gives up")
    end)

    it("skips the parts a window says move by nature", function()
      local root, tex
      root, tex = watched("Backpack", { skip = function() return { [tex] = true } end })
      audit:SetWatching(ctx(), true)
      audit:Changed(root)
      run(5)
      assert.are.same({}, audit:GetReports())
    end)

    it("reports the same misses once, and again once they were fixed and come back", function()
      local root, tex = watched("Backpack")
      audit:SetWatching(ctx(), true)
      audit:Changed(root)
      run(5)
      audit:Changed(root)
      run(5)
      assert.are.equal(1, #audit:GetReports(), "nothing new")
      tex:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
      audit:Changed(root)
      run(5)
      assert.are.equal(1, #audit:GetReports(), "nothing off")
      tex:SetPoint("TOPLEFT", root, "TOPLEFT", 0.3, 0)
      audit:Changed(root)
      run(5)
      assert.are.equal(2, #audit:GetReports(), "off again")
      assert.are.equal(2, #found())
      assert.are.equal(2, #printed)
    end)

    -- Nothing of a closed window shows, so a check would find nothing off: it is not checked, nor said clean.
    it("does not check a window that is not shown, nor say it was checked", function()
      local root = watched("Backpack")
      root:Hide()
      audit:SetWatching(ctx(), true)
      audit:Changed(root)
      run(5)
      assert.are.same({}, audit:GetReports())
      for _, m in ipairs(sent) do
        assert.are_not.equal("pixelAudit/Checked", m[1])
      end
    end)

    it("checks a window again when it is shown", function()
      local root = watched("Backpack")
      audit:SetWatching(ctx(), true)
      run(5)
      assert.are.equal(1, #audit:GetReports(), "every shown window when turned on")
      audit:ClearReports(ctx())
      root:Hide()
      root:Show()
      root:GetScript("OnShow")(root)
      run(5)
      assert.are.equal(1, #audit:GetReports())
    end)

    it("checks every shown window it knows when asked", function()
      watched("Backpack")
      local bank = watched("Bank")
      bank:Hide()
      audit:SetWatching(ctx(), true)
      run(5)
      audit:ClearReports(ctx())
      bank:Show()
      audit:CheckNow(ctx())
      run(5)
      local windows = {}
      for _, r in ipairs(audit:GetReports()) do table.insert(windows, r.window) end
      table.sort(windows)
      assert.are.same({ "Backpack", "Bank" }, windows)
    end)

    it("keeps the last reports and the first lines of each", function()
      local root = CreateFrame("Frame", nil, UIParent)
      root:SetSize(400 * unit, 400 * unit)
      root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
      for i = 1, audit.MAX_LINES + 5 do
        local t = root:CreateTexture()
        t:SetPoint("TOPLEFT", root, "TOPLEFT", i + 0.3, 0)
        t:SetSize(unit, unit)
      end
      audit:Register(root, { title = "Bank" })
      audit:SetWatching(ctx(), true)
      run(5)
      local r = audit:GetReports()[1]
      assert.are.equal(audit.MAX_LINES, #r.lines)
      assert.are.equal(audit.MAX_LINES + 5, r.total)
      for i = 1, audit.MAX_REPORTS + 3 do
        local w = watched("Window " .. i)
        audit:Changed(w)
        run(5)
        w:Hide()
      end
      assert.are.equal(audit.MAX_REPORTS, #audit:GetReports())
      assert.are.equal("Window " .. (audit.MAX_REPORTS + 3), audit:GetReports()[audit.MAX_REPORTS].window, "newest last")
    end)
  end)
end)
