local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextOrnaments: AceModule
local ornaments = addon:GetModule('NextOrnaments')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

-- NextMenuButton is a BetterBags Next panel's bag button, for a theme that puts its header's row in a menu
-- (Header.Buttons.Menu, next-themes.md §19). Asked, of the Plain theme: "remove all top bar buttons ... bring back the
-- drop down menu with these options, just like the original bags ... just the options we are removing from the bar",
-- on the backpack, the bank and the vendor, the vendor's button its portrait (docs/next-plain-theme.md, round three).
-- The button sits at a corner of the body as an ornament's corner piece does, drawn from data: layers of art (a file,
-- an atlas, a unit's portrait), each inset into it and cut by a mask, never flipped; a highlight under the pointer. A
-- left click opens the original bags' menu (ContextMenu, frames/contextmenu.lua) listing the panel's header buttons
-- that are not pinned, Open Options Screen last.
---@class NextMenuButtonModule: AceModule
local menuButton = addon:NewModule('NextMenuButton')

---@class (exact) NextMenuButton
---@field panel table The panel: its frame, body, overlay, side, kind, headerButtons.
---@field frame Button
---@field layers Texture[] Every layer made; the theme's first ones shown.
---@field masks table<number, MaskTexture> Each layer's mask, made the first time one is cut.
---@field highlight Texture Over the layers, lit under the pointer.
---@field glow number The highlight's alpha when lit (its Alpha).
local buttonProto = {}
addon:GetModule('Perf'):RegisterPrototype(buttonProto, 'NextMenuButtonFrame')

-- The menu's title line, as the original bags' menu has one (frames/contextmenu.lua).
local TITLE = addonName

-- Create gives a panel its bag button, hidden until a theme with one styles it (Style).
---@param panel table
---@return NextMenuButton
function menuButton:Create(panel)
  local frame = CreateFrame("Button", nil, panel.frame)
  -- Over the panel's frame drawn above its content (Panel.Frame.Above), as the header's buttons are.
  frame:SetFrameLevel(panel.overlay:GetFrameLevel() + 3)
  frame:RegisterForClicks("LeftButtonUp")
  frame:Hide()
  local b = setmetatable({ panel = panel, frame = frame, layers = {}, masks = {}, glow = 1,
    highlight = frame:CreateTexture(nil, "OVERLAY", nil, 7) }, { __index = buttonProto })
  b.highlight:SetAlpha(0)
  addon.SetScript(frame, "OnEnter", function()
    b:Light(true)
  end)
  addon.SetScript(frame, "OnLeave", function()
    b:Light(false)
  end)
  addon.SetScript(frame, "OnClick", function(ctx)
    b:Open(ctx)
  end)
  return b
end

-- panelName names the panel a kind of bag is shown in, as ornaments name them (Backpack, Bank, Vendor, GuildBank).
---@param kind BagKind
---@return string?
local function panelName(kind)
  for name, kindName in pairs(ornaments.PANELS) do
    if const.BAG_KIND[kindName] == kind then
      return name
    end
  end
  return nil
end

-- Spec returns the theme's menu button for the panel: Header.Buttons.Menu, with what its Panels entry for the panel
-- names over it (the vendor's portrait in place of the bag); nil for a theme without one.
---@return table?
function buttonProto:Spec()
  local M = style.Theme.Header.Buttons.Menu
  if type(M) ~= "table" then
    return nil
  end
  local name = panelName(self.panel.kind)
  local own = M.Panels and name and M.Panels[name]
  if own == nil then
    return M
  end
  local spec = {}
  for k, v in pairs(M) do
    spec[k] = v
  end
  for k, v in pairs(own) do
    spec[k] = v
  end
  return spec
end

-- Room says how much of the title's row the button takes from the body's inner side and from its outer side: from its
-- side to its far edge, for a button at a top corner (none for no button, or one at a bottom corner).
---@return number inner, number outer
function buttonProto:Room()
  local M = self:Spec()
  if M == nil or M.Point:sub(1, 3) ~= "TOP" then
    return 0, 0
  end
  local body = self.panel.body
  local room = math.max(0, pixel:Snap(body, M.X or 0) + pixel:Length(body, M.Width))
  if M.Point == "TOPINNER" then
    return room, 0
  end
  return 0, room
end

-- place anchors a layer or the highlight into the button by its Inset (Left, Right, Top, Bottom; negative reaches
-- past), in whole pixels (docs/next-pixel-perfect.md).
---@param t Texture
---@param inset? table
function buttonProto:place(t, inset)
  inset = inset or {}
  local frame = self.frame
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", frame, "TOPLEFT", pixel:Snap(frame, inset.Left or 0), -pixel:Snap(frame, inset.Top or 0))
  t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pixel:Snap(frame, inset.Right or 0), pixel:Snap(frame, inset.Bottom or 0))
