local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class SonataApply: AceModule
local apply = addon:GetModule('SonataApply')

-- SonataElements applies Sonata element styles: item button decorations, tabs (and their
-- states), section headers, the in-bag search box, the bag menu button, and dialog buttons
-- and edit boxes. A style sets everything it controls, falling back to Blizzard's own look
-- for what it leaves out (a part a style only partly describes keeps the rest of Blizzard's),
-- so a restyle never keeps anything of the previous theme. Template art a style hides is
-- hidden by alpha (its owner still shows and hides it) and gets its own alpha back when the
-- next style uses it; template regions a style changes are recorded the first time and put
-- back when a later style leaves them out.
---@class SonataElements: AceModule
local elements = addon:NewModule('SonataElements')

-- The keys that say what a texture draws. A style that gives any of them replaces all of the
-- default's, so a default atlas never wins over a style's file.
local ART_KEYS = { Texture = true, Atlas = true, Color = true }

-- The item button decoration's Blizzard look (ItemButton, ContainerFrameItemButtonTemplate),
-- with the pushed art BetterBags' blank decoration clears.
local ITEM_ICON = { Inset = 0, TexCoords = { 0, 1, 0, 1 } }
local ITEM_HIGHLIGHT = { Texture = "Interface\\Buttons\\ButtonHilight-Square", BlendMode = "ADD" }
local ITEM_PUSHED = { Texture = "", BlendMode = "BLEND" }
local ITEM_UPGRADE = { Atlas = "bags-greenarrow", Scale = 1 }
local ITEM_COUNT = { Font = { Object = "NumberFontNormal" }, Points = { { Point = "BOTTOMRIGHT", X = -5, Y = 2 } } }
local QUEST_BORDER = "Interface\\Common\\WhiteIconFrame"

-- PanelTabButtonTemplate's and BetterBags' Classic tab template's art, fonts and height, and
-- the text offsets PanelTemplates_SelectTab uses for a template without its own.
local TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
  "LeftHighlight", "MiddleHighlight", "RightHighlight" }
local TAB_IDLE = { "Left", "Middle", "Right" }
local TAB_ACTIVE = { "LeftActive", "MiddleActive", "RightActive" }
local TAB_STATES = { normal = true, selected = true, drop = true }
local TAB_FONT = { Object = "GameFontNormalSmall" }
local TAB_HIGHLIGHT_FONT = { Object = "GameFontHighlightSmall" }
local TAB_HEIGHT = 32

-- InputBoxVisualTemplate's art, and SearchBoxTemplate's (InputBoxInstructionsTemplate's) text
-- font, instruction text and text insets.
local INPUT_ART = { "Left", "Middle", "Right" }
local SEARCH_CAPS = { "Left", "Right" }
local SEARCH_FONT = { Object = "GameFontHighlightSmall" }
local SEARCH_INSTRUCTIONS = { Object = "GameFontDisableSmall", Color = { 0.35, 0.35, 0.35, 1 } }
local SEARCH_INSETS = { Left = 16, Right = 20, Top = 0, Bottom = 0 }

-- The bag menu button's portrait (Interface\Containerframe\Bagslots2x), drawn at OVERLAY 7.
local BAG_PORTRAIT = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0, 0.2, 0, 1 },
  Width = 48, Height = 60, Layer = "OVERLAY", SubLevel = 7 }
local BAG_HIGHLIGHT = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0.2, 0.3992, 0, 1 },
  Width = 48, Height = 60, X = 2, Layer = "OVERLAY", SubLevel = 7 }

-- withDefaults returns spec with every key it leaves out taken from default. A spec that says
-- what to draw (a file, atlas or color) takes none of the default's.
---@param spec? table
---@param default table
---@return table
local function withDefaults(spec, default)
  if type(spec) ~= "table" then
    return default
  end
  local ownArt = false
  for key in pairs(ART_KEYS) do
    if spec[key] ~= nil then
      ownArt = true
    end
  end
  local merged = {}
  for k, v in pairs(default) do
    if not (ownArt and ART_KEYS[k]) then
      merged[k] = v
    end
  end
  for k, v in pairs(spec) do
    merged[k] = v
  end
  return merged
end

-- insetOf reads an inset as one number for every side or { Left, Right, Top, Bottom }.
---@param value? number|table
---@return {Left: number, Right: number, Top: number, Bottom: number}
local function insetOf(value)
  if type(value) == "number" then
    return { Left = value, Right = value, Top = value, Bottom = value }
  end
  local i = type(value) == "table" and value or {}
  return { Left = i.Left or 0, Right = i.Right or 0, Top = i.Top or 0, Bottom = i.Bottom or 0 }
