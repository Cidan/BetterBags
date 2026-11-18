---
paths:
  - "data/guildbank.lua"
  - "next/guildbank.lua"
  - "next/guildbutton.lua"
  - "spec/guildbank*_spec.lua"
  - "spec/next/guildbank_spec.lua"
  - "spec/next/guildbutton_spec.lua"
  - "spec/integration/guild_bank_spec.lua"
---
# The Guild Bank (`data/guildbank.lua`, `next/guildbank.lua`, `next/guildbutton.lua`)

BetterBags reads the guild bank with the same data engine as the bags (categories, search, virtual
stacks, sort, item level, upgrade arrows) and, with BetterBags Next on, shows it in a panel that
stands in for Blizzard's guild bank frame: a third companion of the backpack on the left, beside
the bank and the vendor (next-chain.md §12). With the classic bags nothing changes: Blizzard's frame shows
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
  **Guild Bank** page after the Bank's on clients with a guild bank while BetterBags Next is in use
  (the classic bags have no guild bank; next-settings.md §4, §7), every setting the guild kind's
  (`SettingsCatalog:Bags()`). The player's categories are used in the guild bank as in any bag
  (category-lifecycle.md §6; before, no category was ever enabled for it).

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
- **The logs and the tabs' info text** (issue #1302; what Blizzard's Log, Money Log and Info tabs show,
  `GuildBankFrameTabMixin:OnClick`). They come from the server as tabs do:
  - **Asking** (`LoadLogs(ids)`, `LoadTexts(tabs)`, private `ask`/`askNext`): one at a time, each with
    `QUERY_TIMEOUT` (2 s), after which it counts as received anyway. A log is a tab, or `MoneyLogID()`
    (`MAX_GUILDBANK_TABS + 1`, as Blizzard asks for the gold) for the money log; `QueryGuildBankLog` is
    answered by `GUILDBANKLOG_UPDATE`, which names no log, so each answer is the log asked for last
    (`OnLogUpdate`; one with nothing asked says `guildbank/LogChanged`). `QueryGuildBankText(tab)` is
    answered by `GUILDBANK_UPDATE_TEXT(tab)`, which names its tab (`OnTextUpdate`: one for a tab not waited
    on is taken without losing the list's place). A new list takes the place of what was still to ask for,
    and the one waited on is not asked again. `Answered` marks it received (`IsLogLoaded`, `IsTextLoaded`)
    and says `guildbank/LogLoaded` or `guildbank/TextLoaded` with it. `GUILDBANK_TEXT_CHANGED(tab)` (another
    member saved it) asks again for a text this visit received (`OnTextChanged`). Opening and closing forget
    all of it (`forget`).
  - **Reading** (`ItemLog(tab)`, `MoneyLog()`), newest first (higher indices are newer,
    warcraft.wiki.gg API_GetGuildBankTransaction): `GuildBankLogEntry` holds Blizzard's type (items:
    `deposit`, `withdraw`, `move`, the only ones its frame shows; gold: `deposit`, `withdraw`, `repair`,
    `withdrawForTab`, `buyTab`, `depositSummary`, `buyRename`, `refundRename`), who (nil when the client
    does not know), the item, count and tabs, or the gold, and how long ago in the client's parts and in
    hours (`age`: a month of thirty days, a year of twelve, as `TimeUtil.lua` counts them). The money log is
    read only up to `GetNumGuildBankMoneyTransactions()`: asked for an index past it,
    `GetGuildBankMoneyTransaction` crashes the client (warcraft.wiki.gg; the mock raises).
  - **The text** (`Text`, `CanEditText`: `CanEditGuildTabInfo(tab)`, `SaveText`: `SetGuildBankText`, only
    while open), as Blizzard's Info tab and its Save button use them.

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
  `ContinuableContainer`), a read holding a tab's first items with a fresh layout (refresh-scheduler.md §11a); after `GUILD_PRIME_TIMEOUT`
  (2 s) it is read anyway and again when the data arrives. `guildbank/Changed` reads the loaded tabs
  again (primed), `guildbank/TabsChanged` reads, `guildbank/Closed` forgets the guild bank. Nothing
  happens for a visit that has ended. `RefreshRequest.guild` sweeps the guild bank after the bank and
  before the backpack, only while it is open and its panel has shown; a wipe sweeps it;
  the bank now loads the same way, tab by tab (refresh-scheduler.md §11a);
  `bags/Rederive` naming no kind recalculates every kind. `guildLoad` says why a read ran
  (`"primed"`, `"timeout"`), for profiler traces.

