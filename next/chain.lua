local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextChain keeps BetterBags Next's backpack and its companion (the bank or the vendor, whichever
-- is open) apart on opposite edges of the screen, or chained together on one (next.md §12). Each
-- bag keeps its orientation: the backpack faces left, its companion right. Chained "left", the
-- companion is the anchor at the left edge and the backpack sits beside it, facing it; chained
-- "right", the backpack is the anchor at the right edge and the companion sits beside it. Clicking a
-- bag's name chains it to its partner (the partner is the anchor), puts a chained bag back, or moves
-- a chained pair to the other side (the other bag is then the one at the edge). Alone, a bag sits at
-- its own edge, and joins its partner when it opens. Once a chained bag is beside its anchor, their
-- ribbons twist together across the gap between them (the coupling).
---@class NextChain: AceModule
---@field backpack? NextPanelFrame
---@field companions NextPanelFrame[]
---@field coupling? NextCoupling
---@field driver Frame Turns the braid while the pair is coupled.
---@field watching boolean
local chain = addon:NewModule('NextChain')

-- The pair coupled: amount runs from 0 (straight ribbons) to 1 (braided), toward target; phase is
-- how far the braid has turned, time how long it has been coupled.
---@class (exact) NextCoupling
---@field anchor NextPanelFrame
---@field chained NextPanelFrame
---@field amount number
---@field target number
---@field phase number
---@field time number

-- Which of the pair is the anchor, at its edge, in a chained layout.
local ANCHOR_ROLE = { left = "companion", right = "backpack" }

-- Two places closer than this are the same place (UpdateCoupling).
local PLACED = 0.5

function chain:Init()
  self.backpack = nil
  self.companions = {}
  self.coupling = nil
  self.watching = false
  if self.driver == nil then
    self.driver = CreateFrame("Frame")
  end
  self.driver:SetScript("OnUpdate", nil)
end

-- Register makes panel the chain's backpack or one of its companions. The screen events are
-- registered with the first panel, in BetterBags Next's event scope (BagSystem), so switching to the
-- classic bags unhooks them.
---@param panel NextPanelFrame
---@param role "backpack"|"companion"
function chain:Register(panel, role)
  panel.chainRole = role
  if role == "backpack" then
    self.backpack = panel
  else
    table.insert(self.companions, panel)
  end
  if not self.watching then
    self.watching = true
    events:RegisterEvent("UI_SCALE_CHANGED", function(ctx) self:Update(ctx, true) end)
    events:RegisterEvent("DISPLAY_SIZE_CHANGED", function(ctx) self:Update(ctx, true) end)
    events:RegisterMessage("next/ScalesChanged", function(ctx) self:ScalesChanged(ctx) end)
    events:RegisterMessage("bags/ClampChanged", function(ctx) self:ClampChanged(ctx) end)
  end
end

-- ScalesChanged applies the Size tab's scales (docs/next-appearance-size.md, next/ScalesChanged from its
-- sliders): the item buttons' size, then every panel (ApplyScales), then where the panels rest, a small
-- one refitted to the screen (Update, snapping).
---@param ctx Context
function chain:ScalesChanged(ctx)
  style:SetIconScale(database:GetNextIconScale())
  for _, panel in ipairs(self:Panels()) do
    panel:ApplyScales(ctx)
  end
  self:Update(ctx, true)
end

---@return NextChainLayout
function chain:Layout()
  return database:GetNextChain()
end

---@param panel? NextPanelFrame
---@return boolean
local function isOpen(panel)
  return panel ~= nil and panel.frame:IsShown() and not panel.closing
end

-- isSmall says panel is small (docs/next-small-mode.md): the player places it, and the layouts of
-- the screen's edges do not apply to it.
---@param panel? NextPanelFrame
---@return boolean
local function isSmall(panel)
  return panel ~= nil and panel.size == "small"
end

