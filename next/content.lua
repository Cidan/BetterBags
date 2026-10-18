local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextContent is BetterBagsNext's canvas (next.md §2), the drawable inside the panel's scroll
-- box. Bind turns a tab's data into sections, in one column: Recent Items, the tab's categories
-- in their order, then Free Space; it draws and claims the static item buttons. Render lays the
-- sections out in rows of as many big icons as fit its width, through Motion while it is shown,
-- so what changed place travels there. Cascade fades sections in one after the other.
---@class NextContent: AceModule
local nextContent = addon:NewModule('NextContent')

local STEP = style.ICON + style.GAP

---@class (exact) NextSectionEntry
---@field item? Item
---@field gap? boolean

---@class (exact) NextSection
---@field name string
---@field kind "recent"|"category"|"free"
---@field frame Frame Placed in the canvas.
---@field inner Frame Rises into place during a cascade.
---@field title FontString
---@field count FontString
---@field line Texture
---@field cells Frame The item buttons hang from it.
---@field header Button Across the title row: dragging it moves the section (next.md §7).
---@field entries NextSectionEntry[]
---@field isNew boolean It was not drawn in the previous pass.
---@field rise number How far below its place it is, in pixels.
---@field y number Where the last render put it, from the canvas's top.
---@field height number Its height in the last render.

---@class (exact) NextCanvasDrag
---@field section NextSection The section picked up.
---@field index number Where its gap is among the other sections, from 1.
---@field height number Its height in the last render.
---@field onLost? fun() Called when it leaves the data or the canvas is torn down mid-drag.

---@class NextHeaderHandler
---@field OnHeaderDragStart? fun(self: any, section: NextSection)
---@field OnHeaderDragStop? fun(self: any, section: NextSection)
---@field OnHeaderClick? fun(self: any, ctx: Context, section: NextSection, button: string)
---@field OnHeaderReceiveDrag? fun(self: any, ctx: Context, section: NextSection)
---@field OnHeaderEnter? fun(self: any, section: NextSection)
---@field OnHeaderLeave? fun(self: any, section: NextSection)

---@class (exact) NextCanvas: Drawable
---@field frame Frame
---@field order NextSection[] This pass's sections, in order.
---@field byName table<string, NextSection>
---@field stale table<string, NextSection> Last pass's sections not drawn again yet.
---@field pool NextSection[] Sections not in use, hidden.
---@field buttons table<string, Item> This pass's buttons by slot key.
---@field freeTotal number This pass's free slots, in every bag of the tab.
---@field drag? NextCanvasDrag The section being dragged.
---@field dragSlotY? number Where the last render put the dragged section's gap.
---@field leaving table<string, number> Sections moved away, left out until this time (GetTime).
---@field headerHandler? NextHeaderHandler
local canvasProto = drawable:Extend({}, 'NextCanvas')

---@param parent Frame
---@return NextCanvas
function nextContent:Create(parent)
  ---@type NextCanvas
  local canvas = drawable:Create(canvasProto)
  canvas.frame = CreateFrame("Frame", nil, parent)
  canvas.frame:SetSize(style.GRID_WIDTH, 1)
  canvas.order = {}
  canvas.byName = {}
  canvas.stale = {}
  canvas.pool = {}
  canvas.buttons = {}
  canvas.freeTotal = 0
  canvas.leaving = {}
  addon.SetScript(canvas.frame, "OnHide", function()
    canvas:Settle()
  end)
  return canvas
end

---@return RenderPlan
function canvasProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

