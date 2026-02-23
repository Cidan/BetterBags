# WoW Addon Development Patterns

## Meta-Rule: Document Evolution
**IMPORTANT**: When you discover new abstract patterns through debugging, problem-solving, or user interaction, you MUST update the relevant pattern file (or create a new one). Add the pattern with:
- Clear problem statement
- Why it happens
- Solution pattern with minimal code example
- File references for context

## Pattern Files

Patterns are split into topic files for manageability:

- **`patterns-taint.md`** — Taint, protected code, and secure function rules. Critical to read when working with BankPanel, item buttons, or any protected WoW actions.
- **`patterns-ui.md`** — UI patterns: forms, tooltips, mouse wheel propagation, drag-to-reorder, StaticPopup, object pooling, WindowGrouping, color tiers.
- **`patterns-state.md`** — State management and architecture: context propagation, behavior vs visual methods, bank system architecture, cross-version feature parity, defensive programming, debugging.
