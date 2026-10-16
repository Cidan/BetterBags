# Valid Bugs (Triage of the 20 Oldest Open Bug Reports)

Triage date: 2026-10-15, against `main` at 20406c4.

The 20 oldest open issues labeled `bug` (after closing duplicates) were checked against the
current code. Ten no longer apply and were closed on GitHub with the reason. The ten below
were still valid at triage; #175, #183 and #408 have since been fixed and closed (marked below).

Each entry says what was **verified** (read in the code, the Blizzard UI source under
`.libraries/wow-ui-source`, or the external addon's source) and what is **inferred** (traced
from code, not shown by a capture). No in-game capture was taken for any of them.

| Issue | Client | Area | Confidence |
|---|---|---|---|
| [#175](https://github.com/Cidan/BetterBags/issues/175) | Retail, non-Latin locales | Category item list font | Verified; **fixed** |
| [#183](https://github.com/Cidan/BetterBags/issues/183) | All | Category names | Verified; **fixed** |
| [#204](https://github.com/Cidan/BetterBags/issues/204) | All | Currency bar | Verified |
| [#279](https://github.com/Cidan/BetterBags/issues/279) | Retail + ConsolePort | Gamepad cursor | Never fixed; not reproduced |
| [#280](https://github.com/Cidan/BetterBags/issues/280) | Retail + ConsolePort | Gamepad cursor | Never fixed; not reproduced |
| [#291](https://github.com/Cidan/BetterBags/issues/291) | Retail | Section clipping | Verified |
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

**Fixed (ce7767f, issue closed):** the row now uses `STANDARD_TEXT_FONT`, the locale's file that Blizzard sets on
every client (`Blizzard_Fonts_Shared/Shared/GameFonts.xml`). Roman clients get the same file
as before.

## #183 — "Quest - Quest - <Expansion>"

**Symptom:** with the Subtype category filter on, quest items are filed under
"Quest - Quest", because the item's type and subtype are both "Quest".

**Cause (verified):** `items:GetCategory` (`data/items.lua:2948` and `:2965`) appends the
type, then " - " and the subtype, with no check for them being equal. Subtype is off by
default (`core/constants.lua` `categoryFilters`), which hides it for most users. The
maintainer agreed it should be deduplicated.

**Fixed (ce7767f, issue closed):** a subtype equal to the type before it is skipped ("Quest", "Quest - Classic"), and
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

**Fixed (f397560, issue closed):** the whole window is a drop target; the item goes into a free slot of the window's
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
- **WoW: Forever keyring** ([#1121](https://github.com/Cidan/BetterBags/issues/1121), still
  open). The Classic Era keyring is scanned (`core/era/constants.lua` lists
  `Enum.BagIndex.Keyring` in `BACKPACK_BAGS`), which is why #469 was closed. Forever loads only
  `core/constants.lua`, whose `BACKPACK_BAGS` has no keyring, so the Forever keyring (bag -1,
  camelot-forever.md §7) is never read.

- **Pinned built-in categories are lost on every load: the cause of
  [#1107](https://github.com/Cidan/BetterBags/issues/1107)** (and its duplicate #1119). `DB:Migrate`
  runs on every load and ends with `DB:PruneOrphanedSectionSort()` (`core/database.lua`), which
  deletes every `customSectionSort` entry whose name is in neither `customCategoryFilters` nor
  `ephemeralCategoryFilters`. Built-in categories ("Armor", "Junk", "Miscellaneous") are in
  neither, so their pins are dropped at each load while custom categories keep theirs, which is
  what #1119 describes. The prune arrived in f9cf257, first released in v0.5.5; #1107 reports
  v0.5.0 working. Verified in code; not captured.

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