## 3a. Backpack dimming at the guild bank (removed; issues #768, #1364)

Nothing in the backpack dims while the guild bank is open. v0.9.4 (#768) dimmed a backpack item for
which `C_Bank.IsItemAllowedInBankType(Enum.BankType.Guild, itemLocation)` was false, as an item the
Warbank refuses dims at the bank (item-drawing.md §8). The rule was written without a capture: Blizzard
has no item context for the guild bank, and its own code asks the check only of the bank and the
Warbank (`ItemUtil.lua`, `BankFrame.lua`), so what the check answers for the guild bank had never been
seen. Issue #1364: a player saw every backpack item dim at the guild bank, tradable inks it takes
among them, and saw the check answer false for those inks. v0.9.5 removed the rule, at the user's
request, until what the check answers is captured:

- `items:ResolveItemContextMatchResult` does not ask the check, and `items:contextSignature` does not
  hold `addon.atGuildBank`, so opening or closing the guild bank works no kept grey-out out again. The
  flag itself stays (§2; other code reads it), and the guild banker interaction still recalculates the
  backpack on open and close (`core/hooks.lua`), as it did before #768.
- **Before any dimming comes back:** a `/bbdb` dump at the guild bank (§7). The Dump tab's probe
  records the check's answer for every bank type beside each backpack item (`bankAllowed`,
  data-driven.md), so the dump shows whether the check refuses every item or only some.
- **If the check cannot be used:** a rule of BetterBags' own from what the item's read holds, as
  `items:LegacyAuctionableOf` does for the legacy auction house. The client's refusal messages name
  what the guild bank refuses: `ERR_GUILD_BANK_BOUND_ITEM` (soulbound), `ERR_GUILD_BANK_CONJURED_ITEM`,
  `ERR_GUILD_BANK_QUEST_ITEM`, `ERR_GUILD_BANK_WRAPPED_ITEM` (the live client's strings,
  `Resources/GlobalStrings/enUS.lua` of Ketho/BlizzardInterfaceResources on its `live` branch; not under `.libraries`). The
  read holds whether an item is bound (`bindingInfo.bound`) and a quest item (`questInfo.isQuestItem`);
  retail's tooltip scan records no conjured or wrapped mark (`data/tooltip.lua`, `markClassicLine`), so
  it would have to.
- A client without the check (TBC Anniversary, Mists: the `classic` and `classic_anniversary` branches'
  `BankDocumentation.lua` have no such function) never dimmed anything there.

## 4. Two views

- **All Tabs** (`GUILD_BANK_ALL_TAB`, the Category view): every tab's items in the categories the
  bags use, each tab's free slots its own Free Space entry, the same item stacked across tabs.
