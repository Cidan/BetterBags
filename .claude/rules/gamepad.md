---
paths:
  - "integrations/gamepad.lua"
  - "render/scrollbox.lua"
  - "frames/bag.lua"
  - "next/vendorbutton.lua"
  - "spec/integrations/gamepad_spec.lua"
  - "spec/integration/gamepad_spec.lua"
  - "spec/helpers/gamepad.lua"
  - "spec/render/scrollbox_spec.lua"
---
# WoW: Forever's Gamepad Interface (`integrations/gamepad.lua`)

Issue #1180: with WoW: Forever's Gamepad UI on, the d-pad could not move inside BetterBags' bags, and the right trigger
could not move from a vendor to them. The reply on the issue said Blizzard did not let addons in; the forever branch of
Blizzard's UI (1.60.1, read at build 70938) does: its gamepad UI has entry points written for addon code (§2), and
GW2_UI ships gamepad bags through them (`.libraries/GW2_UI`, `Core/API/utils.lua` `RegisterGamepadWindow`,
`Games/Shared/Inventory/itemButtons.lua`). Asked: "gamepad only is fine, but remember players can switch at will while
in game, handle this", for every window of both designs.

**Not seen in game.** Everything here is built from Blizzard's source and GW2_UI's; no Forever client was available.
§10 lists what only the game can show.

## 1. What it does

While the gamepad interface style is in use (`InputUtil.IsGamepadUIEnabled()`):

- Every open bag window (both designs' backpack and bank, BetterBags Next's vendor and guild bank) is in Blizzard's window
  list. The d-pad cursor moves over its buttons, A presses the selected one, B closes the window, and the triggers move
  to the window on the left or right (LT/RT; Blizzard's trigger hints show on the neighbours).
- The cursor lands only on what the windows mark (§5): items, BetterBags Next's vendor and guild bank buttons, tabs.
- X right-clicks the selected item: uses it, sells it at a merchant, moves it at a bank, as a right click does.
- Blizzard's input legend under the focused window says what A, X and B do.
- The radial menu's Bags opens and closes the backpack.
- Blizzard's own frames BetterBags stands in for (the bank, merchant and guild bank frames under
  `BetterBagsSneakyFrame`) are taken out of its window list, so the focus never lands on an invisible window.

On the mouse style every window is as it always was; switching either way at any time takes effect on the next frame.
In combat the bag windows leave Blizzard's gamepad navigation and come back after it (§4).

## 2. Blizzard's gamepad UI (the contract, `forever` branch)

- **Loaded on every Forever client, both styles:** `Blizzard_GamepadSmartNavigation` and `Blizzard_GamepadSharedUtility`
  (`AllowLoad: Both`), `Blizzard_Gamepad` (`AllowLoadGameType: camelot`). Live retail has none of them; `available()` in
  the module checks the globals, so the module does nothing elsewhere.
- **The window list:** `GamepadMode.FrameControlsManager:FrameShown(frame)` / `FrameHidden(frame)`
  (`FrameControlsManager.lua`). `FrameShown` sorts the list by center X and focuses the frame shown last; focusing calls
  the frame's `FocusGamepad` / `UnfocusGamepad` (through `securecallfunction`), opens Smart Navigation on it
  (`HandlePanelOpen`), and calls `ShowLeftJumpHint` / `ShowRightJumpHint` / `ShowFocusJumpHint` and their `Hide`s on the
  frames around it. The panel manager's `ShowUIPanel` / `HideUIPanel` broadcast (`UIParentPanelManager.ShowUIPanel` /
  `HideUIPanel`, whenever the frame `IsShown()`, even under a hidden parent) feed the list too.
- **Addon calls:** `FrameShown`, `FrameHidden`, `SmartNavigation:RefreshButtonGroups`, `SetTargetButtonForFrame` and the
  `SmartNavigation_*` marks are wrapped by `SecureHelper` (`SecureHelper.lua`): from addon code they run only while the
  combat restriction is off (`C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)`); else
  Blizzard calls `DisplayInterfaceActionBlockedMessage` (a chat line, once a session: `ChatFrameUtilOverrides.lua`) and
  does nothing. `Utility.lua`: these marks "may be set without causing taint (only while out of combat)".
