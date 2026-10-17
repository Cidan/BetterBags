package main

import (
	"bytes"
	"os"
	"testing"
)

var goldenReleases = []Release{
	{ID: 1792281600, Version: "v0.5.17", Channel: "release", Date: "2026-10-18", Headline: `Tabs "for" every theme.`,
		Entries: []Entry{
			{Category: "New", Title: "Themed tabs", Details: `Tabs match the theme.\ A backslash.`, Clients: []string{}},
			{Category: "Fixed", Title: "Keyring slots", Details: "", Clients: []string{"Forever"}},
		}},
	{ID: 1792195200, Version: "v0.5.16", Channel: "release", Date: "2026-10-17", Headline: "An older release.",
		Entries: []Entry{
			{Category: "Improved", Title: "Faster sorting", Details: "Sorting reads the bags once.", Clients: []string{"Retail", "Classic"}},
		}},
}

func TestWriteLuaMatchesTheGoldenFile(t *testing.T) {
	for file, releases := range map[string][]Release{
		"testdata/changelogdata.golden.lua": goldenReleases,
		"testdata/changelogdata.empty.lua":  nil,
	} {
		want, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("read %s: %v", file, err)
		}
		var got bytes.Buffer
		if err := WriteLua(&got, releases); err != nil {
			t.Fatalf("WriteLua: %v", err)
		}
		if got.String() != string(want) {
			t.Errorf("%s differs:\n--- got\n%s\n--- want\n%s", file, got.String(), want)
		}
	}
}

// The copy of the data file in the repository is in the generator's format.
func TestTheRepositorysDataFileStartsLikeTheGenerators(t *testing.T) {
	data, err := os.ReadFile("../../data/changelogdata.lua")
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !bytes.HasPrefix(data, []byte(luaHeader+"changelogData.releases = {")) {
		t.Errorf("data/changelogdata.lua does not start with the generator's header")
	}
}

func TestLuaStringEscapes(t *testing.T) {
	cases := map[string]string{
		`plain`:                `"plain"`,
		"a\"b\\c":              `"a\"b\\c"`,
		"line\nnext\r\ttab":    `"line\nnext\r\ttab"`,
		"bell\x07" + "9":       `"bell\0079"`,
		"del\x7f1":             `"del\1271"`,
		"é and ü pass through": `"é and ü pass through"`,
	}
	for in, want := range cases {
		if got := luaString(in); got != want {
			t.Errorf("luaString(%q) = %s, want %s", in, got, want)
		}
	}
}
