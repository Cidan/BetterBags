local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Bucket: AceModule
local bucket = addon:GetModule('Bucket')

---@class Form: AceModule
local form = addon:GetModule('Form')

---@class Config: AceModule
---@field configFrame FormFrame
local config = addon:NewModule('Config')

function config:CreateConfig()
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
   getValue = function(_)
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
    getValue = function(_)
      return db:GetEnterToMakeCategory()
    end,
    setValue = function(_, value)
      db:SetEnterToMakeCategory(value)
    end
  })
  f:AddCheckbox({
    title = 'Enable Category Sell and Deposit',
    description = 'If enabled, right-clicking a category header at an NPC shop will sell all its contents, or deposit to bank.',
    getValue = function(_)
      return db:GetCategorySell()
    end,
    setValue = function(_, value)
      db:SetCategorySell(value)
    end
  })
  f:AddCheckbox({
    title = 'Show Blizzard Bag Button',
    description = 'Show or hide the default Blizzard bag button.',
    getValue = function(_)
      return db:GetShowBagButton()
    end,
    setValue = function(_, value)
      db:SetShowBagButton(value)
      local sneakyFrame = _G["BetterBagsSneakyFrame"] ---@type Frame	
      if value then
        BagsBar:SetParent(UIParent)
      else
        BagsBar:SetParent(sneakyFrame)
      end
    end
  })

  f:AddDropdown({
    title = 'Upgrade Icon Provider',
    description = 'Select the icon provider for item upgrades.',
    items = {'None', 'BetterBags'},
    getValue = function(_, value)
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
    getValue = function(_)
      return db:GetData().profile.newItemTime / 60
    end,
    setValue = function(_, value)
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
      getValue = function(_, value)
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
      getValue = function(_, value)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
        return db:GetMarkRecentItems(bagType.kind)
      end,
      setValue = function(_, value)
        db:SetMarkRecentItems(bagType.kind, value)
      end
    })

    f:AddCheckbox({
      title = 'Flash Stacks',
      description = 'When a stack of items gets a new item, the stack will flash.',
      getValue = function(_)
        return db:GetShowNewItemFlash(bagType.kind)
      end,
      setValue = function(_, value)
        db:SetShowNewItemFlash(bagType.kind, value)
      end
    })

    f:AddCheckbox({
      title = 'Merge Stacks',
      description = 'Stackable items will merge into a single item button in your backpack.',
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
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
      getValue = function(_)
        return db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).opacity
      end,
      setValue = function(_, value)
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
      getValue = function(_)
        return db:GetBagSizeInfo(bagType.kind, db:GetBagView(bagType.kind)).scale
      end,
      setValue = function(_, value)
        -- TODO(lobato): This should be an event.
        local bag = addon:GetBagFromKind(bagType.kind)
        if not bag then return end
        bag.frame:SetScale(value / 100)
        db:SetBagViewSizeScale(bagType.kind, db:GetBagView(bagType.kind), value)
      end,
    })
  end

  f:GetFrame():SetSize(600, 800)
  f:GetFrame():SetPoint("CENTER")
  self.configFrame = f
end

---@diagnostic disable-next-line: duplicate-set-field
function config:Open()
  self.configFrame:Show()
end

function config:RegisterSettings()
  LibStub('AceConsole-3.0'):RegisterChatCommand("bb", function()
    self:Open()
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbanchor", function()
    addon.Bags.Backpack.anchor:Activate()
    addon.Bags.Backpack.anchor:Show()
    addon.Bags.Bank.anchor:Activate()
    addon.Bags.Bank.anchor:Show()
  end)

  events:RegisterMessage('categories/Changed', function()
    --LibStub('AceConfigRegistry-3.0'):NotifyChange(addonName)
  end)

  events:RegisterMessage('config/Open', function()
    self:Open()
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbdb", function()
    db:SetDebugMode(not db:GetDebugMode())
    local ctx = context:New('on_click')
    events:SendMessage(ctx, 'config/DebugMode', db:GetDebugMode())
  end)
end

function config:OnEnable()
  if self.configFrame then return end
  self:CreateConfig()
  self:RegisterSettings()
  table.insert(UISpecialFrames, self.configFrame.frame:GetName())
end
