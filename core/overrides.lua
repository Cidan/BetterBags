local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')
local _ = L

--[[
  This file is safe to edit manually for translations. Do not overwrite an entire translation table
  with a new one, as this will cause the old translations to be lost. Instead, overwrite translations
  individually. For example, to add a new translation for a string that is in English, you would do
  the following:

L.data["This is a string that is in English"]["frFR"] = "C'est une chaîne qui est en français"
]]--
