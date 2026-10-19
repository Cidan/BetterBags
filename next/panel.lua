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
-- The panel's frame level in the HIGH strata; a chained bag coming in from beneath its anchor is
-- lowered below it for the way, and put back here once in place.
local PANEL_LEVEL = 500
-- The spark gliding in along it, and how much it grows as it settles into the title's cloud.
local SPARK_SIZE = 26
local SPARK_GROWTH = 18
-- The ribbon's glow: thin lines above and below it, fainter the further out.
local RIBBON_GLOW = { { 0, 0.9 }, { 2, 0.35 }, { -2, 0.35 }, { 4, 0.15 }, { -4, 0.15 }, { 6, 0.06 }, { -6, 0.06 } }

---@alias NextSide "RIGHT"|"LEFT"

-- Where a panel is, part way between its sizes: its body's top left (in UIParent's units) and height,
-- its beam's length, its feathers' alpha (full: the inner one; outer: the far one, away from its
-- screen edge) and its small border's.
---@class (exact) NextMorphPoint
---@field x number
---@field y number
---@field h number
---@field ribbon number
---@field full number
---@field outer number
---@field edge number

-- A switch between sizes (panelProto:Morph): the tween's key, where the panel is now, and what puts
-- it at its end at once.
---@class (exact) NextMorph
---@field at NextMorphPoint
---@field finish fun()

-- A bag's half of the braid two coupled bags' ribbons twist into (next.md §12): two strands of
-- lines from its body edge to the middle of the gap, lights running along them, and the knot in the
-- middle (shown by the chained bag).
---@class (exact) NextBraid
---@field layer Frame Above the panel, where the braid is drawn.
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
---@field waiting boolean Out of sight beyond its anchor's edge, waiting for the anchor to open.
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
---@field feather Texture
---@field wash Texture The faint color at the top of the body.
---@field dropGlow Texture Lit while a section from the other bag would drop here (next.md §7).
---@field washColor number[] The wash's color now.
---@field title FontString
---@field label string What the bag is called ("Backpack", "Bank", "Vendor"): never secret, unlike a
--- vendor's title in an instance, so tooltips name the bag by it.
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
---@field size NextSize "full" height on its screen edge, or "small" and movable (docs/next-small-mode.md).
---@field edges Texture[] A small panel's 1-pixel lavender edge, all round.
---@field mover Frame A small panel's title row, dragged to move it.
---@field placeX? number A small panel's place: its top left in UIParent's units.
---@field placeY? number
---@field moving? boolean The player is dragging the small panel.
---@field morph? NextMorph Set while it glides to its new size (Morph).
---@field morphFrom? NextMorphPoint Where its body was as it switched.
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
    Height = math.max(1, self.bag:Height() - style.CONTENT_TOP - style.FOOTER),
  }
end

---@return RenderResult
function rootProto:Render()
  return { Width = self.bag:Width(), Height = self.bag:Height() }
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
  p.label = opts.title
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
  p.size = database:GetNextSize()
  p:BuildPanel(opts.name)
  p:BuildMover()
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
  p:ApplyGeometry()
  return p
end

-- SetSize switches every BetterBags Next panel to a size (docs/next-small-mode.md), saved: a chained
-- pair lets go of its braid at once, a panel not shown takes the size at once, and a shown one
-- morphs to it once every panel has it (where a full panel rests depends on its partner's size). It
-- returns what it did, for profiler traces: "switched", or "same" when it is the size already.
---@param ctx Context
---@param size NextSize
---@return string
function nextPanel:SetSize(ctx, size)
  local _ = ctx
  if database:GetNextSize() == size then
    return "same"
  end
  database:SetNextSize(size)
  chain:LetGo()
  local morphing = {}
  for _, panel in ipairs(chain:Panels()) do
    if panel:PrepareResize(size) then
      table.insert(morphing, panel)
    end
  end
  for _, panel in ipairs(morphing) do
    panel:Morph()
  end
  for _, panel in ipairs(chain:Panels()) do
    panel:UpdateSizeButton()
  end
  return "switched"
end

-- outward is the direction from the panel toward the middle of the screen: left (-1) for the
-- panel on the right, right (1) for the panel on the left.
---@return number
function panelProto:Outward()
  return self.side == "LEFT" and 1 or -1
end

-- HiddenOffset is where the panel is when it has slid off the screen; a small panel, a short way
-- toward its edge side from its place, faded out.
---@return number
function panelProto:HiddenOffset()
  if self:IsSmall() then
    return -self:Outward() * style.Small.Slide
  end
  return -self:Outward() * (style.WIDTH + style.OVERREACH)
end

-- setOffset puts the panel x from where it rests: from its screen edge, top to bottom; a small
-- panel, x along from its place, fading as it leaves it (its slide in and out).
---@private
---@param x number
function panelProto:setOffset(x)
  -- Anything that places the panel while it glides to a new size ends the glide first.
  self:endMorph()
  self.offset = x
  local frame = self.frame
  frame:ClearAllPoints()
  if self:IsSmall() then
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.placeX + x, self.placeY)
    frame:SetAlpha(1 - math.min(1, math.abs(x) / style.Small.Slide))
    return
  end
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
  if self:IsSmall() then
    -- A small panel is never at its screen edge: its fill is its frame.
    self.docked = false
    return
  end
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
  local from = self.offset
  if self:BeyondFarEdge() then
    -- Out of sight beyond its anchor's edge (waiting, or before its entrance): it comes from its
    -- own edge instead of crossing the screen.
    from = self:HiddenOffset()
  end
  self.waiting = false
  self.target = to
  if to ~= 0 then
    self:SetDocked(false)
  end
  tween:Play(self, {
    duration = style.Time.Fly,
    from = from,
    to = to,
    ease = "inOutCubic",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self.frame:SetFrameLevel(PANEL_LEVEL)
      if to == 0 then
        self:SetDocked(true)
      end
      self:finishShowing()
      chain:Arrived(self)
    end,
  })
