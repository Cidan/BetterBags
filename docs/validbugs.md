# Valid Bugs (Triage of the Oldest Open Bug Reports)

Open issues labeled `bug` are triaged oldest first, 20 at a time. Each batch was checked
against the current code; issues that no longer apply were closed on GitHub with the reason,
and the ones still valid are listed here, unfixed.

- [First batch](#first-batch-the-20-oldest): 2026-10-15, against `main` at 20406c4.
- [Second batch](#second-batch-477-to-710): 2026-10-16, against `main` at 60b72a3 (v0.5.16).

# First batch: the 20 oldest

The 20 oldest open issues labeled `bug` (after closing duplicates) were checked against the
current code. Ten no longer apply and were closed on GitHub with the reason. The ten below
were still valid at triage. Since then #175, #183 and #408 were fixed and closed, #204 was
closed as working as intended, and #291 was closed because it no longer reproduces (marked
below). #1107 and #1121 (related findings) were fixed and closed too.

Each entry says what was **verified** (read in the code, the Blizzard UI source under
`.libraries/wow-ui-source`, or the external addon's source) and what is **inferred** (traced
from code, not shown by a capture). No in-game capture was taken for any of them.

| Issue | Client | Area | Confidence |
|---|---|---|---|
| [#175](https://github.com/Cidan/BetterBags/issues/175) | Retail, non-Latin locales | Category item list font | Verified; **fixed** |
| [#183](https://github.com/Cidan/BetterBags/issues/183) | All | Category names | Verified; **fixed** |
| [#204](https://github.com/Cidan/BetterBags/issues/204) | All | Currency bar | Verified; **closed, working as intended** |
| [#279](https://github.com/Cidan/BetterBags/issues/279) | Retail + ConsolePort | Gamepad cursor | Never fixed; not reproduced |
| [#280](https://github.com/Cidan/BetterBags/issues/280) | Retail + ConsolePort | Gamepad cursor | Never fixed; not reproduced |
| [#291](https://github.com/Cidan/BetterBags/issues/291) | Retail | Section clipping | Verified in code; **closed, does not reproduce** |
| [#382](https://github.com/Cidan/BetterBags/issues/382) | Classic Era (and all) | Item loading | Inferred |
| [#408](https://github.com/Cidan/BetterBags/issues/408) | All | Drag and drop | Verified; **fixed** |
| [#437](https://github.com/Cidan/BetterBags/issues/437) | All | Window position | Inferred |
| [#463](https://github.com/Cidan/BetterBags/issues/463) | Retail + ElvUI | ElvUI theme | Verified |

---

## #175 — Non-Latin item names render with a Latin-only font

**Symptom:** item names in a category's item list show missing glyphs on Russian, Korean
and Chinese clients.

**Cause (verified):** `frames/itemrow.lua:209` overrides the row's `GameFontNormalLarge`
with `text:SetFont("Fonts\\FRIZQT__.TTF", 14, "")`. Blizzard's fonts are font families with
one file per alphabet (`Blizzard_Fonts_Shared/Mainline/Fonts.xml`: roman `FRIZQT__.TTF`,
russian `FRIZQT___CYR.TTF`, korean `2002.TTF`, simplified Chinese `ARKai_T.ttf`, traditional
Chinese `blei00d.TTF`). Setting one file drops every alphabet but the roman one. The same
line (then with `"THICK"`) was there when the issue was filed (v0.1.6). The rows are used by
the category pane's item list (`config/categorypane.lua:1181`).

**Fixed (#1132, issue closed):** the row now uses `STANDARD_TEXT_FONT`, the locale's file that Blizzard sets on
every client (`Blizzard_Fonts_Shared/Shared/GameFonts.xml`). Roman clients get the same file
as before.

## #183 — "Quest - Quest - <Expansion>"

**Symptom:** with the Subtype category filter on, quest items are filed under
"Quest - Quest", because the item's type and subtype are both "Quest".

**Cause (verified):** `items:GetCategory` (`data/items.lua:2948` and `:2965`) appends the
type, then " - " and the subtype, with no check for them being equal. Subtype is off by
default (`core/constants.lua` `categoryFilters`), which hides it for most users. The
maintainer agreed it should be deduplicated.

**Fixed (#1132, issue closed):** a subtype equal to the type before it is skipped ("Quest", "Quest - Classic"), and
`DB:RenameRepeatedTypeCategories` moves hidden state and group assignments saved under the old
names (category-lifecycle.md §5).

## #204 — Only 7 currencies are shown, with no warning

**Symptom:** more than 7 currencies can be marked "Show in Backpack", but the bag draws only
the first 7.

**Cause (verified):** `frames/currency.lua:99` stops at `showCount < 7`. The currency pane's
toggle (`config/currencypane.lua:352`, Classic `config/classic/currencypane.lua:374-376`)
calls `SetCurrencyBackpack` with no limit check. Blizzard's own token UI refuses past its
maximum and says so (`TokenFrameMixin:SetTokenWatched` in
`Blizzard_TokenUI/Blizzard_TokenUI.lua`, `TOO_MANY_WATCHED_TOKENS`). The closed duplicates
#677 (currencies overlapping the gold) and #694 (allow more than 7) are part of this.

**Closed (working as intended):** 7 is the designed limit of the currency bar, and the README's
"Show Currencies" section already says only the first 7 are shown.

## #279 and #280 — ConsolePort cursor keeps acting on BetterBags after it closes

**Symptoms:** after closing the bag, the gamepad's plain Y button stops working (#279), and
the interact binding opens the BetterBags menu instead of talking to the NPC (#280). Both
behave as if ConsolePort's interface cursor were still active on the bag.

**Status (never fixed):** `integrations/consoleport.lua` registers the bag frames and every
`L_DropDownList%d` / `L_DropDownList%dButton%d` as ConsolePort cursor frames and selects
`L_DropDownList1Button2` when a menu opens. Apart from removing a config override, that code
is the same as in v0.1.14, the version reported. No change ever targeted these reports.
ConsolePort tracks the frames by hooking their `Show`/`Hide` (`ConsolePort_Cursor/Controller/Stack.lua`),
so the root cause needs a reproduction with ConsolePort; it is not known which registered
frame keeps the cursor active.

## #291 — Profession quality pips are clipped on the first row and column of every section

**Symptom:** the crafting-quality pip in the top-left corner of an item is cut off for items
in the left column (and the top row) of a section.

**Cause (verified):** every section's content is a scrollable grid:
`frames/section.lua:634` calls `grid:Create(s.frame)` without `false`, so `frames/grid.lua:576-591`
wraps the cells in a `WowScrollBox`, which inherits `clipChildren="true"`
(`Blizzard_SharedXML/Shared/Scroll/ScrollBox.xml:20`); the section only hides its scroll
bar. Cells start at x = 0, y = 0 of that box (`frames/grid.lua:464`, `:434`). Blizzard places
`ProfessionQualityOverlay` at `TOPLEFT -3, 2` of the button
(`Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua`, `SetupCraftingQualityOverlay`),
reached through `SetItemButtonQuality` (`frames/item.lua:573`), so 3 px on the left and 2 px
on the top fall outside the clip. The reporter's frame stack screenshot shows the same nesting
(`BetterBagsScrollGrid12` inside the bag's scroll box).

**Closed (does not reproduce):** the maintainer does not see clipped pips on the current
version, after the layout rework. The analysis above was code reading only; if clipped pips are
reported again, the clipping scroll box around each section's cells is the place to look.

## #382 — Items can fail to appear until /reload

**Symptom:** on Classic Era, a quest reward did not appear in the bag until a /reload (or
appeared much later). #472 (closed as its duplicate) is the same report.

**Status (inferred):** the mechanism of v0.1.48, a "refresh in progress" flag
(`items._doingRefresh`) that queued every later refresh until a draw finished, no longer
exists. The current path can still lose a bag's update, though:

- `data/loader.lua:126-152` (`ProcessPendingBagUpdates`) refreshes a bag only when a
  `ContinuableContainer` of all its items finishes loading, with no timeout.
- When an item's load fails, Blizzard clears its callbacks instead of firing them
  (`ITEM_DATA_LOAD_RESULT` with `success == false`: `Blizzard_ObjectAPI/Mainline/AsyncCallbackSystem.lua`;
  Classic Era `Blizzard_ObjectAPI/Classic/Item.lua`, `ItemEventListener`). The container then
  never completes, and the bag is not refreshed until a later batch for it completes.
- The startup read and the bank open read already guard against exactly this with
  `STARTUP_PRIME_TIMEOUT` and `BANK_PRIME_TIMEOUT` (`data/refresh.lua:32`, `:35`;
  refresh-scheduler.md §8, §11). Ordinary bag updates have no such guard.
- On Classic Era, Blizzard's `ContinuableContainer:RecheckEvictableContinuables`
  (`Blizzard_ObjectAPI/Classic/ContinuableContainer.lua`, `classic_era` branch) indexes an
  undefined `continuable` when an item's data was evicted before the container finished, which
  raises an error and leaves the container unfinished. Retail's version uses `evictableObject`.

None of this was captured; it is the remaining code path that produces the reported symptom.

## #408 — Dropping an unequipped item on the bag window does nothing

**Symptom:** dragging gear from the character panel onto the bag only unequips it when it is
dropped on a free slot button, not anywhere on the window as in AdiBags.

**Cause (verified):** the bag frame handles only `OnDragStart`/`OnDragStop` for moving the
window (`frames/bag.lua:939-948`). Nothing in the bag window, views or the default theme
handles `OnReceiveDrag` or a click with an item on the cursor; only the bag button
(`themes/themes.lua:553`, creates a category) and section titles (shift, adds to a category)
do. The maintainer acknowledged the request and planned it; it was never added.

**Fixed (#1132, issue closed):** the whole window is a drop target; the item goes into a free slot of the window's
bags through `util/cursorplacement.lua` (`.claude/rules/bag-drop-zone.md`). Not yet checked in
game; the taint check to run is in that rules file, §3.

## #437 — The bag moves up after a relog

**Symptom:** after logging back in, a bag placed in the upper part of the screen opens higher
than where it was left (clamped at the top).

**Cause (inferred from code):**

1. The bag frame is created 200 x 200 (`frames/bag.lua:841`), its saved position is restored
   (`:952`) and its bottom is recorded (`:953`). LibWindow saves a top-anchored point for a
   window in the upper half of the screen (`libs/LibWindow-1.1/LibWindow-1.1.lua`,
   `lib.SavePosition`), so the recorded bottom is the top minus 200.
2. The startup read draws the hidden bag. `Draw` on a hidden bag defers and calls its callback
   at once (`frames/bag.lua:560-567`), and that callback sets `loaded = true`
   (`core/init.lua:409-413`) before anything was drawn.
3. On the first open, the deferred draw resizes the frame to its real height, then
   `OnResize` (`frames/bag.lua:658`) sees `loaded` and re-anchors the frame's bottom-left to
   the bottom recorded in step 1 (`:672`). The bag grows upward from the placeholder's bottom,
   moving up by its real height minus 200.

A window saved bottom-anchored (lower half) keeps its place. The bag anchor feature
(`frames/anchor.lua`) bypasses this path.

## #463 — ElvUI theme: icon borders break when the bag is scaled

**Symptom:** with the ElvUI theme and a Scale below 100, some 1 px icon borders disappear
(the reporter's screenshot, scale 80).

**Cause (verified):** the theme skins item buttons with ElvUI's
`S:HandleItemButton`/`S:HandleIconBorder` (`themes/elvui.lua:172-173`), whose borders are
sized in `E.mult`, one physical pixel at ElvUI's UI scale (`E:UIMult`,
`ElvUI/Game/Shared/General/PixelPerfect.lua`). BetterBags then scales the whole bag frame with
`SetScale(scale / 100)` (`frames/bag.lua:633`), which makes those borders thinner than a
pixel. Nothing in the theme compensates for the bag's own scale.

---

## Related findings (not among the 20)

- **The Bank's Opacity slider has no effect** (found while checking #209). The slider saves
  the bank's opacity (`config/config.lua:574-586`), but `themes:ApplyTheme` and
  `themes:UpdateOpacity` apply the backpack's opacity to every window
  (`themes/themes.lua:82-83`, `:139-140`, `:293-298`, all reading
  `GetBagSizeInfo(const.BAG_KIND.BACKPACK, ...)`). Verified in code; no issue exists for it.
  **Fixed (#1133):** each bag window gets its own bag's opacity (`themes/README.md`).
- **WoW: Forever keyring** ([#1121](https://github.com/Cidan/BetterBags/issues/1121)). The
  Classic Era keyring is scanned (`core/era/constants.lua` lists `Enum.BagIndex.Keyring` in
  `BACKPACK_BAGS`), which is why #469 was closed. Forever loads only `core/constants.lua`, whose
  `BACKPACK_BAGS` had no keyring, so the Forever keyring (bag -1, camelot-forever.md §7) was
  never read. **Fixed (#1133), issue closed:** it is read with the backpack while the game enables it
  (camelot-forever.md §7). Not yet checked in game.

- **Pinned built-in categories are lost on every load: the cause of
  [#1107](https://github.com/Cidan/BetterBags/issues/1107)** (and its duplicate #1119). `DB:Migrate`
  runs on every load and ends with `DB:PruneOrphanedSectionSort()` (`core/database.lua`), which
  deletes every `customSectionSort` entry whose name is in neither `customCategoryFilters` nor
  `ephemeralCategoryFilters`. Built-in categories ("Armor", "Junk", "Miscellaneous") are in
  neither, so their pins are dropped at each load while custom categories keep theirs, which is
  what #1119 describes. The prune arrived in f9cf257, first released in v0.5.5; #1107 reports
  v0.5.0 working. Verified in code; not captured. **Fixed (#1133), issue closed:** the prune was removed,
  since no load-time check can tell a built-in category from a leftover
  (category-lifecycle.md §3).

## Closed as no longer applying

| Issue | Why |
|---|---|
| #171, #190 | BetterBags reparented the bag slot buttons into a hidden frame, which fought Bartender's bag bar. Removed in 786aeac (2024-08-31). |
| #180 | Plain searches match the tooltip text, including "Use:" lines (`data/search.lua` `defaultIndicies`, `data/tooltip.lua`). |
| #194 | Masque re-skins every decoration after each full draw (`integrations/masque.lua`); the black icons some skins left were fixed in 9d69005 and the integration rewritten since. |
| #209 | `themes:ApplyTheme` applies the opacity at load (since the Themes rework, d911299). |
| #253 | BetterBags hands Masque the stock `IconQuestTexture`; Masque skins it as its `QuestBorder` region and falls back to its square default when a skin has no art for it. |
| #433 | The old options item list was removed (b029d3a); the crash behind it (`GetDetailedItemLevelInfo`) now goes through `C_Item`. |
| #455 | The 60 s refresh context timeout that cancelled slow loads was removed (d242acd); nothing cancels contexts now. |
| #465 | Item buttons created mid-combat made the bag frame protected; every button is now created at boot (`frames/item.lua` `itemFrame:OnEnable`). |
| #469 | Keyring items were filtered out of the views; added back in 52df52e. |

# Second batch: #477 to #710

The next 20 oldest open bugs, triaged on 2026-10-16 against v0.5.16. Issues reporting a Lua
error were closed without further investigation, by the maintainer's decision: every one was
from v0.3.x or older, and the code they pointed at has been rewritten. Four are still valid:

| Issue | Client | Area | Confidence |
|---|---|---|---|
| [#528](https://github.com/Cidan/BetterBags/issues/528) | All | Bag scale in Show Bags | Verified in code |
| [#550](https://github.com/Cidan/BetterBags/issues/550) | Classic Era, WoW: Forever | Free space count | Verified in code |
| [#620](https://github.com/Cidan/BetterBags/issues/620) | Retail + Pawn | Upgrade arrows | Verified in code (and #1061's capture) |
| [#689](https://github.com/Cidan/BetterBags/issues/689) | All | Currency tab state | Verified in code |

## #528 — Turning on Show Bags snaps a scaled bag back to 100%

**Symptom:** a bag scaled to, say, 78% jumps back to full size when Show Bags is turned on, and
can end up partly off screen; it returns to 78% when Show Bags is turned off.

**Cause (verified):** size settings are stored per bag view (`DB:GetBagSizeInfo(kind, view)`
reads `size[view][kind]`, `core/database.lua:175`), scale and opacity included. The Scale slider
saves to the current view (`config/config.lua:596-603`), and the bag applies the current view's
scale on every draw (`frames/bag.lua:676`). Show Bags is its own view
(`const.BAG_VIEW.SECTION_ALL_BAGS`) with its own scale, 100% by default, so it ignores the scale
set in the category view. Items per row and columns are reasonably per view; scale and opacity
apply to the whole window, which is presumably what the player expects. The fix is a design
call: one scale and opacity per bag, not per view (with a migration), or keep them per view.

## #550 — "Show all free space" counts the keyring's empty slots

**Symptom:** with "Show all free space slots" on, the bag shows far more free slots than there
are (34 shown for 4 real, Classic Era); confirmed again in June and December 2025.

**Cause (verified):** the aggregated free-space counter leaves the keyring out
(`items:Phase5_UpdateFreeSlots`, the `Enum.BagIndex.Keyring` guard, `data/items.lua:660`), but
"show all" builds one button per empty slot from `emptySlotsSorted`, filtered only by
`IncludeBagInFreeSpace` (`data/items.lua:772`), which accepts every bag in `BACKPACK_BAGS`,
the keyring included (`data/items.lua:1550-1561`). On Classic Era that adds the keyring's 30-odd
empty slots, matching the report.

**Regression on WoW: Forever:** since v0.5.16 (#1121) the Forever keyring is a backpack bag too,
so players there with "Show all free space" on see the same thing. The test added with #1121
only checked the aggregated count. The fix is the same keyring exclusion in the "show all" path.

## #620 — Pawn upgrade arrows stall the game on every bag change

**Symptom:** with Pawn installed, looting, using an item or moving items freezes the game
briefly. #1061 (closed as its duplicate) measured 124 calls and about 64 ms in one frame per bag
render on retail, v0.4.10.

**Cause (verified):** `integrations/pawn.lua:35` calls `PawnShouldItemLinkHaveUpgradeArrowUnbudgeted`
for every item on every sweep; Pawn's verdicts are deliberately not cached (caches.md §2: an
attempt was reverted because it made sorting hitch), and the budgeted Pawn API is not used because
it answers nil once its budget is spent. Sweeps now read only changed slots (data-loader.md §16),
but every sweep still asks Pawn about every item. Pawn is picked automatically when it is
installed and the player never chose a provider (`items:GetActiveUpgradeProvider`,
`data/items.lua:123-131`).

**What changed since the report:** the "make it optional" request is done: choosing another
provider under "Upgrade Icon Provider" stops BetterBags from calling Pawn. The stall itself
remains for anyone who uses Pawn. Not captured on the current version.

## #689 — Collapsed currency headers expand again after a reload

**Symptom:** expansion headers collapsed in Blizzard's currency tab are expanded again after a
reload, which also affects other addons that read the currency list.

**Cause (verified):** `CurrencyIconGrid:Update` (`frames/currency.lua:96-98`) expands every
collapsed header (`C_CurrencyInfo.ExpandCurrencyList`, or the Classic global) so it can read the
whole list, and never collapses them again. The header state belongs to the client, so the
change shows in Blizzard's currency tab. The fix is to remember which headers were collapsed and
collapse them again after reading, the way the thread notes Altoholic does.

## Closed in the second batch

| Issue | Why |
|---|---|
| #631, #647, #652, #674 | Lua errors from v0.2.2 and v0.3.x, closed by the maintainer's rule for this batch. The code they point at was rewritten or removed (`frames/sectionitemlist.lua`, gone in v0.4.0). |
| #477 | Item level colors now scale with the character's own highest item level, in four tiers whose colors can be set (`util/color.lua`); the fixed Dragonflight item levels that turned everything orange are gone. Coloring by item level rather than quality is the design. |
| #571 | The custom category item list with that close button was removed in v0.4.0 (423f719). |
| #594 | The reporter traced the FPS drop to TradeSkillMaster. |
| #595 | Classic Era's own item button code (`frames/era/item.lua`, hid the glow and called a mixin method on the wrong frame) was merged into the shared item frame (#1044), which plays Era's own `NewItemTexture`, `flashAnim` and `newitemglowAnim`, and Era has `C_NewItems.IsNewItem`. |
| #618 | Settings, including theme and positions, are in the AceDB profile, shared ("Default") unless a character picks another; characters on automatic per-character profiles are moved to "Default" at login (`DB:Migrate`). |
| #621 | Categories are found by item ID (`customCategoryIndex`), and adding an item is a single write, so nothing scales with the category's size. From code; not profiled. |
| #688 | The square is the bag anchor, created hidden and shown only when its saved state says so (`frames/anchor.lua:132`), which only the anchor's Show sets; it defaults to off. |
| #693 | `[[...]]` and `"..."` give the same string in Lua on every platform; the glow was rewritten since. |
| #706 | Caused by an outdated plugin; resolved when the plugin updated (per the reporter). |
| #710 | User categories are saved by item ID and beat built-in categories in `items:GetCategory`; a search category winning at equal priority is by design (priority is configurable); plugin categories are rebuilt by the plugin each session. From code. |

## Feature requests filed as bugs

#522 (use the item with the fewest charges first) and #584 (a `BetterBagsSearch()` global;
`C_Container.SetItemSearch` itself can't drive BetterBags' search) are feature requests. Their
`bug` label was removed and they stay open with the `feature` label. Neither is implemented.
