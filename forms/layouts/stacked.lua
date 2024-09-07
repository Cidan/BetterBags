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
---@field nextIndex Frame
---@field baseFrame Frame
---@field indexFrame Frame
---@field sections {point: Frame, button: Button}[]
---@field scrollBox WowScrollBox
---@field height number
---@field index boolean
local stackedLayout = {}

---@param targetFrame Frame
---@param baseFrame Frame
---@param scrollBox WowScrollBox
---@param index boolean
---@return FormLayout
function layouts:NewStackedLayout(targetFrame, baseFrame, scrollBox, index)
  local l = setmetatable({}, {__index = stackedLayout}) --[[@as StackedLayout]]
  l.targetFrame = targetFrame
  l.nextFrame = targetFrame
  l.height = 0
  l.index = index
  l.baseFrame = baseFrame
  l.scrollBox = scrollBox
  l.sections = {}
  if index then
    l:setupIndex()
  end
  return l
end

---@package
function stackedLayout:setupIndex()
  self.indexFrame = CreateFrame("Frame", nil, self.baseFrame) --[[@as Frame]]
  self.indexFrame:SetPoint("TOPLEFT", self.baseFrame, "TOPLEFT", 10, -20)
  self.indexFrame:SetPoint("BOTTOM", self.baseFrame, "BOTTOM", 0, 0)
  self.indexFrame:SetWidth(120)

  local underline = self:createDividerLineLeft(self.indexFrame)
  self.scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
    for i, section in ipairs(self.sections) do
      local targetTop = section.point:GetTop()
      local parentTop = self.targetFrame:GetTop()
      if parentTop == nil then break end
      if self.scrollBox:GetDerivedScrollOffset() < parentTop - targetTop then
        local uSection = i == 1 and section or self.sections[i - 1]
        underline:SetPoint("TOPLEFT", uSection.button, "BOTTOMLEFT", 0, 0)
        underline:SetPoint("TOPRIGHT", uSection.button, "BOTTOMRIGHT", 0, 0)
        break
      end
    end
  end)
  self.nextIndex = self.indexFrame
end

---@package
---@param title string
---@param point Frame
---@param sub? boolean
function stackedLayout:addIndex(title, point, sub)
  if not self.index then return end
  local indexButton = CreateFrame("Button", nil, self.indexFrame) --[[@as Button]]
  indexButton:SetSize(100, 24)
  if sub then
    indexButton:SetNormalFontObject("GameFontNormal")
  else
    indexButton:SetNormalFontObject("GameFontNormalLarge")
  end
  local fs = indexButton:GetNormalFontObject()
  fs:SetTextColor(1, 1, 1)
  fs:SetJustifyH("LEFT")
  indexButton:SetText(sub and "  " .. title or title)

  indexButton:SetScript("OnClick", function()
    local targetTop = point:GetTop()
    local parentTop = self.targetFrame:GetTop()
    self.scrollBox:ScrollToOffset((parentTop - targetTop) + 1)
  end)

  if self.nextIndex == self.indexFrame then
    indexButton:SetPoint("TOPLEFT", self.indexFrame, "TOPLEFT", 5, -10)
  else
    indexButton:SetPoint("TOPLEFT", self.nextIndex, "BOTTOMLEFT", 0, -5)
  end
  table.insert(self.sections, {point = point, button = indexButton})
  self.nextIndex = indexButton
end

---@private
---@param t Frame
---@param container Frame
---@param indent? number
function stackedLayout:alignFrame(t, container, indent)
  indent = indent or 0
  if t == self.targetFrame then
    if self.index then
      container:SetPoint("TOPLEFT", t, "TOPLEFT", self.indexFrame:GetWidth() + 10 + indent, -10)
    else
      container:SetPoint("TOPLEFT", t, "TOPLEFT", 10 + indent, -10)
    end
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
---@param color? table
---@return FontString
function stackedLayout:createTitle(container, title, color)
  local titleFont = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if color then
    titleFont:SetTextColor(unpack(color))
  else
    titleFont:SetTextColor(1, 1, 1)
  end
  titleFont:SetJustifyH("LEFT")
  titleFont:SetText(title)
  return titleFont
end

---@private
---@param container Frame
---@param description string
---@param color? table
---@return FontString
function stackedLayout:createDescription(container, description, color)
  local descriptionFont = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if color then
    descriptionFont:SetTextColor(unpack(color))
  else
    descriptionFont:SetTextColor(1, 1, 1)
  end
  descriptionFont:SetJustifyH("LEFT")
  descriptionFont:SetText(description)
  descriptionFont:SetWordWrap(true)
  descriptionFont:SetNonSpaceWrap(true)
  return descriptionFont
end

