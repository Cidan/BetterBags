---
paths:
  - "integrations/quickfind.lua"
  - "spec/quickfind_spec.lua"
---
# The QuickFind integration (`integrations/quickfind.lua`, `QuickFind`)

QuickFind (sragia/quickfind) is a launcher: the player types, it suggests spells, toys, mounts and whatever other addons
register, and Enter runs the one picked. BetterBags registers the items in the backpack and the bank as a source, each
tagged with its type, subtype, category, equipment slot and location ("Backpack", "Bank"); Enter on one opens the bag it
is in, switches to the tab that holds it, and searches for its name in the in-bag search box (which must be on).

## 1. QuickFind's API, as its source has it

- `QuickFind.RegisterSource(self, { name, get, iconPath? })` (`QuickFind/API.lua`) keeps the source by name. There is no
  way to take one back: no unregister, no per-source switch (QuickFind's own enable switches cover its built-in presets,
  `QF.enabledPresets`, never an outside source).
- `QF.getAllSuggestions` (`QuickFind/core.lua`) calls every source's `get` (under `pcall`) each time it builds its list;
  the finder keeps that list while it is open (`Finder/suggestions.lua`).
- An entry of type `QuickFind.LOOKUP_TYPE.LUA` runs its `lua(id)` when picked.

## 2. Enable QuickFind Integration (#1262)

Asked (from Discord): "Allow users to toggle off integration with the QuickFind addon", the switch "in it's integration
entry": the `quickFind` setting (`config/catalog.lua`, saved as `quickFindEnabled`, on by default) is the first row of the
QuickFind page under Integrations (next-settings.md §4). It takes effect at once, without a reload:

- `OnEnable` registers the source whenever QuickFind is loaded, the switch on or off: a source registered only while on
  could never be added once turned on without a reload, and one registered could never be taken back.
- `GetItemResults` (what the source's `get` returns) is empty while the switch is off, so QuickFind lists none of the
  player's items from the next time it builds its list.
- The login message ("BetterBags: QuickFind integration enabled.") is printed only while it is on.

Coverage: `spec/quickfind_spec.lua` ("QuickFind integration switch": registered while off too, the items while on and
none while off, the message only while on; and the bank tab routing), `spec/config/catalog_spec.lua`,
`spec/next/settings/content_spec.lua` ("QuickFind"), `spec/core/constants_spec.lua`, `spec/database_spec.lua`. Not seen
in game.
