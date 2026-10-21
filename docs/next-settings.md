# BetterBags Next: Settings

A new settings window for BetterBags Next, built from nothing: modern, in Next's look, with every
control drawn by BetterBags and styled by the Next theme. The classic bags keep the settings window
they have, as they keep their bags. This document is the plan, and tracks the work;
`.claude/rules/next-settings.md` describes what is built.

## Why

Asked (2026-10-20):

> it's time to bring the settings pane into the fold on Next -- the settings pane has always been a
> disaster, and i hate it, so other than the actual settings, we're going to rebuild it entirely
> from the ground up to be modern and sleek, ignoring all previous design decisions. i want to draw
> inspiration from ellesmere UI's settings here, side tabs with top tabs? this is maybe a bit too
> messy, but in general same concept. don't rip the art of whatever, make sure it fits our next
> themes; this also means redoing all our controls (including scrollbars, which i've been meaning to
> tell you to do for bags) so that they are themable as well.
>
> keep old settings around just like we keep old bags around in Original, and get this cleaned up.

The reference is EllesmereUI's settings window (a screenshot): a sidebar of pages grouped under
headings, with a search box; a page header with a large title and a line of description; tabs
across the top of the page; sections with small capital titles; settings in two columns of rows,
the name on the left and the control on the right; a footer with the page's actions and Done.

## What there is today

- **The window** (`config/config.lua`, `Config`): a Sonata Panel window built by the Form module
  (`forms/form.lua`, `forms/layouts/stacked.lua`): a long scrolling list of sections, with an index
  of them down the left, every setting a title, a description and a Blizzard control
  (`UICheckButtonTemplate`, `WowStyle1DropdownTemplate` or `UIDropDownMenu` on Classic, a Blizzard
  slider and number box, `InputBoxTemplate`, `MinimalScrollBar`).
- **Panes** a link in the list opens in place of it: Theme and Next Theme (`config/themepane.lua`),
  Currency (`config/currencypane.lua` and its Classic and Era versions), Item Colors
  (`config/itemcolorpane.lua`), a bag's Categories (`config/categorypane.lua`), QuickFind (inline).
- **Plugins** (`config/plugin.lua`): other addons call `Config:AddPluginConfig(title, options)`
  with AceConfig options; each becomes a section of rows (toggle, execute, select, input, color;
  `range` and everything else are logged and dropped).
- **Dialogs**: `StaticPopup` for profiles, import, reload and renaming a category; the Question
  module for deleting one.
- **The bags' scroll bar** (`render/scrollbox.lua`): Blizzard's `MinimalScrollBar`, shown only
  while scrolling or under the pointer. Not themable.

Every setting's effect lives in the window code: a setter writes the database and sends the
message that makes the bags show it (`bags/Rederive`, `bags/Redraw`, `bags/FullRefreshAll`,
`search/SetInFrame`, ...; refresh-scheduler.md §9, §10).

## The design

### The window

One window, centered when it opens, moved by dragging its header, closed with Escape, the close
button or Done. It is drawn entirely from the Next theme (`Settings`, `Controls`), so every theme
restyles it, and switching themes restyles it at once. Default's sizes:

```
+------------------+---------------------------------------------------------------+
| [bag] BetterBags |  Backpack                                                 [x] |
| ---------------- |  How the backpack lays out, sorts and stacks its items.       |
| [ Search...    ] |                                                               |
|                  |  Layout     Items     Categories                              |
| BETTERBAGS       |  ‾‾‾‾‾‾                                                       |
|   General        |  ORDER                                                        |
|   Appearance     |  +-------------------------------+-----------------------------+
|   Item Colors    |  | Section Order  [Alphabet  v] | Item Order    [Quality  v]  |
| BAGS             |  +-------------------------------+-----------------------------+
| | Backpack       |  SLOTS                                                        |
|   Bank           |  +-------------------------------+-----------------------------+
|   Guild Bank     |  | Show All Free Space   (o==)  | Preserve Gaps       (o==)   |
| PROFILES         |  +-------------------------------+-----------------------------+
|   Profiles       |                                                            |  |
| INTEGRATIONS     |                                                            |  |
|   QuickFind      |                                                               |
|   <plugins>      |                                                               |
|                  +---------------------------------------------------------------+
| v0.7.x           |  What's New                                           [ Done ]|
+------------------+---------------------------------------------------------------+
```

- **Window:** 1000 x 660, in the panels' body color with the wash at its top and a fine edge. It
  scales down to fit a small screen (never past 90% of either side).
- **Sidebar** (232 wide, darker): the brand (the bag glyph and "BetterBags", a gold line fading
  out under it), the search box, the pages under their group headings (selected: a gold bar and a
  lighter fill; under the pointer: a faint fill), scrolling with its own bar when long; the version
  at the bottom.
