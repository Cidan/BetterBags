# BetterBags Next's Settings

BetterBags has one settings window, built from nothing for BetterBags Next (asked; the plan and its
status are in `docs/next-settings.md`): pages grouped down a sidebar, tabs across a page, two-column
rows, and every control BetterBags' own, styled by the Next theme. It is the classic bags' settings
window too, showing what the bags in use read (§7); the classic settings window was removed. It builds
its settings from one catalog.

## 1. The settings catalog (`config/catalog.lua`, `SettingsCatalog`)

Every setting is defined once: its kind (`toggle`, `dropdown`, `slider`), name, description, the
words a search finds it by (`keywords`), its choices (`items`, or `itemsFunction` read each time a
menu opens, form-dropdowns.md) or range (`min`, `max`, `step`), and `get`/`set`: how it is read and
written and what it sends so the bags show it (`bags/Rederive`, `bags/Redraw`, `bags/FullRefreshAll`,
`search/SetInFrame`, `groups/EnabledChanged`; refresh-scheduler.md §9, §10). Before, all of this was
written inside the classic window's code (since removed), so a second window would have had to copy
every setter.

- **A bag's setting** (`bag = true`) is bound to a bag when asked for: `Get(id, bag)` with a
  `SettingBag` (`{ name, kind }`; `Bags()` lists the backpack, the bank, and the guild bank where
  `addon.hasGuildBank`). Its description may be a function of the bag ("... in your backpack.").
  `only` limits it to some kinds (Enable Groups: the backpack); `Has(id, bag)` says whether a bag
  has it. Asking for a bag's setting without a bag, a general one with a bag, or a setting a bag
  does not have is an error naming it.
- **What a window reads** (`SettingOption`): a choice's `get` returns the item chosen, a slider's its
  number.
- **Rules a window follows:** `reload` marks a setting that takes effect after a reload (Enable
  Bank Bags), and `set` returning `false` means the change was refused (BetterBags Next while
  switching is refused: combat, the bank, a vendor) and the window must show the setting again.
- `Ids()` lists every setting in definition order. Defining one twice is an error.

While the classic window existed it was rebuilt on the catalog first, checked entry for entry against
a recording of it (237 entries); that check and the window went together.

