local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- Ember: BetterBags Next in the colors of a banked fire. Everything else is Default's: it shows how far
-- a palette and a few sparkle settings go. Data only (next-themes.md).
sonataNext:RegisterTheme({
  Name = "Ember",
  DisplayName = "Ember",
  Description = "Charcoal and amber, with sparkles that rise like embers.",

  Palette = {
    Body = { 0.07, 0.035, 0.03, 0.94 },
    Wash = { 1.0, 0.45, 0.15, 0.16 },
    Gold = { 1.0, 0.62, 0.25, 1 },
    Lavender = { 1.0, 0.78, 0.62, 1 },
    Text = { 1.0, 0.95, 0.9, 1 },
    Muted = { 0.78, 0.6, 0.5, 1 },
    Tab = { 0.14, 0.06, 0.04, 0.92 },
    TabSelected = { 0.3, 0.12, 0.07, 0.96 },
    Card = { 0.16, 0.07, 0.05, 0.98 },
    SearchFill = { 0.2, 0.09, 0.06, 1 },
    SearchFillFocus = { 0.27, 0.12, 0.08, 1 },
    ButtonIcon = { 1.0, 0.85, 0.75, 1 },
    Bead = { 1.0, 0.9, 0.7, 1 },
    -- The hot orange of a live coal.
    Ember = { 1.0, 0.35, 0.1, 1 },
    -- The settings window's controls (next-settings.md §6): its search box's charcoal, a little darker
    -- idle and when pressed, lighter under the pointer, as Default's are to its own; and a red apart
    -- from its amber for what deletes.
    ControlFill = { 0.178, 0.08, 0.053, 1 },
    ControlHover = { 0.23, 0.104, 0.069, 1 },
    ControlPressed = { 0.142, 0.064, 0.043, 1 },
    Track = { 0.3, 0.135, 0.09, 1 },
    Danger = { 1.0, 0.3, 0.25, 1 },
  },

  -- Embers drift slowly and rise as they go.
  Sparkles = {
    Colors = { "Gold", "Ember", "White" },
    Ribbon = { Speed = { 12, 40 }, Rise = { 4, 18 } },
    Edge = { Rate = 3.5, Speed = { 8, 24 }, Rise = { 6, 16 } },
    Cloud = { Rise = { 2, 8 } },
  },
})
