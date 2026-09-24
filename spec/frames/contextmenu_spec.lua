-- contextmenu_spec.lua -- The bag menu's "Show Bags" toggle (frames/contextmenu.lua).
--
-- `showBankTabs` is a retail-only concept: on retail the bank's `bag.slots` is the
-- bank-TAB filter panel (frames/bankslots.lua) and the persisted `showBankTabs`
-- setting filters the bank to one Blizzard tab. On Classic/Era the bank uses the
-- plain bag-slots panel (frames/bagslots.lua), exactly like the backpack, so its
-- "Show Bags" toggle must behave like the backpack's: the checkmark follows
-- `bag.slots:IsShown()` and toggling never touches `database:SetShowBankTabs`.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local aceAddon = LibStub("AceAddon-3.0")

local LIBDD_MAJOR = "LibUIDropDownMenu-4.0"
local CONTEXT_MENU_PATH = "frames/contextmenu.lua"

local overrides = {}
local function override(tbl, key, value)
  table.insert(overrides, { tbl = tbl, key = key, original = tbl[key] })
  tbl[key] = value
end
local function restoreOverrides()
  for i = #overrides, 1, -1 do
    local o = overrides[i]
    o.tbl[o.key] = o.original
  end
  overrides = {}
end

-- Stub modules registered by this spec are torn down again so later spec files can
-- load the real module (AceAddon refuses to NewModule a name that already exists).
local createdStubs = {}
local function stubModule(name)
  local mod, created = _G.StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end
local function resetCreatedStubs()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
  createdStubs = {}
end

---@param menuList table[]
---@param text string
---@return table|nil
local function findEntry(menuList, text)
  for _, entry in ipairs(menuList) do
    if entry.text == text then
      return entry
    end
  end
  return nil
end

