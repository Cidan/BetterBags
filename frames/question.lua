

---@type BetterBags
local addon = GetBetterBags()

---@class (exact) Question: AceModule
---@field private _pool ObjectPool
---@field private open boolean
local question = addon:NewModule('Question')

---@class (exact) QuestionFrame
---@field frame Frame|DefaultPanelFlatTemplate
---@field text FontString
---@field yes Button|UIPanelButtonTemplate
---@field no Button|UIPanelButtonTemplate
---@field ok Button|UIPanelButtonTemplate
---@field input EditBox|InputBoxTemplate
local questionProto = {}

function question:OnEnable()
  self._pool = CreateObjectPool(self._OnCreate, self._OnReset)
  self.open = false
end

function question:_OnCreate()
  local q = setmetatable({}, {__index = questionProto})
  q.frame = CreateFrame('Frame', nil, UIParent, "DefaultPanelFlatTemplate")
  q.frame:SetFrameStrata("DIALOG")

  q.input = CreateFrame('EditBox', nil, q.frame, "InputBoxTemplate")
  q.input:SetWidth(200)
  q.input:SetHeight(20)
  q.input:SetPoint('BOTTOM', 0, 40)

  q.text = q.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  q.text:SetTextColor(1, 1, 1)
  q.text:SetPoint('TOP', 0, -40)
  q.text:SetHeight(1000)
  q.text:SetWordWrap(true)
  q.text:SetJustifyH("CENTER")

  q.yes = CreateFrame('Button', nil, q.frame, "UIPanelButtonTemplate")
  q.no = CreateFrame('Button', nil, q.frame, "UIPanelButtonTemplate")
  q.ok = CreateFrame('Button', nil, q.frame, "UIPanelButtonTemplate")
  q.yes:SetWidth(100)
  q.no:SetWidth(100)
  q.ok:SetWidth(100)
  q.yes:SetPoint("BOTTOMLEFT", 10, 10)
  q.no:SetPoint("BOTTOMRIGHT", -10, 10)
  q.ok:SetPoint("BOTTOM", 0, 10)
  return q
end

---@param q QuestionFrame
function question:_OnReset(q)
  q.frame:SetTitle("")
  q.text:SetText("")
  q.text:SetHeight(1000)
  q.yes:SetScript("OnClick", nil)
  q.no:SetScript("OnClick", nil)
  q.yes:Show()
  q.no:Show()
  q.ok:Hide()
  q.input:ClearFocus()
  q.input:SetText("")
  q.input:SetScript("OnEscapePressed", nil)
  q.frame:ClearAllPoints()
  q.frame:Hide()
end

function questionProto:Resize()
  local height = self.text:GetStringHeight()
  height = height + (self.input:IsShown() and 50 or 50)
  height = height + self.yes:GetHeight() + 20
  height = height + 40 -- Header up top
  self.text:SetWidth(250)
  self.text:SetHeight(self.text:GetStringHeight())
  self.frame:SetSize(300, math.max(50, height))
end

---@param title string
---@param text string
---@param yes function
---@param no function
function question:YesNo(title, text, yes, no)
  if self.open then return end
  local q = self._pool:Acquire() --[[@as QuestionFrame]]
  q.frame:SetTitle(title)
  q.text:SetText(text)
  q.yes:SetText("Yes")
  q.no:SetText("No")
  q.yes:SetScript("OnClick", function()
    xpcall(yes, geterrorhandler())
    self._pool:Release(q)
    self.open = false
  end)
  q.no:SetScript("OnClick", function()
    xpcall(no, geterrorhandler())
    self._pool:Release(q)
    self.open = false
  end)
  q.input:Hide()
  q:Resize()
  q.frame:SetPoint('CENTER')
  q.frame:Show()
  self.open = true
end

function question:Alert(title, text)
  if self.open then return end
  local q = self._pool:Acquire() --[[@as QuestionFrame]]
  q.frame:SetTitle(title)
  q.text:SetText(text)
  q.no:Hide()
  q.yes:Hide()
  q.ok:SetText("Okay")
  q.ok:SetScript("OnClick", function()
    self._pool:Release(q)
    self.open = false
  end)
  q.ok:Show()
  q.input:Hide()
  q:Resize()
  q.frame:SetPoint('CENTER')
  q.frame:Show()
  self.open = true
end

function question:AskForInput(title, text, onInput)
  if self.open then return end
  local q = self._pool:Acquire() --[[@as QuestionFrame]]
  q.frame:SetTitle(title)
  q.text:SetText(text)
  q.yes:SetText("Okay")
  q.no:SetText("Cancel")
  q.yes:SetScript("OnClick", function()
    if q.input:GetText() ~= "" then
      xpcall(onInput, geterrorhandler(), q.input:GetText())
    end
    self._pool:Release(q)
    self.open = false
  end)
  q.no:SetScript("OnClick", function()
    self._pool:Release(q)
    self.open = false
  end)
  q.input:Show()
  q.input:SetScript("OnEscapePressed", function()
    q.input:ClearFocus()
    self._pool:Release(q)
    self.open = false
  end)
  q.input:SetScript("OnEnterPressed", function()
    xpcall(onInput, geterrorhandler(), q.input:GetText())
    self._pool:Release(q)
    self.open = false
  end)
  q:Resize()
  q.frame:SetPoint('CENTER')
  q.frame:Show()
  self.open = true
end
