local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextToggle: AceModule
local nextToggle = addon:GetModule('NextToggle')

---@class NextDropdown: AceModule
local nextDropdown = addon:GetModule('NextDropdown')

---@class NextSlider: AceModule
local nextSlider = addon:GetModule('NextSlider')

---@class NextSwatch: AceModule
local nextSwatch = addon:GetModule('NextSwatch')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class NextDialog: AceModule
local nextDialog = addon:GetModule('NextDialog')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSettingsRows makes the rows of BetterBags Next's settings window (next-settings.md §3). A
-- setting's row is its name on the left and its control on the right, editing an option (a settings
-- catalog option, config/catalog.lua, or one of a page's own: a color, a plugin's): it reads the
-- option into the control, writes what the player changes, shows the option again when the change
-- was refused (set returns false), and asks in a dialog over the window to reload the UI after a
-- change that needs one. Its description is its tooltip. Other rows go across the page: text,
-- buttons, a link. Every row answers Measure(width) -> height, Place(x, y, width, height) and
-- Refresh(ctx).
---@class NextSettingsRows: AceModule
---@field all NextSettingsRow[]
local rows = addon:NewModule('NextSettingsRows')

-- An option a row edits: a settings catalog option (SettingOption), or a page's own.
---@class (exact) NextSettingsOption
---@field kind "toggle"|"dropdown"|"slider"|"color"|"input"
---@field title string|fun(): string Read again every time the row shows its value when a function.
---@field description? string|fun(): string?
---@field keywords? string[]
---@field items? string[]
---@field itemsFunction? fun(ctx: Context): string[]
---@field min? number
---@field max? number
---@field step? number
---@field hasOpacity? boolean
---@field reload? boolean
---@field disabled? boolean|fun(): boolean Drawn disabled, read each time the row shows its value.
---@field get fun(ctx: Context): any
---@field set fun(ctx: Context, value: any): boolean?

---@class NextSettingsRow
---@field frame Frame
---@field wide boolean It goes across both columns.
---@field label? FontString
---@field hover? Texture
---@field control? table
---@field option? NextSettingsOption
---@field owner? Frame The window a dialog shows over.
---@field hovered boolean
---@field buttons? NextButtonFrame[]
---@field buttonSpecs? table[] What its buttons were made from: their text and disabled, read again on refresh.
---@field hidden? fun(): boolean Left out of its page while it says so (next/settings/page.lua).
local rowProto = {}
addon:GetModule('Perf'):RegisterPrototype(rowProto, 'NextSettingsRow')

rows.all = {}

-- TextOf returns a text that may be a function, read now.
---@param text? string|fun(): string?
---@return string?
function rows:TextOf(text)
  if type(text) == "function" then
    return text()
  end
  return text
end

---@param ctx? Context
function rows:ApplyStyle(ctx)
  local _ = ctx
  for _, row in ipairs(self.all) do
    row:Style()
  end
end

-- newRow makes a row's frame, mouse enabled for its light and tooltip.
---@param parent Frame
---@param wide boolean
---@return NextSettingsRow
local function newRow(parent, wide)
  local frame = CreateFrame("Frame", nil, parent)
  frame:EnableMouse(true)
  ---@type NextSettingsRow
  local row = setmetatable({ frame = frame, wide = wide, hovered = false }, { __index = rowProto })
  table.insert(rows.all, row)
  sonataNext:RegisterWidget(rows)
  return row
end

