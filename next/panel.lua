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

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

-- NextPanel is the panel BetterBagsNext's bags are made of (next.md §3): a full-height panel on a
-- side of the screen that slides in from that edge, its inner edge feathered out to nothing, with
-- the title and its sparkles, a search box, the tabs down its inner side, the content in one
-- column and a footer. Everything mirrors with the side: the backpack is on the right, the bank on
-- the left. A kind (next/bag.lua, next/bank.lua) makes its prototype with Extend and supplies its
-- header buttons, its tabs and what they do, what opening and closing do, sorting and refreshing.
---@class NextPanel: AceModule
---@field proto NextPanelFrame The panel's prototype every kind's chains to.
local nextPanel = addon:NewModule('NextPanel')

-- The ribbon running from the title out of the window.
local RIBBON_LENGTH = 300
-- The ribbon's glow: thin lines above and below it, fainter the further out.
local RIBBON_GLOW = { { 0, 0.9 }, { 2, 0.35 }, { -2, 0.35 }, { 4, 0.15 }, { -4, 0.15 }, { 6, 0.06 }, { -6, 0.06 } }

---@alias NextSide "RIGHT"|"LEFT"

---@class (exact) NextPanelOptions
---@field kind BagKind
---@field side NextSide The edge of the screen it is on and slides out from.
---@field name string The frame's global name.
---@field scrollName string The scroll box's global name.
---@field title string
---@field openSound number
---@field closeSound number
---@field noDrag? boolean Its sections are not dragged, and nothing is dropped on it (the vendor).

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
---@field feather Texture
---@field wash Texture The faint color at the top of the body.
---@field dropGlow Texture Lit while a section from the other bag would drop here (next.md §7).
---@field washColor number[] The wash's color now.
---@field title FontString
---@field ribbon Texture The ribbon's brightest line.
---@field spark Texture What sweeps along the ribbon.
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
  self.feather = feather

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

-- BuildHeader makes the title on the body's inner side, the ribbon running from it out of the
-- window (a thin gold line with a soft glow, fading out toward its end) and the spark that sweeps
-- along it, and the kind's buttons along the top from the screen edge.
---@param text string
function panelProto:BuildHeader(text)
  local frame, body = self.frame, self.body
  local left = self.side == "LEFT"
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

  for _, glow in ipairs(RIBBON_GLOW) do
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetSize(RIBBON_LENGTH, 2)
    line:SetColorTexture(1, 1, 1, 1)
    if left then
      line:SetPoint("LEFT", title, "RIGHT", 10, glow[1])
      line:SetGradient("HORIZONTAL", style:CreateColor("Gold", glow[2]), style:CreateColor("Gold", 0))
    else
      line:SetPoint("RIGHT", title, "LEFT", -10, glow[1])
      line:SetGradient("HORIZONTAL", style:CreateColor("Gold", 0), style:CreateColor("Gold", glow[2]))
    end
    line:SetBlendMode("ADD")
    if glow[1] == 0 then
      self.ribbon = line
    end
  end

  local spark = frame:CreateTexture(nil, "OVERLAY")
  spark:SetTexture(style.SPARKLE_TEXTURE)
  spark:SetBlendMode("ADD")
  spark:SetVertexColor(unpack(style.Color.Gold))
  spark:SetSize(26, 26)
  spark:SetPoint("CENTER", self.ribbon, left and "LEFT" or "RIGHT", 0, 0)
  spark:SetAlpha(0)
  self.spark = spark

  self.headerButtons = {}
  for _, spec in ipairs(self:GetHeaderButtons()) do
    local button = self:headerButton(spec)
    self[spec.key] = button
    table.insert(self.headerButtons, button)
  end
  self:LayoutHeader()
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

-- BuildSparkles makes the two emitters: one around the title's ribbon, one along the feathered
-- edge, both drifting out of the window.
function panelProto:BuildSparkles()
  local fx = CreateFrame("Frame", nil, self.frame)
  fx:SetAllPoints(self.frame)
  fx:SetFrameLevel(self.frame:GetFrameLevel() + 50)
  local out = self:Outward()
  -- Where the ribbon starts, from the panel's top left: 10 pixels outside the title.
  local ribbonStart
  local edge
  if self.side == "LEFT" then
    ribbonStart = style.BODY_WIDTH - (style.PAD + 4) + 10
    edge = style.BODY_WIDTH
  else
    ribbonStart = style.FEATHER + style.PAD + 4 - 10
    edge = style.FEATHER
  end
  local titleMiddle = -(style.TITLE_TOP + 13)
  self.sparkles = sparkles:Create(fx, {
    Rate = 8, Max = 28, Life = { 2.0, 3.6 }, Size = { 6, 15 }, Speed = { 22, 64 }, Rise = { -8, 10 },
    Wobble = 4, Spin = 1.5, Direction = out,
    Spawn = function()
      return ribbonStart + out * math.random() * 70, titleMiddle + (math.random() * 2 - 1) * 8
    end,
  })
  self.edgeSparkles = sparkles:Create(fx, {
    Rate = 2.5, Max = 12, Life = { 2.4, 4.2 }, Size = { 4, 9 }, Speed = { 14, 36 }, Rise = { -6, 6 },
    Wobble = 3, Spin = 1, Alpha = 0.6, Direction = out,
    Spawn = function()
      return edge + out * math.random() * 24, -math.random() * fx:GetHeight()
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

---@private
function panelProto:playShimmer()
  local spark = self.spark
  local out = self:Outward()
  local from = self.side == "LEFT" and "LEFT" or "RIGHT"
  tween:Play(spark, {
    duration = style.Time.Shimmer,
    delay = style.Time.ShimmerEvery - style.Time.Shimmer,
    from = 0,
    to = 1,
    ease = "inOutSine",
    onUpdate = function(t)
      spark:ClearAllPoints()
      spark:SetPoint("CENTER", self.ribbon, from, out * t * RIBBON_LENGTH, 0)
      spark:SetAlpha(math.sin(math.pi * t))
    end,
    onDone = function()
      if self.frame:IsShown() and not self.closing then
        self:playShimmer()
      end
    end,
  })
end

-- OnShowing runs as the panel starts to open, before it draws.
---@param ctx Context
function panelProto:OnShowing(ctx)
  local _ = ctx
end

-- Show slides the panel in from its edge, drawing a draw it kept while hidden (with slotInfo when
-- given), fading its sections in and starting its sparkles. It returns whether it drew.
---@param ctx Context
---@param slotInfo? SlotInfo
---@return boolean drew
function panelProto:Show(ctx, slotInfo)
  if self.frame:IsShown() and not self.closing then
    return false
  end
  local sliding = self.frame:IsShown()
  self.closing = false
  PlaySound(self.openSound)
  self:OnShowing(ctx)
  local from = sliding and self.offset or self:HiddenOffset()
  self:setOffset(from)
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
  tween:Play(self, {
    duration = style.Time.Open,
    from = from,
    to = 0,
    ease = "outBack",
    onUpdate = function(x)
      self:setOffset(x)
    end,
  })
  self.content:Cascade(true, style.Time.OpenCascadeDelay)
  self.sparkles:Start()
  self.edgeSparkles:Start()
  self:playShimmer()
  addon.TriggerItemContextChanged()
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

---@return string
function panelProto:GetName()
  return self.frame:GetName()
end

---@param text string
function panelProto:SetTitle(text)
  self.title:SetText(text)
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
  self.sparkles:Stop()
  self.edgeSparkles:Stop()
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
