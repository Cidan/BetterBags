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
-- The pane draws its text with Sonata's text roles, styled from the saved theme.
local db = stubModule("Database")
local originalGetTheme = db.GetTheme
db.GetTheme = function() return "Default" end
local sonata = UseSonataTextRoles()

LoadBetterBagsModule("debug/perf/format.lua")
LoadFreshBetterBagsModule("PerfSessions", "debug/perf/sessions.lua")
local recorder = LoadFreshBetterBagsModule("RenderRecorder", "debug/renderrecorder.lua")
LoadBetterBagsModule("frames/flamegraph.lua")
LoadBetterBagsModule("frames/tracechart.lua")
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

describe("PerfPane slow ticks", function()
  it("lists the slowest ticks of a capture, the pane and who took them", function()
    local pane = setmetatable({}, { __index = addon:GetModule("PerfPane").proto })
    local lines = {}
    local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
    pane:AddSlowTicks(add, { timeline = { slow = {
      { frame = 3, ms = 40, detail = { pane = "no character pane", addons = {} } },
      { frame = 9, ms = 70, detail = { pane = "GW2_UI's character pane", addons = { { name = "Pawn", ms = 2 } } } },
    } } })
    assert.equal(1, #lines)
    assert.is_truthy(lines[1]:find("frame 9", 1, true))
    assert.is_truthy(lines[1]:find("GW2_UI's character pane", 1, true))
    assert.is_truthy(lines[1]:find("Pawn", 1, true))
    assert.is_truthy(lines[1]:find("frame 3", 1, true))
    assert.is_truthy(lines[1]:find("frame 9", 1, true) < lines[1]:find("frame 3", 1, true))
    assert.is_truthy(lines[1]:find("no addon", 1, true))
  end)

  it("says what it can of a tick it could not describe", function()
    local pane = setmetatable({}, { __index = addon:GetModule("PerfPane").proto })
    local lines = {}
    local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
    pane:AddSlowTicks(add, { timeline = { slow = { { frame = 3, ms = 40, detail = { error = "x" } } } } })
    assert.is_truthy(lines[1]:find("frame 3", 1, true))
    assert.is_truthy(lines[1]:find("not described", 1, true))
  end)

  it("says nothing of a capture without any", function()
    local pane = setmetatable({}, { __index = addon:GetModule("PerfPane").proto })
    local lines = {}
    pane:AddSlowTicks(function(fmt) lines[#lines + 1] = fmt end, { timeline = {} })
    assert.are.same({}, lines)
  end)
end)

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
    recorder:Init()
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

  before_each(function()
    UseSonataTextRoles()
  end)

  teardown(function()
    db.GetTheme = originalGetTheme
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

    -- The render recorder (debug/renderrecorder.lua) starts and stops from its own button.
    it("records rendering from its own button, and follows a recording started somewhere else", function()
      assert.are.equal("Record Rendering", pane.recordButton:GetText())
      pane.recordButton:GetScript("OnClick")(pane.recordButton)
      assert.is_true(recorder:IsRecording())
      assert.are.equal("Stop Recording", pane.recordButton:GetText())
      pane.recordButton:GetScript("OnClick")(pane.recordButton)
      assert.is_false(recorder:IsRecording())
      assert.are.equal("Record Rendering", pane.recordButton:GetText())
      assert.are.equal(1, #BetterBagsPerfDB.renderRecordings)
      recorder:Start()
      assert.are.equal("Stop Recording", pane.recordButton:GetText())
      recorder:Stop()
      assert.are.equal("Record Rendering", pane.recordButton:GetText())
    end)

    it("follows a capture started somewhere else", function()
      perfSessions:StartCapture("reload")
      assert.are.equal("Stop Capture", pane.startButton:GetText())
      perfSessions:StopCapture()
      assert.are.equal("Start Capture", pane.startButton:GetText())
    end)

    it("says when a diagnostics run will capture the next loads", function()
      perfSessions:ArmDiagnostics()
      pane:UpdateStatus()
      assert.is_truthy(pane.status:GetText():find("armed for the next 2 loads", 1, true), pane.status:GetText())
      perfSessions:SetArmedForNextReload(false)
      pane:UpdateStatus()
      assert.is_falsy(pane.status:GetText():find("armed", 1, true))
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
      button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
        button[key] = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
        button[key] = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
      assert.are.equal(sonata:GetTextFont("MutedSmall"), button.Name:GetFontObject())
      assert.are.equal(sonata:GetTextFont("MutedSmall"), button.Alloc:GetFontObject())
      local r, g, b = button.Name:GetTextColor()
      assert.is_true(r < 1 and g < 1 and b < 1)
      local harvest = renderRow(functionRow("Items.Harvest"))
      assert.are.equal(sonata:GetTextFont("BodySmall"), harvest.Name:GetFontObject())
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

  describe("call trace", function()
    local T = addon:GetModule("PerfPaneTraceA", true) or addon:NewModule("PerfPaneTraceA")

    -- 250 calls of 1 ms each, T:TCall(n) returning n * 10, a frame every 50 calls. The
    -- trace starts with the perf/StateChanged message StartCapture sends, once per listener
    -- (AceEvent's registry outlives each test's pane), so T:TCall(n) is call n + offset.
    local function captureTrace()
      function T:TCall(n)
        now = now + 1
        return n * 10
      end
      override(perfSessions, "BuildOptions", function()
        return {
          modules = { "PerfPaneTraceA" }, prototypes = {}, includeRoot = false, calibrate = false,
          trace = true, traceArgs = true, traceChunkSize = 64,
        }
      end)
      perfSessions:StartCapture("manual")
      for i = 1, 250 do
        T:TCall(i)
        if i % 50 == 0 then perf:_OnFrame() end
      end
      return perfSessions:StopCapture()
    end

    local function renderCallRow(row)
      local button = CreateFrame("Button")
      for _, key in ipairs({ "Time", "Frame", "Duration", "Name", "Args" }) do
        button[key] = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      end
      button.Selected = button:CreateTexture()
      pane.callList.init(button, row)
      return button
    end

    local function click(button)
      button:GetScript("OnClick")(button)
    end

    local session, offset, total

    before_each(function()
      session = captureTrace()
      local trace = perfFormat:OpenTrace(session)
      offset = 0
      while trace:Get(offset + 1).name ~= "PerfPaneTraceA.TCall" do
        offset = offset + 1
      end
      total = trace:Count()
      assert.are.equal(250 + offset, total)
      pane.timelineChart.canvas:SetSize(500, 200)
      pane.traceStrip:SetSize(500, 40)
    end)

    it("selects the new session and lists its calls in start order, a page at a time", function()
      assert.are.equal(session.id, pane.selectedId)
      pane:ShowView("calls")
      local rows = itemsOf(pane.callList)
      assert.are.equal(100, #rows)
      assert.are.equal(1, rows[1].index)
      assert.are.equal(100, rows[100].index)
      assert.is_truthy(pane.callPageLabel:GetText():find("1-100 of " .. total, 1, true))
      click(pane.callNext)
      assert.are.equal(101, itemsOf(pane.callList)[1].index)
      click(pane.callLast)
      assert.are.equal(total - 200, #itemsOf(pane.callList))
      assert.is_truthy(pane.callPageLabel:GetText():find("201-" .. total .. " of " .. total, 1, true))
      click(pane.callFirst)
      click(pane.callPrevious)
      assert.are.equal(1, itemsOf(pane.callList)[1].index)
    end)

    it("fills a call row's columns", function()
      local button = renderCallRow(itemsOf(pane.callList)[offset + 3])
      assert.are.equal("2.00 ms", button.Time:GetText())
      assert.are.equal("1", button.Frame:GetText())
      assert.are.equal("1.00 ms", button.Duration:GetText())
      assert.are.equal("PerfPaneTraceA.TCall", button.Name:GetText())
      assert.are.equal("(<PerfPaneTraceA>, 3) -> 30", button.Args:GetText())
    end)

    it("filters calls by name, argument or return text, a budget of calls per frame", function()
      pane.filterBudget = 60
      pane.callFilter:SetText("7")
      pane.callFilter:GetScript("OnEnterPressed")(pane.callFilter)
      assert.is_truthy(pane.callPageLabel:GetText():find("Searching", 1, true))
      local steps = 0
      while not pane.filterState.done do
        pane:StepFilter()
        steps = steps + 1
      end
      assert.is_true(steps > 1, "the search was spread over several frames")
      local rows = itemsOf(pane.callList)
      assert.are.equal(43, #rows)
      assert.are.equal(offset + 7, rows[1].index)
      assert.is_truthy(pane.callPageLabel:GetText():find("1-43 of 43 matching", 1, true))
      pane.callFilter:SetText("")
      pane.callFilter:GetScript("OnEnterPressed")(pane.callFilter)
      assert.are.equal(100, #itemsOf(pane.callList))
    end)

    it("shows a call's details and jumps to it on the timeline", function()
      local row = itemsOf(pane.callList)[offset + 5]
      click(renderCallRow(row))
      assert.are.equal(offset + 5, pane.selectedCall)
      assert.is_truthy(pane.callDetail:GetText():find("<PerfPaneTraceA>, 5", 1, true))
      assert.is_truthy(pane.callDetail:GetText():find("50", 1, true))
      click(pane.showInTimeline)
      assert.are.equal("timeline", pane.currentView)
      assert.are.equal(offset + 5, pane.timelineChart.highlight)
      assert.is_true(pane.timelineChart.from <= 4 and pane.timelineChart.to >= 5)
    end)

    it("opens the timeline on the first frame and steps between frames", function()
      pane:ShowView("timeline")
      assert.are.equal(0, pane.timelineChart.from)
      assert.are.equal(50, pane.timelineChart.to)
      click(pane.nextFrameButton)
      assert.are.equal(50, pane.timelineChart.from)
      assert.are.equal(100, pane.timelineChart.to)
      click(pane.previousFrameButton)
      assert.are.equal(0, pane.timelineChart.from)
      click(pane.wholeCaptureButton)
      assert.are.equal(250, pane.timelineChart.to)
      pane:SelectTraceFrame(3)
      assert.are.equal(100, pane.timelineChart.from)
      assert.are.equal(150, pane.timelineChart.to)
    end)

    it("says when the selected session has no call trace", function()
      table.insert(perfSessions.db.sessions, makeSession(99))
      pane:Update()
      pane:SelectSession(99)
      pane:ShowView("calls")
      assert.are.equal(0, #itemsOf(pane.callList))
      assert.is_truthy(pane.callPageLabel:GetText():find("no call trace", 1, true))
      assert.is_nil(pane.timelineChart.trace)
    end)

    it("marks sessions that carry a trace and removes the selected session's trace", function()
      local row = itemsOf(pane.sessionList)[1]
      assert.is_truthy(row.text:find("trace", 1, true))
      click(pane.removeTraceButton)
      assert.is_nil(perfSessions:GetSession(session.id).trace)
      assert.are.equal(0, #itemsOf(pane.callList))
      assert.is_truthy(pane.callPageLabel:GetText():find("removed", 1, true))
      assert.is_falsy(itemsOf(pane.sessionList)[1].text:find("trace", 1, true))
    end)

    it("asks before removing every trace", function()
      click(pane.removeAllTracesButton)
      assert.is_not_nil(yesNo)
      assert.is_table(perfSessions:GetSession(session.id).trace)
      yesNo.yes()
      assert.is_nil(perfSessions:GetSession(session.id).trace)
    end)

    it("reports the trace in the summary and the status line", function()
      local text = pane.summaryText:GetText()
      assert.is_truthy(text:find("Call trace: " .. total .. " calls", 1, true), text)
      perfSessions:StartCapture("manual")
      T:TCall(1)
      pane:UpdateStatus()
      local traced = perf:GetLiveStats().traceCalls
      assert.is_true(traced >= 1)
      assert.is_truthy(pane.status:GetText():find(perfFormat:Count(traced) .. " call", 1, true), pane.status:GetText())
      assert.is_truthy(pane.status:GetText():find("traced", 1, true), pane.status:GetText())
    end)
  end)

  -- What a capture of the Dream Breath investigation needs to say: what was simulated, where
  -- the player was, which addon restrictions were active, and whose a slow frame was.
  describe("summary of where and under which restrictions", function()
    local function session()
      return {
        id = 7,
        meta = {
          reason = "simulate",
          simulation = { event = "BAG_UPDATE_COOLDOWN", rate = 22, duration = 30, payload = "", openBags = true },
          instanceStart = { name = "Ara-Kara", instanceType = "party", difficultyID = 23, difficultyName = "Mythic" },
          instanceStop = { name = "Ara-Kara", instanceType = "party", difficultyID = 23, difficultyName = "Mythic" },
          restrictionsStart = { Combat = "Active", Map = "Active", Encounter = "Inactive" },
          restrictionsStop = { Combat = "Inactive", Map = "Active", Encounter = "Inactive" },
          topAddonsStop = { { name = "BetterBags", ms = 56.7 }, { name = "Other", ms = 3 } },
        },
        stats = { durationMs = 1000, frames = 3, activeFrames = 3, instrumentedMs = 1 },
        timeline = {
          ours = "100,20000,300",
          blizzard = "50,30000,100",
          series = { app = "16000,180000,17000", all = "1000,31000,2000" },
        },
      }
    end

    it("says whose the client's slowest ticks were", function()
      local s = session()
      s.timeline.slow = { { frame = 2, ms = 180, detail = { pane = "no character pane", addons = {} } } }
      local text = pane:BuildSummary(s)
      assert.is_truthy(text:find("frame 2", 1, true))
      assert.is_truthy(text:find("no character pane; no addon", 1, true))
    end)

    it("says what was simulated, where, and under which restrictions", function()
      local text = pane:BuildSummary(session())
      assert.is_truthy(text:find("Simulated BAG_UPDATE_COOLDOWN at 22/s for 30 s, with the bags opened.", 1, true))
      assert.is_truthy(text:find("Where: Ara-Kara (Mythic, party) at the start and at the end.", 1, true))
      assert.is_truthy(text:find("Addon restrictions active at the start: Combat, Map; at the end: Map.", 1, true))
    end)

    it("says how slow the slowest frame was for the whole client and all addons, and BetterBags' share", function()
      local text = pane:BuildSummary(session())
      assert.is_truthy(text:find("Slowest frame for the whole client (Blizzard): 180 ms, frame 2. In it, all addons took 31.0 ms and BetterBags 20.0 ms (measured) / 30.0 ms (Blizzard).", 1, true))
      assert.is_truthy(text:find("Slowest single tick since the client started (Blizzard): BetterBags 56.7 ms, Other 3.00 ms.", 1, true))
    end)

    it("leaves these lines out of sessions without the data", function()
      local plain = session()
      plain.meta = { reason = "manual" }
      plain.timeline = { ours = "100" }
      local text = pane:BuildSummary(plain)
      assert.is_falsy(text:find("Simulated", 1, true))
      assert.is_falsy(text:find("Where:", 1, true))
      assert.is_falsy(text:find("Addon restrictions", 1, true))
      assert.is_falsy(text:find("whole client", 1, true))
    end)
  end)

  describe("settings", function()
    local function entry(title)
      for _, e in ipairs(createdForm.entries) do
        if e.opts.title == title then return e end
      end
    end

    it("offers the call trace settings", function()
      pane.settingsButton:GetScript("OnClick")(pane.settingsButton)
      local ctx = context:New("Test")
      entry("Record every call in order").opts.setValue(ctx, false)
      assert.is_false(perfSessions:GetSettings().traceCalls)
      entry("Record arguments and return values").opts.setValue(ctx, false)
      assert.is_false(perfSessions:GetSettings().traceArgs)
      entry("Trace call limit").opts.setValue(ctx, 50000)
      assert.are.equal(50000, perfSessions:GetSettings().traceMaxCalls)
      assert.are.equal(50000, entry("Trace call limit").opts.getValue(ctx))
    end)

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
