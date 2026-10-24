# Race themes for BetterBags Next (BetterBags - Themes)

## As asked (2026-10-24)

> look at Sauravisus' theme addon (which we have installed) that has all the Original bag themes, and start adapting
> another set of themes to work on Next bags. ... the key thing here isn't to adapt his themes EXACTLY as they are, but
> instead, i want to work on carrying over the "spirit" of what he was trying to do and the general feel. i still want
> some of those pretty borders, but, you know, smaller and less large, more tasteful, and animated feeling. so for
> example, i can see a green druid type one where the left side of the bag is gnarled roots and leaves, for example,
> but in high resolution.

Then: "i wanted these themes as a part of his addon, not mine! move all assets and themes into *his* addon, we're going
to make a PR" (only the new themes; BetterBags keeps Default, Ember, Parchment and Quiet). Then: "we're going to only
send a PR for this theme [Night Elf] when we're done, let's not work on the other themes right now, as i want to move on
after this theme (but we'll take notes ...)".

## Where things are

- **BetterBags** (branch `next-theme-ornaments`): the engine the themes need, no theme of its own.
  - Switch styles, `Controls.Toggle.Style` = `"Square"` or `"Round"` (`.claude/rules/next-settings.md`, NextToggle).
  - Theme ornaments, `Panel.Ornaments` (`next/ornaments.lua`, `.claude/rules/next-themes.md` §12): art anchored to a
    panel body's sides and corners, mirrored for the bank, animated on the client's animation groups (the sway eases
    only at its turns: eased in and out on every step it stopped dead at rest, "very jerky" in game).
  - `tools/next_theme_check/`: BetterBags' own checks run on the theme addon's Next themes (its README).
- **BetterBags - Themes** (`~/git/BetterBags-Themes`, upstream `AlexHaible/BetterBags-Themes`, fork `Cidan`):
  - `next-themes`: Night Elf alone, what the pull request will hold (`themes/next/Shared.lua`,
    `themes/next/NightElf.lua`, `textures/next/NightElf/`, `tools/next_ornaments.py`).
  - `next-themes-all`: all four themes (Night Elf, Blood Elf, Nightborne, Pandaren) with the whole history; the parked
    themes are picked up from here.
  - Its `themes/next/Shared.lua` registers through `Sonata:RegisterNextTheme`, a no-op on a BetterBags without Next
    themes. Names follow the addon's: `RacesNightElf`, "Races - Night Elf" (Next themes have their own registry, so they
    never clash with the classic ones).

## How the art is made and approved

- `tools/next_ornaments.py` (Python 3, numpy) draws every piece: signed-distance shapes (tapered tubes along curves,
  leaves, mushrooms, metal, gems), shaded under a light from the top left, value noise for grain. Run from the theme
  addon's root: `python3 tools/next_ornaments.py NightElf --preview DIR`, under a time limit, checking its exit status
  (a pipe through `tail` once hid a failure). Pass `-B` when importing it from a scratch script (no `__pycache__` in
  the repository).
- `--preview` writes mockups of a full bag and a small bag drawn in the game's order: ornaments on the background layer,
  the bag's body and feather, its items, then the other ornaments. Their numbers are the theme's (kept in the
  generator's `NIGHTELF_ORNAMENTS`, beside the theme's list).
- **Asked: "you can point me to the art first and i can approve, before you add it to game"**: each round of art is
  shown as mockups and close-ups, and goes into the theme only once approved; then the theme, the checks
  (`tools/next_theme_check/`), a local commit.
- New files need the game restarted, not just reloaded (the client finds files when it starts).

## Lessons (each cost a round)

- **Strips must repeat seamlessly.** Draw them taller with margins (their periodic content running on past both ends)
  and crop (`Strip`, `crop`), so shadows and blurs at the ends see what lies beyond; never offset a shadow with
  `np.roll` (it wraps a bottom copy's shadow onto the top rows); noise lattices must fit the period exactly. Measure
  the seam (the last row against the first, beside the usual row-to-row difference).
- **Nothing may touch an edge it should not.** The generator fails when a piece's art reaches its edge (a soft shadow's
  last few percent excepted), sides declared open per piece (a strip's ends, the bough's base). It caught leaves cut
  off at the Night Elf strip's right edge (seen in game) and at Pandaren's left edge.
