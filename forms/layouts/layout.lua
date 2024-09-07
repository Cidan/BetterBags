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

---@class (exact) FormSubSection: Frame
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
---@field classicDropdown Button

---@class (exact) FormSlider: Frame
---@field title FontString
---@field description FontString
---@field slider Slider
---@field input EditBox

--[[
-- Widget Options
]]--

---@class (exact) FormSectionOptions
---@field title string
---@field description string

---@class (exact) FormSubSectionOptions
---@field title string
---@field description string

---@class (exact) FormCheckboxOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): boolean
---@field setValue fun(ctx: Context, value: boolean)

---@class (exact) FormDropdownOptions
---@field title string
---@field description string
---@field items string[]
---@field getValue fun(ctx: Context, value: string): boolean
---@field setValue fun(ctx: Context, value: string)

---@class (exact) FormSliderOptions
---@field title string
---@field description string
---@field min number
---@field max number
---@field step number
---@field getValue fun(ctx: Context): number
---@field setValue fun(ctx: Context, value: number)

---@class (exact) FormLayout
---@field targetFrame Frame
---@field height number
---@field AddSection fun(self: FormLayout, opts: FormSectionOptions)
---@field AddCheckbox fun(self: FormLayout, opts: FormCheckboxOptions)
---@field AddDropdown fun(self: FormLayout, opts: FormDropdownOptions)
---@field AddSubSection fun(self: FormLayout, opts: FormSubSectionOptions)
---@field AddSlider fun(self: FormLayout, opts: FormSliderOptions)