describe("ContextMenu 'Show Bags' toggle", function()
  local contextMenu, const, database, events, L, context
  local previousModule, previousAceEntry, stubbedLibDD

  -- Recorders, rebuilt per test.
  local showBankTabsCalls, bagViewCalls, sentMessages
  local persistedShowBankTabs, bagViews, previousViews

  setup(function()
    const = stubModule("Constants")
    database = stubModule("Database")
    events = stubModule("Events")
    L = stubModule("Localization")
    context = stubModule("Context")

    if LibStub:GetLibrary(LIBDD_MAJOR, true) == nil then
      LibStub.libs[LIBDD_MAJOR] = {}
      LibStub.minors[LIBDD_MAJOR] = 1
      stubbedLibDD = true
    end

    -- Swap in the real ContextMenu module, remembering any stub another spec left.
    previousModule = addon.modules["ContextMenu"]
    previousAceEntry = aceAddon.addons["BetterBags_ContextMenu"]
    ResetModuleStub("ContextMenu", CONTEXT_MENU_PATH)
    LoadBetterBagsModule(CONTEXT_MENU_PATH)
    contextMenu = addon:GetModule("ContextMenu")
    contextMenu:Init()
  end)

  teardown(function()
    ResetModuleStub("ContextMenu", CONTEXT_MENU_PATH)
    for i = #addon.orderedModules, 1, -1 do
      if addon.orderedModules[i] == contextMenu then
        table.remove(addon.orderedModules, i)
      end
    end
    addon.modules["ContextMenu"] = previousModule
    aceAddon.addons["BetterBags_ContextMenu"] = previousAceEntry

    if stubbedLibDD then
      LibStub.libs[LIBDD_MAJOR] = nil
      LibStub.minors[LIBDD_MAJOR] = nil
    end
    resetCreatedStubs()
  end)

  before_each(function()
    override(addon, "isRetail", addon.isRetail)
    override(addon, "hasWarbank", addon.hasWarbank)
    override(_G, "InCombatLockdown", function() return false end)

    if const.BAG_KIND == nil or const.BAG_KIND.BACKPACK == nil or const.BAG_KIND.BANK == nil then
      override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = 0, BANK = 1 })
    end
    if const.BAG_VIEW == nil or const.BAG_VIEW.SECTION_GRID == nil or const.BAG_VIEW.SECTION_ALL_BAGS == nil then
      override(const, "BAG_VIEW", { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 })
    end

    showBankTabsCalls = {}
    bagViewCalls = {}
    sentMessages = {}
    persistedShowBankTabs = false
    bagViews = {}
    previousViews = {}

    override(L, "G", function(_, key) return key end)
    override(context, "New", function(_, event) return { event = event } end)
    override(events, "SendMessage", function(_, _, event)
      table.insert(sentMessages, event)
    end)

    override(database, "GetShowBankTabs", function() return persistedShowBankTabs end)
    override(database, "SetShowBankTabs", function(_, value)
      table.insert(showBankTabsCalls, value)
      persistedShowBankTabs = value
    end)
    override(database, "GetBagView", function(_, kind)
      return bagViews[kind] or const.BAG_VIEW.SECTION_GRID
    end)
    override(database, "SetBagView", function(_, kind, view)
      table.insert(bagViewCalls, { kind = kind, view = view })
      bagViews[kind] = view
    end)
    override(database, "GetPreviousView", function(_, kind)
      return previousViews[kind] or const.BAG_VIEW.SECTION_GRID
    end)
    override(database, "SetPreviousView", function(_, kind, view)
      previousViews[kind] = view
    end)
    override(database, "GetAnchorState", function() return {} end)
  end)

  after_each(function()
    restoreOverrides()
  end)

  ---Builds a mock bag whose slots panel is backed by a real mock frame.
  ---@param kind number
  ---@param shown boolean Whether the slots panel starts shown.
  local function newBag(kind, shown)
    local slots = { frame = CreateFrame("Frame") }
    slots.frame:SetShown(shown)
    slots.IsShown = function(self) return self.frame:IsShown() end
    slots.Show = function(self) self.frame:Show() end
    slots.Hide = function(self) self.frame:Hide() end
    slots.Draw = spy.new(function() end)

    local anchorFrame = CreateFrame("Frame")
    return {
      kind = kind,
      slots = slots,
      anchor = {
        frame = anchorFrame,
        IsActive = function() return false end,
        ToggleActive = function() end,
        ToggleShown = function() end,
        SetStaticAnchorPoint = function() end,
      },
    }
  end

  local function showBagsEntry(bag)
    return findEntry(contextMenu:CreateContextMenu(bag), "Show Bags")
  end

  describe("Classic/Era bank (plain bag-slots panel)", function()
    before_each(function()
      addon.isRetail = false
      addon.hasWarbank = false
    end)

    it("offers a Show Bags entry when the bank has a slots panel", function()
      local bag = newBag(const.BAG_KIND.BANK, false)
      assert.is_not_nil(showBagsEntry(bag))
    end)

    it("checkmark follows the slots panel, not the retail-only showBankTabs setting", function()
      local bag = newBag(const.BAG_KIND.BANK, false)
      local entry = showBagsEntry(bag)

      persistedShowBankTabs = true
      assert.is_false(entry.checked(), "hidden panel must be unchecked even when showBankTabs is true")

      bag.slots:Show()
      persistedShowBankTabs = false
      assert.is_true(entry.checked(), "shown panel must be checked even when showBankTabs is false")
    end)

    it("toggles the panel and bag view without touching showBankTabs", function()
      local bag = newBag(const.BAG_KIND.BANK, false)
      local entry = showBagsEntry(bag)

      entry.func()
      assert.is_true(bag.slots:IsShown())
      assert.spy(bag.slots.Draw).was.called(1)
      assert.are.equal(const.BAG_VIEW.SECTION_ALL_BAGS, bagViews[const.BAG_KIND.BANK])
      assert.are.same({ "bags/FullRefreshAll" }, sentMessages)
      assert.are.same({}, showBankTabsCalls, "toggling on must not call SetShowBankTabs on Classic")

      entry.func()
      assert.is_false(bag.slots:IsShown())
      assert.are.equal(const.BAG_VIEW.SECTION_GRID, bagViews[const.BAG_KIND.BANK])
      assert.are.same({ "bags/FullRefreshAll", "bags/FullRefreshAll" }, sentMessages)
      assert.are.same({}, showBankTabsCalls, "toggling off must not call SetShowBankTabs on Classic")
    end)
  end)

  describe("Retail bank (bank-tab filter panel)", function()
    before_each(function()
      addon.isRetail = true
      addon.hasWarbank = true
    end)

    it("checkmark reflects the persisted showBankTabs setting", function()
      local bag = newBag(const.BAG_KIND.BANK, true)
      local entry = showBagsEntry(bag)

      persistedShowBankTabs = false
      assert.is_false(entry.checked())

      bag.slots:Hide()
      persistedShowBankTabs = true
      assert.is_true(entry.checked())
    end)

    it("persists showBankTabs when toggled on and off", function()
      local bag = newBag(const.BAG_KIND.BANK, false)
      local entry = showBagsEntry(bag)

      entry.func()
      assert.is_true(bag.slots:IsShown())
      assert.are.same({ true }, showBankTabsCalls)
      assert.are.equal(const.BAG_VIEW.SECTION_ALL_BAGS, bagViews[const.BAG_KIND.BANK])

      entry.func()
      assert.is_false(bag.slots:IsShown())
      assert.are.same({ true, false }, showBankTabsCalls)
      assert.are.equal(const.BAG_VIEW.SECTION_GRID, bagViews[const.BAG_KIND.BANK])
    end)
  end)

  for _, flavor in ipairs({ { name = "Classic/Era", isRetail = false }, { name = "Retail", isRetail = true } }) do
    describe(flavor.name .. " backpack", function()
      before_each(function()
        addon.isRetail = flavor.isRetail
        addon.hasWarbank = flavor.isRetail
      end)

      it("checkmark follows the slots panel and toggling never touches showBankTabs", function()
        local bag = newBag(const.BAG_KIND.BACKPACK, false)
        local entry = showBagsEntry(bag)

        persistedShowBankTabs = true
        assert.is_false(entry.checked())

        entry.func()
        assert.is_true(bag.slots:IsShown())
        assert.is_true(entry.checked())
        assert.are.equal(const.BAG_VIEW.SECTION_ALL_BAGS, bagViews[const.BAG_KIND.BACKPACK])

        entry.func()
        assert.is_false(bag.slots:IsShown())
        assert.is_false(entry.checked())
        assert.are.equal(const.BAG_VIEW.SECTION_GRID, bagViews[const.BAG_KIND.BACKPACK])
        assert.are.same({ "bags/FullRefreshAll", "bags/FullRefreshAll" }, sentMessages)
        assert.are.same({}, showBankTabsCalls)
      end)
    end)
  end
end)
