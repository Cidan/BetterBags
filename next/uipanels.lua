local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextChain: AceModule
local chain = addon:GetModule('NextChain')

-- NextUIPanels keeps Blizzard's UI panels (the Character pane, the Dressing Room, the Friends list...) beside BetterBags
-- Next's panels at the left edge of the screen, not under them, as far as the screen allows (next-uipanels.md). Blizzard's
-- panel manager lays its panels out from LEFT_OFFSET, each after the one before it by the width it has in the layout
-- (UIParentPanelManager.lua, UpdateUIPanelPositions), and keeps only the panels that fit before GetMaxUIPanelsWidth (the
-- screen less RIGHT_OFFSET_BUFFER). The frames BetterBags Next stands in for (the merchant frame, the bank's, the guild
-- bank's) are among them, shown to Blizzard's code and never seen. While a full companion is open, the frame it stands in
-- for takes no room in the layout, and Blizzard's panels move right (shift): past what BetterBags Next covers at the left
-- edge (Room), or as far as they fit on the screen. LEFT_OFFSET and RIGHT_OFFSET_BUFFER move together, so the manager
-- keeps the same panels at any shift. A small companion is a window the player places: Blizzard lays its panels out as
-- beside its own frame.
---@class NextUIPanels: AceModule
---@field room number How far from the left edge BetterBags Next covers, as last told; 0 for nothing.
---@field shift number How far Blizzard's panels are moved right; 0 while they are where Blizzard puts them.
---@field base? number LEFT_OFFSET before they were moved, while they are.
---@field buffer? number RIGHT_OFFSET_BUFFER before they were moved, while they are.
---@field standIn? Frame The frame of Blizzard's that takes no room in the layout.
---@field standInWidth? number Its width in the layout before.
---@field standInFit? number Its checkFitExtraWidth before.
---@field hooked? function The UpdateUIPanelPositions hooked (once: a hook cannot be taken off).
---@field driver Frame Places the panels again the frame after the manager lays them out.
local uiPanels = addon:NewModule('NextUIPanels')

-- The manager's places for panels laid out from the left edge (a native center panel is centered instead).
local SLOTS = { "left", "center", "right", "doublewide" }

function uiPanels:Init()
  self.room = 0
  self.shift = 0
  self.base = nil
  self.buffer = nil
  self.standIn = nil
  self.standInWidth = nil
  self.standInFit = nil
  self.hooked = nil
  if self.driver == nil then
    self.driver = CreateFrame("Frame")
  end
  self.driver:SetScript("OnUpdate", nil)
end

-- layoutAttribute and setLayoutAttribute read and write the panel manager's layout: its own frame's attributes on retail
-- and WoW: Forever (UIPanelLayoutFrame.lua), UIParent's on Classic (set by its UIParent.xml).
---@param name string
---@return number
local function layoutAttribute(name)
  if GetUIPanelLayoutAttribute then
    return GetUIPanelLayoutAttribute(name)
  end
  return UIParent:GetAttribute(name)
end

---@param name string
---@param value number
local function setLayoutAttribute(name, value)
  if SetUIPanelLayoutAttribute then
    SetUIPanelLayoutAttribute(name, value)
  else
    UIParent:SetAttribute(name, value)
  end
end

-- panelAttribute reads one of a frame's attributes in the layout as the manager does (its local GetUIPanelAttribute):
-- the frame's own once they are set, else its UIPanelWindows entry's.
---@param frame Frame
---@param name string
---@return any
local function panelAttribute(frame, name)
  if frame:GetAttribute("UIPanelLayout-defined") then
    return frame:GetAttribute("UIPanelLayout-" .. name)
  end
  local attributes = UIPanelWindows[frame:GetName()]
  return attributes and attributes[name]
end

-- Room is how far from the left edge of the screen BetterBags Next covers, in UIParent's units, and the full companion
-- open: at its edge, its body, then its tabs with their hover slide (past a side rail standing outside it) or its
-- feather, whichever reaches further; the backpack chained beside it, past the backpack's body and its far feather
-- (next-chain.md §12). Its ribbon reaches further, in the title's row, above where Blizzard's panels start (TOP_OFFSET).
-- None beside the backpack on the right, or waiting to go there. No companion while none is open, or a small one.
---@return number room
---@return NextPanelFrame? companion
function uiPanels:Room()
  local companion = chain:Companion()
  if companion == nil or companion:IsSmall() then
    return 0, nil
  end
  if companion.waiting or chain:RestOffset(companion) ~= 0 then
    return 0, companion
  end
  local anchor, backpack = chain:Pair()
  if anchor == companion then
    return 2 * style.BODY_WIDTH + chain:Gap(companion, backpack) + style.Chain.OuterFeather, companion
  end
  return style.BODY_WIDTH + math.max(style.FEATHER, style.RAIL_OUT + companion.tabs:Width() + style.TAB_HOVER), companion
end

-- take makes frame take no room in the layout: the manager puts the panel after it at frame's place plus its width
-- there (times its scale), its x offset and the spacing between panels (PANEl_SPACING_X), so that width cancels the
-- other two. Blizzard also scales every open panel to fit the screen as the UI scale changes (UpdateScaleForFitForOpenPanels),
-- by the screen's width over its width plus checkFitExtraWidth (20 unless set): that one grows by what the width shrank,
-- so the frame is scaled as its own width says, never by a negative one. What they were is kept for giveBack.
---@private
---@param frame Frame
function uiPanels:take(frame)
  self.standIn = frame
  self.standInWidth = panelAttribute(frame, "width")
  self.standInFit = panelAttribute(frame, "checkFitExtraWidth")
  local width = -(layoutAttribute("PANEl_SPACING_X") + (panelAttribute(frame, "xoffset") or 0)) / frame:GetScale()
  SetUIPanelAttribute(frame, "width", width)
  SetUIPanelAttribute(frame, "checkFitExtraWidth", (self.standInFit or 20) + (self.standInWidth or frame:GetWidth()) - width)
end

-- giveBack gives the frame taken its width in the layout and its fit's back.
---@private
function uiPanels:giveBack()
  if self.standIn == nil then
    return
  end
  SetUIPanelAttribute(self.standIn, "width", self.standInWidth)
  SetUIPanelAttribute(self.standIn, "checkFitExtraWidth", self.standInFit)
  self.standIn, self.standInWidth, self.standInFit = nil, nil, nil
end

-- rightEdge is where the last of the panels the manager laid out from the left edge ends, in UIParent's units (its width
-- in the layout: a panel's own beside it included, the Dressing Room's outfit list); nil with none. The manager anchors
-- each by its top left to UIParent's, at its offset divided by its scale. The stand-in, taking no room, ends left of
-- where it starts: never last of several, and alone, left of anything that would hold the panels back.
---@private
---@return number?
function uiPanels:rightEdge()
  local right
  for _, key in ipairs(SLOTS) do
    local frame = GetUIPanel(key)
    if frame ~= nil then
      local point, relativeTo, relativePoint, x = frame:GetPoint(1)
      if point == "TOPLEFT" and relativePoint == "TOPLEFT" and (relativeTo == UIParent or relativeTo == "UIParent") then
        local r = x * frame:GetScale() + GetUIPanelWidth(frame)
        right = right ~= nil and math.max(right, r) or r
      end
    end
  end
  return right
