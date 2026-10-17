local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class DrawableModule: AceModule
local drawable = addon:GetModule('Drawable')

---@class Scrollbox: AceModule
local scrollbox = addon:GetModule('Scrollbox')

---@class WindowModule: AceModule
local window = addon:GetModule('Window')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Changelog: AceModule
local changelog = addon:GetModule('Changelog')

-- ChangelogWindow shows the changelog (data/changelog.lua): a Panel window listing the bundled
-- releases newest first, every entry with its details, with a "Don't show me
-- this again" checkbox and an "Okay!" button under the list. It opens by itself after the first
-- loading screen of a session when the player allows it and has a release they have not seen,
-- and on changelog/Open (the bag menu, /bb changelog). Closing it marks every release seen.
---@class ChangelogWindow: AceModule
---@field window? BetterBagsWindow
---@field body Drawable
---@field scroll ScrollboxDrawable
---@field canvas ChangelogCanvas
---@field checkbox CheckButton
---@field checkboxLabel FontString
---@field okay Button
---@field loginChecked boolean
local changelogWindow = addon:NewModule('ChangelogWindow')

local WIDTH, HEIGHT = 560, 540
-- The room under the list for the checkbox and the button.
local BOTTOM_ROW = 34
-- The room right of the list. The scroll box puts its 8-wide bar 12 in from its right edge, and
-- the bar's 17-wide buttons are centered on it (MinimalScrollBar.xml), so they reach 0.5 past it.
-- The Panel kind has no right inset in Default, whose border covers about 6 pixels of the content
-- box (Blizzard's own Inset frames start 6 in): 10 leaves the buttons 9.5 in, clear of it. At 0,
-- and at 4, the border covered the bar's buttons in game.
local RIGHT_GAP = 10
-- The list's padding: left and right of every part, above the first.
local PAD = 10
local TOP = 8
-- A release's header: the gap between its version line and its headline, and after it.
local HEADLINE_GAP = 4
local AFTER_HEADER = 8
-- An entry: the padding above and below its text, the gap between entries, the column of its
-- category, and the gap above its details.
local ROW_PAD = 3
local ROW_GAP = 2
local TAG_WIDTH = 70
local DETAILS_GAP = 4
local AFTER_RELEASE = 14

-- The text role each category's tag is drawn with.
local TAG_ROLES = { New = "Positive", Improved = "Field", Fixed = "Field", Changed = "Muted" }

---@class (exact) ChangelogHeader
---@field frame Frame
---@field version FontString
---@field date FontString
---@field badge FontString
---@field headline FontString

-- An entry: a button only so the game highlights it under the pointer.
---@class (exact) ChangelogRow
---@field button Button
---@field highlight Texture
---@field tag FontString
---@field title FontString
---@field details FontString
---@field entry? ChangelogEntry

-- The list inside the scroll area: a header per release and a row per entry, laid out top to
-- bottom at the scroll area's width.
---@class (exact) ChangelogCanvas: Drawable
---@field frame Frame
---@field headers ChangelogHeader[]
---@field rows ChangelogRow[]
---@field parts table[] The headers and rows in use, in order: { header = h } or { row = r }.
---@field empty FontString
local canvasProto = drawable:Extend({}, 'ChangelogCanvas')

---@return RenderPlan
function canvasProto:GetRenderPlan()
  return { Plan = { { step = render.SELF } } }
end

---@private
---@param i number
---@return ChangelogHeader
function canvasProto:header(i)
  local h = self.headers[i]
  if h == nil then
    local frame = CreateFrame("Frame", nil, self.frame)
    h = {
      frame = frame,
      version = sonata:CreateText(frame, "Heading"),
      date = sonata:CreateText(frame, "MutedSmall"),
      badge = sonata:CreateText(frame, "Positive"),
      headline = sonata:CreateText(frame, "Description"),
    }
    h.version:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    h.date:SetPoint("BOTTOMLEFT", h.version, "BOTTOMRIGHT", 8, 1)
    h.badge:SetPoint("BOTTOMLEFT", h.date, "BOTTOMRIGHT", 8, 0)
    h.badge:SetText(L:G("New"))
    h.headline:SetPoint("TOPLEFT", h.version, "BOTTOMLEFT", 0, -HEADLINE_GAP)
    h.headline:SetJustifyH("LEFT")
    h.headline:SetWordWrap(true)
    self.headers[i] = h
  end
  return h
end

---@private
---@param i number
---@return ChangelogRow
function canvasProto:row(i)
  local r = self.rows[i]
  if r == nil then
    local button = CreateFrame("Button", nil, self.frame)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.06)
    r = {
      button = button,
      highlight = highlight,
      tag = sonata:CreateText(button, "Field"),
      title = sonata:CreateText(button, "Body"),
      details = sonata:CreateText(button, "Description"),
    }
    r.tag:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -ROW_PAD)
    r.tag:SetJustifyH("LEFT")
    r.title:SetPoint("TOPLEFT", button, "TOPLEFT", TAG_WIDTH, -ROW_PAD)
    r.title:SetJustifyH("LEFT")
    r.title:SetWordWrap(true)
    r.details:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -DETAILS_GAP)
    r.details:SetJustifyH("LEFT")
    r.details:SetWordWrap(true)
    self.rows[i] = r
  end
  return r