-- Create makes a setting's row, its control the option's kind's.
---@param parent Frame
---@param option NextSettingsOption
---@param owner Frame The window the reload dialog shows over.
---@return NextSettingsRow
function rows:Create(parent, option, owner)
  local row = newRow(parent, false)
  row.option, row.owner = option, owner
  local C = style.Theme.Settings.Content
  local hover = row.frame:CreateTexture(nil, "BACKGROUND")
  hover:SetAllPoints(row.frame)
  hover:Hide()
  row.hover = hover
  row.label = style:CreateText(row.frame, C.LabelFont)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(true)
  row.label:SetText(rows:TextOf(option.title) or "")
  local frame, kind = row.frame, option.kind
  local function write(ctx, value) row:Write(ctx, value) end
  local get = option.get
  local mouseFrames
  if kind == "toggle" then
    row.control = nextToggle:Create(frame, { checked = get(nil) == true, onChange = write })
    mouseFrames = { row.control.frame }
  elseif kind == "dropdown" then
    row.control = nextDropdown:Create(frame, {
      items = option.items, itemsFunction = option.itemsFunction, get = get, onChange = write,
    })
    mouseFrames = { row.control.frame }
  elseif kind == "slider" then
    row.control = nextSlider:Create(frame, {
      min = option.min, max = option.max, step = option.step, value = get(nil), onChange = write,
    })
    mouseFrames = { row.control.track, row.control.value.frame }
  elseif kind == "color" then
    row.control = nextSwatch:Create(frame, { color = get(nil), hasOpacity = option.hasOpacity, onChange = write })
    mouseFrames = { row.control.frame }
  elseif kind == "input" then
    row.control = nextInput:Create(frame, { text = get(nil) or "", width = controls:Theme("Dropdown").Width,
      onEnter = write })
    mouseFrames = { row.control.frame }
  else
    error("a settings row has no control for " .. tostring(kind))
  end
  addon.SetScript(frame, "OnEnter", function() row:Enter() end)
  addon.SetScript(frame, "OnLeave", function() row:Leave() end)
  for _, f in ipairs(mouseFrames) do
    addon.HookScript(f, "OnEnter", function() row:Enter() end)
    addon.HookScript(f, "OnLeave", function() row:Leave() end)
  end
  row:Style()
  return row
end

-- CreateText makes a paragraph across the page; text may be a function, read again every time the
-- row shows its value.
---@param parent Frame
---@param text string|fun(): string
---@return NextSettingsRow
function rows:CreateText(parent, text)
  local row = newRow(parent, true)
  row.frame:EnableMouse(false)
  row.label = style:CreateText(row.frame, style.Theme.Settings.Content.TextFont)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(true)
  row.text = text
  row.label:SetText(type(text) == "function" and text() or text)
  row:Style()
  return row
end

-- CreateArea makes a text area across the page (NextInput:CreateArea), opts.height tall; with get,
-- its text is read from it every time the row shows its value.
---@param parent Frame
---@param opts NextTextAreaOptions
---@param get? fun(): string
---@return NextSettingsRow
function rows:CreateArea(parent, opts, get)
  local row = newRow(parent, true)
  row.frame:EnableMouse(false)
  row.area = nextInput:CreateArea(row.frame, opts)
  row.areaHeight = opts.height
  row.get = get
  if get then
    row.area:SetText(get() or "")
  end
  row:Style()
  return row
end

-- CreateButtons makes a row of buttons across the page, from the left.
---@param parent Frame
---@param buttons {text: string, style?: NextButtonStyle, onClick: fun(ctx: Context), tooltip?: string}[]
---@return NextSettingsRow
function rows:CreateButtons(parent, buttons)
  local row = newRow(parent, true)
  row.frame:EnableMouse(false)
  row.buttons = {}
  row.buttonSpecs = buttons
  for i, spec in ipairs(buttons) do
    row.buttons[i] = nextButton:Create(row.frame, {
      text = rows:TextOf(spec.text), style = spec.style, tooltip = spec.tooltip,
      onClick = function(ctx) spec.onClick(ctx) end,
    })
  end
  row:Style()
  row:Refresh()
  return row
end

-- CreateLink makes a link across the page (a search result's page).
---@param parent Frame
---@param text string
---@param onClick fun(ctx: Context)
---@return NextSettingsRow
function rows:CreateLink(parent, text, onClick)
  local row = newRow(parent, true)
  row.frame:EnableMouse(false)
  row.button = nextButton:Create(row.frame, { text = text, style = "Link", onClick = function(ctx) onClick(ctx) end })
  row:Style()
  return row
end

-- Style draws the row from the theme.
function rowProto:Style()
  local C = style.Theme.Settings.Content
  if self.hover then
    controls:Paint(self.hover, C.Hover)
    self.hover:SetShown(self.hovered)
  end
  if self.label then
    style:SetFont(self.label, self.option and C.LabelFont or C.TextFont)
  end
end

-- Measure returns the row's height at a width: a setting's name wraps beside its control, and the row
-- is at least RowHeight tall; text wraps across it.
---@param width number
---@return number
function rowProto:Measure(width)
  local C = style.Theme.Settings.Content
  local pad = C.RowPad
  if self.control then
    self.label:SetWidth(math.max(1, width - self.control.frame:GetWidth() - 3 * pad))
    return math.max(C.RowHeight, math.ceil(self.label:GetStringHeight()) + pad)
  end
  if self.buttons then
    return controls:Theme("Button").Height + pad
  end
  if self.button then
    return self.button.frame:GetHeight() + pad
  end
  if self.area then
    return self.areaHeight + pad
  end
  self.label:SetWidth(math.max(1, width - 2 * pad))
  return math.ceil(self.label:GetStringHeight()) + pad
end

-- Place puts the row x across and y down its parent, width x height, its parts RowPad in.
---@param x number
---@param y number
---@param width number
---@param height number
function rowProto:Place(x, y, width, height)
  local C = style.Theme.Settings.Content
  local pad, frame = C.RowPad, self.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
  frame:SetSize(width, height)
  if self.control then
    self.label:ClearAllPoints()
    self.label:SetPoint("LEFT", frame, "LEFT", pad, 0)
    self.control.frame:ClearAllPoints()
    self.control.frame:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
  elseif self.buttons then
    local previous
    for _, b in ipairs(self.buttons) do
      b.frame:ClearAllPoints()
      if previous == nil then
        b.frame:SetPoint("LEFT", frame, "LEFT", pad, 0)
      else
        b.frame:SetPoint("LEFT", previous.frame, "RIGHT", pad / 2, 0)
      end
      previous = b
    end
  elseif self.button then
    self.button.frame:ClearAllPoints()
    self.button.frame:SetPoint("LEFT", frame, "LEFT", pad, 0)
  elseif self.area then
    local area = self.area.frame
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad / 2)
    area:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad / 2)
    area:SetHeight(self.areaHeight)
  else
    self.label:ClearAllPoints()
    self.label:SetPoint("LEFT", frame, "LEFT", pad, 0)
  end
  frame:Show()
