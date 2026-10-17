package main

import (
	"strings"
	"testing"
)

func versions(releases []Release) string {
	var out []string
	for _, r := range releases {
		out = append(out, r.Version)
	}
	return strings.Join(out, ",")
}

func rel(id int64, version, channel string, entries int) Release {
	r := Release{ID: id, Version: version, Channel: channel}
	for i := 0; i < entries; i++ {
		r.Entries = append(r.Entries, Entry{Category: "Fixed", Title: "t"})
	}
	return r
}

func TestBundleForAReleaseHasOnlyReleasesUpToIt(t *testing.T) {
	stored := []Release{
		rel(10, "v1", "release", 1),
		rel(20, "v1-1-gaaa", "alpha", 1),
		rel(30, "v2", "release", 1),
		rel(40, "v2-1-gbbb", "alpha", 1),
		rel(50, "v3", "release", 1),
	}
	got := Bundle(stored, "release", stored[2])
	if versions(got) != "v2,v1" {
		t.Errorf("bundle = %s", versions(got))
	}
}

func TestBundleForAnAlphaAddsTheAlphasSinceTheLastRelease(t *testing.T) {
	stored := []Release{
		rel(10, "v1", "release", 1),
		rel(20, "v1-1-gaaa", "alpha", 1),
		rel(30, "v2", "release", 1),
		rel(40, "v2-1-gbbb", "alpha", 1),
		rel(50, "v2-2-gccc", "alpha", 1),
		rel(60, "v2-3-gddd", "alpha", 1),
	}
	got := Bundle(stored, "alpha", stored[4])
	if versions(got) != "v2-2-gccc,v2-1-gbbb,v2,v1" {
		t.Errorf("bundle = %s", versions(got))
	}
}

func TestBundleLeavesOutReleasesWithNoEntries(t *testing.T) {
	stored := []Release{rel(10, "v1", "release", 1), rel(20, "v1-1-gaaa", "alpha", 0), rel(30, "v1-2-gbbb", "alpha", 2)}
	if got := Bundle(stored, "alpha", stored[2]); versions(got) != "v1-2-gbbb,v1" {
		t.Errorf("bundle = %s", versions(got))
	}
}

func TestBundleKeepsAtMostItsLimits(t *testing.T) {
	var stored []Release
	id := int64(0)
	for i := 0; i < maxBundledReleases+3; i++ {
		id++
		stored = append(stored, rel(id, "r"+string(rune('a'+i)), "release", 1))
	}
	for i := 0; i < maxBundledAlphas+3; i++ {
		id++
		stored = append(stored, rel(id, "a"+string(rune('a'+i)), "alpha", 1))
	}
	got := Bundle(stored, "alpha", stored[len(stored)-1])
	releases, alphas := 0, 0
	for _, r := range got {
		if r.Channel == "release" {
			releases++
		} else {
			alphas++
		}
	}
	if releases != maxBundledReleases || alphas != maxBundledAlphas {
		t.Errorf("%d releases, %d alphas", releases, alphas)
	}
	if got[0].ID != id {
		t.Errorf("newest first: %d", got[0].ID)
	}
}
