# Tooltip Text Scanning & Sparse-Tooltip Resolution

BetterBags scans each item's tooltip body into `itemInfo.tooltipText` (Phase 2 harvest,
`data/items.lua` → `tooltipScanner:GetTooltipText`) and indexes it under the `tooltip`
search field (`data/search.lua`). This documents how the scan is cached and how the
**retail sparse-tooltip race** is resolved.

## 1. The race: a cold scan can cache a partial tooltip forever

`tooltipScanner` (`data/tooltip.lua`) caches scanned text keyed by **item GUID**
(`self.cache`) and short-circuits `GetTooltipText` on a cache hit. The retail scan uses
`C_TooltipInfo.GetBagItem`, whose returned `TooltipData` can be **sparse**: an item's
"Use:" spell line (`Enum.TooltipDataLineType.ItemSpellTriggerOnUse`, 12.1.0) and spell
description are loaded on a **separate async channel** (`C_Spell.RequestLoadSpellData` →
`SPELL_DATA_LOAD_RESULT`) from the item's base data (`C_Item.RequestLoadItemDataByID` →
`ITEM_DATA_LOAD_RESULT`). The `ItemLoader` `ContinuableContainer` barrier
(`data/loader.lua`) waits only on the **item** channel, so the harvest can scan a tooltip
whose name line is present but whose "Use:" line is still cold.

`GetTooltipText` caches any **non-empty** result, so a cold, name-only scan is cached and
— because nothing invalidated the cache (`ClearCache`/`RemoveFromCache` had **zero**
production callers, and no `TOOLTIP_DATA_UPDATE` listener existed) — it stuck until a
`/reload`. Symptom: searching a word that lives only in the tooltip body (e.g. `health`
from "Use: Restores 70 to 90 health.") **intermittently** failed to match, depending on
whether spell data happened to be warm at scan time. Confirmed on WoW: Forever 1.60.1
(a mainline fork, `addon.isRetail == true`): `GetBagItem` returned the type-44 "Use:" line
in `leftText` directly (no `TooltipUtil.SurfaceArgs` needed), so capture worked *when warm*
— the defect was purely the cold-scan + never-invalidated cache.

## 2. The fix (retail only): resolve via `TOOLTIP_DATA_UPDATE`

`TOOLTIP_DATA_UPDATE` fires (with a `dataInstanceID`) when a previously-sparse tooltip
resolves — this is how Blizzard's own `GameTooltip` rebuilds itself
(`Blizzard_GameTooltip/Mainline/GameTooltip.lua`). BetterBags mirrors it:

- **Instance map.** `GetTooltipText` records the tooltip's `dataInstanceID` (surfaced as
  `ExtractRetail`'s second return) against the item GUID it cached under, via
  `RecordInstance`. Two maps (`instanceToGUID`, `guidToInstance`) are kept **strictly 1:1
  with `cache`**: `RecordInstance` drops any prior instance id for a GUID, and
  `RemoveFromCache`/`ClearCache` clear the map entries too — so they can never leak an
  entry for a GUID whose text is gone.
- **Listener (retail, once).** `Init` registers `events:BucketEvent('TOOLTIP_DATA_UPDATE',
  …)` **only when `addon.isRetail`** and **guarded by `self._tooltipUpdateHooked`** so
  repeated `Init` calls (tests) never leak duplicate handlers. The event exists on Classic
  too, but `C_TooltipInfo`/`dataInstanceID` do **not** (retail-only API, verified via the
  wiki "Game Types" badge), so Classic keeps its unchanged `GameTooltip:SetBagItem`
  FontString scan and is not wired to this path.
- **`OnTooltipDataResolved(resolved)`** iterates the debounced batch; for each resolved
  `dataInstanceID` that maps to one of our cached GUIDs it `RemoveFromCache`s the stale
  entry (so the next harvest re-scans it warm) and, if anything was invalidated, sends
  `bags/RefreshBackpack` (always) and `bags/RefreshBank` (**only when `addon.atBank`**, so
  we never clobber the last-seen bank contents while away). Unknown/`nil` instance ids are
  ignored — no spurious refresh.

Because `RemoveFromCache` only drops the invalidated GUID, the triggered re-harvest
re-scans just that item; every other item hits the warm cache. The re-index is the normal
`Phase8` clean sweep.

## 3. `BucketEvent` now coalesces per-fire args (reusable primitive)

`TOOLTIP_DATA_UPDATE` fires in bursts as data warms; the debounce **and** the collection of
each fire's `dataInstanceID` belong in the Events module, not a hand-rolled timer in the
scanner. `events:BucketEvent(event, callback)` (`core/events.lua`) was expanded: it still
debounces to 0.2s, but now accumulates every fire's payload in the window and passes the
callback an `EventArg[]` as its **second** argument (each entry `{ eventName, args = {…} }`;
`args[1]` is the first payload — e.g. the `dataInstanceID`). Its prior contract is
preserved: `ctx` is still the first arg, callbacks that ignore the second arg (e.g.
`bags/backpack.lua`'s `BAG_UPDATE_COOLDOWN`) are unaffected, and the reset-callbacks-per-
registration behavior is unchanged. Coverage: `spec/events_spec.lua` ("passes the collected
per-fire event arguments to the callback").

## 4. Coverage

`spec/tooltip_spec.lua` ("TOOLTIP_DATA_UPDATE resolution"): records the instance map,
invalidates + re-harvests on resolution, re-scans warm on next lookup, ignores
unknown/`nil` ids, gates the bank refresh on `addon.atBank`, keeps the maps 1:1 with the
cache across re-scan, and asserts the bucket registers exactly once across repeated `Init`
(no handler leak). The spec reuses the real `Events`/`Context` modules when present (only
loading them when absent, to avoid double-`NewModule` collisions) and restores the two
overridden `Events` methods on teardown.