end

---@param frame Frame
---@return table
local function skinOf(frame)
  local skin = frame.sonataSkin
  if skin == nil then
    skin = {}
    frame.sonataSkin = skin
  end
  return skin
end

-- strip hides the named template regions by alpha, or gives them back the alpha they had.
---@param frame Frame
---@param keys string[]
---@param on boolean
local function strip(frame, keys, on)
  local saved = frame.sonataStripped
  if saved == nil then
    saved = {}
    frame.sonataStripped = saved
  end
  for _, key in ipairs(keys) do
    local region = frame[key]
    if region ~= nil then
      if on then
        if saved[key] == nil then
          saved[key] = region:GetAlpha()
        end
        region:SetAlpha(0)
      elseif saved[key] ~= nil then
        region:SetAlpha(saved[key])
        saved[key] = nil
      end
    end
  end
end

-- fill draws spec as a texture of frame, or hides it.
---@param frame Frame
---@param spec? table
---@param key string
---@param layer DrawLayer
---@param sublevel number
---@return Texture?
local function fill(frame, spec, key, layer, sublevel)
  local skin = frame.sonataSkin
  if type(spec) ~= "table" then
    if skin ~= nil and skin[key] ~= nil then
      skin[key]:Hide()
    end
    return nil
  end
  skin = skinOf(frame)
  local texture = skin[key]
  if texture == nil then
    texture = frame:CreateTexture(nil, layer, nil, sublevel)
    skin[key] = texture
  end
  apply:Texture(texture, setmetatable({ Layer = spec.Layer or layer, SubLevel = spec.SubLevel or sublevel }, { __index = spec }))
  if spec.Points ~= nil then
    apply:Points(texture, spec.Points, frame)
  else
    apply:Inset(texture, frame, insetOf(spec.Inset))
  end
  if spec.Height ~= nil then
    texture:SetHeight(spec.Height)
  end
  texture:Show()
  return texture
end

---@param frame Frame
---@param color? SonataColor
local function setEdgeColor(frame, color)
  local skin = frame.sonataSkin
  if skin == nil or skin.edges == nil then
    return
  end
  for _, edge in ipairs(skin.edges) do
    edge:SetColorTexture(apply:Color(color, { 0, 0, 0, 1 }))
  end
end

---@param frame Frame
---@return boolean
local function hasEdges(frame)
  local skin = frame.sonataSkin
  return skin ~= nil and skin.edges ~= nil and skin.edges[1]:IsShown()
end

-- edges draws a pixel border of four textures around frame (inset per side; negative is
-- outside), or hides it.
---@param frame Frame
---@param spec? {Color?: SonataColor, EdgeSize?: number, Inset?: number|table}
local function edges(frame, spec)
  local skin = frame.sonataSkin
  if type(spec) ~= "table" then
    if skin ~= nil and skin.edges ~= nil then
      for _, edge in ipairs(skin.edges) do
        edge:Hide()
      end
    end
    return
  end
  skin = skinOf(frame)
  if skin.edges == nil then
    skin.edges = {}
    for i = 1, 4 do
      skin.edges[i] = frame:CreateTexture(nil, "BORDER", nil, 7)
    end
  end
  local size = spec.EdgeSize or 1
  local i = insetOf(spec.Inset)
  local top, bottom, left, right = skin.edges[1], skin.edges[2], skin.edges[3], skin.edges[4]
  top:ClearAllPoints()
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", i.Left, -i.Top)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i.Right, -i.Top)
  top:SetHeight(size)
  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", i.Left, i.Bottom)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i.Right, i.Bottom)
  bottom:SetHeight(size)
  left:ClearAllPoints()
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", i.Left, -i.Top)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", i.Left, i.Bottom)
  left:SetWidth(size)
  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i.Right, -i.Top)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i.Right, i.Bottom)
  right:SetWidth(size)
  for _, edge in ipairs(skin.edges) do
    edge:Show()
  end
  setEdgeColor(frame, spec.Color)
end

