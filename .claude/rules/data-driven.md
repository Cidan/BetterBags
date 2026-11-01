# Data-Driven Changes (Hard Requirement)

Every change to BetterBags, and every performance or behavior fix above all, must be backed by
captured data: a profiler session, its call trace, or a `/bbdb` dump. Reading the code and
reasoning about it can suggest a cause; it does not establish one.

- **Show the fact in data before acting on it.** Before changing code, point at the capture
  that shows the problem and its cause: the calls, their arguments and return values, the
  costs, the counts.
- **If the data cannot show it, extend the tooling first.** When the existing profiler, trace
  or debug window cannot show the fact a change depends on, the first change is to the tooling
  (a recorded return value, a new span, a new dump field), followed by a capture. Only then the
  fix.
- **Verify with a second capture.** After a fix, a capture of the same actions shows the
  effect; numbers are compared with overhead subtracted (perf-profiler.md §3).
- **Say which parts are measured and which are inferred.** In reports, separate what a capture
  shows from what was concluded from code.

## Diagnostics this requirement added

- **Why a button redrew** (item-drawing.md §7b): `Item.DrawInputChanged` and
  `Item.FreeDrawInputChanged` return the name of the first draw input that differs from the
  button's record, or nil when the redraw is skipped. Both are methods of the `Item`
  prototype, so the call trace records their return value for every draw. Added when Show Bags
  showed every item button redrawing in full and the cause could only be inferred from code.
- **Bank type and item context calls** (perf-profiler.md §2): `BankPanel:SetBankType` and
  `ItemButtonUtil.TriggerEvent(ItemContextChanged)` go through `addon.SetBlizzardBankType` and
  `addon.TriggerItemContextChanged`, measured as `BetterBags.*`. Added when every bank tab
  switch showed 12.6-15 ms of unmeasured time inside `Bank.SwitchToGroup`, the same with zero
  or 529 buttons reacting to the context change, which only one of these two calls could
  explain.
- **The cooldown refresh** (event-buckets.md §3): `Item.UpdateCooldown` returns what it did:
  `"unchanged"` when it skipped Blizzard's update, else the first input that changed
  (`"start"`, `"duration"`, `"enable"`, `"icon"`, `"slot"`, `"decoration"`, `"generation"`,
  `"first"`, `"full"` for a full draw, `"row"`, `"no read"`), or `"empty"`/`"no bag"`.
  `Bag.OnCooldown` returns how many buttons it checked and how many it applied Blizzard's
  update to. Added for the Dream Breath stutter in raids and Mythic+, to show in a capture with
  the bags open how much each refresh does.
- **Circumstances and whole-client time** (perf-profiler.md §3, §10a): captures record the
  addon restrictions and the instance at their start and end, every restriction change, and
  Blizzard's per-frame time for all addons and the whole client. Added when captures of that
  stutter showed slow frames with BetterBags idle, and could say neither where the player was
  nor where the time went.
- **New-item flags and Recent Items timers** (recent-items.md §1): `items:ClientNewItemFlag(bag,
  slot)` returns what the client reports for a slot, and `items:SeedNewItemTimer(kind, item)`
  returns what it did: `"started"`, `"running"` (the GUID already has a timer), `"not new"` (the
  client does not flag the item) or `"no guid"`. Both were local functions. Added when a vendor
  purchase onto a partial stack did not enter Recent Items and no capture could show whether the
  client flagged the slot.
- **Window geometry and the render recorder** (window.md 3a, render-recorder.md):
  `windowProto:Geometry(step)` returns a window's anchors, rect, scale, clamp and the cursor, and
  is called at every step of a resize or a move while a profiler capture runs; the render recorder
  (Performance tab, **Record Rendering**) keeps a snapshot of a window down to its item buttons
  after each render that changed it, and every resize and move step. Added for a bank window that
  grew past the screen when its resize grip was clicked, which no capture could explain: the
  profiler shows neither where the window was anchored nor where each section and button went.
