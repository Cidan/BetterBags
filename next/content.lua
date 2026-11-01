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

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

-- NextContent is BetterBagsNext's canvas (next.md §2), the drawable inside the panel's scroll
-- box. Bind turns a tab's data into sections, in one column: Recent Items, the tab's categories
-- in their order, then Free Space; it draws and claims the static item buttons. Render lays the
-- sections out in rows of as many big icons as fit its width, through Motion while it is shown,
-- so what changed place travels there. Cascade fades sections in one after the other.
---@class NextContent: AceModule
local nextContent = addon:NewModule('NextContent')

-- How long a section moved away stays out of its column while its items are still there (MarkLeaving).
nextContent.LEAVING_SECONDS = 3
-- The fewest cells a column of sections takes: a window that cannot give each this many shows fewer (next.md §7a).
nextContent.MIN_COLUMN_CELLS = 2

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
---@field x? number Where the last render put it, from the canvas's left (its column).
---@field width? number The width it was last laid out, what its title has to fit.
---@field gridCells? number The cells of the whole width, in section columns: its gap is the same as every column's.
---@field titleCut? boolean Its title is cut short to fit.
---@field rowFillUnit? number The grid its row's art was painted on.
---@field boundAt? number Which Bind of its canvas last gave it buttons while it waited in a dock card.
---@field rowFill NextFillSet Its header art (Sections.Header), a fill so it can keep its end caps' shape.
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

-- NextColumnSplit is a width split into columns of whole cells.
---@class (exact) NextColumnSplit
---@field cells number The cells of the whole width.
---@field count number How many columns.
---@field split number[] The cells of each, the spare ones in the first.
---@field down boolean Sections fill down a column and then the next, not across a row and then the next.
---@field wide boolean A wide section takes more than one column.
---@field wideRows? number The rows a section reaches to be wide, at least 2.

