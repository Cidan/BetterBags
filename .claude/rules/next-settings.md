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
| `NextInput` | `input.lua` | A text field (an `EditBox`: its text `Padding` in, after an optional `icon` it draws and makes room for itself, help while empty and unfocused) and `CreateArea`, a text area (a multi-line edit box in a Blizzard scroll box with the scroll bar, the wheel taken only while focused, the cursor kept in sight). Only typed text is reported (`OnTextChanged`'s `userInput`); Enter reports and lets go of focus; Escape puts back the text it had when focused. |
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

## 3. The window (`next/settings/`)

| Module | File | What it is |
|---|---|---|
| `NextSettingsPages` | `pages.lua` | The pages, in the order defined (`Define`, replacing one with the same id in its place): each in a `group` (the sidebar's headings, in the order their first page was defined), with a `title`, a `description`, an optional `bag` its settings are bound to, `shown()` (a page shown only sometimes: the guild bank), and `tabs`. A tab's `sections` (a list, or a function read when the tab is built) hold row definitions: `setting` (a catalog id, bound to the page's bag; one the bag does not have is left out), `option` (a page's own), `text`, `buttons`, or `block` (a function making a wide row, with a `title` and `keywords` for search). Pages are data. |
| `NextSettingsRows` | `rows.lua` | A setting's row: its name (wrapping) on the left and its control on the right (`toggle`, `dropdown`, `slider`, `color`), at least `RowHeight` tall. It reads the option into the control (`Refresh`), writes what the player changes, shows the option again when the change was refused (`set` returns false), and asks in a `NextDialog` over the window to reload after a change that needs one (`reload`). Its description is its tooltip, which stays while the pointer is over its control (`IsMouseOver` on leaving). Rows across the page: `CreateText`, `CreateButtons`, `CreateLink`. Every row answers `Measure(width)`, `Place(x, y, width, height)`, `Refresh(ctx)`, and `wide`. |
| `NextSettingsPage` | `page.lua` | A drawable (render-pipeline.md) laying sections out at the width it is given: a title in capitals and a note, a card of rows in two columns when the page is at least twice `MinColumn` wide (one otherwise), a pair as tall as its taller row, a wide row on a line of its own across both; lines between the card's lines and between a pair's columns; rows of an earlier layout not placed again are hidden; empty text when there are no sections. |
| `NextSettings` | `window.lua` | The window, below. |

**The window** (`BetterBagsNextSettings`, `DIALOG` strata, above every Next panel, toplevel, clamped):
built the first time it opens; centered on every open (moved by dragging its header or brand,
`SetUserPlaced(false)` after a move so the client does not keep the position), its scale at most 1
and at most 95% of either side of the screen (`Settings.Width` x `Height`).
- **Sidebar** (`Settings.Sidebar`): the brand (the bag glyph and "BetterBags", a gold line fading out),
  the search box (a `NextInput` whose `icon` is the magnifier: the field lays out its own room for it, so a theme restyling the fields after the window can no longer put the help text over it, as seen in game), the pages under their headings (rebuilt on every
  open, so a page defined since shows: plugins), the chosen one with a gold bar, a fill and its font,
  the others lit under the pointer; the version (`C_AddOns.GetAddOnMetadata`, nothing for a source
  checkout's `@project-version@`).
- **Header** (`Settings.Header`): the page's title and description; the close glyph at the top right.
- **Tabs**: a `NextTopTabs` under the header for a page with more than one tab; the content starts
  under them.
- **Content**: the page's tab as a `NextSettingsPage`, made the first time it shows and kept, in a
  Scrollbox with the Next scroll bar; its values are read again every time it shows (they can change
  elsewhere: the classic window, a bag's buttons). The window is a render root handing the scroll box
  the content's width and height.
- **Footer** (`Settings.Footer`): What's New (a link: `changelog/Open`) and Done (primary: closes).
- **Remembers** the page and tab shown for the session; `Open(pageId, tabId)` goes to one. A page not
  shown now (or unknown) falls back to the first page shown.
- **Escape**: the window takes its place in the controls' Escape stack when it opens and gives it
  back when it hides; a menu or a dialog over it closes first, and both close with it.
- **Coming and going** (asked: "the same animation as bags when they are detached"): as a small
  Next panel does (next/panel.lua `setOffset`), it slides `Small.Slide` in from the right as it fades
  in, over `Motion.Time.Open` with the `SmallOpen` ease, and out to the right as it fades out, over
  `Time.Close` with `SmallClose`, then hides; its alpha is `1 - |offset| / Small.Slide`. It is closed
  from the moment it starts fading (`IsShown` false, its page left, a menu or dialog over it closed).
  It slides from where it is: centered on opening, where the player moved it on closing; opened again
  while fading out, it comes back from where it is. Escape hides it at once, as it does a bag (Blizzard's
  `CloseSpecialWindows` hides the frame), stopping the slide and putting it back at full strength. A
  drag while it slides in settles it into place first. No sound plays.
- **Search**: typing lists every setting matching the text (case-insensitive, in its name,
  description, searching words or section's title; a block by its name or words) as live rows, a
  section per page and tab ("Backpack > Items", a page with one tab by its title alone) led by a link
  to it (going there leaves the search). Pages not shown are left out; nothing found says so;
  clearing the box (or Escape in it) goes back to the page. Result rows are made once per setting and
  kept for later searches.
- **Theme**: `ApplyStyle` restyles every part and lays the window out again.

**Opening it** (`config/config.lua`): `config:Open` (the `config/Open` message: the settings
buttons, the bag menu, `/bb`) opens `NextSettings` while BetterBags Next is in use
(`BagSystem:ActiveDesign()`) and the classic window otherwise. On `bags/DesignChanged`, a switch made
from the classic window (it is shown, the design is now `next`) hides it and opens BetterBags Next's
on General, where the switch is; one made from BetterBags Next's (shown, design now classic) closes
it and shows the classic one. `core/init.lua` calls `NextSettings:Init()` after `SonataNext`
(initialization.md). The settings files load after `config\plugin.lua` in every TOC (they need the
catalog).

Coverage: `spec/next/settings/page_spec.lua` (rows: each control kind, layout, refusals, the reload
dialog, the light and tooltip over the control, text, buttons, links; the page: two columns, one
column, wide rows, sections and notes and cards, lines, refresh, rows of an earlier layout hidden,
empty text), `spec/next/settings/window_spec.lua` (built on first open, centered, sized, body, moving,
fitting a small screen, closing three ways, the menu and dialog closing with it, What's New, the
sidebar and its pages, navigation, hover, pages defined later, tabs, content and its scroll bar,
remembering the page, values read again on open, a page not shown, search: matching, live rows,
links, nothing found, hidden pages; a theme), `spec/config/config_redraw_spec.lua` (opening the
design's window, swapping windows on a switch), `spec/core/init_spec.lua` (the init order).
Mutation-tested (26 mutations; the one that first survived led to a test).

## 4. The pages (`next/settings/content.lua`, `NextSettingsContent`)

`Init` (from `core/init.lua`, after `NextSettings:Init`) defines the pages in the sidebar's order;
`OnEnable` (from `addon:OnEnable`) names the item level colors' ranges again when the highest item
level seen changes (`itemLevel/MaxChanged`) while Item Colors shows. Every page writes through the
same database calls, with the same effects, as the classic window; every question is a
`NextDialog` over the window (no `StaticPopup`).

| Group | Page (id) | What it shows |
|---|---|---|
| BetterBags | General (`general`) | *Bags:* BetterBags Next, Enable Bank Bags, Show Blizzard Bag Button. *Search:* In-Bag Search, Enter to Make Category. *Items:* Upgrade Icon Provider, New Item Duration, Category Sell and Deposit. |
| | Appearance (`appearance`) | Two theme pickers (`next/settings/themes.lua`, below): BetterBags Next's themes (SonataNext), then the classic themes (Sonata), which draw Next's item buttons and dialogs unless the Next theme does. |
| | Item Colors (`itemcolors`) | The four item level colors as swatches, named with their ranges (61% and 86% of the highest item level seen, as the classic pane); a picked color is saved and sent as `itemLevel/MaxChanged` (Cancel saves the color back too); the highest level seen; Reset Colors, Reset Max Item Level. |
| Bags | Backpack, Bank, Guild Bank (`backpack`, `bank`, `guild`) | Each bound to its bag. *Layout:* Order (Section, Item), Tabs (Enable Groups: the backpack only; the bank's Tabs section is left out), Slots (All Free Space, Gaps). *Items:* Item Level (two), Quality (Glow Intensity), Stacking (seven). *Categories:* Automatic (the seven filters). The guild bank's page shows on a client with one (`addon.hasGuildBank`). |
| Profiles | Profiles (`profiles`) | Tab *Profiles:* the active profile (a pick asks, then switches and reloads), the characters on each, New, Copy, Rename, Delete, Reset to Defaults (the classic flows: Copy creates then copies; Delete switches to Default first; Default cannot be renamed or deleted; a name is asked again while empty). Tab *Import / Export* (`transfer`): Export Categories fills a text area and selects it; Import Categories asks, imports (`DB:ImportSettings`), clears the area and offers a reload, or says what is wrong. |
| Integrations | QuickFind (`quickfind`) | What the integration does. |
| | a plugin (`plugin:<title>`) | Below. |

Settings only the classic bags read stay in the classic window: Enable Bag Fading, Animate Item
Movement, Show Full Section Names, Resizable Window, Snap to Content, Items Per Row, Columns,
Opacity, Scale; and Currency. A spec checks every setting a page names exists in the catalog for
its bag, and none of these is named.

**The theme picker** (`NextSettingsThemes`, a wide row): a card per theme the engine lists (not
hidden; unavailable ones too, marked so), sorted by name, each with its description and status
(Active, Previewing, Unavailable). A pick is previewed (applied unsaved) **on the next frame**, the
last pick before then winning: applying restyles this window, which must not happen inside the
click (the classic theme pane's lesson, sonata.md §2). Apply Theme saves it and is off while there is
nothing to save; a pick that cannot be used shows the saved theme; leaving the page (another page,
the window closing: `OnPageLeft`, sent by the page's `Leave`) puts the saved theme back.

**Plugins** (`AddPlugin`, called by `Config:AddPluginConfig`, which still fills the classic window
too): the options are read the way AceConfigDialog-3.0 reads them (its source, vendored in `libs/`):
- `options` is an AceConfig group, or the `args` of one (what plugins pass today);
- `get`, `set`, `func`, `confirm`, `validate`, `disabled`, `hidden` are inherited from the groups above;
  a member that is a function is called with AceConfig's `info` (the keys of the way, `options`,
  `option`, `type`, `arg`, `handler`, `appName`), and a string is a method of the nearest `handler`,
  except `name`, `desc` and the other literal members;
- options are in `order` (100 when unset, negative ones last), then by name; hidden ones are left out
  (read when the page is first built);
- the plugin's own options go in a section under its title, each group's in a section under the
  group's name, and a `header` starts a section;
- toggle, select (its names shown, its key written; `sorting`, else keys sorted as strings),
  multiselect (a switch per value), range (`softMin`/`softMax`/`bigStep` first; a step of 0 is a
  hundredth of the range), input (one line, or a text area with Accept for `multiline`), color
  (`hasAlpha`), execute, description; anything else is logged, as the classic window does;
- a change goes through `pattern` and `validate` (false or a message refuses it, said in a dialog;
  the row shows the value again), then `confirm` (asked in a dialog), then `set` (`func` for an
  execute, its errors reported to `geterrorhandler`), and the page shows every value again.

Coverage: `spec/next/settings/content_spec.lua` (the pages' order and contents, the catalog check,
the bank without Enable Groups, Appearance's engines, Item Colors (names, saving, Cancel, resets, a
new highest level), every profile flow, import and export, QuickFind, and a plugin page: sections,
order, hidden, toggles with `info`, selects and their order and `sorting`, handler methods by name,
colors, `validate`, multi-line Accept, execute and `confirm`, a group as the root),
`spec/next/settings/themes_spec.lua` (cards, layout, previewing on the next frame, the last pick,
Apply Theme, an unusable pick, leaving the page, hover), `spec/config/plugin_spec.lua`,
`spec/core/init_spec.lua` (init order, enabling). Mutation-tested (39 mutations; the three that first
survived led to two tests and to removing dead code).

`NextSettings:Init` now forgets the page shown too: a new session kept the old window's page and
left it again when showing the first page (seen as the theme pickers restoring a theme of a window
long gone; `spec/next/settings/window_spec.lua`, "forgets the page of a window from an earlier
session").

## 5. The category manager (`next/settings/categories.lua`, `NextSettingsCategories`)

The last section of each bag page's Categories tab ("Your Categories"), a wide row made for its bag
(`Create(parent, window, bag)`), `Settings.Categories` tall. It keeps everything the classic pane does
(config/categorypane.lua, category-lifecycle.md), through the same `Categories` and `Database` calls,
every question a `NextDialog` over the window.

- **The list** (left, `ListWidth`): "Pinned", the pinned categories in their order
  (`customSectionSort[kind]`), then "Other Categories": every other one by name, the categories defined
  (`Categories:GetAllCategories`) and the bag's sections read from its **committed items**
  (`Items.slotInfo[kind].itemsBySlotKey`, `itemInfo.category`; not empty slots, Recent Items or Free
  Space, and none in Show Bags, whose sections are the bags). The classic pane read the classic view's
  sections, which BetterBags Next does not have. Each shows its priority ("P:n"). The list is read again
  when the bag's items are (`items/Refresh<Kind>/Done`) while it shows, and every time the page shows.
- **Pinning:** Shift-click pins a category at the top of Pinned, or unpins a pinned one (the classic
  pane only pinned). Dragging a row (the left button, a marker where it would land) drops it after the
  entry above the pointer's half of a row: above the "Other Categories" heading it is pinned at that
  place, below it unpinned. The order is saved from 1, as the classic pane saved it
  (`ClearCustomSectionSort`, `SetCustomSectionSort`), and the bags recalculated
  (`bags/Rederive { resetLayout, buttons }`).
- **New Category** asks for a name (asked again while empty or taken) and makes an item list category
  (`CreateCategory { name, itemList = {}, save = true }`). **New Search Category** (new) asks for a name
  and shows the category as a draft: it is made when saved with a query (an empty query is refused,
  as the search category editor refuses one).
- **A search category:** its query (a text area), the group by clause kept in step both ways (typing
  `group by type` picks Type; picking one rewrites the clause; a stored group by not in the query is
  added to it), Priority (0-99, 10 when it cannot be read), Group By, Color (and Reset Color, Warcraft
  gold), Show Section (`ToggleCategoryShown`, at once), its items, Save (`CreateCategory` with the query
  without its clause, the group by, the items kept, the color none for gold), Rename, Delete.
- **An item list category:** Color, Priority, Show Section, its items, Save (keeping how it is saved:
  `save = filter.save`), Rename, Delete.
- **Items:** item rows (`ItemRowFrame`, released when the list changes) of
  `Categories:GetMergedCategory`'s items. An item dropped on them (`OnReceiveDrag`, or a left click
  holding one) is added (`AddPermanentItemToCategory`, `ClearCursor`); anything not an item is ignored.
  A right click on a row offers Remove (`DeleteItemFromCategory`).
- **A built-in or leftover category** (no filter): what it is, and Remove Category (the escape hatch,
  category-lifecycle.md §4; `DeleteCategory`).
- **Rules kept:** a dynamic category cannot be renamed ("Cannot Rename"), a group by sub-category
  cannot be deleted ("Cannot Delete"); a rename to a taken name is asked again, and one
  `RenameCategory` refuses says so; renaming keeps the category chosen, deleting chooses none.

Coverage: `spec/next/settings/categories_spec.lua` (the list and its sources, Show Bags, layout,
choosing, Shift-click both ways, drops and a pinned row moved down, dragging with the mouse, reading
the list again, new categories of both kinds, a search category's fields, the clause both ways, Save
and its color and priority, Show Section, Rename both failures, Delete; an item list category's fields,
Save, items dropped and removed, non-items; the rules; nothing chosen) and
`spec/next/settings/content_spec.lua` (the manager on the Categories tab, bound to its bag).
Mutation-tested (40 mutations; the three that first survived led to three tests).

## 6. The themes

Default carries every `Settings` and `Controls` value (next-themes.md §3), from palette colors, so a
theme that only changes its palette changes the window too; each shipped theme sets what its look
needs beyond that:
- **Ember** and **Quiet**: `ControlFill`, `ControlHover`, `ControlPressed` and `Track` in their own
  colors (Default's are indigo: on their bodies they would be patches of the wrong color), derived from
  their search box fills as Default's are from its own (0.89, 1.15 and 0.71 of it; the track 1.5).
  Ember's `Danger` is a red apart from its amber. Quiet's settings titles are smaller with its smaller
  panel title, and its switches and tab markers quicker.
- **Parchment**: the window's body, its menus and its dialogs on the paper art (`Settings.Fill`,
  `Controls.Menu.Fill`, `Controls.Dialog.Card`), no wash; every text role of the window and the
  controls in ink (`Ink`, `InkSoft`, `InkMuted`), sealing wax (`Seal`) where Default is gold (the
  chosen page's bar, the brand, the tab marker, a switch on, a slider's fill, a primary button, the
  category manager's marks); fields a lighter paper edged in ink; `Danger` Blizzard's
  `PARCHMENT_ACCESSIBILITY_RED`, as the bags' Parchment theme uses.

`SonataNext:Check` checks every name in both sections on every client (its color keys gained
`IconColor`; its font keys the new role keys; its texture keys `Icon`).

Coverage: `spec/sonata/next_themes_spec.lua` (each theme's settings and controls; every theme checked
clean on every client), `spec/next/settings/window_spec.lua` ("is restyled by a theme SonataNext
applies"). Mutation-tested (11 mutations: misspelled colors, fonts, glyphs and palette names in both
sections, and Ember's and Quiet's fields left indigo; each caught).

On the whole addon (`spec/integration/next_settings_spec.lua`: every TOC file, the real database,
catalog, categories and bags): `config/Open` opens the window of the design in use, every page and
tab builds without an error and shows something, rows read the real settings, search finds the
stacking settings of every bag, and turning BetterBags Next off from its own window opens the classic
one.

Not seen in game yet: the whole window, on every theme (phase 7 of docs/next-settings.md).

## 7. One window for both designs (what the bags in use read)

Asked (2026-10-20): this window is the settings window of the classic bags too (the classic window is
gone), it shows only what the bags in use read, and nothing the classic window had is missed.

- **`design`** on a page, a section or a row (`"next"` or `"classic"`) shows it only while those bags
  are in use (`NextSettingsPages:DesignInUse()`: `BagSystem:ActiveDesign() == "next"`, else classic).
  The window filters pages (`IsShown`), sections and rows when it builds a tab (each tab is made once
  per design: the cache key is `design:tab`) and when it searches.
- **A design switch while the window is open** (`NextSettings:OnDesignChanged`, from
  `bags/DesignChanged`): it lists its pages again and shows its page (the first page for one the new
  design does not have) or its search again, staying open. Closed, it does nothing; the next open
  builds for the design in use.
- **What each design reads** (checked with `grep` over `next/`, `frames/`, `views/`, `core/`):
  - **Classic only:** General → Bags: Enable Bag Fading, Animate Item Movement; a bag's Layout →
    Window: Resizable Window, Snap to Content, Items Per Row, Columns, Opacity, Scale, and → Sections:
    Show Full Section Names (asked: rows and columns in the classic bags' Layout, not Next's);
    Appearance: Bag Theme (Sonata) and Settings Window (SonataNext: Next's themes draw this window);
    Currency (§8).
  - **Next only:** the Guild Bank page (the classic bags have no guild bank); Appearance: Theme
    (SonataNext). The classic themes' picker (item buttons) is not shown in Next (asked).
  - Everything else, both.
- **Show What's New on Login** (General → What's New, `changelogOnLogin` in the catalog,
  `DB:Get/SetChangelogAutoOpen`): before, only the changelog window's "Don't show me this again"
  checkbox set it. The changelog window reads it when it opens, so both agree.

Coverage: `spec/next/settings/window_spec.lua` ("by design": pages, sections and rows per design, a
switch while open and while closed, search), `spec/next/settings/content_spec.lua` (each page's
contents with their designs marked, the classic-only settings all marked classic, the guild bank per
design, rows and columns per design, Appearance per design), `spec/config/catalog_spec.lua` (What's
New on login). Mutation-tested (12 mutations; the one that first survived led to a test).

## 8. The Currency page (`next/settings/currency.lua`, `NextSettingsCurrency`)

The classic bags' currency icons (`frames/currency.lua`, up to 7 at the bottom of the backpack) read
Blizzard's own "show in backpack" flag. The Currency page (BetterBags group, after Item Colors,
`design = "classic"`, shown on clients with currencies: retail, WoW: Forever and Mists Classic; TBC and
Era have none, where the classic window said "not available") replaces the classic window's currency
panes with a wide row: every currency under its headings (the headings Blizzard keeps collapsed are
expanded, as the backpack's icons expand them), each with its icon, how many you have (of its most)
and a switch. The switch writes `SetCurrencyBackpack`; once the game has taken it (0.1 s, as the
classic pane waited) the page reads the list again and sends `currency/Updated`, which redraws the
backpack's icons. `C_CurrencyInfo` where the client has it, else the legacy globals (Mists Classic),
whose expand and show flags are numbers (`ExpandCurrencyList(i, 1)`, `SetCurrencyBackpack(i, 1|0)`,
Blizzard_TokenUI). No cap on how many are shown: the classic pane had none (Blizzard's token frame caps
its own display, `MAX_WATCHED_TOKENS`).

Coverage: `spec/next/settings/currency_spec.lua` (the list and its expansion, a row's icon, count and
switch, headings without one, writing and the message after the game took it, the legacy API, height
and the empty text), `spec/next/settings/content_spec.lua` (the page per client and design, search).
Mutation-tested (10 mutations, each caught).