end

-- Hold stops the panel where it is (chain:Holds: its anchor is sliding out).
function panelProto:Hold()
  tween:Stop(self)
  self.target = self.offset
end

-- PlaceAt puts the panel at an offset at once (the screen changed).
---@param to number
function panelProto:PlaceAt(to)
  tween:Stop(self)
  self.frame:SetFrameLevel(PANEL_LEVEL)
  self.target = to
  self:setOffset(to)
  self:SetDocked(to == 0)
  self:finishShowing()
end

-- BeyondFarEdge says the panel is out of sight beyond the far edge of the screen (its near side
-- past it): where a chained bag waits for its anchor and comes in from (next.md §12).
---@return boolean
function panelProto:BeyondFarEdge()
  return self.offset * self:Outward() >= UIParent:GetWidth()
end

-- moveIn brings the panel in from an offset to one, after delay seconds, its sections cascading
-- in as it comes; once in place it is at its own level again, says it has finished showing, and
-- the chain couples it.
---@private
---@param from number
---@param to number
---@param duration number
---@param ease NextEase
---@param delay number
function panelProto:moveIn(from, to, duration, ease, delay)
  self:setOffset(from)
  tween:Play(self, {
    duration = duration,
    delay = delay,
    from = from,
    to = to,
    ease = ease,
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self.frame:SetFrameLevel(PANEL_LEVEL)
      self:finishShowing()
      chain:Arrived(self)
    end,
  })
  self.content:Cascade(true, delay + style.Time.OpenCascadeDelay)
end

-- Enter brings a chained bag in beside its anchor (next.md §12): from out of sight beyond the
-- anchor's edge, beneath the anchor, after delay (EntranceDelay), falling into place.
---@param to number
---@param delay number
function panelProto:Enter(to, delay)
  self.waiting = false
  self.target = to
  self:SetDocked(false)
  local anchor = chain:AnchorOf(self)
  if anchor ~= nil then
    self.frame:SetFrameLevel(math.max(1, anchor.frame:GetFrameLevel() - 100))
  end
  self:moveIn(chain:EntranceOffset(self), to, style.Time.Enter, "outBackSoft", delay)
end

-- WaitForAnchor holds a chained bag out of sight beyond its anchor's edge while the anchor is
-- about to open (chain:WaitsForAnchor); the chain brings it in once the anchor opens. If the anchor
-- has not opened within AnchorWait, it opens alone, from its own edge.
function panelProto:WaitForAnchor()
  self.waiting = true
  local at = chain:EntranceOffset(self)
  self.target = at
  self:SetDocked(false)
  self:setOffset(at)
  tween:Play(self, {
    duration = style.Chain.AnchorWait,
    from = at,
    to = at,
    ease = "linear",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self.waiting = false
      self.target = 0
      self:SetDocked(true)
      self:moveIn(self:HiddenOffset(), 0, style.Time.Open, "outBack", 0)
    end,
  })
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
  frame:SetFrameLevel(PANEL_LEVEL)
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:Hide()
  self.frame = frame
  -- Its geometry (the frame's size and place, the body, the fill, the feather) is its size's
  -- (ApplyGeometry).
  self.body = CreateFrame("Frame", nil, frame)

  local fill = frame:CreateTexture(nil, "BACKGROUND")
  local feather = frame:CreateTexture(nil, "BACKGROUND")
  local wash = frame:CreateTexture(nil, "BORDER")
  feather:SetColorTexture(1, 1, 1, 1)
  fill:SetColorTexture(unpack(style.Color.Body))
  self.fill = fill
  self.feather = feather
  self.wash = wash

  -- The far edge feathered out toward the middle of the screen, while not at its edge (SetDocked).
  local outerFeather = frame:CreateTexture(nil, "BACKGROUND")
  outerFeather:SetWidth(style.Chain.OuterFeather)
  outerFeather:SetColorTexture(1, 1, 1, 1)
  if left then
    outerFeather:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    outerFeather:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
  else
    outerFeather:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    outerFeather:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
  end
  outerFeather:Hide()
  self.outerFeather = outerFeather
  self:paintFeathers(1, 1)
  self.docked = true

  wash:SetHeight(260)
  wash:SetColorTexture(1, 1, 1, 1)
  wash:SetBlendMode("ADD")
  self:paintWash(style.Color.Wash)

  -- A small panel's 1-pixel lavender edge round its body, so it reads against the world. On the body,
  -- not the frame: a full panel's frame reaches over its feather, and a growing panel has the full
  -- panel's frame while its edge fades (Morph).
  self.edges = {}
  local l = style.Color.Lavender
  local body = self.body
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local edge = frame:CreateTexture(nil, "BORDER", nil, 1)
    edge:SetColorTexture(1, 1, 1, 1)
    edge:SetVertexColor(l[1], l[2], l[3], style.Small.Edge)
    if side == "TOP" or side == "BOTTOM" then
      edge:SetPoint(side .. "LEFT", body, side .. "LEFT", 0, 0)
      edge:SetPoint(side .. "RIGHT", body, side .. "RIGHT", 0, 0)
      edge:SetHeight(1)
    else
      edge:SetPoint("TOP" .. side, body, "TOP" .. side, 0, 0)
      edge:SetPoint("BOTTOM" .. side, body, "BOTTOM" .. side, 0, 0)
      edge:SetWidth(1)
    end
    edge:Hide()
    table.insert(self.edges, edge)
  end

  local glow = frame:CreateTexture(nil, "BORDER")
  glow:SetAllPoints(self.body)
  glow:SetColorTexture(1, 1, 1, 1)
  glow:SetVertexColor(unpack(style.Color.Lavender))
  glow:SetBlendMode("ADD")
  glow:SetAlpha(0)
  glow:Hide()
  self.dropGlow = glow
end

-- paintFeathers draws the feathers at a strength, 0 to 1: the inner one, from the body's color at the
-- body's inner side out to nothing, and the far one, toward the middle of the screen. A gradient is
-- the texture's vertex colors (warcraft.wiki.gg TextureBase:SetGradient; Blizzard puts a gradient's
-- alpha in its colors, Blizzard_NamePlates.lua), so a feather fades by its gradient's alpha, as the
-- wash does (paintWash). Faded with SetAlpha instead, they did not fade at all in game.
---@param inner number
---@param outer number
function panelProto:paintFeathers(inner, outer)
  local a = style.Color.Body[4]
  local function paint(texture, strength, solidOnLeft)
    local solid, clear = style:CreateColor("Body", a * strength), style:CreateColor("Body", 0)
    if solidOnLeft then
      texture:SetGradient("HORIZONTAL", solid, clear)
    else
      texture:SetGradient("HORIZONTAL", clear, solid)
    end
  end
  local left = self.side == "LEFT"
  paint(self.feather, inner, left)
  paint(self.outerFeather, outer, not left)
