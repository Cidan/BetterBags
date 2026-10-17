// Command changelog writes BetterBags' in-game changelog (data/changelogdata.lua) for a build,
// in CI before the packager runs. Gemini summarizes every commit in the build; the notes are kept
// on the changelog branch so a version always ships the same text, and a build carries the notes
// of the builds before it. See .claude/rules/changelog.md.
//
//	go run ./tools/changelog -channel alpha -from <before> -to <sha> -store <changelog branch checkout>
//	go run ./tools/changelog -channel release -tag v0.5.17 -store <changelog branch checkout>
//
// GEMINI_API_KEY (a Google AI Studio key) lets Gemini write the notes; without it they list the
// commits. GITHUB_TOKEN and GITHUB_REPOSITORY let an alpha read its pull requests' commits.
package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"
)

func main() {
	var cfg Config
	flag.StringVar(&cfg.Channel, "channel", "", `"alpha" (a push to main) or "release" (a tag)`)
	flag.StringVar(&cfg.Tag, "tag", "", "the release's tag")
	flag.StringVar(&cfg.From, "from", "", "the commit main was at before the push (an alpha)")
	flag.StringVar(&cfg.To, "to", "HEAD", "the build's commit (an alpha)")
	flag.StringVar(&cfg.StoreDir, "store", "", "a checkout of the changelog branch")
	flag.StringVar(&cfg.Out, "out", "data/changelogdata.lua", "the data file to write")
	repo := flag.String("repo", os.Getenv("GITHUB_REPOSITORY"), "owner/name, to read pull requests")
	model := flag.String("model", DefaultGeminiModel, "the Gemini model")
	flag.Parse()

	deps := Deps{Git: ExecGit{}, Log: os.Stderr}
	if key := os.Getenv("GEMINI_API_KEY"); key != "" {
		deps.Gemini = &Gemini{
			BaseURL:  DefaultGeminiURL,
			Key:      key,
			Model:    *model,
			HTTP:     &http.Client{Timeout: 3 * time.Minute},
			Attempts: 3,
			Sleep:    time.Sleep,
			Log:      os.Stderr,
		}
	}
	if *repo != "" {
		deps.GitHub = &GitHubClient{
			BaseURL: DefaultGitHubURL,
			Repo:    *repo,
			Token:   os.Getenv("GITHUB_TOKEN"),
			HTTP:    &http.Client{Timeout: 30 * time.Second},
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()
	if err := Run(ctx, cfg, deps); err != nil {
		fmt.Fprintln(os.Stderr, "changelog:", err)
		os.Exit(1)
	}
}