- **Page header:** the page's title (large) and description (one line, muted); the close button at
  the window's top right.
- **Top tabs:** a page with more than one tab shows them across the top, the selected one
  underlined in gold. A page with one tab shows none.
- **Content:** scrolls with BetterBags' own scroll bar. Sections have a small capital title (and a
  note after it, as "(per bag)"). Their rows sit in a card, two columns with a divider; a row is the
  setting's name on the left and its control on the right; a long name wraps, and a pair of rows
  is as tall as the taller. Some rows span both columns: text, buttons, text areas, and a page's
  own blocks (the theme picker, the category manager, the profile list).
- **Descriptions** show in a tooltip over the row (as Blizzard's own settings do), so the rows stay
  compact; the setting's name heads the tooltip.
- **Footer:** "What's New" on the left (the changelog), Done on the right.
- **Search:** typing in the sidebar's box lists every matching setting as live rows (change them
  there), grouped under "Page > Tab", each group's heading a link to its page. It matches names,
  descriptions, section and page names and keywords, case-insensitively. Escape in the box or
  clearing it goes back to the page.
- The window remembers the page and tab shown for the session.

### Pages: where every setting goes

The new window shows only settings that change something in Next. Those of the classic windows
stay in the classic settings: Enable Bag Fading, Animate Item Movement, Show Full Section Names,
Resizable Window, Snap to Content, Items Per Row, Columns, Opacity, Scale (Next reads none of them:
checked with `grep` over `next/`; the canvas, sections and windows that read them are the classic
bags'), and Currency (Blizzard's backpack currency list, which Next's footer does not show).

**BetterBags**

1. **General** (one tab)
   - *Bags:* BetterBags Next (experimental), Enable Bank Bags, Show Blizzard Bag Button.
   - *Search:* Enable In-Bag Search, Enable Enter to Make Category.
   - *Items:* Upgrade Icon Provider, New Item Duration, Enable Category Sell and Deposit.
2. **Appearance**
   - *Theme:* the Next themes as cards (name, description, Active or Unavailable), a pick previewed
     at once on every Next panel and this window, saved with Apply Theme, and the saved theme put
     back when the page is left (as the classic theme pane does, sonata.md §2).
   - *Item Buttons:* the classic themes, the same way. Next draws its item buttons and its dialogs
     with them unless the Next theme styles them itself (`ItemButton`, next-themes.md).
3. **Item Colors** (one tab)
   - *Colors:* Low, Mid, High and Max item level colors (swatches, Blizzard's color picker), named
     with their ranges; the current breakpoints; Reset Colors, Reset Max Item Level.

**Bags** (Backpack, Bank, and Guild Bank where the client has one; each the same, per bag)

4. **Layout:** *Order:* Section Order, Item Order. *Tabs* (backpack): Enable Groups. *Slots:* Show
   All Free Space Slots, Preserve Empty Slots as Gaps.
5. **Items:** *Item Level:* Show Item Level, Show Item Level Color. *Quality:* Quality Glow
   Intensity. *Stacking:* All Items Recent, Flash Stacks, Merge Stacks, Merge Unstackable, Don't
   Merge Partial Stacks, Split Transmogged Items, Unmerge on Interactions.
6. **Categories:** *Automatic:* Equipment Location, Expansion, Equipment Set, Recent Items, Trade
   Skill, Type, Sub Type. *Your categories:* the category manager (below).

**Profiles**

7. **Profiles:** the active profile (switching asks, then reloads), the characters on each, New,
   Copy, Rename, Delete, Reset to Defaults. **Import / Export:** export the categories to a text
   area, import from one.

**Integrations**

8. **QuickFind:** what the integration does.
9. **Plugins:** one page per plugin that registered (`Config:AddPluginConfig`), made from its
   AceConfig options: toggle, select, range (a slider: newly supported), input, multi-line input,
   color, execute, description and header; a group's options become a section titled with its
   name.

### The category manager

Rebuilt, keeping everything the classic pane does (config/categorypane.lua, category-lifecycle.md):

- **The list:** Pinned first (their order, `customSectionSort`), then every other category
  alphabetically: the bag's sections (from its committed items, so Next's are listed too; the
  classic pane read the classic view's sections, which Next does not have) and every defined
  category. Each shows its priority. Drag a row to reorder or pin it; Shift-click pins it.
- **New Category** and **New Search Category** (new: the classic pane could not make one).
- **A search category:** its query (multi-line, its `group by` clause kept in step with Group By),
  Priority, Group By, Color (and Reset), Show Section, the items added to it (drop an item to add,
  right-click to remove), Save, Rename, Delete.
- **An item list category:** Color, Priority, Show Section, its items, Save, Rename, Delete.
- **A built-in or leftover category:** what it is, and Remove Category (the escape hatch,
  category-lifecycle.md §4).
- Rules kept: dynamic categories cannot be renamed, group-by sub-categories cannot be deleted, the
  default color (Warcraft gold) is saved as none.

### Controls

Every control is BetterBags' own, made of plain frames and textures, styled by the Next theme
(`Controls`), restyled on every theme, and usable anywhere in Next. None inherits a Blizzard
template.

| Control | What it is |
|---|---|
| Scroll bar | A thin track and thumb that drives a Blizzard scroll box: drag the thumb, click the track to page, the wheel over it; hidden when nothing scrolls; optionally seen only while scrolling or under the pointer. **The bags use it too** (every Next panel's scroll box), in place of Blizzard's `MinimalScrollBar`. |
| Toggle | A switch: a track and a knob that slides between off and on, the track colored when on. |
| Slider | A track filled up to a thumb, dragged or clicked, snapped to its step; a number box beside it to type a value. |
| Dropdown | A field showing the choice and a chevron; a click opens a menu of the choices (BetterBags' own, scrolling when long), the chosen one marked. |
| Button | Plain, primary (accent) and danger, each with hover, pressed and disabled looks. |
| Text field | One line, with help text while empty; numeric with a range when asked. |
| Text area | Several lines, scrolling with the scroll bar. |
| Color swatch | A square of the color; a click opens Blizzard's color picker. |
| Tabs | Across a page's top, the selected one underlined. |
| Navigation | The sidebar's grouped list. |
| Dialog | A card over the window with a scrim behind: a title, text, an optional text field and buttons; Enter confirms, Escape cancels. It replaces every `StaticPopup` of the classic settings. |

Escape closes the innermost thing open: a menu, then a dialog, then the window (each takes the
window's place in `UISpecialFrames` while open: `SetPropagateKeyboardInput` is protected,
`SimpleFrameAPIDocumentation`).

### The theme

Two new parts of every Next theme, complete in Default, with new palette colors and text roles
(next-themes.md):

- `Settings`: the window's size, fills, edges, the sidebar, brand, navigation, header, tabs,
  content (padding, row height, cards, dividers, row hover), footer, and their fonts.
- `Controls`: each control's sizes, fills (a palette color, a color, or a texture spec, so a theme
  can use art), edges, hover and pressed looks, glyphs and fonts. The bags' scroll bar reads
  `Controls.ScrollBar`.

Parchment, Ember and Quiet set what their look needs (ink on paper, embers, quiet grays). New
glyphs (a chevron, a check, a magnifier) are added to `tools/textures/next_icons.py`.

### Opening it

- `config/Open` (the settings buttons, the bag menu, `/bb`) opens the window of the design in use
  (`BagSystem:ActiveDesign()`): this one in Next, the classic one in the classic bags.
- Switching design from either window (BetterBags Next on or off) closes it and opens the other
  design's on the same page where it has one, so the player sees the setting they just changed.
- The window is built the first time it opens.

### The settings themselves

Every setting is defined once, in `config/catalog.lua` (`SettingsCatalog`): its name, description,
kind, values, how to read and write it and what to send so the bags show it. Both windows build
their rows from it, so the two can never disagree about what a setting does. The classic window is
rebuilt on it with the same sections, order and text, so it looks and behaves as it does now.

## What does not change

The database, every setting's effect, the classic settings window as players see it, the plugin
API (`Config:AddPluginConfig`), the bags, and the classic bags' scroll bar.

## Phases

1. **The catalog** (`config/catalog.lua`): every setting defined once; the classic window built on
   it, unchanged for players.
2. **Controls** (`next/controls/`): every control above, themed, with the Default theme's
   `Controls`; the bags' scroll bar replaced.
3. **The window** (`next/settings/`): sidebar, header, tabs, content, footer, search, dialogs,
   opening, Escape, design switching.
4. **Pages**: General, Appearance, Item Colors, Backpack, Bank, Guild Bank, Profiles, Import /
   Export, QuickFind, Plugins.
5. **The category manager.**
6. **Themes**: Parchment, Ember, Quiet; `SonataNext:Check` knows the new keys.
7. **In game**, with the render recorder, and tuning with the player.

Each phase is tested first (specs that fail before), documented in `.claude/rules/next-settings.md`,
and committed. Status is tracked below.

## Status

| Phase | State |
|---|---|
| 1. The catalog | done (`.claude/rules/next-settings.md` §1) |
| 2. Controls | not started |
| 3. The window | not started |
| 4. Pages | not started |
| 5. The category manager | not started |
| 6. Themes | not started |
| 7. In game | not started |
