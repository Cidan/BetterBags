# UI Patterns

## Forms and Settings

### Use Anchor Points Instead of Fixed Widths
**Problem**: `SetWidth(container:GetWidth() - offset)` evaluates to 0 at creation time because the layout engine hasn't calculated the frame's dimensions yet.
**Solution**: Use `SetPoint("RIGHT", container, "RIGHT", -20, 0)` so the element expands automatically with its parent.

### Constrain FontString Width for Word Wrapping
**Problem**: `SetWordWrap(true)` alone doesn't prevent overflow — the FontString still expands horizontally to fit text on one line.
**Solution**: Anchor both left and right sides: `fontString:SetPoint("RIGHT", container, "RIGHT", -20, 0)`.

### Module Loading Order for GetModule Calls
**Problem**: `addon:GetModule()` at file scope fails if the target module hasn't registered yet (load order race).
**Solution**: Always call `GetModule()` inside functions, not at file scope (functions run after all modules are loaded).

### Accessing Form Element References After Layout
**Problem**: `form:AddTextArea()` returns the container frame, not the EditBox. The EditBox lives at `container.input` and isn't available until after layout completes.
**Solution**: Use `bucket:Later()` to look up the element after layout, then store the reference at module level.

## Tooltips

### GameTooltip:SetText vs AddLine Have Different Signatures
- `SetText(text, r, g, b, **alpha**, textWrap)` — 6 args (has alpha before textWrap)
- `AddLine(text, r, g, b, textWrap)` — 5 args (no alpha)

**Common bug**: `SetText("text", 1, 1, 1, true)` — `true` is parsed as `alpha`, not `textWrap`. Long text renders off-screen.
**Fix**: `SetText("text", 1, 1, 1, 1, true)` — include explicit `alpha=1`.

## Mouse Wheel Scroll Event Propagation

### Disable Mouse Wheel on Child Frames Inside WowScrollBox
**Problem**: WoW does NOT bubble mouse wheel events. The topmost interactive frame with mouse wheel enabled consumes the event silently. Two default sources of interception:
1. `ContainerFrameItemButtonTemplate` — enables mouse wheel in its `OnLoad`
2. Section content grids — inner `WowScrollBox` templates register their own `OnMouseWheel`

**Solution**: On every non-scrollable child frame inside a scrollable parent:
```lua
frame:SetScript("OnMouseWheel", nil)
frame:EnableMouseWheel(false)
```

**Apply to**:
- Item buttons: `frames/item.lua:825-830`, `frames/era/item.lua`, `frames/itemrow.lua:205-210`
- Section content grids: `frames/section.lua:690-696` via `content:EnableMouseWheelScroll(false)`

**Grid API** (defined in `frames/grid.lua:148-156`): `grid:EnableMouseWheelScroll(false)`.

## Drag-to-Reorder with Module-Level State

**Solution pattern** (for tabs or similar reorderable elements):
1. Module-level state: `tabs.draggingTab`, `tabs.isDragging`, `tabs.lastOverlapIndex`
2. Lock Y-axis during horizontal drag (prevents visual jank)
3. 50% overlap threshold: trigger reorder when dragged center is within half the target's width
4. `lastOverlapIndex` debounce to prevent redundant reorders
5. Skip the dragging element when reanchoring all tabs
6. Persist final order to database on mouse up/drop

**Key Files**: `frames/tabs.lua:29-42` (state vars), `frames/tabs.lua:624-804` (handlers), `core/database.lua:681-694` (persistence via `SetGroupOrder`/`GetGroupOrder`)

## StaticPopup Dialog Data Race Condition

**Problem**: Setting `dialog.data` after `StaticPopup_Show()` is too late — `OnShow` fires synchronously during `Show()` before the function returns.
**Solution**: Pass data as the 4th argument to `StaticPopup_Show()`:
```lua
-- BAD: f.data is nil when OnShow fires
local dialog = StaticPopup_Show("MY_DIALOG")
if dialog then dialog.data = { value = x } end  -- too late!

-- GOOD: data is assigned before OnShow
StaticPopup_Show("MY_DIALOG", nil, nil, { value = x })
```
**Related Files**: `bags/backpack.lua` (its `StaticPopup_Show` calls). BetterBags Next's settings use no `StaticPopup` (`NextDialog`).

## Object Pooling Patterns

### Always Reset ALL Properties When Releasing Pooled Objects
**Problem**: Pooled objects retain state (colors, flags, cached data) from prior use, causing visual glitches when reused.
**Rule**: In `Wipe()`/`_DoReset()`, reset **every** custom property. Reset visual properties (restore original colors) before clearing the cached values needed to restore them. Add a comment near every new field reminding future devs to reset it.

### Track Active Pooled Frames for Incremental UI Updates
**Problem**: Pools only store inactive objects. Without a registry of active objects, lightweight visual refreshes (e.g., recoloring item level text on a setting change) require expensive full redraws.
**Solution**: Maintain an `activeItems` weak-key table on the module:
```lua
self.activeItems = setmetatable({}, { __mode = "k" })
-- On Acquire: self.activeItems[item] = true
-- On Release: self.activeItems[item] = nil
-- On setting change: iterate self.activeItems and update visuals
```

## Use Discrete Color Tiers to Avoid Unwanted Midpoint Hues
**Problem**: Smooth blending between distant hues (e.g., blue→orange) produces unexpected intermediate colors (gray/green) at the midpoint.
**Solution**: Compute breakpoints (low/mid/high/max) and pick the tier color directly — no interpolation between tiers.

