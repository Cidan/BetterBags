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
