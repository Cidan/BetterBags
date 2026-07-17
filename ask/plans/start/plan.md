# Implementation Plan: Retire Legacy Files and Promote `_new.lua` Files

## Overview
This plan outlines the steps to remove legacy rendering/data pipeline scripts and promote the `_new.lua` architecture to be the canonical files in the BetterBags addon.

## 1. Delete Legacy Files
Remove the old unused files from the repository:
- `data/items.lua`
- `data/search.lua`
- `data/stacks.lua`

## 2. Rename `_new.lua` Files
Promote the new architecture files by renaming them to their canonical names:
- `data/items_new.lua` -> `data/items.lua`
- `data/stacks_new.lua` -> `data/stacks.lua`
- `data/search_new.lua` -> `data/search.lua`
- `views/gridview_new.lua` -> `views/gridview.lua`
- `views/bagview_new.lua` -> `views/bagview.lua`

## 3. Rename Corresponding Test Files
Promote the spec tests corresponding to the renamed files:
- `spec/items_new_spec.lua` -> `spec/items_spec.lua`
- `spec/search_new_spec.lua` -> `spec/search_spec.lua`
- `spec/stacks_new_spec.lua` -> `spec/stacks_spec.lua`
- `spec/views/gridview_new_spec.lua` -> `spec/views/gridview_spec.lua`
*(Note: If legacy `_spec.lua` files exist, they should be deleted/overwritten during the move).*

## 4. Update WoW TOC Files
Update all project `.toc` files to load the new canonical `.lua` names instead of `_new.lua`:
- `BetterBags.toc`
- `BetterBags_Vanilla.toc`
- `BetterBags_TBC.toc`
- `BetterBags_Mists.toc`

## 5. Update Spec & Dependency References
Perform a global replace across the `spec/` folder to ensure all module loading refers to the correct canonical paths:
- Replace `data/items_new.lua` -> `data/items.lua`
- Replace `data/stacks_new.lua` -> `data/stacks.lua`
- Replace `data/search_new.lua` -> `data/search.lua`
- Replace `views/gridview_new.lua` -> `views/gridview.lua`
- Replace `views/bagview_new.lua` -> `views/bagview.lua`

## 6. Update Documentation and Rules
Update project rules, handoff documentation, and architectural markdown to refer to the finalized filenames:
- `.claude/rules/data-loader.md`
- `.claude/rules/item-drawing.md`
- `docs/render.md`
- `docs/handoff.md`

## Risks and Edge Cases
- Ensure any leftover references to the legacy filenames in `Luacheck` or `Busted` configurations are properly tested.
- Some legacy test files might share the target name (e.g. `items_spec.legacy`); these should be safely removed to prevent confusion.