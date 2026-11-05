---
paths:
  - "core/bagsystem.lua"
  - "spec/bagsystem_spec.lua"
  - "spec/integration/bag_switch_spec.lua"
---
## 11. Switching between the classic bags and BetterBags Next without a reload (`core/bagsystem.lua`)

Asked: "i want to be able to toggle next on or off, without having to do a reload. this is
critical to get right (performance especially, we need to unhook the "classic" bags when we swap,
and vice versa)", and a **Switch to Next** entry in the classic bag's menu ("unsure how to go back
to classic though").

### 11a. One design in use; the other made once and unhooked

`BagSystem` makes the bags of one design, `"classic"` or `"next"`, each set (backpack, bank with
Enable Bank Bags, and Next's vendor and, on a client with one, guild bank) **in an event scope of its own** (`events:NewScope`,
`events:InScope`, event-buckets.md §5). Nearly everything a design registers is registered while
its bags are made: the classic `bagFrame:Create` and its behaviors' `OnCreate`/`RegisterEvents`
(groups, bank tabs, the cooldown bucket), the slots panels (`BagSlots`/`BankSlots:CreatePanel`),
the money frames (`money:Create`) and currencies (`currency:CreateIconGrid`), the overlay search
(`searchBox:Create`); Next's `Watch`/`WatchKind` and the vendor's merchant events. All of it lands
in the scope, so switching a design off unhooks it: WoW events and messages no callback is left
for are unregistered, and its buckets' open windows are closed. A design not in use costs nothing
per event.