- **The cursor:** `Utility.FindButtons` takes every Button, EditBox, or frame with an `OnMouseDown`/`OnMouseUp` script
  under the panel, each in the scroll frame closest above it (a `ScrollFrame`, or anything with a `ScrollTarget`). It
  does not skip frames marked ignored ("that must be done separately"): the cursor never moves to one
  (`IsButtonValid`), and `AttemptClose`'s fallback still looks at them. A moves `SmartNavigation:Click()`: the button's `OnSmartNavClick`, else `MouseDown` and
  `MouseUp` from secure code (a real left click for a secure item button). B is `AttemptClose()`: the frame's
  `SmartNavigationCloseHandler`, and when that does not handle it a click on the frame's `CloseButton`. Selecting runs
  `FocusEnter` (the button's `OnEnter`), `OnSmartNavSelect`, and the registry event `SelectedButtonUpdated` (dispatched
  through `securecallfunction`: addon callbacks are kept apart).
- **What addons must not touch:** Blizzard's prompt footers and binding groups (`CreatePromptedBindingFooter`,
  `GamepadMode.ActivateBindingGroup`). They bind keys with `SetOverrideBinding(UIParent, ...)` from a shared stack the
  gamepad action bars use in combat; addon code there would taint it. The legend (`InputPromptLegends`) is display only
  and is used (§6).
- **The radial menu:** its Bags entry calls `ToggleBackpack_Combined()`; its Character entry (a local
  `ToggleCharacterAndOpenBags`) calls `ToggleBackpack()`, which calls it, only when `IsBagOpen(Enum.BagIndex.Backpack)`
  reads false, to open the bags (`GamepadRadial.lua`); and `ToggleAllBags()` on the gamepad style calls it too
  (`ContainerFrame.lua`). `IsBagOpen` is Blizzard's own combined bag, shown (under `BetterBagsSneakyFrame`) or not.
- **A `CloseButton` an addon sets is clicked tainted:** `AttemptClose` clicks `activeFrame.CloseButton` with a comment
  saying it keeps the click tainted on purpose ("CloseButton may be a tainted reference"), and `HideUIPanel` refuses a
  tainted caller in combat (`CheckProtectedFunctionsAllowed`). So the windows have none (§6).

## 3. The scroll frame (`Scrollbox:SetGamepad`, `ScrollIntoView`)

Both designs put a window's content in `render/scrollbox.lua`'s `WowScrollBox`, made by addon code. Blizzard's cursor,
moving onto a button inside a scroll frame, scrolls that scroll frame (`SmartNavigation.lua` `HandleScroll`) through the
box's own methods, unguarded; an addon's box has methods and state addon code wrote, which taints the move, and
`SelectButton` refuses it (`EnsureIsSecure`). GW2_UI met this and left addon scroll boxes out of its navigation.

So while the gamepad style is on, a native `ScrollFrame` stands between the scroll child and the content
(render-pipeline.md §4): every button is found in it, the scroll frame closest above, and `HandleScroll` on a
`ScrollFrame` uses only the client's own methods (`GetVerticalScroll`, `SetVerticalScroll`). Nothing reaches past it,
so it never scrolls. The box is scrolled from BetterBags' code when the cursor moves (`SelectedButtonUpdated`):
`ScrollIntoView` brings the button into view, when it is in the content (`navFrame`): a tab outside it leaves the box
where it is. Blizzard's `MinimalScrollBar` sits beside the box; BetterBags Next's bar sits in it, and Blizzard finds its
frame and thumb there, both marked ignored, so the cursor never lands on anything in the box itself (the whole-addon
spec checks both designs: nothing navigable in the box, the content in `navFrame`).

It is put in (`Prepare`) and taken out (`Unprepare`) out of combat lockdown only: the classic bags' secure tab buttons
are under the content, and reparenting their ancestor is protected in combat.

## 4. The windows (`Gamepad:Add`, `Update`)

