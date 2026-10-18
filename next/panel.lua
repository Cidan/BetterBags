local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class CursorPlacement: AceModule
local cursorPlacement = addon:GetModule('CursorPlacement')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Scrollbox: AceModule
local scrollbox = addon:GetModule('Scrollbox')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextSparkles: AceModule
local sparkles = addon:GetModule('NextSparkles')

---@class NextTabs: AceModule
local nextTabs = addon:GetModule('NextTabs')

---@class NextContent: AceModule
local nextContent = addon:GetModule('NextContent')

---@class NextDrag: AceModule
local nextDrag = addon:GetModule('NextDrag')

---@class NextChain: AceModule
local chain = addon:GetModule('NextChain')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

-- NextPanel is the panel BetterBagsNext's bags are made of (next.md §3): a full-height panel on a
-- side of the screen that slides in from that edge, its inner edge feathered out to nothing, with
-- the title and its sparkles, a search box, the tabs down its inner side, the content in one
-- column and a footer. Everything mirrors with the side: the backpack is on the right, the bank on
-- the left. Where a panel rests, at its edge or chained beside its partner, is NextChain's
-- (next/chain.lua). A kind (next/bag.lua, next/bank.lua) makes its prototype with Extend and supplies its
-- header buttons, its tabs and what they do, what opening and closing do, sorting and refreshing.
---@class NextPanel: AceModule
---@field proto NextPanelFrame The panel's prototype every kind's chains to.
local nextPanel = addon:NewModule('NextPanel')

-- The ribbon running from the title out of the window.
local RIBBON_LENGTH = style.RIBBON_LENGTH
-- Sparkles a second along a feathered edge.
local EDGE_SPARKLE_RATE = 2.5
-- The spark gliding in along it, and how much it grows as it settles into the title's cloud.
local SPARK_SIZE = 26
local SPARK_GROWTH = 18
-- The ribbon's glow: thin lines above and below it, fainter the further out.
local RIBBON_GLOW = { { 0, 0.9 }, { 2, 0.35 }, { -2, 0.35 }, { 4, 0.15 }, { -4, 0.15 }, { 6, 0.06 }, { -6, 0.06 } }

---@alias NextSide "RIGHT"|"LEFT"

-- A bag's half of the braid two coupled bags' ribbons twist into (next.md §12): two strands of
-- lines from its body edge to the middle of the gap, lights running along them, and the knot in the
-- middle (shown by the chained bag).
---@class (exact) NextBraid
---@field strands Line[][]
---@field beads Texture[]
---@field knot Texture
---@field amount number 0 (straight ribbon) to 1 (braided).
---@field half number From the body edge to the middle of the gap.
---@field chained boolean It is the chained bag (it shows the knot).
---@field phase number
---@field time number
---@field swell number The knot's swell as the pair couples.

-- A puff of the title's cloud and where it rests: x along and y above the title's middle, from the
-- title's point the ribbon joins (TitleJoin), its size and alpha before it breathes.
---@class (exact) NextCloudPuff
---@field texture Texture
---@field base {x: number, y: number, w: number, h: number, a: number}
---@field period number Seconds per breath.
---@field phase number Where in its breath it starts.

---@class (exact) NextCloud
---@field puffs NextCloudPuff[]
---@field join Texture The puff on the ribbon's end.
---@field driver Frame Runs the breathing while the panel shows.
---@field time number Seconds the cloud has breathed.
---@field swell number How brightly it swells with the shimmer, 0 to 1.

---@class (exact) NextPanelOptions
---@field kind BagKind
---@field side NextSide The edge of the screen it is on and slides out from.
---@field name string The frame's global name.
---@field scrollName string The scroll box's global name.
---@field title string
---@field openSound number
---@field closeSound number
---@field noDrag? boolean Its sections are not dragged, and nothing is dropped on it (the vendor).
---@field chainRole "backpack"|"companion" What it is in the chain (next.md §12).

---@class (exact) NextHeaderButton
---@field key string The field the button is kept in on the panel.
---@field atlas? string
---@field texture? string|number
---@field texCoords? number[] Of the texture: left, right, top, bottom.
---@field tooltip string
---@field tooltipFunc? fun(button: Button) Fills the tooltip instead of tooltip.
---@field onClick fun(ctx: Context)

---@class NextPanelFrame
---@field kind BagKind
---@field side NextSide
---@field openSound number
---@field closeSound number
---@field frame Frame The panel.
---@field body Frame The opaque part, inside the feathered edge.
---@field fill Texture The body's color, reaching OVERREACH past the screen edge while docked.
---@field outerFeather Texture The body's far edge feathered out, while it is not at its screen edge.
---@field docked boolean It is at its screen edge (not beside its anchor, nor flying).
---@field chainRole "backpack"|"companion"
---@field target? number The offset it is headed to (or rests at).
---@field ribbonLines Texture[] The ribbon and its glow lines.
---@field ribbonLength number How far the ribbon reaches from the body: full length, or the middle of
--- the gap while coupled.
---@field titleButton Button Over the title: a click chains (next.md §12).
---@field titleGlow Texture Behind the title, lit while the pointer is over it.
---@field braid NextBraid This bag's half of the braid while coupled.
---@field knotSparkles NextSparkleEmitter Bursts from the knot as the pair couples.
---@field sparkSpread number How far out from the body the ribbon's sparkles are born.
---@field edgeOuter boolean The edge sparkles are on the far (outer) edge.
---@field feather Texture
---@field wash Texture The faint color at the top of the body.
---@field dropGlow Texture Lit while a section from the other bag would drop here (next.md §7).
---@field washColor number[] The wash's color now.
---@field title FontString
---@field ribbon Texture The ribbon's brightest line.
---@field spark Texture What glides in along the ribbon and settles into the cloud.
---@field cloud NextCloud Round the title, the ribbon flowing into it.
---@field headerButtons Button[] In order from the screen edge.
---@field searchBox SearchFrame
---@field scroll ScrollboxDrawable
---@field content NextCanvas
---@field root Drawable
---@field tabs NextTabRail
---@field moneyFrame? Money
---@field freeText FontString
---@field emptyText FontString Shown while the tab holds nothing.
---@field sparkles NextSparkleEmitter Around the title's ribbon.
---@field edgeSparkles NextSparkleEmitter Along the feathered edge.
---@field offset number How far the panel is from its place, outward being off the screen.
---@field closing boolean It is sliding out.
---@field onShown? (fun())[] What to call once the slide in playing has ended. Every slide in starts
--- a new list: a slide a close or Escape cut short never ends, so its list is never called.
---@field opening boolean It is drawing as it opens.
---@field tabChanged boolean The next draw shows another tab.
---@field drawOnClose boolean
---@field drawPendingOnShow boolean
---@field lastSlotInfo? SlotInfo
---@field drawnButtons table<Item, boolean>
---@field claims? table<Item, boolean>
---@field loaded boolean
---@field bankTab? number
---@field watchesCooldowns? boolean It refreshes its buttons' cooldowns (the backpack).
local panelProto = {}
nextPanel.proto = panelProto
addon:GetModule('Perf'):RegisterPrototype(panelProto, 'NextPanelFrame')

-- The panel's render root: it hands the scroll box the content's width and the height between
-- the header and the footer.
local rootProto = drawable:Extend({}, 'NextPanelRoot')

