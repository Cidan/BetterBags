-- forever.lua marks the running client as WoW: Forever (codename Camelot).
--
-- Camelot is a mainline retail fork: the engine and UI are retail, so
-- addon.isRetail is true, exactly like live retail. Builds before 1.60.1 (70170)
-- report WOW_PROJECT_ID == WOW_PROJECT_MAINLINE, so no version/build/project number
-- distinguishes them from live retail at runtime (70170+ report WOW_PROJECT_CAMELOT,
-- which core/constants.lua also honors). This load-time signal works on every build:
-- this file is listed ONLY in BetterBags_Camelot.toc, so it runs solely on the
-- Camelot client. It must load after core/boot.lua (which creates the addon) and
-- before core/constants.lua (which reads addon.isForever to size the bank tab tables).
local addonName = ... ---@type string
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

addon.isForever = true
