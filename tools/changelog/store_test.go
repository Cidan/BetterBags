package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStoreSavesAndLoadsReleases(t *testing.T) {
	store := Store{Dir: t.TempDir()}
	alpha := Release{ID: 2, Version: "v0.5.16-14-gceff32a", Channel: "alpha", Date: "2026-10-17", From: "a", To: "b",
		Headline: "h", Entries: []Entry{{Category: "Fixed", Title: "t", Details: "d", Clients: []string{"Forever"}}}, Fallback: true}
	release := Release{ID: 1, Version: "v0.5.16", Channel: "release", Date: "2026-10-01", Headline: "older", Entries: []Entry{}}
	for _, r := range []Release{alpha, release} {
		if err := store.Save(r); err != nil {
			t.Fatalf("Save: %v", err)
		}
	}
	if _, err := os.Stat(filepath.Join(store.Dir, "releases", "v0.5.16-14-gceff32a.json")); err != nil {
		t.Errorf("file: %v", err)
	}
	got, err := store.Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(got) != 2 || got[0].Version != "v0.5.16" || got[1].Version != "v0.5.16-14-gceff32a" {
		t.Fatalf("loaded %+v", got)
	}
	if !got[1].Fallback || got[1].Entries[0].Clients[0] != "Forever" || got[1].From != "a" {
		t.Errorf("alpha = %+v", got[1])
	}
	alpha.Headline = "rewritten"
	alpha.Fallback = false
	if err := store.Save(alpha); err != nil {
		t.Fatalf("Save: %v", err)
	}
	got, _ = store.Load()
	if len(got) != 2 || got[1].Headline != "rewritten" || got[1].Fallback {
		t.Errorf("after overwrite %+v", got)
	}
}

func TestStoreLoadsNothingFromAMissingDirectory(t *testing.T) {
	got, err := Store{Dir: filepath.Join(t.TempDir(), "missing")}.Load()
	if err != nil || len(got) != 0 {
		t.Errorf("got %v, %v", got, err)
	}
}

func TestStoreNamesFilesSafely(t *testing.T) {
	if got := fileName("v1.0/../x y"); got != "v1.0_.._x_y.json" {
		t.Errorf("fileName = %q", got)
	}
}
