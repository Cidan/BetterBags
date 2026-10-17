package main

import "sort"

const (
	// maxBundledReleases is how many tagged releases a build carries.
	maxBundledReleases = 10
	// maxBundledAlphas is how many alpha builds since the latest tag an alpha carries.
	maxBundledAlphas = 20
)

// Bundle picks the releases a build carries, newest first, so a player who skipped builds sees
// the notes of every one they missed: a tagged release carries the tagged releases up to it; an
// alpha also carries the alphas since the latest tag. Releases with no entries are left out.
func Bundle(stored []Release, channel string, current Release) []Release {
	var releases, alphas []Release
	for _, r := range stored {
		if r.ID > current.ID || len(r.Entries) == 0 {
			continue
		}
		if r.Channel == "release" {
			releases = append(releases, r)
		} else if r.Channel == "alpha" {
			alphas = append(alphas, r)
		}
	}
	newestFirst := func(list []Release) {
		sort.SliceStable(list, func(i, j int) bool { return list[i].ID > list[j].ID })
	}
	newestFirst(releases)
	newestFirst(alphas)
	if len(releases) > maxBundledReleases {
		releases = releases[:maxBundledReleases]
	}
	bundle := append([]Release{}, releases...)
	if channel == "alpha" {
		var latestRelease int64
		if len(releases) > 0 {
			latestRelease = releases[0].ID
		}
		kept := 0
		for _, a := range alphas {
			if a.ID <= latestRelease || kept >= maxBundledAlphas {
				continue
			}
			bundle = append(bundle, a)
			kept++
		}
	}
	newestFirst(bundle)
	return bundle
}
