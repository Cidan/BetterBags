---
paths:
  - "next/categorypicker.lua"
  - "spec/next/categorypicker_spec.lua"
---
# The category picker: an item dropped on a bag's title (issue #1270)

**Asked** (issue #1270: "drag and drop the items to a spot on the backpack and bank to either make a new category or add
it to one that's already made. Instead of having to open the settings"): "for Next, i want to be able to drag an item to
the bag name (or in the case of Plain, the bag button -- this has to be themable, so we need a 'item drop' declaration)
to have a (pretty) popup appear that lets you put an item in an existing category, or into a new category. ... i don't
just want to open the config screen. this is for manual or new category creation, and it needs to be highly functional,
but also look good." Then: "go with your defaults. let's prototype and figure it out."

The defaults the player approved: the popup is the shared menu (`NextMenu`) with a field, opened where the item was
dropped, not a dialog over the bag (a `NextDialog` dims the bag, and fills a small panel); only the
backpack and the bank take the drop (on a vendor, Plain's bag button is the vendor's portrait, and a drop there reads as
selling); a row taking an item added to a category by hand back to where it belongs; the drop target lights only while
an item is held over it (no pulse when an item is picked up); a plugin's categories listed but not to be picked.

## 1. Where the drop goes: `Header.ItemDrop` (a theme's declaration)

`Header.ItemDrop = { Target, Highlight }`, or false (no drop target):
- `Target = "Title"` (Default, and every theme inheriting it): the title's button (`panelProto:BuildTitleButton`).
  `Highlight` (`Texture`, `Color`, `Alpha`, `X`, `Y`, `BlendMode`) is the panel's `itemDropGlow`, a texture of its own
  beside the title's glow: styled with it in `styleHeader`, placed with it in `placeTitleRow` (X past the title's text on
  each side and Y above and below it), faded by `lightItemDrop` while an item is held over the title. Default's is gold,
  0.6, larger than the title's hover glow.
- `Target = "Menu"` (Plain): the bag button (`next/menubutton.lua`, next-themes-menubutton.md §19), which lights its own
  `Highlight`.
- `SonataNext:Check` names a target that is neither, and `"Menu"` in a theme with no `Header.Buttons.Menu`.

`panelProto:ItemDropTarget()` reads the theme's target live, on a panel with `categorizes = true` (`next/bag.lua`,
`next/bank.lua`); nil on any other (the vendor, the guild bank) and for `ItemDrop = false`. Only the declared target
takes the item; the other keeps what it did before (the title's click chains the bags, next.md §12; the bag button opens
its menu).

## 2. Taking the item (`panelProto:PickCategory`, next/panel.lua)

