package main

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type fakeSummarizer struct {
	inputs  []string
	summary Summary
	err     error
}

func (f *fakeSummarizer) Summarize(_ context.Context, input string) (Summary, error) {
	f.inputs = append(f.inputs, input)
	return f.summary, f.err
}

type fakeGitHub struct {
	pulls map[string][]PullRequest
	err   error
	calls int
}

func (f *fakeGitHub) PullsForCommit(sha string) ([]PullRequest, error) {
	f.calls++
	return f.pulls[sha], f.err
}

var now = time.Date(2026, 10, 18, 12, 0, 0, 0, time.UTC)

const logFormat = "log --first-parent --format=%H%x1f%s%x1f%b%x1e "

// alphaGit is a repository whose push to main went from "before" to "head": one squash-merged
// pull request.
func alphaGit() fakeGit {
	return fakeGit{
		"rev-parse --verify head^{commit}":                        "head",
		"describe --tags --abbrev=7 " + describeExclude + " head": "v0.5.16-15-g1234567",
		"describe --tags --abbrev=0 " + describeExclude + " head": "v0.5.16",
		"rev-parse --verify before^{commit}":                      "before",
		"merge-base --is-ancestor before head":                    "",
		logFormat + "before..head":                                "sha1\x1fChangelog window (#1145)\x1fA window for the changelog.\x1e",
		logFormat + "older..before":                               "sha0\x1fOlder change (#1144)\x1f\x1e",
	}
}

func alphaConfig(dir string) Config {
	return Config{Channel: "alpha", From: "before", To: "head", StoreDir: filepath.Join(dir, "store"),
		Out: filepath.Join(dir, "changelogdata.lua"), Markdown: filepath.Join(dir, "CHANGELOG.md"),
		Now: func() time.Time { return now }}
}

func markdownFor(t *testing.T, r Release) string {
	t.Helper()
	var b bytes.Buffer
	if err := WriteMarkdown(&b, r); err != nil {
		t.Fatalf("WriteMarkdown: %v", err)
	}
	return b.String()
}

var written = Summary{Headline: "A changelog.", Entries: []Entry{{Category: "New", Title: "What's New", Details: "Read what changed.", Clients: []string{}}}}

func readOut(t *testing.T, cfg Config) string {
	t.Helper()
	out, err := os.ReadFile(cfg.Out)
	if err != nil {
		t.Fatalf("read output: %v", err)
	}
	return string(out)
}

func luaFor(t *testing.T, releases []Release) string {
	t.Helper()
	var b bytes.Buffer
	if err := WriteLua(&b, releases); err != nil {
		t.Fatalf("WriteLua: %v", err)
	}
	return b.String()
}

func TestRunWritesAnAlphasNotesFromItsCommitsAndPullRequests(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	gemini := &fakeSummarizer{summary: written}
	gh := &fakeGitHub{pulls: map[string][]PullRequest{"sha1": {{Number: 1145, Title: "Changelog window",
		Commits: []Commit{{SHA: "p1", Subject: "Window first", Body: "Tests first."}, {SHA: "p2", Subject: "Then the generator"}}}}}}
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: gh, Gemini: gemini}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(gemini.inputs) != 1 {
		t.Fatalf("Gemini asked %d times", len(gemini.inputs))
	}
	for _, want := range []string{"v0.5.16-15-g1234567", "Changelog window (#1145)", "A window for the changelog.",
		"Pull request #1145", "Window first", "Tests first.", "Then the generator"} {
		if !strings.Contains(gemini.inputs[0], want) {
			t.Errorf("input lacks %q:\n%s", want, gemini.inputs[0])
		}
	}
	stored, _ := Store{Dir: cfg.StoreDir}.Load()
	want := Release{ID: now.Unix(), Version: "v0.5.16-15-g1234567", Channel: "alpha", Date: "2026-10-18",
		From: "before", To: "head", Headline: written.Headline, Entries: written.Entries}
	if len(stored) != 1 || stored[0].Headline != want.Headline || stored[0].ID != want.ID || stored[0].Date != want.Date ||
		stored[0].From != "before" || stored[0].To != "head" || stored[0].Channel != "alpha" || stored[0].Fallback {
		t.Fatalf("stored %+v", stored)
	}
	if got := readOut(t, cfg); got != luaFor(t, stored) {
		t.Errorf("output:\n%s", got)
	}
	// The packager's manual changelog: the notes of this build only.
	md, err := os.ReadFile(cfg.Markdown)
	if err != nil || string(md) != markdownFor(t, stored[0]) {
		t.Errorf("markdown %q, %v", md, err)
	}
}