---@return RenderPlan
function rootProto:GetRenderPlan()
  return { Plan = { { step = render.PRE }, { step = render.DEP, target = self.bag.scroll }, { step = render.SELF } } }
end

---@return RenderResult
function rootProto:PreRender()
  return {
    Width = style.GRID_WIDTH + style.GUTTER,
    Height = math.max(1, UIParent:GetHeight() - style.CONTENT_TOP - style.FOOTER),
  }
end

---@return RenderResult
function rootProto:Render()
  return { Width = style.WIDTH, Height = UIParent:GetHeight() }
end

-- Extend makes proto a kind's prototype: its instances fall back to the panel's methods, and the
-- profiler measures its own methods under name.
---@generic T
---@param proto T
---@param name string
---@return T
function nextPanel:Extend(proto, name)
  setmetatable(proto, { __index = panelProto })
  addon:GetModule('Perf'):RegisterPrototype(proto, name)
  return proto
end

-- Create makes a panel of a kind's prototype (one Extend made), hidden.
---@param proto table
---@param opts NextPanelOptions
---@return NextPanelFrame
function nextPanel:Create(proto, opts)
  ---@type NextPanelFrame
  local p = setmetatable({}, { __index = proto })
  p.kind = opts.kind
  p.side = opts.side
  p.openSound = opts.openSound
  p.closeSound = opts.closeSound
  p.offset = 0
  p.closing = false
  p.opening = false
  p.tabChanged = false
  p.drawOnClose = false
  p.drawPendingOnShow = false
  p.drawnButtons = {}
  p:BuildPanel(opts.name)
  p:BuildSearch()
  p:BuildHeader(opts.title)
  p:BuildContent(opts.scrollName)
  p:BuildFooter()
  p:BuildSparkles()
  p:BuildTabs()
  p:Watch()
  p.content:SetHeaderHandler(p)
  if not opts.noDrag then
    nextDrag:Register(p)
  end
  chain:Register(p, opts.chainRole)
  return p
end

-- outward is the direction from the panel toward the middle of the screen: left (-1) for the
-- panel on the right, right (1) for the panel on the left.
---@return number
function panelProto:Outward()
  return self.side == "LEFT" and 1 or -1
end

-- HiddenOffset is where the panel is when it has slid off the screen.
---@return number
function panelProto:HiddenOffset()
  return -self:Outward() * (style.WIDTH + style.OVERREACH)
end

---@private
---@param x number
function panelProto:setOffset(x)
  self.offset = x
  local frame = self.frame
  frame:ClearAllPoints()
  if self.side == "LEFT" then
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
  else
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x, 0)
  end
end

-- RestOffset is where the panel rests: at its edge, or beside its anchor (next.md §12).
---@return number
function panelProto:RestOffset()
  return chain:RestOffset(self)
end

-- SetDocked shapes the body's far edge: at its screen edge the fill and the wash reach OVERREACH past
-- it, so the opening bounce never shows what is behind; away from it (beside its anchor, or flying)
-- they stop at the frame and the far edge feathers out toward the middle of the screen.
---@param docked boolean
function panelProto:SetDocked(docked)
  self.docked = docked
  local reach = docked and style.OVERREACH or 0
  local frame = self.frame
  if self.side == "LEFT" then
    self.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, 0)
    self.wash:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, 0)
  else
    self.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", reach, 0)
    self.wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", reach, 0)
  end
  self.outerFeather:SetShown(not docked)
  self:updateEdgeSparkles()
end

-- finishShowing calls what waited for the panel to finish showing (Show's onShown), once.
---@private
function panelProto:finishShowing()
  local callbacks = self.onShown or {}
  self.onShown = nil
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

-- FlyTo flies the panel to an offset (chaining, next.md §12): detached from its edge as it leaves,
-- docked again if it comes to rest there. A flight that took over an opening slide still says when
-- the panel has finished showing.
---@param to number
function panelProto:FlyTo(to)
  self.target = to
  if to ~= 0 then
    self:SetDocked(false)
  end
  tween:Play(self, {
    duration = style.Time.Fly,
    from = self.offset,
    to = to,
    ease = "inOutCubic",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      if to == 0 then
        self:SetDocked(true)
      end
      self:finishShowing()
      chain:Arrived(self)
    end,
  })
end

-- PlaceAt puts the panel at an offset at once (the screen changed).
---@param to number
function panelProto:PlaceAt(to)
  tween:Stop(self)
  self.target = to
  self:setOffset(to)
  self:SetDocked(to == 0)
  self:finishShowing()
end

-- BuildPanel makes the panel: full height on its edge of the screen, its body a deep indigo with
-- a faint wash of color at the top, its inner edge feathered out to nothing. It sits in the HIGH
-- strata, above the rest of the UI: what must cover it is higher (Blizzard's popups and game menu
-- are DIALOG, menus FULLSCREEN_DIALOG, tooltips TOOLTIP), or HIGH and toplevel, raising itself
-- above it when shown (the stack split, StackSplitFrame.xml).
---@param name string
function panelProto:BuildPanel(name)
  local left = self.side == "LEFT"
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetFrameLevel(500)
  frame:SetToplevel(true)
  frame:SetWidth(style.WIDTH)
  frame:EnableMouse(true)
  if left then
    frame:SetHitRectInsets(0, style.FEATHER, 0, 0)
  else
    frame:SetHitRectInsets(style.FEATHER, 0, 0, 0)
  end
  frame:Hide()
  self.frame = frame
  self:setOffset(0)

  local body = CreateFrame("Frame", nil, frame)
  if left then
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -style.FEATHER, 0)
  else
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", style.FEATHER, 0)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  end
  self.body = body

  -- The fill reaches past the screen edge so the opening overshoot never shows what is behind.
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  local feather = frame:CreateTexture(nil, "BACKGROUND")
  local wash = frame:CreateTexture(nil, "BORDER")
  feather:SetWidth(style.FEATHER)
  feather:SetColorTexture(1, 1, 1, 1)
  if left then
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", -style.OVERREACH, 0)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -style.FEATHER, 0)
    feather:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    feather:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    feather:SetGradient("HORIZONTAL", style:CreateColor("Body"), style:CreateColor("Body", 0))
    wash:SetPoint("TOPLEFT", frame, "TOPLEFT", -style.OVERREACH, 0)
    wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -style.FEATHER, 0)
  else
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", style.FEATHER, 0)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", style.OVERREACH, 0)
    feather:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    feather:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    feather:SetGradient("HORIZONTAL", style:CreateColor("Body", 0), style:CreateColor("Body"))
    wash:SetPoint("TOPLEFT", frame, "TOPLEFT", style.FEATHER, 0)
    wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", style.OVERREACH, 0)
  end
  fill:SetColorTexture(unpack(style.Color.Body))
  self.fill = fill
  self.feather = feather

  -- The far edge feathered out toward the middle of the screen, while not at its edge (SetDocked).
  local outerFeather = frame:CreateTexture(nil, "BACKGROUND")
  outerFeather:SetWidth(style.FEATHER)
  outerFeather:SetColorTexture(1, 1, 1, 1)
  if left then
    outerFeather:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    outerFeather:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    outerFeather:SetGradient("HORIZONTAL", style:CreateColor("Body", 0), style:CreateColor("Body"))
  else
    outerFeather:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    outerFeather:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
    outerFeather:SetGradient("HORIZONTAL", style:CreateColor("Body"), style:CreateColor("Body", 0))
  end
  outerFeather:Hide()
  self.outerFeather = outerFeather
  self.docked = true

  wash:SetHeight(260)
  wash:SetColorTexture(1, 1, 1, 1)
  wash:SetBlendMode("ADD")
  self.wash = wash
  self:paintWash(style.Color.Wash)

  local glow = frame:CreateTexture(nil, "BORDER")
  glow:SetAllPoints(body)
  glow:SetColorTexture(1, 1, 1, 1)
  glow:SetVertexColor(unpack(style.Color.Lavender))
  glow:SetBlendMode("ADD")
  glow:SetAlpha(0)
  glow:Hide()
  self.dropGlow = glow