-- captureRegion records everything a style can change on a template region.
---@param region Texture
---@return table
local function captureRegion(region)
  local points = {}
  for i = 1, region:GetNumPoints() do
    points[i] = { region:GetPoint(i) }
  end
  local layer, sublevel = region:GetDrawLayer()
  return {
    texture = region:GetTexture(),
    atlas = region:GetAtlas(),
    coords = { region:GetTexCoord() },
    color = { region:GetVertexColor() },
    blend = region:GetBlendMode(),
    alpha = region:GetAlpha(),
    layer = layer,
    sublevel = sublevel,
    desaturated = region:IsDesaturated(),
    horizTile = region:GetHorizTile(),
    vertTile = region:GetVertTile(),
    width = region:GetWidth(),
    height = region:GetHeight(),
    points = points,
  }
end

-- restoreRegion puts back what captureRegion recorded. An atlas is set after the coordinates
-- are reset and keeps its own (Blizzard's FrameCloneManager does the same).
---@param region Texture
---@param saved table
local function restoreRegion(region, saved)
  region:ClearTextureSlice()
  region:SetTexCoord(0, 1, 0, 1)
  if saved.atlas ~= nil then
    region:SetAtlas(saved.atlas)
  else
    region:SetTexture(saved.texture)
    region:SetTexCoord(unpack(saved.coords))
  end
  region:SetVertexColor(unpack(saved.color))
  region:SetBlendMode(saved.blend)
  region:SetAlpha(saved.alpha)
  region:SetDrawLayer(saved.layer, saved.sublevel)
  region:SetDesaturated(saved.desaturated)
  region:SetHorizTile(saved.horizTile)
  region:SetVertTile(saved.vertTile)
  region:SetSize(saved.width, saved.height)
  region:ClearAllPoints()
  for _, p in ipairs(saved.points) do
    region:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
end

-- styleRegion applies spec to a template region (recording it the first time), or puts the
-- region back when spec is nil.
---@param owner table
---@param key string
---@param region? Texture
---@param spec? table
---@param anchor Region
local function styleRegion(owner, key, region, spec, anchor)
  if region == nil then
    return
  end
  owner.sonataRegions = owner.sonataRegions or {}
  local saved = owner.sonataRegions[key]
  if type(spec) == "table" then
    if saved == nil then
      owner.sonataRegions[key] = captureRegion(region)
    end
    apply:Texture(region, spec)
    if spec.Points ~= nil then
      apply:Points(region, spec.Points, anchor)
    end
    if spec.Width ~= nil and spec.Height ~= nil then
      region:SetSize(spec.Width, spec.Height)
    elseif spec.Height ~= nil then
      region:SetHeight(spec.Height)
    end
  elseif saved ~= nil then
    restoreRegion(region, saved)
    owner.sonataRegions[key] = nil
  end
end

-- fontObjectFor returns a font object that looks like spec: its own object when it names
-- only one, else a font object made for it (one per distinct spec), so a button's state fonts
-- carry the whole look and hovering does not lose it.
local madeFonts = {}
local madeFontCount = 0
---@param spec SonataFont
---@return FontObject
local function fontObjectFor(spec)
  if spec.Path == nil and spec.Color == nil and spec.Shadow == nil and spec.Justify == nil then
    return apply:FontObject(spec.Object)
  end
  local shadow = spec.Shadow or {}
  local color = spec.Color or {}
  local shadowColor = shadow.Color or {}
  local key = table.concat({
    tostring(spec.Object), tostring(spec.Path), tostring(spec.Size), tostring(spec.Flags),
    tostring(color[1]), tostring(color[2]), tostring(color[3]), tostring(color[4]),
    tostring(spec.Shadow ~= nil), tostring(shadow.X), tostring(shadow.Y),
    tostring(shadowColor[1]), tostring(shadowColor[2]), tostring(shadowColor[3]), tostring(shadowColor[4]),
    tostring(spec.Justify),
  }, "|")
  local font = madeFonts[key]
  if font == nil then
    madeFontCount = madeFontCount + 1
    font = CreateFont("BetterBagsSonataFont" .. madeFontCount)
    if spec.Object ~= nil then
      font:CopyFontObject(apply:FontObject(spec.Object))
    end
    if spec.Path ~= nil then
      font:SetFont(spec.Path, spec.Size or 12, spec.Flags or "")
    end
    if spec.Color ~= nil then
      font:SetTextColor(apply:Color(spec.Color))
    end
    if spec.Shadow ~= nil then
      font:SetShadowColor(apply:Color(shadow.Color, { 0, 0, 0, 1 }))
      font:SetShadowOffset(shadow.X or 1, shadow.Y or -1)
    end
    if spec.Justify ~= nil then
      font:SetJustifyH(spec.Justify)
    end
    madeFonts[key] = font
  end
  return font
end

-- BetterBags Next's rounding while it is in use (docs/next-pixel-perfect.md, SetItemButtonSnap): Offset rounds
-- an offset and Length a length to whole screen pixels on a region's grid, Unit names that grid (a button
-- styled on it records it, sonataSnapUnit, so Next knows to style it again on another). Unset, every item
-- button part is placed as its style says.
---@alias SonataItemSnap {Offset: fun(region: ScriptRegion, units: number): number, Length: fun(region: ScriptRegion, units: number): number, Unit: fun(region: ScriptRegion): number}
---@type SonataItemSnap?
elements.itemSnap = nil

