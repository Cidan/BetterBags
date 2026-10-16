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
-- for what it leaves out, so a restyle never keeps anything of the previous theme. Template
-- art a style hides is hidden by alpha (its owner still shows and hides it) and gets its own
-- alpha back when the next style uses it.
---@class SonataElements: AceModule
local elements = addon:NewModule('SonataElements')

-- The item button decoration's Blizzard look (ItemButton, ContainerFrameItemButtonTemplate),
-- with the pushed art BetterBags' blank decoration clears.
local ITEM_HIGHLIGHT = { Texture = "Interface\\Buttons\\ButtonHilight-Square", BlendMode = "ADD", Inset = {} }
local ITEM_PUSHED = { Texture = "", Inset = {} }
local ITEM_UPGRADE = { Atlas = "bags-greenarrow" }
local ITEM_COUNT = { Font = { Object = "NumberFontNormal" } }

-- PanelTabButtonTemplate's art, and the text offsets BetterBags used for a template without
-- its own (deselectedTextY / selectedTextY).
local TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
  "LeftHighlight", "MiddleHighlight", "RightHighlight" }
local TAB_IDLE = { "Left", "Middle", "Right" }
local TAB_ACTIVE = { "LeftActive", "MiddleActive", "RightActive" }
local TAB_STATES = { normal = true, selected = true, drop = true }

-- InputBoxVisualTemplate's art, and SearchBoxTemplate's text insets and instruction text.
local INPUT_ART = { "Left", "Middle", "Right" }
local SEARCH_CAPS = { "Left", "Right" }
local SEARCH_FONT = { Object = "GameFontNormal", Color = { 1, 1, 1, 1 } }
local SEARCH_INSTRUCTIONS = { Object = "GameFontDisableSmall", Color = { 0.35, 0.35, 0.35, 1 } }
local SEARCH_INSETS = { Left = 16, Right = 20, Top = 0, Bottom = 0 }

-- The bag menu button's portrait (Interface\Containerframe\Bagslots2x).
local BAG_PORTRAIT = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0, 0.2, 0, 1 }, Width = 48, Height = 60 }
local BAG_HIGHLIGHT = { Texture = "Interface\\Containerframe\\Bagslots2x", TexCoords = { 0.2, 0.3992, 0, 1 }, Width = 48, Height = 60, X = 2 }

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

-- fill draws spec as a texture behind everything of frame, or hides it.
---@param frame Frame
---@param spec? table
---@param key? string
---@return Texture?
local function fill(frame, spec, key)
  key = key or "fill"
  local skin = frame.sonataSkin
  if spec == nil then
    if skin ~= nil and skin[key] ~= nil then
      skin[key]:Hide()
    end
    return nil
  end
  skin = skinOf(frame)
  local texture = skin[key]
  if texture == nil then
    texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    skin[key] = texture
  end
  apply:Texture(texture, setmetatable({ Layer = spec.Layer or "BACKGROUND", SubLevel = spec.SubLevel or -8 }, { __index = spec }))
  if spec.Points ~= nil then
    apply:Points(texture, spec.Points, frame)
  else
    apply:Inset(texture, frame, spec.Inset)
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

-- edges draws a pixel border of four textures around frame (inset by spec.Inset; negative
-- is outside), or hides it.
---@param frame Frame
---@param spec? {Color?: SonataColor, EdgeSize?: number, Inset?: number}
local function edges(frame, spec)
  local skin = frame.sonataSkin
  if spec == nil then
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
  local i = spec.Inset or 0
  local top, bottom, left, right = skin.edges[1], skin.edges[2], skin.edges[3], skin.edges[4]
  top:ClearAllPoints()
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", i, -i)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i, -i)
  top:SetHeight(size)
  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", i, i)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i, i)
  bottom:SetHeight(size)
  left:ClearAllPoints()
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", i, -i)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", i, i)
  left:SetWidth(size)
  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i, -i)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i, i)
  right:SetWidth(size)
  for _, edge in ipairs(skin.edges) do
    edge:Show()
  end
  setEdgeColor(frame, spec.Color)
end

