local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Form: AceModule
local form = addon:GetModule('Form')

---@class NewSectionC: AceModule
---@field form FormFrame
---@field currentFilter CustomCategoryFilter
local newSectionC = addon:NewModule('NewSectionC')

function newSectionC:OnEnable()
  self.currentFilter = {
    name = '',
    searchCategory = {
      query = '',
    },
    priority = 100,
    color = {
      [1] = 1,
      [2] = 1,
      [3] = 1,
      [4] = 1,
    }
  }
  self.form = form:Create({
    title = 'New Section',
    layout = const.FORM_LAYOUT.STACKED,
    index = false
  })

  self.form:GetFrame():SetSize(600, 700)

  self.form:AddInputBox({
    title = 'Name',
    description = 'The name of the section as it will appear in your inventory.',
    getValue = function()
      return self.currentFilter.name
    end,
    setValue = function(_, value)
      self.currentFilter.name = value
    end,
  })

  self.form:AddColor({
    title = 'Color',
    description = 'The color of the section.',
    getValue = function()
      return {
        red = self.currentFilter.color[1],
        green = self.currentFilter.color[2],
        blue = self.currentFilter.color[3],
        alpha = self.currentFilter.color[4],
      }
    end,
    setValue = function(_, value)
      self.currentFilter.color = {
        [1] = value.red,
        [2] = value.green,
        [3] = value.blue,
        [4] = value.alpha,
      }
    end,
  })

  self.form:AddTextArea({
    title = 'Query',
    description = 'The query to use to filter items for this section.',
    getValue = function()
      return self.currentFilter.searchCategory.query
    end,
    setValue = function(_, value)
      self.currentFilter.searchCategory.query = value
    end,
  })

  self.form:AddSlider({
    title = 'Priority',
    description = 'Smaller numbers mean that matching items will sort into this section first.',
    getValue = function()
      return self.currentFilter.priority
    end,
    setValue = function(_, value)
      self.currentFilter.priority = value
    end,
    min = 1,
    max = 100,
    step = 1,
  })

  self.form:AddButtonGroup({
    ButtonOptions = {
      { title = 'Cancel', onClick = function() end },
      { title = 'Save', onClick = function() end },
    },
    rightAlign = true
  })
end

---@param filter CustomCategoryFilter
---@param parent Frame
function newSectionC:Open(filter, parent)
  if self.currentFilter and self.currentFilter.name == filter.name then
    self.currentFilter = nil
    self.form:Hide()
    return
  end
  self.currentFilter = CopyTable(filter)
  self.currentFilter.color = self.currentFilter.color or {
    [1] = 1,
    [2] = 1,
    [3] = 1,
    [4] = 1,
  }
  self.currentFilter.searchCategory = self.currentFilter.searchCategory or {query = ''}
  self.form:GetFrame():ClearAllPoints()
  self.form:GetFrame():SetPoint("TOPRIGHT", parent, "TOPLEFT", -10, 0)
  self.form:ReloadAllFormElements()
  self.form:Show()
end
