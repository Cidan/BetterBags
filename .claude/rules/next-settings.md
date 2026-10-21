# BetterBags Next's Settings

BetterBags Next has its own settings window, built from nothing (asked; the plan and its status are
in `docs/next-settings.md`): pages grouped down a sidebar, tabs across a page, two-column rows, and
every control BetterBags' own, styled by the Next theme. The classic bags keep the classic settings
window (`config/config.lua`), as they keep their bags. Both build their settings from one catalog.

## 1. The settings catalog (`config/catalog.lua`, `SettingsCatalog`)

Every setting is defined once: its kind (`toggle`, `dropdown`, `slider`), name, description, the
words a search finds it by (`keywords`), its choices (`items`, or `itemsFunction` read each time a
menu opens, form-dropdowns.md) or range (`min`, `max`, `step`), and `get`/`set`: how it is read and
written and what it sends so the bags show it (`bags/Rederive`, `bags/Redraw`, `bags/FullRefreshAll`,
`search/SetInFrame`, `groups/EnabledChanged`; refresh-scheduler.md §9, §10). Before, all of this was
written inside the classic window's code, so a second window would have had to copy every setter.

- **A bag's setting** (`bag = true`) is bound to a bag when asked for: `Get(id, bag)` with a
  `SettingBag` (`{ name, kind }`; `Bags()` lists the backpack, the bank, and the guild bank where
  `addon.hasGuildBank`). Its description may be a function of the bag ("... in your backpack.").
  `only` limits it to some kinds (Enable Groups: the backpack); `Has(id, bag)` says whether a bag
  has it. Asking for a bag's setting without a bag, a general one with a bag, or a setting a bag
  does not have is an error naming it.
- **What a window reads** (`SettingOption`): a choice's `get` returns the item chosen (the old form
  asked each item whether it was chosen; `Form` gives it that shape), a slider's its number.
- **Rules a window follows:** `reload` marks a setting that takes effect after a reload (Enable
  Bank Bags), and `set` returning `false` means the change was refused (BetterBags Next while
  switching is refused: combat, the bank, a vendor) and the window must show the setting again.
- **`Form(id, bag, hooks)`** is a setting as the classic window's form takes it
  (forms/layouts/layout.lua), calling `hooks.reload` and `hooks.refresh` for those two rules.
- `Ids()` lists every setting in definition order. Defining one twice is an error.

**The classic window is built on it, unchanged for players.** `config/config.lua` adds each
setting with `addSetting(f, id, bag, hooks)` (the form control of its kind), in the order and
sections it always had; its panes, profiles, import and export are as they were. It loads after
the catalog in every TOC.

Coverage: `spec/config/catalog_spec.lua` (bags, binding to a bag and its text, refusals, choices,
the classic shape, ranges, reload and refusal rules, every classic setting defined once, keywords),
`spec/config/classic_settings_layout_spec.lua` (every entry the classic window adds, in order, with
its title, description, choices and range, equal to `spec/fixtures/classic_settings_layout.lua`,
recorded from the window before the catalog, with and without a guild bank) and
`spec/config/config_redraw_spec.lua` (each setting's refresh, unchanged). Mutation-tested (a
setting renamed, dropped or moved, the hooks, the slider range, the dropdown shape, Enable Groups
on every bag, a bag's name in a description: each caught).
