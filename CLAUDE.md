# Claude

@.context/api.md
@.context/documentation.md
@.context/patterns.md
@.context/patterns-taint.md
@.context/patterns-ui.md
@.context/patterns-state.md
@.context/project.md


## PRIME DIRECTIVE #1: Test-First TDD

Always write TESTS FIRST to validate the bug or feature before writing any implementation/fix.
1. Write a failing test that reproduces the bug or simulates the new feature.
2. Run tests to observe and confirm the failure.
3. Write/modify the implementation code.
4. Run tests to confirm they are now passing.
No implementation code should be modified or added without a corresponding test written and observed failing first.


## Evidence

Never make any changes without directly confirming that the functions, code, API's, and work you are implementing exists by directly observing it. You must either observe it as a WoW API, or as part of our addon. Never take any guesses or rely on internal memory -- always look at code and patterns in the code base and use a direct line of reference. Show your work in all your plans, and directly cite any API calls, both internal and external.

## Mocking and WoW API Mocks

To ensure the reliability of the addon and prevent regressions, adhere to the following strict mocking and testing rules:

- **Test changes with mocks**: Whenever you make or introduce code changes, they must be validated and tested via mocks. Ensure that mocks exist for any functionality affected.
- **Create missing WoW API mocks from source**: If mocks are missing for any World of Warcraft APIs, you must create them. Retrieve the precise behavior, return values, and parameters by reading Blizzard's official WoW UI source code (available under `.libraries/wow-ui-source`). Do not guess or invent API interfaces.
- **Code must fit the mock (not vice versa)**: Mocks represent the contract of the World of Warcraft runtime environment. Never modify a mock to fit a shortcut or bug in our implementation code. The implementation code must always be corrected to fit the (accurate) mock contract. Never assume implementation code is correct over a verified mock of Blizzard's API.

## Pattern Learning

As you work through problems and discover new abstract patterns (especially debugging techniques, API workarounds, or architectural decisions), update the appropriate pattern file in `.context/`:
- Taint/protected code → `patterns-taint.md`
- UI patterns → `patterns-ui.md`
- State/architecture → `patterns-state.md`

This helps future contexts understand the codebase's design decisions.

## Commit Requirement

If any file changes are made, create a new git commit in the same task. Commit messages must be detailed and explain what changed and why.

## Luacheck Requirement

For any code changes, always run `luacheck .` from the repository root before finishing. Add any newly introduced WoW API globals to `.luacheckrc` as needed.

## Lua Version

The project targets **Lua 5.1 only**. Not 5.2, not 5.3, not 5.4, not LuaJIT-in-5.2-mode. WoW's runtime is Lua 5.1; the addon's code, its libraries, its tests, and its linter all run on 5.1 and only on 5.1. There is no 5.4 support, there will never be 5.4 support, and any code or test that "happens to work" on 5.4 is not validated by anything in this repository.

This is enforced in three places, redundantly, on purpose:

- **CI pins Lua 5.1** — `.github/workflows/test.yml:32` and `.github/workflows/luacheck.yml:19` both install `leafo/gh-actions-lua@v10` with `luaVersion: "5.1"`, then install `busted` / `luacheck` against that interpreter. A PR that breaks 5.1 will fail CI even if it passes locally on a different runtime.
- **Luacheck is locked to the 5.1 standard** — `.luacheckrc:1` sets `std = "lua51"`, so any 5.2+/5.3+/5.4-only construct (goto, `<close>`, integer division, `//`, etc.) is a lint error.
- **The test suite runtime-asserts 5.1** — `spec/setup.lua:1-12` errors out before any test code runs if `_VERSION ~= "Lua 5.1"`. Running `busted` against any other interpreter fails immediately with a message naming the detected version and pointing at this section.

Practical consequences:

- Do not use any 5.2+ language feature or standard library function. If you are tempted to reach for one, stop and find the 5.1 equivalent. Luacheck will catch it; the test guard will catch it; CI will catch it.
- The `lua` / `busted` binaries on `$PATH` must be 5.1 (or a 5.1-compatible LuaJIT 2.x, whose `_VERSION` is `"Lua 5.1"`). If `lua -v` reports anything other than `Lua 5.1.x`, fix that before running the suite — do not "just try it" on the wrong runtime and trust a green result. `install-deps.sh` does not install a Lua interpreter; you must provide 5.1 yourself.
- When debugging a test failure, never conclude "this works on 5.4" as a workaround. 5.4 is irrelevant. Fix the 5.1 behavior.

## Deps Requirements

Before starting a brand new task, make sure you always run `install-deps.sh` so that deps are installed. This will also let you look at the wow source code directly as needed.