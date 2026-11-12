local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextFill: AceModule
local fills = addon:GetModule('NextFill')

---@class NextFrameArt: AceModule
local frameArt = addon:GetModule('NextFrameArt')

---@class PixelAudit: AceModule
local pixelAudit = addon:GetModule('PixelAudit')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

-- NextDialog is BetterBags Next's dialog (next-settings.md §2), in place of Blizzard's StaticPopup:
-- one at a time, over everything in the window it is shown in (never wider than it), drawn from the theme
-- (Controls.Dialog): a scrim over the window that takes its clicks, and a card with a title, text, a text
-- field when asked, and buttons laid out from the right in the order given. A click on a button calls it
-- with the field's text and closes the dialog, unless it returns true (keep it open, the field focused
-- again: a name already taken). Enter in the field is the last button (the one that answers yes); Escape,
-- in the field or out of it, or the window hiding, the first (the one that answers no). A field may hold a
-- quantity: digits only, with -, + and a button filling in its max after it on its row, as Blizzard's stack
-- split has its arrows (StackSplitFrame.lua).
---@class NextDialog: AceModule
---@field frame Frame
---@field scrim Texture
---@field card Frame
---@field owner? Frame The window it covers.
---@field cardFill Texture
---@field cardBorder Texture Over the card's fill (Border: today's popup's diamond border).
---@field frameArt NextFrameArtSet The theme's frame round the card (Frame, next-themes.md §15).
---@field edge NextEdge
---@field title FontString
---@field text FontString
---@field input NextInputFrame
---@field minus NextButtonFrame A quantity's -.
---@field plus NextButtonFrame A quantity's +.
---@field most NextButtonFrame Fills in a quantity's max.
---@field buttons NextButtonFrame[] Every button made; the first #opts.buttons are shown.
---@field opts? NextDialogOptions
---@field open boolean
---@field answered boolean
local nextDialog = addon:NewModule('NextDialog')

---@class (exact) NextDialogButton
---@field text string
---@field style? NextButtonStyle
---@field onClick fun(ctx: Context, text: string): boolean?

---@class (exact) NextDialogQuantity
---@field min number The least it holds.
---@field max fun(): number The most it holds, asked each time it is needed: it may change while the dialog shows.
---@field step number How far - and + move it: to the multiple of step below or above.
---@field maxText string The label of the button that fills in its max.

---@class (exact) NextDialogInput
---@field text? string
---@field help? string
---@field maxLetters? number
---@field quantity? NextDialogQuantity The field holds a number, kept between its min and its max.

---@class (exact) NextDialogOptions
---@field title string
---@field text string
---@field input? NextDialogInput
---@field buttons NextDialogButton[]

nextDialog.buttons = {}
nextDialog.open = false
nextDialog.answered = false