---@private
---@return NextSection
function canvasProto:newSection()
  local frame = CreateFrame("Frame", nil, self.frame)
  local inner = CreateFrame("Frame", nil, frame)
  inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  local title = inner:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOPLEFT", inner, "TOPLEFT", 2, -4)
  local count = inner:CreateFontString(nil, "OVERLAY")
  count:SetFontObject(style:Font("Count"))
  count:SetPoint("LEFT", title, "RIGHT", 8, 0)
  local line = inner:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 1)
  line:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.35), style:CreateColor("Lavender", 0))
  line:SetHeight(1)
  line:SetPoint("LEFT", count, "RIGHT", 10, 0)
  line:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
  local cells = CreateFrame("Frame", nil, inner)
  cells:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -style.SECTION_HEADER)
  ---@type NextSection
  local section = {
    name = "", kind = "category", frame = frame, inner = inner, title = title, count = count,
    line = line, cells = cells, entries = {}, isNew = true, rise = 0, y = 0, height = 0,
  }
  section.header = self:newHeader(section)
  return section
end

-- newHeader makes a section's header: a button across its title row that passes drags, clicks
-- and drops to the canvas's header handler (the panel).
---@private
---@param section NextSection
---@return Button
function canvasProto:newHeader(section)
  local header = CreateFrame("Button", nil, section.inner)
  header:SetPoint("TOPLEFT", section.inner, "TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", section.inner, "TOPRIGHT", 0, 0)
  header:SetHeight(style.SECTION_HEADER)
  header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  header:RegisterForDrag("LeftButton")
  local highlight = header:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 1)
  highlight:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.12), style:CreateColor("Lavender", 0))
  local function call(name, ...)
    local handler = self.headerHandler
    if handler and handler[name] then
      handler[name](handler, ...)
    end
  end
  header:SetScript("OnDragStart", function() call("OnHeaderDragStart", section) end)
  header:SetScript("OnDragStop", function() call("OnHeaderDragStop", section) end)
  header:SetScript("OnEnter", function() call("OnHeaderEnter", section) end)
  header:SetScript("OnLeave", function() call("OnHeaderLeave", section) end)
  addon.SetScript(header, "OnClick", function(ctx, _, button) call("OnHeaderClick", ctx, section, button) end)
  addon.SetScript(header, "OnReceiveDrag", function(ctx) call("OnHeaderReceiveDrag", ctx, section) end)
  return header
end

-- SetHeaderHandler names what the sections' headers report their drags, clicks and drops to.
---@param handler NextHeaderHandler
function canvasProto:SetHeaderHandler(handler)
  self.headerHandler = handler
end

---@private
---@param section NextSection
---@param rise number
local function setRise(section, rise)
  section.rise = rise
  section.inner:ClearAllPoints()
  section.inner:SetPoint("TOPLEFT", section.frame, "TOPLEFT", 0, -rise)
end

-- section returns this pass's section of a name, reusing last pass's, else a pooled or new one.
---@private
---@param name string
---@param kind "recent"|"category"|"free"
---@return NextSection
function canvasProto:section(name, kind)
  local section = self.byName[name]
  if section ~= nil then
    return section
  end
  section = self.stale[name]
  if section ~= nil then
    self.stale[name] = nil
    section.isNew = false
  else
    section = table.remove(self.pool) or self:newSection()
    section.isNew = true
    section.frame:Show()
  end
  section.name = name
  section.kind = kind
  section.entries = {}
  local font = kind == "recent" and "SectionRecent" or kind == "free" and "SectionFree" or "Section"
  section.title:SetFontObject(style:Font(font))
  section.title:SetText(name)
  self.byName[name] = section
  table.insert(self.order, section)
  return section
end

---@private
---@param section NextSection
function canvasProto:release(section)
  local drag = self.drag
  if drag ~= nil and drag.section == section then
    self.drag = nil
    if drag.onLost then
      drag.onLost()
    end
  end
  tween:Stop(section)
  section.frame:SetAlpha(1)
  setRise(section, 0)
  section.frame:Hide()
  section.frame:ClearAllPoints()
  section.entries = {}
  table.insert(self.pool, section)
end