end

-- SetDropGlow lights the body while a section from the other bag would drop on it.
---@param on boolean
function panelProto:SetDropGlow(on)
  local glow = self.dropGlow
  if on then
    glow:Show()
  end
  tween:Play(glow, {
    duration = style.Time.Hover,
    from = glow:GetAlpha(),
    to = on and 0.12 or 0,
    onUpdate = function(v)
      glow:SetAlpha(v)
    end,
    onDone = function()
      if not on then
        glow:Hide()
      end
    end,
  })
end

-- ShownBankType is the bank type the panel shows: none for the backpack.
---@return number?
function panelProto:ShownBankType()
  return nil
end

-- InTabMode is whether the panel's tabs are Blizzard's bank tabs: never for the backpack.
---@return boolean
function panelProto:InTabMode()
  return false
end

-- titleAdapter is what the classic title's item drop needs of a section (SectionFrame
-- OnTitleClickOrDrop): its bag kind and title.
---@private
---@param section NextSection
---@return table
function panelProto:titleAdapter(section)
  local kind = self.kind
  return {
    GetKind = function() return kind end,
    GetTitle = function() return section.name end,
  }
end

-- OnHeaderDragStart picks a section up by its header (next.md §7).
---@param section NextSection
function panelProto:OnHeaderDragStart(section)
  nextDrag:Begin(self, section)
end

-- OnHeaderDragStop drops the section being dragged.
---@param section NextSection
function panelProto:OnHeaderDragStop(section)
  local _ = section
  nextDrag:Drop(context:New('NextSectionDrop'))
end

-- OnHeaderClick passes an item clicked onto a header to the panel (Shift: to the category), and
-- moves a section to the open window on a right click (Move Categories).
---@param ctx Context
---@param section NextSection
---@param button string
function panelProto:OnHeaderClick(ctx, section, button)
  if CursorHasItem() then
    sectionFrame:OnTitleClickOrDrop(ctx, self:titleAdapter(section))
    return
  end
  if button == "RightButton" and section.kind ~= "free" then
    sectionFrame:MoveItems(nextDrag:SectionItems(section))
  end
end

-- OnHeaderReceiveDrag passes an item dropped on a header to the panel (Shift: to the category).
---@param ctx Context
---@param section NextSection
function panelProto:OnHeaderReceiveDrag(ctx, section)
  if CursorHasItem() then
    sectionFrame:OnTitleClickOrDrop(ctx, self:titleAdapter(section))
  end
end

-- OnHeaderEnter tells what a header does.
---@param section NextSection
function panelProto:OnHeaderEnter(section)
  if nextDrag:IsActive() then
    return
  end
  GameTooltip:SetOwner(section.header, self.side == "LEFT" and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
  GameTooltip:SetText(section.name, 1, 1, 1, 1, true)
  if section.kind == "category" then
    GameTooltip:AddLine(L:G("Drag to reorder, or onto a tab or the other bag."), 0.8, 0.8, 0.8, true)
  end
  if section.kind ~= "free" then
    GameTooltip:AddLine(L:G("Right-click to move it to the open window."), 0.8, 0.8, 0.8, true)
  end
  GameTooltip:Show()
end

---@param section NextSection
function panelProto:OnHeaderLeave(section)
  local _ = section
  GameTooltip:Hide()
end

---@private
---@param c number[]
function panelProto:paintWash(c)
  self.washColor = { c[1], c[2], c[3], c[4] }
  self.wash:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], c[4]))
end

-- SetWash fades the wash at the top of the panel to a color of the palette.
---@param name string
function panelProto:SetWash(name)
  local from = self.washColor
  local to = style.Color[name]
  tween:Play(self.wash, {
    duration = style.Time.Wash,
    from = 0,
    to = 1,
    ease = "inOutSine",
    onUpdate = function(t)
      local c = {}
      for i = 1, 4 do
        c[i] = from[i] + (to[i] - from[i]) * t
      end
      self:paintWash(c)
    end,
  })
end

---@private
---@param spec NextHeaderButton
---@return Button
function panelProto:headerButton(spec)
  local button = CreateFrame("Button", nil, self.frame)
  button:SetSize(22, 22)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  if spec.atlas then
    icon:SetAtlas(spec.atlas)
  else
    icon:SetTexture(spec.texture)
    if spec.texCoords then
      icon:SetTexCoord(unpack(spec.texCoords))
    end
  end
  icon:SetVertexColor(0.85, 0.82, 1, 1)
  button.icon = icon
  button:SetScript("OnEnter", function()
    icon:SetVertexColor(1, 1, 1, 1)
    GameTooltip:SetOwner(button, self.side == "LEFT" and "ANCHOR_BOTTOMRIGHT" or "ANCHOR_BOTTOMLEFT")
    if spec.tooltipFunc then
      spec.tooltipFunc(button)
    else
      GameTooltip:SetText(spec.tooltip, 1, 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    icon:SetVertexColor(0.85, 0.82, 1, 1)
    GameTooltip:Hide()
  end)
  addon.SetScript(button, "OnClick", function(ctx)
    spec.onClick(ctx)
  end)
  return button
end

-- GetHeaderButtons returns the header's buttons, in order from the screen edge.
---@return NextHeaderButton[]
function panelProto:GetHeaderButtons()
  return {}
end

-- TitleJoin says where the ribbon ends and the title's cloud begins: the window's hard edge, where
-- the body (and its wash) starts, as the title's point it is measured from, how far from that
-- point, and which way is in, across the cloud (1 right, -1 left). Nothing of the ribbon goes on
-- into the window (asked: it should "stop flush with the hard edge of the window").
---@return string point, number x, number inward
function panelProto:TitleJoin()
  local edge = style.PAD + 4
  if self.side == "LEFT" then
    return "RIGHT", edge, -1
  end
  return "LEFT", -edge, 1
end

-- CloudSpan is how far the title's cloud reaches across, from the ribbon's end to Pad past the
-- title's far side, for the title as it is now.
---@return number
function panelProto:CloudSpan()
  return self.title:GetStringWidth() + style.PAD + 4 + style.Cloud.Pad
end

-- LayoutCloud spreads the cloud's puffs across the title as it is now (a share of the way across
-- from the join, the widest as wide as the cloud) and draws them.
function panelProto:LayoutCloud()
  local C = style.Cloud
  local _, joinX, inward = self:TitleJoin()
  local span = self:CloudSpan()
  for i, puff in ipairs(self.cloud.puffs) do
    local spec = C.Puffs[i]
    puff.base = {
      x = joinX + inward * spec.F * span,
      y = spec.Y,
      w = spec.W or span * spec.Wide,
      h = spec.H,
      a = spec.A,
    }
    puff.texture:SetSize(puff.base.w, puff.base.h)
  end
  self:applyCloud()
