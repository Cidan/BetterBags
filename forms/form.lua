local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class FormLayouts: AceModule
local layouts = addon:GetModule('FormLayouts')

---@class WindowModule: AceModule
local window = addon:GetModule('Window')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class (exact) Form: AceModule
local form = addon:NewModule('Form')

-- A form is a Panel window (window/window.lua) whose content box holds the form's scroll box
-- and index. Its owner gives it a fixed size (GetFrame():SetSize), which the player cannot
-- change; the window moves it, fades it, and draws its chrome from the theme.
---@class (exact) FormFrame: AceModule
---@field layout FormLayout
---@field window BetterBagsWindow The form's window.
---@field frame Frame This is the container frame for the form window.
---@field ScrollBox WowScrollBox This is the scroll box that contains the inner frame.
---@field ScrollBar MinimalScrollBar This is the scrollbar that controls the scroll box.
---@field inner Frame This is the inner frame that contains the form elements.
local formFrame = {}
addon:GetModule('Perf'):RegisterPrototype(formFrame, 'FormFrame')

---@class FormCreateOptions
---@field title string
---@field layout FormLayoutType
---@field index boolean
---@field tabbed boolean

local formCounter = 0
-- Create will create a new form with the given layout.
---@param opts FormCreateOptions
---@return FormFrame
function form:Create(opts)
  local l = setmetatable({}, {__index = formFrame}) --[[@as FormFrame]]
  l.window = window:Create({
    Kind = "Panel",
    Name = format("BetterBagsForm%d%s", formCounter, opts.title),
    Title = opts.title,
    Strata = "DIALOG",
    Level = 500,
    SizeMode = function() return "window" end,
    Resizable = false,
    Opacity = function()
      return database:GetBagSizeInfo(const.BAG_KIND.BACKPACK, database:GetBagView(const.BAG_KIND.BACKPACK)).opacity
    end,
  })
  l.frame = l.window.frame
  formCounter = formCounter + 1
  local content = l.window.content

  l.ScrollBox = CreateFrame("Frame", nil, content, "WowScrollBox") --[[@as WowScrollBox]]
  l.ScrollBox:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  l.ScrollBox:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

  l.ScrollBar = CreateFrame("EventFrame", nil, l.ScrollBox, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  l.ScrollBar:SetPoint("TOPLEFT", content, "TOPRIGHT", -16, -6)
  l.ScrollBar:SetPoint("BOTTOMLEFT", content, "BOTTOMRIGHT", -16, 2)

  l.ScrollBox:SetInterpolateScroll(true)
  l.ScrollBar:SetInterpolateScroll(true)
  l.ScrollBar:SetHideIfUnscrollable(true)

  l.inner = CreateFrame('Frame', nil, l.ScrollBox)
  l.inner:SetPoint("TOPLEFT", l.ScrollBox)
  l.inner:SetPoint("TOPRIGHT", l.ScrollBox)
  l.inner.scrollable = true

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(60)

  ScrollUtil.InitScrollBoxWithScrollBar(l.ScrollBox, l.ScrollBar, view)

  -- For tabbed mode, we need to ensure scrolling works properly
  l.view = view

  if opts.layout == const.FORM_LAYOUT.STACKED then
    l.layout = layouts:NewStackedLayout(l.inner, content, l.ScrollBox, opts.index, opts.tabbed)
  end
  return l
end

function formFrame:Resize()
  if self.layout.tabbed then
    -- Update all tab container heights to their calculated values
    for i, container in ipairs(self.layout.tabContainers) do
      local tabHeight = (self.layout.tabHeights[i] or 0) + 25
      container:SetHeight(tabHeight)
    end

    -- Set inner frame to the ACTIVE tab's height, not the max
    -- This allows the scroll area to resize dynamically when switching tabs
    local activeTabHeight = (self.layout.tabHeights[self.layout.activeTab] or 0) + 25
    self.inner:SetHeight(activeTabHeight)
    self.inner:SetWidth(self.ScrollBox:GetWidth() - 18)

    -- Force a layout update by reading the height, then notify scroll box
    local _ = self.inner:GetHeight()
    if self.ScrollBox and self.ScrollBox.FullUpdate then
      self.ScrollBox:FullUpdate(true)
    end
  else
    self.inner:SetHeight(self.layout.height + 25)
    self.inner:SetWidth(self.ScrollBox:GetWidth() - 18)
  end
end

function formFrame:ReloadAllFormElements()
  self.layout:ReloadAllFormElements()
end

---@param opts FormSectionOptions
function formFrame:AddSection(opts)
  self.layout:AddSection(opts)
  self:Resize()
end

--- Adds a subsection header inline in the pane content (title, description, divider).
--- Does NOT add to the sidebar index. Use for visual grouping within a tab.
---@param opts FormInlineSubSectionOptions
function formFrame:AddInlineSubSection(opts)
  self.layout:AddInlineSubSection(opts)
end

--- Adds a navigation entry to the sidebar index only.
--- Does NOT render any content in the pane. Use for sub-navigation items.
---@param opts FormSubIndexOptions
function formFrame:AddSubIndex(opts)
  self.layout:AddSubIndex(opts)
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

---@param opts FormPaneLinkOptions
function formFrame:AddPaneLink(opts)
  self.layout:AddPaneLink(opts)
  self:Resize()
end

---@param paneIndex number
function formFrame:ShowPane(paneIndex)
  self.layout:ShowPane(paneIndex)
end

function formFrame:HidePane()
  self.layout:HidePane()
end

---@return boolean
function formFrame:IsPaneActive()
  return self.layout:IsPaneActive()
end

---@return Frame
function formFrame:GetFrame()
  return self.frame
end

function formFrame:Show()
  self.window:Show(context:New('Form_Show'))
  self.layout:UpdateUnderline()
end

function formFrame:Hide()
  self.window:Hide(context:New('Form_Hide'))
end
