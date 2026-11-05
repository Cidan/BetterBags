---
paths:
  - "sonata/themes/next/*.lua"
  - "spec/sonata/next_themes_spec.lua"
  - "spec/next/shipped_themes_spec.lua"
  - "tools/next_theme_check/**"
---
## 8. The shipped themes

- **Default**: the design as it was.
- **Ember**: a charcoal and amber palette, sparkles drifting slowly and rising like embers.
- **Parchment**: Moonlight's parchment art (the plain middle, away from its burnt edges) for the body
  and the dock's card; dark ink text in Blizzard's parchment text colors with no shadow (numbers over
  icons keep one); ink and sealing-wax lines, bars and glows drawn normally, not added as light; no
  sparkles, cloud, spark or wash; glyph icons in ink, colored icons in their own colors. Its paper
  color (feather, tabs) is the art's measured average (0.83, 0.78, 0.70).
- **Quiet**: cool grays, smaller icons nine to a row, a shorter header with its button icons at 0.8
  of their buttons (next-themes.md §11), no ribbon, cloud, spark,
  sparkles or braid, quicker opening without a bounce (the body reaches only 4 past the edge), a
  fainter small border. Its first version drew the border on full panels too; asked: a full panel
  docked at its edge should have none, so it no longer sets `Panel.Edge.Full`.

