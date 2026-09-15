# Form Dropdowns Resolve Their Item List Lazily

This document defines how the stacked form layout (`forms/layouts/stacked.lua`) builds
dropdown menus, and the invariant that keeps late-registered entries visible.

## 1. `itemsFunction` is evaluated on every menu generation, never snapshotted

A dropdown is added with either a static `opts.items` array or a dynamic
`opts.itemsFunction(ctx)` (see `FormDropdownOptions` in `forms/layouts/layout.lua`).

- **Rule:** when `opts.itemsFunction` is present, it must be called **inside** the menu
  generator — the `DropdownButton:SetupMenu(function(_, root) … end)` closure on retail
  (`addDropdownRetail`) and the `UIDropDownMenu_Initialize(...)` init function on classic
  (`addDropdownClassic`). The generator runs on every open / `GenerateMenu()` / `Update()`,
  so the list is always current. Do **not** compute the list once before `SetupMenu` and
  close over it — that freezes the menu to whatever was registered at pane-build time.
- Static `opts.items` may be read directly (it does not change), but the lazy branch handles
  both: `local itemList = opts.items; if not itemList and opts.itemsFunction then itemList =
  opts.itemsFunction(context:New('Dropdown_Items')) end`.

## 2. Failure mode this prevents (the "Pawn not in the provider dropdown" bug)

The config pane is built eagerly by `config:OnEnable` → `config:CreateConfig`
(`config/config.lua`). In `core/init.lua`'s `addon:OnEnable`, `config:Enable()` runs
**before** `pawn:Enable()` (and Pawn can register even later via its `ADDON_LOADED` retry —
see data-loader.md §15). The "Upgrade Icon Provider" dropdown's `itemsFunction` iterates
`items.upgradeProviders`. When the list was snapshotted at build time it contained only the
providers registered so far (`None`, `BetterBags`, and `SimpleItemLevel`, which enables
before Config), so **Pawn was permanently missing** even though `pawn:Register()` succeeded
and printed "Pawn integration enabled." The existence check and registration were correct;
only the dropdown's one-shot capture was wrong. Resolving `itemsFunction` per-generation
makes any provider that registers after the pane is built (init order or late `ADDON_LOADED`)
appear the next time the menu opens or the form reloads (`ReloadAllFormElements` →
`DropdownButton:Update()`).

Coverage: `spec/forms/dropdown_spec.lua` ("resolves itemsFunction lazily so late-registered
entries appear on regenerate", "regenerating via ReloadAllFormElements re-queries the item
list"). The `spec/helpers/wow_mocks.lua` `DropdownButton` mock re-runs the `SetupMenu`
generator on every `GenerateMenu()`/`Update()` and records the produced entries on
`_lastMenuItems`, mirroring the live client.
