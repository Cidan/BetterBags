local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class FormLayouts: AceModule
local layouts = addon:NewModule('FormLayouts')

---@class (exact) FormLayout
---@field targetFrame Frame
---@field sections FontString[]
---@field AddSection fun(self: FormLayout, opts: FormSectionOptions)