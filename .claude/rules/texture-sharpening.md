# Textures Drawn Without the Client's Sharpening (`render/texels.lua`, every bag)

Every texture BetterBags draws in a bag window, in both designs, is drawn without the client's texture sharpening:
`SetSnapToPixelGrid(false)` and `SetTexelSnappingBias(0)` (TextureBase, SimpleTextureBaseAPIDocumentation, on every
client). That covers item buttons, Masque's skins on them, vendor cards, guild bank buttons, bag and tab buttons, and
the windows' own art.

## 1. Why

Reported, with Masque off: "you can see the shadowing changes just by slight resize of the window up and down (no
icons shifted their actual position)". Measured on retail 12.1.5 (3396x1362 at a UI scale of 65%, a small BetterBags
Next backpack at Bag Scale 150%):
- **A sizing recording** (render-recorder.md §2) listed every region in the panel at the same whole pixels at all 337
  steps, icon art and borders included (`t 825.000 b 749.000`). Only the scroll box's clip edge moved.
- **A 60 fps video of the same drag**, diffed frame by frame, changed only along horizontal edges inside the icons:
  their top borders and the horizontal lines of their art. The section title, its line and every vertical edge never
  changed. A pixel column through an icon's top border showed the bright band's centre moving by up to 0.3 pixel in
  the first row and 0.45 in the second, the rows not in step, while the quad's edge stayed on the same pixel row.
- **The client re-picks texels.** Blizzard says what the defaults do (a Blizzard developer on warcraft.wiki.gg,
  TextureBase:SetTexelSnappingBias): "the texture's verts will be rounded to the nearest pixel during the rendering
  phase, texelSnappingBias is a range from 0-1, anything >0 implies snapToPixelGrid; the stronger the
  texelSnappingBias the more aggressive the renderer will be in selecting a texel instead of blending texels, the end
  result is a 'sharpening' sort of effect". So the client picked the texels inside each icon's unmoving quad
  differently as the window's height changed.