end

-- IsSmall says the panel is small (docs/next-small-mode.md): a movable panel, its body alone.
---@return boolean
function panelProto:IsSmall()
  return self.size == "small"
end

-- SmallHeight is a small panel's height on this screen: a share of the screen's, in whole units.
---@return number
function panelProto:SmallHeight()
  return math.floor(UIParent:GetHeight() * style.Small.Height)
end

-- Height is how tall the panel is: the screen's height, or a small panel's.
---@return number
function panelProto:Height()
  if self:IsSmall() then
    return self:SmallHeight()
  end
  return UIParent:GetHeight()
end

-- Width is how wide the panel's frame is: its body and its feather, or a small panel's body alone.
---@return number
function panelProto:Width()
  if self:IsSmall() then
    return style.BODY_WIDTH
  end
  return style.WIDTH
end

-- BodyLeft is where the body starts, from the frame's left edge: past the feather on the full
-- backpack (its feather is on its left), else at the frame's edge.
---@return number
function panelProto:BodyLeft()
  if self.side == "RIGHT" and not self:IsSmall() then
    return style.FEATHER
  end
  return 0
end

-- RibbonBase is the ribbon's length while the panel is not coupled: a small panel's beam is
-- shorter. SparkSpreadBase is how far out along it the ribbon's sparkles are born.
---@return number
function panelProto:RibbonBase()
  return self:IsSmall() and style.Small.Ribbon or RIBBON_LENGTH
end

---@return number
function panelProto:SparkSpreadBase()
  return self:IsSmall() and style.Small.SparkSpread or 70
end

-- clampPlace keeps a small panel's place (its top left) on the screen.
---@private
---@param x number
---@param y number
---@return number x, number y
function panelProto:clampPlace(x, y)
  x = math.max(0, math.min(UIParent:GetWidth() - style.BODY_WIDTH, x))
  y = math.max(self:SmallHeight(), math.min(UIParent:GetHeight(), y))
  return x, y
end

-- SmallPlace is where a small panel sits: chained (docs/next-small-mode.md), beside its anchor where
-- the anchor is now (LivePlace); else where the player left it, else a margin in from its own screen
-- edge (the backpack's right, a companion's left), centered; on the screen either way.
---@return number x, number y
function panelProto:SmallPlace()
  local anchor = chain:SmallAnchorOf(self)
  if anchor ~= nil then
    return self:clampPlace(chain:ChainedPlace(self, anchor, anchor:LivePlace()))
  end
  local x, y = database:GetNextSmallPlace(self.kind)
  if x == nil then
    y = (UIParent:GetHeight() + self:SmallHeight()) / 2
    if self.side == "RIGHT" then
      x = UIParent:GetWidth() - style.BODY_WIDTH - style.Small.Margin
    else
      x = style.Small.Margin
    end
  end
  return self:clampPlace(x, y)
end

-- LivePlace is where a small panel's top left is now: under the mouse while the player drags it, else
-- its place.
---@return number x, number y
function panelProto:LivePlace()
  if self.moving then
    local x, y = self.frame:GetLeft(), self.frame:GetTop()
    if x ~= nil and y ~= nil then
      return x, y
    end
  end
  return self:SmallPlace()
end

-- SmallLeft is where a shown small panel's left edge is now: under the mouse while dragged, else its
-- place plus its slide.
---@return number
function panelProto:SmallLeft()
  if self.moving then
    local x = self.frame:GetLeft()
    if x ~= nil then
      return x
    end
  end
  return self.placeX + self.offset
end

