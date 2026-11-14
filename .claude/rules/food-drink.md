---
paths:
  - "data/fooddrink.lua"
  - "next/fooddrinkbar.lua"
  - "next/screencard.lua"
  - "spec/fooddrink_spec.lua"
  - "spec/next/fooddrinkbar_spec.lua"
  - "spec/next/screencard_spec.lua"
---
# BetterBags Next's Food & Drink bar (`data/fooddrink.lua`, `next/fooddrinkbar.lua`, `next/screencard.lua`)

Two buttons on a small card that stays on screen, bags open or closed: the food and the drink in your bags that the
player's rule picks (the highest item level, or the lowest). A right click eats or drinks it; when it runs out, the
button moves to the next one the rule picks.

Asked (2026-11-14): "a set of two buttons ... a food button, and a drink button. the buttons will show you the highest
(or lowest ...) item level food and drink you have in bags. you can click them to use those items and eat/drink, and the
buttons will automatically swap to the next available item as needed"; "we should have all the same rules for masque";
"the way we drag out our currency tracker is amazing"; not in the backpack's footer ("the footer is already pretty
noisy"); "these don't need to be secure action buttons ... they just need to be normal item buttons, and we change the
bagid + slotid"; "right click to eat works, can we block left clicks?"; "update as we get new items to make sure we
select the right items, and if in combat, update after combat ends"; no drop-an-item-to-make-the-bar gesture ("could
get confusing fast").

## 1. What is food and what is drink (`FoodDrink:Kind`)

An item is food, drink or both by the spell it casts when used (`C_Item.GetItemSpell(link)`: its name and spell ID),
and only a consumable (`classID` 0, `Enum.ItemClass.Consumable`) counts. Measured in every client's item and spell
tables (wago.tools DB2, retail 12.1.5.70783, Mists Classic, TBC Anniversary and Classic Era branches, 2026-11-14):

| Use spell name | Items (retail) | What it restores (its auras) | Here |
|---|---|---|---|
| Food | 849 | health (aura 84 or 20) | food |
| Drink | 252 | mana (aura 85 or 21) | drink |
| Food & Drink | 84 | both (84 and 85) | both |
| Refreshment | 327 | Dragonflight on: buff food (aura 23, Well Fed); older: buff food or a mage's conjured food | a mage's conjured food only (by spell ID), both |
| Hearty Refreshment, Hearty Tier N Meal, Well Fed, ... | | buff food | never |
| Weak/Standard/Strong/Potent Alcohol | 284 | drunkenness | never |

- **Names, in every language.** The item's spell name is compared with the names of three spells the client names in
  its own language: `Food` (spell 433, Tough Jerky's), `Drink` (430, Refreshing Spring Water's) and `Food & Drink`
  (369166, Dragonflight's). 433 and 430 are in all four clients' tables; 369166 is only retail's (the classic clients
  have no Food & Drink items), and a spell the client lacks names nothing. Read once each with `C_Spell.GetSpellName`,
  which every client BetterBags runs on has, as it has `C_Item.GetItemSpell` (Blizzard's API documentation on the live,
  classic_era 1.15.9, classic_anniversary 2.5.6, classic 5.5.4 and forever 1.60.1 branches of wow-ui-source).
- **A mage's conjured food** is named `Refreshment`, like buff food, so it is known by its spell instead:
  `CONJURED_REFRESHMENT` (44166, 61828, 92726, 92738, 92798, 92801, 92804, 95197, 128701, 167152), every spell a
  "Conjured Mana ..." item casts in the four clients' tables. It restores both. Midnight's conjured food is named
  `Food`/`Drink` (spells 1269922, 1269919) and needs nothing.
- **The consumable check** keeps out a tankard you can equip (class 4, whose Drink spell would equip it on a right
  click), a quest item (class 12) and raw fish (class 7). The subclass is not checked: Classic Era files its food under
  subclass 0, not Food & Drink (5).
- **Buff food is never picked** (its Refreshment and Hearty spells are no plain Food or Drink): eating a feast's food
  for its regeneration is not what the bar is for. Old buff food named `Food` counts as food.
