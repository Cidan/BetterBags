local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- PixelAudit holds BetterBags Next to the screen's pixel grid (next-pixel-perfect.md) in game: Check lists the
-- shown parts of a window that are not on whole screen pixels. It reads only what the client gives an addon
-- (where a region is, GetScaledRect; its anchors; its regions and children; whether it shows), so it judges the
-- real layout: real fonts, art, Blizzard's templates, other addons. The specs run the same check
-- (spec/helpers/layout.lua, PixelCheck), the mock answering those calls from its own layout resolver.
---@class PixelAudit: AceModule
local audit = addon:NewModule('PixelAudit')

-- What draws, so its own edges must be on the grid: textures, lines, text, edit boxes. A frame draws nothing
-- itself unless it clips its children (its edges cut what is inside).
local DRAWS = { Texture = true, Line = true, MaskTexture = true, FontString = true, EditBox = true }

-- Which edge or middle of a rect each anchor point is on.
local H_SIDE = {
  TOPLEFT = "left", LEFT = "left", BOTTOMLEFT = "left",
  TOPRIGHT = "right", RIGHT = "right", BOTTOMRIGHT = "right",
  TOP = "middle", CENTER = "middle", BOTTOM = "middle",
}
local V_SIDE = {
  TOPLEFT = "top", TOP = "top", TOPRIGHT = "top",
  BOTTOMLEFT = "bottom", BOTTOM = "bottom", BOTTOMRIGHT = "bottom",
  LEFT = "middle", CENTER = "middle", RIGHT = "middle",
}

local SIDES = { "left", "right", "top", "bottom" }

---@param r table { left, right, top, bottom }
---@param point string
---@return number x, number y
local function pointOf(r, point)
  local h, v = H_SIDE[point], V_SIDE[point]
  local x = (h == "left" and r.left) or (h == "right" and r.right) or (r.left + r.right) / 2
  local y = (v == "top" and r.top) or (v == "bottom" and r.bottom) or (r.top + r.bottom) / 2
  return x, y
end

local function onPixel(value)
  return math.abs(value - math.floor(value + 0.5)) < 1e-3
end

-- visible says whether a region draws: shown with every parent, and neither it nor a parent at alpha 0 (a
-- template's art hidden that way, a glow before it is lit).
---@param region ScriptRegion
---@return boolean
local function visible(region)
  if not region:IsVisible() then
    return false
  end
  local r = region
  while r ~= nil do
    if r:GetAlpha() == 0 then
      return false
    end
    r = r:GetParent()
  end
  return true
end

---@param region ScriptRegion
---@return boolean
local function isFrame(region)
  return region:IsObjectType("Frame")
end

---@param value any
---@return boolean
local function isRegion(value)
  return type(value) == "table" and type(value.IsObjectType) == "function"
end

-- rectOf is where the client puts a region, in UI units at scale 1 (GetScaledRect: its own units times its
-- effective scale, Blizzard's RegionUtil.GetRegionPoint), or nil while it is not placed. warcraft.wiki.gg
-- ScriptRegion:GetRect: not allowed on restricted frames, so a refusal is nil too.
---@param region ScriptRegion
---@return table?
local function rectOf(region)
  local ok, left, bottom, width, height = pcall(region.GetScaledRect, region)
  if not ok or left == nil then
    return nil
  end
  return { left = left, right = left + width, bottom = bottom, top = bottom + height }
end

-- names maps regions to the field paths owner tables reach them by (for messages).
---@param owners? table<string, table>
---@return table<table, string>
local function names(owners)
  local map, seen = {}, {}
  local function walk(t, path, depth)
    if type(t) ~= "table" or seen[t] or depth > 4 then
      return
    end
    seen[t] = true
    for k, v in pairs(t) do
      if type(v) == "table" and type(k) == "string" and k:sub(1, 1) ~= "_" then
        local p = path .. "." .. k
        if map[v] == nil and isRegion(v) then
          map[v] = p
        end
        walk(v, p, depth + 1)
      elseif type(v) == "table" and type(k) == "number" then
        walk(v, path .. "[" .. k .. "]", depth + 1)
      end
    end
  end
  for name, owner in pairs(owners or {}) do
    walk(owner, name, 0)
  end
  return map
end

-- fieldsOf maps the regions a frame keeps in its own fields (a template's parentKeys, a button's state art)
-- to their keys.
---@param frame table
---@return table<table, string>
local function fieldsOf(frame)
  local map = {}
  for k, v in pairs(frame) do
    if type(k) == "string" and k:sub(1, 1) ~= "_" and isRegion(v) and map[v] == nil then
      map[v] = k
    end
  end
  return map
end

-- Check lists every shown part under root that draws and is not on whole screen pixels: a texture's, an edit
-- box's or a clipping frame's four edges, an edit box's text insets, a font string's anchor points (its far
-- edges are its text's measure). A part the client does not place is skipped, as is everything under a region
-- in skip. owners (name -> table) name the parts in the messages; a part no owner reaches is named by the field
-- its parent keeps it in, else by its place in the tree. It returns one string per part.
---@param root ScriptRegion
---@param opts? { skip?: table<table, boolean>, owners?: table<string, table> }
---@return string[]
function audit:Check(root, opts)
  opts = opts or {}
  local skip, named = opts.skip or {}, names(opts.owners)
  local k = 1 / PixelUtil.GetPixelToUIUnitFactor()
  local problems = {}
  local function check(region, path)
    if skip[region] or not visible(region) then
      return
    end
    local frame = isFrame(region)
    local r = (DRAWS[region:GetObjectType()] or (frame and region:DoesClipChildren())) and rectOf(region) or nil
    if r ~= nil then
      local bad = {}
      if region:GetObjectType() == "FontString" then
        for i = 1, region:GetNumPoints() do
          local point = region:GetPoint(i)
          local x, y = pointOf(r, point)
          if not onPixel(x * k) then
            table.insert(bad, string.format("%s x %.3f", point, x * k))
          end
          if not onPixel(y * k) then
            table.insert(bad, string.format("%s y %.3f", point, y * k))
          end
        end
      else
        for _, side in ipairs(SIDES) do
          if not onPixel(r[side] * k) then
            table.insert(bad, string.format("%s %.3f", side, r[side] * k))
          end
        end
      end
      -- An edit box draws its text inside its insets, in its own units (SetTextInsets).
      if region:GetObjectType() == "EditBox" then
        local s = region:GetEffectiveScale()
        local insets = { region:GetTextInsets() }
        for i, side in ipairs(SIDES) do
          if not onPixel(insets[i] * s * k) then
            table.insert(bad, string.format("text inset %s %.3f", side, insets[i] * s * k))
          end
        end
      end
      if #bad > 0 then
        local label = named[region] or ((region:GetName() or region:GetObjectType()) .. " " .. path)
        table.insert(problems, label .. ": " .. table.concat(bad, ", "))
      end
    end
    if not frame then
      return
    end
    local keys = fieldsOf(region)
    local textures, texts = 0, 0
    for _, child in ipairs({ region:GetRegions() }) do
      local segment
      if child:GetObjectType() == "FontString" then
        texts = texts + 1
        segment = "s" .. texts
      else
        textures = textures + 1
        segment = "t" .. textures
      end
      check(child, path .. ">" .. (keys[child] or segment))
    end
    for i, child in ipairs({ region:GetChildren() }) do
      check(child, path .. ">" .. (keys[child] or i))
    end
  end
  check(root, "")
  return problems
end
