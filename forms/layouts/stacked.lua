local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class (exact) FormLayouts: AceModule
local layouts = addon:GetModule('FormLayouts')

---@class (exact) StackedLayout: FormLayout
---@field nextFrame Frame
---@field height number
local stackedLayout = {}

---@param targetFrame Frame
---@return FormLayout
function layouts:NewStackedLayout(targetFrame)
  local l = setmetatable({}, {__index = stackedLayout}) --[[@as StackedLayout]]
  l.targetFrame = targetFrame
  l.nextFrame = targetFrame
  l.height = 0
  l.sections = {}
  return l
end

---@private
---@param t Frame
---@param container Frame
---@param indent? number
function stackedLayout:alignFrame(t, container, indent)
  indent = indent or 0
  if t == self.targetFrame then
    container:SetPoint("TOPLEFT", t, "TOPLEFT", 10 + indent, -10)
    container:SetPoint("TOPRIGHT", t, "TOPRIGHT", -20, -10)
    self.height = self.height + 10
  else
    container:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0 + indent, -20)
    container:SetPoint("RIGHT", self.targetFrame, "RIGHT", -20, 0)
    self.height = self.height + 20
  end
end

---@private
---@param container Frame
---@param title string
---@return FontString
function stackedLayout:createTitle(container, title)
  local titleFont = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleFont:SetTextColor(1, 1, 1)
  titleFont:SetJustifyH("LEFT")
  titleFont:SetText(title)
  return titleFont
end

---@private
---@param container Frame
---@param description string
---@return FontString
function stackedLayout:createDescription(container, description)
  local descriptionFont = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  descriptionFont:SetTextColor(1, 1, 1)
  descriptionFont:SetJustifyH("LEFT")
  descriptionFont:SetText(description)
  descriptionFont:SetWordWrap(true)
  descriptionFont:SetNonSpaceWrap(true)
  return descriptionFont
end

---@param opts FormSectionOptions
function stackedLayout:AddSection(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSection]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title)
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT")

  container.description = self:createDescription(container, opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container:SetHeight(container.title:GetHeight() + container.description:GetHeight() + 10)
  self.sections[opts.title] = container

  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end

---@param opts FormSubSectionOptions
function stackedLayout:AddSubSection(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSubSection]]
  self:alignFrame(t, container)

  local titleContainer = CreateFrame("Frame", nil, container)
  titleContainer:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)
  titleContainer:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  container.title = self:createTitle(titleContainer, opts.title)
  container.title:SetPoint("TOPLEFT", titleContainer, "TOPLEFT")
  container.description = self:createDescription(container, opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container:SetHeight(container.title:GetLineHeight() + container.description:GetLineHeight() + 25)
  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end

---@param opts FormCheckboxOptions
function stackedLayout:AddCheckbox(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormCheckbox]]
  self:alignFrame(t, container)

  container.checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate") --[[@as CheckButton]]
  container.checkbox:SetPoint("TOPLEFT", container, "TOPLEFT")

  container.title = self:createTitle(container, opts.title)
  container.title:SetPoint("LEFT", container.checkbox, "RIGHT", 5, 0)
  container.title:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container.description = self:createDescription(container, opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
  container.description:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container:SetHeight(container.title:GetLineHeight() + container.description:GetLineHeight() + 25)
  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end

---@param opts FormDropdownOptions
function stackedLayout:AddDropdown(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormDropdown]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title)
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
  container.dropdown:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container.dropdown:SetupMenu(function(_, root)
    for _, item in ipairs(opts.items) do
      root:CreateCheckbox(item, opts.getValue, opts.setValue, item)
    end
  end)

  container.dropdown:GenerateMenu()

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.dropdown:GetHeight() +
    25
  )
  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end

---@param opts FormSliderOptions
function stackedLayout:AddSlider(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSlider]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title)
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.slider = CreateFrame("Slider", nil, container, "UISliderTemplate") --[[@as Slider]]
  container.slider:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.slider:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  container.slider:SetOrientation("HORIZONTAL")
  container.slider:SetHeight(20)
  container.slider:SetMinMaxValues(opts.min, opts.max)
  container.slider:SetValueStep(opts.step)
  container.slider:SetObeyStepOnDrag(true)

  container.input = CreateFrame("EditBox", nil, container, "InputBoxTemplate") --[[@as EditBox]]
  container.input:SetSize(50, 20)
  container.input:SetPoint("TOP", container.slider, "BOTTOM", 0, -5)
  container.input:SetNumeric(true)
  container.input:SetAutoFocus(false)
  addon.SetScript(container.input, "OnTextChanged", function(ctx, _, value)
    print(value)
    container.slider:SetValue(value)
    --opts.setValue(ctx, value)
  end)

  addon.SetScript(container.slider, "OnValueChanged", function(ctx, _, value)
    opts.setValue(ctx, value)
  end)
  container.slider:SetValue(opts.getValue(context:New('Slider_Load')))

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.slider:GetHeight() +
    container.input:GetHeight() +
    30
  )
  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end