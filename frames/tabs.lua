local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Tabs: AceModule
local tabs = addon:NewModule('Tabs')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class PanelTabButtonTemplate: Button
---@field Text FontString
---@field Left Texture
---@field Middle Texture
---@field Right Texture
---@field LeftActive Texture
---@field MiddleActive Texture
---@field RightActive Texture
---@field deselectedTextX number
---@field deselectedTextY number
---@field selectedTextX number
---@field selectedTextY number

---@class (exact) Tab
---@field frame Frame
---@field tabs table<string, Button>
---@field tabIndex Button[]
---@field selectedTab string
---@field clickHandler fun(name: string)
local tabFrame = {}

---@param name string
function tabFrame:AddTab(name)
  local tab = CreateFrame("button", format("%sTab%d", self.frame:GetName(), #self.tabIndex), self.frame)
  tab:SetNormalFontObject(GameFontNormalSmall)
  local anchorFrame = self.frame
  local anchorPoint = "TOPLEFT"
  if self.tabIndex[#self.tabIndex] then
    anchorFrame = self.tabIndex[#self.tabIndex]
    anchorPoint = "TOPRIGHT"
  end
  tab:SetPoint("TOPLEFT", anchorFrame, anchorPoint, 5, 0)
  self.tabs[name] = tab
  table.insert(self.tabIndex, tab)
  self:ResizeTab(name)
end

function tabFrame:Reload()
  for name in pairs(self.tabs) do
    self:ResizeTab(name)
  end
  self:SetTab(self.selectedTab)
end

function tabFrame:ResizeTab(name)
  local TAB_SIDES_PADDING = 20
  local tab = self.tabs[name]
  local decoration = themes:GetTabButton(tab)
  decoration.Text:SetText(name)
	local textWidth = decoration.Text:GetStringWidth()
	local width = textWidth + TAB_SIDES_PADDING
	local sideWidths = decoration.Left:GetWidth() + decoration.Right:GetWidth()
	local minWidth = sideWidths

	if minWidth and width < minWidth then
		width = minWidth
		textWidth = width - TAB_SIDES_PADDING
	end
	tab:SetWidth(width)
  tab:SetHeight(32)
  decoration:SetFrameLevel(tab:GetFrameLevel() + 1)
  decoration:SetScript("OnClick", function()
    self:SetTab(name)
    if self.clickHandler then
      self.clickHandler(name)
    end
  end)
end

function tabFrame:SetTab(name)
  for k in pairs(self.tabs) do
    if k == name then
      self:SelectTab(k)
    else
      self:DeselectTab(k)
    end
  end
  self.selectedTab = name
end

---@private
function tabFrame:DeselectTab(name)
  local tab = self.tabs[name]
  local decoration = themes:GetTabButton(tab)
	decoration.Left:Show()
	decoration.Middle:Show()
	decoration.Right:Show()
	decoration:Enable()

	local offsetY = decoration.deselectedTextY or 2

	decoration.Text:SetPoint("CENTER", decoration, "CENTER", (decoration.deselectedTextX or 0), offsetY);

	decoration.LeftActive:Hide()
	decoration.MiddleActive:Hide()
	decoration.RightActive:Hide()
end

---@private
function tabFrame:SelectTab(name)
  local tab = self.tabs[name]
  local decoration = themes:GetTabButton(tab)
	decoration.Left:Hide()
	decoration.Middle:Hide()
	decoration.Right:Hide()
	decoration:Disable()
	decoration:SetDisabledFontObject(GameFontHighlightSmall);

	local offsetY = decoration.selectedTextY or -3;

	decoration.Text:SetPoint("CENTER", decoration, "CENTER", (decoration.selectedTextX or 0), offsetY);

	decoration.LeftActive:Show();
	decoration.MiddleActive:Show();
	decoration.RightActive:Show();

	local tooltip = GetAppropriateTooltip();
	if tooltip:IsOwned(decoration) then
		tooltip:Hide();
	end
end

function tabFrame:SetClickHandler(fn)
  self.clickHandler = fn
end

---@param parent Frame
---@return Tab
function tabs:Create(parent)
  local container = setmetatable({}, {__index = tabFrame})
  container.frame = CreateFrame('Frame', parent:GetName().."TabContainer", parent)
  container.frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 2)
  container.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 2)
  container.frame:SetHeight(40)
  container.frame:SetFrameLevel(parent:GetFrameLevel() > 0 and parent:GetFrameLevel() - 1 or 0)
  container.tabs = {}
  container.tabIndex = {}
  return container
end