end

-- applyCloud draws the cloud as it is now: each puff where it rests, risen and brightened by its
-- breath, the whole cloud and the join's puff brightened by the shimmer's swell.
---@private
function panelProto:applyCloud()
  local C, cloud = style.Cloud, self.cloud
  local point = self:TitleJoin()
  local lift = 1 + C.Swell * cloud.swell
  for _, puff in ipairs(cloud.puffs) do
    local breath = 2 * math.pi * cloud.time / puff.period + puff.phase
    local base = puff.base
    puff.texture:SetPoint("CENTER", self.title, point, base.x, base.y + C.Drift * math.sin(breath))
    puff.texture:SetAlpha(base.a * (1 + C.Depth * math.sin(breath * 0.77 + 1)) * lift)
  end
  cloud.join:SetAlpha(C.Join.A + C.JoinSwell * cloud.swell)
end

-- SetCloudSwell brightens the cloud with the shimmer, 0 to 1.
---@param swell number
function panelProto:SetCloudSwell(swell)
  self.cloud.swell = swell
  self:applyCloud()
end

-- BuildHeader makes the title on the body's inner side, the cloud round it (soft puffs of glow,
-- warm where the ribbon ends, no line anywhere, breathing slowly), the ribbon running from the
-- window's hard edge out of the window (a thin gold line with a soft glow, fading out toward its
-- end), the spark that glides in along it, and the kind's buttons along the top from the screen
-- edge.
---@param text string
function panelProto:BuildHeader(text)
  local frame, body = self.frame, self.body
  local left = self.side == "LEFT"
  local C = style.Cloud
  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(style:Font("Title"))
  if left then
    title:SetPoint("TOPRIGHT", body, "TOPRIGHT", -(style.PAD + 4), -style.TITLE_TOP)
    title:SetJustifyH("RIGHT")
  else
    title:SetPoint("TOPLEFT", body, "TOPLEFT", style.PAD + 4, -style.TITLE_TOP)
  end
  title:SetText(text)
  self.title = title

  local point, joinX = self:TitleJoin()
  local function puffOf(sublevel, color)
    local t = frame:CreateTexture(nil, "ARTWORK", nil, sublevel)
    t:SetTexture(style.CLOUD_GLOW)
    t:SetBlendMode("ADD")
    local c = style.Color[color]
    t:SetVertexColor(c[1], c[2], c[3])
    return t
  end
  local cloud = { puffs = {}, time = 0, swell = 0 }
  for i, spec in ipairs(C.Puffs) do
    -- Out of step: each breathes at its own pace, from its own point in the breath.
    table.insert(cloud.puffs, { texture = puffOf(-2, spec.Color), period = 4 + (i % 4) * 0.9, phase = i * 1.7 })
  end
  cloud.join = puffOf(1, C.Join.Color)
  cloud.join:SetSize(C.Join.Size, C.Join.Size)
  cloud.join:SetPoint("CENTER", title, point, joinX, 0)

  self.ribbonLines = {}
  self.ribbonLength = RIBBON_LENGTH
  for _, glow in ipairs(RIBBON_GLOW) do
    local line = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    table.insert(self.ribbonLines, line)
    line:SetSize(RIBBON_LENGTH, 2)
    line:SetColorTexture(1, 1, 1, 1)
    if left then
      line:SetPoint("LEFT", title, point, joinX, glow[1])
      line:SetGradient("HORIZONTAL", style:CreateColor("Gold", glow[2]), style:CreateColor("Gold", 0))
    else
      line:SetPoint("RIGHT", title, point, joinX, glow[1])
      line:SetGradient("HORIZONTAL", style:CreateColor("Gold", 0), style:CreateColor("Gold", glow[2]))
    end
    line:SetBlendMode("ADD")
    if glow[1] == 0 then
      self.ribbon = line
    end
  end

  cloud.driver = CreateFrame("Frame", nil, frame)
  -- A child of the panel: it runs only while the panel shows.
  cloud.driver:SetScript("OnUpdate", function(_, elapsed)
    cloud.time = cloud.time + elapsed
    self:applyCloud()
  end)
  self.cloud = cloud

  local spark = frame:CreateTexture(nil, "OVERLAY")
  spark:SetTexture(style.SPARKLE_TEXTURE)
  spark:SetBlendMode("ADD")
  spark:SetVertexColor(unpack(style.Color.Gold))
  spark:SetSize(SPARK_SIZE, SPARK_SIZE)
  spark:SetPoint("CENTER", self.ribbon, left and "LEFT" or "RIGHT", 0, 0)
  spark:SetAlpha(0)
  self.spark = spark

  self:LayoutCloud()
  self:BuildBraid()
  self:BuildTitleButton()

  self.headerButtons = {}
  for _, spec in ipairs(self:GetHeaderButtons()) do
    local button = self:headerButton(spec)
    self[spec.key] = button
    table.insert(self.headerButtons, button)
  end
  self:LayoutHeader()
end

