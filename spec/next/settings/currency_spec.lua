-- currency_spec.lua -- NextSettingsCurrency (next/settings/currency.lua): the classic bags' Currency page
-- (next-settings.md §8), in place of the classic window's currency panes (config/currencypane.lua,
-- config/classic/currencypane.lua): every currency under its headings, with a switch that shows it in
-- the backpack, through C_CurrencyInfo or, on Mists Classic, the legacy globals.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextSettingsCurrency", "next/settings/currency.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local currency = addon:GetModule("NextSettingsCurrency")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local function K()
  return style.Theme.Settings.Currency
end

describe("NextSettingsCurrency", function()
  local list, calls, sent, timers, saved

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  -- Blizzard's list: a heading's currencies follow it while it is expanded.
  local function blizzardList()
    return {
      { name = "Dungeon and Raid", isHeader = true, isHeaderExpanded = true },
      { name = "Valor", quantity = 1234, maxQuantity = 3000, iconFileID = 101, isShowInBackpack = true },
      { name = "Player vs. Player", isHeader = true, isHeaderExpanded = false,
        children = { { name = "Honor", quantity = 50, iconFileID = 102, isShowInBackpack = false } } },
    }
  end

  local function visible()
    local out = {}
    for _, entry in ipairs(list) do
      table.insert(out, entry)
      if entry.isHeader and entry.isHeaderExpanded then
        for _, child in ipairs(entry.children or {}) do
          table.insert(out, child)
        end
      end
    end
    return out
  end

  local function modern()
    override(_G, "C_CurrencyInfo", {
      GetCurrencyListSize = function() return #visible() end,
      GetCurrencyListInfo = function(i) return visible()[i] end,
      ExpandCurrencyList = function(i, expand)
        table.insert(calls, { "ExpandCurrencyList", i, expand })
        visible()[i].isHeaderExpanded = expand
      end,
      SetCurrencyBackpack = function(i, shown)
        table.insert(calls, { "SetCurrencyBackpack", i, shown })
        visible()[i].isShowInBackpack = shown
      end,
    })
  end

  local function names(block)
    local out = {}
    for _, row in ipairs(block.rows) do
      if row.frame:IsShown() then
        table.insert(out, (row.header and "# " or "") .. row.name:GetText())
      end
    end
    return out
  end

  local function rowNamed(block, name)
    for _, row in ipairs(block.rows) do
      if row.frame:IsShown() and row.name:GetText() == name then return row end
    end
  end

  before_each(function()
    list, calls, sent, timers, saved = blizzardList(), {}, {}, {}, {}
    override(events, "SendMessage", function(_, _, message) table.insert(sent, message) end)
    override(C_Timer, "After", function(delay, fn) table.insert(timers, { delay, fn }) end)
    override(_G, "GetCurrencyListSize", nil)
    override(_G, "GetCurrencyListInfo", nil)
    override(_G, "ExpandCurrencyList", nil)
    override(_G, "SetCurrencyBackpack", nil)
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  it("lists every currency under its heading, expanding the ones Blizzard keeps collapsed", function()
    modern()
    local block = currency:Create(CreateFrame("Frame"))
    block:Refresh(ctx())
    assert.is_true(block.wide)
    assert.are.same({ { "ExpandCurrencyList", 3, true } }, calls)
    assert.are.same({ "# Dungeon and Raid", "Valor", "# Player vs. Player", "Honor" }, names(block))
  end)

  it("shows a currency's icon, how many you have (of its most), and whether the backpack shows it", function()
    modern()
    local block = currency:Create(CreateFrame("Frame"))
    block:Refresh(ctx())
    local valor = rowNamed(block, "Valor")
    assert.are.equal(101, valor.icon:GetTexture())
    assert.are.equal("1,234 / 3,000", valor.count:GetText())
    assert.is_true(valor.toggle:GetChecked())
    local honor = rowNamed(block, "Honor")
    assert.are.equal("50", honor.count:GetText())
    assert.is_false(honor.toggle:GetChecked())
    assert.is_nil(rowNamed(block, "Dungeon and Raid").toggle, "a heading has no switch")
  end)

  it("shows a currency in the backpack with its switch, then reads the list again and tells the backpack", function()
    modern()
    local block = currency:Create(CreateFrame("Frame"))
    block:Refresh(ctx())
    local honor = rowNamed(block, "Honor")
    honor.toggle.frame:GetScript("OnClick")(honor.toggle.frame, "LeftButton")
    assert.are.same({ "SetCurrencyBackpack", 4, true }, calls[#calls])
    assert.are.same({}, sent, "after the game has taken it")
    assert.are.equal(0.1, timers[1][1])
    timers[1][2]()
    assert.are.same({ "currency/Updated" }, sent)
    assert.is_true(rowNamed(block, "Honor").toggle:GetChecked())
  end)

  it("uses the legacy globals where there is no C_CurrencyInfo (Mists Classic)", function()
    override(_G, "C_CurrencyInfo", nil)
    override(_G, "GetCurrencyListSize", function() return #visible() end)
    override(_G, "GetCurrencyListInfo", function(i)
      local e = visible()[i]
      return e.name, e.isHeader, e.isHeaderExpanded, false, e.isShowInBackpack, e.quantity, e.iconFileID, e.maxQuantity
    end)
    override(_G, "ExpandCurrencyList", function(i, expand)
      table.insert(calls, { "ExpandCurrencyList", i, expand })
      visible()[i].isHeaderExpanded = expand == 1
    end)
    override(_G, "SetCurrencyBackpack", function(i, shown)
      table.insert(calls, { "SetCurrencyBackpack", i, shown })
      visible()[i].isShowInBackpack = shown == 1
    end)
    local block = currency:Create(CreateFrame("Frame"))
    block:Refresh(ctx())
    assert.are.same({ "ExpandCurrencyList", 3, 1 }, calls[1], "a number, as the legacy API takes")
    assert.are.same({ "# Dungeon and Raid", "Valor", "# Player vs. Player", "Honor" }, names(block))
    local valor = rowNamed(block, "Valor")
    valor.toggle.frame:GetScript("OnClick")(valor.toggle.frame, "LeftButton")
    assert.are.same({ "SetCurrencyBackpack", 2, 0 }, calls[#calls])
  end)

  it("is as tall as its headings and currencies, and says so when there are none", function()
    modern()
    local block = currency:Create(CreateFrame("Frame"))
    block:Refresh(ctx())
    local pad = style.Theme.Settings.Content.RowPad
    assert.are.equal(2 * K().HeaderHeight + 2 * K().RowHeight + pad, block:Measure(600))
    block:Place(0, 0, 600, block:Measure(600))
    local valor = rowNamed(block, "Valor")
    assert.are.same({ K().IconSize, K().IconSize }, { valor.icon:GetSize() })
    list = {}
    block:Refresh(ctx())
    assert.are.same({}, names(block))
    assert.is_true(block.empty:IsShown())
  end)
end)
