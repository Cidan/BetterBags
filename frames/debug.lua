local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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

local function sanitizeForDump(val, seen)
  seen = seen or {}
  local t = type(val)
  if t == "function" or t == "userdata" or t == "thread" then
    return nil
  end
  if t ~= "table" then
    return val
  end

  -- Detect UIObject or frame
  if val[0] and type(val[0]) == "userdata" then
    return nil
  end

  if seen[val] then
    return seen[val]
  end

  local copy = {}
  seen[val] = copy

  for k, v in pairs(val) do
    local sk = sanitizeForDump(k, seen)
    local sv = sanitizeForDump(v, seen)
    if sk ~= nil and sv ~= nil then
      copy[sk] = sv
    end
  end

  -- Strip metatables as they can't be saved
  setmetatable(copy, nil)

  return copy
end


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
  -- Shift tabs right to align with frame edge
  self.tabFrame.frame:ClearAllPoints()
  self.tabFrame.frame:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 10, 2)
  self.tabFrame.frame:SetPoint("TOPRIGHT", self.frame, "BOTTOMRIGHT", 0, 2)
  self.tabFrame:SetClickHandler(function(_, id, button)
    if button == "LeftButton" then
      self:SwitchTab(id)
      return true
    end
    return false
  end)

  -- Add default "Debug Log", "Items", and "Dump" tabs
  self.tabFrame:AddTab(ctx, "Debug Log")
  self.tabFrame:AddTab(ctx, "Items")
  self.tabFrame:AddTab(ctx, "Dump")
  self.tabFrame:SetTabByIndex(ctx, 1)

  -- Create content frames for each tab
  self.contentFrames = {}
  self.contentFrames[1] = self:CreateDebugLogFrame()
  self.contentFrames[2] = self:CreateItemsFrame()
  self.contentFrames[3] = self:CreateDumpFrame()

  -- Use existing CloseButton from template if available, otherwise create one
  local closeButton = self.frame.CloseButton or CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
  closeButton:ClearAllPoints()
  closeButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 2, 2)
  closeButton:RegisterForClicks("RightButtonUp", "LeftButtonUp")

  closeButton:SetScript("OnClick", function(_, e)
    local ectx = context:New('DebugFrameCloseClick')
    if e == "LeftButton" then
      database:SetDebugMode(false)
      events:SendMessage(ectx, 'config/DebugMode', false)
    elseif e == "RightButton" then
      events:SendMessage(ectx, 'debug/ClearLog')
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
  events:SendMessage(ctx, 'debug/LogAdded')
end

---CreateDebugLogFrame creates the frame for the debug log tab.
---@return ListFrame
function debugWindow:CreateDebugLogFrame()
  local frame = list:Create(self.frame)
  frame.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -25)
  frame.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -5, 5)
  frame:SetupDataSource("BetterBagsDebugListButton", initDebugListItem, function()end)
  return frame
end

---CreateItemsFrame creates the frame for the Items tab.
---@return ItemBrowserFrame
function debugWindow:CreateItemsFrame()
  local frame = itemBrowser:Create(self.frame)
  frame:GetFrame():SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -25)
  frame:GetFrame():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -5, 5)
  frame:Hide() -- Hide by default as Debug Log is the initial tab
  return frame
end

---CreateDumpFrame creates the frame for the Dump tab.
---@return Frame
function debugWindow:CreateDumpFrame()
  local f = CreateFrame("Frame", nil, self.frame)
  f:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -25)
  f:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -5, 5)
  f:Hide()

  -- Add title and description
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -20)
  title:SetText("Debug Data Dump")

  local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  desc:SetWidth(760)
  desc:SetJustifyH("LEFT")
  desc:SetText("Dump your current full backpack item data to saved variables. This data will be serialized into the WTF folder configuration, which can be extracted and used as a test harness.")

  -- Status Label
  local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  status:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -30)

  -- Function to update status text
  function f.Update()
    local dump = database:GetDebugBackpackDump()
    local count = 0
    if dump then
      for _ in pairs(dump) do
        count = count + 1
      end
    end
    status:SetText(format("Current Dumped Items Count: %d", count))
  end

  -- Dump Button
  local dumpButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  dumpButton:SetSize(200, 35)
  dumpButton:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -20)
  dumpButton:SetText("Dump Backpack Items")

  addon.SetScript(dumpButton, "OnClick", function(_ctx)
    local itemsModule = addon:GetModule("Items")
    local slotInfo = itemsModule.slotInfo and itemsModule.slotInfo[const.BAG_KIND.BACKPACK]
    local backpackItems = slotInfo and slotInfo.itemsBySlotKey
    if backpackItems then
      local sanitized = sanitizeForDump(backpackItems)
      database:SetDebugBackpackDump(sanitized)
      f.Update()
      print("BetterBags: Dumped backpack items to saved variables!")
    else
      print("BetterBags Error: Backpack items not loaded or unavailable!")
    end
  end)

  -- Clear Button
  local clearButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearButton:SetSize(200, 35)
  clearButton:SetPoint("LEFT", dumpButton, "RIGHT", 20, 0)
  clearButton:SetText("Clear Dumped Data")

  addon.SetScript(clearButton, "OnClick", function(_ctx)
    database:SetDebugBackpackDump({})
    f.Update()
    print("BetterBags: Cleared dumped backpack items!")
  end)

  return f
end

---SwitchTab switches to the specified tab.
---@param tabId number
function debugWindow:SwitchTab(tabId)
  for id, frame in pairs(self.contentFrames) do
    if id == tabId then
      frame:Show()
      if id == 2 or id == 3 then
        frame:Update()
      end
    else
      frame:Hide()
    end
  end
end