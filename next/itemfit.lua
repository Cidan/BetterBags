local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextItemFit puts the parts of the item buttons BetterBags Next draws on whole screen pixels
-- (docs/next-pixel-perfect.md). Sonata's item button styler rounds what it places while Next is in use (the
-- icon's inset, the count, a backdrop and its edges, the upgrade arrow: SonataElements:SetItemButtonSnap).
-- The rest are the template's own parts, placed in UI units by Blizzard's XML (ItemButtonTemplate.xml,
-- ContainerFrame.xml) or by frames/item.lua, between pixels wherever a unit is not a whole pixel: Fit places
-- them in whole pixels on the button's grid, remembering where they were, and Restore puts them back for the
-- classic bags, which share the item buttons.
---@class NextItemFit: AceModule
local itemFit = addon:NewModule('NextItemFit')

-- Parts placed from a corner at their template's offset, rounded, their size (when set) in whole pixels.
local FROM_CORNER = { "Stock", "JunkIcon" }
-- Parts that fill the button: the quality border, the icon overlay and the quest art, sized to the button by
-- frames/item.lua and anchored by their middle or top middle (37 x 37, 37 x 38 in the template).
local FILLING = { "IconBorder", "IconOverlay", "IconQuestTexture" }
-- Parts centered on the button at their own size: the template's second overlay and glows, the empty slot's
-- family glyph (frames/item.lua), the extended slot's frame.
local CENTERED = { "IconOverlay2", "flash", "NewItemTexture", "ExtendedSlot", "BetterBagsFamilyIcon" }

-- The buttons Fit placed parts of, and where those parts were: Restore puts them back.
itemFit.saved = setmetatable({}, { __mode = "k" }) ---@type table<Frame, table<Region, table>>
itemFit.keys = setmetatable({}, { __mode = "k" }) ---@type table<Frame, string>

-- remember records where a region is, once: its points and its size.
---@param saved table<Region, table>
---@param region Region
---@return table
local function remember(saved, region)
  local was = saved[region]
  if was == nil then
    local points = {}
    for i = 1, region:GetNumPoints() do
      points[i] = { region:GetPoint(i) }
    end
    was = { points = points, width = region:GetWidth(), height = region:GetHeight() }
    saved[region] = was
  end
  return was
end

-- fromCorner anchors a region by its template point, at its template offset rounded to whole pixels, its
-- size (when it has one) in whole pixels.
---@param saved table<Region, table>
---@param region Region
local function fromCorner(saved, region)
  local was = remember(saved, region)
  local p = was.points[1]
  if p == nil then
    return
  end
  region:ClearAllPoints()
  region:SetPoint(p[1], p[2], p[3], pixel:Snap(region, p[4] or 0), pixel:Snap(region, p[5] or 0))
  if was.width > 0 and was.height > 0 then
    pixel:Size(region, was.width, was.height)
  end
end

-- center anchors a region by its top left so it sits in the middle of the button at its own size (its
-- template offset from the middle kept), on whole pixels.
---@param saved table<Region, table>
---@param region Region
---@param button Frame
---@param width number
---@param height number
local function center(saved, region, button, width, height)
  local was = remember(saved, region)
  local p = was.points[1]
  region:ClearAllPoints()
  pixel:Center(region, button, button:GetWidth(), button:GetHeight(), width, height, p and p[4] or 0, p and p[5] or 0)
end

-- Fit places the parts of an item button BetterBags Next draws in whole pixels on its grid, once per grid,
-- size and Sonata theme generation (the styler may have placed them again). decoration is what draws the
-- item (frames/item.lua's decoration, or a guild bank button); extras are parts of other frames placed
-- from a corner (the item level text, on the interaction button). On a grid it was not styled on (it waits
-- unparented until drawn; a Bag Scale; a dock card's scale), Sonata styles it again, rounding its parts to
-- this one, and item/Updated says so (Masque skins it again on it, as after every theme). It returns what it
-- did, for profiler traces: "kept" or "placed".
---@param ctx Context
---@param decoration Frame
---@param extras? Region[]
---@param item? table The item button the decoration draws, for item/Updated.
---@return string
function itemFit:Fit(ctx, decoration, extras, item)
  local sonata = addon:GetModule('Sonata', true)
  local unit = pixel:Unit(decoration)
  local key = string.format("%.9f:%.4f:%.4f:%s", unit, decoration:GetWidth(), decoration:GetHeight(),
    tostring(sonata and sonata:GetGeneration() or 0))
  if self.keys[decoration] == key then
    return "kept"
  end
  -- Sonata records the grid it rounded the button's parts on (SonataElements.itemSnap).
  local styled = decoration.sonataSnapUnit
  if sonata ~= nil and (styled == nil or math.abs(styled - unit) > 1e-9) then
    if sonata:RestyleElement("ItemButton", decoration) and item ~= nil then
      addon:GetModule('Events'):SendMessage(ctx, "item/Updated", item, decoration)
    end
  end
  local saved = self.saved[decoration] or {}
  self.saved[decoration] = saved
  for _, name in ipairs(FROM_CORNER) do
    local region = decoration[name]
    if region ~= nil then
      fromCorner(saved, region)
    end
  end
  for _, region in ipairs(extras or {}) do
    fromCorner(saved, region)
  end
  for _, name in ipairs(FILLING) do
    local region = decoration[name]
    if region ~= nil then
      remember(saved, region)
      region:ClearAllPoints()
      region:SetAllPoints(decoration)
    end
  end
  for _, name in ipairs(CENTERED) do
    local region = decoration[name]
    if region ~= nil then
      local was = remember(saved, region)
      center(saved, region, decoration, was.width, was.height)
    end
  end
  -- The Blizzard Store's highlight has no size of its own (Blizzard draws it at its image's size, which no
  -- API can read): it takes the new-item glow's box, the glow it shows in place of.
  local store, glow = decoration.BattlepayItemTexture, decoration.NewItemTexture
  if store ~= nil and glow ~= nil then
    local was = remember(saved, glow)
    center(saved, store, decoration, was.width, was.height)
  end
  self.keys[decoration] = key
  return "placed"
end

-- Restore puts a button's parts back where they were before Fit (the classic bags draw it now).
---@param decoration Frame
function itemFit:Restore(decoration)
  local saved = self.saved[decoration]
  if saved == nil then
    return
  end
  for region, was in pairs(saved) do
    region:ClearAllPoints()
    for _, p in ipairs(was.points) do
      region:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
    region:SetSize(was.width, was.height)
  end
  self.saved[decoration] = nil
  self.keys[decoration] = nil
end

-- RestoreAll puts every fitted button's parts back (BetterBags Next is no longer the design in use).
function itemFit:RestoreAll()
  local list = {}
  for decoration in pairs(self.saved) do
    table.insert(list, decoration)
  end
  for _, decoration in ipairs(list) do
    self:Restore(decoration)
  end
end
