# Render

The render pipeline every BetterBags window lays itself out through, and the helpers it places and draws with. The full
design is in `.claude/rules/render-pipeline.md` (the pipeline, the scroll box, the layout engine, motion) and
`.claude/rules/texture-sharpening.md` (texels).

## Files

### render.lua (`Render`)

Runs the staged render plans of drawables. Every drawable declares a plan: `RENDER_PRE` works out what to hand its
children (the width they may use, a maximum height), `RENDER_DEP` renders a child with that result, and `RENDER_SELF`
sizes and places the drawable from its children's results. A chain started at a root renders the whole tree below it,
top-down for constraints and bottom-up for sizes. A drawable that changes outside a chain invalidates itself: the
invalidation walks the parent links the last chain recorded up to the root, and the root renders once on the next frame
however many of its nodes were invalidated. Nothing in a render may yield.

### drawable.lua (`Drawable`)

The base of everything the pipeline draws: an instance has a frame and a render plan, and looks its methods up through
its prototype, every prototype through the drawable defaults (`Extend`), so the profiler's wrappers on a prototype apply to
every instance. Frame helpers (`SetParent`, `SetPoint`, `Show`, `Hide`, sizes) forward to the frame.

### scrollbox.lua (`Scrollbox`)

A drawable that scrolls one child: a `WowScrollBox` with Blizzard's `MinimalScrollBar` or a caller's bar
(`CreateBar`, BetterBags Next's). The scroll box passes the child the width remaining beside the bar, sizes the scroll child to the
height the child used, and reports the viewport it occupies (the child's height capped at `MaxHeight`, or the fixed
height of a window the player sized). Options: `Symmetric` (the bar's room on both sides), `AutoHideBar`, `Snap` and
`SnapScroll` (whole screen pixels). Each window owns one for its lifetime.

On WoW: Forever's gamepad interface (`.claude/rules/gamepad.md` §3), `SetGamepad(true)` puts a native `ScrollFrame`
between the scroll child and the child, so Blizzard's gamepad cursor never scrolls the addon-built box, and
`ScrollIntoView(region)` scrolls the box to show the button the cursor moved to; `SetGamepad(false)` puts the child back.

### flow.lua (`Flow`)

The packing every grid lays out with, as a pure function: boxes are placed left to right in rows, a row wraps when the next box
would pass the row limit, and rows split into columns by height. It reads sizes and returns positions; it touches no
frame, so measuring a layout has no side effects.

### motion.lua (`Motion`)

Positions the frames of a layout, each anchored by its TOPLEFT to the frame it hangs from. In a pass of a root (one
render of a bag's canvas), a frame the previous pass also placed travels to its new place, easing slow, fast, slow; an
item button moves by the slot it shows, so a sort moves items, not buttons. Anything else is placed at once.

### texels.lua (`Texels`)

Draws the bags without the client's texture sharpening: `Unsharpen(root)` turns it off on every texture, line and mask
under a window, except under frames that draw themselves (`DrawsItself`, the item buttons), which unsharpen their own
textures as they draw.
