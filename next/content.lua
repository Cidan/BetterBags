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

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextItemFit: AceModule
local itemFit = addon:GetModule('NextItemFit')

-- NextContent is BetterBagsNext's canvas (next.md §2), the drawable inside the panel's scroll
-- box. Bind turns a tab's data into sections, in one column: Recent Items, the tab's categories
-- in their order, then Free Space; it draws and claims the static item buttons. Render lays the
-- sections out in rows of as many big icons as fit its width, through Motion while it is shown,
-- so what changed place travels there. Cascade fades sections in one after the other.
---@class NextContent: AceModule
local nextContent = addon:NewModule('NextContent')

-- How long a section moved away stays out of its column while its items are still there (MarkLeaving).
nextContent.LEAVING_SECONDS = 3

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
---@field row Texture The theme's art behind the title row (Sections.Header), across the section.
---@field highlight Texture Lit under the title row while the pointer is over it.
---@field cells Frame The item buttons hang from it.
---@field header Button Across the title row: dragging it moves the section (next.md §7).
---@field entries NextSectionEntry[]
---@field isNew boolean It was not drawn in the previous pass.
---@field rise number How far below its place it is, in pixels.
---@field y number Where the last render put it, from the canvas's top.
---@field height number Its height in the last render.

-- NextCanvasAway is a section held out of the column (HoldOut).
---@class (exact) NextCanvasAway
---@field returning boolean It flies back to its place: the column keeps its room, its frame is not placed.
---@field onLost? fun() Called when it leaves the data, or the canvas is torn down, while held.

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
---@field away table<NextSection, NextCanvasAway> Sections held out of the column: waiting in a dock (NextDock), or flying back to their place (returning).
---@field lead? fun(width: number): {frame: Frame, height: number}[] Frames laid out above the sections (a dock's cards, SetLead).
---@field headerHandler? NextHeaderHandler
---@field cards boolean Its buttons are cards, an item's name and price beside its icon (the vendor's: SetCards).
---@field buttonSource {GetButton: fun(self: any, ctx: Context, slotkey: string): Item} Where Bind takes its buttons: the item buttons, or the guild bank's (SetButtonSource).
---@field instant boolean It places everything at once, nothing gliding (SetInstant: its panel is being resized).
local canvasProto = drawable:Extend({}, 'NextCanvas')

---@param parent Frame
---@return NextCanvas
function nextContent:Create(parent)
  ---@type NextCanvas
  local canvas = drawable:Create(canvasProto)
  canvas.frame = CreateFrame("Frame", nil, parent)
  pixel:Size(canvas.frame, style.GRID_WIDTH, 1)
  canvas.order = {}
  canvas.byName = {}
  canvas.stale = {}
  canvas.pool = {}
  canvas.buttons = {}
  canvas.freeTotal = 0
  canvas.leaving = {}
  canvas.away = {}
  canvas.cards = false
  canvas.instant = false
  canvas.buttonSource = itemFrame
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
  local count = inner:CreateFontString(nil, "OVERLAY")
  local line = inner:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 1)
  local row = inner:CreateTexture(nil, "BACKGROUND")
  row:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
  row:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, 0)
  row:Hide()
  local cells = CreateFrame("Frame", nil, inner)
  ---@type NextSection
  local section = {
    name = "", kind = "category", frame = frame, inner = inner, title = title, count = count,
    line = line, row = row, cells = cells, entries = {}, isNew = true, rise = 0, y = 0, height = 0,
  }
  section.header = self:newHeader(section)
  self:styleSection(section)
  return section
end

-- titleRole is the theme's text role for a section's title, by its kind.
---@param kind "recent"|"category"|"free"
---@return string
local function titleRole(kind)
  local S = style.Theme.Sections
  if kind == "recent" then
    return S.RecentFont
  elseif kind == "free" then
    return S.FreeFont
  end
  return S.TitleFont
end

-- paintFading draws a section's line or highlight: art (a texture spec with a Texture or an Atlas, painted), or a
-- color fading across from its From alpha to its To.
---@param texture Texture
---@param spec table
local function paintFading(texture, spec)
  if style:IsArt(spec) then
    style:Paint(texture, spec, spec.Alpha)
  else
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient("HORIZONTAL", style:CreateColor(spec.Color, spec.From), style:CreateColor(spec.Color, spec.To))
  end
  texture:Show()
end

