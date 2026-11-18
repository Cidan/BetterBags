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
none while off, the message only while on), `spec/config/catalog_spec.lua`, `spec/next/settings/content_spec.lua`
("QuickFind"), `spec/core/constants_spec.lua`, `spec/database_spec.lua`. Not seen in game.

## 3. Showing an item (`ShowInBag`, `GetTabIDForItem`; #1343, #1344)

Enter on an entry opens its bag (`bag:Show`), switches to the tab holding the item the way a click on that tab does
(the behavior methods, never the tab bar's visual-only `SetTabByID`: patterns-state.md), then fills the in-bag search box.

**The tab** (`GetTabIDForItem`), worked out as the bag's data is split into tabs (`data/items.lua`, `ItemBelongsToTab`):

| Bag, mode | Tab | Called |
|---|---|---|
| Backpack, groups on | the group its category is assigned to, else Backpack (1) | `behavior:SwitchToGroup` |
| Bank, retail and Forever with `showBankTabs` (Next: Show Bank Tabs; classic: Show Bags) | its bag ID: each Blizzard tab is one bag | classic: `bag.slots:SelectTab` (the tab slots panel marks the tab, then calls `behavior:SwitchToBlizzardTab`); Next: `behavior:SwitchToBlizzardTab` (its rail follows) |
| Bank, groups on, `showBankTabs` off | the group its category is assigned to for its bank type (retail: Warbank for a bag in `const.ACCOUNT_BANK_BAGS`, else character; elsewhere none), else that bank type's default group (`Groups:GetDefaultBankGroup(bankType)`) | `behavior:SwitchToGroup`, only on a bank with a tab bar (`bag.tabs`) |
| Bank, groups off, or `showBankTabs` left on off retail | none | nothing |

- **Bank types apart.** On retail a category is assigned to a bank group per bank type (`DB:SetCategoryGroup`), so a
  Warbank item of a category assigned only in the character bank is in the Warbank's default group.
- **No tabs on the classic Classic bank.** `bags/classic/bank.lua` and `bags/era/bank.lua` keep `bags/bank.lua`'s
  `SwitchToGroup`, which calls `bag.tabs:SetTabByID`, but create no tab bar: QuickFind switches nothing there. BetterBags
  Next's bank lists its groups on every client (`next/bank.lua`, `RefreshTabs`).
- **Off retail, Show Bank Tabs left on** splits the bank's data by bag and shows one tab of every bank bag
  (`data/items.lua`; BetterBags Next keeps listing groups): there is nothing to switch to.
- The bank's groups have no setting to turn them off (Enable Groups is the backpack's, `config/catalog.lua`); the
  database value is still read, as the bank's data split reads it.
- What went wrong before: QuickFind called `SwitchToBank`, `SwitchToCharacterBankTab` and `SwitchToAccountBank`, which
  no bank defines, and returned an item's bag ID as its tab in group mode; the spec's bank mock had the same made-up
  methods, so it passed. The specs now drive the real banks: `bags/bank.lua`'s behavior in `spec/quickfind_spec.lua` and
  the real BetterBags Next bank in `spec/next/bank_spec.lua`.

**The search** (`NameQuery`): `name == "<item name>"`, the name's own `"` escaped as `\"` (util/query.lua's quoted
text). `==` is the whole name without case (`search:isExactly`): every stack of that name, never an item whose name or
tooltip only holds it. The name was set unquoted before, and the query language read its words as terms and operators:
"Ruby Ring" searched for Ruby, "Salt and Pepper Shank" for Salt AND Pepper, and "Rings Not Included" did not parse
(`binary`: "Unexpected NOT after a term"), so nothing matched.

**Bank items only while the bank is open** (#1345, kept by design). `GetItemResults` lists the bank items BetterBags
read (`items:GetAllSlotInfo()`), and closing the bank clears them (`addon.CloseBank` → `SwitchToBankAndWipe` →
`items:ClearBankCache`). The client lets an addon read the bank's containers only at the bank, and no bank window opens
away from one, so a bank item kept after closing would be an entry Enter can do nothing with; the Help article says
bank items show only while the bank is open (`help/articles/integrations.lua`, "Registered Items"). An entry picked from
a list QuickFind built while the bank was open, after it closed, finds no item data (`items:GetItemDataFromSlotKey`)
and does nothing.

**What the bug review found** (no proven bug; the tab chosen was run against the real `Phase10_PartitionIntoTabs` on
every client and mode, and all 8 mutants of the new code were caught). Left as they are, none seen in play:
- An item whose data has not loaded has the name `""`: `name == ""` matches nothing, so every item dims (the old code
  left the box empty). QuickFind would have to list and match a nameless entry by its tags first.
- A name `tonumber` or `StringToBoolean` reads (`Inf`, `1`, `True`) matches nothing with `==`: `search:isExactly` looks
  such a value up as a number or a boolean, and the name index has neither. No WoW item has such a name.
- A name ending in a backslash leaves its quoted text unclosed (`\"` reads as an escaped quote). No WoW item name holds
  a backslash.
- A new item's category is Recent Items (its shown category, `data/items.lua`), so QuickFind goes to the default group:
  the Recent Items section is drawn on every tab, so the item is on screen there.

Coverage: `spec/quickfind_spec.lua` ("QuickFind showing a bank item": groups by bank type and assignment, default groups,
retail, Forever and Classic, no tabs, groups off, Show Bank Tabs left on off retail, Blizzard tabs in both designs;
"QuickFind with the classic retail bank's behavior": the real `bags/bank.lua` behavior and tab slots panel's `SelectTab`,
the bank type set; "QuickFind's search for the item
picked": the real `QueryParser` and `Search`), `spec/next/bank_spec.lua` ("an item picked in QuickFind": the real
BetterBags Next bank), `spec/groups_spec.lua` ("GetDefaultBankGroup": by bank type). Not seen in game.
