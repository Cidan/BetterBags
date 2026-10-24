# Checking a theme addon's Next themes against BetterBags' engine

BetterBags - Themes (Sauravisus' addon) ships Next themes of its own (their ornaments: `.claude/rules/next-themes.md`
§12; the work: `docs/next-race-themes.md`). That addon has no tests, so these specs load its Next themes the way its
TOC does and run BetterBags' own checks on them. Run from BetterBags' root, with the addon's folder in
`BETTERBAGS_THEMES` (default `../BetterBags-Themes`):

```bash
~/.local/lua51/bin/busted tools/next_theme_check/check_spec.lua   # loads through its TOC; Check clean on every client; every file it names shipped as a power-of-two RGBA PNG
~/.local/lua51/bin/busted tools/next_theme_check/panel_spec.lua   # spec/next/theme_panel_spec.lua with them: every theme applied to open, drawn bags at both sizes without an error
~/.local/lua51/bin/busted tools/next_theme_check/pixel_spec.lua   # spec/next/pixel_perfect_spec.lua with them: on whole pixels at rest, both sizes
```

The panel and pixel specs run BetterBags' spec files with the addon's themes registered beside BetterBags' own
(`themes.lua` wraps `FreshNextThemes`), so every-theme tests cover them. Not part of the suite (busted runs `spec/`):
they need the other addon's checkout. To see them cover a theme, break one of its ornaments (a `Point` that is no
place) and watch both fail.