-- SetItemButtonSnap sets BetterBags Next's rounding (SonataNext, while Next is in use) or clears it, and
-- styles every item button again for it.
---@param snap? SonataItemSnap
function elements:SetItemButtonSnap(snap)
  if self.itemSnap == snap then
    return
  end
  self.itemSnap = snap
  if sonata.applied then
    sonata:restyleKind("ItemButton")
  end
end

-- snapAnchors anchors a region again by its points, each offset rounded (itemSnap); its points are
-- corners or edges of the item button, whose edges are on whole pixels.
---@param region Region
local function snapAnchors(region)
  local snap = elements.itemSnap
  local points = {}
  for i = 1, region:GetNumPoints() do
    points[i] = { region:GetPoint(i) }
  end
  region:ClearAllPoints()
  for _, p in ipairs(points) do
    region:SetPoint(p[1], p[2], p[3], snap.Offset(region, p[4] or 0), snap.Offset(region, p[5] or 0))
  end
end

---@param decoration ItemButton
---@param style table
function elements:StyleItemButton(decoration, style)
  decoration.sonataItemStyle = style
  local snap = self.itemSnap
  decoration.sonataSnapUnit = snap ~= nil and snap.Unit(decoration) or nil
  local icon = decoration.icon or decoration.IconTexture
  if icon ~= nil then
    local iconStyle = withDefaults(style.Icon, ITEM_ICON)
    local inset = iconStyle.Inset or 0
    if snap ~= nil then
      inset = snap.Offset(icon, inset)
    end
    icon:ClearAllPoints()
    if inset == 0 then
      icon:SetAllPoints(decoration)
    else
      icon:SetPoint("TOPLEFT", decoration, "TOPLEFT", inset, -inset)
      icon:SetPoint("BOTTOMRIGHT", decoration, "BOTTOMRIGHT", -inset, inset)
    end
    local coords = iconStyle.TexCoords
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  end

  apply:ButtonStates(decoration, {
    Highlight = withDefaults(style.Highlight, ITEM_HIGHLIGHT),
    Pushed = withDefaults(style.Pushed, ITEM_PUSHED),
  })

  local backdrop = type(style.Backdrop) == "table" and style.Backdrop or nil
  fill(decoration, backdrop and backdrop.Color and { Color = backdrop.Color, Inset = backdrop.Inset } or nil,
    "fill", "BACKGROUND", -8)
  local bordered = backdrop ~= nil and (backdrop.BorderColor ~= nil or backdrop.EdgeSize ~= nil)
  edges(decoration, bordered and { Color = backdrop.BorderColor, EdgeSize = backdrop.EdgeSize, Inset = backdrop.BorderInset } or nil)
  local skin = decoration.sonataSkin
  if snap ~= nil and skin ~= nil then
    if skin.fill ~= nil and skin.fill:IsShown() then
      snapAnchors(skin.fill)
    end
    for i, edge in ipairs(skin.edges or {}) do
      if edge:IsShown() then
        snapAnchors(edge)
        if i <= 2 then
          edge:SetHeight(snap.Length(edge, edge:GetHeight()))
        else
          edge:SetWidth(snap.Length(edge, edge:GetWidth()))
        end
      end
    end
  end

  local upgrade = decoration.UpgradeIcon
  if upgrade ~= nil then
    local spec = withDefaults(style.UpgradeIcon, ITEM_UPGRADE)
    if spec.Atlas ~= nil then
      upgrade:SetAtlas(spec.Atlas, true)
    else
      upgrade:SetTexture(spec.Texture)
    end
    upgrade:SetScale(spec.Scale or 1)
    if snap ~= nil then
      -- On its own grid, its scale included.
      upgrade:SetSize(snap.Length(upgrade, upgrade:GetWidth()), snap.Length(upgrade, upgrade:GetHeight()))
    end
  end

  local count = decoration.Count
  if count ~= nil then
    local spec = withDefaults(style.Count, ITEM_COUNT)
    apply:Font(count, spec.Font)
    apply:Points(count, spec.Points, decoration)
    if snap ~= nil then
      snapAnchors(count)
    end
  end
