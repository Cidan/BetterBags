# The In-Game Changelog

On login, BetterBags shows players what changed: a window listing the notes of every build they
have not seen yet, written for players by Gemini from the commits of each build. The notes are
generated in CI for every alpha (push to `main`) and every tagged release, kept on the `changelog`
branch, and packaged into the addon. Nothing is committed back to `main`, so tagging never needs a
source change afterwards.

## 1. In game

**Data** (`data/changelogdata.lua`, module `ChangelogData`): `releases`, a list of
`{ id, version, channel, date, headline, entries }`, each entry
`{ category, title, details, clients }`. `category` is `New`, `Improved`, `Fixed`, or `Changed`
(notes listed from commits when Gemini could not write them); `clients` lists `Retail`,
`Classic` and/or `Forever`, empty meaning every client. The file is generated (§2); the copy in
the repository holds hand-written notes and is what a source checkout shows. Never edit a
packaged copy.

**Reading it** (`data/changelog.lua`, module `Changelog`):
- `GetClient()`: `Forever` when `addon.isForever`, else `Retail` when `addon.isRetail`, else
  `Classic` (every classic flavor).
- `GetReleases()`: the bundled releases newest first (by `id`), each with only the entries for the
  player's client; a release left with none is not returned. The bundled data is not modified.
- Seen state, account wide (AceDB `global.changelog`, shared by every character and profile, kept
  across profile resets; `DB:Get/SetChangelogLastSeen`, `DB:Get/SetChangelogAutoOpen`, defaults
  `lastSeen = 0`, `autoOpen = true` in `const.DATABASE_DEFAULTS.global`):
  - `IsUnseen(release)`: its `id` is above `lastSeen`. `HasUnseen()` over the shown releases.
  - `MarkAllSeen()`: `lastSeen` becomes the highest `id` of every bundled release, including
    releases with nothing for this client, so they never open the window later.
  - `ShouldOpenOnLogin()`: `autoOpen` and `HasUnseen()`.
- Ids order releases and compare across alphas and releases: version strings like
  `v0.5.16-14-gceff32a` do not sort. An id is the time the notes were first written, kept above
  every earlier stored id (§2).

