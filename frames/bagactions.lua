local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class SonataApply: AceModule
local apply = addon:GetModule('SonataApply')

-- BagActions are the action buttons a theme can give a bag window (GW2's side panel): its bag
-- window's Layout.Actions lists BetterBags actions by name, with where they go and their art.
-- The bag owns the buttons and runs its own code for each action; a theme cannot add an action.
---@class BagActions: AceModule
local bagActions = addon:NewModule('BagActions')

-- The level above the window's overlay, as the menu button's.
local LEVEL_ABOVE_OVERLAY = 3

---@class BagActionSet
---@field bag Bag
---@field buttons Button[]

-- The actions a theme can place: their tooltip, and what a click does.
---@type table<string, {tooltip: string, run: fun(ctx: Context, bag: Bag)}>
local ACTIONS = {
  ShowBags = {
    tooltip = "Show Bags",
    run = function(ctx, bag)
      addon:GetModule('ContextMenu'):ToggleBagSlots(ctx, bag)
    end,
  },
  Sort = {
    tooltip = "Sort Bags",
    run = function(ctx, bag)
      addon:GetModule('BagMenuButton'):Sort(ctx, bag)
    end,
  },
  Settings = {
    tooltip = "Open Settings",
    run = function(ctx)
      events:SendMessage(ctx, "config/Open")
    end,
  },
  Menu = {
    tooltip = "Open Menu",
    run = function(ctx, bag)
      addon:GetModule('ContextMenu'):Show(ctx, bag.menuList)
    end,
  },
}

-- Create returns the action buttons of bag, none built until a theme places some.
---@param bag Bag
---@return BagActionSet
function bagActions:Create(bag)
  return { bag = bag, buttons = {} }
end

---@param actions BagActionSet
---@param index number
---@return Button
local function buttonAt(actions, index)
  local button = actions.buttons[index]
  if button ~= nil then
    return button
  end
  button = CreateFrame("Button", nil, actions.bag.frame)
  button:RegisterForClicks("LeftButtonUp")
  addon.SetScript(button, "OnClick", function(ctx)
    ACTIONS[button.bagAction].run(ctx, actions.bag)
  end)
  addon.SetScript(button, "OnEnter", function()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L:G(ACTIONS[button.bagAction].tooltip))
    GameTooltip:Show()
  end)
  addon.SetScript(button, "OnLeave", function()
    GameTooltip:Hide()
  end)
  actions.buttons[index] = button
  return button
end

-- Place builds a button for each of layout.Buttons ({ Action, Normal, Highlight, Pushed }),
-- Size square, the first at layout.Points (relative to the window frame) and each next one
-- Spacing below the one before, above the window's overlay. Buttons it does not use, and every
-- button for a layout of false or nil, are hidden.
---@param actions BagActionSet
---@param layout table|false|nil
---@param frame Frame
---@param overlay? Frame
function bagActions:Place(actions, layout, frame, overlay)
  local entries = type(layout) == "table" and layout.Buttons or {}
  for _, entry in ipairs(entries) do
    if ACTIONS[entry.Action] == nil then
      error("unknown bag action: " .. tostring(entry.Action))
    end
  end
  local size = type(layout) == "table" and layout.Size or 32
  local spacing = type(layout) == "table" and layout.Spacing or 5
  local level = (overlay or frame):GetFrameLevel() + LEVEL_ABOVE_OVERLAY
  for i, entry in ipairs(entries) do
    local button = buttonAt(actions, i)
    button.bagAction = entry.Action
    button:SetSize(size, size)
    button:ClearAllPoints()
    if i == 1 then
      for _, p in ipairs(layout.Points or { { Point = "TOPLEFT" } }) do
        button:SetPoint(p.Point, frame, p.RelativePoint or p.Point, p.X or 0, p.Y or 0)
      end
    else
      button:SetPoint("TOP", actions.buttons[i - 1], "BOTTOM", 0, -spacing)
    end
    apply:ButtonStates(button, {
      Normal = entry.Normal or false,
      Highlight = entry.Highlight or false,
      Pushed = entry.Pushed or false,
    })
    button:SetFrameLevel(level)
    button:Show()
  end
  for i = #entries + 1, #actions.buttons do
    actions.buttons[i]:Hide()
  end
end