-- styleSection draws a section's title row from the theme: the title and count in its roles, the line
-- after them (or none), the art behind the row (or none), the header's height and highlight (or none),
-- the cells below it, in whole pixels. Where the title row's parts go depends on its text:
-- placeTitleRow, every render.
---@private
---@param section NextSection
function canvasProto:styleSection(section)
  local S = style.Theme.Sections
  local title, count, line = section.title, section.count, section.line
  style:SetFont(title, titleRole(section.kind))
  style:SetFont(count, S.CountFont)
  if S.Line then
    paintFading(line, S.Line)
  else
    line:Hide()
  end
  if S.Header then
    style:Paint(section.row, S.Header, S.Header.Alpha)
    section.row:Show()
  else
    section.row:Hide()
  end
  self:placeHeader(section)
  if S.Highlight then
    paintFading(section.highlight, S.Highlight)
  else
    section.highlight:Hide()
  end
end

-- fontHeight is a text's font's height: a whole number of pixels (NextStyle makes every role's so).
---@param text FontString
---@return number
local function fontHeight(text)
  local _, height = text:GetFont()
  return height or 0
end

-- placeTitleRow puts a section's title row on whole pixels (docs/next-pixel-perfect.md): the title at the
-- theme's place, the count after the title's text and the line after the count's, each by its top left,
-- the count and the line centered on the title by the fonts' heights. Anchored to a text's middle or its
-- right edge they would follow the client's measure of the text, between pixels.
---@private
---@param section NextSection
function canvasProto:placeTitleRow(section)
  local S = style.Theme.Sections
  local inner, title, count, line = section.inner, section.title, section.count, section.line
  local x, y = pixel:Snap(inner, S.Title.X), pixel:Snap(inner, S.Title.Y)
  title:ClearAllPoints()
  pixel:Point(title, "TOPLEFT", inner, "TOPLEFT", x, y)
  local titleHeight = fontHeight(title)
  local countX = x + pixel:Ceil(inner, title:GetStringWidth()) + pixel:Snap(inner, S.CountGap)
  count:ClearAllPoints()
  pixel:Point(count, "TOPLEFT", inner, "TOPLEFT", countX, y - pixel:Floor(inner, (titleHeight - fontHeight(count)) / 2))
  local lineX = countX + pixel:Ceil(inner, count:GetStringWidth()) + pixel:Snap(inner, S.LineGap)
  local lineY = y - pixel:Floor(inner, (titleHeight - line:GetHeight()) / 2)
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", inner, "TOPLEFT", lineX, lineY)
  line:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, lineY)
end

-- placeHeader lays a section's header out on the grid it is drawn on (docs/next-pixel-perfect.md): the line's
-- thickness, the title row, the header's height and the cells under it, all in whole pixels. Again when the
-- section is laid out (LayoutSection): seated in a dock card it is drawn at the card's scale.
---@private
---@param section NextSection
function canvasProto:placeHeader(section)
  local spec = style.Theme.Sections.Line
  if spec then
    pixel:Height(section.line, spec.Size)
  end
  self:placeTitleRow(section)
  section.cells:ClearAllPoints()
  pixel:Point(section.cells, "TOPLEFT", section.inner, "TOPLEFT", 0, -style.SECTION_HEADER)
  pixel:Height(section.header, style.SECTION_HEADER)
  pixel:Height(section.row, style.SECTION_HEADER)
end

-- ApplyStyle restyles every section it holds (drawn, kept from the last pass, pooled) for the
-- current theme, and lays them out again (SonataNext applied a theme). Its buttons take the theme's
-- icon size when they are drawn next (claim).
---@param ctx Context
function canvasProto:ApplyStyle(ctx)
  local _ = ctx
  for _, list in ipairs({ self.order, self.pool }) do
    for _, section in ipairs(list) do
      self:styleSection(section)
    end
  end
  for _, section in pairs(self.stale) do
    self:styleSection(section)
  end
  self:Invalidate()
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
  header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  header:RegisterForDrag("LeftButton")
  local highlight = header:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 1)
  section.highlight = highlight
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
  pixel:Point(section.inner, "TOPLEFT", section.frame, "TOPLEFT", 0, -rise)
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
  style:SetFont(section.title, titleRole(kind))
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
  local away = self.away[section]
  if away ~= nil then
    self.away[section] = nil
    if away.onLost then
      away.onLost()
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
  local button = self.buttonSource:GetButton(ctx, slotkey)
  claims[button] = true
  local icon = pixel:Length(self.frame, style.ICON)
  if math.abs(button.frame:GetWidth() - icon) > 0.001 then
    button:SetSize(ctx, icon, icon)
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
    -- An empty slot drawn in place (a tab shown in slot order, which has no Free Space for it).
    button:SetFreeSlots(ctx, data, -1)
    self.freeTotal = self.freeTotal + 1
  else
    button:SetItemFromData(ctx, data)
  end
