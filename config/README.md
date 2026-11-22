# Configuration Module

This folder contains BetterBags' settings: every setting's definition, the slash commands, and the plugin
API. The settings window itself, the same for the classic bags and BetterBags Next, is in
`next/settings/` (`.claude/rules/next-settings.md`). The classic settings window and its panes
(theme, categories, currency, item colors) were removed when that window became the only one; their
features are its pages.

## Files

### catalog.lua (`SettingsCatalog`)

Every setting defined once: its kind (toggle, dropdown, slider), name, description, searching words,
choices or range, how it is read and written, and what it sends so the bags show it (`bags/Redraw` for
what only changes how the bags look, `bags/Rederive` for what the data phase reads, `bags/FullRefreshAll`
for what a bag read depends on). A bag's settings are bound to a bag when requested:
`catalog:Get(id, bag)`, the bags being the backpack, the bank, the guild bank and BetterBags Next's vendor
(`catalog:Bags()`). A bag's setting is the bags' that contain items unless it names its kinds (`only`): each bag's
switch is its own (Enable Bank Bags, Enable Vendor Window, Enable Guild Bank Window), and each bag's Size tab is
every bag's, the vendor's too (`.claude/rules/next-bag-settings.md`). The window builds its rows from it;
`spec/config/settings_effects_spec.lua` checks what each setting sends. Most read and write the profile; Include
Tradeable Reagents (the bank's) is the client's own `bankAutoDepositReagents` CVar, stored per character, which a
Warbank deposit reads (`.claude/rules/warbank-deposit.md`).

### config.lua (`Config`)

Opens the settings window (`Config:Open`, the `config/Open` message) and shows it the settings of the
design the bags switch to (`bags/DesignChanged`).

Chat commands:
- `/bb` opens the settings window; `/bb changelog` opens What's New; `/bb next` switches between the
  classic bags and BetterBags Next; `/bb help` opens the settings window's Help page, and `/bb help` followed by words
  opens it on what they match (the `help/Open` message, `.claude/rules/help.md` §4).
- `/bbanchor` shows the classic bags' anchors. BetterBags Next's bags show theirs from their header's anchor button
  (`.claude/rules/next-bag-anchor.md` §30b).
- `/bbdb` turns debug mode on and off.

Every BetterBags chat command is registered here and nowhere else: the client stores one handler per command, so a
second registration of `/bb` elsewhere left `/bb` printing another handler's text on some setups
(`.claude/rules/slash-commands.md`).

### plugin.lua

`Config:AddPluginConfig(title, options)` adds a plugin's page to the settings window (under
Integrations), made from its AceConfig options: a group, or the args of one. The page reads the options
the way AceConfigDialog does:

- **Types:** `toggle`, `select` (its `values` by key, sorted by key or by its `sorting`; the key is
  written), `multiselect`, `range`, `input` (one line, or `multiline` with an Accept button), `color`
  (`hasAlpha`), `execute`, `description`, `header` (starts a section), `group` (a section of its own).
- **Members:** inherited from groups (`get`, `set`, `func`, `validate`, `confirm`, `disabled`,
  `hidden`), `handler` methods by name, `info` passed to every call, `order`.
- **What changes:** names, values, `disabled` and `hidden` are read again after every change, so an
  option the plugin shows only sometimes appears and disappears as it does. A hidden group hides
  everything in it; a hidden header hides only its line.
- **Writes:** `pattern`, `validate` (false or a message rejects the change, displayed in a dialog), `confirm`
  and `confirmText` (prompted in a dialog), then `set` (or `func`).

```lua
local config = LibStub('AceAddon-3.0'):GetAddon('BetterBags'):GetModule('Config')
config:AddPluginConfig("My Plugin", {
  enabled = {
    type = "toggle",
    name = "Enable Feature",
    desc = "Enables my plugin feature",
    order = 1,
    get = function() return MyPlugin.enabled end,
    set = function(_, value) MyPlugin.enabled = value end,
  },
  mode = {
    type = "select",
    name = "Mode",
    order = 2,
    values = { fast = "Fast", careful = "Careful" },
    get = function() return MyPlugin.mode end,
    set = function(_, key) MyPlugin.mode = key end,
  },
})
```
