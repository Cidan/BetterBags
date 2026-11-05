---
paths:
  - "core/fonts.lua"
  - "sonata/{apply,elements,engine}.lua"
  - "next/{style,pixel,itemfit,tabs,content,panel}.lua"
  - "next/controls/*.lua"
  - "forms/layouts/*.lua"
  - "frames/itemrow.lua"
  - "spec/sonata/text*_spec.lua"
---
## Never Hard-Code a Font File
**Problem**: Blizzard's fonts are font families with one file per alphabet (`Blizzard_Fonts_Shared/Mainline/Fonts.xml`: roman `FRIZQT__.TTF`, russian `FRIZQT___CYR.TTF`, korean `2002.TTF`, Chinese `ARKai_T.ttf` / `blei00d.TTF`). `FontString:SetFont("Fonts\\FRIZQT__.TTF", ...)` replaces the family with the roman file, so Cyrillic, Korean and Chinese text loses its glyphs (issue #175, the category pane's item rows).
**Solution**: pass the locale's file from the globals Blizzard sets per locale on every client (`Blizzard_Fonts_Shared/Shared/GameFonts.xml`: `STANDARD_TEXT_FONT`, `UNIT_NAME_FONT`, `DAMAGE_TEXT_FONT`), or use a font object. Coverage: `spec/itemrow_spec.lua` ("draws the item name in the client's locale font").

## Theme-Colored Text: Font Objects Made Once, Never Changed
**Problem**: text that picks a client font and sets its own color (`CreateFontString(nil, "OVERLAY", "GameFontNormal")` then `SetTextColor(1, 1, 1)`) looks the same under every theme: on a light theme (Parchment) the settings text was white on parchment. The first fix restyled shared font objects in place on each theme switch, counting on a font object passing its changes to its text; a font object changed while text used it left that text out of step once the text switched font objects (hovering a settings entry changed its size until a theme switch).
**Solution**: draw such text with a Sonata text role (`sonata:CreateText(parent, "Body")`, `sonata:SetTextRole(text, "NavActive")`, `sonata:SetButtonTextRole(button, "Money")`). A font object is made per theme and role, styled once as a copy of its client font (`CreateFont` then `CopyFontObject`, never `Font:SetFontObject`), and never changed; a theme switch or a rescale of the client's fonts (`EventRegistry` `TextSizeManager.OnTextScaleUpdated`) makes new ones and Sonata moves every recorded text to them. The text never calls `SetTextColor`/`SetShadowColor`/`SetShadowOffset` itself; states switch roles. `spec/sonata/text_usage_spec.lua` enforces it for the files that draw window and bag text. See `.claude/rules/sonata.md` §3c.

## A Button's Font String Keeps Its Width When Its Font Changes
**Problem**: a button's own font string (`button:SetFontString(fs)`, one anchor, no width) keeps the width it was sized to when its font object changes, and two fonts that look identical can measure differently: a shadow offset of 1 makes a string about 0.8 wider than a glow at offset 0. A settings navigation entry sized while hovered or selected (glow) wrapped onto a clipped second line in its normal role (shadow): "Import/" for "Import/Export" (render recording on WoW: Forever: width 110.0, string 110.8). Blizzard's reset, width 0 then the same text (`QuestLogTitleButton_Resize`), refreshed `GetStringWidth()` but not the width.
**Solution**: after every font change (and when the entry is made), set the width to 0, set the button's text again, then set the width explicitly from `GetStringWidth()`, rounded up with a pixel to spare, as Blizzard sizes a tab after changing its font (`CRFRaidMarkersMixin:SetTab`). Sonata calls back a text's watcher after each font change (`sonata:WatchTextFont(fs, fn)`: role switches, themes, client rescales); `forms/layouts/stacked.lua` `fitNavText` uses it. To see such a bug, record rendering: every Sonata font change is a `text` entry with its width, string width and lines. See `.claude/rules/sonata.md` §3c.

## Set a Font String's Font Before Its Text
**Problem**: `FontString:SetText()` on a font string created without a template and with no font yet raises `FontString:SetText(): Font not set` in the client. A BetterBags Next section title set its text, then its font, and errored on the first open in game while every spec passed.
**Solution**: give a font string its font (`SetFontObject`, `SetFont`, or a template in `CreateFontString`) before any `SetText`. The spec frame mock raises the client's error, so tests catch the order; spec fixtures that stand in for XML templates must give their font strings the template's font.

## Never Give an Edit Box a Font Object Read Back From It
**Problem**: `EditBox:GetFontObject()` on an `InputBoxTemplate` box returns an unnamed font object of the box's own (its XML `<FontString inherits="ChatFontNormal"/>`), not the font it was given; `box:SetFontObject(thatObject)` makes the font inherit from itself and crashes the client with STACK_OVERFLOW (issue #1152, the ElvUI theme at login).
**Solution**: to restore an edit box, record its look by value (`GetFont`, `GetTextColor`, `GetShadowColor`, `GetShadowOffset`, `GetJustifyH`) and set it back with `SetFont` and the setters, and only touch a box a style changed. Font strings are safe to round-trip (Blizzard does it in `MenuTemplates.lua`); edit boxes are not (Blizzard never does). See sonata.md §3a.

