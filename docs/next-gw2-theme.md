# A Guild Wars 2 theme for BetterBags Next

## As asked (2026-10-24)

> guild wars 2 theme! we need to use the guild wars 2 assets when it's installed, just like we do in original
> betterbags themes -- please don't use their draw functions, look at how original sonata does it, and come up with
> guild wars 2 theme for all windows as needed. and yes, you can move the top icon buttons to be side buttons, and side
> buttons can be left on backpack, and right on other bags, etc.
>
> be creative :)
>
> make sure to jot down your plan in //docs first, then go nuts, don't wait for me

## What the classic theme does (`sonata/themes/gw2.lua`)

Data only, nothing of GW2_UI's called: GW2's art drawn from its own files
(`Interface\AddOns\GW2_UI\Textures\...`), offered while GW2_UI is loaded. The bag: GW2's window header
(`bag\bagheader.png` and `bagheader-right.png`), the bag emblem (`bag\bagicon.png`) on the corner, the world map
painting under it, the 40-pixel side panel (`bag\bagleftpanel.png`) holding BetterBags' actions as GW2 micro buttons,
the footer band (`bag\bagfooter.png`), GW2's close button (`uistuff\window-close-button-*.png`), titles in GW2's header
font. Other windows: GW2's tooltip backdrop. The search box: GW2's search bar.

## What GW2_UI draws (read from its source, `.libraries/GW2_UI`)

- **Its bag** (`Games/Shared/Inventory/bag.xml`): body `bag\bagbg.png`; the header pieces above the window; the footer
  band below it; the side panel down the window's left, outside it; the emblem centered on the top left corner; a
  painted brush edge in the bottom right corner (`bag\bottom-right.png`); a settings, a bags and a close button.
- **Its bank and guild bank** (`bank.xml`, `guildBank.lua`): the same, on `bag\bankbg.png`, the same emblem.
- **Its merchant** (`Immersive/Skins/merchant.lua`): `CreateFrameHeaderWithBody` with `character\macro-window-icon.png`.
- **Its item buttons** (`Inventory/inventory.lua`, `reskinItemButton`): the icon cropped 0.07 to 0.93 at 0.9 alpha;
  `bag\bagitembackdrop.png` behind it; `bag\bagitemborder.png` as the quality border, tinted the quality's color at 0.9;
  the same border added at 0.33 under the pointer; `uistuff\ui-quickslot-depress.png` pushed; the count at the top
  right.
- **Its colors** (`Core/color.lua`): `LightHeader` (1, 0.945, 0.82), `Accent` (150, 50, 50), and skin colors (list
  hover and selected rows: `character\menu-hover.png` at 0.8, the light header border, the quest gold, the placeholder
  gray, positive and negative).
- **Its fonts** (`Core/fonts.lua`): at `PLAYER_LOGIN` it rewrites the client's font objects with its own families
  (`fonts\menomonia.ttf` and `fonts\headlines.ttf`, other files for Korean, Chinese and Russian, or a shared-media
  font the player picked, or none in its Blizzard style): `GameFontHighlight` in its normal family,
  `SystemFont_Shadow_Large` in its header family, `NumberFontNormal` at 14.

Measured from the files (a standard-library PNG reader, no image library on this machine): the header's band is rows
19 to 63 of its 64; the footer's rows 0 to 33; the side panel near black at 0.58 alpha down rows 0 to 480 of 512; the
body painting reddish brown (0.19, 0.12, 0.10); the window painting (`character\windowbg.png`, GW2's character windows)
fills rows 0 to 753 of 1024.

## Design

One Next theme, **Guild Wars 2** (`GW2`, `sonata/themes/next/gw2.lua`), `Requires = { "GW2_UI" }`. Every Next window:

- **The panels** (backpack, bank, vendor, guild bank): GW2's bag painting as the body, feathered in its color; GW2's
  header band across the top; GW2's emblem at the top of the side rail (the bag's on the backpack, bank and guild bank,
  the merchant's on the vendor, as GW2_UI does); GW2's footer band along the bottom; GW2's brush edge in the bottom outer
  corner. No ribbon, cloud, spark, sparkles or braid: GW2_UI's look is painted, not starry.
- **The side rail**: the header's buttons go down a strip of GW2's side panel art along the panel's inner side: left on
  the backpack, right on the other panels, as asked. The title gets the whole header row. GW2's close button art on the
  close button; BetterBags' glyphs in LightHeader for the rest (GW2 has no sort, deposit, gold, filter, junk or repair
  icon, and mixing two icon sets is what the header icons were redrawn to stop).
