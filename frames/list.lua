local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class (exact) List: AceModule
---@field private pool ObjectPool
local list = addon:NewModule('List')

---@class (exact) ListScrollFrame: Frame
---@field ScrollBar MinimalScrollBar|EventFrame
---@field ScrollBox WowScrollBox|Frame
---@field ScrollView Frame
---@field ContentFrame Frame|ResizeLayoutFrame
---@field cells Frame[]
local listScrollFrame = {}


function list:OnEnable()
  self.pool = CreateObjectPool(self._OnCreate, self._OnRelease)
  local l = self:Create()
  l:SetParent(UIParent)
  l:SetPoint("CENTER")
  l:SetSize(400, 400)
  --[[
  for i = 1, 100 do
    local cell = CreateFrame("Frame", nil, nil, "BackdropTemplate")
    cell:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    cell:SetSize(400, 40)
    l:Add(cell)
  end
  ]]--
end

---@private
---@return ListScrollFrame
function list:_OnCreate()
  local l = Mixin(CreateFrame("Frame"), listScrollFrame) --[[@as ListScrollFrame]]
  l:OnLoad()
  l.cells = {}
  return l
end

---@private
---@param l ListScrollFrame
function list:_OnRelease(l)
end

---@return ListScrollFrame
function list:Create()
  return self.pool:Acquire()
end

function listScrollFrame:OnLoad()
  self.ScrollBar = CreateFrame("EventFrame", nil, self, "MinimalScrollBar")
  self.ScrollBar:SetPoint("TOPRIGHT")
  self.ScrollBar:SetPoint("BOTTOMRIGHT")
  self.ScrollBar:SetInterpolateScroll(true)

  self.ScrollBox = CreateFrame("Frame", nil, self, "WowScrollBox")
  self.ScrollBox:SetPoint("TOPLEFT")
  self.ScrollBox:SetPoint("BOTTOMRIGHT", self.ScrollBar, "BOTTOMLEFT")
  self.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateQueued)
  self.ScrollBox:SetInterpolateScroll(true)

  self.ScrollView = CreateScrollBoxLinearView()
  self.ScrollView:SetPanExtent(50)

  self.ContentFrame = CreateFrame("Frame", nil, self.ScrollBox, "ResizeLayoutFrame")
  self.ContentFrame.scrollable = true
  self.ContentFrame:SetPoint("TOPLEFT", self.ScrollBox)
  self.ContentFrame:SetPoint("TOPRIGHT", self.ScrollBox)
  self.ContentFrame:SetScript("OnSizeChanged", GenerateClosure(self.OnContentSizeChanged, self))

  ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, self.ScrollView)
end

function listScrollFrame:OnContentSizeChanged()
  self.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
end

---@param cell Frame
function listScrollFrame:Add(cell)
  cell:SetParent(self.ContentFrame --[[@as Frame]])
  if #self.cells > 0 then
    cell:SetPoint("TOP", self.cells[#self.cells], "BOTTOM")
  else
    cell:SetPoint("TOP")
  end
  tinsert(self.cells, cell)
  cell:SetWidth(self:GetWidth() - 20)
  cell:Show()
  self.ContentFrame:MarkDirty()
end

list:Enable()
