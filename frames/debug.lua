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
---@field row FontString
---@field category FontString
---@field message FontString
local debugCell = {}

---@class DebugWindow: AceModule
---@field frame Frame
---@field content Grid
---@field rows number
---@field _pool ObjectPool
local debugWindow = addon:NewModule('DebugWindow')

---@return DebugCell
function debugWindow:NewCell()
  local cell = setmetatable({}, { __index = debugCell }) --[[@as DebugCell]]
  cell.frame = CreateFrame("Frame", nil)
  cell.frame:SetSize(self.content:GetContainer():GetWidth(), 20)
  cell.frame:SetScript("OnMouseWheel", function(_, delta)
    self.content:GetContainer():OnMouseWheel(delta)
  end)
  cell.frame:EnableMouse(true)
  cell.row = cell.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  cell.row:SetPoint("LEFT", 0, 0)
  cell.row:SetText(format("%s", self.rows))
  cell.row:SetTextColor(1, 1, 1)
  cell.row:SetWidth(30)
  cell.row:SetJustifyH("LEFT")
  cell.category = cell.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  cell.category:SetPoint("LEFT", cell.row, "RIGHT", 10, 0)
  cell.category:SetJustifyH("LEFT")
  cell.category:SetTextColor(1, 1, 1)
  cell.category:SetWidth(120)
  cell.category:SetWordWrap(false)
  cell.category:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  cell.message = cell.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  cell.message:SetPoint("LEFT", cell.category, "RIGHT", 5, 0)
  cell.message:SetTextColor(0.8, 0.8, 0.8)
  return cell
end

function debugWindow:_ResetCell(cell)
  cell.frame:Hide()
end

function debugWindow:SetupPool()
  print("BetterBags: Creating Debug Pool")
  self._pool = CreateObjectPool(function() return self:NewCell() end, self._ResetCell)
  self._pool:SetResetDisallowedIfNew(true)
  ---@type DebugCell[]
  local objs = {}
  for _ = 1, 1000 do
    local o = self._pool:Acquire()
    table.insert(objs, o)
  end
  for _, o in pairs(objs) do
    self._pool:Release(o)
  end
end

function debugWindow:Create()
  self.frame = CreateFrame("Frame", "BetterBagsDebugWindow", UIParent, "DefaultPanelFlatTemplate") --[[@as Frame]]
  self.frame:SetPoint("CENTER")
  self.frame:SetSize(800, 600)
  self.frame:SetMovable(true)
  self.frame:EnableMouse(true)
  self.frame:RegisterForDrag("LeftButton")
  self.frame:SetScript("OnDragStart", self.frame.StartMoving)
  self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
  self.frame:SetTitle("BetterBags Debug Window")
  self.rows = 0

  self.content = grid:Create(self.frame)
  self.content:GetContainer():SetPoint("TOPLEFT", 10, -35)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", -10, 10)
  self.content.maxCellWidth = 1

  events:RegisterMessage('config/DebugMode', function(_, enabled)
    if enabled then
      self.frame:Show()
      if not self._pool then
        self:SetupPool()
      end
    else
      self.frame:Hide()
    end
  end)
  if database:GetDebugMode() then
    self.frame:Show()
    debugWindow:SetupPool()
  else
    self.frame:Hide()
  end
  self:AddLogLine("Debug", "debug window created")
end

function debugWindow:AddLogLine(title, message)
  if not self.frame:IsVisible() then
    return
  end
  local cell = self._pool:Acquire()

  cell.row:SetText(format("%s", self.rows))
  cell.category:SetText(format("%s", title))
  cell.category:SetScript("OnEnter", function()
    GameTooltip:SetOwner(cell.frame, "ANCHOR_LEFT")
    GameTooltip:SetText(title)
    GameTooltip:Show()
  end)

  cell.message:SetText(message)

  self.content:AddCell(tostring(self.rows), cell)
  self.content:Draw()
  self.content:GetContainer():FullUpdate()
  self.content:GetContainer():ScrollToEnd()
  self.rows = self.rows + 1
end