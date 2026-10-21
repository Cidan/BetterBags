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

---@class Bucket: AceModule
local bucket = addon:GetModule('Bucket')

---@class Form: AceModule
local form = addon:GetModule('Form')

---@class CategoryPane: AceModule
local categoryPane = addon:GetModule('CategoryPane')

---@class ThemePane: AceModule
local themePane = addon:GetModule('ThemePane')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class CurrencyPane: AceModule
local currencyPane = addon:GetModule('CurrencyPane')

---@class ItemColorPane: AceModule
local itemColorPane = addon:GetModule('ItemColorPane')

---@class SettingsCatalog: AceModule
local catalog = addon:GetModule('SettingsCatalog')

---@class Config: AceModule
---@field configFrame FormFrame
local config = addon:NewModule('Config')

-- The form's control for each kind of setting (forms/layouts/layout.lua).
local ADD = { toggle = 'AddCheckbox', dropdown = 'AddDropdown', slider = 'AddSlider' }

-- addSetting adds a setting of the catalog (config/catalog.lua) to the form, as the control of its
-- kind.
---@param f FormFrame
---@param id string
---@param bag? SettingBag
---@param hooks? SettingHooks
local function addSetting(f, id, bag, hooks)
  local kind = catalog:Get(id, bag).kind
  f[ADD[kind]](f, catalog:Form(id, bag, hooks))
end

-- askToReload asks the player to reload the UI, for a setting that takes effect only then.
local function askToReload()
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
  -- A setting that takes effect after a reload asks for one; a change refused (switching the bags'
  -- design in combat, at the bank or a vendor) shows the settings again as they are.
  local hooks = {
    reload = askToReload,
    refresh = function() self.configFrame:ReloadAllFormElements() end,
  }
  for _, id in ipairs({ 'inBagSearch', 'enterToMakeCategory', 'categorySell', 'showBagButton', 'enableBankBags',
    'bagFading', 'animateItemMovement', 'nextEnabled', 'upgradeProvider', 'newItemDuration' }) do
    addSetting(f, id, nil, hooks)
  end

  f:AddPaneLink({
    title = 'Theme',
    description = 'Change the visual appearance of BetterBags.',
    createPane = function(parent, _)
      return themePane:Create(parent)
    end,
    bagKind = nil,
  })

  -- BetterBags Next's own themes (next-themes.md), picked the same way.
  f:AddPaneLink({
    title = 'Next Theme',
    description = 'Change the look of BetterBags Next.',
    createPane = function(parent, _)
      return themePane:Create(parent, addon:GetModule('SonataNext'))
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

  for _, bag in ipairs(catalog:Bags()) do
    local name = string.lower(bag.name)
    f:AddSection({
      title = bag.name,
      description = 'Settings for the ' .. name .. '.',
    })
    addSetting(f, 'sectionOrder', bag)
    addSetting(f, 'itemOrder', bag)
    if catalog:Has('enableGroups', bag) then
      addSetting(f, 'enableGroups', bag)
    end

    f:AddInlineSubSection({
      title = 'Categories',
      description = 'Settings for Blizzard item categories in the ' .. name .. '.',
    })
    f:AddLabel({
      description = 'To create a custom category, drag an item into the bag button on the top of your bag and let go.',
    })
    for _, id in ipairs({ 'filterEquipmentLocation', 'filterExpansion', 'filterGearSet', 'filterRecentItems',
      'filterTradeSkill', 'filterType', 'filterSubtype' }) do
      addSetting(f, id, bag)
    end

    f:AddInlineSubSection({
      title = 'Item Stacking',
      description = 'Settings for item stacking in the ' .. name .. '.',
    })
    for _, id in ipairs({ 'markRecentItems', 'newItemFlash', 'mergeStacks', 'mergeUnstackable', 'dontMergePartial',
      'dontMergeTransmog', 'unmergeAtShop' }) do
      addSetting(f, id, bag)
    end

    f:AddInlineSubSection({
      title = 'Item Level',
      description = 'Settings for item level in the ' .. name .. '.',
    })
    addSetting(f, 'itemLevel', bag)
    addSetting(f, 'itemLevelColor', bag)

    f:AddInlineSubSection({
      title = 'Display',
      description = 'Settings that adjust layout and visual aspects of the ' .. name .. '.',
    })
    for _, id in ipairs({ 'fullSectionNames', 'showAllFreeSpace', 'preserveGaps', 'glowIntensity', 'resizableWindow',
      'snapToContent', 'itemsPerRow', 'columns', 'opacity', 'scale' }) do
      addSetting(f, id, bag)
    end

    f:AddPaneLink({
      title = 'Categories',
      description = 'Manage and reorder categories for the ' .. name .. '.',
      createPane = function(parent, kind)
        return categoryPane:Create(parent, kind)
      end,
      bagKind = bag.kind,
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
      local title = sonata:CreateText(pane, "Title")
      title:SetPoint("TOPLEFT", 10, -10)
      title:SetText("QuickFind Integration")

      -- Description
      local desc = sonata:CreateText(pane, "Body")
      desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
      desc:SetPoint("RIGHT", pane, "RIGHT", -10, 0)
      desc:SetWordWrap(true)
      desc:SetJustifyH("LEFT")
      desc:SetText("BetterBags integrates with the QuickFind addon to make your items searchable.")

      -- How it works section
      local howItWorksTitle = sonata:CreateText(pane, "Field")
      howItWorksTitle:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
      howItWorksTitle:SetText("How It Works:")

      local howItWorksText = sonata:CreateText(pane, "BodySmall")
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
  -- /bb opens the settings; /bb changelog opens the changelog (frames/changelog.lua); /bb next
  -- switches the bags between the classic design and BetterBags Next (next.md §11).
  LibStub('AceConsole-3.0'):RegisterChatCommand("bb", function(input)
    local command = strtrim(input or ""):lower()
    if command == "changelog" then
      events:SendMessage(context:New('SlashChangelog'), 'changelog/Open')
      return
    end
    if command == "next" then
      addon:GetModule('BagSystem'):Switch(context:New('SlashNext'), db:GetNextEnabled() and "classic" or "next")
      return
    end
    self:Open()
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbanchor", function()
    -- A BetterBags Next bag has no anchor.
    if addon.Bags.Backpack.anchor then
      addon.Bags.Backpack.anchor:Activate()
      addon.Bags.Backpack.anchor:Show()
    end
    if addon.Bags.Bank and addon.Bags.Bank.anchor then
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

  -- The bags switched design from a menu (next.md §11): the checkbox shows it.
  events:RegisterMessage('bags/DesignChanged', function()
    self.configFrame:ReloadAllFormElements()
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
