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
---@field classicDropdown Frame

---@class (exact) FormSlider: Frame
---@field title FontString
---@field description FontString
---@field slider Slider
---@field input EditBox

---@class (exact) FormButtons: Frame
---@field buttons Button[]

---@class (exact) FormTextArea: Frame
---@field title FontString
---@field description FontString
---@field input EditBox

---@class (exact) FormInputBox: Frame
---@field title FontString
---@field description FontString
---@field input EditBox

---@class (exact) FormColor: Frame
---@field title FontString
---@field description FontString
---@field colorPicker Frame
---@field colorTexture Texture

---@class (exact) FormLabel: Frame
---@field description FontString

--[[
-- Widget Options
]]--

---@class Colors
---@field red number
---@field green number
---@field blue number
---@field alpha number

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
---@field items? string[]
---@field itemsFunction? fun(ctx: Context): string[]
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

---@class (exact) FormButtonOption
---@field title string
---@field onClick fun(ctx: Context)

---@class (exact) FormButtonGroupOptions
---@field ButtonOptions FormButtonOption[]

---@class (exact) FormTextAreaOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): string
---@field setValue fun(ctx: Context, value: string)

---@class (exact) FormInputBoxOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): string
---@field setValue fun(ctx: Context, value: string)

---@class (exact) FormColorOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): Colors
---@field setValue fun(ctx: Context, value: Colors)

---@class (exact) FormLabelOptions
---@field description string

---@class (exact) FormLayout
---@field targetFrame Frame
---@field height number
---@field ReloadAllFormElements fun(self: FormLayout)
---@field UpdateUnderline fun(self: FormLayout)
---@field AddSection fun(self: FormLayout, opts: FormSectionOptions)
---@field AddCheckbox fun(self: FormLayout, opts: FormCheckboxOptions)
---@field AddDropdown fun(self: FormLayout, opts: FormDropdownOptions)
---@field AddSubSection fun(self: FormLayout, opts: FormSubSectionOptions)
---@field AddSlider fun(self: FormLayout, opts: FormSliderOptions)
---@field AddButtonGroup fun(self: FormLayout, opts: FormButtonGroupOptions)
---@field AddTextArea fun(self: FormLayout, opts: FormTextAreaOptions)
---@field AddInputBox fun(self: FormLayout, opts: FormInputBoxOptions)
---@field AddColor fun(self: FormLayout, opts: FormColorOptions)
---@field AddLabel fun(self: FormLayout, opts: FormLabelOptions)