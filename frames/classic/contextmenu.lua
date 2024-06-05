---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ContextMenu: AceModule
---@field frame Frame
local contextMenu = addon:NewModule('ContextMenu')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class SliderFrame: AceModule
local slider = addon:GetModule('Slider')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

---@class (exact) MenuList
---@field text string
---@field value? any
---@field checked? boolean|function
---@field isNotRadio? boolean
---@field isTitle? boolean
---@field disabled? boolean
---@field tooltipTitle? string
---@field tooltipText? string
---@field func? function
---@field notCheckable? boolean
---@field hasArrow? boolean
---@field menuList? MenuList[]
---@field keepShownOnClick? boolean
---@field tooltipOnButton? boolean
local menuListProto = {}

function contextMenu:OnInitialize()
  --self:CreateContext()
end

function contextMenu:OnEnable()
  local frame = LibDD:Create_UIDropDownMenu("BetterBagsContextMenu", UIParent)
  LibDD:EasyMenu_Initialize(frame, 4, {})
  self.frame = frame
end

---@param menuList MenuList[]
function contextMenu:Show(menuList)
  LibDD:EasyMenu(menuList, self.frame, 'cursor', 0, 0, 'MENU')
  events:SendMessage('context/show')
end

function contextMenu:Hide()
  LibDD:HideDropDownMenu(1)
  events:SendMessage('context/hide')
end
--[[
local function addDivider(menuList)
  table.insert(menuList, {
    text = "",
    isTitle = true,
    hasArrow = false,
    notCheckable = true,
    iconOnly = true,
    isUninteractable = true,
    icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
    iconInfo = {
      tCoordLeft = 0,
			tCoordRight = 1,
			tCoordTop = 0,
			tCoordBottom = 1,
			tSizeX = 0,
			tSizeY = 8,
			tFitDropDownSizeX = true
    },
  })
end
]]--
---@param menu MenuList[]
local function enableTooltips(menu)
  for _, m in ipairs(menu) do
    m.tooltipOnButton = true
    if m.menuList then
      enableTooltips(m.menuList)
    end
  end
end

---@param bag Bag
---@return MenuList[]
function contextMenu:CreateContextMenu(bag)
  ---@type MenuList[]
  local menuList = {}

  -- Context Menu title.
  table.insert(menuList, {
    --@debug@
		text = addonName..' Dev Mode',
		--@end-debug@
		--[===[@non-debug@
		text = addonName..' @project-version@',
		--@end-non-debug@]===]
    isTitle = true,
    notCheckable = true
  })

  -- View menu for switching between one bag and section grid.
  table.insert(menuList, {
    text = L:G("View"),
    hasArrow = true,
    notCheckable = true,
    menuList = {
      {
        text = L:G("One Bag"),
        keepShownOnClick = false,
        checked = function()
          if database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
            return database:GetPreviousView(bag.kind) == const.BAG_VIEW.ONE_BAG
          end
          return database:GetBagView(bag.kind) == const.BAG_VIEW.ONE_BAG
        end,
        tooltipTitle = L:G("One Bag"),
        tooltipText = L:G("This view will display all items in a single bag, regardless of category."),
        func = function()
          contextMenu:Hide()
          if database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
            database:SetPreviousView(bag.kind, const.BAG_VIEW.ONE_BAG)
          else
            database:SetPreviousView(bag.kind, const.BAG_VIEW.ONE_BAG)
            database:SetBagView(bag.kind, const.BAG_VIEW.ONE_BAG)
            events:SendMessage('bags/FullRefreshAll')
          end
        end
      },
      {
        text = L:G("Section Grid"),
        keepShownOnClick = false,
        checked = function()
          if database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
            return database:GetPreviousView(bag.kind) == const.BAG_VIEW.SECTION_GRID
          end
          return database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_GRID
        end,
        tooltipTitle = L:G("Section Grid"),
        tooltipText = L:G("This view will display items in sections, which are categorized by type, expansion, trade skill, and more."),
        func = function()
          contextMenu:Hide()
          if database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
            database:SetPreviousView(bag.kind, const.BAG_VIEW.SECTION_GRID)
          else
            database:SetPreviousView(bag.kind, const.BAG_VIEW.SECTION_GRID)
            database:SetBagView(bag.kind, const.BAG_VIEW.SECTION_GRID)
            events:SendMessage('bags/FullRefreshAll')
          end
        end
      },
      {
        text = L:G("List"),
        keepShownOnClick = false,
        checked = function()
          if database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
            return database:GetPreviousView(bag.kind) == const.BAG_VIEW.LIST
          end
          return database:GetBagView(bag.kind) == const.BAG_VIEW.LIST
        end,
        tooltipTitle = L:G("List"),
        tooltipText = L:G("This view will display items in a list, which is categorized by type, expansion, trade skill, and more."),
        func = function()
          contextMenu:Hide()
          if database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
            database:SetPreviousView(bag.kind, const.BAG_VIEW.LIST)
          else
            database:SetPreviousView(bag.kind, const.BAG_VIEW.LIST)
            database:SetBagView(bag.kind, const.BAG_VIEW.LIST)
            events:SendMessage('bags/FullRefreshAll')
          end
        end
      }
    }
  })

  -- Show bag slot toggle.
  table.insert(menuList, {
    text = L:G("Show Bags"),
    checked = function() return bag.slots:IsShown() end,
    tooltipTitle = L:G("Show Bags"),
    tooltipText = L:G("Click to toggle the display of the bag slots."),
    func = function()
      if bag.slots:IsShown() then
        bag.slots:Hide()
      else
        bag.slots:Draw()
        bag.slots:Show()
      end
    end
  })

  if bag.kind == const.BAG_KIND.BACKPACK then
    -- Show bag slot toggle.
    table.insert(menuList, {
      text = L:G("Show Currencies"),
      checked = function() return bag.currencyFrame:IsShown() end,
      tooltipTitle = L:G("Show Currencies"),
      tooltipText = L:G("Click to toggle the display of the currencies side panel."),
      func = function()
        if bag.currencyFrame:IsShown() then
          bag.currencyFrame:Hide()
        else
          if bag.sectionConfigFrame:IsShown() then
            bag.sectionConfigFrame:Hide(function()
              bag.currencyFrame:Show()
            end)
          else
            bag.currencyFrame:Show()
          end
        end
      end
    })
  end

  -- Show bag slot toggle.
  table.insert(menuList, {
    text = L:G("Configure Categories"),
    checked = function() return bag.sectionConfigFrame:IsShown() end,
    tooltipTitle = L:G("Configure Categories"),
    tooltipText = L:G("Click to toggle the display of the category configuration side panel."),
    func = function()
      if bag.sectionConfigFrame:IsShown() then
        bag.sectionConfigFrame:Hide()
      else
        if bag.currencyFrame and bag.currencyFrame:IsShown() then
          bag.currencyFrame:Hide(function()
            bag.sectionConfigFrame:Show()
          end)
        else
          bag.sectionConfigFrame:Show()
        end
      end
    end
  })

  table.insert(menuList, {
    text = L:G("Open Options Screen"),
    notCheckable = true,
    tooltipTitle = L:G("Open Options Screen"),
    tooltipText = L:G("Click to open the options screen."),
    func = function()
      contextMenu:Hide()
      events:SendMessage('config/Open')
    end
  })

  table.insert(menuList, {
    text = L:G("Close Menu"),
    notCheckable = true,
    func = function()
      contextMenu:Hide()
    end
  })
  enableTooltips(menuList)
  return menuList
end
