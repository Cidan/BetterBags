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
built-in `BetterBags` provider. SimpleItemLevel is asked on every sweep, as before; so is Pawn's
provider, which answers from what it keeps by link (§2a). A provider's `nil` answer draws no arrow
and is not kept. Reused only while `data.upgradeProvider` is the active provider and
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
| An answer the provider cannot give yet | Not kept, and the item is marked `upgradeUnknown` until it can (§2a) |
Optional events are registered only when `C_EventUtils.IsEventValid` says the client has them
(Blizzard's own pattern); every event above exists on retail, WoW: Forever and every Classic
branch. `RegisterCacheEvents` runs once, from `items:OnEnable`.

### 2a. Pawn's answers (`integrations/pawn.lua`)
Kept value: what Pawn last said about each item (`pawn.answers`), with the upgrade generation it was asked in
(`pawn.answeredAt`), under the item's link without the player's level and spec (`pawn:keyOf`). No verdict is kept on an item, so a
read asks the integration about every item, which is a table lookup or two.

**Why (issue #1209, measured).** A captured loot: `UNIT_INVENTORY_CHANGED`, Pawn's `PawnResetBags` 0.25 s later, our hook on it
starting a new generation, and the refresh that followed asking Pawn about all 163 items through the unbudgeted question: about
141 ms of a 150 ms frame, 0.87 ms a question, with the bags closed and no answer changed. Two loots a third of a second apart cost
it twice.

**Pawn's contract** (Pawn 2.14 `PawnBags.lua`, "If you're the author of a bag addon"): ask `PawnShouldItemLinkHaveUpgradeArrow(link,
true)`, which answers nil past its budget (2/60 of a quarter second, 8.3 ms, `BudgetThrottle`) or without an item's data, so check
back on a timer; register with `PawnRegisterThirdPartyBag(name, { RefreshAll })` to hear when arrows may have changed.
`PawnShouldItemLinkHaveUpgradeArrowUnbudgeted` is marked "Internal only. Don't use this", and we hook nothing of Pawn's now.

| Input | What happens |
|---|---|
| The item | The link is the key: a new stack, a sort or a full re-read asks nothing. A link never seen is asked about in the read, so a looted item has its arrow on the read that found it, unless the budget is spent |
| The player's level and spec | Every bag item's link carries both (`\|Hitem:6948::::::::90:66:...`, every link of a retail dump), so they are left out of the key, or a level-up or respec would change every link and take every arrow away until its turn. What starts the new generation has it checked again, asking with the link a read last saw (`pawn.links`) |
| Pawn's own state (scales, settings, best items per scale, spec) | `RefreshAll`, called by `PawnResetBags`: scale and setting edits, spec changes, and its check after inventory changes, at most once per 0.25 s (`VgerCore.Throttle`: the first at once, a later one when the 0.25 s is up) on `UNIT_INVENTORY_CHANGED` or `ITEM_LOCKED`, skipped in combat (most loots, few of which change an answer). Starts a new generation and queues every item the bags hold |
| Gear, level, skills, spec, spells, reputation | The upgrade generation (§2). The next read or recalculation queues what it finds out of date |
| The provider in use | A signal or a turn that finds Pawn is not the provider forgets everything: it misses Pawn's signals while it is not |

**The queue.** One timer, a quarter second a turn (Pawn's budget comes back then), and each link in the queue once. A turn asks
until Pawn says nil, which may mean the budget is gone, and sends that link to the back. **What waits keeps its turn**: another
signal does not clear the queue (asked: "do we clear the queue if there is one"), so a burst costs one round; what was answered
before the signal goes behind what still waits, so nothing starves however often Pawn signals; what shows no answer yet goes to
the front. An item keeps its old answer while it waits, and a read never asks about it: that was the freeze. A link Pawn has said
nil about 20 times since it last answered waits for the next read, so one Pawn can never answer about does not keep the timer
going; a read that answers it later still tells any other bag holding it (`pawn.gaveUp`). In combat turns ask nothing, and go on
after it (Pawn skips its own check there too); a link never seen is still asked in a read. An answer is kept under the generation
read before asking, so a signal from inside the question makes it wait again.

**Not known yet is not "not an upgrade".** Found by an adversarial review, and reproduced on the real Automation and Seller: an item
Pawn has no answer for showed as no upgrade, so while the budget was spent a rule `upgrade = false` with Auto Sell on sold 3 of 5
real upgrades (`docs/vendor-compat.md` maps Vendor's `Pawn_IsUpgrade()` to this field, and buyback keeps only 12 items). A provider's
nil now leaves the item marked `upgradeUnknown` (`items:ResolveUpgrade`): it draws no arrow, the `upgrade` search field is absent
(search-indexing.md §11, as for an item read cold), and Automation leaves it alone (automation.md §2; the field alone is not enough,
since `NOT upgrade = true` also matches an absent value). Skip Recent Items leaves it alone too (recent-items.md §4): what that ends
cannot be given back when the answer says otherwise. It lasts as long as Pawn has no answer: seconds, on a session's first read or a
bank's first open, and when a read holds more new links than the budget covers. A sale is one list, so with Confirm Auto Sell off it
waits for those items as a merchant opens, at most 10 s, or a merchant beside a login would leave them out for the whole visit
(automation.md §3). An old answer is not "not known": an item
waiting to be checked again is sold by what Pawn last said, since Pawn signals on every item picked up and blocking on that would
stop Auto Sell for seconds after any loot. That leaves one case: an item that became an upgrade by a level-up, sold by a rule
`upgrade = false` at a merchant within the seconds it takes to check it.

**Showing a change** (asked: "let's take care not to trigger full redraws"). A signal asks for no refresh. Only an answer that
changed the arrow recalculates, and only the open bags holding that link (`bags/Rederive` with `categoriesUnchanged`, no
`resetLayout`, no `buttons`), at most once a second while others wait and once more when the queue is done; a button draws only if
what it shows changed (item-drawing.md §7b). A first answer that is no upgrade moves no arrow, but the item shows as not known until
it arrives, so it goes along with a recalculation for an arrow, or when the queue is done, or 5 s after it came: a first open of a big
bank would otherwise recalculate every second for no change on screen, and moving things at the bank, with a signal each time, keeps
the queue from emptying for minutes. A loot with every answer the same recalculates nothing.

**The first attempt, and why this is not it.** Registering as a third-party bag was tried and reverted: it made sorting visibly
hitch. A sort moved every item, so every verdict on an item was asked again; readiness checks doubled each question; and it
refreshed on Pawn's signal, a second full sweep per item picked up. Here the link is the key, there is no readiness check, and the
signal refreshes nothing.

**Accepted:**
- Registering turns off Pawn's arrows on Blizzard's own bag frames (`PawnIsAThirdPartyBagRegistered`, `PawnBags.lua`). That only shows
  on Blizzard's bank with Enable Bank Bags off, which loses them.
- Answers for links no bag holds any more stay until Pawn stops being the provider; they cost a table entry each.
- A bank closed mid-round leaves its links in the queue: up to about 18 s more at Pawn's budget for a 740-link bank (measured by the
  review on mocks). The answers are not wasted: the next open shows them at once.
- `PawnRegisterThirdPartyBag` came with Pawn 2.13.1 (its `Version history.md`). An older Pawn gets no arrows, and a line in chat says
  to update it once (`PawnVersion`).
- A link that gave up keeps what it shows until the next read, if its data arrives after 20 tries: as before, nothing retried until
  a refresh.
- With Pawn not ready (`PawnIsReady`, its API: a start-up that failed, where each question would print a failure and every item stay not
  known, stopping Auto Sell for good) an item gets no arrow and counts as answered, and nothing is asked. Pawn is ready from
  `PLAYER_LOGIN`, before the bags' first read.
- A provider that means "no" by returning nil would stop Auto Sell, as "not known" for good. `RegisterUpgradeProvider` takes a function
  returning a boolean; the built-in one and SimpleItemLevel do.
- A recalculation reads no links, so an item checked again right after a respec is asked about with the link last read, and a read of the
  new link in that generation asks nothing. It matters only if the client changes bag links with no `BAG_UPDATE` and Pawn's answer reads the
  link's spec; the next signal corrects it. Asking again per link would loop between two bags holding one item under different links, each
  answer recalculating, so it is left. Check in game: respec with a two-primary item in the bags.

**Cost, simulated with the capture's 0.87 ms** (`spec/integrations/pawn_spec.lua`, "the reported loot"; not captured in game yet): the
loot's frame asks one question; the other 163 items take about 4 s, at most Pawn's 8.3 ms a turn. Capture a loot with the profiler
to confirm: `Pawn.Turn` returns how many it asked and how many wait, `Pawn.OnArrowsReset` how many wait.

**Coverage:** `spec/integrations/pawn_spec.lua` (registering and an old Pawn; answering a read; the signal, several signals and what waits
keeping its turn; links that follow the level and spec; links Pawn is not sure about and giving up; when a change is shown; combat; the
provider switched; an error from Pawn; the reported loot at the capture's cost), `spec/refresh_pipeline_spec.lua` ("Pawn's answers" on the
real pipeline, the upgrade field while not known, a respec; "a simulated client" > "with Pawn": Pawn's real budget and everything the client
does with enough items and a dear enough question that the budget runs out, every arrow and search entry Pawn's answer once quiet, and
the real Automation and Seller, by both `upgrade = false` and `NOT upgrade = true`, selling no upgrade and everything else in one visit after
a level-up or while Pawn has no answer), `spec/items_spec.lua` ("Pawn provider"), `spec/automation_spec.lua` (left alone while not known, a sale
waiting for answers), `spec/integration/pawn_spec.lua` (the whole addon, both designs). Mutation-tested over three rounds, 119 mutations on the final code; those
that survived led to tests, or to removing what they showed did nothing (a reset of the queue's indices, clearing `gaveUp` on an answer, a
check for an empty sale). One is equivalent: `|Hitem:` in the key's pattern differs only for a caged pet, which is never asked about.
Two adversarial reviews found what the tests first missed: selling upgrades, arrows lost on a respec, a sale leaving items out for a visit,
Skip Recent Items acting on a guess, a broken Pawn stopping Auto Sell.

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
name up again on the next sweep"), `spec/integrations/pawn_spec.lua` and `spec/refresh_pipeline_spec.lua` ("Pawn's answers"),
`spec/categories_spec.lua` ("generation"), `spec/frames/item_spec.lua`
("cooldown refresh", "skipping a redraw whose inputs are unchanged"),
`spec/frames/bag_draw_ownership_spec.lua` ("cooldown refresh (OnCooldown)"),
`spec/search_spec.lua` ("Search incremental indexing (SyncKind)", "with the items that changed").
