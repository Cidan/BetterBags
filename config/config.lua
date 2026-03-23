local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

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

---@class Bucket: AceModule
local bucket = addon:GetModule('Bucket')

---@class Form: AceModule
local form = addon:GetModule('Form')

---@class CategoryPane: AceModule
local categoryPane = addon:GetModule('CategoryPane')

---@class ThemePane: AceModule
local themePane = addon:GetModule('ThemePane')

---@class CurrencyPane: AceModule
local currencyPane = addon:GetModule('CurrencyPane')

---@class ItemColorPane: AceModule
local itemColorPane = addon:GetModule('ItemColorPane')

---@class Config: AceModule
---@field configFrame FormFrame
local config = addon:NewModule('Config')

function config:CreateConfig()
  local f = form:Create({
    title = 'BetterBags Settings',
    layout = const.FORM_LAYOUT.STACKED,
    index = true,
    tabbed = true
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

  f:AddCheckbox({
    title = 'Enable Bank Bags',
    description = 'Enable BetterBags for bank. If disabled, the default Blizzard bank UI will be used. Requires a UI reload to take effect.',
    getValue = function(_)
      return db:GetEnableBankBag()
    end,
    setValue = function(_, value)
      db:SetEnableBankBag(value)
      -- Prompt user to reload UI
      StaticPopupDialogs["BETTERBAGS_RELOAD_UI"] = {
        text = "BetterBags needs to reload the UI for this change to take effect. Reload now?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
          ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      StaticPopup_Show("BETTERBAGS_RELOAD_UI")
    end
  })

  f:AddCheckbox({
    title = 'Enable Bag Fading',
    description = 'If enabled, bags will smoothly fade in and out when opening/closing.',
    getValue = function(_)
      return db:GetEnableBagFading()
    end,
    setValue = function(_, value)
      db:SetEnableBagFading(value)
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

  f:AddPaneLink({
    title = 'Theme',
    description = 'Change the visual appearance of BetterBags.',
    createPane = function(parent, _)
      return themePane:Create(parent)
    end,
    bagKind = nil,
  })

  f:AddPaneLink({
    title = 'Currency',
    description = 'Configure which currencies are shown in your backpack.',
    createPane = function(parent, _)
      return currencyPane:Create(parent)
    end,
    bagKind = nil,
  })

  f:AddPaneLink({
    title = 'Item Colors',
    description = 'Configure item level color gradients. Colors scale automatically based on your highest seen item level.',
    createPane = function(parent, _)
      return itemColorPane:Create(parent)
    end,
    bagKind = nil,
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
      description = 'The order of sections in the ' .. string.lower(bagType.name) .. ' when not pinned.',
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
      ["Expansion"] = const.ITEM_SORT_TYPE.EXPANSION,
    }
    f:AddDropdown({
      title = 'Item Order',
      description = 'The default order of items within each section.',
      items = {'Alphabetically', 'Quality', 'Item Level', 'Expansion'},
      getValue = function(_, value)
        return itemOrders[value] == db:GetItemSortType(bagType.kind, db:GetBagView(bagType.kind))
      end,
      setValue = function(ctx, value)
        db:SetItemSortType(bagType.kind, db:GetBagView(bagType.kind), itemOrders[value])
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end,
    })

    -- Enable Groups checkbox - only for Backpack
    if bagType.kind == const.BAG_KIND.BACKPACK then
      f:AddCheckbox({
        title = 'Enable Groups',
        description = 'Show group tabs at the bottom of the backpack. Groups allow you to organize categories into separate tabs. When disabled, all categories are shown in a single view.',
        getValue = function(_)
          return db:GetGroupsEnabled(bagType.kind)
        end,
        setValue = function(ctx, value)
          db:SetGroupsEnabled(bagType.kind, value)
          events:SendMessage(ctx, 'groups/EnabledChanged', bagType.kind, value)
          events:SendMessage(ctx, 'bags/FullRefreshAll')
        end
      })
    end

    f:AddInlineSubSection({
      title = 'Categories',
      description = 'Settings for Blizzard item categories in the ' .. string.lower(bagType.name) .. '.',
    })

    f:AddLabel({
      description = 'To create a custom category, drag an item into the bag button on the top of your bag and let go.',
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

    f:AddInlineSubSection({
      title = 'Item Stacking',
      description = 'Settings for item stacking in the ' .. string.lower(bagType.name) .. '.',
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
      description = 'Stackable items will merge into a single item button in your ' .. string.lower(bagType.name) .. '.',
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
      description = 'Unstackable items, such as armor and weapons, will merge into a single item button in your ' .. string.lower(bagType.name) .. '.',
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
      description = 'Transmogged items will be split into a separate, stackable button in your ' .. string.lower(bagType.name) .. '.',
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

    f:AddInlineSubSection({
      title = 'Item Level',
      description = 'Settings for item level in the ' .. string.lower(bagType.name) .. '.',
    })

    f:AddCheckbox({
      title = 'Show Item Level',
      description = 'Show the item level on item buttons in the ' .. string.lower(bagType.name) .. '.',
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
      description = 'Show the item level in color on item buttons in the ' .. string.lower(bagType.name) .. '.',
      getValue = function(_)
        return db:GetItemLevelOptions(bagType.kind).color
      end,
      setValue = function(ctx, value)
        db:GetItemLevelOptions(bagType.kind).color = value
        events:SendMessage(ctx, 'bags/FullRefreshAll')
      end
    })

    f:AddInlineSubSection({
      title = 'Display',
      description = 'Settings that adjust layout and visual aspects of the ' .. string.lower(bagType.name) .. '.',
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
      description = 'Show all free space slots, individually, at the bottom of the ' .. string.lower(bagType.name) .. '.',
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
      description = 'The number of columns in the ' .. string.lower(bagType.name) .. '.',
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
      description = 'The opacity of the background of the ' .. string.lower(bagType.name) .. '.',
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
      description = 'The scale of the ' .. string.lower(bagType.name) .. '.',
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

    f:AddPaneLink({
      title = 'Categories',
      description = 'Manage and reorder categories for the ' .. string.lower(bagType.name) .. '.',
      createPane = function(parent, kind)
        return categoryPane:Create(parent, kind)
      end,
      bagKind = bagType.kind,
    })
  end

  -- ============================================================
  -- Integrations Section
  -- ============================================================
  f:AddSection({
    title = 'Integrations',
    description = 'Settings for third-party addon integrations.',
  })

  f:AddPaneLink({
    title = 'QuickFind',
    description = 'Information about QuickFind addon integration.',
    createPane = function(parent)
      local pane = CreateFrame("Frame", nil, parent)
      pane:SetAllPoints()

      -- Title
      local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      title:SetPoint("TOPLEFT", 10, -10)
      title:SetText("QuickFind Integration")

      -- Description
      local desc = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
      desc:SetPoint("RIGHT", pane, "RIGHT", -10, 0)
      desc:SetWordWrap(true)
      desc:SetJustifyH("LEFT")
      desc:SetText("BetterBags integrates with the QuickFind addon to make your items searchable.")

      -- How it works section
      local howItWorksTitle = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      howItWorksTitle:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
      howItWorksTitle:SetText("How It Works:")

      local howItWorksText = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      howItWorksText:SetPoint("TOPLEFT", howItWorksTitle, "BOTTOMLEFT", 0, -10)
      howItWorksText:SetPoint("RIGHT", pane, "RIGHT", -10, 0)
      howItWorksText:SetWordWrap(true)
      howItWorksText:SetJustifyH("LEFT")
      howItWorksText:SetText("• All items in your backpack and bank are registered as a QuickFind source\n\n• When you press Enter on an item in QuickFind, BetterBags will:\n  - Open the appropriate bag (backpack or bank)\n  - Switch to the tab containing the item\n  - Fill the search box with the item's name\n\n• Items are tagged with their type, category, and location for easy filtering")

      return pane
    end
  })

  -- ============================================================
  -- Profiles Section
  -- ============================================================
  f:AddSection({
    title = 'Profiles',
    description = 'Profiles allow you to save different bag configurations and switch between them on any character. The "Default" profile is shared across all characters by default.',
  })

  f:AddDropdown({
    title = 'Active Profile',
    description = 'Select which profile to use. Switching profiles will reload the UI.',
    itemsFunction = function(_)
      -- Return simple array of profile names (dropdown requires string[])
      return db:GetAvailableProfiles()
    end,
    getValue = function(_, value)
      return db:GetCurrentProfileName() == value
    end,
    setValue = function(_, value)
      -- Confirmation dialog for profile switch
      StaticPopupDialogs["BETTERBAGS_SWITCH_PROFILE"] = {
        text = string.format("Switch to profile '%s'?\n\nThis will reload the UI.", value),
        button1 = "Switch",
        button2 = "Cancel",
        OnAccept = function()
          db:SwitchToProfile(value)
          ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      StaticPopup_Show("BETTERBAGS_SWITCH_PROFILE")
    end
  })

  -- Show character counts for profiles
  local function getProfileCountsText()
    local counts = db:GetProfileCharacterCounts()
    local parts = {}
    for profileName, count in pairs(counts) do
      if count > 0 then
        local charText = count == 1 and "character" or "characters"
        table.insert(parts, string.format("%s: %d %s", profileName, count, charText))
      end
    end
    table.sort(parts)
    return table.concat(parts, "  |  ")
  end

  f:AddLabel({
    description = getProfileCountsText(),
  })

  f:AddButtonGroup({
    ButtonOptions = {
      {
        title = 'Create New Profile',
        onClick = function(_)
          StaticPopupDialogs["BETTERBAGS_CREATE_PROFILE"] = {
            text = "Enter a name for the new profile:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            maxLetters = 48,
            OnAccept = function(s)
              local name = s.EditBox:GetText()
              if name and name ~= "" then
                local success, message = db:CreateProfile(name)
                if success then
                  StaticPopupDialogs["BETTERBAGS_PROFILE_CREATED"] = {
                    text = string.format("Profile '%s' created!\n\nSwitch to it now?", name),
                    button1 = "Switch",
                    button2 = "Later",
                    OnAccept = function()
                      db:SwitchToProfile(name)
                      ReloadUI()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                  }
                  StaticPopup_Show("BETTERBAGS_PROFILE_CREATED")
                else
                  StaticPopupDialogs["BETTERBAGS_PROFILE_ERROR"] = {
                    text = message,
                    button1 = "OK",
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                  }
                  StaticPopup_Show("BETTERBAGS_PROFILE_ERROR")
                end
              end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
          }
          StaticPopup_Show("BETTERBAGS_CREATE_PROFILE")
        end
      },
      {
        title = 'Copy Current Profile',
        onClick = function(_)
          local currentName = db:GetCurrentProfileName()
          StaticPopupDialogs["BETTERBAGS_COPY_PROFILE"] = {
            text = string.format("Create a copy of '%s'?\n\nEnter name for the new profile:", currentName),
            button1 = "Copy",
            button2 = "Cancel",
            hasEditBox = true,
            maxLetters = 48,
            OnAccept = function(s)
              local name = s.EditBox:GetText()
              if name and name ~= "" then
                -- Create new profile (automatically switches to it)
                local success, message = db:CreateProfile(name)
                if success then
                  -- Copy data from source profile to new (current) profile
                  local copySuccess, copyMessage = db:CopyFromProfile(currentName)
                  if copySuccess then
                    StaticPopupDialogs["BETTERBAGS_PROFILE_COPIED"] = {
                      text = string.format("Profile copied to '%s'.\n\nThe UI will reload now.", name),
                      button1 = "OK",
                      OnAccept = function()
                        ReloadUI()
                      end,
                      timeout = 0,
                      whileDead = true,
                      hideOnEscape = true,
                      preferredIndex = 3,
                    }
                    StaticPopup_Show("BETTERBAGS_PROFILE_COPIED")
                  else
                    StaticPopupDialogs["BETTERBAGS_PROFILE_ERROR"] = {
                      text = copyMessage,
                      button1 = "OK",
                      timeout = 0,
                      whileDead = true,
                      hideOnEscape = true,
                      preferredIndex = 3,
                    }
                    StaticPopup_Show("BETTERBAGS_PROFILE_ERROR")
                  end
                else
                  StaticPopupDialogs["BETTERBAGS_PROFILE_ERROR"] = {
                    text = message,
                    button1 = "OK",
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                  }
                  StaticPopup_Show("BETTERBAGS_PROFILE_ERROR")
                end
              end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
          }
          StaticPopup_Show("BETTERBAGS_COPY_PROFILE")
        end
      }
    }
  })

  f:AddButtonGroup({
    ButtonOptions = {
      {
        title = 'Rename Profile',
        onClick = function(_)
          local current = db:GetCurrentProfileName()
          if current == "Default" then
            StaticPopupDialogs["BETTERBAGS_PROFILE_ERROR"] = {
              text = "Cannot rename the Default profile.",
              button1 = "OK",
              timeout = 0,
              whileDead = true,
              hideOnEscape = true,
              preferredIndex = 3,
            }
            StaticPopup_Show("BETTERBAGS_PROFILE_ERROR")
            return
          end

          StaticPopupDialogs["BETTERBAGS_RENAME_PROFILE"] = {
            text = string.format("Rename profile '%s' to:", current),
            button1 = "Rename",
            button2 = "Cancel",
            hasEditBox = true,
            maxLetters = 48,
            OnShow = function(s)
              s.EditBox:SetText(current)
              s.EditBox:HighlightText()
            end,
            OnAccept = function(s)
              local newName = s.EditBox:GetText()
              if newName and newName ~= "" and newName ~= current then
                local success, message = db:RenameProfile(current, newName)
                if success then
                  ReloadUI()
                else
                  StaticPopupDialogs["BETTERBAGS_PROFILE_ERROR"] = {
                    text = message,
                    button1 = "OK",
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                  }
                  StaticPopup_Show("BETTERBAGS_PROFILE_ERROR")
                end
              end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
          }
          StaticPopup_Show("BETTERBAGS_RENAME_PROFILE")
        end
      },
      {
        title = 'Delete Profile',
        onClick = function(_)
          local current = db:GetCurrentProfileName()
          if current == "Default" then
            StaticPopupDialogs["BETTERBAGS_PROFILE_ERROR"] = {
              text = "Cannot delete the Default profile.",
              button1 = "OK",
              timeout = 0,
              whileDead = true,
              hideOnEscape = true,
              preferredIndex = 3,
            }
            StaticPopup_Show("BETTERBAGS_PROFILE_ERROR")
            return
          end

          StaticPopupDialogs["BETTERBAGS_DELETE_PROFILE"] = {
            text = string.format("Delete profile '%s'?\n\nThis cannot be undone.\n\nYou will be switched to the Default profile.", current),
            button1 = "Delete",
            button2 = "Cancel",
            OnAccept = function()
              db:SwitchToProfile("Default")
              db:DeleteProfile(current)
              ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
          }
          StaticPopup_Show("BETTERBAGS_DELETE_PROFILE")
        end
      },
      {
        title = 'Reset to Defaults',
        onClick = function(_)
          local current = db:GetCurrentProfileName()
          StaticPopupDialogs["BETTERBAGS_RESET_PROFILE"] = {
            text = string.format("Reset profile '%s' to default settings?\n\nThis will delete all your customizations for this profile.\n\nThis cannot be undone.", current),
            button1 = "Reset",
            button2 = "Cancel",
            OnAccept = function()
              db:ResetCurrentProfile()
              ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
          }
          StaticPopup_Show("BETTERBAGS_RESET_PROFILE")
        end
      }
    }
  })

  -- Spacer between Profiles and Import/Export
  f:AddLabel({
    description = ' ',
  })

  -- ============================================================
  -- Import/Export Section
  -- ============================================================
  f:AddSection({
    title = 'Import/Export',
    description = 'Export your category configuration to share with others or import category configurations from another user.',
  })

  f:AddLabel({
    description = 'Export your current category configuration to a string that can be copied and shared. Import a category configuration string to apply another user\'s bag organization. Note: Only category settings are included - general settings like themes, sizes, and display options are not affected.',
  })

  -- Spacer for button positioning
  f:AddLabel({
    description = ' ',
  })

  -- Store reference to text area input fields
  config.exportTextBox = nil
  config.importTextBox = nil

  f:AddButtonGroup({
    ButtonOptions = {
      {
        title = 'Export Category Configuration',
        onClick = function(_)
          local exportString = db:ExportSettings()
          if config.exportTextBox then
            config.exportTextBox:SetText(exportString)
            config.exportTextBox:HighlightText()
            config.exportTextBox:SetFocus()
          end
        end
      }
    }
  })

  f:AddTextArea({
    title = 'Exported Category Configuration',
    description = 'Copy this text to share your category configuration. Click in the box and press Ctrl+A to select all, then Ctrl+C to copy.',
    getValue = function(_)
      return ""
    end,
    setValue = function()
      -- Store reference will be set after form creation
    end
  })

  -- Initialize the exportTextBox reference
  bucket:Later("getExportTextBox", 0.1, function()
    for container, _ in pairs(f.layout.textAreas) do
      if container.title:GetText() == 'Exported Category Configuration' then
        config.exportTextBox = container.input
        break
      end
    end
  end)

  f:AddTextArea({
    title = 'Import Category Configuration',
    description = 'Paste category configuration string here and click Import to apply.',
    getValue = function(_)
      return ""
    end,
    setValue = function()
      -- Store reference will be set after form creation
    end
  })

  -- Initialize the importTextBox reference
  bucket:Later("getImportTextBox", 0.1, function()
    for container, _ in pairs(f.layout.textAreas) do
      if container.title:GetText() == 'Import Category Configuration' then
        config.importTextBox = container.input
        break
      end
    end
  end)

  f:AddButtonGroup({
    ButtonOptions = {
      {
        title = 'Import Category Configuration',
        onClick = function(_)
          if not config.importTextBox then return end

          local importString = config.importTextBox:GetText()
          if not importString or importString == "" then
            StaticPopupDialogs["BETTERBAGS_IMPORT_ERROR"] = {
              text = "Please paste a category configuration string in the Import Category Configuration field.",
              button1 = "OK",
              timeout = 0,
              whileDead = true,
              hideOnEscape = true,
              preferredIndex = 3,
            }
            StaticPopup_Show("BETTERBAGS_IMPORT_ERROR")
            return
          end

          -- Confirmation dialog
          StaticPopupDialogs["BETTERBAGS_IMPORT_CONFIRM"] = {
            text = "This will overwrite your current category configuration. Continue?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
              local success, message = db:ImportSettings(importString)
              if success then
                StaticPopupDialogs["BETTERBAGS_IMPORT_SUCCESS"] = {
                  text = "Category configuration imported successfully! Reload UI to apply changes?",
                  button1 = "Reload",
                  button2 = "Later",
                  OnAccept = function()
                    ReloadUI()
                  end,
                  timeout = 0,
                  whileDead = true,
                  hideOnEscape = true,
                  preferredIndex = 3,
                }
                StaticPopup_Show("BETTERBAGS_IMPORT_SUCCESS")
                -- Clear the import text box
                if config.importTextBox then
                  config.importTextBox:SetText("")
                end
              else
                StaticPopupDialogs["BETTERBAGS_IMPORT_ERROR"] = {
                  text = "Failed to import category configuration: " .. message,
                  button1 = "OK",
                  timeout = 0,
                  whileDead = true,
                  hideOnEscape = true,
                  preferredIndex = 3,
                }
                StaticPopup_Show("BETTERBAGS_IMPORT_ERROR")
              end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
          }
          StaticPopup_Show("BETTERBAGS_IMPORT_CONFIRM")
        end
      }
    }
  })

  f:GetFrame():SetSize(850, 800)
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
    if addon.Bags.Bank then
      addon.Bags.Bank.anchor:Activate()
      addon.Bags.Bank.anchor:Show()
    end
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