-- ClampChanged follows Clamp Bags to Screen (bags/ClampChanged, window.md §3a): every panel takes the clamp;
-- turned on, each open small panel is put back on the screen (FitSmall; a chained one beside where its anchor
-- is put back, LivePlace) and its place saved there, so turning it off again moves nothing, now or when it
-- opens next. A closed one is put back as it opens.
---@param ctx Context
function chain:ClampChanged(ctx)
  local _ = ctx
  local on = database:GetClampBagsToScreen()
  for _, panel in ipairs(self:Panels()) do
    panel:ApplyClamp()
    if on and isOpen(panel) and isSmall(panel) then
      panel:FitSmall()
      database:SetNextSmallPlace(panel.kind, panel.placeX, panel.placeY)
    end
  end
end

-- Companion returns the companion that is open, if any.
---@return NextPanelFrame?
function chain:Companion()
  for _, panel in ipairs(self.companions) do
    if isOpen(panel) then
      return panel
    end
  end
  return nil
end

-- Partner returns panel's partner when it is open: the open companion for the backpack, the backpack
-- for a companion.
---@param panel NextPanelFrame
---@return NextPanelFrame?
function chain:Partner(panel)
  if panel.chainRole == "backpack" then
    return self:Companion()
  end
  if isOpen(self.backpack) then
    return self.backpack
  end
  return nil
end

-- Gap is the room between the bodies of two bags side by side: both tab rails hang into it from
-- their bodies (past a side rail standing outside each, Header.Buttons.Rail.Outside), each its widest
-- tab plus the hover slide, with a margin between them; never less than the two feathers.
---@param a NextPanelFrame
---@param b NextPanelFrame
---@return number
function chain:Gap(a, b)
  local tabs = a.tabs:Width() + b.tabs:Width() + 2 * (style.TAB_HOVER + style.RAIL_OUT) + style.Chain.TabMargin
  return math.max(2 * style.FEATHER, tabs)
end

-- Distance is how far from its own edge a chained bag sits beside its anchor: the screen less both
-- bodies and the gap. Below 0 the screen is too narrow for the two side by side.
---@param anchor NextPanelFrame
---@param chained NextPanelFrame
---@return number
function chain:Distance(anchor, chained)
  return UIParent:GetWidth() - 2 * (style.WIDTH - style.FEATHER) - self:Gap(anchor, chained)
end

-- Pair returns the anchor and the chained bag when the layout chains them, both are open and they
-- fit on the screen side by side.
---@param layout? NextChainLayout
---@return NextPanelFrame? anchor, NextPanelFrame? chained
function chain:Pair(layout)
  local role = ANCHOR_ROLE[layout or self:Layout()]
  if role == nil or not isOpen(self.backpack) then
    return nil, nil
  end
  local companion = self:Companion()
  if companion == nil or isSmall(self.backpack) or isSmall(companion) then
    return nil, nil
  end
  local anchor, chained = companion, self.backpack
  if role == "backpack" then
    anchor, chained = self.backpack, companion
  end
  if self:Distance(anchor, chained) < 0 then
    return nil, nil
  end
  return anchor, chained
end

-- SmallLayout returns which small panel anchors a chained pair (docs/next-small-mode.md).
---@return NextSmallChain
function chain:SmallLayout()
  return database:GetNextSmallChain()
end

-- SmallGap is the room between two small bags side by side, on the screen: both tab rails hang into it,
-- each its widest tab plus the hover slide at its bag's scale (docs/next-appearance-size.md), with a
-- margin between them; never less than Small.MinGap, both at the larger scale.
---@param a NextPanelFrame
---@param b NextPanelFrame
---@return number
function chain:SmallGap(a, b)
  local sa, sb = a:Scale(), b:Scale()
  local s = math.max(sa, sb)
  local tabs = (a.tabs:Width() + style.TAB_HOVER + style.RAIL_OUT) * sa
    + (b.tabs:Width() + style.TAB_HOVER + style.RAIL_OUT) * sb + style.Chain.TabMargin * s
  return math.max(style.Small.MinGap * s, tabs)
end

