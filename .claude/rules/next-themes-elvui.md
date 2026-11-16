---
paths:
  - "sonata/themes/next/elvui.lua"
  - "docs/next-elvui-theme.md"
---
## 27. The ElvUI theme (`ElvUI`, `sonata/themes/next/elvui.lua`)

Asked (issue #1326, 2026-11-15): "Re-add the ElvUI theme to BetterBags in the same manner as the GW2 theme: Direct
loading of assets/textures without relying on external helper functions", for BetterBags Next ("next only"),
"everything, top to bottom", keeping the player's ElvUI colors ("i do think we should hook UpdateMedia"). The classic
bags' ElvUI theme (`sonata/themes/elvui.lua`) was never removed and is unchanged; BetterBags Next had none. The plan and
what ElvUI's source says, file by file: `docs/next-elvui-theme.md`.

**What it is.** Data only, offered while ElvUI is loaded (`Requires = { "ElvUI" }`; ElvUI is an optional dependency of
every TOC, so it loads first). Nothing of ElvUI's is called:

- **ElvUI's art by path**, `Interface\AddOns\ElvUI\Game\Shared\Media\Textures\` (`Close.tga`, `ArrowUp.tga`,
  `Melli.tga`, `Highlight.tga`, `BagQuestIcon.tga`, `BagUpgradeIcon.tga`, `NormTex2.tga`) and its count font
  (`Media\Fonts\Homespun.ttf`). Every ElvUI file it names is checked against ElvUI's source (`install-deps.sh` clones
  tukui-org/ElvUI into `.libraries/ElvUI`).