// The Markdown holds only the build's own notes, also when the data carries earlier builds'.
func TestRunWritesOnlyTheBuildsNotesToTheMarkdown(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	older := Release{ID: 7, Version: "v0.5.16-14-gceff32a", Channel: "alpha", Date: "2026-10-17", Headline: "Older.", Entries: written.Entries}
	if err := (Store{Dir: cfg.StoreDir}).Save(older); err != nil {
		t.Fatal(err)
	}
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{}, Gemini: &fakeSummarizer{summary: written}}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	md, _ := os.ReadFile(cfg.Markdown)
	if strings.Contains(string(md), "Older.") || !strings.HasPrefix(string(md), written.Headline) {
		t.Errorf("markdown:\n%s", md)
	}
}

// A run that fails leaves no Markdown, so the packager writes its own changelog from the commits.
func TestRunRemovesTheMarkdownBeforeAnythingCanFail(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	if err := os.WriteFile(cfg.Markdown, []byte("stale"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := Run(context.Background(), cfg, Deps{Git: fakeGit{}}); err == nil {
		t.Fatalf("no error")
	}
	if _, err := os.Stat(cfg.Markdown); !os.IsNotExist(err) {
		t.Errorf("the Markdown is still there: %v", err)
	}
}

func TestRunWritesNoMarkdownWhenNotAsked(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	cfg.Markdown = ""
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{}, Gemini: &fakeSummarizer{summary: written}}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(cfg.Out), "CHANGELOG.md")); !os.IsNotExist(err) {
		t.Errorf("wrote a Markdown: %v", err)
	}
}

func TestRunReusesNotesItAlreadyWrote(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	store := Store{Dir: cfg.StoreDir}
	kept := Release{ID: 5, Version: "v0.5.16-15-g1234567", Channel: "alpha", Date: "2026-10-17", From: "before", To: "head",
		Headline: "Kept.", Entries: written.Entries}
	if err := store.Save(kept); err != nil {
		t.Fatal(err)
	}
	gemini := &fakeSummarizer{summary: Summary{Headline: "Different."}}
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{}, Gemini: gemini}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(gemini.inputs) != 0 {
		t.Errorf("Gemini was asked again")
	}
	if got := readOut(t, cfg); !strings.Contains(got, `headline = "Kept."`) {
		t.Errorf("output:\n%s", got)
	}
}

func TestRunListsTheCommitsWhenGeminiFails(t *testing.T) {
	for name, gemini := range map[string]Summarizer{
		"error":  &fakeSummarizer{err: errors.New("503")},
		"no key": nil,
	} {
		cfg := alphaConfig(t.TempDir())
		if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{}, Gemini: gemini}); err != nil {
			t.Fatalf("%s: Run: %v", name, err)
		}
		stored, _ := Store{Dir: cfg.StoreDir}.Load()
		if len(stored) != 1 || !stored[0].Fallback || stored[0].Entries[0].Title != "Changelog window" || stored[0].Entries[0].Category != "Changed" {
			t.Errorf("%s: stored %+v", name, stored)
		}
		if got := readOut(t, cfg); !strings.Contains(got, `title = "Changelog window"`) {
			t.Errorf("%s: output:\n%s", name, got)
		}
	}
}

func TestRunRewritesNotesThatWereListsOfCommits(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	store := Store{Dir: cfg.StoreDir}
	older := Release{ID: 7, Version: "v0.5.16-14-gceff32a", Channel: "alpha", Date: "2026-10-17", From: "older", To: "before",
		Headline: fallbackHeadline, Entries: []Entry{{Category: "Changed", Title: "Older change"}}, Fallback: true}
	if err := store.Save(older); err != nil {
		t.Fatal(err)
	}
	gemini := &fakeSummarizer{summary: written}
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{}, Gemini: gemini}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(gemini.inputs) != 2 || !strings.Contains(gemini.inputs[1], "Older change (#1144)") {
		t.Fatalf("inputs %q", gemini.inputs)
	}
	stored, _ := store.Load()
	for _, r := range stored {
		if r.Version == older.Version && (r.Fallback || r.ID != 7 || r.Date != "2026-10-17" || r.Headline != written.Headline) {
			t.Errorf("rewritten %+v", r)
		}
	}
}