- **A tab by itself** (the Show Bags view, `SECTION_ALL_BAGS`, as the bank's Bank Tabs mode): that
  tab's slots in order, empty slots in place, one headerless section named `#<tab>: <name>`, no
  virtual stacks, and no Free Space: its free slots are those in place (data-loader.md §8; a Free
  Space entry took one of them out of the grid, leaving a gap). The footer counts them. The panel switches the guild kind's view between the two
  (`database:SetBagView(GUILD, ...)`) and recalculates (`bags/Rederive { guild, resetLayout }`).

## 5. BetterBags Next's guild bank (`NextGuildBank`, `NextGuildButton`)

**Taking over Blizzard's guild bank frame.** It is load on demand. Blizzard's `ShowGuildBankFrame`
(retail and Forever; the Classic UIParent's `GUILDBANKFRAME_OPENED` handler is the same) calls
`ShowUIPanel(GuildBankFrame)`, then `CloseGuildBankFrame()` at once when the frame is not visible,
and the frame's `OnHide` (`GuildBankFrameMixin:OnHide`) ends the visit too. So the vendor's way (the
frame under the hidden frame, next-vendor.md §10a) would end every visit. `TakeOver` instead hooks
`ShowUIPanel` securely (once); when it shows `GuildBankFrame` while Next is in use, the frame goes
under a tiny shown frame (`SetScale(0.001)`: visible to Blizzard's check, never seen), its `OnHide`
is taken off, and a frame later it goes under the hidden frame. Bagnon does the same
(`core/features/uiOverrides.lua`, its comment blaming Blizzard's 12.1 guild bank). Its `Hide` is
hooked once to end the visit a frame later, as its `OnHide` did, when something hides it during a
visit (another panel on the left, Escape through `CloseWindows`). `GiveBack` puts it back under
`UIParent` with its `OnHide` when Next is switched off (refused at the guild bank). With the classic
bags the hooks do nothing.

**Blizzard's panel manager still lays the frame out**, double-wide (793, or 769 with an `xoffset` of -16 on Classic), and
put the panels after it far to the right of the guild bank. The panel names it (`standIn = "GuildBankFrame"`, looked up
as it is used: the frame loads on demand): while the guild bank is open at full size, the frame takes no room in the
layout and the layout's left edge moves past the guild bank and its tabs (next-uipanels.md §27).

**Enable Guild Bank Window off** (next-bagsystem.md §11g, #1262): the bag system switches the guild bank off by itself
while Next stays in use, away from the guild bank only: `guildProto:Deactivate` marks the panel `off` (then hides it and
lets go of its buttons) and `GiveBack` puts Blizzard's frame back with its `OnHide`, so its `ShowUIPanel` hook leaves the
next visit to Blizzard's frame (`active` false). `addon.Bags.GuildBank` is nil meanwhile, so the refresh opens and reads
nothing (`refresh:_OpenGuildBank`, as with the classic bags). The data source still says the visit's messages: while
`off`, the panel neither follows `guildbank/TabsChanged` (it would put a tab shown by itself back to All Tabs, writing
`showGuildBankTabs`) nor `guildbank/Closed` (Blizzard's frame closes its own dialogs). `guildProto:Activate` clears `off`
and catches up as every panel does; `TakeOver` takes the frame at the next visit. Coverage:
`spec/next/guildbank_spec.lua` ("switched off"), `spec/integration/guild_bank_spec.lua` (a visit in Blizzard's frame while
off, BetterBags Next's again once on).

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
- **Views** (issue #1302: "I can't see the guild bank money log and I have to disable the addon"; asked, of
  where Blizzard's Log, Money Log and Info tabs go: "maybe tabs for this on the bottom of the rail instead
  of the top?"). Three tabs at the rail's foot (`NextTabEntry.foot`, next.md §3 "Tabs at the rail's foot"),
  under the guild's tabs: **Log**, **Money Log**, **Info**, in Blizzard's words (`GUILD_BANK_LOG`,
  `GUILD_BANK_MONEY_LOG`, `GUILD_BANK_TAB_INFO`). One tab is chosen down the whole rail, a view as any tab
  (asked, of a first version that chose the view apart from the tab, with an Items tab: "the new tabs should
  be just like all the other tabs, meaning, you can get rid of items -- it should just work as a selector
  along side the others, not this sort of dual selector type system. i.e. going from all tabs, to a specific
  item tab, to money log, then back to an item tab should 'just work'"). `self.view` is `VIEW_ITEMS` while
  All Tabs or a tab shows, else the view's id; `SelectedTabID` is what the rail selects. The tab shown before
  a view stays the guild bank's (`shownTab`: where deposits go, `DepositTab`); a log's or Info's title is the
  guild's name. It opens on its items, as Blizzard's frame does (`OnShowing`, `GuildBankFrameMixin:OnShow`).
  - **Switching** (`ShowView`): to a log or Info, the guild buttons drawn are let go (`releaseItems`) and
    what the view shows is asked of the server (`loadView`; every time, as Blizzard's tab click asks).
    Nothing travels from what showed (`Motion:ForgetShown`). A guild tab clicked from a log or Info
    (`ShowItems`) lets go of the view's cards and shows that tab's items: the tab that showed before drawn at
    once from the last read, a read that came meanwhile having waited (`Draw` keeps it), dimmed by what the
    search box holds now (`searchItems`, as `SearchBox` applies a search: each guild button takes its dimming
    from the read it is drawn from); another tab shown as its click shows it (`ShowAll`, `ShowTab`: asked of
    the server, drawn as its read arrives).
  - **Log and Money Log** (`buildLog`, `DrawView`) are the vendor's cards (`NextVendorButton:SetLog`,
    next-vendor.md §10b), `SetCards(true)`, in one column of sections (`SectionColumns` returns 1 for every
    view), a section for each "how long ago" in Blizzard's words (`TimeUtil.GetRecentTimeDate`, "%s ago"),
    newest first. Each card's bottom line is a glyph for what happened, tinted by which way it went, then who
    (asked: "withdraw and deposit need an icon, not text, with the person who did it next to it. icon should be
    color coded. this is so humans can quickly scan it"; `Vendor.LogIcons`, `NextVendorButton:LogIcon`; the colors per
    theme, measured against each theme's cards, next-themes.md, the `Vendor` row). Log
    shows every tab the player can view (`viewTabs`, in the rail's order), their entries merged by age: a card
    is the item and its stack, its name in its quality's color, and Deposit (in), Withdraw (out) or Move's
    glyph with who; its tooltip the item's then "Deposited by" / "Withdrawn by" / "Moved by" who, how many,
    which tab ("Into", "Out of", "From ... to"), and when. Money Log is the whole guild's: a coin, the gold as
    its title (written as the vendor writes a price; "Tab unlocked" for a tab that cost none), and
    DepositGold, WithdrawGold, Repair or BuyTab's glyph with who; its tooltip in Blizzard's money log's words
    ("%s deposited", "withdrew", "repaired", "withdrew for a tab", "bought a tab" or "unlocked a tab", "Guild
    perks deposited", "renamed the guild", "was refunded a guild rename") with the gold, and when. A deposit
    of the guild's perks names "Guild perks"; who the client does not know is `UNKNOWN`, as on Blizzard's
    frame. The footer counts the entries. Empty: "Loading..." until a log shown has arrived, then "Nothing
    logged yet" / "No gold has moved yet"; with no tab to view, "This guild has no tabs you can view". A log
    arriving (`guildbank/LogLoaded` for one shown, `guildbank/LogChanged`) draws it again. The money log is
    asked for again when the guild's gold changes while it shows (`logMoney`: not for the withdrawal limit,
    `GUILDBANK_UPDATE_WITHDRAWMONEY`, which says the same message); Blizzard's asks only on a click.
  - **Info** (`buildInfo`): a section a tab shown, its body a block of the canvas's (`NextCanvasBlock`,
    next.md §2), a text area (`NextInput:CreateArea`, 120 tall as the settings' are, `maxLetters` 500 as
    Blizzard's `GuildBankTabInfoEditBox`) and, for a member `CanEditGuildTabInfo` lets edit it, a Primary
    Save button under it, as a settings page puts its button under its text area (`SaveInfo`: only a
    change, `SetGuildBankText`). The others see it read only (`SetReadOnly`, drawn as ever, as Blizzard's
    takes no focus). Its header's count says "Loading..." until its text arrives. A text that arrives
    replaces the box's unless the box holds what a member who may edit it typed and did not save
    (`refreshInfo`, `loaded`); one who may no longer edit sees the tab's text again. Two tabs named alike are
    told apart by their number ("Gear (tab 2)"): the canvas keeps sections by name. The visit's end forgets
    what was typed (`forgetInfo`, from `OnGuildBankClosed`: the guild bank can open again while the panel
    slides out), the text staying on screen through the slide (`forgotten`). Every switch and redraw lets go
    of a box's focus only when it hides; a text arriving for another tab never hides the box being typed in
    (the canvas keeps a block given again, next.md §2).
  - **Tabs changing** while a log or Info shows (`OnTabsChanged`): drawn again (names, permissions), and a tab
    come into view (bought, or opened to the player's rank) is asked for (`loadMissing`: only what this visit
    has not received). A tab moved on the rail redraws them in its order (`OnTabsReordered`).
  - **Search** in a log dims the cards whose title and tooltip do not hold the box's text (`applyLogSearch`),
    as the vendor's Buyback and Repair tabs dim theirs by name.
  - **Sections** of a log or Info hold no items: their headers neither drag (`OnHeaderDragStart`), withdraw
    nor file; an item dropped or clicked onto one, or onto a card (`onDrop`), goes into the guild bank as a
    drop on the panel does (`PlaceCursorItem`). A backpack section dropped on the panel still deposits.
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

**Sections in and out** (next-drag.md §7; `NextDrag:CanMoveBetween`, `CanDropOnBody`, the guild panel's
`DepositTab`, `CanDepositIn`, `Deposit`, `Withdraw`):
- At the guild bank, a backpack section dropped on the guild bank's body goes into its deposit tab
  (the tab shown by itself, else the current tab), one dropped on a guild tab into that tab; only
  tabs the player may deposit in are targets (not All Tabs, nor "+"). Every item and every pile its
  virtual stack hides, in the backpack's bags, bound items left out.
- **Into a tab the player cannot withdraw from, it is confirmed first**: those items cannot be taken
  back. `Deposit` deposits nothing unless `confirmed` and returns `"confirm"` ("Deposit 15 items?",
  "You cannot take them back out of Donations.", "Double-click to deposit · Right-click to
  cancel"), and the section docks in the guild bank until a double click (next-drag.md §7, "Confirming in
  the target"); the backpack keeps its gap meanwhile.
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
the Warbank's table on Classic, which has none). ConsolePort's cursor reaches it.

**Masque.** Guild bank buttons are in a Guild Bank group of their own. Every draw rewrites the
quality border Masque skins: Blizzard's `SetItemButtonQuality` sets its atlas or texture
(`Mainline/ItemButtonTemplate.lua`; `SetAtlas` slips past Masque's `IconBorder` `SetTexture` hook,
`Core/Regions/IconBorder.lua`), and BetterBags' glow sets its texture, coordinates and blend. So
each draw ends with `guild/Updated`, and the integration skins the button again (`ReSkin`, or
`AddButton` the first time) and gives its border a blend mode, exactly as `item/Updated` does for bag
buttons. A theme applied also re-skins them: Sonata restyles them as `ItemButton` elements, and a
theme change redraws only the backpack and the bank. So does Sonata restyling one for a new pixel grid
(BetterBags Next's item fitter, next-pixel-perfect.md §4): the fitter calls the button's `Restyled(ctx)`,
which sends `guild/Updated`. A theme without Masque takes them out of the
group. **Failure mode (fixed):** they were only added once, at creation, so after their first draw
they showed Masque's frame with Blizzard's and BetterBags' quality border inside it, not the skin's.
**Cost, not measured:** guild buttons have no draw record (item-drawing.md §7b), so every guild
draw re-skins every button it draws, where bag buttons re-skin only the ones that changed.

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
do (next-drag.md §7).

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
- **What `C_Bank.IsItemAllowedInBankType(Enum.BankType.Guild, …)` answers** (§3a): one player saw it
  answer false for tradable inks the guild bank takes (#1364), not captured. A `/bbdb` dump at the guild
  bank with soulbound, warbound, warbound-until-equipped, bind-on-equip, quest, conjured and unbound
  items in the backpack (`bankAllowed` beside each), checked against depositing each one. Also whether
  it answers the same away from the guild bank.
- **The views** (§5): a capture of opening Log on All Tabs, Money Log, and Info, with
  `GuildBank.Answered` (each log's and text's `"answered"` or `"timeout"`), `GuildBank.OnLogUpdate` and
  `NextGuildBankPanel.DrawView`. It shows whether every `QueryGuildBankLog` is answered by one
  `GUILDBANKLOG_UPDATE` (the one-at-a-time asking relies on it), whether a text asked for is answered by
  `GUILDBANK_UPDATE_TEXT`, and whether `GUILDBANK_UPDATE_MONEY` ever fires as the money log arrives (it
  would ask for the log again only if the gold changed, `logMoney`, so no loop either way). Also by eye:
  the sections' "how long ago" titles (Blizzard's `LASTONLINE_*` strings carry `|4` plural escapes the
  client draws), and a read-only text area's text, which should read as the editable one's.

## 8. Not done

- Changing a tab's icon (renaming keeps it). Not a view; on retail Blizzard's icon picker
  (`GuildBankPopupFrame`) is a child of its hidden guild bank frame, so it would need a design of its own.
- **Left as it is (bug reviews of the views, §5):**
  - A money log asked for again while the last question is still unanswered is not asked again (`ask`
    leaves the one waited on), and `logMoney` takes the new gold: if the answer predates the change, the
    newest entry shows only after the next change, or a click. It needs server timing nobody has seen.
  - A log's late answer after its timeout counts for the log asked for next; it reads as received until its
    own answer arrives and draws it again. It comes with asking one at a time, which the answers' naming no
    log forces.
  - A read-only text area takes the wheel only while focused, as every text area does, and refuses focus: a
    long text scrolls by its bar.
  - The log's cards come from the vendor's pool, so Masque skins them in its Vendor group.
  - Halloween's log glyphs read at 2.9, 2.6 and 3.0 to one on its orange cards (in, out, moved: its `Lime`, `Maroon`,
    `Night`), under WCAG's 3:1 for graphics for in and out: its palette has no green or red darker or lighter that keeps
    the color coding there. Measured, not seen in game; a darker green and red of its own would fix it.
- Two tabs with the same name share one Free Space entry in All Tabs (entries are keyed by name).

## 9. Coverage

`spec/core/constants_spec.lua` ("guild bank"), `spec/database_spec.lua` (`showGuildBankTabs`),
`spec/guildbank_spec.lua` (the data source: visits, tabs, loading and its timeout, changes, actions on
the item's tab, placing the cursor's item, moving many items, gold and tabs, "the logs", "the tabs' info
text"), `spec/next/guildbank_spec.lua` ("its views": every view, one tab chosen down the rail, from All
Tabs to a tab to the money log and back, reads kept, the search again, the action glyphs, tabs coming into
view, the rail's order, same-named tabs, editing lost, the visit ending, the box being typed in), `spec/integration/guild_bank_spec.lua` ("shows the money log from the rail's foot"; "dims none of the backpack's items
while the guild bank is open", with both bag designs), `spec/refresh_pipeline_spec.lua` ("at the guild bank"),
`spec/debug/itemprobe_spec.lua` ("records whether each bank takes the item"),
`spec/guildbank_pipeline_spec.lua` (reading, kept slots, cold reads, binding, derive, both views,
stacking across tabs, empty slots in place, the shared index, an ended read), `spec/tooltip_spec.lua`
("guild bank items"), `spec/loader_spec.lua` (`PrimeGuildBank`), `spec/refresh_spec.lua` ("the guild
bank"), `spec/core/init_spec.lua`, `spec/next/guildbutton_spec.lua`, `spec/next/guildbank_spec.lua`,
`spec/next/content_spec.lua` ("a source of buttons of its own"), `spec/next/drag_spec.lua` ("the guild
bank"), `spec/frames/search_spec.lua` ("the guild bank"), `spec/bagsystem_spec.lua`,
`spec/integrations/consoleport_spec.lua`, `spec/integrations/masque_spec.lua` ("guild bank buttons"),
`spec/config/settings_effects_spec.lua` ("writes the guild bank's own settings"),
`spec/next/settings/content_spec.lua` (the page per client and design), `spec/frames/item_classic_spec.lua`
(`DrawQualityGlowFor`), and on the whole addon `spec/integration/guild_bank_spec.lua` (a visit from the
interaction to items drawn, closing, the switch refused, the classic bags left alone). The mocks gained
Blizzard's guild bank functions (`ResetMockGuildBank`), the item button's parts (the `ItemButton`
intrinsic and `ItemButtonTemplate`), `ShowUIPanel`/`HideUIPanel`, the stack split frame's `Hide` and
the full `Enum.PlayerInteractionType`.