---@private
---@param parent Frame
---@return Frame
function stackedLayout:createDividerLineMiddle(parent)
  local container = CreateFrame("Frame", nil, parent)
  local white = CreateColor(1, 1, 1, 1)
  local faded = CreateColor(1, 1, 1, 0.2)
  local left = container:CreateTexture(nil, "ARTWORK")

  left:SetGradient("HORIZONTAL", faded, white)
  left:SetColorTexture(1, 1, 1, 1)
  left:SetHeight(1)
  left:SetWidth(100)

  local middle = container:CreateTexture(nil, "ARTWORK")
  middle:SetColorTexture(1, 1, 1, 1)
  middle:SetHeight(1)

  local right = container:CreateTexture(nil, "ARTWORK")
  right:SetGradient("HORIZONTAL", white, faded)
  right:SetColorTexture(1, 1, 1, 1)
  right:SetHeight(1)
  right:SetWidth(100)

  left:SetPoint("LEFT", container, "LEFT")
  middle:SetPoint("LEFT", left, "RIGHT")
  middle:SetPoint("RIGHT", right, "LEFT")
  right:SetPoint("RIGHT", container, "RIGHT")
  container:SetHeight(3)
  return container
end

function stackedLayout:createDividerLineLeft(parent)
  local container = CreateFrame("Frame", nil, parent)
  local white = CreateColor(1, 1, 1, 1)
  local faded = CreateColor(1, 1, 1, 0.2)

  local left = container:CreateTexture(nil, "ARTWORK")
  left:SetColorTexture(1, 1, 1, 1)
  left:SetHeight(1)

  local right = container:CreateTexture(nil, "ARTWORK")
  right:SetGradient("HORIZONTAL", white, faded)
  right:SetColorTexture(1, 1, 1, 1)
  right:SetHeight(1)
  right:SetWidth(100)

  left:SetPoint("LEFT", container, "LEFT")
  right:SetPoint("LEFT", left, "RIGHT")
  right:SetPoint("RIGHT", container, "RIGHT")

  container:SetHeight(3)
  return container
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

  local div = self:createDividerLineLeft(container)
  div:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  div:SetPoint("RIGHT", container, "RIGHT", -10, 0)

  container:SetHeight(container.title:GetHeight() + container.description:GetHeight() + 18)

  self:addIndex(opts.title, container)
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
  local div = self:createDividerLineMiddle(container)
  div:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  div:SetPoint("RIGHT", container, "RIGHT", -10, 0)
  container:SetHeight(container.title:GetLineHeight() + container.description:GetLineHeight() + 33)
  self:addIndex(opts.title, container, true)
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
  addon.SetScript(container.checkbox, "OnClick", function(ctx)
    opts.setValue(ctx, container.checkbox:GetChecked())
  end)
  container.checkbox:SetChecked(opts.getValue(context:New('Checkbox_Load')))

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("LEFT", container.checkbox, "RIGHT", 5, 0)
  container.title:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
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

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
  container.dropdown:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container.dropdown:SetupMenu(function(_, root)
    for _, item in ipairs(opts.items) do
      root:CreateCheckbox(item, function(value)
        local ctx = context:New('Dropdown_Get')
        return opts.getValue(ctx, value)
      end,
      function(value)
        local ctx = context:New('Dropdown_Set')
        opts.setValue(ctx, value)
      end, item)
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

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.slider = CreateFrame("Slider", nil, container, "UISliderTemplate") --[[@as Slider]]
  container.slider:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.slider:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  container.slider:SetOrientation("HORIZONTAL")
  container.slider:SetHeight(20)
  container.slider:SetMinMaxValues(opts.min, opts.max)
  container.slider:SetValueStep(opts.step)
  container.slider:SetObeyStepOnDrag(true)
  addon.SetScript(container.slider, "OnValueChanged", function(ctx, _, value, user)
    opts.setValue(ctx, value)
    if user then
      container.input:SetText(tostring(value))
    end
  end)

  container.input = CreateFrame("EditBox", nil, container, "InputBoxTemplate") --[[@as EditBox]]
  container.input:SetSize(50, 20)
  container.input:SetPoint("TOP", container.slider, "BOTTOM", 0, -5)
  container.input:SetNumeric(true)
  container.input:SetAutoFocus(false)
  addon.SetScript(container.input, "OnEditFocusLost", function(ctx)
    local value = tonumber(container.input:GetText())
    if value then
      if value < opts.min then
        value = opts.min
      elseif value > opts.max then
        value = opts.max
      end
      container.slider:SetValue(value)
      container.input:SetText(tostring(value))
    else
      value = opts.min
    end
    container.input:SetText(tostring(container.slider:GetValue()))
  end)
  addon.SetScript(container.input, "OnTextChanged", function(ctx, _, user)
    if user then
      local value = tonumber(container.input:GetText())
      if value then
        if value < opts.min then
          value = opts.min
        elseif value > opts.max then
          value = opts.max
        end
        container.slider:SetValue(value)
        container.input:SetText(tostring(value))
      else
        value = opts.min
      end
    else
      container.input:SetText(tostring(container.slider:GetValue()))
    end
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