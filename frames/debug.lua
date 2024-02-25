local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class DebugWindow: AceModule
---@field frame ScrollingFlatPanelTemplate
---@field rows number
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

function debugWindow:Create()
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
  self.frame.ScrollBox:SetInterpolateScroll(true)
  self.frame.ScrollBar:SetInterpolateScroll(true)
  local view = CreateScrollBoxListLinearView()
  view:SetElementInitializer("BetterBagsDebugListButton", initDebugListItem)
  view:SetPadding(4,4,8,4,0)
  view:SetExtent(20)
  ScrollUtil.InitScrollBoxListWithScrollBar(self.frame.ScrollBox, self.frame.ScrollBar, view)
  self.frame.ScrollBox:GetUpperShadowTexture():ClearAllPoints()
  self.frame.ScrollBox:GetLowerShadowTexture():ClearAllPoints()
  self.frame.ScrollBox:SetDataProvider(self.provider)

  self.frame.ClosePanelButton:SetScript("OnClick", function()
    database:SetDebugMode(false)
    events:SendMessage('config/DebugMode', false)
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

  if database:GetDebugMode() then
    self.frame:Show()
  else
    self.frame:Hide()
  end
  self:AddLogLine("Debug", "debug window created")
end

function debugWindow:AddLogLine(title, message)
  if not self.frame:IsVisible() then
    return
  end
  table.insert(self.cells, {
    row=self.rows,
    title=title,
    message=message
  })
  self.rows = self.rows + 1
  events:SendMessage('debug/LogAdded')
end