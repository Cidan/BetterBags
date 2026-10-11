-- perfpane_spec.lua -- The Performance tab of the /bbdb debug window (frames/perfpane.lua).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Earlier spec files stub or patch the shared Context and Events modules without restoring
-- them; these tests need real message delivery, so they load fresh copies.
local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

-- Stub modules registered here are torn down again so later spec files can load the real
-- ones (AceAddon refuses to NewModule a name that already exists).
local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end

local const = stubModule("Constants")
const.FORM_LAYOUT = const.FORM_LAYOUT or { STACKED = 1 }
local list = stubModule("List")
local form = stubModule("Form")
local question = stubModule("Question")

LoadBetterBagsModule("debug/perf/format.lua")
LoadFreshBetterBagsModule("PerfSessions", "debug/perf/sessions.lua")
LoadBetterBagsModule("frames/flamegraph.lua")
LoadFreshBetterBagsModule("PerfPane", "frames/perfpane.lua")

local perf = addon:GetModule("Perf")
local perfFormat = addon:GetModule("PerfFormat")
local perfSessions = addon:GetModule("PerfSessions")
local perfPane = addon:GetModule("PerfPane")

local function fakeList()
  local l = { frame = CreateFrame("Frame"), items = {} }
  function l:SetupDataSource(template, init)
    self.template = template
    self.init = init
  end
  function l:InsertTable(t)
    for _, v in ipairs(t) do table.insert(self.items, v) end
  end
  function l:Wipe() self.items = {} end
  function l:GetAllItems() return self.items end
  function l:Show() self.frame:Show() end
  function l:Hide() self.frame:Hide() end
  return l
end

local function fakeForm()
  local f = { frame = CreateFrame("Frame", "BetterBagsPerfSettingsSpecForm"), entries = {} }
  for _, kind in ipairs({ "AddSection", "AddDropdown", "AddInputBox", "AddSlider", "AddCheckbox" }) do
    f[kind] = function(self, opts) table.insert(self.entries, { kind = kind, opts = opts }) end
  end
  function f:GetFrame() return self.frame end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:ReloadAllFormElements() self.reloaded = (self.reloaded or 0) + 1 end
  return f
end

local function makeSession(id, overrides)
  local s = {
    id = id,
    formatVersion = 1,
    meta = {
      reason = "manual", startedAt = 1700000000 + id, character = "TestChar", realm = "TestRealm",
      gameVersion = "12.0.1", gameBuild = "12345", flavor = "retail", preset = "full",
      blizzardStart = { PeakTime = 10, CountTimeOver5Ms = 1 },
      blizzardStop = { PeakTime = 60, CountTimeOver5Ms = 4 },
    },
    stats = {
      durationMs = 45200, instrumentedMs = 9.5, calls = 7, frames = 3, activeFrames = 2,
      worstFrameMs = 7.5, aborted = 0, nodeCount = 5, droppedNodes = 0, wrappedFunctions = 100,
      overheadPerCallMs = 0.001, allocatedKB = 0, gcFreedKB = 0,
    },
    names = { "[all]", "[event] BAG_UPDATE", "Items.RunRefresh", "Items.Harvest", "Bag.Draw" },
    nodes = {
      "0,1,0,0,0,0",
      "1,2,1000,3,500,0",
      "2,3,2000,1,9000,0",
      "3,4,6000,1,6000,0",
      "1,5,500,2,300,0",
    },
    functions = { "2,3,9000,3000", "3,1,8000,8000", "4,1,6000,6000", "5,2,500,300" },
    histogram = { bounds = { 1, 5, 16, 33, 50, 100 }, counts = { 1, 1, 1, 0, 0, 0, 0 } },
    worst = {
      { frame = 7, atUs = 1500000, us = 7500, blizzardUs = 9000, nodes = { "3,1500,1,0", "4,4000,1,0" } },
    },
    timeline = { ours = "0,1500,7500", blizzard = "0,2000,9000" },
  }
  for k, v in pairs(overrides or {}) do s[k] = v end
  return s
