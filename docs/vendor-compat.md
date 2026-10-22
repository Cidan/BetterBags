# Vendor Compatibility for BetterBags Search

The plan to make BetterBags' search speak everything the Vendor addon's rules can say, so any Vendor
rule can be written as a BetterBags search rule (a category's rule, or the bags' search box). This
document is the research behind it: what each Vendor property and function really reads, what
BetterBags' search has today, what is missing, and what the "math" in Vendor's rules needs from
BetterBags' query engine.

**Status** (2026-10-21): decided (below, "Decisions"). Built: negation (NOT and `!=` match every
indexed item outside their part, anywhere in a query; `.claude/rules/search-indexing.md` §5), and
precedence (AND before OR, saved rules rewritten once to keep their meaning; §6), `bagname` (§7),
expansions in release order (§8), `quality` as the crafting quality tier (§9), the new item fields
of §10-§13 ("Proposed: new fields" marks each), checked against a capture from the game ("What a
capture settled"). The rest is planned.

## Why

Asked (2026-10-21), after a first look at Vendor (selling, keeping and destroying by rules) that
proposed translating Vendor's rules into BetterBags' search on import:

> okay, i actually want to instead take another approach: i want to add the missing rules to
> BetterBags! (also fix the quality and bagname rules)
>
> i'm especially interested in the math parts.
>
> write all this down as a Vendor compat. are you sure level == ilvl here btw? itemlevel isn't
> minimum level requirement. so double check these mean what you think they do.

## Sources, and what is measured

- **Vendor** 6.11.5, `github.com/typicalzergling/vendor` at commit `86893ad` (2026-07-18), MIT
  licensed. File references below (`systems/...`, `rules/...`) are in that repository.
- **Blizzard's UI source** in `.libraries/wow-ui-source` (branch `live`, `b9be93797`, 2026-10-16),
  its generated API documentation (`Blizzard_APIDocumentationGenerated/*.lua`), and warcraft.wiki.gg
  for what the generated documentation does not describe.
- **BetterBags** `main` at `adc49de3`.
- **Measured** (offline, PUC Lua 5.1, the repository's own modules loaded the way the specs load
  them, not in the game client): how the current parser and evaluator answer a set of queries
  ("The query engine today"), and what evaluating a rule item by item costs against an index lookup
  ("Cost"). The probes are throwaway specs outside the repository; their results are quoted here.
- **Counted**: a corpus of 58 real Vendor rules ("What the rules people write use").
- **Read from code, not verified in game**: everything else. The questions only the game can
  answer are listed at the end ("Needs an in-game check").

## How a Vendor rule works

A rule is any Lua expression. Vendor compiles it as `loadstring("return (" .. rule .. ")")`
(`RulesEngine/rule.lua:124`) and runs it with `setfenv` in a read-only environment
(`RulesEngine/engine.lua:303-332`). Nothing restricts the syntax: whatever compiles inside
`return ( )` runs, an inline `(function() ... end)()` included.

**What a rule can see**, searched in this order (`engine.lua:358`):
1. The item's properties, by name (`Level`, `IsSoulbound`, ...; next section). Only plain values
   are copied in (`createAccessors`, `engine.lua:282`), and every property has a default (`false`,
   `0` or `""`, `itempropertyinfo.lua`), so a property is never `nil`. A property the client does
   not support (its `Supported` flag) is absent, and naming it is an error.
2. Vendor's functions and constants (below), and a rule's parameters (`ITEMLEVEL`, ...).
3. Lua's `string`, `math` and `table` libraries, `tonumber` and `tostring` (`engine.lua:591`), and
   Blizzard's `INVTYPE_*` and `INVSLOT_*` globals (`rules/manager.lua:27-46`).

Any other name is an error ("No function or variable named ..."), and the rule is marked unhealthy.

**The result** (`RulesEngine/rule.lua:39-51`): a boolean is used as is, a number is true when it is
not 0, and anything else (a string, a function, nil) is false. So `Level` alone is "has an item
level", and `Name` alone is always false.

**Lua's semantics apply in full**, and real rules depend on them:
- `and` binds tighter than `or`; `not` binds tighter than both.
- `==` is exact and case-sensitive for strings.
- `and`/`or` return one of their operands, not a boolean. A shared Reddit rule writes
  `Quality == (POOR or COMMON)`, which is `Quality == 0`: `0` is true in Lua, so `(0 or 1)` is `0`
  and the rule never matches Common items. BetterBags should not reproduce this; it is the rule's
  bug, not intended behavior.

**Rule types and precedence** (`rules/manager.lua:19-24`, categories sorted by ID in
`RulesEngine/engine.lua:10-20`): the Keep list, then the Sell list, then the Destroy list, then Keep
rules, then Sell rules, then Destroy rules; the first match wins.

**Parameters**: a built-in rule may declare parameters (`Params`, `rules/definitions.lua`), which the
player sets per profile (`{ rule = "sell.raregear", ITEMLEVEL = 81 }` in `Vendor_Profiles`) and the
rule reads as upper-case names. The gear rules' `ITEMLEVEL` defaults to 80% of the lower of the
player's overall and equipped average item level (`DefaultItemLevel`, `rules/definitions.lua:25-31`),
computed when the default is made, not kept current.

## Is Vendor's `Level` the item level?

Yes. `Level` is the item level, not the level required to use the item; that one is `MinLevel`.
BetterBags' `level` (and its alias `ilvl`) is the item level too. The two read it from different
APIs, though, and BetterBags has no required level at all.

| Name | Reads | Means |
|---|---|---|
| Vendor `Level` | `C_Item.GetDetailedItemLevelInfo(link)`, first return (`itemproperties.lua:136`) | The item's actual item level, "same as in tooltip", upgrades included (wiki, `GetDetailedItemLevelInfo`). Does not show timewalking scaling: it "matches [the] number in parenthesis in [the] tooltip" (wiki). |
| Vendor `MinLevel` | `C_Item.GetItemInfo(link)`, 5th return (`itemproperties.lua:146`) | "The minimum level required to use the item, or 0 if there is no level requirement" (wiki, `C_Item.GetItemInfo`). |
| Vendor `MaxLevel` | `C_Item.GetItemUpgradeInfo(link).maxItemLevel` for upgradeable equipment, else `Level` (`itemproperties.lua:185-210`) | The item level once fully upgraded. |
| BetterBags `level` / `ilvl` | `C_Item.GetCurrentItemLevel(itemLocation)` (`data/items.lua:3086`), falling back to `GetDetailedItemLevelInfo(itemID)` | The item level of the item in that slot. The API documents only its signature; caches.md §1 records that it changes with scaling without the link changing (heirlooms, level-scaled gear). |
| `GetItemInfo`'s 4th return | | "The base item level, not including upgrades" (wiki). Neither addon searches on it. |

**Differences that matter:**
- For items that scale (heirlooms, level-scaled gear, timewalking), BetterBags' `level` follows the
  scaling and Vendor's `Level` may not. Which number the tooltip shows in each case is unverified.
- Vendor patches two gaps Blizzard left after the Midnight item level squish, through game curve
  92181 (`C_CurveUtil.EvaluateGameCurve`, documented in `CurveUtilDocumentation.lua`, never called by
  Blizzard's UI): `MaxLevel` when it is more than 26 above `Level` (Blizzard "did not properly reduce
  maxItemLevel for upgradeable items", `itemproperties.lua:192-197`), and `Level` of Poor
  Bind-on-Equip items above 200 (`itemproperties.lua:247-250`). BetterBags applies neither. Whether
  Blizzard has since fixed either is unverified.
- **BetterBags reads `GetItemInfo` by item ID, not by link** (`items:ReadItemProperties`,
  `data/items.lua:3099-3101`). So the fields it reads from it today but does not search on
  (`itemLevel`, `itemMinLevel`, `sellPrice`) describe the base item, not the item in the slot.
  Vendor reads them from the link. Any new search field taken from `GetItemInfo` (required level,
  sell price) must read the link, or be shown to give the same answer by ID (see "Needs an in-game
  check").

## Vendor's item properties, one by one

Every property, what Vendor reads for it (`systems/itemproperties/itemproperties.lua`, the line
noted), and what BetterBags' search has for it today (`fillSnapshot`, `data/search.lua:63-106`).
"(retail)" in a row means Vendor marks the property unsupported on Classic
(`itempropertyinfo.lua`). A **proposed** field name is what this plan would add.

### Identity and counts

| Vendor | Vendor reads | BetterBags today | Notes and proposal |
|---|---|---|---|
| `Name` | `GetItemInfo(link)` 1st | `name` (the container info's name, else `GetItemInfo(id)`) | Same value. Vendor compares exactly (`==`); BetterBags' `=` is a prefix match. Proposed: an exact operator (`==`). |
| `Id` | `ItemMixin:GetItemID()` | `id` | Same. |
| `Link` | `ItemMixin:GetItemLink()` | none | Real rules use it only through `string.find` on the link's IDs. Proposed: not a field; `bonusid` (exists) covers the useful part. |
| `GUID` | `ItemMixin:GetItemGUID()` | `guid` | Same. |
| `Count` | `C_Item.GetStackCount(location)` | `count` / `stackcount` (`ContainerItemInfo.stackCount`) | Same per slot. BetterBags matches a virtual stack through its base pile only (README). |
| `StackSize` | `GetItemInfo` 8th: the most per stack | none (read by ID, not indexed) | Proposed `stacksize`. |

### Level and value

| Vendor | Vendor reads | BetterBags today | Notes and proposal |
|---|---|---|---|
| `Level`, `MinLevel`, `MaxLevel` | above | `level` / `ilvl` only | Proposed `minlevel` (read from the link) and `maxlevel` (with the upgrade fields below). |
| `UnitValue` | `GetItemInfo(link)` 11th, copper; 0 cannot be sold | none (`sellPrice` read by ID, not indexed) | Proposed `price` (copper, from the link). |
| `TotalValue` | `UnitValue * Count` | none | Proposed `totalprice`, or `price * count` once arithmetic exists. |
| `UnitGoldValue`, `TotalGoldValue` | `floor(value / 10000)` | none | With arithmetic: `price / 10000`. Proposed: money literals (`price < 5g`) as a convenience. |
| `IsUnsellable` | `UnitValue == 0` | none | Proposed `sellable`, from `ContainerItemInfo.hasNoValue`: the flag Blizzard's own bags use to decide which Poor items get the junk coin at a merchant (`ContainerFrameItemButtonMixin:UpdateJunkItem`, `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:1721-1727`). Vendor's own notes say a few items have a value but cannot be sold; the container flag is per slot and is what the client sells by. |

### Type

| Vendor | Vendor reads | BetterBags today | Notes and proposal |
|---|---|---|---|
| `Type`, `SubType` | `GetItemInfo(link)` 6th, 7th (localized) | `type`, `subtype` (`GetItemInfoInstant`, localized) | Same values. |
| `TypeId`, `SubTypeId` | 12th, 13th | `class`, `subclass` | Same values. |
| `EquipLoc` | 9th: the token (`"INVTYPE_HEAD"`) | `slot` / `equipmentlocation` holds the localized name (`_G[token]`) | Vendor rules compare against `INVTYPE_*` constants. Proposed: accept the tokens as values of `slot`. |
| `EquipLocName` | `_G[EquipLoc]` | `slot` | Same value. |
| `InventoryType` | `ItemMixin:GetInventoryType()` (`Enum.InventoryType`) | none (`data.inventoryType` is read, not indexed) | Low value; the slot covers it. |
| `ExpansionPackId` | `GetItemInfo` 15th | `expansion` / `exp` holds a short name (`classic`, `bc`, ... `midnight`) | A string field, so `<` and `>` did not work on it (measured below). Vendor's own help warns the ID is set reliably only on equipment. Done: `<`/`>` order expansions by release (`exp < legion`), and numbers work (`exp = 3`). |
| `IsCraftingReagent` | `GetItemInfo` 17th | `reagent` | Same. |
| `IsEquipment` | `C_Item.IsEquippableItem(id)` | none | The API answers "is gear", not "can this character wear it": Blizzard's `/use` equips anything it accepts that is not worn (`SecureTemplates.lua:430`). Proposed `equipment`. |
| `IsProfessionEquipment` | `IsEquipment and TypeId == 19` (retail) | none | Proposed `professiongear`, or `equipment and class = 19`. |
| `HasUseAbility` | `C_Item.IsUsableItem(id)` | none | Vendor's help says "has a Use: effect". The API documents only `usable, noMana`, and Blizzard's own UI never calls it, so what it means for an item without a Use effect is unknown. Proposed `hasuse`, from `C_Item.GetItemSpell(id)` (documented: the spell of the item) or the tooltip's Use line; verify first. |
| `IsUsable` | `C_PlayerInfo.CanUseItem(id)` (retail) | none (the upgrade provider calls it) | Proposed `usable`. |
| `IsEquippable` | `IsUsable and IsEquipment` (retail) | none | Proposed `equippable`. |
| `IsToy` | the tooltip's left text contains `TOY` (`itempropertytooltipscan.lua:53`) | none | `C_ToyBox.GetToyInfo(itemID)` is computed and then unused (`itemproperties.lua`). Proposed `toy`, from `C_ToyBox.GetToyInfo` (Blizzard's Toy Box reads it, `Blizzard_ToyBox.lua:322`). |
| `IsAlreadyKnown` | the tooltip contains `ITEM_SPELL_KNOWN`, only when `HasUseAbility` | none (`tooltip %= "already known"` works in English) | Proposed `known`: toys from `PlayerHasToy` (`Blizzard_ToyBox.lua:248`), otherwise the tooltip line `ITEM_SPELL_KNOWN`, localized. |
| `IsPet`, `PetName`, `PetType`, `IsPetTradeable`, `PetSpeciesId`, `PetCount`, `PetLimit` | `C_PetJournal.GetPetInfoByItemID`, `GetNumCollectedInfo` (retail) | none | Proposed `pet`, `petcount`, `petlimit`. |
| `IsPetCollectable` | `PetCount < PetLimit` | none | Vendor's help says "True if PetCount == PetLimit", the opposite of the code. The code (can still collect) is the useful meaning. Proposed `collectable`. |
| `CraftedQuality` | `C_TradeSkillUI.GetItemCraftedQualityByItemInfo(link)` (retail) | none | `quality` (below): the crafting tier, a reagent's or a crafted item's. |
| `IsScrappable` | `C_Item.CanScrapItem(location)` (retail) | none | Proposed `scrappable`. |
| `IsConduit`, `IsAzeriteItem` | Shadowlands and Battle for Azeroth APIs | none | Old content. Not proposed. |
| `Quality` | `GetItemInfo(link)` 3rd | `rarity` (`C_Item.GetItemQuality(location)`); `quality` is dead (below) | Same values as `rarity`. `quality` stays for crafting quality (below). |

### Binding

BetterBags classifies binding into one value per item (`binding.GetItemBinding`,
`data/binding.lua:41-81`). Vendor sets several flags. They do not line up one to one:

| Vendor | Vendor's rule (`itemproperties.lua:215-244`) | In BetterBags today |
|---|---|---|
| `BindType` | `GetItemInfo(link)` 14th: the base behavior | `bindtype` (same) |
| `IsSoulbound` | `C_Item.IsBound(location)` or BindType 1, and the tooltip does not say Warbound | `binding = soulbound or binding = quest or binding = refundable` (BetterBags splits bound quest items and refundable purchases out). On Classic, where BetterBags cannot tell soulbound from warbound, `bound = true`. |
| `IsBindOnEquip` | not soulbound and BindType 2; true for Warbound-until-Equipped too | `binding = boe or binding = wue` |
| `IsBindOnUse` | not soulbound and BindType 3 | `binding = bou` |
| `IsWarbound` / `IsAccountBound` | bound and the tooltip says `ITEM_ACCOUNTBOUND`, or Warbound until Equipped | `binding = warbound or binding = wue` (BetterBags asks `C_Bank.IsItemAllowedInBankType(Account)` instead of reading the tooltip) |
| `IsWarboundUntilEquip` | `C_Item.IsBoundToAccountUntilEquip(location)` or `IsItemBindToAccountUntilEquip(link)` (retail) | `binding = wue` |

Proposed: booleans with Vendor's meanings (`soulbound`, `boe`, `bou`, `warbound`, `wue`), so a
rule does not need the combinations above.

### Equipment, upgrades and transmog

| Vendor | Vendor reads | BetterBags today | Notes and proposal |
|---|---|---|---|
| `IsEquipped` | the location is an equipment slot | none | Always false for an item in a bag. Not proposed. |
| `IsTransmogEquipment` | the equip location is in Vendor's own list of transmog slots | none | Proposed `transmoggable`, from the same list. |
| `IsUpgradeable`, `UpgradeTrack`, `UpgradeLevel`, `UpgradeMax`, `IsFullyUpgraded` | `C_Item.GetItemUpgradeInfo(link)`: `trackString`, `currentLevel`, `maxLevel`, `maxItemLevel` (retail, equipment only) | none | Documented struct: `ItemUpgradeInfo` (`ItemDocumentation.lua`). Proposed `upgradeable`, `track` ("Veteran", "Hero"; localized), `upgradelevel`, `upgrademax`, `maxlevel`. Vendor's `IsFullyUpgraded` is declared a number but set to a boolean. |
| `HasAppearance`, `AppearanceId`, `SourceId` | `C_TransmogCollection.GetItemInfo(link)` (retail) | read into `data.transmogInfo` (`items:TransmogInfoOf`, `data/items.lua:3155`), not indexed | Proposed `hasappearance`. |
| `IsAppearanceCollected`, `IsUnknownAppearance` | collected when: soulbound (assumed collected), or this source is (`PlayerHasTransmogItemModifiedAppearance`), or any source of the appearance is (`GetAppearanceSources`), or `PlayerHasTransmogByItemInfo(link)` | BetterBags reads `PlayerHasTransmog(itemID, modifiedAppearanceID)`: this exact source only | The two differ: Vendor counts the look as collected through any item that gives it. Proposed `appearance = known` / `unknown` with Vendor's meaning, and `source = known` for this item's own source. |
| `IsCosmetic` | the tooltip contains `ITEM_COSMETIC`, for equipment (retail) | none (a real profile's rule is the bare word `cosmetic`, a text search) | Proposed `cosmetic`, from `C_Item.IsCosmeticItem` (documented). |

### Location and character

| Vendor | Vendor reads | BetterBags today |
|---|---|---|
| `IsBagAndSlot`, `Bag`, `Slot` | the item location | `bagid`, `slotid` |
| `PlayerName`, `PlayerRealm` | `UnitFullName("player")`, constants for the session | none. Proposed `player.name`, `player.realm` (below). |

## Vendor's functions and constants

Functions are registered with a `Supported` flag like properties (`systems/rules/builtins.lua`,
`features/functions/functions.lua`, `systems/lists/functions.lua`). Extension functions are named
`Source_Name` (`rules/extensions.lua:124`).

| Function | What it really does | Proposed in BetterBags |
|---|---|---|
| `PlayerLevel()` | `UnitLevel("player")` | `player.level` |
| `PlayerItemLevel()` | `floor` of `GetAverageItemLevel()`'s first return, the overall average including the bags. Vendor's help says "as it appears in the character panel"; the panel's number is `max(C_PaperDollInfo.GetMinItemLevel(), avgItemLevelEquipped)`, and the overall average is in its tooltip (`PaperDollFrame.lua:1299-1310`). | `player.ilvl` (the overall average, as Vendor) and `player.equippedilvl` |
| `PlayerClass()` | `UnitClass("player")` 2nd: the English token (`"MAGE"`, `"DEATHKNIGHT"`) | `player.class` |
| `PlayerClassId()` | `UnitClass("player")` 3rd | `player.classid` |
| `PlayerSpecialization()`, `PlayerSpecializationId()` | `GetSpecializationInfo(GetSpecialization())` 2nd, 1st (retail) | `player.spec`, `player.specid` |
| `HasProfession(...)` | the player's two primary professions' skill line IDs, from `GetProfessions`; a string is upper-cased and looked up in an English-only map, so only English names work despite the help saying localized | `player.profession = mining` |
| `TooltipContains(text, side?, line?)` | `string.find` on each tooltip line: a Lua pattern, case-sensitive. On retail the `line` argument is ignored; only `side` is used (`builtins.lua`, the retail branch). | `tooltip %= text` exists (below) |
| `HasStat(...)` | `GetItemStats(link)` keys mapped to Blizzard's localized short names, matched against a list of aliases ("crit", "haste", "vers", "speed", ...) | `stat = haste` (BetterBags already calls `GetItemStats` for the stack hash, virtual-stacks.md §4) |
| `TotalItemCount(bank?, uses?)` | `GetItemCount(link, bank, uses, bank)`: the reagent bank with the bank, never the Warbank | `total` (all of the item in the bags), `total(bank)` |
| `WatermarkLevel(account?)` | `C_ItemUpgrade.GetHighWatermarkForItem(link)`: the best item level the character (or account) ever had in this item's slot (retail) | `slotbest` (per item: depends on its slot) |
| `CurrentEquippedLevel()` | the lowest item level of what is worn in the item's slot(s); one-handers check both hands only with `CanDualWield()`; Warriors' two-handers check both (Titan's Grip) | `slotequipped` (per item). BetterBags' upgrade provider already reads the worn gear (caches.md §3). |
| `IsInEquipmentSet(...)` | by item GUID from `C_EquipmentSet.GetItemLocations` (the help says "by item ID"; the code is by GUID) | `equipmentset = "Name"` exists; proposed `inset` for any set |
| `IsInList(...)`, `IsNeverSellItem()`, `IsAlwaysSellItem()`, `IsDestroyItem()`, `IsImportantItem()` | membership in Vendor's lists | The equivalent is a category's added items. Not a search field. |
| `Pawn_IsUpgrade()` | Pawn's verdict | `upgrade`: BetterBags' own upgrade arrow, whichever provider is active (data-loader.md §15) |
| `TSM_*`, `Auctionator_*`, `ATT_*`, `CIMI_*` | the other addon's data | Out of scope. |

**Constants**: qualities `POOR` ... `TOKEN` (0-8); expansions `CLASSIC` ... `WAR_WITHIN` (no
Midnight; `CURRENT_EXPANSION` is still The War Within on retail, `builtins.lua:203-209`); the list
names; primary profession skill lines (`ALCHEMY = 171`, ...); `INVTYPE_*`, `INVSLOT_*`. BetterBags
already accepts quality names for `rarity` (localized, `const.ITEM_QUALITY_TO_ENUM`) and expansion
short names.

## What the rules people write use

A corpus of 58 rules: Vendor's 35 built-in and extension rules (`rules/definitions.lua`,
`systems/extensionmanager/*.lua`), and 23 rules players wrote. The players' rules come from:
- one account's saved custom rules, kept as test data in Vendor's repository
  (`test/migration/11.7.2022/Vendor.lua`: 10 rules);
- Vendor's GitHub issues #23, #43, #60, #75, #109 and #113 (10 rules);
- a Blizzard EU forum thread and two Reddit posts (3 rules).

A GitHub code search for Vendor's saved variables found 22 other committed saved-variables files (from
two players' repositories); none held a custom rule. The appendix lists every player rule.

| Feature | Player rules (23) | Vendor's rules (35) |
|---|---:|---:|
| `IsEquipment` | 7 | 14 |
| `Quality` | 6 | 14 |
| `not` | 7 | 11 |
| `TooltipContains` | 7 | 0 |
| `IsSoulbound` | 6 | 6 |
| `TypeId`, `SubTypeId` | 5 each | 1 each |
| `ExpansionPackId` | 5 | 0 |
| `Level` | 5 | 2 |
| `MaxLevel` | 0 | 11 |
| `IsUnsellable` | 1 | 9 |
| `IsInEquipmentSet` | 3 | 4 |
| `Name ==` (exact) | 2 | 0 |
| `PlayerClass()` | 2 | 0 |
| Comparison to a parameter (`ITEMLEVEL`) | 3 | 9 |
| Player-relative value | 0 | 5 |
| Arithmetic | 0 | 3 |
| Other addons' functions | 3 (TSM) | 4 (Pawn, ATT, CanIMogIt) |
| Old syntax: properties called as functions (`Level()`, `SubTypeId()`), `--` comments | 3 | 0 |

The same account's profiles show which built-in rules are turned on: Poor Items 7 times, Low-Level
Food, Known Toys, Uncollected Appearances, Legendary or Better and Equipment Sets 6 each, Potential
Upgrades 5, Known Toys (destroy) 5, Epic Gear (keep) 4, Rare Gear (keep) 3. Its Sell, Keep and
Destroy lists hold 294 items across 7 profiles.

**What this says about the math**: players compare item fields to fixed numbers (`Level < 300`,
`ExpansionPackId == 6`) and to the gear rules' `ITEMLEVEL` parameter. In this corpus every piece of
arithmetic, and every comparison to the player, is in Vendor's own built-in rules:

| Built-in rule | Expression | Needs |
|---|---|---|
| Low-Level Food | `Level <= (PlayerLevel() - FOOD_LEVEL)` | a player value, subtraction |
| Potential Upgrades | `MaxLevel >= math.min(PlayerItemLevel() * .95, PlayerItemLevel() - 5)` | a player value, `*`, `-`, `min` |
| Side-grade or Better | `MaxLevel >= WatermarkLevel()` and `MaxLevel >= (.8 * PlayerItemLevel())` | a per-item slot value, `*` |
| Side-grade or Better (Classic) | `Level >= CurrentEquippedLevel()` | a per-item slot value |
| Leveling Gear | `MinLevel > PlayerLevel()` | a player value |
| Uncommon/Rare/Epic Gear (sell and keep) | `MaxLevel < ITEMLEVEL`, `MaxLevel >= ITEMLEVEL` | a number the player sets |

Low-Level Food compares the food's item level to the player's level. Whether those two scales still
line up after the item level squishes is unverified.

## The query engine today

The lexer (`util/query.lua:21-120`) makes three kinds of tokens: parentheses, comparison operators
(`=`, `!=`, `%=`, `<`, `<=`, `>`, `>=`), and words. A word is any run of characters that are not
whitespace, a control character or `()=!<>` (`is_alphanumeric`, `util/query.lua:40-42`), so `+`,
`-`, `*`, `/` and `.` are word characters. `AND`, `OR` and `NOT` are words in any case. The parser
(`util/query.lua:125-186`) reads `term`, `field op value`, `NOT term` and parentheses, and joins
terms with AND and OR **left to right, at the same precedence**. The evaluator
(`search:EvaluateAST`, `data/search.lua:726`) answers each comparison from an index as a set of slot
keys, and combines the sets.

**Measured**: the real `util/query.lua` and `data/search.lua`, five items (A Poor, level 10; B Epic,
600; C Common, 90; D Rare, 300; E Poor, 1):

| Query | Parsed as | Matches | Should match |
|---|---|---|---|
| `rarity = poor` | as written | A, E | A, E |
| `NOT rarity = poor` | `NOT(rarity = poor)` | **nothing** | B, C, D |
| `rarity != poor` | as written | B, C, D (and a stray `___NEGATED___` key) | B, C, D |
| `NOT rarity = poor OR ilvl > 500` | `(NOT(...)) OR (...)` | **B** | B, C, D |
| `ilvl > 50 AND NOT rarity = epic` | as written | C, D | C, D |
| `name = alpha OR name = bravo AND rarity = epic` | **`(alpha OR bravo) AND epic`** | B | A, B (Lua and most query languages: AND first) |
| `ilvl > 100-10` | `ilvl > "100-10"` | **nothing** | B, D |
| `ilvl >= rarity` | `ilvl >= "rarity"` | **nothing** | every item (a field compared to a field) |
| `expansion < 5` | as written | **nothing** | A, E |
| `quality = epic`, `quality = 4` | as written | **nothing** | B |
| `bagName = backpack` | as written | **nothing** | every item in the backpack |
| `(rarity = poor` | the unclosed parenthesis is ignored | A, E | an error |

What these mean for Vendor rules:
- **Negation is broken outside an AND.** A NOT returns the items it excludes, marked false, plus a
  `___NEGATED___` marker; only AND reads the marker, and only a bare `field != value` is completed
  against every item (`search:EvaluateQuery`, `data/search.lua:865`). So `NOT x` on its own, or
  inside an OR, matches too little. 18 of the 58 rules use `not`, so this must be fixed first. The
  marker also leaks into the results of a bare `!=` as a slot key (harmless today: no item has
  that key).
- **AND and OR have the same precedence.** Lua gives AND precedence, and Vendor rules are written
  for that. Changing it changes the meaning of any saved rule that mixes AND and OR without
  parentheses. The one real profile in the repository (`test.lua`) has 7 distinct rules and none mixes them
  (`ilvl < 220 and (armor or weapon)` already uses parentheses). Saved rules can be rewritten once,
  with parentheses that keep their old left-to-right meaning, before the precedence changes.
- **No arithmetic, no field-to-field comparison, no ordering on text fields.** Everything a word
  can be compared with is a literal.
- **An unknown field matches nothing, silently** (`search:GetIndex` returns nil).

### `quality` and `bagName`

Both were added with today's search engine (Search Redone, #494, 2024-07-29) and have never matched
anything:
- `quality` is created (`data/search.lua:176`) and never filled; `rarity` holds the item quality.
  It was meant for crafting quality (the tiers of profession reagents and crafted items), which is
  why the item quality is `rarity` (the player, 2026-10-21). Nothing in the repository records that:
  it was created next to `rarity` in #494 with no comment, and no commit, README line or issue
  mentions crafting quality. **Fixed**: it holds the crafting tier, read in the order Blizzard's item
  buttons read it: `C_TradeSkillUI.GetItemReagentQualityByItemInfo`, else
  `GetItemCraftedQualityByItemInfo` (`Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:330-334`;
  both documented in `TradeSkillUIDocumentation.lua`, a nilable number); retail only
  (`.claude/rules/search-indexing.md` §9).
- `bagName` is created (`data/search.lua:165`), and the lines that would fill it were commented out
  from the start. **It is also unreachable**: the evaluator lower-cases every field name before
  looking it up (`evaluate_condition`, `data/search.lua:737`), every other index is created
  lower-case, and `bagName` is not. Items do not carry a bag name today (only the spec mock sets
  one). **Fix**: create it as `bagname` (alias `bag`), filled with `C_Container.GetBagName(bagid)`,
  the plain container name ("Backpack", the bag's item name); the Show Bags labels (`#1: Backpack`,
  `items:GetBagName`) add a number that a search should not need. Bags are only swapped through
  `BAG_CONTAINER_UPDATE`, which is already a wipe sweep (refresh-scheduler.md §10), so the name
  never goes stale.

## Proposed: the math

### Grammar

Keep every query that works today working, and add Lua's expressions:

```
expression  := or
or          := and ( "OR" and )*
and         := not ( "AND" not )*
not         := "NOT" not | comparison
comparison  := sum ( op sum )?          op: = != %= < <= > >= == ~=
sum         := product ( ("+" | "-") product )*
product     := unary ( ("*" | "/" | "%") unary )*
unary       := "-" unary | primary
primary     := number | money | string | name | name "(" args ")" | "(" expression ")"
```

- **Precedence as Lua**: NOT, then AND, then OR. Saved rules that mix AND and OR without
  parentheses are rewritten once to keep their meaning (above).
- **Operators**: `==` (the whole value) and `~=` (its negation) join `=` (prefix), `!=` and `%=`
  (anywhere in the text). Unlike Lua's, `==` ignores case, as every BetterBags text index does (they
  are lower-cased). `+ - * / %` and unary `-` on numbers.
- **Names**: a field (`ilvl`), a player value (`player.level`), a per-item slot value (`slotbest`),
  or a constant (`epic`, `legion`, `INVTYPE_HEAD`). `.` and digits stay inside words, so
  `player.ilvl` and `0.95` lex as one word each, as today. The lexer must learn `+ - * /` as
  operators (today `100 - 10` is three words). Splitting on them even without spaces would also
  split an unquoted hyphenated word; requiring spaces around them keeps every word that works
  today (to decide).
- **Functions**: `min`, `max`, `floor`, `ceil`, `abs` (`math.min` accepted for Vendor's spelling).
- **Bare words stay text searches.** A bare word is a full-text search today, and real rules rely on
  it: the real profile's rule `cosmetic` searches for the word. A boolean field is tested with
  `field = true` (as `reagent = true` today), never by its bare name, so adding a `cosmetic` field
  does not change that rule. Vendor's own spellings are converted by an import, not accepted here
  (decision 2).
- **Money**: `5g`, `50s`, `1g50s` as copper.

### Evaluation

1. **Fold what is constant for the evaluation.** Constants, player values and arithmetic on them
   become a number before any item is looked at: `ilvl <= player.level - 10` becomes `ilvl <= 80`.
2. **A field on one side, a number on the other, is an index lookup**, as today. Every rule in the
   corpus that this plan supports, except the two Side-grade or Better rules (slot-relative), becomes
   this, and costs what a rule costs today.
3. **Anything else is checked item by item**: a field compared to another field (`maxlevel >=
   ilvl`), arithmetic on a field (`price * count > 5g`), or a per-item value (`maxlevel >=
   slotbest`). The item's values are the indexed snapshots (`search.indexed[slotkey]`, which holds
   every field of every indexed item, search-indexing.md §1), so no new store is needed. Within an
   AND, the parts the index can answer are evaluated first, and only their matches are checked one
   by one.
4. **Negation against every item.** NOT and `!=` are completed against `search:Universe()` (every
   item of both bags) wherever they appear, replacing the `___NEGATED___` marker.

### Cost

Measured offline in PUC Lua 5.1 (not the game client), on 200, 600 and 1,500 items, three runs each,
milliseconds per evaluation of one rule over every item:

| Items | Index query (today's `search:Search`) | Compiled check per item | Tree-walking check per item |
|---:|---:|---:|---:|
| 200 | 0.024-0.034 | 0.061-0.068 | 0.118-0.122 |
| 600 | 0.062-0.064 | 0.175-0.188 | 0.368-0.380 |
| 1,500 | 0.113-0.114 | 0.437-0.472 | 0.896-0.923 |

The three answer the same question (an item level threshold and a quality) and returned the same
items. A check per item costs 3-8 times an index lookup, so it is reserved for what an index cannot
answer, and narrowed by the index first. For scale: in the game, re-running every search category
on every sweep already costs 1-5 ms (`docs/roadmap.md`, "Search categories re-run every sweep").
"Compiled" means a Lua closure built from the parsed rule (never `loadstring` on the player's text);
it is what to build.

### Keeping results current

A rule that reads a player value or a slot value changes its answer without any item changing. Search
categories are evaluated on every sweep (`items:RefreshSearchCache`, `data/items.lua:2269`), so a
recalculation (`bags/Rederive`, refresh-scheduler.md §10) is enough, requested on the events that
change each value: `PLAYER_LEVEL_UP` and `PLAYER_LEVEL_CHANGED` (`player.level`),
`PLAYER_AVG_ITEM_LEVEL_UPDATE` (`player.ilvl`), `PLAYER_SPECIALIZATION_CHANGED` (`player.spec`),
`SKILL_LINES_CHANGED` (`player.profession`), `PLAYER_EQUIPMENT_CHANGED` (`slotequipped`, `slotbest`).
Upgrade verdicts already listen to most of these (caches.md §2); a rule should request a
recalculation only when a category's rule reads the value, and every new input goes in caches.md
with its invalidation, as that file requires.

## Proposed: new fields

| Field | Type | Source | Clients | Changes when |
|---|---|---|---|---|
| `quality` (done) | number | the crafting tier: `GetItemReagentQualityByItemInfo`, else `GetItemCraftedQualityByItemInfo`, from the link | retail | the slot changes |
| `bagname`, `bag` (done) | text | `items:GetPlainBagName(bagid)` (`C_Container.GetBagName`) | all | read every sweep |
| `minlevel` (done) | number | `GetItemInfo(link)` 5th | all | the slot changes |
| `maxlevel` (done) | number | `GetItemUpgradeInfo(link).maxItemLevel`, else `level` | retail (else `level`) | the slot changes |
| `upgradeable`, `track`, `upgradelevel`, `upgrademax` (done) | bool, text, numbers | `GetItemUpgradeInfo(link)` | retail | the slot changes |
| `stacksize` (done) | number | `GetItemInfo(link)` 8th | all | the slot changes |
| `price` (done); `totalprice` (dropped: `price * count` once arithmetic exists) | numbers (copper) | `GetItemInfo(link)` 11th | all | the slot changes |
| `sellable` (dropped: `price > 0`) | bool | | | |
| `equipment` (done) | bool | `C_Item.IsEquippableItem(link)` | all | the slot changes |
| `usable`, `equippable` (done) | bool | `C_PlayerInfo.CanUseItem(id)` (and `equipment`) | retail | skills, level, spec (caches.md §2's events) |
| `hasuse` (done) | bool | `C_Item.GetItemSpell(link)` returns something: any `Use:` line, learn lines included ("What a capture settled") | all | the slot changes |
| `toy`, `known` (done) | bool | whole tooltip lines `TOY` and `ITEM_SPELL_KNOWN` ("What a capture settled") | all | learning it (`NEW_TOY_ADDED`; for the rest, the tooltip text, re-scanned on `TOOLTIP_DATA_UPDATE`, tooltip-scanning.md) |
| `pet`, `petcount`, `petlimit`, `collectable` (done) | bool, numbers | `C_PetJournal.GetPetInfoByItemID`, `GetNumCollectedInfo` | retail | learning a pet (`NEW_PET_ADDED`) |
| `cosmetic` (done) | bool | `C_Item.IsCosmeticItem` | retail | the slot changes |
| `hasappearance` (as `transmoggable`); `appearance`, `source` (after a login capture) | bool, known/unknown | `C_TransmogCollection` as Vendor (above) | retail | collecting an appearance (`TRANSMOG_COLLECTION_SOURCE_ADDED`); today a known staleness of kept slots, caches.md §1 |
| `transmoggable` (done) | bool | `C_TransmogCollection.GetItemInfo(link)` returns an appearance | retail | the slot changes |
| `professiongear` (dropped: `equipment = true AND class = 19`) | bool | | | |
| `scrappable` (done) | bool | `C_Item.CanScrapItem(location)` | retail, bag slots | the slot changes |
| `soulbound`, `boe`, `bou`, `warbound`, `wue` (dropped: `binding = ...` with OR says each) | bool | | | |
| `inset` (done) | bool | `equipmentSets` is not empty | all with sets | `EQUIPMENT_SETS_CHANGED` (already a recalculation) |
| `stat` (done) | text set | `GetItemStats(link)` keys' global strings (the names match from their start: `stat = crit`) | all | the slot changes |
| `upgrade` (done) | bool | the item's upgrade verdict (`data.isUpgrade`) | all | caches.md §2 |
| `total` (done) | number | the item's count across the kind's bags, by item ID | all | every sweep |
| `slotbest`, `slotequipped` (with the player values) | numbers, per item | `C_ItemUpgrade.GetHighWatermarkForItem(link)`; the worn gear (`equipmentCache`) | retail; all | `PLAYER_EQUIPMENT_CHANGED` |
| `player.level`, `player.ilvl`, `player.equippedilvl`, `player.class`, `player.classid`, `player.spec`, `player.specid`, `player.profession`, `player.name`, `player.realm` | values | `UnitLevel`, `GetAverageItemLevel`, `UnitClass`, `GetSpecializationInfo`, `GetProfessions`, `UnitFullName` | all (spec: retail) | the events above |

Every field is read only once the item's data has loaded (rule #1, the player's: item data is
assumed not to work until its load completes; `C_Item.GetItemInfoInstant` aside; data-loader.md
§19); an item read cold has none of them until it is read again.

Every field read from the item goes through `fillSnapshot` (search-indexing.md §1), so the
incremental index stays equal to a clean rebuild; the randomized test there must cover each new
field.

## Tooltip matching

`TooltipContains` and BetterBags' `tooltip` differ:

| | Vendor `TooltipContains` | BetterBags `tooltip %= text` |
|---|---|---|
| Text | each line's left and right text (`TooltipInfo` lines on retail) | every line's left and right text joined with spaces (`tooltipScanner:ExtractRetail`, `data/tooltip.lua:108-145`) |
| Match | `string.find`: a Lua pattern, case-sensitive | a plain substring, case-insensitive |
| Side, line | side honored; line ignored on retail | neither |
| Across lines | no | yes (the joined text) |

Real rules show the cost of Vendor's version: #43 checks both `"Garrison"` and `"garrison"`, and two
rules use `TooltipContains(PlayerClass())`, which looks for the class token (`"MAGE"`,
`"DEATHKNIGHT"`) in a line Blizzard writes with display names (`ITEM_CLASSES_ALLOWED` formatted with
each class's `className`, as `Blizzard_Wardrobe_Sets.lua:640-657` builds it; an item tooltip itself
was not checked), so a case-sensitive match should never find it. BetterBags' version is the friendlier one; it only needs a
way to limit a match to one line if that turns out to be wanted.

## Not proposed

- Other addons' data (TSM, Auctionator, AllTheThings, CanIMogIt). Pawn maps to `upgrade`.
- Lua's `string` and `table` libraries, and `Link` matching; `bonusid` covers the item string's
  useful part.
- Vendor's lists as search fields: a category's added items are the list.
- Reproducing Lua's value semantics for `and`/`or` (`Quality == (POOR or COMMON)`).
- Vendor's own spellings in search (`IsSoulbound`, `PlayerLevel()`): an import converts them.
- `IsEquipped`, `IsConduit`, `IsAzeriteItem`, the debug properties.

## What a capture settled

A Dump tab capture on retail 12.1.5 (build 70448, enUS, 2026-10-21; 88 items in the backpack, every
item's data loaded), kept as `spec/fixtures/dump_retail_12_1_5.lua`. What each API answered:

- **Link against item ID.** One item of 88 answered differently: an upgraded Voidfused Wing Cloak,
  by item ID item level 80, required level 80, Uncommon, 225,552 copper; by link 230, 90, Rare,
  325,268. The new fields read the link (`minlevel`, `price`); `C_Item.GetCurrentItemLevel` at its
  location gave 230, the link's level, for every item.
- **Upgrade tracks.** `C_Item.GetItemUpgradeInfo` returned a table for every item (zeros for
  cheese and recipes). The cloak's named a track (Adventurer) with 0/0 levels and max item level 0,
  and its tooltip had no upgrade level line: a track string alone is not a track. `upgradeable`
  needs a track string and a max level above 0.
- **Toys.** `C_ToyBox.GetToyInfo` answered with an item ID for the two toys and for no other item;
  both toys' tooltips have a line `Toy` (`TOY`) and, learned, a line `Already known`
  (`ITEM_SPELL_KNOWN`, line type 43, UsageRequirement). `toy` and `known` read those lines.
- **Use spells.** `C_Item.GetItemSpell` returned a spell for 51 items and nothing for 37: exactly
  the items with a `Use:` line (type 44), plus 8 recipes and pets whose `Use: Teaches you` lines are
  type 38 (ItemSpellTriggerLearn) and return the spell "Learning". `hasuse` is any Use line.
- **Equipment.** `C_Item.IsEquippableItem` was true for the cloak only (consumables, recipes,
  reagents, quest items, housing dyes all false). A second capture the same day
  (`spec/fixtures/dump_retail_12_1_5_bag.lua`, 33 items) had a bag, a Horadric Haversack: equippable
  true, usable true, sell price 0, no Use spell, no appearance. So `equipment` includes bags, as
  Vendor's `IsEquipment` does (the same API).
- **Appearances.** `C_TransmogCollection.GetItemInfo` returned nothing for 87 items and an
  appearance for the cloak (collected).
- **Usability.** `C_PlayerInfo.CanUseItem` was false for the 9 recipes of professions the character
  does not have, true for everything else.
- **Crafting tiers.** Three items answered tier 1 to both `GetItemReagentQualityByItemInfo` and
  `GetItemCraftedQualityByItemInfo`; their tooltips show the tier icon
  (`Professions-Icon-Quality-12-...`).
- **Pets.** `C_PetJournal.GetPetInfoByItemID` answered for the two pet items (species 243 and 3580),
  `GetNumCollectedInfo` 1 of 1 for both.
- **Bags.** `C_Container.GetBagName` gave "Backpack" and the bag's item name ("Shrouded Cloth Bag").
- No API raised an error.

A fresh-login profiler capture the same day (with the collection events and counts,
perf-profiler.md §10b): the pet journal answered 0 owned at 6.9 s (during the loading screen) and
234 owned at its first `PET_JOURNAL_LIST_UPDATE` at 13.36 s, just after the loading screen ended
(13.34 s) and 1.4 s before the startup read (14.80 s); the toy box had loaded by then too (0 at
6.9 s, 165 of 1003 at 13.36 s). `TRANSMOG_COLLECTION_UPDATED` fired once, at 6.9 s.

A diagnostics run the same evening (a login capture and a `/reload` capture with samples, and a dump
with the bank, 509 bank items, the worn gear and every bag's name):

- **Usability** (`C_PlayerInfo.CanUseItem`): false for all 30 backpack items, food included, at the
  end of the login's loading screen; false for 6 after the first `SPELLS_CHANGED`; right for all
  after the second, about 2.2 s later. The first bag read came 0.23 to 0.3 s after it in every login
  captured. Right from the start on a `/reload`. BetterBags now asks again on `SPELLS_CHANGED` and
  `UPDATE_FACTION` (search-indexing.md §13).
- **Pet journal on a `/reload`**: the counts are there from the start (234 owned at `ADDON_LOADED`);
  `PET_JOURNAL_LIST_UPDATE` fires twice, the first 59 ms after the first bag read began
  (search-indexing.md §14).
- **Appearance collection**: 0 collected until `PLAYER_ENTERING_WORLD`, then 3,083, on the login and
  on the reload, both before the first bag read. `TRANSMOG_COLLECTION_UPDATED` is no sign it has
  loaded: at login it fired during the loading screen with 0 collected.
- **Appearances per item**: 141 items with an appearance, every one collected by its own source
  (`PlayerHasTransmogItemModifiedAppearance`), by `GetSourceInfo` and by some source of the
  appearance; `PlayerHasTransmogByItemInfo` said false for 3 of them (The Silver Hand, Ashbringer,
  Truthguard: artifacts). No uncollected appearance to check the other way.
- **Player values** (for `player.*`): at `ADDON_LOADED` the level, class and professions are right,
  but the specialization reads 1 (2 later) and the average item level 0; both are right by about
  11 s, during the loading screen, before any bag read. Not with their own events: the change was
  first seen at `TOYS_UPDATED` and `SKILL_LINES_CHANGED`. `C_PaperDollInfo.GetMinItemLevel` returned
  nil; `GetAverageItemLevel` gave the same 233.6875 three times.
- **Item level**: the tooltip shows `C_Item.GetCurrentItemLevel` at the item's location; the link
  (`GetDetailedItemLevelInfo`) differs for two items (Heart of Azeroth: tooltip and location 29, link
  207; Tamed Eagle: 71 and 362). Bag items already read the location; guild bank items, which have
  none, read the link. Poor Bind-on-Equip items: link, location and tooltip agree.
- **Upgrade tracks**: all 18 worn items name a track (Adventurer, Veteran, Champion) with 0/0 levels
  and maximum item level 0, and none has an upgrade level line in its tooltip
  (`TooltipDataLineType.ItemUpgradeLevel`); the rule of §10 holds. No item had levels, so whether
  curve 92181 is needed stays open.
- **Bag names**: `C_Container.GetBagName` names every character bank tab "Bank" and every Warbank tab
  "Warband Bank" (not the tabs' own names); -2 and -3 have none.
- **Toys**: a toy recipe holds the toy's "Toy" line after a `NestedBlock` line (search-indexing.md
  §12); `C_ToyBox.GetToyInfo` answered for the toys only.
- **Crafting tiers**: 63 item IDs with a tier, none with copies at different tiers.

## Needs an in-game check

Only items this character does not have can settle these; the Dump tab records what is needed when
one is in the bags or the bank.

- An item with upgrade levels (Veteran and up, with levels): its `maxItemLevel`, and whether curve
  92181 is still needed.
- An heirloom and level-scaled gear: `GetCurrentItemLevel(location)` against the tooltip.
- Two copies of a crafted item at different tiers.
- An uncollected appearance: which of the ways of asking says so.
- A known recipe: where its "Already known" line sits against its nested item.

## Decisions

Made by the player (2026-10-21):
1. **Precedence**: AND binds tighter than OR, as in Lua. Saved rules that mix them without
   parentheses are rewritten once with parentheses that keep their meaning.
2. **Vendor's spellings**: not accepted in search. Vendor rules come in through an import that
   converts them to BetterBags' search instead (planned separately).
3. **Expansion order**: `<` and `>` compare expansion names by expansion ID.
4. **`bagname`**: the plain container name.

## Order of work

Asked (2026-10-21): the new item fields first, then player values, then arithmetic, then the
import.

1. Negation (NOT and `!=` against every indexed item), precedence (with the saved-rule rewrite),
   `bagname`, expansion order and `quality` as the crafting tier: done.
2. The new item fields ("Proposed: new fields"), each read only once the item's data has loaded
   (rule #1, `.claude/rules/data-loader.md` §19) and with its invalidation in caches.md: done.
3. Player values (`player.level`, `player.ilvl`, ...), with the events that keep them current: done
   (search-indexing.md §15).
4. The parser and evaluator: `==`/`~=`, arithmetic, functions; constants folded into index
   lookups, the per-item check narrowed by the index: done (search-indexing.md §15; operators need
   spaces around them, the open question of "Grammar").
5. Importing Vendor's rules, converted to BetterBags' search.

Each step updates the README's search section and `.claude/rules/search-indexing.md`.

## Appendix: the player rules in the corpus

| Source | Rule |
|---|---|
| test/migration/11.7.2022 | `(Id == 163569) and (NumKeep() >= 1)` (`NumKeep` no longer exists) |
| test/migration/11.7.2022 | `(not IsEquipment) and (SubTypeId == 0) and (TypeId == 15) and (ExpansionPackId == 0) and (IsUsable) and (not IsUnsellable) and (Quality == 4) and (not TooltipContains(PlayerClass()))` |
| test/migration/11.7.2022 | `ExpansionPackId() == 6 -- Legion and SubTypeId() == 11 -- Artifact Relic and TypeId() == 3 -- Gem` (written on several lines) |
| test/migration/11.7.2022 | `HasStat("speed")` |
| test/migration/11.7.2022 | `IsCraftingReagent and (ExpansionPackId == 0)` |
| test/migration/11.7.2022 | `SubType == "Artifact Relic"` |
| test/migration/11.7.2022 | `TypeId == 0 and SubTypeId() == 8 and TooltipContains("Champion Equipment")` |
| test/migration/11.7.2022 | `TypeId == 15 and SubTypeId == 4 and IsAlreadyKnown and TooltipContains("Garrison Blueprint")` |
| test/migration/11.7.2022 | `TypeId() == 3 and SubTypeId() == 11 and Level() < 225 and ExpansionPackId() == 6` |
| test/migration/11.7.2022 | `string.find(Name, 'Selfless Bearer')` |
| Issue #23 (three rules) | `(not IsInEquipmentSet()) and IsSoulbound and IsEquipment and Quality == UNCOMMON and Level < {itemlevel}`, and the same for `RARE` and `EPIC` |
| Issue #43 | `TooltipContains("Garrison") or TooltipContains("garrison") or Name == "Miner's Coffee"` |
| Issue #60 | `TooltipContains('alcohol', 'left') or (Name == "Mad Brewer's Breakfast")` |
| Issue #75 | `(not IsEquipment) and (Level < 300) and IsSoulbound and (SubType == "Junk") and TooltipContains("Classes:") and (not TooltipContains(PlayerClass()))` |
| Issue #75 | `IsEquipment and IsSoulbound and (not IsEquippable) and (Quality < 5)` |
| Issue #109 | `TSM_CustomValue("dbregionmarketavg") > 0` |
| Issue #109 | `TSM_CustomValue("dbregionsalerate") > 0` |
| Issue #113 | `TSM_HasCustomValue("dbregionsalerate") and TSM_CustomValue("dbregionsalerate") < 0.05` |
| EU forum, "Addon question: Vendor, use lists" | `IsInList("Precious")` |
| r/wow, "Addon for mass vendoring raid loot" | `TooltipContains("Artifact Relic") and BindType == 1 and ExpansionPackId == 6` |
| r/wowaddons, "Vendor Addon Scripts Share Request" (search snippet) | `Quality == (POOR or COMMON) and IsEquipment and (IsEquippable or not IsSoulbound)` |