## WoW UI Parent Frame Pattern & Blizzard Mixin Contracts

### Parent-less Frames Trigger Nil Pointer Crashes in Blizzard Mixins
**Problem**: Parentless frames (e.g. `CreateFrame(type, name, nil, template)`) will crash if Blizzard's native initialization mixin calls `self:GetParent():SomeMethod()` (such as `self:GetParent():IsCombinedBagContainer()` inside `ContainerFrameItemButtonMixin:Initialize`).
**Solution**: Always ensure that secure or template frames have a valid, unique parent frame on creation.

### One Unique Parent Frame Per Item Button
**Problem**: If multiple item buttons share the same parent frame, layout engines that position the parent frame (e.g. setting `item.frame:SetPoint(...)`) will stack all elements on top of each other and hide/wipe them together.
**Solution**: Create a dedicated, unique unsecure parent frame per physical item button, configure it with the correct ID/attributes, and implement fallback methods (like `IsCombinedBagContainer()`) natively on that parent frame to safely bypass Blizzard's native checks without secure attribute taint.

## Shared Static Frames: Claim, Then Sweep

**Problem**: Physical item buttons are static per slot key (`itemFrame.buttonsBySlotkey`) and are shared by several renderers in one draw pass (global Recent Items / Free Space sections plus every tab view). Renderer A acquired button `0_1` (e.g. as the Free Space representative), then renderer B's `Wipe` released the *same* button because B had drawn an item in `0_1` on the previous pass. `item:Release` hides and unparents the frame, so the button A just drew silently vanished ("free space slots disappear when something is put in the bank").

**Why**: Each renderer only knows about its own previous cells. A wipe interleaved with another renderer's acquisition can never tell whether the button it releases has already been re-claimed.

**Solution**: Never release a shared button while renderers are still drawing. `bagProto:Draw` releases nothing up front: every renderer records the buttons it draws in the pass's claim table, and after every renderer has run, `FinishDrawPass` releases only the buttons the previous pass drew that nobody claimed. (An earlier fix released every owner before any renderer ran; it was correct but hid, reset and re-showed every displayed button on every redraw, running Blizzard's OnHide/OnShow handlers each time.) Contract: `.claude/rules/layout-rendering.md` §1.

**Diagnostic**: A section that is populated (`section:HasItem(button)` is true) but whose button frame is hidden / has no parent → something released it mid-pass; only `FinishDrawPass` and the teardown paths (`bag:Wipe`, `DeleteTabView`) may release buttons.

**Related Files**: `frames/bag.lua` (`Draw`), `views/gridview.lua`, `views/bagview.lua`, `frames/item.lua` (`Wipe`/`ClearItem`).

## Close-Time Work Belongs in the Frame's Own OnHide
`behavior:OnHide` only runs when BetterBags closes the bag itself (toggle, close button). ESC hides the frame directly (`UISpecialFrames`), so anything that must happen whenever the bag closes (expiring Recent Items, the refresh that collapses held gaps) hooks the frame's `OnHide` instead (`bagProto:WatchForClose`). `OnHide` also fires when only a parent hid (Alt+Z hides `UIParent`) while the frame's own shown flag stays true, so check `frame:IsShown()` before treating it as a close. Contract: `.claude/rules/recent-items.md` §3.

## Classic Item Buttons: Blizzard's SetItemButtonQuality Always Hides The Border

**Problem**: Rarity borders were missing on Classic/Era/MoP while retail was fine, even though both call the global `SetItemButtonQuality`.

**Why**: In `Blizzard_ItemButton/Classic/ItemButtonTemplate.lua` (classic_era and classic branches) the quality-color block is commented out and the function ends with `button.IconBorder:Hide()`. The retail implementation (`Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua`) colors and shows the border via `ColorManager`.

