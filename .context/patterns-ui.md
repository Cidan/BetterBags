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
**Related Files**: `config/categorypane.lua:354`, `bags/backpack.lua:508, 534`

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
