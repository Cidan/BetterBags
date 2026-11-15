---
paths:
  - "core/hooks.lua"
  - "core/database.lua"
  - "config/catalog.lua"
  - "next/settings/content.lua"
  - "next/chain.lua"
  - "spec/core/interaction_bags_spec.lua"
  - "spec/core/interaction_refresh_spec.lua"
  - "spec/config/catalog_spec.lua"
  - "spec/next/settings/content_spec.lua"
  - "spec/next/chain_spec.lua"
---
# What the Backpack Does at an Interaction

Each interaction BetterBags follows opens the backpack with its window and closes it again with it.
The player picks, for each one, whether it does: General > Interactions in the settings window.

Asked: #471 ("a toggle added to turn off bags closing when leaving an NPC (shop/bank/AH, etc.)") and
#755, closed as its duplicate ("No auto open and No auto close on certain interactions": open at a
vendor, the auction house and the bank but not at a trade; close after the auction house and the bank
but not after a trade or a vendor). Decided with the player (2026-11-14): one dropdown per interaction
with three choices, and "we keep current behavior as the default".

## 1. The choices

| Choice | Saved | The window opens | The window closes |
|---|---|---|---|
| Open and Close (default) | `"openClose"` | the backpack opens | the backpack closes, whoever opened it |
| Open Only | `"open"` | the backpack opens | the backpack stays as it is |
| Leave Alone | `"none"` | the backpack stays as it is | the backpack stays as it is |

Open and Close is what the backpack always did: it closes after the window even when the player had
opened it before. Blizzard's own bags close only the bags the window opened (`OpenAllBags(frame)`
records the frame only when no bag was open, `CloseAllBags(frame)` does nothing for another frame;
`Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`); that rule was offered as the default and turned
down, and is not one of the choices.

**One window handing over to the next in the same frame** (walking from a mailbox to a vendor): the
closing window's choice closes the backpack, and only a next window that opens it keeps it open, in
either order of the two events (`addon.OnUpdate` lets a pending open win over a pending close). So an
Open and Close window handing over to a Leave Alone one closes the backpack, as it would a frame apart;
before the setting every next window opened it, so it always stayed open. Found by the bug review;
kept on purpose, since the result then does not depend on when the client sends the two events.

Escape is not an interaction closing: `addon:CloseSpecialWindows` (Escape, the panel manager closing
everything) still closes the backpack whatever the choice, as Blizzard's `CloseAllWindows` closes the
bags with every other window.

## 2. Where it lives

- **Saved:** `profile.interactionBags`, one value per interaction by its name in
  `Enum.PlayerInteractionType` (`TradePartner`, `Banker`, `AccountBanker`, `Merchant`, `MailInfo`,
  `Auctioneer`, `GuildBanker`, `VoidStorageBanker`, `ScrappingMachine`, `ItemUpgrade`), every one
  `"openClose"` in `const.DATABASE_DEFAULTS`. Names, not the enum's numbers: the numbers are the
  client's.
- **Read and written:** `DB:GetInteractionBags(name)` and `DB:SetInteractionBags(name, value)`
  (`core/database.lua`). Both raise on a name the defaults do not have; the setter raises on any value
  but the three.
- **The interactions followed:** `interactionEvents` (`core/hooks.lua`) maps each interaction type to
  its name. The Warband banker is followed only where the client has a Warband bank (`addon.hasWarbank`).
  Blizzard also registers `Enum.PlayerInteractionType.CharacterBanker` for its bank frame
  (`BankFrame.lua`); BetterBags has never followed it, and this setting does not either.
- **Applied:** `addon.OpenInteractionWindow` (`PLAYER_INTERACTION_MANAGER_FRAME_SHOW`) and
  `addon.CloseInteractionWindow` (`_HIDE`) read the interaction's choice each time, so a choice changed
  during a visit applies as that window closes.
  - Opening, unless Leave Alone: `backpackShouldOpen` and `bags/OpenClose` a frame later, as before;
    `addon.OnUpdate` shows the backpack and recalculates it for the window.
  - Opening, Leave Alone: the same recalculation (`bags/Rederive`, `interactionRecalculation`) is sent
    at once, in the event, since `OnUpdate` does not run: an already open backpack dims what the window
    cannot take, and the bank unmerges at a shop. A backpack the player opens during the visit is
    recalculated again as it opens (`OnUpdate` while `atInteracting`).
  - Closing: the recalculation is sent for every choice (it clears the grey-out, the junk coin,
    item-drawing.md, and stack unmerging from a backpack that stays open), then only Open and Close
    sets `backpackShouldClose` and sends `bags/OpenClose` later.
  - `atInteracting`, `atWarbank` and `atAuctionHouse` are set and cleared for every choice.