- **Text**: GW2_UI's own fonts, by copying the client fonts GW2_UI rewrites, so every locale and the player's GW2 font
  settings are followed with no locale logic in the theme; titles in LightHeader, body text cream, muted text GW2's
  placeholder gray, accents GW2's wine red.
- **Item buttons** (Next's `ItemButton` style): GW2's skin above.
- **Tabs, search box, sections, footer, dock cards, vendor cards**: GW2's colors and art where the part takes art.
- **The settings window, its menus and dialogs**: GW2's character window painting, GW2's list rows (`menu-bg`,
  `menu-hover`) for the sidebar, its colors for every control, GW2's cream buttons (`uistuff\button.png`) for primary
  actions.

## Engine work it needs (each documented in `.claude/rules/next-themes.md`, each test first)

1. **A side rail for the header buttons** (`Header.Buttons.Rail`): `{ Width, Top, Gap, Fill }` or false (Default).
   Set, the body is `Width` wider, everything inside it keeps `Width` more room on its inner side (title, search box,
   scroll area, footer, the canvas's width, the small panel's minimum), and the buttons go down the strip from `Top`,
   `Gap` apart, centered across it, their tooltips away from the panel. The strip's art is mirrored on a left panel.
2. **Ornaments: `TexCoords` and `Panels`**. `TexCoords` crops a piece's art (not with `Tile`), mirrored with the panel;
   needed for the header's right piece and the footer band, whose art is part of their files. `Panels` lists the panels
   a piece shows on (`Backpack`, `Bank`, `Vendor`, `GuildBank`); needed for the two emblems.
3. **Font copies that follow the client**: a role copying a client font (`Object`) is copied when the theme applies,
   which is before GW2_UI rewrites the client's fonts at `PLAYER_LOGIN`. When the game has started
   (`PLAYER_ENTERING_WORLD`) and a copied font is no longer what it was copied from, the theme is applied again,
   unsaved, as a new pixel grid does. Default's `Stack` role (a copy of `NumberFontNormal`, which GW2_UI rewrites) is
   fixed by it too.
4. **Item button art** (Sonata's `ItemButton` element, both engines): a `Backdrop` with a `Texture`; a `QualityBorder`
   given as art (`{ Texture, Alpha, BlendMode }`), tinted the quality's color (`QualityColors` override it, for
   Common), quest borders in it too.
5. **GW2_UI loads first on every client**: it is an optional dependency of the retail and Forever TOCs only; added to
   the Mists, TBC and Vanilla TOCs (GW2_UI supports all five), so the theme is available when Next starts.

## Done (branch `next-gw2-theme`)

All five engine pieces and the theme, each test first, documented in `.claude/rules/next-themes.md` (§4, §8, §12,
§13), `sonata.md` §3a and `item-drawing.md` §5. Also found and fixed: the sparkles' ribbon start was captured when a
panel was built, so a theme that moves the title (its pad, inset or a rail) left them inside the body.

- The ornaments' panel names are looked up in `const.BAG_KIND` as a panel lays out, not at load, so they follow the
  constants as they are.
- The theme's art is checked file by file against GW2_UI's source; `install-deps.sh` now clones GW2_UI (shallow).
- The full suite, luacheck and 57 mutations (each caught) pass.

## Not possible from here

Seeing it: no game client here. Every look is checked by specs against the source and by the theme checks; how it
looks in game is for the player to judge. In particular, not measured: how GW2_UI's painted art reads stretched over
a full-height panel, the emblem's place over the header's start, and whether GW2_UI's fonts at Next's sizes need
other sizes.

## Round two (asked, 2026-10-24)

> also for the gw2 theme, get rid of the feather texture when the bags are docked to the side of the screen.
> undocked/small bags looks good.

> this is how betterbags original looks like (non-next), we need to use those icons, that bag frame style, that
> icon. don't try to squeeze themes to sonata's restrictions -- expand sonata and what's possible (except still make
> sure it's declarative please) to fit this style, for next. X button should still be top right, etc.

> and to be clear, when i say theme for gw2, i also mean tabs, i mean everything. be more comprehensive and match not
> just colors in sonata, but art of buttons, arg of toggles, all of it. go deeper here in expanding what sonata can do.

The screenshot of the original did not come through; the original is its source, `sonata/themes/gw2.lua`: the world
map painting for the body; GW2's header band at the top with the title in its header font on it; GW2's bag emblem
(84 pixels) centered on the top inner corner; GW2's side panel standing *outside* the window along its inner side,
holding the actions as GW2's micro icons (32 pixels, 5 apart); the footer band; GW2's close button at the top right.

GW2_UI's own controls (read from `Core/API/toolkit.lua`, `editBox.lua`, `Immersive/Skins/menu.lua`): buttons
`uistuff\button.png` with dark text, `button_hover.png` darkening them under the pointer, `button_disable.png`;
check boxes `checkbox.png`, `checkboxchecked.png`, `checkbox-disabled.png` (disabled in `SkinColors.Disabled`);
sliders `sliderbg.png` and `sliderhandle.png`; scroll bars `scrollbg.png` and `scrollbarmiddle.png`; dropdowns'
arrow `arrowdown_down.png`; menus `button_hover.png` under the pointer and `checkboxchecked.png` for the chosen row;
side tabs `uistuff\tab-tex-right-left.png` (a tall dark strip with a painted ragged edge, measured: 55 of its 64
columns painted).

### The engine (declarative, each test first, documented in `.claude/rules/next-themes.md`)

1. **A side rail outside the body** (`Rail.Outside`): the strip stands beside the body's inner edge, as GW2_UI's side
   panel stands beside its windows; the body keeps its width; the tab rail hangs past the strip; a chained pair is
   spaced for both strips.
2. **Pinned header buttons** (`Header.Buttons.Pinned`): a button placed at a corner of the body by WoW offsets,
   apart from the rail or the header row (the close button at the top right on every panel, as asked).
3. **Header button art**: an icon may name its art under the pointer (`Hover`: GW2's `-down` and close hover art).
4. **Tabs in art**: `Tabs.Fill` and `SelectedFill` may be art (drawn for the backpack's tabs, sticking out to the
   left, mirrored on the other panels), the selected bar too.
5. **The search box in art**: `Search.Fill` and `FocusFill` may be art.
6. **Sections in art**: a row of art behind a section's title (`Sections.Header`), and art for its line and highlight.
7. **Lines in art**: the footer's line, the settings window's brand line, the top tabs' marker.
8. **Check box toggles** (`Controls.Toggle.Style = "Check"`): a box drawn off, on and disabled from art.
9. **Buttons disabled in art** (`DisabledFill`), and vendor cards in art (`Vendor.CardFill`, `CardHover`).

### The theme

The original's frame: the world map painting, the header band with the title on it, the emblem at the top inner
corner (centered on it while small, inside the top while docked), the side panel outside the window with the actions
in GW2's micro icons (and BetterBags' glyphs in GW2's icon color where GW2 has none), the close button at the top
right, the footer band, no feather while docked. Everything else in GW2_UI's art: tabs, the search box, section rows,
buttons, check boxes, sliders, scroll bars, dropdowns, menus, dialogs, the settings window.

### Done (round two, branch `next-gw2-theme-2`)

Every engine piece above, each test first, documented in `.claude/rules/next-themes.md` (§3, §8, §13, §14), and the
theme as the original's frame with every control in GW2_UI's art. Also:

- **The close button**: pinned at the top outer corner (a pinned button can name a corner by its side, mirrored as
  ornaments are). Top right on the backpack, as asked; top left on the bank, vendor and guild bank, which Next
  mirrors so their side panel, emblem and title start from the right, where a close at the top right would sit on
  the title. A judgment call, easy to change.
- **The world map painting** is an abstract wash (amber top left, near black, teal right), so it is stretched whole
  over the body as the original stretched it.
- **Laid out and checked** on a 1920 x 1080 screen at both sizes through the specs' layout resolver: nothing
  overlaps, once the side buttons start below the emblem's whole square (88).
- **The frame mock** now has `SetVertexColor` replace a gradient, as the client does.
- The full suite, luacheck and 56 mutations (each caught) pass. Not seen in game.

## Round three (asked, 2026-10-24)

From screenshots in game: (1) the side tabs' art made their names hard to read; (2) the header should be see-through
like GW2_UI's character window; (3) the side buttons highlighted unevenly ("the show blizzard bags highlight one
would be ideal"); (4) the settings window's Done button looked under the art; (5) its Delete button was hard to read;
(6) one close button, the bags'; (7) the emblem placed as the character window places it; (8) the bank broke opening;
(9) the size button beside the X, out of the side panel; (10) text cut with "..." after leaving Show Bags.

- **(8) The bank**: a panel made under a theme without a wash never painted one, so `SetWash` faded from nothing.
  Reproduced by a spec (the reported error, same line), fixed (next-themes.md §14).
- **(4, 5) Done and Delete**: Sonata merges a theme's specs with Default's key by key, so the cream button art took
  Default's faint fills' alpha: Primary 0.14 (Done), Danger 0.1 (Delete). Confirmed by resolving the theme; every art
  spec now sets its alpha, and a spec checks every shipped theme on every client.
- **(6) One close button**: the settings close takes art of its own under the pointer (`HoverIcon`), GW2_UI's.
- **(3) Highlights**: GW2_UI's `-down` art is its `-up` art at 2.2 times its opacity (measured); GW2_UI highlights
  buttons by drawing art over the icon (its bag window's `-down` art, its micro menu's icon over itself). Icons now
  take a `Highlight` drawn over them, the same on every side button.
- **(2, 7) The header**: as `GwFrameHeader` and `CreateFrameHeaderWithBody`: the painting starts below the band
  (`Panel.Fill.Top`), so the band is drawn over the world; the emblem's middle on the window's top line, 21 in; the
  title 64 in; the side panel from the top line (`Rail.Start`); no border.
- **(9) The size button**: pinned left of the X; the title keeps clear of the farthest pin, not of both added up.
- **(1) Tabs**: the art is one dark color whose outer 40% fades to nothing, under a name, and whose 1,024 rows were
  squeezed into a 30-pixel tab (its ragged edge streaked). Now its solid columns (0 to 48 of 64) and 64 of its rows.
- **(10) Truncated text**: not reproduced. Only the panel's title has a set width (a small panel's), the round trip
  through Show Bags changes neither it nor what it depends on, and nothing in Next shortens text. Needs a screenshot
  of the text that was cut.
- 18 mutations, each caught; the full suite and luacheck pass; laid out on a 1920 x 1080 screen at both sizes with no
  overlaps. Not seen in game.

## Round four (asked, 2026-10-24)

- **Tab names cut short** ("Backpack" as "Backpa..."): the client keeps the width a font string took when its text
  was set through a later font change; the selected tab's font (its shadow) is slightly wider. Fixed by resetting the
  name's width and setting it to its text's after every name and font change (next-themes.md §14). This was also
  round three's unreproduced "text cut with ...".
- **The emblem over the side panel, as the character window's**: round three followed `GwFrameHeader`, but the
  character window is `GwCharacterWindowTemplate` (`Character/windowBase.xml`): its band above the window from 40 out,
  its icon's bottom right corner 18 in and 22 below the top, its title 31 in, its close 10 in and 10 to 30 above the
  top. The theme now follows it; laid out at both sizes with no overlaps.
- **The size button's art**: GW2_UI's minimize and maximize art (32 x 32, its only) drew blurry; BetterBags' own
  glyphs instead, an underscore and a box with a heavier top, drawn by `tools/textures/next_icons.py`.
