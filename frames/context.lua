local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
---@field frame Frame
local context = addon:NewModule('Context')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

---@class MenuList
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
local menuListProto = {}

function context:OnInitialize()
  --self:CreateContext()
end

function context:OnEnable()
  local frame = LibDD:Create_UIDropDownMenu("BetterBagsContextMenu", UIParent)
  LibDD:EasyMenu_Initialize(frame, 1, {})
  self.frame = frame
end

---@param menuList MenuList[]
function context:Show(menuList)
  LibDD:EasyMenu(menuList, self.frame, 'cursor', 0, 0, 'MENU')
end

function context:Hide()
  LibDD:HideDropDownMenu(1)
end

---@param bag Bag
---@return MenuList[]
function context:CreateContextMenu(bag)
  local menuList = {}

  -- Context Menu title.
  table.insert(menuList, {
    text = L:G("BetterBags Menu"),
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
        checked = function() return database:GetBagView(bag.kind) == const.BAG_VIEW.ONE_BAG end,
        func = function()
          context:Hide()
          database:SetBagView(bag.kind, const.BAG_VIEW.ONE_BAG)
          bag:Wipe()
          bag:Refresh()
        end
      },
      {
        text = L:G("Section Grid"),
        keepShownOnClick = false,
        checked = function() return database:GetBagView(bag.kind) == const.BAG_VIEW.SECTION_GRID end,
        func = function()
          context:Hide()
          database:SetBagView(bag.kind, const.BAG_VIEW.SECTION_GRID)
          bag:Wipe()
          bag:Refresh()
        end
      },
      --[[
      {
        text = L:G("List"),
        keepShownOnClick = false,
        checked = function() return database:GetBagView(bag.kind) == const.BAG_VIEW.LIST end,
        func = function()
          context:Hide()
          database:SetBagView(bag.kind, const.BAG_VIEW.LIST)
          bag:Wipe()
          if bag.kind == const.BAG_KIND.BACKPACK then items:RefreshBackpack() else items:RefreshBank() end
        end
      }
      --]]
    }
  })

  -- Category filter menu for selecting how categories are created in grid view.
  table.insert(menuList, {
    text = L:G("Section Categories"),
    hasArrow = true,
    notCheckable = true,
    menuList = {
      {
        text = L:G("Type"),
        checked = function() return database:GetCategoryFilter(bag.kind, "Type") end,
        func = function()
          context:Hide()
          database:SetCategoryFilter(bag.kind, "Type", not database:GetCategoryFilter(bag.kind, "Type"))
          bag:Wipe()
          bag:Refresh()
        end
      },
      {
        text = L:G("Expansion"),
        tooltipTitle = L:G("Expansion"),
        tooltipText = L:G("If enabled, will categorize items by expansion."),
        checked = function() return database:GetCategoryFilter(bag.kind, "Expansion") end,
        func = function()
          context:Hide()
          database:SetCategoryFilter(bag.kind, "Expansion", not database:GetCategoryFilter(bag.kind, "Expansion"))
          bag:Wipe()
          bag:Refresh()
        end
      },
      {
        text = L:G("Trade Skill (Reagents Only)"),
        tooltipTitle = L:G("Trade Skill"),
        tooltipText = L:G("If enabled, will categorize items by trade skill."),
        checked = function() return database:GetCategoryFilter(bag.kind, "TradeSkill") end,
        func = function()
          context:Hide()
          database:SetCategoryFilter(bag.kind, "TradeSkill", not database:GetCategoryFilter(bag.kind, "TradeSkill"))
          bag:Wipe()
          bag:Refresh()
        end
      }
    }
  })

  -- Create the size menu.
  local sizeMenu = {
    text = L:G("Size"),
    hasArrow = true,
    notCheckable = true,
    menuList = {}
  }

  -- Loop through the two size menu types, as they are extremely similar.
  for _, sub in pairs({"Columns", "Items per Row"}) do
    local subMenu = {
      text = L:G(sub),
      hasArrow = true,
      notCheckable = true,
      menuList = {}
    }

    -- Loop through the size options. Change these if you want to have more size options.
    for i = 3, 7 do
      if sub == "Columns" then
        table.insert(subMenu.menuList, {
          text = L:G(tostring(i)),
          checked = function() return database:GetBagSizeInfo(bag.kind).columnCount == i end,
          func = function()
            context:Hide()
            database:SetBagSizeColumn(bag.kind, i)
            bag:Wipe()
            bag:Refresh()
          end
        })
      else
        table.insert(subMenu.menuList, {
          text = L:G(tostring(i)),
          checked = function() return database:GetBagSizeInfo(bag.kind).itemsPerRow == i end,
          func = function()
            context:Hide()
            database:SetBagSizeItems(bag.kind, i)
            bag:Wipe()
            bag:Refresh()
          end
        })
      end
    end
    table.insert(sizeMenu.menuList, subMenu)
  end
  table.insert(menuList, sizeMenu)

  -- Show bag slot toggle.
  table.insert(menuList, {
    text = L:G("Show Bags"),
    checked = function() return bag.slots:IsShown() end,
    func = function()
      if bag.slots:IsShown() then
        bag.slots:Hide()
      else
        bag.slots:Draw()
        bag.slots:Show()
      end
    end
  })

  -- Show the Blizzard bag button toggle.
  table.insert(menuList, {
    text = L:G("Show Bag Button"),
    checked = function() return BagsBar:IsShown() end,
    func = function()
      BagsBar:SetShown(not BagsBar:IsShown())
      database:SetShowBagButton(BagsBar:IsShown())
    end
  })
  return menuList
end