end

-- Shift is how far Blizzard's panels go right now: past the room BetterBags Next covers (each as far from it as Blizzard
-- puts it from the screen's edge), but no further than leaves the last as far from the screen's right edge as LEFT_OFFSET
-- is from its left, and never left of where Blizzard puts them. With none open, the room: the first opens beside it.
---@return number
function uiPanels:Shift()
  if self.room == 0 then
    return 0
  end
  local right = self:rightEdge()
  if right == nil then
    return self.room
  end
  local base = self.base or layoutAttribute("LEFT_OFFSET")
  local free = UIParent:GetWidth() - base - (right - self.shift)
  return math.max(0, math.min(self.room, free))
end

-- Place moves Blizzard's panels by Shift when that changed: LEFT_OFFSET and RIGHT_OFFSET_BUFFER together from where they
-- were (back there at no shift), then the manager lays its panels out again. A classic client lays them out as each is
-- set (UIParent's OnAttributeChanged, UpdateUIPanelPositions.lua), so the one that leaves more room goes first: the
-- buffer as they move right, LEFT_OFFSET as they move back; in between, every panel fits that fits at either end. It
-- returns what it did, for profiler traces: "placed", or "same".
---@return string
function uiPanels:Place()
  local shift = self:Shift()
  if shift == self.shift then
    return "same"
  end
  if self.base == nil then
    self.base, self.buffer = layoutAttribute("LEFT_OFFSET"), layoutAttribute("RIGHT_OFFSET_BUFFER")
  end
  if shift > self.shift then
    setLayoutAttribute("RIGHT_OFFSET_BUFFER", self.buffer - shift)
    setLayoutAttribute("LEFT_OFFSET", self.base + shift)
  else
    setLayoutAttribute("LEFT_OFFSET", self.base + shift)
    setLayoutAttribute("RIGHT_OFFSET_BUFFER", self.buffer - shift)
  end
  if shift == 0 then
    self.base, self.buffer = nil, nil
  end
  self.shift = shift
  UpdateUIPanelPositions()
  return "placed"
end

-- PlaceLater places the panels again a frame later (Place), once: the manager has laid them out (a panel opened or
-- closed, one changed its width), and its layout must not run again from inside its own.
function uiPanels:PlaceLater()
  if self.room == 0 and self.shift == 0 then
    return
  end
  self.driver:SetScript("OnUpdate", function(driver)
    driver:SetScript("OnUpdate", nil)
    self:Place()
  end)
end

-- hook hooks every layout of the manager's, once (UpdateUIPanelPositions ends each), to place the panels again after.
---@private
function uiPanels:hook()
  if self.hooked ~= nil and self.hooked == UpdateUIPanelPositions then
    return
  end
  hooksecurefunc("UpdateUIPanelPositions", function() self:PlaceLater() end)
  self.hooked = UpdateUIPanelPositions
end

-- Update tells Blizzard's panel manager where BetterBags Next's panels are: when that changed since it last did, the frame
-- the full companion open stands in for takes no room (any other given its width back) and the manager lays its panels
-- out again; then they move by the shift (Place), which follows the screen's width too. NextChain updates it as its
-- panels open, close and move and as the screen changes, NextPanel as they switch size. It returns what it did, for
-- profiler traces: "placed", or "same".
---@return string
function uiPanels:Update()
  local room, companion = self:Room()
  local standIn = companion ~= nil and companion.standIn ~= nil and _G[companion.standIn] or nil
  if room == self.room and standIn == self.standIn then
    return self:Place()
  end
  if standIn ~= self.standIn then
    self:giveBack()
    if standIn ~= nil then
      self:take(standIn)
    end
  end
  self.room = room
  if room > 0 then
    self:hook()
  end
  UpdateUIPanelPositions()
  self:Place()
  return "placed"
end

uiPanels:Init()
