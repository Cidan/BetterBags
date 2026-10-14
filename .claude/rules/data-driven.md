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
- **New-item flags and Recent Items timers** (recent-items.md §1): `items:ClientNewItemFlag(bag,
  slot)` returns what the client reports for a slot, and `items:SeedNewItemTimer(kind, item)`
  returns what it did: `"started"`, `"running"` (the GUID already has a timer), `"not new"` (the
  client does not flag the item) or `"no guid"`. Both were local functions. Added when a vendor
  purchase onto a partial stack did not enter Recent Items and no capture could show whether the
  client flagged the slot.