-- GlideTo glides a shown small panel from where it is to a new place (chaining it beside its partner,
-- or its spot beside its anchor moving), then the chain braids it if it is in place.
---@param x number
---@param y number
function panelProto:GlideTo(x, y)
  local fromX, fromY = self.placeX + self.offset, self.placeY
  self.placeX, self.placeY = x, y
  self.offset = 0
  self.target = 0
  local frame = self.frame
  tween:Play(self, {
    duration = style.Time.Glide,
    from = 0,
    to = 1,
    ease = "outCubic",
    onUpdate = function(t)
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", fromX + (x - fromX) * t, fromY + (y - fromY) * t)
      frame:SetAlpha(1)
    end,
    onDone = function()
      self:setOffset(0)
      chain:Arrived(self)
    end,
  })
end

-- ApplyGeometry shapes the panel for its size and puts it where it is for that size (its offset).
-- Full (next.md §3): the frame on its screen edge, top to bottom, the body inside its feathered
-- inner edge, no clicks taken over the feather, the fill and the wash reaching past the screen edge
-- while docked. Small (docs/next-small-mode.md): the frame is the body, a share of the screen tall,
-- at its place, edged in faint lavender, moved by its title row, its beam shorter.
function panelProto:ApplyGeometry()
  local small = self:IsSmall()
  local frame, body = self.frame, self.body
  local bodyLeft = self:BodyLeft()
  local bodyRight = (not small and self.side == "LEFT") and style.FEATHER or 0
  frame:SetWidth(self:Width())
  if small then
    frame:SetHeight(self:SmallHeight())
  end
  frame:SetHitRectInsets(bodyLeft, bodyRight, 0, 0)
  body:ClearAllPoints()
  body:SetPoint("TOPLEFT", frame, "TOPLEFT", bodyLeft, 0)
  body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -bodyRight, 0)
  local fill, wash = self.fill, self.wash
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", frame, "TOPLEFT", bodyLeft, 0)
  fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -bodyRight, 0)
  wash:ClearAllPoints()
  wash:SetPoint("TOPLEFT", frame, "TOPLEFT", bodyLeft, 0)
  wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -bodyRight, 0)
  self.feather:SetShown(not small)
  if not small then
    self.feather:ClearAllPoints()
    self:growFeather(0)
  end
  for _, edge in ipairs(self.edges) do
    edge:SetShown(small)
  end
  self.ribbonLength = self:RibbonBase()
  for _, line in ipairs(self.ribbonLines) do
    line:SetWidth(self.ribbonLength)
  end
  self.sparkSpread = self:SparkSpreadBase()
  frame:SetMovable(small)
  frame:SetClampedToScreen(small)
  self.mover:SetShown(small)
  if small then
    self.placeX, self.placeY = self:SmallPlace()
    self.docked = false
    self.outerFeather:Hide()
  else
    frame:SetAlpha(1)
    -- The fill and the wash reach past the screen edge while it rests there (SetDocked).
    self:SetDocked((self.offset or 0) == 0)
  end
  self:setOffset(self.offset or 0)
end

-- FitSmall sizes a small panel for the screen as it is now and puts it at its place, kept on the
-- screen: on opening (the screen may have changed while it was closed) and when the screen changes.
-- Its content is laid out again when its height changed.
function panelProto:FitSmall()
  local height = self:SmallHeight()
  local changed = self.frame:GetHeight() ~= height
  self.frame:SetHeight(height)
  self.placeX, self.placeY = self:SmallPlace()
  self:setOffset(self.offset)
  if changed then
    render:Invalidate(self.root)
  end
end

-- BodyRect is where the body is on screen for the panel's size and offset now: its top left (in
-- UIParent's units) and its height. Its width is BODY_WIDTH at both sizes.
---@return number x, number y, number height
function panelProto:BodyRect()
  if self:IsSmall() then
    return self.placeX + self.offset, self.placeY, self:SmallHeight()
  end
  local left = self.offset
  if self.side == "RIGHT" then
    left = UIParent:GetWidth() - style.WIDTH + self.offset
  end
  return left + self:BodyLeft(), UIParent:GetHeight(), UIParent:GetHeight()
end

-- PrepareResize switches the panel's size (nextPanel:SetSize). Not shown (a closing one finishes
-- closing first), it takes the size at once and lays its content out for it. Shown, it finishes
-- what it was doing, keeps where its body is now, and morphs once every panel has its size (Morph).
-- It returns whether it morphs.
---@param size NextSize
---@return boolean
function panelProto:PrepareResize(size)
  if self.closing then
    tween:Stop(self, true)
  end
  if not self.frame:IsShown() then
    -- A glide still running (Escape closed it mid-glide) ends as ApplyGeometry places it (setOffset).
    self.size = size
    self.offset = self:HiddenOffset()
    self:ApplyGeometry()
    render:Invalidate(self.root)
    return false
  end
  if self.morph ~= nil then
    -- Switched back while it glides: it turns around from where it is.
    self.morphFrom = self.morph.at
    tween:Stop(self.morph)
    self.morph = nil
  else
    -- An opening slide or a flight ends where it was going: its end says the panel has shown.
    tween:Stop(self, true)
    local x, y, h = self:BodyRect()
    local small = self:IsSmall()
    self.morphFrom = {
      x = x, y = y, h = h, ribbon = self.ribbonLength,
      full = small and 0 or 1,
      outer = (not small and not self.docked) and 1 or 0,
      edge = small and 1 or 0,
    }
  end
  self.size = size
  return true
end