// A pull request is listed once, with the first of its commits in the build (a preview of an open
// pull request reads every one of its commits, each associated with it).
func TestRunListsEachPullRequestOnce(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	g := alphaGit()
	g[logFormat+"before..head"] = "sha2\x1fSecond\x1f\x1e\nsha1\x1fFirst\x1f\x1e"
	pr := PullRequest{Number: 7, Title: "Both", Commits: []Commit{{SHA: "sha1", Subject: "First"}, {SHA: "sha2", Subject: "Second"}}}
	gemini := &fakeSummarizer{summary: written}
	if err := Run(context.Background(), cfg, Deps{Git: g, GitHub: &fakeGitHub{pulls: map[string][]PullRequest{"sha1": {pr}, "sha2": {pr}}}, Gemini: gemini}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if n := strings.Count(gemini.inputs[0], "Pull request #7"); n != 1 {
		t.Errorf("listed %d times:\n%s", n, gemini.inputs[0])
	}
}

func TestRunKeepsIdsIncreasing(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	future := Release{ID: now.Unix() + 100, Version: "v0.5.16-14-gceff32a", Channel: "alpha", Headline: "h", Entries: written.Entries}
	if err := (Store{Dir: cfg.StoreDir}).Save(future); err != nil {
		t.Fatal(err)
	}
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{}, Gemini: &fakeSummarizer{summary: written}}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	stored, _ := Store{Dir: cfg.StoreDir}.Load()
	for _, r := range stored {
		if r.Version == "v0.5.16-15-g1234567" && r.ID != future.ID+1 {
			t.Errorf("id %d", r.ID)
		}
	}
}

func TestRunSummarizesEveryCommitSinceTheLastTagForARelease(t *testing.T) {
	dir := t.TempDir()
	cfg := Config{Channel: "release", Tag: "v0.5.17", StoreDir: filepath.Join(dir, "store"), Out: filepath.Join(dir, "out.lua"),
		Now: func() time.Time { return now }}
	g := fakeGit{
		"describe --tags --abbrev=0 " + describeExclude + " v0.5.17^": "v0.5.16",
		logFormat + "v0.5.16..v0.5.17":                                "s2\x1fSecond (#2)\x1fTwo.\x1e\ns1\x1fFirst (#1)\x1fOne.\x1e",
	}
	gh := &fakeGitHub{}
	gemini := &fakeSummarizer{summary: written}
	if err := Run(context.Background(), cfg, Deps{Git: g, GitHub: gh, Gemini: gemini}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if gh.calls != 0 {
		t.Errorf("looked up pull requests for a release")
	}
	if !strings.Contains(gemini.inputs[0], "Second (#2)") || !strings.Contains(gemini.inputs[0], "One.") {
		t.Errorf("input:\n%s", gemini.inputs[0])
	}
	stored, _ := Store{Dir: cfg.StoreDir}.Load()
	if len(stored) != 1 || stored[0].Channel != "release" || stored[0].Version != "v0.5.17" || stored[0].From != "v0.5.16" {
		t.Errorf("stored %+v", stored)
	}
}

func TestRunSummarizesWithoutPullRequestsWhenGitHubFails(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	gemini := &fakeSummarizer{summary: written}
	if err := Run(context.Background(), cfg, Deps{Git: alphaGit(), GitHub: &fakeGitHub{err: errors.New("403")}, Gemini: gemini}); err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(gemini.inputs) != 1 || !strings.Contains(gemini.inputs[0], "Changelog window (#1145)") {
		t.Errorf("inputs %q", gemini.inputs)
	}
}

func TestRunEmptiesTheDataBeforeAnythingCanFail(t *testing.T) {
	cfg := alphaConfig(t.TempDir())
	if err := os.WriteFile(cfg.Out, []byte("placeholder"), 0o644); err != nil {
		t.Fatal(err)
	}
	err := Run(context.Background(), cfg, Deps{Git: fakeGit{}, Gemini: &fakeSummarizer{summary: written}})
	if err == nil {
		t.Fatalf("no error")
	}
	if got := readOut(t, cfg); got != luaFor(t, nil) {
		t.Errorf("output:\n%s", got)
	}
}