- **The setting:** ten dropdowns in the settings catalog (`interactionOption`, `config/catalog.lua`:
  `interactionTrade`, `interactionBank`, `interactionWarbank`, `interactionVendor`, `interactionMail`,
  `interactionAuctionHouse`, `interactionGuildBank`, `interactionVoidStorage`, `interactionScrapper`,
  `interactionItemUpgrade`), items Open and Close, Open Only, Leave Alone. Choosing sends nothing: the
  hooks read it at the next window.
- **Shown:** the General page's Interactions section (`next/settings/content.lua`, next-settings.md §4),
  for both designs, a row only for an interaction the client has: the Warband bank where
  `addon.hasWarbank`; the guild bank where `addon.hasGuildBank`; Void Storage on Cataclysm and Mists
  Classic (warcraft.wiki.gg: added in patch 4.3.0, removed from retail in 11.2.0; no Void Storage UI in
  retail's source); the Scrapper on retail (added in 8.0.1); Item Upgrade on retail and Mists Classic
  (`Blizzard_ItemUpgradeUI` loads on the mainline and mists game types). WoW: Forever runs retail's
  code (`addon.isRetail`) in Vanilla's world (camelot-forever.md), so it shows none of the Warband bank,
  the Scrapper, Item Upgrade and Void Storage.

## 3. BetterBags Next's companions

A companion chained to the backpack (layout "right") that opens while the backpack is closed waits out
of sight for the backpack, which its interaction opens a frame later (next-chain.md §12a). A companion
whose interactions all leave the backpack alone opens at once from its own edge instead of waiting
`style.Chain.AnchorWait` for a backpack that is not coming (`chain:WaitsForAnchor`, `opensBackpack`).
Each companion names its interactions (`NextPanelOptions.interactions`): the vendor `Merchant`, the guild
bank `GuildBanker`, the bank `Banker` and, where the client has a Warband bank, `AccountBanker`.

- **Left as it is:** the bank waits while either of its interactions opens the backpack, since which
  banker opened it is not asked. With Bank and Warband Bank set differently, the bank chained right waits
  up to 0.25 s at the banker left alone, then comes in from its own edge, as it always did when the
  backpack did not open.
- A backpack that stays open after its companion closes goes home once the companion has gone
  (next-chain.md §12a: `chain:Holds`, then the slide-out's chain update).

## 4. Measured and inferred

Nothing here was captured in game. The refresh work at an interaction is the same in kind as before
(one recalculation as it opens, one as it closes); for Leave Alone the opening one is sent a frame
earlier, in the event. That a recalculation sent in the hide event clears the junk coin of a backpack
left open is item-drawing.md's (Phase 6 runs after the sweep's yield, from the code, not yet seen in a
capture).

Not built for (the bug review, unreproduced): the closing recalculation's grey-out reads `addon.atBank`,
which only `BANKFRAME_CLOSED` clears (`data/refresh.lua`), not the banker interaction's hide. A backpack
left open after the bank would keep the Warband's grey-out only if `BANKFRAME_CLOSED` came more than a
frame after the hide; no capture has shown that order.

## 5. Coverage

`spec/core/interaction_bags_spec.lua` (every interaction opening and closing by default, one the player
opened first included; Open Only; Leave Alone with the backpack open and closed, its recalculations, the
Auction House flag, a backpack opened during the visit; each interaction's own choice for all ten; a
choice changed during a visit; one window handing over to the next in the same frame, in both orders;
an interaction not followed), `spec/core/interaction_refresh_spec.lua` (the recalculations),
`spec/database_spec.lua` ("GetInteractionBags / SetInteractionBags"), `spec/core/constants_spec.lua`
(the default), `spec/config/catalog_spec.lua` (the ten dropdowns), `spec/next/settings/content_spec.lua`
(the section, and the rows each client shows), `spec/next/chain_spec.lua` (a companion left alone comes
in at once; the bank waits while the banker or the Warband banker opens the backpack), and the
companions' interactions in `spec/next/{bank,vendor,guildbank}_spec.lua`. Mutation-tested: 15 mutations
of the hooks, the chain, the bank's interactions, the rows' clients, the choices, the database check and
the default, all caught; the 15th (the bank reading only its Warband banker) survived the first specs and
led to the banker case of the bank's wait.
