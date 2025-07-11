

---@type BetterBags
local addon = GetBetterBags()

---@class SliderFrame: AceModule
local slider = addon:NewModule('Slider')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class BetterSlider
---@field private frame Frame
---@field private slider Slider
---@field private title FontString
---@field private high FontString
---@field private low FontString
---@field OnValueChanged function
---@field OnMouseUp function
local sliderProto = {}

---@return Frame
function sliderProto:GetFrame()
  return self.frame
end

---@param min number
---@param max number
function sliderProto:SetMinMaxValues(min, max)
  self.slider:SetMinMaxValues(min, max)
  self.high:SetText(tostring(max))
  self.low:SetText(tostring(min))
  self.slider:SetValue(min)
end

---@param value number
function sliderProto:SetValue(value)
  self.slider:SetValue(value)
end

local sliderCount = 0
function slider:CreateDropdownSlider()

  local f = CreateFrame("Frame", "BetterBagsSliderParent" .. sliderCount)
  Mixin(f, UIDropDownCustomMenuEntryMixin)
  f:SetSize(100, 20)

  local s = CreateFrame("Slider", "BetterBagsSlider" .. sliderCount, f, "OptionsSliderTemplate") --[[@as slider]]
  s:SetAllPoints()
  s:SetOrientation("HORIZONTAL")
  s:SetValueStep(1)
  s:SetObeyStepOnDrag(true)

  local t = _G[s:GetName() .. "Text"] ---@type FontString
  local h = _G[s:GetName() .. "High"] ---@type FontString
  local l = _G[s:GetName() .. "Low"] ---@type FontString

  local o = setmetatable({
    frame = f,
    slider = s,
    title = t,
    high = h,
    low = l,
  }, { __index = sliderProto })

  s:SetScript("OnMouseUp", function()
    if o.OnMouseUp then
      o:OnMouseUp()
    end
  end)

  s:SetScript("OnValueChanged", function(_, value)
    t:SetText(tostring(value))
    if o.OnValueChanged then
      o:OnValueChanged(value)
    end
  end)
  sliderCount = sliderCount + 1
  return o
end