end

-- SetReleases lists releases, marking the ones the player has not seen.
---@param releases ChangelogRelease[]
function canvasProto:SetReleases(releases)
  for _, h in ipairs(self.headers) do
    h.frame:Hide()
  end
  for _, r in ipairs(self.rows) do
    r.button:Hide()
    r.entry = nil
  end
  self.parts = {}
  local rowCount = 0
  for i, release in ipairs(releases) do
    local h = self:header(i)
    h.version:SetText(release.version)
    local date = release.date or ""
    if release.channel == "alpha" then
      date = date .. " - " .. L:G("Alpha")
    end
    h.date:SetText(date)
    h.badge:SetShown(changelog:IsUnseen(release))
    h.headline:SetText(release.headline or "")
    h.frame:Show()
    table.insert(self.parts, { header = h })
    for _, entry in ipairs(release.entries) do
      rowCount = rowCount + 1
      local r = self:row(rowCount)
      r.entry = entry
      sonata:SetTextRole(r.tag, TAG_ROLES[entry.category] or "Field")
      r.tag:SetText(L:G(entry.category or ""))
      r.title:SetText(entry.title or "")
      r.details:SetText(entry.details or "")
      r.button:Show()
      table.insert(self.parts, { row = r, last = false })
    end
    self.parts[#self.parts].last = true
  end
  self.empty:SetShown(#releases == 0)
  self:Invalidate()
end

---@param parentResult? RenderResult
---@return RenderResult
function canvasProto:Render(parentResult)
  local width = parentResult and parentResult.Width or (WIDTH - 20)
  local inner = math.max(1, width - PAD * 2)
  local y = -TOP
  if self.empty:IsShown() then
    self.empty:ClearAllPoints()
    self.empty:SetPoint("TOP", self.frame, "TOP", 0, y)
    self.empty:SetWidth(inner)
    y = y - self.empty:GetStringHeight()
  end
  for _, part in ipairs(self.parts) do
    if part.header ~= nil then
      local h = part.header
      h.headline:SetWidth(inner)
      local height = h.version:GetStringHeight()
      local headline = h.headline:GetStringHeight()
      if headline > 0 then
        height = height + HEADLINE_GAP + headline
      end
      h.frame:ClearAllPoints()
      h.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, y)
      h.frame:SetSize(inner, height)
      y = y - height - AFTER_HEADER
    else
      local r = part.row
      local textWidth = math.max(1, inner - TAG_WIDTH)
      r.title:SetWidth(textWidth)
      r.details:SetWidth(textWidth)
      r.tag:SetWidth(TAG_WIDTH)
      local height = math.max(r.title:GetStringHeight(), r.tag:GetStringHeight())
      if (r.entry.details or "") ~= "" then
        r.details:Show()
        height = height + DETAILS_GAP + r.details:GetStringHeight()
      else
        r.details:Hide()
      end
      height = height + ROW_PAD * 2
      r.button:ClearAllPoints()
      r.button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, y)
      r.button:SetSize(inner, height)
      y = y - height - (part.last and AFTER_RELEASE or ROW_GAP)
    end
  end
  local total = -y
  self.frame:SetSize(width, total)
  return { Width = width, Height = total }
end

-- The window's content: the scroll area above the checkbox and the button.
---@class (exact) ChangelogBody: Drawable
---@field frame Frame
---@field plan RenderPlan
local bodyProto = drawable:Extend({}, 'ChangelogBody')

