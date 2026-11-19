-- slash_commands_spec.lua -- BetterBags' chat commands on the whole addon (spec/helpers/whole_addon.lua,
-- slash-commands.md). The client keeps one handler per command: ImportListToHash
-- (Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua) walks SlashCmdList in the table's own order and writes each
-- entry's SLASH_<key><n> commands into hash_SlashCmdList, a later entry replacing an earlier one. A second entry
-- claiming /bb (data/items.lua's debug command) left one of the two dead, which one depending on the player's other
-- addons: /bb printed the debug command's help instead of opening the settings (#1246, #1360).

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("BetterBags' chat commands on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
    end
    handle = nil
  end)

  local function start()
    handle = WholeAddon.Load()
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    return handle.addon
  end

  -- commandsOf lists an entry's commands as the client reads them: SLASH_<key>1, SLASH_<key>2, ... uppercased.
  local function commandsOf(key)
    local commands = {}
    local i = 1
    local tag = _G["SLASH_" .. key .. i]
    while tag do
      table.insert(commands, strupper(tag))
      i = i + 1
      tag = _G["SLASH_" .. key .. i]
    end
    return commands
  end

  -- claimants lists the SlashCmdList entries that name the command, sorted.
  local function claimants(command)
    local keys = {}
    for key in pairs(_G.SlashCmdList) do
      for _, tag in ipairs(commandsOf(key)) do
        if tag == strupper(command) then
          table.insert(keys, key)
          break
        end
      end
    end
    table.sort(keys)
    return keys
  end

  -- import is ImportListToHash's walk over SlashCmdList, visiting the entries in the order given.
  local function import(keys)
    local hash = {}
    for _, key in ipairs(keys) do
      for _, tag in ipairs(commandsOf(key)) do
        hash[tag] = _G.SlashCmdList[key]
      end
    end
    return hash
  end

  local function sortedKeys(reversed)
    local keys = {}
    for key in pairs(_G.SlashCmdList) do table.insert(keys, key) end
    table.sort(keys, function(a, b)
      if reversed then return a > b end
      return a < b
    end)
    return keys
  end

  it("claims /bb, /bbanchor and /bbdb from one entry each, the ones Config registered", function()
    start()
    assert.are.same({ "ACECONSOLE_BB" }, claimants("/bb"))
    assert.are.same({ "ACECONSOLE_BBANCHOR" }, claimants("/bbanchor"))
    assert.are.same({ "ACECONSOLE_BBDB" }, claimants("/bbdb"))
  end)

  for _, reversed in ipairs({ false, true }) do
    local order = reversed and "last to first" or "first to last"
    it("opens the settings on /bb whatever order the client imports the commands in (" .. order .. ")", function()
      local addon = start()
      local hash = import(sortedKeys(reversed))
      assert.is_function(hash["/BB"])
      hash["/BB"]("", nil)
      assert.are.same({}, handle.errors)
      assert.is_true(addon:GetModule("NextSettings"):IsShown())
    end)
  end
end)