-- Morph switches the panel to its new size in two steps (asked: a "2 step" animation, so the feather
-- never looks "spilled out" past the border). The glide: the body glides from where it was
-- (PrepareResize) to where it rests at its new size, its top left and its height (its width is the
-- same at both), the feathers fading out or in and the beam shortening or growing. The border: the
-- small panel's edge fades in once it has shrunk, or out before it grows. Its parts are the new
-- size's from the start (ApplyGeometry), the frame anchored by its top left and sized as it goes, so
-- the body only moves and stretches; nothing reaches past the screen edge on the way. A step with
-- nothing to do (turned around) is skipped. The content is laid out once, at the end.
function panelProto:Morph()
  local from = self.morphFrom --[[@as NextMorphPoint]]
  self.morphFrom = nil
  local small = self:IsSmall()
  self.offset = small and 0 or chain:RestOffset(self)
  self.target = self.offset
  self:ApplyGeometry()
  local tx, ty, th = self:BodyRect()
  local toRibbon = self.ribbonLength
  self:SetDocked(false)
  local frame, feather, edges, outerFeather = self.frame, self.feather, self.edges, self.outerFeather
  feather:Show()
  -- A full panel away from its screen edge has a far feather too (SetDocked): it fades with the near
  -- one (at.outer), and the switch's end decides whether it shows (ApplyGeometry).
  outerFeather:Show()
  if small then
    feather:ClearAllPoints()
    if self.side == "LEFT" then
      feather:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
      feather:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
    else
      feather:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
      feather:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    end
    feather:SetWidth(style.FEATHER)
  end
  for _, edge in ipairs(edges) do
    edge:Show()
  end
  local bodyLeft, width = self:BodyLeft(), self:Width()
  local toFull = small and 0 or 1
  local at = { x = from.x, y = from.y, h = from.h, ribbon = from.ribbon, full = from.full, outer = from.outer,
    edge = from.edge }
  ---@type NextMorph
  local morph = { at = at, finish = function() end }
  self.morph = morph

  local function draw()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", at.x - bodyLeft, at.y)
    frame:SetSize(width, at.h)
    self:paintFeathers(at.full, at.outer)
    for _, edge in ipairs(edges) do
      edge:SetAlpha(at.edge)
    end
    self.ribbonLength = at.ribbon
    for _, line in ipairs(self.ribbonLines) do
      line:SetWidth(at.ribbon)
    end
  end

  morph.finish = function()
    self.morph = nil
    self:paintFeathers(1, 1)
    for _, edge in ipairs(edges) do
      edge:SetAlpha(1)
    end
    self:ApplyGeometry()
    render:Invalidate(self.root)
    chain:Arrived(self)
  end

  -- The glide: the body, the feathers and the beam.
  local function glide(after)
    local x0, y0, h0, r0, f0, o0 = at.x, at.y, at.h, at.ribbon, at.full, at.outer
    if math.abs(tx - x0) < 0.01 and math.abs(ty - y0) < 0.01 and math.abs(th - h0) < 0.01
      and math.abs(toRibbon - r0) < 0.01 and math.abs(toFull - f0) < 0.001 and math.abs(toFull - o0) < 0.001 then
      after()
      return
    end
    tween:Play(morph, {
      duration = style.Time.Morph,
      from = 0,
      to = 1,
      ease = "inOutCubic",
      onUpdate = function(t)
        at.x = x0 + (tx - x0) * t
        at.y = y0 + (ty - y0) * t
        at.h = h0 + (th - h0) * t
        at.ribbon = r0 + (toRibbon - r0) * t
        at.full = f0 + (toFull - f0) * t
        at.outer = o0 + (toFull - o0) * t
        draw()
      end,
      onDone = after,
    })
  end

  -- The border, fading to an alpha, for the share of MorphEdge it has to go.
  local function border(to, after)
    local e0 = at.edge
    if math.abs(to - e0) < 0.001 then
      after()
      return
    end
    tween:Play(morph, {
      duration = style.Time.MorphEdge * math.abs(to - e0),
      from = 0,
      to = 1,
      ease = "inOutSine",
      onUpdate = function(t)
        at.edge = e0 + (to - e0) * t
        draw()
      end,
      onDone = after,
    })
  end

  draw()
  if small then
    glide(function()
      border(1, morph.finish)
    end)
  else
    border(0, function()
      glide(morph.finish)
    end)
  end
end

-- endMorph puts a panel switching size at the end of its switch at once, both steps (anything else
-- that places the panel).
---@private
function panelProto:endMorph()
  local morph = self.morph
  if morph ~= nil then
    tween:Stop(morph)
    morph.finish()
  end
end

-- UpdateSizeButton shows what the size button does now (the backpack has one).
function panelProto:UpdateSizeButton()
end

-- BuildMover makes what moves a small panel (docs/next-small-mode.md): its title row, from the top
-- of the body down to the search box, dragged. The title (a button over it) moves it too, and the
-- header buttons above it still click. Over a full panel it is hidden: there the frame takes it.
function panelProto:BuildMover()
  local mover = CreateFrame("Frame", nil, self.frame)
  mover:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
  mover:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, 0)
  mover:SetHeight(style.SEARCH_TOP - 4)
  mover:SetFrameLevel(self.frame:GetFrameLevel() + 1)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  addon.SetScript(mover, "OnDragStart", function()
    self:StartMove()
  end)
  addon.SetScript(mover, "OnDragStop", function()
    self:StopMove()
  end)
  -- It covers part of the panel, which is a drop target (Watch): an item dropped or clicked onto
  -- the title row goes into the bag too.
  addon.SetScript(mover, "OnReceiveDrag", function()
    self:PlaceCursorItem()
  end)
  addon.SetScript(mover, "OnMouseUp", function(_, _, button)
    if button == "LeftButton" then
      self:PlaceCursorItem()
    end
  end)
  mover:Hide()
  self.mover = mover
end

