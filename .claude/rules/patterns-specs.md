---
paths:
  - "spec/**/*_spec.lua"
  - "spec/helpers/*.lua"
  - "spec/setup.lua"
---
## Spec Files Must Pass Alone and Shuffled
The suite runs every spec file in one Lua state, so a file can pass only because an earlier one left something behind: a stub module with the methods it needs, a real module the earlier file loaded, or a copy of a module loaded with the earlier file's stubs captured in its file-scope locals (`LoadBetterBagsModule` loads a path once per state). Check a new or changed spec file with `~/.local/lua51/bin/busted <file>` and `busted --shuffle --seed=N <file>`, not only in the suite's order. The rules that keep a file independent:
- Create stubs with `StubBetterBagsModule` and remove the ones the file created (the `created` flag) when it ends; never `x.Method = x.Method or default` on a module another file may have loaded for real (its method then runs against data this file never set up): replace it and put the original back.
- Load the module under test fresh (`LoadFreshBetterBagsModule`) when it captures other modules at file scope, and remove it after (`spec/frames/item_spec.lua`).
- Put file-wide restores in a file-level `teardown`, not in one `describe` block's: `--shuffle` reorders blocks, so that block's teardown can run first and undo the stubs every other block needs.
- Revert a `stub(obj, "Method")` with `finally(function() obj.Method:revert() end)`; it otherwise stays for the rest of the file.
- Reset shared engines before re-registering into them: the specs call `Sonata:Init()` before loading the theme files, as the addon's own load order does (`.claude/rules/sonata.md` §2: a theme registering after one was applied reads the saved theme).
- A test that only checks scheduling should stub the scheduled work rather than run it, so it does not depend on what that work touches.
Measured state and the remaining known failures: `docs/roadmap.md`, "Spec isolation".

## A Spec That Replaces a Shared Module's Method Must Put It Back
**Problem**: `StubBetterBagsModule` returns the real module when one is loaded. A spec block that set
`events.RegisterEvent` to a capture and never restored it left every later spec's event registrations going
nowhere: `spec/targeted_sweep_spec.lua` and `spec/window/window_spec.lua` failed only in the full run.

**Rule**: Save what a spec replaces (`rawget`) and restore it in `after_each`, or use the spec's `override`
helper where it has one. When a spec passes alone and fails in the full run, look for a method replaced on a
shared module by an earlier file.

## Never spy.on a Panel's or Frame's Method
**Problem**: luassert's `spy.on` deep-copies every call's arguments to record them, and a method's first argument
is its object. A spy on a BetterBags Next panel's method copied the panel and the whole mocked UI behind it on each
call, over 100 MB a call: two such tests took `spec/next/small_spec.lua` from 278 MB to 1.2 GB, and the suite past
CI's 4 GB limit (`ulimit -v 4000000` in `.github/workflows/test.yml`; it died with "not enough memory"). The suite
already peaked at 3.58 GB before them, so little headroom is left.

**Rule**: Count or record the calls you need with a wrapper put in through the spec's `override` (it is put back
after the test): `countCalls` in `spec/next/small_spec.lua`. Keep `spy.on` for methods whose arguments are small
values. To find a test that holds memory, measure `collectgarbage("count")` around each test from a helper that
subscribes to busted's `{"test", "start"}` and `{"test", "end"}`.