-- captureState remembers a button state region's art the first time a style replaces it.
---@param button Button
---@param key string
---@param region Texture
local function captureState(button, key, region)
  local saved = button.sonataStates
  if saved == nil then
    saved = {}
    button.sonataStates = saved
  end
  if saved[key] ~= nil then
    return
  end
  local r, g, b, a = region:GetVertexColor()
  saved[key] = {
    texture = region:GetTexture(),
    atlas = region:GetAtlas(),
    blend = region:GetBlendMode(),
    coords = { region:GetTexCoord() },
    color = { r, g, b, a },
  }
end

-- highlightState applies a Highlight spec to a button, or puts back the highlight it had.
---@param button Button
---@param spec? SonataTexture
local function highlightState(button, spec)
  local region = button:GetHighlightTexture()
  if spec ~= nil then
    if region ~= nil then
      captureState(button, "Highlight", region)
    end
    apply:ButtonStates(button, { Highlight = spec })
    return
  end
  local saved = button.sonataStates and button.sonataStates.Highlight
  if saved == nil or region == nil then
    return
  end
  if saved.atlas ~= nil then
    region:SetAtlas(saved.atlas)
  else
    region:SetTexture(saved.texture)
  end
  region:SetBlendMode(saved.blend or "BLEND")
  region:SetTexCoord(unpack(saved.coords))
  region:SetVertexColor(unpack(saved.color))
  button.sonataStates.Highlight = nil
end

---@param decoration ItemButton
---@param style table
function elements:StyleItemButton(decoration, style)
  decoration.sonataItemStyle = style
  local icon = decoration.icon or decoration.IconTexture
  if icon ~= nil then
    local iconStyle = style.Icon or {}
    local inset = iconStyle.Inset or 0
    icon:ClearAllPoints()
    if inset == 0 then
      icon:SetAllPoints(decoration)
    else
      icon:SetPoint("TOPLEFT", decoration, "TOPLEFT", inset, -inset)
      icon:SetPoint("BOTTOMRIGHT", decoration, "BOTTOMRIGHT", -inset, inset)
    end
    local coords = iconStyle.TexCoords or { 0, 1, 0, 1 }
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  end

  apply:ButtonStates(decoration, {
    Highlight = style.Highlight or ITEM_HIGHLIGHT,
    Pushed = style.Pushed or ITEM_PUSHED,
  })

  local backdrop = style.Backdrop
  fill(decoration, backdrop and backdrop.Color and { Color = backdrop.Color, Inset = backdrop.Inset } or nil)
  edges(decoration, backdrop and { Color = backdrop.BorderColor, EdgeSize = backdrop.EdgeSize, Inset = backdrop.BorderInset } or nil)

  local upgrade = decoration.UpgradeIcon
  if upgrade ~= nil then
    local spec = style.UpgradeIcon or ITEM_UPGRADE
    if spec.Atlas ~= nil then
      upgrade:SetAtlas(spec.Atlas, true)
    else
      upgrade:SetTexture(spec.Texture)
    end
    upgrade:SetScale(spec.Scale or 1)
  end

  if decoration.Count ~= nil then
    apply:Font(decoration.Count, (style.Count or ITEM_COUNT).Font or ITEM_COUNT.Font)
  end
end

-- DrawItemQuality shows an item's quality on a decoration whose style draws it (on its
-- backdrop border) and returns true; it returns false for BetterBags' own quality glow.
---@param decoration ItemButton
---@param color? SonataColor The quality color, nil for none.
---@return boolean
function elements:DrawItemQuality(decoration, color)
  local style = decoration.sonataItemStyle
  if style == nil or style.QualityBorder ~= "Backdrop" then
    return false
  end
  if decoration.IconBorder ~= nil then
    decoration.IconBorder:Hide()
  end
  local backdrop = style.Backdrop or {}
  setEdgeColor(decoration, color or backdrop.BorderColor)
  return true
end

-- DrawItemQuest swaps the art of a quest icon Blizzard just drew for the style's, and
-- colors the border for a quest item.
---@param decoration ItemButton
function elements:DrawItemQuest(decoration)
  local style = decoration.sonataItemStyle
  local quest = decoration.IconQuestTexture
  if style == nil or quest == nil or not quest:IsShown() then
    return
  end
  if style.QuestIcon ~= nil then
    if style.QuestIcon.Atlas ~= nil then
      quest:SetAtlas(style.QuestIcon.Atlas)
    else
      quest:SetTexture(style.QuestIcon.Texture)
    end
  end
  if style.QuestBorderColor ~= nil then
    if style.QualityBorder == "Backdrop" then
      setEdgeColor(decoration, style.QuestBorderColor)
    elseif decoration.IconBorder ~= nil then
      decoration.IconBorder:SetVertexColor(apply:Color(style.QuestBorderColor))
      decoration.IconBorder:Show()
    end
  end
