local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

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

---@param opts FormSectionOptions
function stackedLayout:AddSection(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSection]]
  if t == self.targetFrame then
    container:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -10)
    container:SetPoint("TOPRIGHT", t, "TOPRIGHT", -20, -10)
    self.height = self.height + 10
  else
    container:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -20)
    container:SetPoint("RIGHT", self.targetFrame, "RIGHT", -20, 0)
    self.height = self.height + 20
  end

  container.title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  container.title:SetTextColor(1, 1, 1)
  container.title:SetJustifyH("LEFT")
  container.title:SetText(opts.title)
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT")

  container.description = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  container.description:SetTextColor(1, 1, 1)
  container.description:SetJustifyH("LEFT")
  container.description:SetText(opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
  container:SetHeight(container.title:GetHeight() + container.description:GetHeight() + 10)
  self.sections[opts.title] = container

  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end

function stackedLayout:AddCheckbox(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormCheckbox]]
  if t == self.targetFrame then
    container:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -10)
    container:SetPoint("TOPRIGHT", t, "TOPRIGHT", -20, -10)
    self.height = self.height + 10
  else
    container:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -20)
    container:SetPoint("RIGHT", self.targetFrame, "RIGHT", -20, 0)
    self.height = self.height + 20
  end

  container.checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate") --[[@as CheckButton]]
  container.checkbox:SetPoint("TOPLEFT", container, "TOPLEFT")

  container.title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  container.title:SetTextColor(1, 1, 1)
  container.title:SetJustifyH("LEFT")
  container.title:SetText(opts.title)
  container.title:SetPoint("LEFT", container.checkbox, "RIGHT", 5, 0)
  container.title:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container.description = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  container.description:SetTextColor(1, 1, 1)
  container.description:SetJustifyH("LEFT")
  container.description:SetWordWrap(true)
  container.description:SetNonSpaceWrap(true)
  container.description:SetText(opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
  container.description:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  container.description:GetLineHeight()
  container.description:GetStringHeight()

  container:SetHeight(container.title:GetLineHeight() + container.description:GetLineHeight() + 25)
  self.nextFrame = container
  self.height = self.height + container:GetHeight()
end

---@param opts FormDropdownOptions
function stackedLayout:AddDropdown(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormDropdown]]
  if t == self.targetFrame then
    container:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -10)
    container:SetPoint("TOPRIGHT", t, "TOPRIGHT", -20, -10)
    self.height = self.height + 10
  else
    container:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -20)
    container:SetPoint("RIGHT", self.targetFrame, "RIGHT", -20, 0)
    self.height = self.height + 20
  end

  container.title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  container.title:SetTextColor(1, 1, 1)
  container.title:SetJustifyH("LEFT")
  container.title:SetText(opts.title)
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  container.description:SetTextColor(1, 1, 1)
  container.description:SetJustifyH("LEFT")
  container.description:SetText(opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate") --[[@as Button]]
  container.dropdown:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  local getValue = function(value)
    return value == "None"
  end
  local setValue = function(value)
  end
  container.dropdown:SetupMenu(function(dropdown, rootDescription)
    for _, item in ipairs(opts.items) do
      rootDescription:CreateCheckbox(item, getValue, setValue, item)
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
