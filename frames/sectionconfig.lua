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

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class SectionConfig: AceModule
local sectionConfig = addon:NewModule('SectionConfig')

---@class SectionConfigElement
---@field title string
---@field header? boolean
---@field index? number

---@class SectionConfigItem
---@field frame Frame
---@field label FontString
local sectionConfigItem = {}

---@class SectionConfigFrame
---@field frame Frame
---@field content ListFrame
---@field package kind BagKind
---@field package fadeIn AnimationGroup
---@field package fadeOut AnimationGroup
local sectionConfigFrame = {}

---@param button BetterBagsSectionConfigListButton
---@param elementData table
function sectionConfigFrame:initSectionItem(button, elementData)

  -- Initial setup, create the button here.
  if not button.Init then
    button.Init = true
    button:SetHeight(30)
    button.Enabled = button:CreateTexture(nil, "OVERLAY")
    button.Enabled:SetSize(24, 24)
    button.Enabled:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.Category = button:CreateFontString(nil, "OVERLAY")
    button.Category:SetHeight(30)
    button.Category:SetPoint("LEFT", button.Enabled, "RIGHT", 0, 0)
    button:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0)
  end

  -- Set the category font info for the button depending on if it's a header or not.
  if elementData.header then
    button.Category:SetFontObject("GameFontNormal")
    button.Category:SetTextColor(1, .81960791349411, 0, 1)
  else
    button.Category:SetFontObject("Game12Font")
    button.Category:SetTextColor(1, 1, 1)
  end

  -- Set the backdrop initial state.
  if categories:IsCategoryEnabled(self.kind, elementData.title) then
    button:SetBackdropColor(1, 1, 0, .2)
  else
    if elementData.header then
      button:SetBackdropColor(0, 0, 0, .3)
    else
      button:SetBackdropColor(0, 0, 0, 0)
    end
  end

  if not elementData.header then
    button:SetScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_LEFT")
      GameTooltip:AddLine(elementData.title, 1, .81960791349411, 0, true)
      if categories:DoesCategoryExist(elementData.title) then
        GameTooltip:AddLine([[
        Left click to enable or disable items from being added to this category.
        Drag this category to Pinned to keep it at the top of your bags, or to Automatically Sorted to have it sorted with the rest of your items.]], 1, 1, 1, true)
        GameTooltip:AddLine("\n", 1, 1, 1, true)
        GameTooltip:AddDoubleLine("Left Click", "Enable or Disable Category")
        GameTooltip:AddDoubleLine("Shift Left Click", format("Move %s to the top of your bags", elementData.title))
        GameTooltip:AddDoubleLine("Right Click", "Hide or Show Category")
      else
        GameTooltip:AddLine([[
          Dynamic categories can't be enabled or disabled (yet).
          Drag this category to Pinned to keep it at the top of your bags, or to Automatically Sorted to have it sorted with the rest of your items.]], 1, 1, 1, true)
          GameTooltip:AddLine("\n", 1, 1, 1, true)
          GameTooltip:AddDoubleLine("Shift Left Click", format("Move %s to the top of your bags", elementData.title))
          GameTooltip:AddDoubleLine("Right Click", "Hide or Show Category")
      end
      GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  else
    button:SetScript("OnEnter", nil)
  end
  -- Set the text and icon for the button.
  button.Category:SetText(elementData.title)

  -- TODO(lobato): Instead of a check, have an X for hiding the category.
  --[[
  if addon.fakeDatabase[elementData.title] then
    button.Enabled:SetTexture("Interface\\raidframe\\readycheck-ready")
  else
      button.Enabled:SetTexture("")
  end
  --]]
  button:SetScript("OnMouseUp", function(_, key)
    -- Headers can't be clicked.
    if elementData.header then
      return
    end

    -- Toggle the category from containing items.
    if key == "LeftButton" then
      if IsShiftKeyDown() then
        self.content.provider:MoveElementDataToIndex(elementData, 2)
        self:UpdatePinnedItems()
      elseif categories:DoesCategoryExist(elementData.title) then
        if categories:IsCategoryEnabled(self.kind, elementData.title) then
          categories:DisableCategory(self.kind, elementData.title)
          button:SetBackdropColor(0, 0, 0, 0)
        else
          categories:EnableCategory(self.kind, elementData.title)
          button:SetBackdropColor(1, 1, 0, .2)
        end
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

---@param callback? fun()
function sectionConfigFrame:Show(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeIn.callback = function()
      self.fadeIn.callback = nil
      callback()
    end
  end
  self.fadeIn:Play()
end

---@param callback? fun()
function sectionConfigFrame:Hide(callback)
  PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG)
  if callback then
    self.fadeOut.callback = function()
      self.fadeOut.callback = nil
      callback()
    end
  end
  self.fadeOut:Play()
end

function sectionConfigFrame:IsShown()
  return self.frame:IsShown()
end

function sectionConfigFrame:UpdatePinnedItems()
  local itemList = self.content:GetAllItems()
  database:ClearCustomSectionSort(self.kind)
  local index, elementData = next(itemList)
  repeat
    if elementData.title ~= "Pinned" and not elementData.header then
      database:SetCustomSectionSort(self.kind, elementData.title, index - 1)
    end
    index, elementData = next(itemList, index)
  until elementData.title == "Automatically Sorted" and elementData.header
end

function sectionConfigFrame:LoadPinnedItems()
  local pinnedList = database:GetCustomSectionSort(self.kind)
  ---@type SectionConfigElement[]
  local sortedList = {}
  for title, index in pairs(pinnedList) do
    table.insert(sortedList, { title = title, index = index })
  end
  table.sort(sortedList, function(a, b)
    return a.index < b.index
  end)
  for _, element in ipairs(sortedList) do
    self.content.provider:Insert({title = element.title})
  end
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
  sc.kind = kind
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
    sc:UpdatePinnedItems()
    events:SendMessage('bags/FullRefreshAll')
  end)

  sc.content:AddToStart({ title = "Pinned", header = true })
  sc:LoadPinnedItems()
  sc.content:AddToStart({ title = "Automatically Sorted", header = true })

  local drawEvent = kind == const.BAG_KIND.BACKPACK and 'bags/Draw/Backpack/Done' or 'bags/Draw/Bank/Done'
  events:RegisterMessage(drawEvent, function()
    ---@type string[]
    local names = {}
    local bag = kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank
    if bag.currentView.bagview == const.BAG_VIEW.SECTION_GRID or bag.currentView.bagview == const.BAG_VIEW.LIST then
      for sName in pairs(bag.currentView.sections) do
        table.insert(names, sName)
      end
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