- **Guild Wars 2** (`GW2`, `sonata/themes/next/gw2.lua`, offered while GW2_UI is loaded, `Requires = { "GW2_UI" }`;
  the plan and what GW2_UI's source says: `docs/next-gw2-theme.md`): GW2_UI's look from its own files, calling
  nothing of it. Asked (round two): "we need to use those icons, that bag frame style, that icon" of the original
  BetterBags GW2 theme (`sonata/themes/gw2.lua`), "X button should still be top right", "tabs, i mean everything",
  and no feather while docked; (round three) the header and emblem as GW2_UI's character window, one highlight for
  every side button, the size button beside the X, one close button. So:
  - **The header as GW2_UI's character window** (`GwCharacterWindowTemplate`, `Character/windowBase.xml`; a first try
    followed `GwFrameHeader`, which the character window does not use, and its emblem sat inside the window): the
    window's top 62 below the body's top; the band's painted rows (45) above it, from over the side panel (40 out);
    the emblem (84) straddling the side panel, its bottom right corner 18 in and 22 below the window's top (so it
    starts at the body's top: a docked panel's top is the screen's); the title 31 in, its middle 18 above the window's
    top; the world map painting from the window's top (`Panel.Fill.Inset.Top`), so the band is drawn over what is behind the
    window; no border (`Panel.Edge = false`); the search bar 13 below the window's top; the footer band (its painted
    rows, 30 tall) with the free slots and money on it; `Panel.Feather = false`.
  - **The side panel outside the window** (`Rail.Outside`, next-themes-ornaments.md §13), 40 wide, its art from the window's top line
    (`Rail.Start`), the actions down it below the emblem in the original's micro icons (32, 5 apart): Show Bags
    (`bagmicrobutton`), Sort (`collectionsmicrobutton`), Settings (`questlogmicrobutton`); GW2_UI's own for the bank
    tabs and deposit (`bankicons.png`'s character and Warbank quarters, `Inventory/bank.xml`) and repair
    (`icons\repair.png`); BetterBags' glyphs in LightHeader where GW2_UI has none.
  - **Every side button highlighted alike** (an icon's `Highlight`, next-themes-ornaments.md §13; asked: as Show Blizzard Bags is): GW2_UI's
    `-down` art over the bag, its hover art over the close, an icon's own art again over one without `-down` art
    (added, for the half-opaque micro icons; drawn again, for the near-opaque ones), no tint. GW2_UI's `-down` art is
    its `-up` art at 2.2 times its opacity (measured, 1.6 for the main menu's).
  - **The close and size buttons side by side at the top outer corner** (`Pinned`, next-themes-ornaments.md §13), the close's middle 20 in and
    20 above the window's top, as the character window's: GW2_UI's close art (its hover art over it), the size button
    left of it (asked: out of the side panel) in BetterBags' own glyphs, an underscore and a box with a heavier top
    (`minimize.png`, `maximize.png`, `tools/textures/next_icons.py`; asked: GW2_UI's own, its only, 32 x 32, drew
    blurry). Top right
    on the backpack, as asked. A judgment call: Next mirrors the other panels, whose side panel, emblem and title
    start from the right, so there they are top left; at the top right they would sit on the title. The settings
    window's close is the same art (`Settings.Header.Close.HoverIcon`).
  - **Every control in GW2_UI's art** (next-themes-art.md §14): its side tabs (`tab-tex-right-left.png`, flipped, its solid columns 0 to
    48 of 64 and 64 of its 1,024 rows: its outer 40% fades to nothing and left names over the world, and squeezed
    whole it streaked; asked: "tough to read"), its bag search bar (no border), its bag section rows (`bag-sep.png`,
    `GwBagHeaderTemplate`) with `menu-hover.png` under the pointer; cream buttons (`button.png`, darker under the
    pointer and pressed, `button_disable.png` disabled, dark text, no edge), check boxes (`checkbox.png`,
    `checkboxchecked.png`, `checkbox-disabled.png`, the mark gray while disabled), sliders (`sliderbg.png`,
    `sliderhandle.png`), scroll bars (`scrollbg.png`, `scrollbarmiddle.png`), fields (`statusbar.png` at half, edged in
    black), dropdowns and menus (its backdrop, `arrowdown_down.png`, `button_hover.png`, the check mark), dialogs and
    dock cards on its backdrop; the settings window as GW2_UI's own (`settingspanelbg.png`, `236menubg.png`,
    `levelreward-sep.png`, `settingspanelsep.png`). Every art spec sets its `Alpha` (next-themes-art.md §14, inherited alphas).
  - Text in GW2_UI's own fonts (copies of the client fonts it rewrites, next-themes.md §4), its colors (LightHeader titles, its
    wine accent, its skin colors); its item buttons (cropped icons on its backdrop, its border in the quality's
    color, its highlight and pushed art, the count at the top right). No sparkles, shimmer, cloud, ribbon, wash or
    braid. Painted rows and columns were measured from the files. Every GW2_UI file it names is checked against
    GW2_UI's source (`install-deps.sh` clones it).
  - Laid out on a 1920 x 1080 screen at both sizes (one-off dumps through the specs' layout resolver): nothing
    overlaps, the header where `GwFrameHeader` puts it.

- **Plain** (`sonata/themes/next/plain.lua`; asked: "the Plain theme looks like the default UI for the version of WoW
  we're playing on"; the plan, what Blizzard draws and how it was checked: `docs/next-plain-theme.md`): Blizzard's own
  art, every name and number read from the files each client loads, at Default's scale and in Default's layout (asked,
  round three: "scale for Plain should be the same as our Default", and of the settings window, "keep it like we do in
  default, just, pass over with skin a bit"). The bags are the original BetterBags bag windows (asked, round two):
  `DefaultPanelTemplate`'s look on every client (`ButtonFrameTemplateNoPortrait`, the client's own art, drawn above the
  content; `UI-Background-Rock` 6, 21, 2 and 2 in and its `TopTileStreaks`; Classic's title band), the search box where
  the original put it with `SearchBoxTemplate`'s insides, the original menu button's `Bagslots2x` bag as the bag button
  holding the header's actions in the original bags' menu (next-themes-menubutton.md §19; the vendor's portrait in Bagslots2x's empty gold ring on
  the vendor's), only the close button in the header, the title centered between them. The settings window is Default's
  in the same frame and stone, its name in the title bar, its sidebar Blizzard's inset (`InsetFrameTemplate` over its
  marble, 4 in, 24 down, 4 above the bottom), its pages in the settings list's art (`Options_CategoryHeader_*`,
  `Options_List_*`), its page tabs (`MinimalTab`) on a line across their column open under the chosen tab, its section
  titles as written, its text areas and item boxes in Blizzard's multi-line edit box's frame (`InputScrollFrameTemplate`).
  Retail and WoW: Forever (`Clients.Retail`): the red close button, the retail menus (`MenuStyle1`, and `MenuStyle2` for
  the settings dropdowns), today's popup's retail border. Every Classic client (`Clients.Classic`): Classic's 32-square
  close, Classic's menus (its own `MenuStyle2`), the popup's Classic border. Every client: the panel button in three
  pieces with its highlight, the input border, the settings check box, slider, dropdown and scroll bar art at Default's
  sizes, today's popup, the client's fonts copied at Default's sizes (the title bar's and the two larger Blizzard fonts
  at their own). Its side tabs are the list rows: Blizzard has no sideways text tabs. No sparkles, feather, wash, ribbon,
  cloud, glow or braid. Round one drew the dialog in the old `Dialog` nine-slice and the retail bags as Blizzard's
  combined bags; round two the bag windows above and the settings window as Blizzard's (next-themes-plain.md §18); round three Default's
  scale and layout, the bag button (docs/next-plain-theme.md).

- **Glitch** (`sonata/themes/next/glitch.lua`; asked: "a 'glitch' theme, where the bag sort of 'glitches' into existance
  when opening, glitches out when closing. think flickers, glitched blinking textures that wobble suddenly and harshly,
  think green mesh ... push the limits of what's possible here", and to keep it off GitHub until it is shown): a
  terminal that will not hold still. Opening, a CRT warming up, then the panel flickering into view through tears,
  datamosh blocks and static, its sections shoved and its title split and corrupted; closing, the same backwards into a
  CRT turning off; a short burst now and then while it shows. At rest: phosphor green on near black, a faint grid, a
  wireframe floor breathing along the bottom, a CRT vignette, scanlines and a rolling bar over the items, HUD brackets
  at the corners that twitch now and then, the title's cyan and magenta ghosts, data raining down the feather and
  faintly behind the items, tabs as HUD boxes (the selected one lit with dark text), dashed section lines, square pixel
  sparks, item buttons as terminal cells. Text in VT323 and Share Tech Mono (`fonts/glitch`, SIL OFL, their licenses
  beside them), Latin locales only. Its palette redefines Default's names in greens, so what it leaves to Default
  follows. The engine it added: next-themes-glitch.md §21.

- **Frost** (`sonata/themes/next/frost.lua`; asked: "a cool blue and cold theme, icy in nature. ... the shades of blue
  and gold should be like the screenshot ... themes are ice, cool breeze, etc. ... go crazy on the show and hide
  animations, and the overall feel"): deep winter blue threaded with gold, its palette Default's names in the
  screenshot's blues and gold (Gold, Lavender as ice blue, Text, Muted), plus Ice, Frost and Silver. Its engine is next-themes-frost.md §22.
  - **Opening:** the bag appears out of a frost storm (asked, after seeing the shatter in game: "i love how the bags
    close, but for the opening of the bag, instead of just doing the close in reverse, can we do a sort of... frost storm
    that grows from the bottom left to the top right and the bag appears? almost like the bag appearing out of the frost
    storm"): the storm grows out of the body's bottom inner corner (bottom left on the backpack, mirrored to bottom right
    on the panels across the screen, as all of the theme is) across it, flakes curling and turning and mist rolling and
    growing in it, shards of its own body forming behind its front; once it has crossed, the seams flash, the frost on
    the shards thaws and the bag shows under them as the storm blows away, the seams never showing (asked, of the first
    storm, which flashed them: "these lines, don't need to show"); a gust of wind blows snow in, and its gold
    threads draw themselves in once every shard has formed. About 0.9 s, under the 1 s a bank waits for its panel to show
    (refresh-scheduler.md §11). (Its first opening was the close in reverse: the shards flying in from around the body;
    still the engine's open without a `Storm`.) **Closing:** frost spreads over it, cracks run along its
    seams out from where the pointer is (the close button clicked), and it shatters, the shards tumbling away under
    gravity, turning and catching the light, on a layer that carries them on after the bag has hidden.
  - **At rest:** the body's art (`body.png`: teal-blue depths, drifting frost), and now and then a gold shooting star
    flying a short way across it toward the inner side, its snowflake head twinkling (`Panel.Snow.Flybys`, next-themes-frost.md §22; at most
    two at once, every 4 to 9 seconds, 110 to 170 units at 55 to 85 a second, the body 458 across). The first version
    painted streaks of wind into the body; asked, "make those animated and not static", they became a tiled ornament
    blown across the whole body, and then, asked: "slightly too noisy ... the wrong color -- more golden, and A LOT less
    of them, more like... slower, shooting star, then don't even go the full length of the bag, more like... flyby
    twinkles", these stars. The rune circle it had behind the items was removed, asked: "get rid of that big rune". An
    aurora drifting across the top, a frosted rim, an interlace
    border down the inner side and along the top and bottom (and the outer side of a small panel), ice crystals growing
    out of the inner corners into the feather and glinting; snow behind the items and down the feather on a breeze that
    gusts now and then, streaks of wind sweeping across; three threads of gold light (round the header behind the title,
    along the footer out into the feather, down the feather), swaying, a glint running along each now and then;
    snowflakes for sparkles and for the spark that glides along the gold ribbon into the frosty mist round the title.
  - **Text:** Cinzel (fonts/frost, Regular and Bold, SIL Open Font License, upstream static files of
    github.com/NDISCOVER/Cinzel) for display text (titles, sections, tabs, dialog and settings titles), the client's
    font for the rest; Cinzel covers Latin alphabets only, so in other locales its roles draw the client's (`Locales`).
  - **Art:** `tools/textures/next_frost.py` (standard-library Python) makes `textures/next/frost/*.png`: the body, hoarfrost
    (dendrites grown in from the edges), an ice crystal cluster, an interlace band (along an edge and turned down a
    side), aurora curtains, a frost rim, a snowflake, a wind streak (a gust's, and a shooting star's tail), a thread of
    light. Checked by its numbers rather than by eye (the body averages 0.05, 0.19, 0.29; the frost covers 9% of its
    file).
  - Item buttons are frosted cells (cropped icons, a thin ice edge carrying the quality); the settings window is drawn
    on the body's art.
  - Not seen in game yet. Seen nowhere else either: no image of it was rendered.

- **Halloween** (`sonata/themes/next/halloween.lua`; asked: "think: black cats, pumpkins/jack-o-lanterns, bats, orange
  and black. the bags should appear in a puff of smoke from bottom to top (get that smoke right! make it feel really
  good). for the bag closing, make the bag 'turn into' several bats, like 10-15 bats, and fly away in random directions
  off screen. like old school cartoon vampires turning into bats and flying away ... main color should be orange with
  black accents (so orange backdrop), with whimsy and fun animations. slightly cartoony almost and flat shaded ... a
  nice good color of orange, like that of a pumpkin, not over the top bright"): pumpkin orange with black accents, its
  palette Default's names in candlelight (Gold), a witch's purple (Lavender) and dark ink (Text, Muted), plus Ink, Bone,
  Night, the smoke's purple-tinged greys and the leaves' autumn colours. Its engine is next-themes-halloween.md §23.
  - **Opening:** smoke rises up the bag from the bottom (NextSmoke). The first version was cartoon smoke (flat,
    cel-shaded puffs popping past their size, holding, shrinking away); asked: "can you make it more real-ish?". Now rows
    of soft, uneven puffs (`puff.png`, noise-shaped) are born from the rising front, each at its own strength (0.35 to
    0.65) and angle, swelling from 0.55 of its size to 1.8, rising faster and faster (buoyancy), curling across its drift,
    fading in quickly and thinning away over 0.75 to 1.25 s, the bottom row spreading along the floor; embers (soft gold
    and pumpkin glows) rise through it. The bag shows under it by 0.4 s (under the 1 s a bank waits for its panel to
    show) and the smoke lingers on its layer, clearing from the bottom up, about 1.6 s in all. A bat or two flutters out
    of its header as it opens. **Closing:** first a puff of smoke covered it and bats burst out of it; asked: "no puff of
    smokes: how the frost theme shatters, we want the bag break up *and morph* into bats and fly away. almost a surreal
    effect". Now it trembles where it stands (0.18 s), breaks into 11 to 15 pieces of its own body that drift apart from
    where it breaks (the pointer, else its middle), and each in turn, nearer the break first, shrinks, spreads wings and
    darkens into a bat (0.32 s) that flies away (four frames, 14 a second) faster and faster, wobbling and banking, until
    it is off the screen.
  - **At rest:** the body's art (`body.png`: one deep pumpkin orange from side to side, averaging 0.8, 0.4, 0.11, a
    touch lighter at the top and darker toward the bottom; the first version's five soft ribs were taken out, asked:
    "remove the dark streaks on the bag ... make the orange slightly deeper"), black goo dripping along its top (16 tall, clear of the title at 24 and the header buttons at
    27), a black edge; at the bottom of the feather a jack-o'-lantern, its candlelit face and a glow round it flickering
    (`Flicker`, next-themes-ornaments.md §12), a black cat sitting on it swishing its tail (`Sway`) and blinking now and then, sometimes twice
    (`Blink`, next-themes-ornaments.md §12); on a small bag, the cat and a little jack-o'-lantern sit on its top edge at the outer corner; a cobweb
    across the feather's top corner, a spider swinging from it; a pumpkin vine curling along the footer out to the
    jack-o'-lantern (a thread, next-themes-frost.md §22); autumn leaves tumbling down the feather and a few behind the items, on a breeze that
    gusts now and then (NextSnow, drawn flat); one to three bats fluttering out of the header every 9 to 18 seconds; a
    candlelit glow round the title, a bat gliding in along a black ribbon into it; little stars for sparkles, drawn flat.
  - **Text:** Creepster (fonts/halloween, Font Diner, SIL Open Font License, Google Fonts' upstream file) for display
    text (titles, sections, the empty text, dialog and settings titles), the client's font for the rest; dark ink on the
    orange, bone and pumpkin on the black (tabs, the search box, menus, a primary button), each with a shadow of its own.
    Its character map covers Latin-1 and more (checked with a stdlib reader of the font's `cmap`: none of the
    accented letters of the eight Latin locales missing), so in other locales its roles draw the client's (`Locales`).
  - **Art:** `tools/textures/next_halloween.py` (standard-library Python; a scanline rasterizer at 4 x 4 samples a pixel
    for flat, hard-edged, anti-aliased shapes) makes `textures/next/halloween/*.png`: the body (8 x 512, every column the
    same, stored uncompressed so the theme's spec reads its pixels), a soft puff of smoke (256 x 256, grey tones, tinted:
    a round falloff broken up by fractal value noise read through a noise-warped point, for curls and thin places), a star, the bat flapping (512 x 128, four square frames) and gliding, the cat with its eyes (on the
    same canvas, so they lie over it exactly) and its tail apart, the jack-o'-lantern with its lit face apart, a cobweb, a
    spider on its thread, a maple leaf, a vine, goo drips repeating across. Checked by ASCII previews of each picture's
    shape in the terminal rather than an image viewer, which hangs.
  - Item buttons are dark cells on the orange (cropped icons, an ink edge carrying the quality); the settings window, a
    dock's card, the currency tracker and dialogs are on the body's art in ink; menus are black with bone text.
  - Not seen in game yet; no image of it was rendered.

- **Make It So** (`sonata/themes/next/makeitso.lua`; asked, to honor Patrick Stewart: "star trek TNG themed, the bags
  obviously need the star trek beam down, and beam up animation for appearing and closing. star trek comm badge is a
  part of the theme as well ... LCARS is an option, but maybe also holodeck too -- up to you, go nuts ... most important
  part is beam down/beam up", with the glam of the Halloween, Glitch and Frost themes): a starship's computer. Its
  palette redefines Default's names in LCARS' colours (Gold its orange, Lavender its lilac, Text and Muted peach) and
  adds them (`LcarsOrange`, `LcarsPeach`, `LcarsLilac`, `LcarsBlue`, `LcarsSalmon`, `LcarsRed`, `Sky`) and the
  transporter's pale blue (`Transporter`). Its engine is next-themes-makeitso.md §24.
  - **Softer and more modern** (asked after the first look, with a screenshot: "softer colors, maybe a bit more
    translucent in the title of each section, more.. modern a bit. i'll let you decide what this means"): a pane of
    glass. LCARS' colours softened to pastels (apricot, peach, lavender, sky, soft blue, salmon; none more than 0.6
    saturated, where the original orange was 1); the body a translucent navy (the holodeck tile's base navy, its grid
    a faint amber, drawn at 0.9, `HolodeckGlass`); the side bar glass (`LilacGlass`, 0.16) with its blocks floating on it
    as rounded keys; a slimmer top bar (10) and bottom bar (8); no border (`Edge = false`: the inner corners are rounded,
    where straight lines would stop short); sections and tabs on glass with their names in peach; the chosen tab solid
    apricot, its name in black; item buttons navy cells with a soft lavender edge.
  - **Beaming down** (NextBeam): a column of pale blue light comes up over where the bag rests, its art flowing up and
    its strength shimmering; the transporter's shimmer (flecks of white, blue and a little peach, about 2.6 to every
    100 x 100 units of the body, some a little past its sides) twinkles in brief flashes and ripples up and down
    through it; the body glows as the bag materializes under them, solid by 0.72 s (under the 1 s a bank waits for its
    panel to show); the light goes out after, by 1.15 s. A moment later the comm badge chirps: a glint flashes across
    it (`Flash`, first 0.85 s after it shows, then every 7 to 13 s). **Beaming up:** where it stands, the column and the
    shimmer come up and the body glows as the bag fades out of the light, gone by 0.65 s; the light goes out after it.
  - **The LCARS frame** (ornaments, next-themes-ornaments.md §12, and the side rail, next-themes-ornaments.md §13): the side bar (52 wide, inside the body on its inner
    side) curves into the slim top bar (10 tall, apricot) at the top elbow (150 x 66, its outer corner rounded 30, the
    corner inside filled round); then a lavender segment, its light flickering as the computer works, the bar on to its
    rounded end short of the comm badge. At the bottom another elbow (peach, 150 x 40, its outer corner rounded 24, its
    top 6 left clear) into the bottom bar (salmon, 8 tall) and its rounded end. A small bag (as narrow as 216) keeps its
    elbows, its bottom bar and the badge: the top bar beyond its elbow would run into them. **Its corners** (asked:
    "corner at the top left and bottom left peak out around the LCARS, i think we need a way to shape the window
    itself"): a small bag's inner corners are rounded as the elbows round them (30 and 24) (`Panel.Corners`, next-themes-makeitso.md §24); its
    outer corners and a full bag's stay square. (The restyle first rounded the outer ones too, 12: the body's fill then
    needed a fourth mask, which the client refuses, next-themes-makeitso.md §24.) The header's buttons are the side bar's blocks: each its soft
    LCARS colour (settings peach, sort and filter lavender, Show Blizzard Bags and repair sky, the size button apricot,
    bank tabs and Sell Junk salmon, deposits blue, gold gold), a key rounded 8, 3 in from the bar's sides, its glyph cut
    in dark navy at its right end, the bar's glass round it, so the blocks stack 4 apart under the elbow
    (`Layout.HeaderButton` 36, each icon's `Scale` 52 / 36, `Rail.Top` 70, `Gap` 4, the glass from 66 where the elbow
    ends), a light over one under the pointer.
  - **The comm badge:** the close button, pinned at the top outer corner (12 in, 6 down), its own icon blank; the badge
    (the gold delta over its silver oval) an ornament drawn over the content, 44 across, centered on the button (36),
    so 4 past it on every side, inside the rounded corner (`Above`), a glint over it, and a soft light round it under
    the pointer (the button's `Highlight`). Tap your comm badge to beam up.
  - **At rest:** the holodeck's golden grid behind the items (the body's fill, a 64 x 64 tile repeating); in the
    feathered edge, stars at warp (NextSnow, next-themes-frost.md §22): streaks and specks drifting out into the world at three speeds,
    never falling, never turned, and every 30 s or so a jump to warp (a gust 600 strong, streaks of light sweeping
    across). Tabs are LCARS bars of glass, rounded where they stick out (lavender at 0.42, `TabGlass`, their names in
    peach; the chosen one solid apricot, its name in black). Section headers are bars of glass (the section bar art: a
    solid rounded tip, a gap, then glass a third as strong fading along the section to a twentieth), 20 tall in a header
    28 tall (`Sections.Header.Height`, `Layout.SectionHeader`), so 8 clear the first row of icons (reported: the title
    "is overlaping with the first icon row"), their names in peach after the tip, counts in lavender; the title in
    LCARS orange with a soft glow, an orange line out of the window and a fleck of the transporter's light gliding in
    along it; no cloud; sparkles are the transporter's flecks; item buttons navy cells, a soft lavender edge carrying an
    item's quality.
  - **Text:** Antonio (fonts/makeitso, Vernon Adams, SIL Open Font License; Google Fonts' upstream,
    googlefonts/antonioFont at `0856299`, its static Bold and SemiBold, checked against the upstream's file hashes), a
    free face in the spirit of LCARS' lettering, for display text (titles, sections, tabs, counts, the empty text,
    dialog and settings titles); the client's font for the rest. Its character map covers Latin-1 (checked with a stdlib
    reader of its `cmap`), none of Cyrillic, Korean or Chinese, so in other locales its roles draw the client's
    (`Locales`).
  - **Art:** `tools/textures/next_makeitso.py` (standard-library Python; shapes at 4 x 4 samples a pixel, lights as
    smooth fields; the frame's pieces drawn for the size the theme gives them in its units, so circles stay circles)
    makes `textures/next/makeitso/*.png`: the elbows, a bar's rounded end, a white square the bars and segments are
    tinted from, a blank, the tab, the section bar, a block for each header button (its glyph read from
    `textures/next/icons` with a stdlib PNG reader and resampled) and the light over one, the comm badge and the light
    round it, the glint, the transporter's column (soft across, streaked, banded so it tiles as it flows), the body's
    glow (softening over its outer fifth, where the beam's margin and ends are), a warp streak and the holodeck tile.
    Checked by ASCII previews, colour classes for the badge and a block. The masks the engine cuts with (a corner, a
    beam's end) are `tools/textures/next_masks.py`'s.
  - Seen in game once, before the restyle (a screenshot: the corners, the section titles and the look above came from
    it); the beam's reach and ends were reported from it too. The restyle is not seen in game yet.

- **Papercraft** (`sonata/themes/next/papercraft.lua`; asked, with a screenshot of a desktop made of torn paper notes: "the
  open animation should be the bags 'unfolding' in two parts (1/4th square, unfold into half, unfold into full), and the
  close animation should it being crumbled up like a paper ball and being tossed up slightly, then falling off the screen.
  the text should all look like it's hand drawn, and the paper should be a soft color. elements should look like they are
  'taped on' and held together ... it's okay to have little doodles too in the paper at the margins. here's the trick for
  this one: the animations? should be stop-motion esque. meaning they are not just staggered in that stop motion FPS, but
  imperfect in their placement from frame to frame."): a sheet of soft cream paper taped to the screen. Its palette
  redefines Default's names in pencil and ink (Gold a red pencil, Lavender a blue one, Text and Muted dark ink) and adds
  the tape's colours, so what it leaves to Default follows. Its engine is next-themes-papercraft.md §25.
  - **Opening:** a folded note with a backpack and "BetterBags" drawn on it drops into place, unfolds across one fold and
    then the other, and the bag's things appear on the sheet, section by section. **Closing:** it is grabbed and shaken for
    a moment, crumples up with its items printed on it, is tossed up a little, tumbling, and falls off the screen.
  - **Stop motion:** every animation of the theme runs at twelve poses a second, each landing a little off where it
    should be: items and sections moving, tabs sliding, a dragged row making room, a tween's value, the fold and the ball
    (their corners each their own way). The doodles' lines boil.
  - **At rest:** the paper's grain and fibres, the creases its folds left, a torn edge with a pale fibrous lip and a soft
    shadow on the world, washi tape holding it to the screen and over its small corners, a red pencil under the title,
    section names over a highlighter's streak with a pencil line on across the section, items mounted on squares of lighter
    paper pencilled round with their quality in coloured pencil, tabs as scraps of paper taped to the bag's side; in the
    margins a cat, a sprig, a sun, a mug, a paper plane, stars, a heart and a note to self (English clients).
  - **Text:** Caveat for display text and Patrick Hand for the rest (fonts/papercraft, SIL Open Font License, the licenses
    beside them): every role, the bags' money (`Footer.CoinFont`), item counts and levels, and cooldown numbers. Caveat has
    Latin and Cyrillic and Patrick Hand Latin, so other locales draw the client's font (`Locales`, and the countdown's own:
    its minutes and hours are words in some); counts and levels are numbers, which every locale has.
  - **Art:** `tools/textures/next_papercraft.py` (standard-library Python) makes `textures/next/papercraft/*.png`, handwritten
    notes read from Caveat itself. Paper and scraps are in their own colours; tape, ink and pencil are white, their tones in
    the alpha, so the theme tints each. Looked over from renders of the real Lua on a rasterizer outside the repository.
  - The settings window, menus, dialogs, dock cards and the currency tracker are sheets of the same paper; buttons and
    fields a pencilled outline in three pieces, check boxes drawn by hand.
  - Not seen in game yet.

Each draws the settings window and its controls in its own look (next-settings.md §6): Ember and Quiet
their control colors in their own charcoal and grays (Quiet also smaller settings titles and quicker
switches and tab markers); Parchment the window, its menus and dialogs on the paper art, ink text and
edges, sealing wax for the accents, Blizzard's parchment red for what deletes.

Not seen in game yet: any theme but Default.
