# BetterBags Next's Currencies (`data/currencies.lua`, `next/currency*.lua`, the Currencies page)

BetterBags Next's backpack shows the currencies and items the player keeps an eye on at the bottom of its footer, where
"N free slots" was, and the player can drag that strip out as a tracker that stays on screen with the bags closed.

Asked (2026-10-25), after research into Plumber's Backpack Item Tracker, ElvUI and GW2_UI (Baganator banned as a
reference): "the whole strip" is what is dragged out; the tracked list is "per profile of course"; drop the free slots
text ("yes, definitely drop this"); "backpack only"; the tracker "configurable maybe? need a whole new section in the
settings screen for it"; and "get creative here. remember our animations and good UX/UI experience, it should 'feel'
good. pay careful attention to details on how you draw things, how things animate, how things layer on top of each
other, and of course, theme support."

The classic bags keep their own currency icons (up to 7, from Blizzard's "show on backpack" flag, `frames/currency.lua`),
set on the classic bags' Currency page (next-settings.md §8). Nothing here changes them.

## 1. What is tracked (`Currencies`, `data/currencies.lua`)

- **One ordered list of currencies and items**, saved in the profile (`nextCurrencies`, `DB:Get/SetNextCurrencies`:
  copies, `{ kind = "currency"|"item", id }`, anything else refused). Nothing is written to Blizzard: the "show on
  backpack" flag stays the classic bags'.
- `Track(ctx, kind, id, index?)` (at the end, or at index; nothing for what is tracked already), `Untrack`, and
  `Move(ctx, key, after)` (after the entry at `after` in the list as it was, counted with itself; 0: first, the contract
  of a settings list's dragged row, `NextListReorder`). Each saves and sends `currencies/Changed`. `Key(kind, id)` names
  an entry (`"currency:3008"`, `"item:210796"`).
- **Items that stack** only (`CanTrackItem`: `C_Item.GetItemMaxStackSizeByID` above 1, Plumber's rule: gear does not).
- **Currencies only where the client has them** (`Available`: retail, WoW: Forever, Mists Classic; TBC and Era have
  none, as next-settings.md §8 says). Items are tracked on every client.

## 2. What each reads, and gains

- **A currency** (`C_CurrencyInfo.GetCurrencyInfo`, on every client that has currencies): its name, icon, quality,
  count; `none` with none or never discovered; the cap it is closest to (the week's, the season's: what it earned toward
  `maxQuantity` with `useTotalEarnedForMaxQty`, or the most it holds) and how far (0 to 1); `capped` at a cap (or
  `PlayerHasMaxQuantity` / `PlayerHasMaxWeeklyQuantity` where the client has them); weekly and season totals; whether it
  belongs to the Warband or moves between its characters.
- **An item**: how many in the bags (`C_Item.GetItemCount`), and, with Count Items Everywhere (§6), in the bank, the
  reagent bank and the Warband bank (`ItemPlaces`; the Warband only with `addon.hasWarbank`, camelot-forever.md §4: WoW:
  Forever's retail client has none). Its icon from `GetItemInfoInstant`; its name and quality only once its data has
  loaded (rule #1, data-loader.md §19): it is asked for once (`load`), and read again when it arrives.
- **When**: every tracked entry once the bags were read (`items/RefreshBackpack/Done`, `items/RefreshBank/Done`), a
  currency when the client says it changed (`CURRENCY_DISPLAY_UPDATE`, its type, or every currency without one), and on
  `currencies/OptionsChanged`. `Refresh` sends `currencies/Updated` with what each gained or lost, only when something
  changed.
- **Gains**: none before the bags were read once (`ready`: counts before then are the client arriving) and none for an
  entry read the first time. An item counted everywhere gained only what its count and its bags' count both gained, so
  moving it between the bags and the bank, or the bank's count arriving after the bags', is no gain. `SessionGain` is
  the net change since the bags were first read.
- **The Warband's amounts** (`Alts`): `C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters`, the most first, those
  with none left out; while the server has not answered it is asked (`RequestCurrencyDataForAccountCharacters`), and
  `ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED` sends `currencies/AltsReady`.
- **Blizzard's currency list** (`List`, for the settings page): every heading and every currency under it, with its ID
  and depth. A heading the player keeps collapsed in the Currency tab is opened to be read and closed again, the last
  opened first so each is still at its own place (ElvUI reads it so): the player's list is left as it was. Retail and
  WoW: Forever through `C_CurrencyInfo` (`currencyID`, `currencyListDepth`); Mists Classic through the legacy globals,
  whose currency ID is `GetCurrencyListInfo`'s twelfth return (Blizzard_TokenUI compares it with
  `Constants.CurrencyConsts.CLASSIC_HONOR_CURRENCY_ID`) and which take 1 and 0 to open and close. `ListSize`,
  `ListEntry` and `ExpandListHeading` are shared with the classic Currency page, which still opens every heading and
  leaves it open (it writes Blizzard's flag by the list's index).

## 3. An entry (`NextCurrencyEntry`, `next/currencyentry.lua`)

One tracked currency or item, for the strip and the tracker alike: its icon (cropped by `Crop`), its count beside it,
a bar under both toward its cap (with Cap Bars on, every entry is as tall, so a row's icons line up), and in the
tracker's list its name. Drawn from the theme's `Currency` (§7), on whole pixels (next-pixel-perfect.md).

- **What you have none of**: its icon desaturated and faded, its count in `NoneFont`. At a cap: its count in
  `CappedFont`, its bar in `Bar.Capped`.
- **A gain**: the count rolls to its new number (`Time.CurrencyCount`), the icon pops by `Bump` and a glow (`Flash`)
  fades out round it, "+N" rises `Rise` off the count on its owner's float layer (over what is around it) and fades; a
  gain while the last still rises adds to it. A loss rolls and "-N" sinks. The bar glides to its new fill. Nothing
  plays while the entry is not shown. What moves while it plays is left out of the pixel checks (`MovingParts`).
- **Measured** for its final count's width, so a rolling count never pushes the entries beside it.
- **Nothing lights behind it** (asked, after a first version had a hover light: "get rid of that entirely", in the
  strip and the tracker). The pointer over it shows its tooltip, nothing else. **Failure mode (fixed):** the light was
  made at alpha 0 and then painted with the theme's color; `NextStyle:Paint` ends a solid color with
  `SetVertexColor(1, 1, 1, 1)`, and a texture's alpha is its vertex color's (next-themes.md §10), so painting turned it
  on at the color's 0.07 until the pointer passed over the entry and away. Coverage: `spec/next/currency_spec.lua`
  ("draws nothing behind its entries", strip and tracker; it failed before the fix).
- **Its tooltip** (`currencyEntry:Tooltip`): Blizzard's own for the currency or item, then how far it is from its caps
  (at a cap, "more is wasted"; near one, the room left), where an item is (bags, bank, reagent bank, Warband bank: each
  that has some), what it gained this session, the Warband's amounts for a currency that moves between characters
  ("Asking your Warband..." until the server answers, then shown again), and hints. Its colors are Blizzard's tooltip
  colors, whatever the theme.

## 4. The strip (`NextCurrencyStrip`, `next/currencystrip.lua`)

- **Where**: the backpack's footer, on its inner side where "N free slots" was (`panelProto:BuildFooterParts`, which
  the backpack overrides, hides the free slots text; the free slots show in Free Space's header). It may take the body
  from its inner side's text inset to the gold, less `MoneyGap`; a small backpack keeps room for "Track Currencies"
  (`FooterWidth`).
- **What it shows**: the tracked entries in order, as many as fit, then "+N" (`MoreFont`) for the rest and, with Hide
  What You Have None Of, for what you have none of. A click on "+N" lists them in a menu (`NextMenu`); one picked is
  brought to the front. Nothing tracked: "Track Currencies", a link to the settings (§6).
- **Drawn only while the backpack shows** (`OnFrameShown`, from the panel's `OnShow`); a change while it is hidden
  waits for it. Gains play only while it shows and not while it opens. Entries that moved glide there (Motion, in the
  interaction time); new ones fade in. Its hiding ends whatever plays (`Settle`).
- **Tracking an item by dropping it**: while an item that can be tracked (and is not) is held over the open backpack, a
  slot opens at the strip's end (`Slot`); dropped there or anywhere on the strip, it is tracked and the item goes back
  where it was picked up (Plumber's way); it arrives with a pop and sparkles (`Sparkles.Gain`). An item that cannot be
  tracked, dropped on the strip, goes into the bags as a drop on the backpack does (bag-drop-zone.md).
- **Clicks**: Shift-click on an item searches the backpack for it (again: clears the search); a right click opens the
  Currencies page on what is tracked; "Track Currencies" opens it where currencies are picked (items, without
  currencies).
- **Dragged** (the strip or one of its entries), a copy pops out as the tracker (§5). With Shift, one entry is dragged
  on its own instead (§5a), and Shift on the strip's own background drags nothing.
- Gains burst sparkles off the entry (`Sparkles.Gain`).

## 5. The tracker (`NextCurrencyTracker`, `next/currencytracker.lua`)

- **A copy of the whole strip**: one at a time; dragging the strip again picks the one out up (it flies from where it is
  to the cursor). It is made with the backpack, in BetterBags Next's event scope (next.md §11).
- **Popping out**: it shows what is tracked now (drawn as it pops: it may have been made after the currencies were
  read), laid out where the strip is and as big, and pops out of it under the cursor, a little past its size held
  (`tracker.POP`) and back over `Time.CurrencyPop`, sparkles bursting (`Sparkles.Pop`), lifted with the shared lift
  (`NextLift`: its shadow, the cursor's place). While held it says what letting go does: "Keep on Screen", or over the
  open backpack "Put Away" (the strip lights, `Drop`, and the card fades a little). A release the client missed drops it,
  as section drags do.
- **Dropped away from the backpack** it lands there (on the screen, on whole pixels of its own grid) and stays, bags
  closed or not; where it was left is saved (`nextCurrencyTracker`, `DB:Get/SetNextCurrencyTracker`: out, and x, y,
  the corner it grows from, in UIParent's units from the screen's top left). It shows again there after a reload, kept
  on the screen when the screen changes (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`); before it was ever placed, in the
  middle of the screen's top third. Dragging it moves it; with Shift, its own background drags nothing.
- **Grows from a corner** (Tracker Grows, §6; asked: "a grow direction for the tracker ... grow direction should
  probably be left (anchor point is right, frame grows out left) ... for list view we need up and down as options"): it
  is anchored by that corner (`Corner`: its right edge growing left, the default, or its left growing right; in a
  column or a list its top growing down, the default, or its bottom growing up; a row by its top), so as what it shows
  gets longer, that corner stays and the rest grows away from it. Changing which way it grows, its layout or its scale
  keeps it where it is on screen and remembers its new corner (`Reanchor`, on `currencies/OptionsChanged`).
- **Dropped back on the backpack** it flies into the strip and is put away; the strip's entries pop one after the other
  (`Welcome`). Put away, it remembers where it was.
- **Shown** while it is out, BetterBags Next is in use (`SetActive`, from the backpack's `Deactivate`/`Activate`),
  something shows in it, no pet battle, and not in combat with Hide Tracker in Combat; it fades in and out.
- **Its layout** (§6): a row, a column, or a list with names (`ListWidth` wide); entries `RowGap` apart in a column or
  list, the card `Pad` round them, its `Fill`, `Edge` and `Frame` (Blizzard's nine-slice art, next-themes.md §15); with
  the background off, the card shows faintly only under the pointer, to grab it by (the pointer coming onto the card or
  straight onto one of its entries, `EntryHovered`), and while it does, the pointer is watched every frame and the card
  fades once the pointer is off the tracker. At its scale. Gains play on it as on the strip.
  **Failure mode (fixed, reported):** the faint card stayed after the pointer left. Its entries are buttons over the
  card: moving onto one, the card's `OnLeave` fires with the pointer still over it (kept), and leaving the entry
  straight off the tracker, the card is told nothing.
- **Clicks**: a right click opens the Currencies page's Display tab; Shift-click on an item finds it in the backpack.

## 5a. Dragging one entry on its own (`NextCurrencyDrag`, `next/currencydrag.lua`)

Asked: "for the items in the tracker, we should be able to shift click -> drag them off the tracker individually (this
means shift click -> drag doesn't move the bar, or create the popout)", as an action is pulled off a locked action bar.

- **Shift-drag** a currency or item in the strip or the tracker: that entry alone is lifted (`NextLift`, the sections'
  lift and shadow); nothing pops out of the strip and the tracker does not move. Not while something else is held or
  dragged, nor with an item on the cursor. A Shift-click without a drag still finds an item in the backpack.
- **The strip and the tracker are views of one list** (containers, `NextCurrencyContainer`: `IsOver`, `IndexAt`,
  `RoomPoint`, `Keys`, `Relayout`, each registered as it is made). While an entry is held, both leave it out (the other
  view's copy of it hides: one on screen at a time); over one of them (or within an icon of it, shown), a room its size
  opens where it would land and the others slide out of its way (Motion); elsewhere they close up behind it. The room
  starts at the entry's own place, and where it goes is worked out from where the others stand with the room among
  them (a row by x, a column or list by y), so it never flickers between two places. A tracker held empty by its only
  entry stays shown, to drop it back.
- **Let go over the strip or the tracker**, it lands in its room and moves there in the tracked order
  (`Currencies:Move`: after the entry before the room, counted as `NextListReorder` counts); where it was, nothing
  changes. A drop on the other view moves it in that view's order, and the entry goes back to its own.
- **Let go anywhere else**, it stops being tracked at once (the others close up) and shrinks away where it was let go
  in a puff of sparkles (`Sparkles.Pop`, on the drag layer).
- Under it while held, what letting go does: "Move Here" or "Stop Tracking" (`Drag.HintFont`). A release the client
  missed lets it go, as section drags do. The backpack closing, or BetterBags Next switched off, puts it straight back.
- Its tooltips say so: "Shift-drag to move it, or off to stop tracking it."

## 6. The options and the Currencies page

**Options** (`nextCurrency`, `DB:Get/SetNextCurrencyOption`; names checked against the defaults, the layout against
`row`, `column`, `list`), each a catalog setting (`config/catalog.lua`, `currencyOption`) that saves and sends
`currencies/OptionsChanged`:

| Setting | Option | Default |
|---|---|---|
| Cap Bars (`nextCurrencyCapBars`) | `capBars` | off (asked) |
| Show Gains (`nextCurrencyGains`) | `gains` | on |
| Hide What You Have None Of (`nextCurrencyHideEmpty`) | `hideEmpty` | on |
| Count Items Everywhere (`nextCurrencyItemsEverywhere`) | `itemsEverywhere` | on |
| Show Tracker (`nextCurrencyTracker`) | the tracker's `out` | off |
| Tracker Layout (`nextCurrencyLayout`, Row / Column / List) | `layout` | row |
| Tracker Grows (`nextCurrencyGrow`: Left / Right in a row, Up / Down in a column or list) | `growX`, `growY` | left, down |
| Tracker Scale (`nextCurrencyScale`, 50% to 200%, steps of 5) | `scale` | 100 |
| Tracker Background (`nextCurrencyBackground`) | `background` | on |
| Hide Tracker in Combat (`nextCurrencyHideInCombat`) | `hideInCombat` | off |

**The Currencies page** (`currencies`, BetterBags group after Categories, BetterBags Next only, every client; the
classic bags keep their Currency page, next-settings.md §7, §8). Four tabs:

- **Tracked** (`NextSettingsCurrencies:CreateTracked`, `next/settings/currencies.lua`): what is tracked, currencies and
  items together, in the order the strip and tracker show them. Drawn as a bag's categories list is (its
  `Settings.BagCategories` theme keys; the icon at `Settings.Currency.IconSize`): each row its icon (desaturated with
  none), its name (`Item N` until the client has the item), how many (of a currency's most) and Remove (stops tracking
  it). Dragging a row moves it (`NextListReorder`, the drag every settings list shares, next-settings.md §5; landing calls
  `Currencies:Move`). It follows `currencies/Changed` and `currencies/Updated` while it shows. "Nothing tracked yet."
- **Currencies** (on clients with currencies): every currency under its headings with a switch that tracks it, the
  classic Currency page's block (`NextSettingsCurrency`) made with `track` (§2's `List`, by currency ID, nothing written
  to Blizzard); the switches follow `currencies/Changed` while it shows. A click anywhere on a currency's row flips its
  switch, as the switch does (asked: "clicking on any currency on the currency list in the settings menu should toggle
  it, not just by pressing the switch"); a heading takes no click. The classic Currency page's rows, the same block, do
  the same.
- **Items**: the shared items tab (`NextSettingsItemsTab`, below) over the items tracked: an item dropped on it that
  stacks is tracked (one that does not is refused, "Only items that stack can be tracked.", and stays on the cursor);
  each shows how many you have and where ("4 in your bags, 20 in your bank"), faded with "You have none."; a right click
  removes one; Remove All asks first and keeps the currencies.
- **Display**: Backpack and Tracker (Cap Bars, Show Gains, Hide What You Have None Of, Count Items Everywhere), Tracker
  (Show Tracker, Tracker Layout, Tracker Grows, Tracker Scale, Tracker Background, Hide Tracker in Combat). Tracker Grows
  offers the choice for the layout shown, its choices read each time its menu opens (form-dropdowns.md); the tracker
  keeps both. Its row shows the choice for the new layout as soon as Tracker Layout changes (the window shows every
  value again after a change, next-settings.md §3; reported: it kept "Left" after the layout became Column).

**The shared items tab** (`next/settings/itemstab.lua`): the Categories page's Added Items tab moved into a module of
its own so the Items tab is the same one (CLAUDE.md, "UI Consistency" 2: never a lookalike). It takes a source
(`NextItemsSource`: what it lists, read-only, its help and words, notes per item, add, remove, clear, Remove All's
question, extra messages that refresh it); the Categories page's Added Items and Ignored Items are two sources of it,
unchanged in look and behavior (their specs pass unchanged). It also holds the frame helpers the Categories page's tabs
used (`TabHeight`, `Metrics`, `PlaceTab`, `Count`, `ByName`).

## 7. Theme (`Currency`, every shipped Next theme)

`Currency`: `Icon`, `Crop`, `CountGap`, `Gap`, `NameGap`, `MoneyGap`; fonts `Font` (`CurrencyCount`), `CappedFont`,
`NoneFont`, `NameFont`, `GainFont`, `LossFont`, `MoreFont`, `HintFont`; `Bar` (`Gap`, `Height`, `Track`, `Fill`,
`Capped`); `Flash` (`Size` times the icon), `Bump`, `Rise`; `Drop`; `Slot` (`Icon`); `Tracker`
(`Pad`, `RowGap`, `ListWidth`, `Fill`, `Edge`, `Frame`). Palette `Gain`, `Capped`. `Motion.Time`: `CurrencyCount`,
`CurrencyBump`, `CurrencyGain`, `CurrencyEnter`, `CurrencyPop`, with eases. `Sparkles.Gain` and `Sparkles.Pop`
(bursts; a theme without sparkles, or the Animation tab's Sparkles off, has none). `SonataNext:Check` checks the font
keys (`FONT_KEYS`). Default sets them all and Ember takes Default's; Parchment (ink), Quiet (a smaller pop, no glow), Guild Wars 2 (its
fonts) and Plain (Blizzard's fonts and art: the tracker on the popup's background, the strip lit as its lists light a
row) set what their look needs.

## 8. Coverage

- `spec/currencies_spec.lua`: tracking, order and moving; counts, caps and none; items everywhere and the Warband (none
  on WoW: Forever); item data loading; gains and their rules; the Warband's amounts; Blizzard's list (every heading and
  currency, collapsed headings opened and closed again in order, nothing touched when nothing is collapsed, Mists'
  legacy list, a client without currencies).
- `spec/next/currency_spec.lua`: the strip (place, Track Currencies and where it opens, order, cap bars, fonts, +N and
  its menu, what you have none of, waiting for the backpack, the gold's width, right clicks, Shift-click), dropping an
  item, gains, tooltips (caps, places, the Warband), the tracker (popping out with what is tracked, its pop, landing on
  whole pixels and remembered, putting away, one at a time, design switches, layouts, scale and background, combat,
  pet battles; its faint card under the pointer; growing from its corner each way, kept on screen and where it was
  dropped), dragging one entry with Shift (from the strip and the tracker: lifted alone, rooms, moving, removing, the
  hint, a missed release, put back on a close, nothing on a background), themes.
- `spec/next/settings/currencies_spec.lua` (the Tracked tab and the Items tab), `spec/next/settings/currency_spec.lua`
  ("tracking (BetterBags Next)"), `spec/config/settings_effects_spec.lua` ("BetterBags Next's currencies"),
  `spec/next/settings/content_spec.lua` (the page per design and client, every setting checked as Next's, every page
  and tab on whole pixels), `spec/integration/next_settings_spec.lua` (every tab built on the whole addon),
  `spec/database_spec.lua`, `spec/core/init_spec.lua`, and the backpack specs that build the strip (`UseNextCurrencies`).

Mutation-tested: 57 mutations of the data module, the strip and tracker's hooks, the settings page's parts, the shared
items tab and the catalog settings, each caught. Four first survived and led to three tests (the bags' gain when the
bank's count arrives with a loot, the Added Items tab shown again when a bag is read, the strip settling as the backpack
hides) and to the Items tab's Remove All untracking by each entry's own kind. The gain test found a bug: the bags rule
(§2) was skipped whenever the count equaled the bags' count, meant for items counted in the bags alone but also true
whenever the bank's count fell to none, so 3 used while the bank's 20 left the count read as a loss of 23. The check
was not needed (counted in the bags alone, the total and the bags change alike) and was removed.

Then (asked in game): cap bars off by default, the Shift-drag (§5a), Tracker Grows, and the tracker's faint card: 48
mutations. Ten first survived: eight led to tests (a tracker put away taking no drop where it was, the tracker showing
the entry again when a drag out of the strip is put back, a drop within an icon of the strip, the room at the strip's
end and landing there, the column's room its size, the lifted entry left shown by the tracker, the release missed for
one frame only, the tracker landing where it was let go); two were code that could not matter, removed (the room's
check for an entry being removed: once untracked it is in no list; the card's watch skipping a held tracker: one held
is under the pointer); one is equivalent (the room's count at a cursor exactly on an entry's middle). A test of the room
found a bug: picked up, the room's place was worked out from the layout that still held the entry, so it could open a
place off; it now starts at the entry's own place.

**Not verified in game yet**: any of it. To check: track a few currencies and an item, earn some (gains), reach a
weekly cap, drag the strip out and back, reload with it out, enter combat with Hide Tracker in Combat, a pet battle,
and check `/console taintLog 1` logs nothing for BetterBags.
