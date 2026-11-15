-- empty_group_hint_spec.lua -- The classic backpack's hint in an empty group's tab ("Drag a section header to this tab..."),
-- on the whole addon (spec/helpers/whole_addon.lua) with its frames resolved on a real screen (spec/helpers/layout.lua).
-- Reported on v0.8.12 (#1216): "clipped on its left, so only the end of each line shows". The empty view measured 0 x 0,
-- so the hint was centered on a container 1 unit tall and only as wide as the rest of the content: in a bag sized to its
-- content that container sits at the scroll box's left, which clips what is past it (WowScrollBox inherits
-- ScrollBoxBaseTemplate, clipChildren="true", Blizzard_SharedXML/Shared/Scroll/ScrollBox.xml), and at its top, above
-- which the hint's top half went, with Free Space hung right below it.
--
-- The frame mock has no item button template, so no item can be drawn on the whole addon (test-harness.md §5): every bag
-- is empty, which is what an empty group shows.

local WholeAddon = dofile("spec/helpers/whole_addon.lua")
local layout = dofile("spec/helpers/layout.lua")

local SCREEN_WIDTH, SCREEN_HEIGHT = 1366, 768
local HINT = "Drag a section header to this tab at the bottom of the window to add a section to this group!"

describe("the classic backpack's hint in an empty group", function()
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

  -- start starts the whole addon past the startup read (unless opts.unread) with a second backpack group, New Group,
  -- which holds no category, shown. opts.profile changes any other default.
  local function start(opts)
    opts = opts or {}
    stop()
    undoScreen = layout.UseScreen(SCREEN_WIDTH, SCREEN_HEIGHT, 1)
    timers = {}
    local gameMenu = _G.CreateFrame("Frame")
    gameMenu:Hide()
    handle = WholeAddon.Load({
      globals = {
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
        local backpack = const.BAG_KIND.BACKPACK
        defaults.groups[backpack][2] = { id = 2, name = "New Group", order = 2, kind = backpack }
        defaults.groupCounter[backpack] = 2
        defaults.activeGroup[backpack] = 2
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
    end
    frames()
    return addon
  end

  -- open shows the backpack and returns it.
  local function open(addon)
    local bag = addon.Bags.Backpack
    bag:Show(addon:GetModule("Context"):New("empty group hint"))
    frames()
    return bag
  end

  local function hintOf(bag)
    local frame = bag.currentView.emptyGroupFrame
    for _, region in ipairs({ frame:GetRegions() }) do
      if region.GetText and region:GetText() == HINT then
        return region
      end
    end
  end

  local function windowSized(width, height)
    return { profile = function(defaults, const)
      for _, view in pairs(defaults.size) do
        local size = view[const.BAG_KIND.BACKPACK]
        size.sizeMode, size.width, size.height = "window", width, height
      end
    end }
  end

  -- inside asserts the whole hint shows: within the scroll box that clips it, and above Free Space.
  local function inside(bag, what)
    local hint = layout.Rect(hintOf(bag))
    local box = layout.Rect(bag.scrollBox)
    local footer = layout.Rect(bag.footerContainer)
    assert.is_true(hint.left >= box.left - 0.01,
      string.format("%s: the hint's left is %.1f, past the scroll box's %.1f", what, hint.left, box.left))
    assert.is_true(hint.right <= box.right + 0.01,
      string.format("%s: the hint's right is %.1f, past the scroll box's %.1f", what, hint.right, box.right))
    assert.is_true(hint.top <= box.top + 0.01,
      string.format("%s: the hint's top is %.1f, above the scroll box's %.1f", what, hint.top, box.top))
    assert.is_true(hint.bottom >= box.bottom - 0.01,
      string.format("%s: the hint's bottom is %.1f, below the scroll box's %.1f", what, hint.bottom, box.bottom))
    assert.is_true(hint.bottom >= footer.top - 0.01,
      string.format("%s: the hint's bottom is %.1f, over Free Space at %.1f", what, hint.bottom, footer.top))
  end

  -- centered asserts the hint is in the middle of the scroll box across.
  local function centered(bag, what)
    local hint = layout.Rect(hintOf(bag))
    local box = layout.Rect(bag.scrollBox)
    local middle, boxMiddle = (hint.left + hint.right) / 2, (box.left + box.right) / 2
    assert.is_true(math.abs(middle - boxMiddle) < 0.01,
      string.format("%s: the hint's middle is %.1f, the scroll box's %.1f", what, middle, boxMiddle))
  end

  it("shows whole, in the middle, in a bag sized to its content", function()
    local bag = open(start())
    assert.is_true(bag.currentView.emptyGroupFrame:IsShown())
    inside(bag, "sized to its content")
    centered(bag, "sized to its content")
    assert.are.same({}, handle.errors)
  end)

  it("shows whole, in the middle, in a window the player sized", function()
    local bag = open(start(windowSized(400, 300)))
    inside(bag, "400 x 300")
    centered(bag, "400 x 300")
    assert.are.same({}, handle.errors)
  end)

  it("shows whole in a window the player made as small as it goes", function()
    local bag = open(start(windowSized(1, 1)))
    inside(bag, "as small as it goes")
    centered(bag, "as small as it goes")
    assert.are.same({}, handle.errors)
  end)

  -- A tab bar wider than a bag's narrowest content widens the window past it; the canvas is still only as wide as its
  -- content and sits at the scroll box's left, as for every bag sized to its content, so the hint is left of the middle
  -- there (layout-rendering.md §5), but whole.
  it("shows whole beside a tab bar wider than a bag's narrowest content", function()
    local bag = open(start({ profile = function(defaults, const)
      local backpack = const.BAG_KIND.BACKPACK
      for id = 3, 6 do
        defaults.groups[backpack][id] = { id = id, name = "Group " .. id, order = id, kind = backpack }
      end
      defaults.groupCounter[backpack] = 6
    end }))
    assert.is_true(bag.tabs.width > 260)
    inside(bag, "beside a wide tab bar")
    assert.are.same({}, handle.errors)
  end)

  -- Loading... is in the middle of the scroll box, where the hint now is: the hint waits for the first read.
  it("does not show under Loading... before the bag was ever read, then shows once it is", function()
    local addon = start({ unread = true })
    local bag = open(addon)
    assert.is_true(bag.loadingText:IsShown())
    assert.is_false(bag.currentView.emptyGroupFrame:IsShown())
    local refresh = addon:GetModule("Refresh")
    refresh._worldFrame:GetScript("OnEvent")(refresh._worldFrame, "LOADING_SCREEN_DISABLED")
    refresh._worldFrame:GetScript("OnUpdate")(refresh._worldFrame, 0.016)
    frames()
    assert.is_false(bag.loadingText:IsShown())
    assert.is_true(bag.currentView.emptyGroupFrame:IsShown())
    inside(bag, "after the first read")
    centered(bag, "after the first read")
    assert.are.same({}, handle.errors)
  end)

  it("takes no room in a group that is not empty, or the default group", function()
    local bag = open(start({ profile = function(defaults, const)
      defaults.activeGroup[const.BAG_KIND.BACKPACK] = 1
    end }))
    assert.is_false(bag.currentView.emptyGroupFrame:IsShown())
    local view = bag.canvas.plan.view
    assert.are.same({ view.content.width, view.content.height }, { view.width, view.height })
  end)
end)