end

---@param decoration Button
---@param spec? SonataFont
local function tabFont(decoration, spec)
  if spec == nil then
    return
  end
  if decoration.Text ~= nil then
    apply:Font(decoration.Text, spec)
  end
  if spec.Object ~= nil then
    local object = apply:FontObject(spec.Object)
    decoration:SetNormalFontObject(object)
    decoration:SetHighlightFontObject(object)
  end
end

---@param decoration Button
---@param style table
function elements:StyleTab(decoration, style)
  decoration.sonataTabStyle = style
  local flat = style.Art == "Flat"
  strip(decoration, TAB_ART, flat)
  fill(decoration, flat and style.Background or nil)
  edges(decoration, flat and style.Border or nil)
  local selected = flat and style.Selected or nil
  fill(decoration, selected and selected.Background or nil, "selectedFill")
  local bar = selected and selected.Bar
  if bar ~= nil then
    local barSpec = setmetatable({
      Layer = "OVERLAY",
      SubLevel = 6,
      Points = bar.Points or { { Point = "TOPLEFT", X = 1, Y = -2 }, { Point = "TOPRIGHT", X = -1, Y = -2 } },
    }, { __index = bar })
    fill(decoration, barSpec, "bar")
  else
    fill(decoration, nil, "bar")
  end
  if style.Height ~= nil then
    decoration:SetHeight(style.Height)
  end
  tabFont(decoration, style.Font)
  self:SetTabState(decoration, decoration.sonataTabState or "normal")
end

-- SetTabState shows a tab as normal, selected, or a drop target (a section dragged over it).
---@param decoration Button
---@param state "normal"|"selected"|"drop"
function elements:SetTabState(decoration, state)
  if not TAB_STATES[state] then
    error("unknown tab state: " .. tostring(state))
  end
  local style = decoration.sonataTabStyle or {}
  local selected = state == "selected"
  local active = selected or state == "drop"
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
    local selectedStyle = style.Art == "Flat" and style.Selected or nil
    if skin.selectedFill ~= nil then
      skin.selectedFill:SetShown(active and selectedStyle ~= nil and selectedStyle.Background ~= nil)
    end
    if skin.bar ~= nil then
      skin.bar:SetShown(active and selectedStyle ~= nil and selectedStyle.Bar ~= nil)
    end
  end

  if state == "drop" then
    return
  end
  decoration.sonataTabState = state
  local offset
  if selected then
    offset = style.SelectedTextOffset or { X = decoration.selectedTextX or 0, Y = decoration.selectedTextY or -3 }
    decoration:SetDisabledFontObject(GameFontHighlightSmall)
    tabFont(decoration, style.SelectedFont or style.Font)
  else
    offset = style.TextOffset or { X = decoration.deselectedTextX or 0, Y = decoration.deselectedTextY or 2 }
    decoration:Enable()
    tabFont(decoration, style.Font)
  end
  if decoration.Text ~= nil then
    decoration.Text:ClearAllPoints()
    decoration.Text:SetPoint("CENTER", decoration, "CENTER", offset.X or 0, offset.Y or 0)
  end
end

---@param fontString FontString
---@param style table
function elements:StyleSectionHeader(fontString, style)
  apply:Font(fontString, style.Font or { Object = "GameFontNormal" })
end

-- captureMiddle remembers the search box's middle art the first time a style replaces it.
---@param box EditBox
local function captureMiddle(box)
  if box.sonataMiddle ~= nil or box.Middle == nil then
    return
  end
  local middle = box.Middle
  local points = {}
  for i = 1, middle:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = middle:GetPoint(i)
    points[i] = { point, relativeTo, relativePoint, x, y }
  end
  box.sonataMiddle = {
    atlas = middle:GetAtlas(),
    texture = middle:GetTexture(),
    height = middle:GetHeight(),
    points = points,
    coords = { middle:GetTexCoord() },
  }