-- BuildTitleButton makes the title a button (next.md §12): a click chains the bag to its partner,
-- puts it back, or moves both across; the pointer over it lights a soft glow behind the title and
-- says what a click does.
function panelProto:BuildTitleButton()
  local frame, title = self.frame, self.title
  local glow = frame:CreateTexture(nil, "ARTWORK", nil, -3)
  glow:SetTexture(style.CLOUD_GLOW)
  glow:SetBlendMode("ADD")
  local gold = style.Color.Gold
  glow:SetVertexColor(gold[1], gold[2], gold[3])
  glow:SetPoint("TOPLEFT", title, "TOPLEFT", -24, 14)
  glow:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 24, -14)
  glow:SetAlpha(0)
  self.titleGlow = glow

  local button = CreateFrame("Button", nil, frame)
  button:SetPoint("TOPLEFT", title, "TOPLEFT", -8, 6)
  button:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 8, -6)
  button:SetFrameLevel(frame:GetFrameLevel() + 55)
  button:RegisterForClicks("LeftButtonUp")
  addon.SetScript(button, "OnClick", function(ctx)
    chain:Click(ctx, self)
  end)
  addon.SetScript(button, "OnEnter", function()
    self:lightTitle(true)
    GameTooltip:SetOwner(button, self.side == "LEFT" and "ANCHOR_BOTTOMRIGHT" or "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(self.title:GetText())
    GameTooltip:AddLine(chain:Tooltip(self), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  addon.SetScript(button, "OnLeave", function()
    self:lightTitle(false)
    GameTooltip:Hide()
  end)
  self.titleButton = button
end

---@private
---@param on boolean
function panelProto:lightTitle(on)
  local glow = self.titleGlow
  tween:Play(glow, {
    duration = style.Time.Hover,
    from = glow:GetAlpha(),
    to = on and 0.3 or 0,
    onUpdate = function(v)
      glow:SetAlpha(v)
    end,
  })
end

-- BuildBraid makes this bag's half of the braid (next.md §12), hidden until it couples: two strands
-- of additive gold lines, the lights that run along them, and the knot in the middle of the gap.
function panelProto:BuildBraid()
  local frame, C = self.frame, style.Chain
  local gold = style.Color.Gold
  local braid = { strands = { {}, {} }, beads = {}, amount = 0, half = 0, chained = false, phase = 0, time = 0,
    swell = 0 }
  for s = 1, 2 do
    for _ = 1, C.Segments do
      local line = frame:CreateLine(nil, "ARTWORK", nil, 1)
      line:SetColorTexture(1, 1, 1, 1)
      line:SetVertexColor(gold[1], gold[2], gold[3])
      line:SetBlendMode("ADD")
      line:SetThickness(C.Thickness)
      line:Hide()
      table.insert(braid.strands[s], line)
    end
  end
  for _ = 1, C.Beads do
    local bead = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    bead:SetTexture(style.CLOUD_GLOW)
    bead:SetBlendMode("ADD")
    bead:SetVertexColor(1, 0.95, 0.8)
    bead:SetSize(C.BeadSize, C.BeadSize)
    bead:Hide()
    table.insert(braid.beads, bead)
  end
  local knot = frame:CreateTexture(nil, "ARTWORK", nil, 3)
  knot:SetTexture(style.CLOUD_GLOW)
  knot:SetBlendMode("ADD")
  knot:SetVertexColor(gold[1], gold[2], gold[3])
  knot:SetSize(C.KnotSize, C.KnotSize)
  knot:Hide()
  braid.knot = knot
  self.braid = braid
end

-- SetCoupling draws this bag's half of the braid: amount from 0 (straight ribbon, no braid) to 1,
-- half the gap's width, whether it is the chained bag (which shows the knot), and how far the braid
-- has turned. Its ribbon reaches the middle of the gap as it couples, and its sparkles stay on its
-- side.
---@param amount number
---@param half number
---@param chained boolean
---@param phase number
---@param time number
function panelProto:SetCoupling(amount, half, chained, phase, time)
  local braid = self.braid
  braid.amount, braid.half, braid.chained, braid.phase, braid.time = amount, half, chained, phase, time
  self.ribbonLength = RIBBON_LENGTH + (math.min(half, RIBBON_LENGTH) - RIBBON_LENGTH) * amount
  for _, line in ipairs(self.ribbonLines) do
    line:SetWidth(self.ribbonLength)
  end
  local o = self.sparkles.options
  if amount > 0 then
    -- Ribbon sparkles die before the middle of the gap, so none drifts over the other bag.
    self.sparkSpread = half * 0.3
    o.Life = { 1.0, 1.6 }
    o.Speed = { 3, half * 0.5 / 1.6 }
  else
    self.sparkSpread = 70
    o.Life = { 2.0, 3.6 }
    o.Speed = { 22, 64 }
  end
  self:updateEdgeSparkles()
  self:applyBraid()
end

-- applyBraid lays this bag's half of the braid out. A strand's height above the ribbon at d pixels
-- from the body edge is the same function of the distance from the middle of the gap on both bags,
-- so the halves meet: s = (d - half) on the left bag, (half - d) on the right one, turning with the
-- braid; it swells from nothing at the body to the full amplitude in the middle, and the second
-- strand mirrors the first, so they cross. The strand in front (by the turn) is brighter.
---@private
function panelProto:applyBraid()
  local braid, C = self.braid, style.Chain
  local shown = braid.amount > 0 and braid.half > 0
  if not shown then
    for _, strand in ipairs(braid.strands) do
      for _, line in ipairs(strand) do
        line:Hide()
      end
    end
    for _, bead in ipairs(braid.beads) do
      bead:Hide()
    end
    braid.knot:Hide()
    return
  end
  local point, joinX = self:TitleJoin()
  local out, h, n = self:Outward(), braid.half, C.Segments
  local amp = C.Amplitude * braid.amount
  local k = 2 * math.pi / C.Wavelength
  local function at(d, sign)
    local s = (d - h) * out
    return sign * amp * math.sin(math.pi * d / (2 * h)) * math.sin(k * s + braid.phase), s
  end
  for strand = 1, 2 do
    local sign = strand == 1 and 1 or -1
    for i, line in ipairs(braid.strands[strand]) do
      local d0, d1 = h * (i - 1) / n, h * i / n
      local y0 = at(d0, sign)
      local y1, s1 = at(d1, sign)
      line:SetStartPoint(point, self.title, joinX + out * d0, y0)
      line:SetEndPoint(point, self.title, joinX + out * d1, y1)
      local front = sign * math.cos(k * s1 + braid.phase)
      line:SetAlpha(C.Alpha * braid.amount * (1 - C.Depth * (1 - front) / 2))
      line:Show()
    end
  end
  for i, bead in ipairs(braid.beads) do
    local u = (braid.time / C.BeadTime + (i - 1) / #braid.beads) % 1
    local d = u * h
    local y = at(d, i % 2 == 0 and -1 or 1)
    bead:SetPoint("CENTER", self.title, point, joinX + out * d, y)
    bead:SetAlpha(math.sin(math.pi * u) * braid.amount)
    bead:Show()
  end
  local knot = braid.knot
  if braid.chained then
    knot:SetPoint("CENTER", self.title, point, joinX + out * h, at(h, 1))
    knot:SetAlpha(C.KnotAlpha * braid.amount * (1 + C.KnotSwell * braid.swell))
    knot:Show()
  else
    knot:Hide()
  end
end

-- BurstKnot flashes the knot and bursts sparkles from it, as the pair couples.
function panelProto:BurstKnot()
  local braid = self.braid
  tween:Play(braid.knot, {
    duration = style.Time.Couple,
    from = 1,
    to = 0,
    onUpdate = function(v)
      braid.swell = v
      self:applyBraid()
    end,
  })
  self.knotSparkles:Burst(12)
end

-- LayoutHeader lines the shown header buttons up from the screen edge, so a hidden one leaves
-- no gap.
function panelProto:LayoutHeader()
  local left = self.side == "LEFT"
  local body = self.body
  local previous
  for _, button in ipairs(self.headerButtons) do
    button:ClearAllPoints()
    if button:IsShown() then
      if previous == nil then
        if left then
          button:SetPoint("TOPLEFT", body, "TOPLEFT", style.PAD, -(style.TITLE_TOP + 3))
        else
          button:SetPoint("TOPRIGHT", body, "TOPRIGHT", -style.PAD, -(style.TITLE_TOP + 3))
        end
      elseif left then
        button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
      else
        button:SetPoint("RIGHT", previous, "LEFT", -8, 0)
      end
      previous = button
    end
  end
end

-- BuildSearch takes the kind's in-bag search box (the data phase reads its query,
-- searchBox:GetSearchText) out of the theme's hands and draws it flat: a soft pill and a fading
-- underline instead of the template's border.
function panelProto:BuildSearch()
  local sf = self:CreateSearchBox()
  sf.frame:ClearAllPoints()
  sf.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", style.PAD, -style.SEARCH_TOP)
  sf.frame:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -style.PAD, -style.SEARCH_TOP)
  sf.frame:SetHeight(style.SEARCH_HEIGHT)
  for _, key in ipairs({ "Left", "Middle", "Right" }) do
    if sf.textBox[key] then
      sf.textBox[key]:SetAlpha(0)
    end
  end
  local pill = sf.frame:CreateTexture(nil, "BACKGROUND")
  pill:SetAllPoints()
  pill:SetColorTexture(1, 1, 1, 1)
  pill:SetGradient("HORIZONTAL", style:CreateColor("TabSelected", 0.55), style:CreateColor("Tab", 0.35))
  local underline = sf.frame:CreateTexture(nil, "BORDER")
  underline:SetPoint("BOTTOMLEFT", sf.frame, "BOTTOMLEFT", 0, 0)
  underline:SetPoint("BOTTOMRIGHT", sf.frame, "BOTTOMRIGHT", 0, 0)
  underline:SetHeight(1)
  underline:SetColorTexture(1, 1, 1, 1)
  underline:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.5), style:CreateColor("Lavender", 0))
  self.searchBox = sf
  self:UpdateSearchShown()