end

-- draw paints a layer or the highlight: its art (NextOrnaments:DrawArt: a unit's portrait while there is one, an atlas,
-- a file), cropped to its TexCoords, in its color, alpha, blend mode and desaturation; one naming only a color, filled
-- with it (the dark disc under a portrait).
---@param t Texture
---@param spec table
local function draw(t, spec)
  local r, g, b, a = style:RGBA(spec.Color or "White", spec.Alpha)
  local c = spec.TexCoords
  if spec.Texture == nil and spec.Atlas == nil and spec.Unit == nil and spec.Color ~= nil then
    t:SetColorTexture(r, g, b, a)
    r, g, b, a = 1, 1, 1, 1
    c = nil
  else
    ornaments:DrawArt(t, spec)
  end
  if c ~= nil then
    t:SetTexCoord(c[1], c[2], c[3], c[4])
  else
    t:SetTexCoord(0, 1, 0, 1)
  end
  t:SetVertexColor(r, g, b, a)
  t:SetBlendMode(spec.BlendMode or "BLEND")
  t:SetDesaturated(spec.Desaturated == true)
end

-- Style draws the button from the theme, or hides it for a theme without one: at its corner (Point: TOPINNER,
-- TOPOUTER, BOTTOMINNER, BOTTOMOUTER, by its own Anchor, the same corner when unset), X toward the body's middle and Y
-- down, mirrored on a panel whose inner side is on the right; Width x Height; its Layers in order, each inset into it,
-- cut by its Mask, never flipped (a portrait, a bag), each a file, an atlas, a unit's portrait or only a color; its
-- Highlight over them.
function buttonProto:Style()
  local M = self:Spec()
  local frame = self.frame
  if M == nil then
    frame:Hide()
    return
  end
  local body = self.panel.body
  local point, anchor = ornaments.CORNERS[M.Point], ornaments.CORNERS[M.Anchor or M.Point]
  if self.panel.side == "LEFT" then
    point, anchor = ornaments.MIRRORED[point], ornaments.MIRRORED[anchor]
  end
  local x, y = pixel:Snap(body, M.X or 0), pixel:Snap(body, M.Y or 0)
  frame:ClearAllPoints()
  frame:SetPoint(anchor, body, point, point:find("LEFT") and x or -x, -y)
  pixel:Size(frame, M.Width, M.Height)
  local list = M.Layers or {}
  for i, spec in ipairs(list) do
    local t = self.layers[i]
    if t == nil then
      t = frame:CreateTexture(nil, "ARTWORK")
      self.layers[i] = t
    end
    t:SetDrawLayer(spec.Layer or "ARTWORK", spec.SubLevel or math.min(7, i - 1))
    self:place(t, spec.Inset)
    draw(t, spec)
    self.masks[i] = ornaments:Cut(t, spec.Mask, frame, self.masks[i], false)
    t:Show()
  end
  for i = #list + 1, #self.layers do
    self.masks[i] = ornaments:Cut(self.layers[i], nil, frame, self.masks[i], false)
    self.layers[i]:Hide()
  end
  local H = M.Highlight
  if H then
    self:place(self.highlight, H.Inset)
    -- A texture's alpha is its vertex color's: colored again, it keeps the alpha it fades through (next-themes.md §10).
    local alpha = self.highlight:GetAlpha()
    draw(self.highlight, H)
    self.glow = H.Alpha or 1
    self.highlight:SetAlpha(math.min(alpha, self.glow))
    self.highlight:SetDrawLayer(H.Layer or "OVERLAY", H.SubLevel or 7)
    self.highlight:Show()
  else
    self.highlight:Hide()
  end
  frame:Show()
