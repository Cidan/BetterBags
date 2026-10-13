# Pure Presentation Item Button Drawing Rules

This document defines the architectural guidelines, design decisions, and API contracts for item button drawing in BetterBags.

## Architectural Guidelines

### 1. Pure Presentation Principle (Dumb Visual Layers)
Item buttons (e.g. `frames/item.lua` and `frames/era/item.lua`) must act as pure presentation layers with zero business logic.
- **Rule:** An item button does not decide *how* many items are stacked, *whether* a vendor is open, or *if* a slot is an upgrade. It only accepts a pre-resolved, pre-computed `ItemData` node and updates its visual elements (icon, count text, item level, quest glow, cooldown) synchronously.

### 2. Fully Decoupled API Signatures
Historically, item buttons queried the central inventory database (`data/items.lua`) on-the-fly inside their internal drawing methods. This caused state leakage, race conditions, and heavy overhead.
- **Rule:** All drawing methods on `itemProto` (e.g., `UpdateCount`, `DrawItemLevel`, `UpdateCooldown`, `UpdateUpgrade`, `UpdateNewItem`) must accept an optional `data` parameter.
- **Fallback:** If `data` is omitted, the method can safely fallback to `self:GetItemData()` for backward compatibility, but all internal drawing sequences within the refresh pipeline must pass `data` directly.

### 3. Upstream Pre-computations (Zero On-the-Fly Database Queries)
Attributes like stacked counts or upgrade arrows are computationally heavy and highly dependent on active options (e.g., merging partial stacks, merging unstackables, merchant interaction state, simple item level options).
- **Rule:** The displayed count (`data.stackedCount`) and upgrade status (`data.isUpgrade`) must be computed upstream during the Stacking and Farming phases (Phases 2 & 3).
- **Count Text:** Inside `UpdateCount(ctx, data)`, the count text is populated directly from `data.stackedCount or data.itemInfo.currentItemCount`. No database stacking state is evaluated.
- **Upgrade Icon:** Inside `UpdateUpgrade(ctx, data)`, the upgrade icon uses `data.isUpgrade` directly. The data layer (`data/items.lua`) pre-computes `data.isUpgrade` using registered upgrade providers (e.g. BetterBags, Pawn, SimpleItemLevel) upstream, ensuring no raw slotkey-to-database queries are made during layout rendering.

### 4. Code Consistency and Unification Across SKU Environments
BetterBags supports multiple World of Warcraft environments (Classic/Era vs. Retail) utilizing a single, unified codebase for its item frames (`frames/item.lua`).
- **Rule:** We do not maintain separate `frames/era` files. Both environments must utilize the exact same decoupled, parameter-passing design in `frames/item.lua`.

### 5. Handling Classic vs Retail ItemButtonMixin Divergence
While Blizzard backported the `ContainerFrameItemButtonTemplate` XML to Classic/Era, they did **not** backport all of the modern Lua `ItemButtonMixin` methods. This causes silent failures or nil-reference crashes if not handled carefully.
- **Rule:** All modern `ItemButtonMixin` method calls must be explicitly guarded. Do not assume `decoration:UpdateQuestItem()` exists.
  ```lua
  if decoration.UpdateQuestItem then decoration:UpdateQuestItem(false, nil, nil) end
  ```
- **Texture Setting:** Classic does not have `decoration:SetItemButtonTexture(tex)`. You must fallback to the global function:
  ```lua
  if decoration.SetItemButtonTexture then
      decoration:SetItemButtonTexture(tex)
  else
      SetItemButtonTexture(decoration, tex)
  end
  ```