end

-- CreateSearchBox makes the panel's search box: the kind's in-bag box, out of the theme's hands.
---@return SearchFrame
function panelProto:CreateSearchBox()
  local sf = searchBox:CreateBox(self.kind, self.frame)
  sonata:UnregisterElement("SearchBox", sf.textBox)
  return sf
end

-- UpdateSearchShown shows the search box while in-bag search is on, as the classic bag does.
function panelProto:UpdateSearchShown()
  self.searchBox.frame:SetShown(database:GetInBagSearch() and true or false)
end

-- BuildContent makes the scroll box between the header and the footer and the canvas it holds.
---@param scrollName string
function panelProto:BuildContent(scrollName)
  local scroll = scrollbox:Create(self.frame, scrollName, { Symmetric = true, AutoHideBar = true })
  scroll.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", style.PAD, -style.CONTENT_TOP)
  scroll.frame:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", -style.PAD, style.FOOTER)
  self.scroll = scroll
  self.content = nextContent:Create(scroll.scrollChild)
  scroll:SetChild(self.content)
  self.root = drawable:Create(rootProto, { frame = self.frame, bag = self })

  local emptyText = self.frame:CreateFontString(nil, "OVERLAY")
  emptyText:SetFontObject(style:Font("Footer"))
  emptyText:SetPoint("TOP", scroll.frame, "TOP", 0, -40)
  emptyText:SetText(L:G("Nothing here yet"))
  emptyText:Hide()
  self.emptyText = emptyText
end

-- CreateMoney returns the money frame the footer shows, or nil for none.
---@return Money?
function panelProto:CreateMoney()
  return nil
end

-- BuildFooter puts the free slots on the inner side and the money on the screen-edge side, under
-- a fading line.
function panelProto:BuildFooter()
  local body = self.body
  local left = self.side == "LEFT"
  local line = self.frame:CreateTexture(nil, "ARTWORK")
  line:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", style.PAD, style.FOOTER - 4)
  line:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -style.PAD, style.FOOTER - 4)
  line:SetHeight(1)
  line:SetColorTexture(1, 1, 1, 1)
  if left then
    line:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.05), style:CreateColor("Lavender", 0.35))
  else
    line:SetGradient("HORIZONTAL", style:CreateColor("Lavender", 0.35), style:CreateColor("Lavender", 0.05))
  end

  local freeText = self.frame:CreateFontString(nil, "OVERLAY")
  freeText:SetFontObject(style:Font("Footer"))
  if left then
    freeText:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -(style.PAD + 4), 14)
  else
    freeText:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", style.PAD + 4, 14)
  end
  self.freeText = freeText

  local m = self:CreateMoney()
  if m ~= nil then
    m.frame:SetParent(self.frame)
    m.frame:ClearAllPoints()
    if left then
      m.frame:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", style.PAD, 12)
    else
      m.frame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -style.PAD, 12)
    end
    self.moneyFrame = m
  end
end

-- BuildSparkles makes the three emitters: one out of the title's cloud, one around the title's
-- ribbon, one along the feathered
-- edge, both drifting out of the window.
function panelProto:BuildSparkles()
  local fx = CreateFrame("Frame", nil, self.frame)
  fx:SetAllPoints(self.frame)
  fx:SetFrameLevel(self.frame:GetFrameLevel() + 50)
  local out = self:Outward()
  -- Where the ribbon starts, from the panel's top left: 10 pixels outside the title.
  local _, joinX, inward = self:TitleJoin()
  -- The title's side the join is measured from: its left edge on the backpack, its right on the
  -- bank, from the panel's top left.
  local titleEdge
  local edge
  if self.side == "LEFT" then
    titleEdge = style.BODY_WIDTH - (style.PAD + 4)
    edge = style.BODY_WIDTH
  else
    titleEdge = style.FEATHER + style.PAD + 4
    edge = style.FEATHER
  end
  local ribbonStart = titleEdge + joinX
  local titleMiddle = -(style.TITLE_TOP + 13)
  -- Born in the cloud above or below the title, never over it, most of them near the join.
  self.cloudSparkles = sparkles:Create(fx, {
    Rate = 3, Max = 10, Life = { 1.4, 2.6 }, Size = { 4, 9 }, Speed = { 3, 12 }, Rise = { -3, 5 },
    Wobble = 2, Spin = 1.2, Alpha = 0.7, Direction = out,
    Spawn = function()
      local span = self:CloudSpan()
      local y = 14 + math.random() * 14
      if math.random() < 0.5 then
        y = -y
      end
      return titleEdge + joinX + inward * span * math.random() ^ 1.7, titleMiddle + y
    end,
  })
  self.sparkSpread = 70
  self.sparkles = sparkles:Create(fx, {
    Rate = 8, Max = 28, Life = { 2.0, 3.6 }, Size = { 6, 15 }, Speed = { 22, 64 }, Rise = { -8, 10 },
    Wobble = 4, Spin = 1.5, Direction = out,
    Spawn = function()
      return ribbonStart + out * math.random() * self.sparkSpread, titleMiddle + (math.random() * 2 - 1) * 8
    end,
  })
  -- Along the feathered edge facing the world: the inner one at its screen edge, the far one when
  -- it is not (updateEdgeSparkles).
  local outerEdge = self.side == "LEFT" and 0 or style.WIDTH
  self.edgeOuter = false
  self.edgeSparkles = sparkles:Create(fx, {
    Rate = EDGE_SPARKLE_RATE, Max = 12, Life = { 2.4, 4.2 }, Size = { 4, 9 }, Speed = { 14, 36 }, Rise = { -6, 6 },
    Wobble = 3, Spin = 1, Alpha = 0.6, Direction = out,
    Spawn = function()
      if self.edgeOuter then
        return outerEdge - out * math.random() * 24, -math.random() * fx:GetHeight()
      end
      return edge + out * math.random() * 24, -math.random() * fx:GetHeight()
    end,
  })
  -- From the knot in the middle of the gap, as the pair couples (BurstKnot).
  self.knotSparkles = sparkles:Create(fx, {
    Rate = 0, Max = 16, Life = { 0.5, 1.1 }, Size = { 4, 10 }, Speed = { 12, 40 }, Rise = { -16, 16 },
    Wobble = 2, Spin = 2, Alpha = 0.9, Direction = out,
    Spawn = function()
      return ribbonStart + out * self.braid.half, titleMiddle
    end,
  })
end

