package main

import (
	"context"
	"fmt"
	"io"
	"strings"
	"time"
)

// Config says which build to write the changelog for, and where.
type Config struct {
	// Channel is "alpha" (a push to main) or "release" (a tag).
	Channel string
	// Tag is the release's tag.
	Tag string
	// From is the commit main was at before the push (an alpha's start); To is the build's commit.
	From string
	To   string
	// StoreDir is a checkout of the changelog branch, where every build's notes are kept.
	StoreDir string
	// Out is the data file to write (data/changelogdata.lua).
	Out string
	Now func() time.Time
}

// Deps are what a run reads from.
type Deps struct {
	Git Git
	// GitHub finds an alpha's pull requests; nil reads only the commits on main.
	GitHub PullFinder
	// Gemini writes the notes; nil lists the commits instead.
	Gemini Summarizer
	Log    io.Writer
}

const (
	noChangesHeadline = "No changes in this build."
	// maxMessage is how much of one commit message goes to Gemini; maxInput, of all of them.
	maxMessage = 8000
	maxInput   = 400000
)

func capped(s string) string {
	if len(s) <= maxMessage {
		return s
	}
	return s[:maxMessage] + "\n(cut short)"
}

// BuildInput lays a build's commits out for Gemini, oldest first, each followed by the commits
// of the pull request it merged.
func BuildInput(channel string, r Range, commits []Commit, pulls map[string][]PullRequest) string {
	var b strings.Builder
	kind := "alpha build"
	if channel == "release" {
		kind = "release"
	}
	fmt.Fprintf(&b, "BetterBags %s %s.\n", kind, r.Version)
	if r.From != "" {
		fmt.Fprintf(&b, "It holds every change since %s.\n", r.From)
	}
	for i := len(commits) - 1; i >= 0; i-- {
		if b.Len() > maxInput {
			b.WriteString("\n(the remaining commits were left out)\n")
			break
		}
		c := commits[i]
		fmt.Fprintf(&b, "\n=== Commit: %s\n", c.Subject)
		if c.Body != "" {
			b.WriteString(capped(c.Body))
			b.WriteString("\n")
		}
		for _, pr := range pulls[c.SHA] {
			fmt.Fprintf(&b, "--- Pull request #%d: %s. Its commits:\n", pr.Number, pr.Title)
			for _, pc := range pr.Commits {
				fmt.Fprintf(&b, "* %s\n", pc.Subject)
				if pc.Body != "" {
					b.WriteString(capped(pc.Body))
					b.WriteString("\n")
				}
			}
		}
	}
	return b.String()
}

type runner struct {
	deps Deps
	log  func(format string, args ...any)
}

// notes writes a build's notes: Gemini's, or the commit subjects (fallback) when Gemini is not
// set up or could not write them.
func (r runner) notes(ctx context.Context, channel string, rng Range) (Summary, bool, error) {
	commits, err := Commits(r.deps.Git, rng.From, rng.To)
	if err != nil {
		return Summary{}, false, err
	}
	if len(commits) == 0 {
		return Summary{Headline: noChangesHeadline, Entries: []Entry{}}, false, nil
	}
	pulls := map[string][]PullRequest{}
	if channel == "alpha" && r.deps.GitHub != nil {
		// Each pull request goes with the oldest of its commits in the build, once.
		listed := map[int]bool{}
		for i := len(commits) - 1; i >= 0; i-- {
			c := commits[i]
			found, err := r.deps.GitHub.PullsForCommit(c.SHA)
			if err != nil {
				r.log("reading the pull requests of %s: %v", c.SHA, err)
				continue
			}
			for _, pr := range found {
				if !listed[pr.Number] {
					listed[pr.Number] = true
					pulls[c.SHA] = append(pulls[c.SHA], pr)
				}
			}
		}
	}
	if r.deps.Gemini == nil {
		r.log("no GEMINI_API_KEY: listing the commits of %s", rng.Version)
		return FallbackSummary(commits), true, nil
	}
	s, err := r.deps.Gemini.Summarize(ctx, BuildInput(channel, rng, commits, pulls))
	if err == nil {
		s, err = s.Validate()
	}
	if err != nil {
		r.log("Gemini could not write the notes of %s, listing its commits: %v", rng.Version, err)
		return FallbackSummary(commits), true, nil
	}
	r.log("Gemini wrote %d entries for %s", len(s.Entries), rng.Version)
	return s, false, nil
}

// Run writes the changelog data for a build. It first empties the data file, so a run that
// fails ships no notes rather than the ones in the repository; then it writes the build's notes
// (or reuses the stored ones), stores them, writes again any bundled notes that were listed from
// commits, and writes the data with the releases the build carries.
func Run(ctx context.Context, cfg Config, deps Deps) error {
	logOut := deps.Log
	if logOut == nil {
		logOut = io.Discard
	}
	r := runner{deps: deps, log: func(format string, args ...any) {
		fmt.Fprintf(logOut, "changelog: "+format+"\n", args...)
	}}
	if err := writeData(cfg.Out, nil); err != nil {
		return err
	}
	if cfg.StoreDir == "" {
		return fmt.Errorf("no store directory")
	}
	rng, err := ResolveRange(deps.Git, cfg)
	if err != nil {
		return err
	}
	r.log("%s %s: %q..%q", cfg.Channel, rng.Version, rng.From, rng.To)
	store := Store{Dir: cfg.StoreDir}
	stored, err := store.Load()
	if err != nil {
		return err
	}
	now := time.Now
	if cfg.Now != nil {
		now = cfg.Now
	}

	index := -1
	var nextID int64 = now().Unix()
	for i, s := range stored {
		if s.Version == rng.Version {
			index = i
		}
		if s.ID >= nextID {
			nextID = s.ID + 1
		}
	}
	if index < 0 || (stored[index].Fallback && deps.Gemini != nil) {
		s, fallback, err := r.notes(ctx, cfg.Channel, rng)
		if err != nil {
			return err
		}
		release := Release{ID: nextID, Version: rng.Version, Channel: cfg.Channel, Date: now().UTC().Format("2006-01-02"),
			From: rng.From, To: rng.To, Headline: s.Headline, Entries: s.Entries, Fallback: fallback}
		if index >= 0 {
			release.ID, release.Date = stored[index].ID, stored[index].Date
			stored[index] = release
		} else {
			stored = append(stored, release)
			index = len(stored) - 1
		}
		if err := store.Save(release); err != nil {
			return err
		}
	} else {
		r.log("reusing the stored notes of %s", rng.Version)
	}
	current := stored[index]

	if deps.Gemini != nil {
		for i, s := range stored {
			if !s.Fallback || i == index || !inBundle(Bundle(stored, cfg.Channel, current), s.Version) {
				continue
			}
			again, fallback, err := r.notes(ctx, s.Channel, Range{Version: s.Version, From: s.From, To: s.To})
			if err != nil || fallback {
				continue
			}
			s.Headline, s.Entries, s.Fallback = again.Headline, again.Entries, false
			if err := store.Save(s); err != nil {
				return err
			}
			stored[i] = s
		}
	}

	bundle := Bundle(stored, cfg.Channel, current)
	r.log("writing %d releases to %s", len(bundle), cfg.Out)
	return writeData(cfg.Out, bundle)
}

func inBundle(bundle []Release, version string) bool {
	for _, r := range bundle {
		if r.Version == version {
			return true
		}
	}
	return false
}