end

-- Paint draws the button again: a unit's portrait, which the panel's showing may have changed (a new vendor).
function buttonProto:Paint()
  self:Style()
end

-- Light fades the highlight in under the pointer (and says what a click does, as the original bags' button did) and
-- out after.
---@param on boolean
function buttonProto:Light(on)
  local glow = self.highlight
  tween:Play(glow, {
    duration = style.Time.Hover,
    from = glow:GetAlpha(),
    to = on and self.glow or 0,
    onUpdate = function(alpha)
      glow:SetAlpha(alpha)
    end,
  })
  if on then
    GameTooltip:SetOwner(self.frame, self.panel.side == "LEFT" and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine(L:G("Left Click"), L:G("Open Menu"), 1, 0.81, 0, 1, 1, 1)
    GameTooltip:Show()
  else
    GameTooltip:Hide()
  end
end

-- pinned says whether a header button stays in the header (Header.Buttons.Pinned: the close button).
---@param button Button
---@return boolean
local function pinned(button)
  local pins = style.Theme.Header.Buttons.Pinned
  return type(pins) == "table" and pins[button.key] ~= nil
end

-- entryOf is a header button as a menu entry, in the original bags' menu's form (LibUIDropDownMenu, EasyMenu): its
-- name (label, else its tooltip), checked for a toggle (checked), disabled as the button is, its tooltip on the entry
-- (menuTooltip, else its tooltip when it is not the name), its action on a click. The tooltip is read now: the
-- library calls back on entering an entry only on retail.
---@param button Button
---@param spec NextHeaderButton
---@return table
local function entryOf(button, spec)
  local label = spec.label or spec.tooltip
  if type(label) == "function" then
    label = label()
  end
  local text = spec.menuTooltip and spec.menuTooltip() or nil
  if text == nil and spec.tooltip ~= nil and spec.tooltip ~= label then
    text = spec.tooltip
  end
  return {
    text = label,
    notCheckable = spec.checked == nil,
    checked = spec.checked,
    isNotRadio = true,
    disabled = not button:IsEnabled(),
    tooltipTitle = label,
    tooltipText = text,
    tooltipOnButton = true,
    tooltipWhileDisabled = true,
    func = function()
      spec.onClick(context:New("NextMenuButton"))
    end,
  }
end

-- Entries lists the menu: the original bags' title line, then the header buttons the panel shows that are not pinned,
-- in their order, those that say menuLast (Open Options Screen, last in the original menu too) at the end.
---@return table[]
function buttonProto:Entries()
  local settings = addon:GetModule('NextSettings', true)
  local version = settings and settings:VersionText() or ""
  local list = { { text = version ~= "" and (TITLE .. " " .. version) or TITLE, isTitle = true, notCheckable = true } }
  local last = {}
  for _, button in ipairs(self.panel.headerButtons) do
    local spec = button.spec
    if spec ~= nil and button:IsShown() and not pinned(button) then
      table.insert(spec.menuLast and last or list, entryOf(button, spec))
    end
  end
  for _, entry in ipairs(last) do
    table.insert(list, entry)
  end
  return list
end

-- Text makes one tooltip text for a menu entry of lines a header button's tooltip shows ({ text, r, g, b } each): each
-- line in its color, one under another (the entry's tooltip is one text, LibUIDropDownMenu's tooltipText).
---@param lines table[]
---@return string
function menuButton:Text(lines)
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = string.format("|cff%02x%02x%02x%s|r", math.floor(line[2] * 255 + 0.5), math.floor(line[3] * 255 + 0.5),
      math.floor(line[4] * 255 + 0.5), line[1])
  end
  return table.concat(out, "\n")
end

-- Open opens the menu at the cursor, as the original bags' button does.
---@param ctx Context
function buttonProto:Open(ctx)
  GameTooltip:Hide()
  addon:GetModule('ContextMenu'):Show(ctx, self:Entries())
end
