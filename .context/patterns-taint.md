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
  i:GetDecoration(ectx):GetPushedTexture():Show()
end)

-- GOOD: plain HookScript, lazy cached reference
local decoration
button:HookScript("OnMouseDown", function()
  if not decoration then
    decoration = i:GetDecoration(context:New('init'))
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

## Buy Bank Tabs Through Blizzard's Script-Only Purchase Template
**Problem**: `C_Bank.PurchaseBankTab` is protected (`HasRestrictions`). Calling it, or a Blizzard function that calls it (`BankFrame:PurchaseFirstSlot()` on WoW: Forever), from addon code is blocked with `ADDON_ACTION_FORBIDDEN`.

**Solution**: Create the button with `BankPanelPurchaseButtonScriptTemplate` (Blizzard's "script-only template for use by addons", `Mainline/BankFrameTemplates.xml`), add `UIPanelButtonTemplate` for a standard look, and set the `overrideBankType` attribute. Its own `OnClick` opens `CONFIRM_BUY_BANK_TAB`, and the dialog's accept makes the purchase. Never set or hook the button's `OnClick`.

**Related Files**: `frames/bankslots.lua` (tab purchase buttons), `bags/bank.lua` (Purchase Bank button), `.claude/rules/camelot-forever.md` §10

## Move Items From Addon Code With PickupContainerItem, Never Through Blizzard's Button Handlers
**Problem**: Moving an item for the player (a drop on the bag window, issue #408) is tempting to do by forwarding the click to the target slot's item button (`button:GetScript("OnClick")(button, ...)`, as AdiBags does). Blizzard's `ContainerFrameItemButton_OnClick` then runs from our tainted call: while a spell waits for an item target it calls `C_Container.UseContainerItem` (`#protected`, blocked), and its merchant branch writes `MerchantFrame` state. Showing a Blizzard `StaticPopup` with data we supply taints the popup the same way.

**Solution**: call `C_Container.PickupContainerItem(bag, emptySlot)` directly. It is not protected (no restriction tag on warcraft.wiki.gg, none in `ContainerDocumentation.lua`; BetterBags already calls it from the WoW: Forever bank sockets), it is exactly what dropping on that slot does, and it writes nothing Blizzard's code reads. Read the free slot from the client at that moment (`C_Container.GetContainerFreeSlots`): picking up onto an occupied slot swaps, putting the other item on the cursor. Leave anything that needs a Blizzard confirmation (a refundable item going into the Warbank) to Blizzard's own buttons.

**Related Files**: `util/cursorplacement.lua`, `frames/bag.lua` (`WatchMouse`), `.claude/rules/bag-drop-zone.md`

## Keep a Blizzard Frame Shown but Unseen: Hook Its Hide, Act a Frame Later

**Problem**: BetterBags Next's vendor replaces Blizzard's merchant frame, but Blizzard's bag code sells on a right click only while `MerchantFrame:IsShown()` (and on its first tab). Hiding the frame breaks selling; leaving it visible shows two vendors. Parented to a hidden frame it stays "shown" (its own flag) and is never visible, but then its `OnHide` never runs either, and that is what ended the visit (`MerchantFrame_OnHide` → `CloseMerchant`), so a hide by the panel manager or Escape leaves the vendor open with nothing on screen.

**Solution**: reparent it at load (as the bank frame), write none of its fields or its tab, and `hooksecurefunc(MerchantFrame, "Hide", ...)` (a secure field write). The hook ends the visit with `C_Timer.After(0, ...)` so `CloseMerchant` runs outside Blizzard's code, guarded so every close path ends the visit once. Code that asked whether a vendor is open with `IsVisible()` must ask `IsShown()`, as Blizzard's bag code does.

**Purchases**: buy through Blizzard's own confirmation functions (`MerchantFrame_ConfirmExtendedItemCost`, `MerchantFrame_ConfirmHighCostItem`), called the way its item button calls them, never instead of them. They run from our click, so they write `MerchantFrame.itemIndex`/`count`/`price` and show the popup tainted (see the section above); their accept calls `BuyMerchantItem`, which is not protected. Not verified in game; CompactVendor ships the same calls.

**Related Files**: `next/vendor.lua` (`TakeOver`, `EndVisitLater`), `next/merchant.lua` (`Purchase`), `util/movementflow.lua`, `.claude/rules/next.md` §10

## Keep a Blizzard Frame Shown When Its Own Show Checks It Is Visible

**Problem**: BetterBags Next's guild bank replaces Blizzard's guild bank frame, which is load on demand. Blizzard's `ShowGuildBankFrame` (retail and Forever; Classic's UIParent handler is the same) calls `ShowUIPanel(GuildBankFrame)` and then `CloseGuildBankFrame()` at once when `GuildBankFrame:IsVisible()` is false, and the frame's `OnHide` ends the visit too. Parenting it to a hidden frame (the vendor's way, above) ends every visit the moment it starts.

**Solution**: `hooksecurefunc("ShowUIPanel", ...)` once; when it shows the frame, put it under a tiny shown frame (`SetScale(0.001)`: visible to Blizzard's check, never seen), take its `OnHide` off (`SetScript`, on a frame that is not protected), and a frame later put it under the hidden frame. Hook its `Hide` to end the visit a frame later, as its `OnHide` did. Give the `OnHide` back with the frame when the feature is switched off. Bagnon does the same (`core/features/uiOverrides.lua`).

**Related Files**: `next/guildbank.lua` (`TakeOver`, `OnShowUIPanel`, `GiveBack`), `spec/integration/guild_bank_spec.lua`, `.claude/rules/guild-bank.md` §5

## Secret Values: Show Them, Never Measure Them

**Problem**: from patch 12.0.0, APIs return secret values under addon restrictions (a dungeon, a raid, combat, an encounter). Addon code may store them, pass them to Lua functions and concatenate them, but arithmetic, comparisons, `#` and table keys error (warcraft.wiki.gg Secret Values). Secrecy spreads: a widget given a secret gets a secret aspect, and its other APIs then return secrets (a font string showing a secret name has a secret width, `SecretWhenAnchoringSecret`). BetterBags Next's vendor put the vendor's name (`UnitName("npc")`, `SecretWhenUnitNameIdentityRestricted`) in its title and measured the title to lay out the cloud: an error in every instance.

**Solution**: check each API's flags in `Blizzard_APIDocumentationGenerated` (`SecretReturns`, `SecretWhen*`, `ConditionalSecret` on a return, `SecretReturnsForAspect`, `SecretArgumentsAddAspect`). Show a secret through an API that takes one (`SecretArguments = "AllowedWhenTainted"`), and never read the widget back for arithmetic: check `issecretvalue` (nil on Classic) and use a stand-in, or keep the value the addon set itself. Never pass a secret to an API the documentation does not mark as taking one from addon code (`GameTooltip` methods are not documented at all); keep a plain value for those (the panel's `label`). Test with the frame mock's `MockSecret`.

**Never a table key, never compared**: a secret may be stored as a table's value but not used as its key, read or written ("attempted to index a table that cannot be indexed with secret keys": the Seller keyed merchants by `UnitGUID("npc")`, secret in a dungeon). Nor may it be compared, even `secret ~= nil`; a boolean test (`secret or default`) is allowed for non-boolean secrets. Ask `issecretvalue` before anything else, and key by something the addon owns instead (the Seller uses the visit). Lua 5.1 never calls a table's `__eq` against `nil`, so the mock cannot catch `secret ~= nil`: write the check so it never happens. Specs guard the tables code indexes with the mock's `SecretKeyGuard`.

**Related Files**: `next/panel.lua` (`CloudSpan`, the title button), `next/chain.lua` (`Tooltip`), `data/seller.lua` (`merchant`), `spec/helpers/wow_mocks.lua` (`MockSecret`, `SecretKeyGuard`), `.claude/rules/next.md` §10b, `.claude/rules/seller.md` §3
