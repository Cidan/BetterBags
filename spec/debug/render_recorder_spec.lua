-- render_recorder_spec.lua -- The render recorder (debug/renderrecorder.lua): while it records,
-- every window render that changed what the window shows adds a snapshot (the window, its content
-- box, and for a bag its scroll area, canvas layout, sections and item buttons), and every step of
-- a resize or a move adds the window's geometry. Recordings are kept in BetterBagsPerfDB.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadFreshBetterBagsModule("Context", "core/context.lua")
LoadFreshBetterBagsModule("Events", "core/events.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = trackStub("Database")
local originalGetTheme, originalSetTheme = db.GetTheme, db.SetTheme
db.GetTheme = function() return "Default" end
db.SetTheme = function() end
trackStub("Fonts")
local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
libWindow.RestorePosition = libWindow.RestorePosition or function() end
libWindow.SavePosition = libWindow.SavePosition or function() end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("sonata/engine.lua")
LoadBetterBagsModule("sonata/apply.lua")
LoadBetterBagsModule("sonata/decoration.lua")
LoadBetterBagsModule("window/window.lua")
ResetModuleStub("RenderRecorder", "debug/renderrecorder.lua")
LoadBetterBagsModule("debug/renderrecorder.lua")

local render = addon:GetModule("Render")
local drawable = addon:GetModule("Drawable")
local sonata = addon:GetModule("Sonata")
local window = addon:GetModule("Window")
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")
local recorder = addon:GetModule("RenderRecorder")

describe("RenderRecorder", function()
  local originalDB, originalBags, originalSend, count, sent

  before_each(function()
    originalDB = _G.BetterBagsPerfDB
    _G.BetterBagsPerfDB = {}
    originalBags = addon.Bags
    addon.Bags = {}
    events:Init()
    sent = {}
    originalSend = events.SendMessage
    events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    render:Init()
    sonata.themes = {}
    sonata:Init()
    sonata:RegisterTheme({ Name = "Base", Hidden = true,
      Windows = { Bag = { Insets = { Left = 6, Right = 6, Top = 42, Bottom = 3 } } } })
    sonata:RegisterTheme({ Name = "Default" })
    recorder:Init()
    count = 0
  end)

  after_each(function()
    if recorder:IsRecording() then recorder:Stop() end
    _G.BetterBagsPerfDB = originalDB
    addon.Bags = originalBags
    events.SendMessage = originalSend
  end)

  teardown(function()
    db.GetTheme, db.SetTheme = originalGetTheme, originalSetTheme
    ResetModuleStub("RenderRecorder", "debug/renderrecorder.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function content()
    local c = drawable:Create({})
    c.frame = CreateFrame("Frame")
    function c:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
    function c:Render() return { Width = 300, Height = 200 } end
    return c
  end

  local function newWindow(size)
    count = count + 1
    local w = window:Create({ Name = "BetterBagsRecorderSpec" .. count, Kind = "Bag", Content = content(),
      SizeMode = function() return "window" end, Size = function() return size[1], size[2] end })
    sonata:ApplyTheme(context:New("spec"), "Default")
    w:UpdateSizeMode()
    return w
  end

  -- fakeBag hangs a bag's parts on a window: a scroll area, a canvas laying out 2 columns of 4
  -- items, a Recent Items section and a view section, each with item buttons.
  local function fakeBag(w)
    -- The frame mock reports positions from _rect; each part is placed from its parent's.
    w.frame._rect = { left = 100, bottom = 200 }
    local function frameIn(parent, x, y, width, height)
      local f = CreateFrame("Frame", nil, parent)
      f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
      f:SetSize(width, height)
      local top = parent:GetTop() + y
      f._rect = { left = parent:GetLeft() + x, bottom = top - height }
      return f
    end
    local function section(title, ipr, slotkeys)
      local frame = frameIn(w.frame, 10, -60, 180, 90)
      local cells = {}
      for i, slotkey in ipairs(slotkeys) do
        table.insert(cells, { slotkey = slotkey, frame = frameIn(frame, 6 + (i - 1) * 41, -20, 37, 37) })
      end
      table.insert(cells, { isGap = true })
      return {
        frame = frame,
        title = { GetText = function() return title end },
        maxItemsPerRow = ipr,
        content = { cells = cells },
      }
    end
    local scrollFrame = frameIn(w.frame, 6, -42, 400, 300)
    local bar = CreateFrame("Frame", nil, scrollFrame)
    bar:Hide()
    local canvasFrame = frameIn(scrollFrame, 0, 0, 386, 500)
    local bag = {
      window = w,
      scroll = { frame = scrollFrame, scrollChild = frameIn(scrollFrame, 0, 0, 386, 500), scrollBar = bar },
      canvas = {
        frame = canvasFrame,
        headerContainer = frameIn(canvasFrame, 0, 0, 386, 50),
        tabContainer = frameIn(canvasFrame, 0, -50, 386, 400),
        footerContainer = frameIn(canvasFrame, 0, -450, 386, 50),
        GetLayout = function(_, width) return { itemsPerRow = width and 4 or 5, columns = 2 } end,
      },
      globalSections = { ["Recent Items"] = section("Recent Items", 8, { "0_1" }) },
      currentView = { sections = { Armor = section("Armor", 4, { "0_2", "0_3" }) } },
    }
    addon.Bags.Backpack = bag
    return bag
  end

  it("keeps its recordings in BetterBagsPerfDB", function()
    assert.are.same({}, BetterBagsPerfDB.renderRecordings)
    assert.is_false(recorder:IsRecording())
  end)

  it("records a window when it renders and again only when what it shows changed", function()
    local w = newWindow({ 640, 480 })
    assert.is_true(recorder:Start())
    assert.is_false(recorder:Start())
    render:NewRenderChain(w, {})
    render:NewRenderChain(w, {})
    assert.are.equal(1, recorder:GetEntryCount())
    w.frame:SetSize(700, 480)
    render:NewRenderChain(w, {})
    local recording = recorder:Stop()
    assert.are.equal(2, #recording.entries)
    local entry = recording.entries[1]
    assert.are.equal("render", entry.kind)
    assert.are.equal(w.frame:GetName(), entry.window)
    assert.is_truthy(entry.lines[1]:find("mode=window sizing=false | ", 1, true))
    assert.is_truthy(entry.lines[1]:find("640.0x480.0", 1, true))
    assert.is_truthy(entry.lines[2]:find("content insets 6.0,6.0,42.0,3.0", 1, true))
    assert.is_truthy(recording.entries[2].lines[1]:find("700.0x480.0", 1, true))
    assert.is_not_nil(tonumber(entry.t))
    assert.are.equal("TestChar", recording.character)
    assert.is_not_nil(recording.stoppedAt)
    assert.are.same({ recording }, BetterBagsPerfDB.renderRecordings)
  end)

  it("describes a bag down to its item buttons: scroll, canvas layout, sections, items", function()
    local w = newWindow({ 640, 480 })
    fakeBag(w)
    local lines = recorder:Snapshot(w)
    local text = table.concat(lines, "\n")
    assert.is_truthy(text:find("scroll @6.0,42.0 400.0x300.0 child 500.0 bar=false", 1, true), text)
    assert.is_truthy(text:find("canvas @6.0,42.0 386.0x500.0 layout ipr=4 columns=2 header=50.0 tab=400.0 footer=50.0", 1, true), text)
    assert.is_truthy(text:find("global section Recent Items ipr=8 cells=2 shown=true @10.0,60.0 180.0x90.0", 1, true), text)
    assert.is_truthy(text:find("view section Armor ipr=4 cells=3", 1, true), text)
    assert.is_truthy(text:find("  item 0_2 @16.0,80.0 37.0x37.0", 1, true), text)
    assert.is_truthy(text:find("  item 0_3 @57.0,80.0 37.0x37.0", 1, true), text)
    assert.is_truthy(text:find("  gap", 1, true), text)
  end)

  -- What each item button shows, beyond where it is: how it was last drawn (an item, a free slot
  -- with its count and bag name), its quality border, Blizzard's padlock (UpdateExtended's
  -- "extended" slot), whether it takes the mouse, and the empty slot glyph.
  it("describes what each item button shows", function()
    local w = newWindow({ 640, 480 })
    local bag = fakeBag(w)
    local function button(slotkey, x, drawnAs)
      local frame = CreateFrame("Frame", nil, w.frame)
      frame:SetSize(37, 37)
      frame._rect = { left = w.frame:GetLeft() + x, bottom = w.frame:GetTop() - 100 - 37 }
      local decoration = CreateFrame("Button", nil, frame)
      decoration.IconBorder = decoration:CreateTexture()
      decoration.IconBorder:Hide()
      local interaction = CreateFrame("Button", nil, frame)
      return { slotkey = slotkey, frame = frame, drawnAs = drawnAs, _decoration = decoration, button = interaction }
    end
    local free = button("-1_7", 10, "free")
    free.freeSlotCount, free.freeSlotName = 1, "Keyring"
    free.button.extendedFrame = CreateFrame("Frame", nil, free.button)
    free.button:EnableMouse(false)
    local reagent = button("5_1", 51, "free")
    reagent.freeSlotCount, reagent.freeSlotName = 1, "Reagent Bag"
    reagent._decoration.IconBorder:SetVertexColor(0.12, 1, 0, 1)
    reagent._decoration.IconBorder:Show()
    reagent._decoration.BetterBagsFamilyIcon = reagent._decoration:CreateTexture()
    reagent._decoration.BetterBagsFamilyIcon:SetAtlas("Mobile-Herbalism")
    local item = button("0_1", 92, "item")
    bag.globalSections = { ["Free Space"] = {
      frame = w.frame, title = { GetText = function() return "Free Space" end }, maxItemsPerRow = 7,
      content = { cells = { free, reagent, item } },
    } }
    bag.currentView = nil
    local text = table.concat(recorder:Snapshot(w), "\n")
    assert.is_truthy(text:find("  item -1_7 @10.0,100.0 37.0x37.0 free count=1 name=Keyring border=off padlock=true mouse=false glyph=none", 1, true), text)
    assert.is_truthy(text:find("  item 5_1 @51.0,100.0 37.0x37.0 free count=1 name=Reagent Bag border=0.12,1.00,0.00 padlock=false mouse=true glyph=Mobile-Herbalism", 1, true), text)
    assert.is_truthy(text:find("  item 0_1 @92.0,100.0 37.0x37.0 item border=off padlock=false mouse=true glyph=none", 1, true), text)
  end)

  it("records each step of a resize and a move with the window's geometry", function()
    local w = newWindow({ 640, 480 })
    w:Show(context:New("spec"))
    recorder:Start()
    w.resizeGrip:GetScript("OnMouseDown")(w.resizeGrip, "LeftButton")
    w.resizeGrip:GetScript("OnMouseUp")(w.resizeGrip, "LeftButton")
    local recording = recorder:Stop()
    local steps = {}
    for _, entry in ipairs(recording.entries) do
      if entry.kind == "step" then
        table.insert(steps, entry.step)
        assert.is_truthy(entry.geometry:find("rect ", 1, true))
      end
    end
    assert.are.same({ "resize start", "resize started", "resize stop", "resize stopped", "on screen", "position saved" }, steps)
  end)

  it("records nothing while stopped", function()
    local w = newWindow({ 640, 480 })
    render:NewRenderChain(w, {})
    recorder:WindowStep(w, "resize start")
    recorder:Start()
    local recording = recorder:Stop()
    assert.are.same({}, recording.entries)
  end)

  it("keeps the newest recordings, and stops adding entries once a recording is full", function()
    local w = newWindow({ 640, 480 })
    for _ = 1, recorder.MAX_RECORDINGS + 2 do
      recorder:Start()
      recorder:Stop()
    end
    local list = BetterBagsPerfDB.renderRecordings
    assert.are.equal(recorder.MAX_RECORDINGS, #list)
    assert.are.equal(3, list[1].id)
    local max = recorder.MAX_ENTRIES
    recorder.MAX_ENTRIES = 2
    recorder:Start()
    for _ = 1, 3 do recorder:WindowStep(w, "resizing") end
    local recording = recorder:Stop()
    recorder.MAX_ENTRIES = max
    assert.are.equal(2, #recording.entries)
    assert.is_true(recording.full)
  end)

  it("says when it starts and stops, and saves a recording still running at logout", function()
    recorder:Start()
    assert.are.same({ "renderRecorder/StateChanged", true }, sent[#sent])
    events._eventMap.PLAYER_LOGOUT.fn("PLAYER_LOGOUT")
    assert.is_false(recorder:IsRecording())
    assert.are.same({ "renderRecorder/StateChanged", false }, sent[#sent])
    assert.are.equal(1, #BetterBagsPerfDB.renderRecordings)
  end)
end)