Coverage: `spec/config/catalog_spec.lua` (bags, binding to a bag and its text, refusals, choices,
ranges, reload and refusal rules, every setting the classic window had defined once, keywords, What's
New on login) and `spec/config/settings_effects_spec.lua` (what each setting sends: redraws,
recalculations, reads, the guild bank's own, size mode, Snap to Content, Animate Item Movement, the
design switch and its refusal, opacity and scale). Mutation-tested (a setting renamed, dropped or
moved, the slider range, the dropdown shape, Enable Groups on every bag, a bag's name in a
description: each caught).

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
| `NextToggle` | `toggle.lua` | A switch: the knob slides (`Motion.Time.Toggle`), the on color fades in with it. A click flips it and calls back; `SetChecked` calls nothing back, and told the state it is already sliding to it keeps sliding (asked: "animate our toggle switches"; a row showing its value again right after a click saved it stopped the slide, so no switch ever looked animated). A settings row slides a switch whose value changed while it shows (one setting turning another off). |
| `NextInput` | `input.lua` | A text field (an `EditBox`: its text `Padding` in, after an optional `icon` it draws and makes room for itself, help while empty and unfocused) and `CreateArea`, a text area (a multi-line edit box in a Blizzard scroll box with the scroll bar, the wheel taken only while focused, the cursor kept in sight). Only typed text is reported (`OnTextChanged`'s `userInput`); Enter reports and lets go of focus; Escape puts back the text it had when focused. |
| `NextSlider` | `slider.lua` | A track filled up to a thumb, pressed or dragged with the left button, and a number box (`NextInput`); every value snapped to the step and kept in range; a change calls back once per value; the wheel is left to the page. |
| `NextMenu` | `menu.lua` | One menu at a time, `FULLSCREEN_DIALOG`, below what opened it (`Gap`), a row per choice, the chosen one checked, scrolling past `MaxRows`; as wide as its widest choice needs, the list's `Padding` on both sides included (it was left out, and a menu opened from a 36-wide item cell read "Rem..."), at least its anchor. Closes on a pick, a click or the wheel outside it (a screen-sized catcher), Escape, a second open for the same frame, or that frame hiding. |
| `NextDropdown` | `dropdown.lua` | The choice made and a chevron; a click opens a `NextMenu`, its choices read each time (`itemsFunction`, form-dropdowns.md); the choice already made calls nothing back. |
| `NextSwatch` | `swatch.lua` | A square of its color. A click opens Blizzard's color picker (`ColorPickerFrame:SetupColorPickerAndShow`, loaded at login on every client); each color picked (`swatchFunc`, `opacityFunc`) calls back, and Cancel puts the color back and calls that back too, so what was saved follows (the classic item color pane left the saved color changed on Cancel). |
| `NextTopTabs` | `toptabs.lua` | A page's tabs, left to right `Gap` apart, the chosen one in its font and underlined by a marker that glides (`Motion.Time.TabMarker`). The chosen tab calls nothing back. |
| `NextItemGrid` | `itemgrid.lua` | A scrolling grid of item icons (`Controls.ItemGrid`, in an input's fill and edge): as many columns as fit, only the cells of the rows in view made and placed (reused as it scrolls: thousands of items cost a screenful), each with the icon, a count above one, the quality on its edge (Uncommon and up; the plain edge for Common and Poor), faded (`DimAlpha`) for an item showing in another category; the item's tooltip (its link, else `SetItemByID`) with the entry's note and the grid's hint. With `onDrop`, an item dropped anywhere on it (a cell, the box, the frame) or clicked onto it goes there; a right click goes to `onRightClick`, a modified click to `HandleModifiedItemClick`. |
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
| `NextSettingsPages` | `pages.lua` | The pages, in the order defined (`Define`, replacing one with the same id in its place): each in a `group` (the sidebar's headings, in the order their first page was defined), with a `title`, a `description`, an optional `bag` its settings are bound to, `shown()` (a page shown only sometimes: the guild bank), and `tabs` (a tab's `shown()` leaves it out while false; `ShownTabs`). A page may have its own list in the sidebar (`sidebar(parent, owner)`), a `heading()` read in place of its title and description, and buttons in the header (`actions(parent, owner)`): below, "A page's own list". A tab's `sections` (a list, or a function read when the tab is built) hold row definitions: `setting` (a catalog id, bound to the page's bag; one the bag does not have is left out), `option` (a page's own), `text`, `buttons`, or `block` (a function making a wide row, with a `title` and `keywords` for search). Pages are data. |
| `NextSettingsRows` | `rows.lua` | A setting's row: its name (wrapping) on the left and its control on the right (`toggle`, `dropdown`, `slider`, `color`), at least `RowHeight` tall. It reads the option into the control (`Refresh`), writes what the player changes, shows the option again when the change was refused (`set` returns false), and asks in a `NextDialog` over the window to reload after a change that needs one (`reload`). Its description is its tooltip, which stays while the pointer is over its control (`IsMouseOver` on leaving). Rows across the page: `CreateText`, `CreateButtons`, `CreateLink`. Every row answers `Measure(width)`, `Place(x, y, width, height)`, `Refresh(ctx)`, and `wide`. |
| `NextSettingsPage` | `page.lua` | A drawable (render-pipeline.md) laying sections out at the width it is given: a title in capitals and a note, a card of rows in two columns when the page is at least twice `MinColumn` wide (one otherwise), a pair as tall as its taller row, a wide row on a line of its own across both; lines between the card's lines and between a pair's columns; rows of an earlier layout not placed again are hidden; empty text when there are no sections. |
| `NextSettings` | `window.lua` | The window, below. |

**The window** (`BetterBagsNextSettings`, `DIALOG` strata, above every Next panel, toplevel, clamped):
built the first time it opens; centered on every open (moved by dragging its header or brand,
`SetUserPlaced(false)` after a move so the client does not keep the position), its scale at most 1
and at most 95% of either side of the screen (`Settings.Width` x `Height`: 1000 x 720, made 60 taller
for the Categories page, as asked).
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
  elsewhere: a bag's buttons and menus). The window is a render root handing the scroll box the
  content's width and height. A row or a section can be hidden while a function says so
  (`hidden`; a section's title alone with `titleHidden`), checked at every layout; the window lays
  itself out again after every change (`Refresh`), and search finds no hidden row.
- **Footer** (`Settings.Footer`): What's New (a link: `changelog/Open`) and Done (primary: closes).
- **Remembers** the page and tab shown for the session; `Open(pageId, tabId)` goes to one. A page not
  shown now (or unknown) falls back to the first page shown.
- **Escape**: the window takes its place in the controls' Escape stack when it opens and gives it
  back when it hides; a menu or a dialog over it closes first, and both close with it.
- **A page's own list** (asked: "animate away our main nav bar, and replace it with our category list
  [...] with a back button on the top left"; the Categories page, §5). Choosing a page with a `sidebar`
  slides the pages (the brand, search box, page list and version, on `navPanel`) out to the left and
  the page's list in from the right (on `listPanel`), each fading as it leaves, over
  `Settings.Back.Slide` with the `Glide` ease, inside the sidebar, which clips them
  (`SetClipsChildren`, every client). The brand's row stays a mover; Back ("All Settings", the left
  chevron) takes the brand's place above it and the gold line under it. The list is made once
  (`listOf`), placed `Sidebar.Width` x `Height - Brand.Height` under Back, and refreshed on every
  `Select` before the tabs are read (it may choose what the page shows, and so which tabs show).
  Opening the window on such a page puts the list in place at once (`arriving`): the window slides as
  a whole. Back (`settings:Back`) goes to the page and tab shown before the list (kept while the list
  shows: re-selecting inside it never overwrites it), else the first page; a search leaves the list.
  The page's `heading()` titles the header, its `actions` sit right of the title (`Header.Actions`:
  `Top` down, `Gap` left of the close button), the title stopping short of them; they hide on any
  other page. `settings:Reselect(ctx)` shows the page again (heading, buttons, tabs, list, rows) and
  does nothing while the window is closed.
- **The first Escape goes back** (asked). While a list shows, a named frame,
  `BetterBagsNextSettingsBack` (a child of the window), is pushed on the controls' Escape stack above
  the window, so `CloseSpecialWindows` hides it, not the window: its `OnHide` goes back when the window
  still shows and the frame's own flag is off; Escape then belongs to the window again (released on the
  next frame). It is released whenever the window's showing ends (`ended`), because
  `CloseSpecialWindows` checks each listed frame's own `IsShown` (UIParentPanelManager.lua, every
  client): a child left flagged shown under a hidden window would swallow an Escape press meant for the
  game. Reopening on the list (a fade-out included) pushes it again, above the window.
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
buttons, the bag menu, `/bb`) opens `NextSettings`, for either design. On `bags/DesignChanged` the
window, if open, shows the new design's settings and stays open (§7). `core/init.lua` calls
`NextSettings:Init()` after `SonataNext`
(initialization.md). The settings files load after `config\plugin.lua` in every TOC (they need the
catalog).