**Solution**: After `SetItemButtonQuality`, non-retail clients call `itemProto:DrawClassicQualityBorder(decoration, quality)` which applies `const.ITEM_QUALITY_COLOR[quality]` and shows `IconBorder` (both for items and for free slots, which use the bag's quality). Never "fix" this by editing the mock: `spec/frames/item_classic_spec.lua` carries a source-faithful Classic mock of `SetItemButtonQuality`.

## Behavior OnCreate Overrides Must Create Every Kind's Sub-Frames

**Problem**: After the UI unification (#1044), UI that the legacy `frames/classic|era/bag.lua` built inline for *both* bags (search, bag-slots panel, currency, theme config) went missing on Classic, first on the backpack (#1089) and then on the bank ("Show Bags" absent from the bank menu).

**Why**: The unified `frames/bag.lua` delegates sub-frame creation to `behavior:OnCreate`, and the Classic/Era overrides in `bags/classic/` and `bags/era/` replace the retail `OnCreate` entirely. Anything a retail `OnCreate` creates, or that the legacy frame created for that kind, must be re-created in each override. Menu entries such as "Show Bags" are gated on the sub-frame existing (`bag.slots`), so a missing frame silently removes the menu item. There is no error.

**Solution**: When auditing a flavor, compare each `bags/<flavor>/*.lua` `OnCreate` against the pre-#1044 `frames/<flavor>/bag.lua` (`git show aa6eeeb^:frames/classic/bag.lua`) for **both** kinds. Also check that per-kind state the shared code assumes (e.g. retail-only `showBankTabs`, or the retail one-tab `SECTION_ALL_BAGS` bank filter) is gated on `addon.isRetail` rather than on `bag.kind` alone.

## Filled Backdrops Belong on the Panel Frame, Not a Sibling of the Content

**Problem**: On WoW: Forever the "Show Bags" slot buttons looked sunk under a dark film. The panel's `TooltipBorderedFrameTemplate` backdrop (90% black centre) had been created as a child "decoration" frame of the panel, a sibling of the slot grid.

**Why**: A child frame gets its parent's level + 1, so the decoration and the grid shared a frame level. The grid is a `WowScrollBox` with `clipChildren="true"`, whose descendants render as a group at the scroll box's level, so the buttons' own higher levels don't lift them above a same-level sibling. Which of two same-level siblings draws on top is not something to rely on. Since 7.0.3 `SetParent` does not re-level a frame either (warcraft.wiki.gg "Frame Strata").

**Solution**: Put a filled backdrop where it is guaranteed to be below the content: on the panel frame itself (inherit the template in its `CreateFrame`, or `SetBackdrop` on a `BackdropTemplate` frame), or on a frame pinned to a lower level (Blizzard's `DefaultPanelFlatTemplate` puts its `Bg` frame at `frameLevel="0"`). A sibling decoration frame is only safe when everything it draws at that level is border art. See camelot-forever.md §5.

## Unified Global ScrollBox Architecture (Zero-Reparenting Secure Frame Design)

**Problem**: WoW secure item buttons and empty slot buttons are bound to unique physical slot keys and cannot be reparented or dynamically moved between views during active combat without causing fatal "Action blocked" taint errors. Storing scrollboxes inside individual tab views requires secure buttons to be reparented on tab switches.
**Solution**: Decouple the scrolling container from individual tab views.
1. Implement exactly **one scroll box** per bag window: the `Scrollbox` drawable (`render/scrollbox.lua`, a `WowScrollBox` with a `MinimalScrollBar`), the content of the bag's `Window`.
2. Statically stack three containers vertically on the scroll box's child, the bag's canvas (`frames/bagcanvas.lua`): `headerContainer` (Recent Items), `tabContainer` (active Tab View), and `footerContainer` (Free Space).
3. Tab views become perfectly dumb and non-scrollable, rendering their layout grids directly into `tabContainer` via `grid:Create(parent, false)` and `SetAllPoints(parent)`.
4. Switch tabs by simply toggling visibility of the layout grids in `tabContainer` with zero secure reparenting or combat taint.
**Key Files**: `frames/bag.lua`, `frames/bagcanvas.lua`, `render/scrollbox.lua`, `window/window.lua`, `frames/grid.lua`, `views/views.lua`.

## Form Sliders Save Only User Input
**Problem**: WoW fires a Slider's `OnValueChanged(self, value, userInput)` whenever its value changes, including when code calls `SetValue` (`userInput` false). A form that sets each slider from its stored setting at build time and on reload, and saves in `OnValueChanged`, writes every setting back and fires every setting's side effect (refreshes) at every login.
**Solution**: save only when `userInput` is true; paths that move the slider for the user from code (a typed number box) call the setter themselves, and only when the value changed. Keep spec mocks faithful: `SetValue` must fire `OnValueChanged` with `userInput` false, or the bug is invisible in tests. See `.claude/rules/refresh-scheduler.md` §9.

## Windows and Elements Made on First Use Are Themed at Registration
**Problem**: a theme is applied at startup, to the windows and elements registered so far. A window built later on first use (the profiler's Settings form, the "Create New Bank Tab" group dialog) used to stay undecorated until the next theme change: no background and no close button.
**Solution**: `Sonata:RegisterWindow` / `RegisterElement` style what registers at once when a theme has already been applied; otherwise the first `ApplyTheme` does. Every window is a `Window` (`window/window.lua`), which registers itself. Coverage: `spec/sonata/engine_spec.lua` ("styles windows and elements registered after a theme was applied at once").
**Consequence**: a window's `OnDecorated` can run inside `window:Create`, before its owner made anything it places, and so can every option the styling reads (in the window size mode it sets the resize bounds from the minimums). An `OnDecorated` that places parts must do nothing while they do not exist, and the owner places them once made; an option must read only what exists before the window (a constant, a setting), not what the owner builds after it. The classic bags made by a design switch (next.md §11f) crashed on this; at login it never shows, because Sonata applies the theme after the bags exist. Test code that matters only once the addon is past login (switches, first use) on the whole addon (test-harness.md §5).

## Never Hard-Code a Font File
**Problem**: Blizzard's fonts are font families with one file per alphabet (`Blizzard_Fonts_Shared/Mainline/Fonts.xml`: roman `FRIZQT__.TTF`, russian `FRIZQT___CYR.TTF`, korean `2002.TTF`, Chinese `ARKai_T.ttf` / `blei00d.TTF`). `FontString:SetFont("Fonts\\FRIZQT__.TTF", ...)` replaces the family with the roman file, so Cyrillic, Korean and Chinese text loses its glyphs (issue #175, the category pane's item rows).
**Solution**: pass the locale's file from the globals Blizzard sets per locale on every client (`Blizzard_Fonts_Shared/Shared/GameFonts.xml`: `STANDARD_TEXT_FONT`, `UNIT_NAME_FONT`, `DAMAGE_TEXT_FONT`), or use a font object. Coverage: `spec/itemrow_spec.lua` ("draws the item name in the client's locale font").

## Moving a Parent Moves Its Children, and Below 0 Is the Top
**Problem**: when a frame's level changes, every descendant shifts by the same amount, and one that would go below 0 is set to 10000 (warcraft.wiki.gg "Frame Strata"). A template child pinned low in XML (`DefaultPanelFlatTemplate`'s `Bg`, `frameLevel="0"`) is therefore thrown above everything when its parent is lowered, covering the window it should sit behind.
**Solution**: record each child's level relative to its parent when the parent is created, and after moving the parent put every child back at that offset, clamped at 0 (`sonata/decoration.lua` `applyTemplate`). Mocks must model the shift and the wrap (`spec/helpers/wow_mocks.lua` `SetFrameLevel`), or the bug cannot fail a test. See `.claude/rules/sonata.md` §3.

## SetAtlas Brings Its Own Coordinates, Tiling and Slicing
**Problem**: `Texture:SetAtlas` sets the atlas's texture coordinates, tiling and nine-slice data along with the file. Resetting a reused texture *after* `SetAtlas` (`SetTexCoord(0, 1, 0, 1)`, `ClearTextureSlice`, `SetHorizTile(false)`) shows the whole atlas sheet, stretches nine-slice atlases and stops tiling ones.
**Solution**: reset first, draw the file, atlas or color second, apply only what the spec sets explicitly last (`sonata/apply.lua` `apply:Texture`). Likewise `SetNormalTexture`-style setters take no nil asset: a state that only tints changes the region the button already has.

## Pre-Made Blizzard Buttons Must Be Hidden Until Used
**Problem**: Blizzard's templates do work when a frame becomes visible: `ContainerFrameItemButtonTemplate` subscribes to `ENCHANT_SPELL_COMPLETED` in its `OnShow` and to the item context callback in its intrinsic `PostOnShow`, and `ContainerFrameItemButtonMixin:Initialize` shows the button itself. A frame with no parent that is shown counts as visible even when it has no anchor and never appears on screen. BetterBags made every slot at login under a shown, unparented holder, so about 2,700 item buttons were visible to the game with the bags closed; Evokers casting Dream Breath in raids and Mythic+ stuttered, and the profiler saw nothing, because the work ran in Blizzard's handlers on our frames.
**Solution**: create the holder hidden, before the template frames inside it (`itemFrame:_DoCreate`), so only the draw pass ever shows a button and the bag window's visibility hides it again (`.claude/rules/item-drawing.md` §7, "Hidden until drawn"). Any pool of pre-made frames from a Blizzard template belongs under a hidden parent until it is used. When BetterBags is suspected but measures near zero, look for Blizzard template code running on frames BetterBags created.

## Theme-Colored Text: Font Objects Made Once, Never Changed
**Problem**: text that picks a client font and sets its own color (`CreateFontString(nil, "OVERLAY", "GameFontNormal")` then `SetTextColor(1, 1, 1)`) looks the same under every theme: on a light theme (Parchment) the settings text was white on parchment. The first fix restyled shared font objects in place on each theme switch, counting on a font object passing its changes to its text; a font object changed while text used it left that text out of step once the text switched font objects (hovering a settings entry changed its size until a theme switch).
**Solution**: draw such text with a Sonata text role (`sonata:CreateText(parent, "Body")`, `sonata:SetTextRole(text, "NavActive")`, `sonata:SetButtonTextRole(button, "Money")`). A font object is made per theme and role, styled once as a copy of its client font (`CreateFont` then `CopyFontObject`, never `Font:SetFontObject`), and never changed; a theme switch or a rescale of the client's fonts (`EventRegistry` `TextSizeManager.OnTextScaleUpdated`) makes new ones and Sonata moves every recorded text to them. The text never calls `SetTextColor`/`SetShadowColor`/`SetShadowOffset` itself; states switch roles. `spec/sonata/text_usage_spec.lua` enforces it for the files that draw window and bag text. See `.claude/rules/sonata.md` §3c.

## A Button's Font String Keeps Its Width When Its Font Changes
**Problem**: a button's own font string (`button:SetFontString(fs)`, one anchor, no width) keeps the width it was sized to when its font object changes, and two fonts that look identical can measure differently: a shadow offset of 1 makes a string about 0.8 wider than a glow at offset 0. A settings navigation entry sized while hovered or selected (glow) wrapped onto a clipped second line in its normal role (shadow): "Import/" for "Import/Export" (render recording on WoW: Forever: width 110.0, string 110.8). Blizzard's reset, width 0 then the same text (`QuestLogTitleButton_Resize`), refreshed `GetStringWidth()` but not the width.
**Solution**: after every font change (and when the entry is made), set the width to 0, set the button's text again, then set the width explicitly from `GetStringWidth()`, rounded up with a pixel to spare, as Blizzard sizes a tab after changing its font (`CRFRaidMarkersMixin:SetTab`). Sonata calls back a text's watcher after each font change (`sonata:WatchTextFont(fs, fn)`: role switches, themes, client rescales); `forms/layouts/stacked.lua` `fitNavText` uses it. To see such a bug, record rendering: every Sonata font change is a `text` entry with its width, string width and lines. See `.claude/rules/sonata.md` §3c.

## SetPoint Takes Both Offsets or Neither
**Problem**: `frame:SetPoint(point, relativeTo, relativePoint, x)` with a nil y offset: the client drops the x offset (a render recording showed a scroll box child anchored 14 in sitting at 0). Both offsets are required (`SimpleScriptRegionResizingAPIDocumentation`), Blizzard's UI never passes one alone, and the spec frame mock used to accept it.
**Solution**: pass both, 0 for the one you do not need. `drawableProto:SetPoint` does it for drawables, and the frame mock now errors on one offset without the other, so a call site that breaks the contract fails its specs. See `.claude/rules/render-pipeline.md` §4a.

## Measure Then Arrange
**Problem**: a layout that positions frames while it measures cannot answer "how wide would this be?", so callers re-derive geometry with formulas that drift from what the layout does (snapped bag windows ended 5 to 111 px wider than their content).
**Solution**: compute the layout as data first (`Flow:Pack`, `grid:Measure`, `section:Measure`, `view:Measure`, `canvas:Plan`), choose, then apply it (`Arrange`); one function places every cell (`gridProto:PlaceCell`), which is where an animation between two layouts would hook in. See `.claude/rules/render-pipeline.md` §4b.

## Sizes Read From the Client Carry Float Error at a UI Scale
**Problem**: at a UI scale (0.65 in the capture) `frame:GetWidth()` can return a hair under the size that was set (a window set to 466 read back just under it once it was anchored by its center). Code that compares such a value with whole-number layouts makes the wrong choice at exactly the fitting width: the bag rejected the layout it had just snapped to.
**Solution**: round sizes read from the client before comparing them exactly. The window rounds the size it hands its content to a hundredth of a unit (`withoutFloatError`, `window/window.lua`), far below a pixel. See `.claude/rules/window.md` §3b.

## Animate Layout Changes by Placing Parents Before Children
**Problem**: animating a reshuffle (rows, sections, items) needs each frame's old place in the coordinate space of its new parent. Placing children before their parents meant an item moving into a section that had just appeared found that section unanchored, and could only jump.
**Solution**: every placement goes through one function (`Motion:Place`, `render/motion.lua`) that anchors offsets from the parent, so each level animates on its own and they compose. Place parents first (containers, then sections, then items): when a child is placed its parent is already anchored where it visually starts (its old spot if moving, its final spot if new). Work out old positions from your own anchors (TOPLEFT to TOPLEFT, plus explicit links where Blizzard positions a frame), not from screen rectangles. See `.claude/rules/render-pipeline.md` §4c.

## Keep the Frame Mock's Anchors Faithful
**Problem**: the spec frame mock's `SetAllPoints` set no points and `SetPoint` appended a second point of the same name, unlike the client. Code that walks anchors (`GetPoint(1)`) behaved differently in specs than in game.
**Solution**: `SetAllPoints` sets TOPLEFT and BOTTOMRIGHT, and `SetPoint` replaces a point already set (warcraft.wiki.gg). When a test relied on the old mock, fix the test, not the mock.

## Set a Font String's Font Before Its Text
**Problem**: `FontString:SetText()` on a font string created without a template and with no font yet raises `FontString:SetText(): Font not set` in the client. A BetterBags Next section title set its text, then its font, and errored on the first open in game while every spec passed.
**Solution**: give a font string its font (`SetFontObject`, `SetFont`, or a template in `CreateFontString`) before any `SetText`. The spec frame mock raises the client's error, so tests catch the order; spec fixtures that stand in for XML templates must give their font strings the template's font.

## Dragging a Real Frame Across Clipping Parents
**Problem**: a section inside a scroll box is clipped by it and draws in its panel's strata, so it can neither leave its window nor show above the other bag while dragged; and the frame under the cursor hides what is below it from `OnEnter`.
**Solution**: reparent the dragged frame to a full-screen, mouse-disabled layer in the `TOOLTIP` strata (its children follow its strata and keep their levels relative to it), and find drop targets by position every frame with `IsMouseOver`, which is geometric. Put it back with the parent's strata and level. BetterBags Next (next/drag.lua, next.md §7).

## Measure a Scaled Frame From Your Own State
**Problem**: the client reports a frame's edges (`GetLeft`, `GetTop`) in the frame's own scale. A dragged section shrunk to 94% reads back about 6% off, so an animation starting from its read-back position starts from the wrong place.
**Solution**: keep the position you gave it (the cursor and the grabbed point) and work from that; read edges only from frames at scale 1 under `UIParent` (the canvas, tabs, scroll area).

## A Drop Is the Release's Hardware Event
**Problem**: moving items (`C_Container.UseContainerItem`) needs a hardware event; a drop detected in `OnUpdate` is not one, and the client can miss a release when another window takes the mouse.
**Solution**: drop in the dragged frame's `OnDragStop`; also check `IsMouseButtonDown` each frame (as Blizzard's chat frame drag does) and, without the release, finish the drag without moving items.

## Never Give an Edit Box a Font Object Read Back From It
**Problem**: `EditBox:GetFontObject()` on an `InputBoxTemplate` box returns an unnamed font object of the box's own (its XML `<FontString inherits="ChatFontNormal"/>`), not the font it was given; `box:SetFontObject(thatObject)` makes the font inherit from itself and crashes the client with STACK_OVERFLOW (issue #1152, the ElvUI theme at login).
**Solution**: to restore an edit box, record its look by value (`GetFont`, `GetTextColor`, `GetShadowColor`, `GetShadowOffset`, `GetJustifyH`) and set it back with `SetFont` and the setters, and only touch a box a style changed. Font strings are safe to round-trip (Blizzard does it in `MenuTemplates.lua`); edit boxes are not (Blizzard never does). See sonata.md §3a.

## A Released Widget Drag Lands on the Frame Under the Cursor
**Problem**: a frame dragged with `RegisterForDrag`/`OnDragStart` that follows the cursor carries its children under the cursor; on release the client fires `OnReceiveDrag` on the topmost mouse-enabled frame there, also for widget drags. Over a `ContainerFrameItemButton` that is a left click, which picks the item up.
**Solution**: put an invisible, mouse-enabled cover over the dragged frame (a margin past its edges, above every frame in it) for the length of the drag; `OnDragStop` still goes to the frame being dragged. Never lower the dragged frame's level to lift it: descendants pushed below 0 jump to 10000 and nothing can be above them. BetterBags Next (next/drag.lua, next.md §7).

## Fade a Gradient Texture Through Its Colors, Not SetAlpha
**Problem**: BetterBags Next's feathers are gradient textures (`SetColorTexture(1, 1, 1, 1)` then `SetGradient` from the body's color to nothing). Switching between full and small faded them with `Texture:SetAlpha`, and in game they did not fade at all, while textures colored with `SetVertexColor` (the small border) faded with the same call. The spec mock honored `SetAlpha`, so the specs passed. Measured: only the player's report; inferred from the docs: a gradient is the texture's vertex colors (warcraft.wiki.gg TextureBase:SetGradient, "see Region:SetVertexColor"), `SetAlpha` and `SetVertexColor` share the same Alpha secret aspect (SimpleRegionAPIDocumentation), and Blizzard puts a gradient's alpha in its colors (`Blizzard_NamePlates.lua`, `CreateColor(r, g, b, a)`).
**Solution**: fade a gradient by setting it again with the alpha in its colors each frame (Next's `paintFeathers`, as `paintWash` always did), and leave its `SetAlpha` alone. In specs, check the gradient's colors (`texture._gradient`), not `GetAlpha`. next.md §14d.

## A Texture's Alpha Is Its Vertex Color's Alpha
**Problem**: for a texture, `SetAlpha` and `SetVertexColor`'s alpha are one value, each replacing the other. Blizzard relies on it: `FCF_SetWindowAlpha` sets a chat window's alpha with `SetAlpha` and `FCF_GetChatWindowInfo` reads it back from `GetVertexColor` (`FloatingChatFrame.lua`). Treating them as separate (a theme alpha in the vertex color, a fade with `SetAlpha`; or coloring with `SetVertexColor` after `SetAlpha(0)`) showed in game as a border brighter than its theme after a fade, and a hover glow lit on open until hovered. The spec mock modeled them as separate until this was found.
**Solution**: set a texture's color first and its alpha last; restyling an animated texture keeps the alpha it shows (`GetAlpha` before, `SetAlpha` after); a texture with a theme alpha that also fades is faded through its vertex color alone. next-themes.md §10.

## A Template's Text Color Wins Over a Font Object
**Problem**: a font string with a color of its own (an XML `<Color>`, as `InputBoxInstructionsTemplate` gives its help text 0.35 gray, or an earlier `SetTextColor`) keeps it when given a font object, so drawing it with a theme's text role leaves it the template's color. Seen by reading Blizzard's `InputBoxTemplates.xml`, not in game.
**Solution**: for such text, set the role's color and shadow on the text too, from the role's font object (never one read back from the text: an edit box's `GetFontObject` returns its own), and again with every theme (`NextStyle:SetTemplateFont`, Sonata's `apply:Font`). Text that no template colors (`BagSearchBoxTemplate` sets no enabled color: its `enabledColor` KeyValues are commented out) needs only its font object. next-themes.md §4.

## Reflow a Panel Live While the Player Sizes It, With Its Layout Animations Off
**Problem**: BetterBags Next lays its content out through Motion, so every layout change glides. A small panel resized with a grip (`Frame:StartSizing`) changes size every frame; laying out again each frame with the glides on starts a new glide toward a target that moves again next frame, so the icons trail the edge instead of flowing with it, and a size change the panel makes itself (a size switch's glide) would lay out every frame for nothing.
**Solution**: lay out from the frame's own `OnSizeChanged` only while a grip sizes it (or an animated reset of its size runs), and turn the canvas's glides off for that time (`canvas:SetInstant`), on again once let go; save the size only when it changed by half a unit or more, so a click on the grip keeps a default size that follows the screen. next.md §14g.

## A Font String Given a Width Centers Its Text
**Problem**: a font string anchored by one corner and sized to its text looks left- or right-aligned whatever its justification. Give it a width (to cut it short, `SetWidth` with `SetWordWrap(false)`) and its text centers in that width, because `justifyH` defaults to `CENTER` (`Blizzard_SharedXML/UI.xsd`, for `Font` and `FontString`). BetterBags Next's small backpack title moved about 100 units right once small panels cut titles short; the bank's, already right-justified, did not move.
**Solution**: justify a font string toward the side it is anchored on whenever it may get a width, and set it again after anything that gives it a new font object. The spec mock answers `CENTER` for a font string never justified, as the client does. next.md §14g.

## A Scaled Frame's Edges and Offsets Are in Its Own Units
**Problem**: `GetLeft`, `GetTop`, `GetCenter` and `GetWidth` report a frame in its own units, and `SetPoint` offsets are in the units of the frame being anchored, so a frame under a scaled parent (BetterBags Next's small panels at their Bag Scale; the settings window scaled down to fit a small screen) reads and places at the wrong spot when its edges are compared with the cursor or with another frame's. BetterBags Next assumed every frame was at scale 1: a section drag's gap, its landing, a tab moved in its rail and the dock's flights all used raw edges.
**Solution**: keep places in UIParent's units and sizes in the frame's own; convert at the boundary, reading a frame on screen with `NextLift:ScaleOf` (`GetEffectiveScale()` over `UIParent`'s), `ScreenPoint` and `Center`, and dividing anchor offsets by the frame's scale. A frame lifted for a drag keeps its size on screen (`Pick` starts at its scale there) and lands at the scale of where it lands. next.md §14h.

## Whole UI Units Are Not Whole Screen Pixels
**Problem**: a UI unit is a whole screen pixel only when the screen is 768 pixels high at a UI scale of 1. At 65% in a 3396x1362 window it is 1.153 pixels, so frames and lines placed in whole units land between pixels, and the client snaps each texture to the grid on its own: a 1-unit edge drew one pixel thick, two, or not at all (the theme card that lost its top edge at 65% and its bottom edge at 70%). Anchoring by a middle point (`CENTER`, `LEFT`, `RIGHT`) puts a region between two pixels whenever the region it is anchored to is an odd number of pixels across, and anchoring after a text's far edge follows the client's fractional measure of the text.
**Solution**: round every length and offset to whole screen pixels on the grid of the region it is used in (`NextPixel`: one pixel is `PixelUtil.GetPixelToUIUnitFactor()` over the region's effective scale), anchor by corners from aligned regions, center by a corner offset with the odd pixel after (`pixel:Middle`, `pixel:Row`, `pixel:Center`), place what follows a text by the text's width or height rounded up, and lay everything out again when the grid changes (UI scale, window size, a frame's own scale). Check it with the spec layout resolver (`spec/helpers/layout.lua`, `PixelCheck`) on real screen sizes. next-pixel-perfect.md.

## A Docked Section Flies to Where Its Items Went
**Problem**: Every move waiting for the player waits in `NextDock`, and a "moved" answer flew the section
into the panel it waited in: right for a sale or a deposit (the items went there), wrong for a purchase,
whose section is the vendor's own items, going to the backpack.

**Rule**: Extend the dock, never build a second card: an offer may give `destination()`, the frame its
items went to; the section flies into its middle, or nowhere when it returns nil (that place is not
shown). The vendor's Shopping List gives the backpack's scroll area (profession-shopping-list.md §5).

## A Section Docked as It Is Bound Is Seated, Never Flown
**Problem**: The dock flies a section into its card from where it is on screen (`lift:ScreenPoint`). A
panel that keeps its sections while hidden (the vendor) reuses a section still anchored where its column
left it last time, so a section docked as the draw binds it flew in from that stale place. The spec frame
mock never showed it: it gives a frame a place on screen only when a test sets one (`_SetRect`).

**Rule**: A section docked before its first layout passes `atOnce` (`NextDockSpec`): seated at once,
whatever place it has. Test any flight decision with a rect, as the client gives every anchored frame one.

## Read Theme-Dependent Geometry When It Is Used, Never When Built
**Problem**: A closure made when a Next panel is built captured a value a theme decides (the title's join, from
`Pad`, `TitleInset` and now a side rail). A theme applied later moved the title but not the captured value: the
ribbon's sparkles started 40 pixels inside the body (next-themes.md §13).

**Rule**: Anything a theme can change is read where it is used (a `Spawn`, a layout pass), as `NextStyle`'s fields
are; capture only what never changes for the panel (its side).

## Copies of the Client's Fonts Go Stale When UI Addons Rewrite Them
**Problem**: A Next role that copies a client font (`Object`) copies it when the theme applies, at BetterBags'
load. UI addons rewrite the client's fonts later (GW2_UI at `PLAYER_LOGIN`), so the copy keeps Blizzard's font.

**Rule**: Record what each copy was taken from and check it once the game has started (`PLAYER_ENTERING_WORLD`):
`NextStyle:CopiesStale`, `SonataNext:WatchClientFonts` (next-themes.md §4). A copy is how a theme follows another
addon's fonts, its locale files and its player's settings, with no locale logic of its own.

## A Part That Took a Color Takes Art Too, Through One Check
**Problem**: BetterBags Next drew tabs, search boxes, section lines and other parts as colors or gradients only, so
a theme matching another UI's art (Guild Wars 2) could not draw them (next-themes.md §14).

**Rule**: A themed part accepts a fill that is either a color or a texture spec with a `Texture`/`Atlas`
(`NextStyle:IsArt`). Draw art with `NextStyle:Paint`; draw a color its own way, after resetting what art left (the
texture's coordinates, and a plain white texture under the color). Art for a panel is drawn for the backpack
(inner side on the left) and mirrored on panels on the left of the screen, as ornaments are.

## A Gradient and a Vertex Color Are the Same Four Corners
**Problem**: The frame mock kept a gradient after `SetVertexColor`, so a test could not see a texture keeping an
old gradient after switching to tinted art.

**Rule**: In the client both write the texture's four corner colors, the last call winning
(warcraft.wiki.gg Region:SetVertexColor; Blizzard's `MarchingAntsMixin` switches between them on one texture).
The mock's `SetVertexColor` clears `_gradient`. When moving a texture from a gradient to art, `Paint` (which tints)
is enough; from art to a gradient, set a white color texture first.

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


## A Theme Part Set to False Arrives as Nothing
**Problem**: A Next theme turns a part off with `false` (`Edge = false`, `Indicator = false`), and resolution removes a
table set to `false` (`SonataResolve.Merge`), so the widget reads `nil`. Seven places read such a part unguarded
(`I.Edge.Idle`, `N.Indicator.Width`, `C.Divider.Size`): the Plain theme, the first to turn those parts off, broke the
settings window on every client. A second form: a part hidden when styled but shown again later (`marker:SetShown(width
> 0)`, a divider's `Show()` after placing) draws anyway.

**Rule**: Read every theme part as possibly absent (`local E = I.Edge; ... E and E.Idle`), and every later `Show` of a
part checks the part is still on. `spec/next/shipped_themes_spec.lua` draws every Next window with every shipped theme
on every client; a new part, or a theme turning one off, is covered by it.

## Protected Restyles Hide Errors From Specs
**Problem**: `SonataNext:RestyleWidgets` styles each widget in a `pcall` and hands a failure to `geterrorhandler()`,
as the client would show it, and the specs' mock handler returns the error and drops it. A theme that broke a widget
passed every spec that applied it (the pixel spec applied Plain to the bags and checked their pixels, not errors).

**Rule**: A spec that applies themes captures the handler (`_G.geterrorhandler = function() return function(err)
table.insert(errors, tostring(err)) end end`) and asserts nothing was sent. It restyles only the widgets it made (its own
`sonataNext.widgets` table for the run): other spec files' widgets were made against their own stubs.

## A Branch of Blizzard's UI Source Holds Every Client's Files
**Problem**: Since the UIs were unified, each branch of `wow-ui-source` carries every game type's folders
(`Mainline\`, `Classic\`, `Vanilla\`, `Camelot\`), loaded only by their own client (`[AllowLoadGameType]`, `[Family]`,
`[Game]`), and a whole addon can be one game type's (the damage meter is `## AllowLoadGameType: standard`, its art in an
unflavored file). Grepping a branch for an atlas proved nothing: retail's menu art passed as present on Classic.

**Rule**: To know what a client has, read the files its TOCs load (`spec/helpers/ui_source.lua`), and search those.
Read a template from the loaded file, not the first match in the branch. Use `origin/<branch>`: a local branch can lag
(the local `live` was a build behind).

## Copying Blizzard's Art Names Is Not Copying Its Look
**Problem**: The Plain theme's first version named only Blizzard's atlases, files and fonts, each checked to exist on
every client, yet in game the settings window was wrong in nearly every way: the list's header art (199 x 144) stretched
across a sidebar that started at the window's outer edge, its fill and art over the border, tabs floating with nothing
under them (their art is a hollow outline meant to sit on `Options_InnerFrame`'s edge), two columns of cards where
Blizzard draws one list. The specs had no atlas sizes, so art drawn at its atlas's size collapsed to nothing in them,
and nothing compared a placement with Blizzard's.

**Rule**: To match a Blizzard window, take its layout from its template (every anchor and size), its art's sizes from
the client's own atlas table (`spec/fixtures/atlas_sizes.lua`, `tools/atlas_sizes/generate.py`), and test placements
against those numbers. Look at the art before deciding where it goes (decode it from the client's files: hollow tab
outlines, a header bar with lines down its column), and look at the result drawn with the client's textures before it
ships; a layout dump through the specs' resolver (`spec/helpers/layout.lua`) gives exact rects to draw from.

## A Theme Key Set to False Is Nil By the Time Code Reads It
**Problem**: Plain sets `Brand = false`; resolution removes a table set to `false`, so the window read `nil`, and
`SetShown(B ~= false)` showed the brand. A window built before its theme applies (the settings window) also read
`Brand.Font` and `Header.DescriptionFont` at build time and failed under Plain.

**Rule**: Test a removable part as a table (`local on = B and true or false`), never against `false`; and never read a
removable part's keys at build time: give the region a role there and set the theme's at style time.

## A Control's Art Covers What Takes Its Clicks, and Each Control Has Its Own Look
**Problem**: The Plain theme's item boxes were white and its Search Rule box drew a 20-pixel strip in a box several times
taller. Both borrowed the single-line input's fill: Plain's is three pieces of the search border at their own thickness,
which on a plain texture (the item grid's) paints the whole box white, and on the text area covers a strip of what takes
its clicks.

**Rule**: A control draws its box from its own theme keys (`Controls.ItemGrid`, `Controls.TextArea`), falling back to
another control's only when the theme gives none, and its art covers exactly the area that takes its clicks (art at a
fixed thickness belongs to a control that is that tall). Blizzard has a frame for each: the single-line field's border,
the multi-line edit box's frame (InputScrollFrameTemplate), the inset (InsetFrameTemplate).

## Matching Default's Scale Means Matching Default's Numbers
**Problem**: Plain copied Blizzard's fonts and sizes (37-pixel item buttons, 10 to 12 point text), which made it look
smaller than the theme it sits beside; asked: "scale for Plain should be the same as our Default".

**Rule**: A skin theme takes Default's sizes (layout, fonts, controls) and replaces only the look; keep a Blizzard size
only where Blizzard's art fixes it (a title bar, a check box, a close button) or where Blizzard's is larger. `Copy` font
roles take the role's `Size` for exactly this (`Size = false` keeps the client's).

## A New Parent Changes a Frame's Level
**Problem**: Plain moves the bag's header buttons under a hidden frame and Default moves them back; the code assumed a
frame keeps its level across `SetParent` (its comment cited 7.0.3's "frame levels no longer change automatically"),
and the buttons came back at one above the panel, under a small panel's mover, which took their clicks. The spec mock
kept levels across `SetParent`, so a test that checked the level passed.

**Rule**: `SetParent` changes a frame's level (Blizzard's LFDFrame.lua: "Setting a new parent changes the frame level,
so we need to move it back"). Read the level before `SetParent` and set it after, as Blizzard's
`FrameUtil.SetParentMaintainRenderLayering` does; a "never lower it" check compares with the level read before. The
mock now gives a reparented frame one above its new parent.