-- updateEdgeSparkles puts the edge sparkles on the feathered edge that faces the world: the inner
-- one at the screen edge, the far one beside an anchor or flying (drifting toward the middle of the
-- screen). An anchor's inner edge faces the bag chained to it, so a coupled anchor has none.
---@private
function panelProto:updateEdgeSparkles()
  local o = self.edgeSparkles.options
  local out = self:Outward()
  self.edgeOuter = not self.docked
  o.Direction = self.edgeOuter and -out or out
  o.Rate = (self.braid.amount > 0 and not self.braid.chained) and 0 or EDGE_SPARKLE_RATE
end

-- BuildTabs makes the tab rail down the body's inner edge and lists the kind's tabs.
function panelProto:BuildTabs()
  self.tabs = nextTabs:Create(self.body, self.side)
  self.tabs:SetClickHandler(function(ctx, id, button)
    self:OnTabClicked(ctx, id, button)
  end)
  self.tabs:SetDragHandler(function(ctx, id)
    self:OnTabDragged(ctx, id)
  end)
  -- Chained, the gap between the bags follows their tabs' widths (next.md §12).
  self.tabs:SetResizeHandler(function(ctx)
    chain:Update(ctx)
  end)
  self:RefreshTabs()
end

-- RefreshTabs lists the kind's tabs.
function panelProto:RefreshTabs()
end

-- OnTabClicked runs a click on a tab.
---@param ctx Context
---@param id number
---@param button string
function panelProto:OnTabClicked(ctx, id, button)
  local _, _, _ = ctx, id, button
end

-- OnTabDragged runs a drag from, or a drop on, a draggable tab.
---@param ctx Context
---@param id number
function panelProto:OnTabDragged(ctx, id)
  local _, _ = ctx, id
end

---@return number
function panelProto:GetCurrentTabID()
  if database:GetGroupsEnabled(self.kind) then
    return database:GetActiveGroup(self.kind) or 1
  end
  return 1
end

-- Watch wires the panel to the rest of the addon: its show and hide, cooldowns (for a kind that
-- watches them), drops, the in-bag search setting, and the kind's own events (WatchKind).
function panelProto:Watch()
  local frame = self.frame
  addon.SetScript(frame, "OnShow", function(ctx)
    self:OnCooldown(ctx)
  end)
  addon.SetScript(frame, "OnHide", function(ctx)
    self:OnHidden(ctx)
  end)
  addon.SetScript(frame, "OnReceiveDrag", function()
    self:PlaceCursorItem()
  end)
  addon.SetScript(frame, "OnMouseUp", function(_, _, button)
    if button == "LeftButton" then
      self:PlaceCursorItem()
    end
  end)
  if self.watchesCooldowns then
    events:BucketEvent("BAG_UPDATE_COOLDOWN", function(ctx)
      self:OnCooldown(ctx)
    end, function()
      return self:IsShown()
    end)
  end
  events:RegisterMessage("search/SetInFrame", function(ctx)
    self:UpdateSearchShown()
    events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
  end)
  self:WatchKind()
end

-- WatchKind registers the kind's own events and messages.
function panelProto:WatchKind()
end

-- playShimmer glides the spark in along the ribbon from its far end, easing to rest where the
-- ribbon ends at the window's edge, then lets it grow and fade there while the cloud swells and
-- settles, every ShimmerEvery seconds. Everything eases in and out: nothing jumps.
---@private
function panelProto:playShimmer()
  local spark = self.spark
  local out = self:Outward()
  local inner = self.side == "LEFT" and "LEFT" or "RIGHT"
  local size = SPARK_SIZE
  tween:Play(spark, {
    duration = style.Time.Shimmer,
    delay = math.max(0, style.Time.ShimmerEvery - style.Time.Shimmer - style.Time.Absorb),
    from = 0,
    to = 1,
    ease = "linear",
    onUpdate = function(t)
      local p = tween.Ease.inOutSine(t)
      spark:ClearAllPoints()
      spark:SetPoint("CENTER", self.ribbon, inner, out * (1 - p) * self.ribbonLength, 0)
      spark:SetSize(size, size)
      spark:SetAlpha(math.sin(math.pi * t / 2))
      self:SetCloudSwell(t > 0.6 and ((t - 0.6) / 0.4) ^ 2 or 0)
    end,
    onDone = function()
      tween:Play(spark, {
        duration = style.Time.Absorb,
        from = 0,
        to = 1,
        ease = "linear",
        onUpdate = function(t)
          local grown = size + SPARK_GROWTH * (1 - (1 - t) ^ 2)
          spark:SetSize(grown, grown)
          spark:SetAlpha((1 - t) ^ 1.5)
          self:SetCloudSwell((1 - t) ^ 2)
        end,
        onDone = function()
          if self.frame:IsShown() and not self.closing then
            self:playShimmer()
          end
        end,
      })
    end,
  })
end

-- OnShowing runs as the panel starts to open, before it draws.
---@param ctx Context
function panelProto:OnShowing(ctx)
  local _ = ctx
end

-- Show slides the panel in from its edge, drawing a draw it kept while hidden (with slotInfo when
-- given), fading its sections in and starting its sparkles. It returns whether it drew. onShown
-- runs once the panel has slid into place: at once when it is open, when a slide still playing
-- ends, never for a slide closing or Escape cut short. A bank open loads the bank then
-- (refresh-scheduler.md §11).
---@param ctx Context
---@param slotInfo? SlotInfo
---@param onShown? fun()
---@return boolean drew
function panelProto:Show(ctx, slotInfo, onShown)
  if self.frame:IsShown() and not self.closing then
    if onShown ~= nil then
      if self.onShown ~= nil then
        table.insert(self.onShown, onShown)
      else
        onShown()
      end
    end
    return false
  end
  self.onShown = { onShown }
  local sliding = self.frame:IsShown()
  self.closing = false
  PlaySound(self.openSound)
  self:OnShowing(ctx)
  self.frame:Show()
  -- Where it rests: at its edge, or beside its open anchor, coming in from behind the anchor or
  -- from its own edge (next.md §12).
  local to = self:RestOffset()
  local anchor = chain:AnchorOf(self)
  local from = self:HiddenOffset()
  if sliding then
    from = self.offset
  elseif anchor ~= nil then
    from = chain:EntranceOffset(self)
    if style.Chain.Enter ~= "edge" then
      self.frame:SetFrameLevel(math.max(1, anchor.frame:GetFrameLevel() - 100))
    end
  end
  self.target = to
  self:setOffset(from)
  self:SetDocked(to == 0)
  local drew = false
  if self.drawPendingOnShow then
    self.drawPendingOnShow = false
    local data = slotInfo or self.lastSlotInfo
    if data then
      self.opening = true
      self:Draw(ctx, data, function() end)
      self.opening = false
      drew = true
    end
  end
  local entering = to ~= 0
  tween:Play(self, {
    duration = entering and style.Time.Enter or style.Time.Open,
    from = from,
    to = to,
    ease = entering and "outCubic" or "outBack",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self:finishShowing()
      chain:Arrived(self)
    end,
  })
  self.content:Cascade(true, style.Time.OpenCascadeDelay)
  self.sparkles:Start()
  self.edgeSparkles:Start()
  self.cloudSparkles:Start()
  self:playShimmer()
  addon.TriggerItemContextChanged()
  chain:Update(ctx)
  return drew
end

