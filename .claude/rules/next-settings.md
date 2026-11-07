---
paths:
  - "config/catalog.lua"
  - "next/settings/*.lua"
  - "spec/next/settings/*_spec.lua"
  - "spec/config/catalog_spec.lua"
  - "spec/integration/next_settings_spec.lua"
---
# BetterBags Next's Settings

BetterBags has one settings window, built from nothing for BetterBags Next (asked; the plan and its
status are in `docs/next-settings.md`): pages grouped down a sidebar, tabs across a page, two-column
rows, and every control BetterBags' own, styled by the Next theme. It is the classic bags' settings
window too, showing what the bags in use read (§7); the classic settings window was removed. It builds
its settings from one catalog.

Sections with their own rule files keep their numbers there: next-controls.md §2 and
next-settings-categories.md §5.

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

## 3. The window (`next/settings/`)

| Module | File | What it is |
|---|---|---|
| `NextSettingsPages` | `pages.lua` | The pages, in the order defined (`Define`, replacing one with the same id in its place): each in a `group` (the sidebar's headings, in the order their first page was defined), with a `title`, a `description`, an optional `bag` its settings are bound to, `shown()` (a page shown only sometimes: the guild bank), and `tabs` (a tab's `shown()` leaves it out while false; `ShownTabs`). A page may have its own list in the sidebar (`sidebar(parent, owner)`), a `heading()` read in place of its title and description, and buttons in the header (`actions(parent, owner)`): below, "A page's own list". A tab's `sections` (a list, or a function read when the tab is built) hold row definitions: `setting` (a catalog id, bound to the page's bag; one the bag does not have is left out), `option` (a page's own), `text`, `buttons`, or `block` (a function making a wide row, with a `title` and `keywords` for search). Pages are data. |
| `NextSettingsRows` | `rows.lua` | A setting's row: its name (wrapping) on the left and its control on the right (`toggle`, `dropdown`, `slider`, `color`), at least `RowHeight` tall. It reads the option into the control (`Refresh`), writes what the player changes, shows the option again when the change was refused (`set` returns false), after a change it took has the window show every row's value again (`onChanged`, set by the window on every setting and option row: a setting may follow another, as Tracker Grows follows Tracker Layout, currency.md §6; reported: it kept "Left" after the layout became Column), and asks in a `NextDialog` over the window to reload after a change that needs one (`reload`). Its description is its tooltip, which stays while the pointer is over its control (`IsMouseOver` on leaving). Rows across the page: `CreateText`, `CreateButtons`, `CreateLink`. Every row answers `Measure(width)`, `Place(x, y, width, height)`, `Refresh(ctx)`, and `wide`. |
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
  [...] with a back button on the top left"; the Categories page, next-settings-categories.md §5). Choosing a page with a `sidebar`
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
empty text), `spec/next/settings/window_spec.lua` (every value shown again after a change, not after a refused one; built on first open, centered, sized, body, moving,
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
| BetterBags | General (`general`) | *Bags:* BetterBags Next, Enable Bank Bags, Show Blizzard Bag Button, Clamp Bags to Screen (window.md §3a), Enable Bag Fading (classic), Animate Item Movement (classic). *Search:* In-Bag Search, Enter to Make Category. *Items:* Upgrade Icon Provider, New Item Duration, Category Sell and Deposit. *What's New:* Show What's New on Login. |
| | Appearance (`appearance`) | Three tabs (asked: "make 'Theme' here a tab, and add a tab for 'Size'", docs/next-appearance-size.md; then an Animation tab). **Theme**: the theme pickers (`next/settings/themes.lua`, below): BetterBags Next's themes (SonataNext) while Next is in use; for the classic bags, their Bag Theme (Sonata), then Settings Window (SonataNext: Next's themes draw this window). **Size** (Next only): Icon Scale (`nextIconScale`) and Bag Scale (`nextBagScale`), 50% to 150% in steps of 5, each sending `next/ScalesChanged` (next.md §3, next-small-mode.md §14h); then Autosize Bags (`nextAutosize`, a switch, on by default, sending `next/AutosizeChanged`: small bags are as tall as what they show, next-small-autosize.md §14i), then Fit Names While Open (`nextFitNamesWhileOpen`, a switch, off by default, sending `next/FitNamesChanged`: small bags follow what they show while open, next-small-names.md §14g). **Animation** (Next only): an Effects section of fifteen switches, Sparkles, Title Shimmer, Title Cloud, Title Ribbon, Braid, Moving Ornaments, Glitch Effects, Data Rain, Ice Shatter, Snow, Leaves and Stars, Smoke Puff, Bats, Transporter, Paper Folding and Stop Motion (`nextSparkles`, `nextShimmer`, `nextTitleCloud`, `nextTitleRibbon`, `nextBraid`, `nextOrnamentMotion`, `nextGlitch`, `nextRain`, `nextShatter`, `nextSnow`, `nextSmoke`, `nextBats`, `nextBeam`, `nextPaper`, `nextStopMotion`; Glitch Effects and Data Rain the Glitch theme's, next-themes-glitch.md §21, Ice Shatter and Snow, Leaves and Stars the Frost theme's, next-themes-frost.md §22, the Halloween theme's leaves and the Make It So theme's stars falling through the same snow, Smoke Puff and Bats the Halloween theme's, next-themes-halloween.md §23, Transporter the Make It So theme's, next-themes-makeitso.md §24, Paper Folding and Stop Motion the Papercraft theme's, next-themes-papercraft.md §25), each turning its effect off on any theme and sending `next/AnimationChanged` (next-themes-animation.md §20). The classic bags size themselves on each bag's page and have none of those effects, so with them Appearance has the Theme tab alone, and no tab strip. |
| | Item Colors (`itemcolors`) | The four item level colors as swatches, named with their ranges (61% and 86% of the highest item level seen, as the classic pane); a picked color is saved and sent as `itemLevel/MaxChanged` (Cancel saves the color back too); the highest level seen; Reset Colors, Reset Max Item Level. |
| | Currencies (`currencies`, Next only) | BetterBags Next's currencies (currency.md §6): *Tracked* (what is tracked, in order, dragged to move, each with Remove), *Currencies* (on clients with currencies: every currency with a switch that tracks it), *Items* (the shared items tab over the items tracked), *Display* (Backpack and Tracker; Tracker). |
| Bags | Backpack, Bank, Guild Bank (`backpack`, `bank`, `guild`) | Each bound to its bag. *Layout:* Order (Section, Item), Sections (Next only: Section Columns, Compact Sections (next-columns.md §7b), Fill Order, Wide Sections Span Columns, Wide Column Limit, next-columns.md §7a), Tabs (Enable Groups: the backpack only; the bank's Tabs section is left out), Slots (All Free Space, Gaps). *Items:* Item Level (two), Quality (Glow Intensity), Stacking (seven). *Categories:* Automatic (the seven filters). *Order:* the order of its categories (next-settings-categories.md §5). The guild bank's page shows on a client with one (`addon.hasGuildBank`). |
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

- **`design`** on a page, a tab, a section or a row (`"next"` or `"classic"`) shows it only while those
  bags are in use (`NextSettingsPages:DesignInUse()`: `BagSystem:ActiveDesign() == "next"`, else
  classic). The window filters pages (`IsShown`), tabs (`ShownTabs`, also used by the search, whose
  results name a tab only when its page shows more than one), sections and rows when it builds a tab
  (each tab is made once per design: the cache key is `design:tab`) and when it searches.
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
    (SonataNext), the Size tab (Icon Scale, Bag Scale, Autosize Bags, Fit Names While Open) and the Animation tab (next-themes-animation.md §20); the Currencies page
    (currency.md §6: the classic bags keep their Currency page). The classic themes' picker (item buttons) is not shown
    in Next (asked).
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
and a switch, which a click anywhere on the row flips too (asked, of BetterBags Next's list, which is this
block: a heading takes no click). The switch writes `SetCurrencyBackpack`; once the game has taken it (0.1 s, as the
classic pane waited) the page reads the list again and sends `currency/Updated`, which redraws the
backpack's icons. `C_CurrencyInfo` where the client has it, else the legacy globals (Mists Classic),
whose expand and show flags are numbers (`ExpandCurrencyList(i, 1)`, `SetCurrencyBackpack(i, 1|0)`,
Blizzard_TokenUI). No cap on how many are shown: the classic pane had none (Blizzard's token frame caps
its own display, `MAX_WATCHED_TOKENS`).

The list is read through the Currencies module's `ListSize`, `ListEntry` and `ExpandListHeading`
(currency.md §2). The same block, made with `track`, is BetterBags Next's Currencies tab: there each switch
tracks the currency in BetterBags' own list, by ID, and Blizzard's list is read with the headings the player
keeps collapsed opened and closed again (`Currencies:List`), never written (currency.md §6).

Coverage: `spec/next/settings/currency_spec.lua` (the list and its expansion, a row's icon, count and
switch, headings without one, writing and the message after the game took it, the legacy API, height
and the empty text), `spec/next/settings/content_spec.lua` (the page per client and design, search).
Mutation-tested (10 mutations, each caught).