---@return RenderPlan
function bodyProto:GetRenderPlan()
  return self.plan
end

---@param parentResult? RenderResult
---@return RenderResult
function bodyProto:PreRender(parentResult)
  local width = parentResult and parentResult.Width or 0
  local height = parentResult and parentResult.Height or 0
  return { Width = math.max(0, width - RIGHT_GAP), Height = math.max(0, height - BOTTOM_ROW) }
end

---@param parentResult? RenderResult
---@return RenderResult
function bodyProto:Render(parentResult)
  return { Width = parentResult and parentResult.Width or 0, Height = parentResult and parentResult.Height or 0 }
end

---@private
function changelogWindow:Create()
  local body = drawable:Create(bodyProto, { frame = CreateFrame("Frame") })
  local scroll = scrollbox:Create(body.frame, "BetterBagsChangelogScroll")
  scroll.frame:SetPoint("TOPLEFT", body.frame, "TOPLEFT", 0, 0)
  scroll.frame:SetPoint("BOTTOMRIGHT", body.frame, "BOTTOMRIGHT", -RIGHT_GAP, BOTTOM_ROW)
  scroll.renderParent = body
  local canvas = drawable:Create(canvasProto, {
    frame = CreateFrame("Frame", nil, scroll.scrollChild),
    headers = {},
    rows = {},
    parts = {},
  })
  canvas.empty = sonata:CreateText(canvas.frame, "Muted")
  canvas.empty:SetText(L:G("There are no changes to show yet."))
  canvas.empty:Hide()
  scroll:SetChild(canvas)
  body.plan = {
    Plan = {
      { step = render.PRE },
      { step = render.DEP, target = scroll },
      { step = render.SELF },
    },
  }

  local checkbox = CreateFrame("CheckButton", nil, body.frame, "UICheckButtonTemplate") --[[@as CheckButton]]
  checkbox:SetSize(24, 24)
  checkbox:SetPoint("BOTTOMLEFT", body.frame, "BOTTOMLEFT", 4, 4)
  addon.SetScript(checkbox, "OnClick", function()
    changelog:SetAutoOpen(not checkbox:GetChecked())
  end)
  local label = sonata:CreateText(body.frame, "Body")
  label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
  label:SetText(L:G("Don't show me this again"))

  local okay = CreateFrame("Button", nil, body.frame, "UIPanelButtonTemplate")
  okay:SetSize(100, 22)
  okay:SetPoint("BOTTOMRIGHT", body.frame, "BOTTOMRIGHT", -6, 6)
  okay:SetText(L:G("Okay!"))
  sonata:RegisterElement("Button", okay)
  addon.SetScript(okay, "OnClick", function(ctx)
    self.window:Hide(ctx)
  end)

  self.body = body
  self.scroll = scroll
  self.canvas = canvas
  self.checkbox = checkbox
  self.checkboxLabel = label
  self.okay = okay

  self.window = window:Create({
    Kind = "Panel",
    Name = "BetterBagsChangelog",
    Title = L:G("What's New in BetterBags"),
    Strata = "DIALOG",
    Toplevel = true,
    Escape = true,
    SizeMode = function() return "window" end,
    Size = function() return WIDTH, HEIGHT end,
    Resizable = false,
    Fade = function() return false end,
    Opacity = function()
      return database:GetBagSizeInfo(const.BAG_KIND.BACKPACK, database:GetBagView(const.BAG_KIND.BACKPACK)).opacity
    end,
    OnHide = function()
      changelog:MarkAllSeen()
    end,
  })
  self.window:SetContent(body)
  self.window:UpdateSizeMode()
end

-- Open shows the changelog with every bundled release for the player's client.
---@param ctx Context
function changelogWindow:Open(ctx)
  if self.window == nil then
    self:Create()
  end
  self.canvas:SetReleases(changelog:GetReleases())
  self.checkbox:SetChecked(not changelog:GetAutoOpen())
  self.window:Show(ctx)
end

function changelogWindow:OnEnable()
  self.loginChecked = false
  events:RegisterEvent('LOADING_SCREEN_DISABLED', function(ctx)
    if self.loginChecked then
      return
    end
    self.loginChecked = true
    if changelog:ShouldOpenOnLogin() then
      self:Open(ctx)
    end
  end)
  events:RegisterMessage('changelog/Open', function(ctx)
    self:Open(ctx)
  end)
end