Coverage: `spec/next/settings/page_spec.lua` (rows: each control kind, layout, refusals, the reload
dialog, the light and tooltip over the control, text, buttons, links; the page: two columns, one
column, wide rows, sections and notes and cards, lines, refresh, rows of an earlier layout hidden,
empty text), `spec/next/settings/window_spec.lua` (built on first open, centered, sized, body, moving,
fitting a small screen, closing three ways, the menu and dialog closing with it, What's New, the
sidebar and its pages, navigation, hover, pages defined later, tabs, content and its scroll bar,
remembering the page, values read again on open, a page not shown, search: matching, live rows,
links, nothing found, hidden pages; rows and sections hidden while a function says so, a title hidden
alone and its room given back, search skipping them; a theme), `spec/config/config_spec.lua` (opening
the window for either design, a switch shown to it), `spec/core/init_spec.lua` (the init order).
Mutation-tested (26 mutations; the one that first survived led to a test).

## 4. The pages (`next/settings/content.lua`, `NextSettingsContent`)

`Init` (from `core/init.lua`, after `NextSettings:Init`) defines the pages in the sidebar's order;
`OnEnable` (from `addon:OnEnable`) names the item level colors' ranges again when the highest item
level seen changes (`itemLevel/MaxChanged`) while Item Colors shows. Every page writes through the
same database calls, with the same effects, as the classic window did; every question is a
`NextDialog` over the window (no `StaticPopup`). A page, section or row may belong to one design
(§7); the table marks those.