end

-- DrawItemQuality shows an item's quality on a decoration whose style draws it (on its
-- backdrop border) and returns true; it returns false for BetterBags' own quality glow.
---@param decoration ItemButton
---@param color? SonataColor The quality color, nil for none.
---@param quality? number The item's quality, for colors the style overrides.
---@return boolean
function elements:DrawItemQuality(decoration, color, quality)
  local style = decoration.sonataItemStyle
  if style == nil or style.QualityBorder ~= "Backdrop" or not hasEdges(decoration) then
    return false
  end
  if decoration.IconBorder ~= nil then
    decoration.IconBorder:Hide()
  end
  local override = quality ~= nil and style.QualityColors ~= nil and style.QualityColors[quality] or nil
  local backdrop = type(style.Backdrop) == "table" and style.Backdrop or {}
  setEdgeColor(decoration, override or color or backdrop.BorderColor)
  return true
end

-- DrawItemQuest swaps the art of the quest icon Blizzard just drew for a quest item for the
-- style's, and colors the border. It goes by the item's quest data: on Classic the quest
-- texture is shown on every button (ContainerFrame.xml gives it no hidden attribute).
---@param decoration ItemButton
---@param questInfo? {isQuestItem?: boolean, questID?: number, isActive?: boolean}
function elements:DrawItemQuest(decoration, questInfo)
  local style = decoration.sonataItemStyle
  if style == nil or questInfo == nil then
    return
  end
  local isQuest = questInfo.questID ~= nil or questInfo.isQuestItem == true
  if not isQuest then
    return
  end
  local starter = questInfo.questID ~= nil and not questInfo.isActive
  local quest = decoration.IconQuestTexture
  local art = (starter and style.QuestStarterIcon) or style.QuestIcon
  if quest ~= nil and type(art) == "table" then
    if art.Atlas ~= nil then
      quest:SetAtlas(art.Atlas)
    else
      quest:SetTexture(art.Texture)
    end
  end
  if style.QuestBorderColor ~= nil then
    if style.QualityBorder == "Backdrop" and hasEdges(decoration) then
      setEdgeColor(decoration, style.QuestBorderColor)
    elseif decoration.IconBorder ~= nil then
      local border = decoration.IconBorder
      border:SetTexture(QUEST_BORDER)
      border:SetBlendMode("BLEND")
      border:SetTexCoord(0, 1, 0, 1)
      border:SetVertexColor(apply:Color(style.QuestBorderColor))
      border:Show()
    end
  end
end

---@param decoration Button
---@param normal SonataFont
---@param highlight? SonataFont
local function tabFonts(decoration, normal, highlight)
  local normalObject = fontObjectFor(normal)
  local highlightObject = highlight and fontObjectFor(highlight) or normalObject
  decoration:SetNormalFontObject(normalObject)
  decoration:SetHighlightFontObject(highlightObject)
  if decoration.Text ~= nil then
    apply:Font(decoration.Text, { Object = normalObject })
  end
end

---@param decoration Button
---@param style table
function elements:StyleTab(decoration, style)
  decoration.sonataTabStyle = style
  local flat = style.Art == "Flat"
  strip(decoration, TAB_ART, flat)
  fill(decoration, flat and style.Background or nil, "fill", "BACKGROUND", -8)
  edges(decoration, flat and style.Border or nil)
  local selected = flat and type(style.Selected) == "table" and style.Selected or nil
  fill(decoration, selected and selected.Background or nil, "selectedFill", "BACKGROUND", -7)
  local bar = selected and selected.Bar
  if type(bar) == "table" then
    fill(decoration, setmetatable({
      Points = bar.Points or { { Point = "TOPLEFT", X = 1, Y = -2 }, { Point = "TOPRIGHT", X = -1, Y = -2 } },
    }, { __index = bar }), "bar", "OVERLAY", 6)
  else
    fill(decoration, nil, "bar", "OVERLAY", 6)
  end
  fill(decoration, flat and style.Hover or nil, "hover", "HIGHLIGHT", 0)
  decoration:SetHeight(style.Height or TAB_HEIGHT)
  self:SetTabState(decoration, decoration.sonataTabState or "normal")
end

