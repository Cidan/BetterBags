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

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class SectionItemList: AceModule
local sectionItemList = addon:GetModule('SectionItemList')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class SectionConfig: AceModule
local sectionConfig = addon:NewModule('SectionConfig')

---@class SectionConfigElement
---@field title string
---@field header? boolean
---@field index? number

---@class BetterBagsSectionConfigListButton: Button
---@field Expand Button
---@field Category FontString
---@field Note FontString
---@field Visible Button
---@field Init boolean

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
---@field package itemList SectionItemListFrame
local sectionConfigFrame = {}

---@param category string
---@return boolean
function sectionConfigFrame:OnReceiveDrag(category)
  local kind, id = GetCursorInfo()
  if kind ~= "item" or not tonumber(id) then return false end
  ClearCursor()
  local itemid = tonumber(id) --[[@as number]]
  database:SaveItemToCategory(itemid, category)
  events:SendMessage('bags/FullRefreshAll')
  return true
end

---@param button BetterBagsSectionConfigListButton
---@param elementData table
function sectionConfigFrame:initSectionItem(button, elementData)

  -- Initial setup, create the button here.
  if not button.Init then
    button.Init = true
    button:SetHeight(30)
    button.Expand = CreateFrame("Button", nil, button)
    button.Expand:SetSize(24, 24)
    button.Expand:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.Visible = CreateFrame("Button", nil, button)
    button.Visible:SetSize(20, 20)
    button.Visible:SetPoint("LEFT", button.Expand, "RIGHT", 5, 0)
    button.Category = button:CreateFontString(nil, "OVERLAY")
    button.Category:SetHeight(30)
    button.Category:SetPoint("LEFT", button.Visible, "RIGHT", 5, 0)
    button.Note = button:CreateFontString(nil, "OVERLAY")
    button.Note:SetHeight(30)
    button.Note:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.Note:SetTextColor(0.8, 0.8, 0.8, 1)
    button.Note:SetFontObject(fonts.UnitFrame12White)
    button:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0, 0, 0, 0)
    button.Expand:SetNormalTexture("Interface\\glues\\common\\glue-leftarrow-button-up")
    button.Expand:SetPushedTexture("Interface\\glues\\common\\glue-leftarrow-button-down")
    button.Expand:SetHighlightTexture("Interface\\glues\\common\\glue-leftarrow-button-highlight", "ADD")
    button.Visible:SetNormalTexture("Interface\\AddOns\\BetterBags\\textures\\visible.blp")
    button.Visible:SetHighlightTexture("Interface\\Addons\\BetterBags\\textures\\visible.blp")
    button.Visible:SetScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_LEFT")
      GameTooltip:AddLine("Show or hide this category in the bags.", 1, .81960791349411, 0, true)
      GameTooltip:Show()
    end)
  end

  -- Set the category font info for the button depending on if it's a header or not.
  if elementData.header then
    button.Category:SetFontObject(fonts.UnitFrame12Yellow)
    button.Expand:Hide()
    button.Visible:Hide()
  else
    button.Category:SetFontObject(fonts.UnitFrame12White)
    button.Expand:SetScript("OnClick", function()
      self.itemList:ShowCategory(elementData.title)
    end)
    button.Expand:Show()
    button.Visible:Show()
    if not categories:DoesCategoryExist(elementData.title) then
      button.Expand:Disable()
      button.Expand:GetNormalTexture():SetDesaturated(true)
    else
      button.Expand:Enable()
      button.Expand:GetNormalTexture():SetDesaturated(false)
    end

    if categories:IsCategoryShown(elementData.title) then
      button.Visible:GetNormalTexture():SetVertexColor(1, 1, 1, 1)
    else
      button.Visible:GetNormalTexture():SetVertexColor(0.6, 0.1, 0.1, 1)
    end
    button.Visible:SetScript("OnClick", function()
      categories:ToggleCategoryShown(elementData.title)
      if categories:IsCategoryShown(elementData.title) then
        button.Visible:GetNormalTexture():SetVertexColor(1, 1, 1, 1)
      else
        button.Visible:GetNormalTexture():SetVertexColor(0.6, 0.1, 0.1, 1)
      end
    end)
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
    button.Expand:SetScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_LEFT")
      GameTooltip:AddLine("Open the sidebar for configuring items in this category.", 1, .81960791349411, 0, true)
      GameTooltip:Show()
    end)

    button.Expand:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

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
        GameTooltip:AddDoubleLine("Right Click", "Open Menu")
        GameTooltip:AddDoubleLine("Shift Right Click", "Hide or Show Category")
      else
        GameTooltip:AddLine([[
          Dynamic categories can't be enabled or disabled (yet).
          Drag this category to Pinned to keep it at the top of your bags, or to Automatically Sorted to have it sorted with the rest of your items.]], 1, 1, 1, true)
          GameTooltip:AddLine("\n", 1, 1, 1, true)
          GameTooltip:AddDoubleLine("Shift Left Click", format("Move %s to the top of your bags", elementData.title))
          GameTooltip:AddDoubleLine("Shift Right Click", "Hide or Show Category")
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

  button:SetScript("OnMouseDown", function(_, b)
    if b ~= "RightButton" or IsShiftKeyDown() then
      return
    end
    if elementData.header then
      return
    end
    local menuOptions = {}
    if categories:DoesCategoryExist(elementData.title) then
      table.insert(menuOptions,{
        text = L:G("Delete Category"),
        notCheckable = true,
        hasArrow = false,
        func = function()
          question:YesNo("Delete Category", format("Are you sure you want to delete the category %s?", elementData.title), function()
            self.content.provider:Remove(elementData)
            self:UpdatePinnedItems()
            if self.itemList:IsShown() and self.itemList:IsCategory(elementData.title) then
              self.itemList:Hide(function()
                categories:DeleteCategory(elementData.title)
              end)
            else
              categories:DeleteCategory(elementData.title)
            end
          end, function()
          end)
        end
      })
    end
--    table.insert(menuOptions, {
--      text = L:G("Hide Category"),
--      hasArrow = false,
--      checked = function()
--        return not categories:IsCategoryShown(elementData.title)
--      end,
--      func = function()
--        categories:ToggleCategoryShown(elementData.title)
--      end
--    })
    contextMenu:Show(menuOptions)
  end)

  if categories:DoesCategoryExist(elementData.title) then
    -- Script handler for dropping items into a category.
    button:SetScript("OnReceiveDrag", function()
      if elementData.header then
        return
      end
      self:OnReceiveDrag(elementData.title)
    end)
  end
  button:SetScript("OnMouseUp", function(_, key)
    -- Headers can't be clicked.
    if elementData.header then
      return
    end

    -- Toggle the category from containing items.
    if key == "LeftButton" then
      if self:OnReceiveDrag(elementData.title) then
        return
      end
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
  button:SetScript("OnMouseDown", nil)
  button:SetScript("OnMouseUp", nil)
  button:SetScript("OnReceiveDrag", nil)
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
  if self.itemList:IsShown() then
    self.itemList:Hide()
  end
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
  sc.frame = CreateFrame("Frame", parent:GetName().."SectionConfig", parent) --[[@as Frame]]
  sc.frame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMLEFT', -10, 0)
  sc.frame:SetPoint('TOPRIGHT', parent, 'TOPLEFT', -10, 0)
  sc.frame:SetWidth(300)
  sc.frame:SetIgnoreParentScale(true)
  sc.frame:SetScale(UIParent:GetScale())
  sc.frame:Hide()
  sc.kind = kind
  sc.fadeIn, sc.fadeOut = animations:AttachFadeAndSlideLeft(sc.frame)
  sc.content = list:Create(sc.frame)
  sc.content.frame:SetAllPoints()

  themes:RegisterSimpleWindow(sc.frame, L:G("Configure Categories"))
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

    if newIndex == 1 then
      sc.content.provider:RemoveIndex(newIndex)
      sc.content.provider:InsertAtIndex(elementData, 2)
    end

    sc:UpdatePinnedItems()
    events:SendMessage('bags/FullRefreshAll')
  end)

  sc.content:AddToStart({ title = "Pinned", header = true })
  sc:LoadPinnedItems()
  sc.content:AddToStart({ title = "Automatically Sorted", header = true })

  -- Create the pop out item list.
  sc.itemList = sectionItemList:Create(sc.frame)

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
    if sc.itemList:IsShown() then
      sc.itemList:Redraw()
    end
  end)

  return sc
end
