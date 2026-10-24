-- pixelpane_spec.lua -- The Pixels tab of the /bbdb debug window (frames/pixelpane.lua): turns the pixel check run
-- in game (debug/pixelaudit.lua, next-pixel-perfect.md) on and off, checks the windows shown now, clears the
-- reports, and lists them, the newest first, each part off the grid under its window.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")
events:Init()

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local list = stubModule("List")
-- The tab draws its text with Sonata's text roles, styled from the saved theme.
local db = stubModule("Database")
local originalGetTheme = db.GetTheme
db.GetTheme = function() return "Default" end
local sonata = UseSonataTextRoles()

ResetModuleStub("PixelPane", "frames/pixelpane.lua")
LoadBetterBagsModule("frames/pixelpane.lua")
local pixelPane = addon:GetModule("PixelPane")
local audit = addon:GetModule("PixelAudit")

describe("PixelPane", function()
  local saved, savedDB, savedPrint

  local function ctx() return context:New("spec") end

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function fakeList()
    local l = { frame = CreateFrame("Frame"), items = {} }
    function l:SetupDataSource(template, init) self.template, self.init = template, init end
    function l:InsertTable(t) for _, v in ipairs(t) do table.insert(self.items, v) end end
    function l:Wipe() self.items = {} end
    return l
  end

  local function newPane()
    local pane = pixelPane:Create(CreateFrame("Frame", nil, UIParent))
    pane:Update()
    return pane
  end

  local function click(button)
    button:GetScript("OnClick")(button, "LeftButton")
  end

  -- rows draws every entry of the pane's list in a row, as the list does, and returns their texts.
  local function rows(pane)
    local texts = {}
    for _, entry in ipairs(pane.list.items) do
      local row = CreateFrame("Button")
      pane.list.init(row, entry)
      table.insert(texts, row.text:GetText())
    end
    return texts
  end

  local function report(id, window, lines, opts)
    opts = opts or {}
    return { id = id, at = 1000 + id, window = window, screen = "3396x1362", uiScale = 0.65, scale = 0.65,
      theme = opts.theme, details = opts.details, total = opts.total or #lines, lines = lines }
  end

  before_each(function()
    UseSonataTextRoles()
    saved = {}
    savedDB, savedPrint = _G.BetterBagsPerfDB, _G.print
    _G.BetterBagsPerfDB = {}
    _G.print = function() end
    audit:Init()
    override(list, "Create", function() return fakeList() end)
    override(_G, "date", function(_, t) return "t" .. tostring(t) end)
  end)

  after_each(function()
    audit:SetWatching(ctx(), false)
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
    _G.BetterBagsPerfDB, _G.print = savedDB, savedPrint
  end)

  teardown(function()
    db.GetTheme = originalGetTheme
    ResetModuleStub("PixelPane", "frames/pixelpane.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  it("turns the check on and off, saying which it is", function()
    local pane = newPane()
    assert.are.equal("Start Checking", pane.toggleButton:GetText())
    assert.is_truthy(pane.status:GetText():find("Not checking", 1, true))
    click(pane.toggleButton)
    assert.is_true(audit:IsWatching())
    assert.are.equal("Stop Checking", pane.toggleButton:GetText())
    assert.is_truthy(pane.status:GetText():find("Checking", 1, true))
    click(pane.toggleButton)
    assert.is_false(audit:IsWatching())
    assert.are.equal("Start Checking", pane.toggleButton:GetText())
  end)

  it("checks the windows shown now when asked, and clears the reports", function()
    local pane = newPane()
    local asked = 0
    override(audit, "CheckNow", function() asked = asked + 1 end)
    click(pane.checkButton)
    assert.are.equal(1, asked)
    table.insert(audit:GetReports(), report(1, "Backpack", { "panel.title: TOPLEFT x 10.500" }))
    click(pane.clearButton)
    assert.are.same({}, audit:GetReports())
  end)

  it("lists the reports newest first, each part under its window, with what state it was in", function()
    local reports = audit:GetReports()
    table.insert(reports, report(1, "Backpack", { "panel.title: TOPLEFT x 10.500" }))
    table.insert(reports, report(2, "Bank", { "panel.edges[1]: left 3.250", "panel.footer: top 7.500" },
      { details = "small, Bag Scale 85%, Icon Scale 100%", theme = "Default", total = 5 }))
    local pane = newPane()
    assert.are.same({
      "t1002  Bank: 5 parts off · 3396x1362 at 65% · small, Bag Scale 85%, Icon Scale 100% · theme Default",
      "    panel.edges[1]: left 3.250",
      "    panel.footer: top 7.500",
      "    and 3 more",
      "t1001  Backpack: 1 part off · 3396x1362 at 65%",
      "    panel.title: TOPLEFT x 10.500",
    }, rows(pane))
  end)

  it("says when nothing was found, and what it checked last", function()
    local pane = newPane()
    assert.are.same({ "Nothing off the grid found yet." }, rows(pane))
    audit.lastChecked = { window = "Backpack", count = 0, at = 1234 }
    pane:Update()
    assert.is_truthy(pane.status:GetText():find("Last checked: Backpack, nothing off, t1234", 1, true),
      pane.status:GetText())
    audit.lastChecked = { window = "Bank", count = 2, at = 1240 }
    pane:Update()
    assert.is_truthy(pane.status:GetText():find("Last checked: Bank, 2 parts off, t1240", 1, true))
  end)

  it("shows what the check does as it happens, while it is shown", function()
    local pane = newPane()
    pane.frame:Show()
    table.insert(audit:GetReports(), report(1, "Backpack", { "panel.title: TOPLEFT x 10.500" }))
    events:SendMessage(ctx(), "pixelAudit/Found", audit:GetReports()[1])
    assert.are.equal(2, #rows(pane))
    events:SendMessage(ctx(), "pixelAudit/StateChanged", true)
    events:SendMessage(ctx(), "pixelAudit/Checked", "Backpack", 1)
    events:SendMessage(ctx(), "pixelAudit/Cleared")
  end)

  it("draws its rows with text roles: a report's head as a title, its parts as body text", function()
    table.insert(audit:GetReports(), report(1, "Backpack", { "panel.title: TOPLEFT x 10.500" }))
    local pane = newPane()
    assert.are.equal("BetterBagsPlainTextListButton", pane.list.template)
    local row = CreateFrame("Button")
    pane.list.init(row, pane.list.items[1])
    assert.are.equal(sonata:GetTextFont("Title"), row.text:GetFontObject())
    pane.list.init(row, pane.list.items[2])
    assert.are.equal(sonata:GetTextFont("Body"), row.text:GetFontObject(), "the same row reused")
  end)
end)
