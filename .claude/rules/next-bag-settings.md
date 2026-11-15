---
paths:
  - "config/catalog.lua"
  - "core/constants.lua"
  - "core/database.lua"
  - "next/settings/content.lua"
  - "next/style.lua"
  - "next/content.lua"
  - "next/vendorbutton.lua"
  - "next/fooddrinkbar.lua"
  - "next/chain.lua"
  - "spec/config/catalog_spec.lua"
  - "spec/config/settings_effects_spec.lua"
  - "spec/database_spec.lua"
  - "spec/database_migration_spec.lua"
  - "spec/next/settings/content_spec.lua"
  - "spec/integration/next_settings_spec.lua"
  - "spec/next/style_spec.lua"
---
# Each Bag's Own Settings: Its Page, Its Switch, Its Size

Asked (2026-11-14): "we need to centralize some of our bag settings, they are split between general, appearance->size,
and the bag's own settings. 0) we need to add a bag menu for all our bag windows, so we have Backpack, Bank, and Guild
Bank, we need to add Vendor as well 1) all the enable/disable toggles in general need to move to a general tab in each
respective bag menu 2) every appearance -> size option needs to become per-bag, and move to a size tab in each
respective bag, and remove Size from the Appearance menu", "make sure that current user options translate to the
option set for all bags (1 -> many should be the same as 1) -- defaults for all bags are the current defaults", then
"the default for vendor is to have autosize off actually".

Before, General held each bag's switch (Enable Bank Bags, Enable Vendor Window, Enable Guild Bank Window), and
Appearance → Size held one Icon Scale, Bag Scale, Autosize Bags and Fit Names While Open for every bag at once.

## 1. The pages (`next/settings/content.lua`)

The Bags group lists Backpack, Bank, Guild Bank (Next, on a client with one) and Vendor (Next), in that order.

- **General tab**, first, on a bag with a switch that leaves it to Blizzard's own window (`generalTab`): the bank's
  (Enable Bank Bags, section "Bank Window", both designs), the guild bank's (Enable Guild Bank Window, "Guild Bank
  Window") and the vendor's (Enable Vendor Window, "Vendor Window"). The bank's has a second section after its switch,
  "Warbank", where there is one (the row's `hidden`): Include Tradeable Reagents (`bankAutoDepositReagents`, both
  designs), what its Deposit All Warbound Items takes (warbank-deposit.md). The backpack is always BetterBags', has no switch,
  and so no General tab: a tab with nothing in it would be a tab for its own sake. General keeps the switches for every
  bag (BetterBags Next, Show Blizzard Bag Button, Clamp Bags to Screen, Enable Bag Fading, Animate Item Movement).
- **Size tab** (`sizeTab`, BetterBags Next only, after Layout): Icon Scale, Bag Scale, Autosize, Fit Names While Open,
  the bag's own. The classic bags size themselves on their Layout tab's Window section, as before. Appearance has no
  Size tab any more (Theme and Animation; the Theme tab alone for the classic bags).
- **The Vendor page** (`design = "next"`, bound to `{ name = "Vendor", kind = BAG_KIND.UNDEFINED }`): General and
  Size alone. It is defined apart from `bagPage`, and is not in `BAG_PAGES`: those are the bags a category is used in
  (`shownBags`, handed to the Categories page), and the vendor files no items in categories.
- Tabs: the bank's and the guild bank's General, Layout, Size, Items, Categories, Order; the backpack's the same without
  General; the vendor's General, Size.

"Autosize Bags" became **Autosize**: on a bag's own page the plural named every bag. Its searching words keep "bags".

## 2. The catalog (`config/catalog.lua`)