- **None of it can be eaten in combat**: every spell above has `SPELL_ATTR0_NOT_IN_COMBAT_ONLY_PEACEFUL` (Attributes_0
  bit 0x10000000, SpellMisc; TrinityCore SharedDefines.h names the bit). So the bar waits out combat (§2) at no cost.

## 2. What is picked, and when (`FoodDrink`)

- **The pick** (`Pick`, `fooddrink/Changed`): for food, then drink, every stack in the backpack's bags
  (`items:GetAllSlotInfo()[BACKPACK].itemsBySlotKey`) of that kind (both counts for both); the item with the highest
  item level (`itemInfo.itemLevel`), or the lowest with Pick set so; at the same item level, the lower item ID. Of that
  item, the smallest stack (eat a partial stack first), then the lowest bag and slot. Its count is every stack of it in
  the bags. Nothing of a kind: no pick.
- **When**: every committed read of the backpack (`items/RefreshBackpack/Done`: what the bags hold changed, a new item
  among them) and `fooddrink/OptionsChanged` (the rule). `fooddrink/Changed` is sent only when a pick's slot, item or
  count changed.
- **Combat** (asked): a read in combat changes nothing on the bar. The first one queues one read for when combat ends
  (`Async:AfterCombat`, PLAYER_REGEN_ENABLED, after the lockdown has ended), which reads the bags as they are then.
- An item read cold (`itemInfo.traits` nil: its data has not loaded, data-loader.md §19) is skipped; the read after its
  data arrives counts it.

## 3. The buttons (`NextFoodDrinkBar`)

- **BetterBags' own item buttons** (`ItemFrame:Create`, `frames/item.lua`): the same decoration, theme (a Sonata
  `ItemButton` element), quality border and item fit (`NextItemFit`) as a button in the bags, each made the first time
  its kind has a pick, and kept.
  Not secure buttons: the container item button is not a protected frame (`ItemButtonTemplate.xml` declares no
  `protected`, `ContainerFrameItemButtonTemplate` inherits none), and a right click on it uses the item through
  Blizzard's own click handler (`ContainerFrameItemButton_OnClick`), as in the bags.
- **Pointed at the pick's slot** (`itemProto:SetSlot`, which binds the holder, the interaction button and the
  decoration as `GetButton` does once for a slot's own button; Blizzard's `SetBagID` goes through an attribute so the bag
  ID taints nothing, ContainerFrame.lua) as soon as the pick changes; a kind with no pick hides at once, so nothing is
  left to click on a slot that changed. Drawn as a row of the item list is (`SetStaticItemFromData`, which never skips a
  draw: no upgrade arrow), never dimmed by a search in the bags, with the count of every stack.
- **No new-item glow** (asked: "eliminate new item glow just on these buttons"): a static draw clears it
  (`ClearFlashItem`, item-drawing.md). Blizzard's own `UpdateNewItem`, which the item button's first draw calls through
  `ResetVisuals`, lit it, looping, on food just bought. The bags' own buttons keep theirs.