end

-- Refresh shows the option's value again (it may have changed elsewhere).
---@param ctx? Context
function rowProto:Refresh(ctx)
  local option, control = self.option, self.control
  if option == nil then
    -- A button's text and whether it is enabled may change (a plugin's execute: its name, disabled).
    for i, spec in ipairs(self.buttonSpecs or {}) do
      local b = self.buttons[i]
      if type(spec.text) == "function" then
        b:SetText(spec.text() or "")
      end
      if spec.disabled ~= nil then
        b:SetEnabled(spec.disabled() ~= true)
      end
    end
    if type(self.text) == "function" then
      self.label:SetText(self.text())
    elseif self.area and self.get then
      self.area:SetText(self.get() or "")
    end
    return
  end
  if type(option.title) == "function" then
    self.label:SetText(option.title() or "")
  end
  local disabled = option.disabled
  if type(disabled) == "function" then
    disabled = disabled()
  end
  if control.SetEnabled then
    control:SetEnabled(disabled ~= true)
  end
  local kind = option.kind
  if kind == "toggle" then
    -- A switch another setting changed (Auto Sell turning Destroy off) slides while it shows.
    local on = option.get(ctx) == true
    control:SetChecked(on, on ~= control:GetChecked() and control.frame:IsVisible())
  elseif kind == "dropdown" then
    control:Refresh(ctx)
  elseif kind == "slider" then
    control:SetValue(option.get(ctx))
  elseif kind == "color" then
    control:SetColor(option.get(ctx))
  elseif kind == "input" then
    control:SetText(option.get(ctx) or "")
  end
end

-- Write writes what the player changed. A change refused shows the option again; one that needs a
-- reload asks for one.
---@param ctx Context
---@param value any
function rowProto:Write(ctx, value)
  local applied = self.option.set(ctx, value)
  if applied == false then
    self:Refresh(ctx)
    return
  end
  if self.option.reload then
    nextDialog:Show(self.owner, {
      title = L:G("Reload UI"),
      text = L:G("BetterBags needs to reload the UI for this change to take effect. Reload now?"),
      buttons = {
        { text = L:G("Later"), onClick = function() end },
        { text = L:G("Reload"), style = "Primary", onClick = function() ReloadUI() end },
      },
    })
  end
end

-- Enter lights the row and shows its tooltip: its name and description.
function rowProto:Enter()
  if self.hovered then
    return
  end
  self.hovered = true
  self.hover:Show()
  local option = self.option
  local description = option and rows:TextOf(option.description)
  if description and description ~= "" then
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:SetText(rows:TextOf(option.title) or "", 1, 1, 1, 1, true)
    GameTooltip:AddLine(description, nil, nil, nil, true)
    GameTooltip:Show()
  end
end

-- Leave puts the light out once the pointer has left the row, not just moved onto its control.
function rowProto:Leave()
  if not self.hovered or self.frame:IsMouseOver() then
    return
  end
  self.hovered = false
  self.hover:Hide()
  if GameTooltip:IsOwned(self.frame) then
    GameTooltip:Hide()
  end
end
