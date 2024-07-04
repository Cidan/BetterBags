local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Tabs: AceModule
local tabs = addon:NewModule('Tabs')
---@class PanelTabButtonTemplate: Button

---@class (exact) Tab
---@field frame Frame
---@field tabs table<string, PanelTabButtonTemplate>
---@field tabIndex PanelTabButtonTemplate[]
---@field selectedTab string
local tabFrame = {}

---@param name string
function tabFrame:AddTab(name)
  local tab = CreateFrame("button", format("%sTab%d", self.frame:GetName(), #self.tabs), self.frame, "PanelTabButtonTemplate") --[[@as PanelTabButtonTemplate]]
  tab.Text:SetText(name)
  local anchorFrame = self.frame
  local anchorPoint = "TOPLEFT"
  if self.tabIndex[#self.tabIndex] then
    anchorFrame = self.tabIndex[#self.tabIndex]
    anchorPoint = "TOPRIGHT"
  end
  tab:SetPoint("TOPLEFT", anchorFrame, anchorPoint, 5, 0)
  tab:SetScript("OnClick", function()
    self:SetTab(name)
    if self.clickHandler then
      self.clickHandler(name)
    end
  end)
  self.tabs[name] = tab
  table.insert(self.tabIndex, tab)
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
	tab.Left:Show()
	tab.Middle:Show()
	tab.Right:Show()
	tab:Enable()

	local offsetY = tab.deselectedTextY or 2

	tab.Text:SetPoint("CENTER", tab, "CENTER", (tab.deselectedTextX or 0), offsetY);

	tab.LeftActive:Hide()
	tab.MiddleActive:Hide()
	tab.RightActive:Hide()
end

---@private
function tabFrame:SelectTab(name)
  local tab = self.tabs[name]
	tab.Left:Hide();
	tab.Middle:Hide();
	tab.Right:Hide();
	tab:Disable();
	tab:SetDisabledFontObject(GameFontHighlightSmall);

	local offsetY = tab.selectedTextY or -3;

	tab.Text:SetPoint("CENTER", tab, "CENTER", (tab.selectedTextX or 0), offsetY);

	tab.LeftActive:Show();
	tab.MiddleActive:Show();
	tab.RightActive:Show();

	local tooltip = GetAppropriateTooltip();
	if tooltip:IsOwned(tab) then
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