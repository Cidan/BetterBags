# Caches and Their Invalidation

BetterBags keeps several values across sweeps so a one-slot change costs one slot of work.
A wrong kept value is the worst outcome a cache can produce (a wrong arrow, count, cooldown or
search result that stays), so every cache follows the same rules, and this file lists, for each
one, every input of the kept value and what invalidates it. **Any change to what a cached value
reads must add the matching invalidation here and a test that fails without it.**

## Rules every cache follows

- **Record what was applied, compare against the record, undo with the record.** Never compare
  or remove using the current ItemData's values: ItemData objects are reused and mutated in place
  (targeted merges, kept harvest slots, Phase 6/8 writes). See `.context/patterns-state.md`
  ("Incremental Work Without Drift").
- **Unknown is never kept.** A value read while the client had no data for it (cold item cache:
  `harvestIncomplete`), or an answer a provider could not give yet (`nil`), is not cached.
- **Wipes rebuild everything.** Every `wipe` sweep (`bags/FullRefreshAll` from the settings a
  read depends on and from other addons, `BAG_CONTAINER_UPDATE`, the first sweep per kind)
  starts from an emptied committed state, re-reads every slot and equipped item, bumps the draw
  and upgrade generations, and rebuilds the kind's search entries.
- **Recalculations read no bag slot.** A `derive` sweep (refresh-scheduler.md §10: most settings,
  categories, gear sets, tooltips resolving, upgrade inputs) runs every phase after the harvest on
  the committed items, refreshing a kept item's volatile fields (cache 1) only while its slot
  still holds it, and only in bags the client has not changed since their read
  (`items:MarkBagUnread`, refresh-scheduler.md §10). Settings and category recalculations also bump the draw generation and reset
  the layout, as their old wipes did. Anything a derive cannot see (a slot's own contents, the
  item level scaling changes) must still request a read.
- **An event that changes an input invalidates and refreshes.** Invalidation alone would leave
  stale values on screen until the next unrelated refresh.
- **Over-invalidating is acceptable; under-invalidating is not.** When in doubt, invalidate.

## The caches

### 1. Kept harvest slots (`items:ReuseHarvestedSlot`, data-loader.md §16)
Kept value: a slot's whole ItemData. Kept when, on a non-wipe sweep, all of these match what the
item was read from:
| Input | Check |
|---|---|
| Item ID, link, count, name, icon, quality, lock, bound, readable, loot, filtered, no-value | `C_Container.GetContainerItemInfo`, compared to the raw values (`rawItemName`, `rawIconFileID`, `rawQuality` before fallbacks) |
| Item traits (`itemInfo.traits`: crafting tier, required level, max stack, sell price, equipment, use, cosmetic, pet, upgrade track, stats; search-indexing.md §10) | the link above: each is a property of the item in the slot; scrappable is asked of the slot's location, which a kept slot keeps |
| Item identity (two identical stacks swapped) | `C_Item.GetItemGUID` |
| Current item level (scaling changes it without the link) | `C_Item.GetCurrentItemLevel` |
| Cold read | `harvestIncomplete` items are never kept |
Refreshed on every kept item, computed exactly as a fresh read (`items:RefreshKeptItem`, also run
by recalculations on every item still in its slot): new-item flag (`items:ClientNewItemFlag`),
gear sets, quest state, tooltip text, whether it can still be refunded (`itemInfo.refundable`,
automation.md §2), whether the character can use it, how many of its pet the
account has and whether its appearance is collected (`items:RefreshCharacterState`,
search-indexing.md §13, §14 and §17). Known staleness, the same as an unvisited bag: a refundable
purchase's binding expiring, an appearance being collected (until the slot changes or a wipe).

A guild bank slot (guild-bank.md §3) is kept the same way by `items:HarvestGuildBank`, compared on
everything the guild bank reports of it (`GuildBank:ReadSlot`: link, count, lock, icon, filter,
quality); it has no GUID or item location to compare. Never kept when read cold.

