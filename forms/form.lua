local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Bucket: AceModule
local bucket = addon:GetModule('Bucket')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class FormLayouts: AceModule
local layouts = addon:GetModule('FormLayouts')

---@class (exact) Form: AceModule
local form = addon:NewModule('Form')

---@class (exact) FormFrame: AceModule
---@field layout FormLayout
---@field frame Frame This is the container frame for the form window.
---@field fadeIn AnimationGroup
---@field fadeOut AnimationGroup
---@field ScrollBox WowScrollBox This is the scroll box that contains the inner frame.
---@field ScrollBar MinimalScrollBar This is the scrollbar that controls the scroll box.
---@field inner Frame This is the inner frame that contains the form elements.
local formFrame = {}

---@class FormCreateOptions
---@field title string
---@field layout FormLayoutType
---@field index boolean

local formCounter = 0
-- Create will create a new form with the given layout.
---@param opts FormCreateOptions
---@return FormFrame
function form:Create(opts)
  local l = setmetatable({}, {__index = formFrame}) --[[@as FormFrame]]
  l.frame = CreateFrame('Frame', format("BetterBagsForm%d%s", formCounter, opts.title), UIParent)
  formCounter = formCounter + 1

  l.frame:SetFrameStrata("DIALOG")
  l.frame:SetFrameLevel(500)

  l.ScrollBox = CreateFrame("Frame", nil, l.frame, "WowScrollBox") --[[@as WowScrollBox]]
  l.ScrollBox:SetPoint("TOPLEFT", l.frame, "TOPLEFT", 4, -22)
  l.ScrollBox:SetPoint("BOTTOMRIGHT", l.frame, "BOTTOMRIGHT", 0, 4)

  l.ScrollBar = CreateFrame("EventFrame", nil, l.ScrollBox, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  l.ScrollBar:SetPoint("TOPLEFT", l.frame, "TOPRIGHT", -16, -28)
  l.ScrollBar:SetPoint("BOTTOMLEFT", l.frame, "BOTTOMRIGHT", -16, 6)

  l.ScrollBox:SetInterpolateScroll(true)
  l.ScrollBar:SetInterpolateScroll(true)
  l.ScrollBar:SetHideIfUnscrollable(true)

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(60)

  l.inner = CreateFrame('Frame', nil, l.ScrollBox)
  l.inner.scrollable = true

  l.frame:EnableMouse(true)
  l.frame:SetMovable(true)
  l.frame:SetScript("OnMouseDown", l.frame.StartMoving)
  l.frame:SetScript("OnMouseUp", l.frame.StopMovingOrSizing)

  ScrollUtil.InitScrollBoxWithScrollBar(l.ScrollBox, l.ScrollBar, view)
  themes:RegisterSimpleWindow(l.frame, opts.title)

  if opts.layout == const.FORM_LAYOUT.STACKED then
    l.layout = layouts:NewStackedLayout(l.inner, l.frame, l.ScrollBox, opts.index)
  end

  l.fadeIn, l.fadeOut = animations:AttachFadeGroup(l.frame)
  l.frame:Hide()
  return l
end

function formFrame:Resize()
  self.inner:SetHeight(self.layout.height + 25)
  self.inner:SetWidth(self.ScrollBox:GetWidth() - 18)
end

function formFrame:ReloadAllFormElements()
  self.layout:ReloadAllFormElements()
end

---@param opts FormSectionOptions
function formFrame:AddSection(opts)
  self.layout:AddSection(opts)
  self:Resize()
end

---@param opts FormSubSectionOptions
function formFrame:AddSubSection(opts)
  self.layout:AddSubSection(opts)
end

---@param opts FormSliderOptions
function formFrame:AddSlider(opts)
  self.layout:AddSlider(opts)
  self:Resize()
end

---@param opts FormInputBoxOptions
function formFrame:AddInputBox(opts)
  self.layout:AddInputBox(opts)
  self:Resize()
end

---@param opts FormDropdownOptions
function formFrame:AddDropdown(opts)
  self.layout:AddDropdown(opts)
  self:Resize()
end

---@param opts FormTextAreaOptions
function formFrame:AddTextArea(opts)
  self.layout:AddTextArea(opts)
  self:Resize()
end

---@param opts FormCheckboxOptions
function formFrame:AddCheckbox(opts)
  self.layout:AddCheckbox(opts)
  self:Resize()
end

---@param opts FormButtonGroupOptions
function formFrame:AddButtonGroup(opts)
  self.layout:AddButtonGroup(opts)
  self:Resize()
end

---@param opts FormColorOptions
function formFrame:AddColor(opts)
  self.layout:AddColor(opts)
  self:Resize()
end

---@param opts FormLabelOptions
function formFrame:AddLabel(opts)
  self.layout:AddLabel(opts)
  self:Resize()
end

---@param opts FormItemListOptions
function formFrame:AddItemList(opts)
  self.layout:AddItemList(opts)
  self:Resize()
end

---@return Frame
function formFrame:GetFrame()
  return self.frame
end

function formFrame:Show()
  self.fadeIn:Play()
  self.layout:UpdateUnderline()
end

function formFrame:Hide()
  self.fadeOut:Play()
end