package main

import (
	"strings"
	"testing"
)

func TestValidateCleansTheText(t *testing.T) {
	s := Summary{
		Headline: "  Faster bags |cffff0000and\nfixes  ",
		Entries: []Entry{{
			Category: "Fixed",
			Title:    "Keyring | free slots\t",
			Details:  "Line one.\nLine two.\x07",
			Clients:  []string{"Forever", "Bogus", "Retail", "Forever"},
		}},
	}
	got, err := s.Validate()
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	if got.Headline != "Faster bags ||cffff0000and fixes" {
		t.Errorf("headline = %q", got.Headline)
	}
	e := got.Entries[0]
	if e.Title != "Keyring || free slots" {
		t.Errorf("title = %q", e.Title)
	}
	if e.Details != "Line one. Line two." {
		t.Errorf("details = %q", e.Details)
	}
	// Known clients only, once each, always in the same order.
	if strings.Join(e.Clients, ",") != "Retail,Forever" {
		t.Errorf("clients = %v", e.Clients)
	}
	if s.Entries[0].Title != "Keyring | free slots\t" {
		t.Errorf("Validate changed its input")
	}
}

func TestValidateCutsLongText(t *testing.T) {
	long := strings.Repeat("é", maxTitle+20)
	got, err := Summary{Headline: "h", Entries: []Entry{{Category: "New", Title: long, Details: "d"}}}.Validate()
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	title := []rune(got.Entries[0].Title)
	if len(title) != maxTitle || !strings.HasSuffix(got.Entries[0].Title, "...") {
		t.Errorf("title is %d runes: %q", len(title), got.Entries[0].Title)
	}
}

func TestValidateKeepsAtMostMaxEntries(t *testing.T) {
	s := Summary{Headline: "h"}
	for i := 0; i < maxEntries+5; i++ {
		s.Entries = append(s.Entries, Entry{Category: "New", Title: "t", Details: "d"})
	}
	got, err := s.Validate()
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	if len(got.Entries) != maxEntries {
		t.Errorf("kept %d entries", len(got.Entries))
	}
}

func TestValidateRejects(t *testing.T) {
	cases := map[string]Summary{
		"no headline":      {Headline: " ", Entries: nil},
		"unknown category": {Headline: "h", Entries: []Entry{{Category: "Changed", Title: "t"}}},
		"no title":         {Headline: "h", Entries: []Entry{{Category: "New", Title: " \n "}}},
	}
	for name, s := range cases {
		if _, err := s.Validate(); err == nil {
			t.Errorf("%s: no error", name)
		}
	}
	if _, err := (Summary{Headline: "Nothing players notice."}).Validate(); err != nil {
		t.Errorf("a summary with no entries: %v", err)
	}
}

func TestFallbackSummaryListsTheCommits(t *testing.T) {
	got := FallbackSummary([]Commit{
		{SHA: "a", Subject: "Forever free slots: leave out the keyring (#1144)"},
		{SHA: "b", Subject: "  "},
		{SHA: "c", Subject: "Fix a | pipe"},
	})
	if got.Headline == "" {
		t.Errorf("no headline")
	}
	if len(got.Entries) != 2 {
		t.Fatalf("entries = %v", got.Entries)
	}
	if got.Entries[0].Title != "Forever free slots: leave out the keyring" || got.Entries[0].Category != "Changed" {
		t.Errorf("first entry = %+v", got.Entries[0])
	}
	if got.Entries[1].Title != "Fix a || pipe" || got.Entries[1].Details != "" || len(got.Entries[1].Clients) != 0 {
		t.Errorf("second entry = %+v", got.Entries[1])
	}
	many := make([]Commit, maxEntries+3)
	for i := range many {
		many[i] = Commit{SHA: "x", Subject: "s"}
	}
	if n := len(FallbackSummary(many).Entries); n != maxEntries {
		t.Errorf("kept %d entries", n)
	}
}
