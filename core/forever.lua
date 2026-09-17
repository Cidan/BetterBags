-- forever.lua marks the running client as WoW: Forever (codename Camelot).
--
-- Camelot is a mainline retail fork: the engine and UI are retail, so
-- WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and addon.isRetail is true, exactly
-- like live retail. There is therefore no version/build/project number that
-- distinguishes Camelot from live retail at runtime. The only reliable signal
-- is load-time: this file is listed ONLY in BetterBags_Camelot.toc, so it runs
-- solely on the Camelot client. It must load after core/boot.lua (which creates
-- the addon) and before core/constants.lua (which reads addon.isForever to size
-- the bank tab tables).
local addonName = ... ---@type string
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

addon.isForever = true
