# Classic Configuration Modules

This folder contains configuration modules specifically adapted for WoW Classic versions (Classic Era, Classic/Cata).

## Overview

These modules provide the same functionality as their retail counterparts but use the older WoW API functions that are available in Classic versions.

## Files

### currencypane.lua

The Classic version of the Currency configuration pane. Provides the same master-detail currency management interface as retail, but uses Classic-specific API functions.

#### API Differences from Retail

| Retail API | Classic API |
|------------|-------------|
| `C_CurrencyInfo.GetCurrencyListInfo(index)` | `GetCurrencyListInfo(index)` |
| `C_CurrencyInfo.SetCurrencyBackpack(index, show)` | `SetCurrencyBackpack(index, 0/1)` |
| `C_CurrencyInfo.GetCurrencyListSize()` | `GetCurrencyListSize()` |
| `C_CurrencyInfo.ExpandCurrencyList(index, expand)` | N/A (headers typically pre-expanded) |

#### Key Features

- Same master-detail layout as retail version
- Left panel shows scrollable list of all currencies
- Right panel shows selected currency details
- Toggle button to show/hide currency in backpack
- Automatic updates when currencies change

#### Return Value Mapping

The Classic `GetCurrencyListInfo()` function returns values in a different format than retail. The module wraps these into a CurrencyInfo-compatible table:

```lua
local name, isHeader, isExpanded, isUnused, isWatched, count, icon,
      maximum, hasWeeklyLimit, currentWeeklyAmount, unknown, itemID = GetCurrencyListInfo(ref)

-- Mapped to:
{
  name = name,
  isHeader = isHeader,
  isHeaderExpanded = isExpanded,
  isTypeUnused = isUnused,
  isShowInBackpack = isWatched,
  quantity = count,
  iconFileID = icon,
  maxQuantity = maximum,
  canEarnPerWeek = hasWeeklyLimit,
  quantityEarnedThisWeek = currentWeeklyAmount,
}
```

## TOC File Mapping

| TOC File | Currency Pane Used |
|----------|-------------------|
| BetterBags.toc (Retail) | `config/currencypane.lua` |
| BetterBags_Mists.toc (Classic/Cata) | `config/classic/currencypane.lua` |
| BetterBags_Vanilla.toc (Classic Era) | `config/currencypane.lua` |
| BetterBags_TBC.toc (TBC Classic) | `config/currencypane.lua` |

Note: Vanilla and TBC use the retail currencypane.lua even though they use Classic-style currency modules in frames/, because the currency pane module is loaded separately and the API differences are minimal for the options UI.
