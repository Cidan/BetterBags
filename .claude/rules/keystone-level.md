---
paths:
  - "data/items.lua"
  - "frames/item.lua"
  - "config/catalog.lua"
  - "next/settings/content.lua"
  - "spec/items_spec.lua"
  - "spec/frames/item_spec.lua"
  - "spec/config/catalog_spec.lua"
  - "spec/config/settings_effects_spec.lua"
  - "spec/next/settings/content_spec.lua"
  - "spec/core/constants_spec.lua"
---
# Keystone Level

A keystone shows its level on its button, in the corner where gear shows its item level (`ilvlText`), as a plain
number (asked, issue #202: the AdiBags Keystones plugin drew it there). Keystones are reagents
(`Enum.ItemClass.Reagent`), so before this their buttons showed no text at all: `DrawItemLevel` hides it for anything
but armor and weapons.

## 1. The level, from the link

A keystone's link is not an item link: `keystone:itemID:challengeModeID:level:affix1:affix2:affix3:affix4`
(warcraft.wiki.gg Hyperlinks), the same for every keystone item (138019, 151086, 158923, 180653, the Timeworn
Keystone 187786). `items:KeystoneLevel(link)` (`data/items.lua`) reads its third value (`|Hkeystone:%d+:%d+:(%d+)`), nil
for any other link. Nothing lists item IDs: the report named 138019 (Legion's) and 187786, which would have missed the
keystone players carry now.

- **Read with the rest of the item.** `items:ItemInfoOf` sets `itemInfo.keystoneLevel` from the slot's link
  (`props.itemLink`, `C_Container.GetContainerItemLink`), so every slot a bag reads has it, as an upstream
  pre-computation (item-drawing.md §3). The button never parses a link.
- **A new level is a new read.** The level is part of the link, and `items:ReuseHarvestedSlot` reads a slot again
  when its container info's `hyperlink` changes, so a keystone whose level changed is never kept with its old one.
- No in-game capture was taken of a keystone's bag link (the player who asked waived it): the format is the wiki's.
  `ReadLinkInfo` already skips links that are not `item:` links, so keystones read complete (data-loader.md §19).

## 2. Drawing it

`itemProto:DrawItemLevel` (`frames/item.lua`) checks for a keystone first, before the armor and weapon check: with
`GetItemLevelOptions(kind).keystone` it calls `itemProto:ShowKeystoneLevel(data)`, else it hides the text, and either
way it returns.

- **Its own setting.** Show Keystone Level is apart from Show Item Level (asked: "yes a toggle"): a player who hides
  item levels still sees key levels, and the other way round.
- **Color.** With Show Item Level Color on, the level is drawn in Blizzard's color for it,
  `C_ChallengeMode.GetKeystoneLevelRarityColor(level)` (a ColorMixin, never nil, ChallengeModeInfoDocumentation);
  off, white. The item level colors scale with the highest item level seen, which says nothing about a key level.
- **The draw record** (item-drawing.md §7b) has no field of its own for it: the level is a function of the link,
  which the record holds. Changing either setting sends `bags/Redraw` with buttons, whose style generation draws
  every button in full.

## 3. The setting

`keystoneLevel` (`config/catalog.lua`), "Show Keystone Level", a toggle for the backpack and the bank
(`only`): the guild bank takes no bound item, so never a keystone. It writes `itemLevel[kind].keystone`, on by
default for every kind (`core/constants.lua`; the guild bank's defaults mirror the bank's, constants_spec), and sends
`bags/Redraw` with buttons, as Show Item Level does (refresh-scheduler.md §9). Its row is the last of the bag pages'
Item Level section (`next/settings/content.lua`), hidden off retail: keystones are retail's (Mythic+); the Classic
clients never have a keystone link.

## 4. Left as is (review)

`GetKeystoneLevelRarityColor` takes secret arguments only untainted (`SecretArguments = "AllowedWhenUntainted"`). A
level read from a link the client gave as a secret value would make that call raise. Nobody has seen a bag link come
back secret, and every read of a slot's link already parses it, so nothing is built for it.

Coverage: `spec/items_spec.lua` ("keystone level (issue #202)": both link colors, the Timeworn Keystone, other links;
"reads a keystone's level from its bag slot's link" through `Harvest`), `spec/frames/item_spec.lua` ("keystone level
(issue #202)": the level, its color, white, its own setting, a reagent that is no keystone; "draws a keystone again
when its level changes"), `spec/config/catalog_spec.lua`, `spec/config/settings_effects_spec.lua`,
`spec/next/settings/content_spec.lua` ("shows Show Keystone Level on retail only"), `spec/core/constants_spec.lua`.
