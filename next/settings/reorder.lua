local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

-- NextListReorder drags a row of a settings list to a new place: from the row's drag start until the
-- left button is let go, a marker (the theme's Settings.BagCategories.DropMarker) shows where it would
-- land, and letting go drops it after the entry above the pointer's half of a row. One drag for every
-- list that reorders (CLAUDE.md, "UI Consistency"): a bag's Categories tab (its pins) and the Categories
-- page's list (the order of the categories, category-lifecycle.md §7).
---@class NextListReorder: AceModule
local reorder = addon:NewModule('NextListReorder')

---@class (exact) NextListReorderOptions
---@field box WowScrollBox The list's scroll box.
---@field content Frame What the rows hang from, top down.
---@field entries fun(): table[] The list's entries, in order.
---@field heightOf fun(entry: table): number How tall an entry's row is.
---@field onDrop fun(name: string, after: number) A row let go after the entry at after (0: before the first).

---@class NextListReorderDrag
---@field opts NextListReorderOptions
---@field marker Texture
---@field dragging? string
local dragProto = {}
addon:GetModule('Perf'):RegisterPrototype(dragProto, 'NextListReorderDrag')

-- Create makes a list's drag, its marker hidden.
---@param opts NextListReorderOptions
---@return NextListReorderDrag
function reorder:Create(opts)
  local drag = setmetatable({ opts = opts }, { __index = dragProto })
  drag.marker = opts.content:CreateTexture(nil, "OVERLAY")
  drag.marker:Hide()
  drag:Style()
  return drag
end

-- Style draws the marker from the theme, shown only during a drag (painting shows a texture).
function dragProto:Style()
  local K = style.Theme.Settings.BagCategories.DropMarker
  local shown = self.dragging ~= nil and self.marker:IsShown()
  controls:Paint(self.marker, { Color = K.Color }, K.Alpha)
  self.marker:SetHeight(K.Size or 2)
  self.marker:SetShown(shown)
end

-- GapAt returns how many entries a row let go where the pointer is would land after, and how far down
-- the list its marker goes; nothing while the list has no place on screen.
---@return number?, number?
function dragProto:GapAt()
  local box = self.opts.box
  local top = box:GetTop()
  if top == nil then
    return nil
  end
  local _, cursorY = GetCursorPosition()
  local down = top - cursorY / box:GetEffectiveScale() + box:GetDerivedScrollOffset()
  local entries = self.opts.entries()
  local y = 0
  for i, entry in ipairs(entries) do
    local height = self.opts.heightOf(entry)
    if down < y + height then
      if down - y < height / 2 then
        return i - 1, y
      end
      return i, y + height
    end
    y = y + height
  end
  return #entries, y
end

-- Start drags a row until the left button is let go.
---@param name string
function dragProto:Start(name)
  self.dragging = name
  addon.SetScript(self.opts.box, "OnUpdate", function() self:Follow() end)
end

-- Follow moves the marker with the pointer, and drops the row once the left button is up.
function dragProto:Follow()
  local after, y = self:GapAt()
  local box, marker = self.opts.box, self.marker
  if not IsMouseButtonDown("LeftButton") then
    box:SetScript("OnUpdate", nil)
    marker:Hide()
    local name = self.dragging
    self.dragging = nil
    if name and after then
      self.opts.onDrop(name, after)
    end
    return
  end
  if after == nil then
    marker:Hide()
    return
  end
  marker:ClearAllPoints()
  marker:SetPoint("TOPLEFT", self.opts.content, "TOPLEFT", 0, -y)
  marker:SetPoint("TOPRIGHT", self.opts.content, "TOPRIGHT", 0, -y)
  marker:Show()
end