-- SetTabState shows a tab as normal, selected, or a drop target (a section dragged over it,
-- which can be the selected tab).
---@param decoration Button
---@param state "normal"|"selected"|"drop"
function elements:SetTabState(decoration, state)
  if not TAB_STATES[state] then
    error("unknown tab state: " .. tostring(state))
  end
  local style = decoration.sonataTabStyle or {}
  local stored = decoration.sonataTabState or "normal"
  local selected = state == "selected" or (state == "drop" and stored == "selected")
  local active = state ~= "normal"
  for _, key in ipairs(TAB_IDLE) do
    if decoration[key] ~= nil then
      decoration[key]:SetShown(not selected)
    end
  end
  for _, key in ipairs(TAB_ACTIVE) do
    if decoration[key] ~= nil then
      decoration[key]:SetShown(active)
    end
  end

  local skin = decoration.sonataSkin
  if skin ~= nil then
    local selectedStyle = style.Art == "Flat" and type(style.Selected) == "table" and style.Selected or nil
    if skin.selectedFill ~= nil then
      skin.selectedFill:SetShown(active and selectedStyle ~= nil and selectedStyle.Background ~= nil)
    end
    if skin.bar ~= nil then
      skin.bar:SetShown(active and selectedStyle ~= nil and selectedStyle.Bar ~= nil)
    end
    local border = style.Art == "Flat" and type(style.Border) == "table" and style.Border or nil
    if border ~= nil then
      local selectedBorder = active and selectedStyle ~= nil and type(selectedStyle.Border) == "table"
        and selectedStyle.Border or nil
      setEdgeColor(decoration, (selectedBorder or border).Color)
    end
  end

  if state == "drop" then
    return
  end
  decoration.sonataTabState = state
  local offset
  local font = style.Font or TAB_FONT
  if state == "selected" then
    offset = style.SelectedTextOffset or { X = decoration.selectedTextX or 0, Y = decoration.selectedTextY or -3 }
    decoration:SetDisabledFontObject(GameFontHighlightSmall)
    tabFonts(decoration, style.SelectedFont or font, style.SelectedFont or style.HighlightFont or (style.Font == nil and TAB_HIGHLIGHT_FONT or nil))
  else
    offset = style.TextOffset or { X = decoration.deselectedTextX or 0, Y = decoration.deselectedTextY or 2 }
    decoration:Enable()
    tabFonts(decoration, font, style.HighlightFont or (style.Font == nil and TAB_HIGHLIGHT_FONT or nil))
  end
  if decoration.Text ~= nil then
    decoration.Text:ClearAllPoints()
    decoration.Text:SetPoint("CENTER", decoration, "CENTER", offset.X or 0, offset.Y or 0)
  end
end

-- GetTabState returns the state a tab was last set to: normal or selected (a drop target
-- keeps its state underneath).
---@param decoration Button
---@return "normal"|"selected"
function elements:GetTabState(decoration)
  return decoration.sonataTabState or "normal"
end

---@param fontString FontString
---@param style table
function elements:StyleSectionHeader(fontString, style)
  apply:Font(fontString, style.Font or { Object = "GameFontNormal" })
  fontString.sonataColor = { fontString:GetTextColor() }
end