What stays, on purpose: module-wide registrations made outside creation (sections, tabs, the
window manager, Masque, ConsolePort's context menus), shared by both designs; frame scripts on the
inactive design's frames, which are hidden and so never run; Sonata's registration of the classic
windows (decorated again only when a theme is applied); `NextDrag`'s registry of panels and
sellers (it skips hidden ones); the hook on Blizzard's merchant frame's `Hide` (it cannot be taken
off; with Next off it does nothing, next-vendor.md §10a), and the guild bank's hooks on `ShowUIPanel` and its frame's
`Hide` (the same, guild-bank.md §5).

### 11b. The switch (`BagSystem:Switch(ctx, design)`)

1. **Refusals**, with Blizzard's error text (`UIErrorsFrame`): in combat (making the classic bags
   makes secure tab buttons), at the bank, at a vendor (Blizzard's merchant frame shown, or
   Next's vendor at one), and at the guild bank (`addon.atGuildBank`: its frame changes hands too). The merchant frame would have to change parents while shown: reparenting
   a shown frame to a visible one runs Blizzard's `OnShow` from our code, which writes
   `MerchantFrame.selectedTab`, a field its bag code reads before the protected `UseContainerItem`.
   The bank's frames are the same for both designs, but its open state lives in each design's bank.
2. **Switching off** the design in use: each bag's `Deactivate` hides it at once (no slide or fade;
   its `OnHide` still runs its close work: Recent Items expiry, the cursor) and lets go of every
   button it drew (`Wipe`). The classic bag also hides its overlay search and its anchor's frame
   (keeping the anchor's saved state). Then its scope is switched off, and Next gives Blizzard's
   merchant frame back to `UIParent` (`NextVendor:GiveBack`), and the guild bank Blizzard's guild
   bank frame, with its `OnHide` (`NextGuildBank:GiveBack`).
3. **The other design**: made the first time (`CreateBackpack`, `CreateRest`, `Finish`: title,
   `UISpecialFrames`; the bag-bar highlight hooks, `addon:WatchBackpackFrame`; ConsolePort's
   cursor frames), else its scope switched back on, Next taking the merchant frame and the guild
   bank's again (`TakeOver`, hooking each once), and each bag catching up (`Activate`): what its
   handlers would have done while unhooked. Classic: the search box's setting, its behavior's
   `Resync` (the backpack lists its groups as tabs; the retail bank its tabs and Purchase Bank
   button; the Classic and Era banks nothing, they have no bank events), the money, the
   currencies, the slots panel, the anchor as saved. Next: the search box's setting, the tabs, the
   money; the bank its Purchase Bank button on retail; the vendor nothing (the next vendor that
   opens draws everything).
4. **Taking over**: `addon.Bags.Backpack`, `addon.Bags.Bank`, `addon.Bags.GuildBank` and `addon.Vendor` become the new
   design's, the setting is saved (`database:SetNextEnabled`), the backpack's `loaded` flag (and
   the bank's) carries over, and the backpack draws the data last read
   (`items:GetAllSlotInfo()[BACKPACK]`; no bag is read again) and opens if the old one was open:
   shown and not closing (`IsClosing`: the classic window fading out, Next's panel sliding out; a
   bag closed a moment before the switch still shows while it does, and used to open the other
   design).
   The in-bag search text of the backpack and the bank carries over, set even when empty so a
   design switched back on never shows a stale search. The bag-bar highlight is updated and
   `bags/DesignChanged` (design) is sent.

No read of the bags happens: the switch costs one draw, plus making the other design the first
time. Not measured in game; capture a switch with the profiler (`BagSystem.Switch`).

### 11c. Where it is switched

- **Settings:** the BetterBags Next checkbox switches at once; a refused switch reloads the form so
  the checkbox shows the setting as it is. Settings follow a switch made elsewhere
  (`bags/DesignChanged` reloads the form).
- **`/bb next`:** switches to the other design.
- **The classic backpack's menu:** **Switch to Next**, above What's New (not the bank's: it is shown
  at the bank, where the bags cannot switch). bag-menu-button.md §3.
- **Next's backpack header:** had a button with a backpack glyph, "Switch to Classic Bags"; it is now
  Show Blizzard Bags (next.md §3, asked), so the settings and `/bb next` switch from Next.

### 11d. Startup

`core/init.lua` makes the saved design through `BagSystem` in the same order as before, keeping
the safecall invariant (initialization.md §5): `CreateBackpack`, then the bag-bar buttons and
bindings and `addon:WatchBackpackFrame`, then `CreateRest` and `Use`, then Sonata, then `Finish`.
`BagSystem:Init` runs in phase 4. `core\bagsystem.lua` loads right before `core\init.lua` in every
TOC (after ConsolePort, which it looks up).

### 11e. Coverage

`spec/events_spec.lua` ("scopes": everything off and on, what is outside left alone, WoW events
unregistered and registered again, open windows closed, idempotent, registering while off, a
dispatch in progress, nesting and errors; buckets one per registration),
`spec/bagsystem_spec.lua` (making each design, no bank without bank bags; switching off and
unhooked, made once, used and saved and announced, the draw and opening, switching back, the
loaded flag and the search carried over, the same design, the three refusals),
`spec/frames/bag_draw_ownership_spec.lua` ("switching designs"), `spec/bags/backpack_spec.lua`
and `spec/bags/bank_spec.lua` (`Resync`), `spec/next/bag_spec.lua`, `spec/next/bank_spec.lua`,
`spec/next/vendor_spec.lua` (`Deactivate`, `Activate`, `GiveBack`, one hook),
`spec/frames/contextmenu_spec.lua`, `spec/config/config_spec.lua`, `spec/core/init_spec.lua`,
`spec/core/backpack_button_spec.lua`. 71 mutations: two survivors led to tests, one showed a guard a
second `Disable` makes unnecessary (removed), one was a malformed mutation.

On the whole addon (`spec/integration/bag_switch_spec.lua`, through `spec/helpers/whole_addon.lua`,
test-harness.md §5): every file of the TOC loaded and started as the client does, then switched
both ways, with the backpack open and closed, with no error; the classic bags made after the theme
(their parts placed); and the strongest check of the unhooking: after any switch, including back
to a design made earlier, BetterBags listens to exactly the events and messages, with as many
callbacks each, as a fresh start in that design. 12 mutations, one survivor leading to the
switch-back check. Then, for what changes what runs while a window is styled: every theme
(Default, Simple Dark, Dark, Parchment, Slate, and ElvUI and Guild Wars 2 with stand-ins for their
addons), each making the classic bags late; the backpack sized to its content and the bank by the
player at once; WoW: Forever both ways; and in-bag search off, groups off and the Show Bags view.
With the minimum width reading the scroll box, 10 of the 17 fail with the reported error.

### 11f. Failure mode (fixed): the classic bags made by a switch

Reported in game, switching from Next to the classic bags the first time:
`frames/bag.lua: attempt to index field 'searchBox' (a nil value)`, twice (backpack and bank), from
`Sonata:RegisterWindow` → `decorate` → the window's `OnDecorated` → `bagProto:PlaceParts`. At
login the bags are made before Sonata applies the theme (at `PLAYER_LOGIN`), so their windows are
decorated after everything exists. A design made by a switch registers its windows after the theme
was applied, and Sonata styles a window the moment it registers (patterns-ui-themes.md, "Windows and
Elements Made on First Use"): inside `BuildWindow`, before `BuildParts`. `PlaceParts` now does
nothing until the parts exist, and `bagFrame:Create` places them once made
(`PlacePartsIfDecorated`, window.md §7). Next's panels register no windows, so making Next by a
switch had no such problem.

The next report was the same order in another place: `frames/bag.lua: attempt to index field
'scroll' (a nil value)`, once, for a bank in the window size mode (Drag to Resize). Styling a window
in that mode sets its resize bounds from the owner's minimums (`window:UpdateSizeMode`), and the
bag's `MinContentWidth` added `self.scroll:GetGutterWidth()`, made after `window:Create`. The bar's
room is fixed by the scroll box's options, so the minimum now reads it from them
(`scrollbox:GutterWidthFor(SCROLL_OPTIONS)`, the options the bag's box is made with) and needs
nothing built later. Every other callback of the windows a switch makes (the bags, both slots
panels, the overlay search) reads only settings or guards what it reads; checked by reading each.

**The rule for windows made after a theme was applied:** everything the window calls while it is
styled (`OnDecorated`, `SizeMode`, `Size`, the minimums, `Opacity`, `Scale`) runs inside
`window:Create`, so it may read only what exists before the owner builds anything else, or must
do nothing until it does. The specs had missed it because `spec/bagsystem_spec.lua` uses stand-in
bags and no spec ran the real `bagFrame:Create` after a theme was applied; the whole-addon spec
reproduces the error exactly without the fix.