**The window** (`frames/changelog.lua`, module `ChangelogWindow`): a Sonata **Panel** window
(`window/window.lua`, `Kind = "Panel"`, so every theme styles it and gives it a close button;
Dialog windows have none), named `BetterBagsChangelog` (closes with Escape), titled "What's New
in BetterBags", 560 x 540, not resizable, in the `DIALOG` strata, with the backpack's opacity, no
fade. Built the first time it opens.
- Content: a `ChangelogBody` drawable (plan PRE, DEP scroll, SELF) whose PRE hands the scroll box
  the content box minus the 34-pixel bottom row and 10 pixels on the right. The scroll area stops
  those 10 pixels short (`RIGHT_GAP`): the scroll box puts its 8-wide bar 12 in from its right
  edge, and the bar's 17-wide up and down buttons are centered on it (`MinimalScrollBar.xml`), so
  they end 9.5 in from the content box's edge. The Panel kind has no right inset in Default, whose
  border covers about 6 pixels of the content box (Blizzard's own `Inset` frames start 6 in); at
  gaps of 0 and 4 the border covered the bar's buttons in game (WoW: Forever). The scroll box (`render/scrollbox.lua`)
  scrolls a `ChangelogCanvas` drawable laid out at the scroll area's width: per release a header
  (version in `Heading`, date in `MutedSmall` with " - Alpha" for an alpha, a `New` badge in
  `Positive` while unseen, the headline in `Description`, wrapped), then a row per entry: the
  category tag in its role (`New` Positive, `Improved`/`Fixed` Field, `Changed` Muted) in a
  70-pixel column, the title in `Body` beside it, and the details in `Description` under the title,
  always shown (an entry without details is its title alone). Each row is a button only so the
  game highlights it under the pointer (a `HIGHLIGHT` texture); it does nothing on a click. With
  nothing to show it says "There are no changes to show yet."
- Bottom row, inside the content box: a `UICheckButtonTemplate` checkbox "Don't show me this
  again" at the bottom left (checked = `autoOpen` off; clicking sets it), and an "Okay!" button
  (`UIPanelButtonTemplate`, styled as a Sonata `Button` element) at the bottom right, which closes
  the window.
- Closing it any way (Okay!, the X, Escape) marks every bundled release seen (`OnHide`).
- Enabled by `addon:OnEnable()` (`core/init.lua`): modules are not enabled automatically
  (initialization.md), and its `OnEnable` registers both ways it opens.
- Opens: by itself on the first `LOADING_SCREEN_DISABLED` of a session when `ShouldOpenOnLogin()`
  (once per session); on the `changelog/Open` message, sent by the bag menu's **What's New** entry
  (`frames/contextmenu.lua`, above Open Options Screen) and by `/bb changelog` (`config/config.lua`;
  `/bb` alone opens the settings). Opened by request it lists every bundled release, seen or not.

## 2. Generating the notes in CI (`tools/changelog`, Go, standard library only)

Both release workflows (`release_alpha.yaml` on push to `main`, `release.yml` on tags) run, before
the packager:
1. `tools/changelog/store.sh checkout $RUNNER_TEMP/changelog-store`: a worktree of
   `origin/changelog` (an empty orphan branch the first time).
2. `go run ./tools/changelog -channel alpha -from <github.event.before> -to <github.sha>` or
   `-channel release -tag <github.ref_name>`, with `-store` that worktree and
   `-out data/changelogdata.lua`.
3. `store.sh save <store> "Notes for ..."`: commits `releases/` and pushes; a push that loses a race
   to another build rebases (`-X theirs`, this build's notes win) and retries, up to 5 times.

**Why no chicken-and-egg:** the packager (BigWigsMods/packager v2.6.1, `release.sh`) packages the
working tree as CI leaves it: it ignores untracked files (`git ls-files --others`) but copies tracked
files with their edits, and checks nothing is uncommitted. The generator overwrites the tracked
`data/changelogdata.lua` in the checkout; nothing is committed to `main`.

**Ranges** (`ResolveRange`):
- A release covers every first-parent commit since the previous tag
  (`git describe --tags --abbrev=0 --exclude=*[Aa][Ll][Pp][Hh][Aa]* <tag>^`; none: the latest 50).
- An alpha covers what the push to `main` added: `before..sha`, or since the latest tag when
  `before` is not a commit main grew from (zeros on a new branch, a force push). Its version is the
  packager's (`git describe --tags --abbrev=7 --exclude=...`).
- On `main` each first-parent commit is a squash-merged pull request. An alpha also reads each
  pull request's own commits (GitHub REST: `commits/{sha}/pulls`, then `pulls/{n}/commits`), each
  pull request listed once, with its oldest commit in the build. A release reads only the commits
  on `main`. A failed GitHub read only drops that pull request's commits.

**Gemini** (`gemini.go`): the Interactions API, `POST
https://generativelanguage.googleapis.com/v1beta/interactions` with the AI Studio key in the
`x-goog-api-key` header (`GEMINI_API_KEY` repository secret), model `gemini-3.8-flash`,
`system_instruction` (who the notes are for, and how this build differs from the previous one:
group related commits into one entry; a feature new in this build is one New entry describing it
as it ships, its changes and fixes within the build part of that entry, never separate Improved or
Fixed entries, which are only for things that existed before the build; never say the same thing
twice, even in different words or when one commit fixes several things others mention; leave out
what players cannot notice; the categories and clients; plain text without `|`),
`input` (every commit message, oldest first, each followed by its pull request's commits),
`response_format: { type: "text", mime_type: "application/json", schema }` (headline, entries with
the category and client enums), `generation_config: { thinking_level: "medium",
max_output_tokens: 16384 }`, `store: false`. The reply's `status` must be `completed`; the notes are
the text of its `model_output` step. Verified against ai.google.dev (model page, structured output,
Interactions breaking changes of May 2026: `steps` replaced `outputs`; `generateContent` is still
supported but not recommended for new work). A busy or failing server (429, 5xx), an unusable reply
and notes that fail validation are retried (3 attempts, 4 s then 16 s apart); a 4xx is not.

**Review pass:** every build's notes take two interactions. The first writes a draft from the
commits; the second gets the commits and the draft (`reviewInput`) and returns the notes corrected
against the same rules: iterations on a new feature folded into its New entry, entries saying the
same thing merged, what players cannot notice removed, nothing added the commits do not say. A
review that fails (after its retries) keeps the draft, which is valid notes already. Asked by the
player: a release's notes describe what shipped, not how it was iterated on within the release,
and commits that fix several things and restate others must not repeat entries.

**Validation** (`Summary.Validate`): a headline is required; categories must be New, Improved or
Fixed; every text is made one line of valid UTF-8 without control characters, trimmed and cut
(headline 300, title 100, details 1200 runes), with `|` doubled (the game reads `|` as an escape;
`||` draws one); clients are kept only if known, once each, in the order Retail, Classic, Forever;
an entry whose title repeats an earlier one's, ignoring case, spacing and punctuation, is dropped
(a safety net under the instructions and the review); at most 40 entries.

**Never blocking a release:**
- Without a key, or when Gemini fails, the notes list the commit subjects (category `Changed`,
  pull request references removed) and are stored with `fallback: true`. Every later build with a
  key writes again each fallback still in its bundle, keeping its id and date.
- `Run` empties the data file before anything else, so a run that fails ships no notes rather than
  the repository's hand-written ones; if the program cannot even run, the workflow copies
  `tools/changelog/testdata/changelogdata.empty.lua` over it. Failed store steps only warn.

**Stored notes** (`changelog` branch, `releases/<version>.json`, `store.go`): written once per
version and reused, so building a version again ships the same text. A stored fallback is written
again when a key is available.

**What a build carries** (`Bundle`): newest first, releases with entries only. A tagged release:
the last 10 tagged releases up to it. An alpha: those, plus up to 20 alphas since the latest of
them. A player who skipped builds sees every one they missed.

**The Lua output** (`luawriter.go`): the exact format of the committed file (the same header; a Go
test checks the committed copy starts with it). Strings are Lua 5.1 literals with control
characters as three-digit decimal escapes.

**The sites' changelog** (`markdown.go`): CurseForge, Wago, WoWInterface and the GitHub release
showed the packager's changelog of commits, which players found long and meaningless. The release
workflows pass `-markdown CHANGELOG.md`, and the generator writes the build's own notes there (only
this build's, not the bundle's): the headline, then `## New`, `## Improved`, `## Fixed` and
`## Changes` (notes listed from commits), each entry `- **Title** (WoW: Forever only): details`,
the client note only when an entry does not apply to every client. Text is escaped for Markdown
(the game's doubled `|` written single and escaped; a line that would start a heading or a list
escaped). `.pkgmeta` names it the manual changelog (`manual-changelog: filename: CHANGELOG.md,
markup-type: markdown`). From packager v2.6.1 `release.sh`: a manual changelog generated for the
build is used even though it is untracked (`vcs_addignore`: "Don't ignore a manual changelog
generated for the build"), sent to CurseForge with its markup type, to Wago, as the GitHub
release body, and to WoWInterface converted to BBCode when pandoc is there; when the file is
missing, the packager warns and writes its changelog of commits as before. `Run` removes the file
before anything can fail, and the workflows remove it when the generator fails, so a failed run
gets the commit changelog, never a stale one. `/CHANGELOG.md` is git-ignored; the packaged addon
carries it. A Go test checks `.pkgmeta` and both workflows name the same file and remove it on a
failure.

**Preview on pull requests** (`test.yml`, `changelog-preview`): for pull requests from this
repository (forks get no secrets), the notes the pull request would ship, written by Gemini into a
temporary store, in the job summary: the Markdown the sites would show, rendered, and the in-game
data under it. The `changelog-generator` job runs the Go tests.

## 3. Coverage

- In game: `spec/changelog_spec.lua` (client names, filtering and order, unseen, marking seen,
  opening on login, the setting, no data), `spec/database_spec.lua` ("changelog": defaults, kept,
  shared by profiles), `spec/frames/changelog_spec.lua` (the Panel window and its size, the layout
  of headers and rows across the scroll area, alpha labels, the New badge, details always shown
  under the title and the hover highlight, rows without details, the tag and title columns, the
  bottom row and the scroll area's size (bottom row, right gap), the checkbox,
  Okay!, marking seen on close, opening once per session on login, not when off or all seen,
  `changelog/Open`, the empty text), `spec/frames/contextmenu_spec.lua` (What's New),
  `spec/core/init_spec.lua` ("enables the changelog window"),
  `spec/config/config_redraw_spec.lua` ("slash commands").
- Generator: `go test ./tools/changelog/` (the Markdown against a golden file, its sections,
  client notes and escaping, the build's own notes only, removed on a failure, and `.pkgmeta` and
  the workflows naming the same file; validation and repeated titles, ranges, the Gemini
  request, its rules, replies and retries, the review pass and a failed review, GitHub reads, the store, bundles, the Lua writer against golden files, whole runs with
  fakes, and `store.sh` against bare repositories, including two builds saving at once).
- Across the two: `spec/tools/changelog_data_spec.lua` loads the generator's golden and empty
  output and the committed copy as `ChangelogData` and reads them with the real `Changelog`.
- Every guard in the window and the generator was mutation-tested (10 and 14 mutations, each
  failing at least one test).
- Not verified yet: a real Gemini call (the key is a repository secret; the first pull request
  preview or alpha build exercises it), and the window in game.
