# BetterBags Next (experimental)

An experiment in a new backpack design: a full-height panel that slides in from the right edge of
the screen, the backpack's groups as tabs down its left side, the categories in one column of big
icons, and a title with a ribbon of light and sparkles drifting out of the window. It replaces
only how the backpack is drawn: the item data, the item buttons and the settings that feed the data
are the classic bag's. Off unless the player turns it on (**BetterBags Next (experimental)** in the
settings, or `/bb next`), which takes effect after a reload. The bank keeps the classic window.

The design, the rules it follows and its coverage are in `.claude/rules/next.md`.

## Module Structure

```
next/
├── style.lua     # NextStyle: sizes, palette, timings and fonts, in one place
├── tween.lua     # NextTween: one tween per key on a single OnUpdate (slide, fades, glides)
├── sparkles.lua  # NextSparkles: a pooled particle emitter of star sprites
├── tabs.lua      # NextTabs: the tab rail down the panel's left edge
├── content.lua   # NextContent: the canvas: sections in one column, laid out through Motion
└── bag.lua       # NextBag: the panel, standing in for the backpack (addon.Bags.Backpack)
```

Files load in that order in every TOC, after `frames\bag.lua` (they use the search box, the money
frame, the backpack behavior and the render pipeline) and before `core\init.lua`.

## How it takes over

`core/init.lua` makes `addon.Bags.Backpack` with `NextBag:Create(ctx)` instead of
`BagFrame:Create(ctx, BACKPACK)` when `database:GetNextEnabled()`. The classic backpack is then not
created at all, so the two never draw the same item buttons. Everything else in the addon talks to
whichever object is there; NextBag provides the members they use (`Show`, `Hide`, `Toggle`,
`IsShown`, `Draw`, `Search`, `ResetSearch`, `OnCooldown`, `Refresh`, `Sort`, `Wipe`, `GetName`,
`SetTitle`, `ToggleSearch`, `PlaceCursorItem`, `frame`, `kind`, `searchBox`, `loaded`,
`drawOnClose`, `behavior.SwitchToGroup`).

## Drawing

`NextBag:Draw` is the classic draw pass: claim the buttons drawn, then release the ones the last
pass drew and this one did not. `NextContent:Bind` builds the sections (Recent Items, the active
tab's categories in their order, Free Space) and draws the static per-slot item buttons, sized to
44 pixels; `NextContent:Render` lays them out in one column inside the panel's scroll box, through
Motion so what changed place glides there. A draw while the panel is hidden waits for it to open.

## Writing Next code

- A font string's font comes before its text (`SetFontObject` first, then `SetText`): the client
  raises `FontString:SetText(): Font not set` otherwise, and the spec mock does too.
- Anything that animates goes through NextTween (a key per thing animated) or Motion (frame
  placement); there is one OnUpdate for each, and neither runs while idle.
- Look and timings live in NextStyle; nothing else hard-codes a size or a color.
- Specs are in `spec/next/`.
