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

## 2. Controls (`next/controls/`)

Every control is BetterBags' own, made of plain frames and textures (no Blizzard template), drawn
from the Next theme's `Controls` (next-themes.md), restyled on every theme (each module registers
with SonataNext and restyles every instance it made in `ApplyStyle`), and usable anywhere in Next.
Asked: "this also means redoing all our controls (including scrollbars ...) so that they are themable".

| Module | File | What it is |
|---|---|---|
| `NextControls` | `base.lua` | `Paint(texture, fill, alpha?)`: a fill is a texture spec (`Color`, `Alpha`; or a `Texture`/`Atlas` tinted by `Color`), a palette color, a color, or `false` (hidden). `CreateEdge`/`PaintEdge(edge, spec, alpha?)`: four lines inside a frame's border, `Size` thick; a strength replaces the alpha (`Idle`/`Hover`/`Focus`). `Theme(name)`. The Escape stack (below). |
| `NextScrollBar` | `scrollbar.lua` | A track and thumb in a scroll box's right edge (`Width`, `Inset`; `Size`, `HoverSize` under the pointer), the thumb the share shown (at least `MinThumb`), hidden while nothing scrolls. |
| `NextButton` | `button.lua` | `Plain`, `Primary`, `Danger`, `Link`: fills and edges idle, under the pointer, pressed; a link is its text alone. As wide as its label and `Padding` (at least `MinWidth`) unless given a width; disabled at `DisabledAlpha`, calling nothing. A tooltip when given. |
| `NextToggle` | `toggle.lua` | A switch: the knob slides (`Motion.Time.Toggle`), the on color fades in with it. A click flips it and calls back; `SetChecked` calls nothing back. |
| `NextInput` | `input.lua` | A text field (an `EditBox`: its text `Padding` in, help while empty and unfocused) and `CreateArea`, a text area (a multi-line edit box in a Blizzard scroll box with the scroll bar, the wheel taken only while focused, the cursor kept in sight). Only typed text is reported (`OnTextChanged`'s `userInput`); Enter reports and lets go of focus; Escape puts back the text it had when focused. |
| `NextSlider` | `slider.lua` | A track filled up to a thumb, pressed or dragged with the left button, and a number box (`NextInput`); every value snapped to the step and kept in range; a change calls back once per value; the wheel is left to the page. |
| `NextMenu` | `menu.lua` | One menu at a time, `FULLSCREEN_DIALOG`, below what opened it (`Gap`), a row per choice, the chosen one checked, scrolling past `MaxRows`. Closes on a pick, a click or the wheel outside it (a screen-sized catcher), Escape, a second open for the same frame, or that frame hiding. |
| `NextDropdown` | `dropdown.lua` | The choice made and a chevron; a click opens a `NextMenu`, its choices read each time (`itemsFunction`, form-dropdowns.md); the choice already made calls nothing back. |
| `NextSwatch` | `swatch.lua` | A square of its color. A click opens Blizzard's color picker (`ColorPickerFrame:SetupColorPickerAndShow`, loaded at login on every client); each color picked (`swatchFunc`, `opacityFunc`) calls back, and Cancel puts the color back and calls that back too, so what was saved follows (the classic item color pane left the saved color changed on Cancel). |
| `NextTopTabs` | `toptabs.lua` | A page's tabs, left to right `Gap` apart, the chosen one in its font and underlined by a marker that glides (`Motion.Time.TabMarker`). The chosen tab calls nothing back. |
| `NextDialog` | `dialog.lua` | In place of `StaticPopup`: a scrim over a window (taking its clicks) and a card with a title, wrapped text, an optional field, and buttons laid out from the right in the order given. A button gets the field's text and closes it unless it returns true; Enter is the last button, Escape or the window hiding the first. |

**Escape, innermost first.** `PushEscape(frame)` names a frame in `UISpecialFrames` in place of the
one under it (a menu over a dialog over the window); `ReleaseEscape(frame)`, from the frame's
`OnHide`, gives Escape back to the frame under it on the next frame, if that one still shows.
Blizzard's `CloseSpecialWindows` walks `UISpecialFrames` with `pairs` and hides frames as it goes
(every client, `UIParentPanelManager.lua`), so the list must not change during a hide: changing a
table `pairs` is walking is undefined. `SetPropagateKeyboardInput`, which would let a frame take
Escape itself, is protected (`HasRestrictions`, SimpleFrameAPIDocumentation).

**The bags' scroll bar.** `render/scrollbox.lua` takes `CreateBar(box, { AutoHide })`: a caller's
bar, made once the box has its view and bound to it (`bar:Bind(box)`), in place of Blizzard's
`MinimalScrollBar`; `sb.scrollBar` is the bar's frame (ConsolePort's `nodeignore` is set on it as
before). Every Next panel's scroll box uses `NextScrollBar` with `AutoHide` (seen while the box
scrolls or the pointer is over it, `Linger` seconds, `FadeIn`/`FadeOut`). The bar drives the box as
`ScrollUtil` binds one (`OnScroll`, `OnSizeChanged`, `OnAllowScrollChanged`; dragging without
interpolating, the track paging by the box's height, the wheel by its pan extent). The classic bags
keep Blizzard's bar.

**Mocks added from Blizzard's source** (`spec/helpers/wow_mocks.lua`): the scroll box's callback
registry, extents, percentages, scrolling allowed and `OnScroll` (`ScrollBox.lua`,
`ScrollController.lua`, `CallbackRegistry.lua`; `BaseScrollBoxEvents`,
`ScrollControllerMixin.Directions`), `ColorPickerFrame` (`ColorPickerFrameMixin`; `_Pick`, `_Cancel`
for specs), `SetMotionScriptsWhileDisabled`, `IsMouseWheelEnabled`, `IsAutoFocus`, `HighlightText`.

Coverage: `spec/next/controls/*_spec.lua` (each control's look, states, callbacks and restyle;
the Escape stack both ways round), `spec/render/scrollbox_spec.lua` ("with a bar of its own"),
`spec/next/bag_spec.lua` (a panel's bar). Mutation-tested (42 mutations; the three that first
survived led to two tests and to removing a redundant guard).
