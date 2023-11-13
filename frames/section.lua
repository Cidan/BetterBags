local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
local sectionFrame = addon:NewModule('SectionFrame')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

-------
--- Section Prototype
-------

--- Section is a view of a single bag section. A section
--- has a title, and contains all the items views for a section.
---
--- Sections can be rendered in multiple different ways, such as
--- a list of icons, a list of rows, or a grid of icons.
---@class Section
---@field frame Frame The raw frame of the section.
---@field title FontString The title of the section.
---@field content Grid The main content frame of the section.
local sectionProto = {}

-- Grid will render the section as a grid of icons.
function sectionProto:Grid()
end

-- List will render the section as a list of rows, with optional icons.
function sectionProto:List()
end

-- SetTitle will set the title of the section.
---@param text string The text to set the title to.
function sectionProto:SetTitle(text)
  self.title:SetText(text)
end

function sectionProto:Wipe()
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
end

---@return number width
---@return number height
function sectionProto:Draw()
  local w, h = self.content:Draw()
  self.content.frame:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, 0)
  self.content.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
  self.content:Show()
  self.frame:SetSize(w, h + self.title:GetHeight())
  return w, h
end

-------
--- Section Frame
-------

function sectionFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

---@param f Section
function sectionFrame:_DoReset(f)
  f:Wipe()
end

---@return Section
function sectionFrame:_DoCreate()
  ---@class Section
  local s = {}
  setmetatable(s, { __index = sectionProto })

  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")
  s.frame = f

  --debug:DrawDebugBorder(f, 1, 1, 1)

  -- Create the section title.
  local title = s.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText("Not set")
  title:SetFontObject("GameFontNormal")
  title:SetHeight(18)
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, 0)
  s.title = title

  local content = grid:Create(s.frame)
  content:Show()
  s.content = content
  f:Show()
  return s
end

-- Create will create a new section view.
---@return Section
function sectionFrame:Create()
  ---@return Section
  return self._pool:Acquire()
end

function sectionFrame:Release(s)
  self._pool:Release(s)
end