- **Leaf clusters size themselves to their room** (`ne_leaf_cluster`).
- **One scale for pieces that meet** (a strip, its crest, its foot), and the same place for what lines up (a rod, the
  roots at the top of the tile).
- **A pulsing ornament takes its strength from its Pulse alone**, no `Alpha` beside it (whether an Alpha animation
  multiplies or replaces the texture's alpha is not verified).
- **A glow fades out before its piece's edges** (`Canvas.add_glow`, `window`), never on a strip that repeats.
- **Small bags' strips end inside the corner pieces.** A strip and the back roots that run past the corner roots show a
  flat cut ("bottom edge of small is sloppy, top too. hard edge there."): end both in the middle of the border root.

## Night Elf

What was asked, in order: "the art is very linear ... like a straight stick. i was thinking something a bit more..
grand, and poking out a bit further away, more 'full'. the roots should be less dense overall, more gaps in them,
thicker/bigger so it's easier to see their detail"; "it should run the full border, top to bottom ... it should feel
like it's a part of the frame"; "make it so it feels like it's really, really embedded in the bag ... like the roots
are cutting into the backdrop and come from 'under' the bag"; the mushrooms "look funny" (redone: "shrooms look
fantastic").

Done: two great gnarled roots (one hugging the edge, one wandering out), a tendril, gaps, furrowed bark, burls, moss,
leaf clusters, glowing mushrooms; full bags top to bottom; the front roots bend into the bag and sink into its backdrop;
back roots on the background layer reach out from under the bag, darkened by its feather; a swaying bough; fronds; the
moon; fireflies; small bags at two thirds, with roots gripping the corners.

**Style direction (asked, with a screenshot just outside Darnassus: "this is what i think of when i think nightelf"):**
violet dusk. Violet is the ambient light (bark, stone, shadow, air), set against saturated moss greens, one tree in
magenta blossom, and pinpoints of cyan-blue light (wisps, lanterns); colossal trees whose buttressed roots sweep and
flare into the ground; the ground a knotwork of interlacing roots; spirals and crescents carved in wood and stone;
Blizzard's hand-painted look (broad soft shapes, strong rim light), not fine noise. Calm, ancient, reverent, a little
glowing. "most leaves in nightelf tend to be two toned as well." So: violet-plum bark with lavender rim light,
teal-emerald moss and two-toned leaves (some violet), a twilight-violet body, painterly shading, flaring buttresses,
an occasional carved spiral, magenta blossoms, soft cyan-blue wisps for fireflies, interlacing back roots; the
mushrooms kept. A style study (the strip and a mockup) comes before redrawing every piece.

## The parked themes (on `next-themes-all`)

Each is a first pass, seen in game only as a group, made before the Night Elf rounds taught what is wanted. Bring each
through the same rounds before shipping it: grand rather than linear; embedded in the bag (crossing its edge and sinking
into its backdrop, a back layer coming from under it); top to bottom on full bags; small bags gripping their corners
with the strips ending inside the corner pieces; nothing cut at an edge; a style study from an in-game reference of
the place it is named for.

- **Races - Blood Elf** (Silvermoon): a gold rod wound with a crimson silk ribbon, scrolls, crimson gems between elven
  leaf blades, a spire crest over a verdant gem, a crimson drop at the foot, three verdant spheres bobbing by the title,
  rising gold sparks, crimson and gold, round switches. Its look is metalwork, not growth: "grand" may mean a fuller
  filigree screen (arches, phoenix motifs) rather than a rod.
- **Races - Nightborne** (Suramar): a silver channel with crescents cradling magenta gems, a ley line of runes drawn as
  light (white art, colored, added) and breathing, a crescent crest holding the Nightwell's light, a rune circle
  turning once a minute behind the title, an arcane lotus at the foot, arcane motes, square switches (the set's one
  example of the square style).
- **Races - Pandaren** (the Jade Forest): bamboo (three stalks, nodes, leaf sprays), cut tops crowned with leaves, a
  mossy stone at the foot, a swaying sprig, a red paper lantern swaying by the title, cherry blossom petals falling as
  sparkles (a theme texture, blended normally), jade, gold and red lacquer, round switches. **Known defect:** bamboo
  leaves are cut off at the strip's left edge; the generator now refuses to write it until they are sized to their
  room.
- Other themes in the addon not started: the rest of the races, Art Deco, Aero Glass, macOS, Dynamic.