-- build makes the dialog's frames, the first time it shows.
---@private
function nextDialog:build()
  if self.frame ~= nil then
    return
  end
  local frame = CreateFrame("Frame", "BetterBagsNextDialog", UIParent)
  frame:EnableMouse(true)
  frame:EnableMouseWheel(true)
  frame:Hide()
  self.scrim = frame:CreateTexture(nil, "BACKGROUND")
  self.scrim:SetAllPoints(frame)
  local card = CreateFrame("Frame", nil, frame)
  card:EnableMouse(true)
  self.cardFill = card:CreateTexture(nil, "BACKGROUND")
  self.cardFill:SetAllPoints(card)
  fills:Wrap(self.cardFill, card)
  self.cardBorder = card:CreateTexture(nil, "BACKGROUND", nil, 1)
  self.cardBorder:SetAllPoints(card)
  self.cardBorder:Hide()
  fills:Wrap(self.cardBorder, card)
  self.frameArt = frameArt:Create(card, card)
  self.edge = controls:CreateEdge(card)
  local D = controls:Theme("Dialog")
  self.title = style:CreateText(card, D.TitleFont)
  self.title:SetJustifyH("LEFT")
  self.text = style:CreateText(card, D.TextFont)
  self.text:SetJustifyH("LEFT")
  self.text:SetWordWrap(true)
  self.input = nextInput:Create(card, {
    onEnter = function(ctx) self:Press(ctx, #self.opts.buttons) end,
    onChange = function() self:typed() end,
    onArrow = function(_, key) self:arrow(key) end,
    onEscape = function() self:Hide() end,
  })
  self.minus = nextButton:Create(card, { text = "-", onClick = function() self:Step(-1) end })
  self.plus = nextButton:Create(card, { text = "+", onClick = function() self:Step(1) end })
  self.most = nextButton:Create(card, { text = "", onClick = function() self:fill(self:quantity().max()) end })
  for _, b in ipairs({ self.minus, self.plus, self.most }) do
    b.frame:Hide()
  end
  addon.SetScript(frame, "OnHide", function(ctx) self:hidden(ctx) end)
  self.frame, self.card = frame, card
  sonataNext:RegisterWidget(self)
  pixelAudit:Register(frame, { title = "Dialog", owners = { dialog = self } })
end

-- button returns the i-th button, made the first time it is needed.
---@private
---@param i number
---@return NextButtonFrame
function nextDialog:button(i)
  local b = self.buttons[i]
  if b == nil then
    b = nextButton:Create(self.card, { text = "", onClick = function(ctx) self:Press(ctx, i) end })
    self.buttons[i] = b
  end
  return b
end

-- levelOver is the frame level that puts the dialog over everything in its window (a docked card's catcher sits
-- a hundred above its section, NextDock), as far above the highest as a lifted frame's cover (NextLift).
---@private
---@param owner Frame
---@return number
function nextDialog:levelOver(owner)
  local level = owner:GetFrameLevel()
  for _, child in ipairs({ owner:GetChildren() }) do
    if child ~= self.frame then
      level = math.max(level, lift:MaxLevel(child))
    end
  end
  return math.min(lift.MAX_LEVEL, level + lift.COVER_ABOVE)
end

---@param owner Frame The window the dialog covers.
---@param opts NextDialogOptions
function nextDialog:Show(owner, opts)
  self:build()
  -- Showing again replaces the dialog shown, answering nothing.
  self.answered = true
  self.opts = opts
  local frame = self.frame
  self.owner = owner
  frame:SetParent(owner)
  frame:ClearAllPoints()
  frame:SetAllPoints(owner)
  frame:SetFrameStrata(owner:GetFrameStrata())
  frame:SetFrameLevel(self:levelOver(owner))
  self.title:SetText(opts.title or "")
  self.text:SetText(opts.text or "")
  local input = opts.input
  local quantity = input and input.quantity
  self.input.frame:SetShown(input ~= nil)
  self.input.frame:SetNumeric(quantity ~= nil)
  for _, b in ipairs({ self.minus, self.plus, self.most }) do
    b.frame:SetShown(quantity ~= nil)
  end
  if quantity ~= nil then
    self.most:SetText(quantity.maxText)
  end
  if input ~= nil then
    self.input.frame:SetMaxLetters(input.maxLetters or 0)
    self.input.help:SetText(input.help or "")
    self.input:SetText(input.text or "")
  end
  self:updateSteppers()
  for i, spec in ipairs(opts.buttons) do
    local b = self:button(i)
    b.style = spec.style or "Plain"
    b:SetText(spec.text)
    b.frame:Show()
  end
  for i = #opts.buttons + 1, #self.buttons do
    self.buttons[i].frame:Hide()
  end
  self:Style()
  self.answered = false
  self.open = true
  frame:Show()
  controls:PushEscape(frame)
  if input ~= nil then
    self.input:SetFocus()
    self.input.frame:HighlightText()
  end
end

-- ApplyStyle restyles the dialog while it shows (SonataNext applied a theme).
---@param ctx? Context
function nextDialog:ApplyStyle(ctx)
  local _ = ctx
  if self.frame ~= nil and self.open then
    self:Style()
  end
end

-- Style lays the card out: the title, the text wrapped to the card, the field (a quantity's -, + and max
-- button after it, - and + square, the field the room they leave), the buttons from the right; the card as
-- tall as they are, in the middle of the window. All in whole pixels (docs/next-pixel-perfect.md): each part
-- down from the card's top by the heights above it rounded up, never from a text's far edge (the client's
-- measure of it), the field's row centered on its tallest part, the buttons corner to corner.
function nextDialog:Style()
  local D = controls:Theme("Dialog")
  local frame, card = self.frame, self.card
  local pad, gap, buttonGap = pixel:Snap(card, D.Pad), pixel:Snap(card, D.Gap), pixel:Snap(card, D.ButtonGap)
  controls:Paint(self.scrim, D.Scrim)
  controls:Paint(self.cardFill, D.Card)
  controls:Paint(self.cardBorder, D.Border)
  style:SetFont(self.title, D.TitleFont)
  style:SetFont(self.text, D.TextFont)
  local width = math.min(pixel:Length(card, D.Width), pixel:Floor(card, self.owner:GetWidth()))
  card:SetWidth(width)
  local inner = width - 2 * pad
  self.title:SetWidth(inner)
  self.text:SetWidth(inner)
  self.title:ClearAllPoints()
  pixel:Point(self.title, "TOPLEFT", card, "TOPLEFT", pad, -pad)
  local down = pad + pixel:Ceil(card, self.title:GetStringHeight()) + gap
  self.text:ClearAllPoints()
  pixel:Point(self.text, "TOPLEFT", card, "TOPLEFT", pad, -down)
  down = down + pixel:Ceil(card, self.text:GetStringHeight())
  if self.input.frame:IsShown() then
    local top = down + gap
    local steppers = self.most.frame:IsShown()
    local fieldWidth = inner
    if steppers then
      local square = pixel:Length(card, controls:Theme("Button").Height)
      self.minus:SetWidth(square)
      self.plus:SetWidth(square)
      for _, b in ipairs({ self.minus, self.plus, self.most }) do
        b:Style()
      end
      fieldWidth = inner - (self.most.frame:GetWidth() + 2 * square + 3 * buttonGap)
    end
    self.input.frame:SetWidth(fieldWidth)
    self.input:Style()
    local row = self.input.frame:GetHeight()
    if steppers then
      row = math.max(row, self.most.frame:GetHeight())
    end
    self.input.frame:ClearAllPoints()
    pixel:Row(self.input.frame, "TOPLEFT", card, pad, row, nil, top)
    if steppers then
      local across = pad
      for _, b in ipairs({ self.most, self.plus, self.minus }) do
        b.frame:ClearAllPoints()
        pixel:Row(b.frame, "TOPRIGHT", card, across, row, nil, top)
        across = across + b.frame:GetWidth() + buttonGap
      end
    end
    down = top + row
  end
  local count = self.opts and #self.opts.buttons or 0
  local right
  for i = count, 1, -1 do
    local b = self.buttons[i]
    b:Style()
    b.frame:ClearAllPoints()
    if right == nil then
      b.frame:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -pad, pad)
    else
      b.frame:SetPoint("TOPRIGHT", right.frame, "TOPLEFT", -buttonGap, 0)
    end
    right = b
  end
  local height = down + gap + pixel:Length(card, controls:Theme("Button").Height) + pad
  -- It covers its window, at its scale: centered by the window's size.
  card:ClearAllPoints()
  pixel:Center(card, frame, self.owner:GetWidth(), self.owner:GetHeight(), width, height)
  controls:PaintEdge(self.edge, D.Edge)
  self.frameArt:Apply(D.Frame)
