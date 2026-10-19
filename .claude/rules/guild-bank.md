# The Guild Bank (`data/guildbank.lua`, `next/guildbank.lua`, `next/guildbutton.lua`)

BetterBags reads the guild bank with the same data engine as the bags (categories, search, virtual
stacks, sort, item level, upgrade arrows) and, with BetterBags Next on, shows it in a panel that
stands in for Blizzard's guild bank frame: a third companion of the backpack on the left, beside
the bank and the vendor (next.md §12). With the classic bags nothing changes: Blizzard's frame shows
the guild bank and BetterBags reads none of it.

## 1. A third kind of bag (`core/constants.lua`)

- `const.BAG_KIND.GUILD = 2`. Every loop over the kinds in the data engine goes over `const.BAG_KIND`
  (skipping `UNDEFINED`), as `core/database.lua` already did, so caches, timers, first-load flags,
  draw generations and the shared search index cover the guild kind.
- **Containers.** A guild bank tab is not a bag, so it has no bag index: each tab gets a container
  id counted from the first multiple of 1000 above every `Enum.BagIndex` value the client declares
  (1000 on every client), `MAX_GUILDBANK_TABS` of them (8; 6 on TBC Anniversary).
  `GUILD_BANK_BAGS[container] = tab`, `GUILD_BANK_TAB_CONTAINER[tab] = container`,
  `GUILD_BANK_BAGS_LIST` in tab order; 98 slots each (`GUILD_BANK_SLOTS`, Blizzard's
  `MAX_GUILDBANK_SLOTS_PER_TAB`, local to its guild bank UI). A guild slot's key is
  `"<container>_<slot>"` ("1002_7"), so every slot key reader works and none collides with a bag.
  `GUILD_BANK_ALL_TAB = 1` is the combined view's tab id (never a container).
- **Which clients.** `addon.hasGuildBank` is `GuildBankFrame_LoadUI ~= nil`: Blizzard defines it on
  retail and WoW: Forever (`Blizzard_GuildBankUI_Bootstrap.lua`) and in the TBC, Wrath, Cata and
  Mists UIParent; never on Classic Era, whose game type loads none of them.
- **Settings.** Every per-bag profile default the bank has is copied for the guild kind (no groups:
  `groups`, `groupCounter`, `categoryToGroup` start empty and `groupsEnabled` is false), and
  `showGuildBankTabs` (false) keeps whether a tab shows by itself (§4). The settings window has a
  **Guild Bank** section after the Bank's on clients with a guild bank (`config/config.lua`'s list of
  bag types), every setting the guild kind's; its window size settings do nothing, as for every
  BetterBags Next panel (next.md §9).

## 2. The guild bank as a data source (`GuildBank`)

`data/guildbank.lua` reads and asks; it draws nothing. Initialized with the data models and enabled
with the rest (`core/init.lua`, initialization.md). On a client without a guild bank it registers
nothing.

