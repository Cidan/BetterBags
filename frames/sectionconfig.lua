local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class List: AceModule
local list = addon:GetModule('List')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class SectionConfig: AceModule
local sectionConfig = addon:NewModule('SectionConfig')

---@class SectionConfigItem
---@field frame Frame
---@field label FontString
local sectionConfigItem = {}

---@class SectionConfigFrame
---@field frame Frame
---@field content ListFrame
---@field package fadeIn AnimationGroup
---@field package fadeOut AnimationGroup
local sectionConfigFrame = {}

---@type table<string, number>
addon.fakeDatabase = {}

---@param button BetterBagsSectionConfigListButton
---@param elementData table
function sectionConfigFrame:initSectionItem(button, elementData)
  -- Initial setup.
  if not button.Init then
    button.Init = true
    button:SetHeight(35)
    button.Enabled = button:CreateTexture(nil, "OVERLAY")
    button.Enabled:SetSize(24, 24)
    button.Enabled:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.Category = button:CreateFontString(nil, "OVERLAY")
    button.Category:SetHeight(35)
    button.Category:SetPoint("LEFT", button.Enabled, "RIGHT", 0, 0)
    button:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
  end


  if elementData.header then
    button.Category:SetFontObject("GameFontNormal")
    button.Category:SetTextColor(1, .81960791349411, 0, 1)
  else
    button.Category:SetFontObject("Game12Font")
    button.Category:SetTextColor(1, 1, 1)
  end

  button.Category:SetText(elementData.title)

  if addon.fakeDatabase[elementData.title] then
    button.Enabled:SetTexture("Interface\\raidframe\\readycheck-ready")
  else
      button.Enabled:SetTexture("")
  end
  button:SetScript("OnMouseDown", function(_, key)
    if key == "RightButton" then
      if addon.fakeDatabase[elementData.title] then
        local lastEnabled = self:GetLastEnabledItem()
        addon.fakeDatabase[elementData.title] = nil
        button.Enabled:SetTexture("")
        self.content.provider:MoveElementDataToIndex(elementData, lastEnabled == 0 and 1 or lastEnabled)
        --button.Enabled:SetTexture("Interface\\raidframe\\readycheck-notready")
      else
        button.Enabled:SetTexture("Interface\\raidframe\\readycheck-ready")
        local lastEnabled = self:GetLastEnabledItem()
        addon.fakeDatabase[elementData.title] = lastEnabled == 0 and 1 or lastEnabled + 1
        self.content.provider:MoveElementDataToIndex(elementData, lastEnabled == 0 and 1 or lastEnabled + 1)
      end
      events:SendMessage('bags/FullRefreshAll')
    end
  end)
end

---@param button BetterBagsSectionConfigListButton
---@param elementData table
function sectionConfigFrame:resetSectionItem(button, elementData)
  _ = elementData
  _ = button
end

function sectionConfigFrame:AddSection(name)
  if self.content:HasItem({ title = name }) then
    return
  end
  self.content:AddToStart({ title = name })
end

function sectionConfigFrame:Wipe()
  self.content:Wipe()
end

---@return number
function sectionConfigFrame:GetLastEnabledItem()
  local enabledIndex = 0
  local itemList = self.content:GetAllItems()
  for index, item in pairs(itemList) do
    if addon.fakeDatabase[item.title] then
      enabledIndex = index
    end
  end
  return enabledIndex
end

function sectionConfigFrame:Show()
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  self.fadeIn:Play()
end

function sectionConfigFrame:Hide()
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  self.fadeOut:Play()
end

function sectionConfigFrame:IsShown()
  return self.frame:IsShown()
end

---@param kind BagKind
---@param parent Frame
---@return SectionConfigFrame
function sectionConfig:Create(kind, parent)
  local sc = setmetatable({}, { __index = sectionConfigFrame })
  sc.frame = CreateFrame("Frame", nil, parent, "DefaultPanelTemplate") --[[@as Frame]]
  sc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  sc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  sc.frame:SetWidth(300)
  sc.frame:SetTitle("Configure Categories")
  sc.frame:Hide()
  sc.fadeIn, sc.fadeOut = animations:AttachFadeAndSlideLeft(sc.frame)
  sc.content = list:Create(sc.frame)
  sc.content.frame:SetAllPoints()

  -- Setup the create and destroy functions for items on the list.
  sc.content:SetupDataSource("BetterBagsSectionConfigListButton", function(f, data)
    ---@cast f BetterBagsSectionConfigListButton
    sc:initSectionItem(f, data)
  end,
  function(f, data)
    ---@cast f BetterBagsSectionConfigListButton
    sc:resetSectionItem(f, data)
  end)

  -- Setup the callback for when an item is moved.
  sc.content:SetCanReorder(true, function(_, elementData, currentIndex, newIndex)

    -- Headers can never be moved.
    if elementData.header then
      -- Use the manual remove/insert to avoid an infinite loop.
      sc.content.provider:RemoveIndex(newIndex)
      sc.content.provider:InsertAtIndex(elementData, currentIndex)
      return
    end

    if addon.fakeDatabase[elementData.title] then
      if newIndex ~= 1 then
        local previousIndex = sc.content:GetIndex(newIndex - 1)
        if not addon.fakeDatabase[previousIndex.title] then
          addon.fakeDatabase[elementData.title] = 1
          sc.content.provider:MoveElementDataToIndex(elementData, 1)
          return
        end
      end
    else
      local nextIndex = sc.content:GetIndex(newIndex + 1)
      if nextIndex and addon.fakeDatabase[nextIndex.title] then
        local lastEnabled = sc:GetLastEnabledItem()
        addon.fakeDatabase[nextIndex.title] = lastEnabled == 0 and 1 or lastEnabled
        sc.content.provider:MoveElementDataToIndex(elementData, lastEnabled == 0 and 1 or lastEnabled)
        return
      end
    end
    if addon.fakeDatabase[elementData.title] then
      addon.fakeDatabase[elementData.title] = newIndex
    end
    events:SendMessage('bags/FullRefreshAll')
  end)

  sc.content:AddToStart({ title = "Pinned", header = true })
  sc.content:AddToStart({ title = "Automatically Sorted", header = true })

  local drawEvent = kind == const.BAG_KIND.BACKPACK and 'bags/Draw/Backpack/Done' or 'bags/Draw/Bank/Done'
  events:RegisterMessage(drawEvent, function()
    ---@type string[]
    local names = {}
    for sName in pairs(kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack.currentView.sections or addon.Bags.Bank.currentView.sections) do
      table.insert(names, sName)
    end
    for sName in pairs(categories:GetAllCategories()) do
      table.insert(names, sName)
    end
    table.sort(names)
    for _, sName in ipairs(names) do
      sc:AddSection(sName)
    end
  end)

  return sc
end
