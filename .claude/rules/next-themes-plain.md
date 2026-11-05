---
paths:
  - "sonata/themes/next/plain.lua"
  - "next/settings/window.lua"
  - "next/settings/page.lua"
  - "next/settings/rows.lua"
  - "spec/sonata/plain_art_spec.lua"
---
## 17. Blizzard's look in controls (for the Plain theme)

Each of these is how Blizzard draws a control, read from its template (docs/next-plain-theme.md), and generally
available to themes:

- **Atlases at their own size** (`useAtlasSize`): `NextStyle:AtlasSize(atlas)` and `SizeOf(spec, art, fallback)`
  (`Size = "Atlas"`); the slider's `ThumbSize = "Atlas"`; fills above.
- **The dropdown's arrow in its art for each state** (`GetWowStyle1ArrowButtonState`): `Chevron.Hover`, `Pressed`
  (pressed under the pointer), `Open`, `Disabled`, at `Size = "Atlas"`, by its right at `Point` from the dropdown's right
  edge; `Justify` (Classic writes the choice right, against the arrow); `DisabledFont` and `DisabledAlpha` (Blizzard
  grays the text and swaps the arrow, dimming nothing); `NarrowWidth` and `NarrowFill` (Classic's `-small` background at
  100 wide or less).
- **Radio menus** (`MenuVariants.CreateRadio`): `Check.Off`, the empty ring on every row not chosen, and `Check.Under`,
  the ring under the chosen row's tick at its top left (retail draws two textures; Classic swaps one, so no `Under`);
  `Menu.Inset` per side (`MenuStyle1Mixin:GetInset`), `Menu.Border` over its fill (Classic's art).
- **The dialog**: `Border` over its `Card` (today's popup: the diamond border over the dark background).
- **Page tabs** (`MinimalTabTemplate`): each tab's `Fill`, `HoverFill`, `SelectedFill`, `Padding` either side of its
  label, the label by its bottom `TextBottom` above the tab's (`SelectedTextBottom` chosen); `Indicator = false` and
  `Line = false` hide the marker and line for good.
- **The settings list** (`Blizzard_CategoryList.lua`): `Spacing`, `TextRaise`, `GroupFills`, `GroupLabel`, atlas-sized
  row fills; `Close.Atlas`, `Close.Highlight`, `Close.Offset`.
- **The settings slider** (`MinimalSliderWithSteppersTemplate`, `MinimalSlider.lua`): `Slider.Steppers` (`Back`,
  `Forward`: `Atlas` or `Texture`, `Width`, `Height`; `Gap` out from the bar's ends; `Room` left either side of the bar;
  `DisabledAlpha` for a stepper whose way the value can go no further, desaturated too), each stepping the value by its
  step; `Slider.Value = "Text"` writes the value `ValueGap` right of the bar in `ValueFont` (`ValueDisabledFont`
  disabled) instead of the box to type in; `Slider.DisabledAlpha` dims the bar alone while disabled (Blizzard's 0.7).
- **The settings dropdown** (`WowStyle2DropdownTemplate`, `DropdownWithSteppersTemplate`): `PressedFill` and
  `DisabledFill` (its art for each state, `GetBackgroundAtlas`); `Chevron.Anchor` (the point it hangs by, `BOTTOM` for
  WowStyle2's arrow) and `Chevron.HoverOnly` (shown only under the pointer); `Steppers` (`Back`, `Next`: an atlas and its
  `Disabled` art; `Width`, `Height`; `BackGap`, `NextGap` out from the dropdown; `Fill` and its states for the buttons,
  at their atlas size centered with `AtlasSize`), stepping to the choice before or after, off at the ends and while the
  dropdown is; `Dropdown.Menu`, what the menu a dropdown opens changes in `Controls.Menu` (`NextMenuOptions.style`,
  merged key by key: Blizzard's settings dropdowns open `MenuStyle2`).
- **The bag search box**: `Search.Inset` (`Left`, `Right`: the box in from the body's sides, mirrored on the bank, else
  the side pads), `Search.Inner` (`IconX`, `IconY`, `IconSize`, `TextLeft`, `TextRight`, `ClearRight`: its insides as
  `SearchBoxTemplate` anchors them, else Next's own layout), `Search.HelpColor` (the template's own color for its help).
- **Smaller ones**: a button's `Highlight`, `DisabledFont` and `SetStyle` (a button changing looks), the magnifier's
  `ActiveColor`, `Search.Template`, a header icon's `Pushed` and `Disabled`, a centered title, `RowStart`, tab
  `Highlight`s, ornaments' `Atlas`, `Mask`, `Unit` and `Above` (next-themes-ornaments.md §12), palette `Global` colors, `Copy` fonts, an input's
  icon `Atlas`.

## 18. The settings window as Blizzard's (`next/settings/window.lua`, `page.lua`, `rows.lua`)

**Why.** Reported in game (round two, docs/next-plain-theme.md): Plain's settings window was Next's own layout in
Blizzard's art (a full-height sidebar from the window's edge, its fill and list art over the border, the brand, two
columns of cards, controls at the far right, tabs floating under the header). Blizzard's settings window
(`Blizzard_SettingsPanel.xml`, the same on every client) is laid out differently; these keys let a theme lay Next's
window out as Blizzard's. Each defaults to Next's own layout, so Default and the other themes do not move (the window
specs that predate them pass unchanged).
Plain laid its settings window out with them in round two; round three went back to Default's layout, skinned (asked: "keep
it like we do in default, just, pass over with skin a bit"; docs/next-plain-theme.md). They stay for a theme that wants
Blizzard's window, covered by their own specs.

- **The window**: `Settings.Title` (`Font`, `Top`, `Left`, `Right`, `Height`: the window's name in its title bar, centered
  between `Left` and `Right`, the bar `Height` tall moving the window), `Settings.InnerFrame` (a fill on the window under
  its content: `Options_InnerFrame` at its size at 17, -64), `Brand = false` (no brand: its icon, name and line hide).
- **The sidebar**: `Sidebar.Left`, `Top`, `Bottom` (the sidebar inside the window, `Left` in and `Top` down to `Bottom`
  above its bottom; its height everything a page's list and the slide measure from), `Back.Height` (the row Back sits in,
  else the brand's); `Nav.ItemWidth` (rows and headings that wide from the list's left), `Nav.GroupUpper = false`
  (headings as written).
- **The search box**: `Search.Place = "Top"` with `Width`, `Right`, `Top` (on the window at its top right), `Search.Atlas`
  (its magnifier an atlas). The pages' list then starts at the sidebar's top.
- **The version**: `Version.Window` with `Left`, `Bottom` (at the window's bottom left).
- **The header and content**: `Header.Left`, `Right`, `Top` (the content from `Left` right of the sidebar to `Right` from
  the window's right, its header `Top` down), `Header.DescriptionFont = false` (no description), `Header.Divider` (a fill
  on the header: `Options_HorizontalDivider` centered 50 down), `Header.Actions.Right` (a page's buttons from the header's
  right; else clear of a close button in its corner); `Settings.Tabs.Top`, `Left` (a page's tabs on the window, `Top`
  down from the content's left, taking no room under the header); `Content.ScrollLeft`, `ScrollRight`, `ScrollTop` (the
  scroll area beside the content's left, in from its right, below the header).
- **The footer**: `Footer.Left` (from the window's left), `Footer.Buttons` (`Width`, `Right`, `Bottom`, `Gap`: Done that
  wide at the bottom right, What's New left of it), `Footer.WhatsNew` (What's New's look: a link, or a button).
- **The page as Blizzard's list** (`Content.Layout = "List"`, `SettingsListTemplate`, `SettingControls`): one column `Pad`
  in and `PadRight` from the right, `Top` and `Bottom` padding, `RowGap` between every element; a section's title element
  `SectionHeight` tall, its title `TitleX` in and `TitleTop` down, as written unless `TitleUpper`; rows at least
  `RowHeight` tall, a setting's name `LabelX` in up to `LabelRight` from the row's middle (wrapping there), each control
  from the middle by its kind's `Content.Controls[kind]` (`X`, `Y` up: `toggle`, `slider`, `dropdown`, `color`, `input`,
  `buttons`), a row lit across it from `HoverInset.Left` past its left to `HoverInset.Right` short of its right; no cards
  or lines.
- **Coverage**: `spec/next/settings/window_spec.lua` ("laid out as Blizzard's settings window"),
  `spec/next/settings/page_spec.lua` (both "laid out as Blizzard's list" blocks), `spec/next/controls/slider_spec.lua`
  ("with steppers and its value written"), `spec/next/controls/dropdown_spec.lua` ("as Blizzard's settings dropdown"),
  `spec/next/theme_panel_spec.lua` ("sits Inset in from its body's sides…", "the Plain theme").
