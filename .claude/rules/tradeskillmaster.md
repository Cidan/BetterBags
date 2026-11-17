---
paths:
  - "integrations/tradeskillmaster.lua"
  - "next/vendor.lua"
  - "spec/integrations/tradeskillmaster_spec.lua"
  - "spec/next/vendor_spec.lua"
  - "spec/helpers/tsm.lua"
---
# TradeSkillMaster's vendor window and BetterBags Next's vendor

Issue #1315 (the reporter of #1188): "The BetterBags Next vendor interface is nice until you need to do something that is
only available through the TradeSkillMaster vendor interface. Suggest putting in some method of swapping between the
BetterBags Next vendor interface and the TradeSkillMaster vendor interface." Asked: "build a full integration with TSM ...
scan at depth for TSM code and make it work as needed".

With TradeSkillMaster (TSM) loaded, BetterBags Next's vendor and TSM's own vendor window swap, one at a time, the way TSM
swaps its window with Blizzard's merchant frame: TSM's window or the vendor shows a merchant, a TradeSkillMaster button on
the vendor opens TSM's window, and TSM's own WoW UI button brings the vendor back. Without TSM nothing of it shows and
nothing is called.

## 1. Why: TSM's window and BetterBags Next before this

Read from TSM v4.15.6 (CurseForge file 9546800, "Interface: 120105, 50504, 20506, 16001, 11509"; TSM's code is All Rights
Reserved, read for compatibility only, nothing of it copied):

- **TSM opens its window on its own** at every merchant, a frame after `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`
  (`LibTSMWoW/Source/UI/DefaultUI.lua:151-186`; `App/VendoringUI/Core.lua:86, 140-148`, a `DelayTimer` run for 0
  frames), whatever Blizzard's merchant frame does. So with BetterBags Next on, both windows opened together.