- **UpdateCooldown:** Classic uses `ContainerFrame_UpdateCooldown(bagid, button)` instead of the mixin `UpdateCooldown` method. `SetItemFromData` must always go through `itemProto:UpdateCooldown(ctx, data)` (which picks the right one) rather than calling `decoration:UpdateCooldown` behind an existence guard — the guard silently skipped cooldowns on Classic at draw time, so they only appeared after the next `BAG_UPDATE_COOLDOWN`.
- **Quality Borders / glow:** Blizzard's Classic `SetItemButtonQuality` (`Blizzard_ItemButton/Classic/ItemButtonTemplate.lua`, classic_era and classic branches) has its quality-color block commented out and unconditionally ends with `button.IconBorder:Hide()`, so Classic's own bags draw **no** quality border at all. Retail's `SetItemButtonQuality_Base` only draws a border when `ColorManager.GetColorDataForBagItemQuality(quality)` returns a color — i.e. Uncommon+ only; Poor/Common get none. BetterBags therefore draws its own quality indicator on both clients:
  - **Items → `itemProto:DrawQualityGlow(decoration, quality)`** (called from `SetItemFromData` after `SetItemButtonQuality`, retail and Classic alike), driven by the per-kind **"Quality Glow Intensity" slider** (`database:GetGlowIntensity(kind)`, 0–100). This slider replaced the old binary "Extra Glowy Item Buttons" checkbox (`GetExtraGlowyButtons`). The mapping (all colored by `const.ITEM_QUALITY_COLOR[quality]`, **Uncommon+** only — **Poor/Common** always `IconBorder:Hide()`):
    - **intensity 0** → hide the border entirely (no color, no glow).
    - **1 … `const.GLOW_INTENSITY_HALO_THRESHOLD` (60)** → a **flat colored border** (`Interface\Common\WhiteIconFrame`, `BlendMode "BLEND"`, full 0–1 texcoord), alpha = `intensity / threshold`, so it fades in and is a **solid** border at exactly 60 — no glow yet.
    - **61 … `const.GLOW_INTENSITY_MAX` (100)** → the **additive glowing halo** (`Interface\Buttons\UI-ActionButton-Border`, `BlendMode "ADD"`, center texcoord), alpha ramping from a clearly-visible floor `HALO_MIN_ALPHA` (0.4, `frames/item.lua`) at 61 up to a blinding `1.0` at 100. The floor makes the halo obviously present the instant it turns on ("extra glowy at 61%") rather than fading up from invisible.
    - **Migration** (`DB:Migrate`, Q3'27 block): the retired per-kind boolean `extraGlowyButtons` maps once to `glowIntensity` — **on → `GLOW_INTENSITY_MAX` (100)**, **off → `GLOW_INTENSITY_DEFAULT` (60)** — then the old field is dropped. Default for fresh profiles is **60** (`const.DATABASE_DEFAULTS.profile.glowIntensity`). `DB:SetGlowIntensity` rounds and clamps to `[0, 100]`.
    - **Classic phantom-frame obscuring the glow (the real "no border on Classic" cause):** `DrawQualityGlow` writes to `decoration.IconBorder`, and the decoration is anchored **one frame level below** the interaction button (`decoration:SetFrameLevel(self.button:GetFrameLevel() - 1)` in `SetItemFromData`). On Classic, `self.button`'s own `NormalTexture` (`Interface\Buttons\UI-Quickslot2`, a 64×64 beveled slot frame) is **re-shown by Blizzard's drag/update logic** after our creation-time `Hide()`, and being on the higher frame level it draws **over** the decoration's border/glow, hiding it — so the quality indicator looked completely missing on Classic even though `DrawQualityGlow` ran correctly. A plain `Hide()` loses to the re-show; the fix (end of `SetItemFromData`, gated `not addon.isRetail`) clears the **texture value** itself — `self.button:GetNormalTexture():SetTexture(nil)` — so nothing renders even when Blizzard re-shows the region. With the obscuring frame gone, the flat border and additive halo (and the whole intensity slider) are visible on Classic **exactly as on retail** (no Classic-specific glow/border code path is needed — retail and Classic both rely on `DrawQualityGlow`). Retail has no such re-show and is left untouched by the gate.
  - **Free slots → `itemProto:DrawClassicQualityBorder(decoration, quality)`** (called from `SetFreeSlots` on non-retail with the bag's quality). It draws a thin colored `WhiteIconFrame` border **only for Uncommon+** bag quality (special bags), and **hides** it for Poor/Common. Previously it showed a **white** border for Common free slots, which double-bordered the `UI-Backpack-EmptySlot` texture (its own frame) and read as an offset/double frame on Classic — the reported free-slot bug.
  - `spec/frames/item_classic_spec.lua` carries a source-faithful mock of the Classic `SetItemButtonQuality`; fix the code, not the mock. Coverage: the same spec ("draws no quality border at glow intensity 0", "draws a solid colored border (no additive halo) at intensity 60", "fades the solid border alpha with intensity below 60", "switches to the additive halo above 60 (extra glowy at 61)", "uses a full-intensity additive halo at 100", "draws no quality border for common items", "does NOT border a plain (common) free slot"), plus `spec/database_spec.lua` ("glow intensity") and `spec/database_migration_spec.lua` ("extra glowy boolean -> glow intensity migration").
- **Bag Kind:** `item.kind` drives item-level options, the quality glow intensity, and Masque groups. It is derived from the bag ID via `const.BANK_BAGS` **and** `const.ACCOUNT_BANK_BAGS`; checking only `BANK_BAGS` classified every Warbank button as backpack.
- **UpdateExtended:** Calling `UpdateExtended()` on Classic clients causes the engine to flag the button as an extended slot (e.g. Reagent bag), which incorrectly applies a blue `ExtendedOverlay` tint to the item. This must be guarded strictly behind `if addon.isRetail then ... end`.
- **Bank tooltip dispatch (main bank container, bag id -1):** BetterBags renders every bank slot — including the 28 main-bank container slots (bag id `-1`) — with `ContainerFrameItemButtonTemplate` buttons. On non-retail clients the template's native `OnEnter`/`UpdateTooltip` shows the tooltip via `GameTooltip:SetBagItem(GetParent():GetID(), GetID())`, i.e. `SetBagItem(-1, slot)` for the main bank. Blizzard's own Classic/TBC bank UI never uses that path; `BankFrameItemButton_OnEnter` (`Blizzard_UIPanels_Game/TBC/BankFrame.lua`) uses `GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))` instead. Feeding a main-bank slot through `SetBagItem(-1, ...)` on a cold/evicted item cache produces a degenerate "vendor price only" tooltip (the sell price is a money child-frame that survives a sparse `tooltipData`, while the name/stat lines are missing), and Classic never registers `TOOLTIP_DATA_UPDATE`, so the 0.2s tooltip poll just re-runs the same broken call. **Rule:** on `not addon.isRetail`, replace the button's `OnEnter` and `UpdateTooltip` with `itemProto:UpdateTooltip`, which calls `BankFrameItemButton_OnEnter(self.button)` when `self.button:GetParent():GetID() == -1` and `ContainerFrameItemButton_OnEnter(self.button)` otherwise, and install `button.GetInventorySlot = ButtonInventorySlot` so the bank handler can translate the slot. The `SetScript("OnEnter", ...)` is set *before* the highlight and `i:OnEnter` `HookScript`s so those still layer on top. Retail's `ItemButtonMixin:OnEnter` resolves bank slots correctly (via `GetSlotAndBagID`) and is left untouched. This dispatcher was lost when `frames/era/item.lua` was folded into the unified `frames/item.lua` (commit `aa6eeeb`, PR #1044) and restored afterward; coverage in `spec/frames/item_classic_spec.lua` ("bank tooltip dispatch on Classic").

### 6. The "Blue Glow" Empty Slot Taint (Classic UI Quirk)
In Classic clients, free/empty slots must be handled explicitly to prevent default XML textures from bleeding through as a glowing blue ring.
- **Missing Backgrounds:** Retail uses `ItemSlotBackgroundCombinedBagsTemplate` to provide a background for empty slots. Classic does not have this. When setting a free slot in Classic, you **must** explicitly set the icon texture to `[[Interface\PaperDoll\UI-Backpack-EmptySlot]]` or the slot will be completely transparent.
- **Bleed-through Textures:** `ContainerFrameItemButtonTemplate` natively includes a `NormalTexture`, `PushedTexture`, `BattlepayItemTexture`, and `NewItemTexture`. If the slot is empty (transparent), these default textures will bleed through and create a persistent blue glow.
- **Rule:** When instantiating the blank `decoration` frame in `themes/themes.lua`, you must immediately and explicitly hide all of these textures:
  ```lua
  if button.GetNormalTexture and button:GetNormalTexture() then
    button:GetNormalTexture():SetTexture("")
    button:GetNormalTexture():Hide()
  end
  if button.GetPushedTexture and button:GetPushedTexture() then
    button:GetPushedTexture():SetTexture("")
    button:GetPushedTexture():Hide()
  end
  if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
  if button.NewItemTexture then button.NewItemTexture:Hide() end
  ```
- Additionally, explicitly call `decoration.ExtendedSlot:Hide()` during `SetFreeSlots()` to suppress the default quickslot background glow.

### 7. Zero Dynamic Frame Allocations (Virtual Item Button Pool)
Virtual slot keys (like `"Container"`, `"Reagent Bag"`, or aggregated free space buttons) must never trigger `CreateFrame` dynamically on the fly during layout drawing.
- **Pre-allocation:** All virtual item buttons are pre-allocated during `itemFrame:OnEnable()` into `itemFrame.virtualPool`.
- **Every physical button exists from boot (taint).** `itemFrame:OnEnable()` also creates a button for every bag and slot the player could ever have: 40 slots for each backpack and character bank bag, 98 for each Warbank tab and the reagent bank. Item buttons cannot be created on the fly: creating them later taints. So buttons are never created lazily, not even for the bank, although this is most of BetterBags' remaining login cost (a captured login: about 256 ms for 1,010 buttons, inside the loading screen, where it is not a visible hitch).
- **Acquisition & Release:** `itemFrame:GetButton(ctx, slotkey)` acquires a virtual button from `virtualPool` via `itemFrame:AcquireVirtualItem(ctx, slotkey)`. When views wipe or release item frames (`item:Wipe(ctx)`), virtual buttons are unmapped from `buttonsBySlotkey` and returned to `virtualPool`.

### 7a. Redrawing a Button Without Releasing It
A button drawn in consecutive passes is no longer released in between (layout-rendering.md §1), so the reset the release used to do before every draw (`ClearItem`) no longer happens.
- **Mode tracking:** `item.drawnAs` records what the button last showed: `"item"`, `"empty"` (`SetItemFromData` with `isItemEmpty`) or `"free"` (`SetFreeSlots`). When a draw changes it, the draw first calls `item:ResetVisuals(ctx)`, the visual half of `ClearItem` (textures, quality, count, quest/junk/new-item state, cooldown, overlay, enable state, item level text, upgrade icon, free-slot fields, `currentData`/`kind`). `ClearItem` is now `item/Clearing` + take the frame off screen + `ResetVisuals` + `ResetSize` + clearing `stacks`/`staticData`; size and static data stay out of `ResetVisuals` because item rows set them before their first draw (`SetSize` then `SetStaticItemFromData`).
- **Same-kind redraws set everything themselves.** `SetItemFromData` sets every visual an item can have; `SetFreeSlots` sets every free-slot visual, and when drawn without a count (`nocount`, the "show all free space" path) it clears a count left by the previous draw with `minDisplayCount` 1 before setting -1, because Blizzard's `SetItemButtonCount` shows any count above the minimum (`Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua`), so 0 would read "0" under -1. Any new visual added to one of the two must be set on every draw of that kind, or reset in `ResetVisuals`.
- **Idempotent release:** `item:Wipe` does nothing when the button has not been drawn since its last release (`item.released`, cleared by every draw and by `AcquireVirtualItem`).
- **Decoration lookups are cached** (`themes:GetItemButton`, default decoration path): a button resolves its decoration once per applied theme (`themes.decorationGeneration`, bumped by `ApplyTheme`, which hides every decoration) and per active theme table; that first lookup shows it and sends `item/NewButton`. Before, every one of the ~10 lookups per button per redraw called `Show()` and sent `item/NewButton`, and Masque (`integrations/masque.lua`) re-added the button on each. A theme with its own `ItemButton` (ElvUI) is asked on every lookup, because it re-applies fixups there: ElvUI re-pins its backdrop's frame level, so `FinishItemDraw` looks the decoration up once more after setting the decoration's level, on full and skipped draws alike, keeping the re-pin the last thing a draw does.
- **Masque re-skins redrawn buttons.** Masque's `AddButton` returns early for a button already in the group (Masque 12.1.0 `Core/Group.lua`), and a button is no longer removed (`item/Clearing`) before each redraw. The integration remembers which group each decoration was added to and calls `group:ReSkin(decoration)` on `item/Updated` (sent by both `SetItemFromData` and `SetFreeSlots` after `item.kind` is set) for a decoration already in it, so Masque's skin is re-applied over BetterBags' quality border on every full draw, as the old remove-then-add did. A skipped redraw (§7b) sends no `item/Updated` and needs no re-skin, because it does not touch the border either. A released button stays in its group: item buttons exist for the whole session, and Masque's `RemoveButton` is a full skin pass restoring the default look that the button's next draw undoes with another (leaving Show Bags spent 9.5 ms un-skinning 145 empty-slot buttons). The integration does not listen to `item/Clearing`; a released button's next draw re-skins it, or `AddButton` moves it when it is reused for the other bag. Coverage: `spec/integrations/masque_spec.lua`.

### 7b. Skipping a Redraw Whose Inputs Are Unchanged
After a one-slot change (using a potion) every button on screen was still redrawn in full: `SetItemFromData` costs roughly 70 µs per button in the client (about 2 ms for 29 buttons in a profiled refresh), all but one of them redrawing exactly what they showed.
- **Rule:** each button records in `item.drawState` the inputs of its last full draw, and a redraw whose inputs all match skips the setters (`item:DrawInputChanged` / `item:FreeDrawInputChanged`, `frames/item.lua`, which return the name of the first input that differs, or nil to skip). They are `Item` methods so the profiler's call trace records the reason for every draw (data-driven.md).
- **Item inputs:** the item's `itemHash` (item ID, enchant, gems, bonus IDs, binding, item level and stats; `itemHash` itself is untouched, since virtual stacks, `BuildOrderedItems` and the stack-sell lookup key on it), plus every other field the setters read: link, icon, quality, bound, current item level, class (item level display), `stackedCount` and `currentItemCount` (the count shown, including a virtual stack's total), new and battle-pay flags, quest item/ID/active, readable, no-value, the applied search match (the live result, else the client's filter), `isUpgrade`, `itemContextMatchResult`, the bag ID, and `drawGeneration` (data-loader.md §17: a new one after every wipe sweep). Also `itemFrame.styleGeneration`, bumped by `itemFrame:RestyleButtons()` when a setting the setters read changes with no new data (glow intensity, item level display; refresh-scheduler.md §9), and the decoration object and `themes.decorationGeneration`, so a theme change redraws. Free slots record the style and decoration generations too.
- **Free-slot inputs:** count, whether the count is shown, empty-slot name, family glyph, quality, bag ID, decoration and theme generation.
- **What still runs on a skip:** `currentData`, `slotkey`, `kind` and the decoration's `_itemData` point at the new data; `FinishItemDraw` keeps the decoration one level below the interaction button (then looks it up again for theme fixups, §7a), clears the Classic slot texture Blizzard re-shows, and shows the frames; and a new item still goes through `UpdateNewItem`, because a full draw replays the one-shot flash whenever the looping glow has stopped.
- **What clears the record:** `ResetVisuals` (a release, or a change between item, free slot and empty slot) and `Lock`. Every guard here is pinned by a test that fails without it. `UpdateSearch` (the live search box applying a result imperatively) updates the record's search match to what it applied, so a later sweep compares against what the button actually shows. Item rows (`staticData`) never skip.
- **Cooldowns** are not part of the inputs: they change without the item changing and are refreshed by `BAG_UPDATE_COOLDOWN` and on bag open (event-buckets.md §3).
- **`item/Updated`** is now sent only by full draws, i.e. when a button actually changed (the integrations README notes this).
- Any new visual a setter applies must either be derived from a recorded input or be added to the record; otherwise a skipped redraw leaves it stale.
- **Coverage:** `spec/frames/item_spec.lua` ("skipping a redraw whose inputs are unchanged": one redraw per changed input, theme generation, decoration identity, release, Classic texture; "skipping a free-slot redraw…") and `spec/frames/bag_draw_ownership_spec.lua` ("fully redraws only the button whose item changed (using a potion)").
- Coverage: `spec/frames/item_spec.lua` ("redrawing without a release", idempotent release tests), `spec/frames/bag_draw_ownership_spec.lua` (free-slot count and enable state across passes), `spec/themes_spec.lua` ("GetItemButton decoration cache").

### 8. Upstream Pre-Computation of ItemContextMatchResult
Evaluating whether an item is valid for active interactions (e.g. bank, merchant, scrapping, or account bank tabs) is pre-computed during data enrichment (`Phase6_EnrichData`) and stored as `data.itemContextMatchResult`.
- **Pure Drawing:** `itemFrame.GetItemContextMatchResult(item)` reads `data.itemContextMatchResult` directly. It performs zero on-the-fly `ItemLocation:CreateFromBagAndSlot` object instantiations, zero `C_Bank.IsItemAllowedInBankType` calls, and zero global addon state queries during draw.
- **Bank-tab switches must re-sweep the backpack.** `items:ResolveItemContextMatchResult` (`data/items.lua`) resolves a backpack item's grey-out against the *currently active bank tab*: it reads `addon.atBank`, `addon.Bags.Bank.bankTab`, and (for Warbank tabs) `C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, ...)`. Because that resolution happens only during a backpack data sweep (`Phase6_EnrichData`) and is then frozen into `data.itemContextMatchResult`, changing the active bank tab does **not** by itself update the backpack grey-out. Firing `ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)` re-runs each drawn button's `UpdateItemContextMatching`, but that only re-reads the already-committed (now stale) `data.itemContextMatchResult` — so the grey stays put.
  - **Failure mode (fixed):** open bags, open bank on the Warbank group tab (backpack items disallowed in the Warbank correctly grey out), then click the Bank (Character) group tab — the grey stayed until a manual bag Sort forced a backpack refresh.
  - **Rule:** every retail bank-tab switch path (`bank.proto:SwitchToGroup` and `bank.proto:SwitchToBlizzardTab`, `bags/bank.lua`) must set `self.bag.bankTab` to the newly active tab *and* `events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = false })` (gated on `addon.atBank`; a recalculation, refresh-scheduler.md §10) after updating the bank type, so the backpack re-sweeps and recomputes `itemContextMatchResult` against the new tab. `SwitchToGroup` already set `bankTab` from `group.bankType`; `SwitchToBlizzardTab` did not (it only set `blizzardBankTab`), so it now also assigns `bankTab = bagIndex`. The extra backpack refresh is a stateless, idempotent clean-sweep, so the redundant refresh triggered by the initial-open `SwitchToGroup` call redraws identical content (no flicker). Coverage: `spec/bags/bank_context_refresh_spec.lua`.

### 9. Upstream Pre-Computation of Search Filtering
Active search query evaluation is performed upstream during the data sweep phase (`Phase8_EnrichCategories`, right after `search:SyncKind` brought the index up to date for this sweep) and attached to item nodes as `data.isSearchResult`. It must not run in `Phase6_EnrichData`, which executes before re-indexing and would evaluate the query against the previous sweep's index.
- **No Draw-Phase Search Execution:** Late-stage search evaluations at the end of frame drawing (e.g., querying `searchBox:GetText()` inside `bag.lua` during `Draw`) are completely removed. Item buttons update their search alpha synchronously from `data.isSearchResult`.
- **`isSearchResult` must be sourced from the box that actually applied the live filter — use `searchBox:GetSearchText(kind)`, never `searchBox:GetText()`.** There are two search inputs: the module-level **overlay** box (`searchBox:Create`, `kind == nil`, toggled by the search keybind, stored as `searchBox.searchFrame`) and the **per-kind in-bag** boxes (`searchBox:CreateBox`, one per bag, stored on the themed decoration as `decoration.search` and reachable via `themes:GetInBagSearchBox(bag.frame)`). In-bag search is the default (`database:GetInBagSearch()`), and its live filter is applied imperatively by `bagProto:Search` from the in-bag box's `OnTextChanged`. `searchBox:GetText()` reads **only** the overlay box, so Phase8 reading it saw an empty query whenever in-bag search was active and reset `isSearchResult` to `nil` for every item; on the next redraw `SetItemFromData` then took the `else` branch (`SetMatchesSearch(not isFiltered)`) and un-dimmed everything — i.e. **any redraw silently cleared the visible filter** (the reported "right-click an item to send it to the bank clears the search" bug). `searchBox:GetSearchText(kind)` (frames/search.lua) resolves the active query for that bag kind: the per-kind in-bag box when in-bag search is on and it holds text, otherwise the overlay box. Coverage: `spec/frames/search_spec.lua` (resolution: in-bag vs overlay, per-kind, empty-fallback, in-bag-disabled) and `spec/items_spec.lua` ("resolves the query via the kind-aware GetSearchText, not the overlay-only GetText").

### 10. Zero Database Mutation in Views
The view rendering layer (`views/views.lua`) is strictly read-only and presentation-driven.
- **Rule:** Methods like `GetOrCreateSection` must never mutate database state or call `categories:CreateCategory`. All dynamic category creation and search-group resolution must occur upstream in the data sweep phase before `slotInfo` is dispatched to views.

### 11. Empty-Slot Family Glyph (Specialized Bags, All Clients)
Empty slots that belong to a **specialized** bag — one with a non-zero *bag family* (reagent
bags on retail; quivers, ammo pouches, soul/herb/enchanting/… bags on classic) — draw a small,
centered, semi-transparent glyph so the slot's restriction is visible at a glance. Generic bags
(family `0`) draw nothing.
- **Detection is by bag family, not bag id.** `C_Container.GetContainerNumFreeSlots(bagID)`
  returns `numFreeSlots, bagFamily` (verified in the API docs; `bagFamily` is `Nilable`). The
  family bit values are the keys of `const.ITEM_BAG_FAMILY`. Classic profession bags (quiver,
  soul/herb/enchanting/…) all report a non-zero family, so no per-client branch is needed for them.
- **The retail Reagent Bag is the one exception — it is id-based, not family-based.** Blizzard's
  own `ContainerFrame_IsReagentBag(id)` is literally `return id == 5`, and
  `GetContainerNumFreeSlots(5)` reports family **0**. A family-only check therefore silently skips
  it (the bug behind "no icon on retail"). `Phase5_UpdateFreeSlots` substitutes the symbolic
  `const.REAGENT_BAG_FAMILY_KEY` (`"ReagentBag"`) as the family when `bagFamily == 0` and
  `const.BACKPACK_ONLY_REAGENT_BAGS[bagid]` is set. The resolver and override map treat that string
  key exactly like a numeric family (override `EMPTY_SLOT_FAMILY_ICON["ReagentBag"]` for a
  reagent-specific glyph — e.g. the retail-only `bags-icon-reagents` atlas — else the default). The
  substitution only fires when the API family is 0, so if a client ever reports a real family for
  the reagent bag, the numeric path wins unchanged.
- **Resolution is data-phase, per the Pure Presentation Principle (§1) — the draw layer never
  resolves it.** `items:GetEmptySlotFamilyIcon(family)` (`data/items.lua`) maps a family key to a
  texture **atlas name**: `nil` for family `0`/`nil` (no glyph), an explicit
  `const.EMPTY_SLOT_FAMILY_ICON[family]` override if present, else the shared
  `const.EMPTY_SLOT_FAMILY_ICON_DEFAULT`. The map is empty by default (every specialized bag shares
  the default glyph); it exists so distinct per-family icons are a one-line data addition later.
- **Values are texture ATLAS names, not file paths** (drawn via `Texture:SetAtlas`). The default is
  `"Mobile-Herbalism"` (a 128×128 atlas, sized down in the draw layer), confirmed present on both
  retail and classic clients. (The earlier `Interface\PaperDoll\UI-PaperDoll-Slot-Bag` file path was
  replaced by the atlas at the user's request.)
- **Threading (data phase).** `Phase5_UpdateFreeSlots` captures the family into
  `emptySlotsByBag[bagid].family`. `Phase6_EnrichData` (now taking `emptySlotsByBag`) resolves and
  stores the ready atlas name on each empty slot's `itemInfo.emptySlotFamilyIcon`. This one field
  reaches **all four** empty-slot render paths: the individual free-space buttons (reuse the
  harvested `itemInfo`), the aggregated/combined free-space "stack" button (`Phase10_PartitionIntoTabs`
  builds it a **fresh** `itemInfo` with `emptySlotName` + `emptySlotFamilyIcon` from
  `familyForSubclass[name]`, and **no `itemQuality`** — see the border note below), and the in-place
  empty slots of the Show-Bags view — whose dummy `itemInfo` is built fresh in `Phase9_Sort`, so it
  copies `emptySlotFamilyIcon` from the harvested empty item it iterates.
- **The aggregated "stack" button carries no quality (no border).** A specialized bag's harvested
  empty-slot `itemInfo` carries the bag's `itemQuality` (from `const.BAG_SUBTYPE_TO_QUALITY`). Reusing
  it for the aggregate counter leaked that quality and painted a colored `IconBorder` around the stack
  button (the reported reagent-bag border), unlike the plain-bag stack. So `Phase10` builds the stack
  button a fresh `itemInfo` **without `itemQuality`** (nil), and `SetFreeSlots` no longer coerces a
  missing quality to `Common` (Blizzard's `ColorManager` returns a color for `Common`, so `Common`
  *would* draw a border; **nil** is what clears it — `SetItemButtonQuality(nil)` and
  `DrawClassicQualityBorder(nil)` both hide the border). Individual free-slot buttons and Show-Bags
  empties still pass their harvested quality through unchanged. Coverage: `spec/frames/item_spec.lua`
  ("passes nil (not Common) to SetItemButtonQuality when a free slot has no itemQuality").
- **Draw (`frames/item.lua`).** `SetFreeSlots` reads `data.itemInfo.emptySlotFamilyIcon` and, when
  set, shows a lazily-created `OVERLAY` texture on the **themed decoration** (`decoration.BetterBagsFamilyIcon`
  via `getFamilyIconTexture`) via `SetAtlas` — 24×24, centered, `0.4` alpha (re-applying `SetSize`
  after `SetAtlas`, since `SetAtlas` can otherwise snap to the atlas's native 128×128) — else hides
  it. The overlay lives on the **decoration** (the visual layer), not `self.button` (the interaction
  layer), and in the `OVERLAY` layer so it sits above the empty-slot art. It is hidden in
  `SetItemFromData` (any real item drawn into the slot) and `ClearItem`. No `items:`/database call
  happens at draw time.
- **Coverage:** `spec/items_spec.lua` ("Empty slot family icons (specialized bags)": resolver
  semantics, `Phase5` family capture, `Phase6` icon resolution incl. the generic-bag nil case) and
  `spec/frames/item_spec.lua` ("Empty slot family icon overlay": shown on specialized slots, hidden
  on generic slots and when the slot is redrawn as an item).