-- GetSectionHeaderColor returns the color the theme gave a section header (its font's, or the
-- style's Color), which a title without a color of its own goes back to.
---@param fontString FontString
---@return number, number, number, number
function elements:GetSectionHeaderColor(fontString)
  local c = fontString.sonataColor
  if c == nil then
    local fontObject = fontString:GetFontObject()
    if fontObject == nil then
      return 1, 1, 1, 1
    end
    local r, g, b, a = fontObject:GetTextColor()
    return r, g, b, a or 1
  end
  return c[1], c[2], c[3], c[4] or 1
end

---@param box EditBox
---@param style table
function elements:StyleSearchBox(box, style)
  strip(box, INPUT_ART, style.Strip == true)
  if style.Strip ~= true then
    strip(box, SEARCH_CAPS, style.HideCaps == true)
  end
  styleRegion(box, "Middle", box.Middle, style.Middle, box)

  local icon = box.searchIcon
  if icon ~= nil then
    strip(box, { "searchIcon" }, style.SearchIcon == false)
    styleRegion(box, "searchIcon", icon, style.SearchIcon, box)
  end
  local clear = box.clearButton
  if clear ~= nil and clear.Icon ~= nil then
    local clearStyle = type(style.ClearButton) == "table" and style.ClearButton or nil
    styleRegion(clear, "Icon", clear.Icon, clearStyle and clearStyle.Icon, clear)
  end

  fill(box, style.Background, "fill", "BACKGROUND", -8)
  edges(box, style.Border)
  apply:Font(box, style.Font or SEARCH_FONT)
  local instructions = box.Instructions
  if instructions ~= nil then
    apply:Font(instructions, style.Instructions or SEARCH_INSTRUCTIONS)
    if style.InstructionsPoints ~= nil then
      if box.sonataInstructionPoints == nil then
        local points = {}
        for i = 1, instructions:GetNumPoints() do
          points[i] = { instructions:GetPoint(i) }
        end
        box.sonataInstructionPoints = points
      end
      apply:Points(instructions, style.InstructionsPoints, box)
    elseif box.sonataInstructionPoints ~= nil then
      instructions:ClearAllPoints()
      for _, p in ipairs(box.sonataInstructionPoints) do
        instructions:SetPoint(p[1], p[2], p[3], p[4], p[5])
      end
      box.sonataInstructionPoints = nil
    end
  end
  local insets = insetOf(style.TextInsets or SEARCH_INSETS)
  box:SetTextInsets(insets.Left, insets.Right, insets.Top, insets.Bottom)
end

---@param texture Texture
---@param spec table
---@param owner Frame
local function bagArt(texture, spec, owner)
  apply:Texture(texture, spec)
  texture:SetSize(spec.Width, spec.Height)
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", owner, "CENTER", spec.X or 0, spec.Y or 0)
end

-- StyleBagButton sizes the bag menu button (Size, or Width and Height), draws its portrait
-- and hover art (false hides either), and gives the button its own state art (States: Normal,
-- Highlight, Pushed, Disabled; a state left out is cleared).
---@param button Button
---@param style table
function elements:StyleBagButton(button, style)
  local size = style.Size or 40
  button:SetSize(style.Width or size, style.Height or size)
  if button.portrait ~= nil then
    if style.Portrait == false then
      button.portrait:Hide()
    else
      bagArt(button.portrait, withDefaults(style.Portrait, BAG_PORTRAIT), button)
      button.portrait:Show()
    end
  end
  if button.highlightTex ~= nil then
    if style.Highlight == false then
      button.highlightTex:Hide()
    else
      local alpha = button.highlightTex:GetAlpha()
      bagArt(button.highlightTex, withDefaults(style.Highlight, BAG_HIGHLIGHT), button)
      button.highlightTex:SetAlpha(alpha)
      button.highlightTex:Show()
    end
  end
  local states = type(style.States) == "table" and style.States or {}
  apply:ButtonStates(button, {
    Normal = states.Normal or false,
    Highlight = states.Highlight or false,
    Pushed = states.Pushed or false,
    Disabled = states.Disabled or false,
  })
end

-- captureFonts records a button's or edit box's own fonts the first time a style changes them.
---@param frame Button|EditBox
local function captureFonts(frame)
  if frame.sonataFonts ~= nil then
    return
  end
  frame.sonataFonts = {
    normal = frame.GetNormalFontObject and frame:GetNormalFontObject() or nil,
    highlight = frame.GetHighlightFontObject and frame:GetHighlightFontObject() or nil,
    disabled = frame.GetDisabledFontObject and frame:GetDisabledFontObject() or nil,
    font = frame.GetFontObject and frame:GetFontObject() or nil,
  }
end

-- hoverBorder colors a button's border style.HoverBorderColor while the mouse is over it. The
-- hooks are installed once; a style without the color leaves the border alone.
---@param button Button
---@param style table
local function hoverBorder(button, style)
  local border = type(style.Border) == "table" and style.Border or nil
  button.sonataHoverBorder = border and style.HoverBorderColor or nil
  button.sonataBorderColor = border and border.Color or nil
  if button.sonataHoverBorder == nil or button.sonataHoverHooked then
    return
  end
  button.sonataHoverHooked = true
  addon.HookScript(button, "OnEnter", function(_, b)
    if b.sonataHoverBorder ~= nil then
      setEdgeColor(b, b.sonataHoverBorder)
    end
  end)
  addon.HookScript(button, "OnLeave", function(_, b)
    if b.sonataHoverBorder ~= nil then
      setEdgeColor(b, b.sonataBorderColor)
    end
  end)
end

---@param button Button
---@param style table
function elements:StyleButton(button, style)
  if next(style) == nil and button.sonataSkin == nil and button.sonataStripped == nil and button.sonataFonts == nil
    and button.sonataRegions == nil and button.sonataHighlightAlpha == nil then
    return
  end
  strip(button, INPUT_ART, style.Strip == true)
  fill(button, style.Background, "fill", "BACKGROUND", -8)
  edges(button, style.Border)
  hoverBorder(button, style)

  local highlight = button:GetHighlightTexture()
  -- Highlight = false hides the highlight by alpha; it gets its alpha back with a later style.
  if style.Highlight == false and highlight ~= nil then
    if button.sonataHighlightAlpha == nil then
      button.sonataHighlightAlpha = highlight:GetAlpha()
    end
    highlight:SetAlpha(0)
  elseif button.sonataHighlightAlpha ~= nil and highlight ~= nil then
    highlight:SetAlpha(button.sonataHighlightAlpha)
    button.sonataHighlightAlpha = nil
  end
  if type(style.Highlight) == "table" then
    button.sonataRegions = button.sonataRegions or {}
    if button.sonataRegions.Highlight == nil and highlight ~= nil then
      button.sonataRegions.Highlight = captureRegion(highlight)
    end
    apply:ButtonStates(button, { Highlight = style.Highlight })
  elseif button.sonataRegions ~= nil and button.sonataRegions.Highlight ~= nil then
    local saved = button.sonataRegions.Highlight
    if saved.texture == nil and saved.atlas == nil then
      button:ClearHighlightTexture()
    else
      restoreRegion(highlight, saved)
    end
    button.sonataRegions.Highlight = nil
  end

  captureFonts(button)
  local fonts = button.sonataFonts
  local normal = style.Font and fontObjectFor(style.Font) or fonts.normal
  if normal ~= nil then
    button:SetNormalFontObject(normal)
  end
  local highlightFont = style.HighlightFont and fontObjectFor(style.HighlightFont) or fonts.highlight
  if highlightFont ~= nil then
    button:SetHighlightFontObject(highlightFont)
  end
  local disabled = style.DisabledFont and fontObjectFor(style.DisabledFont) or fonts.disabled
  if disabled ~= nil then
    button:SetDisabledFontObject(disabled)
  end
end

-- captureEditBoxLook records how an edit box's text looks, by value, before a style first changes
-- its font. Never by font object: an edit box from InputBoxTemplate reports a font object of its
-- own, and handing it back makes that font inherit from itself, which overflowed the client's
-- stack (issue #1152).
---@param box EditBox
local function captureEditBoxLook(box)
  if box.sonataLook ~= nil then
    return
  end
  local file, height, flags = box:GetFont()
  box.sonataLook = {
    file = file, height = height, flags = flags,
    color = { box:GetTextColor() },
    shadowColor = { box:GetShadowColor() },
    shadowOffset = { box:GetShadowOffset() },
    justify = box:GetJustifyH(),
  }
end

-- restoreEditBoxLook gives an edit box back the look captureEditBoxLook recorded.
---@param box EditBox
local function restoreEditBoxLook(box)
  local look = box.sonataLook
  box.sonataLook = nil
  if look.file ~= nil then
    box:SetFont(look.file, look.height, look.flags or "")
  end
  box:SetTextColor(unpack(look.color))
  box:SetShadowColor(unpack(look.shadowColor))
  box:SetShadowOffset(unpack(look.shadowOffset))
  if look.justify ~= nil then
    box:SetJustifyH(look.justify)
  end
end

---@param box EditBox
---@param style table
function elements:StyleEditBox(box, style)
  if next(style) == nil and box.sonataSkin == nil and box.sonataStripped == nil and box.sonataLook == nil then
    return
  end
  strip(box, INPUT_ART, style.Strip == true)
  fill(box, style.Background, "fill", "BACKGROUND", -8)
  edges(box, style.Border)
  if style.Font ~= nil then
    captureEditBoxLook(box)
    apply:Font(box, style.Font)
  elseif box.sonataLook ~= nil then
    restoreEditBoxLook(box)
  end
end

sonata:SetElementStyler("ItemButton", function(element, style) elements:StyleItemButton(element, style) end)
sonata:SetElementStyler("Tab", function(element, style) elements:StyleTab(element, style) end)
sonata:SetElementStyler("SectionHeader", function(element, style) elements:StyleSectionHeader(element, style) end)
sonata:SetElementStyler("SearchBox", function(element, style) elements:StyleSearchBox(element, style) end)
sonata:SetElementStyler("BagButton", function(element, style) elements:StyleBagButton(element, style) end)
sonata:SetElementStyler("Button", function(element, style) elements:StyleButton(element, style) end)
sonata:SetElementStyler("EditBox", function(element, style) elements:StyleEditBox(element, style) end)