## A Template's Text Color Wins Over a Font Object
**Problem**: a font string with a color of its own (an XML `<Color>`, as `InputBoxInstructionsTemplate` gives its help text 0.35 gray, or an earlier `SetTextColor`) keeps it when given a font object, so drawing it with a theme's text role leaves it the template's color. Seen by reading Blizzard's `InputBoxTemplates.xml`, not in game.
**Solution**: for such text, set the role's color and shadow on the text too, from the role's font object (never one read back from the text: an edit box's `GetFontObject` returns its own), and again with every theme (`NextStyle:SetTemplateFont`, Sonata's `apply:Font`). Text that no template colors (`BagSearchBoxTemplate` sets no enabled color: its `enabledColor` KeyValues are commented out) needs only its font object. next-themes.md §4.

## A Font String Given a Width Centers Its Text
**Problem**: a font string anchored by one corner and sized to its text looks left- or right-aligned whatever its justification. Give it a width (to cut it short, `SetWidth` with `SetWordWrap(false)`) and its text centers in that width, because `justifyH` defaults to `CENTER` (`Blizzard_SharedXML/UI.xsd`, for `Font` and `FontString`). BetterBags Next's small backpack title moved about 100 units right once small panels cut titles short; the bank's, already right-justified, did not move.
**Solution**: justify a font string toward the side it is anchored on whenever it may get a width, and set it again after anything that gives it a new font object. The spec mock answers `CENTER` for a font string never justified, as the client does. next-small-names.md §14g.

## Copies of the Client's Fonts Go Stale When UI Addons Rewrite Them
**Problem**: A Next role that copies a client font (`Object`) copies it when the theme applies, at BetterBags'
load. UI addons rewrite the client's fonts later (GW2_UI at `PLAYER_LOGIN`), so the copy keeps Blizzard's font.

**Rule**: Record what each copy was taken from and check it once the game has started (`PLAYER_ENTERING_WORLD`):
`NextStyle:CopiesStale`, `SonataNext:WatchClientFonts` (next-themes.md §4). A copy is how a theme follows another
addon's fonts, its locale files and its player's settings, with no locale logic of its own.

## A Font String Keeps Its Width Through a Font Change
**Problem**: In the client a font string anchored at one point takes its text's width when its text is set, and keeps
it when its font changes afterwards; text wider than that is cut with "..." (or wraps). Seen twice: the classic
settings window's entries (sonata.md 3c) and BetterBags Next's selected tab ("Backpa...": its font has a shadow).
Blizzard documents the reset in `QuestLogTitleButton_Resize` ("HACK").

**Rule**: After changing the font of single-anchored text that is not given a width, reset it as Blizzard does and
size it explicitly: `SetWidth(0)`, `SetText(GetText())`, `SetWidth(math.ceil(GetStringWidth()) + 1)` (`fitNavText`
in `forms/layouts/stacked.lua`, `railProto:placeContent` in `next/tabs.lua`). Text anchored at both ends takes its
width from the anchors and does not need it. The specs' mock measures text the same in every font: a test makes the
text measure wider in the new font to show the code re-measures.

## Text Exactly on a Whole Pixel Jumps a Pixel
**Problem**: in a pixel-perfect layout, tab names and an item count jumped one pixel right as a panel's snap ended,
and nothing else moved. Every text was placed exactly on a whole pixel, and the client draws text in whole pixels:
float error of a thousandth of a pixel (their left edges read 2758.999 during the snap, 2759.000 after) decided which
pixel the glyphs landed in. Texts whose edges were not on a boundary never moved.

**Rule**: place text a quarter pixel right of and above a whole pixel (`NextPixel:TextOffset`, added by `Point`,
`Inset`, `Row` and `TextInsets`), so it is drawn in the same pixel whether the client rounds or truncates; keep
textures on whole pixels. Never hang anything from a text: the offset carries, and a text hung from a text sits half a
pixel off. When a text moves by exactly one pixel with no layout change, look for an anchor exactly on a boundary.

## Never Give a Text the Size It Reports
**Problem**: an item level showed as a dot under the icon, only in BetterBags Next. Its item fitter recorded every
part's size the first time it fitted a button and set it again in whole pixels, texts included. A text with no size of
its own reports its text's size, so the item level was frozen at the width of the level it first showed, rounded to the
nearest pixel, and a text narrower than its text is cut short: a fraction of a pixel short, or a longer level later.

**Rule**: place a text by a corner and let the client size it; save and restore only its points. Size a text only to
the room it may take (a title in a header), never to what it measures now. When a text reads "..." or less, check for
a width set on it. The frame mock reports an unsized text's size as its text's, as the client does; a test that wants
"no width set" compares `GetWidth()` with `GetStringWidth()`, not with 0.
