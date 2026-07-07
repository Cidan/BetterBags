# Implementation Plan: Flat "Blizzard Bags" View for Bank

## 1. Add `RemoveHeader` support to Sections (`frames/section.lua`)
- Add a new method `sectionProto:RemoveHeader()` which sets a flag (e.g. `self.removeHeader = true`).
- In `sectionProto:Grid(kind, view, freeSpaceShown, nosort)`, check for this flag:
  - If `self.removeHeader` is true, do not add `self.title:GetHeight() + 6` to the `fullHeight`.
  - Instead of anchoring the content grid to `self.title` `"BOTTOMLEFT"`, anchor it directly to `self.frame` `"TOPLEFT"`.
  - Call `self.title:Hide()`.
  - For normal (header-enabled) sections, ensure `self.title:Show()` is called and the normal anchoring and height logic is used.
- In `sectionProto:Wipe()` and `sectionFrame._DoReset(ctx, f)`, reset `self.removeHeader = false` to ensure properly recycled sections for the pool.

## 2. Consolidate into a Single Section for Bank (`views/bagview_new.lua`)
- In `BagView(view, ctx, bag, slotInfo, callback)` where it iterates over `currentItems`:
  - If `view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS` and `bag.kind == const.BAG_KIND.BANK`:
    - Hardcode the category to a single shared string (e.g., `L:G("Items")` or `"Everything"`), so all items group together in one section.
- Also, in the empty slots iteration (`view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS`), apply the same bypass for `bag.kind == const.BAG_KIND.BANK` so empty slots merge into the same single category as the items.

## 3. Configure Headerless Layout and Sorting (`views/bagview_new.lua`)
- In the active sections drawing loop `for _, section in pairs(view:GetAllSections()) do`:
  - If `view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS` and `bag.kind == const.BAG_KIND.BANK`, call `section:RemoveHeader()`.
  - We need to sort by physical slot. `sectionProto:Grid` uses `sort.GetItemSortBySlot` when `freeSpaceShown = true`. Currently `section:Draw(...)` is passed `false` as the third parameter. We will modify this call to pass `true` as the third parameter (`freeSpaceShown`) if it's the `SECTION_ALL_BAGS` bank view, which effectively applies `GetItemSortBySlot` for this specific view mode.

## 4. Verify Global Sections Hidden (`frames/bag.lua`)
- No changes required. Code review of `bagFrame.bagProto:DrawGlobalSections` confirms that generation of "Recent Items" and "Free Space" is bypassed entirely (`if currentView ~= const.BAG_VIEW.SECTION_ALL_BAGS then ... end`). Since the bank uses the identical shared UI container frame logic, toggling to `SECTION_ALL_BAGS` will naturally skip evaluating and generating the global sections.