---
paths:
  - "config/config.lua"
  - "data/items.lua"
  - "spec/config/config_spec.lua"
  - "spec/integration/slash_commands_spec.lua"
---
# Slash Commands

BetterBags' chat commands, where they are registered, and why only one place may register them.

## 1. One registrar

`Config:RegisterSettings` (`config/config.lua`, run from `Config:OnEnable`, at `PLAYER_LOGIN`) registers every
BetterBags chat command through AceConsole-3.0's `RegisterChatCommand`:

- `/bb`: the settings window; `/bb help [words]` (help.md §4), `/bb changelog` (changelog.md), `/bb next` (next-bagsystem.md §11c).
- `/bbanchor`: the classic bags' anchors.
- `/bbdb`: debug mode and the debug window.

No other file assigns a `SLASH_*` global or a `SlashCmdList` entry. A new word after `/bb` goes in the `/bb` handler;
a new command is another `RegisterChatCommand` call there. AceConsole stores a command as
`SlashCmdList["ACECONSOLE_<COMMAND>"]` with `SLASH_ACECONSOLE_<COMMAND>1 = "/<command>"`
(`libs/AceConsole-3.0/AceConsole-3.0.lua:86-95`).

## 2. The client keeps one handler per command

`ImportListToHash` (`.libraries/wow-ui-source/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua`:
live 794-813, forever 809-828, classic, classic_era and classic_anniversary 717-736) walks `SlashCmdList` with
`secureexecuterange`, writes `hash_SlashCmdList[strupper(SLASH_<key><n>)] = handler` for each entry (a later entry
replaces an earlier one), then wipes `SlashCmdList`. `ChatFrameEditBoxBaseMixin:ParseText` (`ChatFrameEditBox.lua`:
live 247 and 259-261, forever 257 and 269-271, the classic branches 245 and 257-259) imports before each command and
runs `hash_SlashCmdList[command]`.

So two entries naming one command leave one handler that never runs. Which one is settled by the first import that sees
both, in the table's iteration order, which depends on what every other addon registered: the same build works for one
player and not for another.

## 3. The duplicate `/bb` (#1246, #1360)

`data/items.lua` set `SLASH_BETTERBAGS_DEBUGITEMS1 = "/bb"` (scaffolding from #1002: `/bb debugitems` printed the
backpack items a fresh harvest read). Where it won, `/bb`, `/bb help`, `/bb changelog` and `/bb next` printed
"BetterBags Debug Commands: use '/bb debugitems' to dump harvested physical items." (#1246); where AceConsole's won,
`/bb debugitems` opened the settings. It was removed (#1360), not moved under the `/bb` handler: the `/bbdb` debug
window's **Dump Backpack Items** (`frames/debug.lua`) records the backpack items with what the client's APIs answered
about each (data-driven.md). `spec/config/config_spec.lua` stubs `RegisterChatCommand`, so it could not see a second
entry; the whole-addon spec below reads `SlashCmdList` itself.

## 4. Coverage

- `spec/integration/slash_commands_spec.lua` (the whole addon, spec/helpers/whole_addon.lua): `/bb`, `/bbanchor` and
  `/bbdb` are each named by one `SlashCmdList` entry, Config's; `/bb` dispatched as the client does (`ImportListToHash`
  modelled, the entries walked first to last and last to first) opens the settings window. Before the removal the first
  and the first-to-last tests failed: `/bb` was named by `ACECONSOLE_BB` and `BETTERBAGS_DEBUGITEMS`, and the debug
  handler, walked last, printed its help with the settings closed.
- `spec/config/config_spec.lua`: what each handler does with its input.