- **The visit** is the guild banker interaction (`PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`_HIDE`,
  `Enum.PlayerInteractionType.GuildBanker`, which retail's player interaction manager answers; a
  WoWInterface thread reports `GUILDBANKFRAME_OPENED` not firing on retail since 10.0, while
  Classic's UIParent still handles it).
  `addon.atGuildBank`; messages `guildbank/Opened` and `guildbank/Closed`. Closing forgets what was
  loaded.
- **Tabs** (`Tabs`, `TabInfo`): `GetGuildBankTabInfo`, unnamed tabs named as Blizzard names them
  (`GUILDBANK_TAB_NUMBER`), with `viewable`, `canDeposit`, `numWithdrawals` (0: none, -1: no limit)
  and `remainingWithdrawals`.
- **Loading** (`Load`, `LoadTab`). A tab's contents come from the server. Blizzard's tab click makes
  the tab current and queries it (`GuildBankTabMixin:OnClick`: `SetCurrentGuildBankTab`, then
  `QueryGuildBankTab`), and the answer, `GUILDBANKBAGSLOTS_CHANGED`, names no tab. So tabs load one
  at a time, the current tab first, each made current and queried; each answer is the tab last
  queried (`guildbank/TabLoaded`), or after `QUERY_TIMEOUT` (2 s) the tab counts as loaded anyway.
  The player's current tab is made current again at the end. Tabs the player cannot view are never
  queried. `LoadTab` queries one tab (a tab chosen in the panel), first during a `Load`, and leaves
  it current. **The client keeps every tab it received:** Syndicator (Baganator's scanner) reads all
  tabs with `GetGuildBankItemLink(tab, slot)` on every `GUILDBANKBAGSLOTS_CHANGED`, whichever is
  current, which is what the combined view relies on.
- **Changes**: `GUILDBANKBAGSLOTS_CHANGED` outside a load and `GUILDBANK_ITEM_LOCK_CHANGED` send
  `guildbank/Changed`; `GUILDBANK_UPDATE_TABS` `guildbank/TabsChanged`;
  `GUILDBANK_UPDATE_MONEY`/`_WITHDRAWMONEY` `guildbank/MoneyChanged`. Nothing is sent while closed.
- **Acting on items.** Blizzard's guild bank item buttons act on `GetCurrentGuildBankTab()` only
  (`GuildBankItemButtonMixin`), so every action makes the item's own tab current first: `Pickup`
  (`PickupGuildBankItem`), `Withdraw` (`AutoStoreGuildBankItem`), `Split` (`SplitGuildBankItem`).
  `PlaceCursorItem(tab?)` puts the item held into the first free slot of the tab asked for, else the
  current tab, else any other, only one the player may deposit in and that has loaded (a tab never
  received reads as empty, and a pickup on a slot that holds an item swaps them); it returns
  `"placed"`, `"full"`, `"loading"` or `"ignored"`, with Blizzard's red error text for the first two
  failures. `DepositSlots(slots, tab)` deposits bag slots into a tab made current: a bag item used at
  the guild bank goes into the current tab (`ContainerFrameItemButton_OnClick`'s right click,
  `C_Container.UseContainerItem`). `WithdrawItems(list)`.
- **Gold and tabs** use Blizzard's own dialogs, defined globally (`GameDialogDefs.lua` on every
  client): `GUILDBANK_DEPOSIT`, `GUILDBANK_WITHDRAW` (only when `CanWithdrawGuildBankMoney()`),
  `CONFIRM_BUY_GUILDBANK_TAB` (the guild leader, while fewer than `MAX_BUY_GUILDBANK_TABS` are bought;
  the dialog reads the cost itself). `Close` is `CloseGuildBankFrame`.

## 3. Reading it (`data/items.lua`, `data/refresh.lua`, `data/loader.lua`, `data/tooltip.lua`)

- **Phase 1** reads the tabs received this visit that the player can view (`LoadedContainers`).
- **Harvest** (`HarvestGuildBank`): every slot of those tabs. A slot whose read (`GuildBank:ReadSlot`:
  link, count, lock, icon, filter, quality) is unchanged keeps its committed item, unless that item
  was read cold. The lock is part of it: another player moving the item locks it.
- **A guild slot has no item location**, so `AttachGuildBankItemInfo` builds the item from its read
  and what the item is (`ReadItemProperties`, the same as a bag slot's: `GetItemInfo`, with the
  categorized fields from `GetItemInfoInstant`, never cold). No GUID, quest data, new-item flag (so
  no Recent Items), current transmog or equipment set. Never bound (the guild bank takes no bound
  item): its binding comes from its bind type (`binding.FromBindType`). Its current item level is its
  link's (`GetDetailedItemLevelInfo`), its inventory type `GetItemInventoryTypeByID`. A bag slot and
  a guild slot build their `itemInfo` with the same helpers (`ItemInfoOf`, `TransmogInfoOf`,
  `FinishItemData`), so they hold the same fields.
- **Tooltip text** (`TooltipScanner:GetGuildBankItemText`): `C_TooltipInfo.GetGuildBankItem` on
  retail, the scan tooltip's `SetGuildBankItem` on Classic, cached by link (no GUID) under
  `"guild:" .. link`, a sparse retail tooltip resolving as a bag item's does (tooltip-scanning.md); a
  resolution recalculates the guild bank while it is open.
- **A recalculation** (`derive`, refresh-scheduler.md §10) reads no slot (`RederiveGuildBank`): the
  committed items with their tooltip text refreshed, one read cold read again.
- **Free space** is counted per tab the player may deposit in, from the slots read (a tab has no
  client free-slot count), each tab its own free-space entry named after it.
- **The shared search index** holds the guild bank's items beside the bags' (search-indexing.md §4);
  `ClearGuildBankCache` (the visit's end) drops them on the next sweep of any kind.
- `items/RefreshGuildBank/Done`, which `core/init.lua` hands to `addon.Bags.GuildBank:Draw` when
  there is one (BetterBags Next makes it, maybe after `OnEnable`, so it is looked up per read).
- A guild read whose visit ended while it waited after its harvest commits nothing.
- **The refresh scheduler** reads it as it reads a bank open (refresh-scheduler.md §11):
  `guildbank/Opened` shows `addon.Bags.GuildBank` at once (nothing without one: the classic bags) and
  loads the tabs (`GuildBank:Load`) only once the panel has finished showing, or after
  `GUILD_SHOW_TIMEOUT` (1 s). Each tab loaded is read once its items' data has loaded
  (`ItemLoader:PrimeGuildBank`: `Item:CreateFromItemLink` for each item, in one
  `ContinuableContainer`), the first read of a visit with a fresh layout; after `GUILD_PRIME_TIMEOUT`
  (2 s) it is read anyway and again when the data arrives. `guildbank/Changed` reads the loaded tabs
  again (primed), `guildbank/TabsChanged` reads, `guildbank/Closed` forgets the guild bank. Nothing
  happens for a visit that has ended. `RefreshRequest.guild` sweeps the guild bank after the bank and
  before the backpack, only while it is open and its panel has shown; a wipe sweeps it;
  `bags/Rederive` naming no kind recalculates every kind. `guildLoad` says why a read ran
  (`"primed"`, `"timeout"`), for profiler traces.

## 4. Two views

- **All Tabs** (`GUILD_BANK_ALL_TAB`, the Category view): every tab's items in the categories the
  bags use, each tab's free slots its own Free Space entry, the same item stacked across tabs.
- **A tab by itself** (the Show Bags view, `SECTION_ALL_BAGS`, as the bank's Bank Tabs mode): that
  tab's slots in order, empty slots in place, one headerless section named `#<tab>: <name>`, no
  virtual stacks. The panel switches the guild kind's view between the two
  (`database:SetBagView(GUILD, ...)`) and recalculates (`bags/Rederive { guild, resetLayout }`).

## 5. BetterBags Next's guild bank (`NextGuildBank`, `NextGuildButton`)

**Taking over Blizzard's guild bank frame.** It is load on demand. Blizzard's `ShowGuildBankFrame`
(retail and Forever; the Classic UIParent's `GUILDBANKFRAME_OPENED` handler is the same) calls
`ShowUIPanel(GuildBankFrame)`, then `CloseGuildBankFrame()` at once when the frame is not visible,
and the frame's `OnHide` (`GuildBankFrameMixin:OnHide`) ends the visit too. So the vendor's way (the
frame under the hidden frame, next.md §10a) would end every visit. `TakeOver` instead hooks
`ShowUIPanel` securely (once); when it shows `GuildBankFrame` while Next is in use, the frame goes
under a tiny shown frame (`SetScale(0.001)`: visible to Blizzard's check, never seen), its `OnHide`
is taken off, and a frame later it goes under the hidden frame. Bagnon does the same
(`core/features/uiOverrides.lua`, its comment blaming Blizzard's 12.1 guild bank). Its `Hide` is
hooked once to end the visit a frame later, as its `OnHide` did, when something hides it during a
visit (another panel on the left, Escape through `CloseWindows`). `GiveBack` puts it back under
`UIParent` with its `OnHide` when Next is switched off (refused at the guild bank). With the classic
bags the hooks do nothing.

**The panel** (`next/guildbank.lua`): a `NextPanel` on the left, `kind = GUILD`, the backpack's
companion (it chains as the bank does), in the guild's green (`style.Color.GuildWash`, the guild
tabs' accent `style.Color.Guild`).
- **Title:** the guild's name (`GetGuildInfo("player")`), or the tab shown by itself.
- **Header** (from the screen edge): close; settings; deposit gold; withdraw gold (disabled for a
  member who may not; its tooltip says how much they may take: `GetGuildBankWithdrawMoney`, -1 the
  whole balance).
- **Tabs:** All Tabs, then every tab the player can view (its icon, the guild's accent; the tooltip
  gives Blizzard's access text, `GUILDBANK_TAB_FULL_ACCESS`/`DEPOSIT_ONLY`/`WITHDRAW_ONLY`/`LOCKED`,
  and the stacks left to take today), then "+" for the guild leader. A left click shows All Tabs or a
  tab by itself, which is made current (where deposits go, as on Blizzard's frame) and queried again
  (`LoadTab`); "+" buys a tab; a right click renames a tab for a member who may edit tabs
  (`CanEditGuildBankTabInfo`), keeping its icon (`SetGuildBankTabInfo`). The view is kept
  (`showGuildBankTabs`) and restored on open: the guild bank's current tab, else the first the player
  can view. A tab shown that is gone or closed to the player goes back to All Tabs.
- **Footer:** free slots; the guild's gold.
- **Search:** the guild kind's in-bag box (`searchBox:CreateBox(GUILD)`, "Search Guild Bank"); typing
  searches only the guild bank (`SearchBox:BagOfKind`).
- **Drops:** an item dropped on the panel goes to the tab shown by itself, else the current tab
  (`GuildBank:PlaceCursorItem`); a free slot takes it too (§5, buttons).
- **Closing:** every way ends the visit once: the close button at once (`CloseGuildBankFrame`);
  Escape and Blizzard hiding its frame a frame later (`EndVisitLater`). The visit's end
  (`guildbank/Closed`) closes Blizzard's three guild bank dialogs, as its `OnHide` did, and slides the
  panel out, letting go of its buttons once out.

**Guild bank buttons** (`next/guildbutton.lua`). A guild slot cannot be one of the item buttons made
at boot: they are `ContainerFrameItemButtonTemplate`s whose Blizzard methods read their bag and slot
(cooldowns, new-item flags, junk, clicks, `UseContainerItem`). A guild slot is Blizzard's own guild
bank item button, made as Blizzard makes it: `CreateFrame("ItemButton")` on retail and Forever,
`ItemButtonTemplate` on Classic (`Blizzard_GuildBankUI` Mainline and TBC XML). One per slot key until
released, pooled, announced once (`guild/NewButton`) and registered with Sonata as an `ItemButton`
element (its styler guards the parts a plain item button lacks).
- **Drawn** from ItemData as a bag button is: `SetItemButtonTexture`, `SetItemButtonCount` (a
  virtual stack's total), `SetItemButtonDesaturated` while locked, `SetItemButtonQuality(button,
  quality, link)` (Blizzard's guild bank update), then the theme's quality (`DrawItemQuality`) or
  BetterBags' glow by the guild bank's glow setting (`ItemFrame:DrawQualityGlowFor(GUILD, ...)`, the
  item buttons' own glow, item-drawing.md §5); item level as bag buttons (`NumberFontNormal`, bottom
  left, the guild kind's options); Blizzard's upgrade arrow (`bags-greenarrow`, as
  `ContainerFrameItemButtonTemplate` defines it); the search with `SetMatchesSearch` where the item
  button has it, else Classic's `searchOverlay`. An empty slot draws the bags' empty slot art
  (retail's `UI-Bag-Components` slot background, Classic's `UI-Backpack-EmptySlot`).
- **Clicks** are `GuildBankItemButtonMixin`'s on the item's own tab: a modified click Blizzard
  handles goes to it (`HandleModifiedItemClick`), Shift opens Blizzard's stack split (retail's
  `StackSplitFrame:OpenStackSplitFrame`, Classic's global `OpenStackSplitFrame`; neither client has
  the other) and `SplitStack` splits from the item's tab, gold on the cursor is deposited
  (`"money"`) or put back (`"guildbankmoney"`), a right click withdraws, a left click picks up; drag
  start and receive drag pick up; the tooltip is `GameTooltip:SetGuildBankItem`; hiding closes the
  stack split it opened.
- **The tooltip's return differs by client.** On retail and WoW: Forever `GameTooltip` inherits
  `GameTooltipDataMixin` (`CreateFromMixins(TooltipDataHandlerMixin)`, `Mainline/GameTooltip.lua`), so
  `SetGuildBankItem` is a tooltip data accessor that returns only `true` (shown) or `false` (no data,
  hidden), from `TooltipDataHandlerMixin:InternalProcessInfo`; Blizzard's Mainline button reads
  nothing from it. On Classic `GameTooltipMixin` has no data handler, so it is the native method,
  which returns a caged battle pet's values, and Blizzard's TBC button shows the pet's own tooltip
  (`BattlePetToolTip_Show`) when the species is above 0. The button does each client's.
  **Failure mode (fixed):** it used the TBC pattern everywhere, and on retail compared `true` with 0
  on every hover (`attempt to compare number with boolean`). The spec mock returned nothing, and the
  battle pet test installed Classic's return while the client was retail; the mock now follows
  retail's accessor, and Classic's return is installed only by Classic tests. A free slot
  takes the item held: the slot itself (a tab by itself), or the tab's first free slot (All Tabs).
- The canvas takes these buttons through `NextContent:SetButtonSource`, so `Bind`'s sections, order,
  gaps and free space are the bags'.

**Sections in and out** (next.md §7; `NextDrag:CanMoveBetween`, `CanDropOnBody`, the guild panel's
`DepositTab`, `CanDepositIn`, `Deposit`, `Withdraw`):
- At the guild bank, a backpack section dropped on the guild bank's body goes into its deposit tab
  (the tab shown by itself, else the current tab), one dropped on a guild tab into that tab; only
  tabs the player may deposit in are targets (not All Tabs, nor "+"). Every item and every pile its
  virtual stack hides, in the backpack's bags, bound items left out.
- **Into a tab the player cannot withdraw from, it asks first**: those items cannot be taken back.
  The section lands back meanwhile.
- A guild section dropped on the backpack is withdrawn; on a backpack group tab it is also assigned
  to that group. A guild section header's right click withdraws it (the bank's moves it to the open
  window; the guild bank's open window is the bags).
- The guild bank's own sections reorder as any panel's (their order saved for the guild kind); its
  own tabs are no targets.
- **Not added:** a guild flow to the classic header's Move Categories (`util/movementflow.lua`). A
  right click there could put a whole category where the player cannot take it back; the drag is the
  deliberate act, and it asks.

**Wiring.** `BagSystem` makes the guild bank with BetterBags Next on clients with a guild bank, takes
over and gives back Blizzard's frame with the design, lists it for Escape, and refuses to switch at
the guild bank ("Close the guild bank to switch bags."). `addon.Bags.GuildBank`;
`addon:GetBagFromKind(GUILD)` and `GetBagFromBagID(container)` find it (the latter no longer indexes
the Warbank's table on Classic, which has none). ConsolePort's cursor reaches it. Masque skins its
buttons in a Guild Bank group of their own, added once, taken out under a theme without Masque and
added back under one with it.

## 6. Taint

What BetterBags does to Blizzard's guild bank code: secure hooks on `ShowUIPanel` and on
`GuildBankFrame:Hide` (they run after Blizzard's code and leave its execution secure); `SetParent` and
`SetScript("OnHide", nil)` on `GuildBankFrame`, which is not protected (BetterBags already reparents
`BankFrame` and clears its `OnShow`, camelot-forever.md §10); Blizzard's three dialogs shown from its
buttons, whose accepts call unprotected functions. No guild bank function it calls has generated
documentation or a restriction on its warcraft.wiki.gg page (checked: `AutoStoreGuildBankItem`,
`BuyGuildBankTab`, `PickupGuildBankItem`, `SplitGuildBankItem`, `SetCurrentGuildBankTab`,
`QueryGuildBankTab`, `DepositGuildBankMoney`, `WithdrawGuildBankMoney`, `SetGuildBankTabInfo`,
`CloseGuildBankFrame`), unlike the bank's tab purchase (`C_Bank.PurchaseBankTab`,
camelot-forever.md §10). Deposits by drag call
`C_Container.UseContainerItem` from the drop's release, a hardware event, as the bank's section moves
do (next.md §7).

## 7. Not verified in game

None of it has been seen in a client. Per data-driven.md, the first visit should be captured:
- **A profiler capture** of opening the guild bank, switching tabs and closing:
  `GuildBank.Load`/`TabLoaded` (each tab's `"answered"` or `"timeout"`), `Refresh._GuildBankShown`,
  `Refresh._RunUnit` with `guildLoad`, `Items.HarvestGuildBank`, `NextGuildBankPanel.Draw`. It shows
  whether every tab answers before the timeout and what a read of 8 x 98 slots costs.
- **The render recorder** (render-recorder.md) on the guild bank panel, to check the buttons' size
  and place.
- **Taint:** `/console taintLog 1`, open the guild bank, deposit and withdraw items (click, right
  click, drag, a section both ways), split a stack, deposit and withdraw gold, buy or rename a tab if
  allowed, close with the button, Escape and by walking away; then use a consumable from the bags in
  and out of combat. `Logs/taint.log` should have no BetterBags entries blocking an action.
- Whether the server answers a query for every tab with `GUILDBANKBAGSLOTS_CHANGED` (Syndicator relies
  on it), and whether Blizzard's tab item buttons, under the hidden frame, ever show.

## 8. Not done

- The guild bank's item and money logs and its tab info text (Blizzard's frame has Log, Money Log and
  Info tabs).
- Changing a tab's icon (renaming keeps it).
- Dimming bag items the guild bank would refuse (issue #768): Blizzard has no item context for the
  guild bank (`ItemButtonUtil.ItemContextEnum` stops at `BankDepositing`, while its own `BankPanel`
  shows), so it would be a rule of BetterBags' own.
- Two tabs with the same name share one Free Space entry in All Tabs (entries are keyed by name).

## 9. Coverage

`spec/core/constants_spec.lua` ("guild bank"), `spec/database_spec.lua` (`showGuildBankTabs`),
`spec/guildbank_spec.lua` (the data source: visits, tabs, loading and its timeout, changes, actions on
the item's tab, placing the cursor's item, moving many items, gold and tabs),
`spec/guildbank_pipeline_spec.lua` (reading, kept slots, cold reads, binding, derive, both views,
stacking across tabs, empty slots in place, the shared index, an ended read), `spec/tooltip_spec.lua`
("guild bank items"), `spec/loader_spec.lua` (`PrimeGuildBank`), `spec/refresh_spec.lua` ("the guild
bank"), `spec/core/init_spec.lua`, `spec/next/guildbutton_spec.lua`, `spec/next/guildbank_spec.lua`,
`spec/next/content_spec.lua` ("a source of buttons of its own"), `spec/next/drag_spec.lua` ("the guild
bank"), `spec/frames/search_spec.lua` ("the guild bank"), `spec/bagsystem_spec.lua`,
`spec/integrations/consoleport_spec.lua`, `spec/integrations/masque_spec.lua` ("guild bank buttons"),
`spec/config/config_redraw_spec.lua` ("the guild bank's settings"), `spec/frames/item_classic_spec.lua`
(`DrawQualityGlowFor`), and on the whole addon `spec/integration/guild_bank_spec.lua` (a visit from the
interaction to items drawn, closing, the switch refused, the classic bags left alone). The mocks gained
Blizzard's guild bank functions (`ResetMockGuildBank`), the item button's parts (the `ItemButton`
intrinsic and `ItemButtonTemplate`), `ShowUIPanel`/`HideUIPanel`, the stack split frame's `Hide` and
the full `Enum.PlayerInteractionType`.
