# Claude

When the user types "bb" into a prompt and nothing else, read all the rules in .roo/rules/* as your rules and await further instructions.

## Pattern Learning
As you work through problems and discover new abstract patterns (especially debugging techniques, API workarounds, or architectural decisions), update `.roo/rules/patterns.md` with the new pattern. This helps future contexts understand the codebase's design decisions.

## General Use

The codebase is currently undergoing a major rewrite to integrate the Moonlight framework into BetterBags. Legacy BetterBags code is located in annotations/bb.