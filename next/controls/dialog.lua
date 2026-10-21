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

-- NextDialog is BetterBags Next's dialog (next-settings.md §2), in place of Blizzard's StaticPopup:
-- one at a time, over the window it is shown in, drawn from the theme (Controls.Dialog): a scrim over
-- the window that takes its clicks, and a card with a title, text, a text field when asked, and
-- buttons laid out from the right in the order given. A click on a button calls it with the field's
-- text and closes the dialog, unless it returns true (keep it open: a name already taken). Enter in
-- the field is the last button (the one that answers yes); Escape, or the window hiding, the first
-- (the one that answers no).
---@class NextDialog: AceModule
---@field frame Frame
---@field scrim Texture
---@field card Frame
---@field cardFill Texture
---@field edge NextEdge
---@field title FontString
---@field text FontString
---@field input NextInputFrame
---@field buttons NextButtonFrame[] Every button made; the first #opts.buttons are shown.
---@field opts? NextDialogOptions
---@field open boolean
---@field answered boolean
local nextDialog = addon:NewModule('NextDialog')

---@class (exact) NextDialogButton
---@field text string
---@field style? NextButtonStyle
---@field onClick fun(ctx: Context, text: string): boolean?

---@class (exact) NextDialogInput
---@field text? string
---@field help? string
---@field maxLetters? number

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
  card:SetPoint("CENTER", frame, "CENTER", 0, 0)
  card:EnableMouse(true)
  self.cardFill = card:CreateTexture(nil, "BACKGROUND")
  self.cardFill:SetAllPoints(card)
  self.edge = controls:CreateEdge(card)
  local D = controls:Theme("Dialog")
  self.title = style:CreateText(card, D.TitleFont)
  self.title:SetJustifyH("LEFT")
  self.text = style:CreateText(card, D.TextFont)
  self.text:SetJustifyH("LEFT")
  self.text:SetWordWrap(true)
  self.input = nextInput:Create(card, {
    onEnter = function(ctx) self:Press(ctx, #self.opts.buttons) end,
  })
  addon.SetScript(frame, "OnHide", function(ctx) self:hidden(ctx) end)
  self.frame, self.card = frame, card
  sonataNext:RegisterWidget(self)
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

---@param owner Frame The window the dialog covers.
---@param opts NextDialogOptions
function nextDialog:Show(owner, opts)
  self:build()
  -- Showing again replaces the dialog shown, answering nothing.
  self.answered = true
  self.opts = opts
  local frame = self.frame
  frame:SetParent(owner)
  frame:ClearAllPoints()
  frame:SetAllPoints(owner)
  frame:SetFrameStrata(owner:GetFrameStrata())
  frame:SetFrameLevel(owner:GetFrameLevel() + 100)
  self.title:SetText(opts.title or "")
  self.text:SetText(opts.text or "")
  local input = opts.input
  self.input.frame:SetShown(input ~= nil)
  if input ~= nil then
    self.input.frame:SetMaxLetters(input.maxLetters or 0)
    self.input.help:SetText(input.help or "")
    self.input:SetText(input.text or "")
  end
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

-- Style lays the card out: the title, the text wrapped to the card, the field, the buttons from the
-- right; the card as tall as they are.
function nextDialog:Style()
  local D = controls:Theme("Dialog")
  local card, pad, gap = self.card, D.Pad, D.Gap
  controls:Paint(self.scrim, D.Scrim)
  controls:Paint(self.cardFill, D.Card)
  controls:PaintEdge(self.edge, D.Edge)
  style:SetFont(self.title, D.TitleFont)
  style:SetFont(self.text, D.TextFont)
  card:SetWidth(D.Width)
  local inner = D.Width - 2 * pad
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
  self.title:SetWidth(inner)
  self.text:ClearAllPoints()
  self.text:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -gap)
  self.text:SetWidth(inner)
  local height = pad + self.title:GetStringHeight() + gap + self.text:GetStringHeight()
  if self.input.frame:IsShown() then
    self.input.frame:ClearAllPoints()
    self.input.frame:SetPoint("TOPLEFT", self.text, "BOTTOMLEFT", 0, -gap)
    self.input.frame:SetWidth(inner)
    height = height + gap + self.input.frame:GetHeight()
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
      b.frame:SetPoint("RIGHT", right.frame, "LEFT", -D.ButtonGap, 0)
    end
    right = b
  end
  height = height + gap + controls:Theme("Button").Height + pad
  card:SetHeight(height)
end

-- Press answers with the i-th button: called with the field's text, then closed unless it asks to
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
  local keep = spec.onClick(ctx, self.input:GetText())
  if keep == true and self.opts == opts then
    self.answered = false
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