- **When a bank open stopped waiting for its window** (refresh-scheduler.md §11):
  `Refresh._BankShown(open, reason)` records why the wait ended ("finished", "timeout", "no window")
  and returns what it did ("loading", "already", "ended"), so a capture of a bank open shows whether
  the bank loaded after the show animation or on the timeout. Added with the change that loads the
  bank once its window has shown, so the capture asked for before and after can show it.
- **Leaving the world** (perf-profiler.md §10d): captures record leaving the world, the loading
  screen, windows closing and each bag event, each with what the bags hold then (slots, items by ID,
  items that exist at their location). Added for a `GetItemGUID` error on entering a dungeon, which
  no capture could explain: none showed when a world transfer takes the items away and gives them
  back (refresh-scheduler.md §8).
- **What the client did around a stall** (perf-profiler.md §3a, refresh-scheduler.md §6): `Refresh._CallSorter` measures each sort
  call by name; a capture records events the client fired that BetterBags does not listen to (`[client] UNIT_MODEL_CHANGED` and
  others), with the character pane showing, and names what each addon took in each tick of 33 ms or more. Added for a game-wide
  hitch sorting with the character pane open: a capture showed 56 ms inside `SortBags` and 58 ms in a tick no addon took, and could
  say neither what the client was doing nor whether the pane mattered.
- **What the client answered about an item** (`debug/itemprobe.lua`, `ItemProbe`): the Dump tab of
  `/bbdb` stores, beside each dumped backpack item (`apiProbe`), every value each Blizzard API
  returned about it: `GetItemInfo` by item ID and by link (`n` is how many values, so "returned
  nothing" and "returned nil" differ), `GetItemInfoInstant`, item levels (`GetDetailedItemLevelInfo`
  by ID and by link, `GetCurrentItemLevel`), whether its data was loaded (`IsItemDataCached`,
  `IsItemDataCachedByID`), `IsEquippableItem`, `GetItemSpell`, `IsCosmeticItem`,
  `GetItemUpgradeInfo`, `CanScrapItem`, `GetItemStats`, both crafting tiers, the pet journal (and
  the species' collected count), the toy box (`C_ToyBox.GetToyInfo`, `PlayerHasToy`),
  `C_PlayerInfo.CanUseItem`, the upgrade watermark, the appearance and whether it is collected, the
  bag's name, and the tooltip's lines with their types (`C_TooltipInfo.GetBagItem`). Each call is
  protected (an error is recorded, not raised), a value the addon may not access is recorded as
  `<secret type>` and never read, and an API the client lacks is left out. The dump records the
  client it came from (`debugBackpackDumpClient`: version, build, interface, locale). For an item
  with an appearance it also records every way Vendor asks whether it is collected
  (`GetSourceInfo`, `PlayerCanCollectSource`, `GetAppearanceSources`, `PlayerHasTransmogByItemInfo`).
  The dump also stores `debugDumpExtras`: `player` (`ItemProbe:Player()`: level, effective level,
  average item levels, minimum item level, class, who the player is, specialization and its info,
  professions and each one's info, dual wield, all raw), `equipped` (`ProbeEquipment()`: each worn
  item probed as a bag item is, by equipment slot, with its tooltip from
  `C_TooltipInfo.GetInventoryItem`), `bagNames` (`BagNames()`: every `Enum.BagIndex` container's name,
  slots and free slots), and `bank` (the open bank's items, probed) when dumped at a bank. Added to
  settle the open questions of docs/vendor-compat.md ("Needs an in-game check": the link against the
  item ID, toys, bags as equipment, cold reads) from one capture. Coverage:
  `spec/debug/itemprobe_spec.lua`, `spec/frames/debug_window_spec.lua` ("dumps each backpack item
  with what the client's APIs answered about it"); 11 mutations, all caught.