- **The vendor is a bag with settings of its own**: `Bags()` ends with it (`VENDOR = const.BAG_KIND.UNDEFINED`, the
  vendor panel's kind, next/vendor.lua: it reads no bag the data engine reads, and every loop over `BAG_KIND` in the
  data engine skips UNDEFINED, so it stays the vendor's kind rather than a new one).
- **Whose a bag's setting is** (`Has`): the kinds its `only` names, else `ITEM_BAGS` (backpack, bank, guild bank). So
  none of the bags' item settings (order, stacking, item levels, filters, glow) is the vendor's; it has only what names
  it. Checked over every bag setting by `spec/config/catalog_spec.lua` ("gives the vendor only the settings that name it").
- **The Size tab** (`nextIconScale`, `nextBagScale`, `nextAutosize`, `nextFitNamesWhileOpen`): `bag = true`,
  `only = NEXT_BAGS` (all four kinds), descriptions naming the bag, read and written by its kind. Each sends its
  message with the bag's kind: `next/ScalesChanged`, `next/AutosizeChanged`, `next/FitNamesChanged`.
- **The switches** are bag settings of one bag each: `enableBankBags` (`only = { BANK }`), `nextVendor`
  (`only = { VENDOR }`), `nextGuildBank` (`only = { GUILD }`). Their get and set are unchanged.
- **Include Tradeable Reagents** (`bankAutoDepositReagents`, `only = { BANK }`) reads and writes the client's own
  `bankAutoDepositReagents` CVar (`GetCVarBool`, `SetCVar`), kept per character, and sends nothing: only a Warbank deposit
  reads it. The window shows it again on `CVAR_UPDATE` for it, a change made elsewhere (warbank-deposit.md §3).

## 3. What is saved (`core/constants.lua`, `core/database.lua`)

`nextSizeOptions[kind] = { iconScale, bagScale, fitNamesWhileOpen, autosize }`, one per kind (BACKPACK, BANK, GUILD,
UNDEFINED for the vendor), each at the old defaults (100, 100, off, on), the vendor's Autosize off. Read and written by
`DB:Get/SetNextIconScale(kind[, value])`, `Get/SetNextBagScale`, `Get/SetNextFitNamesWhileOpen`, `Get/SetNextAutosize`;
the scales still whole and kept in 50 to 150 (`nextScale`). New keys, not the old ones made tables: AceDB copies a
table default into a profile only where the saved value is not already a number (`copyDefaults`), so a reused key would
have kept the old number.

A getter reads the default when the logout's strip (initialization.md §7) removed the value, or the bag's whole table
(every value at its default): `spec/integration/logout_spec.lua` found a panel laid out after the logout indexing a
stripped table (`sizeOption`), as `GetPreserveItemGaps` already guards its own.

## 4. One set becomes one per bag (`DB:SplitSizeOptions`)

At every load (`DB:Migrate`, last: §5a) and after a profile copy (`DB:CopyFromProfile`, whose source may never have loaded since):
each old key (`nextIconScale`, `nextBagScale`, `nextFitNamesWhileOpen`, `nextAutosize`) saved at a value other than its
old default is given to every bag, the vendor too; then the old key is dropped, so it runs once and a bag the player sets
afterwards keeps its value. A value at its old default carries nothing over: AceDB strips a setting at its default at
logout, so a saved default cannot be told from one never chosen, and each bag keeps its own default. That is what gives
the vendor Autosize off when the player never turned Autosize Bags off (asked: its default is off), and every bag the
player's choice where they made one. `DB:CreateProfile` and `DB:ResetCurrentProfile` hold no old keys.

## 5. How each bag reads its own

- **Icon Scale** (`next/style.lua`, `next/content.lua`): the style holds no scale. `style.ICON` is the theme's icon
  size (`IconAt(100)`); `style:IconAt(percent)` is a button at a scale, `style:CardHeightAt(icon)` a vendor card's height
  for that icon (never shorter than the theme's icon, which its name and price need). Each canvas asks its bag:
  `canvas:SetIconSource(fn)`, set by `nextPanel:Create` for every panel (`database:GetNextIconScale(p.kind)`), read each
  time it lays out, as its columns are (`SetColumnSource`); `canvas:Icon()` (the theme's size without a source) sizes
  its cells (`CellWidth`, `CellHeight`, `PerRow`, `RowWidth`, `gridLengths`, `MeasureSection`) and the buttons it claims.
  A section docked in another bag's card is laid out by its own canvas (`entry.source.content:LayoutSection`), so it keeps
  its own bag's size there. Before, `NextStyle:SetIconScale` set one `style.ICON` for every bag, pushed by the chain,
  the Food & Drink bar and SonataNext's `Init` (whose order across a design switch the bar had to work around).
- **The vendor's cards** (`next/vendorbutton.lua`): `Fit(icon)` takes the icon size of the canvas placing the card
  (`iconSize`) and styles it again when its grid changed or it was last drawn at another size (`styledIcon`); `Style`
  draws at `iconSize`, the theme's until it is placed.
- **The Food & Drink bar** comes out of the backpack and sizes its buttons at the backpack's Icon Scale; it lays out
  again on `next/ScalesChanged` for the backpack, or for no bag named.
- **Bag Scale, Autosize, Fit Names While Open** (`next/panel.lua`): every read takes the panel's own `kind` (`Scale`,
  `RestingHeight`, `clampPlace`, `saveSized`, `FitSmall`, the grip's let go, `FollowNames`, `FollowHeight`, the glide to
  a height, and `nextPanel:SetSize`, which prepares the height of each panel switching to small whose bag is autosized).
- **`chain:ScalesChanged(ctx, kind)`** redraws only that bag's panel (`ApplyScales`; every panel for no kind), then
  refits every open small panel (`Update`), so the bag chained to the one that changed is placed from it.
  `FitNamesChanged` and `AutosizeChanged` refit every open small panel, each by its own bag's choice.

## 5a. Found by the bug reviews

- **Fixed:** the split ran before the profile system's migration (`Migrate`'s "Profile System Migration" block), which
  may switch a character still on its own profile to an existing Default: that Default kept its old keys for the session,
  every bag drew at the defaults, and the next load overwrote what the player set per bag since. `SplitSizeOptions` now
  runs last in `Migrate` (every branch of that block checked to end on a split profile).
- **Fixed:** a new vendor card was styled and skinned again on its first `Fit`, though placed at the size and on the grid
  it was made for. A card keeps the size its canvas asked for (`iconSize`, set by `Fit`) apart from the size it was last
  drawn at (`styledIcon`, set by `Style`), so one never placed still takes a new theme's icon size at once.
- **Left:** `DB:SwitchToProfile` does not split a profile it switches to. Every caller (`next/settings/content.lua`'s
  profile flows) reloads the UI at once, and the load splits it; nothing switches profiles without reloading.
- **Left:** with a theme of another icon size, a vendor card placed at a size other than the theme's may be styled twice
  in one call (the theme's restyle, then the canvas's `Fit`), depending on which widget the theme restyles first. Nothing
  stale is drawn.
- **Left (not measured):** `canvas:Icon()` calls its source and `IconAt` on every cell measure, where `style.ICON` was a
  field read. No capture shows a cost (data-driven.md); it is left until one does.

## 6. Coverage

`spec/config/catalog_spec.lua` (the bags listed, the vendor's settings, each Size setting per bag and its message, each
switch its bag's alone), `spec/config/settings_effects_spec.lua` (each Size setting once per bag, its message naming the
bag), `spec/database_spec.lua` (each bag's own values and ranges, the vendor's Autosize, the defaults after the
logout's strip), `spec/database_migration_spec.lua` (a choice given to every bag, a default left to each, once, a copied
profile), `spec/core/constants_spec.lua` (the defaults), `spec/next/style_spec.lua` (`IconAt`, `CardHeightAt`, no scale
held), `spec/next/content_spec.lua` (a canvas sized by its own source, not another's), `spec/next/vendorbutton_spec.lua`
(`Fit(icon)`), `spec/next/fooddrinkbar_spec.lua` (the backpack's scale, not the bank's), `spec/next/small_spec.lua`
(every stub asserts the kind it is asked with; each bag's Icon Scale redrawing only its panel, its Bag Scale, its
Autosize, its Fit Names While Open), `spec/next/vendor_spec.lua` (the vendor's own kind), `spec/next/settings/content_spec.lua`
(the pages, tabs, Vendor page, General without the switches, Appearance without Size, each bag's Size tab reading and
writing its own, search), `spec/integration/next_settings_spec.lua` (on the whole addon: every page and tab built for
both designs; a profile saved with one Size tab for every bag loading into each bag's, the vendor's Autosize off, its
Size tab writing its own), `spec/integration/logout_spec.lua`.

Not seen in game yet.
