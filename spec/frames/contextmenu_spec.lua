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
    override(events, "SendMessage", function(_, _, event, options)
      table.insert(sentMessages, event)
      -- Show Bags changes categories, stacking and layout: every bag is recalculated with a
      -- fresh layout (refresh-scheduler.md §10). Nothing a button draws depends on the view
      -- except through data its draw record holds, so unchanged buttons skip their redraw.
      if event == "bags/Rederive" then
        assert.are.same({ resetLayout = true }, options)
      end
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
      assert.are.same({ "bags/Rederive" }, sentMessages)
      assert.are.same({}, showBankTabsCalls, "toggling on must not call SetShowBankTabs on Classic")

      entry.func()
      assert.is_false(bag.slots:IsShown())
      assert.are.equal(const.BAG_VIEW.SECTION_GRID, bagViews[const.BAG_KIND.BANK])
      assert.are.same({ "bags/Rederive", "bags/Rederive" }, sentMessages)
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
        assert.are.same({ "bags/Rederive", "bags/Rederive" }, sentMessages)
        assert.are.same({}, showBankTabsCalls)
      end)
    end)
  end

  -- ToggleBagSlots is the entry's action, shared with the action buttons a theme can give a bag
  -- (frames/bagactions.lua).
  -- The toggles come first (Drag to Resize, Show Bags, and the backpack's Show Bag Button), then
  -- Bag Anchor, then the bank's sorts (kept together), then What's New, the options and Close Menu.
  describe("menu order and Drag to Resize", function()
    local sizeModes, sizeModeCalls

    before_each(function()
      addon.isRetail = true
      addon.hasWarbank = true
      override(_G.C_Container, "SortAccountBankBags", function() end)
      sizeModes, sizeModeCalls = {}, {}
      override(database, "GetBagSizeMode", function(_, kind) return sizeModes[kind] or "content" end)
      override(database, "SetBagSizeMode", function(_, kind, mode)
        table.insert(sizeModeCalls, { kind, mode })
        sizeModes[kind] = mode
      end)
    end)

    -- texts lists the menu's entries below its title.
    local function texts(menuList)
      local out = {}
      for i = 2, #menuList do
        out[#out + 1] = menuList[i].text
      end
      return out
    end

    it("puts Drag to Resize first and Show Bag Button above Bag Anchor in the backpack's menu", function()
      local menuList = contextMenu:CreateContextMenu(newBag(const.BAG_KIND.BACKPACK, false))
      assert.is_true(menuList[1].isTitle)
      assert.are.same({ "Drag to Resize", "Show Bags", "Show Bag Button", "Bag Anchor", "What's New",
        "Open Options Screen", "Close Menu" }, texts(menuList))
    end)

    it("puts Drag to Resize first and Bag Anchor third in the bank's menu, its sorts together after it", function()
      local menuList = contextMenu:CreateContextMenu(newBag(const.BAG_KIND.BANK, false))
      assert.are.same({ "Drag to Resize", "Show Bags", "Bag Anchor", "Sort Bank", "Clean Up Warbank", "What's New",
        "Open Options Screen", "Close Menu" }, texts(menuList))
    end)

    it("keeps the same order on a bank without a Warbank", function()
      addon.isRetail = false
      addon.hasWarbank = false
      local menuList = contextMenu:CreateContextMenu(newBag(const.BAG_KIND.BANK, false))
      assert.are.same({ "Drag to Resize", "Show Bags", "Bag Anchor", "Sort Bank", "What's New",
        "Open Options Screen", "Close Menu" }, texts(menuList))
    end)

    -- The Resizable Window option (config/config.lua), as a toggle: the bag's size mode for the view
    -- it shows, then a redraw, which applies it (bagProto:ApplySizeSettings).
    it("toggles each bag between sizing by its corner and sizing to its items, like Resizable Window", function()
      for _, kind in ipairs({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }) do
        sizeModeCalls, sentMessages = {}, {}
        local entry = findEntry(contextMenu:CreateContextMenu(newBag(kind, false)), "Drag to Resize")
        assert.is_falsy(entry.notCheckable)
        assert.is_false(entry.checked())
        entry.func()
        assert.are.same({ { kind, "window" } }, sizeModeCalls)
        assert.is_true(entry.checked())
        assert.are.same({ "bags/Redraw" }, sentMessages)
        entry.func()
        assert.are.same({ { kind, "window" }, { kind, "content" } }, sizeModeCalls)
        assert.is_false(entry.checked())
        assert.are.same("Drag to Resize", entry.tooltipTitle)
        assert.is_true(entry.tooltipOnButton)
      end
    end)
  end)

  describe("ToggleBagSlots", function()
    before_each(function()
      addon.isRetail = true
      addon.hasWarbank = true
    end)

    it("shows and hides a bag's slots exactly as the menu entry does", function()
      local bag = newBag(const.BAG_KIND.BANK, false)
      contextMenu:ToggleBagSlots(context:New("test"), bag)
      assert.is_true(bag.slots:IsShown())
      assert.are.same({ true }, showBankTabsCalls)
      assert.are.equal(const.BAG_VIEW.SECTION_ALL_BAGS, bagViews[const.BAG_KIND.BANK])
      contextMenu:ToggleBagSlots(context:New("test"), bag)
      assert.is_false(bag.slots:IsShown())
      assert.are.same({ true, false }, showBankTabsCalls)
      assert.are.same({ "bags/Rederive", "bags/Rederive" }, sentMessages)
    end)

    -- The changelog (frames/changelog.lua) opens from the menu, above the options entry.
    it("opens the changelog from a What's New entry, above the options entry", function()
      local bag = newBag(const.BAG_KIND.BACKPACK, false)
      local menuList = contextMenu:CreateContextMenu(bag)
      local entry = findEntry(menuList, "What's New")
      assert.is_not_nil(entry)
      assert.is_true(entry.notCheckable)
      local position, options
      for i, e in ipairs(menuList) do
        if e == entry then position = i end
        if e.text == "Open Options Screen" then options = i end
      end
      assert.are.equal(options - 1, position)
      override(contextMenu, "Hide", function() end)
      entry.func()
      assert.are.same({ "changelog/Open" }, sentMessages)
    end)

    it("refuses in combat, and does nothing for a bag without slots", function()
      local bag = newBag(const.BAG_KIND.BACKPACK, false)
      _G.InCombatLockdown = function() return true end
      override(_G, "print", function() end)
      contextMenu:ToggleBagSlots(context:New("test"), bag)
      assert.is_false(bag.slots:IsShown())
      _G.InCombatLockdown = function() return false end
      bag.slots = nil
      contextMenu:ToggleBagSlots(context:New("test"), bag)
      assert.are.same({}, sentMessages)
    end)
  end)
end)
