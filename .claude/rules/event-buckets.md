# Event Buckets (`events:BucketEvent`) and Bag Cooldown Refresh

This documents the contract of `events:BucketEvent` (`core/events.lua`), the bugs its
previous implementation had, and how bag item cooldowns are refreshed.

## 1. Contract

`events:BucketEvent(event, callback, filter)` batches a high-frequency WoW event into 0.2s
windows:

- **Windows, not a debounce.** The first accepted fire opens a window by creating one
  `C_Timer.NewTimer(0.2, flush)`; later fires in the window only join it (no cancel, no new
  timer). When the timer fires, the window closes and the callback runs once. A continuous
  stream of fires therefore still flushes every 0.2s.
- **Callbacks persist.** The callback runs for every window for the life of the session.
  **Each call makes a bucket of its own**, with its own window, filter and callback; the
  underlying event handler is registered only once. (It used to replace the event's callback and
  filter: the classic backpack and BetterBags Next's backpack both bucket `BAG_UPDATE_COOLDOWN`,
  and with both designs made, next.md §11, one silently took the other's place.)
- **Filter first.** The optional `filter(eventName, ...)` runs on every fire before anything
  else. Returning false drops the fire: nothing is recorded and no window opens. Use it to
  keep uninteresting fires down to a function call (e.g. only our tooltip instance ids,
  only while the bag is shown).
- **Payloads.** The callback receives `(ctx, collected)`, where `collected` is an
  `EventArg[]` of `{ eventName, args = {...} }`, one per accepted fire **that carried a
  payload**. Payload-less fires (e.g. `BAG_UPDATE_COOLDOWN`) record nothing.
- **No per-fire allocation.** The bucket's handler is registered as a `raw` callback in the
  `_eventMap` multiplexer (`events:addEventCallback`), so no Context is built per fire; one
  Context is built per callback per flush.
- **Re-entrancy.** `flush` swaps out the collected list and clears the timer **before**
  calling the callback, so a fire raised from inside the callback opens a fresh window.

## 2. Why (the bugs this replaced)

The previous implementation:

1. **Wiped its callbacks after the first flush** (`self._bucketCallbacks[event] = {}` in the
   flush). Every bucketed listener therefore ran exactly once per session: the
   `BAG_UPDATE_COOLDOWN` bag refresh and the `TOOLTIP_DATA_UPDATE` sparse-tooltip re-scan
   (tooltip-scanning.md) were both dead after the first burst after login. A spec even
   asserted the wipe.
2. **Debounced** (cancel and re-create the timer on every fire), so a stream of fires less
   than 0.2s apart never flushed, and the pending argument list grew without bound for as
   long as the stream lasted.
3. **Allocated on every fire** even though the callback was dead: a Context (4 tables), an
   argument record (2 tables), and a new timer. `TOOLTIP_DATA_UPDATE` fires for every
   tooltip in the game, so this was paid constantly, and spamming `#showtooltip` macros
   drove the rate up.

## 3. Bag cooldown refresh

`bags/backpack.lua` `RegisterEvents` wires item cooldowns (all clients; the Classic/Era
backpack overrides do not replace `RegisterEvents`):

- `BAG_UPDATE_COOLDOWN` is bucketed with the filter `bag:IsShown()`, so fires while the bag
  is closed are dropped before they open a window. Blizzard's own container frames do the
  equivalent by registering the event in `ContainerFrame_OnShow` and unregistering it in
  `OnHide` (`Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`).
- **Refresh on open.** `addon.HookScript(bag.frame, "OnShow", …)` calls `bag:OnCooldown`
  whenever the frame becomes shown. A cooldown that started while the bag was closed and
  caused no `BAG_UPDATE` (e.g. an item used from an action bar with no count change) would
  otherwise stay missing until the next redraw. The hook is on the frame's own `OnShow`, not
  `bagProto:Show`, because the bag's window (`Window:Show`, window/window.lua) shows the frame
  itself, with or without a fade, and `OnShow` fires on every show path. When a
  deferred draw also runs on show (`drawPendingOnShow`), `SetItemFromData` refreshes the
  cooldowns again; that duplicate is harmless.
- `bagProto:OnCooldown` (`frames/bag.lua`) returns early when the bag is hidden (a window
  opened just before closing can flush after it), then refreshes the active tab view's
  buttons **and** the global section buttons in `self.itemFrames` (Recent Items lives
  outside the tab view, and freshly looted consumables sit there). Buttons with
  `isFreeSlot` are skipped: a free slot has no item cooldown to show.
- Each button's refresh (`item:UpdateCooldown(ctx, data, true)`) reads the client's cooldown
  for the slot and skips Blizzard's cooldown update when it matches what the button last
  applied (caches.md §5). `BAG_UPDATE_COOLDOWN` fires on many spell casts, so in combat this
  refresh can run several times a second over every button; before, each one ran Blizzard's
  full update (spiral, icon tint, has-item) on every button. Each button's refresh returns
  why it applied Blizzard's update or that it skipped it, and `OnCooldown` returns how many
  buttons it checked and updated, so a capture's call trace shows how much each refresh did
  (data-driven.md).
- **Nothing else touches a button's cooldown** (12.1.5 source, checked for the Dream Breath
  stutter): `ContainerFrameItemButtonTemplate` has no `OnEvent` and its `OnLoad` registers
  nothing; the `ItemButton` intrinsic handles only `GET_ITEM_INFO_RECEIVED` (registered by its
  own `SetItem` path, which BetterBags does not use); `EnchantingItemButtonAnimTemplate`
  registers only `ENCHANT_SPELL_COMPLETED`, while shown; the `Cooldown` child is a plain
  `CooldownFrameTemplate`. Blizzard's update (`ContainerFrameItemButtonMixin:UpdateCooldown`)
  reads `C_Container.GetContainerItemCooldown` (its returns are not secret) and calls
  `CooldownFrame_Set`. Blizzard's own bag windows register `BAG_UPDATE_COOLDOWN` only while
  visible, and BetterBags keeps them under a hidden parent (`addon:HideBlizzardBags`).

## 4. Coverage

- `spec/events_spec.lua` ("BucketEvent"): single pending timer, callbacks kept after a
  flush, a callback per window, not starved by a continuous stream, filter drops fires
  before scheduling or recording, no Context or record for payload-less fires, underlying
  event registered once, fresh window for fires raised during a flush.
- `spec/bags/backpack_spec.lua` ("only refreshes cooldowns while shown, and refreshes them
  whenever the bag opens").
- `spec/frames/bag_draw_ownership_spec.lua` ("cooldown refresh (OnCooldown)"): Recent Items
  buttons refresh, Free Space buttons are skipped, nothing happens while hidden.

## 5. Scopes (`events:NewScope`, `events:InScope`)

A scope holds the registrations made while it is current: `events:InScope(scope, fn)` makes it
current while `fn` runs (the previous one is current again afterwards, also when `fn` errors), and
every `RegisterEvent`, `RegisterMessage`, `BucketEvent` (and what `CatchUntil` registers) records
its callback in it. `scope:Disable()` unhooks them all: each callback leaves its event's or
message's list (a new list replaces the old, so a dispatch already going over it finishes as it
started), an event or message no callback is left for is unregistered from AceEvent, and its
buckets' open windows are cancelled and forgotten. `scope:Enable()` hooks them all again,
registering with AceEvent what needs it. A callback registered while its scope is off is hooked
when the scope is switched on. BetterBags makes each bag design in a scope of its own and
switches the one not in use off (next.md §11).

Coverage: `spec/events_spec.lua` ("scopes"; "BucketEvent": one bucket per registration).
