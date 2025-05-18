local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Fonts: AceModule
local fonts = addon:NewModule('Fonts')

fonts.UnitFrame12White = CreateFont('BetterBagsUnitFrame12White')
---@diagnostic disable-next-line: param-type-mismatch
fonts.UnitFrame12White:SetFont(UNIT_NAME_FONT, 12, "")
fonts.UnitFrame12White:SetTextColor(1, 1, 1)

fonts.UnitFrame12Yellow = CreateFont('BetterBagsUnitFrame12Yellow')
---@diagnostic disable-next-line: param-type-mismatch
fonts.UnitFrame12Yellow:SetFont(UNIT_NAME_FONT, 12, "")
fonts.UnitFrame12Yellow:SetTextColor(1, .81960791349411, 0, 1)