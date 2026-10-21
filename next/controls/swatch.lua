local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextSwatch is BetterBags Next's color swatch (next-settings.md §2), drawn from the theme
-- (Controls.Swatch): a square of its color, edged. A click opens Blizzard's color picker with it
-- (ColorPickerFrame:SetupColorPickerAndShow, on every client): each color picked is shown and called
-- back, and Cancel puts the color back, calling that back too, so what was saved follows.
---@class NextSwatch: AceModule
---@field all NextSwatchFrame[]
local nextSwatch = addon:NewModule('NextSwatch')

---@class (exact) NextSwatchOptions
---@field color number[] { r, g, b, a }
---@field hasOpacity? boolean The picker sets the alpha too.
---@field onChange fun(ctx: Context, color: number[])

---@class NextSwatchFrame
---@field frame Button
---@field color Texture
---@field edge NextEdge
---@field current number[]
---@field hovered boolean
---@field opts NextSwatchOptions
local swatchProto = {}
addon:GetModule('Perf'):RegisterPrototype(swatchProto, 'NextSwatchFrame')

nextSwatch.all = {}

---@param ctx? Context
function nextSwatch:ApplyStyle(ctx)
  local _ = ctx
  for _, s in ipairs(self.all) do
    s:Style()
  end
end

---@param parent Frame
---@param opts NextSwatchOptions
---@return NextSwatchFrame
function nextSwatch:Create(parent, opts)
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp")
  local color = frame:CreateTexture(nil, "ARTWORK")
  color:SetAllPoints(frame)
  ---@type NextSwatchFrame
  local s = setmetatable({
    frame = frame, color = color, edge = controls:CreateEdge(frame, "OVERLAY"), hovered = false, opts = opts,
    current = { opts.color[1], opts.color[2], opts.color[3], opts.color[4] or 1 },
  }, { __index = swatchProto })
  addon.SetScript(frame, "OnClick", function() s:Open() end)
  addon.SetScript(frame, "OnEnter", function() s:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function() s:SetHovered(false) end)
  table.insert(self.all, s)
  sonataNext:RegisterWidget(self)
  s:Style()
  return s
end

function swatchProto:Style()
  local S = controls:Theme("Swatch")
  self.frame:SetSize(S.Size, S.Size)
  controls:PaintEdge(self.edge, self.hovered and S.HoverEdge or S.Edge)
  local c = self.current
  self.color:SetColorTexture(c[1], c[2], c[3], c[4])
end

---@return number[]
function swatchProto:GetColor()
  local c = self.current
  return { c[1], c[2], c[3], c[4] }
end

-- SetColor shows a color, calling nothing back.
---@param color number[]
function swatchProto:SetColor(color)
  self.current = { color[1], color[2], color[3], color[4] or 1 }
  self:Style()
end

-- Open shows Blizzard's color picker with the swatch's color.
function swatchProto:Open()
  local before = self:GetColor()
  local hasOpacity = self.opts.hasOpacity == true
  local function picked()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a = hasOpacity and ColorPickerFrame:GetColorAlpha() or self.current[4]
    self:SetColor({ r, g, b, a })
    self.opts.onChange(context:New('NextSwatch_Pick'), self:GetColor())
  end
  ColorPickerFrame:SetupColorPickerAndShow({
    r = before[1], g = before[2], b = before[3], opacity = before[4], hasOpacity = hasOpacity,
    swatchFunc = picked,
    opacityFunc = picked,
    cancelFunc = function()
      self:SetColor(before)
      self.opts.onChange(context:New('NextSwatch_Cancel'), self:GetColor())
    end,
  })
end

---@param hovered boolean
function swatchProto:SetHovered(hovered)
  self.hovered = hovered
  self:Style()
end