- **Added as made:** `BagSystem` hands every window it makes to `Gamepad:Add` (`CreateBackpack`, `CreateRest`, `make`;
  the other design's when it is switched to). `Gamepad:Init` runs before the bags are made (`core/init.lua`), `Enable`
  with the integrations.
- **One reconcile pass a frame later:** `Add` hooks the window's frame (`OnShow`, `OnHide`), its `Show` and `Hide`, and
  its scroll box's `Render`; each schedules `Update` on the next frame, through an `OnUpdate` driver of the module's own
  (GW2_UI: a `C_Timer` started from a hook on Blizzard's bag functions taints its gamepad UI). `Update` compares what is
  open (`IsShown() and not IsClosing()`) with what is in Blizzard's list: an open window is prepared (§3, §5, §6) and
  `FrameShown`; one that starts to close (BetterBags Next's slide out, the classic fade) or hides is `FrameHidden`; one
  that drew again has its new controls marked and `RefreshButtonGroups` called (Blizzard only rescans on `CreateFrame`,
  and the bags reuse their buttons). Windows join in the order they were added, so with several opening at once the last
  (an NPC's window: bank, vendor, guild bank) has the focus, the backpack one trigger away.
- **Combat: out of the list before the restriction (`LeaveForCombat`).** Under the restriction Blizzard refuses to take
  a window out of its list, and a window left in through combat and closed then stays in, hidden, with Blizzard's cursor
  in it: while its UI has the focus, A and B are its cursor's and the other face buttons and the d-pad are held by its
  catcher (`FrameControlsManager.lua`), so the controller drives an invisible window. So every window leaves the list
  (`FrameHidden`) and Blizzard's cursor forgets it (`SmartNavigation:RemovePanelInfo`) as the restriction comes:
  `ADDON_RESTRICTION_STATE_CHANGED` with `Activating` (dispatched before it is enforced, Blizzard's documentation), or
  `PLAYER_REGEN_DISABLED` if that comes first. No bag window can be navigated with the gamepad in combat; the mouse
  still reaches them. They join again on the next frame after `PLAYER_REGEN_ENABLED` (or the restriction's `Inactive`),
  if still open; a window opened in combat joins then. As they leave, their trigger hints are hidden (Blizzard hides
  hints only on the windows still in its list), the button Blizzard's cursor was on in each is kept (`lastButton`: the
  current button for the window that has the cursor, Blizzard's panel's `lastButton` for the others), and so is the
  window that has the cursor (`combatFocus`, read before the first `FrameHidden`, which hands the focus on). As they
  join, each is prepared again (what it drew in combat marked), the window that had the cursor joins last (Blizzard
  focuses the window it adds last), and the cursor is put back on each window's button if it still shows there
  (`RestoreCursor`, `SmartNavigation:SetTargetButtonForFrame`), and the kept focus is dropped once given back. A window
  that hides in the fight (not one only sliding out, which can be opened again before it hides), or the mouse style,
  forgets both: it opens fresh. A second `LeaveForCombat` (both of combat's events) keeps the focus the first read.
  Nothing Blizzard refuses is called from here, so the only refusal
  left is Blizzard's own `OnHide` hook asking to forget a window that closes in combat (§10).
- **Switching styles live (`INPUT_DEVICE_INTERFACE_TRANSITION`):** to the mouse, every window counts as out of the list
  at once (Blizzard forgets its list itself) and is put back on the next frame (`Unprepare`: hints and legend hidden, X
  unbound, at once even in combat; the content back under the scroll child out of combat lockdown only, as `Prepare`);
  to the gamepad, the open windows join on the next frame.
- **Blizzard's frames BetterBags stands in for:** a `UIParentPanelManager.ShowUIPanel` callback watches the panel
  shown for a few frames (`replaced`, `REPLACED_FRAMES`); once it hangs from `BetterBagsSneakyFrame` (the bank frame
  with Enable Bank Bags, the merchant and guild bank frames with BetterBags Next's) `Update` calls `FrameHidden` on it.
  The bank and merchant frames are moved before they show; BetterBags Next's guild bank moves Blizzard's under a tiny
  frame as it shows, and under `BetterBagsSneakyFrame` a frame later (`next/guildbank.lua` `OnShowUIPanel`). A panel that
  stays where it shows is let go after the last watched frame.

## 5. Where the cursor lands (`bbGamepad`) and A

`Prepare` walks the window once per render and marks ignored (`SmartNavigation_MarkFrameIgnored(frame, true)`, the frame
only: its children are still found) every frame Blizzard would find that is not marked for it, each frame once
(`marked`, weak). The marks: `bbGamepad = "item"` on the item buttons' interaction button (`frames/item.lua`; the
decoration behind it at the same place is ignored), `"vendor"` on BetterBags Next's vendor icon (`next/vendorbutton.lua`;
the card under it is ignored), `"guild"` on the guild bank's buttons (`next/guildbutton.lua`), `"tab"` on the classic
tabs' decoration, which takes their clicks (`frames/tabs.lua`), and on BetterBags Next's rail tabs (`next/tabs.lua`).
Everything else (header buttons, menus BetterBags builds, the search box, section headers a drag lifts, move bars,
scroll bars, money) is passed over: B closes, and Blizzard cannot navigate a menu an addon built.

A is Blizzard's click: a left click on an item (pick up, place) or a tab. A vendor button presses as Blizzard's merchant
gamepad prompt does (`MerchantFrame_SetupGamepad`: A buys, a right click): `OnSmartNavClick` clicks it right, or left
while an item is held (a sale), and `bbGamepadLabel()` (`GamepadLabel`) says which.

## 6. X, B, the legend and the hints

- **X** (`GAMEPAD_FACE_LEFT`, `PAD3`): `BetterBagsGamepadUse`, a `SecureActionButtonTemplate` with `type2 = "click"`; on
  every move to an item in the focused window (`Retarget`) its `clickbutton2` becomes that button and X is bound to it
  (`SetOverrideBindingClick(use, true, PAD3, name, "RightButton")`, set again each move so it is the last priority
  binding set). `SECURE_ACTIONS.click` clicks the item right from a key binding: a use, in combat too. Bindings and
  attributes cannot change in combat, so X is unbound as combat starts (`PLAYER_REGEN_DISABLED`, which comes before the
  lockdown) and bound again after: bound in combat, it would use the item it was bound to wherever the cursor went.
- **B** (`SmartNavigationCloseHandler`): puts back an item the cursor holds; else closes the window the way its close
  button does (`window:Hide(ctx)`), and says it handled it. The windows have no `CloseButton` for Blizzard to press
  (§2: clicked tainted, refused in combat), and in combat they are out of Blizzard's list, so B never reaches them.
- **The legend:** Blizzard's `InputPromptLegends.CreateInputLegend`, made with the window's other gamepad parts in
  `Prepare` (out of combat: a frame made under a window Blizzard's cursor knows has it look again, `RefreshButtonGroups`,
  refused in combat), shown under the focused window: TOPLEFT on the BOTTOMLEFT of what the window says is its foot
  (`GamepadFooter`: the classic bags' tab row while it shows, `frames/bag.lua`, which hangs below the window), else the
  window. Its prompts in Blizzard's footer order: A (`ACTION_LABEL_SELECT`, or `CONTEXT_ACTION_LABEL_BUY`/`SELL` from a
  vendor button), X on an item (`CONTEXT_ACTION_LABEL_USE`, `SELL` at a merchant, `MOVE` at a bank, `PLACE` at mail, a
  trade or an auction; greyed out as combat starts), B (`FRAME_ACTION_CLOSE`, `BACK` with an item held). Updated on
  focus, on every move, `CURSOR_CHANGED`, the NPC interactions and combat.
- **The hints:** Blizzard's `FrameLeftJumpHintTemplate`, `FrameRightJumpHintTemplate`, `FrameFocusJumpHintTemplate` on
  each window, shown when Blizzard's list asks (§2), and hidden by BetterBags as a window leaves the list (closing, or
  for combat): Blizzard clears them only on the windows still in it.

## 7. The radial menu (`OnRadialToggle`, `FollowBlizzardBackpack`)

Hooks on `ToggleBackpack_Combined`, `ToggleBackpack`, `ToggleCharacter` and `ToggleAllBags` note what ran this frame;
on the next frame:

- `ToggleAllBags` ran: nothing (on the gamepad style Blizzard's `ToggleAllBags` calls `ToggleBackpack_Combined`, and
  BetterBags' own hook on `ToggleAllBags` toggles the bags already).
- `ToggleBackpack` and `ToggleCharacter` ran (the radial's Character entry, which calls `ToggleBackpack` only when
  `IsBagOpen(Enum.BagIndex.Backpack)` reads false, then `ToggleCharacter`): the backpack follows Blizzard's own, asked
  open or closed as BetterBags' interaction windows ask (`backpackShouldOpen`/`backpackShouldClose`, `bags/OpenClose`),
  not toggled: a backpack sliding out shows, and a toggle closed it again. A backpack BetterBags opened itself (its own
  button, a vendor) stays open.
- Else (the radial's Bags, or a Toggle Backpack key, which calls `ToggleBackpack` alone, `Bindings_Camelot.xml`): the
  bags toggle (`addon:ToggleAllBags`), whatever Blizzard's own reads. Following Blizzard's there would take an extra
  press whenever the two disagree (BetterBags opened itself, or B closed BetterBags' window only).

Nothing on the mouse style.

## 8. Diagnostics

`Gamepad:Dump()` goes in `/bbdb`'s dump (`debugDumpExtras.gamepad`, data-driven.md): the style, the restriction,
`combat`, `waiting`, Blizzard's list (`shown`) and focused window, the selected button and its kind, the item X uses, and
each window's `shown`, `closing`, `registered`, `focused`, `prepared` and whether its content is in the native scroll
frame, and the panels it is watching to take out (`replaced`), and what it keeps through a fight: the window that had
the cursor (`combatFocus`) and each window's button (`lastButton`). Its methods return what they did (`Add`, `Update`,
`Prepare`, `Unprepare`, `LeaveForCombat`, `RestoreCursor`, `OnRestrictionChanged`, `FollowBlizzardBackpack`,
`OnPanelShown`, `Retarget`, `UpdateLegend`, `OnTransition`), so a capture's call trace shows each step.

## 9. Coverage

- `spec/helpers/gamepad.lua`: Blizzard's gamepad UI ported from the forever branch (the window list, Smart Navigation's
  finding, selecting, clicking and closing, `AttemptClose`'s fallback to a button named like a close button, the marks,
  the combat refusal and its count, `RemovePanelInfo` wrapped as Blizzard's is, `SetTargetButtonForFrame`, the panel
  manager's broadcasts, `UIPanelCloseButton` through `HideUIPanel`, `ToggleBackpack`, `ToggleBackpack_Combined`,
  `IsBagOpen` on the combined bag, `ToggleCharacter` as a stand-in, the legend, the hints). The whole-addon helper
  installs it on every Forever client, mouse style unless `opts.gamepad`, with Blizzard's combined bag hidden as the
  client starts it. `spec/helpers/wow_mocks.lua` gained `Click`, `MouseDown`/`MouseUp`, `FocusEnter`/`FocusExit`, a
  `ScrollFrame`'s scroll, override bindings, `SecureActionButtonTemplate` (the click action) and
  `C_PlayerInteractionManager.IsInteractingWithNpcOfType`.
- `spec/integrations/gamepad_spec.lua`: joining and leaving, what the cursor can land on, redraws, the replaced frames
  (moved a frame later, never moved, taken out as combat comes), combat (leaving at either event, staying out until it
  ends, nothing refused, hints hidden, what was drawn in it marked, the cursor and the focus put back, a place
  forgotten when the window closes or its button goes), switching styles both ways and
  in combat, X (bound, then unbound off an item, and around combat), B (handled, never falling to Blizzard's fallback),
  the legend (labels, greyed X, its foot), the hints (and on a window that starts to close), scrolling to the selection
  and not for a tab, the radial (Bags, Character, a Toggle Backpack key, a slide out, each frame read afresh,
  `ToggleAllBags`), the dump.
- `spec/integration/gamepad_spec.lua`: both designs' real backpack on the whole addon (only marked buttons navigable,
  nothing navigable in the box, the content in `navFrame`, styles switched while open, the radial), BetterBags Next's
  backpack reopened by the Character entry as it slides out, the classic legend under the tabs, the bank frame, the
  mouse style. The mocks draw no item buttons there; items in `navFrame` are the unit spec's.
- `spec/render/scrollbox_spec.lua` (§3), and the marks: `spec/frames/item_spec.lua`, `spec/frames/tabs_spec.lua`,
  `spec/next/tabs_spec.lua`, `spec/next/guildbutton_spec.lua`, `spec/next/vendorbutton_spec.lua`;
  `spec/bagsystem_spec.lua` (every window handed over), `spec/core/init_spec.lua`, `spec/frames/debug_window_spec.lua`.

## 10. Only the game can show

- A window that closes in combat (the bags' key, Escape, a merchant closing): it is out of Blizzard's list by then, but
  Smart Navigation hooked its `OnHide` when its cursor first came in, and that hook asks to forget it from whatever code
  hid it, BetterBags' here, which Blizzard refuses under the restriction: its "Interface action failed" chat line, once
  a session (`DisplayInterfaceActionBlockedMessage`). Nothing else follows from it. GW2_UI has the same path.
- Whether `ADDON_RESTRICTION_STATE_CHANGED` (`Activating`) or `PLAYER_REGEN_DISABLED` comes while Blizzard still takes
  the calls in every way combat starts. If neither does (combat already on at login or after a loading screen), the
  windows stay in the list until combat ends, the case §4 describes.
- Blizzard's `FrameHidden` stops a spell waiting for a target (`SpellStopTargeting`) when its list empties. With only bag
  windows in the list, the windows leaving for combat would cancel a spell waiting for an item when combat starts.
  Blizzard does the same when the player closes the last window.
- Whether a priority override binding of `PAD3` set after Blizzard's own fall-through block wins (GW2_UI ships this).
- How the cursor moves across sections of different widths (Blizzard's direction search, not its grid mode: the bags
  are no strict grid).
- How Blizzard's legend and hints look beside each theme (Blizzard clamps the legend to the screen,
  `CreateInputLegend`), and whether the native scroll frame changes how the content draws against the window's other
  layers (frame levels after `SetParent`).

## 11. The bug reviews

The first review found, and each was fixed test-first:

1. A window closed in combat stayed in Blizzard's list, hidden, with its cursor in it (§4): the windows now leave the list
   before the restriction. The mock's `RemovePanelInfo` was not wrapped, so the spec said nothing was refused.
2. B in combat clicked a `CloseButton` Blizzard clicks tainted, which `HideUIPanel` refuses: the close button is gone.
3. Blizzard's guild bank frame stayed in the list on the first visit of a session: it is moved out of sight a frame after
   it shows; handed-over panels are now watched for a few frames.
4. Moving to a tab scrolled the content: only buttons in `navFrame` scroll the box.
5. The classic legend covered the tab row: it hangs under `GamepadFooter`.
6. The radial's Character entry closed a backpack BetterBags had opened: it now follows Blizzard's state (§7).
7. Switched to the mouse in combat, the hints stayed until combat ended: only the content move waits.
8. A legend made on first focus in combat would have Blizzard look again, refused: it is made in `Prepare`. The second
   review found this could not happen (Blizzard's `FrameShown` focuses each window it adds, out of combat); the legend
   stays made in `Prepare`, with the window's other parts.

Five tests asserted less than they said (X unbound off an item never bound first; the greyed X never laid out; the
whole-addon test's scroll frame check never ran; the two combat close tests passed only on the mock's gaps): rewritten.

The second review, of those fixes, found, and each was fixed test-first:

1. The trigger hints stayed drawn on the windows that left for combat, and on a window sliding out: hidden as they leave.
2. What a window drew in combat was never marked (it was `prepared`, and `OnRendered` marked only listed windows):
   windows are prepared again as they join, and a prepared window's redraw is always `dirty`.
3. Following Blizzard's backpack on any `ToggleBackpack` made a Toggle Backpack key take two presses once the two
   disagreed: only the Character entry (`ToggleBackpack` with `ToggleCharacter`) follows it.
4. The cursor's place was lost across every fight (`RemovePanelInfo`): kept and given back (`RestoreCursor`).
5. The Character entry during a slide out left the backpack closing (a toggle reads a shown panel as open): it asks for
   the backpack open or closed.

Tests it found not pinning their fix were tightened (a tab test whose tab was already selected; a legend test that could
not fail, removed; the combat guards in `Update` and `LeaveForCombat`, the replaced panels as combat comes, the flags read
afresh each frame, and B's handled result, each now tested).

The third review, of those fixes, found, and each was fixed test-first:

1. A place kept for a window that closed in the fight steered the cursor on a later open: a closed window forgets it.
2. After combat the focus went to the window added last, not the one that had it: that window joins last.

It also found five fixes no test pinned (the two halves of re-preparing, one alone enough: `OnRendered` went back to
listed windows only; the `ToggleCharacter` flag's reset; `RestoreCursor`'s check for a button gone in the fight; the place
kept in a window without the cursor): each now has a test, and a mutation of each fails the unit spec.

The fourth review, of those two fixes, found a window only sliding out (opened again before it hid, as both designs'
windows can be) treated as closed, losing its place and the focus: they are forgotten only once it hides. It also found
the kept focus's clears (on joining, on hiding, on the mouse style, and not overwriting it on combat's second event)
untested: each now has a test, and a mutation of each fails the unit spec. This last fix adds no state, so no fifth
review was run.

Left as speculation: Blizzard's `HideActiveFrames` would loop on a hidden window left in its list (nothing in build
70938 was found to reach it, and §4 keeps the windows out of the list in combat); `SpellStopTargeting` as the windows
leave for combat, and the frame levels after reparenting (§10); `ToggleBackpack` and `ToggleCharacter` run in one frame
by something other than the radial (two keys at once, another addon) reading as the Character entry; and the cost of
marking a window's controls on every open (`Prepare` walks the window), not measured in a client.