An item dropped on the target (`OnReceiveDrag`), or a left click on it with an item held, calls
`PickCategory(ctx, anchor)`:
1. Only an item: `GetCursorInfo()` type `"item"` (a merchant's item, bought by drag, or anything else stays on the
   cursor; bag-drop-zone.md). The title's click and hover and the bag button's click and hover test the same
   (`GetCursorInfo() == "item"`, as the original bags' button does), so anything else held leaves them as they were.
2. What the bags hold of it (`cursorItemData`: its bag slot's data, else an item of its ID; none for an equipped item)
   and where it lands without its category by hand (`items:NaturalCategory`), read first, as a header drop reads them
   (`FileCursorItem`, docs/next-batch-2.md §8).
3. `ClearCursor()`: the item goes back to its slot while the player picks (typing with an item on the cursor, and
   clicking rows with one, would be drops).
4. `NextCategoryPicker:Open(ctx, anchor, { itemID, link, data, natural })`. The module is looked up when used, so the
   panel loads without it (the panels' specs stub it).

While an item is held over the target, the target lights and its tooltip is `NextCategoryPicker:Hint` ("Add to a
Category" / "Drop the item here to put it in a category, or in a new one.") in place of its own.

## 3. The picker (`NextCategoryPicker`, next/categorypicker.lua)

A `NextMenu` with a field (next-controls.md §2), below the anchor, closing with it (the menu closes when its anchor
hides: the bag closing), up to `Picker.MaxRows` (18) rows before it scrolls, more than a dropdown's 12 (asked, after
trying it: "make sure the window is reasonably long as well in general (when there are enough categories) -- generally
speaking, micro windows with tiny interactions for lots of elements is bad"):
- **Its head**: the item's icon (the bags' `itemInfo.itemIcon`, else `C_Item.GetItemInfoInstant`'s, the only read that
  needs no load) in its quality's edge from Uncommon up (`const.ITEM_QUALITY_COLOR`, as an item grid cell draws it), its
  link without its brackets (in its quality's color), and "In <section>" (`itemInfo.category`), none for an item the
  bags do not hold.
- **Its choices** (`Choices(text)`, the text trimmed):
  - Nothing typed: "Back to <natural>" (glyph `Picker.BackIcon`) when the item was added to a category by hand
    (`database:GetItemCategoryByItemID(id).name`) and would land elsewhere (not that category or one of its group by's
    sections); then every category in their order (`categories:GetOrder()`: not a group by's sections). Nothing lit:
    Enter closes.
  - Something typed: the categories whose name has it (case-insensitive), and first a 'New category "X"' (glyph
    `Picker.NewIcon`) unless a category listed has that name in any case or the name is taken
    (`categories:DoesCategoryExist`: a group by's section; the settings refuse a taken name the same way,
    next/settings/categories.lua `askName`). Lit: the first category that matches and can be picked, else the new one.
  - Each category: its color's dot (gold without one, as the settings list), checked when the item shows in it or in one
    of its group by's sections, its note how many items of the backpack and bank it holds (each item once, its group by's
    sections with it, only in bags that use it: the settings list's count, counted once as the picker opens). A category
    made from a Blizzard category never groups, so a longer name ("Toys - Pets") is not one of its sections, for the
    check, the count or the way back (`isShownIn`, category-lifecycle.md §11). A plugin's (`filter.save ~= true`)
    is disabled, its note "Made by a plugin": a plugin fills its own category (`FileItem` returns "plugin").
- **Picking** (`Pick`), then `bags/Rederive` (refresh-scheduler.md §10):
  - a category: `categories:FileItem(ctx, itemID, name, natural)`, exactly the header drop's filing (natural: the
    manual category forgotten; else added to Added Items, unignored);
  - new: `CreateCategory(ctx, { name, itemList = {}, save = true })`, then `FileItem` into it, so the item leaves the
    category it was added to by hand the same way;
  - back: `RemoveItemFromCategory(itemID, home)`.

## 4. Findings left as they are

- **Show Bags view**: there `itemInfo.category` is the bag's name (data/items.lua, `showBags`), so the head reads "In
  Backpack", no category is checked and no counts show; the settings list's counts read the same field.
- **Glow on other themes**: every theme but Plain inherits Default's gold glow (ADD, 0.6); on the paper themes it may
  barely show, and Quiet turns its own title glow off. A theme sets its own `Header.ItemDrop.Highlight`.
- **A new category of the item's own built-in category's name** ("Consumable" for a potion): it is made, empty and saved,
  and `FileItem` takes its natural path (the item lands there anyway); the same as making it in the settings.
- **A glide in flight** (speculative, from Blizzard's source, never seen): `SetScrollPercentage(p, true)` does not cancel
  an arrow key's glide still running (`Interpolator.lua`), so typing within 0.11 s of an arrow key could leave the lit
  row out of sight.
- **Click and drop both firing** on one release (never seen): the section headers and the original bags' button have the
  same pair of scripts.
- **Pushed over its anchor** (speculative): the menu opens below the title, clamped to the screen; at 18 rows (514 units
  with its head and field in Default) a picker opened from a small panel low on the screen is pushed up over the title
  more often than a 12-row one would be.

## 5. Coverage

`spec/next/categorypicker_spec.lua` (the head, the choices and their order, checks, counts, plugins, the new and back
rows and their glyphs, a taken name, filing, making, going back, an item the bags do not hold, the hint),
`spec/next/controls/dropdown_spec.lua` ("NextMenu, with a field to find a choice": head, field, re-reading, the light by
keys and pointer, disabled choices, notes clear of the bar, the lit row in sight after typing and a restyle, no scroll of
a menu whose rows all show on a 4K screen, jump versus glide, dots, notes, glyphs), `spec/next/controls/input_spec.lua`
(`onArrow`, `onEscape`), `spec/next/drag_spec.lua` ("the title": drop and click on the backpack and the bank, an item the
bags do not hold, a merchant's item, the glow and hint, the glow's place, a Menu theme, no drop; "the guild bank": none),
`spec/next/menubutton_spec.lua` ("an item dropped on it"), `spec/sonata/next_engine_spec.lua` (the declaration's check).

**Seen in game**: a picker of three categories, all shown, drew its scroll bar over their notes. Wherever rows are not a
whole number of units tall, Blizzard's box rounds its height (`ScrollBoxBaseMixin:GetVisibleExtent`), so rows that all
show read up to half a unit taller than it and the bar showed, where the menu had left no room for one (it leaves room
only when there are more rows than it shows). `NextScrollBar` now shows only for a range of more than that half unit
(next-controls.md §2), and `NextMenu:showRow` ignores the same range; with that the bar shows exactly when the menu left
room for it, so it never sits over text.

Three bug reviews: the first found notes under the scroll bar, the lit row out of sight after typing or a restyle, the
pointer taking the light away over a plugin's row, a taken section name offered as new, and the targets answering a
merchant's item; the second found a one-pixel scroll of a menu whose rows all show on a 4K screen and the list snapping
to its top then gliding back on each keystroke. Each was fixed test-first. The third, aimed at the scroll bar's half-unit
rule and `Picker.MaxRows`, found no bug a player can hit (a sweep of 10 screen heights, 5 UI scales and 1 to 22 rows: the
bar shows exactly when there are more rows than shown, its room always matches, a menu whose rows all show never
scrolls); it found tests that did not pin the rule, now tightened (each fails with its fix reverted).

**Not seen in game.** To check: drop a bag item and an equipped item on the backpack's title and the bank's, type, use
the arrow keys and Enter, make a new category, take an item back; the same on Plain's bag button; a merchant's item held
over either.
