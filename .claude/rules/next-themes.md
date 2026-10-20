# BetterBags Next Themes (`sonata/next.lua`, `sonata/themes/next/`, `next/style.lua`)

BetterBags Next draws its look from a **Next theme**: a declarative, data-only table, the same
mechanism as the classic bags' Sonata themes (sonata.md), with its own registry, saved choice and
settings page. Asked: "bring sonata engine system's to next, but greatly expanded. same mechanism
(apply with a declarative spec, no functions!), we'll likely need a different theme registration path
(original themes, next themes)... as expansive as possible in our theme application here on the
widgets -- from text, to outlines, to search, to buttons, to backgrounds, to animations, to
fade/feathering, all of it. the current design should be the 'default' -- ... take care with text!
... (don't re-use text objects across themes, make whole new ones)".

Before this, Next's whole look was constants in `next/style.lua` and literals across `next/*.lua`;
`NextStyle` said "Next draws itself and does not follow the theme".

## 1. The pieces

| Piece | File | Role |
|---|---|---|
| `SonataResolve` | `sonata/resolve.lua` | Theme resolution shared by both engines: inheritance (`Parent`, else the registry's base), per-client overrides (`Clients`), variables (`"$Name"`), the merge rules (tables merge, lists replace, `false` removes). Moved out of `sonata/engine.lua`; the classic engine delegates (`Resolve`, `chainOf`, `GetClientKeys`) and every Sonata spec passes unchanged. |
| `SonataNext` | `sonata/next.lua` | Next's engine: registry, data-only validation, availability (`Requires`), the saved choice (`nextTheme`), applying, previews, widgets, item buttons, `Check`. |
| Next themes | `sonata/themes/next/*.lua` | `Default` (complete: every other theme inherits what it does not set from it), `Ember`, `Parchment`, `Quiet`. |
| `NextStyle` | `next/style.lua` | A view of the current theme (`Use`): the old constant fields (`ICON`, `PAD`, `Color`, `Time`, `Small`, `Chain`, `Cloud`, ...) keep their names and are read from the theme, so Next's code reads them as before; `style.Theme` is the resolved theme for widget specs. Fonts, `Paint`, `RGBA`, `Ease`, `TexturePath`. |
| Widgets | `next/*.lua` | Each draws from the theme and has an `ApplyStyle(ctx)` that restyles it live. |

Load order (every TOC, `spec/render/toc_spec.lua`): `sonata\resolve.lua` before `sonata\engine.lua`,
`sonata\next.lua` right after it, the Next theme files after the classic themes and before
`next\style.lua` (which resolves Default when it loads). `core/init.lua` calls
`SonataNext:Init()` right after Sonata's, before any bag is made (initialization.md).

## 2. The engine (`SonataNext`)

- **`RegisterTheme(theme)`** (also `Sonata:RegisterNextTheme(theme)`, the "other registration path"):
  a unique `Name`; **data only**: a function, an object (a table with a metatable, a frame) or
  userdata anywhere in it is refused, naming its path (`Bad.Fonts.Title.Size is a function`).
  `Requires` is a list of addon names (instead of Sonata's `Available` function); unknown client keys
  are refused. A theme registered after Next started that is the saved choice is applied at once,
  unsaved (another addon's theme loading late), as Sonata does.
- **`IsAvailable(key)`**: registered and every `Requires` addon loaded (`C_AddOns.IsAddOnLoaded`,
  second return, every client). `IsSelectable` adds not `Hidden`. `GetThemes` lists every theme not
  hidden; `GetAllThemes` those a player can pick.
- **`Resolve(key)`**: `SonataResolve` over Next's registry with `Default` as the base.
- **`Init()`**: forgets widgets, and uses the saved theme (`GetSavedThemeKey`: the saved one, or
  Default while it is missing, hidden or unavailable, the saved choice kept) without saving or sending
  anything.
- **`ApplyTheme(ctx, key, save?)`**: refuses unknown, hidden or unavailable themes (changing nothing);
  resolves; bumps `GetGeneration()`; saves unless `save == false` (a preview); hands the theme to
  `NextStyle:Use`; syncs the item buttons (§6); calls every registered widget's `ApplyStyle(ctx)`, each
  in its own protected call (a failure goes to `geterrorhandler()` and the rest are still styled; one
  unregistered by another during the apply is skipped); sends `sonata/NextThemeChanged`.
- **`RestoreSavedTheme(ctx)`**: applies the saved choice, unsaved, when another is in use (previews).
- **`RegisterWidget(widget)` / `UnregisterWidget`**: weak; registered by every panel when made
  (`nextPanel:Create`), by `NextDrag` once it builds its layer or dock, by `NextVendorButton` when it
  makes its first button.
- **`Check(key)`**: what a theme names but does not define, each as `"path: problem"`: palette colors
  (keys `Color`, `Fill`, `SelectedFill`, `FocusFill`, `HoverColor`, `FocusColor`, `BeadColor`,
  `KnotColor`, `Unusable`, `SoldOut`, `SoldOutUnusable`, and the values of `Washes`, `Accents`,
  `Colors`), text roles (`Font`, `SelectedFont`, `TitleFont`, `RecentFont`, `FreeFont`, `CountFont`,
  `HelpFont`, `TextFont`, `EmptyFont`, `MoneyFont`, `HintFont`, `WarningFont`, `PriceFont`,
  `UnaffordableFont`, `StackFont`), textures (`Texture`, `QualityBorder`, `QuestMark`: a `Textures`
  name, or a file by path or ID) and eases (`Motion.Ease`, against `NextTween.Ease`). For theme authors;
  every shipped theme is checked on every client.

## 3. The schema (Default, `sonata/themes/next/default.lua`)

Colors are palette names or `{ r, g, b, a }`. A part set to `false` is turned off. A **texture spec**
is `{ Color, Texture (a Textures name or a file), Atlas, TexCoords, HorizTile, VertTile, BlendMode,
Desaturated }`, drawn by `NextStyle:Paint` (a solid color without art; art tinted by `Color`; tiling
loads with the `REPEAT` wrap mode; everything it does not set is reset).

| Key | What |
|---|---|
| `Palette` | Every named color. |
| `Textures` | Named files (`Glow`, `Sparkle`; Parchment adds `Paper`). |
| `FontShadow` | The shadow `Shadow = true` means. |
| `Fonts` | Text roles: `Size`, `Color`, `Shadow` (true, a table, or none), `Flags`, `File` (unset: the client's own font, for the locale), `Justify`. Default's roles: Title, Section, SectionRecent, SectionFree, Count, Tab, TabSelected, Footer, Empty, DragHint, ConfirmTitle, ConfirmWarning, ConfirmHint, Search, SearchText, Price, PriceUnaffordable, Stack. |
| `Layout` | Sizes: Icon, VendorPrice, Gap, PerRow, Gutter, Pad, Feather, TitleTop, TitleInset, SearchTop, SearchHeight, SearchIcon, SearchGap, SearchRight, ContentTop, EmptyTop, Footer, FooterText, FooterMoney, SectionHeader, SectionSpacing, TabHeight, TabSpacing, TabMinWidth, TabMaxWidth, TabPadding, TabHover, TabIcon, TabIconGap, TabGroupGap, HeaderButton, HeaderButtonGap, HeaderButtonTop. |
| `Motion` | `Time` (every animation's seconds), `Ease` (Open, Close, SmallOpen, SmallClose, Enter, Fly, Glide, Hover, Wash, Cascade, Lift, Land, FlyAway, Pulse, Couple, Uncouple, Morph, MorphFade), `Rise` (the cascade). `NextStyle.OVERREACH` follows the Open ease's overshoot (outBack a tenth, outBackSoft a fiftieth, others none). |
| `Panel` | `Fill` (texture spec), `Feather` (`Color`, or false), `Wash` (`Height`, `BlendMode`, or false), `Washes` (Default, Warbank, Guild: palette names), `Edge` (`Color`, `Alpha`, `Size`, `Full`: on full panels too, kept through a size switch; or false), `DropGlow` (or false). |
| `Header` | `Title.Font`; `TitleGlow` (`Texture`, `Color`, `Alpha`, `X`, `Y`, `BlendMode`, or false); `Ribbon` (`Length`, `Thickness`, `Color`, `BlendMode`, `Glow`: `{ offset, alpha }` lines, as many as listed; or false); `Spark` (`Texture`, `Size`, `Growth`, `Color`, `BlendMode`; false: no shimmer); `Cloud` (puffs as many as listed, `Join`, swell and breath; or false); `Buttons` (`Color`, `HoverColor`, `Icons` by button key: `{ Atlas }` or `{ Texture, TexCoords }`; the size button by state, `sizeButtonFull`, `sizeButtonSmall`). |
| `Search` | `Fill`, `FocusFill`, `Edge` (`Color`, `Size`, `Idle`, `Hover`, `Focus`, or false), `Icon` (`Color`, `Idle`, `Active`, `FocusColor`), `HelpFont`, `TextFont`. |
| `Sections` | `Title` (`X`, `Y`), `CountGap`, `LineGap`, `TitleFont`, `RecentFont`, `FreeFont`, `CountFont`, `Line` (`Color`, `From`, `To`, `Size`, or false), `Highlight` (`Color`, `From`, `To`, or false). |
| `Tabs` | `Fill`, `SelectedFill`, `Fade`, `Font`, `SelectedFont`, `Glow` (`Color`, `BlendMode`, `Drop`, `Pulse`, or false), `Indicator` (`Color`, `Width`, or false), `Accents` (Warbank, Guild). A tab entry's `accent` is an accent name, a palette name or a color. |
| `Footer` | `Line` (`Color`, `Inner`, `Outer`, `Size`, or false), `Font`, `EmptyFont`, `MoneyFont` (the guild's gold). |
| `Sparkles` | `Texture`, `BlendMode`, `Colors`, `FadeIn`, `FadeOut`, `TwinkleSpeed`, `TwinkleDepth`, `Shrink`, `WobbleSpeed`; emitters `Cloud`, `Ribbon` (+`Spread`), `Edge` (+`Reach`), `Knot` (+`Burst`), each `Rate`, `Max`, `Life`, `Size`, `Speed`, `Rise`, `Wobble`, `Spin`, `Alpha`, or false; `Sparkles = false` turns them all off. A coupled bag keeps its shorter ribbon and edge sparkle lives (next.md §12, §14e). |
| `Chain` | Chaining (next.md §12) and the braid: `Braid` (false: none), `Segments`, `Beads`, colors (`Color`, `BeadColor`, `KnotColor`), sizes and timing. |
| `Small` | Small mode (next.md §14). The border's alpha is `Panel.Edge.Alpha`. |
| `Drag` | `LiftScale`, `FlyScale`, `Shadow` (`Color`, `Alpha`, `Spread`, or false), `HintFont`, `HintGap`. |
| `Dock` | `Scrim`, `Card` (texture specs: a card can be art), `Pad`, `Top`, `TitleHeight`, `LineHeight`, `Glow` (`Color`, `Width`, `Low`, `High`, `Period`, or false), `Halo` (`Texture`, `Color`, `Spread`, `Low`, `High`, `Period`, `BlendMode`, or false), its line roles. |
| `Vendor` | `QualityBorder` (a file, or false), `QuestMark`, `SearchDim`, `Highlight` (a color), tints (`Unusable`, `SoldOutUnusable`, `SoldOut`), roles (`PriceFont`, `UnaffordableFont`, `StackFont`), `DurabilityHeight`. |
| `ItemButton` | Optional: a Sonata `ItemButton` element style (sonata.md §3a) for item buttons while Next is in use (§6). |

**Default is the v0.7.0 design, value for value**: `spec/fixtures/next_style_v0_7_0.lua` freezes
v0.7.0's `next/style.lua`, and `spec/next/style_theme_spec.lua` checks every value and every font
(file, size, color, shadow) against it. Data-driven colors stay out of themes: item quality,
item level colors, the durability bar's green to red.

## 4. Text (the lesson from Sonata, sonata.md 3c)

- **A font object is made once and never changed.** `NextStyle:Use` starts a new set of font objects
  (uniquely named `BetterBagsNextFont<Role><n>`) with every theme, also the same theme applied again,
  and moves every text drawn with a role to its role's new one. Old font objects are never touched.
- `NextStyle:SetFont(text, role)` / `CreateText(parent, role)` draw text with a role and record it.
  Text must not set its own color or shadow: a state that looks different is another role (the
  vendor's price an item cannot afford is `PriceUnaffordable`, not a red `SetTextColor`; a selected
  tab is `TabSelected`).
- Text on a role the new theme does not define (another theme's own) keeps its font object until its
  widget restyles it with this theme's roles.
- **Template colors win over font objects.** `NextStyle:SetTemplateFont` sets the role's color and
  shadow on the text too, now and with every theme, read from the role's font object, never one read
  back from the text (`.context/patterns-ui.md`). Used for the search box's help text, which
  `InputBoxInstructionsTemplate` gives an XML `<Color>` (0.35 gray). What is typed needs no such
  color: `BagSearchBoxTemplate` sets no enabled color (the template's `enabledColor` KeyValues are
  commented out, "Optional"). Inferred from the XML, not seen in game: v0.7.0 gave the help text only
  a font object, so it likely stayed gray.

## 5. Widgets restyling live

Every widget builds its parts, then styles them from the theme with the same functions `ApplyStyle`
calls again. Sizes are read when used (no value kept at load).

- **Panel** (`next/panel.lua`): `StyleParts` (body, mover, search box, header, content, footer,
  sparkles, tab rail, canvas) then `ApplyStyle` reshapes it (`ApplyGeometry`), places a chained pair
  (`chain:Update`), restarts its emitters and shimmer while it shows, and draws its content again
  (`Draw` with its last data: at once while shown, else on show), so buttons take the theme's icon
  size. Pools let a theme change counts: cloud puffs, ribbon lines, braid segments and beads; surplus
  ones are hidden. The wash remembers its key (`washKey`), so a theme paints the same thing (the
  Warbank's wash) in its own color. Emitters a theme turns off never start (`SetEnabled`).
- **Tab rail** (`next/tabs.lua`): restyles every tab, shown or pooled, and lays them out again (their
  widths follow the new fonts).
- **Canvas** (`next/content.lua`): restyles every section, drawn, kept from the last pass or pooled.
  `SetPriceRow` (the vendor's) replaced `SetCellHeight`, so rows follow the theme's icon size.
- **Drag and dock** (`next/drag.lua`): restyled in place while a section is lifted or docked.
- **Vendor buttons** (`next/vendorbutton.lua`): every button made, in use or pooled; the vendor
  fits its name to the theme's header sizes again.
- **Size button**: its icon follows the theme by state (`SetHeaderIcon`).

## 6. Item buttons

Item buttons are shared by both designs and styled by Sonata's `ItemButton` element (the classic
bags' theme). `Sonata:SetElementStyleOverride(kind, style)` makes a style replace the theme's for a
kind (restyling it at once; nil gives the theme's back). `SonataNext:SetActive(design == "next")` is
called by `BagSystem:Use`; while Next is in use and its theme sets `ItemButton`, that style is the
override, and `ItemFrame:RestyleButtons()` makes every button draw in full again. Default sets none,
so item buttons look as before. Masque is still decided by the bags' theme.

## 7. Picking a theme

The settings window's **Next Theme** page (right after **Theme**) is the Theme pane over SonataNext
(`themePane:Create(parent, sonataNext)`; the pane takes any engine with GetThemes, IsAvailable,
IsSelectable, GetCurrentThemeKey, GetSavedThemeKey, ApplyTheme, RestoreSavedTheme): themes by name,
those whose addons are not loaded shown as unavailable, a pick previewed on the next frame without
saving, **Apply Theme** saves, the saved one put back when the page hides. The bags' theme is left
alone. The setting is `nextTheme` (`DB:Get/SetNextTheme`, default `"Default"`).

## 8. The shipped themes

- **Default**: the design as it was.
- **Ember**: a charcoal and amber palette, sparkles drifting slowly and rising like embers.
- **Parchment**: Moonlight's parchment art (the plain middle, away from its burnt edges) for the body
  and the dock's card; dark ink text in Blizzard's parchment text colors with no shadow (numbers over
  icons keep one); ink and sealing-wax lines, bars and glows drawn normally, not added as light; no
  sparkles, cloud, spark or wash. Its paper color (feather, tabs) is the art's measured average
  (0.83, 0.78, 0.70).
- **Quiet**: cool grays, smaller icons nine to a row, a shorter header, no ribbon, cloud, spark,
  sparkles or braid, quicker opening without a bounce (the body reaches only 4 past the edge), a thin
  border at both sizes.

Not seen in game yet: any theme but Default.

## 9. Coverage

- Engine: `spec/sonata/next_engine_spec.lua` (registration and data-only refusal by path, objects,
  clients, `Requires`; availability and listing; resolution, parents, lists, `false`, clients,
  untouched tables; starting with the saved theme or Default; applying, saving, previews, refusals,
  widget failures isolated, unregistering, late themes; restoring; item buttons with `SetActive`;
  `Check`), `spec/sonata/engine_spec.lua` (the override), every Sonata spec unchanged (the resolver).
- Default and text: `spec/next/style_theme_spec.lua` (the v0.7.0 golden test, split-off roles, layout
  and OVERREACH from a theme, colors, new font objects per theme, edit boxes, role switches, unique
  names, roles a theme lacks, template colors).
- Widgets: `spec/next/theme_panel_spec.lua` (on the real backpack and bank: every part above, its
  toggles, sizes, the content drawn again at the theme's icon size shown and hidden, animations,
  tabs and sections restyled with the panel, and every shipped theme applied in turn to open, drawn
  bags at both sizes with no error), `spec/next/content_spec.lua`, `spec/next/tabs_spec.lua`,
  `spec/next/drag_spec.lua`, `spec/next/vendorbutton_spec.lua`, `spec/next/vendor_spec.lua`,
  `spec/next/guildbank_spec.lua` ("a theme" blocks).
- Themes: `spec/sonata/next_themes_spec.lua` (each resolves on every client and checks clean; each
  looks as described).
- Settings and wiring: `spec/config/themepane_spec.lua` (the pane over SonataNext),
  `spec/config/config_redraw_spec.lua` (the page), `spec/bagsystem_spec.lua` (`SetActive`),
  `spec/database_spec.lua`, `spec/core/constants_spec.lua`, `spec/render/toc_spec.lua`.
- Every guard was mutation-tested (about 80 mutations): each that survived led to a test or to
  removing what it showed unneeded (the edit box's template color).