- **The player's ElvUI** through references (next-themes-references.md §2a) under `ElvUI[1]` (E): `media.bordercolor`,
  `backdropcolor`, `backdropfadecolor`, `rgbvaluecolor` (the value color after the class color), `normTex`,
  `glossTex`, `normFont`, `db.general.fontStyle` (as flags, `NONE` none and a `SHADOW` style the rest, and as a shadow,
  ElvUI's `FontTemplate`), `db.general.fontSize` (below), the bags' text settings (`db.bags.countFont`, `countFontSize`,
  `countFontOutline`, `itemLevelFont`, `itemLevelFontSize`, `itemLevelFontOutline`; a font by its name in
  LibSharedMedia's table, `Libs.LSM.MediaTable.font["$CountName"]`, a path key naming a variable,
  next-themes-references.md §2a), and `TexCoords` (the icon crop). Each falls back to ElvUI's default (`Defaults/Profile.lua`,
  `Defaults/Private.lua`); the font to the client's own. A spec checks each path is one ElvUI's source writes
  (`E.media.<key> = ` in `General/Core.lua`, `E.TexCoords`, the profile's `fontStyle`).
- **Watched** (next-themes-references.md §2b): `E:UpdateMedia` (its options call it after every change, its font size and
  style too; a profile change too), `E:UpdateTexCoords` (ElvUI's start crops icons after its last `UpdateMedia`, so
  `E.TexCoords` is `{ 0, 1, 0, 1 }` when BetterBags Next first applies the theme), and on its bags module (`E.Bags`)
  `UpdateBagColors` (its quest colors) and `UpdateItemDisplay` (its count, item level and item info options).

**The look**, from ElvUI's skins (`Modules/Skins/Skins.lua`), templates (`General/Toolkit.lua`) and bags
(`Modules/Bags/Bags.lua`):

- The palette: `Border`, `Accent` (the value color), `Body` (the transparent template's fade color: panels, menus,
  dialogs, the settings window, the tracker), `Card` and the control fills (the default template's backdrop color:
  cards, fields, tabs, buttons, the search box, header buttons); text white, ElvUI's gold (1, 0.82, 0) where Blizzard's
  templates draw gold and ElvUI keeps it (buttons, tabs, the settings list, links, headings), gray (0.6) for what is
  off. **No text is drawn in a color read from ElvUI**, the value color included: its options call `E:UpdateMedia` on
  every step of a dragged color, and text drawn in it would need new font objects on every step
  (next-themes-references.md §2b).
- Flat: no feather, wash, ribbon, cloud, spark, title glow, sparkles, braid or dock halo; every panel's one-pixel edge
  in the border color, full panels too; no bounce opening.
- Header buttons on a backdrop (`Header.Buttons.Backdrop`, next-themes.md §3): ElvUI's 20-pixel bag buttons, the
  edge in the value color under the pointer; BetterBags' glyphs in white inside, the value color under the pointer.
  The close button bare (`Backdrop = false`), ElvUI's close art, as `HandleCloseButton` draws it.
- Tabs on the default template, the chosen one's edge in the value color, no fade or bar; the search box on it, its
  edge unchanging; sections' lines in the value color.
- Controls: buttons on the gloss template (`HandleButton`), the edge lit under the pointer, gold text white under the
  pointer and gray while off (not dimmed: `DisabledFill`); check boxes a 16-pixel box with ElvUI's gold `Melli` square
  inside its border (`Toggle` in the square style, its knob the mark: `Knob = false`, `KnobOn` the gold square, the
  knob as wide as the box inside its border so it never travels); sliders a 12-tall box (`Slider.Edge`, no fill) with a
  gold square thumb over its border; scroll thumbs in the value color at 0.25, 0.75 under the pointer and held; dropdowns with ElvUI's
  arrow turned down (`TexCoords = { 0, 1, 1, 0 }`); menus on the transparent template, the chosen row's mark the bar
  texture in the value color; list rows lit with `Highlight.tga` (white at 0.3, the value color at 0.5 when chosen).
- Item buttons (Next's `ItemButton` style): the gloss template behind the icon, inset by the border and cropped by
  ElvUI's crop; the border color's edge; quality on the icon's border in Blizzard's frame (`Interface\Common\WhiteIconFrame`,
  as every Next theme draws quality there, next-themes.md §6), Poor and Common in the border color as ElvUI draws them;
  `StyleButton`'s white and gold fills under the pointer and pressed; quest items edged in the player's Quest Starter
  color while the quest is not active and their quest item color once it is (`QuestBorderColor`,
  `QuestActiveBorderColor`: `E.db.bags.colors.items`, watched through `E.Bags:UpdateBagColors`; on Era, where ElvUI's
  tooltip scan marks every quest item active but a starter, the quest item color for every one but a starter,
  `Clients.Era`, `QuestStarterBorderColor`; Era's quest data is not seen in game),
  its "!" (`QuestStarterIcon`) only on an item that starts a quest not yet taken and nothing over other quest items
  (`QuestIcon`: ElvUI's `Invisible.tga`), on every client, as `Modules/Bags/Bags.lua:793` shows it (on Era, `E.Classic`,
  its tooltip scan marks quest items active, :663-683; Blizzard's Era bags show no quest mark at all); its upgrade icon; counts in Homespun 10 `MONOCHROMEOUTLINE`.
- Text: ElvUI's font and style in every role (the shadow black at 0.6, at 1 for `SHADOW` alone, `E:SetFontShadow`),
  at **ElvUI's font size**: every role keeps its difference from ElvUI's 12 (`Size = grow(size)`, a reference with
  `Add`), but the vendor's card names and prices (11, so two lines of a name and a price fit beside its 36-pixel icon)
  and the counts. Font objects are reused by look (next-themes.md §4), so a size slider dragged makes a set per size it
  passes once, and none after.
- **Rows grow with the text** (mapped from the code, every key with its file and line, before it was written): each
  value that sizes a row round following text grows by the change times the lines of text it holds (`grow(base, n)`:
  `Scale` n, `Add` base − 12n), an offset that keeps something centered on a line by half (`HeaderButtonTop`), and a
  width that holds text in proportion (`widen(base)`), the settings window's own `Width` and `Height` too (it shrinks
  itself to fit the screen, `settings:fitScale`, so beyond what the screen holds it is drawn smaller): `Layout.SearchTop`,
  `SearchHeight`, `ContentTop` (2: the title and search above it; nothing derives it), `Footer`, `SectionHeader`,
  `TabHeight`, `TabMaxWidth`; `Dock.TitleHeight`, `LineHeight`; `Currency.Icon` (an entry's row is its icon's, so the
  icons grow too), `Currency.Tracker.ListWidth`; `Controls.Button.Height`, `Input.Height`, `Dropdown.Height`, `Width`,
  `Menu.ItemHeight`, `Menu.Picker.IconSize` (2: a title and a note beside the icon, which grows), `TopTabs.Height`,
  `Slider.ValueWidth`; `Settings.Sidebar.Width`, `Brand.Height`, `Nav.ItemHeight`, `GroupHeight`, `Version.Bottom`,
  `Header.Height` (2), `Content.TitleHeight`, `RowHeight`, `Footer.Height`, `Cards.Height` (3: a name, a status, a
  description), `Categories.RowHeight` (2), `GroupHeight`, `LabelWidth`, `FilterWidth`, `BagCategories.RowHeight`,
  `GroupHeight`, `Currency.HeaderHeight`, `RowHeight`. At ElvUI's 12 every value is as before. Not grown, being no
  theme keys: the money frame (128 × 18, its coins in their own font), the guild's gold (200 × 16), the dock card's gaps,
  the footer line's 4. Not grown on purpose: `FooterText` and `FooterMoney`, anchored by their bottoms in a footer that
  grows as its text does, stay centered where they are (the free-slot text and the currency strip, whose rows grow a
  line); the gold, a box of its own size, has its own anchor, `FooterCoins`, moving by half a line.
- **The bags' text** as ElvUI's bags draw it (`B:UpdateItemDisplay`: FontTemplate, `LSM:Fetch`): item counts and the
  vendor's stack counts (`Stack`) in the count font, size and outline the player picked, item levels in the item level
  ones, a `SHADOW` outline a black shadow 1 down and right (1 alone, 0.6 with an outline, `E:SetFontShadow`), ElvUI's
  Homespun for a name LibSharedMedia does not have (a font not registered for this client's locale: LibSharedMedia
  skips those, `Register`). Not their colors (`countFontColor`, `itemLevelCustomColor`): a color dragged in ElvUI's
  options would make a font object on every step (next-themes-references.md §2b), and the item levels keep BetterBags'
  own colors. Not ElvUI's item info text: BetterBags draws none.
- Layout: 36-pixel icons ten to a row, 4 apart (ElvUI's bags: 34), a shorter header.
- **Outside pixel mode** (Thin Borders off, `E.PixelMode` false; it needs a reload in ElvUI, so it is read, not
  watched): a black line just inside and one just outside every edge, as `SetTemplate` draws them (`$Outlines`: two
  rings, `Offset` 1 and -1, on every edge the theme draws, the panel's, the search box's, the controls', the header
  buttons', the tabs' and cards'; `$ItemOutlines` on item buttons, in Sonata's terms), and what is inside an edge
  just inside its innermost line (`SetInside`, `E.Border`: 1 in pixel mode, 2 outside it): the icon, the item buttons'
  hover and pushed fills (`Inset = "Edge"`), the check box's mark (`KnobInset = "Edge"`, `KnobSize = "Fill"`), each
  measured from the rounded lines themselves. Lines that are not edges (dividers, the tab rail's line) have none.

**Found in review** (Prime Directive #2), each fixed test first: six text roles drawn in the value color made 56 font
objects a frame while it was dragged in ElvUI's options (now gold or gray); the dropdown arrow's `TexCoords` were never
drawn (the dropdown now draws a chevron's `TexCoords`); ElvUI's "!" was on every quest item (now as ElvUI shows it; a second review found a first fix had put it on every
quest item on the Classic clients, from a misreading of ElvUI's `E.Classic`, which is Era alone);
the plain `SHADOW` style's shadow was faint (now by style); the slider's edge covered its thumb's end column (now under
it, `NextControls:CreateEdge`'s `around`); and in the engine a `Watch` written as a map registered but hooked nothing
(now refused), a client's override of a reference kept the base's `Alpha` and `Map` (now replaced whole), and a
`{ Global }` client color named through a variable, data before this change, was refused for having no `Fallback` (now
data again). The second review also found a style's quest art left on a Classic client's button after its quest item
went, over the next item or an empty slot (its buttons have no `UpdateQuestItem`), and a third that a theme without
quest art after one with it left it too: on those buttons the quest texture now shows a style's art over a quest item
and nothing else, and on Retail's a style with quest art owns it (`SonataElements:DrawItemQuest`, also called with no
quest data for a free or reset slot, `frames/item.lua`; sonata.md §3a), which the classic bags' ElvUI theme gets too. Left as they are: a `Watch` in a `Clients` override is not hooked (no theme has one), and the engine's
font check does not count `White`, the color a role without one is drawn in (every theme inherits Default, whose
roles all name a color).

The review of the outlines and quest colors found two drawing bugs, both fixed test first: on a coarse grid (a small
bag at a low UI scale, a screen pixel over 2 units) a ring's offset rounded to nothing while its line kept its pixel, so
the border and both rings fell on one row (offsets are now rounded as lengths: `NextControls` `signedLength`, Sonata
`signedLengthOf`); and an inset of 2 units, rounded once, missed the border and inner ring, each rounded on its own, by
a pixel at some bag scales (a gap at 1.25 and 1.5 pixels per unit, an overlap at 1.6 and 2.6): what sits inside an
edge is now placed from the same rounded lines (`"Edge"`, `"Fill"`). It also found no spec took the rings through a
size switch or the rounded corners' masks; both are covered now. Left as they are: a theme with `Panel.Corners` and
outlines would draw square outer rings round a rounded body (the corner masks lie inside the body; no theme has both);
and on Era a quest starter whose quest the client reports active gets the quest item color, where ElvUI, going by the
tooltip, gives the starter's (no one has seen what Era's quest data says for one).

The review of following ElvUI's font size found three layout bugs, each fixed test first: the footer's free-slot text,
moved by half a line, drifted out of its footer, into the items from 28 (`FooterText` now stays); the sidebar and the
controls widened in a window of a fixed width, so from 30 the controls spilled off the page and at 64 the sidebar was
wider than the window (the window now grows with them); and a settings row's text field and the items tab's filter
kept the width they were made with (`NextInput`'s `width` may be a function, read again as it restyles). It also found
that no spec failed with parts of the font key left out (an Object role's copied look, color, shadow and flags, a
plain role's client file, colors by value, a copy's height, justification); each now fails a spec. Left as they are:
`keyOf` (the classic text roles' key) does not tell a numeric key from a string one or escape strings, so two specs
that differ only so would share an object (no theme writes one); a font LibSharedMedia holds as a file ID would be
drawn as Homespun (the fallback is a string; none seen); neither key includes a font's spacing or alpha.

A third review found closing from a preview slid the window out as a small box (the refit now runs while it is on the
screen, not only while it says it is shown), a UI scale change moved a window the player had dragged to the center (it
now re-centers only for a theme of another size), and no spec on two of the refit's branches (both covered now).

A second review, of those fixes, found the window resized in place when restyled while it showed (a preview, ElvUI's
size changed), off the screen or a small box in a corner (it now fits and centers itself again, next-settings.md §3x);
the gold pinned with `FooterMoney` sat low and hung below the bag from 40 (`Layout.FooterCoins`, the money frame's own
anchor); and, in one restyle order, a settings row's name ran under its widened control (a row now restyles its control
before laying out by it).

**Left out, and why** (also in the design doc):

- The bags' count and item level colors, and the item info text (above).
- LibSharedMedia's override of a font (`OverrideMedia`, which `Fetch` gives first) and its default for a missing name
  (`DefaultMedia`): the name's own file is read, ElvUI's Homespun when there is none. ElvUI's `fontSlug` flag
  (`E:CanFlagSlug`) is not added.
- Not seen in game: the look, and the hook's timing on a real login (inferred from ElvUI's source: its `OnInitialize`
  fills `E.media` from the saved profile before BetterBags starts, and its start calls `UpdateMedia` and then
  `UpdateTexCoords`).

Coverage: `spec/sonata/next_themes_spec.lua` ("ElvUI": its files there in ElvUI, its paths what ElvUI's source keeps
and its watched methods ElvUI's, the player's values followed and Check clean with them, ElvUI's defaults without them,
every font style, ElvUI's font size followed by every role but the vendor's and the counts with every mapped row and
width at 20 and 9, the bags' text by the names picked (and Homespun for a name LibSharedMedia lacks), quest colors
(Era's own), outlines outside pixel mode and none in it, flat, the bag buttons, tabs, search and sections, every control, item buttons, the settings window;
"needs no other addon" and the shipped list), and every shipped-theme spec (`spec/next/shipped_themes_spec.lua`,
`spec/next/pixel_perfect_spec.lua`, `spec/next/theme_panel_spec.lua`) draws it with ElvUI marked loaded; the settings
window with every control, menu and dialog at ElvUI's 22 and 9 (`shipped_themes_spec`), and the backpack and bank on
whole pixels at 9, 15, 20 and 27, full and small (`pixel_perfect_spec`).
