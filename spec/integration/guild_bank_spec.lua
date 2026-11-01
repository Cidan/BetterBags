-- guild_bank_spec.lua -- A guild bank visit on the whole addon (spec/helpers/whole_addon.lua): with
-- BetterBags Next, from the guild banker interaction to the guild bank's items drawn with its own
-- buttons, and the visit's end (guild-bank.md). Blizzard's guild bank frame is shown the way the
-- client shows it (ShowGuildBankFrame) and stays shown, never seen; with the classic bags it is left
-- to Blizzard.

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("a guild bank visit on the whole addon", function()
  local handle, timers

  after_each(function()
    if handle then
      handle:Restore()
    end
    handle = nil
    -- Timers that never ran (timeouts) hold the loaded addon; busted keeps this file's closures, and
    -- with them this list, for the whole run.
    timers = nil
    ResetMockGuildBank()
  end)

  -- A frame clock: every timer waits until the test runs it.
  local function clock()
    timers = {}
    return {
      After = function(delay, fn)
        table.insert(timers, { delay = delay, fn = fn })
      end,
      NewTimer = function(delay, fn)
        local t = { delay = delay, fn = fn }
        function t:Cancel() self.cancelled = true end
        table.insert(timers, t)
        return t
      end,
    }
  end

  -- frames runs the timers due on the next frame (delay 0), and those they schedule, n frames.
  local function frames(n)
    for _ = 1, n or 40 do
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

  -- Items by ID, as the client's item functions describe them (ItemDocumentation.lua).
  local ITEMS = {
    [100] = { name = "Iron Sword", type = "Weapon", subType = "One-Handed Swords", equip = "INVTYPE_WEAPON", class = 2, sub = 7 },
    [200] = { name = "Copper Ore", type = "Tradeskill", subType = "Metal & Stone", equip = "", class = 7, sub = 7 },
  }

  local function linkOf(id)
    return "|cnIQ2:|Hitem:" .. id .. "::::::::80::::::::::|h[" .. ITEMS[id].name .. "]|h|r"
  end

  local function idOf(item)
    return tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
  end

  local function itemFunctions()
    return setmetatable({
      GetItemInfoInstant = function(item)
        local id = idOf(item)
        local def = ITEMS[id]
        if def == nil then return nil end
        return id, def.type, def.subType, def.equip, 134400 + id, def.class, def.sub
      end,
      GetItemInfo = function(item)
        local id = idOf(item)
        local def = ITEMS[id]
        if def == nil then return nil end
        return def.name, linkOf(id), 2, 80, 1, def.type, def.subType, 20, def.equip, 134400 + id, 10, def.class,
          def.sub, 2, 0, 0, false
      end,
      GetItemInventoryTypeByID = function(item)
        return ITEMS[idOf(item)] and ITEMS[idOf(item)].equip == "INVTYPE_WEAPON" and 13 or 0
      end,
      GetDetailedItemLevelInfo = function() return 80, false, 80 end,
      GetItemStats = function() return nil end,
    }, { __index = _G.C_Item })
  end

  local function emptyBags()
    return setmetatable({ GetContainerNumSlots = function() return 0 end }, { __index = _G.C_Container })
  end

  ---@param design "classic"|"next"
  local function start(design)
    local gameMenu = CreateFrame("Frame")
    gameMenu:Hide()
    handle = WholeAddon.Load({
      next = design == "next",
      globals = {
        C_Timer = clock(), GameMenuFrame = gameMenu, C_Container = emptyBags(), C_Item = itemFunctions(),
        SetItemButtonDesaturated = function(button, desaturated) button.icon:SetDesaturated(desaturated and true or false) end,
      },
    })
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    local addon = handle.addon
    local refresh = addon:GetModule("Refresh")
    refresh._worldFrame:GetScript("OnEvent")(refresh._worldFrame, "LOADING_SCREEN_DISABLED")
    refresh._worldFrame:GetScript("OnUpdate")(refresh._worldFrame, 0.016)
    frames()
    assert.is_false(refresh._held, "past the startup read")
    return addon
  end

  -- The guild's bank: two tabs the player can view and deposit in, and Blizzard's guild bank frame
  -- (load on demand, so made here as the client makes it when the guild bank first opens), whose
  -- OnHide ends the visit (GuildBankFrameMixin:OnHide).
  local function guild()
    _G._guildBank.tabs = {
      { name = "Gear", icon = 1, slots = { [1] = { link = linkOf(100), texture = 134500, count = 1, quality = 3 } } },
      { name = "Mats", icon = 2, slots = { [2] = { link = linkOf(200), texture = 134600, count = 20, quality = 1 } } },
    }
    _G._guildBank.current = 1
    _G._guildBank.money = 5000000
    local frame = CreateFrame("Frame", "GuildBankFrame", UIParent)
    frame:Hide()
    frame:SetScript("OnHide", function() CloseGuildBankFrame() end)
    return frame
  end

  -- openGuildBank opens the guild bank as the client does: the interaction (which the player
  -- interaction manager answers with Blizzard's ShowGuildBankFrame: ShowUIPanel, then the visit ends
  -- at once if the frame is not visible), and the server answering every tab queried.
  local function openGuildBank(addon)
    addon:GetModule("Events")._eventMap["PLAYER_INTERACTION_MANAGER_FRAME_SHOW"].fn(
      "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
    ShowUIPanel(GuildBankFrame)
    if not GuildBankFrame:IsVisible() then
      CloseGuildBankFrame()
    end
    frames()
  end

  local function slideIn(addon)
    local tween = addon:GetModule("NextTween")
    for _ = 1, 40 do
      if tween.driver:GetScript("OnUpdate") == nil then break end
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.05)
      frames()
    end
  end

  -- answer has the server send every tab queried, one at a time (GUILDBANKBAGSLOTS_CHANGED).
  local function answer(addon)
    local guildBank = addon:GetModule("GuildBank")
    local event = addon:GetModule("Events")._eventMap["GUILDBANKBAGSLOTS_CHANGED"]
    for _ = 1, 10 do
      if not guildBank:IsLoading() then break end
      _G._guildBank.delivered[_G._guildBank.current] = true
      event.fn("GUILDBANKBAGSLOTS_CHANGED")
      frames()
    end
  end

  it("shows the guild bank at once, reads each tab as it arrives, and draws its items with its own buttons", function()
    local addon = start("next")
    guild()
    local panel = addon.Bags.GuildBank
    openGuildBank(addon)
    assert.are.equal(0, _G._guildBankCalls.closed, "Blizzard's visibility check passed")
    assert.is_true(panel:IsShown(), "shown at once")
    assert.are.equal("Loading...", panel.emptyText:GetText())
    assert.are.same({}, _G._guildBankCalls.queries, "nothing queried while it slides in")
    slideIn(addon)
    assert.are.same({ 1 }, _G._guildBankCalls.queries, "the current tab first")
    answer(addon)
    assert.are.same({ 1, 2 }, _G._guildBankCalls.queries)
    assert.are.equal(1, _G._guildBank.current, "the player's current tab is current again")

    local guildButton = addon:GetModule("NextGuildButton")
    local sword = panel.content.buttons["1001_1"]
    local ore = panel.content.buttons["1002_2"]
    assert.is_not_nil(sword, "the sword is drawn")
    assert.is_not_nil(ore, "the ore is drawn")
    assert.are.equal(guildButton.bySlotkey["1002_2"], ore)
    assert.are.equal(134600, ore.button.icon:GetTexture())
    assert.are.equal("20", tostring(ore.button.Count:GetText()))
    assert.is_false(panel.emptyText:IsShown())
    local names = {}
    for _, section in ipairs(panel.content.order) do table.insert(names, section.name) end
    assert.is_true(#names >= 2, table.concat(names, ", "))
    -- Hovering an item shows Blizzard's tooltip for its slot (retail's SetGuildBankItem returns only
    -- true or false; reading a battle pet from it errored on every hover).
    _G._guildBankCalls.tooltips = {}
    ore.button:GetScript("OnEnter")(ore.button)
    assert.are.same({ { tab = 2, slot = 2 } }, _G._guildBankCalls.tooltips)
    assert.are.same({}, handle.errors, "hovering")
    ore.button:GetScript("OnLeave")(ore.button)
    assert.are.equal(_G.BetterBagsSneakyFrame, GuildBankFrame:GetParent(), "Blizzard's frame never seen")
    assert.is_true(GuildBankFrame:IsShown(), "and still shown to Blizzard's code")
    assert.are.same({}, handle.errors)
  end)

  -- Each tab's read used to keep the layout, so a section took the width what had loaded when it first showed asked for.
  it("gives a section spanning columns its width for the whole guild bank, not the first tab read", function()
    local addon = start("next")
    guild()
    local ores = {}
    for slot = 1, 20 do
      ores[slot] = { link = linkOf(200), texture = 134600, count = 1, quality = 1 }
    end
    _G._guildBank.tabs[1].slots = { [1] = { link = linkOf(200), texture = 134600, count = 1, quality = 1 } }
    _G._guildBank.tabs[2].slots = ores
    local database = addon:GetModule("Database")
    local const = addon:GetModule("Constants")
    database:SetNextSectionColumns(const.BAG_KIND.GUILD, 2)
    -- Not stacked, so the section holds every pile.
    database:SetMergeItems(const.BAG_KIND.GUILD, false)
    local panel = addon.Bags.GuildBank
    openGuildBank(addon)
    slideIn(addon)
    answer(addon)
    frames()
    assert.are.same({}, handle.errors)
    local section
    for _, candidate in ipairs(panel.content.order) do
      if #candidate.entries == 21 then section = candidate end
    end
    assert.is_not_nil(section, "one section holds all 21 piles")
    assert.are.equal(addon:GetModule("NextStyle").GRID_WIDTH, section.frame:GetWidth(), "it spans both columns")
  end)

  -- Found by the adversarial review: GUILDBANKBAGSLOTS_CHANGED names no tab, so the real answer can come after the query
  -- timed out, or after another player's move was taken for it. Such a read is a "change", and it kept the layout.
  describe("a tab's real answer coming late or shifted", function()
    local ORES = { [201] = "Iron Ore", [202] = "Zinc Ore" }

    local function stock()
      for id, name in pairs(ORES) do
        ITEMS[id] = { name = name, type = "Tradeskill", subType = "Metal & Stone", equip = "", class = 7, sub = 7 }
      end
      _G._guildBank.tabs[1].slots = {
        [1] = { link = linkOf(200), texture = 134600, count = 20, quality = 1 },
        [2] = { link = linkOf(202), texture = 134602, count = 20, quality = 1 },
      }
      _G._guildBank.tabs[2].slots = { [1] = { link = linkOf(201), texture = 134601, count = 20, quality = 1 } }
    end

    after_each(function()
      for id in pairs(ORES) do ITEMS[id] = nil end
    end)

    local function order(addon)
      local const = addon:GetModule("Constants")
      local out = {}
      for _, item in ipairs(addon:GetModule("Items").slotInfo[const.BAG_KIND.GUILD].sortedItems) do
        if item.isItemGap then
          out[#out + 1] = "GAP"
        elseif item.itemInfo and item.itemInfo.itemName then
          out[#out + 1] = item.itemInfo.itemName
        end
      end
      return table.concat(out, " | ")
    end

    -- freshOrder is the layout a fresh one gives; the sort is the player's, by name.
    local function freshOrder(addon)
      addon:GetModule("Refresh"):RequestUpdate({ guild = true, resetLayout = true })
      frames()
      return order(addon)
    end

    local function byName(addon)
      addon:GetModule("Sort").GetItemDataSortFunction = function()
        return function(a, b)
          if a.isFreeSlot or a.isItemGap then return false end
          if b.isFreeSlot or b.isItemGap then return true end
          return a.itemInfo.itemName < b.itemInfo.itemName
        end
      end
    end

    local function fireTimeout(seconds)
      for i = #timers, 1, -1 do
        if timers[i].delay == seconds then
          local t = table.remove(timers, i)
          t.fn()
          frames()
          return true
        end
      end
      return false
    end

    local function arrive(addon, tab)
      if tab then _G._guildBank.delivered[tab] = true end
      addon:GetModule("Events")._eventMap["GUILDBANKBAGSLOTS_CHANGED"].fn("GUILDBANKBAGSLOTS_CHANGED")
      frames()
    end

    it("ends in a fresh layout when a tab answers after its query timed out", function()
      local addon = start("next")
      guild()
      stock()
      byName(addon)
      openGuildBank(addon)
      slideIn(addon)
      arrive(addon, 1)
      assert.is_true(fireTimeout(addon:GetModule("GuildBank").QUERY_TIMEOUT))
      arrive(addon, 2)
      local loaded = order(addon)
      assert.are.equal("Copper Ore | Iron Ore | Zinc Ore", freshOrder(addon))
      assert.are.equal("Copper Ore | Iron Ore | Zinc Ore", loaded)
      assert.are.same({}, handle.errors)
    end)

    it("ends in a fresh layout when another player's move was taken for a tab's answer", function()
      local addon = start("next")
      guild()
      stock()
      byName(addon)
      openGuildBank(addon)
      slideIn(addon)
      arrive(addon, 1)
      arrive(addon)
      assert.is_false(addon:GetModule("GuildBank"):IsLoading())
      arrive(addon, 2)
      assert.are.equal("Copper Ore | Iron Ore | Zinc Ore", order(addon))
    end)

    it("gives a section spanning columns its width when its tab answers late", function()
      local addon = start("next")
      guild()
      local ores = {}
      for slot = 1, 20 do
        ores[slot] = { link = linkOf(200), texture = 134600, count = 1, quality = 1 }
      end
      _G._guildBank.tabs[1].slots = { [1] = { link = linkOf(200), texture = 134600, count = 1, quality = 1 } }
      _G._guildBank.tabs[2].slots = ores
      local database, const = addon:GetModule("Database"), addon:GetModule("Constants")
      database:SetNextSectionColumns(const.BAG_KIND.GUILD, 2)
      database:SetMergeItems(const.BAG_KIND.GUILD, false)
      local panel = addon.Bags.GuildBank
      openGuildBank(addon)
      slideIn(addon)
      arrive(addon, 1)
      assert.is_true(fireTimeout(addon:GetModule("GuildBank").QUERY_TIMEOUT))
      arrive(addon, 2)
      local section
      for _, candidate in ipairs(panel.content.order) do
        if #candidate.entries == 21 then section = candidate end
      end
      assert.is_not_nil(section)
      assert.are.equal(addon:GetModule("NextStyle").GRID_WIDTH, section.frame:GetWidth())
    end)

    it("keeps a gap the player made when a tab they looked at is answered again", function()
      local addon = start("next")
      guild()
      stock()
      byName(addon)
      local panel = addon.Bags.GuildBank
      openGuildBank(addon)
      slideIn(addon)
      answer(addon)
      frames()
      local context = addon:GetModule("Context")
      panel:ShowTab(context:New("spec"), addon:GetModule("GuildBank"):ContainerOf(2))
      frames()
      panel:ShowAll(context:New("spec"))
      frames()
      -- The withdrawal, taken for the answer to the tab queried.
      _G._guildBank.tabs[1].slots[2] = nil
      arrive(addon)
      assert.is_truthy(order(addon):find("GAP"), order(addon))
    end)

    it("flies nothing as its tabs arrive", function()
      local addon = start("next")
      guild()
      stock()
      byName(addon)
      local motion = addon:GetModule("Motion")
      openGuildBank(addon)
      slideIn(addon)
      for _, tab in ipairs({ 1, 2 }) do
        arrive(addon, tab)
        assert.are.same({}, motion.moves, "after tab " .. tab)
      end
    end)
  end)

  it("puts the guild's tabs in the panel's tabs, and its gold in the footer", function()
    local addon = start("next")
    guild()
    local panel = addon.Bags.GuildBank
    openGuildBank(addon)
    slideIn(addon)
    answer(addon)
    local ids = {}
    for _, t in ipairs(panel.tabs.tabs) do table.insert(ids, t.id) end
    assert.are.same({ 1, 1001, 1002 }, ids)
    assert.are.equal(C_CurrencyInfo.GetCoinTextureString(5000000), panel.moneyFrame.text:GetText())
    assert.are.same({}, handle.errors)
  end)

  it("ends the visit once when the panel is closed, and forgets the guild bank when it ends", function()
    local addon = start("next")
    guild()
    local panel = addon.Bags.GuildBank
    openGuildBank(addon)
    slideIn(addon)
    answer(addon)
    panel.closeButton:GetScript("OnClick")(panel.closeButton, "LeftButton")
    assert.are.equal(1, _G._guildBankCalls.closed)
    -- The server ends the interaction: the manager hides Blizzard's frame (HideGuildBankFrame).
    addon:GetModule("Events")._eventMap["PLAYER_INTERACTION_MANAGER_FRAME_HIDE"].fn(
      "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
    HideUIPanel(GuildBankFrame)
    frames()
    slideIn(addon)
    assert.are.equal(1, _G._guildBankCalls.closed, "once")
    assert.is_false(addon.atGuildBank)
    local items = addon:GetModule("Items")
    assert.is_nil(next(items:GetAllSlotInfo()[addon:GetModule("Constants").BAG_KIND.GUILD].itemsBySlotKey))
    assert.are.same({}, handle.errors)
  end)

  it("refuses to switch to the classic bags at the guild bank", function()
    local addon = start("next")
    guild()
    openGuildBank(addon)
    local bagSystem = addon:GetModule("BagSystem")
    assert.is_false(bagSystem:Switch(addon:GetModule("Context"):New("test"), "classic"))
    assert.are.equal("next", bagSystem:ActiveDesign())
  end)

  it("leaves the guild bank to Blizzard's frame with the classic bags", function()
    local addon = start("classic")
    local frame = guild()
    openGuildBank(addon)
    assert.is_nil(addon.Bags.GuildBank)
    assert.are.equal(UIParent, frame:GetParent())
    assert.is_true(frame:IsVisible())
    assert.are.same({}, _G._guildBankCalls.queries, "BetterBags queries nothing")
    assert.are.same({}, handle.errors)
  end)
end)
