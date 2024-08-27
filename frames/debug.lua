local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Tabs: AceModule
local tabs = addon:GetModule('Tabs')

---@class List: AceModule
local list = addon:GetModule('List')

---@class ItemBrowser: AceModule
local itemBrowser = addon:GetModule('ItemBrowser')

---@class DebugWindow: AceModule
---@field frame Frame
---@field rows number
---@field tabFrame Tab
---@field contentFrames any[]
local debugWindow = addon:NewModule('DebugWindow')


---@param button BetterBagsDebugListButton
---@param elementData table
local function initDebugListItem(button, elementData)
  button.RowNumber:SetText(format("%s", elementData.row))
  button.Category:SetText(elementData.title)
  button.Category:SetPoint("LEFT", button.RowNumber, "RIGHT", 10, 0)
  button.Message:SetText(elementData.message)
  button.Message:SetPoint("LEFT", button.Category, "RIGHT", 10, 0)
end

---@param ctx Context
function debugWindow:Create(ctx)
  self.cells = {}
  self.rows = 0
  self.provider = CreateDataProvider()
  self.frame = CreateFrame("Frame", "BetterBagsDebugWindow", UIParent, "DefaultPanelFlatTemplate") --[[@as Frame]]
  self.frame:SetPoint("CENTER")
  self.frame:SetSize(800, 600)
  self.frame:SetMovable(true)
  self.frame:EnableMouse(true)
  self.frame:RegisterForDrag("LeftButton")
  self.frame:SetScript("OnDragStart", self.frame.StartMoving)
  self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
  self.frame:SetTitle("BetterBags Debug Window")

  -- Create tab frame
  self.tabFrame = tabs:Create(self.frame)
  self.tabFrame:SetClickHandler(function(_, id, button)
    if button == "LeftButton" then
      self:SwitchTab(id)
      return true
    end
    return false
  end)

  -- Add default "Debug Log" tab and new "Items" tab
  self.tabFrame:AddTab(ctx, "Debug Log")
  self.tabFrame:AddTab(ctx, "Items")
  self.tabFrame:SetTabByIndex(ctx, 1)

  -- Create content frames for each tab
  self.contentFrames = {}
  self.contentFrames[1] = self:CreateDebugLogFrame()
  self.contentFrames[2] = self:CreateItemsFrame()

  local closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButtonDefaultAnchors")
  closeButton:RegisterForClicks("RightButtonUp", "LeftButtonUp")

  closeButton:SetScript("OnClick", function(_, e)
    local ectx = context:New('DebugFrameCloseClick')
    if e == "LeftButton" then
      database:SetDebugMode(false)
      events:SendMessage('config/DebugMode', ectx, false)
    elseif e == "RightButton" then
      events:SendMessage('debug/ClearLog', ectx)
    end
  end)

  events:GroupBucketEvent({}, {'debug/LogAdded'}, function()
    self.contentFrames[1]:InsertTable(self.cells)
    self.contentFrames[1]:ScrollToEnd()
    wipe(self.cells)
  end)

  events:RegisterMessage('config/DebugMode', function(_, enabled)
    if enabled then
      self.frame:Show()
    else
      self.frame:Hide()
    end
  end)

  events:RegisterMessage('debug/ClearLog', function()
    self.contentFrames[1]:Wipe()
    self.cells = {}
    self.rows = 0
  end)

  if database:GetDebugMode() then
    self.frame:Show()
  else
    self.frame:Hide()
  end
  self:AddLogLine(ctx, "Debug", "debug window created")
end

---@param ctx Context
---@param title string
---@param message? string
function debugWindow:AddLogLine(ctx, title, message)
  if not self.frame:IsVisible() then
    return
  end
  table.insert(self.cells, {
    row=self.rows,
    title=title,
    message=message
  })
  self.rows = self.rows + 1
  events:SendMessage('debug/LogAdded', ctx)
end

---CreateDebugLogFrame creates the frame for the debug log tab.
---@return ListFrame
function debugWindow:CreateDebugLogFrame()
  local frame = list:Create(self.frame)
  frame.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -5)
  frame.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 5)
  frame:SetupDataSource("BetterBagsDebugListButton", initDebugListItem, function()end)
  return frame
end

---CreateItemsFrame creates the frame for the Items tab.
---@return ItemBrowserFrame
function debugWindow:CreateItemsFrame()
  local frame = itemBrowser:Create(self.frame)
  frame:GetFrame():SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -5)
  frame:GetFrame():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 5)
  frame:Hide() -- Hide by default as Debug Log is the initial tab
  return frame
end

---SwitchTab switches to the specified tab.
---@param tabId number
function debugWindow:SwitchTab(tabId)
  for id, frame in pairs(self.contentFrames) do
    if id == tabId then
      frame:Show()
    else
      frame:Hide()
    end
  end
end