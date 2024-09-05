local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class (exact) FormLayouts: AceModule
local layouts = addon:GetModule('FormLayouts')

---@class (exact) StackedLayout: FormLayout
local stackedLayout = {}

---@param targetFrame Frame
---@return FormLayout
function layouts:NewStackedLayout(targetFrame)
  local l = setmetatable({}, {__index = stackedLayout}) --[[@as StackedLayout]]
  l.targetFrame = targetFrame
  l.sections = {}
  return l
end

---@param opts FormSectionOptions
function stackedLayout:AddSection(opts)
  local t = self.targetFrame
  local title = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetTextColor(1, 1, 1)
  title:SetJustifyH("LEFT")
  title:SetText(opts.title)
  title:SetPoint("TOPLEFT", t, "TOPLEFT", 45, -5)
  t:SetHeight(100)
end