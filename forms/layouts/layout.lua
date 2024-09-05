local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class FormLayouts: AceModule
local layouts = addon:NewModule('FormLayouts')

---@class (exact) FormSection: Frame
---@field title FontString
---@field description FontString

---@class (exact) FormCheckbox: Frame
---@field title FontString
---@field description FontString
---@field checkbox CheckButton

---@class (exact) FormLayout
---@field targetFrame Frame
---@field height number
---@field sections table<string, FormSection>
---@field AddSection fun(self: FormLayout, opts: FormSectionOptions)
---@field AddCheckbox fun(self: FormLayout, opts: FormCheckboxOptions)