local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextScrollBar: AceModule
local nextScrollBar = addon:GetModule('NextScrollBar')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

---@class PixelAudit: AceModule
local pixelAudit = addon:GetModule('PixelAudit')

-- NextMenu is BetterBags Next's menu of choices (next-settings.md §2): one at a time, drawn from the
-- theme (Controls.Menu), below what opened it, over everything (FULLSCREEN_DIALOG), a row per
-- choice, the chosen one checked, scrolling past MaxRows. A click picks a choice and closes it; a
-- click or the wheel anywhere else, Escape, opening it again for the same frame, or that frame
-- hiding, closes it. A menu to find a choice in (opts.filter: the category picker, issue #1270) has a
-- field over its choices, focused, that reads them again as the player types; the choice Enter takes
-- is lit (Up and Down move the light, the pointer leaves it where it last was), and Escape in the field
-- closes it. Over both, a head may say what the menu is for (an item's icon, its name and a note).
---@class NextMenu: AceModule
---@field frame Frame
---@field fill Texture
---@field border Texture Art over the fill (the theme's Border: Classic's menu art reaching past the menu).
---@field edge NextEdge
---@field box WowScrollBox
---@field list Frame The rows, scrolled by box.
---@field bar NextScrollBarFrame
---@field catcher Button Takes clicks outside the menu, closing it.
---@field rows NextMenuRow[] Every row made; the first #items are shown.
---@field items NextMenuItem[]
---@field lit? number The row Enter takes, lit as under the pointer.
---@field headFrame Frame The head's icon, with its edge.
---@field headIcon Texture
---@field headEdge NextEdge
---@field headText FontString
---@field headNote FontString
---@field field NextInputFrame Finds a choice, in a menu with a filter.
---@field anchor? Frame
---@field opts? NextMenuOptions
---@field open boolean
---@field hooked table<Frame, boolean>
local nextMenu = addon:NewModule('NextMenu')

---@class (exact) NextMenuItem
---@field text string
---@field value? any
---@field selected? boolean
---@field disabled? boolean
---@field note? string A word at its right (how many items a category holds; whose it is).
---@field color? number[] A dot of this color before its text ({ r, g, b }).
---@field glyph? table Drawn where the check goes, for a choice that does something other than choose (Texture or Atlas, Color).

---@class (exact) NextMenuHead
---@field icon number|string
---@field edge? number[] Its icon's edge in this color ({ r, g, b }: an item's quality), else Controls.ItemGrid.CommonEdge.
---@field text string
---@field note? string

---@class (exact) NextMenuFilter
---@field help string The field's help.
---@field items fun(text: string): NextMenuItem[], number? The choices for what is typed, and the one Enter takes (none: Enter closes).

---@class (exact) NextMenuOptions
---@field items? NextMenuItem[] Its choices, unless it has a filter.
---@field onPick fun(ctx: Context, item: NextMenuItem)
---@field onClose? fun()
---@field width? number At least this wide.
---@field style? table Over the theme's Menu.
---@field head? NextMenuHead
---@field filter? NextMenuFilter

---@class NextMenuRow
---@field frame Button
---@field hover Texture
---@field label FontString
---@field check Texture
---@field ring Texture Under the check: the empty radio ring (Check.Off, Check.Under), Blizzard's radio menus.
---@field dot Texture
---@field note FontString
---@field item? NextMenuItem
local rowProto = {}
addon:GetModule('Perf'):RegisterPrototype(rowProto, 'NextMenuRow')

nextMenu.rows = {}
nextMenu.items = {}
nextMenu.open = false
nextMenu.hooked = setmetatable({}, { __mode = "k" })

-- build makes the menu's frames, the first time it opens.
---@private
function nextMenu:build()
  if self.frame ~= nil then
    return
  end
  local frame = CreateFrame("Frame", "BetterBagsNextMenu", UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  self.fill = frame:CreateTexture(nil, "BACKGROUND")
  self.fill:SetAllPoints(frame)
  fills:Wrap(self.fill, frame)
  self.border = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  self.border:Hide()
  fills:Wrap(self.border, frame)
  self.edge = controls:CreateEdge(frame)
  local box = CreateFrame("Frame", nil, frame, "WowScrollBox") --[[@as WowScrollBox]]
  box:SetInterpolateScroll(true)
  pixel:SnapScroll(box)
  local list = CreateFrame("Frame", nil, box)
  list.scrollable = true
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(24)
  box:Init(view)
  self.bar = nextScrollBar:Create(box)
  self.bar:Bind(box)
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:EnableMouse(true)
  catcher:EnableMouseWheel(true)
  catcher:Hide()
  addon.SetScript(catcher, "OnMouseDown", function() self:Close() end)
  addon.SetScript(catcher, "OnMouseWheel", function() self:Close() end)
  addon.SetScript(frame, "OnHide", function() self:hidden() end)
  local headFrame = CreateFrame("Frame", nil, frame)
  self.headIcon = headFrame:CreateTexture(nil, "ARTWORK")
  self.headIcon:SetAllPoints(headFrame)
  self.headEdge = controls:CreateEdge(headFrame)
  self.headText = frame:CreateFontString(nil, "OVERLAY")
  self.headText:SetJustifyH("LEFT")
  self.headText:SetWordWrap(false)
  self.headNote = frame:CreateFontString(nil, "OVERLAY")
  self.headNote:SetJustifyH("LEFT")
  self.headNote:SetWordWrap(false)
  headFrame:Hide()
  self.headFrame = headFrame
  self.field = nextInput:Create(frame, {
    onChange = function(_, text) self:Filter(text) end,
    onEnter = function(ctx) self:Take(ctx) end,
    onArrow = function(_, key) self:Arrow(key) end,
    onEscape = function() self:Close() end,
    icon = function()
      local SR = style.Theme.Settings.Search
      return { Texture = SR.Icon, Atlas = SR.Atlas, Size = SR.IconSize, Color = SR.IconColor }
    end,
  })
  self.field.frame:Hide()
  self.frame, self.box, self.list, self.catcher = frame, box, list, catcher
  sonataNext:RegisterWidget(self)
  pixelAudit:Register(frame, { title = "Menu", owners = { menu = self } })
end

-- row returns the i-th row, made the first time it is needed.
---@private
---@param i number
---@return NextMenuRow
function nextMenu:row(i)
  local row = self.rows[i]
  if row ~= nil then
    return row
  end
  local frame = CreateFrame("Button", nil, self.list)
  frame:RegisterForClicks("LeftButtonUp")
  local hover = frame:CreateTexture(nil, "BACKGROUND")
  hover:SetAllPoints(frame)
  hover:Hide()
  local label = frame:CreateFontString(nil, "OVERLAY")
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  local check = frame:CreateTexture(nil, "ARTWORK", nil, 1)
  local ring = frame:CreateTexture(nil, "ARTWORK")
  ring:Hide()
  local dot = frame:CreateTexture(nil, "ARTWORK")
  dot:Hide()
  local note = frame:CreateFontString(nil, "OVERLAY")
  note:SetJustifyH("RIGHT")
  note:SetWordWrap(false)
  note:Hide()
  row = setmetatable({ frame = frame, hover = hover, label = label, check = check, ring = ring, dot = dot, note = note },
    { __index = rowProto })
  style:SetFont(label, controls:Theme("Menu").Font)
  addon.SetScript(frame, "OnClick", function(ctx) self:Pick(ctx, row) end)
  -- A choice that cannot be taken is never lit: in a menu with a field the light stays where it was.
  addon.SetScript(frame, "OnEnter", function()
    if row.item ~= nil and row.item.disabled then
      if not (self.opts and self.opts.filter) then
        self:Light(nil)
      end
      return
    end
    self:Light(i)
  end)
  -- In a menu with a field the light stays where the pointer left it: Enter takes what was last pointed at.
  addon.SetScript(frame, "OnLeave", function()
    if not (self.opts and self.opts.filter) then
      self:Light(nil)
    end
  end)
  self.rows[i] = row
  return row
end

---@param hovered boolean
function rowProto:SetHovered(hovered)
  self.hover:SetShown(hovered and self.item ~= nil and not self.item.disabled)
end

-- Rows returns the rows of the choices shown.
---@return NextMenuRow[]
function nextMenu:Rows()
  local list = {}
  for i = 1, #self.items do
    list[i] = self.rows[i]
  end
  return list
end

---@param anchor Frame
---@return boolean
function nextMenu:IsOpenFor(anchor)
  return self.open and self.anchor == anchor
end

-- Open shows the menu below anchor with opts' choices, in place of any menu open.
---@param anchor Frame
---@param opts NextMenuOptions
function nextMenu:Open(anchor, opts)
  self:build()
  if self.open then
    self:Close()
  end
  self.anchor, self.opts, self.lit = anchor, opts, nil
  if opts.filter then
    self.field:SetText("")
    self.field.help:SetText(opts.filter.help or "")
    self.items, self.lit = opts.filter.items("")
  else
    self.items = opts.items
  end
  if not self.hooked[anchor] then
    self.hooked[anchor] = true
    addon.HookScript(anchor, "OnHide", function()
      if self.anchor == anchor then
        self:Close()
      end
    end)
  end
  self:Style()
  self.open = true
  self.catcher:Show()
  self.frame:Show()
  controls:PushEscape(self.frame)
  if opts.filter then
    self.field:SetFocus()
  end
end

-- Toggle closes the menu when it is open for anchor, and opens it otherwise.
---@param anchor Frame
---@param opts NextMenuOptions
function nextMenu:Toggle(anchor, opts)
  if self:IsOpenFor(anchor) then
    self:Close()
  else
    self:Open(anchor, opts)
  end
end

function nextMenu:Close()
  if not self.open then
    return
  end
  self.frame:Hide()
  self:hidden()
end

-- hidden ends the menu however it hid (Close, Escape, its parent): once.
---@private
function nextMenu:hidden()
  if not self.open then
    return
  end
  self.open = false
  self.catcher:Hide()
  self.field.frame:ClearFocus()
  controls:ReleaseEscape(self.frame)
  local opts = self.opts
  self.anchor, self.opts, self.lit = nil, nil, nil
  if opts and opts.onClose then
    opts.onClose()
  end
end

-- Light lights the i-th row as under the pointer (none: no row), the one Enter takes in a menu with a field.
---@param i? number
function nextMenu:Light(i)
  self.lit = i
  for j = 1, #self.items do
    self.rows[j]:SetHovered(j == i)
  end
end

-- Filter reads a filter's choices again for what the player typed, the one Enter takes lit.
---@param text string
function nextMenu:Filter(text)
  local filter = self.opts and self.opts.filter
  if filter == nil then
    return
  end
  self.items, self.lit = filter.items(text)
  self:Style()
end

-- Arrow moves the light down or up a row past choices that cannot be taken, no further than the first or the last
-- (from none: the first, or the last), keeping it in sight. Left and Right are the field's.
---@param key string
function nextMenu:Arrow(key)
  local by = (key == "DOWN" and 1) or (key == "UP" and -1) or nil
  if by == nil or not self.open then
    return
  end
  local n = #self.items
  local i = self.lit or (by > 0 and 0 or n + 1)
  repeat
    i = i + by
  until i < 1 or i > n or not self.items[i].disabled
  if i < 1 or i > n then
    return
  end
  self:Light(i)
  self:showRow(i)
end

-- showRow scrolls the list so the i-th row is in sight, as little as it takes, gliding unless at once. A menu whose rows
-- all show never scrolls: on a screen where its rows are a fraction of a unit tall, the box rounds what it shows
-- (ScrollBoxBaseMixin:GetVisibleExtent) and has a range of less than a pixel.
---@private
---@param i number
---@param instant? boolean
function nextMenu:showRow(i, instant)
  local box = self.box
  if box:GetDerivedScrollRange() < pixel:Unit(box) then
    return
  end
  local height = pixel:Length(self.frame, self:look().ItemHeight)
  local top, bottom = (i - 1) * height, i * height
  local offset, visible = box:GetDerivedScrollOffset(), box:GetVisibleExtent()
  if top < offset then
    box:ScrollToOffset(top, instant)
  elseif bottom > offset + visible then
    box:ScrollToOffset(bottom - visible, instant)
  end
end

-- Take takes the lit choice (Enter in the field); with none lit it closes, taking nothing.
---@param ctx Context
function nextMenu:Take(ctx)
  local row = self.lit and self.rows[self.lit]
  if row ~= nil and row.item ~= nil and not row.item.disabled then
    self:Pick(ctx, row)
  else
    self:Close()
  end
end

-- Pick takes a row's choice, unless it is disabled, and closes.
---@param ctx Context
---@param row NextMenuRow
function nextMenu:Pick(ctx, row)
  local item = row.item
  if item == nil or item.disabled then
    return
  end
  local opts = self.opts
  self:Close()
  if opts then
    opts.onPick(ctx, item)
  end
end

-- ApplyStyle restyles the menu while it is open (SonataNext applied a theme).
---@param ctx? Context
function nextMenu:ApplyStyle(ctx)
  local _ = ctx
  if self.frame ~= nil and self.open then
    self:Style()
  end
end

-- look returns the menu's look: the theme's Menu, with what the open menu's style changes (NextMenuOptions.style: a
-- dropdown's own menu, Blizzard's MenuStyle2 for its settings dropdowns).
---@private
---@return table
function nextMenu:look()
  local M = controls:Theme("Menu")
  local own = self.opts and self.opts.style
  if not own then
    return M
  end
  local merged = {}
  for k, v in pairs(M) do merged[k] = v end
  for k, v in pairs(own) do merged[k] = v end
  return merged
end


-- Style lays the rows out and draws the menu: as wide as the widest choice (at least its anchor and
-- opts.width, and Picker.Width with a field), MaxRows tall at most, its head and its field above the rows.
-- All in whole pixels on its own grid (UIParent's: docs/next-pixel-perfect.md), its anchor's width in its
-- units (the anchor may be in a window drawn smaller): its rows one ItemHeight apart, a check, a dot, a label
-- and a note on each centered by its top.
function nextMenu:Style()
  local M = self:look()
  local P = M.Picker
  local opts = self.opts
  local frame, items = self.frame, self.items
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", self.anchor, "BOTTOMLEFT", 0, -M.Gap)
  frame:SetFrameLevel(self.catcher:GetFrameLevel() + 2)
  controls:Paint(self.fill, M.Fill)
  controls:Paint(self.border, M.Border)
  controls:PaintEdge(self.edge, M.Edge)
  local check = M.Check
  -- The check's size, or its atlas's (Size = "Atlas"), and the ring's the same way; the text after the wider.
  local checkWidth, checkHeight = style:SizeOf(check, nil, 12)
  local ringWidth, ringHeight = 0, 0
  if check.Off or check.Under then
    ringWidth, ringHeight = style:SizeOf(check, check.Off or check.Under, checkWidth)
  end
  local pad, itemHeight = pixel:Lengths(frame, M.Padding, M.ItemHeight)
  -- A dot before each name when any choice has a color, the names after the dots.
  local dotted = false
  for _, item in ipairs(items) do
    if item.color ~= nil then
      dotted = true
      break
    end
  end
  local dotLeft = pad + pixel:Length(frame, math.max(checkWidth, ringWidth)) + pad
  local textLeft = dotLeft
  if dotted then
    textLeft = dotLeft + pixel:Length(frame, P.Dot) + pad
  end
  local shown = math.min(#items, M.MaxRows)
  local scrolls = #items > M.MaxRows
  local S = controls:Theme("ScrollBar")
  -- The scroll bar sits over the rows' right edge (NextScrollBar, a child of the box): what is at a row's right stays
  -- clear of it.
  local bar = scrolls and (pixel:Length(frame, S.Width) + pixel:Length(frame, S.Inset)) or 0
  local widest = 0
  for i, item in ipairs(items) do
    local row = self:row(i)
    row.item = item
    local font = M.Font
    if item.disabled then
      font = "ControlMuted"
    elseif item.selected then
      font = M.SelectedFont
    end
    style:SetFont(row.label, font)
    row.label:SetText(item.text)
    -- Its note at its right, the name stopping short of it.
    local noteRoom = 0
    if item.note ~= nil then
      style:SetFont(row.note, P.NoteFont)
      row.note:SetText(item.note)
      row.note:ClearAllPoints()
      pixel:Row(row.note, "TOPRIGHT", row.frame, pad + bar, itemHeight)
      row.note:Show()
      noteRoom = pad + pixel:Ceil(frame, row.note:GetStringWidth())
    else
      row.note:Hide()
    end
    widest = math.max(widest, pixel:Ceil(frame, row.label:GetStringWidth()) + noteRoom)
    controls:Paint(row.hover, M.HoverFill)
    row.hover:Hide()
    -- A glyph, or an atlas (Blizzard's radio tick); the empty ring under it (Off on rows not chosen, Under on the
    -- chosen one), the tick at the ring's top left as Blizzard's retail radios draw it.
    local chosen = item.selected == true
    local glyph = item.glyph
    local ring = (glyph == nil) and (chosen and check.Under or (not chosen and check.Off)) or nil
    if ring then
      controls:Paint(row.ring, { Texture = ring.Texture, Atlas = ring.Atlas, Color = ring.Color or check.Color })
      pixel:Size(row.ring, ringWidth, ringHeight)
      row.ring:ClearAllPoints()
      pixel:Row(row.ring, "TOPLEFT", row.frame, pad, itemHeight)
    else
      row.ring:Hide()
    end
    local mark = glyph or check
    controls:Paint(row.check, { Texture = mark.Texture, Atlas = mark.Atlas, Color = mark.Color or check.Color })
    pixel:Size(row.check, checkWidth, checkHeight)
    row.check:ClearAllPoints()
    if ring then
      row.check:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 0, 0)
    else
      pixel:Row(row.check, "TOPLEFT", row.frame, pad, itemHeight)
    end
    row.check:SetShown(chosen or glyph ~= nil)
    local color = item.color
    if color ~= nil then
      row.dot:SetColorTexture(color[1], color[2], color[3], 1)
      pixel:Size(row.dot, P.Dot, P.Dot)
      row.dot:ClearAllPoints()
      pixel:Row(row.dot, "TOPLEFT", row.frame, dotLeft, itemHeight)
      row.dot:SetAlpha(item.disabled and controls:Theme("Button").DisabledAlpha or 1)
      row.dot:Show()
    else
      row.dot:Hide()
    end
    row.label:ClearAllPoints()
    pixel:Row(row.label, "TOPLEFT", row.frame, textLeft, itemHeight)
    pixel:Row(row.label, "TOPRIGHT", row.frame, pad + bar + noteRoom, itemHeight)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -(i - 1) * itemHeight)
    row.frame:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -(i - 1) * itemHeight)
    row.frame:SetHeight(itemHeight)
    row.frame:Show()
  end
  for i = #items + 1, #self.rows do
    self.rows[i].item = nil
    self.rows[i].frame:Hide()
  end
  -- The rows sit in a list inset Padding on both sides: the menu holds that, the text's left, the
  -- widest text and the room right of it.
  -- The list's inset: Inset on each side when the theme gives one (Blizzard's menus: MenuStyle1Mixin:GetInset), else
  -- Padding all round.
  local inset = M.Inset or {}
  local left, right = pixel:Snap(frame, inset.Left or M.Padding), pixel:Snap(frame, inset.Right or M.Padding)
  local top, bottom = pixel:Snap(frame, inset.Top or M.Padding), pixel:Snap(frame, inset.Bottom or M.Padding)
  local width = left + right + textLeft + widest + pad + bar
  local anchorWidth = self.anchor:GetWidth() * self.anchor:GetEffectiveScale() / frame:GetEffectiveScale()
  width = math.max(width, pixel:Ceil(frame, anchorWidth), pixel:Ceil(frame, opts.width or 0))
  -- Above the rows, its head (an icon IconSize square, its text and note beside it) and its field, each Gap above
  -- what follows.
  local gap = pixel:Length(frame, P.Gap)
  local head, filter = opts.head, opts.filter
  local iconSize = pixel:Length(frame, P.IconSize)
  local above = 0
  if head ~= nil then
    style:SetFont(self.headText, P.HeadFont)
    style:SetFont(self.headNote, P.NoteFont)
    self.headText:SetText(head.text or "")
    self.headNote:SetText(head.note or "")
    local textWidth = math.max(self.headText:GetStringWidth(), head.note and self.headNote:GetStringWidth() or 0)
    width = math.max(width, left + iconSize + gap + pixel:Ceil(frame, textWidth) + right)
    above = iconSize + gap
  end
  if filter ~= nil then
    width = math.max(width, pixel:Ceil(frame, pixel:Length(frame, P.Width)))
    above = above + pixel:Length(frame, controls:Theme("Input").Height) + gap
  end
  frame:SetSize(width, above + shown * itemHeight + top + bottom)
  self:styleHead(head, left, right, top, iconSize, gap)
  if filter ~= nil then
    local field = self.field.frame
    local fieldTop = top + (head ~= nil and iconSize + gap or 0)
    field:ClearAllPoints()
    field:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -fieldTop)
    field:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -fieldTop)
    field:SetWidth(width - left - right)
    self.field:Style()
    field:Show()
  else
    self.field.frame:Hide()
  end
  pixel:Inset(self.box, frame, left, right, top + above, bottom)
  self.box:SetSize(width - left - right, shown * itemHeight)
  self.list:SetHeight(#items * itemHeight)
  self.box:FullUpdate(true)
  self.box:SetScrollPercentage(0, true)
  local lit = self.lit
  if lit ~= nil and (items[lit] == nil or items[lit].disabled) then
    lit = nil
  end
  self:Light(lit)
  -- What Enter takes stays in sight however it was lit (read for what is typed, or restyled while open), at once: the
  -- list was just put back at its top.
  if lit ~= nil then
    self:showRow(lit, true)
  end
end

-- styleHead draws the head (an icon in its edge: the item's quality, as an item grid's cell draws it; its text, and a
-- note under it, centered beside the icon by their top), or puts it away for a menu without one.
---@private
---@param head? NextMenuHead
---@param left number
---@param right number
---@param top number
---@param iconSize number
---@param gap number
function nextMenu:styleHead(head, left, right, top, iconSize, gap)
  local frame = self.frame
  if head == nil then
    self.headFrame:Hide()
    self.headText:Hide()
    self.headNote:Hide()
    return
  end
  local headFrame = self.headFrame
  headFrame:ClearAllPoints()
  headFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
  headFrame:SetSize(iconSize, iconSize)
  self.headIcon:SetTexture(head.icon)
  local K = controls:Theme("ItemGrid")
  if head.edge ~= nil then
    controls:PaintEdge(self.headEdge, { Color = { head.edge[1], head.edge[2], head.edge[3] }, Size = K.CommonEdge.Size }, 1)
  else
    controls:PaintEdge(self.headEdge, K.CommonEdge)
  end
  headFrame:Show()
  local textHeight = pixel:Ceil(frame, pixel:TextHeight(self.headText))
  local noteHeight, between = 0, 0
  if head.note ~= nil then
    noteHeight, between = pixel:Ceil(frame, pixel:TextHeight(self.headNote)), pixel:Snap(frame, 2)
  end
  local textTop = top + pixel:Middle(frame, iconSize, textHeight + between + noteHeight)
  local textLeft = left + iconSize + gap
  self.headText:ClearAllPoints()
  pixel:Point(self.headText, "TOPLEFT", frame, "TOPLEFT", textLeft, -textTop)
  pixel:Point(self.headText, "TOPRIGHT", frame, "TOPRIGHT", -right, -textTop)
  self.headText:Show()
  if head.note ~= nil then
    local noteTop = textTop + textHeight + between
    self.headNote:ClearAllPoints()
    pixel:Point(self.headNote, "TOPLEFT", frame, "TOPLEFT", textLeft, -noteTop)
    pixel:Point(self.headNote, "TOPRIGHT", frame, "TOPRIGHT", -right, -noteTop)
    self.headNote:Show()
  else
    self.headNote:Hide()
  end
end
