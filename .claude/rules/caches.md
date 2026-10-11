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
- **Wipes rebuild everything.** Every `wipe` sweep (`bags/FullRefreshAll` from every settings
  change, `BAG_CONTAINER_UPDATE`, `EQUIPMENT_SETS_CHANGED`, the first sweep per kind) starts from
  an emptied committed state, re-reads every slot and equipped item, bumps the draw and upgrade
  generations, and rebuilds the kind's search entries.
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
| Item identity (two identical stacks swapped) | `C_Item.GetItemGUID` |
| Current item level (scaling changes it without the link) | `C_Item.GetCurrentItemLevel` |
| Cold read | `harvestIncomplete` items are never kept |
Refreshed on every kept item, computed exactly as a fresh read: new-item flag (`clientNewItemFlag`),
gear sets, quest state, tooltip text. Known staleness, the same as an unvisited bag: a refundable
purchase's binding expiring, an appearance being collected (until the slot changes or a wipe).

### 2. Upgrade verdicts (`items:ResolveUpgrade`, data-loader.md §15)
Kept value: `data.upgradeVerdict`, only for providers registered `{ cacheable = true }`: the
built-in `BetterBags` provider, and `Pawn` when Pawn has `PawnRegisterThirdPartyBag` and runs on
Mainline (`VgerCore.IsMainline`; elsewhere Pawn re-checks its own item data on every call, which a
kept verdict would bypass) with every Pawn function its readiness check calls present. A provider can return a second value `false` to mark one answer as not
to be kept; it is shown and asked again on the next sweep. Reused only
while `data.upgradeProvider` is the active provider and `data.upgradeGeneration` equals that
provider's generation (`items._upgradeGenerations[provider]`). `InvalidateUpgrades(provider,
refresh)` bumps one provider's generation (or every provider's) and, with `refresh`, refreshes the
backpack and the open bank on the next frame (`RequestUpgradeRefresh` coalesces a frame's requests
into one refresh per kind and never drops a kind requested later in the frame).
| Input | Invalidation |
|---|---|
| The bag item | A changed slot is a new ItemData (cache 1), which has no verdict |
| Which provider is active | Provider name in the key; the dropdown also sends `bags/FullRefreshAll` |
| Equipped gear (built-in compares item level and equip location; Pawn checks handedness and its best items) | `PLAYER_EQUIPMENT_CHANGED`; the gear harvest invalidates every provider and refreshes when a slot's link, item level or equip location changed, or when the gear stopped reading cold (cache 3) |
| The gear a verdict compares with | `HarvestEquipment` publishes `equipmentCache` as soon as it reads the gear, before anything else in the sweep, so a sweep that fails later cannot leave the bank judged against old gear under a new generation |
| Equipped gear read cold | No verdict is kept while any equipped slot reads cold (`_equipmentIncomplete`); the backpack is retried until it reads warm, which invalidates and refreshes |
| Player level and effective level (Pawn's minimum-level check, usability, scaling) | `PLAYER_LEVEL_UP`, `PLAYER_LEVEL_CHANGED` (level sync and other effective-level changes), `PLAYER_AVG_ITEM_LEVEL_UPDATE`; each also re-reads all gear |
| Proficiencies and skills (`C_PlayerInfo.CanUseItem`) | `SKILL_LINES_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE` |
| Reputation and spells (`C_PlayerInfo.CanUseItem`; the events Blizzard's usability refresh in `Blizzard_Wardrobe.lua` listens for) | `UPDATE_FACTION`, `SPELLS_CHANGED`: they fire often, so they drop only the built-in provider's verdicts and request no refresh; the next refresh recomputes them, as before caching |
| Specialization | `PLAYER_SPECIALIZATION_CHANGED` for `"player"` |
| Pawn's own state (scales and values, visibility, options, best items and item levels, artifacts, plugin scales, initialization) | Pawn's `RefreshAll` (`PawnRegisterThirdPartyBag`), **plus** a hook on each Pawn function that changes that state (`PAWN_STATE_FUNCTIONS` in `integrations/pawn.lua`, from Pawn 2.13.16: Pawn does not call `RefreshAll` after adding, deleting or duplicating a scale, plugin scales, or the item-level part of losing an item), **plus** Pawn's window `OnHide` for options its window sets directly. Each drops Pawn's verdicts whether or not Pawn is active, and refreshes while it is |
| Pawn answering without the data it needs | Pawn answers a definite `false`, not "not sure", when it has no data for the item or for an equipped item it compares with ("we can't evaluate upgrades yet", `Pawn.lua`), and sends no signal when the data arrives. The Pawn provider checks Pawn's data for the item (unless it can never have stats; a relic's answer is never kept while Pawn shows relic upgrades, since Pawn's relic check answers false while relic data loads), for the equipped items in the item's slots, and for weapons for both weapon slots and the equipped weapon link whose handedness Pawn reads (the main hand's, or the off hand's when the main hand is empty); if any is missing the answer is not kept. Checking both weapon slots is more than Pawn needs (its second comparison slot exists only for rings, trinkets and one-hand weapons) and only ever keeps fewer answers |
| A link Pawn can never arrow (caged battle pet, keystone: not an `item:` link) | Pawn answers nil for it forever (`GetItemInfo` has no item); the Pawn provider answers a definite `false` without asking Pawn |
| Settings | Every wipe invalidates every provider |
| Cold item | Verdicts of `harvestIncomplete` items are not kept |
| Provider not sure yet (`nil`: item data still loading) | Not kept, and the item shows **no** arrow, exactly as before caching. After the sweep, `FinishUpgradeResolution` refreshes the bag 0.25 s later while items are unanswered. A round makes progress when an item unanswered last round was answered or is gone, or when an item is unanswered that was not last round (new loot, a moved item, a re-asked item that stopped answering); a round with nothing unanswered clears the count. After 8 rounds in a row without progress the bag is given up until progress. An invalidation is deliberately not progress: invalidations are frequent (Pawn sends one on every item pickup; reputation and spell events arrive constantly), so restarting retries on them would re-sweep a bag forever for an item that is never answered. Given-up items are still never kept: every later sweep asks again, as before caching |
Pawn is asked with `PawnShouldItemLinkHaveUpgradeArrowUnbudgeted`, the check that always answers,
not its public time-budgeted `PawnShouldItemLinkHaveUpgradeArrow`. The budgeted check answers nil
once Pawn's quarter-second budget is spent, which would force either missing arrows (a flicker
after every Pawn `RefreshAll`, which Pawn sends on every item pickup, new loot slot and gear change)
or arrows from before the inputs changed while waiting, and its shared budget starved one bag's
retries with the other's. With verdicts kept, Pawn is only asked when an input changed, so the
always-answering check costs at most what every refresh cost before caching.
Optional events are registered only when `C_EventUtils.IsEventValid` says the client has them
(Blizzard's own pattern); every event above exists on retail, WoW: Forever and every Classic
branch. `RegisterCacheEvents` runs once, from `items:OnEnable`.

Pawn skips its own inventory check in combat (`PawnOnInventoryChanged`); our
`PLAYER_EQUIPMENT_CHANGED` still re-asks Pawn, and when Pawn later updates its state it calls
`RefreshAll`, which invalidates again. That is the same answer an uncached ask would get.

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
field the setters read, `drawGeneration`, the decoration and `themes.decorationGeneration`) match
the record is skipped. Invalidated by `ResetVisuals` (a release, or item/free/empty mode changes)
and `Lock`; `UpdateSearch` keeps the search match current. `drawGeneration` changes on every wipe,
which is how settings that change a button's look without changing its data reach it.

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
Kept value: what each slot is indexed with. `search:SyncKind` re-indexes an item whose fresh
snapshot differs, removes slots that are gone or empty, and rebuilds the kind on a wipe. Checked
against a clean rebuild by a randomized test and a per-field test.

### 7. Tooltip text (`TooltipScanner`, tooltip-scanning.md)
Kept value: an item's tooltip text by GUID. Invalidated by `TOOLTIP_DATA_UPDATE` for the item's
tooltip instance (bounded re-scans). Kept harvest slots re-fetch it, so a re-scan lands.

### Not caches
- Phase 6's bag names and qualities for empty slots are looked up once per bag **per sweep**
  (`bagDetailsOf`); nothing is kept across sweeps, because bags can be swapped.

## Coverage
`spec/refresh_pipeline_spec.lua` ("per-slot harvest cache", "equipped gear cache", "upgrade
verdict cache" — one test per invalidating event, provider scoping, retries with and without
progress, coalescing, cold gear, a failed sweep, same-sweep gear — "draw generation", "incremental
search index", "looks up a bag's name once per sweep", "looks a bag's name up again on the next
sweep"), `spec/items_spec.lua` ("third-party bag contract": one test per hooked Pawn function, the
window hook, `RefreshAll` while inactive), `spec/frames/item_spec.lua`
("cooldown refresh", "skipping a redraw whose inputs are unchanged"),
`spec/frames/bag_draw_ownership_spec.lua` ("cooldown refresh (OnCooldown)"),
`spec/search_spec.lua` ("Search incremental indexing (SyncKind)").
