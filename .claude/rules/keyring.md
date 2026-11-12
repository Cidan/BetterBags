---
paths:
  - "data/items.lua"
  - "util/sort.lua"
  - "core/era/constants.lua"
  - "spec/sort_spec.lua"
  - "spec/refresh_pipeline_spec.lua"
---
# The Keyring

Classic Era and WoW: Forever have a keyring, read with the backpack: `Enum.BagIndex.Keyring` (-2 on Classic Era, -1 on
Forever) is in `const.BACKPACK_BAGS` (`core/era/constants.lua`; on Forever `core/constants.lua` while
`C_ActionBar.ShouldShowKeyring()`, camelot-forever.md §7). It has no bag slot button, its slots are not free space
(`IncludeBagInFreeSpace`), and Show Bags names it "Keyring", numbered after the last bag (`items:GetBagName`: "#6" on
Classic Era, "#7" on Forever). Every check for it also asks that the backpack reads it
(`const.BACKPACK_BAGS[bagid] ~= nil`): live retail's enum has a `Keyring` member (-1) with no keyring, and on the
Classic clients -1 is the bank.

## 1. Only the slots the game opens

The keyring reports about 32 slots (`C_Container.GetContainerNumSlots`), but the game opens only `GetKeyRingSize()`'s.
That is Blizzard's own Lua (`Blizzard_MainMenuBarBagButtons`: `Camelot/MainMenuBarBagButtons.lua` on Forever,
`Classic/MainMenuBarBagButtons.lua` on Classic Era, loaded at startup on both): the last filled slot rounded up to a
row of 4, a row more once every slot up to it holds a key, never more than the keyring's slots; 4 for an empty
keyring. Every key is in one of those slots. Blizzard's bags show the keyring that size
(`ContainerFrame_GetContainerNumSlots` returns it for `KEYRING_CONTAINER`), and its item buttons padlock a slot past it
(`ContainerFrameItemButtonMixin:UpdateExtended`, `ContainerFrameExtendedItemButtonTemplate`, mouse off).

BetterBags' item buttons run that same `UpdateExtended`, so Show Bags (every slot of a bag in place) drew the keyring
as its open slots and then 28 padlocked ones (reported on Forever, with a screenshot; asked: "for keyring, don't show
locked slots, just the empty slots (and full slots) that are enabled by the game"). `items:Harvest` now reads the
keyring's first `GetKeyRingSize()` slots and no others, so nothing past them is an item, an empty slot or a button
in any view.

- **Growing and shrinking.** The size follows the keyring's contents, and any change to them fires `BAG_UPDATE` for
  the keyring, whose read is targeted at it: a key in the last open slot of a full row opens the next row on that read;
  a key taken out closes it, and the targeted read drops the keyring's slots past the new size (a targeted read keeps
  only the other bags' committed items, `RunRefresh`). A read not targeted at the keyring reads it whole again.
- The free space count was already without the keyring, and stays so.
- **Left as they are** (found in review): a key taken out in the frame between the harvest and its commit (`RunRefresh`
  yields once) can show the slots past the new size padlocked until the keyring's own read lands a moment later;
  they were padlocked all the time before. And `GetKeyRingSize` counts a key only where
  `C_Container.GetContainerItemInfo` answers, while the harvest reads `GetContainerItemID`: a slot with an ID and no
  info would be left out, as Blizzard's own bags leave it out. The client has never been seen to answer that way.

Coverage: `spec/refresh_pipeline_spec.lua` ("keyring slots the game opens": an empty keyring, a row opened and closed,
a key in a far slot), with `GetKeyRingSize` mocked from Blizzard's source (`spec/helpers/wow_mocks.lua`).

## 2. Last in Show Bags

Show Bags lists the bags in slot order (`Phase9_Sort`, `sort.SortItemDataBySlot`), its sections in the order their
first items come (`Phase10_PartitionIntoTabs`; Next's canvas follows `tabData.categories`, `canvasProto:Bind`). The
keyring's bag ID is below the backpack's, so it came first, before "#1: Backpack", while numbered after every bag.
`SortItemDataBySlot` now puts the backpack's keyring after every bag (`slotOrder`), its own slots in order (asked:
"keyring should go last here in terms of sort"). The Classic bank's -1 is not the backpack's keyring and keeps its
place.

Coverage: `spec/sort_spec.lua` ("the backpack's keyring": after every bag on Classic Era and Forever, the Classic Era
bank first, live retail's enum ID left alone), `spec/refresh_pipeline_spec.lua` ("lists the keyring's section after
every bag's", through the whole read with the real slot order).