-- SmallAnchorOf returns the bag a small panel sits beside, when the small chain makes it the chained
-- one: the backpack for a companion (layout "backpack", open or not: a companion opens beside where
-- it was left), the open companion for the backpack (layout "companion").
---@param panel NextPanelFrame
---@return NextPanelFrame?
function chain:SmallAnchorOf(panel)
  local layout = self:SmallLayout()
  if layout == "backpack" and panel.chainRole == "companion" then
    return self.backpack
  end
  if layout == "companion" and panel.chainRole == "backpack" then
    return self:Companion()
  end
  return nil
end

-- ChainedPlace is where panel sits beside anchor, whose top left is ax, ay: a companion left of the
-- backpack, the backpack right of a companion, the gap between them, their tops aligned. Each is as
-- wide as the player made it (next.md §14g).
---@param panel NextPanelFrame
---@param anchor NextPanelFrame
---@param ax number
---@param ay number
---@return number x, number y
function chain:ChainedPlace(panel, anchor, ax, ay)
  local gap = self:SmallGap(panel, anchor)
  if panel.chainRole == "companion" then
    return ax - gap - panel:BodyWidth() * panel:Scale(), ay
  end
  return ax + anchor:BodyWidth() * anchor:Scale() + gap, ay
end

-- ChainedSide is the side of a small panel its chained partner is on, where a grip would push the
-- partner (next.md §14g): a bag chained beside an anchor, its facing side always (its place hangs from
-- the anchor's, open or not); an anchor, its facing side while the bag chained to it is open. Facing is
-- the backpack's left, a companion's right. Else nil.
---@param panel NextPanelFrame
---@return "LEFT"|"RIGHT"|nil
function chain:ChainedSide(panel)
  if not isSmall(panel) then
    return nil
  end
  if self:SmallAnchorOf(panel) == nil and self:Follower(panel) == nil then
    return nil
  end
  return panel.chainRole == "backpack" and "LEFT" or "RIGHT"
end

-- UpdateGrips shows or hides every small panel's grips for how the bags are chained now.
function chain:UpdateGrips()
  for _, panel in ipairs(self:Panels()) do
    panel:UpdateGrips()
  end
end

-- SmallPair returns the anchor and the chained bag when the small chain chains them and both are open
-- and small.
---@return NextPanelFrame? anchor, NextPanelFrame? chained
function chain:SmallPair()
  local backpack = self.backpack
  if not isOpen(backpack) then
    return nil, nil
  end
  -- Every panel switches size together (nextPanel:SetSize): the companion's is the pair's.
  local companion = self:Companion()
  if companion == nil or not isSmall(companion) then
    return nil, nil
  end
  local layout = self:SmallLayout()
  if layout == "backpack" then
    return backpack, companion
  end
  if layout == "companion" then
    return companion, backpack
  end
  return nil, nil
end

-- SmallPlaced says a small pair is in place to braid: neither sliding, gliding or switching size. A
-- chained bag is at its spot once still: a bag whose spot moves glides there (Settle), and dragging
-- the chained bag lets it go (Detach).
---@param anchor NextPanelFrame
---@param chained NextPanelFrame
---@return boolean
function chain:SmallPlaced(anchor, chained)
  for _, panel in ipairs({ anchor, chained }) do
    if panel.morph ~= nil or tween:IsPlaying(panel) then
      return false
    end
  end
  return true
end

-- Settle glides a small bag chained to an open anchor to its spot when the spot moved (the gap
-- changed). It returns whether it glides.
---@param panel NextPanelFrame
---@return boolean
function chain:Settle(panel)
  local anchor = self:SmallAnchorOf(panel)
  if anchor == nil or not isOpen(anchor) then
    return false
  end
  local x, y = panel:SmallPlace()
  if math.abs(x - panel.placeX) < PLACED and math.abs(y - panel.placeY) < PLACED then
    return false
  end
  panel:GlideTo(x, y)
  return true
end

-- Dropped runs when the player lets go of a small bag at x, y: dropped beside its open partner's
-- facing side (its inner side within Small.SnapReach of its spot, its top within Small.SnapRise), it
-- chains to it, the partner the anchor, and Dropped returns its spot. A pair that would not fit on
-- the screen does not chain.
---@param panel NextPanelFrame
---@param x number
---@param y number
---@return number? x, number? y
function chain:Dropped(panel, x, y)
  local partner = self:Partner(panel)
  if partner == nil or not isSmall(partner) then
    return nil, nil
  end
  local px, py = partner:SmallPlace()
  local wx, wy = self:ChainedPlace(panel, partner, px, py)
  if wx < 0 or wx + panel:BodyWidth() * panel:Scale() > UIParent:GetWidth() then
    return nil, nil
  end
  if math.abs(x - wx) > style.Small.SnapReach or math.abs(y - wy) > style.Small.SnapRise then
    return nil, nil
  end
  database:SetNextSmallChain(partner.chainRole)
  self:UpdateGrips()
  return wx, wy
end

-- Detach lets a small bag go of its anchor as the player starts to drag it away; its partner braids
-- no more. It returns whether it was chained.
---@param panel NextPanelFrame
---@return boolean
function chain:Detach(panel)
  if self:SmallAnchorOf(panel) == nil then
    return false
  end
  database:SetNextSmallChain("apart")
  self:UpdateCoupling()
  return true
end

-- Follower returns the open small bag chained to panel, when panel anchors the small pair: it moves
-- along with panel.
---@param panel NextPanelFrame
---@return NextPanelFrame?
function chain:Follower(panel)
  local anchor, chained = self:SmallPair()
  if anchor == panel then
    return chained
  end
  return nil
end

-- RestOffset is where panel rests (as an offset from its own edge, setOffset): beside its anchor
-- when it is the chained bag of the layout and its anchor is open, else at its own edge.
---@param panel NextPanelFrame
---@return number
function chain:RestOffset(panel)
  local anchor, chained = self:Pair()
  if anchor ~= nil and chained == panel then
    return panel:Outward() * self:Distance(anchor, chained)
  end
  return 0
end

-- EntranceOffset is where a chained bag comes in from: out of sight beyond its anchor's edge, so it
-- slides out from beneath the anchor (asked: "appearing from the border they are chained to").
---@param panel NextPanelFrame
---@return number
function chain:EntranceOffset(panel)
  return panel:Outward() * (UIParent:GetWidth() + style.FEATHER)
end

-- EntranceDelay is how long a chained bag waits before coming in: Stagger while its anchor is
-- still coming in itself (asked: "the window closest to the border first, then the chained one a
-- few ms after"), none when the anchor is in place.
---@param panel NextPanelFrame
---@return number
function chain:EntranceDelay(panel)
  local anchor = self:AnchorOf(panel)
  if anchor ~= nil and tween:IsPlaying(anchor) then
    return style.Chain.Stagger
  end
  return 0
end

-- ShownAnchorOf returns the bag panel is chained to in the layout while that bag still shows, open
-- or sliding out: the backpack for a companion chained right, the shown companion for the backpack
-- chained left.
---@param panel NextPanelFrame
---@return NextPanelFrame?
function chain:ShownAnchorOf(panel)
  local role = ANCHOR_ROLE[self:Layout()]
  if role == nil or panel.chainRole == role or isSmall(panel) then
    return nil
  end
  if role == "backpack" then
    local backpack = self.backpack
    if backpack ~= nil and backpack.frame:IsShown() then
      return backpack
    end
    return nil
  end
  for _, companion in ipairs(self.companions) do
    if companion.frame:IsShown() then
      return companion
    end
  end
  return nil
end

-- Holds says panel stays where it is: it is away from its own edge (beside its anchor) and its
-- anchor is sliding out. Leaving a bank or a vendor, the companion closes a frame before the
-- backpack (addon.CloseInteractionWindow sends bags/OpenClose later): held, a backpack chained left
-- then leaves after its anchor through the anchor's edge, instead of first flying home across the
-- screen. One that stays open goes home once the anchor has gone (its OnHidden updates the chain).
---@param panel NextPanelFrame
---@return boolean
function chain:Holds(panel)
  local anchor = self:ShownAnchorOf(panel)
  return anchor ~= nil and anchor.closing and not panel.docked
end

-- ExitOffset is where panel goes as it closes: out beyond its anchor's edge while it is beside an
-- anchor that still shows (asked: "if the bag is chained, it should also exit in the direction of
-- the anchor"), else off its own edge.
---@param panel NextPanelFrame
---@return number
function chain:ExitOffset(panel)
  if not panel.docked and self:ShownAnchorOf(panel) ~= nil then
    return self:EntranceOffset(panel)
  end
  return panel:HiddenOffset()
end

-- WaitsForAnchor says whether panel, opening, waits for its anchor out of sight: a companion
-- chained to the backpack (layout "right") while the backpack is closed. A companion opens only at
-- a bank or a vendor, whose interaction opens the backpack a frame later (addon.OpenInteractionWindow
-- sends bags/OpenClose later), so it would otherwise open alone at its own edge and then fly across
-- the screen. The backpack opens after its companion, so it never waits.
---@param panel NextPanelFrame
---@return boolean
function chain:WaitsForAnchor(panel)
  local backpack = self.backpack
  return panel.chainRole == "companion" and ANCHOR_ROLE[self:Layout()] == "backpack" and backpack ~= nil
    and not isOpen(backpack) and self:Distance(backpack, panel) >= 0
end

-- Anchor returns the open anchor of panel when panel is the chained bag of the layout.
---@param panel NextPanelFrame
---@return NextPanelFrame?
function chain:AnchorOf(panel)
  local anchor, chained = self:Pair()
  if chained == panel then
    return anchor
  end
  return nil
end

-- Click runs a click on panel's name. It returns what it did, for profiler traces: "chained" (it
-- flies to its partner, the anchor), "unchained" (a chained bag goes back to its edge), "moved" (the
-- anchor's name: both bags go to the other side), "alone" (no partner is open: nothing), "no room"
-- (the screen is too narrow for the two side by side) or "small" (a small panel's name moves it when
-- dragged, and a click does nothing).
---@param ctx Context
---@param panel NextPanelFrame
---@return string
function chain:Click(ctx, panel)
  if isSmall(panel) then
    return "small"
  end
  local partner = self:Partner(panel)
  if partner == nil then
    return "alone"
  end
  local layout = self:Layout()
  local anchor, chained = self:Pair(layout)
  if chained == panel then
    database:SetNextChain("apart")
    self:Update(ctx)
    return "unchained"
  end
  if anchor == panel then
    database:SetNextChain(layout == "left" and "right" or "left")
    self:Update(ctx)
    return "moved"
  end
  if self:Distance(partner, panel) < 0 then
    UIErrorsFrame:AddMessage(L:G("There is not enough room on the screen to chain the bags."), 1.0, 0.1, 0.1, 1.0)
    return "no room"
  end
  database:SetNextChain(panel.chainRole == "backpack" and "left" or "right")
  self:Update(ctx)
  return "chained"
end

-- Panels returns every registered panel: the backpack, then its companions.
---@return NextPanelFrame[]
function chain:Panels()
  local panels = { self.backpack }
  for _, companion in ipairs(self.companions) do
    table.insert(panels, companion)
  end
  return panels
end

-- Update sends every open bag to where it rests now (flying, or at once with snap: the screen
-- changed), then couples or uncouples the pair.
---@param ctx Context
---@param snap? boolean
function chain:Update(ctx, snap)
  local _ = ctx
  for _, panel in ipairs(self:Panels()) do
    if isOpen(panel) and isSmall(panel) then
      -- Where the player put it; the screen changed: still on it, its height the screen's share. A
      -- chained bag whose spot beside its open anchor moved (the gap changed) glides there. One the
      -- player sizes, or whose size glides (back to its default, or onto its columns' width), is left alone: it
      -- places itself after.
      local sizing = panel.sizing ~= nil or panel.sizeGliding
      if snap and not sizing then
        panel:FitSmall()
      elseif not snap and not sizing and panel.morph == nil and not tween:IsPlaying(panel) then
        -- Never cutting a slide or a switch short (a slide's end says the bag has shown): Arrived
        -- settles it once there.
        self:Settle(panel)
      end
    elseif isOpen(panel) then
      local to = self:RestOffset(panel)
      if panel.waiting then
        -- Its anchor has opened: it comes in after it.
        if self:AnchorOf(panel) ~= nil then
          panel:Enter(to, self:EntranceDelay(panel))
        end
      elseif self:Holds(panel) then
        panel:Hold()
      elseif snap then
        panel:PlaceAt(to)
      elseif math.abs((panel.target or 0) - to) >= PLACED then
        panel:FlyTo(to)
      end
    end
  end
  self:UpdateCoupling()
end

-- Arrived runs when a bag has come to rest after a slide or a flight: a chained bag beside its
-- anchor couples. It returns what UpdateCoupling did, for profiler traces.
---@param panel NextPanelFrame
---@return string
function chain:Arrived(panel)
  -- A small chained bag whose spot moved on the way glides there first ("settling").
  if isSmall(panel) and self:Settle(panel) then
    return "settling"
  end
  return self:UpdateCoupling()
end

-- UpdateCoupling couples the pair once the chained bag has reached its place beside the anchor,
-- keeps a pair coupled while it moves across together (the roles swap: the other bag is at the edge
-- after), and lets go as soon as the bags are no longer chained or one of them closes. A place is
-- the same within half a pixel: it is computed from sizes, and the client hands sizes back with
-- float error at a UI scale, so an exact match could fail for good (reported: the tangle "only
-- appears sometimes"). It returns what it did, for profiler traces: "coupled", "kept", "on its
-- way" (the chained bag has not reached its place), "letting go" (another pair's coupling, or the
-- pair parted), "apart".
---@return string
function chain:UpdateCoupling()
  self:UpdateGrips()
  local anchor, chained = self:Pair()
  local placed, arrived = false, false
  if chained ~= nil then
    local rest = self:RestOffset(chained)
    placed = math.abs((chained.target or 0) - rest) < PLACED
    -- Switching size, either may still be gliding to its place (Morph): its offset is already the
    -- place.
    arrived = placed and math.abs(chained.offset - rest) < PLACED and anchor.morph == nil and chained.morph == nil
  else
    anchor, chained = self:SmallPair()
    if chained ~= nil then
      placed = self:SmallPlaced(anchor, chained)
      arrived = placed
    end
  end
  local c = self.coupling
  if chained ~= nil then
    if placed then
      local same = c ~= nil and ((c.anchor == anchor and c.chained == chained) or (c.anchor == chained and c.chained == anchor))
      if same then
        c.anchor, c.chained = anchor, chained
        if c.target ~= 1 then
          self:tweenCoupling(1)
        end
        self:applyCoupling()
        return "kept"
      end
      if c == nil then
        if not arrived then
          return "on its way"
        end
        self.coupling = { anchor = anchor, chained = chained, amount = 0, target = 0, phase = 0, time = 0 }
        self.driver:SetScript("OnUpdate", function(_, elapsed)
          self:Turn(elapsed)
        end)
        self:tweenCoupling(1)
        return "coupled"
      end
    end
  end
  if c ~= nil then
    if c.target ~= 0 then
      self:tweenCoupling(0)
    end
    return "letting go"
  end
  return "apart"
end

-- LetGo ends the coupling at once, both halves of the braid hidden: the bags are switching size
-- (nextPanel:SetSize), and small panels are not chained yet (docs/next-small-mode.md).
function chain:LetGo()
  local c = self.coupling
  if c == nil then
    return
  end
  tween:Stop(c)
  self.coupling = nil
  self.driver:SetScript("OnUpdate", nil)
  c.anchor:SetCoupling(0, 0, false, 0, 0, style.FEATHER)
  c.chained:SetCoupling(0, 0, false, 0, 0, style.FEATHER)
end

-- Turn turns the braid elapsed seconds on and runs its lights along it.
---@param elapsed number
function chain:Turn(elapsed)
  local c = self.coupling
  if c == nil then
    return
  end
  c.phase = c.phase + elapsed * style.Chain.Turn
  c.time = c.time + elapsed
  self:applyCoupling()
end

-- tweenCoupling twists the ribbons together (to 1) or lets them go (to 0). Coupled, the knot
-- bursts with sparkles; let go, the coupling ends and the braid hides.
---@private
---@param to number
function chain:tweenCoupling(to)
  local c = self.coupling --[[@as NextCoupling]]
  c.target = to
  tween:Play(c, {
    duration = to == 1 and style.Time.Couple or style.Time.Uncouple,
    from = c.amount,
    to = to,
    ease = style:Ease(to == 1 and "Couple" or "Uncouple"),
    onUpdate = function(v)
      c.amount = v
      self:applyCoupling()
    end,
    onDone = function()
      if to == 1 then
        c.chained:BurstKnot()
        return
      end
      if self.coupling == c then
        self.coupling = nil
        self.driver:SetScript("OnUpdate", nil)
      end
      c.anchor:SetCoupling(0, 0, false, 0, 0, style.FEATHER)
      c.chained:SetCoupling(0, 0, false, 0, 0, style.FEATHER)
      -- A pair that formed while this one let go (a companion closed as another opened, the
      -- backpack in place already) couples now: nothing else would.
      self:UpdateCoupling()
    end,
  })
end

-- applyCoupling draws both halves of the braid where the bags are now: half the gap between their
-- bodies each, so it stretches as they part. The driver runs it every frame while coupled, so the
-- braid follows the bags as they move.
---@private
function chain:applyCoupling()
  local c = self.coupling
  if c == nil then
    return
  end
  if isSmall(c.anchor) then
    -- Two free bags: the gap between the backpack's body and its companion's, where they are now.
    local backpack, companion = c.anchor, c.chained
    if backpack.chainRole ~= "backpack" then
      backpack, companion = companion, backpack
    end
    local gap = backpack:SmallLeft() - (companion:SmallLeft() + companion:BodyWidth() * companion:Scale())
    local half = math.max(0, gap / 2)
    -- The braid is drawn in each bag, in its own units (its Bag Scale).
    c.anchor:SetCoupling(c.amount, half / c.anchor:Scale(), false, c.phase, c.time, style.FEATHER)
    c.chained:SetCoupling(c.amount, half / c.chained:Scale(), true, c.phase, c.time, style.FEATHER)
    return
  end
  local gap = UIParent:GetWidth() - 2 * (style.WIDTH - style.FEATHER) - math.abs(c.anchor.offset)
    - math.abs(c.chained.offset)
  local half = math.max(0, gap / 2)
  -- The inner feathers grow to a share of the gap the pair rests at (not of the gap as they part,
  -- which can be the whole screen): style.Chain.CoupledFeather.
  local rest = math.min(math.max(0, gap), self:Gap(c.anchor, c.chained))
  local feather = math.max(style.FEATHER, style.Chain.CoupledFeather * rest)
  c.anchor:SetCoupling(c.amount, half, false, c.phase, c.time, feather)
  c.chained:SetCoupling(c.amount, half, true, c.phase, c.time, feather)
end

-- Tooltip says what a click on panel's name does.
---@param panel NextPanelFrame
---@return string
function chain:Tooltip(panel)
  if isSmall(panel) then
    return L:G("Drag to move it.")
  end
  local partner = self:Partner(panel)
  if partner == nil then
    if panel.chainRole == "backpack" then
      return L:G("Open the bank or a vendor to chain your backpack to it.")
    end
    return L:G("Open your backpack to chain this bag to it.")
  end
  local anchor, chained = self:Pair()
  if chained == panel then
    return L:G("Click to put it back.")
  end
  if anchor == panel then
    return L:G("Click to move both bags to the other side.")
  end
  return format(L:G("Click to chain to the %s."), partner.label)
end

chain:Init()
