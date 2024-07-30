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

---@class TabButton: Button
---@field name string
---@field index number
---@field id? number
---@field onClick? fun()

---@class (exact) Tab
---@field frame Frame
---@field tabs table<string, TabButton>
---@field tabIndex TabButton[]
---@field buttonToName table<TabButton, string>
---@field selectedTab string
---@field clickHandler fun(name: number, button: string): boolean?
---@field width number
local tabFrame = {}

---@param name string
---@param id? number
---@param onClick? fun()
function tabFrame:AddTab(name, id, onClick)
  local tab = CreateFrame("Button", format("%sTab%d", self.frame:GetName(), #self.tabIndex), self.frame) --[[@as TabButton]]
  tab.onClick = onClick
  tab.name = name
  tab.id = id
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
  tab.index = #self.tabIndex
  self.buttonToName[tab] = name
  self:DeselectTab(name)
  self:ResizeTab(name)
  self:ReanchorTabs()
end

function tabFrame:TabExists(name)
  return self.tabs[name] ~= nil
end

function tabFrame:Reload()
  for name in pairs(self.tabs) do
    self:ResizeTab(name)
  end
  self:SetTab(self.selectedTab)
end

function tabFrame:ReanchorTabs()
  self.width = 0
  local tabCount = 1
  for i, tab in ipairs(self.tabIndex) do
    tab:ClearAllPoints()
    if tab:IsShown() then
      local anchorFrame = self.frame
      local anchorPoint = "TOPLEFT"
      if tabCount > 1 then
        anchorFrame = self.tabIndex[i - 1]
        anchorPoint = "TOPRIGHT"
      end
      tab:SetPoint("TOPLEFT", anchorFrame, anchorPoint, 5, 0)
      self.width = self.width + tab:GetWidth() + 5
      tabCount = tabCount + 1
    end
  end
end

function tabFrame:MoveToEnd(name)
  for i, tab in ipairs(self.tabIndex) do
    if tab.name == name then
      table.remove(self.tabIndex, i)
      table.insert(self.tabIndex, tab)
      break
    end
  end
  for i, tab in ipairs(self.tabIndex) do
    tab.index = i
  end
  self:ReanchorTabs()
end

---@param index number
---@return string
function tabFrame:GetTabName(index)
  return self.buttonToName[self.tabIndex[index]]
end

---@param id number
---@return string
function tabFrame:GetTabNameByID(id)
  for name, tab in pairs(self.tabs) do
    if tab.id == id then
      return name
    end
  end
  return ""
end

---@param id number
---@return boolean
function tabFrame:TabExistsByID(id)
  for _, tab in pairs(self.tabs) do
    if tab.id == id then
      return true
    end
  end
  return false
end

---@param id number
---@param name string
function tabFrame:RenameTabByID(id, name)
  for _, tab in pairs(self.tabs) do
    if tab.id == id then
      self.tabs[tab.name] = nil
      tab.name = name
      self.buttonToName[tab] = name
      self.tabs[name] = tab
      self:ResizeTab(name)
      return
    end
  end
end

---@param name string
function tabFrame:ResizeTab(name)
  local tab = self.tabs[name]
  local decoration = themes:GetTabButton(tab)
  decoration.Text:SetText(name)

  PanelTemplates_TabResize(decoration)
	tab:SetWidth(decoration:GetWidth())
  tab:SetHeight(32)

  decoration:SetFrameLevel(tab:GetFrameLevel() + 1)
  decoration:SetScript("OnClick", function(_, button)
    if tab.onClick then
      tab.onClick()
      return
    end
    if self.clickHandler and (self.selectedTab ~= name or button == "RightButton") then
      if self.clickHandler(tab.id or tab.index, button) then
        self:SetTab(name)
      end
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

function tabFrame:ShowTab(name)
  self.tabs[name]:Show()
  self:ReanchorTabs()
end

function tabFrame:HideTab(name)
  self.tabs[name]:Hide()
  self:ReanchorTabs()
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
	--decoration:Disable()
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

---@param fn fun(name: number, button: string): boolean?
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
  container.width = 0
  container.tabs = {}
  container.tabIndex = {}
  container.buttonToName = {}
  return container
end