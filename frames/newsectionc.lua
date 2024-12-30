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

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class NewSectionC: AceModule
---@field form FormFrame
---@field currentFilter CustomCategoryFilter
---@field openedName string
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
    },
    allowBlizzardItems = false,
    itemList = {},
  }
  self.form = form:Create({
    title = 'Section Editor',
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
    description = 'The color of the section title as it appears in your inventory.',
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

  self.form:AddCheckbox({
    title = 'Allow Blizzard Items',
    description = 'If this is a "built in" section, allow items from Blizzard to be added to this section.',
    getValue = function()
      return self.currentFilter.allowBlizzardItems
    end,
    setValue = function(_, value)
      self.currentFilter.allowBlizzardItems = value
    end,
  })

  self.form:AddItemList({
    title = 'Items',
    description = 'The items that will be added to this section.',
    getValue = function()
      ---@type FormItemListItem[]
      local items = {}
      for id in pairs(self.currentFilter.itemList) do
        table.insert(items, {
          id = id,
          category = self.currentFilter.name,
        })
      end
      return items
    end,
    setValue = function(_, value)
      self.currentFilter.itemList = {}
      for _, item in pairs(value) do
        self.currentFilter.itemList[item.id] = true
      end
    end,
  })

  self.form:AddButtonGroup({
    ButtonOptions = {
      { title = 'Cancel', onClick = function()
        self.currentFilter = nil
        self.openedName = nil
        self.form:Hide()
      end },
      { title = 'Save', onClick = function(ctx)
        self:Save(ctx)
        if self.openedName ~= self.currentFilter.name and self.openedName ~= nil and self.openedName ~= "" then
          categories:DeleteCategory(ctx, self.openedName)
        end
        self.openedName = nil
        self.currentFilter = nil
        events:SendMessage(ctx, 'bags/FullRefreshAll')
        self.form:Hide()
      end },
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
  self.openedName = filter.name
  self.currentFilter.color = self.currentFilter.color or {
    [1] = 1,
    [2] = 1,
    [3] = 1,
    [4] = 1,
  }
  self.currentFilter.searchCategory = self.currentFilter.searchCategory or {query = ''}
  self.currentFilter.itemList = self.currentFilter.itemList or {}
  self.form:GetFrame():ClearAllPoints()
  self.form:GetFrame():SetPoint("TOPRIGHT", parent, "TOPLEFT", -10, 0)
  self.form:ReloadAllFormElements()
  self.form:Show()
end

---@param ctx Context
function newSectionC:Save(ctx)
  categories:CreateCategory(ctx, {
    name = self.currentFilter.name,
    priority = self.currentFilter.priority,
    color = self.currentFilter.color,
    searchCategory = self.currentFilter.searchCategory,
    allowBlizzardItems = self.currentFilter.allowBlizzardItems,
  }, true)
end