end

describe("PerfPane", function()
  local pane
  local saved
  local lists
  local createdForm
  local yesNo
  local now

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, tbl[key] })
    tbl[key] = value
  end

  local function itemsOf(l)
    return l:GetAllItems()
  end

  before_each(function()
    saved = {}
    lists = {}
    now = 0
    yesNo = nil
    createdForm = nil
    _G.BetterBagsPerfDB = nil
    events:Init()
    perf:Init()
    perf:SetClock(function() return now end)
    perfSessions._logoutHooked = nil
    perfSessions:Init()
    override(perfSessions, "BuildOptions", function()
      return { modules = {}, prototypes = {}, includeRoot = false, calibrate = false }
    end)
    override(list, "Create", function()
      local l = fakeList()
      table.insert(lists, l)
      return l
    end)
    override(form, "Create", function(_, opts)
      createdForm = fakeForm()
      createdForm.opts = opts
      return createdForm
    end)
    override(question, "YesNo", function(_, title, text, yes, no)
      yesNo = { title = title, text = text, yes = yes, no = no }
    end)
    _G.UISpecialFrames = {}
    pane = perfPane:Create(UIParent)
    pane.flame.canvas:SetSize(500, 300)
    pane.frameFlame.canvas:SetSize(500, 200)
  end)

  after_each(function()
    if perf:IsActive() then perf:Stop() end
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  describe("capturing", function()
    it("starts and stops a capture from its button and selects the saved session", function()
      assert.are.equal("Start Capture", pane.startButton:GetText())
      pane.startButton:GetScript("OnClick")(pane.startButton)
      assert.is_true(perfSessions:IsCapturing())
      assert.are.equal("Stop Capture", pane.startButton:GetText())
      now = 2500
      pane.startButton:GetScript("OnClick")(pane.startButton)
      assert.is_false(perfSessions:IsCapturing())
      assert.are.equal("Start Capture", pane.startButton:GetText())
      assert.are.equal(1, #itemsOf(pane.sessionList))
      assert.are.equal(1, pane.selectedId)
    end)

    it("follows a capture started somewhere else", function()
      perfSessions:StartCapture("reload")
      assert.are.equal("Stop Capture", pane.startButton:GetText())
      perfSessions:StopCapture()
      assert.are.equal("Start Capture", pane.startButton:GetText())
    end)

    it("arms a capture for the next reload from its checkbox", function()
      pane.armCheck:SetChecked(true)
      pane.armCheck:GetScript("OnClick")(pane.armCheck)
      assert.is_true(perfSessions:IsArmedForNextReload())
      pane.armCheck:SetChecked(false)
      pane.armCheck:GetScript("OnClick")(pane.armCheck)
      assert.is_false(perfSessions:IsArmedForNextReload())
    end)

    it("shows live numbers while capturing and the session count when idle", function()
      perfSessions:StartCapture("manual")
      now = 1500
      pane:UpdateStatus()
      assert.is_truthy(pane.status:GetText():find("Capturing", 1, true))
      assert.is_truthy(pane.status:GetText():find("1.50 s", 1, true))
      perfSessions:StopCapture()
      pane:UpdateStatus()
      assert.is_truthy(pane.status:GetText():find("1 saved session", 1, true))
    end)
  end)

  describe("saved sessions", function()
    before_each(function()
      table.insert(perfSessions.db.sessions, makeSession(1))
      table.insert(perfSessions.db.sessions, makeSession(2))
      pane:Update()
    end)

    it("lists saved sessions newest first", function()
      local items = itemsOf(pane.sessionList)
      assert.are.equal(2, #items)
      assert.are.equal(2, items[1].id)
      assert.are.equal(1, items[2].id)
      assert.is_truthy(items[1].text:find("#2", 1, true))
    end)

    it("selects a session from its row and draws its flame graph", function()
      local items = itemsOf(pane.sessionList)
      local button = CreateFrame("Button")
      button.Text = button:CreateFontString()
      button.Selected = button:CreateTexture()
      pane.sessionList.init(button, items[2])
      button:GetScript("OnClick")(button)
      assert.are.equal(1, pane.selectedId)
      assert.are.equal(9.5, pane.flame.tree.root.total)
      assert.is_true(itemsOf(pane.sessionList)[2].selected)
    end)

    it("deletes the selected session", function()
      pane:SelectSession(1)
      pane.deleteButton:GetScript("OnClick")(pane.deleteButton)
      assert.is_nil(perfSessions:GetSession(1))
      assert.are.equal(1, #itemsOf(pane.sessionList))
      assert.is_nil(pane.selectedId)
      assert.is_nil(pane.flame.tree)
    end)

    it("asks before deleting every session", function()
      pane.deleteAllButton:GetScript("OnClick")(pane.deleteAllButton)
      assert.is_not_nil(yesNo)
      assert.are.equal(2, #perfSessions:GetSessions())
      yesNo.yes()
      assert.are.equal(0, #perfSessions:GetSessions())
      assert.are.equal(0, #itemsOf(pane.sessionList))
    end)
  end)

  describe("views", function()
    before_each(function()
      table.insert(perfSessions.db.sessions, makeSession(1))
      pane:Update()
      pane:SelectSession(1)
    end)

    it("switches between views from its buttons", function()
      pane.viewButtons.functions:GetScript("OnClick")(pane.viewButtons.functions)
      assert.is_true(pane.views.functions:IsShown())
      assert.is_false(pane.views.flame:IsShown())
      pane.viewButtons.flame:GetScript("OnClick")(pane.viewButtons.flame)
      assert.is_true(pane.views.flame:IsShown())
    end)

    it("filters the flame graph from the search box", function()
      pane.searchBox:SetText("harvest")
      pane.searchBox:GetScript("OnTextChanged")(pane.searchBox)
      assert.are.equal("harvest", pane.flame.search)
    end)

    it("only offers the allocation view when the session tracked allocations", function()
      assert.is_false(pane.metricButton:IsEnabled())
      local withAlloc = makeSession(3)
      withAlloc.nodes[4] = "3,4,6000,1,6000,2048"
      table.insert(perfSessions.db.sessions, withAlloc)
      pane:Update()
      pane:SelectSession(3)
      assert.is_true(pane.metricButton:IsEnabled())
      pane.metricButton:GetScript("OnClick")(pane.metricButton)
      assert.are.equal("alloc", pane.flame.metric)
    end)

    it("lists functions by self time and re-sorts on a column click", function()
      local rows = itemsOf(pane.functionList)
      assert.are.equal("Items.Harvest", rows[1].name)
      pane.functionHeaders.calls:GetScript("OnClick")(pane.functionHeaders.calls)
      rows = itemsOf(pane.functionList)
      assert.are.equal("[event] BAG_UPDATE", rows[1].name)
      pane.functionHeaders.calls:GetScript("OnClick")(pane.functionHeaders.calls)
      rows = itemsOf(pane.functionList)
      assert.are.equal(1, rows[1].calls)
      assert.are.equal("[event] BAG_UPDATE", rows[#rows].name)
    end)

    it("fills function rows column by column", function()
      local button = CreateFrame("Button")
      for _, key in ipairs({ "Name", "Calls", "Total", "Self", "Avg", "Max", "Alloc" }) do
        button[key] = button:CreateFontString()
      end
      pane.functionList.init(button, itemsOf(pane.functionList)[1])
      assert.are.equal("Items.Harvest", button.Name:GetText())
      assert.are.equal("1", button.Calls:GetText())
      assert.are.equal("6.00 ms", button.Self:GetText())
    end)

    it("lists the worst frames and draws the chosen frame's call tree", function()
      local rows = itemsOf(pane.frameList)
      assert.are.equal(1, #rows)
      assert.is_truthy(rows[1].text:find("7.50 ms", 1, true))
      assert.is_truthy(rows[1].text:find("9.00 ms", 1, true))
      pane:SelectFrame(1)
      assert.are.equal(5.5, pane.frameFlame.tree.root.total)
    end)

    it("lists a frame once, with the Blizzard reading that arrived a frame late", function()
      -- Saved before readings were paired: worst[1] is an empty frame listed only because
      -- Blizzard reported worst[2]'s work one frame later.
      local s = makeSession(9, {
        options = { spikeThresholdMs = 16 },
        worst = {
          { frame = 3, atUs = 60000, us = 30, blizzardUs = 40960, nodes = {} },
          { frame = 2, atUs = 40000, us = 39430, blizzardUs = 11990, nodes = { "5,39430,1,0" } },
        },
        timeline = { ours = "0,12450,39430,30,0", blizzard = "20,680,11990,40960,60" },
      })
      table.insert(perfSessions.db.sessions, s)
      pane:Update()
      pane:SelectSession(9)

      local rows = itemsOf(pane.frameList)
      assert.are.equal(1, #rows)
      assert.is_truthy(rows[1].text:find("^#1 "))
      assert.is_truthy(rows[1].text:find("39.4 ms", 1, true))
      assert.is_truthy(rows[1].text:find("Blizzard 41.0 ms", 1, true))
      assert.are.equal(2, pane.selectedFrame)
      assert.is_true(rows[1].selected)
      assert.is_not_nil(perfFormat:Find(pane.frameFlame.tree, { "Bag.Draw" }))
    end)

    it("draws the per-frame timeline", function()
      pane.timeline:SetSize(500, 70)
      pane:ShowView("frames")
      local shown = 0
      for _, bar in ipairs(pane.timelineBars) do
        if bar:IsShown() then shown = shown + 1 end
      end
      assert.is_true(shown > 0)
    end)

    it("summarizes the session", function()
      local text = pane.summaryText:GetText()
      assert.is_truthy(text:find("TestChar", 1, true))
      assert.is_truthy(text:find("45.20 s", 1, true))
      assert.is_truthy(text:find("9.50 ms", 1, true))
      -- Wrappers saw 9 of the 11 ms Blizzard's profiler charged to the addon.
      assert.is_truthy(text:find("81.8%", 1, true))
      assert.is_truthy(text:find("Peak time", 1, true))
    end)

    it("names the calls cut short by errors in the summary", function()
      local session = makeSession(5, { aborted = { "5,3" } })
      session.stats.aborted = 3
      table.insert(perfSessions.db.sessions, session)
      pane:Update()
      pane:SelectSession(5)
      local text = pane.summaryText:GetText()
      assert.is_truthy(text:find("Calls cut short by errors: 3", 1, true))
      assert.is_truthy(text:find("Bag.Draw (3)", 1, true))
    end)
  end)

  describe("profiler overhead", function()
    -- Each measured call costs 0.5 ms on its caller and 0.5 ms on itself.
    local function calibratedSession(id)
      local s = makeSession(id)
      s.stats.overheadPerCallMs = 1
      s.stats.overheadParentMs = 0.5
      s.stats.overheadChildMs = 0.5
      s.timeline.calls = "0,2,2"
      s.timeline.nested = "0,1,1"
      return s
    end

    local function functionRow(name)
      for _, row in ipairs(itemsOf(pane.functionList)) do
        if row.name == name then return row end
      end
    end

    local function renderRow(row)
      local button = CreateFrame("Button")
      for _, key in ipairs({ "Name", "Calls", "Total", "Self", "Avg", "Max", "Alloc" }) do
        button[key] = button:CreateFontString()
      end
      pane.functionList.init(button, row)
      return button
    end

    before_each(function()
      table.insert(perfSessions.db.sessions, calibratedSession(1))
      pane:Update()
      pane:SelectSession(1)
    end)

    it("subtracts profiler overhead by default and can switch back to raw times", function()
      assert.is_true(pane.adjustCheck:IsEnabled())
      assert.is_true(pane.adjustCheck:GetChecked())
      assert.are.equal("adjusted", pane.flame.metric)
      assert.are.equal("adjusted", pane.frameFlame.metric)
      assert.are.equal("5.50 ms", renderRow(functionRow("Items.Harvest")).Self:GetText())

      pane.adjustCheck:SetChecked(false)
      pane.adjustCheck:GetScript("OnClick")(pane.adjustCheck)
      assert.are.equal("time", pane.flame.metric)
      assert.are.equal("6.00 ms", renderRow(functionRow("Items.Harvest")).Self:GetText())
    end)

    it("shows the worst frames without the profiler's cost", function()
      -- Raw 7.5 ms; its calls carried 1.5 ms of estimated overhead.
      assert.is_truthy(itemsOf(pane.frameList)[1].text:find("6.00 ms", 1, true))
    end)

    it("greys out functions whose time is mostly profiler overhead", function()
      -- Bag.Draw measured 0.5 ms over 2 calls, all of it within the estimated overhead.
      local row = functionRow("Bag.Draw")
      assert.is_true(row.overheadShare > 0.75)
      local button = renderRow(row)
      local r, g, b = button.Name:GetTextColor()
      assert.is_true(r < 1 and g < 1 and b < 1)
      local harvest = renderRow(functionRow("Items.Harvest"))
      local hr, hg, hb = harvest.Name:GetTextColor()
      assert.are.same({ 1, 1, 1 }, { hr, hg, hb })
    end)

    it("reports the calibration and the time without overhead in the summary", function()
      local text = pane.summaryText:GetText()
      assert.is_truthy(text:find("per call", 1, true))
      assert.is_truthy(text:find("without profiler overhead", 1, true))
    end)

    it("offers no adjustment for a session captured without calibration", function()
      local s = makeSession(2)
      s.stats.overheadPerCallMs = 0
      table.insert(perfSessions.db.sessions, s)
      pane:Update()
      pane:SelectSession(2)
      assert.is_false(pane.adjustCheck:IsEnabled())
      assert.are.equal("time", pane.flame.metric)
    end)
  end)

  describe("settings", function()
    local function entry(title)
      for _, e in ipairs(createdForm.entries) do
        if e.opts.title == title then return e end
      end
    end

    it("opens one settings window and writes changes to the profiler settings", function()
      pane.settingsButton:GetScript("OnClick")(pane.settingsButton)
      local first = createdForm
      assert.is_true(first.shown)
      pane.settingsButton:GetScript("OnClick")(pane.settingsButton)
      assert.are.equal(first, createdForm)
      local ctx = context:New("Test")

      entry("Spike threshold (ms)").opts.setValue(ctx, 33)
      assert.are.equal(33, perfSessions:GetSettings().spikeThresholdMs)
      assert.are.equal(33, entry("Spike threshold (ms)").opts.getValue(ctx))

      local measure = entry("What to measure")
      assert.is_true(measure.opts.getValue(ctx, "Everything"))
      measure.opts.setValue(ctx, "Data and draw pipeline")
      assert.are.equal("pipeline", perfSessions:GetSettings().preset)

      entry("Track memory allocations").opts.setValue(ctx, true)
      assert.is_true(perfSessions:GetSettings().trackAllocations)

      entry("Modules to skip").opts.setValue(ctx, "Database")
      assert.are.equal("Database", perfSessions:GetSettings().excludedModules)

      for _, title in ipairs({ "Worst frames kept", "Auto-stop after (seconds)", "Saved sessions kept",
        "Call-tree node limit", "Timeline length (frames)", "Pause garbage collection while capturing",
        "Measure profiler overhead" }) do
        assert.is_not_nil(entry(title), title)
      end
    end)
  end)
end)
