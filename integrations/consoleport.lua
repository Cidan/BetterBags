---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class ContextMenu: AceModule
local contextMenu = addon:GetModule('ContextMenu')

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class ConsolePort: AceModule
---@field private enabled boolean
local consoleport = addon:NewModule('ConsolePort')

function consoleport:OnInitialize()
  self.enabled = ConsolePort and true or false
end

function consoleport:OnEnable()
  if not self.enabled then return end
  self:Add(addon.Bags.Backpack.frame)
  if addon.Bags.Bank then
    self:Add(addon.Bags.Bank.frame)
  end

  -- Context menus are created on demand, so we need to listen for the context/show event to add them.
  events:RegisterMessage('context/show', function()
    local listCount = 1
    local buttonCount = 1
    while _G[format('L_DropDownList%d', listCount)] ~= nil do
      self:Add(_G[format('L_DropDownList%d', listCount)])
      while _G[format('L_DropDownList%dButton%d', listCount, buttonCount)] ~= nil do
        self:Add(_G[format('L_DropDownList%dButton%d', listCount, buttonCount)])
        buttonCount = buttonCount + 1
      end
      listCount = listCount + 1
      buttonCount = 1
    end
    self:Select(_G['L_DropDownList1Button2'])
  end)
end

---@param frame Frame
function consoleport:Add(frame)
  if not self.enabled then return end
  ConsolePort:AddInterfaceCursorFrame(frame)
end

---@param frame Frame
function consoleport:Select(frame)
  if not self.enabled then return end
  ConsolePort:SetCursorNode(frame)
end

---@return boolean
function consoleport:Active()
  return self.enabled
end