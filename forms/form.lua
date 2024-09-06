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
  view:SetPanExtent(60)

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

---@param opts FormSubSectionOptions
function formFrame:AddSubSection(opts)
  self.layout:AddSubSection(opts)
end

---@param opts FormSliderOptions
function formFrame:AddSlider(opts)
  self.layout:AddSlider(opts)
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

  local fakedb = {
    ['upgradeIconProvider'] = 'BetterBags',
    ['backpackSectionOrder'] = 'Alphabetically',
    ['backpackItemOrder'] = 'Alphabetically',
    ['newItemsDuration'] = 30,
  }
  f:AddDropdown({
    title = 'Upgrade Icon Provider',
    description = 'Select the icon provider for item upgrades.',
    items = {'None', 'BetterBags'},
    getValue = function(value)
      return value == fakedb['upgradeIconProvider']
    end,
    setValue = function(value)
      fakedb['upgradeIconProvider'] = value
    end,
  })

  f:AddSlider({
    title = 'New Item Duration',
    description = 'The duration in minutes that an item is considered new.',
    min = 1,
    max = 120,
    step = 1,
    getValue = function(ctx)
      return fakedb['newItemsDuration']
    end,
    setValue = function(ctx, value)
      fakedb['newItemsDuration'] = value
    end,
  })

  f:AddSection({
    title = 'Backpack',
    description = 'Settings for the player backpack bag.',
  })

  f:AddDropdown({
    title = 'Section Order',
    description = 'The order of sections in the backpack when not pinned.',
    items = {'Alphabetically', 'Size Descending', 'Size Ascending'},
    getValue = function(value)
      return value == fakedb['backpackSectionOrder']
    end,
    setValue = function(value)
      fakedb['backpackSectionOrder'] = value
    end,
  })

  f:AddDropdown({
    title = 'Item Order',
    description = 'The default order of items within each section.',
    items = {'Alphabetically', 'Quality', 'Item Level'},
    getValue = function(value)
      return value == fakedb['backpackItemOrder']
    end,
    setValue = function(value)
      fakedb['backpackItemOrder'] = value
    end,
  })

  f:AddSubSection({
    title = 'Item Stacking',
    description = 'Settings for item stacking in the backpack.',
  })
  f:AddCheckbox({
    title = 'All Items Recent',
    description = 'All new items you loot, pickup, or move into the bag will be marked as recent.',
  })

  f:AddCheckbox({
    title = 'Flash Stacks',
    description = 'When a stack of items gets a new item, the stack will flash.',
  })

  f:AddCheckbox({
    title = 'Merge Stacks',
    description = 'Stackable items will merge into a single item button in your backpack.',
  })

  f:AddCheckbox({
    title = 'Merge Unstackable',
    description = 'Unstackable items, such as armor and weapons, will merge into a single item button in your backpack.',
  })

  f:AddCheckbox({
    title = "Don't Merge Partial Stacks",
    description = 'Partial stacks of items will not merge with other partial or full stacks.',
  })

  f:AddCheckbox({
    title = "Split Transmogged Items",
    description = 'Transmogged items will be split into a separate, stackable button in your backpack.',
  })

  f:AddCheckbox({
    title = 'Unmerge on Interactions',
    description = 'When you interact a vendor, mailbox, auction house, etc, all merged items will unmerge.',
  })


  f:AddSubSection({
    title = 'Item Level',
    description = 'Settings for item level in the backpack.',
  })

  f:AddCheckbox({
    title = 'Show Item Level',
    description = 'Show the item level on item buttons in the backpack.',
  })

  f:AddCheckbox({
    title = 'Show Item Level Color',
    description = 'Show the item level in color on item buttons in the backpack.',
  })


  f:AddSubSection({
    title = 'Display',
    description = 'Settings that adjust layout and visual aspects of the backpack.',
  })

  f:AddCheckbox({
    title = 'Show Full Section Names',
    description = 'Show the full section names for each section and do not cut them off.',
  })

  f:AddCheckbox({
    title = 'Show All Free Space Slots',
    description = 'Show all free space slots, individually, at the bottom of the backpack.',
  })

  f:AddCheckbox({
    title = 'Extra Glowy Item Buttons',
    description = 'Item buttons will have an enhanced glow effect using the item quality color.',
  })

  f:Show()
end