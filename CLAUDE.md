# Claude

@.context/wow-addon-architect.md
@.context/api.md
@.context/documentation.md
@.context/patterns.md
@.context/project.md


## Evidence

Never make any changes without directly confirming that the functions, code, API's, and work you are implementing exists by directly observing it. You must either observe it as a WoW API, or as part of our addon. Never take any guesses or rely on internal memory -- always look at code and patterns in the code base and use a direct line of reference. Show your work in all your plans, and directly cite any API calls, both internal and external.

## Pattern Learning

As you work through problems and discover new abstract patterns (especially debugging techniques, API workarounds, or architectural decisions), update `.context/patterns.md` with the new pattern. This helps future contexts understand the codebase's design decisions.

## Commit Requirement

If any file changes are made, create a new git commit in the same task. Commit messages must be detailed and explain what changed and why.

## Luacheck Requirement

For any code changes, always run `luacheck .` from the repository root before finishing. Add any newly introduced WoW API globals to `.luacheckrc` as needed.

## Deps Requirements

Before starting a brand new task, make sure you always run `install-deps.sh` so that deps are installed. This will also let you look at the wow source code directly as needed.