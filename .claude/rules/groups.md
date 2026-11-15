---
paths:
  - "data/groups.lua"
  - "bags/backpack.lua"
  - "bags/bank.lua"
  - "frames/section.lua"
  - "config/catalog.lua"
  - "next/panel.lua"
  - "next/bag.lua"
  - "next/bank.lua"
  - "next/tabs.lua"
  - "next/drag.lua"
  - "spec/groups_spec.lua"
  - "spec/bags/group_delete_spec.lua"
  - "spec/bags/hide_empty_groups_spec.lua"
  - "spec/frames/section_spec.lua"
  - "spec/next/tabs_spec.lua"
  - "spec/next/bag_spec.lua"
  - "spec/next/bank_spec.lua"
  - "spec/next/drag_spec.lua"
---
# Groups (a bag's tabs of categories)

A group is a tab of the backpack or the bank that shows the categories assigned to it. A default group (the
backpack's Backpack, ID 1; the bank's Bank and Warbank, `isDefault`) shows every category of its bag not assigned
to another group. What is saved is in `core/database.lua`, per bag kind: the groups (`groups`), which group each
category is in (`categoryToGroup`, by bank type on retail's bank) and the group shown (`activeGroup`). `Groups`
(`data/groups.lua`) is the API, and sends `groups/Created`, `groups/Changed`, `groups/Deleted`,
`groups/CategoryAssigned` and `groups/CategoryRemoved`.

Which categories a tab shows is worked out when a bag is recalculated (`items:Phase10_PartitionIntoTabs`,
`data/items.lua`): every group's tab gets its items in `slotInfo.tabs[groupID]`, and a draw shows the tab the active
group names (`slotInfo.tabs[GetCurrentTabID()]`, `views/views.lua`, `next/content.lua`). A draw alone, a tab switch
among them, never moves a category to another tab: whatever moves one sends `bags/Rederive` too (a section dropped
on a tab, `frames/section.lua`, `next/drag.lua`; a group deleted, §1).

## 1. Deleting a group

The group's tab menu (right click, not on a default group) offers Delete Group, and its confirmation deletes it:
`BackpackBehavior:ShowDeleteGroupConfirm` (a `StaticPopup`) and `BankBehavior:ShowDeleteGroupConfirm` (`Question:YesNo`),
in both designs (BetterBags Next's panels open them through their `helper`, next.md §3 and §6).

- **The data.** `Groups:DeleteGroup` refuses a default group, then `DB:DeleteGroup` takes the group's categories out
  of it (they are the default group's again) and, when it was the group shown, makes the default group active:
  Backpack, or the character bank's default group (a deleted Warbank group too).
- **The message**, `groups/Deleted (ctx, groupID, groupName, kind, wasActive)`, is sent after that: `wasActive` says
  whether the group deleted was the one shown, read before the database made the default active.
- **The bags.** Each bag listens for its own kind: the classic backpack (`bags/backpack.lua`) and bank
  (`bags/bank.lua`), and Next's backpack and bank (`next/bag.lua`, `next/bank.lua`). With `wasActive` a bag switches
  to the default group, which draws it (the bank's switch also sets Blizzard's bank type, `bankTab`, the title and
  the backpack's grey-out); then it lists its tabs again, without the deleted one. The classic bags also drop the
  deleted tab's views (`frames/bag.lua` `DeleteTabView`).
- **The recalculation.** Both confirmations then send `bags/Rederive` for their bag (`{ backpack = true, bank = false,
  resetLayout = true }`, or the bank's), as a section dropped on a tab does, so the deleted group's categories are on
  the default group's tab. The switch draws at once from the last recalculation, which put them on no tab still
  there; the recalculation is queued (refresh-scheduler.md) and draws them a moment later.
- **Reported (#1265):** deleting the group shown left the bag on its items until the default tab was clicked, and
  its categories missing from the default tab until something else recalculated the bag. Every listener asked the
  database whether the deleted group was the active one, after `DB:DeleteGroup` had already made the default active,
  so none ever switched; and nothing recalculated the bag. Both were there since groups were added (80f7bdea, which
  made the database reset and the listener's check together), and Next's panels copied the check. The specs each
  stood in for the other half: `spec/groups_spec.lua`'s database did not reset the active group, and Next's
  specs kept the deleted group active when they sent the message.
- **The listeners' order on the classic bag.** The behavior's listener (`RegisterEvents`) is registered before the
  bag's own (`frames/bag.lua`, `DeleteTabView`), and messages reach listeners in the order they registered
  (`core/events.lua`): the switch draws tab 1's view, then the deleted tab's view is wiped. That view is already
  empty by then, since every draw releases the sections of the tabs it does not draw (`views/views.lua`).
- **Left as is (the change's review).** A confirmation stays open after its bag closes, and answering it then
  runs the switch away from the bank or the bag: the classic bank sets the character bank type, title and Purchase
  button as closing the bank does (`SwitchToBankAndWipe`), and the bank's recalculation is skipped away from the bank.
  Answered during Next's bank slide-out (0.24 s), the switch draws from the bank's data just cleared, so the bank
  slides out empty. Kept open while switching to Show Bags (or Bank Tabs) and then answered, Next's switch selects
  tab 1 among the bag slot tabs, and `RefreshTabs` lists them again at once with none selected. None was seen to
  show anything wrong, and each needs the player to answer a question about a bag they have left.
- Coverage: `spec/bags/group_delete_spec.lua` (the classic backpack and bank, driven through their confirmations,
  against the real `Database` and `Groups`), `spec/groups_spec.lua` ("says the deleted group was the one shown",
  "says a deleted group that was not shown was not"), `spec/next/bag_spec.lua` and `spec/next/bank_spec.lua` ("shows
  Backpack, drawn" / "shows the default bank group, drawn, when its group goes", "keeps the group it shows when
  another group goes").

## 2. The classic backpack's tabs keep the group shown

`BackpackBehavior:GenerateGroupTabs` lists the groups as tabs whenever they change (created, renamed, deleted, groups
switched on or off, the classic design switched back on) and when the backpack is made. It selects the active
group's tab, and makes Backpack active only when the active group no longer exists.

- Before, it selected Backpack and made it active every time: renaming the group shown, or deleting another one,
  moved the highlight and the active group to Backpack while the bag went on showing the group's items, and the
  next draw showed Backpack's. It was there since groups were added (b575ecd4 moved it to the end of the function, for
  the highlight).
- So the classic backpack now opens on the group it showed last, as the classic bank (`OnShow`) and BetterBags Next
  (`RefreshTabs`) already did. Its `OnCreate` (and the Classic and Era ones) already selected the active group's tab
  after listing them.
- Coverage: `spec/bags/group_delete_spec.lua` ("keeps the group it shows when another group is deleted", "keeps the
  group it shows when a group is renamed", "shows Backpack when the group it last showed is gone", "shows the
  group it showed last when it is made").

## 3. Hide Empty Groups (#1321)

Asked (#1321): "layout groups will be shown at all times even with no items in the inventory actually matching what
should be displayed in the layout. This wastes a lot of space ... There should be an option in the settings to allow
for hiding of empty layout groups." Agreed with the user: every group's tab shows while a section is dragged ("agree
with showing all sections when dragging a section, animate it"); the backpack and the bank, in both designs; a group
whose items are all in categories the bag hides counts as empty ("count hidden groups as empty").

- **The setting** (`hideEmptyGroups`, `config/catalog.lua`): each bag's Layout tab, Tabs section, the backpack's and
  the bank's alone (`only`), off by default (`hideEmptyGroups[kind]`, `DB:Get/SetHideEmptyGroups`; off once the
  logout's strip took the table). The bank's Layout tab gained a Tabs section for it (Enable Groups is the backpack's).
  Setting it sends `groups/HideEmptyChanged (ctx, kind, value)` and recalculates nothing: the bag lists its tabs again.
- **What is empty** (`Groups:HiddenGroups(kind, tabs, shownID)`): with the setting on, every group but the bag's
  default ones (`IsDefaultGroup`: Backpack; Bank and Warbank) and the one shown whose tab in the bag's data
  (`slotInfo.tabs`, `items:Phase10_PartitionIntoTabs`) counts no item (`totalItems`, which leaves out free slots, gaps
  and what a category hides in the bag), or that has no tab there (made since). None before the bag's data was first
  worked out (`tabs` nil). Recent Items are no group's (`ItemBelongsToTab`), so a group whose only items are recent
  shows once they stop being recent. `Groups:SameGroups(a, b)` compares two sets.
- **A group just given a category keeps its tab until the bag is worked out again.** `AssignCategoryToGroup` records
  the bag's data then (`assignedSince[kind][groupID] = slotInfo.tabs`, from `items:GetAllSlotInfo()`, a new table at
  every recalculation), and `HiddenGroups` keeps the group while it is asked with that same data. So a section dropped
  on an empty group's tab, shown by the drag, leaves that tab where it is as the drag ends (it pulses), and the
  recalculation the drop sends brings its items; a drop whose items never came hides it at the next one.
- **What each bag reads**: the last data drawn that was split by group and had tabs (`groupTabs`, recorded only while
  `ListsGroups`). The Show Bags view's data counts every item in every tab and Bank Tabs mode's is keyed by Blizzard's
  bank tabs (`ItemBelongsToTab`, `GetPossibleTabIDs`), so leaving those goes by the data from before them until the
  recalculation. The bank's data has none from its close until it is read as it opens (`items:ClearBankCache`), so it
  goes by the last visit's until then rather than showing every group and hiding some a moment later. Before any (the
  first draw, groups just turned on) nothing is left out, and the recalculation's draw then leaves out the empty ones.
- **BetterBags Next** (`next/panel.lua`, `next/bag.lua`, `next/bank.lua`): a panel whose rail lists groups from data
  split by group (`ListsGroups`: groups on, and neither Show Blizzard Bags nor, for the bank, the Bank Tabs setting,
  which on Classic, with no Bank Tabs mode, still splits its data by bag) lists those not left out (`ShownTabs`,
  recording the set left out, `tabsHidden`, and every tab listed, `tabsListed`). Every draw follows (`FollowGroups`, in
  `Draw` before the layout): the tabs are listed again only when the set left out changed (a group emptied or filled,
  the group shown changed), gliding unless the panel is drawing as it opens. The group shown never goes: an empty group
  switched away from goes then. The bank gives its gap to the first Warbank group shown. `groups/HideEmptyChanged`
  follows the same way.
- **A tab being moved** (next.md §3) is never put back by a draw: `FollowGroups` holds off while the rail moves a tab
  (`SetTabs` cancels a move), and the rail's land handler (`NextTabs:SetLandHandler`: every landing, after the reorder
  handler when it moved, and a move put back as the rail hides) follows once it ends.
- **The drag** (`next/drag.lua`): `NextDrag:Begin` shows every registered panel's groups once it has picked the section
  up (`panelProto:RevealGroups(true)`: `HiddenGroups` none), and `finish`, which every end of a drag goes through
  (landing, flying away, docking, cancelling), leaves the empty ones out again. The rail growing as it reveals is a
  change of tabs as any other: an autosized small panel follows the rail's height, and a chained bag the rail's width
  (next.md §12).
- **The rail's animation** (`NextTabs:SetTabs(entries, animate)`, `next/tabs.lua`): an entry takes its id's tab first, so
  a group keeps its tab (and a drag's target tab stays the same tab); unanimated, an entry without one takes the next
  spare tab as before. Animated, on a rail that shows (`IsVisible`): tabs that stay slide to their places (`slideY`,
  `Time.Interaction`, the `Glide` ease), a tab coming in is a pooled one, placed at once and fading in (`fade`), and a
  tab going out fades out where it is with its mouse off (`fadeOut`), kept in `leaving` and not among `tabs` (no drop
  target, no width, no click), then goes back to the pool (`release` gives it its alpha and mouse back). A tab going out
  that is listed again comes back from where its fade is; listed again unanimated, the tabs going out go at once. The bar
  glides to where the selected tab is going (`Select` aims at `yTarget`).
- **Saving the order** (`panelProto:OnTabsReordered`, `withLeftOut`): a move among the tabs shown is saved with the
  groups left out in their places (each place a tab shown held takes the next id of the new order), so a group left
  out comes back where it was.
- **The classic bags** (`bags/backpack.lua`, `bags/bank.lua`): `GenerateGroupTabs` hides the groups left out
  (`HiddenGroups`, the group shown being the active one), while the data is split by group (`ListsGroups`: groups on,
  not the Show Bags view, and for the bank not Blizzard's bank tabs). Each behavior follows its bag's draws
  (`bag/Rendered`, sent by `frames/bag.lua`'s `Draw`: the data's tabs, then `FollowGroups`) and
  `groups/HideEmptyChanged`. With groups off it records nothing left out (`tabsHidden` nil), so the next draw lists them.
  The backpack lists its tabs while its Show Bags slots panel shows too, its bar kept hidden: turning Show Bags off
  recalculates while the panel fades out (0.1 s, still shown), and `BagSlots:OnClose` shows the bar after. The bank keeps
  its bar hidden while Blizzard's bank tabs panel fades out (`Window:IsClosing`) for the same reason, and by the fade
  rather than by its being shown, which a panel the bank's Escape left shown still is. A section dragged by its title
  (`frames/section.lua`) shows both bags' groups (`SectionFrame:RevealGroupTabs` → `behavior:RevealGroups(ctx, on)`)
  until it is dropped, the drop's assignment first. The classic tab bar has no motion: its tabs show and hide at once.
- **A new group**: both designs' create dialogs make the new group the one shown, so it shows until the player switches
  away; empty, it then hides until something is in it or a section is dragged.
- **Found by the bug reviews** (four rounds, each fixed test-first): the classic backpack recorded groups left out on its
  Show Bags early return without hiding them, so a group that filled meanwhile kept its tab hidden; both designs read data
  split by bag after leaving Show Bags or Bank Tabs (tabs listed wrong for a frame, then gliding); a draw cancelled a tab
  being moved, and a move that landed back in place, or was put back as the rail hid, never caught up; the classic
  backpack's and the retail bank's draws as their slots panels fade out (turning them off) left the backpack's tabs
  stale and showed the bank's bar under the fading panel.
- **Left as is** (reviewed, not built for):
  - A tab moved to a new place is listed again without gliding (`OnTabsReordered`), so a change of the groups left out
    held off during the move shows at once there.
  - A tab going out counts in neither the rail's width nor its height, so an autosized panel shrinks and a chained bag
    moves at once while the tab fades where it was.
  - Whether the client sends `OnLeave` to a hovered tab whose mouse is turned off as it fades out is not known; a tab is
    not hovered during a section drag (the drag's cover is under the cursor).
  - The classic horizontal tab bar can be wider than its window while every tab shows during a drag (the bank widens its
    frame; the backpack waits for its next render). Not seen in game.
  - A draw of the old mode's data between a mode toggle and the recalculation it asks for (a tab clicked then) is read
    for that one draw.
  - The classic bank's view check (`ListsGroups`) mirrors `data/items.lua`; no client reaches that view with Blizzard's
    bank tabs off there.
- Outside the change (noted by the reviews): Next's bank on Classic with the Bank Tabs setting left on shows tab -1
  (`GetCurrentTabID`); turning groups off during the classic Show Bags shows the bar once its panel closes
  (`frames/bagslots.lua`); Show Bags pressed during its fade-out takes the off branch again; Escape leaves the classic
  bank's slots panel shown (`frames/bag.lua` `Hide` returns early).
- Coverage: `spec/groups_spec.lua` ("HiddenGroups"), `spec/database_spec.lua` ("hides its empty groups' tabs", the
  logout's strip), `spec/config/catalog_spec.lua` ("hides a bag's empty group tabs"), `spec/next/settings/content_spec.lua`
  (the bank's Layout), `spec/next/tabs_spec.lua` ("listing tabs again"), `spec/next/bag_spec.lua` ("leaving out empty
  groups": the data split by group, a tab moved, landed in place or put back as the rail hides),
  `spec/next/bank_spec.lua` (the Warbank's gap, the order saved, the drag, the last read's data, leaving Bank Tabs,
  Classic's setting left on, Blizzard's tabs), `spec/next/drag_spec.lua` ("the tabs of empty groups"),
  `spec/bags/hide_empty_groups_spec.lua` (the classic backpack and bank against the real Database, Groups and tab bar:
  Show Bags and its fade, Blizzard's bank tabs and their fade, data with no tabs), `spec/frames/section_spec.lua` ("shows
  every group's tab of both bags while a section is dragged by its title"). Specs that stub Groups install
  `UseHiddenGroups` (`spec/helpers/addon_loader.lua`), which leaves out what the spec names, never the group shown.
