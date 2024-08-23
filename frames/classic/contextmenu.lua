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

---@class Context: AceModule
local context = addon:GetModule('Context')

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

---@param ctx Context
---@param menuList MenuList[]
function contextMenu:Show(ctx, menuList)
  LibDD:EasyMenu(menuList, self.frame, 'cursor', 0, 0, 'MENU')
  events:SendMessage('context/show', ctx)
end

---@param ctx Context
function contextMenu:Hide(ctx)
  LibDD:HideDropDownMenu(1)
  events:SendMessage('context/hide', ctx)
end

function contextMenu:AddDivider(menuList)
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

  table.insert(menuList, {
    text = L:G("Bag Anchor"),
    notCheckable = true,
    hasArrow = true,
    menuList = {
      {
        text = L:G("Enable"),
        notCheckable = false,
        checked = function() return bag.anchor:IsActive() end,
        func = function()
          local ctx = context:New('ToggleAnchor')
          bag.anchor:ToggleActive()
          contextMenu:Hide(ctx)
        end
      },
      {
        text = L:G("Show"),
        notCheckable = false,
        checked = function() return bag.anchor.frame:IsShown() end,
        func = function()
          local ctx = context:New('ToggleAnchor')
          bag.anchor:ToggleShown()
          contextMenu:Hide(ctx)
        end
      },
      {
        text = L:G("Manual Anchor"),
        notCheckable = true,
        hasArrow = true,
        menuList = {
          {
            text = L:G("Top Left"),
            notCheckable = false,
            checked = function() return database:GetAnchorState(bag.kind).staticPoint == 'TOPLEFT' end,
            func = function()
              local ctx = context:New('SetStaticAnchorPoint')
              bag.anchor:SetStaticAnchorPoint('TOPLEFT')
              contextMenu:Hide(ctx)
            end
          },
          {
            text = L:G("Top Right"),
            notCheckable = false,
            checked = function() return database:GetAnchorState(bag.kind).staticPoint == 'TOPRIGHT' end,
            func = function()
              local ctx = context:New('SetStaticAnchorPoint')
              bag.anchor:SetStaticAnchorPoint('TOPRIGHT')
              contextMenu:Hide(ctx)
            end
          },
          {
            text = L:G("Bottom Left"),
            notCheckable = false,
            checked = function() return database:GetAnchorState(bag.kind).staticPoint == 'BOTTOMLEFT' end,
            func = function()
              local ctx = context:New('SetStaticAnchorPoint')
              bag.anchor:SetStaticAnchorPoint('BOTTOMLEFT')
              contextMenu:Hide(ctx)
            end
          },
          {
            text = L:G("Bottom Right"),
            notCheckable = false,
            checked = function() return database:GetAnchorState(bag.kind).staticPoint == 'BOTTOMRIGHT' end,
            func = function()
              local ctx = context:New('SetStaticAnchorPoint')
              bag.anchor:SetStaticAnchorPoint('BOTTOMRIGHT')
              contextMenu:Hide(ctx)
            end
          },
          {
            text = L:G("Automatic"),
            notCheckable = false,
            checked = function() return database:GetAnchorState(bag.kind).staticPoint == nil end,
            func = function()
              local ctx = context:New('SetStaticAnchorPoint')
              bag.anchor:SetStaticAnchorPoint(nil)
              contextMenu:Hide(ctx)
            end
          }
        }
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
        bag.windowGrouping:Show('currencyConfig')
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
      bag.windowGrouping:Show("sectionConfig")
    end
  })

  if bag.kind == const.BAG_KIND.BACKPACK then
    -- Show theme selection window.
    table.insert(menuList, {
      text = L:G("Themes"),
      checked = function() return bag.themeConfigFrame:IsShown() end,
      tooltipTitle = L:G("Themes"),
      tooltipText = L:G("Click to toggle the display of the theme configuration side panel."),
      func = function()
        bag.windowGrouping:Show('themeConfig')
      end
    })
  end
  table.insert(menuList, {
    text = L:G("Open Options Screen"),
    notCheckable = true,
    tooltipTitle = L:G("Open Options Screen"),
    tooltipText = L:G("Click to open the options screen."),
    func = function()
      local ctx = context:New('OpenOptions')
      contextMenu:Hide(ctx)
      events:SendMessage('config/Open', ctx)
    end
  })

  table.insert(menuList, {
    text = L:G("Close Menu"),
    notCheckable = true,
    func = function()
      local ctx = context:New('CloseMenu')
      contextMenu:Hide(ctx)
    end
  })
  enableTooltips(menuList)
  return menuList
end
