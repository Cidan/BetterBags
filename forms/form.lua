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
  l.frame:SetFrameLevel(800)

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

  return l
end

function formFrame:Refresh()
  self.inner:SetHeight(self.layout.height + 20)
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
    layout = const.FORM_LAYOUT.STACKED,
    index = true
  })
 f:AddSection({
   title = 'General',
   description = 'General settings for BetterBags.',
 })
  f:AddCheckbox({
   title = 'Enable In-Bag Search',
   description = 'If enabled, a search bar will appear at the top of your bags.',
   getValue = function(ctx)
    return db:GetInBagSearch()
   end,
    setValue = function(ctx, value)
      db:SetInBagSearch(value)
      events:SendMessage(ctx, 'search/SetInFrame', value)
    end
  })
  f:AddCheckbox({
    title = 'Enable Enter to Make Category',
    description = 'If enabled, pressing Enter with a search query will open the make category menu.',
    getValue = function(ctx)
      return db:GetEnterToMakeCategory()
    end,
    setValue = function(ctx, value)
      db:SetEnterToMakeCategory(value)
    end
  })
  f:AddCheckbox({
    title = 'Enable Category Sell and Deposit',
    description = 'If enabled, right-clicking a category header at an NPC shop will sell all its contents, or deposit to bank.',
    getValue = function(ctx)
      return db:GetCategorySell()
    end,
    setValue = function(ctx, value)
      db:SetCategorySell(value)
    end
  })
  f:AddCheckbox({
    title = 'Show Blizzard Bag Button',
    description = 'Show or hide the default Blizzard bag button.',
    getValue = function(ctx)
      return db:GetShowBagButton()
    end,
    setValue = function(ctx, value)
      db:SetShowBagButton(value)
    end
  })

  f:AddDropdown({
    title = 'Upgrade Icon Provider',
    description = 'Select the icon provider for item upgrades.',
    items = {'None', 'BetterBags'},
    getValue = function(ctx, value)
      return value == db:GetUpgradeIconProvider()
    end,
    setValue = function(ctx, value)
      db:SetUpgradeIconProvider(value)
      events:SendMessage(ctx, 'bag/RedrawIcons')
    end,
  })

  f:AddSlider({
    title = 'New Item Duration',
    description = 'The duration in minutes that an item is considered new.',
    min = 1,
    max = 120,
    step = 1,
    getValue = function(ctx)
      return db:GetData().profile.newItemTime / 60
    end,
    setValue = function(ctx, value)
      db:GetData().profile.newItemTime = value * 60
    end,
  })

  local bagTypes = {
    {name = 'Backpack', kind = const.BAG_KIND.BACKPACK},
    {name = 'Bank', kind = const.BAG_KIND.BANK}
  }
  for _, bagType in ipairs(bagTypes) do

    f:AddSection({
      title = bagType.name,
      description = 'Settings for the ' .. string.lower(bagType.name) .. '.',
    })
    local sectionOrders = {
      ["Alphabetically"] = const.SECTION_SORT_TYPE.ALPHABETICALLY,
      ["Size Descending"] = const.SECTION_SORT_TYPE.SIZE_DESCENDING,
      ["Size Ascending"] = const.SECTION_SORT_TYPE.SIZE_ASCENDING,
    }
    f:AddDropdown({
      title = 'Section Order',
      description = 'The order of sections in the backpack when not pinned.',
      items = {'Alphabetically', 'Size Descending', 'Size Ascending'},
      getValue = function(ctx, value)
        return sectionOrders[value] == db:GetSectionSortType(bagType.kind, db:GetBagView(bagType.kind))
      end,
      setValue = function(ctx, value)
        db:SetSectionSortType(bagType.kind, db:GetBagView(bagType.kind), sectionOrders[value])
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end,
    })

    local itemOrders = {
      ["Alphabetically"] = const.ITEM_SORT_TYPE.ALPHABETICALLY_THEN_QUALITY,
      ["Quality"] = const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY,
      ["Item Level"] = const.ITEM_SORT_TYPE.ITEM_LEVEL,
    }
    f:AddDropdown({
      title = 'Item Order',
      description = 'The default order of items within each section.',
      items = {'Alphabetically', 'Quality', 'Item Level'},
      getValue = function(ctx, value)
        return itemOrders[value] == db:GetItemSortType(bagType.kind, db:GetBagView(bagType.kind))
      end,
      setValue = function(ctx, value)
        db:SetItemSortType(bagType.kind, db:GetBagView(bagType.kind), itemOrders[value])
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end,
    })

    f:AddSubSection({
      title = 'Categories',
      description = 'Settings for Blizzard item categories in the backpack.',
    })

    f:AddCheckbox({
      title = 'Equipment Location',
      description = 'Sort items into categories based on equipment location (Main Hand, Head, etc).',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).EquipmentLocation
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).EquipmentLocation = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Expansion',
      description = 'Sort items into categories based on their expansion.',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).Expansion
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).Expansion = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Equipment Set',
      description = 'Sort items into categories based on equipment sets.',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).GearSet
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).GearSet = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Recent Items',
      description = 'Enable the Recent Items category for new items.',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).RecentItems
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).RecentItems = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Trade Skill',
      description = 'Sort items into categories based on their trade skill usage.',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).TradeSkill
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).TradeSkill = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Type',
      description = 'Sort items into categories based on their equipment type (Consumable, Quest, etc).',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).Type
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).Type = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Sub Type',
      description = 'Sort items into categories based on sub type (Potions, Bandages, etc).',
      getValue = function(ctx)
        return db:GetCategoryFilters(bagType.kind).Subtype
      end,
      setValue = function(ctx, value)
        db:GetCategoryFilters(bagType.kind).Subtype = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddSubSection({
      title = 'Item Stacking',
      description = 'Settings for item stacking in the backpack.',
    })

    f:AddCheckbox({
      title = 'All Items Recent',
      description = 'All new items you loot, pickup, or move into the bag will be marked as recent.',
      getValue = function(ctx)
        return db:GetMarkRecentItems(bagType.kind)
      end,
      setValue = function(ctx, value)
        db:SetMarkRecentItems(bagType.kind, value)
      end
    })

    f:AddCheckbox({
      title = 'Flash Stacks',
      description = 'When a stack of items gets a new item, the stack will flash.',
      getValue = function(ctx)
        return db:GetShowNewItemFlash(bagType.kind)
      end,
      setValue = function(ctx, value)
        db:SetShowNewItemFlash(bagType.kind, value)
      end
    })

    f:AddCheckbox({
      title = 'Merge Stacks',
      description = 'Stackable items will merge into a single item button in your backpack.',
      getValue = function(ctx)
        return db:GetStackingOptions(bagType.kind).mergeStacks
      end,
      setValue = function(ctx, value)
        db:GetStackingOptions(bagType.kind).mergeStacks = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Merge Unstackable',
      description = 'Unstackable items, such as armor and weapons, will merge into a single item button in your backpack.',
      getValue = function(ctx)
        return db:GetStackingOptions(bagType.kind).mergeUnstackable
      end,
      setValue = function(ctx, value)
        db:GetStackingOptions(bagType.kind).mergeUnstackable = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = "Don't Merge Partial Stacks",
      description = 'Partial stacks of items will not merge with other partial or full stacks.',
      getValue = function(ctx)
        return db:GetStackingOptions(bagType.kind).dontMergePartial
      end,
      setValue = function(ctx, value)
        db:GetStackingOptions(bagType.kind).dontMergePartial = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = "Split Transmogged Items",
      description = 'Transmogged items will be split into a separate, stackable button in your backpack.',
      getValue = function(ctx)
        return db:GetStackingOptions(bagType.kind).dontMergeTransmog
      end,
      setValue = function(ctx, value)
        db:GetStackingOptions(bagType.kind).dontMergeTransmog = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Unmerge on Interactions',
      description = 'When you interact a vendor, mailbox, auction house, etc, all merged items will unmerge.',
      getValue = function(ctx)
        return db:GetStackingOptions(bagType.kind).unmergeAtShop
      end,
      setValue = function(ctx, value)
        db:GetStackingOptions(bagType.kind).unmergeAtShop = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })


    f:AddSubSection({
      title = 'Item Level',
      description = 'Settings for item level in the backpack.',
    })

    f:AddCheckbox({
      title = 'Show Item Level',
      description = 'Show the item level on item buttons in the backpack.',
      getValue = function(ctx)
        return db:GetItemLevelOptions(bagType.kind).enabled
      end,
      setValue = function(ctx, value)
        db:GetItemLevelOptions(bagType.kind).enabled = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Show Item Level Color',
      description = 'Show the item level in color on item buttons in the backpack.',
      getValue = function(ctx)
        return db:GetItemLevelOptions(bagType.kind).color
      end,
      setValue = function(ctx, value)
        db:GetItemLevelOptions(bagType.kind).color = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })


    f:AddSubSection({
      title = 'Display',
      description = 'Settings that adjust layout and visual aspects of the backpack.',
    })

    f:AddCheckbox({
      title = 'Show Full Section Names',
      description = 'Show the full section names for each section and do not cut them off.',
      getValue = function(ctx)
        return db:GetShowFullSectionNames(bagType.kind)
      end,
      setValue = function(ctx, value)
        db:SetShowFullSectionNames(bagType.kind, value)
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Show All Free Space Slots',
      description = 'Show all free space slots, individually, at the bottom of the backpack.',
      getValue = function(ctx)
        return db:GetShowAllFreeSpace(bagType.kind)
      end,
      setValue = function(ctx, value)
        db:SetShowAllFreeSpace(bagType.kind, value)
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddCheckbox({
      title = 'Extra Glowy Item Buttons',
      description = 'Item buttons will have an enhanced glow effect using the item quality color.',
      getValue = function(ctx)
        return db:GetExtraGlowyButtons(bagType.kind)
      end,
      setValue = function(ctx, value)
        db:SetExtraGlowyButtons(bagType.kind, value)
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddSlider({
      title = 'Items Per Row',
      description = 'The number of items per row in each section.',
      min = 3,
      max = 20,
      step = 1,
      getValue = function(ctx)
        return db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).itemsPerRow > 20 and 20 or db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).itemsPerRow
      end,
      setValue = function(ctx, value)
        db:SetBagViewSizeItems(bagType.kind, db:GetBagView(bagType.kind), value)
        bucket:Later("setItemsPerRow", 0.2, function()
          events:SendMessage(ctx, 'bags/FullRefreshAll')
        end)
      end,
    })

    f:AddSlider({
      title = 'Columns',
      description = 'The number of columns in the backpack.',
      min = 1,
      max = 20,
      step = 1,
      getValue = function(ctx)
        return db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).columnCount > 20 and 20 or db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).columnCount
      end,
      setValue = function(ctx, value)
        db:SetBagViewSizeColumn(bagType.kind, db:GetBagView(bagType.kind), value)
        bucket:Later("setSectionsPerRow", 0.2, function()
          events:SendMessage(ctx, 'bags/FullRefreshAll')
        end)
      end,
    })

    f:AddSlider({
      title = 'Opacity',
      description = 'The opacity of the background of the backpack.',
      min = 0,
      max = 100,
      step = 1,
      getValue = function(ctx)
        return db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).opacity
      end,
      setValue = function(ctx, value)
        db:SetBagViewSizeOpacity(bagType.kind, db:GetBagView(bagType.kind), value)
        themes:UpdateOpacity()
      end,
    })

    f:AddSlider({
      title = 'Scale',
      description = 'The scale of the backpack.',
      min = 50,
      max = 200,
      step = 1,
      getValue = function(ctx)
        return db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).scale
      end,
      setValue = function(ctx, value)
        -- TODO(lobato): This should be an event.
        local bag = addon:GetBagFromKind(bagType.kind)
        if not bag then return end
        bag.frame:SetScale(value / 100)
        db:SetBagViewSizeScale(bagType.kind, db:GetBagView(bagType.kind), value)
      end,
    })
  end
  f:Show()
end