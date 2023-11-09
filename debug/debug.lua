local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
---@field _bdi table
local debug = addon:NewModule('Debug')

local DLAPI = _G['DLAPI']

function debug:OnInitialize()
  local bdi = {
    colNames = {"ID", "Time", "Cat", "Vrb", "Message"},
    colWidth = { 0.05, 0.12, 0.15, 0.03, 1 - 0.05 - 0.12 - 0.15 - 0.03, },
    colFlex = { "flex", "flex", "drop", "drop", "search", },
    statusText = {
      "Sort by ID",
      "Sort by Time",
      "Sort by Category",
      "Sort by Verbosity",
      "Sort by Message",
    },
    GetSTData = DLAPI.IsFormatRegistered("default").GetSTData
  }
  debug._bdi = bdi
end

function debug:OnEnable()
  print("BetterBags: debug mode enabled")
  if DLAPI then
    DLAPI.RegisterFormat("bdi", debug._bdi)
    DLAPI.SetFormat("BetterBags", "bdi")
  end
end

function debug:Format(...)
  if ... == nil or #... == 0 then
    return ""
  end
  return ...
end

function debug:Log(category, ...)
  DLAPI.DebugLog("BetterBags", format("%s~%s", category, debug:Format(...)))
end
debug:Enable()
