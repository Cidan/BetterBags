local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class Views: AceModule
local views = addon:NewModule('Views')

---@class view
---@field sections table<string, Section>
---@field content Grid
---@field kind BagView
---@field itemsByBagAndSlot table<string, Item>
views.viewProto = {}

---@param bag Bag
---@param dirtyItems ItemData[]
function views.viewProto:Render(bag, dirtyItems)
  _ = bag
  _ = dirtyItems
  error('Render method not implemented')
end

---@return BagView
function views.viewProto:GetKind()
  return self.kind
end

---@return Grid
function views.viewProto:GetContent()
  return self.content
end

-- GetOrCreateSection will get an existing section by category,
-- creating it if it doesn't exist.
---@param category string
---@return Section
function views.viewProto:GetOrCreateSection(category)
  local section = self.sections[category]
  if section == nil then
    section = sectionFrame:Create()
    section.frame:SetParent(self.content:GetScrollView())
    section:SetTitle(category)
    self.content:AddCell(category, section)
    self.sections[category] = section
  elseif self.content:GetCell(category) == nil then
    self.content:AddCell(category, section)
  end
  return section
end

function views.viewProto:GetSection(category)
  return self.sections[category]
end

---@param category string
function views.viewProto:RemoveSection(category)
  self.content:RemoveCell(category)
  self.sections[category] = nil
end

---@return table<string, Section>
function views.viewProto:GetAllSections()
  return self.sections
end

---@return table<string, Item>
function views.viewProto:GetItemsByBagAndSlot()
  return self.itemsByBagAndSlot
end

---@param data ItemData
---@return string
function views.viewProto:GetSlotKey(data)
  return data.bagid .. '-' .. data.slotid
end

---@param slotkey string
---@return number, number
function views.viewProto:ParseSlotKey(slotkey)
  ---@type string, string
  local bagid, slotid = strsplit('-', slotkey)
  return tonumber(bagid) --[[@as number]], tonumber(slotid) --[[@as number]]
end