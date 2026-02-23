# Taint and Protected Code Patterns

## Never Assign to Global `_` Variable
**Problem**: `bindType, _, _, _ = select(...)` without `local` taints the global `_`, blocking protected actions like `UseContainerItem`.
**Solution**: Always declare `local` in the same assignment statement, or only capture what you need.
```lua
-- BAD: taints global _
bindType, _, _, _ = select(14, C_Item.GetItemInfo(itemLink))
-- GOOD:
local bindType = select(14, C_Item.GetItemInfo(itemLink))
```

## Mark Unused Parameters with a Local Throwaway
**Problem**: `_ = arg` without `local` writes to global `_` (taint risk + luacheck W111).
**Solution**: Localize `_` once per scope before throwaway assignments: `local _ = firstArg; _ = nextArg`.

## Compute Toggle State Inside the Active Branch
**Problem**: Declaring `local enabled` outside branches and only assigning in one branch passes `nil` to setters in other branches.
**Solution**: Compute `enabled` from the appropriate data source inside each branch separately.

## Cannot Override Functions Called in Protected Contexts
**Problem**: Overriding Blizzard functions called during protected actions causes `ADDON_ACTION_FORBIDDEN`. Touching Blizzard frames at initialization **permanently** taints them.

**Critical Discovery**: Blizzard's `UseContainerItem()` calls `BankFrame:GetActiveBankType()`. If BankPanel was ever shown at init time by addon code, ALL `UseContainerItem` calls fail — even for the backpack.

**Solution**:
- Never `Show()` BankPanel at initialization — only show when the bank is open, hide when closed
- Use `BankPanel:SetBankType()` method (not direct field assignment) — direct assignment taints BankPanel

## Avoid Context Creation in Mouse Event Hooks on Item Buttons
**Problem**: `addon.HookScript()` on mouse events (OnMouseDown, OnEnter, etc.) creates context objects that taint the execution path before protected clicks (e.g., `UseContainerItem` for consumables).
**Solution**: Use plain `button:HookScript()` with a lazy-cached decoration reference:
```lua
-- BAD: creates context on every mouse event, causes taint
addon.HookScript(button, "OnMouseDown", function(ectx)
  themes:GetItemButton(ectx, i):GetPushedTexture():Show()
end)

-- GOOD: plain HookScript, lazy cached reference
local decoration
button:HookScript("OnMouseDown", function()
  if not decoration then
    decoration = themes:GetItemButton(context:New('init'), i)
  end
  decoration:GetPushedTexture():Show()
end)
```

## Never Manipulate Blizzard Frames in OnHide/OnShow from UISpecialFrames
**Problem**: Frame scripts triggered via UISpecialFrames (ESC key close) run in a protected context. Touching BankPanel or calling `CloseBankFrame()` there creates persistent taint that breaks `UseContainerItem()` for ALL containers afterward.

**Key Rules**:
- ❌ **OnHide script**: Do NOT touch BankPanel or call `CloseBankFrame()` — runs in protected context
- ✅ **CloseSpecialWindows SecureHook**: Safe to call `CloseBankFrame()` (runs after Blizzard's function)
- ✅ **BANKFRAME_CLOSED event handler**: Safe to hide BankPanel (runs in addon context)

**Related Files**: `bags/bank.lua:148-187` (OnHide), `core/hooks.lua:111-153` (CloseSpecialWindows + CloseBank)

## Bank Closing Recursion Prevention with Guard Flags
**Problem**: Stack overflow from close event loops: `Hide()` → `CloseBankFrame()` → `BANKFRAME_CLOSED` → `CloseBank()` → `Hide()` → repeat.

**Solution**: Guard flags prevent re-entry at each potential recursion point.

- **Retail** (`bags/bank.lua:32-38, 723-757`): Module-level `local isClosingBank = false` in the hooksecurefunc; no `CloseBankFrame()` in OnHide.
- **Classic/Era** (`bags/era/bank.lua:43-60`, `bags/classic/bank.lua:43-60`): Instance-level `self.isHiding` flag in OnHide; no `CloseBankFrame()` in OnHide; no hooksecurefunc (skipped via `addon.isRetail` check).

Use `C_Timer.After(0, ...)` to clear the Retail guard after event processing completes.