| Group | Page (id) | What it shows |
|---|---|---|
| BetterBags | General (`general`) | *Bags:* BetterBags Next, Enable Bank Bags, Show Blizzard Bag Button, Enable Bag Fading (classic), Animate Item Movement (classic). *Search:* In-Bag Search, Enter to Make Category. *Items:* Upgrade Icon Provider, New Item Duration, Category Sell and Deposit. *What's New:* Show What's New on Login. |
| | Appearance (`appearance`) | Theme pickers (`next/settings/themes.lua`, below): BetterBags Next's themes (SonataNext) while Next is in use; for the classic bags, their Bag Theme (Sonata), then Settings Window (SonataNext: Next's themes draw this window). |
| | Item Colors (`itemcolors`) | The four item level colors as swatches, named with their ranges (61% and 86% of the highest item level seen, as the classic pane); a picked color is saved and sent as `itemLevel/MaxChanged` (Cancel saves the color back too); the highest level seen; Reset Colors, Reset Max Item Level. |
| Bags | Backpack, Bank, Guild Bank (`backpack`, `bank`, `guild`) | Each bound to its bag. *Layout:* Order (Section, Item), Tabs (Enable Groups: the backpack only; the bank's Tabs section is left out), Slots (All Free Space, Gaps). *Items:* Item Level (two), Quality (Glow Intensity), Stacking (seven). *Categories:* Automatic (the seven filters). The guild bank's page shows on a client with one (`addon.hasGuildBank`). |
| Profiles | Profiles (`profiles`) | Tab *Profiles:* the active profile (a pick asks, then switches and reloads), the characters on each, New, Copy, Rename, Delete, Reset to Defaults (the classic flows: Copy creates then copies; Delete switches to Default first; Default cannot be renamed or deleted; a name is asked again while empty). Tab *Import / Export* (`transfer`): Export Categories fills a text area and selects it; Import Categories asks, imports (`DB:ImportSettings`), clears the area and offers a reload, or says what is wrong. |
| Integrations | QuickFind (`quickfind`) | What the integration does. |
| | a plugin (`plugin:<title>`) | Below. |

A bag's Layout tab adds, for the classic bags only, *Window:* Resizable Window, Snap to Content, Items
Per Row, Columns, Opacity, Scale, and *Sections:* Show Full Section Names; the Currency page (§8) is
theirs too, and the Guild Bank page is BetterBags Next's alone (§7). A spec checks every setting a page
names exists in the catalog for its bag, and that every classic-only one is marked classic.

**The theme picker** (`NextSettingsThemes`, a wide row): a card per theme the engine lists (not
hidden; unavailable ones too, marked so), sorted by name, each with its description and status
(Active, Previewing, Unavailable). A pick is previewed (applied unsaved) **on the next frame**, the
last pick before then winning: applying restyles this window, which must not happen inside the
click (the classic theme pane's lesson, sonata.md §2). Apply Theme saves it and is off while there is
nothing to save; a pick that cannot be used shows the saved theme; leaving the page (another page,
the window closing: `OnPageLeft`, sent by the page's `Leave`) puts the saved theme back.

**Plugins** (`AddPlugin`, called by `Config:AddPluginConfig`; the plugin's only page since the classic
window went): the options are read the way AceConfigDialog-3.0 reads them (its source, vendored in
`libs/`), checked against 12 published plugins' option tables:
- `options` is an AceConfig group, or the `args` of one (what plugins pass today);
- `get`, `set`, `func`, `confirm`, `validate`, `disabled`, `hidden` are inherited from the groups above;
  a member that is a function is called with AceConfig's `info` (the keys of the way, `options`,
  `option`, `type`, `arg`, `handler`, `appName`), and a string is a method of the nearest `handler`,
  except `name`, `desc` and the other literal members;
- options are in `order` (100 when unset, negative ones last), then by name;
- `hidden`, `disabled` and names are read again after every change, as AceConfigDialog reads them:
  an option is hidden while it or any group it is in says so (a hidden group's options never show,
  whatever they say of themselves), and a hidden `header` hides only its line, never the options after
  it. Real plugins need it: BetterBags_ImportExport shows its "Unknown Items" header, list and Recheck
  button only once an export finds unknown items. (The classic window ignored `hidden`; the first
  version of this page read it once, so they never showed.) A button (an execute) follows its
  `disabled` and its name;
- the plugin's own options go in a section under its title, each group's in a section under the
  group's name, and a `header` starts a section;
- toggle, select (its names shown, its key written; `sorting`, else keys sorted as strings),
  multiselect (a switch per value), range (`softMin`/`softMax`/`bigStep` first; a step of 0 is a
  hundredth of the range), input (one line, or a text area with Accept for `multiline`), color
  (`hasAlpha`), execute, description; anything else is logged, as the classic window did;
- a change goes through `pattern` and `validate` (false or a message refuses it, said in a dialog;
  the row shows the value again), then `confirm` (asked in a dialog), then `set` (`func` for an
  execute, its errors reported to `geterrorhandler`), and the page shows every value again.

Coverage: `spec/next/settings/content_spec.lua` (the pages' order and contents, the catalog check,
the bank without Enable Groups, Appearance's engines, Item Colors (names, saving, Cancel, resets, a
new highest level), every profile flow, import and export, QuickFind, and a plugin page: sections,
order, hidden, toggles with `info`, selects and their order and `sorting`, handler methods by name,
colors, `validate`, multi-line Accept, execute and `confirm`, a group as the root; "what a plugin shows,
hides and disables as it changes": BetterBags_ImportExport's shape, a hidden group's options, a hidden
header's line alone, a button's disabled and name), `spec/integration/next_settings_spec.lua` (both
designs on the whole addon),
`spec/next/settings/themes_spec.lua` (cards, layout, previewing on the next frame, the last pick,
Apply Theme, an unusable pick, leaving the page, hover), `spec/config/plugin_spec.lua` (a plugin's
page and nothing else),
`spec/core/init_spec.lua` (init order, enabling). Mutation-tested (39 mutations; the three that first
survived led to two tests and to removing dead code).

`NextSettings:Init` now forgets the page shown too: a new session kept the old window's page and
left it again when showing the first page (seen as the theme pickers restoring a theme of a window
long gone; `spec/next/settings/window_spec.lua`, "forgets the page of a window from an earlier
session").

## 5. Categories: the Categories page and each bag's arrangement

Asked (2026-10-20): categories get a dedicated space, as currency did; defined once, applied to bags;
item and search categories combined, each able to hold both. Then (2026-10-21), after the first version
crowded a list and an editor into one box (a cut-off button, a scrolling page, unclear "Placed Here",
icons over text, no room to drop onto a long list): the list moves to the sidebar, the category gets
the whole content area in three tabs, and the window grew to 720. A fourth, Automation, came with
category automation (2026-10-22, automation.md). The data model is
category-lifecycle.md §6. Every question is a `NextDialog` over the window.

**The Categories page** (`next/settings/categories.lua`, `NextSettingsCategories`; page `categories`,
BetterBags group after Item Colors, both designs). It is a page with its own list (§3): its sidebar is
`CreateList`, its heading `Heading()`, its buttons `CreateActions`, and its tabs one wide block each,
their section titles hidden, each filling the content without scrolling (`ContentHeight` less the
page's `Content.Top` and `Bottom`).
- **The list** (in the sidebar): a filter box where the settings search box is; every category, yours
  and the plugins', in their order, which is their priority (category-lifecycle.md §7), a group by's
  sub-categories left out; each row a color dot, the name and how many of the shown bags' items it
  holds, "N items matching" ("1 item matching"; asked: "just have the subtext to categories say 'x
  items matching'"). The count is the Settings tab's Current Items in this Group: each item once, its
  group by's sections with it, in the bags the settings show (`matchingCounts`, one pass over the
  items, each counted for its category and every name its category is a section of: `isShownIn`'s
  rule). It is counted again on `items/Refresh<Kind>/Done` (every bag) while the list shows. New
  Category at the bottom where the version is (`{ name, itemList = {}, save = true }`, chosen, on top).
  Dragging a row moves its category (`listProto:Drop` → `categories:MoveCategory`): after the row above
  where it is let go, or right before the first row shown when let go above them; the categories a
  filter hides keep their places. The rows are arranged and dragged by `NextListReorder` (below). No
  tooltip (asked: no help text yet). The first category is chosen when
  none is (`EnsureChosen`); clicking one chooses it (`Choose`, then `Reselect`). On `categories/Changed` while
  it shows, the page shows again, the first chosen for one that is gone.
- **The header**: the chosen category's name, and its line (a plugin's starts "Made by a plugin");
  "Categories" and "Make a category to sort your items your way." for none. Rename and Delete for your
  categories; for a plugin's or none they hide and the buttons' frame shrinks so the title takes the
  room.
- **The two item boxes stay put** (asked: boxes a few pixels apart made switching tabs messy): the
  Settings and Search Rule tabs put their box's name row and their box at the same place
  (`boxRows`: under three rows of settings, a row for the name, the box down to the tab's bottom).
- **Settings tab**: three rows, Used In (a switch per bag the settings show, the guild bank like any),
  Group By (yours only; the row stays empty for a plugin's), Color (and
  Reset Color: none, drawn in gold); then **Current Items in this Group** (the player's wording): how
  many items each bag shows in it (its group by's sections too) and those items in a read-only grid,
  one cell per item with how many there are, by name, or "There are no current items in your
  inventory that match this category". With no category it says to make one.
- **Search Rule tab** (asked: "Search Rule" everywhere; yours, and a plugin's that has a rule): the
  search in a field taking the room down to the **Search Results** row, which counts them beside its
  name as it is typed ("Search Results (3 results)", "(invalid search)" for a mistake, caught from
  `Search:Search` in a protected call; asked: no line about an empty rule), with Apply Search Rule on
  its right, on only when the rule changed and has no mistake (it saves it, none for an empty one).
  The results are a grid in full color (asked), those showing in this category first; the tooltip of
  one showing elsewhere says "Shows in X." What is typed is kept while the same category shows. A
  plugin's rule shows read-only (the field disabled, no Apply Search Rule).
- **Added Items tab** (asked: "Placed Here" made no sense; its line "Drag an item here to manually add
  it to this category."): how many items were added (or "3 of 12"
  while filtered), a filter by name, Remove All (asks first; `WipeCategory`, then the bags
  recalculated), and the items in a `NextItemGrid` that holds thousands: icons at once
  (`GetItemInfoInstant`), names and qualities from `C_Item.GetItemNameByID` / `GetItemQualityByID`, the
  names not loaded yet asked for once per category (`ContinuableContainer`) and the list shown again
  when they arrive; by name, those not known yet last. An item in your bags that shows in another
  category is faded, "Shows in X instead." An item dropped anywhere on the grid is added
  (`AddPermanentItemToCategory`, `ClearCursor`, the bags recalculated; asked: the items themselves
  are drop targets); a right click offers Remove. A plugin's items show read-only (no drop, no remove,
  no Remove All).
- **Automation tab** (automation.md §5): a section ("Merchants") of three settings rows, drawn as every
  page's settings (not controls of its own): Auto Sell, Confirm Auto Sell (on by default) and Destroy
  What Can't Be Sold, the last two disabled while Auto Sell is off, saved at once
  (`NextSettingsCategories:AutomationOptions`). Shown while a category is chosen, a plugin's too. The
  heading's line ends "Sells at merchants" or "Sells, destroys the rest".
- `NextSettingsCategories:Show(name)` chooses a category for the next time the page shows (a bag's tab
  links here); `NewFromSearch(query)` makes the list ask for a new category's name with the search as
  its rule (the search box's Enter to Make Category, through `config/NewCategoryFromSearch`, which
  Config handles by opening the page). Both are used once.

**A bag's Categories tab** keeps Automatic (the built-in filters) and, in place of the old manager,
"In This Bag" (`next/settings/bagcategories.lua`, `NextSettingsBagCategories`, `Create(parent,
window, bag)`, `Settings.BagCategories` tall): a filter box; "Pinned" in their order
(`customSectionSort[kind]`), then "Other Categories" by name: the categories defined and the bag's
sections from its committed items (not empty slots, Recent Items, Free Space, or Show Bags' bags).
- A defined category has a switch for this bag (`UpdateCategory { enabled = { [kind] = on } }`); its
  name opens it on the Categories page (`Show`, then `NextSettings:Open("categories")`), and Back
  returns to the bag's tab.
- A group by's sub-category says whose it is ("Grouped by Potions") and opens that one.
- A built-in section says "Automatic"; a pinned name that is neither (a leftover) has Remove
  (category-lifecycle.md §4).
- Shift-click pins at the top or unpins; dragging a row drops it after the entry above the pointer's
  half of a row (above the "Other Categories" heading pinned there, below it unpinned; never above the
  "Pinned" heading, `first = 2`). The order is saved from 1 (the pins a filter hides keep their order
  after the ones it shows) and the bags recalculated (`bags/Rederive { resetLayout, buttons }`). Read
  again on the bag's `items/Refresh<Kind>/Done` and on `categories/Changed` while it shows.

**Dragging a row** (`NextListReorder`, `next/settings/reorder.lua`), shared by both lists. Asked:
"instead of a line on drag, let's animate the move like we do categories (again, re-inventing drag
handling, we do this amazingly in the bags today, look how it's done, be careful)". The first version
drew a gold line where the row would land, a drag of its own; now a row moves exactly as a bag's
section does (next.md §7), through the same code:
- **Each entry has its own row** (`rowOf`: the Categories page keys them by name, the bag's tab by name
  and a heading by a key of its own, so a category named like a heading still has its own). Rows of
  entries no longer listed (a filter, a delete) hide and wait to be reused. So when a category moves in
  the order, its own row slides there.
- **Arranging** (`Arrange(width)`): the rows one under another, each as wide as the list (Motion anchors
  only a frame's top left), placed through Motion in a pass of the list (`BeginPass(list,
  Time.Interaction)`), as the canvas places sections: while the list shows, a row whose place changed
  slides there (0.24 s, the bags' interaction time); a row newly shown, and everything while the list is
  hidden, is put there at once. The content is as tall as the rows. Both lists call it after every
  layout, and when they are placed (a new width).
- **Picking up** (the row's `OnDragStart`): the row is lifted with `NextLift` (`next/lift.lua`, moved out
  of NextDrag so both drags are one): onto the drag layer where it was on screen, a cover over it, the
  theme's shadow under it, shrinking to `Drag.LiftScale` around the point grabbed over `Time.Lift`,
  following the cursor. The list keeps a room the row's height where it was. One drag at a time, and
  none while NextLift holds another frame (a section waiting in the vendor's dock).
- **Making room**: every frame the room goes before the first other row whose middle is below the cursor
  (counting what the list is scrolled), never before `first`, and the rows slide out of its way. Near the
  list's top or bottom (40 pixels) the list scrolls toward the edge, faster closer (`NextLift:AutoScroll`,
  the bags' auto-scroll).
- **Letting go** (the left button found up): the row lands into its room over `Time.Land`, back to full
  size, aiming at the room every frame (`NextLift:Land`), then goes back in the list there. Its owner is
  told what it lands after, counted with the row itself (`onDrop(name, after)`, 0 before the first:
  the owners' `Drop` contract), unless it landed where it was. An owner that draws the list again (the
  bag's tab, and the Categories page through `categories/Changed`) shows the new order; otherwise the
  list reorders its entries itself, so nothing slides back.
- **Ending early**: the list hiding mid-drag, or the dragged entry leaving the list, puts the row
  straight back in its place.
- No hardware event is needed (nothing protected runs), so letting go is read from the mouse button
  each frame, as the bags read a missed release.
- Mutation-tested with the shared lift and NextDrag on it: 74 mutations. Twelve first survived: ten led
  to tests (a frame with its own strata, the level it is put back at, a second drag, the half-row rule,
  following the cursor, ignoring the cursor while landing, a scrolled landing, reusing rows put away,
  the Pinned heading staying on top, NextDrag's landing aiming at its gap), one was a redundant tween stop
  in NextDrag's Cancel (removed: putting the frame back stops it), and one cannot be told apart with the
  mocks (NextDrag finishing a section's flight into the dock before it leaves the dock: the mock frames'
  screen rectangles do not follow their anchors). That last one is NextDrag's behavior from before,
  unchanged.

Coverage: `spec/next/settings/categories_spec.lua` (the list: order, place, filter, choosing,
a category chosen elsewhere, New Category, a search waiting, changes; "N items matching" as the Settings
tab counts, in the bags shown, counted again when a bag is read while it shows; a drag lifting a row,
the others making room, landing it and moving its category; each category's own row, its width, rows put
away; the heading and which tabs show;
Rename and Delete; the Settings tab: its height, none, fields, saving, a plugin's, what the bags show
and reading them again; the Search Rule tab: its names, the count as typed, the results in full color,
the box where the Settings tab's is, Apply Search Rule, typed text kept, a plugin's; the Added Items
tab: order, icons, faded items, the filter, names loading once, drops, removing, Remove All, a plugin's,
its line), `spec/next/controls/itemgrid_spec.lua` (columns, only the rows in view, scrolling to the
end, empty text, cells, tooltips, clicks, drops, the theme), `spec/next/settings/window_spec.lua` ("a
page with its own list": sliding, Back, opening on it, the first Escape, closing and reopening on it, a
fade-out, heading and buttons, tabs shown, tabs read after the list, Reselect, a search, nothing while
closed), `spec/next/settings/bagcategories_spec.lua` (and its drag: lifted, room made, pinned where
it lands, never above the Pinned heading; its own rows, a category named like a heading),
`spec/next/settings/reorder_spec.lua` (arranging: places, widths, height, at once while hidden, sliding
while shown in the interaction time; dragging: the lift, the room under the cursor, `first`, scrolled,
no place on screen, auto-scroll, one drag at a time; letting go: landing aimed at the room, what it lands
after, before every other, the order shown by the list or its owner, nothing for no move; ending when the
list hides or the entry goes), `spec/next/lift_spec.lua` (the shared lift), `spec/next/settings/content_spec.lua` (the page's
list, heading, buttons and three tabs, the bags shown), `spec/integration/next_settings_spec.lua`
(every tab built on the whole addon; the list in the sidebar and the first Escape on the real window),
`spec/next/controls/input_spec.lua` (`commitOnBlur`, a disabled text area),
`spec/next/controls/dropdown_spec.lua` (a menu's whole text from a narrow anchor), `spec/frames/search_spec.lua`
and `spec/config/config_spec.lua` (Enter to Make Category). Mutation-tested: the window's list mode and
the grid (37 mutations; the three survivors led to two tests and dead code removed), the tabs (50; the
survivors led to three tests and two dead guards removed), the controls and the recorder (10; one
equivalent).

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
  - **Classic only:** General → Bags: Enable Bag Fading, Animate Item Movement; General → Search:
    Enable Enter to Make Category (only the classic bags' search box reads it); a bag's Layout →
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
- **The classic window was removed** with everything only it used: `config/config.lua`'s form window,
  the Theme, Category, Currency (retail, Classic, Era) and Item Color panes, and the catalog's `Form`
  adapter. `Config` keeps the slash commands (`/bb`, `/bb changelog`, `/bb next`, `/bbanchor`,
  `/bbdb`), `config/Open` and `Config:AddPluginConfig` (config/README.md). The Form module stays: the
  profiler's settings use it. Every option the classic window had has a place here; besides, three
  options live where they always did, outside any settings window: debug mode (`/bbdb`), and the bag
  menu's Bag Anchor and Drag to Resize (the latter is Resizable Window too).

Coverage: `spec/next/settings/window_spec.lua` ("by design": pages, sections and rows per design, a
switch while open and while closed, search), `spec/next/settings/content_spec.lua` (each page's
contents with their designs marked, the classic-only settings all marked classic, the guild bank per
design, rows and columns per design, Appearance per design), `spec/config/catalog_spec.lua` (What's
New on login), `spec/config/config_spec.lua` (one window for either design, a switch shown to it, the
slash commands, no classic window), `spec/config/settings_effects_spec.lua` (what every setting sends,
moved from the classic window's spec) and `spec/integration/next_settings_spec.lua` (on the whole
addon: every page and tab of each design built, rows and columns for the classic bags, turning
BetterBags Next off from the window keeping it open on the classic bags' settings). Mutation-tested
(12 mutations for the designs, 4 for `Config`; the one that first survived led to a test).

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