-- OnSlidOut runs when the panel has slid off the screen and hidden.
---@param ctx Context
function panelProto:OnSlidOut(ctx)
  local _ = ctx
end

-- Hide slides the panel out to its edge, then hides it.
---@param ctx Context
function panelProto:Hide(ctx)
  if not self.frame:IsShown() or self.closing then
    return
  end
  addon.ForceHideBlizzardBags()
  PlaySound(self.closeSound)
  self.closing = true
  self.target = self:HiddenOffset()
  chain:Update(ctx)
  tween:Play(self, {
    duration = style.Time.Close,
    from = self.offset,
    to = self:HiddenOffset(),
    ease = "inCubic",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self.closing = false
      self.frame:Hide()
      addon.TriggerItemContextChanged()
      self:OnSlidOut(ctx)
    end,
  })
end

---@param ctx Context
function panelProto:Toggle(ctx)
  if self:IsShown() and not self.closing then
    self:Hide(ctx)
  else
    self:Show(ctx)
  end
end

---@return boolean
function panelProto:IsShown()
  return self.frame:IsShown()
end

-- IsClosing says the panel is sliding out: closed, though its frame still shows.
---@return boolean
function panelProto:IsClosing()
  return self.closing
end

---@return string
function panelProto:GetName()
  return self.frame:GetName()
end

---@param text string
function panelProto:SetTitle(text)
  self.title:SetText(text)
  self:LayoutCloud()
end

-- OnHidden runs on every way the panel hides (the slide's end, Escape hiding it at once): the
-- slide, the sparkles and the spark stop, and OnClosed runs.
---@param ctx Context
function panelProto:OnHidden(ctx)
  nextDrag:PanelHidden(self)
  self.closing = false
  tween:Stop(self)
  tween:Stop(self.spark)
  self.spark:SetAlpha(0)
  self.spark:SetSize(SPARK_SIZE, SPARK_SIZE)
  self:SetCloudSwell(0)
  self.sparkles:Stop()
  self.edgeSparkles:Stop()
  self.cloudSparkles:Stop()
  self.knotSparkles:Stop()
  chain:Update(ctx)
  self:OnClosed(ctx)
end

-- OnClosed expires Recent Items, and refreshes once when any expired or gaps are held, while the
-- panel is hidden (recent-items.md §3). A hide while the panel is still shown (a parent hid) does
-- nothing.
---@param ctx Context
function panelProto:OnClosed(ctx)
  if self.frame:IsShown() then
    return
  end
  local expired = items:ExpireRecentItems(self.kind)
  if expired or self.drawOnClose then
    self.drawOnClose = false
    self:Refresh(ctx)
  end
end

-- Deactivate switches the panel off with BetterBags Next (next.md §11): it hides at once (its
-- OnHide still runs its close work) and lets go of every button it drew.
---@param ctx Context
function panelProto:Deactivate(ctx)
  if self.frame:IsShown() then
    self.frame:Hide()
  end
  self:Wipe(ctx)
end

-- Activate catches the panel up when BetterBags Next is switched back on: what its handlers would
-- have done while they were off (the search box's setting, the tabs, the money).
---@param ctx Context
function panelProto:Activate(ctx)
  local _ = ctx
  self:UpdateSearchShown()
  self:RefreshTabs()
  if self.moneyFrame then
    self.moneyFrame:Update()
  end
end

-- Refresh recalculates the kind's bag from what was last read.
---@param ctx Context
function panelProto:Refresh(ctx)
  local _ = ctx
end

-- Draw binds the active tab's data and lays it out, claiming the buttons it draws and releasing
-- the ones the last draw drew that this one did not. A draw while hidden waits for Show.
---@param ctx Context
---@param slotInfo SlotInfo
---@param callback? fun()
function panelProto:Draw(ctx, slotInfo, callback)
  if not self.frame:IsShown() then
    self.lastSlotInfo = slotInfo
    self.drawPendingOnShow = true
    if callback then
      callback()
    end
    return
  end
  if self.claims then
    for item in pairs(self.claims) do
      self.drawnButtons[item] = true
    end
  end
  local claims = {}
  self.claims = claims
  self.content:Bind(ctx, slotInfo, self:GetCurrentTabID(), claims)
  for item in pairs(self.drawnButtons) do
    if not claims[item] then
      item:Release(ctx)
    end
  end
  self.drawnButtons = claims
  self.claims = nil
  self.lastSlotInfo = slotInfo
  render:RenderNow(self.root, { ctx = ctx })
  self.freeText:SetText(format(L:G("%d free slots"), self.content.freeTotal))
  -- Data that was never read (the bank before its first read after it opens) has no tabs.
  self.emptyText:SetText(slotInfo.tabs == nil and L:G("Loading...") or L:G("Nothing here yet"))
  self.emptyText:SetShown(#self.content.order == 0)
  if not self.opening then
    self.content:Cascade(self.tabChanged)
  end
  self.tabChanged = false
  if callback then
    callback()
  end
end

---@param ctx Context
---@param results table<string, boolean>
function panelProto:Search(ctx, results)
  for slotkey, button in pairs(self.content.buttons) do
    if not button.isFreeSlot then
      button:UpdateSearch(ctx, results[slotkey])
    end
  end
end

---@param ctx Context
function panelProto:ResetSearch(ctx)
  for _, button in pairs(self.content.buttons) do
    if not button.isFreeSlot then
      button:UpdateSearch(ctx, true)
    end
  end
end

-- ToggleSearch opens the panel and puts the cursor in its search box, or lets go of the box.
---@param ctx Context
function panelProto:ToggleSearch(ctx)
  local textBox = self.searchBox.textBox
  if self:IsShown() and not self.closing and textBox:HasFocus() then
    textBox:ClearFocus()
    return
  end
  self:Show(ctx)
  if self.searchBox.frame:IsShown() then
    textBox:SetFocus()
  end
end

-- OnCooldown refreshes the cooldown of every item button it shows, and returns how many it
-- checked and how many it applied Blizzard's update to.
---@param ctx Context
---@return number checked, number applied
function panelProto:OnCooldown(ctx)
  if not self.watchesCooldowns or not self:IsShown() then
    return 0, 0
  end
  local checked, applied = 0, 0
  for _, button in pairs(self.content.buttons) do
    local data = not button.isFreeSlot and button:GetItemData() or nil
    if data then
      checked = checked + 1
      local reason = button:UpdateCooldown(ctx, data, true)
      if reason ~= "unchanged" and reason ~= "empty" then
        applied = applied + 1
      end
    end
  end
  return checked, applied
end

---@param ctx Context
function panelProto:Sort(ctx)
  local _ = ctx
end

-- PlaceCursorItem puts the item on the cursor into a free slot of the kind's bags (the bank's
-- active bank type).
---@return string result What CursorPlacement:PlaceCursorItem did.
function panelProto:PlaceCursorItem()
  return cursorPlacement:PlaceCursorItem(self.kind, self.bankTab)
end

-- Wipe tears the drawing down: every section and every button drawn is released.
---@param ctx Context
function panelProto:Wipe(ctx)
  self.content:Release()
  for _, drawn in ipairs({ self.drawnButtons, self.claims or {} }) do
    for item in pairs(drawn) do
      item:Release(ctx)
    end
  end
  self.drawnButtons = {}
  self.claims = nil
end
