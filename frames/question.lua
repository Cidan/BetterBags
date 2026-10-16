local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class WindowModule: AceModule
local window = addon:GetModule('Window')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class (exact) Question: AceModule
---@field private _pool ObjectPool
---@field private open boolean
local question = addon:NewModule('Question')

-- The question's text is this wide; the dialog's content box is this wide.
local TEXT_WIDTH = 250
local BODY_WIDTH = 290
-- Room in the content box around the text and the buttons: 15 above the text, 50 for the
-- input row, 15 below the buttons.
local BODY_PADDING = 80

-- A question is a Dialog window (window/window.lua) whose content is its body: the text, the
-- input box and the buttons, sized to the text through the render pipeline.
---@class (exact) QuestionFrame
---@field window BetterBagsWindow
---@field body QuestionBody
---@field text FontString
---@field yes Button|UIPanelButtonTemplate
---@field no Button|UIPanelButtonTemplate
---@field ok Button|UIPanelButtonTemplate
---@field input EditBox|InputBoxTemplate
local questionProto = {}
addon:GetModule('Perf'):RegisterPrototype(questionProto, 'QuestionFrame')

---@class (exact) QuestionBody: Drawable
---@field question QuestionFrame
local bodyProto = drawable:Extend({}, 'QuestionBody')

---@return RenderPlan
function bodyProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

---@return RenderResult
function bodyProto:Render()
  local q = self.question
  q.text:SetWidth(TEXT_WIDTH)
  local textHeight = q.text:GetStringHeight()
  q.text:SetHeight(textHeight)
  return { Width = BODY_WIDTH, Height = textHeight + q.yes:GetHeight() + BODY_PADDING }
end

function question:OnEnable()
  self._pool = CreateObjectPool(self._OnCreate, self._OnReset)
  self.open = false
end

function question:_OnCreate()
  local q = setmetatable({}, {__index = questionProto})
  q.window = window:Create({
    Kind = "Dialog",
    Strata = "DIALOG",
    Level = 600, -- Higher than the settings window (500) to appear on top.
    Movable = false,
    Fade = function() return false end,
  })

  local frame = CreateFrame('Frame')
  q.body = drawable:Create(bodyProto, { frame = frame, question = q })

  q.input = CreateFrame('EditBox', nil, frame, "InputBoxTemplate")
  q.input:SetWidth(200)
  q.input:SetHeight(20)
  q.input:SetPoint('BOTTOM', 0, 35)

  q.text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  q.text:SetTextColor(1, 1, 1)
  q.text:SetPoint('TOP', 0, -15)
  q.text:SetWordWrap(true)
  q.text:SetJustifyH("CENTER")

  q.yes = CreateFrame('Button', nil, frame, "UIPanelButtonTemplate")
  q.no = CreateFrame('Button', nil, frame, "UIPanelButtonTemplate")
  q.ok = CreateFrame('Button', nil, frame, "UIPanelButtonTemplate")
  q.yes:SetWidth(100)
  q.no:SetWidth(100)
  q.ok:SetWidth(100)
  q.yes:SetPoint("BOTTOMLEFT", 5, 5)
  q.no:SetPoint("BOTTOMRIGHT", -5, 5)
  q.ok:SetPoint("BOTTOM", 0, 5)

  for _, button in ipairs({ q.yes, q.no, q.ok }) do
    sonata:RegisterElement("Button", button)
  end
  sonata:RegisterElement("EditBox", q.input)
  q.window:SetContent(q.body)
  return q
end

---@param q QuestionFrame
function question:_OnReset(q)
  q.window:SetTitle("")
  q.text:SetText("")
  q.yes:SetScript("OnClick", nil)
  q.no:SetScript("OnClick", nil)
  q.ok:SetScript("OnClick", nil)
  q.yes:Show()
  q.no:Show()
  q.ok:Hide()
  q.input:ClearFocus()
  q.input:SetText("")
  q.input:SetScript("OnEscapePressed", nil)
  q.input:SetScript("OnEnterPressed", nil)
  q.window:Hide(context:New('Question_Reset'))
end

-- Open shows the dialog sized to its text.
function questionProto:Open()
  self.body:Invalidate()
  self.window:Show(context:New('Question_Open'))
end

---@param q QuestionFrame
function question:Close(q)
  self._pool:Release(q)
  self.open = false
end

---@param title string
---@param text string
---@param yes function
---@param no function
function question:YesNo(title, text, yes, no)
  if self.open then return end
  local q = self._pool:Acquire() --[[@as QuestionFrame]]
  q.window:SetTitle(title)
  q.text:SetText(text)
  q.yes:SetText("Yes")
  q.no:SetText("No")
  q.yes:SetScript("OnClick", function()
    xpcall(yes, geterrorhandler())
    self:Close(q)
  end)
  q.no:SetScript("OnClick", function()
    xpcall(no, geterrorhandler())
    self:Close(q)
  end)
  q.input:Hide()
  self.open = true
  q:Open()
end

function question:Alert(title, text)
  if self.open then return end
  local q = self._pool:Acquire() --[[@as QuestionFrame]]
  q.window:SetTitle(title)
  q.text:SetText(text)
  q.no:Hide()
  q.yes:Hide()
  q.ok:SetText("Okay")
  q.ok:SetScript("OnClick", function()
    self:Close(q)
  end)
  q.ok:Show()
  q.input:Hide()
  self.open = true
  q:Open()
end

function question:AskForInput(title, text, onInput)
  if self.open then return end
  local q = self._pool:Acquire() --[[@as QuestionFrame]]
  q.window:SetTitle(title)
  q.text:SetText(text)
  q.yes:SetText("Okay")
  q.no:SetText("Cancel")
  q.yes:SetScript("OnClick", function()
    if q.input:GetText() ~= "" then
      xpcall(onInput, geterrorhandler(), q.input:GetText())
    end
    self:Close(q)
  end)
  q.no:SetScript("OnClick", function()
    self:Close(q)
  end)
  q.input:Show()
  q.input:SetScript("OnEscapePressed", function()
    q.input:ClearFocus()
    self:Close(q)
  end)
  q.input:SetScript("OnEnterPressed", function()
    xpcall(onInput, geterrorhandler(), q.input:GetText())
    self:Close(q)
  end)
  self.open = true
  q:Open()
end
