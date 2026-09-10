## Summary
Adds dedicated unit tests and documentation to verify Phase 7 (Section Layout) of our rendering pipeline refactor.

## Motivation
This phase validates that our existing section layout engine natively supports the new stateless, unidirectional data pipeline. Because Phase 5 and Phase 6 decoupled item buttons and mapped them accurately to sections, we do not need to rewrite the section placement logic. This PR adds safety checks via tests to ensure our layout calculations remain stable under the new data model.

## Validation
- Verified `frames/section.lua` and `frames/grid.lua` seamlessly integrate with our new clean-sweep placement engine without any legacy delta dependencies.
- Added comprehensive unit tests in `spec/frames/section_spec.lua` to assert section layout sizing, collapse wrapping, and height logic.
- Passed 765 unit tests in Lua 5.1 with 0 errors.
- Passed `luacheck` with 0 warnings.