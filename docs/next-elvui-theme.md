# An ElvUI theme for BetterBags Next

## As asked (2026-11-15, issue #1326)

> Re-add the ElvUI theme to BetterBags in the same manner as the GW2 theme:
> - Direct loading of assets/textures without relying on external helper functions.
> - Implement following the same pattern as GW2 (`sonata/themes/gw2.lua` / `sonata/themes/next/gw2.lua`).

Triage found the classic bags' ElvUI theme (`sonata/themes/elvui.lua`) was never removed; BetterBags Next never had
one. Then:

> next only, i agree. as for elvui... shoot. we would lose elvui coloring if we just use assets, don't we? before you
> do this, any thoughts on how to keep this for bbn? and scope is everything, top to bottom

Proposed: a theme names a value inside ElvUI's tables as data, and the engine reads it when the theme applies, with
ElvUI's default as the fallback. Then:

> i think this works, pain in the ass for elvui, but i do think we should hook UpdateMedia. let's go ahead and try it.

## What ElvUI draws (read from its source, `.libraries/ElvUI`, tukui-org/ElvUI)

Paths below are under `ElvUI/Game/Shared/`.

- **Its art** is files under `Interface\AddOns\ElvUI\Game\Shared\Media\Textures\` (`Media/SharedMedia.lua:40-49`):
  `Close.tga`, `ArrowUp.tga` (turned for every other way), `Melli.tga` (a solid square), `Highlight.tga` (a gradient),
  `BagQuestIcon.tga`, `BagUpgradeIcon.tga`, `NormTex2.tga` ("ElvUI Norm", the default for both bar textures,
  `Defaults/Private.lua:9-10`), `White8x8.tga` ("ElvUI Blank").
- **Its colors** are the player's (`Defaults/Profile.lua:138-141`, defaults: border black, backdrop 0.1 gray, the
  "fade" backdrop 0.06 gray at 0.8, the value color 0.09, 0.52, 0.82). `E:UpdateMedia()` (`General/Core.lua:351-372`)
  writes them into `E.media.bordercolor`, `backdropcolor`, `backdropfadecolor` and `rgbvaluecolor` (the value color
  after the class color is applied), each holding `r`, `g`, `b`, `a` and `[1]` to `[4]` (`General/Core.lua:286-330`),
  with the textures and font the player picked (`media.normTex`, `media.glossTex`, `media.normFont`).
- **When they are there.** ElvUI's `OnInitialize` (`General/Initialize.lua:719-742`) copies the saved profile in
  (`E:PrepDB`, 685-717) and calls `E:UpdateMedia()`; BetterBags lists ElvUI as an optional dependency, so this runs
  before BetterBags' own `OnInitialize` starts BetterBags Next's theme. At `PLAYER_LOGIN` (`E:OnEnable` →
  `E:Initialize`, `General/Core.lua:2026-2055`) it loads the profile again, calls `UpdateMedia` again, and then crops
  icons: `E.TexCoords` is `{ 0, 1, 0, 1 }` until `E:UpdateTexCoords()` (`General/API.lua:1550`,
  `General/Toolkit.lua:69-81`: 0.04 times `cropIcon`, default 2, in from each side).
- **When they change.** ElvUI fires no event or callback. Its options write a setting and call `E:UpdateMedia()`
  (`ElvUI_Options/Game/Shared/General.lua:76-80`, colors, textures; `:121`, fonts), once per step while a color is
  dragged; a profile change runs `E:UpdateAll` → `E:UpdateStart` → `E:UpdateMedia()` (`General/Initialize.lua:671`,
  `General/Core.lua:1150-1157`).
- **Its frames** (`SetTemplate`, `General/Toolkit.lua:294-375`): a backdrop with a one-pixel edge in the border color
  (`E.twoPixelsPlease` is always false, `General/Initialize.lua:103`), its fill the backdrop color ("Default") or the
  fade color ("Transparent"), on the blank texture or the gloss texture. Outside pixel mode (on by default,
  `Defaults/Private.lua:24`) black lines inside and outside the edge.
- **Under the pointer** (`Modules/Skins/Skins.lua:321-342`): a button's edge turns the value color.
  `StyleButton` (`General/Toolkit.lua:532-562`): white at 0.3 added under the pointer, gold (0.9, 0.8, 0.1) at 0.3
  pressed.
- **Its controls** (`Modules/Skins/Skins.lua`): buttons on the gloss template (`HandleButton`, 910-961); close buttons
  `Close.tga` 12 across, the value color under the pointer (1784-1818); arrows `ArrowUp.tga` turned (836-841), a
  dropdown's 14 across at its right (1446-1476); check boxes a box with ElvUI's gold square (1, 0.82, 0, 0.8) inside
  (1597-1651); sliders a 12 tall box with a gold `Melli` thumb 10 across (1898-1931); scroll bar thumbs in the value
  color at 0.25, 0.75 under the pointer and held (1082-1163); tabs on the default template (1185-1223); edit boxes on
  it (1413-1444); list rows lit with `Highlight.tga` (210-232) or the value color at 0.5 (72-77). Menus
  (`Skins/Menu.lua:27-114`): the transparent template, the chosen row's mark a square of the bar texture in the value
  color.
- **Its bags** (`Modules/Bags/Bags.lua`): the frame on the transparent template (2452); 20-pixel square buttons on
  the default template with art inside (2512-2543); the search box on the default template, 19 tall (2546-2549); slots
  on the gloss template (2789), their edge in the quality's color above Common and the border color otherwise
  (630-660), ElvUI's quest and upgrade icons (2812-2828), counts in Homespun 10 `MONOCHROMEOUTLINE`
  (`Defaults/Profile.lua:487-489`), 34 across (454).
- **Its text** (`FontTemplate`, `General/Toolkit.lua:496-530`): `media.normFont` at the general font size (12) and
  style (`OUTLINE`, `Defaults/Profile.lua:76-78`); `NONE` is no flags; a `SHADOW` style is the rest plus a shadow one
  pixel down and right, black at 0.6 (1 for `SHADOW` alone, `General/Initialize.lua:460-463`).

## Design

One Next theme, **ElvUI** (`ElvUI`, `sonata/themes/next/elvui.lua`), `Requires = { "ElvUI" }`, data only.

- **Following the player's ElvUI** (engine, below): the theme's `Variables` name ElvUI's values: the four colors, the
  bar and gloss textures, the font and its style, and the icon crop. They are read every time the theme resolves, and
  the theme `Watch`es `E:UpdateMedia` and `E:UpdateTexCoords`: after either runs, the theme is read again on the next
  frame and drawn again if anything it reads changed. ElvUI's art is named by path.
- **Every window**: flat, on ElvUI's templates. The panels on the transparent template with the border-color edge;
  no feather, wash, ribbon, cloud, spark, sparkles or braid. Cards, fields, tabs, the search box and dialogs on the
  default template. The value color where ElvUI lights things: under the pointer, the chosen tab and page, the dock's
  glow, scroll thumbs, slider and switch accents in ElvUI's gold where ElvUI draws gold.
- **Header buttons**: ElvUI's bag buttons are squares on the default template, the value color on the edge under the
  pointer; BetterBags' glyphs in white inside (ElvUI's close art on the close button).
- **Item buttons** (Next's `ItemButton` style): the gloss template behind the icon, cropped by ElvUI's crop and inset
  by its border, the border-color edge, quality on the icon's border (Blizzard's frame, Common and Poor in the border
  color: a Next theme never draws quality on the button's edge, next-themes.md §6), ElvUI's hover and pushed fills,
  its quest and upgrade icons, its count font.
- **Text**: ElvUI's font and style in every role; sizes fixed per role (ElvUI's own bags size their text apart from
  the general size too); no text in a color read from ElvUI (a dragged color would make font objects on every step):
  gold where the value color would go.

## Engine work it needs (each documented in `.claude/rules/next-themes.md`, each test first)

1. **References** (`SonataResolve`, both engines): a variable `{ Global, Path, Fallback, Alpha?, Map? }` reads
   `_G[Global]` and then each key of `Path` (raw reads: nothing of the addon runs), maps it through `Map`, and takes it
   when it is the Fallback's kind (a color read as `{ r, g, b, a }`, a list of as many numbers, a string, a number, a
   boolean); otherwise the Fallback. Registration refuses a malformed one. `Check` names one whose addon is there but
   whose value is not.
2. **Watching** (`SonataNext`): `Watch = { { Global, Path, Method } }` hooks each method once (`hooksecurefunc`). A call
   schedules one read on the next frame (calls in between are one); the current theme, read again, is drawn again only
   if its variables changed: restyled with its font objects kept when no role's look changed (a color dragged in
   ElvUI's options would otherwise leave a set of font objects behind on every step), applied again otherwise.
3. **Header buttons on a backdrop** (`Header.Buttons.Backdrop`: `Fill`, `Edge`, `HoverEdge`; false in Default; an
   icon's own `Backdrop`, false for none, wins: ElvUI's close button is bare).
4. **A slider's track edge** (`Controls.Slider.Edge`; unset in Default).
5. **Outlines** (asked after the first build: "do it"): rings round an edge (`Outlines`, `{ Offset, Size, Color,
   Alpha }`) in `NextControls` for every edge it draws and the panel's and search box's own, and on Sonata's item
   button backdrop (`{ Offset, EdgeSize, Color }`); a value a reference's `Map` names is taken as it is, so ElvUI's
   pixel mode (a boolean) turns the rings (a list) on or off.
6. **Quest colors** (asked: "makes sense, do it"): `QuestActiveBorderColor` and `QuestStarterBorderColor` on Sonata's
   item button style, the theme reading the player's Quest Starter and quest item colors and watching
   `E.Bags:UpdateBagColors`.

## Done (branch `worktree-kind-gliding-firefly`)

All four engine pieces and the theme, each test first: references and `Watch` in
`.claude/rules/next-themes-references.md` (§2a, §2b), the backdrop and the slider's edge in `next-themes.md` §3, the theme
in `next-themes-elvui.md` §27. `install-deps.sh` clones ElvUI (shallow) so a spec checks every ElvUI file the theme names,
and that every value it reads is one ElvUI's source writes there.

## Review

The bug review found seven issues, all fixed test first; they are listed in `.claude/rules/next-themes-elvui.md` §27.

## Left out

- **Following ElvUI's font size**: a theme drawn again with other sizes makes new font objects, and font objects can
  never be freed; a size slider dragged would leave a set behind on every step.
- **ElvUI's per-bag text settings** (its count, item level and info fonts are LibSharedMedia names, which only a
  function can turn into files): the count is drawn in ElvUI's default, Homespun 10.

## Not possible from here

Seeing it: no game client here. The look is checked against ElvUI's source by specs; how it looks in game, and the
hook's timing on a real login, are for the player to judge.
