package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// Commit is a commit's message.
type Commit struct {
	SHA     string
	Subject string
	Body    string
}

// Git runs git commands.
type Git interface {
	Run(args ...string) (string, error)
}

// ExecGit runs git in a directory.
type ExecGit struct {
	Dir string
}

// Run runs git with args and returns what it printed.
func (g ExecGit) Run(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = g.Dir
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return string(out), nil
}

// The packager names a build after the latest tag that is not an alpha tag
// (BigWigsMods/packager release.sh, git describe --tags --exclude="*[Aa][Ll][Pp][Hh][Aa]*").
const tagExclude = "--exclude=*[Aa][Ll][Pp][Hh][Aa]*"

// latestCommitsWithoutAStart is how many commits a range with no start reads.
const latestCommitsWithoutAStart = 50

// Commits returns the first-parent commits from from (excluded) to to, newest first: on main,
// one squash-merged pull request each. With no from, the latest commits up to to.
func Commits(g Git, from, to string) ([]Commit, error) {
	args := []string{"log", "--first-parent", "--format=%H%x1f%s%x1f%b%x1e"}
	if from == "" {
		args = append(args, "-n", fmt.Sprint(latestCommitsWithoutAStart), to)
	} else {
		args = append(args, from+".."+to)
	}
	out, err := g.Run(args...)
	if err != nil {
		return nil, err
	}
	var commits []Commit
	for _, record := range strings.Split(out, "\x1e") {
		fields := strings.SplitN(strings.TrimLeft(record, "\n"), "\x1f", 3)
		if len(fields) != 3 {
			continue
		}
		commits = append(commits, Commit{
			SHA:     strings.TrimSpace(fields[0]),
			Subject: strings.TrimSpace(fields[1]),
			Body:    strings.TrimSpace(fields[2]),
		})
	}
	return commits, nil
}

// Range is the build a changelog is written for: its version and the commits it covers.
type Range struct {
	Version string
	From    string
	To      string
}

func describe(g Git, args ...string) (string, error) {
	out, err := g.Run(append([]string{"describe", "--tags"}, args...)...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

// isCommit returns rev resolved to a commit, or false when it does not name one (an empty or
// all-zero "before" of a new branch).
func isCommit(g Git, rev string) (string, bool) {
	if rev == "" || strings.Trim(rev, "0") == "" {
		return "", false
	}
	out, err := g.Run("rev-parse", "--verify", rev+"^{commit}")
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(out), true
}

// ResolveRange works out a build's version and commits. A tagged release covers every commit
// since the previous tag. An alpha covers what the push to main added: from the commit main was
// at before (cfg.From, the push's "before"), or since the latest tag when that is not a commit
// main grew from.
func ResolveRange(g Git, cfg Config) (Range, error) {
	switch cfg.Channel {
	case "release":
		if cfg.Tag == "" {
			return Range{}, fmt.Errorf("a release needs its tag")
		}
		previous, err := describe(g, "--abbrev=0", tagExclude, cfg.Tag+"^")
		if err != nil {
			previous = ""
		}
		return Range{Version: cfg.Tag, From: previous, To: cfg.Tag}, nil
	case "alpha":
		to, ok := isCommit(g, cfg.To)
		if !ok {
			return Range{}, fmt.Errorf("%q is not a commit", cfg.To)
		}
		version, err := describe(g, "--abbrev=7", tagExclude, to)
		if err != nil {
			return Range{}, err
		}
		if from, ok := isCommit(g, cfg.From); ok {
			if _, err := g.Run("merge-base", "--is-ancestor", from, to); err == nil {
				return Range{Version: version, From: from, To: to}, nil
			}
		}
		latest, err := describe(g, "--abbrev=0", tagExclude, to)
		if err != nil {
			latest = ""
		}
		return Range{Version: version, From: latest, To: to}, nil
	}
	return Range{}, fmt.Errorf("unknown channel %q", cfg.Channel)
}
