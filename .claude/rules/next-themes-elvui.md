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
  ElvUI's `FontTemplate`), and `TexCoords` (the icon crop). Each falls back to ElvUI's default (`Defaults/Profile.lua`,
  `Defaults/Private.lua`); the font to the client's own. A spec checks each path is one ElvUI's source writes
  (`E.media.<key> = ` in `General/Core.lua`, `E.TexCoords`, the profile's `fontStyle`).
- **Watched** (next-themes-references.md §2b): `E:UpdateMedia` (its options call it after every change; a profile change too) and
  `E:UpdateTexCoords` (ElvUI's start crops icons after its last `UpdateMedia`, so `E.TexCoords` is `{ 0, 1, 0, 1 }`
  when BetterBags Next first applies the theme).

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
  sizes fixed per role (12 for most, as ElvUI's general size). The vendor's
  card names and prices are 11, so two lines of a name and a price fit beside its 36-pixel icon.
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

**Left out, and why** (also in the design doc):

- ElvUI's font size is not followed: a theme drawn again at other sizes makes new font objects, which can never be freed
  (a size slider dragged would leave a set behind on every step).
- ElvUI's per-bag text settings (its count, item level and info fonts) are LibSharedMedia names, which only a function
  can turn into files: the count is drawn in ElvUI's default.
- Not seen in game: the look, and the hook's timing on a real login (inferred from ElvUI's source: its `OnInitialize`
  fills `E.media` from the saved profile before BetterBags starts, and its start calls `UpdateMedia` and then
  `UpdateTexCoords`).

Coverage: `spec/sonata/next_themes_spec.lua` ("ElvUI": its files there in ElvUI, its paths what ElvUI's source keeps
and its watched methods ElvUI's, the player's values followed and Check clean with them, ElvUI's defaults without them,
every font style, quest colors (Era's own), outlines outside pixel mode and none in it, flat, the bag buttons, tabs, search and sections, every control, item buttons, the settings window;
"needs no other addon" and the shipped list), and every shipped-theme spec (`spec/next/shipped_themes_spec.lua`,
`spec/next/pixel_perfect_spec.lua`, `spec/next/theme_panel_spec.lua`) draws it with ElvUI marked loaded.