- **Laid out** (`LayOut`) in a row or a column, each button the bags' item size (`style.ICON`, so Icon Scale on the Size
  tab, `next/ScalesChanged`) and their gap (`style.GAP`) apart, the card's `Pad` round them, on whole pixels of the card's
  grid (again when the UI scale or the display changes). Each button is sized before it is drawn: Masque sizes a skin to
  the button as the draw's `item/Updated` skins it. Held or coming out, the card is at the lift's scale, whose grid is not
  its own: a layout asked for then (a pick changing) waits until it is at rest (`layOutLater`, the card's `settle`), the
  card keeping the scale of its drag or flight.
- **Right click only** (asked): `RegisterForClicks("RightButtonUp")`, so a left click does nothing (Blizzard's left
  click picks the item up). A left click that eats is not possible on these buttons (asked 2026-11-14): Blizzard's
  `ContainerFrameItemButton_OnClick` uses an item on a left click only to target a spell at it, and
  `C_Container.UseContainerItem` is protected ("#protected ... Use the 'item' action type of SecureActionButtonTemplate
  or the /use slash command", warcraft.wiki.gg), so a use from BetterBags' own click is blocked; only a secure action
  button can. Its `OnReceiveDrag` is taken off (Blizzard's would place what the cursor holds in the slot).
  A drag on a button picks the bar up (its `OnDragStart` and `OnDragStop`, set with plain `SetScript`; its press and a
  drag's start make no context, patterns-taint.md; a drag's end, which no use follows, makes one for the drop).
- **A right click does what it does in the bags**: at a vendor it sells the item, at the bank it deposits it
  (`C_Container.UseContainerItem` is contextual). Left as the bags have it; see §7.
- **Nothing of a kind**: its button hides and the other closes up; with neither, the bar fades out (as the currency
  tracker does with nothing to show), and back in when some arrives.
- **Masque**: its own group, "Food & Drink" (`item.masqueGroup`, read by `integrations/masque.lua`'s skin).

## 4. The card (`NextScreenCard`, shared with the currency tracker)

The bar is the currency tracker's card (currency.md §5), not a lookalike (CLAUDE.md, "UI Consistency" 2): what the
tracker did as a card moved into `next/screencard.lua`, and both are kinds of it (`card:Extend`). The card: its frame,
fill, edge and frame art from the theme's `Currency.Tracker`, its faint card under the pointer with the background off,
its fades, which corner it grows from and keeping it on the screen, where it was left (saved, kept on the screen when the
screen changes), being picked up and dropped (`NextLift`: "Keep on Screen", or over the open backpack "Put Away", the
card fading a little), landing on whole pixels, flying into the backpack to be put away, hiding in combat (Hide in
Combat) and pet battles, and following BetterBags Next being switched off and on. Each kind says what is its own
(`Option`, `Saved`, `Save`, `Home`, `SetHomeLit`, `PutAwayPoint`, `OnPutAway`, `Wants`, `LayOut`, `StyleContent`,
`OnCardHidden`, `OnDeactivate`, `OpenSettings`).

- **Emerging** (`Emerge`, the bar only): Show Food & Drink Bar turned on while the backpack is open, the bar comes out
  of it: from the backpack's middle at the theme's `Drag.FlyScale` to where it was left at its scale, fading in
  (`NextLift:Land`), sparkles bursting (`Sparkles.Pop`), on the drag layer over the backpack (`NextLift:Raise`), as a card
  put away flies in, and back on the screen in its own strata once there (`rest`), as faded in as it is (a theme's fade
  in may be longer than the flight: Frost's). With the backpack closed it fades in
  where it was left, as the tracker's Show Tracker does. It cannot be picked up while it emerges; switched off as it
  emerges, it rests where it was left and hides.
- **Made after the picks were read** (the bags switched to BetterBags Next during a session), it shows them at once.
- **Put away** by dropping it on the open backpack: it flies in, and Show Food & Drink Bar turns off.

## 5. Options and the Food & Drink page

**Options** (`nextFoodDrink`, `DB:Get/SetNextFoodDrinkOption`; names checked against the defaults, choices against
their lists), each a catalog setting (`config/catalog.lua`, `foodDrinkOption`) that saves and sends
`fooddrink/OptionsChanged`:

| Setting | Option | Default |
|---|---|---|
| Show Food & Drink Bar (`nextFoodDrinkBar`) | the bar's `out` (`nextFoodDrinkBar`, `DB:Get/SetNextFoodDrinkBar`) | off |
| Pick (`nextFoodDrinkPick`: Highest Item Level / Lowest Item Level) | `pick` | highest |
| Bar Layout (`nextFoodDrinkLayout`: Row / Column) | `layout` | row |
| Bar Grows (`nextFoodDrinkGrow`: Left / Right in a row, Up / Down in a column) | `growX`, `growY` | left, down |
| Bar Scale (`nextFoodDrinkScale`, 50% to 200%, steps of 5) | `scale` | 100 |
| Bar Background (`nextFoodDrinkBackground`) | `background` | on |
| Hide Bar in Combat (`nextFoodDrinkHideInCombat`) | `hideInCombat` | on (nothing on it can be used in combat, §1) |

**The Food & Drink page** (`fooddrink`, BetterBags group after Currencies, BetterBags Next only, every client): one tab,
Display. A right click on the bar's card opens it.

## 6. Coverage

- `spec/fooddrink_spec.lua`: what counts (Food, Drink, Food & Drink, a mage's Refreshment; buff food, alcohol, a tankard,
  raw fish and an item read cold do not; names read in the client's language), the pick (highest and lowest, ties, the
  smallest stack, the count of every stack, both kinds), when it is sent (only on a change), combat (nothing in combat,
  one read after, the bags as they are then).
- `spec/next/screencard_spec.lua`: the card as a kind of its own (placing, growing, keeping on screen, dropping and
  remembering, putting away, emerging, combat and pet battles).
- `spec/next/fooddrinkbar_spec.lua`: the bar (its buttons BetterBags' item buttons pointed at the picks, right click
  only, no drop into the slot, a drag picking the bar up, the count, a kind with nothing hidden, Masque's group, the
  options, emerging from the open backpack, put away by a drop on the backpack, the settings page from a right click), and
  what the bug review found (§8): the picks shown as it is made, Icon Scale, each draw at the button's size, a layout
  while it comes out or is held waiting for rest without touching its scale, a button hidden at once while held, the UI
  scale.
- `spec/frames/item_classic_spec.lua`: `SetSlot` (Classic's parent ID, retail's `Initialize`).
- `spec/next/bag_spec.lua`, `spec/core/init_spec.lua`, `spec/integrations/masque_spec.lua`, `spec/database_spec.lua`,
  `spec/config/settings_effects_spec.lua`, `spec/next/settings/content_spec.lua`, `spec/integration/next_settings_spec.lua`:
  the backpack makes the bar, start-up starts FoodDrink, Masque's group, the options, the page.
- The currency tracker's specs (`spec/next/currency_spec.lua`) pass unchanged over the shared card.
- Each fix of §8 was undone on its own and its test failed (10 mutations, then 9 by the second review, each caught).

## 7. Left as it is

- **A right click is the bags' right click** (§3): at a vendor, the bank, a mailbox or a trade it does there what it does
  on the item in the bags. Not guarded: the bags do the same, and a guard would be a second behavior for the same button.
- **Between a stack moving and the next read** of the bags the button still points at the slot it had, as a button in
  the bags does. Nothing can be eaten in combat (§1), and a read after combat moves it.
- **A pick changing while the bar comes out of the backpack** (at most the flight, `Time.Land`): the button points at
  the new pick at once and is drawn with it once the bar lands; a right click on it then eats the new pick.

## 8. Bug review

The first review reproduced six bugs, each fixed test-first: the bar did not follow Icon Scale until its next pick; with
Masque, its buttons were drawn (and skinned) before they were sized; made after the picks were read (a switch to
BetterBags Next mid-session) it stayed hidden; a pick changing while it was held or coming out laid it out on the lift's
grid, sizes off whole pixels, kept after landing; it came out of the backpack under it (its own strata under the
backpack's HIGH); and a UI scale change left its buttons on the old grid. It found the currency tracker's move onto the
shared card, the picks and the combat wait sound.

The second review, of those fixes alone, found them sound, and three things more: a theme's longer fade in (Frost's) cut
short as the bar landed from the backpack (fixed test-first: `rest` keeps its alpha); the bar's own screen-change handler
placing it again as the card's already does (removed: it only lays out now); and a layout the card ran on a cancelled
drag, which nothing could see (removed). It also found two specs that failed run alone, because the bar, made once per
spec run, listened to whichever test's events came first (`small_spec`'s count of Icon Scale listeners, `chain_spec`'s one
handler per event): `UseNextFoodDrink` makes the next backpack make the bar again, and `chain_spec` keeps every handler.

Left, as noted by the reviews and not built for:
- Hovering a button clears the item's new-item glow in the bags (`ContainerFrameItemButtonMixin:OnUpdate` calls
  `C_NewItems.RemoveNewItem` for its slot), as hovering it in the bags does.
- The profiler names the card's methods `NextScreenCardFrame.*` where it named the tracker's `NextCurrencyTrackerFrame.*`:
  captures from before the change read differently.

