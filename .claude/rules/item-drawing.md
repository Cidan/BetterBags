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
- **UpdateCooldown:** Classic uses `ContainerFrame_UpdateCooldown(bagid, button)` instead of the mixin `UpdateCooldown` method.
- **UpdateExtended:** Calling `UpdateExtended()` on Classic clients causes the engine to flag the button as an extended slot (e.g. Reagent bag), which incorrectly applies a blue `ExtendedOverlay` tint to the item. This must be guarded strictly behind `if addon.isRetail then ... end`.

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
