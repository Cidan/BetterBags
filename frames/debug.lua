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

---@class DebugWindow: AceModule
---@field frame ScrollingFlatPanelTemplate
---@field rows number
---@field tabFrame Tab
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
  self.frame = CreateFrame("Frame", "BetterBagsDebugWindow", UIParent, "ScrollingFlatPanelTemplate") --[[@as ScrollingFlatPanelTemplate]]
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

  -- Add default "Debug Log" tab
  self.tabFrame:AddTab(ctx, "Debug Log")
  self.tabFrame:SetTabByIndex(ctx, 1)

  -- Create content frames for each tab
  self.contentFrames = {}
  self.contentFrames[1] = self:CreateDebugLogFrame()

  self.frame.ClosePanelButton:RegisterForClicks("RightButtonUp", "LeftButtonUp")

  self.frame.ClosePanelButton:SetScript("OnClick", function(_, e)
    local ectx = context:New('DebugFrameCloseClick')
    if e == "LeftButton" then
      database:SetDebugMode(false)
      events:SendMessage('config/DebugMode', ectx, false)
    elseif e == "RightButton" then
      events:SendMessage('debug/ClearLog', ectx)
    end
  end)

  events:GroupBucketEvent({}, {'debug/LogAdded'}, function()
    self.provider:InsertTable(self.cells)
    wipe(self.cells)
    self.frame.ScrollBox:ScrollToEnd()
  end)

  events:RegisterMessage('config/DebugMode', function(_, enabled)
    if enabled then
      self.frame:Show()
    else
      self.frame:Hide()
    end
  end)

  events:RegisterMessage('debug/ClearLog', function()
    self.provider:Flush()
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
---@return Frame
function debugWindow:CreateDebugLogFrame()
  local frame = CreateFrame("Frame", nil, self.frame)
  frame:SetAllPoints(self.frame)

  frame.ScrollBox = self.frame.ScrollBox
  frame.ScrollBar = self.frame.ScrollBar

  frame.ScrollBox:SetInterpolateScroll(true)
  frame.ScrollBar:SetInterpolateScroll(true)
  local view = CreateScrollBoxListLinearView()
  view:SetElementInitializer("BetterBagsDebugListButton", initDebugListItem)
  view:SetPadding(4,4,8,4,0)
  view:SetExtent(20)
  ScrollUtil.InitScrollBoxListWithScrollBar(frame.ScrollBox, frame.ScrollBar, view)
  frame.ScrollBox:GetUpperShadowTexture():ClearAllPoints()
  frame.ScrollBox:GetLowerShadowTexture():ClearAllPoints()
  frame.ScrollBox:SetDataProvider(self.provider)

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