# WoW Addon Development Patterns

## Meta-Rule: Document Evolution
**IMPORTANT**: When you discover new abstract patterns through debugging, problem-solving, or user interaction, you MUST update the relevant pattern file (or create a new one). Add the pattern with:
- Clear problem statement
- Why it happens
- Solution pattern with minimal code example
- File references for context

## Pattern Files

Patterns are split into topic files for manageability, each a rules file in `.claude/rules/` that loads with the code it names in `paths:`:

- **`patterns-taint.md`** — Taint, protected code, and secure function rules. Critical to read when working with BankPanel, item buttons, or any protected WoW actions.
- **`patterns-ui.md`** — UI patterns: forms, tooltips, mouse wheel propagation, drag-to-reorder, StaticPopup, object pooling, color tiers.
- **`patterns-ui-text.md`** — Text and fonts: font files, text roles, font string widths, edit boxes, text on whole pixels.
- **`patterns-ui-themes.md`** — Themes and textures: styling at registration, frame levels, atlases, gradients and alphas, theme parts set to false, Blizzard's art, animations that read the theme.
- **`patterns-ui-next.md`** — BetterBags Next panels: dragging real frames, scaled frames, the dock, live resizing, whole screen pixels, texture sharpening.
- **`patterns-state.md`** — State management and architecture: context propagation, behavior vs visual methods, bank system architecture, cross-version feature parity, defensive programming, debugging.
- **`patterns-specs.md`** — Spec isolation: spec files that pass alone and shuffled, and put back what they replace.
