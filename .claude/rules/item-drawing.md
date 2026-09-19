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
  - **Items → `itemProto:DrawQualityGlow(decoration, quality)`** (called from `SetItemFromData` after `SetItemButtonQuality`, retail and Classic alike). For **Uncommon+** it draws an additive glow (`Interface\Buttons\UI-ActionButton-Border`, `BlendMode "ADD"`, center texcoord) colored by `const.ITEM_QUALITY_COLOR[quality]`. The **"Extra Glowy Item Buttons"** option (`database:GetExtraGlowyButtons(kind)`) controls **intensity, not presence**: on → full alpha; off → `SUBTLE_QUALITY_GLOW_ALPHA` (0.55) so quality is still visible without the option. **Poor/Common** items get `IconBorder:Hide()` (matching Blizzard). The old behavior drew a thin `WhiteIconFrame` `BLEND` border for the non-glowy case, which was nearly invisible on Classic — hence "you can't see the glow with extra glowy off".
    - **Classic phantom-frame obscuring the glow (the real "no border on Classic" cause):** `DrawQualityGlow` writes the additive halo to `decoration.IconBorder`, and the decoration is anchored **one frame level below** the interaction button (`decoration:SetFrameLevel(self.button:GetFrameLevel() - 1)` in `SetItemFromData`). On Classic, `self.button`'s own `NormalTexture` (`Interface\Buttons\UI-Quickslot2`, a 64×64 beveled slot frame) is **re-shown by Blizzard's drag/update logic** after our creation-time `Hide()`, and being on the higher frame level it draws **over** the decoration's glow, hiding it — so the quality glow looked completely missing on Classic even though `DrawQualityGlow` ran correctly. A plain `Hide()` loses to the re-show; the fix (end of `SetItemFromData`, gated `not addon.isRetail`) clears the **texture value** itself — `self.button:GetNormalTexture():SetTexture(nil)` — so nothing renders even when Blizzard re-shows the region. With the obscuring frame gone, the additive glow and its "Extra Glowy" intensity control are visible on Classic **exactly as on retail** (no Classic-specific glow/border code path is needed — retail and Classic both rely on `DrawQualityGlow`). Retail has no such re-show and is left untouched by the gate.
  - **Free slots → `itemProto:DrawClassicQualityBorder(decoration, quality)`** (called from `SetFreeSlots` on non-retail with the bag's quality). It draws a thin colored `WhiteIconFrame` border **only for Uncommon+** bag quality (special bags), and **hides** it for Poor/Common. Previously it showed a **white** border for Common free slots, which double-bordered the `UI-Backpack-EmptySlot` texture (its own frame) and read as an offset/double frame on Classic — the reported free-slot bug.
  - `spec/frames/item_classic_spec.lua` carries a source-faithful mock of the Classic `SetItemButtonQuality`; fix the code, not the mock. Coverage: the same spec ("draws an additive quality glow…", "uses a full-intensity glow when Extra Glowy is enabled", "draws no quality border for common items", "does NOT border a plain (common) free slot").
- **Bag Kind:** `item.kind` drives item-level options, extra-glowy borders and Masque groups. It is derived from the bag ID via `const.BANK_BAGS` **and** `const.ACCOUNT_BANK_BAGS`; checking only `BANK_BAGS` classified every Warbank button as backpack.
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
- **Acquisition & Release:** `itemFrame:GetButton(ctx, slotkey)` acquires a virtual button from `virtualPool` via `itemFrame:AcquireVirtualItem(ctx, slotkey)`. When views wipe or release item frames (`item:Wipe(ctx)`), virtual buttons are unmapped from `buttonsBySlotkey` and returned to `virtualPool`.

### 8. Upstream Pre-Computation of ItemContextMatchResult
Evaluating whether an item is valid for active interactions (e.g. bank, merchant, scrapping, or account bank tabs) is pre-computed during data enrichment (`Phase6_EnrichData`) and stored as `data.itemContextMatchResult`.
- **Pure Drawing:** `itemFrame.GetItemContextMatchResult(item)` reads `data.itemContextMatchResult` directly. It performs zero on-the-fly `ItemLocation:CreateFromBagAndSlot` object instantiations, zero `C_Bank.IsItemAllowedInBankType` calls, and zero global addon state queries during draw.
- **Bank-tab switches must re-sweep the backpack.** `items:ResolveItemContextMatchResult` (`data/items.lua`) resolves a backpack item's grey-out against the *currently active bank tab*: it reads `addon.atBank`, `addon.Bags.Bank.bankTab`, and (for Warbank tabs) `C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, ...)`. Because that resolution happens only during a backpack data sweep (`Phase6_EnrichData`) and is then frozen into `data.itemContextMatchResult`, changing the active bank tab does **not** by itself update the backpack grey-out. Firing `ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)` re-runs each drawn button's `UpdateItemContextMatching`, but that only re-reads the already-committed (now stale) `data.itemContextMatchResult` — so the grey stays put.
  - **Failure mode (fixed):** open bags, open bank on the Warbank group tab (backpack items disallowed in the Warbank correctly grey out), then click the Bank (Character) group tab — the grey stayed until a manual bag Sort forced a backpack refresh.
  - **Rule:** every retail bank-tab switch path (`bank.proto:SwitchToGroup` and `bank.proto:SwitchToBlizzardTab`, `bags/bank.lua`) must set `self.bag.bankTab` to the newly active tab *and* `events:SendMessage(ctx, 'bags/RefreshBackpack')` (gated on `addon.atBank`) after updating the bank type, so the backpack re-sweeps and recomputes `itemContextMatchResult` against the new tab. `SwitchToGroup` already set `bankTab` from `group.bankType`; `SwitchToBlizzardTab` did not (it only set `blizzardBankTab`), so it now also assigns `bankTab = bagIndex`. The extra backpack refresh is a stateless, idempotent clean-sweep, so the redundant refresh triggered by the initial-open `SwitchToGroup` call redraws identical content (no flicker). Coverage: `spec/bags/bank_context_refresh_spec.lua`.

### 9. Upstream Pre-Computation of Search Filtering
Active search query evaluation is performed upstream during the data sweep phase (`Phase8_EnrichCategories`, right after `search:IndexItems` rebuilt the index for this sweep) and attached to item nodes as `data.isSearchResult`. It must not run in `Phase6_EnrichData`, which executes before re-indexing and would evaluate the query against the previous sweep's index.
- **No Draw-Phase Search Execution:** Late-stage search evaluations at the end of frame drawing (e.g., querying `searchBox:GetText()` inside `bag.lua` during `Draw`) are completely removed. Item buttons update their search alpha synchronously from `data.isSearchResult`.

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
  resolves it.** `items:GetEmptySlotFamilyIcon(family)` (`data/items.lua`) maps a family bit to a
  texture: `nil` for family `0`/`nil` (no glyph), an explicit `const.EMPTY_SLOT_FAMILY_ICON[family]`
  override if present, else the shared `const.EMPTY_SLOT_FAMILY_ICON_DEFAULT`. The map is empty by
  default (every specialized bag shares the default glyph); it exists so distinct per-family icons
  are a one-line data addition later.
- **The default glyph is `Interface\PaperDoll\UI-PaperDoll-Slot-Bag`** — a stock PaperDoll asset
  present on every client (retail and classic; already used on the non-retail path in
  `frames/bagbutton.lua`). Do **not** use the retail-only `bags-icon-*` atlases for the default;
  they are absent on classic.
- **Threading (data phase).** `Phase5_UpdateFreeSlots` captures the family into
  `emptySlotsByBag[bagid].family`. `Phase6_EnrichData` (now taking `emptySlotsByBag`) resolves and
  stores the ready texture string on each empty slot's `itemInfo.emptySlotFamilyIcon`. This one
  field reaches **all three** empty-slot render paths: the individual free-space buttons (reuse the
  harvested `itemInfo`), the aggregated/combined free-space button (reuses the harvested `itemInfo`,
  with a `familyForSubclass` fallback in `Phase10_PartitionIntoTabs` for the no-`originalItem`
  case), and the in-place empty slots of the Show-Bags view.
- **Draw (`frames/item.lua`).** `SetFreeSlots` reads `data.itemInfo.emptySlotFamilyIcon` and, when
  set, shows a lazily-created `OVERLAY` texture on the **themed decoration** (`decoration.BetterBagsFamilyIcon`
  via `getFamilyIconTexture`) — 20×20, centered, `0.8` alpha — else hides it. The overlay lives on
  the **decoration** (the visual layer), not `self.button` (the interaction layer), and in the
  `OVERLAY` layer so it sits above the empty-slot art. It is hidden in `SetItemFromData` (any real
  item drawn into the slot) and `ClearItem`. No `items:`/database call happens at draw time.
- **Coverage:** `spec/items_spec.lua` ("Empty slot family icons (specialized bags)": resolver
  semantics, `Phase5` family capture, `Phase6` icon resolution incl. the generic-bag nil case) and
  `spec/frames/item_spec.lua` ("Empty slot family icon overlay": shown on specialized slots, hidden
  on generic slots and when the slot is redrawn as an item).
