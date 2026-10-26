local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextGlitch draws a panel's glitches (the Glitch theme, next-themes.md §21; asked: "the bag sort of glitches into
-- existence when opening, glitches out when closing. think flickers, glitched blinking textures that wobble suddenly and
-- harshly"): a CRT's beam (opening to the panel's size as it warms up, squashing to a line and a point as it turns
-- off), and a glitch's moments, each rolled anew: bands of a frame tearing across the body, datamosh blocks, static, the
-- title's colours splitting and its letters corrupting, sections shoved sideways. The panel drives them (next/panel.lua:
-- its open, its close, its bursts while open) and applies what a moment asks of the panel itself (a jump, a flicker).
-- Everything is drawn on the panel's glitch layer: a frame over its content that takes no mouse and is drawn at its own
-- alpha, so a glitch shows while the panel flickers to nothing. A theme without Panel.Glitch has none.
---@class NextGlitch: AceModule
local glitch = addon:NewModule('NextGlitch')

-- Where a glitch takes its randomness (a source of numbers in [0, 1)): replaced by the specs.
glitch.Random = math.random

-- The keys of Panel.Glitch, for SonataNext:Check.
glitch.KEYS = { Open = true, Close = true, Bursts = true, Step = true, Jitter = true, Flicker = true, Sections = true,
  Ghosts = true, Tears = true, Blocks = true, Noise = true, Corrupt = true, Beam = true }

-- One UTF-8 character.
local CHARACTER = "[%z\1-\127\194-\244][\128-\191]*"

-- How far above the panel's frame the layer is: over its content (sections and their item buttons are a few levels
-- deep), its overlay (20) and its sparkles (50).
local LAYER_LEVEL = 100

---@class (exact) NextGlitchLayer
---@field frame Frame Over the panel's body, drawn at its own alpha, taking no mouse.
---@field beam Texture The CRT's beam.
---@field noise Texture Static over the body.
---@field tears Texture[] Bands of a frame tearing across the body.
---@field blocks Texture[] Datamosh blocks.
---@field sections table<Frame, AnimationGroup> Each section's shove, made the first time it is shoved.
---@field corrupted boolean The title shows corrupted letters.

-- Spec returns the theme's Panel.Glitch, nil without one.
---@return table?
function glitch:Spec()
  return style.Theme.Panel.Glitch or nil
end

-- Opens says whether the theme's panels glitch open instead of sliding in; Closes, out.
---@return boolean
function glitch:Opens()
  local G = self:Spec()
  return G ~= nil and G.Open ~= nil
end

---@return boolean
function glitch:Closes()
  local G = self:Spec()
  return G ~= nil and G.Close ~= nil
end

-- Layer returns a panel's glitch layer, made the first time: a child of the panel's frame (it moves with it, and hides
-- with it), over its body, at its own alpha.
---@param panel table
---@return NextGlitchLayer
function glitch:Layer(panel)
  local L = panel.glitch
  if L ~= nil then
    return L
  end
  local frame = CreateFrame("Frame", nil, panel.frame)
  frame:SetAllPoints(panel.body)
  frame:SetFrameLevel(panel.frame:GetFrameLevel() + LAYER_LEVEL)
  frame:SetIgnoreParentAlpha(true)
  frame:EnableMouse(false)
  frame:Hide()
  L = {
    frame = frame,
    beam = frame:CreateTexture(nil, "OVERLAY"),
    noise = frame:CreateTexture(nil, "ARTWORK", nil, -1),
    tears = {},
    blocks = {},
    sections = setmetatable({}, { __mode = "k" }),
    corrupted = false,
  }
  L.beam:Hide()
  L.noise:Hide()
  panel.glitch = L
  return L
end

-- between is a number in a { least, most } range.
---@param range number[]
---@return number
local function between(range)
  return range[1] + (range[2] - range[1]) * glitch.Random()
end

-- either is a number from -1 to 1.
---@return number
local function either()
  return 2 * glitch.Random() - 1
end

-- texturesOf returns the first n textures of a pool on the layer, made as needed, and hides the rest.
---@param L NextGlitchLayer
---@param pool Texture[]
---@param n number
---@param layer DrawLayer
---@return Texture[]
local function texturesOf(L, pool, n, layer)
  for i = 1, n do
    if pool[i] == nil then
      pool[i] = L.frame:CreateTexture(nil, layer)
    end
  end
  for i = n + 1, #pool do
    pool[i]:Hide()
  end
  return pool
end

-- countOf is how many of something show at strength: Count of them at full strength, fewer as it weakens, rounded at
-- random.
---@param count number
---@param strength number
---@return number
local function countOf(count, strength)
  return math.floor(count * strength + glitch.Random())
