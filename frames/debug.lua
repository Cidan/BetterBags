local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class DebugCell
---@field frame Frame
---@field category FontString
---@field message FontString
local debugCell = {}

---@class DebugWindow: AceModule
---@field frame Frame
---@field content Grid
---@field rows number
local debugWindow = addon:NewModule('DebugWindow')

function debugWindow:Create()
  self.frame = CreateFrame("Frame", "BetterBagsDebugWindow", UIParent, "BackdropTemplate") --[[@as Frame]]
  self.frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
      left = 4,
      right = 4,
      top = 4,
      bottom = 4,
    },
  })
  self.frame:SetBackdropColor(0, 0, 0, 0.9)
  self.frame:SetPoint("CENTER")
  self.frame:SetSize(800, 600)
  self.frame:SetMovable(true)
  self.frame:EnableMouse(true)
  self.frame:RegisterForDrag("LeftButton")
  self.frame:SetScript("OnDragStart", self.frame.StartMoving)
  self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
  self.rows = 0

  self.content = grid:Create(self.frame)
  self.content:GetContainer():SetPoint("TOPLEFT", 10, -10)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", -10, 10)
  self.content.maxCellWidth = 1

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
  local cell = setmetatable({}, { __index = debugCell }) --[[@as Cell]]
  cell.frame = CreateFrame("Frame", nil)
  cell.frame:SetSize(self.content:GetContainer():GetWidth(), 20)
  cell.frame:SetScript("OnMouseWheel", function(_, delta)
    self.content:GetContainer():OnMouseWheel(delta)
  end)
  cell.frame:EnableMouse(true)
  --[[
  local highlight = cell.frame:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface/QuestFrame/UI-QuestLogTitleHighlight")
  highlight:SetVertexColor(1, 222/255, 100/255, 0.5)
  highlight:SetBlendMode("BLEND")
  highlight:SetAllPoints()
  --]]
  --[[
  cell.frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(cell.frame, "ANCHOR_TOP")
    GameTooltip:SetText(message)
    GameTooltip:Show()
  end)
  cell.frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  ]]--
  local row = cell.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  row:SetPoint("LEFT", 0, 0)
  row:SetText(format("%s", self.rows))
  row:SetTextColor(1, 1, 1)
  row:SetWidth(20)
  row:SetJustifyH("LEFT")
  local category = cell.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  category:SetPoint("LEFT", row, "RIGHT", 10, 0)
  category:SetText(format("%s", title))
  category:SetJustifyH("LEFT")
  category:SetTextColor(1, 1, 1)
  category:SetWidth(120)
  category:SetWordWrap(false)
  category:SetScript("OnEnter", function()
    GameTooltip:SetOwner(cell.frame, "ANCHOR_LEFT")
    GameTooltip:SetText(title)
    GameTooltip:Show()
  end)
  category:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  local m = cell.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  m:SetPoint("LEFT", category, "RIGHT", 5, 0)
  m:SetText(message)
  m:SetTextColor(0.8, 0.8, 0.8)
  self.content:AddCell(tostring(self.rows), cell)
  self.content:Draw()
  self.content:GetContainer():FullUpdate()
  self.content:GetContainer():ScrollToEnd()
  self.rows = self.rows + 1
end