### 2. Upgrade verdicts (`items:ResolveUpgrade`, data-loader.md §15)
Kept value: `data.upgradeVerdict`, only for providers registered `{ cacheable = true }`: the
built-in `BetterBags` provider and Pawn. SimpleItemLevel is asked on every sweep, as before. A
`nil` answer (Pawn's "we're not sure yet": no item data or stats yet) draws no arrow and is not
kept. Reused only while `data.upgradeProvider` is the active provider and
`data.upgradeGeneration` equals `items._upgradeGeneration`. `InvalidateUpgrades(refresh)` bumps the
generation and, with `refresh`, refreshes the backpack and the open bank on the next frame
(`RequestUpgradeRefresh` coalesces a frame's requests into one refresh per kind and never drops a
kind requested later in the frame).
| Input | Invalidation |
|---|---|
| The bag item | A changed slot is a new ItemData (cache 1), which has no verdict |
| Which provider is active | Provider name in the key; the dropdown also recalculates the bags (`bags/Rederive`) |
| Equipped gear (item level and equip location in the item's slots; whether a slot is empty; the main hand's handedness; the item worn in a ring or trinket's other slot) | `PLAYER_EQUIPMENT_CHANGED`; the gear harvest invalidates when a slot's link, item level or equip location changed, or when the gear stopped reading cold (cache 3), and refreshes only the open bank: the backpack sweep that read the gear resolves every backpack verdict after its harvest (a backpack refresh there made every login read the bags twice) |
| Equipped gear not read yet | `equipmentCache` is nil until the first backpack sweep; no verdict is kept until then (a naked character's first read detects no change that would invalidate one) |
| The gear a verdict compares with | `HarvestEquipment` publishes `equipmentCache` as soon as it reads the gear, before anything else in the sweep, so a sweep that fails later cannot leave the bank judged against old gear under a new generation |
| Equipped gear read cold | No verdict is kept while any equipped slot reads cold (`_equipmentIncomplete`); once it reads warm the harvest invalidates (and refreshes the open bank), and that same sweep asks every backpack verdict again. The startup read primes the gear's item data, so it normally reads warm the first time |
| Player level and effective level (the item's level requirement, usability, scaling) | `PLAYER_LEVEL_UP`, `PLAYER_LEVEL_CHANGED` (level sync and other effective-level changes), `PLAYER_AVG_ITEM_LEVEL_UPDATE`; each also re-reads all gear |
| Proficiencies, skills and dual wield (`C_PlayerInfo.CanUseItem`, `CanDualWield`) | `SKILL_LINES_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE` (learning Dual Wield) |
| Reputation and spells (`C_PlayerInfo.CanUseItem`; the events Blizzard's usability refresh in `Blizzard_Wardrobe.lua` listens for) | `UPDATE_FACTION`, `SPELLS_CHANGED`: they fire often, so they invalidate without a refresh; the next refresh recomputes the verdicts, as before caching. The same events, bucketed, recalculate the bags when an item's usability changed (search-indexing.md §13), and that refresh recomputes the verdicts too |
| Specialization (the spec's primary stat; dual wield) | `PLAYER_SPECIALIZATION_CHANGED` for `"player"` |
| The item's stats (primary stats) | Part of the item: a changed slot is a new ItemData; scaling items change with level (above) |
| Settings | No setting but the provider is an input; every wipe invalidates anyway |
| Cold item | Verdicts of `harvestIncomplete` items are not kept |
| Pawn's own state (its scales and settings, its best items per scale, the spec) | `PawnResetBags`, hooked once (`hooksecurefunc`) when the Pawn integration registers: Pawn calls it after every change of what its verdicts read (scale and setting edits, spec changes, its throttled check of the equipped gear after inventory changes, out of combat; Pawn 2.13 `Pawn.lua`). It invalidates without a refresh, as Pawn expects of bag addons that are not registered with it |
Optional events are registered only when `C_EventUtils.IsEventValid` says the client has them
(Blizzard's own pattern); every event above exists on retail, WoW: Forever and every Classic
branch. `RegisterCacheEvents` runs once, from `items:OnEnable`.

**Pawn is cached, without the costs of the first attempt.** An earlier attempt (registering as a
Pawn third-party bag for `RefreshAll`, hooking every Pawn function that changes its state, and
checking Pawn had the data each answer needed) made sorting visibly hitch and was reverted: a sort
moves every item, so every verdict was re-asked anyway, the readiness checks roughly doubled the
cost of each ask, and refreshing on Pawn's signal (it signals on every item pickup) added a second
full sweep. Now: no readiness check (Pawn's own `nil` answer is not kept), one hook on
`PawnResetBags` that invalidates without a refresh, and nothing registered with Pawn. A sort still
asks about every item (each moved item is a new ItemData), once, as before. Pawn's check after
inventory changes always ends in `PawnResetBags`; it runs 0.25 s after `UNIT_INVENTORY_CHANGED`
(equipping, and an item taking a new bag slot, not loot onto a stack) or `ITEM_LOCKED` (an item
picked up), out of combat (warcraft.wiki.gg, Pawn 2.13 `PawnOnInventoryChanged`). So the refresh
after such a loot or move out of combat asks again about every item, as before; loot onto stacks,
a bank open, recalculations (a vendor, a tooltip that loaded, a bank tab switch) and refreshes in
combat ask only about new items. Pawn is called through `PawnShouldItemLinkHaveUpgradeArrowUnbudgeted`; the public time-budgeted check
answers nil once its budget is spent, which is why the internal one is used.

### 3. Equipped gear (`items:HarvestEquipment`)
Kept value: each equipment slot's ItemData (`items._equipped[slot]`), read on backpack sweeps.
| Input | Invalidation |
|---|---|
| The equipped item | `GetInventoryItemLink` compared every backpack sweep |
| Its current item level | `C_Item.GetCurrentItemLevel` on a per-slot `ItemLocation`, compared every sweep |
| Anything the client changes in place | `PLAYER_EQUIPMENT_CHANGED` marks the slot for a re-read |
| Level and scaling | `PLAYER_LEVEL_UP`, `PLAYER_LEVEL_CHANGED`, `PLAYER_AVG_ITEM_LEVEL_UPDATE` re-read every slot |
| Wipes | Every slot re-read |
| Cold read | `GetEquipmentInfo` sets `harvestIncomplete`; such a slot (or one with an item but no link) is read again every sweep, and verdicts are not kept meanwhile (cache 2) |
| A read that fails partway | Nothing is recorded (`_equipped`, dirty flags) until every slot was read, after the invalidation, so the next sweep reads the changed slots again and still sees the change |
The equip location comes from `C_Item.GetItemInfoInstant`, which never needs a server query, so
the built-in provider's two-hand check never sees a cold, empty equip location. Only the built-in
upgrade provider reads `equipmentCache` (`GetItemDataFromInventorySlot`).

### 4. Button draw record (`item.drawState`, item-drawing.md §7b)
Kept value: what the button shows. A redraw whose inputs (the item's `itemHash` and every other
field the setters read, `drawGeneration`, the decoration and Sonata's generation) match
the record is skipped. Invalidated by `ResetVisuals` (a release, or item/free/empty mode changes),
`SetSize` with a new size (Masque's skin follows the size only through a full draw's re-skin)
and `Lock`; `UpdateSearch` keeps the search match current. `drawGeneration` changes on every wipe;
`ItemFrame.styleGeneration` (also in the record, bumped by `RestyleButtons`) changes when a setting
the setters read changes with no new data (glow intensity, item level display), which reach the
buttons through a redraw (refresh-scheduler.md §9); Sonata's generation (`Sonata:GetGeneration()`)
changes with every theme applied, which restyles the decoration.

### 5. Button cooldown record (`item.cooldownState`, `itemProto:UpdateCooldown`)
Kept value: the cooldown last applied to the button (spiral, dimmed icon, has-item state).
`bag:OnCooldown` (every `BAG_UPDATE_COOLDOWN` window, and on bag open) reads each button's
cooldown with `C_Container.GetContainerItemCooldown`, using the bag and slot Blizzard's update
would read (retail: the decoration's `GetBagID`/`GetID`; Classic: the item's bag and the
decoration's ID), and skips Blizzard's update when the start, duration, enable, icon, decoration
and theme generation all match the record. Full draws always apply. `ResetVisuals` and
`SetFreeSlots` (which clear the cooldown) invalidate it; item rows never skip. Nothing else in
BetterBags or in Blizzard's code writes the decoration's cooldown or icon tint between draws (the
decorations are not part of Blizzard's container frames). No assumption is made about which items
can have cooldowns: every button's cooldown is read from the client each window.

### 6. Search index snapshots (`search.indexed`, search-indexing.md §1)
Kept value: what each slot is indexed with, and the item object it was indexed from
(`search.indexedItems`). `search:SyncKind` re-indexes an item whose fresh snapshot differs, removes
slots that are gone or empty, and rebuilds the kind on a wipe. The pipeline passes the items it
worked out again (cache 8, `indexPending`); every other item that is the object its slot was
indexed from is taken as indexed without a comparison, since every in-place change of an indexed
value either drops the item's kept work (which marks it) or goes through `UpdateCategoryIndex`.
Checked against a clean rebuild by a randomized test and a per-field test.

### 7. Tooltip text (`TooltipScanner`, tooltip-scanning.md)
Kept value: an item's tooltip text by GUID, and what its whole lines mark (toy, already known;
search-indexing.md §12), kept and dropped together. Invalidated by `TOOLTIP_DATA_UPDATE` for the
item's tooltip instance (bounded re-scans). Kept harvest slots and recalculations re-fetch it, so a
re-scan lands; a resolution asks for a recalculation, not a read.

### 8. Kept per-item work (`item.derived`, data-loader.md §18)
Kept value: an item's own category, the category it is shown in, and its grey-out, each with what
it was worked out from.
| Input | Invalidation |
|---|---|
| The item itself | A changed slot is a new ItemData (cache 1), which has nothing kept |
| Quest state, tooltip text, gear sets (changed in place) | `RefreshKeptItem` drops `derived` when one differs; `RederiveGuildBank` for a guild item's tooltip |
| Recency (`IsNewItem`, and the stack's, virtual-stacks.md §9; the own category and `base` leave it out) | Compared every sweep; it only picks between `base` and Recent Items |
| Category settings and definitions | The kind's category generation: wipes, recalculations without `categoriesUnchanged`, reads that absorbed one (`recategorize`); and the Categories module's generation (every change made through it) |
| Search categories matched (name and priority) | Compared every sweep with the search cache, which is rebuilt every sweep |
| The item context, the bank open, the bank showing a Warbank tab | `contextSignature()` compared every sweep; under an active item context grey-out is worked out every sweep |
| Show Bags | Not kept: section names are set every sweep |
A sweep that fails partway leaves each item either worked out (with its record) or not, never a
record that claims more: `indexPending` stays on an item until it is indexed.

### Not caches
- Phase 6's bag names and qualities for empty slots are looked up once per bag **per sweep**
  (`bagDetailsOf`), and so is every item's plain bag name (`item.bagName`, `items:GetPlainBagName`,
  the `bagname` search field); nothing is kept across sweeps, because bags can be swapped.

## Coverage
`spec/refresh_pipeline_spec.lua` ("per-slot harvest cache", "equipped gear cache", "upgrade
verdict cache" — one test per invalidating event, provider scoping, coalescing, cold gear and its
warming, failed sweeps and failed gear reads, same-sweep gear — "draw generation", "incremental
search index", "deriving only what changed", "looks up a bag's name once per sweep", "looks a bag's
name up again on the next sweep"), `spec/items_spec.lua` ("kept verdicts": Pawn),
`spec/categories_spec.lua` ("generation"), `spec/frames/item_spec.lua`
("cooldown refresh", "skipping a redraw whose inputs are unchanged"),
`spec/frames/bag_draw_ownership_spec.lua` ("cooldown refresh (OnCooldown)"),
`spec/search_spec.lua` ("Search incremental indexing (SyncKind)", "with the items that changed").