-- StartMove starts moving a small panel with the mouse, finishing its opening slide first. A full
-- panel, one closing, or a press with something on the cursor (a drop, not a move) does not move.
-- It returns whether it did.
---@return boolean
function panelProto:StartMove()
  if not self:IsSmall() or self.closing or self.moving or GetCursorInfo() ~= nil then
    return false
  end
  self:endMorph()
  tween:Stop(self, true)
  self.frame:StartMoving()
  -- StartMoving flags the frame user-placed, and the client then restores a named frame's place
  -- from its layout cache at login (warcraft.wiki.gg Frame:StartMoving): the place is ours to keep.
  self.frame:SetUserPlaced(false)
  self.moving = true
  -- Chained (docs/next-small-mode.md): dragging the other bag lets it go of its anchor; dragging the
  -- anchor, its open partner follows it every frame.
  chain:Detach(self)
  local follower = chain:Follower(self)
  if follower ~= nil then
    -- A glide into its spot ends where it was going: from now on its spot follows the anchor.
    tween:Stop(follower, true)
    self.mover:SetScript("OnUpdate", function()
      follower.placeX, follower.placeY = follower:SmallPlace()
      follower:setOffset(0)
    end)
  end
  return true
end

-- StopMove ends a move: the panel's new place, kept on the screen, is saved for its kind, and it is
-- anchored there again (the client anchors a moved frame to the nearest corner of the screen).
function panelProto:StopMove()
  if not self.moving then
    return
  end
  self.mover:SetScript("OnUpdate", nil)
  local frame = self.frame
  frame:StopMovingOrSizing()
  local x, y = frame:GetLeft(), frame:GetTop()
  self.moving = false
  if x ~= nil and y ~= nil then
    x, y = self:clampPlace(x, y)
    -- Dropped beside its partner, it chains to it and glides into its spot.
    local sx, sy = chain:Dropped(self, x, y)
    self.placeX, self.placeY = x, y
    self.offset = 0
    if sx ~= nil then
      database:SetNextSmallPlace(self.kind, sx, sy)
      self:GlideTo(sx, sy)
      return
    end
    database:SetNextSmallPlace(self.kind, x, y)
  end
  self:setOffset(0)
  -- An anchor let go: its partner settles beside where it was dropped, its place saved too.
  local follower = chain:Follower(self)
  if follower ~= nil then
    follower.placeX, follower.placeY = follower:SmallPlace()
    follower:setOffset(0)
    database:SetNextSmallPlace(follower.kind, follower.placeX, follower.placeY)
  end
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
  -- Above a small panel's mover, which lies over the title row.
  button:SetFrameLevel(self.frame:GetFrameLevel() + 3)
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
  local width = self.title:GetStringWidth()
  -- Secret while the title shows a secret (a vendor's name in an instance): addon code may not do
  -- arithmetic on it. Clients without secrets have no issecretvalue.
  if issecretvalue ~= nil and issecretvalue(width) then
    width = style.Cloud.SecretTitleWidth
  end
  return width + style.PAD + 4 + style.Cloud.Pad
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
  -- Dragging the title moves a small panel, as its title row does.
  button:RegisterForDrag("LeftButton")
  addon.SetScript(button, "OnDragStart", function()
    self:StartMove()
  end)
  addon.SetScript(button, "OnDragStop", function()
    self:StopMove()
  end)
  addon.SetScript(button, "OnEnter", function()
    self:lightTitle(true)
    GameTooltip:SetOwner(button, self.side == "LEFT" and "ANCHOR_BOTTOMRIGHT" or "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(self.label)
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
  local C = style.Chain
  local gold = style.Color.Gold
  -- Its own layer above the panel: a coupled bag's grown feather reaches into the other bag's half
  -- of the gap, and would cover that half if the braid were drawn with the panel's own regions.
  local frame = CreateFrame("Frame", nil, self.frame)
  frame:SetAllPoints(self.frame)
  frame:SetFrameLevel(self.frame:GetFrameLevel() + 40)
  local braid = { strands = { {}, {} }, beads = {}, amount = 0, half = 0, chained = false, phase = 0, time = 0,
    swell = 0, layer = frame }
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
-- has turned. Its ribbon reaches the middle of the gap as it couples, its ribbon sparkles stay on its
-- side, and its inner feather grows toward feather wide (into the gap, past its frame).
---@param amount number
---@param half number
---@param chained boolean
---@param phase number
---@param time number
---@param feather number The inner feather's width when fully coupled.
function panelProto:SetCoupling(amount, half, chained, phase, time, feather)
  local braid = self.braid
  braid.amount, braid.half, braid.chained, braid.phase, braid.time = amount, half, chained, phase, time
  self:growFeather((feather - style.FEATHER) * amount)
  local base = self:RibbonBase()
  self.ribbonLength = base + (math.min(half, base) - base) * amount
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
    self.sparkSpread = self:SparkSpreadBase()
    o.Life = { 2.0, 3.6 }
    o.Speed = { 22, 64 }
  end
  local e = self.edgeSparkles.options
  if amount > 0 and self:IsSmall() then
    -- Two small bags braided (docs/next-small-mode.md): their gap can be narrow, so the edge
    -- sparkles die before the middle of it, never over the other bag (born up to 24 out, half the
    -- gap at least 32: 24 + half * 0.5 stays below the gap).
    e.Life = { 1.0, 1.6 }
    e.Speed = { 3, math.max(3, half * 0.5 / 1.6) }
  else
    e.Life = { 2.4, 4.2 }
    e.Speed = { 14, 36 }
  end
  self:applyBraid()
end

-- growFeather widens the inner feather by grow pixels past the frame's inner edge, into the gap; it
-- still starts at the body edge.
---@private
---@param grow number
function panelProto:growFeather(grow)
  local feather, frame = self.feather, self.frame
  if self.side == "LEFT" then
    feather:SetPoint("TOPRIGHT", frame, "TOPRIGHT", grow, 0)
    feather:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", grow, 0)
  else
    feather:SetPoint("TOPLEFT", frame, "TOPLEFT", -grow, 0)
    feather:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -grow, 0)
  end
  feather:SetWidth(style.FEATHER + grow)
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

-- BuildSearch takes the panel's search box (the kind's in-bag box, whose query the data phase reads,
-- searchBox:GetSearchText; the vendor's own) out of the theme's hands and draws it in Next's look,
-- so it stands out (asked: it was "very difficult to see"): a fill lighter than the panel, a lavender
-- edge all round that brightens under the pointer and while focused, a lavender magnifier, and the
-- help text in Next's muted lavender after it, instead of the template's border and 35% gray text.
function panelProto:BuildSearch()
  local sf = self:CreateSearchBox()
  sf.frame:ClearAllPoints()
  sf.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", style.PAD, -style.SEARCH_TOP)
  sf.frame:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -style.PAD, -style.SEARCH_TOP)
  sf.frame:SetHeight(style.SEARCH_HEIGHT)
  local t = sf.textBox
  for _, key in ipairs({ "Left", "Middle", "Right" }) do
    t[key]:SetAlpha(0)
  end
  local fill = sf.frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(1, 1, 1, 1)
  self.searchFill = fill
  self.searchEdges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local edge = sf.frame:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(1, 1, 1, 1)
    if side == "TOP" or side == "BOTTOM" then
      edge:SetPoint(side .. "LEFT", sf.frame, side .. "LEFT", 0, 0)
      edge:SetPoint(side .. "RIGHT", sf.frame, side .. "RIGHT", 0, 0)
      edge:SetHeight(1)
    else
      edge:SetPoint("TOP" .. side, sf.frame, "TOP" .. side, 0, 0)
      edge:SetPoint("BOTTOM" .. side, sf.frame, "BOTTOM" .. side, 0, 0)
      edge:SetWidth(1)
    end
    table.insert(self.searchEdges, edge)
  end
  self.searchEdgeAlpha = style.SearchEdge.Idle

  local icon = t.searchIcon
  icon:ClearAllPoints()
  icon:SetPoint("LEFT", t, "LEFT", style.SEARCH_GAP, 0)
  icon:SetSize(style.SEARCH_ICON, style.SEARCH_ICON)
  local help = t.Instructions
  help:ClearAllPoints()
  help:SetPoint("LEFT", icon, "RIGHT", style.SEARCH_GAP, 0)
  help:SetPoint("RIGHT", t, "RIGHT", -24, 0)
  help:SetJustifyH("LEFT")
  help:SetFontObject(style:Font("Search"))
  t:SetFontObject(style:Font("SearchText"))
  t:SetTextColor(unpack(style.Color.Text))
  t:SetTextInsets(style.SEARCH_GAP * 2 + style.SEARCH_ICON, 24, 0, 0)

  -- Hooked after the template's scripts (and the box's own OnTextChanged, which replaced the
  -- template's: InputBoxInstructions_OnTextChanged hid the help text), so Next's colors win.
  addon.HookScript(t, "OnEnter", function()
    self.searchHover = true
    self:UpdateSearchLook()
  end)
  addon.HookScript(t, "OnLeave", function()
    self.searchHover = false
    self:UpdateSearchLook()
  end)
  addon.HookScript(t, "OnEditFocusGained", function() self:UpdateSearchLook() end)
  addon.HookScript(t, "OnEditFocusLost", function() self:UpdateSearchLook() end)
  addon.HookScript(t, "OnTextChanged", function()
    help:SetShown(t:GetText() == "")
    self:UpdateSearchLook()
  end)
  self.searchBox = sf
  self:UpdateSearchLook(true)
  self:UpdateSearchShown()
end

-- SearchState is how the search box looks now: "focus" while typed in, "hover" under the pointer,
-- "active" while it holds a search, else "idle".
---@return string
function panelProto:SearchState()
  local t = self.searchBox.textBox
  if t:HasFocus() then
    return "focus"
  end
  if self.searchHover then
    return "hover"
  end
  if t:GetText() ~= "" then
    return "active"
  end
  return "idle"
end

-- UpdateSearchLook draws the search box for its state: the fill and magnifier at once, the edge
-- fading to its strength (at once with now).
---@param now? boolean
function panelProto:UpdateSearchLook(now)
  local state = self:SearchState()
  local focused = state == "focus"
  local fill = style.Color[focused and "SearchFillFocus" or "SearchFill"]
  self.searchFill:SetVertexColor(fill[1], fill[2], fill[3], fill[4])
  local icon = self.searchBox.textBox.searchIcon
  if focused then
    icon:SetVertexColor(1, 1, 1, 1)
  else
    local c = style.Color.Lavender
    icon:SetVertexColor(c[1], c[2], c[3], state == "idle" and style.SearchIcon.Idle or style.SearchIcon.Active)
  end
  local target = focused and style.SearchEdge.Focus
    or (state == "idle" and style.SearchEdge.Idle or style.SearchEdge.Hover)
  local function paint(alpha)
    self.searchEdgeAlpha = alpha
    local c = style.Color.Lavender
    for _, edge in ipairs(self.searchEdges) do
      edge:SetVertexColor(c[1], c[2], c[3], alpha)
    end
  end
  if now then
    tween:Stop(self.searchEdges)
    paint(target)
    return
  end
  local from = self.searchEdgeAlpha
  tween:Play(self.searchEdges, {
    duration = style.Time.Hover,
    from = 0,
    to = 1,
    ease = "outCubic",
    onUpdate = function(t) paint(t >= 1 and target or from + (target - from) * t) end,
  })
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
  -- From the panel's top left, for its size now: the title's side the join is measured from (its
  -- left edge on the backpack, its right on the bank), where the ribbon starts, and the body's inner
  -- edge.
  local function titleEdge()
    if self.side == "LEFT" then
      return self:BodyLeft() + style.BODY_WIDTH - (style.PAD + 4)
    end
    return self:BodyLeft() + style.PAD + 4
  end
  local function ribbonStart()
    return titleEdge() + joinX
  end
  local function innerEdge()
    if self.side == "LEFT" then
      return self:BodyLeft() + style.BODY_WIDTH
    end
    return self:BodyLeft()
  end
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
      return ribbonStart() + inward * span * math.random() ^ 1.7, titleMiddle + y
    end,
  })
  self.sparkSpread = self:SparkSpreadBase()
  self.sparkles = sparkles:Create(fx, {
    Rate = 8, Max = 28, Life = { 2.0, 3.6 }, Size = { 6, 15 }, Speed = { 22, 64 }, Rise = { -8, 10 },
    Wobble = 4, Spin = 1.5, Direction = out,
    Spawn = function()
      return ribbonStart() + out * math.random() * self.sparkSpread, titleMiddle + (math.random() * 2 - 1) * 8
    end,
  })
  -- Along the inner feathered edge, chained or not (asked, of an earlier version that stopped them
  -- while coupled: "let's not do that"). Coupled, they drift into the gap and die before the other
  -- bag: they travel at most 36 * 4.2 + 24 pixels, the gap is at least 192.
  self.edgeSparkles = sparkles:Create(fx, {
    Rate = 2.5, Max = 12, Life = { 2.4, 4.2 }, Size = { 4, 9 }, Speed = { 14, 36 }, Rise = { -6, 6 },
    Wobble = 3, Spin = 1, Alpha = 0.6, Direction = out,
    Spawn = function()
      return innerEdge() + out * math.random() * 24, -math.random() * fx:GetHeight()
    end,
  })
  -- From the knot in the middle of the gap, as the pair couples (BurstKnot).
  self.knotSparkles = sparkles:Create(fx, {
    Rate = 0, Max = 16, Life = { 0.5, 1.1 }, Size = { 4, 10 }, Speed = { 12, 40 }, Rise = { -16, 16 },
    Wobble = 2, Spin = 2, Alpha = 0.9, Direction = out,
    Spawn = function()
      return ribbonStart() + out * self.braid.half, titleMiddle
    end,
  })
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
  self.waiting = false
  PlaySound(self.openSound)
  self:OnShowing(ctx)
  self.frame:Show()
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
  -- Where it comes in from and rests (next.md §12): opened again as it slid out, from where it is;
  -- beside its open anchor, after the anchor, from beyond the anchor's edge; chained to a backpack
  -- about to open, out of sight until it does; else at its own edge, from its edge.
  local to = self:RestOffset()
  if self:IsSmall() then
    -- Where it was left (docs/next-small-mode.md), sliding a short way in from its edge side as it
    -- fades in; opened again as it slid out, from where it is.
    self.target = 0
    if not sliding then
      self:FitSmall()
    end
    self:moveIn(sliding and self.offset or self:HiddenOffset(), 0, style.Time.Open, "outCubic", 0)
  elseif sliding then
    self.target = to
    self:SetDocked(to == 0)
    if to == 0 then
      self:moveIn(self.offset, 0, style.Time.Open, "outBack", 0)
    else
      self:moveIn(self.offset, to, style.Time.Enter, "outBackSoft", 0)
    end
  elseif chain:AnchorOf(self) ~= nil then
    self:Enter(to, chain:EntranceDelay(self))
  elseif chain:WaitsForAnchor(self) then
    self:WaitForAnchor()
  else
    self.target = 0
    self:SetDocked(true)
    self:moveIn(self:HiddenOffset(), 0, style.Time.Open, "outBack", 0)
  end
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
  -- Beside its anchor, it leaves through the anchor's edge, beneath the anchor (next.md §12); else
  -- through its own. Out of sight beyond the far edge, it leaves through its own without crossing
  -- the screen.
  local to = chain:ExitOffset(self)
  local anchor = chain:ShownAnchorOf(self)
  if to ~= self:HiddenOffset() and anchor ~= nil then
    self.frame:SetFrameLevel(math.max(1, anchor.frame:GetFrameLevel() - 100))
  end
  self.target = to
  local from = self.offset
  if self:BeyondFarEdge() and to == self:HiddenOffset() then
    from = to
  end
  self.waiting = false
  chain:Update(ctx)
  tween:Play(self, {
    duration = style.Time.Close,
    from = from,
    to = to,
    ease = "inCubic",
    onUpdate = function(x)
      self:setOffset(x)
    end,
    onDone = function()
      self.closing = false
      self.frame:Hide()
      -- What OnHidden does too, for a hide whose OnHide does not run: back at its own level, and the
      -- bag the chain held for it (chain:Holds) placed again.
      self.frame:SetFrameLevel(PANEL_LEVEL)
      chain:Update(ctx)
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
  self:StopMove()
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
  self.waiting = false
  self.frame:SetFrameLevel(PANEL_LEVEL)
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
