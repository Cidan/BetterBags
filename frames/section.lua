local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
local sectionFrame = addon:NewModule('Section')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')
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
local sectionProto = {}

-- Grid will render the section as a grid of icons.
function sectionProto:Grid()
end

-- List will render the section as a list of rows, with optional icons.
function sectionProto:List()
end

-------
--- Section Frame
-------

-- Create will create a new section view as a child of the
-- given parent.
---@param parent Frame
---@return Section
function sectionFrame:Create(parent)
  ---@class Section
  local s = {}
  setmetatable(s, { __index = sectionProto })

  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")
  f.SetParent(parent)
  s.frame = f

  debug:DrawDebugBorder(f, 1, 1, 1)

  -- Create the section title.
  local title = s.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText("Not set")
  title:SetFontObject("GameFontNormal")
  title:SetHeight(18)
  title:SetJustifyH("LEFT")
  title:SetPoint("BOTTOMLEFT", s.frame, "TOPLEFT", 0, -4)
  s.title = title

  return s
end