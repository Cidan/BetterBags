local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class FormLayouts: AceModule
local layouts = addon:NewModule('FormLayouts')

--[[
-- Widgets
]]--

---@class (exact) FormSection: Frame
---@field title FontString
---@field description FontString

---@class (exact) FormCheckbox: Frame
---@field title FontString
---@field description FontString
---@field checkbox CheckButton

---@class (exact) FormDropdown: Frame
---@field title FontString
---@field description FontString
---@field dropdown DropdownButton

--[[
-- Widget Options
]]--

---@class FormSectionOptions
---@field title string
---@field description string

---@class FormCheckboxOptions
---@field title string
---@field description string

---@class (exact) FormDropdownOptions
---@field title string
---@field description string
---@field items string[]
---@field getValue fun(string): boolean
---@field setValue fun(string)

---@class (exact) FormLayout
---@field targetFrame Frame
---@field height number
---@field sections table<string, FormSection>
---@field AddSection fun(self: FormLayout, opts: FormSectionOptions)
---@field AddCheckbox fun(self: FormLayout, opts: FormCheckboxOptions)
---@field AddDropdown fun(self: FormLayout, opts: FormDropdownOptions)