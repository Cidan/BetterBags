local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Fonts: AceModule
local fonts = addon:GetModule('Fonts')

---@class ItemColorPane: AceModule
local itemColorPane = addon:NewModule('ItemColorPane')

---@class ItemColorPaneFrame
---@field frame Frame
---@field breakpointsLabel FontString
---@field colorPickerLabels table<string, FontString>
local itemColorPaneProto = {}

function itemColorPaneProto:UpdateBreakpoints()
  local maxIlvl = database:GetMaxItemLevel()
  local midPoint = math.floor(maxIlvl * 0.61)
  local highPoint = math.floor(maxIlvl * 0.86)

  self.breakpointsLabel:SetText(string.format(
    "Current maximum item level: |cffffffff%d|r\n\n" ..
    "Color ranges:\n" ..
    "  • Low: |cff9d9d9d1-%d|r\n" ..
    "  • Mid: |cffffffff%d-%d|r (61%% of max)\n" ..
    "  • High: |cff008dde%d-%d|r (86%% of max)\n" ..
    "  • Max: |cffff8000%d+|r\n\n" ..
    "These ranges update automatically as you obtain higher item level gear.",
    maxIlvl,
    midPoint - 1,
    midPoint, highPoint - 1,
    highPoint, maxIlvl - 1,
    maxIlvl
  ))

  -- Update color picker labels
  self.colorPickerLabels.low:SetText("Low Item Level Color (1-" .. (midPoint - 1) .. ")")
  self.colorPickerLabels.mid:SetText("Mid Item Level Color (" .. midPoint .. "-" .. (highPoint - 1) .. ")")
  self.colorPickerLabels.high:SetText("High Item Level Color (" .. highPoint .. "-" .. (maxIlvl - 1) .. ")")
  self.colorPickerLabels.max:SetText("Max Item Level Color (" .. maxIlvl .. "+)")
end

---@param parent Frame
---@return Frame
function itemColorPane:Create(parent)
  local pane = setmetatable({}, {__index = itemColorPaneProto})
  pane.colorPickerLabels = {}

  -- Create main frame
  pane.frame = CreateFrame("Frame", nil, parent)
  pane.frame:SetAllPoints()

  -- Create scrollable content frame
  local content = CreateFrame("Frame", nil, pane.frame)
  content:SetPoint("TOPLEFT", 20, -20)
  content:SetPoint("BOTTOMRIGHT", -20, 20)

  local yOffset = 0

  -- Title
  local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 0, yOffset)
  title:SetText("Dynamic Item Level Colors")
  yOffset = yOffset - 30

  -- Description
  local desc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", 0, yOffset)
  desc:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  desc:SetJustifyH("LEFT")
  desc:SetWordWrap(true)
  desc:SetText("Configure the colors used for item level display. Color ranges automatically scale based on the highest item level you have seen.")
  yOffset = yOffset - 50

  -- Current breakpoints info
  pane.breakpointsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pane.breakpointsLabel:SetPoint("TOPLEFT", 0, yOffset)
  pane.breakpointsLabel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  pane.breakpointsLabel:SetJustifyH("LEFT")
  yOffset = yOffset - 150

  -- Color pickers section
  local colorsTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  colorsTitle:SetPoint("TOPLEFT", 0, yOffset)
  colorsTitle:SetText("Color Configuration")
  yOffset = yOffset - 30

  -- Helper function to create color picker
  local function CreateColorPicker(colorKey, yPos)
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 20, yPos)
    pane.colorPickerLabels[colorKey] = label

    local colorSwatch = CreateFrame("Button", nil, content)
    colorSwatch:SetPoint("TOPLEFT", 200, yPos + 3)
    colorSwatch:SetSize(20, 20)

    local texture = colorSwatch:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    local colors = database:GetItemLevelColors()
    local color = colors[colorKey]
    texture:SetColorTexture(color.red, color.green, color.blue, color.alpha)

    colorSwatch:SetScript("OnClick", function()
      local currentColors = database:GetItemLevelColors()
      local currentColor = currentColors[colorKey]

      ColorPickerFrame:SetupColorPickerAndShow({
        r = currentColor.red,
        g = currentColor.green,
        b = currentColor.blue,
        opacity = currentColor.alpha,
        hasOpacity = true,
        swatchFunc = function()
          local r, g, b = ColorPickerFrame:GetColorRGB()
          local a = ColorPickerFrame:GetColorAlpha()
          texture:SetColorTexture(r, g, b, a)
          local ctx = context:New('ItemColorPane_ColorChange')
          database:SetItemLevelColor(colorKey, {red = r, green = g, blue = b, alpha = a})
          events:SendMessage(ctx, 'bags/FullRefreshAll')
        end,
        cancelFunc = function()
          texture:SetColorTexture(currentColor.red, currentColor.green, currentColor.blue, currentColor.alpha)
        end,
      })
    end)

    return yPos - 25
  end

  yOffset = CreateColorPicker("low", yOffset)
  yOffset = CreateColorPicker("mid", yOffset)
  yOffset = CreateColorPicker("high", yOffset)
  yOffset = CreateColorPicker("max", yOffset)

  -- Initial update of breakpoints
  pane:UpdateBreakpoints()

  yOffset = yOffset - 20

  -- Reset button
  local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  resetButton:SetPoint("TOPLEFT", 20, yOffset)
  resetButton:SetSize(200, 25)
  resetButton:SetText("Reset to Default Colors")
  resetButton:SetScript("OnClick", function()
    local ctx = context:New('ItemColorPane_Reset')
    database:ResetItemLevelColors()
    events:SendMessage(ctx, 'bags/FullRefreshAll')
    -- Refresh the pane
    pane.frame:Hide()
    pane.frame:GetParent():GetParent().currentPane = nil
    local newFrame = itemColorPane:Create(parent)
    newFrame:Show()
  end)

  -- Register for max item level changes
  pane.frame:RegisterEvent("BAG_UPDATE")
  pane.frame:SetScript("OnEvent", function()
    -- Check if we're still visible
    if pane.frame:IsShown() then
      pane:UpdateBreakpoints()
    end
  end)

  -- Also listen for the custom event via Events module
  events:RegisterMessage('itemLevel/MaxChanged', function()
    if pane.frame:IsShown() then
      pane:UpdateBreakpoints()
    end
  end)

  return pane.frame
end
