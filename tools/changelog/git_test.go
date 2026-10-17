package main

import (
	"errors"
	"strings"
	"testing"
)

// fakeGit answers git commands from a table keyed by their arguments; anything else fails.
type fakeGit map[string]string

func (f fakeGit) Run(args ...string) (string, error) {
	key := strings.Join(args, " ")
	out, ok := f[key]
	if !ok {
		return "", errors.New("unexpected git " + key)
	}
	if out == "!error" {
		return "", errors.New("git " + key + " failed")
	}
	return out, nil
}

const describeExclude = "--exclude=*[Aa][Ll][Pp][Hh][Aa]*"

func TestCommitsReadsTheFirstParentLog(t *testing.T) {
	g := fakeGit{
		"log --first-parent --format=%H%x1f%s%x1f%b%x1e v0.5.16..v0.5.17": "aaa\x1fFirst (#1)\x1fBody one.\nMore.\n\x1e\nbbb\x1fSecond\x1f\x1e\n",
	}
	got, err := Commits(g, "v0.5.16", "v0.5.17")
	if err != nil {
		t.Fatalf("Commits: %v", err)
	}
	want := []Commit{{SHA: "aaa", Subject: "First (#1)", Body: "Body one.\nMore."}, {SHA: "bbb", Subject: "Second", Body: ""}}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Errorf("commits = %#v", got)
	}
}

func TestCommitsWithoutAStartReadsTheLatest(t *testing.T) {
	g := fakeGit{"log --first-parent --format=%H%x1f%s%x1f%b%x1e -n 50 abc": "aaa\x1fOnly\x1f\x1e"}
	got, err := Commits(g, "", "abc")
	if err != nil || len(got) != 1 || got[0].Subject != "Only" {
		t.Errorf("commits = %#v, %v", got, err)
	}
}

func TestResolveRangeForARelease(t *testing.T) {
	g := fakeGit{
		"describe --tags --abbrev=0 " + describeExclude + " v0.5.17^": "v0.5.16\n",
	}
	got, err := ResolveRange(g, Config{Channel: "release", Tag: "v0.5.17"})
	if err != nil {
		t.Fatalf("ResolveRange: %v", err)
	}
	if got != (Range{Version: "v0.5.17", From: "v0.5.16", To: "v0.5.17"}) {
		t.Errorf("range = %+v", got)
	}
}

func TestResolveRangeForTheFirstRelease(t *testing.T) {
	g := fakeGit{"describe --tags --abbrev=0 " + describeExclude + " v1^": "!error"}
	got, err := ResolveRange(g, Config{Channel: "release", Tag: "v1"})
	if err != nil || got != (Range{Version: "v1", From: "", To: "v1"}) {
		t.Errorf("range = %+v, %v", got, err)
	}
}

func TestResolveRangeForAnAlpha(t *testing.T) {
	base := fakeGit{
		"rev-parse --verify head^{commit}":                                     "head\n",
		"describe --tags --abbrev=7 " + describeExclude + " head":              "v0.5.16-14-gceff32a\n",
		"describe --tags --abbrev=0 " + describeExclude + " head":              "v0.5.16\n",
		"rev-parse --verify before^{commit}":                                   "before\n",
		"merge-base --is-ancestor before head":                                 "",
		"rev-parse --verify elsewhere^{commit}":                                "elsewhere\n",
		"merge-base --is-ancestor elsewhere head":                              "!error",
		"rev-parse --verify 0000000000000000000000000000000000000000^{commit}": "!error",
	}
	cases := map[string]string{
		"before":    "before",
		"":          "v0.5.16",
		"elsewhere": "v0.5.16",
		"0000000000000000000000000000000000000000": "v0.5.16",
	}
	for from, want := range cases {
		got, err := ResolveRange(base, Config{Channel: "alpha", From: from, To: "head"})
		if err != nil {
			t.Fatalf("from %q: %v", from, err)
		}
		if got != (Range{Version: "v0.5.16-14-gceff32a", From: want, To: "head"}) {
			t.Errorf("from %q: range = %+v", from, got)
		}
	}
}

func TestResolveRangeRejectsAnUnknownChannel(t *testing.T) {
	if _, err := ResolveRange(fakeGit{}, Config{Channel: "beta"}); err == nil {
		t.Errorf("no error")
	}
}
