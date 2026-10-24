# BetterBags Next, pixel perfect

## As asked (2026-10-23)

> should we just take the time right now to make BBN windows pixel perfect?

> i would just start the work on pixel perfect -- we're going to do it anyway. let's do it on this same
> branch (pull back the incorrect border fix)
>
> it's a big lift, so please do it correctly and write tests. this one can get messy fast, and, be sure
> to cover pixel perfection in *everything*, windows, borders, icons, themes, everything. EVERYTHING,
> all placement, everything everywhere.

## Why

Reported: the selected theme card on Appearance's Theme tab lost its top border at the game's UI scale
of 65% and its bottom border at 70%, in a maximized window; none in true fullscreen. The game's log
(`Logs/gx.log`) shows the maximized window renders at 3396x1362 and fullscreen at 3440x1440: at 65% a
UI unit is 1.153 screen pixels in the window and 1.219 in fullscreen. BetterBags Next placed everything
in whole UI units, so its frames and lines landed between screen pixels, and the client snapped each
texture to the pixel grid on its own: a 1-unit line drew 1 or 2 pixels thick, or not at all, depending
on where it landed. (A first fix assumed a screen 1080 pixels high and was reverted.)

## What pixel perfect means here

At rest, every frame and texture of a BetterBags Next window has its four edges on whole screen
pixels, and every text its anchor point on one, at any screen size, UI scale, Bag Scale and theme:

- **One screen pixel** in a region's units is `PixelUtil.GetPixelToUIUnitFactor()` (768 over the
  screen's height in pixels, `GetPhysicalScreenSize`) over the region's effective scale. GW2_UI does
  the same (`GW.mult`).
- **Lengths** (sizes, gaps, pads, insets, line thicknesses, icon sizes, every theme `Layout` value) are
  rounded to whole pixels where they are used, with the grid of the frame they are used in (a small
  panel at its Bag Scale has its own), never below one pixel when not zero. Sums of whole pixels stay
  whole, so a row of icons steps evenly.
- **Offsets** are whole pixels from a pixel-aligned point: a corner or edge of a frame that is itself
  aligned. A point in the middle of a frame (`CENTER`, `TOP`, `LEFT`, ...) is aligned only when the
  frame is an even number of pixels across; centering is done with a computed corner offset instead.
- **Windows** start from UIParent's corners (always whole pixels), at whole-pixel offsets.
- **Text:** a font string's anchor point is on a whole pixel; the glyphs are the client's.
- **Fonts:** every Next font role's height is rounded to whole pixels for the grid the windows are drawn
  at (made once per theme application and pixel grid, as font objects are).
- **Scrolling:** a scroll box at rest is scrolled by whole pixels.
- **When the grid changes** (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`: the UI scale, the window's
  size), the current Next theme is applied again, unsaved: new font objects for the new grid, and every
  window laid out again.
- **Not snapped, by nature:** what is moving (a glide, a slide, a drag, a flight, sparkles, the cloud's
  breathing, the braid): it lands on whole pixels when it comes to rest.

## Tests

- An opt-in layout resolver for the spec mock (`spec/helpers/layout.lua`): each region's rect from its
  anchors, sizes and the scales of its parents, as the client works it out (offsets in the anchored
  region's units). Tested on its own.
- One check (`PixelCheck`): every shown region under a window, at rest, on whole screen pixels; run for
  every Next window (the backpack and bank at both sizes, the vendor, the guild bank, the settings
  window on every page and tab, dialogs, menus, the dock) on several real screens and UI scales: the
  reporter's 3396x1362 at 65% and 70%, 3440x1440 at 65%, 1920x1080 at 64% and 100%, 2560x1440 at 100%
  and 115%, and Bag Scales.

**Status:** started.