-- NextColumnCell is where a section stands in a row of columns.
---@class (exact) NextColumnCell
---@field section NextSection
---@field column number
---@field span number How many columns it takes.

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
---@field dragSlotX? number The same, from its left, in section columns.
---@field columnSource? fun(): number, string?, boolean?, number? How many columns its bag is set to, how they fill, whether wide sections span them, and how many rows make a section wide (SetColumnSource).
---@field grid? NextColumnSplit The columns its last render laid out, none for one column.
---@field heldCells table<string, number> The cells each section takes to stay within its bag's Wide Column Limit, held while it shows (neededCells).
---@field heldRows? number The limit it holds them for.
---@field layoutResets? number Which layout of its bag it holds them for (slotInfo.layoutResets).
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
  canvas.heldCells = {}
  canvas.cards = false
  canvas.instant = false
  canvas.buttonSource = itemFrame
  addon.SetScript(canvas.frame, "OnHide", function()
    canvas:Settle()
  end)
  -- It held nothing while hidden, and what it holds from here is what it shows (neededCells): its bag may open on what it
  -- drew before it closed, with no read to lay it out, and a parent may have hidden it (Alt+Z).
  addon.SetScript(canvas.frame, "OnShow", function()
    if canvas.grid ~= nil then
      canvas:Invalidate()
    end
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
  title:SetWordWrap(false)
  local row = inner:CreateTexture(nil, "BACKGROUND")
  local rowArea = CreateFrame("Frame", nil, inner)
  rowArea:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
  rowArea:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, 0)
  row:Hide()
  local cells = CreateFrame("Frame", nil, inner)
  ---@type NextSection
  local section = {
    name = "", kind = "category", frame = frame, inner = inner, title = title, count = count,
    line = line, row = row, rowArea = rowArea, rowFill = fills:Wrap(row, rowArea), cells = cells, entries = {},
    isNew = true, rise = 0, y = 0, height = 0,
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
  -- A font string keeps the width its text took through a font change, and would cut what no longer fits (next-themes.md §14).
  if section.name ~= nil then
    title:SetWidth(0)
    title:SetText(section.name)
    section.titleCut = nil
  end
  section.rowFill:Paint(S.Header or nil)
  section.rowFillUnit = pixel:Unit(section.rowArea)
  self:placeHeader(section)
  if S.Highlight then
    paintFading(section.highlight, S.Highlight)
  else
    section.highlight:Hide()
  end
end

-- LINE_MIN is the shortest line after a section's title and count worth drawing.
local LINE_MIN = 12

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
  -- A font string keeps the width it was cut to: set back to none, its text set again, it measures its whole text.
  if section.titleCut then
    title:SetWidth(0)
    title:SetText(section.name)
    section.titleCut = nil
  end
  local titleWidth = pixel:Ceil(inner, title:GetStringWidth())
  local countGap = pixel:Snap(inner, S.CountGap)
  local countWidth = pixel:Ceil(inner, count:GetStringWidth())
  -- Too long for its section (a column, a narrow window), it is cut short and its count kept. Its full name is
  -- on its header's tooltip.
  if section.width ~= nil then
    local room = math.max(1, pixel:Floor(inner, section.width - x - countGap - countWidth))
    if titleWidth > room then
      titleWidth = room
      title:SetWidth(room)
      section.titleCut = true
    end
  end
  local countX = x + titleWidth + countGap
  count:ClearAllPoints()
  pixel:Point(count, "TOPLEFT", inner, "TOPLEFT", countX, y - pixel:Floor(inner, (titleHeight - fontHeight(count)) / 2))
  local lineX = countX + countWidth + pixel:Snap(inner, S.LineGap)
  local lineY = y - pixel:Floor(inner, (titleHeight - line:GetHeight()) / 2)
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", inner, "TOPLEFT", lineX, lineY)
  line:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, lineY)
  -- No room left after its title and count: anchored past its section's edge, it would draw backwards.
  if S.Line then
    line:SetShown(section.width == nil or lineX + pixel:Length(inner, LINE_MIN) <= section.width)
  end
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
  -- Its art may be shorter than its row (Sections.Header.Height, from the row's top), so a bar leaves room above the
  -- cells (reported with the Make It So theme: a bar as tall as its row sat right on the first row of icons).
  local art = style.Theme.Sections.Header
  pixel:Height(section.row, art and art.Height or style.SECTION_HEADER)
  pixel:Height(section.rowArea, art and art.Height or style.SECTION_HEADER)
  -- Pieced art rounds its caps on the grid it is painted on, and a dock card draws its section on another.
  local unit = pixel:Unit(section.rowArea)
  if art ~= nil and unit ~= section.rowFillUnit then
    section.rowFillUnit = unit
    section.rowFill:Paint(art)
  end
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
  -- A section waiting in a dock card is drawn on the card's grid: its buttons are the dock's to size and place (LayoutSection,
  -- when Pulse sees it bound again).
  if self.away[section] ~= nil then
    section.boundAt = self.binds
  elseif math.abs(button.frame:GetWidth() - icon) > 0.001 then
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
  self.binds = (self.binds or 0) + 1
end

-- finishBind hides and pools last pass's sections that were not drawn again.
---@private
function canvasProto:finishBind()
  for name, section in pairs(self.stale) do
    self.stale[name] = nil
    self.leaving[name] = nil
    self.heldCells[name] = nil
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
-- (the theme's icon times the player's Icon Scale), or a card (CARD_HEIGHT); in whole pixels.
---@return number
function canvasProto:CellHeight()
  return pixel:Length(self.frame, self.cards and style.CARD_HEIGHT or style.ICON)
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

-- Widest is how many cells the largest section the column lays out holds; given a width to lay out for that holds
-- columns of sections, how many cells they need to stay as they stand there: each column as wide as the largest section
-- beside another (at least what keeps them columns), one spanning columns sharing what it needs among them, one alone in
-- its row what it needs, as it can take the row, or as Recent Items or Free Space, at the full width, when that is more
-- (its gaps included: each takes a cell). Not one waiting
-- in a dock (one flying back is laid out again), nor one leaving; 0 while it lays out none. A small panel let go snaps to
-- its widest row of icons (next.md §14g).
---@param layoutWidth? number
---@return number
function canvasProto:Widest(layoutWidth)
  local grid = layoutWidth and self:ColumnSplit(layoutWidth)
  local widest, whole, columned = 0, 0, {}
  for _, section in ipairs(self.order) do
    local away = self.away[section]
    if (away == nil or away.returning) and not self:IsLeaving(section) then
      if grid and section.kind ~= "category" then
        whole = math.max(whole, #section.entries)
      elseif grid then
        table.insert(columned, section)
      else
        widest = math.max(widest, #section.entries)
      end
    end
  end
  if grid and #columned > 0 then
    local column, row = nextContent.MIN_COLUMN_CELLS, 0
    for _, cells in ipairs(self:columnRows(grid, columned)) do
      -- Filling down, one alone in its row still has a column: the sections above it are in that column too.
      local alone = grid.wide and #cells == 1 and (not grid.down or cells[1].span > 1)
      for _, cell in ipairs(cells) do
        if alone then
          row = math.max(row, self:neededCells(grid, cell.section))
        elseif cell.span > 1 then
          column = math.max(column, math.ceil(self:neededCells(grid, cell.section) / cell.span))
        else
          column = math.max(column, #cell.section.entries)
        end
      end
    end
    widest = math.max(grid.count * column, row)
  end
  return math.max(widest, whole)
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
  -- Another tab or view is other places (Show Blizzard Bags keeps its tab ID): nothing travels from what showed.
  if tabID ~= self.boundTab or slotInfo.builtForView ~= self.boundView then
    self.boundTab, self.boundView = tabID, slotInfo.builtForView
    motion:ForgetShown(self)
    self.heldCells = {}
  end
  if slotInfo.layoutResets ~= self.layoutResets then
    self.layoutResets = slotInfo.layoutResets
    self.heldCells = {}
    -- A read that adds a tab re-sorts everything, tab after tab: what moved is placed at once (refresh-scheduler.md §11a).
    if slotInfo.tabArrived then
      motion:Forget(self)
    end
  end

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
    motion:BeginPass(self, style.Time.Interaction, style.StopMotion)
  else
    -- What it places here goes at once, not into a pass some other failed render left open.
    motion:EndPass()
    motion:Forget(self)
  end
  local drag = self.drag
  local y, placed, others = 0, 0, 0
  self.dragSlotX, self.dragSlotY = nil, nil
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
  local grid = self:ColumnSplit(layoutWidth)
  self.grid = grid
  if grid then
    y, placed = self:renderColumns(grid, width, layoutWidth, spacing, y, placed)
  end
  for _, section in ipairs(grid and {} or self.order) do
    -- A section waiting in a dock is laid out by the dock, at the scale of its card (Lead).
    local away = self.away[section]
    if away == nil or away.returning then
      section.gridCells = nil
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
      section.x, section.y = 0, y
      if away == nil then
        motion:Place(section.frame, self.frame, 0, -y)
        section.frame:Show()
      end
      y = y + height
      placed = placed + 1
    end
  end
  if grid == nil and drag ~= nil and drag.index > others then
    room()
  end
  if animated then
    motion:EndPass()
  end
  local height = math.max(1, y)
  self.frame:SetSize(width, height)
  return { Width = width, Height = height }
end

-- SetColumnSource names what says how many columns of sections it lays out, how they fill, whether wide sections
-- span them and how many rows make a section wide: read each time it lays out. Without one (the vendor's cards) it
-- lays out one column.
---@param source fun(): number, string?, boolean?, number?
function canvasProto:SetColumnSource(source)
  self.columnSource = source
end

-- CanReorder says whether a section dragged in its own bag can take another place: not in columns yet.
---@return boolean
function canvasProto:CanReorder()
  return self.grid == nil
end

-- ColumnSplit splits the cells a row holds at layoutWidth into the columns its bag is set to, each a whole number of
-- cells, the spare ones in the first columns, so the window decides each column's size: nil for one column. Decided
-- in units on the width to lay out for, never on lengths rounded to the grid (next-pixel-perfect.md §3).
---@param layoutWidth number
---@return NextColumnSplit?
function canvasProto:ColumnSplit(layoutWidth)
  if self.columnSource == nil then
    return nil
  end
  local wanted, fill, wide, wideRows = self.columnSource()
  local cells = self:PerRow(layoutWidth)
  local count = math.min(wanted, math.floor(cells / nextContent.MIN_COLUMN_CELLS))
  if count <= 1 then
    return nil
  end
  local split, base, spare = {}, math.floor(cells / count), cells % count
  for i = 1, count do
    split[i] = base + (i <= spare and 1 or 0)
  end
  return { cells = cells, count = count, split = split, down = fill == "down", wide = wide == true, wideRows = wideRows }
end

-- neededCells is how many cells keep a section under its bag's Wide Column Limit: reaching that many rows, it is wide
-- (asked, of a limit of 2: a section of 2 rows in its column expands, which is why the least is 2). Held from the first
-- time it is asked while the canvas
-- shows until the layout starts afresh (its bag closes, a sort, another tab), as gaps are (data-loader.md §13): a section
-- reaching the limit while the player looks at it grows taller where it stands, and one shrinking stays as wide, so
-- nothing is pushed across the bag or left a hole by one item coming or going. Asked: "content changes and isn't always
-- stable, so rows above or below it might get gapped out".
---@private
---@param grid NextColumnSplit
---@param section NextSection
---@return number
function canvasProto:neededCells(grid, section)
  if grid.wideRows ~= self.heldRows then
    self.heldRows = grid.wideRows
    self.heldCells = {}
  end
  local held = self.heldCells[section.name]
  if held ~= nil then
    return held
  end
  local needed = math.ceil(#section.entries / (grid.wideRows - 1))
  if self.frame:IsVisible() then
    self.heldCells[section.name] = needed
  end
  return needed
end

-- ReleaseWidths lets go of the widths it holds, and lays out again in columns: a sort that moved nothing has no read to
-- start the layout afresh, and the player sorted to tidy up.
function canvasProto:ReleaseWidths()
  self.heldCells = {}
  if self.grid ~= nil then
    self:Invalidate()
  end
end

-- columnRows arranges sections in rows, in their order. Rows are the only way sections stand side by side: every
-- section of a row starts on the row's line, and the next row starts below the tallest of them. Never disjoint rows
-- (asked: "absolutely no disjoint rows", for visual clarity). Filling across, a wide section takes as many columns as
-- keep it under its bag's limit from where it would stand; not fitting in what is left of its row, it starts the next one,
-- as nothing is ever put ahead of its order. Filling down, a wide section takes a row of its own across every column,
-- and the sections between such rows fill down their columns.
---@private
---@param grid NextColumnSplit
---@param sections NextSection[]
---@return NextColumnCell[][]
function canvasProto:columnRows(grid, sections)
  local split, count = grid.split, grid.count
  local rows = {}
  if grid.down then
    -- A run fills down the columns. The first section reaching the limit in the column it lands in takes a row of its own,
    -- and the sections either side of it land again, as their own runs.
    local function fillDown(run)
      local tall = math.ceil(#run / count)
      for i, section in ipairs(run) do
        if grid.wide and self:neededCells(grid, section) > split[math.floor((i - 1) / tall) + 1] then
          fillDown({ unpack(run, 1, i - 1) })
          table.insert(rows, { { section = section, column = 1, span = count } })
          fillDown({ unpack(run, i + 1) })
          return
        end
      end
      local first = #rows
      for i, section in ipairs(run) do
        local at = first + (i - 1) % tall + 1
        rows[at] = rows[at] or {}
        table.insert(rows[at], { section = section, column = math.floor((i - 1) / tall) + 1, span = 1 })
      end
    end
    fillDown(sections)
    return rows
  end
  -- The columns a section takes from a column to stay under its limit; nil when what is left is too few.
  local function spanFrom(section, column)
    if not grid.wide then
      return 1
    end
    local needed, held = self:neededCells(grid, section), 0
    for c = column, count do
      held = held + split[c]
      if held >= needed then
        return c - column + 1
      end
    end
    return nil
  end
  local row, column = {}, 1
  for _, section in ipairs(sections) do
    local span = spanFrom(section, column)
    if span == nil and column > 1 then
      table.insert(rows, row)
      row, column = {}, 1
      span = spanFrom(section, 1)
    end
    span = span or count
    table.insert(row, { section = section, column = column, span = span })
    column = column + span
    if column > count then
      table.insert(rows, row)
      row, column = {}, 1
    end
  end
  if #row > 0 then
    table.insert(rows, row)
  end
  return rows
end

-- renderColumns lays its sections out in columns, from height y: Recent Items above them and Free Space below, at the
-- full width, and the rest in rows (columnRows), every icon on one grid, a column's first cell a step from the last
-- cell of the one before. A dragged section keeps its place, as nothing reorders in columns yet.
---@private
---@param grid NextColumnSplit
---@param width number
---@param layoutWidth number
---@param spacing number
---@param y number
---@param placed number
---@return number y, number placed
function canvasProto:renderColumns(grid, width, layoutWidth, spacing, y, placed)
  local frame, drag = self.frame, self.drag
  local top, middle, bottom = {}, {}, {}
  for _, section in ipairs(self.order) do
    local away = self.away[section]
    local dragged = drag ~= nil and section == drag.section
    if not dragged and self:IsLeaving(section) then
      section.frame:Hide()
    elseif dragged or away == nil or away.returning then
      table.insert(section.kind == "recent" and top or section.kind == "free" and bottom or middle, section)
    end
  end
  local function place(section, x, at)
    section.x, section.y = x, at
    if drag ~= nil and section == drag.section then
      self.dragSlotX, self.dragSlotY = x, at
    elseif self.away[section] == nil then
      motion:Place(section.frame, frame, x, -at)
      section.frame:Show()
    end
  end
  local function whole(list)
    for _, section in ipairs(list) do
      section.gridCells = nil
      self:LayoutSection(section, width, layoutWidth)
      if placed > 0 then
        y = y + spacing
      end
      place(section, 0, y)
      y = y + section.height
      placed = placed + 1
    end
  end
  whole(top)
  local cellWidth, gap = self:gridLengths(frame, grid.cells)
  local step = cellWidth + gap
  local xs = { 0 }
  for i = 1, grid.count do
    xs[i + 1] = xs[i] + grid.split[i] * step
  end
  for _, row in ipairs(self:columnRows(grid, middle)) do
    local tallest = 0
    for _, cell in ipairs(row) do
      local section = cell.section
      local cells = 0
      for c = cell.column, cell.column + cell.span - 1 do
        cells = cells + grid.split[c]
      end
      local columnWidth, columnLayout = cells * step - gap, self:RowWidth(cells)
      section.gridCells = grid.cells
      self:LayoutSection(section, columnWidth, columnLayout)
      local height = section.height
      local away = self.away[section]
      local dragged = drag ~= nil and section == drag.section
      -- Drawn on another grid than the column's, its room is its height on the column's (MeasureSection).
      if dragged or (away ~= nil and away.returning) then
        height = self:MeasureSection(section, frame, columnWidth, columnLayout).height
      end
      tallest = math.max(tallest, height)
    end
    if placed > 0 then
      y = y + spacing
    end
    for _, cell in ipairs(row) do
      place(cell.section, xs[cell.column], y)
    end
    y = y + tallest
    placed = placed + 1
  end
  whole(bottom)
  return y, placed
end

-- gridLengths is a cell's width and the gap between cells in whole pixels on grid, for rows of cells cells: where the
-- grid's rounded lengths would run past the row's own width (RowWidth: its cells and gaps in units, the least width
-- that holds them; up to a pixel per cell, over the scroll bar's room), the gap closes by the pixel or two the rounding
-- added. Every gap the same, and the same for a column count whatever the width it is drawn in. Reported: "resizing the
-- window ... causes a ton of item icon jitter all over"; closed for the width drawn, the gaps opened again a pixel or
-- two after each column was added while a grip sized a panel, every icon jumping a second time (up to 19 pixels across,
-- rows a pixel or three down).
---@private
---@param grid Region
---@param cells number
---@return number cellWidth, number gap
function canvasProto:gridLengths(grid, cells)
  local cellWidth, gap = pixel:Lengths(grid, self.cards and style.VENDOR_CARD_WIDTH or style.ICON, style.GAP)
  if cells > 1 then
    gap = math.max(0, math.min(gap, pixel:Floor(grid, (self:RowWidth(cells) - cells * cellWidth) / (cells - 1))))
  end
  return cellWidth, gap
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
  section.width = width
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
      motion:Place(item.frame, section.cells, column * step, -row * rowStep, motion.ShownBy(item))
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
  local perRow = self:PerRow(layoutWidth)
  local cellWidth, gap = self:gridLengths(grid, section.gridCells or perRow)
  local cellHeight, header = pixel:Lengths(grid, self.cards and style.CARD_HEIGHT or style.ICON, style.SECTION_HEADER)
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

-- GetDragSlotX returns where the last render put the dragged section's gap, from the canvas's left: its column.
---@return number?
function canvasProto:GetDragSlotX()
  return self.dragSlotX
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
  pixel:Point(section.frame, "TOPLEFT", self.frame, "TOPLEFT", section.x or 0, -(section.y or 0))
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
  self.heldCells = {}
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