end

-- tear draws bands of a frame tearing across the body: as wide as a third of it to more than all of it, from up to a
-- fifth of it out on the inner side, Height tall, at a random height, their art slipped.
---@private
---@param L NextGlitchLayer
---@param T table
---@param strength number
function glitch:tear(L, T, strength)
  local n = countOf(T.Count or 0, strength)
  local body = L.frame
  local w, h = body:GetWidth(), body:GetHeight()
  for i, t in ipairs(texturesOf(L, L.tears, n, "OVERLAY")) do
    if i <= n then
      style:Paint(t, { Texture = T.Texture, Color = T.Color or "White", BlendMode = T.BlendMode })
      local width = w * (0.35 + 0.9 * self.Random())
      local height = between(T.Height or { 2, 8 })
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", body, "TOPLEFT", pixel:Snap(t, w * (0.75 * self.Random() - 0.2)),
        -pixel:Snap(t, (h - height) * self.Random()))
      pixel:Size(t, width, height)
      local u = self.Random()
      t:SetTexCoord(u, u + 0.4 + 0.6 * self.Random(), 0, 1)
      t:SetAlpha((T.Alpha or 1) * (0.5 + 0.5 * self.Random()))
      t:Show()
    end
  end
end

-- block draws datamosh blocks: squares of Size, anywhere on the body, in one of their Colors.
---@private
---@param L NextGlitchLayer
---@param B table
---@param strength number
function glitch:block(L, B, strength)
  local n = countOf(B.Count or 0, strength)
  local body = L.frame
  local w, h = body:GetWidth(), body:GetHeight()
  local colors = B.Colors or { "White" }
  for i, t in ipairs(texturesOf(L, L.blocks, n, "ARTWORK")) do
    if i <= n then
      local color = colors[math.min(#colors, math.floor(self.Random() * #colors) + 1)]
      style:Paint(t, { Texture = B.Texture, Color = color, BlendMode = B.BlendMode })
      local size = between(B.Size or { 16, 64 })
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", body, "TOPLEFT", pixel:Snap(t, (w - size) * self.Random()), -pixel:Snap(t, (h - size) * self.Random()))
      pixel:Size(t, size, size * (0.3 + 0.7 * self.Random()))
      local u, v = self.Random(), self.Random()
      t:SetTexCoord(u, u + 0.5, v, v + 0.5)
      t:SetAlpha((B.Alpha or 1) * (0.4 + 0.6 * self.Random()))
      t:Show()
    end
  end
end

-- static draws the noise over the body, its art jumping to a new place each moment, as strong as the moment.
---@private
---@param L NextGlitchLayer
---@param N table
---@param strength number
function glitch:static(L, N, strength)
  local t = L.noise
  style:Paint(t, { Texture = N.Texture, Color = N.Color or "White", BlendMode = N.BlendMode })
  t:SetAllPoints(L.frame)
  local u, v = self.Random(), self.Random()
  local scale = 0.75 + 0.5 * self.Random()
  t:SetTexCoord(u, u + scale * L.frame:GetWidth() / 128, v, v + scale * L.frame:GetHeight() / 128)
  t:SetAlpha((N.Alpha or 0.2) * strength)
  t:Show()
end

-- corrupt swaps the letters of a text for Glyphs, each at chance, keeping spaces and the text's length (a letter, and a
-- glyph, is one UTF-8 character).
---@param text string
---@param glyphs string
---@param chance number
---@return string
function glitch:Corrupt(text, glyphs, chance)
  local swaps = {}
  for ch in glyphs:gmatch(CHARACTER) do
    swaps[#swaps + 1] = ch
  end
  local out = {}
  for ch in text:gmatch(CHARACTER) do
    if ch ~= " " and self.Random() < chance then
      ch = swaps[math.min(#swaps, math.floor(self.Random() * #swaps) + 1)]
    end
    out[#out + 1] = ch
  end
  return table.concat(out)
end

-- shove pushes a section's frame dx sideways at once, held until the next moment (a Translation of no time, then one
-- holding it, on the client's animations: they move what is drawn, not where the frame is laid out), or back.
---@private
---@param L NextGlitchLayer
---@param frame Frame
---@param dx number
function glitch:shove(L, frame, dx)
  local g = L.sections[frame]
  if dx == 0 then
    if g ~= nil then
      g:Stop()
    end
    return
  end
  if g == nil then
    g = frame:CreateAnimationGroup()
    local jump = g:CreateAnimation("Translation")
    jump:SetDuration(0.001)
    jump:SetOrder(1)
    local hold = g:CreateAnimation("Translation")
    hold:SetOffset(0, 0)
    hold:SetDuration(10)
    hold:SetOrder(2)
    g.jump = jump
    L.sections[frame] = g
  end
  g:Stop()
  g.jump:SetOffset(dx, 0)
  g:Play()
end

-- Roll draws one moment of a glitch at strength (0: none, 1: full): tears, blocks, static; the title's colour ghosts
-- split up to Ghosts either way and its letters corrupted (Corrupt: each at Chance times the strength; never a title the
-- panel may not read, a secret); and, with displace, a third of its sections shoved up to Sections sideways. It
-- returns how far the panel jumps sideways (up to Jitter, on whole pixels; with displace), and, with flicker, the alpha
-- it flickers to (lit, or dark at Flicker[1], seen more often as the strength falls).
---@param panel table
---@param strength number
---@param displace boolean
---@param flicker boolean
---@return number dx
---@return number alpha
function glitch:Roll(panel, strength, displace, flicker)
  local G = self:Spec()
  if G == nil then
    -- Its theme went while it glitched (another theme, Glitch Effects off): at rest from here on.
    self:Rest(panel)
    return 0, 1
  end
  local L = self:Layer(panel)
  L.frame:Show()
  L.beam:Hide()
  if G.Tears then
    self:tear(L, G.Tears, strength)
  end
  if G.Blocks then
    self:block(L, G.Blocks, strength)
  end
  if G.Noise then
    self:static(L, G.Noise, strength)
  end
  if G.Ghosts and panel.PlaceGhosts then
    local spread = {}
    for i = 1, #(panel.ghosts or {}) do
      spread[i] = either() * G.Ghosts * strength
    end
    panel:PlaceGhosts(spread)
  end
  local text = panel.titleText
  if G.Corrupt and text ~= nil and not (issecretvalue ~= nil and issecretvalue(text)) then
    panel:ShowTitle(self:Corrupt(text, G.Corrupt.Glyphs, (G.Corrupt.Chance or 0) * strength))
    L.corrupted = true
  end
  local dx = 0
  if displace then
    if G.Sections and panel.content ~= nil then
      for _, section in ipairs(panel.content.order or {}) do
        local frame = section.frame
        if self.Random() < 0.35 * strength then
          self:shove(L, frame, pixel:Snap(frame, either() * G.Sections * strength))
        else
          self:shove(L, frame, 0)
        end
      end
    end
    if G.Jitter then
      dx = pixel:Snap(panel.frame, either() * G.Jitter * strength)
    end
  end
  local alpha = 1
  if flicker and G.Flicker then
    alpha = self.Random() < 1 - 0.7 * strength and G.Flicker[2] or G.Flicker[1]
  end
  return dx, alpha
end

-- Beam draws the CRT's line over the body's middle: across of its width, down of its height (never thinner than Height),
-- at alpha of its own. The moments' parts hide while it shows.
---@param panel table
---@param across number
---@param down number
---@param alpha number
function glitch:Beam(panel, across, down, alpha)
  local G = self:Spec()
  if G == nil then
    self:Rest(panel)
    return
  end
  local L = self:Layer(panel)
  local B = G.Beam or {}
  L.frame:Show()
  self:quiet(L)
  local beam = L.beam
  style:Paint(beam, { Color = B.Color or "White", BlendMode = B.BlendMode })
  local w, h = L.frame:GetWidth(), L.frame:GetHeight()
  local thin = pixel:Length(beam, B.Height or 2)
  beam:ClearAllPoints()
  beam:SetPoint("CENTER", L.frame, "CENTER", 0, 0)
  beam:SetSize(math.max(pixel:Unit(beam), w * math.max(0, math.min(1, across))), math.max(thin, h * math.max(0, math.min(1, down))))
  beam:SetAlpha((B.Alpha or 1) * alpha)
  beam:Show()
end

-- quiet hides what a moment drew on the layer.
---@private
---@param L NextGlitchLayer
function glitch:quiet(L)
  for _, t in ipairs(L.tears) do
    t:Hide()
  end
  for _, t in ipairs(L.blocks) do
    t:Hide()
  end
  L.noise:Hide()
end

-- Rest puts a panel back as it is without a glitch: its layer hidden, its sections where they belong, its title's ghosts
-- beside it and its letters as they are.
---@param panel table
function glitch:Rest(panel)
  local L = panel.glitch
  if L == nil then
    return
  end
  self:quiet(L)
  L.beam:Hide()
  L.frame:Hide()
  for frame in pairs(L.sections) do
    self:shove(L, frame, 0)
  end
  if panel.PlaceGhosts then
    panel:PlaceGhosts(nil)
  end
  if L.corrupted then
    L.corrupted = false
    panel:ShowTitle(panel.titleText)
  end
end
