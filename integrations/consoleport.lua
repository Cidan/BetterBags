---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias



local addon = GetBetterBags()

local events = addon:GetEvents()

local contextMenu = addon:GetContextMenu()

local config = addon:GetConfig()

---@class ConsolePort: AceModule
---@field private enabled boolean
local consoleport = addon:NewModule('ConsolePort')

function consoleport:OnInitialize()
  self.enabled = ConsolePort and true or false
end

function consoleport:OnEnable()
  if not self.enabled then return end
  self:Add(addon.Bags.Backpack.frame)
  self:Add(addon.Bags.Bank.frame)

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

  -- Overwrite the config open function so that it opens to Blizzard config when using ConsolePort
  config.Open = function(me)
    ---@cast me +Config
    if addon.isClassic then
      Settings.OpenToCategory(me.frame)
    else
      Settings.OpenToCategory(me.category)
    end
  end
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