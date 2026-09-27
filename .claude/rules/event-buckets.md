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
  Calling `BucketEvent` again for the same event **replaces** its callback and filter; the
  underlying event handler is registered only once.
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
  `bagProto:Show`, because with fading enabled the frame is shown from the fade-in
  animation's `OnPlay` (`animations/fade.lua`); `OnShow` fires on every show path. When a
  deferred draw also runs on show (`drawPendingOnShow`), `SetItemFromData` refreshes the
  cooldowns again; that duplicate is harmless.
- `bagProto:OnCooldown` (`frames/bag.lua`) returns early when the bag is hidden (a window
  opened just before closing can flush after it), then refreshes the active tab view's
  buttons **and** the global section buttons in `self.itemFrames` (Recent Items lives
  outside the tab view, and freshly looted consumables sit there). Buttons with
  `isFreeSlot` are skipped: `SetFreeSlots` does not reset `currentData`, so a button reused
  as a free slot still carries the data of the item it last drew.

## 4. Coverage

- `spec/events_spec.lua` ("BucketEvent"): single pending timer, callbacks kept after a
  flush, a callback per window, not starved by a continuous stream, filter drops fires
  before scheduling or recording, no Context or record for payload-less fires, underlying
  event registered once, fresh window for fires raised during a flush.
- `spec/bags/backpack_spec.lua` ("only refreshes cooldowns while shown, and refreshes them
  whenever the bag opens").
- `spec/frames/bag_draw_ownership_spec.lua` ("cooldown refresh (OnCooldown)"): Recent Items
  buttons refresh, Free Space buttons are skipped, nothing happens while hidden.