-- claim draws a button into a section: sized to a big icon, hung from the section's cells,
-- claimed for the bag's sweep.
---@private
---@param ctx Context
---@param section NextSection
---@param slotkey string
---@param claims table<Item, boolean>
---@return Item
function canvasProto:claim(ctx, section, slotkey, claims)
  local button = itemFrame:GetButton(ctx, slotkey)
  claims[button] = true
  if math.abs(button.frame:GetWidth() - style.ICON) > 0.01 then
    button:SetSize(ctx, style.ICON, style.ICON)
  end
  if button.frame:GetParent() ~= section.cells then
    button.frame:SetParent(section.cells)
  end
  table.insert(section.entries, { item = button })
  self.buttons[slotkey] = button
  return button
end

---@private
---@param ctx Context
---@param section NextSection
---@param data ItemData
---@param claims table<Item, boolean>
function canvasProto:addItem(ctx, section, data, claims)
  if data.isItemGap then
    table.insert(section.entries, { gap = true })
    return
  end
  local button = self:claim(ctx, section, data.slotkey, claims)
  if data.isFreeSlot then
    button:SetFreeSlots(ctx, data, -1)
  else
    button:SetItemFromData(ctx, data)
  end
end

-- Bind puts a tab's data into sections and draws their buttons, claiming each in claims. Last
-- pass's sections not drawn again are hidden and pooled; their buttons are left to the bag's
-- sweep.
---@param ctx Context
---@param slotInfo SlotInfo
---@param tabID number
---@param claims table<Item, boolean>
function canvasProto:Bind(ctx, slotInfo, tabID, claims)
  for name, section in pairs(self.byName) do
    self.stale[name] = section
  end
  self.byName = {}
  self.order = {}
  self.buttons = {}
  self.freeTotal = 0

  local recentName = L:G("Recent Items")
  local recent = {}
  for _, data in ipairs(slotInfo.sortedItems or {}) do
    if data.itemInfo and data.itemInfo.category == recentName then
      table.insert(recent, data)
    end
  end
  if #recent > 0 then
    local section = self:section(recentName, "recent")
    for _, data in ipairs(recent) do
      self:addItem(ctx, section, data, claims)
    end
  end

  local tabData = slotInfo.tabs and slotInfo.tabs[tabID] or { items = {}, categories = {} }
  local byCategory, seen = {}, {}
  for _, data in ipairs(tabData.items or {}) do
    local category = data.itemInfo and data.itemInfo.category or L:G("Everything")
    if byCategory[category] == nil then
      byCategory[category] = {}
      table.insert(seen, category)
    end
    table.insert(byCategory[category], data)
  end
  local ordered, listed = {}, {}
  for _, catData in ipairs(tabData.categories or {}) do
    if byCategory[catData.name] ~= nil and not listed[catData.name] then
      listed[catData.name] = true
      table.insert(ordered, catData.name)
    end
  end
  for _, category in ipairs(seen) do
    if not listed[category] then
      table.insert(ordered, category)
    end
  end
  for _, category in ipairs(ordered) do
    local section = self:section(category, "category")
    for _, data in ipairs(byCategory[category]) do
      self:addItem(ctx, section, data, claims)
    end
  end

  local free = tabData.freeSpace
  if free ~= nil and #free.buttons > 0 then
    local section = self:section(L:G("Free Space"), "free")
    local total = 0
    for _, slot in ipairs(free.buttons) do
      local button = self:claim(ctx, section, slot.slotkey, claims)
      if free.showAll then
        button:SetFreeSlots(ctx, slot, 1, true)
        total = total + 1
      else
        button:SetFreeSlots(ctx, slot, slot.count)
        total = total + (slot.count or 0)
      end
    end
    section.count:SetText(tostring(total))
    self.freeTotal = total
  end

  for _, section in ipairs(self.order) do
    if section.kind ~= "free" then
      local n = 0
      for _, entry in ipairs(section.entries) do
        if entry.item ~= nil then n = n + 1 end
      end
      section.count:SetText(tostring(n))
    end
  end

  for name, section in pairs(self.stale) do
    self.stale[name] = nil
    self.leaving[name] = nil
    self:release(section)
  end