end

-- beginBind sets last pass's sections aside for reuse and starts an empty pass.
---@private
function canvasProto:beginBind()
  for name, section in pairs(self.byName) do
    self.stale[name] = section
  end
  self.byName = {}
  self.order = {}
  self.buttons = {}
  self.freeTotal = 0
end

-- finishBind hides and pools last pass's sections that were not drawn again.
---@private
function canvasProto:finishBind()
  for name, section in pairs(self.stale) do
    self.stale[name] = nil
    self.leaving[name] = nil
    self:release(section)
  end
end

-- SetButtonSource makes Bind take its buttons from source (GetButton) instead of the item buttons:
-- the guild bank's slots are not bag slots (guild-bank.md §5).
---@param source {GetButton: fun(self: any, ctx: Context, slotkey: string): Item}
function canvasProto:SetButtonSource(source)
  self.buttonSource = source
end

-- SetCards says its buttons are cards (the vendor's): an item's name and price beside its icon, as
-- wide as the theme's columns make them.
---@param on boolean
function canvasProto:SetCards(on)
  self.cards = on
  self:Invalidate()
end

-- CellWidth is how wide a button is, without the gap, for the current theme: its icon, or a card; in
-- whole pixels on the canvas's grid.
---@return number
function canvasProto:CellWidth()
  return pixel:Length(self.frame, self.cards and style.VENDOR_CARD_WIDTH or style.ICON)
end

-- CellHeight is how tall a row of buttons is, without the gap, for the current theme: an item button
-- (the theme's icon times the player's Icon Scale), or a card (the theme's icon); in whole pixels.
---@return number
function canvasProto:CellHeight()
  return pixel:Length(self.frame, self.cards and style.CARD_ICON or style.ICON)
end

-- PerRow is how many cells a row holds in layoutWidth (the width to lay out for, in units: a panel's own, never rounded
-- to its grid, next-pixel-perfect.md §3): its icons, or cards, with the theme's gap between them; at least one.
---@param layoutWidth number
---@return number
function canvasProto:PerRow(layoutWidth)
  local step = (self.cards and style.VENDOR_CARD_WIDTH or style.ICON) + style.GAP
  return math.max(1, math.floor((layoutWidth + style.GAP) / step + 1e-6))
end

-- RowWidth is how wide perRow cells are with the gaps between them, in units: the width a small panel snaps its
-- content to (next.md §14g).
---@param perRow number
---@return number
function canvasProto:RowWidth(perRow)
  return perRow * ((self.cards and style.VENDOR_CARD_WIDTH or style.ICON) + style.GAP) - style.GAP
end

-- Widest is how many cells the largest section the column lays out holds (its gaps included: each takes a cell): not
-- one waiting in a dock (one flying back is laid out again), nor one leaving; 0 while it lays out none. A small panel
-- let go snaps to its widest row of icons (next.md §14g).
---@return number
function canvasProto:Widest()
  local widest = 0
  for _, section in ipairs(self.order) do
    local away = self.away[section]
    if (away == nil or away.returning) and not self:IsLeaving(section) then
      widest = math.max(widest, #section.entries)
    end
  end
  return widest
end

---@class (exact) NextCanvasSection
---@field name string
---@field buttons {key: string, frame: Frame}[] Drawn already, in order.
---@field count? string What its header counts, the number of buttons by default.

-- BindSections puts sections of buttons the caller drew (the vendor's) into the canvas, in their
-- order. The buttons are the caller's to release.
---@param sections NextCanvasSection[]
function canvasProto:BindSections(sections)
  self:beginBind()
  for _, s in ipairs(sections) do
    local section = self:section(s.name, "category")
    for _, button in ipairs(s.buttons) do
      if button.frame:GetParent() ~= section.cells then
        button.frame:SetParent(section.cells)
      end
      table.insert(section.entries, { item = button })
      self.buttons[button.key] = button
    end
    section.count:SetText(s.count or tostring(#s.buttons))
  end
  self:finishBind()
end

-- Bind puts a tab's data into sections and draws their buttons, claiming each in claims. Last
-- pass's sections not drawn again are hidden and pooled; their buttons are left to the bag's
-- sweep.
---@param ctx Context
---@param slotInfo SlotInfo
---@param tabID number
---@param claims table<Item, boolean>
function canvasProto:Bind(ctx, slotInfo, tabID, claims)
  self:beginBind()

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
    self.freeTotal = self.freeTotal + total
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

  self:finishBind()
end

-- SetInstant makes the canvas place everything at once while on: its panel is being resized
-- (next.md §14g), and its rows reflow with the edge as a web page's do, nothing gliding behind it.
---@param on boolean
function canvasProto:SetInstant(on)
  self.instant = on
end

-- Render lays the sections out in one column, in rows of as many cells as fit the width it is
-- given; while the canvas is shown, through a Motion pass, so what changed place travels there
-- (but not while it places at once, SetInstant).
---@param parentResult? RenderResult
---@return RenderResult
function canvasProto:Render(parentResult)
  -- Everything in whole pixels on its grid (docs/next-pixel-perfect.md): the width it may take rounded
  -- down, and every step a sum of whole pixels, so its rows step evenly.
  local frame = self.frame
  local width = pixel:Floor(frame, parentResult and parentResult.Width or style.GRID_WIDTH)
  -- The width its rows are decided on, in units (a panel's own, never rounded to its grid): LayoutSection.
  local layoutWidth = parentResult and parentResult.LayoutWidth or width
  local spacing = pixel:Length(frame, style.SECTION_SPACING)
  local animated = self.frame:IsVisible() and not self.instant
  if animated then
    motion:BeginPass(self, style.Time.Interaction)
  else
    motion:Forget(self)
  end
  local drag = self.drag
  local y, placed, others = 0, 0, 0
  self.dragSlotY = nil
  for _, lead in ipairs(self.lead and self.lead(width, layoutWidth) or {}) do
    if placed > 0 then
      y = y + spacing
    end
    motion:Place(lead.frame, frame, pixel:Floor(frame, (width - lead.frame:GetWidth()) / 2), -y)
    y = y + pixel:Snap(frame, lead.height)
    placed = placed + 1
  end
  -- room keeps the dragged section's room in the column.
  local function room()
    if placed > 0 then
      y = y + spacing
    end
    self.dragSlotY = y
    y = y + drag.height
    placed = placed + 1
  end
  for _, section in ipairs(self.order) do
    -- A section waiting in a dock is laid out by the dock, at the scale of its card (Lead).
    local away = self.away[section]
    if away == nil or away.returning then
      self:LayoutSection(section, width, layoutWidth)
    end
    local height = section.height
    -- Held in a drag (drawn shrunk) or flying back from a dock, it is drawn on another grid than the column's: its
    -- room is its height on the column's (MeasureSection).
    if (drag ~= nil and section == drag.section) or (away ~= nil and away.returning) then
      height = self:MeasureSection(section, frame, width, layoutWidth).height
    end
    if drag ~= nil and section == drag.section then
      drag.height = height
    elseif self:IsLeaving(section) then
      section.frame:Hide()
    elseif away == nil or away.returning then
      others = others + 1
      if drag ~= nil and others == drag.index then
        room()
      end
      if placed > 0 then
        y = y + spacing
      end
      section.y = y
      if away == nil then
        motion:Place(section.frame, self.frame, 0, -y)
        section.frame:Show()
      end
      y = y + height
      placed = placed + 1
    end
  end
  if drag ~= nil and drag.index > others then
    room()
  end
  if animated then
    motion:EndPass()
  end
  local height = math.max(1, y)
  self.frame:SetSize(width, height)
  return { Width = width, Height = height }
end

-- LayoutSection lays a section out width wide in its own units (the column's width), in whole pixels on its
-- own grid (docs/next-pixel-perfect.md): its title row, its cells in rows, each a whole number of pixels apart,
-- its size from them. Its own grid is its frame's: the column's, or a dock card's (a docked section is scaled
-- down to fit its card), where its item buttons take its grid's icon size too. Its size times its scale is then
-- whole on the grid it is drawn on. It returns its width and height.
--
-- How many cells go in a row is decided on layoutWidth (the width to lay out for, in units: a panel's own, never
-- rounded to its grid) with the theme's lengths, never on lengths rounded to the grid: the grid changes with a
-- panel's Bag Scale, and rounded lengths moved items between rows as it did (next-pixel-perfect.md §3). A
-- section laid out again with none (in a dock card) keeps the rows it had.
---@param section NextSection
---@param width number
---@param layoutWidth? number
---@return number width, number height
function canvasProto:LayoutSection(section, width, layoutWidth)
  local f = section.frame
  local ctx
  layoutWidth = layoutWidth or section.layoutWidth or pixel:Floor(f, width)
  section.layoutWidth = layoutWidth
  local m = self:MeasureSection(section, f, width, layoutWidth)
  width = m.width
  local perRow, cellWidth, rows, height = m.perRow, m.cellWidth, m.rows, m.height
  local step, rowStep = m.step, m.rowStep
  self:placeHeader(section)
  section.height = height
  section.frame:SetSize(width, height)
  section.inner:SetSize(width, height)
  section.cells:SetSize(width, rows * rowStep)
  for j, entry in ipairs(section.entries) do
    local item = entry.item
    if item ~= nil then
      -- A card styles itself for the grid it is now on (it was made before it was placed).
      if item.Fit ~= nil then
        item:Fit()
      end
      if not self.cards and math.abs(item.frame:GetWidth() - cellWidth) > 0.001 then
        ctx = ctx or addon:GetModule('Context'):New('NextCanvas_LayoutSection')
        item:SetSize(ctx, cellWidth, cellWidth)
      end
      -- Its parts on whole pixels of its size and grid (NextItemFit): an item button's decoration and the
      -- item level text on its interaction button, or the parts a button names (a guild bank button).
      local decoration, extras
      if item.GetDecoration ~= nil then
        ctx = ctx or addon:GetModule('Context'):New('NextCanvas_LayoutSection')
        decoration, extras = item:GetDecoration(ctx), { item.ilvlText }
      elseif item.PixelParts ~= nil then
        decoration, extras = item:PixelParts()
      end
      if decoration ~= nil then
        ctx = ctx or addon:GetModule('Context'):New('NextCanvas_LayoutSection')
        itemFit:Fit(ctx, decoration, extras, item)
      end
      local column, row = (j - 1) % perRow, math.floor((j - 1) / perRow)
      motion:Place(item.frame, section.cells, column * step, -row * rowStep)
      item.frame:Show()
    end
  end
  return width, height
end

-- MeasureSection works out a section's layout in whole pixels on grid's pixel grid (a frame: the section's own,
-- where it is drawn, or the column's, where it takes room), width wide, its cells per row decided on layoutWidth
-- (LayoutSection). Nothing moves. A section drawn on another grid than the column's (held in a drag, drawn shrunk;
-- flying back from a dock) takes room measured on the column's: its own grid's whole pixels are not the column's.
---@param section NextSection
---@param grid Region
---@param width number
---@param layoutWidth number
---@return {width: number, perRow: number, cellWidth: number, cellHeight: number, step: number, rowStep: number, rows: number, height: number}
function canvasProto:MeasureSection(section, grid, width, layoutWidth)
  width = pixel:Floor(grid, width)
  local cellWidth, cellHeight = pixel:Lengths(grid, self.cards and style.VENDOR_CARD_WIDTH or style.ICON,
    self.cards and style.CARD_ICON or style.ICON)
  local gap, header = pixel:Lengths(grid, style.GAP, style.SECTION_HEADER)
  local perRow = self:PerRow(layoutWidth)
  -- The row fits its own width (RowWidth: its cells and gaps in units, the least width that holds them): where the
  -- grid's rounded lengths would run past it (up to a pixel per cell, over the scroll bar's room), the gap closes by the
  -- pixel or two the rounding added. Every gap the same, and the same for a column count whatever the width it is
  -- drawn in. Reported: "resizing the window ... causes a ton of item icon jitter all over"; closed for the width
  -- drawn, the gaps opened again a pixel or two after each column was added while a grip sized a panel, every icon
  -- jumping a second time (up to 19 pixels across, rows a pixel or three down).
  if perRow > 1 then
    gap = math.max(0, math.min(gap, pixel:Floor(grid, (self:RowWidth(perRow) - perRow * cellWidth) / (perRow - 1))))
  end
  local rows = math.max(1, math.ceil(#section.entries / perRow))
  return { width = width, perRow = perRow, cellWidth = cellWidth, cellHeight = cellHeight, step = cellWidth + gap,
    rowStep = cellHeight + gap, rows = rows, height = header + rows * (cellHeight + gap) - gap }
end

-- Cascade fades sections in one after the other, rising into place: every section with all,
-- else only the ones new this pass. delay holds the first one back.
---@param all boolean
---@param delay? number
function canvasProto:Cascade(all, delay)
  local i = 0
  for _, section in ipairs(self.order) do
    local dragged = self.drag ~= nil and self.drag.section == section
    if (all or section.isNew) and not dragged and self.away[section] == nil then
      tween:Play(section, {
        duration = style.Time.Cascade,
        delay = (delay or 0) + i * style.Time.Stagger,
        from = 0,
        to = 1,
        ease = style:Ease("Cascade"),
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
    if (self.drag == nil or section ~= self.drag.section) and not self:isOut(section) then
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
    if not self:isOut(other) then
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
    -- Leaving and held sections keep their places; every other place takes the next of the new order.
    local order, o = {}, 1
    for _, section in ipairs(self.order) do
      if section ~= drag.section and self:isOut(section) then
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
    if section ~= except and not self:isOut(section) then
      table.insert(out, section)
    end
  end
  return out
end

-- isOut says whether a section is out of the column: moved away (IsLeaving), or waiting in a dock (held,
-- not flying back).
---@private
---@param section NextSection
---@return boolean
function canvasProto:isOut(section)
  local away = self.away[section]
  return (away ~= nil and not away.returning) or self:IsLeaving(section)
end

-- HoldOut takes a section out of the column, as it waits in another panel's dock (NextDock): the others
-- close up, its frame is left to the dock, and it is still bound (its buttons drawn, kept up to date).
-- onLost is called if it leaves the data, or the canvas is torn down, while held: before it is let go,
-- so its frame can come back first.
---@param section NextSection
---@param onLost? fun()
function canvasProto:HoldOut(section, onLost)
  tween:Stop(section, true)
  self.away[section] = { returning = false, onLost = onLost }
  self:Invalidate()
end

-- Returning keeps a held section's room in the column, where it is flying back to: renders lay it out
-- (section.y) but do not place its frame.
---@param section NextSection
function canvasProto:Returning(section)
  local away = self.away[section]
  if away ~= nil then
    away.returning = true
    self:Invalidate()
  end
end

-- Return puts a held section back in the column, anchored at once where it is laid out (the last
-- render's section.y): it is there already.
---@param section NextSection
function canvasProto:Return(section)
  if self.away[section] == nil then
    return
  end
  self.away[section] = nil
  section.frame:ClearAllPoints()
  pixel:Point(section.frame, "TOPLEFT", self.frame, "TOPLEFT", 0, -(section.y or 0))
  section.frame:Show()
  self:Invalidate()
end

-- IsAway says whether a section is held out of the column (HoldOut), waiting or flying back.
---@param section NextSection
---@return boolean
function canvasProto:IsAway(section)
  return self.away[section] ~= nil
end

-- SetLead lays frames out above the sections, centered, each as tall as it says (a dock's cards): lead
-- is asked for them, with the column's width, at every render, and they move as sections do.
---@param lead? fun(width: number, layoutWidth: number): {frame: Frame, height: number}[]
function canvasProto:SetLead(lead)
  self.lead = lead
  self:Invalidate()
end

-- MarkLeaving leaves a section that was moved away out of the column for seconds (LEAVING_SECONDS when
-- not given): it stays out until its category is gone from the data, while it has nothing but gaps, or
-- until the time is up with its items still there (a move the game refused). The column is laid out
-- again when the time is up: only a layout brings it back, and nothing else may draw the bag again
-- (reported: a section the merchant did not take all of stayed hidden).
---@param name string
---@param seconds? number
function canvasProto:MarkLeaving(name, seconds)
  local untilTime = GetTime() + (seconds or nextContent.LEAVING_SECONDS)
  self.leaving[name] = untilTime
  self:Invalidate()
  C_Timer.After(seconds or nextContent.LEAVING_SECONDS, function()
    if self.leaving[name] == untilTime then
      self:Invalidate()
    end
  end)
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
