---
paths:
  - "data/groups.lua"
  - "bags/backpack.lua"
  - "bags/bank.lua"
  - "spec/groups_spec.lua"
  - "spec/bags/group_delete_spec.lua"
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
