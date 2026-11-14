---
paths:
  - "data/changelog.lua"
  - "data/changelogdata.lua"
  - "frames/changelog.lua"
  - "tools/changelog/**"
  - ".github/workflows/release*"
  - "spec/changelog_spec.lua"
  - "spec/frames/changelog_spec.lua"
  - "spec/tools/changelog_data_spec.lua"
---
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
  `/bb` alone opens the settings). The settings window's General page has "Show What's New on Login"
  (the same `autoOpen` setting as the checkbox, next-settings.md §7). Opened by request it lists every bundled release, seen or not.

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

**The input** (`BuildInput`): every commit message, oldest first, each followed by its pull
request's commits. A squash merge's message holds every commit of its pull request (GitHub writes
each as a `* subject` line and its body), so one message is cut only past `maxMessage`, 64 KB, above
the longest on `main` (39 KB, "Appearance: Theme and Size tabs..."); `maxInput` (400 KB) bounds them
all. It was 8 KB until November 2026, which cut 3 of v0.8.0's 12 messages by 5-7.8 KB each: the
movable tabs, Auto Sell's one-at-a-time selling and most of the Next themes' work never reached
Gemini, and the shipped v0.8.0 notes left movable tabs out.

**Gemini** (`gemini.go`): the Interactions API, `POST
https://generativelanguage.googleapis.com/v1beta/interactions` with the AI Studio key in the
`x-goog-api-key` header (`GEMINI_API_KEY` repository secret), model `gemini-4-hydrogen` (Gemini 4
Hydrogen, generally available 2026-11-12; was `gemini-3.8-flash`), `system_instruction`, `input`,
`response_format: { type: "text", mime_type: "application/json", schema }`, `generation_config: {
thinking_level: "high", max_output_tokens: 65536 }`, `store: false`. From Google's "What's new in
Gemini 4 Hydrogen" (ai.google.dev/gemini-api/docs/whats-new-gemini-4-hydrogen) and its model page:
thinking levels `low`, `medium`, `high` (the default) and `xhigh` (`minimal` is a 400);
`max_output_tokens` counts thinking as well as the answer, 65,536 the most one synchronous answer
gives (the guide says to remove low caps such as 8,192: 16,384 was ours); sampling parameters are
ignored (none are sent); structured output with a declared schema is supported, as the guide asks
in place of JSON written from instructions. The reply's `status` must be `completed`; the notes
are the text of its `model_output` step (`steps`, Interactions breaking changes of May 2026). A busy
or failing server (429, 5xx), an unusable reply and notes that fail validation are retried (3
attempts, 4 s then 16 s apart); a 4xx is not. A request may take `requestTimeout` (5 minutes; the
slowest measured, v0.8.0's review, took 97 s), the whole run `runTimeout` (15 minutes); `main_test.go`
holds them to that.

**The instructions** (`systemInstruction`), each from a failure seen in the notes (§2a):
- What to cover: every change a player can notice, a build with many changes having many entries:
  a feature, setting or option (where to find it), how something looks or works, a changed
  default, what a player's existing setup does once they update, a removed or replaced control
  (where its job is now), every bug fixed.
- What to leave out: what players cannot notice (tests, CI, refactors, documentation, debugging
  and profiling tools); changes outside the addon (the issue tracker's forms, the repository); what
  a commit's own bug reviews, tests or later commits fixed in its change before it was merged (a
  bug is Fixed only when the commits say players had it: reported, seen in game, or there since an
  earlier build); how the code does it; a change whose effect on players the commits leave unclear
  (left out rather than guessed).
- Grouping: one entry per change a player would look for, never unrelated changes in one entry
  because they shared a commit; changes to one feature in one entry; a feature new in this build
  one New entry as it ships, its changes and fixes within the build part of it (Improved and Fixed
  are only for what existed before the build); nothing said twice, a new feature's change to
  something players had in one entry, never two.
- Accuracy: only what the commits say; clients only when the commits name the versions (limited
  to them, or about something only they have), never worked out from what the model knows of the
  game; a change reported from one version applies to all; `clients_quote`, the commits' own words
  naming them.
- The fields: categories (New: players did not have it; Improved: it existed and works, looks or
  behaves better or differently; Fixed: it did not work as it should), a title of at most 60
  characters, details of one to three short sentences and at most 300 characters, a short headline
  without the version, New then Improved then Fixed, the most notable first, plain text without `|`.

**Review pass:** every build's notes take two interactions. The first writes a draft from the
commits (`summarySchema`); the second (`reviewInput`) gets the commits, `ChangeList`'s numbered list
of every commit's subject and every pull request commit's (BuildInput's `=== Commit:` and `* `
lines, so the `* ` lines inside a squash merge's message too, each once, pull request numbers and
case aside) and the draft, and answers `reviewSchema`: `coverage` first, one row per listed change
(`change`, what players `notice` of it, the `entries` that cover it), then the corrected notes.
Only the notes are kept. It adds what the draft left out, folds iterations on a new feature into
its New entry, removes Fixed entries for what a commit fixed in its own work, splits entries that
join unrelated changes, merges repeats, removes what players cannot notice and code-level detail,
and checks every fact and client list against the commits. The list is built in Go so a change
cannot be skipped unseen: asked to audit the commits itself, the review skipped movable tabs
although #1184's subject names them. A review that fails (after its retries) keeps the draft,
which is valid notes already. Asked by the player: a release's notes describe what shipped, not
how it was iterated on within the release, and commits that fix several things and restate others
must not repeat entries.

**Clients** (`geminiNotes.summary`, in the draft and the review alike, since a failed review ships
the draft): an entry keeps its clients only when its `clients_quote` is in the build's commit
messages (`folded`: typographic quote marks made plain, whitespace folded, no case; the quote's own
surrounding quote marks trimmed; never the review's input, which holds the draft) and names exactly
those clients, each as a whole word and no other (`clientNamed`: Retail `retail`, `mainline`;
Classic `classic`, `era`, `vanilla`, `tbc`, `burning crusade`, `wrath`, `cataclysm`, `mists`, `mop`,
`anniversary`; Forever `forever`, `camelot`); otherwise it applies to every client. The window
hides an entry from other clients (§1), so a guessed client hides a change from players who have
it: twice in about eight runs before this, Hydrogen marked the Next guild bank's logs "Retail and
Classic only" from "the guild bank's on a client with one" (WoW: Forever has a guild bank). Every
quote seen in the runs named exactly its entry's clients ("loaded on retail and Forever", "keyring
last on Classic Era and Forever", "Both changes apply on Forever only."), and the review always
wrote `coverage` before the notes. The instructions say a quote must name its versions and no
others, so their old examples (the keyring, the Warbank), which a quote naming no version cannot
satisfy, are gone. Known gaps, not built for (no run has shown them): "classic" also names the
classic bag design and "forever" is an English word, so a quote about the classic bags, or one
saying something stays forever, passes; a quote is checked against the whole build, not the
entry's own commit; the review sees the draft without its quotes and writes them again.

**Validation** (`Summary.Validate`): a headline is required; categories must be New, Improved or
Fixed; every text is made one line of valid UTF-8 without control characters, trimmed and cut
(headline 300, title 100, details 1200 runes), with `|` doubled (the game reads `|` as an escape;
`||` draws one); clients are kept only if known, once each, in the order Retail, Classic, Forever;
an entry whose title repeats an earlier one's, ignoring case, spacing and punctuation, is dropped
(a safety net under the instructions and the review); at most 40 entries.

### 2a. How the notes were evaluated (November 2026)

The method was iterated against real releases until the notes matched the commits: each version
run against v0.9.2..HEAD (the next release, 21 commits, 88 KB of messages), v0.8.12..v0.9.0 (16
commits) and v0.7.0..v0.8.0 (12 commits, three over the old 8 KB cut), two samples each, every
output read against the commit messages, with the notes stored on the `changelog` branch as the
reference. What each step fixed:
- The shipped v0.9.0 notes (3.8 Flash) left out that Next panels start small by default, joined the
  section-column and Size Descending defaults into one wrong sentence ("two-column layout in small
  panel mode") and folded unrelated fixes into one entry. Hydrogen with the old instructions got the
  defaults right, but on v0.8.0 wrote 9 entries for 12 pull requests, joining unrelated features
  ("Resize small bags and drop items on category headers") and leaving movable tabs out.
- The coverage and grouping rules took v0.8.0 to 19-22 entries and v0.9.3 to 26-31; they also turned
  the bug reviews' findings each commit lists ("Four adversarial reviews found and this fixes: ...
  dock cards shrinking ...") into Fixed entries, and an issue template's change into an "in-game bug
  report form". The rules on a commit's own fixes and on what is outside the addon removed both.
- `ChangeList`'s checklist and the 64 KB cut brought movable tabs back in every run; the rule on
  unclear changes removed an entry that read "a bag uses a category" (Used In) as Hide In; the
  300-character details took the longest from 730 to under 300 characters, with no change lost; the
  client rule and quote ended the guessed "Retail and Classic only" (none in 6 runs, the guard never
  needed).
- Left as it is: Improved against Fixed varies between runs for the same change (a vendor cost's
  tooltip, the keyring's slots), and entry order within a category varies.

To evaluate a change to the method: clone the repository to a scratch directory, tag the commit to
write notes for there (`git tag v0.9.3 HEAD`; never push it), copy the `changelog` branch's
`releases/` into a scratch store without that version's file, build the generator (`go build -o
<bin> ./tools/changelog`) and run it from the clone with `GEMINI_API_KEY` set: `<bin> -channel release
-tag v0.9.3 -store <store> -out <dir>/data.lua -markdown <dir>/CHANGELOG.md -repo ""` (an alpha:
`-channel alpha -from <before> -to <sha> -repo Cidan/BetterBags`). Read `CHANGELOG.md` against `git
log --first-parent <previous tag>..<tag>`, more than one run per range: the model's answers vary.

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
  `spec/config/config_spec.lua` ("opens the changelog on /bb changelog"),
  `spec/config/catalog_spec.lua` ("turns What's New on login on and off").
- Generator: `go test ./tools/changelog/` (the Markdown against a golden file, its sections,
  client notes and escaping, the build's own notes only, removed on a failure, and `.pkgmeta` and
  the workflows naming the same file; validation and repeated titles, ranges, the Gemini
  request (the model, thinking and output limit), its rules, replies and retries, the review pass
  (the numbered list of changes, the coverage schema, only the notes kept) and a failed review,
  clients kept only with the commits' words naming exactly them (the draft's too; each client word;
  typographic quote marks), `ChangeList`, long messages passed whole,
  the timeouts, GitHub reads, the store, bundles, the Lua writer against golden files, whole runs
  with fakes, and `store.sh` against bare repositories, including two builds saving at once).
- Across the two: `spec/tools/changelog_data_spec.lua` loads the generator's golden and empty
  output and the committed copy as `ChangelogData` and reads them with the real `Changelog`.
- Every guard in the window and the generator was mutation-tested (10 and 14 mutations, each
  failing at least one test; the November 2026 method's 26 more: the quote against the commits, not
  the review's input, whole words, exactly its clients named, every client word on its own,
  typographic quote marks, the quote's trim, the draft checked too, the review's coverage, thinking
  at high, `ChangeList`'s repeats, case and spacing, the 64 KB cut).
- Real Gemini calls: verified with `gemini-4-hydrogen` against v0.8.0, v0.9.0 and the commits after
  v0.9.2 (§2a), and an alpha with its pull request's commits. Not verified yet: the window in game.