end

---@param box EditBox
local function restoreMiddle(box)
  local saved = box.sonataMiddle
  if saved == nil then
    return
  end
  local middle = box.Middle
  if saved.atlas ~= nil then
    middle:SetAtlas(saved.atlas)
  else
    middle:SetTexture(saved.texture)
  end
  middle:SetTexCoord(unpack(saved.coords))
  middle:SetHeight(saved.height)
  middle:ClearAllPoints()
  for _, p in ipairs(saved.points) do
    middle:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
  box.sonataMiddle = nil
end

---@param box EditBox
---@param style table
function elements:StyleSearchBox(box, style)
  strip(box, INPUT_ART, style.Strip == true)
  if style.Strip ~= true then
    strip(box, SEARCH_CAPS, style.HideCaps == true)
  end
  if style.Middle ~= nil and box.Middle ~= nil then
    captureMiddle(box)
    local middle = box.Middle
    apply:Texture(middle, style.Middle)
    if style.Middle.Points ~= nil then
      apply:Points(middle, style.Middle.Points, box)
    end
    if style.Middle.Height ~= nil then
      middle:SetHeight(style.Middle.Height)
    end
  elseif box.Middle ~= nil then
    restoreMiddle(box)
  end
  fill(box, style.Background)
  edges(box, style.Border)
  apply:Font(box, style.Font or SEARCH_FONT)
  if box.Instructions ~= nil then
    apply:Font(box.Instructions, style.Instructions or SEARCH_INSTRUCTIONS)
  end
  local insets = style.TextInsets or SEARCH_INSETS
  box:SetTextInsets(insets.Left or 0, insets.Right or 0, insets.Top or 0, insets.Bottom or 0)
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

---@param button Button
---@param style table
function elements:StyleBagButton(button, style)
  local size = style.Size or 40
  button:SetSize(size, size)
  if button.portrait ~= nil then
    bagArt(button.portrait, style.Portrait or BAG_PORTRAIT, button)
  end
  if button.highlightTex ~= nil then
    local alpha = button.highlightTex:GetAlpha()
    bagArt(button.highlightTex, style.Highlight or BAG_HIGHLIGHT, button)
    button.highlightTex:SetAlpha(alpha)
  end
end

---@param button Button
---@param style table
function elements:StyleButton(button, style)
  if next(style) == nil and button.sonataSkin == nil and button.sonataStripped == nil and button.sonataStates == nil then
    return
  end
  strip(button, INPUT_ART, style.Strip == true)
  fill(button, style.Background)
  edges(button, style.Border)
  highlightState(button, style.Highlight)
  if style.Font ~= nil and style.Font.Object ~= nil then
    button:SetNormalFontObject(apply:FontObject(style.Font.Object))
  end
  if style.HighlightFont ~= nil and style.HighlightFont.Object ~= nil then
    button:SetHighlightFontObject(apply:FontObject(style.HighlightFont.Object))
  end
  if style.DisabledFont ~= nil and style.DisabledFont.Object ~= nil then
    button:SetDisabledFontObject(apply:FontObject(style.DisabledFont.Object))
  end
end

---@param box EditBox
---@param style table
function elements:StyleEditBox(box, style)
  if next(style) == nil and box.sonataSkin == nil and box.sonataStripped == nil then
    return
  end
  strip(box, INPUT_ART, style.Strip == true)
  fill(box, style.Background)
  edges(box, style.Border)
  if style.Font ~= nil then
    apply:Font(box, style.Font)
  end
end

sonata:SetElementStyler("ItemButton", function(element, style) elements:StyleItemButton(element, style) end)
sonata:SetElementStyler("Tab", function(element, style) elements:StyleTab(element, style) end)
sonata:SetElementStyler("SectionHeader", function(element, style) elements:StyleSectionHeader(element, style) end)
sonata:SetElementStyler("SearchBox", function(element, style) elements:StyleSearchBox(element, style) end)
sonata:SetElementStyler("BagButton", function(element, style) elements:StyleBagButton(element, style) end)
sonata:SetElementStyler("Button", function(element, style) elements:StyleButton(element, style) end)
sonata:SetElementStyler("EditBox", function(element, style) elements:StyleEditBox(element, style) end)
