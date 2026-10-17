package main

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

func TestWriteMarkdownMatchesTheGoldenFile(t *testing.T) {
	want, err := os.ReadFile("testdata/changelog.golden.md")
	if err != nil {
		t.Fatal(err)
	}
	var got bytes.Buffer
	if err := WriteMarkdown(&got, goldenReleases[0]); err != nil {
		t.Fatalf("WriteMarkdown: %v", err)
	}
	if got.String() != string(want) {
		t.Errorf("differs:\n--- got\n%s\n--- want\n%s", got.String(), want)
	}
}

func TestWriteMarkdownGroupsByCategoryInOrder(t *testing.T) {
	r := Release{Headline: "h", Entries: []Entry{
		{Category: "Fixed", Title: "f", Details: "d"},
		{Category: "Changed", Title: "c"},
		{Category: "New", Title: "n", Details: "d"},
		{Category: "Improved", Title: "i", Details: "d", Clients: []string{"Retail", "Classic"}},
		{Category: "New", Title: "n2", Details: "d", Clients: []string{"Retail", "Classic", "Forever"}},
	}}
	var got bytes.Buffer
	if err := WriteMarkdown(&got, r); err != nil {
		t.Fatal(err)
	}
	want := "h\n\n## New\n\n- **n**: d\n- **n2**: d\n\n## Improved\n\n- **i** (Retail and Classic only): d\n\n" +
		"## Fixed\n\n- **f**: d\n\n## Changes\n\n- **c**\n"
	if got.String() != want {
		t.Errorf("got:\n%s\nwant:\n%s", got.String(), want)
	}
}

func TestWriteMarkdownWithNothingForPlayers(t *testing.T) {
	var got bytes.Buffer
	if err := WriteMarkdown(&got, Release{Headline: "Only behind-the-scenes changes.", Entries: []Entry{}}); err != nil {
		t.Fatal(err)
	}
	if got.String() != "Only behind-the-scenes changes.\n" {
		t.Errorf("got %q", got.String())
	}
}

func TestMarkdownTextEscapes(t *testing.T) {
	cases := map[string]string{
		"Settings > Theme":            `Settings \> Theme`,
		"*bold* _it_ `code` [a](b)":   `\*bold\* \_it\_ \` + "`" + `code\` + "`" + ` \[a\](b)`,
		"<b>tag</b>":                  `\<b\>tag\</b\>`,
		`back\slash`:                  `back\\slash`,
		"a || b":                      `a \| b`,
		"# Heading-like":              `\# Heading-like`,
		"- list-like":                 `\- list-like`,
		"1. numbered":                 `1\. numbered`,
		"plain words, nothing to do.": "plain words, nothing to do.",
	}
	for in, want := range cases {
		if got := markdownText(in); got != want {
			t.Errorf("markdownText(%q) = %q, want %q", in, got, want)
		}
	}
	if strings.Contains(markdownText("2. x"), "2.") && !strings.HasPrefix(markdownText("2. x"), `2\.`) {
		t.Errorf("a leading number is not escaped")
	}
}

// The packager reads the file the release workflows have the generator write (.pkgmeta
// manual-changelog), as Markdown; a run that fails leaves none, so the packager falls back to its
// changelog of commits (BigWigsMods/packager release.sh: no manual changelog file, a generated one).
func TestThePackagerReadsTheMarkdownTheWorkflowsWrite(t *testing.T) {
	pkgmeta, err := os.ReadFile("../../.pkgmeta")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(pkgmeta), "manual-changelog:\n  filename: CHANGELOG.md\n  markup-type: markdown\n") {
		t.Errorf(".pkgmeta does not read CHANGELOG.md as Markdown:\n%s", pkgmeta)
	}
	for _, workflow := range []string{"../../.github/workflows/release_alpha.yaml", "../../.github/workflows/release.yml"} {
		data, err := os.ReadFile(workflow)
		if err != nil {
			t.Fatal(err)
		}
		text := string(data)
		if !strings.Contains(text, "-markdown CHANGELOG.md") {
			t.Errorf("%s does not write CHANGELOG.md", workflow)
		}
		if !strings.Contains(text, "rm -f CHANGELOG.md") {
			t.Errorf("%s keeps a CHANGELOG.md when the changelog fails", workflow)
		}
	}
}
