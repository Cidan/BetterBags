local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class FormLayouts: AceModule
local layouts = addon:GetModule('FormLayouts')

---@class (exact) Form: AceModule
local form = addon:NewModule('Form')

---@class (exact) FormFrame: AceModule
---@field layout FormLayout
---@field frame Frame This is the container frame for the form window.
---@field ScrollBox WowScrollBox This is the scroll box that contains the inner frame.
---@field ScrollBar MinimalScrollBar This is the scrollbar that controls the scroll box.
---@field inner Frame This is the inner frame that contains the form elements.
local formFrame = {}

---@class FormCreateOptions
---@field title string
---@field layout FormLayoutType

local formCounter = 0
-- Create will create a new form with the given layout.
---@param opts FormCreateOptions
---@return FormFrame
function form:Create(opts)
  local l = setmetatable({}, {__index = formFrame}) --[[@as FormFrame]]
  l.frame = CreateFrame('Frame', format("BetterBagsForm%d%s", formCounter, opts.title), UIParent)
  formCounter = formCounter + 1
  l.frame:SetFrameStrata("DIALOG")

  l.ScrollBox = CreateFrame("Frame", nil, l.frame, "WowScrollBox") --[[@as WowScrollBox]]
  l.ScrollBox:SetPoint("TOPLEFT", l.frame, "TOPLEFT", 4, -22)
  l.ScrollBox:SetPoint("BOTTOMRIGHT", l.frame, "BOTTOMRIGHT", 0, 4)

  l.ScrollBar = CreateFrame("EventFrame", nil, l.ScrollBox, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  l.ScrollBar:SetPoint("TOPLEFT", l.frame, "TOPRIGHT", -16, -28)
  l.ScrollBar:SetPoint("BOTTOMLEFT", l.frame, "BOTTOMRIGHT", -16, 6)

  l.ScrollBox:SetInterpolateScroll(true)
  l.ScrollBar:SetInterpolateScroll(true)

  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(40)

  l.inner = CreateFrame('Frame', nil, l.ScrollBox)
  l.inner.scrollable = true

  l.frame:EnableMouse(true)
  l.frame:SetMovable(true)
  l.frame:SetScript("OnMouseDown", l.frame.StartMoving)
  l.frame:SetScript("OnMouseUp", l.frame.StopMovingOrSizing)

  ScrollUtil.InitScrollBoxWithScrollBar(l.ScrollBox, l.ScrollBar, view)
  themes:RegisterFlatWindow(l.frame, opts.title)

  if opts.layout == const.FORM_LAYOUT.STACKED then
    l.layout = layouts:NewStackedLayout(l.inner)
  end

  return l
end

function formFrame:Refresh()
  self.inner:SetHeight(self.layout.height + 50)
  self.inner:SetWidth(self.ScrollBox:GetWidth() - 18)
end

---@param opts FormSectionOptions
function formFrame:AddSection(opts)
  self.layout:AddSection(opts)
  self:Refresh()
end

function formFrame:AddInputBoxGroup(opts)
end

---@param opts FormDropdownOptions
function formFrame:AddDropdown(opts)
  self.layout:AddDropdown(opts)
  self:Refresh()
end

function formFrame:AddTextArea(opts)
end

---@param opts FormCheckboxOptions
function formFrame:AddCheckbox(opts)
  self.layout:AddCheckbox(opts)
  self:Refresh()
end

function formFrame:AddButtonGroup(opts)
end

function formFrame:Show()
  self.frame:Show()
  self.frame:SetSize(600, 800)
  self.frame:SetPoint("CENTER")
end

function form:OnEnable()
  local f = form:Create({
    title = 'BetterBags Settings',
    layout = const.FORM_LAYOUT.STACKED
  })
 f:AddSection({
   title = 'General',
   description = 'General settings for BetterBags.',
 })
  f:AddCheckbox({
   title = 'Enable In-Bag Search',
   description = 'If enabled, a search bar will appear at the top of your bags.',
  })
  f:AddCheckbox({
    title = 'Enable Enter to Make Category',
    description = 'If enabled, pressing Enter with a search query will open the make category menu.',
  })
  f:AddCheckbox({
    title = 'Enable Category Sell and Deposit',
    description = 'If enabled, right-clicking a category header at an NPC shop will sell all its contents, or deposit to bank.',
  })
  f:AddCheckbox({
    title = 'Show Blizzard Bag Button',
    description = 'Show or hide the default Blizzard bag button.',
  })

  local holder = "None"
  f:AddDropdown({
    title = 'Upgrade Icon Provider',
    description = 'Select the icon provider for item upgrades.',
    items = {'None', 'BetterBags'},
    getValue = function(value)
      return value == holder
    end,
    setValue = function(value)
      holder = value
    end,
  })

  f:AddSection({
    title = 'Backpack',
    description = 'Settings for the player backpack bag.',
  })
  f:AddCheckbox({
    title = 'All Items Recent',
    description = 'All new items you loot, pickup, or move into the bag will be marked as recent.',
  })
  f:Show()
end