end

-- Render lays the sections out in one column, in rows of as many icons as fit the width it is
-- given; while the canvas is shown, through a Motion pass, so what changed place travels there.
---@param parentResult? RenderResult
---@return RenderResult
function canvasProto:Render(parentResult)
  local width = parentResult and parentResult.Width or style.GRID_WIDTH
  local perRow = math.max(1, math.floor((width + style.GAP) / STEP))
  local animated = self.frame:IsVisible()
  if animated then
    motion:BeginPass(self)
  else
    motion:Forget(self)
  end
  local drag = self.drag
  local y, placed, others = 0, 0, 0
  self.dragSlotY = nil
  -- gap keeps the dragged section's room in the column.
  local function gap()
    if placed > 0 then
      y = y + style.SECTION_SPACING
    end
    self.dragSlotY = y
    y = y + drag.height
    placed = placed + 1
  end
  for _, section in ipairs(self.order) do
    local rows = math.max(1, math.ceil(#section.entries / perRow))
    local height = style.SECTION_HEADER + rows * STEP - style.GAP
    section.height = height
    section.frame:SetSize(width, height)
    section.inner:SetSize(width, height)
    section.cells:SetSize(width, rows * STEP)
    for j, entry in ipairs(section.entries) do
      if entry.item ~= nil then
        local column, row = (j - 1) % perRow, math.floor((j - 1) / perRow)
        motion:Place(entry.item.frame, section.cells, column * STEP, -row * STEP)
        entry.item.frame:Show()
      end
    end
    if drag ~= nil and section == drag.section then
      drag.height = height
    elseif self:IsLeaving(section) then
      section.frame:Hide()
    else
      others = others + 1
      if drag ~= nil and others == drag.index then
        gap()
      end
      if placed > 0 then
        y = y + style.SECTION_SPACING
      end
      section.y = y
      motion:Place(section.frame, self.frame, 0, -y)
      section.frame:Show()
      y = y + height
      placed = placed + 1
    end
  end
  if drag ~= nil and drag.index > others then
    gap()
  end
  if animated then
    motion:EndPass()
  end
  local height = math.max(1, y)
  self.frame:SetSize(width, height)
  return { Width = width, Height = height }
end

-- Cascade fades sections in one after the other, rising into place: every section with all,
-- else only the ones new this pass. delay holds the first one back.
---@param all boolean
---@param delay? number
function canvasProto:Cascade(all, delay)
  local i = 0
  for _, section in ipairs(self.order) do
    local dragged = self.drag ~= nil and self.drag.section == section
    if (all or section.isNew) and not dragged then
      tween:Play(section, {
        duration = style.Time.Cascade,
        delay = (delay or 0) + i * style.Time.Stagger,
        from = 0,
        to = 1,
        ease = "outCubic",
        onUpdate = function(v)
          section.frame:SetAlpha(v)
          setRise(section, (1 - v) * style.RISE)
        end,
      })
      i = i + 1
    end
  end
end

-- others returns the sections the column lays out around a dragged section, in order.
---@private
---@return NextSection[]
function canvasProto:others()
  local out = {}
  for _, section in ipairs(self.order) do
    if (self.drag == nil or section ~= self.drag.section) and not self:IsLeaving(section) then
      table.insert(out, section)
    end
  end
  return out
end

-- dragRange is where a dragged section's gap may go among the others: after Recent Items, before
-- Free Space.
---@private
---@return number first, number last
function canvasProto:dragRange()
  local others = self:others()
  local first, last = 1, #others + 1
  for i, section in ipairs(others) do
    if section.kind == "recent" then
      first = i + 1
    elseif section.kind == "free" and last == #others + 1 then
      last = i
    end
  end
  return first, last
end

-- BeginDrag starts a section's drag: the column keeps a gap its size where it was. onLost is
-- called if the section leaves the data, or the canvas is torn down, before the drag ends.
---@param section NextSection
---@param onLost? fun()
function canvasProto:BeginDrag(section, onLost)
  local index = 1
  for _, other in ipairs(self.order) do
    if other == section then
      break
    end
    if not self:IsLeaving(other) then
      index = index + 1
    end
  end
  self.drag = { section = section, index = index, height = section.height, onLost = onLost }
  tween:Stop(section, true)
end

-- SetDragIndex moves the dragged section's gap to index among the others (kept among the
-- categories), laying the column out again when it moved.
---@param index number
function canvasProto:SetDragIndex(index)
  local drag = self.drag
  if drag == nil then
    return
  end
  local first, last = self:dragRange()
  index = math.max(first, math.min(last, index))
  if index ~= drag.index then
    drag.index = index
    self:Invalidate()
  end
end

-- DragIndexAt returns the insertion point among the others for a height from the canvas's top:
-- before the first other section whose middle is below it, laid out without the gap.
---@param localY number
---@return number
function canvasProto:DragIndexAt(localY)
  local y = 0
  for i, section in ipairs(self:others()) do
    if i > 1 then
      y = y + style.SECTION_SPACING
    end
    if localY < y + section.height / 2 then
      return i
    end
    y = y + section.height
  end
  return #self:others() + 1
end

-- GetDragSlotY returns where the last render put the dragged section's gap, from the canvas's top.
---@return number?
function canvasProto:GetDragSlotY()
  return self.dragSlotY
end

-- EndDrag ends a drag. With commit the section takes its gap's place in the order; otherwise it
-- keeps the place it had.
---@param commit boolean
function canvasProto:EndDrag(commit)
  local drag = self.drag
  if drag == nil then
    return
  end
  self.drag = nil
  if commit then
    local others = self:othersExcept(drag.section)
    table.insert(others, math.min(drag.index, #others + 1), drag.section)
    -- Leaving sections keep their places; every other place takes the next of the new order.
    local order, o = {}, 1
    for _, section in ipairs(self.order) do
      if section ~= drag.section and self:IsLeaving(section) then
        table.insert(order, section)
      else
        table.insert(order, others[o])
        o = o + 1
      end
    end
    self.order = order
  end
  self:Invalidate()
end

-- othersExcept returns the sections the column lays out, but except, in order.
---@param except NextSection
---@return NextSection[]
function canvasProto:othersExcept(except)
  local out = {}
  for _, section in ipairs(self.order) do
    if section ~= except and not self:IsLeaving(section) then
      table.insert(out, section)
    end
  end
  return out
end

-- MarkLeaving leaves a section that was moved away out of the column for seconds: it stays out
-- until its category is gone from the data, while it has nothing but gaps, or until the time is
-- up with its items still there (a move the game refused).
---@param name string
---@param seconds number
function canvasProto:MarkLeaving(name, seconds)
  self.leaving[name] = GetTime() + seconds
  self:Invalidate()
end

-- IsLeaving says whether a section is left out of the column as moved away.
---@param section NextSection
---@return boolean
function canvasProto:IsLeaving(section)
  local untilTime = self.leaving[section.name]
  if untilTime == nil then
    return false
  end
  local hasItems = false
  for _, entry in ipairs(section.entries) do
    if entry.item ~= nil then
      hasItems = true
      break
    end
  end
  if hasItems and GetTime() >= untilTime then
    self.leaving[section.name] = nil
    return false
  end
  return true
end

-- Settle ends every move and cascade at its end: the canvas hid.
function canvasProto:Settle()
  motion:Forget(self)
  for _, section in ipairs(self.order) do
    tween:Stop(section, true)
  end
end

-- Release hides and pools every section: the bag is torn down. Buttons are the bag's to release.
function canvasProto:Release()
  self.leaving = {}
  for _, section in ipairs(self.order) do
    self:release(section)
  end
  self.order = {}
  self.byName = {}
  self.buttons = {}
end
