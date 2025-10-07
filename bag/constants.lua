local bb = GetBetterBags()

--- BetterBags constants module - centralized configuration values
---@class bagconstants
local bagconstants = bb:NewClass("bagconstants")

-- ============================================================================
-- Window Dimensions
-- ============================================================================

--- Default width for the backpack window in pixels
bagconstants.BACKPACK_DEFAULT_WIDTH = 300

--- Default height for backpack and bank windows in pixels
bagconstants.DEFAULT_WINDOW_HEIGHT = 500

--- Default width for the bank window in pixels
bagconstants.BANK_DEFAULT_WIDTH = 400

-- ============================================================================
-- Positioning Offsets
-- ============================================================================

--- Horizontal offset for tab positioning from window edge
bagconstants.TAB_HORIZONTAL_OFFSET = 10

--- Vertical offset for tab positioning below window (negative = below)
bagconstants.TAB_VERTICAL_OFFSET = -2

--- Spacing between individual tabs
bagconstants.TAB_SPACING = 4

--- Left-side offset for bank window from screen edge
bagconstants.BANK_LEFT_OFFSET = 50

-- ============================================================================
-- Tab Animations
-- ============================================================================

--- Distance in pixels for tab hover animation
bagconstants.TAB_HOVER_ANIMATION_DISTANCE = 3

--- Duration in seconds for tab hover animation
bagconstants.TAB_HOVER_ANIMATION_DURATION = 0.1

--- Distance in pixels for selected tab animation
bagconstants.TAB_SELECTED_ANIMATION_DISTANCE = 7

-- ============================================================================
-- Section Configuration
-- ============================================================================

--- Default spacing between sections in the sectionset
bagconstants.DEFAULT_SECTION_OFFSET = 4

--- Default number of columns for two-column section layouts
bagconstants.DEFAULT_SECTION_COLUMNS_TWO = 2

--- Default number of columns for single-column section layouts
bagconstants.DEFAULT_SECTION_COLUMNS_ONE = 1

-- ============================================================================
-- Blizzard Frame Configuration
-- ============================================================================

--- Maximum number of Blizzard container frames to hide (ContainerFrame1-6)
bagconstants.MAX_BLIZZARD_CONTAINER_FRAMES = 6

-- ============================================================================
-- Bag Filters
-- ============================================================================

--- BagFilter table for all backpack bags (bags 0-5)
--- Bag 0 = main backpack, bags 1-4 = additional bags, bag 5 = reagent bag
bagconstants.ALL_BACKPACK_BAGS = {
	[0] = true,
	[1] = true,
	[2] = true,
	[3] = true,
	[4] = true,
	[5] = true
}

-- ============================================================================
-- UI Assets
-- ============================================================================

--- Default icon texture path for bag representations
bagconstants.DEFAULT_BAG_ICON = [[interface/icons/inv_misc_bag_08.blp]]

-- ============================================================================
-- BankPanel Configuration
-- ============================================================================

--- Alpha value for invisible BankPanel (prevents taint per patterns.md)
bagconstants.BANKPANEL_INVISIBLE_ALPHA = 0

-- ============================================================================
-- Special Section Names
-- ============================================================================

--- Name of the special "New Items" header section
bagconstants.NEW_ITEMS_SECTION = "New Items"

--- Name of the "All Items" section for combined view
bagconstants.ALL_ITEMS_SECTION = "All Items"