end

-- quantity is what the shown dialog's field holds a quantity of, if it holds one.
---@private
---@return NextDialogQuantity?
function nextDialog:quantity()
  local input = self.opts and self.opts.input
  return input and input.quantity
end

-- within keeps a number between a quantity's min and its max as it is now.
---@param q NextDialogQuantity
---@param n number
---@return number
local function within(q, n)
  return math.min(q.max(), math.max(q.min, n))
end

-- updateSteppers turns - off while the field holds no number above the quantity's min. + and the max button
-- are never off: each asks the max when clicked, which may have grown since.
---@private
function nextDialog:updateSteppers()
  local q = self:quantity()
  if q == nil then
    return
  end
  local n = tonumber(self.input:GetText())
  self.minus:SetEnabled(n ~= nil and n > q.min)
end

-- fill shows a number in a quantity's field.
---@private
---@param n number
function nextDialog:fill(n)
  self.input:SetText(tostring(n))
  self:updateSteppers()
end

-- Step moves a quantity to the multiple of its step below (direction -1) or above (1), kept between its min
-- and its max; from an empty field, as from 0.
---@param direction number
function nextDialog:Step(direction)
  local q = self:quantity()
  if q == nil then
    return
  end
  local n = tonumber(self.input:GetText()) or 0
  local target
  if direction < 0 then
    target = (math.ceil(n / q.step) - 1) * q.step
  else
    target = (math.floor(n / q.step) + 1) * q.step
  end
  self:fill(within(q, target))