- **The fix, tested in game.** A `/run` that turned both off on every texture under the backpack stopped it ("holy
  shit that run command fixed it!").
- **Blizzard and ElvUI do the same.** Blizzard turns both off on its own textures that resize (`PlayerFrame.lua`,
  `TargetFrame.lua`, `AlternatePowerBarBase.lua`, `NineSliceUtil.DisableSharpening`). ElvUI turns both off on every
  texture it touches (`Toolkit.lua`, `DisablePixelSnap`).
- **Asked:** "i'm fine if we do this on classic bags too -- literally all bags", and "be sure to also do it for
  masque skins".

BetterBags Next places everything on whole pixels itself (next-pixel-perfect.md), so the client's rounding of
corners adds nothing there.

## 2. How (`Texels`)

- **`Texels:Unsharpen(root)`** walks root and everything under it, shown or not (a hover highlight shows later with no
  draw), and sets both on every `Texture`, `MaskTexture` and `Line`. Font strings are left alone: they have no such
  setting. It sets them every time it walks, because whether a new file or atlas brings the sharpening back is not
  known. It returns how many it set, for profiler traces.
- **`Texels:DrawsItself(frame)`** marks a frame whose own draws unsharpen it. A window's walk leaves it out, unless it
  is the root. Bag item buttons are marked this way (their holder, `item.frame`, in `itemFrame:_DoCreate`): a bag of
  hundreds of buttons is then walked by the buttons that changed, never all of them on every draw.

Where it runs:

| What | When | Where |
|---|---|---|
| A bag item button (both designs) | Each full draw (`SetItemFromData`, `SetFreeSlots`), after `item/Updated` | `frames/item.lua` |
| A Next panel (backpack, bank, guild bank; its sections, tabs, header, footer, guild bank buttons) | After each `Draw`'s render | `next/panel.lua` |
| The vendor (and its cards) | After each `Draw`'s render | `next/vendor.lua` |
| A classic bag window (chrome, sections, tabs, the theme's art) | After each `Draw`'s render | `frames/bag.lua` |
| The classic slots panels (bag buttons, bank tab buttons) | After each `Draw` | `frames/bagslots.lua`, `frames/bankslots.lua` |
| A Masque skin | After every skin the integration asks for (`AddButton`, `ReSkin`: item, vendor, guild bank and bag buttons; a Next theme applied) and when Masque calls back after re-skinning a group for an option changed (`OnSkinChange`: a skin chosen, the group turned off or on, a reset; Masque 12.1.0 `Core/Group.lua` `__FireCB`, after its `ReSkin`) | `integrations/masque.lua` |

- **After the render, after `item/Updated`.** The draw passes run after the render, because the render styles what it
  lays out (the item fitter, vendor cards: `NextVendorButton:Fit`, which Masque re-skins on `vendor/Updated`). The item
  button's pass runs after `item/Updated`, because Masque makes a skin's textures as it skins a button (its Shadow,
  Gloss and others, `Button:CreateTexture()`).
- **Guild bank buttons and vendor cards are not marked.** Guild bank buttons have no draw record, so every draw of the
  panel draws all of them again: walking them in the panel's pass costs the same as walking each in its own draw.
  Vendor cards are few.
- **Item buttons are shared by both designs.** There is nothing to undo on a design switch: both draw without the
  sharpening.

## 3. Not done, not known

- **Outside the bags:** the settings window, dialogs, menus and the debug window are not walked. They do not resize
  as a player drags. The settings window slides as it opens, and its textures settle on whole pixels when it stops.
- **Not measured in game:** the cost of the walks. A Next backpack's pass after a draw walks the panel without its item
  buttons. A full item draw walks one button, about 40 regions. Capture a draw with the profiler (`Texels.Unsharpen`
  returns how many it set).
- **Not seen in game yet:** whether icon art drawn at a size it was not made for (64 texels at 76 pixels) looks softer
  without sharpening. The `/run` test found the shading gone and said nothing of softness.
- **Not confirmed:** whether `SetTexture` or `SetAtlas` bring the sharpening back, which is why every walk sets both
  again. Blizzard's own code sets the bias before `SetAtlas` and never again (`ContainerFrameCurrencyBorderMixin:
  SetupPiece`), so `SetAtlas` likely keeps it. A sizing recording now shows each texture's snapping and bias
  (`PixelAudit:Regions`).

## 5. A clipping frame between two pixels (fixed)

Reported after §2: "when i drag to resize a window, no shimmer. but let's say i drag a bag really wide and let go, when
it snaps back, the icons shimmer ... unclear ... if it's the texture shimmer, or actual movement". Measured:
- **A 60 fps video of the release** (1378x450, the Consumable row of 13 icons): each icon's horizontal shift, matched
  frame by frame against a frame before the release, was 0.00 for the first icon and grew with distance from the
  panel's left edge, up to 0.34 pixel at the thirteenth. Its sign flipped from frame to frame. It died out as the snap
  settled, every icon back where it was. That is a stretch from the left edge, not icons moving apart: the layout keeps
  the gaps for a column count (`MeasureSection`, from `PerRow(layoutWidth)`), and the snap keeps its layout width.
  With the sharpening off, the stretch shows as blending across two pixels.
- **A sizing recording of a snap** (render-recorder.md §2) showed the client sizes a panel in whole pixels while a grip
  is dragged: every `resized` step had the scroll box's edges on whole pixels (`r 2985.000`, `b 337.000`). Every
  `snap` step had its right edge between two pixels (`r 3025.847`, `3004.432`, `2988.494`, ...) until it came to
  rest (`r 2985.000`). The snap set the frame's width from its bounce each frame, unrounded.
- **Inferred, not seen in Blizzard's code:** the client draws what a clipping frame holds stretched across its rect
  when that rect's edge is between two pixels. The scroll box clips (`ScrollBoxBaseTemplate`, `clipChildren="true"`).
  The shimmer appeared exactly while its edge was fractional and never while it was whole: a grip dragged, at rest.

The fix: the snap (`snapTo`) and Shift-click's glide back to the default size (`ResetSize`) size the panel in whole
pixels of its grid every frame (`pixel:LengthIn(self:PixelUnit(), ...)`). The reset glide also places the corner it
moves on whole pixels: the corner across from the grip, and the moving side from the size. The bounce then steps a
pixel at a time, as a grip dragged does. Not changed: the switch between full and small (`Morph`), which changes the
panel's scale as it glides, so what it holds is drawn at another scale through it anyway.

Coverage: `spec/next/small_spec.lua` ("sizes itself in whole pixels at every step of its snap, as a grip dragged
does"; "glides in whole pixels, its far corner still on a whole pixel, from either grip"; "glides its corner in whole
pixels when the screen's edge moves it"), on 3396x1362. Six mutations, each caught. Two first survived: rounding the
top, and the right grip's left edge, which only glide when the screen's edge puts the panel back. They led to the
last test.

## 4. Coverage

- `spec/render/texels_spec.lua`: textures, lines and masks, shown and hidden, deep and under hidden frames; text left
  alone; frames that draw themselves left out, unless they are the root; set again every time.
- `spec/frames/item_spec.lua` ("drawing without the client's sharpening"): an item's and a free slot's full draw, with
  a texture made by an `item/Updated` handler; the holder left out of its window's walk.
- `spec/next/bag_spec.lua` (a panel's footer line, spark, a section's and the header's art after a draw).
- `spec/next/vendor_spec.lua` (a card's icon and a texture on its button).
- `spec/next/guildbank_spec.lua` (a guild bank button's texture).
- `spec/frames/bag_draw_ownership_spec.lua` (a classic window's frame, content and a child's texture).
- `spec/frames/bagslots_spec.lua`, `spec/frames/bankslots_spec.lua` (each panel's textures after a draw).
- `spec/integrations/masque_spec.lua` ("skins drawn without the client's sharpening"): an item button's skin added and
  re-skinned; a vendor button's added, re-skinned and after a Next theme, checked after each; a guild bank button's;
  a bag button's; every button of a group on Masque's callback. Its stand-in group can make a texture as it skins, as
  Masque does.
- Mutation-tested: 20 mutations, each caught. Four first survived and led to tests: both slots panels, and a vendor
  button's first skin and its re-skin, which a later step of the same test had covered.