- **Its saved choice** (`showDefault`, `Core.lua:65-75`, account-wide): its window (false, the default), or Blizzard's
  frame (true), chosen by the WoW UI button in its window's title bar (`LibTSMUI/Source/Frames/ApplicationFrame.lua:
  142-149`). With Blizzard's frame chosen, TSM shows its own small "TSM" switch button on `MerchantFrame`
  (`SwitchButton.lua:24-39`: `SetParent(MerchantFrame)`), the only way back to its window.
- **BetterBags Next hides `MerchantFrame`** under a hidden parent for the whole session (next-vendor.md §10a), so that
  button was never seen: one click on WoW UI and TSM's window never came back, on any character. That is #1315.

## 2. What TSM offers, and what is read from it (`integrations/tradeskillmaster.lua`, `TradeSkillMaster`)

TSM's public API has no call to show or switch its vendor window: `TSM_API.IsUIVisible("VENDORING")` (`App/API.lua:60-73`)
only says whether it is up, and `TSM_API.RegisterUICallback` takes only `"CRAFTING"` (`App/API.lua:81-93`). Everything
else is TSM's own, read as v4.15.6 has it:

- `Available()`: `TSM_API.IsUIVisible` is there.
- `WindowShown()`: `TSM_API.IsUIVisible("VENDORING")`, called with a dot (TSM errors on a colon, `CheckCallMethod`,
  `App/API.lua:536-540`).
- `ChoosesWindow()`: `TradeSkillMasterDB["g@ @vendoringUIContext@showDefault"] == false`. TSM's settings live in its
  saved variable (`LibTSMApp/Source/Service/AddonSettings.lua:66`), each under `scope@scopeValue@namespace@key`, the
  global scope's value `" "` (`LibTSMTypes/Source/Settings/Internal/DB.lua:275-293`, `Types.lua:46-50`), written as TSM
  sets them (`DB.lua:603-619`; the vendor window mirrors its state there, `UIManager:MirrorStateWithTable`). The table is
  protected against new keys (`DB.lua:215-242`); it is only read. A missing value reads as not choosing the window.
- `SwitchButton()`: the one `Button` among `MerchantFrame:GetChildren()` carrying TSM's widget extensions
  (`TSMSetScript`, copied onto every frame TSM makes, `LibTSMUI/Source/Util/Widgets.lua:605-614, 689-`), kept once found
  while it is still `MerchantFrame`'s. TSM makes it the first time it shows Blizzard's frame (`ACTION_SHOW_DEFAULT`,
  `Core.lua:149-154`) and keeps it for the session. `CanSwitch()` is whether it is there.
- `OpenWindow()`: clicks that button (`Button:Click`, which runs its `OnClick`, `ActionButton.lua:158-166, 384-398`; it
  refuses only a disabled button, and TSM's switch is never disabled, `DisableClickCooldown`). TSM then does what its own
  click does (`ACTION_SWITCH`, `Core.lua:173-180`): saves its window as the choice, moves `MerchantFrame` off the screen and
  out of the layout (`Move.SetDefaultUIOffScreen`, `LibTSMWoW/Source/Service/Move.lua:109-137`), and shows its window.
  Never while TSM's window is up (the switch would close it: `"shown"`). It returns `"opened"`, `"clicked"` (not up yet),
  `"shown"`, `"no switch"` or `"no tsm"`, for profiler traces.
- `Follow(onChange)` / `Look()` / `Stop()`: while a vendor is open, a driver frame's `OnUpdate` looks every frame at
  `WindowShown()`, and at `CanSwitch()` while the button is not found and the window not up, and calls `onChange(ctx)`
  when either changed (`Look` returns `"window"`, `"switch"` or `"same"`). TSM shows its window a frame after a merchant
  opens and switches in clicks of its own, with no event or callback another addon can hear; a hook on what TSM happens to
  call as it switches (`MerchantFrame_Update`, `UpdateUIPanelPositions`) would run before its window is up or for
  Blizzard's own calls too. One API call and a cached check a frame, only at a vendor with TSM loaded.

## 3. The swap (`next/vendor.lua`)

- **A merchant opens** (`OnMerchantShow`): with TSM's window its choice (`ChoosesWindow`), the vendor marks itself
  `aside` and does not open (no slide, no sound); TSM's window opens a frame later, alone. Otherwise it opens as before.
  Either way it follows TSM's window (`Follow`, `FollowTSM`) until `MERCHANT_CLOSED` (`Stop`).
- **Aside** (`aside`): the visit goes on. `Hide` ends nothing (no `CloseMerchant`), nor does `OnHidden` once the slide
  ends; Blizzard's merchant frame stays shown to Blizzard's code, so a right click on a bag item still sells, and Move
  Categories still sells (`AtNPCShopWindow`). What waits in its dock from the backpack goes back at once as it steps
  aside (`NextDock:SendBackBorrowed`, as when the merchant closes: found by the bug review, the sections slid out in the
  vendor's cards, gaps in the backpack, until the slide ended); a sale running in a card is cancelled then, what it sold
  sold, as when the merchant closes. Its own Shopping List leaves with it in its card (`OnHidden`, `NextDock:PanelHidden`).
  Blizzard's code hiding `MerchantFrame` (Escape, the panel manager) still ends the visit a frame later (the `Hide` hook,
  `EndVisitLater`), as `MerchantFrame_OnHide` does beside TSM without BetterBags.
- **`FollowTSM`** (returns `"aside"`, `"back"` or `"same"`): TSM's window up and the vendor not aside: it steps aside
  (`StepAside`: `aside`, then `Hide`). TSM's window down, the vendor aside, and TSM's choice no longer its window (its
  WoW UI button): it comes back (`StepBack`: as it opens, on Buy, drawn again, `offered` and `listOffered` cleared so what
  waits for the player docks again). TSM's window closed by its own close button or Escape ends the visit itself (TSM's
  `ACTION_FRAME_HIDE`, `CloseMerchant`); its choice is still its window, so the vendor stays away until
  `MERCHANT_CLOSED`. Nothing once the vendor asked to close (`closeRequested`). While shown, the header follows
  (`UpdateHeader`).
- **The TradeSkillMaster button** (`tsmButton`, last in the header, label "TradeSkillMaster", tooltip "Switch to
  TradeSkillMaster's vendor window"): shown while TSM is loaded (`UpdateHeader`), enabled once TSM's switch button is
  there (a frame after the merchant opens, told by `Look`). Its click (`SwitchToTSM`) opens TSM's window (`OpenWindow`)
  and looks at once (`Look`, which tells `FollowTSM`), so the vendor slides out in the same frame. Only during a visit
  (`atMerchant`, not `closeRequested`, not `closing`; else `"closed"`): found by the bug review, the button shows
  through the close's slide, and TSM's switch asks for no merchant, so a click there opened TSM's window with no vendor
  and saved it as TSM's choice. Its glyph is
  `IconSwap` (two arrows passing; `tools/textures/next_icons.py` `swap`), hand-drawn in Papercraft
  (`next_papercraft.py`, `icon_swap.png`) and an LCARS block in Make It So (`next_makeitso.py`, `block_swap.png`, peach),
  as every header button (next-themes.md §3). In a theme that puts the header in its bag button's menu it is listed by
  its label, as the vendor's other buttons.
- **The next merchant** opens as TSM's last choice says: TSM saves it for the account, so a switch made from either side
  holds on every character.
- **Enable Vendor Window off** (next-bagsystem.md §11g): nothing of this; Blizzard's frame and TSM's own switch buttons
  swap the two, as without BetterBags Next (`OnMerchantShow` returns before following).

## 4. TSM and the merchant frame's place in Blizzard's layout (`next/uipanels.lua`)

TSM writes `MerchantFrame`'s layout as it switches: its window opening, `xoffset` -32 and `width` 0
(`Move.SetDefaultUIOffScreen`); Blizzard's frame showing, `xoffset` 0 and `width` 336 (`Move.RestoreDefaultUI`,
`DEFAULT_ATTRIBUTES`), each followed by `UpdateUIPanelPositions(MerchantFrame)`. While the vendor stands in for the
frame (next-uipanels.md §27b), TSM's restore a frame after a merchant opened (Blizzard's frame its choice) gave the frame
its 336 back: the Character pane opened 368 past the vendor (measured with Blizzard's manager in
`spec/next/uipanels_spec.lua`: 968 for 600). And as the vendor stepped aside for TSM's window, `giveBack` put back what
it had read before TSM's write.

- **`NextUIPanels:Retake`** (returns whether it did): when the stand-in's `width`, `checkFitExtraWidth` or `xoffset` is no
  longer what `hold` left it with (read back after writing: a frame the manager has no entry for keeps nothing, and is
  never taken again), what another addon wrote becomes what it gets back (`standInWidth`, `standInFit`), and it takes no
  room again at the `xoffset` it has now. It runs in `PlaceLater`'s next frame, after the manager's layout (which every
  such write ends with), laying the panels out again when it took, so a Character pane already open moves back. While a
  stand-in is held it runs with no room too (found by the second bug review: a vendor chained on the backpack's right
  left the Character pane at 384 for 16).
- **`giveBack`** gives back the width and the fit each only while it is still what `hold` gave; another addon's stays.
- Both hold for the bank's and the guild bank's stand-ins too (checked on every client's manager by the second bug
  review: quiet at rest, read back unchanged at any scale); nothing but TSM is known to write a stand-in's layout.
  next-uipanels.md §27c.

## 5. Not verified in game

Any of it: there is no client here. To check, with TSM v4.15.x and BetterBags Next at full size: open a vendor with TSM
on its own window (TSM's window alone, the vendor not seen, selling by right click still works); click WoW UI (the vendor
slides in, the visit stays open); click the vendor's TradeSkillMaster button (TSM's window opens, the vendor slides out,
the visit stays open); close TSM's window with its X and with Escape (the visit ends); walk away from each; open the
Character pane (C) at each step (beside the vendor when it shows); repeat on a second character (the choice holds);
`/console taintLog 1` while buying in TSM's window and selling from the bags with the vendor aside. Not measured: what a
frame of `Look` costs at a vendor.

## 6. Left as it is

- **TSM's internals**: the saved choice's key, the switch button's extensions, and that `Button:Click` runs it are TSM
  v4.15.6's; a TSM that renames them leaves the button disabled (no switch found) or the vendor opening beside TSM's
  window, stepping aside a frame later. TSM offers no API for it (§2).
- **A switch inside one frame**: `Look` compares with the last frame, so a window that showed and hid between two frames
  is not seen. TSM's own two buttons cannot both be clicked in one frame; the vendor's button looks at once.
- **A click in a visit's first frame** (bug review, speculation): on a later visit in the same session TSM's switch
  button exists as the vendor opens, so its button is enabled before TSM's one-frame delay has run; clicked then, TSM's
  delayed `ACTION_SHOW_FRAME` would meet its own window and fail its `assert(not state.frame)` (`Core.lua:156`). It needs
  a click within a frame of the vendor starting to slide in. Not built for.
- **Coming back with the backpack closed** in the "right" chain layout: the vendor waits for the backpack it would chain
  to (`chain:WaitsForAnchor`, `AnchorWait`, a quarter second), then opens alone. Read from the code, not reproduced.
- **A Blizzard panel already open** sits where TSM's restore puts it for the one frame before `Retake` (it stayed there
  until the vendor closed before).
- **Back from TSM's window, every waiting category is offered again** (`StepBack` clears `offered`), one the player sent
  back before the round trip too: as a vendor opening.
- The button guard's `atMerchant` and `closeRequested` checks are untested by themselves: with the vendor shown, either
  comes with `closing` (second bug review).

## 7. Coverage

`spec/helpers/tsm.lua` models TSM v4.15.6's vendor window from its source (each piece cited there): `TSM_API`, the
protected settings table with the saved choice, the window a frame after the interaction (or Blizzard's frame with the
switch button made once and kept on `MerchantFrame`), its WoW UI button, the switch, its OnHide ending the visit unless
switching, its close button hiding the window but keeping it TSM's until the interaction ends (found by the bug review:
the model let go of it at once), and its writes to the merchant frame's place and layout (kept off the screen whenever
placed, as TSM's `SetPoint` hook does). The frame mock gained `Button:Click` (SimpleButtonAPIDocumentation; nothing on a disabled button
or one already clicking). `spec/integrations/tradeskillmaster_spec.lua`: nothing without TSM; the window, the choice, no
choice; the switch found among other children and again on another frame; opening with it (the choice saved, the visit
going on), not while the window is up, nothing before TSM made it; following: every frame, only changes, the switch
appearing, what each look saw. `spec/next/vendor_spec.lua` ("with TradeSkillMaster"): no button and nothing followed
without TSM; never opening with TSM's window chosen (no slide, no sound, before TSM's window shows), aside with the visit
going on and `MerchantFrame` shown; staying away as TSM lets go of its window with the merchant closing; back on WoW UI;
opening as before with Blizzard's frame chosen, the button enabled a frame later; stepping aside from the button and back,
ending nothing (its OnHide run); back on Buy, drawn again; the Shopping List docked again; TSM's window closed ending the
visit, the vendor staying away and following nothing after; Blizzard's code hiding `MerchantFrame` still ending it; the
close button as before; nothing from the button once the merchant closed or the close button was pressed; neither aside
nor back once the vendor asked to close; the next merchant as TSM's last choice says. "offering categories at a
merchant" ("stepping aside for TradeSkillMaster's window"): what waits sent back at once, docked again on coming back.
"switched off": nothing followed. "beside Blizzard's panels" ("with TradeSkillMaster", retail's own manager, TSM's
restore while the vendor slides in): the Character pane beside the vendor, TSM's width given back as the merchant
closes, TSM's layout kept as the vendor steps aside. `spec/next/uipanels_spec.lua`: retaken after another addon's width
(the Character pane 600, not 968), laid out again with the pane already open, after an x offset alone, chained on the
right; another addon's width and x offset kept as the vendor closes; nothing retaken while unchanged or for a frame the
manager has no entry for. `spec/sonata/next_themes_spec.lua`: the glyph shipped for `tsmButton` in Default, hand-drawn in
Papercraft, Make It So's 31 textures. Mutation-tested: 21 mutations of the vendor's, the integration's and
`NextUIPanels`' new guards, each caught (three survived the first pass and led to tests; one showed a reset nothing
read, removed).

Bug reviews: the first found the button working through the close's slide, the docked sections sliding out with the
vendor, four untested guards and the model's close; the second, aimed at those fixes, found `Retake` unreached with no
room. Each fixed test-first, above; what they left is in §6.
