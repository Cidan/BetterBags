---
paths:
  - "next/controls/*.lua"
  - "spec/next/controls/*_spec.lua"
---
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
| `NextToggle` | `toggle.lua` | A switch: the knob slides (`Motion.Time.Toggle`), the on color fades in with it. A click flips it and calls back; `SetChecked` calls nothing back, and told the state it is already sliding to it keeps sliding (asked: "animate our toggle switches"; a row showing its value again right after a click saved it stopped the slide, so no switch ever looked animated). A settings row slides a switch whose value changed while it shows (one setting turning another off). Two styles (`Controls.Toggle.Style`; asked: "switch between two styles, the current square toggle, or the 'round peg that sits over a smaller track'"): `"Square"` (Default), the track filling the switch with an edge round it and a square knob `KnobInset` in; `"Round"`, a track `TrackHeight` tall with round ends, centered, in from each end by half of what the knob is taller (the knob's middle over the middle of either end at rest), a round knob `KnobSize` across over it, a soft `KnobShadow` under the knob (or false) and, under the pointer, the `Hover` color in a halo `HoverSpread` round it; no edge. The knob, the ends and the halo are the `Circle` texture unless their spec names art; each end is half the circle, cut on a whole pixel (an odd pixel left to the middle), so the round switch is on whole pixels too (`spec/next/controls/pixel_spec.lua`). |
| `NextInput` | `input.lua` | A text field (an `EditBox`: its text `Padding` in, after an optional `icon` it draws and makes room for itself, help while empty and unfocused) and `CreateArea`, a text area (a multi-line edit box in a Blizzard scroll box with the scroll bar, the wheel taken only while focused, the cursor kept in sight; its box in `Controls.TextArea`'s `Fill`, `FocusFill`, `Edge` and `Frame`, each the input's when unset: the input's fill in pieces at its own thickness covered a strip of the box, not what takes its clicks). Only typed text is reported (`OnTextChanged`'s `userInput`); Enter reports and lets go of focus; Escape puts back the text it had when focused. |
| `NextSlider` | `slider.lua` | A track filled up to a thumb, pressed or dragged with the left button, and a number box (`NextInput`); every value snapped to the step and kept in range; a change calls back once per value; the wheel is left to the page. |
| `NextMenu` | `menu.lua` | One menu at a time, `FULLSCREEN_DIALOG`, below what opened it (`Gap`), a row per choice, the chosen one checked, scrolling past `MaxRows`; as wide as its widest choice needs, the list's `Padding` on both sides included (it was left out, and a menu opened from a 36-wide item cell read "Rem..."), at least its anchor. Closes on a pick, a click or the wheel outside it (a screen-sized catcher), Escape, a second open for the same frame, or that frame hiding. |
| `NextDropdown` | `dropdown.lua` | The choice made and a chevron; a click opens a `NextMenu`, its choices read each time (`itemsFunction`, form-dropdowns.md); the choice already made calls nothing back. |
| `NextSwatch` | `swatch.lua` | A square of its color. A click opens Blizzard's color picker (`ColorPickerFrame:SetupColorPickerAndShow`, loaded at login on every client); each color picked (`swatchFunc`, `opacityFunc`) calls back, and Cancel puts the color back and calls that back too, so what was saved follows (the classic item color pane left the saved color changed on Cancel). |
| `NextTopTabs` | `toptabs.lua` | A page's tabs, left to right `Gap` apart, the chosen one in its font and underlined by a marker that glides (`Motion.Time.TabMarker`), over a line under them all that may reach past them (`Line.Outset`) and stop under the chosen tab (`Line.Open`: a tab sitting on a pane, the gap gliding with it). Tabs too wide for their row give up half their padding, then half their gaps, then cut their names short, the longest first (asked: they "run off if too long"), fitted again when the row's width changes. The chosen tab calls nothing back. |
| `NextItemGrid` | `itemgrid.lua` | A scrolling grid of item icons (`Controls.ItemGrid`, in its own `Fill`, `Edge` and `Frame`, an input's fill and edge when it has none: Plain draws Blizzard's multi-line edit box's frame; drawing a fill in pieces on its plain texture painted it white, round three): as many columns as fit, only the cells of the rows in view made and placed (reused as it scrolls: thousands of items cost a screenful), each with the icon, a count above one, the quality on its edge (Uncommon and up; the plain edge for Common and Poor), faded (`DimAlpha`) for an item showing in another category; the item's tooltip (its link, else `SetItemByID`) with the entry's note and the grid's hint. With `onDrop`, an item dropped anywhere on it (a cell, the box, the frame) or clicked onto it goes there; a right click goes to `onRightClick`, a modified click to `HandleModifiedItemClick`. |
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

**The bar sits above its box's content.** `NextScrollBar` is a child of its box, in the box's right edge
over the content, so the content reaches under it (a list's rows, an item grid's buttons). The client gives
the mouse to, and draws on top, the highest frame under the pointer, and the content hangs deeper (the box's
scroll target, a list's content frame, the rows, what is in them) than the bar, one level above the box.
**Failure mode (fixed, reported):** in a long category list, pressing on the thumb grabbed the row under it
and dragged the row. `barProto:Raise` puts the bar one level above the deepest frame in its box, its own
frames left out (or it would climb each time): when it is bound and each time it shows, never as it scrolls
(a bag holds hundreds of buttons). Rows made while it shows sit as deep as the rows before them. A level
that high only matters within the box's strata, next to the box's own frames, unlike a fixed jump, which
could draw the bar over another window in that strata. Coverage: `spec/next/controls/scrollbar_spec.lua`
("above its box's content": above every frame, again when it shows over rows made while hidden, no climbing)
and `spec/next/settings/categories_spec.lua` ("keeps its scroll bar above its rows"); each part
mutation-checked.

**Mocks added from Blizzard's source** (`spec/helpers/wow_mocks.lua`): the scroll box's callback
registry, extents, percentages, scrolling allowed and `OnScroll` (`ScrollBox.lua`,
`ScrollController.lua`, `CallbackRegistry.lua`; `BaseScrollBoxEvents`,
`ScrollControllerMixin.Directions`), `ColorPickerFrame` (`ColorPickerFrameMixin`; `_Pick`, `_Cancel`
for specs), `SetMotionScriptsWhileDisabled`, `IsMouseWheelEnabled`, `IsAutoFocus`, `HighlightText`.

Coverage: `spec/next/controls/*_spec.lua` (each control's look, states, callbacks and restyle;
the Escape stack both ways round), `spec/render/scrollbox_spec.lua` ("with a bar of its own"),
`spec/next/bag_spec.lua` (a panel's bar). Mutation-tested (42 mutations; the three that first
survived led to two tests and to removing a redundant guard).