end

-- typed shows a quantity's max in place of a larger number the player typed; a smaller one is left to be
-- typed on (a 1 may become a 10), and kept within when answered (answer).
---@private
function nextDialog:typed()
  local q = self:quantity()
  if q == nil then
    return
  end
  local n, most = tonumber(self.input:GetText()), q.max()
  if n ~= nil and n > most then
    self:fill(most)
  else
    self:updateSteppers()
  end
end

-- arrow steps a quantity with the Up and Down keys, as Blizzard's stack split does (StackSplitMixin:OnKeyDown);
-- Left and Right stay the field's.
---@private
---@param key string
function nextDialog:arrow(key)
  if key == "UP" then
    self:Step(1)
  elseif key == "DOWN" then
    self:Step(-1)
  end
end

-- answer is the field's text as a button gets it: a quantity's number kept between its min and its max.
---@private
---@return string
function nextDialog:answer()
  local text = self.input:GetText()
  local q = self:quantity()
  local n = q and tonumber(text)
  if n ~= nil then
    return tostring(within(q, n))
  end
  return text
end

-- Press answers with the i-th button: called with the field's text (answer), then closed unless it asks to
-- stay open.
---@param ctx Context
---@param i number
function nextDialog:Press(ctx, i)
  local opts = self.opts
  local spec = opts and opts.buttons[i]
  if spec == nil then
    return
  end
  self.answered = true
  local keep = spec.onClick(ctx, self:answer())
  if keep == true and self.opts == opts then
    self.answered = false
    if self.input.frame:IsShown() then
      self.input:SetFocus()
      self.input.frame:HighlightText()
    end
    return
  end
  if self.opts == opts then
    self:Hide()
  end
end

-- Hide closes the dialog; one closed without an answer answers with its first button.
function nextDialog:Hide()
  if not self.open then
    return
  end
  self.frame:Hide()
  self:hidden(context:New('NextDialog_Hide'))
end

-- hidden ends the dialog however it hid (Hide, Escape, its window): once.
---@private
---@param ctx Context
function nextDialog:hidden(ctx)
  if not self.open then
    return
  end
  self.open = false
  -- A window hiding hides its children without hiding them for good: one left shown would come back,
  -- unanswerable, with the window, and keep Escape from the game meanwhile (CloseSpecialWindows reads IsShown).
  self.frame:Hide()
  controls:ReleaseEscape(self.frame)
  local opts, answered = self.opts, self.answered
  self.opts = nil
  if not answered and opts and opts.buttons[1] then
    opts.buttons[1].onClick(ctx, self.input:GetText())
  end
end

---@return boolean
function nextDialog:IsShown()
  return self.open
end
